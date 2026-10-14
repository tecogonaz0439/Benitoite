//! 値の葉と入れ子の参照先を宣言順に辿り、転送形式と正準 ABI のメモリを読み書きする。
//! 構築量は言語の出現の表から求め、ABI 専用の組を余分に数えない。

use wasm_encoder::{BlockType, Instruction, MemArg};

use super::codec::CodecPlan;
use super::emit::{BoundedFunction as Function, CoreType};
use super::layout::{LayoutError, LayoutKind, MemoryLayout};
use crate::external::WitPlan;

// 呼び出し一つで共有する作業領域。要素数によらず局所変数の数を固定する。
pub(super) const OUTPUT: u32 = 2;
pub(super) const PAIR: u32 = 3;
pub(super) const PARAMS: u32 = 4;
pub(super) const RESULTS: u32 = 5;
pub(super) const CURSOR: u32 = 6;
const SOURCE: u32 = 7;
const COUNT: u32 = 8;
const BYTES: u32 = 9;
const INDEX: u32 = 10;
const DEST: u32 = 11;
const BYTE: u32 = 12;
const REMAIN: u32 = 13;
const CODEPOINT: u32 = 14;
const MINIMUM: u32 = 15;
const PADDING: u32 = 16;
pub(super) const LIMIT: u32 = 18;
const COST: u32 = 19;
pub(super) const END: u32 = 20;

use super::emit::instructions as ops;
use super::runtime::FailureCode;

/// 平らな ABI の一要素と、根の固定部に対する位置。
#[derive(Clone)]
pub(super) struct Leaf {
    pub offset: u32,
    pub size: u32,
    pub core: CoreType,
    signed: bool,
    boolean: bool,
    character: bool,
    cases: Option<u32>,
    flags_mask: Option<u32>,
    flat: usize,
}

/// 固定部の葉と、可変長の子を持つ要素の平らな走査表。
pub(super) struct FixedValues {
    pub(super) root: Scan,
    scans: Vec<Scan>,
    frames: u32,
}

/// 一つの固定部。リストの子は別の走査表を番号で参照する。
pub(super) struct Scan {
    pub leaves: Vec<Leaf>,
    pub size: u32,
    pub construction: u64,
    references: Vec<Reference>,
    variants: Vec<Variant>,
    actions: Vec<Action>,
    occupied: Vec<(u32, u32)>,
    flat: Vec<CoreType>,
}

struct Variant {
    discriminant: Leaf,
    payload_offset: u32,
    size: u32,
    cases: Vec<Option<usize>>,
    case_bytes: Vec<u64>,
    flat: Vec<CoreType>,
}

enum Action {
    Reference(usize),
    Variant(usize),
    Flags(usize, u64),
}

struct Reference {
    offset: u32,
    element: MemoryLayout,
    child: Option<usize>,
    string: bool,
    list: bool,
    map: bool,
}

impl FixedValues {
    /// 直接の引数を場合ごとの葉から合流する。非選択のスロットは型に合う零で埋める。
    pub(super) fn load_flat(&self, f: &mut Function, base: u32) -> Result<(), LayoutError> {
        use Instruction::*;
        for (slot, &core) in self.root.flat.iter().enumerate() {
            let mut work = vec![FlatValue {
                scan: &self.root,
                slot,
                offset: 0,
                joined: vec![],
                conditions: vec![],
            }];
            let mut branches = 0_u32;
            while let Some(value) = work.pop() {
                if let Some(leaf) = value
                    .scan
                    .leaves
                    .iter()
                    .find(|leaf| leaf.flat == value.slot)
                {
                    if !value.conditions.is_empty() {
                        for (index, (discriminant, case)) in value.conditions.iter().enumerate() {
                            discriminant.load(f, base, 0)?;
                            ops(f, &[I32Const(*case as i32), I32Eq]);
                            if index != 0 {
                                ops(f, &[I32And]);
                            }
                        }
                        ops(f, &[If(BlockType::Result(core.encoded()))]);
                        branches = branches.checked_add(1).ok_or(LayoutError::Memory32)?;
                    }
                    leaf.load(f, base, value.offset)?;
                    let mut from = leaf.core;
                    for &to in value.joined.iter().rev() {
                        ops(f, from.conversion(to)?.to_joined);
                        from = to;
                    }
                    if !value.conditions.is_empty() {
                        ops(f, &[Else]);
                    }
                    continue;
                }
                let variant = value
                    .scan
                    .variants
                    .iter()
                    .find(|v| {
                        value.slot > v.discriminant.flat
                            && value.slot.saturating_sub(v.discriminant.flat) < v.flat.len()
                    })
                    .ok_or(LayoutError::Internal("flat value is missing"))?;
                let slot = value
                    .slot
                    .checked_sub(variant.discriminant.flat)
                    .and_then(|n| n.checked_sub(1))
                    .ok_or(LayoutError::Memory32)?;
                let joined = *variant
                    .flat
                    .get(slot.saturating_add(1))
                    .ok_or(LayoutError::Internal("joined type is missing"))?;
                for (case, child) in variant.cases.iter().enumerate().rev() {
                    let Some(child) = child else {
                        continue;
                    };
                    let scan = self
                        .scans
                        .get(*child)
                        .ok_or(LayoutError::Internal("variant scan is missing"))?;
                    if slot >= scan.flat.len() {
                        continue;
                    }
                    let mut conversions = value.joined.clone();
                    conversions.push(joined);
                    let mut conditions = value.conditions.clone();
                    let mut discriminant = variant.discriminant.clone();
                    discriminant.offset = discriminant
                        .offset
                        .checked_add(value.offset)
                        .ok_or(LayoutError::Memory32)?;
                    conditions.push((
                        discriminant,
                        u32::try_from(case).map_err(|_| LayoutError::Memory32)?,
                    ));
                    work.push(FlatValue {
                        scan,
                        slot,
                        offset: value
                            .offset
                            .checked_add(variant.discriminant.offset)
                            .and_then(|n| n.checked_add(variant.payload_offset))
                            .ok_or(LayoutError::Memory32)?,
                        joined: conversions,
                        conditions,
                    });
                }
            }
            if branches != 0 {
                f.instruction(&match core {
                    CoreType::I32 => I32Const(0),
                    CoreType::I64 => I64Const(0),
                    CoreType::F32 => F32Const(0.0.into()),
                    CoreType::F64 => F64Const(0.0.into()),
                });
                for _ in 0..branches {
                    ops(f, &[End]);
                }
            }
        }
        Ok(())
    }

    /// 型を明示の作業列で辿り、要素数に依存しない走査表と局所変数の数を求める。
    pub(super) fn new(plans: &[WitPlan], codec: &CodecPlan<'_>) -> Result<Self, LayoutError> {
        let mut pending = Vec::new();
        let root = scan(
            plans
                .iter()
                .zip(&codec.layout.roots.fields)
                .map(|(p, f)| (p, f.node, f.offset))
                .collect(),
            codec.layout.roots.memory.size,
            codec,
            &mut pending,
            0,
        )?;
        let mut scans = Vec::new();
        let mut frames = 1;
        while let Some(child) = pending.get(scans.len()) {
            let depth = child.depth;
            let fields = child.fields.clone();
            let size = child.size;
            scans.push(scan(fields, size, codec, &mut pending, depth)?);
            frames = frames.max(depth.checked_add(1).ok_or(LayoutError::Memory32)?);
        }
        Ok(Self {
            root,
            scans,
            frames,
        })
    }

    /// 親のループを保存する領域。型の深さだけに比例し、要素数では増えない。
    pub(super) fn extra_locals(&self) -> Result<u32, LayoutError> {
        self.frames
            .checked_mul(FRAME_SIZE)
            .ok_or(LayoutError::Memory32)
    }
}

struct FlatValue<'a> {
    scan: &'a Scan,
    slot: usize,
    offset: u32,
    joined: Vec<CoreType>,
    conditions: Vec<(Leaf, u32)>,
}

struct Pending<'a> {
    fields: Vec<(&'a WitPlan, usize, u32)>,
    size: u32,
    depth: u32,
}

fn scan<'a>(
    mut work: Vec<(&'a WitPlan, usize, u32)>,
    size: u32,
    codec: &CodecPlan<'_>,
    pending: &mut Vec<Pending<'a>>,
    depth: u32,
) -> Result<Scan, LayoutError> {
    work.reverse();
    let mut leaves = Vec::new();
    let mut references = Vec::new();
    let mut variants = Vec::new();
    let mut actions = Vec::new();
    let mut occupied = Vec::new();
    let mut flat = Vec::new();
    let mut construction = 0_u64;
    while let Some((plan, id, offset)) = work.pop() {
        let node = codec
            .layout
            .nodes
            .get(id)
            .ok_or(LayoutError::Internal("fixed layout is missing"))?;
        let rule = codec
            .construction
            .nodes
            .get(id)
            .ok_or(LayoutError::Internal("fixed construction rule is missing"))?;
        construction = construction
            .checked_add(rule.value_bytes)
            .ok_or(LayoutError::Memory32)?;
        match (&node.kind, plan) {
            (LayoutKind::Record { fields }, _) => {
                let children: Vec<_> = match plan {
                    WitPlan::Record { fields } => fields.iter().map(|(_, p)| p).collect(),
                    WitPlan::Tuple(ps)
                    | WitPlan::TupleFields(ps)
                    | WitPlan::ConstructorTuple { fields: ps, .. } => ps.iter().collect(),
                    WitPlan::S8
                    | WitPlan::S16
                    | WitPlan::S32
                    | WitPlan::S64
                    | WitPlan::U8
                    | WitPlan::U16
                    | WitPlan::U32
                    | WitPlan::U64
                    | WitPlan::F32
                    | WitPlan::F64
                    | WitPlan::Bool
                    | WitPlan::Char
                    | WitPlan::String
                    | WitPlan::Bytes
                    | WitPlan::List(_)
                    | WitPlan::Map(_, _)
                    | WitPlan::Option(_)
                    | WitPlan::Result { .. }
                    | WitPlan::Variant { .. }
                    | WitPlan::Enum { .. }
                    | WitPlan::Flags { .. }
                    | WitPlan::Own(_)
                    | WitPlan::Borrow(_) => {
                        return Err(LayoutError::Internal("fixed record plan is missing"));
                    }
                };
                if children.len() != fields.len() {
                    return Err(LayoutError::Internal("fixed record fields differ"));
                }
                for (p, f) in children.into_iter().zip(fields).rev() {
                    work.push((
                        p,
                        f.node,
                        offset.checked_add(f.offset).ok_or(LayoutError::Memory32)?,
                    ));
                }
            }
            (LayoutKind::Scalar, _) => {
                let [core] = node.flat.as_slice() else {
                    return Err(LayoutError::Internal("fixed scalar type is missing"));
                };
                leaves.push(Leaf {
                    offset,
                    size: node.memory.size,
                    core: *core,
                    signed: matches!(plan, WitPlan::S8 | WitPlan::S16),
                    boolean: matches!(plan, WitPlan::Bool),
                    character: matches!(plan, WitPlan::Char),
                    cases: None,
                    flags_mask: None,
                    flat: flat.len(),
                });
                occupied.push((offset, node.memory.size));
                flat.extend_from_slice(&node.flat);
            }
            (LayoutKind::Enum { discriminant_size }, WitPlan::Enum { cases }) => {
                leaves.push(Leaf {
                    offset,
                    size: *discriminant_size,
                    core: CoreType::I32,
                    signed: false,
                    boolean: false,
                    character: false,
                    cases: Some(u32::try_from(cases.len()).map_err(|_| LayoutError::Memory32)?),
                    flags_mask: None,
                    flat: flat.len(),
                });
                occupied.push((offset, node.memory.size));
                flat.extend_from_slice(&node.flat);
            }
            (
                LayoutKind::Variant {
                    discriminant_size,
                    payload_offset,
                    cases,
                },
                _,
            ) => {
                let children: Vec<_> = match plan {
                    WitPlan::Option(p) => vec![None, Some(p.as_ref())],
                    WitPlan::Result { ok, err } => vec![ok.as_deref(), err.as_deref()],
                    WitPlan::Variant { cases } => {
                        cases.iter().map(|(_, _, p)| p.as_deref()).collect()
                    }
                    WitPlan::S8
                    | WitPlan::S16
                    | WitPlan::S32
                    | WitPlan::S64
                    | WitPlan::U8
                    | WitPlan::U16
                    | WitPlan::U32
                    | WitPlan::U64
                    | WitPlan::F32
                    | WitPlan::F64
                    | WitPlan::Bool
                    | WitPlan::Char
                    | WitPlan::String
                    | WitPlan::Bytes
                    | WitPlan::List(_)
                    | WitPlan::Map(_, _)
                    | WitPlan::Tuple(_)
                    | WitPlan::TupleFields(_)
                    | WitPlan::ConstructorTuple { .. }
                    | WitPlan::Record { .. }
                    | WitPlan::Enum { .. }
                    | WitPlan::Flags { .. }
                    | WitPlan::Own(_)
                    | WitPlan::Borrow(_) => {
                        return Err(LayoutError::Internal("variant plan is missing"));
                    }
                };
                if children.len() != cases.len() {
                    return Err(LayoutError::Internal("variant cases differ"));
                }
                let mut scans = Vec::new();
                for (p, id) in children.into_iter().zip(cases) {
                    scans.push(match (p, id) {
                        (Some(p), Some(id)) => {
                            let child = pending.len();
                            pending.push(Pending {
                                fields: vec![(p, *id, 0)],
                                size: codec
                                    .layout
                                    .nodes
                                    .get(*id)
                                    .ok_or(LayoutError::Internal("variant layout is missing"))?
                                    .memory
                                    .size,
                                depth: depth.checked_add(1).ok_or(LayoutError::Memory32)?,
                            });
                            Some(child)
                        }
                        (None, None) => None,
                        _ => return Err(LayoutError::Internal("variant payload differs")),
                    });
                }
                let discriminant = Leaf {
                    offset,
                    size: *discriminant_size,
                    core: CoreType::I32,
                    signed: false,
                    boolean: false,
                    character: false,
                    cases: Some(u32::try_from(cases.len()).map_err(|_| LayoutError::Memory32)?),
                    flags_mask: None,
                    flat: flat.len(),
                };
                leaves.push(discriminant.clone());
                actions.push(Action::Variant(variants.len()));
                variants.push(Variant {
                    discriminant,
                    payload_offset: *payload_offset,
                    size: node.memory.size,
                    cases: scans,
                    case_bytes: rule.case_bytes.clone(),
                    flat: node.flat.clone(),
                });
                occupied.push((offset, node.memory.size));
                flat.extend_from_slice(&node.flat);
            }
            (LayoutKind::Flags, WitPlan::Flags { cases }) => {
                let mask = if cases.len() == 32 {
                    u32::MAX
                } else {
                    1_u32
                        .checked_shl(u32::try_from(cases.len()).map_err(|_| LayoutError::Memory32)?)
                        .ok_or(LayoutError::Memory32)?
                        .saturating_sub(1)
                };
                actions.push(Action::Flags(leaves.len(), rule.selected_item_bytes));
                leaves.push(Leaf {
                    offset,
                    size: node.memory.size,
                    core: CoreType::I32,
                    signed: false,
                    boolean: false,
                    character: false,
                    cases: None,
                    flags_mask: Some(mask),
                    flat: flat.len(),
                });
                occupied.push((offset, node.memory.size));
                flat.extend_from_slice(&node.flat);
            }
            (
                LayoutKind::String
                | LayoutKind::Bytes
                | LayoutKind::List { .. }
                | LayoutKind::Map { .. },
                _,
            ) => {
                let (element, child) = if let LayoutKind::List { element } = node.kind {
                    let WitPlan::List(p) = plan else {
                        return Err(LayoutError::Internal("list plan is missing"));
                    };
                    let memory = codec
                        .layout
                        .nodes
                        .get(element)
                        .ok_or(LayoutError::Internal("list layout is missing"))?
                        .memory;
                    let child = pending.len();
                    pending.push(Pending {
                        fields: vec![(p, element, 0)],
                        size: memory.size,
                        depth: depth.checked_add(1).ok_or(LayoutError::Memory32)?,
                    });
                    (memory, Some(child))
                } else if let LayoutKind::Map { entry } = &node.kind {
                    let WitPlan::Map(key, value) = plan else {
                        return Err(LayoutError::Internal("map plan is missing"));
                    };
                    let [k, v] = entry.fields.as_slice() else {
                        return Err(LayoutError::Internal("map fields are missing"));
                    };
                    // ABI 専用の組は言語の Pair ではないため、鍵と値の出現だけを数える。
                    let child = pending.len();
                    pending.push(Pending {
                        fields: vec![(key, k.node, k.offset), (value, v.node, v.offset)],
                        size: entry.memory.size,
                        depth: depth.checked_add(1).ok_or(LayoutError::Memory32)?,
                    });
                    (entry.memory, Some(child))
                } else {
                    (
                        MemoryLayout {
                            size: 1,
                            alignment: 1,
                        },
                        None,
                    )
                };
                actions.push(Action::Reference(references.len()));
                references.push(Reference {
                    offset,
                    element,
                    child,
                    string: matches!(plan, WitPlan::String),
                    list: matches!(plan, WitPlan::List(_)),
                    map: matches!(plan, WitPlan::Map(_, _)),
                });
                for (index, position) in
                    [offset, offset.checked_add(4).ok_or(LayoutError::Memory32)?]
                        .into_iter()
                        .enumerate()
                {
                    leaves.push(Leaf {
                        offset: position,
                        size: 4,
                        core: CoreType::I32,
                        signed: false,
                        boolean: false,
                        character: false,
                        cases: None,
                        flags_mask: None,
                        flat: flat.len().checked_add(index).ok_or(LayoutError::Memory32)?,
                    });
                }
                occupied.push((offset, node.memory.size));
                flat.extend_from_slice(&node.flat);
            }
            _ => {
                return Err(LayoutError::Internal(
                    "non-fixed adapter value is not supported yet",
                ));
            }
        }
    }
    Ok(Scan {
        leaves,
        size,
        construction,
        references,
        variants,
        actions,
        occupied,
        flat,
    })
}

impl Scan {
    /// 詰め物と bool/char の不正な表現を、元の関数へ渡す前に拒否する。
    pub(super) fn validate(
        &self,
        f: &mut Function,
        base: u32,
        start: u32,
        fail: u32,
    ) -> Result<(), LayoutError> {
        use Instruction::*;
        let mut end = 0;
        for &(position, size) in &self.occupied {
            for offset in end..position {
                f.instruction(&LocalGet(base));
                f.instruction(&I32Load8U(mem(
                    start.checked_add(offset).ok_or(LayoutError::Memory32)?,
                    0,
                )));
                super::emit::fail_if(f, super::runtime::FailureCode::Format, 0, 0, fail);
            }
            end = position.checked_add(size).ok_or(LayoutError::Memory32)?;
        }
        for leaf in &self.leaves {
            leaf.validate(f, base, start, fail)?;
        }
        for offset in end..self.size {
            f.instruction(&LocalGet(base));
            f.instruction(&I32Load8U(mem(
                start.checked_add(offset).ok_or(LayoutError::Memory32)?,
                0,
            )));
            super::emit::fail_if(f, super::runtime::FailureCode::Format, 0, 0, fail);
        }
        Ok(())
    }
}

impl FixedValues {
    /// 参照先全体の検査と計数を終えてから、正準 ABI または転送形式の領域を確保する。
    pub(super) fn measure(
        &self,
        f: &mut Function,
        root: u32,
        start: u32,
        input: bool,
    ) -> Result<(), LayoutError> {
        use Instruction::*;
        if input {
            // 根の既存の形式の検査は、構築量の検査より先に行う。
            self.root.validate(f, root, start, 3)?;
        }
        let fixed_end = super::wire::HEADER_SIZE
            .checked_add(self.root.size)
            .ok_or(LayoutError::Memory32)?;
        ops(
            f,
            &[
                I32Const(fixed_end as i32),
                LocalSet(CURSOR),
                I64Const(self.root.construction as i64),
                LocalSet(COST),
            ],
        );
        check_budget(
            f,
            COST,
            if input {
                FailureCode::ArgumentConstruction
            } else {
                FailureCode::ResultConstruction
            },
        );
        self.walk(f, root, start, None, Mode::Measure(input))?;
        if input {
            ops(f, &[LocalGet(CURSOR), LocalGet(1), I32Ne]);
            super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
        }
        Ok(())
    }

    /// 検査済みの固定部を予約し、子の相対位置を独立した正準 ABI の位置へ直す。
    pub(super) fn absolute_params(&self, f: &mut Function) -> Result<(), LayoutError> {
        self.walk(f, PARAMS, 0, Some((PARAMS, 0)), Mode::Params)
    }

    /// 固定部を先に予約してから、子の参照先を宣言順に詰め直す。
    pub(super) fn copy_results(&self, f: &mut Function) -> Result<(), LayoutError> {
        use Instruction::*;
        let start = super::wire::HEADER_SIZE;
        let fixed_end = start
            .checked_add(self.root.size)
            .ok_or(LayoutError::Memory32)?;
        ops(f, &[I32Const(fixed_end as i32), LocalSet(CURSOR)]);
        self.walk(f, RESULTS, 0, Some((OUTPUT, start)), Mode::Results)
    }

    fn walk(
        &self,
        f: &mut Function,
        root: u32,
        start: u32,
        destination: Option<(u32, u32)>,
        mode: Mode,
    ) -> Result<(), LayoutError> {
        use Instruction::*;
        let mut work = vec![Walk::Enter(&self.root, 0)];
        ops(
            f,
            &[
                LocalGet(root),
                I32Const(start as i32),
                I32Add,
                LocalSet(frame(0, 0)?),
            ],
        );
        if let Some((base, offset)) = destination {
            ops(
                f,
                &[
                    LocalGet(base),
                    I32Const(offset as i32),
                    I32Add,
                    LocalSet(frame(0, 1)?),
                ],
            );
        }
        while let Some(task) = work.pop() {
            match task {
                Walk::Enter(scan, depth) => {
                    match mode {
                        Mode::Measure(true) => {
                            if depth != 0 {
                                scan.validate(f, frame(depth, 0)?, 0, 3)?;
                            }
                        }
                        Mode::Measure(false) => {
                            for leaf in &scan.leaves {
                                leaf.validate(f, frame(depth, 0)?, 0, 3)?;
                            }
                        }
                        Mode::Params | Mode::Results => {
                            for leaf in &scan.leaves {
                                f.instruction(&LocalGet(frame(depth, 1)?));
                                leaf.load(f, frame(depth, 0)?, 0)?;
                                leaf.store(f, 0)?;
                            }
                        }
                    }
                    work.push(Walk::Actions(scan, 0, depth));
                }
                Walk::Actions(scan, index, depth) => {
                    let Some(action) = scan.actions.get(index) else {
                        continue;
                    };
                    work.push(Walk::Actions(scan, index.saturating_add(1), depth));
                    match *action {
                        Action::Reference(index) => {
                            let reference = scan
                                .references
                                .get(index)
                                .ok_or(LayoutError::Internal("reference action is missing"))?;
                            work.push(Walk::Reference(reference, depth));
                        }
                        Action::Flags(index, item_bytes) => {
                            if let Mode::Measure(input) = mode {
                                let leaf = scan
                                    .leaves
                                    .get(index)
                                    .ok_or(LayoutError::Internal("flags leaf is missing"))?;
                                leaf.load(f, frame(depth, 0)?, 0)?;
                                ops(
                                    f,
                                    &[
                                        I32Popcnt,
                                        I64ExtendI32U,
                                        I64Const(item_bytes as i64),
                                        I64Mul,
                                        LocalSet(END),
                                    ],
                                );
                                charge_measured_cost(f, input);
                            }
                        }
                        Action::Variant(index) => {
                            let variant = scan
                                .variants
                                .get(index)
                                .ok_or(LayoutError::Internal("variant action is missing"))?;
                            work.push(Walk::Case(variant, 0, depth));
                        }
                    }
                }
                Walk::Case(variant, index, depth) => {
                    let Some(child) = variant.cases.get(index) else {
                        continue;
                    };
                    work.push(Walk::Case(variant, index.saturating_add(1), depth));
                    let child = child
                        .map(|id| {
                            self.scans
                                .get(id)
                                .ok_or(LayoutError::Internal("variant scan is missing"))
                        })
                        .transpose()?;
                    variant.discriminant.load(f, frame(depth, 0)?, 0)?;
                    ops(
                        f,
                        &[
                            I32Const(
                                u32::try_from(index).map_err(|_| LayoutError::Memory32)? as i32
                            ),
                            I32Eq,
                            If(BlockType::Empty),
                        ],
                    );
                    let payload = variant
                        .discriminant
                        .offset
                        .checked_add(variant.payload_offset)
                        .ok_or(LayoutError::Memory32)?;
                    if let Mode::Measure(input) = mode {
                        let cost = child
                            .map_or(0, |s| s.construction)
                            .checked_add(variant.case_bytes.get(index).copied().unwrap_or(0))
                            .ok_or(LayoutError::Memory32)?;
                        charge_cost(f, cost, input);
                        if input {
                            let end = variant
                                .discriminant
                                .offset
                                .checked_add(variant.size)
                                .ok_or(LayoutError::Memory32)?;
                            let used = payload
                                .checked_add(child.map_or(0, |s| s.size))
                                .ok_or(LayoutError::Memory32)?;
                            zero_range(
                                f,
                                frame(depth, 0)?,
                                variant
                                    .discriminant
                                    .offset
                                    .checked_add(variant.discriminant.size)
                                    .ok_or(LayoutError::Memory32)?
                                    ..payload,
                            );
                            zero_range(f, frame(depth, 0)?, used..end);
                        }
                    }
                    if let Some(child) = child {
                        let next = depth.checked_add(1).ok_or(LayoutError::Memory32)?;
                        ops(
                            f,
                            &[
                                LocalGet(frame(depth, 0)?),
                                I32Const(payload as i32),
                                I32Add,
                                LocalSet(frame(next, 0)?),
                            ],
                        );
                        if !matches!(mode, Mode::Measure(_)) {
                            ops(
                                f,
                                &[
                                    LocalGet(frame(depth, 1)?),
                                    I32Const(payload as i32),
                                    I32Add,
                                    LocalSet(frame(next, 1)?),
                                ],
                            );
                        }
                        work.push(Walk::EndCase);
                        work.push(Walk::Enter(child, next));
                    } else {
                        ops(f, &[End]);
                    }
                }
                Walk::EndCase => {
                    ops(f, &[End]);
                }
                Walk::Reference(reference, depth) => {
                    let child = reference
                        .child
                        .map(|id| {
                            self.scans
                                .get(id)
                                .ok_or(LayoutError::Internal("list scan is missing"))
                        })
                        .transpose()?;
                    match mode {
                        Mode::Measure(input) => reference.measure(
                            f,
                            frame(depth, 0)?,
                            input,
                            child.map_or(1, |s| s.construction),
                        )?,
                        Mode::Params | Mode::Results => reference.copy_start(f, depth, mode)?,
                    }
                    if let Some(child) = child {
                        loop_begin(f);
                        // 親のループの状態を深さごとの局所変数に保存し、子の検査やコピーと分ける。
                        save_frame(f, depth, false)?;
                        element_pointer(
                            f,
                            SOURCE,
                            reference.element.size,
                            frame(depth.saturating_add(1), 0)?,
                        );
                        if !matches!(mode, Mode::Measure(_)) {
                            if matches!(mode, Mode::Results) {
                                ops(
                                    f,
                                    &[LocalGet(OUTPUT), LocalGet(DEST), I32Add, LocalSet(DEST)],
                                );
                            }
                            element_pointer(
                                f,
                                DEST,
                                reference.element.size,
                                frame(depth.saturating_add(1), 1)?,
                            );
                        }
                        work.push(Walk::LoopEnd(depth));
                        work.push(Walk::Enter(child, depth.saturating_add(1)));
                    } else {
                        match mode {
                            // 結果の UTF-8 は元ゲストの canon lift が検査済みであり、
                            // ホストの復号でも検査する。補助では入力の形式だけを検査する。
                            Mode::Measure(true) if reference.string => validate_utf8(f),
                            Mode::Measure(_) => {}
                            Mode::Params | Mode::Results => reference.copy(
                                f,
                                if matches!(mode, Mode::Results) {
                                    Some(OUTPUT)
                                } else {
                                    None
                                },
                            )?,
                        }
                        ops(f, &[End]);
                    }
                }
                Walk::LoopEnd(depth) => {
                    save_frame(f, depth, true)?;
                    loop_end(f);
                    ops(f, &[End]);
                }
            }
        }
        Ok(())
    }
}

#[derive(Clone, Copy)]
enum Mode {
    Measure(bool),
    Params,
    Results,
}

enum Walk<'a> {
    Enter(&'a Scan, u32),
    Actions(&'a Scan, usize, u32),
    Reference(&'a Reference, u32),
    Case(&'a Variant, usize, u32),
    EndCase,
    LoopEnd(u32),
}

fn zero_range(f: &mut Function, base: u32, range: std::ops::Range<u32>) {
    use Instruction::*;
    for offset in range {
        ops(f, &[LocalGet(base), I32Load8U(mem(offset, 0))]);
        super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
    }
}

fn charge_cost(f: &mut Function, cost: u64, input: bool) {
    use Instruction::*;
    // 現在の費用は既に上限以内なので、残量と比べてから加算する。
    ops(
        f,
        &[
            I64Const(cost as i64),
            LocalGet(LIMIT),
            LocalGet(COST),
            I64Sub,
            I64GtU,
        ],
    );
    reject_local(
        f,
        if input {
            FailureCode::ArgumentConstruction
        } else {
            FailureCode::ResultConstruction
        },
        &[LocalGet(COST), I64Const(cost as i64), I64Add],
        &[LocalGet(LIMIT)],
    );
    ops(
        f,
        &[
            LocalGet(COST),
            I64Const(cost as i64),
            I64Add,
            LocalSet(COST),
        ],
    );
}

// END の費用を残量と比べ、構築前の計数を両方向で揃える。
fn charge_measured_cost(f: &mut Function, input: bool) {
    use Instruction::*;
    ops(
        f,
        &[
            LocalGet(END),
            LocalGet(LIMIT),
            LocalGet(COST),
            I64Sub,
            I64GtU,
        ],
    );
    reject_local(
        f,
        if input {
            FailureCode::ArgumentConstruction
        } else {
            FailureCode::ResultConstruction
        },
        &[LocalGet(COST), LocalGet(END), I64Add],
        &[LocalGet(LIMIT)],
    );
    ops(f, &[LocalGet(COST), LocalGet(END), I64Add, LocalSet(COST)]);
}

const FRAME_SIZE: u32 = 7;

fn frame(depth: u32, slot: u32) -> Result<u32, LayoutError> {
    depth
        .checked_mul(FRAME_SIZE)
        .and_then(|n| n.checked_add(slot))
        .and_then(|n| n.checked_add(21))
        .ok_or(LayoutError::Memory32)
}

fn save_frame(f: &mut Function, depth: u32, restore: bool) -> Result<(), LayoutError> {
    use Instruction::*;
    for (slot, local) in (2..FRAME_SIZE).zip([SOURCE, COUNT, INDEX, DEST, BYTES]) {
        let saved = frame(depth, slot)?;
        let (from, to) = if restore {
            (saved, local)
        } else {
            (local, saved)
        };
        ops(f, &[LocalGet(from), LocalSet(to)]);
    }
    Ok(())
}

fn element_pointer(f: &mut Function, base: u32, size: u32, target: u32) {
    use Instruction::*;
    ops(
        f,
        &[
            LocalGet(base),
            LocalGet(INDEX),
            I32Const(size as i32),
            I32Mul,
            I32Add,
            LocalSet(target),
        ],
    );
}

impl Reference {
    fn measure(
        &self,
        f: &mut Function,
        root: u32,
        input: bool,
        construction: u64,
    ) -> Result<(), LayoutError> {
        use Instruction::*;
        self.read(f, root, 0)?;
        // 長さの上限を先に検査し、積と総量の加算を i64 で求める。
        if !self.map {
            let maximum = if self.list {
                crate::runtime::MAX_LIST_LEN
            } else {
                crate::runtime::MAX_STRING_BYTES
            };
            let maximum32 = u32::try_from(maximum).map_err(|_| LayoutError::Memory32)?;
            ops(f, &[LocalGet(COUNT), I32Const(maximum32 as i32), I32GtU]);
            reject_local(
                f,
                FailureCode::ValueSize,
                &[LocalGet(COUNT), I64ExtendI32U],
                &[I64Const(maximum as i64)],
            );
        }
        // 重複した鍵を縮める前の全要素を数える。積は memory32 の個数と型の費用から求める。
        ops(
            f,
            &[
                LocalGet(COUNT),
                I64ExtendI32U,
                I64Const(construction as i64),
                I64Mul,
                LocalSet(END),
            ],
        );
        charge_measured_cost(f, input);
        ops(
            f,
            &[
                LocalGet(COUNT),
                I64ExtendI32U,
                I64Const(i64::from(self.element.size)),
                I64Mul,
                LocalSet(END),
            ],
        );
        check_memory32(
            f,
            if input {
                FailureCode::ArgumentTransfer
            } else {
                FailureCode::ResultTransfer
            },
        );
        ops(
            f,
            &[
                LocalGet(END),
                I32WrapI64,
                LocalSet(BYTES),
                LocalGet(COUNT),
                I32Eqz,
                If(BlockType::Empty),
            ],
        );
        if input {
            ops(f, &[LocalGet(SOURCE)]);
            super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
        }
        ops(f, &[Else]);
        self.align(f);
        if input {
            ops(f, &[LocalGet(SOURCE), LocalGet(DEST), I32Ne]);
            super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
        }
        ops(
            f,
            &[
                LocalGet(DEST),
                I64ExtendI32U,
                LocalGet(BYTES),
                I64ExtendI32U,
                I64Add,
                LocalSet(END),
            ],
        );
        check_memory32(
            f,
            if input {
                FailureCode::ArgumentTransfer
            } else {
                FailureCode::ResultTransfer
            },
        );
        check_budget(
            f,
            END,
            if input {
                FailureCode::ArgumentTransfer
            } else {
                FailureCode::ResultTransfer
            },
        );
        if input {
            ops(f, &[LocalGet(END), LocalGet(1), I64ExtendI32U, I64GtU]);
            super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
            // 整列の詰め物も形式の一部であり、読み飛ばしてよい領域ではない。
            ops(
                f,
                &[
                    LocalGet(CURSOR),
                    LocalSet(PADDING),
                    Block(BlockType::Empty),
                    Loop(BlockType::Empty),
                    LocalGet(PADDING),
                    LocalGet(DEST),
                    I32GeU,
                    BrIf(1),
                    LocalGet(0),
                    LocalGet(PADDING),
                    I32Add,
                    I32Load8U(mem(0, 0)),
                ],
            );
            super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
            ops(
                f,
                &[
                    LocalGet(PADDING),
                    I32Const(1),
                    I32Add,
                    LocalSet(PADDING),
                    Br(0),
                    End,
                    End,
                    LocalGet(0),
                    LocalGet(SOURCE),
                    I32Add,
                    LocalSet(SOURCE),
                ],
            );
        }
        // 絶対位置も共通の範囲検査を通し、メモリの trap に形式の不一致を任せない。
        ops(
            f,
            &[
                LocalGet(SOURCE),
                LocalGet(BYTES),
                I32Const(self.element.alignment as i32),
                Call(4),
            ],
        );
        ops(f, &[LocalGet(END), I32WrapI64, LocalSet(CURSOR)]);
        Ok(())
    }

    fn copy_start(&self, f: &mut Function, depth: u32, mode: Mode) -> Result<(), LayoutError> {
        use Instruction::*;
        let source = frame(depth, 0)?;
        let destination = frame(depth, 1)?;
        self.read(f, source, 0)?;
        ops(
            f,
            &[
                LocalGet(destination),
                LocalGet(COUNT),
                I32Store(mem(
                    self.offset.checked_add(4).ok_or(LayoutError::Memory32)?,
                    2,
                )),
                LocalGet(COUNT),
                I32Eqz,
                If(BlockType::Empty),
                LocalGet(destination),
                I32Const(0),
                I32Store(mem(self.offset, 2)),
                Else,
                LocalGet(COUNT),
                I32Const(self.element.size as i32),
                I32Mul,
                LocalSet(BYTES),
            ],
        );
        if matches!(mode, Mode::Params) {
            super::emit::allocate_local(f, BYTES, DEST);
            ops(
                f,
                &[
                    LocalGet(DEST),
                    I32Const(0),
                    LocalGet(BYTES),
                    MemoryFill(0),
                    LocalGet(0),
                    LocalGet(SOURCE),
                    I32Add,
                    LocalSet(SOURCE),
                ],
            );
        } else {
            self.align(f);
            // 子の固定部全体を先に予約する。子の可変長の内容はその後へ続ける。
            ops(
                f,
                &[LocalGet(DEST), LocalGet(BYTES), I32Add, LocalSet(CURSOR)],
            );
        }
        ops(
            f,
            &[
                LocalGet(destination),
                LocalGet(DEST),
                I32Store(mem(self.offset, 2)),
            ],
        );
        Ok(())
    }

    fn read(&self, f: &mut Function, root: u32, start: u32) -> Result<(), LayoutError> {
        use Instruction::*;
        let offset = start
            .checked_add(self.offset)
            .ok_or(LayoutError::Memory32)?;
        let length = offset.checked_add(4).ok_or(LayoutError::Memory32)?;
        ops(
            f,
            &[
                LocalGet(root),
                I32Load(mem(offset, 2)),
                LocalSet(SOURCE),
                LocalGet(root),
                I32Load(mem(length, 2)),
                LocalSet(COUNT),
            ],
        );
        Ok(())
    }

    fn copy(&self, f: &mut Function, destination_base: Option<u32>) -> Result<(), LayoutError> {
        use Instruction::*;
        if let Some(base) = destination_base {
            f.instruction(&LocalGet(base));
        }
        f.instruction(&LocalGet(DEST));
        if destination_base.is_some() {
            f.instruction(&I32Add);
        }
        // 文字列と Bytes は検査済みの連続領域である。バイトごとのループで
        // 利用者の燃料を消費せず、入れ子の親の走査状態も変更しない。
        ops(
            f,
            &[
                LocalGet(SOURCE),
                LocalGet(BYTES),
                MemoryCopy {
                    src_mem: 0,
                    dst_mem: 0,
                },
            ],
        );
        Ok(())
    }

    fn align(&self, f: &mut Function) {
        use Instruction::*;
        let mask = i64::from(self.element.alignment.saturating_sub(1));
        ops(
            f,
            &[
                LocalGet(CURSOR),
                I64ExtendI32U,
                I64Const(mask),
                I64Add,
                I64Const(!mask),
                I64And,
                LocalSet(END),
            ],
        );
        check_memory32(f, FailureCode::Format);
        ops(f, &[LocalGet(END), I32WrapI64, LocalSet(DEST)]);
    }
}

fn reject_local(
    f: &mut Function,
    code: FailureCode,
    requested: &[Instruction<'_>],
    limit: &[Instruction<'_>],
) {
    use Instruction::*;
    ops(f, &[If(BlockType::Empty), I32Const(code as i32)]);
    ops(f, requested);
    ops(f, limit);
    ops(f, &[Call(3), Unreachable, End]);
}

fn check_memory32(f: &mut Function, code: FailureCode) {
    use Instruction::*;
    ops(f, &[LocalGet(END), I64Const(i64::from(u32::MAX)), I64GtU]);
    reject_local(f, code, &[LocalGet(END)], &[I64Const(i64::from(u32::MAX))]);
}

/// 指定した局所変数の要求量を、ホストと一致する予算で検査する。
pub(super) fn check_budget(f: &mut Function, requested: u32, code: FailureCode) {
    use Instruction::*;
    ops(f, &[LocalGet(requested), LocalGet(LIMIT), I64GtU]);
    reject_local(f, code, &[LocalGet(requested)], &[LocalGet(LIMIT)]);
}

fn loop_begin(f: &mut Function) {
    use Instruction::*;
    ops(
        f,
        &[
            I32Const(0),
            LocalSet(INDEX),
            Block(BlockType::Empty),
            Loop(BlockType::Empty),
            LocalGet(INDEX),
            LocalGet(COUNT),
            I32GeU,
            BrIf(1),
        ],
    );
}

fn loop_end(f: &mut Function) {
    use Instruction::*;
    ops(
        f,
        &[
            LocalGet(INDEX),
            I32Const(1),
            I32Add,
            LocalSet(INDEX),
            Br(0),
            End,
            End,
        ],
    );
}

// 正準 ABI へ渡す前に UTF-8 の最短表現・スカラー値・末尾までの完結を調べる。
fn validate_utf8(f: &mut Function) {
    use Instruction::*;
    ops(f, &[I32Const(0), LocalSet(REMAIN)]);
    loop_begin(f);
    ops(
        f,
        &[
            LocalGet(SOURCE),
            LocalGet(INDEX),
            I32Add,
            I32Load8U(mem(0, 0)),
            LocalSet(BYTE),
            LocalGet(REMAIN),
            I32Eqz,
            If(BlockType::Empty),
            LocalGet(BYTE),
            I32Const(0x80),
            I32GeU,
            If(BlockType::Empty),
        ],
    );
    // 先頭バイトの範囲を三つに分け、過長表現を拒否する最小値を残す。
    for (low, high, remain, mask, minimum) in [
        (0xc2, 0xdf, 1, 0x1f, 0x80),
        (0xe0, 0xef, 2, 0x0f, 0x800),
        (0xf0, 0xf4, 3, 0x07, 0x10000),
    ] {
        ops(
            f,
            &[
                LocalGet(BYTE),
                I32Const(low),
                I32GeU,
                LocalGet(BYTE),
                I32Const(high),
                I32LeU,
                I32And,
                If(BlockType::Empty),
                I32Const(remain),
                LocalSet(REMAIN),
                LocalGet(BYTE),
                I32Const(mask),
                I32And,
                LocalSet(CODEPOINT),
                I32Const(minimum),
                LocalSet(MINIMUM),
                Else,
            ],
        );
    }
    ops(f, &[I32Const(1)]);
    super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
    ops(
        f,
        &[
            End,
            End,
            End,
            End,
            Else,
            LocalGet(BYTE),
            I32Const(0x80),
            I32LtU,
            LocalGet(BYTE),
            I32Const(0xbf),
            I32GtU,
            I32Or,
        ],
    );
    super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
    ops(
        f,
        &[
            LocalGet(CODEPOINT),
            I32Const(6),
            I32Shl,
            LocalGet(BYTE),
            I32Const(0x3f),
            I32And,
            I32Or,
            LocalSet(CODEPOINT),
            LocalGet(REMAIN),
            I32Const(1),
            I32Sub,
            LocalTee(REMAIN),
            I32Eqz,
            If(BlockType::Empty),
            LocalGet(CODEPOINT),
            LocalGet(MINIMUM),
            I32LtU,
            LocalGet(CODEPOINT),
            I32Const(0x10ffff),
            I32GtU,
            I32Or,
            LocalGet(CODEPOINT),
            I32Const(0xd800),
            I32GeU,
            LocalGet(CODEPOINT),
            I32Const(0xdfff),
            I32LeU,
            I32And,
            I32Or,
        ],
    );
    super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
    ops(f, &[End, End]);
    loop_end(f);
    ops(f, &[LocalGet(REMAIN)]);
    super::emit::fail_if(f, FailureCode::Format, 0, 0, 3);
}

/// memory32 の位置と二の冪の整列を命令の引数へ変換する。
pub(super) fn mem(offset: u32, align: u32) -> MemArg {
    MemArg {
        offset: u64::from(offset),
        align,
        memory_index: 0,
    }
}

impl Leaf {
    fn validate(
        &self,
        f: &mut Function,
        base: u32,
        start: u32,
        fail: u32,
    ) -> Result<(), LayoutError> {
        use Instruction::*;
        if let Some(mask) = self.flags_mask {
            self.load(f, base, start)?;
            ops(f, &[I32Const(!mask as i32), I32And]);
            super::emit::fail_if(f, FailureCode::Format, 0, u64::from(mask), fail);
        }
        if let Some(cases) = self.cases {
            self.load(f, base, start)?;
            f.instruction(&I32Const(cases as i32));
            f.instruction(&I32GeU);
            super::emit::fail_if(f, FailureCode::Format, 0, u64::from(cases), fail);
        }
        if self.boolean {
            self.load(f, base, start)?;
            f.instruction(&I32Const(1));
            f.instruction(&I32GtU);
            super::emit::fail_if(f, super::runtime::FailureCode::Format, 0, 1, fail);
        }
        if self.character {
            self.load(f, base, start)?;
            f.instruction(&I32Const(0x10ffff));
            f.instruction(&I32GtU);
            self.load(f, base, start)?;
            f.instruction(&I32Const(0xd800));
            f.instruction(&I32GeU);
            self.load(f, base, start)?;
            f.instruction(&I32Const(0xdfff));
            f.instruction(&I32LeU);
            f.instruction(&I32And);
            f.instruction(&I32Or);
            super::emit::fail_if(f, super::runtime::FailureCode::Format, 0, 0x10ffff, fail);
        }
        Ok(())
    }

    /// 幅と符号に従い、メモリから平らなコア値を積む。
    pub(super) fn load(&self, f: &mut Function, base: u32, start: u32) -> Result<(), LayoutError> {
        use Instruction::*;
        let arg = mem(
            start
                .checked_add(self.offset)
                .ok_or(LayoutError::Memory32)?,
            self.size.trailing_zeros(),
        );
        let op = match (self.core, self.size, self.signed) {
            (CoreType::I32, 1, true) => I32Load8S(arg),
            (CoreType::I32, 1, false) => I32Load8U(arg),
            (CoreType::I32, 2, true) => I32Load16S(arg),
            (CoreType::I32, 2, false) => I32Load16U(arg),
            (CoreType::I32, 4, _) => I32Load(arg),
            (CoreType::I64, 8, _) => I64Load(arg),
            (CoreType::F32, 4, _) => F32Load(arg),
            (CoreType::F64, 8, _) => F64Load(arg),
            _ => return Err(LayoutError::Internal("invalid fixed scalar load")),
        };
        f.instruction(&LocalGet(base));
        f.instruction(&op);
        Ok(())
    }

    /// 積まれた位置とコア値を、元の幅のビットのまま保存する。
    pub(super) fn store(&self, f: &mut Function, start: u32) -> Result<(), LayoutError> {
        use Instruction::*;
        let arg = mem(
            start
                .checked_add(self.offset)
                .ok_or(LayoutError::Memory32)?,
            self.size.trailing_zeros(),
        );
        let op = match (self.core, self.size) {
            (CoreType::I32, 1) => I32Store8(arg),
            (CoreType::I32, 2) => I32Store16(arg),
            (CoreType::I32, 4) => I32Store(arg),
            (CoreType::I64, 8) => I64Store(arg),
            (CoreType::F32, 4) => F32Store(arg),
            (CoreType::F64, 8) => F64Store(arg),
            _ => return Err(LayoutError::Internal("invalid fixed scalar store")),
        };
        f.instruction(&op);
        Ok(())
    }
}

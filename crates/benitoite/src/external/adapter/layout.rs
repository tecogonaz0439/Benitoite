//! 補助コードとホストが共用する memory32 の配置を求める（設計書 03-10「型の対応」）。
//! 型の木は明示の作業列で辿り、子の配置を平らな表に保存する。

use super::super::{WitPlan, expansion};
use super::emit::{CoreSignature, CoreType};

/// 型の予算・配置の表現上限と、補助の対象外・表の不整合を区別する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum LayoutError {
    TypeBudget,
    GenerationBudget,
    Memory32,
    Resource,
    Internal(&'static str),
}

/// 固定部のバイト数と整列。大きさには末尾の詰め物も含む。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct MemoryLayout {
    pub size: u32,
    pub alignment: u32,
}

impl MemoryLayout {
    /// 配列の次の要素までの距離。
    pub(crate) fn stride(self) -> Result<u32, LayoutError> {
        align_to(self.size, self.alignment)
    }

    /// 可変長の参照先の固定部を確保する前に、memory32 に収まるか調べる。
    pub(crate) fn array_size(self, count: u32) -> Result<u32, LayoutError> {
        self.stride()?
            .checked_mul(count)
            .ok_or(LayoutError::Memory32)
    }
}

/// 欄の位置と、平らな表に保存した子の番号。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct FieldLayout {
    pub offset: u32,
    pub node: usize,
}

/// 根・レコード・組・map の組に共通の、宣言順の配置。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct RecordLayout {
    pub memory: MemoryLayout,
    pub fields: Vec<FieldLayout>,
    pub flat: Vec<CoreType>,
}

/// 固定部から子や参照先へ進むための情報。名前とタグは WitPlan に残す。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum LayoutKind {
    Scalar,
    String,
    Bytes,
    List {
        element: usize,
    },
    Map {
        entry: RecordLayout,
    },
    Record {
        fields: Vec<FieldLayout>,
    },
    Variant {
        discriminant_size: u32,
        payload_offset: u32,
        cases: Vec<Option<usize>>,
    },
    Enum {
        discriminant_size: u32,
    },
    Flags,
}

/// 一つの WIT の型の固定部と、子の配置への参照。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TypeLayout {
    pub memory: MemoryLayout,
    pub kind: LayoutKind,
    pub flat: Vec<CoreType>,
}

/// 同期・memory32 の呼び出し表。lift と lower で間接の結果の向きが異なる。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct FunctionAbi {
    pub lift: CoreSignature,
    pub lower: CoreSignature,
    pub indirect_params: bool,
    pub indirect_results: bool,
}

impl FunctionAbi {
    /// 引数全体と、省略または一つの結果からコアの呼び出し型を求める。
    pub(crate) fn new(params: &LayoutTable, results: &LayoutTable) -> Result<Self, LayoutError> {
        if results.roots.fields.len() > 1 {
            return Err(LayoutError::Internal(
                "a WIT function has more than one result",
            ));
        }
        let indirect_params = params.roots.flat.len() > 16;
        let indirect_results = results.roots.flat.len() > 1;
        let params = if indirect_params {
            vec![CoreType::I32]
        } else {
            params.roots.flat.clone()
        };
        let lift = CoreSignature {
            params: params.clone(),
            results: if indirect_results {
                vec![CoreType::I32]
            } else {
                results.roots.flat.clone()
            },
        };
        let mut lower = CoreSignature {
            params,
            results: results.roots.flat.clone(),
        };
        if indirect_results {
            // 追加の結果領域は元の引数の上限判定の後に足す。16 引数なら合計 17 個になる。
            lower.params.push(CoreType::I32);
            lower.results.clear();
        }
        Ok(Self {
            lift,
            lower,
            indirect_params,
            indirect_results,
        })
    }
}

/// 型の各出現の配置。子の木を複製せず、深い表もループで扱える。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct LayoutTable {
    pub nodes: Vec<TypeLayout>,
    pub roots: RecordLayout,
}

enum Work<'a> {
    Enter(&'a WitPlan, u32),
    Leave(&'a WitPlan, usize),
}

impl LayoutTable {
    /// 照合済みの根から配置を求める。total は照合全体の残りの型予算である。
    pub(crate) fn new(plans: &[WitPlan], total: &mut usize) -> Result<Self, LayoutError> {
        let mut nodes = Vec::new();
        let mut roots = Vec::new();
        for plan in plans {
            let mut remaining = expansion::MAX_NODES;
            charge(1, &mut remaining, total)?;
            let mut work = vec![Work::Enter(plan, 1)];
            let mut results = Vec::new();
            while let Some(item) = work.pop() {
                match item {
                    Work::Enter(plan, depth) => {
                        // 予約時に予算を引くことで、多数の兄弟を作業列へ積む前に止める。
                        // ペイロードのない場合も表の一項目なので、走査する前に数える。
                        let occurrences = if let WitPlan::Variant { cases } = plan {
                            cases.len()
                        } else if let WitPlan::Enum { cases } | WitPlan::Flags { cases } = plan {
                            cases.len()
                        } else {
                            child_count(plan)
                        };
                        charge(occurrences, &mut remaining, total)?;
                        let count = child_count(plan);
                        if count != 0 && depth >= expansion::MAX_DEPTH {
                            return Err(LayoutError::TypeBudget);
                        }
                        work.push(Work::Leave(plan, count));
                        push_children(plan, depth.saturating_add(1), &mut work);
                    }
                    Work::Leave(plan, count) => {
                        let start = results
                            .len()
                            .checked_sub(count)
                            .ok_or(LayoutError::Internal("layout child results are missing"))?;
                        let children = results.split_off(start);
                        let layout = build(plan, &children, &nodes)?;
                        let id = nodes.len();
                        nodes.push(layout);
                        results.push(id);
                    }
                }
            }
            if results.len() != 1 {
                return Err(LayoutError::Internal("layout root result is missing"));
            }
            roots.push(
                results
                    .pop()
                    .ok_or(LayoutError::Internal("layout root result is missing"))?,
            );
        }
        let roots = record(&roots, &nodes)?;
        Ok(Self { nodes, roots })
    }
}

fn charge(count: usize, remaining: &mut usize, total: &mut usize) -> Result<(), LayoutError> {
    if count > *remaining || count > *total {
        return Err(LayoutError::TypeBudget);
    }
    *remaining = remaining.saturating_sub(count);
    *total = total.saturating_sub(count);
    Ok(())
}

fn child_count(plan: &WitPlan) -> usize {
    match plan {
        WitPlan::List(_) | WitPlan::Option(_) => 1,
        WitPlan::Map(_, _) => 2,
        WitPlan::Result { ok, err } => {
            usize::from(ok.is_some()).saturating_add(usize::from(err.is_some()))
        }
        WitPlan::Tuple(fields)
        | WitPlan::TupleFields(fields)
        | WitPlan::ConstructorTuple { fields, .. } => fields.len(),
        WitPlan::Record { fields } => fields.len(),
        WitPlan::Variant { cases } => cases.iter().filter(|(_, _, p)| p.is_some()).count(),
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
        | WitPlan::Borrow(_)
        | WitPlan::Own(_)
        | WitPlan::Enum { .. }
        | WitPlan::Flags { .. } => 0,
    }
}

fn push_children<'a>(plan: &'a WitPlan, depth: u32, work: &mut Vec<Work<'a>>) {
    let mut push = |plan| work.push(Work::Enter(plan, depth));
    match plan {
        WitPlan::List(p) | WitPlan::Option(p) => push(p.as_ref()),
        WitPlan::Map(key, value) => {
            push(value.as_ref());
            push(key.as_ref());
        }
        WitPlan::Result { ok, err } => {
            for p in err.iter().chain(ok).map(Box::as_ref) {
                push(p);
            }
        }
        WitPlan::Tuple(fields)
        | WitPlan::TupleFields(fields)
        | WitPlan::ConstructorTuple { fields, .. } => {
            for p in fields.iter().rev() {
                push(p);
            }
        }
        WitPlan::Record { fields } => {
            for (_, p) in fields.iter().rev() {
                push(p);
            }
        }
        WitPlan::Variant { cases } => {
            for p in cases.iter().rev().filter_map(|(_, _, p)| p.as_deref()) {
                push(p);
            }
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
        | WitPlan::Borrow(_)
        | WitPlan::Own(_)
        | WitPlan::Enum { .. }
        | WitPlan::Flags { .. } => {}
    }
}

fn build(
    plan: &WitPlan,
    children: &[usize],
    nodes: &[TypeLayout],
) -> Result<TypeLayout, LayoutError> {
    let scalar = |size, flat| TypeLayout {
        memory: MemoryLayout {
            size,
            alignment: size,
        },
        kind: LayoutKind::Scalar,
        flat: vec![flat],
    };
    let reference = |kind| TypeLayout {
        memory: MemoryLayout {
            size: 8,
            alignment: 4,
        },
        kind,
        flat: vec![CoreType::I32, CoreType::I32],
    };
    Ok(match plan {
        WitPlan::S8 | WitPlan::U8 | WitPlan::Bool => scalar(1, CoreType::I32),
        WitPlan::S16 | WitPlan::U16 => scalar(2, CoreType::I32),
        WitPlan::S32 | WitPlan::U32 | WitPlan::Char => scalar(4, CoreType::I32),
        WitPlan::S64 | WitPlan::U64 => scalar(8, CoreType::I64),
        WitPlan::F32 => scalar(4, CoreType::F32),
        WitPlan::F64 => scalar(8, CoreType::F64),
        WitPlan::String => reference(LayoutKind::String),
        WitPlan::Bytes => reference(LayoutKind::Bytes),
        WitPlan::List(_) => reference(LayoutKind::List {
            element: *children
                .first()
                .ok_or(LayoutError::Internal("list element is missing"))?,
        }),
        WitPlan::Map(_, _) => reference(LayoutKind::Map {
            entry: record(children, nodes)?,
        }),
        WitPlan::Tuple(_)
        | WitPlan::TupleFields(_)
        | WitPlan::ConstructorTuple { .. }
        | WitPlan::Record { .. } => {
            let record = record(children, nodes)?;
            TypeLayout {
                memory: record.memory,
                kind: LayoutKind::Record {
                    fields: record.fields,
                },
                flat: record.flat,
            }
        }
        WitPlan::Enum { cases } => {
            let size = discriminant_size(cases.len())?;
            TypeLayout {
                memory: MemoryLayout {
                    size,
                    alignment: size,
                },
                kind: LayoutKind::Enum {
                    discriminant_size: size,
                },
                flat: vec![CoreType::I32],
            }
        }
        WitPlan::Flags { cases } => {
            let size = match cases.len() {
                1..=8 => 1,
                9..=16 => 2,
                17..=32 => 4,
                _ => {
                    return Err(LayoutError::Internal(
                        "flags count is outside the supported range",
                    ));
                }
            };
            TypeLayout {
                memory: MemoryLayout {
                    size,
                    alignment: size,
                },
                kind: LayoutKind::Flags,
                flat: vec![CoreType::I32],
            }
        }
        WitPlan::Option(_) => variant(
            vec![
                None,
                Some(
                    *children
                        .first()
                        .ok_or(LayoutError::Internal("option payload is missing"))?,
                ),
            ],
            nodes,
        )?,
        WitPlan::Result { ok, err } => {
            let mut children = children.iter().copied();
            variant(
                vec![
                    if ok.is_some() {
                        Some(
                            children
                                .next()
                                .ok_or(LayoutError::Internal("result payload is missing"))?,
                        )
                    } else {
                        None
                    },
                    if err.is_some() {
                        Some(
                            children
                                .next()
                                .ok_or(LayoutError::Internal("result payload is missing"))?,
                        )
                    } else {
                        None
                    },
                ],
                nodes,
            )?
        }
        WitPlan::Variant { cases } => {
            discriminant_size(cases.len())?;
            let mut children = children.iter().copied();
            let cases = cases
                .iter()
                .map(|(_, _, p)| {
                    p.as_ref()
                        .map(|_| {
                            children
                                .next()
                                .ok_or(LayoutError::Internal("variant payload is missing"))
                        })
                        .transpose()
                })
                .collect::<Result<Vec<_>, _>>()?;
            variant(cases, nodes)?
        }
        WitPlan::Borrow(_) | WitPlan::Own(_) => return Err(LayoutError::Resource),
    })
}

fn node(nodes: &[TypeLayout], id: usize) -> Result<&TypeLayout, LayoutError> {
    nodes
        .get(id)
        .ok_or(LayoutError::Internal("layout node is missing"))
}

fn record(children: &[usize], nodes: &[TypeLayout]) -> Result<RecordLayout, LayoutError> {
    let mut size: u32 = 0;
    let mut alignment = 1;
    let mut fields = Vec::with_capacity(children.len());
    let mut flat = Vec::new();
    for &id in children {
        let child = node(nodes, id)?;
        let memory = child.memory;
        flat.extend_from_slice(&child.flat);
        size = align_to(size, memory.alignment)?;
        fields.push(FieldLayout {
            offset: size,
            node: id,
        });
        size = size.checked_add(memory.size).ok_or(LayoutError::Memory32)?;
        alignment = alignment.max(memory.alignment);
    }
    Ok(RecordLayout {
        memory: MemoryLayout {
            size: align_to(size, alignment)?,
            alignment,
        },
        fields,
        flat,
    })
}

fn variant(cases: Vec<Option<usize>>, nodes: &[TypeLayout]) -> Result<TypeLayout, LayoutError> {
    let discriminant_size = discriminant_size(cases.len())?;
    let mut alignment = discriminant_size;
    let mut payload_size = 0;
    let mut payload_flat: Vec<CoreType> = Vec::new();
    for &id in cases.iter().flatten() {
        let child = node(nodes, id)?;
        let memory = child.memory;
        alignment = alignment.max(memory.alignment);
        payload_size = payload_size.max(memory.size);
        for (position, &ty) in child.flat.iter().enumerate() {
            if let Some(joined) = payload_flat.get_mut(position) {
                *joined = joined.join(ty);
            } else {
                payload_flat.push(ty);
            }
        }
    }
    let payload_offset = align_to(discriminant_size, alignment)?;
    let size = payload_offset
        .checked_add(payload_size)
        .ok_or(LayoutError::Memory32)?;
    let mut flat = vec![CoreType::I32];
    flat.extend(payload_flat);
    Ok(TypeLayout {
        memory: MemoryLayout {
            size: align_to(size, alignment)?,
            alignment,
        },
        kind: LayoutKind::Variant {
            discriminant_size,
            payload_offset,
            cases,
        },
        flat,
    })
}

fn discriminant_size(count: usize) -> Result<u32, LayoutError> {
    match count {
        0 => Err(LayoutError::Internal("a discriminated type has no cases")),
        1..=256 => Ok(1),
        257..=65_536 => Ok(2),
        _ => u32::try_from(count)
            .map(|_| 4)
            .map_err(|_| LayoutError::Memory32),
    }
}

fn align_to(offset: u32, alignment: u32) -> Result<u32, LayoutError> {
    if !alignment.is_power_of_two() || alignment > 8 {
        return Err(LayoutError::Internal("layout alignment is invalid"));
    }
    let mask = alignment.saturating_sub(1);
    offset
        .checked_add(mask)
        .map(|n| n & !mask)
        .ok_or(LayoutError::Memory32)
}

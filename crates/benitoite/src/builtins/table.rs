//! 組み込みの表（実装プラン 10-11「登録と第 1 段の扱い」、10-12）。初期化の後に変更しないので、
//! `const` か関数で表す（設計書 02-01「コンパイル済みプログラムと実行ごとの状態」）。

use super::BuiltinId;
use super::iface::BuiltinDecl;

use super::iface::{CallCtx, Capability, IoServices, Lend, Lent, Reply, StateServices, WorkerWait};
use crate::runtime::Stop;
use crate::runtime::heap::{NoGcCtx, Value};
use crate::vm::InstrRef;

/// VM と参照インタプリタが、同じ文脈で組み込みの関数の包みを呼ぶ。
/// `heap` は呼び出しの区間、`site` は呼んだ命令、`args` は引数の値の並びである。
/// IO と State の口は、その権限の関数を呼ぶときに必須である。第 1 段では `state` に `None` を渡す。
/// 完了・待つ・起動・終了の応答の処理は、呼び出し側が行う（設計書 02-08「組み込みの関数の呼び出し」）。
pub(crate) fn call_builtin<'e>(
    decl: &BuiltinDecl,
    heap: &mut NoGcCtx<'e>,
    io: Option<&mut dyn IoServices>,
    state: Option<&mut dyn StateServices>,
    site: Option<InstrRef>,
    args: &[Value<'e>],
) -> Result<Reply<'e>, Stop> {
    match decl.capability {
        Capability::Io if io.is_none() => {
            return Err(Stop::Internal(
                "io builtin called without io services".into(),
            ));
        }
        Capability::State if state.is_none() => {
            return Err(Stop::Internal(
                "state builtin called without state services".into(),
            ));
        }
        Capability::Pure | Capability::Io | Capability::State => {}
    }
    // 口の参照とトレイトオブジェクトの寿命を、局所の CallCtx を借りる間に縮める
    // （実装プラン 10-11「型と文脈」）。
    let io = io.map(|services| services as &mut dyn IoServices);
    let state = state.map(|services| services as &mut dyn StateServices);
    let mut call = CallCtx::new(heap, io, state, site);
    (decl.raw)(&mut call, args)
}

/// 第 1 段の VM と参照インタプリタが、待つ仕事をその場で実行して結果の値を作る。
/// `args` は待った関数の引数、`site` は呼んだ命令であり、完了の処理にも渡す。
/// リソースと標準入力の貸し出しは、第 2 段の共通の部分が扱うため、ここでは拒む
/// （実装プラン 10-11「登録と第 1 段の扱い」、設計書 02-09「タスクの待ちと取り消し」）。
pub(crate) fn complete_worker<'e>(
    wait: WorkerWait,
    heap: &mut NoGcCtx<'e>,
    io: &mut dyn IoServices,
    site: Option<InstrRef>,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    if wait.lend() != Lend::Nothing {
        return Err(Stop::Internal(
            "stage 1 worker cannot borrow resources or stdin".into(),
        ));
    }
    let done = wait.run(Lent::Nothing);
    let mut call = CallCtx::new(heap, Some(io), None, site);
    done.complete(&mut call.io_ctx()?, args)
}

/// 番号から登録の項目を引く。表にない番号なら `None`（VM は `Stop::Internal` にする）。
pub fn builtin_decl(id: BuiltinId) -> Option<&'static BuiltinDecl> {
    let mut index = usize::from(id.0);
    for part in super::funcs::PARTS {
        if index < part.len() {
            return part.get(index);
        }
        index = index.checked_sub(part.len())?;
    }
    None
}

/// 修飾した名前（`BuiltinDecl::name`。`String.byteLength`、`Benitoite.IO.Console.writeLine` など、
/// 10-12 が定める形）から番号を引く。表にない名前なら `None`。
pub fn lookup_builtin(name: &str) -> Option<BuiltinId> {
    let index = super::funcs::PARTS
        .iter()
        .flat_map(|part| part.iter())
        .position(|decl| decl.name == name)?;
    u16::try_from(index).ok().map(BuiltinId)
}

/// 標準ライブラリのソースで宣言した型の構成子のタグ（実装プラン 10-12「構成子のタグ」）。
/// 10-14 のソースの構成子の宣言の順であり、F06 のテストがソースと一致することを確かめる。
pub mod tags {
    /// `Option.Some`
    pub const OPTION_SOME: u32 = 0;
    /// `Option.None`
    pub const OPTION_NONE: u32 = 1;
    /// `Result.Ok`
    pub const RESULT_OK: u32 = 0;
    /// `Result.Error`
    pub const RESULT_ERROR: u32 = 1;
    /// `Pair`
    pub const PAIR: u32 = 0;
    /// `Triple`
    pub const TRIPLE: u32 = 0;
    /// `IOErrorKind` の構成子（01-09「IO の失敗の種類」の順）
    pub const IO_ERROR_KIND_NOT_FOUND: u32 = 0;
    pub const IO_ERROR_KIND_PERMISSION_DENIED: u32 = 1;
    pub const IO_ERROR_KIND_ALREADY_EXISTS: u32 = 2;
    pub const IO_ERROR_KIND_IS_DIRECTORY: u32 = 3;
    pub const IO_ERROR_KIND_NOT_DIRECTORY: u32 = 4;
    pub const IO_ERROR_KIND_DIRECTORY_NOT_EMPTY: u32 = 5;
    pub const IO_ERROR_KIND_INVALID_UTF8: u32 = 6;
    pub const IO_ERROR_KIND_INVALID_INPUT: u32 = 7;
    pub const IO_ERROR_KIND_OTHER: u32 = 8;
    /// `RoundingMode` の構成子（01-05「prelude が定める型」の順）
    pub const ROUNDING_MODE_HALF_TO_EVEN: u32 = 0;
    pub const ROUNDING_MODE_HALF_AWAY_FROM_ZERO: u32 = 1;
    pub const ROUNDING_MODE_TOWARD_ZERO: u32 = 2;
    pub const ROUNDING_MODE_TOWARD_NEGATIVE_INFINITY: u32 = 3;
    pub const ROUNDING_MODE_TOWARD_POSITIVE_INFINITY: u32 = 4;
    /// レコードの構成子（レコードは構成子が一つの型であり、タグは 0。10-06「脱糖」のレコードの構築）
    pub const RECORD: u32 = 0;
    /// `ByteOrder` の構成子（03-06「Bytes と ByteOrder（初回リリース版）」の順）
    pub const BYTE_ORDER_BIG_ENDIAN: u32 = 0;
    pub const BYTE_ORDER_LITTLE_ENDIAN: u32 = 1;
    /// `NetworkErrorKind` の構成子（01-09「ネットワークの失敗の種類（初回リリース版）」の順）
    pub const NETWORK_ERROR_KIND_HOST_NOT_FOUND: u32 = 0;
    pub const NETWORK_ERROR_KIND_CONNECTION_REFUSED: u32 = 1;
    pub const NETWORK_ERROR_KIND_CONNECTION_RESET: u32 = 2;
    pub const NETWORK_ERROR_KIND_TIMED_OUT: u32 = 3;
    pub const NETWORK_ERROR_KIND_ADDRESS_IN_USE: u32 = 4;
    pub const NETWORK_ERROR_KIND_INVALID_HTTP_DATA: u32 = 5;
    pub const NETWORK_ERROR_KIND_INVALID_INPUT: u32 = 6;
    pub const NETWORK_ERROR_KIND_PERMISSION_DENIED: u32 = 7;
    pub const NETWORK_ERROR_KIND_OTHER: u32 = 8;
    /// `File.EntryKind` の構成子（03-07「File」の順）
    pub const FILE_ENTRY_KIND_REGULAR_FILE: u32 = 0;
    pub const FILE_ENTRY_KIND_DIRECTORY: u32 = 1;
    pub const FILE_ENTRY_KIND_SYMBOLIC_LINK: u32 = 2;
    pub const FILE_ENTRY_KIND_OTHER: u32 = 3;
    /// `File.WriteMode` の構成子（03-07「File」の順）
    pub const FILE_WRITE_MODE_REPLACE: u32 = 0;
    pub const FILE_WRITE_MODE_APPEND: u32 = 1;
    /// `Json.Value` の構成子（03-08「Json」の順）
    pub const JSON_VALUE_NULL: u32 = 0;
    pub const JSON_VALUE_BOOLEAN: u32 = 1;
    pub const JSON_VALUE_INTEGER: u32 = 2;
    pub const JSON_VALUE_FLOAT: u32 = 3;
    pub const JSON_VALUE_STRING: u32 = 4;
    pub const JSON_VALUE_ARRAY: u32 = 5;
    pub const JSON_VALUE_OBJECT: u32 = 6;
}

use crate::ir::core_ir::{Intrinsic, OperatorKind};
use crate::ir::lower_ir::ListEnd;
use crate::types::Scheme;
use crate::types::builtin::BuiltinTypeId;

/// 組み込みの表の項目の種類（実装プラン 10-12「項目の種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EntryKind {
    /// 標準ライブラリのソースで `@builtin` を付けて宣言した関数。型はソースの宣言が与える
    Declared,
    /// 組み込みのエフェクトの操作（権限は `Io`）。型はソースの操作の宣言が与える
    EffectOp,
    /// 演算子 `⊕_T`・`neg_T`（01-12）。`=` と `<>` は `Equality`
    Operator {
        op: OperatorKind,
        operand: BuiltinTypeId,
    },
    /// `eq[T]`（`negated` が偽）と `ne[T]`（真）
    Equality { negated: bool },
    /// リストのパターンの内部の項目（02-06「判定の木への変換」）
    ListPattern(ListPatternOp),
    /// ソースに名前を持たない文字列補間の `str_T`
    Interpolation { operand: BuiltinTypeId },
}

/// リストのパターンの内部の項目（10-06 の下位 IR の `CaseLength`・`ListGet`・`ListSlice`）。
/// どれも実行時エラーを起こさない。範囲の外の位置を受け取ったら `Stop::Internal` を返す（判定の木が長さを
/// 確かめてから呼ぶので、型検査を通ったプログラムでは起きない）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ListPatternOp {
    /// `%List.length`: `function[T](List[T]) -> Integer`
    Length,
    /// `%List.getFront`・`%List.getBack`: `function[T](List[T], Integer) -> T`。端から 0 で数えた位置の要素
    Get(ListEnd),
    /// `%List.slice`: `function[T](List[T], Integer, Integer) -> List[T]`。前の n 個と後の m 個を除いた部分
    Slice,
}

/// 演算子の項目（01-06「演算子の型付け」、02-07「演算子の移し方」）。
pub const OPERATORS: &[(OperatorKind, BuiltinTypeId, &str)] = &[
    (OperatorKind::Add, BuiltinTypeId::INTEGER, "%Integer.add"),
    (
        OperatorKind::Sub,
        BuiltinTypeId::INTEGER,
        "%Integer.subtract",
    ),
    (
        OperatorKind::Mul,
        BuiltinTypeId::INTEGER,
        "%Integer.multiply",
    ),
    (OperatorKind::IntDiv, BuiltinTypeId::INTEGER, "%Integer.div"),
    (OperatorKind::Mod, BuiltinTypeId::INTEGER, "%Integer.mod"),
    (OperatorKind::Neg, BuiltinTypeId::INTEGER, "%Integer.negate"),
    (OperatorKind::Lt, BuiltinTypeId::INTEGER, "%Integer.less"),
    (
        OperatorKind::Le,
        BuiltinTypeId::INTEGER,
        "%Integer.lessOrEqual",
    ),
    (OperatorKind::Gt, BuiltinTypeId::INTEGER, "%Integer.greater"),
    (
        OperatorKind::Ge,
        BuiltinTypeId::INTEGER,
        "%Integer.greaterOrEqual",
    ),
    (OperatorKind::Add, BuiltinTypeId::FLOAT, "%Float.add"),
    (OperatorKind::Sub, BuiltinTypeId::FLOAT, "%Float.subtract"),
    (OperatorKind::Mul, BuiltinTypeId::FLOAT, "%Float.multiply"),
    (OperatorKind::Div, BuiltinTypeId::FLOAT, "%Float.divide"),
    (OperatorKind::Neg, BuiltinTypeId::FLOAT, "%Float.negate"),
    (OperatorKind::Lt, BuiltinTypeId::FLOAT, "%Float.less"),
    (OperatorKind::Le, BuiltinTypeId::FLOAT, "%Float.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::FLOAT, "%Float.greater"),
    (
        OperatorKind::Ge,
        BuiltinTypeId::FLOAT,
        "%Float.greaterOrEqual",
    ),
    (OperatorKind::Add, BuiltinTypeId::DECIMAL, "%Decimal.add"),
    (
        OperatorKind::Sub,
        BuiltinTypeId::DECIMAL,
        "%Decimal.subtract",
    ),
    (
        OperatorKind::Mul,
        BuiltinTypeId::DECIMAL,
        "%Decimal.multiply",
    ),
    (OperatorKind::Div, BuiltinTypeId::DECIMAL, "%Decimal.divide"),
    (OperatorKind::Neg, BuiltinTypeId::DECIMAL, "%Decimal.negate"),
    (OperatorKind::Lt, BuiltinTypeId::DECIMAL, "%Decimal.less"),
    (
        OperatorKind::Le,
        BuiltinTypeId::DECIMAL,
        "%Decimal.lessOrEqual",
    ),
    (OperatorKind::Gt, BuiltinTypeId::DECIMAL, "%Decimal.greater"),
    (
        OperatorKind::Ge,
        BuiltinTypeId::DECIMAL,
        "%Decimal.greaterOrEqual",
    ),
    (OperatorKind::Add, BuiltinTypeId::STRING, "%String.add"),
    (OperatorKind::Lt, BuiltinTypeId::STRING, "%String.less"),
    (
        OperatorKind::Le,
        BuiltinTypeId::STRING,
        "%String.lessOrEqual",
    ),
    (OperatorKind::Gt, BuiltinTypeId::STRING, "%String.greater"),
    (
        OperatorKind::Ge,
        BuiltinTypeId::STRING,
        "%String.greaterOrEqual",
    ),
    (
        OperatorKind::Lt,
        BuiltinTypeId::CHARACTER,
        "%Character.less",
    ),
    (
        OperatorKind::Le,
        BuiltinTypeId::CHARACTER,
        "%Character.lessOrEqual",
    ),
    (
        OperatorKind::Gt,
        BuiltinTypeId::CHARACTER,
        "%Character.greater",
    ),
    (
        OperatorKind::Ge,
        BuiltinTypeId::CHARACTER,
        "%Character.greaterOrEqual",
    ),
    (OperatorKind::Lt, BuiltinTypeId::BYTE, "%Byte.less"),
    (OperatorKind::Le, BuiltinTypeId::BYTE, "%Byte.lessOrEqual"),
    (OperatorKind::Gt, BuiltinTypeId::BYTE, "%Byte.greater"),
    (
        OperatorKind::Ge,
        BuiltinTypeId::BYTE,
        "%Byte.greaterOrEqual",
    ),
];

/// `eq[T]` の項目の名前。
pub const EQUALITY: &str = "%eq";
/// `ne[T]` の項目の名前。
pub const INEQUALITY: &str = "%ne";

/// 文字列補間の `str_T` の項目（01-06「演算子の型付け」の補間の型のうち `String` を除くもの）。
/// ソースに同じ意味の関数があるものはその項目を使い、`Boolean` だけ内部の項目を置く。
pub const INTERPOLATION: &[(BuiltinTypeId, &str)] = &[
    (BuiltinTypeId::INTEGER, "Integer.toString"),
    (BuiltinTypeId::FLOAT, "Float.toString"),
    (BuiltinTypeId::CHARACTER, "Character.toString"),
    (BuiltinTypeId::BOOLEAN, "%Boolean.toString"),
    (BuiltinTypeId::BYTE, "Byte.toString"),
    (BuiltinTypeId::DECIMAL, "Decimal.toString"),
];

/// リストのパターンの内部の項目。
pub const LIST_PATTERN: &[(ListPatternOp, &str)] = &[
    (ListPatternOp::Length, "%List.length"),
    (ListPatternOp::Get(ListEnd::Front), "%List.getFront"),
    (ListPatternOp::Get(ListEnd::Back), "%List.getBack"),
    (ListPatternOp::Slice, "%List.slice"),
];

/// 専用の命令に移す `@builtin` の関数（02-07「コード生成」の `FORCE`・`UPDATE`）。
pub const INTRINSIC_FUNCTIONS: &[(&str, Intrinsic)] = &[
    ("Lazy.force", Intrinsic::Force),
    ("Reference.update", Intrinsic::Update),
];

/// 項目の種類。名前が `%` から始まる項目は上の定数の表から、`Benitoite.` から始まる項目は `EffectOp`、
/// ほかは `Declared` とする。
pub fn builtin_kind(id: BuiltinId) -> Option<EntryKind> {
    let decl = builtin_decl(id)?;
    if decl.name.starts_with("Benitoite.") {
        return (decl.capability == Capability::Io).then_some(EntryKind::EffectOp);
    }
    if !decl.name.starts_with('%') {
        return (decl.capability != Capability::Io).then_some(EntryKind::Declared);
    }
    if decl.capability != Capability::Pure {
        return None;
    }
    if let Some(&(op, operand, _)) = OPERATORS.iter().find(|(_, _, name)| *name == decl.name) {
        return Some(EntryKind::Operator { op, operand });
    }
    if decl.name == EQUALITY || decl.name == INEQUALITY {
        return Some(EntryKind::Equality {
            negated: decl.name == INEQUALITY,
        });
    }
    if let Some(&(op, _)) = LIST_PATTERN.iter().find(|(_, name)| *name == decl.name) {
        return Some(EntryKind::ListPattern(op));
    }
    INTERPOLATION.iter().find_map(|&(operand, name)| {
        (name == decl.name).then_some(EntryKind::Interpolation { operand })
    })
}

/// 専用の命令に移す項目の `Intrinsic`（`Operator`・`Equality` の項目と `INTRINSIC_FUNCTIONS`）。
pub fn builtin_intrinsic(id: BuiltinId) -> Option<Intrinsic> {
    match builtin_kind(id)? {
        EntryKind::Operator { op, operand } => Some(Intrinsic::Operator { op, operand }),
        EntryKind::Equality { negated: false } => Some(Intrinsic::Eq),
        EntryKind::Equality { negated: true } => Some(Intrinsic::Ne),
        EntryKind::Declared
        | EntryKind::EffectOp
        | EntryKind::ListPattern(_)
        | EntryKind::Interpolation { .. } => {
            let name = builtin_decl(id)?.name;
            INTRINSIC_FUNCTIONS
                .iter()
                .find_map(|&(n, intrinsic)| (n == name).then_some(intrinsic))
        }
    }
}

/// 演算子とオペランドの型から項目を引く（`OPERATORS`）。
pub fn operator_builtin(op: OperatorKind, operand: BuiltinTypeId) -> Option<BuiltinId> {
    let (_, _, name) = OPERATORS
        .iter()
        .find(|(o, t, _)| *o == op && *t == operand)?;
    lookup_builtin(name)
}

/// `eq`（`negated` が偽）か `ne`（真）の項目。
pub fn equality_builtin(negated: bool) -> Option<BuiltinId> {
    lookup_builtin(if negated { INEQUALITY } else { EQUALITY })
}

/// 文字列補間の `str_T` の項目（`INTERPOLATION`）。`String` には `None` を返す（`str_T` を通さない）。
pub fn interpolation_builtin(operand: BuiltinTypeId) -> Option<BuiltinId> {
    let (_, name) = INTERPOLATION.iter().find(|(t, _)| *t == operand)?;
    lookup_builtin(name)
}

/// リストのパターンの内部の項目（`LIST_PATTERN`）。
pub fn list_pattern_builtin(op: ListPatternOp) -> Option<BuiltinId> {
    let (_, name) = LIST_PATTERN.iter().find(|(o, _)| *o == op)?;
    lookup_builtin(name)
}

/// ソースに宣言のない項目（`Operator`・`Equality`・`ListPattern`・`Interpolation`）の宣言の型。
/// `Declared` と `EffectOp` の項目には `None` を返す（型はソースの宣言が与える）。
/// 型パラメータは `T` 一つ（`Equality` は組み込みの制約 `equality` を持つ）か、ない。エフェクトは空集合である。
pub fn builtin_scheme(id: BuiltinId) -> Option<Scheme> {
    use crate::types::{BuiltinConstraint, EffectSet, ParamKind, Ty, TyCon, TypeParamInfo};
    let basic = |id| Ty::Con(TyCon::Builtin(id), Vec::new());
    let integer = basic(BuiltinTypeId::INTEGER);
    let boolean = basic(BuiltinTypeId::BOOLEAN);
    let string = basic(BuiltinTypeId::STRING);
    let list = Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![Ty::Param(0)]);
    let mut type_params = Vec::new();
    let (params, ret) = match builtin_kind(id)? {
        EntryKind::Declared | EntryKind::EffectOp => return None,
        EntryKind::Operator { op, operand } => {
            let ty = basic(operand);
            let params = if op == OperatorKind::Neg {
                vec![ty.clone()]
            } else {
                vec![ty.clone(), ty.clone()]
            };
            let ret = if matches!(
                op,
                OperatorKind::Lt | OperatorKind::Le | OperatorKind::Gt | OperatorKind::Ge
            ) {
                boolean
            } else {
                ty
            };
            (params, ret)
        }
        kind @ (EntryKind::Equality { .. } | EntryKind::ListPattern(_)) => {
            type_params.push(TypeParamInfo {
                name: "T".into(),
                kind: ParamKind::Value,
                builtin: if matches!(kind, EntryKind::Equality { .. }) {
                    Some(BuiltinConstraint::Equality)
                } else {
                    None
                },
            });
            match kind {
                EntryKind::Equality { .. } => (vec![Ty::Param(0), Ty::Param(0)], boolean),
                EntryKind::ListPattern(ListPatternOp::Length) => (vec![list], integer),
                EntryKind::ListPattern(ListPatternOp::Get(_)) => {
                    (vec![list, integer], Ty::Param(0))
                }
                EntryKind::ListPattern(ListPatternOp::Slice) => {
                    (vec![list.clone(), integer.clone(), integer], list)
                }
                EntryKind::Declared
                | EntryKind::EffectOp
                | EntryKind::Operator { .. }
                | EntryKind::Interpolation { .. } => return None,
            }
        }
        EntryKind::Interpolation { operand } => (vec![basic(operand)], string),
    };
    Some(Scheme {
        type_params,
        effect_params: Vec::new(),
        class_constraints: Vec::new(),
        params,
        ret,
        effects: EffectSet::empty(),
        wrote_io_all: false,
    })
}

#[cfg(test)]
mod tests {
    // 164 項目の登録は、U1 が番号・権限・宣言の型を引く契約である（実装プラン 10-12「確かめること」）。
    // テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use crate::types::{BuiltinConstraint, EffectSet, ParamKind, Ty, TyCon, TypeParamInfo};

    fn basic(id: BuiltinTypeId) -> Ty {
        Ty::Con(TyCon::Builtin(id), vec![])
    }

    #[test]
    fn table_names_parts_capabilities_and_schemes_are_consistent() {
        let lengths = [
            43, 15, 9, 5, 18, 1, 9, 8, 18, 3, 3, 2, 4, 1, 5, 2, 2, 6, 6, 2, 2, 4, 7, 2, 7, 7, 2,
            16, 2, 2, 3, 2, 13, 6, 3, 9, 10, 3, 12, 5, 11, 4, 1, 7, 1, 1,
        ];
        assert_eq!(
            super::super::funcs::PARTS
                .iter()
                .map(|part| part.len())
                .collect::<Vec<_>>(),
            lengths
        );
        let mut names = std::collections::BTreeSet::new();
        let mut capabilities = [0; 3];
        for decl in super::super::funcs::PARTS
            .iter()
            .flat_map(|part| part.iter())
        {
            assert!(names.insert(decl.name), "duplicate {}", decl.name);
            let id = lookup_builtin(decl.name).unwrap();
            assert_eq!(builtin_decl(id).unwrap().name, decl.name);
            let kind = builtin_kind(id).unwrap();
            assert_eq!(
                decl.capability == Capability::Io,
                decl.name.starts_with("Benitoite.")
            );
            let segments = decl
                .name
                .trim_start_matches('%')
                .split('.')
                .collect::<Vec<_>>();
            assert!(
                segments
                    .iter()
                    .all(|s| !s.is_empty() && s.bytes().all(|b| b.is_ascii_alphanumeric()))
            );
            assert!(
                segments
                    .last()
                    .unwrap()
                    .starts_with(|c: char| c.is_ascii_lowercase())
            );
            if !decl.name.starts_with('%') {
                assert!(segments.len() >= 2);
            }
            match decl.capability {
                Capability::Pure => capabilities[0] += 1,
                Capability::State => capabilities[1] += 1,
                Capability::Io => capabilities[2] += 1,
            }
            let scheme = builtin_scheme(id);
            assert_eq!(scheme.is_some(), decl.name.starts_with('%'));
            if let Some(scheme) = scheme {
                assert_eq!(scheme.params.len(), usize::from(decl.arity));
                assert!(scheme.effects.is_empty());
                assert!(scheme.effect_params.is_empty());
                assert!(scheme.class_constraints.is_empty());
                assert!(!scheme.wrote_io_all);
            }
            assert_eq!(
                matches!(kind, EntryKind::Declared),
                !decl.name.starts_with('%') && !decl.name.starts_with("Benitoite.")
            );
        }
        assert_eq!(lengths.len(), 46);
        assert_eq!(names.len(), 304);
        assert_eq!(capabilities, [231, 16, 57]);
        assert!(lookup_builtin("missing.name").is_none());
        let invalid = BuiltinId(u16::MAX);
        assert!(builtin_decl(invalid).is_none());
        assert!(builtin_kind(invalid).is_none());
        assert!(builtin_intrinsic(invalid).is_none());
        assert!(builtin_scheme(invalid).is_none());
    }

    #[test]
    fn u3_declarations_match_the_frozen_interface() {
        use Capability::{Io, Pure, State};
        // L00 は、10-15 の名前・権限・引数の数・部分内の順を凍結する。ソースとの照合だけでは
        // 宣言とソースを一緒に変えた誤りを捕まえられないため、独立した期待の一覧を持つ
        // （実装プラン L00「宣言の照合」。test-audit の固定の一覧の原則への個別の指示）。
        let expected: &[&[(&str, Capability, u16)]] = &[
            &[
                ("Character.isAlphabetic", Pure, 1),
                ("Character.isNumeric", Pure, 1),
                ("Character.isWhitespace", Pure, 1),
                ("Character.isUppercase", Pure, 1),
                ("Character.isLowercase", Pure, 1),
                ("Character.toUppercase", Pure, 1),
                ("Character.toLowercase", Pure, 1),
            ],
            &[
                ("String.toUppercase", Pure, 1),
                ("String.toLowercase", Pure, 1),
            ],
            &[
                ("Map.get", Pure, 2),
                ("Map.set", Pure, 3),
                ("Map.remove", Pure, 2),
                ("Map.contains", Pure, 2),
                ("Map.size", Pure, 1),
                ("Map.keys", Pure, 1),
                ("Map.values", Pure, 1),
            ],
            &[
                ("Set.contains", Pure, 2),
                ("Set.add", Pure, 2),
                ("Set.remove", Pure, 2),
                ("Set.size", Pure, 1),
                ("Set.union", Pure, 2),
                ("Set.intersection", Pure, 2),
                ("Set.difference", Pure, 2),
            ],
            &[("String.toUTF8", Pure, 1), ("String.fromUTF8", Pure, 1)],
            &[
                ("Bytes.empty", Pure, 0),
                ("Bytes.fromList", Pure, 1),
                ("Bytes.fromIntegers", Pure, 1),
                ("Bytes.fromHex", Pure, 1),
                ("Bytes.fromBinary", Pure, 1),
                ("Bytes.toList", Pure, 1),
                ("Bytes.toHex", Pure, 1),
                ("Bytes.toBinary", Pure, 1),
                ("Bytes.length", Pure, 1),
                ("Bytes.get", Pure, 2),
                ("Bytes.slice", Pure, 3),
                ("Bytes.concatenate", Pure, 2),
                ("Bytes.readUnsigned", Pure, 4),
                ("Bytes.readSigned", Pure, 4),
                ("Bytes.fromUnsigned", Pure, 3),
                ("Bytes.fromSigned", Pure, 3),
            ],
            &[
                ("NetworkError.kind", Pure, 1),
                ("NetworkError.message", Pure, 1),
            ],
            &[
                ("Benitoite.IO.Console.readAllLines", Io, 0),
                ("Benitoite.IO.Console.readAllBytes", Io, 0),
            ],
            &[
                ("Benitoite.IO.Process.scriptDirectory", Io, 0),
                ("Benitoite.IO.Process.environmentVariable", Io, 1),
                ("Benitoite.IO.Process.workingDirectory", Io, 0),
            ],
            &[
                ("Benitoite.IO.Clock.now", Io, 0),
                ("Benitoite.IO.Clock.localOffsetMinutes", Io, 0),
            ],
            &[
                ("Benitoite.IO.File.readBytes", Io, 1),
                ("Benitoite.IO.File.readLines", Io, 1),
                ("Benitoite.IO.File.exists", Io, 1),
                ("Benitoite.IO.File.info", Io, 1),
                ("Benitoite.IO.File.listDirectory", Io, 1),
                ("Benitoite.IO.File.walk", Io, 1),
                ("Benitoite.IO.File.canonicalize", Io, 1),
                ("Benitoite.IO.File.writeBytes", Io, 2),
                ("Benitoite.IO.File.appendBytes", Io, 2),
                ("Benitoite.IO.File.createDirectory", Io, 1),
                ("Benitoite.IO.File.remove", Io, 1),
                ("Benitoite.IO.File.removeTree", Io, 1),
                ("Benitoite.IO.File.rename", Io, 2),
            ],
            &[
                ("Benitoite.IO.File.readChunk", Io, 2),
                ("Benitoite.IO.File.openWriter", Io, 2),
                ("Benitoite.IO.File.write", Io, 2),
                ("Benitoite.IO.File.writeLine", Io, 2),
                ("Benitoite.IO.File.writeChunk", Io, 2),
                ("IO.File.closeWriter", State, 1),
            ],
            &[
                ("Benitoite.IO.Process.run", Io, 1),
                ("Benitoite.IO.Process.runAttached", Io, 1),
                ("Benitoite.IO.Process.shell", Io, 1),
            ],
            &[
                ("Benitoite.IO.Random.integer", Io, 2),
                ("Benitoite.IO.Random.float", Io, 0),
                ("Benitoite.IO.Random.boolean", Io, 0),
                ("Benitoite.IO.Random.shuffle", Io, 1),
                ("Benitoite.IO.Random.choose", Io, 1),
                ("IO.Random.fromSeed", Pure, 1),
                ("IO.Random.nextInteger", Pure, 3),
                ("IO.Random.nextFloat", Pure, 1),
                ("IO.Random.shuffleWith", Pure, 2),
            ],
            &[
                ("Path.join", Pure, 2),
                ("Path.joinAll", Pure, 1),
                ("Path.parent", Pure, 1),
                ("Path.fileName", Pure, 1),
                ("Path.stem", Pure, 1),
                ("Path.extension", Pure, 1),
                ("Path.withExtension", Pure, 2),
                ("Path.isAbsolute", Pure, 1),
                ("Path.components", Pure, 1),
                ("Path.normalize", Pure, 1),
            ],
            &[
                ("Json.parse", Pure, 1),
                ("Json.stringify", Pure, 1),
                ("Json.stringifyPretty", Pure, 1),
            ],
            &[
                ("Regex.compile", Pure, 1),
                ("Regex.isMatch", Pure, 2),
                ("Regex.find", Pure, 2),
                ("Regex.findAll", Pure, 2),
                ("Regex.matchText", Pure, 1),
                ("Regex.matchByteStart", Pure, 1),
                ("Regex.matchByteEnd", Pure, 1),
                ("Regex.group", Pure, 2),
                ("Regex.namedGroup", Pure, 2),
                ("Regex.replaceFirst", Pure, 3),
                ("Regex.replaceAll", Pure, 3),
                ("Regex.split", Pure, 2),
            ],
            &[
                ("Csv.parse", Pure, 1),
                ("Csv.parseWith", Pure, 2),
                ("Csv.parseWithHeader", Pure, 1),
                ("Csv.format", Pure, 1),
                ("Csv.formatWith", Pure, 2),
            ],
            &[
                ("Time.fromUnixSeconds", Pure, 1),
                ("Time.fromUnixMilliseconds", Pure, 1),
                ("Time.toUnixSeconds", Pure, 1),
                ("Time.toUnixMilliseconds", Pure, 1),
                ("Time.addMilliseconds", Pure, 2),
                ("Time.differenceMilliseconds", Pure, 2),
                ("Time.toDateTime", Pure, 2),
                ("Time.fromDateTime", Pure, 1),
                ("Time.formatISO8601", Pure, 2),
                ("Time.parseISO8601", Pure, 1),
                ("Time.format", Pure, 3),
            ],
            &[
                ("Encoding.base64Encode", Pure, 1),
                ("Encoding.base64Decode", Pure, 1),
                ("Encoding.base64UrlEncode", Pure, 1),
                ("Encoding.base64UrlDecode", Pure, 1),
            ],
            &[("Hash.sha256", Pure, 1)],
            &[
                ("Benitoite.Network.Http.listen", Io, 2),
                ("Benitoite.Network.Http.listenerPort", Io, 1),
                ("Benitoite.Network.Http.accept", Io, 1),
                ("Benitoite.Network.Http.respond", Io, 2),
                ("Network.Http.requestOf", State, 1),
                ("Network.Http.closeListener", State, 1),
                ("Network.Http.closeExchange", State, 1),
            ],
            &[("Network.Http.pathSegments", Pure, 1)],
            &[("Benitoite.Network.Http.send", Io, 1)],
        ];
        let actual = &super::super::funcs::PARTS[22..];
        assert_eq!(actual.len(), expected.len());
        assert_eq!(expected.iter().map(|part| part.len()).sum::<usize>(), 136);
        for (actual, expected) in actual.iter().zip(expected) {
            assert_eq!(
                actual
                    .iter()
                    .map(|d| (d.name, d.capability, d.arity))
                    .collect::<Vec<_>>(),
                *expected
            );
        }
    }

    #[test]
    fn internal_lookup_functions_supply_the_language_types_and_intrinsics() {
        for &(op, operand, name) in OPERATORS {
            let id = operator_builtin(op, operand).unwrap();
            assert_eq!(builtin_decl(id).unwrap().name, name);
            assert_eq!(builtin_kind(id), Some(EntryKind::Operator { op, operand }));
            assert_eq!(
                builtin_intrinsic(id),
                Some(Intrinsic::Operator { op, operand })
            );
            let scheme = builtin_scheme(id).unwrap();
            let ty = basic(operand);
            assert_eq!(
                scheme.params,
                if op == OperatorKind::Neg {
                    vec![ty.clone()]
                } else {
                    vec![ty.clone(), ty.clone()]
                }
            );
            assert_eq!(
                scheme.ret,
                if matches!(
                    op,
                    OperatorKind::Lt | OperatorKind::Le | OperatorKind::Gt | OperatorKind::Ge
                ) {
                    basic(BuiltinTypeId::BOOLEAN)
                } else {
                    ty
                }
            );
            assert!(scheme.type_params.is_empty());
        }
        assert!(operator_builtin(OperatorKind::Div, BuiltinTypeId::INTEGER).is_none());
        for (negated, name, intrinsic) in [
            (false, EQUALITY, Intrinsic::Eq),
            (true, INEQUALITY, Intrinsic::Ne),
        ] {
            let id = equality_builtin(negated).unwrap();
            assert_eq!(builtin_decl(id).unwrap().name, name);
            assert_eq!(builtin_intrinsic(id), Some(intrinsic));
            let scheme = builtin_scheme(id).unwrap();
            assert_eq!(
                scheme.type_params,
                vec![TypeParamInfo {
                    name: "T".into(),
                    kind: ParamKind::Value,
                    builtin: Some(BuiltinConstraint::Equality)
                }]
            );
            assert_eq!(scheme.params, vec![Ty::Param(0), Ty::Param(0)]);
            assert_eq!(scheme.ret, basic(BuiltinTypeId::BOOLEAN));
        }
        for &(operand, name) in INTERPOLATION {
            let id = interpolation_builtin(operand).unwrap();
            assert_eq!(builtin_decl(id).unwrap().name, name);
            assert!(builtin_intrinsic(id).is_none());
            if name.starts_with('%') {
                let scheme = builtin_scheme(id).unwrap();
                assert_eq!(scheme.params, vec![basic(BuiltinTypeId::BOOLEAN)]);
                assert_eq!(scheme.ret, basic(BuiltinTypeId::STRING));
                assert!(scheme.type_params.is_empty());
            } else {
                assert!(builtin_scheme(id).is_none());
            }
        }
        assert!(interpolation_builtin(BuiltinTypeId::STRING).is_none());
        let list = Ty::Con(TyCon::Builtin(BuiltinTypeId::LIST), vec![Ty::Param(0)]);
        let integer = basic(BuiltinTypeId::INTEGER);
        for &(op, name) in LIST_PATTERN {
            let id = list_pattern_builtin(op).unwrap();
            assert_eq!(builtin_decl(id).unwrap().name, name);
            assert_eq!(builtin_kind(id), Some(EntryKind::ListPattern(op)));
            assert!(builtin_intrinsic(id).is_none());
            let scheme = builtin_scheme(id).unwrap();
            assert_eq!(
                scheme.type_params,
                vec![TypeParamInfo {
                    name: "T".into(),
                    kind: ParamKind::Value,
                    builtin: None
                }]
            );
            let (params, ret) = match op {
                ListPatternOp::Length => (vec![list.clone()], integer.clone()),
                ListPatternOp::Get(_) => (vec![list.clone(), integer.clone()], Ty::Param(0)),
                ListPatternOp::Slice => (
                    vec![list.clone(), integer.clone(), integer.clone()],
                    list.clone(),
                ),
            };
            assert_eq!(
                (scheme.params, scheme.ret, scheme.effects),
                (params, ret, EffectSet::empty())
            );
        }
        for &(name, intrinsic) in INTRINSIC_FUNCTIONS {
            let id = lookup_builtin(name).unwrap();
            assert_eq!(builtin_intrinsic(id), Some(intrinsic));
            assert!(builtin_scheme(id).is_none());
        }
    }
}

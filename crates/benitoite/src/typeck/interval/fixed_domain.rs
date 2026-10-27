//! 読み込み済みのシフト宣言に付ける固定の定義域
//! （設計書 02-05「区間解析の内部入力」、01-12「区間解析の直接引数と固定の定義域」）。

use crate::base::BindingId;
use crate::resolve::BindingKind;
use crate::typeck::decls::Decls;
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{Scheme, Ty, TyCon};

/// ソース順とは別の引数位置・契約名・型・正常域。Byte は算術七種へ加えない。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(in crate::typeck) struct Contract {
    pub name: &'static str,
    pub argument: usize,
    pub parameters: [&'static str; 2],
    pub argument_types: [B; 2],
    pub result: B,
    pub minimum: i128,
    pub maximum: i128,
}

impl Contract {
    const fn shift(name: &'static str, operand: B, maximum: i128) -> Self {
        Self {
            name,
            argument: 1,
            parameters: ["a", "n"],
            argument_types: [operand, B::INTEGER],
            result: operand,
            minimum: 0,
            maximum,
        }
    }

    fn matches(&self, scheme: &Scheme) -> bool {
        let same_type = |ty: &Ty, expected| matches!(ty, Ty::Con(TyCon::Builtin(actual), args) if *actual == expected && args.is_empty());
        self.minimum <= self.maximum
            && self.argument_types.get(self.argument) == Some(&B::INTEGER)
            && scheme.type_params.is_empty()
            && scheme.effect_params.is_empty()
            && scheme.class_constraints.is_empty()
            && scheme.effects.is_empty()
            && scheme
                .param_names
                .iter()
                .map(String::as_str)
                .eq(self.parameters)
            && scheme.params.len() == self.argument_types.len()
            && scheme
                .params
                .iter()
                .zip(self.argument_types)
                .all(|(ty, expected)| same_type(ty, expected))
            && same_type(&scheme.ret, self.result)
    }
}

/// 別名も元の宣言の BindingId を保つ。役割が同じでも宣言を統合しない。
#[derive(Clone, Copy, Debug)]
pub(super) struct Entry {
    pub declaration: BindingId,
    pub contract: &'static Contract,
}

impl Entry {
    fn resolve(contract: &'static Contract, decls: &Decls<'_>) -> Option<Self> {
        let entry = Self {
            declaration: decls.resolved.stdlib(contract.name)?,
            contract,
        };
        let binding = decls.resolved.bindings.get(entry.declaration)?;
        if !matches!(binding.kind, BindingKind::Fn | BindingKind::BuiltinFn(_))
            || !entry
                .contract
                .matches(decls.out.decl_types.get(entry.declaration)?)
        {
            return None;
        }
        Some(entry)
    }
}

/// 交換へ渡す標準表もこの完全名の辞書順を使い、Range の二項の後へ追加する。
/// 存在しない unsigned/Byte の shiftRightUnsigned は列挙しない。
const CONTRACTS: [Contract; 27] = [
    Contract::shift("Benitoite.Byte.shiftLeft", B::BYTE, 7),
    Contract::shift("Benitoite.Byte.shiftRight", B::BYTE, 7),
    Contract::shift("Benitoite.Integer.shiftLeft", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer.shiftRight", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer.shiftRightUnsigned", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer16.shiftLeft", B::INTEGER16, 15),
    Contract::shift("Benitoite.Integer16.shiftRight", B::INTEGER16, 15),
    Contract::shift("Benitoite.Integer16.shiftRightUnsigned", B::INTEGER16, 15),
    Contract::shift("Benitoite.Integer32.shiftLeft", B::INTEGER32, 31),
    Contract::shift("Benitoite.Integer32.shiftRight", B::INTEGER32, 31),
    Contract::shift("Benitoite.Integer32.shiftRightUnsigned", B::INTEGER32, 31),
    Contract::shift("Benitoite.Integer64.shiftLeft", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer64.shiftRight", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer64.shiftRightUnsigned", B::INTEGER, 63),
    Contract::shift("Benitoite.Integer8.shiftLeft", B::INTEGER8, 7),
    Contract::shift("Benitoite.Integer8.shiftRight", B::INTEGER8, 7),
    Contract::shift("Benitoite.Integer8.shiftRightUnsigned", B::INTEGER8, 7),
    Contract::shift(
        "Benitoite.UnsignedInteger.shiftLeft",
        B::UNSIGNED_INTEGER64,
        63,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger.shiftRight",
        B::UNSIGNED_INTEGER64,
        63,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger16.shiftLeft",
        B::UNSIGNED_INTEGER16,
        15,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger16.shiftRight",
        B::UNSIGNED_INTEGER16,
        15,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger32.shiftLeft",
        B::UNSIGNED_INTEGER32,
        31,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger32.shiftRight",
        B::UNSIGNED_INTEGER32,
        31,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger64.shiftLeft",
        B::UNSIGNED_INTEGER64,
        63,
    ),
    Contract::shift(
        "Benitoite.UnsignedInteger64.shiftRight",
        B::UNSIGNED_INTEGER64,
        63,
    ),
    Contract::shift("Benitoite.UnsignedInteger8.shiftLeft", B::BYTE, 7),
    Contract::shift("Benitoite.UnsignedInteger8.shiftRight", B::BYTE, 7),
];

/// 追加ロードせず、解決済みで署名が一致する純粋な宣言だけを固定順で返す。
pub(super) fn loaded(decls: &Decls<'_>) -> Vec<Entry> {
    CONTRACTS
        .iter()
        .filter_map(|contract| Entry::resolve(contract, decls))
        .collect()
}

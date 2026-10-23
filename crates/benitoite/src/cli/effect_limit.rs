//! run と test の宣言上限と許す原子的エフェクトを照合する（設計書 06-01「実行前のエフェクト上限の照合」）。

use std::collections::{BTreeSet, HashSet};

use crate::diag::{DiagBuilder, Diagnostic, codes::DiagCode};
use crate::types::builtin::{BUILTIN_EFFECTS, BuiltinEffectId, effect_name};

use super::inspection::FunctionContract;
use super::text;

/// CLI が受理した、許す原子的な組み込みエフェクトの集合。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EffectLimit(BTreeSet<BuiltinEffectId>);

/// 正規名だけを受理し、空白や重複を補正しない。
pub(super) fn parse(value: &str) -> Result<EffectLimit, String> {
    let mut allowed = BTreeSet::new();
    if !value.is_empty() {
        for name in value.split(',') {
            if name.is_empty() {
                return Err(text::EMPTY_EFFECT_NAME.into());
            }
            let id = BUILTIN_EFFECTS
                .iter()
                .enumerate()
                .filter_map(|(index, _)| u16::try_from(index).ok().map(BuiltinEffectId))
                .filter(|id| *id != BuiltinEffectId::IO_ALL)
                .find(|id| effect_name(*id).as_deref() == Some(name))
                .ok_or_else(|| text::INVALID_EFFECT_NAME.replace("{name}", name))?;
            if !allowed.insert(id) {
                return Err(text::DUPLICATE_EFFECT_NAME.replace("{name}", name));
            }
        }
    }
    Ok(EffectLimit(allowed))
}

/// 型検査が確定した宣言上限を ID で比較し、不足した関数に一件だけ返す。
pub(super) fn check(contract: &FunctionContract, allowed: &EffectLimit) -> Option<Diagnostic> {
    let missing = contract
        .effects
        .iter()
        .copied()
        .filter(|id| !allowed.0.contains(id))
        .collect::<Vec<_>>();
    if missing.is_empty() {
        return None;
    }
    let mut diagnostic = DiagBuilder::new(DiagCode::E0512)
        .arg("function", contract.name.clone())
        .arg("missing", display(missing.iter().copied()))
        .arg("allowed", display(allowed.0.iter().copied()))
        .primary(contract.location)
        .note("missing")
        .note("allowed")
        .help("review");
    // IO.Allの展開先が複数不足しても、同じ追加元は一度だけ示す
    // （設計書 06-01「実行前のエフェクト上限の照合」）。
    let mut seen = HashSet::new();
    for (effect, span) in &contract.file_origins {
        if missing.contains(effect) && seen.insert(*span) {
            diagnostic = diagnostic.secondary(*span, "file");
        }
    }
    Some(diagnostic.build())
}

fn display(effects: impl IntoIterator<Item = BuiltinEffectId>) -> String {
    // 解析と契約の抽出で検証済みの ID だけを受ける。ID の順と表示の辞書順を分ける。
    let names = effects
        .into_iter()
        .filter_map(effect_name)
        .collect::<BTreeSet<_>>();
    if names.is_empty() {
        crate::diag::codes::EMPTY_EFFECT_SET.into()
    } else {
        names.into_iter().collect::<Vec<_>>().join(", ")
    }
}

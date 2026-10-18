//! 検査済みの表から報告用の契約を所有して取り出す（設計書 02-01「検査と実行の経路」、
//! 06-01「main の非実行の検査報告」）。

use crate::base::{BindingId, Span};
use crate::ir::InternalError;
use crate::modules::ModuleKind;
use crate::pipeline::CheckedProgram;
use crate::syntax::ast::Item;
use crate::types::EffectName;
use crate::types::builtin::BuiltinEffectId;

/// 検査した関数の宣言名・位置・原子的エフェクトの上限。
pub(super) struct FunctionContract {
    pub binding: BindingId,
    pub name: String,
    pub location: Span,
    pub effects: Vec<BuiltinEffectId>,
}

/// AST と型表を破棄した後も報告に使う所有データ。
pub(super) struct ProgramInspection {
    pub main: Option<FunctionContract>,
    pub tests: Vec<FunctionContract>,
    pub process_shell_reference: ShellReference,
}

/// 検査対象全体にある標準 shell の参照。
pub(super) enum ShellReference {
    Present,
    Absent,
    Unknown,
}

fn internal(message: &str) -> InternalError {
    InternalError {
        stage: "check",
        message: message.into(),
    }
}

/// 検査済みの原子的エフェクトを名前空間の接頭辞なしの正規名へ写す。
pub(super) fn effect_name(id: BuiltinEffectId) -> Result<String, InternalError> {
    crate::types::builtin::effect_name(id)
        .filter(|_| id != BuiltinEffectId::IO_ALL)
        .ok_or_else(|| internal("unknown or unexpanded builtin effect in checked contract"))
}

/// 宣言した上限を取り出す。未確定な型表を純粋な契約に補わない。
pub(super) fn function_contract(
    checked: &CheckedProgram,
    binding: BindingId,
    name: &str,
    location: Span,
) -> Result<FunctionContract, InternalError> {
    let scheme = checked
        .types
        .decl_types
        .get(binding)
        .ok_or_else(|| internal("function scheme missing from checked program"))?;
    if !scheme.effects.failures.is_empty() {
        return Err(internal("unhandled failure in checked entry contract"));
    }
    if !scheme.no_fail.is_empty() || !scheme.effects.vars.is_empty() {
        return Err(internal("effect variables in checked entry contract"));
    }
    let mut effects = scheme
        .effects
        .names
        .iter()
        .map(|effect| {
            let EffectName::Builtin(id) = effect else {
                return Err(internal("user effect in checked entry contract"));
            };
            Ok((effect_name(*id)?, *id))
        })
        .collect::<Result<Vec<_>, InternalError>>()?;
    effects.sort_by(|a, b| a.0.cmp(&b.0));
    effects.dedup_by_key(|effect| effect.1);
    Ok(FunctionContract {
        binding,
        name: name.into(),
        location,
        effects: effects.into_iter().map(|(_, id)| id).collect(),
    })
}

/// main の宣言と型表を照合する。実行前の上限の照合では shell の参照を調べない。
pub(super) fn main_contract(checked: &CheckedProgram) -> Result<FunctionContract, InternalError> {
    let main = checked
        .types
        .main
        .as_ref()
        .ok_or_else(|| internal("main missing from checked program"))?;
    let function = checked
        .asts
        .iter()
        .flat_map(|module| &module.decls)
        .find_map(|top| {
            let Item::Fn(function) = &top.item else {
                return None;
            };
            (checked.resolved.decls.get(function.id) == Some(&main.binding)).then_some(function)
        })
        .ok_or_else(|| internal("main declaration missing from checked program"))?;
    if function.name.text != "main" {
        return Err(internal("main binding does not name main"));
    }
    function_contract(
        checked,
        main.binding,
        &function.name.text,
        function.name.span,
    )
}

/// main の宣言と型表を照合し、全参照の表で標準 shell を探す。
pub(super) fn inspect_main(checked: &CheckedProgram) -> Result<ProgramInspection, InternalError> {
    Ok(ProgramInspection {
        main: Some(main_contract(checked)?),
        tests: Vec::new(),
        process_shell_reference: shell_reference(checked)?,
    })
}

/// 通常の実行器が選んだテストと同じ束縛の宣言上限を取り出す。
pub(super) fn inspect_tests(
    checked: &CheckedProgram,
    tests: &[super::tools::test_runner::TestFn],
) -> Result<ProgramInspection, InternalError> {
    let tests = tests
        .iter()
        .map(|test| function_contract(checked, test.binding, &test.function, test.location))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(ProgramInspection {
        main: None,
        tests,
        process_shell_reference: shell_reference(checked)?,
    })
}

fn shell_reference(checked: &CheckedProgram) -> Result<ShellReference, InternalError> {
    // 索引の欠落とモジュールの未読を区別する。判定のために標準ソースを追加で読まない。
    let process_loaded = checked.modules.modules.iter().any(|module| {
        matches!(module.kind, ModuleKind::Prelude | ModuleKind::Stdlib)
            && module
                .name
                .0
                .iter()
                .map(String::as_str)
                .eq(["Benitoite", "IO", "Process"])
    });
    let reference = if process_loaded {
        let shell = checked
            .resolved
            .stdlib("Benitoite.IO.Process.shell")
            .ok_or_else(|| internal("shell binding missing from loaded IO.Process"))?;
        if checked
            .resolved
            .refs
            .iter()
            // 操作名にも同じ束縛が入るため、式の型を持つ参照に限る。
            // ハンドラの節の名前だけを式の参照に数えない（設計書 06-01「main の非実行の検査報告」）。
            .any(|(node, binding)| {
                *binding == shell && checked.types.expr_types.get(node).is_some()
            })
        {
            ShellReference::Present
        } else {
            ShellReference::Absent
        }
    } else {
        ShellReference::Absent
    };
    Ok(reference)
}

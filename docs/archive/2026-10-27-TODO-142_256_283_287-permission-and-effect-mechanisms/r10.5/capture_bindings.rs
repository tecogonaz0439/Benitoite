//! Top の交換の比較に使う、同じ入力の宣言の所属・種類・名前と束縛番号の記録。
//! 比較結果から番号の対応を推測せず、通常の名前解決の出力から独立に採る。
use benitoite::pipeline::{check_text, CheckOptions};
use benitoite::resolve::BindingKind;

fn main() {
    let source = std::fs::read("crates/benitoite/tests/desugar_export/batch3/scope.bnt").unwrap();
    let checked = check_text("scope", &source, CheckOptions { require_main: false, deny_warnings: false });
    assert_eq!(checked.error_count(), 0);
    let program = checked.program.unwrap();
    for (id, b) in program.resolved.bindings.iter() {
        let (kind, owner) = match b.kind {
            BindingKind::Data => ("data", None),
            BindingKind::Record => ("record", None),
            BindingKind::BuiltinType(_) => ("builtin-type", None),
            BindingKind::Fn => ("fn", None),
            BindingKind::BuiltinFn(_) => ("builtin-fn", None),
            BindingKind::Trait => ("class", None),
            BindingKind::Method { trait_, .. } => ("method", Some(trait_)),
            BindingKind::Effect => ("effect", None),
            BindingKind::Op { effect, .. } => ("op", Some(effect)),
            _ => continue,
        };
        let module = &program.modules.get(b.module).unwrap().name.0;
        let owner = owner.and_then(|id| program.resolved.bindings.get(id)).map(|b| b.name.as_str()).unwrap_or("");
        println!("{}\t{}\t{}\t{}\t{}", id.0, module.join("."), kind, owner, b.name);
    }
}

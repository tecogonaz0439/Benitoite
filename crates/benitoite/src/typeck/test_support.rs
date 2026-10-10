//! 後続の段のテストが使う実際の読み込み・名前解決・型検査（実装プラン F07「テストの補助」）。
use super::{TypeckOutput, typecheck};
use crate::diag::Diagnostic;
use crate::modules::LoadOutput;
use crate::resolve::{ResolveOutput, test_support::resolve_files};
/// メモリ上のソースを本物の標準ライブラリとともに検査する。誤りのある前段の出力は後段へ渡さない（02-01「誤りが見つかったときの段の進め方」）。
pub(crate) fn check_files(
    files: &[(&str, &str)],
    require_main: bool,
) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    // F06 の補助は読み込みの成功を前提にする。失敗の場合も全診断を返すため、先に読み込む。
    let (loaded, _) = crate::modules::memfs::load_files(files);
    if loaded.diagnostics.iter().any(Diagnostic::is_error) {
        let diagnostics = loaded.diagnostics.clone();
        return (
            loaded,
            ResolveOutput::default(),
            TypeckOutput::default(),
            diagnostics,
        );
    }
    let (load, resolved, _) = resolve_files(files);
    let mut diagnostics = load.diagnostics.clone();
    diagnostics.extend(resolved.diagnostics.clone());
    let out = if diagnostics.iter().any(Diagnostic::is_error) {
        TypeckOutput::default()
    } else {
        let (out, diags) = typecheck(
            &load.modules,
            &load.asts,
            &load.sources,
            &resolved,
            require_main,
        );
        diagnostics.extend(diags);
        out
    };
    (load, resolved, out, diagnostics)
}

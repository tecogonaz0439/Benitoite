//! 後続の段のテストが使う読み込みと名前解決（実装プラン F06「作るもの」、設計書 02-04）。

use crate::base::IdGen;
use crate::modules::{LoadOutput, memfs::load_files};

use super::{ResolveOutput, resolve};

/// 本物の読み込みの段と名前解決をつなぐ。読み込みが失敗した AST は後続の段に渡さない（02-01「誤りが見つかったときの段の進め方」）。
pub(crate) fn resolve_files(files: &[(&str, &str)]) -> (LoadOutput, ResolveOutput, IdGen) {
    let (load, mut ids) = load_files(files);
    assert!(
        !load
            .diagnostics
            .iter()
            .any(crate::diag::Diagnostic::is_error),
        "loading failed: {:?}",
        load.diagnostics
    );
    let resolved = resolve(&load.modules, &load.asts, &load.sources, &mut ids);
    (load, resolved, ids)
}

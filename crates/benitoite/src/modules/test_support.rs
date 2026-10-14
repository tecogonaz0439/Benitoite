//! ファイルシステムを使うテストの一時ディレクトリ（設計書 07-03「テストの設計の原則」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used)]

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT: AtomicU64 = AtomicU64::new(0);

/// テストが失敗して巻き戻した場合も、作ったディレクトリを削除する。
pub(super) struct Temporary(pub PathBuf);
impl Temporary {
    /// プロセスの中で一意な名前で作り、正規化したパスを保持する。
    pub(super) fn new() -> Self {
        let path = std::env::temp_dir().join(format!(
            ".module-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).unwrap();
        // 正規化の失敗にも guard を残し、macOS のリンクを解決したパスを使う。
        let mut dir = Self(path);
        dir.0 = dir.0.canonicalize().unwrap();
        dir
    }
}
impl Drop for Temporary {
    fn drop(&mut self) {
        let _removed = std::fs::remove_dir_all(&self.0);
    }
}

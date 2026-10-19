//! 仮想入口だけを差し替え、importとパッケージ探索を通常の読み込みへ渡す
//! （設計書 06-04「テストの実行」、02-02「docの位置対応」）。

use std::io;
use std::path::{Path, PathBuf};

use crate::modules::{DirEntryName, EntrySpec, ModuleFs, RealFs};

/// 実ファイルと衝突しない入口を持つ、doc一例の読み取り用入力。
pub struct VirtualInput<'a> {
    /// 通常と同じ根・設定・依存を使う独立した入口。
    pub entry: EntrySpec,
    source: &'a [u8],
    original: &'a EntrySpec,
    original_bytes: &'a [u8],
    execution_module: bool,
}

impl<'a> VirtualInput<'a> {
    /// 元モジュールの宣言やimportを補わず、例の本文だけを入口にする。
    pub fn new(
        original: &'a EntrySpec,
        original_bytes: &'a [u8],
        source: &'a [u8],
        display_name: String,
        execution_module: bool,
    ) -> Self {
        Self {
            entry: EntrySpec {
                // NULは実ファイル名にもimportの識別子にも現れない。OSへこのパスを渡さない。
                path: original.root.join("\0benitoite-doc"),
                root: original.root.clone(),
                display_name,
            },
            source,
            original,
            original_bytes,
            execution_module,
        }
    }
}

impl ModuleFs for VirtualInput<'_> {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
        if path == self.entry.path {
            Ok(self.source.to_vec())
        } else if RealFs
            .canonicalize(&self.original.path)
            .ok()
            .is_some_and(|original| RealFs.canonicalize(path).ok().as_ref() == Some(&original))
        {
            Ok(self.original_bytes.to_vec())
        } else {
            RealFs.read_file(path)
        }
    }

    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>> {
        RealFs.list_dir(dir)
    }

    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
        if path == self.entry.path {
            if self.execution_module {
                // mainを持つ元入口へのimportは、通常のE0320の照合で拒否する。
                RealFs.canonicalize(&self.original.path)
            } else {
                Ok(RealFs
                    .canonicalize(&self.entry.root)?
                    .join("\0benitoite-doc"))
            }
        } else {
            RealFs.canonicalize(path)
        }
    }
}

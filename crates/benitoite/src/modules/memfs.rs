//! テスト用のファイルシステム（設計書 02-04「モジュールの探し方」、実装プラン F05）。
//! ファイルの名前から項目を作り、大小文字の違いとシンボリックリンクを再現する。

use std::collections::{BTreeMap, BTreeSet};
use std::io;
use std::path::{Component, Path, PathBuf};

use crate::base::IdGen;
use crate::prelude;

use super::{DirEntryName, EntrySpec, LoadOutput, ModuleFs, load_program};

/// 仮の根 `/root` を持つファイルシステム。絶対パスを与えれば根の外にも置ける。
pub(crate) struct MemFs {
    files: BTreeMap<PathBuf, Vec<u8>>,
    links: BTreeMap<PathBuf, PathBuf>,
    directories: BTreeSet<PathBuf>,
    /// 真ならファイルを開く際に大小文字を区別しない。項目の一覧には保存した名前を返す。
    pub case_insensitive: bool,
}

impl Default for MemFs {
    fn default() -> Self {
        Self {
            files: BTreeMap::new(),
            links: BTreeMap::new(),
            directories: BTreeSet::from([PathBuf::from("/"), PathBuf::from("/root")]),
            case_insensitive: false,
        }
    }
}

impl MemFs {
    /// 相対パスを `/root` の下のファイルとして加える。
    pub fn new(files: &[(&str, &str)]) -> Self {
        let mut fs = Self::default();
        for (path, text) in files {
            fs.add_file(path, text.as_bytes().to_vec());
        }
        fs
    }

    /// 内容を変換せずに保存する。UTF-8 でないファイルも作れる。
    pub fn add_file(&mut self, path: impl AsRef<Path>, bytes: Vec<u8>) {
        let path = rooted(path.as_ref());
        self.directories
            .extend(path.ancestors().skip(1).map(Path::to_path_buf));
        self.files.insert(path, bytes);
    }

    /// シンボリックリンクを加える。相対の指す先はリンクのあるディレクトリから解決する。
    pub fn add_link(&mut self, path: impl AsRef<Path>, target: impl AsRef<Path>) {
        let path = rooted(path.as_ref());
        self.directories
            .extend(path.ancestors().skip(1).map(Path::to_path_buf));
        self.links.insert(path, target.as_ref().to_path_buf());
    }

    fn stored_path(&self, path: &Path) -> Option<PathBuf> {
        if self.files.contains_key(path)
            || self.links.contains_key(path)
            || self.directories.contains(path)
        {
            return Some(path.to_path_buf());
        }
        let mut names = self
            .files
            .keys()
            .chain(self.links.keys())
            .chain(self.directories.iter());
        names
            .find(|stored| {
                *stored == path
                    || (self.case_insensitive
                        && stored
                            .to_string_lossy()
                            .eq_ignore_ascii_case(&path.to_string_lossy()))
            })
            .cloned()
    }

    fn resolve(&self, path: &Path) -> io::Result<PathBuf> {
        let mut path = normalize(&rooted(path));
        let mut visited = BTreeSet::new();
        loop {
            if !visited.insert(path.clone()) {
                return Err(io::Error::from(io::ErrorKind::InvalidInput));
            }
            let mut prefix = PathBuf::new();
            let mut replaced = None;
            let mut components = path.components();
            while let Some(component) = components.next() {
                prefix.push(component);
                let Some(stored) = self.stored_path(&prefix) else {
                    return Err(io::Error::from(io::ErrorKind::NotFound));
                };
                prefix = stored;
                if let Some(target) = self.links.get(&prefix) {
                    let mut resolved = if target.is_absolute() {
                        target.clone()
                    } else {
                        prefix.parent().unwrap_or(Path::new("/")).join(target)
                    };
                    resolved.extend(components);
                    replaced = Some(normalize(&resolved));
                    break;
                }
            }
            if let Some(next) = replaced {
                path = next;
            } else {
                return Ok(prefix);
            }
        }
    }
}

impl ModuleFs for MemFs {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
        let path = self.resolve(path)?;
        self.files
            .get(&path)
            .cloned()
            .ok_or_else(|| io::Error::from(io::ErrorKind::NotFound))
    }

    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>> {
        let dir = self.resolve(dir)?;
        if !self.directories.contains(&dir) {
            return Err(io::Error::from(io::ErrorKind::NotADirectory));
        }
        let paths: BTreeSet<_> = self
            .files
            .keys()
            .chain(self.links.keys())
            .chain(self.directories.iter())
            .collect();
        let mut entries = Vec::new();
        for path in paths {
            if path.parent() != Some(dir.as_path()) {
                continue;
            }
            let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
                continue;
            };
            let resolved = if self.links.contains_key(path) {
                self.resolve(path)?
            } else {
                path.to_path_buf()
            };
            entries.push(DirEntryName {
                name: name.to_owned(),
                is_dir: self.directories.contains(&resolved),
            });
        }
        Ok(entries)
    }

    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
        self.resolve(path)
    }
}

fn rooted(path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        Path::new("/root").join(path)
    }
}

fn normalize(path: &Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            Component::ParentDir => {
                result.pop();
            }
            Component::CurDir => {}
            Component::Normal(_) | Component::RootDir | Component::Prefix(_) => {
                result.push(component)
            }
        }
    }
    result
}

/// 最初のファイルを入口として標準ライブラリとともに読み、続く検査用にノード番号の状態も返す。
pub(crate) fn load_files(files: &[(&str, &str)]) -> (LoadOutput, IdGen) {
    let fs = MemFs::new(files);
    let path = files.first().map_or("main.bnt", |(path, _)| *path);
    let entry = EntrySpec {
        path: rooted(Path::new(path)),
        display_name: path.to_owned(),
        root: PathBuf::from("/root"),
    };
    let mut ids = IdGen::new();
    let output = load_program(&entry, prelude::STDLIB, &fs, &mut ids);
    (output, ids)
}

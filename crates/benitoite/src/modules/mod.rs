//! 読み込みの段: モジュールの探索と読み込み、モジュールの表、依存グラフと循環の検出
//! （設計書 02-04「モジュールの表」「モジュールの探し方」「依存グラフと循環の検出」「標準ライブラリのソースの持ち方」、
//! 02-02「ソースとファイル ID」、ADR 0126・0127・0156・0244）。

use std::path::PathBuf;

use crate::base::{ModuleId, NodeId, SourceTable};
use crate::diag::Diagnostic;
use crate::syntax::ast;
use crate::syntax::token::Comment;

/// 一つの検査で読むすべてのソース（標準ライブラリのソースを含む）の大きさの和の上限（512 MiB）。
/// 超えたら読み込みの誤り E0101 とする。ノード番号と束縛の番号を u32 に収めるための処理系の制限である
/// （ノードと束縛は字句に対応して作るので、数はソースの大きさの和の定数倍に収まる）。
/// ファイル一つの上限は `base::source::MAX_SOURCE_BYTES`（最小実行版のまま）。
pub const MAX_TOTAL_SOURCE_BYTES: usize = 512 * 1024 * 1024;

/// モジュールの名前の各段。利用者のモジュールは根のディレクトリからの名前（`["Lib", "Text"]`）、
/// 標準ライブラリのモジュールは `Benitoite` から始まる名前（`["Benitoite", "IO", "Console"]`）。
#[derive(Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ModulePath(pub Vec<String>);

impl ModulePath {
    /// 段をドットでつないだ形（`Lib.Text`）。診断に示す。
    pub fn dotted(&self) -> String {
        self.0.join(".")
    }
}

/// モジュールの種類（02-04「モジュールの表」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ModuleKind {
    /// 実行を始めるモジュール
    Entry,
    /// import で読み込んだ利用者のモジュール
    User,
    /// prelude のモジュール（標準ライブラリのうち import なしで使える部分）
    Prelude,
    /// prelude でない標準ライブラリのモジュール
    Stdlib,
}

/// import の宣言一つと、取り込むモジュール。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ImportLink {
    /// import の宣言のノード番号
    pub decl: NodeId,
    /// 取り込むモジュール。読み込みの誤りで決まらなかったときは `None`
    pub target: Option<ModuleId>,
}

/// モジュールの表の項目一つ。
#[derive(Clone, PartialEq, Debug)]
pub struct ModuleInfo {
    pub id: ModuleId,
    pub name: ModulePath,
    pub kind: ModuleKind,
    /// import の宣言を書いた順に並べた取り込み先（依存グラフの辺）
    pub imports: Vec<ImportLink>,
}

/// モジュールの表。モジュールの ID の値の順に並べる。読み込みを終えた後は変更しない（02-04）。
#[derive(Clone, PartialEq, Debug, Default)]
pub struct ModuleTable {
    pub modules: Vec<ModuleInfo>,
}

/// 処理系に埋め込んだ標準ライブラリのモジュール一つ（02-04「標準ライブラリのソースの持ち方」）。
/// 表は 10-14 が `prelude` モジュールに置く。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct StdlibModuleSource {
    /// `Benitoite` を除いたモジュールの名前の段（`&["IO", "Console"]`）。ソースは標準ライブラリの根の下の
    /// `IO/Console.bnt` であり、表示名は `<benitoite>/IO/Console.bnt` とする
    pub path: &'static [&'static str],
    /// prelude に入るか
    pub prelude: bool,
    /// 非公式のモジュールか（設計書 03-06「標準のモジュールと非公式のモジュール（初回リリース版）」、ADR 0286）。
    /// 真なら `import Benitoite.Unofficial.<path>` で取り込み、偽なら `import Benitoite.<path>` で取り込む。
    /// `path` は、どちらでも標準に加えた後の名前の段である
    pub unofficial: bool,
    pub text: &'static str,
}

/// 実行を始めるファイル（02-02「ソースとファイル ID」、ADR 0127）。
/// ディレクトリを指定したときの `main.bnt` の補いと表示名の組み立ては、呼び出し側（パイプライン）が行う。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EntrySpec {
    /// 読むファイルのパス
    pub path: PathBuf,
    /// 表示名（コマンドラインで与えたパス、またはディレクトリのパスに `main.bnt` を続けた名前）
    pub display_name: String,
    /// 根のディレクトリ。通常は `path` のあるディレクトリ。`test` でディレクトリを指定したときは
    /// そのディレクトリ（01-03「実行を始めるモジュール（初回リリース版）」）
    pub root: PathBuf,
}

/// ディレクトリの項目一つ（ADR 0244 の照合に使う）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct DirEntryName {
    /// ファイルシステムに保存された名前
    pub name: String,
    pub is_dir: bool,
}

/// 読み込みの段の結果。
#[derive(Debug, Default)]
pub struct LoadOutput {
    pub sources: SourceTable,
    pub modules: ModuleTable,
    /// モジュールごとの AST。添字はモジュールの ID の値
    pub asts: Vec<ast::Module>,
    /// モジュールごとのコメントの一覧。添字はモジュールの ID の値
    pub comments: Vec<Vec<Comment>>,
    /// 読み込みの誤り、字句の切り出しの誤り、構文解析の誤り、循環する import の誤り。
    /// ファイル ID の順に、各ファイルの中では字句の誤りを構文の誤りより先に並べる
    pub diagnostics: Vec<Diagnostic>,
}

use std::io;
use std::path::Path;

use crate::base::IdGen;

/// 読み込みの段がファイルシステムを読むための操作。テストはファイルシステムを使わない実装を作る。
pub trait ModuleFs {
    /// ファイルの内容を読む。
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>>;
    /// ディレクトリの項目の一覧を読む。名前はファイルシステムに保存された形で返す（ADR 0244）。
    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>>;
    /// シンボリックリンクを解決した絶対パス（02-04「モジュールの探し方」の手順 3）。
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf>;
}

/// 本番のファイルシステム（`std::fs`）。
#[derive(Clone, Copy, Debug, Default)]
pub struct RealFs;

impl ModuleFs for RealFs {
    fn read_file(&self, path: &Path) -> io::Result<Vec<u8>> {
        std::fs::read(path)
    }
    fn list_dir(&self, dir: &Path) -> io::Result<Vec<DirEntryName>> {
        let mut entries = Vec::new();
        for entry in std::fs::read_dir(dir)? {
            let entry = entry?;
            let Ok(name) = entry.file_name().into_string() else {
                continue;
            };
            entries.push(DirEntryName {
                name,
                is_dir: std::fs::metadata(entry.path())?.is_dir(),
            });
        }
        Ok(entries)
    }
    fn canonicalize(&self, path: &Path) -> io::Result<PathBuf> {
        std::fs::canonicalize(path)
    }
}

impl ModuleTable {
    pub fn get(&self, id: ModuleId) -> Option<&ModuleInfo> {
        self.modules.get(usize::try_from(id.0).ok()?)
    }
    /// 名前でモジュールを引く。
    pub fn find(&self, name: &ModulePath) -> Option<&ModuleInfo> {
        self.modules.iter().find(|module| &module.name == name)
    }
    pub fn iter(&self) -> impl Iterator<Item = &ModuleInfo> {
        self.modules.iter()
    }
}

/// 実行を始めるファイルから import を辿ってすべてのモジュールを読み、字句解析と構文解析を行う
/// （02-02「ソースとファイル ID」の 4 手順）。作業の一覧の最初に実行を始めるファイルを、続けて
/// `stdlib` のうち prelude のモジュールを表の順に置く。`stdlib` の prelude でないモジュールは、
/// import で辿れたものだけを読む（ADR 0156）。
/// すべてのファイルを読み終えた後、依存グラフの循環を明示の積み重ねで調べる（02-04「依存グラフと循環の検出」）。
/// 誤りがあっても読めたものは結果に入れる。呼び出し側は、診断に誤りが一つでもあれば名前解決に進まない。
pub fn load_program(
    entry: &EntrySpec,
    stdlib: &[StdlibModuleSource],
    fs: &dyn ModuleFs,
    ids: &mut IdGen,
) -> LoadOutput {
    load::load(entry, stdlib, fs, ids)
}

mod cycle;
mod find;
mod load;
mod text;

#[cfg(test)]
pub(crate) mod memfs;
#[cfg(test)]
mod tests;

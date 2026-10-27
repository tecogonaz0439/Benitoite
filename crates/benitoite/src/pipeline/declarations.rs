//! 本体を検査せず、解決済みの宣言を生成道具に渡す（設計書 02-01「宣言だけの収集」）。

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::Mutex;

use crate::base::{IdGen, SourceTable};
use crate::diag::Diagnostic;
use crate::modules::{EntrySpec, ModuleFs, ModuleKind, ModuleTable};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::Module;
use crate::typeck::TypeckOutput;

/// 宣言の構造を所有する情報。型・制約は通常の型検査と同じ表現である。
/// AST の本体は構文解析済みだが、参照・型・定数値の表には本体の結果を含まない。
/// `CheckedProgram` として実行・コンパイルへ渡すことはできない。
#[derive(Debug)]
pub struct DeclarationInventory {
    /// 読み込んだ全ファイルの識別と元のバイト列。位置はこの表を指す。
    pub sources: Arc<SourceTable>,
    /// 読み込みで成功した全ファイル。依存のハッシュ検証だけが読んだ入力も含む。
    /// 埋め込みの標準ソースは `sources` に保持する。
    pub files: Vec<DeclarationFile>,
    /// 解決名・import の依存関係。
    pub modules: ModuleTable,
    /// 宣言順・型注釈・元の位置。
    pub asts: Vec<Module>,
    /// 宣言・import・シグネチャの名前解決と可視性。
    /// Data/RecordのBinding.opaqueとmoduleを保ち、生成先から内部表現を使えるか判定できる。
    /// 内部の構成子・欄の表は削らない。
    pub resolved: ResolveOutput,
    /// 解決した型の構造・関数のシグネチャ・型クラスとエフェクト。
    /// 本体の表は空であり、`main` は実行可能な入口を保証しない。
    pub types: TypeckOutput,
}

/// 読み込み時点のファイルの同一性と内容。後で読み直してハッシュを取らない。
#[derive(Debug)]
pub struct DeclarationFile {
    /// ファイルシステムへ渡したパス。
    pub path: PathBuf,
    /// 読めた時点の生バイト列。
    pub bytes: Vec<u8>,
}

struct RecordingFs<'a> {
    inner: &'a dyn ModuleFs,
    files: Mutex<BTreeMap<PathBuf, Vec<u8>>>,
}
impl ModuleFs for RecordingFs<'_> {
    fn read_file(&self, path: &Path) -> std::io::Result<Vec<u8>> {
        let bytes = self.inner.read_file(path)?;
        let mut files = self
            .files
            .lock()
            .map_err(|e| std::io::Error::other(e.to_string()))?;
        // 同じ入力の二度目の読み取りが変わっていたら、AST とハッシュを対応させられない。
        if files.get(path).is_some_and(|previous| *previous != bytes) {
            return Err(std::io::Error::other(text::INPUT_CHANGED));
        }
        files.insert(path.to_path_buf(), bytes.clone());
        Ok(bytes)
    }
    fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf> {
        self.inner.canonicalize(path)
    }
    fn list_dir(&self, path: &Path) -> std::io::Result<Vec<crate::modules::DirEntryName>> {
        self.inner.list_dir(path)
    }
}

mod text {
    pub const INPUT_CHANGED: &str = "input changed during declaration collection";
}

/// 宣言だけの収集結果。通常の `check` の成功とは区別する。
#[derive(Debug)]
pub struct DeclarationResult {
    /// 失敗時にも、読めたソースを診断とともに返す。
    pub sources: Arc<SourceTable>,
    /// 通常のパイプラインと同じ診断・並び順・依存の警告の抑制。
    pub diagnostics: Vec<Diagnostic>,
    /// 宣言の検査に誤りがなければ `Some`。本体の正しさを意味しない。
    pub inventory: Option<DeclarationInventory>,
}

/// 読み込み・構文解析・宣言の名前解決・型と制約の検査を行う。
/// 本体の名前解決・型検査・定数の評価・実行・外部コンポーネントとの照合は行わない。
/// 通常の段と同じスタックと panic 境界を使い、失敗は既存の診断で返す。
pub fn collect_declarations(entry: &EntrySpec, fs: &(dyn ModuleFs + Sync)) -> DeclarationResult {
    let failure =
        |message: &str, panic: Option<&crate::runtime::panic::PanicReport>| DeclarationResult {
            sources: Arc::new(SourceTable::new()),
            diagnostics: vec![crate::runtime::report::internal_diagnostic(
                "declarations",
                message,
                panic,
                crate::runtime::report::FaultThread::Stage,
            )],
            inventory: None,
        };
    match super::on_large_stack(|| crate::runtime::panic::catch(|| collect(entry, fs))) {
        Ok(Ok(result)) => result,
        Ok(Err(panic)) => failure(&panic.message, Some(&panic)),
        Err(error) => failure(&error.to_string(), None),
    }
}

fn collect(entry: &EntrySpec, fs: &dyn ModuleFs) -> DeclarationResult {
    let fs = RecordingFs {
        inner: fs,
        files: Mutex::new(BTreeMap::new()),
    };
    let mut ids = IdGen::new();
    let loaded = crate::modules::load_program(entry, crate::prelude::STDLIB, &fs, &mut ids);
    let hidden = loaded
        .modules
        .iter()
        .filter(|m| matches!(m.kind, ModuleKind::Package | ModuleKind::PackageConfig))
        .map(|m| m.id.file())
        .collect();
    // 並びと警告の規則を check と共用し、成功値だけを別の型で返す。
    let mut result = super::CheckResult {
        sources: Arc::new(loaded.sources),
        entry: None,
        diagnostics: vec![],
        interval_analysis: Default::default(),
        program: None,
    };
    super::append_stage(&mut result, loaded.diagnostics, &hidden);
    let mut inventory = None;
    if result.error_count() == 0 {
        let mut resolved = crate::resolve::resolve_declarations(
            &loaded.modules,
            &loaded.asts,
            &result.sources,
            &mut ids,
        );
        super::append_stage(
            &mut result,
            std::mem::take(&mut resolved.diagnostics),
            &hidden,
        );
        if result.error_count() == 0 {
            let (types, diagnostics) = crate::typeck::collect_declarations(
                &loaded.modules,
                &loaded.asts,
                &result.sources,
                &resolved,
            );
            super::append_stage(&mut result, diagnostics, &hidden);
            if result.error_count() == 0 {
                inventory = Some(DeclarationInventory {
                    sources: Arc::clone(&result.sources),
                    modules: loaded.modules,
                    asts: loaded.asts,
                    resolved,
                    types,
                    files: fs
                        .files
                        .into_inner()
                        .unwrap_or_else(|e| e.into_inner())
                        .into_iter()
                        .map(|(path, bytes)| DeclarationFile { path, bytes })
                        .collect(),
                });
            }
        }
    }
    DeclarationResult {
        sources: result.sources,
        diagnostics: result.diagnostics,
        inventory,
    }
}

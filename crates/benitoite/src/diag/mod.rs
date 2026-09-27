//! 診断の内部の表現と、診断を組み立てる手段（設計書 02-10）。
//! 文言は codes.rs の表の型板から作り、診断を出す処理に英語の文を直接書かない（ADR 0033）。

pub mod codes;
pub mod render;

pub use codes::{CodeInfo, DiagCode};

use crate::base::Span;

/// 重大度。最小実行版の段は警告を出さない（02-10）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Severity {
    Error,
    Warning,
}

/// 報告の種類。JSON の `kind` の値に対応する（02-10「JSON の形式」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReportKind {
    /// 検査の誤りと警告（`E`・`W` のコード）
    Check,
    /// 処理系の制限（`L` のコード）
    Limit,
    /// 実行時エラー（`R01nn`・`R02nn`）
    Runtime,
    /// 資源の不足（`R09nn`）
    Resource,
    /// 実行の開始前の誤り（`R03nn`）
    Args,
    /// 処理系の不具合（コードなし）
    Internal,
}

/// span とそれに添える短いラベル。ラベルは空でもよい。
#[derive(Clone, PartialEq, Debug)]
pub struct Label {
    pub span: Span,
    pub text: String,
}

/// 呼び出しの履歴の一段の名前（02-10「実行時エラーと資源の不足の報告」）。
#[derive(Clone, PartialEq, Debug)]
pub enum FrameName {
    /// 利用者のトップレベルの関数の名前、または修飾した名前（`List.map`、`Int.floorDiv`）
    Named(String),
    /// 利用者のラムダ。span はラムダを書いた位置。表示は `<lambda ファイル:行:列>`
    Lambda(Span),
}

#[derive(Clone, PartialEq, Debug)]
pub struct TraceFrame {
    pub name: FrameName,
    /// その関数を呼び出した位置。`main` と、prelude のソースの中から呼ばれた段は持たない
    pub call_site: Option<Span>,
}

/// 内側から外側へ並べた呼び出しの履歴。20 段を超えるときは内側 10 段と外側 10 段だけを持ち、
/// 省いた段の数を `omitted` に入れる（ADR 0034）。
#[derive(Clone, PartialEq, Debug)]
pub struct CallTrace {
    pub frames: Vec<TraceFrame>,
    pub omitted: u32,
}

/// 一つの診断・報告。
#[derive(Clone, PartialEq, Debug)]
pub struct Diagnostic {
    pub kind: ReportKind,
    pub severity: Severity,
    /// 処理系の不具合では `None`
    pub code: Option<DiagCode>,
    pub message: String,
    pub primary: Option<Label>,
    pub secondary: Vec<Label>,
    pub notes: Vec<String>,
    pub helps: Vec<String>,
    /// 実行時エラーと資源の不足の呼び出しの履歴
    pub trace: Option<CallTrace>,
    /// 処理系の不具合のバックトレース（取得できたとき）
    pub backtrace: Option<String>,
}

impl Diagnostic {
    pub fn is_error(&self) -> bool {
        self.severity == Severity::Error
    }
}

/// 診断を組み立てる手段。型板の `{名前}` を `arg` で与えた値で置き換える。
///
/// ```ignore
/// let d = DiagBuilder::new(DiagCode::E0401)
///     .arg("expected", "Int")
///     .arg("found", "String")
///     .primary(span)
///     .secondary(decl_span, "declared")
///     .note("because_let_annotation")
///     .build();
/// ```
///
/// `secondary`・`note`・`help`・`primary_label` の第 2 引数は、そのコードの `extras` の鍵である。
/// 鍵が表にないときと、型板の `{名前}` に値がないときは、型板をそのまま残す
/// （ゴールデンテストの期待値と食い違うので、テストで見つかる）。
#[derive(Debug)]
pub struct DiagBuilder {
    code: DiagCode,
    args: Vec<(&'static str, String)>,
    primary: Option<(Span, Option<&'static str>)>,
    secondary: Vec<(Span, &'static str)>,
    notes: Vec<&'static str>,
    helps: Vec<&'static str>,
}

impl DiagBuilder {
    pub fn new(code: DiagCode) -> DiagBuilder {
        DiagBuilder {
            code,
            args: Vec::new(),
            primary: None,
            secondary: Vec::new(),
            notes: Vec::new(),
            helps: Vec::new(),
        }
    }

    pub fn arg(mut self, key: &'static str, value: impl Into<String>) -> DiagBuilder {
        self.args.push((key, value.into()));
        self
    }

    /// 主な位置。ラベルはコードの `label` の型板で作る。
    pub fn primary(mut self, span: Span) -> DiagBuilder {
        self.primary = Some((span, None));
        self
    }

    /// 主な位置。ラベルは `extras` の鍵 `key` の型板で作る。
    pub fn primary_label(mut self, span: Span, key: &'static str) -> DiagBuilder {
        self.primary = Some((span, Some(key)));
        self
    }

    pub fn secondary(mut self, span: Span, key: &'static str) -> DiagBuilder {
        self.secondary.push((span, key));
        self
    }

    pub fn note(mut self, key: &'static str) -> DiagBuilder {
        self.notes.push(key);
        self
    }

    pub fn help(mut self, key: &'static str) -> DiagBuilder {
        self.helps.push(key);
        self
    }

    pub fn build(self) -> Diagnostic {
        let info = self.code.info();
        let fill = |template: &str| codes::fill_template(template, &self.args);
        let extra = |key: &str| {
            let template = info
                .extras
                .iter()
                .find(|(k, _)| *k == key)
                .map_or(key, |(_, t)| *t);
            fill(template)
        };
        let primary = self.primary.map(|(span, key)| Label {
            span,
            text: match key {
                Some(key) => extra(key),
                None => fill(info.label),
            },
        });
        Diagnostic {
            kind: info.kind,
            severity: Severity::Error,
            code: Some(self.code),
            message: fill(info.message),
            primary,
            secondary: self
                .secondary
                .iter()
                .map(|(span, key)| Label {
                    span: *span,
                    text: extra(key),
                })
                .collect(),
            notes: self.notes.iter().map(|key| extra(key)).collect(),
            helps: self.helps.iter().map(|key| extra(key)).collect(),
            trace: None,
            backtrace: None,
        }
    }
}

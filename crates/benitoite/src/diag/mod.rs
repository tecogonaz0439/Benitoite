//! 診断の内部の表現と、診断を組み立てる手段（設計書 02-10）。
//! 文言は codes.rs の表の型板から作り、診断を出す処理に英語の文を直接書かない（ADR 0033）。

pub mod codes;
pub mod render;

pub use codes::{CodeInfo, DiagCode};

use crate::base::Span;

/// 重大度（02-10「診断の内部の表現」）。`W` のコードは `Warning`、ほかは `Error`。
/// `--deny-warnings` で誤りとして扱った警告は `Error` に変える（`Diagnostic::deny_warning`）。
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
    /// 実行時エラー（`R01nn`・`R02nn`・`R04nn`〜`R08nn`・`R10nn`）
    Runtime,
    /// 資源の不足（`R09nn`）
    Resource,
    /// `Process.exit` と中断の要求で止める途中の解放の失敗（`R04nn`。02-10「解放の失敗の報告」）
    Release,
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

/// 置き換え一つ（02-10「修正案」）。範囲が空なら挿入、`replacement` が空なら削除を表す。
#[derive(Clone, PartialEq, Debug)]
pub struct Edit {
    pub span: Span,
    pub replacement: String,
}

/// 修正案一つ。置き換えを持たない修正案の `edits` は空。一つの修正案の置き換えは互いに重ならない。
#[derive(Clone, PartialEq, Debug)]
pub struct Help {
    pub message: String,
    pub edits: Vec<Edit>,
}

/// 呼び出しの履歴の一段の名前（02-10「実行時エラーと資源の不足の報告」）。
#[derive(Clone, PartialEq, Debug)]
pub enum FrameName {
    /// 利用者のトップレベルの関数（実行を始めるモジュールでなければモジュールの名前で修飾する。`Report.format`）、
    /// 実装のメソッド（`Show[Person].show`）、標準ライブラリの公開の関数と値として使った組み込みの関数と操作
    /// （`List.map`、`Console.writeLine`）
    Named(String),
    /// 利用者のラムダ。span はラムダを書いた位置。表示は `<lambda ファイル:行:列>`
    Lambda(Span),
    /// 利用者の `handle` の本体。表示は `<handle ファイル:行:列>`
    Handle(Span),
    /// 利用者の `handle` の節。表示は `<case Log.write ファイル:行:列>`
    Case { operation: String, span: Span },
    /// 利用者の `lazy` の本体。表示は `<lazy ファイル:行:列>`
    Lazy(Span),
}

#[derive(Clone, PartialEq, Debug)]
pub struct TraceFrame {
    pub name: FrameName,
    /// その関数を呼び出した位置（タスクの起動の履歴では、タスクを起動した呼び出しの位置）。
    /// `main` の段、タスクの最初の段、標準ライブラリのソースの中から呼ばれた段は持たない
    pub call_site: Option<Span>,
}

/// 内側から外側へ並べた呼び出しの履歴。20 段を超えるときは内側 10 段と外側 10 段だけを持ち、
/// 省いた段の数を `omitted` に入れる（ADR 0034）。
#[derive(Clone, PartialEq, Debug)]
pub struct CallTrace {
    pub frames: Vec<TraceFrame>,
    pub omitted: u32,
}

/// 行き詰まりで待つタスク一つ（02-10「実行時エラーと資源の不足の報告」の R1001）。
#[derive(Clone, PartialEq, Debug)]
pub struct WaitingTask {
    /// `main` のタスクは `Named("main")` で位置なし。ほかのタスクは起動の履歴の最も内側の段
    pub task: TraceFrame,
    /// 待つ種類（`Task.await`、`TaskGroup release` など。runtime::report の `text` の語）
    pub waits_for: String,
    /// 待つ位置。主な位置と同じ規則で作る（02-08「実行時エラーの情報の記録」）
    pub location: Option<Span>,
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
    pub helps: Vec<Help>,
    /// 実行時エラー・資源の不足・解放の失敗の呼び出しの履歴。行き詰まりでは段のない履歴
    pub trace: Option<CallTrace>,
    /// タスクの起動の履歴（内側のタスクから `main` のタスクまで）。`main` のタスクで起きたときは空
    pub task_origins: Vec<TraceFrame>,
    /// 行き詰まりで待つタスク（起動した順）。R1001 のほかでは空
    pub waiting: Vec<WaitingTask>,
    /// 処理系の不具合のバックトレース（取得できたとき）
    pub backtrace: Option<String>,
}

impl Diagnostic {
    pub fn is_error(&self) -> bool {
        self.severity == Severity::Error
    }

    pub fn is_warning(&self) -> bool {
        self.severity == Severity::Warning
    }

    /// 注記を末尾に加える（止める途中の解放の失敗、書き出しの失敗など、組み立てた後に加わる注記）。
    pub fn add_note(&mut self, text: String) {
        self.notes.push(text);
    }

    /// `--deny-warnings` で警告を誤りとして扱う（02-10「警告の扱い」）。コードは `W` のまま変えず、
    /// 重大度を誤りに変えて、誤りとして扱ったことを注記に加える。警告でなければ何もしない。
    pub fn deny_warning(&mut self) {
        if self.severity == Severity::Warning {
            self.severity = Severity::Error;
            self.notes
                .push(String::from(codes::text::DENIED_WARNING_NOTE));
        }
    }
}

/// 診断を組み立てる手段。型板の `{名前}` を `arg` で与えた値で置き換える。
///
/// ```ignore
/// let d = DiagBuilder::new(DiagCode::E0334)
///     .arg("name", "total")
///     .primary(span)
///     .secondary(earlier, "visible")
///     .help_edits("shadow", vec![Edit { span: keyword, replacement: String::from("shadow") }])
///     .build();
/// ```
///
/// `secondary`・`note`・`help`・`help_edits`・`primary_label` の鍵は、そのコードの `extras` の鍵である。
/// 鍵が表にないときと、型板の `{名前}` に値がないときは、型板をそのまま残す
/// （ゴールデンテストの期待値と食い違うので、テストで見つかる）。
#[derive(Debug)]
pub struct DiagBuilder {
    code: DiagCode,
    kind: Option<ReportKind>,
    args: Vec<(&'static str, String)>,
    primary: Option<(Span, Option<&'static str>)>,
    secondary: Vec<(Span, &'static str)>,
    notes: Vec<&'static str>,
    helps: Vec<(&'static str, Vec<Edit>)>,
}

impl DiagBuilder {
    pub fn new(code: DiagCode) -> DiagBuilder {
        DiagBuilder {
            code,
            kind: None,
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

    /// 報告の種類をコードの表と違うものにする（R0401 を `Release` として報告するときだけ使う）。
    pub fn kind(mut self, kind: ReportKind) -> DiagBuilder {
        self.kind = Some(kind);
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

    /// 置き換えを持たない修正案。
    pub fn help(mut self, key: &'static str) -> DiagBuilder {
        self.helps.push((key, Vec::new()));
        self
    }

    /// 置き換えを持つ修正案。`key` はそのコードの `fixes` に挙げた鍵でなければならない（F16 のテストで確かめる）。
    pub fn help_edits(mut self, key: &'static str, edits: Vec<Edit>) -> DiagBuilder {
        self.helps.push((key, edits));
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
            kind: self.kind.unwrap_or(info.kind),
            severity: info.severity,
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
            helps: self
                .helps
                .into_iter()
                .map(|(key, edits)| Help {
                    message: extra(key),
                    edits,
                })
                .collect(),
            trace: None,
            task_origins: Vec::new(),
            waiting: Vec::new(),
            backtrace: None,
        }
    }
}

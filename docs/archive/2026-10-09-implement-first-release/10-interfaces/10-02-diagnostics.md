# 診断

本章は、診断の内部の表現、診断コードの表と文言の型板、診断を組み立てる手段、診断を書き出す関数のシグネチャを定める。設計書の対応する章は[診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)であり、各段が出す診断の内容は仕様の各章と処理系の各章が定める。最小実行版の章（最小実行版の実装プランの 10-02）を引き継ぎ、初回リリース版で加わる次のものを加える。

- 置き換えを持つ修正案（[ADR 0035](../../2026-10-09-design-first-release/decisions/0035-help-suggestions-without-rewriting.md)）
- 警告と `--deny-warnings`（[ADR 0166](../../2026-10-09-design-first-release/decisions/0166-warnings-reported-by-run-and-deny-option.md)）
- 複数のファイルからなるプログラムの位置（[ADR 0156](../../2026-10-09-design-first-release/decisions/0156-module-loading-and-whole-program-checking.md)）
- タスクの起動の履歴、行き詰まりの記録、解放の失敗の報告（`"release"`）
- 初回リリース版の診断コード（E01〜E08、W03〜W05、R01〜R10、L01）

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C02

本章のコードは C02 が置く。U2 第 1 段（R01〜R14）は診断を作らないので、C01 は本章を置かない（`lib.rs` の `pub mod diag;` に合わせて、道具が中身のないモジュールを作る）。最小実行版の `diag` は、C04 が `src/legacy/diag/` へ移す。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/diag/mod.rs` | 置く（`file=`） | — |
| `src/diag/codes.rs` | 置く（`file=`） | —（後述の「型板の直し方」の範囲で、コードを出す作業が直す） |
| `src/diag/render.rs` | 置く（`sig=`） | F16 |

`render.rs` の中身は、最小実行版の `src/legacy/diag/render.rs` を写して、本章の「診断の書き出し」の変更を加える。

## 診断の内部の表現

02-10「診断の内部の表現」の項目を、構造体の欄にする。実行時エラーの呼び出しの履歴・タスクの起動の履歴・行き詰まりで待つタスクの並び、処理系の不具合のバックトレースも同じ構造体に持たせ、文章と JSON の両方の形式をこの一つの表現から作る（02-10「JSON の形式」の最後の段落）。

最小実行版からの変更は次のとおりである。

| 項目 | 変更 |
|---|---|
| `ReportKind` | `Release`（`Process.exit` と中断の要求で止める途中の解放の失敗）を加える |
| `Diagnostic::helps` | 文字列の並びから、文と置き換えの並びの組（`Help`）の並びに変える |
| `FrameName` | `handle` の本体・節と `lazy` の本体の段を加える（02-10「実行時エラーと資源の不足の報告」） |
| `Diagnostic` の欄 | タスクの起動の履歴（`task_origins`）と、行き詰まりで待つタスク（`waiting`）を加える |
| `DiagBuilder` | 重大度をコードの表から決める（`W` のコードは警告）。置き換えを持つ修正案（`help_edits`）と、報告の種類を変える `kind` を加える |

```rust file=src/diag/mod.rs
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
```

`Option::unwrap_or` は lint の `unwrap_used` に当たらない。処理系の不具合の報告（コードを持たない）は `DiagBuilder` を使わず、`runtime::report::internal_diagnostic`（[パイプラインと CLI](10-13-pipeline-and-cli.md)）が `Diagnostic` を直接組み立てる。

## 診断コードの表

### 番号の付け方

02-10「診断コード」の区分に従って番号を振る。

- 一度公開したコードの意味は変えない（ADR 0031）。最小実行版で割り当てた番号は、意味を変えずに使い続ける。文言の型板は、初回リリース版の構文と型の名前（`function`・`Integer`・`Boolean`・`bind` など）に合わせて書き直した。同じ誤りを初回リリース版の言語で言い直したものであり、意味は変えていない。
- 初回リリース版の検査は、各区分の続きの番号に割り当てる。区分の中の番号は 01 から順に振る。
- 最小実行版の診断のうち、初回リリース版で起きなくなるものは廃止し、番号を使い回さない。廃止したコードは `DiagCode` から除き、`RETIRED` に残す。
- 本章の後に加えるコード（U3・U4 と、作業の途中で見つかった誤り）は、区分の続きの番号を使い、本章の表と `codes.rs` を同時に改める。コードを加えるときは、作業を止めて報告する（[作業の進め方](../00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。

最小実行版から意味の範囲を広げたコードが二つある。E0305（型の名前の重なり）は、初回リリース版で型と同じ名前空間に入るレコード・型の別名・型クラス・エフェクト・import の名前にも使う。E0306（関数の名前の重なり）は、関数と同じ名前空間に入る定数とエフェクトの操作にも使う。どちらも「同じ名前空間の名前の重なり」という同じ誤りであり、名前空間に入るものが増えただけなので、新しいコードを割り当てなかった。この扱いは 02-10「診断コード」にも定めた（2026-09-30、設計者の判断）。

廃止したコードは次のとおりである。

| コード | 最小実行版の意味 | 廃止した理由 |
|---|---|---|
| E0111 | 文字列の中の `${` は予約 | 文字列補間を初回リリース版で加えた（01-01「文字列リテラル」） |
| E0117 | 予約語を名前に使った | 初回リリース版に予約語はない（02-03「字句」）。キーワードを名前に使った誤りは E0216 |
| E0205 | 関数の本体の `{` を次の行に書いた | ブロックを波括弧で書かない（ADR 0108）。波括弧は E0212 |
| E0307 | prelude の名前を型の名前に使った | 利用者の名前は prelude の名前を隠してよい（01-03「標準ライブラリの名前空間と prelude」） |
| E0308 | `Some` などを型の名前に使った | 構成子を型の名前で修飾して書くので、同じ名前の型を宣言してよい（ADR 0099） |
| E0317 | `Option.Some` を修飾して書いた | 修飾して書く規則に変わった（ADR 0099）。修飾しない構成子は E0331 |

初回リリース版の検査に割り当てた後に使わないことにしたコードも、同じく `DiagCode` から除き、`RETIRED` に残す（欠番）。

| コード | 割り当てた意味 | 使わない理由 |
|---|---|---|
| E0444 | 文字列リテラルか定数式を渡した `Regex.compile` の正規表現の構文の誤り | 初回リリース版では、検査の時点で正規表現の構文を確かめない（[ADR 0316](../../2026-10-09-design-first-release/decisions/0316-no-compile-time-regex-check-in-first-release.md)）。作業 F17 を取りやめた |

### 表の項目

- `message` は 1 行目の文言、`label` は主な位置のラベルの型板である。
- `extras` は、補助の位置のラベル・注記・修正案に使う型板を、鍵で引く表である。
- `fixes` は、`extras` の鍵のうち、置き換えを持つ修正案（`DiagBuilder::help_edits`）に使う鍵である（02-10「修正案」の「置き換えを付けるかどうか」）。置き換えは、それを当てれば誤りがなくなると処理系が決められるときだけ付ける。`fixes` の鍵でも、呼び出し側が置き換えを決められない場合（綴りの近い名前の候補が二つ以上あるなど）は、`help` で文だけを示す。
- `explanation` は、コードの説明（誤りの意味と、よくある直し方）である。サーバモードの MCP の道具 `explain` が引く（02-10、[ADR 0210](../../2026-10-09-design-first-release/decisions/0210-mcp-in-server-chapter-and-explain-tool.md)）。初回リリース版の CLI は表示しない。
- 重大度は、コードの頭の文字で決める（`W` は警告、ほかは誤り）。報告の種類（`kind`）は表に書き、R0401 を `Release` として報告するときだけ `DiagBuilder::kind` で変える。
- 型板の中の `{名前}` は、`DiagBuilder::arg` で与える値で置き換える。型の名前は型の表示（[型と型検査](10-05-types.md)の型の表示）で、識別子はソースの綴りで、モジュールの名前はドットでつないだ形（10-04 の `ModulePath::dotted`）で与える。型板の中で、コードの字面は `` ` `` で囲む。
- 型板に埋める値のうち、固定の語（種類の呼び名、構文の呼び名など）は、各段のモジュールの `text` に定数として置く（[実装の規約](../00-common/00-02-conventions.md)の「文言」）。

表は、宣言のマクロ `diag_codes!` で書く。マクロは、一つの並びから `DiagCode`、すべてのコードの並び `ALL`、`DiagCode::info` を作る。一つの項目は次の形である。

```text
<コード> <報告の種類> "<文言>" "<ラベル>" [<鍵>: "<型板>", ...] fix [<鍵>, ...] "<説明>";
```

`fix [...]` は、置き換えを持つ修正案の鍵がなければ省く。

### 型板の直し方

`codes.rs` は `file=` のコードであり、C02 が置いた後に作業が変えないのが原則である（[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。ただし、文言の型板は、コードを出す段の実装とゴールデンテストを書いて初めて過不足の分かるものがある。そこで、コードを出す作業は、次の範囲に限って `codes.rs` を直してよい。直したものは、完了の報告の「判断したこと」に挙げる。この例外は、凍結したファイルのほかの例外とあわせて [作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」にも挙げてある。範囲は本節で定める。

- そのコードの `message`・`label`・`extras` の型板の言い回しと、`explanation` を直す。誤りの意味（何を誤りとするか）を変えない。
- そのコードの `extras` に鍵を加え、`fixes` に鍵を加える。

コードを加える・消す・報告の種類を変える・番号を変える必要が生じたら、作業を止めて報告する。

### 表

```rust file=src/diag/codes.rs
//! 診断コードと文言の型板の表（設計書 02-10「診断コード」「文言の言語」、ADR 0031・0033・0035）。
//! 番号の付け方と各コードを出す段は、実装プラン 10-02「診断コードの表」「コードの一覧」で定める。

use super::{ReportKind, Severity};

/// 一つの診断コードの表の項目。
#[derive(Clone, Copy, Debug)]
pub struct CodeInfo {
    /// `E0401` などのコードの文字列
    pub id: &'static str,
    pub kind: ReportKind,
    pub severity: Severity,
    pub message: &'static str,
    /// 主な位置のラベルの型板。空文字列ならラベルを付けない
    pub label: &'static str,
    /// 鍵で引く型板（補助の位置のラベル、注記、修正案）
    pub extras: &'static [(&'static str, &'static str)],
    /// `extras` の鍵のうち、置き換えを持つ修正案に使うもの（02-10「修正案」）
    pub fixes: &'static [&'static str],
    /// コードの説明（MCP の道具 `explain` が引く。02-10）
    pub explanation: &'static str,
}

/// 廃止したコード。番号を使い回さない（ADR 0031、実装プラン 10-02「番号の付け方」）。
pub const RETIRED: &[&str] = &[
    "E0111", "E0117", "E0205", "E0307", "E0308", "E0317", "E0444",
];

/// 重大度はコードの頭の文字で決まる（`W` は警告）。
fn severity_of(id: &str) -> Severity {
    if id.starts_with('W') {
        Severity::Warning
    } else {
        Severity::Error
    }
}

macro_rules! diag_codes {
    ($(
        $code:ident $kind:ident $message:literal $label:literal
        [$($key:ident : $text:literal),* $(,)?]
        $(fix [$($fix:ident),* $(,)?])?
        $explanation:literal;
    )*) => {
        /// 診断コード。名前はコードの文字列と同じにする。
        #[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
        pub enum DiagCode {
            $($code,)*
        }

        /// すべてのコード（表の順）。
        pub const ALL: &[DiagCode] = &[$(DiagCode::$code,)*];

        impl DiagCode {
            pub fn info(self) -> CodeInfo {
                match self {
                    $(DiagCode::$code => CodeInfo {
                        id: stringify!($code),
                        kind: ReportKind::$kind,
                        severity: severity_of(stringify!($code)),
                        message: $message,
                        label: $label,
                        extras: &[$((stringify!($key), $text)),*],
                        fixes: &[$($(stringify!($fix)),*)?],
                        explanation: $explanation,
                    },)*
                }
            }
        }
    };
}

impl DiagCode {
    /// コードの文字列から引く（MCP の道具 `explain` とテストが使う）。廃止したコードと知らない文字列は `None`。
    pub fn from_id(id: &str) -> Option<DiagCode> {
        ALL.iter().copied().find(|code| code.info().id == id)
    }
}

diag_codes! {
    // ---- E01: 読み込みと字句 ----
    E0101 Check "cannot read file `{path}`" ""
        [reason: "{reason}", imported: "the module is imported here"]
        "The source file could not be read. Check the path and the file permissions. A file larger than 256 MiB, or a file that makes all sources of the program larger than 512 MiB, is also reported with this code.";
    E0102 Check "source file is not valid UTF-8" "invalid UTF-8 byte sequence" []
        "Source files must be encoded in UTF-8.";
    E0103 Check "character {char} is not allowed here" "not allowed outside literals and comments"
        [allowed: "only printable ASCII characters, spaces, tabs, and newlines may appear outside string literals, character literals, and comments"]
        "Outside literals and comments, only printable ASCII, spaces, tabs, and newlines are allowed, so that invisible or look-alike characters cannot change the meaning of code.";
    E0104 Check "invisible control character {char} is not allowed" ""
        [escape: "to include it in a value, write the escape `{escape}` in a string or character literal"]
        "Bidirectional control characters and a byte order mark after the start of the file are not allowed anywhere, even in literals, comments, and the shebang line.";
    E0105 Check "unexpected symbol `{symbol}`" "not a valid token" []
        "This symbol is not part of the language.";
    E0106 Check "semicolons are not used" "remove this `;`"
        [newline: "separate statements with a newline"]
        fix [newline]
        "Statements are separated by newlines, not semicolons.";
    E0107 Check "carriage return without a following line feed" "expected LF after CR" []
        "Line breaks must be LF or CR LF.";
    E0108 Check "unterminated string literal" "this string is not closed on this line"
        [one_line: "a string literal must end on the line where it starts; write `\\n` for a line break",
         multi_line: "for text with line breaks, use a multi-line string that starts and ends with `\"\"\"`"]
        "String literals must be closed with `\"` on the same line. Multi-line strings are written with `\"\"\"`.";
    E0109 Check "unterminated character literal" "this character literal is not closed" []
        "Character literals must be closed with `'`.";
    E0110 Check "invalid escape sequence `{escape}`" "invalid escape"
        [valid_string: "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\$`, and `\\u{...}`",
         valid_char: "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\'`, `\\$`, and `\\u{...}`",
         unicode: "`\\u{...}` must contain 1 to 6 hexadecimal digits naming a Unicode scalar value"]
        "Only the listed escape sequences may follow `\\`.";
    E0112 Check "empty character literal" "" []
        "A character literal must contain exactly one character.";
    E0113 Check "character literal contains more than one character" ""
        [use_string: "use a string literal (\"...\") for text made of more than one character"]
        fix [use_string]
        "A character literal holds exactly one Unicode scalar value. Characters built from several scalar values must be written as strings.";
    E0114 Check "control character {char} must be escaped" ""
        [escape: "write it as `{escape}`"]
        fix [escape]
        "Control characters other than tab must be written with an escape sequence inside literals.";
    E0115 Check "malformed integer literal `{text}`" ""
        [leading_zero: "decimal literals other than `0` must not start with `0`",
         underscore: "`_` must be placed between two digits",
         digit: "invalid digit for this base",
         no_digits: "the base prefix must be followed by digits",
         prefix: "base prefixes must be lowercase: `0x`, `0o`, `0b`",
         suffix: "a number must not be directly followed by a letter, a digit of another base, or `_`; separate words with a space, such as `2 mod 3`"]
        "Integer literals are decimal, or hexadecimal, octal, or binary with a lowercase prefix.";
    E0116 Check "malformed floating-point literal `{text}`" ""
        [missing_digits: "digits are required on both sides of `.`",
         leading_zero: "the integer part must not start with `0` unless it is `0`",
         underscore: "`_` must be placed between two digits",
         exponent: "the exponent needs at least one digit",
         suffix: "a number must not be directly followed by a letter or `_`; separate words with a space, such as `2 mod 3`",
         second_dot: "a number cannot contain a second `.` followed by digits"]
        "Floating-point literals have a decimal point or an exponent. Each part must contain digits.";
    E0118 Check "empty string interpolation" "`${}` contains no expression"
        [escape: "write `\\$` to include a literal `$` followed by `{`"]
        "An interpolation `${...}` must contain an expression.";
    E0119 Check "string interpolation is not closed on this line" "this `${` is not closed"
        [one_line: "an interpolation must end with `}` on the line where it starts, also inside multi-line strings"]
        "The expression of an interpolation is written on one line and closed with `}`.";
    E0120 Check "comments are not allowed inside string interpolation" ""
        [move: "move the comment outside the string literal"]
        "`//` inside `${...}` would hide the rest of the line, so comments cannot be written there.";
    E0121 Check "text after the opening `\"\"\"` of a multi-line string" ""
        [newline: "start the text on the line after `\"\"\"`"]
        fix [newline]
        "The first line of a multi-line string starts on the line after the opening `\"\"\"`.";
    E0122 Check "this line does not start with the indentation of the closing `\"\"\"`" ""
        [closing: "the closing `\"\"\"` is here",
         same_chars: "indent the line with the same spaces or tabs as the closing line"]
        "Every non-blank line of a multi-line string must start with the indentation of the closing line. The indentation is removed from every line.";
    E0123 Check "unterminated multi-line string" "this string is not closed"
        [close: "close the string with `\"\"\"` at the start of a line after indentation"]
        "A multi-line string ends with `\"\"\"` after indentation at the start of a line. The expression may continue after the closing quotes.";
    E0124 Check "malformed Decimal literal `{text}`" ""
        [exponent: "a Decimal literal cannot have an exponent",
         suffix_case: "the Decimal suffix is a lowercase `m`",
         base: "a Decimal literal must be written in decimal",
         missing_digits: "digits are required on both sides of `.`",
         leading_zero: "the integer part must not start with `0` unless it is `0`",
         underscore: "`_` must be placed between two digits",
         suffix: "`m` must not be directly followed by a letter, a digit, or `_`; separate words with a space"]
        fix [suffix_case]
        "Decimal literals are decimal numbers followed by a lowercase `m`, such as `12.50m`.";
    E0125 Check "cannot write formatted file `{path}`" ""
        [reason: "{reason}", temp_left: "the temporary file `{temp}` could not be removed"]
        "`benitoite fmt` writes the formatted source to a temporary file in the same directory and renames it over the original file. Writing or renaming failed, so the original file was left unchanged. Check the permissions of the file and its directory.";

    // ---- E02: 構文 ----
    E0201 Check "expected {expected}, found {found}" "unexpected {found}" []
        "The parser found a token that cannot appear here.";
    E0202 Check "comparison operators cannot be chained" "second comparison"
        [and: "write the comparisons separately, such as `a < b and b < c`"]
        fix [and]
        "Comparison operators are non-associative.";
    E0203 Check "`.` cannot follow a value" "method-call syntax is not supported"
        [pipe: "pass the value with a pipe, such as `xs |> List.map(f)`",
         field: "read a record field with its field function, such as `Person.name(p)` or `p |> Person.name`"]
        "A dot is only used after a module, type, record, trait, or effect name, such as `List.map` or `Shape.Circle`.";
    E0204 Check "`_` can only be a direct argument of a call" "not a call argument"
        [record: "a record construction is not a call; write a lambda instead"]
        "The placeholder `_` builds a function from a call, such as `clamp(0, _, 100)`.";
    E0206 Check "constructor `{name}` without fields must not have parentheses" ""
        [remove: "remove `()`"]
        fix [remove]
        "Constructors without fields are declared and written without parentheses.";
    E0207 Check "function names cannot be qualified with a module name" ""
        [remove: "remove `{module}.` from the name"]
        fix [remove]
        "Top-level functions are declared with a plain name. The module of a function is the file it is written in.";
    E0208 Check "the program is nested too deeply" "nesting limit of {limit} reached here" []
        "The parser limits the depth of nested syntax.";
    E0209 Check "a function type with `uses` must be parenthesized here" ""
        [paren: "write the function type in parentheses, such as `function((function() -> Unit uses Console.Write), List[Integer]) -> Unit`"]
        "`uses` reads as many effect names as possible, so a function type with `uses` inside a list of types must be parenthesized.";
    E0210 Check "`_` cannot be a lambda parameter" ""
        [name: "use a name that starts with `_`, such as `_unused`"]
        fix [name]
        "Unused lambda parameters are named with a leading `_`.";
    E0211 Check "`{symbol}` is not an operator in Benitoite" "not a Benitoite operator"
        [equal: "write `=` to compare values",
         not_equal: "write `<>` for inequality",
         and: "write `and`",
         or: "write `or`",
         not: "write `not`",
         remainder: "write `mod` for the remainder",
         question: "write `try` before the expression, such as `try parse(text)`",
         fat_arrow: "write the branch as `case pattern -> expression`"]
        fix [equal, not_equal, and, or, not, remainder]
        "Benitoite writes these operators as words or with other symbols.";
    E0212 Check "blocks are not written with braces" "braces are not used"
        [end: "close the block with `end {construct}` instead of `}`",
         open: "start the block with the keyword of the construct; it ends with `end` and the construct name, such as `end function` or `end if`"]
        "Blocks start with a keyword and end with `end` followed by the name of the construct.";
    E0213 Check "`end {found}` does not close `{expected}`" "expected `end {expected}`"
        [opened: "the `{expected}` block starts here",
         replace: "write `end {expected}`"]
        fix [replace]
        "A block is closed by `end` followed by the name of the construct that opened it.";
    E0214 Check "`{construct}` is not closed" "expected `end {construct}` before this"
        [opened: "the `{construct}` block starts here"]
        "Every block must be closed with `end` and the name of its construct.";
    E0215 Check "`with` must be on the same line as `match`" "`with` starts a new line here"
        [same_line: "put `with` at the end of the previous line, such as `match value with`"]
        fix [same_line]
        "A line break after the value of `match` ends the expression, so `with` must follow on the same line.";
    E0216 Check "`{word}` is a keyword and cannot be used as a name" "keyword used as a name"
        [rename: "choose another name"]
        "Keywords cannot be used as names of variables, functions, or types.";
    E0217 Check "parenthesized lists of values are not tuples" ""
        [pair: "use `Pair`, such as `Pair(a, b)` or the type `Pair[A, B]`",
         triple: "use `Triple`, such as `Triple(a, b, c)` or the type `Triple[A, B, C]`",
         record: "declare a `record` for four or more values"]
        "Benitoite has no tuple syntax. `Pair` and `Triple` hold two or three values, and records hold more.";
    E0218 Check "`{keyword}` cannot be used inside {context}" ""
        [lazy_body: "a `lazy` body produces one value; compute the value with an expression",
         guard: "a guard is a condition; check the value in the branch body instead",
         lambda: "`{keyword}` is allowed inside a lambda written there"]
        "`return` and `try` cannot leave a `lazy` body or a `match` guard, except inside a lambda written there.";
    E0219 Check "`import` must come before other declarations" "import after a declaration"
        [first: "the first declaration is here"]
        "All `import` declarations are written at the start of the file.";
    E0220 Check "an attribute argument must be a string literal" ""
        [plain: "write a plain string literal without interpolation, such as `@deprecated(\"use format instead\")`"]
        "Attribute arguments are string literals, and interpolation is not allowed in them.";
    E0221 Check "`public` is not allowed on {what}" ""
        [remove: "remove `public`",
         implement: "an implementation is visible wherever its trait and type are visible"]
        fix [remove]
        "Implementations and the functions inside them are not marked `public`.";
    E0222 Check "`{name}` is not a built-in constraint" ""
        [builtin: "the lowercase constraints are `equality` and `key`; traits are written with an uppercase name",
         ordered: "`ordered` can only be used in the standard library"]
        "A lowercase name in a constraint must be one of the built-in constraints.";
    E0223 Check "the built-in constraint `{name}` cannot be a supertrait" ""
        [remove: "remove `{name}` from the supertraits"]
        fix [remove]
        "Only traits can be supertraits of a trait.";
    E0224 Check "a record update must change at least one field" ""
        [use_value: "use `{value}` directly"]
        fix [use_value]
        "`Record(..value)` without fields would copy the value unchanged.";
    E0225 Check "a record pattern must name at least one field" ""
        [wildcard: "use the pattern `_` to match any value"]
        fix [wildcard]
        "`Record(..)` without fields matches every value; `_` says this directly.";
    E0226 Check "a list literal can contain at most one spread" "second spread"
        [first: "first spread here",
         concat: "join the lists with `List.concatenate`"]
        "A list literal may contain one `..e`. Join more lists with `List.concatenate`.";
    E0227 Check "`{written}` is not the spread syntax" ""
        [spread: "write `..{name}` to spread a list"]
        fix [spread]
        "A list is spread into a list literal with `..e`.";
    E0228 Check "this documentation comment is not attached to a declaration" ""
        [plain: "write a normal comment with `//`"]
        fix [plain]
        "A `///` comment must be directly followed by the declaration it documents.";
    E0229 Check "a module documentation comment must be at the start of the file" ""
        [plain: "write a normal comment with `//`"]
        fix [plain]
        "`//!` comments come before `import` declarations and other declarations.";
    E0230 Check "`let` is not used to bind names" ""
        [bind: "write `bind {name} <- {value}`",
         shadow: "if `{name}` is already a local name here, write `shadow {name} <- {value}`"]
        "A binding statement is written `bind x <- e`, or `shadow x <- e` to hide a visible local name.";
    E0231 Check "`case ... of` is not the syntax of `match`" ""
        [match_with: "write `match {value} with`"]
        "Pattern matching is written `match value with`, followed by branches `case pattern ->`.";
    E0232 Check "`when` does not start a branch" ""
        [case: "write the branch as `case {pattern} ->`"]
        "Branches of `match` and clauses of `handle` start with `case` and use `->`.";
    E0233 Check "an algebraic data type is declared with `data`" ""
        [data: "write `data {name}` and close it with `end data`"]
        fix [data]
        "`type` declares a type alias. Types with constructors are declared with `data ... end data`.";
    E0234 Check "the return type is written after `->`" "expected `->`"
        [arrow: "replace `:` with `->`"]
        fix [arrow]
        "The return type of a function, lambda, method, or operation follows `->`.";
    E0235 Check "`try` does not start a block" ""
        [result: "there are no exceptions; return a `Result` and write `try` before a call that returns `Result` or `Option`"]
        "`try` returns an `Error` or `None` to the caller early. Errors are values, and there is no exception-catching syntax.";
    E0236 Check "alternatives in a pattern are separated by commas" ""
        [comma: "write `case {first}, {second} ->`"]
        fix [comma]
        "A branch that accepts several patterns lists them separated by `,`.";
    E0237 Check "a type alias cannot list constructors" ""
        [data: "declare a `data` type with one constructor per line, closed by `end data`"]
        "`type` gives another name to an existing type. Constructors are declared in `data`.";
    E0238 Check "a branch must start with `case`" ""
        [case: "write the branch as `case {pattern} -> ...`"]
        "Every branch of `match` starts with `case` and uses `->`.";
    E0239 Check "`{word}` is not Benitoite syntax" ""
        [switch: "write `match {value} with`",
         default: "write `case _ ->`"]
        "Pattern matching is written with `match ... with` and branches `case pattern ->`.";
    E0240 Check "`break` is not needed in a branch" ""
        [remove: "remove `break`; a branch never continues into the next branch"]
        fix [remove]
        "Branches of `match` do not fall through.";
    E0241 Check "a guard is written with `if`" ""
        [if: "write `case {pattern} if {condition} ->`"]
        fix [if]
        "A branch condition follows the pattern after `if`.";
    E0242 Check "a range is written `low..high`" ""
        [range: "write `{low}..{high}`; both ends are included"]
        fix [range]
        "Range patterns include both ends and are written with `..` only.";
    E0243 Check "a lambda is written with parentheses and `end lambda`" ""
        [lambda: "write `lambda({params}) return {body} end lambda`"]
        "Lambdas are written `lambda(x) return x + 1 end lambda`.";
    E0244 Check "modules are imported by name" ""
        [by_name: "write `import {module}`, a module name relative to the directory of the starting file"]
        "`import` names a module, such as `import Lib.Text` for the file `Lib/Text.bnt`.";
    E0245 Check "`implement` must name a trait" ""
        [functions: "write top-level functions instead, such as `function describe(p: {name}) -> String`"]
        "`implement` implements a trait for a type, such as `implement Show[Person]`.";
    E0246 Check "`with` does not install a handler" ""
        [handle: "write `handle ... with case operation(args) -> ... end handle`"]
        "Handlers are written with `handle ... with` and clauses `case`. `with` also binds resources.";
    E0247 Check "attributes are written with `@` and a lowercase name" ""
        [test: "write `@test`",
         other: "the attributes are `@test`, `@test(\"...\")`, and `@deprecated(\"...\")`"]
        fix [test]
        "Attributes are written on the line before a declaration.";
    E0248 Check "a type alias is written `type Name = Type`" ""
        [alias: "write `type {name} = ...`"]
        "`type` declares a type alias; there is no `alias` keyword.";
    E0249 Check "documentation comments are written with `///`" ""
        [doc: "write each line of the documentation with `///` before the declaration"]
        "Documentation comments start with `///`, and module documentation starts with `//!`.";
    E0250 Check "a list pattern can contain at most one `..`" "second `..`"
        [first: "first `..` here"]
        "A list pattern has one rest part, such as `[first, ..rest]`.";

    E0251 Check "`fn` is not used for function declarations or lambdas" ""
        [function: "write `function {signature} ... end function`",
         lambda: "write `lambda{signature} ... end lambda`, using `return` for the result"]
        "Declare functions with `function` and write anonymous functions with `lambda`.";

    // ---- E03: 名前、import、公開 ----
    E0301 Check "cannot find `{name}` in this scope" "not found"
        [similar: "a similar name exists: {candidates}"]
        fix [similar]
        "The name is not bound by a local binding, a function, or a constant visible here.";
    E0302 Check "cannot find `{name}`" "not found"
        [similar: "a similar name exists: {candidates}"]
        fix [similar]
        "The name before `.` must be a module imported in this file, a prelude module, a type, a record, a trait, or an effect.";
    E0303 Check "`{module}` has no member `{name}`" "not found in `{module}`"
        [similar: "a similar name exists: {candidates}",
         length: "strings have no unit-less length; use `String.byteLength` (bytes) or `String.characterCount` (characters)",
         slice: "use `String.byteSlice` (byte positions) or `String.characterSlice` (character positions)",
         index_of: "use `String.byteIndexOf`, which returns a byte position",
         unwrap: "there is no `{name}`; use `{module}.unwrapOr` or `match`",
         not_reexported: "names imported by `{module}` are not visible through it; import that module directly"]
        fix [similar]
        "The module, type, record, trait, or effect does not define this name.";
    E0304 Check "`{name}` is {found_kind}, not {expected_kind}" "" []
        "Each position accepts only one kind of name.";
    E0305 Check "the name `{name}` is defined more than once" "redefined here"
        [first: "first defined here",
         import: "give the import another name with `as`, such as `{suggestion}`"]
        fix [import]
        "Types, records, type aliases, traits, effects, and import names share one namespace in a module.";
    E0306 Check "`{name}` is defined more than once" "redefined here"
        [first: "first defined here"]
        "Functions, constants, and effect operations share one namespace in a module.";
    E0309 Check "the constructor `{name}` is defined more than once in `{ty}`" "redefined here"
        [first: "first defined here"]
        "Constructor names must be unique within a type.";
    E0310 Check "the parameter `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Parameter names must be unique within a function or lambda.";
    E0311 Check "`{name}` is bound more than once in the same pattern" "bound again here"
        [first: "first bound here"]
        "A pattern cannot bind the same variable twice.";
    E0312 Check "the type parameter `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Type parameter names must be unique within a list.";
    E0313 Check "the type parameter `{name}` has the same name as a top-level declaration" ""
        [declared: "the top-level declaration is here"]
        "Type parameters and effect variables cannot reuse top-level uppercase names or `Benitoite`.";
    E0314 Check "`{name}` is an effect and cannot be used as a type" ""
        [uses_only: "effects and effect variables can only appear after `uses`"]
        "Effect names and effect variables are not types.";
    E0315 Check "`{name}` is not an effect" "expected an effect name or an effect variable"
        [qualify: "effects of other modules are written with the module name, such as `Console.Write`"]
        fix [qualify]
        "After `uses`, write effects declared in this module, `State`, effects qualified with a module name, or effect variables.";
    E0316 Check "`{name}` is not an effect" "read as part of the `uses` list"
        [paren: "if `{name}` belongs to the surrounding list, parenthesize the function type that has `uses`, such as `function((function() -> Unit uses Console.Write), Integer) -> Unit`"]
        fix [paren]
        "`uses` reads as many comma-separated names as possible, so a following list element may be taken as an effect.";
    E0318 Check "cannot find module `{module}`" "no file `{path}` under the root directory"
        [similar: "a similar module exists: {candidates}",
         case_only: "the directory has `{actual}`, which differs only in upper and lower case"]
        "A module name refers to a file under the directory of the starting file, such as `Lib/Text.bnt` for `Lib.Text`.";
    E0319 Check "the module `{module}` is outside the root directory" ""
        [resolved: "`{path}` resolves to `{target}`, outside `{root}`"]
        "Modules are imported only from the directory of the starting file and its subdirectories, after resolving symbolic links.";
    E0320 Check "the module where execution starts cannot be imported" ""
        [entry: "`{module}` is the starting file of this program"]
        "The starting module is not a library. Move the shared declarations to another module.";
    E0321 Check "`{module}` is not a standard library module" ""
        [similar: "a similar module exists: {candidates}",
         root_file: "names that start with `Benitoite` always refer to the standard library, so `{path}` cannot be imported",
         unofficial: "this module is unofficial in this version and is imported as `{suggestion}`",
         standard: "this module is a standard module in this version and is imported as `{suggestion}`"]
        fix [similar, unofficial, standard]
        "Modules whose names start with `Benitoite` are the standard library modules. Unofficial modules are imported with `Unofficial` after `Benitoite`, such as `Benitoite.Unofficial.IO.Console`.";
    E0322 Check "modules import each other in a cycle" "this import closes the cycle"
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "Imports must not form a cycle. Move the declarations the modules share to another module.";
    E0323 Check "two imports have the name `{name}`" "second import named `{name}`"
        [first: "first import named `{name}`",
         alias: "give one of them another name with `as`, such as `import {module} as {suggestion}`"]
        fix [alias]
        "Each import gives the module one name in the file, the last part of its name or the name after `as`.";
    E0324 Check "the module `{module}` is imported more than once" "imported again here"
        [first: "first imported here",
         remove: "remove this import"]
        fix [remove]
        "A module is imported once in a file.";
    E0325 Check "`Benitoite` cannot be used as a name here" ""
        [reserved: "`Benitoite` always refers to the standard library namespace"]
        "`Benitoite` cannot be declared or used as an import name.";
    E0326 Check "the effect `{name}` has the same name as its module" ""
        [rename: "effects are not modules; choose a name different from the module name"]
        "An effect cannot have the name of the module that declares it, because a qualified name such as `Log.write` would be ambiguous.";
    E0327 Check "the field `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Field names must be unique within a record.";
    E0328 Check "the method `{name}` is declared more than once in `{trait_name}`" "redeclared here"
        [first: "first declared here"]
        "Method names must be unique within a trait.";
    E0329 Check "the public {what} `{name}` uses the non-public {used_kind} `{used}`" "`{used}` is not public"
        [declared: "`{used}` is declared here",
         make_public: "mark `{used}` as `public`",
         handle: "handle the effect inside the function before returning"]
        fix [make_public]
        "Everything a public declaration exposes, including types, traits, and effects, must also be public.";
    E0330 Check "`{name}` is not public in `{module}`" "not public"
        [declared: "declared here",
         make_public: "mark `{name}` as `public` in `{module}`"]
        fix [make_public]
        "Only `public` declarations of another module can be used.";
    E0331 Check "the constructor `{name}` must be written with its type name" ""
        [qualify: "write `{suggestion}`"]
        fix [qualify]
        "Constructors are written with their type name, such as `Option.Some(x)`, `Result.Error(e)`, and `Shape.Circle(r)`.";
    E0332 Check "the module `{module}` is not imported" ""
        [import: "add `import {full}` at the start of the file"]
        fix [import]
        "Standard library modules outside the prelude must be imported before use.";
    E0333 Check "`IO` is a module, not an effect" "expected an effect"
        [all: "use `IO.All` to allow every effect in `Benitoite.IO`"]
        fix [all]
        "The built-in effects are `Console.Write`, `File.Read`, and so on. `IO.All` stands for all of them.";
    E0334 Check "`{name}` is already a local name here" "`bind` cannot hide a local name"
        [visible: "`{name}` is bound here",
         shadow: "write `shadow` to bind a new value to `{name}`"]
        fix [shadow]
        "`bind` introduces names that are not visible yet. `shadow` hides a visible local name.";
    E0335 Check "`{name}` is not a local name here" "nothing to shadow"
        [bind: "write `bind` to introduce `{name}`"]
        fix [bind]
        "`shadow` hides a visible local name. `bind` introduces a new one.";
    E0336 Check "this binding mixes visible and new names" ""
        [visible: "`{name}` is bound here",
         split: "split the statement into a `bind` and a `shadow`"]
        "All variables on the left of `bind` must be new, and all variables on the left of `shadow` must be visible local names.";
    E0337 Check "`shadow` does not bind any variable here" ""
        [bind: "write `bind _ <- ...` to evaluate and discard the value"]
        fix [bind]
        "`shadow` needs at least one variable on its left.";
    E0338 Check "{binder} `{name}` hides a local name" ""
        [hidden: "`{name}` is bound here",
         rename: "choose another name"]
        "Lambda parameters, pattern variables of branches, handler clause parameters, and `with` bindings cannot hide visible local names.";

    // ---- E04: 型 ----
    E0401 Check "mismatched types" "expected `{expected}`, found `{found}`"
        [declared: "expected because of this",
         expanded: "the expanded expected type is `{expanded}`",
         because_call_arg: "argument {index} must match the parameter type of the called function",
         because_if_branches: "the branches of `if` must have compatible types",
         because_if_no_else: "`if` without `else` must have type `Unit`",
         because_condition: "a condition must have type `Boolean`",
         because_match_arms: "the branches of `match` must have compatible types",
         because_pattern: "a pattern must match the type of the value being matched",
         because_alternatives: "a variable bound in several alternatives must have one type",
         because_list: "the elements of a list must have compatible types",
         because_spread: "a spread `..e` must be a list of the element type",
         because_bind_annotation: "the value must match the type annotation",
         because_const_annotation: "the value of a constant must match its type",
         because_return: "the returned value must match the declared return type",
         because_lambda_return: "the lambda body must match the annotated return type",
         because_field: "the value must match the type of the field `{field}`",
         because_update: "a record update keeps the type arguments of the record",
         because_resume: "the value passed to `resume` must match the result type of the operation",
         because_handle: "the body and the clauses of `handle` must have compatible types",
         because_operands: "both operands of `{op}` must have the same type",
         because_logic: "the operands of `{op}` must have type `Boolean`",
         because_int_operands: "the operands of `{op}` must have type `Integer`",
         because_call: "the called value must be a function",
         float_literal: "write a floating-point literal such as `{literal}.0`",
         to_string: "convert the value with `{function}`, or use string interpolation such as `\"${x}\"`",
         to_string_any: "convert the other value to a `String` before joining it with `+`, or use string interpolation"]
        fix [float_literal]
        "Two types that must be equal are different.";
    E0402 Check "this function takes {expected} argument(s) but {found} were supplied" ""
        [declared: "function declared here"]
        "Functions are not curried; supply every argument, or use `_` placeholders to build a new function.";
    E0403 Check "a value of type `{found}` is not a function" "cannot be called"
        [constant: "`{name}` is a constant; remove `()`"]
        fix [constant]
        "Only functions can be called.";
    E0404 Check "a type would contain itself" "this makes the type infinite" []
        "A type variable cannot be equal to a type that contains it.";
    E0405 Check "`{op}` cannot be applied to `{ty}`" ""
        [allowed: "`{op}` works on {allowed}",
         div: "use `div` for integer division, or convert with `Integer.toFloat` before `/`",
         type_param: "operators cannot be applied to values of a type parameter",
         to_string: "convert the value with `{function}`, or use string interpolation such as `\"${x}\"`",
         to_string_any: "convert the other value to a `String` before joining it with `+`, or use string interpolation"]
        fix [div]
        "Arithmetic and ordering operators work only on the listed basic types.";
    E0406 Check "values of type `{ty}` cannot be compared with `{op}`" ""
        [why: "types that contain functions, `IOError`, or other opaque types cannot be compared with `=` or `<>`",
         constraint: "add the constraint `equality` to the type parameter, such as `[{param}: equality]`"]
        fix [constraint]
        "Equality is defined only for types without functions and opaque standard library types.";
    E0407 Check "the type of this expression cannot be determined" ""
        [annotate: "add a type annotation"]
        "An operator, an interpolation, a comparison, a key, a trait method, a `try`, or a `with` needs its type to be known by the end of the function body.";
    E0408 Check "integer literal is out of range for `Integer`" ""
        [range: "`Integer` values range from -9223372036854775808 to 9223372036854775807"]
        "Integer literals must fit in a 64-bit signed integer.";
    E0409 Check "floating-point literal is too large for `Float`" "" []
        "The literal rounds to infinity.";
    E0410 Check "`{name}` expects {expected} type argument(s) but {found} were given" "" []
        "Every type argument of a generic type or a type alias must be written.";
    E0411 Check "the type `{name}` has no constructors" ""
        [add: "add at least one constructor"]
        "A `data` declaration needs at least one constructor.";
    E0412 Check "the constructor `{name}` has {expected} field(s) but the pattern has {found}" "" []
        "A constructor pattern needs one sub-pattern per field.";
    E0413 Check "the constructor `{name}` has no fields and is written without parentheses" ""
        [remove: "remove `()`"]
        fix [remove]
        "Constructors without fields are values, not functions.";
    E0414 Check "no `main` function" ""
        [define: "define `function main() -> Unit` in the file where execution starts"]
        "A program starts by calling `main` of the starting module.";
    E0415 Check "`main` has an invalid signature" ""
        [params: "`main` takes no parameters",
         type_params: "`main` cannot have type parameters or effect variables",
         ret: "`main` must return `Unit` or `Result[Unit, String]`",
         effects: "`main` can only use the built-in effects in `IO.All` and the network effects",
         assert: "`main` cannot use `Assert.Check`"]
        "`main` has no parameters, returns `Unit` or `Result[Unit, String]`, and uses only built-in effects.";
    E0416 Check "the value of this expression is not used" "this has type `{found}`, not `Unit`"
        [discard: "write `bind _ <- ...` to discard the value",
         reassign: "`=` compares values and variables cannot be reassigned; to bind a new value to the name, write `shadow {name} <- ...`"]
        fix [discard, reassign]
        "An expression statement that is not the last in a block must have type `Unit`.";
    E0417 Check "a `uses` list can contain at most one effect variable" "" []
        "Use the same effect variable for several parameters to combine their effects.";
    E0418 Check "the effect variable `{name}` does not appear in any parameter type" "" []
        "An effect variable must be determined by a parameter type.";
    E0419 Check "`{name}` appears more than once in `uses`" ""
        [remove: "remove the second `{name}`"]
        fix [remove]
        "Each effect is listed once.";
    E0420 Check "Decimal literal has more than 28 digits after the decimal point" ""
        [limit: "a `Decimal` has at most 28 digits after the decimal point"]
        "Decimal literals are not rounded, so their digits must fit the `Decimal` type.";
    E0421 Check "Decimal literal is out of range for `Decimal`" ""
        [limit: "the digits of a `Decimal`, without the decimal point, must be less than 2^96"]
        "Decimal literals are not rounded, so their value must fit the `Decimal` type.";
    E0422 Check "a value of type `{ty}` cannot be interpolated into a string" ""
        [show: "convert the value to a `String` first with `{function}`",
         import_show: "if this type implements `Show`, write `import Benitoite.Trait` and convert the value with `Trait.Show.show`",
         convert: "convert the value to a `String` before interpolating it"]
        fix [show]
        "`${...}` accepts `String`, `Integer`, `Float`, `Decimal`, `Byte`, `Character`, and `Boolean`.";
    E0423 Check "`{ty}` cannot be used as a key" ""
        [float: "`Float` has values that are not equal to themselves; use `Integer`, `Decimal`, or `String` instead"]
        "Map keys and set elements must have types that satisfy `key`. Types that contain `Float` do not.";
    E0424 Check "the type parameter `{param}` needs the constraint `{constraint}`" ""
        [required: "required by this use",
         add: "add the constraint, such as `[{param}: {constraint}]`"]
        fix [add]
        "Comparing values or using them as keys requires `equality` or `key` on a type parameter.";
    E0425 Check "the constraint `{constraint}` cannot be written here" "" []
        "Type declarations cannot have constraints. Built-in constraints can be written on value type parameters of functions, methods, and implementations, but not on type constructor parameters or supertraits.";
    E0426 Check "`{name}` needs type arguments here" "" []
        "A type constructor such as `List` or a parameter `F[_]` is a type only with its type arguments.";
    E0427 Check "`{name}` takes {expected} type argument(s) where {found} are needed" "" []
        "A trait over type constructors, such as `Functor`, needs a type constructor that takes the same number of type arguments.";
    E0428 Check "the record `{name}` is missing fields: {fields}" "missing fields"
        [declared: "the record is declared here"]
        "A record construction gives a value to every field. Use `Record(..value, field: x)` to copy the other fields.";
    E0429 Check "the record `{name}` has no field `{field}`" "unknown field"
        [similar: "a similar field exists: {candidates}"]
        fix [similar]
        "Only the fields declared in the record can be written.";
    E0430 Check "the field `{field}` is given more than once" "given again here"
        [first: "first given here"]
        "Each field is written once in a construction, an update, or a pattern.";
    E0431 Check "the type alias `{name}` refers to itself" ""
        [member: "part of the cycle",
         chain: "the cycle is {chain}",
         data: "declare a `data` type for a recursive type"]
        "A type alias is replaced by its definition, so it cannot refer to itself directly or through other aliases.";
    E0432 Check "the type parameter `{param}` is not used in the type alias `{name}`" "" []
        "Every type parameter of a type alias must appear on its right-hand side.";
    E0433 Check "this expression cannot be used in a constant" "not a constant expression"
        [function: "write a function without parameters to compute the value when it is called"]
        "A constant is computed before the program runs, from literals, other constants, operators, constructors, records, lists, and `Map.fromList` or `Set.fromList`.";
    E0434 Check "the type of the constant `{name}` cannot contain type parameters" "" []
        "A constant has one value, so its type must be a concrete type.";
    E0435 Check "computing the constant `{name}` fails: {condition}" "fails here" []
        "A constant whose computation would stop with a runtime error is reported before the program runs.";
    E0436 Check "the key `{key}` appears more than once in a constant" "repeated key"
        [first: "first given here"]
        "`Map.fromList` and `Set.fromList` in a constant must not repeat a key.";
    E0437 Check "constants refer to each other in a cycle" "this constant is part of a cycle"
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "A constant can use other constants, but not itself through a chain of constants.";
    E0438 Check "the function can reach its end without `return`" "the end of the body is reachable"
        [path: "the body can reach its end through this path",
         add: "add `return` with a value of type `{expected}`"]
        "A function or lambda whose return type is not `Unit` must leave through `return` on every path.";
    E0439 Check "this statement is never executed" "unreachable statement"
        [exit: "this always leaves the block"]
        "A statement after `return`, or after an `if` or `match` that always leaves, is never executed.";
    E0440 Check "`try` cannot be applied to `{ty}`" ""
        [kinds: "`try` works on `Result` and `Option`"]
        "`try` takes a `Result` or an `Option`.";
    E0441 Check "`try` on `{ty}` needs the function to return {needed}" ""
        [declared: "the function returns `{declared}`",
         convert: "convert the value with `Option.okOr` or `Result.toOption` before `try`"]
        "`try` on a `Result` needs the enclosing function or lambda to return a `Result`, and `try` on an `Option` needs it to return an `Option`.";
    E0442 Check "`try` cannot return an error of type `{found}` from a function that returns errors of type `{expected}`" ""
        [declared: "the function returns `{declared}`",
         map_error: "convert the error with `Result.mapError` before `try`"]
        "The error type of the value after `try` must be the error type of the function's result.";
    E0443 Check "`{ty}` is not a resource type" ""
        [resources: "`with` binds values opened by functions such as `File.openReader` and `TaskGroup.open`"]
        "A `with` binding needs a resource, which is released when the block ends.";

    // ---- E05: エフェクト、ハンドラ ----
    E0501 Check "this function performs `{effect}` but does not declare it" "`{effect}` happens here"
        [declared: "declared here",
         add_uses: "add `uses {effect}` to the signature, or move this call to a function that uses `{effect}`"]
        "A function body can only perform the effects listed after `uses`.";
    E0502 Check "this lambda performs `{effect}` but its `uses` does not include it" "`{effect}` happens here"
        [declared: "declared here"]
        "A lambda with `uses` can only perform the listed effects.";
    E0503 Check "a `lazy` body cannot perform `{effect}`" "`{effect}` happens here"
        [lambda: "use a lambda without parameters to delay an effectful computation"]
        "A `lazy` body is computed at most once at an unknown time, so it cannot have effects.";
    E0504 Check "a guard cannot perform `{effect}`" "`{effect}` happens here"
        [body: "compute the condition in the branch body instead"]
        "Guards are conditions and cannot have effects.";
    E0505 Check "`TaskGroup.open` can only be called in a `with` binding" ""
        [with: "write `with group = TaskGroup.open() do ... end with`"]
        "A task group must be released when its block ends, so it is opened only by `with`.";
    E0506 Check "`{function}` does not handle the effect `{effect}`" "`{effect}` is not handled"
        [handle: "handle `{effect}` with `handle ... with` inside `{function}`"]
        "Effects declared by the program must be handled inside `main` and inside test functions.";
    E0507 Check "`{name}` is not an operation of an effect" ""
        [state: "`State` has no operations and cannot be handled"]
        "A clause of `handle` names an operation declared in an `effect`.";
    E0508 Check "the operation `{name}` is handled twice in one `handle`" "second clause"
        [first: "first clause here"]
        "Each operation has at most one clause in a `handle`.";
    E0509 Check "`resume` can only be used directly in a clause of `handle`" ""
        [lambda: "`resume` cannot be used in a lambda or a `lazy` body inside a clause"]
        "`resume` continues the computation that performed the operation, so it is written in the clause itself.";
    E0510 Check "invalid effect operation declaration" ""
        [uses: "an operation declaration cannot have `uses`; the handler decides the effects",
         effect_var: "an operation cannot have effect variables",
         type_ctor: "an operation cannot have type constructor parameters such as `F[_]`",
         trait_constraint: "a type parameter of an operation can have only `equality` or `key`, not a trait"]
        "Operations of an effect are declared with a name, parameters, and a result type.";

    // ---- E06: パターン ----
    E0601 Check "`match` does not cover every value" "`{witness}` is not matched"
        [add_arm: "add a branch `case {witness} ->`, or `case _ ->`"]
        "Every possible value must be matched by some branch.";
    E0602 Check "this branch can never be selected" "unreachable branch"
        [covering: "this earlier branch already matches the values"]
        "Earlier branches match every value this branch matches.";
    E0603 Check "the pattern variable `{name}` has the name of a constant" "binds a new variable"
        [constant: "the constant is declared here",
         guard: "compare with the constant in a guard, such as `case n if n = {name} ->`"]
        fix [guard]
        "A lowercase name in a pattern always binds a new variable. Compare with a constant in a guard.";
    E0604 Check "the alternatives bind different variables" ""
        [missing: "`{name}` is not bound in this alternative",
         first: "`{name}` is bound here",
         extra: "`{name}` is bound only in this alternative",
         sets: "missing variables: {missing}; extra variables: {extra}",
         missing_set: "missing variables: {missing}",
         extra_set: "extra variables: {extra}"]
        "Every alternative in one branch must bind the same variables.";
    E0605 Check "the range `{low}..{high}` is empty" ""
        [swap: "write `{high}..{low}`"]
        fix [swap]
        "The lower end of a range pattern must not be greater than the upper end.";
    E0606 Check "a range pattern needs two `Integer` or two `Character` literals" "" []
        "Range patterns compare integers or characters.";
    E0607 Check "this pattern does not match every value of `{ty}`" "`{witness}` is not matched"
        [match: "use `match ... with` to handle the other values"]
        "The pattern on the left of `bind` or `shadow` must match every value.";
    E0608 Check "this alternative can never be selected" "unreachable alternative"
        [covering: "already matched here"]
        "Earlier patterns match every value this alternative matches.";

    // ---- E07: 型クラス ----
    E0701 Check "this implementation must be in the module of `{trait_name}` or of `{ty}`" ""
        [trait_decl: "the trait is declared here",
         type_decl: "the type is declared here"]
        "An implementation is written in the module that declares the trait or the type, so that it is found without importing other modules.";
    E0702 Check "`{trait_name}` is implemented more than once for `{ty}`" "overlapping implementation"
        [other: "the other implementation is here"]
        "Each type constructor has at most one implementation of a trait.";
    E0703 Check "traits are supertraits of each other in a cycle" ""
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "Supertraits must not form a cycle.";
    E0704 Check "the implementation of `{trait_name}` for `{ty}` needs `{supertrait}` for `{ty}`" ""
        [constraint: "add the constraint `{constraint}` to the type parameter of the implementation"]
        "A type implements a trait only if it implements the supertraits under the same constraints.";
    E0705 Check "`{ty}` does not implement `{trait_name}`" "`{trait_name}` is required here"
        [required: "required by this use"]
        "A value used with a trait method, or passed where a constraint is required, must have an implementation.";
    E0706 Check "the type parameter `{param}` needs the constraint `{trait_name}`" ""
        [add: "add the constraint, such as `[{param}: {trait_name}]`"]
        fix [add]
        "Using a trait method on a value of a type parameter requires that constraint on the parameter.";
    E0707 Check "the implementation of `{trait_name}` is missing methods: {methods}" ""
        [trait_decl: "the trait is declared here"]
        "An implementation defines every method of its trait.";
    E0708 Check "`{name}` is not a method of `{trait_name}`" ""
        [similar: "a similar method exists: {candidates}"]
        fix [similar]
        "An implementation defines only the methods of its trait.";
    E0709 Check "the method `{name}` does not mention the type parameter of `{trait_name}`" "" []
        "A method is chosen by the type of its parameters or its result, so it must mention the trait's type parameter.";
    E0710 Check "the trait `{name}` declares no methods" "" []
        "A trait declares at least one method.";
    E0711 Check "the method `{name}` does not match its declaration in `{trait_name}`" "expected `{expected}`, found `{found}`"
        [declared: "declared here"]
        "An implemented method has the parameter and result types of the trait's method, and at most its effects.";
    E0712 Check "cannot implement a trait for `{ty}`" ""
        [form: "implement it for a type name with distinct type parameters, such as `Option[T]`"]
        "Implementations are written for one type constructor applied to distinct type parameters.";
    E0713 Check "the type parameter `{param}` is not used in the implemented type" "" []
        "Every type parameter of an implementation must appear in the implemented type.";
    E0714 Check "`{name}` does not fit the trait `{trait_name}`" ""
        [value: "`{trait_name}` is for types of values, such as `Integer`",
         constructor: "`{trait_name}` is for type constructors, such as `List`"]
        "A trait is either for types of values or for type constructors, and its implementations and constraints must match.";

    // ---- E08: 属性 ----
    E0801 Check "unknown attribute `@{name}`" ""
        [allowed: "the attributes are `@test`, `@test(\"...\")`, and `@deprecated(\"...\")`"]
        "Only the listed attributes can be written.";
    E0802 Check "`@{name}` cannot be written on {what}" "" []
        "`@test` is written on functions. `@deprecated` is written on functions, constants, `data` types, type aliases, records, traits, and effects.";
    E0803 Check "`@{name}` is written more than once" "written again here"
        [first: "first written here",
         remove: "remove this attribute"]
        fix [remove]
        "Each attribute is written at most once on a declaration.";
    E0804 Check "`@deprecated` needs one non-empty message" ""
        [message: "write the reason and the replacement, such as `@deprecated(\"use formatDate instead\")`"]
        "The message of `@deprecated` is shown with every use of the declaration.";
    E0805 Check "`@test` takes at most one description" "" []
        "`@test` is written alone or with one description string.";
    E0806 Check "the test function `{name}` has an invalid signature" ""
        [params: "a test function takes no parameters",
         type_params: "a test function cannot have type parameters or effect variables",
         ret: "a test function must return `Unit` or `Result[Unit, String]`"]
        "Test functions are called without arguments by `benitoite test`.";
    E0807 Check "`@builtin` can only be used in the standard library" ""
        [remove: "remove `@builtin` and write the body of the function"]
        "Built-in functions are provided by the standard library.";
    E0808 Check "the function `{name}` has no body" ""
        [body: "write the body and close it with `end function`"]
        "Functions without a body exist only in the standard library.";

    // ---- W03: 名前の警告 ----
    W0301 Check "`{name}` is deprecated" "deprecated"
        [declared: "declared deprecated here",
         message: "{message}"]
        "The declaration is marked `@deprecated` and may be removed later. The note shows its message.";

    // ---- W04: 型と演算の警告 ----
    W0401 Check "this divides by zero" "the divisor is always 0" []
        "The divisor is a constant expression whose value is 0, so the division stops the program when it runs.";
    W0402 Check "this calculation overflows `{ty}`" "always overflows" []
        "Every operand is a constant expression and the result does not fit the type, so the calculation stops the program when it runs.";
    W0403 Check "the key `{key}` appears more than once" "repeated key"
        [first: "first given here"]
        "`Map.fromList` keeps the last value for a repeated key and `Set.fromList` keeps one element, so a repeated key in a list literal is likely a mistake.";

    // ---- W05: エフェクトの警告 ----
    W0501 Check "`uses IO.All` allows more effects than this function performs" ""
        [narrow: "write `uses {effects}`",
         remove: "remove `uses IO.All`; this function performs no effects"]
        fix [narrow, remove]
        "Listing only the effects a function performs shows which operations it needs.";

    // ---- R01: 基本型の演算 ----
    R0101 Runtime "division by zero" "" []
        "Integer and Decimal division, `mod`, `Integer.floorDivide`, and `Integer.floorModulo` by zero stop the program.";
    R0102 Runtime "integer overflow" "" []
        "The result does not fit in a 64-bit signed integer.";
    R0103 Runtime "Decimal overflow" "" []
        "The result does not fit in a `Decimal` even after rounding.";

    // ---- R02: 標準出力と標準エラー出力 ----
    R0201 Runtime "failed to write to standard output" ""
        [reason: "{reason}"]
        "Writing to standard output failed, for example because the reading side of a pipe was closed.";
    R0202 Runtime "failed to write to standard error" ""
        [reason: "{reason}"]
        "Writing to standard error failed.";

    // ---- R03: 実行の開始前 ----
    R0301 Args "command-line argument {index} is not valid UTF-8" "" []
        "Arguments passed to a script must be valid UTF-8.";

    // ---- R04: リソース ----
    R0401 Runtime "failed to release `{resource}` opened at {location}" "released here"
        [failure: "failed to release `{resource}` opened at {location}: {reason}",
         reason: "{reason}"]
        "Releasing a resource failed when its `with` block ended, when its task was cancelled, or when a handler discarded the computation.";
    R0402 Runtime "`{resource}` is used after it was released" "" []
        "A resource cannot be used after its `with` block has ended.";

    // ---- R05: ハンドラ ----
    R0501 Runtime "`resume` was called twice in one clause" "" []
        "A continuation can be resumed at most once.";
    R0502 Runtime "the handler for `{operation}` cannot be used in a task" ""
        [clause: "the clause is here",
         tail: "a handler inherited by a task must end its clause with `resume`"]
        "Tasks inherit only handlers whose clauses end by calling `resume`.";

    // ---- R07: 引数 ----
    R0701 Runtime "argument {index} of `{function}` is out of range" "" []
        "The function accepts only the values described in its documentation for this argument.";

    // ---- R08: ネットワーク ----
    R0801 Runtime "a response was already sent for this request" "" []
        "`Http.respond` can be called once for each exchange.";

    // ---- R09: 資源の不足 ----
    R0901 Resource "the call stack is too deep" ""
        [frames: "{frames} calls were active",
         raise: "use tail calls, or raise the limit with `--max-call-stack`"]
        "Nested non-tail calls exceeded the call stack limit.";
    R0902 Resource "`{function}` would create a value that is too large" ""
        [size: "the result would have {size} {unit}; the limit is {limit}"]
        "A single operation cannot build a string or `Bytes` larger than 2^30 bytes, or a list longer than 2^24 elements.";
    R0903 Resource "`{function}` read more than the limit of {limit} {unit}" "" []
        "A single read cannot produce a value larger than the size limit. Read the input in parts.";

    // ---- R10: 並行処理 ----
    R1001 Runtime "no task can proceed because tasks are waiting for each other" "" []
        "Every remaining task waits for another task, so the program cannot continue.";
    R1002 Runtime "the awaited task was cancelled, so it has no result" "" []
        "`Task.await` cannot return a value for a task that was cancelled. A `Task` value used outside its `with` block may refer to such a task.";

    // ---- L01: 処理系の制限 ----
    L0101 Limit "the function `{name}` needs too many registers" ""
        [limit: "a function can use at most 65535 registers; split it into smaller functions"]
        "The bytecode addresses registers with 16 bits.";
    L0102 Limit "the function `{name}` has too many constants" ""
        [limit: "a function can have at most 65536 constants; split it into smaller functions"]
        "The bytecode addresses constants with 16 bits.";
    L0103 Limit "the function `{name}` has too many `match` expressions" ""
        [limit: "a function can have at most 65536 switch tables; split it into smaller functions"]
        "The bytecode addresses the switch tables of a function with 16 bits.";
    L0104 Limit "the function `{name}` has too many `handle` expressions" ""
        [limit: "a function can have at most 65536 handlers; split it into smaller functions"]
        "The bytecode addresses the handler descriptions of a function with 16 bits.";
    L0105 Limit "the program has too many constructors" ""
        [limit: "a program can have at most 65535 constructors"]
        "The bytecode addresses constructors with 16 bits.";
    L0106 Limit "the program uses too many built-in functions" ""
        [limit: "a program can use at most 65535 built-in functions"]
        "The bytecode addresses built-in functions with 16 bits.";
    L0107 Limit "the program has too many implementations" ""
        [limit: "a program can have at most 65535 implementations"]
        "The bytecode addresses implementations with 16 bits.";
    L0108 Limit "the program has too many effect operations" ""
        [limit: "a program can have at most 65535 effect operations"]
        "The bytecode addresses effect operations with 16 bits.";
    L0109 Limit "the trait `{name}` has too many methods" ""
        [limit: "a trait can have at most 65535 methods"]
        "The bytecode addresses the methods of a trait with 16 bits.";
    L0110 Limit "the trait `{name}` has too many supertraits" ""
        [limit: "a trait can have at most 65535 supertraits"]
        "The bytecode addresses the supertraits of a trait with 16 bits.";
    L0111 Limit "an implementation of `{name}` has too many constraints" ""
        [limit: "an implementation can have at most 65535 constraint dictionaries"]
        "The bytecode addresses the dictionaries of an implementation with 16 bits.";
}

/// 型板の `{名前}` を値で置き換える。値のない `{名前}` はそのまま残す。
pub fn fill_template(template: &str, args: &[(&'static str, String)]) -> String {
    let mut out = String::with_capacity(template.len());
    let mut rest = template;
    while let Some(open) = rest.find('{') {
        let (before, from_open) = rest.split_at(open);
        out.push_str(before);
        let after_open = from_open.get(1..).unwrap_or("");
        match after_open.find('}') {
            Some(close) => {
                let key = after_open.get(..close).unwrap_or("");
                let is_key =
                    !key.is_empty() && key.chars().all(|c| c.is_ascii_alphanumeric() || c == '_');
                match args.iter().find(|(k, _)| *k == key) {
                    Some((_, value)) if is_key => {
                        out.push_str(value);
                        rest = after_open.get(close.saturating_add(1)..).unwrap_or("");
                    }
                    _ => {
                        out.push('{');
                        rest = after_open;
                    }
                }
            }
            None => {
                out.push_str(from_open);
                rest = "";
            }
        }
    }
    out.push_str(rest);
    out
}

/// 診断コードの表に属さない、報告の定型の文（ADR 0033）。
pub mod text {
    /// 実行時エラーの履歴の見出し（02-10）
    pub const TRACE_HEADER: &str = "call trace (innermost first):";
    /// タスクの起動の履歴の見出し
    pub const TASK_ORIGINS_HEADER: &str = "in a task started by (innermost first):";
    /// 行き詰まりで待つタスクの見出し
    pub const WAITING_HEADER: &str = "waiting tasks:";
    /// 待つタスクの行の、種類と位置の間の語。`{kind}` と `{location}` を置き換える
    pub const WAITS_FOR: &str = "waits for {kind}";
    /// 末尾呼び出しの注記
    pub const TRACE_TAIL_NOTE: &str = "functions left by tail calls are not shown";
    /// 省いた段の行。`{count}` を置き換える
    pub const TRACE_OMITTED: &str = "... {count} frames omitted ...";
    /// 書き出しの失敗を先の報告に加えるときの注記。`{stream}` と `{reason}` を置き換える
    pub const FLUSH_FAILED_NOTE: &str = "also failed to write to {stream}: {reason}";
    /// 止める途中の解放の失敗を先の報告に加えるときの注記（02-10「解放の失敗の報告」）
    pub const RELEASE_WHILE_STOPPING: &str =
        "while stopping, failed to release `{resource}` opened at {location}: {reason}";
    /// `Process.exit` で止める途中の解放の失敗の最後の注記。`{code}` を置き換える
    pub const RELEASE_EXIT_NOTE: &str =
        "the program was exiting by `Process.exit({code})`; the exit status is not changed";
    /// 中断の要求で止める途中の解放の失敗の最後の注記
    pub const RELEASE_INTERRUPT_NOTE: &str =
        "the program was interrupted; the exit status is not changed";
    /// `--deny-warnings` で警告を誤りとして扱ったときの注記
    pub const DENIED_WARNING_NOTE: &str = "treated as an error because of `--deny-warnings`";
    /// 文章の形式で 50 件を超えたときの行。`{count}` を置き換える
    pub const TOO_MANY: &str = "{count} more diagnostics not shown";
    /// 件数の行（02-10「文章の形式」）。`{verb}` は `run`・`check`・`test`
    pub const SUMMARY_ONE: &str = "could not {verb} {file} due to 1 previous error";
    pub const SUMMARY_MANY: &str = "could not {verb} {file} due to {count} previous errors";
    /// 誤りの件数の行に続ける警告の件数
    pub const SUMMARY_WARNINGS_ONE: &str = "; 1 warning emitted";
    pub const SUMMARY_WARNINGS_MANY: &str = "; {count} warnings emitted";
    /// 警告だけがあるときの件数の行
    pub const WARNINGS_ONLY_ONE: &str = "1 warning emitted";
    pub const WARNINGS_ONLY_MANY: &str = "{count} warnings emitted";
    /// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）
    pub const INTERNAL_MESSAGE: &str = "internal compiler error";
    pub const INTERNAL_VERSION: &str = "benitoite {version}";
    pub const INTERNAL_STAGE: &str = "the error occurred in the {stage} stage";
    pub const INTERNAL_THREAD: &str = "the panic occurred in the {thread} thread";
    pub const INTERNAL_PANIC: &str = "panic: {message} at {location}";
    pub const INTERNAL_REPORT: &str =
        "this is a bug in the implementation; please report it with the script that caused it";
}
```

`fill_template` と `text` の定数は、最小実行版のものを引き継ぎ、警告の件数、タスクの起動の履歴、行き詰まり、解放の失敗、`--deny-warnings` の文を加えた。50 件を超えたときの行は、警告も数えるので、`more errors` を `more diagnostics` に改めた。C05 で最小実行版のゴールデンテストの期待値が変わる箇所の一つである。

## コードの一覧

`codes.rs` の表の各コードについて、条件、出す段、根拠の節を示す。「出す作業」は、そのコードの診断を組み立てる作業である。「最小実行版」の印は、最小実行版から引き継いだコードであり、そのうち型板を初回リリース版の言語に合わせて書き直したものに「書き直し」と添えた。

### E01 読み込みと字句

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0101 | ファイルがない・読めない、ファイル一つの大きさの上限（256 MiB）、すべてのソースの大きさの和の上限（512 MiB）。import で読むファイルでは、import の宣言のモジュールの名前を主な位置とする（ラベルの鍵 `imported`）。理由の文（大きさの上限の文を含む）は `modules` の `text` に置く | F05 | 02-02「ソースとファイル ID」「ソースの大きさの上限」（最小実行版） |
| E0102〜E0110、E0112、E0114〜E0116 | 最小実行版のとおり。E0108 に複数行の文字列の修正案（`multi_line`）、E0115・E0116 の `suffix` に空白で区切る例を加えた | F01 | 01-01（最小実行版） |
| E0113 | 最小実行版の条件に加え、複数のスカラー値からなる文字（結合文字、ZWJ の絵文字）。修正案は文字列リテラルへの置き換え | F01 | 01-01「文字リテラル」、02-10「修正案」（最小実行版） |
| E0118 | 空の補間 `${}` | F01 | 01-01「文字列リテラル」、02-03「文字列補間と複数行の文字列の切り出し」 |
| E0119 | 補間の式が同じ行で `}` で閉じない（補間の中の改行を含む） | F01 | 同上 |
| E0120 | 補間の式の中の `//` | F01 | 同上 |
| E0121 | 開きの `"""` の後の同じ行に文字がある | F01 | 01-01「複数行の文字列と raw 文字列」 |
| E0122 | 空白でない行が、閉じの行の字下げで始まらない（空白とタブの違いを含む）。位置は字下げを取り除く前のソースの位置 | F01 | 同上、02-02「span」 |
| E0123 | 閉じの `"""` がない（`r"""` を含む） | F01 | 同上 |
| E0124 | `Decimal` のリテラルの形の誤り（指数、大文字の `M`、基数の接頭辞、`m` の直後の文字、先頭の 0、`_`） | F01 | 01-01「Decimal リテラル」「数値リテラルの直後の文字」 |
| E0125 | `fmt` が整形の結果でファイルを置き換えられない（一時ファイルを作れない・書けない、名前を変えられない）。主な位置を持たない。一時ファイルを消せなかったときは注記 `temp_left`。U4 で加えた（[10-17](10-17-formatter.md)「診断コード」） | D03 | 06-01「`fmt` のコマンドライン（初回リリース版）」、ADR 0247 |

大きさの上限を E0101 とするのは、[モジュールと名前解決](10-04-modules-and-resolve.md)の `MAX_TOTAL_SOURCE_BYTES` の定めと、最小実行版の扱い（ファイル一つの上限を E0101 の理由として示す）に合わせたためである。文字列補間の入れ子の深さは、構文の入れ子と合わせて E0208 で報告する（02-03「文字列補間…の切り出し」）。

### E02 構文

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0105 | 字句に使えない記号のうち、特定の修正案のないもの（`#`、単独の `\|`、`~`、`^`、`` ` ``、`$`） | F02 | 01-01「演算子と区切り記号」（最小実行版） |
| E0106 | `;`（最小実行版。修正案に削除の置き換えを付ける） | F02 | 同上 |
| E0201、E0204、E0206、E0208、E0210 | 最小実行版のとおり。E0204 はレコードの構築の中の `_` にも使う（鍵 `record`） | F02〜F04 | 01-02、02-03（最小実行版） |
| E0202 | 比較演算子を連ねた（書き直し。`a < b and b < c` への置き換え） | F02 | 01-02「演算子の優先順位と結合性」、02-10「修正案」 |
| E0203 | 値に続けたドット（書き直し。フィールドを読む関数の修正案を加えた） | F02 | 01-02「ドット記法」「レコード」 |
| E0207 | 関数の名前を修飾して宣言した（書き直し） | F02 | 01-02「プログラムと宣言」（最小実行版） |
| E0209 | `uses` の並びの後の要素に `[` が続いた（書き直し。例を初回リリース版の構文にした） | F02 | 02-03「型の解析」 |
| E0211 | 他の言語の演算子 `==`・`!=`・`&&`・`\|\|`・`!`・`%`・`?`・`=>`。記号ごとに修正案の鍵を選ぶ | F02 | 01-01「演算子と区切り記号」、02-03「他の言語の書き方への診断」 |
| E0212 | 波括弧 `{`・`}` によるブロック | F02 | 01-02「ブロックと文」 |
| E0213 | `end` の後の構文の名前が、閉じる構文と一致しない。補助の位置は開いた位置 | F02 | 同上、02-03「構文の規則に伴う診断」 |
| E0214 | ブロックを閉じないまま、ファイルの終わりか外側の `end` に達した | F02 | 同上 |
| E0215 | `match 対象` の次の行の頭に `with` を書いた | F02 | 01-01「改行による区切り」、01-02「パターンマッチ」 |
| E0216 | キーワードを名前に使った（E0117 に代わる） | F02 | 01-01「キーワード」、02-10「修正案」 |
| E0217 | 丸括弧の中にコンマで並べた値・型・パターン（組の構文） | F04 | 01-02「組と bind・shadow のパターン」 |
| E0218 | `lazy` の本体とガードの中の `return`・`try`（内側のラムダの中を除く） | F04 | 02-03「文脈の制限」 |
| E0219 | ほかの宣言の後の `import` | F03 | 01-02「モジュールと import」 |
| E0220 | 属性の引数が文字列リテラルでない、または補間を含む | F03 | 01-02「属性」 |
| E0221 | `implement` と、その中の関数に付けた `public` | F03 | 01-02「型クラス」 |
| E0222 | 制約の位置の `equality`・`key` でない小文字の名前（利用者のソースの `ordered` を含む） | F04 | 01-02「型クラス」、02-03「標準ライブラリのソースの構文」、ADR 0157 |
| E0223 | 上位の型クラスの位置の組み込みの制約 | F04 | 01-02「型クラス」 |
| E0224 | フィールドのないレコードの更新 `Person(..p)` | F03 | 01-02「レコード」 |
| E0225 | フィールドのないレコードのパターン `Person(..)` | F03 | 同上 |
| E0226 | リストのリテラルの二つ目の展開 | F04 | 01-02「リストの展開」、ADR 0272 |
| E0227 | `...xs`・`*xs` の形の展開 | F04 | 同上、02-03「他の言語の書き方への診断」 |
| E0228 | 宣言に結び付かない `///` | F03 | 01-02「ドキュメントコメント」、02-03「コメントとドキュメントコメント」 |
| E0229 | ファイルの先頭にない `//!` | F03 | 同上 |
| E0230 | `let x = e` | F02 | 01-02「ブロックと文」、02-10「修正案」 |
| E0231 | `case e of` | F02 | 01-02「パターンマッチ」、02-10「修正案」 |
| E0232 | `when p:`（`match` の分岐と `handle` の節の位置） | F02 | 同上 |
| E0233 | 構成子を並べた `type` の宣言 | F02 | 01-02「プログラムと宣言」、ADR 0256 |
| E0234 | 引数の並びの `)` の直後の `:`（関数・ラムダ・メソッド・操作） | F02 | 01-02、ADR 0254 |
| E0235 | `try` の直後の `{` | F04 | 01-09「try」、02-10「診断コード」 |
| E0236 | 分岐の頭の `\|` による選択肢 | F04 | 02-03「他の言語の書き方への診断」 |
| E0237 | 型の別名の右辺の `\|` | F03 | 同上 |
| E0238 | `case` のない分岐（`パターン -> 式`、`パターン => 式`） | F02 | 01-02「パターンマッチ」 |
| E0239 | `switch e`、`default:` | F02 | 同上 |
| E0240 | 分岐の本体の後の `break` | F02 | 同上 |
| E0241 | `when`・`where` によるガード | F04 | 02-03「他の言語の書き方への診断」 |
| E0242 | `1..=5`・`1..<5`・`1...5` の形の範囲 | F04 | 01-05「パターンの拡張」、02-10「修正案」 |
| E0243 | `lambda x: e` | F02 | 01-02「ラムダ」 |
| E0244 | パスの文字列や `from` による import | F03 | 02-03「他の言語の書き方への診断」 |
| E0245 | 型クラスを指定しない `implement` | F04 | 同上 |
| E0246 | `with handler`・`try … with` の形のハンドラ | F04 | 同上 |
| E0247 | `#[test]`・`[<Test>]`・`@Test` | F03 | 同上 |
| E0248 | `type alias`・`typealias` | F03 | 同上 |
| E0249 | `/** … */`・`{-\| … -}`・`(** … *)`・`@doc` | F03 | 同上 |
| E0250 | リストのパターンの二つ目の `..` | F04 | 01-05「パターンの拡張」 |
| E0251 | 最小実行版の `fn` の関数宣言・ラムダ（文だけの修正案） | F20 | 01-02「プログラムと宣言」「ラムダ」、02-03「他の言語の書き方への診断」 |

範囲のパターンの書き方の誤り（E0242）とリストのパターンの `..` の数（E0250）は、02-10 の区分の表では「パターン」（E06）の「範囲のパターンの誤り」に当たりうるが、構文解析器が字句の並びだけで判定する誤りなので、構文の区分に置いた。E06 には、型と値の範囲の誤り（E0605・E0606）を置く。

### E03 名前、import、公開

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0301 | 修飾しない名前が見つからない（書き直し。説明の文を定数と操作に広げた） | F06 | 01-03、02-04「誤りと修正案」（最小実行版） |
| E0302 | 修飾した名前の最初の段が見つからない（書き直し） | F06 | 同上 |
| E0303 | モジュール・型・レコード・型クラス・エフェクトに、その名前がない。取り込んだモジュールが取り込んだ名前を通して引いたとき（鍵 `not_reexported`） | F06 | 同上 |
| E0304 | 位置に合わない種類の名前（型を値に使った、エフェクトを修飾に使ったなど） | F06 | 同上（最小実行版） |
| E0305 | 型と同じ名前空間の名前の重なり（範囲を広げた。本章「番号の付け方」）。import の名前との重なりは鍵 `import` の修正案 | F06 | 01-03「トップレベルの名前空間」 |
| E0306 | 関数・定数・エフェクトの操作の名前の重なり（範囲を広げた） | F06 | 同上 |
| E0309〜E0312、E0314 | 最小実行版のとおり。E0311 はリストの `..rest` と選択肢ごとの束縛を含む | F06 | 01-03（最小実行版） |
| E0313 | 型パラメータとエフェクト変数が、トップレベルの大文字の名前か `Benitoite` と同じ名前（書き直し） | F06 | 01-03「トップレベルの名前空間」 |
| E0315 | `uses` の最初の要素がエフェクトでない（書き直し。別のモジュールのエフェクトを修飾する修正案） | F06 | 01-07、02-04 |
| E0316 | `uses` の後の要素がエフェクトでない（書き直し。関数の型を括弧で囲む置き換え） | F06 | 02-10「修正案」、ADR 0047 |
| E0318 | import のモジュールのファイルがない。大文字と小文字だけが違う項目しかないときは鍵 `case_only` の注記 | F05 | 02-04「モジュールの探し方」、ADR 0244 |
| E0319 | シンボリックリンクを解決したパスが根のディレクトリの外 | F05 | 同上の手順 3 |
| E0320 | 実行を始めるモジュールを取り込んだ | F05 | 同上の手順 4、01-03「実行を始めるモジュール」 |
| E0321 | `Benitoite.X` が標準ライブラリのモジュールでない。根の直下に `Benitoite` のファイルかディレクトリがあれば鍵 `root_file` の注記。非公式のモジュールを `Benitoite.X` の名前で書いたときは鍵 `unofficial`、標準のモジュールを `Benitoite.Unofficial.X` の名前で書いたときは鍵 `standard` の修正案と、正しい取り込みの名前への置き換え（`{suggestion}`） | F05 | 02-04「モジュールの探し方」の手順 1、03-06「標準のモジュールと非公式のモジュール（初回リリース版）」 |
| E0322 | import の循環。主な位置は循環を閉じる import、補助の位置はほかの import | F05 | 02-04「依存グラフと循環の検出」 |
| E0323 | 同じ名前になる二つの import | F06 | 02-04「import の宣言の誤り」 |
| E0324 | 同じモジュールの二度の取り込み | F06 | 同上 |
| E0325 | `as Benitoite`、トップレベルの大文字の名前としての `Benitoite` | F06 | 01-03「トップレベルの名前空間」、02-04「import の宣言の誤り」 |
| E0326 | モジュールと同じ名前のエフェクト | F06 | 01-03「トップレベルの名前空間」、01-02「エフェクトの宣言とハンドラ」 |
| E0327 | レコードのフィールドの名前の重なり | F06 | 01-05「レコード」 |
| E0328 | 型クラスのメソッドの名前の重なり | F06 | 01-02「型クラス」、01-06「型クラス」、[ADR 0279](../../2026-10-09-design-first-release/decisions/0279-no-duplicate-method-names-in-trait.md) |
| E0329 | 公開する契約に非公開の型・型クラス・エフェクトを使った。`{what}` と `{used_kind}` は `resolve` の `text` の種類の呼び名 | F06 | 01-03「公開」、02-04「宣言の検査」、ADR 0154 |
| E0330 | 別のモジュールの公開していない名前を使った | F06 | 01-03「公開」 |
| E0331 | 構成子を型の名前で修飾せずに書いた（`Some(x)`、`Circle(r)`）。E0317 に代わる | F06 | 01-03「修飾しない名前の解決」、02-10「修正案」、ADR 0099 |
| E0332 | 取り込んでいない標準ライブラリのモジュールの名前を使った。置き換えは import の行の挿入。`{full}` は取り込みの名前（非公式のモジュールでは `Benitoite.Unofficial.IO.Console` の形） | F06 | 01-03「修飾された名前の解決」、02-10「修正案」 |
| E0333 | 最小実行版の `uses IO` | F06 | 01-07、02-10「修正案」、ADR 0130 |
| E0334 | 見えている局所の名前を `bind` で束縛した | F06 | 01-03「シャドーイング」、02-04「名前の引き方」、ADR 0255 |
| E0335 | 見えていない名前を `shadow` で束縛した | F06 | 同上 |
| E0336 | 左辺に見えている名前と見えていない名前が混ざった | F06 | 同上 |
| E0337 | 変数を束縛しない左辺の `shadow` | F06 | 同上 |
| E0338 | キーワードを書けない束縛（ラムダの引数、分岐のパターンの変数、`handle` の節の引数、`with` の束縛）が局所の名前を隠した。`{binder}` は `resolve` の `text` の呼び名 | F06 | 同上 |

### E04 型

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0401 | 型の不一致（書き直し。理由の鍵にレコード・展開・`resume`・`handle`・`return`・定数を加えた） | F07〜F10 | 02-05「制約の生成」（最小実行版） |
| E0402、E0404、E0409、E0411、E0412、E0417、E0418 | 最小実行版のとおり | F07・F09・F10 | 01-06（最小実行版） |
| E0403 | 関数でない値の呼び出し。定数の呼び出し `c()` には鍵 `constant` の置き換え | F07 | 01-02「定数」 |
| E0405 | 演算子を適用できない型（書き直し。`Decimal`・`Byte`、型パラメータ、`Integer` の `/` の修正案） | F07 | 01-04、01-06「演算子の型付け」 |
| E0406 | 等しさを比べられない型（書き直し。`=`・`<>`、型パラメータへの `equality` の修正案） | F07・F08 | 01-06「組み込みの制約」 |
| E0407 | 型が決まらない（説明を制約を持つ型変数全般に広げた。型クラスの型が決まらない場合も含む） | F07〜F09 | 02-05「本体の後の検査」 |
| E0408 | 整数のリテラルが `Integer` の範囲の外（書き直し） | F07 | 01-04 |
| E0410 | 型の引数の数（型の別名にも使う） | F07 | 01-06「型の別名」 |
| E0413 | 引数のない構成子に括弧を付けた（`Tree.Leaf()`。置き換えを付ける） | F07 | 01-05、02-10「修正案」 |
| E0414 | `main` がない（書き直し。実行を始めるモジュールについて。`test` の経路では検査しない） | F07 | 01-07「プログラムの入口」、02-05「宣言の検査」 |
| E0415 | `main` のシグネチャの誤り（書き直し。組み込みのエフェクトとネットワークのエフェクト、`Assert.Check`） | F07・F09 | 同上 |
| E0416 | 式文が `Unit` でない（書き直し。`bind _ <-` の置き換え、`x = 5` の形には鍵 `reassign`） | F07 | 01-02「ブロックと文」、02-10「修正案」 |
| E0419 | `uses` の中の重なり（置き換えを加えた） | F09 | 01-06（最小実行版） |
| E0420 | `Decimal` のリテラルの小数点の後が 29 桁以上 | F07 | 01-04「Decimal」 |
| E0421 | `Decimal` のリテラルが範囲の外（直接の単項の `-` は符号を含めて判定する） | F07 | 同上 |
| E0422 | 文字列補間に書けない型 | F07 | 01-06「演算子の型付け」 |
| E0423 | `Float` を含む型を鍵に使った | F07 | 01-06「鍵の型」 |
| E0424 | 型パラメータに要る組み込みの制約（`equality`・`key`）がない | F08 | 01-06「組み込みの制約」 |
| E0425 | 組み込みの制約を書けない位置（`data` の型パラメータ、`F[_]`）。`data` の型パラメータの制約は構文解析器が報告する（F08「`data` の型パラメータの制約」） | F08 | 02-05「宣言の検査」 |
| E0426 | 型構成子を引数なしで値の型の位置に書いた | F07 | 01-06「高カインド型」、02-05「型の形」 |
| E0427 | 型構成子の位置の引数の数の不一致 | F08 | 同上 |
| E0428 | レコードの構築でフィールドが足りない | F07 | 01-05「レコード」 |
| E0429 | レコードの構築・更新・パターンのないフィールド | F07 | 同上 |
| E0430 | 同じフィールドを二度書いた | F07 | 同上 |
| E0431 | 型の別名の循環 | F06 | 01-06「型の別名」、02-05（名前解決が報告する） |
| E0432 | 型の別名の使わない型パラメータ | F07 | 01-06「型の別名」 |
| E0433 | 定数式でない式 | F07 | 01-02「定数」、02-05「定数の検査と評価」 |
| E0434 | 定数の型が型パラメータを含む | F07 | 01-06「定数の型」 |
| E0435 | 定数の評価が実行時エラーの条件に当たる（`{condition}` は 0 による除算・`Integer` の溢れ・`Decimal` の溢れ。`typeck` の `text` の文） | F07 | 02-01「定数の評価」、ADR 0123 |
| E0436 | 定数の `Map.fromList`・`Set.fromList` の重なる鍵 | F07 | ADR 0136 |
| E0437 | 定数の循環 | F06 | 02-04「宣言の検査」（名前解決が報告する） |
| E0438 | `Unit` でない関数が `return` なしに本体の終わりに達しうる | F07 | 01-02「return」、01-06「必ず抜ける文」 |
| E0439 | 必ず抜ける文の後の文 | F07 | 同上 |
| E0440 | `try` の対象が `Result` でも `Option` でもない | F09 | 01-09「try」 |
| E0441 | `try` と囲む関数の戻り値の型の不一致 | F09 | 同上 |
| E0442 | `try` の誤りの型の不一致 | F09 | 同上 |
| E0443 | `with` の束縛の式がリソースの型でない | F09 | 01-10 |
| E0444 | 欠番。使わない（「番号の付け方」の `RETIRED`） | — | [ADR 0316](../../2026-10-09-design-first-release/decisions/0316-no-compile-time-regex-check-in-first-release.md) |

### E05 エフェクト、ハンドラ

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0501、E0502 | 宣言しないエフェクト（最小実行版。利用者のエフェクトの操作の呼び出しを含む） | F07 | 01-07、02-05 |
| E0503 | `lazy` の本体のエフェクト | F09 | 01-06「明示遅延」 |
| E0504 | ガードのエフェクト | F10 | 02-05 |
| E0505 | `with` の束縛の外の `TaskGroup.open` | F09 | 01-11、ADR 0153 |
| E0506 | `main` とテストの関数で処理していない利用者のエフェクト | F09 | 01-07「プログラムの入口」、06-04 |
| E0507 | `handle` の節に操作でない関数を書いた | F09 | 02-10「診断コード」 |
| E0508 | 一つの `handle` の同じ操作の二つの節 | F09 | 同上 |
| E0509 | `resume` を書けない位置（構文解析器が報告する） | F04 | 02-03「文脈の制限」、ADR 0155 |
| E0510 | 操作の宣言の `uses` とエフェクト変数、型構成子を表す型パラメータ、型パラメータの型クラスの制約（構文解析器が報告する。後の二つは F09 が加える。ADR 0311・0312） | F04、F09 | 01-02「エフェクトの宣言とハンドラ」 |

### E06 パターン

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0601 | 網羅していない `match`（最小実行版） | F10 | 01-05、02-05 |
| E0602 | 選ばれない分岐（最小実行版。ガード付きの分岐を含む） | F10 | 同上 |
| E0603 | 定数と同じ名前のパターンの変数 | F06 | 01-05「パターン」、02-10「修正案」、ADR 0123 |
| E0604 | 選択肢の束縛する名前の違い（型の違いは E0401 の鍵 `because_alternatives`） | F06 | 01-05「パターンの拡張」 |
| E0605 | 下端が上端より大きい範囲 | F10 | 同上 |
| E0606 | 範囲の両端が `Integer` か `Character` の同じ種類のリテラルでない | F10 | 同上 |
| E0607 | 束縛の文の左辺の、必ず照合しないパターン | F10 | 01-05「必ず照合するパターン」、02-10「修正案」 |
| E0608 | 選ばれない選択肢 | F10 | 01-05「選ばれない分岐の検査」 |

### E07 型クラス

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0701 | 孤立した実装 | F08 | 01-06「型クラス」、02-05 |
| E0702 | 重なる実装 | F08 | 同上 |
| E0703 | 上位の型クラスの循環 | F06 | 同上 |
| E0704 | 上位の型クラスの制約が解けない実装 | F08 | 同上 |
| E0705 | 解けない制約（実装がない） | F08 | 同上 |
| E0706 | 型パラメータに要る型クラスの制約がない | F08 | 同上 |
| E0707 | メソッドの欠けた実装 | F06 | 同上 |
| E0708 | 型クラスにないメソッドを実装に書いた | F06 | 同上 |
| E0709 | 型クラスの引数を含まないメソッド | F08 | 同上 |
| E0710 | メソッドのない型クラス | F08 | 同上 |
| E0711 | 実装のメソッドの型が型クラスの宣言と合わない | F08 | 同上 |
| E0712 | 実装の対象の形の誤り | F08 | 同上 |
| E0713 | 実装の型パラメータが対象に現れない | F08 | 同上 |
| E0714 | 値の型の型クラスと型構成子の型クラスの取り違え | F08 | 01-06「高カインド型」 |

孤立した実装は、型検査器が実装の検査で判定する（02-05「実装の検査」。2026-09-30、設計者の判断）。02-04・02-05 は、メソッドの欠けた実装・宣言にないメソッド・上位の型クラスの循環を名前解決の段で判定するとしている。どの段が判定しても、コードは E07 とする（02-10 の区分の表）。名前解決の段で判定する三つ（E0703・E0707・E0708）は、名前解決の作業 F06 が出す。

### E08 属性

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| E0801 | 書けない属性 | F03 | 01-02「属性」、ADR 0119 |
| E0802 | 属性を付けられない宣言 | F03 | 同上 |
| E0803 | 同じ属性を二度書いた | F03 | 同上 |
| E0804 | `@deprecated` の引数の誤り（引数がない、二つ以上、空の文字列） | F03 | 同上 |
| E0805 | `@test` の引数が二つ以上 | F03 | 同上 |
| E0806 | `@test` を付けた関数のシグネチャの誤り | F07 | 06-04「テストの関数」 |
| E0807 | 利用者のソースの `@builtin` | F03 | 02-03「標準ライブラリのソースの構文」、ADR 0157 |
| E0808 | 利用者のソースの本体のない関数 | F03 | 同上 |

### 警告

| コード | 条件 | 出す作業 | 根拠 |
|---|---|---|---|
| W0301 | `@deprecated` を付けた宣言の参照（宣言の外からの参照ごと）。鍵 `message` の注記に属性の文字列を示す | F06 | 01-02「属性」、02-04「宣言の検査」、ADR 0119 |
| W0401 | 除数が 0 の定数式の除算 | F07 | ADR 0146 |
| W0402 | 引数がすべて定数式の演算の溢れ（`{ty}` は `Integer` か `Decimal`） | F07 | 同上 |
| W0403 | 定数の外の `Map.fromList`・`Set.fromList` の引数のリストのリテラルで重なる鍵 | F07 | ADR 0136 |
| W0501 | `uses IO.All` と書いた関数の本体が `IO.All` の一部のエフェクトしか生じない。置き換えは生じるエフェクトの並び | F09 | ADR 0116 |

### 実行時エラー、資源の不足、処理系の制限

実行時エラーのコードは、[値とヒープ](10-08-values-and-heap.md)の `Stop` の値ごとに一つ割り当てる（02-10「診断コード」の最後の段落）。報告を組み立てるのは `runtime::report`（[パイプラインと CLI](10-13-pipeline-and-cli.md)。R38）である。

| コード | `Stop` の値 | 根拠 |
|---|---|---|
| R0101 | `RuntimeError::DivisionByZero`（説明を `Decimal` と `floorDivide` に広げた） | 01-08、01-04 |
| R0102 | `RuntimeError::IntegerOverflow` | 同上（最小実行版） |
| R0103 | `RuntimeError::DecimalOverflow` | 01-04「Decimal」 |
| R0201・R0202 | `RuntimeError::WriteFailed`（出力ごと） | 02-09「出力のバッファ」（最小実行版） |
| R0301 | コマンドライン引数の検査（`Stop` でない。`runtime::run::check_args`） | 02-09「プログラムの実行の流れ」（最小実行版） |
| R0401 | `RuntimeError::ReleaseFailed`。`Process.exit` と中断の要求で止める途中の解放の失敗も R0401 とし、報告の種類を `Release` にする | 01-10「解放の失敗」、02-10「解放の失敗の報告」 |
| R0402 | `RuntimeError::ReleasedResourceUsed` | 01-10 |
| R0501 | `RuntimeError::ContinuationResumedTwice` | 01-07、01-12 |
| R0502 | `RuntimeError::InheritedHandlerClause` | 01-11、ADR 0151 |
| R0701 | `RuntimeError::ArgumentOutOfDomain`（`{index}` は 1 から数えた引数の位置） | 01-08 |
| R0801 | `RuntimeError::ResponseSentTwice` | 03-09 |
| R0901 | `ResourceError::CallStackTooDeep` | 02-08「呼び出しの入れ子の上限」（最小実行版） |
| R0902 | `ResourceError::ValueTooLarge`（説明に `Bytes` を加えた） | 02-09「一つの操作で作る値の大きさの上限」（最小実行版） |
| R0903 | `ResourceError::InputTooLarge`（10-08） | 02-10「実行時エラーと資源の不足の報告」 |
| R1001 | `RuntimeError::TaskDeadlock` | 01-11「失敗と停止」、ADR 0238 |
| R1002 | `RuntimeError::AwaitedTaskCancelled`（R39 が加える） | 01-11「取り消し」、ADR 0317 |

処理系の制限は、コード生成（F15）が 02-07「処理系の制限」に従って出す。原型ごとの制限（L0101〜L0104）は制限に当たった関数ごとに一つ出し、その関数の宣言の位置を示す。プログラム全体の制限（L0105〜L0111）は表ごとに一つ出し、位置を持たない。L0109〜L0111 の `{name}` は、型クラスの名前（L0111 は実装の型クラスの名前）である。

| コード | 数 | オペランド |
|---|---|---|
| L0101 | 一つの原型のレジスタの数（最小実行版） | レジスタの番号 |
| L0102 | 一つの原型の定数の番号の並びの長さ（最小実行版） | `LOADK` の Bx |
| L0103 | 一つの原型の分岐表の数 | `SWITCH` の Bx |
| L0104 | 一つの原型のハンドラの記述の番号の並びの長さ | `HANDLE` の C |
| L0105 | 構成子の表 | `CON` の B |
| L0106 | 組み込みの関数の参照 | `PRIM`・`IO` の B |
| L0107 | 実装の表 | `DICT` の B |
| L0108 | 操作の表 | `PERFORM` の B |
| L0109 | 一つの型クラスのメソッドの数 | `METHOD`・`TAILMETHOD` の C |
| L0110 | 一つの型クラスの上位の型クラスの数 | `SUPER` の C |
| L0111 | 一つの実装の制約の辞書の数 | `GETDICT` の B |

オペランドの欄は、[バイトコード](10-07-bytecode.md)の命令の表の被演算子の名前である。オペランドの幅と、原型ごとの制限の上限（65535 か 65536 か）は 10-07 の符号化に従い、表の文言の数と食い違えば、F15 が本章の「型板の直し方」で直す。

## 診断の書き出し

次の関数の中身は F16 が書く。最小実行版の `src/legacy/diag/render.rs` を写し、次の変更を加える。書式は 02-10「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」「解放の失敗の報告」に従う。

| 変更 | 内容 |
|---|---|
| 複数のファイル | 位置の表示名と行の抜粋は、span のファイル ID でソースの表を引いて作る。補助の位置が主な位置と別のファイルにあれば、`:::` の行と抜粋を加える。標準ライブラリのソースの位置も同じく示す（表示名 `<benitoite>/X/Y.bnt`） |
| 修正案の置き換え | 置き換えを持つ修正案は、`= help:` の行の後に、置き換えを当てた後の行を行番号付きで示し、変わった部分の下に `~` を並べる。置き換えが複数の行にわたるときは、変わった行をすべて示す。抜粋の中のタブは空白 4 つにする |
| 警告 | 重大度の語を `warning` とする。件数の行は、誤りと警告を分けて数える（`text::SUMMARY_*`・`WARNINGS_ONLY_*`）。`--deny-warnings` で誤りにした警告は誤りに数える |
| 50 件の打ち切り | 誤りと警告を合わせて数える |
| `test` の件数の行 | `Verb::Test` の `could not test` |
| 呼び出しの履歴の名前 | `FrameName` の `Handle`・`Case`・`Lazy` を `<handle …>`・`<case 操作 …>`・`<lazy …>` と書く |
| タスクの起動の履歴 | `task_origins` が空でなければ、呼び出しの履歴の後に `text::TASK_ORIGINS_HEADER` の注記として並べる |
| 行き詰まり | `waiting` が空でなければ、`-->` の行と抜粋を書かず、`text::WAITING_HEADER` の注記として、タスク・待つ種類・待つ位置を列を揃えて並べる |
| 解放の失敗 | 報告の種類 `Release` は、重大度の位置を `error` とし、JSON の `kind` を `"release"` とする |
| JSON | `helps` の要素を `message` と `edits` のオブジェクトにする。置き換えは `file`・`start`・`end`（`line`・`column`・`offset`）・`replacement` を持つ。`trace` があれば `trace`・`traceOmitted`・`taskOrigins` を、`waiting` が空でなければ `waitingTasks` を加える |

JSON の項目の順は、`kind`・`severity`・`code`・`message`・`primary`・`secondary`・`notes`・`helps` の後に、あれば `trace`・`traceOmitted`・`taskOrigins`・`waitingTasks`・`backtrace` を続ける。`trace`・`taskOrigins` の要素は `function` と `location`、`waitingTasks` の要素は `task`・`waitsFor`・`location` を持つ（`task` は `function` と `location` のオブジェクト）。ゴールデンテストは JSON の文字列どうしを比べるので、この順と、`:` と `,` の後に空白を入れないことを守る。JSON の文字列の書き出しは、依存するクレートを使わずに手で書く（最小実行版のとおり）。

```rust sig=src/diag/render.rs
use crate::base::SourceTable;
use super::Diagnostic;

/// 文章の形式の選択肢。
#[derive(Clone, Copy, Debug)]
pub struct TextOptions {
    /// 色を付けるか。CLI が、標準エラー出力が端末で `NO_COLOR` がないときに true にする
    pub color: bool,
}

/// 件数の行の動詞（02-10「文章の形式」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Verb {
    Run,
    Check,
    Test,
}

/// 検査の診断（誤りと警告）の一覧を、文章の形式にする。渡された順に書き（並べるのは呼び出し側。
/// 10-13 の `pipeline::check`）、誤りと警告を合わせて 50 件を超えた分は書かずに件数を示し、
/// 最後に件数の行を書く（誤りも警告もなければ書かない）。`file` は実行を始めるファイルの表示名。
pub fn render_check_text(diags: &[Diagnostic], sources: &SourceTable, verb: Verb, file: &str, opts: TextOptions) -> String;

/// 一件の診断・報告を文章の形式にする（末尾に空行を含めない改行で終える）。
/// 実行時エラー、資源の不足、解放の失敗、処理系の不具合、処理系の制限、コマンドライン引数の誤りに使う。
pub fn render_one_text(diag: &Diagnostic, sources: &SourceTable, opts: TextOptions) -> String;

/// 一件の診断・報告を、JSON のオブジェクト一つの一行にする（末尾に改行を付けない）。
pub fn render_json_line(diag: &Diagnostic, sources: &SourceTable) -> String;
```

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C02 | `diag/mod.rs`・`codes.rs` の `file=` と、`render.rs` の `sig=` の `todo!()` の仮置き（00-02）を置く |
| F01〜F10、F15、R38、D03 | 「コードの一覧」の「出す作業」の欄のコードの診断を組み立てる。型板は「型板の直し方」の範囲で直してよい |
| F16 | `render.rs` の中身。`DiagBuilder::help_edits` の鍵が `fixes` に含まれることと、`ALL` の番号が区分の中で重ならず `RETIRED` と重ならないことを確かめる単体テスト。F06 までに出る診断（E01〜E03、W0301）の修正案と置き換えを、02-10「修正案」の表と照らして揃える |

F07〜F10 が出す診断の置き換えは、それぞれの作業が付ける。F16 は F06 の後に行うので、F07 以降の診断の置き換えを確かめるのは、それぞれの作業の受け入れテストである。

## 設計書との食い違い

本章を書く中で見つかった、設計書との食い違いと定めのない点を挙げる。設計書の改めは本章の範囲の外である。

- 型クラスのメソッドの名前の重なり（E0328）は、設計書に明記がなかった。本章はこれを誤りとし、設計者が認めて [ADR 0279](../../2026-10-09-design-first-release/decisions/0279-no-duplicate-method-names-in-trait.md) と 01-02・01-06「型クラス」に定めた（2026-09-30）。
- 01-03「トップレベルの名前空間」の重なりの一覧はエフェクトを挙げていなかったが、エフェクトは型と同じ名前空間に入る（同節）。E0305 はエフェクトを含める。一覧にエフェクトを加えた（2026-09-30）。
- 02-10「診断コード」は範囲のパターンの誤りを E06 に置くが、構文の形の誤り（`1..=5`）は構文解析器が判定するので E02（E0242）に置いた。同じく、02-10 は `resume` の位置と操作の宣言の誤りを E05 に置き、構文解析器が報告するとしているので、本章もそれに従った（E0509・E0510）。
- 02-10「修正案」の表の「`{` を次の行の先頭に書いた」の行は、最小実行版の波括弧の書き方の名残だったので、初回リリース版の E0212（波括弧のブロック。置き換えなし）に当たる行に改めた。
- 文字列補間の入れ子の深さを構文の入れ子と合わせて数えることは 02-03 が定めるが、その診断のコードは定めがない。本章は E0208 とした。

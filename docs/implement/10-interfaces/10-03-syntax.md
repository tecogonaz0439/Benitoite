# 字句と構文木

本章は、初回リリース版の字句、抽象構文木（AST）、字句の切り出し・改行の判定・構文解析の関数のシグネチャを定める。設計書の対応する章は[字句解析器と構文解析器](../../design/02-impl/02-03-frontend.md)であり、字句と文法の規則は[字句構造](../../design/01-spec/01-01-lexical.md)と[構文](../../design/01-spec/01-02-syntax.md)の「初回リリース版の文法の全体」で定める。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C02

本章のコードは C02 が置く。U2 第 1 段は構文木を使わないので、C01 は本章を置かない。

最小実行版の実装した構文は、波括弧でブロックを書く形（`fn f() -> Int { let x = e }`、`match x { p => e }`、`==`・`&&`）であり、初回リリース版の構文（`function … end function`、`bind x <- e`、`match … with case … end match`、`=`・`and`）とは字句の集合から違う。そこで、本章は `syntax` の四つのファイル（`token.rs`・`lexer.rs`・`newline.rs`・`ast.rs`）と構文解析器の入口（`parser/mod.rs`）を新しく定める。「置く」のファイルは、C04 が最小実行版の同じパスのファイルを `src/legacy/` へ移して空けたパスに、新しく置く（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。最小実行版の字句の切り出しと改行の判定の中身（`src/legacy/syntax/`）は、文字の読み方（UTF-8 の検査、エスケープシーケンス、数値リテラル、見えない文字の検査）を F01 が写して使ってよい。構文解析器の中身は F02〜F04 が書き直す。最小実行版の構文解析器は `legacy` に残り、C05 が古い構文のテストを消すまで、そのテストが使う。

| ファイル | 扱い | 中身を書く作業 |
|---|---|---|
| `src/syntax/mod.rs` | 置く（`file=`） | — |
| `src/syntax/token.rs` | 置く（`file=`） | — |
| `src/syntax/lexer.rs` | 置く（`sig=`） | F01 |
| `src/syntax/newline.rs` | 置く（`sig=`） | F01 |
| `src/syntax/ast.rs` | 置く（`file=`） | — |
| `src/syntax/parser/mod.rs` | 置く（`sig=`） | F02（F03・F04 が子のモジュールを加える） |

構文解析器の子のモジュール（宣言、式、パターン、型の解析）の分け方は、F02〜F04 の作業の文書で決める。F03 と F04 は並行して進めるので、F02 が子のモジュールの境目（宣言を読む関数、文と式を読む関数、パターンを読む関数、型を読む関数と、解析の文脈の印）を先に置く。

## モジュールの構成

```rust file=src/syntax/mod.rs
//! 字句解析と構文解析（設計書 02-03）。
//! 処理の流れ: lexer（字句の切り出し）→ newline（改行の判定）→ parser（構文解析）。

pub mod ast;
pub mod lexer;
pub mod newline;
pub mod parser;
pub mod token;
```

## 字句

字句の種類は、01-01 の字句と 02-03「字句」のキーワードの表（初回リリース版には予約語がない）と記号に、改行の印・NEWLINE・誤りの字句・ファイルの終わりを加えたものである。`as`・`equality`・`key`・`ordered` はキーワードにせず、小文字の識別子の字句にする（02-03「字句」）。

誤りの字句は二種類ある。`Error` は字句を切り出す工程が誤りを報告済みの字句であり、構文解析器はその位置で期待した構文の誤りのノードにして、新たな構文エラーを報告しない。`BadSymbol` は字句に使えない記号（`;`、`{`、`==`、`&&`、`=>`、`%`、`?`、`#`、`|` など）であり、字句を切り出す工程は報告せず、構文解析器が文脈に合った修正案とともに一度ずつ報告する（02-03「字句の誤り」「他の言語の書き方への診断」）。

文字列補間を含む文字列リテラルは、`StrStart`・`StrMid`・`StrEnd` と、`${` と `}` の間の式の字句に分ける（01-01「文字列リテラル」）。複数行の文字列と raw 文字列は、補間を含まなければ `StringLit` 一つである。どの字句の span もソースに書いた範囲を指す（02-02「span」）。

```rust file=src/syntax/token.rs
//! 字句（設計書 02-03「字句」、01-01）。

use crate::base::Span;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TokenKind {
    LowerIdent,
    UpperIdent,
    IntLit,
    FloatLit,
    /// `Decimal` のリテラル（`1.25m`）
    DecimalLit,
    /// 文字列補間を含まない文字列リテラル（複数行の文字列と raw 文字列を含む）
    StringLit,
    /// 補間の開始: 開きの引用符から最初の `${` まで
    StrStart,
    /// 補間の中間: 式の後の `}` から次の `${` まで
    StrMid,
    /// 補間の終わり: 最後の式の後の `}` から閉じの引用符まで
    StrEnd,
    CharLit,
    // キーワード（02-03「字句」のキーワードの表）
    KwAnd,
    KwBind,
    KwCase,
    KwConst,
    KwData,
    KwDiv,
    KwDo,
    KwEffect,
    KwElse,
    KwEnd,
    KwFalse,
    KwFunction,
    KwHandle,
    KwIf,
    KwImplement,
    KwImport,
    KwLambda,
    KwLazy,
    KwMatch,
    KwMod,
    KwNot,
    KwOr,
    KwPublic,
    KwRecord,
    KwResume,
    KwReturn,
    KwShadow,
    KwThen,
    KwTrait,
    KwTrue,
    KwTry,
    KwType,
    KwUses,
    KwWith,
    // 演算子と区切り記号（01-01「演算子と区切り記号」）
    /// `+`
    Plus,
    /// `-`
    Minus,
    /// `*`
    Star,
    /// `/`
    Slash,
    /// `=`
    Eq,
    /// `<>`
    NotEq,
    /// `<`
    Lt,
    /// `<=`
    Le,
    /// `>`
    Gt,
    /// `>=`
    Ge,
    /// `|>`
    PipeGt,
    /// `->`
    Arrow,
    /// `<-`
    LeftArrow,
    /// `:`
    Colon,
    /// `,`
    Comma,
    /// `.`
    Dot,
    /// `..`
    DotDot,
    /// `&`
    Amp,
    /// `@`
    At,
    LParen,
    RParen,
    LBracket,
    RBracket,
    /// `_` 一文字
    Underscore,
    /// 改行の印。字句の切り出しの工程だけが作る
    LineBreak,
    /// 改行の判定で残った改行字句（NEWLINE）
    Newline,
    /// 字句を切り出す工程が誤りを報告済みの字句（許されない文字、誤りを含むリテラルなど）。
    /// 構文解析器は、期待していた構文の誤りのノードにし、新たな構文エラーを報告しない
    Error,
    /// 字句に使えない記号（`;`・`{`・`}`・`==`・`!=`・`&&`・`||`・`!`・`=>`・`%`・`?`・`#`・`|` など）。
    /// 値は `TokenValue::Symbol`。構文解析器が文脈で修正案を選んで報告する（02-03「字句の誤り」）
    BadSymbol,
    /// ファイルの終わり。span の長さは 0
    Eof,
}

/// 字句が持つ値（02-03「字句」の表）。
#[derive(Clone, PartialEq, Debug)]
pub enum TokenValue {
    None,
    /// 識別子の綴り
    Ident(String),
    /// 基数（2・8・10・16）と、接頭辞と `_` を除いた数字列
    Int { radix: u32, digits: String },
    /// `_` を除いた字面
    Float(String),
    /// `_` と接尾辞 `m` を除いた字面
    Decimal(String),
    /// エスケープを解いた後の文字列。複数行の文字列は字下げを除き行末の `\` を処理した後、
    /// raw 文字列は書いた文字の並びそのもの。`StrStart`・`StrMid`・`StrEnd` はその部分の文字列
    Str(String),
    /// エスケープを解いた後のスカラー値
    Char(char),
    /// `BadSymbol` の記号の字面
    Symbol(String),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Token {
    pub kind: TokenKind,
    pub span: Span,
    pub value: TokenValue,
}

/// コメントの種類（02-03「コメントとドキュメントコメント」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum CommentKind {
    /// `//`（`////` 以上を含む）
    Plain,
    /// `///`: 直後の宣言の説明
    Doc,
    /// `//!`: ファイルのモジュールの説明
    ModuleDoc,
}

/// コメント一つ。本文は `//`・`///`・`//!` の後から行末まで（改行を含まない）。
#[derive(Clone, PartialEq, Debug)]
pub struct Comment {
    pub span: Span,
    pub kind: CommentKind,
    pub text: String,
}
```

## 字句の切り出しと改行の判定

字句の切り出しは、シェバンの行を読み飛ばし（01-01「シェバンの行（初回リリース版）」）、文字列補間・複数行の文字列・raw 文字列を 02-03「文字列補間と複数行の文字列の切り出し」の手順で分ける。コメントは種類を分けて別の一覧に集める。

```rust sig=src/syntax/lexer.rs needs=10-02
use crate::base::FileId;
use crate::diag::Diagnostic;
use super::token::{Comment, Token};

/// 字句の切り出しの結果。
#[derive(Debug)]
pub struct LexOutput {
    /// 字句と改行の印（`LineBreak`）の列。最後は必ず `Eof`。
    /// フォーマッタ（U4）は、この列を改行の位置を知るために使う（02-03「用途」）
    pub tokens: Vec<Token>,
    /// ドキュメントコメントを含むすべてのコメント。ソースの順
    pub comments: Vec<Comment>,
    pub diagnostics: Vec<Diagnostic>,
}

/// ソースのバイト列（`Source::text()`）を先頭から読み、字句と改行の印の列を作る（02-03「処理の流れ」の 1）。
/// span のファイル ID には `file` を使う。誤りを報告した後も続ける（02-03「字句の誤り」）。
/// ファイルの先頭（先頭の U+FEFF があればその直後）の `#!` から改行の直前までは、シェバンの行として
/// 読み飛ばし、改行の印は残す。
pub fn lex(file: FileId, text: &[u8]) -> LexOutput;
```

改行の判定は、開いている括弧とキーワードのブロックの積み重ねを持って字句の列を一度辿る（02-03「処理の流れ」の 2）。`with` の次の字句が `case` かどうか、`match` と `handle` の分岐の頭の `if` がガードかどうかも、この工程で判定する。

```rust sig=src/syntax/newline.rs
use super::token::Token;

/// 改行の印ごとに、NEWLINE を置くか空白として捨てるかを決める（01-01「改行による区切り」）。
/// 入力は `lex` の字句の列。出力は `LineBreak` を含まない。連続する NEWLINE は一つにまとめる。
pub fn resolve_newlines(tokens: Vec<Token>) -> Vec<Token>;
```

## AST

AST は、01-02「初回リリース版の文法の全体」の形をそのまま表す（02-03「AST」）。パイプ、プレースホルダを含む呼び出し、括弧の式、`else if` の連なり、文字列補間、`try`、レコードの一部を変えた値、束縛の文のパターン、パターンの選択肢とガードは、展開せずに書かれた形で持つ。展開は型検査と脱糖が行う。

各ノードは、span と、一つの検査の中で重ならないノード番号（`id`）を持つ。名前を束縛する箇所と名前を使う箇所は、それぞれ独立したノードである。名前解決の表の鍵にするノードを次に示す。

| 役割 | ノード（欄 `id`） |
|---|---|
| 束縛を宣言したノード（名前解決の `decls` の鍵） | `FnDecl`・`ConstDecl`・`DataDecl`・`Variant`・`AliasDecl`・`RecordDecl`・`FieldDecl`・`TraitDecl`・`MethodSig`・`EffectDecl`・`OpSig`・`ImportDecl`・`TypeParamDecl`・`Param`・`VarPat`・`ListRest`（残りの変数があるとき）・`WithBind`・`ClauseParam`（名前のあるとき） |
| 名前を使うノード（名前解決の `refs` の鍵） | `NameExpr`・`NamedType`・`EffectRef`・`CtorPat`・`RecordExpr`・`RecordPat`・`FieldArg`・`FieldPat`・`OpRef`・`ClassRef`・`ImplFn` |

`ImplFn` は、実装の中の関数の宣言の名前を、型クラスのメソッドを使う箇所として持つノードである。同じ関数は、`ImplFn::decl`（`FnDecl`）の `id` で自分の束縛を宣言する（02-04「束縛と表」）。`ImportDecl` は、取り込んだモジュールに付けた名前の束縛を宣言し、同時にモジュールの名前を使う箇所でもある（参照の表は取り込んだモジュールの束縛を指す）。

修飾した名前は、段の並び（`Vec<Name>`。各段の名前と span）で持ち、段の数に上限を設けない（02-03「AST」、ADR 0126）。各段が何を指すかは名前解決が決める。

ドキュメントコメントは、`///` を付けられる宣言（トップレベルの宣言、構成子、フィールド、メソッド、操作、実装の中の関数）の欄 `doc` に、`//!` はモジュールの欄 `doc` に入れる（02-03「コメントとドキュメントコメント」）。連続する行は一つの説明にまとめ、各行の `///`・`//!` の後の本文を改行でつないだ文字列を持つ。

誤りのノード（`ErrorNode`）は、構文エラーから回復した箇所に置く。誤りのノードを含む AST は名前解決以降の段に渡らない（ADR 0019）。

```rust file=src/syntax/ast.rs
//! 抽象構文木（設計書 02-03「AST」）。名前解決と型検査はこの木を変更しない（ADR 0022）。
//! 形は 01-02「初回リリース版の文法の全体」をそのまま表す。

use crate::base::{FileId, NodeId, Span};

/// 名前の綴りと位置。ノードではない。
#[derive(Clone, PartialEq, Debug)]
pub struct Name {
    pub text: String,
    pub span: Span,
}

/// 構文エラーから回復した箇所に置くノード。読み飛ばした範囲を span に持つ。
#[derive(Clone, PartialEq, Debug)]
pub struct ErrorNode {
    pub id: NodeId,
    pub span: Span,
}

/// ドキュメントコメント（`///` か `//!` の連続する行）。`text` は各行の本文を改行でつないだもの。
/// span は最初の行の先頭から最後の行の末尾まで。
#[derive(Clone, PartialEq, Debug)]
pub struct DocComment {
    pub span: Span,
    pub text: String,
}

// ---------------- モジュールと宣言 ----------------

/// ファイル一つのモジュール（02-03「AST」）。
#[derive(Clone, PartialEq, Debug)]
pub struct Module {
    pub id: NodeId,
    pub span: Span,
    pub file: FileId,
    /// ファイルの先頭の `//!` の説明
    pub doc: Option<DocComment>,
    pub imports: Vec<ImportDecl>,
    pub decls: Vec<TopDecl>,
}

/// `import A.B.C [as X]`。取り込んだモジュールに付けた名前の束縛を宣言し、
/// モジュールの名前を使う箇所でもある（10-04「名前解決の表」）。
#[derive(Clone, PartialEq, Debug)]
pub struct ImportDecl {
    pub id: NodeId,
    pub span: Span,
    /// モジュールの名前の各段
    pub path: Vec<Name>,
    pub alias: Option<Name>,
}

/// トップレベルの宣言と、その前の説明・属性・`public`（01-02「属性（初回リリース版）」）。
#[derive(Clone, PartialEq, Debug)]
pub struct TopDecl {
    /// 説明を除き、最初の属性（なければ `public`、なければ宣言の最初の字句）から宣言の終わりまで
    pub span: Span,
    pub doc: Option<DocComment>,
    pub attrs: Vec<Attribute>,
    /// `public` の字句の位置。書かなければ `None`
    pub public: Option<Span>,
    pub item: Item,
}

#[derive(Clone, PartialEq, Debug)]
pub enum Item {
    Fn(Box<FnDecl>),
    Const(ConstDecl),
    Data(DataDecl),
    Alias(AliasDecl),
    Record(RecordDecl),
    Trait(TraitDecl),
    Effect(EffectDecl),
    Impl(ImplDecl),
    Error(ErrorNode),
}

/// 属性 `@name("arg", ...)`。
#[derive(Clone, PartialEq, Debug)]
pub struct Attribute {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub args: Vec<StrArg>,
}

/// 属性の引数（文字列補間を含まない文字列リテラル）。
#[derive(Clone, PartialEq, Debug)]
pub struct StrArg {
    pub span: Span,
    pub value: String,
}

/// 関数の宣言。トップレベルの関数、実装の中の関数、`@builtin` を付けた本体のない関数。
#[derive(Clone, PartialEq, Debug)]
pub struct FnDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub params: Vec<Param>,
    pub ret: TypeExpr,
    pub uses: Option<UsesList>,
    /// `@builtin` を付けた宣言（標準ライブラリのソースだけ）は `None`（02-03「標準ライブラリのソースの構文」）
    pub body: Option<Block>,
}

/// 型パラメータの宣言。関数・メソッド・操作・実装・型クラスの引数・型の宣言の型パラメータ。
#[derive(Clone, PartialEq, Debug)]
pub struct TypeParamDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub kind: TypeParamKind,
    /// `:` の後の制約の並び（`&` で区切った順）。型クラスの宣言の引数では上位の型クラスの並び
    pub constraints: Vec<ConstraintRef>,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum TypeParamKind {
    /// 値の型を表す型パラメータ（`T`）
    Value,
    /// 型構成子を表す型パラメータ（`F[_]`）。`arity` は `_` の数
    Ctor { arity: u32 },
    /// エフェクト変数（`effect E`）
    Effect,
}

/// 制約の位置に書いたもの。
#[derive(Clone, PartialEq, Debug)]
pub enum ConstraintRef {
    /// 型クラスの名前（修飾した名前を含む）
    Class(ClassRef),
    /// 組み込みの制約（`equality`・`key`、標準ライブラリのソースでは `ordered`）
    Builtin {
        span: Span,
        kind: BuiltinConstraint,
    },
}

/// 組み込みの制約（01-06「組み込みの制約（初回リリース版）」「標準ライブラリの関数の型」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum BuiltinConstraint {
    Equality,
    Key,
    /// 順序の比較演算子の型の集まり。標準ライブラリのソースでだけ書ける
    Ordered,
}

/// 型クラスの名前を使う箇所（制約、上位の型クラス、`implement` の型クラス）。
#[derive(Clone, PartialEq, Debug)]
pub struct ClassRef {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
}

/// 関数・メソッド・操作・ラムダの引数。関数・メソッド・操作の引数は `ty` が必ず `Some`（文法が要求する）。
#[derive(Clone, PartialEq, Debug)]
pub struct Param {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub ty: Option<TypeExpr>,
}

/// `const name: T = e`。
#[derive(Clone, PartialEq, Debug)]
pub struct ConstDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub ty: TypeExpr,
    pub value: Expr,
}

/// `data Name[T] … end data`。型パラメータの `kind` は `Value` だけで、制約を持たない。
#[derive(Clone, PartialEq, Debug)]
pub struct DataDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub variants: Vec<Variant>,
}

/// データ構成子の宣言。
#[derive(Clone, PartialEq, Debug)]
pub struct Variant {
    pub id: NodeId,
    pub span: Span,
    pub doc: Option<DocComment>,
    pub name: Name,
    pub fields: Vec<TypeExpr>,
}

/// `type Name[T] = T'`。
#[derive(Clone, PartialEq, Debug)]
pub struct AliasDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub ty: TypeExpr,
}

/// `record Name[T] … end record`。
#[derive(Clone, PartialEq, Debug)]
pub struct RecordDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub fields: Vec<FieldDecl>,
}

/// フィールドの宣言。フィールドを取り出す関数の束縛を兼ねる（02-04「束縛と表」）。
#[derive(Clone, PartialEq, Debug)]
pub struct FieldDecl {
    pub id: NodeId,
    pub span: Span,
    pub doc: Option<DocComment>,
    pub name: Name,
    pub ty: TypeExpr,
}

/// `trait Name[P: S1 & S2] … end trait`。`param.constraints` は上位の型クラスの並び（`Class` だけ）。
#[derive(Clone, PartialEq, Debug)]
pub struct TraitDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub param: TypeParamDecl,
    pub methods: Vec<MethodSig>,
}

/// 型クラスのメソッドの宣言（本体を持たない）。
#[derive(Clone, PartialEq, Debug)]
pub struct MethodSig {
    pub id: NodeId,
    pub span: Span,
    pub doc: Option<DocComment>,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub params: Vec<Param>,
    pub ret: TypeExpr,
    pub uses: Option<UsesList>,
}

/// `implement[T: C] Class[Target] … end implement`。束縛を作らない（02-04「束縛と表」）ので、
/// 型検査と脱糖はこのノードの `id` で実装を指す。
#[derive(Clone, PartialEq, Debug)]
pub struct ImplDecl {
    pub id: NodeId,
    pub span: Span,
    pub type_params: Vec<TypeParamDecl>,
    pub class: ClassRef,
    pub target: TypeExpr,
    pub fns: Vec<ImplFn>,
}

/// 実装の中の関数。`id` はメソッドの名前を使う箇所（参照の表でメソッドの束縛を指す）、
/// `decl.id` はこの関数自身の束縛を宣言したノード。
#[derive(Clone, PartialEq, Debug)]
pub struct ImplFn {
    pub id: NodeId,
    pub doc: Option<DocComment>,
    pub decl: FnDecl,
}

/// `effect Name … end effect`。
#[derive(Clone, PartialEq, Debug)]
pub struct EffectDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub ops: Vec<OpSig>,
}

/// エフェクトの操作の宣言。`uses` を持たず、型パラメータにエフェクト変数を持たない（構文解析器が検査する）。
#[derive(Clone, PartialEq, Debug)]
pub struct OpSig {
    pub id: NodeId,
    pub span: Span,
    pub doc: Option<DocComment>,
    pub name: Name,
    pub type_params: Vec<TypeParamDecl>,
    pub params: Vec<Param>,
    pub ret: TypeExpr,
}

// ---------------- 型 ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum TypeExpr {
    Named(NamedType),
    Fn(FnType),
    Paren(ParenType),
    Error(ErrorNode),
}

/// 名前の型（修飾した名前と型引数）。名前を使う箇所のノード。
/// 型構成子を書く位置（`implement Functor[Option]` の `Option`）も、型引数のないこのノードで表す。
#[derive(Clone, PartialEq, Debug)]
pub struct NamedType {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
    pub args: Vec<TypeExpr>,
}

/// `function(A, B) -> R uses E`。
#[derive(Clone, PartialEq, Debug)]
pub struct FnType {
    pub id: NodeId,
    pub span: Span,
    pub params: Vec<TypeExpr>,
    pub ret: Box<TypeExpr>,
    pub uses: Option<UsesList>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct ParenType {
    pub id: NodeId,
    pub span: Span,
    pub inner: Box<TypeExpr>,
}

/// `uses` の並び。span は `uses` から最後の名前まで。
#[derive(Clone, PartialEq, Debug)]
pub struct UsesList {
    pub span: Span,
    pub effects: Vec<EffectRef>,
}

/// `uses` の並びの中のエフェクトの名前（修飾した名前）。名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct EffectRef {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
}

// ---------------- ブロックと文 ----------------

/// 文の並び。関数とラムダの本体、`if` の分岐、`match` の分岐と `handle` の節の本体、
/// `lazy`・`with`・`handle` の本体。
#[derive(Clone, PartialEq, Debug)]
pub struct Block {
    pub id: NodeId,
    pub span: Span,
    pub stmts: Vec<Stmt>,
}

#[derive(Clone, PartialEq, Debug)]
pub enum Stmt {
    /// 大きいので箱に入れる（`Stmt` の大きさを式の大きさに揃える）
    Bind(Box<BindStmt>),
    Expr(Expr),
    Error(ErrorNode),
}

/// `bind` と `shadow` のどちらで書いたか（02-03「構文解析の方式」、ADR 0255）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BindMode {
    Bind,
    Shadow,
}

/// 束縛の文 `bind p: T <- e`・`shadow p: T <- e`。左辺の名前は `VarPat` が束縛を宣言する。
#[derive(Clone, PartialEq, Debug)]
pub struct BindStmt {
    pub id: NodeId,
    pub span: Span,
    pub mode: BindMode,
    /// `bind`・`shadow` の字句の位置（修正案の診断に使う）
    pub keyword_span: Span,
    pub pattern: Pattern,
    pub ty: Option<TypeExpr>,
    pub value: Expr,
}

// ---------------- 式 ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum Expr {
    Lit(LitExpr),
    Interp(InterpExpr),
    Name(NameExpr),
    Unit(UnitExpr),
    Paren(ParenExpr),
    List(ListExpr),
    Call(CallExpr),
    Record(RecordExpr),
    Binary(BinaryExpr),
    Unary(UnaryExpr),
    Pipe(PipeExpr),
    If(IfExpr),
    Match(MatchExpr),
    Lambda(LambdaExpr),
    Return(ReturnExpr),
    Try(TryExpr),
    Lazy(LazyExpr),
    With(WithExpr),
    Handle(HandleExpr),
    Resume(ResumeExpr),
    Error(ErrorNode),
}

#[derive(Clone, PartialEq, Debug)]
pub enum Literal {
    /// 基数と、接頭辞と `_` を除いた数字列。値の範囲は型検査器が判定する（02-03「字句」）
    Int { radix: u32, digits: String },
    /// `_` を除いた字面
    Float(String),
    /// `_` と接尾辞 `m` を除いた字面
    Decimal(String),
    Str(String),
    Char(char),
    Bool(bool),
}

#[derive(Clone, PartialEq, Debug)]
pub struct LitExpr {
    pub id: NodeId,
    pub span: Span,
    pub lit: Literal,
}

/// 文字列補間 `"a${x}b${y}c"`。`head` が `a`、`segments` の各要素が `${x}` と続く部分の文字列 `b`・`c`。
#[derive(Clone, PartialEq, Debug)]
pub struct InterpExpr {
    pub id: NodeId,
    /// 文字列リテラル全体
    pub span: Span,
    /// 最初の `${` の前の部分の文字列（エスケープを解いた後）
    pub head: String,
    pub segments: Vec<InterpSegment>,
}

/// 補間の一つの式と、その後の部分の文字列。
#[derive(Clone, PartialEq, Debug)]
pub struct InterpSegment {
    /// `${` から `}` まで（02-02「合成ノードの由来位置」の文字列補間）
    pub span: Span,
    pub expr: Expr,
    /// `}` の後、次の `${` か閉じの引用符までの部分の文字列
    pub tail: String,
}

/// 式の中の名前（修飾を含む）。名前を使う箇所のノード。`path` は一つ以上の段。
#[derive(Clone, PartialEq, Debug)]
pub struct NameExpr {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
}

/// `()` の式。
#[derive(Clone, PartialEq, Debug)]
pub struct UnitExpr {
    pub id: NodeId,
    pub span: Span,
}

/// 括弧で囲んだ式 `(e)`。パイプの右辺の括弧を区別するためにノードとして残す（ADR 0050）。
#[derive(Clone, PartialEq, Debug)]
pub struct ParenExpr {
    pub id: NodeId,
    pub span: Span,
    pub inner: Box<Expr>,
}

/// リストリテラル。展開 `..e` は高々一つ（構文解析器が検査する。ADR 0272）。
#[derive(Clone, PartialEq, Debug)]
pub struct ListExpr {
    pub id: NodeId,
    pub span: Span,
    pub elems: Vec<ListElem>,
}

#[derive(Clone, PartialEq, Debug)]
pub enum ListElem {
    Expr(Expr),
    Spread(SpreadElem),
}

/// リストリテラルの展開の要素 `..e`。
#[derive(Clone, PartialEq, Debug)]
pub struct SpreadElem {
    pub id: NodeId,
    /// `..` から `e` の終わりまで
    pub span: Span,
    pub expr: Expr,
}

/// 呼び出し。引数に一つでも `Placeholder` があれば、プレースホルダを含む呼び出しである。
#[derive(Clone, PartialEq, Debug)]
pub struct CallExpr {
    pub id: NodeId,
    pub span: Span,
    pub callee: Box<Expr>,
    pub args: Vec<Arg>,
}

#[derive(Clone, PartialEq, Debug)]
pub enum Arg {
    Expr(Expr),
    Placeholder(PlaceholderArg),
}

/// 呼び出しの直接の引数に書いた `_`。
#[derive(Clone, PartialEq, Debug)]
pub struct PlaceholderArg {
    pub id: NodeId,
    pub span: Span,
}

/// レコードの構築 `R(f: e, ...)` と一部を変えた値 `R(..base, f: e, ...)`。
/// `id` はレコードの名前（`path`）を使う箇所のノード。フィールドは一つ以上（構文解析器が検査する）。
#[derive(Clone, PartialEq, Debug)]
pub struct RecordExpr {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
    pub base: Option<Box<Expr>>,
    /// 書いた順
    pub fields: Vec<FieldArg>,
}

/// レコードの構築のフィールドの引数 `name: e`。`id` はフィールドの名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct FieldArg {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub value: Expr,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum BinOp {
    /// `+`
    Add,
    /// `-`
    Sub,
    /// `*`
    Mul,
    /// `/`
    Div,
    /// `div`
    IntDiv,
    /// `mod`
    Mod,
    /// `=`
    Eq,
    /// `<>`
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    /// `and`
    And,
    /// `or`
    Or,
}

#[derive(Clone, PartialEq, Debug)]
pub struct BinaryExpr {
    pub id: NodeId,
    pub span: Span,
    pub op: BinOp,
    /// 演算子の字句の位置
    pub op_span: Span,
    pub lhs: Box<Expr>,
    pub rhs: Box<Expr>,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum UnOp {
    /// 単項の `-`
    Neg,
    /// `not`
    Not,
}

#[derive(Clone, PartialEq, Debug)]
pub struct UnaryExpr {
    pub id: NodeId,
    pub span: Span,
    pub op: UnOp,
    pub op_span: Span,
    pub operand: Box<Expr>,
}

/// パイプ `lhs |> rhs`。展開しない形で持つ（02-03「AST」）。
#[derive(Clone, PartialEq, Debug)]
pub struct PipeExpr {
    pub id: NodeId,
    pub span: Span,
    pub lhs: Box<Expr>,
    pub rhs: Box<Expr>,
}

/// `if c then B else B' end if`。
#[derive(Clone, PartialEq, Debug)]
pub struct IfExpr {
    pub id: NodeId,
    pub span: Span,
    pub cond: Box<Expr>,
    pub then_block: Block,
    pub else_branch: Option<ElseBranch>,
}

/// `else` の後。`else if` の連なりは `If` で表す（02-03「AST」）。
#[derive(Clone, PartialEq, Debug)]
pub enum ElseBranch {
    Block(Block),
    If(Box<IfExpr>),
}

/// `match e with case … end match`。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchExpr {
    pub id: NodeId,
    pub span: Span,
    pub scrutinee: Box<Expr>,
    pub arms: Vec<MatchArm>,
}

/// `match` の分岐 `case p1, p2 if g -> body`。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchArm {
    pub id: NodeId,
    /// `case` から本体の終わりまで
    pub span: Span,
    /// コンマで並べた選択肢。一つ以上
    pub patterns: Vec<Pattern>,
    pub guard: Option<Box<Expr>>,
    pub body: Block,
}

/// `lambda(x, y: T) -> R uses E … end lambda`。
#[derive(Clone, PartialEq, Debug)]
pub struct LambdaExpr {
    pub id: NodeId,
    pub span: Span,
    pub params: Vec<Param>,
    pub ret: Option<TypeExpr>,
    pub uses: Option<UsesList>,
    pub body: Block,
}

/// `return e`。
#[derive(Clone, PartialEq, Debug)]
pub struct ReturnExpr {
    pub id: NodeId,
    pub span: Span,
    pub value: Box<Expr>,
}

/// 前置の `try e`（01-02「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」）。
#[derive(Clone, PartialEq, Debug)]
pub struct TryExpr {
    pub id: NodeId,
    pub span: Span,
    pub value: Box<Expr>,
}

/// `lazy … end lazy`。
#[derive(Clone, PartialEq, Debug)]
pub struct LazyExpr {
    pub id: NodeId,
    pub span: Span,
    pub body: Block,
}

/// `with x = e, y = e' do … end with`。
#[derive(Clone, PartialEq, Debug)]
pub struct WithExpr {
    pub id: NodeId,
    pub span: Span,
    /// 書いた順。一つ以上
    pub binds: Vec<WithBind>,
    pub body: Block,
}

/// `with` の束縛 `x = e`。`id` は名前 `x` の束縛を宣言したノード。
#[derive(Clone, PartialEq, Debug)]
pub struct WithBind {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub value: Expr,
}

/// `handle … with case op(x) -> … end handle`。
#[derive(Clone, PartialEq, Debug)]
pub struct HandleExpr {
    pub id: NodeId,
    pub span: Span,
    pub body: Block,
    /// 一つ以上
    pub clauses: Vec<HandleClause>,
}

/// `handle` の節 `case op(x, _) -> body`。
#[derive(Clone, PartialEq, Debug)]
pub struct HandleClause {
    pub id: NodeId,
    /// `case` から本体の終わりまで
    pub span: Span,
    pub op: OpRef,
    pub params: Vec<ClauseParam>,
    pub body: Block,
}

/// 節の `case` に書いた操作の名前（修飾した名前、最後の段は小文字）。名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct OpRef {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
}

/// 節の引数。名前を書いたものは束縛を宣言する。`_` を書いたものは `name` が `None`。
#[derive(Clone, PartialEq, Debug)]
pub struct ClauseParam {
    pub id: NodeId,
    pub span: Span,
    pub name: Option<Name>,
}

/// `resume(e)`。`handle` の節の中に直接書いたものだけを構文解析器が受け付ける（ADR 0155）。
#[derive(Clone, PartialEq, Debug)]
pub struct ResumeExpr {
    pub id: NodeId,
    pub span: Span,
    pub value: Box<Expr>,
}

// ---------------- パターン ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum Pattern {
    Wildcard(WildcardPat),
    Var(VarPat),
    Lit(LitPat),
    Unit(UnitPat),
    Ctor(CtorPat),
    Record(RecordPat),
    Range(RangePat),
    List(ListPat),
    Error(ErrorNode),
}

#[derive(Clone, PartialEq, Debug)]
pub struct WildcardPat {
    pub id: NodeId,
    pub span: Span,
}

/// 変数のパターン。束縛の宣言したノードになる。
#[derive(Clone, PartialEq, Debug)]
pub struct VarPat {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
}

/// リテラルのパターン。`negative` は整数リテラルの前置の `-`。
/// `Literal::Float` と `Literal::Decimal` は現れない（文法が許さない）。
#[derive(Clone, PartialEq, Debug)]
pub struct LitPat {
    pub id: NodeId,
    pub span: Span,
    pub negative: bool,
    pub lit: Literal,
}

#[derive(Clone, PartialEq, Debug)]
pub struct UnitPat {
    pub id: NodeId,
    pub span: Span,
}

/// 構成子のパターン。名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct CtorPat {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
    /// 引数がなくても括弧を書いたか（`Tree.Leaf()` の誤りを型検査器が報告するため）
    pub has_parens: bool,
    pub args: Vec<Pattern>,
}

/// レコードのパターン `R(f: p, ..)`。`id` はレコードの名前を使う箇所のノード。フィールドは一つ以上。
#[derive(Clone, PartialEq, Debug)]
pub struct RecordPat {
    pub id: NodeId,
    pub span: Span,
    pub path: Vec<Name>,
    /// 書いた順
    pub fields: Vec<FieldPat>,
    /// 最後に `..` を書いたか
    pub rest: bool,
}

/// レコードのパターンのフィールド `name: p`。`id` はフィールドの名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct FieldPat {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub pattern: Pattern,
}

/// 範囲のパターン `lo..hi`。
#[derive(Clone, PartialEq, Debug)]
pub struct RangePat {
    pub id: NodeId,
    pub span: Span,
    pub lo: RangeEnd,
    pub hi: RangeEnd,
}

/// 範囲の端（`[-] IntLit` か `CharLit`）。`lit` は `Literal::Int` か `Literal::Char`。
#[derive(Clone, PartialEq, Debug)]
pub struct RangeEnd {
    pub span: Span,
    pub negative: bool,
    pub lit: Literal,
}

/// リストのパターン `[p1, ..rest, pn]`。`..` は高々一つ（構文解析器が検査する）。
#[derive(Clone, PartialEq, Debug)]
pub struct ListPat {
    pub id: NodeId,
    pub span: Span,
    /// `..` の前の要素（`..` がなければすべての要素）
    pub before: Vec<Pattern>,
    pub rest: Option<ListRest>,
    /// `..` の後の要素
    pub after: Vec<Pattern>,
}

/// リストのパターンの `..` と、残りを束縛する変数（`..rest`）。
/// 変数を書いたときは `id` が束縛の宣言したノードになる。
#[derive(Clone, PartialEq, Debug)]
pub struct ListRest {
    pub id: NodeId,
    pub span: Span,
    pub name: Option<Name>,
}

// ---------------- 共通の操作 ----------------

impl Item {
    /// 宣言のノード番号。`Impl` は実装の宣言のノード番号。
    pub fn id(&self) -> NodeId {
        match self {
            Item::Fn(d) => d.id,
            Item::Const(d) => d.id,
            Item::Data(d) => d.id,
            Item::Alias(d) => d.id,
            Item::Record(d) => d.id,
            Item::Trait(d) => d.id,
            Item::Effect(d) => d.id,
            Item::Impl(d) => d.id,
            Item::Error(d) => d.id,
        }
    }
}

impl Expr {
    pub fn id(&self) -> NodeId {
        match self {
            Expr::Lit(e) => e.id,
            Expr::Interp(e) => e.id,
            Expr::Name(e) => e.id,
            Expr::Unit(e) => e.id,
            Expr::Paren(e) => e.id,
            Expr::List(e) => e.id,
            Expr::Call(e) => e.id,
            Expr::Record(e) => e.id,
            Expr::Binary(e) => e.id,
            Expr::Unary(e) => e.id,
            Expr::Pipe(e) => e.id,
            Expr::If(e) => e.id,
            Expr::Match(e) => e.id,
            Expr::Lambda(e) => e.id,
            Expr::Return(e) => e.id,
            Expr::Try(e) => e.id,
            Expr::Lazy(e) => e.id,
            Expr::With(e) => e.id,
            Expr::Handle(e) => e.id,
            Expr::Resume(e) => e.id,
            Expr::Error(e) => e.id,
        }
    }

    pub fn span(&self) -> Span {
        match self {
            Expr::Lit(e) => e.span,
            Expr::Interp(e) => e.span,
            Expr::Name(e) => e.span,
            Expr::Unit(e) => e.span,
            Expr::Paren(e) => e.span,
            Expr::List(e) => e.span,
            Expr::Call(e) => e.span,
            Expr::Record(e) => e.span,
            Expr::Binary(e) => e.span,
            Expr::Unary(e) => e.span,
            Expr::Pipe(e) => e.span,
            Expr::If(e) => e.span,
            Expr::Match(e) => e.span,
            Expr::Lambda(e) => e.span,
            Expr::Return(e) => e.span,
            Expr::Try(e) => e.span,
            Expr::Lazy(e) => e.span,
            Expr::With(e) => e.span,
            Expr::Handle(e) => e.span,
            Expr::Resume(e) => e.span,
            Expr::Error(e) => e.span,
        }
    }
}

impl Pattern {
    pub fn id(&self) -> NodeId {
        match self {
            Pattern::Wildcard(p) => p.id,
            Pattern::Var(p) => p.id,
            Pattern::Lit(p) => p.id,
            Pattern::Unit(p) => p.id,
            Pattern::Ctor(p) => p.id,
            Pattern::Record(p) => p.id,
            Pattern::Range(p) => p.id,
            Pattern::List(p) => p.id,
            Pattern::Error(p) => p.id,
        }
    }

    pub fn span(&self) -> Span {
        match self {
            Pattern::Wildcard(p) => p.span,
            Pattern::Var(p) => p.span,
            Pattern::Lit(p) => p.span,
            Pattern::Unit(p) => p.span,
            Pattern::Ctor(p) => p.span,
            Pattern::Record(p) => p.span,
            Pattern::Range(p) => p.span,
            Pattern::List(p) => p.span,
            Pattern::Error(p) => p.span,
        }
    }
}

impl TypeExpr {
    pub fn id(&self) -> NodeId {
        match self {
            TypeExpr::Named(t) => t.id,
            TypeExpr::Fn(t) => t.id,
            TypeExpr::Paren(t) => t.id,
            TypeExpr::Error(t) => t.id,
        }
    }

    pub fn span(&self) -> Span {
        match self {
            TypeExpr::Named(t) => t.span,
            TypeExpr::Fn(t) => t.span,
            TypeExpr::Paren(t) => t.span,
            TypeExpr::Error(t) => t.span,
        }
    }
}

impl Stmt {
    pub fn span(&self) -> Span {
        match self {
            Stmt::Bind(s) => s.span,
            Stmt::Expr(e) => e.span(),
            Stmt::Error(e) => e.span,
        }
    }
}
```

AST の各ノードの欄についての補足を次に示す。

- `BindStmt` の左辺は、最小実行版の文法の名前と `_` も含めて、すべて `Pattern` で表す（`bind x <- e` の左辺は `Pattern::Var`、`bind _ <- e` の左辺は `Pattern::Wildcard`）。どちらで書いたかを区別する必要はない。
- `MatchArm::body` と `HandleClause::body` は、01-02 の `ArmBody`（`Stmt { NL Stmt }`）を `Block` で表す。この `Block` の span は `->` の後の最初の文から最後の文までである。
- `LitExpr` の整数リテラルに単項の `-` を直接適用した式は、`UnaryExpr` の中の `LitExpr` のまま表す。符号を含めた値の範囲は型検査器が判定する（02-05「制約の生成」）。
- プレースホルダを含む呼び出しの展開と、パイプの展開は、型検査器と脱糖が行う。展開で作るラムダは AST に現れないので、型検査の表では `CallExpr` のノード番号で指す（10-05「型検査の出力」）。
- 構文解析器は、02-03「文脈の制限」の表の制限（`resume`・`return`・`try` の位置、import の順序、属性、`public`、制約の小文字の名前、操作の宣言、レコードのフィールドの数、ラムダの引数、プレースホルダ、ドキュメントコメント）を判定し、誤りの構文には誤りのノードを置かずに診断だけを出してよい。その場合も、誤りの診断があれば AST は名前解決に渡らない。

## 構文解析

構文解析器は、02-03「構文解析の方式」の再帰下降と Pratt 法で書く。誤りからの回復（02-03「誤りからの回復」）と入れ子の深さの上限（02-03「入れ子の深さ」）は最小実行版と同じ考え方で、初回リリース版の構文に広げる。

```rust sig=src/syntax/parser/mod.rs needs=10-02
use crate::base::{FileId, IdGen, SourceKind};
use crate::diag::Diagnostic;
use super::ast::Module;
use super::token::{Comment, Token};

/// 構文解析器が作る AST の深さの上限（02-03「入れ子の深さ」）。
pub const MAX_DEPTH: u32 = 1000;

/// 一つのファイルの構文解析の結果（02-03「構文解析の結果」）。
#[derive(Debug)]
pub struct ParseOutput {
    pub module: Module,
    /// 字句の切り出しの結果のコメントをそのまま入れる（ドキュメントコメントも含む）
    pub comments: Vec<Comment>,
    /// 構文解析の誤り。字句の切り出しの誤りは含めない（呼び出し側の読み込みの段が先に並べる）
    pub diagnostics: Vec<Diagnostic>,
}

/// NEWLINE を含む字句の列（`resolve_newlines` の出力）から、ファイル一つのモジュールの AST を作る。
/// `kind` が `SourceKind::Prelude`（標準ライブラリのソース。10-01「ソースの表」）のときだけ、`@builtin`・本体のない関数の宣言・制約 `ordered` を受け付ける。
/// ノード番号は `ids` から振る。`ids` は検査ごとに一つで、すべてのファイルで共有する（02-03「AST」）。
/// ドキュメントコメントは `comments` から宣言に結び付け、結び付かなかったものを構文エラーにする。
/// `text` は `lex` に渡したのと同じソースのバイト列（`Source::text()`）である。ドキュメントコメントと宣言の間の
/// 空行の判定と、修正案の置き換えの文字列（span の範囲のソースの写し）を作るために読む。
pub fn parse(file: FileId, kind: SourceKind, text: &[u8], tokens: Vec<Token>, comments: Vec<Comment>, ids: &mut IdGen) -> ParseOutput;
```

字句の切り出しから構文解析までを一つのファイルについて続けて行う関数は、読み込みの段（[モジュールと名前解決](10-04-modules-and-resolve.md)の `modules::load_program`）の中に書く。フォーマッタ（U4）は `lex` と `parse` を直接呼ぶ。

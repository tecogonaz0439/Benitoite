# 字句と構文木

本章は、字句、コメント、AST、字句解析と構文解析の関数のシグネチャを定める。設計書の対応する章は[字句解析器と構文解析器](../../2026-09-27-design-initial/02-impl/02-03-frontend.md)であり、規則そのものは[字句構造](../../2026-09-27-design-initial/01-spec/01-01-lexical.md)と[構文](../../2026-09-27-design-initial/01-spec/01-02-syntax.md)で定める。

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

字句の種類は、01-01 の字句の一覧をそのまま列挙型にする。予約語は字句の種類に入れず、誤りの字句（`Error`）にする（02-03「字句」）。

`LineBreak` は、字句の切り出しの工程だけが作る改行の印である。改行の判定の工程が、`LineBreak` を `Newline` にするか取り除く。構文解析器は `LineBreak` を受け取らない。

```rust file=src/syntax/token.rs
//! 字句（設計書 02-03「字句」）。

use crate::base::Span;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum TokenKind {
    LowerIdent,
    UpperIdent,
    IntLit,
    FloatLit,
    StringLit,
    CharLit,
    // キーワード（01-01「キーワード」）
    KwEffect,
    KwElse,
    KwFalse,
    KwFn,
    KwIf,
    KwLet,
    KwMatch,
    KwTrue,
    KwType,
    KwUses,
    // 演算子と区切り記号（01-01「演算子と区切り記号」）
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    EqEq,
    BangEq,
    Lt,
    Le,
    Gt,
    Ge,
    AndAnd,
    OrOr,
    Bang,
    PipeGt,
    Arrow,
    FatArrow,
    Eq,
    Colon,
    Comma,
    Dot,
    LParen,
    RParen,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    Underscore,
    /// 改行の印。字句の切り出しの工程だけが作る
    LineBreak,
    /// 改行の判定で残った改行字句（NEWLINE）
    Newline,
    /// 誤りの字句（予約語、誤りを含むリテラル）。構文解析器は、期待していた構文の誤りのノードにする
    Error,
    /// ファイルの終わり。span の長さは 0
    Eof,
}

/// リテラルの字句が持つ値（02-03「字句」の表）。
#[derive(Clone, PartialEq, Debug)]
pub enum TokenValue {
    None,
    /// 識別子の綴り
    Ident(String),
    /// 基数（2・8・10・16）と、接頭辞と `_` を除いた数字列
    Int {
        radix: u32,
        digits: String,
    },
    /// `_` を除いた字面
    Float(String),
    /// エスケープを解いた後の文字列
    Str(String),
    /// エスケープを解いた後のスカラー値
    Char(char),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Token {
    pub kind: TokenKind,
    pub span: Span,
    pub value: TokenValue,
}

/// コメント一つ。本文は `//` の後から行末まで（改行を含まない）。
#[derive(Clone, PartialEq, Debug)]
pub struct Comment {
    pub span: Span,
    pub text: String,
}
```

## 字句の切り出しと改行の判定

```rust sig=src/syntax/lexer.rs
use crate::base::FileId;
use crate::diag::Diagnostic;
use super::token::{Comment, Token};

/// 字句の切り出しの結果。
#[derive(Debug)]
pub struct LexOutput {
    /// 字句と改行の印（`LineBreak`）の列。最後は必ず `Eof`
    pub tokens: Vec<Token>,
    pub comments: Vec<Comment>,
    pub diagnostics: Vec<Diagnostic>,
}

/// ソースのバイト列（`Source::text()`）を先頭から読み、字句と改行の印の列を作る（02-03「処理の流れ」の 1）。
/// span のファイル ID には `file` を使う。誤りを報告した後も続ける（02-03「字句」の最後の段落）。
/// ソースの表に依存しない形にして、T04 を待たずに実装とテストができるようにしてある。
pub fn lex(file: FileId, text: &[u8]) -> LexOutput;
```

```rust sig=src/syntax/newline.rs
use super::token::Token;

/// 改行の印ごとに、NEWLINE を置くか空白として捨てるかを決める（01-01「改行による区切り」）。
/// 入力は `lex` の字句の列。出力は `LineBreak` を含まない。連続する NEWLINE は一つにまとめる。
pub fn resolve_newlines(tokens: Vec<Token>) -> Vec<Token>;
```

## AST

AST は、01-02 の文法の形をそのまま表す（02-03「AST」）。すべてのノードは `id`（ノード番号）と `span` を持つ。名前を束縛する箇所と名前を使う箇所は、それぞれ独立したノードにする。

名前の綴りと位置は `Name` で持つ。`Name` はノードではなく、ノード番号を持たない。束縛の表と参照の表の鍵は、`Name` を含むノードのノード番号である（[名前解決](10-04-resolve.md)）。

```rust file=src/syntax/ast.rs
//! 抽象構文木（設計書 02-03「AST」）。名前解決と型検査はこの木を変更しない（ADR 0022）。

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

// ---------------- プログラムと宣言 ----------------

#[derive(Clone, PartialEq, Debug)]
pub struct Program {
    pub id: NodeId,
    pub span: Span,
    pub file: FileId,
    pub items: Vec<Item>,
}

#[derive(Clone, PartialEq, Debug)]
pub enum Item {
    Fn(Box<FnDecl>),
    Type(TypeDecl),
    Error(ErrorNode),
}

/// 関数の宣言。束縛の表では、トップレベルの関数と prelude のソースの関数の宣言したノードになる。
#[derive(Clone, PartialEq, Debug)]
pub struct FnDecl {
    pub id: NodeId,
    pub span: Span,
    /// 名前を修飾したモジュールの名前（prelude のソースでだけ `Some`。02-03「prelude のソースの構文」）
    pub module: Option<Name>,
    pub name: Name,
    pub type_params: Vec<TypeParam>,
    pub params: Vec<Param>,
    pub ret: TypeExpr,
    pub uses: Option<UsesList>,
    pub body: Block,
}

/// 型パラメータの宣言。`effect` を付けたものはエフェクト変数の宣言である。
#[derive(Clone, PartialEq, Debug)]
pub struct TypeParam {
    pub id: NodeId,
    pub span: Span,
    pub is_effect: bool,
    pub name: Name,
}

/// 関数の引数とラムダの引数。関数の引数は `ty` が必ず `Some`（文法が要求する）。
#[derive(Clone, PartialEq, Debug)]
pub struct Param {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub ty: Option<TypeExpr>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct TypeDecl {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub type_params: Vec<TypeParam>,
    pub variants: Vec<Variant>,
}

/// データ構成子の宣言。
#[derive(Clone, PartialEq, Debug)]
pub struct Variant {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub fields: Vec<TypeExpr>,
}

// ---------------- 型 ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum TypeExpr {
    Named(NamedType),
    Fn(FnType),
    Paren(ParenType),
    Error(ErrorNode),
}

/// 名前の型（型引数を含む）。名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct NamedType {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
    pub args: Vec<TypeExpr>,
}

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

/// `uses` の並びの中のエフェクトの名前。名前を使う箇所のノード。
#[derive(Clone, PartialEq, Debug)]
pub struct EffectRef {
    pub id: NodeId,
    pub span: Span,
    pub name: Name,
}

// ---------------- ブロックと文 ----------------

#[derive(Clone, PartialEq, Debug)]
pub struct Block {
    pub id: NodeId,
    pub span: Span,
    pub stmts: Vec<Stmt>,
}

#[derive(Clone, PartialEq, Debug)]
pub enum Stmt {
    Let(LetStmt),
    Expr(Expr),
    Error(ErrorNode),
}

/// `let` 文。`let x = e` の束縛の宣言したノードは、この `let` 文である（02-04「束縛」）。
#[derive(Clone, PartialEq, Debug)]
pub struct LetStmt {
    pub id: NodeId,
    pub span: Span,
    pub name: LetName,
    pub ty: Option<TypeExpr>,
    pub value: Expr,
}

#[derive(Clone, PartialEq, Debug)]
pub enum LetName {
    Var(Name),
    /// `let _ = e`。span は `_` の位置
    Wildcard(Span),
}

// ---------------- 式 ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum Expr {
    Lit(LitExpr),
    Name(NameExpr),
    Unit(UnitExpr),
    Paren(ParenExpr),
    List(ListExpr),
    Call(CallExpr),
    Binary(BinaryExpr),
    Unary(UnaryExpr),
    Pipe(PipeExpr),
    Block(Block),
    If(IfExpr),
    Match(MatchExpr),
    Lambda(LambdaExpr),
    Error(ErrorNode),
}

#[derive(Clone, PartialEq, Debug)]
pub enum Literal {
    /// 基数と、接頭辞と `_` を除いた数字列。値の範囲は型検査器が判定する（02-03「字句」）
    Int {
        radix: u32,
        digits: String,
    },
    /// `_` を除いた字面
    Float(String),
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

/// 式の中の名前（修飾を含む）。名前を使う箇所のノード。`Some` などの修飾しない構成子もこれで表す。
#[derive(Clone, PartialEq, Debug)]
pub struct NameExpr {
    pub id: NodeId,
    pub span: Span,
    /// `A.b` の `A`
    pub qualifier: Option<Name>,
    pub name: Name,
}

/// `()` の式。
#[derive(Clone, PartialEq, Debug)]
pub struct UnitExpr {
    pub id: NodeId,
    pub span: Span,
}

/// 括弧で囲んだ式 `(e)`。
#[derive(Clone, PartialEq, Debug)]
pub struct ParenExpr {
    pub id: NodeId,
    pub span: Span,
    pub inner: Box<Expr>,
}

#[derive(Clone, PartialEq, Debug)]
pub struct ListExpr {
    pub id: NodeId,
    pub span: Span,
    pub elems: Vec<Expr>,
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

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    Rem,
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    And,
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
    Neg,
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

#[derive(Clone, PartialEq, Debug)]
pub struct MatchExpr {
    pub id: NodeId,
    pub span: Span,
    pub scrutinee: Box<Expr>,
    pub arms: Vec<MatchArm>,
}

/// `match` の分岐。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchArm {
    pub id: NodeId,
    pub span: Span,
    pub pattern: Pattern,
    pub body: Expr,
}

#[derive(Clone, PartialEq, Debug)]
pub struct LambdaExpr {
    pub id: NodeId,
    pub span: Span,
    pub params: Vec<Param>,
    pub ret: Option<TypeExpr>,
    pub uses: Option<UsesList>,
    pub body: Block,
}

// ---------------- パターン ----------------

#[derive(Clone, PartialEq, Debug)]
pub enum Pattern {
    Wildcard(WildcardPat),
    Var(VarPat),
    Lit(LitPat),
    Unit(UnitPat),
    Ctor(CtorPat),
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

/// リテラルのパターン。`negative` は整数リテラルの前置の `-`。`Literal::Float` は現れない
/// （文法が浮動小数リテラルを許さない）。
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
    /// `Shape.Circle(r)` の `Shape`
    pub qualifier: Option<Name>,
    pub name: Name,
    /// 引数がなくても括弧を書いたか（`Tree.Leaf()` の誤りを型検査器が報告するため）
    pub has_parens: bool,
    pub args: Vec<Pattern>,
}

// ---------------- 共通の操作 ----------------

impl Expr {
    pub fn id(&self) -> NodeId {
        match self {
            Expr::Lit(e) => e.id,
            Expr::Name(e) => e.id,
            Expr::Unit(e) => e.id,
            Expr::Paren(e) => e.id,
            Expr::List(e) => e.id,
            Expr::Call(e) => e.id,
            Expr::Binary(e) => e.id,
            Expr::Unary(e) => e.id,
            Expr::Pipe(e) => e.id,
            Expr::Block(e) => e.id,
            Expr::If(e) => e.id,
            Expr::Match(e) => e.id,
            Expr::Lambda(e) => e.id,
            Expr::Error(e) => e.id,
        }
    }

    pub fn span(&self) -> Span {
        match self {
            Expr::Lit(e) => e.span,
            Expr::Name(e) => e.span,
            Expr::Unit(e) => e.span,
            Expr::Paren(e) => e.span,
            Expr::List(e) => e.span,
            Expr::Call(e) => e.span,
            Expr::Binary(e) => e.span,
            Expr::Unary(e) => e.span,
            Expr::Pipe(e) => e.span,
            Expr::Block(e) => e.span,
            Expr::If(e) => e.span,
            Expr::Match(e) => e.span,
            Expr::Lambda(e) => e.span,
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
            Stmt::Let(s) => s.span,
            Stmt::Expr(e) => e.span(),
            Stmt::Error(e) => e.span,
        }
    }
}
```

## 構文解析

```rust sig=src/syntax/parser/mod.rs
use crate::base::{FileId, IdGen, SourceKind};
use crate::diag::Diagnostic;
use super::ast::Program;
use super::token::{Comment, Token};

/// 構文解析器が作る AST の深さの上限（02-03「入れ子の深さ」）。
pub const MAX_DEPTH: u32 = 1000;

/// 構文解析の結果（02-03「構文解析の結果」）。
#[derive(Debug)]
pub struct ParseOutput {
    pub program: Program,
    pub comments: Vec<Comment>,
    /// 字句の切り出しの誤りと構文解析の誤り。呼び出し側（10-09 の `parse_source`）が字句の誤りを先に並べる
    pub diagnostics: Vec<Diagnostic>,
}

/// NEWLINE を含む字句の列（`resolve_newlines` の出力）から AST を作る。
/// `kind` が `SourceKind::Prelude` のときだけ、修飾した関数の宣言を受け付ける。
/// ノード番号は `ids` から振る。`comments` は字句の切り出しの結果をそのまま受け取り、結果に入れる。
pub fn parse(file: FileId, kind: SourceKind, tokens: Vec<Token>, comments: Vec<Comment>, ids: &mut IdGen) -> ParseOutput;
```

構文解析器の内部のファイルの分け方（`parser/decl.rs`・`parser/expr.rs` など）は、作業 T11・T12 の文書で定める。

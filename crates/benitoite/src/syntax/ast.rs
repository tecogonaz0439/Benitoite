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

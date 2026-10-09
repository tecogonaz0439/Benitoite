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
    Builtin { span: Span, kind: BuiltinConstraint },
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
    Int {
        radix: u32,
        digits: String,
    },
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

//! コア IR（設計書 02-06「コア IR」、01-12「構文」「初回リリース版の拡張」）。
//! 値の型 `Val<C>` はラムダの本体の計算の型 `C` を型引数にとり、コア IR と下位 IR で共有する。
//! 辞書（`DictVal`）と継続（`ContVar`）は `Val` と分けて持つ（実装プラン 10-06「型、辞書、継続」）。

use crate::base::{BindingId, BindingMap, Decimal, NodeId, Span};
use crate::builtins::BuiltinId;
use crate::builtins::iface::Capability;
use crate::types::builtin::BuiltinTypeId;
use crate::types::{
    AdtTable, ClassConstraint, ConstValue, EffectName, EffectSet, Scheme, TraitDef, Ty, TypeArg,
    TypeArgs,
};

/// 定義の中の変数の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct VarId(pub u32);

/// ラムダ、`lazy` の本体、`handle` の本体と節の番号。プログラム全体で重ならない。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BodyId(pub u32);

/// 変数。`name` はソースの名前（脱糖で作った変数では `None`）。診断と読みやすさのためだけに持つ。
#[derive(Clone, PartialEq, Debug)]
pub struct Var {
    pub id: VarId,
    pub name: Option<String>,
    pub ty: Ty,
}

/// 定数（01-12 の `c`。`IOError` などの中身を見せない値は実行中にだけ現れるので含めない）。
#[derive(Clone, Debug)]
pub enum Const {
    Int(i64),
    Float(f64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    Byte(u8),
    Decimal(Decimal),
}

impl PartialEq for Const {
    /// 表現の等しさ。`Float` はビットの並び、`Decimal` は仮数と小数の桁数で比べる（木の形を比べるテストのため）。
    fn eq(&self, other: &Const) -> bool {
        match (self, other) {
            (Const::Int(a), Const::Int(b)) => a == b,
            (Const::Float(a), Const::Float(b)) => a.to_bits() == b.to_bits(),
            (Const::Str(a), Const::Str(b)) => a == b,
            (Const::Char(a), Const::Char(b)) => a == b,
            (Const::Bool(a), Const::Bool(b)) => a == b,
            (Const::Unit, Const::Unit) => true,
            (Const::Byte(a), Const::Byte(b)) => a == b,
            (Const::Decimal(a), Const::Decimal(b)) => a.same_repr(*b),
            _ => false,
        }
    }
}

/// 演算子の組み込みの関数の種類（01-12 の `⊕_T`・`neg_T`）。`=` と `<>` は `Intrinsic::Eq`・`Ne` で表す。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum OperatorKind {
    Add,
    Sub,
    Mul,
    /// `/`
    Div,
    /// `div`
    IntDiv,
    /// `mod`
    Mod,
    Lt,
    Le,
    Gt,
    Ge,
    /// 単項の `-`
    Neg,
}

/// コード生成が `PRIM`・`IO` でなく専用の命令に移す組み込みの関数（02-06「下位 IR からコード生成へ渡すもの」、
/// 02-07「演算子の移し方」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Intrinsic {
    /// `⊕_T`・`neg_T`。`operand` はオペランドの型（10-05 の組み込みの型の表の番号）
    Operator {
        op: OperatorKind,
        operand: BuiltinTypeId,
    },
    /// `eq[T]`。T は `ValKind::Builtin::targs` の 0 番
    Eq,
    /// `ne[T]`
    Ne,
    /// `Lazy.force`
    Force,
    /// `Reference.update`
    Update,
}

/// 組み込みの関数の呼び出しの種類（02-06「下位 IR からコード生成へ渡すもの」の「呼び出しの種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinInfo {
    /// 外部に作用する操作（`Io`）、`State` を型に持つ関数とタスクを起動する関数（`State`）、純粋な関数（`Pure`）
    pub class: Capability,
    /// `class` が `Io` のとき、この組み込みの関数に当たる組み込みのエフェクトの操作の束縛。
    /// ハンドラの節を探す鍵になる（02-09「操作の振り分け」）
    pub op: Option<BindingId>,
    /// 項目の宣言の束縛。`Declared` の項目（10-12）では `@builtin` を付けた関数の束縛（`BindingKind::BuiltinFn`）、
    /// `EffectOp` の項目では操作の束縛（`op` と同じ）。ソースに宣言のない項目（演算子、`eq`・`ne`、文字列補間の内部の項目）では `None`。
    /// 検査器が宣言の型（`Program::schemes`）を引く鍵になる
    pub decl: Option<BindingId>,
    /// 専用の命令に移すもの
    pub intrinsic: Option<Intrinsic>,
}

/// 値。
#[derive(Clone, PartialEq, Debug)]
pub struct Val<C> {
    pub kind: ValKind<C>,
    pub ty: Ty,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum ValKind<C> {
    Var(VarId),
    Const(Const),
    /// トップレベルの関数とフィールドを取り出す関数 `f[T̄; Ē]`。定義は束縛の番号で指す
    TopFn {
        def: BindingId,
        targs: TypeArgs,
    },
    /// 組み込みの関数 `b[T̄; Ē]`。演算子（`⊕_T`・`eq[T]`）と組み込みのエフェクトの操作もこれで表す
    Builtin {
        id: BuiltinId,
        targs: TypeArgs,
        info: BuiltinInfo,
    },
    /// 利用者が宣言したエフェクトの操作 `op[T̄]`。操作の束縛の番号で指す
    Op {
        op: BindingId,
        targs: TypeArgs,
    },
    /// 関数 `λ(x̄:Ā). M`
    Lambda(Box<Lambda<C>>),
    /// 構成子を適用した値 `C[T̄](V̄)`（レコードを含む）。`adt` は型の宣言の束縛の番号
    Ctor {
        adt: BindingId,
        tag: u32,
        tys: Vec<Ty>,
        args: Vec<Val<C>>,
    },
    /// リスト `[V̄]`
    List(Vec<Val<C>>),
    /// トップレベルの定数の参照 `k`。定数の束縛の番号で指す
    ConstRef(BindingId),
}

#[derive(Clone, PartialEq, Debug)]
pub struct Lambda<C> {
    pub id: BodyId,
    pub params: Vec<Var>,
    pub body: C,
    /// ラムダを書いた位置（プレースホルダの展開では、プレースホルダを含む呼び出しの式の位置）
    pub span: Span,
}

/// 辞書（01-12 の `I[T̄](V̄)`・`V↑S`・辞書の引数）。`class` と `arg` が辞書の型 `Dict[class, arg]` である。
#[derive(Clone, PartialEq, Debug)]
pub struct DictVal {
    pub kind: DictKind,
    pub class: BindingId,
    pub arg: TypeArg,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum DictKind {
    /// 実装の辞書 `I[T̄](V̄)`。`impl_decl` は実装の宣言のノード番号、`tys` は実装の型パラメータに与える型、
    /// `args` は実装の制約の辞書（`ImplDef::dict_params` の順）
    Impl {
        impl_decl: NodeId,
        tys: Vec<TypeArg>,
        args: Vec<DictVal>,
    },
    /// 上位の型クラスの辞書 `V↑S`。`index` は `V` の型クラスの上位の型クラスの並び（`TraitDef::supers`）の位置
    Super { of: Box<DictVal>, index: u32 },
    /// 定義の辞書の引数（`Def::dict_params` の変数）
    Param(VarId),
    /// 実装の制約の辞書 `d̄` の `index` 番目。実装のメソッドの本体と `ImplDef::supers` の中だけに現れる
    ImplParam(u32),
}

/// メソッドの呼び出し `V.m[S̄; Ē](Ū, W̄)`（01-12 の C-Meth）。
#[derive(Clone, PartialEq, Debug)]
pub struct MethodCall<C> {
    /// メソッドを引く辞書 V
    pub dict: DictVal,
    /// 型クラスのメソッドの並び（`TraitDef::methods`）の位置
    pub method: u32,
    /// メソッド自身の型パラメータとエフェクト変数の置き換え（`S̄; Ē`）
    pub targs: TypeArgs,
    /// メソッド自身の制約の辞書 Ū
    pub dicts: Vec<DictVal>,
    pub args: Vec<Val<C>>,
}

/// 継続を束縛する変数（`handle` の節の k）。値としては使えず、`resume` だけが番号で指す。
#[derive(Clone, PartialEq, Debug)]
pub struct ContVar {
    pub id: VarId,
    /// 継続の型 `Cont(B → T ! ε)` の B（節の操作の戻り値の型）
    pub arg: Ty,
}

/// `handle` の節 `op(x̄) k ⇒ N`。
#[derive(Clone, PartialEq, Debug)]
pub struct Clause<C> {
    pub id: BodyId,
    /// 節の AST のノード番号。節の中の型に現れる `Ty::Rigid { clause, index }` の `clause` と同じ番号であり、
    /// 検査器はこの番号で、`Ty::Rigid` がこの節の操作の型パラメータかを判定する（10-05「型の表現」）
    pub node: NodeId,
    /// 節の操作の束縛の番号（利用者の操作と組み込みのエフェクトの操作のどちらも `Op` の束縛）
    pub op: BindingId,
    pub params: Vec<Var>,
    pub cont: ContVar,
    /// 末尾で再開する節か（型検査の「ハンドラの節」の表から写す。設計書 02-05「書く位置の検査」）
    pub tail_resumptive: bool,
    pub body: C,
    /// 節を書いた位置（原型の名前 `<case 操作の名前>` の位置）
    pub span: Span,
}

/// `handle M with H`。
#[derive(Clone, PartialEq, Debug)]
pub struct Handle<C> {
    /// 本体の番号
    pub id: BodyId,
    pub body: C,
    pub clauses: Vec<Clause<C>>,
    /// handled(H)（型検査の「ハンドラの節」の表から写す）
    pub handled: EffectSet,
}

/// 計算。
#[derive(Clone, PartialEq, Debug)]
pub struct Comp {
    pub kind: CompKind,
    pub ty: Ty,
    pub eff: EffectSet,
    pub origin: Span,
}

#[derive(Clone, PartialEq, Debug)]
pub enum CompKind {
    Return(Val<Comp>),
    Let {
        var: Var,
        bound: Box<Comp>,
        body: Box<Comp>,
    },
    /// 適用 `V(W̄)`。制約を持つ関数の呼び出しでは、辞書を値の引数の前の `dicts` に置く
    App {
        func: Val<Comp>,
        dicts: Vec<DictVal>,
        args: Vec<Val<Comp>>,
    },
    Method(Box<MethodCall<Comp>>),
    If {
        cond: Val<Comp>,
        then_branch: Box<Comp>,
        else_branch: Box<Comp>,
    },
    /// `match V { 行の並び; 分岐の並び }`（02-06「パターンの拡張」）
    Match {
        scrutinee: Val<Comp>,
        rows: Vec<MatchRow>,
        arms: Vec<MatchArm>,
    },
    /// `escape V`（途中の `return` と `try`）
    Escape(Val<Comp>),
    /// `use V in M`（`with`）
    Use {
        resource: Val<Comp>,
        body: Box<Comp>,
    },
    /// `lazy M`
    Lazy {
        id: BodyId,
        body: Box<Comp>,
    },
    Handle(Box<Handle<Comp>>),
    /// `resume κ V`。`cont` は節の `ContVar::id`
    Resume {
        cont: VarId,
        value: Val<Comp>,
    },
}

/// `match` の行。表層の分岐の選択肢ごとに一つ、元の順に並べる。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchRow {
    pub pattern: CorePat,
    /// 分岐の番号（`arms` の位置）
    pub arm: u32,
}

/// `match` の分岐。本体は分岐ごとに一つだけ持つ。
#[derive(Clone, PartialEq, Debug)]
pub struct MatchArm {
    /// 表層の分岐のパターンが束縛する変数（パターンの中で左から現れる順）。同じ分岐のどの行も同じ変数を束縛する
    pub vars: Vec<Var>,
    /// ガード。型は `Boolean`、エフェクトは空集合
    pub guard: Option<Comp>,
    pub body: Comp,
}

/// パターン（01-12 の `p` と初回リリース版の拡張）。構成子の型名の修飾は除き、`-n` は負の定数にし、
/// レコードのパターンは宣言の順の構成子のパターン（書かないフィールドは `Wild`）にしてある。
#[derive(Clone, PartialEq, Debug)]
pub enum CorePat {
    Wild,
    /// 分岐の変数（`MatchArm::vars` の変数）を束縛する
    Var(VarId),
    Const(Const),
    Ctor {
        adt: BindingId,
        tag: u32,
        args: Vec<CorePat>,
    },
    /// 範囲（両端を含む）。`Integer` か `Character` の定数
    Range {
        lo: Const,
        hi: Const,
    },
    /// リストのパターン。`rest` は `..` を書いたか（書いたなら、その後の変数）
    List {
        before: Vec<CorePat>,
        rest: Option<ListRest>,
        after: Vec<CorePat>,
    },
}

/// リストのパターンの `..` の部分。
#[derive(Clone, PartialEq, Debug)]
pub struct ListRest {
    /// `..` の後に書いた変数（分岐の変数）
    pub var: Option<VarId>,
}

/// 定義の由来。原型の名前と由来の種類（10-07 の `ProtoOrigin`）を決めるのに使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DefOrigin {
    /// 利用者のモジュールの定義
    User,
    /// 標準ライブラリのソースの公開の関数と実装のメソッド
    StdlibPublic,
    /// 標準ライブラリのソースの `public` を付けない関数（呼び出しの履歴に示さない）
    StdlibHelper,
}

/// 定義の種類。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DefKind {
    /// トップレベルの関数
    Fn,
    /// レコードのフィールドを取り出す関数（01-12「レコード」。脱糖が作る）
    FieldGetter { record: BindingId, index: u32 },
    /// 実装のメソッド。`index` は型クラスのメソッドの並びの位置
    Method { impl_decl: NodeId, index: u32 },
}

/// 定義の辞書の引数一つ。
#[derive(Clone, PartialEq, Debug)]
pub struct DictParam {
    pub var: VarId,
    pub constraint: ClassConstraint,
}

/// 関数の定義 `fn f[ᾱ; ρ̄](d̄, x̄:Ā) : B ! ε = M`。
#[derive(Clone, PartialEq, Debug)]
pub struct Def<C> {
    /// 関数・フィールド・実装の中の関数の束縛の番号
    pub binding: BindingId,
    /// 表示のための名前（02-07「原型の名前と由来の種類」の名前。`main`、`Report.format`、`List.map`、`Show[Person].show`）
    pub name: String,
    pub origin: DefOrigin,
    pub kind: DefKind,
    pub type_params: Vec<String>,
    pub effect_params: Vec<String>,
    /// 型クラスの制約の辞書の引数（制約の番号の順）。実装のメソッドでは、メソッド自身の制約だけを持つ
    pub dict_params: Vec<DictParam>,
    pub params: Vec<Var>,
    pub ret: Ty,
    pub eff: EffectSet,
    pub body: C,
    /// 関数の宣言の位置
    pub span: Span,
    pub var_count: u32,
}

/// 実装の定義 `impl I[β̄](d̄ : …) : Dict[Cl, τ] = { S̄ = Ū; m̄ = D̄ }`。
#[derive(Clone, PartialEq, Debug)]
pub struct ImplDef<C> {
    pub impl_decl: NodeId,
    /// 型クラスの束縛の番号
    pub class: BindingId,
    /// 表示のための名前（`Show[Person]`）
    pub name: String,
    pub origin: DefOrigin,
    pub type_params: Vec<String>,
    /// 実装の対象 τ（`types::ImplDef::target` の写し。値の型なら `TypeArg::Ty`、型構成子なら `TypeArg::Head`）。
    /// 検査器が V-Dict・D-Impl の `Dict[Cl, τ]` を作るのに使う（01-12「型クラス」）
    pub target: TypeArg,
    /// 実装の型パラメータの制約（辞書 d̄ の順）
    pub dict_params: Vec<ClassConstraint>,
    /// 上位の型クラスの辞書 Ū（`TraitDef::supers` の順）
    pub supers: Vec<DictVal>,
    /// メソッドの定義（`TraitDef::methods` の順）
    pub methods: Vec<Def<C>>,
    pub span: Span,
}

/// 定数の定義 `const k : A = M`（02-06「コア IR」の定数の段落）。
#[derive(Clone, Debug)]
pub struct ConstDef<C> {
    pub binding: BindingId,
    pub name: String,
    pub ty: Ty,
    /// 定数式の計算 ⟦e⟧。参照インタプリタが実行する
    pub body: C,
    /// 型検査の定数の評価器が求めた値。コード生成が定数の記述にする
    pub value: ConstValue,
    pub span: Span,
    pub var_count: u32,
}

/// エフェクトの操作の表の項目（10-07 の操作の表の元）。
#[derive(Clone, PartialEq, Debug)]
pub struct OpDef {
    pub binding: BindingId,
    pub effect: EffectName,
    /// エフェクトで修飾した名前（`Log.write`、`Console.writeLine`）
    pub name: String,
    pub arity: u32,
    /// 組み込みのエフェクトの操作なら、対応する組み込みの関数（名前解決の `builtin_ops`）
    pub builtin: Option<BuiltinId>,
}

/// プログラム（02-06「コア IR」のプログラムの段落）。すべてのモジュール（標準ライブラリのソースを含む）の
/// 定義を一つにまとめる。各並びは、モジュールの ID の順、モジュールの中では宣言の順に並べる。
#[derive(Clone, Debug)]
pub struct Program<C> {
    /// トップレベルの関数とフィールドを取り出す関数
    pub defs: Vec<Def<C>>,
    pub impls: Vec<ImplDef<C>>,
    pub consts: Vec<ConstDef<C>>,
    pub ops: Vec<OpDef>,
    pub adts: AdtTable,
    pub traits: BindingMap<TraitDef>,
    /// 宣言の型（型検査の `decl_types` の写し）。検査器が関数・操作・メソッドの型を引く
    pub schemes: BindingMap<Scheme>,
    /// `main` の束縛。`main` を検査しない経路（10-05 の `typecheck` の `require_main` が偽。`test` の経路と、
    /// `main` を持たないプログラムを脱糖する単体テスト）では `None`（型検査の出力の `main` を写す）
    pub main: Option<BindingId>,
    /// `main` の戻り値の型が `Result[Unit, String]` か。`main` が `None` なら偽
    pub main_returns_result: bool,
    /// 振った `BodyId` の数
    pub body_count: u32,
}

pub type CoreVal = Val<Comp>;
pub type CoreDef = Def<Comp>;
pub type CoreProgram = Program<Comp>;

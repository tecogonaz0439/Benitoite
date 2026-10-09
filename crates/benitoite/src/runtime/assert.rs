//! テストの実行器が処理する `Assert.Check` の操作（設計書 02-11「テストの実行」、06-04「期待の確認」「結果の報告」、
//! 実装プラン README「U3・U4 で決めたこと」の 12）。どの言語のハンドラも処理しなかった `Assert` の操作を、
//! VM は送り出しの列に置かずに `evaluate` へ渡す。

use std::collections::HashMap;

use crate::base::Span;
use crate::builtins::BuiltinId;
use crate::types::{AdtTable, Ty};
use crate::vm::{FrameRecord, InstrRef, SpawnRecord};

/// `Assert.Check` の四つの操作（06-04「期待の確認」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum AssertOp {
    Equal,
    NotEqual,
    IsTrue,
    Fail,
}

impl AssertOp {
    /// 報告に書く操作の名前。
    pub fn name(self) -> &'static str {
        match self {
            AssertOp::Equal => "Assert.equal",
            AssertOp::NotEqual => "Assert.notEqual",
            AssertOp::IsTrue => "Assert.isTrue",
            AssertOp::Fail => "Assert.fail",
        }
    }
}

/// テストの実行器が VM に渡す表。ファイル一つの検査の結果から一度作り、そのファイルのテストで共有する。
#[derive(Debug)]
pub struct AssertTable {
    /// 組み込みの関数の表の項目と操作の対応（`Benitoite.Assert.equal` などを 10-11 の `lookup_builtin` で引いたもの）
    pub ops: Vec<(BuiltinId, AssertOp)>,
    /// `Assert.equal`・`Assert.notEqual` を呼ぶ式の span → 比べる値の型（本章「確認と値の書き出し」）
    pub value_types: HashMap<Span, Ty>,
    /// 型の中の代数的データ型とレコードを引く表（10-05 の `TypeckOutput::adts` の写し）
    pub adts: AdtTable,
}

/// 確認の結果。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum AssertVerdict {
    Passed,
    Failed {
        message: String,
        left: Option<String>,
        right: Option<String>,
    },
}

/// 確認の失敗の記録。VM が失敗を見つけた時点で、枠を一つも降ろさないうちに作る（10-09 の `StopInfo` と同じ時点）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CheckFailure {
    pub op: AssertOp,
    /// `AssertVerdict::Failed` の `message`
    pub message: String,
    pub left: Option<String>,
    pub right: Option<String>,
    /// 操作を呼んだ命令
    pub at: InstrRef,
    /// 失敗したタスクの呼び出しの枠（内側から外側の順）
    pub frames: Vec<FrameRecord>,
    pub spawns: Vec<SpawnRecord>,
}

use crate::pipeline::CheckedProgram;
use crate::runtime::Stop;
use crate::runtime::heap::{Value, ValueCtx};

impl AssertTable {
    /// 検査を通ったプログラムから表を作る（本章「確認と値の書き出し」）。`Assert` の操作が組み込みの関数の表か
    /// 標準ライブラリの名前の索引にないときは、処理系の不具合として説明の文字列を返す。
    pub fn build(checked: &CheckedProgram) -> Result<AssertTable, String> {
        let mut ops = Vec::with_capacity(OPERATIONS.len());
        for (name, op) in OPERATIONS {
            let id = crate::builtins::lookup_builtin(name)
                .ok_or_else(|| format!("builtin table has no {name}"))?;
            ops.push((id, op));
        }
        let binding = |name: &str| {
            checked
                .resolved
                .stdlib_names
                .get(name)
                .copied()
                .ok_or_else(|| format!("stdlib name index has no {name}"))
        };
        let mut collector = Collector {
            checked,
            targets: [binding(EQUAL_NAME)?, binding(NOT_EQUAL_NAME)?],
            value_types: HashMap::new(),
        };
        // 利用者のモジュールだけを辿る。標準ライブラリの中の呼び出しは、利用者の確認の位置にならない。
        for module in checked
            .modules
            .iter()
            .filter(|m| matches!(m.kind, ModuleKind::Entry | ModuleKind::User))
        {
            let ast = usize::try_from(module.id.0)
                .ok()
                .and_then(|index| checked.asts.get(index))
                .ok_or_else(|| format!("module {} has no AST", module.id.0))?;
            collector.module(ast);
        }
        Ok(AssertTable {
            ops,
            value_types: collector.value_types,
            adts: checked.types.adts.clone(),
        })
    }

    /// 組み込みの関数の項目が `Assert` の操作なら、その操作を返す。
    pub fn op_of(&self, id: BuiltinId) -> Option<AssertOp> {
        self.ops
            .iter()
            .find_map(|&(candidate, op)| (candidate == id).then_some(op))
    }
}

/// 確認を行う（本章「確認と値の書き出し」）。`args` は操作の引数、`site` は操作を呼んだ命令の由来位置。
pub fn evaluate<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    op: AssertOp,
    args: &[Value<'e>],
    site: Option<Span>,
) -> Result<AssertVerdict, Stop> {
    match (op, args) {
        (AssertOp::Equal | AssertOp::NotEqual, &[actual, expected]) => {
            let equal = crate::runtime::equal::values_equal(ctx, actual, expected)?;
            if equal == (op == AssertOp::Equal) {
                return Ok(AssertVerdict::Passed);
            }
            // 型は呼び出しの式の span で引く（10-18「確認と値の書き出し」、02-02「合成ノードの由来位置」）。
            let ty = site.and_then(|span| table.value_types.get(&span));
            Ok(AssertVerdict::Failed {
                message: format!("{}{}", text::ASSERTION_FAILED, op.name()),
                left: Some(render_value(ctx, table, actual, ty)?),
                right: Some(render_value(ctx, table, expected, ty)?),
            })
        }
        (AssertOp::IsTrue, &[condition, message]) => {
            let holds = condition
                .as_bool()
                .ok_or_else(|| internal("Assert.isTrue condition is not Boolean"))?;
            if holds {
                Ok(AssertVerdict::Passed)
            } else {
                Ok(failed_with(ctx, message)?)
            }
        }
        (AssertOp::Fail, &[message]) => Ok(failed_with(ctx, message)?),
        _ => Err(internal("Assert operation has wrong number of arguments")),
    }
}

/// 値を 03-06 の `Show.show` の形に揃えて書き出す。`ty` が `None` か型パラメータを含むときは、値の形だけから書く。
pub fn render_value<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: Option<&Ty>,
) -> Result<String, Stop> {
    // 型パラメータを含む型は、どの位置の型が分かるかを決められないので、値全体を形だけから書く（10-18）。
    let ty = ty
        .filter(|ty| !has_params(ty))
        .map(|ty| Rc::new(ty.clone()));
    let mut out = String::new();
    // 実行時の値を辿るので、Rust の再帰でなく明示の積み重ねで書く（実装プラン 00-02「再帰の深さ」）。
    let mut stack = vec![Work::Value(value, ty)];
    while let Some(work) = stack.pop() {
        match work {
            Work::Text(text) => out.push_str(text),
            Work::Owned(text) => out.push_str(&text),
            Work::Value(value, ty) => {
                let mut forward = Vec::new();
                render_one(ctx, table, value, ty, &mut forward)?;
                stack.extend(forward.into_iter().rev());
            }
        }
    }
    Ok(out)
}

/// 報告の表記（ADR 0033。`Show.show` の形の記号と、型が分からない値の書き方）。
mod text {
    /// `Failed` の `message` の前置き。操作の名前を続ける（10-18「確認と値の書き出し」）
    pub const ASSERTION_FAILED: &str = "assertion failed: ";
    pub const TRUE: &str = "true";
    pub const FALSE: &str = "false";
    pub const UNIT: &str = "()";
    pub const LIST_OPEN: &str = "[";
    pub const LIST_CLOSE: &str = "]";
    pub const MAP_OPEN: &str = "Map.fromList([";
    pub const SET_OPEN: &str = "Set.fromList([";
    pub const BYTES_OPEN: &str = "Bytes.fromList([";
    pub const FROM_LIST_CLOSE: &str = "])";
    pub const PAIR_OPEN: &str = "Pair(";
    pub const ARGS_OPEN: &str = "(";
    pub const ARGS_CLOSE: &str = ")";
    pub const SEPARATOR: &str = ", ";
    pub const FIELD_SEPARATOR: &str = ": ";
    pub const QUALIFIER: &str = ".";
    /// 型が分からない構成子の値。`{tag}` は構成子のタグ
    pub const UNKNOWN_CONSTRUCTOR: &str = "<constructor #{tag}>";
    /// 中身を見せない組み込みの型の値。`{name}` は型の名前
    pub const OPAQUE: &str = "<{name}>";
    /// 型が分からず、形からも書けない値（関数、リソース、セルなど）
    pub const FUNCTION: &str = "<function>";
    pub const UNKNOWN_VALUE: &str = "<value>";
}

use std::rc::Rc;

use crate::base::BindingId;
use crate::modules::ModuleKind;
use crate::runtime::heap::{FieldsKind, ObjKind};
use crate::syntax::ast::{self, Arg, ElseBranch, Expr, ListElem, Stmt};
use crate::types::builtin::{BuiltinTypeClass, BuiltinTypeId};
use crate::types::{TyCon, TypeArg};

const EQUAL_NAME: &str = "Benitoite.Assert.equal";
const NOT_EQUAL_NAME: &str = "Benitoite.Assert.notEqual";
const OPERATIONS: [(&str, AssertOp); 4] = [
    (EQUAL_NAME, AssertOp::Equal),
    (NOT_EQUAL_NAME, AssertOp::NotEqual),
    ("Benitoite.Assert.isTrue", AssertOp::IsTrue),
    ("Benitoite.Assert.fail", AssertOp::Fail),
];

fn internal(message: &str) -> Stop {
    Stop::Internal(message.to_owned())
}

fn failed_with<'e>(ctx: &ValueCtx<'e>, message: Value<'e>) -> Result<AssertVerdict, Stop> {
    let message = ctx
        .str(message)
        .ok_or_else(|| internal("Assert message is not String"))?;
    Ok(AssertVerdict::Failed {
        message: message.to_owned(),
        left: None,
        right: None,
    })
}

// ---------------- 呼び出しの式の型の表 ----------------

// AST は再帰で辿ってよい（実装プラン 00-02「再帰の深さ」）。
struct Collector<'a> {
    checked: &'a CheckedProgram,
    /// `Assert.equal`・`Assert.notEqual` の操作の束縛
    targets: [BindingId; 2],
    value_types: HashMap<Span, Ty>,
}

impl Collector<'_> {
    fn module(&mut self, module: &ast::Module) {
        for decl in &module.decls {
            match &decl.item {
                ast::Item::Fn(f) => self.function(f),
                ast::Item::Const(c) => self.expr(&c.value),
                ast::Item::Impl(i) => {
                    for f in &i.fns {
                        self.function(&f.decl);
                    }
                }
                ast::Item::Data(_)
                | ast::Item::Alias(_)
                | ast::Item::Record(_)
                | ast::Item::Trait(_)
                | ast::Item::Effect(_)
                | ast::Item::Error(_) => {}
            }
        }
    }

    fn function(&mut self, f: &ast::FnDecl) {
        if let Some(body) = &f.body {
            self.block(body);
        }
    }

    fn block(&mut self, block: &ast::Block) {
        for stmt in &block.stmts {
            match stmt {
                Stmt::Bind(b) => self.expr(&b.value),
                Stmt::Expr(e) => self.expr(e),
                Stmt::Error(_) => {}
            }
        }
    }

    /// 呼び出しが `Assert.equal`・`Assert.notEqual` の操作を名前で指すなら、比べる値の型（名前のノードの
    /// 最初の型引数）を返す（10-18「確認と値の書き出し」）。
    fn compared_type(&self, call: &ast::CallExpr) -> Option<Ty> {
        let mut callee = &*call.callee;
        while let Expr::Paren(p) = callee {
            callee = &p.inner;
        }
        let Expr::Name(name) = callee else {
            return None;
        };
        let binding = self.checked.resolved.refs.get(name.id)?;
        if !self.targets.contains(binding) {
            return None;
        }
        match self.checked.types.type_args.get(name.id)?.tys.first()? {
            TypeArg::Ty(ty) => Some(ty.clone()),
            TypeArg::Head(_) => None,
        }
    }

    fn expr(&mut self, expr: &Expr) {
        match expr {
            Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) | Expr::Error(_) => {}
            Expr::Interp(e) => {
                for segment in &e.segments {
                    self.expr(&segment.expr);
                }
            }
            Expr::Paren(e) => self.expr(&e.inner),
            Expr::List(e) => {
                for elem in &e.elems {
                    match elem {
                        ListElem::Expr(x) => self.expr(x),
                        ListElem::Spread(s) => self.expr(&s.expr),
                    }
                }
            }
            Expr::Call(call) => {
                if let Some(ty) = self.compared_type(call) {
                    self.value_types.insert(call.span, ty);
                }
                self.expr(&call.callee);
                for arg in &call.args {
                    if let Arg::Expr(x) = arg {
                        self.expr(x);
                    }
                }
            }
            Expr::Record(e) => {
                if let Some(base) = &e.base {
                    self.expr(base);
                }
                for field in &e.fields {
                    self.expr(&field.value);
                }
            }
            Expr::Binary(e) => {
                self.expr(&e.lhs);
                self.expr(&e.rhs);
            }
            Expr::Unary(e) => self.expr(&e.operand),
            Expr::Pipe(e) => {
                // 脱糖はパイプの展開の計算の由来位置をパイプの式全体にするので、その span も鍵にする
                // （02-02「合成ノードの由来位置」）。
                if let Expr::Call(call) = &*e.rhs
                    && let Some(ty) = self.compared_type(call)
                {
                    self.value_types.insert(e.span, ty);
                }
                self.expr(&e.lhs);
                self.expr(&e.rhs);
            }
            Expr::If(e) => self.if_expr(e),
            Expr::Match(e) => {
                self.expr(&e.scrutinee);
                for arm in &e.arms {
                    if let Some(guard) = &arm.guard {
                        self.expr(guard);
                    }
                    self.block(&arm.body);
                }
            }
            Expr::Lambda(e) => self.block(&e.body),
            Expr::Return(e) => self.expr(&e.value),
            Expr::Try(e) => self.expr(&e.value),
            Expr::Lazy(e) => self.block(&e.body),
            Expr::With(e) => {
                for bind in &e.binds {
                    self.expr(&bind.value);
                }
                self.block(&e.body);
            }
            Expr::Handle(e) => {
                self.block(&e.body);
                for clause in &e.clauses {
                    self.block(&clause.body);
                }
            }
            Expr::Resume(e) => self.expr(&e.value),
        }
    }

    fn if_expr(&mut self, e: &ast::IfExpr) {
        self.expr(&e.cond);
        self.block(&e.then_block);
        match &e.else_branch {
            Some(ElseBranch::Block(b)) => self.block(b),
            Some(ElseBranch::If(next)) => self.if_expr(next),
            None => {}
        }
    }
}

// ---------------- 値の書き出し ----------------

enum Work<'e> {
    Text(&'static str),
    Owned(String),
    /// 書き出す値と、分かっていればその型（型パラメータを含まない）
    Value(Value<'e>, Option<Rc<Ty>>),
}

// 静的な型は値ではないので、再帰で辿ってよい。
fn has_params(ty: &Ty) -> bool {
    match ty {
        Ty::Con(_, args) => args.iter().any(has_params),
        Ty::Fn(f) => f.params.iter().any(has_params) || has_params(&f.ret),
        Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => true,
    }
}

// 構成子の引数の型の、型の宣言の型パラメータを、値の型の引数で置き換える。
fn substitute(ty: &Ty, args: &[Ty]) -> Ty {
    match ty {
        Ty::Con(con, xs) => Ty::Con(*con, xs.iter().map(|x| substitute(x, args)).collect()),
        Ty::Fn(f) => Ty::Fn(Box::new(crate::types::FnTy {
            params: f.params.iter().map(|x| substitute(x, args)).collect(),
            ret: substitute(&f.ret, args),
            effects: f.effects.clone(),
        })),
        Ty::Param(i) => usize::try_from(*i)
            .ok()
            .and_then(|i| args.get(i))
            .cloned()
            .unwrap_or_else(|| ty.clone()),
        Ty::App(..) | Ty::Rigid { .. } => ty.clone(),
    }
}

// 値一つを、前から順に書く仕事の並びにする。中の値は `Work::Value` として残し、呼び出し側が積み重ねで辿る。
fn render_one<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: Option<Rc<Ty>>,
    out: &mut Vec<Work<'e>>,
) -> Result<(), Stop> {
    if let Some(ty) = ty
        && render_typed(ctx, table, value, &ty, out)?
    {
        return Ok(());
    }
    render_shape(ctx, value, out)
}

// 型に従って書く。値が型の形でない（表の型が当たらない）ときは偽を返し、呼び出し側が形だけから書く。
fn render_typed<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: &Ty,
    out: &mut Vec<Work<'e>>,
) -> Result<bool, Stop> {
    let Ty::Con(con, args) = ty else {
        return Ok(false);
    };
    let elem = |i: usize| args.get(i).map(|t| Rc::new(t.clone()));
    match con {
        TyCon::Builtin(id) => match *id {
            BuiltinTypeId::LIST if is_list(ctx, value) => {
                let items = crate::runtime::list::to_vec(ctx, value)?;
                sequence(out, text::LIST_OPEN, items, elem(0), text::LIST_CLOSE);
            }
            BuiltinTypeId::SET if is_set(ctx, value) => {
                let items = crate::runtime::map::set_to_vec(ctx, value)?;
                sequence(out, text::SET_OPEN, items, elem(0), text::FROM_LIST_CLOSE);
            }
            BuiltinTypeId::MAP if is_map(ctx, value) => {
                let pairs = crate::runtime::map::map_to_vec(ctx, value)?;
                map_pairs(out, pairs, elem(0), elem(1));
            }
            BuiltinTypeId::INTEGER
            | BuiltinTypeId::FLOAT
            | BuiltinTypeId::DECIMAL
            | BuiltinTypeId::BYTE
            | BuiltinTypeId::BOOLEAN
            | BuiltinTypeId::UNIT
            | BuiltinTypeId::STRING
            | BuiltinTypeId::CHARACTER
            | BuiltinTypeId::BYTES => {
                // 基本型は値の形と書き方が一対一なので、形だけから書くのと同じになる。形が型と合うかだけ確かめる。
                if !basic_matches(ctx, *id, value) {
                    return Ok(false);
                }
                render_shape(ctx, value, out)?;
            }
            other => {
                let Some(def) = other.def() else {
                    return Ok(false);
                };
                if !matches!(
                    def.class,
                    BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                ) {
                    return Ok(false);
                }
                out.push(Work::Owned(text::OPAQUE.replace("{name}", def.name)));
            }
        },
        TyCon::Adt(binding) => {
            let Some(def) = table.adts.adts.get(*binding) else {
                return Ok(false);
            };
            let Some((tag, fields)) = constructor_parts(ctx, value)? else {
                return Ok(false);
            };
            let Some(ctor) = def.ctors.iter().find(|c| c.tag == tag) else {
                return Ok(false);
            };
            if ctor.fields.len() != fields.len() {
                return Ok(false);
            }
            let types = ctor.fields.iter().map(|f| Rc::new(substitute(f, args)));
            if let Some(record) = &def.record {
                // レコードはフィールドの名前を宣言の順に書く（10-18 の表）。
                out.push(Work::Owned(def.name.clone()));
                out.push(Work::Text(text::ARGS_OPEN));
                for (i, ((field, value), ty)) in record.iter().zip(fields).zip(types).enumerate() {
                    if i > 0 {
                        out.push(Work::Text(text::SEPARATOR));
                    }
                    out.push(Work::Owned(field.name.clone()));
                    out.push(Work::Text(text::FIELD_SEPARATOR));
                    out.push(Work::Value(value, Some(ty)));
                }
                out.push(Work::Text(text::ARGS_CLOSE));
                return Ok(true);
            }
            // 構成子が一つで型と同じ名前のもの（`Pair`・`Triple`）は型で修飾しない（10-14「書き方の方針」）。
            if def.ctors.len() == 1 && ctor.name == def.name {
                out.push(Work::Owned(ctor.name.clone()));
            } else {
                out.push(Work::Owned(def.name.clone()));
                out.push(Work::Text(text::QUALIFIER));
                out.push(Work::Owned(ctor.name.clone()));
            }
            arguments(out, fields.into_iter().zip(types.map(Some)));
        }
    }
    Ok(true)
}

fn basic_matches<'e>(ctx: &ValueCtx<'e>, id: BuiltinTypeId, value: Value<'e>) -> bool {
    match id {
        BuiltinTypeId::INTEGER => matches!(value, Value::Int(_)),
        BuiltinTypeId::FLOAT => matches!(value, Value::Float(_)),
        BuiltinTypeId::BYTE => matches!(value, Value::Byte(_)),
        BuiltinTypeId::BOOLEAN => matches!(value, Value::Bool(_)),
        BuiltinTypeId::UNIT => matches!(value, Value::Unit),
        BuiltinTypeId::CHARACTER => matches!(value, Value::Char(_)),
        BuiltinTypeId::DECIMAL => ctx.kind(value) == Some(ObjKind::Decimal),
        BuiltinTypeId::STRING => ctx.kind(value) == Some(ObjKind::Str),
        BuiltinTypeId::BYTES => ctx.kind(value) == Some(ObjKind::Bytes),
        _ => false,
    }
}

// 値の形だけから書く（10-18「確認と値の書き出し」の型が分からないとき）。
fn render_shape<'e>(
    ctx: &ValueCtx<'e>,
    value: Value<'e>,
    out: &mut Vec<Work<'e>>,
) -> Result<(), Stop> {
    let written = match value {
        Value::Int(n) => n.to_string(),
        Value::Float(x) => crate::base::prim::float_to_text(x),
        Value::Byte(b) => b.to_string(),
        Value::Bool(b) => return push(out, if b { text::TRUE } else { text::FALSE }),
        Value::Char(c) => quoted([c].into_iter(), '\''),
        Value::Unit => return push(out, text::UNIT),
        Value::Tag(tag) => text::UNKNOWN_CONSTRUCTOR.replace("{tag}", &tag.0.to_string()),
        Value::Resource(_) => return push(out, text::UNKNOWN_VALUE),
        Value::EmptyList => {
            sequence(out, text::LIST_OPEN, Vec::new(), None, text::LIST_CLOSE);
            return Ok(());
        }
        Value::EmptyMap => {
            map_pairs(out, Vec::new(), None, None);
            return Ok(());
        }
        Value::EmptySet => {
            sequence(out, text::SET_OPEN, Vec::new(), None, text::FROM_LIST_CLOSE);
            return Ok(());
        }
        Value::Obj(_) => return render_object(ctx, value, out),
    };
    out.push(Work::Owned(written));
    Ok(())
}

fn render_object<'e>(
    ctx: &ValueCtx<'e>,
    value: Value<'e>,
    out: &mut Vec<Work<'e>>,
) -> Result<(), Stop> {
    match ctx.kind(value) {
        Some(ObjKind::Str) => {
            let s = ctx
                .str(value)
                .ok_or_else(|| internal("string object has no text"))?;
            out.push(Work::Owned(quoted(s.chars(), '"')));
        }
        Some(ObjKind::Decimal) => {
            let d = ctx
                .decimal(value)
                .ok_or_else(|| internal("decimal object has no value"))?;
            out.push(Work::Owned(d.to_text()));
        }
        Some(ObjKind::Bytes) => {
            let bytes = ctx
                .bytes(value)
                .ok_or_else(|| internal("bytes object has no content"))?;
            out.push(Work::Text(text::BYTES_OPEN));
            for (i, b) in bytes.iter().enumerate() {
                if i > 0 {
                    out.push(Work::Text(text::SEPARATOR));
                }
                out.push(Work::Owned(b.to_string()));
            }
            out.push(Work::Text(text::FROM_LIST_CLOSE));
        }
        Some(ObjKind::Fields(FieldsKind::ListCell | FieldsKind::ListNode)) => {
            let items = crate::runtime::list::to_vec(ctx, value)?;
            sequence(out, text::LIST_OPEN, items, None, text::LIST_CLOSE);
        }
        Some(ObjKind::Fields(FieldsKind::MapNode)) => {
            let pairs = crate::runtime::map::map_to_vec(ctx, value)?;
            map_pairs(out, pairs, None, None);
        }
        Some(ObjKind::Fields(FieldsKind::SetNode)) => {
            let items = crate::runtime::map::set_to_vec(ctx, value)?;
            sequence(out, text::SET_OPEN, items, None, text::FROM_LIST_CLOSE);
        }
        Some(ObjKind::Fields(FieldsKind::Ctor)) => {
            let Some((tag, fields)) = constructor_parts(ctx, value)? else {
                return Err(internal("constructor object has no fields"));
            };
            out.push(Work::Owned(
                text::UNKNOWN_CONSTRUCTOR.replace("{tag}", &tag.to_string()),
            ));
            arguments(out, fields.into_iter().map(|v| (v, None)));
        }
        Some(ObjKind::Fields(FieldsKind::Func)) => out.push(Work::Text(text::FUNCTION)),
        Some(
            ObjKind::Fields(FieldsKind::Dict | FieldsKind::IoError | FieldsKind::NetworkError)
            | ObjKind::Cell
            | ObjKind::Opaque
            | ObjKind::Host,
        ) => out.push(Work::Text(text::UNKNOWN_VALUE)),
        None => return Err(internal("object value has no kind")),
    }
    Ok(())
}

fn push(out: &mut Vec<Work<'_>>, text: &'static str) -> Result<(), Stop> {
    out.push(Work::Text(text));
    Ok(())
}

// 構成子の値のタグと引数。構成子の値でなければ `None`。
fn constructor_parts<'e>(
    ctx: &ValueCtx<'e>,
    value: Value<'e>,
) -> Result<Option<(u32, Vec<Value<'e>>)>, Stop> {
    if let Value::Tag(tag) = value {
        return Ok(Some((tag.0, Vec::new())));
    }
    let Some((FieldsKind::Ctor, tag)) = ctx.fields_header(value) else {
        return Ok(None);
    };
    let len = ctx
        .fields_len(value)
        .ok_or_else(|| internal("constructor length missing"))?;
    let mut fields = Vec::with_capacity(usize::try_from(len).unwrap_or(0));
    for i in 0..len {
        fields.push(
            ctx.field(value, i)
                .ok_or_else(|| internal("constructor field missing"))?,
        );
    }
    Ok(Some((tag, fields)))
}

fn arguments<'e>(
    out: &mut Vec<Work<'e>>,
    fields: impl ExactSizeIterator<Item = (Value<'e>, Option<Rc<Ty>>)>,
) {
    if fields.len() == 0 {
        return;
    }
    out.push(Work::Text(text::ARGS_OPEN));
    for (i, (value, ty)) in fields.enumerate() {
        if i > 0 {
            out.push(Work::Text(text::SEPARATOR));
        }
        out.push(Work::Value(value, ty));
    }
    out.push(Work::Text(text::ARGS_CLOSE));
}

fn sequence<'e>(
    out: &mut Vec<Work<'e>>,
    open: &'static str,
    items: Vec<Value<'e>>,
    ty: Option<Rc<Ty>>,
    close: &'static str,
) {
    out.push(Work::Text(open));
    for (i, value) in items.into_iter().enumerate() {
        if i > 0 {
            out.push(Work::Text(text::SEPARATOR));
        }
        out.push(Work::Value(value, ty.clone()));
    }
    out.push(Work::Text(close));
}

fn map_pairs<'e>(
    out: &mut Vec<Work<'e>>,
    pairs: Vec<(Value<'e>, Value<'e>)>,
    key: Option<Rc<Ty>>,
    value: Option<Rc<Ty>>,
) {
    out.push(Work::Text(text::MAP_OPEN));
    for (i, (k, v)) in pairs.into_iter().enumerate() {
        if i > 0 {
            out.push(Work::Text(text::SEPARATOR));
        }
        out.push(Work::Text(text::PAIR_OPEN));
        out.push(Work::Value(k, key.clone()));
        out.push(Work::Text(text::SEPARATOR));
        out.push(Work::Value(v, value.clone()));
        out.push(Work::Text(text::ARGS_CLOSE));
    }
    out.push(Work::Text(text::FROM_LIST_CLOSE));
}

fn is_list<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptyList)
        || matches!(
            ctx.kind(value),
            Some(ObjKind::Fields(FieldsKind::ListCell | FieldsKind::ListNode))
        )
}

fn is_map<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptyMap)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::MapNode))
}

fn is_set<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptySet)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::SetNode))
}

// リテラルの形。`Trait.showString`・`Trait.showCharacter` と同じエスケープ（`builtins::funcs::traits` の
// `escaped` と同じ規則を写したもの。実装プラン D10「手順の要点」の 4）。
pub(crate) fn quoted(chars: impl Iterator<Item = char>, quote: char) -> String {
    let mut out = String::new();
    out.push(quote);
    for c in chars {
        escape_into(&mut out, c, quote);
    }
    out.push(quote);
    out
}

fn escape_into(out: &mut String, c: char, quote: char) {
    match c {
        '\n' => out.push_str("\\n"),
        '\r' => out.push_str("\\r"),
        '\t' => out.push_str("\\t"),
        '\\' => out.push_str("\\\\"),
        '$' if quote == '"' => out.push_str("\\$"),
        c if c == quote => {
            out.push('\\');
            out.push(c);
        }
        '\u{0}'..='\u{1f}'
        | '\u{7f}'
        | '\u{61c}'
        | '\u{200e}'
        | '\u{200f}'
        | '\u{202a}'..='\u{202e}'
        | '\u{2066}'..='\u{2069}'
        | '\u{feff}' => out.push_str(&format!("\\u{{{:x}}}", u32::from(c))),
        c => out.push(c),
    }
}

#[cfg(test)]
pub(crate) mod tests;

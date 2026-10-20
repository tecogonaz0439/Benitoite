//! テストの実行器が処理する `Assert.Check` の操作
//! （設計書 02-11「テストの実行」、06-04「期待の確認」「結果の報告」）。
//! どの言語のハンドラも処理しなかった `Assert` の操作を、VM は送り出しの列に置かずに `evaluate` へ渡す。

use std::collections::{HashMap, HashSet};

use crate::base::Span;
use crate::base::literal::{escape_into, text as literal_text};
use crate::builtins::BuiltinId;
use crate::bytecode::program::CompiledProgram;
use crate::resolve::BindingKind;
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

// 関数の使用箇所の型引数と、その名前を書いたトップレベルの関数。
type FunctionInstance = (Vec<Ty>, Option<BindingId>);

/// テストの実行器が VM に渡す表。ファイル一つの検査の結果から一度作り、そのファイルのテストで共有する。
#[derive(Debug)]
pub struct AssertTable {
    /// 組み込みの関数の表の項目と操作の対応（`Benitoite.Assert.equal` などを `lookup_builtin` で引いたもの）
    pub ops: Vec<(BuiltinId, AssertOp)>,
    /// `Assert.equal`・`Assert.notEqual` を呼ぶ式の span → 比べる値の型（設計書 06-04「期待の確認」）
    pub value_types: HashMap<Span, Ty>,
    /// 型パラメータを含む確認の位置 → 確認を書いたトップレベルの関数。
    pub owners: HashMap<Span, BindingId>,
    /// 利用者の関数を呼ぶ式の span → 呼ばれる関数と型引数。
    pub calls: HashMap<Span, CallTypeArgs>,
    /// 関数の全使用箇所の型引数と、その名前を書いたトップレベルの関数。
    pub instances: HashMap<BindingId, Vec<FunctionInstance>>,
    /// 型引数に型コンストラクタを含む使用がある関数。その使用を候補に写せないので、候補の集まりが欠ける。
    pub incomplete_instances: HashSet<BindingId>,
    /// 型の中の代数的データ型とレコードを引く表（`TypeckOutput::adts` の写し。設計書 02-05「出力」）
    pub adts: AdtTable,
}

/// 利用者のトップレベルの関数を呼ぶ位置の型引数（設計書 02-11「テストの実行」）。
#[derive(Debug)]
pub struct CallTypeArgs {
    /// 呼ばれる関数の束縛。
    pub callee: BindingId,
    /// 名前のノードに記録された型引数。
    pub args: Vec<Ty>,
    /// 呼び出しを書いたトップレベルの関数。実装のメソッドと定数は含めない。
    pub owner: Option<BindingId>,
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

/// 確認の失敗の記録。VM が失敗を見つけた時点で、枠を一つも降ろさないうちに作る（`StopInfo` と同じ時点。設計書 02-08「実行時エラーの情報の記録」）。
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
use crate::runtime::heap::{Value, ValueCtx};
use crate::runtime::{Stop, list, map};

impl AssertTable {
    /// 検査を通ったプログラムから表を作る（設計書 06-04「期待の確認」）。`Assert` の操作が組み込みの関数の表か
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
        let mut functions = HashSet::new();
        for module in checked.modules.iter().filter(|m| {
            matches!(
                m.kind,
                ModuleKind::Entry | ModuleKind::User | ModuleKind::Package
            )
        }) {
            let ast = usize::try_from(module.id.0)
                .ok()
                .and_then(|index| checked.asts.get(index))
                .ok_or_else(|| format!("module {} has no AST", module.id.0))?;
            for decl in &ast.decls {
                if let ast::Item::Fn(f) = &decl.item
                    && let Some(&binding) = checked.resolved.decls.get(f.id)
                    && checked
                        .resolved
                        .bindings
                        .get(binding)
                        .is_some_and(|b| b.kind == BindingKind::Fn)
                {
                    functions.insert(binding);
                }
            }
        }
        let mut collector = Collector {
            checked,
            targets: [binding(EQUAL_NAME)?, binding(NOT_EQUAL_NAME)?],
            value_types: HashMap::new(),
            functions,
            owner: None,
            owners: HashMap::new(),
            calls: HashMap::new(),
            instances: HashMap::new(),
            incomplete_instances: HashSet::new(),
        };
        // 利用者のモジュールだけを辿る。標準ライブラリの中の呼び出しは、利用者の確認の位置にならない。
        for module in checked.modules.iter().filter(|m| {
            matches!(
                m.kind,
                ModuleKind::Entry | ModuleKind::User | ModuleKind::Package
            )
        }) {
            let ast = usize::try_from(module.id.0)
                .ok()
                .and_then(|index| checked.asts.get(index))
                .ok_or_else(|| format!("module {} has no AST", module.id.0))?;
            collector.module(ast);
        }
        Ok(AssertTable {
            ops,
            value_types: collector.value_types,
            owners: collector.owners,
            calls: collector.calls,
            instances: collector.instances,
            incomplete_instances: collector.incomplete_instances,
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

/// 確認を行う（設計書 06-04「期待の確認」）。`args` は操作の引数、`site` は操作を呼んだ命令の由来位置。
/// 型パラメータを含む値の比較が失敗したときだけ `frames` で枠を取得し、`program` の原型と照合する。
pub fn evaluate<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    op: AssertOp,
    args: &[Value<'e>],
    site: Option<Span>,
    program: &CompiledProgram,
    frames: &dyn Fn() -> Vec<FrameRecord>,
) -> Result<AssertVerdict, Stop> {
    match (op, args) {
        (AssertOp::Equal | AssertOp::NotEqual, &[actual, expected]) => {
            let equal = crate::runtime::equal::values_equal(ctx, actual, expected)?;
            if equal == (op == AssertOp::Equal) {
                return Ok(AssertVerdict::Passed);
            }
            // 型は呼び出しの式の span で引く（設計書 06-04「期待の確認」、02-02「合成ノードの由来位置」）。
            let ty = site.and_then(|span| table.value_types.get(&span));
            // 成り立つ確認では枠を集めない。復元した型は値の形とも照合する（設計書 02-11「テストの実行」）。
            let recovered = if let Some(ty) = ty.filter(|ty| has_params(ty)) {
                Some(recover_type(
                    ctx,
                    table,
                    program,
                    &frames(),
                    site,
                    ty,
                    (actual, expected),
                )?)
            } else {
                None
            };
            let ty = recovered.as_ref().or(ty);
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

/// 一つの値の書き出しの上限（`…` を含む）（設計書 06-04「結果の報告」）。
const MAX_RENDERED_BYTES: usize = 4096;

/// 値を 03-06 の `Show.show` の形に揃えて書き出す。型が分からない位置だけを値の形から書く。
/// 4,096 バイトを超えるときは切って `…` で終える（設計書 06-04「結果の報告」）。
pub fn render_value<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: Option<&Ty>,
) -> Result<String, Stop> {
    // 外側やフィールドの具体的な型は残し、型パラメータの位置だけ形から書く。
    let ty = ty.map(|ty| Rc::new(ty.clone()));
    let mut out = String::new();
    // 実行時の値を辿るので、Rust の再帰でなく明示の積み重ねで書く（AGENTS.md「実装の規約」の「再帰の深さ」）。
    let mut stack = vec![Work::Value(value, ty)];
    // 各値の最初の仕事は、数値・真偽・単位・引用符・型名・構成子名・開き記号・形の代替表記の
    // いずれかで、必ず 1 バイト以上を書く。List・Tree・Bytes の続きも一度に一要素だけを進める。
    // したがって、辿る値の数は出力の上限で抑えられる。構成子の引数の数は宣言で決まる
    // （設計書 06-04「結果の報告」）。上限ちょうどの値を切らないため、超えたことが分かるまで書く。
    while out.len() <= MAX_RENDERED_BYTES {
        let Some(work) = stack.pop() else {
            break;
        };
        let budget = MAX_RENDERED_BYTES.saturating_sub(out.len());
        match work {
            Work::Text(text) => append_within(&mut out, text, budget),
            Work::Owned(text) => append_within(&mut out, &text, budget),
            Work::Value(value, ty) => {
                let mut forward = Vec::new();
                render_one(ctx, table, value, ty, &mut forward, budget)?;
                stack.extend(forward.into_iter().rev());
            }
            Work::List {
                mut cursor,
                ty,
                first,
                close,
            } => {
                if let Some(value) = cursor.next(ctx)? {
                    stack.push(Work::List {
                        cursor,
                        ty: ty.clone(),
                        first: false,
                        close,
                    });
                    stack.push(Work::Value(value, ty));
                    if !first {
                        stack.push(Work::Text(literal_text::SEPARATOR));
                    }
                } else {
                    stack.push(Work::Text(close));
                }
            }
            Work::Tree {
                mut cursor,
                key,
                value,
                is_map,
                first,
            } => {
                if let Some((k, v)) = cursor.next(ctx)? {
                    stack.push(Work::Tree {
                        cursor,
                        key: key.clone(),
                        value: value.clone(),
                        is_map,
                        first: false,
                    });
                    if is_map {
                        stack.push(Work::Text(literal_text::ARGS_CLOSE));
                        stack.push(Work::Value(v, value));
                        stack.push(Work::Text(literal_text::SEPARATOR));
                    }
                    stack.push(Work::Value(k, key));
                    if is_map {
                        stack.push(Work::Text(literal_text::PAIR_OPEN));
                    }
                    if !first {
                        stack.push(Work::Text(literal_text::SEPARATOR));
                    }
                } else {
                    stack.push(Work::Text(literal_text::FROM_LIST_CLOSE));
                }
            }
            Work::Bytes { value, index } => {
                let bytes = ctx
                    .bytes(value)
                    .ok_or_else(|| internal("bytes object has no content"))?;
                if let Some(b) = bytes.get(index) {
                    stack.push(Work::Bytes {
                        value,
                        index: index.saturating_add(1),
                    });
                    stack.push(Work::Owned(b.to_string()));
                    if index > 0 {
                        stack.push(Work::Text(literal_text::SEPARATOR));
                    }
                } else {
                    stack.push(Work::Text(literal_text::FROM_LIST_CLOSE));
                }
            }
        }
    }
    if out.len() > MAX_RENDERED_BYTES {
        let mut end = MAX_RENDERED_BYTES.saturating_sub(literal_text::ELLIPSIS.len());
        while !out.is_char_boundary(end) {
            end = end.saturating_sub(1);
        }
        out.truncate(end);
        out.push_str(literal_text::ELLIPSIS);
    }
    Ok(out)
}

/// 実行器だけが使う報告の表記（設計書 02-10「文言の言語」）。
pub(crate) mod text {
    /// `Failed` の `message` の前置き。操作の名前を続ける（設計書 06-04「期待の確認」）
    pub const ASSERTION_FAILED: &str = "assertion failed: ";
    /// 型を復元できない構成子。`{tag}` は型の宣言の中の位置（0 から数える）。
    pub const UNKNOWN_CONSTRUCTOR: &str = "<constructor #{tag} of an unknown type>";
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
use crate::syntax::ast::{self, ElseBranch, Expr, ListElem, Stmt};
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

// AST は再帰で辿ってよい（AGENTS.md「実装の規約」の「再帰の深さ」）。
struct Collector<'a> {
    checked: &'a CheckedProgram,
    /// `Assert.equal`・`Assert.notEqual` の操作の束縛
    targets: [BindingId; 2],
    value_types: HashMap<Span, Ty>,
    functions: HashSet<BindingId>,
    owner: Option<BindingId>,
    owners: HashMap<Span, BindingId>,
    calls: HashMap<Span, CallTypeArgs>,
    instances: HashMap<BindingId, Vec<FunctionInstance>>,
    incomplete_instances: HashSet<BindingId>,
}

impl Collector<'_> {
    fn module(&mut self, module: &ast::Module) {
        for decl in &module.decls {
            match &decl.item {
                ast::Item::Fn(f) => {
                    self.owner = self
                        .checked
                        .resolved
                        .decls
                        .get(f.id)
                        .copied()
                        .filter(|b| self.functions.contains(b));
                    self.function(f);
                    self.owner = None;
                }
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
                | ast::Item::ExternalType(_)
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
    /// 最初の型引数）を返す（設計書 06-04「期待の確認」）。
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

    fn instance(&mut self, name: &ast::NameExpr) -> Option<(BindingId, Vec<Ty>)> {
        let binding = *self.checked.resolved.refs.get(name.id)?;
        if !self.functions.contains(&binding) {
            return None;
        }
        let args = self
            .checked
            .types
            .type_args
            .get(name.id)?
            .tys
            .iter()
            .map(|arg| match arg {
                TypeArg::Ty(ty) => Some(ty.clone()),
                TypeArg::Head(_) => None,
            })
            .collect::<Option<Vec<_>>>();
        let Some(args) = args else {
            // 一部の使用を落とすと、残る候補だけで誤った型に決まる（設計書 02-11「テストの実行」）。
            self.incomplete_instances.insert(binding);
            return None;
        };
        Some((binding, args))
    }

    fn call(&mut self, callee: &Expr, site: Span) {
        let mut callee = callee;
        while let Expr::Paren(p) = callee {
            callee = &p.inner;
        }
        if let Expr::Name(name) = callee
            && let Some((binding, args)) = self.instance(name)
        {
            self.calls.insert(
                site,
                CallTypeArgs {
                    callee: binding,
                    args,
                    owner: self.owner,
                },
            );
        }
    }

    fn comparison(&mut self, call: &ast::CallExpr, site: Span) {
        if let Some(ty) = self.compared_type(call) {
            if has_params(&ty)
                && let Some(owner) = self.owner
            {
                self.owners.insert(site, owner);
            }
            self.value_types.insert(site, ty);
        }
    }

    fn expr(&mut self, expr: &Expr) {
        match expr {
            Expr::Lit(_) | Expr::Unit(_) | Expr::Error(_) => {}
            Expr::Name(name) => {
                if let Some((binding, args)) = self.instance(name) {
                    self.instances
                        .entry(binding)
                        .or_default()
                        .push((args, self.owner));
                }
            }
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
                self.comparison(call, call.span);
                self.call(&call.callee, call.span);
                self.expr(&call.callee);
                for arg in &call.args {
                    if let Some(x) = arg.expr() {
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
                if let Expr::Call(call) = &*e.rhs {
                    self.comparison(call, e.span);
                    self.call(&call.callee, e.span);
                } else {
                    self.call(&e.rhs, e.span);
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
            Expr::Try(e) => {
                self.expr(&e.value);
                if let crate::syntax::ast::TryAction::Die {
                    message: Some(message),
                    ..
                } = &e.action
                {
                    self.expr(message);
                }
            }
            Expr::Block(e) => self.block(&e.body),
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

// ---------------- 型パラメータの復元 ----------------

// 枠が消えた呼び出しは、全使用箇所の型引数を辿って候補を作る。循環や多数の実体で報告が
// 長引かないよう、探索の段数と項目数を制限する（設計書 02-11「テストの実行」）。
const MAX_INSTANCE_DEPTH: usize = 8;
const MAX_INSTANCES: usize = 64;
const MAX_FIT_STEPS: usize = 4096;

// 確認が関数の本体に直接あるときだけ枠から置き換え、続きは直接の呼び出し元の枠に限る。
// 枠を失った段やラムダでは全使用箇所の候補へ進み、左右の形に合う型が一つのときだけ使う。
// 形の照合だけでは、別の起動の型の取り違えを防げない（設計書 02-11「テストの実行」）。
fn recover_type<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    program: &CompiledProgram,
    frames: &[FrameRecord],
    site: Option<Span>,
    original: &Ty,
    values: (Value<'e>, Value<'e>),
) -> Result<Ty, Stop> {
    let (left, right) = values;
    let initial_owner = site.and_then(|site| table.owners.get(&site)).copied();
    let mut owner = initial_owner;
    let mut ty = original.clone();
    // 同じ関数の再帰でも、原型を段ごとに線形に探し直さない。
    let protos = program.top_fns.iter().copied().collect::<HashMap<_, _>>();
    let mut remaining = frames.iter().peekable();
    while has_params(&ty) {
        let Some(binding) = owner else { break };
        let Some(&proto) = protos.get(&binding) else {
            break;
        };
        let Some(frame) = remaining.next().filter(|frame| frame.proto == proto) else {
            break;
        };
        let Some(at) = frame.call_site else { break };
        let Some(call) = crate::runtime::report::instr_span(program, at)
            .and_then(|span| table.calls.get(&span))
            .filter(|call| call.callee == binding)
        else {
            break;
        };
        ty = substitute(&ty, &call.args);
        owner = call.owner;
        // 末尾呼び出しでは呼び出し元の枠が消えている。同じ原型の別の起動が直後にあっても辿らない。
        let opcode = program.proto(at.proto).and_then(|proto| {
            usize::try_from(at.pc)
                .ok()
                .and_then(|pc| proto.code.get(pc))
                .and_then(|instr| instr.opcode())
        });
        if opcode != Some(crate::bytecode::instr::Opcode::Call)
            || !remaining.peek().is_some_and(|next| next.proto == at.proto)
            || owner.and_then(|binding| protos.get(&binding)).copied() != Some(at.proto)
        {
            break;
        }
    }
    // 復元した型が値の形に合わなければ、確認の位置の型から候補を求め直す。
    if !fits(ctx, table, left, &ty)? || !fits(ctx, table, right, &ty)? {
        ty = original.clone();
        owner = initial_owner;
    }
    if !has_params(&ty) {
        return Ok(ty);
    }
    let Some(instances) = owner.and_then(|owner| concrete_instances(table, owner)) else {
        return Ok(ty);
    };
    let mut candidates = HashSet::new();
    for args in instances {
        let candidate = substitute(&ty, &args);
        if !has_params(&candidate) {
            candidates.insert(candidate);
        }
    }
    let mut found = None;
    for candidate in candidates {
        if fits(ctx, table, left, &candidate)? && fits(ctx, table, right, &candidate)? {
            if found.is_some() {
                return Ok(ty);
            }
            found = Some(candidate);
        }
    }
    Ok(found.unwrap_or(ty))
}

// 型引数の中のパラメータは、その名前を書いた関数の実体で置き換え、重なりを除いてから上限を調べる。
// 展開できない使用や探索の打ち切りがあれば、候補が欠けるので途中の実体も使わない。
// 循環は深さの上限で決めない側に倒す（設計書 02-11「テストの実行」）。
fn concrete_instances(table: &AssertTable, owner: BindingId) -> Option<HashSet<Vec<Ty>>> {
    if table.incomplete_instances.contains(&owner) {
        return None;
    }
    let initial = table.instances.get(&owner)?;
    let initial = unique_instances(initial);
    if initial.len() > MAX_INSTANCES {
        return None;
    }
    let mut stack = initial
        .iter()
        .map(|(args, writer)| (args.clone(), *writer, 0usize))
        .collect::<Vec<_>>();
    let mut seen = HashSet::new();
    let mut items = HashSet::new();
    let mut result = HashSet::new();
    while let Some((args, writer, depth)) = stack.pop() {
        let concrete = !args.iter().any(has_params);
        // 具体的な項目は書いた関数と深さによらず同じ候補である。循環する項目は深さを残す。
        let key = (args.clone(), writer, if concrete { 0 } else { depth });
        if !seen.insert(key) {
            continue;
        }
        items.insert((args.clone(), writer));
        if items.len() > MAX_INSTANCES {
            return None;
        }
        if concrete {
            result.insert(args);
            continue;
        }
        let writer = writer?;
        if table.incomplete_instances.contains(&writer) || depth >= MAX_INSTANCE_DEPTH {
            return None;
        }
        let uses = unique_instances(table.instances.get(&writer)?);
        if uses.is_empty() {
            return None;
        }
        let expanded = uses
            .into_iter()
            .map(|(outer, writer)| {
                let args = args.iter().map(|ty| substitute(ty, &outer)).collect();
                normalized_instance(args, writer)
            })
            .collect::<HashSet<_>>();
        if expanded.len() > MAX_INSTANCES {
            return None;
        }
        for (args, writer) in expanded {
            stack.push((args, writer, depth.saturating_add(1)));
        }
    }
    Some(result)
}

fn normalized_instance(args: Vec<Ty>, writer: Option<BindingId>) -> FunctionInstance {
    let writer = args.iter().any(has_params).then_some(writer).flatten();
    (args, writer)
}

fn unique_instances(instances: &[FunctionInstance]) -> HashSet<FunctionInstance> {
    instances
        .iter()
        .map(|(args, writer)| normalized_instance(args.clone(), *writer))
        .collect()
}

// コレクションの続きを一要素ずつ積む。全要素を積んでから上限を調べると、長い値を辿り切ってしまう。
enum FitWork<'e> {
    Value(Value<'e>, Ty),
    List(list::Cursor<'e>, Ty),
    Tree(map::Cursor<'e>, Ty, Option<Ty>),
}

// 表記と同じ基準で型と左右の値を照合する。共有した構造を展開し続けないよう、上限を超えた残りは
// 合うとみなす。真の型の候補を退けないので、上限のために一つの型に決まることはない。
// 候補の完全性と枠の対応は呼び出し側で確かめる（設計書 02-11「テストの実行」）。
fn fits<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: &Ty,
) -> Result<bool, Stop> {
    let mut stack = vec![FitWork::Value(value, ty.clone())];
    for _ in 0..MAX_FIT_STEPS {
        let Some(work) = stack.pop() else {
            return Ok(true);
        };
        let (value, ty) = match work {
            FitWork::Value(value, ty) => (value, ty),
            FitWork::List(mut cursor, ty) => {
                if let Some(value) = cursor.next(ctx)? {
                    stack.push(FitWork::List(cursor, ty.clone()));
                    stack.push(FitWork::Value(value, ty));
                }
                continue;
            }
            FitWork::Tree(mut cursor, key, item) => {
                if let Some((k, v)) = cursor.next(ctx)? {
                    stack.push(FitWork::Tree(cursor, key.clone(), item.clone()));
                    stack.push(FitWork::Value(k, key));
                    if let Some(item) = item {
                        stack.push(FitWork::Value(v, item));
                    }
                }
                continue;
            }
        };
        let Ty::Con(con, args) = ty else { continue };
        match con {
            TyCon::Builtin(id) => match id {
                BuiltinTypeId::LIST => {
                    if !is_list(ctx, value) {
                        return Ok(false);
                    }
                    if let Some(elem) = args.first() {
                        stack.push(FitWork::List(list::cursor(ctx, value)?, elem.clone()));
                    }
                }
                BuiltinTypeId::SET => {
                    if !is_set(ctx, value) {
                        return Ok(false);
                    }
                    if let Some(elem) = args.first() {
                        stack.push(FitWork::Tree(map::Cursor::set(value), elem.clone(), None));
                    }
                }
                BuiltinTypeId::MAP => {
                    if !is_map(ctx, value) {
                        return Ok(false);
                    }
                    if let Some(key) = args.first() {
                        stack.push(FitWork::Tree(
                            map::Cursor::map(value),
                            key.clone(),
                            args.get(1).cloned(),
                        ));
                    }
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
                    if !basic_matches(ctx, id, value) {
                        return Ok(false);
                    }
                }
                other => {
                    if !other.def().is_some_and(|def| {
                        matches!(
                            def.class,
                            BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                        )
                    }) {
                        return Ok(false);
                    }
                }
            },
            TyCon::External(_) => {}
            TyCon::Adt(binding) => {
                let Some(def) = table.adts.adts.get(binding) else {
                    return Ok(false);
                };
                let Some((tag, fields)) = constructor_parts(ctx, value)? else {
                    return Ok(false);
                };
                let Some(ctor) = def.ctors.iter().find(|ctor| ctor.tag == tag) else {
                    return Ok(false);
                };
                if fields.len() != ctor.fields.len() {
                    return Ok(false);
                }
                for (value, ty) in fields.into_iter().zip(&ctor.fields).rev() {
                    stack.push(FitWork::Value(value, substitute(ty, &args)));
                }
            }
        }
    }
    Ok(true)
}

// ---------------- 値の書き出し ----------------

enum Work<'e> {
    Text(&'static str),
    Owned(String),
    /// 書き出す値と、分かっていればその型（型パラメータの位置は形から書く）
    Value(Value<'e>, Option<Rc<Ty>>),
    List {
        cursor: list::Cursor<'e>,
        ty: Option<Rc<Ty>>,
        first: bool,
        close: &'static str,
    },
    Tree {
        cursor: map::Cursor<'e>,
        key: Option<Rc<Ty>>,
        value: Option<Rc<Ty>>,
        is_map: bool,
        first: bool,
    },
    Bytes {
        value: Value<'e>,
        index: usize,
    },
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
            param_names: f.param_names.clone(),
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
    budget: usize,
) -> Result<(), Stop> {
    if let Some(ty) = ty
        && render_typed(ctx, table, value, &ty, out, budget)?
    {
        return Ok(());
    }
    render_shape(ctx, value, out, budget)
}

// 型に従って書く。値が型の形でない（表の型が当たらない）ときは偽を返し、呼び出し側が形だけから書く。
fn render_typed<'e>(
    ctx: &ValueCtx<'e>,
    table: &AssertTable,
    value: Value<'e>,
    ty: &Ty,
    out: &mut Vec<Work<'e>>,
    budget: usize,
) -> Result<bool, Stop> {
    let Ty::Con(con, args) = ty else {
        return Ok(false);
    };
    let elem = |i: usize| args.get(i).map(|t| Rc::new(t.clone()));
    match con {
        TyCon::Builtin(id) => match *id {
            BuiltinTypeId::LIST if is_list(ctx, value) => {
                sequence(ctx, out, value, elem(0))?;
            }
            BuiltinTypeId::SET if is_set(ctx, value) => {
                tree_sequence(out, map::Cursor::set(value), elem(0), None, false);
            }
            BuiltinTypeId::MAP if is_map(ctx, value) => {
                tree_sequence(out, map::Cursor::map(value), elem(0), elem(1), true);
            }
            BuiltinTypeId::INTEGER
            | BuiltinTypeId::INTEGER8
            | BuiltinTypeId::INTEGER16
            | BuiltinTypeId::INTEGER32
            | BuiltinTypeId::UNSIGNED_INTEGER16
            | BuiltinTypeId::UNSIGNED_INTEGER32
            | BuiltinTypeId::UNSIGNED_INTEGER64
            | BuiltinTypeId::FLOAT32
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
                render_shape(ctx, value, out, budget)?;
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
        TyCon::External(_) => return Ok(false),
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
                // レコードはフィールドの名前を宣言の順に書く（設計書 06-04「期待の確認」）。
                out.push(Work::Owned(def.name.clone()));
                out.push(Work::Text(literal_text::ARGS_OPEN));
                for (i, ((field, value), ty)) in record.iter().zip(fields).zip(types).enumerate() {
                    if i > 0 {
                        out.push(Work::Text(literal_text::SEPARATOR));
                    }
                    out.push(Work::Owned(field.name.clone()));
                    out.push(Work::Text(literal_text::FIELD_SEPARATOR));
                    out.push(Work::Value(value, Some(ty)));
                }
                out.push(Work::Text(literal_text::ARGS_CLOSE));
                return Ok(true);
            }
            // 構成子が一つで型と同じ名前のもの（`Pair`・`Triple`）は型で修飾しない。
            if def.ctors.len() == 1 && ctor.name == def.name {
                out.push(Work::Owned(ctor.name.clone()));
            } else {
                out.push(Work::Owned(def.name.clone()));
                out.push(Work::Text(literal_text::QUALIFIER));
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
        BuiltinTypeId::INTEGER8 => matches!(value, Value::Int8(_)),
        BuiltinTypeId::INTEGER16 => matches!(value, Value::Int16(_)),
        BuiltinTypeId::INTEGER32 => matches!(value, Value::Int32(_)),
        BuiltinTypeId::UNSIGNED_INTEGER16 => matches!(value, Value::UInt16(_)),
        BuiltinTypeId::UNSIGNED_INTEGER32 => matches!(value, Value::UInt32(_)),
        BuiltinTypeId::UNSIGNED_INTEGER64 => matches!(value, Value::UInt64(_)),
        BuiltinTypeId::FLOAT32 => matches!(value, Value::Float32(_)),
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

// 値の形だけから書く（設計書 06-04「期待の確認」の型が分からないとき）。
fn render_shape<'e>(
    ctx: &ValueCtx<'e>,
    value: Value<'e>,
    out: &mut Vec<Work<'e>>,
    budget: usize,
) -> Result<(), Stop> {
    let written = match value {
        Value::Int(n) => n.to_string(),
        Value::Int8(n) => n.to_string(),
        Value::Int16(n) => n.to_string(),
        Value::Int32(n) => n.to_string(),
        Value::UInt16(n) => n.to_string(),
        Value::UInt32(n) => n.to_string(),
        Value::UInt64(n) => n.to_string(),
        Value::Float32(x) => crate::base::prim::float32_to_text(x),
        Value::Float(x) => crate::base::prim::float_to_text(x),
        Value::Byte(b) => b.to_string(),
        Value::Bool(b) => {
            return push(
                out,
                if b {
                    literal_text::TRUE
                } else {
                    literal_text::FALSE
                },
            );
        }
        Value::Char(c) => quoted_within([c].into_iter(), '\'', budget),
        Value::Unit => return push(out, literal_text::UNIT),
        Value::Tag(tag) => text::UNKNOWN_CONSTRUCTOR.replace("{tag}", &tag.0.to_string()),
        Value::Resource(_) => return push(out, text::UNKNOWN_VALUE),
        Value::EmptyList => {
            sequence(ctx, out, value, None)?;
            return Ok(());
        }
        Value::EmptyMap => {
            tree_sequence(out, map::Cursor::map(value), None, None, true);
            return Ok(());
        }
        Value::EmptySet => {
            tree_sequence(out, map::Cursor::set(value), None, None, false);
            return Ok(());
        }
        Value::Obj(_) => return render_object(ctx, value, out, budget),
    };
    out.push(Work::Owned(written));
    Ok(())
}

fn render_object<'e>(
    ctx: &ValueCtx<'e>,
    value: Value<'e>,
    out: &mut Vec<Work<'e>>,
    budget: usize,
) -> Result<(), Stop> {
    match ctx.kind(value) {
        Some(ObjKind::Str) => {
            let s = ctx
                .str(value)
                .ok_or_else(|| internal("string object has no text"))?;
            out.push(Work::Owned(quoted_within(s.chars(), '"', budget)));
        }
        Some(ObjKind::Decimal) => {
            let d = ctx
                .decimal(value)
                .ok_or_else(|| internal("decimal object has no value"))?;
            out.push(Work::Owned(d.to_text()));
        }
        Some(ObjKind::Bytes) => {
            out.push(Work::Text(literal_text::BYTES_OPEN));
            out.push(Work::Bytes { value, index: 0 });
        }
        Some(ObjKind::Fields(FieldsKind::ListNode)) => {
            sequence(ctx, out, value, None)?;
        }
        Some(ObjKind::Fields(FieldsKind::MapNode)) => {
            tree_sequence(out, map::Cursor::map(value), None, None, true);
        }
        Some(ObjKind::Fields(FieldsKind::SetNode)) => {
            tree_sequence(out, map::Cursor::set(value), None, None, false);
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
    out.push(Work::Text(literal_text::ARGS_OPEN));
    for (i, (value, ty)) in fields.enumerate() {
        if i > 0 {
            out.push(Work::Text(literal_text::SEPARATOR));
        }
        out.push(Work::Value(value, ty));
    }
    out.push(Work::Text(literal_text::ARGS_CLOSE));
}

fn sequence<'e>(
    ctx: &ValueCtx<'e>,
    out: &mut Vec<Work<'e>>,
    value: Value<'e>,
    ty: Option<Rc<Ty>>,
) -> Result<(), Stop> {
    out.push(Work::Text(literal_text::LIST_OPEN));
    out.push(Work::List {
        cursor: list::cursor(ctx, value)?,
        ty,
        first: true,
        close: literal_text::LIST_CLOSE,
    });
    Ok(())
}

fn tree_sequence<'e>(
    out: &mut Vec<Work<'e>>,
    cursor: map::Cursor<'e>,
    key: Option<Rc<Ty>>,
    value: Option<Rc<Ty>>,
    is_map: bool,
) {
    out.push(Work::Text(if is_map {
        literal_text::MAP_OPEN
    } else {
        literal_text::SET_OPEN
    }));
    out.push(Work::Tree {
        cursor,
        key,
        value,
        is_map,
        first: true,
    });
}

// 超過の判定に要る一文字までを足す。長い名前や表記でも出力の String を上限付近に保つ。
fn append_within(out: &mut String, text: &str, budget: usize) {
    let mut end = text.len().min(budget.saturating_add(1));
    while !text.is_char_boundary(end) {
        end = end.saturating_add(1);
    }
    if let Some(prefix) = text.get(..end) {
        out.push_str(prefix);
    }
}

// 逃がした後の長さで判定し、超えたら入力の残りを読まない（設計書 06-04「結果の報告」）。
fn quoted_within(chars: impl Iterator<Item = char>, quote: char, budget: usize) -> String {
    let mut out = String::new();
    out.push(quote);
    for c in chars {
        if out.len() > budget {
            return out;
        }
        escape_into(&mut out, c, quote);
    }
    if out.len() <= budget {
        out.push(quote);
    }
    out
}

fn is_list<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptyList)
        || matches!(ctx.kind(value), Some(ObjKind::Fields(FieldsKind::ListNode)))
}

fn is_map<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptyMap)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::MapNode))
}

fn is_set<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> bool {
    matches!(value, Value::EmptySet)
        || ctx.kind(value) == Some(ObjKind::Fields(FieldsKind::SetNode))
}

#[cfg(test)]
pub(crate) mod tests;

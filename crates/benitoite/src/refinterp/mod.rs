//! 参照インタプリタ（設計書 01-12「実行の規則」、02-01「検査と実行の経路」、ADR 0018）。
//!
//! コア IR を、01-12 の抽象機械 `⟨M, K⟩` の遷移の規則どおりに一歩ずつ実行する。VM と同じ
//! プログラムを実行して結果を突き合わせる差分テスト（07-03「差分テスト」）の正解として使い、
//! 利用者の経路には含めない。
//!
//! 01-12 は置き換え `M[V/x]` で意味を定めるが、ここでは環境（`VarId` から値への表）で実装する。
//! 束縛した値は変わらず、`VarId` は定義の中で重ならないので、観測できる振る舞いは置き換えと
//! 同じになる（実装プラン T19「状態」）。
//!
//! 継続 K は `Vec<Frame>` で持ち、言語の関数の呼び出しで Rust の関数を入れ子に呼ばない
//! （ADR 0016、00-02「再帰の深さ」）。どの呼び出しも枠を積まないので、末尾呼び出しで継続は
//! 伸びない（01-12「末尾呼び出しの保証」）。

use std::collections::{BTreeSet, HashMap};

use crate::base::{BindingId, Span};
use crate::builtins::BuiltinKind;
use crate::builtins::table::spec;
use crate::ir::core_ir::{
    Comp, CompKind, Const, CoreDef, CorePat, CoreProgram, Lambda, LambdaId, Val, ValKind, VarId,
};
use crate::runtime::Stop;
use crate::runtime::heap::Heap;
use crate::runtime::io::IoHandlers;
use crate::runtime::value::{FuncObj, RefCode, Value};

/// 参照インタプリタの実行の結果。
#[derive(Debug)]
pub enum RefOutcome {
    /// `main` が値を返した
    Returned(Value),
    /// 実行時エラー・資源の不足・処理系の不具合で止まった。`origin` は止まった計算の由来位置
    Stopped { stop: Stop, origin: Option<Span> },
}

/// `main` を呼ぶ状態 `⟨main[;](), []⟩` から実行する（01-12「実行の規則」）。テストだけで使う。
/// 継続は `Vec` で持ち、Rust の再帰を使わない。
pub fn run(program: &CoreProgram, io: &mut dyn IoHandlers) -> RefOutcome {
    run_counting(program, io).0
}

/// 変数の環境。添字は `VarId`、大きさは定義の `var_count`。
type Env = Vec<Option<Value>>;

/// ラムダの表の項目（実装プラン T19「状態」）。
struct LambdaInfo<'p> {
    lambda: &'p Lambda<Comp>,
    /// 本体の自由な変数。ラムダの値はこれらの値だけを写して持つ
    free: Vec<VarId>,
    /// ラムダを含む定義の `var_count`。本体を実行する環境の大きさにする
    var_count: u32,
}

/// 継続の枠。`let x ⇐ □ in N` に当たる。
struct Frame<'p> {
    var: VarId,
    body: &'p Comp,
    env: Env,
}

/// 抽象機械の今の計算。
enum Control<'p> {
    /// 計算 `M` をこの環境で実行する
    Eval(&'p Comp, Env),
    /// `return V` の `V` を求め終えた
    Ret(Value),
}

/// 遷移が止まったときの理由と、止まった計算の由来位置。
struct Halt {
    stop: Stop,
    origin: Span,
}

fn internal(message: &str, origin: Span) -> Halt {
    Halt {
        stop: Stop::Internal(String::from(message)),
        origin,
    }
}

/// 実行し、結果と、実行中の継続の最大の長さを返す。長さは末尾呼び出しの保証を確かめるのに使う。
fn run_counting(program: &CoreProgram, io: &mut dyn IoHandlers) -> (RefOutcome, usize) {
    let mut machine = Machine::new(program);
    // Heap は run の中で作る（実装プラン T19「始まりと終わり」）
    let mut heap = Heap::new();
    let outcome = match machine.execute(&mut heap, io) {
        Ok(value) => RefOutcome::Returned(value),
        Err(Some(halt)) => RefOutcome::Stopped {
            stop: halt.stop,
            origin: Some(halt.origin),
        },
        Err(None) => RefOutcome::Stopped {
            stop: Stop::Internal(String::from("main definition not found")),
            origin: None,
        },
    };
    (outcome, machine.max_frames)
}

struct Machine<'p> {
    main: BindingId,
    defs: HashMap<BindingId, &'p CoreDef>,
    lambdas: HashMap<LambdaId, LambdaInfo<'p>>,
    max_frames: usize,
}

impl<'p> Machine<'p> {
    fn new(program: &'p CoreProgram) -> Machine<'p> {
        let defs = program.defs.iter().map(|d| (d.binding, d)).collect();
        // 実行の前に、すべてのラムダの表を一度だけ作る（実装プラン T19「状態」）。
        let mut lambdas = HashMap::new();
        for def in &program.defs {
            index_comp(&def.body, def.var_count, &mut lambdas);
        }
        Machine {
            main: program.main,
            defs,
            lambdas,
            max_frames: 0,
        }
    }

    /// 一つの遷移を一回の繰り返しとして実行する。`Err(None)` は `main` が見つからないこと。
    fn execute(&mut self, heap: &mut Heap, io: &mut dyn IoHandlers) -> Result<Value, Option<Halt>> {
        let main = self.defs.get(&self.main).copied().ok_or(None)?;
        let mut control = Control::Eval(
            &main.body,
            new_env(main.var_count, main.body.origin).map_err(Some)?,
        );
        let mut stack: Vec<Frame<'p>> = Vec::new();
        loop {
            self.max_frames = self.max_frames.max(stack.len());
            control = match control {
                // E-Return: 継続が空なら終わり、そうでなければ枠を降ろして N に進む
                Control::Ret(value) => match stack.pop() {
                    None => return Ok(value),
                    Some(frame) => {
                        let mut env = frame.env;
                        set_var(&mut env, frame.var, value, frame.body.origin)?;
                        Control::Eval(frame.body, env)
                    }
                },
                Control::Eval(comp, env) => self.step(comp, env, &mut stack, heap, io)?,
            };
        }
    }

    /// 計算 `comp` の一つの遷移を行う。
    fn step(
        &self,
        comp: &'p Comp,
        mut env: Env,
        stack: &mut Vec<Frame<'p>>,
        heap: &mut Heap,
        io: &mut dyn IoHandlers,
    ) -> Result<Control<'p>, Halt> {
        let at = comp.origin;
        match &comp.kind {
            CompKind::Return(v) => Ok(Control::Ret(self.eval_val(v, &env, heap, at)?)),
            // E-Let: 枠を積み、bound に進む。bound を実行する間も N の環境を保つため写しを積む
            CompKind::Let { var, bound, body } => {
                stack.push(Frame {
                    var: var.id,
                    body,
                    env: env.clone(),
                });
                Ok(Control::Eval(bound, env))
            }
            CompKind::App { func, args } => {
                let func = self.eval_val(func, &env, heap, at)?;
                let mut arg_values = Vec::with_capacity(args.len());
                for a in args {
                    arg_values.push(self.eval_val(a, &env, heap, at)?);
                }
                self.apply(&func, arg_values, heap, io, at)
            }
            // E-IfT・E-IfF
            CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => match self.eval_val(cond, &env, heap, at)? {
                Value::Bool(true) => Ok(Control::Eval(then_branch, env)),
                Value::Bool(false) => Ok(Control::Eval(else_branch, env)),
                Value::Int(_)
                | Value::Float(_)
                | Value::Char(_)
                | Value::Unit
                | Value::Str(_)
                | Value::Func(_)
                | Value::Ctor(_)
                | Value::List(_)
                | Value::IoError(_) => Err(internal("if condition is not a Bool", at)),
            },
            // E-Match: 分岐を順に試し、最初に照合した分岐に進む
            CompKind::Match { scrutinee, arms } => {
                let value = self.eval_val(scrutinee, &env, heap, at)?;
                for arm in arms {
                    let mut binds = Vec::new();
                    let matched = matches(&arm.pattern, &value, &mut binds)
                        .map_err(|stop| Halt { stop, origin: at })?;
                    if matched {
                        for (id, v) in binds {
                            set_var(&mut env, id, v, at)?;
                        }
                        return Ok(Control::Eval(&arm.body, env));
                    }
                }
                // 網羅性は型検査が保証するので、ここに来るのは処理系の不具合である
                Err(internal("no match arm matched", at))
            }
        }
    }

    /// 関数の値を引数に適用する。どの呼び出しも継続に枠を積まない（01-12「末尾呼び出しの保証」）。
    fn apply(
        &self,
        func: &Value,
        args: Vec<Value>,
        heap: &mut Heap,
        io: &mut dyn IoHandlers,
        at: Span,
    ) -> Result<Control<'p>, Halt> {
        let Some(FuncObj::Ref {
            code,
            env: captured,
        }) = func.as_func()
        else {
            return Err(internal("applied value is not a reference function", at));
        };
        match code {
            // E-Lam: 写した値と引数を新しい環境に入れて本体に進む
            RefCode::Lambda(id) => {
                let info = self
                    .lambdas
                    .get(id)
                    .ok_or_else(|| internal("unknown lambda", at))?;
                let mut env = new_env(info.var_count, at)?;
                for (var, value) in captured {
                    set_var(&mut env, *var, value.clone(), at)?;
                }
                bind_params(&mut env, info.lambda.params.iter().map(|p| p.id), args, at)?;
                Ok(Control::Eval(&info.lambda.body, env))
            }
            // E-Fun: 型の置き換えは実行に影響しないので行わない
            RefCode::TopFn(binding) => {
                let def = self
                    .defs
                    .get(binding)
                    .ok_or_else(|| internal("unknown top-level function", at))?;
                let mut env = new_env(def.var_count, at)?;
                bind_params(&mut env, def.params.iter().map(|p| p.id), args, at)?;
                Ok(Control::Eval(&def.body, env))
            }
            // E-Prim・E-Err・E-IO・E-IOErr: VM と同じ組み込みの表の実装を呼ぶ
            RefCode::Builtin(id) => {
                let result = match spec(*id).kind {
                    BuiltinKind::Pure(f) => f(heap, &args),
                    BuiltinKind::Io(op) => io.call(op, &args, heap),
                };
                result
                    .map(Control::Ret)
                    .map_err(|stop| Halt { stop, origin: at })
            }
        }
    }

    /// 値を求める。`at` は値を含む計算の由来位置で、止まったときに使う。
    fn eval_val(&self, v: &Val<Comp>, env: &Env, heap: &mut Heap, at: Span) -> Result<Value, Halt> {
        match &v.kind {
            ValKind::Var(id) => get_var(env, *id)
                .cloned()
                .ok_or_else(|| internal("unbound variable", at)),
            ValKind::Const(c) => Ok(match c {
                Const::Int(n) => Value::Int(*n),
                Const::Float(f) => Value::Float(*f),
                Const::Str(s) => heap.string(s),
                Const::Char(ch) => Value::Char(*ch),
                Const::Bool(b) => Value::Bool(*b),
                Const::Unit => Value::Unit,
            }),
            ValKind::TopFn { def, .. } => Ok(heap.func_ref(RefCode::TopFn(*def), Vec::new())),
            ValKind::Builtin { id, .. } => Ok(heap.func_ref(RefCode::Builtin(*id), Vec::new())),
            // 自由な変数の値だけを今の環境から写す
            ValKind::Lambda(lam) => {
                let info = self
                    .lambdas
                    .get(&lam.id)
                    .ok_or_else(|| internal("unknown lambda", at))?;
                let mut captured = Vec::with_capacity(info.free.len());
                for id in &info.free {
                    let value = get_var(env, *id)
                        .cloned()
                        .ok_or_else(|| internal("unbound captured variable", at))?;
                    captured.push((*id, value));
                }
                Ok(heap.func_ref(RefCode::Lambda(lam.id), captured))
            }
            ValKind::Ctor { tag, args, .. } => {
                let mut fields = Vec::with_capacity(args.len());
                for a in args {
                    fields.push(self.eval_val(a, env, heap, at)?);
                }
                Ok(heap.ctor(*tag, fields))
            }
            ValKind::List(items) => {
                let mut values = Vec::with_capacity(items.len());
                for item in items {
                    values.push(self.eval_val(item, env, heap, at)?);
                }
                heap.list_from_vec(values, "list literal")
                    .map_err(|stop| Halt { stop, origin: at })
            }
        }
    }
}

/// 大きさ `var_count` の空の環境を作る。変換の失敗は処理系の不具合として止める（00-02「数値の変換」）。
fn new_env(var_count: u32, at: Span) -> Result<Env, Halt> {
    let len = usize::try_from(var_count)
        .map_err(|_| internal("variable count does not fit in usize", at))?;
    Ok(vec![None; len])
}

fn get_var(env: &Env, id: VarId) -> Option<&Value> {
    let index = usize::try_from(id.0).ok()?;
    env.get(index)?.as_ref()
}

fn set_var(env: &mut Env, id: VarId, value: Value, at: Span) -> Result<(), Halt> {
    let slot = usize::try_from(id.0)
        .ok()
        .and_then(|i| env.get_mut(i))
        .ok_or_else(|| internal("variable number out of range", at))?;
    *slot = Some(value);
    Ok(())
}

fn bind_params(
    env: &mut Env,
    params: impl ExactSizeIterator<Item = VarId>,
    args: Vec<Value>,
    at: Span,
) -> Result<(), Halt> {
    if params.len() != args.len() {
        return Err(internal("argument count mismatch", at));
    }
    for (id, value) in params.zip(args) {
        set_var(env, id, value, at)?;
    }
    Ok(())
}

/// 01-12 の `match(p, V)`。照合したら束縛を `binds` に加えて真を返す。
/// パターンは AST から作られ深さが抑えられているので、再帰してよい（00-02「再帰の深さ」）。
fn matches(p: &CorePat, v: &Value, binds: &mut Vec<(VarId, Value)>) -> Result<bool, Stop> {
    match p {
        CorePat::Wild => Ok(true),
        CorePat::Var(var) => {
            binds.push((var.id, v.clone()));
            Ok(true)
        }
        // 定数どうしの等しさは `==` の意味による。String は中身で比べる
        CorePat::Const(c) => match (c, v) {
            (Const::Int(a), Value::Int(b)) => Ok(a == b),
            (Const::Float(a), Value::Float(b)) => Ok(a == b),
            (Const::Char(a), Value::Char(b)) => Ok(a == b),
            (Const::Bool(a), Value::Bool(b)) => Ok(a == b),
            (Const::Unit, Value::Unit) => Ok(true),
            (Const::Str(a), Value::Str(b)) => Ok(a.as_str() == b.as_str()),
            _ => Err(Stop::Internal(String::from(
                "constant pattern and value kinds differ",
            ))),
        },
        CorePat::Ctor { tag, args, .. } => {
            let Some((vtag, fields)) = v.as_ctor() else {
                return Err(Stop::Internal(String::from(
                    "constructor pattern against a non-constructor value",
                )));
            };
            if vtag != *tag {
                return Ok(false);
            }
            if fields.len() != args.len() {
                return Err(Stop::Internal(String::from(
                    "constructor field count mismatch",
                )));
            }
            for (sub, field) in args.iter().zip(fields) {
                if !matches(sub, field, binds)? {
                    return Ok(false);
                }
            }
            Ok(true)
        }
    }
}

// ---- ラムダの表を作る。IR の深さは構文解析器の上限で抑えられるので再帰で辿る（00-02「再帰の深さ」） ----

fn index_comp<'p>(c: &'p Comp, var_count: u32, table: &mut HashMap<LambdaId, LambdaInfo<'p>>) {
    match &c.kind {
        CompKind::Return(v) => index_val(v, var_count, table),
        CompKind::Let { bound, body, .. } => {
            index_comp(bound, var_count, table);
            index_comp(body, var_count, table);
        }
        CompKind::App { func, args } => {
            index_val(func, var_count, table);
            for a in args {
                index_val(a, var_count, table);
            }
        }
        CompKind::If {
            cond,
            then_branch,
            else_branch,
        } => {
            index_val(cond, var_count, table);
            index_comp(then_branch, var_count, table);
            index_comp(else_branch, var_count, table);
        }
        CompKind::Match { scrutinee, arms } => {
            index_val(scrutinee, var_count, table);
            for arm in arms {
                index_comp(&arm.body, var_count, table);
            }
        }
    }
}

fn index_val<'p>(v: &'p Val<Comp>, var_count: u32, table: &mut HashMap<LambdaId, LambdaInfo<'p>>) {
    match &v.kind {
        ValKind::Var(_) | ValKind::Const(_) | ValKind::TopFn { .. } | ValKind::Builtin { .. } => {}
        ValKind::Lambda(lam) => {
            let mut used = BTreeSet::new();
            let mut bound: BTreeSet<VarId> = lam.params.iter().map(|p| p.id).collect();
            vars_comp(&lam.body, &mut used, &mut bound);
            let free = used.difference(&bound).copied().collect();
            table.insert(
                lam.id,
                LambdaInfo {
                    lambda: lam,
                    free,
                    var_count,
                },
            );
            index_comp(&lam.body, var_count, table);
        }
        ValKind::Ctor { args, .. } | ValKind::List(args) => {
            for a in args {
                index_val(a, var_count, table);
            }
        }
    }
}

/// 計算の中で参照する変数を `used` に、束縛する変数を `bound` に集める。
/// `VarId` は定義の中で重ならないので、自由な変数は `used` から `bound` を除いたものになる。
fn vars_comp(c: &Comp, used: &mut BTreeSet<VarId>, bound: &mut BTreeSet<VarId>) {
    match &c.kind {
        CompKind::Return(v) => vars_val(v, used, bound),
        CompKind::Let {
            var,
            bound: b,
            body,
        } => {
            bound.insert(var.id);
            vars_comp(b, used, bound);
            vars_comp(body, used, bound);
        }
        CompKind::App { func, args } => {
            vars_val(func, used, bound);
            for a in args {
                vars_val(a, used, bound);
            }
        }
        CompKind::If {
            cond,
            then_branch,
            else_branch,
        } => {
            vars_val(cond, used, bound);
            vars_comp(then_branch, used, bound);
            vars_comp(else_branch, used, bound);
        }
        CompKind::Match { scrutinee, arms } => {
            vars_val(scrutinee, used, bound);
            for arm in arms {
                pat_vars(&arm.pattern, bound);
                vars_comp(&arm.body, used, bound);
            }
        }
    }
}

fn vars_val(v: &Val<Comp>, used: &mut BTreeSet<VarId>, bound: &mut BTreeSet<VarId>) {
    match &v.kind {
        ValKind::Var(id) => {
            used.insert(*id);
        }
        ValKind::Const(_) | ValKind::TopFn { .. } | ValKind::Builtin { .. } => {}
        ValKind::Lambda(lam) => {
            bound.extend(lam.params.iter().map(|p| p.id));
            vars_comp(&lam.body, used, bound);
        }
        ValKind::Ctor { args, .. } | ValKind::List(args) => {
            for a in args {
                vars_val(a, used, bound);
            }
        }
    }
}

fn pat_vars(p: &CorePat, bound: &mut BTreeSet<VarId>) {
    match p {
        CorePat::Wild | CorePat::Const(_) => {}
        CorePat::Var(var) => {
            bound.insert(var.id);
        }
        CorePat::Ctor { args, .. } => {
            for a in args {
                pat_vars(a, bound);
            }
        }
    }
}

#[cfg(test)]
// テストの失敗は panic で表すので、これらの lint を許す（00-02「#[allow] を書いてよい箇所」）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // 入力は手で組んだコア IR とし、IO は TestIo で受ける（実装プラン T19「受け入れテスト」）。
    use std::collections::BTreeMap;

    use super::{RefOutcome, run, run_counting};
    use crate::base::{BindingId, BytePos, FileId, Span};
    use crate::builtins::BuiltinId;
    use crate::ir::core_ir::{
        Arm, Comp, CompKind, Const, CoreDef, CorePat, CoreProgram, Def, DefOrigin, Lambda,
        LambdaId, Program, Val, ValKind, Var, VarId,
    };
    use crate::runtime::io::IoEvent;
    use crate::runtime::test_io::TestIo;
    use crate::runtime::value::Value;
    use crate::runtime::{RuntimeError, Stop, Stream};
    use crate::types::{AdtTable, EffectSet, Ty, TyCon};

    const MAIN: u32 = 1;
    const F: u32 = 2;

    fn span(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n),
        }
    }

    fn v(kind: ValKind<Comp>) -> Val<Comp> {
        Val {
            kind,
            ty: Ty::int(),
            origin: span(0),
        }
    }

    fn var(n: u32) -> Var {
        Var {
            id: VarId(n),
            name: None,
            ty: Ty::int(),
        }
    }

    fn x(n: u32) -> Val<Comp> {
        v(ValKind::Var(VarId(n)))
    }

    fn int(n: i64) -> Val<Comp> {
        v(ValKind::Const(Const::Int(n)))
    }

    fn string(s: &str) -> Val<Comp> {
        v(ValKind::Const(Const::Str(String::from(s))))
    }

    fn builtin(id: BuiltinId) -> Val<Comp> {
        v(ValKind::Builtin {
            id,
            tys: vec![],
            effs: vec![],
        })
    }

    fn topfn(n: u32) -> Val<Comp> {
        v(ValKind::TopFn {
            def: BindingId(n),
            tys: vec![],
            effs: vec![],
        })
    }

    fn comp(kind: CompKind, at: u32) -> Comp {
        Comp {
            kind,
            ty: Ty::int(),
            eff: EffectSet::empty(),
            origin: span(at),
        }
    }

    fn ret(val: Val<Comp>) -> Comp {
        comp(CompKind::Return(val), 0)
    }

    fn app_at(func: Val<Comp>, args: Vec<Val<Comp>>, at: u32) -> Comp {
        comp(CompKind::App { func, args }, at)
    }

    fn app(func: Val<Comp>, args: Vec<Val<Comp>>) -> Comp {
        app_at(func, args, 0)
    }

    fn let_(n: u32, bound: Comp, body: Comp) -> Comp {
        comp(
            CompKind::Let {
                var: var(n),
                bound: Box::new(bound),
                body: Box::new(body),
            },
            0,
        )
    }

    fn if_(cond: Val<Comp>, then_branch: Comp, else_branch: Comp) -> Comp {
        comp(
            CompKind::If {
                cond,
                then_branch: Box::new(then_branch),
                else_branch: Box::new(else_branch),
            },
            0,
        )
    }

    fn match_(scrutinee: Val<Comp>, arms: Vec<(CorePat, Comp)>) -> Comp {
        let arms = arms
            .into_iter()
            .map(|(pattern, body)| Arm { pattern, body })
            .collect();
        comp(CompKind::Match { scrutinee, arms }, 0)
    }

    fn def(binding: u32, params: Vec<u32>, body: Comp, var_count: u32) -> CoreDef {
        Def {
            binding: BindingId(binding),
            name: format!("d{binding}"),
            origin: DefOrigin::User,
            type_params: vec![],
            effect_params: vec![],
            params: params.into_iter().map(var).collect(),
            ret: Ty::int(),
            eff: EffectSet::empty(),
            body,
            span: span(0),
            var_count,
        }
    }

    fn program(defs: Vec<CoreDef>) -> CoreProgram {
        Program {
            defs,
            adts: AdtTable::default(),
            main: BindingId(MAIN),
            main_returns_result: false,
            lambda_count: 1,
        }
    }

    fn run_main(body: Comp, var_count: u32, others: Vec<CoreDef>) -> (RefOutcome, TestIo) {
        let mut defs = others;
        defs.push(def(MAIN, vec![], body, var_count));
        let mut io = TestIo::new(vec![], BTreeMap::new());
        let outcome = run(&program(defs), &mut io);
        (outcome, io)
    }

    fn returned_int(outcome: &RefOutcome) -> i64 {
        match outcome {
            RefOutcome::Returned(Value::Int(n)) => *n,
            other @ (RefOutcome::Returned(_) | RefOutcome::Stopped { .. }) => {
                panic!("expected an Int result, got {other:?}")
            }
        }
    }

    #[test]
    fn main_returning_a_value_ends_with_that_value() {
        let (outcome, _) = run_main(ret(int(42)), 0, vec![]);
        assert_eq!(returned_int(&outcome), 42);
    }

    #[test]
    fn io_calls_joined_by_let_happen_in_order() {
        let body = let_(
            0,
            app(builtin(BuiltinId::ConsolePrintln), vec![string("a")]),
            app(builtin(BuiltinId::ConsolePrintln), vec![string("b")]),
        );
        let (outcome, io) = run_main(body, 1, vec![]);
        assert!(matches!(outcome, RefOutcome::Returned(Value::Unit)));
        let write = |text: &str| IoEvent::Write {
            stream: Stream::Stdout,
            text: String::from(text),
        };
        assert_eq!(io.events, vec![write("a\n"), write("b\n")]);
    }

    /// `f(n) = if n == 0 then 0 else f(n - 1)`（末尾呼び出し）。変数 0 が n。
    fn countdown() -> CoreDef {
        let body = let_(
            1,
            app(builtin(BuiltinId::Eq), vec![x(0), int(0)]),
            if_(
                x(1),
                ret(int(0)),
                let_(
                    2,
                    app(builtin(BuiltinId::SubInt), vec![x(0), int(1)]),
                    app(topfn(F), vec![x(2)]),
                ),
            ),
        );
        def(F, vec![0], body, 3)
    }

    #[test]
    fn deep_tail_recursion_does_not_grow_the_continuation() {
        let defs = vec![
            countdown(),
            def(MAIN, vec![], app(topfn(F), vec![int(1_000_000)]), 0),
        ];
        let mut io = TestIo::default();
        let (outcome, max_frames) = run_counting(&program(defs), &mut io);
        assert_eq!(returned_int(&outcome), 0);
        // 一回の呼び出しの中の let が積む枠だけで、呼び出しの回数に比例しない
        assert!(max_frames <= 1, "continuation grew to {max_frames}");
    }

    #[test]
    fn deep_non_tail_recursion_runs_without_the_rust_stack() {
        // g(n) = if n == 0 then 0 else 1 + g(n - 1)
        let body = let_(
            1,
            app(builtin(BuiltinId::Eq), vec![x(0), int(0)]),
            if_(
                x(1),
                ret(int(0)),
                let_(
                    2,
                    app(builtin(BuiltinId::SubInt), vec![x(0), int(1)]),
                    let_(
                        3,
                        app(topfn(F), vec![x(2)]),
                        app(builtin(BuiltinId::AddInt), vec![int(1), x(3)]),
                    ),
                ),
            ),
        );
        let (outcome, _) = run_main(
            app(topfn(F), vec![int(10_000)]),
            0,
            vec![def(F, vec![0], body, 4)],
        );
        assert_eq!(returned_int(&outcome), 10_000);
    }

    #[test]
    fn runtime_error_stops_at_the_application() {
        let body = app_at(builtin(BuiltinId::DivInt), vec![int(1), int(0)], 77);
        let (outcome, _) = run_main(body, 0, vec![]);
        match outcome {
            RefOutcome::Stopped { stop, origin } => {
                assert_eq!(stop, Stop::Runtime(RuntimeError::DivisionByZero));
                assert_eq!(origin, Some(span(77)));
            }
            other => panic!("expected a stop, got {other:?}"),
        }
    }

    #[test]
    fn lambda_uses_the_captured_value_when_called_elsewhere() {
        // main: let k = 10 in let f = λ(x). k + x in applyIt(f, 5)
        // applyIt(g, a) = g(a)。applyIt の環境に k はないので、捕捉した値でしか計算できない
        let lambda = v(ValKind::Lambda(Box::new(Lambda {
            id: LambdaId(0),
            params: vec![var(2)],
            body: app(builtin(BuiltinId::AddInt), vec![x(0), x(2)]),
            span: span(0),
        })));
        let body = let_(
            0,
            ret(int(10)),
            let_(1, ret(lambda), app(topfn(F), vec![x(1), int(5)])),
        );
        let apply_it = def(F, vec![0, 1], app(x(0), vec![x(1)]), 2);
        let (outcome, _) = run_main(body, 3, vec![apply_it]);
        assert_eq!(returned_int(&outcome), 15);
    }

    fn some(p: CorePat) -> CorePat {
        CorePat::Ctor {
            con: TyCon::Option,
            tag: 0,
            args: vec![p],
        }
    }

    #[test]
    fn match_selects_the_first_matching_arm() {
        let none = CorePat::Ctor {
            con: TyCon::Option,
            tag: 1,
            args: vec![],
        };
        let some_val = |n: i64| {
            v(ValKind::Ctor {
                con: TyCon::Option,
                tag: 0,
                tys: vec![],
                args: vec![int(n)],
            })
        };
        let none_val = v(ValKind::Ctor {
            con: TyCon::Option,
            tag: 1,
            tys: vec![],
            args: vec![],
        });
        for (input, expected) in [(some_val(0), 1), (some_val(5), 2), (none_val, 3)] {
            let body = let_(
                0,
                ret(input),
                match_(
                    x(0),
                    vec![
                        (some(CorePat::Const(Const::Int(0))), ret(int(1))),
                        (some(CorePat::Var(var(1))), ret(int(2))),
                        (none.clone(), ret(int(3))),
                    ],
                ),
            );
            let (outcome, _) = run_main(body, 2, vec![]);
            assert_eq!(returned_int(&outcome), expected);
        }
    }

    #[test]
    fn string_constant_patterns_compare_contents() {
        for (input, expected) in [("yes", 1), ("no", 2), ("maybe", 3)] {
            // 定数は実行のたびに別の文字列の対象になるので、中身で比べないと照合しない
            let body = let_(
                0,
                ret(string(input)),
                match_(
                    x(0),
                    vec![
                        (CorePat::Const(Const::Str(String::from("yes"))), ret(int(1))),
                        (CorePat::Const(Const::Str(String::from("no"))), ret(int(2))),
                        (CorePat::Wild, ret(int(3))),
                    ],
                ),
            );
            let (outcome, _) = run_main(body, 1, vec![]);
            assert_eq!(returned_int(&outcome), expected);
        }
    }

    #[test]
    fn failed_io_returns_an_err_value_without_stopping() {
        let body = app(
            builtin(BuiltinId::FileReadText),
            vec![string("missing.txt")],
        );
        let (outcome, io) = run_main(body, 0, vec![]);
        let RefOutcome::Returned(value) = outcome else {
            panic!("expected a value, got {outcome:?}");
        };
        let (tag, fields) = value.as_ctor().unwrap();
        assert_eq!(tag, 1);
        assert!(fields[0].as_io_error().is_some());
        assert_eq!(
            io.events,
            vec![IoEvent::ReadFile {
                path: String::from("missing.txt"),
                ok: false
            }]
        );
    }
}

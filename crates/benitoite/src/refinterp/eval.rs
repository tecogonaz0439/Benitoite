//! コア計算の遷移のループ（設計書 01-12「実行の規則」「初回リリース版の拡張」）。
//! 継続の先頭は Vec の末尾とする。言語の呼び出しは状態を置き換え、Rust の再帰を使わない。
use super::convert::{BuiltinBridge, BuiltinOutcome};
use super::value::{Closure, DictCode, FunctionCode, Value, Values};
use super::{RefOutcome, index::Index, pattern, resources};
use crate::base::{BindingId, Span};
use crate::builtins::iface::{Capability, IoServices};
use crate::builtins::table::tags;
use crate::ir::core_ir::*;
use crate::runtime::heap::ResourceId;
use crate::runtime::{ReleaseFailure, RuntimeError, Stop};
use crate::vm::MainOutcome;
use std::collections::HashMap;
use std::rc::Rc;

#[derive(Clone)]
struct Env {
    vars: Vec<Option<Value>>,
    impl_dicts: Rc<Values>,
}
impl Env {
    fn new(count: u32) -> Result<Self, Stop> {
        Ok(Self {
            vars: vec![None; usize::try_from(count).map_err(|_| fault("variable count overflow"))?],
            impl_dicts: Rc::new(Values { items: vec![] }),
        })
    }
    fn get(&self, id: VarId) -> Result<Value, Stop> {
        self.vars
            .get(number(id.0)?)
            .and_then(Option::as_ref)
            .cloned()
            .ok_or_else(|| fault("unbound variable"))
    }
    fn set(&mut self, id: VarId, v: Value) -> Result<(), Stop> {
        *self
            .vars
            .get_mut(number(id.0)?)
            .ok_or_else(|| fault("variable out of range"))? = Some(v);
        Ok(())
    }
    fn bind(
        &mut self,
        params: impl ExactSizeIterator<Item = VarId>,
        values: Vec<Value>,
    ) -> Result<(), Stop> {
        if params.len() != values.len() {
            return Err(fault("argument count mismatch"));
        }
        for (id, v) in params.zip(values) {
            self.set(id, v)?;
        }
        Ok(())
    }
}
#[derive(Clone)]
struct MatchState<'p> {
    value: Value,
    rows: &'p [MatchRow],
    arms: &'p [MatchArm],
    next: usize,
    env: Env,
    origin: Span,
}
#[derive(Clone)]
enum Frame<'p> {
    Let {
        var: VarId,
        body: &'p Comp,
        env: Env,
    },
    Mark,
    Update(usize),
    SetReference(usize),
    Release(ResourceId, Span),
    Handle {
        handle: &'p Handle<Comp>,
        env: Env,
    },
    Drop(usize),
    Guard {
        body: &'p Comp,
        env: Env,
        retry: MatchState<'p>,
    },
    Constant(BindingId),
}
enum Store<'p> {
    Cell(Value),
    Thunk { id: BodyId, env: Env },
    Done(Value),
    Cont(Vec<Frame<'p>>),
    Used,
}
struct Halt {
    stop: Stop,
    origin: Option<Span>,
    release_failures: Vec<ReleaseFailure>,
}
enum State<'p> {
    Eval(&'p Comp, Env),
    Apply {
        func: Value,
        dicts: Vec<Value>,
        args: Vec<Value>,
        origin: Span,
    },
    Method {
        dict: Value,
        method: u32,
        dicts: Vec<Value>,
        args: Vec<Value>,
        origin: Span,
    },
    Match(MatchState<'p>),
    Return(Value),
    Escape(Value),
    Error(Halt),
    Exit(u8, Vec<ReleaseFailure>),
    End(RefOutcome),
}
impl State<'_> {
    fn origin(&self) -> Option<Span> {
        match self {
            Self::Eval(c, _) => Some(c.origin),
            Self::Apply { origin, .. } | Self::Method { origin, .. } => Some(*origin),
            Self::Match(m) => Some(m.origin),
            Self::Error(h) => h.origin,
            Self::Return(_) | Self::Escape(_) | Self::Exit(..) | Self::End(_) => None,
        }
    }
}
pub(super) struct Machine<'p> {
    program: &'p CoreProgram,
    index: Index<'p>,
    stack: Vec<Frame<'p>>,
    store: Vec<Store<'p>>,
    constants: HashMap<BindingId, Value>,
    next_constant: usize,
    pub(super) bridge: BuiltinBridge,
    #[cfg(test)]
    pub(super) max_frames: usize,
    #[cfg(test)]
    pub(super) updates: usize,
}
impl<'p> Machine<'p> {
    pub fn new(program: &'p CoreProgram) -> Result<Self, Stop> {
        Ok(Self {
            program,
            index: Index::new(program)?,
            stack: vec![],
            store: vec![],
            constants: HashMap::new(),
            next_constant: 0,
            bridge: BuiltinBridge::new(),
            #[cfg(test)]
            max_frames: 0,
            #[cfg(test)]
            updates: 0,
        })
    }
    pub fn run(&mut self, io: &mut dyn IoServices) -> RefOutcome {
        if self.program.main.is_none() {
            return stopped(fault("program has no main"), None);
        }
        let mut state = self.start().unwrap_or_else(|s| error(s, None));
        loop {
            #[cfg(test)]
            {
                self.max_frames = self.max_frames.max(self.stack.len());
            }
            if let State::End(outcome) = state {
                return outcome;
            }
            let at = state.origin();
            state = self.step(state, io).unwrap_or_else(|s| error(s, at));
        }
    }
    fn start(&mut self) -> Result<State<'p>, Stop> {
        if let Some(def) = self.index.constants.get(self.next_constant) {
            self.next_constant = self
                .next_constant
                .checked_add(1)
                .ok_or_else(|| fault("constant index overflow"))?;
            self.stack.push(Frame::Constant(def.binding));
            return Ok(State::Eval(&def.body, Env::new(def.var_count)?));
        }
        self.enter_def(
            *self
                .index
                .defs
                .get(
                    &self
                        .program
                        .main
                        .ok_or_else(|| fault("program has no main"))?,
                )
                .ok_or_else(|| fault("main definition missing"))?,
            vec![],
            vec![],
            Rc::new(Values { items: vec![] }),
        )
    }
    fn mark(&mut self) {
        if !matches!(self.stack.last(), Some(Frame::Mark)) {
            self.stack.push(Frame::Mark);
        }
    }
    fn enter_def(
        &mut self,
        def: &'p CoreDef,
        dicts: Vec<Value>,
        args: Vec<Value>,
        impl_dicts: Rc<Values>,
    ) -> Result<State<'p>, Stop> {
        let mut env = Env::new(def.var_count)?;
        env.impl_dicts = impl_dicts;
        env.bind(def.dict_params.iter().map(|d| d.var), dicts)?;
        env.bind(def.params.iter().map(|p| p.id), args)?;
        self.mark();
        Ok(State::Eval(&def.body, env))
    }
    fn value(&self, v: &CoreVal, env: &Env) -> Result<Value, Stop> {
        match &v.kind {
            ValKind::Var(id) => env.get(*id),
            ValKind::Const(c) => Ok(pattern::constant(c)),
            ValKind::ConstRef(id) => self
                .constants
                .get(id)
                .cloned()
                .ok_or_else(|| fault("constant has not been evaluated")),
            ValKind::TopFn { def, .. } => Ok(function(
                FunctionCode::TopFn(*def),
                vec![],
                Rc::new(Values { items: vec![] }),
            )),
            ValKind::Builtin { id, info, .. } => Ok(function(
                FunctionCode::Builtin(*id, *info),
                vec![],
                Rc::new(Values { items: vec![] }),
            )),
            ValKind::Op { op, .. } => Ok(function(
                FunctionCode::Op(*op),
                vec![],
                Rc::new(Values { items: vec![] }),
            )),
            ValKind::Lambda(l) => {
                let body = self
                    .index
                    .bodies
                    .get(&l.id)
                    .ok_or_else(|| fault("lambda body missing"))?;
                let captures = body
                    .free
                    .iter()
                    .map(|id| Ok((*id, env.get(*id)?)))
                    .collect::<Result<Vec<_>, Stop>>()?;
                Ok(function(
                    FunctionCode::Body(l.id),
                    captures,
                    Rc::clone(&env.impl_dicts),
                ))
            }
            ValKind::Ctor { tag, args, .. } => Ok(Value::ctor(*tag, self.values(args, env)?)),
            ValKind::List(items) => {
                crate::runtime::heap::CheckedLen::elements(
                    u64::try_from(items.len()).map_err(|_| fault("list size overflow"))?,
                    "list literal",
                )?;
                Ok(Value::list(self.values(items, env)?))
            }
        }
    }
    fn values(&self, vs: &[CoreVal], env: &Env) -> Result<Vec<Value>, Stop> {
        vs.iter().map(|v| self.value(v, env)).collect()
    }
    fn dict(&self, d: &DictVal, env: &Env) -> Result<Value, Stop> {
        match &d.kind {
            DictKind::Param(id) => env.get(*id),
            DictKind::ImplParam(n) => env
                .impl_dicts
                .items
                .get(number(*n)?)
                .cloned()
                .ok_or_else(|| fault("implementation dictionary missing")),
            DictKind::Impl {
                impl_decl, args, ..
            } => Ok(Value::Dict {
                code: DictCode::Impl(*impl_decl),
                args: Rc::new(Values {
                    items: self.dicts(args, env)?,
                }),
            }),
            // V-Super は値の形を残す。上位の実装の循環を E-Super の遷移で扱う（設計書 01-12「型クラス」）。
            DictKind::Super { of, index } => Ok(Value::Dict {
                code: DictCode::Super(*index),
                args: Rc::new(Values {
                    items: vec![self.dict(of, env)?],
                }),
            }),
        }
    }
    fn dicts(&self, ds: &[DictVal], env: &Env) -> Result<Vec<Value>, Stop> {
        ds.iter().map(|d| self.dict(d, env)).collect()
    }
    fn super_step(&self, dict: Value) -> Result<Value, Stop> {
        let mut current = dict;
        let mut path = vec![];
        loop {
            let Value::Dict { code, args } = &current else {
                return Err(fault("method dictionary is not a dictionary"));
            };
            match code {
                DictCode::Super(n) => {
                    path.push(*n);
                    current = args
                        .items
                        .first()
                        .cloned()
                        .ok_or_else(|| fault("super dictionary missing"))?;
                }
                DictCode::Impl(id) => {
                    let implementation = self
                        .program
                        .impls
                        .iter()
                        .find(|i| i.impl_decl == *id)
                        .ok_or_else(|| fault("implementation missing"))?;
                    let index = path
                        .pop()
                        .ok_or_else(|| fault("super projection missing"))?;
                    let projection = implementation
                        .supers
                        .get(number(index)?)
                        .ok_or_else(|| fault("super projection out of range"))?;
                    let env = Env {
                        vars: vec![],
                        impl_dicts: Rc::clone(args),
                    };
                    current = self.dict(projection, &env)?;
                    break;
                }
            }
        }
        while let Some(n) = path.pop() {
            current = Value::Dict {
                code: DictCode::Super(n),
                args: Rc::new(Values {
                    items: vec![current],
                }),
            };
        }
        Ok(current)
    }
    fn allocate(&mut self, value: Store<'p>) -> usize {
        let n = self.store.len();
        self.store.push(value);
        n
    }
    fn location(&self, v: &Value) -> Result<usize, Stop> {
        if let Value::Location(n) = v {
            Ok(*n)
        } else {
            Err(fault("expected store location"))
        }
    }
    fn drop_cont(&mut self, n: usize) -> Result<(), Stop> {
        let entry = self
            .store
            .get_mut(n)
            .ok_or_else(|| fault("continuation location missing"))?;
        // releases(K') の順序は Vec の順を保つ。pop は内側の枠を先に取り出す（設計書 01-12「ハンドラ」）。
        match std::mem::replace(entry, Store::Used) {
            Store::Cont(frames) => self.stack.extend(
                frames
                    .into_iter()
                    .filter(|f| matches!(f, Frame::Release(..) | Frame::Drop(_))),
            ),
            Store::Used => {}
            Store::Cell(_) | Store::Thunk { .. } | Store::Done(_) => {
                return Err(fault("drop of non-continuation"));
            }
        }
        Ok(())
    }
    fn operation(&mut self, op: BindingId, args: Vec<Value>) -> Result<Option<State<'p>>, Stop> {
        let found = self
            .stack
            .iter()
            .enumerate()
            .rev()
            .find_map(|(n, f)| match f {
                Frame::Handle { handle, env } => handle
                    .clauses
                    .iter()
                    .find(|c| c.op == op)
                    .map(|c| (n, c, env.clone())),
                Frame::Let { .. }
                | Frame::Mark
                | Frame::Update(_)
                | Frame::SetReference(_)
                | Frame::Release(..)
                | Frame::Drop(_)
                | Frame::Guard { .. }
                | Frame::Constant(_) => None,
            });
        let Some((n, clause, mut env)) = found else {
            return Ok(None);
        };
        // 枠の写しには該当する handle 自体も含めるので、再開後にも同じ節を使う（E-Op）。
        let captured = self
            .stack
            .get(n..)
            .ok_or_else(|| fault("handler stack range"))?
            .to_vec();
        self.stack.truncate(n);
        let location = self.allocate(Store::Cont(captured));
        self.stack.push(Frame::Drop(location));
        env.bind(clause.params.iter().map(|p| p.id), args)?;
        env.set(clause.cont.id, Value::Location(location))?;
        let body = self
            .index
            .bodies
            .get(&clause.id)
            .ok_or_else(|| fault("clause body missing"))?;
        Ok(Some(State::Eval(body.body, env)))
    }
    fn step(&mut self, state: State<'p>, io: &mut dyn IoServices) -> Result<State<'p>, Stop> {
        match state {
            State::Eval(comp, env) => match &comp.kind {
                CompKind::Return(v) => Ok(State::Return(self.value(v, &env)?)),
                CompKind::Escape(v) => Ok(State::Escape(self.value(v, &env)?)),
                CompKind::Let { var, bound, body } => {
                    self.stack.push(Frame::Let {
                        var: var.id,
                        body,
                        env: env.clone(),
                    });
                    Ok(State::Eval(bound, env))
                }
                CompKind::App { func, dicts, args } => Ok(State::Apply {
                    func: self.value(func, &env)?,
                    dicts: self.dicts(dicts, &env)?,
                    args: self.values(args, &env)?,
                    origin: comp.origin,
                }),
                CompKind::Method(m) => Ok(State::Method {
                    dict: self.dict(&m.dict, &env)?,
                    method: m.method,
                    dicts: self.dicts(&m.dicts, &env)?,
                    args: self.values(&m.args, &env)?,
                    origin: comp.origin,
                }),
                CompKind::If {
                    cond,
                    then_branch,
                    else_branch,
                } => match self.value(cond, &env)? {
                    Value::Bool(true) => Ok(State::Eval(then_branch, env)),
                    Value::Bool(false) => Ok(State::Eval(else_branch, env)),
                    Value::Decimal(_)
                    | Value::Location(_)
                    | Value::Resource(_)
                    | Value::Opaque(_)
                    | Value::Dict { .. }
                    | Value::Map(_)
                    | Value::Set(_)
                    | Value::Int(_)
                    | Value::Float(_)
                    | Value::Byte(_)
                    | Value::Char(_)
                    | Value::Unit
                    | Value::Str(_)
                    | Value::Bytes(_)
                    | Value::Ctor { .. }
                    | Value::List(_)
                    | Value::Func(_)
                    | Value::IoError { .. } => Err(fault("non-boolean condition")),
                },
                CompKind::Match {
                    scrutinee,
                    rows,
                    arms,
                } => Ok(State::Match(MatchState {
                    value: self.value(scrutinee, &env)?,
                    rows,
                    arms,
                    next: 0,
                    env,
                    origin: comp.origin,
                })),
                CompKind::Use { resource, body } => {
                    let Value::Resource(id) = self.value(resource, &env)? else {
                        return Err(fault("use of non-resource"));
                    };
                    self.stack.push(Frame::Release(id, comp.origin));
                    Ok(State::Eval(body, env))
                }
                CompKind::Lazy { id, .. } => {
                    let info = self
                        .index
                        .bodies
                        .get(id)
                        .ok_or_else(|| fault("lazy body missing"))?;
                    let mut captured = Env::new(info.var_count)?;
                    captured.impl_dicts = Rc::clone(&env.impl_dicts);
                    for id in &info.free {
                        captured.set(*id, env.get(*id)?)?;
                    }
                    let n = self.allocate(Store::Thunk {
                        id: *id,
                        env: captured,
                    });
                    Ok(State::Return(Value::Location(n)))
                }
                CompKind::Handle(h) => {
                    self.stack.push(Frame::Handle {
                        handle: h,
                        env: env.clone(),
                    });
                    Ok(State::Eval(
                        self.index
                            .bodies
                            .get(&h.id)
                            .ok_or_else(|| fault("handler body missing"))?
                            .body,
                        env,
                    ))
                }
                CompKind::Resume { cont, value } => {
                    let n = self.location(&env.get(*cont)?)?;
                    let v = self.value(value, &env)?;
                    let entry = self
                        .store
                        .get_mut(n)
                        .ok_or_else(|| fault("resume location missing"))?;
                    match std::mem::replace(entry, Store::Used) {
                        Store::Cont(frames) => {
                            self.stack.extend(frames);
                            Ok(State::Return(v))
                        }
                        Store::Used => Ok(error(
                            Stop::Runtime(RuntimeError::ContinuationResumedTwice),
                            Some(comp.origin),
                        )),
                        Store::Cell(_) | Store::Thunk { .. } | Store::Done(_) => {
                            Err(fault("resume of non-continuation"))
                        }
                    }
                }
            },
            State::Apply {
                func,
                dicts,
                args,
                origin,
            } => {
                let Value::Func(closure) = func else {
                    return Err(fault("application of non-function"));
                };
                match closure.code {
                    FunctionCode::TopFn(id) => self.enter_def(
                        *self
                            .index
                            .defs
                            .get(&id)
                            .ok_or_else(|| fault("function definition missing"))?,
                        dicts,
                        args,
                        Rc::clone(&closure.impl_dicts),
                    ),
                    FunctionCode::Body(id) => {
                        if !dicts.is_empty() {
                            return Err(fault("lambda received dictionaries"));
                        }
                        let info = self
                            .index
                            .bodies
                            .get(&id)
                            .ok_or_else(|| fault("lambda body missing"))?;
                        let mut env = Env::new(info.var_count)?;
                        env.impl_dicts = Rc::clone(&closure.impl_dicts);
                        for (id, v) in &closure.captures {
                            env.set(*id, v.clone())?;
                        }
                        env.bind(info.params.iter().map(|p| p.id), args)?;
                        let body = info.body;
                        self.mark();
                        Ok(State::Eval(body, env))
                    }
                    FunctionCode::Op(op) => self
                        .operation(op, args)?
                        .ok_or_else(|| fault("unhandled user operation")),
                    FunctionCode::Builtin(id, info) => self.builtin(id, info, args, origin, io),
                }
            }
            State::Method {
                dict,
                method,
                dicts,
                args,
                origin,
            } => {
                let Value::Dict {
                    code,
                    args: impl_dicts,
                } = &dict
                else {
                    return Err(fault("method receiver is not dictionary"));
                };
                match code {
                    DictCode::Super(_) => Ok(State::Method {
                        dict: self.super_step(dict)?,
                        method,
                        dicts,
                        args,
                        origin,
                    }),
                    DictCode::Impl(id) => {
                        let imp = self
                            .program
                            .impls
                            .iter()
                            .find(|i| i.impl_decl == *id)
                            .ok_or_else(|| fault("method implementation missing"))?;
                        let def = imp
                            .methods
                            .get(number(method)?)
                            .ok_or_else(|| fault("method index out of range"))?;
                        self.enter_def(def, dicts, args, Rc::clone(impl_dicts))
                    }
                }
            }
            State::Match(mut m) => {
                for (n, row) in m.rows.iter().enumerate().skip(m.next) {
                    let mut binds = vec![];
                    if !pattern::matches(&row.pattern, &m.value, &mut binds)? {
                        continue;
                    }
                    let arm = m
                        .arms
                        .get(number(row.arm)?)
                        .ok_or_else(|| fault("match arm missing"))?;
                    let mut env = m.env.clone();
                    for (id, v) in binds {
                        env.set(id, v)?;
                    }
                    if let Some(guard) = &arm.guard {
                        m.next = m
                            .rows
                            .iter()
                            .enumerate()
                            .skip(n)
                            .find(|(_, r)| r.arm != row.arm)
                            .map_or(m.rows.len(), |(n, _)| n);
                        self.stack.push(Frame::Guard {
                            body: &arm.body,
                            env: env.clone(),
                            retry: m,
                        });
                        return Ok(State::Eval(guard, env));
                    }
                    return Ok(State::Eval(&arm.body, env));
                }
                Err(fault("non-exhaustive core match"))
            }
            State::Return(v) => {
                let Some(frame) = self.stack.pop() else {
                    return Ok(State::End(self.finish(v)?));
                };
                match frame {
                    Frame::Let { var, body, mut env } => {
                        env.set(var, v)?;
                        Ok(State::Eval(body, env))
                    }
                    Frame::Mark | Frame::Handle { .. } => Ok(State::Return(v)),
                    Frame::Update(n) => {
                        *self
                            .store
                            .get_mut(n)
                            .ok_or_else(|| fault("lazy update missing"))? = Store::Done(v.clone());
                        #[cfg(test)]
                        {
                            self.updates = self.updates.saturating_add(1);
                        }
                        Ok(State::Return(v))
                    }
                    Frame::SetReference(n) => {
                        self.set_cell(n, v)?;
                        Ok(State::Return(Value::Unit))
                    }
                    Frame::Release(id, origin) => Ok(match self.release(id) {
                        Ok(()) => State::Return(v),
                        Err(s) => error(s, Some(origin)),
                    }),
                    Frame::Drop(n) => {
                        self.drop_cont(n)?;
                        Ok(State::Return(v))
                    }
                    Frame::Guard { body, env, retry } => match v {
                        Value::Bool(true) => Ok(State::Eval(body, env)),
                        Value::Bool(false) => Ok(State::Match(retry)),
                        Value::Decimal(_)
                        | Value::Location(_)
                        | Value::Resource(_)
                        | Value::Opaque(_)
                        | Value::Dict { .. }
                        | Value::Map(_)
                        | Value::Set(_)
                        | Value::Int(_)
                        | Value::Float(_)
                        | Value::Byte(_)
                        | Value::Char(_)
                        | Value::Unit
                        | Value::Str(_)
                        | Value::Bytes(_)
                        | Value::Ctor { .. }
                        | Value::List(_)
                        | Value::Func(_)
                        | Value::IoError { .. } => Err(fault("non-boolean match guard")),
                    },
                    Frame::Constant(id) => {
                        self.constants.insert(id, v);
                        self.start()
                    }
                }
            }
            State::Escape(v) => {
                let frame = self
                    .stack
                    .pop()
                    .ok_or_else(|| fault("escape outside function boundary"))?;
                match frame {
                    Frame::Mark => Ok(State::Return(v)),
                    Frame::Release(id, origin) => Ok(match self.release(id) {
                        Ok(()) => State::Escape(v),
                        Err(s) => error(s, Some(origin)),
                    }),
                    Frame::Drop(n) => {
                        self.drop_cont(n)?;
                        Ok(State::Escape(v))
                    }
                    Frame::Let { .. }
                    | Frame::Update(_)
                    | Frame::SetReference(_)
                    | Frame::Handle { .. }
                    | Frame::Guard { .. }
                    | Frame::Constant(_) => Ok(State::Escape(v)),
                }
            }
            State::Error(mut h) => {
                let Some(frame) = self.stack.pop() else {
                    return Ok(State::End(RefOutcome::Stopped {
                        stop: h.stop,
                        origin: h.origin,
                        release_failures: h.release_failures,
                    }));
                };
                self.unwind(frame, &mut h.release_failures)?;
                Ok(State::Error(h))
            }
            State::Exit(status, mut failures) => {
                let Some(frame) = self.stack.pop() else {
                    return Ok(State::End(RefOutcome::Exited {
                        status,
                        release_failures: failures,
                    }));
                };
                self.unwind(frame, &mut failures)?;
                Ok(State::Exit(status, failures))
            }
            State::End(outcome) => Ok(State::End(outcome)),
        }
    }
    fn builtin(
        &mut self,
        id: crate::builtins::BuiltinId,
        info: BuiltinInfo,
        args: Vec<Value>,
        origin: Span,
        io: &mut dyn IoServices,
    ) -> Result<State<'p>, Stop> {
        let decl = self
            .bridge
            .declaration(id)
            .ok_or_else(|| fault("unknown builtin"))?;
        if decl.name.starts_with("Task.") || decl.name.starts_with("TaskGroup.") {
            return Ok(State::End(RefOutcome::Unsupported(decl.name.into())));
        }
        if usize::from(decl.arity) != args.len() {
            return Err(fault("builtin arity mismatch"));
        }
        if info.class == Capability::Io
            && let Some(op) = info.op
            && let Some(state) = self.operation(op, args.clone())?
        {
            return Ok(state);
        }
        match info.intrinsic {
            Some(Intrinsic::Force) => {
                let n = self.location(
                    args.first()
                        .ok_or_else(|| fault("force argument missing"))?,
                )?;
                match self
                    .store
                    .get(n)
                    .ok_or_else(|| fault("lazy location missing"))?
                {
                    Store::Done(v) => Ok(State::Return(v.clone())),
                    Store::Thunk { id, env } => {
                        let body = self
                            .index
                            .bodies
                            .get(id)
                            .ok_or_else(|| fault("lazy body missing"))?
                            .body;
                        let env = env.clone();
                        self.stack.push(Frame::Update(n));
                        Ok(State::Eval(body, env))
                    }
                    Store::Cell(_) | Store::Cont(_) | Store::Used => {
                        Err(fault("force of non-lazy location"))
                    }
                }
            }
            Some(Intrinsic::Update) => {
                let n = self.location(
                    args.first()
                        .ok_or_else(|| fault("update reference missing"))?,
                )?;
                let value = self.cell(n)?;
                let func = args
                    .get(1)
                    .cloned()
                    .ok_or_else(|| fault("update function missing"))?;
                self.stack.push(Frame::SetReference(n));
                Ok(State::Apply {
                    func,
                    dicts: vec![],
                    args: vec![value],
                    origin,
                })
            }
            None | Some(Intrinsic::Operator { .. } | Intrinsic::Eq | Intrinsic::Ne) => match decl
                .name
            {
                "Reference.new" => {
                    let n = self.allocate(Store::Cell(
                        args.first()
                            .cloned()
                            .ok_or_else(|| fault("new value missing"))?,
                    ));
                    Ok(State::Return(Value::Location(n)))
                }
                "Reference.get" => Ok(State::Return(self.cell(
                    self.location(args.first().ok_or_else(|| fault("get reference missing"))?)?,
                )?)),
                "Reference.set" => {
                    let n =
                        self.location(args.first().ok_or_else(|| fault("set reference missing"))?)?;
                    self.set_cell(
                        n,
                        args.get(1)
                            .cloned()
                            .ok_or_else(|| fault("set value missing"))?,
                    )?;
                    Ok(State::Return(Value::Unit))
                }
                _ => {
                    let mut state = resources::State {
                        resources: Rc::clone(&self.bridge.resources),
                    };
                    Ok(match self.bridge.call(id, &args, io, Some(&mut state)) {
                        BuiltinOutcome::Done(v) => State::Return(v),
                        BuiltinOutcome::Stopped(s) => error(s, Some(origin)),
                        BuiltinOutcome::Exited(n) => State::Exit(n, vec![]),
                        BuiltinOutcome::Unsupported(name) => {
                            State::End(RefOutcome::Unsupported(name))
                        }
                    })
                }
            },
        }
    }
    fn cell(&self, n: usize) -> Result<Value, Stop> {
        match self.store.get(n) {
            Some(Store::Cell(v)) => Ok(v.clone()),
            _ => Err(fault("invalid reference cell")),
        }
    }
    fn set_cell(&mut self, n: usize, v: Value) -> Result<(), Stop> {
        match self.store.get_mut(n) {
            Some(Store::Cell(old)) => {
                *old = v;
                Ok(())
            }
            _ => Err(fault("invalid reference cell")),
        }
    }
    fn release(&mut self, id: ResourceId) -> Result<(), Stop> {
        self.bridge
            .resources
            .try_borrow_mut()
            .map_err(|_| resources::fault())?
            .release(id)
    }
    fn unwind(&mut self, frame: Frame<'p>, failures: &mut Vec<ReleaseFailure>) -> Result<(), Stop> {
        match frame {
            Frame::Release(id, _) => match self.release(id) {
                Ok(()) => {}
                Err(Stop::Runtime(RuntimeError::ReleaseFailed(mut fs))) => failures.append(&mut fs),
                Err(s) => return Err(s),
            },
            Frame::Drop(n) => self.drop_cont(n)?,
            Frame::Let { .. }
            | Frame::Mark
            | Frame::Update(_)
            | Frame::SetReference(_)
            | Frame::Handle { .. }
            | Frame::Guard { .. }
            | Frame::Constant(_) => {}
        }
        Ok(())
    }
    fn finish(&self, v: Value) -> Result<RefOutcome, Stop> {
        if !self.program.main_returns_result {
            return Ok(RefOutcome::Finished(MainOutcome::Ok));
        }
        let Value::Ctor { tag, args } = v else {
            return Err(fault("main did not return Result"));
        };
        if args.items.len() != 1 {
            return Err(fault("main Result arity"));
        }
        Ok(RefOutcome::Finished(match (tag, args.items.first()) {
            (tags::RESULT_OK, Some(Value::Unit)) => MainOutcome::Ok,
            (tags::RESULT_ERROR, Some(Value::Str(message))) => {
                MainOutcome::Error(message.to_string())
            }
            _ => return Err(fault("main Result payload")),
        }))
    }
}
fn function(code: FunctionCode, captures: Vec<(VarId, Value)>, impl_dicts: Rc<Values>) -> Value {
    Value::Func(Rc::new(Closure {
        code,
        captures,
        impl_dicts,
    }))
}
fn number(n: u32) -> Result<usize, Stop> {
    usize::try_from(n).map_err(|_| fault("index does not fit usize"))
}
fn fault(message: &str) -> Stop {
    Stop::Internal(message.into())
}
fn error<'p>(stop: Stop, origin: Option<Span>) -> State<'p> {
    State::Error(Halt {
        stop,
        origin,
        release_failures: vec![],
    })
}
pub(super) fn stopped(stop: Stop, origin: Option<Span>) -> RefOutcome {
    RefOutcome::Stopped {
        stop,
        origin,
        release_failures: vec![],
    }
}

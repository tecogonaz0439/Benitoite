//! 捕捉と再利用のための変数の走査（設計書 02-07「関数の値と捕捉」「その場での再利用」）。

use super::*;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub(super) enum Key {
    Var(VarId),
    ImplParam(u32),
}

#[derive(Clone, Copy)]
pub(super) enum Node<'a> {
    Comp(&'a LComp),
    Val(&'a LowVal),
    Dict(&'a DictVal),
    Ref(Key),
}

enum Work<'a> {
    Node(Node<'a>),
    Bind(Vec<Key>),
    Unbind(Vec<Key>),
}

// ガードを写した兄弟の分岐で同じ番号を束縛できるよう、走査も束縛の有効範囲を持つ（F15）。
pub(super) fn free_keys(root: Node<'_>, bound: Vec<Key>) -> Vec<Key> {
    let mut scope: HashMap<Key, usize> = bound.into_iter().map(|k| (k, 1)).collect();
    let mut work = vec![Work::Node(root)];
    let mut seen = HashSet::new();
    let mut free = Vec::new();
    while let Some(item) = work.pop() {
        match item {
            Work::Bind(keys) => {
                for key in keys {
                    let n = scope.entry(key).or_default();
                    *n = n.saturating_add(1);
                }
            }
            Work::Unbind(keys) => {
                for key in keys {
                    if let Some(n) = scope.get_mut(&key) {
                        *n = n.saturating_sub(1);
                    }
                }
            }
            Work::Node(Node::Ref(key)) => {
                if scope.get(&key).copied().unwrap_or(0) == 0 && seen.insert(key) {
                    free.push(key);
                }
            }
            Work::Node(node) => expand(node, &mut work),
        }
    }
    free
}

fn scoped<'a>(work: &mut Vec<Work<'a>>, body: &'a LComp, keys: Vec<Key>) {
    work.push(Work::Unbind(keys.clone()));
    work.push(Work::Node(Node::Comp(body)));
    work.push(Work::Bind(keys));
}

fn vals<'a>(work: &mut Vec<Work<'a>>, values: &'a [LowVal]) {
    for v in values.iter().rev() {
        work.push(Work::Node(Node::Val(v)));
    }
}
fn dicts<'a>(work: &mut Vec<Work<'a>>, values: &'a [DictVal]) {
    for v in values.iter().rev() {
        work.push(Work::Node(Node::Dict(v)));
    }
}

fn expand<'a>(node: Node<'a>, work: &mut Vec<Work<'a>>) {
    match node {
        Node::Ref(_) => {}
        Node::Dict(d) => match &d.kind {
            DictKind::Param(x) => work.push(Work::Node(Node::Ref(Key::Var(*x)))),
            DictKind::ImplParam(i) => work.push(Work::Node(Node::Ref(Key::ImplParam(*i)))),
            DictKind::Super { of, .. } => work.push(Work::Node(Node::Dict(of))),
            DictKind::Impl { args, .. } => dicts(work, args),
        },
        Node::Val(v) => match &v.kind {
            ValKind::Var(x) => work.push(Work::Node(Node::Ref(Key::Var(*x)))),
            ValKind::Lambda(l) => scoped(
                work,
                &l.body,
                l.params.iter().map(|p| Key::Var(p.id)).collect(),
            ),
            ValKind::Ctor { args, .. } | ValKind::List(args) => vals(work, args),
            ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::Op { .. }
            | ValKind::ConstRef(_) => {}
        },
        Node::Comp(c) => match &c.kind {
            LCompKind::Return(v) | LCompKind::Escape(v) => work.push(Work::Node(Node::Val(v))),
            LCompKind::Let { var, bound, body } => {
                scoped(work, body, vec![Key::Var(var.id)]);
                work.push(Work::Node(Node::Comp(bound)));
            }
            LCompKind::App {
                func,
                dicts: ds,
                args,
            } => {
                vals(work, args);
                dicts(work, ds);
                work.push(Work::Node(Node::Val(func)));
            }
            LCompKind::Method(m) => {
                vals(work, &m.args);
                dicts(work, &m.dicts);
                work.push(Work::Node(Node::Dict(&m.dict)));
            }
            LCompKind::If {
                cond,
                then_branch,
                else_branch,
            } => {
                work.push(Work::Node(Node::Comp(else_branch)));
                work.push(Work::Node(Node::Comp(then_branch)));
                work.push(Work::Node(Node::Val(cond)));
            }
            LCompKind::CaseCtor {
                scrutinee,
                arms,
                default,
                ..
            } => {
                if let Some(d) = default {
                    work.push(Work::Node(Node::Comp(d)));
                }
                for arm in arms.iter().rev() {
                    scoped(
                        work,
                        &arm.body,
                        arm.fields.iter().map(|p| Key::Var(p.id)).collect(),
                    );
                }
                work.push(Work::Node(Node::Val(scrutinee)));
            }
            LCompKind::CaseConst {
                scrutinee,
                arms,
                default,
            } => {
                if let Some(d) = default {
                    work.push(Work::Node(Node::Comp(d)));
                }
                for arm in arms.iter().rev() {
                    work.push(Work::Node(Node::Comp(&arm.body)));
                }
                work.push(Work::Node(Node::Val(scrutinee)));
            }
            LCompKind::CaseLength {
                scrutinee,
                exact,
                otherwise,
                ..
            } => {
                work.push(Work::Node(Node::Comp(otherwise)));
                for arm in exact.iter().rev() {
                    work.push(Work::Node(Node::Comp(&arm.body)));
                }
                work.push(Work::Node(Node::Val(scrutinee)));
            }
            LCompKind::ListGet { list, .. } | LCompKind::ListSlice { list, .. } => {
                work.push(Work::Node(Node::Val(list)))
            }
            LCompKind::Join {
                params,
                handler,
                body,
                ..
            } => {
                scoped(
                    work,
                    handler,
                    params.iter().map(|p| Key::Var(p.id)).collect(),
                );
                work.push(Work::Node(Node::Comp(body)));
            }
            LCompKind::Jump { args, .. } => vals(work, args),
            LCompKind::Use { resource, body } => {
                work.push(Work::Node(Node::Comp(body)));
                work.push(Work::Node(Node::Val(resource)));
            }
            LCompKind::Lazy { body, .. } => work.push(Work::Node(Node::Comp(body))),
            LCompKind::Handle(h) => {
                for cl in h.clauses.iter().rev() {
                    let keys = cl
                        .params
                        .iter()
                        .map(|p| Key::Var(p.id))
                        .chain(std::iter::once(Key::Var(cl.cont.id)))
                        .collect();
                    scoped(work, &cl.body, keys);
                }
                work.push(Work::Node(Node::Comp(&h.body)));
            }
            LCompKind::Resume { cont, value } => {
                work.push(Work::Node(Node::Val(value)));
                work.push(Work::Node(Node::Ref(Key::Var(*cont))));
            }
        },
    }
}

pub(super) fn with_reads(future: &HashSet<Key>, node: Node<'_>) -> HashSet<Key> {
    let mut result = future.clone();
    result.extend(free_keys(node, Vec::new()));
    result
}

// 捕捉した参照はその場の命令より長く生きうるので、その分岐全体で再利用の候補から外す。
pub(super) fn captured(root: Node<'_>) -> HashSet<Key> {
    let mut work = vec![Work::Node(root)];
    let mut result = HashSet::new();
    while let Some(item) = work.pop() {
        if let Work::Node(node) = item {
            match node {
                Node::Val(LowVal {
                    kind: ValKind::Lambda(l),
                    ..
                }) => {
                    result.extend(free_keys(
                        Node::Comp(&l.body),
                        l.params.iter().map(|p| Key::Var(p.id)).collect(),
                    ));
                }
                Node::Comp(LComp {
                    kind: LCompKind::Lazy { body, .. },
                    ..
                }) => result.extend(free_keys(Node::Comp(body), Vec::new())),
                Node::Comp(LComp {
                    kind: LCompKind::Handle(h),
                    ..
                }) => {
                    result.extend(free_keys(Node::Comp(&h.body), Vec::new()));
                    for cl in &h.clauses {
                        result.extend(free_keys(
                            Node::Comp(&cl.body),
                            cl.params
                                .iter()
                                .map(|p| Key::Var(p.id))
                                .chain(std::iter::once(Key::Var(cl.cont.id)))
                                .collect(),
                        ));
                    }
                }
                Node::Val(_) | Node::Comp(_) | Node::Dict(_) | Node::Ref(_) => {}
            }
            expand(node, &mut work);
        }
    }
    result
}

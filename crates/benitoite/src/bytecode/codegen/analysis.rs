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

// アドレスは借用中の下位IRの節の同一性だけに使い、逆参照しない。
// SpanやVarIdは兄弟の分岐で重複するため、部分木の鍵には使えない。
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
enum Identity {
    Comp(*const LComp),
    Val(*const LowVal),
    Dict(*const DictVal),
}

impl Node<'_> {
    fn identity(self) -> Option<Identity> {
        match self {
            Self::Comp(c) => Some(Identity::Comp(c)),
            Self::Val(v) => Some(Identity::Val(v)),
            Self::Dict(d) => Some(Identity::Dict(d)),
            Self::Ref(_) => None,
        }
    }
}

#[derive(Clone, Copy)]
pub(super) struct ReadRange {
    start: usize,
    end: usize,
}

// 使用位置をキーごとに並べ、束縛位置の区間最小値を保持する。
// 範囲内で束縛された同名の変数を、外側の変数の読み出しに数えない。
#[derive(Default)]
struct Uses {
    positions: Vec<usize>,
    bindings: Vec<usize>,
    minima: Vec<usize>,
}

impl Uses {
    fn finish(&mut self) {
        let n = self.bindings.len();
        self.minima.resize(n.saturating_mul(2), usize::MAX);
        for (i, binding) in self.bindings.drain(..).enumerate() {
            if let Some(slot) = self.minima.get_mut(n.saturating_add(i)) {
                *slot = binding;
            }
        }
        for i in (1..n).rev() {
            let left = i.saturating_mul(2);
            let value = self.minima.get(left).copied().unwrap_or(usize::MAX).min(
                self.minima
                    .get(left.saturating_add(1))
                    .copied()
                    .unwrap_or(usize::MAX),
            );
            if let Some(slot) = self.minima.get_mut(i) {
                *slot = value;
            }
        }
    }

    fn reads(&self, range: ReadRange) -> bool {
        let n = self.positions.len();
        let mut left = n.saturating_add(self.positions.partition_point(|p| *p < range.start));
        let mut right = n.saturating_add(self.positions.partition_point(|p| *p < range.end));
        while left < right {
            if left % 2 == 1 {
                if self.minima.get(left).is_some_and(|b| *b < range.start) {
                    return true;
                }
                left = left.saturating_add(1);
            }
            if right % 2 == 1 {
                right = right.saturating_sub(1);
                if self.minima.get(right).is_some_and(|b| *b < range.start) {
                    return true;
                }
            }
            left /= 2;
            right /= 2;
        }
        false
    }
}

// 専用保持先は通常値の Key と別の索引へ加える。
// 補助原型もこの索引を共有し、捕捉一覧は各本体の終了時に一度だけ確定する。
#[derive(Default)]
pub(super) struct BodyAnalysis {
    ranges: HashMap<Identity, ReadRange>,
    ordinary: HashMap<Key, Uses>,
    captures: HashMap<Identity, Vec<Key>>,
    builders: HashMap<Identity, Vec<(BuilderId, BuilderKind)>>,
    captured_at: HashMap<Key, Vec<usize>>,
}

struct Body {
    root: Identity,
    owner: Option<usize>,
    start: usize,
    seen: HashSet<Key>,
    free: Vec<Key>,
    builder_free: Vec<(BuilderId, BuilderKind)>,
    builder_seen: HashSet<BuilderId>,
}

impl Body {
    fn read(&mut self, key: Key, binding: usize) {
        if binding < self.start && self.seen.insert(key) {
            self.free.push(key);
        }
    }
}

enum Work<'a> {
    BuilderBind(BuilderId),
    BuilderUnbind(BuilderId),
    BuilderRead(BuilderId, &'a BuilderKind),
    Node(Node<'a>),
    Finish(Identity, usize),
    Bind(Vec<Key>),
    Unbind(Vec<Key>),
    BeginBody(&'a LComp, Option<Identity>),
    EndBody,
}

impl BodyAnalysis {
    pub fn new(root: &LComp, params: Vec<Key>) -> CgResult<Self> {
        let mut result = Self::default();
        let mut scope: HashMap<Key, Vec<usize>> = HashMap::new();
        let mut bodies: Vec<Body> = Vec::new();
        let mut builder_scope: HashMap<BuilderId, Vec<usize>> = HashMap::new();
        let mut cursor = 1_usize;
        let mut work = Vec::new();
        prototype(&mut work, root, params, None);
        while let Some(item) = work.pop() {
            match item {
                Work::BuilderBind(id) => {
                    builder_scope.entry(id).or_default().push(cursor);
                    cursor = cursor.saturating_add(1);
                }
                Work::BuilderUnbind(id) => {
                    if let Some(v) = builder_scope.get_mut(&id) {
                        v.pop();
                    }
                }
                Work::BuilderRead(id, kind) => {
                    let bound = builder_scope
                        .get(&id)
                        .and_then(|v| v.last())
                        .copied()
                        .unwrap_or(0);
                    if let Some(body) = bodies.last_mut()
                        && bound < body.start
                        && body.builder_seen.insert(id)
                    {
                        body.builder_free.push((id, kind.clone()));
                    }
                    cursor = cursor.saturating_add(1);
                }
                Work::Bind(keys) => {
                    for key in keys {
                        scope.entry(key).or_default().push(cursor);
                    }
                    cursor = cursor.saturating_add(1);
                }
                Work::Unbind(keys) => {
                    for key in keys {
                        if let Some(bindings) = scope.get_mut(&key) {
                            bindings.pop();
                        }
                    }
                }
                Work::Finish(id, start) => {
                    result.ranges.insert(id, ReadRange { start, end: cursor });
                }
                Work::BeginBody(body, owner) => {
                    let owner = owner
                        .map(|id| {
                            result
                                .ranges
                                .get(&id)
                                .map(|r| r.start)
                                .ok_or_else(|| internal("missing capture owner"))
                        })
                        .transpose()?;
                    bodies.push(Body {
                        root: Identity::Comp(body),
                        owner,
                        start: cursor,
                        seen: HashSet::new(),
                        free: Vec::new(),
                        builder_free: Vec::new(),
                        builder_seen: HashSet::new(),
                    });
                    cursor = cursor.saturating_add(1);
                }
                Work::EndBody => {
                    let body = bodies
                        .pop()
                        .ok_or_else(|| internal("missing analysis body"))?;
                    for key in &body.free {
                        if let Some(position) = body.owner {
                            result.captured_at.entry(*key).or_default().push(position);
                        }
                        if let Some(parent) = bodies.last_mut() {
                            let binding =
                                scope.get(key).and_then(|s| s.last()).copied().unwrap_or(0);
                            parent.read(*key, binding);
                        }
                    }
                    for (id, kind) in &body.builder_free {
                        let bound = builder_scope
                            .get(id)
                            .and_then(|v| v.last())
                            .copied()
                            .unwrap_or(0);
                        if let Some(parent) = bodies.last_mut()
                            && bound < parent.start
                            && parent.builder_seen.insert(*id)
                        {
                            parent.builder_free.push((*id, kind.clone()));
                        }
                    }
                    result.builders.insert(body.root, body.builder_free);
                    result.captures.insert(body.root, body.free);
                }
                Work::Node(Node::Ref(key)) => {
                    let binding = scope.get(&key).and_then(|s| s.last()).copied().unwrap_or(0);
                    let uses = result.ordinary.entry(key).or_default();
                    uses.positions.push(cursor);
                    uses.bindings.push(binding);
                    if let Some(body) = bodies.last_mut() {
                        body.read(key, binding);
                    }
                    cursor = cursor.saturating_add(1);
                }
                Work::Node(node) => {
                    let id = node
                        .identity()
                        .ok_or_else(|| internal("missing node identity"))?;
                    let start = cursor;
                    cursor = cursor.saturating_add(1);
                    // ownerの開始位置は子の本体を辿る時点でも参照する。
                    result.ranges.insert(id, ReadRange { start, end: cursor });
                    work.push(Work::Finish(id, start));
                    expand(node, &mut work);
                }
            }
        }
        for uses in result.ordinary.values_mut() {
            uses.finish();
        }
        for positions in result.captured_at.values_mut() {
            positions.sort_unstable();
            positions.dedup();
        }
        Ok(result)
    }

    pub fn range(&self, node: Node<'_>) -> CgResult<ReadRange> {
        node.identity()
            .and_then(|id| self.ranges.get(&id))
            .copied()
            .ok_or_else(|| internal("node is absent from body analysis"))
    }

    pub fn values(&self, values: &[LowVal]) -> CgResult<Option<ReadRange>> {
        match (values.first(), values.last()) {
            (Some(first), Some(last)) => Ok(Some(ReadRange {
                start: self.range(Node::Val(first))?.start,
                end: self.range(Node::Val(last))?.end,
            })),
            _ => Ok(None),
        }
    }

    pub fn builders(&self, body: &LComp) -> &[(BuilderId, BuilderKind)] {
        self.builders
            .get(&Identity::Comp(body))
            .map_or(&[], Vec::as_slice)
    }

    pub fn captures(&self, body: &LComp) -> CgResult<&[Key]> {
        self.captures
            .get(&Identity::Comp(body))
            .map(Vec::as_slice)
            .ok_or_else(|| internal("missing body captures"))
    }

    pub fn captured(&self, node: Node<'_>, aliases: &HashSet<Key>) -> CgResult<bool> {
        let range = self.range(node)?;
        Ok(aliases.iter().any(|key| {
            self.captured_at.get(key).is_some_and(|positions| {
                positions
                    .get(positions.partition_point(|p| *p < range.start))
                    .is_some_and(|p| *p < range.end)
            })
        }))
    }
}

// 呼び出し元の範囲を借用し、分岐・Letごとに全自由変数集合を複製しない。
// 長いLetの各boundでは、同じ索引の接尾範囲だけを付け替える。
#[derive(Default)]
pub(super) struct Reads<'a> {
    parent: Option<&'a Reads<'a>>,
    ranges: Vec<ReadRange>,
}

impl<'a> Reads<'a> {
    pub fn with(&'a self, range: ReadRange) -> Reads<'a> {
        Reads {
            parent: Some(self),
            ranges: vec![range],
        }
    }

    pub fn with_values(
        &'a self,
        analysis: &BodyAnalysis,
        values: &[LowVal],
    ) -> CgResult<Reads<'a>> {
        Ok(Reads {
            parent: Some(self),
            ranges: analysis.values(values)?.into_iter().collect(),
        })
    }

    pub fn add(&mut self, analysis: &BodyAnalysis, node: Node<'_>) -> CgResult<()> {
        self.ranges.push(analysis.range(node)?);
        Ok(())
    }

    pub fn contains(&self, analysis: &BodyAnalysis, key: &Key) -> bool {
        let Some(uses) = analysis.ordinary.get(key) else {
            return false;
        };
        let mut current = Some(self);
        while let Some(reads) = current {
            if reads.ranges.iter().any(|r| uses.reads(*r)) {
                return true;
            }
            current = reads.parent;
        }
        false
    }
}

fn scoped<'a>(work: &mut Vec<Work<'a>>, body: &'a LComp, keys: Vec<Key>) {
    work.push(Work::Unbind(keys.clone()));
    work.push(Work::Node(Node::Comp(body)));
    work.push(Work::Bind(keys));
}

fn prototype<'a>(
    work: &mut Vec<Work<'a>>,
    body: &'a LComp,
    keys: Vec<Key>,
    owner: Option<Identity>,
) {
    work.push(Work::EndBody);
    scoped(work, body, keys);
    work.push(Work::BeginBody(body, owner));
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
            ValKind::Lambda(l) => prototype(
                work,
                &l.body,
                l.params.iter().map(|p| Key::Var(p.id)).collect(),
                node.identity(),
            ),
            ValKind::Ctor { args, .. } | ValKind::List(args) => vals(work, args),
            ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. }
            | ValKind::External { .. }
            | ValKind::Op { .. }
            | ValKind::ConstRef(_) => {}
        },
        Node::Comp(c) => match &c.kind {
            LCompKind::BuilderLet { id, body, .. } => {
                work.push(Work::BuilderUnbind(*id));
                work.push(Work::Node(Node::Comp(body)));
                work.push(Work::BuilderBind(*id));
            }
            LCompKind::BuilderOp { id, kind, args, .. } => {
                work.push(Work::BuilderRead(*id, kind));
                vals(work, args);
            }
            LCompKind::Return(v) | LCompKind::Escape(v) => work.push(Work::Node(Node::Val(v))),
            LCompKind::Let { var, bound, body } => {
                scoped(work, body, vec![Key::Var(var.id)]);
                work.push(Work::Node(Node::Comp(bound)));
            }
            LCompKind::App {
                func,
                dicts: ds,
                args,
                exit_report,
            } => {
                if let Some(report) = exit_report {
                    if let Some(message) = &report.message {
                        work.push(Work::Node(Node::Val(message)));
                    }
                    work.push(Work::Node(Node::Val(&report.cause)));
                }
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
            LCompKind::Lazy { body, .. } => prototype(work, body, Vec::new(), node.identity()),
            LCompKind::Handle(h) => {
                for cl in h.clauses.iter().rev() {
                    let keys = cl
                        .dict_params
                        .iter()
                        .map(|p| Key::Var(p.var))
                        .chain(cl.params.iter().map(|p| Key::Var(p.id)))
                        .chain(std::iter::once(Key::Var(cl.cont.id)))
                        .collect();
                    prototype(work, &cl.body, keys, node.identity());
                }
                prototype(work, &h.body, Vec::new(), node.identity());
            }
            LCompKind::Resume { cont, value } => {
                work.push(Work::Node(Node::Val(value)));
                work.push(Work::Node(Node::Ref(Key::Var(*cont))));
            }
        },
    }
}

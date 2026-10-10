//! Exchange/Syntax.lean の構成子名・欄名に合わせた JSON。serde はテスト内だけで使う。
use benitoite::base::{BindingId, NodeId};
use benitoite::builtins::{self, table};
use benitoite::ir::core_ir as c;
use benitoite::pipeline::CheckedProgram;
use benitoite::resolve::BindingKind;
use benitoite::syntax::ast as a;
use benitoite::typeck::TryKind;
use benitoite::types::builtin::{BuiltinTypeClass, BuiltinTypeId};
use benitoite::types::{
    self, ConstValue, DictExpr, EffectName, EffectSet, Scheme, Ty, TyCon, TyHead, TypeArg, TypeArgs,
};
use serde_json::{Value, json};
use std::collections::{BTreeMap, BTreeSet};

#[path = "builtins.rs"]
mod builtin_export;
pub use builtin_export::{builtin_tables, complete_stdlib};

fn tagged(tag: &str, fields: Value) -> Value {
    json!({tag:fields})
}
fn con_name(adt: BindingId, tag: u32) -> String {
    format!("con:{}:{tag}", adt.0)
}
fn fun_name(id: BindingId) -> String {
    format!("fn:{}", id.0)
}
fn class_name(id: BindingId) -> String {
    format!("class:{}", id.0)
}
fn method_name(id: BindingId) -> String {
    format!("meth:{}", id.0)
}
fn impl_name(id: NodeId) -> String {
    format!("impl:{}", id.0)
}
fn data_name(id: BindingId) -> String {
    format!("data:{}", id.0)
}
// Release.TyCon が持たない組み込みの型構成子は、版 3 でも対象外。
fn unsupported_target(target: &TypeArg) -> Option<&'static str> {
    match target {
        TypeArg::Head(TyHead::Con(TyCon::Builtin(id)))
            if !matches!(
                *id,
                BuiltinTypeId::LIST
                    | BuiltinTypeId::MAP
                    | BuiltinTypeId::SET
                    | BuiltinTypeId::REFERENCE
                    | BuiltinTypeId::LAZY
            ) =>
        {
            Some("higher kind: unsupported constructor")
        }
        TypeArg::Ty(_) | TypeArg::Head(_) => None,
    }
}
fn unsupported(name: &str) -> Value {
    tagged("unsupported", json!({"name":name}))
}
fn eff(e: &EffectSet) -> Value {
    let mut atoms: Vec<Value> = e
        .names
        .iter()
        .map(|n| {
            let name = match n {
                EffectName::User(id) => format!("effect:{}", id.0),
                EffectName::Builtin(id) => {
                    let d = id.def().unwrap();
                    if d.module.is_empty() {
                        d.name.to_owned()
                    } else {
                        format!("{}.{}", d.module.join("."), d.name)
                    }
                }
            };
            tagged("name", json!({"value":name}))
        })
        .collect();
    atoms.extend(e.vars.iter().map(|i| tagged("rho", json!({"index":i.0}))));
    json!(atoms)
}

fn constant(v: &ConstValue) -> Value {
    match v {
        ConstValue::Integer(value) => tagged("integer", json!({"value":value})),
        ConstValue::Float(value) => tagged("float", json!({"bits":value.to_bits().to_string()})),
        ConstValue::String(value) => tagged("string", json!({"value":value})),
        ConstValue::Character(value) => tagged("character", json!({"value":u32::from(*value)})),
        ConstValue::Boolean(value) => tagged("boolean", json!({"value":value})),
        ConstValue::Decimal(value) => tagged(
            "decimal",
            json!({"mantissa":value.mantissa(),"scale":value.scale()}),
        ),
        ConstValue::Unit => json!("unit"),
        ConstValue::Byte(_)
        | ConstValue::Ctor { .. }
        | ConstValue::List(_)
        | ConstValue::Map(_)
        | ConstValue::Set(_) => panic!("unsupported literal sent to Exchange: {v:?}"),
    }
}

// γ₀ の識別子が各 γⱼ のどの位置にあるか。集合一致と重複なしを先に確かめる。
fn slots<T: Copy + Ord>(first: &[T], current: &[T]) -> Option<Vec<usize>> {
    let first_set: BTreeSet<_> = first.iter().copied().collect();
    let current_set: BTreeSet<_> = current.iter().copied().collect();
    if first_set.len() != first.len()
        || current_set.len() != current.len()
        || first_set != current_set
    {
        return None;
    }
    first
        .iter()
        .map(|v| current.iter().position(|w| w == v))
        .collect()
}

// Rust の脱糖と同じ伝播規則。Result だけを補正し、Tail の match は計数だけする。
#[derive(Clone, Copy, PartialEq, Eq)]
enum Position {
    Tail,
    Result,
    Other,
}

// 継続と `_` の節引数も、普通の値の番号をずらす位置を占める。
#[derive(Clone, Copy, PartialEq, Eq)]
enum SurfaceSlot {
    Local(BindingId),
    Continuation,
    Ignored,
    Dictionary(usize),
}
#[derive(Clone, Copy, PartialEq, Eq)]
enum CoreSlot {
    Local(c::VarId),
    Continuation(c::VarId),
    ImplDictionary(usize),
}

struct ConstantEntry {
    ty: Value,
    body: Value,
    references: BTreeSet<BindingId>,
    outside: BTreeSet<String>,
}
struct ConstantTable(BTreeMap<BindingId, ConstantEntry>);
impl ConstantTable {
    fn reasons(
        &self,
        id: BindingId,
        active: &mut BTreeSet<BindingId>,
        cache: &mut BTreeMap<BindingId, BTreeSet<String>>,
    ) -> BTreeSet<String> {
        if let Some(reasons) = cache.get(&id) {
            return reasons.clone();
        }
        assert!(active.insert(id), "cyclic surface constant: {id:?}");
        let entry = self.0.get(&id).expect("missing surface constant");
        let mut reasons = entry.outside.clone();
        for reference in &entry.references {
            reasons.extend(self.reasons(*reference, active, cache));
        }
        active.remove(&id);
        cache.insert(id, reasons.clone());
        reasons
    }
    fn json(&self) -> Value {
        json!(
            self.0
                .iter()
                .filter(|(_, e)| e.outside.is_empty())
                .map(|(id, e)| json!({"name":format!("const:{}",id.0),"ty":e.ty,"body":e.body}))
                .collect::<Vec<_>>()
        )
    }
}

/// 既存 corpus の原子に混ぜず、同じ AST の走査から得る網羅性検査の入力。
#[derive(Default)]
pub struct CoverageExport {
    pub matches: Vec<Value>,
    pub bindings: Vec<Value>,
}

struct Surface<'a> {
    p: &'a CheckedProgram,
    coverage: CoverageExport,
    constants: Option<&'a ConstantTable>,
    constant_references: BTreeSet<BindingId>,
    closed_constant: bool,
    outside: BTreeSet<String>,
    return_ty: Option<Ty>,
    placeholder_argument: bool,
    placeholder_clause_depth: Option<usize>,
    guard_clause_depth: Option<usize>,
    known_differences: BTreeSet<String>,
    clause_types: Vec<(NodeId, usize)>,
    type_order: Vec<usize>,
    // [対象箇所数, 元の注釈が R と異なる箇所数]。対象外の関数も含む。
    annotations: BTreeMap<&'static str, [usize; 2]>,
}
impl Surface<'_> {
    fn new(p: &CheckedProgram, ret: Option<Ty>, type_order: Vec<usize>) -> Surface<'_> {
        Surface {
            p,
            coverage: CoverageExport::default(),
            constants: None,
            constant_references: BTreeSet::new(),
            closed_constant: false,
            outside: BTreeSet::new(),
            return_ty: ret,
            placeholder_argument: false,
            placeholder_clause_depth: None,
            guard_clause_depth: None,
            known_differences: BTreeSet::new(),
            clause_types: Vec::new(),
            type_order,
            annotations: BTreeMap::new(),
        }
    }
    fn type_index(&self, i: u32) -> usize {
        assert!(!self.closed_constant, "type parameter in constant body");
        let i = usize::try_from(i).unwrap();
        let mapped = if self.type_order.is_empty() {
            i
        } else {
            self.type_order[i]
        };
        mapped + self.clause_types.iter().map(|(_, n)| n).sum::<usize>()
    }
    fn type_arg(&mut self, t: &TypeArg) -> Value {
        match t {
            TypeArg::Ty(t) => self.ty(t),
            TypeArg::Head(TyHead::Param(i)) => tagged("tvar", json!({"index":self.type_index(*i)})),
            TypeArg::Head(TyHead::Con(con)) => {
                let head = match con {
                    TyCon::Adt(id) => tagged("data", json!({"name":data_name(*id)})),
                    TyCon::Builtin(id) => match *id {
                        BuiltinTypeId::LIST => json!("list"),
                        BuiltinTypeId::MAP => json!("map"),
                        BuiltinTypeId::SET => json!("set"),
                        BuiltinTypeId::REFERENCE => json!("reference"),
                        BuiltinTypeId::LAZY => json!("lazyT"),
                        _ => return self.outside("higher kind: unsupported constructor"),
                    },
                };
                tagged("ctor", json!({"head":head}))
            }
        }
    }
    fn dict_params(&self, cs: &[types::ClassConstraint]) -> Vec<Value> {
        cs.iter()
            .map(|c| json!([class_name(c.class), self.type_index(c.param)]))
            .collect()
    }
    fn dict_ty(&mut self, c: &types::ClassConstraint) -> Value {
        tagged(
            "dict",
            json!({"cls":class_name(c.class),"arg":self.ty(&Ty::Param(c.param))}),
        )
    }
    fn dictionary(&mut self, d: &DictExpr, env: &[SurfaceSlot]) -> Value {
        match d {
            DictExpr::Impl {
                impl_decl,
                type_args,
                args,
            } => {
                if let Some(reason) =
                    unsupported_target(&self.p.types.impls.get(*impl_decl).unwrap().target)
                {
                    return self.outside(reason);
                }
                let tys: Vec<_> = type_args.iter().map(|t| self.type_arg(t)).collect();
                let args: Vec<_> = args.iter().map(|d| self.dictionary(d, env)).collect();
                tagged(
                    "impl",
                    json!({"name":impl_name(*impl_decl),"tys":tys,"args":args}),
                )
            }
            DictExpr::Param { constraint, supers } => {
                let index = env
                    .iter()
                    .rev()
                    .position(|s| {
                        *s == SurfaceSlot::Dictionary(usize::try_from(*constraint).unwrap())
                    })
                    .expect("surface dictionary not in environment");
                let mut value = tagged("local", json!({"index":index}));
                for cl in supers {
                    value = tagged("super", json!({"dict":value,"cls":class_name(*cl)}));
                }
                value
            }
        }
    }
    fn outside(&mut self, name: &str) -> Value {
        self.outside.insert(name.to_owned());
        json!("unit")
    }
    fn ty(&mut self, ty: &Ty) -> Value {
        match ty {
            Ty::Param(index) => tagged("tvar", json!({"index":self.type_index(*index)})),
            Ty::App(i, ts) => {
                let args: Vec<_> = ts.iter().map(|t| self.ty(t)).collect();
                tagged("tapp", json!({"index":self.type_index(*i),"args":args}))
            }
            Ty::Rigid { clause, index } => {
                assert!(!self.closed_constant, "Rigid type in constant body");
                let mut offset = 0;
                for (node, count) in self.clause_types.iter().rev() {
                    if node == clause {
                        assert!(
                            usize::try_from(*index).unwrap() < *count,
                            "Rigid index out of range"
                        );
                        return tagged(
                            "tvar",
                            json!({"index":offset + usize::try_from(*index).unwrap()}),
                        );
                    }
                    offset += count;
                }
                panic!("Rigid clause not in scope: {clause:?}");
            }
            Ty::Fn(f) => {
                let params: Vec<_> = f.params.iter().map(|p| self.ty(p)).collect();
                let ret = self.ty(&f.ret);
                tagged(
                    "fn",
                    json!({"params":params,"ret":ret,"eff":eff(&f.effects)}),
                )
            }
            Ty::Con(con, args) => {
                let args: Vec<_> = args.iter().map(|t| self.ty(t)).collect();
                match con {
                    TyCon::Adt(id) => tagged("data", json!({"name":data_name(*id),"args":args})),
                    TyCon::Builtin(id) => {
                        let d = id.def().unwrap();
                        if d.class == BuiltinTypeClass::Basic {
                            assert!(args.is_empty());
                            return tagged("base", json!({"name":d.name}));
                        }
                        match *id {
                            BuiltinTypeId::LIST => tagged("list", json!({"elem":args[0]})),
                            BuiltinTypeId::MAP => {
                                tagged("map", json!({"key":args[0],"value":args[1]}))
                            }
                            BuiltinTypeId::SET => tagged("set", json!({"elem":args[0]})),
                            BuiltinTypeId::BYTES => json!("bytes"),
                            BuiltinTypeId::REFERENCE => {
                                tagged("reference", json!({"elem":args[0]}))
                            }
                            BuiltinTypeId::LAZY => tagged("lazyT", json!({"elem":args[0]})),
                            // Task などは Release の O[A] に対応する一意な中身を見せない型名。
                            _ => tagged(
                                "opaque",
                                json!({"name":format!("{}:{}",id.0,serde_json::to_string(&args).unwrap())}),
                            ),
                        }
                    }
                }
            }
        }
    }
    fn node_ty(&mut self, id: NodeId) -> Value {
        self.ty(self
            .p
            .types
            .expr_types
            .get(id)
            .unwrap_or_else(|| panic!("missing expr_types: {id:?}")))
    }
    fn annotation(&mut self, id: NodeId, position: Position, kind: &'static str) -> Value {
        let original = self.p.types.expr_types.get(id).unwrap().clone();
        if position == Position::Other || (position == Position::Tail && kind == "return") {
            return self.ty(&original);
        }
        let ret = self
            .return_ty
            .as_ref()
            .expect("result without function")
            .clone();
        let key = match (position, kind) {
            (Position::Result, "return") => "resultReturn",
            (Position::Result, "match") => "resultMatch",
            (Position::Tail, "match") => "tailMatch",
            _ => unreachable!(),
        };
        let counts = self.annotations.entry(key).or_default();
        counts[0] += 1;
        counts[1] += usize::from(original != ret);
        self.ty(if position == Position::Result {
            &ret
        } else {
            &original
        })
    }
    fn op_ref(&self, id: BindingId) -> Value {
        match self.p.resolved.builtin_ops.get(id) {
            Some(b) => tagged(
                "prim",
                json!({"name":builtins::builtin_decl(*b).unwrap().name}),
            ),
            None => tagged("user", json!({"name":format!("op:{}",id.0)})),
        }
    }
    fn std_ctor(&self, name: &str) -> String {
        let id = self.p.resolved.stdlib(name).unwrap();
        let BindingKind::Ctor { data, tag } = self.p.resolved.bindings.get(id).unwrap().kind else {
            panic!("invalid stdlib constructor: {name}")
        };
        con_name(data, tag)
    }
    fn targs(&mut self, id: NodeId, binding: BindingId) -> (Vec<Value>, Vec<Value>) {
        let scheme = self.p.types.decl_types.get(binding).unwrap();
        let empty = TypeArgs::default();
        let args = self.p.types.type_args.get(id).unwrap_or_else(|| {
            assert!(
                scheme.type_params.is_empty() && scheme.effect_params.is_empty(),
                "missing type args {id:?}"
            );
            &empty
        });
        self.args(args)
    }
    fn args(&mut self, args: &TypeArgs) -> (Vec<Value>, Vec<Value>) {
        let tys = args.tys.iter().map(|t| self.type_arg(t)).collect();
        (tys, args.effects.iter().map(eff).collect())
    }
    fn header(&mut self, s: &Scheme) -> Value {
        let mut ordered: Vec<_> = s.type_params.iter().enumerate().collect();
        if !self.type_order.is_empty() {
            ordered.sort_by_key(|(i, _)| self.type_order[*i]);
        }
        let tparams: Vec<_> = ordered
            .into_iter()
            .map(|(_, t)| t)
            .map(|t| match t.builtin {
                Some(types::BuiltinConstraint::Equality) => json!([true, false]),
                Some(types::BuiltinConstraint::Key) => json!([true, true]),
                Some(types::BuiltinConstraint::Ordered) => panic!("user ordered constraint"),
                None => json!([false, false]),
            })
            .collect();
        let params: Vec<_> = s.params.iter().map(|p| self.ty(p)).collect();
        json!({"tparams":tparams,"neffs":s.effect_params.len(),"params":params,
            "ret":self.ty(&s.ret),"eff":eff(&s.effects)})
    }
    fn declaration(&self, id: NodeId) -> BindingId {
        *self.p.resolved.decls.get(id).unwrap()
    }
    fn reference(&self, id: NodeId) -> BindingId {
        *self.p.resolved.refs.get(id).unwrap()
    }
    fn literal(&mut self, id: NodeId) -> Value {
        let value = self.p.types.lit_values.get(id).unwrap();
        match value {
            ConstValue::Byte(_) => self.outside("Byte literal"),
            ConstValue::Decimal(decimal) => {
                assert!(
                    decimal.mantissa() >= 0,
                    "negative surface Decimal coefficient"
                );
                constant(value)
            }
            ConstValue::Integer(_)
            | ConstValue::Float(_)
            | ConstValue::String(_)
            | ConstValue::Character(_)
            | ConstValue::Boolean(_)
            | ConstValue::Unit
            | ConstValue::Ctor { .. }
            | ConstValue::List(_)
            | ConstValue::Map(_)
            | ConstValue::Set(_) => constant(value),
        }
    }
    fn pattern(&mut self, p: &a::Pattern, env: &mut Vec<SurfaceSlot>) -> Value {
        match p {
            a::Pattern::Wildcard(_) => json!("wild"),
            a::Pattern::Var(v) => {
                self.node_ty(v.id);
                // 選択肢の二つ目以降は最初の束縛への参照である。
                let id = self
                    .p
                    .resolved
                    .decls
                    .get(v.id)
                    .or_else(|| self.p.resolved.refs.get(v.id))
                    .copied()
                    .unwrap();
                env.push(SurfaceSlot::Local(id));
                json!("var")
            }
            a::Pattern::Lit(v) => {
                if matches!(
                    self.p.types.lit_values.get(v.id),
                    Some(ConstValue::Decimal(_))
                ) {
                    self.outside("Decimal pattern")
                } else {
                    tagged("const", json!({"value":self.literal(v.id)}))
                }
            }
            a::Pattern::Unit(_) => tagged("const", json!({"value":"unit"})),
            a::Pattern::Ctor(v) => {
                let id = self.reference(v.id);
                let BindingKind::Ctor { data, tag } =
                    self.p.resolved.bindings.get(id).unwrap().kind
                else {
                    panic!("ctor pattern")
                };
                let args: Vec<_> = v.args.iter().map(|p| self.pattern(p, env)).collect();
                tagged("con", json!({"name":con_name(data,tag),"args":args}))
            }
            a::Pattern::Record(v) => {
                let adt = self.reference(v.id);
                let fields = self.p.types.adts.get(adt).unwrap().record.as_ref().unwrap();
                let n = fields.len();
                let positions: Vec<_> = v
                    .fields
                    .iter()
                    .map(|f| {
                        let id = self.reference(f.id);
                        fields.iter().position(|decl| decl.binding == id).unwrap()
                    })
                    .collect();
                // 環境は toCore の照合順。JSON の子はソースの順に戻す。
                // 入れ子でも同じ処理を繰り返すため、別の番号の対応表は要らない。
                let mut order: Vec<_> = (0..v.fields.len()).collect();
                order.sort_by_key(|i| positions[*i]);
                let mut args = vec![Value::Null; v.fields.len()];
                for i in order {
                    args[i] = self.pattern(&v.fields[i].pattern, env);
                }
                tagged(
                    "record",
                    json!({"name":con_name(adt,0),"n":n,"positions":positions,"args":args}),
                )
            }
            a::Pattern::Range(v) => {
                let (lo, hi) = self.p.types.range_bounds.get(v.id).unwrap();
                tagged("range", json!({"lo":constant(lo),"hi":constant(hi)}))
            }
            a::Pattern::List(v) => {
                let before: Vec<_> = v.before.iter().map(|p| self.pattern(p, env)).collect();
                let rest = v.rest.as_ref().map(|r| {
                    if r.name.is_some() {
                        let id = self
                            .p
                            .resolved
                            .decls
                            .get(r.id)
                            .or_else(|| self.p.resolved.refs.get(r.id))
                            .copied()
                            .unwrap();
                        env.push(SurfaceSlot::Local(id));
                        "bind"
                    } else {
                        "skip"
                    }
                });
                let after: Vec<_> = v.after.iter().map(|p| self.pattern(p, env)).collect();
                tagged("list", json!({"before":before,"rest":rest,"after":after}))
            }
            a::Pattern::Error(_) => panic!("checked error pattern"),
        }
    }
    fn name(&mut self, n: &a::NameExpr, env: &[SurfaceSlot]) -> Value {
        let id = self.reference(n.id);
        let binding = self.p.resolved.bindings.get(id).unwrap();
        match binding.kind {
            BindingKind::Local(_) => {
                let index = env
                    .iter()
                    .rev()
                    .position(|b| *b == SurfaceSlot::Local(id))
                    .expect("local not in lexical environment");
                tagged("local", json!({"index":index}))
            }
            BindingKind::Const => {
                self.constant_references.insert(id);
                if let Some(table) = self.constants {
                    self.outside.extend(
                        table
                            .0
                            .get(&id)
                            .expect("missing surface constant")
                            .outside
                            .iter()
                            .cloned(),
                    );
                }
                tagged("constName", json!({"name":format!("const:{}",id.0)}))
            }
            BindingKind::Field { .. } => {
                if self
                    .p
                    .types
                    .decl_types
                    .get(id)
                    .unwrap()
                    .class_constraints
                    .is_empty()
                {
                    let (tys, effs) = self.targs(n.id, id);
                    tagged(
                        "funName",
                        json!({"name":fun_name(id),"tys":tys,"effs":effs}),
                    )
                } else {
                    self.outside("constrained head: field")
                }
            }
            BindingKind::Method { .. } => self.dictionary_name(n, id, env),
            BindingKind::Fn | BindingKind::BuiltinFn(_) | BindingKind::Op { .. } => {
                let s = self.p.types.decl_types.get(id).unwrap();
                if !s.class_constraints.is_empty() {
                    if matches!(binding.kind, BindingKind::BuiltinFn(_)) {
                        return self.outside("constrained head: builtin");
                    }
                    if matches!(binding.kind, BindingKind::Op { .. }) {
                        return self.outside("constrained head: operation");
                    }
                    return self.dictionary_name(n, id, env);
                }
                let (tys, effs) = self.targs(n.id, id);
                if matches!(binding.kind, BindingKind::Op { .. }) {
                    assert!(effs.is_empty(), "operation has effect arguments: {id:?}");
                }
                let (tag, name) = match binding.kind {
                    BindingKind::Fn => ("funName", fun_name(id)),
                    BindingKind::BuiltinFn(b) => (
                        "primName",
                        builtins::builtin_decl(b).unwrap().name.to_owned(),
                    ),
                    BindingKind::Op { .. } => match self.p.resolved.builtin_ops.get(id) {
                        Some(b) => (
                            "primName",
                            builtins::builtin_decl(*b).unwrap().name.to_owned(),
                        ),
                        None => ("opName", format!("op:{}", id.0)),
                    },
                    BindingKind::ImplFn { .. }
                    | BindingKind::Data
                    | BindingKind::BuiltinType(_)
                    | BindingKind::Alias
                    | BindingKind::Record
                    | BindingKind::Trait
                    | BindingKind::Effect
                    | BindingKind::BuiltinEffect(_)
                    | BindingKind::Module(_)
                    | BindingKind::NamespaceRoot
                    | BindingKind::TypeParam { .. }
                    | BindingKind::EffectVar { .. }
                    | BindingKind::Const
                    | BindingKind::Field { .. }
                    | BindingKind::Ctor { .. }
                    | BindingKind::Method { .. }
                    | BindingKind::Local(_) => unreachable!(),
                };
                if tag == "opName" {
                    tagged(tag, json!({"name":name,"tys":tys}))
                } else {
                    tagged(tag, json!({"name":name,"tys":tys,"effs":effs}))
                }
            }
            BindingKind::Ctor { data, tag } => {
                if self.p.types.adts.get(data).unwrap().record.is_some() {
                    self.outside("record");
                }
                let (tys, _) = self.targs(n.id, id);
                let args = self
                    .p
                    .types
                    .type_args
                    .get(n.id)
                    .cloned()
                    .unwrap_or_default();
                let s = self.p.types.decl_types.get(id).unwrap();
                let instantiated = s.fn_ty().subst(&args.tys, &args.effects);
                let Ty::Fn(f) = instantiated else {
                    panic!("ctor type")
                };
                if f.params.is_empty() {
                    tagged("nullCon", json!({"name":con_name(data,tag),"tys":tys}))
                } else {
                    let params: Vec<_> = f.params.iter().map(|t| self.ty(t)).collect();
                    tagged(
                        "conValue",
                        json!({"name":con_name(data,tag),"tys":tys,"params":params}),
                    )
                }
            }
            BindingKind::ImplFn { .. }
            | BindingKind::Data
            | BindingKind::BuiltinType(_)
            | BindingKind::Alias
            | BindingKind::Record
            | BindingKind::Trait
            | BindingKind::Effect
            | BindingKind::BuiltinEffect(_)
            | BindingKind::Module(_)
            | BindingKind::NamespaceRoot
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. } => panic!("invalid checked name: {:?}", binding.kind),
        }
    }
    fn dictionary_name(&mut self, n: &a::NameExpr, id: BindingId, env: &[SurfaceSlot]) -> Value {
        let (mut tys, effs) = self.targs(n.id, id);
        let args = self
            .p
            .types
            .type_args
            .get(n.id)
            .cloned()
            .unwrap_or_default();
        let scheme = self.p.types.decl_types.get(id).unwrap();
        let Ty::Fn(f) = scheme.fn_ty().subst(&args.tys, &args.effects) else {
            panic!("dictionary name type")
        };
        let params: Vec<_> = f.params.iter().map(|t| self.ty(t)).collect();
        let dicts: Vec<_> = self
            .p
            .types
            .dicts
            .get(n.id)
            .unwrap()
            .iter()
            .map(|d| self.dictionary(d, env))
            .collect();
        if matches!(
            self.p.resolved.bindings.get(id).unwrap().kind,
            BindingKind::Method { .. }
        ) {
            assert!(!tys.is_empty() && !dicts.is_empty());
            tys.remove(0);
            tagged(
                "methName",
                json!({"dict":dicts[0],"name":method_name(id),"tys":tys,"effs":effs,"dicts":dicts[1..],"params":params,"eff":eff(&f.effects)}),
            )
        } else {
            tagged(
                "funDicts",
                json!({"name":fun_name(id),"tys":tys,"effs":effs,"dicts":dicts,"params":params,"eff":eff(&f.effects)}),
            )
        }
    }
    fn expr(&mut self, e: &a::Expr, env: &[SurfaceSlot]) -> Value {
        self.expr_at(e, env, Position::Other)
    }
    fn expr_at(&mut self, e: &a::Expr, env: &[SurfaceSlot], position: Position) -> Value {
        self.node_ty(e.id());
        if let Some(args) = self.p.types.type_args.get(e.id()) {
            self.args(args);
        }
        match e {
            a::Expr::Lit(v) => tagged("literal", json!({"value":self.literal(v.id)})),
            a::Expr::Unit(_) => json!("unit"),
            a::Expr::Name(n) => self.name(n, env),
            a::Expr::Paren(p) => tagged(
                "paren",
                json!({"inner":self.expr_at(&p.inner,env,position)}),
            ),
            a::Expr::Call(v) => self.call(v, env),
            a::Expr::Pipe(v) => {
                let lhs = self.expr(&v.lhs, env);
                let rhs = self.expr(&v.rhs, env);
                tagged("pipe", json!({"lhs":lhs,"rhs":rhs}))
            }
            a::Expr::Unary(v) => {
                // 直接の負号だけが符号込みで記録される。括弧を挟む式は一般の neg にする。
                if v.op == a::UnOp::Neg
                    && let Some(ConstValue::Decimal(value)) = self.p.types.lit_values.get(v.id)
                {
                    let a::Expr::Lit(l) = v.operand.as_ref() else {
                        panic!("recorded Decimal negation is not direct")
                    };
                    let Some(ConstValue::Decimal(positive)) = self.p.types.lit_values.get(l.id)
                    else {
                        panic!("missing positive Decimal literal")
                    };
                    assert!(positive.mantissa() >= 0);
                    assert_eq!(value.mantissa(), -positive.mantissa());
                    assert_eq!(value.scale(), positive.scale());
                    return tagged(
                        "negDecimal",
                        json!({"mantissa":positive.mantissa(),"scale":positive.scale()}),
                    );
                }
                if v.op == a::UnOp::Neg
                    && let Some(ConstValue::Float(value)) = self.p.types.lit_values.get(v.id)
                {
                    return tagged("negFloat", json!({"bits":value.to_bits().to_string()}));
                }
                if v.op == a::UnOp::Neg
                    && matches!(
                        self.p.types.lit_values.get(v.id),
                        Some(ConstValue::Integer(_))
                    )
                {
                    return tagged("literal", json!({"value":self.literal(v.id)}));
                }
                let inner = self.expr(&v.operand, env);
                if v.op == a::UnOp::Not {
                    tagged("not", json!({"inner":inner}))
                } else {
                    let operand = self.ty(self.p.types.operand_types.get(v.id).unwrap());
                    tagged("neg", json!({"operand":operand,"inner":inner}))
                }
            }
            a::Expr::Binary(v) => {
                let lhs = self.expr(&v.lhs, env);
                let rhs_position =
                    if matches!(v.op, a::BinOp::And | a::BinOp::Or) && position == Position::Tail {
                        Position::Tail
                    } else {
                        Position::Other
                    };
                let rhs = self.expr_at(&v.rhs, env, rhs_position);
                if matches!(v.op, a::BinOp::And | a::BinOp::Or) {
                    tagged(
                        if v.op == a::BinOp::And { "and" } else { "or" },
                        json!({"lhs":lhs,"rhs":rhs}),
                    )
                } else {
                    let operand = self.ty(self.p.types.operand_types.get(v.id).unwrap());
                    tagged(
                        "binary",
                        json!({"op":bin_name(v.op),"operand":operand,"lhs":lhs,"rhs":rhs}),
                    )
                }
            }
            a::Expr::List(v) => {
                let Ty::Con(_, ts) = self.p.types.expr_types.get(v.id).unwrap() else {
                    panic!("list type")
                };
                let elem = self.ty(&ts[0]);
                let mut before = Vec::new();
                let mut after = Vec::new();
                let mut spread = None;
                for e in &v.elems {
                    match e {
                        a::ListElem::Expr(e) => {
                            let value = self.expr(e, env);
                            if spread.is_some() {
                                after.push(value);
                            } else {
                                before.push(value);
                            }
                        }
                        a::ListElem::Spread(e) => {
                            assert!(spread.is_none(), "multiple checked list spreads");
                            spread = Some(self.expr(&e.expr, env));
                        }
                    }
                }
                if let Some(spread) = spread {
                    let id = self
                        .p
                        .resolved
                        .stdlib("Benitoite.List.concatenate")
                        .unwrap();
                    let scheme = self.p.types.decl_types.get(id).unwrap();
                    let effs = vec![Vec::<Value>::new(); scheme.effect_params.len()];
                    let kind = &self.p.resolved.bindings.get(id).unwrap().kind;
                    let (tag, name) = if let BindingKind::Fn = kind {
                        ("funName", fun_name(id))
                    } else if let BindingKind::BuiltinFn(b) = kind {
                        (
                            "primName",
                            builtins::builtin_decl(*b).unwrap().name.to_owned(),
                        )
                    } else {
                        panic!("invalid List.concatenate binding: {kind:?}")
                    };
                    let concat = tagged(tag, json!({"name":name,"tys":[elem.clone()],"effs":effs}));
                    tagged(
                        "listSpread",
                        json!({"elem":elem,"concat":concat,"before":before,"spread":spread,"after":after}),
                    )
                } else {
                    tagged("list", json!({"elem":elem,"elems":before}))
                }
            }
            a::Expr::Lambda(v) => {
                let Ty::Fn(f) = self.p.types.expr_types.get(v.id).unwrap() else {
                    panic!("lambda type")
                };
                let params: Vec<_> = f.params.iter().map(|t| self.ty(t)).collect();
                let ret = self.ty(&f.ret);
                let effects = self.p.types.lambda_effects.get(v.id).unwrap();
                let mut local = env.to_vec();
                local.extend(
                    v.params
                        .iter()
                        .map(|p| SurfaceSlot::Local(self.declaration(p.id))),
                );
                let saved_ret = self.return_ty.replace(f.ret.clone());
                let saved_argument = std::mem::replace(&mut self.placeholder_argument, false);
                let saved_depth = self.placeholder_clause_depth.take();
                for slot in &mut local {
                    if *slot == SurfaceSlot::Continuation {
                        *slot = SurfaceSlot::Ignored;
                    }
                }
                let body = self.block(&v.body, &local, Position::Tail);
                self.return_ty = saved_ret;
                self.placeholder_argument = saved_argument;
                self.placeholder_clause_depth = saved_depth;
                tagged(
                    "lam",
                    json!({"params":params,"ret":ret,"eff":eff(effects),"body":body}),
                )
            }
            a::Expr::If(v) => self.if_expr(v, env, position),
            a::Expr::Match(v) => {
                let scrutinee = self.expr(&v.scrutinee, env);
                let scrutinee_ty = self.node_ty(v.scrutinee.id());
                let arms: Vec<_> = v
                    .arms
                    .iter()
                    .map(|arm| {
                        let mut first = Vec::new();
                        let alts: Vec<_> = arm
                            .patterns
                            .iter()
                            .enumerate()
                            .map(|(j, p)| {
                                let mut bindings = Vec::new();
                                let pat = self.pattern(p, &mut bindings);
                                let ids: Vec<_> = bindings
                                    .iter()
                                    .map(|s| {
                                        let SurfaceSlot::Local(id) = s else {
                                            panic!("pattern slot")
                                        };
                                        *id
                                    })
                                    .collect();
                                if j == 0 {
                                    first = ids.clone();
                                }
                                let mapping = slots(&first, &ids).unwrap_or_else(|| {
                                    self.outside("surface alternative variables");
                                    Vec::new()
                                });
                                json!({"pat":pat,"slots":mapping})
                            })
                            .collect();
                        if alts.is_empty() {
                            self.outside("surface empty alternatives");
                        }
                        let mut local = env.to_vec();
                        local.extend(first.into_iter().map(SurfaceSlot::Local));
                        let guard = arm.guard.as_ref().map(|g| {
                            let saved = self.guard_clause_depth.replace(self.clause_types.len());
                            let guard = self.expr(g, &local);
                            self.guard_clause_depth = saved;
                            guard
                        });
                        let body = self.block(&arm.body, &local, position);
                        tagged("mk", json!({"alts":alts,"guard":guard,"body":body}))
                    })
                    .collect();
                self.coverage.matches.push(json!({"node":v.id.0,
                    "scrutineeTy":scrutinee_ty,
                    "arms":arms.iter().map(|a| {
                        let a = &a["mk"];
                        json!({"alts":a["alts"].as_array().unwrap().iter().map(|p| p["pat"].clone()).collect::<Vec<_>>(),
                            "guarded":!a["guard"].is_null()})
                    }).collect::<Vec<_>>() }));
                tagged(
                    "matchE",
                    json!({"ret":self.annotation(v.id,position,"match"),"scrutinee":scrutinee,"arms":arms}),
                )
            }
            a::Expr::Return(v) => {
                let ret = self.annotation(v.id, position, "return");
                let inner = self.expr_at(
                    &v.value,
                    env,
                    if position == Position::Tail {
                        Position::Tail
                    } else {
                        Position::Other
                    },
                );
                tagged("returnE", json!({"ret":ret,"inner":inner}))
            }
            a::Expr::Interp(v) => {
                let mut parts = vec![tagged("text", json!({"value":v.head}))];
                let mut es = Vec::new();
                let mut converters = Vec::new();
                for s in &v.segments {
                    es.push(self.expr(&s.expr, env));
                    let ty = self.p.types.interp_types.get(s.expr.id()).unwrap();
                    let Ty::Con(TyCon::Builtin(b), args) = ty else {
                        panic!("non-basic interpolation type: {ty:?}")
                    };
                    assert!(args.is_empty());
                    if *b == BuiltinTypeId::STRING {
                        parts.push(json!("stringExpr"));
                    } else {
                        let id = table::interpolation_builtin(*b).unwrap();
                        let name = builtins::builtin_decl(id).unwrap().name;
                        parts.push(tagged("converted", json!({"ty":self.ty(ty)})));
                        converters
                            .push(tagged("primName", json!({"name":name,"tys":[],"effs":[]})));
                    }
                    parts.push(tagged("text", json!({"value":s.tail})));
                }
                tagged(
                    "interpolation",
                    json!({"parts":parts,"es":es,"converters":converters}),
                )
            }
            a::Expr::Record(v) => {
                let adt = self.reference(v.id);
                let fields = self.p.types.adts.get(adt).unwrap().record.as_ref().unwrap();
                let n = fields.len();
                let positions: Vec<_> = v
                    .fields
                    .iter()
                    .map(|f| {
                        let id = self.reference(f.id);
                        fields.iter().position(|decl| decl.binding == id).unwrap()
                    })
                    .collect();
                let tys = if let Some(base) = &v.base {
                    let Ty::Con(TyCon::Adt(data), tys) =
                        self.p.types.expr_types.get(base.id()).unwrap()
                    else {
                        panic!("record base type")
                    };
                    assert_eq!(*data, adt);
                    tys.iter().map(|t| self.ty(t)).collect::<Vec<_>>()
                } else {
                    self.targs(v.id, adt).0
                };
                // base、書いたフィールドの順で走査し、ラムダの注釈も保つ。
                let base = v.base.as_ref().map(|b| self.expr(b, env));
                let args: Vec<_> = v.fields.iter().map(|f| self.expr(&f.value, env)).collect();
                if let Some(base) = base {
                    tagged(
                        "recordUpdate",
                        json!({"name":con_name(adt,0),"tys":tys,"n":n,"positions":positions,"base":base,"args":args}),
                    )
                } else {
                    tagged(
                        "record",
                        json!({"name":con_name(adt,0),"tys":tys,"positions":positions,"args":args}),
                    )
                }
            }
            a::Expr::Try(v) => {
                if self.placeholder_argument {
                    self.outside("known: try in placeholder argument");
                }
                let info = self.p.types.try_kinds.get(v.id).unwrap();
                let Ty::Con(_, ret_args) = &info.ret else {
                    panic!("try return type")
                };
                let ret_args: Vec<_> = ret_args.iter().map(|t| self.ty(t)).collect();
                let inner = self.expr(&v.value, env);
                match info.kind {
                    TryKind::Result => tagged(
                        "tryResult",
                        json!({"retArgs":ret_args,"ok":self.std_ctor("Benitoite.Result.Ok"),"err":self.std_ctor("Benitoite.Result.Error"),"inner":inner}),
                    ),
                    TryKind::Option => tagged(
                        "tryOption",
                        json!({"retArgs":ret_args,"someCon":self.std_ctor("Benitoite.Option.Some"),"noneCon":self.std_ctor("Benitoite.Option.None"),"inner":inner}),
                    ),
                }
            }
            a::Expr::Lazy(v) => {
                let saved_ret = self.return_ty.take();
                let saved_argument = std::mem::replace(&mut self.placeholder_argument, false);
                let saved_depth = self.placeholder_clause_depth.take();
                let local: Vec<_> = env
                    .iter()
                    .map(|s| {
                        if *s == SurfaceSlot::Continuation {
                            SurfaceSlot::Ignored
                        } else {
                            *s
                        }
                    })
                    .collect();
                let body = self.block(&v.body, &local, Position::Other);
                self.return_ty = saved_ret;
                self.placeholder_argument = saved_argument;
                self.placeholder_clause_depth = saved_depth;
                tagged("lazyE", json!({"body":body}))
            }
            a::Expr::Resume(v) => {
                let index = env
                    .iter()
                    .rev()
                    .position(|s| *s == SurfaceSlot::Continuation)
                    .expect(
                        "accepted resume without enclosing continuation (lambda/lazy boundary)",
                    );
                if self
                    .placeholder_clause_depth
                    .is_some_and(|depth| self.clause_types.len() <= depth)
                {
                    self.outside("known: resume in placeholder argument");
                }
                if self
                    .guard_clause_depth
                    .is_some_and(|depth| self.clause_types.len() <= depth)
                {
                    self.known_differences
                        .insert("ガードの中の resume（TODO-190）".to_owned());
                }
                tagged(
                    "resume",
                    json!({"index":index,"inner":self.expr(&v.value, env)}),
                )
            }
            a::Expr::With(v) => {
                let body_position = if position == Position::Other {
                    Position::Other
                } else {
                    Position::Result
                };
                self.with_binds(&v.binds, &v.body, env, body_position)
            }
            a::Expr::Handle(v) => {
                let body = self.block(&v.body, env, Position::Other);
                let info = self.p.types.handlers.get(v.id).unwrap();
                assert_eq!(v.clauses.len(), info.clauses.len());
                let clauses: Vec<_> = v.clauses.iter().zip(&info.clauses).map(|(clause, info)| {
                    let mut local = env.to_vec();
                    local.extend(clause.params.iter().map(|p| match p.name {
                        Some(_) => SurfaceSlot::Local(self.declaration(p.id)),
                        None => SurfaceSlot::Ignored,
                    }));
                    local.push(SurfaceSlot::Continuation);
                    let ntys = self.p.types.decl_types.get(info.op).unwrap().type_params.len();
                    self.clause_types.push((clause.id, ntys));
                    let body = self.block(&clause.body, &local, Position::Other);
                    self.clause_types.pop();
                    json!({"op":self.op_ref(info.op),"arity":clause.params.len(),"ntys":ntys,"body":body})
                }).collect();
                tagged("handleE", json!({"body":body,"clauses":clauses}))
            }
            a::Expr::Error(_) => panic!("checked error expression"),
        }
    }
    fn with_binds(
        &mut self,
        binds: &[a::WithBind],
        block: &a::Block,
        env: &[SurfaceSlot],
        position: Position,
    ) -> Value {
        let Some((first, rest)) = binds.split_first() else {
            return self.block(block, env, position);
        };
        let ty = self.node_ty(first.id);
        let o = ty["opaque"]["name"]
            .as_str()
            .expect("resource is opaque")
            .to_owned();
        let bound = self.expr(&first.value, env);
        let mut local = env.to_vec();
        local.push(SurfaceSlot::Local(self.declaration(first.id)));
        let body = if rest.is_empty() {
            self.block(block, &local, position)
        } else {
            let expr = self.with_binds(rest, block, &local, position);
            tagged("last", json!({"expr":expr}))
        };
        tagged("withE", json!({"o":o,"bound":bound,"body":body}))
    }
    fn call(&mut self, v: &a::CallExpr, env: &[SurfaceSlot]) -> Value {
        let mut ctor = None;
        if let a::Expr::Name(n) = v.callee.as_ref() {
            let id = self.reference(n.id);
            if let BindingKind::Ctor { data, tag } = self.p.resolved.bindings.get(id).unwrap().kind
            {
                if self.p.types.adts.get(data).unwrap().record.is_some() {
                    self.outside("record");
                }
                let (tys, _) = self.targs(n.id, id);
                ctor = Some((con_name(data, tag), tys));
            }
        }
        let callee = if ctor.is_none() {
            self.expr(&v.callee, env)
        } else {
            self.node_ty(v.callee.id());
            json!("unit")
        };
        let holes = v.args.iter().any(|a| matches!(a, a::Arg::Placeholder(_)));
        let args: Vec<_> = v
            .args
            .iter()
            .map(|a| match a {
                a::Arg::Expr(e) => {
                    let saved_argument = self.placeholder_argument;
                    self.placeholder_argument |= holes;
                    let saved_depth = self.placeholder_clause_depth;
                    if holes {
                        self.placeholder_clause_depth = Some(self.clause_types.len());
                    }
                    let inner = self.expr(e, env);
                    self.placeholder_argument = saved_argument;
                    self.placeholder_clause_depth = saved_depth;
                    if holes {
                        tagged("expr", json!({"inner":inner}))
                    } else {
                        inner
                    }
                }
                a::Arg::Placeholder(p) => tagged("hole", json!({"ty":self.node_ty(p.id)})),
            })
            .collect();
        match (ctor, holes) {
            (Some((name, tys)), false) => {
                tagged("conCall", json!({"name":name,"tys":tys,"args":args}))
            }
            (Some((name, tys)), true) => {
                tagged("partialCon", json!({"name":name,"tys":tys,"args":args}))
            }
            (None, false) => tagged("call", json!({"callee":callee,"args":args})),
            (None, true) => {
                let Ty::Fn(f) = self.p.types.expr_types.get(v.id).unwrap() else {
                    panic!("partial type")
                };
                let ret = self.ty(&f.ret);
                let e = self.p.types.lambda_effects.get(v.id).unwrap();
                tagged(
                    "partialCall",
                    json!({"callee":callee,"args":args,"ret":ret,"eff":eff(e)}),
                )
            }
        }
    }
    fn if_expr(&mut self, v: &a::IfExpr, env: &[SurfaceSlot], position: Position) -> Value {
        self.node_ty(v.id);
        let cond = self.expr(&v.cond, env);
        let yes = self.block(&v.then_block, env, position);
        match &v.else_branch {
            Some(a::ElseBranch::Block(b)) => {
                let no = self.block(b, env, position);
                tagged("ite", json!({"cond":cond,"yes":yes,"no":no}))
            }
            Some(a::ElseBranch::If(b)) => {
                let no = self.if_expr(b, env, position);
                tagged("elseIf", json!({"cond":cond,"yes":yes,"no":no}))
            }
            None => tagged("ifOnly", json!({"cond":cond,"yes":yes})),
        }
    }
    fn block(&mut self, b: &a::Block, env: &[SurfaceSlot], position: Position) -> Value {
        self.statements(&b.stmts, env, position)
    }
    fn statements(&mut self, ss: &[a::Stmt], env: &[SurfaceSlot], position: Position) -> Value {
        let Some((first, rest)) = ss.split_first() else {
            return json!("empty");
        };
        match first {
            a::Stmt::Expr(e) => {
                let expr = self.expr_at(
                    e,
                    env,
                    if rest.is_empty() {
                        position
                    } else {
                        Position::Other
                    },
                );
                if rest.is_empty() {
                    tagged("last", json!({"expr":expr}))
                } else {
                    let rest = self.statements(rest, env, position);
                    tagged("seq", json!({"expr":expr,"rest":rest}))
                }
            }
            a::Stmt::Bind(b) => {
                let expr = self.expr(&b.value, env);
                let ty = self.node_ty(b.id);
                let shadow = b.mode == a::BindMode::Shadow;
                let mut local = env.to_vec();
                let pattern = self.pattern(&b.pattern, &mut local);
                let last = rest.is_empty();
                // check_body が is_irrefutable を呼ぶ束縛だけを収集する。
                if !matches!(&b.pattern, a::Pattern::Var(_) | a::Pattern::Wildcard(_)) {
                    let kind = if last { "lastPat" } else { "bindPat" };
                    self.coverage
                        .bindings
                        .push(json!({"node":b.id.0,"kind":kind,"ty":ty,"pattern":pattern}));
                }
                let rest = if last {
                    json!("empty")
                } else {
                    self.statements(rest, &local, position)
                };
                match &b.pattern {
                    a::Pattern::Var(_) => {
                        if last {
                            tagged("lastBind", json!({"shadow":shadow,"ty":ty,"expr":expr}))
                        } else {
                            tagged(
                                "bind",
                                json!({"shadow":shadow,"ty":ty,"expr":expr,"rest":rest}),
                            )
                        }
                    }
                    a::Pattern::Wildcard(_) => {
                        if last {
                            tagged("lastDiscard", json!({"expr":expr}))
                        } else {
                            tagged("discard", json!({"expr":expr,"rest":rest}))
                        }
                    }
                    a::Pattern::Lit(_)
                    | a::Pattern::Unit(_)
                    | a::Pattern::Ctor(_)
                    | a::Pattern::Record(_)
                    | a::Pattern::Range(_)
                    | a::Pattern::List(_)
                    | a::Pattern::Error(_) => {
                        if last {
                            tagged(
                                "lastPat",
                                json!({"shadow":shadow,"pattern":pattern,"ty":ty,"expr":expr}),
                            )
                        } else {
                            tagged(
                                "bindPat",
                                json!({"shadow":shadow,"pattern":pattern,"ty":ty,"expr":expr,"rest":rest}),
                            )
                        }
                    }
                }
            }
            a::Stmt::Error(_) => panic!("checked error statement"),
        }
    }
}

fn bin_name(op: a::BinOp) -> &'static str {
    match op {
        a::BinOp::Add => "add",
        a::BinOp::Sub => "sub",
        a::BinOp::Mul => "mul",
        a::BinOp::Div => "div",
        a::BinOp::IntDiv => "intDiv",
        a::BinOp::Mod => "mod",
        a::BinOp::Eq => "eq",
        a::BinOp::Ne => "ne",
        a::BinOp::Lt => "lt",
        a::BinOp::Le => "le",
        a::BinOp::Gt => "gt",
        a::BinOp::Ge => "ge",
        a::BinOp::And => "and",
        a::BinOp::Or => "or",
    }
}

pub fn operators() -> Vec<Value> {
    let mut result: Vec<_> = table::OPERATORS
        .iter()
        .map(|(kind, ty, name)| {
            let op = match kind {
                c::OperatorKind::Add => "add",
                c::OperatorKind::Sub => "sub",
                c::OperatorKind::Mul => "mul",
                c::OperatorKind::Div => "div",
                c::OperatorKind::IntDiv => "intDiv",
                c::OperatorKind::Mod => "mod",
                c::OperatorKind::Lt => "lt",
                c::OperatorKind::Le => "le",
                c::OperatorKind::Gt => "gt",
                c::OperatorKind::Ge => "ge",
                c::OperatorKind::Neg => "neg",
            };
            let id = table::operator_builtin(*kind, *ty).unwrap();
            assert_eq!(builtins::builtin_decl(id).unwrap().name, *name);
            json!({"op":op,"operand":tagged("base",json!({"name":ty.def().unwrap().name})),"name":name})
        })
        .collect();
    for (op, name) in [("eq", table::EQUALITY), ("ne", table::INEQUALITY)] {
        let id = table::equality_builtin(op == "ne").unwrap();
        let s = table::builtin_scheme(id).unwrap();
        assert!(s.effect_params.is_empty(), "equality has effect variables");
        assert_eq!(builtins::builtin_decl(id).unwrap().name, name);
        result.push(json!({"op":op,"operand":null,"name":name}));
    }
    result
}
struct Core<'a> {
    surface: Surface<'a>,
    lambda_effects: Vec<Value>,
    program: &'a c::CoreProgram,
    constant_stack: BTreeSet<BindingId>,
}
impl Core<'_> {
    fn dictionary(&mut self, d: &c::DictVal, env: &[CoreSlot]) -> Value {
        match &d.kind {
            c::DictKind::Impl {
                impl_decl,
                tys,
                args,
            } => {
                if let Some(reason) =
                    unsupported_target(&self.surface.p.types.impls.get(*impl_decl).unwrap().target)
                {
                    return unsupported(reason);
                }
                let tys: Vec<_> = tys.iter().map(|t| self.surface.type_arg(t)).collect();
                let args: Vec<_> = args.iter().map(|d| self.dictionary(d, env)).collect();
                tagged(
                    "dict",
                    json!({"name":impl_name(*impl_decl),"tys":tys,"args":args}),
                )
            }
            c::DictKind::Param(var) => {
                match env.iter().rev().position(|s| *s == CoreSlot::Local(*var)) {
                    Some(index) => tagged("var", json!({"index":index})),
                    None => unsupported("unbound core dictionary"),
                }
            }
            c::DictKind::ImplParam(i) => match env
                .iter()
                .rev()
                .position(|s| *s == CoreSlot::ImplDictionary(usize::try_from(*i).unwrap()))
            {
                Some(index) => tagged("var", json!({"index":index})),
                None => unsupported("unbound implementation dictionary"),
            },
            c::DictKind::Super { of, index } => {
                assert_eq!(
                    self.surface.p.types.traits.get(of.class).unwrap().supers
                        [usize::try_from(*index).unwrap()],
                    d.class
                );
                tagged(
                    "super",
                    json!({"dict":self.dictionary(of,env),"cls":class_name(d.class)}),
                )
            }
        }
    }
    fn constant(&self, v: &c::Const) -> Value {
        match v {
            c::Const::Int(n) => constant(&ConstValue::Integer(*n)),
            c::Const::Float(n) => constant(&ConstValue::Float(*n)),
            c::Const::Str(n) => constant(&ConstValue::String(n.clone())),
            c::Const::Char(n) => constant(&ConstValue::Character(*n)),
            c::Const::Bool(n) => constant(&ConstValue::Boolean(*n)),
            c::Const::Unit => json!("unit"),
            c::Const::Byte(_) => unsupported("Byte literal"),
            c::Const::Decimal(n) => constant(&ConstValue::Decimal(*n)),
        }
    }
    fn value(&mut self, v: &c::CoreVal, env: &[CoreSlot]) -> Value {
        match &v.kind {
            c::ValKind::Var(id) => {
                match env.iter().rev().position(|v| *v == CoreSlot::Local(*id)) {
                    Some(index) => tagged("var", json!({"index":index})),
                    None => unsupported("unbound core variable"),
                }
            }
            c::ValKind::Const(c) => tagged("const", json!({"value":self.constant(c)})),
            c::ValKind::TopFn { def, targs } => {
                let (tys, effs) = self.surface.args(targs);
                tagged(
                    "fnRef",
                    json!({"name":fun_name(*def),"tys":tys,"effs":effs}),
                )
            }
            c::ValKind::Builtin { id, targs, .. } => {
                let (tys, effs) = self.surface.args(targs);
                tagged(
                    "prim",
                    json!({"name":builtins::builtin_decl(*id).unwrap().name,"tys":tys,"effs":effs}),
                )
            }
            c::ValKind::Lambda(l) => {
                let Ty::Fn(f) = &v.ty else {
                    panic!("core lambda type")
                };
                // 実際のラムダだけを数える。裸の直接の頭にはラムダがなく、
                // 括弧で包んだ辞書付きの名前は値化したラムダとしてここを通る。
                self.lambda_effects.push(eff(&f.effects));
                let params: Vec<_> = l.params.iter().map(|p| self.surface.ty(&p.ty)).collect();
                let mut local = env.to_vec();
                local.extend(l.params.iter().map(|p| CoreSlot::Local(p.id)));
                let body = self.comp(&l.body, &local);
                tagged("lam", json!({"params":params,"body":body}))
            }
            c::ValKind::Ctor {
                adt,
                tag,
                tys,
                args,
            } => {
                let tys: Vec<_> = tys.iter().map(|t| self.surface.ty(t)).collect();
                let args: Vec<_> = args.iter().map(|v| self.value(v, env)).collect();
                tagged(
                    "con",
                    json!({"name":con_name(*adt,*tag),"tys":tys,"args":args}),
                )
            }
            c::ValKind::List(vs) => {
                let elems: Vec<_> = vs.iter().map(|v| self.value(v, env)).collect();
                tagged("list", json!({"elems":elems}))
            }
            c::ValKind::ConstRef(_) => {
                self.surface.outside("constant reference outside Return");
                unsupported("constant reference outside Return")
            }
            c::ValKind::Op { op, targs } => {
                assert!(
                    targs.effects.is_empty(),
                    "core operation has effect arguments: {op:?}"
                );
                let (tys, _) = self.surface.args(targs);
                tagged("op", json!({"name":format!("op:{}",op.0),"tys":tys}))
            }
        }
    }
    fn pattern(&self, p: &c::CorePat, vars: &mut Vec<c::VarId>) -> Value {
        match p {
            c::CorePat::Wild => json!("wild"),
            c::CorePat::Var(v) => {
                vars.push(*v);
                json!("var")
            }
            c::CorePat::Const(c) => tagged("const", json!({"value":self.constant(c)})),
            c::CorePat::Ctor { adt, tag, args } => {
                let args: Vec<_> = args.iter().map(|p| self.pattern(p, vars)).collect();
                tagged("con", json!({"name":con_name(*adt,*tag),"args":args}))
            }
            c::CorePat::Range { lo, hi } => tagged(
                "range",
                json!({"lo":self.constant(lo),"hi":self.constant(hi)}),
            ),
            c::CorePat::List {
                before,
                rest,
                after,
            } => {
                let before: Vec<_> = before.iter().map(|p| self.pattern(p, vars)).collect();
                let rest = rest.as_ref().map(|r| match r.var {
                    Some(v) => {
                        vars.push(v);
                        "bind"
                    }
                    None => "skip",
                });
                let after: Vec<_> = after.iter().map(|p| self.pattern(p, vars)).collect();
                tagged("list", json!({"before":before,"rest":rest,"after":after}))
            }
        }
    }
    fn comp(&mut self, c: &c::Comp, env: &[CoreSlot]) -> Value {
        match &c.kind {
            c::CompKind::Return(v) => {
                if let c::ValKind::ConstRef(id) = v.kind {
                    assert!(
                        self.constant_stack.insert(id),
                        "cyclic core constant: {id:?}"
                    );
                    let definition = self
                        .program
                        .consts
                        .iter()
                        .find(|d| d.binding == id)
                        .expect("missing core constant");
                    // 定数の本体は閉じている。使用位置の型・変数の番号を引き継がない。
                    let mut surface = Surface::new(self.surface.p, None, Vec::new());
                    surface.closed_constant = true;
                    surface.constants = self.surface.constants;
                    let saved = std::mem::replace(&mut self.surface, surface);
                    let body = self.comp(&definition.body, &[]);
                    let inside = std::mem::replace(&mut self.surface, saved);
                    self.surface.outside.extend(inside.outside);
                    self.constant_stack.remove(&id);
                    body
                } else {
                    tagged("ret", json!({"value":self.value(v,env)}))
                }
            }
            c::CompKind::Let { var, bound, body } => {
                let bound = self.comp(bound, env);
                let mut local = env.to_vec();
                local.push(CoreSlot::Local(var.id));
                let body = self.comp(body, &local);
                tagged("letIn", json!({"bound":bound,"body":body}))
            }
            c::CompKind::App { func, dicts, args } => {
                // 表層の範囲判定の漏れは unsupported の不一致として残す。
                // funDicts は Fn の頭だけを表し、prim・op・field の辞書は表さない。
                if !dicts.is_empty() {
                    match &func.kind {
                        c::ValKind::Builtin { .. } => {
                            return unsupported("constrained head: builtin");
                        }
                        c::ValKind::Op { .. } => return unsupported("constrained head: operation"),
                        c::ValKind::TopFn { def, .. }
                            if matches!(
                                self.surface.p.resolved.bindings.get(*def).unwrap().kind,
                                BindingKind::Field { .. }
                            ) =>
                        {
                            return unsupported("constrained head: field");
                        }
                        c::ValKind::Var(_)
                        | c::ValKind::Const(_)
                        | c::ValKind::TopFn { .. }
                        | c::ValKind::Lambda(_)
                        | c::ValKind::Ctor { .. }
                        | c::ValKind::List(_)
                        | c::ValKind::ConstRef(_) => {}
                    }
                }
                let callee = self.value(func, env);
                let mut values: Vec<_> = dicts.iter().map(|d| self.dictionary(d, env)).collect();
                values.extend(args.iter().map(|v| self.value(v, env)));
                let args = values;
                tagged("app", json!({"callee":callee,"args":args}))
            }
            c::CompKind::If {
                cond,
                then_branch,
                else_branch,
            } => {
                let cond = self.value(cond, env);
                let yes = self.comp(then_branch, env);
                let no = self.comp(else_branch, env);
                tagged("ite", json!({"cond":cond,"yes":yes,"no":no}))
            }
            c::CompKind::Match {
                scrutinee,
                rows,
                arms,
            } => {
                // 連続した同じ arm をまとめる。欠落・再出現・番号の飛びは専用の理由で数える。
                let mut groups: Vec<Vec<&c::MatchRow>> = Vec::new();
                for row in rows {
                    let index = usize::try_from(row.arm).unwrap();
                    if index == groups.len() {
                        groups.push(vec![row]);
                    } else if index.checked_add(1) == Some(groups.len()) {
                        groups.last_mut().unwrap().push(row);
                    } else {
                        return self.surface.outside("core match arm order");
                    }
                }
                if groups.len() != arms.len() {
                    return self.surface.outside("core match missing arm rows");
                }
                let scrutinee = self.value(scrutinee, env);
                let arms: Vec<_> = groups
                    .iter()
                    .zip(arms)
                    .map(|(rows, arm)| {
                        let written: Vec<_> = arm.vars.iter().map(|v| v.id).collect();
                        let mut first = Vec::new();
                        let alts: Vec<_> = rows
                            .iter()
                            .enumerate()
                            .map(|(j, row)| {
                                let mut vars = Vec::new();
                                let pat = self.pattern(&row.pattern, &mut vars);
                                if j == 0 {
                                    first = vars.clone();
                                }
                                // arm.vars のソース順は使わず、集合と重複だけを検査する。
                                if slots(&written, &vars).is_none() {
                                    self.surface.outside("core match arm variables");
                                }
                                let mapping = slots(&first, &vars).unwrap_or_else(|| {
                                    self.surface.outside("core alternative variables");
                                    Vec::new()
                                });
                                json!({"pat":pat,"slots":mapping})
                            })
                            .collect();
                        let mut local = env.to_vec();
                        local.extend(first.into_iter().map(CoreSlot::Local));
                        // ラムダの注釈はガード、本体の順。ガードは分岐ごとに一度だけ出す。
                        let guard = arm.guard.as_ref().map(|g| self.comp(g, &local));
                        let body = self.comp(&arm.body, &local);
                        tagged("mk", json!({"alts":alts,"guard":guard,"body":body}))
                    })
                    .collect();
                tagged("matchC", json!({"scrutinee":scrutinee,"arms":arms}))
            }
            c::CompKind::Escape(v) => tagged("escape", json!({"value":self.value(v,env)})),
            c::CompKind::Method(m) => {
                let dict = self.dictionary(&m.dict, env);
                let cl = self.surface.p.types.traits.get(m.dict.class).unwrap();
                let name = method_name(cl.methods[usize::try_from(m.method).unwrap()]);
                let (tys, effs) = self.surface.args(&m.targs);
                let mut args: Vec<_> = m.dicts.iter().map(|d| self.dictionary(d, env)).collect();
                args.extend(m.args.iter().map(|v| self.value(v, env)));
                tagged(
                    "meth",
                    json!({"dict":dict,"name":name,"tys":tys,"effs":effs,"args":args}),
                )
            }
            c::CompKind::Use { resource, body } => {
                let resource = self.value(resource, env);
                let body = self.comp(body, env);
                tagged("use", json!({"resource":resource,"body":body}))
            }
            c::CompKind::Lazy { body, .. } => tagged("lazyC", json!({"body":self.comp(body,env)})),
            c::CompKind::Handle(h) => {
                let body = self.comp(&h.body, env);
                let clauses: Vec<_> = h.clauses.iter().map(|clause| {
                    let mut local = env.to_vec();
                    local.extend(clause.params.iter().map(|p| CoreSlot::Local(p.id)));
                    local.push(CoreSlot::Continuation(clause.cont.id));
                    let ntys = self.program.schemes.get(clause.op).unwrap().type_params.len();
                    self.surface.clause_types.push((clause.node, ntys));
                    let body = self.comp(&clause.body, &local);
                    self.surface.clause_types.pop();
                    json!({"op":self.surface.op_ref(clause.op),"arity":clause.params.len(),"ntys":ntys,"body":body})
                }).collect();
                tagged("handle", json!({"body":body,"clauses":clauses}))
            }
            c::CompKind::Resume { cont, value } => {
                let index = env
                    .iter()
                    .rev()
                    .position(|s| *s == CoreSlot::Continuation(*cont))
                    .expect("core continuation not in environment");
                tagged(
                    "resume",
                    json!({"index":index,"value":self.value(value, env)}),
                )
            }
        }
    }
}

// Γ の辞書は制約の宣言順。実装の d̄ はメソッド自身の辞書より外側。
fn definition(
    p: &CheckedProgram,
    core: &c::CoreProgram,
    d: &c::CoreDef,
    decl: &a::FnDecl,
    implementation: Option<(&c::ImplDef<c::Comp>, BindingId)>,
    constants: &ConstantTable,
    coverage: &mut CoverageExport,
) -> Value {
    let scheme = p.types.decl_types.get(d.binding).unwrap();
    let (type_order, impl_count) = match implementation {
        None => (Vec::new(), 0),
        Some((i, _)) => {
            let b = i.type_params.len();
            let g = scheme.type_params.len() - b;
            (
                (0..b).map(|j| g + j).chain(0..g).collect(),
                i.dict_params.len(),
            )
        }
    };
    let mut s = Surface::new(p, Some(d.ret.clone()), type_order);
    s.constants = Some(constants);
    if let Some((i, _)) = implementation
        && let Some(reason) = unsupported_target(&i.target)
    {
        s.outside(reason);
    }
    let header = s.header(scheme);
    assert_eq!(
        scheme.class_constraints[impl_count..],
        d.dict_params
            .iter()
            .map(|d| d.constraint)
            .collect::<Vec<_>>()
    );
    let dict_params = s.dict_params(&scheme.class_constraints[impl_count..]);
    let mut env: Vec<_> = (0..scheme.class_constraints.len())
        .map(SurfaceSlot::Dictionary)
        .collect();
    env.extend(
        decl.params
            .iter()
            .map(|p| SurfaceSlot::Local(s.declaration(p.id))),
    );
    let body = s.block(decl.body.as_ref().unwrap(), &env, Position::Tail);
    coverage.matches.append(&mut s.coverage.matches);
    coverage.bindings.append(&mut s.coverage.bindings);
    let name = format!("{} ({})", d.name, fun_name(d.binding));
    if !s.outside.is_empty() {
        return json!({"name":name,"annotations":s.annotations,"scope":tagged("outOfScope",json!({"elements":s.outside}))});
    }
    let annotations = json!(s.annotations);
    let surface = json!({"header":header,"dictParams":dict_params,"body":body,
        "implementation":implementation.map(|(i,_)| impl_name(i.impl_decl)),
        "method":implementation.map(|(_,m)| method_name(m)),"supers":[]});
    let known_differences = json!(s.known_differences);
    let (core, core_outside) = core_definition(s, core, d, impl_count);
    if !core_outside.is_empty() {
        return json!({"name":name,"annotations":annotations,"scope":tagged("outOfScope",json!({"elements":core_outside}))});
    }
    json!({"name":name,"annotations":annotations,"knownDifferences":known_differences,"scope":tagged("inScope",json!({"surface":surface,"core":core}))})
}

fn core_definition(
    surface: Surface<'_>,
    core: &c::CoreProgram,
    d: &c::CoreDef,
    impl_count: usize,
) -> (Value, BTreeSet<String>) {
    let mut c = Core {
        surface,
        lambda_effects: Vec::new(),
        program: core,
        constant_stack: BTreeSet::new(),
    };
    let mut actual_scheme = core.schemes.get(d.binding).unwrap().clone();
    assert_eq!(d.type_params.len(), actual_scheme.type_params.len());
    assert_eq!(d.effect_params.len(), actual_scheme.effect_params.len());
    actual_scheme.params = d.params.iter().map(|p| p.ty.clone()).collect();
    actual_scheme.ret = d.ret.clone();
    actual_scheme.effects = d.eff.clone();
    let mut header = c.surface.header(&actual_scheme);
    let mut params: Vec<_> = d
        .dict_params
        .iter()
        .map(|d| c.surface.dict_ty(&d.constraint))
        .collect();
    params.extend(header["params"].as_array().unwrap().clone());
    header["params"] = json!(params);
    let mut env: Vec<_> = (0..impl_count).map(CoreSlot::ImplDictionary).collect();
    env.extend(d.dict_params.iter().map(|d| CoreSlot::Local(d.var)));
    env.extend(d.params.iter().map(|p| CoreSlot::Local(p.id)));
    let body = c.comp(&d.body, &env);
    // 明示した境界条件だけを対象外へ戻す。ほかのコアの書き出し漏れは不一致として残す。
    let core_outside = c
        .surface
        .outside
        .iter()
        .filter(|reason| {
            matches!(
                reason.as_str(),
                "constant reference outside Return"
                    | "core match arm order"
                    | "core match missing arm rows"
                    | "core match arm variables"
                    | "core alternative variables"
            )
        })
        .cloned()
        .collect();
    let body = if c.surface.outside.is_empty() {
        body
    } else {
        unsupported(&c.surface.outside.into_iter().collect::<Vec<_>>().join(","))
    };
    (
        json!({"header":header,"body":body,"lambdaEffects":c.lambda_effects,"supers":[]}),
        core_outside,
    )
}

fn getter_definition(
    p: &CheckedProgram,
    core: &c::CoreProgram,
    d: &c::CoreDef,
    record: BindingId,
    index: u32,
) -> Value {
    let mut s = Surface::new(p, Some(d.ret.clone()), Vec::new());
    let adt = p.types.adts.get(record).unwrap();
    let constructor = adt.ctors.first().unwrap();
    assert_eq!(constructor.tag, 0);
    let fields = adt.record.as_ref().unwrap();
    assert_eq!(fields[usize::try_from(index).unwrap()].binding, d.binding);
    assert!(d.dict_params.is_empty());
    let args: Vec<_> = constructor.fields.iter().map(|t| s.ty(t)).collect();
    let decl = json!({"data":data_name(record),"ntys":adt.type_params.len(),"args":args});
    let name = format!("{} ({})", d.name, fun_name(d.binding));
    if !s.outside.is_empty() {
        return json!({"name":name,"annotations":s.annotations,"scope":tagged("outOfScope",json!({"elements":s.outside}))});
    }
    let annotations = json!(s.annotations);
    let (actual, core_outside) = core_definition(s, core, d, 0);
    assert!(
        core_outside.is_empty(),
        "constant reference in generated accessor"
    );
    json!({"name":name,"annotations":annotations,"scope":tagged("accessor",json!({
        "name":fun_name(d.binding),"con":con_name(record,0),"k":index,"decl":decl,"core":actual}))})
}

// 表層の本体は名前だけを保持する。依存先の範囲判定は使用時に伝播する。
fn constant_table(
    p: &CheckedProgram,
    core: &c::CoreProgram,
    coverage: &mut CoverageExport,
) -> ConstantTable {
    let mut entries = BTreeMap::new();
    for d in &core.consts {
        let decl = p
            .asts
            .iter()
            .flat_map(|m| &m.decls)
            .find_map(|v| {
                if let a::Item::Const(c) = &v.item
                    && p.resolved.decls.get(c.id) == Some(&d.binding)
                {
                    Some(c)
                } else {
                    None
                }
            })
            .expect("missing constant AST");
        assert_eq!(p.types.decl_types.get(d.binding).unwrap().ret, d.ty);
        let mut s = Surface::new(p, None, Vec::new());
        s.closed_constant = true;
        let ty = s.ty(&d.ty);
        let body = s.expr(&decl.value, &[]);
        coverage.matches.append(&mut s.coverage.matches);
        coverage.bindings.append(&mut s.coverage.bindings);
        assert!(
            entries
                .insert(
                    d.binding,
                    ConstantEntry {
                        ty,
                        body,
                        references: s.constant_references,
                        outside: s.outside,
                    }
                )
                .is_none(),
            "duplicate constant"
        );
    }
    let mut table = ConstantTable(entries);
    let mut cache = BTreeMap::new();
    for id in table.0.keys() {
        table.reasons(*id, &mut BTreeSet::new(), &mut cache);
    }
    for (id, reasons) in cache {
        table.0.get_mut(&id).unwrap().outside = reasons;
    }
    table
}

pub fn definitions(
    p: &CheckedProgram,
    core: &c::CoreProgram,
) -> (Vec<Value>, Value, CoverageExport) {
    let mut coverage = CoverageExport::default();
    let constants = constant_table(p, core, &mut coverage);
    let mut result = Vec::new();
    for d in &core.defs {
        if d.origin != c::DefOrigin::User {
            continue;
        }
        if let c::DefKind::FieldGetter { record, index } = d.kind {
            result.push(getter_definition(p, core, d, record, index));
            continue;
        }
        if d.kind != c::DefKind::Fn {
            continue;
        }
        let decl = p
            .asts
            .iter()
            .flat_map(|m| &m.decls)
            .find_map(|v| {
                if let a::Item::Fn(f) = &v.item
                    && p.resolved.decls.get(f.id) == Some(&d.binding)
                {
                    Some(f.as_ref())
                } else {
                    None
                }
            })
            .expect("missing user AST function");
        result.push(definition(
            p,
            core,
            d,
            decl,
            None,
            &constants,
            &mut coverage,
        ));
    }
    for i in &core.impls {
        if i.origin != c::DefOrigin::User {
            continue;
        }
        let decl = p
            .asts
            .iter()
            .flat_map(|m| &m.decls)
            .find_map(|v| {
                if let a::Item::Impl(d) = &v.item
                    && d.id == i.impl_decl
                {
                    Some(d)
                } else {
                    None
                }
            })
            .expect("missing user AST implementation");
        let cl = p.types.traits.get(i.class).unwrap();
        for (d, m) in i.methods.iter().zip(&cl.methods) {
            let f = decl
                .fns
                .iter()
                .find(|f| p.resolved.decls.get(f.decl.id) == Some(&d.binding))
                .unwrap();
            result.push(definition(
                p,
                core,
                d,
                &f.decl,
                Some((i, *m)),
                &constants,
                &mut coverage,
            ));
        }
        // 上位辞書は、メソッドの範囲判定と独立した一単位。
        let info = p.types.impls.get(i.impl_decl).unwrap();
        let mut s = Surface::new(p, None, Vec::new());
        if let Some(reason) = unsupported_target(&i.target) {
            s.outside(reason);
        }
        let scheme = Scheme {
            type_params: info.type_params.clone(),
            effect_params: Vec::new(),
            class_constraints: Vec::new(),
            params: Vec::new(),
            ret: Ty::Con(TyCon::Builtin(BuiltinTypeId::UNIT), Vec::new()),
            effects: EffectSet::empty(),
            wrote_io_all: false,
        };
        let header = s.header(&scheme);
        let env: Vec<_> = (0..info.class_constraints.len())
            .map(SurfaceSlot::Dictionary)
            .collect();
        let supers: Vec<_> = cl
            .supers
            .iter()
            .zip(&info.supers)
            .map(|(cl, d)| json!([class_name(*cl), s.dictionary(d, &env)]))
            .collect();
        let name = format!("{} supers ({})", i.name, impl_name(i.impl_decl));
        if !s.outside.is_empty() {
            result.push(json!({"name":name,"annotations":{},"scope":tagged("outOfScope",json!({"elements":s.outside}))}));
            continue;
        }
        let surface = json!({"header":header,"dictParams":[],"body":"empty","implementation":impl_name(i.impl_decl),"method":null,"supers":supers});
        let mut c = Core {
            surface: s,
            lambda_effects: Vec::new(),
            program: core,
            constant_stack: BTreeSet::new(),
        };
        // 上位辞書の単位の頭は共通の実装シグネチャ。脱糖の比較対象は supers の値。
        let header = c.surface.header(&scheme);
        let env: Vec<_> = (0..i.dict_params.len())
            .map(CoreSlot::ImplDictionary)
            .collect();
        let supers: Vec<_> = cl
            .supers
            .iter()
            .zip(&i.supers)
            .map(|(cl, d)| json!([class_name(*cl), c.dictionary(d, &env)]))
            .collect();
        let body = if c.surface.outside.is_empty() {
            tagged(
                "ret",
                json!({"value":tagged("const",json!({"value":"unit"}))}),
            )
        } else {
            unsupported("unsupported core implementation supers")
        };
        let core = json!({"header":header,"body":body,"lambdaEffects":[],"supers":supers});
        result.push(json!({"name":name,"annotations":{},"scope":tagged("inScope",json!({"surface":surface,"core":core}))}));
    }
    for definition in &mut result {
        definition
            .as_object_mut()
            .unwrap()
            .entry("knownDifferences")
            .or_insert_with(|| json!([]));
    }
    (result, constants.json(), coverage)
}

/// 表は一度だけ出す。コアの表は型検査の写しなので、写した対応はここで確かめる。
/// 標準ライブラリがソースで宣言した利用者のエフェクトも含む。
pub fn operation_tables(p: &CheckedProgram, core: &c::CoreProgram) -> Value {
    let mut surface = Surface::new(p, None, Vec::new());
    let mut ops = Vec::new();
    let mut prim_ops = BTreeMap::new();
    let mut seen = BTreeSet::new();
    for op in &core.ops {
        assert!(seen.insert(op.binding), "duplicate core operation");
        let BindingKind::Op { effect, index } = p.resolved.bindings.get(op.binding).unwrap().kind
        else {
            panic!("core operation binding is not an operation");
        };
        let effect = p.types.effects.get(effect).unwrap();
        assert_eq!(effect.ops[usize::try_from(index).unwrap()], op.binding);
        assert_eq!(effect.name, op.effect);
        assert_eq!(op.builtin.as_ref(), p.resolved.builtin_ops.get(op.binding));
        let scheme = p.types.decl_types.get(op.binding).unwrap();
        assert_eq!(core.schemes.get(op.binding).unwrap(), scheme);
        assert_eq!(usize::try_from(op.arity).unwrap(), scheme.params.len());
        assert!(
            scheme.effect_params.is_empty(),
            "operation declares effect parameters"
        );
        if let Some(b) = op.builtin {
            let name = builtins::builtin_decl(b).unwrap().name;
            prim_ops.insert(
                name.to_owned(),
                json!({"name":name,"arity":scheme.params.len(),"ntys":scheme.type_params.len()}),
            );
        } else {
            let EffectName::User(effect) = op.effect else {
                panic!("non-builtin operation in builtin effect");
            };
            ops.push(json!({"name":format!("op:{}",op.binding.0),"eff":format!("effect:{}",effect.0),"header":surface.header(scheme)}));
        }
    }
    let effects: Vec<_> = p.types.effects.iter().filter_map(|(_, e)| {
        for op in &e.ops { assert!(seen.contains(op), "missing core operation"); }
        let EffectName::User(id) = e.name else { return None; };
        Some(json!({"name":format!("effect:{}",id.0),"ops":e.ops.iter().map(|id| format!("op:{}",id.0)).collect::<Vec<_>>()}))
    }).collect();
    assert!(
        surface.outside.is_empty(),
        "unsupported operation declaration: {:?}",
        surface.outside
    );
    json!({"ops":ops,"effects":effects,"primOps":prim_ops.into_values().collect::<Vec<_>>()})
}

/// 型クラス・実装の宣言表。二重の比較の代わりに Rust の写しの整合を検査する。
pub fn class_tables(p: &CheckedProgram, core: &c::CoreProgram) -> Value {
    let mut s = Surface::new(p, None, Vec::new());
    let mut classes = Vec::new();
    for (id, cl) in p.types.traits.iter() {
        let mut methods = Vec::new();
        for (index, m) in cl.methods.iter().enumerate() {
            assert!(matches!(p.resolved.bindings.get(*m).unwrap().kind,
                BindingKind::Method { trait_, index:i }
                    if trait_ == id && usize::try_from(i).unwrap() == index));
            let scheme = p.types.decl_types.get(*m).unwrap();
            assert_eq!(scheme, core.schemes.get(*m).unwrap());
            assert_eq!(
                scheme.class_constraints[0],
                types::ClassConstraint {
                    param: 0,
                    class: id
                }
            );
            let g = scheme.type_params.len() - 1;
            s.type_order = std::iter::once(g).chain(0..g).collect();
            let mut header = s.header(scheme);
            // γ̄, P に並べた後、暗黙の P をメソッドの型パラメータの宣言から除く。
            header["tparams"].as_array_mut().unwrap().pop();
            let mut params: Vec<_> = scheme.class_constraints[1..]
                .iter()
                .map(|c| s.dict_ty(c))
                .collect();
            params.extend(header["params"].as_array().unwrap().clone());
            header["params"] = json!(params);
            methods.push(json!({"name":method_name(*m),"header":header}));
        }
        classes.push(json!({"name":class_name(id),"supers":cl.supers.iter().map(|id| class_name(*id)).collect::<Vec<_>>(),"methods":methods}));
    }
    s.type_order.clear();
    let mut impls = Vec::new();
    for i in &core.impls {
        let info = p.types.impls.get(i.impl_decl).unwrap();
        assert_eq!(info.class, i.class);
        assert_eq!(info.target, i.target);
        assert_eq!(info.class_constraints, i.dict_params);
        assert_eq!(
            info.type_params.iter().map(|t| &t.name).collect::<Vec<_>>(),
            i.type_params.iter().collect::<Vec<_>>()
        );
        assert_eq!(
            info.methods,
            i.methods.iter().map(|m| m.binding).collect::<Vec<_>>()
        );
        assert_eq!(info.supers.len(), i.supers.len());
        let cl = p.types.traits.get(i.class).unwrap();
        assert_eq!(i.supers.len(), cl.supers.len());
        assert_eq!(i.methods.len(), cl.methods.len());
        for (index, m) in i.methods.iter().enumerate() {
            assert_eq!(
                m.kind,
                c::DefKind::Method {
                    impl_decl: i.impl_decl,
                    index: u32::try_from(index).unwrap()
                }
            );
        }
        if unsupported_target(&i.target).is_some() {
            continue;
        }
        let scheme = Scheme {
            type_params: info.type_params.clone(),
            effect_params: Vec::new(),
            class_constraints: Vec::new(),
            params: Vec::new(),
            ret: Ty::Con(TyCon::Builtin(BuiltinTypeId::UNIT), Vec::new()),
            effects: EffectSet::empty(),
            wrote_io_all: false,
        };
        impls.push(json!({"name":impl_name(i.impl_decl),"tparams":s.header(&scheme)["tparams"],"dictParams":s.dict_params(&info.class_constraints),"cls":class_name(i.class),"target":s.type_arg(&info.target)}));
    }
    assert!(
        s.outside.is_empty(),
        "unsupported class/implementation declaration: {:?}",
        s.outside
    );
    json!({"classes":classes,"impls":impls})
}

/// E2c: 本体を持たない標準ライブラリの宣言。入力内の束縛番号を保存する。
pub fn stdlib_declarations(p: &CheckedProgram, core: &c::CoreProgram, input: &Value) -> Value {
    fn references(value: &Value, names: &mut BTreeSet<String>) {
        match value {
            Value::Array(xs) => xs.iter().for_each(|x| references(x, names)),
            Value::Object(xs) => {
                for tag in ["funName", "funDicts"] {
                    if let Some(name) = xs.get(tag).and_then(|x| x["name"].as_str()) {
                        names.insert(name.to_owned());
                    }
                }
                xs.values().for_each(|x| references(x, names));
            }
            Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {}
        }
    }
    let mut refs = BTreeSet::new();
    references(input, &mut refs);
    let mut s = Surface::new(p, None, Vec::new());
    let functions: Vec<_> = core
        .defs
        .iter()
        .filter(|d| d.origin != c::DefOrigin::User && refs.contains(&fun_name(d.binding)))
        .map(|d| {
            let scheme = p
                .types
                .decl_types
                .get(d.binding)
                .expect("missing stdlib scheme");
            assert_eq!(core.schemes.get(d.binding), Some(scheme));
            json!({"name":fun_name(d.binding),"header":s.header(scheme),
                "dictParams":s.dict_params(&scheme.class_constraints)})
        })
        .collect();
    let impls: Vec<_> = core
        .impls
        .iter()
        .filter(|i| i.origin != c::DefOrigin::User && unsupported_target(&i.target).is_none())
        .map(|i| {
            let info = p
                .types
                .impls
                .get(i.impl_decl)
                .expect("missing stdlib implementation");
            let cl = p.types.traits.get(i.class).expect("missing stdlib class");
            let scheme = Scheme {
                type_params: info.type_params.clone(),
                effect_params: Vec::new(),
                class_constraints: Vec::new(),
                params: Vec::new(),
                ret: Ty::Con(TyCon::Builtin(BuiltinTypeId::UNIT), Vec::new()),
                effects: EffectSet::empty(),
                wrote_io_all: false,
            };
            json!({"signature":{"name":impl_name(i.impl_decl),
                "tparams":s.header(&scheme)["tparams"],
                "dictParams":s.dict_params(&info.class_constraints),
                "cls":class_name(i.class),"target":s.type_arg(&info.target)},
                "methods":cl.methods.iter().map(|m| method_name(*m)).collect::<Vec<_>>(),
                "supers":cl.supers.iter().map(|c| class_name(*c)).collect::<Vec<_>>()})
        })
        .collect();
    assert!(
        s.outside.is_empty(),
        "unsupported stdlib signature: {:?}",
        s.outside
    );
    // 契約: 表層の関数参照のすべてに、利用者か信頼する関数の宣言がある。
    let declared: BTreeSet<_> = core
        .defs
        .iter()
        .filter(|d| d.origin == c::DefOrigin::User)
        .map(|d| fun_name(d.binding))
        .chain(
            functions
                .iter()
                .map(|f| f["name"].as_str().unwrap().to_owned()),
        )
        .collect();
    assert!(
        refs.is_subset(&declared),
        "function reference without a declaration"
    );
    json!({"group":input["group"],"name":input["name"],"functions":functions,"impls":impls})
}

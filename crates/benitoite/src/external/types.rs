//! 宣言の型から変換表を作り、WIT の型と照合する（設計書 03-10「型の対応」）。

use super::{WitPlan, text};
use crate::base::BindingId;
use crate::resolve::ResolveOutput;
use crate::types::{AdtTable, Ty, TyCon, builtin::BuiltinTypeId as B};
use wasmtime::component::Type;

pub(super) fn is_unit(ty: &Ty) -> bool {
    matches!(ty, Ty::Con(TyCon::Builtin(B::UNIT), args) if args.is_empty())
}

// 宣言の名前を残す表と WIT の名前を保存する表を分けることで、
// 実行時に名前を推測せず値を作れる（設計書 03-10「型の対応」）。
#[derive(Clone, Debug)]
pub(super) enum DeclPlan {
    Scalar(WitPlan),
    External(BindingId),
    List(Box<DeclPlan>),
    Map(Box<DeclPlan>, Box<DeclPlan>),
    Flags {
        name: String,
        cases: Vec<(String, u32)>,
    },
    Option(Box<DeclPlan>),
    Result {
        ok: Option<Box<DeclPlan>>,
        err: Option<Box<DeclPlan>>,
    },
    Tuple(Vec<DeclPlan>),
    Record {
        name: String,
        fields: Vec<(String, DeclPlan)>,
    },
    Variant {
        name: String,
        cases: Vec<(String, u32, Vec<DeclPlan>)>,
    },
}

pub(super) struct Unsupported<'a> {
    pub ty: &'a Ty,
    pub note: Option<&'static str>,
    pub recursive: Option<BindingId>,
}

pub(super) fn plan<'a>(
    ty: &'a Ty,
    resolved: &ResolveOutput,
    adts: &'a AdtTable,
    total: &mut usize,
) -> Result<DeclPlan, Unsupported<'a>> {
    use super::expansion::{ExpansionError, Visit, WalkError};
    let mut plans = Vec::new();
    let mut check_map_key = false;
    super::expansion::walk(ty, resolved, adts, total, |ty, visit| {
        match visit {
            Visit::Enter => {
                // 子に入る時点なら型引数が代入済みなので、宣言内の仮の鍵を拒まない。
                if std::mem::take(&mut check_map_key) && !is_map_key(ty) {
                    return Err(unsupported(ty, Some("map_key")));
                }
                validate(ty, adts)?;
                check_map_key = matches!(ty, Ty::Con(TyCon::Builtin(B::MAP), _));
            }
            Visit::Leave(count) => {
                let start = plans
                    .len()
                    .checked_sub(count)
                    .ok_or_else(|| unsupported(ty, None))?;
                let children = plans.split_off(start);
                plans.push(build(ty, resolved, adts, children)?);
            }
            Visit::Result { ok, err } => {
                let count = usize::from(ok).saturating_add(usize::from(err));
                let start = plans
                    .len()
                    .checked_sub(count)
                    .ok_or_else(|| unsupported(ty, None))?;
                let mut children = plans.split_off(start).into_iter();
                plans.push(DeclPlan::Result {
                    ok: if ok {
                        Some(Box::new(
                            children.next().ok_or_else(|| unsupported(ty, None))?,
                        ))
                    } else {
                        None
                    },
                    err: if err {
                        Some(Box::new(
                            children.next().ok_or_else(|| unsupported(ty, None))?,
                        ))
                    } else {
                        None
                    },
                });
            }
        }
        Ok(())
    })
    .map_err(|error| match error {
        WalkError::Expansion(ExpansionError::Budget) => unsupported(ty, Some("budget")),
        WalkError::Expansion(ExpansionError::Recursive(ty, id)) => Unsupported {
            recursive: Some(id),
            ..unsupported(ty, Some("recursive"))
        },
        WalkError::Visitor(error) => error,
    })?;
    if plans.len() != 1 {
        return Err(unsupported(ty, None));
    }
    plans.pop().ok_or_else(|| unsupported(ty, None))
}

#[cold]
#[inline(never)]
fn unsupported<'a>(ty: &'a Ty, note: Option<&'static str>) -> Unsupported<'a> {
    Unsupported {
        ty,
        note,
        recursive: None,
    }
}

fn scalar(ty: &Ty) -> Option<WitPlan> {
    let Ty::Con(TyCon::Builtin(id), args) = ty else {
        return None;
    };
    if !args.is_empty() {
        return None;
    }
    match *id {
        B::INTEGER8 => Some(WitPlan::S8),
        B::INTEGER16 => Some(WitPlan::S16),
        B::INTEGER32 => Some(WitPlan::S32),
        B::UNSIGNED_INTEGER16 => Some(WitPlan::U16),
        B::UNSIGNED_INTEGER32 => Some(WitPlan::U32),
        B::UNSIGNED_INTEGER64 => Some(WitPlan::U64),
        B::FLOAT32 => Some(WitPlan::F32),
        B::INTEGER => Some(WitPlan::S64),
        B::FLOAT => Some(WitPlan::F64),
        B::BOOLEAN => Some(WitPlan::Bool),
        B::CHARACTER => Some(WitPlan::Char),
        B::STRING => Some(WitPlan::String),
        B::BYTE => Some(WitPlan::U8),
        B::BYTES => Some(WitPlan::Bytes),
        _ => None,
    }
}

fn is_map_key(ty: &Ty) -> bool {
    matches!(
        scalar(ty),
        Some(
            WitPlan::Bool
                | WitPlan::S8
                | WitPlan::S16
                | WitPlan::S32
                | WitPlan::S64
                | WitPlan::U8
                | WitPlan::U16
                | WitPlan::U32
                | WitPlan::U64
                | WitPlan::Char
                | WitPlan::String
        )
    )
}

fn validate<'a>(ty: &'a Ty, adts: &'a AdtTable) -> Result<(), Unsupported<'a>> {
    if scalar(ty).is_some() {
        return Ok(());
    }
    match ty {
        Ty::Con(TyCon::External(_), args) if args.is_empty() => Ok(()),
        Ty::Con(TyCon::Builtin(B::LIST), args) if args.len() == 1 => Ok(()),
        Ty::Con(TyCon::Builtin(B::SET), args) if args.len() == 1 => Ok(()),
        Ty::Con(TyCon::Builtin(B::MAP), args) if args.len() == 2 => Ok(()),
        Ty::Con(TyCon::Adt(id), args) => {
            let def = adts.get(*id).ok_or_else(|| unsupported(ty, None))?;
            if args.len() != def.type_params.len() {
                return Err(unsupported(ty, None));
            }
            Ok(())
        }
        Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
            Err(unsupported(ty, None))
        }
    }
}

fn build<'a>(
    ty: &'a Ty,
    resolved: &ResolveOutput,
    adts: &'a AdtTable,
    children: Vec<DeclPlan>,
) -> Result<DeclPlan, Unsupported<'a>> {
    if let Some(plan) = scalar(ty) {
        return Ok(DeclPlan::Scalar(plan));
    }
    let mut children = children.into_iter();
    match ty {
        Ty::Con(TyCon::External(id), _) => Ok(DeclPlan::External(*id)),
        Ty::Con(TyCon::Builtin(B::MAP), _) => {
            let key = children.next().ok_or_else(|| unsupported(ty, None))?;
            let value = children.next().ok_or_else(|| unsupported(ty, None))?;
            Ok(DeclPlan::Map(Box::new(key), Box::new(value)))
        }
        Ty::Con(TyCon::Builtin(B::SET), _) => {
            let Some(DeclPlan::Variant { name, cases }) = children.next() else {
                return Err(unsupported(ty, Some("flags_data")));
            };
            if cases.is_empty() || cases.len() > 32 {
                return Err(unsupported(ty, Some("flags_count")));
            }
            if cases.iter().any(|(_, _, payload)| !payload.is_empty()) {
                return Err(unsupported(ty, Some("flags_data")));
            }
            Ok(DeclPlan::Flags {
                name,
                cases: cases
                    .into_iter()
                    .map(|(name, tag, _)| (name, tag))
                    .collect(),
            })
        }
        Ty::Con(TyCon::Builtin(B::LIST), _) => children
            .next()
            .map(|plan| DeclPlan::List(Box::new(plan)))
            .ok_or_else(|| unsupported(ty, None)),
        Ty::Con(TyCon::Adt(id), _) if Some(*id) == resolved.stdlib("Benitoite.Option.Option") => {
            children
                .next()
                .map(|plan| DeclPlan::Option(Box::new(plan)))
                .ok_or_else(|| unsupported(ty, None))
        }
        Ty::Con(TyCon::Adt(id), _)
            if ["Benitoite.Pair.Pair", "Benitoite.Triple.Triple"]
                .iter()
                .any(|name| Some(*id) == stdlib_type(resolved, name)) =>
        {
            Ok(DeclPlan::Tuple(children.collect()))
        }
        Ty::Con(TyCon::Adt(id), _) => {
            let def = adts.get(*id).ok_or_else(|| unsupported(ty, None))?;
            if let Some(fields) = &def.record {
                if fields.len() != children.len() {
                    return Err(unsupported(ty, None));
                }
                Ok(DeclPlan::Record {
                    name: def.name.clone(),
                    fields: fields
                        .iter()
                        .zip(children)
                        .map(|(field, plan)| (field.name.clone(), plan))
                        .collect(),
                })
            } else {
                Ok(DeclPlan::Variant {
                    name: def.name.clone(),
                    cases: def
                        .ctors
                        .iter()
                        .map(|ctor| {
                            let payload: Vec<_> =
                                children.by_ref().take(ctor.fields.len()).collect();
                            if payload.len() != ctor.fields.len() {
                                return Err(unsupported(ty, None));
                            }
                            Ok((ctor.name.clone(), ctor.tag, payload))
                        })
                        .collect::<Result<_, _>>()?,
                })
            }
        }
        Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
            Err(unsupported(ty, None))
        }
    }
}

pub(super) struct Mismatch(pub Option<String>);

fn normalize(name: &str) -> String {
    name.chars()
        .filter(|ch| *ch != '-')
        .map(|ch| ch.to_ascii_lowercase())
        .collect()
}

fn names(declared: &[&str], wit: &[&str], kind: &str, owner: &str) -> Result<(), Mismatch> {
    for (side, names) in [(text::DECLARED, declared), (text::WIT, wit)] {
        let mut seen = std::collections::BTreeSet::new();
        for name in names {
            if !seen.insert(normalize(name)) {
                return Err(Mismatch(Some(text::duplicate_name(side, name))));
            }
        }
    }
    if declared.len() != wit.len() {
        return Err(Mismatch(Some(text::member_count(
            kind,
            owner,
            declared.len(),
            wit.len(),
        ))));
    }
    for (i, (declared, wit)) in declared.iter().zip(wit).enumerate() {
        if normalize(declared) != normalize(wit) {
            return Err(Mismatch(Some(text::member_name(
                kind,
                owner,
                i.saturating_add(1),
                declared,
                wit,
            ))));
        }
    }
    Ok(())
}

pub(super) type ResourceBindings =
    std::collections::BTreeMap<BindingId, (std::path::PathBuf, wasmtime::component::ResourceType)>;
pub(super) struct BindContext<'a> {
    pub resources: &'a ResourceBindings,
    pub exported_resources: &'a [(wasmtime::component::ResourceType, String)],
    pub component_display: &'a str,
    pub component: &'a std::path::Path,
    pub resolved: &'a ResolveOutput,
    pub result: bool,
}

pub(super) fn bind(
    plan: &DeclPlan,
    ty: &Type,
    context: &BindContext<'_>,
) -> Result<WitPlan, Mismatch> {
    let side = |plan: &Option<Box<DeclPlan>>, ty: Option<Type>| match (plan, ty) {
        (None, None) => Ok(None),
        (Some(plan), Some(ty)) => bind(plan, &ty, context).map(|p| Some(Box::new(p))),
        _ => Err(Mismatch(None)),
    };
    match (plan, ty) {
        (DeclPlan::External(id), ty) => {
            let Some((component, resource)) = context.resources.get(id) else {
                return Err(Mismatch(None));
            };
            let expected = if context.result { "own" } else { "borrow" };
            let found = match ty {
                Type::Borrow(r) if !context.result => Some(r),
                Type::Own(r) if context.result => Some(r),
                Type::Own(_)
                | Type::Borrow(_)
                | Type::Bool
                | Type::S8
                | Type::U8
                | Type::S16
                | Type::U16
                | Type::S32
                | Type::U32
                | Type::S64
                | Type::U64
                | Type::Float32
                | Type::Float64
                | Type::Char
                | Type::String
                | Type::List(_)
                | Type::Option(_)
                | Type::Result(_)
                | Type::Tuple(_)
                | Type::Map(_)
                | Type::Record(_)
                | Type::Variant(_)
                | Type::Enum(_)
                | Type::Flags(_)
                | Type::Future(_)
                | Type::Stream(_)
                | Type::ErrorContext
                | Type::FixedLengthList(_) => None,
            };
            if found == Some(resource) && component == context.component {
                return Ok(if context.result {
                    WitPlan::Own(id.0)
                } else {
                    WitPlan::Borrow(id.0)
                });
            }
            let name = context
                .resolved
                .bindings
                .get(*id)
                .map_or("_", |b| b.name.as_str());
            let decl = context.resolved.externals.get(*id);
            let found_resource = if let Type::Own(r) | Type::Borrow(r) = ty {
                context
                    .exported_resources
                    .iter()
                    .find(|(resource, _)| resource == r)
                    .map(|(_, name)| name.as_str())
            } else {
                None
            };
            Err(Mismatch(Some(text::external_mismatch(
                name,
                decl,
                expected,
                ty,
                found_resource,
                context.component_display,
            ))))
        }
        (DeclPlan::Scalar(p), ty)
            if matches!(
                (p, ty),
                (WitPlan::S8, Type::S8)
                    | (WitPlan::S16, Type::S16)
                    | (WitPlan::S32, Type::S32)
                    | (WitPlan::U16, Type::U16)
                    | (WitPlan::U32, Type::U32)
                    | (WitPlan::U64, Type::U64)
                    | (WitPlan::F32, Type::Float32)
                    | (WitPlan::S64, Type::S64)
                    | (WitPlan::F64, Type::Float64)
                    | (WitPlan::Bool, Type::Bool)
                    | (WitPlan::Char, Type::Char)
                    | (WitPlan::String, Type::String)
                    | (WitPlan::U8, Type::U8)
            ) =>
        {
            Ok(p.clone())
        }
        (DeclPlan::Scalar(WitPlan::Bytes), Type::List(l)) if l.ty() == Type::U8 => {
            Ok(WitPlan::Bytes)
        }
        (DeclPlan::List(p), Type::List(l)) => {
            Ok(WitPlan::List(Box::new(bind(p, &l.ty(), context)?)))
        }
        (DeclPlan::Map(key, value), Type::Map(map)) => {
            let bind_member = |plan: &DeclPlan, ty: Type, member| {
                bind(plan, &ty, context).map(Box::new).map_err(|m| {
                    Mismatch(Some(m.0.unwrap_or_else(|| {
                        text::map_member(member, &plan.show(), &show(&ty))
                    })))
                })
            };
            Ok(WitPlan::Map(
                bind_member(key, map.key(), text::KEY)?,
                bind_member(value, map.value(), text::VALUE)?,
            ))
        }
        (DeclPlan::Flags { name, cases }, Type::Flags(flags)) => {
            let wit: Vec<_> = flags.names().collect();
            names(
                &cases
                    .iter()
                    .map(|(name, _)| name.as_str())
                    .collect::<Vec<_>>(),
                &wit,
                text::FLAG,
                name,
            )?;
            Ok(WitPlan::Flags {
                cases: cases
                    .iter()
                    .zip(wit)
                    .map(|((_, tag), name)| (name.to_owned(), *tag))
                    .collect(),
            })
        }
        (DeclPlan::Option(p), Type::Option(o)) => {
            Ok(WitPlan::Option(Box::new(bind(p, &o.ty(), context)?)))
        }
        (DeclPlan::Result { ok, err }, Type::Result(r)) => Ok(WitPlan::Result {
            ok: side(ok, r.ok())?,
            err: side(err, r.err())?,
        }),
        (DeclPlan::Tuple(ps), Type::Tuple(t)) if ps.len() == t.types().len() => ps
            .iter()
            .zip(t.types())
            .map(|(p, ty)| bind(p, &ty, context))
            .collect::<Result<Vec<_>, _>>()
            .map(WitPlan::Tuple),
        (DeclPlan::Variant { cases, .. }, Type::Tuple(t)) if cases.len() == 1 => {
            let (_, tag, fields) = cases.first().ok_or(Mismatch(None))?;
            if fields.is_empty() || fields.len() != t.types().len() {
                return Err(Mismatch(None));
            }
            let fields = fields
                .iter()
                .zip(t.types())
                .map(|(p, ty)| bind(p, &ty, context))
                .collect::<Result<Vec<_>, _>>()?;
            Ok(WitPlan::ConstructorTuple { tag: *tag, fields })
        }
        (DeclPlan::Record { name, fields }, Type::Record(r)) => {
            let wit: Vec<_> = r.fields().collect();
            names(
                &fields.iter().map(|(n, _)| n.as_str()).collect::<Vec<_>>(),
                &wit.iter().map(|f| f.name).collect::<Vec<_>>(),
                text::FIELD,
                name,
            )?;
            fields
                .iter()
                .zip(wit)
                .map(|((_, p), f)| {
                    Ok((
                        f.name.to_owned(),
                        bind(p, &f.ty, context).map_err(|m| {
                            Mismatch(Some(
                                m.0.unwrap_or_else(|| text::member_type(text::FIELD, name, f.name)),
                            ))
                        })?,
                    ))
                })
                .collect::<Result<Vec<_>, _>>()
                .map(|fields| WitPlan::Record { fields })
        }
        (DeclPlan::Variant { name, cases }, Type::Variant(v)) => {
            let wit: Vec<_> = v.cases().collect();
            names(
                &cases.iter().map(|(n, _, _)| n.as_str()).collect::<Vec<_>>(),
                &wit.iter().map(|c| c.name).collect::<Vec<_>>(),
                text::CASE,
                name,
            )?;
            cases
                .iter()
                .zip(wit)
                .map(|((_, tag, p), c)| {
                    let mismatch = || Mismatch(Some(text::member_type(text::CASE, name, c.name)));
                    let payload = match (p.as_slice(), c.ty) {
                        ([], None) => None,
                        ([p], Some(ty)) => Some(Box::new(bind(p, &ty, context).map_err(|m| {
                            Mismatch(Some(
                                m.0.unwrap_or_else(|| text::member_type(text::CASE, name, c.name)),
                            ))
                        })?)),
                        (ps, Some(Type::Tuple(t)))
                            if ps.len() > 1 && ps.len() == t.types().len() =>
                        {
                            let fields = ps
                                .iter()
                                .zip(t.types())
                                .map(|(p, ty)| {
                                    bind(p, &ty, context).map_err(|m| {
                                        Mismatch(Some(m.0.unwrap_or_else(|| {
                                            text::member_type(text::CASE, name, c.name)
                                        })))
                                    })
                                })
                                .collect::<Result<Vec<_>, _>>()?;
                            Some(Box::new(WitPlan::TupleFields(fields)))
                        }
                        ([], Some(_)) | (_, None) => {
                            return Err(Mismatch(Some(text::payload(name, c.name))));
                        }
                        _ => return Err(mismatch()),
                    };
                    Ok((c.name.to_owned(), *tag, payload))
                })
                .collect::<Result<Vec<_>, _>>()
                .map(|cases| WitPlan::Variant { cases })
        }
        (DeclPlan::Variant { name, cases }, Type::Enum(e)) => {
            let wit: Vec<_> = e.names().collect();
            names(
                &cases.iter().map(|(n, _, _)| n.as_str()).collect::<Vec<_>>(),
                &wit,
                text::CASE,
                name,
            )?;
            cases
                .iter()
                .zip(wit)
                .map(|((_, tag, p), n)| {
                    if !p.is_empty() {
                        return Err(Mismatch(Some(text::payload(name, n))));
                    }
                    Ok((n.to_owned(), *tag))
                })
                .collect::<Result<Vec<_>, _>>()
                .map(|cases| WitPlan::Enum { cases })
        }
        _ => Err(Mismatch(None)),
    }
}

impl DeclPlan {
    pub(super) fn external_ids(&self) -> Vec<BindingId> {
        let mut ids = Vec::new();
        let mut pending = vec![self];
        while let Some(p) = pending.pop() {
            match p {
                Self::External(id) => ids.push(*id),
                Self::Scalar(_) | Self::Flags { .. } => {}
                Self::List(p) | Self::Option(p) => pending.push(p),
                Self::Map(key, value) => pending.extend([key.as_ref(), value.as_ref()]),
                Self::Result { ok, err } => pending.extend(ok.iter().chain(err).map(Box::as_ref)),
                Self::Tuple(ps) => pending.extend(ps),
                Self::Record { fields, .. } => pending.extend(fields.iter().map(|(_, p)| p)),
                Self::Variant { cases, .. } => {
                    pending.extend(cases.iter().flat_map(|(_, _, ps)| ps))
                }
            }
        }
        ids
    }

    pub(super) fn show(&self) -> String {
        match self {
            Self::External(_) => text::EXTERNAL_TYPE.into(),
            Self::Scalar(p) => p.show(),
            Self::List(p) => format!("list<{}>", p.show()),
            Self::Map(key, value) => format!("map<{}, {}>", key.show(), value.show()),
            Self::Flags { cases, .. } => format!(
                "flags {{ {} }}",
                cases
                    .iter()
                    .map(|(name, _)| name.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Self::Option(p) => format!("option<{}>", p.show()),
            Self::Result { ok, err } => format!(
                "result<{}, {}>",
                ok.as_ref().map_or_else(|| "_".into(), |p| p.show()),
                err.as_ref().map_or_else(|| "_".into(), |p| p.show())
            ),
            Self::Tuple(ps) => format!(
                "tuple<{}>",
                ps.iter().map(Self::show).collect::<Vec<_>>().join(", ")
            ),
            Self::Record { fields, .. } => format!(
                "record {{ {} }}",
                fields
                    .iter()
                    .map(|(n, p)| format!("{n}: {}", p.show()))
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Self::Variant { cases, .. } => format!(
                "variant {{ {} }}",
                cases
                    .iter()
                    .map(|(n, _, ps)| match ps.as_slice() {
                        [] => n.clone(),
                        [p] => format!("{n}({})", p.show()),
                        _ => format!(
                            "{n}(tuple<{}>)",
                            ps.iter().map(Self::show).collect::<Vec<_>>().join(", ")
                        ),
                    })
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
        }
    }
}

impl WitPlan {
    pub(super) fn show(&self) -> String {
        match self {
            Self::Own(_) => "own<resource>".into(),
            Self::Borrow(_) => "borrow<resource>".into(),
            Self::S8 => "s8".into(),
            Self::S16 => "s16".into(),
            Self::S32 => "s32".into(),
            Self::U16 => "u16".into(),
            Self::U32 => "u32".into(),
            Self::U64 => "u64".into(),
            Self::F32 => "f32".into(),
            Self::S64 => "s64".into(),
            Self::F64 => "f64".into(),
            Self::Bool => "bool".into(),
            Self::Char => "char".into(),
            Self::String => "string".into(),
            Self::U8 => "u8".into(),
            Self::Bytes => "list<u8>".into(),
            Self::List(inner) => format!("list<{}>", inner.show()),
            Self::Map(key, value) => format!("map<{}, {}>", key.show(), value.show()),
            Self::Option(inner) => format!("option<{}>", inner.show()),
            Self::Result { ok, err } => format!(
                "result<{}, {}>",
                ok.as_ref().map_or_else(|| "_".into(), |p| p.show()),
                err.as_ref().map_or_else(|| "_".into(), |p| p.show())
            ),
            Self::Record { fields } => format!(
                "record {{ {} }}",
                fields
                    .iter()
                    .map(|(n, p)| format!("{n}: {}", p.show()))
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Self::Variant { cases } => format!(
                "variant {{ {} }}",
                cases
                    .iter()
                    .map(|(n, _, p)| p
                        .as_ref()
                        .map_or_else(|| n.clone(), |p| format!("{n}({})", p.show())))
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Self::Enum { cases } | Self::Flags { cases } => format!(
                "{} {{ {} }}",
                if matches!(self, Self::Flags { .. }) {
                    "flags"
                } else {
                    "enum"
                },
                cases
                    .iter()
                    .map(|(n, _)| n.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            ),
            Self::Tuple(plans)
            | Self::TupleFields(plans)
            | Self::ConstructorTuple { fields: plans, .. } => format!(
                "tuple<{}>",
                plans.iter().map(Self::show).collect::<Vec<_>>().join(", ")
            ),
        }
    }
}

pub(super) fn show(ty: &Type) -> String {
    match ty {
        Type::Bool => "bool".into(),
        Type::S8 => "s8".into(),
        Type::U8 => "u8".into(),
        Type::S16 => "s16".into(),
        Type::U16 => "u16".into(),
        Type::S32 => "s32".into(),
        Type::U32 => "u32".into(),
        Type::S64 => "s64".into(),
        Type::U64 => "u64".into(),
        Type::Float32 => "f32".into(),
        Type::Float64 => "f64".into(),
        Type::Char => "char".into(),
        Type::String => "string".into(),
        Type::List(list) => format!("list<{}>", show(&list.ty())),
        Type::Option(option) => format!("option<{}>", show(&option.ty())),
        Type::Result(result) => format!(
            "result<{}, {}>",
            result.ok().as_ref().map_or_else(|| "_".into(), show),
            result.err().as_ref().map_or_else(|| "_".into(), show)
        ),
        Type::Tuple(tuple) => format!(
            "tuple<{}>",
            tuple
                .types()
                .map(|ty| show(&ty))
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Type::Map(map) => format!("map<{}, {}>", show(&map.key()), show(&map.value())),
        Type::Record(r) => format!(
            "record {{ {} }}",
            r.fields()
                .map(|f| format!("{}: {}", f.name, show(&f.ty)))
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Type::Variant(v) => format!(
            "variant {{ {} }}",
            v.cases()
                .map(|c| c.ty.as_ref().map_or_else(
                    || c.name.to_owned(),
                    |ty| format!("{}({})", c.name, show(ty))
                ))
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Type::Enum(e) => format!("enum {{ {} }}", e.names().collect::<Vec<_>>().join(", ")),
        Type::Flags(flags) => format!(
            "flags {{ {} }}",
            flags.names().collect::<Vec<_>>().join(", ")
        ),
        Type::Own(_) | Type::Borrow(_) => "resource".into(),
        Type::Future(_) => "future".into(),
        Type::Stream(_) => "stream".into(),
        Type::ErrorContext => "error-context".into(),
        Type::FixedLengthList(_) => "fixed-length-list".into(),
    }
}

// 表で逆に引けない型が一つでもあれば、名前を推測した宣言を示さない
// （設計書 03-10「照合」）。
pub(super) fn declaration(
    name: &str,
    function: &wasmtime::component::types::ComponentFunc,
) -> Option<String> {
    let names: Vec<_> = function
        .params()
        .map(|(name, _)| {
            let mut parts = name.split('-');
            let mut camel = parts.next().unwrap_or_default().to_ascii_lowercase();
            for part in parts {
                let mut chars = part.chars();
                if let Some(first) = chars.next() {
                    camel.push(first.to_ascii_uppercase());
                    camel.extend(chars);
                }
            }
            camel
        })
        .collect();
    let mut used: std::collections::BTreeSet<_> = names
        .iter()
        .filter(|name| crate::syntax::lexer::keyword(name).is_none())
        .cloned()
        .collect();
    let params = function
        .params()
        .zip(names)
        .enumerate()
        .map(|(index, ((_, ty), mut name))| {
            if crate::syntax::lexer::keyword(&name).is_some() {
                let mut n = index.saturating_add(1);
                loop {
                    name = text::argument_name(n);
                    if used.insert(name.clone()) {
                        break;
                    }
                    n = n.saturating_add(1);
                }
            }
            Some(format!("{name}: {}", declared_type(&ty)?))
        })
        .collect::<Option<Vec<_>>>()?;
    let results: Vec<_> = function.results().collect();
    let result = match results.as_slice() {
        [] => text::TYPE_UNIT.into(),
        [ty] => declared_type(ty)?,
        _ => return None,
    };
    Some(text::declaration(name, &params.join(", "), &result))
}

fn declared_type(ty: &Type) -> Option<String> {
    Some(match ty {
        Type::S8 => text::TYPE_INTEGER8.into(),
        Type::S16 => text::TYPE_INTEGER16.into(),
        Type::S32 => text::TYPE_INTEGER32.into(),
        Type::U16 => text::TYPE_UNSIGNED_INTEGER16.into(),
        Type::U32 => text::TYPE_UNSIGNED_INTEGER32.into(),
        Type::U64 => text::TYPE_UNSIGNED_INTEGER64.into(),
        Type::Float32 => text::TYPE_FLOAT32.into(),
        Type::S64 => text::TYPE_INTEGER.into(),
        Type::Float64 => text::TYPE_FLOAT.into(),
        Type::Bool => text::TYPE_BOOLEAN.into(),
        Type::Char => text::TYPE_CHARACTER.into(),
        Type::String => text::TYPE_STRING.into(),
        Type::U8 => text::TYPE_BYTE.into(),
        Type::List(list) if list.ty() == Type::U8 => text::TYPE_BYTES.into(),
        Type::List(list) => text::applied_type(text::TYPE_LIST, &declared_type(&list.ty())?),
        Type::Option(option) => {
            text::applied_type(text::TYPE_OPTION, &declared_type(&option.ty())?)
        }
        Type::Result(result) => {
            let side = |ty: Option<Type>| match ty {
                None => Some(text::TYPE_UNIT.into()),
                Some(ty) => declared_type(&ty),
            };
            text::applied_type(
                text::TYPE_RESULT,
                &format!("{}, {}", side(result.ok())?, side(result.err())?),
            )
        }
        Type::Tuple(tuple) => {
            let name = match tuple.types().len() {
                2 => text::TYPE_PAIR,
                3 => text::TYPE_TRIPLE,
                _ => return None,
            };
            let types = tuple
                .types()
                .map(|ty| declared_type(&ty))
                .collect::<Option<Vec<_>>>()?;
            text::applied_type(name, &types.join(", "))
        }
        Type::Map(_)
        | Type::Record(_)
        | Type::Variant(_)
        | Type::Enum(_)
        | Type::Flags(_)
        | Type::Own(_)
        | Type::Borrow(_)
        | Type::Future(_)
        | Type::Stream(_)
        | Type::ErrorContext
        | Type::FixedLengthList(_) => return None,
    })
}

// Pair と Triple は型と構成子が同じ名前なので、索引は構成子の束縛を指す。
// 構成子から型の束縛を引き、利用者が同じ名前で宣言した型を取り違えない。
fn stdlib_type(resolved: &ResolveOutput, name: &str) -> Option<crate::base::BindingId> {
    let id = resolved.stdlib(name)?;
    if let crate::resolve::BindingKind::Ctor { data, .. } = resolved.bindings.get(id)?.kind {
        Some(data)
    } else {
        Some(id)
    }
}

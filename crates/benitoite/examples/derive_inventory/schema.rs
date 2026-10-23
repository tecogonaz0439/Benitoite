//! 外部契約の型・署名を明示し、内部の番号と表示順へ依存させない（設計書 03-06「外部生成の宣言情報」）。
use super::{Error, Output, kind, text, type_params, visibility};
use benitoite::{
    base::BindingId,
    resolve::BindingKind,
    syntax::ast::Item,
    types::{EffectName, EffectSet, ParamKind, Scheme, Ty, TyCon, TyHead, TypeArg},
};
use serde_json::{Value, json};
use std::collections::BTreeMap;

impl Output<'_> {
    fn con_name(&self, con: TyCon) -> Result<String, Error> {
        match con {
            TyCon::Builtin(id) => {
                let d = id.def().ok_or(text::INVALID_SCHEMA)?;
                Ok(format!(
                    "Benitoite.{}{}",
                    if d.module.is_empty() {
                        String::new()
                    } else {
                        format!("{}.", d.module.join("."))
                    },
                    d.name
                ))
            }
            TyCon::Adt(id) | TyCon::External(id) => {
                let name = self.name(id);
                if name.is_empty() {
                    Err(text::INVALID_SCHEMA.into())
                } else {
                    Ok(name)
                }
            }
        }
    }
    fn con_arity(&self, con: TyCon) -> Result<usize, Error> {
        match con {
            TyCon::Builtin(id) => Ok(usize::from(id.def().ok_or(text::INVALID_SCHEMA)?.arity)),
            TyCon::Adt(id) => Ok(self
                .inv
                .types
                .adts
                .get(id)
                .ok_or(text::INVALID_SCHEMA)?
                .type_params
                .len()),
            TyCon::External(_) => Ok(0),
        }
    }
    pub(super) fn ty(&self, ty: &Ty, s: &Scheme) -> Result<Value, Error> {
        match ty {
            Ty::Con(con, args) => {
                if self.con_arity(*con)? != args.len() {
                    return Err(text::INVALID_SCHEMA.into());
                }
                Ok(
                    json!({"tag":"application","head":{"tag":"named","name":self.con_name(*con)?},
                    "arguments":args.iter().map(|t|self.ty(t,s)).collect::<Result<Vec<_>,_>>()?}),
                )
            }
            Ty::App(index, args) => {
                let i = usize::try_from(*index)?;
                if !matches!(s.type_params.get(i).map(|p|p.kind), Some(ParamKind::Ctor{arity}) if usize::try_from(arity).ok()==Some(args.len()))
                {
                    return Err(text::INVALID_SCHEMA.into());
                }
                Ok(
                    json!({"tag":"application","head":{"tag":"parameter","index":index},
                    "arguments":args.iter().map(|t|self.ty(t,s)).collect::<Result<Vec<_>,_>>()?}),
                )
            }
            Ty::Param(index) => {
                if s.type_params.get(usize::try_from(*index)?).map(|p| p.kind)
                    != Some(ParamKind::Value)
                {
                    return Err(text::INVALID_SCHEMA.into());
                }
                Ok(json!({"tag":"parameter","index":index}))
            }
            Ty::Fn(f) => self.function_type(&f.param_names, &f.params, &f.ret, &f.effects, s),
            Ty::Rigid { .. } => Err(text::INVALID_SCHEMA.into()),
        }
    }
    fn function_type(
        &self,
        names: &[String],
        params: &[Ty],
        ret: &Ty,
        effects: &EffectSet,
        s: &Scheme,
    ) -> Result<Value, Error> {
        if names.len() != params.len()
            || names
                .iter()
                .collect::<std::collections::BTreeSet<_>>()
                .len()
                != names.len()
        {
            return Err(text::INVALID_SCHEMA.into());
        }
        Ok(
            json!({"tag":"function","params":names.iter().zip(params).map(|(n,t)|Ok(json!({"name":n,"type":self.ty(t,s)?}))).collect::<Result<Vec<_>,Error>>()?,
            "returnType":self.ty(ret,s)?,"effects":self.effect_set(effects,s)?}),
        )
    }
    fn effect_set(&self, e: &EffectSet, s: &Scheme) -> Result<Value, Error> {
        let mut names = e.names.iter().map(|n|match n {
            EffectName::Builtin(id) => {
                let d = id.def().ok_or(text::INVALID_SCHEMA)?;
                Ok(json!({"tag":"builtin","name":d.module.iter().copied().chain(std::iter::once(d.name)).collect::<Vec<_>>().join(".")}))
            }
            EffectName::User(id) => Ok(json!({"tag":"named","name":self.name(*id)})),
        }).collect::<Result<Vec<_>,Error>>()?;
        names.sort_by_key(|v| {
            v.get("name")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_owned()
        });
        names.dedup();
        let mut vars = e.vars.iter().map(|v| v.0).collect::<Vec<_>>();
        if vars.iter().any(|i| {
            usize::try_from(*i)
                .ok()
                .is_none_or(|i| i >= s.effect_params.len())
        }) {
            return Err(text::INVALID_SCHEMA.into());
        }
        vars.sort();
        vars.dedup();
        let mut failures = e
            .failures
            .iter()
            .map(|t| self.ty(t, s))
            .collect::<Result<Vec<_>, _>>()?;
        failures.sort_by_key(Value::to_string);
        failures.dedup();
        Ok(json!({"names":names,"vars":vars,"failures":failures}))
    }
    pub(super) fn signature(&self, s: &Scheme) -> Result<Value, Error> {
        // 宣言収集の合併済みSchemeを渡し、元ASTの個別usesから作り直さない。
        // 入れ子の関数型と実装メソッドは追加対象ではない（設計書 03-06「外部生成の宣言情報」）。
        let mut value = self.function_type(&s.param_names, &s.params, &s.ret, &s.effects, s)?;
        let obj = value.as_object_mut().ok_or(text::INVALID_SCHEMA)?;
        obj.remove("tag");
        let mut no_fail = s.no_fail.iter().map(|v| v.0).collect::<Vec<_>>();
        if no_fail.iter().any(|i| {
            usize::try_from(*i)
                .ok()
                .is_none_or(|i| i >= s.effect_params.len())
        }) {
            return Err(text::INVALID_SCHEMA.into());
        }
        no_fail.sort();
        no_fail.dedup();
        obj.insert("typeParams".into(), json!(type_params(&s.type_params)));
        obj.insert("effectParams".into(), json!(s.effect_params));
        obj.insert("noFail".into(), json!(no_fail));
        obj.insert(
            "constraints".into(),
            self.constraints(&s.class_constraints, &s.type_params)?,
        );
        Ok(value)
    }
    fn constraints(
        &self,
        cs: &[benitoite::types::ClassConstraint],
        ps: &[benitoite::types::TypeParamInfo],
    ) -> Result<Value, Error> {
        Ok(json!(
            cs.iter()
                .map(|c| {
                    let p = ps
                        .get(usize::try_from(c.param)?)
                        .ok_or(text::INVALID_SCHEMA)?;
                    let class = self
                        .inv
                        .types
                        .traits
                        .get(c.class)
                        .ok_or(text::INVALID_SCHEMA)?;
                    if p.kind != class.param_kind {
                        return Err(text::INVALID_SCHEMA.into());
                    }
                    Ok(json!({"param":c.param,"class":self.name(c.class)}))
                })
                .collect::<Result<Vec<_>, Error>>()?
        ))
    }
    fn methods(&self, ids: &[BindingId]) -> Result<Vec<Value>, Error> {
        ids.iter()
            .map(|id| {
                let b = self
                    .inv
                    .resolved
                    .bindings
                    .get(*id)
                    .ok_or(text::INVALID_SCHEMA)?;
                let s = self
                    .inv
                    .types
                    .decl_types
                    .get(*id)
                    .ok_or(text::INVALID_SCHEMA)?;
                Ok(json!({"name":b.name,"signature":self.signature(s)?}))
            })
            .collect()
    }
    pub(super) fn declaration_tables(&self) -> Result<(Value, Value, Vec<Value>), Error> {
        let mut types = BTreeMap::new();
        for (id, b) in self.inv.resolved.bindings.iter() {
            let (name, tag, arity, extensible) = match b.kind {
                BindingKind::BuiltinType(t) => (
                    self.con_name(TyCon::Builtin(t))?,
                    "builtin",
                    self.con_arity(TyCon::Builtin(t))?,
                    false,
                ),
                BindingKind::Data | BindingKind::Record => {
                    let a = self.inv.types.adts.get(id).ok_or(text::INVALID_SCHEMA)?;
                    (
                        self.name(id),
                        if a.record.is_some() { "record" } else { "data" },
                        a.type_params.len(),
                        a.extensible,
                    )
                }
                BindingKind::ExternalType => (self.name(id), "external", 0, false),
                BindingKind::Fn
                | BindingKind::BuiltinFn(_)
                | BindingKind::ImplFn { .. }
                | BindingKind::Const
                | BindingKind::Alias
                | BindingKind::Field { .. }
                | BindingKind::Ctor { .. }
                | BindingKind::Trait
                | BindingKind::Method { .. }
                | BindingKind::Effect
                | BindingKind::BuiltinEffect(_)
                | BindingKind::Op { .. }
                | BindingKind::Module(_)
                | BindingKind::NamespaceRoot
                | BindingKind::TypeParam { .. }
                | BindingKind::EffectVar { .. }
                | BindingKind::Local(_) => continue,
            };
            types.entry(name.clone()).or_insert(json!({"name":name,"kind":tag,"arity":arity,
                "module":self.inv.modules.get(b.module).map(|m|m.name.dotted()),"visibility":visibility(b)?,
                "public":b.public,"package":b.package,"opaque":b.opaque,"extensible":extensible}));
        }
        let mut classes = BTreeMap::new();
        for (id, c) in self.inv.types.traits.iter() {
            let b = self
                .inv
                .resolved
                .bindings
                .get(id)
                .ok_or(text::INVALID_SCHEMA)?;
            classes.insert(self.name(id),json!({"name":self.name(id),"module":self.inv.modules.get(c.module).map(|m|m.name.dotted()),
                "visibility":visibility(b)?,"public":b.public,"package":b.package,
                "paramKind":kind(c.param_kind),"superclasses":c.supers.iter().map(|id|self.name(*id)).collect::<Vec<_>>(),"methods":self.methods(&c.methods)?}));
        }
        // implementは束縛を持たないので、宣言のASTから順に取り出す。
        let mut implementations = vec![];
        for ast in &self.inv.asts {
            for top in &ast.decls {
                let Item::Impl(decl) = &top.item else {
                    continue;
                };
                let i = self
                    .inv
                    .types
                    .impls
                    .get(decl.id)
                    .ok_or(text::INVALID_SCHEMA)?;
                let s = Scheme {
                    param_names: vec![],
                    type_params: i.type_params.clone(),
                    effect_params: vec![],
                    no_fail: vec![],
                    class_constraints: i.class_constraints.clone(),
                    params: vec![],
                    ret: Ty::Con(
                        TyCon::Builtin(benitoite::types::builtin::BuiltinTypeId::UNIT),
                        vec![],
                    ),
                    effects: EffectSet::empty(),
                    wrote_io_all: false,
                };
                let target = match &i.target {
                    TypeArg::Ty(t) => self.ty(t, &s)?,
                    TypeArg::Head(TyHead::Con(c)) => {
                        json!({"tag":"named","name":self.con_name(*c)?})
                    }
                    TypeArg::Head(TyHead::Param(p)) => json!({"tag":"parameter","index":p}),
                };
                implementations.push(json!({"class":self.name(i.class),"target":target,"typeParams":type_params(&i.type_params),
                    "constraints":self.constraints(&i.class_constraints,&i.type_params)?,"module":self.inv.modules.get(i.module).map(|m|m.name.dotted()),
                    "span":self.span(decl.span),"methods":self.methods(&i.methods)?,"sourceRegion":self.source_region(decl.span)}));
            }
        }
        Ok((json!(types), json!(classes), implementations))
    }
    fn source_region(&self, span: benitoite::base::Span) -> Option<String> {
        let s = self.inv.sources.get(span.file)?;
        let before = s.text().get(..usize::try_from(span.start.0).ok()?)?;
        let mut region = None;
        for line in String::from_utf8_lossy(before).lines() {
            if let Some(name) = line.strip_prefix("// benitoite-derive:begin ") {
                region = Some(name.to_owned());
            }
            if line.starts_with("// benitoite-derive:end ") {
                region = None;
            }
        }
        region
    }
}

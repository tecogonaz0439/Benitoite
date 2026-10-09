//! 共有の表と定数の記述（設計書 02-07「定数表」「辞書とメソッドの呼び出し」）。

use super::*;

#[derive(PartialEq, Eq, Hash)]
pub(super) enum ConstKey {
    Int(i64),
    Float(u64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    Byte(u8),
    Decimal(i128, u8),
    Ctor(CtorIdx, Vec<ConstIdx>),
    List(Vec<ConstIdx>),
    Map(Vec<(ConstIdx, ConstIdx)>),
    Set(Vec<ConstIdx>),
    Func(ProtoIdx),
    Dict(ImplIdx),
}

impl ConstKey {
    fn of(desc: &ConstDesc) -> Self {
        match desc {
            ConstDesc::Int(x) => Self::Int(*x),
            ConstDesc::Float(x) => Self::Float(x.to_bits()),
            ConstDesc::Str(x) => Self::Str(x.clone()),
            ConstDesc::Char(x) => Self::Char(*x),
            ConstDesc::Bool(x) => Self::Bool(*x),
            ConstDesc::Unit => Self::Unit,
            ConstDesc::Byte(x) => Self::Byte(*x),
            ConstDesc::Decimal { mantissa, scale } => Self::Decimal(*mantissa, *scale),
            ConstDesc::Ctor { ctor, args } => Self::Ctor(*ctor, args.clone()),
            ConstDesc::List(x) => Self::List(x.clone()),
            ConstDesc::Map(x) => Self::Map(x.clone()),
            ConstDesc::Set(x) => Self::Set(x.clone()),
            ConstDesc::Func(x) => Self::Func(*x),
            ConstDesc::Dict(x) => Self::Dict(*x),
        }
    }
}

pub(super) fn scalar(c: &Const) -> ConstDesc {
    match c {
        Const::Int(x) => ConstDesc::Int(*x),
        Const::Float(x) => ConstDesc::Float(*x),
        Const::Str(x) => ConstDesc::Str(x.clone()),
        Const::Char(x) => ConstDesc::Char(*x),
        Const::Bool(x) => ConstDesc::Bool(*x),
        Const::Unit => ConstDesc::Unit,
        Const::Byte(x) => ConstDesc::Byte(*x),
        Const::Decimal(x) => ConstDesc::Decimal {
            mantissa: x.mantissa(),
            scale: x.scale(),
        },
    }
}

// プログラム全体の表は 65536 項目以上を拒む（10-07「オペランドの補足」）。
fn table_limit(size: usize) -> bool {
    size >= 65536
}

impl Gen<'_> {
    fn check_table(&mut self, code: DiagCode, size: usize, identity: String, name: &str) {
        if table_limit(size) && self.limit_keys.insert((code, identity)) {
            self.diags.push(
                DiagBuilder::new(code)
                    .arg("name", name)
                    .note("limit")
                    .build(),
            );
        }
    }
    pub(super) fn constant(&mut self, desc: ConstDesc) -> CgResult<ConstIdx> {
        let key = ConstKey::of(&desc);
        if let Some(index) = self.const_index.get(&key) {
            return Ok(*index);
        }
        let index = ConstIdx(count(self.out.consts.len())?);
        self.out.consts.push(desc);
        self.const_index.insert(key, index);
        Ok(index)
    }
    pub(super) fn ctor(&mut self, adt: BindingId, tag: u32) -> CgResult<CtorIdx> {
        if let Some(index) = self.ctor_index.get(&(adt, tag)) {
            return Ok(*index);
        }
        let data = self
            .input
            .adts
            .get(adt)
            .ok_or_else(|| internal("unknown constructor type"))?;
        let ctor = data
            .ctors
            .iter()
            .find(|c| c.tag == tag)
            .ok_or_else(|| internal("unknown constructor tag"))?;
        let index = CtorIdx(count(self.out.ctors.len())?);
        self.out.ctors.push(CtorInfo {
            type_name: data.name.clone(),
            ctor_name: ctor.name.clone(),
            tag,
            arity: r16(count(ctor.fields.len())?),
        });
        self.ctor_index.insert((adt, tag), index);
        self.check_table(DiagCode::L0105, self.out.ctors.len(), String::new(), "");
        Ok(index)
    }
    pub(super) fn trait_(&mut self, class: BindingId) -> CgResult<TraitIdx> {
        if let Some(index) = self.trait_index.get(&class) {
            return Ok(*index);
        }
        let cl = self
            .input
            .traits
            .get(class)
            .ok_or_else(|| internal("unknown trait"))?;
        let name = cl.name.clone();
        let index = TraitIdx(count(self.out.traits.len())?);
        self.trait_index.insert(class, index);
        self.out.traits.push(TraitInfo {
            name: name.clone(),
            methods: Vec::new(),
            supers: Vec::new(),
        });
        let mut methods = Vec::new();
        let names = self
            .input
            .impls
            .iter()
            .find(|imp| imp.class == class)
            .map(|imp| &imp.methods);
        for (i, method) in cl.methods.iter().enumerate() {
            let scheme = self
                .input
                .schemes
                .get(*method)
                .ok_or_else(|| internal("missing method scheme"))?;
            // 先頭の辞書はメソッドを選ぶ V であり、引数の辞書 Ū に数えない（01-12「型クラス」）。
            let own = scheme
                .class_constraints
                .len()
                .checked_sub(1)
                .ok_or_else(|| internal("method has no owner constraint"))?;
            let arity = own.saturating_add(scheme.params.len());
            let method_name = names
                .and_then(|defs| defs.get(i))
                .map_or("", |def| def.name.rsplit('.').next().unwrap_or(""));
            methods.push(MethodInfo {
                name: method_name.to_string(),
                arity: r16(count(arity)?),
            });
        }
        let mut supers = Vec::new();
        for cl in &cl.supers {
            supers.push(self.trait_(*cl)?);
        }
        self.check_table(DiagCode::L0109, methods.len(), format!("{class:?}"), &name);
        self.check_table(DiagCode::L0110, supers.len(), format!("{class:?}"), &name);
        let slot = usize::try_from(index.0)
            .ok()
            .and_then(|i| self.out.traits.get_mut(i))
            .ok_or_else(|| internal("invalid trait slot"))?;
        slot.methods = methods;
        slot.supers = supers;
        Ok(index)
    }
    pub(super) fn implementation(&mut self, decl: NodeId) -> CgResult<ImplIdx> {
        if let Some(index) = self.impl_index.get(&decl) {
            return Ok(*index);
        }
        let imp = self
            .input
            .impls
            .iter()
            .find(|imp| imp.impl_decl == decl)
            .ok_or_else(|| internal("unknown implementation"))?;
        let class = self.trait_(imp.class)?;
        let index = ImplIdx(count(self.out.impls.len())?);
        let methods = self
            .method_protos
            .get(&decl)
            .cloned()
            .ok_or_else(|| internal("missing method prototypes"))?;
        self.impl_index.insert(decl, index);
        self.out.impls.push(ImplInfo {
            name: imp.name.clone(),
            trait_: class,
            dict_arity: r16(count(imp.dict_params.len())?),
            methods,
            supers: Vec::new(),
        });
        self.check_table(DiagCode::L0107, self.out.impls.len(), String::new(), "");
        let name = self
            .input
            .traits
            .get(imp.class)
            .ok_or_else(|| internal("unknown trait"))?
            .name
            .clone();
        self.check_table(
            DiagCode::L0111,
            imp.dict_params.len(),
            format!("{decl:?}"),
            &name,
        );
        let mut supers = Vec::new();
        for dict in &imp.supers {
            supers.push(self.recipe(dict)?);
        }
        let slot = usize::try_from(index.0)
            .ok()
            .and_then(|i| self.out.impls.get_mut(i))
            .ok_or_else(|| internal("invalid implementation slot"))?;
        slot.supers = supers;
        Ok(index)
    }
    fn recipe(&mut self, dict: &DictVal) -> CgResult<DictRecipe> {
        match &dict.kind {
            DictKind::Impl {
                impl_decl, args, ..
            } => {
                let imp = self.implementation(*impl_decl)?;
                let args = args
                    .iter()
                    .map(|d| self.recipe(d))
                    .collect::<CgResult<_>>()?;
                Ok(DictRecipe::Impl { imp, args })
            }
            DictKind::ImplParam(i) => Ok(DictRecipe::Param(r16(*i))),
            DictKind::Super { of, index } => Ok(DictRecipe::Super {
                of: Box::new(self.recipe(of)?),
                index: r16(*index),
            }),
            DictKind::Param(_) => Err(internal(
                "function dictionary parameter in a supertrait recipe",
            )),
        }
    }
    pub(super) fn operation(&mut self, binding: BindingId) -> CgResult<OpIdx> {
        if let Some(index) = self.op_index.get(&binding) {
            return Ok(*index);
        }
        let op = self
            .input
            .ops
            .iter()
            .find(|op| op.binding == binding)
            .ok_or_else(|| internal("unknown operation"))?;
        let effect = match op.effect {
            EffectName::User(_) => op
                .name
                .rsplit_once('.')
                .map_or("", |(head, _)| head)
                .to_string(),
            EffectName::Builtin(id) => {
                let def = id.def().ok_or_else(|| internal("unknown builtin effect"))?;
                def.module.last().map_or_else(
                    || def.name.to_string(),
                    |module| format!("{module}.{}", def.name),
                )
            }
        };
        let index = OpIdx(count(self.out.ops.len())?);
        self.op_index.insert(binding, index);
        self.out.ops.push(OpInfo {
            name: op.name.clone(),
            effect,
            arity: r16(op.arity),
            builtin: None,
        });
        self.check_table(DiagCode::L0108, self.out.ops.len(), String::new(), "");
        if let Some(id) = op.builtin {
            let builtin = self.builtin(id, Some(binding))?;
            let slot = usize::try_from(index.0)
                .ok()
                .and_then(|i| self.out.ops.get_mut(i))
                .ok_or_else(|| internal("invalid operation slot"))?;
            slot.builtin = Some(builtin);
        }
        Ok(index)
    }
    pub(super) fn builtin(
        &mut self,
        id: BuiltinId,
        op: Option<BindingId>,
    ) -> CgResult<BuiltinRefIdx> {
        if let Some(index) = self.builtin_index.get(&id) {
            return Ok(*index);
        }
        let decl = crate::builtins::builtin_decl(id).ok_or_else(|| internal("unknown builtin"))?;
        let index = BuiltinRefIdx(count(self.out.builtins.len())?);
        self.builtin_index.insert(id, index);
        self.out.builtins.push(BuiltinRef {
            id,
            arity: decl.arity,
            capability: decl.capability,
            op: None,
        });
        self.check_table(DiagCode::L0106, self.out.builtins.len(), String::new(), "");
        let op = if decl.capability == Capability::Io {
            Some(
                op.or_else(|| {
                    self.input
                        .ops
                        .iter()
                        .find(|op| op.builtin == Some(id))
                        .map(|op| op.binding)
                })
                .ok_or_else(|| internal("builtin operation has no binding"))?,
            )
        } else {
            None
        };
        if let Some(binding) = op {
            let op_index = self.operation(binding)?;
            let slot = usize::try_from(index.0)
                .ok()
                .and_then(|i| self.out.builtins.get_mut(i))
                .ok_or_else(|| internal("invalid builtin slot"))?;
            slot.op = Some(op_index);
        }
        Ok(index)
    }
    pub(super) fn const_ref(&mut self, binding: BindingId) -> CgResult<ConstIdx> {
        if let Some(index) = self.const_refs.get(&binding) {
            return Ok(*index);
        }
        let value = &self
            .input
            .consts
            .iter()
            .find(|c| c.binding == binding)
            .ok_or_else(|| internal("unknown constant"))?
            .value;
        let index = self.const_value(value)?;
        self.const_refs.insert(binding, index);
        Ok(index)
    }
    fn const_value(&mut self, value: &ConstValue) -> CgResult<ConstIdx> {
        let desc = match value {
            ConstValue::Integer(x) => ConstDesc::Int(*x),
            ConstValue::Float(x) => ConstDesc::Float(*x),
            ConstValue::String(x) => ConstDesc::Str(x.clone()),
            ConstValue::Character(x) => ConstDesc::Char(*x),
            ConstValue::Boolean(x) => ConstDesc::Bool(*x),
            ConstValue::Unit => ConstDesc::Unit,
            ConstValue::Byte(x) => ConstDesc::Byte(*x),
            ConstValue::Decimal(x) => ConstDesc::Decimal {
                mantissa: x.mantissa(),
                scale: x.scale(),
            },
            ConstValue::Ctor { adt, tag, args } => {
                let ctor = self.ctor(*adt, *tag)?;
                let args = args
                    .iter()
                    .map(|v| self.const_value(v))
                    .collect::<CgResult<_>>()?;
                ConstDesc::Ctor { ctor, args }
            }
            ConstValue::List(xs) => ConstDesc::List(
                xs.iter()
                    .map(|v| self.const_value(v))
                    .collect::<CgResult<_>>()?,
            ),
            ConstValue::Set(xs) => ConstDesc::Set(
                xs.iter()
                    .map(|v| self.const_value(v))
                    .collect::<CgResult<_>>()?,
            ),
            ConstValue::Map(xs) => ConstDesc::Map(
                xs.iter()
                    .map(|(k, v)| Ok((self.const_value(k)?, self.const_value(v)?)))
                    .collect::<CgResult<_>>()?,
            ),
        };
        self.constant(desc)
    }
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    use super::*;
    // 関門: F15 が非公開の関数での検査を指定する。巨大な表の構築に費やさず、符号化の境界を確かめる。
    #[test]
    fn global_limits_have_no_span_and_are_reported_once_per_table() {
        let (lower, sources) = super::super::tests::over_limit_program(0, false);
        let mut g = Gen::new(&lower, sources);
        for code in [
            DiagCode::L0105,
            DiagCode::L0106,
            DiagCode::L0107,
            DiagCode::L0108,
            DiagCode::L0109,
            DiagCode::L0110,
            DiagCode::L0111,
        ] {
            for size in [65535, 65536, 65537] {
                g.check_table(code, size, "table".into(), "Trait");
            }
        }
        assert_eq!(g.diags.len(), 7);
        assert!(g.diags.iter().all(|d| d.primary.is_none()));
        assert!(!table_limit(65535));
        assert!(table_limit(65536));
    }
}

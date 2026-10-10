//! E2 の宣言表。入力ごとの束縛の番号を保ち、版 7 の corpus とは別に書き出す。
use super::*;
use benitoite::builtins::BuiltinId;
use benitoite::builtins::iface::Capability;
use benitoite::types::builtin::{BUILTIN_EFFECTS, BUILTIN_TYPES, BuiltinEffectId};

// 表層の参照・節とコアの prim をすべて含める。脱糖が挿入した関数も落とさない。
fn used_prims(value: &Value, names: &mut BTreeSet<String>) {
    match value {
        Value::Array(xs) => xs.iter().for_each(|v| used_prims(v, names)),
        Value::Object(xs) => {
            for tag in ["prim", "primName"] {
                if let Some(name) = value.get(tag).and_then(|v| v["name"].as_str()) {
                    names.insert(name.to_owned());
                }
            }
            xs.values().for_each(|v| used_prims(v, names));
        }
        Value::Null | Value::Bool(_) | Value::Number(_) | Value::String(_) => {}
    }
}

// opaque の名前の中の引数は Release.Ty.subst が辿れない。具体的な引数でも印を残す。
fn opaque_arguments(ty: &Ty, names: &mut BTreeSet<String>) {
    match ty {
        Ty::Con(con, args) => {
            if let TyCon::Builtin(id) = con
                && !args.is_empty()
                && !matches!(*id, BuiltinTypeId::REFERENCE | BuiltinTypeId::LAZY)
                && id.def().is_some_and(|d| {
                    matches!(
                        d.class,
                        BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                    )
                })
            {
                names.insert(id.def().unwrap().name.to_owned());
            }
            args.iter().for_each(|t| opaque_arguments(t, names));
        }
        Ty::Fn(f) => {
            f.params.iter().for_each(|t| opaque_arguments(t, names));
            opaque_arguments(&f.ret, names);
        }
        Ty::App(_, args) => args.iter().for_each(|t| opaque_arguments(t, names)),
        Ty::Param(_) | Ty::Rigid { .. } => {}
    }
}

fn summary(s: &types::TypeSummary) -> Value {
    json!({"always":s.always,"dependsOn":s.depends_on})
}

/// 未 import の操作の宣言も得るための書き出し専用の入力。corpus には入れない。
pub fn complete_stdlib() -> CheckedProgram {
    let mut source = String::new();
    for module in benitoite::prelude::STDLIB.iter().filter(|m| !m.prelude) {
        source.push_str(&format!(
            "import Benitoite.{}{}\n",
            if module.unofficial { "Unofficial." } else { "" },
            module.path.join(".")
        ));
    }
    let checked = benitoite::pipeline::check_text(
        "builtin-declarations.bnt",
        source.as_bytes(),
        benitoite::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(
        checked.error_count(),
        0,
        "complete stdlib: {:?}",
        checked.diagnostics
    );
    checked.program.unwrap()
}

// 補助入力のデータ型だけを元の入力の名前空間へ移す。型パラメータ・エフェクトは変えない。
fn remap_ty(ty: &Ty, names: &BTreeMap<BindingId, BindingId>) -> Ty {
    match ty {
        Ty::Con(con, args) => Ty::Con(
            match con {
                TyCon::Adt(id) => TyCon::Adt(names[id]),
                TyCon::Builtin(id) => TyCon::Builtin(*id),
            },
            args.iter().map(|t| remap_ty(t, names)).collect(),
        ),
        Ty::Fn(f) => Ty::Fn(Box::new(types::FnTy {
            params: f.params.iter().map(|t| remap_ty(t, names)).collect(),
            ret: remap_ty(&f.ret, names),
            effects: f.effects.clone(),
        })),
        Ty::App(i, args) => Ty::App(*i, args.iter().map(|t| remap_ty(t, names)).collect()),
        Ty::Param(_) | Ty::Rigid { .. } => ty.clone(),
    }
}

fn qualified_data(p: &CheckedProgram, adt: &types::AdtDef) -> String {
    format!(
        "{}.{}",
        p.modules.get(adt.module).unwrap().name.dotted(),
        adt.name
    )
}

/// 使用する prim と組み込みの操作全体、データ型の宣言と要約を入力の識別子とともに返す。
pub fn builtin_tables(p: &CheckedProgram, input: &Value, stdlib: &CheckedProgram) -> Value {
    let mut names = BTreeMap::new();
    let mut supplemental_data = Vec::new();
    let mut next = p
        .resolved
        .bindings
        .iter()
        .map(|(id, _)| id.0)
        .max()
        .unwrap()
        + 1;
    // レコードの同名の構成子が公開の索引の型名を上書きする場合もあるため、
    // 公開の名前の索引ではなく、モジュールと AdtDef の名前から型の修飾名を作る。
    let existing: BTreeMap<_, _> = p
        .types
        .adts
        .adts
        .iter()
        .filter(|(_, adt)| {
            matches!(
                p.modules.get(adt.module).unwrap().kind,
                benitoite::modules::ModuleKind::Prelude | benitoite::modules::ModuleKind::Stdlib
            )
        })
        .map(|(id, adt)| (qualified_data(p, adt), id))
        .collect();
    for (id, adt) in stdlib.types.adts.adts.iter() {
        let qualified = qualified_data(stdlib, adt);
        let local = if let Some(id) = existing.get(&qualified) {
            *id
        } else {
            let id = BindingId(next);
            next += 1;
            supplemental_data.push(json!([data_name(id), qualified]));
            id
        };
        names.insert(id, local);
    }
    let mut used = BTreeSet::new();
    used_prims(input, &mut used);
    let mut prims = Vec::new();
    let mut state_pure = Vec::new();
    let mut supplemental_prims = Vec::new();
    let mut surface = Surface::new(p, None, Vec::new());
    for index in 0..=u16::MAX {
        let id = BuiltinId(index);
        let Some(decl) = builtins::builtin_decl(id) else {
            break;
        };
        let entry = table::builtin_kind(id).unwrap();
        if entry != table::EntryKind::EffectOp && !used.contains(decl.name) {
            continue;
        }
        let binding = p.resolved.bindings.iter().find_map(|(binding, b)| {
            let matches = match (entry, &b.kind) {
                (table::EntryKind::Declared, BindingKind::BuiltinFn(b)) => *b == id,
                (table::EntryKind::EffectOp, BindingKind::Op { .. }) => {
                    p.resolved.builtin_ops.get(binding) == Some(&id)
                }
                _ => false,
            };
            matches.then_some(binding)
        });
        let scheme = match entry {
            table::EntryKind::Declared | table::EntryKind::EffectOp => {
                if let Some(binding) = binding {
                    p.types.decl_types.get(binding).unwrap().clone()
                } else {
                    assert_eq!(
                        entry,
                        table::EntryKind::EffectOp,
                        "missing used builtin: {}",
                        decl.name
                    );
                    let binding = stdlib
                        .resolved
                        .builtin_ops
                        .iter()
                        .find_map(|(binding, b)| (*b == id).then_some(binding))
                        .unwrap_or_else(|| panic!("missing builtin operation: {}", decl.name));
                    let mut scheme = stdlib.types.decl_types.get(binding).unwrap().clone();
                    scheme.params = scheme.params.iter().map(|t| remap_ty(t, &names)).collect();
                    scheme.ret = remap_ty(&scheme.ret, &names);
                    supplemental_prims.push(decl.name);
                    scheme
                }
            }
            table::EntryKind::Operator { .. }
            | table::EntryKind::Equality { .. }
            | table::EntryKind::ListPattern(_)
            | table::EntryKind::Interpolation { .. } => table::builtin_scheme(id).unwrap(),
        };
        // operation_tables と同じ番号順。prim の tys の番号を入れ替えない。
        let tparams: Vec<_> = scheme
            .type_params
            .iter()
            .map(|t| {
                let equality = matches!(
                    t.builtin,
                    Some(types::BuiltinConstraint::Equality | types::BuiltinConstraint::Key)
                );
                json!({"equality":equality,"key":t.builtin == Some(types::BuiltinConstraint::Key),
                "ordered":t.builtin == Some(types::BuiltinConstraint::Ordered)})
            })
            .collect();
        let mut unconvertible = BTreeSet::new();
        scheme
            .params
            .iter()
            .for_each(|t| opaque_arguments(t, &mut unconvertible));
        opaque_arguments(&scheme.ret, &mut unconvertible);
        let kind = match decl.name {
            "Reference.new" => "refNew",
            "Reference.get" => "refGet",
            "Reference.set" => "refSet",
            "Reference.update" => "refUpdate",
            "Lazy.force" => "force",
            "Benitoite.IO.Process.exit" => "exit",
            _ if entry == table::EntryKind::EffectOp => "io",
            _ => "pure",
        };
        let op_eff = if entry == table::EntryKind::EffectOp {
            assert_eq!(decl.capability, Capability::Io);
            assert!(scheme.effect_params.is_empty());
            assert!(scheme.effects.vars.is_empty());
            let effect = eff(&scheme.effects);
            assert_eq!(effect.as_array().unwrap().len(), 1);
            Some(effect[0]["name"]["value"].as_str().unwrap().to_owned())
        } else {
            None
        };
        if decl.capability == Capability::State && kind == "pure" {
            state_pure.push(decl.name);
        }
        let params: Vec<_> = scheme.params.iter().map(|t| surface.ty(t)).collect();
        prims.push(json!({"name":decl.name,"tparams":tparams,"neffs":scheme.effect_params.len(),
            "params":params,"ret":surface.ty(&scheme.ret),"eff":eff(&scheme.effects),
            "kind":kind,"opEff":op_eff,"classConstraints":surface.dict_params(&scheme.class_constraints),
            "unconvertibleTypes":unconvertible}));
    }
    let effects: Vec<_> = BUILTIN_EFFECTS
        .iter()
        .enumerate()
        .filter_map(|(i, _)| {
            let id = BuiltinEffectId(u16::try_from(i).unwrap());
            // IO.All は注釈の別名であり、EffectSet に現れない。
            if id == BuiltinEffectId::IO_ALL {
                return None;
            }
            let effect = eff(&EffectSet {
                names: vec![EffectName::Builtin(id)],
                vars: vec![],
            });
            let name = effect[0]["name"]["value"].as_str().unwrap();
            let ops: Vec<_> = prims
                .iter()
                .filter(|p| p["opEff"].as_str() == Some(name))
                .map(|p| p["name"].clone())
                .collect();
            assert!(
                id == BuiltinEffectId::STATE || !ops.is_empty(),
                "missing builtin operations: {name}"
            );
            Some(json!({"name":name,"ops":ops}))
        })
        .collect();
    let resources: Vec<_> = BUILTIN_TYPES
        .iter()
        .enumerate()
        .filter(|(_, d)| d.class == BuiltinTypeClass::Resource)
        .map(|(i, _)| u16::try_from(i).unwrap())
        .collect();
    let mut data_decls = Vec::new();
    let mut summaries = Vec::new();
    let mut adts: Vec<_> = p
        .types
        .adts
        .adts
        .iter()
        .map(|(id, adt)| (id, adt.clone()))
        .collect();
    for (id, adt) in stdlib.types.adts.adts.iter() {
        let local = names[&id];
        if p.types.adts.get(local).is_none() {
            let mut adt = adt.clone();
            adt.binding = local;
            for ctor in &mut adt.ctors {
                ctor.fields = ctor.fields.iter().map(|t| remap_ty(t, &names)).collect();
            }
            adts.push((local, adt));
        }
    }
    adts.sort_by_key(|(id, _)| *id);
    for (id, adt) in adts {
        assert_eq!(id, adt.binding);
        let ctors: Vec<_> = adt
            .ctors
            .iter()
            .enumerate()
            .map(|(tag, c)| {
                assert_eq!(u32::try_from(tag).unwrap(), c.tag);
                let args: Vec<_> = c.fields.iter().map(|t| surface.ty(t)).collect();
                json!({"name":con_name(id, c.tag),"args":args})
            })
            .collect();
        data_decls.push(json!({"name":data_name(id),"ntys":adt.type_params.len(),"ctors":ctors}));
        summaries.push(json!({"name":data_name(id),"eq":summary(&adt.eq_summary),"key":summary(&adt.key_summary)}));
    }
    assert!(
        surface.outside.is_empty(),
        "unsupported builtin/data declaration: {:?}",
        surface.outside
    );
    json!({"group":input["group"],"name":input["name"],"prims":prims,"effects":effects,
        "resources":resources,"dataDecls":data_decls,"summaries":summaries,"statePure":state_pure,
        "supplementalData":supplemental_data,"supplementalPrims":supplemental_prims})
}

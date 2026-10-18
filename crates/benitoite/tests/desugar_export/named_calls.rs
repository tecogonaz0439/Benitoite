//! 名前と位置を保持する呼び出しの交換（設計書 07-04「証明する性質」）。
use super::*;
use benitoite::typeck::CallPlan;

/// ソース順の引数を保ち、対応表を交換形式の必須欄へ写す。
/// 穴付きの args は expr/hole、通常の args は式そのものである。
pub fn call_fields(
    callee: Value,
    labels: Vec<Option<String>>,
    mut args: Vec<Value>,
    plan: &CallPlan,
    names: &[String],
    partial: Option<(Value, Value)>,
) -> Value {
    assert_eq!(names.len(), usize::try_from(plan.arity).unwrap());
    assert_eq!(names.iter().collect::<BTreeSet<_>>().len(), names.len());
    assert_eq!(labels.len(), args.len());
    assert_eq!(plan.source_to_param.len(), args.len());
    let mut occupied = BTreeSet::new();
    if plan.inserted_first {
        assert!(plan.arity > 0);
        occupied.insert(0);
    }
    for position in &plan.source_to_param {
        assert!(*position < plan.arity);
        assert!(occupied.insert(*position), "duplicate argument position");
    }
    assert_eq!(occupied.len(), usize::try_from(plan.arity).unwrap());
    if let Some((ret, eff)) = partial {
        assert!(
            !plan.inserted_first,
            "partial calls do not insert an argument"
        );
        assert_eq!(
            args.iter().filter(|a| a.get("hole").is_some()).count(),
            plan.hole_names.len()
        );
        assert_eq!(
            args.iter()
                .zip(&plan.source_to_param)
                .filter(|(a, _)| a.get("hole").is_some())
                .map(|(_, i)| names[usize::try_from(*i).unwrap()].clone())
                .collect::<Vec<_>>(),
            plan.hole_names
        );
        for ((arg, label), position) in args.iter_mut().zip(labels).zip(&plan.source_to_param) {
            let field = if arg.get("hole").is_some() {
                "hole"
            } else {
                "expr"
            };
            assert!(arg.get(field).is_some());
            arg[field]["label"] = json!(label);
            arg[field]["position"] = json!(position);
        }
        tagged(
            "partialCall",
            json!({"callee":callee,"names":names,"args":args,"ret":ret,"eff":eff}),
        )
    } else {
        assert!(plan.hole_names.is_empty());
        tagged(
            "call",
            json!({"callee":callee,"labels":labels,"positions":plan.source_to_param,"args":args}),
        )
    }
}

fn placeholder(arg: &a::Arg) -> Option<&a::PlaceholderArg> {
    match arg {
        a::Arg::Placeholder(p) => Some(p),
        a::Arg::Named(a) => match &a.value {
            a::ArgValue::Placeholder(p) => Some(p),
            a::ArgValue::Expr(_) => None,
        },
        a::Arg::Expr(_) => None,
    }
}

impl Surface<'_> {
    pub(super) fn named_call(
        &mut self,
        v: &a::CallExpr,
        env: &[SurfaceSlot],
        ctor: Option<(String, Vec<Value>)>,
    ) -> Value {
        let plan = self
            .p
            .types
            .call_plans
            .get(v.id)
            .expect("named call plan")
            .clone();
        let holes = v.args.iter().any(|a| placeholder(a).is_some());
        let saved_ret = self.return_ty.clone();
        let partial = if holes {
            let Ty::Fn(f) = self.p.types.expr_types.get(v.id).unwrap() else {
                panic!("partial type")
            };
            assert_eq!(f.param_names.len(), f.params.len());
            assert_eq!(f.param_names, plan.hole_names);
            self.return_ty = Some(f.ret.clone());
            Some((
                self.ty(&f.ret),
                self.eff(self.p.types.lambda_effects.get(v.id).unwrap()),
            ))
        } else {
            None
        };
        let callee = if ctor.is_none() {
            self.expr(&v.callee, env)
        } else {
            self.node_ty(v.callee.id());
            json!("unit")
        };
        let mut labels = vec![];
        let args = v
            .args
            .iter()
            .map(|arg| {
                labels.push(match arg {
                    a::Arg::Named(a) => Some(a.name.text.clone()),
                    a::Arg::Expr(_) | a::Arg::Placeholder(_) => None,
                });
                if let Some(p) = placeholder(arg) {
                    tagged("hole", json!({"ty":self.node_ty(p.id)}))
                } else {
                    let inner = self.expr(
                        match arg {
                            a::Arg::Expr(e) => e,
                            a::Arg::Named(a) => match &a.value {
                                a::ArgValue::Expr(e) => e,
                                a::ArgValue::Placeholder(_) => unreachable!(),
                            },
                            a::Arg::Placeholder(_) => unreachable!(),
                        },
                        env,
                    );
                    if holes {
                        tagged("expr", json!({"inner":inner}))
                    } else {
                        inner
                    }
                }
            })
            .collect();
        self.return_ty = saved_ret;
        let Ty::Fn(f) = self.p.types.expr_types.get(v.callee.id()).unwrap() else {
            panic!("callee type")
        };
        assert_eq!(f.param_names.len(), f.params.len());
        let call = call_fields(callee, labels, args, &plan, &f.param_names, partial);
        if let Some((name, tys)) = ctor {
            assert!(v.args.iter().all(|a| !matches!(a, a::Arg::Named(_))));
            assert_eq!(
                plan.source_to_param,
                (u32::from(plan.inserted_first)..plan.arity).collect::<Vec<_>>()
            );
            let field = if holes { "partialCall" } else { "call" };
            tagged(
                if holes { "partialCon" } else { "conCall" },
                json!({"name":name,"tys":tys,"args":call[field]["args"]}),
            )
        } else {
            call
        }
    }
}

//! ソースの解析から、脱糖の評価順と一回性を独立したコアと実行結果で確かめる
//! （設計書 02-06「内部の終了報告」、07-03「テストの設計の原則」）。
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::test_support::desugar_die_source;
use crate::base::Span;
use crate::builtins::iface::Capability;
use crate::ir::core_ir::*;
use crate::types::builtin::BuiltinTypeId;
use crate::types::{EffectName, EffectSet, FnTy, Ty, TyCon, TypeArg, TypeArgs};

fn source_span(start: usize, end: usize) -> Span {
    Span {
        file: crate::base::FileId(0),
        start: crate::base::BytePos(u32::try_from(start).unwrap()),
        end: crate::base::BytePos(u32::try_from(end).unwrap()),
    }
}

fn ty(id: BuiltinTypeId) -> Ty {
    Ty::Con(TyCon::Builtin(id), vec![])
}
fn val(kind: ValKind<Comp>, ty: Ty, origin: Span) -> CoreVal {
    Val { kind, ty, origin }
}
fn reference(var: &Var, origin: Span) -> CoreVal {
    val(ValKind::Var(var.id), var.ty.clone(), origin)
}
fn ret(value: CoreVal) -> Comp {
    Comp {
        ty: value.ty.clone(),
        eff: EffectSet::empty(),
        origin: value.origin,
        kind: CompKind::Return(value),
    }
}
fn let_in(var: Var, bound: Comp, body: Comp, origin: Span) -> Comp {
    Comp {
        ty: body.ty.clone(),
        eff: bound.eff.union(&body.eff),
        origin,
        kind: CompKind::Let {
            var,
            bound: Box::new(bound),
            body: Box::new(body),
        },
    }
}

// 関門: 公開の脱糖が返す失敗分岐を、入力・説明・表示が各一つの独立した期待コアと比べる。
// 従来の Return と報告を手で付けた App の検査には、Die の分岐生成と辞書の接続がない。
// 変数番号は束縛から読むが、期待する計算・参照・順序は型検査の TryInfo から作らない。
#[test]
fn die_failure_core_has_one_message_then_one_cause_and_canonical_exit() {
    for kind in ["result", "generic", "option"] {
        for message in [None, Some(""), Some("context")] {
            let (params, input) = match kind {
                "result" => ("", "Result[Integer, String]"),
                "generic" => ("[E: Trait.Show]", "Result[Integer, E]"),
                "option" => ("", "Option[Integer]"),
                _ => unreachable!(),
            };
            let suffix = message.map_or(String::new(), |s| format!("(\"{s}\")"));
            let source = format!(
                "import Benitoite.Trait\nimport Benitoite.Unofficial.IO.Process\nfunction f{params}(r: {input}) -> Integer uses Process.Exit\n return try r or die{suffix}\nend function\n"
            );
            let (_, resolved, _, core) = desugar_die_source(&source);
            let def = core.defs.iter().find(|d| d.name == "f").unwrap();
            let CompKind::Let {
                var: operand,
                bound,
                body,
            } = &def.body.kind
            else {
                panic!("input must be evaluated once before match")
            };
            let CompKind::Match {
                scrutinee,
                rows,
                arms,
            } = &body.kind
            else {
                panic!("two-way match")
            };
            let at = body.origin;
            assert_eq!(**bound, ret(reference(&def.params[0], bound.origin)));
            assert_eq!(*scrutinee, reference(operand, bound.origin));
            assert_eq!(rows.len(), 2);
            assert_eq!(arms.len(), 2);
            let constructor = resolved
                .stdlib(if kind == "option" {
                    "Benitoite.Option.Some"
                } else {
                    "Benitoite.Result.Ok"
                })
                .unwrap();
            let crate::resolve::BindingKind::Ctor { data: adt, .. } =
                resolved.bindings.get(constructor).unwrap().kind
            else {
                panic!("standard constructor")
            };
            let success = &arms[0].vars[0];
            assert_eq!(success.ty, ty(BuiltinTypeId::INTEGER));
            assert_eq!(
                rows[0],
                MatchRow {
                    pattern: CorePat::Ctor {
                        adt,
                        tag: 0,
                        args: vec![CorePat::Var(success.id)]
                    },
                    arm: 0,
                }
            );
            assert_eq!(arms[0].guard, None);
            assert_eq!(arms[0].body, ret(reference(success, at)));
            assert_eq!(arms[1].guard, None);
            assert_eq!(arms[1].vars.len(), usize::from(kind != "option"));
            assert_eq!(
                rows[1],
                MatchRow {
                    pattern: CorePat::Ctor {
                        adt,
                        tag: 1,
                        args: arms[1].vars.iter().map(|v| CorePat::Var(v.id)).collect()
                    },
                    arm: 1,
                }
            );
            let (message_var, cause_body) = if let Some(message_text) = message {
                let CompKind::Let { var, bound, body } = &arms[1].body.kind else {
                    panic!("message let")
                };
                assert_eq!(var.ty, ty(BuiltinTypeId::STRING));
                assert_eq!(
                    **bound,
                    ret(val(
                        ValKind::Const(Const::Str(message_text.into())),
                        ty(BuiltinTypeId::STRING),
                        bound.origin
                    ))
                );
                (Some((var, bound.origin)), body.as_ref())
            } else {
                (None, &arms[1].body)
            };
            let CompKind::Let {
                var: cause,
                body: exit,
                ..
            } = &cause_body.kind
            else {
                panic!("cause let")
            };
            assert_eq!(cause.ty, ty(BuiltinTypeId::STRING));
            let expected_cause = if kind == "option" {
                ret(val(
                    ValKind::Const(Const::Str("expected a value, got Option.None".into())),
                    ty(BuiltinTypeId::STRING),
                    at,
                ))
            } else {
                let dict_kind = if kind == "generic" {
                    DictKind::Param(def.dict_params[0].var)
                } else {
                    let implementation = core
                        .impls
                        .iter()
                        .find(|i| {
                            i.class == resolved.stdlib("Benitoite.Trait.Show").unwrap()
                                && i.target == TypeArg::Ty(ty(BuiltinTypeId::STRING))
                        })
                        .unwrap();
                    DictKind::Impl {
                        impl_decl: implementation.impl_decl,
                        tys: vec![],
                        args: vec![],
                    }
                };
                Comp {
                    kind: CompKind::Method(Box::new(MethodCall {
                        dict: DictVal {
                            kind: dict_kind,
                            class: resolved.stdlib("Benitoite.Trait.Show").unwrap(),
                            arg: TypeArg::Ty(if kind == "generic" {
                                Ty::Param(0)
                            } else {
                                ty(BuiltinTypeId::STRING)
                            }),
                            origin: at,
                        },
                        method: 0,
                        targs: TypeArgs::default(),
                        dicts: vec![],
                        args: vec![reference(&arms[1].vars[0], at)],
                    })),
                    ty: ty(BuiltinTypeId::STRING),
                    eff: EffectSet::empty(),
                    origin: at,
                }
            };
            let effects = EffectSet {
                names: vec![EffectName::Builtin(
                    crate::types::builtin::find_builtin_effect(&["IO", "Process"], "Exit").unwrap(),
                )],
                vars: vec![],
            };
            let exit_id = resolved.stdlib("Benitoite.IO.Process.exit").unwrap();
            let expected_exit = Comp {
                kind: CompKind::App {
                    func: val(
                        ValKind::Builtin {
                            id: crate::builtins::lookup_builtin("Benitoite.IO.Process.exit")
                                .unwrap(),
                            info: BuiltinInfo {
                                class: Capability::Io,
                                decl: Some(exit_id),
                                op: Some(exit_id),
                                intrinsic: None,
                            },
                            targs: TypeArgs {
                                tys: vec![TypeArg::Ty(ty(BuiltinTypeId::INTEGER))],
                                effects: vec![],
                            },
                        },
                        Ty::Fn(Box::new(FnTy {
                            param_names: vec!["code".into()],
                            params: vec![ty(BuiltinTypeId::INTEGER)],
                            ret: ty(BuiltinTypeId::INTEGER),
                            effects: effects.clone(),
                        })),
                        at,
                    ),
                    dicts: vec![],
                    args: vec![val(
                        ValKind::Const(Const::Int(1)),
                        ty(BuiltinTypeId::INTEGER),
                        at,
                    )],
                    exit_report: Some(ExitReportArgs {
                        cause: Box::new(reference(cause, at)),
                        message: message_var.map(|(v, origin)| Box::new(reference(v, origin))),
                    }),
                },
                ty: ty(BuiltinTypeId::INTEGER),
                eff: effects.clone(),
                origin: at,
            };
            assert_eq!(**exit, expected_exit);
            assert_eq!(
                *cause_body,
                let_in(cause.clone(), expected_cause, expected_exit, at)
            );
            assert_eq!(body.ty, ty(BuiltinTypeId::INTEGER));
            assert_eq!(body.eff, effects);
        }
    }
}

// 関門: 純粋な説明・Show の未評価と順序は実際の停止理由、入力の一回性は State で観測する。
// コアの構造比較だけでは実行器が説明を先読みする失敗を捕まえない。本番 API は増やさない。
#[test]
fn die_evaluation_uses_only_the_failure_branch_in_source_order() {
    use crate::builtins::funcs::fixed_io::FixedIo;
    use crate::refinterp::{RefOutcome, run};
    use crate::runtime::io::services::RunInput;
    use crate::runtime::{RuntimeError, Stop, Stream};
    use crate::vm::{DieFailure, MainOutcome};

    for (input, suffix, cause, message, stopped) in [
        ("Result.Ok(7)", "(explain())", None, None, None),
        ("Option.Some(7)", "(explain())", None, None, None),
        (
            "Result.Error(Bad)",
            "(explain())",
            None,
            None,
            Some("1 div 0"),
        ),
        ("Result.Error(Bad)", "", None, None, Some("2 div 0")),
        (
            "Result.Error(\"bad\\n\\\"\")",
            "",
            Some("\"bad\\n\\\"\""),
            None,
            None,
        ),
        (
            "Result.Error(\"bad\")",
            "(\"\")",
            Some("\"bad\""),
            Some(""),
            None,
        ),
        (
            "Result.Error(\"bad\")",
            "(\"context\")",
            Some("\"bad\""),
            Some("context"),
            None,
        ),
        (
            "Option.None",
            "(\"\")",
            Some("expected a value, got Option.None"),
            Some(""),
            None,
        ),
        (
            "Option.None",
            "",
            Some("expected a value, got Option.None"),
            None,
            None,
        ),
        (
            "Option.None",
            "(\"context\")",
            Some("expected a value, got Option.None"),
            Some("context"),
            None,
        ),
    ] {
        let input_ty = if input.starts_with("Option") {
            "Option[Integer]"
        } else if input.contains("Bad") || input.contains("Ok") {
            "Result[Integer, Bad]"
        } else {
            "Result[Integer, String]"
        };
        let source = format!(
            r#"
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process
data Bad
 Bad
end data
implement Trait.Show[Bad]
 function show(x: Bad) -> String
  return Integer.toString(2 div 0)
 end function
end implement
function explain() -> String
 return Integer.toString(1 div 0)
end function
function operand(count: Reference[Integer]) -> {input_ty} uses State
 Reference.update(reference: count, f: lambda(value) return value + 1 end lambda)
 return {input}
end function
function main() -> Unit uses State, Console.Write, Process.Exit
 bind count <- Reference.new(0)
 bind _ <- try operand(count) or die{suffix}
 Console.writeLine(Integer.toString(Reference.get(count)))
end function
"#
        );
        let (load, _, _, mut core) = desugar_die_source(&source);
        // この補助は require_main=false の公開の型検査を使う。実行する入口だけを指定する。
        core.main = Some(core.defs.iter().find(|d| d.name == "main").unwrap().binding);
        let mut io = FixedIo::new(RunInput {
            arguments: vec![],
            script_directory: ".".into(),
            working_directory: ".".into(),
        });
        let outcome = run(&core, &mut io);
        assert_eq!(io.take_internal_error(), None);
        if let Some(expression) = stopped {
            let start = source.find(expression).unwrap();
            assert_eq!(
                outcome,
                RefOutcome::Stopped {
                    stop: Stop::Runtime(RuntimeError::DivisionByZero),
                    origin: Some(source_span(start, start + expression.len())),
                    release_failures: vec![],
                }
            );
        } else if let Some(cause) = cause {
            let start = source.find("try operand").unwrap();
            let end = source[start..].find('\n').unwrap() + start;
            assert_eq!(
                outcome,
                RefOutcome::Exited {
                    status: 1,
                    die_failure: Some(DieFailure {
                        cause: cause.into(),
                        message: message.map(str::to_owned),
                        at: source_span(start, end),
                    }),
                    release_failures: vec![]
                }
            );
        } else {
            assert_eq!(outcome, RefOutcome::Finished(MainOutcome::Ok));
        }
        assert_eq!(
            io.take_output(),
            if stopped.is_none() && cause.is_none() {
                vec![(Stream::Stdout, b"1\n".to_vec())]
            } else {
                vec![]
            }
        );

        // 参照側だけでは、コード生成や VM の先読み・レジスタの寿命の退行を捕まえない。
        let lower = crate::ir::decision::lower_program(&core).unwrap();
        let bytecode =
            crate::bytecode::codegen::codegen(&lower, std::sync::Arc::new(load.sources)).unwrap();
        for mode in [crate::vm::ExecMode::Direct, crate::vm::ExecMode::Request] {
            let mut vm = crate::vm::Vm::new(
                &bytecode,
                crate::vm::VmConfig::default(),
                crate::runtime::heap::HeapConfig::default(),
            );
            let mut services = crate::vm::dispatch::test_support::TestIo::new(RunInput {
                arguments: vec![],
                working_directory: ".".into(),
                script_directory: ".".into(),
            });
            vm.start_main().unwrap();
            let step = loop {
                match vm.run(services.runtime(mode)) {
                    crate::vm::VmStep::Requests(ids) => {
                        for id in ids {
                            vm.serve_request(&mut services.rt, id);
                        }
                    }
                    step @ (crate::vm::VmStep::Finished(_) | crate::vm::VmStep::Stopped(_)) => {
                        break step;
                    }
                }
            };
            match &outcome {
                RefOutcome::Finished(expected) => {
                    assert_eq!(step, crate::vm::VmStep::Finished(expected.clone()));
                }
                RefOutcome::Exited {
                    status,
                    die_failure,
                    release_failures,
                } => {
                    assert_eq!(
                        step,
                        crate::vm::VmStep::Stopped(crate::vm::StopEnd {
                            reason: crate::vm::StopReason::Exit {
                                code: *status,
                                die_failure: die_failure.clone(),
                            },
                            release_failures: release_failures.clone(),
                        })
                    );
                }
                RefOutcome::Stopped {
                    stop,
                    origin,
                    release_failures,
                } => {
                    let crate::vm::VmStep::Stopped(end) = step else {
                        panic!("expected division stop: {step:?}");
                    };
                    let crate::vm::StopReason::Error(info) = end.reason else {
                        panic!("expected division stop: {:?}", end.reason);
                    };
                    assert_eq!(&info.stop, stop);
                    assert_eq!(
                        info.at
                            .and_then(|at| crate::runtime::report::instr_span(&bytecode, at)),
                        *origin
                    );
                    assert_eq!(&end.release_failures, release_failures);
                }
                RefOutcome::Unsupported(name) => panic!("unexpected unsupported operation: {name}"),
            }
            assert_eq!(
                services.take_output(),
                if stopped.is_none() && cause.is_none() {
                    vec![(Stream::Stdout, b"1\n".to_vec())]
                } else {
                    vec![]
                },
                "{mode:?}: {input} or die{suffix}"
            );
            assert!(services.rt.queue.live.is_empty());
        }
    }
}

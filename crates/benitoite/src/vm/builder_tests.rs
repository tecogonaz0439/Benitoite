//! 専用コアの保持と独立参照評価を実行の境界で比べる（設計書 02-08「参照インタプリタ」）。
// テストの準備の添字と失敗の表現を許す（AGENTS.md「実装の規約」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::ir::core_ir::*;
use crate::ir::desugar::test_support::desugar_files;
use crate::resolve::builders::BuilderOp;
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::{EffectSet, Ty, TyCon, TypeArgs};

fn ty(id: B) -> Ty {
    Ty::Con(
        TyCon::Builtin(id),
        vec![],
        crate::types::builtin::RangeIndex::TOP,
    )
}
fn comp(kind: CompKind, ty: Ty, origin: crate::base::Span) -> Comp {
    Comp {
        kind,
        ty,
        eff: EffectSet::empty(),
        origin,
    }
}
fn val(value: Const, ty: Ty, origin: crate::base::Span) -> CoreVal {
    Val {
        kind: ValKind::Const(value),
        ty,
        origin,
    }
}
fn operation(
    kind: &BuilderKind,
    op: BuilderOp,
    args: Vec<CoreVal>,
    origin: crate::base::Span,
) -> Comp {
    let result = match op {
        BuilderOp::Append | BuilderOp::AppendAll => ty(B::UNIT),
        BuilderOp::Copy => kind.contents(),
        BuilderOp::Length => ty(B::INTEGER),
    };
    comp(
        CompKind::BuilderOp {
            id: BuilderId(0),
            kind: kind.clone(),
            op,
            args,
        },
        result,
        origin,
    )
}
fn sequence(bindings: Vec<(Var, Comp)>, mut body: Comp) -> Comp {
    for (var, bound) in bindings.into_iter().rev() {
        body = Comp {
            ty: body.ty.clone(),
            eff: bound.eff.union(&body.eff),
            origin: body.origin,
            kind: CompKind::Let {
                var,
                bound: Box::new(bound),
                body: Box::new(body),
            },
        };
    }
    body
}
fn handle(c: &Comp) -> Handle<Comp> {
    match &c.kind {
        CompKind::Handle(h) => *h.clone(),
        CompKind::Let { bound, body, .. } => {
            if matches!(bound.kind, CompKind::Handle(_)) {
                handle(bound)
            } else {
                handle(body)
            }
        }
        CompKind::BuilderLet { .. }
        | CompKind::BuilderOp { .. }
        | CompKind::Return(_)
        | CompKind::App { .. }
        | CompKind::Method(_)
        | CompKind::If { .. }
        | CompKind::Match { .. }
        | CompKind::Escape(_)
        | CompKind::Use { .. }
        | CompKind::Lazy { .. }
        | CompKind::Resume { .. } => panic!("handle template missing"),
    }
}

// 関門: 専用コアを直接入力し、脱糖の切替前にも全三種類の命令・専用入力を実行する。
// Host 単体検査では捕まらない（設計書 02-07「命令」）、親/保存枠の同じ根、捕捉の種類、再開と破棄、
// copy の後の追記による退行を、VM と独立ストアと固定した期待値で検出する。
#[test]
fn dedicated_builders_survive_handle_resume_drop_and_nested_bodies() {
    for class in [
        BuilderKind::String,
        BuilderKind::List(ty(B::INTEGER)),
        BuilderKind::Bytes,
    ] {
        for (resume, nested) in [(true, false), (false, false), (true, true), (false, true)] {
            let (contents, old, current, append) = match &class {
                BuilderKind::String => (
                    "String",
                    "\"a\"",
                    if resume { "\"abb\"" } else { "\"ab\"" },
                    Const::Str("a".into()),
                ),
                BuilderKind::List(_) => (
                    "List[Integer]",
                    "[1]",
                    if resume { "[1, 2, 2]" } else { "[1, 2]" },
                    Const::Int(1),
                ),
                BuilderKind::Bytes => (
                    "Bytes",
                    "Bytes.fromList([0x01u8])",
                    if resume {
                        "Bytes.fromList([0x01u8, 0x02u8, 0x02u8])"
                    } else {
                        "Bytes.fromList([0x01u8, 0x02u8])"
                    },
                    Const::Byte(1),
                ),
            };
            let source = format!(
                "import Benitoite.Bytes\neffect Pause\n function pause() -> Unit\nend effect\nfunction template() -> Unit\n return handle pause() with case pause() -> {} end handle\nend function\nfunction observe(old: {contents}, current: {contents}, size: Integer) -> String\n return if old = {old} and current = {current} and size = {} then \"ok\" else \"wrong\" end if\nend function\nfunction fragment() -> Bytes\n return Bytes.fromList([0x02u8])\nend function\nfunction native() -> String\n return \"stub\"\nend function\nfunction main() -> Result[Unit, String]\n return Result.Error(native())\nend function\n",
                if resume { "resume(())" } else { "()" },
                if resume { 4 } else { 3 }
            );
            let (load, _, _, mut core) = desugar_files(&[("builders.bnt", &source)], true);
            let template = core
                .defs
                .remove(core.defs.iter().position(|d| d.name == "template").unwrap());
            let mut h = handle(&template.body);
            let observe = core
                .defs
                .iter()
                .find(|d| d.name == "observe")
                .unwrap()
                .clone();
            let fragment = core
                .defs
                .iter()
                .find(|d| d.name == "fragment")
                .unwrap()
                .clone();
            let native = core.defs.iter_mut().find(|d| d.name == "native").unwrap();
            let origin = native.span;
            let mut next = template.var_count + 1;
            let mut fresh = |t: Ty| {
                let v = Var {
                    id: VarId(next),
                    name: None,
                    ty: t,
                };
                next += 1;
                v
            };
            let read = |v: &Var| Val {
                kind: ValKind::Var(v.id),
                ty: v.ty.clone(),
                origin,
            };
            let unit = || {
                comp(
                    CompKind::Return(val(Const::Unit, ty(B::UNIT), origin)),
                    ty(B::UNIT),
                    origin,
                )
            };
            let elem = match &class {
                BuilderKind::String => ty(B::STRING),
                BuilderKind::Bytes => ty(B::BYTE),
                BuilderKind::List(t) => t.clone(),
            };
            let first = val(append, elem.clone(), origin);
            let second = val(
                match &class {
                    BuilderKind::String => Const::Str("b".into()),
                    BuilderKind::Bytes => Const::Byte(2),
                    BuilderKind::List(_) => Const::Int(2),
                },
                elem.clone(),
                origin,
            );
            let all = match &class {
                BuilderKind::String | BuilderKind::List(_) => comp(
                    CompKind::Return(Val {
                        kind: ValKind::List(vec![second.clone()]),
                        ty: Ty::Con(
                            TyCon::Builtin(B::LIST),
                            vec![elem],
                            crate::types::builtin::RangeIndex::TOP,
                        ),
                        origin,
                    }),
                    Ty::Con(
                        TyCon::Builtin(B::LIST),
                        vec![second.ty.clone()],
                        crate::types::builtin::RangeIndex::TOP,
                    ),
                    origin,
                ),
                BuilderKind::Bytes => comp(
                    CompKind::App {
                        func: Val {
                            kind: ValKind::TopFn {
                                def: fragment.binding,
                                targs: TypeArgs {
                                    tys: vec![],
                                    effects: vec![],
                                },
                            },
                            ty: core.schemes.get(fragment.binding).unwrap().fn_ty(),
                            origin,
                        },
                        dicts: vec![],
                        args: vec![],
                        exit_report: None,
                    },
                    class.contents(),
                    origin,
                ),
            };
            let all_arg = fresh(all.ty.clone());
            let before_pause = fresh(ty(B::UNIT));
            let paused = fresh(ty(B::UNIT));
            let after_pause = fresh(ty(B::UNIT));
            let pause = h.body;
            h.body = sequence(
                vec![
                    (all_arg.clone(), all),
                    (
                        before_pause,
                        operation(&class, BuilderOp::AppendAll, vec![read(&all_arg)], origin),
                    ),
                    (paused, pause),
                    (
                        after_pause,
                        operation(&class, BuilderOp::Append, vec![second], origin),
                    ),
                ],
                unit(),
            );
            if nested {
                let mut outer = h.clone();
                outer.id = BodyId(core.body_count);
                core.body_count += 1;
                for cl in &mut outer.clauses {
                    cl.id = BodyId(core.body_count);
                    core.body_count += 1;
                }
                outer.body = comp(CompKind::Handle(Box::new(h)), ty(B::UNIT), origin);
                h = outer;
            }
            let unused = fresh(ty(B::UNIT));
            let old = fresh(class.contents());
            let handled = fresh(ty(B::UNIT));
            let current = fresh(class.contents());
            let changed = fresh(ty(B::UNIT));
            let size = fresh(ty(B::INTEGER));
            let call = comp(
                CompKind::App {
                    func: Val {
                        kind: ValKind::TopFn {
                            def: observe.binding,
                            targs: TypeArgs {
                                tys: vec![],
                                effects: vec![],
                            },
                        },
                        ty: core.schemes.get(observe.binding).unwrap().fn_ty(),
                        origin,
                    },
                    dicts: vec![],
                    args: vec![read(&old), read(&current), read(&size)],
                    exit_report: None,
                },
                ty(B::STRING),
                origin,
            );
            let body = sequence(
                vec![
                    (
                        unused,
                        operation(&class, BuilderOp::Append, vec![first.clone()], origin),
                    ),
                    (old, operation(&class, BuilderOp::Copy, vec![], origin)),
                    (
                        handled,
                        comp(CompKind::Handle(Box::new(h)), ty(B::UNIT), origin),
                    ),
                    (current, operation(&class, BuilderOp::Copy, vec![], origin)),
                    (
                        changed,
                        operation(&class, BuilderOp::Append, vec![first], origin),
                    ),
                    (size, operation(&class, BuilderOp::Length, vec![], origin)),
                ],
                call,
            );
            native.body = comp(
                CompKind::BuilderLet {
                    id: BuilderId(0),
                    kind: class.clone(),
                    body: Box::new(body),
                },
                ty(B::STRING),
                origin,
            );
            native.var_count = next;
            assert!(
                crate::ir::check::check_program(&core).is_empty(),
                "{:?}",
                crate::ir::check::check_program(&core)
            );
            let program =
                crate::pipeline::compile(&core, std::sync::Arc::new(load.sources)).unwrap();
            crate::bytecode::verify::verify(&program).unwrap();
            for mode in [ExecMode::Direct, ExecMode::Request] {
                let result = super::run(
                    &program,
                    VmConfig {
                        call_budget: 1,
                        ..VmConfig::default()
                    },
                    HeapConfig {
                        stress: true,
                        ..HeapConfig::default()
                    },
                    mode,
                )
                .0;
                assert_eq!(
                    result,
                    VmStep::Finished(MainOutcome::Error("ok".into())),
                    "{class:?}/{resume}/{nested}"
                );
            }
            let mut fixed = crate::builtins::funcs::fixed_io::FixedIo::new(RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            });
            assert_eq!(
                crate::refinterp::run(&core, &mut fixed),
                crate::refinterp::RefOutcome::Finished(MainOutcome::Error("ok".into())),
                "{class:?}/{resume}/{nested}"
            );
        }
    }
}

// 関門: 参照実行器が対象にしないタスク取消でも、待つ子の専用欄を破棄し、
// 呼び出し枠の計数を戻す。ready は Host の生成後にだけ親を進める。
#[test]
fn cancelling_waiting_task_discards_builder_slots_and_stack_cost() {
    let source = r#"
import Benitoite.ListBuilder
import Benitoite.Unofficial.IO.Clock
effect Abort
 function abort() -> Unit
end effect
function waitReady(ready: Reference[Boolean]) -> Unit uses State
 if Reference.get(ready) then return () end if
 return waitReady(ready)
end function
function main() -> Result[Unit, String] uses State, Clock.Time
 bind ready <- Reference.new(false)
 bind _ <- handle
  with group = TaskGroup.open() do
   bind _ <- TaskGroup.spawn(group: group, action: lambda()
    bind b: ListBuilder[String] <- ListBuilder.new()
    ListBuilder.append(builder: b, value: String.repeat(s: "child", n: 8))
    Reference.set(reference: ready, value: true)
    Clock.sleep(3600000)
    return ListBuilder.copy(b)
   end lambda)
   waitReady(ready)
   abort()
  end with
 with case abort() -> () end handle
 return Result.Error("ok")
end function
"#;
    let (load, _, _, core) = desugar_files(&[("builder-cancel.bnt", source)], true);
    assert!(crate::ir::check::check_program(&core).is_empty());
    let program = crate::pipeline::compile(&core, std::sync::Arc::new(load.sources)).unwrap();
    crate::bytecode::verify::verify(&program).unwrap();
    let mut vm = Vm::new(
        &program,
        VmConfig {
            call_budget: 1,
            ..VmConfig::default()
        },
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let mut services = super::io();
    let mut waited = false;
    let outcome = loop {
        match vm.run(services.runtime(ExecMode::Request)) {
            VmStep::Requests(ids) => {
                // この入力の IO は子の sleep だけなので、要求が出た時点で
                // 専用欄を持つ子が実際に待つ経路を通ったと分かる。
                assert!(!ids.is_empty());
                waited = true;
                for id in ids {
                    vm.serve_request(&mut services.rt, id);
                }
            }
            done @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break done,
        }
    };
    assert!(waited);
    assert_eq!(outcome, VmStep::Finished(MainOutcome::Error("ok".into())));
    assert_eq!(vm.state.meter.bytes(), 0);
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    assert!(vm.heap.take_fault().is_none());
}

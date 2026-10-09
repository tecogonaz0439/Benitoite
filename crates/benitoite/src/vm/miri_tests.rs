//! ヒープの内部を VM の代表的な使い方で通す小さなテスト（設計書 07-03、ADR 0318）。
//! 振る舞いの網羅は既存のテストに残し、ここではパイプラインのコンパイルを行わない。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;
use crate::builtins::iface::{
    Capability, IoCtx, IoReply, IoWait, Lend, Lent, OsResource, WorkerWait, builtin,
};
use crate::builtins::table::tags;
use crate::bytecode::asm::ProgramBuilder;
use crate::bytecode::instr::Opcode;
use crate::bytecode::program::{ConstDesc, MainKind};
use crate::runtime::heap::{FieldsKind, HeapConfig, ResourceId, Value};
use crate::runtime::io::resources::{ResourceContent, ResourceState};
use crate::runtime::io::services::RunInput;
use crate::runtime::sched::ExtOpId;
use crate::runtime::sched::testing::{ScheduleEvent, ScheduleHandle};
use crate::runtime::{ResourceKind, Stream};
use crate::vm::dispatch::test_support::{self, TestIo};
use crate::vm::task::{TaskEndWait, TaskObj, WaitReason};

fn io() -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: "/".into(),
        script_directory: "/".into(),
    })
}

fn stress() -> HeapConfig {
    HeapConfig {
        stress: true,
        ..HeapConfig::default()
    }
}

fn request(vm: &mut Vm<'_>, io: &mut TestIo) -> RequestId {
    let VmStep::Requests(ids) = vm.run(io.runtime(ExecMode::Request)) else {
        panic!("expected an IO request");
    };
    assert_eq!(ids.len(), 1);
    ids[0]
}

// 関門: 既存の大きなケースの補助を再利用し、最後の使用の後に本物の安全点で回収する。
#[test]
fn safepoint_clears_dead_registers_and_keeps_live_values() {
    super::tests::check_dead_list_at_safepoints(12);
}

// 関門: 再開と破棄では捕捉した窓の移動先が異なるため、短い二経路を同じ代表にする。
#[test]
fn continuation_capture_resume_and_discard() {
    test_support::check_small_continuations();
}

// 関門: 書き込み後の値と更新枠だけを根にした値の両方を、既存の同じ補助で観察する。
#[test]
fn lazy_result_and_cell_write_survive_collection() {
    test_support::check_lazy_and_cell_writes();
}

// 関門: 子の IO の要求で外側に戻し、待つ親の保存した窓だけにある値を回収に通す。
#[test]
fn waiting_parent_register_is_a_root_during_child_collection() {
    let mut b = ProgramBuilder::new();
    b.program.main_kind = MainKind::Result;
    let main = b.proto("parent", 0, 5).unwrap();
    let child = b.proto("child", 0, 2).unwrap();
    let all = b
        .named_builtin("Task.all", 1, Capability::State, None)
        .unwrap();
    let write = b
        .named_builtin("Benitoite.IO.Console.writeLine", 1, Capability::Io, None)
        .unwrap();
    let error = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.loadk(main, 1, ConstDesc::Func(child)).unwrap();
    b.code(main).unwrap().op(Opcode::List, 2, 1, 1);
    b.code(main)
        .unwrap()
        .op(Opcode::Prim, 3, all.0.try_into().unwrap(), 2);
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 4, error.0.try_into().unwrap(), 0);
    b.code(main).unwrap().ret(4);
    b.loadk(child, 0, ConstDesc::Str("child checkpoint".into()))
        .unwrap();
    b.code(child)
        .unwrap()
        .op(Opcode::Io, 1, write.0.try_into().unwrap(), 0);
    b.code(child).unwrap().ret(1);
    let program = b.finish(main).unwrap();
    let mut vm = Vm::new(&program, VmConfig::default(), stress());
    vm.start_main().unwrap();
    let parent = vm.state.current_task;
    vm.heap.epoch(|ctx| {
        let value = ctx.alloc_str("waiting parent", "Miri task root").unwrap();
        ctx.store(&mut vm.state.segment_mut().unwrap().regs[0], value);
    });
    let mut io = io();
    let script = ScheduleHandle::new([], false);
    io.rt.parts = script.parts();
    let id = request(&mut vm, &mut io);
    assert_eq!(
        vm.state.scheduler.waiting.get(&parent).unwrap().reason,
        WaitReason::TaskEnd(TaskEndWait::Spawned)
    );
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    vm.heap.epoch(|ctx| {
        let task = ctx
            .host::<TaskObj>(vm.state.tasks.get(ctx, parent).unwrap())
            .unwrap();
        assert_eq!(
            ctx.str(ctx.load(&task.stack.segments[0].regs[0])),
            Some("waiting parent")
        );
    });
    vm.serve_request(&mut io.rt, id);
    assert_eq!(
        vm.run(io.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Error("waiting parent".into()))
    );
    assert_eq!(
        io.take_output(),
        [(Stream::Stdout, b"child checkpoint\n".to_vec())]
    );
    assert!(vm.heap.take_fault().is_none());
    assert_eq!(script.record().remaining, 0);
    assert!(script.record().error.is_none());
}

#[derive(Debug)]
struct Resource {
    used: bool,
}

impl OsResource for Resource {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(self: Box<Self>) -> Result<(), String> {
        Ok(())
    }
}

builtin! {
    name = "Benitoite.IO.File.readText",
    io fn small_work(ctx, path: &'c str) -> IoReply<'e> {
        let _ = ctx;
        let lend = if path.starts_with("resource") { Lend::Resource(ResourceId(0)) } else { Lend::Nothing };
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(lend, |lent| {
            match lent {
                Lent::Resource(resource) => {
                    resource.as_any_mut().downcast_mut::<Resource>().unwrap().used = true;
                    1_u8
                }
                Lent::Nothing => 0,
                Lent::Stdin(_) => panic!("unexpected stdin loan"),
            }
        }, complete_work))))
    }
}

fn complete_work<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    completed: u8,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    let text = format!("{}:{completed}", ctx.str(args[0]).unwrap());
    ctx.services().write_output(Stream::Stdout, &text)?;
    let value = ctx.alloc_str(&text, "Miri IO result")?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

// 確認する状態を引数だけ変えて共有し、通常の競合の組み合わせは R26 の受け入れテストに残す。
fn check_worker_wait(lend: bool) {
    let mut b = ProgramBuilder::new();
    b.program.main_kind = MainKind::Result;
    let main = b.proto("worker wait", 0, 4).unwrap();
    let read = b
        .named_builtin("Benitoite.IO.File.readText", 1, Capability::Io, None)
        .unwrap();
    let error = b.ctor("Result", "Error", tags::RESULT_ERROR, 1).unwrap();
    b.code(main).unwrap().op(Opcode::Concat, 2, 0, 1);
    b.code(main)
        .unwrap()
        .op(Opcode::Io, 3, read.0.try_into().unwrap(), 2);
    b.code(main).unwrap().op(Opcode::Field, 0, 3, 0);
    b.code(main)
        .unwrap()
        .op(Opcode::Con, 3, error.0.try_into().unwrap(), 0);
    b.code(main).unwrap().ret(3);
    let program = b.finish(main).unwrap();
    let mut vm = Vm::new(&program, VmConfig::default(), stress());
    vm.start_main().unwrap();
    let task = vm.state.current_task;
    vm.heap.epoch(|ctx| {
        let prefix = ctx
            .alloc_str(if lend { "resource " } else { "pay" }, "Miri IO argument")
            .unwrap();
        let suffix = ctx
            .alloc_str(if lend { "payload" } else { "load" }, "Miri IO argument")
            .unwrap();
        let regs = &mut vm.state.segment_mut().unwrap().regs;
        ctx.store(&mut regs[0], prefix);
        ctx.store(&mut regs[1], suffix);
    });
    if lend {
        assert_eq!(
            vm.state.resources.insert(
                ResourceKind::FileReader,
                ResourceContent::Os(Some(Box::new(Resource { used: false }))),
                None,
            ),
            ResourceId(0)
        );
    }
    let script = ScheduleHandle::new([], false);
    let mut io = io();
    io.rt.parts = script.parts();
    io.rt.builtin_overrides.insert(
        crate::builtins::lookup_builtin("Benitoite.IO.File.readText").unwrap(),
        &small_work::DECL,
    );
    let id = request(&mut vm, &mut io);
    // 外へ渡した後の回収と、Worker へ待ちを移した後の回収の両方を通す（R26、ADR 0314）。
    vm.heap.collect(&vm.state);
    vm.serve_request(&mut io.rt, id);
    assert_eq!(
        vm.state.scheduler.waiting.get(&task).unwrap().reason,
        WaitReason::Worker(ExtOpId(0))
    );
    if lend {
        assert_eq!(
            vm.state.resources.state(ResourceId(0)),
            Some(ResourceState::Lent(ExtOpId(0), false))
        );
        assert!(matches!(
            vm.state.resources.entries[&ResourceId(0)].content,
            ResourceContent::Os(None)
        ));
    }
    vm.heap.collect(&vm.state);
    vm.heap.epoch(|ctx| {
        let task = ctx
            .host::<TaskObj>(vm.state.tasks.get(ctx, task).unwrap())
            .unwrap();
        let regs = &task.stack.segments[0].regs;
        assert_eq!(task.stack.segments[0].calls[0].pc, 1);
        assert!(matches!(ctx.load(&regs[0]), Value::Unit));
        assert!(matches!(ctx.load(&regs[1]), Value::Unit));
        assert_eq!(
            ctx.str(ctx.load(&regs[2])),
            Some(if lend { "resource payload" } else { "payload" })
        );
    });
    script.allow_worker(ExtOpId(0));
    assert_eq!(
        vm.run(io.runtime(ExecMode::Request)),
        VmStep::Finished(MainOutcome::Error(
            if lend {
                "resource payload:1"
            } else {
                "payload:0"
            }
            .into()
        ))
    );
    assert_eq!(
        io.take_output(),
        [(
            Stream::Stdout,
            if lend {
                b"resource payload:1".to_vec()
            } else {
                b"payload:0".to_vec()
            }
        )]
    );
    if lend {
        assert_eq!(
            vm.state.resources.state(ResourceId(0)),
            Some(ResourceState::Open)
        );
        let ResourceContent::Os(Some(resource)) = &mut vm
            .state
            .resources
            .entries
            .get_mut(&ResourceId(0))
            .unwrap()
            .content
        else {
            panic!("resource was not returned");
        };
        assert!(
            resource
                .as_any_mut()
                .downcast_mut::<Resource>()
                .unwrap()
                .used
        );
    }
    assert!(io.rt.ops.records.is_empty());
    vm.heap.collect(&vm.state);
    assert_eq!(vm.heap.verify(&vm.state), Ok(()));
    assert!(vm.heap.take_fault().is_none());
    let record = script.record();
    assert_eq!(record.remaining, 0);
    assert!(record.error.is_none());
    assert!(
        record
            .events
            .contains(&ScheduleEvent::WorkerRan(ExtOpId(0)))
    );
}

// 関門: 貸した実体が表から外れ、実行・完了の取り込みで同じ実体が戻る VM の経路を通す。
#[test]
fn resource_loan_returns_after_worker_completion() {
    check_worker_wait(true);
}

// 関門: 定数に残らない引数を IO の命令位置で保持し、完了の結果をヒープに作って配送する。
#[test]
fn io_completion_reads_saved_arguments_after_collection() {
    check_worker_wait(false);
}

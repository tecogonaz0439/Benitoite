//! タスクの起動・待ち・切り替えの冷たい経路（設計書 02-08「タスクの切り替え」、ADR 0266）。
use super::*;

pub(in crate::vm) mod cancel;
pub(in crate::vm) mod io;
use crate::builtins::iface::{Spawn, SpawnMode, StateWait, TaskEndTarget};
use crate::runtime::io::resources::ResourceState;
use crate::vm::frame::{OtherKind, Segment, TaskStack};
use crate::vm::handler::HandlerRecord;
use crate::vm::state::{SpawnHistory, Switch};
use crate::vm::task::{SpawnWait, TaskEndWait, TaskObj, TaskResult, TaskState, WaitReason};
use crate::vm::{DeadlockWaitKind, DeadlockWaiter, SpawnRecord, TaskId};

fn object<'e>(state: &RunState, ctx: &NoGcCtx<'e>, id: TaskId) -> Result<Value<'e>, Stop> {
    state
        .tasks
        .get(ctx, id)
        .ok_or_else(|| missing("live task missing"))
}
fn empty_task(id: TaskId, budget: u32) -> TaskObj {
    TaskObj {
        id,
        state: TaskState::Ready,
        stack: TaskStack::default(),
        inherited: Vec::new(),
        budget: super::super::budget::Budget::new(budget),
        cancel_requested: false,
        result: TaskResult::Pending,
        awaiters: Vec::new(),
        handle: None,
        spawned: Vec::new(),
        spawn_wait: None,
        spawner: None,
        precall_done: None,
        returning: None,
    }
}
#[cold]
#[inline(never)]
pub(in crate::vm) fn start_main(state: &mut RunState, ctx: &NoGcCtx<'_>) -> Result<(), Stop> {
    state.tasks.check_insert()?;
    let id = state
        .tasks
        .insert(ctx, |id| ctx.alloc_host(empty_task(id, state.call_budget)));
    state.current_task = id;
    state.scheduling.active = true;
    state.scheduling.main = Some(id);
    state.scheduling.spawns.insert(
        id,
        SpawnHistory {
            serial: 0,
            history: Vec::new(),
        },
    );
    Ok(())
}
#[cold]
#[inline(never)]
pub(in crate::vm) fn slow_path_end(state: &mut RunState, initial: u32) -> Result<bool, Stop> {
    if state.budget.finish_slow(initial) == SlowPathEnd::Switch {
        // 回収だけで戻るときは仮想時間を進めない。時間の境界は待ちと予算の
        // 終わりに限る（10-10「テストで差し替える部品」）。
        state.scheduling.switch = Some(Switch::Yield);
        Ok(true)
    } else {
        Ok(false)
    }
}

#[cold]
#[inline(never)]
pub(super) fn park(state: &mut RunState, reason: WaitReason) -> Result<Control, Stop> {
    state.scheduler.check_park(state.current_task)?;
    state.scheduler.park(state.current_task, reason);
    state.scheduling.switch = Some(Switch::Park);
    Ok(Control::Return)
}

// 全欄を同じ区間の中で移す。TaskObj の空の欄と RunState の欄が二重の根にならない
// （実装プラン R25「タスクの対象と実行中のタスク」）。
fn save(state: &mut RunState, ctx: &mut NoGcCtx<'_>, switch: Switch) -> Result<(), Stop> {
    state.scheduling.active = false;
    if matches!(switch, Switch::Done) {
        return Ok(());
    }
    let value = object(state, ctx, state.current_task)?;
    let reason = state
        .scheduler
        .waiting
        .get(&state.current_task)
        .map(|w| w.reason);
    ctx.host_mut::<TaskObj, _>(value, |task, _| {
        task.stack = std::mem::take(&mut state.stack);
        task.inherited = std::mem::take(&mut state.inherited);
        task.returning = state.returning.take();
        task.precall_done = state.precall_done.take();
        task.budget = state.budget;
        task.state = if let Some(work) = state.unwinding.take() {
            TaskState::Unwinding(work)
        } else if let Some(reason) = reason {
            TaskState::Waiting(reason)
        } else {
            TaskState::Ready
        };
    })
    .ok_or_else(|| missing("task object missing"))?;
    if matches!(switch, Switch::Yield) {
        state.scheduler.ready.push_back(state.current_task);
    }
    Ok(())
}
fn restore(state: &mut RunState, ctx: &mut NoGcCtx<'_>, id: TaskId) -> Result<(), Stop> {
    let value = object(state, ctx, id)?;
    ctx.host_mut::<TaskObj, _>(value, |task, _| {
        state.stack = std::mem::take(&mut task.stack);
        state.inherited = std::mem::take(&mut task.inherited);
        state.returning = task.returning.take();
        state.precall_done = task.precall_done.take();
        state.budget = task.budget;
        state.unwinding = match std::mem::replace(&mut task.state, TaskState::Ready) {
            TaskState::Unwinding(mut work) => {
                work.waiting = None;
                Some(work)
            }
            TaskState::Ready | TaskState::Waiting(_) | TaskState::Done => None,
        };
    })
    .ok_or_else(|| missing("task object missing"))?;
    state.current_task = id;
    state.scheduling.active = true;
    if ctx.collect_requested() {
        state.budget.interrupt();
    }
    cancel::begin(state, ctx)?;
    Ok(())
}

// 待ちと予算の終わりを同じ順序で処理する（実装プラン 10-10）。
#[cold]
#[inline(never)]
fn boundary(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    at: crate::runtime::io::WaitPoint,
) -> Result<(), Stop> {
    io::boundary(program, state, ctx, rt, at)?;
    let now = rt.parts.clock.monotonic_millis();
    for (timer, task) in state.scheduler.expire_timers(now) {
        if !cancel::expire(state, ctx, task, timer)? {
            if let Some((owner, site)) = rt.sleeps.remove(&timer) {
                rt.sleep_timers.remove(&owner);
                if owner != task {
                    return Err(missing("sleep timer owner mismatch"));
                }
                io::write_result(program, state, ctx, task, site, Value::Unit)?;
            }
            io::expire_retry(program, state, ctx, rt, timer)?;
            state.scheduler.wake_if(task, WaitReason::Timer(timer));
        }
    }
    Ok(())
}
#[cold]
#[inline(never)]
pub(super) fn switch(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
) -> Result<(), Stop> {
    match switch_inner(program, state, ctx, rt) {
        Err(stop) if state.scheduling.stopping => {
            stop_without_progress(state, ctx, stop);
            Ok(())
        }
        result => result,
    }
}
#[cold]
#[inline(never)]
fn switch_inner(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
) -> Result<(), Stop> {
    let switch = state.scheduling.switch.take();
    if let Some(switch) = switch {
        if matches!(switch, Switch::Yield) {
            // ほかのタスクが計算を続けても短い出力を届ける。空の転送はポートが省く
            // （設計書 02-09「出力のバッファ」、ADR 0320）。
            rt.stdout.request_transfer();
            rt.stderr.request_transfer();
        }
        save(state, ctx, switch)?;
        state.scheduling.boundary_at = Some(if matches!(switch, Switch::Yield) {
            crate::runtime::io::WaitPoint::SlowPath
        } else {
            crate::runtime::io::WaitPoint::Park
        });
        if ctx.collect_requested() {
            return Ok(());
        }
    }
    let at = state
        .scheduling
        .boundary_at
        .take()
        .unwrap_or(crate::runtime::io::WaitPoint::Park);
    loop {
        boundary(program, state, ctx, rt, at)?;
        if matches!(state.step, Some(VmStep::Requests(_))) {
            return Ok(());
        }
        #[cfg(test)]
        if let Some(mut hook) = state.scheduling.test_boundary.take() {
            let result = hook(state, ctx);
            state.scheduling.test_boundary = Some(hook);
            result?;
        }
        let next = if state.stopping.is_some() {
            state
                .scheduler
                .next(&mut crate::runtime::sched::parts::FifoPicker)
        } else {
            state.scheduler.next(&mut *rt.parts.picker)
        };
        if let Some(next) = next {
            return restore(state, ctx, next);
        }
        if !state.scheduler.ready.is_empty() {
            return Err(missing("task picker refused ready tasks"));
        }
        if state.tasks.live_count() == 0 {
            if let Some(reason) = state.stopping.take() {
                state.roots.truncate(ctx, 0);
                state.step = Some(VmStep::Stopped(StopEnd {
                    reason,
                    release_failures: std::mem::take(&mut state.scheduling.failures),
                }));
            } else {
                state.step = state.scheduling.outcome.take().map(VmStep::Finished);
            }
            return Ok(());
        }
        rt.stdout.request_transfer();
        rt.stderr.request_transfer();
        if state.scheduler.is_deadlocked() {
            if state.scheduling.stopping {
                return Err(missing("scheduler deadlocked while stopping"));
            }
            if state.stopping.is_none() {
                state.stopping = Some(StopReason::Error(deadlock(state, ctx)?));
            }
            begin_stop_all(state, ctx)?;
            continue;
        }
        // attach より前の要求はシグナルの通知を持たないため、待つ前にも印を読む
        // （設計書 02-08「タスクの切り替え」の「この待ちでも中断の印を調べる」）。
        if state.stopping.is_none() && rt.interrupt.requested() {
            state.stopping = Some(StopReason::Interrupted);
            begin_stop_all(state, ctx)?;
            continue;
        }
        match rt.parts.workers.idle(state.scheduler.next_deadline()) {
            crate::runtime::sched::parts::IdleWake::Progress => {}
            crate::runtime::sched::parts::IdleWake::Interrupted => {
                if state.stopping.is_none() && rt.interrupt.requested() {
                    state.stopping = Some(StopReason::Interrupted);
                    begin_stop_all(state, ctx)?;
                }
            }
            crate::runtime::sched::parts::IdleWake::ScriptExhausted => {
                return Err(missing("scheduler script exhausted while waiting"));
            }
        }
    }
}

// 既に全体を止めているときは、同じ失敗で停止を始め直しても進まない。
// 残った所有と計数を手放し、最初の理由と既に集めた解放の失敗を保って終える
// （実装プラン R25「cleanup の抜ける条件」、02-08「止める手順」）。
#[cold]
#[inline(never)]
pub(super) fn stop_without_progress(state: &mut RunState, ctx: &mut NoGcCtx<'_>, stop: Stop) {
    let reason = state
        .stopping
        .take()
        .unwrap_or_else(|| StopReason::Error(state.stop_info(stop.clone(), None)));
    state.scheduling.stop_error = Some(stop);
    let stack = std::mem::take(&mut state.stack);
    discard_stopped_stack(state, ctx, stack);
    if let Some(mut work) = state.unwinding.take() {
        state.scheduling.failures.append(&mut work.log.failures);
        for (segment, _) in &work.segments {
            state
                .meter
                .shrink(segment.frame_count(), segment.reg_count());
        }
        for (segment, _) in work.segments {
            ctx.discard(segment);
        }
    }
    ctx.discard(state.returning.take());
    ctx.discard(std::mem::take(&mut state.inherited));
    // 添字や古い id に頼らず、まだ所有する表の対象を一つずつ手放す。
    for entry in &mut state.tasks.entries {
        if let Some(slot) = entry.task.take() {
            let value = ctx.load(&slot);
            ctx.host_mut::<TaskObj, _>(value, |task, slots| {
                let mut old = std::mem::replace(task, empty_task(task.id, 0));
                task.state = TaskState::Done;
                task.result = TaskResult::Cancelled;
                for segment in &old.stack.segments {
                    state
                        .meter
                        .shrink(segment.frame_count(), segment.reg_count());
                }
                if let TaskState::Unwinding(work) = &mut old.state {
                    state.scheduling.failures.append(&mut work.log.failures);
                    for (segment, _) in &work.segments {
                        state
                            .meter
                            .shrink(segment.frame_count(), segment.reg_count());
                    }
                }
                slots.discard(old.stack);
                slots.discard(old.inherited);
                slots.discard(old.handle);
                slots.discard(old.returning);
                if let Some(wait) = old.spawn_wait {
                    slots.discard(wait.children);
                }
                if let TaskResult::Value(result) = old.result {
                    slots.discard(result);
                }
                if let TaskState::Unwinding(work) = old.state {
                    for (segment, _) in work.segments {
                        slots.discard(segment);
                    }
                }
            });
            ctx.discard(slot);
        }
    }
    state.scheduler.ready.clear();
    state.scheduler.clear_waiting();
    state.scheduler.clear_timers();
    state.scheduling.timed_out.clear();
    state.scheduling.active = false;
    state.scheduling.switch = None;
    state.precall_done = None;
    state.roots.truncate(ctx, 0);
    state.step = Some(VmStep::Stopped(StopEnd {
        reason,
        release_failures: std::mem::take(&mut state.scheduling.failures),
    }));
}

fn discard_stopped_stack(state: &mut RunState, ctx: &NoGcCtx<'_>, stack: TaskStack) {
    for segment in &stack.segments {
        state
            .meter
            .shrink(segment.frame_count(), segment.reg_count());
    }
    ctx.discard(stack);
}

#[cold]
#[inline(never)]
pub(super) fn dispatch(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    cursor: &Cursor<'_>,
    instr: Instr,
    rt: &mut IoRuntime,
) -> Result<Control, Stop> {
    let reference = program
        .builtin(BuiltinRefIdx(u32::from(instr.b())))
        .ok_or_else(|| missing("state builtin missing"))?;
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    let args = read_range(
        ctx,
        active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
        &reg_range(instr.c(), reference.arity)?,
    )?;
    let decl =
        builtin_decl(reference.id).ok_or_else(|| missing("state builtin declaration missing"))?;
    let reply = {
        let mut services = super::super::state::Stage1StateServices {
            resources: &mut state.resources,
            scheduler: &mut state.scheduler,
        };
        let mut call = CallCtx::new(ctx, None, Some(&mut services), Some(at));
        (decl.raw)(&mut call, &args)?
    };
    match reply {
        Reply::Done(value) => {
            write(
                ctx,
                active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
                instr.a(),
                value,
            )?;
            Ok(after_alloc(state, ctx))
        }
        Reply::Wait(WaitRequest::State(wait)) => {
            let reason = match wait {
                StateWait::TaskEnd(TaskEndTarget::Await(id)) => {
                    let value = object(state, ctx, id)?;
                    ctx.host_mut::<TaskObj, _>(value, |task, _| {
                        task.awaiters.push(state.current_task)
                    })
                    .ok_or_else(|| missing("awaited task missing"))?;
                    WaitReason::TaskEnd(TaskEndWait::Await(id))
                }
                StateWait::TaskEnd(TaskEndTarget::TaskGroupRelease(id)) => {
                    WaitReason::TaskEnd(TaskEndWait::TaskGroupRelease(id))
                }
                StateWait::Resource(id) => WaitReason::Release(id),
            };
            cursor.locals.save(state.frame_mut()?);
            park(state, reason)
        }
        Reply::SpawnTasks(spawn) => spawn_tasks(program, state, ctx, cursor, instr, spawn, rt),
        Reply::Wait(WaitRequest::Io(_)) | Reply::Exit(_) => {
            Err(missing("invalid state builtin reply"))
        }
    }
}

#[cold]
#[inline(never)]
fn spawn_tasks<'e>(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    cursor: &Cursor<'_>,
    instr: Instr,
    spawn: Spawn<'e>,
    rt: &mut IoRuntime,
) -> Result<Control, Stop> {
    let group = if let SpawnMode::GroupSpawn { group } = spawn.mode {
        state.resources.check_release(group)?;
        let kind = state
            .resources
            .kind(group)
            .ok_or_else(|| missing("task group missing"))?;
        if kind != crate::runtime::ResourceKind::TaskGroup {
            return Err(missing("spawn requires a task group"));
        }
        if state.resources.state(group) != Some(ResourceState::Open) {
            return Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind }));
        }
        if spawn.funcs.len() != 1 {
            return Err(missing("group spawn requires one function"));
        }
        Some(group)
    } else {
        if matches!(spawn.mode, SpawnMode::WithTimeout { .. }) && spawn.funcs.len() != 1 {
            return Err(missing("timeout requires one child"));
        }
        None
    };
    let parent = object(state, ctx, state.current_task)?;
    let mut inherited: Vec<_> = state
        .stack
        .segments
        .iter()
        .rev()
        .flat_map(|s| s.others.iter().rev())
        .filter_map(|o| match &o.kind {
            OtherKind::Handle(frame) => Some(ctx.load(&frame.record)),
            OtherKind::Release { .. }
            | OtherKind::Update { .. }
            | OtherKind::CellUpdate(_)
            | OtherKind::Drop { .. } => None,
        })
        .collect();
    let handle = inherited.first().copied().or_else(|| {
        ctx.host::<TaskObj>(parent)
            .and_then(|t| t.handle.as_ref().map(|s| ctx.load(s)))
    });
    inherited.extend(state.inherited.iter().map(|s| ctx.load(s)));
    let at = InstrRef {
        proto: cursor.locals.proto,
        pc: cursor.locals.pc,
    };
    let mut children = Vec::new();
    for func in spawn.funcs {
        let proto_id = ProtoIdx(require_func(ctx, func)?);
        let proto = program
            .proto(proto_id)
            .ok_or_else(|| missing("spawn prototype missing"))?;
        if proto.num_params != 0 {
            return Err(missing("spawned function requires arguments"));
        }
        let size = u32::from(proto.num_regs);
        if !state.meter.fits(1, u64::from(size)) {
            return Err(Stop::Resource(ResourceError::CallStackTooDeep {
                frames: state.meter.frames(),
            }));
        }
        state.tasks.check_insert()?;
        let mut task_value = Value::Unit;
        let id = state.tasks.insert(ctx, |id| {
            let mut task = empty_task(id, state.call_budget);
            let mut segment = Segment::default();
            segment
                .regs
                .resize_with(usize::from(proto.num_regs), Slot::default);
            segment.calls.push(CallFrame {
                func: ctx.new_slot(func),
                proto: proto_id,
                pc: 0,
                base: 0,
                size,
                ret: None,
                call_site: Some(at),
                boundary: proto.boundary,
                chain_resume: None,
            });
            task.stack.segments.push(segment);
            task.inherited = inherited.iter().map(|&v| ctx.new_slot(v)).collect();
            task.handle = handle.map(|v| ctx.new_slot(v));
            task.spawner = Some((state.current_task, at));
            task_value = ctx.alloc_host(task);
            task_value
        });
        state.meter.grow(1, u64::from(size));
        state.scheduling.serial = state
            .scheduling
            .serial
            .checked_add(1)
            .ok_or_else(|| missing("spawn serial overflow"))?;
        let mut history = vec![SpawnRecord {
            spawned_at: at,
            spawner_frames: state
                .stop_info(Stop::Internal(String::new()), Some(at))
                .frames,
        }];
        if let Some(previous) = state.scheduling.spawns.get(&state.current_task) {
            history.extend(previous.history.clone());
        }
        state.scheduling.spawns.insert(
            id,
            SpawnHistory {
                serial: state.scheduling.serial,
                history,
            },
        );
        rt.parts.picker.spawned(state.scheduling.serial, id);
        if let Some(handle) = handle {
            let position = ctx
                .host_mut::<HandlerRecord, _>(handle, |record, _| {
                    let position = record.members.len();
                    record.members.push(id);
                    position
                })
                .ok_or_else(|| missing("spawn handler missing"))?;
            state.scheduling.member_positions.insert(id, position);
        }
        let position = ctx
            .host_mut::<TaskObj, _>(parent, |t, _| {
                let position = t.spawned.len();
                t.spawned.push(id);
                position
            })
            .ok_or_else(|| missing("spawner missing"))?;
        state.scheduling.child_positions.insert(id, position);
        if let Some(group) = group {
            state.resources.add_group_task(group, id)?;
        }
        state.scheduler.ready.push_back(id);
        children.push(task_value);
    }
    if group.is_some() {
        let child = children
            .first()
            .copied()
            .ok_or_else(|| missing("group spawn result missing"))?;
        write(
            ctx,
            active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
            instr.a(),
            child,
        )?;
        return Ok(after_alloc(state, ctx));
    }
    if children.is_empty() {
        write(
            ctx,
            active_window(state.segment_mut()?, cursor.locals.base, cursor.active.size)?,
            instr.a(),
            match spawn.mode {
                SpawnMode::All => Value::EmptyList,
                SpawnMode::AllOk => {
                    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::EmptyList])?
                }
                SpawnMode::Race => Value::Tag(CtorTag(tags::OPTION_NONE)),
                SpawnMode::WithTimeout { .. } | SpawnMode::GroupSpawn { .. } => {
                    return Err(missing("spawn requires a child"));
                }
            },
        )?;
        return Ok(if spawn.mode == SpawnMode::AllOk {
            after_alloc(state, ctx)
        } else {
            Control::Next
        });
    }
    let timer = if let SpawnMode::WithTimeout { millis } = spawn.mode {
        let deadline = rt
            .parts
            .clock
            .monotonic_millis()
            .checked_add(millis)
            .ok_or_else(|| missing("timer deadline overflow"))?;
        let timer = state.scheduler.new_timer_id();
        state
            .scheduler
            .add_timer(deadline, timer, state.current_task);
        Some(timer)
    } else {
        None
    };
    ctx.host_mut::<TaskObj, _>(parent, |t, slots| {
        t.spawn_wait = Some(SpawnWait {
            mode: spawn.mode,
            children: children.iter().map(|&v| slots.new_slot(v)).collect(),
            timer,
        })
    })
    .ok_or_else(|| missing("spawner missing"))?;
    state
        .scheduling
        .deliveries
        .insert(state.current_task, instr.a());
    cursor.locals.save(state.frame_mut()?);
    notify_collect(state, ctx);
    park(state, WaitReason::TaskEnd(TaskEndWait::Spawned))
}

#[cold]
#[inline(never)]
pub(super) fn finish<'e>(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    value: Value<'e>,
) -> Result<Control, Stop> {
    if state.scheduling.main == Some(state.current_task) {
        // テストの関数は `start_test` が置いた型で読む（実装プラン 10-18「テストの関数の実行」）。
        let kind = state.main_kind.unwrap_or(program.main_kind);
        state.scheduling.outcome = Some(main_outcome(kind, ctx, value)?);
    }
    finish_task(state, ctx, Some(value))?;
    Ok(Control::Return)
}
#[cold]
#[inline(never)]
fn finish_task<'e>(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    result: Option<Value<'e>>,
) -> Result<(), Stop> {
    let id = state.current_task;
    let value = object(state, ctx, id)?;
    let (awaiters, handle, spawner) = ctx
        .host_mut::<TaskObj, _>(value, |t, slots| {
            if let TaskResult::Value(old) = std::mem::replace(&mut t.result, TaskResult::Pending) {
                slots.discard(old);
            }
            t.result = result.map_or(TaskResult::Cancelled, |v| {
                TaskResult::Value(slots.new_slot(v))
            });
            t.state = TaskState::Done;
            slots.discard(std::mem::take(&mut t.stack));
            slots.discard(std::mem::take(&mut t.inherited));
            let handle = t.handle.take();
            let awaiters = std::mem::take(&mut t.awaiters);
            if let Some(wait) = t.spawn_wait.take() {
                slots.discard(wait.children);
            }
            for child in t.spawned.drain(..) {
                state.scheduling.child_positions.remove(&child);
            }
            t.precall_done = None;
            if let Some(work) = t.returning.take() {
                slots.discard(work);
            }
            (awaiters, handle, t.spawner.take())
        })
        .ok_or_else(|| missing("finishing task missing"))?;
    for waiter in awaiters {
        state
            .scheduler
            .wake_if(waiter, WaitReason::TaskEnd(TaskEndWait::Await(id)));
    }
    if let Some(handle) = handle {
        let record = ctx.load(&handle);
        let wake = ctx
            .host_mut::<HandlerRecord, _>(record, |r, _| {
                remove_member(&mut r.members, &mut state.scheduling.member_positions, id)?;
                Ok((r.body_finished && r.members.is_empty()).then_some(r.evaluated_by))
            })
            .ok_or_else(|| missing("task handler missing"))??;
        if let Some(task) = wake {
            state
                .scheduler
                .wake_if(task, WaitReason::TaskEnd(TaskEndWait::HandleEnd));
        }
        ctx.discard(handle);
    }
    if let Some(group) = state.resources.finish_group_task(id)? {
        state
            .scheduler
            .wake_all(WaitReason::TaskEnd(TaskEndWait::TaskGroupRelease(group)));
    }
    if let Some((parent, _)) = spawner {
        if let Some(parent_value) = state.tasks.get(ctx, parent) {
            // 結果の所有は SpawnWait::children が続ける。取り消す候補の番号には
            // 終わっていない子だけを残す（10-09「タスクの対象」、R39）。
            ctx.host_mut::<TaskObj, _>(parent_value, |task, _| {
                remove_member(&mut task.spawned, &mut state.scheduling.child_positions, id)
            })
            .ok_or_else(|| missing("spawner object missing"))??;
        }
        deliver_all(state, ctx, parent)?;
    }
    ctx.discard(std::mem::take(&mut state.stack));
    ctx.discard(std::mem::take(&mut state.inherited));
    state.precall_done = None;
    // 実行中の番号は選択時に ready から外れている。終了時に列全体を探す必要はない。
    state.scheduler.remove_waiting(id);
    state.scheduler.remove_task_timers(id);
    state.scheduling.timed_out.remove(&id);
    state.resources.remove_waiter(id);
    state.tasks.check_remove(id)?;
    state.tasks.remove(ctx, id);
    state.scheduling.spawns.remove(&id);
    state.scheduling.switch = Some(Switch::Done);
    Ok(())
}
// members と spawned は所属と取り消しの集合であり、結果の順序は SpawnWait が持つ。
// 位置を引いて末尾と入れ替えることで、終了ごとに生きている兄弟を走査しない（SECB6）。
fn remove_member(
    members: &mut Vec<TaskId>,
    positions: &mut std::collections::BTreeMap<TaskId, usize>,
    id: TaskId,
) -> Result<(), Stop> {
    let position = positions
        .remove(&id)
        .ok_or_else(|| missing("task membership index missing"))?;
    if members.get(position) != Some(&id) {
        return Err(missing("task membership index mismatch"));
    }
    members.swap_remove(position);
    if let Some(&moved) = members.get(position) {
        positions.insert(moved, position);
    }
    Ok(())
}

fn deliver_all(state: &mut RunState, ctx: &mut NoGcCtx<'_>, parent: TaskId) -> Result<(), Stop> {
    let Some(parent_value) = state.tasks.get(ctx, parent) else {
        return Ok(());
    };
    let task = ctx
        .host::<TaskObj>(parent_value)
        .ok_or_else(|| missing("spawner object missing"))?;
    let Some(wait) = &task.spawn_wait else {
        return Ok(());
    };
    // 全体停止では配送先を既に外している。SpawnWait は親自身の停止の完了で
    // 手放し、子の完了では結果を判断も配送もしない（設計書 02-08「止める手順」）。
    if state.scheduling.stopping {
        return Ok(());
    }
    if task.cancel_requested {
        return cancel::discard_cancelled_parent(state, ctx, parent);
    }
    if wait.mode != SpawnMode::All {
        return cancel::deliver(state, ctx, parent);
    }
    let mut results = Vec::new();
    for child in &wait.children {
        let task = ctx
            .host::<TaskObj>(ctx.load(child))
            .ok_or_else(|| missing("spawn child missing"))?;
        match &task.result {
            TaskResult::Pending => return Ok(()),
            TaskResult::Value(slot) => results.push(ctx.load(slot)),
            TaskResult::Cancelled => return Ok(()),
        }
    }
    let result = list::from_values(ctx, &results, "Task.all")?;
    let dest = state
        .scheduling
        .deliveries
        .remove(&parent)
        .ok_or_else(|| missing("spawn destination missing"))?;
    ctx.host_mut::<TaskObj, _>(parent_value, |task, slots| -> Result<(), Stop> {
        let segment = task
            .stack
            .segments
            .last_mut()
            .ok_or_else(|| missing("spawner segment missing"))?;
        let frame = segment
            .calls
            .last_mut()
            .ok_or_else(|| missing("spawner frame missing"))?;
        // 結果の書き込みと pc の更新を回収なしで行う（実装プラン R25「回収の前の整理」）。
        let reg = frame
            .base
            .checked_add(u32::from(dest))
            .ok_or_else(|| missing("spawn result overflow"))?;
        slots.store(
            segment
                .regs
                .get_mut(index(reg)?)
                .ok_or_else(|| missing("spawn result register missing"))?,
            result,
        );
        frame.pc = frame
            .pc
            .checked_add(1)
            .ok_or_else(|| missing("spawn pc overflow"))?;
        let wait = task
            .spawn_wait
            .take()
            .ok_or_else(|| missing("spawn wait missing"))?;
        slots.discard(wait.children);
        Ok(())
    })
    .ok_or_else(|| missing("spawner object missing"))??;
    notify_collect(state, ctx);
    state
        .scheduler
        .wake_if(parent, WaitReason::TaskEnd(TaskEndWait::Spawned));
    Ok(())
}

fn deadlock(state: &RunState, ctx: &NoGcCtx<'_>) -> Result<super::super::StopInfo, Stop> {
    let mut waiters = Vec::new();
    for (&id, waiting) in &state.scheduler.waiting {
        let value = object(state, ctx, id)?;
        let task = ctx
            .host::<TaskObj>(value)
            .ok_or_else(|| missing("deadlocked task missing"))?;
        let segments: Vec<_> = match &task.state {
            TaskState::Unwinding(work) => work
                .segments
                .iter()
                .rev()
                .map(|(s, _)| s)
                .chain(task.stack.segments.iter().rev())
                .collect(),
            TaskState::Ready | TaskState::Waiting(_) | TaskState::Done => {
                task.stack.segments.iter().rev().collect()
            }
        };
        let frames: Vec<_> = segments.iter().flat_map(|s| s.calls.iter().rev()).collect();
        let mut at = frames
            .first()
            .map(|f| InstrRef {
                proto: f.proto,
                pc: f.pc,
            })
            .or_else(|| task.returning.as_ref().map(|w| w.at));
        let kind = match waiting.reason {
            WaitReason::TaskEnd(TaskEndWait::Await(_)) => DeadlockWaitKind::Builtin("Task.await"),
            WaitReason::TaskEnd(TaskEndWait::Spawned) => DeadlockWaitKind::Builtin(
                match task
                    .spawn_wait
                    .as_ref()
                    .ok_or_else(|| missing("spawn wait missing"))?
                    .mode
                {
                    SpawnMode::All => "Task.all",
                    SpawnMode::AllOk => "Task.allOk",
                    SpawnMode::Race => "Task.race",
                    SpawnMode::WithTimeout { .. } => "Task.withTimeout",
                    SpawnMode::GroupSpawn { .. } => {
                        return Err(missing("group spawn cannot wait for children"));
                    }
                },
            ),
            WaitReason::Lazy => DeadlockWaitKind::Lazy,
            WaitReason::TaskEnd(TaskEndWait::HandleEnd) => {
                if let Some(site) = segments
                    .iter()
                    .flat_map(|s| s.others.iter().rev())
                    .find_map(|o| {
                        if let OtherKind::Handle(frame) = &o.kind {
                            Some(frame.at)
                        } else {
                            None
                        }
                    })
                {
                    at = Some(site);
                }
                DeadlockWaitKind::HandleEnd
            }
            WaitReason::TaskEnd(TaskEndWait::TaskGroupRelease(_)) => {
                if let Some(site) = segments
                    .iter()
                    .flat_map(|s| s.others.iter().rev())
                    .find_map(|o| {
                        if let OtherKind::Release { at, .. } = o.kind {
                            Some(at)
                        } else {
                            None
                        }
                    })
                {
                    at = Some(site);
                }
                DeadlockWaitKind::TaskGroupRelease
            }
            WaitReason::Worker(_)
            | WaitReason::Timer(_)
            | WaitReason::Readiness(_)
            | WaitReason::Output(..)
            | WaitReason::Lend(_)
            | WaitReason::Release(_)
            | WaitReason::Response => return Err(missing("external wait classified as deadlock")),
        };
        let at = at.ok_or_else(|| missing("deadlock location missing"))?;
        let spawn = state
            .scheduling
            .spawns
            .get(&id)
            .ok_or_else(|| missing("spawn history missing"))?;
        waiters.push((
            spawn.serial,
            DeadlockWaiter {
                kind,
                at,
                call_sites: frames.iter().map(|f| f.call_site).collect(),
                spawns: spawn.history.clone(),
            },
        ));
    }
    waiters.sort_by_key(|(serial, _)| *serial);
    Ok(super::super::StopInfo {
        stop: Stop::Runtime(RuntimeError::TaskDeadlock),
        at: None,
        frames: Vec::new(),
        spawns: Vec::new(),
        deadlock: waiters.into_iter().map(|(_, w)| w).collect(),
    })
}

#[cold]
#[inline(never)]
pub(super) fn begin_stop_all(state: &mut RunState, ctx: &mut NoGcCtx<'_>) -> Result<(), Stop> {
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindWork};
    if state.scheduling.stopping {
        return Ok(());
    }
    state.scheduling.stopping = true;
    state.scheduling.expire_io = true;
    state.scheduling.deliveries.clear();
    state.scheduling.timed_out.clear();
    let ids: Vec<_> = state
        .tasks
        .entries
        .iter()
        .filter_map(|e| {
            e.task
                .as_ref()
                .and_then(|s| ctx.host::<TaskObj>(ctx.load(s)).map(|t| t.id))
        })
        .collect();
    for id in ids {
        if id == state.current_task && state.scheduling.active {
            state.precall_done = None;
            if let Some(work) = state.returning.take() {
                ctx.discard(work);
            }
            let rest = std::mem::take(&mut state.stack);
            if let Some(work) = &mut state.unwinding {
                work.escalate(rest, UnwindCause::Stop);
                if let Some(WaitReason::Release(resource)) = work.waiting
                    && crate::runtime::io::http::stop_exchange(&mut state.resources, resource)
                {
                    work.waiting = None;
                }
            } else {
                state.unwinding = Some(UnwindWork {
                    cause: UnwindCause::Stop,
                    segments: rest
                        .segments
                        .into_iter()
                        .map(|s| (s, UnwindCause::Stop))
                        .collect(),
                    waiting: None,
                    log: ReleaseLog::default(),
                });
            }
            continue;
        }
        let value = object(state, ctx, id)?;
        let mut reason = state.scheduler.waiting.get(&id).map(|w| w.reason);
        // 通常の解放を待っていた Exchange も、停止では待ちを外す。
        // ほかのリソースの解放は完了を待つ（設計書 02-09「リソースの追跡」）。
        let closed_exchange = if let Some(WaitReason::Release(resource)) = reason {
            crate::runtime::io::http::stop_exchange(&mut state.resources, resource)
        } else {
            false
        };
        if closed_exchange {
            reason = None;
        }
        ctx.host_mut::<TaskObj, _>(value, |t, slots| {
            t.precall_done = None;
            if let Some(work) = t.returning.take() {
                slots.discard(work);
            }
            let rest = std::mem::take(&mut t.stack);
            let old = std::mem::replace(&mut t.state, TaskState::Ready);
            let work = if let TaskState::Unwinding(mut work) = old {
                work.escalate(rest, UnwindCause::Stop);
                if closed_exchange {
                    work.waiting = None;
                }
                work
            } else {
                UnwindWork {
                    cause: UnwindCause::Stop,
                    segments: rest
                        .segments
                        .into_iter()
                        .map(|s| (s, UnwindCause::Stop))
                        .collect(),
                    waiting: reason.filter(|r| matches!(r, WaitReason::Release(_))),
                    log: ReleaseLog::default(),
                }
            };
            t.state = TaskState::Unwinding(work);
        })
        .ok_or_else(|| missing("stopping task missing"))?;
        if !matches!(reason, Some(WaitReason::Release(_))) {
            state.scheduler.wake(id);
            state.resources.remove_waiter(id);
        }
    }
    Ok(())
}
#[cold]
#[inline(never)]
pub(super) fn finish_stop(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    failures: Vec<crate::runtime::ReleaseFailure>,
) -> Result<Control, Stop> {
    if state.scheduling.main.is_none() {
        state.roots.truncate(ctx, 0);
        if let Some(reason) = state.stopping.take() {
            state.step = Some(VmStep::Stopped(StopEnd {
                reason,
                release_failures: failures,
            }));
        }
        return Ok(Control::Return);
    }
    state.scheduling.failures.extend(failures);
    finish_task(state, ctx, None)?;
    Ok(Control::Return)
}

#[cfg(test)]
mod tests;

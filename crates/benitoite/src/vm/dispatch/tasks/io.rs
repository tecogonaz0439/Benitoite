//! IO の要求と完了を、待ちと予算の終わりの冷たい境界で処理する（設計書 02-09「IO 実行器」）。
use super::*;
use crate::builtins::iface::{IoWait, Lend, OutputWaitKind, WorkerWait};
use crate::runtime::Stream;
use crate::runtime::io::ops::{
    self, Accepted, Completion, JobWork, LentOwned, OpKind, OpRecord, Outcome, WorkerJob,
};
use crate::runtime::io::output::WriteFailure;
use crate::runtime::io::resources::{LendResult, ReleaseStart};
use crate::runtime::io::services::IoView;
use crate::runtime::io::{DispatchAction, Request, RequestPhase, STDIN_LEND, WaitPoint};

#[cold]
#[inline(never)]
pub(in crate::vm::dispatch) fn publish(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    locals: &LoopLocals<'_>,
    rt: &mut IoRuntime,
    op: &'static crate::builtins::iface::BuiltinDecl,
    #[cfg(test)] id: crate::builtins::BuiltinId,
) -> Result<Control, Stop> {
    #[cfg(test)]
    let op = rt.builtin_overrides.get(&id).copied().unwrap_or(op);
    locals.save(state.frame_mut()?);
    park(state, WaitReason::Response)?;
    rt.queue.publish(
        state.current_task,
        op,
        InstrRef {
            proto: locals.proto,
            pc: locals.pc,
        },
    );
    notify_collect(state, ctx);
    Ok(Control::Return)
}

#[cold]
#[inline(never)]
fn reflect_cancellation(state: &mut RunState, rt: &mut IoRuntime) {
    if std::mem::take(&mut state.scheduling.expire_io) {
        rt.queue.expire_all();
        rt.stdin_waiters.clear();
        rt.sleeps.clear();
        rt.stdout.cancel_all_pending();
        rt.stderr.cancel_all_pending();
        rt.output_sites.clear();
        rt.sleep_timers.clear();
        rt.ops.detach_all();
        for timer in std::mem::take(&mut rt.readiness.op_timers).into_values() {
            rt.readiness.retries.remove(&timer);
            state.scheduler.remove_timer(timer);
        }
    }
    for task in std::mem::take(&mut state.scheduling.cancelled_io) {
        rt.queue.expire_task(task);
        for op in rt.ops.task_operations(task) {
            if let Some(timer) = rt.readiness.op_timers.remove(&op) {
                rt.readiness.retries.remove(&timer);
                state.scheduler.remove_timer(timer);
            }
        }
        rt.ops.detach_task(task);
        rt.stdin_waiters.retain(|&id| id != task);
        if let Some(timer) = rt.sleep_timers.remove(&task) {
            rt.sleeps.remove(&timer);
        }
        rt.stdout.cancel_pending(task);
        rt.stderr.cancel_pending(task);
        rt.output_sites.remove(&task);
    }
}

fn operands(
    program: &CompiledProgram,
    site: InstrRef,
) -> Result<crate::bytecode::program::BuiltinCallOperands, Stop> {
    let instruction = program
        .proto(site.proto)
        .and_then(|p| p.code.get(usize::try_from(site.pc).ok()?))
        .copied()
        .ok_or_else(|| missing("IO instruction missing"))?;
    program
        .builtin_call_operands(instruction)
        .ok_or_else(|| missing("IO operands missing"))
}
fn args<'e>(
    program: &CompiledProgram,
    state: &RunState,
    ctx: &NoGcCtx<'e>,
    task: TaskId,
    site: InstrRef,
) -> Result<Operands<'e>, Stop> {
    let call = operands(program, site)?;
    let value = object(state, ctx, task)?;
    let task = ctx
        .host::<TaskObj>(value)
        .ok_or_else(|| missing("IO task missing"))?;
    let segment = task
        .stack
        .segments
        .last()
        .ok_or_else(|| missing("IO segment missing"))?;
    let frame = segment
        .calls
        .last()
        .ok_or_else(|| missing("IO frame missing"))?;
    if frame.proto != site.proto || frame.pc != site.pc {
        return Err(missing("IO frame changed"));
    }
    let start = frame
        .base
        .checked_add(u32::from(call.args_start))
        .ok_or_else(|| missing("IO argument overflow"))?;
    let end = start
        .checked_add(u32::from(call.arg_count))
        .ok_or_else(|| missing("IO argument overflow"))?;
    let slots = segment
        .regs
        .get(index(start)?..index(end)?)
        .ok_or_else(|| missing("IO arguments missing"))?;
    let mut values = Operands::new(slots.len());
    for (dst, slot) in values.as_mut_slice().iter_mut().zip(slots) {
        *dst = ctx.load(slot);
    }
    Ok(values)
}

#[cold]
#[inline(never)]
pub(super) fn write_result<'e>(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    task: TaskId,
    site: InstrRef,
    result: Value<'e>,
) -> Result<(), Stop> {
    let call = operands(program, site)?;
    let value = object(state, ctx, task)?;
    ctx.host_mut::<TaskObj, _>(value, |task, slots| -> Result<(), Stop> {
        let segment = task
            .stack
            .segments
            .last_mut()
            .ok_or_else(|| missing("IO segment missing"))?;
        let frame = segment
            .calls
            .last_mut()
            .ok_or_else(|| missing("IO frame missing"))?;
        if frame.proto != site.proto || frame.pc != site.pc {
            return Err(missing("IO result frame changed"));
        }
        let dst = frame
            .base
            .checked_add(u32::from(call.result))
            .ok_or_else(|| missing("IO result overflow"))?;
        let next = site
            .pc
            .checked_add(1)
            .ok_or_else(|| missing("IO pc overflow"))?;
        // 書き込みと位置の更新を一続きにする。回収が見るのは次の命令の入口だけである（設計書 02-08「IO の命令」）。
        slots.store(
            segment
                .regs
                .get_mut(index(dst)?)
                .ok_or_else(|| missing("IO result missing"))?,
            result,
        );
        frame.pc = next;
        Ok(())
    })
    .ok_or_else(|| missing("IO result task missing"))??;
    notify_collect(state, ctx);
    Ok(())
}

fn waiting(state: &RunState, task: TaskId, reason: WaitReason) -> bool {
    state
        .scheduler
        .waiting
        .get(&task)
        .is_some_and(|w| w.reason == reason)
}
fn repark(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    task: TaskId,
    from: WaitReason,
    to: WaitReason,
) -> Result<(), Stop> {
    state.scheduler.repark(task, from, to)?;
    let value = object(state, ctx, task)?;
    ctx.host_mut::<TaskObj, _>(value, |t, _| {
        if matches!(t.state, TaskState::Waiting(_)) {
            t.state = TaskState::Waiting(to);
        }
    })
    .ok_or_else(|| missing("reparked task missing"))?;
    Ok(())
}
fn fail_task(
    state: &mut RunState,
    ctx: &NoGcCtx<'_>,
    task: TaskId,
    site: InstrRef,
    stop: Stop,
) -> Result<(), Stop> {
    if state.stopping.is_none() {
        let value = object(state, ctx, task)?;
        let task_obj = ctx
            .host::<TaskObj>(value)
            .ok_or_else(|| missing("failed IO task missing"))?;
        let frames = task_obj
            .stack
            .segments
            .iter()
            .rev()
            .flat_map(|s| {
                s.calls.iter().rev().map(|f| crate::vm::FrameRecord {
                    proto: f.proto,
                    call_site: f.call_site,
                })
            })
            .collect();
        state.stopping = Some(StopReason::Error(crate::vm::StopInfo {
            stop,
            at: Some(site),
            frames,
            spawns: state
                .scheduling
                .spawns
                .get(&task)
                .map_or_else(Vec::new, |s| s.history.clone()),
            deadlock: Vec::new(),
        }));
    }
    Ok(())
}

#[cold]
#[inline(never)]
pub(in crate::vm) fn serve(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    id: crate::vm::RequestId,
) -> Result<(), Stop> {
    reflect_cancellation(state, rt);
    let Some(req) = rt.queue.take_for_serve(id) else {
        return Ok(());
    };
    if !waiting(state, req.task, WaitReason::Response) {
        return Err(missing("request task is not waiting for response"));
    }
    let result = serve_inner(program, state, ctx, rt, req);
    if let Err(stop) = result {
        fail_task(state, ctx, req.task, req.site, stop)?;
    }
    if state.stopping.is_some() {
        begin_stop_all(state, ctx)?;
        reflect_cancellation(state, rt);
    }
    Ok(())
}
#[cold]
#[inline(never)]
fn serve_inner(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    req: Request,
) -> Result<(), Stop> {
    let args = args(program, state, ctx, req.task, req.site)?;
    rt.output_task = req.task;
    let reply = {
        let mut view = IoView {
            rt,
            resources: &mut state.resources,
        };
        let mut call = CallCtx::new(ctx, Some(&mut view), None, Some(req.site));
        (req.op.raw)(&mut call, &args)?
    };
    match reply {
        Reply::Done(value) => {
            write_result(program, state, ctx, req.task, req.site, value)?;
            state.scheduler.wake_if(req.task, WaitReason::Response);
        }
        Reply::Wait(WaitRequest::Io(IoWait::Worker(work))) => {
            submit(state, ctx, rt, req, work, WaitReason::Response)?
        }
        Reply::Wait(WaitRequest::Io(IoWait::Readiness { resource, interest })) => {
            let op = state.scheduler.new_ext_op_id();
            rt.ops.check_insert(op)?;
            repark(
                state,
                ctx,
                req.task,
                WaitReason::Response,
                WaitReason::Readiness(op),
            )?;
            rt.ops.insert(
                op,
                OpRecord {
                    kind: OpKind::Readiness,
                    deliver_to: Some(req.task),
                    lent: None,
                    site: Some(req.site),
                },
            );
            rt.readiness.resources.insert(op, resource);
            rt.readiness
                .resource_ops
                .entry(resource)
                .or_default()
                .insert(op);
            state.resources.watch_readiness(resource);
            // 待ちの記録を公開してから OS の登録を行う（実装プラン 10-16「準備の待ちの規則」）。
            let armed = crate::runtime::io::http::arm(
                &mut state.resources,
                resource,
                &rt.wakeup,
                interest,
            )?;
            for &token in &armed.tokens {
                rt.readiness.tokens.entry(token).or_default().insert(op);
            }
            rt.readiness.op_tokens.insert(op, armed.tokens);
            if let Some(deadline) = armed.deadline {
                let timer = state.scheduler.new_timer_id();
                rt.readiness.retries.insert(timer, op);
                rt.readiness.op_timers.insert(op, timer);
                state.scheduler.add_timer(deadline, timer, req.task);
            }
        }
        Reply::Wait(WaitRequest::Io(IoWait::Sleep { millis })) => {
            let timer = state.scheduler.new_timer_id();
            let deadline = rt
                .parts
                .clock
                .monotonic_millis()
                .checked_add(millis)
                .ok_or_else(|| missing("sleep deadline overflow"))?;
            repark(
                state,
                ctx,
                req.task,
                WaitReason::Response,
                WaitReason::Timer(timer),
            )?;
            state.scheduler.add_timer(deadline, timer, req.task);
            rt.sleeps.insert(timer, (req.task, req.site));
            rt.sleep_timers.insert(req.task, timer);
        }
        Reply::Wait(WaitRequest::Io(IoWait::Output { stream, kind })) => {
            if kind != OutputWaitKind::Capacity {
                return Err(missing("builtin returned output flush wait"));
            }
            repark(
                state,
                ctx,
                req.task,
                WaitReason::Response,
                WaitReason::Output(stream, kind),
            )?;
            rt.output_sites.insert(req.task, req.site);
        }
        Reply::Exit(status) => {
            if state.stopping.is_none() {
                state.stopping = Some(StopReason::Exit(status.0));
            }
        }
        Reply::Wait(_) | Reply::SpawnTasks(_) => {
            return Err(missing("IO reply has unsupported wait or spawn"));
        }
    }
    Ok(())
}

#[cold]
#[inline(never)]
fn submit(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    req: Request,
    work: WorkerWait,
    from: WaitReason,
) -> Result<(), Stop> {
    if work.needs_output_flush() {
        // 再開時は既に完了した出力を待ち直さない。貸し出しの待ちも出力の後である（10-10）。
        let streams: &[Stream] = match from {
            WaitReason::Output(Stream::Stdout, OutputWaitKind::Flush) => &[Stream::Stderr],
            WaitReason::Output(Stream::Stderr, OutputWaitKind::Flush) | WaitReason::Lend(_) => &[],
            WaitReason::Response => &[Stream::Stdout, Stream::Stderr],
            WaitReason::Worker(_)
            | WaitReason::Timer(_)
            | WaitReason::Readiness(_)
            | WaitReason::Output(_, OutputWaitKind::Capacity)
            | WaitReason::Release(_)
            | WaitReason::TaskEnd(_)
            | WaitReason::Lazy => return Err(missing("invalid wait before output flush")),
        };
        for &stream in streams {
            let port = match stream {
                Stream::Stdout => &mut rt.stdout,
                Stream::Stderr => &mut rt.stderr,
            };
            port.request_transfer();
            if port
                .flush_pending()
                .map_err(|failure| output_failure(stream, failure))?
            {
                port.flush_target(req.task);
                rt.queue.check_park_request(&req)?;
                rt.queue.park_request(req, RequestPhase::AwaitFlush(work));
                return repark(
                    state,
                    ctx,
                    req.task,
                    from,
                    WaitReason::Output(stream, OutputWaitKind::Flush),
                );
            }
        }
    }
    let (op, lent) = match work.lend() {
        Lend::Nothing => (state.scheduler.new_ext_op_id(), LentOwned::Nothing),
        Lend::Stdin => {
            let Some(reader) = rt.stdin.take() else {
                rt.stdin_waiters.push_back(req.task);
                return await_lend(state, ctx, rt, req, work, from, STDIN_LEND);
            };
            (state.scheduler.new_ext_op_id(), LentOwned::Stdin(reader))
        }
        Lend::Resource(id) => {
            state.resources.check_lend(id)?;
            let op = state.scheduler.new_ext_op_id();
            match state.resources.lend(id, op, req.task) {
                LendResult::Lent(handle) => (op, LentOwned::Resource(id, handle)),
                LendResult::MustWait => return await_lend(state, ctx, rt, req, work, from, id),
                LendResult::Released(kind) => {
                    return Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind }));
                }
            }
        }
    };
    rt.ops.check_insert(op)?;
    repark(state, ctx, req.task, from, WaitReason::Worker(op))?;
    rt.ops.insert(
        op,
        OpRecord {
            kind: OpKind::Worker,
            deliver_to: Some(req.task),
            lent: match &lent {
                LentOwned::Resource(id, _) => Some(*id),
                LentOwned::Nothing | LentOwned::Stdin(_) => None,
            },
            site: Some(req.site),
        },
    );
    rt.parts.workers.submit(WorkerJob {
        op,
        work: JobWork::Builtin(work),
        lent,
    });
    Ok(())
}
fn await_lend(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    req: Request,
    work: WorkerWait,
    from: WaitReason,
    resource: crate::runtime::heap::ResourceId,
) -> Result<(), Stop> {
    rt.queue.check_park_request(&req)?;
    rt.queue
        .park_request(req, RequestPhase::AwaitLend(resource, work));
    repark(state, ctx, req.task, from, WaitReason::Lend(resource))
}
fn resume_lender(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    task: TaskId,
    resource: crate::runtime::heap::ResourceId,
) -> Result<bool, Stop> {
    let reason = WaitReason::Lend(resource);
    if !waiting(state, task, reason) {
        return Ok(false);
    }
    let request = rt
        .queue
        .take_task_request(task)
        .ok_or_else(|| missing("lender request missing"))?;
    let RequestPhase::AwaitLend(id, work) = request.phase else {
        return Err(missing("lender request phase mismatch"));
    };
    if id != resource {
        return Err(missing("lender resource mismatch"));
    }
    if let Err(stop) = submit(state, ctx, rt, request.req, work, reason) {
        fail_task(state, ctx, task, request.req.site, stop)?;
        begin_stop_all(state, ctx)?;
        reflect_cancellation(state, rt);
    }
    Ok(true)
}
fn resume_resource(
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    id: crate::runtime::heap::ResourceId,
    all: bool,
) -> Result<(), Stop> {
    while let Some(task) = state.resources.pop_waiter(id) {
        if resume_lender(state, ctx, rt, task, id)? && !all {
            break;
        }
    }
    Ok(())
}
fn output_failure(stream: Stream, failure: WriteFailure) -> Stop {
    match failure {
        WriteFailure::Io(reason) => Stop::Runtime(RuntimeError::WriteFailed { stream, reason }),
        WriteFailure::Panicked(report) => internal(&report.message),
    }
}

#[cold]
#[inline(never)]
fn poll_outputs(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
) -> Result<(), Stop> {
    for stream in [Stream::Stdout, Stream::Stderr] {
        let (tasks, failure) = match stream {
            Stream::Stdout => rt.stdout.poll(),
            Stream::Stderr => rt.stderr.poll(),
        };
        for task in tasks {
            let reason = WaitReason::Output(stream, OutputWaitKind::Capacity);
            let (site, result) = if waiting(state, task, reason) {
                let site = rt
                    .output_sites
                    .remove(&task)
                    .ok_or_else(|| missing("output capacity site missing"))?;
                let result = match &failure {
                    Some(failure) => Err(output_failure(stream, failure.clone())),
                    None => {
                        write_result(program, state, ctx, task, site, Value::Unit)?;
                        state.scheduler.wake_if(task, reason);
                        Ok(())
                    }
                };
                (site, result)
            } else {
                let reason = WaitReason::Output(stream, OutputWaitKind::Flush);
                if !waiting(state, task, reason) {
                    continue;
                }
                let request = rt
                    .queue
                    .take_task_request(task)
                    .ok_or_else(|| missing("output flush request missing"))?;
                let RequestPhase::AwaitFlush(work) = request.phase else {
                    return Err(missing("output flush phase mismatch"));
                };
                let result = match &failure {
                    Some(failure) => Err(output_failure(stream, failure.clone())),
                    None => submit(state, ctx, rt, request.req, work, reason),
                };
                (request.req.site, result)
            };
            if let Err(stop) = result {
                fail_task(state, ctx, task, site, stop)?;
                begin_stop_all(state, ctx)?;
                reflect_cancellation(state, rt);
            }
        }
    }
    Ok(())
}

#[cold]
#[inline(never)]
pub(super) fn boundary(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    at: WaitPoint,
) -> Result<(), Stop> {
    reflect_cancellation(state, rt);
    if state.stopping.is_some() && !state.scheduling.stopping {
        begin_stop_all(state, ctx)?;
        reflect_cancellation(state, rt);
    }
    dispatch_pending(program, state, ctx, rt, at)?;
    let mut readiness = ready_ops(state, rt).into_iter();
    loop {
        while let Some((id, op, resource)) = state.resources.take_release_job() {
            rt.ops.check_insert(op)?;
            rt.ops.insert(
                op,
                OpRecord {
                    kind: OpKind::Release(id),
                    deliver_to: None,
                    lent: None,
                    site: None,
                },
            );
            rt.parts.workers.submit(WorkerJob {
                op,
                work: JobWork::Release(resource),
                lent: LentOwned::Nothing,
            });
        }
        let Some(completion) = readiness
            .next()
            .map(|op| Completion {
                op,
                outcome: Outcome::Ready,
                returned: LentOwned::Nothing,
            })
            .or_else(|| rt.parts.workers.try_recv())
        else {
            break;
        };
        if matches!(completion.outcome, Outcome::Ready) {
            clear_ready(state, rt, completion.op)?;
        }
        ops::check_completion(&rt.ops, &state.resources, &completion)?;
        let accepted =
            ops::accept_completion(&mut rt.ops, &mut state.resources, &mut rt.stdin, completion);
        for event in accepted {
            match event {
                Accepted::Returned(id) => resume_resource(state, ctx, rt, id, false)?,
                Accepted::StartRelease(id) => {
                    state.resources.check_release(id)?;
                    let op = state.scheduler.new_ext_op_id();
                    if let ReleaseStart::Done(result) = state.resources.request_release(id, op) {
                        state.resources.finish_release(id, result);
                        state.scheduler.wake_all(WaitReason::Release(id));
                        resume_resource(state, ctx, rt, id, true)?;
                    }
                }
                Accepted::ReleaseFinished(id) => {
                    state.scheduler.wake_all(WaitReason::Release(id));
                    resume_resource(state, ctx, rt, id, true)?;
                }
                Accepted::Bug(report) => {
                    state.fail(internal(&report.message), None);
                    rt.worker_bug = Some(report);
                    begin_stop_all(state, ctx)?;
                    reflect_cancellation(state, rt);
                }
                Accepted::Deliver {
                    task,
                    op,
                    site,
                    outcome,
                } => {
                    if !waiting(state, task, WaitReason::Worker(op))
                        && !waiting(state, task, WaitReason::Readiness(op))
                    {
                        continue;
                    }
                    let site = site.ok_or_else(|| missing("completion site missing"))?;
                    if matches!(outcome, Outcome::Ready) {
                        retry_request(program, state, ctx, rt, task, op, site)?;
                        continue;
                    }
                    let result = complete(program, state, ctx, rt, task, site, outcome);
                    match result {
                        Ok(value) => {
                            write_result(program, state, ctx, task, site, value)?;
                            if !state.scheduler.wake_if(task, WaitReason::Worker(op)) {
                                state.scheduler.wake_if(task, WaitReason::Readiness(op));
                            }
                        }
                        Err(stop) => {
                            fail_task(state, ctx, task, site, stop)?;
                            begin_stop_all(state, ctx)?;
                            reflect_cancellation(state, rt);
                        }
                    }
                }
                Accepted::Dropped => {}
            }
        }
        while rt.stdin.is_some() {
            let Some(task) = rt.stdin_waiters.pop_front() else {
                break;
            };
            if resume_lender(state, ctx, rt, task, STDIN_LEND)? {
                break;
            }
        }
    }
    poll_outputs(program, state, ctx, rt)?;
    Ok(())
}
// やり直した要求を、同じ境界で実行器へ渡す（実装プラン L30 の手順 (b)）。
fn dispatch_pending(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    at: WaitPoint,
) -> Result<(), Stop> {
    match rt.dispatcher.on_wait_point(&mut rt.queue, at) {
        DispatchAction::ServeNow(ids) => {
            for id in ids {
                serve(program, state, ctx, rt, id)?;
            }
        }
        DispatchAction::ReturnToExecutor(ids) => {
            if !ids.is_empty() || at == WaitPoint::SlowPath || state.scheduler.ready.is_empty() {
                if let Some(VmStep::Requests(existing)) = &mut state.step {
                    existing.extend(ids);
                } else {
                    state.step = Some(VmStep::Requests(ids));
                }
            }
        }
        DispatchAction::Nothing => {}
    }
    Ok(())
}
fn retry_request(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    task: TaskId,
    op: crate::runtime::sched::ExtOpId,
    site: InstrRef,
) -> Result<(), Stop> {
    if !waiting(state, task, WaitReason::Readiness(op)) {
        return Ok(());
    }
    let builtin = program
        .builtin(operands(program, site)?.builtin)
        .ok_or_else(|| missing("readiness builtin reference missing"))?;
    let decl = crate::builtins::table::builtin_decl(builtin.id)
        .ok_or_else(|| missing("readiness builtin declaration missing"))?;
    repark(
        state,
        ctx,
        task,
        WaitReason::Readiness(op),
        WaitReason::Response,
    )?;
    rt.queue.publish(task, decl, site);
    dispatch_pending(program, state, ctx, rt, WaitPoint::Park)
}
fn clear_ready(
    state: &mut RunState,
    rt: &mut IoRuntime,
    op: crate::runtime::sched::ExtOpId,
) -> Result<(), Stop> {
    if let Some(tokens) = rt.readiness.op_tokens.remove(&op) {
        for token in tokens {
            if let Some(ops) = rt.readiness.tokens.get_mut(&token) {
                ops.remove(&op);
                if ops.is_empty() {
                    rt.readiness.tokens.remove(&token);
                }
            }
        }
    }
    if let Some(timer) = rt.readiness.op_timers.remove(&op) {
        rt.readiness.retries.remove(&timer);
        state.scheduler.remove_timer(timer);
    }
    if let Some(resource) = rt.readiness.resources.remove(&op)
        && let Some(ops) = rt.readiness.resource_ops.get_mut(&resource)
    {
        ops.remove(&op);
        if ops.is_empty() {
            rt.readiness.resource_ops.remove(&resource);
            state.resources.unwatch_readiness(resource);
            crate::runtime::io::http::disarm(&mut state.resources, resource, &rt.wakeup)?;
        }
    }
    Ok(())
}
fn ready_ops(
    state: &RunState,
    rt: &mut IoRuntime,
) -> std::collections::BTreeSet<crate::runtime::sched::ExtOpId> {
    let tokens = if rt.readiness.tokens.is_empty() {
        Vec::new()
    } else {
        crate::runtime::io::event::take_ready(&rt.wakeup)
    };
    ready_for_tokens(state, rt, tokens)
}
// 一つの操作を二度完了させず、配送後の古い知らせを捨てる（実装プラン L30 の手順 (c)）。
fn ready_for_tokens(
    state: &RunState,
    rt: &IoRuntime,
    tokens: impl IntoIterator<Item = usize>,
) -> std::collections::BTreeSet<crate::runtime::sched::ExtOpId> {
    let mut ready = std::collections::BTreeSet::new();
    for token in tokens {
        if let Some(ops) = rt.readiness.tokens.get(&token) {
            ready.extend(ops);
        }
    }
    // 解放で登録が外れた資源の待ちもやり直し、解放後の使用の誤りとして起こす（実装プラン L30）。
    for resource in state.resources.closed_readiness() {
        if let Some(ops) = rt.readiness.resource_ops.get(&resource) {
            ready.extend(ops);
        }
    }
    ready.retain(|op| rt.ops.records.contains_key(op));
    ready
}

/// 満了した受け付けの再試行を Ready の完了として処理する（実装プラン L30）。
pub(super) fn expire_retry(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'_>,
    rt: &mut IoRuntime,
    timer: crate::runtime::sched::TimerId,
) -> Result<(), Stop> {
    let Some(op) = rt.readiness.retries.remove(&timer) else {
        return Ok(());
    };
    rt.readiness.op_timers.remove(&op);
    if !rt.ops.records.contains_key(&op) {
        return Ok(());
    }
    clear_ready(state, rt, op)?;
    let completion = Completion {
        op,
        outcome: Outcome::Ready,
        returned: LentOwned::Nothing,
    };
    ops::check_completion(&rt.ops, &state.resources, &completion)?;
    for accepted in
        ops::accept_completion(&mut rt.ops, &mut state.resources, &mut rt.stdin, completion)
    {
        if let Accepted::Deliver {
            task,
            op,
            site,
            outcome: Outcome::Ready,
        } = accepted
        {
            retry_request(
                program,
                state,
                ctx,
                rt,
                task,
                op,
                site.ok_or_else(|| missing("accept retry site missing"))?,
            )?;
        }
    }
    Ok(())
}

fn complete<'e>(
    program: &CompiledProgram,
    state: &mut RunState,
    ctx: &mut NoGcCtx<'e>,
    rt: &mut IoRuntime,
    task: TaskId,
    site: InstrRef,
    outcome: Outcome,
) -> Result<Value<'e>, Stop> {
    let args = args(program, state, ctx, task, site)?;
    let Outcome::Worker(done) = outcome else {
        return Err(missing("unsupported completion outcome"));
    };
    rt.output_task = task;
    let mut view = IoView {
        rt,
        resources: &mut state.resources,
    };
    let mut call = CallCtx::new(ctx, Some(&mut view), None, Some(site));
    done.complete(&mut call.io_ctx()?, &args)
}

#[cfg(test)]
mod tests;

#[cfg(test)]
mod output_tests;

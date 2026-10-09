//! 止まったときの報告の組み立て（設計書 02-08「実行時エラーの情報の記録」、02-10「実行時エラーと資源の不足の報告」
//! 「解放の失敗の報告」「処理系の不具合と処理系の制限の報告」）。
//! 報告を標準エラー出力に書くのは呼び出し側である。ここでは `Diagnostic` を作るだけにする。

/// 処理系の不具合が起きたスレッド（02-10「処理系の不具合と処理系の制限の報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FaultThread {
    /// 検査・脱糖・コンパイルの段（`pipeline` の段のスレッド）
    Stage,
    /// VM のスレッド
    Vm,
    /// 作業用のスレッド（10-10）
    Worker,
    /// 書き出し用のスレッド（10-10）
    Writer,
}

/// `Process.exit` と中断の要求で止める途中の解放の失敗の報告（`"release"`）の、止めた理由（02-10「解放の失敗の報告」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReleaseCause {
    Exit(u8),
    Interrupted,
}

/// 報告の型板に埋める値の語（ADR 0033）。
pub mod text {
    /// `FaultThread` の呼び名（`codes::text::INTERNAL_THREAD` の `{thread}`）
    pub const THREAD_STAGE: &str = "compiler";
    pub const THREAD_VM: &str = "VM";
    pub const THREAD_WORKER: &str = "worker";
    pub const THREAD_WRITER: &str = "output writer";
    /// リソースの型の名前（`ResourceKind` の順。R0401・R0402 の `{resource}`）
    pub const RESOURCE_FILE_READER: &str = "File.Reader";
    pub const RESOURCE_FILE_WRITER: &str = "File.Writer";
    pub const RESOURCE_HTTP_LISTENER: &str = "Http.Listener";
    pub const RESOURCE_HTTP_EXCHANGE: &str = "Http.Exchange";
    pub const RESOURCE_TASK_GROUP: &str = "TaskGroup";
    /// 行き詰まりで待つ種類（組み込みの関数のほか。`WaitingTask::waits_for`）
    pub const WAIT_LAZY: &str = "Lazy evaluation";
    pub const WAIT_HANDLE_END: &str = "handle end";
    pub const WAIT_TASK_GROUP_RELEASE: &str = "TaskGroup release";
    /// 出力の呼び名（`codes::text::FLUSH_FAILED_NOTE` の `{stream}`）
    pub const STDOUT_NAME: &str = "standard output";
    pub const STDERR_NAME: &str = "standard error";
    /// R0902・R0903 の `{unit}`
    pub const UNIT_BYTES: &str = "bytes";
    pub const UNIT_ELEMENTS: &str = "elements";
    /// 位置が分からないときに `{location}` に埋める値
    pub const UNKNOWN_LOCATION: &str = "<unknown>";
}

use crate::base::{SourceKind, Span};
use crate::builtins::builtin_decl;
use crate::bytecode::program::{CompiledProgram, ProtoIdx, ProtoOrigin};
use crate::diag::codes::{self, fill_template};
use crate::diag::{
    CallTrace, DiagBuilder, DiagCode, Diagnostic, FrameName, ReportKind, Severity, TraceFrame,
    WaitingTask,
};
use crate::runtime::panic::PanicReport;
use crate::runtime::{
    ReleaseFailure, ResourceError, ResourceKind, RuntimeError, SizeUnit, Stop, Stream,
};
use crate::vm::{DeadlockWaitKind, FrameRecord, InstrRef, SpawnRecord, StopInfo};

/// 実行時エラー・資源の不足の報告を作る。`Stop` の値ごとのコードは 10-02「実行時エラー、資源の不足、処理系の制限」の表に従う。
/// 主な位置、呼び出しの履歴、タスクの起動の履歴は 02-08「実行時エラーの情報の記録」の 1〜4 で作る。
/// 書き込みの失敗は主な位置と履歴を持たない。行き詰まり（R1001）は主な位置を持たず、段のない履歴と、待つタスクの並びを持つ。
/// `Stop::Internal` は処理系の不具合の報告（`internal_diagnostic` と同じ形。スレッドは VM）にする。
pub fn stop_diagnostic(program: &CompiledProgram, info: &StopInfo) -> Diagnostic {
    let builder = match &info.stop {
        Stop::Runtime(RuntimeError::DivisionByZero) => DiagBuilder::new(DiagCode::R0101),
        Stop::Runtime(RuntimeError::IntegerOverflow) => DiagBuilder::new(DiagCode::R0102),
        Stop::Runtime(RuntimeError::DecimalOverflow) => DiagBuilder::new(DiagCode::R0103),
        Stop::Runtime(RuntimeError::WriteFailed { stream, reason }) => {
            return write_failed(*stream, reason);
        }
        Stop::Runtime(RuntimeError::ReleaseFailed(failures)) => {
            let Some(first) = failures.first() else {
                return internal_diagnostic(
                    "run",
                    "release failure record is empty",
                    None,
                    FaultThread::Vm,
                );
            };
            release_builder(program, first)
        }
        Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind }) => {
            DiagBuilder::new(DiagCode::R0402).arg("resource", resource_name(*kind))
        }
        Stop::Runtime(RuntimeError::ContinuationResumedTwice) => DiagBuilder::new(DiagCode::R0501),
        Stop::Runtime(RuntimeError::InheritedHandlerClause { operation }) => {
            DiagBuilder::new(DiagCode::R0502)
                .arg("operation", operation.clone())
                .help("tail")
        }
        Stop::Runtime(RuntimeError::ArgumentOutOfDomain { function, argument }) => {
            DiagBuilder::new(DiagCode::R0701)
                .arg("function", *function)
                .arg("index", u32::from(*argument).saturating_add(1).to_string())
        }
        Stop::Runtime(RuntimeError::ResponseSentTwice) => DiagBuilder::new(DiagCode::R0801),
        Stop::Runtime(RuntimeError::TaskDeadlock) => return deadlock_diagnostic(program, info),
        Stop::Runtime(RuntimeError::AwaitedTaskCancelled) => DiagBuilder::new(DiagCode::R1002),
        Stop::Resource(ResourceError::CallStackTooDeep { frames }) => {
            DiagBuilder::new(DiagCode::R0901)
                .arg("frames", frames.to_string())
                .note("frames")
                .help("raise")
        }
        Stop::Resource(ResourceError::ValueTooLarge {
            function,
            size,
            unit,
            limit,
        }) => DiagBuilder::new(DiagCode::R0902)
            .arg("function", *function)
            .arg("size", size.to_string())
            .arg("unit", unit_name(*unit))
            .arg("limit", limit.to_string())
            .note("size"),
        Stop::Resource(ResourceError::InputTooLarge {
            function,
            unit,
            limit,
        }) => DiagBuilder::new(DiagCode::R0903)
            .arg("function", *function)
            .arg("unit", unit_name(*unit))
            .arg("limit", limit.to_string()),
        Stop::Internal(message) => {
            return internal_diagnostic("run", message, None, FaultThread::Vm);
        }
    };
    let primary = user_location(program, info.at, info.frames.iter().map(|f| f.call_site));
    let builder = match primary {
        Some(span) => builder.primary(span),
        None => builder,
    };
    let mut report = builder.build();
    let trace = match call_trace(program, &info.frames) {
        Ok(trace) => trace,
        Err(message) => return internal_diagnostic("run", &message, None, FaultThread::Vm),
    };
    let origins = match task_origins(program, &info.spawns) {
        Ok(origins) => origins,
        Err(message) => return internal_diagnostic("run", &message, None, FaultThread::Vm),
    };
    report.trace = Some(trace);
    report.task_origins = origins;
    if let Stop::Runtime(RuntimeError::ReleaseFailed(failures)) = &info.stop {
        for failure in failures {
            report.notes.push(release_note(program, failure, "failure"));
        }
    }
    report
        .notes
        .push(String::from(codes::text::TRACE_TAIL_NOTE));
    report
}

/// 実行時エラーか資源の不足で止める途中の解放の失敗を、先の報告に注記として加える（02-10「解放の失敗の報告」、ADR 0068）。
/// 注記は `codes::text::RELEASE_WHILE_STOPPING` の形で、末尾呼び出しの注記の前に置く。
pub fn add_release_failures(
    report: &mut Diagnostic,
    program: &CompiledProgram,
    failures: &[ReleaseFailure],
) {
    for failure in failures {
        let args = release_args(program, failure);
        insert_before_tail(
            report,
            fill_template(codes::text::RELEASE_WHILE_STOPPING, &args),
        );
    }
}

/// `Process.exit` と中断の要求で止める途中の解放の失敗一つの報告（R0401、報告の種類 `Release`）。
/// 解放の失敗を報告しないリソースの型（`Http.Exchange`。ADR 0149）の失敗は、呼び出し側が渡さない。
pub fn release_report(
    program: &CompiledProgram,
    failure: &ReleaseFailure,
    cause: ReleaseCause,
) -> Diagnostic {
    let mut report = release_builder(program, failure)
        .kind(ReportKind::Release)
        .arg("reason", failure.reason.clone())
        .note("reason")
        .build();
    report.notes.push(match cause {
        ReleaseCause::Exit(code) => fill_template(
            codes::text::RELEASE_EXIT_NOTE,
            &[("code", code.to_string())],
        ),
        ReleaseCause::Interrupted => String::from(codes::text::RELEASE_INTERRUPT_NOTE),
    });
    report
}

/// 出力の最後の転送の失敗の報告（R0201・R0202。主な位置と履歴を持たない。02-09「プログラムの実行の流れ」）。
pub fn write_failed(stream: Stream, reason: &str) -> Diagnostic {
    let code = match stream {
        Stream::Stdout => DiagCode::R0201,
        Stream::Stderr => DiagCode::R0202,
    };
    DiagBuilder::new(code)
        .arg("reason", reason)
        .note("reason")
        .build()
}

/// 出力の最後の転送の失敗を、先の実行時エラーの報告に注記（`codes::text::FLUSH_FAILED_NOTE`）として加える。
pub fn add_flush_failure(report: &mut Diagnostic, stream: Stream, reason: &str) {
    let stream = match stream {
        Stream::Stdout => text::STDOUT_NAME,
        Stream::Stderr => text::STDERR_NAME,
    };
    insert_before_tail(
        report,
        fill_template(
            codes::text::FLUSH_FAILED_NOTE,
            &[
                ("stream", String::from(stream)),
                ("reason", String::from(reason)),
            ],
        ),
    );
}

/// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）。コードを持たないので `DiagBuilder` を使わず、
/// `Diagnostic` を直接組み立てる（kind は `Internal`、文言は `codes::text::INTERNAL_*`）。版・段・スレッド・panic の内容・
/// 報告を求める文を注記に、バックトレースを `backtrace` に入れる。`stage` は段の名前、`message` は不具合の説明。
pub fn internal_diagnostic(
    stage: &str,
    message: &str,
    panic: Option<&PanicReport>,
    thread: FaultThread,
) -> Diagnostic {
    let thread = match thread {
        FaultThread::Stage => text::THREAD_STAGE,
        FaultThread::Vm => text::THREAD_VM,
        FaultThread::Worker => text::THREAD_WORKER,
        FaultThread::Writer => text::THREAD_WRITER,
    };
    let mut notes = vec![
        fill_template(
            codes::text::INTERNAL_VERSION,
            &[("version", String::from(env!("CARGO_PKG_VERSION")))],
        ),
        fill_template(
            codes::text::INTERNAL_STAGE,
            &[("stage", String::from(stage))],
        ),
        fill_template(
            codes::text::INTERNAL_THREAD,
            &[("thread", String::from(thread))],
        ),
    ];
    if !message.is_empty() {
        notes.push(String::from(message));
    }
    if let Some(panic) = panic {
        notes.push(fill_template(
            codes::text::INTERNAL_PANIC,
            &[
                ("message", panic.message.clone()),
                (
                    "location",
                    panic
                        .location
                        .clone()
                        .unwrap_or_else(|| String::from(text::UNKNOWN_LOCATION)),
                ),
            ],
        ));
    }
    notes.push(String::from(codes::text::INTERNAL_REPORT));
    Diagnostic {
        kind: ReportKind::Internal,
        severity: Severity::Error,
        code: None,
        message: String::from(codes::text::INTERNAL_MESSAGE),
        primary: None,
        secondary: Vec::new(),
        notes,
        helps: Vec::new(),
        trace: None,
        task_origins: Vec::new(),
        waiting: Vec::new(),
        backtrace: panic.and_then(|p| p.backtrace.clone()),
    }
}

/// 原型の名前と由来の種類から、履歴の段の名前を作る（02-10「実行時エラーと資源の不足の報告」の名前の規則）。
/// 標準ライブラリの補助の関数は `None`（履歴に含めない）。
pub fn frame_name(program: &CompiledProgram, proto: ProtoIdx) -> Option<FrameName> {
    let proto = program.proto(proto)?;
    Some(match proto.origin {
        ProtoOrigin::UserFn
        | ProtoOrigin::UserMethod
        | ProtoOrigin::StdlibPublic
        | ProtoOrigin::BuiltinValue => FrameName::Named(proto.name.clone()),
        ProtoOrigin::UserLambda => FrameName::Lambda(proto.span?),
        ProtoOrigin::UserHandleBody => FrameName::Handle(proto.span?),
        ProtoOrigin::UserHandleClause => FrameName::Case {
            operation: proto
                .name
                .strip_prefix("<case ")
                .and_then(|name| name.strip_suffix('>'))
                .unwrap_or(&proto.name)
                .to_owned(),
            span: proto.span?,
        },
        ProtoOrigin::UserLazy => FrameName::Lazy(proto.span?),
        ProtoOrigin::StdlibHelper => return None,
    })
}

/// 命令の由来位置。位置なしの命令と、表にない命令は `None`。
pub fn instr_span(program: &CompiledProgram, at: InstrRef) -> Option<Span> {
    let proto = program.proto(at.proto)?;
    let pc = usize::try_from(at.pc).ok()?;
    // 位置の表だけに項目があっても、存在しない命令の位置とはしない（10-13）。
    proto.code.get(pc)?;
    proto.positions.get(pc).copied().flatten()
}

// 省く数は補助の関数を除いた後に数える（設計書 02-08「実行時エラーの情報の記録」）。
const TRACE_MAX: usize = 20;
const TRACE_KEEP: usize = 10;

fn user_span(program: &CompiledProgram, at: InstrRef) -> Option<Span> {
    let span = instr_span(program, at)?;
    (program.sources.get(span.file)?.kind() == SourceKind::User).then_some(span)
}

fn user_location(
    program: &CompiledProgram,
    at: Option<InstrRef>,
    call_sites: impl Iterator<Item = Option<InstrRef>>,
) -> Option<Span> {
    at.and_then(|at| user_span(program, at))
        .or_else(|| call_sites.flatten().find_map(|at| user_span(program, at)))
}

fn trace_name(program: &CompiledProgram, proto: ProtoIdx) -> Result<Option<FrameName>, String> {
    let origin = program
        .proto(proto)
        .ok_or("trace prototype is missing")?
        .origin;
    let name = frame_name(program, proto);
    if name.is_none() && origin != ProtoOrigin::StdlibHelper {
        return Err("trace prototype has no source span".to_owned());
    }
    Ok(name)
}

fn call_trace(program: &CompiledProgram, records: &[FrameRecord]) -> Result<CallTrace, String> {
    let mut frames = Vec::new();
    // 材料は内側から並ぶ。最も外側の枠は末尾呼び出しで置き換わっても位置を示さない。
    // 補助の関数を除く前の材料で判定し、起動の履歴の位置は保つ
    // （設計書 02-08「実行時エラーの情報の記録」、ADR 0325）。
    let outermost = records.len().saturating_sub(1);
    for (index, record) in records.iter().enumerate() {
        if let Some(name) = trace_name(program, record.proto)? {
            frames.push(TraceFrame {
                name,
                call_site: if index == outermost {
                    None
                } else {
                    record.call_site.and_then(|at| user_span(program, at))
                },
            });
        }
    }
    let omitted = frames.len().saturating_sub(TRACE_MAX);
    if omitted > 0 {
        frames.drain(TRACE_KEEP..TRACE_KEEP.saturating_add(omitted));
    }
    let omitted = u32::try_from(omitted).map_err(|_| "trace length exceeds u32")?;
    Ok(CallTrace { frames, omitted })
}

fn main_frame() -> TraceFrame {
    TraceFrame {
        name: FrameName::Named(String::from("main")),
        call_site: None,
    }
}

fn spawn_frame(program: &CompiledProgram, record: &SpawnRecord) -> Result<TraceFrame, String> {
    let name = spawn_builtin_name(program, record.spawned_at)?;
    if let Some(call_site) = user_span(program, record.spawned_at) {
        return Ok(TraceFrame {
            name: FrameName::Named(name.to_owned()),
            call_site: Some(call_site),
        });
    }
    // この枠の関数が利用者側から呼ばれた位置を選ぶ。位置を含む原型の名前ではない
    // （設計書 02-10「実行時エラーと資源の不足の報告」の Http.serve の例）。
    for frame in &record.spawner_frames {
        let name = trace_name(program, frame.proto)?;
        if let Some(call_site) = frame.call_site.and_then(|at| user_span(program, at))
            && let Some(name) = name
        {
            return Ok(TraceFrame {
                name,
                call_site: Some(call_site),
            });
        }
    }
    // 利用者の位置がない場合にも、起動した関数の名前は残す（同節の位置を持たない段）。
    Ok(TraceFrame {
        name: FrameName::Named(name.to_owned()),
        call_site: None,
    })
}

fn spawn_builtin_name(program: &CompiledProgram, at: InstrRef) -> Result<&'static str, String> {
    let proto = program
        .proto(at.proto)
        .ok_or("spawn prototype is missing")?;
    let pc = usize::try_from(at.pc).map_err(|_| "spawn pc exceeds usize")?;
    let instr = proto.code.get(pc).ok_or("spawn instruction is missing")?;
    let operands = program
        .builtin_call_operands(*instr)
        .ok_or("spawn instruction is not a builtin call")?;
    let builtin = program
        .builtin(operands.builtin)
        .ok_or("spawn builtin reference is missing")?;
    let decl = builtin_decl(builtin.id).ok_or("spawn builtin declaration is missing")?;
    Ok(decl.name)
}

fn task_origins(
    program: &CompiledProgram,
    records: &[SpawnRecord],
) -> Result<Vec<TraceFrame>, String> {
    let mut origins = records
        .iter()
        .map(|record| spawn_frame(program, record))
        .collect::<Result<Vec<_>, _>>()?;
    if !origins.is_empty() {
        origins.push(main_frame());
    }
    Ok(origins)
}

fn deadlock_diagnostic(program: &CompiledProgram, info: &StopInfo) -> Diagnostic {
    let mut report = DiagBuilder::new(DiagCode::R1001).build();
    // 行き詰まりには段のない履歴を付ける。末尾呼び出しの注記は付けない（10-13）。
    report.trace = Some(CallTrace {
        frames: Vec::new(),
        omitted: 0,
    });
    for waiter in &info.deadlock {
        let task = match waiter.spawns.first() {
            Some(record) => match spawn_frame(program, record) {
                Ok(frame) => frame,
                Err(message) => return internal_diagnostic("run", &message, None, FaultThread::Vm),
            },
            None => main_frame(),
        };
        let waits_for = match waiter.kind {
            DeadlockWaitKind::Builtin(name) => name,
            DeadlockWaitKind::Lazy => text::WAIT_LAZY,
            DeadlockWaitKind::HandleEnd => text::WAIT_HANDLE_END,
            DeadlockWaitKind::TaskGroupRelease => text::WAIT_TASK_GROUP_RELEASE,
        };
        report.waiting.push(WaitingTask {
            task,
            waits_for: waits_for.to_owned(),
            location: user_location(program, Some(waiter.at), waiter.call_sites.iter().copied()),
        });
    }
    report
}

fn resource_name(kind: ResourceKind) -> &'static str {
    match kind {
        ResourceKind::FileReader => text::RESOURCE_FILE_READER,
        ResourceKind::FileWriter => text::RESOURCE_FILE_WRITER,
        ResourceKind::HttpListener => text::RESOURCE_HTTP_LISTENER,
        ResourceKind::HttpExchange => text::RESOURCE_HTTP_EXCHANGE,
        ResourceKind::TaskGroup => text::RESOURCE_TASK_GROUP,
    }
}

fn unit_name(unit: SizeUnit) -> &'static str {
    match unit {
        SizeUnit::Bytes => text::UNIT_BYTES,
        SizeUnit::Elements => text::UNIT_ELEMENTS,
    }
}

fn release_args(
    program: &CompiledProgram,
    failure: &ReleaseFailure,
) -> [(&'static str, String); 3] {
    let location = failure
        .opened_at
        .and_then(|at| instr_span(program, at))
        .and_then(|span| {
            program.sources.get(span.file).map(|source| {
                let pos = source.line_col(span.start);
                format!("{}:{}:{}", source.name(), pos.line, pos.column)
            })
        })
        .unwrap_or_else(|| String::from(text::UNKNOWN_LOCATION));
    [
        ("resource", resource_name(failure.kind).to_owned()),
        ("location", location),
        ("reason", failure.reason.clone()),
    ]
}

fn release_builder(program: &CompiledProgram, failure: &ReleaseFailure) -> DiagBuilder {
    release_args(program, failure).into_iter().fold(
        DiagBuilder::new(DiagCode::R0401),
        |builder, (key, value)| builder.arg(key, value),
    )
}

fn release_note(program: &CompiledProgram, failure: &ReleaseFailure, key: &'static str) -> String {
    release_builder(program, failure)
        .note(key)
        .build()
        .notes
        .into_iter()
        .next()
        .unwrap_or_default()
}

fn insert_before_tail(report: &mut Diagnostic, note: String) {
    let index = report
        .notes
        .iter()
        .rposition(|note| note == codes::text::TRACE_TAIL_NOTE)
        .unwrap_or(report.notes.len());
    report.notes.insert(index, note);
}

#[cfg(test)]
// 診断の欄と順序が公開の契約である。準備と失敗の表現に添字・算術・panic を使う。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::{BytePos, FileId, Source, SourceTable};
    use crate::builtins::iface::Capability;
    use crate::bytecode::asm::ProgramBuilder;
    use crate::bytecode::instr::Opcode;
    use crate::vm::DeadlockWaiter;
    use std::sync::Arc;

    const USER: FileId = FileId(0);
    const STDLIB: FileId = FileId(1);

    fn span(file: FileId, pos: u32) -> Span {
        Span {
            file,
            start: BytePos(pos),
            end: BytePos(pos + 1),
        }
    }

    fn at(proto: u32, pc: u32) -> InstrRef {
        InstrRef {
            proto: ProtoIdx(proto),
            pc,
        }
    }
    fn frame(proto: u32, call_site: Option<InstrRef>) -> FrameRecord {
        FrameRecord {
            proto: ProtoIdx(proto),
            call_site,
        }
    }

    fn sources(builder: &mut ProgramBuilder) {
        let mut sources = SourceTable::new();
        assert_eq!(
            sources.add(Source::new(
                "main.bnt".into(),
                SourceKind::User,
                vec![b' '; 200]
            )),
            USER
        );
        assert_eq!(
            sources.add(Source::new(
                "stdlib.bnt".into(),
                SourceKind::Prelude,
                vec![b' '; 200]
            )),
            STDLIB
        );
        builder.program.sources = Arc::new(sources);
    }

    fn proto(
        builder: &mut ProgramBuilder,
        name: &str,
        origin: ProtoOrigin,
        definition: Option<Span>,
        position: Option<Span>,
    ) -> ProtoIdx {
        let index = builder.proto(name, 0, 4).unwrap();
        let code = builder.code(index).unwrap();
        code.proto.origin = origin;
        code.proto.span = definition;
        code.ret(0);
        code.proto.positions[0] = position;
        index
    }

    fn chain() -> CompiledProgram {
        let mut b = ProgramBuilder::new();
        sources(&mut b);
        let main = proto(
            &mut b,
            "main",
            ProtoOrigin::UserFn,
            None,
            Some(span(USER, 10)),
        );
        proto(
            &mut b,
            "List.map",
            ProtoOrigin::StdlibPublic,
            None,
            Some(span(STDLIB, 20)),
        );
        proto(
            &mut b,
            "mapHelper",
            ProtoOrigin::StdlibHelper,
            None,
            Some(span(STDLIB, 30)),
        );
        proto(
            &mut b,
            "<lambda>",
            ProtoOrigin::UserLambda,
            Some(span(USER, 90)),
            Some(span(USER, 40)),
        );
        b.finish(main).unwrap()
    }

    fn info(stop: Stop) -> StopInfo {
        StopInfo {
            stop,
            at: Some(at(3, 0)),
            frames: vec![
                frame(3, Some(at(2, 0))),
                frame(2, Some(at(1, 0))),
                frame(1, Some(at(0, 0))),
                frame(0, None),
            ],
            spawns: vec![],
            deadlock: vec![],
        }
    }

    fn named(name: &str, call_site: Option<Span>) -> TraceFrame {
        TraceFrame {
            name: FrameName::Named(name.into()),
            call_site,
        }
    }

    // 関門: 報告の公開の出力で、補助の段の除外と命令・呼び出しの位置の選択を守る。
    // 最小実行版ではこの表現を検査していなかった。render は位置の選択をしない。
    // 位置の繰り上げや段の名前の取り違えで失敗する。本番への差し込み口は加えない。
    #[test]
    fn trace_filters_helpers_and_selects_the_innermost_user_location() {
        let p = chain();
        let mut i = info(Stop::Runtime(RuntimeError::DivisionByZero));
        let d = stop_diagnostic(&p, &i);
        assert_eq!(d.primary.unwrap().span, span(USER, 40));
        assert_eq!(
            d.trace.unwrap(),
            CallTrace {
                frames: vec![
                    TraceFrame {
                        name: FrameName::Lambda(span(USER, 90)),
                        call_site: None
                    },
                    named("List.map", Some(span(USER, 10))),
                    named("main", None)
                ],
                omitted: 0
            }
        );
        assert!(d.task_origins.is_empty());
        assert_eq!(d.notes, [codes::text::TRACE_TAIL_NOTE]);

        i.at = Some(at(2, 0));
        i.frames.remove(0);
        assert_eq!(
            stop_diagnostic(&p, &i).primary.unwrap().span,
            span(USER, 10)
        );
        i.frames[1].call_site = Some(at(0, 99));
        assert_eq!(stop_diagnostic(&p, &i).primary, None);
        assert_eq!(instr_span(&p, at(0, 99)), None);
        assert_eq!(instr_span(&p, at(99, 0)), None);
        assert_eq!(frame_name(&p, ProtoIdx(99)), None);
    }

    // 関門: 由来の種類に応じた名前を報告の境界で確かめる。名前の分類の退行を捕まえる。
    #[test]
    fn origin_names_preserve_definitions_and_qualified_names() {
        let definition = span(USER, 90);
        let cases = [
            (
                ProtoOrigin::UserLambda,
                "<lambda>",
                FrameName::Lambda(definition),
            ),
            (
                ProtoOrigin::UserHandleBody,
                "<handle>",
                FrameName::Handle(definition),
            ),
            (
                ProtoOrigin::UserHandleClause,
                "<case Log.write>",
                FrameName::Case {
                    operation: "Log.write".into(),
                    span: definition,
                },
            ),
            (ProtoOrigin::UserLazy, "<lazy>", FrameName::Lazy(definition)),
            (
                ProtoOrigin::BuiltinValue,
                "Console.writeLine",
                FrameName::Named("Console.writeLine".into()),
            ),
            (
                ProtoOrigin::UserMethod,
                "Show[Person].show",
                FrameName::Named("Show[Person].show".into()),
            ),
        ];
        for (origin, name, expected) in cases {
            let mut b = ProgramBuilder::new();
            sources(&mut b);
            let main = proto(&mut b, name, origin, Some(definition), None);
            let p = b.finish(main).unwrap();
            let mut i = info(Stop::Runtime(RuntimeError::IntegerOverflow));
            i.at = Some(at(0, 0));
            i.frames = vec![frame(0, None)];
            let d = stop_diagnostic(&p, &i);
            assert_eq!(
                d.trace.unwrap().frames,
                [TraceFrame {
                    name: expected,
                    call_site: None
                }]
            );
            assert_eq!(d.primary, None);
        }
    }

    // 関門: 補助を含む長い履歴で、除外後の長さ・境界・省略数を守る。
    #[test]
    fn trace_truncates_after_filtering_helpers() {
        let mut b = ProgramBuilder::new();
        sources(&mut b);
        for index in 0..25 {
            proto(
                &mut b,
                &format!("f{index}"),
                ProtoOrigin::UserFn,
                None,
                None,
            );
        }
        proto(&mut b, "helper", ProtoOrigin::StdlibHelper, None, None);
        let p = b.finish(ProtoIdx(0)).unwrap();
        for length in [20, 25] {
            let mut i = info(Stop::Resource(ResourceError::CallStackTooDeep {
                frames: 26,
            }));
            i.at = None;
            i.frames = (0..length)
                .flat_map(|index| [frame(index, None), frame(25, None)])
                .collect();
            let d = stop_diagnostic(&p, &i);
            let expected = if length == 25 {
                (0..10).chain(15..25).collect::<Vec<_>>()
            } else {
                (0..20).collect()
            };
            assert_eq!(
                d.trace.unwrap(),
                CallTrace {
                    frames: expected
                        .into_iter()
                        .map(|index| named(&format!("f{index}"), None))
                        .collect(),
                    omitted: length - 20
                }
            );
            assert_eq!(
                d.notes,
                ["26 calls were active", codes::text::TRACE_TAIL_NOTE]
            );
            assert_eq!(
                d.helps[0].message,
                "use tail calls, or raise the limit with `--max-call-stack`"
            );
        }
    }

    fn spawn_program() -> CompiledProgram {
        let mut b = ProgramBuilder::new();
        sources(&mut b);
        let main = b.proto("main", 0, 4).unwrap();
        let spawn = b
            .named_builtin("TaskGroup.spawn", 2, Capability::State, None)
            .unwrap();
        let all = b
            .named_builtin("Task.all", 1, Capability::State, None)
            .unwrap();
        let code = b.code(main).unwrap();
        code.op(Opcode::Prim, 0, u16::try_from(spawn.0).unwrap(), 1);
        code.op(Opcode::Prim, 0, u16::try_from(all.0).unwrap(), 1);
        code.ret(0);
        code.proto.positions = vec![
            Some(span(USER, 10)),
            Some(span(USER, 12)),
            Some(span(USER, 14)),
        ];
        let public = b.proto("Http.serve", 0, 4).unwrap();
        let code = b.code(public).unwrap();
        code.proto.origin = ProtoOrigin::StdlibPublic;
        code.op(Opcode::Prim, 0, u16::try_from(spawn.0).unwrap(), 1);
        code.ret(0);
        code.proto.positions = vec![Some(span(STDLIB, 20)), None];
        proto(
            &mut b,
            "helper",
            ProtoOrigin::StdlibHelper,
            None,
            Some(span(STDLIB, 30)),
        );
        b.finish(main).unwrap()
    }

    fn spawn(spawned_at: InstrRef, spawner_frames: Vec<FrameRecord>) -> SpawnRecord {
        SpawnRecord {
            spawned_at,
            spawner_frames,
        }
    }

    // 関門: 起動した命令の関数の名前、利用者側の呼び出しへの繰り上げ、main の付加を守る。
    #[test]
    fn task_origins_use_spawned_builtins_and_promote_stdlib_calls() {
        let p = spawn_program();
        let mut i = info(Stop::Runtime(RuntimeError::DivisionByZero));
        i.at = Some(at(0, 0));
        i.frames = vec![frame(0, None)];
        i.spawns = vec![
            spawn(at(0, 0), vec![frame(0, None)]),
            spawn(at(0, 1), vec![frame(0, None)]),
        ];
        assert_eq!(
            stop_diagnostic(&p, &i).task_origins,
            [
                named("TaskGroup.spawn", Some(span(USER, 10))),
                named("Task.all", Some(span(USER, 12))),
                named("main", None)
            ]
        );
        i.spawns = vec![spawn(
            at(1, 0),
            vec![
                frame(2, Some(at(1, 0))),
                frame(1, Some(at(0, 1))),
                frame(0, None),
            ],
        )];
        assert_eq!(
            stop_diagnostic(&p, &i).task_origins,
            [
                named("Http.serve", Some(span(USER, 12))),
                named("main", None)
            ]
        );
        i.spawns[0].spawner_frames = vec![frame(1, None)];
        assert_eq!(
            stop_diagnostic(&p, &i).task_origins,
            [named("TaskGroup.spawn", None), named("main", None)]
        );
        i.spawns.clear();
        assert!(stop_diagnostic(&p, &i).task_origins.is_empty());
    }

    // 関門: 行き詰まり固有の待つタスクの順序、種類、位置を守る。一般の履歴では検出できない。
    #[test]
    fn deadlock_lists_waiters_in_record_order_without_a_primary_or_call_frames() {
        let p = spawn_program();
        let mut i = info(Stop::Runtime(RuntimeError::TaskDeadlock));
        i.deadlock = vec![
            DeadlockWaiter {
                kind: DeadlockWaitKind::TaskGroupRelease,
                at: at(0, 2),
                call_sites: vec![],
                spawns: vec![],
            },
            DeadlockWaiter {
                kind: DeadlockWaitKind::Builtin("Task.await"),
                at: at(1, 0),
                call_sites: vec![Some(at(2, 0)), Some(at(0, 0))],
                spawns: vec![spawn(at(0, 0), vec![])],
            },
            DeadlockWaiter {
                kind: DeadlockWaitKind::Builtin("Task.await"),
                at: at(0, 1),
                call_sites: vec![],
                spawns: vec![spawn(at(0, 1), vec![])],
            },
        ];
        let d = stop_diagnostic(&p, &i);
        assert_eq!(d.code, Some(DiagCode::R1001));
        assert_eq!(d.primary, None);
        assert_eq!(
            d.trace,
            Some(CallTrace {
                frames: vec![],
                omitted: 0
            })
        );
        assert!(d.task_origins.is_empty());
        assert!(d.notes.is_empty());
        assert_eq!(
            d.waiting,
            [
                WaitingTask {
                    task: named("main", None),
                    waits_for: "TaskGroup release".into(),
                    location: Some(span(USER, 14))
                },
                WaitingTask {
                    task: named("TaskGroup.spawn", Some(span(USER, 10))),
                    waits_for: "Task.await".into(),
                    location: Some(span(USER, 10))
                },
                WaitingTask {
                    task: named("Task.all", Some(span(USER, 12))),
                    waits_for: "Task.await".into(),
                    location: Some(span(USER, 12))
                },
            ]
        );
        for (kind, expected) in [
            (DeadlockWaitKind::Lazy, "Lazy evaluation"),
            (DeadlockWaitKind::HandleEnd, "handle end"),
        ] {
            i.deadlock = vec![DeadlockWaiter {
                kind,
                at: at(1, 1),
                call_sites: vec![None, Some(at(2, 0))],
                spawns: vec![],
            }];
            let d = stop_diagnostic(&p, &i);
            assert_eq!(d.waiting[0].waits_for, expected);
            assert_eq!(d.waiting[0].location, None);
        }
    }

    // 関門: Stop からコードへの対応と型板の値の変換を、一つの表で確かめる。
    // コードの表そのものを写すテストではなく、誤った分岐・引数の基点・単位を捕まえる。
    #[test]
    fn stops_choose_codes_and_fill_arguments() {
        let p = chain();
        let cases = [
            (
                Stop::Runtime(RuntimeError::DivisionByZero),
                DiagCode::R0101,
                "division by zero",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::IntegerOverflow),
                DiagCode::R0102,
                "integer overflow",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::DecimalOverflow),
                DiagCode::R0103,
                "Decimal overflow",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::ReleasedResourceUsed {
                    kind: ResourceKind::FileWriter,
                }),
                DiagCode::R0402,
                "`File.Writer` is used after it was released",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::ContinuationResumedTwice),
                DiagCode::R0501,
                "`resume` was called twice in one clause",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::InheritedHandlerClause {
                    operation: "Log.write".into(),
                }),
                DiagCode::R0502,
                "the handler for `Log.write` cannot be used in a task",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                    function: "Decimal.round",
                    argument: 1,
                }),
                DiagCode::R0701,
                "argument 2 of `Decimal.round` is out of range",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                    function: "Process.exit",
                    argument: 0,
                }),
                DiagCode::R0701,
                "argument 1 of `Process.exit` is out of range",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::ResponseSentTwice),
                DiagCode::R0801,
                "a response was already sent for this request",
                vec![],
            ),
            (
                Stop::Runtime(RuntimeError::AwaitedTaskCancelled),
                DiagCode::R1002,
                "the awaited task was cancelled, so it has no result",
                vec![],
            ),
            (
                Stop::Resource(ResourceError::CallStackTooDeep { frames: 42 }),
                DiagCode::R0901,
                "the call stack is too deep",
                vec!["42 calls were active"],
            ),
            (
                Stop::Resource(ResourceError::ValueTooLarge {
                    function: "String.repeat",
                    size: 7,
                    unit: SizeUnit::Bytes,
                    limit: 6,
                }),
                DiagCode::R0902,
                "`String.repeat` would create a value that is too large",
                vec!["the result would have 7 bytes; the limit is 6"],
            ),
            (
                Stop::Resource(ResourceError::ValueTooLarge {
                    function: "List.repeat",
                    size: 9,
                    unit: SizeUnit::Elements,
                    limit: 8,
                }),
                DiagCode::R0902,
                "`List.repeat` would create a value that is too large",
                vec!["the result would have 9 elements; the limit is 8"],
            ),
            (
                Stop::Resource(ResourceError::InputTooLarge {
                    function: "File.readText",
                    unit: SizeUnit::Bytes,
                    limit: 100,
                }),
                DiagCode::R0903,
                "`File.readText` read more than the limit of 100 bytes",
                vec![],
            ),
            (
                Stop::Resource(ResourceError::InputTooLarge {
                    function: "input",
                    unit: SizeUnit::Elements,
                    limit: 50,
                }),
                DiagCode::R0903,
                "`input` read more than the limit of 50 elements",
                vec![],
            ),
        ];
        for (stop, code, message, mut notes) in cases {
            let d = stop_diagnostic(&p, &info(stop));
            assert_eq!(d.code, Some(code));
            assert_eq!(d.message, message);
            assert_eq!(
                d.kind,
                if matches!(code, DiagCode::R0901 | DiagCode::R0902 | DiagCode::R0903) {
                    ReportKind::Resource
                } else {
                    ReportKind::Runtime
                }
            );
            notes.push(codes::text::TRACE_TAIL_NOTE);
            assert_eq!(d.notes, notes);
            assert_eq!(d.primary.unwrap().span, span(USER, 40));
            assert!(d.trace.is_some());
            if code == DiagCode::R0502 {
                assert_eq!(
                    d.helps[0].message,
                    "a handler inherited by a task must end its clause with `resume`"
                );
            }
        }
    }

    // 関門: 解放の失敗の集約、停止中の注記の順序、終了と中断での報告の種類を守る。
    #[test]
    fn release_failures_preserve_all_reasons_and_the_stop_cause() {
        let p = chain();
        let failures = vec![
            ReleaseFailure {
                kind: ResourceKind::FileWriter,
                opened_at: Some(at(0, 0)),
                reason: "disk full".into(),
            },
            ReleaseFailure {
                kind: ResourceKind::HttpListener,
                opened_at: Some(at(0, 99)),
                reason: "close failed".into(),
            },
        ];
        let mut d = stop_diagnostic(
            &p,
            &info(Stop::Runtime(RuntimeError::ReleaseFailed(failures.clone()))),
        );
        assert_eq!(d.code, Some(DiagCode::R0401));
        assert_eq!(
            d.message,
            "failed to release `File.Writer` opened at main.bnt:1:11"
        );
        assert_eq!(d.primary.as_ref().unwrap().text, "released here");
        assert_eq!(
            d.notes,
            [
                "failed to release `File.Writer` opened at main.bnt:1:11: disk full",
                "failed to release `Http.Listener` opened at <unknown>: close failed",
                codes::text::TRACE_TAIL_NOTE
            ]
        );
        add_release_failures(&mut d, &p, &failures);
        assert_eq!(
            &d.notes[2..],
            [
                "while stopping, failed to release `File.Writer` opened at main.bnt:1:11: disk full",
                "while stopping, failed to release `Http.Listener` opened at <unknown>: close failed",
                codes::text::TRACE_TAIL_NOTE
            ]
        );
        for (cause, expected) in [
            (
                ReleaseCause::Exit(2),
                "the program was exiting by `Process.exit(2)`; the exit status is not changed",
            ),
            (
                ReleaseCause::Interrupted,
                codes::text::RELEASE_INTERRUPT_NOTE,
            ),
        ] {
            let d = release_report(&p, &failures[0], cause);
            assert_eq!(d.code, Some(DiagCode::R0401));
            assert_eq!(d.kind, ReportKind::Release);
            assert_eq!(d.notes, ["disk full", expected]);
            assert_eq!(d.primary, None);
            assert_eq!(d.trace, None);
            assert!(d.task_origins.is_empty());
        }
        for (kind, expected) in [
            (ResourceKind::FileReader, "File.Reader"),
            (ResourceKind::HttpExchange, "Http.Exchange"),
            (ResourceKind::TaskGroup, "TaskGroup"),
        ] {
            let d = stop_diagnostic(
                &p,
                &info(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind })),
            );
            assert_eq!(
                d.message,
                format!("`{expected}` is used after it was released")
            );
        }
        let failure = ReleaseFailure {
            kind: ResourceKind::FileReader,
            opened_at: None,
            reason: "failure".into(),
        };
        assert_eq!(
            release_report(&p, &failure, ReleaseCause::Interrupted).message,
            "failed to release `File.Reader` opened at <unknown>"
        );
    }

    // 関門: 検出時点の枠を誤って書き込みの原因として示さないことと、追加の注記の順序を守る。
    #[test]
    fn write_failures_have_no_location_and_flush_notes_precede_the_trace_tail() {
        let p = chain();
        for (stream, code, message, flush) in [
            (
                Stream::Stdout,
                DiagCode::R0201,
                "failed to write to standard output",
                "also failed to write to standard output: broken pipe",
            ),
            (
                Stream::Stderr,
                DiagCode::R0202,
                "failed to write to standard error",
                "also failed to write to standard error: broken pipe",
            ),
        ] {
            let mut d = stop_diagnostic(
                &p,
                &info(Stop::Runtime(RuntimeError::WriteFailed {
                    stream,
                    reason: "broken pipe".into(),
                })),
            );
            assert_eq!(d, write_failed(stream, "broken pipe"));
            assert_eq!(d.code, Some(code));
            assert_eq!(d.message, message);
            assert_eq!(d.kind, ReportKind::Runtime);
            assert_eq!(d.primary, None);
            assert_eq!(d.trace, None);
            assert!(d.task_origins.is_empty());
            assert_eq!(d.notes, ["broken pipe"]);
            add_flush_failure(&mut d, stream, "broken pipe");
            assert_eq!(d.notes, ["broken pipe", flush]);
            let mut d = stop_diagnostic(
                &p,
                &info(Stop::Resource(ResourceError::CallStackTooDeep {
                    frames: 25,
                })),
            );
            add_flush_failure(&mut d, stream, "broken pipe");
            assert_eq!(
                d.notes,
                ["25 calls were active", flush, codes::text::TRACE_TAIL_NOTE]
            );
        }
    }

    // 関門: 不具合の説明・panic の内容・スレッドと注記の順序を公開の報告で守る。
    #[test]
    fn internal_reports_order_notes_and_preserve_panic_details() {
        for (thread, name) in [
            (FaultThread::Stage, "compiler"),
            (FaultThread::Vm, "VM"),
            (FaultThread::Worker, "worker"),
            (FaultThread::Writer, "output writer"),
        ] {
            for location in [Some("src/x.rs:1:2".to_owned()), None] {
                let panic = PanicReport {
                    message: "boom".into(),
                    location: location.clone(),
                    backtrace: Some("bt".into()),
                };
                let d = internal_diagnostic("run", "bad register", Some(&panic), thread);
                assert_eq!(d.kind, ReportKind::Internal);
                assert_eq!(d.code, None);
                assert_eq!(d.message, codes::text::INTERNAL_MESSAGE);
                assert_eq!(
                    d.notes,
                    [
                        format!("benitoite {}", env!("CARGO_PKG_VERSION")),
                        "the error occurred in the run stage".into(),
                        format!("the panic occurred in the {name} thread"),
                        "bad register".into(),
                        format!(
                            "panic: boom at {}",
                            location.as_deref().unwrap_or("<unknown>")
                        ),
                        codes::text::INTERNAL_REPORT.into()
                    ]
                );
                assert_eq!(d.backtrace.as_deref(), Some("bt"));
                assert_eq!(d.primary, None);
                assert_eq!(d.trace, None);
            }
        }
        let d = internal_diagnostic("check", "", None, FaultThread::Stage);
        assert_eq!(d.notes.len(), 4);
        assert_eq!(d.backtrace, None);
        let p = chain();
        assert_eq!(
            stop_diagnostic(&p, &info(Stop::Internal("bad register".into()))),
            internal_diagnostic("run", "bad register", None, FaultThread::Vm)
        );
    }

    // 関門: 壊れた記録を黙って省かず、不具合の報告へ変える。panic 境界に頼らない。
    #[test]
    fn invalid_report_records_become_internal_diagnostics() {
        let mut p = chain();
        let mut i = info(Stop::Runtime(RuntimeError::DivisionByZero));
        i.frames[0].proto = ProtoIdx(99);
        assert_eq!(stop_diagnostic(&p, &i).kind, ReportKind::Internal);
        i = info(Stop::Runtime(RuntimeError::DivisionByZero));
        p.protos[3].span = None;
        assert_eq!(stop_diagnostic(&p, &i).kind, ReportKind::Internal);
        i = info(Stop::Runtime(RuntimeError::ReleaseFailed(vec![])));
        assert_eq!(stop_diagnostic(&p, &i).kind, ReportKind::Internal);
        let p = spawn_program();
        i = info(Stop::Runtime(RuntimeError::DivisionByZero));
        i.frames = vec![frame(0, None)];
        i.spawns = vec![spawn(at(0, 99), vec![])];
        assert_eq!(stop_diagnostic(&p, &i).kind, ReportKind::Internal);
    }
}

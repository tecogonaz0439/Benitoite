//! VM と参照インタプリタの比較（設計書 07-03「差分テスト」「コア IR の検査」）。
//! ランダムなプログラムのテストからも使うため、ゴールデンテストのファイルの形式には依存しない。

// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use std::ffi::OsString;
use std::path::Path;
use std::sync::{Arc, Mutex};

use benitoite::base::{SourceKind, SourceTable, Span};
use benitoite::builtins::iface::{IoServices, IoWait, OsResource};
use benitoite::diag::ReportKind;
use benitoite::pipeline::{self, CheckedProgram, CompileError};
use benitoite::refinterp::{self, RefOutcome};
use benitoite::runtime::heap::{HeapConfig, ResourceId};
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::{ResourceKind, Stop, Stream};
use benitoite::vm::{ExecMode, InstrRef, MainOutcome, StopInfo, VmConfig};

/// 検査の成功、失敗の説明、比較から外した理由。失敗はコア IR と差分比較を区別する。
#[derive(Debug)]
pub enum Comparison {
    Matched,
    Failed(String),
    Excluded(String),
}

/// 比較から外してよい制限と、正常終了を求めるかの指定。
#[derive(Default)]
pub struct CompareOptions {
    pub expected_limit: bool,
    pub require_returned: bool,
}

/// 型検査済みのプログラムを脱糖・検査し、VM と参照インタプリタの出力と終わり方を比べる。
/// 深い IR の検査と破棄も CLI の段と同じスタックで行う。
pub fn compare(
    checked: CheckedProgram,
    sources: Arc<SourceTable>,
    input: RunInput,
    config: VmConfig,
    mode: ExecMode,
    options: CompareOptions,
    prepare_reference: Box<dyn FnOnce() -> Result<(), String> + Send>,
) -> Comparison {
    let thread = std::thread::Builder::new()
        .name("golden-differential".into())
        .stack_size(pipeline::STAGE_STACK_BYTES)
        .spawn(move || {
            compare_on_stage(
                checked,
                sources,
                input,
                config,
                mode,
                options,
                prepare_reference,
            )
        });
    match thread {
        Ok(thread) => match thread.join() {
            Ok(result) => result,
            Err(_) => Comparison::Failed("differential test: stage thread panicked".into()),
        },
        Err(error) => Comparison::Failed(format!("differential test: cannot start stage: {error}")),
    }
}

fn compare_on_stage(
    checked: CheckedProgram,
    sources: Arc<SourceTable>,
    input: RunInput,
    config: VmConfig,
    mode: ExecMode,
    options: CompareOptions,
    prepare_reference: Box<dyn FnOnce() -> Result<(), String> + Send>,
) -> Comparison {
    let core = match pipeline::desugar_checked(&checked) {
        Ok(core) => core,
        Err(error) => return Comparison::Failed(format!("desugaring failed: {error:?}")),
    };
    let errors = benitoite::ir::check::check_program(&core);
    if !errors.is_empty() {
        return Comparison::Failed(format!("core IR check failed: {errors:?}"));
    }
    let program = match pipeline::compile(&core, Arc::clone(&sources)) {
        Ok(program) => program,
        // 処理系の制限は抽象機械の規則にない。実行時の資源の上限と同じく比較から外す。
        Err(CompileError::Limit(_)) if options.expected_limit => {
            return Comparison::Excluded("implementation limit".into());
        }
        Err(CompileError::Limit(diags)) => {
            return Comparison::Failed(format!("unexpected implementation limit: {diags:?}"));
        }
        Err(CompileError::Internal(error)) => {
            return Comparison::Failed(format!("compilation failed: {error:?}"));
        }
    };
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let vm = run::run_program(
        &program,
        RunEnv {
            input: input.clone(),
            stdin: StdinSource::Empty,
            stdout: OutputTarget::Capture(Arc::clone(&stdout)),
            stderr: OutputTarget::Capture(Arc::clone(&stderr)),
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode,
            vm: config,
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        },
    );
    if options.require_returned && vm.end != EndKind::Returned {
        return Comparison::Failed(format!(
            "benchmark did not return normally: VM {:?}/{:?}, reports {:?}",
            vm.end, vm.main_error, vm.reports
        ));
    }
    if vm.end == EndKind::Internal {
        return Comparison::Failed(format!(
            "differential test failed: VM internal error: {:?}",
            vm.reports
        ));
    }
    // 資源の上限は抽象機械の規則にない。深い再帰を参照側で走らせる前に外す（設計書 07-03「差分テスト」）。
    if vm.reports.iter().any(|d| d.kind == ReportKind::Resource) {
        return Comparison::Excluded("resource exhaustion".into());
    }
    if let Err(error) = prepare_reference() {
        return Comparison::Failed(format!("reference preparation failed: {error}"));
    }
    let (reference, ref_stdout, ref_stderr) = run_reference(&core, input);
    compare_results(
        &program,
        &sources,
        &vm,
        (&stdout.lock().unwrap(), &stderr.lock().unwrap()),
        reference,
        (&ref_stdout, &ref_stderr),
    )
}

/// 既存の独立参照評価と固定 IO の準備を、実行境界の検査から共有する。
pub fn run_reference(
    core: &benitoite::ir::core_ir::CoreProgram,
    input: RunInput,
) -> (RefOutcome, Vec<u8>, Vec<u8>) {
    let mut io = ReferenceIo {
        input,
        stdout: Vec::new(),
        stderr: Vec::new(),
    };
    let outcome = refinterp::run(core, &mut io);
    (outcome, io.stdout, io.stderr)
}

/// 実行結果の比較。ランダムなプログラムの検出力の検査でも同じ判定を使う。
pub fn compare_results(
    program: &benitoite::bytecode::program::CompiledProgram,
    sources: &SourceTable,
    vm: &run::RunEnd,
    vm_output: (&[u8], &[u8]),
    reference: RefOutcome,
    ref_output: (&[u8], &[u8]),
) -> Comparison {
    match &reference {
        RefOutcome::Unsupported(_) => return Comparison::Excluded("unsupported builtin".into()),
        RefOutcome::Stopped {
            stop: Stop::Resource(_),
            ..
        } => {
            return Comparison::Excluded("resource exhaustion".into());
        }
        RefOutcome::Stopped {
            stop: Stop::Internal(message),
            ..
        } => {
            return Comparison::Failed(format!(
                "differential test failed: reference internal error: {message}"
            ));
        }
        RefOutcome::Finished(_) | RefOutcome::Stopped { .. } | RefOutcome::Exited { .. } => {}
    }
    let mut differences = Vec::new();
    for (name, vm_bytes, ref_bytes) in [
        ("stdout", vm_output.0, ref_output.0),
        ("stderr", vm_output.1, ref_output.1),
    ] {
        if vm_bytes != ref_bytes {
            differences.push(format!("{name}: VM {vm_bytes:?}, reference {ref_bytes:?}"));
        }
    }
    let ref_die = if let RefOutcome::Exited { die_failure, .. } = &reference {
        die_failure.as_ref()
    } else {
        None
    };
    if vm.die_failure.as_ref() != ref_die {
        differences.push(format!(
            "exit report: VM {:?}, reference {ref_die:?}",
            vm.die_failure
        ));
    }
    let (ref_end, ref_error, ref_origin) = match reference {
        RefOutcome::Finished(MainOutcome::Ok) => (EndKind::Returned, None, None),
        RefOutcome::Finished(MainOutcome::Error(message)) => {
            (EndKind::MainError, Some(message), None)
        }
        RefOutcome::Exited { status, .. } => (EndKind::Exited(status), None, None),
        RefOutcome::Stopped { stop, origin, .. } => {
            let internal = matches!(stop, Stop::Internal(_));
            let expected = benitoite::runtime::report::stop_diagnostic(
                program,
                &StopInfo {
                    stop,
                    at: None,
                    frames: vec![],
                    spawns: vec![],
                    deadlock: vec![],
                },
            );
            match vm.reports.first() {
                Some(actual)
                    if actual.code == expected.code && actual.message == expected.message => {}
                actual => differences.push(format!(
                    "stop kind/message: VM {actual:?}, reference {expected:?}"
                )),
            }
            (
                if internal {
                    EndKind::Internal
                } else {
                    EndKind::Stopped
                },
                None,
                origin,
            )
        }
        // 外す条件は比較の前に処理済みである。
        RefOutcome::Unsupported(_) => return Comparison::Excluded("unsupported builtin".into()),
    };
    if vm.end != ref_end || vm.main_error != ref_error {
        differences.push(format!(
            "end: VM {:?}/{:?}, reference {ref_end:?}/{ref_error:?}",
            vm.end, vm.main_error
        ));
    }
    let vm_origin = vm
        .reports
        .first()
        .and_then(|d| d.primary.as_ref())
        .map(|l| l.span);
    if let (Some(vm_at), Some(ref_at)) = (
        user_span(vm_origin, sources),
        user_span(ref_origin, sources),
    ) && vm_at != ref_at
    {
        differences.push(format!("stop position: VM {vm_at:?}, reference {ref_at:?}"));
    }
    if differences.is_empty() {
        Comparison::Matched
    } else {
        Comparison::Failed(format!(
            "differential test failed: {}",
            differences.join("; ")
        ))
    }
}

fn user_span(span: Option<Span>, sources: &SourceTable) -> Option<Span> {
    span.filter(|s| {
        sources
            .get(s.file)
            .is_some_and(|source| source.kind() == SourceKind::User)
    })
}

// 外部の入力と出力だけを置き換える。値・評価・組み込みの本体は本物を使う（設計書 02-08「参照インタプリタ」）。
struct ReferenceIo {
    input: RunInput,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}
impl IoServices for ReferenceIo {
    fn write_output(&mut self, stream: Stream, text: &str) -> Result<Option<IoWait>, Stop> {
        match stream {
            Stream::Stdout => &mut self.stdout,
            Stream::Stderr => &mut self.stderr,
        }
        .extend_from_slice(text.as_bytes());
        Ok(None)
    }
    fn arguments(&self) -> &[String] {
        &self.input.arguments
    }
    fn script_directory(&self) -> &Path {
        &self.input.script_directory
    }
    fn working_directory(&self) -> &Path {
        &self.input.working_directory
    }
    fn environment_variable(&self, _name: &str) -> Option<OsString> {
        None
    }
    // 時計と乱数を使うケースは呼ぶ側が名前の一覧で外す。
    fn now_millis(&self) -> i64 {
        0
    }
    fn local_offset_minutes(&self) -> i32 {
        0
    }
    fn monotonic_millis(&self) -> i64 {
        0
    }
    fn random_u64(&mut self) -> u64 {
        0
    }
    fn register_resource(
        &mut self,
        _kind: ResourceKind,
        _handle: Box<dyn OsResource>,
        _at: Option<InstrRef>,
    ) -> ResourceId {
        panic!("reference interpreter must register resources in its own resource table")
    }
}

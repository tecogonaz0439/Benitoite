//! R29 の組み込みの関数を、部品を渡す公開の実行経路で確かめる。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::arithmetic_side_effects
)]
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::ops::{Completion, JobWork, LentOwned, Outcome, WorkerJob};
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{IdleWake, WorkerExec};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::collections::VecDeque;
use std::sync::{Arc, Mutex, mpsc};

fn compile(source: &str) -> benitoite::bytecode::program::CompiledProgram {
    let checked = pipeline::check_text(
        "runtime-builtins.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}
fn environment(mode: ExecMode, output: Arc<Mutex<Vec<u8>>>) -> RunEnv {
    RunEnv {
        input: RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        stdin: StdinSource::Bytes(b"Ada\n".to_vec()),
        stdout: OutputTarget::Capture(output),
        stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
        interrupt: Box::new(NoInterrupt),
        parts: None,
        mode,
        vm: VmConfig::default(),
        heap: HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
        dev_panic_after_first_write: false,
    }
}
// ScriptWorkers の起こし口と出力の待ちをそのまま使い、単一の標準入力の仕事を同期で行う。
// 出力先のロックを idle まで保ち、偶然 writer が先に終わる場合を除く（実装プラン R29）。
#[derive(Debug)]
struct InlineWorkers {
    waiting: Box<dyn WorkerExec>,
    done: VecDeque<Completion>,
    prompt: Option<PromptGate>,
}
#[derive(Debug)]
struct PromptGate {
    output: Arc<Mutex<Vec<u8>>>,
    release_output: mpsc::Sender<()>,
    observations: Arc<Mutex<(bool, usize)>>,
}
impl WorkerExec for InlineWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.waiting.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        if let Some(prompt) = &self.prompt {
            assert!(
                prompt.observations.lock().unwrap().0,
                "stdin began before the output wait"
            );
            assert_eq!(
                *prompt.output.try_lock().expect("output still transferring"),
                b"Name: "
            );
            assert!(matches!(job.lent, LentOwned::Stdin(_)));
            prompt.observations.lock().unwrap().1 = 1;
        }
        let JobWork::Builtin(work) = job.work else {
            panic!("expected builtin work")
        };
        let mut lent = job.lent;
        use benitoite::builtins::iface::Lent;
        let done = work.run(match &mut lent {
            LentOwned::Nothing => Lent::Nothing,
            LentOwned::Resource(_, reader) => Lent::Resource(reader.as_mut()),
            LentOwned::Stdin(reader) => Lent::Stdin(reader.as_mut()),
        });
        self.done.push_back(Completion {
            op: job.op,
            outcome: Outcome::Worker(done),
            returned: lent,
        });
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.done.pop_front().or_else(|| self.waiting.try_recv())
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        if !self.done.is_empty() {
            return IdleWake::Progress;
        }
        if let Some(prompt) = &self.prompt {
            prompt.observations.lock().unwrap().0 = true;
            let _released = prompt.release_output.send(());
        }
        self.waiting.idle(deadline)
    }
}
// 関門: 公開の RunEnv::parts が R27 の WorkerExec::wakeup を出力へ渡す契約。
// 本体や VM のテストでは run_program の部品の配線を通らない。
#[test]
fn injected_parts_wait_for_output_before_reading_stdin() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Console.Write,Console.Read
 Console.write("Name: ")
 bind name <- try Console.readLine() |> Result.mapError(_,IOError.message)
 return if name = Option.Some("Ada") then Result.Ok(()) else Result.Error("unexpected input") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let held = Arc::clone(&output);
        let (release, receive) = mpsc::channel();
        let (ready, initialized) = mpsc::channel();
        let gate = std::thread::spawn(move || {
            let guard = held.lock().unwrap();
            ready.send(()).unwrap();
            receive.recv().unwrap();
            drop(guard);
        });
        initialized.recv().unwrap();
        let script = ScheduleHandle::new([], false);
        let mut parts = script.parts();
        let observations = Arc::new(Mutex::new((false, 0)));
        parts.workers = Box::new(InlineWorkers {
            waiting: parts.workers,
            done: VecDeque::new(),
            prompt: Some(PromptGate {
                output: Arc::clone(&output),
                release_output: release.clone(),
                observations: Arc::clone(&observations),
            }),
        });
        let mut env = environment(mode, Arc::clone(&output));
        env.parts = Some(parts);
        let end = run::run_program(&program, env);
        let _released = release.send(());
        gate.join().unwrap();
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0);
        assert!(end.reports.is_empty());
        assert!(end.main_error.is_none());
        assert_eq!(*output.lock().unwrap(), b"Name: ");
        assert_eq!(*observations.lock().unwrap(), (true, 1));
        assert!(script.record().error.is_none(), "{:?}", script.record());
    }
}
// 関門: Exit の VM の応答だけでは、公開の終了結果と終了状態の変換を確かめられない。
// 資源の解放の回数は file のプログラムのテストに任せ、この境界では出力と終了結果を確かめる。
#[test]
fn process_exit_finishes_output_and_returns_the_requested_status() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.File
function main() -> Result[Unit,String] uses File.Read,State,Console.Write,Process.Exit
 with reader = try File.openReader("Cargo.toml") |> Result.mapError(_,IOError.message) do
  bind _ <- try File.readLine(reader) |> Result.mapError(_,IOError.message)
  Console.write("before exit")
  Process.exit(3)
  Console.write("after exit")
  return Result.Ok(())
 end with
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let script = ScheduleHandle::new([], false);
        let mut env = environment(mode, Arc::clone(&output));
        env.input.working_directory = env!("CARGO_MANIFEST_DIR").into();
        let mut parts = script.parts();
        parts.workers = Box::new(InlineWorkers {
            waiting: parts.workers,
            done: VecDeque::new(),
            prompt: None,
        });
        env.parts = Some(parts);
        let end = run::run_program(&program, env);
        assert_eq!(end.end, EndKind::Exited(3), "{end:?}");
        assert_eq!(end.exit_code, 3);
        assert!(end.reports.is_empty());
        assert_eq!(*output.lock().unwrap(), b"before exit");
        assert!(script.record().error.is_none());
    }
}

// 関門: L00 の八つのソース関数が、鍵順に一度ずつ関数を呼び、その結果を使う契約。
// 本体の単体テストはソースの脱糖や State の伝播を通らない。実行の公開の境界を使い、
// Reference の観察結果と返り値を確かめる（設計書 03-06「関数を引数にとる関数の共通の規則」）。
#[test]
fn map_and_set_source_functions_call_in_key_order_once_and_use_the_results() {
    let cases = [
        (
            "Map.map",
            "Map.map(m, lambda(k, v) record_visit(log, k * 100 + v)\nreturn k + v end lambda)",
            "Map.toList(result) = mapped",
        ),
        (
            "Map.filter",
            "Map.filter(m, lambda(k, v) record_visit(log, k * 100 + v)\nreturn k <> 2 end lambda)",
            "Map.toList(result) = filteredMap",
        ),
        (
            "Map.fold",
            "Map.fold(m, 7, lambda(acc, k, v) record_visit(log, k * 100 + v)\nreturn acc + k + v end lambda)",
            "result = foldedMap",
        ),
        (
            "Map.forEach",
            "Map.forEach(m, lambda(k, v) return record_visit(log, k * 100 + v) end lambda)",
            "result = ()",
        ),
        (
            "Set.map",
            "Set.map(s, lambda(k) record_visit(log, k * 110)\nreturn 1 end lambda)",
            "Set.toList(result) = mappedSet",
        ),
        (
            "Set.filter",
            "Set.filter(s, lambda(k) record_visit(log, k * 110)\nreturn k <> 2 end lambda)",
            "Set.toList(result) = filteredSet",
        ),
        (
            "Set.fold",
            "Set.fold(s, 7, lambda(acc, k) record_visit(log, k * 110)\nreturn acc * 10 + k end lambda)",
            "result = foldedSet",
        ),
        (
            "Set.forEach",
            "Set.forEach(s, lambda(k) return record_visit(log, k * 110) end lambda)",
            "result = ()",
        ),
    ];
    for count in [0, 1, 3] {
        let pairs = (1..=count)
            .rev()
            .map(|n| format!("Pair({n}, {})", n * 10))
            .collect::<Vec<_>>()
            .join(", ");
        let keys = (1..=count)
            .rev()
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let trace = (1..=count)
            .map(|n| (n * 110).to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let mapped = (1..=count)
            .map(|n| format!("Pair({n}, {})", n * 11))
            .collect::<Vec<_>>()
            .join(", ");
        let filtered_map = (1..=count)
            .filter(|&n| n != 2)
            .map(|n| format!("Pair({n}, {})", n * 10))
            .collect::<Vec<_>>()
            .join(", ");
        let filtered_set = (1..=count)
            .filter(|&n| n != 2)
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let folded_map = 7 + (1..=count).map(|n| n * 11).sum::<i64>();
        let folded_set = (1..=count).fold(7, |acc, n| acc * 10 + n);
        for (name, expression, expected) in cases {
            let source = format!(
                r#"
function record_visit(log: Reference[List[Integer]], n: Integer) -> Unit uses State
  return Reference.set(log, List.append(Reference.get(log), n))
end function
function main() -> Result[Unit, String] uses State
  bind m: Map[Integer, Integer] <- Map.fromList([{pairs}])
  bind s: Set[Integer] <- Set.fromList([{keys}])
  bind originalMap <- Map.toList(m)
  bind originalSet <- Set.toList(s)
  bind mapped: List[Pair[Integer, Integer]] <- [{mapped}]
  bind filteredMap: List[Pair[Integer, Integer]] <- [{filtered_map}]
  bind filteredSet: List[Integer] <- [{filtered_set}]
  bind mappedSet: List[Integer] <- [{mapped_set}]
  bind foldedMap <- {folded_map}
  bind foldedSet <- {folded_set}
  bind log: Reference[List[Integer]] <- Reference.new([])
  bind result <- {expression}
  return if {expected} and Reference.get(log) = [{trace}] and Map.toList(m) = originalMap and Set.toList(s) = originalSet then
    Result.Ok(())
  else
    Result.Error("{name} result or call order")
  end if
end function
"#,
                mapped_set = if count == 0 { "" } else { "1" }
            );
            let program = compile(&source);
            let output = Arc::new(Mutex::new(Vec::new()));
            let end =
                run::run_program(&program, environment(ExecMode::Direct, Arc::clone(&output)));
            assert_eq!(end.end, EndKind::Returned, "{name}, count {count}: {end:?}");
            assert_eq!(end.exit_code, 0, "{name}, count {count}: {end:?}");
            assert!(end.reports.is_empty(), "{name}, count {count}: {end:?}");
            assert!(end.main_error.is_none(), "{name}, count {count}: {end:?}");
            assert!(output.lock().unwrap().is_empty());
        }
    }
}

// 関門: Trait の辞書を選び、Map・Set の Show・Semigroup・Monoid のソースを実行する契約。
// 型検査を通すだけでは、鍵順の表示、右の値の優先、空の値、元の Decimal の鍵の保存を
// 確かめられないため、公開の実行経路で出力と終了結果まで確かめる。
#[test]
fn map_and_set_standard_traits_show_combine_and_empty() {
    let program = compile(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit, String] uses Console.Write
  bind m <- Map.fromList([Pair(2, "b"), Pair(1, "a")])
  bind s <- Set.fromList([2, 1])
  Console.writeLine(Trait.Show.show(m))
  Console.writeLine(Trait.Show.show(s))
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(m, Map.fromList([Pair(1, "new"), Pair(3, "c")]))))
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(s, Set.fromList([3, 2]))))
  bind emptyMap: Map[Integer, String] <- Trait.Monoid.empty()
  bind emptySet: Set[Integer] <- Trait.Monoid.empty()
  Console.writeLine(Trait.Show.show(emptyMap))
  Console.writeLine(Trait.Show.show(emptySet))
  bind d <- Trait.Semigroup.combine(Map.fromList([Pair(1.0m, "old")]), Map.fromList([Pair(1.00m, "new")]))
  bind preserved <- Decimal.toString(List.head(Map.keys(d)) |> Option.unwrapOr(_, 0m)) = "1.0" and Map.get(d, 1.00m) = Option.Some("new")
  return if preserved and Map.toList(Trait.Semigroup.combine(emptyMap, m)) = Map.toList(m) and Map.toList(Trait.Semigroup.combine(m, emptyMap)) = Map.toList(m) and Set.toList(Trait.Semigroup.combine(emptySet, s)) = Set.toList(s) and Set.toList(Trait.Semigroup.combine(s, emptySet)) = Set.toList(s) and Map.toList(m) = [Pair(1, "a"), Pair(2, "b")] and Set.toList(s) = [1, 2] then
    Result.Ok(())
  else
    Result.Error("collection traits")
  end if
end function
"#,
    );
    let output = Arc::new(Mutex::new(Vec::new()));
    let end = run::run_program(&program, environment(ExecMode::Direct, Arc::clone(&output)));
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert_eq!(end.exit_code, 0, "{end:?}");
    assert!(end.reports.is_empty(), "{end:?}");
    assert!(end.main_error.is_none(), "{end:?}");
    assert_eq!(*output.lock().unwrap(), b"Map.fromList([Pair(1, \"a\"), Pair(2, \"b\")])\nSet.fromList([1, 2])\nMap.fromList([Pair(1, \"new\"), Pair(2, \"b\"), Pair(3, \"c\")])\nSet.fromList([1, 2, 3])\nMap.fromList([])\nSet.fromList([])\n");
}

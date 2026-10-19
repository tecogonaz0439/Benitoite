//! ランタイムを使う組み込みの関数を、部品を渡す公開の実行経路で確かめる（設計書 02-09「実行ごとの状態」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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
// 出力先のロックを idle まで保ち、偶然 writer が先に終わる場合を除く。
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
// 関門: 公開の RunEnv::parts が WorkerExec::wakeup を出力へ渡す契約。
// 本体や VM のテストでは run_program の部品の配線を通らない。
#[test]
fn injected_parts_wait_for_output_before_reading_stdin() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Console.Write,Console.Read
 Console.write("Name: ")
 bind name <- try Console.readLine() |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
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
            let guard = held
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            let _ready = ready.send(());
            let timed_out = matches!(
                receive.recv_timeout(std::time::Duration::from_secs(120)),
                Err(mpsc::RecvTimeoutError::Timeout)
            );
            drop(guard);
            timed_out
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
        let gate_timed_out = gate.join().unwrap();
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0);
        assert!(end.reports.is_empty());
        assert!(end.main_error.is_none());
        assert!(
            !gate_timed_out,
            "the output gate was not released by idle within 120 s"
        );
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
 with reader = try File.openReader("Cargo.toml") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda) do
  bind _ <- try File.readLine(reader) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
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

// 関門: コレクションの八つのソース関数が、鍵順に一度ずつ関数を呼び、その結果を使う契約。
// 本体の単体テストはソースの脱糖や State の伝播を通らない。実行の公開の境界を使い、
// Reference の観察結果と返り値を確かめる（設計書 03-06「関数を引数にとる関数の共通の規則」）。
#[test]
fn map_and_set_source_functions_call_in_key_order_once_and_use_the_results() {
    let cases = [
        (
            "Map.map",
            "Map.map(m: m, f: lambda(key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn key + value end lambda)",
            "Map.toList(result) = mapped",
        ),
        (
            "Map.filter",
            "Map.filter(m: m, p: lambda(key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn key <> 2 end lambda)",
            "Map.toList(result) = filteredMap",
        ),
        (
            "Map.fold",
            "Map.fold(m: m, initial: 7, f: lambda(acc, key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn acc + key + value end lambda)",
            "result = foldedMap",
        ),
        (
            "Map.forEach",
            "Map.forEach(m: m, f: lambda(key, value) return record_visit(log: log, n: key * 100 + value) end lambda)",
            "result = ()",
        ),
        (
            "Set.map",
            "Set.map(s: s, f: lambda(value)\n record_visit(log: log, n: value * 110)\nreturn 1 end lambda)",
            "Set.toList(result) = mappedSet",
        ),
        (
            "Set.filter",
            "Set.filter(s: s, p: lambda(value)\n record_visit(log: log, n: value * 110)\nreturn value <> 2 end lambda)",
            "Set.toList(result) = filteredSet",
        ),
        (
            "Set.fold",
            "Set.fold(s: s, initial: 7, f: lambda(acc, value)\n record_visit(log: log, n: value * 110)\nreturn acc * 10 + value end lambda)",
            "result = foldedSet",
        ),
        (
            "Set.forEach",
            "Set.forEach(s: s, f: lambda(value) return record_visit(log: log, n: value * 110) end lambda)",
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
  return Reference.set(reference: log, value: List.append(xs: Reference.get(log), x: n))
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
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(x: m, y: Map.fromList([Pair(1, "new"), Pair(3, "c")]))))
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(x: s, y: Set.fromList([3, 2]))))
  bind emptyMap: Map[Integer, String] <- Trait.Monoid.empty()
  bind emptySet: Set[Integer] <- Trait.Monoid.empty()
  Console.writeLine(Trait.Show.show(emptyMap))
  Console.writeLine(Trait.Show.show(emptySet))
  bind d <- Trait.Semigroup.combine(x: Map.fromList([Pair(1.0m, "old")]), y: Map.fromList([Pair(1.00m, "new")]))
  bind preserved <- Decimal.toString(List.head(Map.keys(d)) |> Option.unwrapOr(o: _, fallback: 0m)) = "1.0" and Map.get(m: d, k: 1.00m) = Option.Some("new")
  return if preserved and Map.toList(Trait.Semigroup.combine(x: emptyMap, y: m)) = Map.toList(m) and Map.toList(Trait.Semigroup.combine(x: m, y: emptyMap)) = Map.toList(m) and Set.toList(Trait.Semigroup.combine(x: emptySet, y: s)) = Set.toList(s) and Set.toList(Trait.Semigroup.combine(x: s, y: emptySet)) = Set.toList(s) and Map.toList(m) = [Pair(1, "a"), Pair(2, "b")] and Set.toList(s) = [1, 2] then
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

// 関門: 不透明な失敗値の Show が message をそのまま返す契約を公開の実行経路で守る。
// 既存のコレクションの Show 検査にはこの二型の辞書選択・組み込みの呼び出しがない。
// 不正なパスと URL は外部のファイル・通信へ進まず失敗し、本番の差し込み口を増やさない。
#[test]
fn opaque_failures_show_their_messages_in_both_io_modes() {
    let program = compile(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Network.Http
function main() -> Result[Unit, String] uses File.Read, Http.Connect
  bind io <- match File.readText("\u{0}") with
    case Result.Error(e) -> Trait.Show.show(e) = IOError.message(e) and IOError.message(e) <> ""
    case Result.Ok(_) -> false
  end match
  bind network <- match Http.get("ftp://invalid.example/") with
    case Result.Error(e) -> Trait.Show.show(e) = "URL must be an absolute http or https URL"
      and Trait.Show.show(e) = NetworkError.message(e)
    case Result.Ok(_) -> false
  end match
  return if io and network then Result.Ok(()) else Result.Error("failure Show") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(output.lock().unwrap().is_empty());
    }
}

// 作成時の関門: 狭い整数の変換の範囲と字句、拡大の正確さを公開の実行経路で守る。
// 旧 Integer のテストには縮小や符号なしの負号の拒否がなく、登録漏れや幅の取り違えを捕まえない。
// 本物の段をつなぎ、テスト専用の差し込み口は加えない。
#[test]
fn narrow_integer_conversions_preserve_values_and_reject_invalid_input() {
    for (module, suffix, low, high) in [
        ("Integer8", "s8", -128_i64, 127_i64),
        ("Integer16", "s16", -32768, 32767),
        ("Integer32", "s32", -2147483648, 2147483647),
        ("UnsignedInteger16", "u16", 0, 65535),
        ("UnsignedInteger32", "u32", 0, 4294967295),
    ] {
        let below = low - 1;
        let above = high + 1;
        let mut checks = vec![
            format!("{module}.fromInteger({low}) = Option.Some({low}{suffix})"),
            format!("{module}.fromInteger({high}) = Option.Some({high}{suffix})"),
            format!("{module}.fromInteger({below}) = Option.None"),
            format!("{module}.fromInteger({above}) = Option.None"),
            format!("{module}.fromInteger(-9223372036854775808) = Option.None"),
            format!("{module}.fromInteger(9223372036854775807) = Option.None"),
            format!("{module}.toInteger({low}{suffix}) = {low}"),
            format!("{module}.toInteger({high}{suffix}) = {high}"),
            format!("{module}.toFloat({low}{suffix}) = {low}.0"),
            format!("{module}.toFloat({high}{suffix}) = {high}.0"),
            format!("{module}.parse(\"{low}\") = Option.Some({low}{suffix})"),
            format!("{module}.parse(\"{high}\") = Option.Some({high}{suffix})"),
            format!("{module}.parse(\"{below}\") = Option.None"),
            format!("{module}.parse(\"{above}\") = Option.None"),
            format!("{module}.parse(\"0\") = Option.Some(0{suffix})"),
            format!(
                "{module}.parse(\"-0\") = {}",
                if low < 0 {
                    format!("Option.Some(0{suffix})")
                } else {
                    "Option.None".into()
                }
            ),
        ];
        for invalid in [
            "",
            "-",
            "+1",
            "01",
            "00",
            "-01",
            " 1",
            "1 ",
            "1\\n",
            "0x10",
            "1_0",
            "1.0",
            "1e1",
            "999999999999999999999999999999",
        ] {
            checks.push(format!("{module}.parse(\"{invalid}\") = Option.None"));
        }
        let source = format!(
            "function main() -> Result[Unit, String]\n return if {} then Result.Ok(()) else Result.Error(\"{module} conversions\") end if\nend function\n",
            checks.join(" and ")
        );
        let program = compile(&source);
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(ExecMode::Direct, output));
        assert_eq!(end.exit_code, 0, "{module}: {end:?}");
        assert_eq!(end.end, EndKind::Returned, "{module}: {end:?}");
        assert!(end.reports.is_empty(), "{module}: {end:?}");
    }
}

// 作成時の関門: 床と 0 方向の除算の違い、最小値の剰余、絶対値と大小を守る。
// 算術演算子の既存テストは標準関数の床への補正を通らず、負の除数の誤りを捕まえない。
#[test]
fn narrow_integer_standard_functions_keep_floor_and_truncation_distinct() {
    for (module, suffix, low, high) in [
        ("Integer8", "s8", -128_i64, 127_i64),
        ("Integer16", "s16", -32768, 32767),
        ("Integer32", "s32", -2147483648, 2147483647),
        ("UnsignedInteger16", "u16", 0, 65535),
        ("UnsignedInteger32", "u32", 0, 4294967295),
    ] {
        let mut checks = vec![
            format!("{module}.minimum(a: {low}{suffix}, b: {high}{suffix}) = {low}{suffix}"),
            format!("{module}.minimum(a: {high}{suffix}, b: {low}{suffix}) = {low}{suffix}"),
            format!("{module}.maximum(a: {low}{suffix}, b: {high}{suffix}) = {high}{suffix}"),
            format!("{module}.maximum(a: {high}{suffix}, b: {low}{suffix}) = {high}{suffix}"),
            format!("{module}.absolute({high}{suffix}) = {high}{suffix}"),
            format!("{module}.absolute(0{suffix}) = 0{suffix}"),
            format!("{module}.floorDivide(a: {low}{suffix}, b: 1{suffix}) = {low}{suffix}"),
            format!("{module}.floorModulo(a: {low}{suffix}, b: 1{suffix}) = 0{suffix}"),
        ];
        let mut divisions = vec![(7, 3, 2, 1, 2, 1), (6, 3, 2, 0, 2, 0), (0, 3, 0, 0, 0, 0)];
        if low < 0 {
            checks.push(format!("{module}.absolute(-7{suffix}) = 7{suffix}"));
            checks.push(format!(
                "{module}.floorModulo(a: {low}{suffix}, b: -1{suffix}) = 0{suffix}"
            ));
            checks.push(format!(
                "{module}.floorDivide(a: {high}{suffix}, b: {low}{suffix}) = -1{suffix}"
            ));
            checks.push(format!(
                "{module}.floorModulo(a: {high}{suffix}, b: {low}{suffix}) = -1{suffix}"
            ));
            checks.push(format!(
                "{module}.floorDivide(a: {low}{suffix}, b: {high}{suffix}) = -2{suffix}"
            ));
            checks.push(format!(
                "{module}.floorModulo(a: {low}{suffix}, b: {high}{suffix}) = {}{suffix}",
                high - 1
            ));
            divisions.extend([
                (-7, 3, -3, 2, -2, -1),
                (7, -3, -3, -2, -2, 1),
                (-7, -3, 2, -1, 2, -1),
                (-6, 3, -2, 0, -2, 0),
                (6, -3, -2, 0, -2, 0),
                (0, -3, 0, 0, 0, 0),
            ]);
        }
        for (a, b, q, r, trunc_q, trunc_r) in divisions {
            checks.extend([
                format!("{module}.floorDivide(a: {a}{suffix}, b: {b}{suffix}) = {q}{suffix}"),
                format!("{module}.floorModulo(a: {a}{suffix}, b: {b}{suffix}) = {r}{suffix}"),
                format!("({a}{suffix} div {b}{suffix}) = {trunc_q}{suffix}"),
                format!("({a}{suffix} mod {b}{suffix}) = {trunc_r}{suffix}"),
            ]);
        }
        let source = format!(
            "function main() -> Result[Unit, String]\n return if {} then Result.Ok(()) else Result.Error(\"{module} standard functions\") end if\nend function\n",
            checks.join(" and ")
        );
        let program = compile(&source);
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(ExecMode::Direct, output));
        assert_eq!(end.exit_code, 0, "{module}: {end:?}");
        assert_eq!(end.end, EndKind::Returned, "{module}: {end:?}");
        assert!(end.reports.is_empty(), "{module}: {end:?}");
    }
}

// 作成時の関門: 標準関数の失敗が None や panic にならず、規定の診断で停止する契約。
// 既存の演算子のテストは標準関数を呼ばないため、同じ幅でも別の登録と本体を確かめる。
#[test]
fn fixed_width_integer_standard_functions_report_overflow_and_zero_divisors() {
    use benitoite::diag::DiagCode;
    for (module, suffix, low) in [
        ("Integer8", "s8", -128_i64),
        ("Integer16", "s16", -32768),
        ("Integer32", "s32", -2147483648),
        ("UnsignedInteger16", "u16", 0),
        ("UnsignedInteger32", "u32", 0),
        ("UnsignedInteger64", "u64", 0),
        ("UnsignedInteger", "u64", 0),
    ] {
        let mut cases = vec![
            (
                format!("{module}.floorDivide(a: 1{suffix}, b: 0{suffix})"),
                DiagCode::R0101,
            ),
            (
                format!("{module}.floorModulo(a: 1{suffix}, b: 0{suffix})"),
                DiagCode::R0101,
            ),
        ];
        if low < 0 {
            cases.extend([
                (format!("{module}.absolute({low}{suffix})"), DiagCode::R0102),
                (
                    format!("{module}.floorDivide(a: {low}{suffix}, b: -1{suffix})"),
                    DiagCode::R0102,
                ),
            ]);
        }
        for (expression, code) in cases {
            let program = compile(&format!(
                "function main() -> Unit\n bind n <- {expression}\n return ()\nend function\n"
            ));
            let output = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_program(&program, environment(ExecMode::Direct, output));
            assert_eq!(end.end, EndKind::Stopped, "{expression}: {end:?}");
            assert_eq!(end.exit_code, 1, "{expression}: {end:?}");
            assert_eq!(end.reports.len(), 1, "{expression}: {end:?}");
            assert_eq!(
                end.reports.first().unwrap().code,
                Some(code),
                "{expression}: {end:?}"
            );
        }
    }
}

// Return の明示は実行結果・失敗側の短絡・入力の一回評価を変えない。
#[test]
fn explicit_and_implicit_try_return_have_the_same_success_and_failure() {
    for action in ["", " or return"] {
        let source = format!(
            r#"
import Benitoite.Unofficial.IO.Console
function inputResult(x: Result[Integer, String]) -> Result[Integer, String] uses Console.Write
  Console.write("r")
  return x
end function
function result(x: Result[Integer, String]) -> Result[String, String] uses Console.Write
  bind n <- try inputResult(x){action}
  Console.write("+")
  return Result.Ok(Integer.toString(n))
end function
function inputOption(x: Option[Integer]) -> Option[Integer] uses Console.Write
  Console.write("o")
  return x
end function
function option(x: Option[Integer]) -> Option[String] uses Console.Write
  bind n <- try inputOption(x){action}
  Console.write("+")
  return Option.Some(Integer.toString(n))
end function
function main() -> Result[Unit, String] uses Console.Write
  bind ok <- result(Result.Ok(7))
  bind error <- result(Result.Error("failure"))
  bind some <- option(Option.Some(8))
  bind none <- option(Option.None)
  return if ok = Result.Ok("7") and error = Result.Error("failure") and some = Option.Some("8") and none = Option.None then
    Result.Ok(())
  else
    Result.Error("try result changed")
  end if
end function
"#
        );
        let program = compile(&source);
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let output = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
            assert_eq!(end.end, EndKind::Returned, "{action}: {end:?}");
            assert_eq!(end.exit_code, 0, "{action}: {end:?}");
            assert!(end.reports.is_empty(), "{action}: {end:?}");
            assert!(end.main_error.is_none(), "{action}: {end:?}");
            assert_eq!(*output.lock().unwrap(), b"r+ro+o");
        }
    }
}

#[path = "fixtures/scope.rs"]
mod scope_cases;

// 四問: 独立入力で成功時の全保存欄と六失敗・優先順・Showを公開実行経路で守る。
// 静的拒否の表だけでは、私有builtinの配線・Result/Pair・標準ラッパー・射影を通らない。
// 通常の引数を通じて実行時Errorを観察し、差し込み口は増やさない。
#[test]
fn scope_checked_values_preserve_inputs_and_runtime_errors() {
    use scope_cases::quoted as q;
    let mut source = String::from(
        r#"
import Benitoite.Unofficial.Scope
import Benitoite.Trait
function dynamicHost(pattern: String, host: String) -> Result[Scope.CheckedHost, Scope.ScopeError]
 return Scope.checkHost(pattern: pattern, host: host)
end function
function dynamicPath(pattern: String, path: String) -> Result[Scope.CheckedPath, Scope.ScopeError]
 return Scope.checkPath(pattern: pattern, path: path)
end function
function dynamicEndpoint(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer) -> Result[Scope.CheckedEndpoint, Scope.ScopeError]
 return Scope.checkEndpoint(hostPattern: hostPattern, host: host, minimumPort: minimumPort, maximumPort: maximumPort, port: port)
end function
function main() -> Result[Unit, String]
"#,
    );
    for (i, case) in scope_cases::cases().into_iter().enumerate() {
        let kind = case.get("kind").unwrap().as_str().unwrap();
        let result = case.get("result").unwrap().as_str().unwrap();
        let pattern = q(case.get("pattern").unwrap().as_str().unwrap());
        let target = q(case.get("target").unwrap().as_str().unwrap());
        let expected = if result == "ok" {
            let p = q(case.get("expectedPattern").unwrap().as_str().unwrap());
            let t = q(case.get("expectedTarget").unwrap().as_str().unwrap());
            let comparison = match kind {
                "host" => format!("Scope.hostPattern(value) = {p} and Scope.host(value) = {t}"),
                "path" => format!("Scope.pathPattern(value) = {p} and Scope.path(value) = {t}"),
                _ => format!(
                    "Scope.endpointHostPattern(value) = {p} and Scope.endpointHost(value) = {t} and Scope.endpointMinimumPort(value) = {} and Scope.endpointMaximumPort(value) = {} and Scope.endpointPort(value) = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap(),
                    case.get("port").unwrap()
                ),
            };
            format!("case Result.Ok(value) -> {comparison}\n case Result.Error(_) -> false")
        } else {
            let error = match result {
                "InvalidPattern" => format!(
                    "Scope.ScopeError.InvalidPattern(input, reason) -> input = {pattern} and String.byteLength(reason) > 0"
                ),
                "InvalidTarget" => format!(
                    "Scope.ScopeError.InvalidTarget(input, reason) -> input = {target} and String.byteLength(reason) > 0"
                ),
                "OutsideScope" => {
                    format!("Scope.ScopeError.OutsideScope(p, t) -> p = {pattern} and t = {target}")
                }
                "InvalidPortRange" => format!(
                    "Scope.ScopeError.InvalidPortRange(lo, hi) -> lo = {} and hi = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap()
                ),
                "InvalidPort" => format!(
                    "Scope.ScopeError.InvalidPort(port) -> port = {}",
                    case.get("port").unwrap()
                ),
                _ => format!(
                    "Scope.ScopeError.PortOutsideScope(lo, hi, port) -> lo = {} and hi = {} and port = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap(),
                    case.get("port").unwrap()
                ),
            };
            format!(
                "case Result.Ok(_) -> false\n case Result.Error(error) ->\n String.byteLength(Trait.Show.show(error)) <= 4096 and match error with\n case {error}\n case _ -> false\n end match"
            )
        };
        source.push_str(&format!(" bind good{i} <- match dynamic{}({}) with\n {expected}\n end match\n if not good{i} then return Result.Error(\"scope case {i}\") end if\n", scope_cases::operation(&case), scope_cases::arguments(&case)));
    }
    source.push_str(r#"
 bind original <- String.repeat(s: "あ", n: 3000)
 bind preserved <- match dynamicHost(pattern: "localhost", host: original) with
   case Result.Error(Scope.ScopeError.InvalidTarget(value, _)) -> value = original
   case _ -> false
 end match
 if not preserved then return Result.Error("scope original input") end if
 bind shown <- Trait.Show.show(Scope.ScopeError.InvalidPattern("a\"\n", "why"))
 if shown <> "InvalidPattern(\"a\\\"\\n\", \"why\")" then return Result.Error(shown) end if
 bind long <- Trait.Show.show(Scope.ScopeError.OutsideScope(String.repeat(s: "é", n: 5000), String.repeat(s: "\u{0}", n: 5000)))
 if String.byteLength(long) > 4096 or not String.endsWith(s: long, suffix: "...") then return Result.Error("scope show limit") end if
 if not String.startsWith(s: long, prefix: "OutsideScope(\"") or not String.endsWith(s: long, suffix: "\")...") then return Result.Error("scope show delimiters") end if
 bind escaped <- Trait.Show.show(Scope.ScopeError.InvalidPattern(String.repeat(s: "\u{0}", n: 5000), String.repeat(s: "\\\"\nあ", n: 5000)))
 if String.byteLength(escaped) > 4096 or not String.endsWith(s: escaped, suffix: "\")...") then return Result.Error("scope escaped show delimiters") end if
 if not String.contains(s: escaped, part: "\\u{0}") or String.contains(s: escaped, part: "\\u{...") then return Result.Error("scope show partial escape") end if

 return Result.Ok(())
end function
"#);
    let program = compile(&source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
        assert!(output.lock().unwrap().is_empty());
    }
}

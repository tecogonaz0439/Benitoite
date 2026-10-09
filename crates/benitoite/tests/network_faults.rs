//! ネットワークの失敗の表を実行器と CLI へ渡して確かめる（設計書 03-09・07-03、実装プラン L33）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]

use benitoite::cli::{self, CliEnv, DevPanic};
use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{NetworkFault, NetworkFaults, RuntimeParts};
use benitoite::runtime::sched::testing::{ScheduleEvent, ScheduleHandle};
use benitoite::vm::{ExecMode, VmConfig};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

const IMPORTS: &str =
    "import Benitoite.Unofficial.Network.Http\nimport Benitoite.Unofficial.IO.Console\n";

fn faults() -> NetworkFaults {
    NetworkFaults {
        by_host: vec![
            ("MiSsInG.InVaLiD".into(), NetworkFault::HostNotFound),
            ("REFUSED.INVALID".into(), NetworkFault::ConnectionRefused),
            ("ReSeT.InVaLiD".into(), NetworkFault::ConnectionReset),
            ("TiMeOuT.InVaLiD".into(), NetworkFault::TimedOut),
        ],
    }
}

struct ScriptFile(PathBuf);
impl ScriptFile {
    fn new(source: &str) -> Self {
        // CLI はファイルから読む。
        let directory = std::env::temp_dir().join(format!(
            "benitoite-network-faults-{}-{}",
            std::process::id(),
            std::thread::current().name().unwrap()
        ));
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join("main.bnt");
        std::fs::write(&path, source).unwrap();
        Self(path)
    }
}
impl Drop for ScriptFile {
    fn drop(&mut self) {
        // アサーションで巻き戻している場合も、後始末の失敗で二度目の panic を起こさない。
        let _removed = std::fs::remove_dir_all(self.0.parent().unwrap());
    }
}

// 同じソース・表を両方の実行口に渡す。表の引き渡し忘れは、筋書きにない仕事の待ちで失敗する。
fn execute_injected(source: &str, mode: ExecMode, through_cli: bool) -> String {
    let source = format!("{IMPORTS}{source}");
    let schedule = ScheduleHandle::new([], false);
    let mut parts = schedule.parts();
    parts.network_faults = faults();
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let heap = HeapConfig {
        stress: true,
        ..HeapConfig::default()
    };
    if through_cli {
        let script = ScriptFile::new(&source);
        let command = cli::parse_args(vec!["run".into(), script.0.as_os_str().to_owned()]).unwrap();
        let status = cli::execute(
            command,
            CliEnv {
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                stdin: StdinSource::Empty,
                working_directory: env!("CARGO_MANIFEST_DIR").into(),
                color: false,
                mode,
                interrupt: Some(Box::new(NoInterrupt)),
                parts: Some(parts),
                heap,
                dev_panic: DevPanic::None,
                dev_alloc_stats: false,
            },
        );
        assert_eq!(
            status,
            0,
            "{}",
            String::from_utf8_lossy(&stderr.lock().unwrap())
        );
    } else {
        let checked = pipeline::check_text(
            "network-faults.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        let program = pipeline::compile(&core, checked.sources).unwrap();
        let end = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: env!("CARGO_MANIFEST_DIR").into(),
                    script_directory: env!("CARGO_MANIFEST_DIR").into(),
                },
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::clone(&stderr)),
                interrupt: Box::new(NoInterrupt),
                parts: Some(parts),
                mode,
                vm: VmConfig::default(),
                heap,
                dev_panic_after_first_write: false,
            },
        );
        assert_eq!(end.end, EndKind::Returned, "{end:?}");
        assert_eq!(end.exit_code, 0, "{end:?}");
        assert!(
            end.reports.is_empty() && end.main_error.is_none(),
            "{end:?}"
        );
    }
    assert!(stderr.lock().unwrap().is_empty());
    let record = schedule.record();
    assert!(record.error.is_none(), "{record:?}");
    assert!(
        !record
            .events
            .iter()
            .any(|event| matches!(event, ScheduleEvent::WorkerRan(_))),
        "{record:?}"
    );
    String::from_utf8(stdout.lock().unwrap().clone()).unwrap()
}

// 関門: ソースの get/send とエラーのアクセサを含む、二つの parts の引き渡しの契約。
// L32 の関数単体のテストでは CLI と RunEnv の引き渡し忘れ・名前の大小文字を捕まえない。
// 注入は既存の外部依存の表だけを使い、本番の差し込み口を増やさない。
#[test]
fn get_and_send_expose_all_four_fault_kinds_through_run_and_cli() {
    let mut body =
        String::from("function main() -> Result[Unit, String] uses Http.Connect, Console.Write\n");
    let mut expected = String::new();
    for (host, kind) in [
        ("missing.invalid", "HostNotFound"),
        ("refused.invalid", "ConnectionRefused"),
        ("reset.invalid", "ConnectionReset"),
        ("timeout.invalid", "TimedOut"),
    ] {
        for host in [host.to_owned(), host.to_ascii_uppercase()] {
            for call in [
                format!("Http.get(\"http://{host}/\")"),
                format!("Http.send(Http.clientRequest(\"POST\", \"http://{host}/\"))"),
            ] {
                body.push_str(&format!(r#"
  Console.writeLine(match {call} with
    case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.{kind} then "{kind}" else "wrong kind" end if
    case Result.Ok(_response) -> "unexpected success"
  end match)
"#));
                expected.push_str(&format!("{kind}\n"));
            }
        }
    }
    body.push_str("return Result.Ok(())\nend function\n");
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for through_cli in [false, true] {
            assert_eq!(execute_injected(&body, mode, through_cli), expected);
        }
    }
}

// 関門: listen の待ち受けと serve のループへ進まず HostNotFound を返す契約。
// L30 の単体の返り値だけでは、serve のソースと実行口の接続を確かめられない。
#[test]
fn listen_and_serve_return_host_not_found_before_listening() {
    let source = r#"
function main() -> Result[Unit, String] uses Http.Listen, State, Console.Write
  Console.writeLine(match Http.listen("MiSsInG.InVaLiD", 0) with
    case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.HostNotFound then "listen HostNotFound" else "wrong kind" end if
    case Result.Ok(listener) ->
      bind _ <- Http.closeListener(listener)
      "unexpected success"
  end match)
  Console.writeLine(match Http.serve("MISSING.INVALID", 0, lambda(_request) return Http.text(200, "unused") end lambda) with
    case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.HostNotFound then "serve HostNotFound" else "wrong kind" end if
    case Result.Ok(_) -> "unexpected success"
  end match)
  return Result.Ok(())
end function
"#;
    for mode in [ExecMode::Direct, ExecMode::Request] {
        for through_cli in [false, true] {
            assert_eq!(
                execute_injected(source, mode, through_cli),
                "listen HostNotFound\nserve HostNotFound\n"
            );
        }
    }
}

// 関門: 表にない名前を一律に注入へ振り分ける退行を捕まえる。同じ実行の中で
// 注入と本物の loopback を通し、準備の待ちも扱える real_with_poll を使う（実装プラン 10-16）。
#[test]
fn an_unmatched_host_reaches_the_loopback_server() {
    let source = format!(
        r#"{IMPORTS}
function main() -> Result[Unit, String] uses Http.Listen, Http.Connect, State, Console.Write
  bind failed <- Http.get("http://MISSING.INVALID/")
  if not Result.isError(failed) then return Result.Error("missing injection") end if
  with listener = try Http.listen("127.0.0.1", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
    bind server <- TaskGroup.spawn(group, lambda()
      with exchange = try Http.accept(listener) |> Result.mapError(_, NetworkError.message) do
        bind request <- Http.requestOf(exchange)
        return Http.respond(exchange, Http.text(200, Http.Request.path(request))) |> Result.mapError(_, NetworkError.message)
      end with
    end lambda)
    bind response <- try Http.get("http://127.0.0.1:" + Integer.toString(Http.listenerPort(listener)) + "/unmatched") |> Result.mapError(_, NetworkError.message)
    bind _ <- try Task.await(server)
    Console.writeLine(Integer.toString(Http.Response.status(response)))
    Console.writeLine(Option.unwrapOr(String.fromUTF8(Http.Response.body(response)), "invalid UTF-8"))
    return Result.Ok(())
  end with
end function
"#
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let checked = pipeline::check_text(
            "unmatched.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
        let program = pipeline::compile(&core, checked.sources).unwrap();
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: env!("CARGO_MANIFEST_DIR").into(),
                    script_directory: env!("CARGO_MANIFEST_DIR").into(),
                },
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::clone(&stdout)),
                stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                interrupt: Box::new(NoInterrupt),
                parts: Some(RuntimeParts::real_with_poll(faults()).unwrap()),
                mode,
                vm: VmConfig::default(),
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            },
        );
        assert_eq!(end.end, EndKind::Returned, "{end:?}");
        assert_eq!(end.exit_code, 0, "{end:?}");
        assert!(
            end.main_error.is_none() && end.reports.is_empty(),
            "{end:?}"
        );
        assert_eq!(*stdout.lock().unwrap(), b"200\n/unmatched\n");
    }
}

//! Wasm に入った後も Rust のスタックあふれを検出できることを確かめる。
//! macOS は Mach の例外ポート、Linux はシグナルの処理器の経路を通る。
//! 中断の検査は Wasm の実行中の SIGINT・SIGTERM を終了状態 130 として扱えることを確かめる
//! （設計書 03-01「使う Rust のクレート」、02-09「中断の要求」）。
#![cfg(unix)]
// テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::arithmetic_side_effects
)]

use std::io::Read;
use std::os::unix::process::ExitStatusExt;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
use wasmtime::{
    Engine, Store,
    component::{Component, Linker},
};

const PROBE: &str = "BENITOITE_WASM_SIGNAL_PROBE";

fn enter_wasm() {
    let engine = Engine::new(&benitoite::external::engine_config()).unwrap();
    let bytes = wat::parse_str(
        r#"(component
        (core module $m (func (export "f")))
        (core instance $i (instantiate $m))
        (func (export "f") (canon lift (core func $i "f"))))"#,
    )
    .unwrap();
    let component = Component::from_binary(&engine, &bytes).unwrap();
    let mut store = Store::new(&engine, ());
    store.set_fuel(1000).unwrap();
    store.set_epoch_deadline(1);
    let instance = Linker::new(&engine)
        .instantiate(&mut store, &component)
        .unwrap();
    let f = instance.get_typed_func::<(), ()>(&mut store, "f").unwrap();
    f.call(&mut store, ()).unwrap();
}

#[inline(never)]
fn recurse(n: usize) -> usize {
    if std::hint::black_box(n) == usize::MAX {
        n
    } else {
        std::hint::black_box(recurse(n + 1)) + 1
    }
}

#[test]
fn wasmtime_process_probe() {
    let Some(mode) = std::env::var_os(PROBE) else {
        return;
    };
    enter_wasm();
    if mode == "stack" {
        std::hint::black_box(recurse(0));
        return;
    }
    let directory = std::path::PathBuf::from(env!("CARGO_TARGET_TMPDIR"))
        .join(format!("wasm-signal-probe-{}", std::process::id()));
    std::fs::create_dir_all(&directory).unwrap();
    let script = directory.join("main.bnt");
    std::fs::write(
        directory.join("spin.wasm"),
        wat::parse_str(
            r#"(component
        (core module $m (func (export "warmup")) (func (export "spin") (loop br 0)))
        (core instance $i (instantiate $m))
        (func (export "warmup") (canon lift (core func $i "warmup")))
        (func (export "spin") (canon lift (core func $i "spin"))))"#,
        )
        .unwrap(),
    )
    .unwrap();
    let test = mode == "test-interrupt";
    let body = r#"import Benitoite.Unofficial.IO.File
@external("wasm", "spin.wasm", "warmup")
function warmup() -> Unit
@external("wasm", "spin.wasm", "spin")
function spin() -> Unit
"#;
    let completed = if test {
        "@test\nfunction prepared() -> Unit\n  warmup()\nend function\n"
    } else {
        ""
    };
    let remaining = if test {
        "@test\nfunction remaining() -> Unit uses File.Write\n  bind _ <- File.writeText(path: \"remaining\", text: \"must not run\")\nend function\n"
    } else {
        ""
    };
    let function = if test {
        "@test\nfunction spinning()"
    } else {
        "function main()"
    };
    std::fs::write(
        &script,
        format!(
            r#"{body}{completed}{function} -> Unit uses File.Write
  warmup()
  bind _ready <- File.writeText(path: "ready", text: "ready")
  spin()
end function
{remaining}"#
        ),
    )
    .unwrap();
    let command = benitoite::cli::parse_args(vec![
        if test { "test".into() } else { "run".into() },
        script.into_os_string(),
    ])
    .unwrap();
    let exit = benitoite::cli::execute(
        command,
        benitoite::cli::CliEnv {
            stdout: benitoite::runtime::run::OutputTarget::Stdout,
            stderr: benitoite::runtime::run::OutputTarget::Stderr,
            stdin: benitoite::runtime::run::StdinSource::Process,
            working_directory: directory.clone(),
            color: false,
            mode: benitoite::vm::ExecMode::Direct,
            interrupt: None,
            parts: None,
            heap: benitoite::runtime::heap::HeapConfig::default(),
            dev_panic: benitoite::cli::DevPanic::None,
            dev_alloc_stats: false,
        },
    );
    std::fs::remove_dir_all(directory).unwrap();
    std::process::exit(i32::from(exit));
}

fn probe(mode: &str, signal: Option<&str>) -> (std::process::ExitStatus, String) {
    let mut child = Command::new(std::env::current_exe().unwrap())
        .args(["--exact", "wasmtime_process_probe", "--nocapture"])
        .env(PROBE, mode)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let stdout = child.stdout.take().unwrap();
    let reader = std::thread::spawn(move || {
        let mut output = String::new();
        std::io::BufReader::new(stdout)
            .read_to_string(&mut output)
            .unwrap();
        output
    });
    let directory = std::path::PathBuf::from(env!("CARGO_TARGET_TMPDIR"))
        .join(format!("wasm-signal-probe-{}", child.id()));
    if let Some(signal) = signal {
        let started = Instant::now();
        while !directory.join("ready").exists() {
            if started.elapsed() > Duration::from_secs(3) || child.try_wait().unwrap().is_some() {
                let _killed = child.kill();
                let output = child.wait_with_output().unwrap();
                reader.join().unwrap();
                let _removed = std::fs::remove_dir_all(&directory);
                panic!(
                    "probe did not become ready: {}",
                    String::from_utf8_lossy(&output.stderr)
                );
            }
            std::thread::sleep(Duration::from_millis(5));
        }
        // 同じコンポーネントの warmup でコンパイルと見張りの起動を終えた後に送る。
        // 取り込みのない Wasm から準備を通知できないので、spin への移行には短い余裕を置く。
        std::thread::sleep(Duration::from_millis(200));
        assert!(
            Command::new("kill")
                .args([signal, &child.id().to_string()])
                .status()
                .unwrap()
                .success()
        );
    }
    let started = Instant::now();
    let status = loop {
        if let Some(status) = child.try_wait().unwrap() {
            break status;
        }
        if started.elapsed() > Duration::from_secs(3) {
            child.kill().unwrap();
            child.wait().unwrap();
            panic!("probe did not exit");
        }
        std::thread::sleep(Duration::from_millis(10));
    };
    reader.join().unwrap();
    let mut stderr = String::new();
    child
        .stderr
        .take()
        .unwrap()
        .read_to_string(&mut stderr)
        .unwrap();
    assert!(
        !directory.join("remaining").exists(),
        "interrupted test ran the remaining function"
    );
    let _removed = std::fs::remove_dir_all(&directory);
    (status, stderr)
}

#[test]
fn interrupts_during_wasm_have_exit_status_130() {
    // 関門: run と test の読み口の違いを、実際のシグナルから終了状態まで確かめる。
    // Wasmtime の単体の中断では、テスト実行器の共有の印の渡し忘れを検出できない。
    for (mode, signal) in [
        ("interrupt", "-INT"),
        ("interrupt", "-TERM"),
        ("test-interrupt", "-INT"),
        ("test-interrupt", "-TERM"),
    ] {
        let (status, stderr) = probe(mode, Some(signal));
        assert_eq!(status.code(), Some(130), "{mode} {signal}: {stderr}");
    }
}

#[test]
fn rust_stack_overflow_after_wasm_call_is_detected() {
    let (status, stderr) = probe("stack", None);
    assert_eq!(
        status.signal(),
        Some(signal_hook::consts::SIGABRT),
        "{stderr}"
    );
    assert!(stderr.contains("stack overflow"), "{stderr}");
}

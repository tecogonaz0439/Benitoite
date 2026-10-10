#!/usr/bin/env python3
"""Verify and measure the Benitoite benchmark programs with Python's stdlib."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import http.client
import json
import os
import platform
import queue
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence


BENCH = Path(__file__).resolve().parent
ROOT = BENCH.parents[1]
PROGRAMS = BENCH / "programs"
RESULTS = BENCH / "results"
NAMES = ("fib", "loop", "list", "tree", "eval", "string", "println", "lines")
COMPARABLE_ADDITIONS = ("trait", "listget", "map")
BENITOITE_ADDITIONS = ("handler", "tasks", "cycle")
FIRST_RELEASE_NAMES = ("trait", "handler-tail", "handler-saved", "tasks", "cycle", "listget", "map")
ITERATIONS = 10
BENCH_INPUTS = {
    # 2026-09-27 に Apple M4 で Benitoite の実行時間が 1〜3 秒になるように合わせた。
    # string と lines は List の要素数の上限（16,777,216）で抑えられる。string は 1 秒に届かない（約 0.5 秒）。
    # eval は深さ 500 の式を入力の回数だけ評価する。
    "fib": 35,
    # 2026-10-09 の短い試行: 15,000,000 は 0.94 秒、20,000,000 は 1.26 秒。
    "loop": 20_000_000,
    "list": 1_500_000,
    "tree": 22,
    "eval": 30_000,
    "string": 8_000_000,
    "println": 7_000_000,
    "lines": 16_000_000,
    # 2026-10-09 の短い試行で 1〜3 秒に調整した。handler は単一の深さを増やすと
    # 1 GiB の上限に達するため、深さ 100,000 の処理を 100 回繰り返す。
    "trait": (20_000_000,),
    "handler-tail": (100_000, "tail", 100),
    "handler-saved": (100_000, "saved", 100),
    "tasks": (1_000, 30_000),
    "cycle": (10_000_000,),
    "listget": (100_000, 8_000_000),
    # Map 200,000 は短い試行で 2.55 秒。HTTP の共通 1,000 要求は試行の基準として
    # 残し、本測定は --http-inputs で条件ごとに 1〜10 秒になる要求数を渡す。
    "map": (200_000,),
    "http": (1_000,),
}
ALLOC_STATS_RE = re.compile(
    r"^alloc-stats: allocations=(\d+) allocated_bytes=(\d+) peak_heap_bytes=(\d+) collections=(\d+)$",
    re.MULTILINE,
)


@dataclass
class Runtime:
    name: str
    family: str
    prefix: list[str]
    version: str
    extension: str = ""
    environment: dict[str, str] = field(default_factory=dict)
    remove_environment: tuple[str, ...] = ()
    rust_bins: Path | None = None
    ocaml_bins: Path | None = None
    ocaml_compiler: str | None = None

    def command(self, name: str, arguments: Sequence[str]) -> list[str]:
        if self.family == "rust":
            assert self.rust_bins is not None
            executable = self.rust_bins / name
            return [str(executable), *arguments]
        if self.family == "ocaml":
            assert self.ocaml_bins is not None
            executable = self.ocaml_bins / f"{name}.{self.extension}"
            return [*self.prefix, str(executable), *arguments]
        source = PROGRAMS / self.family / f"{name}.{self.extension}"
        return [*self.prefix, str(source), *arguments]

    def child_environment(self) -> dict[str, str]:
        env = os.environ.copy()
        for name in self.remove_environment:
            env.pop(name, None)
        env.update(self.environment)
        return env


def command_path(value: str) -> str | None:
    candidate = Path(value)
    if candidate.is_absolute() or len(candidate.parts) > 1:
        if candidate.is_file():
            return str(candidate.resolve())
        return None
    return shutil.which(value)


def command_output(command: Sequence[str], env: dict[str, str] | None = None) -> str:
    try:
        result = subprocess.run(
            list(command),
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError:
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def cpython_jit_available(python: str) -> bool:
    probe = (
        "import sys; jit = getattr(sys, '_jit', None); "
        "print(int(bool(jit and jit.is_available())))"
    )
    env = os.environ.copy()
    env["PYTHON_JIT"] = "0"
    return command_output([python, "-c", probe], env).strip() == "1"


def cpython_jit_enabled(python: str) -> bool:
    probe = (
        "import sys; jit = getattr(sys, '_jit', None); "
        "print(int(bool(jit and jit.is_available() and jit.is_enabled())))"
    )
    env = os.environ.copy()
    env["PYTHON_JIT"] = "1"
    return command_output([python, "-c", probe], env).strip() == "1"


def build_ocaml_programs(ocamlc: str, ocamlopt: str, additions: bool = False) -> None:
    build_dir = PROGRAMS / "ocaml" / "_build"
    build_dir.mkdir(parents=True, exist_ok=True)
    for name in NAMES + (COMPARABLE_ADDITIONS if additions else ()):
        source = PROGRAMS / "ocaml" / f"{name}.ml"
        if not source.is_file():
            raise RuntimeError(f"OCaml のソースがない: {source.relative_to(ROOT)}")
        build_source = build_dir / source.name
        shutil.copyfile(source, build_source)
        for compiler, extension in ((ocamlc, "byte"), (ocamlopt, "native")):
            output = build_dir / f"{name}.{extension}"
            command = [compiler, "-o", str(output), str(build_source)]
            try:
                result = subprocess.run(
                    command,
                    cwd=build_dir,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
            except OSError as error:
                raise RuntimeError(f"OCaml のビルドを起動できない: {compiler}: {error}") from error
            if result.returncode != 0:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                raise RuntimeError(
                    f"OCaml のビルドに失敗した: {' '.join(command)}"
                    + (f"\n{detail}" if detail else "")
                )


def detect_runtimes(skip_comparators: bool, additions: bool = False) -> tuple[list[Runtime], list[str]]:
    if skip_comparators:
        return [], ["比較対象: --skip-comparators により測定を省略した"]

    runtimes: list[Runtime] = []
    skipped: list[str] = []

    python = sys.executable
    python_version = command_output([python, "--version"]) or platform.python_version()
    if sys.implementation.name != "cpython":
        skipped.append(f"CPython: run.py を動かす Python は CPython ではない（{sys.implementation.name}）")
    else:
        runtimes.append(
            Runtime(
                "CPython (JIT off)",
                "python",
                [python],
                python_version,
                "py",
                {"PYTHON_JIT": "0"},
                ("PYTHON_JIT",),
            )
        )
        if cpython_jit_available(python):
            if cpython_jit_enabled(python):
                runtimes.append(
                    Runtime(
                        "CPython (JIT on)",
                        "python",
                        [python],
                        python_version,
                        "py",
                        {"PYTHON_JIT": "1"},
                        ("PYTHON_JIT",),
                    )
                )
            else:
                skipped.append("CPython (JIT on): PYTHON_JIT=1 で JIT を有効にできなかった")
        else:
            skipped.append("CPython (JIT on): この CPython ビルドは JIT を利用できない")

    ruby = command_path("ruby")
    if ruby is None:
        skipped.append("Ruby MRI: ruby が見つからない")
    else:
        ruby_version = command_output([ruby, "--version"]) or "unknown"
        ruby_engine = command_output([ruby, "-e", "puts RUBY_ENGINE"])
        if ruby_engine != "ruby":
            skipped.append(f"Ruby MRI: ruby は MRI ではない（{ruby_version}）")
        else:
            runtimes.append(
                Runtime(
                    "Ruby MRI (YJIT off)",
                    "ruby",
                    [ruby],
                    ruby_version,
                    "rb",
                    remove_environment=("RUBYOPT",),
                )
            )
            yjit_probe = command_output(
                [ruby, "--yjit", "-e", "puts RubyVM::YJIT.enabled?"],
                {**os.environ, "RUBYOPT": ""},
            )
            if yjit_probe == "true":
                runtimes.append(
                    Runtime(
                        "Ruby MRI (YJIT on)",
                        "ruby",
                        [ruby, "--yjit"],
                        ruby_version,
                        "rb",
                        remove_environment=("RUBYOPT",),
                    )
                )
            else:
                skipped.append("Ruby MRI (YJIT on): ruby --yjit がこのビルドで使えない")

    lua = next(
        (
            candidate
            for name in ("lua", "lua5.4", "lua5.3", "lua5.2", "lua5.1")
            if (candidate := command_path(name)) is not None
        ),
        None,
    )
    if lua is None:
        skipped.append("Lua: lua が見つからない")
    else:
        lua_version = command_output([lua, "-v"]) or "unknown"
        lua_implementation = command_output([lua, "-e", "print(jit and 'LuaJIT' or 'Lua')"])
        if lua_implementation != "Lua":
            skipped.append(f"Lua: lua は標準 Lua ではない（{lua_version}）")
        else:
            runtimes.append(Runtime("Lua", "lua", [lua], lua_version, "lua"))

    rust_target = Path(os.environ.get("CARGO_TARGET_DIR", PROGRAMS / "rust" / "target"))
    rust_bins = rust_target.resolve() / "release"
    rustc = command_path("rustc")
    rust_names = NAMES + (COMPARABLE_ADDITIONS if additions else ())
    rust_missing = [name for name in rust_names if not (rust_bins / name).is_file()]
    if rustc is None:
        skipped.append("Rust: rustc が見つからない")
    elif rust_missing:
        skipped.append(
            "Rust: release バイナリがない（cargo build --release --manifest-path "
            "tools/bench/programs/rust/Cargo.toml を実行する）"
        )
    else:
        rust_version = command_output([rustc, "--version"]) or "unknown"
        runtimes.append(
            Runtime("Rust (--release)", "rust", [], rust_version, rust_bins=rust_bins)
        )

    ocamlc = command_path("ocamlc")
    ocamlopt = command_path("ocamlopt")
    ocamlrun = command_path("ocamlrun")
    missing_ocaml = [
        name
        for name, executable in (
            ("ocamlc", ocamlc),
            ("ocamlopt", ocamlopt),
            ("ocamlrun", ocamlrun),
        )
        if executable is None
    ]
    if missing_ocaml:
        skipped.append(f"OCaml: {', '.join(missing_ocaml)} が見つからない")
    else:
        assert ocamlc is not None and ocamlopt is not None and ocamlrun is not None
        build_ocaml_programs(ocamlc, ocamlopt, additions)
        ocaml_version = command_output([ocamlopt, "-version"]) or "unknown"
        ocaml_bins = PROGRAMS / "ocaml" / "_build"
        runtimes.extend(
            (
                Runtime(
                    "OCaml (bytecode)",
                    "ocaml",
                    [ocamlrun],
                    ocaml_version,
                    "byte",
                    ocaml_bins=ocaml_bins,
                    ocaml_compiler=ocamlc,
                ),
                Runtime(
                    "OCaml (native)",
                    "ocaml",
                    [],
                    ocaml_version,
                    "native",
                    ocaml_bins=ocaml_bins,
                    ocaml_compiler=ocamlopt,
                ),
            )
        )

    return runtimes, skipped


def run_process(
    command: Sequence[str],
    env: dict[str, str] | None = None,
    capture_stdout: bool = False,
) -> tuple[float, bytes, bytes, int]:
    start = time.perf_counter()
    try:
        result = subprocess.run(
            list(command),
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE if capture_stdout else subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as error:
        raise RuntimeError(f"コマンドを起動できない: {command[0]}: {error}") from error
    elapsed = time.perf_counter() - start
    return elapsed, result.stdout or b"", result.stderr or b"", result.returncode


def require_success(command: Sequence[str], env: dict[str, str] | None = None) -> bytes:
    _, stdout, stderr, code = run_process(command, env, capture_stdout=True)
    if code != 0:
        detail = stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"終了状態 {code}: {' '.join(command)}"
            + (f"\n{detail}" if detail else "")
        )
    return stdout


def small_arguments(name: str) -> list[str]:
    path = PROGRAMS / f"{name}.args.small"
    return path.read_text(encoding="utf-8").splitlines()


def verify(benitoite: str, runtimes: list[Runtime], skipped: list[str], bench_run: str) -> int:
    if not runtimes:
        raise RuntimeError("--verify には比較対象の処理系が必要である")
    for name in NAMES + COMPARABLE_ADDITIONS + BENITOITE_ADDITIONS:
        source = PROGRAMS / f"{name}.bnt"
        require_success([benitoite, "check", str(source)])
        arguments = small_arguments(name)
        expected = require_success([benitoite, "run", str(source), *arguments])
        for runtime in (runtimes if name not in BENITOITE_ADDITIONS else []):
            actual = require_success(runtime.command(name, arguments), runtime.child_environment())
            if actual != expected:
                raise RuntimeError(
                    f"出力が一致しない: {name} / {runtime.name}\n"
                    f"Benitoite: {expected.decode('utf-8', errors='replace')!r}\n"
                    f"比較対象: {actual.decode('utf-8', errors='replace')!r}"
                )
            print(f"verify: {name} / {runtime.name}: OK")
        if name in BENITOITE_ADDITIONS:
            print(f"verify: {name} / Benitoite: OK (比較対象なし)")
        if name == "handler":
            tail = require_success([benitoite, "run", str(source), arguments[0], "tail"])
            if tail != expected:
                raise RuntimeError("handler の tail と saved の出力が一致しない")
            print("verify: handler / tail と saved: OK")
    source = PROGRAMS / "http.bnt"
    require_success([benitoite, "check", str(source)])
    for busy in (0, 1):
        for clients in (1, 8):
            stats = http_sample(bench_run, 16, busy, clients)
            print(f"verify: http / busy={busy} clients={clients}: {stats['responses']} responses: OK")
    for line in skipped:
        print(f"skip: {line}")
    return 0


def generated_sources(directory: Path, functions: int = 10_000) -> tuple[Path, Path, Path]:
    noop = directory / "noop.bnt"
    noop.write_text("function main() -> Unit\n  return ()\nend function\n", encoding="utf-8")
    large = directory / "large-check.bnt"
    with large.open("w", encoding="utf-8", newline="\n") as output:
        for number in range(functions):
            output.write(f"function bench_{number}() -> Integer return {number} end function\n")
        output.write("function main() -> Unit return () end function\n")
    rust_source = directory / "noop.rs"
    rust_source.write_text("fn main() {}\n", encoding="utf-8")
    return noop, large, rust_source


def runtime_noop_command(runtime: Runtime, noop_script: Path, rust_noop: Path | None) -> list[str]:
    if runtime.family == "rust":
        if rust_noop is None:
            raise RuntimeError("Rust の空プログラムをコンパイルできなかった")
        return [str(rust_noop)]
    if runtime.family == "ocaml":
        if runtime.ocaml_compiler is None:
            raise RuntimeError(f"{runtime.name} のコンパイラがない")
        source = noop_script.with_suffix(".ml")
        source.write_text("let () = ()\n", encoding="utf-8")
        executable = source.with_suffix(f".{runtime.extension}")
        require_success([runtime.ocaml_compiler, "-o", str(executable), str(source)])
        return [*runtime.prefix, str(executable)]
    source = noop_script.with_suffix({"python": ".py", "ruby": ".rb", "lua": ".lua"}[runtime.family])
    source.write_text("", encoding="utf-8")
    return [*runtime.prefix, str(source)]


def memory_wrapper(command: Sequence[str]) -> list[str] | None:
    if os.environ.get("BENITOITE_BENCH_RSS") == "resource" and sys.platform in ("darwin", "linux"):
        return [sys.executable, str(BENCH / "rss.py"), *command]
    timer = Path("/usr/bin/time")
    if not timer.is_file():
        return None
    if platform.system() == "Darwin":
        return [str(timer), "-l", *command]
    if platform.system() == "Linux":
        return [str(timer), "-v", *command]
    return None


def parse_max_rss(stderr: bytes) -> int | None:
    text = stderr.decode("utf-8", errors="replace")
    resource_rss = re.search(r"^bench-rss: (\d+)$", text, re.MULTILINE)
    if resource_rss:
        return int(resource_rss.group(1))
    if platform.system() == "Darwin":
        match = re.search(r"^\s*(\d+)\s+maximum resident set size$", text, re.MULTILINE)
        return int(match.group(1)) if match else None
    if platform.system() == "Linux":
        match = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", text)
        return int(match.group(1)) * 1024 if match else None
    return None


def median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def format_seconds(value: float | None) -> str:
    return "—" if value is None else f"{value:.6f}"


def format_bytes(value: int | None) -> str:
    return "—" if value is None else f"{value:,}"


def total_memory() -> str:
    try:
        pages = os.sysconf("SC_PHYS_PAGES")
        page_size = os.sysconf("SC_PAGE_SIZE")
        return f"{pages * page_size:,} bytes"
    except (AttributeError, OSError, ValueError):
        return "unknown"


def cpu_description() -> str:
    machine = platform.machine() or "unknown"
    if platform.system() == "Darwin":
        model = command_output(["sysctl", "-n", "machdep.cpu.brand_string"])
        if model:
            return model
        return f"{machine} (model unavailable)"
    if platform.system() == "Linux":
        try:
            cpuinfo = Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace")
        except OSError:
            cpuinfo = ""
        for line in cpuinfo.splitlines():
            key, separator, value = line.partition(":")
            if separator and key.strip().lower() in ("model name", "hardware"):
                return value.strip()
    return platform.processor() or machine


def collect_system_info() -> dict[str, str]:
    return {
        "os": platform.platform(),
        "cpu": cpu_description(),
        "logical_cpus": str(os.cpu_count() or "unknown"),
        "memory": total_memory(),
        "rustc": command_output([command_path("rustc") or "rustc", "--version"]) or "not found",
    }


def git_revision() -> str:
    return command_output(["git", "rev-parse", "--short=12", "HEAD"]) or "unknown"


def generate_lines(path: Path, count: int) -> None:
    require_success(
        [sys.executable, str(PROGRAMS / "gen_lines.py"), str(path), "--lines", str(count)]
    )


def allocation_stats(stderr: bytes) -> tuple[int, int, int, int] | None:
    match = ALLOC_STATS_RE.search(stderr.decode("utf-8", errors="replace"))
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def measure_one(command: Sequence[str], env: dict[str, str], label: str) -> tuple[float, bytes]:
    elapsed, _, stderr, code = run_process(command, env)
    if code != 0:
        detail = stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(f"{label}: 終了状態 {code}" + (f"\n{detail}" if detail else ""))
    return elapsed, stderr


def benchmark_source(name: str) -> Path:
    stem = "handler" if name.startswith("handler-") else name
    return PROGRAMS / f"{stem}.bnt"


def has_comparators(name: str) -> bool:
    return name in NAMES + COMPARABLE_ADDITIONS


def workload_args(name: str, quick: bool, lines_input: Path) -> list[str]:
    if name == "lines":
        return [str(lines_input)]
    if quick:
        if name.startswith("handler-"):
            return [small_arguments("handler")[0], name.split("-", 1)[1]]
        return small_arguments(name)
    value = BENCH_INPUTS[name]
    return [str(v) for v in value] if isinstance(value, tuple) else [str(value)]


def render_input_rows(rows: list[tuple[str, list[str]]], quick: bool) -> str:
    return markdown_table(["ベンチマーク", "入力"],
                          [[name, f"{100 if quick else BENCH_INPUTS['lines']:,} 行（生成）" if name == "lines" else " ".join(args)]
                           for name, args in rows])


def markdown_table(headers: list[str], rows: list[list[object]]) -> str:
    # 一時ファイルのパスや失敗の理由も、Markdown の欄を壊さずに記録する。
    def cells(row: Sequence[object]) -> str:
        return "| " + " | ".join(str(v).replace("|", "\\|").replace("\n", " ") for v in row) + " |"
    return "\n".join([cells(headers), cells(["---"] * len(headers)), *(cells(row) for row in rows)])


def bench_sample(tool: str, source: Path, arguments: Sequence[object], *options: str) -> dict[str, int]:
    command = [tool, *options, str(source), *(str(v) for v in arguments)]
    wrapped = memory_wrapper(command)
    _, _, stderr, code = run_process(wrapped or command)
    # macOS の sandbox では time の統計だけが拒まれる場合がある。そのときは本体を実行し直す。
    if code != 0 and wrapped is not None:
        _, _, stderr, code = run_process(command)
    if code != 0:
        raise RuntimeError(f"bench_run が終了状態 {code} を返した: {' '.join(command)}\n{stderr.decode(errors='replace')}")
    return parse_bench_stats(stderr)


def parse_bench_stats(stderr: bytes) -> dict[str, int]:
    match = re.search(rb"^bench-run: (.+)$", stderr, re.MULTILINE)
    if match is None:
        raise RuntimeError("bench_run の統計行がない")
    try:
        stats = {key: int(value) for key, value in (field.split("=", 1) for field in match.group(1).decode().split())}
    except (ValueError, UnicodeError) as error:
        raise RuntimeError("bench_run の統計行を読めない") from error
    required = {"check_nanos", "desugar_nanos", "compile_nanos", "run_nanos", "total_nanos", "call_budget",
                "trigger_factor_percent", "collections", "peak_heap_bytes", "pause_count", "pause_p50_nanos",
                "pause_p95_nanos", "pause_p99_nanos", "pause_max_nanos", "pause_total_nanos"}
    if not required <= stats.keys():
        raise RuntimeError(f"bench_run の統計に必要な項目がない: {sorted(required - stats.keys())}")
    rss = parse_max_rss(stderr)
    if rss is not None:
        stats["rss"] = rss
    return stats


def http_sample(tool: str, count: int, busy: int, clients: int, *options: str,
                timeout: float = 30.0) -> dict[str, int | float | list[int]]:
    """サーバを一回動かし、外部の時計で全要求の応答までの時間を測る（L41）。"""
    if count <= 0 or clients <= 0:
        raise RuntimeError("HTTP の要求数とクライアント数は正でなければならない")
    command = [tool, *options, str(PROGRAMS / "http.bnt"), str(count), str(busy)]
    # stderr は統計と診断を失わず保存し、パイプが満杯でサーバが止まることを避ける。
    with tempfile.TemporaryFile() as stderr:
        process = subprocess.Popen(memory_wrapper(command) or command, cwd=ROOT, stdout=subprocess.PIPE, stderr=stderr,
                                   start_new_session=os.name == "posix")

        def stop_server() -> None:
            # RSS ラッパーを使う場合も、時間切れでサーバの子を残さない。
            if os.name == "posix":
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            elif process.poll() is None:
                process.kill()
        ports: queue.Queue[bytes] = queue.Queue()
        assert process.stdout is not None

        def read_stdout() -> None:
            ports.put(process.stdout.readline())
            # 二行目以降も読み捨て、予期しない出力でプロセスが詰まらないようにする。
            for _ in process.stdout:
                pass

        reader = threading.Thread(target=read_stdout, daemon=True)
        reader.start()
        deadline = time.perf_counter() + timeout
        executor = None
        try:
            try:
                port = int(ports.get(timeout=timeout).strip())
            except (queue.Empty, ValueError) as error:
                raise RuntimeError("HTTP サーバのポートを受け取れない") from error
            if not 1 <= port <= 65535:
                raise RuntimeError(f"HTTP サーバのポートが範囲外: {port}")
            workers = min(clients, count)
            barrier = threading.Barrier(workers)

            def client(index: int) -> list[tuple[int, int]]:
                timings = []
                barrier.wait(timeout=max(0.001, deadline - time.perf_counter()))
                for _ in range(index, count, workers):
                    remaining = deadline - time.perf_counter()
                    if remaining <= 0:
                        raise TimeoutError("HTTP 測定が時間切れになった")
                    # サーバの接続は一要求で閉じる。接続の確立も応答時間に含める。
                    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=remaining)
                    try:
                        start = time.perf_counter_ns()
                        connection.request("GET", "/")
                        response = connection.getresponse()
                        body = response.read()
                        end = time.perf_counter_ns()
                        if response.status != 200 or body != b"ok":
                            raise RuntimeError(f"HTTP の応答が期待と異なる: {response.status} {body!r}")
                        timings.append((start, end))
                    finally:
                        connection.close()
                return timings

            executor = concurrent.futures.ThreadPoolExecutor(max_workers=workers)
            futures = [executor.submit(client, index) for index in range(workers)]
            timings = [item for future in futures for item in future.result(timeout=max(0.001, deadline - time.perf_counter()))]
            code = process.wait(timeout=max(0.001, deadline - time.perf_counter()))
            stderr.seek(0)
            diagnostic = stderr.read()
            if code != 0:
                raise RuntimeError(f"HTTP サーバが終了状態 {code} を返した")
            stats = parse_bench_stats(diagnostic)
            pause_line = re.search(rb"^bench-pauses: *(.*)$", diagnostic, re.MULTILINE)
            pauses = [int(p) for p in pause_line.group(1).split(b",") if p.strip()] if pause_line else []
            if pause_line and (len(pauses) != stats["pause_count"] or sum(pauses) != stats["pause_total_nanos"]):
                raise RuntimeError("HTTP の停止標本が統計行と一致しない")
            latencies = [end - start for start, end in timings]
            elapsed = max(end for _, end in timings) - min(start for start, _ in timings)
            return {**stats, "pause_nanos": pauses, "responses": len(timings), "throughput": count * 1e9 / elapsed,
                    "latency_p50_nanos": statistics.median(latencies), "latency_max_nanos": max(latencies)}
        except (OSError, ValueError, RuntimeError, TimeoutError, concurrent.futures.TimeoutError, subprocess.TimeoutExpired,
                threading.BrokenBarrierError, http.client.HTTPException) as error:
            # 失敗したサーバを残さず止め、その後に診断を読んで報告する。
            if process.poll() is None:
                stop_server()
            process.wait()
            stderr.seek(0)
            detail = stderr.read().decode(errors="replace").strip()
            raise RuntimeError(f"HTTP 測定に失敗した: {error}" + (f"\n{detail}" if detail else "")) from error
        finally:
            if process.poll() is None:
                stop_server()
                process.wait()
            if executor is not None:
                executor.shutdown(wait=True, cancel_futures=True)
            reader.join(timeout=1)
            process.stdout.close()


def measure_http(tool: str, quick: bool, clients: Sequence[int], budgets: Sequence[int], iterations: int,
                 inputs: dict[str, int] | None = None) -> str:
    rows = []
    for budget in budgets:
        for busy in (0, 1):
            for concurrency in clients:
                condition = f"{busy}/{concurrency}/{budget}"
                count = 16 if quick else (inputs or {}).get(condition, BENCH_INPUTS["http"][0])
                samples = [http_sample(tool, count, busy, concurrency, f"--call-budget={budget}")
                           for _ in range(iterations)]
                typical = lambda key: statistics.median(sample[key] for sample in samples)
                rows.append([f"{busy}/{concurrency}/{budget}", count, busy, concurrency,
                             budget, f"{typical('throughput'):.3f}",
                             f"{typical('latency_p50_nanos') / 1e6:.6f}",
                             f"{typical('latency_max_nanos') / 1e6:.6f}",
                             format_seconds(typical('run_nanos') / 1e9), int(typical('responses'))])
    return markdown_table(["条件 (計算/クライアント/予算)", "要求数", "計算タスク (0/1)", "クライアント数", "予算", "要求/秒",
                           "応答中央値 (ms)", "応答最大 (ms)", "実行 (秒)", "応答数"], rows)

def measure_first_release(tool: str, quick: bool, temp: Path, noop: Path, large: Path, iterations: int,
                          http_clients: Sequence[int], task_memory_work: int | None = None,
                          http_inputs: dict[str, int] | None = None) -> tuple[str, str]:
    def samples(name: str, arguments: Sequence[object], *options: str) -> list[dict[str, int]]:
        source = benchmark_source(name)
        return [bench_sample(tool, source, arguments, *options) for _ in range(iterations)]

    def typical(rows: list[dict[str, int]], key: str) -> float:
        return statistics.median(row[key] for row in rows)

    def rss_max(rows: list[dict[str, int]]) -> int | None:
        values = [row["rss"] for row in rows if "rss" in row]
        return max(values) if values else None

    sections = ["## 初回リリース版の設定\n\n"
                f"- bench_run: `{tool}`\n- 標本数: {iterations}\n"
                "- handler・tasks・cycle: 比較対象なし。処理系を変えた前後の比較に使う。\n"
                "- 回収の百分位: nearest-rank。各実行で算出した値の中央値。標本数 0 では 0 と表示する。\n"
                "- RSS が — の場合: /usr/bin/time が使えない、または統計を読み取れなかった。"]

    gc_rows = []
    for name in ("cycle", "list", "tree", "eval"):
        arguments = small_arguments(name) if quick else workload_args(name, False, temp / "unused")
        rows = samples(name, arguments)
        gc_rows.append([name, " ".join(arguments),
                        *[f"{typical(rows, key) / 1e6:.6f}" for key in
                          ("pause_p50_nanos", "pause_p95_nanos", "pause_p99_nanos", "pause_max_nanos", "pause_total_nanos")],
                        typical(rows, "collections"), typical(rows, "pause_count"),
                        format_bytes(int(typical(rows, "peak_heap_bytes"))), format_bytes(rss_max(rows))])
    sections.append("## 回収の費用\n\n" + markdown_table(
        ["ベンチマーク", "入力", "p50 (ms)", "p95 (ms)", "p99 (ms)", "最大 (ms)", "合計 (ms)",
         "回収回数", "停止の標本数", "最大ヒープ (bytes)", "最大 RSS (bytes)"], gc_rows))

    work = 100 if quick else BENCH_INPUTS["tasks"][1]
    memory_work = work if task_memory_work is None or quick else task_memory_work
    counts = (10, 20, 40) if quick else (1_000, 10_000, 100_000)
    # main とゲートの一つのタスクは全入力で共通に含む。差分でその固定費を除く。
    baseline = rss_max(samples("tasks", (0, memory_work)))
    task_rows = []
    for count in counts:
        rows = samples("tasks", (count, memory_work))
        rss = rss_max(rows)
        per_task = (rss - baseline) / count if rss is not None and baseline is not None else None
        task_rows.append([count, memory_work, format_seconds(typical(rows, "run_nanos") / 1e9),
                          format_bytes(rss), format_bytes(baseline), "—" if per_task is None else f"{per_task:.2f}"])
    sections.append("## 並行処理でのメモリ\n\n"
                    "一つあたりのメモリは (最大 RSS − 0 タスクの最大 RSS) ÷ 起動数の近似である。"
                    "main とゲートのタスクを含む。負の差も丸めず残し、RSS の揺れとして読む。\n\n" +
                    markdown_table(["タスク数", "各タスクの反復数", "実行 (秒)", "最大 RSS (bytes)",
                                    "0 タスクの RSS (bytes)", "一つあたりの近似 (bytes)"], task_rows))

    default = bench_sample(tool, noop, [])["call_budget"]
    budget_rows = []
    budgets = tuple(dict.fromkeys((max(1, default // 4), max(1, default // 2), default, default * 2, default * 4)))
    for budget in budgets:
        count = counts[0]
        rows = samples("tasks", (count, work), f"--call-budget={budget}")
        budget_rows.append([budget, count, work, format_seconds(typical(rows, "run_nanos") / 1e9)])
    sections.append("## 呼び出しの回数の予算\n\n" + markdown_table(
        ["予算", "タスク数", "各タスクの反復数", "実行 (秒)"], budget_rows))

    lookup_rows = []
    for length in ((100, 1_000) if quick else (10**3, 10**4, 10**5, 10**6, 10**7)):
        count = 1_000 if quick else BENCH_INPUTS["listget"][1]
        baseline_rows = samples("listget", (length, 0))
        rows = samples("listget", (length, count))
        run = typical(rows, "run_nanos") / 1e9
        setup = typical(baseline_rows, "run_nanos") / 1e9
        lookup_rows.append([length, count, format_seconds(run), format_seconds(setup), f"{(run - setup) * 1e9 / count:.3f}"])
    sections.append("## リストの添字の時間\n\n"
                    "一回あたりは、実行時間から 0 回の実行時間を差し引いて回数で割った近似である。"
                    "リストの構築を除くが、疑似乱数、剰余、呼び出し、加算の費用も含む。負の差も残す。\n\n" +
                    markdown_table(["長さ", "回数", "実行 (秒)", "0 回の実行 (秒)", "一回あたりの近似 (ns)"], lookup_rows))

    breakdown = []
    noops = [bench_sample(tool, noop, []) for _ in range(iterations)]
    large_rows = [bench_sample(tool, large, []) for _ in range(iterations)]
    stdlib = typical(noops, "check_nanos")
    for label, rows in (("何もしない main", noops), ("100 関数" if quick else "約 1 万関数", large_rows)):
        breakdown.append([label, *[format_seconds(typical(rows, key) / 1e9) for key in
                                  ("check_nanos", "desugar_nanos", "compile_nanos", "run_nanos", "total_nanos")],
                          format_seconds(stdlib / 1e9), format_seconds((typical(rows, "check_nanos") - stdlib) / 1e9)])
    sections.append("## 起動と検査の内訳\n\n"
                    "標準ライブラリの読み込みと型検査の近似は、main が () を返すだけの検査時間である。"
                    "それ以外の近似は、大きなスクリプトの検査時間との差である。"
                    "読み込み・字句解析・名前解決なども含むので、型検査だけの時間ではない。"
                    "合計は bench_run 内の時間で、OS のプロセス起動と終了は含まない。\n\n" +
                    markdown_table(["対象", "検査 (秒)", "脱糖 (秒)", "コード生成 (秒)", "実行 (秒)", "合計 (秒)",
                                    "標準ライブラリの近似 (秒)", "それ以外の近似 (秒)"], breakdown))
    sections[0] += f"\n- 既定の予算: {default}\n- 回収の係数 (百分率): {noops[0]['trigger_factor_percent']}"
    http_rows = measure_http(tool, quick, http_clients, budgets, iterations, http_inputs)
    return "\n\n".join(sections), http_rows


def measure(
    benitoite: str,
    runtimes: list[Runtime],
    skipped: list[str],
    args: argparse.Namespace,
) -> int:
    revision = git_revision()
    date_label = dt.date.today().isoformat()
    result_path = args.output or RESULTS / f"{date_label}-{revision}.md"
    if result_path.exists() or result_path.with_suffix(".html").exists():
        raise RuntimeError(f"測定記録がすでにある: {result_path}")

    result_path.parent.mkdir(parents=True, exist_ok=True)
    timings: list[dict[str, str]] = []
    startup_rows: list[dict[str, str]] = []
    memory_rows: list[dict[str, str]] = []
    allocation_rows: list[dict[str, str]] = []
    profile_rows: list[str] = []
    bytecode_rows: list[dict[str, str]] = []
    information = collect_system_info()
    iterations = 1 if args.quick else ITERATIONS
    names = NAMES + (FIRST_RELEASE_NAMES if args.first_release else ())
    first_release = ""
    http_rows = "未計測（--first-release を指定していない）。"
    input_rows: list[tuple[str, list[str]]] = []
    interpreter_version = command_output([benitoite, "--version"]) or "unknown"
    skipped = list(skipped)

    with tempfile.TemporaryDirectory(prefix="benitoite-bench-", dir=BENCH) as raw_temp:
        temp = Path(raw_temp)
        noop, large_check, rust_noop_source = generated_sources(temp, 100 if args.quick else 10_000)
        rust_noop: Path | None = None
        rustc = command_path("rustc")
        if rustc is not None and any(runtime.family == "rust" for runtime in runtimes):
            rust_noop = temp / ("noop-rust.exe" if os.name == "nt" else "noop-rust")
            compile_result = subprocess.run(
                [rustc, "--edition=2024", "-O", str(rust_noop_source), "-o", str(rust_noop)],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            if compile_result.returncode != 0:
                detail = compile_result.stderr.decode("utf-8", errors="replace").strip()
                skipped.append(f"Rust 起動測定: 空プログラムのビルドに失敗した: {detail}")
                rust_noop = None

        startup_commands: list[tuple[str, list[str], dict[str, str]]] = [
            ("Benitoite", [benitoite, "run", str(noop)], os.environ.copy())
        ]
        for runtime in runtimes:
            if runtime.family == "rust" and rust_noop is None:
                continue
            startup_commands.append(
                (
                    runtime.name,
                    runtime_noop_command(runtime, temp / "noop", rust_noop),
                    runtime.child_environment(),
                )
            )
        for runtime_name, command, env in startup_commands:
            samples: list[float] = []
            for _ in range(iterations):
                elapsed, _ = measure_one(command, env, f"起動測定 {runtime_name}")
                samples.append(elapsed)
            startup_rows.append({"runtime": runtime_name, "seconds": format_seconds(median(samples))})

        check_samples: list[float] = []
        for _ in range(iterations):
            elapsed, _ = measure_one(
                [benitoite, "check", str(large_check)], os.environ.copy(), "1 万行の check"
            )
            check_samples.append(elapsed)
        startup_rows.append(
            {"runtime": "Benitoite / 100 関数の check" if args.quick else "Benitoite / 約 1 万行の check",
             "seconds": format_seconds(median(check_samples))}
        )

        lines_input = temp / "lines-input.txt"
        generate_lines(lines_input, 100 if args.quick else BENCH_INPUTS["lines"])
        memory_any = False

        for name in names:
            source = benchmark_source(name)
            require_success([benitoite, "check", str(source)])
            bytecode_rows.append(bytecode_row(name, source, args.bytecode_stats))
            check_samples = []
            for _ in range(iterations):
                elapsed, _ = measure_one([benitoite, "check", str(source)], os.environ.copy(), f"{name} check")
                check_samples.append(elapsed)
            check_seconds = median(check_samples)

            workload_arguments = workload_args(name, args.quick, lines_input)
            input_rows.append((name, workload_arguments))
            modes: tuple[str | None, ...] = ("direct", "request") if name in ("println", "lines") else ("direct",)

            for mode in modes:
                benitoite_env = os.environ.copy()
                benitoite_env["BENITOITE_DEV_IO_MODE"] = mode or "direct"
                samples = []
                alloc_samples: list[tuple[int, int, int, int]] = []
                command = [benitoite, "run", str(source), *workload_arguments]
                # 実行時間は計数を含まない既定のビルドで測り、確保と回収は alloc-stats のビルドで別に数える
                # （計数の費用を実行時間に混ぜないため）。確保の回数は実行ごとに変わらないので一回だけ数える。
                for _ in range(iterations):
                    elapsed, _ = measure_one(command, benitoite_env, f"Benitoite {name} ({mode})")
                    samples.append(elapsed)
                if args.benitoite_alloc is not None:
                    alloc_env = dict(benitoite_env)
                    alloc_env["BENITOITE_DEV_ALLOC_STATS"] = "1"
                    _, stderr = measure_one(
                        [args.benitoite_alloc, "run", str(source), *workload_arguments],
                        alloc_env,
                        f"Benitoite {name} ({mode}) alloc-stats",
                    )
                    stats = allocation_stats(stderr)
                    if stats is not None:
                        alloc_samples.append(stats)
                run_seconds = median(samples)
                approximate_seconds = (
                    run_seconds - check_seconds
                    if run_seconds is not None and check_seconds is not None
                    else None
                )
                timings.append(
                    {
                        "benchmark": name,
                        "runtime": "Benitoite",
                        "mode": mode or "direct",
                        "seconds": format_seconds(run_seconds),
                        "check_seconds": format_seconds(check_seconds),
                        "approx": format_seconds(approximate_seconds),
                    }
                )
                allocation_rows.append(
                    {
                        "benchmark": name,
                        "mode": mode or "direct",
                        "allocations": format_bytes(int(statistics.median([row[0] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                        "allocated_bytes": format_bytes(int(statistics.median([row[1] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                        "peak_heap_bytes": format_bytes(int(statistics.median([row[2] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                        "collections": format_bytes(int(statistics.median([row[3] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                    }
                )

                candidates = [("Benitoite", command, benitoite_env)]
                if mode == "direct":
                    for runtime in (runtimes if has_comparators(name) else []):
                        candidates.append(
                            (
                                runtime.name,
                                runtime.command(name, workload_arguments),
                                runtime.child_environment(),
                            )
                        )
                for runtime_name, memory_command_target, env in candidates:
                    wrapped = memory_wrapper(memory_command_target)
                    if wrapped is None:
                        memory_rows.append(
                            {"benchmark": name, "runtime": runtime_name, "mode": mode or "direct", "bytes": "unsupported"}
                        )
                        continue
                    rss_values: list[int] = []
                    for _ in range(iterations):
                        _, _, stderr, _ = run_process(wrapped, env)
                        # OS が計測用の情報を拒んでも、先行する実行時間の計測で対象の終了状態は確認済みである。
                        rss = parse_max_rss(stderr)
                        if rss is not None:
                            rss_values.append(rss)
                    memory_any = memory_any or bool(rss_values)
                    memory_rows.append(
                        {
                            "benchmark": name,
                            "runtime": runtime_name,
                            "mode": mode or "direct",
                            "bytes": format_bytes(max(rss_values) if rss_values else None),
                        }
                    )

            for runtime in (runtimes if has_comparators(name) else []):
                runtime_arguments = workload_arguments
                samples = []
                for _ in range(iterations):
                    elapsed, _ = measure_one(
                        runtime.command(name, runtime_arguments),
                        runtime.child_environment(),
                        f"{runtime.name} {name}",
                    )
                    samples.append(elapsed)
                timings.append(
                    {
                        "benchmark": name,
                        "runtime": runtime.name,
                        "mode": "—",
                        "seconds": format_seconds(median(samples)),
                        "check_seconds": "—",
                        "approx": "—",
                    }
                )

        depth_row = "未計測（--quick の動作確認では上限を探さない）。" if args.quick else measure_call_depth_limit(benitoite)
        if args.first_release:
            first_release, http_rows = measure_first_release(args.bench_run, args.quick, temp, noop, large_check,
                                                            iterations, args.http_clients, args.task_memory_work, args.http_inputs)

        if args.profile:
            samply = command_path("samply")
            if samply is None:
                skipped.append("CPU profile: samply が見つからない")
                profile_rows.append("samply が見つからないため未取得。")
            else:
                profile_dir = RESULTS / "profiles" / f"{date_label}-{revision}"
                profile_dir.mkdir(parents=True, exist_ok=True)
                for name in names:
                    profile_path = profile_dir / f"{name}.json"
                    source = benchmark_source(name)
                    workload_arguments = workload_args(name, args.quick, lines_input)
                    target_env = os.environ.copy()
                    target_env["BENITOITE_DEV_IO_MODE"] = "direct"
                    command = [
                        samply,
                        "record",
                        "--save-only",
                        "--output",
                        str(profile_path),
                        "--",
                        benitoite,
                        "run",
                        str(source),
                        *workload_arguments,
                    ]
                    try:
                        require_success(command, target_env)
                    except RuntimeError as error:
                        profile_rows.append(f"{name}: 取得に失敗した（{error}）。")
                    else:
                        profile_rows.append(f"{name}: `{profile_path.relative_to(ROOT)}`")
        else:
            profile_rows.append("未取得（`--profile` を指定していない）。")

    if not memory_any:
        skipped.append("最大常駐メモリ: /usr/bin/time の形式を読み取れなかった")

    runtime_rows = [{"runtime": "Benitoite", "version": interpreter_version}]
    runtime_rows.extend({"runtime": runtime.name, "version": runtime.version} for runtime in runtimes)
    for line in skipped:
        runtime_rows.append({"runtime": "skip", "version": line})

    replacements = {
        "{{DATE}}": date_label,
        "{{REVISION}}": revision,
        "{{ENVIRONMENT}}": render_environment(information),
        "{{RUNTIMES}}": render_runtimes(runtime_rows),
        "{{INPUTS}}": render_input_rows(input_rows, args.quick),
        "{{ITERATIONS}}": str(iterations),
        "{{CHECK_SIZE}}": "100" if args.quick else "約 1 万",
        "{{RUN_KIND}}": "動作確認（--quick）。性能の判断には使わない。" if args.quick else "本測定",
        "{{FIRST_RELEASE_ROWS}}": first_release,
        "{{HTTP_ROWS}}": http_rows,
        "{{TIMING_ROWS}}": render_timings(timings),
        "{{STARTUP_ROWS}}": render_startup(startup_rows),
        "{{MEMORY_ROWS}}": render_memory(memory_rows),
        "{{ALLOCATION_ROWS}}": render_allocations(allocation_rows),
        "{{BYTECODE_ROWS}}": render_bytecode(bytecode_rows),
        "{{DEPTH_ROWS}}": depth_row,
        "{{PROFILE_ROWS}}": "\n".join(f"- {line}" for line in profile_rows),
    }
    template = (RESULTS / "TEMPLATE.md").read_text(encoding="utf-8")
    for token, value in replacements.items():
        template = template.replace(token, value)
    if "{{" in template:
        raise RuntimeError("TEMPLATE.md に置換されていない値がある")
    try:
        with result_path.open("x", encoding="utf-8", newline="\n") as output:
            output.write(template)
    except FileExistsError as error:
        raise RuntimeError(f"測定記録がすでにある: {result_path}") from error

    print(f"測定記録: {result_path}")
    # 同じ記録からグラフ付きの HTML を作る（report_html.py。一つの記録だけを示す）。
    import report_html

    html_path = report_html.render(result_path)
    print(f"グラフ付きの記録: {html_path}")
    print(f"比較対象: {len(runtimes)} 種類。記録内の skip 行も確認すること。")
    return 0


ALLOC_MISSING = "未計測（--benitoite-alloc に alloc-stats のビルドを指定していない、または統計の行がない）"
BYTECODE_STATS_RE = re.compile(r"^bytecode-stats (.*)$", re.MULTILINE)
DEPTH_START = 10_000


def bytecode_row(name: str, source: Path, tool: str | None) -> dict[str, str]:
    """ベンチマークのバイトコードの大きさ（07-02「測る項目」）。1 命令は 8 バイトである。"""
    if tool is None:
        return {"benchmark": name, "user": "未計測（--bytecode-stats を指定していない）", "total": "—"}
    _, stdout, stderr, code = run_process([tool, str(source)], os.environ.copy(), capture_stdout=True)
    match = BYTECODE_STATS_RE.search(stdout.decode("utf-8", errors="replace"))
    if code != 0 or match is None:
        detail = stderr.decode("utf-8", errors="replace").strip()
        return {"benchmark": name, "user": f"取得に失敗した（{detail}）", "total": "—"}
    fields = dict(item.split("=", 1) for item in match.group(1).split())
    return {
        "benchmark": name,
        "user": f"{fields['user_protos']} 原型 / {fields['user_instrs']} 命令 / {fields['user_consts']} 定数",
        "total": f"{fields['total_protos']} 原型 / {fields['total_instrs']} 命令 / {fields['total_consts']} 定数",
    }


def render_bytecode(rows: list[dict[str, str]]) -> str:
    lines = ["| ベンチマーク | 利用者のコード | 全体（prelude などを含む） |", "|---|---|---|"]
    lines.extend(f"| {row['benchmark']} | {row['user']} | {row['total']} |" for row in rows)
    return "\n".join(lines)


def depth_reached(benitoite: str, depth: int) -> bool | None:
    """`depth.bnt` を既定の上限で実行し、上限に達せずに終われば True、R0901 で止まれば False を返す。"""
    _, _, stderr, code = run_process(
        [benitoite, "run", str(PROGRAMS / "depth.bnt"), str(depth)], os.environ.copy()
    )
    if code == 0:
        return True
    if code == 1 and b"R0901" in stderr:
        return False
    return None


def measure_call_depth_limit(benitoite: str) -> str:
    """末尾でない再帰で、既定の呼び出しの情報の上限（1 GiB）に達する段数を 1% の精度で求める（設計書 07-02「測る項目」）。"""
    low = 0
    high = DEPTH_START
    while True:
        reached = depth_reached(benitoite, high)
        if reached is None:
            return f"測定に失敗した（{high} 段の実行が予期しない終わり方をした）"
        if not reached:
            break
        low = high
        high = high * 2
    while high - low > max(1, low // 100):
        middle = (low + high) // 2
        reached = depth_reached(benitoite, middle)
        if reached is None:
            return f"測定に失敗した（{middle} 段の実行が予期しない終わり方をした）"
        if reached:
            low = middle
        else:
            high = middle
    return f"{low} 段まで実行でき、{high} 段で R0901 になった（既定の上限、`tools/bench/programs/depth.bnt`）。"


def render_environment(information: dict[str, str]) -> str:
    return "\n".join(
        f"- {label}: {information[key]}"
        for key, label in (
            ("cpu", "CPU"),
            ("logical_cpus", "論理 CPU 数"),
            ("memory", "メモリ"),
            ("os", "OS"),
            ("rustc", "rustc"),
        )
    )


def render_runtimes(rows: list[dict[str, str]]) -> str:
    return markdown_table(["処理系", "版または状態"], [[row["runtime"], row["version"]] for row in rows])


def render_inputs() -> str:
    header = "| ベンチマーク | 入力 |\n|---|---:|"
    body = [f"| {name} | {BENCH_INPUTS[name]:,} |" for name in NAMES]
    return "\n".join([header, *body])


def render_timings(rows: list[dict[str, str]]) -> str:
    header = "| ベンチマーク | 処理系 | IO mode | run 中央値 (秒) | check 中央値 (秒) | 検査を差し引いた近似 (秒) |\n|---|---|---|---:|---:|---:|"
    body = [
        f"| {row['benchmark']} | {row['runtime']} | {row['mode']} | {row['seconds']} | {row['check_seconds']} | {row['approx']} |"
        for row in rows
    ]
    return "\n".join([header, *body])


def render_startup(rows: list[dict[str, str]]) -> str:
    header = "| 対象 | 実時間中央値 (秒) |\n|---|---:|"
    body = [f"| {row['runtime']} | {row['seconds']} |" for row in rows]
    return "\n".join([header, *body])


def render_memory(rows: list[dict[str, str]]) -> str:
    header = "| ベンチマーク | 処理系 | IO mode | 最大 RSS (bytes) |\n|---|---|---|---:|"
    body = [
        f"| {row['benchmark']} | {row['runtime']} | {row['mode']} | {row['bytes']} |"
        for row in rows
    ]
    return "\n".join([header, *body])


def render_allocations(rows: list[dict[str, str]]) -> str:
    header = "| ベンチマーク | IO mode | 確保回数の中央値 | 累積確保量の中央値 (bytes) | 最大ヒープ使用量の中央値 (bytes) | 回収回数の中央値 |\n|---|---|---:|---:|---:|---:|"
    body = [
        f"| {row['benchmark']} | {row['mode']} | {row['allocations']} | {row['allocated_bytes']} | {row['peak_heap_bytes']} | {row['collections']} |"
        for row in rows
    ]
    return "\n".join([header, *body])


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benitoite", default="benitoite", help="path to the benitoite executable")
    parser.add_argument("--verify", action="store_true", help="compare small-input output; do not measure")
    parser.add_argument("--profile", action="store_true", help="request samply CPU profiles while measuring")
    parser.add_argument(
        "--benitoite-alloc",
        default=None,
        help="path to a benitoite built with --features alloc-stats (allocation counts only)",
    )
    parser.add_argument(
        "--bytecode-stats",
        default=None,
        help="path to the bytecode_stats example (cargo build --release -p benitoite --examples)",
    )
    parser.add_argument(
        "--skip-comparators",
        action="store_true",
        help="measure Benitoite only (useful when comparison runtimes are unavailable)",
    )
    parser.add_argument("--first-release", action="store_true", help="include first-release workloads and metrics")
    parser.add_argument("--bench-run", help="path to the bench_run example (required by --first-release and --verify)")
    parser.add_argument("--http-clients", type=int, nargs="+", default=[1, 8],
                        help="positive concurrent HTTP client counts (default: 1 8)")
    parser.add_argument("--task-memory-work", type=int, help="iterations per task for RSS scaling only (default: tasks input)")
    parser.add_argument("--http-inputs", type=Path, help="JSON mapping busy/clients/budget to request count")
    parser.add_argument("--quick", action="store_true", help="smoke check: small inputs, one sample, no depth probe")
    parser.add_argument("--output", type=Path, help="new Markdown record path (required by --quick)")
    args = parser.parse_args(argv)
    if args.output is not None and args.output.suffix != ".md":
        parser.error("--output requires a .md path")
    if args.quick and (not args.first_release or args.output is None):
        parser.error("--quick requires --first-release and --output (use a temporary workspace path)")
    if args.quick and args.profile:
        parser.error("--quick and --profile cannot be used together")
    if any(count <= 0 for count in args.http_clients):
        parser.error("--http-clients requires positive integers")
    args.http_clients = list(dict.fromkeys(args.http_clients))
    if args.task_memory_work is not None and args.task_memory_work < 0:
        parser.error("--task-memory-work requires a non-negative integer")
    if args.http_inputs is not None:
        try:
            inputs = json.loads(args.http_inputs.read_text())
            if not isinstance(inputs, dict) or not all(isinstance(k, str) and re.fullmatch(r"[01]/[1-9][0-9]*/[1-9][0-9]*", k)
                    and type(v) is int and v > 0 for k, v in inputs.items()):
                raise ValueError("expected positive counts indexed by busy/clients/budget")
            args.http_inputs = inputs
        except (OSError, ValueError) as error:
            parser.error(f"--http-inputs: {error}")
    if args.first_release or args.verify:
        args.bench_run = command_path(args.bench_run or "target/release/examples/bench_run")
        if args.bench_run is None:
            parser.error("--first-release and --verify require a built bench_run example")
    if args.verify and args.profile:
        parser.error("--verify and --profile cannot be used together")
    if args.verify and args.skip_comparators:
        parser.error("--verify requires at least one comparison runtime")
    return args


def main(argv: Sequence[str] = sys.argv[1:]) -> int:
    args = parse_args(argv)
    executable = command_path(args.benitoite)
    if executable is None:
        print(f"benitoite を見つけられない: {args.benitoite}", file=sys.stderr)
        return 2

    runtimes, skipped = detect_runtimes(args.skip_comparators, args.verify or args.first_release)
    try:
        if args.verify:
            return verify(executable, runtimes, skipped, args.bench_run)
        return measure(executable, runtimes, skipped, args)
    except (OSError, RuntimeError) as error:
        print(f"tools/bench/run.py: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

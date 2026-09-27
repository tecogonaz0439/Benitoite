#!/usr/bin/env python3
"""Verify and measure the Benitoite benchmark programs with Python's stdlib."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import platform
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence


BENCH = Path(__file__).resolve().parent
ROOT = BENCH.parents[1]
PROGRAMS = BENCH / "programs"
RESULTS = BENCH / "results"
NAMES = ("fib", "loop", "list", "tree", "eval", "string", "println", "lines")
ITERATIONS = 10
BENCH_INPUTS = {
    # 2026-09-27 に Apple M4 で Benitoite の実行時間が 1〜3 秒になるように合わせた。
    # string と lines は List の要素数の上限（16,777,216）で抑えられる。string は 1 秒に届かない（約 0.5 秒）。
    # eval は深さ 500 の式を入力の回数だけ評価する。
    "fib": 35,
    "loop": 15_000_000,
    "list": 1_500_000,
    "tree": 22,
    "eval": 30_000,
    "string": 8_000_000,
    "println": 7_000_000,
    "lines": 16_000_000,
}
ALLOC_STATS_RE = re.compile(r"^alloc-stats allocations=(\d+) bytes=(\d+) freed=(\d+)$", re.MULTILINE)


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


def build_ocaml_programs(ocamlc: str, ocamlopt: str) -> None:
    build_dir = PROGRAMS / "ocaml" / "_build"
    build_dir.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
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


def detect_runtimes(skip_comparators: bool) -> tuple[list[Runtime], list[str]]:
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

    rust_bins = PROGRAMS / "rust" / "target" / "release"
    rustc = command_path("rustc")
    rust_missing = [name for name in NAMES if not (rust_bins / name).is_file()]
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
        build_ocaml_programs(ocamlc, ocamlopt)
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


def verify(benitoite: str, runtimes: list[Runtime], skipped: list[str]) -> int:
    if not runtimes:
        raise RuntimeError("--verify には比較対象の処理系が必要である")
    for name in NAMES:
        source = PROGRAMS / f"{name}.bnt"
        require_success([benitoite, "check", str(source)])
        arguments = small_arguments(name)
        expected = require_success([benitoite, "run", str(source), *arguments])
        for runtime in runtimes:
            actual = require_success(runtime.command(name, arguments), runtime.child_environment())
            if actual != expected:
                raise RuntimeError(
                    f"出力が一致しない: {name} / {runtime.name}\n"
                    f"Benitoite: {expected.decode('utf-8', errors='replace')!r}\n"
                    f"比較対象: {actual.decode('utf-8', errors='replace')!r}"
                )
            print(f"verify: {name} / {runtime.name}: OK")
    for line in skipped:
        print(f"skip: {line}")
    return 0


def generated_sources(directory: Path) -> tuple[Path, Path, Path]:
    noop = directory / "noop.bnt"
    noop.write_text("fn main() -> Unit { () }\n", encoding="utf-8")
    large = directory / "large-check.bnt"
    with large.open("w", encoding="utf-8", newline="\n") as output:
        for number in range(10_000):
            output.write(f"fn bench_{number}() -> Int {{ {number} }}\n")
        output.write("fn main() -> Unit { () }\n")
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


def allocation_stats(stderr: bytes) -> tuple[int, int, int] | None:
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


def measure(
    benitoite: str,
    runtimes: list[Runtime],
    skipped: list[str],
    args: argparse.Namespace,
) -> int:
    revision = git_revision()
    date_label = dt.date.today().isoformat()
    result_path = RESULTS / f"{date_label}-{revision}.md"
    if result_path.exists():
        raise RuntimeError(f"測定記録がすでにある: {result_path.relative_to(ROOT)}")

    RESULTS.mkdir(parents=True, exist_ok=True)
    timings: list[dict[str, str]] = []
    startup_rows: list[dict[str, str]] = []
    memory_rows: list[dict[str, str]] = []
    allocation_rows: list[dict[str, str]] = []
    profile_rows: list[str] = []
    bytecode_rows: list[dict[str, str]] = []
    information = collect_system_info()
    interpreter_version = command_output([benitoite, "--version"]) or "unknown"
    skipped = list(skipped)

    with tempfile.TemporaryDirectory(prefix="benitoite-bench-", dir=BENCH) as raw_temp:
        temp = Path(raw_temp)
        noop, large_check, rust_noop_source = generated_sources(temp)
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
            for _ in range(ITERATIONS):
                elapsed, _ = measure_one(command, env, f"起動測定 {runtime_name}")
                samples.append(elapsed)
            startup_rows.append({"runtime": runtime_name, "seconds": format_seconds(median(samples))})

        check_samples: list[float] = []
        for _ in range(ITERATIONS):
            elapsed, _ = measure_one(
                [benitoite, "check", str(large_check)], os.environ.copy(), "1 万行の check"
            )
            check_samples.append(elapsed)
        startup_rows.append(
            {"runtime": "Benitoite / 約 1 万行の check", "seconds": format_seconds(median(check_samples))}
        )

        lines_input = temp / "lines-input.txt"
        generate_lines(lines_input, BENCH_INPUTS["lines"])
        memory_any = False

        for name in NAMES:
            source = PROGRAMS / f"{name}.bnt"
            require_success([benitoite, "check", str(source)])
            bytecode_rows.append(bytecode_row(name, source, args.bytecode_stats))
            check_samples = []
            for _ in range(ITERATIONS):
                elapsed, _ = measure_one([benitoite, "check", str(source)], os.environ.copy(), f"{name} check")
                check_samples.append(elapsed)
            check_seconds = median(check_samples)

            if name == "lines":
                workload_arguments = [str(lines_input)]
            else:
                workload_arguments = [str(BENCH_INPUTS[name])]
            modes: tuple[str | None, ...] = ("direct", "request") if name in ("println", "lines") else ("direct",)

            for mode in modes:
                benitoite_env = os.environ.copy()
                benitoite_env["BENITOITE_DEV_IO_MODE"] = mode or "direct"
                samples = []
                alloc_samples: list[tuple[int, int, int]] = []
                command = [benitoite, "run", str(source), *workload_arguments]
                # 実行時間は計数を含まない既定のビルドで測り、確保と解放は alloc-stats のビルドで別に数える
                # （計数の費用を実行時間に混ぜないため）。確保の回数は実行ごとに変わらないので一回だけ数える。
                for _ in range(ITERATIONS):
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
                        "bytes": format_bytes(int(statistics.median([row[1] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                        "freed": format_bytes(int(statistics.median([row[2] for row in alloc_samples])))
                        if alloc_samples
                        else ALLOC_MISSING,
                    }
                )

                candidates = [("Benitoite", command, benitoite_env)]
                if mode == "direct":
                    for runtime in runtimes:
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
                    for _ in range(ITERATIONS):
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

            for runtime in runtimes:
                if name == "lines":
                    runtime_arguments = [str(lines_input)]
                else:
                    runtime_arguments = [str(BENCH_INPUTS[name])]
                samples = []
                for _ in range(ITERATIONS):
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

        depth_row = measure_call_depth_limit(benitoite)

        if args.profile:
            samply = command_path("samply")
            if samply is None:
                skipped.append("CPU profile: samply が見つからない")
                profile_rows.append("samply が見つからないため未取得。")
            else:
                profile_dir = RESULTS / "profiles" / f"{date_label}-{revision}"
                profile_dir.mkdir(parents=True, exist_ok=True)
                for name in NAMES:
                    profile_path = profile_dir / f"{name}.json"
                    source = PROGRAMS / f"{name}.bnt"
                    workload_arguments = [str(lines_input)] if name == "lines" else [str(BENCH_INPUTS[name])]
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
        "{{INPUTS}}": render_inputs(),
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
        raise RuntimeError(f"測定記録がすでにある: {result_path.relative_to(ROOT)}") from error

    print(f"測定記録: {result_path.relative_to(ROOT)}")
    # 同じ記録からグラフ付きの HTML を作る（report_html.py。一つの記録だけを示す）。
    import report_html

    html_path = report_html.render(result_path)
    print(f"グラフ付きの記録: {html_path.relative_to(ROOT)}")
    print(f"比較対象: {len(runtimes)} 種類。記録内の skip 行も確認すること。")
    return 0


ALLOC_MISSING = "未計測（--benitoite-alloc に alloc-stats のビルドを指定していない、または統計の行がない）"
BYTECODE_STATS_RE = re.compile(r"^bytecode-stats (.*)$", re.MULTILINE)
DEPTH_START = 10_000


def bytecode_row(name: str, source: Path, tool: str | None) -> dict[str, str]:
    """ベンチマークのバイトコードの大きさ（07-02「命令の長さ」）。1 命令は 8 バイトである。"""
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
    """末尾でない再帰で、既定の呼び出しの情報の上限（1 GiB）に達する段数を 1% の精度で求める（ADR 0030）。"""
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
    header = "| 処理系 | 版または状態 |\n|---|---|"
    body = [f"| {row['runtime']} | {row['version']} |" for row in rows]
    return "\n".join([header, *body])


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
    header = "| ベンチマーク | IO mode | 確保回数の中央値 | 確保量の中央値 (bytes) | 解放回数の中央値 |\n|---|---|---:|---:|---:|"
    body = [
        f"| {row['benchmark']} | {row['mode']} | {row['allocations']} | {row['bytes']} | {row['freed']} |"
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
    args = parser.parse_args(argv)
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

    runtimes, skipped = detect_runtimes(args.skip_comparators)
    try:
        if args.verify:
            return verify(executable, runtimes, skipped)
        return measure(executable, runtimes, skipped, args)
    except (OSError, RuntimeError) as error:
        print(f"tools/bench/run.py: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

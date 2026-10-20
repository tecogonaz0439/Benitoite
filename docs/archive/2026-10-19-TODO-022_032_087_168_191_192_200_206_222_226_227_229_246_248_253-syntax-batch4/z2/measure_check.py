"""RV3 の成功する型検査の入力を、二つの release CLI で交互に測る。"""
import hashlib
import json
import platform
from pathlib import Path
import statistics
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def main():
    before, after = (Path(arg).resolve() for arg in sys.argv[1:])
    inputs = HERE / "perf-inputs"
    inputs.mkdir(exist_ok=True)
    paths = []
    for n in (250, 500, 900):
        source = "function chain(n: Integer) -> Integer\n bind x0 <- n\n"
        source += "".join(f" bind x{i} <- x{i-1} + {i}\n" for i in range(1, n + 1))
        source += f" return x{n}\nend function\nfunction main() -> Unit\nend function\n"
        path = inputs / f"chain-{n}.bnt"
        path.write_text(source)
        paths.append(path)
    path = inputs / "arithmetic-400.bnt"
    path.write_text("function arithmetic(x: Integer) -> Integer\n" + "".join(f" bind _ <- x + x * {i}\n" for i in range(1, 401)) + " return x\nend function\nfunction main() -> Unit\nend function\n")
    paths.append(path)
    if hashlib.sha256(before.read_bytes()).digest() == hashlib.sha256(after.read_bytes()).digest():
        raise RuntimeError("baseline and candidate binaries are identical; rebuild the candidate")
    cpu = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], text=True, capture_output=True)
    report = {"platform": platform.platform(), "machine": platform.machine(),
              "cpu": cpu.stdout.strip() if cpu.returncode == 0 else "unavailable: sandbox denies sysctl",
              "rustc": subprocess.check_output(["rustc", "--version"], text=True).strip(),
              "baseline": subprocess.check_output(["git", "rev-parse", "be7dc868"], cwd=ROOT, text=True).strip(),
              "candidate_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "candidate_rust_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "--", "crates/benitoite/src"], cwd=ROOT)).hexdigest(),
              "binaries_sha256": {"before": hashlib.sha256(before.read_bytes()).hexdigest(), "after": hashlib.sha256(after.read_bytes()).hexdigest()},
              "samples_per_case": 11, "warmups_per_state_case": 2, "cases": []}
    for path in paths:
        samples = {"before": [], "after": []}
        for name, binary in (("before", before), ("after", after)):
            for _ in range(2):
                subprocess.run([str(binary), "check", str(path)], check=True, capture_output=True)
        for i in range(11):
            order = [("before", before), ("after", after)]
            if i % 2:
                order.reverse()
            for name, binary in order:
                start = time.perf_counter_ns()
                result = subprocess.run([str(binary), "check", str(path)], capture_output=True)
                elapsed = (time.perf_counter_ns() - start) / 1e6
                if result.returncode:
                    raise RuntimeError(result.stderr.decode())
                samples[name].append(elapsed)
        case = {"input": str(path.relative_to(HERE)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "samples_ms": samples}
        for name, values in samples.items():
            q1, _, q3 = statistics.quantiles(values, n=4)
            case[name] = {"median_ms": statistics.median(values), "iqr_ms": q3 - q1, "min_ms": min(values), "max_ms": max(values)}
        report["cases"].append(case)
        print(path.name, case["before"], case["after"], flush=True)
    (HERE / "check-timings.json").write_text(json.dumps(report, indent=2) + "\n")

if __name__ == "__main__":
    main()

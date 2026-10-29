"""別機の最終ログと試作のソースを照合する。Lean は起動しない。"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PAIRS = [
    ("Contracts.lean", "contracts-final.log"),
    ("FullTypes.lean", "full-types-final.log"),
]


def main():
    report = {"runs": [], "ok": True}
    for source, logfile in PAIRS:
        data = (ROOT / source).read_bytes()
        text = data.decode()
        log = (ROOT / logfile).read_text()
        declared = re.findall(r"^\s*theorem\s+([^\s:{(]+)", text, re.M)
        printed = re.findall(r"^#print axioms (\S+)", text, re.M)
        audited = re.findall(r"^'([^']+)' (?:depends on axioms:|does not depend on any axioms)", log, re.M)
        axioms = set()
        for group in re.findall(r"depends on axioms: \[([^]]*)\]", log):
            axioms.update(x.strip() for x in group.split(",") if x.strip())
        result = re.search(r"^== run-lean: exit (\d+), elapsed (\d+)s, top-mem-peak (\d+)MB.*$", log, re.M)
        rss = re.search(r"(\d+)\s+maximum resident set size", log)
        real = re.search(r"([\d.]+) real\s+([\d.]+) user\s+([\d.]+) sys", log)
        errors = re.findall(r"^.*(?:error:|error\(|warning:).*$", log, re.M)
        banned_source = re.findall(r"\b(?:sorry|admit|axiom|native_decide)\b", text)
        ok = (result is not None and result[1] == "0" and not errors and not banned_source
              and len(declared) == len(printed) == len(audited)
              and set(printed) == set(audited)
              and axioms <= {"propext", "Classical.choice", "Quot.sound"})
        entry = {
            "source": source, "sha256": hashlib.sha256(data).hexdigest(),
            "log": logfile, "theorems": len(declared), "audited": len(audited),
            "axioms": sorted(axioms), "errors_or_warnings": errors,
            "banned_source_tokens": banned_source,
            "last_line": result[0] if result else None,
            "exit": int(result[1]) if result else None,
            "elapsed_seconds": int(result[2]) if result else None,
            "top_mem_peak_mb": int(result[3]) if result else None,
            "maximum_rss_bytes": int(rss[1]) if rss else None,
            "maximum_rss_mib": round(int(rss[1]) / 1048576, 2) if rss else None,
            "lean_real_seconds": float(real[1]) if real else None,
            "command": f"zsh work/m013/remote-lean.sh SB {source} 6144 180",
            "memory_limit_mib": 6144, "time_limit_seconds": 180, "ok": ok,
        }
        report["runs"].append(entry)
        report["ok"] = report["ok"] and ok
    (ROOT / "qa.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not report["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

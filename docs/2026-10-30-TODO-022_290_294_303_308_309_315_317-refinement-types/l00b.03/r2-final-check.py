"""レビュー対応後の入力・固定対象・文書を、ビルドを重ねず照合する。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = Path(tempfile.gettempdir())


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    frozen = json.loads((HERE / "r2-inputs.json").read_text())
    assert all(sha(ROOT / n) == h for n, h in frozen.items())
    start = json.loads((RAW / "l00b03-r2-start.json").read_text())
    allowed = {"formal/Benitoite/Release/Refinement/Context/" + n + ".lean" for n in ("WF", "Facts", "Declarations", "Capture")}
    allowed.add(str((HERE.parent / "l00b.02/signatures.md").relative_to(ROOT)))
    changed, protected = [], []
    for n, h in start["files"].items():
        p = ROOT / n
        if p.exists() and sha(p) == h:
            continue
        changed.append(n)
        if n in allowed or (p.parent == HERE and not p.name.startswith("rv-")):
            continue
        protected.append(n)
    assert not protected, protected
    links, broken, absolute = 0, [], []
    documents = [HERE / "signatures.md", HERE / "results.md", HERE / "large-records.md"]
    # 最終の記録はこの検査の末尾で書く。
    for n in ("r2-final-check.json", "r2-delivery.json"):
        if not (HERE / n).exists():
            (HERE / n).write_text("{}\n")
    for p in documents:
        text = p.read_text()
        for target in re.findall(r"\[[^\]\n]+\]\(([^)\n]+)\)", text):
            target = target.strip().strip("<>").split("#", 1)[0]
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            links += 1
            if target.startswith("/"):
                absolute.append(target)
            elif not (p.parent / target).exists():
                broken.append({"file": str(p.relative_to(ROOT)), "link": target})
    assert not broken and not absolute, (broken, absolute)
    oversized = [p.name for p in HERE.iterdir() if p.is_file() and p.stat().st_size > 100_000]
    assert not oversized, oversized
    # レビューの原文と過去の生出力はそのままにする。
    for p in [HERE / "signatures.md", HERE / "results.md", HERE / "large-records.md"] + list(HERE.glob("r2-*")):
        if p.is_file():
            text = p.read_text()
            assert str(ROOT) not in text and str(Path.home()) not in text, p.name
    commands = json.loads((HERE / "r2-commands.json").read_text())
    assert len(commands) == 4 and all(c["exit"] == 0 for c in commands)
    for c in commands:
        output = c["output"]
        path = RAW / output["name"] if output["storage"] == "<tmp>" else HERE / output["name"]
        assert sha(path) == output["sha256"] and path.stat().st_size == output["bytes"]
        if c["input_sha256"]:
            assert sha(ROOT / "formal" / c["command"][-1]) == c["input_sha256"]
    now = datetime.datetime.now(datetime.timezone.utc)
    began = datetime.datetime.fromisoformat(start["started_utc"].replace("Z", "+00:00"))
    delivery = {"started_utc": began.isoformat(), "finished_utc": now.isoformat(),
                "elapsed_seconds": (now - began).total_seconds(),
                "elapsed_minutes": (now - began).total_seconds() / 60,
                "active_time_separated": False, "rss": "未取得（計画上の非採取）",
                "git": "未実行", "work": "未実行", "l00b04": "未着手"}
    (HERE / "r2-delivery.json").write_text(json.dumps(delivery, ensure_ascii=False, indent=2) + "\n")
    artifacts = sorted(p.name for p in HERE.iterdir() if p.name.startswith("r2-") and p.is_file())
    output = {"formal_inputs_unchanged": len(frozen), "protected_changes": protected,
              "existing_files_changed": sorted(changed), "new_review_response_artifacts": artifacts,
              "relative_links": links, "broken_links": broken, "absolute_links": absolute,
              "oversized_change_records": oversized,
              "artifact_hashes": {p.name: sha(p) for p in HERE.iterdir() if p.is_file() and
                                  (p.name in ("boundary.lean", "signatures.md", "results.md") or
                                   (p.name.startswith("r2-") and p.name != "r2-final-check.json"))},
              "finished_utc": now.isoformat()}
    (HERE / "r2-final-check.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print("検査後の入力変更0、固定対象の変更0、リンク切れ0。外側", round(delivery["elapsed_minutes"], 2), "分。")


if __name__ == "__main__":
    main()

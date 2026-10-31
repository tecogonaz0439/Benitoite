"""ビルドを繰り返さず、検査後の入力・文書・新規ファイルの一覧を照合する。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    inputs = json.loads((HERE / "inputs-final.json").read_text())
    assert all((ROOT / n).exists() and sha(ROOT / n) == h for n, h in inputs.items())
    start = json.loads((Path(tempfile.gettempdir()) / "benitoite-l00b03-inputs-start.json").read_text())
    changed = [n for n, h in start["files"].items() if n != "formal/Benitoite.lean" and
               (not (ROOT / n).exists() or sha(ROOT / n) != h)]
    assert not changed, changed
    req = HERE.parent / "reviews/RV-L00b.03-request.md"
    documents = [HERE / n for n in ("signatures.md", "results.md", "public-api.md", "large-records.md")] + [req]
    links, broken, absolute = 0, [], []
    for p in documents:
        content = p.read_text()
        assert str(ROOT) not in content and str(Path.home()) not in content
        for target in re.findall(r"\[[^\]\n]+\]\(([^)\n]+)\)", content):
            target = target.strip().strip("<>").split("#", 1)[0]
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            links += 1
            if target.startswith("/"):
                absolute.append(target)
            elif not (p.parent / target).exists():
                broken.append({"file": str(p.relative_to(ROOT)), "link": target})
    assert not broken and not absolute, (broken, absolute)
    sources = json.loads((HERE / "source-changes.json").read_text())
    new = [x["path"] for x in sources if x["before"] is None]
    artifacts = sorted(p.name for p in HERE.iterdir() if p.is_file())
    missing = [n for n in new + ["l00b.03/" + a for a in artifacts] if n not in req.read_text()]
    assert not missing, missing
    oversized = [p.name for p in HERE.iterdir() if p.is_file() and p.stat().st_size > 100_000]
    assert not oversized, oversized
    for p in HERE.iterdir():
        if p.suffix in (".py", ".lean", ".md", ".json", ".txt", ".log"):
            data = p.read_text()
            assert str(ROOT) not in data and str(Path.home()) not in data, p.name
    commands = json.loads((HERE / "commands.json").read_text())
    assert len(commands) == 8 and all(c["exit"] == 0 for c in commands)
    config = (ROOT / "formal/lakefile.toml").read_text()
    assert 'moreLeanArgs = ["-M", "12288"]' in config
    assert all(c["command"] == ["lake", "build"] or c["command"][3:5] == ["-M", "12288"] for c in commands)
    for c in commands:
        item = c["output"]
        p = Path(tempfile.gettempdir()) / item["name"] if item["storage"] == "<tmp>" else HERE / item["name"]
        assert p.stat().st_size == item["bytes"] and sha(p) == item["sha256"]
    # 検査後に変えていない入力の保存。自己の出力と終了時刻は除く。
    artifact_inputs = {p.name: sha(p) for p in sorted(HERE.iterdir())
                       if p.is_file() and p.name not in ("final-check.json", "delivery.json")}
    finished = datetime.datetime.now(datetime.timezone.utc)
    began = datetime.datetime.fromisoformat("2026-10-31T07:14:55+00:00")
    delivery = {"started_utc": began.isoformat(), "finished_utc": finished.isoformat(),
                "elapsed_seconds": (finished - began).total_seconds(),
                "elapsed_minutes": (finished - began).total_seconds() / 60,
                "active_time_separated": False, "rss": "未取得（計画上の非採取）",
                "git": "未実行", "work": "取りまとめが担当するため未実行",
                "next": "L00b.04 は未着手。独立レビューと受け入れは取りまとめ・設計者が担当する"}
    (HERE / "delivery.json").write_text(json.dumps(delivery, ensure_ascii=False, indent=2) + "\n")
    final = {"checked_relative_links": links, "broken_links": broken, "absolute_links": absolute,
             "formal_inputs_unchanged": len(inputs), "protected_changes": changed,
             "request_lists_all_new_files": True, "new_production_files": new,
             "new_change_files": artifacts + ["reviews/RV-L00b.03-request.md"],
             "oversized_change_records": oversized, "commands_all_passed": len(commands),
             "artifact_inputs": artifact_inputs, "delivery_sha256": sha(HERE / "delivery.json"),
             "finished_utc": finished.isoformat()}
    (HERE / "final-check.json").write_text(json.dumps(final, ensure_ascii=False, indent=2) + "\n")
    print("相対リンク", links, "件、切れ0。新規ファイル一覧の漏れ0。検査後の入力変更0。")
    print("外側の時間", round(delivery["elapsed_minutes"], 2), "分。")


if __name__ == "__main__":
    main()

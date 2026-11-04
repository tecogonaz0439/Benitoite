"""再開2の復元、保持した処置、二つの開始状態とのコメント限定の差を照合する。"""
import hashlib
import json
from inventory import HERE, ROOT, digest, write


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def uncomment(text):
    """入れ子のブロックコメントと行コメントを除く。文字列の内容は保つ。"""
    out, i, depth = [], 0, 0
    while i < len(text):
        if depth:
            if text.startswith("/-", i):
                depth += 1
                i += 2
            elif text.startswith("-/", i):
                depth -= 1
                i += 2
            else:
                i += 1
        elif text.startswith("/-", i):
            depth = 1
            i += 2
        elif text.startswith("--", i):
            i = text.find("\n", i)
            if i == -1:
                break
        elif text[i] == '"':
            start = i
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            out.append(text[start:i])
        else:
            out.append(text[i])
            i += 1
    assert depth == 0
    return "".join(out)


def reverse(text, patches):
    for p in reversed(patches):
        assert text.count(p["after"]) == 1, p["after"][:100]
        text = text.replace(p["after"], p["before"])
    return text


def check(tmp):
    rec = json.loads((HERE / "resume2-restoration.json").read_text())
    initial = json.loads((tmp / "resume-initial.json").read_text())
    resume2 = json.loads((tmp / "resume2-initial.json").read_text())
    baseline = json.loads((tmp / "b-work-inputs.json").read_text())
    # 保持するσと三箇所の文言だけを逆変換し、再開1開始時の全文ハッシュを照合する。
    for r in rec["retained"]:
        text = reverse((ROOT / r["file"]).read_text(), r["retained_patches"])
        assert sha(text) == r["initial_sha256"] == initial[r["file"]]
    for r in rec["comments"]:
        assert digest(ROOT / r["file"])["sha256"] == initial[r["file"]] == baseline[r["file"]]["sha256"]
    # 復元の全差分を保存した断片から再構築して、再開2開始時とも一致させる。
    for r in rec["documents"]:
        text = (ROOT / r["file"]).read_text()
        for part in r["patch_parts"]:
            for p in json.loads((HERE / part).read_text()):
                assert text.count(p["after"]) == 1
                text = text.replace(p["after"], p["before"])
        assert sha(text) == resume2[r["file"]]
    audited_versions = {}
    for r in rec["comments"]:
        text = (ROOT / r["file"]).read_text()
        audited = text
        for before, after in r["replacements"].items():
            assert audited.count(before) == 1
            audited = audited.replace(before, after)
        assert sha(audited) == resume2[r["file"]]
        assert uncomment(text) == uncomment(audited)
        audited_versions[r["file"]] = {"bytes": len(audited.encode()), "sha256": sha(audited)}
    b_edits = {r["file"]: r for r in rec["b_work_comment_edits"]}
    formal = []
    for f, old in baseline.items():
        if not f.startswith("formal/"):
            continue
        p = ROOT / f
        assert p.exists(), f
        if digest(p) == old:
            continue
        assert f in b_edits, f
        text = p.read_text()
        previous = reverse(text, b_edits[f]["retained_patches"])
        assert sha(previous) == old["sha256"], f
        assert uncomment(previous) == uncomment(text), f
        formal.append({"file": f, "b_work": old, "current": digest(p),
                       "noncomment_sha256": sha(uncomment(text))})
    assert set(b_edits) == {r["file"] for r in formal}
    assert not [str(p.relative_to(ROOT)) for p in (ROOT / "formal").rglob("*.lean")
                if ".lake" not in p.parts and str(p.relative_to(ROOT)) not in baseline]
    report = {"b_work": "70d726b70b6cb4cbf5abace21d377f6ae155b512",
              "baseline_manifest": digest(tmp / "b-work-inputs.json"),
              "resume1_initial_manifest": digest(tmp / "resume-initial.json"),
              "resume2_initial_manifest": digest(tmp / "resume2-initial.json"),
              "formal_inputs_compared": sum(f.startswith("formal/") for f in baseline),
              "b_work_differences": formal, "definition_statement_proof_changes": 0,
              "restored_occurrences": sum(r["restored_occurrences"] for r in rec["documents"] + rec["comments"]),
              "audit_reuse": "再開1の監査入力との不一致7ファイルはコメントの復元だけ。逆変換の全文ハッシュとコメント外の一致で接続する"}
    # 再開1が挿入した誤記だけを検索する。復元した既存の文言は改めない。
    paths = [ROOT / r["file"] for r in rec["documents"]]
    paths += [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    patterns = ["Certificate.Entails", "入力rho", "変更前の", "採用済みの定数警告",
                "閉じた二種類は、閉じた二種類の成功"]
    for pattern in patterns:
        assert not [str(p.relative_to(ROOT)) for p in paths if pattern in p.read_text()], pattern
    report["new_error_patterns_absent"] = patterns
    write(HERE / "resume2-source-check.json", report)
    return audited_versions

#!/usr/bin/env python3
"""保存した全入力を順に読み、入口失敗と再出力の影響を照合する。"""
import hashlib
import json
from pathlib import Path
import re
import runpy
import shutil
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
READER = runpy.run_path(str(ROOT / "crates/benitoite/tests/desugar_export/check_named.py"))


def require(value, message):
    if not value:
        raise AssertionError(message)


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def rows(path):
    # 全corpus二組をPythonのオブジェクトとして同時に保持しない。
    text = path.read_text()
    marker = re.search(r'"inputs"\s*:\s*\[', text)
    require(marker, "inputs missing")
    index = marker.end()
    decoder = json.JSONDecoder()
    while True:
        while text[index].isspace() or text[index] == ',':
            index += 1
        if text[index] == ']':
            return
        value, index = decoder.raw_decode(text, index)
        yield value


def redact(value):
    return json.loads(json.dumps(value).replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>"))


def before():
    expected = {(i["group"], i["name"]): i for i in READER["read"](READER["MANIFEST"])["programs"]}
    missing, no_main = [], []
    corpus = ROOT / "target/k10.3-before/named-programs-corpus.json"
    count = 0
    for item in rows(corpus):
        count += 1
        if "scopeAcceptance" not in item:
            missing.append(item)
        if not any(reason.startswith("entry: NoMainFile") for reason in item["excluded"]):
            continue
        entry = expected[item["group"], item["name"]]
        require(item["excluded"] != entry["excluded"], "old literal comparison unexpectedly agrees")
        normalize = READER["relocation_independent_routing"]
        require(normalize(item)["excluded"] == normalize(entry)["excluded"], item["name"])
        # 同じbasenameでも異なる相対位置を許さない。絶対位置と相対位置の双方を検査する。
        for wrong in ("crates/benitoite/testdata/wrong/" + Path(item["name"]).name,
                      "/elsewhere/crates/benitoite/testdata/wrong/" + Path(item["name"]).name):
            altered = {**item, "excluded": ['entry: NoMainFile { dir: ' + json.dumps(wrong) + ' }']}
            try:
                normalize(altered)
            except AssertionError:
                pass
            else:
                raise AssertionError("wrong relative location accepted")
        no_main.append(dict(group=item["group"], name=item["name"], normalized=normalize(item)["excluded"]))
    require(len(missing) == len(no_main) == 3, "unexpected missing/NoMainFile count")
    require([i["name"] for i in missing] == [i["name"] for i in no_main], "different missing set")
    result = dict(inputs=count, missing=missing, noMainComparisons=no_main,
                  oldLiteralComparisonsFailed=3, normalizedComparisonsPassed=3,
                  wrongRelativeLocationRejected=6)
    (OUT / "missing-and-exclusions.json").write_text(json.dumps(redact(result), ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(dict(inputs=count, missing=len(missing), noMain=len(no_main), negativeChecks=6)))


def compare():
    original = ROOT / "target/desugar-diff/k10.3"
    new = ROOT / "target/desugar-diff/k10.3-reexport"
    baseline = json.loads((OUT / "initial-state.json").read_text())["artifacts"]
    changes, same, extra = [], [], []
    for p in sorted(new.rglob('*')):
        if not p.is_file():
            continue
        relative = p.relative_to(new)
        target = original / relative
        current_hash = digest(p)
        prior = baseline.get(str(target.relative_to(ROOT)))
        if prior is None:
            extra.append(str(relative))
        elif current_hash != prior["sha256"]:
            changes.append(dict(path=str(relative), before=prior,
                                after=dict(bytes=p.stat().st_size, sha256=current_hash)))
        else:
            same.append(str(relative))
    require([c['path'] for c in changes] == ['named-programs-corpus.json'], "unexpected changed files")
    require(not extra, "unexpected new export files")
    old_path = ROOT / "target/k10.3-before/named-programs-corpus.json"
    new_path = new / "named-programs-corpus.json"
    # 入力以外のヘッダと末尾もバイトで同じであることを照合する。
    old_text, new_text = old_path.read_text(), new_path.read_text()
    marker = '"inputs":['
    require(old_text.split(marker, 1)[0] == new_text.split(marker, 1)[0], "header changed")
    require(old_text.rsplit('],', 1)[-1] == new_text.rsplit('],', 1)[-1], "trailer changed")
    del old_text, new_text
    fixed, total = [], 0
    empty = dict(patterns=[], hosts=[], limits=dict(body=dict(operations=16384, items=512),
                                                   whole=dict(operations=65536, items=2048)))
    from itertools import zip_longest
    for old, item in zip_longest(rows(old_path), rows(new_path)):
        require(old is not None and item is not None, "input count changed")
        total += 1
        require('scopeAcceptance' in item, "scopeAcceptance missing after fix")
        if 'scopeAcceptance' not in old:
            # 空の解析表と四上限は、実装から生成し直さない独立期待値である。
            require(item['scopeAcceptance'] == empty, "entry failure acceptance differs")
            fixed.append(item['name'])
            item = {k: v for k, v in item.items() if k != 'scopeAcceptance'}
        require(old == item, f"unrelated input change: {old['name']}")
    require(len(fixed) == 3 and total == 1792, "fixed input count differs")
    result = dict(changed=changes, unchanged=same, extra=extra, inputsCompared=total, fixed=fixed,
                  installed=[c['path'] for c in changes])
    (OUT / "reexport-comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    for change in changes:
        shutil.copy2(new / change['path'], original / change['path'])
    # collect は再実行しない。修理した一ファイルの同定だけを更新し、元の記録を保持する。
    manifest_path = ROOT / 'target/interval-diff/k10.3/input-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    changed_rows = []
    for row in manifest['artifacts']:
        if row['root'] == 'desugar' and row['path'] == 'named-programs-corpus.json':
            require(row['sha256'] == changes[0]['before']['sha256'], 'frozen original hash differs')
            changed_rows.append(dict(before=dict(row)))
            row.update(changes[0]['after'])
            changed_rows[-1]['after'] = dict(row)
    require(len(changed_rows) == 1, 'input manifest row missing or duplicated')
    shutil.copy2(manifest_path, ROOT / 'target/k10.3-before/input-manifest.json')
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(',', ':')) + '\n')
    (OUT / 'input-manifest-update.json').write_text(json.dumps(dict(
        changedRows=changed_rows, beforeSha256=digest(ROOT / 'target/k10.3-before/input-manifest.json'),
        afterSha256=digest(manifest_path), reason='入口失敗三入力の必須欄の修理。期待値と残る凍結入力は不変'),
        ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(inputs=total, fixed=fixed, changed=[c['path'] for c in changes], unchanged=len(same))))


if __name__ == "__main__":
    {"before": before, "compare": compare}[sys.argv[1]]()

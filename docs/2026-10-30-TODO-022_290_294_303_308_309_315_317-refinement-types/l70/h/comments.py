# -*- coding: utf-8 -*-
"""段で足した・変えた Lean のモジュールのコメントの工程 ID の検査（L70.46 (e)、TODO-317）。

対象は段の開始版から最終版までに足した・変えた formal/ の .lean（削除したものを除く）。コメント（`--` の行と `/- -/`）の中の
工程・作業・判断・問いの番号（段・単位・群・再開・レビュー・決定・義務・問いなど）を探す。群 H の開始版（B_WORK）の
同じファイルと今の作業木の両方を数え、今の作業木で0件であることを確かめる。記録は comments.json。
使い方: python3 comments.py"""
import collections
import json
from pathlib import Path
import re
from support import B_STAGE, B_WORK, HERE, ROOT, digest, git, write

PATTERN = re.compile(
    r"(?<![A-Za-z0-9_.`])(L[0-9]{2}[ab]?(?:\.[0-9]+[a-z]?)?|R[0-9]{2}[ab]?|K[0-9]{1,2}|V[0-9]{2}|D[0-9]{2}|U0[0-9]|"
    r"J[0-9]{2}-[0-9]+|O[0-9]{3}|RV-[A-Za-z0-9.\-]+|F-REG|F-CONN|F-LOCAL|TODO-[0-9]{3}|DET-[A-Z]?[0-9]+|H[0-9]{2}|"
    r"S[0-9]{2}|Q[0-9]{1,2}|E[0-9]\.[0-9]|PL[0-9][a-d]?|F[0-9]{2}|C[0-9]{2}|G[0-9]{2}|M[0-9]{2}|A-L|W-L|W-P)(?![A-Za-z0-9_])"
    r"|(?<![A-Za-z0-9_])l[0-9]{2}[a-z]?/|resume[0-9]+|第[0-9]+弾|案 ?[A-D](?![A-Za-z0-9])|群 ?[A-Z][0-9]?(?![A-Za-z0-9])"
    r"|再開[0-9]+|問 ?[0-9]+|決定の判断 ?[0-9]+|段 ?[A-Z](?![A-Za-z0-9])|plan-[a-z0-9-]+")
COMMENT = re.compile(r"/-.*?-/|--[^\n]*", re.S)


def hits(text):
    found = []
    for m in COMMENT.finditer(text):
        for h in PATTERN.finditer(m.group()):
            found.append((text.count("\n", 0, m.start() + h.start()) + 1, h.group()))
    return found


def main():
    status = git("diff", "--name-status", "-M", B_STAGE, "--", "formal").splitlines()
    files = sorted({line.split("\t")[-1] for line in status if not line.startswith("D")
                    and line.split("\t")[-1].endswith(".lean")})
    before, after = {}, {}
    for f in files:
        try:
            old = git("show", f"{B_WORK}:{f}")
        except Exception:
            old = ""
        b, a = hits(old), hits((ROOT / f).read_text())
        if b:
            before[f] = b
        if a:
            after[f] = a
    tokens = collections.Counter(re.sub(r"[0-9]+", "N", t) for v in before.values() for _, t in v)
    record = {"base": B_STAGE, "group_base": B_WORK, "files": len(files),
              "before": {"hits": sum(len(v) for v in before.values()), "files": len(before), "tokens": dict(tokens),
                         "by_file": {f: [f"{line}:{t}" for line, t in v] for f, v in before.items()}},
              "after": {"hits": sum(len(v) for v in after.values()), "files": len(after)},
              "pattern_sha256": __import__("hashlib").sha256(PATTERN.pattern.encode()).hexdigest(),
              "inputs": {"comments.py": digest(Path(__file__))}}
    assert not after, after
    write(HERE / "comments.json", record)
    print(json.dumps({"files": len(files), "before": record["before"]["hits"], "before_files": len(before),
                      "after": 0}, ensure_ascii=False))


if __name__ == "__main__":
    main()

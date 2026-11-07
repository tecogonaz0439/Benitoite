# -*- coding: utf-8 -*-
"""信頼条件の構造体の段の開始版と最終版の比較（RV-L70.h の中2 の処置）。

主定理の仮定の信頼条件 `Builtins.CoreAssumptions` と `Builtins.TargetAgreement`、およびそれらが `toX` の欄で含む親の
構造体（`SubstitutionAssumptions`・`ValueAssumptions`・`TypeAssumptions`・`ExternalAssumptions`・`ResponseAssumptions`）
について、次を開始版と最終版の書き出し（stage.py の base-*.log・final-*.log）で比べる。

1. 構造体の欄の列と構成子の列。欄・構成子・親の構造体が増えていれば、新しい信頼条件の候補として一覧にする。
2. 各欄（射影）の型と構成子の型の印字のハッシュ。
3. 欄の型と構成子の型が参照する定数の閉包（型の定数、定義・opaque の本体の定数、帰納型の構成子を辿る。定理は型だけを
   辿る。`Benitoite` の名前に限る）の各定数の状態（同じ・型が変わった・本体が変わった・構成子の列が変わった、片方の
   閉包だけにあるものは、他方の環境にもない「足した」「削除した」と、他方の環境にはある「閉包に入った」「閉包から外れた」）。
   欄の型の印字が同じでも、参照先の定義が変わっていれば欄の意味は変わる。

記録は --out（既定 ../h3）の trust.json と trust.md。閉包の全一覧は --scratch に置き、大きさと SHA-256 を残す。
使い方: python3 trust.py --tmp <一時領域> [--out <記録>] [--scratch <場所>]"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import L70, digest, private_key, write
import stage

R = "Benitoite.Release.Refinement."
ROOTS = [R + "Builtins.CoreAssumptions", R + "Builtins.TargetAgreement"]
STATE_ORDER = ["同じ", "型が変わった", "本体が変わった", "構成子の列が変わった", "足した", "閉包に入った", "削除した",
               "閉包から外れた"]


def structures(nodes):
    """根の構造体と、`toX` の欄で含む親の構造体（推移的）。"""
    out, pending = [], list(ROOTS)
    while pending:
        s = pending.pop(0)
        if s in out or s not in nodes:
            continue
        out.append(s)
        for f in nodes[s]["fields"]:
            if f.startswith("to"):
                parents = [d for d in nodes[s + "." + f]["type_deps"]
                           if d in nodes and nodes[d]["kind"] == "inductive" and d.endswith("." + f[2:])]
                assert len(parents) == 1, (s, f, parents)
                pending.append(parents[0])
    return out


def closure(nodes, starts):
    seen, pending = set(), list(starts)
    while pending:
        c = pending.pop()
        if c in seen or c not in nodes or not (c.startswith("Benitoite.") or c.startswith("_private.Benitoite.")):
            continue
        seen.add(c)
        node = nodes[c]
        pending.extend(node["type_deps"])
        if node["kind"] in ("definition", "opaque"):
            pending.extend(node["value_deps"])
        if node["kind"] == "inductive":
            pending.extend(node["ctors"])
    return seen


def keyed(nodes, names):
    return {private_key(nodes[n]["module"], n): n for n in names}


def state(b, f, in_base=False, in_final=False):
    if b is None:
        return "閉包に入った" if in_base else "足した"
    if f is None:
        return "閉包から外れた" if in_final else "削除した"
    if b["type"] != f["type"]:
        return "型が変わった"
    if b["value"] != f["value"]:
        return "本体が変わった"
    if b["ctors"] != f["ctors"]:
        return "構成子の列が変わった"
    return "同じ"


GENERATED = re.compile(stage.GENERATED)


def named(name):
    return not name.startswith("_private.") and GENERATED.search(name) is None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=L70 / "h3")
    parser.add_argument("--scratch", type=Path)
    args = parser.parse_args()
    scratch = args.scratch or args.tmp
    _, final = stage.merged(args.tmp, "final")
    _, base = stage.merged(args.tmp, "base")
    assert all(n["value"] is not None for n in list(final.values())[:10] + list(base.values())[:10]), \
        "本体のハッシュのない書き出し（群 H3 の前の axioms.lean）"
    fs, bs = structures(final), structures(base)
    env_f, env_b = set(keyed(final, final)), set(keyed(base, base))

    def compare(kb, kf):
        return {k: state(base[kb[k]] if k in kb else None, final[kf[k]] if k in kf else None, k in env_b, k in env_f)
                for k in set(kf) | set(kb)}
    rows, new_conditions = [], []
    for s in sorted(set(fs) | set(bs)):
        f, b = final.get(s), base.get(s)
        if b is None or f is None:
            new_conditions.append({"structure": s.removeprefix(R), "change": "構造体が足された" if b is None else
                                   "構造体が除かれた"})
            continue
        added = [x for x in f["fields"] if x not in b["fields"]]
        removed = [x for x in b["fields"] if x not in f["fields"]]
        if added or removed or f["ctors"] != b["ctors"]:
            new_conditions.append({"structure": s.removeprefix(R), "added_fields": added, "removed_fields": removed,
                                   "ctors": [b["ctors"], f["ctors"]]})
        fields = []
        for x in f["fields"]:
            proj_f, proj_b = final.get(s + "." + x), base.get(s + "." + x)
            cf = closure(final, proj_f["type_deps"])
            cb = closure(base, proj_b["type_deps"]) if proj_b else set()
            kf, kb = keyed(final, cf), keyed(base, cb)
            states = compare(kb, kf)
            changed = sorted(k[1] for k, v in states.items() if v != "同じ")
            direct = sorted({private_key(final[d]["module"], d)[1] for d in proj_f["type_deps"] if d in final} &
                            set(changed))
            fields.append({"field": x, "type_same": proj_b is not None and proj_b["type"] == proj_f["type"],
                           "closure": len(states), "changed": len(changed),
                           "states": {s: c for s in STATE_ORDER if (c := sum(v == s for v in states.values()))},
                           "direct_changed": [d.removeprefix(R) for d in direct if named(d)]})
        rows.append({"structure": s.removeprefix(R), "fields": len(f["fields"]),
                     "ctor_type_same": final[f["ctors"][0]]["type"] == base[b["ctors"][0]]["type"],
                     "field_rows": fields})
    # 構造体の全体（構成子の型の閉包）の比較。
    starts_f = [final[final[s]["ctors"][0]]["type_deps"] for s in fs]
    starts_b = [base[base[s]["ctors"][0]]["type_deps"] for s in bs]
    cf = closure(final, [d for x in starts_f for d in x])
    cb = closure(base, [d for x in starts_b for d in x])
    kf, kb = keyed(final, cf), keyed(base, cb)
    all_states = compare(kb, kf)
    listing = scratch / "trust-closure.tsv"
    listing.write_text("".join(f"{v}\t{k[0] or ''}\t{k[1]}\n" for k, v in sorted(all_states.items(),
                                                                               key=lambda kv: (kv[1], kv[0][1], kv[0][0] or ""))))
    by_state = collections.Counter(all_states.values())
    named_changed = collections.defaultdict(list)
    for k, v in all_states.items():
        if v != "同じ" and named(k[1]):
            named_changed[v].append(k[1].removeprefix(R))
    kinds = collections.Counter((v, (final.get(kf.get(k)) or base.get(kb.get(k)))["kind"]) for k, v in all_states.items())
    record = {
        "roots": [r.removeprefix(R) for r in ROOTS], "structures": [s.removeprefix(R) for s in fs],
        "base_structures": [s.removeprefix(R) for s in bs],
        "new_conditions": new_conditions, "rows": rows,
        "closure": {"constants": len(all_states), "by_state": {s: by_state.get(s, 0) for s in STATE_ORDER},
                    "by_state_kind": {f"{s}/{k}": c for (s, k), c in sorted(kinds.items())},
                    "named_changed": {s: sorted(v)[:60] for s, v in sorted(named_changed.items())},
                    "named_changed_counts": {s: len(v) for s, v in sorted(named_changed.items())},
                    "listing": digest(listing)},
        "inputs": {"trust.py": digest(Path(__file__)), "stage.py": digest(Path(stage.__file__))},
    }
    args.out.mkdir(parents=True, exist_ok=True)
    write(args.out / "trust.json", record)
    lines = ["# 信頼条件の構造体の比較", "",
             "生成物（[../h/trust.py](../h/trust.py)）。段の開始版と最終版の書き出しで、信頼条件の構造体の欄の列・構成子・欄の型と、"
             "欄の型が参照する定数の閉包の各定数（型の印字、定義・opaque の本体の構造のハッシュ、帰納型の構成子の列）を比べた。"
             "接頭辞 `Benitoite.Release.Refinement.` を省く。", "",
             f"新しい信頼条件の候補（欄・構成子・親の構造体の増減）: {len(new_conditions)} 件。", "",
             "| 構造体 | 欄 | 構成子の型が同じ | 欄の型の印字が同じ欄 | 参照先が変わった欄 |", "|---|---:|---|---:|---:|"]
    for r in rows:
        same = sum(x["type_same"] for x in r["field_rows"])
        changed = sum(x["changed"] > 0 for x in r["field_rows"])
        lines.append(f"| `{r['structure']}` | {r['fields']} | {'はい' if r['ctor_type_same'] else 'いいえ'} | {same} | {changed} |")
    lines += ["", "閉包の定数の状態（構成子の型から辿った全体）:", "",
              "| 状態 | 定数 |", "|---|---:|"]
    lines += [f"| {s} | {by_state.get(s, 0):,} |" for s in STATE_ORDER]
    lines += ["", "## 欄ごとの比較", "",
              "| 構造体 | 欄 | 型の印字 | 閉包 | 変わった定数 | 欄の型が直接参照し、変わった名前 |", "|---|---|---|---:|---:|---|"]
    for r in rows:
        for x in r["field_rows"]:
            direct = "・".join(f"`{d}`" for d in x["direct_changed"][:8]) + ("…" if len(x["direct_changed"]) > 8 else "")
            lines.append(f"| `{r['structure']}` | `{x['field']}` | {'同じ' if x['type_same'] else '変わった'} | "
                         f"{x['closure']:,} | {x['changed']:,} | {direct or 'なし'} |")
    (args.out / "trust.md").write_text("\n".join(lines) + "\n")
    assert (args.out / "trust.md").stat().st_size <= 100000
    print(json.dumps({"structures": len(fs), "new_conditions": len(new_conditions),
                      "closure": record["closure"]["by_state"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()

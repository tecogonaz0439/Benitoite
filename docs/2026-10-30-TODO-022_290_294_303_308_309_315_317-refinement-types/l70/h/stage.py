# -*- coding: utf-8 -*-
"""段（L70）の公理監査・宣言の一覧・主定理の型のハッシュ（L70.46 (a)(b)(c)(d)）。

prepare: 監査の入力（../axioms.lean の SELECT・AUDIT・REQUIRED の行を差し替えた写し）を一時領域に作る。最終版は既定 import
  の閉包（Benitoite）と7入口の根ごと（根はどれも main を持つので別の環境）、開始版は同じ形で AUDIT を false にする。
run: 共有ロックの下で一つずつ `lake env lean -M 12288` を実行する。最終版は作業木の formal、開始版は一時領域に取り出して
  既定ビルドした formal（`git archive` の写し）で行う。生の出力は一時領域に置き、終了・時間・大きさ・SHA-256 を記録する。
analyze: 生の出力から、全宣言（private・生成宣言・構造体の欄・マクロのスコープを持つ名前を含む）を開始版と最終版で比べ、
  公理の組・sorryAx・マクロのスコープを持つ名前・必須の名前の型と本体のハッシュを照合し、記録を書く。宣言の比較は型の
  印字と、定義・opaque の本体の印字のハッシュで行う（定理の証明は比べない）。
記録は --out（既定は ../h3。群 H の記録 h/ は群 H のコミットの時点のもの）に書く。名前の一覧などの大きな生成物は
--scratch（既定は --tmp）に書く。照合（../verify.py）は --out と --scratch を別の一時の場所にして記録を書き直さずに比べる。
使い方: python3 stage.py prepare|run|analyze --tmp <一時領域> [--which final|base] [--out <記録>] [--scratch <場所>]"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from support import (B_STAGE, B_WORK, ENTRIES, ENTRY_PREFIXES, HERE, L70, PREFIX, ROOT, closure, digest,
                     module_graph, private_key, write)

# 記録の置き場所（main が --out で差し替える）。
OUT = L70 / "h3"

GENERATED = r"\.(match_\d+|_sparseCasesOn_\d+|eq_\d+|eq_def|_unfold|proof_\d+|splitter|_simp_\d+_\d+|_f|" \
            r"_flat_ctor|_sizeOf_\d+|_sizeOf_inst|ctorElim|ctorElimType|elim|else_eq|congr_simp|_cstage\d|" \
            r"_closed_\d+|_lambda_\d+|_boxed|_redArg|_unsafe_rec|injEq|inj|noConfusion|noConfusionType|" \
            r"recOn|casesOn|below|brecOn|binductionOn|ibelow|rec|sizeOf_spec|mk\.injEq|ext_iff|ctorIdx)$"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
STATES = ["足した", "削除した", "型が変わった", "同じ", "所属の変わった", "本体が変わった"]
INPUTS = {"library": "Benitoite", **{key: root for key, root in ENTRIES.items()}}
# 旧主定理（段の開始版）と、それに当たる新しい主定理（最終版）。接頭辞 `Benitoite.` を省く。
OLD_MAIN = {
    "Release.progress": ["Release.Refinement.progress"],
    "Release.preservation": ["Release.Refinement.preservation", "Release.Refinement.steps_preservation"],
    "Release.step_sound": ["Release.Refinement.step_sound"],
    "Release.effect_soundness": ["Release.Refinement.effect_soundness"],
    "Release.effect_soundness_noLamNames": ["Release.Refinement.effect_soundness_noLamNames"],
    "Release.reachable_target_sound": ["Release.Refinement.reachable_target_sound"],
    "Release.reachable_target_sound_event": ["Release.Refinement.reachable_target_sound_event"],
    "Release.reachable_target_sound_of_assumptions": ["Release.Refinement.StandardModel.included_guarantees"],
    "Release.step_target_sound": ["Release.Refinement.step_target_sound"],
    "Release.Model.assumptions": ["Release.Refinement.ExternalModels.ModelCase.composition"],
    "Release.ModelTargets.assumptions": ["Release.Refinement.ExternalModels.ModelCase.composition"],
    "Release.ModelHttp.assumptions": ["Release.Refinement.ExternalModels.ModelCase.composition"],
    "Surface.desugar_typed": ["Release.Refinement.Surface.desugar_typed"],
    "Surface.surface_effect_soundness": ["Release.Refinement.Surface.surface_effect_soundness"],
    "Surface.surface_target_sound": ["Release.Refinement.Surface.surface_target_sound"],
    "Surface.CheckTables.checkProgram_sound": ["Release.Refinement.Surface.CheckTables.checkProgram_sound"],
    "Surface.CheckAccept.checkProgramAccepted_sound": ["Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound"],
}


def required_names():
    """必須の名前。main は主定理の一覧と主な言明（stage-results.md の表）、extra は群 H2・H3 が述べ直した定理など。"""
    names = json.loads((L70 / "h3" / "required-names.json").read_text())
    extra = [n for group in names["extra"].values() for n in group]
    return names["main"] + [n for n in extra if n not in names["main"]]


def main_required():
    return json.loads((L70 / "h3" / "required-names.json").read_text())["main"]


def make_input(template, key, base):
    root = INPUTS[key]
    text = template
    select_old = '  let selected : String → Bool := fun s => s.startsWith "Benitoite"\n'
    audit_old = "  let audit : Bool := true\n"
    required_old = "  let required : List Name := []\n"
    assert text.count(select_old) == text.count(audit_old) == text.count(required_old) == 1
    if key != "library":
        text = text.replace("import Benitoite\n", f"import {root}\n", 1)
        prefixes = ", ".join(f'"{p}"' for p in ENTRY_PREFIXES)
        text = text.replace(select_old, f"  let selected : String → Bool := fun s => [{prefixes}].any (s.startsWith ·)\n")
    if base:
        text = text.replace(audit_old, "  let audit : Bool := false\n")
    elif key == "library":
        names = ", ".join(f"`{n}" for n in required_names())
        text = text.replace(required_old, f"  let required : List Name := [{names}]\n")
    return text


def prepare(tmp):
    template = (L70 / "axioms.lean").read_text()
    for which in ["final", "base"]:
        for key in INPUTS:
            (tmp / f"{which}-{key}.lean").write_text(make_input(template, key, which == "base"))
    print(json.dumps({"inputs": len(INPUTS) * 2, "required": len(required_names())}))


def run(tmp, which, lock):
    formal = ROOT / "formal" if which == "final" else tmp / "base/formal"
    record = {"which": which, "formal": "<repo>/formal" if which == "final" else "<tmp>/base/formal",
              "lock": "共有ロック", "runs": {}}
    for key in INPUTS:
        source, log = tmp / f"{which}-{key}.lean", tmp / f"{which}-{key}.log"
        start = time.monotonic()
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        with log.open("wb") as out:
            done = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(lock), "lake", "env", "lean", "-M", "12288",
                                   str(source)], cwd=formal, stdout=out, stderr=subprocess.STDOUT)
        record["runs"][key] = {"start": stamp, "exit": done.returncode, "seconds": round(time.monotonic() - start, 1),
                               "input": digest(source), "output": digest(log)}
        print(json.dumps({key: record["runs"][key]}, ensure_ascii=False), flush=True)
        assert done.returncode == 0, log.read_text()[-3000:]
    write(OUT / f"runs-{which}.json", record)


def load(log):
    nodes, audits, macros, unresolved, sigs = {}, {}, {}, [], {}
    text = log.read_text()
    for line in text.splitlines():
        i = line.find("NODE ")
        if i >= 0 and line[i:].startswith("NODE ["):
            fields = json.loads(line[i + 5:])
            # 群 H・H2 の書き出しは8欄、群 H3 の後は本体のハッシュ・構成子・構造体の欄を足した11欄。
            name, module, kind, ln, th, macro, td, vd = fields[:8]
            vh, ctors, sfields = fields[8:] if len(fields) == 11 else (None, [], [])
            assert name not in nodes, name
            nodes[name] = {"module": module, "kind": kind, "line": ln, "type": th, "macro": macro,
                           "deps": sorted(set(td) | set(vd)), "type_deps": td, "value": vh, "value_deps": vd,
                           "ctors": ctors, "fields": sfields}
    for module, name, axioms in re.findall(r"^AUDIT_MACRO (\S+) (\"(?:[^\"\\]|\\.)*\") (\[.*\])$", text, re.M):
        macros[json.loads(name)] = json.loads(axioms)
    printed = re.findall(r"^'(.+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", text, re.M)
    for name, axioms in printed:
        audits[name] = sorted(a.strip() for a in axioms.split(",") if a.strip())
    unresolved = re.findall(r"^AUDIT_UNRESOLVED (.+)$", text, re.M)
    for name, body in re.findall(r"^SIGNATURE_BEGIN (\S+)\n(.*?)^SIGNATURE_END \1$", text, re.M | re.S):
        sigs[name] = body.strip()
    values = {name: body.strip() for name, body in
              re.findall(r"^VALUE_BEGIN (\S+)\n(.*?)^VALUE_END \1$", text, re.M | re.S)}
    unfolded = {name: body.strip() for name, body in
                re.findall(r"^UNFOLDED_BEGIN (\S+)\n(.*?)^UNFOLDED_END \1$", text, re.M | re.S)}
    targets = re.findall(r"^AUDIT_TARGET (\S+) (.+)$", text, re.M)
    count = re.search(r"^AUDIT_COUNT (\d+)$", text, re.M)
    macro_count = re.search(r"^AUDIT_MACRO_COUNT (\d+)$", text, re.M)
    modules = re.findall(r"^AUDIT_MODULE (\S+)$", text, re.M)
    errors = re.findall(r"error:|AUDIT_(?:AXIOM|MISSING|FIXED_POINT_LIMIT|REQUIRED_MISSING)", text)
    return {"nodes": nodes, "audits": audits, "macros": macros, "unresolved": unresolved, "signatures": sigs,
            "values": values, "unfolded": unfolded,
            "targets": targets, "count": int(count[1]), "macro_count": int(macro_count[1]), "modules": modules,
            "errors": errors, "sorry": len(re.findall(r"sorryAx", text)), "raw": digest(log)}


def merged(tmp, which):
    """根ごとの出力をまとめる。同じ名前（SurfaceCheck の共有モジュール）は同じ記録であることを確かめて一つにする。"""
    parts = {key: load(tmp / f"{which}-{key}.log") for key in INPUTS}
    nodes = {}
    for key, part in parts.items():
        assert not part["errors"], (which, key, part["errors"][:3])
        for name, node in part["nodes"].items():
            if name in nodes and nodes[name]["module"] != node["module"]:
                # 根ごとの環境の同じ名前（各入口の main など）は、所属モジュールを付けて別に持つ。
                assert node["module"].split(".")[0] in ENTRY_PREFIXES, name
                nodes[name + "@@" + node["module"]] = node
            elif name in nodes:
                assert nodes[name]["type"] == node["type"], name
            else:
                nodes[name] = node
    return parts, nodes


def family(module):
    if module == "local":
        return "印字で実体化した生成宣言"
    for p in ENTRY_PREFIXES:
        if module.startswith(p):
            return "7入口"
    parts = module.split(".")
    if module.startswith(PREFIX + "Surface"):
        return "Release.Refinement.Surface"
    if module.startswith(PREFIX[:-1]):
        return "Release.Refinement"
    return ".".join(parts[1:2]) if len(parts) > 1 else parts[0]


def analyze(tmp, scratch):
    final_parts, final = merged(tmp, "final")
    base_parts, base = merged(tmp, "base")
    # (b) 公理監査。最終版の全宣言が監査され、許可した三公理の部分集合だけに依存し、sorryAx がない。
    audits, macros, unresolved = {}, {}, set()
    for key, part in final_parts.items():
        assert part["sorry"] == 0, key
        assert part["count"] == len(part["nodes"]), key
        assert part["macro_count"] == len(part["macros"]), key
        assert {n for _, n in part["targets"]} | set(part["macros"]) == set(part["nodes"]), key
        for name, axioms in list(part["audits"].items()) + list(part["macros"].items()):
            assert set(axioms) <= ALLOWED, (name, axioms)
            audits[name] = tuple(sorted(axioms))
        macros.update(part["macros"])
        unresolved.update(part["unresolved"])
    assert set(audits) == {n.split("@@")[0] for n in final}, (len(audits), len(final))
    assert all(n["kind"] != "axiom" for n in final.values())
    macro_kinds = collections.Counter(final[n]["kind"] for n in macros)
    axiom_sets = collections.Counter(" + ".join(sorted(a)) or "なし" for a in audits.values())
    # 既定 import の閉包と環境のモジュールの一致。
    graph = module_graph(ROOT / "formal")
    default = closure(graph, ["Benitoite"])
    reachable = closure(graph, ["Benitoite", *ENTRIES.values()])
    library_modules = set(final_parts["library"]["modules"])
    assert library_modules == default, (sorted(library_modules - default)[:5], sorted(default - library_modules)[:5])
    final_modules = {n["module"] for n in final.values()} - {"local"}
    assert final_modules <= reachable
    final_files = reachable
    # (a) 開始版との全宣言の比較。private は所属モジュールと実名の接頭辞を除いた名前で対応させる。
    def keyed(nodes):
        result = {}
        for name, node in nodes.items():
            if node["module"] == "local":
                continue
            k = private_key(node["module"], name)
            assert k not in result, k
            result[k] = (name, node)
        return result
    kb, kf = keyed(base), keyed(final)
    base_graph = module_graph(tmp / "base/formal")
    base_modules = closure(base_graph, ["Benitoite", *ENTRIES.values()])
    # モジュールはファイルの import の閉包で数える（宣言を持たないモジュールも含む）。
    added_modules = sorted(final_files - base_modules)
    removed_modules = sorted(base_modules - final_files)
    without_declarations = {"added": sorted(set(added_modules) - final_modules),
                            "removed": sorted(set(removed_modules) - {n["module"] for n in base.values()})}
    assert all(m in default or m in closure(graph, list(ENTRIES.values())) for m in added_modules)
    states = {}
    for k in sorted(set(kb) | set(kf), key=lambda k: (k[0] or "", k[1])):
        b, f = kb.get(k), kf.get(k)
        if b is None:
            state = "足した"
        elif f is None:
            state = "削除した"
        elif b[1]["type"] != f[1]["type"]:
            state = "型が変わった"
        elif b[1]["value"] != f[1]["value"]:
            # 定義・opaque の本体の構造のハッシュ、又は宣言の種類（定義から構造体へ、など）が変わった。定理は本体を
            # 比べないので両方とも空である。
            state = "本体が変わった"
        else:
            state = "同じ"
        states[k] = state
    rows = collections.Counter()
    by_family = collections.defaultdict(collections.Counter)
    by_module = collections.defaultdict(collections.Counter)
    lists = collections.defaultdict(list)
    for k, state in states.items():
        name, node = kf.get(k) or kb.get(k)
        generated = not name.startswith("_private.") and re.search(GENERATED, name) is not None
        kind = node["kind"]
        rows[(state, kind, k[0] is not None, generated, node["macro"])] += 1
        by_family[family(node["module"])][state] += 1
        by_module[node["module"]][state] += 1
        lists[state].append(f"{node['module']}\t{name}\t{kind}")
        if kb.get(k) and kf.get(k) and kb[k][1]["module"] != kf[k][1]["module"]:
            lists["所属の変わった"].append(f"{kb[k][1]['module']}\t{kf[k][1]['module']}\t{name}")
    totals = collections.Counter(states.values())
    removed_in_removed_modules = sum(1 for k, s in states.items() if s == "削除した" and kb[k][1]["module"] in removed_modules)
    # 名前の一覧は一時領域に置き、改造には大きさと SHA-256 を残す（宣言の記録の写しは一回分だけ）。
    list_digests = {}
    for state, items in lists.items():
        path = scratch / f"declarations-{STATES.index(state)}.tsv"
        path.write_text("\n".join(sorted(items)) + "\n")
        list_digests[state] = {"count": len(items), **digest(path)}
    def counts(pred):
        return {s: sum(v for key, v in rows.items() if key[0] == s and pred(key)) for s in totals}
    summary = {
        "base": B_STAGE, "final_base": B_WORK,
        "final_declarations": len(final), "final_without_local": len(kf), "base_declarations": len(kb),
        "states": dict(totals),
        "by_kind": {kind: counts(lambda key, kind=kind: key[1] == kind) for kind in sorted({k[1] for k in rows})},
        "private": counts(lambda key: key[2]), "generated": counts(lambda key: key[3]),
        "macro_scoped": counts(lambda key: key[4]),
        "named_public": counts(lambda key: not key[2] and not key[3] and not key[4]),
        "theorems_named_public": counts(lambda key: key[1] == "theorem" and not key[2] and not key[3] and not key[4]),
        "definitions_named_public": counts(lambda key: key[1] in ("definition", "inductive", "constructor", "opaque")
                                           and not key[2] and not key[3] and not key[4]),
        "by_family": {f: dict(c) for f, c in sorted(by_family.items())},
        "modules": {"base": len(base_modules), "final": len(final_files), "added": len(added_modules),
                    "removed": len(removed_modules), "default_import": len(default),
                    "declarations_in_removed_modules": removed_in_removed_modules,
                    "without_declarations": without_declarations},
        "lists": list_digests,
        "rows_fields": ["状態", "種類", "private", "生成", "マクロのスコープ"],
    }
    write(OUT / "declarations.json", summary)
    module_rows = {m: dict(c) for m, c in sorted(by_module.items()) if c.get("足した") or c.get("削除した")
                   or c.get("型が変わった")}
    write(OUT / "modules.json", {"added": [m.removeprefix("Benitoite.") for m in added_modules],
                                  "removed": [m.removeprefix("Benitoite.") for m in removed_modules]})
    module_file = scratch / "module-states.json"
    module_file.write_text(json.dumps(module_rows, ensure_ascii=False, indent=0))
    # (d) 必須の名前（主定理と主な言明）の型と本体のハッシュ。定義は本体（値）の印字、定理は型に現れる主な言明を
    # 一段展開した型の印字の SHA-256 も持つ（型の印字だけでは言明の名前しか固定しないため）。
    lib = final_parts["library"]
    sigs, values, unfolded = lib["signatures"], lib["values"], lib["unfolded"]
    required = required_names()
    assert set(required) == set(sigs), sorted(set(required) - set(sigs))[:5]
    assert all((final[n]["kind"] == "definition") == (n in values) for n in required)
    assert all((final[n]["kind"] == "theorem") == (n in unfolded) for n in required)
    assert not any("⋯" in t for t in list(sigs.values()) + list(values.values()) + list(unfolded.values()))
    sha = lambda s: hashlib.sha256(s.encode()).hexdigest()  # noqa: E731
    hashes = {n: {"kind": final[n]["kind"], "module": final[n]["module"], "type_sha256": sha(sigs[n]),
                  "value_sha256": sha(values[n]) if n in values else None,
                  "unfolded_sha256": sha(unfolded[n]) if n in unfolded else None, "axioms": list(audits[n])}
              for n in required}
    # 本体又は展開した型の値は名前ごとに異なる（同じ値は同じ中身を意味する）ことを数える。
    contents = collections.Counter(h["value_sha256"] or h["unfolded_sha256"] for h in hashes.values())
    shared_contents = {c: sorted(n for n, h in hashes.items() if (h["value_sha256"] or h["unfolded_sha256"]) == c)
                       for c, k in contents.items() if k > 1}
    signature_file = scratch / "signatures.txt"
    signature_file.write_text("".join(f"### {n}\n{sigs[n]}\n" + (f"#### value\n{values[n]}\n" if n in values else "")
                                      + (f"#### unfolded\n{unfolded[n]}\n" if n in unfolded else "") + "\n"
                                      for n in required))
    audit_summary = {
        "targets": len(audits), "printed": sum(len(p["audits"]) for p in final_parts.values()),
        "macro_scoped": len(macros), "macro_scoped_kinds": dict(macro_kinds),
        "macro_scoped_axioms": dict(collections.Counter(" + ".join(a) or "なし" for a in macros.values())),
        "unresolved": len(unresolved), "axiom_sets": dict(axiom_sets), "sorryAx": 0, "new_axioms": 0,
        "axiom_declarations": 0, "allowed": sorted(ALLOWED),
        "parts": {key: {"declarations": len(p["nodes"]), "macro_scoped": len(p["macros"]),
                        "unresolved": len(p["unresolved"]), "raw": p["raw"]} for key, p in final_parts.items()},
        "base_parts": {key: {"declarations": len(p["nodes"]), "raw": p["raw"]} for key, p in base_parts.items()},
        "required": {n: hashes[n] for n in main_required()}, "required_all": "required-<群>.json",
        "shared_contents": shared_contents,
        "signatures": digest(signature_file), "module_states": digest(module_file),
        "old_main": {o: {"in_base": "Benitoite." + o in base, "in_final": "Benitoite." + o in final,
                         "new": n, "new_in_final": all("Benitoite." + x in final for x in n)}
                     for o, n in OLD_MAIN.items()},
        "inputs": {"axioms.lean": digest(L70 / "axioms.lean"), "stage.py": digest(Path(__file__)),
                   "required-names.json": digest(L70 / "h3" / "required-names.json")},
    }
    write(OUT / "audit-summary.json", audit_summary)
    # 全ての必須の名前の値（所属モジュールは audit-summary.json の main と declarations の一覧にあるので除く）。
    # 群ごとの記録（一つの記録の大きさの制限のため。名前は最初に現れる群に置く）。
    names = json.loads((L70 / "h3" / "required-names.json").read_text())
    placed = set()
    for group, group_names in [("main", names["main"]), *names["extra"].items()]:
        part = {n: {k: v for k, v in hashes[n].items() if k != "module"} for n in group_names if n not in placed}
        placed |= set(part)
        write(OUT / f"required-{group}.json", part)
    assert placed == set(hashes)
    # 群 H2・H3 が述べ直した定理など（必須の名前の extra）の表。主定理の一覧（main）の表は stage-results.md にある。
    main_names = set(main_required())
    lines = ["# 群 H2・H3 の必須の名前と型・本体のハッシュ", "",
             "生成物（[../h/stage.py](../h/stage.py) の analyze）。段の公理監査の既定 import の閉包の書き出しから、群 H2・H3 が述べ直した"
             "定理など（[required-names.json](required-names.json) の extra）の型の印字の SHA-256 と、定義は本体の印字、定理は型に現れる"
             "主な言明を一段展開した型の印字の SHA-256 を載せる。接頭辞 `Benitoite.` を省く。", "",
             "| 名前 | 種類 | 型の SHA-256 | 本体又は展開した型の SHA-256 | 公理 |", "|---|---|---|---|---|"]
    for n in required:
        if n in main_names:
            continue
        h = hashes[n]
        kind = {"theorem": "定理", "definition": "定義"}.get(h["kind"], h["kind"])
        lines.append(f"| `{n.removeprefix('Benitoite.')}` | {kind} | `{h['type_sha256']}` | "
                     f"`{h['value_sha256'] or h['unfolded_sha256']}` | {' + '.join(h['axioms']) or 'なし'} |")
    (OUT / "required.md").write_text("\n".join(lines) + "\n")
    assert (OUT / "required.md").stat().st_size <= 100000
    print(json.dumps({"final": len(final), "base": len(kb), "states": dict(totals), "macro": len(macros),
                      "axiom_sets": dict(axiom_sets), "modules": summary["modules"]}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "run", "analyze"])
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--which", choices=["final", "base"], default="final")
    parser.add_argument("--lock", type=Path)
    parser.add_argument("--out", type=Path, default=L70 / "h3")
    parser.add_argument("--scratch", type=Path)
    args = parser.parse_args()
    global OUT
    OUT = args.out
    OUT.mkdir(parents=True, exist_ok=True)
    if args.command == "prepare":
        prepare(args.tmp)
    elif args.command == "run":
        run(args.tmp, args.which, args.lock)
    else:
        analyze(args.tmp, args.scratch or args.tmp)


if __name__ == "__main__":
    main()

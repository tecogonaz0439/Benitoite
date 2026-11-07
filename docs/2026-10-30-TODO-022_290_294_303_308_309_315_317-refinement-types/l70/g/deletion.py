#!/usr/bin/env python3
"""棚卸しの宣言の閉包による削除を準備し、入力の一致後にだけ適用する。"""
import argparse
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
A = HERE.parent / "a" / "inventory.json"


def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def mask_comments(text):
    # 位置を保存して、入れ子のコメント・文字列中をコマンドとして読まない。
    chars = list(text)
    depth = 0
    quote = False
    escape = False
    i = 0
    while i < len(text):
        if depth:
            if text.startswith("/-", i):
                chars[i:i+2] = "  "; depth += 1; i += 2; continue
            if text.startswith("-/", i):
                chars[i:i+2] = "  "; depth -= 1; i += 2; continue
            if chars[i] != "\n": chars[i] = " "
        elif quote:
            c = text[i]
            if c != "\n": chars[i] = " "
            if escape: escape = False
            elif c == "\\": escape = True
            elif c == '"': quote = False
        elif text.startswith("/-", i):
            chars[i:i+2] = "  "; depth = 1; i += 2; continue
        elif text.startswith("--", i):
            j = text.find("\n", i)
            if j < 0: j = len(text)
            chars[i:j] = " " * (j-i); i = j; continue
        elif text[i] == '"':
            quote = True; chars[i] = " "
        i += 1
    return "".join(chars)


COMMAND = re.compile(r"^(?:(?:private|protected|noncomputable|unsafe|partial)\s+)*(?P<kind>def|theorem|example|abbrev|structure|inductive|namespace|section|end|open|export|attribute|set_option|variable|mutual)\b(?P<rest>[^\n]*)", re.M)


def declarations(text):
    commands = list(COMMAND.finditer(mask_comments(text)))
    stack = []
    out = []
    for k, m in enumerate(commands):
        kind, rest = m.group("kind"), m.group("rest").strip()
        if kind == "namespace":
            stack.append(("namespace", rest.split()[0])); continue
        if kind in ("section", "mutual"):
            stack.append((kind, "")); continue
        if kind == "end":
            if stack: stack.pop()
            continue
        if kind not in ("def", "theorem", "example", "abbrev", "structure", "inductive"):
            continue
        name = None if kind == "example" else rest.split()[0]
        space = ".".join(n for t,n in stack if t == "namespace")
        full = (space + "." + name).strip(".") if name else None
        start = m.start()
        # 所属する直前の文書コメントも同じ削除範囲へ入れる。
        before = text[:start].rstrip()
        if before.endswith("-/"):
            comment = before.rfind("/-")
            if comment >= 0 and before[comment:].startswith("/--"):
                start = comment
        finish = commands[k+1].start() if k+1 < len(commands) else len(text)
        # 次のコマンドの文書コメントはそのコマンドへ残す。
        tail = text[:finish].rstrip()
        if tail.endswith("-/"):
            comment = tail.rfind("/-")
            if comment >= m.end(): finish = comment
        out.append({"name": full, "kind":kind, "start":start, "end":finish,
                    "line":text.count("\n",0,m.start())+1})
    return out


def deletion_plan():
    inventory = json.loads(A.read_text())
    fixed = inventory["fixpoint"]
    kept = set(fixed["surface_syntax_kept"])
    modules = set(fixed["delete_release"])
    modules.add("Benitoite.Release.LegacyCheck")
    for folder in (FORMAL / "Benitoite/Core", FORMAL / "Benitoite/Surface"):
        for p in folder.rglob("*.lean"):
            n = ".".join(p.relative_to(FORMAL).with_suffix("").parts)
            if n not in kept: modules.add(n)
    graph = {}
    for source in FORMAL.rglob("*.lean"):
        if ".lake" in source.parts or "tests" in source.parts: continue
        n = ".".join(source.relative_to(FORMAL).with_suffix("").parts)
        graph[n] = re.findall(r"^import\s+(\S+)", source.read_text(), re.M)
    def frontier(n, seen=None):
        seen = set() if seen is None else seen
        if n in seen: return set()
        seen.add(n)
        if n not in modules: return {n}
        return set().union(*(frontier(dep,seen) for dep in graph.get(n,[])))
    def closure(roots):
        found=set()
        pending=list(roots)
        while pending:
            n=pending.pop()
            if n in found: continue
            found.add(n)
            pending.extend(graph.get(n,[]))
        return found
    removed = set(fixed["forbidden_in_kept_modules"] + fixed["change_release_declarations"] + fixed["change_other_declarations"])
    edits = {}
    for module in ["Benitoite.Release.Model", "Benitoite.Release.ModelTargets", "Benitoite.Release.ModelHttp", "Benitoite.Release.TargetTable", "Benitoite.Release.Refinement.CurrentSignatureRows", "Benitoite.Scope.CompatExamples"]:
        path = FORMAL / (module.replace(".", "/") + ".lean")
        text = path.read_text()
        decls = declarations(text)
        cuts = [d for d in decls if d["name"] in removed]
        if module == "Benitoite.Release.Model":
            cuts += [d for d in decls if d["kind"] == "example" and d["line"] in [150,310,350,439]]
            assert len([d for d in cuts if d["kind"] == "example"]) == 4
        if module == "Benitoite.Scope.CompatExamples":
            cuts += [d for d in decls if d["kind"] == "example" and "Surface.union_empty_right_nested" in text[d["start"]:d["end"]]]
        actual = text
        for d in sorted(cuts, key=lambda d:d["start"], reverse=True):
            actual = actual[:d["start"]] + actual[d["end"]:]
        if module == "Benitoite.Release.ModelHttp":
            actual = actual.replace("singleton_of_admissible ref_scoped_get ref_scoped_set)", "singleton_of_admissible)")
        imports = []
        for line in actual.splitlines(keepends=True):
            m = re.match(r"import\s+(\S+)",line)
            if m and m.group(1) in modules: imports.append(m.group(1))
        actual = "".join(line for line in actual.splitlines(keepends=True)
                         if not (re.match(r"import\s+(\S+)",line) and re.match(r"import\s+(\S+)",line).group(1) in modules))
        existing = re.findall(r"^import\s+(\S+)", actual, re.M)
        additions = set().union(*(frontier(n) for n in imports)) if imports else set()
        additions -= closure(existing)
        if module == "Benitoite.Scope.CompatExamples": additions=set()
        # 同じ依存を既に供給する辺があれば、直接の import は重ねない。
        additions = {n for n in additions if not any(n in closure([other]) for other in additions if other != n)}
        if additions:
            actual = "".join("import " + n + "\n" for n in sorted(additions)) + actual
        edits[str(path.relative_to(ROOT))] = {"before":digest(text.encode()), "after":digest(actual.encode()),
            "declarations":[{k:d[k] for k in ["name","kind","line"]} for d in cuts],"imports":imports,"added_imports":sorted(additions),"text":actual}
    found={d["name"] for edit in edits.values() for d in edit["declarations"] if d["name"]}
    assert removed <= found, sorted(removed-found)
    return {"inventory":digest(A.read_bytes()),"delete_modules":sorted(modules),"deleted_sources":{n:digest((FORMAL/(n.replace(".","/")+".lean")).read_bytes()) for n in sorted(modules)},"keep_release":fixed["keep_release"],"keep_surface":sorted(kept),"edits":edits}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument("--apply",action="store_true")
    mode.add_argument("--verify-applied",action="store_true")
    args=parser.parse_args()
    if args.verify_applied:
        record=json.loads((HERE/"deletion-plan.json").read_text())
        assert digest(A.read_bytes())==record["inventory"],"棚卸しの入力が変わった"
        for n in record["delete_modules"]:
            assert not (FORMAL/(n.replace(".","/")+".lean")).exists(),n
        for p,e in record["edits"].items():
            assert digest((ROOT/p).read_bytes())==e["after"],p
        for n in record["keep_release"]+record["keep_surface"]:
            assert (FORMAL/(n.replace(".","/")+".lean")).exists(),n
        forbidden=set(record["delete_modules"])
        for p in FORMAL.rglob("*.lean"):
            if ".lake" in p.parts or "tests" in p.parts: continue
            for dep in re.findall(r"^import\s+(\S+)",p.read_text(),re.M):
                assert dep not in forbidden,(str(p.relative_to(ROOT)),dep)
        print(json.dumps({"verify_applied":True,"deleted_modules":len(forbidden),
            "deleted_commands":sum(len(e["declarations"]) for e in record["edits"].values()),
            "kept_release":len(record["keep_release"]),"kept_surface":len(record["keep_surface"])},ensure_ascii=False))
        return
    plan=deletion_plan()
    record={**plan,"edits":{p:{k:v for k,v in x.items() if k!="text"} for p,x in plan["edits"].items()}}
    saved=HERE/"deletion-plan.json"
    if args.apply:
        expected=json.loads(saved.read_text())
        assert expected==record,"削除の確認後に入力が変わった"
        for p,e in plan["edits"].items(): (ROOT/p).write_text(e["text"])
        for n in plan["delete_modules"]:
            p=FORMAL/(n.replace(".","/")+".lean")
            if p.exists(): p.unlink()
    else:
        saved.write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"apply":args.apply,"delete_modules":len(plan["delete_modules"]),"declarations":sum(len(e["declarations"]) for e in plan["edits"].values()),"keep_release":len(plan["keep_release"]),"keep_surface":len(plan["keep_surface"])},ensure_ascii=False))

if __name__=="__main__":main()

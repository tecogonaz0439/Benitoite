#!/usr/bin/env python3
"""交換の新しい版で値を持つ四欄の中身を、旧版の欄と処理系の登録表から導いた値と照らす。

四欄は、型パラメータの種類（`tparamKinds`）、型クラスの引数の種類（`argumentKind`）、data の型の構成子の対応
（`constructors`）、不透明型の公開名（`opaqueNames`）である。照らす相手は、新旧の照合で旧版と一致を確かめた
欄（型・辞書の制約・実装の対象・組込みの表の data の宣言）と、処理系の組込みの型の登録表
（`crates/benitoite/src/types/builtin.rs` の `BUILTIN_TYPES` の原文）である。

使い方: `check_value_fields.py <書き出しのディレクトリ> <作業木の根> <出力の JSON>`
"""
import collections
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "g"))
from stream_json import events  # noqa: E402

VALUE = "value"
# 組込みの型構成子の頭の型引数の数（`Exchange.TyCon`。data の頭は組込みの表の宣言から引く）。
BUILTIN_HEADS = {"list": 1, "set": 1, "lazy": 1, "reference": 1, "map": 2}


def ctor(n):
    return {"constructor": {"arity": n}}


def registry(root):
    """`BUILTIN_TYPES` の原文を読み、番号ごとの公開名・型引数の数・分類を返す。"""
    text = (root / "crates/benitoite/src/types/builtin.rs").read_text()
    body = text[text.index("pub const BUILTIN_TYPES: &[BuiltinTypeDef] = &["):]
    body = body[:body.index("\n];")]
    rows = re.findall(r"BuiltinTypeDef \{\s*module: &\[([^\]]*)\],\s*name: \"([^\"]+)\",\s*arity: (\d+),"
                      r"\s*class: BuiltinTypeClass::(\w+),\s*\}", body)
    assert rows and len(rows) == body.count("BuiltinTypeDef {"), "registry parse"
    table = []
    for module, name, arity, cls in rows:
        parts = re.findall(r"\"([^\"]+)\"", module)
        table.append({"public": ".".join(["Benitoite", *parts, name]), "arity": int(arity), "class": cls})
    return table


def walk(value, visit, path=()):
    visit(value, path)
    if isinstance(value, dict):
        for k, v in value.items():
            walk(v, visit, path + (k,))
    elif isinstance(value, list):
        for i, v in enumerate(value):
            walk(v, visit, path + (i,))


def applications(value):
    """型の中の `tapp` の（番号, 実引数の数）と、`tvar` の番号を集める。"""
    applied, plain = [], []

    def visit(v, _):
        if isinstance(v, dict) and len(v) == 1:
            if "tapp" in v and isinstance(v["tapp"], dict):
                applied.append((v["tapp"]["index"], len(v["tapp"]["args"])))
            elif "tvar" in v and isinstance(v["tvar"], dict):
                plain.append(v["tvar"]["index"])
    walk(value, visit)
    return applied, plain


class Checker:
    def __init__(self, reg):
        self.reg = reg
        self.counts = collections.Counter()
        self.errors = []

    def error(self, where, message):
        self.counts["errors"] += 1
        if len(self.errors) < 50:
            self.errors.append(f"{where}: {message}")

    def header(self, where, h, constraints, class_kinds, extra=None):
        """頭部の種類を、型の中の適用と辞書の制約から導いた種類と照らす。"""
        kinds = h.get("tparamKinds")
        if kinds is None or len(kinds) != len(h["tparams"]):
            self.error(where, "kind count")
            return
        self.counts["headers"] += 1
        context = list(kinds) + ([extra] if extra is not None else [])
        applied, plain = applications({k: h[k] for k in ("params", "ret", "eff") if k in h})
        witnessed = set()
        for index, n in applied:
            if index >= len(context):
                self.error(where, f"type application outside the context: {index}")
                continue
            if context[index] != ctor(n):
                self.error(where, f"tapp {index} with {n} arguments but kind {context[index]}")
            witnessed.add(index)
        for cls, index in constraints:
            kind = class_kinds.get(cls)
            if kind is None:
                self.counts["constraintsWithoutClass"] += 1
                continue
            if index < len(context):
                if context[index] != kind:
                    self.error(where, f"constraint {cls} on {index}: {kind} != {context[index]}")
                if kind != VALUE:
                    witnessed.add(index)
        for index, kind in enumerate(kinds):
            if kind == VALUE:
                self.counts["valueParams"] += 1
                continue
            if not (isinstance(kind, dict) and set(kind) == {"constructor"} and kind["constructor"]["arity"] > 0):
                self.error(where, f"invalid kind {kind}")
                continue
            self.counts["constructorParams"] += 1
            if index in witnessed:
                self.counts["constructorParamsDerived"] += 1
            else:
                self.counts["constructorParamsUnderived"] += 1
                if index in plain:
                    self.counts["constructorParamsUnappliedOnly"] += 1

    def corpus_input(self, where, item, table):
        if item["excluded"]:
            return
        self.counts["corpusInputs"] += 1
        classes = {c["name"]: c for c in item["classes"]}
        class_kinds = {n: c["argumentKind"] for n, c in classes.items()}
        data_arity = {d["name"]: d["ntys"] for d in (table or {}).get("dataDecls", [])}
        # 型クラス: 引数の種類を、メソッドの頭部での引数の適用と照らす。
        for c in item["classes"]:
            kind = c["argumentKind"]
            self.counts["classes"] += 1
            self.counts["classesConstructor" if kind != VALUE else "classesValue"] += 1
            seen = False
            for m in c["methods"]:
                h = m["header"]
                applied, _ = applications({k: h[k] for k in ("params", "ret", "eff")})
                own = len(h["tparams"])
                for index, n in applied:
                    if index == own:
                        seen = True
                        if kind != ctor(n):
                            self.error(f"{where}: {c['name']}", f"class argument applied to {n} but kind {kind}")
                self.header(f"{where}: {c['name']}.{m['name']}", h, [], class_kinds, extra=kind)
            if kind != VALUE:
                self.counts["classesConstructorDerived" if seen else "classesConstructorUnderived"] += 1
        # 実装: 対象が型構成子であることと、その頭の型引数の数を、型クラスの引数の種類と照らす。
        for im in item["impls"]:
            kind = class_kinds.get(im["cls"])
            if kind is None:
                self.counts["implsWithoutClass"] += 1
                continue
            target = im["target"]
            self.counts["impls"] += 1
            if kind == VALUE:
                if isinstance(target, dict) and "ctor" in target:
                    self.error(f"{where}: {im['name']}", "value class implemented for a type constructor")
                continue
            head = target.get("ctor", {}).get("head") if isinstance(target, dict) else None
            if head is None:
                self.error(f"{where}: {im['name']}", "constructor class implemented for a type")
                continue
            arity = data_arity.get(head["data"]["name"]) if isinstance(head, dict) else BUILTIN_HEADS.get(head)
            if arity is None:
                self.counts["implHeadsWithoutArity"] += 1
            elif kind != ctor(arity):
                self.error(f"{where}: {im['name']}", f"head arity {arity} but class kind {kind}")
            else:
                self.counts["implsConstructorDerived"] += 1
        # 頭部: 定義（表層・コア）と操作の頭部。
        for d in item["definitions"]:
            scope = d["scope"].get("inScope")
            if scope is None:
                continue
            surface = scope["surface"]
            self.header(f"{where}: {d['name']}", surface["header"], surface["dictParams"], class_kinds)
            self.header(f"{where}: {d['name']} (core)", scope["core"]["header"], surface["dictParams"], class_kinds)
        for o in item["ops"]:
            self.header(f"{where}: {o['name']}", o["header"], o.get("dictParams", []), class_kinds)
        # data の型の構成子の対応を、組込みの表の同じ data の宣言と照らす。
        if table is not None:
            decls = {d["name"]: d for d in table["dataDecls"]}
            for info in item["dataTypes"]:
                self.counts["dataTypes"] += 1
                decl = decls.get(info["name"])
                if decl is None:
                    self.error(where, f"data type without declaration: {info['name']}")
                    continue
                expected = [[c["name"], c["constructorName"]] for c in decl["ctors"]]
                if info["constructors"] != expected:
                    self.error(where, f"constructors of {info['name']}: {info['constructors']} != {expected}")
                else:
                    self.counts["dataTypesConstructorsDerived"] += 1
                    self.counts["constructors"] += len(expected)

    def table_input(self, where, item, corpus_item):
        self.counts["tableInputs"] += 1
        for p in item["prims"]:
            self.header(f"{where}: {p['name']}", p, p.get("classConstraints", []), {})
        used = set()

        def visit(v, _):
            if isinstance(v, dict) and isinstance(v.get("opaque"), dict) and len(v) == 1:
                used.add(v["opaque"]["name"])
        walk({k: item[k] for k in ("prims", "dataDecls", "valContents")}, visit)
        for e in item["valKinds"]:
            used.add(e["name"])
        if corpus_item is not None:
            walk(corpus_item, visit)
        table = dict(item["opaqueNames"])
        if len(table) != len(item["opaqueNames"]):
            self.error(where, "duplicate opaque names")
        if set(table) != used:
            self.error(where, f"opaque names {sorted(set(table) ^ used)}")
        for source, public in table.items():
            self.counts["opaqueNames"] += 1
            ident, args = source.split(":", 1)
            entry = self.reg[int(ident)]
            if entry["class"] not in ("Opaque", "Resource"):
                self.error(where, f"{source} is {entry['class']}")
            if entry["public"] != public:
                self.error(where, f"{source}: {public} != {entry['public']}")
            elif len(json.loads(args)) not in (0, entry["arity"]):
                self.error(where, f"{source}: argument count")
            else:
                self.counts["opaqueNamesDerived"] += 1

    def stdlib_input(self, where, item):
        for f in item["functions"]:
            self.header(f"{where}: {f['name']}", f["header"], f.get("dictParams", []), {})


def is_exchange_corpus(path):
    """根の欄（鍵順で `inputs` の後に `operators`・`version` が来る）から交換のコーパスを見分ける。"""
    with path.open("rb") as f:
        f.seek(max(0, path.stat().st_size - 400000))
        tail = f.read().decode("utf-8", "replace")
    return '"operators":' in tail and '"interval-corpus"' not in tail and '"seedXor"' not in tail


def inputs(path):
    for kind, key, index, value in events(path):
        if key == "inputs" and kind == "item":
            yield value


def main():
    directory, root, output = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    checker = Checker(registry(root))
    files = collections.Counter()
    for corpus in sorted(directory.rglob("*corpus.json")):
        if not is_exchange_corpus(corpus):
            continue
        stem = corpus.name[:-len("corpus.json")]
        table_path = corpus.with_name(stem + "builtins.json")
        tables = {}
        if table_path.exists():
            tables = {(t["group"], t["name"]): t for t in inputs(table_path)}
        files["corpus"] += 1
        corpus_items = {}
        for item in inputs(corpus):
            checker.corpus_input(f"{corpus.relative_to(directory)}: {item['name']}", item,
                                 tables.get((item["group"], item["name"])))
            if (item["group"], item["name"]) in tables:
                corpus_items[(item["group"], item["name"])] = {
                    k: item[k] for k in ("definitions", "constants", "ops", "classes", "impls")}
        for key, table in tables.items():
            files["tableInputsPaired"] += 1
            checker.table_input(f"{table_path.relative_to(directory)}: {key[1]}", table, corpus_items.get(key))
        stdlib = corpus.with_name(stem + ("stdlib.json" if stem else "stdlib-decls.json"))
        if stdlib.exists():
            files["stdlib"] += 1
            for item in inputs(stdlib):
                checker.stdlib_input(f"{stdlib.relative_to(directory)}: {item['name']}", item)
    result = {"files": dict(files), "counts": dict(checker.counts), "errors": checker.errors}
    output.write_text(json.dumps(result, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps(result, ensure_ascii=False))
    return 1 if checker.errors else 0


if __name__ == "__main__":
    sys.exit(main())

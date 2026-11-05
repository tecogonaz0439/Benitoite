"""公理監査の対象モジュール・必須入口と、前段から引き継ぐ宣言名を再生成する。"""
import json
import re
from support import HERE, MODULES, ROOT, write

# 今回の本番の公開入口は、二つのモジュールの名前付き宣言を本文から再抽出する。
required = set(json.loads((HERE.parent / "c/required-names.json").read_text()))
for module in MODULES:
    text = (ROOT / "formal" / (module.replace(".", "/") + ".lean")).read_text()
    space = [""]
    for line in text.splitlines():
        opened = re.match(r"^namespace ([\w.]+)$", line)
        closed = re.match(r"^end ([\w.]+)$", line)
        if opened:
            space.append(space[-1] + "." + opened[1] if space[-1] else opened[1])
        elif closed and len(space) > 1:
            space.pop()
        found = re.match(r"^(?:noncomputable )?(?:def|theorem) ([A-Za-z][\w.]*)", line)
        if found:
            required.add(space[-1] + "." + found[1])
write(HERE / "requested-modules.json", MODULES)
write(HERE / "required-names.json", sorted(required))
write(HERE / "referenced-names.json", [])
names = []
for path in sorted((HERE.parent / "a").glob("declarations-*.json")):
    for row in json.loads(path.read_text()):
        if row["module"] == MODULES[0]:
            names.append(row["name"])
write(HERE / "inherited-declarations.json", sorted(names))
print(json.dumps({"modules": len(MODULES), "required": len(required), "inherited": len(names)},
                 ensure_ascii=False))

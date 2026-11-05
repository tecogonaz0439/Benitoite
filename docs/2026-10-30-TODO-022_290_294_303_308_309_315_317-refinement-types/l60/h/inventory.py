# -*- coding: utf-8 -*-
"""段末の公理監査の対象モジュールと必須の名前を作り直す（群Gの同名の台本に倣う）。

対象モジュールは段で足した37と段で変えた既存の5で、全宣言の署名を印字する。必須の名前は、
段末の一覧が名指す C01〜C18・F01〜F08・旧主定理と新しい葉・後段の受け口、義務と申し送りの証拠と読者、
群A〜Gの必須の名前の和である。監査は必須の名前が既定環境にないと失敗する。"""
import json
import families
from support import L60, MODULES, PREFIX, write


def full(name):
    return name if name.startswith("Benitoite.") else PREFIX + name


names = set()
for table in (families.C_FAMILIES, families.F_FAMILIES, families.HANDOFFS):
    for group in table.values():
        names.update(full(n) for n in group)
for old, leaves in families.OLD_MAIN.items():
    names.add(old)
    names.update(full(n) for n in leaves)
records = json.loads((L60 / "g/obligations.json").read_text())["rows"] + \
    json.loads((L60 / "g/handoffs.json").read_text())["rows"]
for row in records:
    names.update(full(n) for n in row["evidence"] + row.get("readers", []))
previous = set()
for group in ["a", "b", "c", "d", "e", "f1", "f2", "g"]:
    previous.update(json.loads((L60 / group / "required-names.json").read_text()))
write(L60 / "h/requested-modules.json", MODULES)
write(L60 / "h/required-names.json", sorted(names | previous))
write(L60 / "h/referenced-names.json", [])
print(json.dumps({"modules": len(MODULES), "stage_names": len(names), "previous": len(previous),
                  "required": len(names | previous)}, ensure_ascii=False))

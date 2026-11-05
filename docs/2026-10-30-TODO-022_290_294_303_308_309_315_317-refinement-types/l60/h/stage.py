# -*- coding: utf-8 -*-
"""段末の一覧（../stage-results.md）と、その機械の照合の記録（stage.json）を作る。

表の件数・名前は群A〜Hの記録と既定環境の依存の書き出し（graph.lean の出力）から作り、手で写さない。
C01〜C18 の入口をL60の宣言が読む件数と、L60の宣言が旧主定理を読まないことも同じ書き出しで照合する。
使い方: python3 stage.py --log <graph.lean の出力> [--verify]"""
import argparse
import collections
import json
from pathlib import Path
import families
from support import B_WORK, HERE, L60, L60_BASE, MODULES, NEW, EDITED, PREFIX, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--log", type=Path, required=True)
parser.add_argument("--verify", action="store_true")
args = parser.parse_args()


def read(rel):
    return json.loads((L60 / rel).read_text())


def short(name):
    return name.removeprefix(PREFIX)


def full(name):
    return name if name.startswith("Benitoite.") else PREFIX + name


def code(names):
    return "・".join(f"`{n}`" for n in names) or "なし"


deps, owner = {}, {}
for line in args.log.read_text().splitlines():
    i = line.find("NODE ")
    if i >= 0:
        name, mod, kind, _, tdeps, vdeps = json.loads(line[i + 5:])
        deps[name], owner[name] = set(tdeps) | set(vdeps), mod
stage_modules = set(MODULES)
stage_names = {n for n, m in owner.items() if m in stage_modules}
audit = read("h/audit-summary.json")
copies = read("h/copies.json")
obligations = read("g/obligations.json")["rows"]
handoffs = read("g/handoffs.json")["rows"]
conditions = read("g/conditions.json")["summary"]
assumptions = read("f2/assumptions.json")
tables = read("f2/tables-check.json")
resources = read("e/resources.json")["summary"]

# C01〜C18 の入口を直接（型又は値で）読む段の宣言の数。
c_readers = {}
for cid, names in families.C_FAMILIES.items():
    c_readers[cid] = {n: sum(full(n) in deps[d] for d in stage_names if d != full(n)) for n in names}
# 段の宣言は旧主定理を型・値で読まない。
old_read = sorted(d for d in stage_names if deps[d] & set(families.OLD_MAIN))
assert not old_read, old_read[:5]
for old, leaves in families.OLD_MAIN.items():
    assert old in deps and all(full(n) in deps for n in leaves), old

# 段の宣言の群ごとの件数（モジュールを最初に足した群に数え、変えた既存のモジュールは別の行にする）。
by_group = collections.defaultdict(lambda: collections.Counter())
for part in audit["parts"]:
    for module, rows in json.loads((HERE / part["file"]).read_text()).items():
        group = "既存のモジュール" if PREFIX + module in EDITED else audit["touched_by_groups"][module][0].upper()
        for name, kind, _, _, generated, private, _, state in rows:
            if audit["states"][state] == "既存のモジュールで段に型が変わった宣言":
                continue
            c = by_group[group]
            c["宣言"] += 1
            c["定理"] += kind == "theorem"
            c["定義"] += kind != "theorem"
            c["private"] += private
            c["生成"] += generated
            c["名前付き"] += not generated and not private
edited = read("h/edited.json")
GEN = ("match_", "eq_", "_", "proof_", "splitter", "casesOn", "rec", "recOn", "mk")


def plain(change):
    return not change["name"].split(".")[-1].startswith(GEN)


modules_by_group = collections.Counter("既存のモジュール" if m in EDITED else audit["touched_by_groups"][short(m)][0].upper()
                                       for m in MODULES)

# 義務と申し送りの最終の判定（群Hの単位の分を反映する）。
H_OBLIGATIONS = {
    "O016": ("L60の分は完了（L60.35の段の公理監査・既定import・旧主定理と新しい葉の全名、L60.36の段末の独立レビュー"
             "RV-L60.h（条件付き可、中1・軽1）の処置）", "L70と各段レビュー"),
    "O027": ("L60.37の段末のworkと正式RSSは取りまとめの段末の work で確定（本書の作成の時点では未実施）", "L70/R20/R70の限定採取"),
    "O084": ("L60の分は完了（群Gまでと、L60.36の処置で停止条件に当たる変更0）", "L70/R/K/Vの合成・比較"),
    "O118": ("L60の分は完了（L60.34・.36の本番と写しに工程IDなし、verify.pyで照合）", "L70/R50/R60/D10/V10"),
    "O157": ("L60.34の分は完了（写しの段全体の照合、01-12の定理名の訂正1）", "L70境界改訂、R50除外0、D10/V10最終候補"),
}
H_HANDOFFS = {"S07": "完了（L60.34の写しの段全体の照合。copies.json）"}
final_obligations = []
for row in obligations:
    judgment, remaining = H_OBLIGATIONS.get(row["id"], (row["judgment"], row["remaining"]))
    final_obligations.append({**row, "judgment": judgment, "remaining": remaining})
final_handoffs = [{**row, "status": H_HANDOFFS.get(row["id"], row["status"])} for row in handoffs]
o_counts = collections.Counter(r["class"] for r in final_obligations)
h_counts = collections.Counter(r["class"] for r in final_handoffs)
assert o_counts == {"技術": 21, "記録": 1, "共通": 4, "他段": 1} and h_counts == {"L60受持": 41, "既済み継承": 4, "他段受持": 14}

L = []


def p(*lines):
    L.extend(lines)


p("# L60 段末の照合と受け入れ資料", "",
  f"2026-11-05。実装担当がL60.34〜.37（取りまとめの段末のworkを除く）を行った段末の資料である。指定ブランチは `m014/l60.h`、B_WORK は `{B_WORK}`、"
  f"段の開始版はL60の詳細の取り込み `{L60_BASE}` である。gitの操作は行っていない。L60.36で段末の独立レビュー（RV-L60.h）の所見を処置し、"
  "L60.37で義務・申し送りと受け口を確定した。**取りまとめの段末のwork・正式RSSと設計者の受け入れは未実施**である。"
  "群Hの作業記録は [h/results.md](h/results.md) にある。", "")

p("## 担当分と全体の区別", "",
  "L60は外部の宣言・応答・通常資源・合成表の葉と充足を閉じる段である。進行・保存・step_sound・effect_soundness/noLamNames、"
  "対象の一段・到達・表層、性質1、全表層checker・交換の切替はL70の所有であり、本段の成功をRust/Lean全比較やABI全体の証明と呼ばない。"
  "義務27行のL60の分と申し送り59行を一行ずつ判定した（下の二表）。義務全体を閉鎖した行は0である。各群の独立レビュー"
  "（RV-L60.a〜RV-L60.g）は全て処置済みで、群末のworkは取りまとめが各群で一度実行した（各群のresults.md）。", "")

# 段で足した宣言。
p("## 段で足した定義・言明・仮定", "",
  f"段の公理監査（[axioms.lean](axioms.lean)）の対象のうち、段で足した{len(NEW)}モジュールの全宣言"
  f"{audit['new_module_declarations']}件と、段で変えた既存の{len(EDITED)}モジュールに足した宣言"
  f"{audit['record_status']['既存のモジュールに段で足した宣言']}件の、"
  f"計{audit['new_module_declarations'] + audit['record_status']['既存のモジュールに段で足した宣言']}件を数えた。"
  "private と生成宣言（照合の補助・等式・展開の補題・証明の補助など）を含む。モジュールは最初に足した群に数える。"
  "全件の名前・種類・行・型のSHA-256・記録した群は [h/declarations](h/declarations-01.json) の分割記録にある。", "",
  "| 群 | モジュール | 宣言 | 定理 | 定義（def・inductive・構成子・再帰原理） | private | 生成 | 名前付きの公開 |",
  "|---|---:|---:|---:|---:|---:|---:|---:|")
order = ["A", "B", "C", "D", "E", "F1", "F2", "G", "既存のモジュール"]
for g in order:
    c = by_group[g]
    p(f"| {g} | {modules_by_group[g]} | {c['宣言']} | {c['定理']} | {c['定義']} | {c['private']} | {c['生成']} | {c['名前付き']} |")
total = collections.Counter()
for c in by_group.values():
    total.update(c)
p(f"| 計 | {len(MODULES)} | {total['宣言']} | {total['定理']} | {total['定義']} | {total['private']} | {total['生成']} | {total['名前付き']} |", "")
p("既存の5モジュールは、段の開始版のソースを一時領域で検査した環境と最終版の公理監査を全宣言（構造体の欄・private・生成宣言を含む）で"
  "比べ、新規・変更（型の印字が変わった）・継承・削除に分けた（[h/edited.py](h/edited.py)、[h/edited.json](h/edited.json)）。"
  "privateは実名の接頭辞を除いた名前で対応させた。上表の既存のモジュールの行は新規だけを数え、変更は分割記録に別の状態で置く。", "",
  "| モジュール | 新規 | 変更 | 継承 | 削除 |", "|---|---:|---:|---:|---:|")
for module, c in edited["counts"].items():
    p(f"| {module} | {c.get('新規', 0)} | {c.get('変更', 0)} | {c.get('継承', 0)} | {c.get('削除', 0)} |")
p("", "生成宣言（照合の補助・等式・再帰原理など）を除く名前は次である。privateの名前には（private）を付ける。"
  "新規はいずれも元の固定の表の定理を一般化した形とその前提をまとめる構造体であり、元の定理は一般化した形の元の表への適用として残る"
  "（群F1・F2の判断）。`StandardOrdinaryListBodies.Inputs` は欄 `constructors` を `options` に置き換え、"
  "`StandardOrdinaryCoreProgram` の `keyParam`・`pair` はprivateから公開に変えた（削除と新規の対）。", "")
for state in ["新規", "変更", "削除"]:
    names = [c["name"].removeprefix(PREFIX) + ("（private）" if c["private"] else "") for c in edited["changes"]
             if c["state"] == state and plain(c)]
    p(f"- {state}: {code(names)}")
p("", "段のモジュールから消した宣言は、群F1が `StandardModel.no_store_transitions` を `store_transitions` へ置き換えたこと（plan.md の群F1の判断）、"
  "群F2が読者のなくなった `StandardOrdinaryCoreBodies.getter_reference` を `getter_reference_of` へ"
  "置き換えたこと（plan.md の群F2の判断(5)）と、L60.35の読者の照合で見つけた、どの宣言にも例にも読まれない "
  "`StandardModel.definitions`（群Aの `StandardModelDeclarations` の一行の定義）を除いたことである。後者は写しと記録が名指して"
  "おらず、除いても他の宣言の型と値は変わらない（[h/results.md](h/results.md)）。", "",
  "仮定は次のとおりである。",
  "- Leanの公理：追加0。段の全宣言の公理依存は propext・Quot.sound・Classical.choice の部分集合だけで、sorryAx 0（下の「段末の公理監査」）。",
  "- 信頼条件：`Builtins.CoreAssumptions` の28欄、`Builtins.TargetAgreement` の1欄、`Builtins.ExternalAssumptions` の3欄の定義・欄数・"
  "意味は変えていない。三モデルと合成表はこれらを定理として構成し、主定理への新しい仮定にしていない。",
  "- 入口の前提：合成表の `program_typed`・`program_wellFormed`・`collection_inputs` は外部宣言の表の構造検証 `ExternalWF` を、"
  "三モデルのTargets・Httpは元と同じ `HasFile P`・`HasHttp P` を前提に取る。Pを外部宣言のないものに制限していない。",
  f"- 仮定側の名前：Leanの証拠がないRustの登録{tables['check2_assumption_without_evidence']['assumption_rows']}名は、"
  "07-04の方針どおり δ・IO応答・通常解放の条件として定理の引数で量化し、名前と理由を台帳に記す（下の「仮定側の全名前と理由」）。", "")

# 旧主定理と新しい葉。
p("## 旧主定理と新しい葉の対応", "",
  "旧主定理（旧Releaseの判断の主定理と旧三モデル）は変えず、既定importに残す。段の宣言は旧主定理を型でも値でも読まない"
  "（既定環境の依存の書き出しで照合）。次表の葉は、L70が新しい判断で同じ種類の言明を閉じるときにL60から読む入口である。"
  "対応は言明の種類の対応であり、旧主定理から新しい葉への依存ではない。", "",
  "| 旧主定理 | L70が読むL60の葉 |", "|---|---|")
for old, leaves in families.OLD_MAIN.items():
    p(f"| `{old}` | {code(leaves)} |")
p("")

# 全場合。
CASES = [
    ("宣言の鍵と値（4対）", "ExternalNominal.table_wf_iff・type_entry・function_entry・singleton_type・singleton_function、"
     "ExternalSignatureLeaves.declarations_wf", "同種の2対は受理、種違いの2対は拒否", "b"),
    ("専用ID（3種・6境界）", "ExternalNominal.unknown・unknown_handle・duplicate・distinct・declared_arity・handle_declaration・"
     "transformed_distinct", "表示名を等号に使わない。未知・重複・差替え・不正型引数の拒否", "b"),
    ("受渡し型（9規則）と外部型の出現（6規則）", "ExternalSignatureLeaves.occurrence_declaration・key_no_occurrence、"
     "ExternalModels.shape_inputs", "任意の有限の導出から同じcomponentの宣言へ。Mapの鍵の出現は適格な鍵で排除", "b・c"),
    ("名目型の全構文位置（Tyの21構成子）", "ExternalNominal.Preserves・transformations（29変換）、既存の Ty.bind_external",
     "全変換で同じIDを保つ。Ty.observationTypeは引数を空にする観測", "b"),
    ("使用位置と所有（3規則・4対）、署名（TelWF2規則・WF8欄）", "ExternalUseAt.mode、ExternalSignatureLeaves.use_declaration・"
     "declared_use・collected_contract", "argument/borrowとresult/ownの2対、uses_exactの両方向と一意性、単相・空kind、State", "b"),
    ("値と計算の直接規則（3規則）", "ExternalSurface.ref_typed・call_typed、ExternalNominal.handle_declaration",
     "既存のV_ExternalRef・V_ExternalHandle・C_Externalの読者。新しい型規則なし", "a・b・d"),
    ("型付けの移送（14判断・76枝）", "Builtins.TypingFieldsEq と14の `*.of_fields`", "同じPで七射影の等号からBだけをB'へ移す", "a"),
    ("carrier（12構成子）と篩の受信条件（12構成子）", "ExternalCarrier.of_fields・ExternalCarrierEach.of_fields・"
     "ExternalCarrierFields.of_fields、ExternalModels.responses、ExternalModelExamples.positive_receive_pair",
     "carrierまでを信頼し、篩は受信検査で読む", "a・c"),
    ("生の応答（4葉）", "ExternalModel.receive_value・receive_reject・receive_error_no_exit、ExternalModel.response",
     "検査成功・篩拒否・err・exitの排除", "c"),
    ("外部遷移（3葉）と外部IO対象", "StateTyE.external_step_of_response・external_receive・external_response_step、"
     "step_external_selected・step_external_apply", "E_External・E_ExternalErr・E_ExternalApply、観測は空", "d"),
    ("通常資源の分類（Rustの5種）", "StandardModel.resource_table・ExternalModels.ModelCase.resource_table・resource_iff、"
     "[e/resources.json](e/resources.json)", f"Leanの資源名はFile.Handleの1、Rustの5種は仮定側（{resources['rust_assumption']}）", "e"),
    ("解放の遷移（8葉）と解放枠への入口（1葉）", "StateTyE.release_return_all・release_escape_all・release_error_all・"
     "release_exit_all・use_release_all、ContTy.release_not_external", "4開始×成功・失敗。外部ハンドルを持たない", "e"),
    ("表層・脱糖の外部固有部分（5接続）", "ExternalSurface.type_declared_iff・ref_of_lookup・call_of_lookup・named_call・partial_call",
     "ソース順の評価・束縛と生成ラムダの型付けはL70", "d"),
    ("偽造を断る境界（3分類）", "ExternalSignatureLeaves.handle_not_source・non_binding_pattern_rejected・"
     "constructor_value_rejected", "変数とwildcardの束縛は認める。実CLIはR50/V10", "b"),
    ("三モデルの12欄", "ExternalModels.ModelCase.composition・external_constant・new_field_inputs、"
     "ExternalModels.model_vacuous_premises", "下の四分類", "e・g"),
    ("登録の表と既存証拠（E01〜E15の552出典行・三モデル75欄・Rust 61部分523参照）", "[f2/tables-check.json](f2/tables-check.json)",
     f"合成{tables['check3_composition_lookup']['composition_rows']}行・仮定{tables['check2_assumption_without_evidence']['assumption_rows']}行。"
     f"対応のない出典行{tables['check1_evidence_to_composition']['unmapped']}、仮定側の証拠名{tables['check2_assumption_without_evidence']['with_evidence']}", "f2"),
]
p("## detail.md 第2節の全場合", "",
  "各母集団の全場合を量化した証拠の入口と、完了を記した群の記録である。件数のうち Tyの21構成子・14判断76枝・carrierの12構成子・"
  "29変換・合成表の377行と130本体は、段末に既定環境の構成子の数と前の群の照合の記録で数え直した（[h/copies.json](h/copies.json) の `counts`）。", "",
  "| 母集団 | 証拠の入口 | 全場合の判定 | 群 |", "|---|---|---|---|")
for population, entries, judgment, groups in CASES:
    links = "・".join(f"[{g.upper()}]({g}/results.md)" for g in groups.split("・"))
    p(f"| {population} | {entries} | {judgment} | {links} |")
p("")

# 四分類。
m87 = conditions["models87"]
p("## 四分類の最終件数", "",
  "第2.4節の定義（不成立・空疎・自明・実質）で判定した最終の件数である。前提も入力も持たない `state_effect`・`ref_get`・`ref_set` と、"
  "任意のP・C・aについて定義で閉じる `sat_unconstrained` を自明に数える2026-11-05の設計者の決定を反映した。"
  "判定の行ごとの記録は [g/conditions.json](g/conditions.json)、論点は [g/cases.md](g/cases.md) にある。", "",
  "| 母集団 | 実質 | 自明 | 空疎 | 不成立 | detail.mdの目標・前段の値との差 |", "|---|---:|---:|---:|---:|---|")
rows4 = [("三モデルの新12欄", m87["新12"], "目標と同じ"),
         ("三モデルの既存75欄", m87["既存75"], "L50の受け入れ（実質69・空疎6）から実質−12・自明+12"),
         ("三モデルの87欄", m87["合計87"], "目標（実質76・自明3・空疎8）から実質−12・自明+12"),
         ("合成表の28+1欄", conditions["composite29"], "目標なし"),
         ("合成表の行の契約96行", conditions["rows96"], "目標なし（純粋86・IO/終了10）")]
for label, c, note in rows4:
    p(f"| {label} | {c.get('実質', 0)} | {c.get('自明', 0)} | {c.get('空疎', 0)} | {c.get('不成立', 0)} | {note} |")
p("", "差の12欄は三モデルの `state_effect`・`ref_get`・`ref_set` の9欄と `sat_unconstrained` の3欄であり、証明は変わらず分類の基準を"
  "第2.4節に揃えた差である。保留は0、空疎は前提の否定の導出を持つ8欄（Modelのpure・IO・exitの6欄とModel・Httpの解放の2欄）だけである。"
  "各群の葉の分類（群Bの保持の系・偽造の境界、群Dの四分類の集計など）は各群の記録にあり、ここに足し合わせない。", "")

# 義務。
p("## 義務27行の最終の判定と残る所有", "",
  "群Gの照合（[g/obligations.md](g/obligations.md)。証拠の完全名と種類を既定環境で照合）に、群Hの単位の分を反映した。"
  f"分類は技術{o_counts['技術']}・記録{o_counts['記録']}・共通{o_counts['共通']}・他段{o_counts['他段']}である。"
  "「L60の分は完了」は右列の残る所有を残す。義務全体の閉鎖は右列の段が終わった後に判定する。", "",
  "| 義務 | 分類 | 判定 | 証拠 | L60後に残る段 |", "|---|---|---|---|---|")
for r in final_obligations:
    p(f"| {r['id']} | {r['class']} | {r['judgment']} | {code(r['evidence'])} | {r['remaining']} |")
p("")
p("## 申し送り59行の最終の判定", "",
  "群Gの照合（[g/handoffs.md](g/handoffs.md)。読者の型又は値の定数の閉包に証拠が含まれることを経路で照合）に、群Hの単位の分を反映した。"
  f"分類はL60受持{h_counts['L60受持']}・既済み継承{h_counts['既済み継承']}・他段受持{h_counts['他段受持']}である。"
  "L60.35で同じ照合を段の最終状態の書き出しに対して再実行し、全59行の読者の経路が一致した（[h/verification.json](h/verification.json)）。", "",
  "| 行 | 分類 | 状態 | 証拠 | 読者 | 注記 |", "|---|---|---|---|---|---|")
for r in final_handoffs:
    p(f"| {r['id']} | {r['class']} | {r['status']} | {code(r['evidence'])} | {code(r['readers'])} | {r['note']} |")
p("")

# 受け口。
NOTES = {
    "L70 名目性と署名": "有限外部表と名目性・borrow/own/Stateをソース収集から供給する。Rust受理→WFの向きだけ",
    "L70 表層と脱糖": "全表層・脱糖・checkerの子の結果から同じ篩付きの型・効果へ。名前付き引数・穴・評価順と全表層の健全性の合成はL70。"
                   "Leanの `Val.Source` は外部参照を値として拒否しない（Rustは拒否する。群Dの判断）",
    "L70 進行・保存・step_sound": "任意の型付き外部開始から同じP/B/σ/Eb/μで存在と計算→関係。逆方向の完全性は結論しない",
    "L70 通常資源": "`ResourceRelease.Table` の表で四開始の全結果の遷移と型付け、実行関数の選択",
    "L70 三モデル": "三モデルの既存25欄＋外部3欄＋解放1欄とCore・対象条件。四分類の根拠と正常・拒否の入力を添える",
    "L70 合成表": "合成対象の同じP/Bの28+1欄・WellTyped・WellFormed・入力の定理。利用者Pへの収集と全主定理・互換readerの切替はL70で一度だけ。"
               "衝突18名の公開名から内部名への対応はRustの登録と標準ソースの実定義で定める（群Aの判断）",
    "R10b・R50 外部の宣言": "実external型ID・入れ子・宣言表・borrow/own/State・合成側のsourceTelRows/operationKinds・資源の分類との照合。"
                        "入力の型をopaque/Topへ消さない",
    "R30・R50 通常資源と範囲": "実資源の解放・中断・失敗と抽象関係の向きの照合。外部ownの解放は既存の別の義務。実体・副通信・OSの保証を足さない",
    "R50 比較": "F-CONNで二つの除外の理由（externalType・external function）の実の件数（未実施）。仮定側150名と実登録の対応、"
              "関数値が到達しうる27行の二表現の比較（[g/function-values.json](g/function-values.json)）、合成表の鍵の順序と処理系の構成子の順序",
    "D10・V10・K10": "O086/O157/O168の段別の証拠と残る所有。新しい葉・写しと、R50の実0件と実候補を混同しない",
}
p("## 後段へ渡す署名と受け口", "",
  "完全名の接頭辞は `Benitoite.Release.Refinement.` である。L70・Rの各段はこの表の入口を受け取る。全暗黙引数を含む実署名は、"
  "F01〜F08・旧主定理・C01〜C18・この表の入口の和集合を [h/signatures](h/signatures-01.md) の分割記録に一回分置き、各入口の保存先を"
  "「実署名」の列に示す。主な定義の本体は [h/definitions.md](h/definitions.md) にある。どの名前も段の公理監査の必須の名前に含めた。", "",
  "| 受け手 | 入口 | 実署名 | 受け持つ残件 |", "|---|---|---|---|")
index = audit["signature_index"]
for receiver, names in families.HANDOFFS.items():
    assert all(n in index for n in names), receiver
    files = sorted({index[n] for n in names})
    p(f"| {receiver} | {code(names)} | " + "・".join(f"[{f}](h/{f})" for f in files) + f" | {NOTES[receiver]} |")
p("", "U02（公開のPathBases・At・ScopeErrorと安全な入口の名前と字面）とU05（交換版・readerの切替）は未決のまま保ち、L60の内部名を公開形へ先取りしていない。", "")

# F と C。
p("## F01〜F08 の入口と C01〜C18 の継承", "",
  "F01〜F08の名前の一覧は次である。F・Cの全名の実署名は [h/signatures](h/signatures-01.md) の分割記録にある。群Aで固定した完全署名から群F2が使わない"
  "前提 `hw` を除いた `definition_typed`・`core` は、元の形の適用例を既定ビルドに置いた（plan.md の群F2の判断(4)）。", "",
  "| 族 | 入口 |", "|---|---|")
for fam, names in families.F_FAMILIES.items():
    p(f"| {fam} | {code(names)} |")
p("", "C01〜C18は前段の入口であり、L60は再実装していない。各名前を型又は値で直接読む段の宣言の数を、段の最終状態の依存の書き出しで数えた。"
  "0の名前は段の宣言が直接は読まず、同じ族の別の入口か前段の読者を経て使う。", "",
  "| 控除 | 名前（直接読む段の宣言の数） |", "|---|---|")
for cid, counts in c_readers.items():
    assert all(n in index for n in counts), cid
    p(f"| {cid} | " + "・".join(f"`{n}`（{c}）" for n, c in counts.items()) + " |")
p("")

# 仮定側。
p("## 仮定側の全名前と理由", "",
  f"最終の台帳の仮定側は{tables['check2_assumption_without_evidence']['assumption_rows']}名である（群F2の [assumptions.json](f2/assumptions.json)）。"
  "種類ごとの理由と全名前を次に示す。どの名前もE01〜E15に同名の実算法・状態の対応証拠がなく、新しい意味や定数errで補っていない。"
  "R50が実登録との対応と形式化の内外を確かめる。", "")
kinds = collections.OrderedDict()
for row in assumptions["names"]:
    kinds.setdefault(row["kind"], {"detail": set(), "names": []})
    kinds[row["kind"]]["detail"].add(row["detail"])
    kinds[row["kind"]]["names"].append(row["lean_name"])
assert sum(len(v["names"]) for v in kinds.values()) == len(assumptions["names"]) == 150
for kind, v in kinds.items():
    p(f"### {kind}（{len(v['names'])}名）", "", "理由: " + "／".join(sorted(v["detail"])) + "。", "", code(v["names"]), "")

# 写しと監査。
p("## 01-12・07-04 の写しの照合", "",
  f"段の開始版から作業木までに01-12と07-04へ加えた文の `…` の名前{copies['tokens']}件を、既定環境の宣言・名前空間・モジュールへ解決した"
  f"（[h/copies.py](h/copies.py)、[h/copies.json](h/copies.json)）。分類は "
  + "・".join(f"{k}{v}" for k, v in copies["by_class"].items()) + "で、未解決は0である。"
  "Leanの既定環境の外の名前（表層の構文・処理系のソース・実行時の誤りの理由の文字列・既定importの外の検査の道具）は、所在を記録に書いた。"
  f"段で足した{copies['new_modules_in_table']}モジュールは全て07-04の形式化のモジュールの表の行に現れる。段で消した宣言の名前は写しに残っていない。"
  "写しが述べる件数（14判断76枝、carrierの12構成子、Tyの21構成子、29変換、合成表の377行・130本体、入力の定理の79・7・10行）は"
  "既定環境の構成子の数と前の群の照合の記録で一致した。", "",
  "照合で01-12の一箇所の食い違いを見つけて直した。群Bの再開2で `constructor_pattern_rejected` を `non_binding_pattern_rejected` へ改名した"
  "（RV-L60.b の再レビューの新軽2）が、01-12の外部の偽造の境界の段落が旧名のままだった。07-04の同じ境界の段落は定理の名前を書かず、変更は要らない。直したのはこの一語だけである。", "",
  "群F2が既存のモジュールに足した一般化の形（`*_of`）は写しに個別の名前で書いていない。写しが述べる固定の表の定理は一般化の形の適用として残り、"
  "述べた内容は現在も成り立つ。合成表の上での再証明は01-12の `StandardModel.body_typed` の段落が述べる。", "")
p("## 段末の公理監査と型のハッシュ・読者の照合", "",
  f"段の [axioms.lean](axioms.lean) は既定Benitoiteのimport閉包{audit['modules']}モジュールの全プロジェクト宣言{audit['targets']}件"
  f"（private・生成宣言を含む）を所属モジュールから固定点（{audit['closure_rounds']}巡）で列挙し、全件に `#print axioms` を行った。"
  "標準ライブラリの使用定義への依存は各 `#print axioms` が再帰的に辿る。公理の組は次である。許可した三公理の外0、sorryAx 0、新しい公理0。", "",
  "| 公理依存の集合 | 全宣言 | 段の宣言 |", "|---|---:|---:|")
for k, v in audit["axiom_sets"].items():
    p(f"| {k} | {v} | {audit['stage_axiom_sets'].get(k, 0)} |")
p("", f"段の宣言{audit['stage_declarations']}件の型のSHA-256を群A〜Gの記録の型と照合した（[h/audit.py](h/audit.py)、[h/audit-summary.json](h/audit-summary.json)）。"
  "状態は " + "・".join(f"{k}{v}" for k, v in audit["record_status"].items() if k != "既存のモジュールの宣言（段の前から）")
  + "で、群の記録との差は0である。既存の5モジュールの「段で足した宣言」「段に型が変わった宣言」は段の開始版との比較（[h/edited.json](h/edited.json)）による。「記録の後の群が変えた宣言」は、群F1・F2が組込みの行の構成子を足したことによる "
  + code(audit["changed_after_record"]) + " の型の変化であり、「記録の後の群が足した宣言」は群F1・F2が群Aのモジュールへ足した行・署名・宣言である。"
  "「群Aの名前の記録」は群Aが名前だけを記録した宣言で、型の照合の対象がない。", "",
  "義務と申し送りの証拠・読者の依存は、群Gの台本（[g/records.py](g/records.py)）を段の最終状態の依存の書き出しに対して照合の形で再実行し、"
  "全86行の証拠と読者の経路が群Gの記録と一致した。四分類・除外の境界・関数値の行の台本（conditions.py・boundary.py・function_values.py）も同じ形で一致した。"
  "段で足した全モジュールの公開した入口は、名前付きの読者又は既定ビルドの適用例を持つ（[h/readers.json](h/readers.json)）。"
  "段のモジュールのソースに sorry・axiom・native_decide・#eval・工程のIDはない。`set_option maxHeartbeats`・`maxRecDepth` は群A・F2と段の前の"
  "既存のモジュールが置いた15箇所であり、一覧を [h/verification.json](h/verification.json) に記した（段末に足したものはない）。", "")

# 見込みと実績。
SPANS = [("A", "08:10:42〜11:23:47（初回から再開4まで中断込み）、再開5 3分47秒", "542.96"),
         ("B", "11:46:53〜12:17:01（四単位）、再開1 12:28:55から", "593.60"),
         ("C", "13:05:14〜13:34:05（四単位）、再開1 6分9秒", "575.78"),
         ("D", "14:04:20〜14:33:50（読解を含む約30分）、再開1", "615.28"),
         ("E", "14:11:06〜14:32:23（四単位、区間は重なる）、再開1・2", "620.95"),
         ("F1", "15:21:00〜15:37:07（三単位）、再開1 16:16:21〜16:26:09", "630.68"),
         ("F2", "16:49:19〜19:38:00（四単位）、RV-L60.f2 の処置", "877.69"),
         ("G", "20:20:09〜21:22:00（読解を含む約1時間02分）、RV-L60.g の処置 21:34:32〜21:41", "861.05")]
p("## 見込みと実績", "",
  "段の枠は所要時間（能動時間）17〜41時間（中心29）、37単位の積上げは21時間55分〜37時間10分である。下表は各群のresults.mdにある外側の区間で、"
  "能動時間と待ちは分離していない。読解・取りまとめ・独立レビュー・回答待ちの時間を含まない区間があるため、能動時間の見込みは変更しない。"
  "群Hの区間は [h/results.md](h/results.md) にある。", "",
  "| 群 | 記録にある外側の区間（2026-11-05、JST） | 群末のworkの外側の時間（秒、取りまとめ） |", "|---|---|---:|")
for g, span, work in SPANS:
    p(f"| [{g}]({g.lower()}/results.md) | {span} | {work} |")
p("")

p("## 計画との差と設計者の見直しの対象", "",
  "各群の計画からのずれと取りまとめの判断は、plan.md「計画の変更と取りまとめへの確認点」の2026-11-05の項目と各群のresults.mdにある。"
  "段の主な差は次である。",
  "- 衝突18名を合成表の内部名に分け、元Defを保持して関数参照名だけを単射で写した（群A。設計者の見直しの対象）。",
  "- J60-3=(a) により、Leanの証拠がある行だけを合成し、`Reference.new`・`Reference.update`・`Lazy.force` と `%List.getFront` を合成側へ、"
  "`Process.exit` を仮定側へ置いた（群E・F1・F2）。",
  "- Leanの `Val.Source` が外部参照を値として受け入れ、Rustが拒否する差を変えず、L70の収集とR50へ申し送った（群D。設計者の見直しの対象）。",
  "- 前提も入力も持たない三欄と三モデルの `sat_unconstrained` を自明に数えた（群G。設計者の決定）。",
  "- 群F2が群Aの完全署名から使わない前提 `hw` を除き、既存の証明に一般化の形を足した（群F2の判断(4)(5)）。",
  "- 段末に01-12の旧名一語を直し、読者のない `StandardModel.definitions` を除き、群Aが根から直接importしていなかった6モジュール"
  "（FunctionNameMap・StandardModelDeclarations・StandardModelSignatures・StandardModelPrimitiveLookup・BuiltinResponseTransport・"
  "ExternalModelTransport。既定importの閉包には入っていた）を `formal/Benitoite.lean` のimportに加えた（群H）。", "",
  "主な10言明・型付けの規則・Step・CoreAssumptions・TargetAgreement・前段の実署名は変えていない。新しい公理・独立の信頼条件・精密な外部状態・"
  "書ける形の制限・提供範囲の削減・U02に依存する公開形の選択は0である。", "")

p("## L60.36・L60.37 の受け口と残りの手順", "",
  "| 手順 | 担当・内容 | 見込み |", "|---|---|---|",
  "| 段末の独立レビュー | RV-L60.h（[../reviews/RV-L60.h.md](../reviews/RV-L60.h.md)）。条件付き可（重0・中1・軽1） | 実施済み |",
  "| L60.36 所見の処置 | 中1（既存の5モジュールの宣言の判定）・軽1（実署名の保存先）を処置した（[h/results.md](h/results.md) の「RV-L60.h の処置」）。"
  "本番のLeanは変えていない | 実施済み |",
  "| L60.37 受け渡し | 義務・申し送りの最終の判定と残る所有、L70・Rへの受け口を本書に確定した | 実施済み |",
  "| L60.37 最終work・正式RSS | 取りまとめが同じ最終状態でworkを一度実行し、sandbox外で正式RSSを同じ実行に付ける。O027はこの実行で確定する | 未実施 |",
  "| 段末の受け入れ | 設計者。本書は受け入れを記録しない | 未実施 |", "")
text = "\n".join(L) + "\n"
assert len(text.encode()) <= 100000, len(text.encode())
record = {"c_readers": c_readers, "old_main_read_by_stage": old_read, "by_group": {k: dict(v) for k, v in by_group.items()},
          "obligations": collections.Counter(r["judgment"].split("（")[0] for r in final_obligations),
          "handoffs": collections.Counter(r["status"].split("（")[0] for r in final_handoffs),
          "bytes": len(text.encode())}
record = json.loads(json.dumps(record, ensure_ascii=False))
if args.verify:
    assert (L60 / "stage-results.md").read_text() == text, "stage-results.md が台本の出力と違う"
    assert json.loads((HERE / "stage.json").read_text()) == record
    print(json.dumps({"verified": True, "bytes": len(text.encode())}))
else:
    (L60 / "stage-results.md").write_text(text)
    write(HERE / "stage.json", record)
    print(json.dumps({"bytes": len(text.encode()), "by_group": record["by_group"]}, ensure_ascii=False)[:1500])

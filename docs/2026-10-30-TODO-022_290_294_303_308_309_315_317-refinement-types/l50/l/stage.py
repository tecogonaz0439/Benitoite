"""確定した監査と一行表から、独立レビューへ渡す段末本文を生成する。"""
from pathlib import Path
import argparse
import collections
from datetime import datetime
import json
import re
from inventory import HERE, STAGE, CHANGE, ROOT, PREFIX, digest, write


def short(text):
    return text.replace(PREFIX, "").replace("Benitoite.Release.", "Release.").replace("Benitoite.Scope.", "Scope.")


def names(items):
    return "、".join("`" + short(x) + "`" for x in items) or "なし"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    audit = json.loads((HERE / "audit-summary.json").read_text())
    rec = json.loads((HERE / "reconciliation.json").read_text())
    signatures = {n: (m, int(line), typ.strip()) for m, n, line, typ in
                  json.loads((args.tmp / "stage-signatures.json").read_text())}
    families = json.loads((HERE / "families.json").read_text())
    trace = [r for f in rec["trace_parts"] for r in json.loads((HERE / f["file"]).read_text())]
    stage = """# L50 段末の照合と受け入れ資料

2026-11-05。実装担当がL50.56〜.58・.60の担当分を照合した資料である。指定ブランチは `m014/l50.l`、B_WORK は `70d726b70b6cb4cbf5abace21d377f6ae155b512`。gitの操作は行っていない。L50.59の段末独立レビューへの応答は別の起動とし、今回は受け口だけを用意した。**段末の独立レビュー・正式な最終work/RSS・設計者の受け入れは未実施**である。

## 担当分と全体の区別

技術26義務のL50担当分と、記録2義務の今回の記録を照合した。他段1義務の入力推論と、共通4義務の後段・レビュー・限定採取を分ける。L50の技術的な独立未完は0件であり、未実施のレビューや受け入れを完了へ繰り上げない。33義務の全体を閉鎖した行は0である。

31申し送りは技術24・継承5・他段2の全行を照合した。H17の既済み三補題やH18の処分済み事項を再実装せず、L60/L70/R/D/Vの受け口を保持した。三モデルの75欄は実証済みの出力であり、各モデルのexternal三欄とrelease一欄、計12欄はL60の所有である。

## 全場合と実δ・実行の接続

| 母集団 | 照合結果・証拠 | 後段との境界 |
|---|---|---|
| F01〜F10 | 下記の実定義・実署名。F04/F05は承認済みのNamesWFを含み、F06.currentは不要なCaptureOkを持たない | 主な十言明の形を今回変更していない |
| 起点付加と被覆 | 4パターン対、RangeExpr9対、5起点の等号/不等号、RangeIx4対、Atom9対。ScopeCoverage/MembershipTargets/EffectTargets。全σの所属、同じsnapshot、対象3sortへ接続 | 静的被覆はσを読まない。異なる起点の解決先が等しくても静的には同一視しない |
| 値の型付け | 29規則・25構文、canonical_heldの四形からConstOKで定数を排除し保持三形へ。要求はcheckedRequestとcheckedAt(some req)の二経路 | 任意Ψと非Top/Top、全適格σを維持。一般のValの全shape一致へ強めない |
| 準備とAt | 局所23葉は別母集団。終端失敗15、成功4経路×checkAt8の上限47から12組を排除して35、型付きindexで34。[全場合](d/cases.md)とStateTyE.at_step | 経路の全直積や到達する型付き状態の存在数ではない。全失敗の保存を保持 |
| 13範囲API | 純粋6行・IO7行の全入力、同じ実δ又は実応答関係、全応答の型・適格性・非exit、応答存在を[別列](l/apis.md)で照合 | 正常応答の存在・実IOの成功・副通信の隔離を保証しない |
| 共通表とモデルの署名 | 共通16行＝13＋Reference2＋発行1。Model3・ModelTargets15・ModelHttp7の延べ25行 | 同じPの有限宣言・lookup・arity・行支持。全標準328APIの収集はL60/L70 |
| U1 | 2規則・4保持経路、7位置・5具体化行を[k/connections](k/connections.md)へ照合 | 同じ保持元と実引数位置の一致は入口の前提であり、全体の値の流れはL70。推論手続きはR10b/R30 |
| 実行の読者 | E_Prim/E_Err、E_IO/E_IOErr/E_Exit、E_OpPrimとAt3/発行2の11葉。ScopedTargetInputsと既存保存葉 | 同じσ/Eb/μ、捕捉したhandlerだけfresh継続セルを追加。全保存・到達・表層はL70 |
| 診断の保存 | 失敗7構成子、unboundの5base展開で11形、20等号（save9/fromCheck9/準備の元入力2）。AtErrorReaders | 内部の九欄と七String観測。元の生Valを観測から取り出さない条件を保持。公開形はU02後 |
| 否定 | DET-R01〜26を[k/denials](k/denials.md)の解析済みの内側と字句・CLI・外部・公開形へ分離 | 起点差/分割被覆/未束縛/偽造のLean境界と、実CLIの拒否を混同しない |
| 移植 | 27目的＝新規候補26＋継承T07。Bの13新移植と継承1、C/E/F/Gの残る族を実入口へ対応 | 同じ目的を新定理の件数に加算しない。後段のTargetStep/TargetPropagationは合成の読者 |

充足と応答存在は別に判定した。単に欄の型が存在することや、空の関係についての全称命題を、型付き入力に対する存在証明の代用にしていない。

## 三モデルの75欄

完全名の先頭は、特に断らない限り `Benitoite.Release.Refinement` である。表の各行の原契約は[j/conditions](j/conditions.md)、その75欄の全称の契約を同じ既定環境で単独Leanにより再検査した記録は[l/conditions-check](l/conditions-check.json)である。Modelは任意P、ModelTargetsはHasFile P、ModelHttpはHasHttp Pを使う。

| 番号 | 同じモデル | 欄 | 実証の入口と出力 | 判定 |
|---:|---|---|---|---|
"""
    conditions = json.loads((STAGE / "j/conditions.json").read_text())
    for i, row in enumerate(conditions, 1):
        stage += f"| {i} | {row['model']} | {row['field']} | `{row['theorem']}` → `{row['projection']}` | 証明済み |\n"
    stage += """
## L60へ残す12欄と具体の入口

各行は同じP/Bで `ModelScopeConditions.core` のexternal又はrelease引数へ渡す。三モデルの外部応答関係は空である。external_typed/no_targetsの全称命題が空疎に成り立ってもexternal_existsを代用しない。外部宣言・ExternalWF・型付きExternalArgsを持つPでは現在のexternal_existsは成り立たない。

| モデル | 残る欄 | 具体の入口・現在の制限 |
|---|---|---|
"""
    for model in ["Model", "ModelTargets", "ModelHttp"]:
        call = f"({model}.scopeConditions P" + ("" if model == "Model" else " hp") + ").core external release"
        for field in ["external_typed", "external_exists", "external_no_targets", "release_exists"]:
            if field.startswith("external_"):
                entry = f"`Builtins.ExternalAssumptions.{field}`を同じP/{model}.builtinsで束ね、`{call}`へ"
            else:
                entry = f"`{call}`のrelease引数。"
                entry += "isResource=falseで前提が偽、空疎" if model != "ModelTargets" else "File.Handleの前提は充足可能だが、releaseResponseはr=noneで結論が自明"
            stage += f"| {model} | {field} | {entry} |\n"
    stage += """
L60は計画された外部応答・通常資源の関係を実表へ接続する。[群J](j/handoffs.md)・[群K](k/l60-fields.md)の注意を保持し、空の表から任意Pの全Coreを構成しない。外部型の名目性、borrow/own/Stateと通常資源のreleaseは範囲IOの新葉と別に閉じる。

## 33義務の段別の証拠と残る段

前段はREADMEに従いL20/L30を2026-11-03、L40を2026-11-04に設計者が受け入れ済みとして継承する。次表はL50担当分の証拠であり、義務全体の閉鎖は0行である。完全名・所在・実型のSHA-256は[l/trace-part](l/trace-part-01.json)の二分割にある。

| 義務 | 分類・今回の判定 | 実証の入口 | 残る段と具体の受け口 |
|---|---|---|---|
"""
    for r in trace:
        if r["kind"] != "obligations":
            continue
        stage += "| " + " | ".join([r["id"], r["classification"] + "：" + r["stage_status"],
            names(r["proofs"]), r["remaining_entry"].replace("|", "／")]) + " |\n"
    stage += """
O016/O084の段末独立レビューとL50.59、O027の正式な最終work/RSSは今回の担当を完了したことと区別する。O118の今回の写し・コメント照合は完了した。これらの既知の未実施を、新たに発見した証明の独立未完として後段へ付け替えていない。

## 31申し送りの一行ずつの照合

| 受け口 | 分類・L50の証拠 | 実際の入口 | 残る所有と受け口 |
|---|---|---|---|
"""
    for r in trace:
        if r["kind"] != "handoffs":
            continue
        stage += "| " + " | ".join([r["id"], r["classification"] + "：" + r["finding"],
            names(r["proofs"]), r["remaining_entry"].replace("|", "／")]) + " |\n"
    stage += """
義務・申し送り64行の読者は型と値の依存から再抽出した。**依存する読者あり49、証拠そのものが入口8、同じ前提を共有するだけ4、記録・監査の関係3**である。49行のうち33行は、証拠の一部だけに名前付きの読者がある。各行の証拠全部へ読者があるという意味ではない。証拠ごとの経路とprivateの読者は[k/reader-dependencies](k/reader-dependencies.json)と一致し、同じ80672節点の抽出を再検査した。無名の適用例は名前付きの読者へ数えない。

## F01〜F10の実際の完全署名と定義形

以下は同じ監査の型印字から名前空間の共通の接頭辞だけを省いたものである。量化・暗黙引数・前提・結論を省かない。`open Benitoite`・`open Benitoite.Release`を置いた `namespace Benitoite.Release.Refinement` の中で読む。全名を展開した1771実署名は[l/signatures-part](l/signatures-part-01.md)の分割記録、定義の本体・構造体の全欄は[l/definitions](l/definitions.md)にある。

"""
    for family, ns in families.items():
        stage += "### " + family + "\n\n"
        for name in ns:
            module, line, typ = signatures[name]
            src = "formal/" + module.replace(".", "/") + ".lean"
            stage += f"所在: [{short(name)}](../../../{src})（行{line}）。\n\n```lean\n{short(name)} :\n{short(typ)}\n```\n\n"
        if family == "F02":
            stage += "Eff.Allowsの定義はEffectFactsに一つだけあり、対象の種類と同名の固定範囲原子の所属から同じσのMemを要求する。静的Coversにはσを足さない。\n\n"
        elif family == "F04":
            stage += "NamesWFはplanで承認した追加前提であり、実表のPrimSig.Scoped.namesWFから供給する。任意の位置pを量化する。\n\n"
        elif family == "F06":
            stage += "AtPrepared.currentはCaptureOkを要求しない。元状態の閉包・basesの適格性から供給する。Readyを全状態の新たな前提にしない。\n\n"
        elif family == "F07":
            stage += "純粋六行・IO七行の各実名の完全型も署名分割記録へ保存した。ScopeResponseの同じ決定的δの存在と全応答、ScopedIOResponseの同じ関係の全応答と存在を区別する。正常成功の存在は要求しない。\n\n"
        elif family == "F09":
            src = ROOT / "formal/Benitoite/Release/Refinement/TargetModelConditions.lean"
            body = src.read_text().split("structure ModelScopeConditions", 1)[1].split("/--", 1)[0]
            stage += "実際の出力の定義形は次のとおりである。主定理の新しい未検査の前提ではない。\n\n```lean\nstructure ModelScopeConditions " + body.strip() + "\n```\n\n"
        elif family == "F10":
            stage += "Detail Valは失敗・生入力二欄・解析済み二欄・解決済み二欄・両起点の九欄を保持する。未解析noneと未解決、解決済みの空列を区別する。公開PathBases/At/ScopeErrorの形はここで選択しない。\n\n"
    stage += """
## 後段へ渡す署名と受け口

| 受け手 | 実際の署名・証拠 | 受け持つ残件 |
|---|---|---|
| L60 | Model/ModelTargets/ModelHttp.scopeConditions、ModelScopeConditions.core、ScopeResponse.delta_typed、ScopedIOResponse.response/io_exists | 同じP/Bの外部三条件と通常資源のreleaseを構成し、全標準実表へ組み込む。75欄の出力を新しい公理や独立の信頼条件にしない |
| L70 | F01/F02/F03/F04/F05、AtPrepared.current/StateTyE.at_step、ScopedTargetInputs.response_inputs/pure_steps/io_steps/handled_step/at_steps/path_bases_apply/issue | 主な全保存・進行・step_sound・事象/対象の一段・到達・表層、同じσ/Eb/ストアへの合成。保持元と実引数位置の全体の値の流れ |
| R10b/R30 | ScopedCallContracts.single_inputs/request_inputs、ScopedTargetExamples.single_io/request_io/widened_input/incomparableと13API表 | 入力から一度だけ範囲を具体化する推論、5形と7位置の実受理・拒否。結果型/許容効果からrsを逆算しない |
| R30/R70 | Source/PreparationTargets、ModelTargetsExamplesの発行、AtPrepared.current、起点差・secretsの全称の入口 | 固定σの供給、PathBases/Atと同じ保持絶対対象をFile6本/Httpへ。work/tmpの実在と管理、起動形・別cwd・secretsのCLI拒否、heap/stress |
| R50 | ScopeResponse/ScopedIOResponseの同じ実δと全応答、起点差・Top・要求二形、parseUrlTargetとparseAtInput、pathValueRun_parseAtInput | L70のF-REG後のF-CONN、外部関数を含む全比較。δの既知の三差はE再開1で揃え済みであり、未処置として送らない。関門外URLの受理、捕捉内部を読む契約の差は保持 |
| U02後・L70前の別作業 | Detail/AtError.save_exact/fromCheck/error_saved、AtErrorReaders、ResultShape.Declared/Program.StandardErrorComplete | J50-1。公開名・全署名・観測・宣言・照合・網羅性を写す。生Valを読むならatErrorの閉性・適格性を再点検 |
| R30/R60 | 同じ内部保存と全失敗、七String観測、D61 | 選ばれた公開構成子・文言・Show。保存値は非切詰め、表示は引用・エスケープ・4096バイト上限。outsideScopeの意味を動的/静的な不所属へ潰さない |
| D10/V10 | O044/O156、Sourceの直接構築の境界、全σの所属と静的被覆 | 00-01/AGENTSの公開要約と実CLIのcheck観測/run固定値の限界、IFC未実装。今回先行改訂しない |

## 設計者の見直しと計画との差

[全一覧](l/review-points.md)にplan/READMEの指定項目と各群の差をまとめ、[出どころ33行](l/review-point-sources.json)を保存した。L20/L30/L40の受け入れ済みの判断は再承認待ちへ戻さない。L50のNamesWF二前提、F06.currentの不要前提除去、Requestの三入口のform除去、D61の内部保存、δのRustとの三差の処置、内部配置・場合数・読者の分類を明記した。J50-1/U02の公開形と、CaptureReadBoundaryの登録判断を残す。今回新しく停止条件に当たる変更の判断は求めていない。

## 定義・言明・仮定の一覧と段末公理監査

"""
    stage += f"既定の{audit['project_modules']}モジュール・{audit['targets']}宣言へ全名で#print axiomsを行い、固定点{audit['closure_rounds']}巡でprivate・生成宣言を含めた。変更{audit['changed_modules']}モジュール（根importを含む）の{audit['changed_module_declarations']}宣言、新設{audit['new_modules']}モジュールの{audit['new_module_declarations']}宣言を区別する。変更分にはprivateの全名{audit['private_changed_declarations']}、個別のソース位置を持たない生成宣言{audit['generated_without_source_line']}を含む（分類は重複する）。\n\n"
    stage += "新規の全宣言と使用定義・言明・仮定の所在は、[監査要約](l/audit-summary.json)が指すdeclarations-partの分割記録にある。各記録に所属モジュール・相対ソース・全名・種類・行番号を保存し、生成宣言の行番号を作らない。変更モジュール全体を収めるため追加宣言を漏らさないが、既存の宣言を新規件数とは呼ばない。標準ライブラリの使用定義への依存も各#print axiomsが再帰的に辿る。旧Releaseの主定理・モデルを含め既定から外したモジュールは0件である。\n\n"
    stage += "| 公理依存の集合 | 宣言数 |\n|---|---:|\n"
    for ax, count in audit["axiom_sets"].items():
        stage += f"| {ax} | {count} |\n"
    stage += "\n新公理・sorryAxは0件である。許可された三公理だけであることと、sorry拒否を別に照合した。全対象一覧は一時領域に置き、台本・件数・SHA-256を残す。\n\n| 出力 | bytes | SHA-256 |\n|---|---:|---|\n"
    for label, info in [("監査生出力", audit["raw"]), ("全名対象一覧", audit["target_list"])]:
        stage += f"| {label} | {info['bytes']} | `{info['sha256']}` |\n"
    stage += """

## 検査と今回の変更

01-12と07-04へ、Sourceによる実行時構成子の直接構築の拒否と、静的判断・全σの意味・固定σの実行の境界を明記した。一般の型付きValを偽造不能とは呼ばず、check/runの環境の一致、実体・副通信の隔離、情報フロー制御を保証しない。曖昧なコメントを実名と内部観測の形へ直した。定義・言明・証明の中身は変更していない。工程ID・手元の絶対パス・新公理・未実装の段名を写しへ追加していない。

| 検査 | 中身・結果 | 記録 |
|---|---|---|
"""
    for label, description in [("build-check", "対象指定なしの既定lake build、1293 jobs"),
        ("audit-full-check", "全環境の公理監査と実署名・定義形の印字"),
        ("conditions-check", "三モデル75欄の全称の契約を単独Leanで再検査"),
        ("dry-run-check", "指定B_WORK・onlyなしのworkの選択確認"),
        ("work-check", "仕様対応表の自己検査/集計、仕様例、既定Leanビルドとsorry拒否")]:
        file = HERE / (label + ".json")
        if file.exists():
            r = json.loads(file.read_text())
            stage += f"| {description} | 終了{r['exit']}、外側{r['seconds']:.6f}秒 | [記録](l/{label}.json) |\n"
        else:
            stage += f"| {description} | 未実施。今回の作業末に一度実行する | 記録の受け口：l/{label}.json |\n"
    stage += "\n公理監査の印字API・未知オプションによる失敗と、署名の証明省略・容量を検出した再集計は[l/results](l/results.md)に残した。本番の不足や公理の発見ではない。最終に保存する宣言・実署名は成功した一回分だけである。\n"
    stage += """
## 見込みと実績

L50全段の枠36.5〜84時間（中心60.25）、60単位の参考積上げ38時間30分〜71時間5分（中心54時間47分30秒）は変更しない。今回の指定は.59を除き1時間55分〜3時間30分、上限7時間である。下表は各resultsにある外側の区間で、能動時間と待ちは未分離である。資料読解を含まない初回の単位区間と、読解を含む再開区間を別に置き、厳密な総能動時間を作らない。取りまとめの独立レビュー・clean再ビルド・正式RSSの時間はこの表へ加算していない。

| 群 | 初回又は本番単位の外側の区間 | 再開・補足 | 出どころ |
|---|---|---|---|
"""
    rows = [
        ("A", "16:02:58〜16:09:48の6分50秒でF04停止", "再開1 8分03秒、再開2 22分40秒、再開3 4分13秒。停止資料・各群末外の厳密な合計は未取得"),
        ("B", "16分54秒", "再開1 4分00秒"),
        ("C", "36分33秒", "再開1 9分13秒。誤起動した既定build2件の全生出力・外側時間は未取得"),
        ("D", "58分35秒", "再開1 10分05秒。単位境界の一部はdate出力から転記"),
        ("E", "38分13秒", "再開1 25分05秒"),
        ("F", "26分00秒", "再開1 15分15秒"),
        ("G", "18分09秒", "取りまとめの写し修正の外側時間は未取得"),
        ("H", "25分19秒", "取りまとめの記録/写し修正の外側時間は未取得"),
        ("I", "19分11秒", "取りまとめのコメント・上限設定・写し修正の外側時間は未取得"),
        ("J", "15分25秒", "取りまとめの例・コメント・写し修正の外側時間は未取得"),
        ("K", "23分33秒", "再開1 16分11秒。取りまとめの注記等の外側時間は未取得")]
    for g, first, resume in rows:
        stage += f"| {g} | {first} | {resume} | [{g.lower()}/results]({g.lower()}/results.md) |\n"
    times = re.findall(r"^\| (L50\.\d+) \| (\d{4}-[^| ]+) \| (\d{4}-[^| ]+) \|",
                       (HERE / "results.md").read_text(), re.M)
    if len(times) == 4:
        seconds = sum(int((datetime.fromisoformat(end) - datetime.fromisoformat(start)).total_seconds())
                      for _, start, end in times)
        stage += f"| L（今回） | {seconds // 60}分{seconds % 60:02}秒 | .56〜.58・.60の四区間。資料読解・検査待ちを含む。能動時間未分離 | [l/results](l/results.md) |\n"
    else:
        stage += "| L（今回） | [単位別の開始・終了](l/results.md)を正とする | 資料読解・検査待ちを含む。能動時間未分離 | [l/results](l/results.md) |\n"
    stage += "\n計画下書きと再開1・2の外側時間は[l50/results](results.md)にある。初回の単位と同じ記録ではないため、実装の一件当たり係数には使わない。取得していないレビュー・回答待ちや能動時間を0として足さない。\n"
    stage += """
## L50.59と最終検査・受け入れの受け口

L50.59は未開始であり、取りまとめが段末独立レビューを依頼した後の別の起動で処置する。本書・全F署名・定義の本体・全名の所在・33義務/31申し送り・75/12欄・13API表・群Kの依存の限定・見直しの一覧をレビューの入力とする。全所見について当たる本番/写し、前提・結論・供給元、処置と古くなった検査/監査を一行ずつ記録する。主な十言明・新公理・独立の信頼条件・書ける形・提供範囲・精密外部状態・型付け規則・U02依存の公開形の選択が必要なら、実装の前に停止する。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 段末独立レビュー | 取りまとめが依頼。定義・言明・仮定、実表と存在、全場合/読者と残る所有を確認 | 不明 |
| L50.59の所見の処置と再確認 | 別の実装起動。変更で古くなった検査・公理監査・実署名だけを更新 | detailの45〜90分。レビュー待ちは不明 |
| 正式な最終workと最大常駐量 | 取りまとめがレビュー処置後の同じ実装状態で一度採る。計測器と本体の終了を分け、機械・OS・原単位・HEAD/差分/入力を記録 | 不明。今回の増分実行を次の計測の初期値とする |
| 段末の照合・受け入れ | 取りまとめが証拠を集約し設計者が受け入れを判定 | 不明 |
| U02の公開形への写し | U02確定後・L70前の別作業。選んだ形の前提と全読者を確認 | 比較材料の仮見込みを短い代表一件で見直す。全体は不明 |
| L60/L70/R段 | 各既存計画の外部/解放・主定理/表層/全比較・固定σ/推論/実CLI | 各計画。待ちは不明 |

正式な最終work/RSSの記録欄は、対象HEAD/未コミット差分、入力/生成物/設定/道具/構成、コマンド、件数、終了、外側時間、最大常駐量・原単位、計測器の終了、関係状態一致の根拠、判断者/日付とする。現時点は未取得・未受け入れである。今回の既定build・公理監査・作業末workの成功を、Rust/Leanの全比較・主定理全体の閉鎖・実行時隔離・段末受け入れの証拠としない。
"""
    assert len(stage.encode()) <= 100000, len(stage.encode())
    (STAGE / "stage-results.md").write_text(stage)
    print(json.dumps({"stage_results": digest(STAGE / "stage-results.md"), "obligations": 33,
                      "handoffs": 31, "conditions": 75, "l60": 12, "families": len(families)}))


if __name__ == "__main__":
    main()

# L00a.06b: 新判断の並置と旧導出の埋め込み

2026-10-30。実装担当 Codex による結果である。[契約](../l00a.06a/contracts.md)に従い、本番の `Benitoite.Release.Refinement` に最小の新判断を並置した。既存の判断・主定理は残し、集約モジュールだけに新しい import を追加した。独立レビューと受け入れは取りまとめ・設計者の担当であり、本書の自己点検とは区別する。

## 基準と範囲

| 項目 | 内容 |
|---|---|
| 指定ブランチ | `m014/l00a.06b`。切り替え・作成・コミットなし |
| B_WORK | `74bdfcdd0f8e0a2b1d1944955d072511542e97d5`。起動依頼の指定値 |
| 読取り直後の時計 | 2026-10-30 20:51:48（+0900） |
| 条件 | 共通依頼文、plan の L00a.06b、decisions/README の承認済み判断、修正後の contracts、RV-L00a.06a、.06a の申し送り |
| 変数と論理 | Nat の de Bruijn と WF、有限の Γ/facts/Φ、構文による Entails。意味の所属を新しい外部前提にしていない |
| 変更 | `formal/Benitoite/Release/Refinement/` の9モジュール、`formal/Benitoite.lean` の import、本ディレクトリの記録 |
| 処理系・現行設計書 | `crates/`・`docs/design/` の編集なし |
| Git | 担当による git コマンドなし。検査入口による基準・差分の読取りだけを使用 |
| メモリ | lakefile の `-M 12288` を使用。最大常駐量は **未取得（計画上の非採取）** |

## 定義と閉じた補題

| モジュール | 置いた定義・証明 |
|---|---|
| `Types.lean` | Term/Pred、新 Ty の16構成子（旧15構成子と refined）、新型の Fail を持つ EffR、NamesWF、embedTy/embedTys/embedEff と型列の写し |
| `Order.lean` | 順位0〜14を保ち refined を15とする木の辞書式順序。述語も有限構文として比較。`tyCompare_eq_iff`、`tyCompare_total`、`tyCompare_lt_trans`、`tyCompare_antisymm`、LawfulEqCmp/TransCmp、`tyCompare_embed`、`embedTy_injective`。木・項・述語の写しと単射性は非公開の補助 |
| `Normalize.lean` | Ty.norm/normTys、Eff.norm、各 Canonical、memFail、empty/singleFail/union。`Ty.normTys_eq_map`、`Ty.norm_idem`、`Ty.normTys_idem`、`Eff.norm_idem`、`Eff.norm_memFail`、`embedTy_norm`、`embedEff_norm`、`embed_memFail`、`embed_canonical`。型列の正規化の交換は非公開の相互補題 |
| `Context.lean` | Ctx/facts、Ty.assume、Pred.lift/open/WF/Sorted、Ty.IntegerCarrier/WF/WFList/Sorted、Eff.WF、値参照の shiftV と Ctx.extend/extendNone。`embed_wf` と、列・行の WF を移す非公開の相互補題。SubstEnv の四欄、Ty/Eff.rawBind と rawBind 後の norm を含む bind |
| `Logic.lean` | 契約の全17構成子の Entails、`Entails.weaken` と `Entails.cut`。Or の両分岐と Not の仮定追加の場合も証明 |
| `Le.lean` | 契約の全9構成子の Ty.LeQ、Eff.Sub/Covers、`Ty.LeQ.assume`、`embedCovers`、`embedLe` |
| `Syntax.lean` | 新しい宣言・Program・PrimSig・Builtins・LocTy/StoreTy/LocalCtx、全 Val/Comp/Arm/Clause。Const/BuilderOp は共有する型の略記。Const.type は embedTy と旧 type の合成。ConstOK と Val.toTerm? |
| `Subst.lean` | 新構文の値の rename/subst と型・行の substTyAt、Comp/Arm/Clause と列の相互再帰。ラムダ・let・腕・節の束縛の下へ入る際は像の外側の値参照を移す。型・行の有限列の特殊化に使う補助は非公開 |
| `Typing.lean` | V_Var/V_Const/V_Lam/V_List/V_Sub/V_Refine、Vs と Each の nil/cons、C_Return/C_Let/C_App/C_Sub/C_Eff。Γ/Φ と新 LeQ/Covers を使い、WF と sort、束縛に応じた移動を置く。空 Q の各入口も新判断の略記 |

`embedLe` は旧 Le の等号と最外関数の効果拡大の二枝を消去して証明した。`embedCovers` は原子の証人を保持する。Fail は新側の任意の問い合わせ型から内側の旧要素の証人を取り出し、旧被覆の証人と正規化の交換を合成する。問い合わせ型を旧埋め込みの像へ制限していない。両補題は任意の Γ/Φ を取り、ConstOK、旧入力の新しい WF/Canonical/有限支持等を追加前提にしていない。

`Ty.LeQ.assume` は全9構成子を扱う。trans では中間型の assume を帰納仮定で導き、共通の facts/Φ とともに cut する。refine は元の述語を仮定した導出と、carrier どうしの帰納仮定の弱化を使う。

ConstOK は、整数の各幅、Byte の255以下、Decimal の仮数の絶対値が2^96−1以下・scaleが28以下を検査する。Integer64Value の境界は共有する payload の証拠による。標準対象の裸 opaque は valKind/valContent で区分し、通常資源の枝を残す。Decimal の数値は現行の `src/base/decimal.rs` と設計書 01-04 の範囲を照合した。新しい数値の幅を選んだものではない。

## 検査

途中は関係する新モジュールだけを `rtk proxy lake build Benitoite.Release.Refinement.<対象>`（formal/ 内）で検査した。対象は Normalize、Context、Logic、Le、Syntax、Subst、Typing である。lake の単一ファイル実行にも lakefile の `-M 12288` が付く。既定ターゲット全件のビルドは作業末の work に一度集約する。ただし work の `lake build` は増分である。新しい9モジュールは直前の局所ビルド（olean の時刻は work の開始の直前）で作成済みで、work では既存の成果物を再利用したため約1秒だった。新しいモジュールの全件の再検査はこの時間に含まない（取りまとめが [RV-L00a.06b](../reviews/RV-L00a.06b.md) の中1に従って追記した）。

途中に次の失敗と修正があった。Pred.Sorted の再帰引数を直接のパターンマッチへ直した。embedCovers の原子の所属では Eff を場合分けして写しの定義を展開し、Fail のリスト所属の型を明示した。Subst の生成時に区切りの検索と末尾のコメントを直した。自己点検では if の第二枝に束縛の移動を誤って付けた箇所を除き、旧構文から写した保持要求の古いコメントを改めた。最終の局所 Typing ビルドは成功した。これらを検査未実施のまま後段へ送っていない。

最終の検査結果と外側の時間は、本書の末尾と [checks.json](checks.json)・[work.log](work.log) に記す。

## 契約との差と申し送り

契約の公開する型・欄・規則、LeQ/Entails/埋め込み/assume の前提・結論を変更していない。新公理・sorry・admit を置かず、旧 Le の lift 構成子や最外の篩だけのアダプタを使っていない。ファイルの細分は契約で認めた実装上の選択である。比較の本体は既存の木の順序を直接使い、同じ比較順を返すことを旧比較との等式で証明した。

L00a.07a には、旧判断の使用箇所と今回追加した新判断の使用箇所を区別して棚卸しすることを渡す。今回の embedLe/embedCovers は旧の型/行の導出だけの片方向の補題であり、全値・計算・状態・表層・組込みの埋め込みの完了に数えない。予約名の腕/通常節/Fail節・状態・保存等は空の判断で定義していない。旧 Release から新モジュールへの import はなく、集約の Benitoite.lean からのみ追加している。

.08〜.10 は今回の shiftV/rawBind/bind と有限構文を使って、移動・一般置換・被覆の保存を証明する。Γの参照順序の保存、facts の extend の式、型付きの像から facts と整数観測を導くこと、narrowing と四判断の相互置換は .12a/.12b の担当である。Entails の一般の rename/bind はそれぞれの後段で証明する。閉じた評価器と ground は L00b.04、篩の平坦化と true 消去は L00b.11 に残る。

## 義務の段別判定

| 義務 | 今回の判定と証拠 | 残る段 |
|---|---|---|
| L00a.06b | 並置定義・交換・旧導出の埋め込み・assume/cut を実装。検査の最終結果は末尾 | 取りまとめの独立レビューと受け入れ |
| O042 | .06b の並置と埋め込みの分。証拠は新9モジュール、既定import、work の結果 | L10/L20 の追随、L70 の切替 |
| O159 | .06b の作成表で指定した判断と空Q入口を定義。予約行を完成と数えない | L00b/L10 の全構成子、L70 の読者と旧判断の処置 |
| O002/O004/O029/O031 | 定義と embed_wf、有限論理の cut まで。一般の保存を閉じたと数えない | .08〜.12b、L00b、L20 |
| O003/O010 | 今回の新補題の実装を記録。棚卸しの件数・中心の補題全体の実績は未集計 | .07a〜.07b、.16a〜.16b |

## 最終の検査結果と所要

work は次の指定で一度だけ実行した。先に同じ指定の dry-run を取り、その選択を読んでから本実行した。[実行台本](run-checks.py)は二つを別の呼出しとして記録し、同じ種類の検査の再実行を拒否する。Lean の既定ターゲットは Benitoite、desugarDiff、builtinCheck、coverageDiff、coverageProgramDiff、surfaceCheck、surfaceCheckAll、intervalDiff の全件である。

```sh
rtk proxy scripts/check.sh --level work --base 74bdfcdd0f8e0a2b1d1944955d072511542e97d5 --dry-run
rtk proxy scripts/check.sh --level work --base 74bdfcdd0f8e0a2b1d1944955d072511542e97d5
```

実際の起動は、リポジトリの根で `rtk proxy python3 <本ディレクトリ>/run-checks.py dry-run` と、選択を確認した後の同じ台本の `work` 引数で行った。台本は上記の引数を subprocess.run に配列で渡しており、記録中の単調時計の差を各コマンドの外側の時間としている。

| 検査 | 終了 | 外側の時間 | 対象・結果・証拠 |
|---|---:|---:|---|
| dry-run | 0 | 0.110821750秒 | 15変更ファイル。formal_buildだけを選択（既定lake buildとsorry拒否）。[ログ](dry-run.log) |
| work | 0 | 1.030493750秒 | 17変更ファイル。formal_buildだけを実行し、selected checks passed。既定ビルド成功、sorryによる拒否なし。[ログ](work.log) |
| 新21補題の局所公理依存・署名確認 | 0 | 0.315479875秒 | [入力](proof-audit.lean)、[ログ](proof-audit.log)、[コマンドと時間](proof-audit.json)。許可された三公理の範囲だけ |

dry-run と work の変更ファイル数の差は、dry-run のログと記録の追加による。対象の formal の内容や lakefile は変えていない。work の後に増やしたのも本ディレクトリの結果・照合記録だけであり、[入力のハッシュ](source-audit.json)を追記時に再照合した。

局所の公理依存の確認は formal/ 内で `rtk proxy lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00a.06b/proof-audit.lean` を実行した。21補題の依存は propext・Classical.choice・Quot.sound の部分集合であり、sorryAx・独自公理はない。これは新しい葉の局所確認であり、L00a末の既存主定理も含む A-L や独立レビューの代替とはしない。

[ソースの照合記録](source-audit.json)には、新9モジュールと集約モジュール・toolchain・lakefile・契約の SHA-256、構成子名、宣言の欄の名前を保存した。旧の [L00a.01b の一覧](../l00a.01b/inventory.json.gz)が持つ formal/ と check.sh の402入力を現物と比較したところ、401件は一致し、集約の Benitoite.lean だけが新 import の一行を追加していた。追加部分を除いた内容も旧ハッシュと一致した。旧判断・主定理のソースを改変していない根拠として使い、今回の B_WORK と旧一覧の基準IDを同一とは扱わない。新ディレクトリ以外で Refinement を import するのは集約モジュールだけである。

同じ自己点検で、旧 Ty の15構成子に refined を加えた16構成子、Valの17・Compの13・Armの1・Clauseの2構成子と、Def/ConDecl/OpDecl/MethSig/ClassDecl/ImplDecl/Program/PrimSig/Builtins の全欄の名前が旧表現と対応することを確認した。ソース上にも独自 axiom/sorry/admit の宣言はない。これは入力の構造の自己点検であり、実行される全遷移や全型付けの埋め込みを検証したとはしない。

最初の読取り直後の時計は20:51:48、最終のソース照合は21:05:25（+0900）であり、この区間の外側の時間は **13分37秒** だった。正規化・埋め込みの交換と embedLe の二枝の証明はこの区間内に閉じ、最初の1時間の確認条件を満たした。その後の本節の追記と最後の応答はこの区間に含めない。能動時間と、読取り・編集・局所ビルドの待ちを全区間について分離した記録はなく、13分37秒を能動時間とは扱わない。最大常駐量は **未取得（計画上の非採取）** であり、RSS用の追加ビルドはしていない。

作業末の work は成功し、L00a.06b の担当する定義と補題の実装を完了した。契約・主定理の前提/結論・提供範囲の変更を要する停止条件、時間超過による停止条件は発生していない。検査入力を変える修正と未完の証明を残して完了扱いにした箇所はない。取りまとめによる独立レビューと設計者の受け入れは未実施である。

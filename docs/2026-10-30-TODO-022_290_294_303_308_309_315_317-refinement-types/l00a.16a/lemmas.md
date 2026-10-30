# L00a の中心の補題と後続段への義務

2026-10-31。基準は `9863c0141511dc225aff9ec787a4b733d65a9431`、指定ブランチは `m014/l00a.16` である。現在の最小構文に対する完成を整理した。全構成子・全状態・新しい主定理への一般化の完成は含めない。

## 完成した補題と利用先

下表の新しい名前の接頭辞は `Benitoite.Release.Refinement.` である。完全名は [A-L の対象一覧](targets.txt)、現在の公理依存は [生出力](axioms.log)と[集計](axioms-summary.json)にある。署名・前提・結論は本番ソースと各作業の監査ログを正とする。

| 完成した本番の補題・定義 | 確認した範囲と使用条件 | 次の利用先 | 元記録 |
|---|---|---|---|
| `embedLe`、`embedCovers` | 旧 Le の二枝と被覆を構文の新導出へ写す。任意の Γ/Φ。旧入力へ新しい WF 等を足さない | L00b/L10 の埋め込み追加、L20 の全導出、L70 の旧体系の処置 | [.06b](../l00a.06b/results.md) |
| `embedTy_norm`、`embedEff_norm`、`embed_memFail`、`embed_canonical`、`embed_wf`、`tyCompare_embed`、`embedTy_injective` | 旧正規化・比較・WF との交換。新 WF の芯の条件にも追随済み | L00b.11/L10 の正規化と適格な旧導出、L40 の不変位置 | [.06b](../l00a.06b/results.md)、[.12 最終](../l00a.12/results.md#二度目の停止への対応) |
| `Entails.weaken`、`Entails.cut`、`Entails.bind`、`Entails.shiftV` | 有限な構文の含意。Or/Not の仮定追加を含む | L00b.04 の ground 追加、L20 の文脈保存、L30/L40 の論理の葉 | [.06b](../l00a.06b/results.md)、[.08](../l00a.08/results.md) |
| `Ty.LeQ.assume`、`Ty.assume_bind`、`Transport.assumptions` | 型像で増える事実は包含と cut で扱う。事実の列の等号を要求しない | L20 の文脈/置換、L40 の篩 canonical forms | [.06b](../l00a.06b/results.md)、[.08](../l00a.08/results.md) |
| `Ty.shiftV_eq_renameTy`、`Ty.norm_shiftV`、`Ty.wf_shiftV` と型列/行の版、`Ctx.facts_shiftV`、`Ty.LeQ.shiftV`、`Eff.Covers.shiftV` | self/外側の値、開いた Γ/Φ/None、Nat/cutoff。WF を保つのは順序を保つ移動 | L00b/L10 の追加構成子、L20 の改名と束縛。任意の並べ替えへは一般化しない | [.08](../l00a.08/results.md) |
| `Ty.LeQ.bind` / `rawBind` / `substAt` / `subst` / `shift`、`Ty.norm_rawBind` と行の版 | LeQ の全9規則の帰納法。篩と外側値依存を含む型/行像。`Transport` の整数観測と facts の証拠を用いる | L00b/L10 の構成子追加、L20 の型/行置換、L40 の型規則 | [.08 の .09a](../l00a.08/results.md#l00a09a-型行の-substatsubst) |
| `Transport.extend` / `up` / `up_raw` / `extendNone`、`Ty.bind_up`、`Eff.bind_up` | 型付き束縛/値なし束縛の下へ移す。None の0番を値として読まない | L00b.03、L20 の依存列・束縛・節への拡張 | [.08](../l00a.08/results.md) |
| 型/行の `bind_substV` / `substAt_substV` / `bind_mapRanges` / `substAt_mapRanges` / `mapRanges_substV`、LeQ/Covers の `substV` / `substVAt` / `mapRanges` / `substRAt` / `instR` / `shiftR` | 開いた値/範囲像、像へ再適用しない。同時置換の交換には記録された `θ.values = Term.var` 等の条件がある | L20 の四名前空間の置換・交換、L50 の具体化。任意の四名前空間同士の合成の完成は主張しない | [.08 の .09b](../l00a.08/results.md#l00a09b-範囲値の置換と交換) |
| `Eff.Covers.bind` と各置換/移動の系、`Eff.Sub.covers`、`cannot_split_one_atom`、`covers_not_sub` | 一原子ごとの証人、行像の複数原子、範囲、正規化した Fail を保持。構造上の包含と被覆を区別 | L20 の型付け/継続、L50 の対象条件、L70 の効果/対象健全性 | [.08 の .10](../l00a.08/results.md#l00a10-一原子の被覆) |
| `Ty.canonical_of_wf`、`Ty.wf_bind_values` / `sorted_bind_values` と行の版、`Ty.rawSubstV_of_wf_zero` / `subst_values_of_wf_zero` と行の版 | 値だけの置換の WF/sort、値非依存の注釈の不変。最上位の Eff.WF は Canonical を含意せず、必要箇所は別に要求 | L10 の一般の像の WF/sort、L20 の項・R・ストア・後続文脈の置換 | [.12 最終](../l00a.12/results.md#二度目の停止への対応) |
| `HasTypeVQ.integer_observation` / `toTerm_of_integerCarrier` / `assume`、`SubstOk.transport` / `observation`、`Pred.bind_congr_sorted` | 型付き像から facts と整数観測を導く。整数を読まない位置の既定値へ意味の仮定を足さない。相互置換に先行し循環しない | L00b/L10 の全sort、L20 の全相互置換、L40 の事実の抽出 | [.12](../l00a.12/results.md) |
| `HasTypeVQ.subst`、`HasTypeVsQ.subst`、`HasTypeEachQ.subst`、`HasTypeCQ.subst` | 現在の全四判断の相互置換。V_Sub/C_Sub/C_Eff、V_Lam/C_Let、任意の Γ/Φ。Φ の像の導出は別に受け取る。注釈・結果型・行・R は bind を使う | L20 の腕/節/継続/全状態、L40 の δ/return の葉、L70 の保存 | [.12 最終](../l00a.12/results.md#二度目の停止への対応) |
| `Ctx.Narrows`、四判断の `.narrow`、`Ty.LeQ.notContCore`、`Ty.notContCore_of_wf_ordinary` | 外側の LeQ と元の型の WF/sort から構成し、後続の値/None を保つ。narrowing を Transport の仮定にしない。V_Var の規則は変更していない | L20 の全文脈、L40 の逆転/篩。LeQ 拡張時も必要な芯の性質を保つ | [.12 最終](../l00a.12/results.md#二度目の停止への対応)、[RV-.12](../reviews/RV-L00a.12.md) |
| `SubstOk.transport_extendNone`、四判断の `.subst_under_none` | 親の型付き像と Φ の移送から `Transport.extendNone` を実際に使う入口 | L00b.03/L20 の値なし束縛と全判断 | [.12 最終](../l00a.12/results.md#二度目の停止への対応) |
| `OpenSubstitution.introduce_bind` / `introduce_bind_shape` / `introduce_bind_under_none`、`RawValueSubstCollision.substituted_lambda_typed` / `substituted_return_typed`、`NarrowingExample.narrowed_value` / `narrowed_comp` / `narrowed_under_none` | 空でない facts、篩付きで外側値に依存する像、V_Sub/C_Sub、None を使う実際の導出。rawBind の負の例と正規化後の正の例を区別 | 後続の構成子追加時の接続確認。代表だけで一般定理の完成を代用しない | [.08 のレビュー対応](../l00a.08/results.md#rv-l00a08-への対応)、[.12 最終](../l00a.12/results.md#二度目の停止への対応) |

## 申し送りの統合表

後の作業へ送る義務を、解消済みのものと分けた。同じ義務を複数の見込みへ加算しない。下表の担当は後続段の実装担当、定義・署名の確定とレビュー手配は取りまとめである。

| 出どころ・所見/義務 | 現在の処置 | 残る内容・担当する段 | 見込みへの扱い |
|---|---|---|---|
| [.01a](../l00a.01a/results.md)・[.01b](../l00a.01b/results.md)、O045/O055 | 現行ソースと clean 成果物を開始時に照合済み。以後は増分。.16の取りまとめworkは選択なしで終了0 | L00a末のRSSは理由付き未取得。L00aのRSS証拠は.01aのclean W-L0だけ。次はL00b末に採取 | 計測用buildを追加せず、過去P3/P4の未取得も成功へ変更しない |
| [RV-.06a](../reviews/RV-L00a.06a.md) 重1/中3、O159 | 最小構文と予約名の表、完全名と作成担当を契約へ記録 | L00b.02a/.02b/L10 の全構成子、L70 の全読者と旧体系の処置 | 骨格と各段の内数 |
| RV-.06a 重2・軽4、.06b の正規化 | 旧正規化の拡張と埋め込みとの交換は完成 | L00b.11 の平坦化/true消去/正規化後等号、追加場合への追随 | L00b/L10、L20/L40 の内数 |
| RV-.06a 中2/中5、.06b の facts/整数観測/narrowing | .12 最終で最小四判断について完成 | 全sort、依存 Tel、全 canonical forms と状態は L00b/L10/L20/L40 | 完成部分を再加算せず、一般化枠を保つ |
| RV-.06b 軽1/軽2 | .08 で必要補助30名を公開し、shiftV と renameTy の等式を証明。.12 でさらに必要補助6名を公開 | 今回の補題の使用時は公開名を使う | 解消済み。新しい未完として計上しない |
| RV-.06b 軽3/軽6 | .08 で変更した既存4モジュールへ説明を追加 | 残るモジュールの未使用 private/冒頭説明は次に触る担当が確認 | 該当作業の保守の内数。新しい証明群にしない |
| RV-.06b 軽4、二度目の契約改訂 | refined の WF に NotContCore を追加し、.12 の narrowing は完成。元の送り先L00b.02aの芯での判定の分はこの改訂で解消済み | L10/L20 の型像へ継続型を含めない前提、L20 の文脈WF、L40 の芯の性質、L70の規範切替で01-12へ反映 | L10/L20/L40/L70 の内数、未検証の一般化を残す |
| RV-.06b 軽5、[RV-.08](../reviews/RV-L00a.08.md) 軽4 | `rawApply_refined` で引数を捨てる現動作を言明済み | L00b.02a の kind と .11 の型構成子像の適用を照合。base 等でも引数が落ちる点を含む | L00b/L10 の内数。正しい将来契約と認定しない |
| RV-.08 中1/軽1/軽2 | facts を実際に使う篩導入の代表、O031/O040 の行、extendNone を追加済み | .12 の専用入口も完成。全構成子への拡張は後段 | 現最小構文の修正は解消済み |
| RV-.08 軽3 | .12 で値だけの bind の WF/sort を完成 | 一般の型/行 `wf_bind` / `sorted_bind` は L10、全判断への追随は L20 | 値だけの実績から一般の完成へ繰り上げない |
| RV-.08 軽5/軽6/軽7 | rangeAt の列の外の番号を詰めない規約は説明済み | 像上の分割拒否の代表は任意。`assumptions` の同名は名前空間で区別 | 任意の例を必須義務へ増やさない |
| .08〜.10 の交換 | 指定された正規化との交換は完成 | 四名前空間の任意の同時置換同士の一般合成は未完。必要な型/行/範囲/値の全交換を L20 で具体化 | L20 の type_subst 枠。完成した条件付き交換と区別 |
| [.07a](../l00a.07a/results.md)・[.07b](../l00a.07b/results.md)、O003 | 962候補、最小版対応済み7、旧候補の未処理955を分類済み | L10=151、L20=394、L40=82、L50=36、L70=292。新規L30/L60等の義務は件数外 | 本番追随の旧見込みを保持。962件を所要単価へ変換しない |
| [RV-.12-stop](../reviews/RV-L00a.12-stop.md)、第一の契約改訂 | 項の注釈の値置換と substKind を bind に修正。.08 の「生の一般WF保存」は撤回。負の例は rawBind 明示へ変更 | L20：並べ替え/縮約には正規化する改名、ストア/継続/R/後続文脈の値置換も bind。L50：項への範囲具体化も bind | L20/L50 の内数。生のWF保存を将来義務に残さない |
| .12 二度目の停止、RV-.12-stop の候補比較 | WF の芯の除外で解消。narrowing への Ordinary の前提追加と V_Var 変更は採らなかった | 利用者が書く型に継続型はなく、D02/D03 の篩対象も狭めない。将来もこの境界を照合 | 提供範囲/主定理を変えず、一般化の不確かさを保持 |
| [RV-.12](../reviews/RV-L00a.12.md) 中1 | 最小構文には継続束縛の判断がなく、今回の subst は成立 | L20/L40：節の `k : Cont` の下で `SubstOk.up` を構成。改名の枝の追加か内部不変条件の公開を、詳細化とレビューで確定 | 束縛/全相互置換は L20、規則/逆転への接続は L40。同じ証明を二重計上しない |
| RV-.12 中2 | 型置換の一般WF保存は未言明なので、今回壊れた補題はない | L10/L20：「型の像に継続型を含まない」を明記してWF保存を言明。01-12の型引数の規約と一致させる | L10 の像のWF条件、L20 の使用・保存の内数 |
| RV-.12 軽3 | 現在の `LeQ.notContCore` は iff | L40 で LeQ を拡張しても、narrowing に要る「b の芯が cont でなければ a の芯も cont でない」を保つ | L40 の構造別逆転/型規則の内数 |
| RV-.12 軽5 | WF の除外で narrowing は成立。WFでないΓの変数導出は構成できる | L20 で文脈WFを不変条件とする。L70の規範切替で01-12のWFに芯の条件を記す。D10はその反映済み規範との文書照合 | L20 の文脈/状態、L70の規範反映、D10の照合の内数 |
| RV-.12 軽6、RV-.16 中3/軽3 | .12の最後のLean workはsandbox内でRSS未採取。.16の取りまとめworkはsandbox外・選択なしで終了0 | L00a末の限定RSSは未取得と確定。計測用buildは追加しない。次の採取はL00b末。以後、段の最後のLean workを取りまとめがsandbox外で実行するよう起動依頼に固定 | .16のcheck.sh自身の14,761,984バイトをLeanのRSSとしない。今回Leanを直す場合に限りその最後のworkへ差し替える |
| RV-.12 軽2 | 理由の docstring は今回変更しない | 次に Subst.lean を触る担当：値置換は正規化、改名は生のままとする理由を記す | その作業の内数 |
| RV-.12 軽1/軽4/軽7 | ¬Ctx.Narrows の直接例と refine の追加代表は任意。O006 の一般の型/行像の保存は .08 が根拠 | 必須の新規作業にしない。.12 の古い未完表は履歴、最終節を現状態として読む | 見込みを追加しない |
| O007/O008/O030/O032/O039/O046/O047/O051/O052 | 最小補題は利用できるが、全canonical/ground/状態の完成は未主張 | L00b.03/.04/.11/.13/.14、L20 の全Store/閉包/Cont、L40 の全逆転/値所属 | 状態代表と一般化、canonical/ground と文脈保存を分け、元行2/4の内数を保存 |
| RV-.16 軽1、O016の次のA-L | 今回694対象にはモデルの仮定充足と旧前提との同値の一部を含めていない。既存Releaseは未変更 | L00b末から `Benitoite.Release.Model.assumptions`、`Benitoite.Release.ModelTargets.assumptions`、`Benitoite.Release.ModelHttp.assumptions`、`Benitoite.Release.Ty.le_iff_leOld`、`Benitoite.Release.Ty.wf_iff_old`、`Benitoite.Release.Ty.varsIn_iff_old`、`Benitoite.Release.Eff.covers_iff_sub_old` 等を追加。取りまとめが07-04の前提変更/限定同値の一覧と照合して固定する | 既存の次回A-Lの内数。今回の入力へ後から追加して694対象の実行済み記録を変えない |
| O016/O010/O040/O075/O089 | A-L を本単位で実行。.16のworkは取りまとめが実施済み、末尾RSSは理由付き未取得。時間と見込みは [.16b](../l00a.16b/estimate.md) | RV-.16への応答の再確認と設計者の見込みの読み方/案の了承。O016の後続全L/L70、O159の切替は残る | 時間と待ちの分離不能と区間内の上限をともに示す。修正版の独立レビューの完了は主張しない |

旧 Release の主定理を検査したことは、新しい型付けに対する進行・保存・対象健全性の完成を意味しない。L70 は L20〜L60 の葉、表層と交換、旧体系の処置を合成して閉じる担当を維持する。

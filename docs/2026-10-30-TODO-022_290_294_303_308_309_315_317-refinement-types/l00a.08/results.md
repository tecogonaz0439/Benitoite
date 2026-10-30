# L00a.08〜.10: 移動・置換・一原子の被覆

2026-10-30。指定ブランチは `m014/l00a.08`、B_WORK は `22aaeb3cb1faf65264abad20cab8eb99ec3fcc81` である。担当による git コマンドの実行・状態を変える操作は行っていない。指定された検査入口による基準と差分の読取りだけを用いる。処理系・現行設計書・契約・計画・docs/todo を変更していない。

## 契約と作業の境界

[契約](../l00a.06a/contracts.md)、[L00a.06b の結果](../l00a.06b/results.md)、[レビュー](../reviews/RV-L00a.06b.md)、[分類と申し送り](../l00a.07b/inventory.md)に従う。初めに共通依頼文と非公開の運用の補足を読んだ。日本語の記録は japanese-tech-writing に従う。サブエージェントと独立レビューは起動していない。

既存の型・欄・シグネチャ・構成子を変更せず、本番の Refinement へ13モジュールを追加した。既存の4モジュールは補助名の公開と冒頭の説明だけを変更した。既定の集約へ `Benitoite.Release.Refinement.OpenSubstitution` の import を追加し、13モジュールをすべて既定 import の推移的な依存に含めた。旧判断・既存の主定理を残した。

実装前には、本書に `Entails.bind`、`Ty.LeQ.bind`、shiftV と renameTy の等号、`Eff.Covers.bind` の目標署名を記した。最終の公開署名は、各単位の `proof-audit-*.lean` の `#check` とそのログに全文を保存した。完全名の機械可読な一覧は [public-names.json](public-names.json) にある。型・整数ID・誤りの構文は追加・変更していない。番号と cutoff は Nat、WF は既存の `Ty.WF nr nt nv` のままである。範囲は既存の `Scope.Signature.Ix` / `Scope.Domain.Range` を使う。

`Transport θ Γ Φ Δ Ψ` は、この最小 LeQ が実際に使う二つの証拠を持つ Prop の構造である。一つは、Γで整数を観測できる位置の像がΔでも整数項であること。もう一つは、Γ.facts と Φ の各置換像を Δ.facts と Ψ から Entails で導けることである。意味上の型の所属、任意の論理の公理、置換後の LeQ/Covers を欄にしていない。任意のΦの保存を型付き像だけから仮定していない。値の像からこの条件を導くのは .12a/.12b の担当である。全入力に対する WF/sort の保存を Transport 自体の結論としては主張しない。

最大常駐量は、すべて **未取得（計画上の非採取）**。一ファイルの検査は `lake env lean -M 12288`、lake のビルドは lakefile の `moreLeanArgs = ["-M", "12288"]` を用いた。上限・heartbeat・警告の抑制・公理の追加をしていない。

## L00a.08: 移動

閉じた補題は次である。型の全16構成子、型列、Fail の内部まで相互帰納する。Γ/Φを空にしたり None を除去したりする前提はない。

| 内容 | 本番の補題と定義 |
|---|---|
| 論理の全17規則の置換・移動 | `Entails.bind` / `shiftV`。Or の二つの仮定追加、Not の仮定追加を含む |
| self と外側の値 | `upValues_comp`、`upValues_shiftIndex`、`predBind_lift`、`predBind_open` |
| 二つの改名の接続（レビュー軽2） | `Ty.shiftV_eq_renameTy`、`Ty.shiftVTys_eq_rename`、`Eff.shiftV_eq_renameEff` |
| 比較・正規形・WF | `Ty.shiftV_compare`、型/列/行の `norm_shiftV` と `wf_shiftV`。Fail の整列も移動と交換する |
| 開いたΓ/Φ・None・sort・facts | `Ctx.shiftV` / `lookup_shiftV` / `mem_facts` / `facts_shiftV`、`Transport.shiftV`、`Ty.LeQ.shiftV`、`Eff.Covers.shiftV`、`Pred.sorted_shiftV`、型/列/行の sort 保存 |
| 束縛を加えた事実 | `Pred.open_shiftV_self` / `outer`、`Ctx.mem_facts_extend`。束縛した値の事実と、外側から lift した事実を分ける |
| 型変数の Nat/cutoff | `Ty.LeQ.shift`、`Eff.Covers.shift`、`Ty.wf_shift`、`Eff.wf_shift`。TypeSubst モジュール内に置いた |

閉じなかった L00a の最小構文に対する移動の言明はない。範囲変数の移動も .09b の `shiftR` / `mapRanges` に接続した。TelLe は契約どおり未定義であり、空の判断や仮の規則を作って対象に数えていない。依存する列と全sortを追加する場合の移動は L00b/L10、その後の全判断の追随は L20 の担当である。

最初の時計の取得は21:39:17（+0900）であった。22:07:25の時計の取得より前に、開いたΓ/ΦとNoneの下の LeQ.shiftV、Covers.shiftV、WF/sort/facts、二つの改名の接続が局所Lean検査で通っていた。したがって「最初の1時間に、本番の表現で .08 の言明の形を確かめる」条件を満たした。単位だけの実装時間は分離不能であり、四単位の共通区間を本単位の能動時間として計上しない。

コマンド・終了・外側の時間: 最終の局所署名/公理検査は [proof-audit-08.lean](proof-audit-08.lean)、[proof-08.log](proof-08.log)、[checks.json](checks.json) の `proof-08` に記録した。終了0、83宣言、外側0.334877500秒。これは最終の局所検査の時間であり、実装の所要時間ではない。

## L00a.09a: 型・行の substAt/subst

`Ty.LeQ.bind` と `rawBind` は9構成子すべてに帰納し、新しい Ty.LeQ の導出を返す。型像が篩を持つ場合にも旧Tyへ戻らない。`Ty.assume_bind` は元の事実の像が新しい型の事実に含まれることだけを使い、型像で増える事実との等号を要求しない。篩導入・篩同士の比較では Entails.bind と cut を用いる。

| 内容 | 本番の補題と定義 |
|---|---|
| 正規化との交換 | 型/型列/行の `norm_rawBind`、`Ty.rawBind_norm_congr`、`rawApply_norm`。構成子位置の像も任意のTyのまま扱う |
| 型・行の有限列 | `Ty.substAt` / `subst`、`Eff.substAt` / `subst`、各 LeQ/Covers の保存。既存の `typeEnvAt` / `substTypeAt` / `substRowAt` の特殊化である |
| Γの None と増えた事実 | `Ctx.bindTypes`、`Ctx.facts_bindTypes`、`Transport.types`。値を恒等に保つ型・行・範囲の置換について、移送条件を導く |
| 依存する束縛の下のup | `SubstEnv.up`、型/列/行の `rawBind_up`、型/行の `bind_up`、`typeEnvAt_up`、型/行の `substAt_up` |
| 束縛したΓ/facts/Φ | `Transport.extend` / `up` / `up_raw`。正規化後の型と生の型注釈の両方へ接続する |

**残した命題と理由（レビュー軽5）**: `rawApply (.refined a p) args = .refined a p` は、現行の定義で引数を捨てる。この挙動を `rawApply_refined` として証明し、無断で変更していない。型構成子の位置に篩を許す条件と、その適用で型引数を保持する規則は **L00b.11** の担当へ送る。今回の LeQ.bind / norm_rawBind / substAt の証明から、篩付きの型構成子像を除外していない。現在の関数の導出の保存を閉じたのであり、その関数が将来の kind の契約に適合すると認定したものではない。

LeQ/Coversの導出を保存する、指定された最小構文の型・行置換とupには未証明枝はない。型付きの値の像から facts を得る仕事と V_Sub の枝は .12a、C_Sub を含む四判断の相互置換は .12b に残る。

一般の型・行の同時置換についての `Ty.wf_bind` / `Eff.wf_bind` と `Ty.sorted_bind` / `Eff.sorted_bind`（後者の行の結論は既存の `sortedEff`）は、像のWF/sortと名前空間の番号の上限を明示して **L10** が閉じる。今回のLeQ/Coversの保存から、これらの一般の保存を閉じたとはしない。L00a.12aは、型付きの値の像を四判断へ接続する前提として必要な、現在の最小構文の**値の名前空間だけの置換**に対するWF/sortの保存を同作業の内数で先に閉じる。この場合も型と行の両方、および生の型注釈を対象にする。全構成子の追加と全置換への追随は L00b/L10/L20 の担当である。

コマンド・終了・外側の時間: [proof-audit-09a.lean](proof-audit-09a.lean)、[proof-09a.log](proof-09a.log)、[checks.json](checks.json) の `proof-09a`。終了0、73宣言、外側0.320855333秒。単位の実装時間は他の三単位と分離不能である。

## L00a.09b: 範囲・値の置換と交換

閉じた範囲の列による具体化と、開いた範囲変数を像に持てる写像を分けた。`rangeAt c rs` は cutoff より下の範囲変数と、列の外の範囲変数の番号をそのまま保つ。型・行の `instR_eq_bind` と `mapIx_rangeAt` は、cutoff 0 の具体化を既存の Ix.inst と四欄の SubstEnv に接続する。

| 内容 | 本番の補題と定義 |
|---|---|
| 範囲の置換と移動 | 型/行の `rawMapRanges` / `mapRanges` / `substRAt` / `instR` / `shiftR`、LeQ/Covers の各保存 |
| 値の同時置換とcutoff | `SubstEnv.valuesOnly`、`upTerms`、型/行の `substV` / `substVAt`、LeQ/Covers の保存。値の像は一般のTermでよい |
| 型/行/範囲の像と値置換の交換 | 型/行の `bind_substV` / `substAt_substV`、`typeEnvAt_mapValues`。像へ値置換を一度適用して交換先の環境を作る |
| 型/行の像と範囲置換の交換 | 型/行の `bind_mapRanges` / `substAt_mapRanges`、`typeEnvAt_mapRanges`。任意の開いた範囲位置の像に対応する |
| 範囲と値の交換 | 型/行の `rawMapRanges_rawSubstV` / `mapRanges_substV` |
| 正規化との交換 | 型/列/行の `norm_rawMapRanges`、.09aのnorm_rawBindと組み合わせ、上記の交換を正規化後にも証明した |

`bind_substV` の `θ.values = Term.var` は、型・行・範囲だけを置換する操作と値置換を交換するための条件である。`bind_mapRanges` の `θ.values = Term.var` / `θ.ranges = []` は型・行だけの置換との交換を表す。源の構文や型・行像に値・範囲の自由変数がない、という条件ではない。.09aの typeEnvAt はこれらを定義上満たし、任意のNat/cutoff・任意の型/行像について substAt の系を閉じた。四名前空間の任意の二つの同時置換の一般合成を、これらの交換から証明済みとはしていない。

[OpenSubstitution](../../../formal/Benitoite/Release/Refinement/OpenSubstitution.lean) は、Γに `Integer{self=7}` とNone、ΔにNoneと外側の整数を持つ。Γ.factsは `[path]` である。Δ.facts は `And (predBind σ path) truth` を一つ持ち、Ψ は `Or (predBind σ path) falsity` を一つ持つ。`target_path_from_facts` はΔ.factsのAndから等式を取り出し、`target_conditions_from_facts` はそこからΨも導く。`transport.facts` はこの等式の導出を弱化して用いるため、置換像の等式そのものを仮定する `.hyp` だけでは閉じない。

型・範囲・行の各自由変数が結果に残り、行像は複数原子と外側の整数を読む篩付きFailを持つ。`images_wf_sorted` が型像とFail像のWF/sort、`path_witness` が源と行き先の等式の条件を満たす具体的な整数の割当を示す。Δ.factsの残る条件はtruth、Ψの右枝はfalsityなので、同じ割当でΔ.factsとΨも満たす。未実装の Entails.ground を導入していない。

`all_open_derivation` / `all_open_covers` は関数の効果の枝を移す代表であり、それだけではfactsを使う篩の導入を確かめたことにはならない。RV-L00a.08の中1に従い、`source_introduce Φ` で `tvar 0 ≤ refined (tvar 0) (lift path)` を任意のΦについて導く代表を足した。`lift path` はselfではなく外側の値0が7であることを表し、その導出はΓ.factsにあるpathを明示的に使う。Φを空にもできるので、Φに同じpathがあることには依存しない。`introduce_bind` はこれを `.bind θ transport` で移し、`introduce_bind_shape` は移送後の型変数の像が `Integer{self ≤ outer 2 + 1}` であり、そこへ `outer 2 + 1 = 7` の篩を導入した形を示す。`introduce_bind_under_none` は、Noneを一つ加えた下でも同じ導出を移す。
同代表のσは冪等でない。二度適用すると型像とFail像が変わることを `double_value_substitution_changes_image` / `fail` で証明した。`image_not_reapplied` / `row_image_not_reapplied` は挿入した像へ同じ置換を再適用しないことを示す。型/行と値、型/行と範囲の四つの交換も同代表で閉じた。

**正規化との交換で閉じなかった指定の言明はない。** 範囲の平坦化、篩のtrue消去などの正規化を L00b.11 が追加すれば、今回の正規化の補題にも追加の場合の証明が必要になる。Term の論理置換と、一般の `σ : Nat → Val` の整数観測の接続は .12a/.12b に残す。現在の valEnv の `toTerm?.getD (integer 0)` を、整数以外の値が整数0であるという意味の前提にしない。整数を観測する位置について、型付けと観測の証拠から接続する必要がある。

コマンド・終了・外側の時間: [proof-audit-09b.lean](proof-audit-09b.lean)、[proof-09b.log](proof-09b.log)、[checks.json](checks.json) の `proof-09b`。終了0、126宣言、外側0.342489500秒。単位の実装時間は他の三単位と分離不能である。

## L00a.10: 一原子の被覆

`Eff.Covers.bind` は、源の各一原子の証人を置換後へ移し、Coversの導出を返す。範囲付き名前の原子は同じ範囲の具体化を使い、行の原子から来た複数の原子は同じ行像の所属で覆う。行像へ範囲/値/型の置換を再適用しない。Failは元の型から来る場合と行像から来る場合を分け、前者にはnorm_rawBindの合同、後者には同じ像の所属を使う。LeQでFailの型を拡大していない。

型/行の `substAt` / `subst`、型変数の `shift`、値の `shiftV` / `substV` / `substVAt`、範囲の `mapRanges` / `substRAt` / `instR` / `shiftR` の系を閉じた。Γ/Φは被覆の定義では参照しないため、行き先のΔ/Ψに余計な条件を足していない。

`cannot_split_one_atom` は、同じホストのポート0..9の一原子を、0..4と5..9の二原子では覆えないことを示す。既存の範囲の被覆の定理を使い、意味上の対象集合の和で導出を置き換えていない。`Eff.Sub.covers` は構造上の包含から被覆への一方向の補題であり、`covers_not_sub` は逆向きが成り立たないことを示す。開いた行像・範囲・篩付きFailを含む導出は上の `all_open_covers` にも接続した。

指定された最小構文の被覆について未証明枝はない。σ/保持対象と全sortの葉、全状態や効果健全性は今回の被覆補題の完了に数えず、L00b/L20/L50/L70に残す。

コマンド・終了・外側の時間: [proof-audit-10.lean](proof-audit-10.lean)、[proof-10.log](proof-10.log)、[checks.json](checks.json) の `proof-10`。終了0、11宣言、外側0.311952542秒。単位の実装時間は他の三単位と分離不能である。

## 公開へ変更した名前

次の30名を既存モジュールのprivateから公開へ変更した。共通接頭辞は `Benitoite.Release.Refinement` である。定義の型・本体は変更していない。後の証明が実装を展開・参照できるようにするための変更である。

| モジュール | 名前 |
|---|---|
| Order | `termTree`、`predTree`、`Ty.toTree`、`Eff.toTree`、`Ty.toTrees` |
| Context | `termBind`、`predBind`、`termWF`、`termSorted`、`sortedTys`、`sortedEff`、`shiftVTys`、`upValues`、`rawApply`、`substAtoms`、`rowFails`、`rawBindTys` |
| Subst | `renEnv`、`renameTy`、`renameEff`、`valEnv`、`substTyValues`、`substEffValues`、`shiftTypes`、`shiftTypesList`、`shiftRowsTypes`、`typeEnvAt`、`substTypeAt`、`substRowAt` |
| Le | `assumptions` |

## 新しく追加した公開名

初回の実装時に追加した263宣言の一覧を以下に記す。レビュー修正で追加した9宣言は末尾の対応節に記す。共通接頭辞は `Benitoite.Release.Refinement`、OpenSubstitution の行だけはさらに `OpenSubstitution` を付ける。自動生成される構成子・射影・再帰子は、その型の宣言に含めている。公開する各宣言の型と公理依存は上記の#check/#print axiomsのログを正とする。

| モジュール | 公開名 |
|---|---|
| Basic | `termBind_id`、`predBind_id`、`termBind_comp`、`predBind_comp`、`upValues_id`、`upValues_comp`、`predBind_lift`、`predBind_open`、`Entails.bind`、`shiftIndex`、`Pred.shiftV`、`upValues_shiftIndex`、`Entails.shiftV`、`termWF_bind`、`Pred.wf_bind`、`Pred.wf_shiftV`、`termSorted_bind`、`instAtoms_nil`、`substAtoms_nil`、`Ty.shiftV_eq_renameTy`、`Ty.shiftVTys_eq_rename`、`Eff.shiftV_eq_renameEff`、`renEnv_types`、`renEnv_rows`、`renEnv_ranges`、`renEnv_values` |
| Bind | `rawBindTys_eq_map`、`Ty.normTys_append`、`rawApply_norm`、`Ty.norm_rawBind`、`Ty.normTys_rawBind`、`Eff.norm_rawBind`、`Ty.rawBind_norm_congr`、`Eff.mem_rowFails`、`Eff.memFail_rawBind`、`Eff.mem_substAtoms`、`Ty.rawBind_id`、`rawBindTys_id`、`Eff.rawBind_id` |
| EffectCover | `Eff.mem_norm`、`Eff.Covers.refl`、`Eff.Covers.trans`、`Eff.Sub.covers`、`Eff.covers_norm_left`、`Eff.covers_norm_right`、`Eff.mem_rawBind`、`atomCovers_instR`、`Eff.Covers.bind`、`cannot_split_one_atom`、`covers_not_sub` |
| Transport | `Ty.integerCarrier_norm`、`Ty.IntegerCarrier.bind`、`Ty.assume_norm`、`Ty.assume_bind`、`Transport`、`termSorted_lift`、`Pred.sorted_bind`、`Transport.assumptions`、`Ty.LeQ.bind`、`Ty.LeQ.rawBind`、`Transport.id`、`Ty.LeQ.norm` |
| ShiftOrder | `Ty.tree_shiftV_compare`、`Ty.trees_shiftV_compare`、`Eff.tree_shiftV_compare`、`Ty.shiftV_compare`、`shiftVTys_eq_map`、`Ty.norm_shiftV`、`Ty.normTys_shiftV`、`Eff.norm_shiftV`、`Ty.wf_shiftV`、`Ty.wfList_shiftV`、`Eff.wf_shiftV` |
| Shift | `Ctx.shiftV`、`Ctx.lookup_shiftV`、`Ty.integerCarrier_shiftV`、`Ty.assume_shiftV`、`Ctx.mem_facts`、`Ctx.facts_shiftV`、`Transport.shiftV`、`Ty.LeQ.shiftV`、`Eff.Covers.shiftV`、`Pred.sorted_shiftV`、`Ty.sorted_shiftV`、`sortedTys_shiftV`、`sortedEff_shiftV`、`Pred.open_shiftV_self`、`Pred.open_shiftV_outer`、`Ctx.mem_facts_extend` |
| Exchange | `SubstEnv.up`、`SubstEnv.up_types`、`SubstEnv.up_rows`、`SubstEnv.up_ranges`、`SubstEnv.up_values`、`Ty.rawBind_up`、`rawBindTys_up`、`Eff.rawBind_up`、`Ty.bind_up`、`Eff.bind_up`、`Transport.extend`、`Transport.up`、`Transport.up_raw` |
| TypeSubst | `Ctx.bindTypes`、`Ctx.facts_bindTypes`、`Transport.types`、`Ty.substAt`、`Eff.substAt`、`Ty.subst`、`Eff.subst`、`Ty.LeQ.substAt`、`Ty.LeQ.subst`、`Eff.Covers.substAt`、`Eff.Covers.subst`、`SubstEnv.shiftTypes`、`Ty.shift`、`Eff.shift`、`Ty.LeQ.shift`、`Eff.Covers.shift`、`shiftTypes_shiftV`、`shiftTypesList_shiftV`、`shiftRowsTypes_shiftV`、`typeEnvAt_up`、`Ty.substAt_up`、`Eff.substAt_up`、`shiftTypes_zero`、`shiftTypesList_zero`、`shiftRowsTypes_zero`、`Ty.wfList_iff`、`shiftTypesList_length`、`Ty.wf_shiftTypes_norm`、`wfList_shiftTypes_norm`、`Eff.wf_shiftTypes_norm`、`Ty.rawBind_shiftTypes`、`rawBindTys_shiftTypes`、`Eff.rawBind_shiftTypes`、`Ty.wf_shift`、`Eff.wf_shift` |
| RangeSubst | `mapIx`、`mapAtomRanges`、`mapRangeAtoms`、`Ty.rawMapRanges`、`mapRangesTys`、`Eff.rawMapRanges`、`mapRangesTys_eq_map`、`Ty.mapRanges`、`Eff.mapRanges`、`Ty.norm_rawMapRanges`、`normTys_rawMapRanges`、`Eff.norm_rawMapRanges`、`Ty.assume_rawMapRanges`、`Ty.integerCarrier_rawMapRanges`、`Ctx.mapRanges`、`Ctx.facts_mapRanges`、`Eff.Covers.mapRanges`、`Ty.LeQ.mapRanges`、`rangeAt`、`Ty.substRAt`、`Eff.substRAt`、`Ty.instR`、`Eff.instR`、`Ty.shiftR`、`Eff.shiftR`、`Ty.LeQ.substRAt`、`Eff.Covers.substRAt`、`SubstEnv.rangesOnly`、`mapIx_rangeAt`、`mapRangeAtoms_rangeAt`、`Ty.rawMapRanges_rangesOnly`、`mapRangesTys_rangesOnly`、`Eff.rawMapRanges_rangesOnly`、`Ty.instR_eq_bind`、`Eff.instR_eq_bind`、`Ty.LeQ.instR`、`Ty.LeQ.shiftR`、`Eff.Covers.instR`、`Eff.Covers.shiftR` |
| ValueSubst | `SubstEnv.valuesOnly`、`upTerms`、`upTerms_zero`、`upTerms_one`、`Ty.substV`、`Eff.substV`、`Ty.substVAt`、`Eff.substVAt`、`Ty.LeQ.substV`、`Ty.LeQ.substVAt`、`Eff.Covers.substV`、`Eff.Covers.substVAt`、`rawApply_refined` |
| ValueExchange | `Ty.rawSubstV`、`substVTys`、`Eff.rawSubstV`、`substVTys_eq_map`、`Ty.rawSubstV_eq_rawBind`、`substVTys_eq_rawBind`、`Eff.rawSubstV_eq_rawBind`、`SubstEnv.mapValues`、`SubstEnv.mapValues_types`、`SubstEnv.mapValues_rows`、`SubstEnv.mapValues_ranges`、`SubstEnv.mapValues_values`、`Ty.rawBind_substV`、`rawBindTys_substV`、`Eff.rawBind_substV`、`Ty.bind_substV`、`Eff.bind_substV`、`shiftTypes_substV`、`shiftTypesList_substV`、`shiftRowsTypes_substV`、`typeEnvAt_mapValues`、`Ty.substAt_substV`、`Eff.substAt_substV` |
| RangeExchange | `mapRangeAtoms_spec`、`mapRangeAtoms_rho`、`SubstEnv.mapRanges`、`SubstEnv.mapRanges_types`、`SubstEnv.mapRanges_rows`、`SubstEnv.mapRanges_ranges`、`SubstEnv.mapRanges_values`、`Ty.rawBind_mapRanges`、`rawBindTys_mapRanges`、`Eff.rawBind_mapRanges`、`Ty.bind_mapRanges`、`Eff.bind_mapRanges`、`shiftTypes_mapRanges`、`shiftTypesList_mapRanges`、`shiftRowsTypes_mapRanges`、`typeEnvAt_mapRanges`、`Ty.substAt_mapRanges`、`Eff.substAt_mapRanges`、`Ty.rawMapRanges_rawSubstV`、`mapRangesTys_substVTys`、`Eff.rawMapRanges_rawSubstV`、`Ty.mapRanges_substV`、`Eff.mapRanges_substV` |
| OpenSubstitution | `Γ`、`Δ`、`path`、`σ`、`dependentType`、`dependentFail`、`rowImage`、`θ`、`inner`、`outer`、`source`、`context_facts`、`context_none`、`transport`、`source_covers`、`all_open_derivation`、`all_open_covers`、`open_images`、`path_witness`、`images_wf_sorted`、`type_value_exchange`、`row_value_exchange`、`type_range_exchange`、`row_range_exchange`、`image_not_reapplied`、`double_value_substitution_changes_image`、`double_value_substitution_changes_fail`、`row_image_not_reapplied` |

## 検査と所要の記録

途中は関係するモジュールの `lake build Benitoite.Release.Refinement.<対象>`、又は `lake env lean -M 12288 Benitoite/Release/Refinement/<対象>.lean` だけを使った。途中の失敗は、simpが環境の定義を先に展開して帰納仮定に合わなくなる箇所、Boolの所属とListの所属の型の明示、木の比較で根の構成子が既知の場合だけを展開する箇所、補題名と不要なrflの修正である。失敗の後は当該モジュールを再検査し、最終の局所ビルドと293宣言の署名/公理検査で取り残しがないことを確かめた。検査の制限や期待値を緩めていない。全試行の能動時間と待ち時間は分離できない。

最終の局所ビルドは `lake build Benitoite.Release.Refinement.OpenSubstitution`、終了0、外側8.429942416秒、[local-build.log](local-build.log)に保存した。これは変更した葉とその依存の**増分ビルド**であり、既定ターゲット全件のビルドではない。既定全件は次のworkで実行する。

作業末の指定は次である。実行台本は [run-checks.py](run-checks.py)、外側の時間と終了は [checks.json](checks.json) に保存する。dry-run と work は別の起動とし、台本は同じ検査名の二度目の実行を拒否する。

```sh
rtk proxy scripts/check.sh --level work --base 22aaeb3cb1faf65264abad20cab8eb99ec3fcc81 --dry-run
rtk proxy scripts/check.sh --level work --base 22aaeb3cb1faf65264abad20cab8eb99ec3fcc81
```

既定ターゲットは Benitoite、desugarDiff、builtinCheck、coverageDiff、coverageProgramDiff、surfaceCheck、surfaceCheckAll、intervalDiff の8件である。workは既定の**増分ビルド**とsorryの拒否を行う。Rustの全lib・全比較・測定は追加しない。workの最終結果と共通区間の時間は末尾へ追記する。

293宣言（新263、公開へ変更30）の#check/#print axiomsはすべて終了0・警告なし。依存は propext・Quot.sound・Classical.choice の部分集合だけであった。[proof-summary.json](proof-summary.json)に単位別の件数と依存を記した。これは今回の新しい葉の局所検査であり、L00a末の既存主定理も含むA-L、独立レビュー、Rust/Leanの全比較の代わりではない。

## 義務の段別判定と次の作業

| 義務 | 今回の判定と証拠 | 残る段 |
|---|---|---|
| O002 | .08〜.10の最小構文について、LeQ/Coversの移動・四名前空間の置換・交換と、開いた代表の構文導出を閉じた。各単位の本番補題と監査ログ | .12a/.12bの型付き像と相互置換、L00b/L10の追加場合、L20の全導出 |
| O004 | Nat/cutoffとself/外側の値、WF/sort/facts、型/行/範囲/値の交換を上記の範囲で閉じた。heartbeat上限の変更なし。最大常駐量は未取得（計画上の非採取） | L00bの全sort、L20の全判断、取りまとめによる段末RSS |
| O006 | 篩と外側値依存を持つ型/行の像を除外しない一般の補題に加え、Γ.factsを使うsource_introduceと、篩付きの像へ移すintroduce_bind/shapeを閉じた。RV-L00a.08中1への対応を含む | .12a/.12bの型付き値、L20の全置換 |
| O031 | L00aのLeQ/CoversのsubstAt/subst/shiftと、外側の値に依存する型・行の像の分を閉じた。TypeSubst/ValueExchange/RangeExchange、各保存補題、OpenSubstitutionが証拠 | .12a/.12bの相互置換、L20の全判断 |
| O040 | 本番のNat/cutoffで.08の移動の言明と補題を実装し、局所検査とworkの実績を記録した。レビューの.08の判定を満たす | .16a/.16bの実績の集約と見込み更新、後段の全構成子 |
| O010 | 四単位の本番の成果と共通区間・検査の記録を残す。単位別の能動時間は分離不能である | .16a/.16bの集約・見込みの更新と取りまとめのレビュー |
| O016 | 新しい葉と公開補助293宣言の局所公理依存を確認。独自の公理なし | L00a末のA-Lと独立レビュー |

L00a.12aは、`Transport` のfacts欄を型付きの値の像から導き、Φの像の証拠と合わせて `Ty.LeQ.rawBind` 又は `bind` をV_Subへ適用する。`Ty.assume_bind` は型像で増えた事実を許す包含、`Transport.assumptions` と Entails.cut は仮定の移送を受け持つ。束縛の下は `Transport.extend` / `up` / `up_raw` と `rawBind_up` / `bind_up` を使う。既存の項の置換の型注釈が生のrawBindであることを見落とさず、正規化後の型だけへ結論を変更しない。hideContsと篩付き継続の問題（レビュー軽4）は、L00b.02a/L10の担当を保つ。

型/行の有限列と値・範囲の交換は ValueExchange/RangeExchange、被覆の枝は Eff.Covers.bind とその系を使える。C_Sub/C_Effを含む四判断の相互入口は .12b が閉じる。構成子追加後の全sort、依存列、正規化の追加の場合、全値/計算/腕/節、ストア/継続/状態の一般化と新主定理は今回の完了へ繰り上げない。

計画からのずれは、補題を13モジュールへ分けたこと、早い段階で一般のCovers.bindを閉じてLeQ.bindに使い、四単位の実装が時間的には重なったことである。新しい公理、契約や主定理の前提/結論の変更、範囲の縮小、停止条件に当たる未知の不一致はない。篩付き型構成子像の既知の論点だけを指定されたL00b.11へ送った。独立レビューと設計者の受け入れは未実施である。

## 初回の作業末の検査の結果

| 検査 | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| 関係モジュールの最終増分ビルド | 0 | 8.429942416秒 | 新13モジュールとその依存。既定全件の実行ではない。[ログ](local-build.log) |
| work の dry-run | 0 | 0.307576375秒 | 35変更ファイルから formal_build だけを選択。[ログ](dry-run.log) |
| 作業末の work | 0 | 1.354807541秒 | 36変更ファイル。既定lake buildとsorryの拒否が成功。[ログ](work.log) |

workは同じB_WORKと指定で一度実行し、selected checks passedとなった。既定のlake buildは増分である。新しい葉は直前の局所ビルドで作成済みで、workではそれらの成果物を再利用した。workの約1.35秒を新モジュール全件の再コンパイル時間とはしない。dry-runとworkの変更ファイル数の差は、保存したdry-run.logの追加による。work後は結果の文書と照合の記録だけを追記し、形式化・設定・入力を変更していない。Rustのテスト・全比較・RSS用の追加ビルドは行っていない。

[source-audit.py](source-audit.py)をworkの前後に実行し、356入力のハッシュが一致した。[source-audit.json](source-audit.json)に各入力のバイト数とSHA-256を保存した。L00a.01bの旧327モジュールのうち集約以外の326件は同じであり、集約はL00a.06bの状態から今回のimport一行だけを追加していた。L00a.06bの9モジュールではTypes/Normalize/Logic/Syntax/Typingの5件が同じであり、残る4件も今回の公開範囲と冒頭の説明を戻すと保存済みのハッシュと一致した。lakefileとtoolchainも同じである。これは異なる基準の記録との入力照合であり、今回のB_WORKを過去の基準IDと同一視するものではない。

入力照合の台本の初回は、Leanの冒頭コメントを除く正規表現の誤記で終了1となった。正規表現を直し、上記の一致を確認してからdry-runとworkへ進んだ。Leanソースの問題ではなく、照合用の台本だけの修正であった。

最初の取得時計21:39:17から、最後の入力再照合の終了 2026-10-30T22:20:14+09:00 までの共通区間の外側の時間は **40分57.932秒** であった。最初の読取りから時計の取得までの時間と、本節の追記以後はこの値に含めない。四単位を順に測った記録ではないため、単位別の実装の外側の時間は分離不能であり、共通区間を四単位へ重複計上しない。全体の能動時間と待ち時間も分離不能であり、この値を能動時間の実績として外挿しない。検査ごとの外側の時間はchecks.jsonへ保存した。

四単位の最小構文に対する指定の補題を本番へ残した。計画の2〜4時間に対して共通区間はそれより短いが、計画時の能動時間と今回の分離不能な外側の時間を直接比にしない。8時間超過の停止条件は発生していない。既知のrawApplyの論点と後段の追加構成子・型付き値・全主定理への義務は上の各単位の節に残した。独立レビューと受け入れを済ませたとはしていない。最大常駐量は **未取得（計画上の非採取）** である。

## RV-L00a.08 への対応

同じブランチとB_WORKを引き継ぐ継続作業である。初回の検査・時間・入力の記録は残し、今回の記録を [rv-l00a.08/](rv-l00a.08/) に分けた。担当によるgitの操作はない。レビュー本文を読み、中1・軽1・軽2・軽3・軽5に対応した。軽4は取りまとめのplanへの記録、軽6・軽7は後段への注意という指定を保つ。

| 所見 | 修正と証拠 | 状態 |
|---|---|---|
| 中1 | source_introduceは任意のΦについてΓ.factsのpathから外側の値を観測する篩を導入する。introduce_bindで篩付きで値に依存する像へ移し、introduce_bind_shapeに結果の具体形を示した。Δ.factsのAndから等式を取り出し、ΨのOrもそこから導く。09b節をこの代表の性格に合わせて訂正 | 実装済み。修正後の検査は下記 |
| 軽1 | 義務表へO031とO040を追加。O006の代表の証拠も今回の導出へ対応 | 記録済み |
| 軽2 | Ctx.mem_facts_extendNoneとTransport.extendNoneを追加。整数観測の0番をNoneとして拒否し、外側のfacts/Φだけをliftする。introduce_bind_under_noneも閉じた | 実装済み。.12aへ未証明としては送らない |
| 軽3 | 一般の型・行のwf_bind/sorted_bindはL10、.12aで先に要る最小構文の値置換の場合は.12aの内数と09a節に明記 | 未実装の義務の送り先を記録 |
| 軽5 | rangeAtと型・行のsubstRAtのdocstringに、列の外の範囲変数の番号を下げない既存のIx.instの規約を記した | 修正済み |

新しく追加した公開名は次の9名である。共通接頭辞は `Benitoite.Release.Refinement`。既存のprivateを新たに公開へ変更したものはない。

- `Ctx.mem_facts_extendNone`
- `Transport.extendNone`
- `OpenSubstitution.Ψ`
- `OpenSubstitution.target_path_from_facts`
- `OpenSubstitution.target_conditions_from_facts`
- `OpenSubstitution.source_introduce`
- `OpenSubstitution.introduce_bind`
- `OpenSubstitution.introduce_bind_shape`
- `OpenSubstitution.introduce_bind_under_none`

OpenSubstitutionのΔは、移送先で必要な等式をAndの内部に持つ篩付きの整数の型へ変更した。同モジュールのcontext_facts、transport、all_open_derivation、all_open_coversの言明はこのΔ/Ψへ対応した。これらはレビューで指示された代表の修正であり、固定した契約の型・欄・規則、一般のLeQ.bind/Covers.bind、主定理の前提・結論を変更していない。RangeSubstの変更はdocstringだけである。

今回の公開名の一覧は [rv-l00a.08/public-names.json](rv-l00a.08/public-names.json)、新9宣言を含む、OpenSubstitution全体とExchangeの追加2補題の計37宣言の署名と公理依存は [proof-audit.lean](rv-l00a.08/proof-audit.lean) とその検査ログへ保存する。初回の263宣言・293件の検査は初回時点の記録として残し、今回変更した代表の現行の型と公理依存は今回のログを正とする。現在の追加モジュールの公開宣言は272件である。

一ファイルのLean検査は `-M 12288`、ビルドは既定のlakefileの設定を使い、上限を変更していない。最大常駐量は **未取得（計画上の非採取）**。初回に続く今回のworkも、同じB_WORKでdry-runの選択を確認してから一度実行する。[今回の実行台本](rv-l00a.08/run-checks.py)は初回のログとchecks.jsonを上書きしない。

今回の検査は次の結果であった。各コマンドの全引数、起点、終了、外側の時間は [checks.json](rv-l00a.08/checks.json) に保存した。基準はすべて `22aaeb3cb1faf65264abad20cab8eb99ec3fcc81` である。

| 検査 | 終了 | 外側の時間 | 証拠 |
|---|---:|---:|---|
| 関係する葉の増分ビルド | 0 | 2.587600458秒 | [ログ](rv-l00a.08/local-build.log) |
| 新9宣言と代表を含む37宣言の署名・公理依存 | 0 | 0.327433958秒 | [ログ](rv-l00a.08/proof.log) |
| workのdry-run（49変更ファイル、formal_buildだけ） | 0 | 0.114401458秒 | [ログ](rv-l00a.08/dry-run.log) |
| 作業末のwork（50変更ファイル、formal_build） | 0 | 0.906071250秒 | [ログ](rv-l00a.08/work.log) |

新宣言と変更した代表の検査は警告なしで、依存は propext・Quot.sound・Classical.choice の部分集合だけであった。[proof-summary.json](rv-l00a.08/proof-summary.json)に件数と照合結果を保存した。既定のlake buildは増分であり、新しい葉は先の局所ビルドで作成済みだった。workでは既存の成果物を再利用している。約0.91秒を全ソースの再コンパイル時間とはしない。既定8ターゲットのビルドとsorryの拒否を実行し、selected checks passedとなった。dry-runとworkの差の1ファイルはdry-run.logの追加による。

[source-audit.py](rv-l00a.08/source-audit.py)をworkの前後に実行し、360入力が一致することを確かめた。[source-audit.json](rv-l00a.08/source-audit.json)にSHA-256と大きさを保存した。継続作業の開始時点から変わった本番の入力はExchange/OpenSubstitution/RangeSubstの3ファイルだけで、RangeSubstは追加したdocstringを戻すと開始時のハッシュと一致した。契約・計画・旧判断・既存の主定理・ツールチェーンは、この継続作業で変更していない。検査後の追記は結果の文書だけである。

今回の取得時計22:31:32から最後の入力再照合 2026-10-30T22:39:37+09:00 までの外側の時間は **8分5.089秒** である。レビュー等の読取りから時計の取得までと、この記録の追記後は含めない。能動時間と全待ち時間を分離した記録はないため、能動時間の実績にはしない。局所ビルド・公理依存・workはそれぞれ一度記録した。初回の検査の記録とは別の、今回の修正後の検査である。

指定された中1・軽1・軽2・軽3・軽5への実装・記録と今回の検査を終えた。一般のWF/sort置換保存は上記の送り先で未実装であり、今回閉じたとはしていない。軽4のkind/rawApplyの扱いは取りまとめによるL00b.11等への記録、軽6の像上の分割拒否は任意の後続、軽7のassumptionsの同名への注意は後段へ申し送る。今回の修正後の独立レビューと受け入れは未実施である。最大常駐量は **未取得（計画上の非採取）**。

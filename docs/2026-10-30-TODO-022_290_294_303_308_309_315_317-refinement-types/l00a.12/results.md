# L00a.12a・L00a.12b: 値・計算の相互置換

**現行の結果と判定は末尾の「二度目の停止への対応」を正とする。それ以前は初回・継続作業（1）の各停止時点の記録であり、現行の WF や完了状態の主張ではない。**

指定ブランチは `m014/l00a.12`、B_WORK は `c652fa3d15f0c4a86e89250c28eccf662cb91f93` である。担当による Git コマンドの実行・状態変更は行わない。作業開始の取得時計は 2026-10-30 22:41:10 +09:00 である。

## 契約の照合で見つかった問題

値置換が型注釈へ生の `rawBind` を適用する一方、`Ty.WF` は関数型・継続型に含まれる行の `Eff.Canonical` を要求する。異なる変数を同じ値へ写すと、異なっていた二つの Fail 型が一致し、生の Fail 列に重複が残る可能性がある。型付きの像・空でない文脈の事実・篩付きの像でも生じるか、現行定義を変えずに再現を検査する。

再現の補題は本番の `Refinement.SubstTypingObstruction` に残す。整数・添字・cutoff は既存の型を用い、定義済みの型・公開署名・規則は変更しない。予定する主な再現の署名は次である（検査前の予定であり、閉鎖の記録ではない）。

```text
RawValueSubstCollision.source_wf : sourceTy.WF 0 0 Γ.length
RawValueSubstCollision.source_sorted : sourceTy.Sorted Γ
RawValueSubstCollision.images_typed :
  Γ[i]? = some (some a) → HasTypeVQ P B store Q C Δ Φ (σ i) (substTyValues σ a)
RawValueSubstCollision.transport : Transport (valEnv σ) Γ Φ Δ Φ
RawValueSubstCollision.substituted_not_wf : ¬ (substTyValues σ sourceTy).WF 0 0 Δ.length
```

上の再現は確定した。**L00a.12a・L00a.12b は未完であり、現行の項の値置換に対する相互置換は成立しない。** 正規化後の型付き像を使っても再現する。停止後は原因の再現・結果の記録・指定の検査だけを行った。型付け・置換・正規化の既存定義、契約・計画・Rust・現行設計書は変更していない。既存ファイルの変更は、集約 `formal/Benitoite.lean` への新モジュールの import 一行だけである。

## 確定した反例と停止の理由

[本番の再現](../../../formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean)は、次の構文を使う。下の `x₀`・`x₁` は説明のための外側の変数で、実装では self の下の Nat の番号1・2となる。

```text
I       = Integer{self = 7}
Γ       = [some I, some I]
Δ       = [some I]
Φ       = [x₀ = 7]
σ i     = var 0
F₀      = Integer{self = x₀}
F₁      = Integer{self = x₁}
latent  = Fail の列 [F₀, F₁]、名前・行の原子なし
sourceTy = fn [] [] Unit latent
sourceVal = lam ["f"] [sourceTy] (return Unit)
valueTy   = fn ["f"] [sourceTy] Unit empty
resultTy  = refined valueTy (lift (x₀ = 7))
```

`failure_compare` と `latent_canonical` は元の Fail 列が整列済み・重複なしであることを示す。`source_wf`・`source_sorted` は、元の `sourceTy` が参照の上限と sort を含めて適格であることを示す。Γ の各位置は、内側の変数を参照しない同じ閉じた I である。範囲の具体化・外部呼出し・ストア・継続・新しい意味のモデルを使わずに再現する。

`images_typed` は生の置換後の型について、`images_typed_bind` は契約の `SubstOk` が要求する **正規化後の `Ty.bind (valEnv σ)` の型**について、各 σ i の型付けを示す。どちらも Δ の篩付きの変数そのものが像である。`SubstOk` の宣言自体は本作業では作っていないため、これをその宣言の定理とは呼ばない。契約の通常値の各欄に必要な型付き像を具体的に満たし、継続の位置はないことを示した。

`context_facts` の Γ.facts は `[x₀=7, x₁=7]`、Δ.facts は `[x₀=7]` であり、`transport` は元の facts と Φ の両方の像を Δ.facts から導く。`source_le` は Γ.facts から得た `x₀=7` を実際に使って `introduce` を適用する。`source_v_sub` と `source_c_sub` はこの LeQ をそれぞれ本番の V_Sub・C_Sub へ適用する。空でない Γ/facts/Φ と篩付きの像を、使わずに並べただけの例ではない。

しかし `latent_image` は、現在の `substEffValues σ latent` の Fail 列が `[F₀,F₀]` になることを示す。`latent_image_not_canonical` は、その行の norm が重複を除くため、行自身との等号が成立しないことを示す。このため `substituted_not_wf` が成立する。これは sort や自由変数の範囲の不一致ではなく、潜在効果の `Eff.Canonical` の不一致である。

さらに `substituted_lambda_untypable` は、**任意の行き先の Φ'・結果型 a** について、現在の `Val.subst` 後のラムダの型付けがないことを示す。`HasTypeVQ.lam_annotations_wf` は外側の V_Sub・V_Refine の連鎖を越えて、ラムダの注釈の WF を取り出す。したがって結果型だけを Ty.bind で正規化する方法では反例を避けられない。`substituted_return_untypable` は `HasTypeCQ.return_value_typable` を使い、任意の結果型・効果・R・局所参照文脈について現在の `Comp.subst` 後の return の型付けがないことまで示す。

共通依頼文「実装の条件」の「未承認の変更、公理の追加、結論の弱化、…未知の食い違い」と、起動依頼の「契約の型・公開の欄を変える必要が出たら、実装を進めずに報告する」を踏まえ、既存の公開置換の動作を変更する前に取りまとめへ返す。直接食い違うのは、前作業の結果の「生の型注釈を対象にする」WF 保存と、現在の `substTyValues`/`substEffValues`/`Val.subst`/`Comp.subst` の定義である。**署名の変更が必須だとまでは確定していない。** 同じ署名のまま正規化を追加する候補もあるが、公開の置換の動作と生の注釈の保存の扱いを再指定する必要がある。主定理の前提や結論を弱めて回避していない。

## L00a.12a の結果

| 内容 | 判定・証拠 |
|---|---|
| ラムダ注釈の必要条件 | `HasTypeVQ.lam_annotations_wf` を閉じた。最小判断の全該当場合を扱う |
| 篩付きの型付き像と facts/Φ の移しの代表 | `images_typed_bind`・`transport`・`source_le`・`source_v_sub` を閉じた。一般の型付き像から Transport.facts を導く補題ではない |
| 生の値置換による WF 保存 | 指定の一般命題は成立しない。`substituted_not_wf` と実際の項の `substituted_lambda_untypable` が反証 |
| 一般の整数観測・既定値の無関係性・sort 保存 | 未実装。停止後に新しい実装を増やしていない |
| 型付き像から facts を得る一般補題、V_Sub を含む値の置換 | 未完。像を正規化しても、項の生の注釈で反例が残る |
| `SubstOk`・`ClosedTy`・Γ の narrowing | 未実装。本作業の残りであり、L00a 完了として後へ送っていない |

最初の一時間の接続確認では、V_Sub を含む値の置換の一群を閉じられるという確認には至らず、その一群の現行の項置換に対する反例を得た。V_Sub の LeQ だけを移すことに範囲を狭めて完了とはしていない。

## L00a.12b の結果

| 内容 | 判定・証拠 |
|---|---|
| return の値の必要条件 | `HasTypeCQ.return_value_typable` を閉じた。C_Sub/C_Eff の外側の連鎖も含む |
| C_Sub を実際に使う元の導出と置換後の否定 | `source_c_sub`・`substituted_return_untypable` を閉じた |
| V/Vs/Each/C の相互置換、C_Sub/C_Eff の一般の枝 | 未完。現行の Comp.subst に対する一般命題は上の反例で成立しない |
| Γ の narrowing の CQ 側、値なし束縛への `Transport.extendNone` の使用 | 未実装。既存の `Transport.extendNone` は変更していない |
| 全 canonical forms、腕・節・全状態 | 契約どおり L00b/L40・L20 に残る。今回の二つの必要条件を全 canonical forms の完了とはしない |

## 義務の行の判定

前作業で閉じた LeQ/Covers 自体の保存を取り消す結果ではない。項の値置換との接続の .12a/.12b の分を区別する。

| 義務 | 今回の .12a の分 | 今回の .12b の分 | 残る作業と証拠 |
|---|---|---|---|
| O002 | 未完。型付き像から値型付けへの接続で反例 | 未完。計算への接続でも反例 | .12 の再指定後に相互入口を閉じ、L20 で全導出へ追随。`substituted_*_untypable` |
| O006 | 未完。値に依存する Fail 型を実際に代入すると重複することを確認 | 未完。型/行の像の範囲を制限していない | .12 の再開と L20。独立に型/行の置換を全 Top や非依存へ狭める対策は採らない |
| O029 | 具体的な facts/Φ の移しのみ閉鎖。一般の型付き像からの cut・Γ narrowing は未完 | CQ を含む一般の Γ 保存は未完 | .12 の再開、L00b.03、L20。`transport` は代表であり一般定理ではない |
| O031 | 未完。V_Sub を含む元の導出からの置換保存が反例で不成立 | 未完。C_Sub を含む元の導出からの置換保存が反例で不成立 | .12 の再指定が必要。LeQ/Covers の .08〜.10 の結果は保つ |
| O010 | 本番に残る反例・必要条件と外側の時間を記録。中心の補題の完成とはしない | 同左 | .16a/.16b で未完を引き継ぎ、成功例として外挿しない |
| O016 | 新37公開宣言の依存をすべて照合済み | 同左 | 段末の旧主定理・新しい葉全体の A-L は .16a に残る |
| O040 | Nat の de Bruijn と構文の葉のまま再現 | 同左 | .16a/.16b で比較・較正を完了。今回の反例検査時間を完成の所要時間に使わない |

## 追加した公開名

既存の private を公開へ変えた宣言はない。新37宣言の完全名は [public-names.json](public-names.json)、署名全文と公理依存は [proof-audit.lean](proof-audit.lean) と [proof.log](proof.log) にある。共通接頭辞は `Benitoite.Release.Refinement` である。

| 名前空間 | 新しい公開名 |
|---|---|
| `HasTypeVQ` | `lam_annotations_wf` |
| `HasTypeCQ` | `return_value_typable` |
| `RawValueSubstCollision`（定義） | `refinedInt`、`Γ`、`Δ`、`path`、`Φ`、`σ`、`failure`、`latent`、`sourceTy`、`sourceVal`、`valueTy`、`resultTy` |
| `RawValueSubstCollision`（補題） | `failure_compare`、`failure_norm`、`latent_canonical`、`source_wf`、`source_sorted`、`image_type`、`images_typed`、`images_typed_bind`、`context_facts`、`transport`、`latent_image`、`latent_image_not_canonical`、`substituted_not_wf`、`value_wf`、`value_sorted`、`path_lift_sorted`、`path_lift_wf`、`source_le`、`lambda_typed`、`source_v_sub`、`source_c_sub`、`substituted_lambda_untypable`、`substituted_return_untypable` |

非公開の再帰の補助は `lam_annotations` と `return_value` の二つである。新しい型・構成子・信頼条件は追加していない。今回作った補題はすべて本番の新モジュールに残し、集約の既定 import から読む。

## 検査・時間・入力

基準はすべて `c652fa3d15f0c4a86e89250c28eccf662cb91f93`。コマンドの全引数・起点・開始時刻・終了・外側の時間は [checks.json](checks.json)、実行台本は [run-checks.py](run-checks.py) にある。Lean の単一ファイルの検査には `-M 12288`、ビルドには既定の lakefile の `moreLeanArgs = ["-M", "12288"]` を使った。最大常駐量は **未取得（計画上の非採取）** である。

| 検査 | コマンドの中心部分 | 終了 | 外側の時間 | 証拠 |
|---|---|---:|---:|---|
| 再現の最終の局所ビルド | `lake build Benitoite.Release.Refinement.SubstTypingObstruction` | 0 | 0.582921041秒 | [local-build.log](local-build.log)。57 jobs、新モジュールを作成した増分ビルド |
| 新37宣言の署名・公理依存 | `lake env lean -M 12288 ../docs/…/l00a.12/proof-audit.lean` | 0 | 0.334611459秒 | [proof.log](proof.log)、[proof-summary.json](proof-summary.json) |
| 指定の work の dry-run | `scripts/check.sh --level work --base c652fa3d15f0c4a86e89250c28eccf662cb91f93 --dry-run` | 0 | 0.118342708秒 | [dry-run.log](dry-run.log)。11変更ファイル、formal_build だけ |
| 作業末の work（一度） | `scripts/check.sh --level work --base c652fa3d15f0c4a86e89250c28eccf662cb91f93` | 0 | 1.020264083秒 | [work.log](work.log)。12変更ファイル、formal_build、selected checks passed |

work の formal_build は、既定の `lake build`（8ターゲット）と `sorry` の拒否である。先の局所ビルドで新モジュールを作成済みであり、既存の成果物を再利用した **増分ビルド** として記録する。約1.02秒を全ソースの再コンパイル時間とはしない。dry-run と work の差の1ファイルは dry-run.log の追加である。Rust の lib や統合テスト、段末の全 A-L、Rust/Lean の全比較は実行していない。

新37宣言の依存は propext・Quot.sound・Classical.choice の部分集合だけであり、未承認の公理・sorryAx はない。新モジュールの `sorry`・`admit`・独自の `axiom`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`set_option` の検索は該当なし（rg の終了1）。Lean の最終の局所検査と新モジュールのビルドに警告はない。ログ先頭の rtk の hook 未導入の注意は道具の設定についてのもので、設定は変更していない。

途中の同じ `lake env lean -M 12288 Benitoite/Release/Refinement/SubstTypingObstruction.lean` の局所検査では、比較の簡約、WF の展開、論理和の並び、rawBind の環境の明示、型付けの添字を一般化した構造再帰、V_Lam の引数の推論、予約語 `local` の使用に関する証明スクリプトの誤りで失敗した。これらを新モジュール内で直し、最終の局所ビルド・37宣言の依存の照合・work が成功した。途中の各試行のログの保存と外側の時間の個別採取は行っていないため、最終の検査値に混ぜない。制限・警告・期待値を緩めていない。

検査前後の348入力の SHA-256 と大きさは [source-audit.json](source-audit.json) に保存し、work 後に一致を確認した。対象はライブラリの本番の全 Lean ソース、新しい集約、lakefile/manifest/toolchain、check.sh、共通依頼文・計画・契約である。これは別状態の旧検査の引用ではなく、今回の入力を直接検査した記録である。初回の入力記録は再現を作成した後なので、開始版との全ファイル差分をハッシュだけで証明したものではない。検査後の変更は本結果の追記だけである。

開始時計 22:41:10 から work 後の入力一致確認の時計 22:49:06 まで、共通区間の外側の時間は **7分56秒** である。この後の報告の執筆は含めない。二単位ごとの能動時間と待ち時間は分離不能であり、これを能動時間又は中心の補題を完成させた実績にはしない。見込み上端の2倍の4時間を超えていない。時間超過ではなく、現行の置換の定義と WF 保存の不成立による停止である。

## 修正候補と L00a.16a への申し送り

第一候補は、**項の型注釈の値置換にも正規化を適用する**ことである。`substTyValues`/`substEffValues` を `Ty.bind`/`Eff.bind` と合わせる方法、又は同じ正規化を計算可能な関数で実装して既存の norm との一致を示す方法がある。前者は現在の norm が noncomputable なので、Val/Comp/Arm/Clause の置換へ noncomputable が伝播する可能性を照合する必要がある。署名を保てる可能性があるが、既存の生の構文との交換、束縛下の up、型注釈の正規化、旧構文の埋め込みとの対応を同じ契約へそろえる必要がある。本作業でこの変更を実装していない。

第二候補は、WF と行の Canonical を別の条件として扱うか、正規化を明示した項の判断を使うことである。これは型付けの規則・公開契約への影響が広く、現行の WF の条件を黙って削る対策は採らない。置換を単射な改名へ限定する対策や、外側の値に依存する Fail 型を除く対策は、契約の量化範囲を狭めるため候補から除く。結果型だけの正規化は `substituted_lambda_untypable` で不十分と分かる。

| 再開に必要な残り | 担当・見込み |
|---|---|
| 現行定義・反例・修正方針の独立レビュー、公開の置換の動作と生の注釈の義務の再指定 | 取りまとめ・設計者。時間は不明 |
| 項の置換と正規化の接点の短い確認、WF/sort/up/整数観測/facts の補題 | 再指定を受けた .12 担当。最初の1時間で形を確認する案。未実測 |
| V_Sub/C_Sub と Γ narrowing を含む相互置換の再開 | .12 担当。現時点の追加の能動時間は不明。元の1〜2時間を保証として再利用しない |
| 修正した入力の局所検査、新しい宣言の公理依存、作業末 work | .12 担当。増分の所要は変更範囲に依存し不明 |
| 旧主定理・新しい葉を含む段末 A-L、較正の集約、独立レビュー・受け入れ | L00a.16a/.16b・取りまとめ・設計者。時間は不明 |

L00a.16a は .12a/.12b を完了したものとして中心の補題の較正・受け入れを行えない。取りまとめが既存規則と本反例をレビューし、項の注釈をどう置換するかを再指定した後、.12 の残りを閉じる必要がある。本番へ残した二つの必要条件の補題と反例は、その再指定と後段の新構成子の追加時に参照する。全 canonical forms・腕・節・状態に予定済みの残りと、今回の .12 自身の未完を混同しない。

## RV-L00a.12-stop への対応

2026-10-30、継続作業の開始時計は22:59:08 +09:00。取りまとめが採択した(a)に従い、`substTyValues`/`substEffValues`/`substKind` を bind に合わせ、Val/Comp/Arm/Clause の値置換を noncomputable にする。署名・規則・主定理の量化範囲は変えない。Val.rename/renameTy は生のまま保つ。

実装前の主な目標署名は `Ty.WF nr nt nv a → a.Canonical`、`Ty.WFList nr nt nv as → Ty.normTys as = as`、値だけの bind の WF/sort 保存、`valEnv (upSubst k σ)` と k 回の up の交換、`HasTypeVQ.toTerm_of_integerCarrier`、契約の `SubstOk` と `ClosedTy`、V/Vs/Each/C の subst と narrowing である。最上位の行は WF だけでは Canonical にならない既存の規約を保ち、行の版は Fail 要素の正規化と、正規化した行の WF/Canonical として示す。

L00a.08/results.md の「生の型注釈を対象にする」一般の WF 保存の申し送りは偽なので撤回する。同ファイル自体は変えない。初回の `substituted_*` の反例は rawBind を明示する回帰の例へ書き換え、修正後の Val.subst に対する不成立の主張として残さない。

### 継続作業の結果と二度目の停止

**正規化した値置換と、現在の V/Vs/Each/C の全構成子に対する相互置換を閉じた。しかし Γ narrowing で別の反例を得たため、.12a/.12b 全体は未完である。** Narrowing の前提や V_Var の規則を変えずに済むものとして、範囲を狭めて完了にはしていない。二度目の停止後は反例の確定・記録・指定の検査だけを行った。

変更した既存の本番ファイルは Subst・Typing・SubstTypingObstruction と既定集約である。既存の型・構成子・判断の規則・公開署名を変更していない。新しい本番モジュールは ValueRegularity・ValueBinding・TypedFacts・TypingShift・SubstTyping・NarrowingObstruction の6個であり、既定集約からすべて読む。Git の状態変更、Rust・現行設計書・契約・計画・l00a.08/results.md の編集はない。勧告の照合と組み込まない判断も引き継ぐ。

### RV-L00a.12-stop の所見への対応

| 所見 | 変更と判定 |
|---|---|
| 重大1・重大3、中1 | `substTyValues`/`substEffValues` と substKind を bind へそろえ、値・計算・腕・節の値置換を noncomputable とした。修正後の `substituted_lambda_typed`/`substituted_return_typed` が、以前の反例の元の V_Sub/C_Sub の導出から新しい相互置換を実際に使う |
| 重大2 | `swap_injective` と `swap_latent_image`/`swap_not_canonical` を追加。単射の交換でも生の Fail 列の整列が崩れることを本番へ残した |
| 中2 | 前節のとおり、生の型注釈についての一般の WF 保存を撤回した。L00a.08 の記録は変更していない |
| 中3 | Val.rename/renameTy の動作は変更していない。`shift_values` の WF 保存は順序を保つ `shiftIndex k c` に限る。任意の単射 ξ への一般化は主張しない |
| 軽1 | 反例の行の像・WF の否定は rawBind を明示した言明に改めた。`substituted_lambda_untypable`/`substituted_return_untypable` は削除し、明示した生の注釈の `rawSourceVal` に対する `raw_lambda_untypable`/`raw_return_untypable` とした。二つの必要条件の補題は維持 |
| 軽2 | C=[] の反例の位置づけを維持し、修正後の相互置換は C を任意に量化した |

新体系の Val.subst/substTyValues/substEffValues の読者を rg で確認し、既定ビルドでも照合した。初回の反例の `rfl` の言明を上のように改めた。新体系以外で同名の旧 Release.Val.subst の計算を変えた箇所はない。

### L00a.12a で閉じた言明

| 内容 | 証拠と限界 |
|---|---|
| WF の型が Canonical であること | `Ty.canonical_of_wf`・`Ty.normTys_of_wf`。最上位の Eff.WF は整列を要求しないため、行の版は `Eff.normTys_of_wf`（Fail の各型の正規化）とした |
| 値だけの置換の WF/sort | `Ty.wf_bind_values`/`sorted_bind_values`、`Eff.wf_bind_values`/`sorted_bind_values`。内部の Bounds/BoundsList/BoundsEff は Canonical を除いた番号の上限を表し、生の値置換で上限を保つ証明と norm で WF/Canonical を作る証明を分ける。元の型の sort と、整数として読まれる位置の像の sort だけを使い、None の位置の像を整数へ制限しない |
| 自己束縛の下の環境 | `valEnv_upSubst`/`valEnv_upN`/`valEnv_upSubst_one`。k 個の束縛を越える像と up の対応 |
| 束縛下の型・行と注釈 | `Ty.bind_shiftV_values`/`Eff.bind_shiftV_values`、`Ty.bind_fn`、`HasTypeVQ.subst_lam`。本体の相互帰納でこれらを使い、注釈を `ps.map (Ty.bind (valEnv σ))` と同じ型へそろえた |
| 値を参照しない旧注釈 | `Ty.rawSubstV_embed`/`Eff.rawSubstV_embed` と列版、`substTyValues_embed`/`substEffValues_embed`。後二者は旧型/行を正規化したものの埋め込みとの一致を返す。既に Canonical である旧注釈には不変が従う。一般の「値を参照しない新型」を分類する公開述語はまだ置いていない |
| 整数 carrier の逆方向と観測 | `Ty.LeQ.integerCarrier`、`HasTypeVQ.integer_observation`/`toTerm_of_integerCarrier`。V_Sub の全 LeQ の場合を扱う |
| 型付き像から facts を得る順序 | `HasTypeVQ.assume` を型付けの導出の帰納法で先に証明し、`SubstOk.transport` がそれを使う。内部の `TypedImages.transport` は元の Γ.facts の各仮定を置換後の型の assume に移し、型付き像から導く。Typed.subst の結論を使う循環はない |
| 整数項と実際の値置換の接続 | `SubstOk.observation`。`Pred.bind_congr_sorted` は Sorted が読まない位置の像の差が述語へ影響しないことを示し、getD の整数0を意味の所属の前提にしない |
| 通常値・閉じた値の条件 | 契約の型の `SubstOk` と `ClosedTy` を定義した。SubstOk の通常値は正規化後の型付き像、継続の位置は旧第三枝に相当する閉じた契約と同じ場所・R0の条件を保つ。None は無条件。既存の valEnv は契約の ofValues の記法に相当する四欄を持ち、別の信頼条件を足していない |
| V_Sub を含む値・値列の置換 | `HasTypeVQ.subst`/`HasTypeVsQ.subst`/`HasTypeEachQ.subst`。σ : Nat→Val を任意に量化し、Φ の像の導出だけを別に受け取る。値の List/関数/場所等の像を一律に排除しない |
| Γ narrowing | 未完。後述の反例が成立する |

V_Sub の枝は、帰納仮定の型付け、型付き像から得た `Transport`、`LeQ.bind`、置換先の WF/sort を組み合わせる。型像の assume の移しは既存の `Ty.assume_bind` の包含と cut を使い、元の事実と増えた事実の等号を要求しない。Γ と Φ は構文の列のままで、意味の所属を仮定していない。

### L00a.12b で閉じた言明と残り

`HasTypeCQ.subst` は、C_Return/C_Let/C_App/C_Sub/C_Eff の全場合を、V/Vs/Each と同じ相互帰納で閉じた。R は `R.map (substTyValues σ)`、結果型・効果はそれぞれ bind による値置換とする。C_Sub は `LeQ.bind` と `Covers.bind` を使う。C_Let と V_Lam は、型付き像を捕捉の境界で隠し、値と注釈を同じ数だけ移動して帰納仮定を適用する。最小判断には局所参照を使う葉がないため、ρ は任意であり、将来の LocalSubstOk の定義を先取りしていない。

現在の最小判断に対する相互置換には未証明枝はない。一方、Γ narrowing の CQ 側は後述の反例で不成立である。`Transport.extendNone` を使う値なし束縛の専用入口は、新しい反例による停止までに追加しておらず、今回の残りである。Γ に既存の None を含む場合は SubstOk と相互置換の量化に含まれるが、それを専用入口の実装済みとは数えない。

全 canonical forms、腕・節の予約した判断、全状態・継続・ストアの置換は予定どおり L00b/L20/L40 に残る。今回の `variable_origin` と初回から維持した `lam_annotations_wf`/`return_value_typable` を、全 canonical forms の完成とは呼ばない。

最初の1時間の接続条件については、開始22:59:08から23:22:37までに新しい SubstTyping の局所ビルドが終了0となった。従って23分29秒以内に、V_Lam の枝を含む四判断の相互置換と注釈の bind との接続を確認した。これは単位ごとの能動時間ではない。

### narrowing の別の反例

[NarrowingObstruction.lean](../../../formal/Benitoite/Release/Refinement/NarrowingObstruction.lean)に、次の反例を本番へ残した。

```text
a = Cont(Unit → Unit ! empty)
b = a{true}
Γ = extend [] b
Δ = extend [] a
```

`a_wf`/`b_wf`・`a_sorted`/`b_sorted` は両型が束縛の外の空の文脈で WF/sort を満たすことを示す。`subtype_outside : LeQ [] [] a b` は self を読まない true の導入である。`source_variable` は Γ の下で var 0 : b を導く。一方、`target_variable_untypable` は任意の P/B/store/Q/C/Φ/結果型について、Δ の下で var 0 の型付けが存在しないことを示す。`source_return` と `target_return_untypable` は計算側の同じ問題を示す。

`HasTypeVQ.variable_origin` は V_Sub/V_Refine の連鎖を越え、変数の導出の元に V_Var の許す Ordinary な文脈の位置が必要なことを示す。b の最外は refined なので現行の V_Var は許すが、a の最外は cont なので拒否する。両型は閉じているため、束縛時の shift による参照順序の問題もない。`context_facts` と `facts_preserved` では Γ.facts=[true]、Δ.facts=[] から元の事実を導けることも示した。facts を移せないことが原因ではない。

これは RV-L00a.06b 軽4の「篩付きの継続の型を継続の除外が見落とす余地」に対応する。同レビューは L00a では到達しないとして L00b.02a/L10 へ送っていたが、任意の Γ を扱う今回の narrowing では現に到達する。a/b の LeQ と WF/sort だけでは指定された型付けの再構成は成り立たない。

候補は、narrowing で狭める先の位置が通常値として使用できることを明記するか、篩を除いた carrier にも継続の除外を適用するなどして V_Var/Γ の規約をそろえることである。前者は narrowing の前提の追加が契約の範囲かを確認する必要があり、後者は今回固定された規則の変更となる。いずれも実装していない。取りまとめが契約と後段の継続の判断を照合して再指定する必要がある。最初の正規化の問題は解消済みであり、この二つの停止の原因を同一に扱わない。

### 義務の段別の判定と後の段への明示的な義務

| 義務 | 継続後の .12a/.12b の判定 | 残り |
|---|---|---|
| O002 | 現在の四判断の値置換の分は閉鎖。LeQ/Covers の .08〜.10 と合成した | 新構成子と全導出は L00b/L10/L20。Γ narrowing と None の専用入口を含む .12 全体は未完 |
| O006 | σ と型注釈の外側の値への依存を除外せず、bind する値・計算の代表を閉鎖 | 全構成子の追加と全置換は後段 |
| O029 | 型付き像→facts→cut と、任意の Γ/Φ/None の既存位置に対する相互置換は閉鎖 | Γ narrowing が別の反例で停止。値なし束縛の専用入口は未実装。L00b.03/L20 の全 Γ 規約も残る |
| O031 | V_Sub/C_Sub を含む最小四判断の相互置換は閉鎖。source_v_sub/source_c_sub を実際に移した | Γ narrowing と None 専用入口を残したまま .12 全体を完了扱いにしない。L20 の全相互置換も残る |
| O010/O040 | 最初の1時間の V_Lam の接続を確認し、本番に残す証明と反例を記録 | .16a/.16b の較正では、閉じた相互置換と未完の Γ narrowing を分ける |
| O016 | 現行172公開宣言、公開化6名、変更定義7名の計185対象を実行して照合した | 旧主定理と全ての新しい葉の段末 A-L は .16a |
| O003/O029/O031 の後段の改名 | 並べ替え・縮約の生の改名に WF 保存を主張しない | L20：必要になったら正規化する改名の版を別に置き、単調な shift と区別する |
| O002/O031/O032 の後段の値置換 | 今回は項の注釈と R の値置換を bind にした | L20：ストアの型・継続の型・R・依存する後続の文脈の型の値置換も bind を通す |
| O002/O031 の範囲具体化 | 今回は項の範囲置換を実装していない | L50：範囲の具体化を項の型注釈へ適用するときも bind を通し、型の一致・整列・重複除去を保つ |

### 継続作業の検査と入力

初回の検査記録は上書きしていない。今回の全引数・終了・起点・外側の時間は [rv-stop/checks.json](rv-stop/checks.json)、実行台本は [rv-stop/run-checks.py](rv-stop/run-checks.py) に保存する。基準は引き続き `c652fa3d15f0c4a86e89250c28eccf662cb91f93`、単一の Lean は `-M 12288`、ビルドは既定の lakefile の同じ上限である。

新しい葉の最後の増分ビルドは63 jobs、終了0であった。記録用の局所ビルドはその直後の再利用であり、終了0・外側0.159842042秒である。この記録を新ソースの全コンパイルの所要時間とはしない。[rv-stop/local-build.log](rv-stop/local-build.log) に再利用した状態の出力を保存した。

署名と公理依存の検査は終了0・外側0.384909833秒。185対象の依存は propext・Classical.choice・Quot.sound の部分集合だけで、sorryAx・独自公理・未承認依存はない。[rv-stop/proof-audit.lean](rv-stop/proof-audit.lean)、[生出力](rv-stop/proof.log)、[集計](rv-stop/proof-summary.json)を保存した。新しい7モジュールの sorry/admit/axiom/native_decide/implemented_by/unsafe/partial/extern/set_option の検索は該当なし（rg の終了1）である。

work の dry-run は終了0・外側0.242483416秒、31変更ファイル、formal_build だけを選んだ。[rv-stop/dry-run.log](rv-stop/dry-run.log)に保存した。本実行は同じ指定でこの継続作業の末に一度行い、結果を下へ追記する。

途中は関係する葉だけを `lake env lean -M 12288` 又は `lake build <対象>` で確認した。失敗は、構造の ext の用意、List.map の関数の等号、束縛数の長さ、名前の解決、mutual の添字の一般化、simp が型の定義や関数合成を展開する順の調整によるものだった。新しい判断の規則・前提・結論を変更して修正していない。最後の7モジュールのビルドは警告なし。途中の全試行の時間とログは個別に採取していないため、最終検査の記録に混ぜない。

検査前の全 formal ソース（.lake を除く）・設定・契約・計画・共通依頼文・レビューの365入力の SHA-256 と大きさは [rv-stop/source-audit.json](rv-stop/source-audit.json) に保存した。これは今回変更を終えた後の入力であり、開始状態との差分の全体をハッシュだけで示した記録ではない。work 後に同じ入力が一致するか確認する。最大常駐量は **未取得（計画上の非採取）**。

### L00a.16a への継続後の申し送り

.16a は、四判断の正規化した値置換を本番の完成した補題として読める。一方、.12a/.12b 全体の受け入れと中心の補題の較正の完了は、narrowing の反例の処置と None の専用入口を閉じるまで保留である。既に閉じた相互置換を取り消す反例ではない。

| 次に必要な残り | 担当・見込み |
|---|---|
| 継続の carrier と Γ narrowing の範囲・規約の独立レビュー、再指定 | 取りまとめ・設計者。時間は不明 |
| 再指定した Γ narrowing と値なし束縛の専用入口 | .12 担当。追加の能動時間・待ち時間は現時点で不明 |
| 必要な規則・言明への追随、局所検査・公理依存・work | 再開担当。変更範囲を確定後に短い確認から見積もる |
| 全 canonical forms・腕・節・全状態 | 契約どおり L00b/L20/L40。今回の未完を完成扱いでここへ移さない |
| 段末 A-L、中心の補題の実績の集約、独立レビュー・受け入れ | .16a/.16b・取りまとめ・設計者。時間は不明 |

### 継続作業で追加・公開化した名前

現行7モジュールの公開宣言は172件である。初回の35名を維持し、新137名を追加した。初回から削除した2名と置き換え先は上の所見の対応表に記した。完全名・現行の署名は [一覧](rv-stop/public-names.json)・[初回からの差](rv-stop/public-name-delta.json)・[署名の生出力](rv-stop/proof.log)を正とする。以下は共通接頭辞 `Benitoite.Release.Refinement` を省いた、新137名の一覧である。自動生成される構造の構成子・射影・再帰子は、その構造の宣言に含める。

| モジュール | 新しい公開名 |
|---|---|
| ValueRegularity | `Ty.canonical_of_wf`、`Ty.normTys_of_wf`、`Eff.normTys_of_wf`、`termWF_of_sorted`、`Pred.wf_of_sorted`、`Ty.integerCarrier_rawSubstV`、`Ty.sorted_rawSubstV`、`sortedTys_rawSubstV`、`sortedEff_rawSubstV`、`Ty.sorted_norm`、`sortedTys_norm`、`sortedEff_norm`、`Ty.wf_bind_values`、`Ty.sorted_bind_values`、`Eff.wf_bind_values`、`Eff.sorted_bind_values` |
| ValueBinding | `Val.toTerm_rename`、`Val.observe_rename`、`SubstEnv.upN`、`renameTy_id`、`renameEff_id`、`renameTy_identity`、`renameEff_identity`、`upRen_identity`、`Val.rename_identity`、`Val.renameList_identity`、`Comp.rename_identity`、`Arm.renameList_identity`、`Clause.renameList_identity`、`upSubst_zero`、`valEnv_upSubst_one`、`valEnv_upSubst`、`upTerms_succ`、`valEnv_upN`、`Ty.rawSubstV_comp`、`substVTys_comp`、`Eff.rawSubstV_comp`、`renameTy_eq_rawSubstV`、`renameEff_eq_rawSubstV`、`Ty.bind_shiftV_values`、`Eff.bind_shiftV_values`、`Ty.bind_fn`、`valEnv_valuesOnly`、`substTyValues_eq_bind`、`substEffValues_eq_bind`、`Ty.shiftV_comm`、`Eff.shiftV_comm`、`Pred.shiftV_lift`、`upRen_shiftIndex`、`HasTypeVQ.subst_lam`、`Ty.rawSubstV_embed`、`substVTys_embed`、`Eff.rawSubstV_embed`、`substTyValues_embed`、`substEffValues_embed` |
| TypedFacts | `Ty.LeQ.integerCarrier`、`HasTypeVQ.integer_observation`、`HasTypeVQ.toTerm_of_integerCarrier`、`Pred.open_lift`、`HasTypeVQ.assume`、`termSorted_bind_congr`、`Pred.bind_congr_sorted` |
| TypingShift | `Ty.Ordinary`、`Ty.ordinary_shiftV`、`Ty.IntegerCarrier.ordinary`、`Ty.assume_ordinary`、`ShiftMap`、`renameTy_shiftIndex`、`renameEff_shiftIndex`、`ShiftMap.values`、`ShiftMap.facts`、`ShiftMap.transport`、`hideConts_lookup`、`ShiftMap.hide`、`ShiftMap.underParams`、`ShiftMap.outer`、`liftMany_eq`、`liftMany_one`、`liftMany_shiftV`、`Entails.under_params`、`ShiftMap.conditions_params`、`Ctx.mem_facts_hide`、`Entails.hideConts`、`Transport.entails`、`ShiftMap.sorted`、`ShiftMap.wf`、`HasTypeVQ.shift_values`、`HasTypeVsQ.shift_values`、`HasTypeEachQ.shift_values`、`HasTypeCQ.shift_values` |
| SubstTyping | `ClosedTy`、`SubstOk`、`SubstOk.transport`、`Ty.ordinary_bind_values`、`shiftIndex_zero`、`shiftIndex_add`、`Ty.shiftV_zero`、`Pred.shiftV_zero`、`HasTypeVQ.hide_context`、`predBind_upSubst_shift`、`SubstOk.observation`、`Const.type_bind_values`、`substEffValues_empty`、`HasTypeVQ.subst`、`HasTypeVsQ.subst`、`HasTypeEachQ.subst`、`HasTypeCQ.subst` |
| SubstTypingObstruction | `RawValueSubstCollision.rawSourceVal`、`RawValueSubstCollision.raw_lambda_untypable`、`RawValueSubstCollision.raw_return_untypable`、`RawValueSubstCollision.subst_ok`、`RawValueSubstCollision.conditions_image`、`RawValueSubstCollision.substituted_lambda_typed`、`RawValueSubstCollision.substituted_return_typed`、`RawValueSubstCollision.normalized_image_canonical`、`RawValueSubstCollision.swapIndex`、`RawValueSubstCollision.swapσ`、`RawValueSubstCollision.swap_involutive`、`RawValueSubstCollision.swap_injective`、`RawValueSubstCollision.swap_latent_image`、`RawValueSubstCollision.swap_not_canonical` |
| NarrowingObstruction | `HasTypeVQ.variable_origin`、`ContinuationNarrowingObstruction.a`、`ContinuationNarrowingObstruction.b`、`ContinuationNarrowingObstruction.Γ`、`ContinuationNarrowingObstruction.Δ`、`ContinuationNarrowingObstruction.a_wf`、`ContinuationNarrowingObstruction.b_wf`、`ContinuationNarrowingObstruction.a_sorted`、`ContinuationNarrowingObstruction.b_sorted`、`ContinuationNarrowingObstruction.subtype_outside`、`ContinuationNarrowingObstruction.context_facts`、`ContinuationNarrowingObstruction.facts_preserved`、`ContinuationNarrowingObstruction.source_variable`、`ContinuationNarrowingObstruction.target_variable_untypable`、`ContinuationNarrowingObstruction.source_return`、`ContinuationNarrowingObstruction.target_return_untypable` |

private から公開へ変えた6名は、`renameKind`、`hideConts`、`hideBuilders`、`bindParams`、`liftMany`、`localExtend` である。型と本体は変えず、同じ束縛操作を補題から使うために公開した。`substKind` は private のまま noncomputable とした。

動作を変えた既存の公開定義7名は `substTyValues`、`substEffValues`、`Val.subst`、`Val.substList`、`Comp.subst`、`Arm.substList`、`Clause.substList` である。署名・引数・既定引数は保ち、型注釈を bind で正規化する契約に合わせた。

### 継続作業末の検査と外側の時間

| 検査 | 終了 | 外側の時間 | 状態と証拠 |
|---|---:|---:|---|
| 記録用の局所増分ビルド | 0 | 0.159842042秒 | 先の63 jobs の成功後の再利用。[ログ](rv-stop/local-build.log) |
| 185宣言の署名・公理依存 | 0 | 0.384909833秒 | 新規・変更・公開化の定義を含む。[ログ](rv-stop/proof.log) |
| 同じ基準の work の dry-run | 0 | 0.242483416秒 | 31変更ファイル、formal_build だけ。[ログ](rv-stop/dry-run.log) |
| 継続作業末の work（一度） | 0 | 1.224614708秒 | 33変更ファイル、formal_build、selected checks passed。[ログ](rv-stop/work.log) |

work は、既定の `lake build` の8ターゲットと sorry の拒否を実行した増分ビルドである。約1.22秒を全ソースの再コンパイル時間とはしない。dry-run と work の差の2ファイルは dry-run.log と public-name-delta.json の追加である。Rust の lib/統合テスト・全比較・段末の全 A-L を追加していない。初回の work とは別に、今回の変更後の状態で一度だけ実行した。設定上限・期待値・警告を緩めていない。

work 後の365入力のハッシュの一致も確認した。確認時計23:33:35まで、開始22:59:08からの共通区間の外側の時間は **34分27秒** である。この後の報告の執筆は含まない。能動時間と待ち時間、.12a/.12b の各単位の時間は分離不能である。1.5〜3時間の目安や上端の2倍の6時間に達しておらず、時間による停止ではない。narrowing の型付けの再構成の反例による停止である。最大常駐量は **未取得（計画上の非採取）**。

修正後の独立レビューと受け入れは未実施である。narrowing を通常値の位置に限る等の前提の追加や V_Var の規則変更を、担当の裁量で加えて完了とはしない。取りまとめによる契約の再指定を要する。

## 二度目の停止への対応

2026-10-30、継続作業（2）の開始時計は23:37:07 +09:00。取りまとめが改訂した契約に従い、`Ty.WF` の refined の場合へ、担い手の芯が cont でない条件を加える。主定理の署名と前提・結論は保つ。

芯は `Ty.core : Ty → Ty`、除外の条件は `Ty.NotContCore : Ty → Prop` とする。公開の narrowing は、外側で検査した `LeQ Γ Φ a b` と元の b の WF/sort から一つの束縛を狭め、後続の値/None の束縛を保つ `Ctx.Narrows` と、その導出の帰納法で構成する V/Vs/Each/C の `.narrow` とする。通常値への新しい制限を前提として追加しない。Transport へ narrowing 自体を仮定として登録せず、V_Sub に必要な変数の型付けと facts を補題で構成する。

値なし束縛の予定する公開入口は `SubstOk.transport_extendNone` と四判断の `.subst_under_none` である。前者は既存の `Transport.extendNone` を使い、`valEnv (upSubst 1 σ)` へ環境をそろえる。後者は親の SubstOk と Φ の像を受け取り、Γ.extendNone / Δ.extendNone、lift した Φ/Ξ と upSubst の下で同じ型付けの置換を返す。

### WF の改訂と既存の補題への追随

`Ty.core` は、最外の refined を繰り返し除き、子の型には入らない。`Ty.NotContCore a` は、a.core が cont でないことを表す。新しい WF の refined の場合は、担い手 a の WF、p の参照の上限、a.NotContCore の三条件である。WF の引数・型の構成子・最上位の行の Canonical の扱いは変えていない。Ty.WFList/Eff.WF は同じ再帰で改訂した Ty.WF を読む。

`Ty.notContCore_norm`・`notContCore_shiftV`・`notContCore_shiftTypes`・`notContCore_rawSubstV` により、正規化・単調な値の移動・型の番号の移動・値だけの置換が芯の条件を保つ。ShiftOrder の wf_shiftV、TypeSubst の wf_shiftTypes_norm、ValueRegularity の内部の Bounds と norm/WF の証明をこの条件へ追随させた。embed_wf は旧型に refined がないため、言明・証明を変更せずに再検査できた。

`Ty.NotContCore.ordinary`、`Ty.notContCore_of_wf_ordinary`、`Ty.LeQ.notContCore` を閉じた。これにより、元の b が WF で、V_Var が使える位置なら、b の芯は継続型でない。外側の LeQ a b はその性質を a へも保つため、狭めた位置でも V_Var が使える。**V_Var の継続の除外の規則と、Ty.Ordinary の定義は変更していない。** narrowing に a.Ordinary を新しい前提として加えていない。

OpenSubstitution と SubstTypingObstruction の正の例は、新しい WF の芯の条件を明示して通し直した。最初の正規化の反例は引き続き rawBind に対する回帰例として有効である。二度目の narrowing の反例では、以前の `b_wf` を削除し、`b_not_wf` と `nested_not_wf` を置いた。これらは任意の nr/nt/nv で cont を芯に持つ篩が WF を満たさないことを示す。source_variable/source_return の導出自体は、WF でない文脈を渡せば構成できる例として残るが、narrowing の元の b の WF の前提を満たさないため、改訂後の反例にはならない。

### narrowing の全入口

[Narrowing.lean](../../../formal/Benitoite/Release/Refinement/Narrowing.lean) の `Ctx.Narrows` は、次の三つだけから文脈の対応を作る。

- `here`：束縛の外の Γ/Φ における LeQ a b と、元の b の WF/sort から、Γ.extend b を Γ.extend a に狭める。
- `under`：その対応の内側へ同じ型の値の束縛を足す。
- `underNone`：その対応の内側へ None の束縛を足す。

この導出の帰納法で、private の ContextMap を構成する。ContextMap は、長さの一致と、元の各使用可能な変数を元の型で型付けする導出を持つ。最初の位置は新しい変数の V_Var と、外側で検査した LeQ を移動した V_Sub で再構成する。他の位置の番号と型、後続の None、Φ の位置は保つ。

facts の移しは、再構成した型付き変数の `HasTypeVQ.assume` とその V_Sub の枝の `Ty.LeQ.assume` を使って構文の含意を導く。元の各事実を行き先で証明するので、増えた事実との等号は要求しない。ContextMap.values/sorted は整数として読まれる位置と型の sort を保存し、長さが同じなので既存の参照の上限も保つ。narrowing 自体を未検査の Transport の前提に登録していない。

そこから値・値列・同型の値列・計算の相互の文脈変更を証明し、公開の `HasTypeVQ.narrow` / `HasTypeVsQ.narrow` / `HasTypeEachQ.narrow` / `HasTypeCQ.narrow` を閉じた。V_Sub/C_Sub、V_Lam の捕捉、C_Let の束縛、V_Refine の sort と含意の枝も対象である。Γ/Φを空に限定していない。構文の項・元の結果型・効果・R・局所参照の文脈を変えない。

### 値なし束縛と値を参照しない注釈

`SubstOk.transport_extendNone` は、親の型付き像から構成した Transport に、既存の `Transport.extendNone` を適用する。valEnv_upSubst_one により、束縛下の環境と同じ型にそろえる。None の位置へ型付き像や事実を仮定せず、0番を値として読ませない。新しい四判断の `.subst_under_none` は、この移送の証拠と親の型付き像を使う専用の入口である。親の Φ の像は従来どおり別に受け取り、外部の意味の所属は要求しない。

前の依頼で求められた値非依存の注釈の不変も明示した。`Ty.rawSubstV_of_wf_zero`・列と行の版は、値の自由参照がない（nv=0 の WF）注釈の生の置換が恒等であることを示す。self の束縛は残す。`Ty.subst_values_of_wf_zero` は WF から Canonical を使い、正規化する値置換でも同じ型を返すことを示す。最上位の行の版 `Eff.subst_values_of_wf_zero` は、行の既存の Canonical を別に要求する。最上位の Eff.WF だけが整列を含意するとはしていない。先に置いた旧構文の埋め込みとの一致と併せて、型注釈の恒等性の接点を閉じた。

### 実際の導出による代表

SubstTypingObstruction の `NarrowingExample` は、外側に Integer{self=7} と None、その内側に狭める束縛を持つ。元の位置の型は Integer{self=7}、狭める先はそれへ true の篩を重ねた型である。`source_le` は Γ.facts の等式を実際に使う introduce であり、`source_value`/`source_comp` は V_Sub/C_Sub の導出を持つ。`narrowed_value`/`narrowed_comp` は新しい narrowing を適用し、`narrowed_under_none` はさらに None の後続を越える。

RawValueSubstCollision の `substituted_lambda_under_none` と `substituted_return_under_none` は、空でない facts/Φ と篩付きの変数の像を使い、四判断の専用入口のうち値・計算の入口を実際に適用する。元の V_Sub/C_Sub を含む相互置換の正の例も維持した。空の判断や、事実を使わずに並べただけの代表で完了とはしていない。

### L00a.12a・L00a.12b の全体の判定

**実装担当の自己判定は、現在の最小構文について .12a/.12b とも完了・受け入れ可能である。** 過去の二つの停止の原因は、改訂された契約の範囲で処置した。修正後の独立レビューと設計者の受け入れは未実施であり、この自己判定とは区別する。

| 単位 | 閉じた内容 | その単位の未完 |
|---|---|---|
| L00a.12a | 型付き像から facts を得る cut、整数観測と実際の値置換、WF/sort、V_Sub を含む値・値列の置換、Γ narrowing、値非依存の注釈の不変 | 現在の最小構文にはなし |
| L00a.12b | V/Vs/Each/C の相互置換、C_Sub/C_Eff と C_Let/V_Lam の束縛、CQ を含む narrowing、Transport.extendNone を使う四つの専用入口 | 現在の最小構文にはなし |

全 canonical forms、全sort、依存 Tel、全ての腕・節、保持値・ストア・継続・状態の構成子を追加した後の置換・narrowing は、契約どおり L00b/L10/L20/L40 以降に残る。予約した腕・節の判断を完成したものに数えていない。Rust/Lean の全比較も今回の成果に含めない。

| 義務 | 今回までの .12a/.12b の判定 | 後段へ残る内容 |
|---|---|---|
| O002 | 最小構文の値型付け・計算型付けと、LeQ/Covers の導出を合成する部分を閉鎖 | L00b/L10 の追加構成子、L20 の全導出 |
| O006 | 外側の値を読む型/行の像を除外せず、型付き像から facts を導く接続と代表を閉鎖 | 全構成子・全置換の追随 |
| O029 | 構文の Γ/facts/Φ、cut、WF/sort と参照位置の保持、Γ narrowing、None の専用入口を閉鎖 | L00b.03 の全 Γ 規約・依存列、L20 の全状態 |
| O031 | 本番 Nat の V_Sub/C_Sub を含む四判断の相互置換と narrowing を閉鎖 | L20 の全判断の相互置換 |
| O010/O040 | 本番に残す中心の補題と代表、通常記録の外側の時間を保存 | .16a/.16b の較正・外挿と独立レビュー |
| O016 | WF の定義を含む382対象の署名・公理依存を実行して照合 | .16a の旧主定理と新しい葉全体を含む段末 A-L |
| O003/O029/O031 の改名 | 生の WF 保存は shiftIndex の単調な移動に限る | L20 の並べ替え・縮約には正規化する改名の版を置く |
| O002/O031/O032 の値置換 | 項の注釈・今回の R の値置換は bind を使用 | L20 のストアの型・継続の型・後続の文脈の型も bind を使用 |
| O002/O031 の範囲具体化 | 型の既存の範囲置換を壊していない | L50 で項の型注釈へ当てるときも bind を使用 |

### 今回の検査と記録の範囲

今回の記録は [wf-core/](wf-core/) に分け、初回と継続作業（1）の記録は上書きしていない。基準は `c652fa3d15f0c4a86e89250c28eccf662cb91f93` のままである。全コマンド・起点・終了・開始時刻・外側の時間は [checks.json](wf-core/checks.json)、実行台本は [run-checks.py](wf-core/run-checks.py) にある。

| 検査 | 終了 | 外側の時間 | 証拠 |
|---|---:|---:|---|
| 記録用の局所増分ビルド | 0 | 0.158540375秒 | [ログ](wf-core/local-build.log)。先の64 jobs の成功後の再利用 |
| 382対象の署名・公理依存 | 0 | 0.434670667秒 | [入力](wf-core/proof-audit.lean)・[生出力](wf-core/proof.log)・[集計](wf-core/proof-summary.json) |
| 同じ基準の work の dry-run | 0 | 0.113945625秒 | [ログ](wf-core/dry-run.log)。47変更ファイル、formal_build だけ |
| 今回の作業末の work（一度） | 0 | 0.924291125秒 | [ログ](wf-core/work.log)。48変更ファイル、formal_build、selected checks passed |

既定の lake build は8ターゲットの増分ビルドであり、新しい葉は局所ビルドで作成済みの状態を再利用した。約0.92秒を全ソースの再コンパイル時間とはしない。work は sorry の拒否も実行した。dry-run と work の差の1ファイルは dry-run.log の追加による。公理依存は今回対象の14モジュールの公開378宣言と、Ctx.Narrows の here/under/underNone/rec の4宣言を照合した。公開化・変更した定義も378件に含む。依存は propext・Classical.choice・Quot.sound の部分集合だけで、sorryAx・独自公理・未承認依存はない。

Lean の一ファイルの検査は `-M 12288`、ビルドは既定の lakefile の同じ上限で行った。Refinement 全体の sorry/admit/axiom/native_decide/implemented_by/unsafe/partial/extern/set_option の検索は該当なし（rg の終了1）。最終の局所ビルドと新しい証明の警告はない。最大常駐量は **未取得（計画上の非採取）**。Rust の lib や統合テスト、形式化の全比較を追加していない。

途中は、追加した WF の三つ目の条件への射影、自己再帰する補題での simp の順、identity の環境を rawBind_id にそろえる形、帰納法の名前の指定、代表の P/B/store/Q の推論の明示を直した。これらの局所検査の失敗を、新しい反例や主定理の変更で回避していない。途中の各試行の時間・生出力は個別に採取していないので、上の最終検査の時間へ混ぜない。

検査の入力366件の SHA-256 と大きさは [source-audit.json](wf-core/source-audit.json) に保存し、work 後に一致を確認する。対象は .lake を除く formal の全ソース、lakefile/manifest/toolchain、check.sh、共通依頼文・計画・契約と停止時のレビューである。開始状態との差分をハッシュだけで証明した記録ではなく、今回の最終の入力を検査した証拠である。

### L00a.16a への最終の申し送り

.16a は、修正後の四判断の相互置換・narrowing・None の専用入口を、本番に残した中心の補題として使用できる。二つの古い停止時点の「未完」を現行の状態と混同せず、本節の判定と今回の検査を読む。修正後の独立レビューでは、WF の芯の除外、V_Var を変えずに成立する narrowing、Γ/Φ の型付き像からの構成、全四判断の前提・結論を確認する必要がある。

段末の A-L と限定 RSS の採取、中心の補題の実績の集約、.16b の独立レビュー・設計者の受け入れは、取りまとめの予定どおり残る。今回の最大常駐量の未取得を測定済みとせず、.16a の最後の work へ取りまとめが採取を付ける。全構成子の追加時は、今回の補題の該当する場合と、正規化する値/範囲の置換の規約も同じ作業で追随する。

取りまとめの追記（2026-10-31、[RV-L00a.12](../reviews/RV-L00a.12.md) に従って）: 後の段の義務として次を加える。(1) L20/L40: 継続を束縛する節の下の `SubstOk.up`（今の SubstOk の継続の枝は「σ i が場所 l」だけで、旧 Release の改名の枝 `σ i = var j ∧ Δ[j] = x` がない。改名の枝を足すか内部の不変条件を公開する）。(2) L10/L20: 型置換の WF の保存を言明するとき「型の像に継続の型を含まない」前提を置く（`refined (tvar i) p` の tvar を継続の型で置き換えると WF でない。01-12 は型引数に継続の型を書けないと定めるので、利用者の形は狭まらない）。(3) LeQ を拡張するとき、narrowing に要る一方向（b の芯が cont でなければ a の芯も cont でない）を保つ（今の `LeQ.notContCore` は iff）。(4) L20: 文脈の WF を不変条件に置く（V_Var と hideConts は最外の cont だけを見るので、WF でない Γ の `Cont{true}` は今も変数として型付けされる）。設計書へ反映するとき、01-12 の整形式へ芯の条件を書く。(5) 次に `Subst.lean` を触る作業: 値置換が注釈を bind で正規化し改名は生のままにする理由を docstring に書く。

### 今回追加した公開名

既存の private を新たに公開へ変えたものはない。新しい公開宣言は49件である。完全名は [今回の差](wf-core/public-name-delta.json)、対象14モジュールの現行の一覧は [public-names.json](wf-core/public-names.json)、型と依存は [proof.log](wf-core/proof.log) に保存した。共通接頭辞 `Benitoite.Release.Refinement` を省いた一覧を次に示す。

| モジュール | 新しい公開名 |
|---|---|
| Context | `Ty.core`、`Ty.NotContCore`、`Ty.notContCore_norm`、`Ty.IntegerCarrier.notContCore`、`Ty.notContCore_shiftV` |
| TypeSubst | `Ty.notContCore_shiftTypes` |
| ValueRegularity | `Ty.notContCore_rawSubstV` |
| ValueBinding | `Ty.rawSubstV_of_wf_zero`、`substVTys_of_wf_zero`、`Eff.rawSubstV_of_wf_zero`、`Ty.subst_values_of_wf_zero`、`Eff.subst_values_of_wf_zero` |
| TypingShift | `Ty.NotContCore.ordinary`、`Ty.notContCore_of_wf_ordinary`、`Ty.LeQ.notContCore`、`ShiftMap.outerNone`、`Entails.under_none` |
| SubstTyping | `SubstOk.transport_extendNone`、`HasTypeVQ.subst_under_none`、`HasTypeVsQ.subst_under_none`、`HasTypeEachQ.subst_under_none`、`HasTypeCQ.subst_under_none` |
| Narrowing | `Ctx.Narrows`、`Ctx.Narrows.conditions`、`HasTypeVQ.narrow`、`HasTypeVsQ.narrow`、`HasTypeEachQ.narrow`、`HasTypeCQ.narrow` |
| SubstTypingObstruction | `RawValueSubstCollision.substituted_lambda_under_none`、`RawValueSubstCollision.substituted_return_under_none`、`NarrowingExample.outer`、`NarrowingExample.Φ`、`NarrowingExample.narrowTy`、`NarrowingExample.source`、`NarrowingExample.target`、`NarrowingExample.result`、`NarrowingExample.original_wf`、`NarrowingExample.original_sorted`、`NarrowingExample.narrows`、`NarrowingExample.source_le`、`NarrowingExample.result_wf`、`NarrowingExample.result_sorted`、`NarrowingExample.source_value`、`NarrowingExample.narrowed_value`、`NarrowingExample.source_comp`、`NarrowingExample.narrowed_comp`、`NarrowingExample.narrowed_under_none` |
| NarrowingObstruction | `ContinuationNarrowingObstruction.b_not_wf`、`ContinuationNarrowingObstruction.nested_not_wf` |

このほか Ctx.Narrows の here/under/underNone/rec の生成される4宣言も公理依存を照合した。以前の `ContinuationNarrowingObstruction.b_wf` は偽となるため削除し、`b_not_wf`/`nested_not_wf` へ置き換えた。変更した WF の定義の型は保った。Ty.WF 本体の変更に加え、それを読む Ty.WFList/Eff.WF も監査の対象へ含めた。

今回の開始時計23:37:07から、work 後の入力照合時計23:57:36までの外側の時間は **20分29秒** である。この後の報告の執筆は含めない。能動時間と待ち時間、.12a/.12b の各単位の時間は分離不能である。今回の1〜2時間の目安の上端の2倍には達していない。最大常駐量は **未取得（計画上の非採取）**。過去の停止の区間を成功した証明だけの時間として混ぜず、.16a は三回の記録を区別して集約する。

work 後の366入力のハッシュは検査前と一致した。その後の追記は結果の文書と公開名の一覧だけであり、Lean ソース・設定は変更していない。相互置換・narrowing・値なし束縛の最小構文について未完はない。次に残る独立レビューと設計者の受け入れは、実装担当の自己判定とは区別する。

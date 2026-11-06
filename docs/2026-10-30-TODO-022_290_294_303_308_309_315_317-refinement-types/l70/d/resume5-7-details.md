# 再開5〜7の詳細

## 再開5（範囲パラメータを持つ利用者の関数）

### 判定と基準

**停止。三つの形の規則と全具体化の性質1は未完である。** 最初の接続の確認で、現在の表層の導出と値の置換の仮定からは範囲の全具体化の型付けが従わない反例を得た。組込みの型引数の許容を、開いた範囲文脈でどう要求するかという型付けの規則の変更を、取りまとめへ返す。停止の根拠・完全な言明・差・代案・所要と実用への影響は [resume5-obstruction.md](resume5-obstruction.md) に記した。

ブランチは `m014/l70.d2`、B_WORK と開始時の HEAD は `e70794188e24de95b5bb424f9d75090f77d1c703` で一致した。開始時に作業木の差分はなかった。ブランチの切り替え・作成・コミット・その他の Git の状態の変更を行っていない。以後の照合の台本は Git を呼ばない。共通依頼文の勧告の照合の引継ぎを使い、依存やツールチェーンを変更していない。`scripts/check.sh` と Rust の検査は実行していない。

### 最初の接続の確認

核の `RangeTyping` の十四判断は全適格具体化の量化であり、`TelBodyTyR` の前提を表層へ移すだけでは要求された性質1にならないことを確認した。表層の構造的な導出から具体化後の本体を得るため、葉の許容判定の保存を調べた。

`PrimSig.admits` は任意の述語であり、`Builtins.ValueAssumptions` が要求するのは値の改名・値の置換による保存だけである。範囲の具体化による保存は含まれない。範囲変数を関数型の効果に持つ型引数を一個だけ使い、既存の値の置換の仮定の全4欄を満たす表で、具体化後に許容が失われる例を Lean で証明した。

反例の完全名は `Benitoite.Release.Refinement.Surface.RangeAdmissibilityExample.existing_premises_insufficient` である。この例は、宣言の対応・値の置換の仮定・表層の `BodyTy`・範囲深さ1での脱糖したソースの形成・`RangesFit [RangeExpr.top] [.path]` と、具体化後の核の `TelBodyTy` の否定を同時に構成する。組込みの値の反転 `HasTypeVQ.inv_prim` から許容の前提を取り出すので、否定は任意の結果型で成り立つ。合成表の実在する組込みの不具合や、現在の `desugar_typed` の反例を主張するものではない。

依頼の「止める条件」の「型付けの規則の変更」に従い、許容の前提の変更を入れる前に止めた。範囲の量化を定理の署名へ足すことと、単一の許容判定を全具体化についての許容という規則の前提に変えることを区別した。発行専用の節に限る拒否の例外を、許容判定の変更へ広げていない。

### 三つの形と受理・拒否の例

| 対象 | 今回の判定 | 残るもの |
|---|---|---|
| 範囲パラメータを持つ関数の参照と直接の呼出し | 未実装。試した範囲引数の欄と閉じた呼出しの変更は、停止時に開始時の内容へ戻した | `CallHeadTy.fn`・`fnDicts`、指定の6規則、fn・fnDicts の性質1の場合と、開いた型・行引数の許容の受け持ち |
| 範囲パラメータを持つ関数の定義 | 未実装。既存の `Def.WellTyped`・`BodyTy` と脱糖を保つ | 範囲文脈での有限の表層の導出と、任意の適格な具体化の `TelBodyTy` を得る性質1、`FunDecl.rangeParams` の読み出しと `Def.rkinds` への写し |
| 開いた範囲を型の別名へ渡す R5 | 未実装。既存の閉じた範囲での一般の展開の言明を保つ | 開いた範囲の引数・展開・注釈の形成と性質1への接続 |
| 関数から関数への `.rvar`、host・endpoint の組込みへの転送、path の別名の注釈の受理例 | 未追加 | 三つの形の実装とともに既定ビルドへ置く |
| 発行専用の組込みを処理する節の拒否規則と例 | 未追加。途中で試した拒否の前提は戻した | 指定された例外の範囲での拒否と、他の節の受理の対照 |

要求された正の全具体化の補題は、証明・追加していない。既存の表層の本体の判断をそのまま用いる一般化の不成立を、上記の否定の証人で示した。現在の表層の規則・提供範囲・主な十言明を変更していない。新しい公理・独立の信頼条件・精密な外部状態・既定 import からの除外はない。

### 残した変更と主な定理の差

残したソースの変更は、新しい `Surface/RangeAdmissibilityExample.lean` と、既定の `Surface/Examples.lean` の import 一行だけである。新モジュールは20定理と、それらが読む表・型・本体の定義を持つ。private の補助にも本番の読者がある。試した構文・規則・脱糖・性質1の変更は開始時のバイト列へ戻し、保護範囲の指紋で照合した。核の直下・旧 Release・群 B・C・F1・K と処理系を変えていない。

01-12 と07-04の写しには、値の置換の仮定が要求する許容の保存の範囲と、追加した反例の言明・モジュールの対応だけを記した。新しい表層の規則や全具体化の証明を実装済みとは記していない。

既存の言明に差がある行は0件である。266件の署名の台帳と、結合で増えた2件を含む開始時の全268定理を区別して照合する。今回の差の表は次のとおりである。

| 宣言 | 元の言明 → 残した言明 | 判定 |
|---|---|---|
| `Surface.desugar_typed` | 同じ | 変更なし |
| `Surface.HasTypeQ.desugar` と式・文・腕・節などの性質1 | 同じ | 変更なし |
| `Surface.BodyTy.desugar`・`Def.WellTyped.desugar`・`ImplDecl.WellTyped.desugar` | 同じ | 変更なし |
| `Surface.AliasDecl.expand_annotation` と別名の形成の諸定理 | 同じ | 変更なし |
| `Surface.Declarations.realizes_no_ranges`・`desugarProgram_ranges` | 同じ | 結合で追加された2定理も変更なし |

主定理の前提を追加したり、`ValueAssumptions` に範囲の保存の仮定を足したりしていない。旧署名へ戻すための新しい系は不要である。

### 例の作成時の関門

| 関門 | 答え |
|---|---|
| 守る境界 | 表層の本体の導出と既存の値の置換の仮定から、範囲の全具体化の核の型付けが従うかという論理上の境界 |
| 捕まえる誤り | 範囲を含む型引数の許容が自動的に具体化で保存されるとして性質1を一般化すること |
| 既存の例との差 | 群 K の範囲変数の転送は型・行引数が空の例が中心であり、任意の `admits` を持つ表への一般化を検査しない |
| 差し込み口 | 追加していない。既存の表・表層の規則・核の反転を使う。表の例は既存の仮定を実際に満たす |

### 計画からのずれと取りまとめへの判断

依頼された規則・全具体化の性質1・受理例・発行専用の節の拒否を完了せず、最初の接続の確認で停止した。時間の上限による停止ではない。許容の前提の変更を未承認の型付けの規則の変更として扱ったことが、停止の理由である。見込みの5時間と上限10時間には達していない。

取りまとめには、[停止の文書](resume5-obstruction.md)の案 A、すなわち、表層の開いた導出の葉で組込みの `admits` と関数の制約の照合を範囲文脈に応じて要求する規則を、今回の追加の範囲に含めてよいかを確認してもらう。核や主定理の信頼条件を増やさず、範囲のない系を保つ案を推す。表層の導出全体を全具体化の核の型付けという前提で置き換える案ではない。許容の完全署名と最初の保存の接続の確認は30〜60分、以後の全場合・検査・レビュー・受け入れを含む総所要は不明である。

### 作業末の検査

ビルド・監査・照合の結果と単位ごとの外側の時間は、検査を終えた後に下へ追記する。能動時間と待ち時間は分離していない。最大常駐量は計画上の非採取である。


既定ビルドと公理監査は、指定された共有ロックに対する `lockf -t 3600 <共有ロック> <コマンド>` の下で、`formal/` を作業ディレクトリとして各一度実行した。`lake build` に対象を指定していない。ビルドの開始は共有ロックの取得待ちを含み、待ちの原因を読み取りで確認したところ、並行の群 E の検査がロックを保持していた。プロセスを止めていない。

| 検査 | ロック内のコマンド又は照合の入口 | 開始〜終了（JST） | 外側の時間 | 結果 |
|---|---|---|---:|---|
| 全既定対象のビルド | `lake build` | 16:14:06〜16:25:54 | 707.556秒（共有ロック待ちを含む） | 終了0、1,384ジョブ。追加・変更した2モジュールの警告なし |
| 変更モジュールの全宣言の公理監査 | `lake env lean -M 12288 ../<改造>/l70/d/axioms.lean` | 16:27:04〜16:27:29 | 25.448秒 | 終了0、289宣言、private 153件と生成宣言を含む |
| 台帳・記録・本番の照合 | `python3 <改造>/l70/d/verify.py --tmp <tmp>` | 16:27:59〜16:28:00 | 0.995秒 | 一度実行し終了0。266署名の台帳・全268既存定理・追加20定理・全宣言・既定 import・保護範囲・記録の大きさを照合 |

ビルドと監査の前後の1,137入力の指紋は、いずれも `e26cdb09a41701506d163757ccea835bf961606bc96e435da5a190db8a8de421` で一致した。監査は既定環境から変更した2モジュールの全宣言を所属モジュールで選び、private と印字時に実体化する生成宣言を固定点まで列挙した。新モジュール142宣言、既存の Examples 147宣言である。公理なし123件、propextだけ73件、propextとQuot.soundの二つ1件、propext・Classical.choice・Quot.soundの三つ92件で、新公理・sorryAx・三公理の外の依存は0件だった。主な十言明と、今回変更していない核の全宣言を再監査したという意味ではない。

監査対象の一覧は `audit-modules.json`、必須の名前は `required-names.json`、再生成する入口は `verify.py --write-modules` と `axioms.lean` である。全宣言の整列した名前の列は27,724バイト、SHA-256 `a38b1d47c90d05ab07cf091598f406959283ad3242bac40785ed28c425d715be`。宣言の生の写しは改造に追加せず、群末の一回分の要約を `resume5-verification.json` に置いた。開始時の個別・保護範囲の集約の指紋は `resume5-baseline.json`、全268既存定理の署名のハッシュは `resume5-signatures.json` である。属性と括弧の深さを読む抽出器の自己検査8例も照合時に実行した。

| 生出力（いずれも一時領域に保存） | 大きさ | SHA-256 |
|---|---:|---|
| ビルド | 186,284バイト | `b727abf90fab0a3508e7b076a2d3a364e40b9d3afe1d9494496447412e53b7d4` |
| 公理監査 | 130,636バイト | `ecf5603b40191de93195bb25e8b10fa05a10b93a10f620e5f5ddeab2ba83b82e` |
| 照合 | 1,000バイト | `b84874f27ac841bafb258fea5b28c76a5b7a8b86e6223991113de8719f52544f` |

局所の単独 Lean は `lake env lean -M 12288` を一度に一つだけ実行した。反例の初稿では、予約語を補題名に使ったこと、効果の射影の指定、空の列の暗黙引数と形成の証明の不足を直した。既定ビルドの前に最終のソースが終了0・警告なしで検査を通ることを確かめた。途中の表層の候補を局所検査した際の証明の不足も、候補を残したまま未完とはせず、開始時のソースへ戻した。既定ビルド・公理監査・作業末の照合の失敗と再実行はない。`verify.py --write-modules` は最終実行の前の対象の一覧の準備であり、最終検査の代わりにはしていない。

### 単位ごとの所要

最初に取得した時刻以後の外側の経過を示す。能動時間と待ちを分離していない。ビルド待ちの間に停止の文書と結果を書いており、その時間を別に加算しない。

| 単位 | 開始〜終了（JST） | 外側の時間 |
|---|---|---:|
| 資料読み・範囲引数の候補・許容の保存の検討 | 15:46:57〜16:02:12 | 15分15秒 |
| 反例の定式化・局所検査・候補の復元・写し | 16:02:12〜16:11:26 | 9分14秒 |
| 監査・照合台本と指紋の準備 | 16:11:26〜16:14:06 | 約2分40秒 |
| 共有ロック待ち・既定ビルド・並行して停止の文書と結果を記録 | 16:14:06〜16:25:54 | 707.556秒 |
| ビルド結果の読み取り・監査の準備 | 16:25:54〜16:27:04 | 約1分10秒 |
| 全宣言の公理監査・照合・結果の読み取り | 16:27:04〜16:28:00 | 約56秒 |
| 最終の結果の追記 | 16:28:00〜16:29:20 | 約80秒 |

記録時刻: 2026-11-06T16:29:20+09:00。初回に取得した時刻からの外側の経過は約42.4分である。終了後に変更したのはこの結果の追記だけで、検査したソース・写し・仮定・証明を変えていない。検査の成功を、三つの形の実装・全具体化の性質1・独立レビュー・受け入れの完了とは判定しない。

## 再開6（範囲パラメータを持つ利用者の関数、案 A）

### 判定と基準

**停止。依頼された三つの形の規則と全具体化の性質1は未完である。** 案 A の許容と制約の照合を常に真にした表でも、使用する組込みの署名自身の範囲の有効範囲がなければ、具体化後の本体の型付けが従わない反例を確認した。署名の有効範囲の条件を葉に追加することは、今回の例外である `PrimSig.admits`・`B.sat` の前提の追加とは別の規則変更として扱い、その条件を足す前に止めた。根拠・完全な言明・必要な差・代案・所要と実用への影響は [resume6-obstruction.md](resume6-obstruction.md) に記した。

ブランチは指定された `m014/l70.d2` のまま、B_WORK と `git rev-parse HEAD` は `e70794188e24de95b5bb424f9d75090f77d1c703` で一致する。再開5の未コミットの差分は保った。git の切替・作成・コミット・その他の変更操作、`scripts/check.sh` は実行していない。private/AGENTS.md はこの作業木にない。

### 足した反例と性質1の停止箇所

`Surface/RangeSignatureExample.lean` を追加し、`Surface.Examples` から既定 import へ接続した。名前空間は `Benitoite.Release.Refinement.Surface.RangeSignatureExample`。再開5の反例のモジュールは変更せず、空のプログラム・宣言の表と、`Read[ρ₀]` を潜在効果に持つ関数型 `argument` を再利用した。

反例の組込み `probe` は型・行・範囲のパラメータと値引数が空で、結果が `Reference[argument]`、効果が空の署名を持つ。`admits` と `sat` は常に真である。`values` は既存の `Builtins.ValueAssumptions` を満たし、`surface_typed`・`body_typed` は既存の表層の規則から参照と本体を型付ける。`code_sourceScoped`・`telescope_sourceScoped` は、脱糖した本体と依存列を呼出し元の範囲深さ1で形成できることを示す。しかし `signature_not_scoped` が示すとおり、組込みの署名は自身の範囲深さ0では形成されない。

`probe` の空の実引数列は具体化で変わらず、核の型付けは表にある元の署名を読む。期待する結果型の `Read[ρ₀]` だけを `Read[Top]` に替えても、元の参照型の内容との不変性を満たさない。`instantiated_value_rejected` は `HasTypeVQ.inv_prim`・`TelClosure.done_outputs`・`Ty.LeQ.refCore` で全ての型付けの導出を否定する。`instantiated_body_rejected` は本体の判断からこの値の判断を取り出す。字面の不一致だけで型付けの不成立を代用していない。

全具体化の保存の補題は未実装であり、完成した完全名はない。代わりに、その導出に必要な前提の不足を次の完全名で示した。

```lean
Benitoite.Release.Refinement.Surface.RangeSignatureExample.admissibility_premises_insufficient
```

言明は [停止の文書](resume6-obstruction.md#否定の証明) と本番に同じ形で記した。宣言の対応、値の置換の仮定、許容と制約の全具体化、表層の本体の型付け、範囲深さ1での本体と依存列の形成、適格な具体化と、具体化後の核の本体の型付けの不成立を同時に示す。新しい開いた導出の反例や、現在の範囲のない `desugar_typed` の反例とは呼ばない。

### 三つの形と受理・拒否例の判定

| 依頼された形・規則 | 本再開の判定 | 性質1の場合 |
|---|---|---|
| 関数の参照と直接の呼出し。`CallHeadTy.fn`・`fnDicts` と `E_Fun`・`E_FunDicts`・`E_CallDirect`・`E_PipeCallDirect`・`E_PipeApplyDirect`・`E_PartialCallDirect` | 未実装。範囲の具体化の列を追加する前に停止 | `CallHeadTy.app_value`・`glue` と6規則の追加の場合は未完 |
| 範囲パラメータを持つ関数の定義。`Def.WellTyped` と `FunDecl.rangeParams` の読み出し | 未実装。既存の型付けと脱糖は変更していない | 開いた本体の導出から全適格具体化の `TelBodyTy` を作る補題は未完 |
| 関数の範囲を別名へ渡す R5 | 未実装。`AliasDecl.expand_annotation` など既存の署名は保った | 開いた範囲を渡す形成の補題は未完 |
| 関数間の `.rvar` の転送、host・endpoint の組込みへの転送、path 範囲を別名へ渡す受理例 | 未実装 | 受理の証人を追加したとは判定しない |
| 発行専用の組込みに対する節の拒否 | 未実装。`HasClausesQ.cons` など既存の規則は保った | 新しい拒否規則と拒否例は未完 |

既定ビルドに追加した受理と拒否の対照は、同じ `probe` の本体の具体化前の型付けと、具体化後の期待型での型付けの否定である。発行専用の節を拒否したという意味ではない。

### 群 D の言明の差の表

| 入口 | 元の言明 | 本再開の言明・差 | 範囲なしの系 |
|---|---|---|---|
| `desugar_typed` | 表層の整形式・型付け・`ValueAssumptions` から脱糖後の整形式・型付け・効果の整合 | 同じ。前提・結論・定義・証明の変更なし | 新たな系は不要 |
| `HasTypeQ.desugar`・相互の列・腕・節・ブロック | 表層の導出から同じ文脈・型・効果の核の判断 | 同じ。範囲の量化の追加もなし | 同上 |
| `CallHeadTy.app_value`・`glue` | 宣言の対応から頭の値と適用の核の型付け | 同じ | 同上 |
| `BodyTy.desugar`・`Def.WellTyped.desugar` | 表層の本体・定義から核の本体・定義の型付け | 同じ | 同上 |
| `AliasDecl.expand_annotation` など別名の入口 | 型・値・閉じた範囲引数の条件から展開の注釈の形成 | 同じ | 同上 |
| 266署名の台帳と、その後の22件を含む開始時の全288定理 | 開始時の実署名 | すべて同じ。台本の準備で一致し、最終照合でも確認する | 既存署名をそのまま使える |

足した20定理は反例とその補助であり、既存の群 D の主な定理の置き換えではない。核、前段の固定署名、主な十言明、`ValueAssumptions`、旧 Release、他群の成果物は変更していない。三条件による署名変更を新たに適用した行はない。

### 合成表への影響と取りまとめの判断

この停止点に限れば、合成表の実在する署名を拒む例は見つけていない。既存の `StandardModel.sig_scoped` は、合成表の全lookupについて同じ合成プログラムで `PrimSig.Scoped` を示すので、署名の範囲の有効範囲は既に得られる。これを `admits` と `sat` の範囲の具体化の保存の証明に読み替えない。依頼された、合成表の各組込みについての許容と制約の保存の証明と、渡せなくなる型引数の形の一覧は未実施・未確定である。

推す対応は、新しい開いた導出の組込みの葉に、使用する署名の `s.tel.RangesScoped s.rkinds.length` 又はそれを導く既存の `s.Scoped P` の構文上の証拠を求めることである。型付けの規則への別の前提として今回の例外を広げてよいかを、取りまとめの判断へ返す。表全体への独立の信頼条件、性質1の既存の前提、核の署名の解釈は変えない案を推す。最初の完全署名と一つの保存の場合の確認は30〜60分、その後の全場合・検査・レビュー・受け入れまでの総所要は不明である。

### 変更範囲・写し・検査の記録

本番の変更は新しい `Surface.RangeSignatureExample` と、`Surface.Examples` の import の1行だけである。01-12 は値の置換の仮定の段落の後にこの反例の定義・言明の写しを一段落、07-04 は本文の一段落とモジュールの表の一行を追加した。既存の規範と表層の規則の写しを変更していない。

`verify.py` と `run_check.py` を再開6の開始時の指紋・署名・記録へ更新した。`axioms.lean` の対象一覧の作成方法のコメントも実装に合わせた。開始時の個別・保護範囲の集約の指紋は `resume6-baseline.json`、全288既存定理の署名は `resume6-signatures.json`。監査の対象の一覧は `verify.py --write-modules`、監査する全宣言の一覧は `axioms.lean` で作り直せる。private と印字時に実体化する生成宣言も固定点まで対象にする。宣言の生の写しは増やさず、群末の一回分の件数とSHA-256を記録する。

局所の単独 Lean は `lake env lean -M 12288` を一度に一つだけ実行し、最終の反例のソースは終了0・警告なしだった。初稿の暗黙引数・空の列の正規化・原子の写像の等号の証明を直した。初回は入力を書く作業ディレクトリを誤ってファイルを作れなかったが、その後に正しい場所へ作成した。未完の候補や設定による証明の穴は残していない。プロセスの一覧の読み取りは sandbox が拒んだため取得できず、他のプロセスの停止は行っていない。

最終の既定ビルド・公理監査・照合と、単位ごとの所要は以下へ追記する。停止は時間超過によるものではない。独立レビューと受け入れは取りまとめが受け持つ。

### 作業末の検査

既定ビルドと全宣言の公理監査は、`formal/` から指定の共有ロックに対する `lockf -t 3600 <共有ロック> <コマンド>` の下で、それぞれ一度実行した。ビルドは対象を指定していない。照合も一度実行した。

| 検査 | ロック内のコマンド又は照合の入口 | 開始〜終了（JST） | 外側の時間 | 結果 |
|---|---|---|---:|---|
| 全既定対象のビルド | `lake build` | 16:42:22〜16:44:57 | 155.382秒 | 終了0、1,385ジョブ。追加・変更した2モジュールの警告なし |
| 変更モジュールの全宣言の公理監査 | `lake env lean -M 12288 ../<改造>/l70/d/axioms.lean` | 16:45:59〜16:46:13 | 13.062秒 | 終了0、225宣言。private 127件と生成宣言を含む |
| 台帳・追加宣言・記録・本番の照合 | `python3 <改造>/l70/d/verify.py --tmp <tmp>` | 16:46:29〜16:46:30 | 0.992秒 | 終了0。266署名の台帳、全288既存定理、追加20定理、全宣言、既定import、保護範囲と記録の上限を照合 |

監査の内訳は `Surface.RangeSignatureExample` が78宣言、変更した `Surface.Examples` が147宣言。公理なし90件、propextだけ74件、propext・Classical.choice・Quot.soundの三つ61件で、新公理・sorryAx・許可した三公理の外の依存は0件だった。監査対象の整列した全宣言名の列は22,032バイト、SHA-256 `6b4f9461c983eaf4e699546bdbc911bbb81aa4454d72d70999b6557e406e1757`。対象一覧の再生成は `verify.py --write-modules` と `axioms.lean` が行い、宣言の生の写しは置いていない。主な十言明と、変更していない核の全宣言を再監査したという意味ではない。

1,138入力の指紋は、ビルドと監査の前後のすべてで `dac23657dfcbe0d90329dbc19d544785a6326bf9c62983e3f7f62db23ce6324a` で一致した。最終の要約は `resume6-build-summary.json`・`resume6-axioms-summary.json`・`resume6-verify-summary.json`・`resume6-verification.json`。署名の抽出器の自己検査8例、protected領域の集約、追加モジュールが既定importの閉包に入ることも照合した。最終検査の失敗と再実行はない。`--write-modules` は監査の対象一覧の準備であり、最終の検査とは別である。

| 生出力（すべて一時領域に保存） | 大きさ | SHA-256 |
|---|---:|---|
| ビルド | 186,285バイト | `ee59832d1ae7734f2468f5dc7cb2d03dcdd80a0e93bf6d56fb425ad51673f873` |
| 公理監査 | 105,400バイト | `9372950f0143e5b0e00cd7d419cd7011a76e31ef59551134ad26a98b6904a514` |
| 照合 | 959バイト | `10ee48898f574317876e61211ff0a387078de5ea88035070baaa977a794a626b` |

最大常駐量は計画上の非採取により未取得。ビルドの外側の時間は共有ロックの待ちを含み、その待ちだけを分離していない。出力がない時間はあったが、ロックの所有者を特定してはいない。初回取得以前の時間、能動時間と待ち時間も分離していない。

### 単位ごとの所要と計画からのずれ

| 単位 | 開始〜終了（JST） | 外側の時間 |
|---|---|---:|
| 資料読みの前半 | 初回の時刻の取得以前 | 未取得 |
| 取得後の照合・反例の実装と局所検査・写し・監査台本の準備 | 16:36:43〜16:42:22 | 約5分39秒 |
| 共有ロック待ちを含む既定ビルド、並行して停止の文書を作成 | 16:42:22〜16:44:57 | 155.382秒 |
| 結果の記録・監査の準備 | 16:44:57〜16:45:59 | 約1分2秒 |
| 全宣言の公理監査 | 16:45:59〜16:46:13 | 13.062秒 |
| 照合の準備・最終照合 | 16:46:13〜16:46:30 | 約17秒（照合自体0.992秒） |
| 最終の結果の追記 | 16:46:30以後 | 終了時刻を末尾に記す |

計画との差は、三つの形の規則・全具体化の性質1・受理例・発行専用の節の拒否を実装する前に、許容以外の署名の形成条件が必要であることを確認して停止した点である。見込み5時間や上限10時間による停止ではない。取りまとめへの判断点は、使用する組込みの署名の範囲の有効範囲の証拠を、新しい表層の葉の構文上の条件として求めることを、規則変更の例外に追加してよいかの一点である。独立の信頼条件や核の変更を先に加えてはいない。

終了の記録: 2026-11-06T16:47:45+09:00。最終照合の後に変更したのは本結果の追記だけであり、検査したソース・写し・定義・言明・証明を変えていない。初回の時刻取得16:36:43からの外側の経過は約11.0分。最後の結果の追記は16:46:30から終了時刻までである。資料読みの前半は未計測なので、全体の実測所要と呼ばない。

## 再開7（範囲パラメータを持つ利用者の関数）

三つの形の実装・全具体化の性質1・受理と拒否の例を閉じた。最終候補の既定ビルド・全宣言の公理監査・照合は、いずれも終了0である。

### 対象と表層の導出

開始版は `e70794188e24de95b5bb424f9d75090f77d1c703`、ブランチは `m014/l70.d2` で一致した。開始時にあった再開5・6の差分と反例を残した。git の変更操作、核と他群の変更、`scripts/check.sh` の実行はしていない。案Aに従い、表層の新しい葉で許容と宣言の構文形成を検査する。核・主な十言明・`Builtins.ValueAssumptions` に条件を加えていない。

| 依頼の形 | 表層の規則・定義 | 性質1の接続 |
|---|---|---|
| 関数の参照と直接の呼出し | `Expr.funName`・`funDicts` が `RangeIx` の列を持つ。通常の `CallHeadTy.fn`・`fnDicts` は閉じた具体化、`OpenSurface.CallHeadTy.fn`・`fnDicts` は呼出し元の `.rvar` を含む `RangeArguments` を受ける。`E_Fun`・`E_FunDicts`・`E_CallDirect`・`E_PipeCallDirect`・`E_PipeApplyDirect`・`E_PartialCallDirect` は同じ頭へ接続する | `OpenSurface.CallHeadTy.glue_core` と、各呼出し・パイプ・部分適用の保存補題を、`OpenSurface.HasTypeQ.desugar` の各場合から使う |
| 関数の定義 | `Def.WellTyped` が `rangeParams` の下の `AnnotationR` と `BodyTyR` を読む。空なら元の `BodyTy`、非空なら `OpenSurface.BodyTy`。脱糖は `rangeParams` を核の `rkinds` へ写す | `OpenSurface.BodyTy.desugar_at`・`desugar` → `BodyTyR.desugar` → 元の `Def.WellTyped.desugar` と `desugar_typed` |
| 関数の範囲を別名へ渡すR5 | `AliasDecl.expandOpen`・`openContext` と、種類を照合する `RangeArguments` を追加 | `AliasDecl.expandOpen_annotation` が呼出し元の範囲文脈の `AnnotationR` を返す。閉じた範囲の `AliasDecl.expand_annotation` の言明は同じ |

開いた表層の規則は、元の引数の対応 `CallOk`、含意、部分型、効果の被覆、view付きの網羅性を保つ。有限な表層の相互帰納に、全具体化の核の本体の型付けを葉として置いていない。核の全称の判断の定義を適用するだけの証明でもない。式・ブロック・腕・節の再帰する子の保存から、それぞれの具体化後の核の構成子を実際に作る。

### 全具体化の言明

`Benitoite.Release.Refinement.Surface.OpenSurface.BodyTy.desugar_at` の言明は次のとおりである（名前空間の暗黙引数Pも明記した）。

```lean
{P : Refinement.Program} {D B ks op Q C Γ Φ t body}
(h : Benitoite.Release.Refinement.Surface.OpenSurface.BodyTy D B ks op Q C Γ Φ t body)
(hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
(σ : {rs : List RangeExpr // RangesFit rs ks}) :
TelBodyTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
  (rangeTel σ.val t) ((desugarBlock op .tail body).instR σ.val)
```

`Benitoite.Release.Refinement.Surface.OpenSurface.BodyTy.desugar` は、同じ h・hR・hA から
`TelBodyTyR P B StoreTy.empty Q ks C Γ Φ t (desugarBlock op .tail body)` を返す。
`Benitoite.Release.Refinement.Surface.BodyTyR.desugar` は、空の種類列では元の `BodyTy.desugar`、非空ではこの新しい証明を使う。元の `desugar_typed` と `Def.WellTyped.desugar` の言明は保った。

### 葉の条件と合成表

表中の新しい条件は、開いた表層の使用箇所の葉に置いた。表全体への独立した信頼条件にしていない。

| 葉の条件 | 合成表からの供給（完全名） |
|---|---|
| 全適格具体化での型引数の許容 `Primitive` と関数の制約 `Satisfies`・`Admits` | `Benitoite.Release.Refinement.Surface.RangeStandard.admits_instR`・`sat_instR`。任意の標準lookupと型引数について証明し、List.sortの順序の条件も保存する |
| 組込みの宣言した深さでの `PrimSig.Scoped` | 既存の `Benitoite.Release.Refinement.StandardModel.sig_scoped`。範囲部分の系は `Benitoite.Release.Refinement.Surface.RangeStandard.signature_ranges` |
| 関数の依存列の、宣言した深さでの `RangesScoped` と `WF` | `Benitoite.Release.Refinement.Surface.RangeStandard.function_formation` |
| 操作とメソッドの依存列の範囲深さ0の形成、実装対象型の範囲閉性 | `Benitoite.Release.Refinement.Surface.RangeStandard.declarations_empty`。合成プログラムの操作・型クラス・実装の宣言表は空 |
| コンストラクタの欄の範囲閉性。照合・パターン束縛では `PatternRangesClosed` | `Benitoite.Release.Refinement.Surface.RangeStandard.pattern_ranges_closed` |
| 節の署名の各引数型と結果型の範囲閉性と正規性 | `Benitoite.Release.Refinement.Surface.OpenStandardClauses.standard_clauseSig_prim`・`Benitoite.Release.Refinement.Surface.RangeStandard.clause_formation`。操作として得られる11種類の標準署名すべてを確認 |
| 参照する外部関数の依存列の範囲閉性 | 標準の固定宣言は外部関数を追加しない。`Benitoite.Release.Refinement.Surface.RangeStandard.external_signature_formation`。利用者が加える任意の外部宣言について、`ExternalWF` だけからこの閉性が従うとは主張しない |

全377組込みのlookupについて、許容と制約の保存を証明した。この二条件によって渡せなくなる標準の組込み名・型引数の形は0件である。標準操作の節についても、追加した構文条件を満たさない署名はない。外部関数の葉は、当該外部署名に未宣言の範囲変数が残る形を受けない。外部宣言を持つP全体を除く条件は置いていない。この外部宣言の条件と、標準の固定表の充足は区別して受け入れ時に確認する。

`OpenPatterns` はパターンの型付け・`Exhaustive`・`ViewExhaustive` の範囲写像と具体化の保存を証明する。具体化で型を満たす値の形が増える場合は、同じ値を戻すのではなく、元の型の別の値へ反映し、述語の確定値とパターンの成功を保つ。将来の拡張では、範囲を持つ未知の欄だけを同じ欄数の任意の値を含む関数型へ写し、既存の宣言と公開の診断の宣言を保つ。網羅性を全具体化で仮定し直す条件は加えていない。

### 受理と拒否

| 例 | 既定ビルドの受理の証人 |
|---|---|
| 関数から関数へpathの `.rvar 0` を渡す | `Benitoite.Release.Refinement.Surface.RangeFunctionExamples.path_forward_def_wellTyped`。汎用の `forward_def_wellTyped` も置く |
| hostの `.rvar 0` を同種の組込みへ渡す | `Benitoite.Release.Refinement.Surface.RangeFunctionExamples.host_primitive_def_wellTyped`。例の中で構成した表の `Example.inspect` を使う |
| endpointの同じ形 | `Benitoite.Release.Refinement.Surface.RangeFunctionExamples.endpoint_primitive_def_wellTyped` |
| 標準のendpointの組込みへ渡す | `Benitoite.Release.Refinement.Surface.RangeFunctionExamples.endpoint_standard_def_wellTyped`。実在する `Http.widenRequestIn` の二つの範囲位置へ同じ `.rvar 0` を渡す |
| pathの開いた範囲を型別名へ渡す注釈 | `Benitoite.Release.Refinement.Surface.pathAlias_expandOpen_annotation`。一般の展開の形成は `AliasDecl.expandOpen_annotation` |

最初の四行は実際の `Surface.Def.WellTyped` に対する証明である。核の本体全体の型付けを与えて表層の受理と呼んでいない。`standard_no_host_range` が全377登録行の種類列にhostがないことを証明するので、hostの例を標準のhost APIの存在の証拠には数えない。型別名の型・値引数は既存の `AliasTypeArgs`・`AliasArgs` の形成条件に従う。

`ClauseAllowed` を通常の `HasClausesQ.cons` と開いた節の規則が読む。拒否するのは、利用者の操作の一覧が選ばれていないラベルで、選んだ組込みの一覧に属し、署名の種類が `pathBases` である組込みの節に限る。`RangeClauseExamples.standard_issue_clause_rejected` と `open_standard_issue_clause_rejected` は標準表の発行の節を拒否する。`user_clause_accepted` と `open_user_clause_accepted` は、同じ `Process.Environment` に属する利用者の操作の節を受理する。核の節や発行の規則は変えていない。

### 言明の差

266件の台帳と、結合・再開5・6を含む開始時の全308言明を比較した。既存306言明は同じで、変更は次の2件だけである。いずれも新しい種類列を読むことで元の言明が一般には偽になり、列の対応又は空の列の宣言を加える差である。

| 入口 | 元の署名 | 新しい署名・強いられる理由 | 元の形に戻る場合 |
|---|---|---|---|
| `desugarProgram_ranges` | 脱糖した関数のlookupから `d.rkinds = []` | 表層の対応するfdのlookupも受け、`d.rkinds = fd.rangeParams`。非空の列を核へ写すため、常に空という結論は偽 | `desugarProgram_ranges_no_ranges` が、表層の全関数の種類列が空のとき、元のkernel lookupから空の列を返す |
| `Declarations.realizes_no_ranges` | 核の全関数の種類列が空なら、Realizesと元の四条件が同値 | 表層の全関数の種類列が空という宣言hsも受ける。対応の定義が `rkinds = fd.rangeParams` なので、核だけが空では対応を導けない | 表層と核の種類列がともに空のとき元の四条件との同値を返す |
| `desugar_typed`・`Def.WellTyped.desugar`・通常の `BodyTy.desugar` | 元の型保存の言明 | 同じ。定義の `WellTyped` が宣言の範囲文脈を読む変更は、前記の表に明記した | `Def.wellTyped_no_ranges` と `bodyTyR_nil` が元の名前・kind・注釈・本体の形を返す |
| `HasTypeQ.desugar`・列・腕・節・ブロック、`CallHeadTy.app_value`・`glue` | 元の表層の性質1の言明 | 同じ。新しい開いた判断の保存は `OpenSurface` の別の入口 | 元の入口をそのまま使える |
| `AliasDecl.expand_annotation` など別名の旧入口 | 閉じた範囲の形成と展開の言明 | 同じ。開いた範囲の入口を別に追加 | 元の入口をそのまま使える |
| `ScopedProof` の19言明と `BodyTy.scoped` | 範囲深さ0の元の言明 | **すべて同じ**。一般化した証明は `_ranges` 名へ分け、旧名は元の署名の系として残した | `NoRangeScopedExamples` の19例と `Examples` の本体の例が旧名へ直接適用する |

一般化19件は `DictEv.Scoped.toVal`・`DictEv.ScopedList.toValList`・`directCallee_scoped`・`recordUpdateValues_scoped`・`exitCall_scoped`・`recordUpdateValues_scoped'`・`spreadFinish_scoped`・`JoinTy.scoped`・`JoinPartsTy.scoped`・`InterpTy.scoped`・`holeTypes_scoped`・`argVals_scoped`・`fixedShift_scoped`・`HasTypeQ.scoped`・`HasFixedQ.scoped`・`HasTypesQ.scoped`・`HasArmsQ.scoped`・`HasClausesQ.scoped`・`HasBlockQ.scoped` である。これらの旧headerは開始時のSHA-256と一致する。`ScopedList nt ne nv ds` の旧呼出し形も、追加のnrをdsの後の省略可能引数に置いて維持した。

`resume7-signature-differences.json` は2件を一行ずつ元・新の指紋で記録する。`resume7-signatures.json` は開始時の308件、266件の元の台帳は結合の記録を読む。前段の固定した核の署名と主な十言明には差を作っていない。

### 検査・変更範囲・所要

本番の差は `Surface/` の既存12モジュールと新規37モジュール、および01-12・07-04の該当する写しである。`prepare.py` と `verify.py --write-modules` が開始時の指紋から一覧を作る。公理監査は、この49モジュールに残した反例2モジュールも加えた51モジュールを対象とする。既存・新規の全モジュールが既定importに入ることを照合する。宣言の列の生の写しは保存せず、private・生成宣言を含む全環境の列を `axioms.lean` で固定点まで列挙し、件数・大きさ・SHA-256を最後の一回分だけ記録する。

最初の中間導出の足場のうち、読者のない全本体の証拠と専用の例を除いた。`OpenBody` は本番で使う `Instance`・`Le`・`Covers` とその具体化だけを持つ。`ExprCore`・`BlockCore` は固定した具体化の核結論の略記であり、表層の規則の前提に置いていない。七つの相互判断のconstructor名・順序は通常の表層と完全一致する（72・2・2・3・3・2・11）。本体の2場合と合わせ97場合を証明する。

新しい証明用の設定は、`OpenSurfaceProperty1` と `OpenSurfaceScoped` の相互証明の `maxHeartbeats 400000` だけである。完成した現ソースから設定だけ除いた既定200000の試行で、どちらもwhnfのタイムアウトを確認した。根拠の大きさ・SHA-256は `resume7-limits.json`。Handlersに一時置いた二つの上限設定は除き、既定値で通した。

| 最終検査 | 実行と結果 |
|---|---|
| 全既定対象のビルド | `formal/` から共有ロックの下の `lake build`。19:26:20〜19:27:14 JST、外側53.414秒、終了0、1,422ジョブ |
| 全宣言の公理監査 | 同じ共有ロックの下の `lake env lean -M 12288 ../<改造>/l70/d/axioms.lean`。19:28:04〜19:28:18 JST、外側13.824秒、終了0、4,590宣言 |
| 台帳・宣言・import・保護範囲・記録の照合 | この結果の初稿を含む状態で `verify.py --tmp <tmp>` を実行し、末尾へ結果を追記する |

最終のビルドと監査の1,175入力の指紋は、実行の前後でいずれも `e245def4163176a14db39eaaa55290e2efd964e6b473c82dc021a4bf0428ec96` だった。要約は `resume7-build-summary.json`・`resume7-axioms-summary.json`。最大常駐量は未取得（計画上の非採取）。外側の時間は共有ロックの待ちを含み、能動時間と待ちだけを分けていない。

最終候補の検査の前に、共有ロック付きの起動を1件中断した。19:13:35のログ作成から無出力のまま待機していたときに、既存スコープ署名20件を変える必要がないと確認したため、当該セッションへ割込みを送った。終了130、出力0バイトであり、lakeが開始したかは未確認で、成功の証拠には数えない。`resume7-aborted-start.json` にこの区別を記録した。プロセスの名前による停止はしていない。署名復元後のimport検査で旧キャッシュの生成宣言の重複を一度検出したが、該当する例を新しい依存の上で再生成して解消した。これは最終の既定ビルドの失敗ではない。最終候補の所定のビルド・監査は各一回で終了0である。

| 生出力（tmpに保存） | 大きさ | SHA-256 |
|---|---:|---|
| ビルド | 191,177バイト | `600d698b40d5586f5c7200e80d1f24a9aaf9fde449a84e84abfa3705a1b4adcd` |
| 公理監査 | 1,644,992バイト | `be923313bfdbfd235cc407907e8b8a293f60c2b5e7bda054056b6e4fedd33f3e` |

| 作業のまとまり | 取得した区間（JST） | 外側の所要 |
|---|---|---:|
| 資料の照合、三形・全保存・標準表・例の実装と局所検査、写しと台本の初稿 | 初回時刻16:49:58〜一覧準備の時刻19:11:28 | 約2時間21分30秒 |
| 台帳の準備、待機起動の中断、旧スコープ署名の復元と局所再検査 | 19:11:28〜最終ビルド開始19:26:20 | 約14分52秒 |
| 最終の既定ビルド | 19:26:20〜19:27:14 | 53.414秒 |
| 結果の準備と公理監査 | 19:27:14〜19:28:18 | 約1分4秒（監査自体13.824秒） |
| 最終照合と結果の追記 | 19:28:18以後 | 終了時刻を末尾に記す |

三形、標準表の証明、各構文の保存は並行して進めたため、単位ごとの能動時間は分離しておらず未計測である。表の外側の時間を能動時間の合計と呼ばない。受理例の担当の最初の20〜35分の見込みは、追加の保存補題の分担とProgram接続待ちを含め18:26までに上端の2倍を超えたため、原因と残りを報告し、追加分担ごとに再見込みを確認した。全体の見込み2〜5時間・上限10時間は超えていない。

計画からのずれは、追加を認められた葉の構文条件を前記の一覧まで具体化し、全構文の保存を補助モジュールへ分けた点である。合成表が満たさない条件、公理、独立の信頼条件、核の変更、提供範囲の削減は行っていない。通常の規則への変更は、承認された発行専用の節の拒否だけである。取りまとめの確認点は、(1)追加した葉の条件の一覧、(2)外部関数では標準の固定表と利用者が足す宣言の形成を区別している点、(3)hostは標準行がないため小表の受理例を用いている点である。Rust・checkerと利用者プログラムへの主定理の系は担当外であり、今回のLean成功をそれらの照合済みとは呼ばない。独立レビュー・受け入れは取りまとめへ返す。

### 最終照合と終了の記録

`verify.py --tmp <tmp>` は19:32:27〜19:32:28 JST、外側1.046秒で終了0だった。266件の台帳、開始時の全308言明（306件同じ・差2件）、追加489定理の署名、既定import、95の表層規則と本体2場合の網羅、377登録行、保護した核・他群・設定、記録の上限を照合した。要約は `resume7-verification.json` と `resume7-verify-summary.json`。追加定理の署名の集合のSHA-256は `ec55f3a19e69c3fd6e1a7f0194f59524c635f5d8c9a89a9856d614fa06e5c7c1` である。

監査対象4,590宣言にはprivate 965件と生成宣言を含む。公理なし2,047件、propextだけ556件、propextとQuot.soundが64件、propext・Quot.sound・Classical.choiceの三つが1,923件だった。新公理・sorryAx・この三公理の外への依存は0件である。整列した全宣言名の列は340,013バイト、SHA-256 `6f68a93cc76959182595bbbdb0894a269646b2cc5aa67306dd861b321679b5a3`。生の列は改造へ写していない。既定importから既存モジュールを外しておらず、必須の受理・拒否・全具体化の入口も監査対象に含む。

照合の生出力は10,587バイト、SHA-256 `d00e6aba46fd415b8423f54bc41b5bf4b07b4aae7983ddb737dca8f4aec63ff3`。最終候補のビルド・監査・照合に失敗と再実行はない。先行する起動の中断は前記の別記録で区別した。最終照合後に変えたのは本結果の追記だけで、検査したソース・写し・設定・監査台本を変えていない。

終了の記録: 2026-11-06T19:35:02+09:00。初回時刻16:49:58からの外側の経過は約2.75時間（約165.1分）。最終照合と結果の追記の区間は19:28:18からこの時刻までであり、能動時間と待ちを分離していない。

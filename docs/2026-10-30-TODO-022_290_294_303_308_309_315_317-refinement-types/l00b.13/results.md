# L00b.13: 値の葉の実装結果

RV-L00b.13 の対応結果は末尾に追記する。初回実装の記録とレビュー対応後の検査を分ける。

2026-11-01。指定ブランチは `m014/l00b.13`、B_WORK は `40311429fea38171b53f7e909096c63222ce06e5` である。整数・List・data の実際の構成子の欄・保持要求から事実を取り出す葉を実装した。完全署名を先に [signatures.md](signatures.md) へ書き、同じ起動で実装と検査を行った。独立レビューと受け入れは未実施である。

## 閉じた定義と補題

本番の新規ファイルは四つ、計499行である。新規公開宣言は47個であり、既存の四宣言の型も照合した。完全な型の解釈結果は [public-api.log](initial-public-api.log)、対象名は [public-names.json](public-names.json) にある。

| ファイル | 閉じた内容 |
|---|---|
| `formal/Benitoite/Release/Refinement/ValueFacts.lean` | `facts` と `subtype_facts` は実際の `toTerm?` の成功から目的の assume への Entails を返す。`inv_const`・`integer_facts`、`list_facts`、`inv_con`・`con_field`・`field_facts` を接続した。要素列の member/get と、LeQ の定数・data の芯の保存も含む。12宣言 |
| `formal/Benitoite/Release/Refinement/HeldValues.lean` | `Ty.Holds`、その正規化・篩との交換、名前の一意性、`Ty.LeQ.holds` と範囲の被覆の合成を置いた。checked/checkedRequest/checkedAt の逆転、保持内容の型の固定と facts、要求なし・端点不一致の拒否、同じ値の範囲拡大を閉じた。19宣言 |
| `formal/Benitoite/Release/Refinement/TargetTable.lean` | 旧表の `clientRequestTy` と `valContent` を埋め込んだ。RequestIn は要求の型、PathIn は内容なしという区分を同じ表から得る。4宣言 |
| `formal/Benitoite/Release/Refinement/ModelHttp.lean` | `valueRun` は checkedRequest と、At が作る checkedAt の some req の双方から、判定した同じ要求を返す。型付きの射影と既知の valContent の型への固定、旧モデルの groundTy/groundVal/射影との交換を閉じた。12宣言 |

篩の facts の一般の証明は既存の `HasTypeVQ.assume` と `Ty.LeQ.assume` を使う。これらは入れ子の篩、部分型の推移、V_Sub の連鎖、V_Normal を扱う。新しい葉を最外の構成子だけの逆転で閉じていない。値の形の逆転では、Sub/Normal/Refine の三つの包みを再帰して取り除き、元の葉の情報を保つ。

整数の葉は表現可能性の `ConstOK` と芯の一致を返し、実観測を整数述語へ代入する。List の葉は元の要素型と最終の要素型の LeQ を保つ。data の欄は、値の構成子 c の `P.cons c` の欄を、その値に保持された型引数で具体化する。同じ data の別の構成子の欄を読まない。data の新しい変性の規則は加えていない。

保持値の逆転は元の要求、計算可能な判定の成功、固定した `Val.reqTarget` との一致、元の範囲の所属を返す。最終型へは Covers の合成を返す。範囲を Top へ広げ、scoped から opaque へ忘却した後も同じ要求が残る。通常資源の opaque は ConstOK の内容なしの枝で受け入れる。

## D20 の計算可能な前提

開始版の `V_CheckedRequest` と `CheckedWitness.request` は、D20/O049 が定めた `groundVal req = true` の位置に `req.Ground` を持っていた。承認済みの D20 を本番へ反映し、この二つの欄を bool の成功へ揃えた。`AtTyping.checkedRequest_opaque` と `CheckedWitness.absolute_request` も同じ欄を読む。Typing は既存の AtPrepare の判定を import し、判定を複製していない。

Ground は `groundVal_ground` で導く。一般の Ground から bool の成功を導く補題は置かない。型付けの導出の範囲は D20 の条件に合わせて変わる。これは従来の Ground と同じ意味であるという主張ではない。信頼条件の欄の本文、主な定理の前提・結論は変えていないが、それらが量化する型付けの葉にはこの条件が入る。D28 の新旧対照と01-12への反映を L00b.15 へ申し送る。

値の置換・移動・narrowing の主定理の署名は変えていない。既存三族76場合と既定 import の全利用先を、新しい欄の下で再ビルドした。新しい公理、精密な外部状態、実表の新しい信頼条件、利用者の書ける形に関する未承認の制限は加えていない。

## 場合の数の予定と実際

Lean の環境から数えた結果は [case-inventory.txt](case-inventory.txt) にある。数は証明の主な帰納の場合の数であり、tactic が作る細分化の総数ではない。

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 新規の値の逆転5本 | HasTypeVQ 各29、計145 | 各29、計145。const/con/checked/checkedRequest/checkedAt |
| LeQ の構造補題3本 | 各13、計39 | 各13、計39。constCore/dataCore/holds |
| HasTypeEachQ・HasTypeVsQ | 各2 | 各2。member/get |
| Const の区分 | 16 | 16。定数の芯と ConstOK |
| RangeIx・CheckedWitness | 各2 | 各2 |
| ground の埋め込み | 旧 Ty/Val の全構成子 | 旧 Ty15、旧 Val17。型列・値列は各2場合 |
| 既存の値・計算・ImageOk | 29 / 24 / 4 を維持 | 29 / 24 / 4 |
| 既存三族・Step | 76 / 76 を維持 | 76 / 76。構成子の追加・削除なし |

既存の全 sort の assume と List の逆転を呼ぶ箇所では、それらの帰納証明を複製していない。

## 境界入力と遷移

[boundary.lean](boundary.lean) は379行で、公開する補助定理51本を含む。公理監査は私有・生成宣言を含む104宣言を対象にした。各正例は元の型付けと実際の値を構成し、結論の型付けや Entails を入力として仮定しない。

| 入力 | 確認した内容 |
|---|---|
| `seven_nested` → `seven_wrapped` → `integer_extracted` | 7へ二つの篩を導入し、forget/introduce/trans と V_Sub/V_Normal を通した後に `0 ≤ 7` を抽出する。`subtype_fact_direct` は V_Sub を構成する前の型付けと LeQ だけから同じ事実を得る |
| `raw_unit_inverted`・`list_element` | 生の Unit{true} の型付けを構成し、V_Normal と List の V_Sub を通して、実際の定数と要素の情報を逆転する |
| `list_length_fact` | 一要素の List に長さの篩を導入し、正規化後の List の葉から長さ1の事実を抽出する。assume が空の例ではない |
| `box_field_fact` | Box.Int と Box.Text を持つ data について、Box.Int の整数の欄の篩から `0 ≤ 7` を得る。構成子の宣言と欄の型の具体化も実際に行う |
| `held_top`・`projection_known_content` | 標準の Http.ClientRequest の欄を持つ要求について、計算可能な閉性、固定した URL 解析、範囲所属から保持値を作る。Top への共変、V_Normal、scoped の忘却後も同じ要求と既知の内容型を得る |
| `retained_fact` | 内容の型にも constructorIs の篩を持つ表を使い、保持要求から実際の内容の空でない fact を得る |
| `before_state`・`actual_step`・`after_state`・`after_leaf` | 実際の E_IfT の前後で StateTy を構成し、事前に構成した値の型付けを再利用して射影の葉を適用する。StateTy の内部から導出を取り出した例ではない |
| `at_transition`・`at_projection` | checkedAt の some req についても、同じ要求の射影、実際の Step、前後の StateTy を構成する。snapshot は絶対範囲の none であり、精密な外部状態を加えない |
| `no_request`・`wrong_endpoint`・`checked_at_no_request`・`checked_at_wrong` | 内容を持つ RequestIn に要求なしの値を与えず、端点の異なる要求を型付けない。通常の保持値と At の到達値の両方を検査する |
| `bare_request_rejected`・`resource_opaque`・`resource_kind` | 標準対象の裸 opaque を拒否し、資源 File の opaque は Top で型付く |

作成時の関門では、持ち主を「型付き値の逆転から実観測の facts と保持要求の射影まで」とした。旧の正規化の例だけでは、欄の型を別の構成子から読む退行、Top への拡大で要求を失う退行、At の値を射影すると既定要求へ置き換える退行を検出できない。今回の例は本番の型付け・部分型・逆転・射影・遷移を接続して検査する。処理系内部のテストダブルや専用の差し込み口は加えていない。旧テストは削除していない。

## 補助契約で決めたこと

| 論点 | 採った案と理由 | 捨てた案 |
|---|---|---|
| facts の実観測 | toTerm? の some を受け取り、既存 assume と LeQ.assume の cut/bind を使う | 欠落時の整数0を実観測と扱う案 |
| data の欄 | 値の構成子と保持した型引数で欄を具体化する | 同じ data の任意の構成子から同じ位置の欄を読む案 |
| 保持値の型の情報 | 正規化した芯の scoped/opaque と元の添字からの Covers を返す。opaque の kind は復元せず元の valKind の証拠を使う | 全型の等号へまとめる案、忘却で保持内容を落とす案 |
| Top と共変 | 元の所属と Covers から同じ値を広げる。固定添字の WF は True なので余分な outer.WF を要求しない | 狭い注釈だけで保持値を導入する案、補助のために範囲の WF を追加する案 |
| 内容の型の固定 | Holds の名前の一意性と同じ valContent の lookup で A を固定する | 表の単射性を仮定する案 |
| ground | D20 の bool の成功を保持し、Ground は既存補題から得る | 一般の Ground を判定成功へ逆向きに変える案 |
| HTTP の配置 | 並置体系に射影を置き、旧モデルとの埋め込みの交換を証明する。At の some req も射影する | 旧の信頼条件をそのまま新しい型付けの証拠とする案、At の値を既定要求へ置き換える案 |

これらの補助の選択は、主定理の一般の Γ/Φ/型像を制限しない。D20 の承認済みの葉の条件の反映以外に、主な定理が量化する範囲を変える条件を足していない。

## 初回実装のビルドと公理依存

最終検査は [verify.py](verify.py) で再実行できる。すべて終了0である。既定の lake build は lakefile.toml の `-M 12288` を使い、単独の Lean も同じ上限を明示した。Lean は固定した `formal/lean-toolchain` の v4.34.1 である。

| 検査 | 終了 | 外側の時間 | 証拠 |
|---|---:|---:|---|
| formal/ で既定の `lake build`。旧体系・並置体系・全既定ターゲット | 0 | 0.798097秒 | [build.log](initial-build.log)。715 jobs、増分ビルド。新規・変更した Lean に警告なし |
| `lake env lean -M 12288` で全境界入力とその公理依存 | 0 | 1.542778秒 | [boundary.log](initial-boundary.log)。104宣言、新しい警告なし |
| 同じ入口で全 Refinement と集約・旧主定理等の公理依存 | 0 | 11.967481秒 | [axioms-summary.json](initial-axioms-summary.json)、[対象記録](initial-axiom-targets.txt)、[大きい記録](initial-large-records.md) |
| 同じ入口で新規47・変更4宣言の完全署名 | 0 | 0.675001秒 | [public-api.log](initial-public-api.log) |

公理依存は計13,948宣言を確認した。Refinement 全133モジュールと集約モジュール、旧モデル三つの仮定充足・限定同値・旧主定理の12宣言、境界の104宣言を含み、私有・生成宣言も省いていない。未監査の対象は0である。依存は propext・Quot.sound・Classical.choice だけで、sorryAx と未承認公理はない。

実行の開始UTC・コマンド・終了・外側の時間・出力のハッシュは [verification.json](initial-verification.json)、入力の SHA-256 は [inputs-sha256.json](initial-inputs-sha256.json) にある。[input-stability.json](input-stability.json) で検査中の入力変更がないことを確認した。[source-delta.json](initial-source-delta.json) は開始時のソースのハッシュとの照合で、新規4・既存3の7ファイルである。git は使っていないため、基準コミットとの正式な差分の照合は取りまとめが行う。

途中の境界検査では、型引数の空の kind 文脈、型の具体化の正規化、公開補助補題の import と Normal の入力、固定添字の推論、snapshot の Adequate の組立てを直した。URL の解析の具体例は、長い名前の cbv が探索上限へ達したため `http://a` にし、固定した本番の parseUrlTarget を通す代表を保った。上限をさらに広げていない。

最初の記録付き検査はビルド成功・境界失敗であった。[first-verification.json](first-verification.json)、[first-boundary.log](first-boundary.log)、[first-inputs-sha256.json](first-inputs-sha256.json) を保持した。境界の公理列挙が parser の補助宣言まで拾う誤りも直し、自分の名前空間の私有・生成宣言を列挙するようにした。途中経過で終了前の空の出力を成功と報告した点は会話中に訂正した。最終の終了0と公理依存の結果を完成の根拠とする。

RSS は未取得（計画上の非採取）である。作業末の work は指示に従い実行していない。Rust/Lean の全比較、性能測定、独立レビュー、受け入れを実施済みとはしていない。100 KB を超える生の公理記録と対象名は `<tmp>` に置き、大きさと SHA-256 を large-records.md へ記録した。改造内の各ファイルは100 KB以下である。

## 義務の判定と残り

| 義務 | L00b.13 の判定・証拠 | 残る段 |
|---|---|---|
| O030 | 今回の値の葉は完了。5本の全場合の逆転、整数/List/data欄/保持要求の空でない facts、Sub/Normal/Refine の連鎖と実際の遷移後の適用を boundary で確認 | L40: 型から閉じた値の形を得る全 canonical forms、関数・Map/Set・辞書・lazy 等の残り、全δ/return/状態との合成 |
| O047 | 今回の接続は完了。subtype_facts は LeQ.assume の推移と篩の連鎖を cut/bind で実観測へ写す。逆転と値ごとの facts に接続 | L40: 全 canonical forms への適用。既存の一般の assume の完成と、今回の葉の完成を二重に計上しない |
| O049 | 今回の葉は完了。計算可能な前提・固定 reqTarget・valContent の区分・Top/共変・同じ要求の射影を本番と正負の入力で確認 | L10/L50: 適格な旧導出の埋め込みと対象の具体化。L60: 三モデルの信頼条件の充足。L00b.15: D20/D28 の新旧対照と01-12への反映 |
| O016・当該L作業 | 既定ビルドと上記13,948宣言の公理依存を確認 | 後続の各L段とL70のA-Lは予定どおり残る |

L00b.11 の中1・中2・軽1の取りまとめの処置を保持した。組込みの遷移は正規形の型・行引数を表へ渡す。CellOk.val は格納型の norm で読み、継続の R は StoreOk の下で ContTy.end_normal・ClosureTy.return_normal・resume_raw_return から生の等号へ戻す。今回これらの契約を差し替えていない。

L00b.14a へは、評価済みの値に `facts` / `subtype_facts` を適用し、その実観測を Tel.argumentsEnv に使えることを申し送る。整数の0の既定値を実観測とみなさず、`toTerm? = some t` を確保する。保持要求の Ground は bool の成功から得る。受信前の Outcome.Carrier と受信後の元の型付けを区別し、外部応答には受信成功後の型付けでだけ葉を使う。開始の同じ契約・固定 Eb を保つ依存βの代表は本作業では実装していない。

| 残る手順 | 担当・範囲 | 見込み |
|---|---|---|
| 独立レビュー・受け入れ | 取りまとめ。RV-L00b.13-request の署名・定義・前提・境界・全新規ファイルを照合する | 不明 |
| work・基準版との正式な差分照合・取り込み | 取りまとめ。担当は git と work を実行しない | 不明 |
| L00b.14a | 取りまとめが受け入れ後に別途起動する依存βの代表。未着手 | 計画の2〜4時間 |

## 計画との差と外側の時間

ファイルは Canonical を直接増やす代わりに、ValueFacts と HeldValues に分けた。既存の Canonical の公開入口を利用し、集約の Benitoite.lean から新規四モジュールを既定 import した。At の保持要求の射影も、この作業の値の葉の内数として閉じた。D20 の承認済みの条件を実際の規則へ揃えたこと、補助の細部を確定したこと以外に、提供範囲を変える計画変更はない。

最初の時刻の確認は2026-10-31 15:40:49 UTC（2026-11-01 00:40:49 JST）である。それより前の指定文書の読取りの開始時刻は未採取である。最終検査は16:04:28 UTCに終わり、最初の時刻の確認から23分39秒であった。文書を含む最終の照合時刻と外側の時間を末尾へ追記する。能動時間と途中の待ちは分離していない。最終四検査の待ちは計14.983357秒である。3〜6時間の見込みの上端と停止条件の12時間には達していない。


最終の文書照合は2026-10-31 16:09:27 UTCである。最初の時刻の確認から28分38秒で、先行の文書読取りの時間は未採取である。142入力の SHA-256、相対リンク、新規ファイルの列挙、全ファイルの100 KB以下、公理と検査の終了を再照合した。新規は本番4ファイル、l00b.13/ の文書・入力・証拠24ファイル、レビュー依頼1ファイルの計29ファイルである。既存の変更は formal/ の3ファイルに限る。L00b.13 の末で止め、L00b.14a は未着手である。


## RV-L00b.13 の対応結果（2026-11-01）

今回の依頼と取りまとめの追記に従い、中1・中2・軽1・軽3・軽5を実装し、軽2・軽4・軽6・軽7を後続の義務として signatures.md に記録した。レビュー本文・plan.md・rv-13-w2.lean・rv-13-w3.lean は変更していない。初回の成功記録は initial-* に保存し、以下をレビュー対応後の結果とする。

### 中1: 閉じた篩を持つ型引数

AtPrepare の groundTy に `.refined a p => groundTy a && decide (p.WF 1)` を加えた。既存の構成的な Pred.wfDecidable を使い、self だけを参照できる述語を判定する。groundTy_notContCore を置き、groundTy_wf の refined の場合を、基底型の WF、述語の上限の拡大、NotContCore から閉じた。groundVal_ground と利用先も再ビルドした。旧 Release.ModelHttp は変更せず、groundTy_embed とその型列・値列・valueRun の交換五本も再確認した。

これは受理する groundVal の範囲を広げる変更である。一般の Ground から判定成功が導けるようになったとはしていない。D20/D28 の新旧対照へ、閉じた refined 型引数の受理と p.WF 1 の意味を送った。判定の前提や信頼条件の欄を追加していない。

[review-ground-boundary.lean](review-ground-boundary.lean) は、提供された rv-13-w3 の入力を別の名前空間で正例へ反転した。Pair[String{true},String] を持つ要求について、元の型付け・groundVal の成功・V_CheckedRequest の保持を構成し、cap の var 0 経由の AtPrepared も実際に計算して成功させた。変数から返す値の型引数は正規化されないので、レビューが示した生の入力を検査している。

空でない閉じた篩は `0 ≤ 1` を使い、正規化の後にも述語が残ることを remaining_fact で確認した。型付きの要求・V_CheckedRequest・At の準備の成功も通した。この例は、残る型引数に合う欄型の宣言を使う。現行の data の不変性を共変へ変えていない。標準の Pair[String,String] の欄へ非自明な篩付きの型を広げる部分は、L40 の検証済みの変性と合わせて扱う。

負例は var 1 を参照する述語で、p.WF 1 でないこと、groundTy/groundVal が false であること、保持値が型付かないことを示した。同じ構造の要求を At に渡した結果も、invalidTarget となることを計算した。Rust の同じ入力は実行していない。true・残る閉じた述語・開いた述語の三入力を、L30 以降の Rust/Lean の比較へ申し送った。

### 中2: 準備から実際の E_AtOk の到達値まで

次の補題を本番に置いた。

| 補題 | 内容 |
|---|---|
| `AtPrepared.request` | valContent が some のとき、実際に closeVal した入力の groundVal の成功、固定した reqTarget の結果、準備結果がその absolute 対象である等号を取り出す |
| `parseUrlTarget_kind`・`Val.reqTarget_kind` | 本番の解析の成功から、結果の kind が endpoint であることを導く。任意の表の性質を仮定しない |
| `checkAt.absolute` | absolute t の入力に対する検査の成功が、同じ t を返すことを導く |
| `CheckedWitness.of_prepared_request` | 型付きの閉じた入力と準備・所属検査の成功から、遷移が作る同じ要求の CheckedWitness を構成する。ground や reqTarget の結果、URL の kind は別の入力にしない |

prepareCore の後半の検査を非公開の finishPreparation へ分け、三つの段階を Except.bind で記述した。元の判定の順序、成功結果、誤りの分岐を保つ。成功した bind の逆転と finishPreparation_target を使うことで、解析器や Decidable の実装まで展開せずに AtPrepared.request を証明した。公開する AtPrepare/AtPrepared の型と、遷移の規則は変えていない。

review-ground-boundary の prepared_raw・checked_target は、準備と対象の検査を実際に計算する。at_ok_step は、その同じ前提を使って実際の E_AtOk の遷移を構成する。witness_from_preparation は準備の結果の要求情報と URL の kind を入力に取らず、本番の補題で CheckedWitness を作る。reached_value_leaf は遷移後の Result の値に含まれる checkedAt を取り出し、その型付けに ModelHttp.valueRun_checkedAt_typed を適用して、同じ要求の射影を得る。

初回の E_IfT の例は、事前に構成した値の型付けを再利用した例であった。StateTy 内部の導出を取り出す例ではないと説明を修正した。今回の E_AtOk の例では、遷移の前提から到達値の保持部分を実際に型付けて葉を適用している。StateTy からの一般の return の逆転と、Result の宣言を含む全状態の保存は L40 に残る。

### 軽所見の処置

| 所見 | 今回の処置と残り |
|---|---|
| 軽1 | E_IfT の説明を修正し、上記の実際の E_AtOk の例を追加した。一般の StateTy 内部の逆転は L40 |
| 軽2 | 各幅の整数・Byte の契約の葉を L40 の義務へ明記した |
| 軽3 | HasTypeVQ.list_element_facts と field_facts_by_type を ValueFacts に移した。境界に、空でない要素の facts と型の側の data 引数の facts の例を追加した |
| 軽4 | 通常の checked/PathIn の Top への拡大と逆転、checkedRequest_facts の直接の入口を L50 へ送った |
| 軽5 | retained_fact は実観測の some の等号を示して facts を通す形へ替えた |
| 軽6 | 標準の valKind の並置を L50 の義務へ明記した |
| 軽7 | atError の dataValue の観測と欄の facts を L40 の残りへ明記した |

今回の本番の変更は AtPrepare・AtInput・AtSound・AtTyping・ValueFacts の五ファイルで、新しい本番ファイルはない。[review-source-delta.json](review-source-delta.json) が今回の開始時との照合である。新規公開補題は8本、初回と合わせた新規宣言は55個となった。意味の変わる ground 判断等を含む12宣言と、旧モデルとの交換五本も [public-api.log](public-api.log) に列挙した。主な定理の言明、信頼条件の欄、新しい公理、提供範囲、精密な外部状態を変更していない。利用者の書ける形を狭めていない。

groundTy_wf は全21型構成子のうち refined の場合を追加した。旧型15・旧値17の埋め込みの全場合、既存三族76、Step76を保ち、新しい型付けや遷移の構成子は加えていない。

### 最終検査と記録

最終の六検査はすべて終了0である。既定ビルドは715 jobs、増分ビルドである。単独の Lean にも -M 12288 を明示した。今回の変更箇所と境界に新しい警告はない。既存の別のモジュールの lint とリンカの探索先の警告は残る。

| 検査 | 終了 | 外側の時間 | 出力 |
|---|---:|---:|---|
| build | 0 | 0.155445秒 | [build.log](build.log) |
| boundary | 0 | 1.605557秒 | [boundary.log](boundary.log) |
| review-ground-boundary | 0 | 1.841515秒 | [review-ground-boundary.log](review-ground-boundary.log) |
| review-reference | 0 | 0.645283秒 | [review-reference.log](review-reference.log) |
| axioms | 0 | 12.043162秒 | [axioms.log](axioms.log) |
| public-api | 0 | 0.679889秒 | [public-api.log](public-api.log) |

公理依存は14,087宣言を確認した。Refinement 全133モジュールと集約、旧モデルの仮定充足・限定同値・旧主定理の12宣言、初回境界106宣言とレビュー対応境界101宣言を含む。私有・生成宣言も監査し、未監査のモジュールは0である。依存は propext・Quot.sound・Classical.choice だけで、sorryAx と未承認公理はない。[集計](axioms-summary.json)、[実行記録](verification.json)、[入力のハッシュ](inputs-sha256.json)、[入力の安定性](input-stability.json) に記録した。

提供された rv-13-w2 は読み取りだけで再実行した。rv-13-w3 は修正前の負例として保存し、編集せず、新しいファイルで正例へ反転した。[protected-inputs.json](protected-inputs.json) で両ファイル・plan.md・レビュー本文のハッシュが同じことを確認した。実行器のログは review-reference.log とし、rv-* の入力と区別した。100 KB を超える公理の生の記録と対象名は tmp に置き、[large-records.md](large-records.md) に大きさと SHA-256 を記した。

途中の局所検査では、do の展開が match へ分配されて bind の逆転を直接適用できないことと、全分岐の展開が探索上限に達することを確認した。非公開の末尾の検査を分けて明示的な bind にし、既定の探索上限のまま閉じた。境界では、注釈の WFList の明示、空でない述語の Sorted/Declared、List の要素の明示的な引数を直した。未証明の前提や新しい公理で埋めていない。

作成時の関門では、持ち主を「捕捉環境から読む要求の準備と保持値の生成」とした。従来の E_IfT の例だけでは、groundTy が raw の篩を拒む退行や、準備と reqTarget/CheckedWitness が接続しない退行を検出できない。今回の入力は本番の準備・解析・所属検査・E_AtOk・逆転・射影を接続する。内部のテストダブルや専用の差し込み口は加えていない。初回の境界を残し、要素と欄の二例を追加した。新しい review-ground-boundary はtruth の篩・残る閉じた篩・開いた述語の差を検査する。

work と git の操作は実行していない。Rust/Lean の比較・独立レビュー・受け入れは未実施である。RSS は計画上の非採取で、未取得である。今回の開始は2026-10-31 16:22:19 UTC。最終の Lean 検査の終了は16:39:13 UTCで、開始から16分54秒であった。文書を含む最終照合の時刻を末尾へ追記する。能動時間と途中の待ちは分離していない。最終六検査の待ちは計16.970851秒である。4時間の上限には達していない。

L00b.14a へは、実観測の facts と bool からの Ground に加え、AtPrepared.request・reqTarget_kind・checkAt.absolute・CheckedWitness.of_prepared_request を使う入口を申し送る。受信前の Carrier と受信後の元の型付けの区別を保つ。依存β、全状態の保存、各幅の契約、atError、標準表の具体化と Rust との比較は指定した後続へ残す。L00b.14a は未着手である。


今回の最終照合は2026-10-31 16:42:29 UTCで、開始から20分10秒であった。146入力の SHA-256、相対リンク、41ファイルの一覧、各ファイルの100 KB以下を確認した。旧 Release.ModelHttp と、提供された入力・計画・レビュー本文のハッシュは同じである。今回の formal/ の差分は五ファイルに限り、未完の差分を戻していない。検査後に本番ソース・入力・検査台本は変更していない。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 所見対応の再確認・受け入れ | 取りまとめ。更新した依頼で定義・言明・前提・正負の入力を確認する | 不明 |
| work・正式な基準版との差分照合・取り込み | 取りまとめ。担当は git と work を実行しない | 不明 |
| L00b.14a | 受け入れ後に別途起動する依存βの代表。未着手 | 計画の2〜4時間 |

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `40311429fea38171b53f7e909096c63222ce06e5`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 40311429fea38171b53f7e909096c63222ce06e5` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 65.58 秒、最大常駐量 1150877696 B である。

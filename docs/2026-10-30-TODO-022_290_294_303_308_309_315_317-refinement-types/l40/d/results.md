# 群 D：scalar と有限事実の読者

2026-11-03。L40.16〜.20 の担当分を完了した。以下は初回の記録であり、RV-L40.d の処置と現行の検査結果は末尾の「再開1」を正とする。独立レビュー後の受け入れは設計者が行う。

基準 B_WORK は `5e2012958fe8aab1edca8587ec8dd731a1527a82`、指定ブランチは `m014/l40.d`。担当は git コマンドを実行していない。ブランチ・HEAD の実値は起動依頼の指定を採用し、現在の入力を verify.py の SHA-256 で識別する。

## 単位の時刻（UTC）

開始・終了は各時点でこのファイルへ記録した。表は外側の時刻であり、読取り・能動時間・待ちは分離していない。

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L40.16 | 2026-11-03T11:22:10.262181+00:00 | 2026-11-03T11:33:59.029215+00:00 | 担当分完了 |
| L40.17 | 2026-11-03T11:33:59.029215+00:00 | 2026-11-03T11:36:42.192601+00:00 | 担当分完了 |
| L40.18 | 2026-11-03T11:36:42.192601+00:00 | 2026-11-03T11:38:16.290054+00:00 | 担当分完了 |
| L40.19 | 2026-11-03T11:38:16.290054+00:00 | 2026-11-03T11:41:34.918053+00:00 | 担当分完了 |
| L40.20 | 2026-11-03T11:41:34.918053+00:00 | 2026-11-03T11:54:51.901564+00:00 | 担当分完了 |

単位の後の照合で、篩を持つ等値の型引数の具体例と、正常応答の Outcome.Typed/Ground/AdequateResult/exit 排除の受渡しを補った。後者の照合と検査は checks.json の reply-contracts-final・final-build-3・axioms-final に記録する。

単位の区間の合計は1,961.639383秒（約32分42秒）である。単位前の読取りと単位後の写し・監査・記録の照合はこの区間の外にある。この値を能動時間とせず、未経験の群へ一律に外挿しない。D の積上げ3時間〜5時間50分と、L40 の枠15〜35時間を改める根拠には使わない。RSS は未取得（計画上の非採取）である。

## 本番の追加と数値の担当分

新しい既定モジュールは次の五つである。scalar の定義は `StandardScalar` の名前空間に置き、有限事実の本体は `StandardFactExamples` に置いた。既存の規則・型付け・CoreAssumptions・主な十言明は変更していない。L10/L30 が数値の表現可能性を型付けへ入れた、既存の決定からの変更を継承し、その値域を実応答へ接続した。

| モジュール | 閉じた担当分 | 環境に保持される宣言 |
|---|---|---:|
| StandardInteger | 七幅の実変換、正常算術、42比較、名前による部分表、min/max・bitwise/shift・床方向の正常部 | 321 |
| StandardByteCharacter | UInt8/Char の実変換、code、六比較、String の scalar 範囲、同じ Bytes の導入/射影 | 82 |
| StandardFloat | 二幅の六分類・六比較、実名の部分表、特殊値と構文の等号の対照 | 22 |
| StandardDecimal | 同じ丸め定義の正常値の再検査、五モード、実名の部分表、六比較・absolute・明示変換 | 131 |
| StandardFactExamples | 前提を読む LeQ、Not を使う if/guard の本体と元の捕捉、実行、正常応答の三条件 | 89 |
| 合計 | private・生成宣言を含む。匿名の example の件数とは別 | 645 |

全名は `audit.py` と `axioms.lean` が環境の所属モジュールから再生成し、`declarations-<モジュール>.json` へ保存する。手書きの公開名・private 名・匿名例の件数は `verify.py` が [declarations.json](declarations.json) へ再生成する。

| 型・系列 | 固定した正常応答と関係 | Stop・失敗の境界 |
|---|---|---|
| Integer8/16/32/64（Integer）・UnsignedInteger16/32/64 | `integerConvert_some/none/result` は実変換の Some を同じ数学値、None を対象幅の外と同値にする。全七幅の上下端・その一つ外も実分岐で確認。加減乗21組・符号付き負号4組は同じ checked 演算を呼び、正常値の等式・表現可能性・型付けへ接続 | 変換の None は正常な Option 値。除算・剰余、床除算、最小値の absolute、shift count の Stop の全幅の条件と第一失敗の接続は L40.29 |
| Integer への明示変換 | 小幅は同じ値の全域の拡大、u64 は Option。u64 最大値の None と Integer 最大値の Some を実表で対照。Integer64 自身への架空の fromInteger は作らない | u64 の変換の None を overflow の Stop としない |
| min/max・bitwise・shift・床方向 | 同じ入力を選ぶ min/max、幅内のビットと符号の復元、count の検査、床方向の符号補正。負数の床商/剰余と算術/論理右シフト、u64 の左シフトの切捨てを同じ表で確認 | 床剰余を商の overflow だけでは拒否しない。一般の非線形・ビット演算を線形理論へ加えない |
| Byte/UnsignedInteger8 | 実 UInt8 の変換の Some/None と同値・範囲、0/255/域外、同じ Integer への射影、実ビット演算。Bytes の元の各要素の値と Byte の型付けを保持 | 暗黙変換・Byte→UInt16 の API は追加0。列長の一律の上限なし。shift count の Stop の全整理は .29 |
| Character | 実 Char の成功と同じ code が同値。負数・surrogate・0x10ffff を越す値は None。characterCode・String 内の scalar 範囲・六比較の Boolean を同じ型付けへ渡す | Unicode の字句処理・全分類表は外側。変換の None は正常値 |
| Float32/Float（Float64） | 実 UInt32/UInt64 bits から12分類・12比較を供給。finite は zero を含む。NaN・±∞・±0・同じ NaN を含む対照。実 API は Float32.isInfinite と両幅の isNaN・比較 | 数の ±0 は等しく、NaN は自分とも等しくない。Lean の Term の構文の等号とは異なる。Rust の構造比較の Float 成分は IEEE の等号を使う。全ビットの丸め・実数への線形化は追加0 |
| Decimal | `decimalRound_represented/typed` は同じ normal から仮数/scale を再検査。五つの実構成子を `decimalDelta_round` で同じ定義へ渡す。整数への TowardZero、u64 の端数0と範囲、同じ scale の absolute、桁合わせの六比較 | 五モードすべてで正常/仮数の表現外/不正 places を対照。round の DecimalOverflow と ArgumentOutOfDomain は error、変換の Option.None は正常値。Decimal の96 bit の仮数部は U03 の保存係数128 bit と別。桁合わせの一時積を128 bit に制限しない |

S01/S03/S04〜07/S09/S34〜36 の D の担当分を上の入口へ接続した。S02 と S35/S36 の Stop の全幅の整理は .29、Bytes の正常 length と他の measure は .21、全23モジュール328 API の行と BuiltinArgs の照合は .28、具体の表全体の CoreAssumptions の充足は L60 が受け持つ。今回の部分表の正常応答の証明を、全標準表の充足証明とは呼ばない。

`arithmetic_reply_contract` と `decimal_reply_contract` は、同じ正常応答へ Outcome.Typed（型付けと Ground）、AdequateResult、exit の排除をそろえる。補助の数学上の型域だけを前提にしたのではなく、実変換・checked 演算・同じ丸めからの応答の等号を使う。全行の結果の型・名前・引数の数の収集と全量化は .28/L60 の割当を保つ。

## 実物の .bnt・Rust との照合

[sources.py](sources.py) は標準ソース19モジュールの239 API の署名を再収集し、D が直接使う109署名について、実物の引数名を含む宣言を保存し、引数型・結果型を期待する署名と照合する。Integer64・UnsignedInteger・UnsignedInteger8・Float64 のラッパーの実呼出し先も保存する。Rust を含む36入力の bytes/SHA-256 と、Lean に書いた実名の登録先との照合は [sources.json](sources.json) にある。名前の不一致は0件である。Float.isInfinite は実物にないため追加していない。

数値の読取りでは `narrow_integer.rs` と `unsigned_integer64.rs` の try_from・全域の拡大・端数0の検査、`operators.rs` と signed/unsigned の checked 演算、`integer.rs` と `width_bits.rs` の床方向の補正・checked_abs・幅内のビット・count の検査を照合した。Byte/Character は実 UInt8/Char の導入と射影に対応させた。Decimal は `base/decimal.rs` の五モード・余り0・同率・符号・0補完・最終の仮数の検査・cmp_num、Float は実比較と `runtime/equal.rs` の IEEE の等号を照合した。

この照合は、原ソースとモデルの定義の読取り、および名前・型の機械的照合である。Rust の実行との全比較を実施したとの主張ではない。Decimal.fromFloat の Float 表記・指数展開・文字列の解析、通常の parse の字句処理は既存の外側の境界に残す。`decimalConversionReply` は解析後の表現を再検査する出口であり、Float の全ビットの文字列変換を証明したものではない。Rust/Lean の接続と全比較は L70 の F-REG、R50 の F-CONN、K10、V10 が担う。`check-formal.sh` は実行していない。

## 有限事実の実際の読者

`length_le` は、先頭の長さの等式を `.hyp 0`、型域二条件の後の `n>0` を `.use 3` で読む証明書を `checked_refinement` に渡す。長さの等式だけ・非負の一般葉だけでは済ませていない。同じ source/target で正数の経路条件を除くと、self が空の List、n が0のモデルで `Ty.LeQ` 自体を否定できる。

`false_fact_typing` は B04 を使う既存の `false_side` から Not を得て、返却値の篩へ導入する本体である。同じ本体を前提なしで同じ型にすることは、Boolean=true のモデルと `facts` から否定する。`false_if_typing` は元の条件が未知でも両枝を型付けし、`false_if_closed/selected` は同じ CaptureOk と実際の条件から選択した枝を閉じる。標準整数比較の実正常応答も `integer_comparison_branch` でこの捕捉と本体へ渡す。

guard は `if b then false else true` とし、true/false の両方が起こる。`guard_typing` の契約を true で開くと、`guard_body_typing` の本体に必要な Not が得られる。`guard_arms_typing` は obs=None のまま guard と通常の後続腕を保持し、`guard_match_closed` は元の CaptureOk で match 全体を閉じる。guard が true を返す同じ捕捉へ、実評価で真になる契約を `addEvaluated` で足して body を閉じた。既定ビルドの具体例は if の一歩、guard の二歩、true で body へ進む場合と false で後続腕へ進む場合を含む。

観測が none の原子を true にせず、And/Or の片側だけで結果が決まる場合も右辺を none のまま残す。偽の左側から、到達しない右辺が true だという事実は導けないことを別の実モデルで否定した。到達しない右辺の事実を経路の仮定に追加しない。

## 固定署名・義務・計画との差

| 対象 | 差と判定 |
|---|---|
| 群 A の F01〜07、群 B/C の確定署名 | 変更0。未使用の前提を除く変更も0 |
| 主な十言明・StateTy・型付け・CoreAssumptions・実行の規則 | 変更0。新しい公理・独立の信頼条件・利用者の書ける形の制限0 |
| 本番の配置 | StandardScalar の名前空間を保ち、整数・Byte/Character・Float・Decimal を四つの新モジュールに分けた。有限事実を含め新5本。既定 import で全て検査 |
| 01-12・07-04 | 実際の定義と前提、正常応答と部分表の範囲を同じ変更で反映。規範の演算・主定理の言明の変更0 |
| 保護対象 | plan/detail/README/レビュー記録・群 A〜C の記録・処理系・旧 Release の担当による変更0。git の操作0 |
| 時刻と計測 | 単位の開始・終了を各時点で記録。能動時間と待ちは未分離。RSS は計画上の非採取 |
| 初期の局所試行の記録 | L40.16 の run.py 導入前の試行は、生出力の保存と秒数が未取得。型域の定義展開・整数専用の比較原子・List.findSome? の簡約・シフトの型等を修正した。最終の局所検査・既定ビルド・全公理監査・work は生出力の bytes/SHA-256 を保存 |

[obligations.md](obligations.md) に64行を一行ずつ照合した。技術21行に D の証拠を記し、他群・共通・後段の義務を分けた。全体の義務の閉鎖は0行である。共通の担当分について、許可公理、既定 import、写し、検査・記録・独立レビューの境界を照合した。独立レビューと設計者の受け入れは未実施である。

新たに取りまとめの仕様判断を要する停止事項はない。取りまとめには、五つの数値の部分表を .28 の全標準行と L60 の具体表へ組み込む際に、同じ宣言・BuiltinArgs・全型/行/範囲引数を使うこと、型域から演算の一致を推測しないことを引き継ぐ。Decimal の字句処理と Float の全ビットの丸め、L40.29 の Stop、.21 の長さを今回の完了へ繰り上げない。群 C の生 lambda と closure の表現に関する L60/R50 への申し送りもそのまま保つ。

## 検査と受け入れの境界

固定 Lean は `formal/lean-toolchain` の `leanprover/lean4:v4.34.1`。既定ビルドは formal/ から対象なしの `lake build`、単独検査は `lake env lean -M 12288` である。新モジュールを既定 import へ含め、旧主定理や失敗例を除いていない。途中の UInt8 のシフト型、Char の妥当性、構文の等号に対する非計算的な Decidable、Annotation と捕捉の展開等の局所失敗は修正し、最終の各局所検査は終了0になった。各コマンド・本体終了・UTC の開始/終了・外側秒・生出力の bytes/SHA-256 は [checks.json](checks.json) を正とする。

初回末の公理監査は [audit-summary-before-resume1.json](audit-summary-before-resume1.json)。初回は後の正常応答の受渡しを含まないため、[audit-summary-initial.json](audit-summary-initial.json) と分けた。初回末は全710モジュール・69,557宣言で、新5モジュールの645宣言を含む。一覧の全名と `#print axioms` を一対一で照合した。private・生成宣言を含み、公理依存は propext・Quot.sound・Classical.choice の部分集合だけである。新公理・sorryAx・ofReduceBool・監査 error は0。

| 現行の証拠 | 終了 | 外側秒 | 内容 |
|---|---:|---:|---|
| final-build-3 | 0 | 1.347 | 新5モジュールと正常応答の三条件を含む、対象指定なしの既定 lake build |
| axioms-final | 0 | 38.720 | Python の照合を含む全監査。Lean 本体は38.341秒 |
| work-selection | 0 | 0.116 | --only なしの選択確認。仕様対応の自己検査・集計、仕様例、既定全 Lean/sorry 拒否 |

最終の work と verify.py の結果は末尾へ追記する。work は指定の B_WORK と --base だけを使って一度実行する。Rust の本体・テストは変更していないため、Rust 全 lib/clippy の追加実行はしない。

生出力は `<tmp>/l40-d/` に置く。全宣言の生の監査出力は12,319,540 bytes、SHA-256 `1d71bcc6b899d16c70c905c04cf562511f4c87f4d48da550571a5b3435b6b066`。対象名の全一覧は4,244,311 bytes、SHA-256 `0e500bfa8a49e5b508be22c3c0c119542fcdee5649acafbe1b2804b3a897dac1`。改造内の各記録は100 KB 以下とし、入力・記録の照合は [verify.py](verify.py) で再生成する。

Lean の具体例には test-audit の作成時の関門を適用した。所有する境界は、実変換/実応答から型付け・篩・実行へ渡す契約である。Some/None と Stop、数値とビット/仮数の表現、capture 内の Boolean の事実の取り違えを捕まえる。既存の型域・有限論理だけの例は名前による応答表や実本体を通らず、今回の境界を検査しない。既存テストは削除0、Rust のテスト変更0、試験用の実装フラグ・差し込み口・利用者 API の追加0である。

### 作業末の work と最終照合

`scripts/check.sh --level work --base 5e2012958fe8aab1edca8587ec8dd731a1527a82` を一度実行し、終了0、外側7.931秒となった。`--only` は付けていない。選ばれた仕様対応の自己検査・集計、仕様例7件（失敗0・無視0）、既定全 Lean と sorry 拒否が成功した。生出力は5,847 bytes、SHA-256 `d9ede7575a8bca3e7709b740da1b72307f40df7af4affede60f5a7e187142080`。Rust 全 lib/clippy・全比較・性能測定の追加実行は0である。

`verify.py` の照合は終了0。五つの既定 import、公理監査との宣言一覧の件数一致、実ソースの再収集、義務64行、work の実行が一回で指定どおりであること、各記録100 KB 以下、相対リンクと入力を照合した。新5モジュールは、手書きの名前付き公開117・private35、ほかの環境宣言493（構成子・instance・生成宣言等）で計645宣言である。匿名の87例は環境に保持される宣言と別に既定ビルドで検査する。全 Lean ソース721ファイルの一覧は `<tmp>` に置き、bytes/SHA-256 を [inputs.json](inputs.json) へ保存する。各本番入力と記録の SHA-256、verify の開始・終了・秒も同ファイルに残す。

| 最終報告前の照合 | 判定 |
|---|---|
| L40.16 七整数型の定数・算術・比較・明示変換と実応答 | 担当分完了。Stop の全幅の整理は .29 |
| L40.17 Byte/Character/Bytes の値域と実導入・射影 | 担当分完了。長さの標準応答は .21 |
| L40.18 Float 二幅の12分類・12比較と特殊値 | 担当分完了。全ビットの丸めは外側 |
| L40.19 Decimal の正常値・五モード・六比較・再検査 | 担当分完了。96 bit の仮数部と128 bit の保存係数を区別 |
| L40.20 前提を読む length_le、Not を使う実本体、同じ捕捉と実行 | 担当分完了。unknown・未到達の右辺を含む |
| 実 .bnt の型・名前と Rust 本体の照合 | 109署名・実名の不一致0。全239 API の原宣言と36入力を保存 |
| 単位の開始/終了の同時点の記録 | 全五単位で実施。後の照合の追加は checks.json に分離 |
| 固定署名・規則・主定理・新公理・独立の信頼条件 | 変更/追加0 |
| 公開入口の読者・既定 import・写し | 全新モジュールで実施。型付け/部分型/具体例の適用を既定ビルドで検査 |
| private・生成宣言を含む公理監査 | 645追加宣言を含む全69,557宣言。許可三公理だけ |
| 本番コメント/写しの工程ID・手元の絶対パス・新しい用語 | 初回の自己点検で B04 を見落とした。再開1で除き、検出の自己検査を追加。写しには現在の性質と実前提を記す |
| 既定ビルド・作業末の work・記録照合 | 終了0。work の実行は指定の一回 |
| 各記録100 KB 以下・全名/一覧を再生成する台本 | audit.py・axioms.lean・sources.py・verify.py を保存 |
| 初期の局所試行の生ログの欠測 | 上記のとおり L40.16 の初期だけ未取得。最終検査で代用したとは書かない |
| 独立レビュー・設計者の受け入れ | 今回の担当による実施0。取りまとめ・設計者へ渡す |

上表は担当の自己点検であり、独立レビュー済みとは扱わない。完了した D の技術の担当分と、未実施の全標準行の充足・Rust/Lean の全比較・主定理の合成・受け入れを区別して引き渡す。

## 再開1: RV-L40.d の処置

開始 2026-11-03T12:33:40.780348+00:00（UTC）。中1・軽1〜5・情報1〜3を処置する。開始時に、最初の単位 L40.16（中1・情報1）を開始した。単位の終了は完了時に追記する。

L40.16（中1・情報1・Option 共通入口）の終了 2026-11-03T12:39:22.126226+00:00。床演算・absolute・min/max・bitwise・shift・負号の全幅の名前の等号と具体例、共通 Option 型付けを追加し、局所検査成功。L40.17（軽1・軽3・軽5）を同時刻に開始した。

L40.17 の終了 2026-11-03T12:40:41.307509+00:00。Byte 六比較・Byte/Character の引数検査と Option 型付けを追加し、既定ビルド成功。L40.18（軽1）を同時刻に開始した。

L40.18 の終了 2026-11-03T12:41:35.198227+00:00。Float 二幅の引数検査を共通化し、既定ビルド成功。L40.19（軽1・軽2・軽3）を同時刻に開始した。

L40.19 の終了 2026-11-03T12:43:34.611397+00:00。Decimal.fromFloat の名前付きの行と再検査の読者、各 Option 応答の型付けを追加し、既定ビルド成功。L40.20（合成した適用例・軽4・照合記録）を同時刻に開始した。

L40.20 の終了 2026-11-03T12:46:53.647904+00:00。等値比較の合成例、同じ Option 構成子宣言を供給する適用例、docstring・写しと照合台本の修正を行い、既定ビルド成功。以下で全宣言の公理監査と今回一度の work 検査を行う。

### 指摘の処置と判定

取りまとめの判断（plan「計画の変更と取りまとめへの確認点」の先頭）を適用した。群 A〜C の固定署名・型付け・Step・主な十言明・CoreAssumptions の変更は0である。D の部分表の型・行・範囲引数をそろえる変更は、今回の軽1の指示の範囲で行った。

| 指摘 | 処置と本番の読者 | 判定 |
|---|---|---|
| 中1 | `integerDelta_floor/absolute/minMax/bitwise/bitwiseNot/shift/negate`。任意の IntKind と表現可能な実入力から、名前で引いた δ と同じ幅の本体の等号を証明した。floor と min/max は各二種、bitwise は四種、shift は三種。論理右シフトと負号は実 API のある符号付きの幅に限る。七幅の床演算と各入口の具体の適用例を既定ビルドに置いた | 完了。O124・O046 の D 分の証拠を更新。Stop の全幅の条件は .29 |
| 軽1 | 整数の型引数の読取りを `scalarTypeCore` に合わせ、Character・Float 二幅・Decimal、追加の Byte の表には `scalarArguments/scalarDelta` を適用した。等値は型引数一つ、篩を外した芯と実定数の基本型が一致、行・範囲引数は空。他の項目は三引数列とも空。`scalarReplies/equalityCalls` が六つの表を合成し、全七整数幅・Byte・Character・Float 二幅・Decimal の `%eq/%ne` について受理二件（基本型・篩付き）と拒否五件（空・重複・異なる基本型・余分な行・範囲）を検査する | 完了 |
| 軽2 | `decimalFromFloatDelta` に `Decimal.fromFloat` の名前付きの行を置いた。解析結果を入力として受け、同じ `decimalConversionReply` による再検査と `decimalFromFloat_typed` を接続した。具体例は有効な Some、解析失敗の None、表現外を再検査した None。Float のビット列から表記を作り解析した結果との一致は結論しない | 完了。名前付きの行を .28 へ送らない。表記の生成と解析は外側 |
| 軽3 | `scalarOption_typed` と各読者が Some と None を `HasTypeVQ` の構文規則 V_Con で型付ける。同じ P の Some・None の実宣言と Option の型引数数1を明示し、適用例の `optionProgram/optionArity` がそれを供給する。対象は各小幅の fromInteger、Byte・Character の fromInteger、u64 の toInteger/fromDecimal、Decimal.truncate/fromFloat。各変換に正常な Some/None の両入力の適用例を置き、明示的な両構成子の型付けも置いた | 完了。全標準表の P との収集・照合は .28/L60 |
| 軽4 | docstring の B04 を除いた。verify.py は L・B・O・TODO・RV の工程 ID を検出し、B04/B15-2/L40.16 等の陽性例と型名・16進数等の陰性例を自己検査する。01-12・07-04 から形式化していない Float 成分の構造比較の文を除いた | 完了。処理系の事実は下の照合記録へ移した |
| 軽5 | `byteDelta` に `%Byte.less/lessOrEqual/greater/greaterOrEqual` と `%eq/%ne` の六比較を追加。`byte_compare` は任意の UInt8 二値・六比較について名前付き応答、Boolean 型付け、同じ整数値の有限述語を一緒に返す | 完了。L40.17 の D 分。O046・O125 に証拠を追記 |

### 実物との照合と申し送り

等値の型引数は、処理系の [builtin_scheme](../../../../crates/benitoite/src/builtins/table.rs) の996〜1007行（一つの value 型引数 T、Equality 制約、二引数とも T、結果 Boolean）を正とした。[型検査の具体化](../../../../crates/benitoite/src/typeck/context.rs) の745〜804行はその一つの引数を作り、同じ Equality 制約を登録する。[呼出しの検査](../../../../crates/benitoite/src/typeck/calls.rs) の615〜632行は実引数を同じ仮引数の型へ接続する。01-12 の組み込み参照と型引数の検査の規則に従い、型引数の省略を δ の入口で補わない。篩の真そのものは呼出しの型付けで扱い、部分表のタグと引数の検査から導かない。

[sources.py](sources.py) を再実行し、19標準モジュール・239公開関数・109署名を照合した。Rust の登録名は、全七幅の床演算・absolute・min/max・bitwise・shift の連結名と、符号付きの論理右シフト・負号まで照合する。Byte の六比較、fromFloat の実名も対象に含む。Rust の型検査の3ファイルを追加し、識別する実入力は39ファイル、不一致0である。処理系・標準ソースの変更は0であり、この静的照合を Rust/Lean の全比較とは数えない。

Float 成分を構造比較の中で IEEE の等号で比べるのは、処理系の [runtime/equal.rs](../../../../crates/benitoite/src/runtime/equal.rs) の147〜148行を読んで確かめた事実である。Lean ではこの構造比較を形式化していないので、01-12・07-04 の写しには置かない。

| 情報の申し送り | 処置・後段への境界 |
|---|---|
| 情報1 | `integerDelta_binary/fromInteger/equality/toInteger/order` の5定理から maxHeartbeats の引上げを全て除いた。変換が元の値を返す補題を分け、simp に大きな数値範囲を展開させず、必要な本体だけを展開する。追加の全幅の7定理も引上げなしで既定ビルド成功。表の振分けの定義と先行の署名は保った |
| 情報2 | 独立レビューの参考 RSS 2,049,605,632 bytes は [RV-L40.d](../../reviews/RV-L40.d.md) の再監査の値である。今回の担当の RSS は未取得（計画上の非採取）で、参考値を今回の正式値へ転記しない |
| 情報3 | 連結名の照合を床演算・min/max・bitwise・shift まで sources.py に拡張した。標準ソースの署名と Rust の登録の照合を両方残す。全行の BuiltinArgs・宣言表との収集と具体モデルの充足は .28/L60 で行う |

### 再開1の単位別の時刻と外側の時間

開始・終了は単位を始めるときと終えるときに本節へ記録した。下表は [resume1-times.json](resume1-times.json) の同じ値であり、能動時間と待ちは分離していない。

| 単位 | 開始（UTC） | 終了（UTC） | 外側の秒 |
|---|---|---|---:|
| L40.16 / 中1・情報1 | 2026-11-03T12:33:40.780348+00:00 | 2026-11-03T12:39:22.126226+00:00 | 341.346 |
| L40.17 / 軽1・軽3・軽5 | 2026-11-03T12:39:22.126226+00:00 | 2026-11-03T12:40:41.307509+00:00 | 79.181 |
| L40.18 / 軽1 | 2026-11-03T12:40:41.307509+00:00 | 2026-11-03T12:41:35.198227+00:00 | 53.891 |
| L40.19 / 軽1・軽2・軽3 | 2026-11-03T12:41:35.198227+00:00 | 2026-11-03T12:43:34.611397+00:00 | 119.413 |
| L40.20 / 合成読者・軽4・照合記録 | 2026-11-03T12:43:34.611397+00:00 | 2026-11-03T12:46:53.647904+00:00 | 199.037 |

単位の区間の合計は 792.868 秒。単位開始 2026-11-03T12:33:40.780348+00:00 から記録の終了 2026-11-03T12:50:30.420919+00:00 までは 1009.641 秒である。先行した依頼文・レビュー等の読取りは計測開始前で、この秒数には含めない。末尾の記録照合の開始・終了と秒数は inputs.json に別に保存する。この外側の値を能動時間や後段の一件当たりの所要時間に換算しない。

### 再開1の検査と最終の照合

全コマンド・開始/終了・終了状態・外側の秒・生出力の大きさと SHA-256 は [checks.json](checks.json) に保存する。生出力は `<tmp>/l40-d-r1/` に置き、改造内へ大きなログを置かない。途中の局所試行の失敗は、Option の構成子の展開、変換の等号からの出力の範囲への書換え、RangeExpr の構成子等の補助証明を直して再確認した。初回の既定ビルドは変更中の Byte の補助証明で失敗し、修正後の既定ビルドで閉じた。以後は検査中に本番のファイルを編集していない。

| 検査 | 結果 | 外側の秒 |
|---|---|---:|
| formal/ から対象なしの既定 lake build | 終了 0 | 1.909 |
| private・生成宣言を含む全既定モジュールの公理監査 | 終了 0 | 40.128 |
| 指定 work の dry-run による選択の確認 | 終了 0 | 0.117 |
| 指定 work：仕様対応の自己検査と集計・仕様例・既定全 Lean と sorry 拒否 | 終了 0 | 3.754 |

work の本体は今回一度、`scripts/check.sh --level work --base 5e2012958fe8aab1edca8587ec8dd731a1527a82` を実行した。`--only` は使っていない。仕様例は7成功・0失敗・0無視。Rust 全 lib/clippy・全比較・性能測定の追加実行は0である。初回の work と今回の work は checks.json の `work` と `r1-work` に分け、verify.py がそれぞれ一件で同じ指定であることを検査する。

公理監査は [audit-summary.json](audit-summary.json) を現行とする。初回末は audit-summary-before-resume1.json に保管した。現行の全710モジュール・69,677宣言の全件について、対象一覧と #print axioms の一対一を照合した。依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAx・ofReduceBool・監査エラーは0である。

| 新5モジュール | 現行の環境宣言数 |
|---|---:|
| StandardByteCharacter | 160 |
| StandardDecimal | 141 |
| StandardFactExamples | 93 |
| StandardFloat | 24 |
| StandardInteger | 347 |

合計765宣言（初回645から純増120）。手書きの公開143・private47、その他の環境宣言575であり、匿名155例は別に既定ビルドで検査した。全宣言名は台本で再生成する `declarations-<モジュール>.json`、手書きの名前と例の件数は declarations.json に置く。公理監査の生出力は 12378817 bytes、SHA-256 `d88f2475c0fe02a7a14ce761054714b49cec42353ebcd25dd375520c08c0208e`。対象名の一覧は 4259299 bytes、SHA-256 `ea8694f827dd371dca6a00d3a305e40bdc47589537a8a1c2105f8cbf0eaaa0b5`。

verify.py の照合は終了0。新5本の既定 import、全 Lean 721ファイルの入力、宣言一覧と監査の件数、実ソースの再収集、義務64行、今回一度の work、工程 ID の自己検査、相対リンク、各記録100 KB 以下を確認する。各記録と本番入力の現行 SHA-256 は inputs.json に再生成して保存する。

| 最終報告前の担当の照合 | 判定 |
|---|---|
| 中1の全幅の名前から本体への等号、O124・O046 | 完了。Stop の全幅の条件は .29 のまま |
| 軽1の引数の一貫性と合成した受理・拒否 | 完了。全七整数幅と他の五基本型、両等値名で確認 |
| 軽2の fromFloat の行と再検査の読者 | 完了。表記の生成・解析は外側 |
| 軽3の Some・正常な None の型付け | 完了。同じ P の構成子宣言と型引数数を具体の適用例で供給 |
| 軽4の本番の工程 ID と写しの範囲 | 完了。工程 ID の検出の自己検査を追加 |
| 軽5の Byte 六比較 | 完了。L40.17 の担当として証明し O046・O125 へ反映 |
| 情報1〜3の処置と一行ずつの申し送り | 完了。5定理の maxHeartbeats の引上げ0 |
| 既定ビルド・公理監査・今回一度の work・記録照合 | 終了0 |
| 保護したファイルと署名、公理・信頼・提供範囲 | 群 A〜C・plan/detail/README/レビュー・処理系・旧 Release の変更0。新公理・独立の信頼条件・提供範囲の縮小0。git の操作0 |
| 独立レビューと受け入れ | 本節は担当の自己点検。再開1の独立レビューと受け入れは取りまとめ・設計者へ渡す |

新たに取りまとめの仕様判断を求める停止事項はない。残る担当は、.28 の全標準行と実宣言表・BuiltinArgs の照合、.29 の Stop の全幅の条件、L60 の具体モデル、L70/R50 の合成と Rust/Lean の全比較である。Option の局所型付けや fromFloat の名前付きの行を、それらの全体の充足と同一には扱わない。

## 作業末の work

取りまとめが、再開1の後に、Refinement の生成物を消してから、sandbox の外で macOS の `/usr/bin/time -l` を付けて一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 5e2012958fe8aab1edca8587ec8dd731a1527a82` | 0 | 173.27秒 | 1,695,973,376 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。機械は Apple M4・メモリ 32 GiB、OS は macOS 27.2。最大常駐量は `/usr/bin/time` が報告した、`check.sh` とその子のプロセスのうち最大のものの値であり、計測器自身の分と分けていない。

## 取りまとめの申し送り

- L60: `Decimal.fromFloat` の具体表を作るとき、解析結果 `parsed` を同じ Float のビット列から作っていることを確かめる（RV-L40.d の再レビューの情報R1）。

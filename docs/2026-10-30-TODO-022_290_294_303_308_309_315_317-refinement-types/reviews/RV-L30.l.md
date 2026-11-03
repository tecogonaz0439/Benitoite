# RV-L30.l: L30 群 L・M・N（L30.67〜.80）と L30 段末の照合資料の独立レビュー

2026-11-03。対象はブランチ `m014/l30.l` の未コミットの作業木、基準 `c30b5b34`（san_benito の先端）。新規の Lean 6本（CoefficientModel・StepAccounting・AccountingWork・ProofContract・ProofContractExamples・ProofReplayExamples）は全文を読んだ。既存の変更（`formal/Benitoite.lean`・01-12・07-04・effort-ledger）は `git diff` で読んだ。群の記録は `l30/l/` の results.md・signatures.md・r20-contract.md・review-handoffs.md・case-completion.md・review-response.md・records.py・finalize.py・各 json・replay.lean・signature-check.lean を読んだ。段末の資料は `l30/stage-results.md`・`axioms.lean`・`audit.py`・`audit-summary.json` を読んだ。

根拠として README「設計者の決定」の 2026-10-30（ステップ数の訂正）と 2026-11-03（U03）、`l30/detail.md` の第4節・第6節の L30.67〜.80 の行・第7〜11節、各群の results.md の申し送りの節、`reviews/RV-L30.{a,b,d,f,h,j}.md`（所見と取りまとめの追記）、plan.md の「義務の対応表」と「計画の変更と取りまとめへの確認点」の L30 の項を読んだ。形は `l20/stage-results.md` と `RV-L20.s.md` に合わせた。補助の入力と再実行の出力は `<tmp>/rv-l30-l/` に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**（重0・中1・軽6、情報3）。中1を処置すれば、段末の受け入れの資料として可とする。

U03 の四点は Lean の実物に反映されている。`CoefficientRepresented` は幅を引数に保ち、128 は `storageBits` の値としてだけ現れる。保存（`save`・`binary`・`neg`）と正確な一時計算（`temporaryProduct`・`decimalAligned`）は別の定義で、u64 最大値の積（符号付き129ビット）と Decimal の桁合わせ（192ビットで表せる）が保存幅を超える対照もある。`step` は各操作で使用数を 1 だけ増やし、重み・段ごとの上限・別の unknown を持たない。`create` は `used + reserved + 2 ≤ limit` を確かめて使用数と予約を一つずつ増やし、`destroy` は予算を新たに要求せず予約を一つ使用済みへ移す。`step_valid`・`run_valid`・`run_used`・`destroy_once`・`rollback_all` の言明は決定どおりである。三種の停止は別の構成子であり、版の字面は `proof-steps-v1` である。

段末の公理監査は再実行で一致した。台本の出力先だけを `<tmp>` に変えて `axioms.lean` を実行し、終了0、外側38.41秒、最大常駐量 2,034,319,360 バイトだった。688モジュール・67,881宣言で、対象名の一覧の SHA-256 は記録の `4ea79ab2…` と一致した。依存集合の七つの件数も記録と一致した。`signature-check.lean` は終了0、`replay.lean` は17行すべて true で終了0だった。35義務は plan の L30 担当31行と共通4行に機械的に一致した。申し送り63行は元の14行と六レビューの49所見に一件ずつ対応した。

中1は R20 へ渡す契約の不足である。`AccountingWork` の操作列が `proof-steps-v1` の規範の数え方なのか例示なのかが、どの文書にも書かれていない。軽はコメントの工程ID（O118 の判定と食い違う）、負の除数の除算の意味、三停止の証拠の書き方、docstring の強さ、32ビット構成の記録、申し送りの分類の基準である。主な言明・型付けの規則・公理に触れる所見はない。

## 群 L・M・N の所見

### 中

#### 中1: `AccountingWork` の操作列が `proof-steps-v1` の規範か例示かが決まっておらず、一部の数え方は決定 (2) の読みと合わない（読めば確定。数は補助入力で確認）

- 場所: `AccountingWork.lean` の `compareBytes`（11〜21行）と `merge`（59〜71行）、`l30/l/r20-contract.md`「全実作業との照合を受け持つ読者」の表、README 2026-11-03 の (2)・(3)。
- 問題点: 版の字面を固定する目的は、同じ版のもとで同じ入力の使用数が一つに決まることである。ところが、Lean の具体の列（`compareBytes` の一致した1位置で `node`・`element`×2・`readByte`×2・`compareByte`・`edge`×2 の8操作、`merge` の1位置で13操作）を v1 の規範とするのか、数え方の一例とするのかが書かれていない。r20-contract は「R20 は実際の各基本操作の直前に予算を確認する」と書くだけで、R20 が Rust の実際の操作を独自に数えれば、Lean の列と違う使用数でも v1 を名乗れる。逆に規範とするなら、次の点が決定 (2) の「一 byte の読取り・比較は一 byte、固定幅の算術は一演算」と合うかを確かめる必要がある。
  - `compareBytes` は同じ byte に `element` と `readByte` を別々に数える。連続した byte 列では一つの読取りであり、一つの基本操作を二回数える読みになる。
  - `merge` は1位置ごとに `compareWord` を6回数える（入力二つの上下端4回と結果の2回）。保存域から読んだ i128 は既に表現可能であり、Rust の検査付き加算はこの6回の比較を別に行わない。
  - `merge` は入力が表現外のとき、`add` と結果の比較を含む同じ10操作の列を返す（補助入力で、入力 2^127 と 0 でも長さ10を確認）。実行していない演算を数えている。
- 修正案: 取りまとめが次のどちらかを選び、r20-contract.md の冒頭と 01-12「篩の係数と基本操作の計上」に一文で書く。(a) `AccountingWork` の列は対応の例示であり、v1 の規範の数え方は R20 が Rust の操作の表として固定し、R50 で Lean の対応の資料と照らす。(b) `AccountingWork` の列を v1 の規範とする。(b) を選ぶ場合は、`element` と `readByte` を別の操作とする理由を書き、`merge` の範囲比較と失敗時の列を実際に行う操作に合わせて直す。どちらでも主な言明と予約の規則は変わらない。

### 軽

#### 軽1: 新しい本番のコメントに工程ID「R20」が3箇所あり、O118 と case-completion の判定に反する（読めば確定）

- 場所: `ProofContract.lean` 48行（`replayProof` の docstring）・70行（`Accepted` の docstring）、`ProofContractExamples.lean` 151行のコメント。`l30/l/case-completion.md` の末段（「工程ID…はない」）、`stage-results.md` の O118 の行（「工程ID/絶対パスを追加せず」）、`l30/l/records.py` 170行の禁止語の正規表現。
- 問題点: O118 は「本番コメント/期待値に作業IDを残さない」であり、AGENTS.md の実装の規約もコメントに作業の ID（R21 など）を引かないと定める。基準の追跡済みの Lean には段ID の一致が0件で、今回の3件が初めてになる。records.py の正規表現は `L30\.\d` だけを見るので、`R20` を検出しない。
- 修正案: コメントを「全実作業と actions の一致は、検査器の実装のレビューで照合する」のように段ID を使わない言い方に改める。records.py の正規表現に `\b[LRKVD]\d{2}[a-z]?\b` 程度の段ID を加え、O118 の行と case-completion を再生成する。

#### 軽2: 負の除数の除算の意味が R20 へ渡されていない（Lean で確認）

- 場所: `CoefficientModel.lean` の `Binary.eval`（27〜29行）、01-12「篩の係数と基本操作の計上」第1段落、r20-contract.md「成功した部分演算」の行。
- 問題点: `binary` の除算は Lean の `Int` の `/`（ユークリッド除算）である。補助入力で `binary 128 .divide 3 (-2) = some (-1)`・`binary 128 .divide (-3) (-2) = some 2` を確かめた。後者は床（1）とも零方向（1）とも異なる。r20-contract は「正の除数の床は言語の零方向への除算と区別する」と正の除数だけを書き、負の除数で Rust が `/`・`div_euclid`・`div_floor` のどれに当たるかを書いていない。線形の丸めは正の除数だけを使うので健全性には影響しないが、`Operation.divide` を一般の固定幅の演算として渡すなら意味を決めておく必要がある。
- 修正案: r20-contract の行に「負の除数ではユークリッド除算（Rust の `i128::div_euclid` に当たる）。最小値と −1 は保存幅の外で拒否する」と書く。又は `binary` の除算を正の除数に限り、負の除数を `none` にする。

#### 軽3: 三停止を証明済みにしない証拠は結果の型の区別だけで、計上と再生を結ぶ定義がない（Lean で確認）

- 場所: `ProofContract.lean` の `replayProof`・`stopped_not_proved`・`ProofContract.Accepted`、`l30/l/results.md` の L30.71 の行、stage-results.md の O026・O158 の行。
- 問題点: `stopped_not_proved` は `rfl` で、`replayProof` は `stepsExhausted` を返さない。計上の `run` と再生を合わせて `ProofResult` を返す定義はなく、「入力検査の途中で尽きたものを proved にしない」（detail 第4節）を示す Lean の定理はない。`Accepted` は `actions` と証明書を結ばないので、補助入力で上限0・空の操作列でも `Accepted premise goal twice 0 [] (initial 0)` が成り立つことを確かめた。r20-contract と 01-12 は記録が全実作業を覆うことを結論しないと正しく書いており、誤りではない。L30.71 の「別の結果形」の完了条件は満たしている。ただし results の L30.71 の行が「unknown を証明済みや実反例にしない」を証拠付きの性質のように書いている。
- 修正案: 次のどちらかを取る。(a) `ProofContract` に `checkAccounted limit actions p q c : ProofResult`（`run` の失敗を `stopped` に写し、成功時だけ `replayProof` を呼ぶ）を置き、`isProved = true → Accepted …` を示す。(b) 定義を足さない場合は、L30.71 の行と O026・O158 の証拠に「結果の型で区別する。計上と再生を一つにした手続きは R20 の実装で作る」と書く。

#### 軽4: docstring の三点が言明より強い（読めば確定）

- 場所と問題点:
  - `ProofContract.lean` 9行の `input_certificate_expansion` の docstring「I・C・展開後の P は、実際に行う基本操作の列である」は、仮定を事実のように述べる。言明は連結の長さと使用数の増分の等式だけである。01-12 の「基本操作列として与えた場合」は正しい。
  - `ProofReplayExamples.lean` 7行の「同じ列を、核内の decide と実行時の再生の両方へ渡す」。実行時の再生は改造の記録の `l30/l/replay.lean` だけにあり、既定のビルドには含まれない。07-04 の「核内の decide の照合を置く」は正しい。
  - `CoefficientModel.product_then_save` は仮定 `ht` をそのまま結論へ返すだけである。01-12 の「一時積の表現幅と保存幅は別に検査する」の根拠としては、一時の幅で計算する定義がないことを示すに留まる。
- 修正案: 一つ目を「I・C・P を基本操作列として与えた場合の、使用数の増分」とする。二つ目を「同じ列を核内の decide で検査する。実行時の再生は同じ `rows` を読む」とする。三つ目は docstring に「一時の表現可能性は前提として受け取り、計算はしない」と書くか、01-12 の文を「一時積の表現可能性と保存の表現可能性を別の前提に取る」と直す。

#### 軽5: L30.67 の「32ビット構成の照合」の扱いが記録にない（読めば確定）

- 場所: detail 第4節「係数幅の判断 J30-1」の「32ビット構成で同じ意味を保つ」、第6節の L30.67 の行（「32bit構成と表現外を照合」）、`l30/l/results.md` の L30.67 の行、r20-contract.md の「保存幅」の行。
- 問題点: Lean のモデルは `Int` と幅の引数だけを使い、ホストの幅に依存しないので、32ビット構成でも同じ意味である。ただ、この根拠が L30.67 の行に書かれていない。r20-contract は lookup の行で「32ビット構成も同じ数学の番号を読む」と書くが、係数の i128 の行には32ビット構成を書いていない。stage-results の J30-1 の残りは「32ビット構成の変換」を R20 に残すので、受け渡しの所在はある。
- 修正案: results の L30.67 の行に「モデルは Int と幅の引数だけを使い、ホストの幅に依存しない。usize への変換と32ビット構成の i128 は R20 で確かめる」と書き、r20-contract の「保存幅」の行にも同じ受け入れ条件を加える。

### 情報

#### 情報1: `StepAccounting.State`・`step`・`run` は親の名前空間の `Refinement.State`・`step` 等と同名である

補助入力で `open Benitoite.Release.Refinement` と `open StepAccounting` を併せると `State` が曖昧になった。results.md も初回の失敗に名前解決を挙げている。証明の誤りではないが、L40・R20 の読者が例を書くときは名前空間を明示する必要がある。改名するなら `StepState`・`stepAction` などが候補である。

#### 情報2: `rollback_all` は `Valid` を前提にしない

補助入力で、予約が重複した不正な状態 `⟨1,0,[(0,.body),(0,.body)],1⟩` に rollback を当てると使用数2で上限1を超えた。上限の中に収まることは `rollback_within_limit` が `Valid` から示しており、問題はない。R20 で予約の一意性を実装側で守る必要があることの例として記す。

### 確認した事項

#### 1. U03 の契約（観点1）

- 保存幅: `CoefficientRepresented bits n` は `0 < bits ∧ -(2^(bits-1)) ≤ n < 2^(bits-1)`。`storageBits = 128` は定数で、補題はすべて `bits` を引数に取る。両端（−2^127、2^127−1）の受理、外側の拒否、`save 0 0 = none`、最小値と −1 の除算・最小値の負号・最大値＋1 の拒否は `coefficient_endpoints`・`coefficient_operations` が `decide` で示す。
- 一時計算: `u64_temporary` は u64 最大値の積が `CoefficientRepresented 129` を満たし、保存できず、本番の `IntKind.checkedMul .unsignedInteger64` が `.rejected .overflow` を返すことを示す。`decimal_exact` は有効な最大係数と scale 28 の桁合わせが 128 を超えて 192 に収まり、比較の結果が本番の `Observation.compare` と一致することを示す。`decimal_compare` は定義上の等号（`rfl`）である。
- steps: `step` の三腕は決定どおりで、`.work` は段（`Phase`）を読まない。重み・段ごとの上限・深さや枝数の unknown はない。`State.Valid` は `used + reserved ≤ limit`・予約の一意性・番号の範囲で、`remaining_exact` が三つの和を示す。`destroy_once` は `Valid` の一意性から二度目の破棄を `malformed` にする。補助入力で、種類の違う予約の破棄も `malformed` になることを確かめた。`execute` は停止の直前の状態を返し、`execute_valid` で不変条件を保つ。`reservations` の例は、残り0で読取りが `stepsExhausted` になり、そのあと予約済みの rollback が成功する経路を示す。
- 停止: `ProofStop` は三構成子で、表現外（`storeCoefficient`）と steps 超過（`run`）は別の経路から出る。`ProofResult` に反例の構成子はない。版の字面は `StepAccounting.version` と `ProofContract.stepsVersion` で一致する。

#### 2. R20 への契約（観点2）

- r20-contract.md は、Lean で示したこと（列長と使用数、不変条件、予約、三停止、raw 成功からの含意）と、R20 の実装レビューに残すこと（操作列が全実作業を覆うこと、各操作の直前の確認、所有・共有 prefix・明示スタック）を表で分けている。CPU 時間・証明書の byte 数だけへの線形・allocator の時間を保証しないと明記し、未証明の線形の主張はない。不足は中1・軽2・軽5である。
- `Accepted.sound` の結論（含意・`final.used = actions.length`・`final.Valid`）は二前提から正しく導かれる。前提に記録の網羅を足していない。

#### 3. 再生と核内の照合（L30.74）

- `rows_checked` は17行を `decide` で検査し、`replay.lean` は同じ `rows` を実行して false と件数の不一致で失敗する。再実行で17行すべて true、終了0だった。`native_decide`・`#eval` は新規の6本にない。

#### 4. 新規の宣言と禁止構文（観点6）

- 名前付きの手書き宣言は 15・26・14・13・14・2 の計84件で、declarations.json の84件と一致した。`sorry`・`native_decide`・`#eval`・`axiom`・`implemented_by`・`unsafe`・`set_option` は新規の6本にない。`formal/Benitoite.lean` は3行の import の追加だけで、既存の import の除外はない。
- 01-12 の新しい節と 07-04 の行は Lean の定義・前提と一致し、経緯の文はない。除算の意味（軽2）と一時の幅の書き方（軽4）を除き、前提を実物どおりに書いている。

## 段末の資料の所見

### 軽

#### 軽6: 申し送りの「済」と「転記」の基準が行によって違う（読めば確定）

- 場所: `l30/l/review-handoffs.md` の「J 軽3」の行と「RV-L00b.04 鍵の等値」の行、`reviews/RV-L30.j.md`「取りまとめの追記」の二つ目の項。
- 問題点: RV-L30.j の取りまとめの追記は「軽3（鍵の値から `KeyShape` を供給する補題）と情報2・3は L40 への申し送りとして残す」と書く。処分表は情報2・3を「転記」としながら、軽3を「済」とした。同じ内容（型付きの鍵から `KeyShape`・`ClosedSlots` を L40 が供給する）の RV-L00b.04 の行は「転記」である。「済」の中には後段の担当を持つ行（L20群I/J/N の行など）もあり、判定の基準が表の冒頭の説明（「済」は L30 の担当分の処置）だけでは行ごとに決まらない。
- 修正案: J 軽3 を「転記（L40）」とし、集計を済52・転記11に改める。又は、軽3の L30 分の処置（記録への明記）を「済」とする理由を行に書き、RV-L00b.04 との違いを示す。stage-results.md と completion-summary.json の件数も同じ変更で直す。

### 情報

#### 情報3: 公理監査の対象は既定の import の閉包であり、既定の外のファイルが一つある

`axioms.lean` は `import Benitoite` の閉包の 688 モジュールを対象にする。`formal/Benitoite/` の下の Lean ファイルのうち、`Benitoite/Release/LegacyCheck.lean`（0.0.8 から、どこからも import されない）だけが閉包の外で、ビルドにも監査にも入らない。今回の変更ではなく、stage-results の「既定の新旧全モジュール」という書き方は正しい。lean_exe の根（DesugarDiff 等）は名前が `Benitoite` で始まらず対象外だが、証明を含まない。段末の資料に既定の外のファイルとして一言書くと、後段の監査で同じ確認を繰り返さずに済む。

### 確認した事項

#### 5. 公理監査（観点5）

- 再実行の結果は「総合判定」に記した。`audit.py` と同じ照合（対象名の整列と重複なし、`AUDIT_TARGET` の印と一覧の一致、モジュールごとの件数の和、`#print axioms` の各名一回、許可三公理だけ）を補助の台本で行い、すべて成り立った。`sorryAx`・`ofReduceBool` の出現は0だった。新規6モジュールの件数（47・285・89・53・16・9、計499）は記録と一致する。
- 対象は所属モジュールの全定数で、private と生成宣言（`match_1`・`proof_1` など）を含む。旧主定理5・三モデル3・十移送は `required` で存在を強制する。匿名の `example` は定数に現れないが、既定ビルドの sorry 拒否と禁止構文の点検で覆う（D 情報3 の処置どおり）。
- 台本は `audit.py --tmp <tmp>` で再生成できる。`audit.py` は要約を改造のディレクトリへ書くので、本レビューでは使わず `axioms.lean` を直接実行した。

#### 6. 35義務（観点4）

- plan の義務の表で担当の欄に L30 を含む行は31行（detail の27行と、取りまとめが加えた O046・O079・O138・O143）で、stage-results の31行と一致した。共通4行（O016・O084・O027・O118）を加えた35行は、stage-results の表の35行と過不足なく一致した。
- 記録の宣言名を形式化のソースと照合し、実在しない名前はなかった（`rows17` は「rows の17行」の略記である）。
- O016 と O027 を「一部」、全体の閉鎖を0行とした判定は、段末の独立レビュー・正式な RSS・受け入れが未実施であることと合う。O118 の「共通記録完了」は軽1の処置まで成り立たない。
- J30-1〜5 と方式の関門 A1〜A5 の表は各群の結果とレビューの判定に合う。L40 へ渡す四入口の署名は signature-check.lean の実物と一致した。
- 見込みの集計（14群の和が 2,825〜5,515分）、台帳の担当12行（約5時間4分）、レビュー8行（約1時間5分10秒）、取りまとめの work 6行（921.30秒）、計画2行・計画レビュー2行は、台帳の行番号と値に一致した。

#### 7. 申し送り63行（観点3）

- 元の14行は `l30/results.md`「レビュー申し送りの照合」の14行と順に一致した。49行は六レビューの所見（A 10・B 6・D 9・F 8・H 8・J 8）と一件ずつ一致し、漏れと重複はない。各行に理由と残る担当がある。転記10行の内訳（元の14行から7、D 情報2・J 情報2・J 情報3）も表のとおりである。分類の基準の一件は軽6に記した。
- 各群の results の申し送りの節（b・d・f・h・j）は群の間の受け渡しで、後の群が処置した。63行の外に残るものはなかった。

#### 8. 記録（観点6）

- 改造に保存した記録はいずれも 100 KB 以下である（最大は audit-summary.json の 35,590 バイト）。手元の絶対パスは records.py の検査用の正規表現だけで、docs/todo へのリンク、`work/`・`reference/` への参照はない。

## 補助の入力

`<tmp>/rv-l30-l/` に置いた。

- `audit/`: `axioms.lean` を出力先だけ変えて実行した生出力（`axioms.log`・`targets.txt`）と時間の記録。`check_audit.py` は audit.py と同じ照合を、要約を書かずに行う。
- `probe.lean`: 負の除数の除算二例（軽2）、種類の違う予約の破棄、上限0・空の操作列の `Accepted`（軽3）、表現外の入力の `merge` の列長10（中1）、長さの違う `merge` が先に作った係数の予約を残す例、重複した予約の rollback（情報2）。`cd formal && lake env lean -M 12288 <tmp>/rv-l30-l/probe.lean` で終了0。
- `names.py`: 記録の宣言名を形式化のソースの語と照合する台本。
- `sig.log`・`replay.log`: signature-check.lean と replay.lean の再実行の出力。

## 再レビュー（再開1）

2026-11-03。対象は同じ作業木の再開1の差分である。plan.md の「計画の変更と取りまとめへの確認点」の先頭の項（中1の判断）、`l30/l/results.md` と `l30/stage-results.md` の「再開1」、`l30/l/review-response.md`、新規6本の現行の全文、01-12・07-04 の差分、r20-contract.md・review-handoffs.md・records.py を読んだ。担当の報告は読まず、実物で確かめた。

### 総合判定

**可**（新しい所見なし、情報1）。中1・軽1〜6・情報1〜3は処置済みである。

### 前回の所見の処置

| 所見 | 判定 | 確かめた内容 |
|---|---|---|
| 中1 | 処置済み | r20-contract.md の冒頭、01-12 の節の第1段落と第6段落、07-04 の行が、規範（決定(2)の粒度と `StepAccounting` の状態遷移）と例示（`AccountingWork` の列）を同じ言い方で分け、例示の数を実装の使用数に固定しないと書く。plan の判断と一致する。例示も直っている。`compareBytes` は1位置で `node`・`readByte`×2・`compareByte`（一致なら辺2つ）になり、同じ byte に `element` と `readByte` を重ねない。`merge` は `addCoefficients` を通じ、入力を幅・下端・上端の順に検査し、失敗した時点で止める。`accounting_prefixes` は、上端の外で比較3回、下端の外で2回、右の入力の失敗で9操作、結果のあふれで13操作になり、失敗後の比較・加算・生成を含まないことを `decide` で示す。`readCoefficient_eq` と `addCoefficients_eq` は、例示の値が `save` と `binary` に一致することを示し、`merge_eq` はこれを使う。readCoefficient の「0 < bits」の比較は、数学 Int と幅の引数をとる例示が実際に行う比較であり、01-12 と r20-contract は保存済みの固定幅の入力に同じ比較を課さないと明記する。したがって決定(2)と食い違わない |
| 軽1 | 処置済み | 新規6本に段ID・単位ID・U/J/O の番号の一致はない。records.py の `stage_id` は新規の Lean のソースを検査し、`R20 で`・`（R20）`・`L30.67/L`・`R10b.02`・`D10a`・`L00b.14b-paths` を拾い、`StepState`・`Integer8`・`R200` を拾わないことを確かめた。改造の記録は段ID を正当に使うので、この検査の対象外で問題ない。U03・J30・O118 の形の番号は拾わないが、現行の新規ソースにも追跡済みの Lean にも出現しない |
| 軽2 | 処置済み | 01-12 と r20-contract に、負の除数のユークリッド除算、`3/(−2) = −1`・`(−3)/(−2) = 2`、最小値/−1 の拒否がある。`coefficient_operations` に同じ二例がある |
| 軽3 | 処置済み | `checkAccounted` は `runActions` の失敗を同じ理由の `stopped` に写し、成功時だけ `replayProof` を呼ぶ。`checkAccounted_stopped` は失敗した計上から停止を、`checkAccounted_proved` は証明済みから `Accepted` を導く。後者は `replay_checked` の同値を使い、仮定を空にしていない。`counted_stops` は上限0の steps 超過と不正な破棄で証明済みにならず、上限1で証明済みになる三つを示す。`Accepted` が上限0・空列でも成り立つことは、01-12・07-04・r20-contract と具体例の注釈で限定して書かれ、全実作業の計上の証拠に使わないとしている |
| 軽4 | 処置済み | `input_certificate_expansion` は「I・C・P を基本操作列として与えた場合の、使用数の増分」となった。`ProofReplayExamples` は核内の検査とし、01-12 は `product_then_save` が一時積の表現可能性を前提として受け取り、一時の幅で計算する定義ではないと書く |
| 軽5 | 処置済み | r20-contract の保存幅の行と results に、モデルがホストの幅に依存しないこと、32ビット構成の i128・usize 変換の実行照合は R20 の受け入れ条件で L30 では実行していないことが書かれた |
| 軽6 | 処置済み | review-handoffs.md の行を数え直すと済52・転記11で、J 軽3 は転記（L40）である。records.py はこの件数を assert し、stage-results.md・completion-summary.json・results.md の値も一致する |
| 情報1 | 処置済み | `StepState`・`stepAction`・`runActions` と補題（`stepAction_valid`・`runActions_used` など）に改名され、新規6本・01-12・07-04・r20-contract・case-completion・signature-check.lean・replay.lean に旧名（`State`・`step`・`run`・`run_used` など）は残っていない。旧名を出すのは signatures.md の改名の記述だけである。旧名の別名もない |
| 情報2・3 | 処置済み | 応答の記録に申し送りとして残し、定義と import は変えていない |

### 再実行

- `axioms.lean` を出力先だけ `<tmp>` に変えて実行した。終了0、外側38.26秒、最大常駐量 2,024,751,104 バイト。688モジュール・67,907宣言で、照合（整列・印と一覧・件数の和・各名一回・許可三公理だけ）はすべて成り立った。対象名の一覧の SHA-256 `fd6e9939…` と、依存集合の七つの件数、新規6モジュールの件数（98・47・68・18・9・285）が `audit-summary.json` と stage-results の再開1の表に一致した。`sorryAx`・`ofReduceBool` は0件。
- 新規の Lean の成果物は各ソースより新しい。`replay.lean` は22行すべて true で終了0、`signature-check.lean` は終了0だった（出力中の「error」の2行は `Except.error` を含む型の表示である）。`rows_checked` は22行を核内で検査する。
- 名前付きの手書き宣言は94件で、記録と一致した。35義務の分類（技術31・共通記録完了2・一部2・全体閉鎖0）は変わらず、初回の表の値は「初回」の節に残し、現行の値は「再開1」の節にある。

### 情報

#### 情報4: records.py の `stage_id` は U03・J30-1・O118 の形の番号を拾わない

計画の問い（U）・判断（J）・義務（O）の番号も作業の文書の番号であり、O118 の趣旨では本番のコメントに残さない方がよい。現行の新規ソースにも追跡済みの Lean にも出現しないので、今回の判定には影響しない。後段で同じ台本を流用するときに `[UJO]\d{2,3}` を加えるかを決めればよい。

## 取りまとめの追記

- 中1は、規範を決定(2)の数え方と `StepAccounting` の契約とし、`AccountingWork` を例示とする判断を plan.md の 2026-11-03 の項に記した。中1・軽1〜6・情報は担当の再開1で処置し、再レビュー（再開1）で可とした。
- 段末の work は終了0、159.00秒、最大常駐量 1,704,460,288 バイト（l30/l/results.md）。義務35行の処分は plan.md の義務の対応表へ写した。
- 情報4（records.py が U03・J30-1・O118 の形の番号を拾わない）は、次に records.py を使う段で広げる。

# C1Rb3b の事前点検と未完の記録

2026-10-25。基準 B_WORK は `a05f97303522045d56a0105a437712b7c46dcf38`。開始時の HEAD は基準と一致し、未コミット差分はなかった。指定の枝は `mod012/C1Rb3b`。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 計画からのずれと停止の理由

**C1Rb3b は未完である。** 着手時に定義と証明の依存を点検した結果、D8a の構成子別の走査、その接続に伴う既存証明の更新、入れ子の保存列の証明、独立例までを、この枝の見込み2〜3時間に収めるのは難しいと判断した。暫定見積もりは実装・局所検査・記録を合わせて4〜6時間である。ソースを読んだ見積もりであり、実装の試行による実測ではない。

plan.md「作業の指定」の「着手時の点検または最初の30分で枝の見込みにも収まらないと分かったら、取りまとめが対象・保持する不変条件・依存・検査を追記して再分割する」と、C1Rb3b の行の「着手時に収まらなければ、この枝も最初に分ける」に従い、Lean の実装を変更する前に止めた。今回変更したのは、この結果記録と `reviews/RV-C1-response.md` への追記だけである。plan.md とほかの results.md は変更していない。

C1Rb3a が解消した import の循環は再発見した問題として扱わない。BudgetAnalyze は BudgetIndependentRun を import でき、解析本体より前に independentWith の実行定義を使える。以下は、その整理の後にも残る C1Rb3b の作業量の内訳である。

| 点検した箇所 | 現在の形と必要な変更 |
|---|---|
| `BudgetAnalyze.lean` の expr、IndependentInput.run、independent と `BudgetWalk.lean` の skip 群 | expr の未知の場合と未対応の binary は skipChildren を呼ぶ。run と independent は expr・block の相互再帰の後にあるため、expr からそのまま呼ぶ形にはできない。independentWith へ減少する fuel の expr・block を渡し、Exprs・HoleArgs・Option の容器を宣言順に辿る処理を組み立てる必要がある。別本体・未到達の枝の番号だけの走査は残す。skip の後に同じ子を解析し直す形にはしない |
| `BudgetTraversal.lean` の analysis_walk、`BudgetLocated.lean` の analysis_located、`BudgetRegion.lean` の within_unknown・analysis_within | 現在の未知の場合は skip_walk・skip_located・skip_silent に接続されている。independentWith_walk と independentWith_silent 自体は C1Rb3a で利用可能になったが、構成子別に子・容器・別本体の走査を合成する証明はまだない。その合成を追加したうえで、解析全体の fuel の帰納証明へつなぐ必要がある |
| `BudgetIndependent.lean` の analysis_keepsInputs と `BudgetIndependentSound.lean` の run_contract・run_saves・independentWith_saves | run_saves は、解析が独立入力列を変えないことから導かれる。接続後はこの結論を使えない。run_contract は入力自身の正常値・警告原因・領域を先に与えており、これを independentWith_saves へ渡し、子の実行が追加した入力の健全性を小さい fuel の帰納仮定から与える SavesInputs の証明が必要である。中心二命題を弱める必要があると判明したわけではない |
| `BudgetNormal.lean`・`BudgetCause.lean`・`BudgetBody.lean` と独立例 | 未知の結果は引き続き Top、親の候補は復元するという性質を、接続後の実行について使う。式の証明だけで終えず、analyzeBody の既存の系を再ビルドし、本体入口から保存される独立入力にも保証を接続する。現在の BudgetIndependentExamples は独立入口を直接呼ぶ例であり、未知の構成子からの到達と入れ子を検査する例は追加が必要である |

以上は定義と証明を読んで確認した依存である。試作のビルド失敗や、新しい実行時の反例を再現した記録ではない。新しい Lean 定義・補題・独立例は追加していない。D8a の案 b、言語の規則、中心二命題、対象構文の評価関係、旧主定理、公理、Builtins.Assumptions は変更していない。それらの変更を要することが判明したための停止でもない。

## 取りまとめへの分割案

以下の枝名と割り当ては提案である。計画への登録、範囲・基準の固定、再依頼は取りまとめが行う。依存は表の上から順とし、各枝で既定ビルドと証明済みの範囲を保つ。既存証明を未証明の仮定で置き換えない。

| 枝の案 | 対象と保持する不変条件 | 検査・レビュー・受け入れ | 実装・局所検査・記録の見込み |
|---|---|---|---|
| C1Rb3b1 | Exprs・HoleArgs・Option の走査と、未知の構成子の子を振り分ける補助処理を、Expr/Block の実行を引数に受け取る形で定義する。with の追加位置、handle の保護本体、別本体の区分もここで固定する。番号の先行順、親の候補の復元、入力ごとの契約を仮定した保存列の合成を示す。expr への接続はまだ変えない | 既定 import へ接続し、`formal_build,spec_examples,spec_tally`。定義・言明・仮定と、走査順・予算計上を独立レビューする。レビュー時間は不明。補助処理を完了しても親 C1Rb は未完 | 1〜2時間 |
| C1Rb3b2 | b1 のうち Expr の直接の子を解析本体へ接続し、入れ子を扱う。Walk・正常値・位置・原因・領域を閉じ、analysis_keepsInputs に頼る run_saves を SavesInputs の帰納証明へ置き換える。with の本体と handle の保護本体はこの段では従来の skip のままと明記する。中心二命題と既存の本体入口の系を保つ | 同じ三単位の work と、式の子の内側だけの除数0・あふれ、外の事実の忘却、元の番号、入れ子、途中停止の独立例。定理の言明と公理依存を独立レビューする。レビュー時間は不明。残る Block の接続を完了扱いにしない | 2〜3時間 |
| C1Rb3b3 | with の本体・handle の保護本体も接続する。with の位置0を Top として予算内で構築し、外の事実と子の正常値・return・絞り込みを親へ渡さない。lam・lazy・handler 節を別本体のまま保つ。全構成子と本体入口からの保存列を照合し、Block 側の番号・途中停止の独立例を置く | 同じ三単位の work。D8a の対象全体、別本体の境界、本体入口、停止後の保存列を独立レビューし、C1Rb3b の範囲を受け入れる。レビュー・受け入れ時間は不明。その後 C1Rb3c が文書全体を照合する | 約1時間 |

各枝の work は `scripts/check.sh --level work --base <取りまとめが固定した B_WORK> --only formal_build,spec_examples,spec_tally` とし、先に同じ指定の dry-run を行う案である。各枝で一度ずつ実行し、今回の C1Rb3b の検査を接続後の証拠に引用しない。Lean のビルドは並行させず、単一ファイル検査には引き続き `-M 12288` を付ける。独立例を加える前には test-audit の作成時の関門を通す。C1Rb3c の既存の文書の照合と、C1Rb・C1 全体の受け入れは取りまとめの割り当てに残る。

## 実行した検査

指定された三単位の dry-run と work 本実行を各一度行った。Lean のソースを変更していないため、単一ファイルの試作検査や公理依存の再検査は追加していない。この検査は現在の未接続の実装の確認であり、C1Rb3b の完了の証拠ではない。

```sh
scripts/check.sh --level work --base a05f97303522045d56a0105a437712b7c46dcf38 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base a05f97303522045d56a0105a437712b7c46dcf38 --only formal_build,spec_examples,spec_tally
git diff --check
```

work 本実行は `/usr/bin/time -l python3 /private/tmp/benitoite-c1rb3b-work.py` で包み、Python の subprocess から上記の検査を起動した。書込み可能な既存の一時 CARGO_HOME を使い、依存の版と検査範囲は変えていない。

| 検査・コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| 指定の work の dry-run | 0。spec_tally・spec_examples・formal_build の三単位を選択 | 未計測（1秒未満） |
| 指定の work 本実行（一度） | 検査本体0。三単位とも成功 | Python monotonic 7.801805秒、time real 7.82秒 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。実行器の表示3.80秒 |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功 | 個別の外側時間は未計測 |
| git diff --check（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` は `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。Python が取得した検査本体の終了状態0とは区別する。lake build の各 Lean には formal/lakefile.toml の `-M 12288` が適用され、Lean のビルドを並行して走らせていない。検査本体の失敗と再実行はなかった。

一時ログ・終了状態・時間は `/private/tmp/benitoite-c1rb3b-work.{log,json}` に保存した。上の表に、この作業で必要な結果を記録しており、別の関係状態へ結果を引用する記録ではない。

## 申し送り

中1・中5、C1Rb3b・親 C1Rb は未完である。取りまとめが分割後の対象・保持する不変条件・依存・検査を plan.md へ登録し、枝を指定して再依頼する。C1Rb3a で済んだ依存の整理をやり直す必要はない。A01 等の着手条件や独立レビューの受け入れを、今回の検査成功だけで満たしたものとしない。

## 再開後の実装結果（2026-10-25）

**この起動で C1Rb3b の実装範囲を完了した。** 上の事前点検・停止・分割案は前回の記録として残す。今回は、取りまとめが再分割せず最大6時間を目安に全体を仕上げることを認めた依頼に従い、提案した三段を同じ枝で順に進めた。今回の基準 B_WORK と開始時の HEAD は `7b0a42c6780ddcc1b78263f7e43ad146a272877c`。開始時に未コミット差分はなかった。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

### 実装した範囲と三段の検査

| 段 | 実装・保持した契約 | 既定ビルド |
|---|---|---|
| 1 補助走査と合成証明 | BudgetChildren を新設し、Exprs・HoleArgs・Option を先に平坦化せず分類と作業枠を計上する childExprs・childHoles・childOptional と、実行を引数に受け取る unknownChildren を定義した。元のフィールド順の Walk、親の候補を復元する Silent、入力自身の契約と内部の SavesInputs を合成する補題を置いた。既定 import に接続した | `cd formal && lake build`、終了0、332 jobs。外側時間は未計測 |
| 2 Expr の子・入れ子・保存列 | expr の未知の場合と未対応の二項演算を skipChildren から unknownChildren へ置き換えた。小さい fuel の expr・block を実行引数に渡し、入れ子へ入る。analysis_keepsInputs を削除し、analysis_savesInputs の帰納証明から run_saves を導いた。番号・正常値・位置・原因・領域と既存の本体入口の系を維持した。この段の with・handleFail・handleE の保護本体はまだ skip とした | `cd formal && lake build`、終了0、333 jobs。外側時間は未計測 |
| 3 Block と本体入口 | with・handleFail・handleE の保護本体を独立入力へ接続した。with の位置0を topSlot (some (.opaque owner)) として BudgetScan.push で追加し、外の位置は忘却する。ラムダ・lazy・failure 節・通常の handler 節は別本体として番号だけを辿る。bodyWork_saves と analyzeExpr_independent_sound・analyzeBody_independent_sound を追加した | `cd formal && lake build`、終了0、333 jobs。外側時間は未計測 |

三段の既定ビルドは直列に実行した。Lean の各プロセスには lakefile.toml の `-M 12288` が適用されている。単一ファイルの検査にも同じ上限を付けた。最後のコメント修正と独立例の一行追加は、後述の work の既定ビルドで検査した。

unknownChildren は独立入力の結果を親のフローへ返さず、親の正常値は引き続き Top とする。子の return・正常値・絞り込みと親の候補列を混ぜない。親の未知の評価の空 trace で子の候補を正当化せず、保存した各入力自身の EvalPartial/EvalBlock・Models に対して IndependentResult.Sound を得る。保存列の合成は成功・停止の双方を扱い、入れ子の入力と既存の接尾辞も残す。

番号は独立入力を呼ぶ現在の next から一度だけ消費し、前もって skip してから解析し直さない。Block の入口には合成した式や番号を加えない。容器の fuel は容器の再帰で減らし、実行引数には親の expr より小さい fuel の expr・block を固定して渡す。深さで停止しない fuel の全体的な選び方は、既存の計画どおり C1Rc の範囲である。

言語の規則、対象構文の評価関係、中心二命題、旧主定理の前提・結論、公理、Builtins.Assumptions は変更していない。Rust のソース・テストは変更していない。01-12・07-04・契約表・分類表・用語集の全体照合は C1Rb3c の割り当てなので、この起動では変更していない。

### 独立例と作成時の関門

BudgetChildrenExamples を既定 import に加えた。9組の #guard は実際の analyzeExpr・analyzeBody からの出力を固定期待値と比較する。構成子の表は9行、保護本体と別本体の表は5行である。キー・原因・次番号の期待は手で数え、surfacePreorder や解析の出力から期待を生成していない。

守る契約は、呼び出し・リスト・レコード・更新・補間・穴・try・未知の二項演算のフィールド順、内側だけの除数0とあふれ、入れ子、外の0の忘却と内側の bind の利用、親への return の非伝播、with の位置0と外の位置1、保護本体と別本体の区分、本体入口の元番号、途中停止での候補と保存入力の保持である。番号の二重消費、未知の子を再び skip する変更、外の0の持ち込み、子の候補の親への混入、別本体への誤った侵入、停止後の保存列の欠落があれば失敗する。

既存の BudgetIndependentExamples は independent を直接呼ぶため、未知の構成子から到達する際の欠落や誤った振り分けを捕まえない。今回の例はその接続の境界を検査し、既存の直接入口の例は変更していない。テスト専用の本番の差し込み口は追加していない。新しい方針 D8a の実装の例であり、既存の不具合の修正前後を比較する退行テストとしては扱っていない。

### 局所検査と修正

以下のコマンドはすべて直列に実行した。外側時間は、最後の work を除いて未計測である。局所の各ビルドは必要な依存も再ビルドした。

| コマンド（lake は特記しなければ formal/ で実行） | 終了状態・内容 |
|---|---|
| `lake build Benitoite.Interval.BudgetChildren` | 初回1。opaque を変数名に使った構文エラーを owner へ修正した |
| 同じコマンドを誤ってリポジトリの根で実行 | 1。lakefile がない実行位置の誤り。以後 formal/ を指定した |
| `lake build Benitoite.Interval.BudgetChildren` | 1。容器の式の書換えを eq_def へ修正し、構成子の合成証明を整理した |
| `lake build Benitoite.Interval.BudgetLocated` | 1。unknownChildren_walk の候補適用が定義を過剰に展開して heartbeat の上限へ達した。with_reducible で適用する形に直した。最終コードで heartbeat の上限を増やしていない |
| `lake build Benitoite.Interval.BudgetIndependentSound` | 補助走査の段、Expr の接続後、Block の接続後の計3回とも0 |
| `lake build` | 上表の三段で各0 |
| `lake build Benitoite.Interval.BudgetChildrenExamples` | 初回1。String の別名に構造体の構築記法を使ったことと Unit の Ty の書き方を修正。修正後0。Block の例の追加後も0。最後の普通の tryOption の例の追加時に List Ty を Ty と書いたため1となり、型引数をリストへ修正した。最後の work で修正後の成功を確認した |
| `lake env lean -M 12288 /private/tmp/c1rb3b-probe.lean` | 入れ子の停止位置を2回、with の停止位置を1回、計3回とも0。14操作で次の容器分類に進めないことを確認し、保存数と停止位置を計上規則でも数え直した |
| `lake env lean -M 12288 /private/tmp/benitoite-c1rb3b-axioms.lean` | 0。次表の29宣言の公理依存を確認した |

局所の構文・証明・例の型の誤りは上のとおり修正した。期待値、予算、ignore、検査範囲を緩めて失敗を消していない。定理や公理の停止条件に当たる変更はなかった。

| 公理依存の確認対象 | 結果 |
|---|---|
| childContainers_property・unknownChildren_property・childContainers_walk・unknownChildren_walk・unknownChildren_silent・unknownChildren_saves | propext・Classical.choice・Quot.sound のみ |
| analysis_walk・analyze_normal_sound・analyze_warning_sound・analyze_warning_located・analyze_warning_region・analysis_savesInputs | 同上 |
| IndependentInput.run_contract・IndependentInput.run_saves・independent_saves・bodyWork_saves・analyzeExpr_independent_sound・analyzeBody_independent_sound | 同上 |
| analyzeBody_normal・analyzeBody_warning_sound・analyzeBody_warning_located・analyzeBody_warning_region | 同上 |
| Core.progress・Core.preservation・Core.effect_soundness | propext・Quot.sound のみ |
| Release.progress・Release.preservation・Release.effect_soundness・Surface.surface_effect_soundness | propext・Classical.choice・Quot.sound のみ |

### 指定された作業末の検査

今回の基準に対し、次の dry-run と work 本実行を各一度行った。水準全体の自動選択ではなく、依頼で名指しされた三単位の実行である。

```sh
scripts/check.sh --level work --base 7b0a42c6780ddcc1b78263f7e43ad146a272877c --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base 7b0a42c6780ddcc1b78263f7e43ad146a272877c --only formal_build,spec_examples,spec_tally
```

本実行は `/usr/bin/time -l python3 /private/tmp/benitoite-c1rb3b-current-work.py` で包んだ。Python の subprocess で上記の本実行を起動し、検査本体の終了状態と monotonic の外側時間を保存した。書込み可能な既存の一時 CARGO_HOME を使い、依存の版は変えていない。

| 検査 | 終了状態 | 外側時間・件数 |
|---|---|---|
| dry-run | 0。spec_tally・spec_examples・formal_build を名指しで選択 | 未計測、1秒未満 |
| work 本実行 | 検査本体0。三単位すべて成功 | monotonic 8.74420425秒、time real 8.77秒 |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。実行器の表示3.76秒 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功。最後に追加した tryOption の修正も検査済み | 個別の外側時間は未計測 |
| `git diff --check`（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となったためである。検査本体の終了0と区別する。work 本実行の失敗・再実行はない。一時ログと計測結果は `/private/tmp/benitoite-c1rb3b-current-work.{log,json}` と `/private/tmp/benitoite-c1rb3b-current-time.log` に保存した。この表に必要な結果を残しており、別の関係状態へ結果を引用する記録ではない。

### 取りまとめへの申し送り

C1Rb3b の三段は完了した。中1・中5への本接続と入れ子の保証は今回の実装に含む。所見別の対応は `reviews/RV-C1-response.md` に追記した。前回提案した追加の三枝は作らず、今回の明示の依頼に従って同じ枝で閉じた。

C1Rb3c は、BudgetChildren・analysis_savesInputs と二つの入口の保存列の系を含め、01-12・07-04・契約表・分類表・用語集を照合する。現行文書に残る「未知の子には未接続」「解析は保存入力を変更しない」といった前段の説明を、今回の定義へ揃える。C1Rc が受け持つ全体の駆動・予算付き別本体の発見・fuel の選び方、Rust/VM との比較は先取りしていない。C1Rb3b の独立レビューと受け入れ、親 C1Rb・C1 の受け入れは取りまとめの担当である。

行数の増減は、Lean の定義・証明・既定 import が追加509行・削除159行、独立例が追加142行・削除0行である。テストの削除や既存の期待値の変更はない。構成子に共通する候補列の復元と入力保存の合成は、同じ unknownChildren_property を Silent と SavesInputs に適用し、構成子ごとの証明を二重に持たない形にした。

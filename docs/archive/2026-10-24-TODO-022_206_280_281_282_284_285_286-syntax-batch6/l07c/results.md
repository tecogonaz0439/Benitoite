# L07c の結果

2026-10-24。基準 B_WORK と開始時の HEAD は `7fde1dfe2d3202cb31f71b92f221b91dd0064c96`、依頼されたブランチは `mod012/L07c` である。開始時の作業ディレクトリに差分はなかった。

L07c の実装と指定の work 検査を完了した。全53構成子と相互帰納容器の先行順を定義し、既存の評価規則の子のキーを親と構文から決める形に直した。任意の評価導出について trace のキーの範囲と一意性を証明した。L07b の反例入力には異なるキーでの導出があり、同じキーの二事象を持つ導出はない。中心命題の言明と公理は変更していない。

これは C0 の受け入れ完了ではない。L07c の定義・言明・仮定の独立レビューは取りまとめに渡す。比較・Block・単一 if の評価規則と導出の存在は L07d、二つの中心定理の解析への接続は L07b が担当する。

## 変更した定義と証明

`formal/Benitoite/Interval/Identity.lean` を新設し、既存の `OperationKey` と直接の子を列挙する六関数を、名前と定義を保って `Eval.lean` から移した。新設した定義は次のとおりである。

| 定義・定理 | 契約 |
|---|---|
| `surfacePreorder` と五つの容器の走査 | Expr 一つに一要素を割り当て、宣言のフィールド順・列に書かれた順で辿る。Exprs・HoleArgs・Block・Arms・Clauses 自身、穴、パターン、専用 builder の位置は数えない。未対応の部分木と constE の埋め込み本体も含む |
| `surfacePreorder_children` | 全構成子について、走査列が `source :: (children source).flatMap surfacePreorder` と一致する。二つの列挙が食い違う変更を証明で検出する |
| `surfaceSize`・`surfaceSize_children` | 先行順の列の長さを部分木の大きさとし、親の大きさが 1 と各子の大きさの和であることを示す |
| `childKey parent preceding` | 定義名を保ち、番号を `parent.surfacePreorder + 1 + (preceding.map surfaceSize).sum` とする。preceding は対象の子に先行する直接の子の接頭辞である |
| `numbered`・`numbered_preorders`・`numbered_keys_nodup` | 入力された根の番号から各出現に連続するキーを付け、番号列の連続性とキーの一意性を示す。同じ内容の式の繰り返しも別の出現として数える |

`Eval.lean` の paren・constE・returnE・add・divMod と算術の子の失敗・return の伝播規則は、子のキーを自由な引数で受け取らない。単一の子と左の子には `childKey key []`、二項演算の右の子には `childKey key [left]` を用いる。左が失敗して右を評価しない場合にも、構文上の番号を詰め直さない。

`TraceKeys key size trace` は、trace の事象のキーが対ごとに異なること、定義名が key と同じであること、各番号 n が `key.surfacePreorder ≤ n < key.surfacePreorder + size` を満たすことを表す。`eval_trace_keys` は、任意の環境・入力・outcome・trace について、評価導出だけから `TraceKeys input.key (surfaceSize input.source) trace` を示す。左右の部分木の番号範囲の分離と、親の番号が子の範囲に含まれないことを使う。`eval_trace_keys_nodup` は trace のキー列の重複がないことを結論する。Models や予算について新しい前提を要しない。

`formal/Benitoite.lean` に Identity の import を加えた。`Arithmetic.lean`・`Analyze.lean` の既存評価例を子のキーの新契約に合わせた。`Flow.lean` の `integerConstant_sound`・`atomRange_sound` は、paren・constE の構成子の引数変更に合わせて場合分けを直した。これらの局所定理の言明、解析の規則、値・失敗・trace の期待結果は保っている。

01-12「区間解析の対象構文の評価関係」に番号付けと子のキー、trace の範囲・一意性の定義と言明を写した。07-04 の同節と「01-12 との対応」、形式化の範囲の表にも対応と限界を記した。定義名と本体名の生成、番号付けの予算、元 AST の NodeId・span との対応は含めない。

## 反例の再現と独立例

修正前の確認には、B_WORK の `Eval.lean` を読み取り専用の `git show` で一時ファイル `/private/tmp/l07c-before.lean` に取り出した。既存の定義と衝突しないよう名前空間だけを `Benitoite.IntervalBefore` に替え、Domain の既存定義を参照した。末尾の小例で、任意の環境と根のキーについて `(1 intDiv 1) intDiv 0` の正常な内側と拒否される外側の二事象に同じキーを付けた導出と、キー列が Nodup でないことを証明した。評価規則の変更、解析器の代用品、追加の仮定・公理・sorry は使っていない。これは [L07b の反例](../l07b/key-collision.lean) と同じ衝突を、評価関係の境界で再確認したものである。

修正後の回帰例は `Eval.lean` の既定ビルドに含めた。同じ入力について、内側のキーを `childKey key []`、外側のキーを key とした正常な内側・拒否される外側の導出を実際に構成する。そのうえで、二事象に同じ親のキーを付けた trace には、どの outcome への導出もないことを証明する。導出の存在と排除を組にし、対象の形に導出がないために否定だけが成立する例にしていない。従来の `l07b/key-collision.lean` は修正前の問題の記録として変更していない。

Identity の独立例は、六つの相互帰納型を一つの小さい入力に含め、番号10〜25の順序を固定した。const 本体、穴と通常引数、builder の位置、guard と本体、複数の節、任意の説明、契約位置と異なる順に書いた名前付き引数を含む。期待する番号と局所参照の並びは、解析結果や番号付け関数で生成せずに指定した。

`test-audit` の作成時の関門では、trace のキーの一意性と、番号付けの順序を独立した契約とした。既存例は子のキーを自由に指定していたため、この退行を捕まえない。新例は実際の番号付けと評価の公開定義を使い、テスト専用のフラグ・注入・ラッパーを加えていない。既存例・テスト・本番の定義の削除はない。コメントと import を含め、Lean の定義・証明側の純増は294行、各ファイルの最初の example 以降の純増は43行である。Rust 本体と Rust テストの増減はともに0行である。

## 実行した検査

lake は `formal/`、check.sh と git の読み取りはリポジトリの根で実行した。下表の成功した実行の外側時間は `/usr/bin/time -p` による。rtk proxy は出力を変更せずに通す。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `rtk proxy lake env lean /private/tmp/l07c-before.lean` | 0 | 0.75秒 | 基準版の規則で同じキーの二事象の導出と、Nodup でないことを再現 |
| `rtk proxy lake build Benitoite.Interval.Eval Benitoite.Interval.Analyze Benitoite.Interval.Flow` | 0 | 4.30秒 | Identity と変更先・依存先、既存例と新しい二例が成功。警告なし |
| `rtk proxy lake env lean /private/tmp/l07c-axioms.lean` | 0 | 0.31秒 | 六定理の `#print axioms` を確認。下記の Lean 標準の公理だけに依存 |
| `rtk proxy scripts/check.sh --level work --base 7fde1dfe2d3202cb31f71b92f221b91dd0064c96 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | spec_tally・spec_examples・formal_build の三単位だけを選択 |
| `rtk proxy scripts/check.sh --level work --base 7fde1dfe2d3202cb31f71b92f221b91dd0064c96 --only formal_build,spec_examples,spec_tally` | 0 | 12.07秒 | 指定の work を一度実行。仕様集計の自己検査・集計、仕様例7件、既定 lake build と sorry の拒否が成功 |
| `rtk proxy git diff --check` | 0 | 未計測 | 空白の誤りなし |

仕様例は成功7件・失敗0件・ignored 0件であり、仕様集計の初回リリース完了条件に未記入はない。集計の「テスト参照のない節」の表示を、Lean の形式化の失敗とは扱っていない。

局所の証明調整では、同じ Identity・Eval・Flow ターゲットのビルドを反復し、構文・型推論・場合分けのエラーで終了1となった試行がある。相互帰納型に通常の induction を使えない箇所は構造再帰の補題と cases に直し、キーの推論は対象を明示し、既存 Flow の場合分けと評価例は新しい構成子の引数に合わせた。初期には lake の実行ディレクトリを誤った試行もあり、formal/ に直している。これらの初期試行の外側時間は未計測で、成功した局所ビルドを上表に記した。作業末の指定検査には失敗・再実行はない。期待値・大きさ・ignore・時間制限・検査範囲は緩めていない。

`surfacePreorder_children`・`surfaceSize_children`・`numbered_preorders` の公理の依存は propext、`numbered_keys_nodup`・`eval_trace_keys`・`eval_trace_keys_nodup` は propext・Classical.choice・Quot.sound である。新しい公理の宣言、Builtins.Assumptions の追加、未証明の仮定はない。`Reached`・`NormalSoundness`・`WarningSoundness` は、基準版との定義本文の文字列比較でも一致した。既存の Release・Builtins には差分がない。

## 計画との差と申し送り

- 検査は依頼文の補足どおり formal_build・spec_examples・spec_tally を名指しした。plan の検査表そのものは変更していない。
- 評価構成子の引数変更に必要な `Arithmetic.lean`・`Analyze.lean` の既存例と `Flow.lean` の局所証明、既定 import も同じ変更で更新した。言語の規則、旧主定理、中心命題の前提・結論を変える必要や停止事項はなかった。
- L07d はこの子キーの関数を使い、Block などの容器自身に番号を割り当てず、先行する式の部分木の大きさを加算する。新しい評価規則を加えた場合は `eval_trace_keys` の新しい場合も閉じる必要がある。
- L07b は、キーの重複がないことと、解析の子の区間に具体的な引数が所属することを分けて証明する。キーの一意性だけでは二つの中心命題を結論しない。六比較・not・Block・単一 if の評価規則と導出存在は、この変更には追加していない。
- L26 は、定義名・境界の本体名・番号付けの予算超過・Rust の NodeId との対応の前提を受け持つ。今回の走査は有限の全構文の番号付けの定義であり、予算付きの処理系の走査を実装したものではない。
- L07c の独立レビューと受け入れは取りまとめ担当で、L07d の前提にする前に行う。C0 は L07d と L07b の完了とレビューまで閉じない。Rust/Lean 全比較と VM 比較は X の担当であり、この作業では実行していない。
- private/ とそこを指すスキルのリンクは読んでいない。git の add・commit・branch・merge・stash・reset・checkout 等の変更操作は行っていない。コミット・取り込み・docs/todo の更新・公開操作は取りまとめへ渡す。

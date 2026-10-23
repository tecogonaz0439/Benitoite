# RV-F5: 作業 F5（Rust と Lean の全接続）のレビュー

- 対象: `git show 7fdc02eb`（基準 `28376432`。`28376432` はレビューの記録だけを加えたコミットであり、F5 の B_WORK は `b621fa1a`）。
- 読んだもの: plan.md の作業 F5 と検査の割り当て（K1・S-F）、RV-I の M1・L4〜L6、RV-F13 の L7、RV-F4 の M1、f5/results.md、f5/k1-summary.json、コミットの全差分。
- 実行していないもの: ビルド・テスト・check-formal（結果は f5/results.md と k1-summary.json による）。確かめたのは、差分の読解、マニフェストの新旧の JSON としての比較、コミットの中のマニフェスト3件の SHA-256 と k1-summary.json の記録の照合である。

## 申し送りの確認

| 申し送り | 判断 | 根拠 |
|---|---|---|
| RV-I M1 (a) 書式付きの頭が `%Format.<T>` の primName であること | 満たす | `Exchange/Convert.lean` 413〜426 行。部分の列を左から辿り、`converted` は頭を一つ読み飛ばし、`formatted t` は `FormatSpec.headName t` と一致する `.primName n [] []` を要求する。個数は直前の検査で一致しているので、頭と部分の対応はずれない。型引数・エフェクト引数付き、`funName`、別名、別の型の頭を拒否する変異を `test_formatted_head_identity_and_membership` が本物の入口で確かめ、変更前の実行器で5変異が失敗したことが記録されている |
| RV-I M1 (b) 使う頭が組み込みの表にあること | 満たす（段階 E2 の入口だけ） | `Exchange/CheckInput.lean` の `validateFormatHeads` を `prepare` から呼ぶ。desugarDiff・網羅性の入口は組み込みの表を読まないので照合しないが、07-04 は「E2の準備では」と範囲を明記しており、記述と一致する |
| RV-I M1 (c) `typedInput` の注記 | 満たす | `Surface/CheckExamples.lean` 700 行 |
| RV-I L4・RV-F13 L7 14 の頭のそろい | 満たす | Rust の側は `batch5.rs` が書き出した表 `export.tables[0]` に14の頭があることを、Python の側は `check_rust` が実際の `builtins.json` の頭の集合を独立の `builtins.json`（手書き）の集合と比べ、14件を要求する。Lean の `validateFormat` 自体はそろいを求めないが、L4 の修正案は「独立の検査」を求めていたので足りる |
| RV-I L5 旧版の拒否と利用者の名前のキー | 満たす（抜き取りで確認） | 書き出しの `serde_json::Map` への挿入は dataDecls の固定のキーだけで、primOps は `BTreeMap` から値の配列として出す（`exchange.rs` 265〜276・2585〜2653 行）。`annotations` のキーも固定の分類名である。全木の `rejectFields` を変えない判断は妥当 |
| RV-I L6 書式付き String の stringExpr への脱落 | 満たす | `check_rust` が corpus 全体の `stringExpr` を数え、`mixed` の書式なしの1件だけであること、`formatted` 28件・そのうち String 3件を要求する。脱落があれば両方の件数が外れる |
| RV-F4 M1-1 formatted の書き出し | 満たす | `exchange.rs` 1288〜1320 行。七欄を必ず出し、幅・精度の `None` は null になる。頭の名前は `table::FORMAT` から取るが、Lean の側は `headName` で独立に照合する |
| RV-F4 M1-2 corpus 14・sidecar 6 | 満たす | 全書き出し箇所と第2・3弾の照合器の版を14/6へ上げ、第3弾の不正な版の試験の値も 6 を有効として 7・8 へずらした |
| RV-F4 M1-3 manifest に行を足すだけで通していないこと | 満たす | 書き出しが formatted を出すようになった後で `formatted_interpolation_order.bnt` の行（inScope 4）を加えている。脱糖の比較は Lean が formatted の表層から作ったコアと Rust のコアを比べるので、書式を落とした入力が範囲内として通ることはない |

## マニフェストの変更

routing-manifest.json の差分は 3,594 行あるが、各行の `version` が 13 から 14 に変わったためである。版を除いて `(group, name)` で突き合わせると、変化は次の二つだけであり、行の順序も保たれている。

- 追加: `testdata/eval/formatted_interpolation_order.bnt`（excluded なし、inScope 4、網羅性 0/0）。
- 変更: `testdata/patterns/match_on_error_type.bnt` の excluded に `Some(E0601)` を追記（C2 の診断の反映。定義数 0・対象外の分類は不変）。

exchange-manifest.json も、同じ2行の反映、`namedVersions` の 14/6、件数の増分（脱糖 1,058→1,062、表層 51,725→51,729、定義 73,836→73,840、表層検査 51,745→51,749、golden プログラム 370→371）だけである。増分はいずれも新しい入力の4定義・1プログラムと一致する。`outOfScope` 19・`q11` 1・`preparationFailure` 0・`mismatched` 0 と `surfaceOutcomes` の既存の分類は変わっていない。既存の不一致を隠す変更はない。

コミットの中の routing・exchange・batch5 rust-manifest の SHA-256 は、k1-summary.json の `inputSha256` の値と一致した。

## Lean の側

- 変更は `Convert.lean`（交換の境界の検査の追加）、`CheckInput.lean`（`validateFormatHeads` の追加と `prepare` からの呼び出し）、`CheckExamples.lean`（注記1行）だけである。主な定理・公理・`Builtins.Assumptions` に触れていない。
- 3ファイルに `sorry`・`axiom`・`admit` の追加はない（`admitsDec` 等の既存の名前の一致だけ）。
- 削除した `test_wrong_head_type_reaches_surface_checker` は、頭の名前を `String.add` に変えた入力が表層検査で型の不一致として拒否されることを確かめていた。新しい Convert の検査が先に拒否するので、この経路は交換からは届かなくなった。頭の署名の検査は CheckExamples の `typedInput` の小例が引き続き確かめており、検査の穴にはならない。

## 指摘

### 読めば確定するもの

#### M1（中）K1 の記録は、別の状態（7fdc02eb）へ引用するための欄が足りない

- 場所: `f5/k1-summary.json` 3〜4 行（`base`・`head` がともに `b621fa1a…`）、`f5/results.md` 3 行。
- 問題: K1 は `b621fa1a` の上の未コミットの作業ツリーで走らせ、その後 `7fdc02eb` としてコミットされた。G1 が K1 を `7fdc02eb`（以降）の証拠として引用すると、07-03「結果の保存と引用」の「別の状態へ結果を引用するときだけ、未コミット差分と未追跡入力の内容のSHA-256も保存する」「差分の有無とファイル一覧」に当たるが、記録には差分のファイル一覧も差分の SHA-256 もない。入力のハッシュはマニフェスト3件と生成物だけで、変更した Lean のソース・`test_batch5_exchange.py`・`batch5.rs`・`exchange.rs`・`check-formal.sh` は含まれない。マニフェスト3件はコミットと一致したが、それだけでは K1 が `7fdc02eb` の内容で走ったことを示せない。
- 修正案: G1 が K1 を引用する前に、取りまとめか F5 担当が次のどちらかを行う。(a) `results.md`（または k1-summary.json）に、対象の状態を「`b621fa1a` ＋未コミットの差分＝`7fdc02eb` の 19 ファイルから f5/ の2ファイルを除いたもの」と書き、差分のファイル一覧と、`git diff b621fa1a 7fdc02eb -- . ':!docs/2026-10-23-TODO-206_272_273_276-syntax-batch5'` の SHA-256、実行時の作業ツリーと同一と判断した者と日付を記す。実行時の差分の SHA-256 は保存されていないので、これは担当の判断に基づく引用になることも明記する。(b) (a) の判断を置けないなら、K1 を「F5 の接続が通った記録」に留め、G1 では引用せず、Z1 の K2（計画どおり最後の関係状態で再実行する）を全比較の唯一の証拠とする。Z1 は K2 を再実行する計画なので、Z1 は K1 の引用に依存しない。

#### L1（軽）07-04 の「E2の準備」が段階の名前と処理の名前を省いている

- 場所: `docs/design/07-quality/07-04-formal-semantics.md` 187 行（新しい節「書式付き補間の交換形式」）、308 行（表の行）。
- 問題: 同章のほかの箇所は「段階 E2」と書く。「E2の準備」は、どの関数の処理かが読み取りにくい。
- 修正案: 「段階 E2 の入口の準備（`Exchange.CheckInput.prepare`）では」に改める。308 行も「組み込み表への登録は段階 E2 の入口の準備」とする。

#### L2（軽）07-04 の「29定義」と「25関数」の関係が書かれていない

- 場所: 07-04 308 行（「29定義の期待コア」）と 189 行（「独立入力の25関数の表層とコア」）。
- 問題: 独立入力は29定義を持ち、Rust 出力の照合モードはそのうち `format0`〜`format24` に当たる25定義を比べる。二つの数が別々に出てくるので、食い違いと読まれうる。
- 修正案: 189 行を「独立入力の29定義のうち、Rust のソースと対応する25関数の表層とコア」とする。

#### L3（軽）報告の `formattedStringFallback` が数えた値ではなく定数である

- 場所: `formal/tests/test_batch5_exchange.py` 274 行（`formattedStringFallback=0`）。
- 問題: 前の `require` が通ったときだけ書くので結果は正しいが、k1-summary.json の `formattedStringFallback: 0` が実測の件数に見える。
- 修正案: `formattedStringFallback=strings - manifest['plainString']` のように数えた値を書く。必須ではない。

#### L4（軽）check-formal で batch5 の単体テストを二度走らせている

- 場所: `scripts/check-formal.sh` 140 行と 159 行、`test_batch5_exchange.py` 283〜284 行。
- 問題: `--rust-dir` 付きの呼び出しも先に `unittest.main` を走らせるので、独立入力の検査（約2秒）が重複する。誤りではない。
- 修正案: `--rust-dir` があるときは単体テストを省くか、140 行の呼び出しを除く。時間が小さいので任意。

### 実行しないと分からないもの

なし。L5 の主張（利用者の名前をキーにする欄がない）は書き出しの抜き取りで裏付けたが、全欄の網羅は読んでいない。違反があっても、旧版の正しい入力を誤って拒否する側の失敗であり、誤った受理にはならない。

## その他の確認

- src は変えていない（`git show --stat` で確認）。S-F は計画どおり引用の照合で足りる。
- K1 の時間は 1,009 秒（約17分）で、仮予算15〜30分に収まる。
- plan の F5 の完了の条件（新構成の対象外 0 件、六入口・独立交換入力・組み込み宣言表・名前付きプログラム・routing/exchange manifest の件数のそろい、check-formal 全体の成功）は、記録の上で満たされている。文字列の出力算法は、ランタイムの独立期待値で別に検査すると 07-04 に書かれており、コア形の比較で代用していない。

## 重さの要約

| ID | 重さ | 種類 | 要旨 |
|---|---|---|---|
| M1 | 中 | 読めば確定 | K1 の記録に、7fdc02eb へ引用するための差分の一覧・SHA-256・判断者がない |
| L1 | 軽 | 読めば確定 | 07-04 の「E2の準備」を「段階 E2 の入口の準備（`prepare`）」に |
| L2 | 軽 | 読めば確定 | 07-04 の29定義と25関数の関係を明記 |
| L3 | 軽 | 読めば確定（任意） | `formattedStringFallback` を数えた値に |
| L4 | 軽 | 読めば確定（任意） | check-formal で batch5 の単体テストが重複 |

## 段 V を閉じて G1 に進む判断

進んでよい。申し送り（RV-I の M1・L4〜L6、RV-F13 の L7、RV-F4 の M1 の三条件）はすべて満たされ、マニフェストの変更は新しい入力と C2 の E0601 の反映だけで、既存の分類は変わっていない。Lean の主定理・公理・仮定は変わらず、抜け道もない。M1 は、G1 が K1 を引用する前に (a) の記録を足すか、(b) K1 を引用せず K2 に任せるかを取りまとめが決めればよく、段 V の作業のやり直しは要らない。L1〜L4 は G1 の文書の修正か docs/todo への回付でよい。

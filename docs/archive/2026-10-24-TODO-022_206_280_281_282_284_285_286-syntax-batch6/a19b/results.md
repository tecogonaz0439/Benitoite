# A19b の結果

着手: 2026-10-26 14:41:05 JST（最初に採取した時刻。指示とスキルの読み込みは直前に開始した）。終了: 2026-10-26 15:05:59 JST。所要時間: 24分54秒（最初の時刻記録から）。

**状態: A19b の指定範囲の実装・固定表の再生成と照合・局所検査・指定 work を完了した。独立レビューと受け入れは取りまとめへ引き渡す。**

B_WORK・HEAD は `60b2267cbd677a99697df344ae7f29d1bdfcd5f6`、ブランチは `mod012/A19b`。着手時の差分はなかった。plan.md の二つの計画変更と、依頼の補足を優先した。private/ とそこを指すリンクは読まず、git の変更操作と担当の委任は行っていない。

## 実装した範囲

- 標準表の照会を、型・エフェクト・辞書の引数がない `FunName`・`PrimName` に揃えた。出現表を一参照してから標準表を一致まで走査する。Range の由来と射影は従来どおり `FunName` に限る。
- シフトの27宣言（組み込み20、包み7）の標準宣言・元キー・署名・契約位置を認定し、`domainEntry`・`domainCallShape` の順で参照・型列・ラベル・置換・引数容器を計上する。置換用の基準列と削除の接頭辞だけを auxiliary とし、成功・停止とも領域を出るときに返す。
- 認定した引数をソース順に親の環境で解析し、`selectArguments` と同じ枠・分類を計上して、親にはシフト量の正常区間と由来だけを保持する。未認定の call は従来どおり子の独立入力と未対応の印を持つ。
- 全体が正常域と交差しない区間だけに `Cause::OutsideDomain` と `TargetOperation::Standard { declaration, contract }` の候補を保存する。元ノードは call、一次位置は対象引数、`left` は推定区間、`right` は正常域、`origins` は対象引数の由来である。交差・Top・Bottom、先行または後続の引数の Bottom・return には親の候補を作らない。保存の枠・候補一項・返却は既存の `save_candidate` を使う。
- `02-05` に照会の頭、シフトの引数と候補、計上を反映した。W0404 の診断の登録・表示、操作・HTTP の追跡、Lean の定義・定理・公理、公開の型検査の署名は変更していない。

主な本番の変更は `interval/flow/range.rs`・`interval/flow/fixed_domain.rs`・`interval/arithmetic.rs`・`interval/fixed_domain.rs`・`interval/flow.rs` である。`interval/diagnostics.rs` は新しい原因を表示せずに扱えるよう戻り値を Option にしただけである。候補を診断に変える標準 call の照合は未接続であり、A21b の担当範囲である。

## 固定表の再生成と差の再現

生成元の二つの `.lean` に、既存の `StandardBinding.argumentTypes` の既定値 `[]` を明示した。入力式・予算・上限・選択規則を変えていない。再生成器自体も変更していない。

```sh
python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --log-dir <記録先>
python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --check --range-export <直前の書き出し先> --log-dir <記録先>
```

生成器は最初に専用の `desugar_export` を実行し、実交換の宣言だけを Lean へ渡した。Rust の解析結果・費用から期待値を作っていない。Lean は生成と確認のそれぞれで二入力を逐次実行し、常に一プロセス、`lake env lean -M 12288` とした。formal/ と `lakefile.toml` に差分はない。生成・確認以外の Lean の実行はない。

| 表 | 旧→新の行数 | 同じキーの変更 | 追加 | 削除 |
|---|---:|---:|---:|---:|
| body | 18,336→18,342 | 158 | 6 | 0 |
| whole | 6,304→6,304 | 0 | 0 | 0 |
| summary | 6,304→6,304 | 0 | 0 | 0 |

内訳は `with` の52行変更・2行追加と `nestedWith` の106行変更・4行追加だけである。最小完走予算は操作が22→23・40→42、保持は21・33で不変となる。取得の `.primName "open"` の call が出現表を一参照し、入れ子では二回となるためである。L25T の表と一致し、追加の原因はない。[差の点検器](reference-diff.py)と[詳細](reference-diff.json)に保存した。

旧動作（PrimName を照会しない状態）へ一時的に戻すと、`with` の本体操作上限9で停止分類・保持・独立入力が新しい表と不一致になった（[退行の記録](heads-regression.log)）。修正を復元すると本体・全体の予算境界テスト4件が成功した。`--check` は保存済みの三表と完全一致した。

生成の生出力は [ZIP](reference-generate/raw-logs.zip)・[索引](reference-generate/raw-logs-index.json)、確認の生出力は [ZIP](reference-check/raw-logs.zip)・[索引](reference-check/raw-logs-index.json)に保存した。実交換の [range-bindings.json](reference-generate/range-bindings.json) も残した。圧縮後に SHA-256 の一致を確かめた。

## テストの作成時の関門と局所の確認

rtk・japanese-tech-writing・test-audit を適用した。新しいテストは、本物の名前解決・型検査から既存の本体入口を呼ぶ。守る契約は、27宣言と引数順・区間の対応、二表と元キーの必須性、親と独立入力の区別、対象位置だけの保持、失敗の順序、任意予算での保存済み候補と一時保持の返却である。Range だけの既存の固定表はシフトを含まず、この欠落を検出できない。

- `tests/fixed_domain.rs` の表は27宣言×2引数順×7区間の378通りを、DomainExamples の独立した幅・区間と照合する。定義域の上端、推定区間、原因は本番の契約表から生成していない。
- 親の局所事実、対象外の引数、div 0 の正常Top、先行・後続のあふれと return、最大値の左シフト、偽の同名関数・間接・括弧・穴・パイプを確認する。
- 二表の不在・別宣言・別キーのテストを既存の表の境界へ一件追加した。型や純粋性・宣言の集合の契約は既存の A19a のテストを残した。
- 置換の逆順では contains と erase が各一要素余分に読み、操作が2増えることを独立に指定した。本体・全体の操作・保持を別々に小予算で走査し、停止時の一時保持0、候補の保存と完走境界の整合を確認する。この部分は同じ入力の完走時の使用量との不変条件の検査であり、新しい Lean のシフトの全費用との比較を実施済みとは扱わない。

新しいテスト関数は計5件。既存の二つの算術テストの網羅的な match に、標準の候補なら失敗する分岐を加えた。テストの削除・入力の縮小・上限や期待値の緩和・ignore の変更・本番の差し込み口の追加はない。

シフトの call を未認定の経路へ戻す試行では、新しい378通りのテストが独立入力の混入を検出して失敗した（[記録](domain-regression-valid.log)）。最初の試行は接続先の未使用警告でコンパイルが止まったため、テストの退行確認として数えず、参照を残す形に直して上記の失敗を確認した（[初回](domain-regression.log)）。修正後の局所テストは成功した。

## 検査・時間・割り当て量

実行場所は `<repo>`。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo`、固定版 Rust 1.98.1・Lean 4.34.1 を使った。各実行のコマンド・終了状態・外側時間は同名の JSON、出力は log に保存した。[実行器](run.py)が手元のパスを伏せている。

| 検査 | 結果・外側時間 | 記録 |
|---|---|---|
| 固定表の生成 | 終了0、165.166秒。Lean 本体/全体71.638秒、集計17.174秒 | [生成](reference-generate.json) |
| 固定表の `--check` | 終了0、88.838秒。Lean 本体/全体71.488秒、集計17.179秒 | [確認](reference-check.json) |
| 旧照会の退行確認 | 期待した不一致、終了101、7.865秒 | [JSON](heads-regression.json) |
| 修正した照会と固定表 | 4件成功、終了0、18.513秒 | [記録](budget-heads.log) |
| 新しい原因・演算の初回コンパイル | 終了101、9.638秒。既存の二つのテストの網羅的 match に新しい演算の分岐が不足し、上記のとおり訂正した | [記録](compile-domain.log) |
| Range の局所検査 | 19件成功、終了0、32.097秒 | [記録](range-local.log) |
| シフトの初回局所検査 | 3件成功、終了0、17.862秒 | [記録](domain-tests.log) |
| 予算を加えた局所検査 | 4件成功、終了0、14.942秒 | [記録](domain-budget.log) |
| 二表・元キーと既存の表 | 3件成功、終了0、16.289秒 | [記録](tables-local.log) |
| 区間解析全体の局所検査 | 60件成功、終了0、20.798秒 | [記録](interval-local.log) |
| 割り当て量の途中の実測 | 2件成功、終了0、29.514秒 | [記録](allocations.log) |
| work の dry-run | 終了0、0.090秒。指定の基準、--test 省略の七単位を確認した | [記録](work-dry-run.log) |
| 作業末の work | **七単位成功、検査本体0、494.372秒。外側は494.399秒・終了1（計測の制限）** | [外側](work.json)・[本体](work-check.json)・[出力](work.log) |

| 割り当て量の入力 | 実測値 | 保持した上限 |
|---|---:|---:|
| 20,000定数の鎖 | 442,822,829バイト | 536,870,912（512 MiB 未満） |
| 5,000定数・1,000診断 | 254,937,092バイト | 268,435,456（256 MiB 未満） |

二件とも A19a と同じ値である。

作業末は [work-check.py](work-check.py) から次を一度実行し、外側を `/usr/bin/time -l` で包んだ。

```sh
scripts/check.sh --level work --base 60b2267cbd677a99697df344ae7f29d1bdfcd5f6
```

fmt、examples を含む clippy、lib 全件、全統合、ソース規約、生成 Skill、仕様集計の七単位が成功した。lib は **1,332件成功・失敗0・既存 ignored 21件**、全統合は **40ターゲット・388件成功・失敗0・既存 ignored 10件** である。[件数の詳細](work-counts.json)にターゲット別の数を保存した。生成 Skill に差分はなく、仕様集計の初回リリース版の完了条件の未記入は none だった。指定 work は一度だけで、失敗による再実行はない。

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体の終了0の後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。real/user/sys は494.39 / 1500.03 / 89.48秒である。未取得を0とせず、取得のための再実行もしていない。

[作業末の入力ハッシュ](work-inputs-sha256.json)の14ファイルは、検査開始から最終点検まで一致した。[最終点検器](final-review.py)と[詳細](final-review.json)で、この一致、formal・依存・Skill・割り当て量のテストの不変、whole・summary・再生成器の不変、ログのパスの伏せ方、ZIP のハッシュ、Python の構文、結果記録のリンクと `git diff --check` を確認した。検査後の変更は本ディレクトリの結果と記録だけである。

本番 Rust は324行追加・23行削除、テスト Rust は394行追加・4行削除である。[変更の集計](changes.json)に、未追跡の新しい二ファイルも含めて保存した。

## 取りまとめと後続への申し送り

A21a はシフトの直接引数だけの W0404 の型板を登録する。A21b は `diagnostics::Warnings::append` の演算の照合と、`diagnostic` の OutsideDomain の分岐を接続する。宣言・契約位置・推定区間・正常域・対象引数の位置と由来は上記の候補から読める。A21c は診断を含む文書と生成 Skill を揃える。操作・HTTP の候補は追加していない。

新しいシフトの全関係状態・実交換・実 VM との一致は X01〜X03 の担当範囲である。今回の局所の独立期待値と予算の不変条件は、その比較の代用にしていない。stage・change・release・check-formal.sh 全体・性能測定・32ビットでのビルドや実行は実施していない。別の状態の検査結果を引用して省いた検査はない。

計画の変更は不要だった。Lean の定義・主定理の変更や公理の追加、言語の規則・公開の型検査の署名の変更を要する停止条件には当たっていない。コミット・取り込み・docs/todo の更新・保管・公開、独立レビューと受け入れは取りまとめの担当である。


| 残る手順 | 担当・受け入れの区切り | 見込み |
|---|---|---|
| A19b の独立レビュー・受け入れ・コミットと取り込み | 取りまとめ。二表・元キー・順序・候補と計上を確認する | 不明 |
| W0404 の登録・表示・文書と Skill、各 work とレビュー | A21a〜A21c。診断を接続した後に案III の区切りを確認する | 計画の1〜2・1〜3・1〜2時間。独立レビューは不明 |
| 実交換・全関係状態・実 VM の比較と受け入れ | X01〜X03 と取りまとめ、計画の各区切り | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。Lean（`formal/`）は変わらない。予算の固定表の変化は `l25t/results.md` の表（body の `with`・`nestedWith`、158 行の変更と 6 行の追加、whole・summary は不変）と一致し、`regenerate-reference.py --check` が一致を確かめた。生成元の二つの Lean 入力の変更は、`StandardBinding` の argumentTypes の既定値 `[]` の明示だけである。work は終了0、`call_allocations` の二件は A19a と同じである。A21a へ進む。

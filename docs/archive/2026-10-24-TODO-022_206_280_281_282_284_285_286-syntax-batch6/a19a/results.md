# A19a の結果

着手: 2026-10-26 13:54:13 JST。終了: 2026-10-26 14:23:10 JST。所要時間: 28分57秒。

- B_WORK・HEAD: `61e04c646797d045d8bf876800c2e8cba690db59`。ブランチは `mod012/A19a`。着手時の差分はなかった。
- 状態: A19a の標準宣言の表と出現の保存、局所検査、固定表の比較、作業末の検査を完了した。独立レビュー・受け入れと、後続の頭の対応の確認は取りまとめへ引き渡す。
- 適用範囲: plan.md「計画の変更（2026-10-26、L25R・L25S を受けて）」の A19a の行を優先した。共通依頼文、前提と依存、内部の契約、作業群 A19〜A21、指定の判断・レビュー・前段の申し送りと取りまとめのレビューを確認した。private/ とそこを指すリンクは読んでいない。

## 実装した範囲

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/typeck/interval/fixed_domain.rs` | 27宣言の契約表を追加した。読み込み済みの標準索引、関数の種類、純粋性、型・エフェクトのパラメータと辞書の不在、引数の契約名・型・戻り型を照合する。追加ロードは行わない |
| `crates/benitoite/src/typeck/interval/flow/range.rs` | 既存の標準表にシフトの項を保存する。Range の二項を先頭に保ち、シフトは完全名の辞書順で追加する。シフトの出現のない本体には項を追加しない。名前の出現は `consts::std_call` で元の宣言と照合し、元 NodeId から参照する |
| `crates/benitoite/src/typeck/interval/mod.rs` | 固定域の契約表のモジュールを接続した |
| `crates/benitoite/src/typeck/interval/flow/range/tables_tests.rs` | 本物の読み込み・名前解決・型検査と既存の本体入力の収集から、27宣言の契約・型・別名・順序、同名の利用者関数の除外、他の本体と未ロードのモジュールの不変を確認する二件を追加した |
| `crates/benitoite/src/typeck/interval/tests/budget_reference.rs` | 既存の表形式のテストに操作の呼び出しを追加した。型引数付き funName と opName の操作数・番号列が一致し、単相の funName との元の差を保つことを確認する |
| `docs/design/02-impl/02-05-typechecker.md` | 保存する宣言・契約・表の順序と、名前の保存と頭の照会の区別を反映した |

シフトの引数の解析、`domainEntry`・`domainCallShape`・`selectArguments` の接続、固定域外の候補、W0404 は追加していない。標準表の照会を行う既存の `range_direct_call` は変更せず、型引数・エフェクト引数・辞書のない funName の頭だけを照会する。opName・primName と型引数付きの頭では照会しない。Byte を算術七種へ加えていない。

契約上の対象は0始まりの引数位置1、契約名は `[a,n]`、引数の型は `[シフトする値の型,Integer64]`、戻り型はシフトする値と同じ型である。正常域は次のとおりである。Integer と Integer64、UnsignedInteger と UnsignedInteger64、UnsignedInteger8 と Byte は、型が同じでも異なる宣言として保持する。

| 宣言を持つモジュール | 方向 | 宣言数 | n の正常域 |
|---|---|---:|---|
| Integer・Integer64 | shiftLeft・shiftRight・shiftRightUnsigned | 各3 | `[0,63]` |
| Integer8 | 同上 | 3 | `[0,7]` |
| Integer16 | 同上 | 3 | `[0,15]` |
| Integer32 | 同上 | 3 | `[0,31]` |
| UnsignedInteger・UnsignedInteger64 | shiftLeft・shiftRight | 各2 | `[0,63]` |
| UnsignedInteger16 | 同上 | 2 | `[0,15]` |
| UnsignedInteger32 | 同上 | 2 | `[0,31]` |
| UnsignedInteger8・Byte | 同上 | 各2 | `[0,7]` |

テストの作成時の関門を通した。主に守るのは Lean へ渡す宣言の同一性・型・固定域と探索順序の契約であり、別名の欠落、Byte の誤った型、署名やエフェクトを無視した登録、他の本体への項の混入で失敗する。既存の Range と予算のテストはシフトの27宣言を入力に持たないため、新しい二件が必要である。期待値は `FixedDomainApi` の契約と標準ソースから別に記述し、本番の契約表から生成していない。差し込み口・公開範囲は増やさず、既存の解析上限・期待値・入力の規模・ignore は変更していない。既存テストの削除はない。rtk・test-audit・japanese-tech-writing を適用した。

## 検査と途中の失敗

実行場所は `<repo>`。Rust は固定版1.98.1、Lean は固定版4.34.1を使った。Cargo は書き込み可能な既存の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。コマンド・終了状態・外側時間は各 JSON、出力は各 log に保存した。

| 検査 | 結果・外側時間 | 記録 |
|---|---|---|
| 新しい二件の初回 | 終了101、90.103秒。テスト入力の公式モジュールに Unofficial を付けた誤りと、複数引数の名前の欠落があった | [tables-first.log](tables-first.log)・[JSON](tables-first.json) |
| 名前付き引数の訂正後 | 終了101、24.991秒。一件成功、一件は公式モジュールの import の誤りで失敗した | [tables.log](tables.log)・[JSON](tables.json) |
| 入力の訂正後 | 二件成功、終了0、5.590秒 | [tables-corrected.log](tables-corrected.log)・[JSON](tables-corrected.json) |
| 割り当て量の途中の実測 | 二件成功、終了0、29.443秒 | [allocations.log](allocations.log)・[JSON](allocations.json) |
| 既存の予算の境界比較 | 四件成功、終了0、7.432秒。拡張した頭の比較、本体・全体の固定表、無関係な関数の比較を含む | [budget-local.log](budget-local.log)・[JSON](budget-local.json) |
| 通常の固定表の確認器 `--check` | 終了1、5.154秒。下記の第三欄の省略により、一時入力の型検査で停止した | [reference-check.log](reference-check.log)・[JSON](reference-check.json) |
| 第三欄を一時入力で明示して比較 | 終了0、89.204秒。三表がバイト単位で一致した | [reference-compatible.log](reference-compatible.log)・[比較](reference-comparison.json) |
| 最初の work の dry-run | 終了0、0.087秒。七単位を選択した | [work-dry-run.log](work-dry-run.log)・[JSON](work-dry-run.json) |
| 最初の work | 検査本体1、41.184秒。fmt は成功、追加テストの enum のワイルドカード分岐が lint に拒否された。後続は未実行 | [work.log](work.log)・[本体](work-check.json)・[外側](work.json) |
| 再実行の指定の誤り | dry-run・検査入口とも終了2。`tests_related` を明示する `--only` は `--test` が必須だった。検査の単位は起動していない | [dry-run](work-retry-dry-run.log)・[本体](work-retry-check.json) |
| 最終の dry-run | 終了0。元の自動選択へ戻し、同じ七単位を確認した | [work-final-dry-run.log](work-final-dry-run.log)・[JSON](work-final-dry-run.json) |
| 修正後の work | **七単位成功、検査本体0、454.944秒。外側は454.970秒・終了1（計測の制限）** | [work-final.log](work-final.log)・[本体](work-final-check.json)・[外側](work-final.json) |

最終の lib は1,327件成功・失敗0・既存 ignored 21件、全統合は40ターゲット・388件成功・失敗0・既存 ignored 10件である。ソース規約・生成 Skill・仕様集計も成功し、生成 Skill に差分はない。仕様集計の初回リリースの完了条件の未記入は none である。

初回の lint の失敗は、新しいテストの `BindingKind` の判定を `matches!` と条件分岐へ直した。処理系の実装・契約・テストの期待値は変更していない。再実行は、その変更で古くなった fmt・lint と、停止により未実行だった五単位に限る。元の自動選択と同じ七単位であるため、`--test` を省いた全統合の指定を保った。

作業末の実コマンドは次である。最初の一回と失敗修正後の再実行は同じ指定であり、先に同じ指定の `--dry-run` を行った。

```sh
scripts/check.sh --level work --base 61e04c646797d045d8bf876800c2e8cba690db59
```

[work-check.py](work-check.py) と [work-final-check.py](work-final-check.py) からこのコマンドを呼び、外側を `/usr/bin/time -l` で包んだ。計測器と検査本体の終了状態を分けた。**maximum resident set size はサンドボックスで `sysctl kern.clockrate: Operation not permitted` となり取得できない。未取得を0としていない。**

## 固定表と割り当て量

通常の確認器の失敗は、L25S と同じ、`StandardBinding.argumentTypes` の既定値を構築の第三欄で省略した入力の型検査の問題である。[check-references.py](check-references.py) は、現在の Rust の実交換から宣言を新たに取得し、一時入力の二つの構築に既定値 `[]` を明示して計算した。入力式・予算の上限と選択規則・期待値は変更せず、既存の生成器の選択処理を使った。Lean の定義と追跡中の生成入力・生成器・README・表は編集していない。通常の生成器の互換修正は本枝では行っていない。

二入力は `lake env lean -M 12288 <一時入力>` で順に実行し、並行実行していない。本体・全体の採取は70.448秒、集計は17.067秒、どちらも終了0である。生の出力は [raw-logs.zip](reference-compatible-output/raw-logs.zip) と [索引](reference-compatible-output/raw-logs-index.json)、実交換は [range-bindings.json](reference-compatible-output/range-bindings.json) に保存した。

| 表 | 行数 | 保存済みの表との比較 |
|---|---:|---|
| body | 18,336 | ヘッダー・行順・全列を含めバイト一致 |
| whole | 6,304 | 同上 |
| summary | 6,304 | 同上 |

比較した表の計算前後の SHA-256 は [reference-comparison.json](reference-comparison.json)、固定表関連7ファイルと B_WORK との一致は [fixed-inputs-sha256.json](fixed-inputs-sha256.json) に保存した。固定表を作り直していない。

| 割り当て量の入力 | 実測値 | 元の上限 |
|---|---:|---:|
| 20,000定数の鎖 | 442,822,829バイト | 536,870,912（512 MiB 未満） |
| 5,000定数・1,000診断 | 254,937,092バイト | 268,435,456（256 MiB 未満） |

二件とも A18b までの値と同じである。入力・上限・期待値を変更していない。その後の実装の変更はなく、テストの enum 分岐だけを訂正した。

## 後続へ渡す契約と確認点

本枝で保存した27宣言のうち、現行の名前解決では20宣言が `BindingKind::BuiltinFn`、包みの7宣言（Integer64 の三つ、UnsignedInteger と UnsignedInteger8 の各二つ）が `BindingKind::Fn` となる。`identity::name_form` は前者を `PrimName`、後者を `FunName` にする。例えば `Integer.shiftLeft(a: 1, n: 64)` の頭は前者、`Integer64.shiftLeft(a: 1, n: 64)` は後者である。新しいテストは実際の解決結果の20対7を確認する。

Lean の `standardCallHead` は型引数のない funName だけを認める。本枝はこの条件を守り、primName を funName へ変更したり Lean の認定を拡げたりしていない。**A19b で27宣言すべての call を認定する場合は、この分類と独立交換へ渡す頭の対応を、取りまとめが先に確認する必要がある。** 表に27宣言を保存したことを、27宣言の引数解析や W0404 まで接続済みという意味にはしていない。言語規則・Lean の主要定理・公理・固定済みの Rust の型と署名を変更する判断は、本枝では行っていない。

| 担当・時期 | 残る作業・検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A19b の前 | A19a の独立レビューと受け入れ、上の頭の対応の確認。標準表は Range 二項の後にシフトの完全名の辞書順、出現表は元 NodeId と解決済み宣言の対応とする | 不明 |
| A19b、受け入れ後 | 引数の契約位置・型・ソース順と `domainEntry`・`domainCallShape`・`selectArguments` の計上を接続し、独立期待値と指定 work を確認する | 計画の1〜3時間。頭の対応の扱いによる追加費用は不明 |
| A21a〜A21c、計画の依存を満たした後 | W0404 の型板、候補と診断、文書・生成 Skill の接続と各 work、レビュー・受け入れ | 計画の各1〜2・1〜3・1〜2時間 |
| X01〜X03 と取りまとめ、計画の各区切り | 独立交換、Rust/Lean の全関係状態、実 VM の比較、段・改造全体・公開候補の検査と受け入れ | 計画による。今回未測定の範囲は不明 |

stage・change・release、check-formal.sh 全体、実 VM との比較、32ビット環境での実行・クロスビルドは本枝で実施していない。git の変更操作、コミット・取り込み・docs/todo の更新・保管・公開は行っていない。


## 最終点検と計画との差

最終の work を開始してから、処理系・テスト・設計書の六入力を変更していない。入力のハッシュは [work-inputs-sha256.json](work-inputs-sha256.json)、初回の検査前のものは [work-first-inputs-sha256.json](work-first-inputs-sha256.json) に区別した。

実装範囲の変更はない。途中のテスト入力・lint・再実行の指定の誤りを訂正し、固定表の比較には L25S と同じ、一時入力で第三欄を明示する方法を使った。別の状態の検査結果を引用して省いた検査はない。4時間の上限による中断はない。A19a が担当する実装と指定の検査に未完・不合格は残っていない。最大常駐量の取得不能と、後続の頭の対応・通常の生成器の互換修正が未実施であることは、上記のとおりである。

[最終点検器](final-review.py)と[詳細](final-review.json)で、六入力のハッシュ、固定表関連7ファイルと B_WORK の一致、formal・依存・生成 Skill・割り当て量のテスト・index の不変、`git diff --check`、記録と圧縮したログのパスの伏せ方、Python の構文、結果記録の相対リンクを確認した。点検器の初回は、同じ単位の二コマンドの見出しを別の単位として数えて失敗した（[記録](audit-first.json)）。出現順を保って重複を除く照合へ直し、成功した。これは点検器の訂正であり、検査対象の変更ではない。

本番 Rust は271行追加・46行削除、テスト Rust は197行追加・1行削除である。新しいテスト関数は二つで、既存の一つを拡張した。

## 取りまとめのレビュー（2026-10-26）

受け入れる。Lean・予算の固定表・関連の7ファイルは変わらず、work は終了0、`call_allocations` の二件は A18b と同じである。

申し送りの確認点は取りまとめが確かめた。Lean の表層（`Surface/Syntax.lean`）は組み込みの関数を `.primName` の頭で表し、区間解析の `standardCallHead` は型引数のない `.funName` だけを認定する。L22〜L25S の例はシフトを `.funName` の頭で書いていたので、実際のソースの組み込みのシフト20宣言（`BindingKind::BuiltinFn`、`PrimName`）を Lean は認定しない。これは Lean の模型の誤りなので、A19b の前に Lean の作業 L25T を置き、型引数とエフェクト引数のない `.primName` の頭も同じ表で認定する（計画の変更（2026-10-26、A19a を受けて））。

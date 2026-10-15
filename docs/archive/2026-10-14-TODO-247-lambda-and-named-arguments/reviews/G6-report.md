### レビューの記録（高なし、中 2、低 4）

中1: N25 の振り分けで Lean の検査から外れる入力がある（tests/desugar_export/named.rs の uses_named_arguments、312 行付近）。新形式へ回す条件が「呼び出しに名前付き引数がある」「Named の穴の計画がある」だけで、名前付きの関数型の注釈だけを使い呼び出しは位置指定という入力（`bind action: function(left: Integer, right: Integer) -> Integer <- f` に位置呼び出しだけ）は旧形式で書き出され契約名が落ちる。型検査はこうした注釈を名前の境界として扱い（has_named_contract_syntax、named_input）E0454 を出すので、その照合を Lean が確かめない範囲が残る。修正案: 判定を利用者モジュールの expr_types と decl_types に names_origin == Named で引数を持つ関数型があるかに改める（または型検査と同じ判定の関数を使う）。注釈だけの入力を manifest に一件加える。

中2: レコードを値として許すかが本体の中の順序で変わる（resolve/walk.rs 76 行付近の `ctx.record_values |= !t.params.is_empty()`）。名前付きの関数型を辿った時点で旗が以降の文すべてに立ち、入れ子のラムダの注釈で立った旗も外へ漏れる。`bind p <- Point` は注釈より前なら名前解決の誤り、後なら受理。旗の判定も型検査の named_contracts（has_named_arguments）と一致しない。修正案: 本体に入る前に has_named_contract_syntax() で一度だけ決め、型を辿る途中で旗を書き換えない。順序で結果が変わらないことのテストを加える。

低3: 同じ未知の関数の呼び出しごとに E0455 が重なるおそれ（typeck/calls.rs の unresolved）。回復を equal(callee, Error) と equal(ret, Error) で行うので、戻り値が他の制約で確定済みのとき（`Integer.toString(n: g(a: 1)) + Integer.toString(n: g(a: 2))`）二件目でも E0455 が出うる（机上の推測）。修正案: call_contracts と同じく poison で回復し、上の入力を診断のテストに加える。
低4: E0454 の副の位置のラベルが空文字列（typeck/traits/impls.rs 330 行付近の `secondary(declared, if valid { "" } else { "declared" })`）。鍵 "" は型板の表にない。修正案: E0454 に declared の鍵を加えるか副の位置を付けない。
低5: 同じ本体の中で位置呼び出しの扱いが経路ごとに異なる（typeck/generate.rs の call_body）。名前付き引数を含む本体ではパイプと穴だけが calls::generate を通り、`x |> target(2)` や `target(1, _)` は E0449、`target(1, 2)` は旧い経路で受理。修正案: N33 までの意図した差なら decisions.md に記録し、N33 の完了条件に入れる。そうでなければ E0449 を出す。
低6: 届かない分岐が文脈を戻さずに抜ける（typeck/calls.rs の generate の `else { return ITy::Error; }`）。修正案: named_contracts を戻してから返す。

問題のなかった観点: 評価順と値の置き場所（パイプは左辺→呼ぶ式→明示の引数、穴は生成した関数の呼び出し時に評価、名前は元の契約名をソース順）、N22 の推論の順序と連鎖、標準ライブラリの移行（Q10 の表と一致、取り違えなし）、テストの弱化なし、規約の違反なし。

## 対応

- 中1: `tests/desugar_export/named.rs::uses_named_arguments` で利用者の式の確定型も調べる。N27 の宣言型の対応だけでは局所注釈を見落とすことを再現し、注釈と一引数の位置呼び出しだけの独立入力を追加した（n27/exchange-manifest.json、R79）。
- 中2: `resolve/walk.rs` の型の走査中の旗の更新を廃止し、署名・本体・定数の入口で `has_named_contract_syntax` により決める。局所注釈と入れ子の注釈の前後にレコード値を置く四ケースを名前解決の公開の境界で検査する。
- 低3: 提示例は修正前の現行版でも E0455 が一件で、重複を再現しなかった。`Solver::equal_with_outer` の Error の経路は既に `poison` を呼ぶため回復処理は変更せず、`tests/named_arguments.rs` の既存の表に提示例と一件・最初の呼び出し位置の検査を追加した。
- 低4: `typeck/traits/impls.rs` の副の位置を `declared` に統一し、E0454 の型板へ `method declared here` を追加した。既存の統合テストで副の位置の件数と文字列を検査し、`gen_skill` で診断の参照を再生成した。
- 低5: 旧位置指定の通常呼び出しと、先に新経路へ接続したパイプ・穴の差は N33 まで残す。decisions.md の R78 に理由を書き、plan.md の N33 に三経路の拒否と対応する名前付き入力の受理を完了条件として追加した。
- 低6: `typeck/calls.rs::generate` の到達しない引数分岐でも `named_contracts` を戻してから返す。

### メモリ対策の検証

`/usr/bin/time -l` でテスト実行ファイルの `--exact export_desugar_corpus --ignored --nocapture` を直接測定する。Cargo とコンパイルの最大値を混ぜない。修正前の f47e7c98、同じ版へのメモリ対策だけの適用、改造前の e18f38fe、Z7 の全修正後を比較する。過去版のソースは `git archive` で target/ 内に展開し、ブランチと git の索引を変えずに測定する。

保持が増える原因は、旧形式・新形式それぞれで全件の入力・組み込み表・標準宣言・網羅性の Value を保存し、最後の json! で複製することであった。組み込み表は入力ごとの束縛番号を含むため、一律の共有ではなく一件ずつの書き出しを採用した（R77）。`tests/desugar_export.rs::CorpusStream` と `exchange.rs::InputStream` が一件だけを保持し、一時ファイルと集計した注釈から同じ鍵順・版・Decimal の整数表現で最終ファイルを作る。

メモリ対策だけを適用した全件の出力は、修正前の f47e7c98 と八ファイルすべてバイト単位で一致した。旧形式 1,582 入力（対象内 1,204・除外 378）、新形式 142 入力、生成入力 1,000 件を維持する。SHA-256 とファイル長は下表および作業用の `target/z7-memory/byte-comparison.json` に記録した。Z7 の全修正後の全件の出力も同じ八ファイルすべてで一致した。交換形式の版、対象内外の判定、注釈の件数、Decimal の整数表現を変更していない。

`/usr/bin/time -l` 自体は sandbox の `sysctl kern.clockrate` の拒否で最大常駐メモリの表示を完了できなかった。テストは成功したが time の終了状態は 1 になった。64 MiB を確保する子プロセスで、Python の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` が子自身の最大値に対応することを確認し、time とテストの実行を維持したまま、その親から同じ測定値を補足する方法で現行の修正前後を再測定した。テストの成功は終了状態とは別に `test result: ok. 1 passed;` で確認する。e18f38fe の書き出しも成功（旧形式 1,715 入力、対象内 1,337・除外 378）したが、最初の time の実行では最大常駐メモリを取得できなかった。同じ getrusage の補足で e18f38fe も再測定した。

### 検査

- `cargo test -p benitoite --lib`: 1,149 成功、従来の ignore 21 件。
- `cargo test -p benitoite --test named_arguments --test desugar_export`: 28 成功（15 + 13）、従来の formal 用 ignore 1 件。独立入力を一引数へ確定した後も desugar_export の 13 件が成功した。
- `cargo test -p benitoite --test golden --test skill_docs`: 10 成功。
- `cargo clippy --all-targets` と `cargo fmt --check`: 成功。
- `cargo run -p benitoite --example gen_skill`: 成功。生成物の差分は E0454 の declared の一行だけ。
- 最終の全件で `check_named.py::check_routing` の 1,724 入力の照合が成功した。`check_named.py::check_named` で、新しい注釈だけの入力と既存の五種類の独立入力について、Lean の新形式の脱糖・組み込み表・単一定義群の表層検査・全件の表層検査の受理を確認した。
- 中1・中2・低4は修正前に意図した失敗を確認した。中1は最終確定した一引数の独立入力についても、式型の振り分け条件を一時的に除くと uses_named_arguments の assert で失敗し、戻すと全 13 件が成功することを確認した。低3は既存の正しい振る舞いの確認として提示例を既存の表に追加した。既存の assert の削除・期待値の緩和・ignore 化はない。
- テストの削除はない。本番の Rust は 19 行増・4 行減、単体テストは 21 行増、統合テストとその補助は 210 行増・47 行減である。全件の書き出しの保持方法の変更が大半を占める。
- `scripts/check.sh` と gc-stress は依頼どおり実行していない。formal/ のファイル・規則・定理は変更していない。

### 全件の出力の一致

修正前、メモリ対策だけの版、Z7 の全修正後で次の長さと SHA-256 が同じである。バイト列自体も修正前とメモリ対策だけの版で比較した。生成入力 1,000 件も同じ生成器の種を使う。

| ファイル | バイト数 | SHA-256 |
|---|---:|---|
| `builtins.json` | 41,479,553 | `82156f239a316fb1646cd57d391cb2dbf4f80164ac922508c5da85b24f0bf2a5` |
| `corpus.json` | 297,765,770 | `fe5ea9b731fa6b93831be25b87f7edf8b546a963dec2a61028eaa21611a38576` |
| `coverage-matches.json` | 6,043,095 | `82d0ad119ff7a25feef5d8e45ba8beda95353e8142542cfffd10f1b6a348d781` |
| `named-programs-builtins.json` | 4,670,684 | `2e6bd9df4df0dbe13b09366473c4492137b4c7914a75f2fa9749b8a912bdef27` |
| `named-programs-corpus.json` | 4,105,687 | `d951a59a0019fc590875d7d7d3c18bbdf7dd645e42117359a0fd9e3909a2f822` |
| `named-programs-coverage.json` | 51,498 | `347cc1fa1c45c201d62e6410f16e36a7a96a2db21b216cac63a38326b4715739` |
| `named-programs-stdlib.json` | 334,442 | `29b19ca3a270948d940b3abc30b23b33f8ceba99c6bd5f27ee37f923a56c50b2` |
| `stdlib-decls.json` | 469,069 | `ccd77fa6fe06ff2c7f6dbf7c612badb01f693be7af391374ebc66e55961d845a` |

### 最大常駐メモリの測定結果

値は time を待つ親の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` で補足したものであり、time が拒否後に表示した値ではない。すべての測定で全件テストの成功を確認した。並行して測定したため、実行時間の性能比較は行わない。

| 版 | 最大常駐メモリ（バイト） | GiB |
|---|---:|---:|
| e18f38fe（改造前） | 18,384,027,648 | 17.121 |
| f47e7c98（Z7 修正前） | 14,054,719,488 | 13.089 |
| Z7 修正後 | 237,600,768 | 0.221 |

現行の修正前後では 98.31% 減少し、修正後は 226.59 MiB であった。今回の最大常駐値では、設計者が観測した 27 GB そのものは再現していない。全件の保持と最終の複製をなくした比較で、既存の出力を変えずに最大値が減ったことを確認した。

再測定した修正後の八ファイルも、最初の修正後の出力とバイト単位で一致した。過去版を展開して再測定した f47e7c98 は、除外された三つの NoMainFile の絶対パスだけが展開先を含む。三箇所のリポジトリの絶対パスを元のルートへ戻すと、八ファイルの長さ・SHA-256 が最初の修正前と一致する。測定値の生のバイト数は作業用の target/z7-memory/memory-comparison.json にも記録した。

申し送り: R78 の通常・パイプ・穴の複数位置指定の統一は N33 で行う。scripts/check.sh と gc-stress の最終検査はオーケストレータに委ねる。コミットと docs/todo/ の変更は行っていない。

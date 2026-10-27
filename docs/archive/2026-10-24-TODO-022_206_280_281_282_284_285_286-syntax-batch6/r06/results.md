# R06 の結果

2026-10-24。基準 B_WORK は `3268d805f9dd513e50540ff7e6aa07702d908055`。着手時の HEAD は基準と同じで、ブランチは `mod012/R06`、作業ツリーに差分はなかった。

## 実行したコマンドと結果

外側の時間は `/usr/bin/time -p` の real である。コマンドは `rtk proxy` を通した。作業ディレクトリは、明示した Lean ビルド以外はリポジトリの根である。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `cargo run -p benitoite --example gen_skill` | 0 | 4.92秒 | 計画 T-G の再生成。生成物と bundle.rs に内容の差分なし |
| `cargo test -p benitoite --test reference_examples --test skill_examples`（初回） | 101 | 8.59秒 | 新しい二例が E0439。reference_examples の1テスト失敗、skill_examples は未実行 |
| `cargo test -p benitoite --test reference_examples --test skill_examples`（修正後） | 0 | 14.87秒 | reference_examples の1テスト、skill_examples の3テストが成功 |
| `lake build`（`formal/` 内） | 0 | 0.43秒 | 既定ビルド成功、296 jobs |
| `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/g2 --report target/formal-batch3/g2-exchange-results.json` | 0 | 1.01秒 | 計画 T-L。1入力・11定義で六入口が一致 |
| `scripts/check.sh --level work --base 3268d805f9dd513e50540ff7e6aa07702d908055 --only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --dry-run` | 0 | 各0.01秒 | 局所試行中と修正後の2回。ともに指定の4単位を選択 |
| `scripts/check.sh --level work --base 3268d805f9dd513e50540ff7e6aa07702d908055 --only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples` | 0 | 15.75秒 | 選択された全検査が成功。work の実行はこの1回のみ |
| `git diff --check` | 0 | 未計測 | 空白の誤りなし |

work の内訳は `tests_related`（skill_examples、3成功）、`skill_generated`（再生成前後の状態が一致）、`reference_examples`（1成功）、`skill_docs`（8成功）である。テストは計12成功・0失敗・0 ignored。英語リファレンスの実行・検査対象は、新しい二例を含む43例である。

初回の失敗は、`with` の末尾に置いた `return ()` が main から戻り、後続の `File.readText` を到達不能にしたためである。両文書のテキスト例と JSON 例の末尾を Unit の式 `()` に直し、`end with` の後に読み戻しへ進めるようにした。期待出力、検査器、時間制限は変更していない。

## Log の局所交換

標準ソース、交換入力 `crates/benitoite/tests/desugar_export/batch4/log-standard.bnt`、manifest、交換器は B_WORK から変更していない。計画 T-L に従い、既存の `target/formal-batch3/g2/` の五形式を入力にして、既定 Lean ビルド後に六入口の比較を再実行した。書き出しの Cargo テストと VM／参照評価の比較は、R06 では再実行していない。ここに示す六入口の結果は今回実行した比較の結果である。

| 入口 | 件数と結果 |
|---|---|
| `coverageDiff` | 1件一致、不一致0、fuelExhausted 0 |
| `coverageProgramDiff` | 1件一致、不一致0、対象外0、fuelExhausted 0 |
| `desugarDiff` | 11定義一致、不一致・対象外・除外はいずれも0 |
| `builtinCheck` | 1入力、94 summary comparisons、summaryMismatchCount 0、errors なし |
| `surfaceCheck` | 1入力・11定義、ok true |
| `surfaceCheckAll` | 11件一致、不一致・対象外・q11・lazyRestriction・preparationFailure はいずれも0 |

| ファイル（`target/formal-batch3/g2/` 内） | SHA-256 |
|---|---|
| `corpus.json` | `f8abe9504fe8e7e5c85e93a2ed247eeb53b7fe62a839c132a690bc25a83a88c6` |
| `builtins.json` | `05ea9dfc536f6dfa9443d3133d407df30f39c9b70d1b54ca4b3e7d3db222cf68` |
| `stdlib.json` | `823f42d8f9147147a0705160fd151c91bfff65d66e198f19c2f1fc3bc5f41d42` |
| `coverage.json` | `85ad908a217046d0c3c12f078e125efdafe4f4d42b1473476f4f84a66bae5441` |
| `coverage-program.json` | `5ad372a7d061266ec749a5a6a44ac302e066c61bbd9d651ad9285d0eac4db069` |

## 計画からのずれと申し送り

- 英語リファレンスと Skill の idioms に、テキストと JSON の実行例をそれぞれ追加した。テキストは `Log.formatRecord` を `File.writeLine` へ渡す。JSON は利用側の純粋な関数で変換し、属性の配列、u64 最大値の十進文字列、非有限 Float の明示したオブジェクトを使う。SKILL.md に手書き参照へのリンクを加え、03-07 に組み方・寿命・失敗・残るエフェクトを反映した。
- 各例は一度開いた Writer へ二行を書き、Debug の除外、水準と位置、重複属性の順序、改行・引用符のエスケープを、解放後の読み戻しと標準出力の比較で確かめる。JSON 例には Text・Boolean・Integer・u64 最大値・有限 Float・NaN を含む。位置は出力の再現性のため固定の Location を構築し、実際の位置には各呼び出しへ直接 `SourceLocation.here()` を渡すと説明した。
- `test-audit` の作成時の関門を確認した。守る契約は公開 API を組み合わせた文書例の出力と寿命であり、Writer の解放前の読み戻し、フィルタの脱落、属性の Map 化、数値の情報欠落があれば失敗する。既存の整形単体の検査ではファイルへの書き込みと読み戻しを含む文書例の成立を確かめられないため、既存の共有 doc_examples を使う両文書の入口に例を追加した。新しい Rust テスト、検査用の本番の差し込み口、期待件数の変更はない。
- Rust・Lean・Log.bnt・交換入力は変更していない。したがって stdlib_doc_examples の追加実行は不要であり、Rust の全 lib・fmt・lint・heap/stress は R06 の指定へ追加していない。生成物は再生成したが内容は同じである。本番と Rust テストの行数の増減はいずれも0行である。
- 正負の無限大、書き込み失敗、解放失敗、解放後の使用、並行タスクは新しい実行例の対象にしていない。寿命と失敗の説明は既存の File とリソースの規則に合わせた。言語の規則の変更、Lean の主な定理の変更、公理の追加、未解決の設計判断はない。
- 計画の範囲と検査の割り当てからの変更はない。独立レビュー・受け入れ、R06 後の stage S-R3 は取りまとめ担当で未実施。改造全体の change と最終候補の release は、それぞれ計画の担当と時期に実施する。
- git の変更操作、private/ とそれを指すスキルの読み取り、docs/todo の更新、版上げ・公開は行っていない。

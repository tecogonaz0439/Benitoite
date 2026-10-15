# N34b の実装記録

## 範囲と維持した契約

N34 の cleanup-manifest.json にある一時モデル・入口の 95 ファイルを削除した。正式な Release・Surface・Exchange と六つの入口は変更しない。移動後の 95 ファイルのハッシュは N34 の switch-manifest.json と一致し、793 定理の言明は theorem-correspondence.json と一致する。段階 A の Core の 16 ファイルも HEAD と一致する。削除したファイルのハッシュと確認結果は cleanup-results.json に記録した。

Rust の書き出し器から corpus 7・型表 1・網羅性 1 のラッパー、版による分岐、旧呼び出しの書き出し、構文による版の振り分けを削除した。関数型・宣言・ラムダの名前と、呼び出しのラベル・位置は常に最終形式へ保持する。型とコアの整合、名前の個数・一意性、分類理由を確かめる assertion は維持する。

旧形式の identity は、同じ本体と型検査成功の assertion を保って independent-program の最終形式へ移した。単一／全表層、脱糖、宣言表、プログラム内の網羅性を正式入口で検査する。一般入力との識別子の非重複も維持する。旧形式だけのワイルドカードの出力は削除し、同じ網羅性の契約を最終形式の q3/wild・golden/after-wild と identity の照合で保つ。

未呼び出しの旧版専用の照合関数と期待値は、その維持先を確認して削除した。旧版への振り分けの assertion は、宣言と式の型にある入れ子の関数型の契約名の整形式を確かめる assertion へ移した。この判断は R102 に記録した。一般入力・分類理由・定義数・観測結果・破損入力の期待値は変更せず、ignore の追加は行わない。

exchange-manifest.json は N34 の基準から legacy・legacyReports と旧網羅性の欄だけを除き、independent-program の一入力・一定義・照合一件を加えたものである。一般入力の routing-manifest.json は N34 の基準を引き続き参照する。実行結果から期待値を生成しない。

## テストの作成時の関門

1. 最終形式だけを書き出し、六つの正式入口が同じ型・名前・脱糖・網羅性を検査する契約を守る。正式な定理の言明と証明を保持する。
2. 削除漏れによる旧版の出力、契約名の消失、入力識別子の二重使用、対象内入力の欠落、対象外理由の付け替えを捕まえる。
3. 新しい同種のテストを加えず、既存の独立入力と全件の比較を最終形式へ移す。旧版の受理を確かめるだけの検査は役割を終え、旧版の拒否は既存の formal/tests/test_named_exchange.py が六入口で確認する。破損入力の拒否と数値のビットの assertion も維持する。
4. Rust の公開の AST・型表・コアと Lean の正式 CLI を境界にする。本番の API・公開範囲・差し込み口は追加しない。本番の Rust コードの変更はない。

## 検査

- `cargo test -p benitoite --lib`: 1,154 件成功、既存の ignore 21 件。
- `cargo test -p benitoite --test desugar_export --test coverage_export`: 15 件成功、既存の ignore 2 件。最終の Rust の差分でも再実行して成功した。
- `cargo clippy --all-targets`: 成功。
- K の `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` と `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`: 成功。
- `cargo fmt --all --check`、`git diff --check`、`bash -n scripts/check-formal.sh`: 成功。
- `formal/` の `lake build`: 159 jobs 成功。Lean のソースに sorry はない。
- `scripts/check-formal.sh`: 終了状態 0。Rust の書き出しは ignore を含め coverage_export の 2 件と desugar_export の 15 件が成功した。手書きの最終形式の 12 件と幅付き数値の 4 件も成功した。
- 六入口の全件比較: 一般入力 1,726 件・73,733 定義・網羅性 22,438 件、独立した網羅性 10,020 件と関数型の二件が一致した。表層の結果は matched 51,636、対象外 19、Q11 1、不一致・準備失敗 0。除外 380 件の識別子と理由、全入力の分類理由も基準と一致した。破損入力 15 件は意図した理由で拒否された。
- 最終形式へ移した independent-program は一定義が脱糖・単一／全表層・宣言表の検査を通り、プログラム内の照合一件も一致した。旧形式のワイルドカードの出力は生成されない。
- 正式モデルの 95 ファイル、793 定理の言明と証明、Core の 16 ファイルは前述の基準と一致した。`rg` で formal・scripts・crates の検査・tools・fuzz・現行設計書とリファレンスを調べ、移行用の名前空間・実行ファイル名・旧書き出しと振り分けの参照がゼロであることを確認した。

全件の結果と比較の記録は formal-results.json・formal-comparison.txt に置いた。一般入力の報告は N34a の formal-results.json と厳密に一致する。出力先は target/desugar-diff/n34b-final と target/coverage-diff/n34b-final であり、Rust の全件の書き出しには前の作業と同じく `CARGO_PROFILE_TEST_OPT_LEVEL=1` を指定した。最終の出力先に旧版の corpus・型表・網羅性のファイルがないことも確認した。

本番の Rust コードの変更はない。Rust と Python のテスト・補助の差分は追加 141 行・削除 551 行である。移行専用の分岐と重複モデルを削除し、観察可能な契約と独立した比較を最終形式に残した。計画の範囲の変更はなく、検査の維持先の判断だけを R102 に追加した。

## 申し送り

N35 以降の版・language 宣言・訳の変更は行わない。ユーザーの指定により scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は、オーケストレータによる取り込み時の検査へ残す。コミットと docs/todo/ の変更は行わない。

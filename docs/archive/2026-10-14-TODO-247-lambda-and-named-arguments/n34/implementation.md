# N34 の実装記録

## 範囲

一般入力を全件 corpus 8・型表 2・網羅性 2 に統一する。正式モデルと規則の写しは変更せず、N34a の適用用 patch を作る。旧入口には一般入力と別の独立入力を渡す。

## テストの作成時の関門

1. 公開の解析・型検査・脱糖が出した全入力について、契約名・ソース順・対応位置を Lean の独立した六入口へ渡す契約を守る。N33 の入力識別子・分類理由・定義数・網羅性の件数を維持する。
2. 名前付き呼び出しを持たない入力を旧形式に残す退行、名前の欠落、対象外理由の付け替え、独立した網羅性の境界入力の欠落を検出する。
3. 既存の差分検査の入力と manifest を移す。VM の結果比較だけでは、型付き表層・コアの契約名と対応表の欠落を捕まえられない。追加の同種の VM テストは作らない。
4. 公開の API と実際の書き出しファイル・Lean CLI を境界とする。本番への差し込み口や公開範囲の拡大を要しない。

旧入口の独立入力は、一般入力を新形式へ移した後も旧モデルの脱糖・型・プログラム内の網羅性の境界を検査する。直接のワイルドカードの照合を含む一関数を公開の解析・型検査へ渡し、旧六入口の比較に接続する。この契約は全件を Named へ移した一般入力では検査できず、本番への差し込み口を要しない。幅付きの既存の短い出力は出力先を分け、同じ 30 定義を Lean に比較させる。VM の比較やビットの保存の assertion だけでは書き出しと独立モデルの接続を検査できない。

既存 assertion と破損入力の期待理由を維持する。版別の分類だけを N33 の基準から導き、成功数・対象外理由を観測値に合わせて緩めない。

## 検査

- `cargo test -p benitoite --lib`: 1,154 件成功、既存の ignore 21 件。
- `cargo test -p benitoite --test desugar_export --test coverage_export`: 15 件成功、既存の ignore 2 件。形式化の検査では ignore を含む全件を書き出す。
- `cargo clippy --all-targets`: 成功。
- K の `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` と `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`: 成功。
- `cargo fmt --all --check`・`git diff --check`: 成功。
- `git apply --check n34a-switch.patch`: 成功。別のディレクトリの変更後の全 103 ファイルのハッシュも patch と一致した。
- 切り替え先の `lake build`: 159 jobs 成功、sorry なし。段階 A の Core 16 ファイルは不変で、Named の import と lake の登録はゼロ。
- 切り替え先の手書きの独立入力: named exchange 12 件と width exchange 4 件が成功。
- 切り替え先の全件比較: 一般入力 1,726 件・73,733 定義・網羅性 22,438 件、独立した網羅性 10,020 件と関数型二件、既存の破損入力 15 件が成功。16 定理の公理依存は既存の範囲に収まる。詳細は `promotion-results.json`・`promotion-axioms.txt`・`promotion-comparison.txt`。

元の作業ツリーでも `scripts/check-formal.sh` を最初から再実行し、終了状態 0 で完了した。再実行はテストのビルドだけに `CARGO_PROFILE_TEST_OPT_LEVEL=1` を指定した。出力先は `target/desugar-diff/n34-final` と `target/coverage-diff/n34-final` である。coverage_export の二件と desugar_export の 15 件を ignore を含めて実行し、旧六入口・Named の六入口・全件・破損入力が通った。一般入力の除外 380 件と、表層の対象外 19 件・Q11 一件の理由も基準と一致した。詳細は `formal-results.json`・`formal-comparison.txt` に記す。

## 差分と申し送り

本番のコードの変更はない。テストとその書き出しの補助は追加 134 行・削除 31 行（差し引き 103 行）であり、既存 assertion・期待値・ignore を弱めていない。追加したテストは旧入口の独立入力を書き出す一件である。既存の検査を削除していない。

計画の範囲内の接続の補正は R99・R100 に記した。最初の全件の検査では、作業中に作った旧入口の独立入力のプログラム内の網羅性が空だったため、その入口の終了状態が 1 だった。一般入力の全件と Named の比較自体は通った。独立入力を照合を含む非空のものに直し、一般入力側の元の非空の assertion も維持した。幅付きの Rust 出力の空のプログラム内の網羅性は、入口の仕様どおり終了状態 1 と全ゼロの報告を厳密に検査する。

N34a は `README.md` の手順で patch と manifest をレビューし、正式モデル・全入口・写しを同時に切り替える。N34b の削除対象は `cleanup-manifest.json` に列挙した。N34 では正式モデルと現在の設計書の写しを変更しない。ユーザーの指定に従い、`scripts/check.sh`（dry-run を含む）と gc-stress の検査、コミット、docs/todo/ の変更は行わない。

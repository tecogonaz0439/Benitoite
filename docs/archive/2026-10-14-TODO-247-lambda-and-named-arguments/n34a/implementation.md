# N34a の実装記録

## 範囲と差分の確認

N34 の `n34a-switch.patch` を適用し、名前を保持するモデルを正式な `Release`・`Surface`・`Exchange` へ移す。六つの正式入口、ルートの import、lake の登録、形式化の検査、01-12・07-04・07-03 を同時に切り替える。段階 A の Core は変えない。一時モデルと旧形式の書き出し器の実体の削除は N34b に残す。

適用前に `switch-manifest.json` の 103 出力先の変更前ハッシュと、95 移動元のハッシュを照合し、`git apply --check` を通した。適用直後の 103 出力先の変更後ハッシュも一致した。793 定理の対応は N34 の `theorem-correspondence.json` を使い、名前空間の置換以外に言明と証明を変えない。

準備済み patch からの補正は R101 の非重複の assertion の保持、独立入力と検査スクリプトの説明の更新、lakefile の末尾の空行の除去である。旧入口の呼び出しだけを登録から外す理由は、最終形式の入口が旧形式を拒否することと、全一般入力を新形式で比較することを同時に確かめるためである。旧報告の照合関数と期待値の実体は残す。assertion の削除・期待値の緩和・ignore の追加は行わない。

## テストの作成時の関門

1. 六つの正式 CLI が corpus 8・型表 2・網羅性 2 だけを受理し、Rust の全入力の契約名・ラベル・対応位置と Lean の規則が一致する契約を守る。進行・保存・エフェクト健全性・性質 1・checker と網羅性の健全性を正式名で維持する。
2. 名前空間や入口の切り替え漏れ、必須名の補完、偽のラベル・位置の受理、一般入力の欠落と対象外理由の付け替えを捕まえる。
3. 新しい同種のテストを加えず、既存の独立入力・破損入力・全件の manifest の厳密な比較を正式入口へ移す。旧形式の受理は最終規則の契約ではなく、六入口の既存の旧版拒否テストで拒否を確認する。数の値・ビット・診断・件数の assertion は維持する。
4. 実際の Rust の出力と Lean の CLI を境界にする。本番の API や公開範囲を変更せず、テスト用の差し込み口を加えない。

## 検査

- `cargo test -p benitoite --lib`: 1,154 件成功、既存の ignore 21 件。
- `cargo test -p benitoite --test desugar_export --test coverage_export --test spec_examples`: 22 件成功、既存の ignore 2 件。
- `cargo clippy --all-targets`: 成功。
- K の `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` と `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`: 成功。
- `cargo fmt --all --check`: 成功。`git diff --check` が検出した準備済み patch の lakefile の末尾の空行を除き、再検査も成功した。
- `formal/` の `lake build`: 159 jobs 成功、sorry なし。
- 正式名での主要 16 定理の公理依存: 既存の `propext`・`Classical.choice`・`Quot.sound` の範囲内。`axioms.txt` に記録した。
- `promotion-results.json`: 95 ファイルは名前空間の置換だけで移動元と一致。793 定理の言明と証明は N34 の対応表のまま。Core の 16 ファイルは HEAD と一致し、Named の import と lake の登録はゼロ。

- `scripts/check-formal.sh`: 終了状態 0。Rust の書き出しは ignore を含め coverage_export の 2 件と desugar_export の 15 件が成功した。手書きの新形式の 12 件と幅付きの数の 4 件も成功した。
- 六つの正式入口の全件比較: 一般入力 1,726 件・73,733 定義・網羅性 22,438 件、独立した網羅性 10,020 件と関数型の二件が一致した。表層の結果は matched 51,636、対象外 19、Q11 1、不一致・準備失敗 0。除外 380 件の識別子と理由、全入力の分類理由も N34 の基準と一致した。既存の破損入力 15 件は意図した理由で拒否された。
- `formal-results.json`・`formal-comparison.txt`: 全件の結果と比較の記録。スクリプトが出す正式入口の root の報告も N34 の manifest と厳密に比較した。出力先は `target/desugar-diff/n34a-final` と `target/coverage-diff/n34a-final`。Rust の全件の書き出しには N34 と同じく `CARGO_PROFILE_TEST_OPT_LEVEL=1` を指定した。
- `bash -n scripts/check-formal.sh` と最後の `git diff --check`: 成功。

ユーザーの指定に従い、`scripts/check.sh`（dry-run を含む）、gc-stress の構成の検査、コミット、docs/todo/ の変更は行わない。

## 差分と申し送り

計画の範囲内で正式モデル・六入口・規則の写しを同時に切り替えた。準備済み patch との差は前述の補正だけであり、判断の記録は R101 である。Rust の本番のコードの変更はない。Python の既存の検査の移行は追加 71 行・削除 73 行であり、新しいテストや ignore は加えず、assertion と厳密な期待値を維持した。

N34b は N34 の `cleanup-manifest.json` を出発点として、未登録の Named の一時ファイル、旧形式の Rust の分岐と独立入力、未呼び出しの `check_legacy`・`check_legacy_reports` を削除する。R101 で保持した非重複の assertion は、旧独立入力の書き出しを削除するときに合わせて整理する。段階 A の Core、一般入力と新形式の独立入力、分類理由・件数・破損入力の assertion は引き続き保持する。オーケストレータによる取り込み時の共通検査と gc-stress の検査は今回実行していない。

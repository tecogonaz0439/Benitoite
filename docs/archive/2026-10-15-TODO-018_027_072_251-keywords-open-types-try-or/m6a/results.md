# M6a 版の宣言と固定ハッシュの更新パッチ

2026-10-16、開始時の HEAD は `584955aa6bd709f958481f9bf1f453e0c3e2fcb2`、作業ツリーに変更はなかった。M7 の同時更新のためのパッチと確認表を作り、一時ディレクトリへコピーしたソースで適用後の版と入力を検査した。元の作業ツリーの処理系・入力・crate の版は0.0.5のままである。

## 変更したファイル

- `m6a/01-release.patch`・`02-current-inputs.patch`・`03-boundaries-and-hashes.patch`: M7 用の順序を持つ三つのパッチである。全体で80ファイルを更新する内容で、版・変更表・CHANGELOG、通常入力、診断の厳密な期待値と固定ハッシュを揃えた。
- `m6a/manifest.json`: パッチと各対象ファイルの元のハッシュ、適用順、適用後のハッシュ、確認に使う成果物のハッシュを固定した。
- `m6a/inventory.json`: P1 の一覧を更新した。4,364ファイル、候補2,046件、未分類・未確認0件。P1 からの変更278件・追加92件・削除0件を記録した。
- `m6a/packages.json`・`hashes.json`: package.bnt 52件と全要約対象、要約の変わる47パッケージを記録し、固定値のある3組の新旧の値を独立して計算した。
- `m6a/review.md`: 全対象ファイル、変更と保持の分類、版・診断の対応、test-audit の四問への回答、適用手順を記した。
- `m6a/verify.py`: 元の入力を変えず、ファイル集合とハッシュ、全パッチの順次適用と逆適用、パッケージの各入力のバイト内容、固定ハッシュの要約を照合する作業用の確認器である。
- `decisions.md`: ワークスペース外の古い fuzz/Cargo.lock と日本語文書の翻訳元の版の扱いを R81 に記した。

実際の本番コードと Rust のテストの増減は0行である。パッチ内でも新しいテスト関数の追加・削除、既存の assert の削除・緩和、ignore の追加はない。12個の Rust の対象ファイルは、変更前後の assert マクロの数も同一である。既存の版境界の表の成功・失敗の期待を新しい版へ合わせ、0.0.5の拒否を追加する。help の全文と置換なしの確認は、全該当項目に拡張した。

## 検査と結果

検査は実行前に設計者へ知らせた。cargo のコマンドは rtk 経由で実行した。

| 対象 | コマンド・確認 | 結果 |
|---|---|---|
| 元の0.0.5 | `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、112.15秒 |
| 元の0.0.5 | 下記9ターゲットの統合テスト | 成功。89 passed、既存1 ignored、69.78秒 |
| 元の0.0.5 | `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| 元の0.0.5 | `cargo fmt --all --check` | 成功 |
| 一時コピーの0.0.6 | `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、テスト81.11秒 |
| 一時コピーの0.0.6 | 下記9ターゲットの統合テスト | 成功。89 passed、既存1 ignored、テスト70.63秒 |
| 一時コピーの0.0.6 | `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| 一時コピーの0.0.6 | `cargo fmt --all --check` | 成功 |
| 一時コピーの0.0.6 | `cargo run -p benitoite --example gen_skill` を反復 | 成功。最終の生成物と bundle は元の作業ツリーのものと同一で、生成用パッチは不要 |
| 一時コピーの最終文書 | `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs` | 成功。16 passed、5.36秒。全体検査後に直した説明文の確認 |
| 元の作業ツリー | `python3 -B .../m6a/verify.py` | 成功。三つのパッチ、80ファイルの全段階のハッシュと適用、逆適用による元のバイト内容の復元、候補2,046件の確認状態を照合 |
| 固定ハッシュ | hashlib による元と更新後の独立計算、実際の lib/package CLI/golden の観測 | 3組とも一致。ハッシュ不一致の入力と expected のゼロ64桁は保持 |
| その他の要約 | Wasm の README 3件の SHA-256 と実ファイルの中身 | 全件一致。今回の版更新で中身を変えないため保持 |
| 作業文書・成果物 | `git diff --check`、新規ファイルそれぞれの `git diff --no-index --check /dev/null <file>`、JSON/Python構文と相対リンク | 成功。パッチの空の文脈行も Git が適用できる形で末尾の空白を除いた |

統合テストのコマンドは、両ツリーとも `cargo test -p benitoite --test package_command --test runtime_builtins --test golden --test reference_examples --test skill_docs --test fmt_command --test test_command --test spec_examples --test desugar_export` である。

最初のパッチを一時コピーへ適用した検査では modules の6テストが E0908 の混入で失敗し、通常用の依存設定10箇所の移行漏れを検出した。該当入力の版だけをパッチへ追加し、同じ assert を保って上記の lib 全体を通した。最終確認後に Rust・実行するコード例・期待値を変更していない。後で修正したのは設計書01-03・06-09の説明文と日本語文書の翻訳元の表記であり、最終文書の3スイートを追加で通した。

依頼に従い、scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。formal/ と形式化した規則は変えていないため、lake build と check-formal は対象にしていない。

## 計画との差と申し送り

版の更新と通常入力の同時適用は M7 に残した。元の処理系・通常入力・crate の版にはパッチを適用していない。docs/todo/ の変更とコミットも行っていない。

追加した判断は R81 だけである。fuzz/Cargo.lock の benitoite の項目は今回より前から0.0.1のままであり、数字だけを0.0.6に変える修正を避け、ワークスペース外の依存の再解決を別の作業として申し送る。日本語文書の翻訳元の0.0.5は M8 で本文とともに更新する。日本語リファレンスの通常の版宣言・導入例はパッチに含む。

M7 は [review.md](review.md) と [manifest.json](manifest.json) の順序に従い、まず verify.py で元のバイト内容を照合してから三つのパッチをすべて適用する。ソースに差があれば、ハッシュを無条件に書き換えず内容を再確認する。gen_skill の再生成、所定の段末・形式化・全体の検査は、M7〜M9 とオーケストレータへ引き継ぐ。

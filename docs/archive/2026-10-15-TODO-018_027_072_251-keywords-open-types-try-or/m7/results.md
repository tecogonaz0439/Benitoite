# M7 0.0.6 と通常入力・固定ハッシュの同時更新

2026-10-16、開始時の HEAD は `35be6ae48b8a9673d4a66304de7ee89e9416a6a1`、作業ツリーに変更はなかった。M6a の確認済みパッチを番号順にすべて適用し、crate の版と通常入力を同時に0.0.6へ更新した。

## 変更したファイル

対象80ファイルの一覧と分類は [M6a の確認表](../m6a/review.md)、元と更新後のハッシュは [manifest.json](../m6a/manifest.json) にある。適用前に `python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/m6a/verify.py` を通し、3パッチ・80ファイルの順次適用と逆適用、候補2,046件の確認状態を照合した。

- `crates/benitoite/Cargo.toml`・`Cargo.lock` の benitoite の版を0.0.6へ更新した。根の Cargo.toml には crate の版の定義がなく、変更は不要である。
- `src/modules/package.rs` の BREAKING_CHANGES に0.0.6を追加し、`modules/text.rs` の既存の移行文を本番へ接続した。0.0.5の履歴は維持した。
- 通常の language 宣言、Rust の合成入力、依存の package.bnt、英語の公開文書と導入例を更新した。日本語の通常入力・導入例も確認済みパッチに従って更新し、翻訳元の版は M8 に残した。
- lib・package CLI・golden の固定ハッシュ3組を更新した。ハッシュ不一致の expected のゼロ64桁、旧版・不正な版・未来版の負の入力の意図を保った。
- modules の既存の版境界の表と golden の期待値を更新した。0.0.4以下は2件、0.0.5は1件の移行案内、0.0.6は受理、0.0.7は E0907 を厳密に比較する。
- CHANGELOG の0.0.6節に、die の予約、四型の属性、return 直後の改行継続の廃止、明示 try、裸の try の意味の固定、診断と help の変更をまとめた。

適用後の4,364ソースは、変更対象を manifest の最終ハッシュ、それ以外を inventory の元のハッシュと比較し、全件一致した。52パッケージの全入力も更新後のハッシュと照合した。固定ハッシュ3組は、Rust の二つの fixture の実際のバイト内容と Hashkit の実ファイルから Python hashlib で独立に再計算し、すべて一致した。

## test-audit の関門

1. 守る契約は、通常入力が新しい版でも元の仕事を検査することと、版・内容ハッシュの境界で正しい診断を返すことである。主となる公開境界は既存の modules の読み込み、package CLI、golden である。
2. 捕まえる退行は、通常入力の移行漏れによる E0908、固定ハッシュの更新漏れによる E0919、旧版の案内の欠落・重複・順序の誤り、負の入力の意図の消失である。
3. 既存の版境界の表を拡張し、既存の厳密な比較を新しい版へ合わせた。変更した Rust 12ファイルの assert マクロ数、test 属性数、ignore 属性数は変更前後で一致した。help の全文と置換なしの確認は全該当項目へ拡張し、観測する契約を減らしていない。
4. テスト専用の本番 API・フラグ・ラッパーを加えていない。新しい Rust テスト関数も加えていない。処理系の不具合の修正ではなく、リリースによる仕様上の期待値の更新である。

診断の旧→新の主文・help・位置・終了状態・維持先は [M6a の対応表](../m6a/review.md#版診断の期待値と維持先) に従う。追加の診断仕様変更はない。

Rust の本番コードは12行追加・8行削除、テストは60行追加・55行削除である。テストの増分は既存の版境界の表と全 help の比較への拡張であり、新しいテスト関数はない。

## 検査と結果

検査は実行前に設計者へ知らせた。cargo は rtk 経由で実行した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、80.54秒 |
| `cargo test -p benitoite --lib modules::` | 成功。39 passed、2.03秒 |
| 関連統合テスト9ターゲット（下記） | 成功。89 passed、既存1 ignored、69.76秒 |
| `cargo test --workspace --all-targets` | 成功。2,590 passed、既存44 ignored、47スイート、430.63秒 |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | 成功。2,604 passed、既存44 ignored、47スイート、563.94秒 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物と bundle に差分なし |
| `bash scripts/check-formal.sh` | 成功。lake build、六入口、独立した交換入力、破損入力の拒否と件数・対象外理由の照合がすべて一致 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` と新規作業記録の空白検査 | 成功。既存ファイルの変更は予定した80ファイルだけ、新規ファイルは本記録だけ |
| `target/debug/benitoite --version` | `benitoite 0.0.6` を確認 |

関連統合テストのコマンドは `cargo test -p benitoite --test package_command --test runtime_builtins --test golden --test reference_examples --test skill_docs --test fmt_command --test test_command --test spec_examples --test desugar_export` である。

A4 の E0201 の help は ``start the return value on the same physical line as `return` `` であり、0.0.6の移行文・CHANGELOG と一致する。A4 で移行した wit-transfer の6ファイル・24箇所は変更せず、inventory の照合でも同じ内容であることを確認した。

形式化の出力は `target/desugar-diff/run-78444/` と `target/coverage-diff/run-78444/` にある。六入口の結果は次のとおりである。

| 入口 | 観測した件数・結果 |
|---|---|
| desugarDiff | 全1,741入力。対象内は golden 352件と乱択1,000件、検査で誤りとなる389件、範囲外0件。73,753定義が一致、不一致0件 |
| builtinCheck | 対象内1,352入力、要約の比較72,600件。不一致・非収束・誤り0件 |
| coverageDiff | 通常10,020件、view付き10,028件が一致。不一致・燃料切れ0件 |
| coverageProgramDiff | 対象内1,352入力、match 16,417件と bind 6,036件、合計22,453件が一致。不一致・範囲外・燃料切れ0件 |
| surfaceCheck | 全1,741入力を個別に確認し、成功・除外・既知の拒否の期待が manifest と一致 |
| surfaceCheckAll | 51,652件一致、不一致・準備の失敗0件。既存の範囲外19件と Q11 の1件を理由ごとに manifest と照合 |

corpus 10・型表3・網羅性3の版と全六入口の対応も一致した。独立した幅・名前付き呼び出し・拡張可能な型・tryの正負の交換入力が成功した。三つの契約、六つの一般入力の hole/pipe、六つの名前付き呼び出しの破損を意図した理由で拒否し、外部の型の view を欠く破損も拒否した。新しい axiom・sorry・admit・native_decide や定理の弱化はない。

## 計画との差と申し送り

M6a の3パッチを変更せずに適用した。追加の仕様判断はなく、decisions.md への R の追加は不要である。formal/ と形式化した規則は変更していない。

依頼に従い、scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。これらはオーケストレータの最終検査へ残す。コミット、タグ、公開、docs/todo/ の変更も行っていない。

M8 は日本語訳を英語の最終版から更新する。R81 で既に記録した fuzz/Cargo.lock の古い依存の控えは今回も保持する。M6a の verify.py は適用前の元の内容を検証する道具であり、適用後のツリーへそのまま再実行するものではない。

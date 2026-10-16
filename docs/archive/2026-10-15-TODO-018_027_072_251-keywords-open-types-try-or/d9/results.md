# D9 D の文書と段末検査

## 目的と test-audit の作成時の関門

D の実装済みの規則を、設計書・英語リファレンス・同梱 Skill に揃える。基準は `47fab7e777272e6a33ceb553fe6b1c33d65683f8`（作業開始時に差分なし）である。

1. 追加する英語リファレンスの例の境界は、既存の reference_examples が呼ぶ実際の CLI である。Result の失敗側で外部の拡張可能な record を分解する案内と、構築・更新・getter の出力が文書どおりであることを守る。
2. record の `..` が将来の形まで覆うと誤認して必要な分岐を除く、getter で取る欄を取り違える、型注釈・名前付き引数の例を誤る変更で失敗する。期待する二行の出力は手で定める。
3. D8 の型検査と golden が本体の規則を守る。今回の例は英語リファレンスのコピーして実行できる案内を確かめるもので、Rust の検査の重複追加はしない。既存の文書例の実行器をそのまま使う。
4. 本番の公開範囲・型・引数・検査用の差し込み口を変えない。既存の assert・期待値・ignore を変更しない。

## 検査の方針

依頼の明示的な指定に従い、scripts/check.sh は dry-run を含めて実行せず、gc-stress の構成も実行しない。これらはオーケストレータの最終検査へ引き継ぐ。D9 の両構成の workspace all-targets は、既定構成と gc-mark-sweep,heap-verify（gc-stress なし）で順に実行する。形式化の六入口は scripts/check-formal.sh で全件を再照合する。

## 変更と診断の照合

用語集、01-03 のパッケージの境界、01-05 の四型・record の制限・互換性、03-10 の WIT の別契約、06-06 の手書き Skill の案内を更新した。07-04 の作業 ID による説明を現在の書き出し器の説明へ替えた。Lean の Coverage と CoverageShow に残る「先行モデル」のコメントを接続済みの説明へ直した。Lean の定義・定理・前提・結論・公理依存は変更していない。

英語リファレンスには属性・内外の境界・入れ子・診断の修正方法・四型・互換性・WIT の説明と、実行できる例一件を加えた。Skill の三つの手書き文書にも四型と record の制限を反映した。gen_skill を実行し、生成物と bundle.rs に差分がないことを確認した。構文の章・標準ライブラリのソース・診断表は変更していない。

診断の仕様変更はない。E0601/E0607 のコード・主文・help・主/副位置・終了状態は開始時の実装と同じであり、R43 の E0607 の案内を仕様の文章にも揃えた。既存の golden、診断の期待値、Rust のテスト・本体は変更していない。計画と異なる実態による追加の判断はなく、decisions.md への R の追加はない。

形式化の二つの manifest は開始時とバイト単位で同一である。六入口の照合でも、既存入力の診断列・対象内件数・対象外理由をこの一覧と比較した。

| 一覧 | SHA-256 |
|---|---|
| routing-manifest.json | `2c0dcc50f96c9df39da0f8fe437d693c6848254af19074a5079a73499b6ec969` |
| exchange-manifest.json | `012f0ac39dd752c1329fcbce94ce28138debc9fad94289b483adabe8056b91ab` |

## 検査の結果

| コマンド | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。生成物に差分なし |
| `cargo test -p benitoite --lib --test reference_examples --test skill_examples --test skill_docs --test spec_examples` | 成功。lib 1,162 件、reference_examples 1 件、skill_examples 3 件、skill_docs 8 件、spec_examples 7 件。既存の lib の ignore 21 件を維持 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check`・`git diff --check` | 成功 |
| `python3 tools/spec-coverage/spec_coverage.py --self-test` と同ツールの通常の集計 | 成功。完了条件の未記入なし |
| `cargo test --workspace --all-targets` | 成功。46 ターゲット・2,523 件成功、既存の ignore 44 件 |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | 成功。46 ターゲット・2,537 件成功、既存の ignore 44 件 |

両構成は lib を含み、最後の wit_transfer_cost の example に含まれる本体のテストも実行した。heap-verify では機能に固有の検査があるため件数が増える。

## 形式化の六入口

`BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/d9-final BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/d9-final bash scripts/check-formal.sh` を実行し、終了状態 0 で完了した。check-formal.sh は計画にある六入口の専用検査であり、gc-stress の構成を含まない。

| 工程・入口 | 結果 |
|---|---|
| formal/ の `lake build` | 成功（56 秒）。Lean の定義と証明は不変、新しい axiom・sorry・admit・native_decide なし |
| `coverageDiff` | 通常 10,020 件・view 付き 10,028 件が全件一致。不一致・燃料切れ 0 |
| 交換形式の独立した正負の検査 | width 4 件・named 12 件・extensible 22 件が成功 |
| Rust の脱糖の全入力の書き出し | 成功。17 テスト、1,735 入力中 1,349 入力を出力、既存の静的エラーの 386 入力を維持。560.65 秒 |
| `desugarDiff` | golden 349 入力・968 定義、乱択 1,000 入力・72,778 定義が一致。不一致・対象外 0 |
| `builtinCheck` | 1,349 入力・72,468 比較が一致。不一致・非収束・欠けた組み込みや構成子 0。既存の対象外理由を維持 |
| `coverageProgramDiff` | 1,349 入力、match 16,417 件・bind 6,036 件、計 22,453 件が一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 一致 51,645 件、既存の対象外 19 件・Q11 一件を維持。不一致・準備の失敗・lazy の制限の違い 0 |
| `surfaceCheck` と最終の六入口の照合 | 1,735 入力・73,746 定義・22,453 網羅性入力の識別子・件数・対象範囲・診断による除外が固定 manifest と一致。194 秒 |
| 破損入力の拒否 | 契約三件・hole/pipe 六件・交換形式六件を意図した理由で拒否。外部の IOErrorKind の view の欠落と定数の所属の検査も成功 |

六入口の全件比較は、開始時の二つの manifest を変えずに成功した。対象内件数・対象外理由・静的エラーの分類の下方修正はない。G3a の R45 で増えた record の match 一件を含むため、網羅性の総数は D8 の作業当時の 22,452 件から開始時の 22,453 件になっている。これは D9 による追加ではない。

## ログと後の作業への申し送り

Rust の個別検査・両構成の全ターゲット・Clippy のログは `/private/tmp/d9-required-tests.log`・`/private/tmp/d9-all-targets-default.log`・`/private/tmp/d9-all-targets-heap-verify.log`・`/private/tmp/d9-clippy.log` に、形式化は `/private/tmp/d9-formal.log` に保持する。spec-coverage の集計は `/private/tmp/d9-spec-coverage.log` にある。全交換入力と結果の JSON は上記の target/ の二つのディレクトリに保持する。

[G3b・G3 全体のレビュー用の照合](../reviews/G3b-request.md) を作成した。外部レビューの完了は主張しない。check.sh（dry-run を含む）・gc-stress の最終検査と G3b/G3 の取り込み判断はオーケストレータへ引き継ぐ。版の変更・E0908・CHANGELOG の公開用の移行案内・日本語訳の最終照合は M の作業で行う。

削除したテストと削除の候補にしたテストはない。Rust の本番コード・テストの行数の増減はいずれも 0 行である。formal/ の差分はコメント二行の置換だけである。コミットと docs/todo/ の変更は行っていない。

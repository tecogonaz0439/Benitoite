# M8 日本語訳と全サンプルの最終照合

2026-10-16、開始時の HEAD は `7ffaea1010c25fd6b4f4f70dc159ad30775c26d0`、作業ツリーに変更はなかった。M7 の最終の英語版から日本語訳を更新し、M8 の照合と指定の検査を完了した。

## 変更したファイル

- docs/ja/reference/benitoite.md に、拡張可能な四型、パッケージの境界、record の分解と互換性の制限、明示 try、Show、Process.Exit と終了報告、return 直後の改行の規則、WIT の厳密な照合を反映した。
- docs/ja/skill/SKILL.md と手書きの references 3ファイルを、英語の最終版へ揃えた。入口の die と再利用する関数の return を書き分け、import・uses・戻り値と出力の契約も原文に合わせた。
- docs/ja/reference/install.md を含む6ファイルの翻訳元の版を0.0.6へ更新した。導入例の版とコマンドは M7 で更新済みであり、英語版との一致を確認した。
- [review.md](review.md) に照合表と保持理由、[audit.json](audit.json) にコード・見出し・リンク・ハッシュ・候補の対応を残した。[audit.py](audit.py) はその作業記録を再確認する読み取り専用の道具であり、通常の検査には接続していない。

英日6組の184コードブロックが完全一致し、見出し103組とローカルリンク183件を照合した。try を含む実行用ブロックは各言語20個で、構文・型の検査を通った。各言語の TryExpr は51件（return 19、die 32、裸0）である。全追跡入力の走査は2,995入力・3,850候補であり、移行の必要な候補0件、未分類・未確認の現行サンプル0件である。M5 の日本語5ファイル・46候補の引き継ぎも照合表で閉じた。

## test-audit の関門と診断

1. 守る契約は、最終の英語版と訳のコード・版・説明が一致することである。コードの実行は既存の spec_examples・reference_examples・skill_examples、生成物は skill_docs を主となる境界とする。
2. 捕まえる退行は、明示する処置と uses・戻り値の不一致、四型や record の制限の説明漏れ、return の改行の誤った案内、版やリンクの更新漏れである。コードの完全一致・全ブロックの解析と、本文の照合を組み合わせた。
3. 処理系のテストは追加・変更していない。既存の公開境界の検査を使い、翻訳の一致は作業の照合記録として確認した。既存の assert、期待値、ignore、裸の検査入力を変更していない。
4. テスト専用の本番 API・フラグ・ラッパーは加えていない。Rust の本体とテストの行数の増減はいずれも0行である。

診断の仕様変更はない。コード・主文・help・主/副位置・終了状態・元の誤りの検査は従来のままであり、文書の説明だけを英語版へ合わせた。Skill の生成元・生成物・bundle、formal/ は変更していない。

## 検査と結果

実行する検査は、事前に設計者へ知らせた。cargo は rtk 経由で実行した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、81.83秒 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 成功。4スイート・19 passed、10.26秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| try-actions-migrate の最終 inventory | 成功。change 0件、全3,850候補の件数が一致 |
| M8 の audit.py | 成功。全入力のハッシュ、英日コード・見出し・リンク、40実行用ブロックの構文と型、残す候補173件を照合 |
| `git diff --check` と新規の作業記録の空白検査 | 成功 |

## 計画との差と申し送り

追加の仕様判断はなく、decisions.md への R の追記は不要である。移行手順は CHANGELOG へ集めたままにした。日本語訳を Skill の配布ディレクトリへ加えていない。

依頼に従い、scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。これらと M9 の公開前の全体検査はオーケストレータへ残す。formal/ を変更していないため、lake build と check-formal は実行していない。コミット・公開・docs/todo/ の変更も行っていない。

M9 では、この最終の訳と英語版の組で G8 の公開前確認を行う。M7 からの既知の申し送り（R81 の fuzz/Cargo.lock の古い依存の控えなど）は今回の変更の範囲外として保持した。

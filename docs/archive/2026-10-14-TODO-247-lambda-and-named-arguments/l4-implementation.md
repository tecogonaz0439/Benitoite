# L4 文書上の推奨と段 1 の例

## 範囲と確認の方針

Q13 と R20 に従い、現行の設計書・英語リファレンス・同梱 Skill の一般例を揃える。位置呼び出しと現在の関数型を使い、構文の有効性と文書上の推奨を分ける。構文説明・専用の検査例・過去の記録は残す。Z1 の書き直しの一覧を確認し、翌行の終端を内側が取る説明や R19 の空行保持を再導入しない。

## 例の変更前の test-audit の関門

1. 守る契約は、文書の例が現行の構文と局所束縛の規則に従い、実行例の出力・終了状態・診断を維持することである。`if` から `match` への変更では条件の評価回数・順序・選択された分岐だけの評価と `return` の作用先を保つ。
2. 短い形の外側の区切りの取り違え、包括的な変数名と局所名の衝突、作用を持つ条件のガードへの移動、`return` の脱落で失敗する。
3. 既存の `spec_examples`・`reference_examples`・`skill_examples` が文書から入力を取り出し、本物の解析・名前解決または CLI の実行を通す。これらの入力を更新し、期待する出力や診断と既存の assert は維持する。別の層に同じテストは追加しない。
4. 本番コードへの差し込み口は不要である。文書と生成元を変更し、`gen_skill` と既存の `skill_docs` で生成物の一致を確かめる。

作用を持つ条件の例を英語リファレンスに加える前にも、この関門を適用した。条件を表示する実行例で、第一条件が真なら第二条件を実行せず、偽なら一度だけ実行することと、入れ子の `return` が元の関数から抜けることを出力で確かめる。一般例の既存の純粋な条件だけではこの違いを観測できないため、`reference_examples` の既存の実行器に一例だけ加える。ガードへの作用の移動、条件の先行評価・重複評価、`return` の作用先の変更を検出でき、本番の差し込み口は不要である。

## 検査

| 検査 | 最終結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。生成元は R18 どおり `src/cli/tools/skill/generate.rs`。文法の参照文書を再生成し、他の生成物と埋め込み一覧には差分なし |
| `cargo test -p benitoite --lib` | 1128 成功、失敗 0、既存の ignore 21。約 63 秒 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_examples --test skill_docs` | それぞれ 7・1・3・8 成功、失敗 0 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

最初のライブラリテストは R21 の固定件数だけで失敗した。調整後、該当テスト単独とライブラリ全体を再実行して成功した。最終の文書例の検査は、例の変更と再生成を終えた後にも実行した。

英語リファレンスと Skill の手書き文書の既存の `output`・`diagnostic`・`stderr` のブロックを HEAD と比較し、追加した条件の例の出力を除き全件一致した。既存の assert・診断の期待・終了状態を弱めず、ignore を追加していない。Rust の差分は、生成器の案内文（13 行追加・1 行削除）と既存テストの件数・添字の二行だけであり、実行の規則は変えていない。

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は実行していない。formal/ と形式化の規則は変更していないため、Lean のビルドと形式化の差分検査は実行していない。コミット、docs/todo、訳、過去の記録にも変更なし。

## 固定件数と検査対象の番号の調整（R21）

変更前のライブラリテストは `specification_examples_and_golden_programs_parse` の `assert_eq!(examples.len(), 11)` で、実件数 14 のため失敗した。新しい構文例三つを加えた結果、元の `area` と `total` を含む例も添字 8 から 11 へ移った。件数を 14、添字を 11 へ更新し、すべての既存の assert を維持する。

この変更前の test-audit の四つの答えは、(1) 文書の全例を解析し、元の二分岐と入れ子のパイプの AST を維持する契約、(2) 例の取り出し漏れ・構文誤り・異なる AST で失敗、(3) 主となる既存テストを更新し、別の層にテストを増やさない、(4) 本番コードへの差し込み口は不要、である。件数と番号以外の入力・診断・AST の期待を変えず、範囲の比較にも緩めない。

## 後の作業への申し送り

L4 の文書例は段 1 の位置呼び出しと関数型を使う。N1 の基準と分類は、この変更後の例を対象にする。名前付きへの最終変更は N31・N32、訳は N35 で行い、段 1 だけの文書は公開しない。取り込み時の `scripts/check.sh` と gc-stress の検査はオーケストレータが行う。計画との差は R21 の既存テストの固定件数・添字への対応だけである。

# M3 設計書・英語リファレンス・Skill の全サンプル

2026-10-16、開始時の HEAD は `c5bb6132ae9d`、作業ツリーに変更はなかった。M3 のサンプル移行と指定の検査を完了した。コミット、docs/todo の変更、check.sh と gc-stress の検査は行っていない。

## 変更

- 設計書の01-02・01-07・01-09・01-10・01-11、03-07・03-08・03-09、06-04、付録08-04のコードとインラインの利用例を明示形へ変更した。再利用する関数、ハンドラを教える例、同じ失敗値を返す契約の例は `or return` とし、型と uses を保った。
- 英語リファレンス、Skill の SKILL.md と手書きの idioms・common-mistakes・language-comparison を更新した。一回限りの11個の入口では30箇所に `or die` を採り、main を Unit にし、Process.Exit と import を合わせた。標準失敗型を表示するだけの mapError を除き、成功時の出力を維持した。main の Result.Error を教える例と SKILL.md の空ファイルを返す契約の例は `or return` にした。
- diag/codes.rs の E0211 question の修正例を `try parse(text) or return` にした。lexical/unknown_symbol.diag.json の help だけを同じ全文へ変更し、diag/render/help_tests.rs の既存テーブルへ一行と厳密な全文の assert を追加した。既存の assert の削除・比較の緩和・ignore の追加はない。本体の Rust は1行を置換し、テストの Rust は13行を追加した。
- gen_skill で diagnostics.md を再生成した。ほかの生成物と bundle の内容に差はない。文書のテストの戻り値の説明も、返す処置と終了する処置を区別した。
- decisions.md に R78・R79 を追記した。処理系の構文・型・脱糖・形式化は変更していない。

## 候補と適用の確認

[review.md](review.md) は初回の56入力・375候補を一件ずつ対応付ける。機械適用は56箇所（return 26、die 30）で、確認済み manifest の SHA-256 は `8d123dff52de87d098bb62768418bf42ccd10a241e292141f7a306aee3a234d1` である。適用と再適用の差分なしを確認した後、省略した説明例8箇所と benitoite test の4箇所、インラインの利用例、修正案の説明を手で変更した。元の `typed: false` と機械抽出の保留理由は改ざんしていない。最終の確認結果は review.md に記録し、未確認・未解決の現行サンプルは0件である。

適用の順は approved.diff → manual.diff → inline.diff である。記録自体に末尾の空白を残さないため、差分は文脈0行で保存した。HEAD の元のファイルを一時ディレクトリへ復元し、`git apply --unidiff-zero` で三つを順に適用すると、現在の全編集先とバイト単位で一致することを確認した。receipt は機械適用直後の記録であり、後の手作業まで含む最終ツリーへの再適用には使わない。

最終の113入力・424候補を再走査した。自動分類は already_explicit 134、hold 83、notation 207である。残る hold は生成元の文言や記法の確認を要する自動分類であり、review.md と全コードブロックの確認で解消した。AST の裸26件はすべて、型規則・脱糖・裸の意味・優先順位を説明する一般形である。block-audit.json では、try を含む37ブロックを調べた。うち5件は EBNF・キーワード列などの記法、残る32件はソースの例であり、その72個の TryExpr は return 40、die 32、implicit_return 0である。最小版リファレンスと導入手順に try の実行例はなかった。

既存の実行例の output・stderr・diagnostic、ハンドラと assert は変更していない。コードブロックの言語指定を変えて検査を外していない。裸の形を確かめる .bnt、Rust の既存入力、fuzz・ランダム生成器は変更していない。golden の変更前後の JSON を比較し、question の help 以外の全フィールドの一致も確認した。最終入力のハッシュは final-inventory.json と一致する。

## test-audit の関門

1. 主となる境界は公開の parser が返す診断と、CLI の既存 golden である。修正例が失敗時の処置を明示し、置換用の edit を添えない契約を守る。文書のコードは既存の仕様例・リファレンス・Skill の検査で確認する。
2. question の修正例から処置を落とす退行を、独立した全文の assert で捕まえる。旧文言のまま追加したテーブルを実行し、旧 help と新しい期待全文の不一致で失敗することを確認した。
3. 既存テーブルは型板との一致を確かめるため、生成元の型板と一緒に処置が消えても検出できない。一行と二つの assert を同じ既存テストへ加えた。golden は位置・JSON・CLI の接続を独立して守るため残した。別の重複テストは増やしていない。
4. 実際の lexer と parser、既存の CLI・文書検査を使った。本体の公開 API・フラグ・テスト専用の差し込み口は追加していない。

## 診断の対応

| 項目 | 旧 | 新 |
|---|---|---|
| コード | E0211 | E0211。計画の E0201 question は実態と異なるため R78 に記録 |
| 主文 | `` `?` is not an operator in Benitoite `` | 同じ |
| help | ``write `try` before the expression, such as `try parse(text)` `` | ``write `try` before the expression, such as `try parse(text) or return` `` |
| 主位置 | unknown_symbol.bnt 5行3列、offset 77〜78 | 同じ |
| 副位置・notes・edits | なし | 同じ |
| 終了状態 | 2 | 2 |
| 元の誤りの検査 | unknown_symbol の golden と parser の診断 | 同じ入力を維持し、help の全文を既存テーブルでも厳密に比較 |

## 検査

| コマンド・確認 | 結果 |
|---|---|
| `cargo build -p benitoite --example try_actions_inventory` | 成功 |
| 移行器の inventory、確認済み manifest の diff・apply・再apply | 成功。11ファイルへ56候補を適用後、already applied; no diff |
| question のテーブルだけのテスト（変更前） | 期待どおり失敗。旧 help に or return がないことを確認 |
| `cargo test -p benitoite --lib` | 1,194 passed、既存21 ignored。81.49秒 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test golden` | 5スイート・21件成功。69.99秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。二度目は59ファイルの全ハッシュが一致 |
| `cargo test -p benitoite --test spec_examples --test skill_docs`（最終の再生成後） | 2スイート・15件成功。3.41秒 |
| 全 fence の実際の parser による確認、最終113入力のハッシュ比較 | 成功 |
| 三つの差分の元ファイルへの順次再適用と最終バイト列の比較 | 成功 |
| `git diff --check` と新規記録の空白の検査 | 成功 |

最後の lib・統合テスト・clippy・fmt の後、Rust と実行する文書例のコードは変えていない。形式化に触れていないため lake build と check-formal は実行していない。依頼に従い check.sh は dry-run も含め実行していない。gc-stress の構成の検査と全体の検査はオーケストレータへ残す。

## 計画との差と申し送り

計画との差は、question の実際のコードを E0211 として扱う R78 と、移行器が解析しない実行用 fence・省略した例を個別に手で確認する R79 である。仕様・型・脱糖・公開のシグネチャを変える追加の判断はない。

M4 は標準ライブラリの実装、examples、例を作るソース、現在の tools を扱う。M5 ではこの確認表と P1 の裸の検査の基準を照合する。版・ハッシュの更新は M6a・M7、日本語訳は M8 に残す。今回の移行 manifest はこの作業の開始時の入力に固定しており、M4 の候補へ流用しない。M1 の旧移行器の基準データ欠落は今回のサンプル移行に持ち込まず、既存の残件として引き継ぐ。

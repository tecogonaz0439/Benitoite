# Z6 G6 のレビュー指摘の修正結果

## 変更

G6 の指摘をすべて修正した。開始時の HEAD は `ca6d2bbbb3e5c79338651e7a783e0a98276cc93a`、作業ツリーに差分はなかった。

| ファイル | 変更 |
|---|---|
| [harness-response.md](../harness-response.md) | dirty の自動採取をやめた理由と通常ビルドの値、list/show の名前の保証、loaderEnvironment の各欄、形式の版を上げる条件、古い commit が残る限界、root と Target.status、E0512.notes の非安定性と集合差、書き込み失敗の優先、検査範囲・オプションの位置・提供予定の言い回しを修正。JSON のビルド情報と一覧62件を実出力に更新 |
| [SKILL.md](../../../../crates/benitoite/skill/SKILL.md) | 修正中は通常の check／test --check を使い、実行の確認の直前に一度 JSON 報告を取得する手順へ変更。inspection.md を必要なときに読むよう案内 |
| [inspection.md](../../../../crates/benitoite/skill/references/inspection.md)、[idioms.md](../../../../crates/benitoite/skill/references/idioms.md) | ハーネス向けの契約を新しい手書き文書へ移動。idioms のテストの手順も同じ流れへ更新 |
| common-mistakes.md、language-comparison.md | 移動した節へのリンクを inspection.md へ更新 |
| examples/skill_support/paths.rs、src/cli/tools/skill/bundle.rs | 手書き文書の生成元一覧へ inspection.md を追加し、gen_skill で埋め込み一覧を再生成。生成された文法・診断・標準ライブラリ文書の差分はない |
| 06-06 | SKILL.md の手順、版と文書の取得、実行前に使う報告、参照文書と翻訳対象の一覧、空の許す集合の表記を揃えた |
| 02-11、06-01、00-03 | 検査範囲を「外部の関数の照合まで」に統一。初回リリース版の後に加えた宣言上限の報告と包含の照合をロードマップに追記 |
| [decisions.md](../decisions.md) | R29 に文書の分割と生成・翻訳・評価の扱いを記録 |
| [G6.md](../reviews/G6.md) | 依頼に付いたレビュー全文をそのまま保存 |
| [cli-observations.json](cli-observations.json) | 今回の実行ファイルによる入力と22呼び出しの引数・終了状態・出力を保存。新文書の長さ・ハッシュも記録 |

処理系の動作、公開の引数・JSON の形式・診断・終了状態は変えていない。テストファイル、既存の assert・期待値・ignore は変更していない。formal/、docs/todo/、docs/ja/ は変更せず、コミットしていない。

## 検査

実行する検査を事前に知らせ、既定構成で実施した。gc-stress の構成と scripts/check.sh は実行していない。

| コマンド・確認 | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。二回目の生成前後でファイルの SHA-256 がすべて一致 |
| `cargo build -p benitoite --bin benitoite` | 成功。最終のリンク修正を含む target/debug/benitoite から実出力を採取 |
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。80.25秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test l13_external_commands --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 7 suites、87 passed、0 failed。27.33秒 |
| `cargo clippy --all-targets` | 成功、指摘なし |
| `cargo fmt --check` | 成功 |
| skill-creator の `quick_validate.py crates/benitoite/skill` | 成功 |
| `git diff --check` | 成功 |
| 文書の相対リンク | 変更文書の172件でファイル・見出しの存在を確認。移動した旧見出しへのリンクは残っていない |
| 実出力との照合 | 回答の JSON 例9件を抜粋の範囲も含め構造で比較し、BNT 入力例2件も一致。main/test のソース数44/41、Skill の一覧62件を確認 |
| Skill の埋め込み | 全62件の list/show の本文・バイト数・SHA-256・名前の規則が一致。references の本文は作業ツリーのファイルともバイト単位で一致 |
| その他の契約 | 記録した22呼び出しは期待した終了状態と一致。ローダ変数の拒否で子の marker は作られない。回答文に内部の作業 ID・R/Q の番号・plan.md・results.md・docs/todo への言及はない |

## 計画との差と申し送り

計画 D2b の手書き三文書に inspection.md を加える最小の変更を R29 の「推す案」として記録し、適用した。これに伴い一覧は61件から62件となる。仕様や実装の範囲を広げる判断はない。

- M3b: SKILL.md、idioms.md、common-mistakes.md、language-comparison.md の日本語訳を更新し、inspection.md の日本語訳を追加する。英語版を正とし、日本語訳は Skill の埋め込みに含めない。
- Skill の手順変更が成功率と修正の負担に与える影響は、skill-eval で評価する必要がある。LLM を呼ぶ評価は今回実施していない。設計者の了承を得た後の作業へ渡す。
- scripts/check.sh と gc-stress の構成の最終検査はオーケストレータへ渡す。版の更新・取り込み後は、回答のビルド情報・版・件数・本文の長さとハッシュを提供する実行ファイルで再確認する。

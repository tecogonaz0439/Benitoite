# N35a の実装記録と訳の確認表

## 範囲

N35 を取り込んだ `c8eafb53` の英語版を正として、既存の日本語訳 6 ファイルを Benitoite `0.0.5` に更新した。処理系・英語版・生成物・テストの実装は変更しない。最小実行版の文書、過去の記録、docs/todo/ は変更しない。

## 訳の確認表

コードブロックは、情報文字列・コード・コメント・期待出力・標準エラー・診断・補助ファイル・シェルの例を含め、英語版と順序も含めて完全一致することを確認した。`SKILL.md` の訳だけにある「原文の前付け」のブロックは、本文の比較から除いて別に照合した。コードブロック以外では、追加・変更した段落のコード表記を英語版と照合し、既存訳の補足や反復は維持した。

| 英語版 | 日本語訳 | コードブロック数 | `benitoite` の例 | 診断ブロック数 | 結果 |
|---|---|---:|---:|---:|---|
| [言語リファレンス](../../reference/benitoite.md) | [言語リファレンス](../../ja/reference/benitoite.md) | 58 | 20 | 2 | 一致 |
| [導入手順](../../reference/install.md) | [導入手順](../../ja/reference/install.md) | 10 | 0 | 0 | 一致 |
| [Skill 本文](../../../crates/benitoite/skill/SKILL.md) | [Skill 本文](../../ja/skill/SKILL.md) | 4 | 2 | 0 | 一致 |
| [idioms](../../../crates/benitoite/skill/references/idioms.md) | [idioms](../../ja/skill/references/idioms.md) | 43 | 20 | 0 | 一致 |
| [common-mistakes](../../../crates/benitoite/skill/references/common-mistakes.md) | [common-mistakes](../../ja/skill/references/common-mistakes.md) | 56 | 28 | 16 | 一致 |
| [language-comparison](../../../crates/benitoite/skill/references/language-comparison.md) | [language-comparison](../../ja/skill/references/language-comparison.md) | 5 | 2 | 0 | 一致 |
| 合計 | | 176 | 72 | 18 | 一致 |

`benitoite` の例の件数には `check`・`test`・`error` のブロックも含む。訳の更新前は、6 組すべてでコードブロックが最終の英語版と不一致だった。更新後は全組で一致し、英語版の既存の検査で例の振る舞いを確かめた。

| 照合する内容 | 確認した内容 |
|---|---|
| 版と宣言 | 翻訳元・現行版・導入のコマンド・通常入力の `language` を `0.0.5` に揃えた。`0.0.4` は移行元と過去のリリースの説明にだけ残る |
| 通常の呼び出し | 複数引数の名前必須、混在の禁止、一引数の省略、任意のラベル順とソース順の評価、専用構文との区別を反映した |
| 関数型とコールバック | 一引数でも名前と宣言順が契約に含まれること、未使用名の維持、明示のラムダで契約を合わせる方法、E0454・E0455 の対処を反映した |
| 穴とパイプ | 穴の名前と記述順、遅延した評価、最初のパラメータへの挿入、重複、二つの穴を自動で再部分適用しない規則を反映した |
| ラムダの終端 | 同一物理行の条件、見出しの行で始めた本体の終端、外側との対応、直接の入れ子の括弧、旧二行形式の移行を反映した |
| 文書上の推奨 | `match`・短いラムダ・衝突しない包括的な名前を推奨し、`shadow`・`else`・`else if` は有効だが非推奨とした。評価順と `return` の作用先を保つ案内も反映した |
| 移行と診断 | E0257・E0449・E0451〜E0455、未来版の E0907、旧版の E0908、language なしの新規則、依存のハッシュと Skill の更新を英語と照合した |
| リンクと配布 | 訳の 86 件のリンクの対象ファイルと見出しを確認した。新しい移行節と目次の参照は日本語の見出しを指す。生成参照文書への案内は英語の原文を指す。訳は配布する Skill の外に保った |

## テストの作成時の関門

1. 訳の例が最終の英語版と同じ出力・診断・契約を示すことを守る。既存の assert と期待出力・診断は、英語の最終版と同じものを保つ。
2. 位置引数の残存、ラムダの契約名の取り違え、古い版の宣言、例や診断の転記漏れがあれば、英日照合が失敗する。更新前の 6 組の不一致も確認した。
3. 英語版の例は `reference_examples` と `skill_examples` が既に実行する。日本語訳との完全一致を別に確認することで転記漏れを検出し、同じ例を実行する恒久的なテストは追加しない。`skill_docs` で既存の生成・埋め込みの契約も確認する。
4. 本番の API・公開範囲・フラグ・テスト用の差し込み口は追加しない。Rust の本番コードとテストは、ともに行数の増減ゼロである。テストの削除・弱化・ignore の追加はない。

## 検査

- `cargo test -p benitoite --lib`: 1,155 件成功、既存の ignore 21 件。
- `cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples`: 12 件成功（1・8・3 件）。
- `cargo clippy --all-targets`: 成功。
- `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats`: 成功。
- `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`: 成功。
- `cargo fmt --all --check`: 成功。
- 英日照合: コードブロック 176 個、追加・変更段落のコード表記、リンク 86 件が一致。
- `git diff --check`: 成功。確認表の 12 件のファイルリンクも確認した。

## 申し送り

計画からのずれと追加の設計判断はない。依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress の構成は実行しない。formal/ の変更はないため、lake build の対象はない。コミット・タグ・公開は行わない。N36 では、この最終の訳と版で公開前の全体検査を行う。

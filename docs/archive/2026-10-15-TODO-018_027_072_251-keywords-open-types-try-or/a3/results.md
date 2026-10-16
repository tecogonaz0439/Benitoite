# A3 語の文書と生成物の作業記録

## 目的と変更した範囲

A1・A2 で実装済みの語の分類と名前の拒否を、現在の設計書と同梱 Skill に反映した。追加する語は `die` 一語で、合計は 35 語である。`die` の式・try の処置、`@extensible`、return の一般の改行規則は今回の受理範囲に加えていない。

| ファイル | 変更 |
|---|---|
| `docs/design/01-spec/01-01-lexical.md` | 35 語、`die` の予約と近い綴りの識別子、名前の各位置での拒否、文脈で読む語と並行処理の非予約語を明記 |
| `docs/design/01-spec/01-02-syntax.md` | EBNF の識別子からキーワードを除くこと、省略形を構文として使わないこと、属性名の分類を明記。属性の一覧と文法は維持 |
| `docs/design/02-impl/02-03-frontend.md` | 字句の一覧を 35 語へ更新。識別子として切り出す語、KwDie の改行・境界走査・parser の扱いを明記 |
| `docs/design/02-impl/02-10-diagnostics.md` | `die` を名前にした E0216 と、式として書いた E0201 の既存の案内を記載 |
| `docs/design/06-tooling/06-06-agent-skills.md` | design.md「文書・形式化への反映」に従い、Skill の要約と生成文法で語の分類と未受理の範囲を案内することを記載 |
| `docs/design/07-quality/07-04-formal-semantics.md` | キーワードの分類・名前の拒否・文脈で読む語の検査を、形式化の対象外として明記 |
| `crates/benitoite/skill/SKILL.md`、`skill/references/common-mistakes.md` | 35 語と文脈で読む語の英語の案内。`die` と `@extensible` が未受理であることを明記 |
| `crates/benitoite/src/cli/tools/skill/generate.rs` | 生成する grammar の英語の導入にも同じ分類と未受理の範囲を記載 |
| `crates/benitoite/skill/references/grammar.md` | gen_skill で再生成。生成物を手で編集していない |
| `crates/benitoite/tests/spec_examples.rs` | キーワード一覧ブロックを識別する固定文字列に `die` を追加。一致の厳密さと失敗を要求する検査は維持 |
| この作業記録 | 変更範囲、関門、検査、後続への申し送り |

B/D の未実装の文法・型・実行の説明は、この改造ディレクトリの [design.md](../design.md) に留めた。設計書の見出し・文法・コード例は変更していない。英語リファレンスと日本語訳の変更もない。

## test-audit の作成時の関門

1. 語の振る舞いの主となる公開境界は既存の lex・resolve_newlines・parse の表である。生成物は `tests/skill_docs.rs`、手書き Skill の例は `tests/skill_examples.rs`、仕様の例は `tests/spec_examples.rs` で検査する。
2. 捕まえる退行は、予約語の追加による既存入力の拒否、名前位置の診断の接続漏れ、生成物の更新漏れ、既存の文書の例と実装の不一致である。
3. A1・A2 の表が `die` と非予約語の正負の振る舞いを既に検査している。A3 は説明を揃える作業なので、一覧を写すテストや他の層で同じ入力を繰り返すテストは加えていない。`spec_examples` には旧キーワード一覧の先頭行を完全一致で引く表があり、その識別文字列だけを新しい先頭行へ更新する。既存の表で同じブロックの存在と解析の失敗を引き続き要求する。
4. 本番の公開範囲・引数・フラグ・テスト専用の差し込み口は変更していない。

テストの変更前に `spec_examples` が旧先頭行との不一致で失敗することを確認した。変更は既存の一覧ブロックの識別文字列の更新だけであり、assert・比較方法・ignore・時間制限・表の項目数を変更しない。新しい対象外理由や skip は追加しない。Rust の本番のコードの差分は生成文書の定数の追加 6 行、削除 0 行であり、テストは 1 行の置換、差し引き 0 行である。

## 診断と計画との対応

A3 による診断の仕様変更はない。E0216/E0201 のコード・主文・help・主/副位置・終了状態は、[A1 の診断の対応表](../a1/results.md#診断の対応)のとおりである。静的検査の失敗の終了状態は 2 を保つ。診断の表の生成元 `diag/codes.rs` と診断の生成物には差分がない。

計画の変更ファイルの補足は、`spec_examples` の固定の照合文字列の更新である。判断と理由は [decisions.md の R23](../decisions.md#r23-仕様例の検査が使うキーワード一覧の識別文字列)に記した。生成物の導入の説明は `generate.rs` の定数を変更してから再生成した。formal/・01-12 の型付けと脱糖の規則は変更していないため、lake build/check-formal を要する変更はない。docs/todo/ に触れておらず、コミットも作成していない。

## 検査と後続への申し送り

検査の範囲と見込みの時間は実行前に報告した。コマンドは rtk を経由し、通常の構成を使う。

| コマンド | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差分は grammar.md の導入だけ |
| `cargo test -p benitoite --lib` | 最終の Rust ツリーで成功。1,155 passed、既存の ignored 21、72.02 秒。最初の実行も同じ件数で成功 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 最終実行は成功。四ターゲット、19 passed、7.59 秒。最初の失敗と照合文字列の修正は上記のとおり |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| 35 語の照合と Markdown の空白・相対リンクの検査（Python） | 成功。lexer・01-01・02-03・common-mistakes の一覧が一致。新規作業記録もリンクと空白の検査に含める |

補助のリンク検査は、最初にコード内の `](...)` をリンクとして誤認したため、コードブロックとインラインコードを除いて再実行した。文書のリンクの修正を要する問題はなかった。

上記の検査の後に Rust と入力は変更していない。

scripts/check.sh（dry-run を含む）と gc-stress の構成は依頼に従い実行していない。共通の関門 K7 はオーケストレータが最後に担当する。段末の検査と G1 の完了、return の一般の改行規則・診断・24 行の移行は A4 の担当である。D の属性と B の try の処置を受理する作業では、今回明記した未受理の説明を受理後の仕様に合わせ、Skill の生成元と生成物も同じ作業で更新する。日本語訳との最終の対応は M8 へ引き継ぐ。

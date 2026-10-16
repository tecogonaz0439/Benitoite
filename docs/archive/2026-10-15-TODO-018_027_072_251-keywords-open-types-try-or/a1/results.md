# A1 の作業結果

## 目的と変更範囲

2026-10-15、plan.md の A1「die の字句と名前の拒否」を実装した。開始時の HEAD は `63a2704596ee0cc39fe519d1f8f578f6fc545e83`、作業ツリーは clean であった。既存の 34 語を保ち、die 一語だけを予約した。単独の die と try の処置はまだ受理しない。

以下のパスは `crates/benitoite/src/` 以下である。

| ファイル | 変更 |
|---|---|
| `syntax/token.rs`、`syntax/lexer.rs` | KwDie と小文字の綴り die を追加 |
| `syntax/newline.rs`、`syntax/lambda_bounds.rs` | キーワードと物理行の分類へ追加。continues_after へは追加しない |
| `syntax/parser/text.rs`、`decls.rs`、`exprs.rs`、`types.rs` | 表示と keyword の綴り、宣言・式・型の入口を更新 |
| `syntax/parser/exprs.rs`、`types.rs`、`items.rs`、`patterns_ext.rs`、`effects.rs` | 識別子かどうかを先に判定する名前の入口から、共通の E0216 へ接続（R21） |
| `syntax/lexer/tests.rs`、`syntax/newline.rs`、`syntax/parser/mod.rs` | 既存の表へ予約語・近い綴り・非予約語、改行、診断の位置と案内の対照を追加 |

改造ディレクトリでは本記録、README.md の入口、decisions.md の R21・R22 を追加した。現行設計書・生成物の語の更新は A3、return の改行は A4 の担当である。formal と docs/todo は変更していない。コミットは作成していない。

## KwTry の全使用箇所の確認

開始時と実装後の `git grep -n KwTry -- crates/benitoite` はともに 14 件である。行番号は開始時のものを示す。

| 箇所 | KwDie の扱い |
|---|---|
| `syntax/token.rs:53` | KwDie を追加 |
| `syntax/lexer.rs:785` | die の綴りだけを予約 |
| `syntax/lexer/tests.rs:933` | 既存の予約語の表へ追加。各語に x を足した識別子の対照も維持 |
| `syntax/newline.rs:161` | is_keyword へ追加 |
| `syntax/newline.rs:224` | continues_after へは追加しない。KwReturn の変更はしない |
| `syntax/lambda_bounds.rs:224` | 通常の字句として扱い、ブロックや lambda の開始にはしない |
| `syntax/parser/decls.rs:138` | 宣言として不適切な開始字句の分類へ追加 |
| `syntax/parser/types.rs:58` | die は名前の入口へ渡し、E0216 を報告 |
| `syntax/parser/exprs.rs:297` | 式の不適切な開始字句の分類へ追加し、E0201 を報告 |
| `syntax/parser/text.rs:46`、`:124` | 表示と keyword の綴りを追加 |
| `syntax/parser/exprs.rs:80`、`:246` | return/try の脱出・専用入口は維持。die の受理を加えない |
| `syntax/parser/effects.rs:427` | try の脱出検査を維持。die の受理を加えない |

加えて parser 内の LowerIdent/UpperIdent の判定と formatter 内の TokenKind の使用を調べた。名前の先読みの補足は R21 に記す。formatter は AST を使い、独立したキーワード一覧は持たないため本体の変更は不要であった。網羅的な match はコンパイルでも確認した。

## test-audit の作成時の関門

1. 主となる公開境界は lex、resolve_newlines、parse である。lex は die だけの予約、resolve_newlines は die の次行を続けない規則、parse は名前の位置での E0216 と未受理の式の E0201 を守る。別の境界を使う理由は、字句の分類だけでは名前の先読みの接続と診断の位置を確認できないためである。
2. 想定する退行は、近い綴りや大文字も予約すること、KwDie を continues_after に入れること、ラベルなどの先読みで共通の名前の拒否を通り過ぎること、有効な fn の呼び出しを他言語風の構文として拒否することである。
3. 既存の予約語・非予約語、改行、束縛、式の形、診断の位置と修正案の表を拡張した。新しいテスト関数や重複した準備は追加していない。既存の表には die がなく、今回の予約と接続漏れを捕まえなかった。
4. 本番の公開範囲・フラグ・引数・テスト専用の差し込み口は増やしていない。新しいケースは本物の字句解析と公開の parse を使う。

字句の追加後、接続を補う前に `bind [..die] <- xs` が E0201 となり、新しい E0216 の期待で失敗することを確認した。with の入口の補足前にも `with die = acquire() do` が E0246 となる失敗を確認した。接続後は同じ期待で成功した。最初の検査では、新たに加えた fn のラムダ引数の正のケースを、lambda の形に未対応の既存の shape 補助へ渡して失敗した。このケースを、診断のないことを確かめる既存の公開 parse の正の表へ移し、入力の検査を保った。

途中の検査では @die に E0216 と E0801 が重複する失敗も確認した。予約語の診断の後で属性を構築せず、その行から回復するように直し、E0216 一件の期待を維持した。

既存 assert の削除、期待値の緩和、skip/ignore 化、件数や時間制限の変更はない。テストを削除していない。Rust の本番のコードは追加 38 行・削除 16 行（差し引き 22 行増）、テストは追加 204 行・削除 1 行（差し引き 203 行増）である。テストの削除一行は既存の正の表を複数行へ展開したもので、元の全ケースを保っている。

## 診断の対応

以下の旧診断は開始時の構文解析の分類であり、名前解決や型検査の成否とは区別する。E0216 の主文は `` `die` is a keyword and cannot be used as a name ``、主位置の文は `keyword used as a name`、help は `choose another name` とする。主位置は die の三バイト、副位置・notes・修正の編集はなしである。既存の診断表自体は変えていない。

| 入力の役割 | 旧 → 新 | 元の誤りの検査の維持先 |
|---|---|---|
| 変数、関数、引数、ラベル、フィールド、リストの残り、with の束縛名 | 構文として受理 → E0216 | 既存の非予約語の受理と die の拒否を parser の表で対照 |
| import の別名・末尾、裸の小文字の型名 | E0201 → E0216 | 他の不適切な名前・型の検査はそのまま維持 |
| 小文字の値のドット後 | E0203 → E0216 | p.name/xs.map(f) の E0203、位置・pipe/field の案内を維持 |
| 属性名 | E0801 → E0216 | 未知の属性の既存テストは維持。die は予約語として一度報告 |
| die 単独・die(message)・try result or die・try result or die(message) | 名前または通常の呼び出しとして解析 → E0201 | try の既存の成功/失敗の入力は変更なし。新しい四行で未受理を確認 |

E0201 の四行の主文は ``expected an expression, found `die` ``、主位置の文は ``unexpected `die` ``、主位置は die、副位置・notes・help はなしである。未受理の or die を勧めない。新しい行ではコード・主文・主位置とその文・副位置・notes・help の数と改名の文・編集なしを確認する。終了状態は run/check ともに既存の静的検査の失敗として 2 である。P2 の記録の終了状態 1 は現行の仕様・実装と食い違うため、R22 に訂正を記した。

## 検査と後続への申し送り

検査の範囲は実行前に設計者へ報告した。コマンドは rtk を経由し、表には内側のコマンドを記す。通常の構成を使い、時間制限・種・件数は上書きしていない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib syntax::` | 最終実行は成功。105 passed、2.91 秒。途中の接続漏れなどの失敗と修正は上記のとおり |
| `cargo test -p benitoite --lib` | 成功。1,155 passed、既存の ignored 21、71.93 秒。診断の主文・主位置の文の厳密な比較も含む最終の Rust ツリー |
| `cargo test -p benitoite --test golden --test fmt_command` | 成功。2 ターゲット、17 passed、54.46 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功。追加文書も no-index の空白検査でエラー出力なし（追加差分による終了状態 1） |
| CLI の手動確認（Python、一時ディレクトリは実行後に削除） | 五入力 × run/check の 10 実行で、JSON の診断コード・標準出力なし・終了状態 2 を確認。入力は局所名・ラベル・大文字/小文字のドット後・未受理の処置 |
| 改造ディレクトリの変更文書の相対リンク確認 | 成功 |

scripts/check.sh（dry-run を含む）と gc-stress 構成は依頼に従い実行していない。共通の関門 K7 の実行はオーケストレータが担当する。formal は変更していないので lake build/check-formal の対象はない。診断表・構文の章を変えていないため gen_skill の再生成は不要である。

計画の補足は R21 の名前の入口の接続と R22 の終了状態の記録の訂正であり、新しい構文・診断番号・公開のシグネチャ変更は加えていない。A2 は formatter の契約の確認、A3 は 35 語の文書と生成物、A4 は return の一般の改行規則を引き継ぐ。die の本番の処置の受理は B11 まで行わない。後続の静的診断の対応表では P2 の終了状態 1 の誤記を引き継がず、現行仕様の 2 とする。

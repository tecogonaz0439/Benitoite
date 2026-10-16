# A4 return の改行規則の作業記録

## 目的と変更範囲

R13 の回答 B に従い、普通の `return` の直後の物理改行を、括弧内や次行の継続字句より優先して文末にした。値は同じ物理行で書き始める。書き始めた後の演算子・括弧・呼び出しの引数・`then` による継続と、短いラムダの一物理行の条件を維持した。

| ファイル | 変更 |
|---|---|
| `src/syntax/newline.rs` | `KwReturn` を `continues_after` から外し、直後の改行を優先して NEWLINE にする。キーワードの分類は維持。既存の表を拡張 |
| `src/syntax/parser/exprs.rs` | `parse_return` の直後が NEWLINE の場合だけ、改行の E0201 と return の補足位置・help を作り、次行を消費せず失敗を返す |
| `src/diag/codes.rs` | E0201 に `return_start` の補足ラベルと `return_value_line` の help を追加 |
| `src/syntax/parser/mod.rs` | 公開 parser の入口で拒否・診断・回復を確認。既存の優先順位の表に有効な継続を追加 |
| `tests/fmt_command.rs` | 既存の正の表に四種類の有効な継続の整形・再解析・冪等性、負の表に旧形の拒否・終了状態 2・書き換えないことを追加 |
| `tools/bench/wit-transfer/` の下表の6ファイル | 24箇所を `return if …` へ移行。空白以外の内容が旧入力と一致することを照合 |
| 現行設計書 01-01・01-02・02-03・02-10・06-03・07-04 | 改行・値の開始行・診断・整形時の拒否・形式化の対象外を反映 |
| `docs/reference/benitoite.md`、Skill の `SKILL.md`・`common-mistakes.md` | 同じ行での書き始めと、その後の通常の複数行の規則を英語で案内 |
| `src/cli/tools/skill/generate.rs` と生成物 | 英語の文法の導入を更新し、gen_skill で grammar.md・diagnostics.md を再生成 |
| このディレクトリ | 調査時点の候補・P1 のハッシュとの差・移行と診断・検査の記録 |

`src/` と `tests/` は `crates/benitoite/` 以下を指す。公開の型とシグネチャ、Lean、01-12 の規則は変えていない。07-04 には物理行の字句・構文検査だけを独立した対象外の行として加え、型付き表層の return と escape への脱糖を対象外へ移していない。

## 調査と24箇所の移行

開始時の HEAD は `af9d5820fc37846e1a89ce98ca2a9135d251b3e8`、作業ツリーは clean だった。P1 の一覧と HEAD の全追跡ファイルを照合した。候補と各入力の SHA-256、P1 の役割、保持・移行の理由は [return-inputs-before.json](return-inputs-before.json) に記す。P1 以降の25ファイルの差は A1〜A3 の語・診断・検査・文書の変更であり、今回の24箇所の入力は変わっていなかった。

`.bnt`・`.formatted`・Markdown 全文と、通常/raw/byte の Rust 文字列を調べた。Rust 文字列の復号には既存の `tools/named-arguments-migrate/extract.py` を使い、言語らしさのフィルタを外した。`return` 直後の改行・行末コメントを含む28候補は、下表の24箇所と、既存の newline の検査1件・formatter の負の検査1件・01-08 のコメント1件・WAT の return 1件だった。reference・archive・todo・過去の測定・syntax-measure の固定入力は除いた。UTF-8 の負の入力 `lexical/invalid_utf8.bnt` は文字列の復号対象にしなかった。

| `tools/bench/wit-transfer/` 以下 | 旧 return の行 | 数 | 修正 |
|---|---|---:|---|
| `large-bytes-adapter.bnt` | 12, 16 | 2 | 次行の if を return と同じ行へ |
| `large-bytes-typed.bnt` | 16, 20 | 2 | 同上 |
| `large-bytes.bnt` | 14, 18 | 2 | 同上 |
| `nested.bnt` | 12, 16 | 2 | 同上 |
| `numbers.bnt` | 46, 50, 54, 58, 62, 66, 70, 74, 78, 82, 86, 90, 94, 98 | 14 | 同上 |
| `primitives.bnt` | 21, 25 | 2 | 同上 |
| 合計 | | 24 | 戻り値・uses・仕事量を維持 |

ホスト内の `return\n`・`return\r`、format/concat・置換の周辺も検索した。`tasks/io/output_tests.rs` の既存の置換は return の前に改行を足し、値の `()` を同じ行に残すので変更していない。調査は任意の生成器の出力を完全に解析した証明ではなく、全ターゲット検査と併せて確認する。裸の try の入力は移行していない。

## test-audit の作成時の関門

1. 主な公開境界は既存の lex → resolve_newlines → parse である。改行の残り方は newline の既存表、診断と回復は parser、整形とファイルの保存は既存の fmt のプロセスの表で確かめる。
2. 捕まえる退行は、次行の `+`・`|>` や括弧が return の改行を消すこと、LF/CRLF・コメント・空行で規則が変わること、E0201 の位置と案内の欠落、別の構文の誤りへの案内の誤付与、有効な継続を整形が壊すことである。
3. 既存の newline と優先順位と fmt の表を拡張した。parser の新しい表は、それまで存在しなかった同じ行での値の開始と診断の契約を守る。fmt の表は実際のファイルを保存する経路・終了状態・再整形を確認する。各層で同じ診断の全文を重ねて比較していない。
4. 本番の公開範囲・引数・フラグ・テスト専用の差し込み口は増やしていない。

実装前に parser の新しい検査を実行し、旧 parser が `return` の次行の値を受理して診断を返さないため失敗することを確認した。実装後の最初の実行では、テスト側が回復後の最初のノードを `Stmt::Expr(Expr::Error)` と誤認して失敗した。実際の `Stmt::Error` を厳密に要求し、その後に次行の値が独立した文として残ることを確認する形へ直した。

既存の `continuation_and_new_statement_boundaries` の `"return\n  x"` は、同じ表の NEWLINE を一つ要求する側へ移した。これはR13で変える契約の期待値の更新であり、比較を緩めていない。formatter/verify の `before.replace("return call", "return\n call")` の拒否を含む既存の assert は保持した。新しい ignore・対象外理由・時間制限を追加していない。

## 診断の対応

| 入力・観測 | 旧 | 新 | 元の検査の維持先・理由 |
|---|---|---|---|
| 値が次行にある普通の return（短いラムダなどの別の制限に違反しないもの） | 改行を除去し、値を return の式として受理 | E0201、主文 `expected an expression, found a newline`、主ラベル `unexpected a newline`、主位置は最初の改行、補足位置は return、補足ラベル `return starts here`。help は ``start the return value on the same physical line as `return` ``、編集なし。静的検査・fmt は終了状態2 | newline の旧入力1件を文末側へ移動。parser の表は位置・全文・help件数・編集なし・次行の回復を厳密に比較。fmt の既存表は拒否・保存・終了状態を確認 |
| formatter/verify の `return` 直後を改行した短いラムダの負の入力 | E0254、主文 ``a lambda without `end lambda` must fit on one physical line``。主位置は lambda（2行目7〜13列）、副位置は次行の call（3行目2〜6列）、副ラベル `the lambda continues on another physical line`。help は ``start the body on the next line and add `end lambda` to use a multiline body``、編集なし、終了状態2 | E0201、主文・ラベル・helpは上の行と同じ。主位置は2行目末の改行、副位置は同じ行の return。終了状態2を維持 | `rejects_changed_lambda_boundaries` の入力と assert は変更していない。引数内の改行・見出し内の改行も引き続き拒否し、parser の既存表でも値を始めた後の短いラムダの E0254 を維持 |
| 値を書き始めた後のオペランド不足、引数の誤り | 既存の構文診断 | 既存の構文診断。return_value_line は付けない | parser の対照入力と既存の構文・短いラムダの検査を維持 |
| `return` の直後の改行の後がブロックの終端 | E0201 が終端の字句を指す | E0201 が改行を指し、上の補足・helpを付ける | 値が必須という既存の誤りを引き続き報告し、移行方法を示す |

E0201 の通常の主文の型板・番号・診断種別・終了状態は変えていない。golden の期待値の一括再生成は行っていない。

## 検査と後続への申し送り

検査するコマンドと段末の見込みの時間を実行前に報告した。以下は同じ Rust・入力のツリーでの結果であり、コマンドは rtk を経由した。

| コマンド・照合 | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差は grammar.md の導入と diagnostics.md の E0201 だけ |
| `cargo test -p benitoite --lib` | 成功。1,156 passed、既存の ignored 21、71.86秒。syntax と formatter の単体テストを含む |
| `cargo test -p benitoite --test golden --test fmt_command --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 成功。6ターゲット、36 passed、63.68秒 |
| `cargo test --workspace --all-targets` | 成功。2,509 passed、既存の ignored 44、46 suites、382.66秒 |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | 成功。2,523 passed、既存の ignored 44、46 suites、501.71秒。既定構成との差14件は既存の heap-verify 固有の検査 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check`、`git diff --check` | 成功 |
| WIT の manifest とゲストの存在・SHA-256 | 12ゲストのソース・Wasm、24ファイルが一致。再生成を要しなかった |
| 24箇所の移行の前後を空白を除いて照合 | 全6ファイルで一致 |
| `target/debug/benitoite check tools/bench/wit-transfer/<各ファイル>.bnt` | 6ファイルすべて診断なし、終了状態0。実行・性能測定はしていない |
| CLI の JSON の診断の対照確認 | 次行の値と値なしは E0201・所定の help・終了状態2。`return 1 +` の後のオペランド不足は既存の E0201、helpなし、終了状態2 |
| 既存の formatter の負の入力の CLI の診断を対照 | ソースの旧経路を照合し、手元の保存済み release バイナリと今回の debug でも上表の E0254 → E0201・位置・全文・help・終了状態2を確認。保存済みバイナリの HEAD を今回の基準として扱ってはいない |
| 変更した Markdown の相対リンク | 成功。コードブロックとインラインコードを除いて照合 |

Rust の本番部分は追加26行・削除5行（差し引き21行）、テスト部分は追加77行・削除1行（差し引き76行）である。テストの削除1行は既存の newline の入力を同じ表の文末側へ移した分であり、入力や assert の削除ではない。

上記の検査後に Rust と検査入力は変更していない。最後に作業記録を追記し、文書のリンク・空白・JSON と `git diff --check` を再確認した。

計画からの設計上のずれはない。共通の関門 K7 と段末の check.sh・gc-stress は依頼に従ってオーケストレータへ引き継ぐ。formal/ に変更がないため lake build/check-formal は実行しない。G1 の所定のレビューはこの差分と記録を使って行う。

B6 は普通の return と処置を字句段階で区別せず、今回の一般の改行規則を使う。E0908・CHANGELOG・0.0.6 の登録は M6/M7、英語版との最終の訳の照合は M8 が担当する。docs/todo/・コミット・版の更新は行っていない。

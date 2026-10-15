# Z1 R20 の同じ物理行の終端への変更

## 変更の内容

設計者の R20 の決定に従い、見出しの行に本体を始めたラムダは、その一文の直後の同じ物理行に対応する `end lambda` がある場合だけ終端付きとした。`end` と `lambda` の両字句が同じ行に収まることを確かめる。次の行以降の終端は内側の短い形を閉じない。見出しの次の行から本体を始める終端付きの形、直接の入れ子の括弧の規則、型検査と脱糖の規則は維持する。

整形器の R19 の空行保持処理を取り除いた。短いラムダの直後に外側の終端が続く場合も、通常の閉じ字句前の空行除去を適用する。終端種別と本体の境界、字句、コメントの比較、再解析、冪等性の検査を維持した。

E0213 と E0201 の主文・コードは維持し、短い候補の境界に残った `end lambda` を誤りとして報告する場合にだけ、終端を同じ物理行へ置くか、本体を見出しの次の行へ移す案内を加えた。外側を正しく閉じる終端には診断を加えない。

## 旧入力の照合と書き直しの一覧

開始時の HEAD の現行入力から、ラムダを含む 698 入力を抽出した。内訳は Rust の文字列 435、Markdown のコードブロック 85、`.bnt` 160、`.formatted` 5、Python のファイル 13 である。Rust の通常文字列のエスケープと raw 文字列、文書の text・bnt 等のコードブロックは既存の `study/count-calls.py` の抽出を使った。Python はファイル全体のエスケープされた改行も戻して候補を照合した。

公開の字句解析を通し、開始時の `lambda_bounds` と R20 の境界走査の分類を比較した。翌行の終端を取らなくなる既存候補は次の 4 件だけであった。位置は変更前のソースの行である。

| ファイル・テスト | 変更前 | 書き直し・新しい検査 |
|---|---|---|
| `src/syntax/parser/mod.rs:1120`、`short_lambdas_preserve_boundaries_and_explicit_endings` | `lambda(x) return x` の次の行に `end lambda` | 本体を見出しの次の行へ移す。終端付きであることの既存の assert は維持する |
| 同 `:1121`、同テスト | `lambda(x) return x // tail` の次の行に `end lambda` | 本体を見出しの次の行へ移す。末尾コメントと終端付きの検査を維持する |
| `src/cli/tools/formatter/verify/tests.rs:65`、`preserves_lambda_layouts_across_whitespace_changes` | `bind f <- lambda(x) return x // body` の次の行に `end lambda` | 本体を見出しの次の行へ移す。LF から CRLF への変換と空白変更を受理する既存の検査を維持する |
| `src/syntax/parser/mod.rs:1185`、`short_lambda_diagnostics_keep_syntax_errors_and_outer_recovery` | 内側の短いラムダの束縛の次の行に外側の終端。R8 の下では E0214 | R20 では正しい入力である。元の入力を成功する境界の表へ移した。`short_lambdas_leave_outer_endings_independent_of_spacing` で空行・CRLF・末尾コメント・コメント行を表の形で変え、外側 Explicit、内側 Omitted、それぞれの文数と内側の戻り値の式を検査する。診断表の行は旧二行形式の拒否の厳密な期待 `[E0213, E0201]` に置き換える |

現行の `.bnt`、testdata、examples、tools の入力、文書のコード例には、これ以外に旧二行形式の移行が必要な候補はなかった。複数行の本体は L1a・L2 で既に移行されていた。生成断片・format・連結・replace の完成した入力は抽出だけでは保証できないため、ライブラリ、ランダム生成、ゴールデン、脱糖の既存検査を併用する。

`reference/`、`docs/archive/`、docs/todo、過去の測定記録、`tools/syntax-measure/variants/` の比較案は編集対象にしなかった。照合に使った一時的な Rust の例は削除した。

## R19 のテストの期待を変える理由

| テスト | R19 の期待 | R20 の期待と維持する契約 |
|---|---|---|
| `formatter::tests::preserves_short_lambdas_and_their_boundaries` の空行のケース | 外側の終端の前に空行を一つ残す | 空行を全て除く正規形と厳密に比較する。空行のない入力の行も加え、同じ正規形・再解析・冪等性を検査する。コメントのケースの期待は維持する |
| `formatter::verify::tests::rejects_changed_lambda_boundaries` の最後のケース | 空行の除去を拒否する | このケースを `accepts_removed_blank_lines_before_outer_lambda_ending` として独立させ、受理を要求する assert に変える。短い本体・見出しの改行、終端の追加、コメントの変更を拒否する既存の assert は維持する |

これは R20 による契約の変更に合わせた期待の変更であり、期待値の緩和ではない。既存の assert の削除、新しい ignore、ゴールデン期待値の一括更新は行っていない。

## テストの作成時の関門

1. 解析器の公開入口で、同じ物理行の終端と外側の終端の対応、空行に依存しない本体、旧二行形式の移行ヘルプを守る。整形と検証の公開入口では空行を除く正規形と本体・終端の保持を守る。
2. 翌行の終端を内側が取る退行、R19 の例外を残す退行、移行ヘルプを出さない退行で失敗する。
3. 既存の終端不足の期待は R8 に依存していた。仕様変更に合わせて成功時の AST と拒否時の診断を別々に確かめる。整形の正規形と整形後の検証には各層に固有の危険があるため、それぞれの公開入口で検査を維持する。
4. 本番にテスト専用の公開範囲、フラグ、注入の入口は加えていない。

実装を直す前に、解析器と整形器の新しい期待が、それぞれ E0214 と空行保持の差分によって失敗することを確かめた。R20 を接続した後は、対象のラムダのテストが成功した。

## 文書と計画への反映

`decisions.md` に設計者の決定 R20 を追加し、R8 と R19 に変更の注記を付けた。`design.md` と `plan.md` の L2・L4、01-02、02-03、06-03、07-04、英語リファレンスと Skill の生成元を更新した。生成された grammar と diagnostics は `gen_skill` で作り直した。L1a・L3 の過去の記録には、R20 が後続の規則であることを注記した。

R20 は依頼された計画の変更であり、それ以外の計画からのずれはない。07-04 の既存の「対象外」の行に同じ物理行の終端判定を明記した。型付き表層の入力と脱糖を変えず、formal/ に変更はない。

## 検査の結果

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,128 成功、既存の ignore 21 件。最終実行 62 秒 |
| `cargo test -p benitoite --test fmt_command --test golden --test spec_examples --test skill_docs --test reference_examples --test skill_examples --test random_programs --test desugar_export` | 8 スイート・44 成功、既存の ignore 1 件。128 秒 |
| `cargo clippy --all-targets` | 成功、警告なし |
| `cargo fmt --check`、`git diff --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。grammar と diagnostics が変更され、その他の生成物には差分なし |

依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は実行していない。formal/ の変更はなく、lake build は実行していない。

Rust の本番のコードは差し引き 5 行増、テストは差し引き 64 行増である。

## 後の作業への申し送り

L4 の残る文書上の推奨と例、後続の名前付き引数の移行は R20 を使う。見出しの行に本体を書く場合は終端まで一行にまとめ、複数行の本体は次の行から始める。外側の終端のために空行を保つ処理や例は加えない。日本語訳の更新は既存プランの N35a に従う。

オーケストレータが取り込み前に scripts/check.sh と gc-stress の構成の検査を行う。コミット、docs/todo の変更、改造ディレクトリの保管は行っていない。

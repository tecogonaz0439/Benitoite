# G6 レビューの報告（B11〜B13）

対象: `git diff efe81fb1 HEAD`（HEAD = ee1b8243、B13 の取り込み）。git の読み取りだけで行い、cargo・lake・check.sh は実行していない。

## 結論

重大 0 件、中 1 件、軽 5 件。G4 で合意した規則、設計者の決定（裸の try の意味の固定、die は予約語で Process.Exit を足す、R18 の報告順、R70 の test runner の表示、G5a 指摘 7 の `or return die` の help）は、実装・検査・文書に反映されている。テストが弱められた箇所は見つからなかった。テストの期待値を書き換えた箇所は、受理への切り替え（R72）と R70 による厳密な新しい期待に限られる。中の 1 件は、利用者向けの文書が R63（Process の別名は E0339 で拒否する）と食い違っている点である。

## 確かめた観点と結果

| 観点 | 結果 |
|---|---|
| 本番の受理 | `parser/mod.rs` の `allow_die`・`accepts_die` と `test_support::parse_with_die` を除き、`try_action_ahead` は `or return` と `or die` を同じように扱う。テスト専用の本番フラグは残っていない |
| 公開入口からの Result/Option の成功と失敗 | golden に `todo250-die-success`（Result.Ok・Option.Some）、`-result`（複数行の説明付きで失敗）、`-option`（説明なしの None）を追加。`cli_process` は文章と JSON の両方で、原因・説明・位置・状態 1・報告一回を確かめる |
| 任意の戻り値 | golden の `value(...) -> Integer` と `main -> Unit` で確認。lib の `die_types_and_dictionaries_do_not_constrain_the_enclosing_return` も残っている |
| Show の有無 | Option は Show なしで成功。Result[_, Failure] は E0705（golden `todo250-die-no-show`）。E0706 は lib の検査で確認 |
| uses と import の案内 | `typeck/effects/tests.rs` の `die_production_loading_keeps_imports_and_effect_help_explicit` が、本物の pipeline で import なし・import あり・import なしで uses だけ（E0332）・別名（E0339）を確かめる。golden `todo250-die-no-uses` も同じ |
| 説明の括弧・複数行 | parser の表（同じ物理行の `(`、括弧内の改行、CRLF、コメント、E0254・E0258・E0259）と golden の複数行の説明 |
| ガード・lazy の中の die | `check_escape` を `try` の字句で呼ぶため、処置によらず E0218 になる。die を直接書いた検査の行はない（軽 5） |
| 報告の順と一回性（R18） | `cli_process::die_reports_precede_real_release_and_flush_failures` が、ファイルサイズ制限と閉じたソケットを使った本物の失敗で、die → R0401（解放の逆順）×2 → R0201 の順と状態 1 を、二つの IO 方式・文章/JSON・run/test で確かめる |
| test runner（R70） | `report.rs` は `die_failure` のある場合だけ EXITED の行を省く。JSON の `reason`・`message`・`exitCode`・`notes` は保つ。統合検査で、次のテストの成功と捕捉出力の重複のなさを確認 |
| `or return die`（G5a 指摘 7） | E0258 に `return_value` と `die_action` の二つの help。主位置は die。parser の表に二行を追加 |
| 性能 | prelude の import は増えていない。E0501 の補足は誤りのときだけ通り、`#[cold]` が付いている。Process.bnt はドキュメントのコメントだけを差し替え、行数は変わらない |
| 実装の規約 | 本番のコードに `unwrap`・添字・`#[allow]` の追加はない。文言は `diag::codes` の表に置いた。`format!("{name}.Exit")` は型板に埋める値であり、英語の文ではない |
| docs/todo へのリンク | 追加した行に docs/todo へのリンクも `reference/` へのリンクもない |
| Skill の生成物 | grammar.md・diagnostics.md・stdlib/IO.Process.md・stdlib/index.md は、generate.rs・codes.rs・Process.bnt の変更と合っている（B11・B13 の記録では skill_docs が通過） |

## 指摘

### 【中】1. 利用者向けの文書が「Process の別名を使える」と案内しており、E0339（R63）と食い違う

- 場所: `docs/reference/benitoite.md:659`、`crates/benitoite/skill/references/idioms.md:65`
- 問題: どちらにも「They add `Process.Exit`; import `Benitoite.Unofficial.IO.Process` to name it in `uses`, **or use its existing alias**.」とある。しかし組み込みのエフェクトを宣言するモジュールは `as` で改名できない（E0339。decisions R63 で現行の規則を維持すると決めた）。B11 の検査も、`import ... as P` と `uses P.Exit` の組み合わせが E0339 になることを確かめている。このため、LLM がこの文を読んで別名を書くと拒否される。Skill の idioms.md は手書きの文書であり、書き手（LLM）への手本として読まれる。
- 修正案: 「or use its existing alias」を消す。代わりに「The module cannot be renamed with `as` (E0339), so write `uses Process.Exit`.」のように、改名できないことを書く。日本語訳は M8 で揃える。

### 【軽】2. E0501 の die の補足が別名の場合に `uses P.Exit` を案内し、E0339 の修正案と食い違いうる

- 場所: `crates/benitoite/src/typeck/solve.rs:1765`（`add_die_effect_help`）
- 問題: import に別名があると、`import.alias` から `"{name}.Exit"` を組み立てる。別名は E0339 で拒否されるので、この分岐が役に立つことはない。`import ... as P` を書いて `uses` を書いていない場合は E0339 と E0501 が両方出るはずで（実行しての確認はしていない）、E0501 は `uses P.Exit` を、E0339 は `P.` を `Process.` に直すことを案内することになり、二つの案内が矛盾する。計画 B11 の「別名で import していればその別名を使う」は、R63 より前の想定である。
- 修正案: 別名の分岐を除いて、いつも `Process.Exit` を案内する（`die_uses` の引数を固定にするか、型板を `Process.Exit` に固定する）。02-05 の「取り込んだ名前による uses を示す」も「`uses Process.Exit` を示す」に揃える。

### 【軽】3. 01-spec（01-12）に処理系の実装と検査の接続状況が入っている

- 場所: `docs/design/01-spec/01-12-core-calculus.md:750`（「die のモデル」）
- 問題: 「本番の parser と corpus 10 の交換器へ接続済みである」は、処理系と検査の道具の状況である。AGENTS.md は 01-spec に実装方式に依存する記述を入れないと定めている。同じ内容は 07-04「01-12 との対応」の表に書いてある。
- 修正案: 01-12 からこの一文を除き、07-04 の表の記述に任せる。

### 【軽】4. parser の検査で、同じ本番の解析を二回呼んでいる

- 場所: `crates/benitoite/src/syntax/parser/effects.rs:1248`（`parse_die`）、`:1290`（`parse_source`）
- 問題: B11 で `parse_die` は本番の `parse` を呼ぶようになり、`test_support::parse_source` と同じ解析になった。それでも `die_actions_share_pratt_boundaries_in_production` は、同じソースを `parse_die` と `parse_source` で二回解析して、両方とも診断がないことを確かめている。`parse_die` という名前も、先行の入口が残っているように読める。
- 修正案: `parse_source` に一本化し、二つ目の assert を除く。あるいは補助の名前を `parse_user` などに改める（test-audit の重複の整理）。

### 【軽】5. ガードと lazy に直接書いた `or die` の拒否を確かめる行がない

- 場所: `crates/benitoite/src/syntax/parser/effects.rs:1090` 付近の表
- 問題: G4 で、ガードと lazy の直接の本体の die は拒否すると合意した。実装は `try` の字句で `check_escape` を呼ぶので、処置によらず E0218 になる。ただし表にあるのは `lazy try r or return end lazy` とガードの `or return` だけで、die の行がない。将来、処置の種類で分岐する変更が入ると、die だけが漏れても気付けない。
- 修正案: 同じ表に `lazy try r or die end lazy` と `match x with case n if try r or die -> n end match` を加え、どちらも E0218 を期待する。

### 【軽】6. 明示した `uses` を持つラムダの中の die（E0502）には、die の案内が付かない

- 場所: `crates/benitoite/src/typeck/solve.rs:1752`（`d.code == Some(DiagCode::E0501)` の条件）
- 問題: 補足を加えるのは E0501 だけである。`lambda() -> Integer uses Console.Write try r or die end lambda` のように、uses を明示したラムダで Process.Exit が足りない場合は、通常の E0502 だけになり、import の案内がない。01-09 は「die による E0501 は uses と必要な import を案内する」とだけ定めているので、仕様との食い違いではない。
- 修正案: 今回は対応しなくてよい。直すなら E0502 にも同じ補足を加え、01-09 の文を「E0501・E0502」に広げる。

## 補足（指摘にしないもの）

- リファレンスの try の節は「Use an explicit action in new code」の直後に、裸の try を使う従来の例（parsePort）を置いている。計画どおり、既存例の移行は M1〜M5 で行う前提として扱った。
- B11 と B12 の記録にある check-formal の manifest の追加（R73）は、旧入力が完全に一致することを確かめてから五入力と七定義だけを加えたものである。対象内の件数と対象外の理由は変わっていない。

## 対応

Z8（2026-10-16）。計画と現行の規則の整合、および検査の整理の理由は decisions.md の R74 に記録した。

| 指摘 | 対応 |
|---|---|
| 1 | 英語リファレンスと手書きの Skill の idioms.md から別名の案内を除き、`as` は E0339 になるため `uses Process.Exit` と書くことを明記した。日本語訳は予定どおり M8 に残す |
| 2 | `add_die_effect_help` の別名から名前を作る分岐を除き、診断表の `die_uses` を `Process.Exit` に固定した。02-05 も揃え、gen_skill で diagnostics.md を作り直した。公開 pipeline では別名 import は E0339 で止まり、uses がなくても E0501 は同時に出なかったため、その場合を既存の表に加えた |
| 3 | 01-12「die のモデル」から本番 parser と交換器への接続状況を除いた。接続状況は07-04の既存の表に任せる |
| 4 | `parse_die` と二回目の解析を除き、既存の `user` → `parse_source` に一本化した。字句診断・構文診断・AST・説明・境界の検査を維持した。除いた assert は同じ入力を二度解析した結果への重複分だけであり、期待値の緩和はない |
| 5 | E0218 の既存の表に、ガードと lazy に直接書いた `or die` の二行を加えた |
| 6 | 対応しない。01-09 が die 専用の案内を定めるのは E0501 だけであり、E0502 への拡張は今回の範囲に含めない |

本番コードは3行減、テストコードは13行減（追加した表の三行と重複の整理を合わせた差分）。golden の期待値は変更していない。

Z8 の検査結果（通常の既定の構成）:

| 検査 | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差分は diagnostics.md の `die_uses` の一行だけ |
| `cargo test -p benitoite --lib` | 1,194 成功、既存の ignored 21、失敗0 |
| `cargo test -p benitoite --test golden --test reference_examples --test skill_docs --test skill_examples --test spec_examples` | 5バイナリ、計21成功、失敗0 |
| `cargo clippy --all-targets` | 成功、指摘なし |
| `cargo fmt --check` | 成功 |
| `git diff --check` | 成功 |

調査中には、別名 import と uses 不足で E0339・E0501 が同時に出るという仮定を検査し、実際には E0339 だけであることを確認した。最終の表はこの実態を厳密に期待し、既存の行の期待値と assert は維持している。formal/ は変更していないため lake build は実行していない。

B14 の段末検査（`check.sh --only rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,formal` と check-formal）は、オーケストレータが Z8 の前の HEAD で実行済みであり、結果は b14 の記録を参照する。Z8 では check.sh と gc-stress の構成の検査を実行しない。

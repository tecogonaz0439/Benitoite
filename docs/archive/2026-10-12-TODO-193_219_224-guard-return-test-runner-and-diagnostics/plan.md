# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` は最後に一度だけ行う。

各作業の内容は `study.md` の部と節で示す（「C 部 2 節」は「調査 C」の部の 2 節）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。調査で使った再現の入力は、scratchpad の `orch9/a/`・`orch9/b/`・`orch9/c/`（`/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/orch9/`）にある。読んでよいが、そこに書かない。

## どの作業にも共通する決まり

- 診断の文言は `diag::codes` の表（型板）と、各モジュールの `text` にまとめる（AGENTS.md「文言」）。新しい note・help の鍵を足すときは、既存の型板の書き方と文の調子に揃える。
- 診断の文言・コード・修正案を変えたら、同じ作業で次を行う。
  - 影響するゴールデン（`crates/benitoite/testdata/**/*.diag.json` など）を `BENITOITE_BLESS=1 cargo test -p benitoite --test golden` で作り直し、差分が意図したものだけであることを確かめて報告に書く（作り直した件数と、意図した変更の要約）。
  - `cargo run -p benitoite --example gen_skill` で Skill の生成物を作り直す。
  - 設計書（`docs/design/`）の該当の節を、改造の後の実装に合わせて直す。`###` 以下の見出しは変えない。決定の直後の「理由: 〜。」は 1〜3 文。
  - 利用者から見える変更は `CHANGELOG.md` の Unreleased の節に英語で書く（既存の節の形に揃える。0.0.2 以前の節は変えない）。
- テストを加えるときは、スキル `test-audit` の作成時の関門を通す。退行のテストは、直す前のコード（または一時的に壊したコード）で落ちることを確かめて報告に書く。新しい振る舞いは、ゴールデン（文章と JSON の両方の形が固定される）か単体テストのどちらか適したほうで一度だけ確かめ、同じことを二重に確かめない。新しいゴールデンの名前に作業の ID を付けない。
- 凍結した型やシグネチャ（`docs/archive/2026-10-09-implement-first-release/10-interfaces/`）を変えてよいのは、Q3 の `AssertTable` の欄と `evaluate` に枠を渡す形だけである。ほかに変える必要が生じたら、作業を止めて報告する（非公開の補助の関数・型・欄は自由に加えてよい）。
- `formal/` は変えない。

どの作業の完了の条件にも、最後に次を含める（以下では省く）。

```sh
cargo test -p benitoite --test golden
cargo test -p benitoite --test skill_docs
cargo test -p benitoite --lib help_tests   # 修正案を当てて検査し直すテスト
cargo run -q -p benitoite --example gen_skill && git status --porcelain -- crates/benitoite/skill   # 作り直した結果を作業の変更に含める
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
cargo fmt --all --check
```

## 作業 W1: ガードと `lazy` の中のプレースホルダの引数の `return`（TODO-193、Q1・R1）

処理系の振る舞い（どの入力を受け付け、どれを拒否するか）は変えない。A 部 3 節の選択肢 B の「最小」の案を行う。

1. 言語仕様:
   - 01-05 のガードの規則（A 部 1 節が示す 189 行付近の「内側のラムダの中を除き」）を、「内側の `lambda … end lambda` の本体の中を除き、`return` と `try` を書けない。プレースホルダを含む呼び出しの呼ぶ関数と引数の中にも書けない」の趣旨にし、理由を 1〜2 文添える。
   - 01-02 のプレースホルダの節（338 行付近の「`return` と `try` は展開後のラムダから抜け」の箇条）に、ガードと `lazy` の本体の中ではこれらの式の中に `return` と `try` を書けないこと（01-05 を参照）を加える。01-02「`return`」の `lazy` の箇条（209 行付近）も同じ趣旨に揃える。
   - 01-12 の 711 行付近の「内側のラムダの中を除き」に、構文の制限としてプレースホルダの引数を除くことを書く。
   - 同じ規則を書いた 01-09・02-03・02-05 の箇所（事前点検の補足が挙げる）も同じ趣旨に揃える。
   - 07-04「01-12 との対応」の表の該当の行に、ガードと `lazy` の中のプレースホルダの呼び出しの `return`・`try` には形式化の型付けが型を付けるが、構文で拒否する（形式化のほうが広い）ことを書き足す。表がすでに「より広い」と記している行の書き方に揃える。
2. 診断（E0218）: `diag/codes.rs` の E0218 の助言を「`{keyword}` is allowed inside a `lambda ... end lambda` written there」の趣旨にし、説明の文に「Arguments of a call with `_` placeholders are not exempt.」の趣旨を加える。02-10 の表に E0218 の文の写しがあれば合わせる。今の単体テスト（`patterns_ext.rs` と `effects.rs` の "inside a lambda" を見るもの）は新しい文で落ちるので、比べる文字列を新しい文に合わせて直す。
3. テスト: ガードのテスト（`syntax/parser/patterns_ext.rs` の E0218 のテスト）に `n if f(return 1, _)(n)` と `n if f(try g(), _)(n)` の形、`lazy` のテスト（`syntax/parser/effects.rs` の E0218 のテスト）に `lazy f(return 1, _) end lazy` の形を加え、E0218 になることを確かめる。仕様の文に対応させて `// spec: 01-05 <見出し>` の印を付ける。
4. CHANGELOG に、E0218 の助言の変更を一行書く。

完了の条件:

```sh
cargo test -p benitoite --lib syntax
cargo test --test spec_examples
```

## 作業 W2: 表記の中立化、剛な型の表示、補間の E0405（TODO-224 の 1・2、Q4、R2・R3）

1. 表記の中立化（R2、C 部 1 節の案 A）: `base` の下に新しいモジュール（名前は作業で決めてよい。例 `base/literal.rs`）を作り、`quoted`・`escape_into` と `Show.show` の形の記号の表（`text` という子のモジュールの定数）を `runtime/assert.rs` から移す。`quoted_within` は `assert.rs` に残して新しいモジュールの `escape_into` を呼ぶ。`typeck/consts/key.rs`・`cli/tools/test_runner/report.rs` など、記号と `quoted` を引く箇所を新しいモジュールへ向ける。`typeck/consts/key.rs` が引く `ELLIPSIS`・`UNKNOWN_CONSTRUCTOR` も共有の表へ移す。出力は変えない（ゴールデンが変わらないことで確かめる）。`builtins/funcs/traits.rs` の写しの統一は、大きさの見積もりの直しを伴うので、無理なくできるときだけ行い、行ったかを報告する。新しいモジュールの `//!` に役割（型検査とテストの実行器が共有する値の表記）と設計書の節を書く。
2. 剛な型の表示（R3、C 部 2 節の案 A）: 本体の型の表示を `Body` の側の一つの関数（と、一つの診断の中で名前の表を共有する複数の型の版）に集め、中身を今の `Solver::show_named` と同じく `diagnostic_type` → `name_rigid_types` → `Ty::show` にする。`typeck/effects/special.rs`・`typeck/pattern_ext.rs`・`typeck/traits/solve.rs`・`typeck/generate.rs`（E0438）の型の表示をこれに置き換え、出力用の `finalize` の既定値（`Unit`）を診断に持ち込まない（未確定の型は `_`）。`check_rigid_bound`（`typeck/traits/mod.rs`）の型の名前も同じ付け方にし、剛な型のときの help を、外側の関数でなく操作の宣言に制約を書く案内にする（文言の鍵を足してよい）。C 部 2 節の「今の出力」の r1・r2b・r4・r6・r11 の形を、`typeck/effects/tests.rs` などの単体テストにする（外側の型パラメータの名前が出ず、`store.T` の形が出ること、未確定の型が `Unit` でないこと）。
3. 補間の E0405（Q4、C 部 2 節の付随の所見の r9）: 型パラメータの値を文字列の補間に書いたとき（`ReasonKind::Interp`）、`check_parameter_bound`（`typeck/traits/mod.rs`）が E0405「`ordered` cannot be applied」でなく E0422 を出すようにする。help は事前点検の補足のとおり、型パラメータの種類（`Show` の制約なし・あり・剛な型）で分ける。普通の型パラメータと剛な型の両方を単体テストで確かめる。
4. 設計書: 02-05「誤りの報告と検査の継続」の剛な型の名前の段落を、本体の型の表示すべてに当てはまる書き方にする。補間の誤りの扱いを書いた節（02-05 か 02-10）を合わせる。02-07 か 02-11 などに表記の場所を書いた記述があれば合わせる。

完了の条件:

```sh
cargo test -p benitoite --lib typeck
cargo test -p benitoite --lib runtime::assert
cargo test -p benitoite --lib cli::
cargo test -p benitoite --test test_command
```

## 作業 W3: 宣言の流れ込みの報告の位置（TODO-224 の 4、Q4、R5）

C 部 4 節の案 A と案 D を行う。

1. 案 A: `typeck/solve.rs` の `pair_failure` の移し替え（失敗を `declared` の記録の理由の位置へ移す処理）を、失敗した制約が変数を定める側（束縛の文・分岐のパターンの制約 `ReasonKind::Pattern` で、記録のある変数がパターンの側にあるとき）に限る。どちらの側がパターンかは、制約の向きの決まりで知る（R5。`ReasonKind::Pattern` の制約は、どれも `expected` が値の側、`found` がパターンの側である。凍結した `Reason` に印は足さない）。d13（`g(s)` の引数の誤りを `return s` の位置に報告する）が、失敗した位置（`g(s)` の引数）で報告されるようにする。
2. 案 D: 宣言の流れ込みが失敗し、流れ込む側の型が別の宣言の流れ込みで決まったものであるときは、その場で報告せず、`late` とは別の非公開の欄に積んで後へ回し（`poison` しない）、`late` の報告の後に、その変数が誤りの型になっていれば捨て、なっていなければ報告する。d18（型注釈と `return` の二つの宣言の流れ込み）で、本当の誤り（`bind s <- n` と注釈の食い違い）が注釈の側で報告され、`return s` の報告が出ないようにする。
3. テスト: `typeck/tests.rs` に d13・d7・d9・d16・d18 の形（`orch9/c/d*.bnt`）を加え、報告の位置・コード・件数を確かめる。前の改造で足した `declaration_flow_preserves_inner_failure_positions_and_repairs` と FE403 の既存のテストが通り続けることを確かめる。E0401 の位置を `return` へ移した形を固定したゴールデン（`the returned value must match` を含む `.diag.json`）があれば、変化が意図したものかを確かめて報告する。
4. 設計書: 02-05「誤りの報告と検査の継続」の、手順 1 で決めた変数との食い違いを宣言の理由で報告する段落に、移すのは変数を定める制約の失敗に限ることと、宣言どうしの食い違いの扱いを書く。

完了の条件:

```sh
cargo test -p benitoite --lib typeck
```

## 作業 W4（行わない）

設計者の指示で行わない（`decisions.md` の Q5）。波括弧のレコード・`new`・`=` の案内は、docs/todo の TODO-225 で扱う。

## 作業 W5: `Assert` の報告の構成子の名前（TODO-219 の後半、Q3・R6）

B 部 2 節の (e) を行う。

1. e1: `runtime/assert.rs` の `render_value` が、型が型パラメータを含むときに値全体を形だけで書くのをやめ、型の具体的な部分（`Option[T]` の `Option`、`List[T]` のリスト、具体的なフィールドの型）は型に従って書き、型パラメータの位置の値だけを、下の e2・e3 で決めた型か形で書く。
2. e2: `Assert` の確認が失敗したとき、`render_value` の前に、VM の呼び出しの枠（`vm/dispatch/handlers.rs` の `assert_check` と `state.stop_info` の枠の集め方）を外へ辿り、各枠の呼び出しの位置で型検査が記録した型引数（`TypeckOutput::type_args`）で、比べる値の型の型パラメータを置き換える。表は `AssertTable::build` で、関数の呼び出しの位置 → 型引数の表として作る（凍結した `AssertTable` に欄を足す。Q3 で了承済み）。`evaluate` に枠を渡す形を加える（同じく了承済み。既存の `evaluate` を残して新しい関数を足すか、引数を足すかは作業で決める）。
3. e3: 枠から型が決まらないとき（型パラメータを持つ関数どうしの末尾呼び出しが二段以上続く場合、関数を値として渡した場合。末尾呼び出しでも、呼ばれた関数の枠の `call_site` には末尾呼び出しの命令が入るので、一段の末尾呼び出しは e2 で決まる）は、プログラムの中のその関数の全ての呼び出しの型引数の集まり（型引数が別の関数の型パラメータなら、その関数の集まりへ辿った閉包）から、値の形（タグ、引数の数、引数の形）に合う型を選ぶ。一つに決まるときだけ使う。
4. R6: どれでも決まらないときは、型が分からないことを読み取れる表示（例 `<constructor #0 of an unknown type>`）にする。W2 で `UNKNOWN_CONSTRUCTOR` を型検査と共有する表へ移すので、共有の定数は変えず、実行器だけが使う新しい定数を足す。
5. 設計書と文書: 02-11「テストの実行」と 06-04「結果の報告」に、型の復元の手順と、決まらないときの表示を書く（足す位置は事前点検の補足に従う）。06-04、言語リファレンス（`docs/reference/benitoite.md`）、Skill の手書きの文書（`crates/benitoite/skill/SKILL.md`）に、型パラメータを持つ補助の関数では型が決まらないことがあり、比べる値の型を具体的にすればよいことを書く。
6. テスト: `orch9/b/ctor.bnt`・`ctor_nontail.bnt` の形（引数のない構成子、引数のある構成子、レコード、`Option`、`List`、末尾呼び出し、2 段の補助の関数、ラムダ）を `testdata/` のテストのゴールデン（`benitoite test` の出力を固定するもの）か単体テストにし、名前で書かれることを確かめる。一つに決まらない形（同じ補助の関数を、同じタグと引数の数の構成子を持つ二つの型で使い、末尾呼び出しで枠が消える形）で、R6 の表示になることを確かめる。
7. CHANGELOG に一行。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::assert
cargo test -p benitoite --lib cli::
cargo test -p benitoite --test test_command
cargo test -p benitoite --lib vm
```

## 最後に行うこと（オーケストレータ）

- 全作業の後、`scripts/check.sh --dry-run` で選ばれる検査を確かめ、設計者に知らせてから一度だけ走らせる。
- 文言の多い変更なので、Skill の評価（LLM を呼ぶ）は行わない。行うなら設計者の了承を得る。
- docs/todo の TODO-193・224 を閉じ（TODO-224 の三つ目の点は TODO-225 に移したことを書く）、TODO-219 は並行の実行の部分だけを残す（構成子の表示の部分を閉じたことを書く）。

# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` は最後に一度だけ行う。

各作業の内容は `study.md` の部と節で示す（「A 部 2 節 (b)」は「調査 A」の部の 2 節の (b)）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。

## どの作業にも共通する決まり

- 診断の文言は `diag::codes` の表（型板）と、各モジュールの `text` にまとめる（AGENTS.md「文言」）。新しい note・help の鍵を足すときは、既存の型板の書き方と文の調子に揃える。
- 診断の文言・コード・修正案を変えたら、同じ作業で次を行う。
  - 影響するゴールデン（`crates/benitoite/testdata/**/*.diag.json` など）を `BENITOITE_BLESS=1 cargo test -p benitoite --test golden` で作り直し、差分が意図したものだけであることを確かめて報告に書く（作り直した件数と、意図した変更の要約）。
  - `cargo run -p benitoite --example gen_skill` で Skill の生成物を作り直す。
  - 設計書（`docs/design/`）の該当の節を、改造の後の実装に合わせて直す。`###` 以下の見出しは変えない。決定の直後の「理由: 〜。」は 1〜3 文。
  - 利用者から見える変更は `CHANGELOG.md` の Unreleased の節に英語で書く（既存の節の形に揃える。0.0.1 以前の節は変えない）。
- テストを加えるときは、スキル `test-audit` の作成時の関門を通す。退行のテストは、直す前のコード（または一時的に壊したコード）で落ちることを確かめて報告に書く。新しい振る舞いは、ゴールデン（文章と JSON の両方の形が固定される）か単体テストのどちらか適したほうで一度だけ確かめ、同じことを二重に確かめない。
- 凍結した型やシグネチャ（`docs/archive/2026-10-09-implement-first-release/10-interfaces/`）を変えてよいのは、Q8 の `FaultThread::Main` だけである。ほかに変える必要が生じたら、作業を止めて報告する（非公開の補助の関数・型・欄は自由に加えてよい）。

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

## 作業 W1: 名前解決の補助（TODO-179、Q2・Q3・R3・R4）

`src/resolve/` を中心に変える。

1. モジュールの名前を書いた形で示す（Q3、A 部 2 節 (b)、B 部 1 節）: E0303・E0330 の見出し・ラベル・修正案の文の `{module}` を、参照に書いた段の綴り（`String`・`Benitoite.String`・別名 `S`・`Console`）にする。E0330 の `public` を付ける修正案だけは本来の名前で示す（型板の引数を分ける）。
2. 旧名と別名の表（Q2・R3、A 部 2 節 (b) の推奨 1〜3）: `resolve` の新しいモジュールに、0.0.0 の旧名（CHANGELOG.md の「Incompatible changes from 0.0.0」から拾う）と他言語の別名を一つの表で置く。E0303 では近い名前より先に引き、当たれば置き換え付きの help を一つ示す。旧名は「0.0.1 で改名した」旨を示す。モジュールの旧名（`Int`→`Integer`、`Bool`→`Boolean`、`Char`→`Character`、`IoError`→`IOError`）は E0301・E0302 で同じ表から示し、`Int.abs` のように改名したモジュールの関数は改名後の完全な名前を示す（`Int.mod`→`Integer.floorModulo` は同じ関数の改名なので、普通の行として扱う）。表の行の正しい名前が今の標準ライブラリにあることを確かめる単体テストを置く。
3. 名前の一覧（Q2）: 表にも近い名前にも当たらないとき、そのモジュール（型）で引ける名前の一覧を注記で示す。並びは決まった順（名前の順）にする。
4. 途中の段の足りない import（R4、A 部 2 節 (b) の推奨 4）: `IO.Console.write` を import なしで書いたときの E0303 に、E0332 と同じ足りない import の修正案を出す。import を足すだけでは誤りが消えない（`IO.Console.write` は import の後も E0303 になる）ので、置き換えには import の挿入と、参照の `IO.Console` を `Console` に書き換える編集の両方を含める。
5. 設計書: 02-04「誤りと修正案」（示すモジュールの名前、旧名と別名の表、名前の一覧、途中の段の import）、02-10「修正案」の表。

ゴールデンを足す: 旧名（`String.charCount` など）、別名（`Map.insert`）、一覧（当たらない名前）、モジュールの旧名（`Int.abs`）、別名 `S` で書いた参照。

完了の条件:

```sh
cargo test -p benitoite --lib resolve
cargo test -p benitoite --lib modules
```

## 作業 W2: prelude を隠した注記と、取り込みの修正案（TODO-170・179、Q1・Q4・R5）

1. TODO-170（Q1、A 部 3 節の案 A）: 名前解決の E0303・E0330 で、最初の段が隠した参照のとき（`prelude_shadowed` に記録する条件と同じ）に、隠したことの注記と宣言の位置の補助のラベル、`Benitoite.` を前に挿入する置き換え付きの help（隠された prelude の束縛がその名前を持つとき）を加える。型検査の E0401 で期待と実際の型に利用者が宣言した prelude と同じ名前の型が含まれるとき、E0410（期待と実際の型を持たない）では書いた型が利用者が宣言した prelude と同じ名前の型に解決したとき、注記と `Benitoite.X` で書けることの help（置き換えなし）を加える。02-04「名前の引き方」の該当の項を実装した範囲に合わせて書き直し、02-05・02-10 に足す。E0339 と E0321 の変更は 02-04「import の宣言の誤り」「モジュールの探し方」に書く。
2. E0339 の修正案（Q4、C 部 7 節）: `as` を消す編集に、同じファイルの別名への参照を本来の名前に書き換える編集を含める。C 部 7 節の推奨 2 のとおり、E0339 を報告した import は別名と本来の名前の両方で束縛を作り、E0332 の修正案と重ならないようにする（重なると両方を当てて同じ import が二つになり E0324 になる）。E0339 は本体の参照を解決する前に作られるので、参照の位置が揃うよう、診断の組み立てをモジュールを辿り終えた後へ回す。編集を当てた結果が検査を通ることをテストで確かめる。E0321 の修正案（別名を残す）は変えない。
3. E0321 の最後の段（R5、A 部 2 節 (c)）: 最後の段が標準ライブラリのモジュールの最後の段と大文字小文字を区別せずに一致するものを、距離の候補より先に示す。一つなら置き換え付き。候補の案内は note でなく help に揃える。

ゴールデンを足す: `record Task` で隠した後の E0303、`Result` を隠した E0401、E0339 の参照の書き換え、`import Benitoite.Http`。

完了の条件:

```sh
cargo test -p benitoite --lib resolve
cargo test -p benitoite --lib modules
cargo test -p benitoite --lib typeck
```

## 作業 W3: 型検査の位置と修正案（TODO-179、R1・R2・R6・R7・R18・R19）

1. E0416（R1・R2、A 部 1 節・2 節 (a)）: 理由 `FnBody` の位置を本体の最後の式文にする補助を置き、E0438 も同じ位置へ移す。同じ本体に E0416 を報告したときは E0438 を出さず、戻り値の型を書いたラムダでは `LambdaReturn` の E0401 を重ねない。戻り値の型が Unit でない本体では `return ` を挿入する修正案を最初に示し `discard` を出さない。戻り値の型を書いていないラムダでは両方を置き換え付きで示す。凍結した `ReasonKind` は変えず、`Body` に別の表を持たせる。本体が `bind` で始まるときに構文として誤った置き換え（`bind _ <- bind y <- …`）が出ないことも確かめる。
2. `return s`（R18、C 部 4 節）: FE403 の仕組みを手順 2 の食い違いの全般に広げ、`return s` の位置で期待と実際を正しい向きに示す。
3. E0441・E0442（R19、C 部 5 節）: プレースホルダの呼び出しが作る関数であることを示す専用の注記と、呼び出しを指す補助の位置を加える。ラムダの場合も注記を分ける。
4. E0304（R6、A 部 2 節 (c)）: E0304 は名前解決の段（`resolve/lookup.rs`）が出す。レコードを値・呼び出しの位置に書いたとき、フィールドの名前を使った構築の形を help で示す（置き換えなし）。レコードの E0303 で `new`・`create`・`make`・`of`・`init` を書いたときも同じ help を示す（W1 の表の補助と重ならないよう、先に引く順を決めて報告に書く）。
5. E0201（R7、A 部 2 節 (c)）: 文の終わりで直前が名前の `[` に出会ったとき、呼び出しが型引数を取らないことを help で示す。`名前[…](` の形なら `[…]` を消す置き換えを付ける。
6. 設計書: 02-05（本体の最後の式文の位置、`return` の修正案、E0438 を重ねないこと、手順 2 の食い違いの位置、プレースホルダの注記）、02-04「誤りと修正案」（E0304）、02-03「他の言語の書き方への診断」（E0201）、02-10「修正案」の表。

ゴールデンを足す: 最後の式の `return` 忘れ、`-> Unit` の最後の `x = 5`、`return s`、E0304 の構築、E0201 の型引数。

完了の条件:

```sh
cargo test -p benitoite --lib typeck
cargo test -p benitoite --lib syntax
cargo test -p benitoite --lib resolve
```

## 作業 W4: 型の表示と注記（TODO-179、Q6・R8・R10・R11・R12）

1. SECF1 の E0401（Q6、C 部 8 節）: 剛な型を操作の型パラメータの名前で示し、脱出の注記と節を指す補助の位置を加える。外側の関数が型パラメータを持つ場合に誤った名前を示さないことをゴールデンかテストで確かめる。
2. `IO.All` の表示（R8、B 部 2 節 (a)）: 型を表示するとき、`IO.All` の 10 個のエフェクトをすべて含む集合を `IO.All` とまとめる。02-05 の「`IO.All` を書いたかを覚えておく」の記述を実装に合わせる。
3. E0412・E0209（R10、B 部 2 節 (d)）: `pattern_arity` の構成子を書いたパスで示す。`uses_then_bracket` の E0209 の位置を型全体にし、括弧で囲む置き換えを付ける。02-03 の該当の記述を直す。
4. 定数の鍵の文（R11、B 部 3 節）: `key_text` を `Show.show` の形にし（文字列は引用符付き、改行などは逃がす）、`bound_failure` の文字列を `typeck` の `text` に移す。
5. E0507 の注記 `state`（R12、B 部 4 節）: 操作を宣言したモジュールが Prelude か Stdlib のときだけ付ける。利用者の操作に付かないことを確かめるテストを置く。
6. E0211（R9）: `syntax/parser/foreign.rs` の edits を付けない経路に、理由（記号が演算子を置けない位置にあり、置き換えても誤りが残る）をコメントで書く。

完了の条件:

```sh
cargo test -p benitoite --lib typeck
cargo test -p benitoite --lib syntax
cargo test -p benitoite --lib types
```

## 作業 W5: 描画と報告（TODO-179、Q5・Q8・R13〜R17）

1. 制御文字（Q5、C 部 6 節）: 文章の形の描画の一か所で、見出し・注記・help・ラベル・段の名前に埋めた文字列の端末の制御文字と双方向の書式の制御文字を逃がす。既に逃がしている経路と二重に逃がさないよう、逃がす場所を一つにまとめる。JSON は逃がさない。標準ライブラリの誤りを不具合の報告にする複数行の注記は行で分けてから逃がす。`main` が返す `Result.Error` の文字列は対象外。02-10「文章の形式」に書く。
2. BOM（R13 (d)、B 部 5 節 (d)）: BOM 付きのファイルの抜粋と修正案の行で BOM を除き、印の桁を合わせる。既存のゴールデン `testdata/lexical/bom_at_start` は JSON の形だけを固定しているので、文章の形も固定する。
3. 表示の小さな点（R13 (a)〜(c)、B 部 5 節）。
4. 処理系の不具合の報告（Q8・R16、C 部 2 節）: `FaultThread::Main` を加え、主スレッドの panic（`fmt`・`test`・`skill` の本体、CLI の外側の境界）をそう呼ぶ。panic の説明は一度だけ書き、スレッドの注記は panic のときだけ書く。不具合が二つ起きたときは、後の報告が先の不具合の写し（作業用のスレッドや書き出し用のスレッドの panic を VM が `Stop::Internal` として写したもの）なら一件にまとめ、別の不具合なら先の報告を残して後の報告を加える。`FaultThread::Main` に付随する定数 `text::THREAD_MAIN` も加えてよい。02-09「panic 境界」と 02-10「処理系の不具合と処理系の制限の報告」を直す。
5. 実行時エラーの primary（R17、C 部 3 節）: タスクの最初の枠に呼び出した位置を持たせない。02-08 の規則に書き足す。`TaskGroup.spawn(group, ask)` の形で primary が親の起動を指さないことを確かめる。
6. コード生成の制限（R14・R15、C 部 1 節）: L0101〜L0104 を定義ごとに一つにまとめ、L 系の診断だけで終わるときも件数の行を書く。`case_length` の前提を doc に書き、外れたら `InternalError` を返す。02-07 に上限の数を明記する。重複の退行のテストは、大きな入力が要るなら単体の段のテスト（コード生成に小さな上限を渡せる口があればそれ）で書き、10 秒を超えるテストを足さない。

完了の条件:

```sh
cargo test -p benitoite --lib diag
cargo test -p benitoite --lib runtime::report
cargo test -p benitoite --lib bytecode
cargo test -p benitoite --lib vm::
cargo test -p benitoite --lib resolve
cargo test -p benitoite --lib base::source
cargo test -p benitoite --lib cli::
cargo test -p benitoite --test cli_process
cargo test -p benitoite --test test_command
```

## 作業 W6: 上限の定数とフォーマッタのテスト（TODO-209・221、Q7・R20〜R22）

1. TODO-209（Q7、D 部 1 節）: 非公開の組み込みの関数を加え、`MAX_STRING_BYTES` を返させる。`Regex.bnt` の `1073741824` をその呼び出しに置き換える。03-08「Regex」に一文足す。
2. TODO-221 (a)（R20）: `tests/golden/formatting.rs` で、整形の結果をもう一度整形して変わらないことを確かめる。構文の誤りで整形できない入力は飛ばす。07-03 と 06-03「テスト」に書き足す。
3. TODO-221 (b)（R21）: `///` の後の行の空の行の印を消し、`roles/tests.rs` の期待と 06-03「空の行」を直す。
4. TODO-221 (c)（R22）: 直前の分岐や本体に文がないときだけ、`else`・`with` の前のコメントを内側の段に置く。ゴールデン（`blank_lines_comments.formatted`）を直し、06-03「コメント」に一文足す。

完了の条件:

```sh
cargo test -p benitoite --lib cli::tools::formatter
cargo test -p benitoite --lib builtins
cargo test -p benitoite --test fmt_command
```

## 最後に行うこと（オーケストレータ）

- 全作業の後、`scripts/check.sh --dry-run` で選ばれる検査を確かめ、設計者に知らせてから一度だけ走らせる。
- 文言の多い変更なので、Skill の評価（LLM を呼ぶ）は行わない。行うなら設計者の了承を得る。

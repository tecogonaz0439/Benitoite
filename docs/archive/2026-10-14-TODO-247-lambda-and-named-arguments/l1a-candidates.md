# L1a 候補と移行の確認表

注記（Z1、2026-10-14）: 以下の「翌行の終端は変更不要」は R8 時点の記録であり、R20 で改めた。旧二行形式の照合と書き直しは [z1-implementation.md](z1-implementation.md) に記録する。

## 集計と確認方法

R8 の 61 候補を再現した。表の行番号は移行前の HEAD の位置である。61 は一致行から抽出した候補の数であり、ラムダの変更箇所の数ではない。

| 区分 | 件数 |
|---|---:|
| R8 の候補 | 61 |
| 変更した候補 | 55 |
| 変更不要 | 6 |
| 保留 | 0 |
| 55 候補に含まれるラムダの開始箇所 | 58 |
| 同じ行の先行する終端に隠れた開始箇所 | 3 |
| replace で複数行になる生成入力の開始箇所 | 2 |
| 改行を追加した開始箇所の合計 | 63 |
| 入力を変更したファイル | 17 |

抽出のコマンドは R8 と同じである。通常の Rust 文字列の `\n`・`\r` を改行に戻し、見出しの後に return・bind・shadow・resume・呼び出しを含み、その行に end lambda がない候補を読む。

```sh
rg --json 'lambda\([^
]*\)[^
]*' crates/benitoite tools fuzz -g '*.rs' -g '*.bnt' -g '!results/**'
```

各入力の header/body の境界を手で確認した。通常文字列では `\n`、raw 文字列と .bnt では実際の改行を、見出しの最後の字句と本体の最初の字句の間に追加した。生成断片では開く側の文字列を直した。終端・文・引数順・型・値は保持した。

追加の読み取り照合では、現行の .bnt、Rust の通常・raw 文字列、文書の text のコードブロックからラムダを含む 649 入力を抽出した。式・文の断片は一時的な関数へ置き、公開の lexer → newline → parser を使った。構文比較の資料も参照用に含めたが、変更していない。AST から span とノード番号だけを除いて比較し、649 入力すべてで同じ木になった。型注釈だけの断片、動的な format・連結・replace の完成形はこの比較だけでは保証できないため、下の確認と既存の実行・生成器の検査を併用した。

読み取り照合で得た 1,134 個のラムダ AST について、見出しの最後の字句、本体の最初・最後の字句、終端の物理行を調べた。同じ行に始めて複数行へ続く本体または離れた終端を持つものは移行前 56 個、移行後 0 個であった。残る七つの開始箇所（三つの深さ生成断片、io_modes の handler を差し込む format 一つ、IO の ending を差し込む format 一つ、replace の二つ）は個別に完成形を確認した。L2 の受理規則自体はこの作業では未接続であり、ここでの確認は R8 の行境界の準備と既存の意味の維持である。

## R8 の 61 候補

| 番号 | 移行前の位置 | 判断 | 本体・生成入力の確認 |
|---|---|---|---|
| 1 | `crates/benitoite/src/typeck/pattern_ext.rs:797` | 変更 | 開く断片を `lambda()\n bind _ <- ` にする。外側の値に入る内側のラムダと改行した終端を保持 |
| 2 | `crates/benitoite/src/ir/check.rs:1723` | 不要 | Rust の IR を作る関数の呼び出し。Benitoite のラムダではない |
| 3 | `crates/benitoite/src/ir/check.rs:2575` | 不要 | Rust の IR を作る関数の呼び出し。Benitoite のラムダではない |
| 4 | `crates/benitoite/examples/stack_probe/support.rs:153` | 変更 | 開く断片を `lambda()\n bind _ <- ` にする。外側の値に入る内側のラムダと改行した終端を保持 |
| 5 | `crates/benitoite/tests/runtime_builtins.rs:227` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 6 | `crates/benitoite/tests/runtime_builtins.rs:232` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 7 | `crates/benitoite/tests/runtime_builtins.rs:237` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 8 | `crates/benitoite/tests/runtime_builtins.rs:247` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 9 | `crates/benitoite/tests/runtime_builtins.rs:252` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 10 | `crates/benitoite/tests/runtime_builtins.rs:257` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 11 | `crates/benitoite/tests/interrupt_process.rs:257` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 12 | `crates/benitoite/src/syntax/parser/mod.rs:955` | 不要 | 終端は同じ行の `end \t lambda`。空白の違いだけであり変更不要 |
| 13 | `crates/benitoite/src/syntax/parser/mod.rs:2078` | 不要 | repeat の完成形は全ラムダが同じ行で終端まで閉じる |
| 14 | `crates/benitoite/src/syntax/parser/mod.rs:2083` | 不要 | repeat の完成形は全ラムダが同じ行で終端まで閉じる |
| 15 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:80` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 16 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:113` | 変更 | 同じ一致行の外側と内側の二つの見出しを改行。複数文と入れ子の範囲を保持 |
| 17 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:283` | 変更 | 同じ一致行の外側と内側の二つの見出しを改行。複数文と入れ子の範囲を保持 |
| 18 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:693` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 19 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:933` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 20 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:939` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 21 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:945` | 変更 | 同じ一致行の外側と内側の二つの見出しを改行。複数文と入れ子の範囲を保持 |
| 22 | `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs:1058` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 23 | `crates/benitoite/tests/io_modes.rs:442` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 24 | `crates/benitoite/tests/io_modes.rs:470` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 25 | `crates/benitoite/tests/io_modes.rs:499` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 26 | `crates/benitoite/src/syntax/parser/effects.rs:676` | 変更 | match の複数行ブロック。見出しの後を改行し、元の E0509 と文脈の assert を保持 |
| 27 | `crates/benitoite/tests/random_programs/generator.rs:435` | 不要 | 外側の見出しの戻り値は function 型。本体の return は既に次の行から始まる |
| 28 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:169` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 29 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:280` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 30 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:639` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 31 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:642` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 32 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:724` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 33 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:959` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 34 | `crates/benitoite/src/vm/dispatch/tasks/io/tests.rs:962` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 35 | `crates/benitoite/src/vm/dispatch/tasks/io/output_tests.rs:437` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |
| 36 | `tools/bench/wit-transfer/large-bytes-typed.bnt:15` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 37 | `tools/bench/wit-transfer/large-bytes-typed.bnt:18` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 38 | `tools/bench/wit-transfer/large-bytes-adapter.bnt:11` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 39 | `tools/bench/wit-transfer/large-bytes-adapter.bnt:14` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 40 | `tools/bench/wit-transfer/large-bytes.bnt:13` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 41 | `tools/bench/wit-transfer/large-bytes.bnt:16` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 42 | `crates/benitoite/src/pipeline.rs:796` | 変更 | 開く断片を `lambda()\n bind _ <- ` にする。外側の値に入る内側のラムダと改行した終端を保持 |
| 43 | `tools/bench/wit-transfer/numbers.bnt:45` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 44 | `tools/bench/wit-transfer/numbers.bnt:48` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 45 | `tools/bench/wit-transfer/numbers.bnt:51` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 46 | `tools/bench/wit-transfer/numbers.bnt:54` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 47 | `tools/bench/wit-transfer/numbers.bnt:57` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 48 | `tools/bench/wit-transfer/numbers.bnt:60` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 49 | `tools/bench/wit-transfer/numbers.bnt:63` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 50 | `tools/bench/wit-transfer/numbers.bnt:66` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 51 | `tools/bench/wit-transfer/numbers.bnt:69` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 52 | `tools/bench/wit-transfer/numbers.bnt:72` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 53 | `tools/bench/wit-transfer/numbers.bnt:75` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 54 | `tools/bench/wit-transfer/numbers.bnt:78` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 55 | `tools/bench/wit-transfer/numbers.bnt:81` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 56 | `tools/bench/wit-transfer/numbers.bnt:84` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 57 | `tools/bench/wit-transfer/nested.bnt:11` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 58 | `tools/bench/wit-transfer/nested.bnt:14` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 59 | `tools/bench/wit-transfer/primitives.bnt:20` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 60 | `tools/bench/wit-transfer/primitives.bnt:23` | 変更 | return の式が次の行へ継続するため、return の前を改行 |
| 61 | `crates/benitoite/testdata/concurrency/c12-race-and-timeout.bnt:14` | 変更 | 複数文または複数行ブロック・差し込む文がある本体。先頭を改行 |

## 追加の五つの開始箇所

| 移行前の位置 | 見出しの識別 | 判断 |
|---|---|---|
| `src/vm/dispatch/tasks/tests/cancellation.rs:34` | Error(1) の終端の後の pause(10000) を呼ぶラムダ | 改行を追加。allOk の最初の失敗と取り消し範囲を保持 |
| 同 `:114` | return 1 の終端の後の pause(10000) を呼ぶラムダ | 改行を追加。二つ目の子を保持 |
| 同 `:1060` | 1 div 0 のラムダの後の pause(10000) を呼ぶラムダ | 改行を追加。全体停止と prior release failures の検査を保持 |
| `src/vm/dispatch/tasks/io/output_tests.rs:555` | writes を呼ぶラムダ | `replace(")) return", "))\n return")`で二文になる。見出しの後を改行し、既存の replace と assert を保持 |
| 同 `:556` | File.readText を呼ぶラムダ | 既存の replace で二文になる。見出しの後を改行し、既存の replace と assert を保持 |

上表の `src/` は `crates/benitoite/src/` を指す。通常文字列の物理行と、埋め込むスクリプトの改行を区別して確認した。

## 移行しない入力

| 範囲 | 確認結果 |
|---|---|
| 同じ行の単文直後に終端がある入力、直後の物理行の先頭に終端がある入力 | R8 でも明示の終端付きであり、変更不要 |
| crates の現行標準ライブラリ・Skill の手書き文書・生成物、現行設計書・英語リファレンス | 本体が既に次の行から始まるか、同じ行で終端まで閉じる。生成元に変更がないため gen_skill の再生成は不要 |
| random_programs の生成器・縮小器 | function 型を含む見出しの後に本体を改行している。型注釈の `return` を本体と誤認しない |
| fuzz の現行入力と生成箇所 | 対象となる同じ行から始まる複数行の旧ラムダはない |
| tools/syntax-measure の variants・template・selftest | 構文の比較案の独立した入力であり、現在の処理系への移行対象から除外 |
| reference/、docs/archive/、docs/todo/、最小実行版の文書 | 依頼とリポジトリの規約に従い編集しない |

# T28 テストの作成: 評価・IO・受け入れ

- 依存する作業: [T25](T25-golden-runner.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（ゴールデンテストのスクリプトが 50〜70 本）
- ブランチ: impl/T28-tests-eval

## 目的

評価意味論・基本型の演算・prelude の関数・IO・プログラムの入口について、`run` のゴールデンテストを `testdata/eval/`・`testdata/io/` に置く。あわせて、ロードマップの最小実行版の完了条件の各行に対応する受け入れテストを `testdata/acceptance/` に置き、`testdata/acceptance/INDEX.md` の対応表を埋める（07-03「受け入れ例と仕様の項目の対応」）。これらのテストは、差分テストと IO の方式のテストの対象にもなる（T25）。

## 読む設計書の節

- [評価意味論](../../2026-09-27-design-initial/01-spec/01-08-evaluation.md): 「正格評価」「評価順序」「関数の呼び出し」「末尾呼び出し」「プログラムの実行」「実行時エラーによる停止」「資源の不足」
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md): 全節
- [エフェクト](../../2026-09-27-design-initial/01-spec/01-07-effects.md): 「IO が起きる時期と順序」「IO の失敗」「外部から受け取る文字列」「プログラムの入口」「IO を行う組み込み関数」
- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md): 全節
- [コア計算と脱糖](../../2026-09-27-design-initial/01-spec/01-12-core-calculus.md): 「末尾呼び出しの保証」
- [診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md): 「実行時エラーと資源の不足の報告」
- [仮想機械](../../2026-09-27-design-initial/02-impl/02-08-vm.md): 「呼び出しの入れ子の上限」「実行時エラーの情報の記録」
- [ランタイム](../../2026-09-27-design-initial/02-impl/02-09-runtime.md): 「一つの操作で作る値の大きさの上限」「プログラムの実行の流れ」
- [ロードマップ](../../2026-09-27-design-initial/00-overview/00-03-roadmap.md): 最小実行版の「完了条件」
- [処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md): 「ゴールデンテスト」「受け入れ例と仕様の項目の対応」
- [組み込みの関数](../10-interfaces/10-10-builtins.md)
- [T25 ゴールデンテストの実行器](T25-golden-runner.md): 期待値のファイルの組と `.opts`

## 作るもの

- `crates/benitoite/testdata/eval/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/io/*.bnt` と期待値のファイル（`.args`・`.files/` を含む）
- `crates/benitoite/testdata/acceptance/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/acceptance/INDEX.md` のテストの名前の欄

処理系のソースは変えない。

## 手順の要点

- 書き方の決まりは [T26](T26-tests-front.md) の「手順の要点」と同じである。
- 実行時エラーのテストは、02-10「実行時エラーと資源の不足の報告」の呼び出しの履歴の内容（段の名前、呼び出した位置、末尾呼び出しで消えた段、prelude の補助の関数を示さないこと）を `.diag.json` の `trace` で確かめる。
- 実行の時間: 一本のテストが、デバッグビルドで数秒を超えないようにする。末尾呼び出しのテストの回数は、スタックを使い果たさないことが分かる程度（100 万回）にとどめる。
- 呼び出しの入れ子が深すぎるテストは、T25 の `.opts` ファイル（`max-call-stack=64KiB` など）で上限を小さくする。既定の 1 GiB の上限に達するまで再帰すると時間がかかるからである。資源の不足で止まるテストは差分テストの対象から外れる（ADR 0018）。
- 期待値の数値（`Float.toString` の表記、整数の除算の丸め）は、01-04 の規則から自分で導いて確かめる。処理系の出力を写すだけにしない。

### 置くテスト

| 区分 | 名前 | 確かめること |
|---|---|---|
| eval | `order_call_args` | 01-08 の `f(Console.println("a"), g(Console.println("b")))` は `a` の後に `b` を出力する |
| eval | `order_pipe` | `read() |> List.filter(nonEmpty)` の形で、左辺を先に評価する |
| eval | `order_binary_list_ctor` | 二項演算、リストリテラル、構成子の呼び出しの引数を左から評価する |
| eval | `short_circuit` | `&&`・`||` の右辺を評価しない場合に、右辺の IO が起きない |
| eval | `if_match_unselected` | 選ばれない分岐の IO が起きない |
| eval | `lambda_delays` | ラムダを作っても本体の IO が起きず、呼ぶたびに起きる（01-08「正格評価」の `later` の例） |
| eval | `placeholder_delays` | プレースホルダを含む呼び出しは、呼び出す関数と引数をラムダを呼ぶたびに評価する（01-08「評価順序」の表） |
| eval | `closure_capture` | ラムダが作ったときの局所の束縛の値を使う |
| eval | `tail_self` | 01-08 の `sumTo(1000000, 0)` がスタックを使い果たさない |
| eval | `tail_mutual` | `isEven(1000000)`・`isOdd` の相互再帰 |
| eval | `tail_lambda_and_value` | ラムダ、関数の値、構成子、組み込みの関数の末尾呼び出し（01-08「末尾呼び出し」の関数の種類） |
| eval | `tail_and_or` | `n != 0 && isEven(n - 1)` の右辺の末尾呼び出し |
| eval | `call_stack_limit` | 末尾でない再帰が上限を超えて R0901 で止まる。`.opts` で上限を小さくする。報告に呼び出しの枠の数 |
| eval | `div_by_zero_trace` | 02-10 の例（22 行目の `List.map` とラムダと `ratio`）。R0101、履歴の段と位置、末尾呼び出しの注記 |
| eval | `div_by_zero_tail` | ラムダの本体を `fn(x) { ratio(x, n) }` にすると、ラムダの段が履歴に現れない |
| eval | `trace_truncated` | 25 段の末尾でない再帰の中で止まり、内側 10 段と外側 10 段と省いた段の数が示される |
| eval | `int_overflow` | `+`・`-`・`*`・単項の `-`・`/`（−2^63 ÷ −1）・`Int.abs`・`Int.floorDiv` の溢れ（R0102）。一つのスクリプトに一つずつ |
| eval | `int_division` | `-7 / 2`、`-7 % 2`、`7 % -2`、`Int.floorDiv(-7, 2)`、`Int.mod(-7, 2)`、−2^63 `%` −1 が 0 |
| eval | `float_semantics` | 0 による除算が無限大と NaN、`0.0 == -0.0`、NaN の比較、`Float.isNaN` |
| eval | `float_to_string` | 01-04「型の変換」の表記（`1.0`、`0.001`、`123.45`、`1.0e+21`、`1.5e-7`、`-0.0`、`NaN`、`Infinity`、`-Infinity`、最短の桁） |
| eval | `float_round_floor` | `Float.floor`・`ceil`・`round` の 0 の符号と中間の値、`Float.truncate` の `None` |
| eval | `parse_functions` | `Int.parse` と `Float.parse` が受け付ける表記と受け付けない表記（`_`、`+`、空白、`NaN`）、`Float.parse("-1e-9999")` |
| eval | `char_functions` | `Char.toInt`・`fromInt`（サロゲートと範囲の外は `None`）・`toString`・`isAsciiDigit`・`isAsciiWhitespace` |
| eval | `string_positions` | `byteLength`・`byteSlice`（境界でない位置は `None`）・`charCount`・`charAt`・`charSlice`。ASCII でない文字を含む |
| eval | `string_functions` | `split`（`"a,,b"`、空の区切り、空の文字列）、`lines`（`"a\r\nb\n"`、`"a\n\nb"`）、`join`、`trim`、`replace`（空の `old`）、`repeat`（0 以下）、`chars`、`fromChars`、`contains`・`startsWith`・`endsWith`・`byteIndexOf` |
| eval | `string_compare` | `String` の辞書式の順序と、正規化しない `==`（NFC と NFD） |
| eval | `value_too_large` | `String.repeat("ab", 1000000000)` が値を作らずに R0902 で止まる。報告に大きさと上限 |
| eval | `list_functions` | 03-06 の `List` の組み込みの関数（範囲の外の `get`、`take`・`drop` の境界、`range` の空、`contains`、`concat`、`reverse`、`append`） |
| eval | `list_sort` | 安定な並べ替え、`Float` の NaN を後ろに置く、`0.0` と `-0.0` を等しく扱う |
| eval | `list_hof_order` | `List.map`・`filter`・`fold`・`forEach` が要素を先頭から順に一度ずつ渡す（IO の順で確かめる）。`any`・`all`・`find` が結果の決まった時点で止まる |
| eval | `list_hof_long` | 100 万要素のリストに `List.map`・`filter`・`fold` を適用してもスタックを使い果たさない |
| eval | `option_result_functions` | 03-06 の `Option` と `Result` の関数すべて |
| eval | `adt_recursive` | 利用者の再帰型（`Tree`）を作って辿る |
| io | `print_println_eprintln` | `Console.print` は改行を付けず、`println`・`eprintln` は付ける。標準出力と標準エラー出力 |
| io | `main_unit` | `main` が `()` を返して終了状態 0 |
| io | `main_ok` | `main` が `Ok(())` を返して終了状態 0 |
| io | `main_err` | `main` が `Err("bad input")` を返す。標準エラー出力に `bad input` と改行、終了状態 1、それまでの出力が残る |
| io | `read_text_ok` | `.files/` の `input.txt` を読んで行数を出力する |
| io | `read_text_missing` | ないファイルは `Err`。`IoError.message` の文面は比べず、`Err` の分岐に入ったことを出力で確かめる |
| io | `read_text_invalid_utf8` | 内容が正しい UTF-8 でないファイルは `Err`（ADR 0012） |
| io | `read_text_bom_kept` | 先頭の BOM を取り除かない（`String.byteLength` で確かめる） |
| io | `process_args` | `.args` の引数が渡した順に返り、スクリプトのパスを含まない。`-` で始まる引数もそのまま |
| io | `runtime_error_flushes` | 実行時エラーで止まる前に書いた出力がすべて出る |

`Float.toString` など期待値を導くのに計算が要るテストは、導き方（どの規則を使ったか）をスクリプトのコメントに書く。

### 受け入れテストと対応表

ロードマップの最小実行版の完了条件の 8 行それぞれに、`testdata/acceptance/` のテストを一本以上置く。

| 完了条件 | テスト（名前は例） | 内容 |
|---|---|---|
| 固定の文字列を標準出力に書く | `hello` | 文字列を出力し、終了状態 0 |
| 利用者が代数的データ型で定義したリストを、パターンマッチで集計して出力する | `adt_list_sum` | `type IntList { Nil Cons(Int, IntList) }` を作り、`match` で合計を求めて出力する |
| 十分に深い末尾再帰を行う | `deep_tail_recursion` | 1000 万回の末尾再帰（リリースビルドでなくても数秒で終わる回数に調整してよい。調整したら理由をコメントに書く） |
| 型の合わない式を含む | `type_error_check`（`check`）と `type_error_run`（`run`） | どちらも実行せず、診断コード・span・抜粋を持つ診断を出し、終了状態 2。抜粋は `.text.stderr` で確かめる |
| 網羅していないパターンマッチを含む | `nonexhaustive` | 漏れているパターンを示す E0601 |
| IO を行う関数を、IO を許さない文脈から呼ぶ | `effect_violation` | E0501 |
| ファイルを読んで行数を数える | `count_lines_ok` と `count_lines_missing` | 01-07「プログラムの入口」の例のスクリプト。ファイルがあれば行数を出力し、なければ理由を示して終了状態 1 |
| 構文エラーを含む | `syntax_error` | 誤りの位置を示す診断（`.text.stderr` も置く） |

`INDEX.md` の各行のテストの欄に、`acceptance/<名前>.bnt` の形でテストを並べる。ベンチマークが実行できることの行は、T31 のベンチマークのスクリプトが T25 の差分テストで実行されることで確かめるので、欄に `tools/bench/programs/`（T31）と書く。書き終えたら `spec_coverage.py` を実行し、対応表の欠けがないこと（終了状態 0）を確かめる。

## 受け入れテスト

- 上の二つの表のテストがすべて置かれている。
- `INDEX.md` の完了条件の 8 行すべてに、存在するテストの名前がある。`spec_coverage.py` が終了状態 0 で終わる。
- 実行時エラーの三種（0 による除算、整数の溢れ、`main` の `Err`）と、資源の不足の二種（R0901・R0902）を起こすテストがある。
- 各スクリプトの先頭に `// spec:` の行がある。
- `spec_coverage.py` の出力で、01-04・01-07・01-08 の最小実行版の範囲の節のうち、テストのない節が残っていれば、テストを足すか、足さない理由を完了の報告に書く。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）。ただし、仕様と処理系が食い違うと報告したテストの失敗は除く
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、仕様と食い違った処理系の振る舞いの一覧を書く

## 難易度の理由

実行の結果を確かめるテストが中心であり、期待値の多くは出力の文字列である。仕様の例がそのまま使える場合が多い。注意が要るのは、`Float.toString` の最短の表記、整数の除算と剰余の符号、呼び出しの履歴の段の選び方を、仕様から自分で導いて期待値と照らすことである。

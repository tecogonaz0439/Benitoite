# TODO-201 と TODO-185（Regex の点）の調査

本書は、改造の調査のうち、TODO-201（繰り返す照合を一致ごとに区切り、取り消しと中断を効かせる）と、TODO-185 の `Regex` の確保の上限の 3 点を受け持つ。HTTP の TODO-202 は別の文書で扱う。行番号は 2026-10-11 の `san_benito`（`0485561`）のものである。処理系のビルドとテストは走らせていない。

## 要点

1. 今の `findAll`・`replaceAll`・`split` は純粋な組み込みの関数であり、すべての一致を Rust の中で一度に求める。途中で中断の印も取り消しも調べない。`replaceAllWith` は標準ライブラリのソースだが、最初に `findAll` を呼ぶので同じである。
2. 中断の印は、関数を呼ぶ命令（`CALL`・`TAILCALL` など）ごとに調べている。繰り返しを標準ライブラリのソースのループ（末尾呼び出し）に移せば、一致ごとに中断・取り消し・タスクの切り替えが起こりうる。VM には手を入れなくてよい。
3. regex 1.13.1 の反復の空の一致の規則は「直前の一致の終わりと同じ位置で終わる空の一致を捨て、1 バイト先からもう一度探す。文字の符号の途中の空の一致は探索の側が飛ばす」である。`captures_at`・`find_at` で開始の位置を渡せば、`\b` や `^` は前後の文字を見て判定される。
4. 推奨: 非公開の組み込みの関数を二つ（捕獲グループつきの `findAt` と、範囲だけを返す `spanAt`）設け、`findAll`・`replaceAll`・`replaceAllWith`・`split` を `Regex.bnt` のループで書く。`replaceAll` は、部分の数が 2^24 を超えても作れるよう、部分をまとまりごとにつなぐ。
5. TODO-185 の 3 点の状態: groups の確保は今も確かめていない（推奨案では、一回の操作が作る `Match` が一つになるので、この点はなくなる）。`compile` の誤りの文面は正規表現の全文を含む（文面を切り詰める案を推奨）。`replaceAllWith` は 2 乗ではない（O(k log k + n)。k は一致の数、n は入力の長さ）。ただし、部分のリストが一致 1 つにつき 2 要素ずつ増えるので、一致が 2^23 を超えると `List.append` の上限で止まる。
6. 「最後の切り替えの後に中断の印を調べるか」は、`main` が値で終わった時点で印を一度だけ調べる案（終了状態 130 にする）を推奨する。命令の振り分けの速い経路は変えずに済む。

## 1. 今の実装

### 1.1 組み込みの関数（`crates/benitoite/src/builtins/funcs/regex.rs`）

| 行 | 内容 |
|---|---|
| 10〜15 | `Pattern`（`regex::Regex` と、名前付きグループの名前の表 `Rc<BTreeMap>`） |
| 17〜34 | `Match`。一致の部分の文字列 `text`、始まりの絶対のバイト位置 `start`、一致の中での相対の位置で表したグループの表 `groups`、名前の表を持つ。`heap_bytes` が文字列とグループの表の大きさを返す（TODO-196 の案 B と TODO-042 は前の改造で直した） |
| 61〜90 | `match_value`。`Captures` から `Match` を作る。グループが一致の全体の外に出たら `Stop::Internal` |
| 119〜134 | `compile`。`RegexBuilder::new(source).build()` を既定の設定で呼び、誤りなら `error.to_string()` をそのまま `Result.Error` の文字列にする（130 行） |
| 136〜142 | `isMatch`（`is_match`） |
| 144〜155 | `find`（`captures`） |
| 157〜174 | `findAll`。`find_iter(text).count()` で一致を数えて `CheckedLen::elements` で確かめ（164 行）、`captures_iter` でもう一度辿って `Match` を作る（169〜171 行）。一致の数×グループの数の確保は確かめない |
| 220〜247 | `replace`（`replaceFirst`・`replaceAll` の共通の部分）。`find_iter` で置き換える総バイト数と回数を数え、結果の長さを `CheckedLen::bytes` で確かめてから、`replacen(text, limit, NoExpand(..))` で作る |
| 265〜281 | `split`。`regex.split(text).count()` で数えて確かめ（274 行）、もう一度 `split` で辿る |
| 283〜297 | `DECLS`。「番号は表の中の位置で決まるので、末尾以外には加えない」 |

`regex.rs` の関数は、どれも `builtin!` の `pure fn` で宣言する。マクロ（`crates/benitoite/src/builtins/iface.rs` 846〜893 行）は、`PureCtx`（433〜451 行。作った後に変わらない値の確保と読み出しだけができる文脈）を渡し、`BuiltinDecl { capability: Capability::Pure, .. }` を作る。表の部分は `crates/benitoite/src/builtins/funcs/mod.rs` 95 行以降の `PARTS` に並び、`regex::DECLS` は 135 行にある。表の契約のテスト（`crates/benitoite/src/builtins/table.rs` 491 行以降の `table_names_parts_capabilities_and_schemes_are_consistent`）は、部分ごとの項目の数（493〜496 行。`regex` の部分は 12）、名前の総数 304、権限ごとの数 `[231, 16, 57]` を固定している。

### 1.2 標準ライブラリのソース（`crates/benitoite/src/prelude/stdlib/Regex.bnt`）

| 行 | 内容 |
|---|---|
| 1〜2 | モジュールの説明。一回の照合は入力の長さとパターンの大きさの積、繰り返す照合は最悪で入力の長さの 2 乗とパターンの大きさの積に比例すると書く（前の改造で直した） |
| 16〜18、44〜50 | `findAll`・`replaceAll`・`split` は `@builtin` の宣言 |
| 52〜65 | `replaceAllWith`。`findAll` で全一致を求めてから、`replaceFrom` が `List.get(matches, i)` で一つずつ取り出し、`f` を呼び、`List.append` で部分を二つずつ積み、最後に `String.join(parts, "")` でつなぐ |
| 67〜69 | `sliceOrEmpty`（`String.byteSlice` の `Option` を外す） |

非公開の組み込みの関数の前例は `crates/benitoite/src/prelude/stdlib/Trait.bnt` 67〜71 行の `@builtin("Trait.showString") function showString(..)` と `showCharacter` である。`public` を付けないので、そのモジュールの中からだけ呼べる（03-06「標準ライブラリのソースの書き方」）。同梱の Skill の生成物にも載らない（`skill/references/stdlib/Trait.md` に `showString` はない）。名前が `%` で始まる組み込みの関数（`%List.getFront` など）は、型を処理系の表で与える、脱糖とコード生成のための関数であり、標準ライブラリのソースからは呼ばない。今回の用途の前例にはならない。

### 1.3 中断の印・予算・取り消しを調べる位置

- 中断の印は、関数の値かメソッドを呼ぶ命令で、呼ぶ前に緩い順序付けで読む（02-08「タスクの切り替え」の手順 1）。実装は `crates/benitoite/src/vm/dispatch.rs` 1159〜1161 行（`CALL` と `TAILCALL` の共通の関数）と `crates/benitoite/src/vm/dispatch/cell.rs` 42〜46 行（セルの更新の呼び出し）である。印が立っていれば `interrupt_call`（`dispatch.rs` 293〜304 行）が止める理由を `StopReason::Interrupted` にする。
- 予算は同じ位置で一つ減らし、0 なら遅い経路で回収・取り消し・切り替えを行う（02-08「タスクの切り替え」）。取り消しの要求は予算を 0 にして遅い経路に入らせる（02-08「取り消し」）。
- `PRIM`・`IO`（操作を持たない IO の組み込みの関数）は、その場で組み込みの関数を呼び（`dispatch.rs` 564〜592 行）、印を調べない。`RETURN` も調べない。02-08「タスクの切り替え」は「`PRIM` と演算の命令の途中でタスクを切り替えることはない」と定める。
- 印の実体は `crates/benitoite/src/runtime/run/interrupt.rs` の `ProcessInterrupt`（`AtomicBool`、`requested()` が `Relaxed` で読む）である。終わり方の対応は `crates/benitoite/src/runtime/run.rs` 485〜495 行（`StopReason::Interrupted` を終了状態 130 にする）。
- 02-09「中断の要求」の決定は「VM は、タスクを切り替える位置と、外部に作用する操作を待つ位置で中断の印を調べる」である。`main` が、印が立った後に呼び出しも待ちも通らずに値で終わると、印は読まれず終了状態 0 になる。前の改造で、128 KiB の入力の `findAll` の途中に SIGINT を送ると、照合の後に終了状態 0 で終わることを確かめた（`docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/study-runtime.md` の TODO-196 の節）。

したがって、繰り返しを標準ライブラリのソースの末尾呼び出しのループで書けば、一致ごとの `TAILCALL` で印・予算・取り消しを調べる。VM と 02-08 の決まりは変えずに済む。

### 1.4 一致の扱いの今の振る舞い（テストで固定しているもの）

`crates/benitoite/src/builtins/funcs/regex/tests.rs` が、期待値を固定値で書いて確かめている。

- `findAll`（133〜171 行）: `a*` を `baaa` に当てると `("",0,0)`・`("aaa",1,4)`。空の正規表現を `日é` に当てると 0・3・5 の空の一致（文字の境目だけ）。空の入力には空の一致が一つ。
- `replaceFirst`・`replaceAll`（173〜211 行）: 置換の文字列を展開しない。`a*` で `baaa` → `XbX`、空の正規表現で `é` → `XéX`。
- `split`（213〜241 行）: `,` で `",a,,b,"` → `["", "a", "", "b", ""]`。空の正規表現で `ab` → `["", "a", "b", ""]`。`a*` で `baaa` → `["", "b", ""]`（非空の一致に隣り合う空の一致は区切りにならない）。
- 上限（268〜302 行）: `replaceAll` の結果が 2^30 バイトを超えると `ValueTooLarge { function: "Regex.replaceAll", .. }`。空の正規表現を 2^24 バイトの入力に当てると、`findAll` は `size == 2^24 + 1`、`split` は `size == 2^24 + 2` の `ValueTooLarge` で、値を作る前に止まる。
- `replaceAllWith`（327 行以降）: `f` を左から呼び、グループを使える。

ゴールデンテスト `crates/benitoite/testdata/stdlib/l40-regex.bnt` は、`findAll`・`replaceAllWith`（`f` の中で位置を書き出す）・`replaceFirst`・`replaceAll`・`split`・`isMatch`・誤りの組み立てを、CLI の出力で確かめる。

## 2. 確かめた外部の事実

regex の版は `Cargo.lock` で `regex 1.13.1`・`regex-automata 0.4.18`・`regex-syntax 0.8.11`、`crates/benitoite/Cargo.toml` 30 行で `regex = "=1.13.1"` に固定している。以下の出典のパスは `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/` からの相対である。

### 2.1 繰り返す照合の時間

`regex-1.13.1/src/lib.rs` 1093〜1124 行（「Iterating over matches」）は、`is_match`・`find`・`captures` の最悪 O(m n) が `find_iter`・`captures_iter` には当てはまらず、最悪 O(m n²) であることと、例として `.*[^A-Z]|[A-Z]` と `AAAAA` を挙げ、避ける方法はないと書く。一致ごとに区切っても、一回の探索の O(m n) は変わらない。区切ることで得られるのは、一致の間で止められることだけである。

### 2.2 位置を指定する探索

- `Regex::find_at(haystack, start)`（`regex-1.13.1/src/regex/string.rs` 1154〜1163 行）と `Regex::captures_at(haystack, start)`（1193〜1207 行）は、`Input::new(haystack).span(start..haystack.len())` で探す。文書は「開始の位置は周りの文脈を考慮する。たとえば `\A` は `start == 0` のときだけ一致する」と書き、`\bchew\b` を `eschew` に当てる例で、`&hay[2..]` を探すと一致し、`find_at(hay, 2)` では一致しないことを示す。したがって、入力を `String.byteSlice` で切ってから探す書き方は、`\b`・`^`・`\A` の判定を変えるので使えない。位置を渡す組み込みの関数が要る。
- 同じ文書は「`start >= haystack.len() + 1` のとき panic する」と書く。`Input::set_span`（`regex-automata-0.4.18/src/util/search.rs` 424〜434 行）は `span.end <= haystack.len() && span.start <= span.end + 1` を `assert!` する。組み込みの関数の側で `start <= text.len()` を確かめてから呼ぶ。
- `captures_at` は呼ぶたびに `create_captures()` で捕獲の位置の領域を作る（1198 行）。

### 2.3 空の一致の規則

- `find_iter`・`captures_iter` は、meta の反復（`regex-automata-0.4.18/src/meta/regex.rs` 2114〜2116 行の `FindMatches::next`、2178〜2185 行の `CapturesMatches::next`）を通して、`Searcher::advance` を使う。
- `Searcher::try_advance`（`regex-automata-0.4.18/src/util/iter.rs` 420〜442 行）の規則は次のとおりである。
  1. 今の開始の位置から一回探す。
  2. 見つけた一致が空で、その終わりが直前の一致の終わり（`last_match_end`）と等しければ、`handle_overlapping_empty_match`（667〜678 行）が開始の位置を 1 バイト進めてもう一度だけ探し、その結果（空でも非空でも、なしでも）を採る。
  3. 採った一致の終わりを次の開始の位置と `last_match_end` にする。最初の探索では `last_match_end` はない（`None`、166 行）。
- 1 バイト進めると文字の符号の途中から探すことになるが、meta の設定 `utf8_empty` の既定は真であり（`meta/regex.rs` 3127〜3129 行）、探索の側が、文字の符号を割る空の一致を報告しない（`regex-automata-0.4.18/src/util/empty.rs` の冒頭の説明）。
- `find_iter(..).count()` は半分の一致（終わりだけ）で数える `advance_half` を使う（`util/iter.rs` 395〜413 行。条件は `m.offset() == last_match_end`）。推奨案では数える走査をなくすので、この差は関係しなくなる。
- `split`（`meta/regex.rs` 2234〜2262 行）は、一致ごとに `[前の一致の終わり, 一致の始まり)` を返し、最後に `[最後の一致の終わり, 入力の長さ]` を返す。区切りの一致は `find_iter` と同じ反復で求める。
- `replacen`（`regex-1.13.1/src/regex/string.rs` 956〜1003 行）は、展開しない置換では `find_iter` で辿り、`[前の一致の終わり, 一致の始まり)` と置換の文字列を交互に積み、最後に残りを積む。

以上から、Benitoite の側で次の書き方をすれば、今の 4 関数と同じ一致の並びになる（推論。regex の実装を読んで得た結論であり、実行して確かめてはいない）。

- 最初は位置 0 から、「直前の一致がない」として探す。
- 2 回目以降は、直前の一致の終わりの位置から、「直前の一致がある」として探す。
- 「直前の一致がある」ときに、開始の位置ちょうどで空の一致を見つけたら、開始の位置が入力の長さと等しければ「なし」とし、そうでなければ 1 バイト先からもう一度だけ探す。この処理は Rust の組み込みの関数の中で行う。

### 2.4 組み立ての上限と誤りの文面

- `RegexBuilder` の既定は、NFA の大きさの上限 10 MiB（`regex-1.13.1/src/builders.rs` 53 行の `nfa_size_limit(Some(10 * (1 << 20)))`、`regex-automata-0.4.18/src/meta/regex.rs` 3159 行）と、入れ子の上限 250（`regex-syntax-0.8.11/src/ast/parse.rs` 141 行）である。`size_limit`（`builders.rs` 690 行）、`dfa_size_limit`（733 行）、`nest_limit`（774 行）で変えられる。今の `compile` は既定のまま使い、テスト（`regex/tests.rs` 243〜266 行）が `\w{1000}` で「size limit」の誤りになることを確かめている。
- 正規表現の文字列の長さそのものの上限は、既定の設定にはない（確かめた範囲。`builders.rs` の設定の一覧に長さの上限はない）。
- 構文の誤りの表示（`regex-syntax-0.8.11/src/error.rs` 89〜123 行）は、`regex parse error:` の行に続けて、正規表現の全文と誤りの位置を指す `^` の行を書き、最後に `error: <誤りの種類>` を書く。正規表現が改行を含むときは、行ごとに行番号を付け、79 文字の `~` の区切りで挟む。したがって、文面は正規表現の長さに比例して大きくなり、改行の多い正規表現では行番号の分だけ数倍になる。
- 大きさの上限の誤り（`regex-1.13.1/src/error.rs` 66〜78 行）は `Compiled regex exceeds size limit of {limit} bytes.` であり、正規表現を含まない。
- 捕獲グループの数の上限が NFA の 10 MiB からいくつになるかは、確かめていない。

## 3. 直し方の案

### 3.1 繰り返す照合（TODO-201）

#### 案 A（推奨）: 一致ごとに一回だけ探す非公開の組み込みの関数

`Regex.bnt` に、次の二つを `public` を付けずに宣言する（名前は案）。

```text
@builtin("Regex.findAt")
function findAt(pattern: Pattern, text: String, start: Integer, afterMatch: Boolean) -> Option[Match]

@builtin("Regex.spanAt")
function spanAt(pattern: Pattern, text: String, start: Integer, afterMatch: Boolean) -> Option[Pair[Integer, Integer]]
```

- `findAt` は `captures_at` で探し、今の `match_value` で `Match` を作る。`findAll` と `replaceAllWith` が使う。
- `spanAt` は `find_at` で探し、一致の範囲を `Pair(始まり, 終わり)` で返す。`replaceAll` と `split` が使う。捕獲グループを求めない探索は速い（regex の `replacen` の注記、`string.rs` 963〜970 行）ので、今の `replaceAll`・`split` が `find_iter` を使うのと同じ探索の費用に保てる。
- どちらも、2.3 節の規則（`afterMatch` が真で、`start` ちょうどの空の一致なら 1 バイト先から探し直す）を Rust の中で行う。`start` が負、入力の長さより大きい、文字の境目でない場合は、標準ライブラリのソースの誤りなので `Stop::Internal` にする（02-08「組み込みの関数の呼び出し」、AGENTS.md「失敗を panic で表さない」）。
- 呼び出しの引数の `text` はヒープの文字列の値を指すだけであり、`ctx.str` で借りるので、呼ぶたびに入力を写さない。`Match` は一致の部分だけを写す（前の改造の TODO-196 の案 B）。一致は重ならないので、`findAll` の写しの合計は入力の長さ以下である。

`Regex.bnt` のループの形（概略。`findAll` の例）:

```text
public function findAll(pattern: Pattern, text: String) -> List[Match]
  return findAllFrom(pattern, text, 0, false, [])
end function

function findAllFrom(pattern: Pattern, text: String, start: Integer, afterMatch: Boolean, acc: List[Match]) -> List[Match]
  return match findAt(pattern, text, start, afterMatch) with
    case Option.None -> acc
    case Option.Some(m) -> findAllFrom(pattern, text, matchByteEnd(m), true, List.append(acc, m))
  end match
end function
```

`split` は `[直前の終わり, 一致の始まり)` を `String.byteSlice` で切り出して積み、最後に残りを積む。`replaceAllWith` は `f` を一致ごとに呼ぶ形になる（今は全一致を求めてから `f` を呼ぶ）。

結果の組み立ての費用:

- `List.append` は O(log n)（03-06「List」。末尾の葉を別に持つので、ほとんどの場合は葉の写し一つ）。一致 k 個のリストは O(k log k) で作れ、2 乗にならない。逆順に `List.prepend` で積んで `List.reverse` する必要はない。
- `String.join(parts, "")` は全体の長さに比例する。`String.byteSlice` で切り出す部分の合計は入力の長さ以下である。
- `replaceAll`・`replaceAllWith` は、部分を一つのリストに積むと、リストの長さの上限 2^24 で止まる。今の組み込みの `replaceAll` は結果のバイト数だけを確かめるので、一致が 2^24 を超える入力（16 MiB を超える入力で、空白ごとに置き換えるなど）も扱える。この振る舞いを保つため、部分を 4096 個などのまとまりごとに `String.join` で一つの文字列にし、まとまりの文字列のリストを最後にもう一度 `String.join` でつなぐ。各バイトを 2 回写すだけなので線形である。結果が 2^30 バイトを超えるときは、まとまりか最後の `String.join` が資源の不足で止まる。
- 一致ごとの「直前の部分」と「置き換えた文字列」は、`+` で一つの文字列にしてから積めば、部分の数が半分になる。

#### 案 B: まとめて探す組み込みの関数

開始の位置から最大 N 個（64 など）の一致を求めて返し、標準ライブラリのソースが N 個ごとに呼び直す形。VM のループの費用は 1/N になるが、病的な入力では一回の呼び出しが N 回の O(m n) の探索になり、止められるまでの時間が N 倍になる。戻り値に「次の位置」と「直前の一致があるか」を含めるので、型も複雑になる。案 A を測って遅れが大きいときの次の手とする。

#### 採らない案

- 入力を `String.byteSlice` で切ってから `find` を呼ぶ: 2.2 節のとおり `\b`・`^` の判定が変わる。
- 組み込みの関数の中で中断の印を調べる: regex の API は探索の途中で呼び出し側に戻らないので、一回の探索の途中では調べられない。照合の外側の繰り返しの中で調べることはできるが、純粋な関数の文脈は印を持たず（`PureCtx` は `ValueCtx` だけを持つ）、取り消しとタスクの切り替えは組み込みの関数の中からは起こせない（02-08「組み込みの関数の呼び出し」の応答は完了・待つ・起動・終了だけである）。
- 作業用のスレッドに移す、時間で止める: 前の改造の study-runtime の案 6・案 4 と同じ理由（取り消しても裏で CPU を使い続ける、結果が実行ごとに変わる）で採らない。

#### 一致の多い普通の入力での遅れの見込み

確かめていない（推測を含む）。初回リリース版の測定では、`loop` の 2,000 万回の末尾呼び出しが 1.28 秒であり（`tools/bench/results/2026-10-09-first-release-4304d507f6bf.md` 65 行）、一回の繰り返しは約 64 ナノ秒である。案 A の一致ごとの繰り返しは、`TAILCALL` 一つ、`PRIM` 3〜4 個（`findAt`、`matchByteEnd`、`List.append` など）、`Option` の分岐、`Match` か `Pair` と `Option` の確保を含むので、一致ごとに 0.3〜0.6 マイクロ秒ほど増えると見込む。一致が 10 万個の 1 MiB の入力で 30〜60 ミリ秒、200 万個で 0.6〜1.2 秒の増加である。今の `findAll` は数える走査と作る走査の 2 回を辿るので、探索の費用そのものは約半分になり、増加の一部を打ち消す。

測り方の案（短い測定で十分と考える。07-02「性能の関門」は VM の変更を対象とし、本案は VM を変えない）:

- 改造の前と後の release ビルドで、同じスクリプトを 5 回ずつ交互に走らせ、中央値を比べる。スクリプトは入力を `String.repeat` で作り、次の 5 つを測る。(1) `findAll(r"\d+", ..)` を数字の多い 1 MiB の行に、(2) `findAll(r"\w+", ..)` を 4 MiB の英文に（一致がとても多い場合）、(3) `split(r",", ..)` を 1 MiB の CSV の形の文字列に、(4) `replaceAll(r"\s+", .., " ")` を 1 MiB に、(5) `replaceAllWith` を (1) と同じ入力に。病的な入力（`.*[^A-Z]|[A-Z]` と 32 KiB の `A`）も 1 回走らせ、時間が同じ桁に収まることを見る。
- 道具は `tools/bench/run.py` の比較の仕組みを使うか、短いシェルのループで足りる。記録は `tools/bench/results/` に短い測定として残す（スキル `benchmark`）。ベンチマーク集合への恒久の追加（`programs/regex.bnt`）は必須ではない。
- 判断の目安（案）: (2) の増加が 2 倍を超えるときは、案 B を検討する。

### 3.2 最後の切り替えの後に中断の印を調べるか

案 A を採ると、印を読まない区間は「一回の探索」と「最後の呼び出しから `main` の終わりまで」に縮む。それでも、長い純粋な組み込みの関数（`List.sort` の大きなリスト、`String.repeat` の大きな文字列、一回の病的な `Regex.find` など）の途中で受けた SIGINT は、その後に呼び出しを通らずに `main` が終われば読まれず、終了状態 0 になる。02-09「中断の要求」の決まりの範囲内の振る舞いだが、利用者からは Ctrl-C が効かなかったように見える。

| 案 | 内容 | 評価 |
|---|---|---|
| (a) 今のまま | 決まりを変えない | 作業はない。窓は案 A で狭まるが残る |
| (b) 実行の終わりで一度調べる | 最初のタスク（`main`）が値で終わった後、出力の最後の転送の前に印を一度読む。立っていれば、終わり方を中断の要求にして終了状態 130 にする（止める手順で降ろす枠は残っていない） | 速い経路を変えない。`crates/benitoite/src/runtime/run.rs` の終わり方の決定と、テストの実行器（`crates/benitoite/src/cli/tools/test_runner/mod.rs`）の対応する箇所に閉じる。仕事は終えたが 130 で終わることになる |
| (c) `PRIM` の戻りごとに調べる | 純粋な組み込みの関数から戻るたびに印を読む | `PRIM` は命令の振り分けの速い経路であり、07-02「性能の関門」の測定が要る。`main` の終わりの窓は (b) なしでは残る |
| (d) 長い組み込みの関数の中で調べる | 関数ごとに区切りを入れる | regex は途中で戻らないので照合には使えない。純粋な関数の文脈に印を渡すことになり、02-08 の文脈の分け方を変える |

推奨は (b) である。印を読む位置を一つ足すだけで、「実行中に受けた中断の要求は終了状態 130 になる」と言い切れる範囲が、`main` の終わりまで広がる。02-09「中断の要求」の決定に「`main` が値で終わった後にも印を調べる」を加える変更になる。`main` が `Result.Error` を返したときと、実行時エラーで止まったときの扱い（130 を優先するか）は決める必要がある。実行時エラーは既に止める手順に入っているので、変えないのが自然である（後述の問い 4）。

## 4. TODO-185 の Regex の 3 点

### 4.1 `findAll` の groups の確保

今も確かめていない（`regex.rs` 164 行は一致の数だけを `CheckedLen::elements` で確かめる）。一つの `Match` のグループの表は `captures_len` × 24 バイト（`Option<(usize, usize)>`）であり、`findAll` の一回の呼び出しで、一致の数×グループの数×24 バイトを確保しうる。

- 案 A を採れば、一回の組み込みの関数の呼び出しが作る `Match` は一つになる。02-09「一つの操作で作る値の大きさの上限」は一つの操作で作る値を抑える決まりであり、ループで小さな値を何度も作る場合は対象外である（同節の末尾）。したがって、この点はなくなる。残るのは、ループ全体で確保する量であり、これは利用者のループと同じ扱いになる。
- 案 A を採らないときは、`find_iter` で数えた一致の数に `captures_len` と 24 を掛けた値を、`checked_mul` で計算し、文字列と同じ 2^30 バイトの上限で確かめる（02-09 の計算の仕方に合わせる）。要素の数の上限（2^24）で確かめると、グループが 31 個の正規表現で一致が 100 万個の普通の入力を拒むので、バイトで確かめるほうがよい。

### 4.2 `compile` の誤りの文面の大きさ

今も直っていない（130 行が `error.to_string()` をそのまま値にする）。2.4 節のとおり、構文の誤りの文面は正規表現の全文と `^` の行を含み、改行の多い正規表現では行番号の分だけさらに大きくなる。`alloc_str` は 2^30 バイトの上限を確かめる（`crates/benitoite/src/runtime/heap/ctx.rs` 441〜444 行）ので、上限を超える値は作られないが、超えると `Result.Error` ではなく資源の不足で止まる。上限の内でも、数百 MiB の文字列を作りうる。Rust の `String` を作る時点の一時の確保は、どの案でも確かめられない。

| 案 | 内容 | 評価 |
|---|---|---|
| (i) 文面を切り詰める | 文面が一定の長さ（4 KiB など）を超えたら、`regex parse error: ` と最後の `error: ..` の行だけを残し、正規表現を省いたことを示す（`(pattern of N bytes omitted)` など） | 言語の振る舞いは「理由の文面は版によって変わりうる」（03-08「共通の規則」）の範囲で変わる。誤りの種類は残るので、LLM が直す手がかりは保たれる。位置の情報は失う |
| (ii) 正規表現の長さに上限を設ける | 長さが上限（64 KiB、1 MiB など）を超えたら、組み立てずに `Result.Error` を返す | 解析の時間と一時の確保も抑えられる。言語に新しい上限が増え、03-08 に決まりを足す。単語の一覧から作る長い選択の正規表現を拒みうる。上限の値の根拠がない |
| (iii) `regex-syntax` を直接使う | 誤りの種類と位置を取り出して、短い文面を自分で作る | 依存を直接に足し、regex と同じ解析の設定を二重に持つ。勧めない |

推奨は (i) である。文面の大きさの問題だけを最小の変更で直し、新しい上限を言語に足さない。切り詰める長さは定数にし、`regex.rs` の `text` の子のモジュールに置く（AGENTS.md「文言」）。

### 4.3 `replaceAllWith` の計算量

2 乗ではない。`List.get` と `List.append` は O(log n)（03-06「List」の表）、`String.byteSlice` で写す部分の合計は入力の長さ以下、`String.join` は全体の長さに比例するので、`findAll` を除く部分は O(k log k + n) である（k は一致の数、n は入力の長さ）。表の計算量から導いた結論であり、測ってはいない。

別の点として、部分のリストが一致 1 つにつき 2 要素ずつ増える（63 行）ので、一致が 2^23 を超えると `List.append` が 2^24 の上限で資源の不足になる。`findAll` が許す 2^24 までの一致のうち、半分しか扱えない。案 A でまとまりごとにつなぐ形にすれば、この食い違いもなくなる。

## 5. 設計者に決めてもらう問いの候補

1. 繰り返す照合をどう区切るか。
   - 選択肢: 案 A（一致ごとに一回探す非公開の組み込みの関数と、`Regex.bnt` のループ）／案 B（N 個ずつまとめて探す）／今のまま（文書だけ）。
   - 推奨: 案 A。理由: 中断・取り消し・`Task.withTimeout` が一致の間で効く、決定的な唯一の手段であり、VM を変えずに済む。案 B は止められるまでの時間が N 倍になり、型も複雑になる。遅れが大きいと測れたときに案 B へ移れる。
2. 内部の関数を一つにするか二つにするか。
   - 選択肢: `findAt`（捕獲グループつき）と `spanAt`（範囲だけ）の二つ／`findAt` だけ。
   - 推奨: 二つ。理由: `replaceAll` と `split` は捕獲グループを要らず、`find_at` は `captures_at` より速い。今の組み込みの `replaceAll`・`split` が `find_iter` を使うのと同じ探索に保てる。`findAt` だけにすると、`Match` の確保（一致の文字列の写しとグループの表）が一致ごとに増える。
3. 上限を超えるときの止まり方の変化を受け入れるか。
   - 内容: 案 A では、一致が 2^24 を超える `findAll`・`split` は、値を作る前ではなく、2^24 個を作った後に `List.append` の上限で止まる。報告の関数の名前も `Regex.findAll` から `List.append` に変わる。止まるまでに使うメモリは、成功する最大の呼び出しと同じである。`replaceAllWith` では、止まる前に `f` を呼ぶ。
   - 選択肢: 受け入れる／先に数える走査を標準ライブラリのソースで足す（時間が約 2 倍になる）。
   - 推奨: 受け入れる。理由: 先に数える走査は、時間を倍にして、前の改造が問題にした「止められない時間」を延ばす。止まるまでのメモリは上限の内の成功する呼び出しと同じ大きさで抑えられる。報告の関数の名前は、止めた組み込みの関数を示すという今の決まり（02-09「一つの操作で作る値の大きさの上限」）のとおりである。
4. 実行の終わりで中断の印を調べるか（3.2 節）。
   - 選択肢: (a) 今のまま／(b) `main` が値で終わった後に一度調べ、立っていれば 130／(c) `PRIM` の戻りごとに調べる。
   - 推奨: (b)。`main` が `Result.Error` を返したときも 130 にし、実行時エラーと資源の不足で止まったときは変えない。理由: 速い経路を変えずに、中断の要求を受けた実行が 0 で終わる窓をなくせる。実行時エラーで止まったときは、既に止める手順に入っている。止める理由を後の出来事で置き換えない今の決まり（02-08「タスクの切り替え」の行き詰まりの扱い、02-09「プログラムの実行の流れ」の転送の失敗の扱い）に合わせる。
5. `compile` の誤りの文面を切り詰めるか、正規表現の長さに上限を設けるか（4.2 節）。
   - 推奨: (i) 切り詰める。切り詰める長さは 4 KiB を案とする。理由: 言語に新しい上限を足さずに、文面の大きさだけを抑えられる。上限の値には根拠がなく、長い選択の正規表現を拒みうる。
6. TODO-185 の groups の確保の点を、案 A で解消したとして閉じるか。
   - 推奨: 閉じる。理由: 一回の操作が作る `Match` が一つになり、02-09 の決まりの対象から外れる。ループ全体の確保は、利用者のループと同じくヒープの回収の決まりに従う。

## 6. 作業の分け方の案

| 作業 | 内容 | 完了の条件 | 走らせる関係のテスト |
|---|---|---|---|
| W1: 照合のループ（TODO-201 の本体、TODO-185 の 3 点） | `regex.rs` に `findAt`・`spanAt` を加え、`findAll`・`replaceAll`・`split` の組み込みの関数を消す。`Regex.bnt` に非公開の宣言とループ（`findAll`・`replaceAll`・`replaceAllWith`・`split`）を書く。`replaceAll`・`replaceAllWith` はまとまりごとにつなぐ。`compile` の文面の切り詰め。表の契約のテストの数（`regex` の部分の項目の数、名前の総数、権限ごとの数）を直す。単体テストを、直接呼ぶ形から、スクリプトで確かめる形に移す（後述）。文書（03-08、`Regex.bnt` の説明、言語リファレンス）と、同梱の Skill の生成物の作り直し。CHANGELOG | 1.4 節の期待値がすべて保たれる。`regex.rs` の DECLS に消した関数が残らない。`Regex.bnt` の新しい関数に `public` がない。生成物が作り直してある | `cargo test -p benitoite regex`、`cargo test -p benitoite --lib builtins::table`、`cargo test --test golden`（`l40-regex`）、`cargo test --test skill_docs`、`cargo test --test reference_examples`、`scripts/check.sh` の選んだ検査 |
| W2: 中断の確かめ | `tests/interrupt_process.rs` に、病的な `findAll`（`.*[^A-Z]|[A-Z]` と 1 MiB の `A`。直す前は数分かかる）の途中で SIGINT を送り 130 で終わるテストを足す。`Task.withTimeout` が照合を期限で取り消して `None` を返すことを確かめるテストを足す | 直す前の処理系では待ちの上限（30 秒、16 行の `LIMIT`）で失敗し、直した後は通る | `cargo test --test interrupt_process` |
| W3: 実行の終わりの印（問い 4 で (b) を選んだとき） | `runtime/run.rs` とテストの実行器で、`main` が値で終わった後に印を読む。02-09「中断の要求」と 07-03「中断の要求のテスト（初回リリース版）」を直す。長い純粋な組み込みの関数（`List.sort` の大きなリストなど）の途中で SIGINT を送り、その後に呼び出しを通らずに `main` が終わる場合に 130 になることを確かめるテストを足す | 足したテストが通り、既存の中断のテストが変わらない | `cargo test --test interrupt_process`、`cargo test --test test_command` |
| W4: 短い測定 | 3.1 節の測り方で、W1 の前と後を比べる | 記録が `tools/bench/results/` にある | （測定だけ） |

W1 と W3 は触れるファイルが重ならない。W2 は W1 の後に行う。W1 だけでも 1 本の作業として Codex に渡せる大きさ（`regex.rs` で 60〜100 行の増減、`Regex.bnt` で 80〜120 行、テストの移し替えで 150 行前後。推測）である。メモ（改造は直列で行う）に従えば、W1 → W2 → W3 → W4 の順に一作業ずつ進める。

単体テストの移し方の注意:

- 今の `regex/tests.rs` の `find_all`・`replace_all`・`split` を直接呼ぶテストは、関数がなくなるので、`run_script`（304 行）を使うスクリプトのテストか、ゴールデンテストに移す。期待値（1.4 節）はそのまま使う。
- `expanded_replacement_and_empty_match_lists_are_rejected_before_building`（268〜302 行）のうち、`findAll`・`split` の 2^24 の上限の部分は、2^24 回の VM のループになるので、時間を測ってから長いテスト（`#[ignore = "long: ..."]`）にするか、`findAt` を直接呼ぶ単体テスト（開始の位置と空の一致の規則）に置き換えるかを決める。報告の関数の名前は `List.append` に変わる（問い 3）。
- `findAt`・`spanAt` の単体テストには、`\b`・`^`（`(?m)` を含む）を途中の位置から探す場合（`&text[start..]` で切ると結果が変わる場合）と、`afterMatch` の空の一致の探し直し（多バイト文字の前後、入力の終わり）を含める。スキル `test-audit` の作成時の関門に従う。

## 7. 影響する設計書・テスト・生成物

- 設計書:
  - 03-08「Regex」: 「`Regex.replaceAllWith` は … `Regex.findAll` で求めた一致を … ほかの関数は組み込みで実装する」の段落を、「`findAll`・`replaceAll`・`replaceAllWith`・`split` は標準ライブラリのソースで、一致ごとに一回探す内部の組み込みの関数を繰り返し呼んで書く。一致の間で中断・取り消しが効く」の形に書き直す。時間の記述（最悪で 2 乗）は変えない。`compile` の誤りの文面を切り詰めることを書く（問い 5 で (i) のとき）。
  - 02-09「中断の要求」: 問い 4 で (b) を選んだとき、印を調べる位置に「`main` が値で終わった後」を足す。「プログラムの実行の流れ」の表の「中断の要求で止まった」の行の説明も合わせる。
  - 07-03「中断の要求のテスト（初回リリース版）」: 足した中断のテストの契約を書き足す。
  - 02-08 は変えない（VM の決まりは変わらない）。02-08「値の表現」の表（45 行）の `Regex.Match` の説明も変わらない。
- 標準ライブラリのソース: `Regex.bnt`（1〜2 行の説明は時間の記述を保つ。照合の途中で中断できることを足すかは W1 で決める）。
- 言語リファレンス: `docs/reference/benitoite.md` 798 行の表の説明は時間の記述だけなので、変えなくてよい。日本語の訳（`docs/ja/reference/`）はリリースのときに訳し直す。
- 同梱の Skill の生成物: `skill/references/stdlib/Regex.md` は `Regex.bnt` の `public` の宣言と説明から作るので、宣言が `@builtin` から本体つきの関数に変わると、載せるシグネチャの行の形が変わりうる（確かめていない）。標準ライブラリのソースを変えたら、同じ変更で `cargo run -p benitoite --example gen_skill` で作り直し、`tests/skill_docs.rs` で確かめる。非公開の `findAt`・`spanAt` は載らない（`Trait.md` に `showString` が載らないことから推測）。
- 組み込みの表: `funcs/mod.rs` の `PARTS` の並びの位置で番号が決まる。`regex` の部分の項目を消して加えると、後ろの部分（`csv` 以降）の番号がずれる。確かめた範囲では、番号を固定するテストやゴールデンテストはない（`testdata` と `tests` に `PRIM` の番号を含む期待値はない）。表の契約のテストの数は直す。
- 診断の表: 新しい診断はない。文言の表（`diag::codes`）も変わらない。`compile` の切り詰めの文言は `regex.rs` の `text` の子のモジュールに置く。
- 形式化（`formal/`）: 影響はない。構文・型の規則・脱糖に触れず、標準ライブラリのソースと組み込みの関数だけを変えるからである（07-04「01-12 との対応」の対象外）。`scripts/check-formal.sh` は要らない。
- 性能の関門: VM を変えないので、07-02「性能の関門」の測定（fib と loop）は要らない。W4 の短い測定で一致の多い入力の遅れを見る。W3 は `runtime/run.rs` の終わりの処理だけで、命令の振り分けには触れない。
- skill-eval の課題 `tools/skill-eval/tasks/regex_text/` は、言語の振る舞いが変わらないので影響しない。
- CHANGELOG の Unreleased: 「繰り返す照合の途中で Ctrl-C と `Task.withTimeout` が効く」「`Regex.compile` の誤りの文面が長い正規表現を含まない」「一致が多い `replaceAllWith` が止まらない」と、問い 3 の止まり方の変化（報告の関数の名前）を書く。問い 4 の (b) を選べば、「`main` が終わる直前に受けた中断の要求も終了状態 130 になる」を書く。

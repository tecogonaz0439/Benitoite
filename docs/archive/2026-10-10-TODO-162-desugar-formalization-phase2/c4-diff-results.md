# C4c-1: `try`・`with`・`lazy` の脱糖の差分検査

2026-10-10 に実装・検査した。TODO-162 フェーズ 2 の C4c-1 を扱う。C4a-1 の表層の定義を使い、交換形式、Rust のテスト内の書き出し、形式化用の生成器だけを広げた。処理系の本番のコード、`Surface`・`Release`・`Core`、設計書、検査スクリプトは変更していない。コミットはしていない。

## 入力・比較の単位

C3 と同じ探索規則でゴールデン入力 523 件を集め、`generate_formal` の種 0〜999 から 1,000 件を生成した。比較単位は、利用者の全モジュールの `DefOrigin::User` かつ `DefKind::Fn` の定義である。型検査などに失敗した入力を「除外」、型検査後に今回の範囲から外れる関数を「対象外」とする。対象外の関数と比較できる関数が同じプログラムにある場合、プログラムを対象外と数え、関数は別々に数える。

無作為の入力は C3 と同じではない。`generate_formal` だけに専用の選択を加えた。通常の `generate(seed, stage)` は、段 1〜6 と種 0〜999 の 6,000 組について、HEAD の生成器とソース・機能別計数がすべて一致した。比較用の一時の Rust プログラムは `target/desugar-diff/generator-stability/` に置いた。

## 範囲に入れた構成と書き出し

| 構成 | 交換形式と対応 |
|---|---|
| Result の `try` | `tryResult(retArgs, ok, err, inner)`。`retArgs` は `try_kinds` の `TryInfo.ret` の型引数から取る |
| Option の `try` | `tryOption(retArgs, someCon, noneCon, inner)`。戻り値の型引数は同じ経路から取る |
| `with` | 各束縛を `withE(o, bound, body)` にする。2 束縛目以降を、前の本体の唯一の文 `.last` として入れ子にする。最後の本体は元の本体である |
| `lazy` | `lazyE(body)` にする。内部の局所変数は既存の環境で番号に移す |
| コアの `Use` | `use(resource, body)` にする |
| コアの `Lazy` | `lazyC(body)` にする |

構成子は `resolved.stdlib("Benitoite.Result.Ok")` などから `BindingKind::Ctor { data, tag }` を取り出し、既存の `con_name(data, tag)` で名前を作る。これは処理系の非公開の `std_ctor` と同じ引き方である。`withE.o` は、既存の `opaque` の名前 `"<BuiltinTypeId>:<型引数の JSON>"` と同じ文字列である。たとえば `TaskGroup` は `"15:[]"` になる。

Lean の JSON の符号化・復号、Exchange から Surface への変換、Release の出力から Exchange への変換を同時に広げた。ラムダのエフェクトを別欄で比較する既存の処理も、`try` の入力、`with` の束縛式と本体、`lazy` の本体をたどるようにした。`lazy` の中のラムダのエフェクトも比較する。

比べる前に捨てる情報は、C3 の型・由来・名前・識別子の付随情報に加え、`Use`・`Escape` の型とエフェクトの付随情報、`Lazy` の `BodyId` である。`Escape` の値、`Use` のリソースと本体、`Lazy` の本体は捨てない。意味変換による新しい正規化、`let` の代入消去は加えていない。

表層の範囲判定から `try`・`with`・`lazy` を外し、コアの `Use`・`Lazy` を `unsupported` にする分岐を、対応する書き出しに替えた。ほかの対象外の印は維持した。範囲内の `lazyC` の本体だけを `unsupported("Resume")` に替えた一時のコーパスは、不一致 1、対象外 0、終了状態 1 になった。対象外の印を対象外件数に戻して隠していない。

## 指摘 1: Result 位置の型の注釈

Rust の脱糖と同じ `Tail`・`Result`・`Other` を書き出し側に設けた。関数の本体は `Tail`、末尾の式だけがブロックの位置を受け継ぐ。括弧、条件分岐・else if、`match` の分岐は位置を受け継ぐ。`with` の本体は外側が `Tail` または `Result` なら `Result` にする。

束縛の式、呼び出しの引数、パイプの両辺、条件、照合対象、ガード、リストの要素、単項演算の入力は `Other` にする。通常の二項演算の両辺も `Other` とし、`and`・`or` の右辺は外側が `Tail` の場合だけ `Tail` にする。`Result` は右辺へ伝えない。`return` の入力も、外側が `Tail` の場合だけ `Tail` とし、それ以外は `Other` にする。ラムダは戻り値型を自身の R に替えて本体を `Tail` で処理し、`lazy` は戻り値型を退避して本体を `Other` で処理する。

`Result` 位置の `returnE.ret` と `matchE.ret` を、処理系の `result_ty` と同じく現在の関数の戻り値型 R に替える。Lean の脱糖はこの注釈を捨てるため、コアの一致だけでは補正の正しさを確かめられない。書き出し側は各関数に `annotations` を残し、コーパスにも合計を残して標準エラーに報告する。配列の一つ目が対象箇所数、二つ目が元の注釈と R が異なる箇所数である。対象外の関数内の箇所も数える。

| 入力 | 位置・注釈 | R に替えた数 | 元の注釈が R と異なる数 |
|---|---|---:|---:|
| ゴールデン | Result の `returnE` | 19 | 19 |
| ゴールデン | Result の `matchE` | 0 | 0 |
| 無作為 | Result の `returnE` | 2,000 | 2,000 |
| 無作為 | Result の `matchE` | 487 | 487 |
| 合計 | Result の `returnE` | 2,019 | 2,019 |
| 合計 | Result の `matchE` | 487 | 487 |

Tail の `matchE` は補正せず、同じ二つの数を観察だけする。ゴールデンは 56 箇所中 1 箇所で R と異なり、無作為は 0 箇所だった。その 1 箇所は `testdata/syntax/f04_list_spread.bnt` の `insertByCount` であり、元の注釈は `Unit`、R は `List[Pair[String, Integer]]` だった。この関数自体はリストのパターン・ガード・展開などのため対象外である。小さな、範囲内の関数でも同じ差を確認した。

小さい入力の一つは次の関数である（同じ入力に `main() -> Unit` を置いた）。

```text
function direct() -> Integer uses State
  with group = TaskGroup.open() do
    return 1
  end with
end function
```

JSON の本体は次の形になった。元の `return` の型は `Unit` であり、`resultReturn` は `[1, 1]` だった。

```json
{"last":{"expr":{"withE":{
  "o":"15:[]",
  "bound":{"call":{"callee":{"primName":{"name":"TaskGroup.open","tys":[],"effs":[]}},"args":[]}},
  "body":{"last":{"expr":{"returnE":{
    "ret":{"base":{"name":"Integer"}},
    "inner":{"literal":{"value":{"integer":{"value":1}}}}
  }}}}
}}}}
```

補助の小さな入力は 7 関数であり、JSON の注釈を直接確認した。入れ子の `with`・`if`・`match` を通った `return` と `match` は `Integer` になった。束縛式の `return` は元の `Unit`、論理演算の右辺の `return` は元の `Boolean` のままだった。外側の R が `Integer` のとき、内側のラムダの R が `String` と `Boolean` である例でも、各ラムダ内の `with` の注釈はそれぞれの R になった。Tail の `matchE` は `Unit` のまま保たれた。7 関数の補助コーパスの差分も一致した。この補助入力は主コーパスの数に加えていない。

## 最終の数と内訳

| 入力 | 単位 | 対象（一致＋不一致） | 一致 | 不一致 | 対象外 | 除外（検査の誤り） |
|---|---|---:|---:|---:|---:|---:|
| ゴールデン | プログラム | 175 | 175 | 0 | 83 | 265 |
| ゴールデン | 関数 | 352 | 352 | 0 | 103 | 計数しない |
| 無作為 | プログラム | 1,000 | 1,000 | 0 | 0 | 0 |
| 無作為 | 関数 | 7,218 | 7,218 | 0 | 0 | 0 |

Rust 側の入力の計数は、対象の関数を一つでも書き出せたかで分けるため、書き出し 1,203・対象外 55・除外 265 である。28 プログラムが対象と対象外の関数を両方持つ。比較器のプログラムの判定とはこの 28 件について異なる。

新しく対象に入った構成の数は次のとおりである。「関数」はその構成を持つ範囲内の関数数、「箇所」はその構成の出現数である。対象外の関数に含まれる構成は数えない。

| 構成 | ゴールデンの関数／プログラム／箇所 | 無作為の関数／プログラム／箇所 |
|---|---|---|
| `tryResult` | 26 / 24 / 42 | 1,000 / 1,000 / 1,000 |
| `tryOption` | 0 / 0 / 0 | 1,000 / 1,000 / 1,000 |
| `withE` | 16 / 16 / 23 | 1,000 / 1,000 / 1,492 |
| `lazyE` | 4 / 4 / 5 | 1,000 / 1,000 / 1,000 |

対象外の理由の内訳は次のとおりである。同じ関数が複数の理由を持つので、合計は対象外の総数にならない。無作為の内訳はすべて 0 である。既知の差は構文名とは別の理由名にしている。

| 理由 | ゴールデンの関数数 | ゴールデンのプログラム数 |
|---|---:|---:|
| field | 22 | 17 |
| interpolation | 22 | 22 |
| record | 21 | 18 |
| handler | 22 | 20 |
| resume | 17 | 16 |
| user operation | 13 | 13 |
| constant reference | 8 | 7 |
| alternative | 4 | 4 |
| list pattern | 7 | 7 |
| guard | 5 | 5 |
| range pattern | 3 | 3 |
| Rigid | 2 | 2 |
| typeclass method | 29 | 26 |
| record pattern | 4 | 4 |
| spread | 2 | 2 |
| class_constraints | 10 | 5 |
| TypeArg.Head | 4 | 3 |
| App | 1 | 1 |
| Decimal literal | 1 | 1 |
| known: try in placeholder argument | 0 | 0 |

## 不一致の分類

最終の差分に見つかった不一致はなしである。(a) 処理系の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化・書き出しの不足はすべて 0 件である。今回の三つの構成に、意味変換による追加の正規化は要らなかった。

## 既知の差: プレースホルダの引数の中の `try`

プレースホルダの穴でない引数の中に `try` がある関数は、`known: try in placeholder argument` として対象外にする。引数の中のラムダ・`lazy` に入ると、この判定の文脈を退避する。その内側で新しいプレースホルダの引数に入った場合は再び判定する。処理系の本番の脱糖は変更していない。

主コーパスにはこの理由だけで除いた例はなかった。後述の `try` の再現例を、テストの登録をせずに、現在の書き出しの補助を呼ぶ一時の実行ファイルで確認した。その関数は既知の差で対象外 1、同じ入力の残りの 2 関数は一致した。引数内のラムダに `try` を置いた例と、引数内の `lazy` の中のラムダに `try` を置いた例は、同じ入力の計 5 関数がすべて範囲内で一致した。これらの補助入力は主コーパスの数に加えていない。

## 処理系の不具合の候補の確かめ

P10 の再現テストは、依頼どおり、リポジトリ外の `/private/tmp/benitoite-c4c1-probes/` のプログラムを CLI で検査・実行する確かめに置き換えた。以下のプログラムをリポジトリのテストには加えていない。コマンドは `cargo run -p benitoite -- check <path>` と `cargo run -p benitoite -- run <path>` である。各出力から cargo の構築・起動の行だけを省く。全出力と終了状態は `target/desugar-diff/c4c-1/cli-probes.json` に残した。

### プレースホルダの引数内の `try`

```text
import Benitoite.Unofficial.IO.Console
function add(left: Integer, right: Integer) -> Integer
  return left + right
end function
function probe() -> Option[Integer]
  bind f <- add(try Option.None, _)
  bind n <- f(1)
  return Option.Some(n)
end function
function main() -> Unit uses Console.Write
  match probe() with
    case Option.Some(n) -> Console.writeLine(Integer.toString(n))
    case Option.None -> Console.writeLine("none")
  end match
end function
```

`check`: 終了状態 0。標準出力・診断ともに空である。

`run`: 終了状態 3。標準出力は 空である。

標準エラー:

```text
internal error: internal compiler error
   = note: benitoite 0.0.1
   = note: the error occurred in the run stage
   = note: the panic occurred in the VM thread
   = note: builtin Integer.toString: argument count or kind mismatch
   = note: this is a bug in the implementation; please report it with the script that caused it
```

### 節内で呼ぶ、引数内の `resume`

```text
import Benitoite.Unofficial.IO.Console
effect Ask
  function ask() -> Integer
end effect
function add(left: Integer, right: Integer) -> Integer
  return left + right
end function
function main() -> Unit uses Console.Write
  bind n <- handle
    ask() + 2
  with
    case ask() ->
      bind f <- add(resume(10), _)
      f(1)
  end handle
  Console.writeLine(Integer.toString(n))
end function
```

`check`: 終了状態 0。標準出力・診断ともに空である。

`run`: 終了状態 0。標準出力は 

```text
13
```

### 節の外へ保存してから呼ぶ、引数内の `resume`

```text
import Benitoite.Unofficial.IO.Console
effect Ask
  function ask() -> Integer
end effect
function add(left: Integer, right: Integer) -> Integer
  return left + right
end function
function main() -> Unit uses Console.Write, State
  bind saved: Reference[Option[function(Integer) -> Integer]] <- Reference.new(Option.None)
  bind _ <- handle
    ask() + 2
  with
    case ask() ->
      bind f <- add(resume(10), _)
      Reference.set(saved, Option.Some(f))
      100
  end handle
  match Reference.get(saved) with
    case Option.Some(f) -> Console.writeLine(Integer.toString(f(1)))
    case Option.None -> Console.writeLine("none")
  end match
end function
```

`check`: 終了状態 0。標準出力・診断ともに空である。

`run`: 終了状態 1。標準出力は 空である。

標準エラー:

```text
runtime error[R0501]: `resume` was called twice in one clause
  --> /private/tmp/benitoite-c4c1-probes/resume-escaped.bnt:14:21
   |
14 |       bind f <- add(resume(10), _)
   |                     ^^^^^^^^^^
   |
   = note: call trace (innermost first):
             <lambda /private/tmp/benitoite-c4c1-probes/resume-escaped.bnt:14:17> at /private/tmp/benitoite-c4c1-probes/resume-escaped.bnt:19:63
             main
   = note: functions left by tail calls are not shown
```

`try` の例は、型検査が受け付けた `Integer` を返すはずの生成ラムダから `Option.None` が返り、その値を整数として使うところで処理系の不具合になる。節内の `resume` の例では、生成ラムダが外側の継続を使い、`10 + 2 + 1 = 13` を出力する。保存した例では `resume` を一度も実行していない段階でハンドラを抜けるが、後から初めて呼んだときにも R0501 になる。後二者は処理系の不具合としての停止ではない。P10 の候補について、型検査が受け付けることと、生成ラムダから外側の継続を使う振る舞いを確認できた。恒久的な再現テストを加えるかはオーケストレータに残す。

## 無作為の生成器

各種に、Result・Option の `try` を持つ関数、`with` を持つ関数、`lazy` を持つ関数を四つ加え、`main` から呼ぶ。Result・Option は入力の成功型を `Integer`、戻り値の成功型を `String` にして、`retArgs` が入力の型引数ではないことも比較する。成功／失敗の入力を種に従って選ぶ。`with` は 1 束縛または 2 束縛、内部の途中の `return` は `if` または `match` から選ぶ。`lazy` は局所値を捕えるラムダと、既存の生成器が作る整数式を含む。

通常の生成器の共有部分は変更していない。形式化用の専用の乱数源は `seed ^ 0xc4c1` を使い、通常の生成器の乱数列に影響しない。無作為の 1,000 入力すべてが型検査を通り、対象外も不一致も 0 だった。

## 検査・時間

この worktree の `Surface` の定理には C4a-1 が置いた `sorry` が 12 か所ある。`scripts/check-formal.sh` の `sorry` 検査を変更せず、依頼の手順を手で実行した。

```sh
export BENITOITE_DESUGAR_DIFF_DIR="$PWD/target/desugar-diff/c4c-1"
(cd formal && lake build desugarDiff)
cargo test --test desugar_export -- --include-ignored --nocapture
formal/.lake/build/bin/desugarDiff "$BENITOITE_DESUGAR_DIFF_DIR/corpus.json" "$BENITOITE_DESUGAR_DIFF_DIR/report.json"
```

| 検査 | 結果・時間 |
|---|---|
| `lake build desugarDiff` | 成功、16 jobs。交換形式の初回構築は約 10 秒 |
| `lake build` | 成功、63 jobs。構築済みの定理を使う実行は約 0.03 秒。既存の `sorry` は 12 か所のまま |
| Rust の書き出し | 1 テスト成功。テスト内の計測 47.579 秒、ハーネス 48.13 秒。最終実行の cargo の構築は 0.32 秒 |
| Lean の主コーパスの比較 | 終了状態 0、約 0.669 秒、不一致 0 |
| `cargo fmt --check` | 成功 |
| `cargo clippy -p benitoite --all-targets -- -D warnings` | 成功、最終実行 0.28 秒 |
| `git diff --check` | 成功 |

主コーパスと報告は `target/desugar-diff/c4c-1/corpus.json`・`report.json`、比較の全出力は `diff.log` にある。注釈の確認は `annotations.json`・`annotations-report.json`、既知の差と境界の確認は `known-try.json`・`known-try-report.json`・`boundaries.json`・`boundaries-report.json` にある。これらと、対象外の印を故意に加えた `unsupported.json` は通常の集計に加えていない。

`scripts/check.sh --base HEAD --dry-run` は今回の 6 ファイルについて `rust`・`formal` を選んだ。共通検査の Rust 部分は `scripts/check.sh --base HEAD --only rust` で走らせた。format と mark-sweep の lint（6.86 秒）は通り、テストの構築は 19.34 秒だった。既存の HTTP テスト `runtime::io::http::tests::stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting` が `runtime/io/http/tests.rs:298` のソケットの bind で `PermissionDenied: Operation not permitted` を受けて停止した。ライブラリテストは 789 成功・1 失敗・16 ignored、38.93 秒であり、共通検査の終了状態は 1 だった。後続の GC 強制、仮置きの許可、Skill の生成物の検査には到達していない。全出力は `target/desugar-diff/c4c-1/check-rust.log` にある。ソケットを bind できる環境での共通検査をオーケストレータに残す。

テストの作成時の関門として、既存の差分検査が守る「公開の脱糖と独立した Lean の脱糖が対応する」という契約を広げた。今回の追加は失敗構成子の型引数、解放の枠の入れ子と評価順、遅延内の捕捉・関数境界の退行を検出する。C3 では三つとも対象外だったため、この失敗を捕まえなかった。既存の書き出しテストを拡張し、本番の差し込み口は加えていない。テストの削除、本番のコードの変更はない。

## C4a-2 で広げるときの注意

- 範囲の判定とコアの対象外の印を同時に広げる。今回は `Handle`・`Resume`・利用者の `Op`、`Rigid` をまだ対象外にしている。
- 継続の変数 `ContVar` は普通の局所変数と区別して番号へ移す。節の暗黙の継続を、最も内側の節から明示的に書き出す。
- 節の中の `Rigid` と定義の型パラメータを、節の型パラメータ数と入れ子に合わせてずらす。`try.retArgs` も節内の番号に合わせる。型引数の番号の恒等対応をそのまま使わない。
- 利用者の操作とエフェクトの表を書き出し、操作の呼び出しと値として使う形を広げる。節に書いた組み込みの操作と普通の組み込みの関数を対応させる。
- ラムダ・`lazy` は外側の継続と戻り値型を退避する。プレースホルダでない引数内の `resume` には、今回確認した継続の漏れがあるので、同じ既知の差として別名で判定するか、処理系の修正後に範囲へ入れる。
- `Handle` の付随情報を捨てる範囲を決め、操作・継続・節の対応は比較に残す。脱糖が本体を複製・並べ替えるなら、出力順だけでラムダのエフェクトを対応させる既存の方式を見直す。
- Tail の `matchE` の注釈が R と異なる例は今回直していない。表層の型付けの前提を検査する段階では扱いを決める必要がある。


## C4c-2: `handle`・`resume`・利用者の操作

2026-10-10 に実装・検査した。C4a-2 の脱糖の定義に合わせ、交換形式、Rust のテスト内の書き出し、形式化用の生成器を広げた。C4c-1 の記録は変更していない。処理系の本番のコード、`Surface`・`Release`・`Core`、設計書、検査スクリプトも変更していない。コミットはしていない。

### 対象と入力

比較単位と入力の探索規則は C4c-1 と同じである。ゴールデン入力は 523 件、無作為な入力は `generate_formal` の種 0〜999 の 1,000 件である。無作為の入力は C4c-1 と同じではない。今回の生成器は、C4c-1 の入力にハンドラと操作を使う関数を加える。

表層の範囲判定から handler・resume・user operation・Rigid を外し、コアの `Handle`・`Resume`・利用者の `ValKind::Op` を書き出す分岐を加えた。型クラス、レコード、展開、パターンの拡張などの対象外の理由は維持した。新しく対象にした構成と、その構成を含む比較対象の関数数は次のとおりである。同じ関数を複数の行に数える。

| 構成 | ゴールデン | 無作為 |
|---|---:|---:|
| `handle` | 18 | 6,000 |
| `resume` | 13 | 5,155 |
| 利用者の操作の名前（呼び出し位置を含む） | 10 | 6,000 |

比較したコアの節はゴールデン 25 節（組み込み 10、利用者 15）、無作為 8,000 節（すべて利用者）である。型パラメータを持つ節は、それぞれ 6 節、4,000 節である。ほかの対象外の構成を含む関数もあるため、ゴールデンでこれらの構成を含む全関数が対象になったことは意味しない。これら四つの理由による除外はなくなった。

### 交換形式と表

`Corpus.version` は **2** に上げた。入力ごとに `ops`・`effects`・`primOps` を加え、型検査で除外された入力にも空の並びを出す。旧版のコーパスは新版の比較器で受け付けない。

表層に `opName(name, tys)`・`handleE(body, clauses)`・`resume(index, inner)`、コアに `op(name, tys)`・`handle(body, clauses)`・`resume(index, value)` を加えた。表層の節とコアの節は、操作、引数の個数 `arity`、型パラメータの個数 `ntys`、本体を持つ。節の順序は保持する。操作を直接呼ぶ形は、既存の `call` の callee に `opName` を置く。

利用者の操作とエフェクトは `op:{BindingId}`・`effect:{BindingId}` で識別する。表示用の `OpDef.name` は識別に使わない。節の組み込みの操作は `resolved.builtin_ops` で組み込みの関数を引き、既存の `primName` と同じ名前の `OpRef.prim` に移す。

利用者の操作表は、名前、属するエフェクト、型パラメータの組み込みの制約、引数の型、戻り値の型を持つ。エフェクト表は、エフェクトの名前と、宣言順の操作名の並びを持つ。標準ライブラリがソースで宣言する利用者のエフェクト（`Assert.Check` など）も含める。`builtin` が `Some` の操作と組み込みのエフェクトはこの二つの表から除き、組み込みの操作の名前・`arity`・`ntys` だけを `primOps` に置く。

表は一度だけ出す。Rust 側で、操作の束縛、エフェクトと操作の並び、組み込みとの対応、操作の個数、型検査の scheme とコアの scheme の一致を確かめる。Lean 側はこれを表層の `Program.ops`・`effects` に移し、全表層項を辿って、節の `arity` と宣言の引数数、節の `ntys` と宣言の型パラメータ数の一致を検査する。これは `HasClauses.cons` の対応する前提の検査である。組み込みの節も `primOps` で同じ検査を行う。表そのものを二重に出して同じ写しどうしを比較する検査は行わない。

操作の値は型引数だけを持つ。表層の型検査の `type_args.effects` とコアの `ValKind::Op.targs.effects` が空であることを Rust の書き出しで確かめ、空でなければ停止する。非空のエフェクト引数を捨てて一致させることはしない。組み込みの操作名を表層から移す場合も同じ検査を行う。

### 継続と型変数の番号

表層の値の環境を、普通の局所変数、継続、名前のない位置の三種類に分けた。節の引数を宣言順に加え、`_` も名前のない位置として加え、最後に継続を加える。番号は環境の末尾から数えるので、節の入口では継続が 0、最後の引数が 1、その前の引数が 2、その後が外側の環境となる。

表層の `resume` は、その位置の環境で最も内側の節の継続を探して番号を求める。入れ子の `handle` の本体は継続を追加しないので、外側の節の継続を指す。内側の節は自分の継続を追加する。普通の束縛を挟めばその個数だけ番号が増える。コアでも普通の `VarId` と `ContVar.id` を別の印で保持し、`Resume.cont` と一致する継続の番号を求める。継続が見つからないときは停止する。

節の型変数は `(節の NodeId, ntys)` の積み重ねで管理する。積むのは節の本体に入るときだけであり、`handle` の本体には積まない。`Rigid { clause: c, index: j }` は、j に「c より内側の節の型パラメータ数の合計」を足して `tvar` に移す。c が積み重ねにない場合と j がその節の範囲を越える場合は、書き出しの誤りとして停止する。定義の `Ty::Param` は、囲む節の型パラメータ数の合計だけずらす。

同じ換算を、型引数、ラムダの引数の型、節内の `try.retArgs`、`return`・`match` の注釈にも適用する。コアの節の `ntys` は `core.schemes[clause.op].type_params.len()` から求める。節の `node` は `Rigid` の換算に使ってから捨てる。

ラムダ・`lazy` に入ると外側の継続の印を隠す。そこから外側の継続を指す `resume` が型検査を通った場合は、対象外に数えず書き出しを止める。内側で新しく作った節の継続は通常どおり扱う。

### 比較前に捨てた情報

`Handle.id`・`handled`、節の `id`・`node`・`tail_resumptive`・`span`、節の引数の型、`cont.arg` を比較するコア項から除いた。引数の型と継続の引数の型は操作宣言から求まる。操作と節の対応、引数数、型パラメータ数、継続の参照先、本体と節の順序は比較に残す。

ラムダのエフェクトは従来どおり別欄で比較する。Lean の `Expr.lambdaEffects` に `handleE`・`resume` を加え、Rust のコア走査にも `Handle` を加えた。両側ともハンドラの本体、節の宣言順に辿り、再開の引数内のラムダも辿る。今回の脱糖はこの順序を変えず、本体も複製しない。

### 最終の差分検査の結果

| 入力 | プログラム一致 | プログラム対象外 | 型検査等で除外 | 関数一致 | 関数対象外 | 不一致 |
|---|---:|---:|---:|---:|---:|---:|
| ゴールデン | 190 | 68 | 265 | 371 | 84 | 0 |
| 無作為 | 1,000 | 0 | 0 | 14,218 | 0 | 0 |
| 合計 | 1,190 | 68 | 265 | 14,589 | 84 | 0 |

プログラムの対象内は 1,190 件、対象外は 68 件である。比較した関数は 14,589、対象外の関数は 84、型検査後の関数の合計は 14,673 である。Rust の書き出しの表示は、比較できる関数が一つでもある入力を exported と数えるため、exported 1,211、out of scope 47、excluded 265 となる。比較器は対象外の関数が一つでもあればプログラムを対象外と数えるため、プログラムの数え方にこの差がある。

対象外の理由の内訳は次のとおりである。理由は重複して数える。無作為の関数には対象外の理由はない。

| 理由 | ゴールデンの関数 | ゴールデンのプログラム |
|---|---:|---:|
| field | 22 | 17 |
| interpolation | 22 | 22 |
| record | 21 | 18 |
| constant reference | 8 | 7 |
| alternative | 4 | 4 |
| list pattern | 7 | 7 |
| guard | 5 | 5 |
| range pattern | 3 | 3 |
| typeclass method | 29 | 26 |
| record pattern | 4 | 4 |
| spread | 2 | 2 |
| class_constraints | 10 | 5 |
| TypeArg.Head | 4 | 3 |
| App（高カインドの型適用） | 1 | 1 |
| Decimal literal | 1 | 1 |
| known: try in placeholder argument | 0 | 0 |
| known: resume in placeholder argument | 0 | 0 |

最終の比較で見つかった不一致は **なし** である。(a) 処理系の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化・書き出しの不足として残る不一致はすべて 0 件である。コア項の意味を変える正規化は加えていない。

作成中には、組み込みの操作の scheme を `table::builtin_scheme` から引こうとして書き出しが停止した。この関数はソースで宣言される操作には `None` を返すため、型検査が持つ宣言の scheme を使う形に直した。除外された入力の表の欄が欠ける不備も、空の並びを書く形に直した。いずれも差分を比較する前の書き出しの不備であり、処理系の脱糖と Lean の脱糖の不一致ではない。生成器に誤った構成子の型引数構文を書いた箇所は、値の束縛の型注釈に替えた。生成した入力に検査の誤りがあれば、テストを止める検査も加えた。

### 既知の差と補助コーパス

プレースホルダの穴でない引数内にある `resume` が、その引数の外で束縛された継続を指すときは、`known: resume in placeholder argument` として関数を対象外にする。引数に入るときの節の深さを保存し、`resume` の位置の節の深さがそれ以下なら、この理由を付ける。引数内の `handle` の本体は新しい節に入らないので外側の継続を指す。引数内の節の本体は深さが増えるため、その節の継続を指す `resume` は除外しない。さらに内側のプレースホルダの引数に入れば、その位置の深さを保存し直す。

C4c-1 の `try` の印は併用するが、再開の判定には使わない。ラムダ・`lazy` に入ると両方のプレースホルダの文脈を退避する。主コーパスでこの既知の差として除いた関数は **0** である。

一時の実行ファイルから同じ書き出しを呼ぶ補助コーパスを `target/desugar-diff/c4c-2/probes/` に作った。リポジトリのテストには登録せず、主コーパスの数にも加えていない。

| 補助入力 | `probe` の判定 |
|---|---|
| 外側の節内の `add(resume(10), _)` | 既知の差 |
| 外側の節内の `add(handle resume(10) with … end handle, _)` | 既知の差 |
| 引数内の節でさらに `add(resume(10), _)` を作る | 既知の差 |
| `add(handle ask() with case ask() -> resume(10) end handle, _)` | 対象内・一致 |
| 外側の節内で上の新しい節を作る | 対象内・一致 |

補助コーパスは 5 プログラム・15 関数で、プログラム一致 2、プログラム対象外 3、関数一致 12、既知の差による関数対象外 3、不一致 0 である。最初の例の節の本体は次の形であり、C4c-1 に記録した TODO-178 の再現と同じである。

```text
case ask() ->
  bind f <- add(resume(10), _)
  f(1)
```

外側の節から `lambda() return resume(10) end lambda` または `lazy resume(10) end lazy` を作る 2 入力は、どちらも型検査が E0509 で拒んだ。型検査の Internal 診断、脱糖の InternalError は見つからなかった。

補助コーパスから対象内の関数を一つ取り出し、コアに `unsupported("Handle")` を入れたもの、継続番号を変えたもの、節の操作を変えたものを比較した。いずれも関数不一致 1、対象外 0、終了状態 1 となった。表層の節の `arity` または `ntys` を変えたものは `clause signature mismatch`、終了状態 2 で停止した。範囲内に残る対象外の印や、節の対応の不整合を除外件数に戻して隠していない。

### 生成器と検査

`generate_formal` だけに専用の生成を加えた。既存の専用乱数源で、再開する節としない節、末尾の再開と束縛して使う再開、整数の加算量、節内の `return` と再開を選ぶ。種 0〜999 の選択は、末尾の再開 363、束縛して使う再開 290、再開しない節 347 である。

各入力に、操作を値として使う形、直接呼び出し、パイプとプレースホルダ、入れ子の `handle`、型パラメータを一つまたは二つ持つ操作を加えた。節の中で外側の値・型パラメータを使い、内側の節で外側の `Rigid`、定義の型パラメータ、二番目の `Rigid` をそれぞれ引数に取るラムダ、`_` を含む三つの引数の番号を確かめる。Option・Result の `try`、`return`・`match` の注釈、引数内で新しく束縛した継続の再開も含む。

通常の `generate(seed, stage)` は、変更前の HEAD の生成器と、段 1〜6・種 0〜999 の **6,000 組**について、ソースと機能別計数がすべて一致した。比較用の一時の Rust プログラムは `target/desugar-diff/generator-stability/` にある。通常の生成器の乱数源・分岐は変更していない。

実行手順は次のとおりである。

```sh
export BENITOITE_DESUGAR_DIFF_DIR="$PWD/target/desugar-diff/c4c-2"
(cd formal && lake build desugarDiff)
cargo test --test desugar_export -- --include-ignored --nocapture
formal/.lake/build/bin/desugarDiff "$BENITOITE_DESUGAR_DIFF_DIR/corpus.json" "$BENITOITE_DESUGAR_DIFF_DIR/report.json"
```

所要時間は、最終の Rust 書き出し **72.575 秒**（テスト本体 **73.87 秒**、cargo の再構築 **0.39 秒**）、Lean の比較 **1.77 秒**である。主コーパスと報告は `target/desugar-diff/c4c-2/corpus.json`・`report.json` に残した。

`formal/` の `lake build` と `lake build desugarDiff` は成功した。C4a-2 の `Surface/Lemmas/Typing.lean` の `sorry` は 1 か所のままである。`scripts/check-formal.sh` の `sorry` 検査は変更せず、依頼のとおり後続の手順を手で実行した。`cargo fmt --check` と `cargo clippy -p benitoite --all-targets -- -D warnings` は成功した。共通検査の dry-run は Rust と formal を選び、long と heap は選ばなかった。共通検査一式はこの実装担当では実行していない。

### C5 で広げるときの注意

- 表層の範囲判定とコアの対象外の印を同時に広げる。メソッド・辞書・空でない `App.dicts`・`TypeArg::Head`・高カインドの `Ty::App` は今回も対象外である。
- 辞書の引数を通常の値の環境に加えるときも、継続の印と `_` の節引数の位置は維持する。メソッドと実装の型パラメータの番号を並べ替えた後に、節の型パラメータ分のずらしを適用する。
- 操作のエフェクト引数が空であることの検査は残す。ADR 0312 の制限を外した版を試すときは、操作の値の辞書引数、操作宣言、節の `arity` を同時に広げる。現在の `arity` は辞書を含まない宣言の引数数である。
- 操作表を二重に書き出して脱糖の検査をしたことにしない。節のシグネチャ検査は操作表を使うので、型クラスと高カインドの宣言を表せるように表の型も広げる。
- プレースホルダ引数内の `try` と外側の継続への `resume` の既知の差は維持する。内側の節で新しく束縛された継続を指す再開まで除外しない。
- 本体を複製・並べ替える構成を加える場合は、ラムダのエフェクトを出力順に対応させる方式を見直す。今回のハンドラは本体、節の順序を保っている。

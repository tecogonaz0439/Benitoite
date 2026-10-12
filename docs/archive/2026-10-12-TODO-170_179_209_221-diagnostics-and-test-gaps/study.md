# 調査

項目ごとの調査を Opus 四つに任せた結果を、部として並べたものである（2026-10-12、san_benito の 44e38cbf の時点。リポジトリを変えず、小さな入力で今の診断と出力を確かめた）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。部は、A（TODO-179 の E0416 と診断の補助、TODO-170）、B（TODO-179 の表示の細部）、C（TODO-179 の実行時の報告と修正案）、D（TODO-209・221）である。再現に使った入力は保管しない。

## 調査 A: TODO-179 の E0416 と診断の補助、TODO-170 の prelude を隠す注記

2026-10-12、san_benito の 44e38cbf で調べた。リポジトリは変えていない。診断の実例は、scratchpad の `orch8/a/*.bnt` を `target/debug/benitoite check` で検査した出力である（空の `|` の行を省いた）。行番号は `crates/benitoite/src/` からの相対。

### 1. TODO-179 の 1 つ目: 本体の最後の文の E0416 の位置

#### 今のコードの事実

- `typeck/generate.rs:113`（関数の本体）は `equal(…, block.span, ReasonKind::FnBody)`、`generate.rs:699`（ラムダの `lambda_result`）は `e.body.span` を使う。TODO の行番号（113・636）のうち 636 は 699 にずれている。
- `typeck/generate.rs:735-768` の `block` は、最後でない式文にだけ `ExprStmt` の理由で `e.span()` を使う。最後の文の型はブロックの型として返り、`FnBody` の制約がブロック全体の位置で付く。
- `typeck/solve.rs:625-626` で、理由が `ExprStmt`・`FnBody` の E0401 を E0416 に変える。`solve.rs:757-776` で、`discard`（`r.span.start` に `bind _ <- ` を挿入する）を常に付け、`reassign(ctx, r.span)` は `expr_stmts` の表（鍵は式文の span、`generate.rs:744-749` で登録する）を引く。位置がブロック全体なので、最後の文の `x = 5` の表を引けない。
- E0438（`generate.rs:933-938`）も主な位置が `b.span`（ブロック全体）である。
- テストは `typeck/tests.rs:337-343` の最後でない式文（`ExprStmt`）だけ。ゴールデンは `testdata/types/discarded_value.diag.json` の 1 件（同じく最後でない式文）。

#### 今の出力（`orch8/a/e416a.bnt`、`e416b.bnt`）

```text
function f(x: Integer) -> Integer      // 最後の文 `y * 2`
error[E0416]: the value of this expression is not used
  --> e416a.bnt:2:3
 2 |   bind y <- x + 1
   |   ^^^^^^^^^^^^^^^ this has type `Integer`, not `Unit`
   = help: write `bind _ <- ...` to discard the value
 2 |   bind _ <- bind y <- x + 1          ← 構文として誤った置き換え
error[E0438]: the function can reach its end without `return`
  --> e416a.bnt:2:3                      ← 同じくブロックの先頭
   = help: add `return` with a value of type `Integer`
```

- `-> Unit` の関数の最後の文 `y = 5` も 1 行目の `bind` を指し、`reassign` の修正案が出ない（型は `Boolean` と正しく示す）。
- 注釈のないラムダの `bind m <- n * 2` / `m + 1` も `bind _ <- bind m <- …` になる。最後の文が `if … end if` の関数も、`if` の行の先頭に `bind _ <- ` を付ける。
- 戻り値の型を書いたラムダ（`lambda(n: Integer) -> Integer  n + 1`）は、E0416 と E0401（`the lambda body must match the annotated return type`）が同じ式に二つ出る。

#### 直し方（推奨）

1. `FnBody` の位置を「本体のブロックの最後の文が式文ならその式の span、そうでなければブロックの span」にする。`block` の外で `b.stmts.last()` を見る小さな補助（`body_tail_span`）を `generate.rs` に置き、113 と 699 で使う。最後の文が束縛の文・空のブロックなら型は Unit なので E0416 は出ず、位置の選び方は E0416 にだけ効く。
2. `block` で、最後の文の `x = e` も `expr_stmts` に登録しているので（`generate.rs:744` は全式文に付く）、位置を直せば `reassign` は自動で出る。
3. E0438 も同じ補助の位置へ移す（最後の文を指す）。あわせて、同じ本体に E0416（`FnBody`）を報告したときは E0438 を出さない（原因が一つで、`return` を足せば両方消える）。

#### 触れるテストの見込み

- `typeck/tests.rs`: 新しい単体テスト 1 件（関数の最後の式・束縛の後の最後の式で置き換えが `bind _ <- m + 1` になること・`-> Unit` の最後の `x = 5` で `reassign`・ラムダの最後の式）。`tests.rs:353` の E0438 の期待（2,2）は位置が変われば直す。
- ゴールデン: 変わるものはない見込み（E0416 の 1 件は最後でない式文）。`types/` に 1 件足すとよい。
- 型と凍結: `ReasonKind`（`typeck/infer.rs`、凍結した 10-05 の `file=`）は変えない。

### 2. TODO-179 の 2 つ目: 診断の補助

#### (a) E0416 で `return` を勧める

- 今: `diag/codes.rs:593-597` の E0416 は `discard`・`reassign` の二つだけ。
- 推奨: 理由が `FnBody` で、本体の戻り値の型が `Unit` でないとき、`return` の修正案（最後の式の先頭に `return ` を挿入する置き換え付き）を最初に示し、`discard` を出さない（`discard` を当てると E0438 になり遠回りになる）。戻り値の型を書いていないラムダでは、`return` を先、`discard` を後に両方示す（どちらが意図かを処理系が決められないので、02-10 の規則に合わせて `return` は文だけにするか、両方に置き換えを付けるかは R 扱いで決めればよい。推奨は「両方に置き換え」。今の `discard` も確実でないのに置き換えを付けているため）。`-> Unit` は今のまま（`discard`・`reassign`）。
- 実装: 解決の時点で、`FnBody` の理由の位置から「戻り値の型の注釈の有無と、それが Unit か」を引ける表を `Body` に持つ（`context.rs:64` の `expr_stmts` と同じ作り方）。`ReasonKind::FnBody` に欄を足すと凍結した型を変えるので避ける。型板は `diag/codes.rs` の E0416 に `return_value: "write `return` to return this value from the {what}"` のような help の鍵を足す。
- 戻り値を書いたラムダで E0401（`LambdaReturn`）が重なる件は、`FnBody` の E0416 を出したラムダでは `LambdaReturn` の E0401 を出さない、で揃えるのを推奨（小さな点）。

#### (b) E0303 の補助

今のコード: `resolve/lookup.rs:405-470`。補助は `not_reexported`、`Benitoite.String` の `length`・`slice`・`substring`・`indexOf`、`Option`/`Result` の `unwrap`・`expect`、近い名前（`resolve/suggest.rs`。レーベンシュタイン距離 2 以下、最大 3 つ。候補が一つなら置き換え付き）だけである。E0302・E0301 も同じ `similar` を使う。

今の出力（`orch8/a/e303.bnt`、`old.bnt`）:

| 書いたもの | 今の補助 |
|---|---|
| `Map.insert` | なし |
| `String.charCount`・`Float.abs`・`List.concat`・`Console.println`・`List.size` | なし |
| `Result.isErr` | `isError`（距離 2 で偶然当たる） |
| `Int.abs`（E0302） | `IO`, `Set`（誤った方向） |
| 型の `Int`（E0301） | `Set`, `Unit`。`Char`・`Bool` はなし |
| `Point.z`（利用者のレコード） | `x`, `y` |

- 表示の名前: 見出しとラベルの `{module}` は `m.name.dotted()`（`lookup.rs:405-407`）で、`Benitoite.Map`、さらに `import Benitoite.Unofficial.IO.Console` で取り込んだものも `Benitoite.IO.Console` と出る（`Unofficial` が抜け、書いた名前とも import の名前とも合わない）。TODO-179 の別の点（02-05「ソースに書いた形で示す」）と同じ箇所なので、同じ作業で、参照に書いた段（`path[..index]` の綴り）を示すよう直すのを推奨する。ゴールデン 4 件（`names/option_unwrap`・`unknown_member`・`string_length`・`modules/c11-not-reexported`）と E0330 の 2 件（`names/prelude_only_hidden`・`modules/c11-private`）の文字列が変わる。

0.0.0 の旧名の表（CHANGELOG.md の「Incompatible changes from 0.0.0」。0.0.1→0.0.2 に改名はない）:

- 同じモジュールの中の改名 15: `Console.println`/`print`/`eprintln`、`Process.args`、`String.charCount`/`charAt`/`charSlice`/`chars`/`fromChars`、`Float.sqrt`/`abs`/`ceil`、`List.concat`、`Result.mapErr`/`isErr`。
- モジュールの改名 4（E0301/E0302 で出る）: `Int`→`Integer`、`Bool`→`Boolean`、`Char`→`Character`、`IoError`→`IOError`。
- 改名したモジュールの関数 9: `Char.toInt`/`fromInt`/`isAsciiDigit`/`isAsciiWhitespace`、`Int.abs`/`min`/`max`/`floorDiv`/`mod`（`Int.mod`→`Integer.floorModulo` は意味の注意が要る）。
- 計 約 28 項目。

別名の表（評価で出た `Map.insert` などの、他言語の名前）の候補は、今の名前と突き合わせて 20〜30 項目の見込み: `Map.insert`/`put`→`set`、`Map.lookup`/`find`→`get`、`Map.has`/`containsKey`→`contains`、`Map.length`/`count`→`size`、`List.size`/`len`/`count`→`length`、`List.push`→`append`、`List.first`→`head`、`List.nth`/`at`→`get`、`List.reduce`→`fold`、`List.each`→`forEach`、`List.includes`/`has`→`contains`、`Set.insert`→`add`、`String.toUpper`/`upper`→`toUppercase`、`String.strip`→`trim`、`Option.flatMap`/`bind`→`andThen`、`Option.getOrElse`→`unwrapOr`、`Result.toOption`→`ok` など。

推奨:

1. 旧名と別名を一つの表（鍵: 標準ライブラリの完全な名前 `Benitoite.Map` と書いた名前、値: 正しい名前と種類「0.0.1 での改名」か「別名」）にし、`resolve` の新しいモジュール（`resolve/renames.rs`）に置く。E0303 では表を近い名前より先に引き、当たれば候補一つとして置き換え付きの help（`renamed: "`{old}` was renamed to `{module}.{new}` in 0.0.1"`、`alias: "use `{module}.{new}`"`）を示す。E0301/E0302 の `Int` などは同じ表のモジュールの行で示す。
2. 表の行の正しい名前が今の標準ライブラリの名前の索引にあることを確かめる単体テストを 1 件置く（改名や削除で表が古くならないように）。
3. 近い名前も表も当たらないとき、その位置で使える名前（今の `pool`）の一覧を注記で示す。標準ライブラリのモジュールの関数は最大 35 前後（`String` が最多）で、1 行に収まる。
4. 「`IO.Console.Write` を import なしで書いた」場合の `` `Benitoite.IO` has no member `Console` ``（`orch8/a/shadow4.bnt`）にも、E0302 と同じ足りない import の修正案（`import Benitoite.Unofficial.IO.Console`）を出すのを推奨（小さな点。02-04「誤りと修正案」の「足りない import の宣言」は最初の段だけを対象にしている）。
5. CHANGELOG.md の 0.0.1 の節の「`check` reports an old name … without suggesting the new one」は過去の版の記録なので変えず、Unreleased の Changed に新しい案内を書く。

#### (c) E0304・E0201・E0321 の補助

今の出力（`orch8/a/e304b.bnt`、`e201.bnt`、`e321.bnt`、`e304.bnt`）:

- `Point(1, 2)` と `Point`（値の位置）: `` `Point` is a record, not a value ``、補助なし（`codes.rs:383` の E0304 は help が空）。`Point.new(1, 2)`: E0303、補助なし。`Point { x: 1, y: 2 }`: E0212（波括弧のブロック）が 2 件と、続く行の E0201。
- `Map.empty[String, Integer]()`: `` expected a newline or the end of the block, found `[` ``、補助なし（`syntax/parser/exprs.rs:651-653` の `parse_block`。`codes.rs:173` の E0201 は help が空）。
- `import Benitoite.Http`・`import Benitoite.Unofficial.Network.HTTP`・`import Benitoite.Unofficial.Console`: 補助なし。`modules/find.rs:170-176` の `ranked_candidates` は完全な名前どうしの距離で比べるので、最後の段が合っても候補にならない。

推奨:

- E0304（レコードを値・呼び出しの位置に書いた）: help で構築の形を示す。`construct: "build a record with its field names, such as `{name}({fields})`"`。`{fields}` はレコードの宣言のフィールドから `x: …, y: …` を組み立てる。置き換えは付けない（引数の対応を名前解決では決めない）。レコードの E0303 で、書いた名前が `new`・`create`・`make`・`of`・`init` のときも同じ help を出す。E0212 で直前が大文字の名前のときの構築の案内は、構文解析器の回復が絡むので今回は外すのを推奨。
- E0201: 文の終わりで `[` に出会い、直前の字句が名前（修飾した名前を含む）のとき、help `type_arguments: "calls take no type arguments, such as `Map.empty()`; write the type on the binding (`bind m: Map[String, Integer] <- Map.empty()`). Lists are read with `List.get`"` を足す。`名前[…](` の形（直後が `(`）なら `[…]` を消す置き換えを付ける。
- E0321: 最後の段が標準ライブラリのモジュールの最後の段と（大文字小文字を区別せずに）一致するものを、今の距離の候補より先に示す。一つなら置き換え付き（`Benitoite.Http`→`Benitoite.Unofficial.Network.Http`、`Benitoite.Unofficial.Console`→`Benitoite.Unofficial.IO.Console`）。
- なお E0321 の `similar` は候補が複数のとき `note`（`find.rs:186`）、E0303 は `help` で、揃っていない。揃えるかは R で決めてよい（推奨: 両方 help）。

#### 触れるテストとゴールデンの見込み（(a)〜(c) と表示の名前）

- ゴールデン: E0303 4・E0330 2（表示の名前）、E0321 5 のうち `modules/f20-similar-import` が変わりうる、E0304 2 は今の 2 件がレコードでないので変わらない見込み。新しいゴールデンを 4〜6 件（旧名、別名、レコードの構築、型引数、import の最後の段）。
- 単体テスト: `resolve/tests.rs`（E0303・E0302 の表の補助）、`diag/render/help_tests.rs`、`typeck/tests.rs`、`modules` の E0321、構文解析器のテスト。表の突き合わせのテスト 1 件。
- 文言を変えるので `cargo run -p benitoite --example gen_skill` で `skill/references/diagnostics.md` を作り直す。`skill/references/common-mistakes.md`・SKILL.md の「`Map.insert` はない」の行は残してよい。
- 凍結した型やシグネチャの変更は不要（`DiagBuilder` の help・note の鍵を足すだけで、`codes.rs` は 10-02「型板の直し方」の範囲）。

#### 設計書で直す節

- 02-05「制約の生成」の表の「関数の本体」「ラムダ」の行か「誤りの報告と検査の継続」の修正案の並びに、本体の最後の式文の E0416 の位置と `return` の修正案、E0438 を重ねないことを書く。
- 02-10「修正案」の表に、本体の最後の式文の E0416（`return`）、E0303 の旧名と別名の表・名前の一覧、レコードの構築の形（E0304）、型引数（E0201）、import の最後の段（E0321）の行を足す。
- 02-04「誤りと修正案」の「見つからない名前」の修正案の並びに、旧名と別名の表、近い名前がないときの名前の一覧、修飾した名前の途中の段の足りない import、示すモジュールの名前は参照に書いた段とすることを足す。

### 3. TODO-170: prelude を隠したことの注記

#### 今のコードの事実

- 記録: `resolve/mod.rs:129-130` の `prelude_shadowed: NodeMap<BindingId>`（凍結した 10-04 の `file=` にある）。書くのは `resolve/lookup.rs:335-343` だけで、条件は「最初の段の名前が prelude の表にあり、別の束縛に解決し、モジュールが Entry か User」。
- 読み手: `resolve/tests.rs:425` の 1 件だけ。型検査器も診断も読まない。
- 設計書との食い違い: 02-04「名前の引き方」の最後から 2 つ目の項は「型検査器は、その参照に関わる診断に、prelude の名前を隠していることと `Benitoite.X` で prelude の側を書けることを添える」と書いたままである。TODO-170 の本文は「設計書を実装に合わせて記述を消した」とするが、消したのは 01-03 の側で、02-04 には残っている。この改造で実装するにせよしないにせよ直す必要がある。
- `Benitoite.X` は今の言語で書ける（`orch8/a/shadow2.bnt`・`shadow7.bnt` が通る。`Benitoite.Option[Integer]`、`Benitoite.Option.Some(1)`、`Benitoite.Task.all(…)`）。根の中で引けるのは prelude のモジュール（27 個: `Integer`〜`Task`・`TaskGroup`・`IO`・`Assert`・`Bytes`・`NetworkError` など）と `Unit`・`State` だけで、`Path`・`Time`・`Json` などの非公式のモジュールは prelude でないので、そもそも隠す対象でない。
- 警告の仕組み: 02-10「警告の扱い」。警告は `check` では終了状態 0、`--deny-warnings` で誤り（終了状態 2）。警告を抑えるオプションとソースの書き方は設けない。名前の区分の警告は `W03nn`（`@deprecated` の参照）がある。

#### 今の出力

```text
record Task                          // orch8/a/shadow6.bnt
  title: String
...
  bind h <- Task.spawn(work)        // （実在しない名前の例。Task.all でも同じ形）
error[E0303]: `Task` has no member `spawn`
   |                  ^^^^^ not found in `Task`         ← 注記なし

data/record Result …                // orch8/a/shadow3.bnt
  bind r: Result <- Benitoite.Result.Ok(1)
error[E0401]: mismatched types
   ... expected `Result`, found `Result[Integer, _]`    ← 同じ名前の二つの型。注記なし
```

#### 案

- 案 A（推奨）: 注記だけ。警告にしない。添える対象は二つに絞る。
  1. 名前解決の E0303・E0330 で、最初の段が隠した参照のとき（`lookup.rs:335` の条件と同じ）。注記「`Task` here is the record declared in this file, which hides the prelude module `Task`」と、宣言の位置の副ラベル。隠された prelude の束縛がその名前を持つなら、`Benitoite.` を前に挿入する置き換え付きの help（`Benitoite.Task.all`）。
  2. 型検査の型の不一致（E0401 と、型引数の数の E0410）で、期待と実際の型に、利用者のモジュールで宣言した型のうち名前が prelude の型と同じものが含まれるとき。注記と、`Benitoite.Result` で prelude の型を書けることの help（置き換えなし）。判定は表示する型の ADT から行い、`decls.resolved` の標準ライブラリの名前の索引（`Benitoite.<名前>.<名前>`）を引く。参照の表は不要だが、1 の判定は記録の条件と同じなので、`prelude_shadowed` を読む形にしてもよい。
  - 理由: 型や記録の名前に `Task`・`Pair`・`Result` を使うのは正当であり、警告にすると、抑える手段がない（02-10）ので書くたびに出続け、`--deny-warnings` で通らなくなる。誤りが出たときだけ添えれば、正しいプログラムには何も出ない。
- 案 B: 宣言の位置に W03nn の警告を出す（隠すたびに 1 件）。上の理由で推奨しない。
- 案 C: 何もせず、02-04 の記述を消して TODO-170 を「行わない」で閉じる。`prelude_shadowed` はテストだけの表として残るか、test-audit の観点で表ごと消す（凍結した型の欄を消すことになる）。

#### 触れるテストの見込み（案 A）

- 新しいゴールデン 2 件（`names/` に E0303、`types/` に E0401）。既存のゴールデンは変わらない見込み（今のゴールデンに prelude を隠すものはない。`names/prelude_only_hidden` は非公開の名前の例で別物）。
- `resolve/tests.rs:425` は残し、注記の単体テストを 1〜2 件。型検査の側に 1 件。
- `diag/codes.rs` の E0303・E0330・E0401・E0410 に note・help の鍵を足し、gen_skill で作り直す。
- 凍結した型の変更は不要（案 C で表を消すときだけ 10-04 の `Resolved` の欄を消す）。

#### 設計書で直す節

- 02-04「名前の引き方」の最後から 2 つ目の項（実装に合わせて、添える診断を E0303・E0330 と型の不一致に絞った書き方にする。案 C なら後半の文を消す）。
- 02-05「誤りの報告と検査の継続」の修正案の並びに、prelude を隠した型の不一致の注記を足す。
- 02-10「修正案」の表に 1 行。

### 4. 設計者に決めてもらう点

1. TODO-170: 注記だけにするか（案 A、推奨）、警告にするか（案 B）、行わないか（案 C）。案 A なら添える対象を「E0303・E0330」と「型の不一致」に絞ってよいか。
2. TODO-179 (b): 近い名前も旧名・別名の表も当たらないときに、そのモジュール（型）で使える名前の一覧を注記で全部示すか（推奨: 示す。最多の `String` で約 35 個の 1 行）。
3. TODO-179 (b): 別名の表に何を載せるか（推奨: 評価で実際に出た `Map.insert` などと、上に挙げた 20〜30 項目。旧名 約 28 項目とあわせて約 50〜60 行）。旧名の help に「0.0.1 で改名」と版を書くか。
4. E0303・E0330 のモジュールの名前を、参照に書いた形（`String`、`Console`）で示す方向でよいか（TODO-179 が方向を決めているが、`Benitoite.IO.Console` が `Unofficial` を落とす実例が加わった）。

推奨どおりでよい小さな点（R）: E0438 を最後の文の位置にし E0416 と重ねない、ラムダの `LambdaReturn` の E0401 を重ねない、注釈のないラムダでは `return` と `discard` の両方に置き換えを付ける、`IO.Console` の途中の段の足りない import、E0321 の候補の help と note の揃え、E0212 のレコードの構築の案内は外す。

## 調査 B: TODO-179 の診断の表示の細部（44e38cbf で確かめた）

パスは `crates/benitoite/` からの相対で書く。実例は `target/debug/benitoite check` で出した。リポジトリは変えていない。試した `.bnt` は `scratchpad/orch8/b/` にある。

凍結した型・シグネチャ（`docs/archive/2026-10-09-implement-first-release/10-interfaces/`）を変える必要がある点はない。`EffectSet`（10-05）と `ConstValue`（10-05）には欄を加えない案にした。`Source::line_text`（10-01）は意味を変えるがシグネチャは変えない（後述の 5(d)）。

---

### 1. E0303・E0330 がモジュールを `Benitoite.String` と示す件

#### 今のコード
- `src/resolve/lookup.rs:379-404`（E0330）は `.arg("module", self.modules.get(module)?.name.dotted())`。
- `src/resolve/lookup.rs:406-409`（E0303）は、モジュールなら `m.name.dotted()`、型・レコードなどなら `binding.name` を使う。
- 一方で修正案の文は、`src/diag/codes.rs:374-380` の表に書いた固定の `String.byteLength` などと、`{module}.unwrapOr` を使う。

#### 今の出力
| 書いたもの | 見出しとラベル | 修正案 |
|---|---|---|
| `String.length(s)` | `` `Benitoite.String` has no member `length` `` | `` use `String.byteLength` `` |
| `Benitoite.String.length(s)` | 同上 | 同上 |
| `import Benitoite.String as S` の後に `S.length(s)` | 同上（`S` と書いたのに `Benitoite.String`） | `String.byteLength`（`S` と食い違う） |
| `Option.unwrap(x)` | `` `Benitoite.Option` has no member `unwrap` `` | `` use `Benitoite.Option.unwrapOr` `` |
| `import Util.Text as T` の後に `T.hidden()` | `` `hidden` is not public in `Util.Text` `` | `` mark `hidden` as `public` in `Util.Text` ``（編集は Text.bnt の宣言を指す） |
| `import Util.Text as T` の後に `T.shwn()` | `` `Util.Text` has no member `shwn` `` | 近い名前 `shown` |

#### 直し方の案
- **案 A（推奨）**: 見つからない段の前までを、ソースに書いた段の文字列（`path[..index]` を `.` でつないだもの）で示す。`String.length` は `String`、`Benitoite.String.length` は `Benitoite.String`、`S.length` は `S`、`A.B` は `A` になる。02-05「ソースに書いた形で示す」と一致し、モジュールでない型（`Shape.Circl`）も同じ規則で示せる。`length`・`slice`・`index_of` の修正案の文も `` `{module}.byteLength` `` に変える（`S.byteLength`、`Benitoite.String.byteLength` になる）。`unwrap` の修正案の文は、`{module}` を変えるだけで `Option.unwrapOr` になる。
  - E0330 の `make_public` の修正案（「mark `hidden` as `public` in `{module}`」）は、宣言のあるファイルを直す案内なので、本来のモジュールの名前（`Util.Text`）のままにする。そのために、表の文に別の引数（例: `{declared_in}`）を加える。見出しの `{module}` はソースに書いた形にする。
  - 判定の `m.name.dotted() == "Benitoite.String"` などは本来の名前のままでよい（表示だけ変える）。
- 案 B: 本来の名前のうち、prelude の名前だけを短くする（`Benitoite.String` → `String`）。別名の `S` を示せないので、案 A より劣る。

#### 触れるテスト・ゴールデン
- ゴールデン 4 件: `testdata/names/string_length.diag.json`（3 つの診断）、`names/option_unwrap.diag.json`（2 つ）、`names/unknown_member.diag.json`、`names/prelude_only_hidden.diag.json`。`modules/c11-not-reexported`・`c11-private` は既にソースの形と一致し、変わらない。
- 単体テスト（`resolve/tests.rs`、`diag/render/help_tests.rs`）は部分の一致で確かめているので壊れない見込み。別名（`import ... as S`）と `Benitoite.String.length` の場合のテストを加える。
- 表の文を変えるので、`cargo run -p benitoite --example gen_skill` で `skill/references/diagnostics.md` を作り直す。

#### 設計書
- 02-04「誤りと修正案」（212-213 行の「見つからない名前」「公開されていない名前」の項目）に、「見つからなかった段の前までを、ソースに書いた形（別名を含む）で示す。`public` を付ける修正案は宣言したモジュールの名前で示す」と書く。02-05 369 行の規則は型についてのものなので、02-04 に書くのがよい。

#### 設計者に決めてもらう点
- 案 A でよいか。特に、別名 `S` で書いたときに見出しを `S` と示すこと（本来の名前は出なくなる）と、E0330 の `public` の修正案だけを本来の名前で示すこと。

---

### 2. 作業 C05 の確認で残した細部

#### (a) `IO.All` の展開がラベルに出る
- **今のコード**: `uses` に `IO.All` を書いたかは、`Scheme.wrote_io_all`（`src/types/mod.rs:176-177`、設定は `typeck/decls.rs:429`）が宣言の一番外の `uses` についてだけ覚えている。使い手は W0501（`typeck/effects/declarations.rs:136`）だけである。引数の型の中の `function() -> Unit uses IO.All` のような入れ子の関数の型は、`EffectSet`（`types/mod.rs:46-51`。10-05 で凍結）に展開した名前しか持たず、書いたことを覚えていない。型の表示は `src/types/mod.rs:497-528` の `show_ty` が、集合の名前を一つずつ並べる。
- 02-05 151 行は「宣言の型は、`uses` に `IO.All` を書いたかどうかを、警告と診断のために覚えておく」と書くが、今は診断の表示には使っていない。
- **今の出力**（`testdata/effects/outermost_only.diag.json`）: `expected List[function() -> Unit uses State, Console.Write, Console.Read, File.Read, File.Write, Process.Run, Process.Exit, Process.Environment, Clock.Time, Random.Generate], found ...`。`effect_var_rigid.diag.json` も同じ。
- **案 A（推奨）**: 表示の段でまとめる。`show_ty` で、集合が `in_io_all` の項目（`types/builtin.rs` の表）をすべて含むとき、それらを `IO.All` 一つに置き換えて先頭に置き、残り（ネットワーク・利用者のエフェクト・エフェクト変数）を続ける。凍結した型を変えずに済み、入れ子の関数の型にも効く。欠点は、10 個を一つずつ書いた場合も `IO.All` と示すことだが、同じ集合を表すので害は小さい。
- 案 B: `EffectSet` に「`IO.All` を書いた」印を加える。10-05 の凍結した型を変え、等値（`PartialEq`・`Hash`）の扱いも決める必要があるので勧めない。
- `Ty::show` の使い手は、型検査の診断（`typeck/solve.rs:564`）と脱糖の `ir/desugar/decls.rs:346,357`（実装の対象の型の名前）である。後者が関数の型を示すことはない見込みだが、実装のときに確かめる。
- **ゴールデン**: 2 件（`effects/outermost_only`、`effects/effect_var_rigid`）。展開した一覧を期待する単体テストはない。まとめる場合とまとめない場合（9 個だけのとき）の単体テストを `types/mod.rs` の tests に加える。
- **設計書**: 02-05 151 行を、今の実装に合わせて直す（「宣言の一番外の `uses` に書いたかを W0501 のために覚える。診断で型を示すときは、`IO.All` を展開した集合をすべて含むエフェクトの集合を `IO.All` とまとめて示す」）。369 行の「ソースに書いた形で示す」の後にも一文を加える。
- **設計者に決めてもらう点**: 10 個を一つずつ書いた場合も `IO.All` と示してよいか（案 A の前提）。

#### (b) E0211 の edits が `foreign.rs` の回収の経路にない
- **今のコード**: 二項・前置の位置の経路（`syntax/parser/foreign.rs:83-99` の `operator`。`exprs.rs:56-64,110,420` から呼ぶ）は、置き換えを付ける。前置の `!done` も `exprs.rs:420` で `not ` の置き換えが付く。置き換えのない経路は、`foreign.rs:178-191`（`report_unclaimed` を通る、構文の回復で読み飛ばした記号）だけである。
- **今の出力**: `== 1`（文の頭）、`bind x: Integer != 3 <- 1`、`case !x -> ()`、`lambda(a && b)`、`[1, 2] !` で、help の文だけが出て edits は空。`(1 ==)` と `return !done` は置き換えが付く。
- **推奨: 直さない**。この経路は、記号が演算子として置けない位置にある場合であり、記号を語に置き換えても誤りが残る（`= 1`、`case not x`、`lambda(a and b)` はどれも誤り）。02-10「修正案」の「置き換えは、それを当てれば誤りがなくなると処理系が決められるときだけ付ける」に今の振る舞いが合っている。`foreign.rs:178` の直前に、この理由を書いたコメントを置くだけにする。help の表の `fix [... not ...]` は、二項・前置の経路で置き換えを付けるので、そのままでよい。
- **ゴールデン**: 0 件。
- **設計者に決めてもらう点**: この理由で項目 (b) を閉じてよいか。

#### (d-1) `pattern_arity` の構成子が修飾なし
- **今のコード**: `typeck/generate.rs:1276-1283`（E0412）は `.arg("name", p.path.last()...)` で最後の段だけを示す。同じ関数の E0413（`generate.rs:1257-1262`）は、パスの全部を `.` でつなぐ。
- **今の出力**: `case Shape.Rect(width)` で「the constructor `Rect` has 2 field(s) but the pattern has 1」。
- **推奨**: E0413 と同じく、書いたパスを `.` でつないで示す（`Shape.Rect`）。つなぐ処理は小さな補助の関数にまとめ、E0413 と共有する。
- **ゴールデン**: 1 件（`patterns/pattern_arity.diag.json`）。表の文は変わらないので gen_skill は不要。設計書の変更は要らない（02-05 の「ソースに書いた形」に合わせる直し）。

#### (d-2) `uses_then_bracket` の E0209 の位置が `[` の 1 文字
- **今のコード**: `syntax/parser/types.rs:212-218` の `parse_uses` は、`p.peek().span`（`[`）を主な位置にし、help の文だけを付ける。名前解決の同類の診断 E0316（`resolve/lookup.rs:727-774`）は、エフェクトとして読んだ名前を主な位置にし、ラベル「read as part of the `uses` list」と、関数の型の先頭に `(`、直前のエフェクトの後に `)` を入れる置き換えを付ける。
- **今の出力**: `function(function() -> Unit uses Console.Write, List[Integer]) -> Unit` で、主な位置は 4 行 76 桁の `[` の 1 文字、ラベルは空、edits は空。
- **推奨**: 主な位置を、エフェクトとして読んだ名前から `]` まで（`List[Integer]`）にし、ラベルを E0316 と同じ趣旨にする。置き換えも E0316 と同じ形で付ける（関数の型の先頭に `(`、直前のエフェクト `Console.Write` の後に `)`）。これには `parse_uses` に囲む関数の型の開始位置（`Option<usize>`）を渡す。型の位置から呼ぶ `types.rs:175` だけが `Some` を渡し、宣言の `uses`（`decls.rs:252`）とラムダの `uses`（`exprs.rs:893`）は `None` を渡して、今の help の文だけにする。`parse_uses` は `pub(super)` で、凍結の対象ではない。02-10 の修正案の表（「`uses` の並びにエフェクトでない名前を書いた」「置き換え あり」）にも合う。
- **ゴールデン**: 1 件（`syntax/uses_then_bracket.diag.json`）。単体テスト `syntax/parser/mod.rs:1373-1376` はコードだけを見ている。置き換えを当てると誤りが消えることを確かめるテストを加える。ラベルの文を表（`codes.rs:196`）に加えるので gen_skill で作り直す。
- **設計書**: 02-03 201 行の「`uses` を持つ関数の型を括弧で囲むよう示す」に、位置（読んだ名前と型引数）と置き換えを付けることを加える。

---

### 3. 定数の鍵の文の Debug 表記と `bound_failure` の文字列

#### 今のコード
- `typeck/consts.rs:677-700` の `key_text` は、数・文字列・文字・真偽値を `value_text` で、`()` を `"()"` で書く。構成子は名前だけ（引数を捨てる）、`List`・`Map`・`Set` は `format!("{v:?}")`（Rust の Debug 表記）である。使い手は E0436（`consts.rs:477-481`）と W0403（`consts.rs:891`）。
- `typeck/solve.rs:1100-1107` の `bound_failure` は、許す型の一覧を ``format!("`{}`", d.name)`` と `", "` で組み立てて `{allowed}` に入れる。英語の文ではなく記号だけだが、later-issues の 6 (c) が `text` へ移すよう求めている。

#### 今の出力（`Set.fromList([...])` に同じ値を二つ書いた）
| 値 | 今の見出し |
|---|---|
| `[1, 2]` | `` the key `List([Integer(1), Integer(2)])` appears more than once `` |
| `Set.fromList([1])` | `` the key `Set([Integer(1)])` `` |
| `Option.Some(1)` | `` the key `Some` ``（引数が落ちる） |
| `Pair(1, "x")` | `` the key `Pair` `` |
| `Color.Rgb(1, 2)` | `` the key `Rgb` `` |
| `"a b"` | `` the key `a b` ``（引用符がない） |
| `"a\nb"` | 見出しの中に生の改行が入り、2 行に割れる |
| `1`、`'x'`、`()` | `1`、`x`、`()` |

#### 直し方の案（推奨）
- `key_text` を、`Show.show` と同じリテラルの形で書く関数に置き換える。テストの実行器の値の表示（`runtime/assert.rs:278-300` の `text` と `quoted`。06-04「結果の報告」）と同じ形にする。文字列は `"a\nb"`、文字は `'x'`、構成子は `Option.Some(1)`・`Color.Rgb(1, 2)`、組は `Pair(1, "x")`、リストは `[1, 2]`、集合は `Set.fromList([1])`、写像は `Map.fromList([Pair(1, "a")])` と書く。文字列のエスケープは `runtime::assert::quoted`（`pub(crate)`）を使う。改行と制御文字が逃がされるので、見出しが割れる問題も消える。値は `Vec` の積み重ねで辿る（AGENTS.md「再帰の深さ」。同じファイルの `compare` と同じ書き方）。
- 記号の表（`[`、`Set.fromList([`、`, ` など）は、`runtime/assert.rs` の `mod text` と共有するか、`typeck/text.rs` に写す。共有したほうが表示の食い違いを防げる。
- 長い値は、06-04 と同じく上限で切って `…` を付けるか決める（推奨: 診断の見出しなので、上限で切る）。
- `bound_failure` の一覧の組み立ては `typeck/text.rs` に ``code_list(names) -> String``（`` `A`, `B` `` の形）を置いて呼ぶ。出力は変わらない。

#### 触れるテスト・ゴールデン
- ゴールデン 0 件（鍵の文を持つゴールデンは `warnings/c11-duplicate-keys.diag.json` などの整数の `1` が 4 件だけで、変わらない）。
- `typeck/consts.rs` の tests に、文字列（改行を含む）・構成子・リスト・集合の重複の見出しを確かめるテストを加える。
- 表の文は変えないので gen_skill は不要。

#### 設計書
- 02-05「定数」か W0403・E0436 の説明の箇所に、「鍵は `Show.show` と同じ形で示す」と一文を加える（実装のときに節を決める）。

#### 設計者に決めてもらう点
- 鍵を `Show.show` の形（文字列に引用符を付ける）で示すこと。今の整数の表示は変わらないが、文字列の鍵は `` `"a b"` `` のように引用符が二重になる。

---

### 4. E0507 の注記 `state` を利用者の関数に付けている件

TODO-179 の見出しの文「利用者の関数にも付ける」は、later-issues の 10 と項目の本文（「モジュールが Stdlib・Prelude のときだけ付ける」）とは逆の意味に読める。later-issues の 10 によると、今は利用者の関数にも付けており、組み込みの関数だけに絞るのが求められている。以下はこの読み方で書く。

- **今のコード**: `typeck/effects/handle.rs:52-61` は、節の名前の宣言の型のエフェクトに `State` があれば、宣言したモジュールを見ずに `note("state")`（「`State` has no operations and cannot be handled」）を付ける。
- **今の出力**: `function bump(r: Reference[Integer]) -> Unit uses State` を `case bump(r) -> ...` と書くと、E0507 に注記「`State` has no operations and cannot be handled」が付く。`case plain()`（`State` なし）には付かない。`case Reference.set(r, v)` には付く。利用者の関数では、`State` を処理しようとしたのではなく、操作でない関数の名前を書いただけなので、この注記は話がずれる。
- **推奨**: 束縛のモジュールの種類（`resolve::Binding.module` → `ModuleTable` の `ModuleKind`）が `Prelude`・`Stdlib` のときだけ付ける。`typeck/decls.rs:171` と `consts.rs:940` が同じ判定を書いている。
- **ゴールデン**: 0 件（注記のあるゴールデンは `effects/c11-nonoperation.diag.json` の `Reference.get` だけで、変わらない）。`typeck/effects/tests.rs:254-260` に、`uses State` を持つ利用者の関数では注記が付かないことを確かめる場合を加える。
- **設計書**: 02-05 には E0507 の注記についての記述が見当たらない（02-10 96 行に「`State` を型に持つ関数など」とあるだけ）。直す必要はない見込みで、書くなら 02-05 のハンドラの検査の箇所に「組み込みの関数のときだけ」と一文を加える。
- **設計者に決めてもらう点**: 見出しの文の向き（組み込みの関数だけに絞る、で合っているか）。

---

### 5. 診断の表示の小さな点

#### (a) `resolve/tests.rs` の期待が「notes か helps のどちらか」
- 今は `resolve/tests.rs:516-529`（項目の 521-532 から移っている）。`notes` と `helps` のどちらかに文字列があれば通る。E0303 の `length`・`unwrap` の案内は help、E0314 の `uses_only` は note（`resolve/lookup.rs:263`）である。
- **推奨**: 表の各場合に、期待する種類（`Note`・`Help`）を加え、その種類だけを調べる。ゴールデン 0 件。設計書の変更なし。

#### (b) JSON の `trace` を `waiting` のときにも書く
- `diag/render.rs:304-307` は `diag.trace` が `Some` のときだけ `trace` などを書き、`308-323` は `waiting` が空でなければ `waitingTasks` を書く。02-10 319 行は、行き詰まりの報告で `trace` と `taskOrigins` を空の配列にして書くとする。
- 今 `waiting` を作るのは `runtime/report.rs:450-478` の `deadlock_diagnostic` だけで、必ず `trace` を `Some(空)` にするので、今の出力は 02-10 どおりである（`testdata/concurrency/c12-deadlock.diag.json`）。食い違いは、作る側の約束にだけ頼っている点である。
- **推奨**: 描画の側で、`waiting` が空でなく `trace` が `None` のときも、空の `trace`・`traceOmitted: 0`・空の `taskOrigins` を書く（02-10 の規則を描画の段で守る）。単体テストを `diag/render` の tests に一つ加える。ゴールデン 0 件。設計書の変更なし。

#### (c) ソースの表にないファイルの edit に `null` を書く
- `diag/render.rs:879-883` の `append_json_edit` は、ファイルが表にないと `null` を書く。02-10 213 行は、`edits` の要素を `file`・`start`・`end`・`replacement` を持つものとし、`null` を許していない。今の診断は、どれも表にあるファイルを指すので、実際には起きない見込みである。
- **推奨**: 一つの修正案の置き換えのうち一つでもファイルが表になければ、その修正案の `edits` を空の配列にする（文は残す）。置き換えの一部だけを当てさせないためである。文章の形式の側も同じ扱いにそろえる。単体テストを一つ加える。ゴールデン 0 件。設計書の変更なし（02-10 にすでに合う）。

#### (d) `line_text` が 1 行目の BOM を除かない（再現した）
- `base/source.rs:110-127` の `line_text` は 1 行目の先頭の BOM を含めて返す。`line_col`（`source.rs:74-105`）は BOM を列に数えない（02-02 89 行のとおり）。描画（`diag/render.rs:351-384` の `prepare_label`）は、行の内容を `line_text` で、印の字下げを `line_start_offset`（行の先頭 = 0）からのバイトの位置で求める。
- **再現**: `printf '\xef\xbb\xbffunction main() -> Unit uses Consle.Write\n...'` の E0302 で、`-->` の行と JSON の桁はどちらも 30 で正しい。しかし抜粋の行には BOM（バイト `357 273 277`）がそのまま出て、`^` の字下げが BOM のない同じファイルより 1 桁右にずれる（端末では BOM の幅が 0 なので、印が `Consle` の 1 文字右から始まる）。
- **推奨**: `line_text` が 1 行目の先頭の BOM を除いて返すようにし、`prepare_label` は 1 行目で BOM があるとき行の先頭の位置に BOM の長さ（3）を足す。BOM の長さは `source.rs` の非公開の定数か、描画の側の非公開の補助で求め、公開の API は増やさない。`line_text` の `///` に「1 行目の先頭の BOM は含めない」と書く。シグネチャは変わらないが、10-01 の一覧にある関数の意味が変わることは記録しておく。
- **テスト**: `base/source.rs` の tests に BOM 付きの `line_text`、`diag/render` の tests に BOM 付きの抜粋の字下げを加える。ゴールデン 0 件（BOM で始まるゴールデンはない。`lexical/bom_in_middle.bnt` はファイルの途中の U+FEFF で、別の扱い）。
- **設計書**: 02-10「文章の形式」の抜粋の説明に、「1 行目の先頭のバイト順マークは抜粋に示さない」と一文を加える（02-02 89 行の列の数え方と合わせる）。

---

### まとめ: ゴールデンの変更の見込み

| 点 | ゴールデン | gen_skill |
|---|---|---|
| 1 | 4 件（names/ の 4 ファイル、7 つの診断） | 要（E0303 の文、E0330 の引数） |
| 2(a) | 2 件（effects/outermost_only・effect_var_rigid） | 不要 |
| 2(b) | 0 件（直さない） | 不要 |
| 2(d) pattern_arity | 1 件 | 不要 |
| 2(d) E0209 | 1 件 | 要（ラベルの文） |
| 3 | 0 件 | 不要 |
| 4 | 0 件 | 不要 |
| 5(a)〜(d) | 0 件 | 不要 |

## 調査 C: TODO-179 の診断の表示の 8 点（san_benito 44e38cbf）

再現に使った入力は scratchpad の `orch8c/` に置いた（`dup4.bnt`・`task3.bnt`・`ret.bnt`・`rigid.bnt`・`alias*.bnt`・`bidi.bnt`・`esc\x1b[31mdir/` など）。リポジトリのファイルは変えていない。凍結したシグネチャ（10-interfaces）を変えずに直せる。ただし 2 の案 B だけは、凍結した `FaultThread` に値を一つ加える。

### 1. コード生成の制限の診断の重複

#### 事実
- `bytecode/codegen/mod.rs:230-275` の `finish` は、原型ごとに L0101〜L0104 を調べる。名前と位置には `fg.def.name` と `fg.def.span` を使う。
- ラムダ・`handle` の本体・節・`lazy` の原型は `emit.rs:1264` の `FnGen::new(fg.def, boundary)` で作られる。`def` は外側の定義のままなので、内側の原型の診断も外側の関数の名前と宣言の位置を示す。
- プログラム全体の表（`tables.rs:65-75`）は `limit_keys` で重複を除く。原型ごとの検査は除かない。

#### 再現（再現した）
`gen.py` は、関数の本体とその中のラムダの両方に、異なる定数 70,000 個を釣り合った `+` の木（入れ子の深さ約 34）で並べた入力を作る。`run` は、名前も位置も同じ診断を二つ出した。

```
error[L0102]: the function `f` has too many constants
  --> dup4.bnt:1:1
   = note: a function can have at most 65536 constants; split it into smaller functions
error[L0102]: the function `f` has too many constants      ← 同じものがもう一つ
```

- 文の並べ方や長いリストのリテラルでは作れない。どちらも入れ子の上限（E0208、1000）に先に当たる。釣り合った木なら作れる。
- `check` はコード生成を行わないので、この診断を出さない（02-07・06-01 の記述どおり）。

#### 別に見つけた点（小）
L 系の診断だけで終わるとき、件数の行（`error: could not run … due to N previous errors`）が出ない（`cli/mod.rs:611-616` は `write_report` を回して `EXIT_CHECK` で終える）。02-10 は L 系を「検査の誤りと同じ文章の形式で書く」とし、件数の行は「最後に」書くとしている。件数の行を書くかを、この改造で合わせて決めるとよい。

#### 直し方の案
- **案 A（推奨）**: `finish` で `(code, def の位置)` を `limit_keys` に入れ、同じ定義では一度だけ報告する。02-07 の「原型の関数ごとに一つ」を「定義ごとに一つ」と読む書き方に揃える。変更が最小で済み、文言も変わらない。
- 案 B: 内側の原型では、原型の位置（`body_proto` の `span`、ラムダなら `lambda` の位置）を主な位置にする。分けるべき場所が正確に分かる。一方で、文言の「the function `f`」を「a lambda in `f`」などに変える必要があり、文言の方針に関わる。

#### `case_length` の exact の不変条件
`ir/decision.rs:1212-1218` は、exact を必ず `0..at_least` の全長さで昇順に作る。後の処理で exact の腕を消す箇所もない。したがって、`emit.rs:822-846` が最後の腕の比較を省く前提は成り立っている。ただし、この前提を書いた文が `ir/lower_ir.rs:57` の doc に「`len` の昇順。どれも `at_least` より小さい」としかない。推奨は次の二つである。
- doc に「`0..at_least` のすべての長さを一つずつ持つ」と書き足す。
- `case_length` の先頭に、`exact.len() == at_least` と `a.len == i` の確かめを置き、外れたら `InternalError` を返す（数行で済む）。

#### 10-07 の 16 ビットの上限の書き方の揺れ
- 原型ごとの表: `> 65536` で拒む。つまり 65,536 項目まで許す。
- プログラム全体の表: `tables.rs:62` が `>= 65536` で拒む。つまり 65,535 項目までしか許さない（L0105〜 の注記も「at most 65535」）。
- 16 ビットの番号は 65,536 項目まで収まるので、全体の表は 1 項目だけ控えめになっている。10-07 自身も、原型ごとは「16 ビットに収める」、全体は「65536 項目以上で拒む」と書き分けている。
- 推奨: 振る舞いは変えない。02-07「処理系の制限」の表に、上限の数（原型ごと 65,536・レジスタ 65,535・全体 65,535）を明記する。揃える場合は全体の判定を `> 65536` にし、L0105〜L0111 の注記の数を直す。

#### テスト・設計書・決めること
- テスト: `codegen/tests.rs` に、定義とラムダの両方が上限を超える場合を 1 件加える（`over_limit_program` を流用）。ゴールデンは 0 件。
- 設計書: 02-07「処理系の制限」、02-10「処理系の不具合と処理系の制限の報告」。
- 決めること: 案 A と案 B のどちらにするか。L 系の診断に件数の行を書くか。

### 2. 処理系の不具合の報告

#### 事実と再現（再現した）
- `BENITOITE_DEV_PANIC=check` と `=run` で、注記の `BENITOITE_DEV_PANIC=check`（`message`）と `panic: BENITOITE_DEV_PANIC=check at …`（panic の内容）が二重に出る。
- 原因は呼び出し側にある。`pipeline.rs:128-133`・`cli/mod.rs:404`（`write_tool_panic`）・`cli/mod.rs:557/577/602`・`run.rs:366-401` が、どれも `&panic.message` と `Some(&panic)` を両方渡す。
- `runtime/report.rs:232-293` の `internal_diagnostic` は、スレッドの注記（"the panic occurred in the {thread} thread"）を、panic がないとき（`Stop::Internal`、"missing interrupt source" など）にも書く。report.rs:1305 のテストは、この振る舞い（注記 4 件）を固定している。02-10 は「Rust の panic であればその内容と起きたスレッド」としており、食い違う。
- スレッドの種類の固定: `write_internal`（`cli/mod.rs:408-423`）と `write_tool_panic`（`cli/mod.rs:388-406`）は、`FaultThread::Stage`（"compiler"）に固定している。
  - `fmt`・`test`・`skill` の本体（`cli/tools.rs:38-51`）は主スレッドで動くので、`BENITOITE_DEV_PANIC=tool benitoite fmt` は「the panic occurred in the compiler thread」と出る（確かめた）。
  - `cli/mod.rs:577` の外側の `Err(panic)` も主スレッドの panic である。
  - 段のスレッドの中の panic（557・602）は Stage で正しい。
- `run.rs` の置き換え（要確認の件）:
  - `run.rs:376-386` は、`rt.worker_bug` があれば、VM の panic の報告を作業用のスレッドの報告で置き換える。`worker_bug` を書くのは VM のスレッドだけ（`vm/dispatch/tasks/io.rs:665-668`）で、VM が panic した後は書かれない。したがって、両方があるときは作業用のスレッドの不具合が先に起きている。先の不具合を残す結果になるので、実害は小さい（VM の panic の記録だけが失われる）。
  - `run.rs:389-402` の書き出し用のスレッドの panic は、VM の panic の報告を無条件に置き換える。VM の panic が先なら、先の不具合が消える。

#### 直し方の案（凍結した `internal_diagnostic` のシグネチャは変えない）
1. `internal_diagnostic` は、`panic` が `Some` のとき、スレッドの注記と panic の注記を書き、`message` が `panic.message` と等しければ `message` の注記を書かない。`panic` が `None` のときは、スレッドの注記を書かない。呼び出し側を直す方法（panic のときは `message` に "" を渡す）より漏れがない。
2. 主スレッドの panic: `write_internal` と `write_tool_panic` に `FaultThread` を引数で渡す（どちらも非公開の関数）。ツールの本体と外側の境界の値は二案ある。
   - **案 A（推奨）**: `Stage` の呼び名 `"compiler"` を、主スレッドも含む名前（例 `"main"`）にするか、02-09・02-10 の「検査の段」に主スレッドを含めると書く。凍結した型は変えない。
   - 案 B: `FaultThread::Main` を加える（10-13 の凍結した enum の変更）。
3. 置き換え: `end` がすでに `EndKind::Internal` なら置き換えず、後の不具合の報告を `reports` に加える。報告は二件になる。推奨は「先の報告を残し、後の報告を加える」である。

#### テスト・設計書・決めること
- テスト: `runtime/report.rs` の 2 件、`tests/cli_process.rs` の不具合の報告の確かめ（注記の行数を見ていれば数件）。ゴールデンは 0 件。
- 設計書: 02-10「処理系の不具合と処理系の制限の報告」（スレッドは panic のときだけ書く、不具合が複数のときの扱い）、02-09「panic 境界」（主スレッドの扱い）。
- 決めること: 主スレッドの呼び名（案 A・案 B）。不具合が複数のとき両方を報告するか。

### 3. 実行時エラーの primary がタスクの起動の位置を指す

#### 事実
- `vm/dispatch/tasks.rs:552-561` は、タスクの最初の枠の `call_site` に、起動した命令（`at`）を入れる。同じ値を `task.spawner` にも入れる。
- `runtime/report.rs:338-345` の `user_location` は、止まった命令が利用者のソースになければ、全ての段の `call_site` から利用者のソースの最初のものを探す。最も外側（タスクの最初の段）も含めて探す。
- 一方、呼び出しの履歴（`call_trace`、report.rs:359-383）は、最も外側の段の位置を出さない。02-08「実行時エラーの情報の記録」の 2 と、ADR 0325（テスト `r41-inherited-non-tail` の関門）も、子の最初の段は位置なしとする。

#### 再現（再現した）
`task3.bnt` は、タスクの関数として操作 `ask` をそのまま渡す（`TaskGroup.spawn(group, ask)`）。外側の節は `resume` で終わらない（R0502）。報告は次のとおりである。

```
runtime error[R0502]: the handler for `Ask.ask` cannot be used in a task
  --> task3.bnt:10:17              ← 親のタスクの TaskGroup.spawn の呼び出し
   = note: call trace (innermost first):
             Ask.ask
   = note: in a task started by (innermost first):
             TaskGroup.spawn at task3.bnt:10:17
```

- primary が、起動の履歴と同じ親のタスクの位置を指している。
- ラムダで包むと（`task4.bnt`）、primary はラムダの中の `ask()` を指す（正しい）。
- 末尾呼び出しで最初の枠が置き換わると、`call_site` は末尾呼び出しの命令になり、起動の位置は残らない（`task1.bnt`・`task2.bnt` は primary なし）。
- 起きるのは、タスクの関数が「値として使う組み込みの関数か操作の原型」か「標準ライブラリの関数」で、その中で止まった場合である。待ち合いの行き詰まりの待つ位置（report.rs:474）も同じ経路を通る。

#### 規則の案
**推奨**: VM が、タスクの最初の枠の `call_site` を `None` にする（起動の位置は `task.spawner` だけに持つ）。
- `main` の最初の枠（`vm/mod.rs:228`）と同じ扱いになる。
- 末尾呼び出しで置き換わった後の `call_site`（同じタスクの命令）はそのまま使えるので、`tail.bnt` のように末尾呼び出しを指す primary は保たれる。
- 02-08 の 3 に「タスクの最初の段の、タスクを起動した命令は見ない（起動の位置は起動の履歴だけに示す）」と書き足す。
- 代案は `user_location` で最も外側の段を除くことである。ただし、末尾呼び出しの命令を指す有用な primary（`tail.bnt` の `main` の例）も消えるので勧めない。

#### テスト・設計書・決めること
- テスト: `task3.bnt` の形のゴールデンを 1 件加える。既存のゴールデンの変化は 0 件の見込み（`r41-inherited-non-tail`・`c12-deadlock` はラムダを渡すので変わらない）。VM の単体テストで最初の枠の `call_site` を見ているものがあれば直す（`vm/dispatch/tasks/tests/cancellation.rs:1549` 付近）。
- 設計書: 02-08「実行時エラーの情報の記録」、02-10「実行時エラーと資源の不足の報告」は参照だけ。
- 決めること: なし（規則の明確化）。案の承認だけでよい。

### 4. `return s` で期待と実際が逆に見える

#### 再現（再現した。型注釈を書いた場合も起きる）

```
function f() -> Unit
  bind s <- Integer.toString(1)
  return s          → 2:8 の `s` を指して「expected `String`, found `Unit`」。note は "a pattern must match …"
function g() -> Unit
  bind s: String <- Integer.toString(1)
  return s          → 同じ（利用者が String と書いた位置で「found Unit」）
function h() -> Integer  … 「expected `String`, found `Integer`」
```

#### 原因
- `typeck/generate.rs:1295-1321` の `bind_stmt` は、パターンの変数に新しい型変数 α を作り、`Equal(target, α)`（理由 Pattern、手順 2）を加える。
- `return s` の流れ込む制約（`generate.rs:1211-1225`、Declared、手順 1）が先に解かれ、α が Unit になる。
- その後に、パターンの Equal が String と Unit で失敗する。02-05「制約の解決」の手順 1 の狙い（宣言に合わない使い方の側を誤りにする）と逆の結果になっている。
- 手順 1 で変数を決めたときは、`solve.rs:490-497` が `declared[α] = return の理由` を記録している。FE403 は、これを呼び出しの戻り値の型の比較（`call_return`、solve.rs:505-540）にだけ使っている。

#### 直し方の案
- **推奨**: FE403 の仕組みを一般化する。手順 2 の Equal と Flow が、`declared` に記録のある変数（の根）と食い違って失敗したとき、その記録の理由（return の位置、"declared return type" の注記）で報告する。期待は宣言の側の型（Unit）、実際は他方（String）にする。f・g・h はどれも `return s` の位置で「expected `Unit`, found `String`」になる。
- 代案: 手順 1 で、`from` がまだ決まっていない型変数の return を手順 2 の後へ回す。推論の順序が広く変わるので勧めない。

#### テスト・設計書・決めること
- テスト: `typeck/tests.rs` に f・g・h の 3 件を加える。ゴールデンは 0 件（"a pattern must match" を含む `.diag.json` はない）。FE403 の既存のテストが通ることを確かめる。
- 設計書: 02-05「誤りの報告と検査の継続」（手順 1 で決めた変数との食い違いは宣言の理由で報告する）。
- 決めること: なし。

### 5. E0441 の注記がプレースホルダの関数を指すことが分かりにくい

#### 事実と再現
- ゴールデン `testdata/types/todo178-placeholder-try-error.diag.json` を `add(try Option.None, _)` で再現した。注記は「the function returns `Integer`」で、どの関数のことか読み取れない。
- 注記を作るのは `typeck/effects/special.rs:148-163`（E0441）と `:181-190`（E0442 も同じ注記 `declared`）である。
- 文脈はある。プレースホルダの呼び出しでは `generate.rs:241` が `ctx.placeholder_boundary = true` にする。`try_expr`（`effects/mod.rs:72-87`）は、それを制約に渡していない。

#### 直し方の案（推奨）
- `placeholder_boundary` を、真偽値から呼び出しの位置（`Option<Span>`）に変える（`context.rs` の非公開の欄）。
- `try_expr` で、`Reason.related` に入れるか、Try の制約に印を付ける。
- E0441・E0442 では、プレースホルダの場合に別の注記を使い、呼び出しを補助の位置で示す。
  - 注記の例: `placeholder: "the function made by `_` in this call returns `{declared}`"`
  - 補助の位置のラベルの例: "this call with `_` makes a function"
- ついでに、ラムダの場合も「the lambda returns」と分けるかを決める。

#### テスト・設計書・決めること
- テスト: ゴールデン 1 件、`effects/tests.rs` の E0441・E0442 の該当テスト数件。`gen_skill` で Skill の診断の文書を作り直す。
- 設計書: 02-05「誤りの報告と検査の継続」か、01-09 の `try` の診断の記述（あれば）。
- 決めること: 注記とラベルの文言。ラムダにも別の注記を使うか。

### 6. 文章の形の診断に埋める制御文字と双方向の制御文字

#### 既に逃がしている箇所
`diag/render.rs:444-470` の `escape_terminal_controls`（C0・DEL・C1 を `\u{1B}` の形にする）を使っている。
- 抜粋の行（render.rs の抜粋の経路）
- `-->`・`:::` のファイル名（render.rs:583）
- 件数の行（render.rs:83）
- `test` の報告（`cli/tools/test_runner/report.rs:29,51`）
- `fmt`（`formatter/mod.rs:239`）
- `skill`（`skill/mod.rs:225,235,259,359,377`）

#### 逃がしていない埋め込み（確かめたもの）
- 見出しの文: `E0101 "cannot read file `{path}`"` は、ESC をそのまま出す（`check "…nofile\x1bx.bnt"` で確かめた。同じ実行の件数の行は逃がしている）。同じ形のものに `E0125 {path}`・`{temp}`（fmt）がある。
- 履歴の段の名前: `<lambda 表示名:行:列>`（render.rs:765-790 の `anonymous_name`）。ディレクトリ名の ESC がそのまま出て、`at` の列の幅もずれる。`esc\x1b[31mdir/r.bnt` で確かめた。同じ行の `at …` の位置は逃がしている。`handle`・`lazy`・`case` の名前も同じ経路である。
- 起動の履歴の段の名前、待つタスクの行（同じ `anonymous_name` を通る）。
- `R0401` と解放の失敗の注記の `{location}`。注記・help の文全般も、render.rs:201-205 の `append_tagged_line` は逃がさない。
- 双方向の制御文字: どこでも逃がさない。字句解析は U+202E などを誤り（E0xxx）にするが、その誤りの抜粋が U+202E をそのまま出す（`bidi.bnt` で確かめた）。逃がす文字の集合は、既に `runtime/assert.rs:915-925` と `builtins/funcs/traits.rs:40-45` にある（U+202A〜202E、U+2066〜2069 など。表示の `show` で使う）。
- 定数の鍵（E0436・W0403 の `{key}`）は、今は `typeck/consts.rs` の `key_text` が Rust の Debug 表記（`{v:?}`）で逃がしている。TODO-179 の別の項目でこれを `text` に寄せるときに、逃がしを落とさないよう注意が要る。
- 識別子（モジュールの名前を含む）は、字句の規則で制御文字を含めないので対象外である。

#### 直し方の案
- **推奨**: 文章の形の描画（`render_one_text`）の一か所で、見出しの文・ラベル・注記・help・履歴と待つ行の名前を、新しい関数（C0・DEL・C1 と双方向の制御文字と、先頭以外の U+FEFF を逃がす）に通す。抜粋とファイル名の逃がしにも、双方向の制御文字を加える。
  - JSON の形式（`render_json_line`）では逃がさない（02-10 の既存の方針どおり）。逃がしは描画の段だけに置き、`Diagnostic` の値は変えない。
  - 例外が一つある。`cli/mod.rs:443-450` は、標準ライブラリの中の誤りを処理系の不具合にするとき、複数行の文章の形の描画の結果を `message` の注記に入れる。一律に逃がすと LF が `\u{A}` になる。この経路は行ごとに注記へ分けるか、逃がしの前に行で分ける。
  - 逃がしは冪等である（逃がした後の文字列に制御文字は残らない）ので、既に逃がしたファイル名を二重に逃がしても変わらない。
- 代案: 埋め込む値（`arg`）ごとに呼び出し側で逃がす。JSON にも逃がした値が入ってしまうので勧めない。
- `main` が返す `Result.Error(msg)` の文字列（02-09 の表）も今は生のまま出る。ただし、これはプログラムの出力に当たるもので、`Console.writeError` で同じことができる。対象外として、そのままにすることを推奨する。

#### テスト・設計書・決めること
- テスト: `diag/render/tests.rs` に、見出し・注記・履歴の名前・双方向の制御文字のテストを数件加える。CLI のテスト 1 件（E0101 のパス）。ゴールデンは 0 件の見込み（制御文字を含むパスのゴールデンはない）。
- 設計書: 02-10「文章の形式」の制御文字の【方針】の段落。対象を全文に広げ、双方向の制御文字を加える。
- 決めること: 双方向の制御文字を逃がす対象にすること。`Result.Error` の文字列は逃がさないこと。

### 7. E0339 と E0321 の修正案

#### 再現（確かめた）
- `import Benitoite.Unofficial.IO.Console as C` と `uses Console.Write`、`C.writeLine(…)` の入力では、次の二つが同時に出る。
  - E0339（編集は `as C` を消すだけ）
  - E0332「the module `Console` is not imported」（編集は同じ import の行を先頭に足す）
  - 両方の編集を当てると同じ import が二つになり、E0324 になる。
- E0339 の編集だけを当てると、`C.writeLine` が `E0302 cannot find C` になる。修正案は「a similar name exists: `IO`」で、誤った方向へ導く（TODO の写しは E0332 と書いているが、実際は E0302）。
- `import Benitoite.IO.File as F` の E0321 の修正案は `Benitoite.Unofficial.IO.File as F` で、当てると E0339 と E0332 になる（確かめた）。
- コードの位置:
  - `resolve/imports.rs:59-85`（E0339。コメント「誤りの後も別名で束縛を作り、uses と本体の参照の診断を重ねない」）
  - `modules/find.rs:154-170`（E0321。読み込みの段で、まだ参照の位置を知らない）

#### 直し方の案（推奨）
1. E0339 の編集に、同じファイルの別名の参照（式・`uses`・型・`case` の `C.` の修飾）を本来の名前（`Console`）に書き換える編集を加える。参照の位置は名前解決の段が持っている（別名の束縛への参照）。
   - 本来の名前が、そのファイルで別の取り込みや名前と衝突するときは、書き換えを加えず、今の help だけにする。
2. E0339 を出したときは、別名と本来の名前の両方で束縛を作る。こうすると、本来の名前で書いた `uses Console.Write` に E0332（と重複する import の編集）が重ならない。
3. E0321 は読み込みの段にあり、参照の位置を知らない。そこで、今の編集（パスの置き換え）のままとし、次の検査の E0339 が完全な修正案を出す二段の流れとする。
   - 代案: E0321 の時点で `as F` も消す。参照が E0302 になるので勧めない。

#### テスト・設計書・決めること
- テスト: `testdata/modules/todo177-effect-module-alias.diag.json`（E0339）が変わる。E0321 の 3 件（`f20-*`）と `l40-import-*` 2 件は、別名を使っていなければ変わらない。`resolve/tests.rs` に、編集を当てた後に検査を通るテストを 1〜2 件加える。
- 設計書: 02-04（名前解決）の E0339 の修正案の記述。01-03「モジュールと import」は参照だけ。
- 決めること: E0339 の修正案に参照の書き換えを含めること。E0321 は二段で直る流れでよいこと。

### 8. SECF1 の E0401「expected `Option[_]`, found `Option[_]`」

#### 事実と再現
- `testdata/handlers/secf1-*.diag.json` の 8 件は、どれも `_` と `_`、または `Option[_]` と `Option[_]` を示す。
- 表示の原因:
  - `typeck/solve.rs:575-600` の `diagnostic_type` は、`ITy::Rigid` を `Ty::Rigid` のまま渡す。
  - `types/mod.rs:490` は、`Rigid { index }` の名前を、表示している関数の `type_params` から引く。
  - 操作の型パラメータではなく、外側の関数の型パラメータの表から引いていることになる。
- **さらに誤った名前を出す**: 外側の関数が型パラメータを持つと、操作の `T` が外側の関数の `A` と表示される。`rigid.bnt`（`function run[A](a: A)` の中で SECF1 の形）では「expected `Option[_]`, found `Option[A]`」になった（確かめた）。
- 脱出の判定は `solve.rs:317-341` の `restrict_clauses` で、`DiagCode::E0401` だけを返す。注記は、元の制約の理由の一般の文（"argument 1 must match …" など）になる。

#### 直し方の案（凍結した `TyNames` を変えずに直せる）
- `Body` に「節のノード番号 → 操作の名前と型パラメータの名前」の表を持たせる。`handle` の節を辿るときに作る。
- `solve.rs` の `show` で、名前の表を `type_params` の写しの後ろに伸ばし、`Rigid` をその番号の `Ty::Param` に置き換えてから表示する。表示は「expected `Option[_]`, found `Option[T]`」になる。
- 利用者の関数にも同じ名前の `T` があると紛らわしい。そこで、脱出のとき（`restrict_clauses` の失敗）は、失敗の種類を区別して返し、`failure` で次の二つを加える。
  - 注記の例: "`T` is the type parameter of the operation `Swap.store`; a value of this type cannot leave the clause"
  - 補助の位置: 節（`case store(x)`）、ラベル "the clause of `store`"
- 区別の方法は二案ある。
  - **案 A（推奨）**: E0401 に注記を加える。
  - 案 B: 専用の診断コードを新しく作る。LLM が読み分けやすい一方、コードの表・Skill の文書・コードの一覧の変更が増える。

#### テスト・設計書・決めること
- テスト: ゴールデン 8 件（`secf1-*.diag.json` すべて）、`rigid.bnt` の形のゴールデンかテストを 1 件加える、`typeck/effects/tests.rs` の剛な型のテスト数件。`gen_skill` で Skill の文書を作り直す。
- 設計書: 02-05「誤りの報告と検査の継続」（操作の型パラメータは操作の宣言の名前で示す。脱出の注記）。
- 決めること: 案 A と案 B。注記とラベルの文言。

### 決めてもらう点のまとめ

1. L0101〜L0104 の重複: 定義ごとに一つにする（案 A）か、ラムダの位置を示す（案 B、文言を変える）か。L 系の診断の後に件数の行を書くか。
2. 不具合の報告の主スレッドの呼び名: 呼び名の変更か設計書の読み替え（案 A）か、凍結した `FaultThread::Main` の追加（案 B）か。不具合が複数あるとき両方を報告するか。
3. E0441 と E0442 のプレースホルダの注記とラベルの文言。ラムダの注記も分けるか。
4. 制御文字の逃がしを、文章の形の全文と双方向の制御文字に広げること。`Result.Error` の文字列は対象外とすること。
5. E0339 の修正案に参照の書き換えを含めること。E0321 は二段で直る流れでよいこと。
6. SECF1: E0401 の注記（案 A）か、専用のコード（案 B）か。文言。
- 3（primary の規則）と 4（`return s`）は、規則の明確化と不具合の修正であり、案の承認だけでよい。

## 調査 D: TODO-209（標準ライブラリの上限の定数）と TODO-221（フォーマッタのテストの冪等性と印）

基準: ブランチ san_benito の 44e38cbf。リポジトリのファイルは変えていない。試した入力は scratchpad の `orch8/idem/`・`orch8/b/` に置いた。

### 1. TODO-209 標準ライブラリのソースの数の定数

#### 今のコードの事実

標準ライブラリのソース（`crates/benitoite/src/prelude/stdlib/**/*.bnt`、`src/prelude/mod.rs` が `include_str!` で埋め込む）の、コメントの外の 2 桁以上の数のリテラルを全部集めた。処理系の定数と対応するのは一つだけである。

| 場所 | 値 | 処理系の定数 | 関係 |
|---|---|---|---|
| `Regex.bnt:107`（`appendPart` の `if nextBytes > 1073741824 then`） | 2^30 | `MAX_STRING_BYTES`（`src/runtime/mod.rs:18`） | 等しくなければならない |
| `Regex.bnt:110`（`List.length(next) = 4096`） | 4096 | `MAX_LIST_LEN`（`src/runtime/mod.rs:20`、2^24） | 対応しない。まとまりの大きさで、2^24 より十分小さければよい |
| `Network/Http.bnt:115`（`timeoutMilliseconds: 30000`、113 行のドキュメントコメントにも 30000） | 30000 | なし（`builtins/funcs/http_client.rs:19` の `MAX_CLIENT_TIMEOUT_MILLISECONDS` は上限で別の値） | 標準ライブラリが正。ドキュメントコメントと同じファイルの中で揃っている |
| `Time.bnt` の 1970・2026 など、`Byte.bnt`・`Bytes.bnt` の 255、HTTP の状態の番号 | — | なし | 例・型の定義・文書の値 |

ほかに設計書 03-08「Regex」（`docs/design/03-interop/03-08-text-and-data.md:158`）が「2^30 バイトを超えた時点で結合を試す」と書く。

食い違ったときの影響（コードを読んだ推測。実行では確かめていない）: 標準ライブラリの値が処理系の上限より小さいと、累積が値を超えた後の `appendPart` のたびに `finishParts` が全体を結合して成功し、結果を捨てるので、置換が 2 乗の時間になる。大きいと、止まるのが次の 4096 部分のまとまりか最後の結合まで遅れる（結合の上限検査は働くので、誤った値は返らない）。

#### 直し方の案

- **案 A（ソースを読んで比べるテスト）**: `src/prelude/mod.rs` のテストか `builtins/funcs/regex/tests.rs` で、埋め込んだ `Regex.bnt` の文字列から `nextBytes > <数> then` を探し、`MAX_STRING_BYTES` と比べる。テスト 1 件。test-audit の「ソースや文字列を字面で探すだけのテスト」に当たり、関門の説明が要る。本物の構文解析器で AST から探しても、テストの形は変わらない。
- **案 B（非公開の組み込みの関数で値を出す。推奨）**: `Regex.bnt` に非公開の `@builtin("Regex.maxStringBytes") function maxStringBytes() -> Integer` を置き、`appendPart` で `nextBytes > maxStringBytes()` と書く。本体は `MAX_STRING_BYTES` を返すだけである。値の出どころが一つになるので、突き合わせのテストが要らない。非公開の組み込みの関数は `findAt`・`spanAt` の前例がある（03-08:155）。引数のない組み込みの関数も前例がある（`Bytes.empty` など、`builtins/table.rs:606`）。触れる箇所は、`builtins/funcs/regex.rs` の `builtin!` と `DECLS`（「末尾以外には加えない」とあるので末尾に加える）、`builtins/table.rs` の Regex の行（707 行の後）、`Regex.bnt`。新しいテストは要らない。既存の `replaceAll` の経路のテストが `appendPart` を通る。`builtins/table.rs:473` の登録の契約のテストが新しい行も確かめる。非公開なので、Skill の文書（`gen_skill`）には出ない（`spanAt` は `skill/` と `docs/reference/` に出ていない）。
- **案 C（テストを設けず、相互のコメントだけ置く）**: `MAX_STRING_BYTES` の `///` に「`Regex.bnt` の `appendPart` に同じ値を書いている」と書き、TODO-209 を閉じる。費用は最小だが、気づくかどうかは書き手しだいである。

推奨は案 B。理由: 二重に書かないことで食い違いそのものをなくせ、字面を探すテストを足さずに済むからである。組み込みの関数を一つ加える費用は小さい（10 行程度）。テストの置き場所は不要になる。案 A にするなら、置き場所は `builtins/funcs/regex/tests.rs`（Regex の組み込みの関数の持ち主）。

#### 設計書で直す節

- 案 B: 03-08「Regex」の 155 行（非公開の組み込みの関数の列挙）に、上限の値を返す関数を加える。158 行の「2^30 バイトを超えた時点で」は、そのままでよい（値の出どころを書くなら一文）。
- 案 A: 07-03 に書く場所はない（テストの種類を新しく作るほどではない）。改造の文書だけに書く。
- 案 C: 設計書は変えない。

#### 設計者に決めてもらう点

- 案 A・B・C のどれにするか（推奨は B）。
- 案 B のとき、組み込みの関数の名前（`Regex.maxStringBytes` か、`String` の側に置く非公開の名前か）。`String` の側に置くと、ほかのモジュールからは非公開なので使えない点に注意する。

### 2. TODO-221 フォーマッタ

#### (a) ゴールデンテストの冪等性

今のコードの事実:

- `fmt` の方式の実行器 `crates/benitoite/tests/golden/formatting.rs` の `run_fmt_case`（23〜110 行）は、整形の結果を `.formatted` と比べるだけで、結果をもう一度整形しない。
- `check`・`run` の方式では、同じファイルの `check_properties`（269〜338 行）が `format_source` を二度呼んで冪等性を確かめる。単体テストは `src/cli/tools/formatter/tests.rs:29-34` の `check` が個々の場合の冪等性を確かめる。
- 設計書は、冪等性の自動の確かめを `check` と `run` のゴールデンだけに書く（07-03「ゴールデンテストの形式（初回リリース版）」の 116〜122 行の【決定】、06-03「テスト」の表の 3 行目）。

今のゴールデンで冪等でない例はない。`testdata/fmt/` の `.formatted` 9 個とディレクトリの `directory.formatted/`（2 ファイル）、元が正規形の `check_canonical.bnt`、`testdata/acceptance/fmt_comments.formatted` を写し、`benitoite fmt --check` にかけた。どれも終了状態 0（変更なし）だった。`--check` が変更を見つけることは、`blank_lines.bnt`（整形の前）で終了状態 1 になることで確かめた。

直し方の案（推奨）: `run_fmt_case` で、`fmt` の方式（`fmt-check` でない）のとき、各ファイルの整形の結果に `format_source(FileId(i), SourceKind::User, result)` を当て、`changed` が真なら「formatting is not idempotent」を失敗に加える。`Err(FormatError::Syntax(_))` は飛ばす（`syntax_error.bnt` は書き換えられず、結果が元のままのため）。`Err(FormatError::Verify(_))` は失敗にする。`check_properties` の二度目の整形の部分（293〜310 行）を補助の関数に出して共有する（test-audit の「重複した準備の処理は、同じ変更の中でまとめる」）。テストの数は増えない（実行器の変更だけで、対象は fmt の方式の 11 件。testdata は変えない）。test-audit の関門: 守る契約は 06-03 の冪等性で、`fmt` のゴールデンは空の行・複数行の文字列・行末など規則ごとの入力を集めており、`check`・`run` のゴールデンと単体テストの入力では届かない。本番のコードの差し込み口は要らない。

設計書で直す節: 07-03「ゴールデンテストの形式（初回リリース版）」の方式の表の `fmt` の行（114 行）に「整形の結果を再び整形しても変わらないこと」を加える。06-03「テスト」の表の 1 行目（ゴールデンテストの `fmt` の方式）にも冪等性を加える。

設計者に決めてもらう点: なし（推奨のとおりでよいかの確認だけ）。

#### (b) `///` の後の行の空の行の印（leading）

今のコードの事実:

- `src/cli/tools/formatter/roles/walk.rs:318-323` は、宣言が説明（`decl.doc`）を持つとき、宣言の最初の字句（最初の属性の `@` か宣言の語）に `leading_blank` の印を付ける。06-03「空の行」の「`///` の行と属性の間の空の行は除く」を実装したものである。
- この印は効かない。構文解析器は、宣言の最初の字句の直前の行から上に続く `///` だけを集め、空の行で止める（02-03「コメントとドキュメントコメント」）。止まって結び付かなかった `///` は E0228 になり、E02nn なので `fmt` は整形を断る（06-03「構文の誤りがあるファイル」）。試した結果: `/// doc`・空の行・`function` の入力と、`/// doc`・空の行・`@test`・`function` の入力は、どちらも E0228 で終了状態 2、ファイルは変わらない。説明が結び付く入力では、`///` の行と最初の字句の行の間に空の行がないので、印で除くものがない。さらに `print.rs:333` は、前の行がコメントだけの行（`///` の行）だと `leading` を見ずに一つまで保つ。
- 印を確かめているのは `roles/tests.rs:148` の表の 1 行（`(2, (true, false)), // `///` の行と属性の間`）だけである。
- 属性の行と宣言の間の印（同じ関数の 334〜339 行）は効く（`@test` と `function` の間の空の行を除く。`c.bnt` で確かめた）。

直し方の案:

- **案 1（印を消す。推奨）**: `walk.rs:318-323` を消し、`roles/tests.rs:148` の期待を `(false, false)` に変え、注釈を「`///` の後の行（空の行は置けない）」などに直す。触れるテストは 1 件の 1 行。06-03「空の行」の「属性の行と宣言の間、`///` の行と属性の間の空の行は除く」から「`///` の行と属性の間」を除き、「`///` の行と宣言・属性の間に空の行を置いたファイルは E0228 で整形しない」と一文で書く。06-03「コメント」の「空の行の規則（次節）は、`///` の行と宣言の間、`///` の行と属性の間に空の行を加えない」は、加えない側の記述なので残してよい。
- **案 2（印を残し、効く入力のテストを足す）**: 効く入力が存在しないので、テストを書けない。取れない。

設計者に決めてもらう点: 案 1 でよいか。

#### (c) 空の `then` と `handle` の本体の中のコメント

今のコードの事実:

- コメントだけの行の段は `print.rs:376-386` が決める。後の最初のコードの行の最初の字句の `inner_level`（閉じの字句だけが持つ）があればそれを、なければ `level` を使う。`inner_level` は `walk.rs:1080-1084` が `closers`（`walk.rs:232-237` の `closer`）だけに付ける。区切りの字句（`else`、節の並びを始める `with`。`walk.rs:239-243` の `separator`）は持たない。
- そのため、中身がコメントだけの `then`・`else if` の分岐・`handle` の本体のコメントは、`else`・`with` と同じ外側の段に置かれる。中身がコメントだけの `else`・`lazy`・`lambda`・宣言のコメントは、閉じの字句の前なので内側の段に置かれる。

実例（`orch8/b/h.bnt` を整形した結果）:

```text
  handle
  // nothing yet
  with
    case Ask.ask() -> resume(1)
  end handle
  if true then
  // a
  // b
  else if false then
  // c
  else
    // d
  end if
```

`testdata/fmt/blank_lines_comments.formatted` の 23〜32 行がこの振る舞いを固定している（`then` と `handle` は外側、すぐ下の `else` は内側で、隣り合って並ぶ）。中身のある分岐の後の `else` の前のコメント（`testdata/fmt/comments.formatted` の `// before else`）は、06-03「コメント」が `else` と同じ段と明記しており、今のとおり外側である。

直し方の案:

- **案 X（今のまま）**: 06-03 の規則どおりなので、コードは変えない。06-03「コメント」に、中身がコメントだけの分岐と本体のコメントも外側の段になることを一文で書くかを決める。
- **案 Y（中身が空のときだけ内側にする。推奨）**: 区切りの字句の直前の中身（`then` の分岐・`else if` の分岐・`handle` の本体）に文が一つもないとき、その区切りの字句にも `inner_level`（開きの行の段 + 1）を付ける。実装は `walk.rs` の `if_chain`（778〜808 行）で `e.then_block` が空なら、`handle`（863〜877 行）で `e.body` が空なら、`separator` に加えて `closers` と同じ記録を行うだけで、`print.rs` は変えない（`inner_level` の欄の説明 `roles.rs:24-26` と `closer`・`closers` の名前の説明は直す）。中身のある分岐の後の `else` の前のコメントは、今のとおり外側に残る。整形の結果は構造だけで決まるので、冪等性は保たれる。触れるテストは、`blank_lines_comments.formatted` の 2 か所（`// then の中身が空である`、`// handle の本体が空である` の 2 行）の期待の書き直しと、`roles/tests.rs` の `inner_level` の表（240〜255 行あたり）に空の `then` の `else` の行を足すかどうか（ゴールデンが観察できる振る舞いを確かめるので、足さなくてよい）。
- **案 Z（区切りの前のコメントを常に内側にする）**: 中身のある分岐の後の `else` の前のコメントも内側になる。06-03 の「`else` の前のコメントは `else` と同じ段に」と `comments.formatted` を変える。コメントが前の分岐の続きか、次の分岐の見出しかは書き手しだいなので、どちらの段も誤りになりうる。

推奨は案 Y。理由: 中身がコメントだけの本体では、コメントが本体に属することが構造から明らかであり、外側の段に置くと `else`・`with` の説明に見える。同じ関数の中で空の `else` と `lazy` の本体のコメントは内側なので、空の本体の扱いが揃う。中身のある分岐の後のコメントの扱い（06-03 の明記の規則）は変えずに済む。

設計書で直す節（案 Y）: 06-03「コメント」の段落「コメントだけの行は、その後の最初のコードの行…」に、「ただし、`else` か `handle` の節の並びを始める `with` で始まる行の前の分岐・本体に文がないときは、閉じの字句の前と同じく、構文の中の段に置く」を加える。06-03「入力表現」は変えない。

設計者に決めてもらう点: 案 X・Y・Z のどれにするか（推奨は Y）。案 Y のとき、`match` の分岐の本体は空にできないので対象外でよいかの確認（`case` の前のコメントは、今は次の `case` の段）。

### 触れるテストの数のまとめ

| 項目 | 推奨の案 | テストの変更 |
|---|---|---|
| TODO-209 | 案 B | 新しいテストなし（既存の Regex のテストと登録の契約のテストが通ることを確かめる） |
| TODO-221 (a) | 実行器に加える | 実行器 1 ファイル（`tests/golden/formatting.rs`）。対象は fmt の方式の 11 件。今はすべて通る |
| TODO-221 (b) | 案 1 | `roles/tests.rs` の 1 行 |
| TODO-221 (c) | 案 Y | `testdata/fmt/blank_lines_comments.formatted` の 2 行 |

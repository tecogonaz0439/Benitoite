# C3a: Lean と Rust の脱糖の差分検査

2026-10-10 に実装・測定した。C1・C2 の定義と定理、Rust の本番のコード、設計書は変更していない。コミットはしていない。

## 入力と集計の単位

ゴールデン入力は `tests/golden.rs` の探索規則で集めた 523 件である。`.files`・`.formatted` を探索せず、隣に `.mode` があるディレクトリは一つのケースとする。ベンチマークは含めない。`mode=test` は `require_main=false` とする。ほかは `require_main=true` とし、警告では除外しない。読み込みから型検査までの誤りと、ディレクトリに `main.bnt` がない誤りは「除外（検査の誤り）」に数える。

無作為な入力は `generate_formal` の種 0〜999 の 1,000 件である。既存の生成器と整数式の生成を共有するが、段ごとの追加部分を出さず、観察は `Console.writeLine(Integer.toString(x))` とする。整数式の選択は段 1 に固定し、展開を出さない。レコード・定数・`Lazy` を選ばない。既存の `generate(seed, stage)` は、6 段階それぞれの種 0〜999 について、変更前後のソースと機能別計数が完全に一致した。

比較単位は、読み込まれた利用者の全モジュールの `DefOrigin::User` かつ `DefKind::Fn` の定義である。標準ライブラリの関数、フィールドを取り出す関数、実装のメソッドは比較しない。

プログラム単位では、不一致のあるものを不一致、残りのうち対象外の関数を含むものを対象外、残りを一致と数える。対象外の関数と一致する関数を両方持つプログラムでも、関数単位ではそれぞれを数える。検査で除外したプログラムについては型検査済みの定義がないため、関数の除外数は数えず、表示の 0 は「定義を取得していない」の意味である。

Rust の書き出しの集計は「範囲内の関数を一つでも書き出したか」で判定する。1,185 件を書き出し、73 件を対象外、265 件を検査の誤りで除外した。これは比較器のプログラム単位の判定とは異なる。30 件が範囲内の関数と対象外の関数を両方持つ。

## 交換形式と名前

`formal/Benitoite/Exchange/Syntax.lean` が型・定数・パターン・表層構文・コアの項・定義の頭・範囲の判定・入力の型を持つ。JSON は構成子名を鍵、構成子の引数名を欄名にする。引数のない構成子は文字列で表す。コーパスの版は 1 であり、先頭に Rust の `OPERATORS`・`EQUALITY`・`INEQUALITY` から作る演算子の表を置く。

| 種類 | 名前の規則 |
|---|---|
| 関数 | `fn:<BindingId>` |
| データ型 | `data:<BindingId>` |
| 構成子 | `con:<adt BindingId>:<tag>`。値・呼び出し・パターンで共通 |
| 組み込みの関数 | `builtin_decl(id).name` をそのまま使う |
| 組み込みのエフェクト | 組み込みの表のモジュール名と名前を `.` でつなぐ。`State` はそのまま |
| 利用者のエフェクト | `effect:<BindingId>` |
| 型パラメータ・エフェクト変数 | `Ty::Param(i)`・`EffVar(i)` の i をそのまま使う |

10-05「型パラメータの番号」は、トップレベルの関数の番号を宣言順としている。Release の番号と恒等に対応する。型パラメータの equality・key の制約も頭で比較する。等値・不等値のスキームがエフェクト変数を持たないことは書き出し時に assert する。Lean の `opPrim` は表を引き、型引数には `Operator.typeArgs` を使う。

エフェクトは `name` と `rho` の有限の並びで受け渡す。入力 JSON に現れた原子を重複なく集め、Lean の関数としての集合をその原子について調べて並びに戻す。脱糖が原子を追加しないため、この戻し方で情報を失わない。比較時は並びの順と重複を取り除く。

Float は Rust の `f64::to_bits()` と Lean の `Float.ofBits`・`Float.toBits` で変換する。Lean の `UInt64` の標準 JSON 表現は十進の文字列であるため、JSON の `bits` は文字列とし、Lean では UInt64 として読む。数値としての浮動小数点数の比較は行わない。正のゼロと負のゼロのビットの違いも保つ。

使用中の Lean の `#eval` と実行ファイルでは、NaN のペイロードを持つビットを `Float.ofBits`・`Float.toBits` で往復させると、ペイロードが変わった。`floatFromBits` は往復後のビットを確認し、保持できない入力をエラーとして拒否する。Rust の `typeck/generate.rs::literal` は Float リテラルを `is_finite()` で検査するため、今回の型検査済みの入力には NaN と無限大は現れない。実行ファイルで正負のゼロ・非正規化数・有限値の両端・無限大の 10 種のビットが保たれることと、NaN のペイロードを保持できない入力が終了状態 2 になることを確認した。

本番の公開 API と serde の導出の追加はない。二つの統合テストが共有する生成器のモジュールは、テストクレートの中で `pub mod` とする。二つの入口の片方を使わないテストのために `dead_code` の許可を加えることは避けた。

## 正規化と整合の検査

| 内容 | 場所 |
|---|---|
| AST の局所束縛を de Bruijn の番号へ移す。引数の最後、最後に束縛した変数が 0 | Rust `exchange.rs` の `Surface::name`・`Surface::statements`・`Surface::pattern` |
| コアの `VarId` を同じ規則の番号へ移す | Rust `Core::value`・`Core::comp` |
| `match` の行と分岐を `(Pattern, Comp)` にする。行数と分岐数が等しく、行 i の `arm=i` であることを検査する | Rust `Core::comp` |
| 分岐の変数がパターンの変数と重複なく一致することを検査し、照合順に環境へ追加する | Rust `Core::pattern`・`Core::comp` |
| 構成子の識別、修飾の除去、負の整数のパターンを定数へ移す | Rust `con_name`・`Surface::pattern`、Lean `Pattern.toSurface`・`fromPattern` |
| `Val`・`Comp` の型と由来、`Var.ty`、`BuiltinInfo`、ラムダの `BodyId` と引数の名前を捨てる | Rust `Core::value`・`Core::comp` |
| ラムダの引数の型をコアで比較する。エフェクトは、Release のラムダが注釈を保持しないため、コアのラムダの出力順に別欄で比較する | Rust `Core::value`、Lean `Expr.lambdaEffects`・`Block.lambdaEffects` |
| エフェクトを集合として比較する | Lean `fromEff`・`canonicalJson` |
| 定義の頭も独立に読み出して比較する | Rust `Surface::header`・`definitions`、Lean `desugar` |

`let x ⇐ return V` を代入して消す正規化は加えていない。パイプの差し込み引数と、プレースホルダの穴の再束縛は、C2 の定義のままで Rust と一致した。追加の意味変換による正規化はない。

表層で範囲内と判定した定義のコアに、`Lazy`・`Handle`・`Use`・`Resume`・`Method`・空でない `App.dicts`・`ConstRef`・利用者の `Op`・範囲またはリストのパターン・ガードが現れたら、`unsupported` を保持して比較を失敗させる。行と分岐の対応や、パターンの変数の整合が崩れた場合も同じである。対象外へ数え直すことはしない。

## 比較結果

| 入力 | 単位 | 一致 | 不一致 | 対象外 | 除外（検査の誤り） |
|---|---|---:|---:|---:|---:|
| ゴールデン | プログラム | 149 | 6 | 103 | 265 |
| ゴールデン | 関数 | 314 | 6 | 135 | 計数しない |
| 無作為 | プログラム | 1,000 | 0 | 0 | 0 |
| 無作為 | 関数 | 2,621 | 0 | 0 | 0 |

対象外の内訳は以下のとおりである。同じ関数またはプログラムが複数の要素を持つため、行の合計は対象外の総数とは一致しない。無作為な入力の内訳はすべて 0 である。

| 要素 | ゴールデンの関数数 | ゴールデンのプログラム数 |
|---|---:|---:|
| field | 22 | 17 |
| interpolation | 22 | 22 |
| try | 52 | 44 |
| record | 21 | 18 |
| handler | 22 | 20 |
| resume | 17 | 16 |
| user operation | 13 | 13 |
| with | 27 | 24 |
| lazy | 5 | 5 |
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

## 不一致の分類

残る不一致は 6 関数、16 箇所で、すべて **(b) Lean の脱糖の定義の対応漏れ** と分類する。型保存の定理が偽になる反例ではない。Lean の定義が Rust の直接の負の Float リテラルの処理を写していないため、C3 の項の一致が成り立たない。

Rust の `typeck/generate.rs::unary` は、直接の `-` と Integer・Float・Decimal のリテラルを、符号を含めて `lit_values` に記録する。`ir/desugar/exprs.rs::unary` はその項目があれば直接の定数を返す。Lean の `Surface.desugarExpr` は整数の `negInt` だけを定数にし、Float の場合は一般の `neg` に移す。

最小の違いは `-1.0` で、次の形になる。

```text
Lean: let x ⇐ return Float(bits=0x3ff0000000000000)
      in %Float.negate(x)
Rust: return Float(bits=0xbff0000000000000)
```

`-0.0` も同じである。Rust は `0x8000000000000000` の定数を返し、Lean は `0x0000000000000000` を `%Float.negate` に渡す。この違いは変数の番号や付随情報の違いではないので、比較器で演算を実行する正規化は加えない。

| 入力 | 関数 | 最初に異なる部分の最小の入力 | 同じ原因の箇所数 | 分類 |
|---|---|---|---:|---|
| `testdata/eval/f15_float_to_string.bnt` | `main` (`fn:30`) | `-1.0` | 2 | (b) |
| `testdata/eval/float_round_floor.bnt` | `main` (`fn:31`) | `-0.5` | 6 | (b) |
| `testdata/eval/float_semantics.bnt` | `main` (`fn:31`) | `-0.0` | 3 | (b) |
| `testdata/eval/float_to_string.bnt` | `main` (`fn:30`) | `-1.0` | 2 | (b) |
| `testdata/eval/list_sort.bnt` | `main` (`fn:31`) | `-1.0` | 2 | (b) |
| `testdata/test/values.bnt` | `standard` (`fn:37`) | `-2.0` | 1 | (b) |

箇所数の確認では、不一致のある定義の全体を書き出し、診断用の一時の処理で上記の Float の形だけを対応させると、6 定義とも残りの全体が一致することを確かめた。この処理は差分検査に組み込んでいない。`report.json` は、最初の差の JSON の場所・最小の部分木・両側の定義の全体を保持する。

C3b の修正案は、Lean の `neg` の直接の Float リテラルの場合を定数へ移す規則を加えることである。括弧で囲んだリテラルや一般の式への `neg` は今の呼び出しの規則を保つ。型付け・範囲の条件・型保存の証明・例を見直し、01-12 の「名前とリテラル」と「演算子」の行および形式化した規則の写しを同じ変更で更新する。Rust を Lean の一般の `neg` に揃える案もあるが、現在の Rust の型検査が符号込みのリテラルを記録する処理との整合を要する。どちらを正にするかは C3b で確定する。

(a) に分類した不一致と、追加の正規化を要する (c) の不一致は 0 件である。C3a で直したのは交換形式と名前・変数・エフェクト・分岐の表し方の対応であり、脱糖の定義は直していない。

## 検査と時間

作業の最初に `lean_exe` を登録し、小さな実行ファイルの `lake build desugarDiff` と実行が macOS 上で成功することを確かめた。その後、同じ入口を JSON の比較器に置き換えた。

再現するコマンドは次のとおりである。出力先の環境変数は省略でき、省略時は `target/desugar-diff/` の実行ごとの場所を使う。

```sh
BENITOITE_DESUGAR_DIFF_DIR="$PWD/target/desugar-diff/c3a" /bin/bash scripts/check-formal.sh
scripts/check.sh --base HEAD --only rust,formal
```

`check-formal.sh` は最後の集計と報告の保存まで走り、不一致を理由に終了状態 1 で終わった。結果は `target/desugar-diff/c3a/corpus.json`・`report.json`、全出力は `target/desugar-diff/check-formal.log` にある。無作為な各入力のソースも同じ出力ディレクトリに保存する。

最終の実行の時間は次のとおりである。スクリプトの段の時間は bash の `$SECONDS` による秒単位であり、ビルド済みの成果物を使った。

| 段 | 時間 | 結果 |
|---|---:|---|
| `lake build` | 1 秒 | 63 jobs、成功、`sorry` の警告なし |
| `lake build desugarDiff` | 0 秒（秒単位の測定） | 16 jobs、成功 |
| Rust の書き出し（cargo を含む） | 38 秒 | 1 テスト成功 |
| Lean の比較 | 1 秒 | 集計・保存を完了、不一致で終了状態 1 |

書き出しのテスト内の計測は **36.893 秒**、テストハーネスの表示は **37.13 秒**であり、10 秒を超える。書き出しは型検査・脱糖・JSON の保存までを含み、無作為なプログラムを実行しない。

検出器については、一致する入力の範囲内のコアだけを `unsupported(Lazy)` に置き換えた一時のコーパスが、不一致 1・対象外 0 で終了状態 1 になることを確認した。Float の正のゼロと負のゼロを取り違えたコーパスも、不一致 1 で失敗した。エフェクトだけを重複・並べ替えしたコーパスは一致した。これらの一時の入力と報告は `target/desugar-diff/c3a/` に置き、通常の集計には含めていない。

共通検査は format と全ターゲットの lint を通った後、既存の HTTP テスト `runtime::io::http::tests::stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting` が `runtime/io/http/tests.rs:298` の `TcpListener::bind(("127.0.0.1", 0))` で `Operation not permitted` を受けて失敗した。通常のライブラリの結果は 789 成功・1 失敗・16 ignored である。同じテストの単独実行でも再現した。サンドボックスがソケットの bind を許可しないため、要求された `--only rust,formal` の成功は確認できていない。既存のテストと検査スクリプトの実行内容は変えていない。

`check.sh --base HEAD --only formal` は成功し、`lake build` に `sorry` の警告はない。差分検査の実行ファイルも `sorry` なしでビルドした。

既存の `random_programs` のテストは、`--no-default-features --features gc-mark-sweep,heap-verify` で 3 成功（23.38 秒）、これに `gc-stress` を加えた設定でも 3 成功（15.32 秒）である。最後の Rust の書き出しの変更の後も、`cargo fmt --all` と、書き出し・無作為テストを対象にした `cargo clippy` は成功した。`/bin/bash -n scripts/check-formal.sh` も成功した。

## C4 以降で範囲を広げるときの注意

- 範囲の判定と、コアに残る対象外の印の検査を同時に広げる。表層の判定の漏れを対象外の数へ戻して隠さない。
- C4 の継続は普通の値の変数と区別する。`ContVar`・`Rigid`・操作の型パラメータの番号の変更を、既存の変数の正規化へ混ぜない。
- C5 の辞書・メソッド・`TypeArg::Head` は現在の番号の恒等対応の範囲外である。10-05 のメソッドと実装の番号の規則を改めて写す必要がある。
- C6 のレコードは構成子とフィールドの順、文字列補間と展開は評価順を保って比較する。Decimal の定数は Float のビット表現とは分ける。
- C7 の選択肢・ガードは現在の「行 i が分岐 i」を満たさない。選択肢ごとの束縛の対応と、共有する分岐の本体をどう比較するかを先に決める。
- Release のラムダはエフェクトの欄を持たないため、現在は表層とコアからそれぞれ出力順に集めて比較する。脱糖が本体を複製・並べ替える構成を加えるなら、ラムダと注釈を対応させる方式も見直す。
- `opaque` の型名に型引数の交換表現を含める形は、今回の脱糖の形の比較用である。E2 の型付けの検査に再利用するときは、Task などの型引数と型の置き換えを表す方式を別途検討する。

## C3b: 直接の負の Float リテラルの対応

2026-10-10 に実装・検査した。オーケストレータの決定に従い、Lean の脱糖を Rust に合わせた。IEEE 754 の符号反転は `-0.0` を含めて値を定められ、一般の `neg` の呼び出しと同じ値になる。処理系と同じ定数の形にすることで、比較器に演算を実行する正規化を加えずに済む。01-12 の写しの更新はオーケストレータが担当するため、この作業では `docs/design/` を変更していない。Decimal は C6 の範囲のままである。

### 加えた構文・規則と証明

`Surface.Expr.negFloat (x : Float)` は、括弧を挟まず Float リテラル x に単項の `-` を適用した式を表す。x は符号反転前の値である。型付けの `E_NegFloat` は型を `Float`、エフェクトを空とする。番号の範囲条件は `True`、`Exits` は `False` である。脱糖は `.ret (.const (.float (-x)))` とする。

型の不変条件・脱糖の範囲保存・脱糖の型保存の三つの導出に `E_NegFloat` の場合を加えた。`desugar_typed` と `surface_effect_soundness` の言明、`Benitoite.Release` の定義と証明、組み込みの関数の仮定は変更していない。

`Examples.lean` に `-1.25` と `-0.0` の脱糖の例を加え、どちらも `rfl` で証明した。Float のビット変換は実行時に確認するため、`#guard` で `Float.ofBits 0` の `negFloat` の脱糖結果から Float を取り出し、その `toBits` が `0x8000000000000000` であることを検査した。数値の等値により正負のゼロを同一視していない。

交換形式には `negFloat(bits)` を加えた。bits は Rust の型検査が直接の負号の式の ID に記録した、符号込みの `lit_values` の Float 値のビットである。Rust の書き出しはこの値を十進の文字列として出力する。Lean の交換形式から表層への変換は、既存の `floatFromBits` でビットの往復を検査してから符号を戻し、反転前の値を持つ `Surface.Expr.negFloat` を作る。脱糖時に符号を反転するので、コアに出る値は Rust が記録した値になる。これは表層の入力表現の変換であり、コアを比較する正規化の追加ではない。

整数の `-n` の書き出しは変更していない。括弧を挟む `-(1.0)` と一般の式への負号は、符号込みのリテラル値が記録されないため、既存の `neg` の呼び出しのままである。Rust の本番の型検査・脱糖・公開 API は変更していない。

### 最終の差分検査の結果

実行したコマンドは次のとおりである。

```sh
BENITOITE_DESUGAR_DIFF_DIR="$PWD/target/desugar-diff/c3b" /bin/bash scripts/check-formal.sh
```

終了状態は **0** であり、不一致は **0** である。入力の探索規則、無作為な入力の種、比較単位、対象外の判定は C3a と同じである。結果は `target/desugar-diff/c3b/corpus.json`・`report.json`、全出力は `target/desugar-diff/check-formal-c3b.log` に保存した。`report.json` の `mismatches` は空である。

| 入力 | 単位 | 一致 | 不一致 | 対象外 | 除外（検査の誤り） |
|---|---|---:|---:|---:|---:|
| ゴールデン | プログラム | 154 | 0 | 104 | 265 |
| ゴールデン | 関数 | 320 | 0 | 135 | 計数しない |
| 無作為 | プログラム | 1,000 | 0 | 0 | 0 |
| 無作為 | 関数 | 2,621 | 0 | 0 | 0 |

Rust の書き出しの集計は 1,185 件の書き出し、73 件の対象外、265 件の除外で、入力は計 1,523 件である。これは C3a と同じ数である。

C3a の 6 件の不一致のうち、5 件はプログラム単位で一致となり、`testdata/test/values.bnt` は対象外となった。同入力の `standard` は一致したが、別の関数 `records` がレコードを含むためである。プログラム単位の「不一致、対象外、一致」の優先順による分類の変化であり、対象外の関数を増やした結果ではない。対象外の要素ごとの関数数・プログラム数は、上の C3a の内訳表の全 22 行と同じである。無作為な入力の対象外の内訳はすべて 0 である。

C3a で (b) と分類した 6 関数・16 箇所の対応漏れはすべて解消した。**新しく見つかった不一致はなし**。(a) Rust の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化の不足は、最終の検査ではいずれも 0 件である。既存の差分検査が修正前の不一致を検出済みであり、同じ入力で修正後の一致を確認できたため、Rust の退行テストは重ねて追加していない。

| 段 | 時間 | 結果 |
|---|---:|---|
| `lake build` | 7 秒 | 63 jobs、成功、`sorry` の警告なし |
| `lake build desugarDiff` | 3 秒 | 16 jobs、成功 |
| Rust の書き出し（cargo を含む） | 38 秒 | 1 テスト成功 |
| Lean の比較 | 1 秒 | 不一致 0、終了状態 0 |

スクリプトの段の時間の合計は 49 秒である（bash の `$SECONDS` による秒単位の測定）。書き出しのテスト内の計測は 36.906 秒、テストハーネスの表示は 37.14 秒である。

### 公理と静的な検査

`formal/README.md` の手順にある 11 定理について `#print axioms` を実行した。一時ファイルは `formal/AxiomsC3b.lean` に作成し、検査後に削除した。Surface の二つの定理の出力は次のとおりである。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

ほかの 9 定理も README に記録された標準の公理だけであり、`sorryAx` や新しい公理は現れなかった。`cargo fmt --check` と `cargo clippy -p benitoite --all-targets` は成功した。

`scripts/check.sh --base HEAD --dry-run` は、変更した Rust のテストから `rust`、Lean のファイルから `formal` を選んだ。同じ指定での実行は format と全ターゲットの lint（mark-sweep）に成功した後、通常のライブラリテストで C3a と同じ HTTP テストが失敗した。失敗は `runtime::io::http::tests::stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting` の `runtime/io/http/tests.rs:298` にある `TcpListener::bind(("127.0.0.1", 0))` のみであり、OS の `PermissionDenied: Operation not permitted` による。結果は 789 成功・1 失敗・16 ignored、39.01 秒である。実行環境のソケットの bind の制限として、オーケストレータが別の環境で検査する。全出力は `target/desugar-diff/check-c3b.log` に保存した。

共通検査はこの失敗で止まるため、後続の gc-stress・仮置きの許可・Skill の生成物・formal の検査には到達しなかった。未到達の formal は `scripts/check.sh --base HEAD --only formal` で別に実行し、成功した。共通検査の全体の成功は、この環境では確認できていない。

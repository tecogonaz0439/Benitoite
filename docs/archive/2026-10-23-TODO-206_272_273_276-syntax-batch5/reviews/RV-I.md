# RV-I 段 I（形式化の先行）のレビュー

2026-10-23、レビュー担当。対象は基準 `35e3bc65b2de31c96fd3167a54f9fc775bb93a69` から `19d12c8a8845da1eea74414c179c55fd941cab16` まで（作業 L1・L2a・L2b・L3 の 4 コミット）である。作業ツリーではなく `git show`・`git diff` で対象のコミットを読んだ。ビルドは行っておらず、Lean の既定ビルドの成否は各作業の results.md の記録に依る。

## 結論

重い指摘はない。中の指摘が 1 件、軽い指摘が 6 件ある。主な定理の言明、公理、`Builtins.Assumptions` は変わっておらず、型付け・脱糖・検査・交換は同じ `FormatSpec.Valid` を使っている。段 V（処理系）へ進んでよい。中の指摘 M1 は F5 の手順に加えれば足り、段 I の作り直しは要らない。

## 確かめたこと

### 1. 主な定理・公理・抜け道

- 差分の追加行に `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`opaque`・`set_option` はない（`git diff … -- formal` を検索した）。`partial def` は既存の交換・差分の実行ファイル（`DesugarDiff/Main.lean`・`Exchange/Builtins.lean`・`Version.lean`）にだけあり、証明の対象外である。
- 削除された `theorem` の行は `interpAllowed_spec` だけであり、改行を変えただけで言明は同じである。`formal/Benitoite/Release/` には差分がなく、`Builtins.Assumptions` と性質 2・3 は変わっていない。
- 言明が変わったのは内部の補題だけである。`interpolate_typed` は前提に `InterpPart.Allowed parts` が加わった。`StrHeadsTyped`・`directHeads_typed`・`converterTypes_fn` は一引数の形 `[name] [t]` から任意の `names args` へ一般化した。どれも `Lemmas/Typing.lean` の `E_Interpolation` の場合の中で使われ、そこで必要な前提 `hp` は型判断から得ている。性質 1 の言明は変わっていない。
- L2a で入れた一時的な拒否（`interpAllowed` の `.formatted _ _ :: _ => false`）は L2b で外されている。`CheckSoundCollections.lean` の差分は二つのコミットで打ち消し合って 0 になり、`Check.lean`・`CheckComputeCalls.lean`・`CheckComputeSound.lean` には差分がない。有限支持は `InterpParts.AtomsIn` が書式付きの T も含め、`interpolation_types_atoms` が八引数の固定シグネチャを支持の中に入れることで既存の証明に接続している。

### 2. 書式の定義と decisions.md の一致

`formal/Benitoite/Surface/FormatSpec.lean` を D4〜D8・D29 と study 5.1・5.2 の表に照らした。

| 決定 | Lean の定義 | 判定 |
|---|---|---|
| D6 符号は `+` だけ | `FormatSign` は `default`・`plus` だけ。`-` と空白は表せず、字句で断る | 一致 |
| D8 精度 0〜28・f が必要 | `SyntaxValid` の第 3 項 | 一致 |
| D8 幅 1〜65535 | 第 2 項 | 一致 |
| D8 空の書式は誤り | `s ≠ {}`。構造体の既定値はすべて省略・false | 一致 |
| D8 寄せには幅が必要、ゼロ埋めには幅が必要で明示の寄せと併用しない、`#` は b/o/x/X だけ | 第 4〜6 項 | 一致 |
| D7・study 5.2 の 14 型の受理表 | `SupportedType`・`IntegerType`（Byte を含む八型）・`FractionalType`（三型）・`Compatible` | 表の全セルと一致。符号なしの整数への `+`、Boolean への幅・寄せを許し、Boolean への `b` を断る |
| D5 精度なしの f | `fixedPrecision`。Float 系は 6、Decimal は値の scale を使う | 一致（補助の定義だけで、判定には使わない。01-12 に明記されている） |
| D29 符号化と引数の順 | `kindCode`・`alignCode`・`signCode`、幅の省略は 0、精度の省略は −1、`constantTypes`・`parameterNames` | 一致。Integer64 の範囲に入ることを妥当性から証明している |

`CheckPredicates.lean` の `FormatExamples` は、受理表と境界を `SupportedType` などから作らずに手で列挙しており、独立した期待値になっている。

### 3. 型付け・脱糖・検査の条件の一致

- 型付け `InterpPart.Allowed` は `.formatted t s` に `s.Valid t` を求める。検査 `interpAllowed` は `formatValid t s` を求め、`interpAllowed_spec` が両者の同値を示す。交換の `InterpPart.toSurface` も `SyntaxValid ∧ Compatible`（= `Valid`）を求める。三つの入口の条件に広い・狭いの差はない。
- 頭の型は、型付け・検査とも `converterTypes` を介して `converterType t` を要求し、交換の `validateFormat` も同じ `converterType` と照合する。
- 脱糖の順序は、既存の `sequence` が全式を左から評価し、その後 `interpolate` が書いた順に変換・整形を束縛し、最後に `joinStringParts` が連結する。書式付きの分岐は書式なしの `converted` と同じく、残りの値・頭・蓄積した文字列を `(· + 1)` でずらす。CheckExamples の混在の例（書式付き String・書式なしの Integer・String の式）の期待コアは手で書かれており、束縛の下の番号を手で追って正しいことを確かめた。
- `InterpPart.count` は既存の `_ :: ps => 1 + count ps` で書式付きの部分を一つと数える。

### 4. 交換の形式

- corpus 14・sidecar 6 を受理し、それより古い版で `formatted` の欄が深い位置にあれば再生成を案内して拒否する（`Version.lean` 146 行）。`sidecarVersion` も 14→6 へ延ばしている。旧版の正例（8〜14）は `test_corpus_sidecar_generations` と `test_batch4_exchange.py` で通ることが L3 の results.md に記録されている。
- `FromJson InterpPart` は `formatted` の外側と `spec` の欄の数と名前を確かめ、欠落・余剰を省略として読まない。幅・精度は必須で、`null` だけが省略を表す。`FormatExamples.lean` は `null` と明示した 0 の書き戻しを `#guard` で確かめる。
- 組み込みの表では、`%Format.` で始まる名前を 14 型の `headName` に対応付け、固定シグネチャ・空の効果・`pure`・多相でないことを要求する。

### 5. 設計書の写し

01-12「解析済みの書式と内部の整形契約」と 07-04「01-12 との対応」の記述は、上の定義・補題名・判定の条件と一致する。【未決】【要検証】は加えられていない。新書式の ` ```text ` の例は加えておらず、plan の指示に従っている。

## 指摘

### 読めば確定するもの

#### M1（中）`formatted T` の頭が `%Format.<T>` であることを、Lean のどこでも照合していない

- 場所: `formal/Benitoite/Exchange/Convert.lean` 311〜316 行・412 行、`formal/Benitoite/Exchange/Builtins.lean` 128 行、`formal/Benitoite/Surface/CheckExamples.lean` 700 行（`typedInput`）。plan の「作業 F5」。
- 問題: D29 と plan の「受け渡す内部の契約」は、書式付きの部分の頭を `%Format.<基本型名>` と定める。しかし Lean の型付けと検査は頭の型（`converterType T`）と直接性だけを見ており、交換の読み込みも `directCallee` が `some` であることしか確かめない。`validateFormat` は組み込みの表の中の `%Format.*` の署名を照合するだけで、corpus の各部分がどの頭を使うかは照合しない。CheckExamples の `typedInput` は `%Format.String` の名前に Integer などの署名を与えて受理させており、名前と型が結び付いていないことを示している。型付けを広くしたこと自体は 01-12 が明記しており、性質 1 の正しさには影響しない。ただし F5 で Rust の表層と Rust のコアを Lean と比べるとき、Rust が同じ固定シグネチャを持つ別の頭を選んでも、Lean の検査とコアの比較は両方とも通る。組み込みの表の照合と型付けにより、別の `%Format.U` を選ぶ誤りは捕まる。残るのは、同じ署名を持つ `%Format.` 以外の頭を選ぶ誤りだけである。
- 修正案: F5 の手順に次を加える。主定理には触れない。(a) 交換の `InterpPart`・`interpolation` の変換で、書式付きの部分に対応する変換の頭が `.primName (headName T)` であることを確かめる（交換の境界の検査とし、01-12・07-04 の表の「JSON の変換と内部頭の宣言照合」の行に加える）。(b) 書式付きの部分を含む入力では、使う `%Format.<T>` が組み込みの表にあることも確かめる。(c) CheckExamples の `typedInput` に「名前と型の結び付きは交換の境界で検査する」と一行の注記を加える。

#### L1（軽）07-04 の句点の後の半角空白

- 場所: `docs/design/07-quality/07-04-formal-semantics.md` 136 行「型検査の判定の結果は信頼しない。 内部の `%Format.<基本型名>` は…」。
- 問題: 句点の後に半角空白が入っている。
- 修正案: 空白を削る。

#### L2（軽）同じ概念に複数の語を使っている

- 場所: 01-12 649 行以降と 07-04 の 136・185・297 行。
- 問題: 同じものを「固定シグネチャ」と「固定署名」（07-04 297 行）、「内部の整形頭」「内部頭」「整形頭」「整形の頭」と呼び分けている。「読取り」（07-04 297 行）も、AGENTS.md などで使う「読み取り」と表記が違う。AGENTS.md「文章の規範」は、同じ概念に別の語を使わないことを求めている。
- 修正案: 「固定シグネチャ」と「整形の頭」（初出は「内部の整形の頭」）に揃え、「読み取り」と書く。整形の頭を用語集に載せるかは取りまとめが決める。既存の「直接の呼び出しの頭」と同じ語の作りなので、新しい術語にはならないと考える。

#### L3（軽）07-04 の「同ファイルの独立した小例」が指す先があいまい

- 場所: 07-04 185 行。
- 問題: 直前の文が 01-12 への写しを述べているので、「同ファイル」が 01-12 を指すとも読める。実際の小例は `Surface/CheckPredicates.lean` の `FormatExamples` にある。
- 修正案: 「`Surface/CheckPredicates.lean` の `FormatExamples` の独立した小例で」と書く。

#### L4（軽）組み込みの表に 14 の頭がそろうことは確かめていない

- 場所: `Exchange/Builtins.lean` 128 行。
- 問題: `validateFormat` は表にある `%Format.*` を照合するだけで、14 の頭がすべてあることは求めない。L3 の範囲（照合の受け口を作る）としては足りている。F3 で頭を登録した後の確認先が決まっていない。
- 修正案: F3 または F5 で、Rust の書き出した組み込みの表に 14 の頭がすべてあることを確かめる独立の検査を加える（M1 の (b) とまとめてよい）。

### 実行しないと分からないもの

#### L5（軽）旧版の拒否は木の全体のキーを探す

- 場所: `Exchange/Version.lean` 146 行（`rejectFields ["formatted"]`）。
- 問題: 旧版の入力の任意の深さで、キー `formatted` を持つオブジェクトを拒否する。利用者の名前（レコードの欄の名前など）を JSON のキーに使う欄が交換にあれば、版 13 以前の正しい入力を誤って拒否しうる。既存の `block` などの拒否も同じ方式であり、既存の正例はすべて通っている。利用者の名前をキーに使う欄があるかどうかは、この差分を読んだだけでは確かめきれなかった。
- 修正案: F5 で、Rust の書き出しに利用者の名前を JSON のキーに使う欄がないことを確かめる。あれば `mapField` と同じく既知の欄だけを辿る形に改める。再現するまで規則は変えない。

#### L6（軽）書式付きの String が `stringExpr` に落ちる誤りは、Lean の入口だけでは捕まらない

- 場所: D30、`formal/tests/batch5-exchange/README.md`。
- 問題: Lean は `stringExpr` と書式付きの String の両方を受理する。Rust が書式付きの String を `stringExpr` として書き出し、コアも書式なしで作ると、比較は一致する。L3 の独立入力は Lean の側で両方の形を確かめているが、Rust の出力を照合するモードは F5 で加える予定である。
- 修正案: F5 の Rust の出力を照合するモードで、書式付きの String のソースから `formatted` が出ることを件数とともに確かめる（plan の F5「新構成が対象外へ落ちた件数を確認」に、`stringExpr` へ落ちた件数も含める）。

## 段 V へ進む判断

進んでよい。段 I の完了の条件（既定ビルドが `sorry` なしで通ること、主な定理の前提と結論を変えないこと、公理を増やさないこと、型付け・脱糖・検査の条件をそろえること、01-12・07-04 に写すこと）は、読んだ範囲で満たされている。M1・L4〜L6 は F3・F5 の手順に加える申し送りとする。L1〜L3 は文書の小さな修正であり、段 V の作業のどれかで直せばよい。

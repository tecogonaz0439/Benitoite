# C6c-1: Decimal・リストの展開・文字列補間の差分検査

2026-10-10 に実装・検査した。C6a-1 の定義に合わせ、交換形式、Rust のテスト内の書き出し、形式化用の生成器、Lean の比較器を広げた。`Surface/`・`Release`・`Core`、処理系の本番のコード、設計書、検査スクリプトには変更がない。コミットはしていない。

## 入力と比較単位

ゴールデン入力は C5c-2 と同じ探索規則で収集する。無作為な入力は `generate_formal` の種 0〜999 の 1,000 件である。**無作為の入力は C5c-2 と同じではない。** C5 の入力に、Decimal・展開・補間を使う関数を加えた。入力は型検査・脱糖まで処理し、実行しない。

比較単位は C5 と同じであり、利用者の関数、実装メソッド、実装ごとの上位辞書を別々に比べる。標準ライブラリの関数の本体は比較しない。比較器の `functions` はこれらを合わせた単位数である。対象外の単位が一つでもあれば、そのプログラムは対象外に数える。対象内の単位は同じプログラムのほかの単位から独立して比べる。

## 交換形式と書き出しの対応

`Corpus.version` を **3 から 4 に上げた**。Decimal 定数と表層の新しい構成子を追加したためである。新版の比較器は旧版の入力を受け付けない。定義・宣言表の欄は変更していない。`Surface.Program` などの構造体は既存も含め欄名を指定して作る。

| 場所 | 今回加えた表現 |
|---|---|
| 表層とコアの定数 | `Const.decimal(mantissa, scale)` |
| 表層の直接の負号 | `Expr.negDecimal(mantissa, scale)` |
| 表層の展開 | `listSpread(elem, concat, before, spread, after)` |
| 補間の部分 | `text(value)`・`stringExpr`・`converted(ty)` |
| 表層の補間 | `interpolation(parts, es, converters)` |

### Decimal の係数と小数の桁数

リテラルには非負の係数を入れる。括弧を挟まない直接の負号は `negDecimal` とし、負号を付ける前の非負の係数と桁数を入れる。型検査器が `e.id` に記録した負の値と `l.id` に記録した正の値を照合してから書き出す。`-0.0m` は係数 0・桁数 1 の `negDecimal` であり、正のリテラルと表層で区別できる。括弧を挟む `-(1.50m)` は従来の `neg` と `paren` を使う。

Lean の変換は、負の係数を持つ表層の `literal decimal` と `negDecimal` を誤りにする。コアの係数には負の値を許し、符号を反転した係数と同じ桁数を比較する。Rust の i128 の仮数は `serde_json` の `arbitrary_precision` により JSON の数として保持する。Decimal の値の正規化や桁数の省略は行わない。Decimal パターンは形式化されていないため、式とは別の理由 `Decimal pattern` で対象外にする。

### リストの展開

表層の要素を、展開前の要素・展開式・展開後の要素に分ける。`concat` は処理系が参照する `Benitoite.List.concatenate` の束縛から決め、`Fn` は `funName`、`BuiltinFn` は宣言にある組み込みの名前の `primName` とする。型引数は要素の型一つ、エフェクト引数は宣言のエフェクトパラメータの個数分の空の集合である。現在の標準ライブラリは `@builtin` である。

差分検査は `desugarDef` で定義ごとに行うため、concat の定義を比較するプログラムの Σ に足す必要はない。空の側の concat を省く判断と評価順は Lean と Rust の脱糖に任せ、比較前に展開式をコアへ書き換えない。

### 文字列補間

Rust の `head` は最初の `text` に、各 `segment` は式の部分と後続の `text` に写す。型検査の `interp_types` が `String` なら `stringExpr`、それ以外の許される基本型なら `converted T` とする。式の並び `es` は全式に順に対応し、`converters` は `converted` にだけ順に対応する。変換する呼ぶ値は `table::interpolation_builtin` から求めた組み込みの名前の `primName name [] []` である。

空の head・tail も `text ""` として保持する。Rust と Lean が脱糖で空の断片を省くことをそのまま比べる。連結は既存の `operators()` と `makeOpPrim` を使い、`%String.add` と `opPrim (.binary .add) (.base .string)` を対応させる。Lean の変換では、式と変換関数の個数、converted の型、呼ぶ値が直接の頭であることも検査する。

補間の全式を評価した後、String 以外の変換を順に行い、その後に連結する形を比較する。最後の連結を末尾の計算として残すことも比較対象である。ラムダのエフェクトの走査は、展開の前の要素・展開式・後の要素・concat の頭、補間の全式・変換の頭の順に広げた。頭には既存の `headLambdaEffects` を使い、値化しない直接の辞書付きの頭をラムダとして数えない。

## 比べる前に捨てた情報

今回追加した構成について新たに捨てた情報は、数値リテラルの綴りと、Rust の head/segment という区切り方である。Decimal の係数・桁数・直接の負号の区別、補間の空の断片・式の型・式順・変換関数の対応、展開前後の要素順・展開式・concat の種類と型引数は保持する。

コアの省略と名前の換算は C5c-2 までの方式を維持した。型検査済みのコアの各計算・値に付く型、由来・表示名・スパン・ラムダの BodyId を省く。関数の頭、型引数とエフェクト引数、値引数と辞書の順、ラムダの引数型とエフェクトは比較に残す。エフェクトは集合として同じ原子順に揃える。コアにだけ残る対象外の印は不一致にし、表層の対象外へ戻して隠さない。

## 生成器と既存の generate の保存

formal 専用の関数を `generate_formal` からだけ呼び、専用の種 `seed ^ 0xc6c1` で値と入れ子のラムダの位置を選ぶ。Decimal の正のリテラル・直接の負号・負のゼロ・最大仮数とその負号・括弧を挟む負号、展開の先頭・途中・末尾・両側とも空、補間の 7 つの型・空の断片・連続する式・有効な部分が 1 を含む。Byte は `Byte.fromInteger` を `match` し、`Option.Some` の枝で取り出す。展開の前後の要素・展開式と補間式の中にラムダを置き、その注釈の走査も比べる。

部分数は、空でない text と式の合計であり、空の text は部分数を増やさない。「連続する式」は空の text を挟む式も含む。部分が 0 の補間は構文解析器が作らないので、生成しない。件数 0 を明示し、その構成について不一致 0 とは主張しない。

変更前に段 1〜6・種 0〜999 の `generate` のソースと coverage を保存し、変更後も同じ順で保存して `cmp` で完全一致を確認した。6,000 件の SHA-256 は両方とも次のとおりである。

```text
af00826584b5cfc83321073cd7cde273853d9e7c08ca5e4def2bd8b242ee0fb5
```

確認用のソース・実行ファイル・出力は `target/desugar-diff/c6c-1/` に置いた。

## 最終の差分検査の結果

| 入力 | プログラム一致 | プログラム対象外 | 型検査等で除外 | 単位一致 | 単位対象外 | 不一致 |
|---|---:|---:|---:|---:|---:|---:|
| ゴールデン（523） | 218 | 40 | 265 | 416 | 55 | 0 |
| 無作為（1,000） | 1,000 | 0 | 0 | 46,218 | 0 | 0 |
| 合計（1,523） | 1,218 | 40 | 265 | 46,634 | 55 | 0 |

比較できた 46,634 単位の内訳は次のとおりである。対象外の 55 単位を含めた総数は 46,689 である。型検査等で除外した入力の定義数は計数しない。

| 入力 | 関数 | 実装メソッド | 上位辞書の単位 |
|---|---:|---:|---:|
| ゴールデン | 404 | 4 | 8 |
| 無作為 | 26,218 | 10,000 | 10,000 |

Rust の書き出しの表示は exported 1,235・out of scope 23・excluded 265 であった。比較できる単位が一つでもあれば exported と数えるため、プログラムの分類は Lean の表示と異なる。

### 今回追加した構成の比較件数

次の表の値は「箇所数 / その構成を含む比較単位数」である。件数が 0 の欄は未比較であり、その構成の一致を主張しない。

| 構成 | ゴールデン（箇所 / 単位） | 無作為（箇所 / 単位） |
|---|---:|---:|
| Decimal literal | 0 / 0 | 3,000 / 1,000 |
| Decimal direct negation | 0 / 0 | 3,000 / 1,000 |
| Decimal direct negative zero | 0 / 0 | 1,000 / 1,000 |
| spread: first | 0 / 0 | 1,346 / 1,000 |
| spread: middle | 0 / 0 | 1,000 / 1,000 |
| spread: last | 0 / 0 | 1,367 / 1,000 |
| spread: before empty | 0 / 0 | 1,346 / 1,000 |
| spread: after empty | 0 / 0 | 1,367 / 1,000 |
| spread: both empty | 0 / 0 | 1,287 / 1,000 |
| interpolation | 15 / 13 | 8,000 / 1,000 |
| interpolation: text | 19 / 11 | 3,000 / 1,000 |
| interpolation: empty text | 13 / 9 | 23,000 / 1,000 |
| interpolation: String | 6 / 6 | 5,000 / 1,000 |
| interpolation: Integer | 10 / 7 | 6,000 / 1,000 |
| interpolation: Float | 0 / 0 | 1,000 / 1,000 |
| interpolation: Character | 0 / 0 | 1,000 / 1,000 |
| interpolation: Boolean | 1 / 1 | 1,000 / 1,000 |
| interpolation: Byte | 0 / 0 | 1,000 / 1,000 |
| interpolation: Decimal | 0 / 0 | 3,000 / 1,000 |
| interpolation: consecutive expressions | 0 / 0 | 9,000 / 1,000 |
| interpolation: parts 0 | 0 / 0 | 0 / 0 |
| interpolation: parts 1 | 2 / 2 | 4,000 / 1,000 |
| interpolation: parts 2+ | 13 / 11 | 4,000 / 1,000 |
| interpolation: parts 2 | 7 / 5 | 1,000 / 1,000 |
| interpolation: parts 4 | 2 / 2 | 0 / 0 |
| interpolation: parts 3 | 4 / 4 | 1,000 / 1,000 |
| interpolation: parts 5 | 0 / 0 | 1,000 / 1,000 |
| interpolation: parts 7 | 0 / 0 | 1,000 / 1,000 |

展開の四つの形の箇所数の合計は無作為の 5,000 である。「先頭」は前だけ空、「末尾」は後ろだけ空と同じ構成を別のラベルで表示する。「両側とも空」はそれらへ重ねて数えない。呼ぶ値は `primName` が 5,000、`funName` が 0 であり、今回の入力では Fn の場合を比較していない。ゴールデンでは展開も Decimal のリテラル・負号も比較できていない。これらを含む関数には、定数参照・リストパターンなどの対象外の構成が残るためである。

補間の有効な部分数の分布は、ゴールデンが 1: 2、2: 7、3: 4、4: 2、無作為が 1: 4,000、2: 1,000、3: 1,000、5: 1,000、7: 1,000 である。空の断片・部分数・式の種類は脱糖前の交換表現から数えており、コアから推測しない。「連続する式」の箇所数は隣接する式の組の数である。部分が 0 は両方 0 件で、構文解析から到達しない構成として未比較である。Byte は無作為の 1,000 箇所・1,000 単位を比較した。

### 引き続き比較した C5 までの構成

| 構成 | ゴールデン（箇所 / 単位） | 無作為（箇所 / 単位） |
|---|---:|---:|
| methName: empty U | 70 / 24 | 30,000 / 12,000 |
| DictEv.impl | 122 / 19 | 79,000 / 9,000 |
| methName: empty U direct: call | 66 / 22 | 4,000 / 3,000 |
| DictEv.local | 10 / 7 | 116,000 / 15,000 |
| funDicts | 6 / 4 | 27,000 / 6,000 |
| funDicts direct: call | 6 / 4 | 3,000 / 2,000 |
| implementation method | 4 / 4 | 10,000 / 10,000 |
| implementation supers unit | 8 / 8 | 10,000 / 10,000 |
| DictEv.super | 4 / 3 | 4,000 / 1,000 |
| implementation superclass dictionary | 1 / 1 | 2,000 / 2,000 |
| methName: nonempty U | 0 / 0 | 21,000 / 2,000 |
| methName: nonempty U parenthesized: placeholder | 0 / 0 | 5,000 / 2,000 |
| funDicts parenthesized: call | 0 / 0 | 3,000 / 2,000 |
| methName: empty U parenthesized: pipe rule 2 | 0 / 0 | 2,000 / 2,000 |
| funDicts direct: pipe rule 1 | 0 / 0 | 2,000 / 1,000 |
| funDicts parenthesized: pipe rule 1 | 0 / 0 | 2,000 / 1,000 |
| funDicts direct: placeholder | 0 / 0 | 4,000 / 1,000 |
| funDicts direct: placeholder pipe rule 2 | 0 / 0 | 2,000 / 1,000 |
| funDicts parenthesized: placeholder | 0 / 0 | 4,000 / 1,000 |
| funDicts parenthesized: placeholder pipe rule 2 | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U direct: call | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U direct: pipe rule 1 | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U parenthesized: call | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U parenthesized: pipe rule 1 | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U direct: placeholder | 0 / 0 | 4,000 / 1,000 |
| methName: nonempty U direct: placeholder pipe rule 2 | 0 / 0 | 2,000 / 1,000 |
| methName: nonempty U parenthesized: placeholder pipe rule 2 | 0 / 0 | 2,000 / 1,000 |
| methName: empty U direct: pipe rule 1 | 0 / 0 | 1,000 / 1,000 |
| methName: empty U parenthesized: call | 0 / 0 | 1,000 / 1,000 |
| methName: empty U parenthesized: pipe rule 1 | 0 / 0 | 1,000 / 1,000 |
| methName: empty U direct: placeholder | 0 / 0 | 2,000 / 1,000 |
| methName: empty U direct: placeholder pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| methName: empty U parenthesized: placeholder | 0 / 0 | 2,000 / 1,000 |
| methName: empty U parenthesized: placeholder pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| methName: empty U direct: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| funDicts direct: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| funDicts parenthesized: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| methName: nonempty U direct: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| methName: nonempty U parenthesized: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |

### 対象外の理由

理由は同じ単位・プログラムに重なるため、合計は対象外の総数と一致しない。無作為の対象外は 0 である。

| 理由 | ゴールデンの単位 | ゴールデンのプログラム |
|---|---:|---:|
| field | 25 | 20 |
| record | 23 | 18 |
| constant reference | 8 | 7 |
| alternative | 4 | 4 |
| list pattern | 7 | 7 |
| guard | 5 | 5 |
| range pattern | 3 | 3 |
| record pattern | 4 | 4 |

既知の `known: try in placeholder argument`・`known: resume in placeholder argument`、`Byte literal`・`Decimal pattern`・`higher kind: unsupported constructor` は今回の両群とも 0 件である。

### 出力と所要時間

最終のコーパスは `target/desugar-diff/c6c-1/final/corpus.json`、機械可読な結果は同じディレクトリの `report.json`、スクリプトの全出力は `target/desugar-diff/c6c-1/check-formal.log` に保持した。スクリプトは終了状態 0 で成功した。

| 段 | スクリプトの時間表示 |
|---|---:|
| lake build | 0 秒（構築済み） |
| lake build desugarDiff | 3 秒 |
| Rust export（cargo を含む） | 337 秒 |
| desugarDiff | 12 秒 |
| 表示の合計 | 352 秒（約 5 分 52 秒） |

Rust の入力処理の表示は 328.415 秒、テスト全体は 335.58 秒である。最初の証明本体の再構築は 12 秒で成功した。書き出し中に、部分数ごとの計数を追加した比較器を再構築した（16 jobs 成功）。スクリプトの比較段はこの最終の実行ファイルを使っており、実際の全出力・report.json に部分数ごとの内訳を含む。


## 不一致と既知の差

**なし。** 比較器が不一致を報告した入力はなかった。(a) 処理系の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化・書き出しの不足のいずれにも分類する反例はなかった。処理系・Lean の脱糖の定義は修正していない。

実装中のコンパイルエラーは、交換形式の型検査で `Release.Ty` の BEq を使った点と、計数で fromJson? の型注釈の括弧を誤った点の二つであり、Exchange の基本型名の検査と型注釈の修正で解消した。これらはコーパスの比較で出た不一致ではない。

C4・C5 の `known: try in placeholder argument` と `known: resume in placeholder argument` の判定は維持する。新しい構成の対象外理由をこれらへまとめていない。レコード・定数参照・パターンの対象外も今回外していない。

## 検査

| 検査 | 結果 |
|---|---|
| `scripts/check-formal.sh` | 成功、比較単位の不一致 0 |
| `formal/` で `lake build` | 成功、69 jobs、sorry の警告なし |
| `formal/` で `lake build desugarDiff` | 成功、16 jobs |
| `cargo fmt --check` | 成功 |
| `cargo clippy -p benitoite --all-targets -- -D warnings` | 成功、警告なし |
| `scripts/check.sh --base HEAD --dry-run` | rust・formal を選択、長いテスト・check-heap の選択なし |
| `scripts/check.sh --base HEAD --only formal` | 成功、all checks passed |
| `git diff --check` | 成功 |
| `generate` の 6,000 件のソースと coverage | cmp で完全一致 |
| 交換形式の境界の一時の Lean #guard | 6 件成功 |

共通検査の rust は Skill の生成物と本番コードの bundle.rs を書き直すため、今回の編集範囲を守って選択しなかった。Rust の通常テスト全体・gc-stress・Skill 再生成はこの作業では実行していない。完了条件の fmt・clippy・formal 差分検査は実行済みである。HTTP のソケット bind の失敗は今回の検査にはなかった。

境界の確認は `target/desugar-diff/c6c-1/Validate.lean` を `lake env lean` で実行した。負の係数の Decimal リテラル・negDecimal の拒否、負のゼロと大きな係数の受理、converted String の拒否、補間の式数の不一致の拒否を確認した。formal のソースに sorry・admit の宣言はなく、証明本体にも変更はない。

test-audit の作成時の関門は既存の差分検査の拡張として通した。独立した Lean の脱糖との一致が契約であり、型が付く誤った束縛順・変数番号・変換や連結の選択を検出する。既存のコア型検査や VM と参照実行器の比較ではこの契約を検査できず、本番コードへの差し込み口も追加していない。既存のテストの削除はない。

## C6a-2・C6a-3 で範囲を広げるときの注意

- レコードでは、表層の record・field・record pattern の判定とコアに残る対象外の印を同じ変更で更新する。書いた順の評価と宣言順への並べ替え、更新しないフィールドの環境、括弧付きのフィールドの値化・パイプ・穴の呼び出しを別々に検査する。
- `Surface` の構造体に欄が増えたら、`Input.operationProgram` の欄名付きの構築に必要な表を足す。今回の Exchange はレコードの表を作っていない。交換形式に必須欄や構成子を足す際は version 4 から上げるかを決める。
- 定数では、表層の定数参照とコアの `ConstRef` を同時に広げる。今回の `Const.decimal` は値のリテラルの対応であり、トップレベルの定数参照や構造を持つ定数を対象にしたものではない。空の環境の本体を使用位置へ移すときの局所変数・辞書の番号と `C`・`R` の扱いを検査する。
- 新しい式の子と呼ぶ値について `lambdaEffects` と構成別の計数を同時に広げる。直接の頭と値化する頭を分け、ラムダの注釈を省かない。今回の concat・変換関数の書き出しは現在の標準ライブラリの選択を写すものであり、一般的な呼ぶ値すべての入力を試したものではない。
- 0 件の構成について一致を主張しない。補間の部分が 0 の場合は処理系の構文解析から到達しない。Decimal パターン・Byte リテラルは引き続き対象外である。既知の try・resume のプレースホルダ引数の差は別の課題として保つ。

## C6c-2: レコードとフィールドを取り出す関数

2026-10-10 に C6a-2 の定義に合わせて差分検査を広げた。以下は C6c-2 の結果であり、上の C6c-1 の記録は変更していない。

### 入力と交換形式

ゴールデン入力の探索規則は従来どおりである。無作為入力は `generate_formal` の種 0〜999 の 1,000 件である。**無作為の入力は C6c-1 と同じではない。** レコードの宣言と専用の二つの関数を追加した。入力は型検査・脱糖まで処理し、実行しない。

`Corpus.version` を **4 から 5 に上げた**。表層の構築・更新・パターンと、本体の AST を持たない取得関数の比較単位を追加したためである。新版の比較器は旧版のコーパスを受け付けない。

| 場所 | 追加した形 |
|---|---|
| 構築 | `Expr.record(name, tys, positions, args)` |
| 更新 | `Expr.recordUpdate(name, tys, n, positions, base, args)` |
| パターン | `Pattern.record(name, n, positions, args)` |
| 構成子の宣言 | `RecordConDecl { data, ntys, args }` |
| 取得関数の比較単位 | `Scope.accessor(name, con, k, decl, core)` |

構築・更新の `positions` は、名前解決済みの各フィールドの `BindingId` を、ADT の `record` の宣言順の位置に変換する。位置は 0 から数える。`args` は書いた順を保ち、Lean の `recordFields` に並べ替えを任せる。構築は全フィールドを指定するため、総数は `positions.length` である。更新の `n` は全フィールド数であり、`tys` は `base` の型引数を使う。式の評価順は `base`、書いたフィールドの順である。

交換形式から表層への変換では、構築の位置が `range args.length` の置換であることを確認する。更新では空でないこと、位置と子の個数の一致、位置の重複がないこと、範囲内であることを確認する。パターンも位置と子の個数の一致・重複・範囲を確認する。これらは処理系の型検査を通った入力を交換形式へ移す条件の検査であり、Lean の表層の型付けを追加して検査するものではない。

### パターンの束縛番号の対応

レコードのパターンは、子を宣言位置の順に辿って環境へ束縛を積む。書き出した各子は元の添字に保存し、JSON の `args` は書いた順に戻す。入れ子の子でも同じ処理を繰り返す。分岐の本体はこの環境を使って書き出す。コア側は既存の `CorePat` の照合順の走査を使う。したがって、表層・コアとも宣言順の束縛を末尾から数え、**別の番号の対応表は保持しない**。

例えば、宣言順が `first, second, third` で、パターンが `R(third: z, first: x, second: y)` なら、対応は次のとおりである。

| 束縛 | 処理系がソースを辿って積む順 | 書き出しの環境の順 | 比較する de Bruijn の番号 |
|---|---:|---:|---:|
| z | 0 | 2 | 0 |
| x | 1 | 0 | 2 |
| y | 2 | 1 | 1 |

外側の宣言順が `inner, tail` で、ソースが `Outer(tail: t, inner: R(third: z, second: y, first: x))` なら、ソースの束縛順 `t,z,y,x` は照合順 `x,y,z,t` へ対応する。本体の番号は `x=3,y=2,z=1,t=0` となる。未指定のフィールドは Lean が `_` にし、束縛を増やさない。

### 取得関数の表とコアの比較

利用者の `DefKind::FieldGetter { record, index }` を `definitions()` に追加した。`record` の構成子は `con_name(record, 0)`、取得関数名は `fun_name(d.binding)`、`k` は `index` である。構成子の宣言にはデータ名、型パラメータ数、宣言順のフィールド型を入れる。処理系のコアの頭・本体・ラムダのエフェクトの書き出しは、通常の関数と共通の `core_definition` を使う。

Lean は対象内の取得関数単位から `Program.cons` と `Program.accessors` を作り、`defs` を空にした表層のプログラムを `desugarProgram` に渡す。その結果の `defs name` を引いて処理系の定義と比較するため、`lookupFun` を通して `accessorDef` を生成する経路も検査する。表の名前の重複、位置の範囲、同じ構成子に対する宣言の整合も確認する。宣言のエフェクトは既存の集合としての正規化を適用して照合する。

表に入れるのは、比較する利用者の取得関数に限る。標準ライブラリの取得関数の宣言は追加しない。呼び出しの `BindingKind::Field` は通常の `Fn` と同じ `funName(fun_name(id), tys, effs)` にし、処理系の `TopFn` と名前を揃える。通常の関数の脱糖は呼ぶ関数の宣言を検索しないため、標準ライブラリの取得関数の呼び出しもこの形で比較できる。

`Expr::Record`、レコードのパターン、制約なしのフィールド名の対象外判定を外した。レコード構成子を名前として値化する形、位置引数で呼ぶ形、辞書を持つ `constrained head: field` は従来の判定を残す。コアの構成子・パターン・`TopFn` は既存の書き出しで表せる。取得関数も同じコアの走査を使い、コアに残る `unsupported` を不一致として扱う。

### ラムダのエフェクトと捨てた情報

`Expr.lambdaEffects` に構築の全引数、更新の `base` と全引数を追加した。Rust の表層の走査も同じ順で子を処理する。コアの `Core::comp`・`value` の走査は従来どおりであり、実際のラムダのエフェクトを収集する。生成入力には、構築と全更新の中に純粋なラムダと State のラムダを置き、自由変数の移動も比較する。

今回新たに捨てた情報は、レコードとフィールドのソースでの表示名、パターンの末尾の `..` の有無である。表示名は構成子名・関数名と宣言位置に換算し、`..` が示す未指定の位置は `n` と `positions` で表す。書いた順、宣言位置、全フィールド数、型引数、束縛の参照、関数名、ラムダのエフェクト、処理系が実際に作った本体は保持する。コアの型注釈・由来・スパンなどの省略は従来と同じである。

### 生成器と既存の generate の保存

`generate_formal` からだけ呼ぶ `formal_records` を追加した。専用の乱数源は `seed ^ 0xc6c2` であり、値、構築の指定順、一部の更新位置、入れ子のパターンの指定順を選ぶ。レコードは多相の三フィールドの型、これを入れ子にする型、純粋・State の関数を持つ型を宣言する。多相の関数内での構築と更新、一部・全部の更新、一部のフィールドのパターン、入れ子のパターン、宣言順と異なる束縛、フィールドの関数値を取り出した呼び出しを比較する。

取得関数の名前について、直接の呼び出し、括弧に入れて局所変数へ保存する `(R.f)`、括弧付きの呼び出し、裸の名前と空引数の呼び出しを右辺にするパイプ、プレースホルダ、括弧付きのプレースホルダ、プレースホルダを右辺にするパイプを生成する。

通常の `generate` の乱数源・分岐・宣言は変更していない。変更前に段 1〜6・種 0〜999 の 6,000 件のソースと coverage を `Generated` の Debug 表示で保存し、最終の変更後も同じ順・同じ表示で保存した。`cmp` で完全一致した。両方の SHA-256 は次のとおりである。このハッシュは今回の保存形式に対するものであり、C6c-1 の記録のハッシュと直接比較するものではない。

```text
3bd5375353a92f9897de56404d5680d2a4e991e727d155e06f10aeb166c861dd
```

確認用のソース・実行ファイル・出力は `target/c6c2/` に保持した。

### 最終の差分検査の結果

| 入力 | プログラム一致 | プログラム対象外 | 型検査等で除外 | 単位一致 | 単位対象外 | 不一致 |
|---|---:|---:|---:|---:|---:|---:|
| ゴールデン（523） | 240 | 18 | 265 | 467 | 20 | 0 |
| 無作為（1,000） | 1,000 | 0 | 0 | 55,218 | 0 | 0 |
| 合計（1,523） | 1,240 | 18 | 265 | 55,685 | 20 | 0 |

`functions` は通常の関数・実装メソッド・上位辞書・取得関数の比較単位を合わせた数である。対象外の単位を含むプログラムでも、対象内の単位は独立して比較する。

| 入力 | 通常の関数 | 実装メソッド | 上位辞書の単位 | 取得関数 |
|---|---:|---:|---:|---:|
| ゴールデン | 435 | 8 | 8 | 16 |
| 無作為 | 28,218 | 10,000 | 10,000 | 7,000 |

構成別の件数は、比較した単位の表層から数えた箇所数と、その構成を一つ以上含む単位数である。複数の分類は重なり、全体の単位数とは合計が一致しない。パターンの「reordered」は指定位置の列が昇順でないもの、「nested」は別のレコードパターンの子にあるものを数える。取得関数の呼び出し形の集計は、比較対象の利用者の取得関数名を使う。標準ライブラリの取得関数の呼び出しは通常の関数の本体として比較するが、この取得関数名別の集計には含めない。`parenthesized value` は呼び出しの頭やパイプ右辺にある括弧も含むため、括弧付きの呼び出し形の件数と重なる。

| 構成 | ゴールデン（箇所 / 単位） | 無作為（箇所 / 単位） |
|---|---:|---:|
| record construction | 19 / 15 | 4,000 / 2,000 |
| record construction: reordered | 0 / 0 | 3,509 / 2,000 |
| record update: partial | 6 / 6 | 2,000 / 2,000 |
| record update: all | 0 / 0 | 3,000 / 2,000 |
| record update: reordered | 0 / 0 | 2,667 / 2,000 |
| record pattern | 5 / 2 | 8,000 / 2,000 |
| record pattern: partial | 3 / 2 | 3,000 / 1,000 |
| record pattern: nested | 0 / 0 | 2,000 / 1,000 |
| record pattern: reordered | 0 / 0 | 3,986 / 2,000 |
| accessor definition | 16 / 16 | 7,000 / 7,000 |
| accessor definition: polymorphic | 1 / 1 | 5,000 / 5,000 |
| accessor direct: call | 10 / 8 | 2,000 / 2,000 |
| accessor parenthesized: call | 0 / 0 | 1,000 / 1,000 |
| accessor direct: pipe rule 1 | 0 / 0 | 1,000 / 1,000 |
| accessor parenthesized: pipe rule 1 | 0 / 0 | 1,000 / 1,000 |
| accessor direct: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| accessor parenthesized: pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| accessor direct: placeholder | 0 / 0 | 2,000 / 1,000 |
| accessor parenthesized: placeholder | 0 / 0 | 2,000 / 1,000 |
| accessor direct: placeholder pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| accessor parenthesized: placeholder pipe rule 2 | 0 / 0 | 1,000 / 1,000 |
| accessor parenthesized value | 0 / 0 | 6,000 / 1,000 |

0 件の欄ではその構成の一致を検査していない。0 件について「不一致 0」とは主張しない。今回の無作為群は表にある各構成を実際に比較している。

### 対象外の理由

理由は同じ単位・プログラムに重なる。型検査等で除外した入力の定義は数えない。

| 理由 | ゴールデンの単位 | ゴールデンのプログラム | 無作為の単位 | 無作為のプログラム |
|---|---:|---:|---:|---:|
| constant reference | 8 | 7 | 0 | 0 |
| alternative | 4 | 4 | 0 | 0 |
| list pattern | 7 | 7 | 0 | 0 |
| guard | 5 | 5 | 0 | 0 |
| range pattern | 3 | 3 | 0 | 0 |

### 出力と時間

コーパスと機械可読な結果は `target/desugar-diff/run-23625/corpus.json` と `target/desugar-diff/run-23625/report.json`、スクリプトの全出力は `target/c6c2/check-formal.log` に保持した。終了状態は 0 である。書き出し中に宣言のエフェクト照合の正規化を揃えて比較器を再ビルドし、比較段は最終の実行ファイルを使った。

```text
lake build: 1s
lake build desugarDiff: 0s
desugar export: 1251 exported, 7 out of scope, 265 excluded (check error); 1523 inputs; 387.233s; target/desugar-diff/run-23625
Rust export (including cargo): 396s
golden programs: matched=240 mismatched=0 outOfScope=18 excluded(check error)=265
golden functions: matched=467 mismatched=0 outOfScope=20 excluded(check error)=0
random programs: matched=1000 mismatched=0 outOfScope=0 excluded(check error)=0
random functions: matched=55218 mismatched=0 outOfScope=0 excluded(check error)=0
desugarDiff: 15s; report: target/desugar-diff/run-23625/report.json
```

スクリプトが表示した段ごとの時間の合計は 412 秒（約 6 分 52 秒）である。書き出し中の比較器の再ビルドはこの時間内で行った。

### 不一致・既知の差・検査

**不一致はなし。** (a) 処理系の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化・書き出しの不足に分類するコーパスの反例はなかった。本番の脱糖と Lean の表層の定義・証明は変更していない。

実装中のビルドでは、Lean の `filterMap` に対する括弧と、Rust の更新元の型引数が `TypeArg` でなく `Ty` である点を直した。最初の無作為入力はエフェクト付きラムダに戻り型の注釈がないため構文検査で失敗し、生成テンプレートに `-> Integer` を加えた。これらは比較器が報告した不一致ではない。

C4・C5 の `known: try in placeholder argument` と `known: resume in placeholder argument` は対象外判定を維持する。定数参照、ガード・選択肢・範囲・リスト・Decimal パターン、Byte リテラル、形式化していない型構成子、辞書を持つフィールドの頭なども引き続き対象外である。これらの判定へ新しいレコードの構成をまとめて除外していない。

| 検査 | 結果 |
|---|---|
| `scripts/check-formal.sh` | 成功、不一致 0 |
| `formal/` で `lake build` | 成功、sorry の警告なし |
| `formal/` で `lake build desugarDiff` | 成功 |
| `cargo fmt --check` | 成功 |
| `cargo clippy -p benitoite --all-targets -- -D warnings` | 成功、警告なし |
| `scripts/check.sh --base HEAD --dry-run` | rust・formal を選択、長いテスト・check-heap の選択なし |
| `scripts/check.sh --base HEAD --only formal` | 成功、all checks passed |
| `git diff --check` | 成功 |
| `generate` の 6,000 件のソースと coverage | cmp で完全一致 |
| 交換形式の位置の境界の一時の Lean #guard | 10 件成功 |

共通検査の rust は Skill の生成物と本番の `bundle.rs` を書き直すため、編集範囲を守って選択しなかった。Rust の通常テスト全体・gc-stress・Skill 再生成は実行していない。HTTP のソケット bind の失敗は今回の検査にはなかった。`formal/` の Lean ソースには `sorry`・`admit` がなく、証明の本体にも変更はない。

境界の確認は `target/c6c2/Validate.lean` を `lake env lean` で実行した。正しい逆順の構築・パターン、一部の更新を受け付け、重複・範囲外・子の個数の不一致・空の更新を拒否することを確認した。

`test-audit` の作成時の関門は既存の差分検査の拡張として通した。独立して証明した Lean の脱糖との一致が契約であり、評価順、フィールドの並べ替え、束縛の番号、取得関数の生成の退行を検出する。型の付く誤った脱糖は既存のコア型検査や VM と参照実行器の比較では検出できない。本番の API やテスト専用の差し込み口は追加していない。既存のテストの削除、本番コードの変更はない。

### C6a-3（定数）と C7（パターンの拡張）の注意

- 定数参照では、表層の参照とコアの `ConstRef` の対象外判定を同時に広げる。空の環境の定数の本体を使用位置へ移す扱いを、構築・更新の引数と `base`、取得関数の引数、入れ子のパターンの本体、ラムダの中でも適用する。自由変数と辞書の番号、ハンドラの型変数、`C`・`R` の注釈を省かない。
- `Program`・`Declarations` の構築は欄名を指定する形を保つ。定数の欄を足した後も、取得関数の `cons`・`accessors` と `lookupFun` の経路を維持する。交換形式の構成子や必須欄が増えたら版 5 から上げるかを決める。
- C7 のレコード内のリスト・範囲・選択肢のパターンでも、宣言順の子を再帰的に辿る環境の作り方を保つ。選択肢の同じ束縛への参照と、リストの残りの束縛、展開した行と分岐の対応を同時に扱う。現在のコアの走査は行と分岐が一対一で、ガードがない場合に限る。
- 新しい構成の子を `lambdaEffects` と構成別の集計にも追加する。現在の取得関数の呼び出し形の集計は、利用者の比較対象の取得関数だけを数える。標準ライブラリも名前別の件数へ含める場合は、宣言表とは分けて名前の判定を広げる。
- 0 件の構成について一致を主張しない。位置の重複など型検査を通らない入力への Lean と処理系の脱糖の違いは、この型検査済みの差分検査の範囲に含めない。

## C6c-3: トップレベルの定数

2026-10-10 に C6a-3 の定義と P5 に合わせて差分検査を広げた。以下は C6c-3 の結果であり、既存の節は変更していない。

### 入力と交換形式

ゴールデン入力の探索規則は従来どおりである。無作為入力は `generate_formal` の種 0〜999 の 1,000 件である。**無作為の入力は C6c-2 と同じではない。** 基本型・リスト・レコード・別の定数を参照する定数の宣言と、専用の二つの関数を追加した。入力は型検査と脱糖まで処理し、実行しない。

`Corpus.version` を **5 から 6 に上げた**。必須の `Input.constants` と、表層の参照 `Expr.constName(name)` を追加したためである。新版の比較器は旧版のコーパスを受け付けない。表の項目は `ConstantEntry { name, ty, body }` である。名前は `BindingId` を `const:<番号>` に変換したもので、`ty` は宣言の注釈型、`body` は表層の式である。本体の中の参照も名前だけを書き、JSON に本体を重ねて埋め込まない。

Rust は各定数を一度ずつ書き出す。定数ごとの本体は `Surface::new(p, None, Vec::new())` と空の局所環境で変換する。使用位置の `type_order`・`clause_types`・戻り型・プレースホルダの文脈を引き継がない。注釈型と本体の型情報に `Ty::Param`・`Ty::App`・`TyHead::Param`・`Ty::Rigid` が現れたら書き出しの誤りとして停止する。定数本体の範囲判定を依存先へ再帰し、得た理由を名前ごとに覚えて参照元の比較単位へ伝える。依存先も含めて対象内の定数だけを交換表へ出す。

Lean の `Input.constantCache` は表の名前の重複を拒否し、`expandConstant` が依存先を先に変換する。展開中の名前の集合で循環を検出し、欠落した名前もエラーにする。完成した `.constE ty body` は名前ごとに一度だけキャッシュへ入れる。各 `constName` はその値を返すため、同じ定数の参照に別々の注釈や本体を持たせられない。使用位置の環境を変換に渡さない。

### ConstRef の置き換えと正規化

コアの書き出しは、`CompKind::Return(v)` で `v.kind` が `ConstRef(binding)` の場合に限って、その計算全体を同じ BindingId の `ConstDef.body` の書き出しで置き換える。本体の中の `Return(ConstRef(...))` も再帰的に置き換える。空の局所環境と新しい型変換の文脈を使うため、`State::new` が使用位置と重なる番号を振っていても、de Bruijn の番号は定数本体の内部だけで決まる。閉じた本体なので番号のずらしは行わない。コアの循環や定義の欠落も書き出しの誤りとして停止する。

呼び出しの引数、構成子のフィールド、リストの要素などでは、処理系の `eval` が `Return(ConstRef)` を先に `let` へ束縛する。その左辺の計算だけを置き換えると、Lean の `.constE` が `.other` で本体を脱糖し、`sequence` が `let` を作る形と一致する。末尾の参照も本体の `.other` の脱糖に置き換える。

**意味を変える正規化は追加していない。** `let` の結合則・単位則、原子的な値の束縛の省略は行わない。従来のエフェクトの集合としての順序の正規化だけを維持する。

`Return` の直下以外の `ConstRef` は値の書き出しで検出し、`constant reference outside Return` という専用の理由で対象外として数える。それ以外のコアに残る `unsupported` は対象内の不一致として残す。既存の表層の `constant reference` の対象外判定を外す変更と、コアのこの検査を同時に行った。

### ラムダのエフェクトと捨てた情報

Exchange の `Expr.lambdaEffects` は `constName` の本体を同じ表から辿る。各参照の位置ごとに本体の注釈を収集し、共有した定数の二回目以降の参照も省かない。Rust は `ConstDef.body` を展開する同じコアの走査でラムダの注釈を収集し、表層と同じ順に比較する。現在のソース言語の定数式はラムダを本体に書けないため、定数本体内のラムダの注釈の比較は交換形式の境界確認で行った。生成入力のラムダの中にある定数参照は、実際の差分検査で比較した。

今回新たに捨てた情報は、定数の表示名と、処理系が定数の評価器で先に求めた `ConstDef.value` である。表示名は BindingId による名前へ換算し、比較には計算である `ConstDef.body` を使う。定数表の注釈型は保持するが、`.constE` の脱糖後には残らない。コアの型注釈・スパン・由来・変数数の省略は従来と同じである。定数の単独の宣言は比較単位に追加せず、対象内の関数等からの参照で展開した計算を比較する。

### 生成器と既存の generate の保存

`generate_formal` からだけ呼ぶ `formal_constants` を追加した。専用の乱数源は `seed ^ 0xc6c3` であり、整数・小数の値、真偽値、レコードの指定順を選ぶ。Integer・Boolean・Float・Decimal・String・Character・Unit の定数、整数のリスト、レコード、レコードのリストを宣言する。算術を含む整数定数、別の定数への参照、その別名、同じレコードを二回使うリストによって依存先の再帰展開と再参照を検査する。

参照位置は、呼び出しの引数、位置引数の構成子のフィールド、レコードのフィールド、リストの要素、純粋・State のラムダの内部、レコードの更新元、局所束縛の下である。多相な関数の本体でもリストとレコードの定数を参照する。型と局所変数の使用位置への依存を持ち込まずに本体を展開できるかを検査する。

通常の `generate` の乱数源・分岐・宣言は変更していない。変更前に段 1〜6・種 0〜999 の 6,000 件のソースと coverage を `Generated` の Debug 表示で保存し、変更後も同じ順と形式で保存した。`cmp` で完全一致した。両方の SHA-256 は次のとおりである。

```text
3bd5375353a92f9897de56404d5680d2a4e991e727d155e06f10aeb166c861dd
```

確認用のソース・実行ファイル・出力は `target/c6c3/generator_snapshot.rs`、`generator_snapshot`、`generate-before.txt`、`generate-after.txt` に保持した。

### 最終の差分検査の結果

| 入力 | プログラム一致 | プログラム対象外 | 型検査等で除外 | 単位一致 | 単位対象外 | 不一致 |
|---|---:|---:|---:|---:|---:|---:|
| ゴールデン（523） | 247 | 11 | 265 | 475 | 12 | 0 |
| 無作為（1,000） | 1,000 | 0 | 0 | 57,218 | 0 | 0 |
| 合計（1,523） | 1,247 | 11 | 265 | 57,693 | 12 | 0 |

`functions` は通常の関数・実装メソッド・上位辞書・取得関数の比較単位を合わせた数である。対象外の単位があるプログラムでも、対象内の単位は独立して比較する。

| 入力 | 通常の関数 | 実装メソッド | 上位辞書の単位 | 取得関数 |
|---|---:|---:|---:|---:|
| ゴールデン | 443 | 8 | 8 | 16 |
| 無作為 | 30,218 | 10,000 | 10,000 | 7,000 |

構成別の件数は、実際に比較した単位の表層を定数参照の本体まで辿った箇所数と、その構成を一つ以上含む単位数である。定数の本体の参照は使用のたびに数える。「nested」は別の定数の本体で参照した箇所である。位置の分類は祖先の構成に基づくので重なるが、閉じた定数の本体へは使用位置のラムダ・局所束縛などの文脈を引き継がない。「constructor field」は位置引数の構成子と、レコードの構築・更新のフィールドを含む。単位数や全体の件数との合計は一致しない。

| 構成 | ゴールデン（箇所 / 単位） | 無作為（箇所 / 単位） |
|---|---:|---:|
| constant reference | 30 / 8 | 61,000 / 2,000 |
| constant: basic | 23 / 7 | 54,000 / 2,000 |
| constant: list | 3 / 2 | 3,000 / 2,000 |
| constant: record | 0 / 0 | 4,000 / 2,000 |
| constant: data | 0 / 0 | 0 / 0 |
| constant: nested | 10 / 5 | 43,000 / 2,000 |
| constant: call argument | 8 / 4 | 2,000 / 1,000 |
| constant: constructor field | 1 / 1 | 14,000 / 2,000 |
| constant: list element | 4 / 1 | 10,000 / 2,000 |
| constant: lambda | 0 / 0 | 2,000 / 1,000 |
| constant: record update base | 0 / 0 | 1,000 / 1,000 |
| constant: under local binding | 2 / 1 | 16,000 / 1,000 |
| constant: other type | 4 / 2 | 0 / 0 |

0 件の欄ではその構成の一致を検査していない。ゴールデン群のレコード定数・ラムダ内の参照・レコードの更新元、両群のリスト・レコード以外の data 型の定数、無作為群のその他の型の定数について「不一致 0」とは主張しない。指定された参照位置と入れ子の定数は、無作為群ですべて 0 件を超えて比較できた。既存の構成の全件数は `report.json` とスクリプトの全出力に保持した。

### 対象外の理由

理由は同じ単位とプログラムに重なる。型検査等で除外した入力の定義は数えない。

| 理由 | ゴールデンの単位 | ゴールデンのプログラム | 無作為の単位 | 無作為のプログラム |
|---|---:|---:|---:|---:|
| alternative | 4 | 4 | 0 | 0 |
| list pattern | 7 | 7 | 0 | 0 |
| guard | 5 | 5 | 0 | 0 |
| range pattern | 3 | 3 | 0 | 0 |
| constant reference | 0 | 0 | 0 | 0 |
| constant reference outside Return | 0 | 0 | 0 | 0 |

`constant reference` の従来の除外は残っていない。`constant reference outside Return` は実際のコーパスでは 0 件であり、後述の境界テストでこの形の拒否と理由を確認した。

### 出力と時間

最終のコーパスと機械可読な結果は `target/desugar-diff/c6c3-final/corpus.json` と `report.json`、スクリプトの全出力は `target/c6c3/check-formal-final.log` に保持した。最終コードでスクリプトを最初から最後まで実行し、終了状態は 0 である。以下は最終出力の数と段ごとの時間である。

```text
lake build: 0s
lake build desugarDiff: 0s
desugar export: 1256 exported, 2 out of scope, 265 excluded (check error); 1523 inputs; 426.790s; target/desugar-diff/c6c3-final
Rust export (including cargo): 436s
golden programs: matched=247 mismatched=0 outOfScope=11 excluded(check error)=265
golden functions: matched=475 mismatched=0 outOfScope=12 excluded(check error)=0
random programs: matched=1000 mismatched=0 outOfScope=0 excluded(check error)=0
random functions: matched=57218 mismatched=0 outOfScope=0 excluded(check error)=0
desugarDiff: 17s; report: target/desugar-diff/c6c3-final/report.json
```

スクリプトが表示した段ごとの時間の合計は **453 秒（約 7 分 33 秒）**である。先行実行でも同じ数のプログラム・単位が一致し、不一致は 0 件だったが、上の時間と保存先は最終コードの再実行を指す。

### 不一致・既知の差・検査

**不一致はなし。** (a) 処理系の脱糖の誤り、(b) Lean の定義の誤り、(c) 正規化・書き出しの不足に分類する実際のコーパスの反例はなかった。本番の脱糖、Lean の表層の定義と証明、Release と Core は変更していない。

実装中のビルドでは、定数表を渡す変換の引数、Lean の `Expr` の名前の曖昧さ、Rust の `expr` の引数の数を直した。境界テストの準備コードには必要な `return` を追加し、末尾位置で `Return(ConstRef)` になるコアを使った。これらは差分比較器が報告した不一致ではない。

C4・C5 の `known: try in placeholder argument` と `known: resume in placeholder argument` は対象外判定を維持する。ガード・選択肢・範囲・リスト・Decimal パターン、Byte リテラル、形式化していない型構成子、辞書を持つフィールドの頭なども引き続き対象外である。定数本体がこのような対象外の構成を持つ場合は、その具体的な理由を参照元へ伝え、定数参照全般の除外にまとめない。

| 検査 | 結果 |
|---|---|
| `scripts/check-formal.sh` | 成功、不一致 0 |
| `formal/` で `lake build` | 成功、sorry の警告なし |
| `formal/` で `lake build desugarDiff` | 成功 |
| `cargo fmt --check` | 成功 |
| `cargo clippy -p benitoite --all-targets -- -D warnings` | 成功、警告なし |
| `scripts/check.sh --base HEAD --dry-run` | rust・formal を選択、長いテスト・check-heap の選択なし |
| `scripts/check.sh --base HEAD --only formal` | 成功、all checks passed |
| `git diff --check` | 成功 |
| `generate` の 6,000 件のソースと coverage | cmp で完全一致 |
| 交換形式の境界の一時の Lean #guard | 10 件成功 |
| Rust の `export_rejects_constref_in_value_position` | 成功、最終の check-formal でも実行 |

共通検査の rust は Skill の生成物と本番の `bundle.rs` を書き直すため、編集範囲を守って選択しなかった。Rust の通常テスト全体・gc-stress・Skill 再生成は実行していない。HTTP のテストは実行していない。`formal/Benitoite` と `formal/DesugarDiff` の Lean ソースには sorry・admit の宣言がなく、証明の本体にも変更はない。

交換形式の境界は `target/c6c3/Validate.lean` を `lake env lean` で実行して確認した。欠落した名前、自己循環、相互循環、重複した名前を拒否し、前方参照を受け付ける。前方参照を展開した計算は独立した期待値の整数の return と一致する。共有する定数への二回の参照でラムダの注釈を二回収集する。13 定数の依存 DAG では、名前ごとに一つの値をキャッシュへ入れ、交換 JSON の本体は二つの名前の参照のまま保つことを確認した。

追加した Rust 境界テストは、型検査済みのソースの脱糖出力を受け取り、`Return(ConstRef)` を `Escape(ConstRef)` に変え、対象外の理由が `constant reference outside Return` になることを確かめる。別の書き出し漏れである束縛されていないコア変数に変えると、対象内の `unsupported` のまま残ることも確かめる。この変形は書き出しの境界だけを検査するもので、本番の脱糖の不一致ではない。

`test-audit` の作成時の関門は、既存の差分検査の拡張と交換形式の境界の検査として通した。独立して証明した Lean の脱糖との一致が契約であり、定数本体と使用位置の変数・型の番号の混同、展開位置、入れ子の参照、ラムダの注釈の順の退行を検出する。コア型検査や VM と参照実行器の比較では型の付く誤った脱糖を検出できない。境界テストは現在の脱糖では生じない ConstRef の位置の拒否を検査し、通常の差分入力では届かない失敗を検出する。本番の API やテスト専用の差し込み口は追加していない。既存のテストの削除、本番コードの変更はない。

### C7（パターンの拡張）の注意

- 表層のパターンとコアの対象外の印を同じ変更で更新する。定数参照の処理とは別に、現在の行と分岐の一対一の対応とガードなしの制限を見直す。選択肢の展開で行が増えた場合や、ガード・リストの残りの束縛がある場合に、判定の漏れを対象外の理由へ戻して隠さない。
- レコードの子の束縛は宣言順に辿る既存の方式を保つ。選択肢の同じ束縛、リストの要素と残りの束縛、入れ子のパターン内の変数を、表層とコアの両方で同じ de Bruijn の番号へ写す。分岐の本体にある定数の本体は、引き続き空の環境で展開する。
- 定数表の名前と注釈型・本体の共有、循環と欠落の拒否を保つ。現行の ConstRef の位置の前提を変えるなら、専用の対象外理由の件数を確認し、計算を値の位置へ挿入する規則を決める。正規化が必要になった場合は、両側の同じ規則と意味への影響を記録する。今回のコアは参照ごとに本体の計算を展開して JSON に書くため、表層の定数表の共有だけでコア出力の大きさまで抑えるものではない。
- 新しいパターンが持つ式やガード、分岐の本体を、ラムダのエフェクトの走査と構成別の集計にも追加する。現在の定数の位置の件数は祖先の構成による分類であり、パターンの形式を分類するものではない。
- `Surface` の構造体は欄名付きで作る。交換形式の必須欄・構成子を足した場合は版 6 から上げるかを決める。0 件の構成について一致を主張しない。型検査を通らない入力の脱糖は、型検査済みのこの差分検査の対象に含めない。

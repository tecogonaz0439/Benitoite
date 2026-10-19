# Result の Monad2・推す書き方・関数内の構築器の調査

2026-10-18 の S2 の調査である。対象は docs/todo の TODO-164・021・248。S2 の開始版は `6cb18610f4a24f5bd564c57504de50b6cd91ca79`、ブランチは `mod009/design` である。0.0.8 公開後の `6b0568a3ddcc46b0a0e64504139ce286a27fd86a` との差は S1 の文書4件だけであり、以下の処理系・現行設計・formal の行番号は両版で同じである。項目の写しは [todo-items.md](../todo-items.md)、選択肢は [問い](monad2-and-builders-questions.md) に置く。推す案は未回答であり、現行仕様や採用済みの判断を表さない。

版全体の13件と TODO-191 を除く範囲は設計者の指定に従う。S1 の [A・C の調査](checked-values.md) とは、作り方を隠す型、形式化の先行、版全体の検査の割り当てで接続する。前回の [改造の記録](../../2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/README.md) と study の形は調査・判断・計画を分ける参考にした。現行規則の根拠には現在の設計書と実装を使う。

## 推す最初の範囲

B は `Benitoite.Trait` に型クラス（type class）`Functor2`・`Applicative2`・`Monad2` を追加し、成功値を第1引数、保つ型を第2引数とする。標準の実装は `Result` から始め、利用者も自分の二引数の型に実装できるようにする。型構成子（type constructor）の部分適用、型ラムダ（type lambda）、do 記法、既存の `Monad` の改名は加えない。この範囲は既存の高カインド型（higher-kinded type）と辞書渡し（dictionary passing）で表せる見込みである。

021 では、具体的な型を扱う普通のスクリプトには `List.map`・`Option.andThen`・`Result.andThen` などを推し、型を抽象化する関数では必要な型クラスを使う。`try … or return`・`or die` の選択は失敗時の処置で決める。辞書の費用は未分離なので、速度の優劣をこの推奨の理由にしない。

D は `StringBuilder`・`ListBuilder[T]`・`BytesBuilder` という局所名の分類と専用操作を設け、既存の `Reference` と不変値へ展開する案を推す。すべての操作に `State` を残す。構築器を通常値として使わず、専用の直接呼び出しだけに許す。取り出しは、その後の追記で変化しない通常値を返す。物理的なコピーの必須性は B5 の判断に分ける。

この案には、局所エフェクトを消す規則、寿命や領域の型変数、ネイティブの可変バッファ、容量予約を含めない。構築器の表層からの展開は新しい脱糖（desugaring）なので、Release を保っても形式化の仕事は残る。推す範囲では型付き表層の局所名と展開を Lean にも入れ、ソースの名前解決は Rust に残す。実装前にその範囲と工数を B10 で決める。

## 現行の型クラス・Result・辞書

パスはリポジトリの根から示す。表のリンクはファイルを、行番号は調査開始版の位置を指す。

| 確かめたこと | ファイルと行 | 今回への含意 |
|---|---|---|
| `Show.show`、`Order.compare`、`Semigroup.combine`、`Monoid.empty` がある | [Trait.bnt](../../../../crates/benitoite/src/prelude/stdlib/Trait.bnt) 10〜32行 | 021 は map だけの問題ではない。表示・比較・結合も推奨を揃える |
| `Functor.map`、`Applicative.pure/apply`、`Monad.flatMap` は一引数の F を取る。コールバックの効果を保つ | 同ファイル35〜52行 | 二引数版でも名前・引数の契約を揃え、型引数を一つ増やす |
| `Foldable.fold` と `Traversable.traverse` がある。traverse の G は一引数の Applicative である | 同ファイル55〜64行・481〜493行 | `Monad2[Result]` を加えても既存の traverse の G に Result は渡せない |
| Option と List に上記五クラスの実装がある。map・fold・Option の flatMap は既存関数へ委ねる。List の flatMap は補助関数で順に連結する | 同ファイル394〜494行 | 型クラスと既存関数の重複は現行の構成である |
| Result は成功型が先、エラー型が後である。`map`・`mapError`・`andThen`・`unwrapOr`・`ok` がある | [Result.bnt](../../../../crates/benitoite/src/prelude/stdlib/Result.bnt) 4〜63行 | 現在の関数名は `Result.andThen` である。`Result.flatMap` があると説明しない |
| Option に `map`・`andThen`・`unwrapOr`・`okOr` がある | [Option.bnt](../../../../crates/benitoite/src/prelude/stdlib/Option.bnt) 10〜55行 | 成功値を写す操作と、次の Option を返す操作を分ける |
| List に append・concatenate・map・filter・fold・forEach がある | [List.bnt](../../../../crates/benitoite/src/prelude/stdlib/List.bnt) 24〜113行 | 構築器を作らずに一括処理する現行の選択肢がある |
| 完全適用した別名は展開後の型と等しい。型引数を省いた別名を型構成子としては使えない | [01-06](../../../design/01-spec/01-06-type-system.md) 43行・201〜209行 | `type R[A, X] = Result[A, X]` は新しい実装の対象となる型構成子を作らない |
| `F[_, _]` は二引数の型構成子を表す。引数の数は一致が必要で、部分適用はない | 同章416〜422行、[decls.rs](../../../../crates/benitoite/src/typeck/decls.rs) 450〜546行、[solve.rs](../../../../crates/benitoite/src/typeck/solve.rs) 668〜683行 | 二引数クラスの宣言は現行の規則に沿う。`F[_]` への Result の推論は追加されない |
| 上位クラスも引数の数を照合する | [collect.rs](../../../../crates/benitoite/src/typeck/traits/collect.rs) 65〜85行・226〜248行 | `Monad2` の上位は同じ二引数の `Applicative2` とする |
| 同じクラスと型構成子の実装は高々一つ。クラスか対象型を宣言したモジュール以外の実装を禁じる | [01-06](../../../design/01-spec/01-06-type-system.md) 441〜453行、[impls.rs](../../../../crates/benitoite/src/typeck/traits/impls.rs) 36〜105行 | 別名ごとの別辞書、import 順による実装の選択、局所的な上書きを加えない |
| 制約付き関数は辞書を値引数より先に受け取り、型ごとの関数複製はしない。値化したメソッドは辞書を捕捉するラムダになる | [02-06](../../../design/02-impl/02-06-ir-and-lowering.md) 119〜132行、[dicts.rs](../../../../crates/benitoite/src/ir/desugar/dicts.rs) 7〜144行・166〜225行 | `Monad2` も同じ経路を使う。新しい辞書選択方式は不要である |
| 0.0.8 は操作・節にも辞書を渡す。節の辞書を束縛に写し、宣言の個数と型をコア検査する | 同章125〜130行、同 Rust ファイル49行以降、[07-04](../../../design/07-quality/07-04-formal-semantics.md) 219行 | 操作の辞書は部分適用の代わりにはならない |

操作の型パラメータは値の型であるという制限を保つ。`function[F[_, _]: Trait.Monad2]` のような通常関数と、`effect` の操作に同じ高カインド引数を加える変更は区別する。今回、後者は含めない。試作の Dictionaries.lean の `OpPacket` は高カインドの M を持つ広いモデルなので、その成功を現行の操作宣言が受理する証拠に数えない。

## Reference・State と構築の費用

| 確かめたこと | ファイルと行 | 今回への含意 |
|---|---|---|
| new・get・set・update はすべて State を持つ。update の f は純粋である | [Reference.bnt](../../../../crates/benitoite/src/prelude/stdlib/Reference.bnt) 3〜17行、[reference.rs](../../../../crates/benitoite/src/builtins/funcs/reference.rs) 8〜38行 | 構築器の読み取りや取り出しも State を持つ |
| State は操作のないエフェクトであり、handle で消せない | [01-07](../../../design/01-spec/01-07-effects.md) 187〜202行・295行 | 局所だからと State を取り除くことは現行規則にない |
| Reference の実行は既存のストアのセルを読む・置き換える規則である | [Semantics.lean](../../../../formal/Benitoite/Release/Semantics.lean) 186〜203行 | 不変値を入れるセルへの展開なら新しい可変バッファの実行規則を要しない |
| String の `+` は両方の断片を新しい領域へ写す。合計長を確保前に検査する | [operators.rs](../../../../crates/benitoite/src/builtins/funcs/operators.rs) 280〜284行、[ctx.rs](../../../../crates/benitoite/src/runtime/heap/ctx.rs) 455〜463行、[core.rs](../../../../crates/benitoite/src/runtime/heap/core.rs) 390〜415行 | 長さが増える文字列への反復追記は累積のコピーを減らさない |
| String.join は合計長を先に求めてから組み立てる | [string.rs](../../../../crates/benitoite/src/builtins/funcs/string.rs) 175〜206行 | 断片の List が既にある場合の比較対象となる |
| List の append は最大32要素の末尾葉や木の経路を作り、concat は木構造を結合する。空の片側をそのまま返す場合もある | [list.rs](../../../../crates/benitoite/src/runtime/list.rs) 195〜239行 | 不変リストの追記を毎回の全体コピーと見なさない |
| Bytes.concatenate は両入力を新しいバイト列へ写す | [bytes.rs](../../../../crates/benitoite/src/builtins/funcs/bytes.rs) 133〜143行 | Ref[Bytes] を更新するだけでは、反復連結の二乗の費用をなくせない |

ここでいう二乗の費用は、等しい長さの断片を n 回追記すると、コピーする長さの合計が `1 + 2 + … + n` に比例するという実装からの見積もりである。新たな性能測定ではない。List にこの計算をそのまま当てはめない。

現在に近い [0.0.8 の性能記録](../../../../tools/bench/results/2026-10-18-1c545d8f5c5d.md) は、Apple M4、10回の中央値、コミット `1c545d8f5c5d` を対象にする。95行の string は run 0.317160秒、検査を差し引いた近似0.306076秒、71行の list は2.249250秒／2.238046秒、121行の trait は2.259450秒／2.248098秒である。278行の string の累積確保量は758,195,168バイト、275行の list は1,342,467,200バイトである。いずれも S2 開始版の再測定値ではない。

これらは連結だけの費用を測っていない。[string.bnt](../../../../tools/bench/programs/string.bnt) 22〜24行は repeat・二度の `+`・split、[list.bnt](../../../../tools/bench/programs/list.bnt) 22〜25行は range・map・filter・fold、[trait.bnt](../../../../tools/bench/programs/trait.bnt) 14〜25行は整数の Step メソッドを呼ぶ反復である。trait と loop の差を、そのまま辞書渡しの費用にしない。Bytes の反復連結と、型クラス版 map 対直接版 map の同条件の比較は、今回読んだ記録にない。

[Bytes と List[Byte] の外部境界の記録](../../../../tools/bench/results/2026-10-13-typed-list-f8a7470e.md) 9〜15行では、6 MB の Bytes 経路が27.0〜27.4 ms、List[Byte] が52.6〜53.0 ms だった。これはハッシュ処理と境界を含む測定であり、連結や構築器の速さではない。同記録17行のとおり32 MiB を一度に List[Byte] に直すと要素数の上限に当たる。BytesBuilder を全量の List[Byte] に展開して済ませる案も、既存 Bytes と同じ範囲を保てない。

## 試作の証拠と採用範囲の違い

試作は docs/todo の sources/2026-10-17-feasibility-spikes の164・248を読んだ。非公開なのでリンクしない。findings.md と対応する Lean の定義・言明を照合したが、再実行していない。各ファイルは `import Std` の独立モデルであり、formal/ との接続の成功を示していない。

### 164 の部分適用と二引数辞書

Restricted.lean は、穴一つの型構成子について、`subst_plug`・`shift_plug` と代入の合成を証明する。Normalization.lean は閉じた値の種類の型式を正規形へ評価し、比較成功から正規形の等号を導く。`raw_sound_impossible` は簡約前の式まで等しいとは言えない反例である。Reduction.lean と RejectedStructural.lean は、種類を制限しない自己適用と、代入結果へそのまま構造再帰する定義の問題を示す。これを「型ラムダは実装不能」と読むのは誤りである。

Dictionaries.lean の `BinaryMonadDict` は、A と X をメソッド側に持ち、`M A X` の成功値だけを写す。`binary_map_result` は直接の Result.map との一致を示す。純粋な Result の三つの Monad の法則も示すが、`badDict` は同じ辞書型を持っても法則に従わない実装を作れることを示す。型検査を通ることと法則の成立は別である。

findings.md 冒頭の「最初は穴一つの部分適用を推す」は試作担当の提案であり、その後の設計者の「Release を保つ二引数クラス」の方針と異なる。今回の具体物は後者の三クラス・Result の辞書・使用例である。部分適用の試作を取り込む作業にはしない。透明な別名で引数順を替えるだけでは、一引数の Monad へ渡せないという反例も、この選択を支える。

### 248 の局所性と State を残す展開

LocalBuilder.lean は通常値と構築器名の文脈を分け、`world_frame`・`local_mask_sound`・`erase_clean` を証明した。通常の State も消す案は `bad_mask_counterexample` で否定した。`copyExample_runs` は取り出し済みの列が後の追記で変化しない例である。共有セルは一つ、コマンドは有限で、ハンドラ・保存継続・タスク・再帰を含まない。

Escape.lean の `generic_escape_counterexample` は具体化前の型だけを見る検査、`signature_only_counterexample` は関数の引数型と戻り値型だけを見る検査の不足を示す。`ordinary_subst` は、代入する型も通常型であるという条件を要する。`shallow_snapshot` は、リストの構造が安定しても要素のセルへの書き込みは見えることを示す。Regions.lean は領域の名前を単射で付け替える条件と、潜在エフェクトまで見る必要を示す。

Lowering.lean の `lower_preserves` は、一つの構築器と追記・コピーを、不変リストと let に直す限定した変換の意味保存である。Reference を使う本番の変換を証明したものではない。LocalBuilder.lean の `state_fallback_sound` と合わせて、新しい隔離の定理を要しない案を検討する材料となる。

今回作る案は三種類の局所名・専用操作・持ち出し検査・State 付き展開・診断と文書である。試作が見積もったネイティブ局所文脈案の30〜60ファイル・80〜220件の定義や補題は、この初版の件数ではない。コピーと局所性だけで TODO-248 の当初の高速化まで完了したとは扱わない。

## 他の言語の一次資料

以下は2026-10-18に取得して内容を確認した資料である。前例の API と、Benitoite への推す判断を区別する。

| 前例 | 確認した事実と出典 | Benitoite での判断材料 |
|---|---|---|
| fp-ts | [Monad の公式 API](https://gcanti.github.io/fp-ts/modules/Monad.ts.html) に Monad1・Monad2・Monad2C 等があり、Monad2 は Applicative2 と Chain2 を継承する。[Chain の公式ソース](https://github.com/gcanti/fp-ts/blob/master/src/Chain.ts#L37-L45) は通常版で E をメソッド側、2C 版でクラス側に固定する | 引数の数ごとに分ける実在の前例である。fp-ts の E,A の順を Benitoite の A,X へ読み替える。TypeScript の型の符号化を移植する必要はない |
| Haskell | [base 4.22.0.0 の Control.Monad.ST](https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Control-Monad-ST.html#v:runST) の runST は `(forall s. ST s a) -> a`。文書は全称量化が内部状態への外部からのアクセスを防ぐと説明する | 通常の State を無条件に消す前例にはならない。今回、領域の全称量化や runST 相当を導入しない |
| Rust | [String](https://doc.rust-lang.org/std/string/struct.String.html#method.push_str) は push_str・reserve を持ち、[into_bytes](https://doc.rust-lang.org/std/string/struct.String.html#method.into_bytes) は自身を消費しコピーせず変換する。[Vec の保証](https://doc.rust-lang.org/std/vec/struct.Vec.html#guarantees) は容量を持ち、push の償却 O(1) を約束するが成長率は固定しない | バッファ更新による性能の前例である。既存の不変値をセルへ入れるだけではこの保証を得ない。消費して渡す API は今回の再利用可能な取り出しと異なる |
| OCaml | [5.4 の Buffer](https://ocaml.org/manual/5.4/api/Buffer.html) は自動拡張と add_string を持つ。contents と to_bytes はコピーを返し、元のバッファを変えないと明記する | 取り出した後も追記できる契約の比較対象となる。Benitoite の関数内限定の規則まで備えた前例とはしない |
| Scala | [2.13.16 の公式 StringBuilder ソース](https://github.com/scala/scala/blob/v2.13.16/src/library/scala/collection/mutable/StringBuilder.scala#L24-L38) は可変の文字列構築器を定義する。91〜102行に addOne・addAll・clear・result/toString があり、結果は underlying.toString へ委ねる | 操作と取り出しの名前を比べられる。このファイルだけから、内部のコピー量や関数外への持ち出し禁止を主張しない |

fp-ts の master は可変の参照であり、継続して実装判断の根拠に使うときは対象の版を固定する。今回の記述は取得した内容の確認であり、将来の API の保証ではない。Scala の API サイトは取得できなかったため、固定タグの公式ソースを確認した。

## Monad2 の API と重複の扱い

次は提案の宣言である。現行版で実行した例ではない。X は保つ値の型、E はコールバックのエフェクト変数である。

```text
public trait Functor2[F[_, _]]
  function map[A, B, X, effect E](x: F[A, X], f: function(value: A) -> B uses E) -> F[B, X] uses E
end trait

public trait Applicative2[F[_, _]: Functor2]
  function pure[A, X](x: A) -> F[A, X]
  function apply[A, B, X, effect E](fs: F[(function(value: A) -> B uses E), X], x: F[A, X]) -> F[B, X] uses E
end trait

public trait Monad2[F[_, _]: Applicative2]
  function flatMap[A, B, X, effect E](x: F[A, X], f: function(value: A) -> F[B, X] uses E) -> F[B, X] uses E
end trait
```

apply の関数型は括弧で囲む。現行の解析では `uses E, X` を効果の並びとして最長一致で読むため、括弧なしでは X が第2の型引数にならない（[parser/types.rs](../../../../crates/benitoite/src/syntax/parser/types.rs) 239〜332行）。新しい構文で解決せず、既存の区切り方を使う。

Result の map と flatMap はそれぞれ既存の `Result.map` と `Result.andThen` に委ね、pure は Ok を返す。apply は fs が Error ならそのエラー、fs が Ok で x が Error なら x のエラー、両方が Ok なら関数を一度適用する。引数式そのものはソース順に評価済みであり、「エラーなら後の引数式を評価しない」とは約束しない。複数エラーを集める意味は加えない。

flatMap の前後で X を保ち、異なるエラー型の暗黙の和や変換をしない。必要なら Result.mapError で型を揃える。純粋な f に対する法則と、エフェクトを持つ f の呼び出し回数・順序は分けて確認する。任意の利用者実装の法則を型検査で証明する仕様にはしない。

一引数の `Monad` と二引数の `Monad2` は別の制約であり、暗黙には変換しない。標準クラスと具体型の関数の重複に加え、引数の数によるクラスの重複も、[設計原則5](../../../design/00-overview/00-01-goals.md) の例外として理由を記録する案を推す。理由は、既存の型の規則を保って Result を抽象化するためである。Foldable2・Traversable2・Bifunctor・Monad3 などを同時に増やす根拠にはしない。

透明な別名を、独立した実装を選ぶ名前として扱わない。現行ではそもそも引数付き別名の裸の名前を型構成子に渡せないため、`Monad2[Alias]` を今回だけ許可する変更も加えない。完全適用した別名を値の型に使う場合は元の Result と同じ実装を使う。別の意味を選ぶ必要があるなら別の data 型を宣言し、そのモジュールに実装する。

利用者の成功型が先の二引数 ADT は対象にできる。エラー型が先の Either 相当の型にはそのまま適合せず、引数順を替えた透明な別名では回避できない。標準に Either の重複型や変換のラッパーは追加しない。一引数版向けの汎用関数を利用したければ、その関数を二引数制約で書き直すか、閉じたエラー型の別 data を明示的に作る必要が残る。

## 同梱の Skill で推す書き方

| 場面 | 推す書き方 | 理由 |
|---|---|---|
| List・Option・Result が具体的に決まっている | List.map/fold、Option.map/andThen、Result.map/andThen/mapError | 不要な import とクラスの選択を減らし、既存の例へ揃える |
| 一つの関数を複数の一引数容器で使う | 最小限の Functor・Applicative・Monad・Foldable の制約 | 値の型に依存しない操作であることを契約に書ける |
| 成功型が先の二引数容器を抽象化する | 対応する Functor2・Applicative2・Monad2 | Result 専用関数で表せない抽象化に限定して使う |
| 失敗を呼び出し元へ返す／実行を終える | try … or return／or die | クラスの連結と、関数や実行を終える処置を混同しない |
| 人が読む通常の表示・並べ替え・結合 | 数の toString、文字列補間、List.sort、具体型の結合 | Show はコードに近い表示、Order は全順序など、完全な同義でないものを機械的に置き換えない |
| 利用者の型の表示や汎用の比較・結合 | 必要なら Show・Order・Semigroup・Monoid を使う | 具体関数の型で受けられないときにクラスを使う |

既存関数を隠したり非推奨にしたりしない。型クラスを使っている既存コードを一括で直すことも推さない。推奨を手書きの [Skill](../../../../crates/benitoite/skill/SKILL.md) と [idioms](../../../../crates/benitoite/skill/references/idioms.md) に置き、全 API の説明は生成した参照に残す。特に Order[Float] は NaN を扱う全順序であり、組み込み比較と無条件に交換できない（Trait.bnt 214〜223行）。Result の Monad 化から Failure.toResult や try の優先順位変更を導かない。TODO-260 の案内の修正とは、失敗を扱う説明の語と例を照合する。

## 構築器の宣言・操作・持ち出し禁止

名前の案は、明示的に import する `Benitoite.StringBuilder`・`Benitoite.ListBuilder`・`Benitoite.BytesBuilder` とする。prelude へは入れない。これらは普通の型の別名や公開レコードではなく、関数内の宣言にだけ書ける局所の分類である。S1 の `@opaque` は作り方を隠せても、値の受け渡しや捕捉を禁じないため、構築器の局所性の代用にはならない。

推す表記は既存の bind の形を使う。ただし専用の new と型注釈の組を、通常値の束縛とは別に検査する。新しい予約語は加えない。次は案の例であり、現行版では受理されない。

```text
import Benitoite.StringBuilder

function snapshots(names: List[String]) -> Pair[String, String] uses State
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "names: ")
  StringBuilder.appendAll(builder: b, texts: names)
  bind before <- StringBuilder.copy(b)
  StringBuilder.append(builder: b, text: "\n")
  return Pair(before, StringBuilder.copy(b))
end function
```

List の宣言は `bind b: ListBuilder[Integer] <- ListBuilder.new()`、Bytes は `bind b: BytesBuilder <- BytesBuilder.new()` とする。名前 b を通常値として推論させない。new の値化、部分適用、別の関数を通した作成、構築器名の別名束縛、型の別名を使った局所型の隠蔽は初版では拒否する。import の別名は、同じ専用の束縛に解決される場合に限り同じ扱いとし、文字列としての名前の一致では判定しない。

| 専用操作の案 | StringBuilder | ListBuilder[T] | BytesBuilder |
|---|---|---|---|
| new() | 空の文字列 | 空のリスト | 空のバイト列 |
| append(builder, …) → Unit | text: String | value: T | value: Byte |
| appendAll(builder, …) → Unit | texts: List[String]。区切りなしで順に追加 | values: List[T] | bytes: Bytes |
| copy(builder) | String | List[T] | Bytes |
| 長さを得る | byteLength(builder) → Integer | length(builder) → Integer | length(builder) → Integer |

表は操作の契約を示す記法であり、構築器を引数に取れる普通の関数型を利用者へ公開する案ではない。各操作は専用の直接呼び出しだけとし、複数引数には既存どおり名前を付ける。どの操作も State を持つ。clear・reserve・消費する finish・文字列への任意バイトの追加・構築器どうしの連結は初版へ加えない。List の要素 T は通常の型に限り、Reference を含んでもよい。

### 動的な反復と禁止する受け渡し

[01-02](../../../design/01-spec/01-02-syntax.md) 1031行のとおり for・while・loop はない。構築器の捕捉を禁じると、List.forEach のラムダで外側の b を追記できず、再帰関数へ b を渡すこともできない。このため appendAll を含める案を推す。断片は既存の List.map などで先に作って渡す。断片作成のコールバックが構築器を捕捉しなければ、通常の型と効果の範囲で使える。

ストリームを読みながら同じ構築器へ追記する使い方までは、この初版に含まれない。B8 でこの制限を受け入れるかを尋ねる。受け入れない場合は、専用の反復や非持ち出しを保証するコールバックの規則を別に設計し、Lean と処理系を再見積もりする。一般の List.forEach を「すぐ実行するから」とだけ説明して例外にしない。

| 使用位置 | 推す初版の判定 |
|---|---|
| 宣言した関数の同じ字句範囲の専用操作、通常の if・match の分岐からの操作 | 許す。分岐内で宣言した局所名は外へ出さない |
| return、利用者関数への引数、構成子・record・List・Map・Reference への格納 | 拒否する。型注釈や型引数を省略しても同じである |
| b を別の名前へ束縛、通常の関数・専用操作の値化、プレースホルダ・パイプを通した b の適用 | 拒否する。専用の直接呼び出しへ書き直す案内を出す |
| ラムダ・lazy・タスクへの外側の構築器名の捕捉 | 拒否する。引数型・戻り値型だけで判定しない。内側の関数が自分の構築器を作ることは許す |
| handle の本体と、その本体が使う継続 | 通常の Reference として実行し、State を残す。ソースの構築器名を値へ変える規則はない |
| handle の節から外側の構築器を参照する | 初版は拒否する。節を別の捕捉境界とする。節の内側で作り、そこで使い切る構築器は許す |
| 完成した String・List[T]・Bytes を返す、保存する、捕捉する | 許す。List[Reference[T]] の要素のセルは従来どおり共有される |

専用の局所名を通常の値の環境に入れないことが、禁止の中心となる。通常の型パラメータへ構築器を渡す規則がないため、「型引数を決めた後だけ特別な型が紛れ込む」経路を閉じられる。全体の関数型だけを調べる事後の検査にはしない。捕捉は解決済みの束縛で検査するので、同じ綴りの内側の通常変数まで拒否しない。

## State を残す具体的な展開

最初は文字列の構築器を `Reference[String]`、リストを `Reference[List[T]]`、バイト列を `Reference[Bytes]` に直す。これは内部表現の案であり、利用者が `type StringBuilder = Reference[String]` と書ける仕様ではない。型付きの局所名から、コンパイラが作るセルの変数への対応を持つ。

```text
// 左が提案する操作、右が内部で行う既存の操作の概略
new()              => Reference.new(空の不変値)
append(b, value)   => value を一度評価して保存する;
                      old <- Reference.get(cell_b);
                      next <- 既存の純粋な追記(old, value);
                      Reference.set(reference: cell_b, value: next)
copy(b)            => Reference.get(cell_b)
length(b)          => 既存の長さ関数(Reference.get(cell_b))
```

実際の変換では、引数式を既存の名前付き引数のソース順で一度だけ評価し、その後にセルを更新する。appendAll は String.join と `+`、List.concatenate、Bytes.concatenate を使う。Byte 一つの追加はその Byte だけの Bytes を作って連結する。List[Byte] へ全量を直さない。大きさの検査と純粋な更新を終えてから set するため、上限超過で既存の実行時エラーになった操作はセルを途中まで変更しない。

読み出しと書き込みの間に利用者のコールバックを呼ばない。局所名の捕捉と受け渡しを拒むので、ソースの別タスクがこのセルを更新することもできないという設計である。ハンドラが計算の続きを保存しても、セルの寿命を関数終了時の手動解放で打ち切らず、既存の Reference と継続の規則に委ねる。関数の終了・失敗・取消のために新しいバッファ解放の命令を設けない。

copy の展開は現在の不変値を返し、後の追記は別の値へセルを置き換える。そのため、取り出し済みの値の構造上の内容は変わらない。List の要素が Reference なら、そのセルの後の変更は見える。この意味の安定性と、毎回メモリ上で全構造を複製する契約は別である。TODO-248 の当初の「構造をコピーする」を物理コピーまで必須と読むなら、この展開のまま全要件を満たしたことにはならない。B5 で、初版は不変値の共有を許し意味を固定する案を尋ねる。

この実装では、文字列・バイト列の反復連結のコピー量は減らない。リストも既存の永続木の操作にセル操作を足すので、速くなるとは約束できない。State の追加により純粋な関数のまま構築器へ置き換えることもできない。既存の String.join・List.fold 等を Skill の既定の推奨から外さず、構築器は同じ名前を再束縛せず段階的に組み立てる選択肢として説明する。

## 形式化の内外と実装へ進む順序

正は [07-04「01-12 との対応」](../../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) である。Release を変えないことと、表層の変更を証明しないことは同義ではない。

| 変更 | 内外の判定と必要な扱い |
|---|---|
| 三つの二引数クラス・Result の通常の implement | 既存の型クラスと辞書の範囲内の宣言追加。型付け規則の変更は見込まない。実際の宣言を既存の表層検査・辞書・交換へ通して照合する |
| 二引数を揃える高カインドの種類の検査、別名の裸の名前の拒否 | 現行の Lean は種類を検査しない広い型付けである（07-04 240行）。Rust の種類の検査まで証明済みと説明しない |
| Monad の三法則 | 辞書の型保存からは得られない。必要なら純粋な Result の小さな意味の補題を別に置く。任意の実装の法則を公理で要求しない |
| ソースの識別子・import の別名・字句範囲への登録と禁止の診断 | 名前解決は形式化の外側。07-04 の対象外の行へ今回の範囲を追記する |
| 構築器の型付き表層・局所名の規則・State 付きの脱糖 | 形式化の内側。Surface の専用の局所文脈と構文を用意し、既存 Reference への型と効果の保存、検査器の健全性へつなぐ。Release の Ty/Eff/Step に構築器を足さない |
| 持ち出し検査を Rust だけに置く代案 | その禁止は Lean の保証外と明記する。それでも新しい表層からの脱糖は内側であり、変換後だけの検査を変換元の証明と数えない |
| ネイティブの局所ストア・領域変数・局所エフェクトの消去 | 型付け・ストア・継続・実行の形式化の内側。この版では採らない |

推す B10 は、型付き表層では構築器の名前を通常値とは別の番号で表し、専用操作でだけ使えるようにする。各スコープとラムダ等の捕捉境界で許す局所名を限定し、検査成功からその規則を導く。別の通常値に構築器名が入らない性質と、脱糖後のセルの型・State の保存を分けて示す。ソースの文字の名前からこの表層への変換は、既存どおり信頼する接続として記録する。

形式化の受け入れ条件は、State を外していないこと、全種類の通常値の中へ局所名を埋め込む規則がないこと、型と行の代入・変数番号の移動・捕捉境界で規則を保つこと、既存の `desugar_typed`・表層のエフェクト健全性・検査器の健全性11件とプログラム全体の言明を維持することである。ソースの持ち出し禁止全体、OS のメモリ解放、ネイティブの高速化の証明まで得たとはしない。

docs/todo の TODO-250 の末尾が重いとした三種類、すなわち「エフェクトへ値や型を加える」「エフェクトを外す」「型の計算を加える」を、推す初版はいずれも避ける。B10 の局所表層が見込みを超える場合も、部分適用や局所エフェクト消去へついでに広げない。一版に形式化の重い項目を一つまでとする条件を守り、範囲の取り直しを設計者へ示す。

版に含む Lean の変更は A・C と B・D を最初の段へまとめ、既定の `lake build` が sorry なしで通り、定義・言明・仮定のレビューを終えてから処理系へ進む。接続を閉じる区切りと最終の関係状態では `check-formal.sh` 全体を実行するか、07-03 の条件を満たす記録を引用する。これは後の plan の担当と検査の割り当てへ具体化する事項であり、今回の調査で実行した検査ではない。

## 作業の数と時間の幅

以下はコーディングエージェントの能動作業時間の未実測の見積もりである。設計者の判断・レビュー待ち、長い回帰の待ち、性能測定、版全体の公開作業を含めない。並行実行による経過時間の短縮を前提にしない。試作の見積もりを、S2 の API と保証の範囲へ具体化した値である。

| 範囲 | 作業数の案 | Lean の時間 | 処理系・ライブラリ・文書の時間 | 根拠 |
|---|---:|---:|---:|---|
| B の三クラス・Result・021 | 4〜6 | 2〜8時間 | 8〜20時間 | 164 の試作はライブラリ案を2〜8時間／4〜16時間とした。三クラスの階層と apply の意味、利用者型、値化と上位辞書、Skill の推奨と生成物の照合の分を処理系側へ含めた |
| D の State 展開、持ち出し検査は Rust のみ | 4〜6 | 4〜12時間 | 12〜32時間 | 248 の0〜2時間は既存 Reference の利用だけの幅である。今回は新しい型付き表層からの脱糖も内側とするため、その接続を加算した。持ち出し禁止そのものは保証外になる |
| D の推す案。局所名の規則も Lean に入れる | 6〜9 | 8〜20時間 | 12〜32時間 | 局所表層・検査器・脱糖の4〜12時間と、試作の禁止規則の4〜10時間は同じ文脈を共有するため重複を除いた暫定幅。保存継続の新しい所属や解放の証明を増やさない |
| B・021 と D の推す範囲の合計 | 10〜15 | 10〜28時間 | 20〜52時間 | 合計30〜80時間。A・C、ほかの相乗り項目と版全体の回帰は別である |

B の区切りは、既存の二引数辞書の接続確認、クラスと Result の実装、独立した期待値による契約の確認、Skill とリファレンスの整備を想定する。D は Lean の表層・検査器、脱糖と交換、定義と言明のレビューを先行し、Rust の宣言と局所名、専用操作の展開、捕捉・異常経路、文書へ分ける。正式な作業 ID と取り込み単位は plan で固定する。

最初の Lean の具体化で、変更する Surface/Check・Desugar・Lemmas・Exchange の集合と、十一件の健全性へ追加する場合を数え直す。Release の Ty/Eff/Step、保存継続の所属、外部状態の隔離の変更が必要ならこの見積もりは成立しない。語句の追加だけと見積もって先に Rust を実装しない。学習用の小証明と、実装へ接続する証明を別々に記録する。

## S2 の確認と後の計画への申し送り

今回の成果物は文書だけである。作業末の入口は `scripts/check.sh --level work --base 6cb18610f4a24f5bd564c57504de50b6cd91ca79` とし、同じ指定に `--dry-run` を付けて選択を確認してから一度実行する。ローカルリンク、TODO の写し、問いの連番、行末空白、変更先も確認する。実行結果は [S2 の記録](../s2/results.md) に置く。Rust・Lean のビルドや新しい性能測定はこの調査に含めない。

後の計画では [07-03](../../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査) に従い、作業末の work、接続を閉じる場合に限る stage、版全体の change、実際の公開候補の release を分担する。生成文書・仕様とリファレンスの例は関係する work の入口へ含め、同じ検査を直接のコマンドで重ねない。今回は文書だけで新しい接続がないため stage は不要である。

実装の確認対象は、Result の両側と apply のエラー優先・一度だけの評価、異なる X の拒否、利用者型・二引数の上位辞書・値化、一引数との不一致、局所名の返却・格納・捕捉・型引数を通る迂回の拒否、コピー後の安定性と要素のセルの共有、上限超過時の更新前の失敗である。テストを書くときに test-audit の関門を通し、同じ契約の重複や実装の形だけを固定する検査を加えない。

既存 Reference の規則を利用するだけならヒープの不変条件を変える作業は見込まない。ただし、生成したセルや引数を安全点を越えて保存するコードを変える場合は、局所の heap-verify・gc-stress と doc_default、必要な check-heap を次の作業の前提にする。後の性能測定は benchmark スキルに従い、連結だけの系列・一括結合・短い構築・取り出しを三種類ごとに比べる。今回の既存記録の参照をその測定の代わりにしない。

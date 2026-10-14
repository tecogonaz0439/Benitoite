# 扱う項目の本文の写し

docs/todo は非公開のリポジトリなので、2026-10-13 の時点の本文を写す。TODO-047 は、受け渡しの残りの点を参照するために写す（この改造では閉じない）。

## TODO-020 相互運用のための幅の違う数の型

- 状態: 未着手
- 旧: OPEN-042
- 出どころ: [open-issues の OPEN-042](../archive/2026-10-09-design-first-release/open-issues.md#open-042)、[01-04 基本型の意味論](../archive/2026-10-09-design-first-release/01-spec/01-04-types-basic.md)の「型の一覧」、[ADR 0105](../archive/2026-10-09-design-first-release/decisions/0105-byte-type.md)、[ADR 0114](../archive/2026-10-09-design-first-release/decisions/0114-decimal-type.md)、[2026-10-11 の言語の方向のメモ](sources/2026-10-11-language-direction/memo.md)、[WebAssembly の仕様の「Types」](https://webassembly.github.io/spec/core/syntax/types.html)、[コンポーネントモデルの「WIT」](https://component-model.bytecodealliance.org/design/wit.html)、[2026-10-11 のパッケージ管理と WASM の設計案](sources/2026-10-11-package-wasm/memo.md)

初回リリース版の数の型は、`Integer`（64 bit）・`Float`（倍精度）・`Byte`（0〜255）・`Decimal`（128 bit の 10 進の小数）である。固定幅の数は、バイト列から読み書きする関数で扱う（ADR 0107）。

2026-10-11 に設計者が、将来の WASM のライブラリと WASM のランタイムへの対応を想定し、WASM に合わせた型を検討する方向とした（関連: OPEN-051、外部の関数と WASM のプラグインの分野）。C のライブラリとの受け渡しと、単精度の数の大量の保持にも使う。`Float` は倍精度のまま変えないと決めてある。

WASM の型（2026-10-11 に確かめた）:

- コアの仕様の数の型は `i32`・`i64`・`f32`・`f64` で、ベクトルの型 `v128` がある。整数の型は符号の有無を持たず、解釈は個々の命令が決める（WebAssembly の仕様の「Types」）。
- コンポーネントモデルのインターフェースの記述（WIT）の基本の型は、`bool`・`s8`〜`s64`・`u8`〜`u64`・`f32`・`f64`・`char`・`string` である（コンポーネントモデルの「WIT」）。

ライブラリとの受け渡しを考えるなら、型の集まりを WIT の基本の型に合わせるのが自然という見立てがある（決定ではない）。

方向（2026-10-11、設計者。[パッケージ管理と WASM の設計案](sources/2026-10-11-package-wasm/memo.md)の「値の受け渡し」）: パッケージ管理と外部の関数の改造（TODO-211）では、Benitoite が今持つ型と WIT の型の共通部分だけを受け渡す（TODO-047）。WASM に合わせた新しい型は、構文の見直し（TODO-205）の改造で検討する。

加える場合に決めること:

- 型の間の変換
- 演算子の型の集まり（01-06「演算子の型付け」の規則の拡張）
- リテラルの書き方
- 型ごとの溢れの規則（`Integer` の溢れは実行時エラーである）
- 型の名前。省略しない名前の方針（ADR 0101）と、構文の見直しの可読性の基準（TODO-205）の両方で決める

## TODO-241 WASM の型に合わせた言語の型の見直しと、外部の関数の受け渡しの仕組みの見直し（フェーズ 3）

- 状態: 方針あり
- 出どころ: 2026-10-13 の設計者との相談（TODO-240 の作業中）

外部の関数の受け渡しは、型付きの速い経路（`Integer`・`Float`・`String`・`Bytes` と、TODO-240 の `List[Byte]`・`List[Integer]`・`List[Float]`）のほかは、Wasmtime の動的な値（`Val`、1 つ 40 バイト）を経て渡す。ほかの要素のリスト（`List[Boolean]`・`List[Character]`・`List[String]`）、入れ子のリスト、`Option`・`Result`・`Pair`・`Triple`、レコード・`data` がこれに当たる。Wasmtime 49.0.2 の `values.rs` の `Val::Record(Vec<(String, Val)>)`・`Val::Variant(String, …)`・`Val::Enum(String)` は、値ごとに欄や構成子の名前の文字列を写すので、レコードのリストが最も重い。型付きの速い経路は型の組み合わせごとに Rust の具体化を要し（TODO-240 で strip の後 2.17 MB 増えた）、利用者の書いたレコードの形は処理系のビルドの時点で決まらないので、この方式では全部の型を覆えない。

設計者の方向（2026-10-13）: フェーズ 3 で、WASM（WIT）が持つ型に合わせて言語の型を見直す（幅の決まった整数、`flags`、`map` など）。そのときに受け渡しの仕組みも合わせて見直す。

調べること:

- 処理系が WIT の型を見ながら Benitoite の値をゲストの線形メモリへ直接書き込む（canonical ABI の並べ方に従う）変換器を一つ持つ方式が、Wasmtime の公開の API で実現できるか。できないときの代わり（Wasmtime の内部に頼る、Wasmtime への提案、今の型付きの経路と動的な経路の組み合わせを続ける）。
- `List[String]`・`List[Boolean]`・レコードのリストを渡すときの受け渡しの量（`--wasm-stats`）と最大 RSS。
- 新しい型を加えたときの実行ファイルの大きさと照合の規則（03-10「型の対応」）の変わり方。

関連: TODO-213、TODO-236、TODO-239、TODO-240。

## TODO-047 WASM の実行基盤と値の受け渡しの残り

パッケージ管理と外部の関数の改造のフェーズ 1・2（2026-10-13。フェーズ 2 は 改造 `docs/archive/2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2/`）で、実行系、受け渡す型（レコード・直和型・外部の型（WIT の resource）を含む）、インターフェースの書き出し、速い経路、上限を変える引数と消費量の報告を入れた。内容は 03-10「外部の関数」と 02-09「外部の関数の実行」にある。残る点は次のとおりである。

- `Map` と WIT の `map<K, V>`（Wasmtime の `Config::wasm_component_model_map` で有効にする機能）、`flags`、幅の違う整数。型パラメータを持つ型と、引数が 2 個以上の構成子の受け渡し。宣言の側に型がない `s32` などを使う関数は今は誤りにしている（TODO-020）。
- 外部の型の `own` の引数（渡した後の値を使えなくする仕組みが要る）と、明示の解放の関数。
- WASM の実行中のタスクの切り替え。今は同期で実行し、その間ほかのタスクへ切り替えないので、`Task.withTimeout` の取り消しは外部の関数の実行中には効かない。ホストの関数の操作をハンドラに渡す仕組み（TODO-213）とあわせて考える。
- 実時間の上限。今は燃料で計算量だけを抑える。フェーズ 2 の測定（`tools/bench/results/2026-10-13-wasm-efc47689.md`）では、燃料 10^10 は最小のループで約 3.2 秒、実際のコード（Fuzzy）で約 0.3 秒に当たった。
- コンパイル済みのコードの再利用。今は検査と実行のたびにコンポーネントを Cranelift でコンパイルする（Regex の 926 KB で約 0.5 秒）。Wasmtime の事前にコンパイルしたコードを読む API（`deserialize`）は `unsafe` で、改ざんされたキャッシュから任意のコードが走りうるので使っていない。一回の `benitoite test` の中での共有は TODO-229、大きなコンポーネントのコンパイルの費用は TODO-228 で扱う。
- 上限の既定の値と、利用者以外が上限を決める方法は TODO-237 で扱う。

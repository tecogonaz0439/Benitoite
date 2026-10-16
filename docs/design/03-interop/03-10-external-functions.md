# 外部の関数

## 目的と範囲

WASM のコンポーネントから外部の関数の本体を与える宣言、外部の型の宣言、実行前の照合、呼び出しと失敗、外部の型の値の解放の扱いを定める。

## 前提

[構文](../01-spec/01-02-syntax.md)の属性と、[エフェクト](../01-spec/01-07-effects.md)の純粋な関数の規則と「外部の関数のエフェクト」を前提とする。形式は WebAssembly Component Model、型の記述は WIT とする。根と依存の別名は[パッケージ](../06-tooling/06-09-packages.md)で定める。

WIT はコンポーネントの取り込みと書き出しを記述する言語であり、world はその両方の契約をまとめる（出典: [Component Model の WIT 仕様](https://github.com/WebAssembly/component-model/blob/6c48079b/design/mvp/WIT.md#the-wit-text-format)、[WIT Worlds](https://github.com/WebAssembly/component-model/blob/6c48079b/design/mvp/WIT.md#wit-worlds)）。

実行系は Wasmtime 49.0.2 に固定し、`default-features = false` と `runtime`・`component-model`・`std`・`cranelift` を使う。補助のバイナリは wasm-encoder 0.258.3 の安全な公開 API で生成し、生成後に `Component::from_binary` で検証する。wasm-encoder は既定機能を無効にして `std`・`component-model` だけを使い、その任意依存の wasmparser は有効にしない。元ゲストのインスタンス数の見積もりには、別の直接依存の wasmparser 0.258.3（既定機能なし、`std`・`component-model`）を使う。WAT の解析はテストのゲストだけに使い、本番では行わない。

各クレートの配布物の Cargo.toml により、Wasmtime は `Apache-2.0 WITH LLVM-exception`、wasm-encoder と wasmparser は `Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT`、生成器の必須依存 leb128fmt 0.1.0 は `MIT OR Apache-2.0` であることを確認した。[依存のライセンスの規則](03-01-library-structure.md#依存のライセンス)の許可範囲に含まれる（出典: [Wasmtime 49.0.2](https://docs.rs/crate/wasmtime/49.0.2/source/Cargo.toml)、[wasm-encoder 0.258.3](https://docs.rs/crate/wasm-encoder/0.258.3/source/Cargo.toml)、[wasmparser 0.258.3](https://docs.rs/crate/wasmparser/0.258.3/source/Cargo.toml)、[leb128fmt 0.1.0](https://docs.rs/crate/leb128fmt/0.1.0/source/Cargo.toml)）。

## 仕様

### 宣言の形

【決定】`@external("wasm", "コンポーネントのパス", "関数の名前")` を、本体のないトップレベルの関数に付ける。引数と戻り値には具体的な型を書く。型パラメータ・制約・エフェクト変数・本体・`end function` は書けない。宣言の引数か戻り値の型に外部の型を含む場合だけ `uses State` を書く。`public` または `public(package)` と `@deprecated` は併用でき、`@test` と `@builtin` は併用できない。

```text
@external("wasm", "wasm/fuzzy.wasm", "distance")
public function distance(a: String, b: String) -> Integer
```

【決定】第 3 引数は world の直下の関数の名前か、`インターフェースの書き出しの名前#関数の名前` とする。`#` があれば最後の `#` で区切り、どちらかが空なら構文解析で E0815 とする。インターフェースの名前は版を含めて文字列の完全一致を求める。理由: 書き出しの版が宣言と違う場合を実行前に報告し、契約の変更を見落とさせないためである。

```text
@external("wasm", "wasm/calc.wasm", "bnt:test/api@1.2.0#add")
function add(a: Integer, b: Integer) -> Integer
```

【決定】外部の型（WIT の resource に当たる型）は、`@external("wasm", "パス", "インターフェース#resource") type 名前` と宣言する。右辺と型パラメータを持たない。関数と同じく公開の指定と `@deprecated` を付けられる。01-10 のリソースの型には含めず、`with` には使えない。等値・鍵・順序の制約を満たさず、`Show` の既定の実装も持たない。型クラスの実装は利用者の型と同じ規則で書ける。理由: 中身を見せない値を回収で管理し、外部の操作の後始末を定めるリソースの型と区別するためである。

```text
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#cell")
public type Cell
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#[constructor]cell")
public function newCell(start: Integer) -> Cell uses State
```

### コンポーネントのパス

【決定】パスの基準は、宣言を書いたモジュールが属する根である。入口と根のモジュールでは入口の根、依存のモジュールではパッケージの根から探す。依存のモジュールのパスは `wasm/` の下に限る。根の `package.bnt` に `package` のブロックがある場合は、入口と根のモジュールにも同じ制限を当てる。`package` のブロックがなければ、`package.bnt` があっても根全体を対象とする。理由: パッケージを自分の根で検査したときと、依存として読み込んだときで、許すパスを一致させるためである。

- パスは `/` で区切る相対パスであり、`.wasm` で終える。空の文字列、先頭の `/`、`\`、空の段、`.`・`..`、`.` で始まる名前の段は誤りとする。
- 段ごとにディレクトリの項目と大文字小文字まで一致する名前を探す。途中の段はディレクトリ、最後の段はファイルでなければならない。
- シンボリックリンクを解決したパスは、正規化した根の下にあることを確かめる。パッケージでは根の `wasm/` の下にあることを確かめる。
- ファイルは普通のファイルだけを読み、256 MiB を上限とする。

理由: 大文字小文字を区別しないファイルシステムでも宣言とハッシュが同じ名前を指し、パッケージのハッシュが含めないファイルを読めないようにするためである。

### 照合

【決定】Benitoite 内の外部関数の呼び出しは、宣言したパラメータ名を契約として対応付ける。ソース順に評価した値を宣言位置へ配置してから外部へ渡す。WIT の関数との照合は位置ごとの型を使い、WIT の引数名との一致を要求しない。Benitoite の静的な契約と、外部の ABI の照合は区別する。

【決定】型検査の後、`check`・`run`・`test` の共通の経路で照合する。外部の宣言がなければ Wasmtime の `Engine` を作らない。同じ正規化したパスは、検査の間に一度だけ読み、一度だけコンパイルする。`fmt` は照合しない。

1. バイナリがコンポーネントの magic とバージョンを持つことを確かめる。コアのモジュールとテキスト形式は受け付けない。
2. Wasmtime の `Component::from_binary` でコンパイルし、取り込みが空であることを確かめる。取り込みがあれば、名前を最大五つ示す。WASI の取り込みがあればビルド先の修正も示す。
3. `#` がなければ world の直下から、あれば前半の名前と完全に一致するインスタンスの書き出しの中から、指定した名前の同期の関数を引く。型の側の `get_export` で前半と後半を順に引き、版の互換性による検索は使わない。
4. 引数の数と位置ごとの型を照合する。引数の名前は照合しない。戻り値が `Unit` なら WIT の戻り値は零個、それ以外なら一個で型が対応しなければならない。レコードの欄と直和型の場合は、「型の対応」の規則で数・順・名前・型を照合する。

理由: 取り込みのないコンポーネントだけを受け付け、位置ごとの型と、値の受け渡しに使う欄・場合の名前の対応を実行前に検査するためである。

【決定】外部の型を先に resource の書き出し（`#` がなければ world の直下、あれば前半のインターフェースの中）に照合し、その後に関数を照合する。引数の外部の型は `borrow<R>`、戻り値は `own<R>` と、同じコンポーネントの同じ resource であることまで照合する。型の書き出しが存在しないか resource でなければ E1012 とし、書き出した resource の一覧を示す。その型を使う関数の照合は飛ばし、同じ原因の診断を重ねない。理由: 関数の照合に使う外部の型と resource の対応を先に確定するためである。

【決定】宣言の型を展開した後に外部の型を含むかを調べ、`uses State` がなければ E0816 と挿入の修正案を出す。ほかのエフェクト、または外部の型を含まない関数の `uses` は E0812 とする。この検査は別名を展開し、レコードと直和型の欄が確定した型検査の段で行い、外部の型を含む場合は `uses State` への置き換え、含まない場合は `uses` の削除を修正案にする。外部の関数のエフェクトの検査は型検査の段で行うので、E1010・E1012 より先に報告される。理由: 宣言の順や別名に依存せず、呼び出し側のエフェクトの誤りに外部の宣言の誤りが隠れないようにするためである。

【決定】関数が見つからないときは E1006 とし、第 3 引数の全体を示す。注記 `exports` に、world の直下の関数と、インターフェースの中の関数を `名前#関数` の形で書き出しの順に並べる。resource のメソッドなども、関数なら一覧に含める。前半と版だけが違う書き出しがあれば、注記 `version` に実際の名前と完全一致を要することを示す。`#` のない指定がインターフェースの名前なら、注記 `interface` に `名前#function` の形を示す。理由: 宣言に書ける名前を診断から選べるようにするためである。

【決定】引数の数・引数の型・戻り値の照合の誤り（E1007〜E1009）には、WIT の型をすべて「型の対応」の表で逆に引ける場合に限り、注記 `declaration` で期待する `function 名前(引数) -> 戻り値` を示す。名前は Benitoite の宣言の名前とし、引数名は WIT の名前の先頭の片を小文字にし、`-` を除いてその直後の英字を大文字にする。予約語に当たる名前は `argN`（N は 1 から数える引数の位置）にする。他の引数の名前と既に決めた代替名の集合を持ち、重なる間は N を進める。`list<u8>` は `Bytes`、2 要素と 3 要素の `tuple` は `Pair`・`Triple`、戻り値なしと `result` の省略した側は `Unit` とする。幅付きの数の基本型も逆に引く。record・variant・enum・flags・map、1 要素または 4 要素以上の tuple を含め、逆に引けない型が一つでもあれば注記を付けない。理由: Benitoite の型の名前を決められない場合に、推測した名前を示さないためである。

【決定】照合の段がパスの基準の根を開き直すときに I/O の失敗が起きた場合（読み込みの後に根や依存のディレクトリが消えた場合など）は、その根を使う宣言のコンポーネントのパスの位置で E1001 を報告する。理由: 外部のファイルシステムの変化を処理系の不具合として扱わないためである。

【決定】検査と実行系の設定は `external::engine_config()` にまとめる。燃料の計数と epoch の中断を有効にし、Wasm のスタックの上限を 512 KiB とし、Wasm の履歴の取得を切り、WIT の map を有効にする。シグナルの処理と Spectre の緩和は Wasmtime の既定のままとする。照合の結果は名前解決の `externals` の表に、パス・インターフェースの書き出しの名前（world の直下ならなし）・関数の名前・バイト列・型の変換表として残す。Wasmtime の型は照合の結果に含めない。

### 型の対応

【決定】型の別名を展開し、レコードと `data` の具体的な型引数を欄と構成子の引数へ代入した宣言の型を、次の表で照合する。型・エフェクトの未確定の変数は受け付けない。

| Benitoite | WIT |
|---|---|
| `Integer8`・`Integer16`・`Integer32` | `s8`・`s16`・`s32` |
| `Integer`（`Integer64`） | `s64` |
| `Float32` | `f32` |
| `Float`（`Float64`） | `f64` |
| `Boolean` | `bool` |
| `Character` | `char` |
| `String` | `string` |
| `Byte`（`UnsignedInteger8`） | `u8` |
| `UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64`（`UnsignedInteger`） | `u16`・`u32`・`u64` |
| `Bytes` | `list<u8>` |
| `List[T]` | `list<T>` |
| `Option[T]` | `option<T>` |
| `Result[T, E]` | `result<T, E>` |
| `Pair[A, B]` | `tuple<A, B>` |
| `Triple[A, B, C]` | `tuple<A, B, C>` |
| 具体的な型引数を代入したレコード | `record` |
| 具体的な型引数を代入した `data` | `variant`。2 個以上の引数は一つの平らな tuple のペイロード |
| すべての構成子が引数を持たない具体的な `data` | `enum` または中身のない場合だけの `variant` |
| 引数が 1 個以上の一構成子の具体的な `data` | 同じ個数・順・型の `tuple` |
| `Set[D]`（D は引数なしの構成子を 1〜32 個持つ具体的な `data`） | `flags` |
| `Map[K, V]` | `map<K, V>`。鍵は下記の範囲に限る |
| 外部の型 | 引数は `borrow<R>`、戻り値は `own<R>` |
| `Unit`（関数の戻り値だけ） | 戻り値なし |

`Result` の片側が `Unit` のときは、WIT でその側を省く。例えば `Result[Unit, String]` は `result<_, string>`、`Result[Unit, Unit]` は両側を省いた `result` に対応する。引数や `List`・`Option`・タプルの中の `Unit` は受け渡せない。`List[Byte]` と `Bytes` はどちらも `list<u8>` に対応するが、変換表は宣言の型を区別する。

対応する標準ライブラリの `Option`・`Result`・`Pair`・`Triple` を束縛の番号で識別する。それ以外のレコードと `data` は、利用者の型と標準ライブラリの型を同じ規則で扱う。関数、`Decimal`・上記以外の `Set`・01-10 のリソースの型・`Task` など、表にない型は誤りとする。外部の型は `List`・`Option`・`Result`・タプル・レコード・直和型の中でも受け渡せる。理由: 受け渡し方が決まる型だけを受け付け、対応のない型を実行前に報告するためである。

【決定】レコードは `record` と欄の数・宣言の順・名前・型を照合する。`data` は `variant` と場合の数・宣言の順・名前・ペイロードの有無と型を照合する。引数のない構成子だけの `data` は、同じ数・順・名前の `enum` にも照合する。型自体の名前は照合しない。欄と場合の名前は、両側から `-` を除き、ASCII の英字を小文字にした結果で比べる（`byte-start` と `byteStart`、`not-found` と `NotFound`）。`_` は除かない。一つの record・variant・enum・flags の中で、正規化した名前が WIT の側か Benitoite の側で重複したら照合の誤りとする。理由: 名前を使って値を受け渡す際の対応を一意に決め、欄や場合の入れ替えも検出するためである。

【決定】`@extensible` はソースのパターンの使用条件であり、WIT との構造照合を緩めない。指定付きの型も、現在の宣言の名前・数・順序・型を同じ規則で照合し、未知の外部タグは受理しない。属性によって実行時の構成子のタグ・ABI・等値性・鍵の条件は変わらない。理由: ソースの網羅性の保証と、外部との値の受け渡しの契約を分けるためである。

【決定】標準の `Pair`・`Triple` を先に束縛の番号で識別する。それ以外の一構成子の `data` は、WIT が tuple なら引数の数・順・型で照合し、構成子の名前は比べない。1 要素と 4 要素以上も受け付け、0 要素の tuple とレコードの tuple への対応は受け付けない。WIT が variant なら、同じ一構成子の宣言にも variant の規則を使う。variant の引数 0 個はペイロードなし、1 個はその型、2 個以上は平らな tuple とし、一般の `Unit` の引数は省かない。理由: 一つの WIT のペイロードを複数の言語の欄へ対応させ、戻り値を宣言した構成子へ直接組み直すためである。

【決定】flags は項目の数・宣言順・正規化した名前を `Set[D]` の D の構成子と照合し、構成子のタグと WIT の項目番号の対応を保存する。選択の空集合は許す。型の項目が 0 個または 33 個以上なら E1010 とし、理由と 1〜32 個の範囲を示す。補助の記憶域と転送形式は 1〜8 項目で 1 バイト、9〜16 項目で 2 バイト、17〜32 項目で 4 バイト、平らな引数は i32 一つである。戻り値の余分な上位ビットは捨て、宣言した項目だけを Set にする。理由: Wasmtime 49.0.2 が使う wasmparser 0.258.3 の検証器が受理する flags の範囲に合わせる（出典: [flags の検証](https://docs.rs/crate/wasmparser/0.258.3/source/src/validator/component.rs)）。

【決定】map の鍵 K は `Boolean`・符号付きと符号なしの各幅の整数・`Character`・`String` に限る。`Decimal`・`Bytes`・`Unit`・data・レコードなど、言語内で鍵になるほかの型も境界では E1010 とする。V は受け渡せる非再帰の型とし、外部の型を含む場合は状態を持つ動的な経路を使う。行きは Map のカーソルから鍵の順に一意な組を渡す。帰りは元の順で全組を検査し、重複した鍵は後の値を採り、結果を鍵の順にする。重複で消える値も検査と予算に含め、外部の型の対象は管理の表へ登録する。中間の `List[Pair]` は作らない。理由: WIT の鍵の範囲と、言語の Map の後勝ちと鍵順を保ち、不正な値が重複の縮約で検査を逃れないようにするためである。

【決定】型引数は環境を持って欄を辿るときに代入し、大きな型の木を先に複製しない。再帰は、型パラメータを葉として、到達した型宣言の欄・構成子の引数に明記された依存の循環で検出し、E1010（注記 `recursive`）とする。List・Option などの内側と、代入で新たに到達する宣言も調べる。使用しない宣言は調べない。有限の `Box[Box[Integer]]` は受け付け、`Nest[T]` の欄が `Nest[List[T]]` の形と、別の宣言を通る循環は拒否する。外部の型を含むかの型検査にも同じ代入と予算を当て、実際の欄に外部の型がある場合だけ State を要求する。未使用の型引数だけでは要求しない。予算切れは根の型の E1010 として止める。理由: 同じ宣言の有限の入れ子と、展開を終えられない宣言の循環を区別するためである。

【決定】引数と戻り値の型を展開する際は、型ごとに深さ 100、節点数 100,000、検査一回で展開する節点の合計は 1,000,000 を上限とする。根を深さ 1 とし、葉の型を含めて型の出現ごとに一節点を数える。同じ型を複数の欄で使う場合も、それぞれ数える。展開の入口から予算を数え、上限を超えた時点で展開を止めて、宣言に書いた引数か戻り値の根の型を E1010（注記 `budget`）で示す。合計の予算を使い切った後の宣言は、宣言ごとに一件の E1010 とし、同じ注記と関数の名前を示す。位置は最初の引数の型とし、引数がなければ関数名とする。展開を行っていない型と `Unit` の戻り値は名指ししない。理由: 深さは wasmparser 0.258.3 の `MAX_WASM_COMPONENT_TYPE_DEPTH` に合わせ、その上限を超える型はどのコンポーネントとも照合できない。節点数は検査の費用を抑えるため、wasmparser の型の大きさの上限 1,000,000 より小さくし、共有した型が指数的に展開される場合にも最後まで展開しない（出典: [wasmparser 0.258.3 の型の上限](https://docs.rs/crate/wasmparser/0.258.3/source/src/limits.rs)、[型の深さと大きさの計数](https://docs.rs/crate/wasmparser/0.258.3/source/src/validator/types.rs)）。

【決定】欄・場合・flags の項目・tuple の数・順・名前・型、map の鍵と値の型、ペイロードの有無、正規化した名前の重複の食い違いは E1008・E1009 とし、注記 `reason` で最初の食い違いを示す。名前の食い違いと重複では正規化の規則も示す。WIT の型と宣言から作る表は、`record { byte-start: s64, y: s64 }`・`variant { circle(f64), empty }`・`enum { red, blue-ish }` の形で中身を示す。E1008・E1009 の `declared`・`wit` と対応する表の型の表示は、それぞれ 2,000 文字を上限とし、超える場合は末尾を `…` で省く。理由: 直すべき欄や場合を診断から特定できるようにするためである。

【決定】宣言から作る表には Benitoite の欄・構成子の名前を残す。照合を通った実行用の変換表には、WIT の名前と順、構成子のタグ、ペイロードの有無、照合した種類（record・variant・enum・flags・map・tuple）と、構成子の欄数およびペイロードを単一の欄に戻すか複数の欄へ分配するかを保存する。両方向の値の変換は明示の作業列で行い、Rust の関数を再帰的に呼ばない。理由: 実行時の動的な値は WIT の名前を必要とし、値の入れ子によって処理系のスタックを増やさないためである。

型が入れ子の場合は、予算の超過を除き、受け渡せない内側の型を E1010 の文言に示す。例えば受け渡せない `Decimal` を含む `Option[List[Decimal]]` では、`Decimal` を示す。標準ライブラリの `Option`・`Result`・`Pair`・`Triple` と同じ綴りの利用者の型には、宣言したファイルを注記し、標準ライブラリの型と区別する。E1008・E1009 の `user_type` の注記は宣言の型の一番外側だけで判定し、内側へは広げない。予算の超過にはこの注記を付けない。

具体的な型引数を持つレコードと有限の入れ子は、次のように宣言する。

```text
record Box[T]
  value: T
end record
@external("wasm", "generic.wasm", "box")
function box(v: Box[Integer]) -> Box[Integer]
@external("wasm", "generic.wasm", "nested")
function nested(v: Box[Box[Integer]]) -> Box[Box[Integer]]
```

flags は、引数なしの構成子の Set として宣言する。

```text
data D1
  F1
end data
@external("wasm", "flags.wasm", "f1")
function f1(v: Set[D1]) -> Pair[Set[D1], Integer]
```

map は、鍵と値の具体的な型を Map に書く。

```text
@external("wasm", "maps.wasm", "result")
function result(v: Map[String, Integer]) -> Map[String, Integer]
```

4 要素の tuple は、一構成子の data で表す。

```text
data Four
  Item(Integer, Integer, Integer, Integer)
end data
@external("wasm", "tuples.wasm", "tuple4")
function tuple4(v: Four) -> Four
```

複数引数の variant は、構成子に各欄の型を書く。

```text
data Two
  Value(Integer, Integer)
  Empty
end data
@external("wasm", "variants.wasm", "fields")
function two(v: Two) -> Two
```

本章の宣言と入力の例は、次のゴールデンケースに対応する。ケースは同じパス・書き出し名・宣言・入力を使い、CLI の実際の外部の関数の入口から結果と終了状態を確かめる。`spec_examples` は本章を読まないため、この検査の代用にならない。

| 例と入力 | 結果 | ケース |
|---|---|---|
| world の直下: `distance(a: "kitten", b: "sitting")` | `3` | `external/wit-docs-declarations` |
| インターフェース: `add(a: 20, b: 22)` | `42` | 同上 |
| resource: `newCell(10)` を `[method]cell.get` で読む | `10` | 同上 |
| 型引数: `box(Box(value: 35))`、`nested(Box(value: Box(value: -7)))` の value | `42`、内側は `0` | `external/wit-docs-values` |
| flags: `f1(Set.fromList([D1.F1]))`、`f1(Set.empty())` | 戻る選択は両方とも F1 のみ。入力のビット値は `1`、`0` | 同上 |
| map: `result(Map.empty())` | `[Pair("a", 2), Pair("z", 3)]`。重複は後の値 | 同上 |
| tuple: `tuple4(Four.Item(1, 2, 3, 4))` | `Four.Item(12, 14, 16, 18)` | 同上 |
| variant: `two(Two.Value(3, 7))` | `Two.Value(14, 29)` | 同上 |

ケースは [wit-docs-declarations](../../../crates/benitoite/testdata/external/wit-docs-declarations/main.bnt) と [wit-docs-values](../../../crates/benitoite/testdata/external/wit-docs-values/main.bnt) に置く。ゲストは既存の [Fuzzy](../../../crates/benitoite/testdata/packages/libraries.files/fuzzy/README.md)、interface・resource・wit-generic-values・wit-flags-boundaries・wit-map-values・wit-tuple-values・wit-variant-fields の試験用コンポーネントを、例のパスへ写したものである。Fuzzy 以外は同じ場所に手書きの WAT と対応するバイナリを置く。`BENITOITE_GOLDEN_FILTER=wit-docs cargo test -p benitoite --test golden` で二件を実行する。

### 作り方の例

取り込みのない Rust のコンポーネントは、`wit-bindgen` で書き、`wasm32-unknown-unknown` 向けにビルドしてから包む。`wasm32-wasip2` は WASI の取り込みを加えるため、取り込みが空という条件を満たさない場合がある。

```sh
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
wasm-tools component new target/wasm32-unknown-unknown/release/fuzzy.wasm -o ../wasm/fuzzy.wasm
wasm-tools component wit ../wasm/fuzzy.wasm
```

出典: [wit-bindgen の Rust の例](https://github.com/bytecodealliance/wit-bindgen/tree/v0.62.0/crates/guest-rust)と [wasm-tools の component のコマンド](https://github.com/bytecodealliance/wasm-tools/tree/v1.261.0/src/bin/wasm-tools/component)。試験用の Fuzzy は Rust 1.98.1、wit-bindgen 0.62.0、wasm-tools 1.261.0 で作ったコンポーネントを置き、元のソースと手順を添える。検証用の Hash・Regex・Json のパッケージも、元のソースと作り直す手順を添える。各パッケージの README（[Hash](../../../crates/benitoite/testdata/packages/libraries.files/wasm-hash/README.md)、[Regex](../../../crates/benitoite/testdata/packages/libraries.files/wasm-regex/README.md)、[Json](../../../crates/benitoite/testdata/packages/libraries.files/wasm-json/README.md)）では `CARGO_TARGET_DIR` を根の `target/wasm-guests` にし、`RUSTFLAGS` の `--remap-path-prefix` でホストのパスを置き換える手順を定める。

### 実行

【決定】外部の関数は、直接呼ぶ場合も関数の値として渡す場合も同じ入口で呼ぶ。引数と戻り値を「型の対応」の表に従って変換し、外部の型を受け渡さない関数ではコンポーネントの状態を呼び出しごとに作り直す。戻り値の文字列と `Bytes` は 2^30 バイト、リストは 2^24 要素の上限を、言語の値を作る前に確かめる。文字列は UTF-8 を確かめる API を通す。理由: 同じ引数の結果が以前の呼び出しの状態に依存せず、言語の値の不変条件を守るためである。

【決定】外部の型を受け渡す関数は、実行ごと・コンポーネントごとに一つの状態を持つインスタンスで呼ぶ。外部の型の値が回収されたら解放待ちの列へ番号を入れ、次にそのインスタンスへ入る前に解放する。解放の時期は回収の時期に依存するため、共有の状態を読むメソッドの結果と資源の消費量は回収の時期によって変わりうる。明示の解放の関数は持たない。解放は回収を待つため、外部でない値が多く生きている間は、外部の型の値を作り捨てても状態を持つインスタンスの線形メモリの上限（既定 64 MiB）に達しうる。解放待ちの列のデストラクタのトラップ・燃料切れ・中断は、次の呼び出しの失敗として報告する。トラップの報告の書き出し名には、`[resource-drop]cell` のように解放する型を示す。型に外部の型を含まない関数（`[static]` を含む）は呼び出しごとのインスタンスで呼ぶので、状態を持つインスタンスの状態を見られない。実行の終わり・中断・呼び出しの失敗では状態を捨てる。参照インタプリタはこの経路を扱わず、差分テストから除く。理由: 外部の型の値を呼び出しをまたいで使い、回収された値のゲストの領域を使い回せるようにするためである。

【決定】インターフェースの中の関数は、照合で決めた完全なインターフェースの名前を `Component::get_export_index` で引き、得た索引を親として関数の名前の索引を引く。world の直下なら親の索引を指定しない。索引は実行系がコンパイルしたコンポーネントから呼び出しごとに得て、そのコンポーネントから作ったインスタンスの `get_func` に渡す。`get_export_index` は完全一致を先に探すので、照合で完全一致を確かめた名前は同じ書き出しを返す（出典: Wasmtime 49.0.2 の [NameMap::get](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/environ/src/component/names.rs#L180-L202) と [Component::get_export_index](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/wasmtime/src/runtime/component/component.rs#L794-L806)）。理由: 索引はコンパイルしたコンポーネントに属するため、検査のときの別のコンポーネントの索引を使わないためである。

【決定】一回の呼び出しの燃料は既定で 10^10、線形メモリは呼び出し全体の合計で既定 64 MiB（状態を持つインスタンスではその寿命の合計）を上限とする。`run` と `test` の `--wasm-memory`・`--wasm-fuel`・`--wasm-transfer` で上限を変更できる。大きさはバイト数か `KiB`・`MiB`・`GiB` つきの整数とし、線形メモリと受け渡しの予算は 1 MiB 以上 4 GiB 以下、燃料は 1 以上 2^64−1 以下の整数とする。範囲の外は使い方の誤りとして実行前に拒否する。コアのインスタンス・メモリ・表の数はそれぞれ 16、表一つは 10,000 要素を上限とする。燃料は計算量の上限であり、実時間の上限ではない。理由: 上限を実行する利用者が決められるようにし、既定の燃料は試験用の Fuzzy の 3,000 文字どうしの距離の計算が消費した 549,697,585 の約 18.2 倍に保つためである。

【決定】呼び出しの経路は照合時に次の順で決める。実行の失敗後に別の経路で再試行しない。

1. 引数か戻り値の実際の欄に外部の型があれば、状態を持つ動的な経路（統計の `stateful`）を使う。新しい数・map・組を含む場合も、同じ Store の `Val` で渡す。
2. 外部の型がなく、既存の型付きの呼び出しの範囲なら、速い経路（`typed`）を使う。
3. 残る対応済みの非再帰の値は、型から生成した補助コードの経路（`adapter`）を使う。戻り値なしもこの経路である。
4. 補助の生成量・memory32 の配置・コアインスタンス数の見積もりが上限を超える場合は、呼ぶ前に動的な経路（`dynamic`）へ振り分ける。未対応の言語の型は静的な誤りとする。

理由: 現在の速い経路を保ち、新しい型の組み合わせを共通の生成器で扱い、失敗した外部の操作を繰り返さないためである。

型付きの経路は引数 0〜3 個、戻り値一個で、直接現れる `Integer`・`Float`・`String`・`Bytes`・`List[Byte]`・`List[Integer]`・`List[Float]` を扱う。ただし引数に `List[Integer]` または `List[Float]` がある場合は引数 2 個以下に限る。数のリストを含む 3 引数、レコードや Option などの内側の値は補助へ送る。既存の別名は同じ型なので経路を変えない。`Bytes` と `List[Byte]` の Rust の具体化は共有し、戻り値は宣言の型へ戻す。理由: 現在の 642 通りの具体化を増やさず、実行ファイルの増大を抑えるためである。

【決定】補助の合成は、同じ元のバイト列・インターフェースと関数の書き出し名・WIT の形・言語の構築量の数え方・転送形式の版を共有の鍵とし、関数ごとに分ける。同じ鍵の宣言だけが一つの合成を共有する。元のコンポーネントを外側に一つ入れ子にし、その関数だけの変換コードと補助メモリを置く。別の関数の宣言を加えても、この合成のコアインスタンス数と生成上限の判定を変えない。構成子のタグ番号は宣言の変換表に残し、共有の鍵から除く。Bytes と List[Byte]、`One(Pair[A, B])` と `Two(A, B)` は WIT の形が同じでも構築量が違うので別の合成とし、タグ番号だけが違う宣言は共有できる。理由: 全関数を一つに合成すると、宣言を加えたことだけで別の関数がインスタンス数の上限に達するためである。

元のソースと補助のコンパイル済み Component は別のキャッシュに置き、実行ごとの Engine とともに保持する。検査と実行の間でコンパイル済みコードを受け渡さず、永続キャッシュと deserialize は使わない。補助の呼び出しは毎回新しい Store とインスタンスを作り、結果を言語の値へ変換した後に捨てる。補助の確保器は解放しない方式なので、同じインスタンスを呼び出し間で再利用しない。補助の対象は取り込みのない元ゲストに限る。外側だけに内部の報告関数 `adapter-fail: (u32, u64, u64) -> ()` を接続し、利用者が指定するホストの関数の入口は設けない。

【決定】生成した補助の区画は、元のバイナリを除いて 16 MiB を上限とする。書き込み前に残量を検査する。生成の上限・memory32 の表現上限に達したら途中の生成物を捨て、関数ごとに動的へ振り分ける。元ゲストのコアインスタンス数を start を実行せずに保守的に見積もり、補助のメモリ・変換用・融合用の三個を加えて 16 を超える場合も動的へ送る。統計の `fallback_reasons` には、それぞれ `generation_limit`・`memory32_layout`・`core_instance_limit` を残す。補助の準備には宣言ごとに別の型走査予算 4,000,000 を当て、超過は当該書き出しの位置の E1010 とする。生成コードの検証失敗や ABI の規則の不整合は処理系の不具合として報告する。理由: 実行前の資源の見積もりによる振り分けと、生成器の不具合を区別するためである。

【決定】補助のホストとの呼び出し型は `TypedFunc<(&[u8],), (Vec<u8>,)>` に固定する。内部の転送形式の版 1 は、32 バイトのヘッダに `BNTW` の四バイト・版 u32・全長 u32・根の個数 u32・転送上限 u64・構築上限 u64 をリトルエンディアンで置き、その後に根の固定部を置く。引数の根は位置順、戻り値の根は 0 個か 1 個である。固定部は正準 ABI（canonical ABI）の memory32 の配置を使い、string・list・map の参照は相対位置 u32 と長さ u32 とする。map の参照先は鍵と値の tuple の列である。詰め物と非選択の領域は零とし、動的な参照先は深さ優先・宣言順に詰める。list/map の固定部全体を先に予約し、空の参照は位置 0 とする。

固定部の数は幅どおりに置き、bool は 1 バイト、char は Unicode のスカラー値の u32、record/tuple は宣言順の整列した欄、enum は場合数に応じた判別子、variant/option/result は判別子と選択したペイロードとする。ABI の平らな形では s/u8・16・32、bool・char・enum・flags は i32、s/u64 は i64、f32/f64 はその幅、string/list/map は i32 二つ、record/tuple は子の列の連結にする。variant は判別子を先頭に置き、各場合の列を位置ごとに合流する。同じ種類ならその型、i32 と f32 の混合は i32、それ以外の幅・種類の混合は i64 とし、数値変換をせずビットを再解釈する。理由: 数値変換によって整数や NaN のビットを変えないためである（出典: [Wasmtime 49.0.2 の ABI の配置と平らな型](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/crates/environ/src/component/types.rs)）。

転送形式の正は `external/adapter/wire.rs` とする。復号では版・magic・全長・根の個数・両予算をホストの指定値と照合し、整列と次の未使用位置を確認する。共有・重なり・後方参照・範囲外・余分な末尾・加算の溢れ・零でない詰め物と非選択の領域を拒否する。全体を検査した後に言語の値を作る。補助は memory32・同期・UTF-8 を使い、平らな引数が 16 個を超える場合は引数の record の位置一つを渡す。lower した結果が一個を超える場合は、呼び出し側が用意した結果領域の位置を末尾の引数に加える。lift と lower の間接の結果の向きを分けて生成する。元ゲストの UTF-16 などの符号化と post-return は Component Model に任せる。元の関数を一度だけ呼び、結果を補助のメモリへ移してから詰め直す。外側の `TypedFunc::call` も post-return を行うので追加で呼ばない。理由: 元ゲストのポインタとホスト用の相対位置を分け、ゲストの後処理後も結果を保持するためである。

【決定】受け渡しの予算は、引数と戻り値でそれぞれ既定 256 MiB とし、経路ごとに次の量を数える。

| 経路 | 受け渡しの量 |
|---|---|
| 補助 | ヘッダ・根・詰め物・参照先を含む転送バイト列の全長。CLI の上限がより大きくても、u32 の全長に収まる必要がある |
| 型付き | Bytes と List[Byte] は 1 バイトにつき 1、List[Integer] と List[Float] は 1 要素につき 8。引数の string は UTF-8 のバイト数、戻り値の string はゲストの符号化されたバイト数。数は 0 |
| 動的・状態を持つ動的 | list/tuple の各要素と Option/Result の存在するペイロードごとに `size_of::<Val>()`（対応環境では 40 バイト）。Bytes も各バイトを Val として数える。record は各欄の Val と WIT の欄名、variant は場合名と存在するペイロードの Val、enum は場合名、map は全組の鍵と値の Val、flags は選択項目名の UTF-8 のバイト数。子の費用も加える。string の引数は UTF-8、戻り値はゲストの符号化のバイト数、外部の型は 0 |

理由: 型付きと補助は動的な Val の展開を避けるため、同じ値でも関数の契約と経路によって上限へ達する量が変わる。動的な flags の名前の列そのものの記憶域を、この論理上の予算で制限したとは扱わない。

【決定】補助には、転送予算と別に、引数と結果それぞれの言語の値の構築予算を設け、同じ `--wasm-transfer` の値を上限にする。値の出現一つを 16 バイトとし、String と Bytes の内容のバイト数を加える。構成子とその各欄、list の要素、map の全組の鍵と値、flags の選択項目も出現として数える。Bytes の個々の u8 は数えず、List[Byte] の各要素は数える。Map と Set 自体は一つの値である。根の record、map の各組、複数引数のペイロードをまとめる ABI 専用の tuple は出現に数えない。サイズ零の ABI の要素と、重複で消える map の値も数える。補助は加算前に、ホストは値の確保前に検査する。理由: 短いバイト列から大量の言語の値を構築する入力を抑え、実際に作る構成子に合わせて費用を数えるためである。

構築量は論理上の量であり、ヒープの節点・確保器・変換の作業領域を含むプロセス全体のメモリ上限ではない。String/Bytes の 2^30 バイト、List の 2^24 要素は全経路で確保前に検査し、Map/Set には言語共通の新しい要素数上限を設けない。補助の線形メモリ・コアインスタンス・表も Store の既存の上限に含め、生成した走査と元ゲストを同じ燃料と epoch の中断の対象にする。既定値は自動で上げない。補助は複数のコピーを保持するため、転送量の約 3〜4 倍のメモリを要する場合があり、従来の経路で通る値でも 64 MiB の既定上限に達しうる。メモリ不足の診断には補助のメモリも含むことを注記する。

【決定】引数の予算の検査と変換（速い経路の文字列と `Bytes` は借用、リストは型付きの並びへの変換）は、実行時の遅延コンパイル・Store の作成・インスタンス化・解放待ちの列の処理より先に行い、戻り値は Wasmtime の hostcall fuel で持ち上げの途中に制限する。言語の値を作るときの大きさの上限より先に、この予算に達する場合がある。値の根拠と実装は[ランタイム](../02-impl/02-09-runtime.md)の「外部の関数の実行」で定める。検査時のコンパイルは引数の値がまだない別の段である。理由: start の失敗より引数の誤りを先に報告するためである。

【決定】`--wasm-stats` を指定した場合は、CLI の一回の起動の終わりに、上限と消費量を JSON の一行で標準エラー出力へ書く。`test` はテストの関数の実行をすべて集計し、テストごとの内訳は出さない。呼び出しの回数は、引数の検査で止まった試行も含む。指定しない場合は集計を作らず、戻り値の統計のための走査も行わない。補助の転送・構築・値の大きさの予算検査は、統計の指定によらず行う。参照インタプリタと公開の埋め込みの実行 API は既定の上限を使う。理由: 普段の出力を変えずに、上限の設定と実際に数えた量を確認できるようにするためである。

補助の `construction_bytes` は、検査済みの引数と結果の構築量の和であり、転送量とは別に集計する。型付き・動的・状態を持つ経路の呼び出しは、この量も `incomplete_calls` も増やさない。補助で全量を測る前に止まった場合だけ、その欄の `incomplete_calls` を増やす。

燃料の消費量は、呼び出しのために設定した値から `Store::get_fuel()` の残量を引く。インスタンス化と解放待ちの列の処理も含む。線形メモリは制限器が受け付けた成長の合計を使い、ゲスト自身の maximum による拒否を含めない。確保が後で失敗しても計数は戻さない。最大は呼び出しごとの合計（状態を持つインスタンスでは寿命の合計）の最大、合計は各呼び出しの成長分の和とし、同じインスタンスのメモリを重ねて加えない。

引数の受け渡しの量は予算の検査で数えた値を使う。戻り値の量は、取得した戻り値を前述の規則で数える。Wasmtime 49.0.2 の公開の `Store::hostcall_fuel()` は設定値を返し、残量を返さないためである（出典: [Store の実装](https://docs.rs/crate/wasmtime/49.0.2/source/src/runtime/component/store.rs)、[持ち上げの局所の予算](https://docs.rs/crate/wasmtime/49.0.2/source/src/runtime/component/func/options.rs)）。値を取得する前の失敗などで計数できなかった呼び出しは `incomplete_calls` に数え、その方向の合計と最大には加えない。失敗した呼び出しの部分的な持ち上げの消費量は取得できない。

型付きと動的な経路の文字列の統計は処理系の UTF-8 表現のバイト数を使う。補助の統計は UTF-8 に変換済みの転送形式の全長を使い、文字列だけの量へ分けない。型付きと動的な経路で戻り値を UTF-16 または Compact UTF-16 で持ち上げる場合、Wasmtime はゲストの符号化されたバイト数を数えるため、UTF-8 の統計と実際の hostcall fuel の消費量が異なることがある。UTF-16 はコード単位ごとに 2 バイト、Compact UTF-16 は Latin-1 の場合に 1 バイト、それ以外は UTF-16 のコード単位ごとに 2 バイトを数える（出典: [Wasmtime 49.0.2 の WasmStr::new](https://docs.rs/crate/wasmtime/49.0.2/source/src/runtime/component/func/typed.rs)）。

| JSON の欄 | 内容 |
|---|---|
| `wasm_stats` | 報告の識別用の `true` |
| `limits.memory`・`limits.fuel`・`limits.transfer` | 設定した上限。大きさはバイト数 |
| `overrides.memory`・`overrides.fuel`・`overrides.transfer` | 対応する引数を指定したか。既定値と同じ値でも指定したら `true` |
| `calls` | 呼び出しの回数の合計 |
| `fuel`・`memory`・`arguments_transfer`・`results_transfer` | 各消費量の `total`（合計）・`maximum`（最大）・`incomplete_calls`（計数できなかった回数） |
| `construction_bytes` | 補助の引数と結果の論理上の構築量の和の `total`・`maximum`・`incomplete_calls` |
| `routes` | `typed`・`adapter`・`dynamic`・`stateful` ごとの試行回数 |
| `fallback_reasons` | 動的への事前の振り分けの理由ごとの試行回数 |
| `adapter_failures` | 補助の報告番号 `code`・要求量 `requested`・上限 `limit`・回数 `calls` の列 |
| `functions` | コンポーネントの表示用パスと宣言の関数名を `"<component>#<function>"` で結んだ鍵ごとの回数・各消費量・達した上限。欄は起動全体のものと同じ |
| `reached_limits` | 停止を起こした上限名から回数への表。名前は `fuel`・`memory`・`transfer`、または `core_instances`・`core_memories`・`core_tables`・`table_elements` |
| `stateful_instances` | インスタンスごとの `instance`（起動内の通し番号）・`component`（表示用パス）・`maximum`（寿命の線形メモリの最大） |

【決定】ゲストのトラップとコンポーネントの ABI 違反・資源の上限以外の元ゲストのインスタンス化の失敗は実行時エラー R0601、燃料の上限は資源の不足 R0904、線形メモリ・受け渡し・構築の予算の上限は R0905（線形メモリか受け渡しの予算かを注記し、構築の上限も受け渡しの予算として示す）、表の要素数とコアのインスタンス・メモリ・表の数の上限は R0906、戻り値から作る値の上限は R0902 として停止する。コンポーネントの `Result.Error` は宣言の型に従った値であり、トラップとは区別する。ゲストの panic と Rust のメモリ不足も `unreachable` のトラップとして現れうる。経路によって Wasmtime のトラップの文言が変わる場合も、分類は同じである。生成コードの検証失敗、補助形式・変換表と値の不一致、ゲストのトラップや資源の上限ではない補助のインスタンス化の失敗は処理系の不具合とする。

内部の報告関数の番号 1/2 は引数/結果の転送、3/4 は引数/結果の構築、5 は既存の値の大きさ、6 は realloc のメモリ不足、7 は補助形式・配置の不一致である。1〜4 と 6 は R0905、5 は R0902、7 と未知の番号は処理系の不具合とする。ホストは専用の Rust のエラー型で受け取り、失敗後に診断用の Wasm 関数を呼び直さない。燃料・中断・Store の制限器の失敗は既存の分類を優先する。

【決定】実行は同期で行い、その間はほかのタスクへ切り替えない。`SIGINT`・`SIGTERM` の中断は Wasm の実行中にも受け付け、トラップの報告を出さず終了状態 130 で終える。`Task.withTimeout` の取り消しは、外部の関数の実行中には効かない。理由: タスクの切り替えを行わず、タイマーの満了を処理する位置へ戻らないためである。

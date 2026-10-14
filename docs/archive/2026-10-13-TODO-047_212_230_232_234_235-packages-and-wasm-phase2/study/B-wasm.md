# 調査 B: WASM の実行系とゲストの試作（フェーズ 2）

調査日: 2026-10-13。対象: `todo-items.md` の TODO-047（受け渡す型の拡張）・TODO-230（大きな `Bytes` の経路）・TODO-235（インターフェースの書き出し）・TODO-212（`Hash`・`Regex`・`Json` の仮の実装）。

「試した」と書いたものは、次の作業場所で実際にビルドして動かした結果である。一次資料は、wasmtime 49.0.2 と wasmtime-environ 49.0.2 のソース（`~/.cargo/registry/src/*/wasmtime-49.0.2/`）と、Component Model の仕様（`design/mvp/WIT.md` と `design/mvp/Explainer.md`。main のコミット 6c48079b を 2026-10-13 に取得）である。確かめていないことは「未確認」、根拠からの推測は「推測」と書いた。

## 作業場所と環境

作業場所: `/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/pkg2/wasm/`（以下 `$W`）。

| 場所 | 内容 |
|---|---|
| `$W/guests/demo/` | インターフェースの書き出しと合成の型を確かめるゲスト（`wit/demo.wit`、`src/lib.rs`） |
| `$W/guests/hash/` | Hash のゲスト（sha2 0.10.9） |
| `$W/guests/regex/` | Regex のゲスト（regex 1.13.1。resource の形と毎回パターンを渡す形） |
| `$W/guests/json/` | Json のゲスト（serde_json 1.0.154。文字列から文字列、平らな節点の表、resource の三つの形） |
| `$W/out/*.wasm` | 上の四つのコンポーネント |
| `$W/variants/` | 最適化と機能の設定を変えたゲストの大きさの比較 |
| `$W/host/` | 試しのホスト。`src/bin/` の `names`（1）、`types`・`typeerr`（3）、`resource`（2）、`bytes`・`typedmany`・`typedfew`（4）、`json`・`regexlong`（5）、`inst`（6） |
| `$W/spec/` | 取得した仕様の文書と、再帰する WIT の試し（`rec/rec.wit`） |

- 環境: macOS（aarch64-apple-darwin）、Rust 1.98.1。wasmtime 49.0.2（機能 `runtime`・`component-model`・`std`・`cranelift`。Benitoite と同じ）、wit-bindgen 0.62.0、wasm-tools 1.261.0（`scratchpad/pkg/wasmtest/tools/bin/wasm-tools`）。
- エンジンの設定は Benitoite の `external::engine_config` と同じにした（`consume_fuel`・`epoch_interruption`・`max_wasm_stack(512 KiB)`）。
- 時間はすべて release ビルドの簡単な計測（中央値）で、機械の状態を整えていない。**正式な測定ではなく目安である**（正式な測定は Q4 のとおり実装の後に行う）。

## 要約

- **インターフェースの関数は二段で引く。** `Component::get_export(None, "bnt:demo/api@1.2.0")` でインスタンスの索引を得て、`get_export(Some(&idx), "slug")` で関数を得る（試した）。`ns:pkg/iface#name` の形の名前は、Wasmtime のコンポーネントの API では引けない。`#` は、wit-component がコアのモジュールの書き出しに付ける名前の形である。インスタンスを作る前に、`component_type()` から書き出したインターフェースの関数の型を読める。
- **版の照合は semver の互換で緩い。** `@1.2.0` を書き出したコンポーネントは、`@1.0.0` でも `@1.9.9` でも引けた。`@1`・`@1.2`・版なし・`@2.0.0` では引けなかった（試した。ソース `names.rs` の `alternate_lookup_key`）。宣言より古い版が引けてしまうので、Benitoite は、実際の書き出しの名前を列挙して自分で照合する方がよい（判断）。
- **関数の呼び出しが誤りを返すと、Store 全体が使えなくなる。** 罠のほか、ホストの側の引数の形の誤り（record の欄の順、variant の場合の名前など）や、捨てた resource の使用でも、Store に「罠が起きた」の印が立つ。印が立つと、同じ Store の別のインスタンスにも入れなくなる（`cannot enter component instance`）。例外は、引数の数の誤りだけだった（試した。ソース `func.rs` の `set_trapped`）。
- **resource は動けるが、Store を長く持つ必要がある。** `[static]pattern.compile` → `[method]pattern.is-match` → `ResourceAny::resource_drop` の流れは動いた。`ResourceAny` は `Copy` の索引で、実体は Store にある。罠が起きると、その Store の resource はすべて使えなくなり、destructor も走らない。燃料と epoch の期限は Store に一つなので、呼び出しのたびに入れ直す。メモリの上限は Store の寿命の全体で数えることになる。
- **record・variant・enum・flags・option・result・tuple は `Val` で受け渡せる。** record の欄は WIT の順に並べる必要がある。再帰する型は、仕様が禁じ、wasm-tools も誤りにした（試した）。
- **list<u8> の速い経路は TypedFunc で作れる。** `TypedFunc<(&[u8],), (Vec<u8>,)>` で呼べた。1 MiB の往復は、`Val` の経路が 16.7 ms、TypedFunc が 37〜46 µs で、約 400 倍の差だった。`Val` の list<u8> は 1 要素 40 バイトを確保した。受け渡しの予算（hostcall fuel）は、TypedFunc では 1 バイトにつき 1、`Val` では 1 要素につき 40 を数える。10 MiB の戻り値は、`Val` の経路では予算 256 MiB を超えて失敗した。
- **TypedFunc は型の組み合わせごとに具体化が要る。** `ComponentType` を自前で実装するには `unsafe impl` と `#[doc(hidden)]` の関数が要るので、Benitoite の規約に合わない。型を {s64, f64, string, list<u8>} に限り、引数 0〜3 個と結果 1 個の 340 通りを具体化すると、ホストの実行ファイルが約 0.8 MB 増えた（試した）。
- **三つのゲストは取り込みなしで作れた。** wasm32-unknown-unknown + wit-bindgen 0.62.0 + `wasm-tools component new`（adapter なし）で、Hash 22 KB、Json 81 KB、Regex 926 KB になった（`opt-level = "s"`、LTO）。wasip2 で作ると、Hash でも WASI を 14 個取り込んだ。依存はネットワークから取得できた。
- **Regex は resource で持つ価値が大きい。** 短い入力の 1,000 回の照合は、resource を使い回す形が 0.65 ms、毎回パターンを渡す形が 78 ms、毎回インスタンスも作る形が 110 ms だった。20 MB の入力の照合は、燃料（OutOfFuel）でも epoch（Interrupt）でも止められた。
- **インスタンスの作成は 5〜22 µs、コンパイルは 15〜470 ms だった。** 呼び出しごとにインスタンスを作る今の形は、小さなゲストでは軽い。Regex（926 KB）のコンパイルは約 0.47 秒かかる（TODO-228 の材料）。

---

## 1. インターフェースの書き出し（TODO-235）

### 1.1 WIT の書き方と、コンポーネントに残る名前（試した）

`$W/guests/demo/wit/demo.wit` は、次の四つの形の書き出しを持つ。

```wit
package bnt:demo@1.2.0;
interface api { ... slug: func(s: string) -> string; ... }
interface other { hello: func() -> string; }
world demo {
  export api;                                 // パッケージのインターフェース
  export other;
  export top: func(s: string) -> string;      // world の直下の関数
  export inline: interface { f: func() -> s32; }  // world の中に書いたインターフェース
}
```

`wasm-tools component wit out/demo.wasm` の出力の world は次のとおりである。

```wit
world root {
  export top: func(s: string) -> string;
  export bnt:demo/api@1.2.0;
  export bnt:demo/other@1.2.0;
  export inline: interface { f: func() -> s32; }
}
```

- world の名前（`demo`）はコンポーネントに残らず `root` になる（フェーズ 1 と同じ）。一方、インターフェースの名前は、パッケージの名前空間・名前・版を含む `bnt:demo/api@1.2.0` の形で残る。
- パッケージの版は、そのパッケージのすべてのインターフェースに付く。
- world の中に書いたインターフェース（`inline`）は、版も名前空間もない平らな名前 `inline` で書き出される。
- インターフェースと world に同じ名前は付けられない（`duplicate item named json` で wit-bindgen が失敗した。Json のゲストは、インターフェースを `codec` に改めた）。

仕様の名前の文法（Explainer.md「Import and Export Definitions」の `externname`）は、`plainname`（`label`、`[constructor]`・`[method]`・`[static]` の付いた名前）と `interfacename`（`namespace words projection interfaceversion?`。例 `ns:pkg/iface@1.2.0`）の二つだけである。`#` を含む名前はない。

### 1.2 Wasmtime 49.0.2 での引き方（試した。`$W/host/src/bin/names.rs`）

- `Component::get_export(instance: Option<&ComponentExportIndex>, name)` と `Component::get_export_index` が、入れ子の書き出しを一段ずつ引く（ソース `src/runtime/component/component.rs` の 794 行目と 876 行目付近）。`Instance::get_export`・`Instance::get_export_index` も同じ形で、インスタンスを作った後に使う（`instance.rs` 289・334 行目付近）。
- 得た `ComponentExportIndex` を `Instance::get_func(&mut store, &idx)` に渡す。
- 結果:

| 引いた名前 | 結果 |
|---|---|
| `top` | 関数 |
| `bnt:demo/api@1.2.0` | インスタンス |
| `bnt:demo/api@1.0.0`・`bnt:demo/api@1.9.9` | インスタンス（同じもの） |
| `bnt:demo/api@1`・`bnt:demo/api@1.2`・`bnt:demo/api`・`bnt:demo/api@2.0.0` | なし |
| `bnt:demo/api@1.2.0#slug`・`api` | なし |
| `inline` | インスタンス |
| `api` の中の `slug`・`move-point` | 関数 |
| `api` の中の `point` | 型（`ComponentItem::Type`） |
| `Instance::get_func(store, "bnt:demo/api@1.2.0#slug")`・`get_func(store, "slug")` | なし |

- `Component` から得た索引は、その `Component` から作った別の Store のインスタンスにもそのまま使えた。別にコンパイルした `Component` の索引は使えなかった（`ComponentExportIndex` が `Component` の識別子を持つ。ソース `lookup_export_index`）。このため、照合のときに一度引いた索引を、`ExternalRuntime` が持つコンパイル済みのコンポーネントと一緒に保存し、呼び出しごとの文字列の照合を省ける（案）。

### 1.3 版の扱い（ソースで確かめ、試した）

- 名前の表は `wasmtime_environ::component::NameMap` で、まず完全に一致する名前を探し、なければ semver で互換な名前を探す（ソース `wasmtime-environ-49.0.2/src/component/names.rs` の `NameMap::get`）。
- 互換の鍵は `alternate_lookup_key` が作る。主版が 0 でなければ `@主版`、主版が 0 で副版が 0 でなければ `@0.副版` までを鍵にする。`0.0.x` とプレリリースの版は互換の鍵を持たない。表に同じ鍵の版が複数あると、最も大きな版を残す。
- 結果として、`@1.2.0` を書き出したコンポーネントを `@1.9.9` で引いても見つかる（1.2 の試しの表）。これは、宣言が求める版（1.9.9）より古い版（1.2.0）でも照合が通ることを意味する。Benitoite の `@external` が版つきの名前を書くなら、`component_type().exports()` で実際の名前を列挙し、版を自分で比べる方が安全である（判断）。照合の誤りは、型の照合で捕まることが多い（新しい版で加えた関数がなければ、関数を引けない）が、型が同じで意味だけ変わった場合は捕まらない（推測）。
- 仕様は、版を `canonversion`（`1`・`0.2` など）に縮めた「canonical な名前」を 🔗 の印つきで定めている。今の非 canonical な名前は「temporarily permitted」で、将来拒まれうると書く（Explainer.md「Canonical Interface Name」）。wasm-tools 1.261.0 の出力は `@1.2.0` の形だった。Wasmtime と wasm-tools が canonical な名前に移る時期は未確認である。

### 1.4 照合の前に型を読む（試した）

- `component.component_type().exports(&engine)` は、`(&str, ComponentExtern)` の並びを返す。`ComponentExtern.ty` が `ComponentItem::ComponentInstance(ty)` なら、`ty.exports(&engine)` で中の関数（`ComponentItem::ComponentFunc`）・型（`Type`）・resource（`Resource`）を列挙できる。`Component::get_export(...)` の戻り値の `ComponentItem` からも同じ情報を読める。インスタンスを作る必要はない。
- 関数の型は `ComponentFunc::params()`・`results()` で読む。record・variant などは `Type::Record(r)` の `r.fields()`（`Field { name, ty }`）、`Type::Variant(v)` の `v.cases()`（`Case { name, ty: Option<Type> }`）、`Type::Enum(e).names()`、`Type::Flags(f).names()`、`Type::Option(o).ty()`、`Type::Result(r).ok()`/`err()`、`Type::Tuple(t).types()` で辿れた（`$W/host/src/bin/types.rs` の `show`）。出力の例:

  ```
  move-point: (p: record{x: S64, y: S64, label: String}, dx: S64) -> [record{x: S64, y: S64, label: String}]
  area: (s: variant{circle(Float64), rect(record{...}), empty}) -> [Float64]
  maybe: (x: option<S64>) -> [result<String, String>]
  ```

- resource のメソッドは、インスタンスの中に `[method]pattern.is-match` などの名前の関数として並ぶ。第 1 引数は `self: Borrow(ResourceType)` である（2.1）。

### 1.5 wit-bindgen が普通に作る形

- wit-bindgen は、WIT に書いた world のとおりに作る。world の直下の関数は `Guest` トレイトのメソッドに、`export api;` は `exports::bnt::demo::api::Guest` トレイトになる（`$W/guests/demo/src/lib.rs` で両方を書いて試した）。どちらが既定ということはない。
- `export api;` と `export top: func` は一つの world に混ぜられる（試した）。
- 世の中の Rust のゲストでどちらが多いかは調べていない（未確認）。WASI の world がインターフェースを書き出す形を使うことも、今回の一次資料では確かめていない（未確認）。
- resource は interface の中か world の中に書く必要がある（WIT の `resource` は `interface` か `world` の項目）。Regex・Json のゲストは、resource を interface に置いたので、インターフェースの書き出しを指す仕組み（TODO-235）がないと Benitoite から呼べない。world の直下に resource を書く形は試していない（未確認）。

---

## 2. resource（TODO-047・TODO-212 の Regex）

### 2.1 作る・呼ぶ・捨てる流れ（試した。`$W/host/src/bin/resource.rs`）

Regex のゲストの WIT（`$W/guests/regex/wit/regex.wit`）:

```wit
interface re {
  record span { start: u32, end: u32 }
  resource pattern {
    compile: static func(source: string) -> result<pattern, string>;
    is-match: func(text: string) -> bool;
    find: func(text: string) -> option<span>;
    count: func(text: string) -> u32;
    replace-all: func(text: string, replacement: string) -> string;
  }
  is-match-once: func(source: string, text: string) -> result<bool, string>;
  count-once: func(source: string, text: string) -> result<u32, string>;
}
```

- インスタンスの書き出しには、`pattern`（`ComponentItem::Resource`）、`[static]pattern.compile`、`[method]pattern.is-match` などが並んだ。名前の形は仕様の `plainname` のとおりである（WIT.md の `%[constructor]blob`・`%[method]blob.write`・`%[static]blob.merge` の例）。
- 失敗しうる作成は、`constructor` ではなく `static func ... -> result<pattern, string>` で書いた。仕様は `constructor(...) -> result<blob2>` の形も認めている（WIT.md 1822 行目付近）が、Wasmtime 49.0.2 と wit-bindgen 0.62.0 での扱いは試していない（未確認）。
- 流れ:
  1. `compile` を `Val::String` で呼ぶと、`Val::Result(Ok(Some(Box<Val::Resource(ResourceAny)>)))` が返った。`owned() == true`、型は `ResourceType { kind: Guest { store, instance, id } }` だった。
  2. メソッドは `[Val::Resource(p), Val::String(..)]` で呼ぶ。`Val::Bool(true)` などが返った。
  3. `p.resource_drop(&mut store)` で捨てる。ゲストの destructor が走る（ソース `resources/any.rs` の `resource_drop_impl`）。
- `ResourceAny` は `#[derive(Copy, Clone)]` の小さな値（Store の中の表の索引、型、所有か借用か）で、寿命の引数を持たない（ソース `resources/any.rs` 48 行目）。言語のヒープに置かず、ホストの表の番号で指す形にできる（推測）。説明は、借用を含むすべての `ResourceAny` に `resource_drop` を呼ぶことを求めている。

| 操作 | 結果 |
|---|---|
| 捨てた後にもう一度 `resource_drop` | `Err("unknown handle index 1")`。Store は使い続けられた |
| 捨てた後にメソッドを呼ぶ | `Err("host-owned resource was already de-allocated")`。**Store の印が立ち、同じ Store の別のインスタンスも使えなくなった** |
| インスタンス 1 で作った resource を、同じ Store のインスタンス 2 のメソッドに渡す | `Err("mismatched resource types")`。これも Store の印が立った |

捨てた resource を使うことは、Benitoite の側で防ぐ必要がある（リソースの型の線形性、あるいは捨てた印をホストの表に持つ）。

### 2.2 呼び出しの誤りと Store の印（ソースで確かめ、試した）

- `Func::call` は、引数の数を確かめた後に `call_raw` に入る。`call_raw` の結果が誤りなら、`store.0.set_trapped()` で Store 全体に印を立てる（ソース `src/runtime/component/func.rs` 388〜391 行目）。以後、その Store の関数の呼び出しは、`may_enter()` が偽になり `Trap::CannotEnterComponent` を返す（同 468 行目、`store.rs` の `may_enter`）。`resource_drop` も、destructor を持つ resource では同じ理由で失敗する（`resources/any.rs` 205 行目）。
- 試した結果（`$W/host/src/bin/typeerr.rs`）。各行は新しい Store で試した。

| 一回目の呼び出しの誤り | 同じインスタンス | 同じ Store の新しいインスタンス |
|---|---|---|
| record の欄の順が違う（`expected field 'x', got 'y'`） | 入れない | 作れるが入れない |
| record の欄の名前が違う | 入れない | 同上 |
| variant の場合の名前が違う・中身がない | 入れない | 同上 |
| enum の名前が違う | 入れない | 同上 |
| 数の型が違う（s64 に S32） | 入れない | 同上 |
| 引数の数が違う | **使える** | 使える |
| ゲストの panic（`unreachable`） | 入れない | 作れるが入れない |
| 燃料切れ | 入れない | 作れる（呼び出しは試していないが、上と同じ印で入れないはずである。推測） |

- epoch の期限が過ぎた Store では、`instantiate` も `Trap::Interrupt` になった。その後に期限を入れ直しても、その Store のインスタンスには入れなかった。
- **Benitoite への示唆**: 今は呼び出しごとに Store を作るので、この印は問題にならない。resource のために Store を長く持つと、(a) 一度の罠や変換の誤りで、その Store の resource がすべて使えなくなる、(b) 値の変換の誤りも罠と同じ扱いになるので、宣言の型から作る `Val` が WIT の形（欄の順、場合の名前）に正しく合うことが、今より重要になる。

### 2.3 Store を長く持つときの燃料・メモリ・epoch（試した）

- **燃料**: Store に一つの残量である。`Store::set_fuel` は残量を設定し直すので、呼び出しの前に毎回入れ直せば、呼び出しごとの上限になる。試しでは、パターンの作成（インスタンスの作成を含む）が約 169 万、1 MB の入力の `count` が約 1.4 億を使った。燃料 10,000 で `count` を呼ぶと `OutOfFuel` で止まった。
- **epoch**: 期限は `set_epoch_deadline` を呼んだ時点の epoch からの相対である（ソースの説明）。呼び出しの間に epoch が進むと、期限を入れ直さない限り次の呼び出しはすぐ `Interrupt` になった。Benitoite の今の作り（中断の印が立っている間だけ epoch を進める）では、印を戻した後も期限が過ぎたままになるので、呼び出しの前に毎回 `set_epoch_deadline(1)` を呼ぶ必要がある（推測。今のコードは Store を作るたびに呼んでいる）。
- **メモリ**: 線形メモリは縮まない。20,000 個のパターンを捨てずに作ると、ゲストのメモリは 1.4 MB から 100.7 MB に増えた。すべて捨てた後も 100.7 MB のままで、さらに 20,000 個作っても増えなかった（ゲストの確保器が解放した領域を使い回す）。このため、今の「一回の呼び出しの線形メモリの合計 64 MiB」（`CallLimits`）は、Store を長く持つと「Store の寿命の合計」に変わる。上限に当たった Store を捨てて作り直すと、その Store の resource はすべて失われる。
- **捨て忘れ**: Store を捨てれば、捨てていない resource もまとめて消える（ゲストの destructor は走らない）。ゲストの destructor が外部の状態を持たない純粋なゲストでは、これで困らない（推測）。
- **罠の後の resource の捨て方**: メソッドの実行中に罠が起きると、`resource_drop` は `cannot remove owned resource while borrowed` を返した。借用の印が残るためである。罠の後は Store ごと捨てるほかない。

### 2.4 一つの Store に複数のインスタンスを持つときの上限（試した）

- `StoreLimits` の `instances` は、コンポーネントのインスタンスではなく、コアのモジュールのインスタンスを数える（`StoreLimitsBuilder::instances` の説明は「The maximum number of instances that can be created for a Store. Module instantiation will fail if this limit is exceeded.」である。ソース `src/runtime/limits.rs` 255 行目付近。コアのインスタンスを数えることは、次の試した結果から判断した）。Regex のコンポーネントは、`instances(3)` で 1 個目が作れて 2 個目が「instance count too high at 4」、`instances(4)` で 2 個目が「at 5」で失敗した。1 個のインスタンスが 3 個のコアのインスタンス（`$main`・`$wit-component-shim-module`・`$wit-component-fixup`）を数えている。resource を持たないゲストでは数が違う（未確認）。
- `StoreLimits::memory_size` は線形メモリ一つごとの上限で、Store の合計ではない。`memory_size(4 MiB)` の Store に 10 個のインスタンスを作り、それぞれでパターンを作れた。Store の合計を抑えるには、Benitoite の `CallLimits` のように `ResourceLimiter` を自前で書いて合計を数える。
- Benitoite の今の `OBJECTS = 16`（`instances`・`memories`・`tables`）は、一つの Store に Regex のような resource を持つインスタンスを 5 個までしか置けない数である。

### 2.5 設計の候補（判断の材料。推測を含む）

| 形 | 利点 | 欠点 |
|---|---|---|
| A. resource を作った呼び出しの Store を、resource が生きている間持つ（resource ごとに Store 一つ） | 罠の影響が一つの resource に閉じる | resource ごとにインスタンスの費用（Regex で 22 µs と初期のメモリ 1.4 MB）がかかる。resource を引数に取る別の resource の関数（例: 二つのパターンを合わせる）が書けない |
| B. 一回の実行で、コンポーネントごとに Store を一つ持つ | resource どうしを渡せる。インスタンスの作成が一度で済む | 一度の罠で、そのコンポーネントの resource がすべて使えなくなる。メモリの上限が実行の全体にかかる |
| C. resource を持たない関数は今のとおり呼び出しごとの Store、resource を返す関数とメソッドだけ B の Store | resource を使わない関数の振る舞いが変わらない | 同じコンポーネントに二つの経路ができる |

いずれの形でも、Benitoite のリソースの型の値には、Store を指す番号と `ResourceAny` を持たせ、言語の値（`Value<'epoch>`）を Store に置かない（Wasmtime の `Store` のデータに言語の値を置かない今の規約と同じ）。Benitoite の中断（02-09「中断の要求」）と取り消しでリソースを返すときに `resource_drop` を呼ぶ順序は、別に決める必要がある。

---

## 3. 合成の型の `Val` の形と、再帰する型（TODO-047）

### 3.1 `Val` の形（試した。`$W/host/src/bin/types.rs`）

| WIT | 渡した `Val` / 返った `Val` |
|---|---|
| `record point { x: s64, y: s64, label: string }` | `Val::Record(vec![("x", S64(2)), ("y", S64(3)), ("label", String("p"))])` |
| `variant shape { circle(f64), rect(point), empty }` | `Val::Variant("circle", Some(Box::new(Float64(2.0))))`、`Val::Variant("empty", None)` |
| `enum color { red, green, blue-ish }` | `Val::Enum("blue-ish")` |
| `flags perms { read, write }` | `Val::Flags(vec!["read"])`（立っている名前の並び） |
| `option<s64>` | `Val::Option(Some(Box::new(S64(5))))`、`Val::Option(None)` |
| `result<string, string>` | `Val::Result(Ok(Some(Box::new(String("5")))))`、`Val::Result(Err(Some(..)))`。中身のない側は `None` |
| `tuple<s64, string>` | `Val::Tuple(vec![S64(1), String("a")])` |
| resource（own・borrow とも） | `Val::Resource(ResourceAny)` |

- record の欄は、名前を確かめたうえで **WIT の順に並べる必要がある**。順が違うと `expected field 'x', got 'y'` で失敗し、Store の印が立った（2.2）。Benitoite のレコードの欄の順と WIT の欄の順が違う場合は、変換で並べ替える必要がある。
- variant・enum・flags の名前は WIT の kebab-case の名前そのもの（`blue-ish`）で、`Val` は名前を `String` で持つ。値一つごとに名前の文字列を確保するので、大きな表（5.3 の節点の表）では確保が増える（ソース `values.rs` の `Val::Variant(String, Option<Box<Val>>)`）。
- `size_of::<Val>()` は 40 バイトだった（フェーズ 1 と同じ）。

### 3.2 再帰する型

- WIT.md は「Types, however, cannot be recursive:」と書き、`type foo = foo;` と互いに参照する record を誤りの例に挙げる（WIT.md 2037 行目付近）。フェーズ 1 の調査と同じ結論である。
- `variant value { null, array(list<value>) }` を wasm-tools 1.261.0 に通すと、「type `value` depends on itself」で誤りになった（試した。`$W/spec/rec/rec.wit`）。
- このため、`Json.Value` のような木は WIT の型で直接書けない。5.3 の三つの形で越える。

---

## 4. 大きな list<u8> と数のリストの速い経路（TODO-230）

### 4.1 TypedFunc で呼べるか（試した。`$W/host/src/bin/bytes.rs`）

- `instance.get_typed_func::<(&[u8],), (Vec<u8>,)>(&mut store, &idx)` で、`echo-bytes: func(b: list<u8>) -> list<u8>` を呼べた。引数は `Vec<u8>` でもよい（`get_typed_func::<(Vec<u8>,), (Vec<u8>,)>` も通った）。`&[i64]`・`&[f64]` と `Vec<i64>`・`Vec<f64>` も通った。
- 型が合わないと、`get_typed_func` の時点で `type mismatch with parameters: expected 'u16' found 'u8'` の誤りになる（Store の印は立たない。呼び出し前の確かめだからである）。
- ソースでは、`Vec<T>`・`&[T]`・`Box<[T]>`・`Arc<[T]>` が `list<T>` に対応する（`func/typed.rs` 417 行目の表と 875〜877 行目）。

### 4.2 時間と確保量（目安）

同じインスタンスを使い回した時間（中央値）と、1 回目の呼び出しの確保量（計数の確保器で測った）。

| 大きさ | echo（Val） | echo（typed） | sum（Val） | sum（typed） | Val の確保量 | typed の確保量 |
|---|---|---|---|---|---|---|
| 1 KiB | 16.3 µs | 0.2 µs | 5.1 µs | 0.6 µs | 123,856 B | 1,088 B |
| 1 MiB | 16.7 ms | 37〜46 µs | 5.4 ms | 0.53 ms | 126,877,648 B | 1,048,640 B |
| 10 MiB | 失敗（予算超過） | 0.47 ms | 55 ms | 5.3 ms | 419,430,629 B | 10,485,824 B |

- `echo` は往復、`sum` は行きだけ（結果は u64）。`sum` の typed の時間の大部分は、ゲストの中の合計の計算（燃料の数え上げつき）である（推測）。
- `Val::List` に 1 MiB の u8 を入れると、41,943,040 B（**1 要素あたり 40.0 B**）を確保した。往復では、引数の `Val`、戻り値の `Val`、`Vec<u8>` への変換で、約 121 倍の確保になった。
- 1M 要素の list<s64> と list<f64> の往復は、`Val` が 14.3 ms、typed が 0.31 ms だった。
- Hash の sha256 を、今の形（呼び出しごとに Store とインスタンスを作る）で呼んだ時間:

| 大きさ | Val | typed | ホストの sha2（ネイティブ） |
|---|---|---|---|
| 1 KiB | 17.7 µs | 12.7 µs | 1.9 µs |
| 1 MiB | 9.6 ms | 4.7 ms | 1.7 ms |
| 10 MiB | 95.5 ms | 46.4 ms | 16.5 ms |

  typed の経路でも、WASM の sha256 はネイティブの約 2.7 倍かかった。燃料の数え上げと、SIMD などの命令を使わないことの影響と推測する（確かめていない）。Hash では、境界の費用（Val と typed の差）とゲストの計算の遅さが同じくらいの大きさである。

### 4.3 受け渡しの予算（hostcall fuel）の数え方（ソースで確かめ、試した）

- `Store::set_hostcall_fuel` の予算は、ゲストからホストへ移すデータ（呼び出しの戻り値の lift）で消費する。ホストからゲストへの引数は数えない（`store.rs` 480〜516 行目の説明「data transferred from the host to the guest is not limited」）。試しでも、予算 1,000 で 1 MiB の引数を渡せた。
- `Val` の経路は、リストの要素一つごとに `size_of::<Val>()`（40）を数える（`values.rs` 1120・1148 行目）。typed の経路は、`WasmList::new` が `len * size_of::<T>()` を数える（`typed.rs` 1777 行目）。list<u8> なら 1 バイトにつき 1 である。文字列は、どちらもバイト数を数える。
- 試した結果: 予算 2 MiB で 1 MiB を返すと、typed は通り、`Val` は「fuel allocated for hostcalls has been exhausted」で失敗した。予算 256 MiB で 10 MiB を返す `Val` の経路も失敗した（10 MiB × 40 = 400 MiB）。
- Benitoite の今の予算（02-09「外部の関数の実行」。戻り値の 256 MiB を hostcall fuel で数える）は、typed の経路では、そのまま「バイト数」の予算として働く。引数の側の予算は、Benitoite の `convert::check_arguments` が自分で数えている。typed の経路にも同じ数え方（バイト数か要素数×40 か）を決める必要がある。

### 4.4 型の組み合わせと、`ComponentType` を自前で実装する可否

- `TypedFunc<Params, Results>` の `Params`・`Results` は、コンパイルの時点で決まる Rust の型である。Benitoite の宣言から実行時に選ぶには、使う組み合わせをあらかじめ具体化しておき、宣言の型の形で振り分けるほかない。
- record・variant・enum・flags の Rust の型は `#[derive(ComponentType, Lift, Lower)]` か `bindgen!` で作る（`typed.rs` 417 行目付近の表）。WIT の型ごとにコンパイルの時点で作るので、利用者のパッケージの record には使えない。
- `ComponentType`・`Lower`・`Lift` は `pub unsafe trait` で、必須の関数（`typecheck`、`linear_lower_to_memory` など）は `#[doc(hidden)]` である（`typed.rs` 498・573・668 行目）。自前の型（例えば、`Val` を持ちつつ list<u8> だけ速く写す型）に実装するには、`unsafe impl` を書き、版の互換を約束しない隠れた API に頼ることになる。AGENTS.md の規約（`unsafe` は `runtime::heap` の内部の層だけ）に合わないので、勧めない（判断）。
- コンポーネントの線形メモリに直接写す経路は、公開の API にない。`Instance` はコアのメモリや `cabi_realloc` を取り出す関数を持たない（`instance.rs` の公開の関数は `get_func`・`get_typed_func`・`get_module`・`get_resource`・`get_export`・`get_export_index` など。`get_module` が返すのはモジュールとして書き出したものだけである）。
- 具体化の費用（試した。`$W/host/src/bin/typedmany.rs`）: 型を {s64, f64, string, list<u8>} に限り、引数 0〜3 個と結果 1 個の全組み合わせ 340 通りの `typed` と `call` を具体化した。ホストの実行ファイルは 13,944,672 B（1 通り）から 14,763,184 B（340 通り）へ、約 0.8 MB（1 通りあたり約 2.4 KB）増えた。ビルドの時間の増分は数秒だった。
- **案**: 宣言の型が全部「速い経路の型の集合」に入る関数だけ TypedFunc で呼び、ほかは今の `Val` の経路で呼ぶ。集合と引数の数の上限を小さく保てば、具体化の数は抑えられる。例えば、`Bytes` か数のリストを含む関数に限り、ほかの引数を {s64, f64, bool, string} とする。どこまで含めるかは、Hash・Encoding・Csv の関数の形から決める（判断）。

---

## 5. ゲストの試作（TODO-212）

### 5.1 ビルドの手順と大きさ（試した）

各ゲストの `Cargo.toml` は次の形である（`$W/guests/<名前>/Cargo.toml`）。

```toml
[lib]
crate-type = ["cdylib"]
[dependencies]
wit-bindgen = "0.62.0"
sha2 = "0.10.9"            # Hash。Regex は regex = "1.12"、Json は serde_json = "1.0" と serde = "1.0"
[profile.release]
opt-level = "s"
panic = "abort"
lto = true
codegen-units = 1
strip = true
[workspace]
```

手順（`CARGO_TARGET_DIR=$W/target` を共有した）:

```sh
cd $W/guests/hash && cargo +1.98.1 build --release --target wasm32-unknown-unknown
wasm-tools component new $W/target/wasm32-unknown-unknown/release/hash.wasm -o $W/out/hash.wasm
wasm-tools component wit $W/out/hash.wasm
```

| ゲスト | 依存 | コアのモジュール | コンポーネント | `opt-level = 3` のコンポーネント |
|---|---|---|---|---|
| demo（確認用） | — | 38,665 B | 42,507 B | — |
| Hash | sha2 0.10.9 | 21,729 B | 21,969 B | 27,366 B |
| Json | serde_json 1.0.154 | 77,497 B | 80,997 B | 124,024 B |
| Regex | regex 1.13.1 | 922,767 B | 925,875 B | 1,149,936 B |

Regex の大きさの内訳を、設定を変えて見た（`$W/variants/`）。

| Regex の設定 | コンポーネント |
|---|---|
| 既定の機能、`opt-level = "s"` | 925,875 B |
| 既定の機能、`opt-level = "z"` | 868,520 B |
| `default-features = false, features = ["std", "perf"]`（Unicode の表なし） | 617,637 B |
| `default-features = false, features = ["std", "unicode"]`（速さの最適化なし） | 612,349 B |

Unicode の表と速さの最適化が、それぞれ約 0.3 MB を占める。Unicode の表を外すと、`\w` などの意味が Benitoite の今の `Regex`（Rust の regex クレートを既定の機能で使っていると推測。確かめていない）と変わるので、仮の実装は既定の機能のままにした。

- **取り込み**: 四つとも、コンポーネントの取り込みは 0 個だった（`wasm-tools component wit` と `component_type().imports()` で確かめた）。resource を持つ Regex と Json のコアのモジュールは、`[export]bnt:regex/re@0.1.0` の `[resource-new]pattern`・`[resource-drop]pattern` を取り込む。これは wit-component がコンポーネントの中で満たす正準の組み込みで、コンポーネントの取り込みにはならない。
- **wasip2**: Hash を `wasm32-wasip2` で作ると、`panic = "abort"` でも `wasi:io/*`・`wasi:clocks/monotonic-clock`・`wasi:cli/*` の 14 個（いずれも `@0.2.9`）を取り込んだ（フェーズ 1 の Fuzzy と同じ）。
- **wit-bindgen の版**: 0.62.0（フェーズ 1 と同じ）。生成されたコードを書き直さずに使えた。resource は `type Pattern = P;` と `impl GuestPattern for P` で書き、`Pattern::new(P(..))` で返す。
- **ネットワーク**: `cargo build` の「Updating crates.io index」が通り、`https://index.crates.io/config.json` も HTTP 200 を返した。今回の依存は、すでに `~/.cargo/registry` にあったものに解決した。
- **ビルドの時間**: wit-bindgen のマクロを含めて、何もない状態から demo が 7.7 秒、Regex が 5.2 秒（マクロはビルド済み）だった。

### 5.2 Regex（試した。`$W/host/src/bin/regexlong.rs`）

- **resource の形と毎回パターンを渡す形**（短い入力 `"Hello 2026 and World 12"` を 1,000 回）:

| 形 | 1,000 回の時間 |
|---|---|
| resource を一度作って使い回す | 0.65 ms |
| 毎回パターンを渡す（同じインスタンス） | 78 ms |
| 毎回パターンを渡し、毎回インスタンスも作る（今の呼び出しの形） | 110 ms |
| 参考: ホストのネイティブの regex | 0.045 ms |

  毎回パターンを渡す形の費用は、ゲストの中のパターンのコンパイル（1 回約 78 µs）が大部分である。Benitoite の `Regex.compile` → `Regex.isMatch` の使い方を WASM で再現するには、resource が要る。

- **大きな入力（19.8 MB）**: 毎回パターンを渡す形の `count` は 44 ms で、燃料を 7.2 億使った（約 0.06 ns/燃料）。ネイティブは 15.6 ms だった。燃料 10^7 では 2.1 ms、10^8 では 7.4 ms で `OutOfFuel` になった。epoch を別のスレッドから 5 ms 後に進めると、7.6 ms で `Interrupt` になった。regex クレートは破滅的な後戻りを起こさないので、長い照合は入力の大きさで作った。
- Benitoite の燃料の既定値（10^10）は、この照合では約 0.6 秒分にあたる（推測。燃料あたりの時間は処理によって違う）。

### 5.3 Json（試した。`$W/host/src/bin/json.rs`）

WIT（`$W/guests/json/wit/json.wit`）は三つの越え方を持つ。

1. **文字列から文字列**: `validate`・`pretty`・`minify`。
2. **平らな節点の表**: `parse: func(text: string) -> result<list<node>, parse-error>` と `stringify: func(nodes: list<node>) -> result<string, string>`。`node` は `variant node { null, boolean(bool), integer(s64), float(f64), text(string), array(u32), object(u32), key(string) }` で、前順に並べる。配列と対象は子の数を持ち、対象の子は `key` の節点と値の節点の対である。Benitoite の `Json.Value` の `Integer`・`Float` の区別も表せる。ゲストの側の組み立て直し（`rebuild`）は明示の積み重ねで書いた。
3. **resource**: `resource document { parse: static func(..) -> result<document, parse-error>; get: func(pointer: string) -> option<string>; len: ... }`。JSON Pointer で指した値だけを JSON の文字列で返す。

正しさ: `{"b":[1,2.5,"x"],"a":{"c":null,"d":true}}` を `parse` すると、鍵の順（serde_json の既定の `BTreeMap`）に並んだ 12 個の節点が返り、`stringify` で `{"a":{"c":null,"d":true},"b":[1,2.5,"x"]}` に戻った。誤りは `parse-error` の record（行・列・文）で返った。10 万段の入れ子の `[[[...]]]` は、`validate` が正しいと答えた（スタックを使い切らなかった）。

時間（呼び出しごとに新しいインスタンス。中央値。目安）:

| 入力 | validate | minify | parse→表 | 表→文字列 | ホストの serde_json の解析 | 節点の数 | document の parse + get | validate の燃料 |
|---|---|---|---|---|---|---|---|---|
| 1 KB | 4.6 µs | 19 µs | 28 µs | 34 µs | 4.3 µs | 253 | 13 µs | 57,012 |
| 100 KB | 0.18 ms | 1.7 ms | 2.3 ms | 3.0 ms | 0.34 ms | 22,240 | 0.85 ms | 5,015,899 |
| 10 MB | 18.7 ms | 168 ms | 226 ms | 294 ms | 39 ms | 2,185,534 | 84 ms | 501,289,004 |

- 「parse→表」は、ゲストの解析と、表を `Val` で返す費用の合計である。表は節点一つごとに `Val::Variant`（40 B）・場合の名前の `String`・中身の `Box<Val>` を確保するので、境界の費用が大きい（3.1）。Benitoite の `Json.Value` に組み直す費用は含まない。
- 10 MB の表（約 219 万節点）は、受け渡しの予算 256 MiB の中に収まった。節点の数がこの数倍の入力では、予算を超えると見込む（推測）。
- 要る値だけを読む課題では、resource の形（84 ms）が、表を全部返す形（226 ms）より速かった。
- Benitoite の `@builtin` の `Json`（A）と、Benitoite で書いた解析器（B）との比較は、この調査では行っていない。

---

## 6. インスタンスの作成とコンパイルの費用（試した。`$W/host/src/bin/inst.rs`）

| ゲスト | 大きさ | `Component::new`（Cranelift） | 新しい Store + `instantiate` | 新しい Store + `InstancePre::instantiate` | 作成直後の線形メモリ |
|---|---|---|---|---|---|
| demo | 42,507 B | 23 ms | 5.0 µs | 4.9 µs | 1,114,112 B |
| Hash | 21,969 B | 15 ms | 4.8 µs | 4.7 µs | 1,114,112 B |
| Json | 80,997 B | 51 ms | 5.7 µs | 5.6 µs | 1,114,112 B |
| Regex | 925,875 B | 468 ms | 22 µs | 22 µs | 1,441,792 B |

- インスタンスの作成は、300 回の中央値で 5〜22 µs だった。フェーズ 1 の 30〜100 µs より短いのは、繰り返して温まった状態の中央値を取ったためと推測する。`InstancePre` にしても差はなかった。
- 呼び出しごとにインスタンスを作る今の形の費用は、小さなゲストでは 1 回 5 µs 程度で、短い呼び出し（数 µs〜数十 µs）と同じくらいの大きさである。
- Regex のコンパイル（約 0.47 秒）は、Benitoite が検査と実行のたびに行う（TODO-047 の「コンパイル済みのコードの再利用」、TODO-228）。Regex を WASM の Unofficial のモジュールにするなら、この費用を毎回払うことになる。

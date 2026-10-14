# V4・V5 の事前点検の補足

- 点検はコミット `44548d5f`（san_benito）の処理系と、`wasmtime-49.0.2` のソースを読んで行った。行番号はこのコミットのものである。V1〜V3 は未取り込みなので、V2 の `ExternalSpec.instance`（インターフェースの名前）と二段の引き方、V3 の `DeclPlan`・`WitPlan::{Record, Variant, Enum}`・`bind` を前提に書いた（`reviews/preflight-V1V3.md`）。cargo のビルドとテストは走らせていない。`.wat` は手元の wasm-tools 1.261.0（dev-dependency の `wat = "=1.261.0"` と同じ版）の `validate` で確かめた。
- 新しい診断コード: V4 は足さない。V5 は `E0816`（区分 E08）と `E1012`（区分 E10）を使う。V2 が `E0815` を使うので、E08 の続きは `E0816` である。
- 既存の診断の文言を変えるときは、型板に引数を足し、既存の場合の出力が一字一句変わらない値を渡す（V1〜V3 の補足と同じ）。
- 凍結の表の範囲で足りないものが二つある（「オーケストレータへの報告」の 2・3）。本書は、推す形と、了承が得られないときの代わりの形の両方を書く。オーケストレータが設計者の答えに合わせてどちらかを消してから渡す。

## V4 への補足

### 経路の印

- `ExternalSpec` に `pub route: ExternalRoute` を足す。`ExternalRoute` は `src/external/mod.rs` に置く非公開でない列挙で、V4 では `Dynamic` と `Typed(TypedShape)` の二つを持つ。V5 は `Stateful` を足す。理由: V5 も経路を選ぶ印を要するので、真偽値や `Option` を二つ並べるより、一つの列挙に足すほうが選び方が一か所で済む。
- `TypedShape` は `{ params: Vec<TypedKind>, result: TypedKind }`、`TypedKind` は `S64・F64・String・Bytes` の四つとする。`WitPlan::S64・F64・String・Bytes` だけに当たり、`WitPlan::List(U8)`（`List[Byte]`）・`Bool`・`Char`・`U8` は当たらない。
- 印は `src/external/check.rs` で、V3 の `bind` が WIT の名前を焼き込んだ `WitPlan` を作った後に、関数 `ExternalRoute::of(&params, result.as_ref())` で決める。引数が 0〜3 個で、すべての引数と戻り値が四つの型のどれかなら `Typed`、それ以外（戻り値なしを含む。R6）は `Dynamic` とする。
- `ExternalSpec` を手で組み立てるテスト（`src/bytecode/liveness.rs` 655 行付近、`src/bytecode/verify.rs` 672 行付近、`src/external/convert.rs` の `spec()`、`src/external/runtime.rs` の `table()`）も同じ `ExternalRoute::of` で欄を埋める。手書きの `Debug`（`src/external/mod.rs` 86〜97 行）にも欄を足す。`ExternalSpec` は `Arc` で `CompiledProgram` に入り `assert_shareable` の対象なので、`route` に Wasmtime の型と `Rc` を入れない。

### 型付きの呼び出しの具体化

- 新しい非公開のモジュール `src/external/typed.rs` に置く。先頭の `//!` に役割と設計書 03-10「実行」を書く。
- 引数は `enum TypedArg<'a> { Int(i64), Float(f64), Str(&'a str), Bytes(&'a [u8]) }` に読む。`Str` と `Bytes` は `ctx.str(v)`・`ctx.bytes(v)` が返すヒープの中の借用をそのまま使い、写さない。`external::call` は `&NoGcCtx` を持ち、その間は回収が起きないので、呼び出しの間この借用は有効である（AGENTS.md「回収しない区間と値の扱い」に反しない。値を区間の外に置かない）。
- 戻り値は `enum TypedOut { Int(i64), Float(f64), Str(String), Bytes(Vec<u8>) }` で受け、言語の値への変換は具体化の外で一度だけ行う。理由: 340 個の葉を小さく保ち、実行ファイルの増分を調査 B の約 0.8 MB に近づける。
- 葉は一つの総称の関数で書く。

  ```rust
  fn call_leaf<P, R>(store: &mut Store<CallLimits>, func: &Func, params: P,
                     out: fn(R) -> TypedOut) -> Result<TypedOut, CallError>
  where P: ComponentNamedList + Lower, R: ComponentNamedList + Lift
  ```

  `func.typed::<P, R>(&*store)` の誤りは、照合で型を確かめた後なので `Stop::Internal`（処理系の不具合）にする。`typed.call(&mut *store, params)` の誤りだけを `failure()` に渡す。`CallError` は二つを区別する非公開の型でよい。
- 振り分けは `macro_rules!` の積み上げ（push-down accumulator）で書く。引数を一つずつ `match` し、型と値を角括弧の中に積み、引数を使い切ったら戻り値の種類で `match` して `call_leaf::<(..), (i64,)>` などを呼ぶ形である。

  ```rust
  macro_rules! dispatch {
      ($cx:tt [$($t:ty : $v:ident),*] ) => { leaf!($cx [$($t : $v),*]) };
      ($cx:tt [$($t:ty : $v:ident),*] $a:ident $($rest:ident)*) => {
          match $a {
              TypedArg::Int(x) => dispatch!($cx [$($t : $v,)* i64 : x] $($rest)*),
              TypedArg::Float(x) => dispatch!($cx [$($t : $v,)* f64 : x] $($rest)*),
              TypedArg::Str(x) => dispatch!($cx [$($t : $v,)* &str : x] $($rest)*),
              TypedArg::Bytes(x) => dispatch!($cx [$($t : $v,)* &[u8] : x] $($rest)*),
          }
      };
  }
  ```

  呼ぶ側は `match args.as_slice() { [] => dispatch!(cx []), [a] => dispatch!(cx [] a), [a, b] => ..., [a, b, c] => ..., _ => internal }` とする（`a` などは `let` で `TypedArg` の値に束縛してから渡す）。各段で束縛する `x` は、マクロの衛生により段ごとに別の名前になる。マクロで 340 個の葉が生成されることを、生成後のコードを数えるか、`TypedKind` の 4^0+4^1+4^2+4^3=85 通り × 戻り値 4 通りの説明のコメントで示す。`clippy::indexing_slicing` などの lint に当たらない形（`get`・スライスのパターン）で書く。
- `Lower` と `Lift` は `unsafe trait` だが、Wasmtime が実装済みの型（`i64`・`f64`・`&str`・`&[u8]`・`String`・`Vec<u8>`）を使うだけなので、`unsafe` は書かない（R6 の理由のとおり）。

### 実行の手順の共通化

- `call_with_fuel` を、(1) 表を引き引数の数を確かめる、(2) コンパイル済みのコンポーネントを得る、(3) `Store` を作り上限を設定する（今の 286〜292 行）、(4) インスタンスを作り関数を引く（V2 の二段の引き方）、(5) 経路ごとの呼び出し、(6) 戻り値の変換、に分ける。(1)〜(4) と `failure()` は経路で共有する。
- 経路ごとの関数を `call_dynamic`（今の `Val` の経路）と `call_typed` に分け、`call_with_fuel` は `spec.route` で選ぶ。テストは `call_dynamic` を `Typed` の印の付いた関数に直接使い、二つの経路の結果を比べる。
- テストで受け渡しの予算を小さくできるよう、`fuel: u64` の引数を非公開の `Limits { fuel: u64, transfer: u64 }` に置き換え、`check_arguments` の `limit` と `set_hostcall_fuel` の両方にこの値を渡す。本番の入口 `call` は `Limits { fuel: FUEL, transfer: TRANSFER }` を渡す。

### 予算と大きさの上限

- 引数: `call_typed` は変換の前に、`Str` と `Bytes` のバイト数の和を数え、`transfer` を超えたら今と同じ `ResourceError::ExternalTransfer` を返す（1 バイトにつき 1。Q7）。数は 0 と数える。`check_arguments`（`Bytes` を 1 バイトにつき `size_of::<Val>()` と数える）は `Dynamic` の経路だけで使い、変えない。
- 戻り値: `set_hostcall_fuel(transfer)` を今のとおり設定する。Wasmtime の型付きの持ち上げが `String` をバイト数で、`Vec<u8>` を `len × 1` で数える（`wasmtime-49.0.2/src/runtime/component/func/typed.rs` 1530 行・1777 行）。
- 戻り値の文字列と `Bytes` は、今と同じく 2^30 バイトを `check_size` で確かめてから値を作る。文字列は `alloc_str_utf8` を通し、`None` は `invalid()` とする（Wasmtime が持ち上げで UTF-8 を確かめるので、通常は起きない）。`Bytes` は `CheckedLen::bytes` と `alloc_bytes_with` で写す。
- 型付きの経路では、戻り値の予算と 2^30 の上限には実際には届かない。戻り値はゲストの線形メモリ（合計 64 MiB）の中の一つの範囲だからである。03-10 には「速い経路では `Bytes` を 1 バイトにつき 1 と数える」とだけ書き、届かないことは書かなくてよい。R0905 の注記は変えない（既存のゴールデン `aliased-result` の出力を変えない）。

### 既存のテストへの影響

- `src/external/runtime.rs` の `bytes_transfer_budget_and_empty_values` の最後の場合（`() -> Bytes` が 7 MiB を返し、`ExternalTransfer` を期待する）は、V4 の後は速い経路で成功する。この場合は、`Val` の経路の予算の検査として残すため、宣言の型を速い経路に当たらない形（`WitPlan::List(Box::new(WitPlan::U8))`、Benitoite の `List[Byte]`）に変えて同じ期待を保つ。同じテストの `Bytes -> Unit`（戻り値なし）は `Dynamic` のままなので変えない。
- ゴールデン `testdata/external/roundtrip` の `integer`・`float`・`string`・`bytes` と、`bad-utf8`・`bad-pointer`（`() -> String`）は、V4 の後は速い経路を通る。期待の出力が変わらないことを確かめる。`bad-utf8`・`bad-pointer` の文言は、`Val::String` も `String` の `Lift` の実装を使う（`values.rs` 257 行）ので同じになるはずである。変わったら作り直さず、原因を調べて報告する。

### テスト

- 置き場所は `src/external/runtime.rs` の単体テストとする。`wat::parse_str` で組み立てる今の形に倣う。ゴールデンは足さない（VM と参照インタプリタの両方が同じ `external::call` を通るので、経路の違いは単体テストで足りる）。
  - 同じ結果: `(s64, f64) -> f64`、`(string, s64) -> string`、`(list<u8>) -> list<u8>`、`() -> s64` などのいくつかの形を、`call_typed` と `call_dynamic` で呼び、同じ値になることを確かめる。NaN と空の文字列・空の `Bytes` を一つずつ含める。
  - 大きな `Bytes`: 10 MiB の `Bytes` の往復（ゲストは `realloc` で 1024 番地を返し、受け取った位置と長さをそのまま返す。初期メモリ 176 ページ）。`Dynamic` では 10 MiB × 40 = 400 MiB で予算を超える大きさである。テストの時間を測り、debug ビルドで 10 秒を超えたら 8 MiB に下げる（8 MiB でも `Dynamic` の上限の約 6.7 MB を超える）。
  - 予算: `Limits { transfer: 1024, .. }` で、2 KiB の `Bytes` の引数が `ExternalTransfer`、2 KiB を返す関数が `ExternalTransfer` になること。
  - 燃料: `(s64) -> s64` の無限ループを小さな燃料で呼び `ExternalFuel` になること。中断: `epoch_interrupts_running_wasm_and_watcher_joins` と同じ形で、速い経路の関数が `ExternalFailure::Interrupted` を返すこと。
  - 印: `ExternalRoute::of` の単体テストで、3 引数は `Typed`、4 引数・`Bool`・`List[Byte]`・戻り値なしは `Dynamic` になること。
- 仕様の節に当たるテストに `// spec: 03-10 実行` を付ける。

### 実行ファイルの大きさ

- 作業を始める前（ブランチを切った直後）と作業の後に、`cargo build --release -p benitoite --bin benitoite` を行い、`target/release/benitoite` の大きさと、`strip -o <scratch>/benitoite.stripped target/release/benitoite` で作った写しの大きさを、バイトで報告に書く。`Cargo.toml` の `[profile.release]` は strip を設定していない。release のビルドは数分かかる。

### 設計書

- 03-10「実行」の二つ目の【決定】: 「`Bytes` は各バイトを一つの `Val` として数える」の後に、速い経路の条件（引数 0〜3 個、引数と戻り値が `Integer`・`Float`・`String`・`Bytes`、戻り値あり）と、その経路では `Bytes` を 1 バイトにつき 1 と数えること、同じ大きさの `Bytes` でも関数の型で上限に達するかが変わることを書く。理由は 1〜3 文（Q7 の理由）。
- 02-09「外部の関数の実行」の予算の段落を同じ趣旨で直す。02-07 の外部の関数の表の記述に変換表の中身があれば、経路の印を加える。
- 言語リファレンスの 21 節の 1056 行「Transfer accounting includes the host representations of list elements, so large `Bytes` can exhaust the budget ...」を、速い経路の条件と数え方に合わせて直す。CHANGELOG の Unreleased に書く。

## V5 への補足

### 用語

- 設計書と言語リファレンスでは、WIT の `resource` に当たる Benitoite の型を「外部の型」（英語は external type）と呼び、01-10 の「リソースの型」と呼ばない。理由: 01-10 のリソースの型は `with` と解放の `State` を要する型であり、R5 の外部の型は回収で管理する中身を見せない値なので、同じ語を使うと章をまたいで意味がずれる。WIT の側の語として「resource」を併記するのはよい（例:「外部の型（WIT の resource に当たる型）」）。コードの識別子も `External` を使い、`Resource` を使わない（`BuiltinTypeClass::Resource`・`Value::Resource` と取り違えないため）。

### 構文と構文木

- `Item` に列挙子 `ExternalType(ExternalTypeDecl)` を足す。`ExternalTypeDecl { id: NodeId, span: Span, name: Name, type_params: Vec<TypeParamDecl> }`。`Item::id` にも足す。凍結の表の 10-03「右辺のない `type` の宣言を表す列挙子」に当たる。`AliasDecl.ty` を `Option` にする形は、既存の欄の意味を変えるので採らない。
- 構文解析: `src/syntax/parser/decls.rs` 92〜93 行の振り分けで、`TokenKind::KwType` の場合に、属性に `external` があり、`alias_ahead(p)` が偽で、名前と型パラメータの後が改行・`;`・ファイルの終わりなら、新しい `parse_external_type` を呼ぶ。`external` のない右辺のない `type` は今のとおり `parse_data(p, depth, true)`（E0233）に進む。`@external` を付けた `type 名前 = ...` は今のとおり別名として読み、属性の検査で E0802 になる。
- 属性の検査（`src/syntax/parser/items.rs` 185 行 `check_decl_header`）: `external` は `Item::Fn` と `Item::ExternalType` で受け付け、`test`・`builtin` は `ExternalType` でも E0802 にする。`ExternalType` の型パラメータは E0811 で報告する。E0811 の型板に引数 `what` を足し（既存は `function`）、外部の型では `type` と、外部の型に合った修正案（例: `an external type stands for one resource of the component and takes no type parameters`）を出す。
- `public` と `public(package)`（V1）は `TopDecl` の欄なので、そのまま付けられる。整形器（`src/cli/tools/formatter/`）は `@external(...)` の行と `type 名前` の行を出す。`src/cli/tools/package/effects.rs` の `match` には `Item::ExternalType(_) => {}` を足す（コンポーネントの一覧には、属性を見る今のループで入る）。`skill/generate.rs` など `Item` を網羅して照合する箇所は、コンパイラが示すとおりに足す（`wildcard_enum_match_arm` が deny なので漏れない）。

### 束縛と型の構成子

- `BindingKind` に `ExternalType` を足す（凍結の表の 10-04）。`collect_decl`（`src/resolve/collect.rs` 330 行付近）に `Item::ExternalType(d) => (&d.name, BindingKind::ExternalType, d.span)` を足す。`declaration_kind` の文言は型と同じ `type` とする。公開する契約の検査（`src/resolve/checks.rs` 22〜30 行の `matches!`）の型の種類に `ExternalType` を加える。理由: 非公開の外部の型を `public` の関数の型に使ったら、ほかの型と同じく E0329 にする。
- 外部の型の宣言の属性と照合の結果は、既存の `ResolveOutput.externals`（`BindingMap<ExternalDecl>`）に、型の束縛の番号を鍵として入れる。`ExternalDecl.decl` は型の宣言のノード番号とする。`ExternalDecl` は凍結していないので、照合の結果を入れる欄 `pub external_type: Option<Arc<ExternalTypeSpec>>`（照合の前と誤りのときは `None`）を足してよい。理由: `ResolveOutput` に欄を足すと凍結の表を超える（「オーケストレータへの報告」の 3）。`externals` を読むのは照合（`check.rs`）と脱糖（`ir/desugar/decls.rs` 49 行・204 行。どちらも関数の束縛で引く）だけなので、型の項目が混ざっても脱糖は変わらない。02-04 の表の説明は「外部の宣言（関数と型）」に直す。
- `TyCon` に `External(BindingId)` を足す（凍結の表の 10-05）。`src/typeck/decls.rs` 395〜401 行の `match binding.kind` に `BindingKind::ExternalType => (TyCon::External(id), 0)` を足す。`TyCon::Adt` に `ctors` の空の `AdtDef` で表す形は採らない。理由: (1) `src/typeck/solve.rs` 1150 行付近は、`adts.get(id)` が `None` のとき等値の制約を通してしまう、(2) 構成子のない型を網羅性の判定や V3 の `DeclPlan` が `data` として扱う、(3) 新しい列挙子なら、扱いを決めるべき箇所をすべてコンパイラが示す。
- 型の表示（`src/types/mod.rs` 462 行 `show_ty`）は外部の型の名前を要する。推す形（了承が要る。「オーケストレータへの報告」の 2）: 凍結の `TyNames` に欄 `pub bindings: &'a BindingMap<Binding>`（名前解決の束縛の表）を足し、`TyCon::External(id)` は `names.bindings.get(id)` の名前で示す。`TyNames { .. }` を作る 6 か所（`external/check.rs` 155 行、`ir/desugar/decls.rs` 390 行、`typeck/context.rs` 171 行、`typeck/generate.rs` 288 行、`typeck/traits/collect.rs` 349 行、`types/mod.rs` 623 行）に渡す。了承が得られないときの代わり: 型検査の宣言の収集で、外部の型ごとに `AdtDef { name, module, type_params: vec![], ctors: vec![], record: None, eq_summary: always, key_summary: always }` を `AdtTable` に名前の表としてだけ載せ、`show_ty` の `TyCon::External(id)` は `names.adts.get(id)` の名前で示す。この場合も型は `TyCon::External` で表し、`TyCon::Adt(id)` を外部の型に使わない。
- `TyCon::External` の各箇所の扱い（コンパイラが示す箇所のうち、判断の要るもの）:
  - 等値・鍵: `typeck/decls.rs` 1075 行 `summary` は `Fn` と同じく `out.always = !key`、`typeck/solve.rs` 1137 行付近は `valid = false`（`Bound::Set` でも偽）。今の `Regex.Pattern`（`BuiltinTypeClass::Opaque`）と同じく、`==`・`<>`・`Map` の鍵・`Set` の要素・`Assert.equal` が型の誤りになる。
  - `with`: `typeck/effects/special.rs` 55 行は `BuiltinTypeClass::Resource` だけを受け付けるので、外部の型を加えない（`with` に使えば型の誤り）。
  - 等値の命令の選択（`bytecode/codegen/emit.rs` 573 行）は `Opcode::EqV` の側に足す（型の誤りで届かない）。
  - テストの実行器の値の照合（`runtime/assert.rs` 887 行・1031 行）は、`BuiltinTypeClass::Opaque` と同じく中身を見ずに受け付ける。値の表示は今のとおり `UNKNOWN_VALUE` になる。
  - `ir/check.rs`（317 行など）は中身を見せない型と同じに扱う。
  - 実装（`implement Show[Cell]` など）は、利用者の `data` と同じ規則で許す。`Show` の実装がなければ、文字列への埋め込みは今の `Regex.Pattern` と同じく型の誤りになる。
  - 形式化の書き出し器（`tests/desugar_export/exchange.rs` 276 行・376 行）は「対象外」（`self.outside("external type")` など）とする。外部の関数を含むプログラムは書き出し器が丸ごと除く（07-04 の 150 行）ので、実際には届かない。`formal/` は変えない。

### エフェクトの検査（E0812 の場所と改め方）

- 今の E0812 は構文解析（`src/syntax/parser/items.rs` 223〜240 行）にあるが、構文解析では引数の型が外部の型かを決められない（`import` した型や別名を通す場合がある）。次のように分ける。
  - 構文解析: `uses` が「名前一つで、その綴りが `State`」でなければ、今のとおり E0812 と `uses` を消す修正案を出す。`uses State` だけは通す。E0812 の文言は「an external function can declare only `uses State`, and only when its type contains an external type」の趣旨に改め、注記 `pure` も同じ趣旨に直す。E0812 を確かめているのは `items.rs` 1262 行の単体テストだけなので、ゴールデンへの影響はない。
  - 照合（`src/external/check.rs` の宣言ごとの処理。コンポーネントを読む前の、`declaration_plan` と同じ段）: 宣言の型（`Scheme.params`・`ret`。別名は展開済み）に `TyCon::External` が現れるかを調べる。(a) 現れて `Scheme.effects` が組み込みの `State` ただ一つでない（`uses` がない場合を含む）→ `uses` がなければ新しい **E0816**（「the external function `{name}` passes an external type, so it must declare `uses State`」の趣旨、修正案は戻り値の型の後に ` uses State` を挿入する編集）、ほかのエフェクトなら E0812。(b) 現れず `uses` がある → E0812（`uses` を消す修正案）。`uses` の位置は `check.rs` 165 行付近で見つける `FnDecl` の `uses` から取る。
  - `State` かどうかは綴りでなく、`Scheme.effects.names` が組み込みの `State`（`BuiltinEffectId`）ただ一つで `vars` が空であることで判定する。
- 脱糖（`src/ir/desugar/decls.rs` 213 行と 221 行の `EffectSet::empty()` の二か所）を `scheme.effects.clone()` に変える。外部の型を含まない関数では E0812 により空なので、今と同じになる。

### 照合

- `check_all` の宣言の並びを二回に分けて処理する。一回目で外部の型の宣言を照合し、二回目で関数を照合する。理由: `BindingMap` の順は束縛の番号の順で、関数が型より先に来ることがある。
- 外部の型の宣言の照合: 第 3 引数を V2 と同じく最後の `#` で区切り、コンポーネントの型の書き出しから `ComponentItem::Resource(ty)` を引く（`#` がなければ world の直下を引く。world の直下の resource を書けるかは確かめていないが、規則を分けない）。見つからない・resource でなければ新しい **E1012**（「the component `{path}` has no resource `{name}`」の趣旨。注記に書き出した resource の一覧を `名前#resource` の形で示す）とする。通れば、照合の中だけで使う表 `BTreeMap<BindingId, (コンポーネントのキャッシュの鍵, wasmtime::component::ResourceType)>` に入れ、`ExternalDecl.external_type` に `ExternalTypeSpec { id: u32, component: Arc<ComponentSource>, instance: Option<String>, name: String }` を入れる。`ResourceType` は検査の中だけで使い、`ExternalSpec`・`ExternalTypeSpec`・`ExternalTable` に入れない（02-08「外部の関数の実行系」と `ExternalTable` は Wasmtime の型を含めない約束）。
- `DeclPlan`（V3）に `External(BindingId)` を足し、`Ty::Con(TyCon::External(id), [])` から作る。`List`・`Option`・`Result`・`Pair`・`Triple`・レコードの欄の中に現れてもよい。
- `bind` に引数の位置か戻り値の位置かの印を渡す。`DeclPlan::External(id)` は、引数の位置では `Type::Borrow(ty)`、戻り値の位置では `Type::Own(ty)` だけに合わせ、`ty` が一回目の表の `ResourceType` と等しく、関数と型のコンポーネントのキャッシュの鍵が同じであることを求める。結果は `WitPlan::Borrow(u32)`・`WitPlan::Own(u32)`（数は外部の型の束縛の番号）とする。
- 誤りは E1008・E1009 と V3 の注記 `reason` で報告する。`reason` の例: 「`` the component takes ownership of `other` (`own<cell>`); external functions can only lend external types (`borrow<cell>`) ``」「`` `Cell` is the resource `bnt:test/counter@0.1.0#cell` of `a.wasm`, but this parameter is `borrow<cell>` of `bnt:test/second@0.1.0` ``」。WIT は戻り値に `borrow` を書けないので、戻り値の `borrow` の場合は作らなくてよい。
- 外部の型の宣言が誤り（E1012 など）だった場合、その型を使う関数は診断を出さずに照合を飛ばす（誤りの連鎖を避ける）。
- `ResourceType` の同一性は、Wasmtime が検査の型を `ResourceType::uninstantiated(&types, index)` か `abstract_` で作り、どちらも `ComponentTypes` の番地と番号で比べる（`wasmtime-49.0.2/src/runtime/component/resources/ty.rs` 82〜98 行、`types.rs` 943〜944 行・1260〜1276 行）。書き出しの `ComponentItem::Resource` と関数の引数の `Type::Borrow` が同じ値になることは、ソースからの推測で、試していない。最初に、下記の試験用のコンポーネントで「同じ resource は等しい、`second` の `cell` とは等しくない」ことを `src/external/tests.rs` の単体テストで確かめてから先に進む。等しくならなければ、作業を止めて報告する。
- E1006 の書き出しの一覧（V2）には resource のメソッドも関数として含まれる。V2 のとおりでよい。

### 実行（状態を持つインスタンス）

- `ExternalRoute` に `Stateful` を足し、`ExternalRoute::of` は、引数か戻り値の `WitPlan` に `Own`・`Borrow` が一つでもあれば `Stateful` を返す（`Typed` より先に判定する。V4 の四つの型は外部の型を含まないので重ならない）。`WitPlan` の木を辿るときは明示の積み重ねで書く。
- `ExternalRuntime` に `stateful: Vec<Option<Stateful>>`（`components` と同じ添字）を足す。`Stateful { store: Store<CallLimits>, instance: Instance, handles: Vec<Option<ResourceAny>>, free: Vec<u32>, queue: Rc<RefCell<Vec<u32>>> }`。初めて `Stateful` の関数を呼ぶときに、燃料・epoch・受け渡しの予算を設定してからインスタンスを作る（インスタンスの作成も最初の呼び出しの燃料で数える）。
- 呼び出しごとに: (1) `store.set_fuel`・`set_hostcall_fuel`・`set_epoch_deadline(1)` を設定し直す（調査 B 2.3。epoch の期限は設定した時点からの相対なので毎回要る）。(2) 解放待ちの列を空にし、番号ごとに `handles` から `ResourceAny` を取り出して `resource_drop(&mut store)` を呼び、番号を `free` に戻す。`resource_drop` の誤りは、今の呼び出しの誤りとして `failure()` で分類する。(3) V2 の二段の引き方で関数を引き、`Val` の経路で呼ぶ。
- `CallLimits.memory` は `Store` の寿命の合計を数える（R5）。上限を超えたら今と同じ R0905 になる。`OBJECTS = 16` はコアのインスタンスの数で、wit-component が作るコンポーネントは一つで 3 個を数える（調査 B 2.4）。一つの `Store` に一つのインスタンスなので足りる。
- 呼び出しが誤りを返したら、その `Stateful` を `None` に置き換える。理由: 誤りの後は Wasmtime が `Store` に印を立て、二度と入れない（調査 B 2.2）。今は外部の関数の誤りで実行全体が止まるので、置き換えた後に呼ばれることはない。
- 外部の型を含まない関数は、今のとおり呼び出しごとにインスタンスを作る（R5）。このため、外部の型を型に含まない `[static]` の関数（例: `[static]cell.live() -> s64`）は、状態を持つインスタンスの状態を見られない。この点を 03-10 に書く。

### 中身を見せない値と解放待ちの列

- 外部の型の値は、`ctx.alloc_opaque(ExternalHandle { component, resource, slot, queue })` で作る（AGENTS.md「言語の値を作る経路」）。`component` は `ExternalTable.components` の添字、`resource` は `WitPlan::Own` の数、`slot` は `handles` の番号、`queue` は `Stateful.queue` の `Rc` の写しである。`OpaqueData` の約束（作った後に変えない、言語の値を含めない）を守る。`Rc` の指す列は対象の外の共有の領域であり、対象自身の欄は変えない。
- `impl Drop for ExternalHandle` は、`queue.try_borrow_mut()` が成功したときだけ `slot` を積み、失敗したら何もしない（panic しない）。コメントに、解放そのものは行わず番号を積むだけであること、解放は次にその状態を持つインスタンスへ入るときに行うこと（設計書 03-10）を書く。`HostData` の説明が禁じる「`Drop` の中の言語の後始末」には当たらない（ヒープのテストの `Opaque(Rc<Cell<u32>>)` が `Drop` で数を変えるのと同じ種類の操作である。`runtime/heap/core/mark_sweep.rs` 277 行）。
- AGENTS.md との整合: 列は実行ごとの `ExternalRuntime` とその実行のヒープの対象だけが共有し、大域の状態ではない（「大域の状態」）。列は番号（`u32`）だけを持ち、`Value<'epoch>` を区間の外に置かない（「回収しない区間と値の扱い」）。`ExternalRuntime` が先に捨てられても、`Rc` が列を生かすので、後から捨てられる対象が積むのは害がない。参照インタプリタの `BuiltinBridge.resources: Rc<RefCell<..>>`（`refinterp/convert.rs` 41 行）が同じ形の前例である。
- 変換: `to_wasm` と `from_wasm` に、外部の型を扱うための引数（例: `Option<&mut ExternalHandles<'_>>`。`Dynamic` の経路では `None`）を足す。
  - `to_wasm` の `WitPlan::Borrow(r)`: `ctx.opaque::<ExternalHandle>(v)` で読み、`component` が呼ぶ関数の `ExternalRef.component` と等しい、`resource == r`、`Rc::ptr_eq(&handle.queue, &stateful.queue)` を確かめ、`handles[slot]` の `ResourceAny` を `Val::Resource` にして渡す（所有している handle を `borrow` の位置に渡してよいことは調査 B の試作で確かめた）。どれかが合わなければ `Stop::Internal`。
  - `from_wasm` の `(WitPlan::Own(r), Val::Resource(any))`: `any.owned()` を確かめ、`handles` に入れて（`free` を先に使う）、`ExternalHandle` を作る。
  - `check_arguments` は、外部の型の値を数として 0 と数える（ほかのスカラーと同じ）。
- 回収の契機: ゲストの線形メモリはヒープの大きさに現れないので、外部の型の値を作り捨てるループでは、回収が起きないままゲストのメモリが 64 MiB に達しうる（R5 の目的が果たせない）。そこで `ExternalHandle::heap_bytes` は、その値を返した呼び出しの間に `Store` の線形メモリが増えた量（`CallLimits.memory` の呼び出しの前と後の差。一つの呼び出しで複数の値を返したら最初の値に全部を割り当て、ほかは 0）を返す。理由: 解放した領域をゲストが使い回す間は 0 になり、メモリを増やして値を作るときだけ回収を早める（`heap_bytes` は確保のときに一度だけ読まれる。`runtime/heap/core.rs` 516〜520 行）。この扱いは「オーケストレータへの報告」の 4 で設計者に確かめる。了承が得られなければ `heap_bytes` は 0 のままにし、下記のループのテストを、ループの中で回収を促す確保を含む形にする。

### 参照インタプリタ

- `src/refinterp/eval.rs` 445 行の `ValKind::External { spec, .. }` の分岐で、`spec.route` が `Stateful` なら `self.bridge.external` を呼ばず、`Ok(State::End(RefOutcome::Unsupported(spec.function.clone())))` を返す（811 行に同じ形の前例がある）。差分テストは `Comparison::Excluded` にする（`tests/golden/differential.rs` 169 行）。`Stop::Internal` を返すと差分テストが失敗扱いにするので、使わない。

### テスト

- 試験用のコンポーネントは `.wat` で書ける。WIT とコアのモジュールのテキストから wasm-tools で作り、`wasm-tools print` の出力を `.wat` として置く。オーケストレータの作業場所 `/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/pkg2/v5wat/` に、`r.wit`（WIT）、`core.wat`（コアのモジュール）、`comp.wat`（できたコンポーネントの印刷。約 13 KB）を置いた。作り方は次のとおりで、`validate` を通り、取り込みは 0 個だった。

  ```sh
  wasm-tools parse core.wat -o core0.wasm
  wasm-tools component embed r.wit core0.wasm -o core.wasm
  wasm-tools component new core.wasm -o comp.wasm
  wasm-tools print comp.wasm > comp.wat
  ```

  WIT の中身: インターフェース `bnt:test/counter@0.1.0` の `resource cell`（`constructor(start: s64)`、`make: static func(start: s64) -> option<cell>`、`get`、`bump(by: s64) -> s64`、`pair(other: borrow<cell>) -> s64`、`take(other: cell) -> s64`、`live() -> s64`）と関数 `other(x: s64) -> s64`、別のインターフェース `bnt:test/second@0.1.0` の `resource cell`（`constructor()`）。コアのモジュールは、resource ごとに線形メモリを 1 ページ（64 KiB）増やすか、解放したページを使い回す（`dtor` が空きの列に戻す）。生きている数を `live` が返す。したがって、解放しなければ約 1,000 個で 64 MiB に達する。
  - `comp.wat` を `testdata/external/resource/x.wat` に写し、`BENITOITE_BLESS=1 cargo test -p benitoite --test golden testdata_components_match_their_text` で `.wasm` を作る（`wasm-tools parse comp.wat` の結果は印刷の前の `comp.wasm` と一致しないが、検証は通る。置く `.wasm` は `.wat` から作ったものにする）。`r.wit` と `core.wat` も同じディレクトリの `src/` に置き、`testdata/external/README.md` に作り方の四行を書く。
- 置き場所と場合:
  - 構文解析の単体テスト: `@external(...) type Cell` を読める、`@external(...) type Cell[T]` が E0811、`@external` のない `type Cell` は今のとおり E0233、`@test type Cell` が E0802、`uses Console.Write` の外部の関数が構文解析の段で E0812。
  - 照合の単体テスト（`src/external/tests.rs` の表の形）: 同じ resource の同一性（上記の確かめ）、resource でない名前と存在しない名前が E1012、`take` を `function take(self: Cell, other: Cell) -> Integer uses State` で宣言すると E1008（`own`）、`second#cell` と宣言した型を `counter` のメソッドに渡すと E1008（違う resource）、`uses` がないと E0816、`uses State, Console.Write` が E0812、外部の型を含まない `other` に `uses State` が E0812、`make` を `-> Option[Cell] uses State` で照合できる。
  - 実行の単体テスト（`src/external/runtime.rs`）: 状態が残る（`bump` を 2 回呼ぶと足し合わさる）、`pair` に二つの値を渡せる、解放待ちの列（二つ作り、一つを根から外して `heap.collect` した後に `live` を呼ぶと 1 になる。列が回収の後の次の呼び出しで片付けられることを、回収の時期を制御して確かめる）、別の実行系の値や違う `resource` の値を渡すと `Stop::Internal`。
  - ゴールデン（`testdata/external/resource/`、`run`）: `constructor`・`make`・`bump`・`pair` を呼び、回収の時期に依らない値だけを出力する（`live` を出力しない）。同じ実行の中で、1,500 個の値を作って捨てるループが R0905 にならずに終わることを確かめる。参照インタプリタは `Unsupported` で比較から外れる。
  - gc-stress: `BENITOITE_GOLDEN_FILTER=external/resource cargo test -p benitoite --no-default-features --features gc-mark-sweep,gc-stress --test golden` と、実行の単体テストを gc-stress の構成でも走らせ、結果が同じであることを確かめる。ループの回数で 10 秒を超えたら、1,100 個まで下げる（解放しなければ 64 MiB を超える数を保つ）。
  - 文言の形は、`check` のゴールデンを一つ（E0816 か E1012）で確かめる。
- 仕様の節に当たるテストに `// spec: 03-10 <見出し>`・`// spec: 01-07 外部の関数のエフェクト` を付ける。

### 設計書

- plan.md の一覧（03-10、01-07「外部の関数のエフェクト」、02-08・02-09、07-01、01-02、言語リファレンスの 21 節）に加えて、次を直す。
  - 02-04「束縛と表」の束縛の種類の表（外部の型）と、外部の宣言の表の説明（関数と型）。
  - 02-05 138 行「名前の型」の型構成子の一覧（外部の型。等値の型ではない）。
  - 02-10 の表の E08・E10 の行（E0816・E1012）。
  - 言語リファレンスの 254 行「equality types」の中身を見せない型の例に external types を加える。21 節の 1054 行「Records, user-defined data types, ... resources ... cannot cross」と 1056 行「fresh component instances on every call」を改める。外部の型の例は、今の 21 節と同じく `text` の例にする（WASM のバイナリを `files` ブロックで置けないため。138 行のコメントの前例）。
  - 03-10 に、状態を持つインスタンスの上限の意味（線形メモリの 64 MiB は寿命の合計）、解放の時期は回収の時期に依存すること、外部の型を型に含まない関数は状態を見ないこと、外部の型は 01-10 のリソースの型ではないこと、`own` の引数を受け付けないことを書く。

## 作業の間の依存

- V4 は V2（二段の引き方）と V3（`bind` の後の `WitPlan`）の後に行う。`ExternalRoute::of` は V3 の後の `WitPlan` から決める。
- V5 は V4 の `ExternalRoute` と、実行の手順の共通化（`Store` の設定・関数の引き方・`failure()` の共有）を前提にする。V4 を取り込んだ後に始める。
- V4 と V5 が同じファイルに触れる箇所: `src/external/mod.rs`（`ExternalSpec`・`ExternalRoute`・`WitPlan`）、`src/external/runtime.rs`、`src/external/convert.rs`、`src/external/check.rs`、03-10「実行」、02-09「外部の関数の実行」、言語リファレンスの 21 節、CHANGELOG。直列に取り込めば衝突しない。
- V5 の `Item`・`BindingKind`・`TyCon` の列挙子の追加は、構文・名前解決・型検査・脱糖・形式化の書き出し器・整形器の網羅の照合に広く及ぶ。V1（`public(package)`）の `TopDecl.package` は、外部の型の宣言にもそのまま効く。
- V6 の `Regex` の resource の形と `Json` の越え方 3 は、V5 の外部の型を使う。V6 のゲストの WIT は、resource をインターフェースの中に置き（調査 B 1.5）、関数の名前を `インターフェース#[method]pattern.is-match` の形で書く。失敗しうる作成は `[static]` の関数で書く（`[constructor]` の `result` を返す形は確かめていない）。

## オーケストレータへの報告

1. plan.md の凍結の表の「作業」の欄が、resource に関わる行（10-03 の右辺のない `type`、10-04 の resource の型の束縛、10-05 の `TyCon`）を V4 としているが、resource は V5 である。V4 の列を V5 に直すべきである。
2. 凍結の表で足りないもの（設計者の了承が要る）: 型の表示に使う `TyNames`（10-05）は、利用者の型の名前を `AdtTable` からだけ引くので、`TyCon::External` の名前を示せない。推す形は `TyNames` に `bindings: &BindingMap<Binding>` を足すこと（作る箇所は 6 か所）。了承が得られなければ、外部の型の名前だけを `AdtTable` に構成子のない `AdtDef` として載せる代わりの形で進める（凍結の表の「既存の利用者の型の表で表す」の範囲だが、`AdtTable` に代数的データ型でない項目が混ざる）。
3. 外部の型の宣言の属性と照合の結果を、`ResolveOutput` に新しい欄を足さず、既存の `externals` の表に型の束縛の番号を鍵として入れるよう指示した（`ResolveOutput` の欄の追加は凍結の表にない）。設計者が別の欄を好むなら、了承が要る。
4. 回収の契機: R5 は「列に入れて片付ければ、使い捨ての resource を多く作るプログラムが上限に当たりにくい」としたが、ゲストの線形メモリはヒープの大きさに現れないので、確保の少ないループでは回収が起きず、64 MiB に達しうる。補足では、外部の型の値の `heap_bytes` に、その値を作った呼び出しの間に増えたゲストの線形メモリの量を返させ、回収を早める形を指示した。`OpaqueData::heap_bytes` の説明（この対象だけが所有する別の領域）を広げる読み方で、`peak_heap_bytes` などの統計にゲストのメモリの一部が入る。この扱いでよいかを設計者に確かめたい。
5. 用語: plan.md・decisions.md の「resource の型」は、01-10 の「リソースの型」（`with` と解放の `State` を要する型）と紛らわしい。補足では、設計書とリファレンスで「外部の型」（external type）と呼ぶよう指示した。00-04 用語集に加える候補である（V7）。設計者に語を確かめたい。
6. R5 の「型に resource を含む関数だけを状態を持つインスタンスで呼ぶ」の帰結として、外部の型を型に含まない `[static]` の関数（生きている数を返す関数など）は、状態を持つインスタンスの状態を見られない。決定どおりだが利用者に分かりにくいので、03-10 に書くよう指示した。
7. E0812 は構文解析の段にあるが、引数の型が外部の型かは名前解決と型検査の後でないと分からない（`import` した型、別名）。補足では、構文解析には「`State` 以外の `uses`」の検査だけを残し、外部の型の有無で決まる検査を照合の段に移した。外部の型を含むのに `uses` がない場合は新しい E0816、resource が見つからない場合は新しい E1012 とした。
8. 確かめていないこと: 検査の型で、書き出しの `ComponentItem::Resource` と関数の引数の `Type::Borrow` の `ResourceType` が等しくなること（ソースからの推測）。補足では、V5 の最初にこれを単体テストで確かめ、成り立たなければ止めるよう指示した。試験用のコンポーネント（`scratchpad/pkg2/v5wat/`）は wasm-tools の `validate` だけを通し、Wasmtime では動かしていない。
9. V4 の後、既存の単体テスト `bytes_transfer_budget_and_empty_values` の最後の場合（`() -> Bytes` の 7 MiB で予算の超過を期待）は、速い経路で成功するようになる。補足では、宣言の型を `List[Byte]` に変えて `Val` の経路の予算の検査として残すよう指示した。plan.md の誤りではない。
10. plan.md の V5 の設計書の一覧に、02-04 の束縛の種類の表、02-05 の型構成子の一覧、02-10 の E08・E10 の行、言語リファレンスの 254 行（等値の型）が抜けている。補足で加えた。
11. V4 の実行ファイルの大きさの測定は、release のビルドを作業の前と後に 2 回行う（それぞれ数分）。

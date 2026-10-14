# V1〜V3 の事前点検の補足

- 点検はコミット `6c6a897d`（san_benito）の処理系と、`wasmtime-49.0.2`・`wasmparser-0.258.3` のソースを読んで行った。行番号はこのコミットのものである。`.wat` の書き方は、手元の wasm-tools 1.261.0（Benitoite の dev-dependency の `wat = "=1.261.0"` と同じ版）の `validate` で確かめた。
- 新しい診断コードは「区分の空いた番号」ではなく、**区分の続きの番号**に割り当てる。02-10「診断コード」は「新しい検査は各区分の続きの番号に割り当てる。廃止したコードの番号は使い回さない」と定めている。`E0307`・`E0308`・`E0317` などの欠番は廃止したコードであり、使ってはならない（`src/diag/codes.rs` 26 行の一覧）。今の最後の番号は E02 が `E0252`、E03 が `E0339`、E08 が `E0814`、E10 が `E1011` である。この補足では、V1 が `E0253`、V2 が `E0815` を使う。V3 は新しいコードを足さない。
- 既存の診断の文言を変えるときは、型板に引数を足して、既存の場合の出力が一字一句変わらない値を渡す形を優先する。既存のゴールデンの差分を、意図した変更だけにするためである。
- 凍結の表の範囲で足りる。V1 は `TopDecl` と `Binding` に欄を一つずつ足すだけで済み、`ResolveOutput`・`BindingKind` には触れない。V2・V3 が触れる `ExternalSpec`・`WitPlan`・`ExternalDecl` は凍結した型ではない。
- `ExternalSpec` に欄を足すと、テストの中で `ExternalSpec { .. }` を作る箇所もコンパイルが通らなくなる。`src/bytecode/liveness.rs` 655 行付近、`src/bytecode/verify.rs` 672 行付近、`src/external/convert.rs` のテストの `spec()`、`src/external/runtime.rs` のテストを直す。`ExternalSpec` の `Debug` は手で書いた実装（`src/external/mod.rs` 86〜97 行）なので、足した欄をそこにも加える。

## V1 への補足

- 構文木: `TopDecl` に `pub package: Option<Span>` を足す。`public(package)` と書いたときの `(` から `)` までの位置を持ち、`public` だけのときは `None` にする。`public: Option<Span>` は今のとおり `public` の字句の位置を持つ（`public(package)` でも `Some`）。理由: `public` の欄の意味（`public` の字句の位置）を変えずに済む。また、E0329 の修正案で `(package)` を消す編集の位置として、この欄の位置をそのまま使える。
- `top.public` を読んでいる次の 5 か所を、すべて見直す。`public(package)` を `public` と取り違えるのを防ぐためである。
  - `src/resolve/collect.rs` 320 行（`collect_decl`）。`Binding.public` には `top.public.is_some() && top.package.is_none()` を入れる。
  - `src/resolve/walk.rs` 118 行（`save_contract`）。`public` の宣言と `public(package)` の宣言の両方で、契約を集める。
  - `src/cli/tools/package/effects.rs` 40 行。`decl.public.is_none() || decl.package.is_some()` の宣言を飛ばす（R1）。
  - `src/cli/tools/skill/generate.rs` 259 行と 274 行。`public` だけの宣言を載せる。
  - `src/cli/tools/formatter/roles/walk.rs` 345 行。整形については後述する。
- 束縛: `Binding` に `pub package: bool` を足す。`public(package)` の束縛では `true`、それ以外では `false` とし、`public(package)` の束縛の `public` は `false` にする。`node_binding`（`collect.rs` 106 行）に引数を足し、構成子・欄・メソッド・操作の束縛（`collect.rs` 425〜488 行）に、包む宣言の値を渡す。理由: `Binding.public` を読む既存の箇所は、`ResolveOutput.exports`（`collect.rs` 175 行）、脱糖の名前と出どころ（`src/ir/desugar/decls.rs` 231・316 行。標準ライブラリだけを区別する）、標準ライブラリの型のモジュールの子（`lookup.rs` 240 行）である。`public(package)` の束縛を「`public` でない」と扱えば、これらはどれも正しく動く。
- 段階の大小は、`resolve` の中の非公開の補助（例: `enum Level { Private, Package, Public }` と `fn level(&Binding) -> Level`）で表す。
- 字句と構文:
  - `parse_public`（`src/syntax/parser/items.rs` 293 行）を改め、`public` の直後の字句が `(` なら括弧の中を読む。返り値の形は自由に変えてよい（凍結していない。`src/syntax/parser/mod.rs` 17 行の表も直す）。`public` と `(` の間に改行があるときは、`(` を読まない（`Newline` は字句なので、`p.at(TokenKind::LParen)` が偽になる）。
  - `public (package)` のように空白を挟んだ形は受け付ける。整形器が `public(package)` に直す。
  - 括弧の中が識別子 `package` でなければ、新しいコード **E0253**（区分 E02 構文）を出す。対象は、`public(crate)`、`public(internal)`、`public()` などである。文言は例えば「`public(...)` accepts only `package`」とする。修正案は、括弧の中の語を `package` に置き換える編集とする（`public()` なら、`()` の中に `package` を入れる）。`)` がないときは、既存の一般の誤り（期待した字句の誤り）で足りる。`package` は予約しない語なので、識別子の字句として来る。
  - `public(package) implement` と、`implement` の中の関数の `public(package)`（`src/syntax/parser/traits.rs` 181 行）は、`public` と同じく誤りにする。削除の修正案の範囲には `(package)` を含める（`reject_public` の `removal`）。
  - 入口のモジュールに書いた `public(package)` は、誤りにしない（R1、調査 C 1.3）。標準ライブラリのソースでは、この作業では `public(package)` を使わない。
- 同じパッケージかの判定は、`resolve` の中の非公開の関数 `same_package(a: ModuleId, b: ModuleId)` で行う。
  - どちらも `ModuleKind::Package` で、`ModuleInfo.name.0` の先頭の段（依存の別名）が同じなら真とする。
  - どちらも `Entry` か `User` なら真とする。
  - どちらも `Prelude` か `Stdlib` なら真とする。
  - それ以外は偽とする。`Config`・`PackageConfig` は宣言を持たないので、偽でよい。
  - 理由: 依存のモジュールの名前は、別名を先頭に付けた形である（`src/modules/find.rs` 341〜357 行）。依存の依存は許さない（01-03「依存のパッケージの取り込み」）ので、パッケージをまたぐ参照は、根から依存への参照と、依存から標準ライブラリへの参照だけである。
- 名前の引き方: `Resolver` に非公開の表 `package_exports: BTreeMap<ModuleId, BTreeMap<String, BindingId>>` を足す。`collect.rs` 175 行で `exports` に載せる箇所の隣で、`package` の束縛をこの表に載せる。`lookup.rs` 207 行の `children` では、ほかのモジュールを引くとき、`!public_only && same_package(ctx.module, module)` なら `exports` と `package_exports` を合わせた表を返し、そうでなければ今のとおり `exports` を返す。`ResolveOutput.exports` の意味（`public` だけ）は変えない。
- 公開する契約の検査（`src/resolve/checks.rs` 13〜62 行）: 今の判定「`exposed.public` か、別のモジュールなら通す」を、次の判定に置き換える。対象は、今と同じく型・型クラス・エフェクトの種類の束縛に限る。
  - `level(exposed) >= level(owner)` なら通す。
  - 別のモジュールの束縛で、`level(exposed) != Package` なら通す（別のモジュールの非公開の名前は、ここに来る前に名前解決の誤りになる）。
  - それ以外は E0329 を出す。
  - 理由: R1 は「宣言の型に現れる名前は、その宣言の段階以上」と定めている。同じパッケージの別のモジュールの `public(package)` の型を、`public` の関数が使う場合も誤りにしないと、使う側が名前で書けない型が外に漏れる。今の 01-03 は「同じモジュールの型」に限って書いているので、文言も直す（後述）。
- E0329 の文言（`src/diag/codes.rs` 496〜501 行）: 型板に引数を足し、既存の場合の出力を変えない。
  - 文言: `"the {level} {what} \`{name}\` uses the {used_level} {used_kind} \`{used}\`"`。`level` は `public` か `` `public(package)` ``、`used_level` は `non-public` か `` `public(package)` `` とする。
  - ラベル「`` `{used}` is not public ``」は変えない（`public(package)` も `public` ではないので、どの場合も正しい）。
  - 修正案: `make_public` を `` "mark `{used}` as `{target}`" `` に改める。`target` は `public` か `public(package)` とする。
  - 編集は三通りある。
    - 宣言が `public` で、使った型が非公開のとき: 今のとおり `insertion` の位置に `public ` を入れる。
    - 宣言が `public(package)` で、使った型が非公開のとき: `public(package) ` を入れる。
    - 宣言が `public` で、使った型が `public(package)` のとき: その宣言の `TopDecl.package` の位置を空の文字列に置き換える。束縛から `(package)` の位置を引くため、`insertion` と同じ形の非公開の表を `Resolver` に足す。
  - 説明の文は「Everything a declaration exposes ... must be at least as visible as the declaration」の趣旨に改める。
- E0330（`lookup.rs` 431〜480 行）: 依存の `public(package)` の名前を、別のパッケージ（根）から引いたときは、注記 `package` の代わりに新しい注記 `package_only` を付ける。文言は例えば「`` `{name}` is marked `public(package)`, so only modules of the same package can use it ``」とする。修正案は出さない。理由: この場合の宣言は必ず依存の側にあり、今も依存を編集する修正案は出していない（`user_module` が偽）。根の中の非公開の名前を引いたときの修正案（`public ` を入れる）は、今のとおりとする。
- 整形器（`formatter/roles/walk.rs` 345 行）: `decl.package` があれば、その `(` の字句の添字を `self.open_bracket(index, true)` で開く（`tight` が真の括弧として印を付ける）。理由: 今の `space_before`（同 1116 行）は、キーワードの後の `(` の前に空白を置くので、何もしなければ `public (package)` と出力してしまう。06-03「字句の間の空白」の表の最後の行（引数の並びなどを開く `(`）に、`` `public(package)` `` の `(` を加える。
- `benitoite package` のエフェクトの集計は、上記の `effects.rs` 40 行の変更で足りる。テストは `src/cli/tools/package/tests.rs` 148 行の `public_contracts_include_nested_function_types_and_trait_methods` の形に倣い、`uses Process.Run` を持つ `public(package)` の関数が集計に現れないことを確かめる単体テストを一つ足す。
- 設計書:
  - 01-02: `[ "public" ]` が、349・417・504・607・659〜663・698・721・788〜795 行に繰り返し現れる。EBNF に `Visibility = "public" [ "(" "package" ")" ] .` を足し、`[ "public" ]` をすべて `[ Visibility ]` に置き換える。674 行の属性の表の「`public` と `@deprecated` を併用でき」にも `public(package)` を加える。
  - 01-03「公開（初回リリース版）」（221〜246 行）: 234〜242 行の規則を、段階の大小の規則に書き直す。今は「`public` を付けていない同じモジュールの型」と書いている。書き直した後は、同じパッケージの別のモジュールの `public(package)` の型を `public` の宣言が使う場合も、誤りに含める。
  - 02-03「文脈の制限」の表（`public` の行）、02-04「束縛と表」「宣言の検査」「名前の引き方」「誤りと修正案」、06-03「字句の間の空白」、06-09「`benitoite package`」を直す。01-01 は変えない（`package` は予約しない語のまま）。
  - E0253 を足したら、02-10 の表の E02 の行の例にも加える。E02 の行は「属性の書き方の誤り」などを挙げているので、`public(...)` の括弧の中の誤りを加える。
- テスト（ゴールデン）は `testdata/packages/` の形に倣う。ディレクトリ `名前/` に `main.bnt` を置き、依存は `名前/deps/<パッケージ>/package.bnt`（`language "0.0.3"` と `package 名前 ... end package`）とモジュールに置く。`名前.mode`・`名前.exit`・`名前.stdout` か `名前.diag.json` を添える（例: `package-private-name`）。依存の中のモジュールどうしは、パッケージの根からのパスで取り込む（例: `local-textkit/deps/textkit/Slug.bnt` の `import Internal.Words`）。根の `main.bnt` は、`dependency 別名 path "deps/…" end dependency` の後に `import 別名.モジュール` と書く。三つの場合を確かめる。
  - 依存の中の別のモジュールの `public(package)` の関数を、依存の `public` の関数が呼び、根がその `public` の関数を呼べる（`run`）。
  - 根が依存の `public(package)` の名前を引くと E0330 と注記 `package_only` になる（`check`）。
  - 根の中の二つのモジュールの間で `public(package)` の名前を引ける（`run`）。
  - 名前の例: `package-visibility-run`、`package-visibility-hidden`、`package-visibility-root`。
- 契約の三段階、E0253、`implement` の前の誤りは、`testdata/modules/c11-public-contract.bnt` と同じ形の単一ファイルのゴールデンか、構文解析器の単体テストで確かめる。整形の往復は `testdata/fmt/` の形で、`public (package)` が `public(package)` になることを確かめる。

## V2 への補足

- 区切り: 第 3 引数の値に `#` があれば、最後の `#` で区切る。前半か後半が空なら、構文解析の段で新しいコード **E0815**（区分 E08 属性。`@external` の引数の誤り）を出す。場所は `src/syntax/parser/items.rs` 524 行の `attribute_args_error` の `"external"` の分岐の隣で、位置は第 3 引数の文字列とする。後半の文字の種類は検査しない。V5 で `[method]pattern.is-match` などを書くためである。`#` のない名前は、今のとおり world の直下を引く。
- 照合の引き方（`src/external/check.rs` 276〜294 行）:
  - 今の `component.component_type().get_export(&engine, name)` は、型の側の `types::Component::get_export` である。これは `IndexMap::get` による完全一致で、semver の互換を探さない（`wasmtime-49.0.2/src/runtime/component/types.rs` 1104〜1109 行。`exports` の表は `wasmtime-environ` の `IndexMap<String, ComponentExtern>`）。したがって、`get_export(&engine, 前半)` が `ComponentItem::ComponentInstance(inst)` を返せば、その `inst.get_export(&engine, 後半)`（同 1143 行。これも完全一致）で関数を引けば、R2 の「版を含めて完全一致」を満たす。書き出しの列挙は、E1006 の一覧を作るときだけに使えばよい。
  - semver の互換で引くのは、実行時の `wasmtime::component::Component::get_export_index` と `Instance::get_export_index` である（`NameMap::get`）。
- 実行（`src/external/runtime.rs` 296〜298 行）:
  - `ExternalSpec` に `pub instance: Option<String>` を足す（インターフェースの書き出しの名前。world の直下なら `None`）。`export` には関数の名前（`#` の後半）を入れる。
  - `instance` があれば、`component.get_export_index(None, instance)` と `component.get_export_index(Some(&parent), &spec.export)` で索引を得て、`instance.get_func(&mut store, &index)` を呼ぶ。`component` は `ExternalRuntime` が持つコンパイル済みのものを使う（調査 B 1.2。検査のときの索引は別の `Component` のものなので使えない）。実行時の引き方は semver の互換も探すが、まず完全一致を探すので、検査で完全一致を確かめた名前なら同じ書き出しを返す。
  - 索引は呼び出しのたびに引いてよい。キャッシュは V4 で要れば足す。
- E1006（`codes.rs` 1033〜1035 行）:
  - 文言を `"the component \`{path}\` has no function \`{name}\`"` に改め、「at the top level of its world」を除く。`name` には第 3 引数の全体を入れる。
  - 注記 `exports` の一覧には、world の直下の関数と、インターフェースの書き出しの中の関数（`名前#関数` の形）を、書き出しの順に並べる。インターフェースの中の resource のメソッド（`名前#[method]R.m`）も、関数なので含める。
  - 前半が書き出しの名前と版だけ違う場合は、注記 `version` を足す。例: 「`` the component exports the interface as `{found}`; the version must match exactly ``」。
  - `#` のない名前がインターフェースの書き出しの名前に一致した場合は、注記 `interface` を足す。例: 「`` `{name}` is an interface; write `{name}#function` ``」。
  - 説明の文は「External declarations name a function exported by the component, directly or as `interface#function`.」の趣旨にする。
  - E1006 を確かめているのは、ゴールデンではなく `src/external/tests.rs` 89〜96 行の単体テストだけである（`nested` の場合は、引き続き E1006 になる）。
- 期待する宣言の型（R2）: E1007・E1008・E1009 に注記 `declaration` を足す。例: 「`` the component function corresponds to `function {name}({params}) -> {result}` ``」。
  - `name` は Benitoite の宣言の名前とする。
  - 引数名は WIT の名前から `-` を除き、除いた位置の次の英字を大文字にする（`byte-start` → `byteStart`）。
  - 型は 03-10「型の対応」の表を逆に引く。`list<u8>` は `Bytes`、`tuple` の 2 要素と 3 要素は `Pair`・`Triple` とする。結果がなければ `Unit` とする。
  - 表で引けない WIT の型が一つでもあれば、注記を付けない。record・variant・enum も Benitoite の型の名前を決められないので、V3 の後も注記を付けない。
  - 理由: 型の名前を作れない場合に、推測した名前を示さないためである。
- 試験用のコンポーネント: `.wat` で、版つきのインターフェースを書き出せることを確かめた。

  ```wat
  (component
    (core module $m
      (func (export "add") (param i64 i64) (result i64) local.get 0 local.get 1 i64.add)
      (func (export "top") (result i64) i64.const 7))
    (core instance $i (instantiate $m))
    (func $add (param "a" s64) (param "b" s64) (result s64) (canon lift (core func $i "add")))
    (func $top (result s64) (canon lift (core func $i "top")))
    (instance $api (export "add" (func $add)))
    (export "bnt:test/api@1.2.0" (instance $api))
    (export "top" (func $top)))
  ```

  `wasm-tools component wit` は、これを `export bnt:test/api@1.2.0;` と `export top: func() -> s64;` の world として読んだ。
- テストの置き場所:
  - 照合の成否（版つきの完全な名前で引ける、`@1.0.0` が E1006、前半が空・後半が空が E0815、world の直下が今のとおり引ける）は、`src/external/tests.rs` の `component_and_signature_errors` の表に場合を足して確かめる。`wat::parse_str` で組み立てる形である。
  - 実行（インターフェースの中の関数を VM と参照インタプリタで呼べる）は、`testdata/external/` に `run` のゴールデンを一つ足して確かめる。`.wat` と、`testdata_components_match_their_text` で作り直した `.wasm` を置く。名前の例: `interface`。
  - E1006 の注記の文面は、`check` のゴールデンを一つ足して確かめる。
- 設計書: plan.md の一覧に加えて、01-02「外部の関数の宣言」（「書き出した関数の名前」）を直す。02-10 の表の E10 の行の「world の直下の関数と型の照合」も直す。

## V3 への補足

- 受け付ける型:
  - `TypeckOutput.adts`（`AdtTable`。鍵は型の束縛の番号で、`TyCon::Adt(id)` の `id` と同じ）に載っている型を、`Option`・`Result`・`Pair`・`Triple` の判定（`types.rs` 24〜52 行）の後で受け付ける。
  - 標準ライブラリのレコードと `data` も、利用者の型と同じ規則で受け付ける。例えば `Json.ParseError` を WIT の record に照合でき、V6 の Json で使える。再帰する `Json.Value` は、下記の再帰の検出で誤りになる。
  - `types::plan` は今 `&ResolveOutput` だけを受け取っているので、`&AdtTable`（`check_all` の `types.adts`）も渡す。
- 二段の変換表にする。
  - 理由: Wasmtime の `Val::Record`・`Val::Variant`・`Val::Enum` は、WIT の名前（`byte-start` など）を文字列で持つ（調査 B 3.1）。したがって、実行時に使う `ExternalSpec.params`・`result` の `WitPlan` には、Benitoite の名前ではなく WIT の名前を入れなければならない。WIT の名前は照合の後にしか分からない。enum と variant のどちらに照合したかも、照合の後にしか決まらない。
  - 宣言から作る形を、非公開の型 `DeclPlan`（`types.rs` の中）とする。レコードは Benitoite の欄の名前と子の組の並び、`data` は構成子の名前・タグ・子（0 個か 1 個）の並びを持つ。
  - `declaration_plan`（`check.rs` 388 行）は、コンポーネントを読む前に `DeclPlan` を作り、受け渡せない型を E1010 で報告する（今と同じ順で、コンポーネントがなくても E1010 を出す）。
  - 照合では、今の `WitPlan::matches(&self, &Type) -> bool` を `fn bind(plan: &DeclPlan, ty: &Type) -> Result<WitPlan, Mismatch>` に置き換え、WIT の名前を焼き込んだ `WitPlan` を作る。
  - `WitPlan` に足す列挙子の例:
    - `Record { fields: Vec<(String, WitPlan)> }`（WIT の名前と子。順は WIT の順で、宣言の順と同じ）
    - `Variant { cases: Vec<(String, u32, Option<Box<WitPlan>>)> }`（WIT の名前、構成子のタグ、ペイロード）
    - `Enum { cases: Vec<(String, u32)> }`
- 名前の比べ方（R3）:
  - 正規化は、`-` を除いて ASCII の英字を小文字にする（`byte-start` → `bytestart`、`byteStart` → `bytestart`、`NotFound` → `notfound`）。
  - 欄と場合は、位置ごとに正規化した名前の一致を求める（順の一致を兼ねる）。
  - 「二つ以上に当たる」の判定は、一つの record・variant・enum の中で、正規化した名前が重なるかを、WIT の側と Benitoite の側の両方で調べる。WIT の側の例は `a-bc` と `ab-c`、Benitoite の側の例は `byteStart` と `bytestart` で、どちらも正規化すると重なる。重なれば照合の誤りとする。
  - `_` は除かない。`x_y` のように `_` を含む Benitoite の名前は、どの WIT の名前にも一致しない（R3 のとおり）。照合の誤りの注記で、正規化の規則を示す。
- 照合の規則:
  - レコードは、WIT の `record` だけに照合する。欄の数・順・名前・型が一致しなければならない。
  - すべての構成子が引数を持たない `data` は、`enum` にも、中身のない場合だけの `variant` にも照合する。
  - 引数が 1 個の構成子を含む `data` は、`variant` に照合する。場合の数・順・名前と、ペイロードの有無と型が一致しなければならない。
  - Benitoite の構成子の引数は、位置で並べる形だけで、名前付きの欄の形はない（`syntax/ast.rs` の `Variant.fields: Vec<TypeExpr>`）。WIT の `variant` の場合に record を載せるときは、レコードの型を引数に一つ取る構成子（`Rect(Rectangle)`）として書く。
- E1010 の系（宣言から分かる誤り。`DeclPlan` を作る段で出す）:
  - 型パラメータを持つ型（`AdtDef.type_params` が空でない。具体的な型引数を渡していても誤り）には、注記 `type_params` を付ける。
  - 引数が 2 個以上の構成子には、注記 `arity` を付ける。修正案として、引数をレコードか `Pair`・`Triple` にまとめることを示す。
  - 再帰する型には、注記 `recursive` を付ける。
  - 文言の `ty` には、その利用者の型を入れる。
  - 再帰の検出は `DeclPlan` を作る関数で行う。いま展開している型の束縛の番号を経路の積み重ね（`Vec<BindingId>`）で持ち、同じ番号に再び入ったら再帰とする。`List`・`Option` などを通した間接の再帰も、この経路で捕まえる。訪れた型の集合（visited）ではなく経路で判定し、兄弟の欄に同じ型が二度現れる場合を再帰と取り違えないようにする。
  - `types.rs` の `plan` は今 `Result<WitPlan, &Ty>` を返しているが、理由を運べる非公開の誤りの型に変えてよい。
  - 注記 `types` の一覧（`codes.rs` 1044 行）に「records, and `data` types without type parameters whose constructors take at most one argument」の趣旨を加える。既存のゴールデン（`unsupported-inner` など）の差分は、この注記の文だけになる。
- E1008・E1009 の系（照合の誤り）:
  - 欄・場合の数、順、名前、ペイロードの有無の食い違いと、正規化した名前の重なりは、E1008・E1009 で報告する。
  - 新しい注記 `reason` に、最初の食い違いを一文で示す。例: 「`` field 2 is `y` in WIT but `z` in `Point` ``」「`` names are compared without `-` and ignoring case ``」。
  - `types::show`（`types.rs` 128〜169 行）は、record・variant・enum の中身を `record { byte-start: s64, y: s64 }`、`variant { circle(f64), empty }`、`enum { red, blue-ish }` の形で示すように改める。`WitPlan`・`DeclPlan` の表示も同じ形にする（`DeclPlan` の名前は Benitoite の名前のままでよい）。
- 変換（`src/external/convert.rs`）。作業列の形（`children`・`ToWasm`・`FromWasm`）に分岐を足し、Rust の再帰を使わない。
  - レコード → `Val::Record`: 値の頭が `(FieldsKind::Ctor, tags::RECORD)` であることを確かめ、`ctx.field(v, i)` で欄を取り出す。`Build` で `Val::Record(names.zip(values))` を作る。
  - 構成子 → `Val::Variant`・`Val::Enum`: 引数のない構成子は `Value::Tag(CtorTag(tag))`、引数のある構成子は `fields_header == (Ctor, tag)` のフィールドの対象である（調査 A 3.1）。タグから場合を引く。
  - `Val::Record` → 値: WIT の順に子を積み、`FromWasm::Ctor(tags::RECORD, n)` で作る。
  - `Val::Variant(name, payload)`・`Val::Enum(name)` → 値: 名前で場合を探す（線形でよい）。ペイロードがなければ `Value::Tag(CtorTag(tag))`、あれば `FromWasm::Ctor(tag, 1)` で作る。名前が見つからない、ペイロードの有無が合わない場合は、今と同じく `invalid()`（処理系の不具合）とする。Wasmtime が判別子を確かめた後なので、ゲストの不正ではないためである。
- 受け渡しの予算: Wasmtime の動的な値の持ち上げと同じ数え方にする（`wasmtime-49.0.2/src/runtime/component/values.rs` 137・143・169・182 行）。
  - record: 欄の数 × `size_of::<Val>()` と、欄の WIT の名前のバイト数の和。
  - variant: 場合の WIT の名前のバイト数と、ペイロードがあれば `size_of::<Val>()`。
  - enum: 名前のバイト数。
  - `check_arguments`（`convert.rs` 73〜138 行）にこの数え方を足し、03-10「実行」（93 行）と 02-09「外部の関数の実行」（347 行）の予算の段落に書き足す。plan.md の V3 の設計書の一覧には 02-09 が抜けているので加える。
  - 理由: 戻り値は Wasmtime がこの数え方で数えるので、引数を同じ数え方にすれば、03-10 の「引数と戻り値でそれぞれ 256 MiB」の意味が揃う。
- `.wat` の書き方（wasm-tools 1.261.0 の `validate` で確かめた）:
  - 書き出す関数の型に現れる record・variant・enum は、名前を付けて書き出さなければならない。書き出さないと「func not valid to be used as export」か「instance not valid to be used as export」になる。
  - インターフェースの中に置く場合は、インスタンスの中で、型の書き出しを関数の書き出しより前に並べる。順が逆でも、型の書き出しが欠けていても誤りになった。

    ```wat
    (type $point (record (field "byte-start" s64) (field "y" s64)))
    (type $color (enum "red" "green" "blue-ish"))
    (func $sum (param "p" $point) (result s64) (canon lift (core func $i "sum")))
    (func $pick (param "n" s64) (result $color) (canon lift (core func $i "color")))
    (instance $api
      (export "point" (type $point))
      (export "color" (type $color))
      (export "sum" (func $sum))
      (export "pick" (func $pick)))
    (export "bnt:test/shapes" (instance $api))
    ```

  - world の直下に置く場合は、`(export $p "point" (type $p0))` で書き出し、関数の型には書き出しが返した `$p` を使う（`src/external/tests.rs` の `typed_component` と同じ形）。
  - record を戻り値にする関数は平らな値が二つ以上になるので、`testdata/external/roundtrip/x.wat` と同じく、メモリに書いて番地を返す（`canon lift` に `memory` と `realloc` を渡す）。
- テストの置き場所:
  - 照合の誤り（欄の順、名前、場合の数、型パラメータ、再帰（直接と `List` を通した間接）、引数 2 個の構成子、名前の重なり、`byte-start` と `byteStart`・大小の違いが通ること）は、`src/external/tests.rs` の表の形の単体テストで、コードと注記を確かめる。`.wat` の誤りの場合ごとにゴールデンを作ると、場合ごとにコンポーネントのファイルが増え、検査の時間もかかるためである。
  - 文言の形は、`check` のゴールデンを一つで確かめる。
  - 往復（record、payload のある variant、enum、`Result[T, MyError]`、`Option[MyRecord]`）は、`testdata/external/` の `run` のゴールデンを一つで確かめる。名前の例: `records`。`run` は VM と参照インタプリタの両方で走る。
- 設計書: plan.md の一覧（03-10「型の対応」、言語リファレンスの 21 節）に加えて、次を直す。
  - 03-10「照合」の手順 4 と、その理由。今は「名前の変換の規則を要しない位置で型を検査するため」と書いている。
  - 03-10「型の対応」の段落「利用者の `data`、レコード…は誤りとする」と、その理由。
  - 03-10「実行」と 02-09「外部の関数の実行」の予算。
  - 02-07 の外部の関数の表の変換表の中身（記述があれば）。

## 作業の間の依存

- V1 は V2・V3 と独立である。重なるのは、`src/diag/codes.rs`（別の区分の行）、`CHANGELOG.md`、02-10、Skill の生成物（`skill/references/diagnostics.md`・`grammar.md`）だけである。直列に取り込めば衝突しない。
- V2 と V3 は、同じファイルに触れる。重なるのは、`src/external/check.rs`（引き方と照合の本体）、`src/external/mod.rs`（`ExternalSpec`・`WitPlan`）、`src/external/tests.rs`、`codes.rs` の E10 の行、03-10、言語リファレンスの 21 節である。V2 を取り込んだ後に V3 を始める。V3 は V2 の注記 `declaration`（E1007〜E1009）を前提にし、record・variant・enum を含む関数では注記を付けない。
- V1 の契約の検査は、V3 の後に `public` の外部の関数が非公開のレコードを使う場合にも当たる。追加の作業は要らない。
- V2 の `ExternalSpec.instance` と V3 の `WitPlan` の新しい列挙子は、V4（速い経路の判定）と V5（resource）が前提にする。
- 診断コードは作業の順に続きの番号を取る。V1 が E0253、V2 が E0815 を使うので、V4・V5 で足すコードは E0254・E0816・E1012 以降になる。

## オーケストレータへの報告

- plan.md の「どの作業にも共通する決まり」の「新しい診断コードは、既存の区分の空いた番号を使う」は、02-10「診断コード」と食い違う。02-10 は、続きの番号を使い、廃止した番号を使い回さないと定めている。plan.md を「区分の続きの番号」に直すべきである。
- R2 と調査 B 1.3 は「書き出しを列挙して照合する」としているが、検査で使っている型の側の `types::Component::get_export`・`ComponentInstance::get_export` は、`IndexMap` による完全一致である。semver の互換で引くのは、実行時の `get_export_index` だけである。結論（完全一致を求める）は変わらないが、実装は列挙なしで済む。decisions.md の理由の文を直すかは任意である。
- V3 の変換表は、照合の後に WIT の名前と enum・variant の別を焼き込む二段の形が要る。plan.md の V3 の 1 は「`WitPlan` に欄の順・構成子のタグ・ペイロードの有無を焼き込む」としか書いていない。補足で、`DeclPlan` から `WitPlan` を作る形を指示した。
- plan.md の設計書の一覧に抜けがある。
  - V2 には、01-02「外部の関数の宣言」と、02-10 の E10 の行が抜けている。
  - V3 には、02-09「外部の関数の実行」の予算、03-10「照合」の理由、03-10「実行」の予算が抜けている。
  - V1 では、01-03 の契約の規則が「同じモジュールの型」に限っている。同じパッケージの別のモジュールの `public(package)` を `public` の宣言が使う場合も誤りにすると補足で決めたので、その旨を書き直す必要がある（R1 の趣旨どおり）。
- 設計者に尋ねる候補（補足では推す答えで指示した）は次の四つである。
  1. 標準ライブラリのレコードと `data` も外部の関数に渡せるようにするか。補足では許すとした（`Json.ParseError` を V6 で使える）。R3 は「利用者の」とだけ書いている。
  2. R2 の「期待する宣言の型を示す」の範囲。補足では、E1007〜E1009 の注記とし、表で逆に引けない型があれば付けないとした。
  3. 同じパッケージの中の非公開の名前を引いた E0330 の修正案を、`public` のままにするか、`public(package)` にするか。補足では、既存の出力を変えないため `public` のままとした。パッケージの作者には `public(package)` のほうが狭くて安全である。
  4. `_` を含む Benitoite の欄の名前が WIT の名前に一致しないこと（R3 の帰結）を受け入れるか。
- plan.md の V3 の 4 は、誤りの場合ごとに `.wat` のゴールデンを置く書き方である。補足では、照合の誤りを `src/external/tests.rs` の単体テストに寄せ、ゴールデンを文言と往復の 2 件に絞った。plan.md の「必要な数に絞る」の趣旨に合わせた変更である。
- 記録: 型が DAG で共有されると、`DeclPlan` と照合の大きさが型の入れ子の深さに対して指数的に増えうる（例: 二つの欄が同じ型を持つ型の連なり）。実用上の危険は小さいので、この作業では上限を設けない。必要なら docs/todo に項目を足す。

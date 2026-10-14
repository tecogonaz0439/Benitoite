# 調査 A: 処理系の現状（フェーズ 2 の前）

2026-10-13 に、コミット `2d8f1d0b`（san_benito）の処理系を読んで調べた。ビルドもテストも走らせていない。行番号はこのコミットのものである。Wasmtime の事実は手元の cargo のレジストリにある `wasmtime-49.0.2` のソースで確かめた（パスは `~/.cargo/registry/src/*/wasmtime-49.0.2/`）。確かめていない見立てには「推測」と書く。

パスの略記: `src/` は `crates/benitoite/src/`、`wt/` は `wasmtime-49.0.2/src/runtime/component/`。

## 1. 外部の関数の今の流れ

### 1.1 段ごとの場所

| 段 | 場所 | 内容 |
|---|---|---|
| 字句・構文 | `src/syntax/parser/items.rs` 159〜168（`body_rule`）、196〜197・213〜（`check_decl_header`。E0811 型パラメータ、E0812 `uses`）、514・526〜537（`attribute_args_error`。E0809 引数が三つでない、E0810 第 1 引数が `"wasm"` でない）、`src/syntax/parser/decls.rs` 283〜（本体を書いたら E0814） | 属性の引数は `StrArg` の並びとして構文木に残る。第 3 引数（関数の名前）の形は検査しない |
| 収集 | `src/resolve/collect.rs` 368〜386 | `@external` の付いた関数の束縛ごとに `ExternalDecl { module, decl, kind, path, export, spec: None }` を `ResolveOutput.externals`（`src/resolve/mod.rs` 141）に入れる |
| 型検査 | 普通の関数として型を付ける。宣言の型（`TypeckOutput.decl_types` の `Scheme`）を照合が使う | |
| 照合 | `src/external/check.rs` 89〜386（`check_externals` → `check_all`）、`src/external/types.rs` | 後述 1.2 |
| 脱糖 | `src/ir/desugar/decls.rs` 200〜224 | 本体のない外部の関数に、`ValKind::External { def, spec }` を呼ぶ合成の本体を作る。エフェクトは `EffectSet::empty()`（純粋） |
| コード生成 | `src/bytecode/codegen/emit.rs` 254〜259（`EXT A B C` を出す）、`src/bytecode/codegen/tables.rs` 285〜320（`external`） | `ExternalSpec.id` ごとに一つ、`Arc<ComponentSource>` の同一性ごとに一つにまとめて `CompiledProgram.externals`（`ExternalTable { functions: Vec<ExternalRef>, components: Vec<Arc<ComponentSource>> }`、`src/bytecode/program.rs` 254〜266・289）に積む。項目の数が 65535 を超えると L0113（`src/diag/codes.rs` 1186、`check_table`） |
| VM | `src/vm/dispatch.rs` 568（振り分け）、990〜1031（`external_call`） | 中断の印を見てから引数を読み、`state.externals`（`RunState` の欄、`src/vm/state.rs` 22。`Option<Box<ExternalRuntime>>`）を初回に作って `external::call` を呼ぶ |
| 参照インタプリタ | `src/refinterp/convert.rs` 36〜37・120〜160、`src/refinterp/eval.rs` 445 | 自前の値をヒープの値に写してから同じ `external::call` を呼び、結果を写し戻す。写し戻しは中身を見せない値を受け付けない（`from_heap_with(ctx, value, &mut \|_\| Err(invalid_conversion()))`） |
| 実行 | `src/external/runtime.rs` 235〜321（`call`・`call_with_fuel`）、`src/external/convert.rs` | 後述 1.3 |

### 1.2 照合（`check.rs`・`types.rs`）

- 外部の関数がなければ何もしない（`check.rs` 98）。あれば検査ごとに `Engine` を一つ作る（129）。同じ正規化したパスのコンポーネントは `cache`（147・248〜265）で一度だけ読み、`check_component`（33〜57）で magic と版を確かめ、`Component::from_binary` でコンパイルし、取り込みが空であることを確かめる。
- 宣言ごとに `declaration_plan`（388〜424）が、宣言の型から変換表 `WitPlan` を作る。作れない型は E1010（`unsupported`、425〜441）。
- 書き出しは `component.component_type().get_export(&engine, &decl.export.value)`（277〜280）で world の直下の名前だけを引く。関数でなければ E1006（281〜294。書き出しの一覧も world の直下の関数だけを示す）。非同期の関数は E1011（295〜302）。
- 引数の数（E1007）、位置ごとの型（`WitPlan::matches`、E1008）、戻り値（E1009）を照合する（303〜367）。WIT の名前（引数名など）は見ない。
- 通れば `ExternalSpec { id, function, component, export, params, result }`（`src/external/mod.rs` 65〜75）を `Arc` で `decl.spec` に入れる（368〜383）。`id` は検査の中の通し番号。

型の対応表は `types.rs` 12〜57 の `plan`（宣言の `Ty` → `WitPlan`）と、59〜102 の `WitPlan::matches`（`WitPlan` × `wasmtime::component::Type`）の二つである。`WitPlan`（`mod.rs` 31〜48）の列挙子は `S64・F64・Bool・Char・String・U8・Bytes・List・Option・Result{ok,err}・Tuple` で、`Option`・`Result`・`Pair`・`Triple` は `resolved.stdlib(...)` の束縛の番号で識別する（`Pair`・`Triple` は構成子の束縛から型の束縛を引く `stdlib_type`、171〜180）。`plan` は `Ty` の入れ子を Rust の再帰で辿る。`show`（128〜169）は WIT の `record`・`variant`・`enum`・`resource` などを中身なしの語で示すだけである。

### 1.3 実行（`runtime.rs`・`convert.rs`）

- `ExternalRuntime`（`runtime.rs` 41〜61）は `Engine`、コンパイル済みの `Component` の表（`Vec<Option<Component>>`、`ExternalTable.components` と同じ添字）、空の `Linker<CallLimits>`、中断の見張り（`Watcher`、62〜96）を持つ。言語の値は持たない（02-08 の表も「回収の根に含めない」と書く）。VM では最初の `EXT` で作る（`dispatch.rs` 1009〜1013）。コンポーネントは初めて呼ぶときに `Component::from_binary` でコンパイルし直す（`runtime.rs` 279〜282。検査のときのコンパイル結果は使い回さない）。
- 呼び出しごとに（286〜308）: `Store::new(&engine, CallLimits::default())`、`store.limiter`、`set_fuel(10^10)`（`FUEL`、19）、`set_hostcall_fuel(256 MiB)`（`TRANSFER`、21）、`set_epoch_deadline(1)`、`linker.instantiate`、`instance.get_func(&mut store, &spec.export)`、`func.call(&mut store, &params, &mut results)`。インスタンスと `Store` は呼び出しの後に捨てる。
- 制限器 `CallLimits`（115〜163）: メモリの増加量を `Store` ごとの合計 `memory` に加え、64 MiB（`MEMORY`）を超えたら誤り。表の要素 10,000、インスタンス・メモリ・表の数それぞれ 16。
- 失敗の分類 `failure`（164〜232）: 専用の誤りの型、hostcall fuel の枯渇（文言の一致、`text.rs` 50）、数の上限（文言の接頭辞、`text.rs` 53〜66）、`Trap::Interrupt` → `ExternalFailure::Interrupted`、`Trap::OutOfFuel` → R0904、その他 → R0601。
- 中断: 共有の印があるときだけ、10 ms ごとに印を読み `Engine::increment_epoch` を呼ぶスレッドを起こす（`Watcher::new`、67〜86）。参照インタプリタは印を渡さない。
- 値の変換（`convert.rs`）: どれも明示の作業列で行う。
  - `check_arguments`（73〜138）: 変換前に予算を数える。リストと `Bytes` は要素ごとに `size_of::<Val>()`（40 バイト）、文字列は UTF-8 のバイト数。
  - `to_wasm`（149〜219）: 言語の値 → `Val`。`Bytes` は `Val::List(bytes.iter().map(Val::U8))`（168〜174）。子は `children`（17〜70）で取り出す。`Option` は `Value::Tag(CtorTag(OPTION_NONE))` か `fields_header == (Ctor, OPTION_SOME)` で見分け、`Result` はタグで見分ける。
  - `from_wasm`（239〜346）: `Val` → 言語の値。文字列・`Bytes` は 2^30 バイト、リストは 2^24 要素を先に確かめる（`check_size`）。`Bytes` は `Val::U8` を一つずつ取り出して `Vec<u8>` に集めてから `alloc_bytes_with` で写す（270〜309）。タプルは `FromWasm::Ctor(tags::PAIR, n)`（316）で作る。`tags::PAIR` と `tags::TRIPLE` はどちらも 0（`src/builtins/table.rs` 102・104）なので、`Triple` も正しく作れる（不具合ではない）。

### 1.4 拡張ごとに変える箇所

| 拡張 | 変える箇所 |
|---|---|
| レコード・直和型・enum（TODO-047） | `WitPlan` に列挙子を足す（`mod.rs` 31〜48）。`types::plan` に `AdtTable` を渡して利用者の型を引く（今は `&ResolveOutput` だけを受け取る。`check.rs` 155〜160 の `names.adts` が `TypeckOutput.adts` を既に持つ）。再帰の検出（今の `plan` は再帰する型で止まらない）。`WitPlan::matches` に `Type::Record`・`Type::Variant`・`Type::Enum` の照合。`WitPlan::show` と `types::show` に中身を示す形。`convert.rs` の `children`・`check_arguments`・`to_wasm`・`from_wasm` に分岐。E1010 の注記の型の一覧（`src/diag/codes.rs` 1044〜1047）。`unsupported` の利用者の型の注記（`check.rs` 430〜439） |
| resource（TODO-047・212） | 型の側: Benitoite の型をどう宣言するか（後述 2.4）。照合: `Type::Own`・`Type::Borrow` と、resource の型の同一性（`ResourceType`）を宣言の型と結ぶ。実行: `ExternalRuntime` に長く生きる `Store` とインスタンスを持たせる（後述 2.2）。`convert.rs` に `Val::Resource(ResourceAny)` の受け渡し。参照インタプリタの写し（`refinterp/convert.rs` は中身を見せない値を写せない） |
| インターフェースの関数（TODO-235） | 属性の第 3 引数の形（`items.rs` 526〜537 で引数の数を三つに固定）。照合: `check.rs` 277〜294 を、インターフェースの書き出し（`ComponentItem::ComponentInstance`）の中の関数まで辿る形に。E1006 の書き出しの一覧（282〜284）と文言（`codes.rs` 1033〜1035「at the top level of its world」）。実行: `runtime.rs` 296〜298 の `get_func(&mut store, &spec.export)` を、`ComponentExportIndex` を二段で引く形に（後述 1.5）。`ExternalSpec` にインターフェースの名前の欄（`ExternalSpec` は凍結した型ではない） |
| 速い経路（TODO-230） | `convert.rs` の `Bytes` の三か所（予算 109〜112、`to_wasm` 168〜174、`from_wasm` 270〜309）と数のリスト（`List(S64)` など）。`runtime.rs` 299〜305 の `func.call`（`Val` の並び）を、型付きの呼び出しか線形メモリへの直接の書き込みに置き換える経路を足す。予算の数え方（02-09「外部の関数の実行」の決定）と、それに頼るテスト（`convert.rs` 371〜438、`testdata/external/aliased-result`） |

### 1.5 Wasmtime 49.0.2 で確かめた API（拡張に関係するもの）

- インターフェースの中の書き出し: `Component::get_export_index(&self, instance: Option<&ComponentExportIndex>, name)`（`wt/component.rs` 794）と `Instance::get_export_index(&self, store, instance: Option<&ComponentExportIndex>, name: &str)`（`wt/instance.rs` 334）がある。インターフェースの書き出しの索引を先に引き、それを `instance` に渡して中の関数の索引を引き、`Instance::get_func(store, 索引)`（`wt/instance.rs` 155。`name: impl ExportLookup` は索引も受け付ける）で関数を得る。インターフェースの書き出しの名前の綴り（`ns:pkg/iface` か、版つきか）は確かめていない（調査 B の範囲）。
- トラップの後: `Store` は `trapped` の印を立て、以後はその `Store` のどのインスタンスにも入れない（`wt/store.rs` 284〜298 の `may_enter`、`wt/func.rs` 468 で `Trap::CannotEnterComponent`）。
- resource の解放: `ResourceAny::resource_drop(self, store)`（`wt/resources/any.rs` 165）。`ResourceAny` は作った `Store` に結び付く。
- 受け渡しの予算: 動的な値の持ち上げは要素ごとに `size_of::<Val>()` を数える（`wt/values.rs` 232 など）。型付きの持ち上げの `Vec<T>`・`WasmList<T>` は `len × size_of::<T>()` を数える（`wt/func/typed.rs` 1777）。したがって型付きの `list<u8>` は 1 バイトにつき 1 を数える。
- `map<K, V>` は `Config::wasm_component_model_map` で有効にする機能である（`wasmtime-49.0.2/src/config.rs` 1365）。今の `engine_config()`（`src/external/mod.rs` 96〜104）は有効にしていない。既定で無効かは確かめていない。

## 2. resource を入れる上での論点

### 2.1 今の前提

- 03-10「実行」は「コンポーネントの状態は呼び出しごとに作り直す。理由: 同じ引数の結果が以前の呼び出しの状態に依存せず」と決め、02-09「外部の関数の実行」も「インスタンスは結果の変換を終えたら捨て、次の呼び出しに状態を残さない」と決めている。`runtime.rs` 446〜454 のテスト（`failures_and_fresh_instances` の最後）は、大域の計数器を持つコンポーネントを 2 回呼んで、どちらも 1 を返すこと（状態が残らないこと）を確かめている。
- 外部の関数を純粋な関数として型付けする根拠（01-07「外部の関数のエフェクト」、07-01 の保証の表「純粋な関数として型が付く」）は、取り込みがないことと、呼び出しごとに状態を作り直すことにある。WASM の側に resource を長く持たせると、その resource のメソッドの結果が前の呼び出しに依存しうる。純粋として型を付け続けるなら、この点を設計書の保証にどう書くかが論点になる。

### 2.2 インスタンスを長く持つ場所

- 置き場所の候補は `ExternalRuntime`（実行ごとの状態。`RunState.externals`）である。大域の状態の禁止（AGENTS.md「大域の状態」）に合い、テストの関数ごとに実行を作る `benitoite test` でも実行をまたがない。`ExternalRuntime` は言語の値を持たない約束（02-08「外部の関数の実行系」）なので、Wasmtime の `Store` と `ResourceAny` を持つことはこの約束に反しない。
- 単位の候補（推測。どれも未検証）:
  - (a) コンポーネントごとに一つの長く生きる `Store`・インスタンスを持ち、そのコンポーネントの全関数をそこで呼ぶ。resource 以外の関数の呼び出しにも状態が残るので、2.1 の決定を広く変える。
  - (b) resource を作る呼び出しごとに専用の `Store`・インスタンスを作り、その resource のメソッドはその `Store` で呼ぶ。resource を受け渡さない関数は今のまま呼び出しごとに作る。状態が残るのは resource の中だけになる。`Regex.compile` のたびにインスタンス化の費用がかかる（TODO-232 で測る対象）。
- 長く持つときに変わる上限の意味: `CallLimits.memory`（`runtime.rs` 115〜141）は `Store` の寿命の合計を数えるので、「一回の呼び出しの合計 64 MiB」が「一つの `Store` の寿命の合計」になる。(b) では resource の数 × 64 MiB までゲストのメモリを持ちうるので、実行全体の上限か resource の数の上限が要る。燃料・hostcall fuel・epoch の期限は呼び出しの前に設定し直せば呼び出しごとのままにできる（`set_fuel` などは `Store` の関数）。
- トラップ・燃料切れ・中断: どれも今は実行を止める（R0601・R0904・中断の終了状態 130）。トラップした `Store` には二度と入れないが、実行そのものが止まるので、同じ実行の中で再び入ることはない。中断で止まるときも `ExternalRuntime` を捨てるだけでよい（推測）。
- 推測: Rust の `regex` クレートは照合のたびに内部の遅延 DFA のキャッシュを更新するので、resource を長く持つと、同じ照合の燃料の消費量が前の照合に依存する。燃料の上限に達するかどうかが履歴で変わりうる。

### 2.3 Benitoite の今のリソースの型と、中身を見せない型

- 言語のリソースの型（01-10「リソースの型」）は、標準ライブラリが定めるものに限り、利用者が定義する方法はない。組み込みの型の表（`src/types/builtin.rs` 9〜19 の `BuiltinTypeClass::Resource`）で `TaskGroup`・`File.Reader`・`File.Writer`・`Http.Listener`・`Http.Exchange` の五つである。解放のエフェクトは `State`、`with` で束縛すると抜けるときに解放する。
- 実行時は `Value::Resource(ResourceId)`（`src/runtime/heap/value.rs` 28・80）で、実体は実行ごとの `ResourceTable`（`src/runtime/io/resources.rs` 49〜67、`RunState.resources`）にある。種類は `ResourceKind`（`src/runtime/mod.rs` 30〜36、凍結の 10-10）、中身は `ResourceContent::{Os, TaskGroup}`（23〜29）。番号の下位 3 ビットが種類で（116・472）、今は五種類なので三つ空いている。状態は `Open`・`Lent`・`Releasing`・`Released`。解放は VM の解放の枠と止める手順で行い（02-09「リソースの追跡」）、作業用のスレッドへの貸し出しの仕組みと結び付いている。
- 一方、今の `Regex.Pattern` と `Regex.Match` はリソースの型ではなく、中身を見せない型（`BuiltinTypeClass::Opaque`、`src/types/builtin.rs` 184〜195）である。実体は `ObjKind::Opaque` のヒープの対象で、Rust の値 `Pattern { regex, names: Rc<...> }`（`src/builtins/funcs/regex.rs` 10〜15）を持ち、回収で解放される。`with` も解放のエフェクトも要らない。`OpaqueData` は作った後に変えない約束で、`ValueCtx::opaque` は共有の参照だけを返す（`value.rs` の `OpaqueData` の説明）。
- したがって、「Regex のコンパイル済みの正規表現を WASM 側に持つ」を今の `Regex` と同じ使い勝手で行うなら、写す先は言語のリソースの型ではなく、中身を見せない型である（推測）。言語のリソースの型に写すと、`with` と `State` が要り、純粋な外部の関数という今の型付け（`uses` を書けない、`EffectSet::empty()`）と合わない。
- 中身を見せない値で表す案の論点（推測）:
  - ヒープの対象には `ExternalRuntime` の中の `Store` を指す番号（世代付き）だけを持たせ、`Store` そのものは `ExternalRuntime` に置く。対象は変えないので `OpaqueData` の約束を守れる。
  - 回収で対象が消えたときに WASM の側の resource を `resource_drop` する手段がない。対象の `Drop` からは `ExternalRuntime` に触れない。候補は、`Rc<RefCell<Vec<番号>>>` の解放待ちの列を対象と `ExternalRuntime` で共有し、次の外部の呼び出しか安全点で片付ける形、または実行の終わりまで解放しない形（resource を多く作るループで `Store` が溜まる）。`HostData` の説明は `Drop` で言語の後始末をしないことを求めている。WASM の `Store` の破棄が「言語の後始末」に当たるかは決めていない。
  - 既定の構成のヒープは mark-sweep（`Cargo.toml` の `default = ["gc-mark-sweep"]`）で、対象が消える時期は回収の時期に依存する。
  - 参照インタプリタは中身を見せない値を写せない（1.1 の表）。resource を受け渡す関数を参照インタプリタで動かすには、写しの仕組みを足すか、参照インタプリタとの差分テストの対象から外す。
- 言語のリソースの型で表す案の論点（推測）: `ResourceKind` に列挙子を足し（凍結の 10-10）、`ResourceContent` に外部の中身を足し、解放の処理（`resource_drop` と `Store` の破棄）を 02-09 の表に加える。解放でブロックしないので作業用のスレッドは要らない。利用者が `with` で囲む必要があり、外部の関数に `uses State` を許すかが論点になる（今は E0812 で `uses` を禁じる）。
- どちらの案も、WIT の resource に対応する Benitoite の型を宣言する手段が今の言語にない（2.4）。

### 2.4 resource に対応する型の宣言

- 構成子のない `data` は誤り（01-05「型の宣言は、少なくとも一つの構成子を持たなければならない」）で、中身を見せない型を利用者が宣言する構文はない。WIT の resource に当たる型を宣言するには、新しい宣言の形（例: 型の宣言に `@external` を付ける）か、組み込みの型の表への追加が要る（推測）。
- 新しい宣言の形は、構文木（`Item`。凍結の 10-03）、束縛の種類（`BindingKind`。凍結の 10-04）、型の構成子（`TyCon`。凍結の 10-05）のどれかに触れる見込みである（推測）。型の表現を変えるなら、形式化の型検査の出力の検査（`scripts/check-formal.sh` の `surfaceCheckAll`）への影響も確かめる要がある（推測）。

## 3. Benitoite の値の表現と、外部の関数の結果から値を作る方法

### 3.1 実行時の表現（`src/runtime/heap/value.rs`、02-08「値の表現」）

| 型 | 表現 |
|---|---|
| `Integer`・`Float`・`Byte`・`Boolean`・`Character`・`Unit` | 即値（`Value::Int` など、71〜86） |
| 引数のない構成子 | 即値 `Value::Tag(CtorTag(tag))`。`tag` は型の宣言の中で 0 から数えた番号（宣言の順） |
| 引数のある構成子・レコード・`Pair`・`Triple` | `FieldsKind::Ctor` の対象。印 `tag` と引数の並び（192〜211）。レコードは構成子が一つの型で、タグは 0（`tags::RECORD`、`src/builtins/table.rs`）、欄は宣言の順 |
| `String`・`Bytes` | 長さ付きの対象。`ctx.str`・`ctx.bytes` で読む |
| `List` | 空は `Value::EmptyList`、ほかは永続ベクタ（`FieldsKind::ListNode`） |
| `Map`・`Set` | 空は `Value::EmptyMap`・`EmptySet`、ほかは重みで平衡させる二分木（`FieldsKind::MapNode`・`SetNode`） |
| リソースの型 | `Value::Resource(ResourceId)` |
| 中身を見せない型 | `ObjKind::Opaque` の対象（`OpaqueData`） |

### 3.2 値を作る API（`NoGcCtx`・`ValueCtx` の公開の層）

- `src/runtime/heap/ctx.rs`: `alloc_str`（451）、`alloc_str_utf8`（466。UTF-8 を確かめる）、`alloc_bytes`（486）、`alloc_bytes_with(CheckedLen, |dst| ...)`（491）、`alloc_fields(FieldsKind, tag, &[Value])`（505）、`fields_header`（519）、`fields_len`（524）、`field`（531）、`alloc_opaque`（535）、`opaque`（538）、`alloc_host`（572）。
- `src/runtime/list.rs`: `from_values`（23）、`len`（52）、`to_vec`（189）、`cursor`（209）。
- `src/runtime/map.rs`: `map_from_sorted`（23。鍵の順に並んだ組から作る）、`map_to_vec`（63）、`compare_keys`（18）。`Json.parse` はこれで `Object` を作る（`src/builtins/funcs/json.rs` 368〜381）。

### 3.3 型の情報をどこから得るか

- 照合は型検査の後に走り、`TypeckOutput.adts`（`AdtTable`）を持っている（`check.rs` 155〜160）。`AdtDef`（`src/types/mod.rs` 222〜236）は名前・モジュール・型パラメータ・構成子の並び `ctors: Vec<CtorDef>`・レコードの欄 `record: Option<Vec<FieldInfo>>` を持ち、`CtorDef`（202〜210）は名前・`tag`（宣言の順）・引数の型 `fields: Vec<Ty>`（型パラメータは `Ty::Param`）を持つ。
- 実行時に要るのは、欄の数と順、構成子のタグ、引数の数だけである。これらは照合のときに `WitPlan` の中へ焼き込めば足りる（例: `Record { fields: Vec<WitPlan> }`、`Variant { cases: Vec<(tag, Option<WitPlan>)> }`、`Enum { tags }`）。`WitPlan` は `ExternalSpec` に入り、`ExternalSpec` は `Arc` のまま `CompiledProgram.externals` に入るので、コード生成と VM の側の変更は要らない（推測。`ExternalTable` は Wasmtime の型を含めない約束であり、`WitPlan` はそれに合う）。
- 作り方の対応（推測）: レコードは `alloc_fields(Ctor, tags::RECORD, 欄)`。直和型の引数のない構成子は `Value::Tag(CtorTag(tag))`、引数のある構成子は `alloc_fields(Ctor, tag, 引数)`。取り出しは `fields_header` と `field`（今の `Option`・`Result` と同じ形）。
- WIT との形の違い（推測）: WIT の `variant` の各場合のペイロードは一つなので、引数が二つ以上の構成子はタプルにするか受け付けない。WIT の `record` は欄の名前を持ち、Benitoite の欄の名前（camelCase）と WIT の名前（kebab-case）は綴りが違う。今の照合は「位置で照合し、WIT の名前には依存しない」（`types.rs` 60）ので、欄も位置で照合するか名前の変換の規則を設けるかを決める。`Val::Record` は WIT の順の `(名前, Val)` の並びである。
- 型パラメータを持つ利用者の型は、`plan` が受け取る `Ty::Con(Adt(id), args)` の `args` で `CtorDef.fields` の `Ty::Param` を置き換えれば扱える（推測）。TODO-047 の案は型パラメータなしに限る。
- 再帰する型（`Json.Value` は `Array(List[Value])`・`Object(Map[String, Value])` を持つ、`src/prelude/stdlib/Json.bnt` 4〜12）は WIT の型で表せない（TODO-212 の見込み。WIT に再帰型がないことは調査 B の範囲）。`plan` に辿った型の集合を持たせて再帰を誤りにする必要がある。

## 4. 公開の規則の実装

### 4.1 今の実装

| 項目 | 場所 |
|---|---|
| キーワード | `src/syntax/lexer.rs` 753（`"public" => KwPublic`）。キーワードの一覧は 729〜765 の `keyword`（34 語。01-01「キーワード」） |
| 構文 | `src/syntax/parser/items.rs` 293〜301（`parse_public`。`public` の字句を読んで `Option<Span>` を返し、`implement` の前なら誤り） |
| 構文木 | `TopDecl.public: Option<Span>`（`src/syntax/ast.rs` 90〜98。凍結の 10-03 の 322〜328） |
| 束縛 | `Binding.public: bool`（`src/resolve/mod.rs` 100〜116。凍結の 10-04 の 310〜320）。`collect_decl`（`src/resolve/collect.rs` 319〜320）が `top.public.is_some()` を写し、構成子・欄・メソッド・操作は包む宣言の値を受け継ぐ（`node_binding`、106〜122） |
| 公開の表 | `ResolveOutput.exports`（`mod.rs` 129。凍結の 10-04 の 337）。`collect.rs` 175〜181 で `public` の束縛だけを載せる。読むのは名前解決の中だけ（`collect.rs` 241・299、`lookup.rs` 223） |
| 見えるかの判定 | `src/resolve/lookup.rs` 206〜246（`children`）。同じモジュールの中ならトップレベルの表、ほかのモジュールなら公開の表を引く。標準ライブラリの型のモジュールの中の名前は `b.public` で絞る（240）。利用者の型の構成子・欄は、型を引ければ公開を問わず引ける（245） |
| 公開されていない名前の診断 | `lookup.rs` 431〜480 付近（E0330 は 440 行）。依存のモジュールなら注記 `package`、根のモジュールなら `public` を挿入する修正案 |
| 公開する契約の検査 | `src/resolve/walk.rs` 117〜124（`save_contract`。`public` の宣言のシグネチャで使った名前を集める）、`src/resolve/checks.rs` 13〜62（`check_declarations`。使った型・型クラス・エフェクトが非公開で同じモジュールなら E0329） |
| 型検査 | 公開を見ない（`src/typeck/` に `public` の参照はない） |
| ほかに `public` を読む箇所 | `src/cli/tools/package/effects.rs` 40（エフェクトの集計）、`src/cli/tools/skill/generate.rs` 259（標準ライブラリの文書の生成）、`src/cli/tools/formatter/roles/walk.rs` 415（整形） |

### 4.2 パッケージとモジュールの同一性

- `ModuleInfo { id, name: ModulePath, kind, imports }`（`src/modules/mod.rs` 22〜67）。`ModuleKind` は `Entry`・`Config`・`PackageConfig`・`User`・`Package`・`Prelude`・`Stdlib`（33〜48）。
- 依存のモジュールの名前は、依存の別名を先頭に付けた `ModulePath`（`src/modules/find.rs` 341〜347）で、種類は `ModuleKind::Package`（351〜357）。照合も先頭の段を別名として使う（`check.rs` 201〜212）。
- したがって「同じパッケージ」は、今あるデータだけで次のように判定できる（推測）: どちらも `Package` で名前の先頭の段（別名）が同じ、またはどちらも根の側（`Entry`・`User`）。根の `package.bnt` に `package` のブロックがあって自分の根で検査するときは、パッケージのモジュールは `User` として読まれるので、根の側の判定がそのまま「パッケージの中」になる。依存として読まれたときは `Package` になるので、二つの場合で判定が一致する。

### 4.3 パッケージの中だけの公開を入れるときの変更点（推測を含む）

- 判定の中心は `lookup.rs` の `children` である。ほかのモジュールを引くときに、同じパッケージなら「公開とパッケージの中の公開」の表を、違えば公開の表を引く。この表は `Resolver` の非公開の欄に置けるので、`ResolveOutput.exports` の意味を変えずに済む（`exports` を読むのは名前解決の中だけであることを確かめた）。
- `Binding.public: bool` は二値なので、三つ目の段階を持たせるには、`Binding` に欄を足すか（凍結の 10-04 の変更）、`Resolver` の非公開の集合で持つ。構成子・欄が型の段階を受け継ぐ必要がある（今は `public` を受け継ぐ）。
- 公開する契約の検査（`checks.rs` 20）は「`exposed.public` か、別のモジュールなら通す」という二値の判定である。三段階では、`public` の宣言がパッケージの中の型を使うと誤り、パッケージの中の宣言が非公開の型を使うと誤り、の二つに広げる。`save_contract`（`walk.rs` 118）は今 `public` の宣言だけを集めるので、パッケージの中の宣言も集める。E0329・E0330 の文言と修正案（`codes.rs` 496〜510）にもう一つの段階を加える。
- 書き方の候補と影響:
  - `public(package)` のように `public` を修飾する形: 予約語は増えない（`package` は 01-01 で予約しない語）。`parse_public` と `TopDecl.public`（凍結の 10-03）の形が変わる。`TopDecl.public` を `Some` のまま段階を別の欄で持つなら、`top.public.is_some()` を読む箇所（4.1 の表の最後の行と、`collect.rs` 320、`walk.rs` 118）をすべて見直す。整形（`formatter/roles/walk.rs` 415）も括弧を扱う。
  - 新しいキーワード（例: `internal`）: キーワードが 35 語になり、その語を識別子に使ったスクリプトが誤りになる。TODO-018 は、予約語を加える変更を互換性を壊す変更として 0.x のマイナーの版で `CHANGELOG` に移行の手順を書いて行うとし、構文の見直し（TODO-205）で扱うとしている。
  - 属性（例: `@package`）: 構文木を変えない（`attrs` に入る）。属性の名前の検査（`items.rs` 514・196〜197）に加える。`@deprecated` と同じ並びに置ける。
- 根（パッケージでないスクリプト）の扱いの候補:
  - (i) 根の側（入口とその根の下のモジュール）をすべて一つのパッケージとみなす。パッケージの中だけの公開は、根では `public` と同じ見え方になる（依存から根は見えないため）。
  - (ii) 根に `package` のブロックがあるときだけ許し、ないときは誤りか警告にする。
  - 入口のモジュールは取り込めないので、そこに書いたパッケージの中だけの公開は意味を持たない（今の `public` も同じ）。
- 凍結した型: `TopDecl`（10-03）、`Binding`・`ResolveOutput`（10-04）に触れる案がある。フェーズ 1 の plan.md の了承の表は、10-03 では先頭の部分の欄、10-04 ではモジュールの識別・探索の引数・`BindingKind` の列挙子・`ModuleKind` の列挙子だけを了承しており、公開の欄は含まない。触れるなら新たな了承が要る。`Resolver` の非公開の欄と属性で作る形なら凍結した型に触れない（推測）。
- 形式化: 07-04「01-12 との対応」の表で「初回リリース版の拡張: モジュール」は「対象外（入力の時点で一意な名前に消えている）」（07-04 の 148 行）、ファイルの先頭の部分と依存のパッケージのモジュールも対象外（149 行）。`formal/` の Lean のソースに `public` を扱う定義は見当たらなかった。公開の規則は形式化の範囲の外である。02-04 も「脱糖より後の段は、定義を束縛の番号で指すので、モジュールの名前と公開を扱わない」と書く（109 行）。

## 5. Unofficial の Hash・Regex・Json の今の実装

### 5.1 宣言と実装

| モジュール | 標準ライブラリのソース | 組み込みの実装 | 公開の関数 |
|---|---|---|---|
| `Hash` | `src/prelude/stdlib/Hash.bnt` | `src/builtins/funcs/hash.rs`（`sha2` クレート） | `sha256(b: Bytes) -> Bytes` の一つだけ |
| `Regex` | `src/prelude/stdlib/Regex.bnt` | `src/builtins/funcs/regex.rs`（359 行。`regex` クレート）、テスト `regex/tests.rs`（492 行） | `compile(String) -> Result[Pattern, String]`、`isMatch(Pattern, String) -> Boolean`、`find(Pattern, String) -> Option[Match]`、`findAll`、`matchText(Match) -> String`、`matchByteStart`・`matchByteEnd(Match) -> Integer`、`group(Match, Integer) -> Option[String]`、`namedGroup(Match, String) -> Option[String]`、`replaceFirst`、`replaceAll`、`split`、`replaceAllWith[effect E](..., f: function(Match) -> String uses E)` |
| `Json` | `src/prelude/stdlib/Json.bnt` | `src/builtins/funcs/json.rs`（861 行。`serde_json`、再帰しない変換） | `parse(String) -> Result[Value, ParseError]`、`stringify(Value) -> String`、`stringifyPretty(Value) -> String` が組み込み。`get`・`at`・`asString`・`asInteger`・`asFloat`・`asBoolean`・`asArray`・`asObject` は Benitoite で書いた関数 |

- `Regex` の `findAll`・`replaceAll`・`split`・`replaceAllWith` は、非公開の組み込みの `findAt`・`spanAt`・`maxStringBytes` を使って Benitoite で書いてある（`Regex.bnt` 60〜127）。一致を探す組み込みを、一致の数だけ呼ぶ。WASM に移すと、この呼び出しの数だけ境界を越える（推測）。`replaceAllWith` は利用者の関数を呼ぶので、WASM の側で完結しない。
- `Pattern` と `Match` は組み込みの中身を見せない型（2.3）。`Match` は一致した部分の文字列と捕獲の位置を持ち、`names` の表を `Pattern` と `Rc` で共有する（`regex.rs` 17〜33）。
- `Json.Value`（`Json.bnt` 4〜12）は `Null`・`Boolean(Boolean)`・`Integer(Integer)`・`Float(Float)`・`String(String)`・`Array(List[Value])`・`Object(Map[String, Value])` の再帰する型。タグは `tags::JSON_VALUE_*`（`src/builtins/table.rs`）。`ParseError` はレコード（`line`・`column`・`message`、`json.rs` 18〜23 の `parse_error` で欄の順を定める）。
- これらの組み込みは純粋な関数（`builtin!` の `pure fn`）である。

### 5.2 テストと測定の道具

- ゴールデン: `testdata/stdlib/l40-regex.bnt`、`testdata/stdlib/l40-json.bnt`、`testdata/stdlib/l40-encoding-hash.bnt`、`testdata/acceptance/json_summary.bnt`、`testdata/io/l40-json-total.bnt`、`testdata/network/todo194-json-parse-server.bnt`、`testdata/network/routes-and-post.bnt`。三つの実装が同じ結果を返すことを確かめる入力の材料になる。
- 単体テスト: `hash.rs` 20〜62（NIST の既知の値）、`regex/tests.rs`、`json.rs` 560 行以降。
- WASM のコンポーネントの作り方の例: `testdata/packages/libraries.files/fuzzy/`（`rust/`・`wit/`・`wasm/`・`README.md`。Rust 1.98.1、wit-bindgen 0.62.0、wasm-tools 1.261.0、`wasm32-unknown-unknown`）。手元の cargo のレジストリに `wit-bindgen-0.62.0` がある。
- 外部の関数のゴールデン: `testdata/external/`（17 件。`roundtrip` が各型の受け渡し、`aliased-result` が予算の超過）。`.wat` から `.wasm` を作り直すテスト `testdata_components_match_their_text`（`testdata/external/README.md`）。
- 性能の測定: `tools/bench/run.py`（`programs/` の `.bnt` と `.args.small`、`--verify` で出力を照合）、`tools/bench/gate.py`（fib と loop の交互の比較）、開発用の例 `examples/bench_run.rs`。Json・Regex・Hash のベンチマークのプログラムはまだない。記録の型板は `tools/bench/results/TEMPLATE.md`。手順はスキル `benchmark` に従う。

## 6. `benitoite package` のエフェクトの集計（R24）とパッケージの中だけの公開

- 集計は `src/cli/tools/package/mod.rs` 669〜672 で、パッケージの根の下のソースのファイルすべて（`source_files`。import で辿れるかを問わない）を構文解析し、`effects::Summary::collect`（`src/cli/tools/package/effects.rs` 16〜83）に渡す。型検査はしない（R24）。
- `collect` は `decl.public.is_none()` の宣言を飛ばし（40〜42）、`public` の関数・型クラスのメソッド・型の別名・レコード・`data` のシグネチャと `uses` から組み込みのエフェクトを集める。`@external` のコンポーネントは公開を問わず一覧に入れる（32〜39）。
- パッケージの中だけの公開を入れると、その宣言はパッケージを使う側から見えないので、集計から外すのが R24（「パッケージを使う側から見える関数だけを集計する」）に合う（推測）。外すには、書き方に応じて `effects.rs` 40 の判定を変える（`public(package)` なら段階を見る、属性なら属性を見る）。パッケージの中だけの関数のエフェクトは、それを呼ぶ `public` の関数の `uses` に現れる（エフェクトは宣言に書くので）ため、外しても見落としにはならない（推測。ハンドラで処理された場合は `public` の関数の型に現れないが、それは今の `public` でも同じ）。

## 7. 変えるべき文書の一覧

| 文書 | 節 | 関係する TODO |
|---|---|---|
| `docs/design/03-interop/03-10-external-functions.md` | 「宣言の形」（第 3 引数の形）、「照合」の手順 3（インターフェースの中の関数を指せない）、「型の対応」の表と「利用者の `data`、レコード、…リソース…は誤り」、「作り方の例」、「実行」（呼び出しごとに作り直す決定、予算の数え方） | 047・230・235・212 |
| `docs/design/02-impl/02-09-runtime.md` | 「実行ごとの状態」の表の「外部の関数の実行系」、「外部の関数の実行」（呼び出しごとの `Store`、上限の単位、予算、変換）、resource を言語のリソースにするなら「リソースの追跡」 | 047・230 |
| `docs/design/02-impl/02-08-vm.md` | 実行ごとの状態の表の「外部の関数の実行系」（66 行）、「外部の関数の呼び出し」（213 行〜） | 047 |
| `docs/design/02-impl/02-07-bytecode.md` | 外部の関数の表（25 行。変換表の中身） | 047・235 |
| `docs/design/01-spec/01-07-effects.md` | 「外部の関数のエフェクト」（純粋の根拠） | 047（resource） |
| `docs/design/01-spec/01-10-resources.md` | 「リソースの型」（利用者が定義できない）。外部のリソースを言語のリソースにするなら | 047 |
| `docs/design/07-quality/07-01-security-model.md` | 保証の表の「外部の関数」（53 行）、79 行 | 047 |
| `docs/design/01-spec/01-03-names-modules.md` | 「公開（初回リリース版）」 | 234 |
| `docs/design/01-spec/01-01-lexical.md` | 「キーワード」（キーワードを足すなら） | 234（018） |
| `docs/design/01-spec/01-02-syntax.md` | 宣言の構文（`public` の形を変えるなら）、外部の関数の宣言 | 234・235 |
| `docs/design/02-impl/02-04-resolver.md` | 「束縛と表」の公開の表（101 行）、「宣言の検査」の公開する契約（175 行）、「名前の引き方」（214 行）、「誤りと修正案」（224 行） | 234 |
| `docs/design/06-tooling/06-09-packages.md` | 「`benitoite package`」のエフェクトの集計 | 234 |
| `docs/design/02-impl/02-10-diagnostics.md` | 新しい診断コードを足すなら | 全般 |
| `docs/design/03-interop/03-08-text-and-data.md`（Hash・Regex・Json） | Hash・Regex・Json の WASM 版を試すだけなら変えない見込み（推測） | 212 |
| `docs/design/05-platform/05-01-distribution.md` | 外部の関数に関係するのは Wasmtime のビルドに C コンパイラが要るという記述（45 行）だけで、フェーズ 2 で変える箇所は見当たらない | — |
| `docs/reference/benitoite.md` | 21 節「Pure external functions through WASM」（1017 行〜。型の表、「functions inside exported interfaces cannot be selected」、「Records, user-defined data types, … resources … cannot cross」、「fresh component instances on every call」、予算の説明）、12 節「Modules」（549 行〜。公開） | 047・230・234・235 |
| `docs/ja/reference/` | 英語の版を変えたら、リリースのときに訳し直す | — |
| `crates/benitoite/skill/references/diagnostics.md` | 生成物。E0329・E0330・E1006・E1010 などの文言を変えたら `cargo run -p benitoite --example gen_skill` で作り直す | 全般 |
| `crates/benitoite/skill/references/grammar.md` | 生成物。構文の章を変えたら作り直す | 234・235 |
| `crates/benitoite/skill/SKILL.md`・`references/idioms.md` | 外部の関数に触れている（手で書く部分かは作業の前に確かめる） | 047・235 |
| `CHANGELOG.md` | Unreleased の節 | 全般 |

## 8. 気づいた点

- 03-10 と 02-09 は「呼び出しごとに作り直す」ことを、純粋な関数として型を付ける根拠と結果の再現性の理由にしている。resource を入れるとこの理由を書き直すことになるので、resource の単位（2.2 の (a)・(b)）を決める前に、純粋の保証をどう述べるかを設計者に尋ねる必要がある。
- 今の `Regex.Pattern` は言語のリソースの型ではなく中身を見せない型であり、TODO-047 の「Benitoite のリソースの型 ↔ WIT resource」という言い方と食い違う。`Regex` の WASM 版を今の `Regex` と同じ使い勝手にするなら、中身を見せない型に写すのが近い（2.3）。
- `Json.Value` は再帰するので、型の拡張（再帰なし案）を入れても `Json` の木はそのまま受け渡せない。C の実装は TODO-212 に挙がった三つの越え方（文字列、平らな節点の表、resource）のどれかになる。
- 速い経路の予算は、型付きの持ち上げなら `list<u8>` が 1 バイトにつき 1 を数える（1.5）。予算の値（256 MiB）を変えなくても、渡せる `Bytes` は約 6.7 MB から 256 MB 近くまで広がる（推測。引数の側の数え方は処理系が自分で決める）。

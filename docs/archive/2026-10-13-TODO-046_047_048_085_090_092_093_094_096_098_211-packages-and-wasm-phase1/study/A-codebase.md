# 調査 A: パッケージ管理と外部の関数（WASM）フェーズ 1 のための処理系の現状

- 対象: `san_benito`（`02b52fd7`、0.0.3）。行番号はこの版のもの。リポジトリのファイルは変えていない。ビルドとテストは走らせていない。
- パスは `crates/benitoite/src/` を `src/` と略す。
- 外部のライブラリ（Wasmtime など）については書かない（別の調査が受け持つ）。

---

## 1. モジュールの探し方（今の仕組み）

### 1.1 根のディレクトリの決め方

- `src/pipeline.rs:94-117` `entry_spec`: ディレクトリを指定したら `main.bnt` を補い、根は「読むファイルのあるディレクトリ」（親がなければ `.`）。設定ファイルは探さず、親も遡らない（ADR 0127 の決定 3・4。01-03 の 254 行も同じ）。
- `run`・`check` は `pipeline::check_path`（`pipeline.rs:151`）から `entry_spec` を通る。
- `test` はディレクトリを指定すると、その下の `.bnt` を**すべて**（再帰で）入口にし、根を指定したディレクトリにする（`src/cli/tools/test_runner/mod.rs:173-197`、集め方は `src/cli/tools/args.rs:113-134`。シンボリックリンクは辿らない）。
- 根の情報は `modules::EntrySpec { path, display_name, root }`（`src/modules/mod.rs:85-95`。10-04 で凍結）だけで運ぶ。

### 1.2 `import X.Y` からファイルへ（ADR 0126/0127 の時期のまま）

- 読み込みの段の入口: `modules::load_program`（`src/modules/mod.rs:182-189`、凍結 10-04:191）→ `load::load_with_limits`（`src/modules/load.rs:71-201`）。
  - FIFO の作業一覧。最初に入口、続けて prelude を置く（`load.rs:80-92`）。
  - 1 ファイルを読むたびに字句解析・構文解析し（`load.rs:134-136`）、各 import を `finder.find(import)` で解決して一覧に積む（`load.rs:140-154`）。
  - 既に積んだ名前は `scheduled: BTreeSet<ModulePath>`、読めた名前は `loaded: BTreeMap<ModulePath, ModuleId>` で管理する（`load.rs:86,94,155`）。**モジュールの同一性の鍵は `ModulePath`（段の並び）だけ**である。
  - 最後に循環を調べる（`load.rs:197-199`、`modules/cycle.rs`）。
- 利用者のモジュールの探し方: `src/modules/find.rs:35-136` `Finder::find`。
  - 段ごとに `list_dir` で大文字小文字まで正確に一致する項目を探す（`find.rs:51-92`）。
  - 正規化したパスが根の外なら `E0319`（`find.rs:103-114`）、入口自身なら `E0320`（`find.rs:115-123`）。
  - 種類は常に `ModuleKind::User`、`SourceKind::User`（`find.rs:130-135`、`load.rs:122-126`）。
  - **`Finder` は根を一つだけ持ち（`find.rs:12-18`）、`find` は「どのモジュールから import したか」を受け取らない**（`load.rs:142`）。パッケージの中のモジュールが、パッケージの根から相対に import する形は今は表せない。
  - 表示名は入口の表示名のディレクトリ部分に相対パスを続ける（`find.rs:124-133`）。

### 1.3 標準ライブラリ（`Benitoite.*`・`Benitoite.Unofficial.*`）の解決

- 先頭の段が `Benitoite` なら、ファイルシステムを見ずに埋め込みの表 `prelude::STDLIB`（`StdlibModuleSource`、`modules/mod.rs:69-83`）を引く（`find.rs:38-40`、`find.rs:138-232`）。
- 2 段目が `Unofficial` なら非公式の表の項目だけを、そうでなければ標準の項目だけを認める（`find.rs:139-153`）。見つからなければ `E0321`。根の直下に `Benitoite` という項目があれば注記 `root_file` を付ける（`find.rs:219-230`）。
- 名前解決では、import の別名・最後の段が `Benitoite` なら `E0325`（`src/resolve/imports.rs:39-47`）。
- 規範: 01-03 の 185・193 行「`Benitoite` で始まる名前は、常に標準ライブラリを指す」。

### 1.4 依存の別名の名前空間をつなぐ場所

`import Fuzzy.Distance` を「パッケージ Fuzzy の `Distance.bnt`」に解決するには、少なくとも次を変える。

| 箇所 | 今 | 要る変更 |
|---|---|---|
| `Finder::find`（`find.rs:35-40`） | 先頭の段が `Benitoite` か否かの二分 | 先頭の段が依存の別名なら、そのパッケージの根で同じ照合（`find.rs:51-123` の手順）を行う分岐を加える。`Benitoite` と同じく、別名の段は根の下のファイルより優先する規則にするのが今の規則と揃う |
| `Finder` の欄（`find.rs:12-18`） | 根が一つ | 依存の別名からパッケージの根（正規化したパス）への表を持つ |
| `find` の引数（`load.rs:142`） | import の宣言だけ | 「import した側のモジュールが属するパッケージ」を渡す。パッケージの中の `import Util`（または `import Fuzzy.Util`）を、そのパッケージの根で探すため。パッケージ自身の依存（依存の依存）の別名表もパッケージごとに要る |
| 根の外の検査（`find.rs:103-114`） | 入口の根だけ | パッケージのモジュールは、そのパッケージの根の下にあることを確かめる（例の `path "../packages/fuzzy"` は入口の根の外にある） |
| `ModulePath`（`modules/mod.rs:19-28`） | 段の並びだけ | パッケージを区別できる名前にする（例: 先頭にパッケージの印を持つ段、または別の欄）。今の `scheduled`・`loaded` の鍵、`ModuleTable::find`（`mod.rs:166-169`）、脱糖の名前（`ir/desugar/decls.rs:109-127` の `User => "{dotted}.{name}"`）がこれに依る |
| `ModuleKind`（`modules/mod.rs:31-42`、凍結 10-04:62） | Entry・User・Prelude・Stdlib | パッケージのモジュールを `User` のまま扱うか、新しい種類を足すか。`ModuleKind` を見ている箇所: `resolve/imports.rs:53`、`resolve/lookup.rs:179,191,227,397,458,662,694`、`resolve/collect.rs:211,233,243,296,392,460`、`ir/desugar/decls.rs:78,99,111`、`runtime/assert.rs:121,155`、`typeck/consts.rs:922`、`typeck/effects/handle.rs:57`、`modules/cycle.rs:21` |
| 依存の記述の読み取り | なし | 入口のファイルの先頭か根の直下の設定ファイルを、`load_program` の前（または入口を解析した直後）に読み、別名表を作る。パッケージの設定（`package.bnt`）も読む |

### 1.5 根の下の同じ名前のモジュールとの衝突

- 今は鍵が `ModulePath` だけなので、`Fuzzy` という依存の別名と、根の下の `Fuzzy/Distance.bnt` が両方あると、同じ鍵 `["Fuzzy","Distance"]` になり、`scheduled` で後から来た方が黙って捨てられる（`load.rs:144`）。パッケージを区別する名前に変えるか、衝突を誤りにするかを決める必要がある。
- `Benitoite` の前例（`find.rs:219-230` の注記、01-03 の 193 行）に倣うなら、「依存の別名の段は常に依存を指す。根の直下に同じ名前の項目があれば注記を出す（または誤りにする）」となる。
- 別名の束縛の衝突: import の最後の段（`Distance`）が束縛になる（`resolve/imports.rs:31-33`）。根のモジュール `Distance.bnt` と依存の `Fuzzy.Distance` を同時に import すると、今の規則どおり束縛の重なり（`E0305`）になり、`as` で避ける。新しい規則は要らない。
- 設定ファイルの名前が `.bnt` の場合（例の `project.bnt`・`package.bnt`）の衝突:
  - `import Project` で設定ファイルをモジュールとして取り込めてしまう（`find.rs` は名前の照合だけ）。除く規則が要る。
  - `test <dir>` は根の下の `.bnt` をすべて入口にするので（`args.rs:113-134`）、設定ファイルとパッケージの中のファイル（根の下に置いた場合）も入口として検査される。
  - `fmt <dir>` も同じ集め方なので、設定ファイルの構文を整形器が読めなければ誤りになる。

---

## 2. 属性と本体のない関数、`@external` の既存の記述

### 2.1 属性の表し方と解析

- AST: `TopDecl { attrs: Vec<Attribute>, public, item }`（`src/syntax/ast.rs:53-63`）、`Attribute { id, span, name: Name, args: Vec<StrArg> }`（`ast.rs:79-86`、凍結 10-03:347）、引数は補間なしの文字列リテラルだけ（`StrArg`、`ast.rs:88-93`）。`@external("wasm", "wasm/fuzzy.wasm", "distance")` は今の属性の形でそのまま表せる。
- `FnDecl { …, uses: Option<UsesList>, body: Option<Block> }`（`ast.rs:94-106`、凍結 10-03:363）。コメントは「`@builtin` を付けた宣言（標準ライブラリのソースだけ）は `None`」。
- 解析: `parse_module`（`src/syntax/parser/decls.rs:10-50`）が import の後のトップレベルで `items::parse_attributes`（`src/syntax/parser/items.rs:332-430`）を呼ぶ。
  - 名前の検査 `attribute_name_error`（`items.rs:431-471`）: 大文字なら `E0247`、`@doc` は `E0249`、利用者のソースの `@builtin` は `E0807`、`test`・`deprecated`・`builtin` 以外は `E0801`（知らない属性）。**今 `@external` を書くと `E0801` になる**（ADR 0139 の決定 6 のとおり）。
  - 引数の検査 `attribute_args_error`（`items.rs:472-486`）: `@builtin` は引数がちょうど 1 個。
  - 付けられる宣言の検査 `check_decl_header`（`items.rs:167-209`）: `test`・`builtin` は関数だけ（`E0802`）。
  - 重なり `E0803`、引数が文字列でない `E0220`（`items.rs:353-418`）。
- 本体の有無: `body_rule`（`items.rs:160-166`）が `@builtin` を付けたら `BodyRule::Omitted`。`parse_function`（`decls.rs:263-300`）は `Omitted` なら本体を読まず `None`、それ以外で本体がなければ `report_missing_body`（`items.rs:252-260`）が `E0808`（"the function `{name}` has no body"）。`body_rule` は `SourceKind` を受け取るが今は使わない（`_kind`）。
- 名前解決: `resolve/collect.rs:328-339` が `@builtin("名前")` の関数を `BindingKind::BuiltinFn(BuiltinId)` にする（`lookup_builtin` で静的な表を引く）。`BindingKind` は凍結（10-04:242）。
- 型検査: 本体のない関数は本体の検査を飛ばす（`typeck/generate.rs:87-90`）。型は宣言のシグネチャ（`uses` を含む）をそのまま信用する。

`@external` を入れるときの変更点（構文）: `attribute_name_error` に `external` を加える（利用者のソースで許す）、`attribute_args_error` に「3 個、1 個目は `"wasm"`」の検査、`check_decl_header` で関数だけに限る、`body_rule` で `Omitted` にする、`@builtin` との併用や `@test` との併用の禁止。

### 2.2 `external` の既存の記述

- `src/`: 該当なし（`external` の語は `runtime/sched` の「外部の待ち」、ヒープの大きさの計算など別の意味だけ）。
- `docs/design/`: `00-overview/00-04-glossary.md:159-160`（「初回リリース版は、外部の関数を呼ぶ層を持たない」）、`07-quality/07-01-security-model.md:7,73`（「外部の関数を呼ぶ層も、初回リリース版にはない」）、`08-appendix/08-03-language-surveys.md`（調査記録）。改造ではこれらの文を直す。ADR 0139 が関連章に挙げた `04-extensions/` の部は今の設計書にない（`docs/design/README.md:13` で欠番）。
- 予約: CLI のサブコマンド名 `package` は予約済み（`src/cli/mod.rs:73-76` の `RESERVED_COMMANDS`、使うと `RESERVED_COMMAND` の誤り）。

### 2.3 ADR 0139 の決定（`docs/archive/2026-10-09-design-first-release/decisions/0139-external-functions-via-wasm.md`）

1. 外部の関数の対象は WASM のモジュールの関数だけ。C の ABI の共有ライブラリを呼ぶ経路は設けない。
2. 本体のない関数の宣言に `@external("wasm", "モジュールのパス", "関数の名前")` を付けて宣言する。1 個目は対象の種類で、今は `"wasm"` だけ。
3. モジュールのパスは根のディレクトリからのパスとし、根の下に限る（import と同じ）。
4. WASM が外に作用できるのはホストの関数だけで、ホストの関数は標準ライブラリの IO の操作であり IO 実行器を通る。外部の関数の型のエフェクトは、取り込むホストの関数のエフェクトを含まなければならない。何も取り込まない関数は純粋な関数として宣言できる。
5. 外部の関数のための新しいキーワード・エフェクト・権限の種類は設けない。
6. 初回リリース版は `@external` を知らない属性として誤りにする。値の対応・失敗の扱い・ホストの関数の範囲・実行環境は後で決める。

却下した案: キーワード `external function`（予約語を増やす。ADR 0093 の例外になる）、C の ABI（IO 実行器を通らず権限制御が保証にならない）、専用のエフェクト `Foreign.Call`（WASM ならホストの関数のエフェクトで表せる）、処理系に組み込んでビルドし直す経路。

関連: ADR 0154（公開する契約の型に `uses` のエフェクトも含め、非公開の型・エフェクトを使うと誤り）、ADR 0156（import を辿って読み、プログラム全体を一つの単位として検査する。根の下でも辿れないファイルは読まない）、ADR 0127（ディレクトリ指定は `main.bnt`、根は入口のディレクトリ、設定ファイルを設けない・親を遡らない。根を設定ファイルで指定する仕組みはパッケージ管理とあわせて決める、と帰結に書いてある）。

---

## 3. 組み込みの関数の経路（宣言から VM まで）

### 3.1 経路

1. **型**: 標準ライブラリの `.bnt`（`src/prelude/stdlib/`）に `@builtin("Hash.sha256")` 付きの本体のない関数を書き、そのシグネチャ（`uses` を含む）が型になる。表の側にも `table::builtin_scheme` がある（演算子など宣言のない項目用）。
2. **名前解決**: `@builtin` の文字列で `builtins::lookup_builtin`（`src/builtins/table.rs:82-`）を引き、`BindingKind::BuiltinFn(BuiltinId)`（`resolve/collect.rs:328-339`）。表にない名前は処理系の不具合扱い。
3. **脱糖**: `ir/desugar/exprs.rs:150,893` → `Desugar::builtin`（`src/ir/desugar.rs:278-308`）がコア IR の `ValKind::Builtin { id: BuiltinId, targs, info: BuiltinInfo }` を作る（`src/ir/core_ir.rs:133-137`、`BuiltinInfo` は `core_ir.rs:101-113`。`class: Capability` を `builtin_decl(id).capability` から写す）。コア IR は凍結（10-06:202）。
4. **コード生成**: `bytecode/codegen/tables.rs:285-310` が `BuiltinId` ごとに `BuiltinRef { id, arity, capability, op }`（`src/bytecode/program.rs:236-244`、凍結 10-07:761）を `CompiledProgram::builtins`（`program.rs:256-275`、凍結 10-07:780）に一つ置く。命令は `PRIM`（純粋・State）か `IO`。
5. **VM**: `execute_builtin`（`src/vm/dispatch.rs:884-924`）が `program.builtin(idx)` を引き、`Io` なら要求として IO 実行器へ（`tasks::io::publish`、`dispatch.rs:953-975`）、純粋なら `invoke_pure`（`dispatch.rs:926-948`）で `builtin_decl(reference.id)` の `raw` を `CallCtx::new(ctx, None, None, Some(at))` で呼ぶ。State は `tasks::dispatch`（`dispatch.rs:977-1001`、`vm/dispatch/tasks.rs:427`）。
6. **参照インタプリタ**: `refinterp/convert.rs:84-90` も `builtin_decl(id)` で同じ包みを呼ぶ。ゴールデンテストの差分（`tests/golden/differential.rs`）で VM と比べる。

### 3.2 登録の表は静的

- `BuiltinId(pub u16)`（`src/builtins/mod.rs:10-12`）は表の中の位置。`builtin_decl`（`table.rs:69-80`）は `funcs::PARTS`（各モジュールの `const DECLS: &[BuiltinDecl]`）を順に数えて引く。**すべてコンパイル時に決まる `'static` の表**であり、実行中に足す口はない（`table.rs:1-2` のコメント「初期化の後に変更しないので const か関数で表す」）。
- `BuiltinDecl { name: &'static str, capability, arity: u16, raw: RawFn }`（`src/builtins/iface.rs:646-654`、凍結 10-11:627）、`RawFn = for<'c,'e> fn(&'c mut CallCtx<'c,'e>, &[Value<'e>]) -> Result<Reply<'e>, Stop>`（`iface.rs:644`）。`raw` は環境を捕えない `fn` ポインタで、`builtin!` マクロ（`iface.rs:671-`）が作る。
- 純粋な関数の文脈 `CallCtx::new(ctx, None, None, at)` は IO の口も State の口も持たない。実行ごとの状態（WASM のインスタンスなど）に触れる手段がない。
- 実行時エラーの `RuntimeError::ArgumentOutOfDomain { function: &'static str, .. }`（`src/runtime/mod.rs:69-72`）など、関数の名前を `&'static str` で持つ型がある。外部の関数の名前は実行時に決まるので、報告に名前を出すなら型を変える必要がある。
- `Stop` は `Runtime`・`Resource`・`Internal` の三つ（`runtime/mod.rs:110-115`、凍結 10-08:170）。WASM のトラップを実行時エラーにするなら `RuntimeError` に種類を足す（01-08「実行時エラーによる停止」の表と診断の `R` コードも足す）。

### 3.3 プログラムごとの外部の関数を呼べるようにする案（調べた範囲で言えること）

| 案 | 内容 | 変える凍結の型 |
|---|---|---|
| A. 外部の関数の専用の経路 | 名前解決に `BindingKind::ExternalFn(番号)`、コア IR に `ValKind::External { … }`、`CompiledProgram` に外部の関数の表（コンポーネントのパス、関数名、引数と戻り値の型の変換表）と、命令（新しい opcode か `PRIM` の B の解釈の拡張）を足す。VM は実行ごとの状態に置いた WASM の実行系を引いて呼ぶ | `BindingKind`（10-04）、`ValKind`/コア IR（10-06）、`CompiledProgram`・`Opcode`（10-07）、場合により `RunState`（10-09）。`bytecode::verify`、`disasm`、`liveness`、`ir/check.rs`、`ir/decision.rs`、`bytecode/codegen/analysis.rs`・`emit.rs`、`refinterp/eval.rs`・`index.rs` も対応が要る |
| B. 一つの組み込みの関数で中継する | 静的な表に `%external`（仮）を一つ加え、脱糖で `@external` の関数の呼び出しを「外部の関数の番号 + 引数」の呼び出しに変える。可変の引数の数は、引数をリスト等にまとめるか、引数の数ごとに項目を足す | `BuiltinDecl.arity` が固定なのでまとめ方が要る。純粋な文脈から実行ごとの WASM の状態に届かないので、`CallCtx`（10-11）に口を足すか、`State`・`Io` の権限で呼ぶ必要がある。`Capability` が `Pure` でない呼び出しは型のエフェクトと食い違う（`Capability::State` は `State` のエフェクトを持つ関数の印として使われている、`ir/core_ir.rs:102`） |

どちらの案でも次は共通である。

- 外部の関数の表はコンパイル済みプログラムに置き、実体（読み込んだコンポーネント、インスタンス）は実行ごとの状態に置く。大域の可変状態は禁じられている（AGENTS.md「大域の状態」。例外は 4 つだけ）。`CompiledProgram` は `Send + Sync` を要する（`program.rs:376-379` の `assert_shareable`）。
- コンポーネントの読み込みと WIT の型の照合（宣言の型との突き合わせ、取り込みが空かの判定）は、検査（`check`）の段で行うのが「静的に検出できる誤りは実行前に報告する」（原則 1）に合う。今の段は「読み込み → 名前解決 → 型検査」（`pipeline.rs:249-300`）なので、型検査の後に「外部の関数の照合」の段を足すか、型検査の中で行う。
- 過去の改造は、凍結した型を変えるときに改造の実装プランで変えてよい項目を列挙している（例: `docs/archive/2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics/plan.md:16`、`docs/archive/2026-10-12-TODO-170_179_209_221-diagnostics-and-test-gaps/plan.md:16`）。この改造でも、変える凍結の型（上の表）を実装プランに列挙する必要がある。

---

## 4. 中断と予算（WASM の呼び出しを揃えるための現状）

### 4.1 VM の切り替えと中断の印

- 切り替えの位置は「関数の値かメソッドを呼ぶ命令」（`CALL`・`TAILCALL`・`METHOD`・`TAILMETHOD`、`HANDLE`・`FORCE`・`UPDATE`、`PERFORM`・`IO`）。呼ぶ前に (1) 中断の印を `Relaxed` で読む、(2) 予算を 1 減らす、(3) 0 なら遅い経路（回収・取り消し・切り替え）（設計書 02-08「タスクの切り替え」、`docs/design/02-impl/02-08-vm.md:264-293`）。
- 実装: `src/vm/dispatch.rs:1159-1167`（`interrupt` の `AtomicBool` を読み、立っていれば `interrupt_call`（`dispatch.rs:296-`）、`state.budget.tick()` が偽なら `call_slow_path`）。予算は `src/vm/budget.rs:16-80`（初めの値 2,500 回）。
- 待ち行列が空のときの待ちでも印を読む（`src/vm/dispatch/tasks.rs:288-305`）。`main` が値で終わった後に一度読む（`src/runtime/run.rs:395`、TODO-201 の Q2）。
- 印の実体は `src/runtime/run/interrupt.rs`（`signal_hook` で `SIGINT`・`SIGTERM` を受けて `AtomicBool` を立てる。大域の状態の例外の一つ）。
- **`PRIM` と演算の命令の途中では切り替えず、印も読まない**（02-08 の 291 行）。純粋な組み込みの関数は 1 回の呼び出しが終わるまで VM に戻らない。

### 4.2 TODO-201（Regex）で長い照合を止められるようにした仕組み

- 記録: `docs/archive/2026-10-11-TODO-185_201_202-regex-and-http-details/decisions.md` の Q1・Q2、`study-201.md` の 3.1・3.2 節。
- 仕組みは **VM を変えず、長い仕事を「1 回の呼び出しで 1 件だけ探す」非公開の組み込みの関数（`Regex.findAt`・`Regex.spanAt`）に分け、繰り返しを標準ライブラリの `Regex.bnt` の再帰（末尾呼び出し）で書く**こと。一致の間に必ず `CALL`/`TAILCALL` を通るので、そこで中断の印・予算・取り消しが効く。
- 採らなかった案（`study-201.md` 3.1「採らない案」）: 組み込みの関数の中で中断の印を調べる（純粋な文脈は印を持たない。`PureCtx` は `ValueCtx` だけ。応答は完了・待つ・起動・終了だけで、組み込みの関数の中から切り替えは起こせない）、作業用のスレッドに移す・時間で止める（取り消しても裏で CPU を使い続ける、結果が実行ごとに変わる）。
- 1 回の探索そのもの（病的な正規表現）は今も止められない。

### 4.3 WASM の呼び出しを揃えるときに当たる点（事実だけ）

- WASM の 1 回の呼び出しは `PRIM` と同じく VM に戻らない。止めるには、(a) 呼び出しの途中で VM に戻す仕組み（WASM の実行を途中で止めて後で続ける）か、(b) WASM の側の打ち切り（打ち切ったら実行時エラーか取り消しとして扱う）が要る。
- VM が呼び出しを途中で止めてタスクを切り替える既存の形は「待つ」応答（`Reply::Wait(WaitRequest)`、`src/builtins/iface.rs:138-143`）だけで、これは `Io`・`State` の権限の関数にしか許されない（`invoke_pure` は `Wait` を処理系の不具合にする、`dispatch.rs:942-947`）。作業用のスレッドへ渡す仕事は `Send + 'static` で言語の値を含めない決まりがある（AGENTS.md「組み込みの関数の書き方」）。
- 中断の印は VM の側では `Option<&AtomicBool>` で手元にある（`dispatch.rs:1159`）ので、WASM の打ち切りの判定に同じ印を渡すことはできる（大域の状態を増やさずに済む）。

---

## 5. エフェクト: 本体のない宣言の `uses` と「State を持つ関数はハンドラで除けない」

### 5.1 本体のない宣言の `uses`

- 型検査は宣言のシグネチャをそのまま型にする（`typeck/generate.rs:87-90` で本体の検査を飛ばす、`typeck/decls.rs:440-454` で `BuiltinFn` を `Fn` と同じに扱う）。`uses` が本体と合うかを確かめる手段はない（本体がない）。
- 組み込みの関数の `uses` と権限（`Capability`）の一致は、実行時でも検査の段でもなく、単体テスト `table_names_parts_capabilities_and_schemes_are_consistent`（`src/builtins/table.rs:492-`）だけが確かめる。
- 外部の関数では、「宣言の `uses` ⊇ コンポーネントの取り込みから求めたエフェクト」を読み込みのときに検査する新しい検査が要る（ADR 0139 の決定 4、メモの 2.3）。フェーズ 1 は取り込みが空のものだけなので、どの `uses` でも包含は成り立つ（純粋な宣言を求めるか、多めの `uses` を許すかは決めごと）。取り込みが空でないコンポーネントを誤りにすれば、フェーズ 1 は照合の表を持たずに済む。

### 5.2 「State を持つ関数はハンドラで処理できない」の実装

- 規範: 01-07 の 46・185・288 行。`State` は操作を持たないエフェクトで、`State` を型に持つ関数（セル、タスクの集まり、`Task.await`、解放の関数）を節の `case` に書くと誤り。
- 実装（`src/typeck/effects/handle.rs`）:
  - 節の `case` の名前が `BindingKind::Op` でなければ `E0507`（"is not an operation of an effect"）。標準ライブラリの関数で型に `State` を持つなら注記 `state` を付ける（`handle.rs:27-68`）。つまり「State を持つ関数」が除けないのは、**それが操作ではなく、`State` が操作を一つも持たないから**であり、専用の禁止の規則があるわけではない。
  - ハンドラが型から除くエフェクトは、「操作が 1 個以上あり、そのすべての操作の節を書いたエフェクト」（`handle.rs:167-172`）。本体のエフェクト ⊆ 除いたエフェクト ∪ 節のエフェクト、の制約を足す（`handle.rs:173-180`）。
- 外部の関数への当てはめ:
  - 外部の関数そのものは操作ではないので、`case Distance.distance(..)` は今の規則のまま `E0507` になる。
  - 問題はフェーズ 2 以降（取り込みのあるコンポーネント）で、`uses File.Read` の外部の関数を呼ぶ本体を `handle … with case File.readText …` で包むと、今の規則（`handle.rs:167-172`）は `File.Read` を型から除く。WASM の中のホストの関数の呼び出しは節に渡らないので、保証が破れる（メモの 2.4）。塞ぐには、外部の関数の呼び出しから来たエフェクトを、ハンドラが除けない形で型に残す仕組みが要る（例: 推論の中で外部の関数のエフェクトに印を付ける、`State` のように操作を持たない別の名前のエフェクトとして扱う、など）。これは型の規則の変更なので、形式化した範囲（7. 節）に触れる。
  - フェーズ 1（純粋な外部の関数だけ）では、この規則がなくても保証は破れない。

---

## 6. 形式化（07-04「01-12 との対応」）との関係

`docs/design/07-quality/07-04-formal-semantics.md:130-163`。該当する行を写す。

> | 初回リリース版の拡張: モジュール | 対象外（入力の時点で一意な名前に消えている） | |

> | 末尾呼び出しの保証、置き換えてよい等式 | 対象外 | |

組み込みの関数は形式化の中で中身を定義せず、「形式化で仮定するもの」（`07-04:82-121`）の仮定として扱う。その表の行の一部:

> | δ の型の保存 | 型 `(Ā) → B ! ε` の IO を行わない組み込みの関数 `b[T̄; Ē]` に、置き換えた型 `Āθ` の値を渡すと、`δ(b[T̄; Ē], W̄)` は定義されていて、型 `Bθ` の値か `error(r)` を返す（θ = [T̄/ᾱ, Ē/ρ̄]） | 「実行の規則」の E-Prim・E-Err |

> | 組み込みの関数のエフェクト | IO を行う組み込みの関数の型のエフェクトは、組み込みのエフェクトの名前（段階 A では `IO`）を含む | 性質 3 が IO の事象の不在を型から導くための前提 |

> | 組み込みのエフェクトの操作 | IO を行う組み込みの関数とプロセスの終了の関数は、組み込みのエフェクト L の操作であり、型のエフェクトは `{L}` だけで、エフェクト変数を持たない。（後略） | 「ハンドラ」の（後略） |

また、段階 E2 の行は「処理系の書き出しから表層の構文への変換、標準ライブラリの宣言、原子の集合が入力の原子をすべて含むことは、信頼する前提である」と書く。

判断の材料:

- **依存の記述の構文**（`language`、`dependency … end dependency`、設定ファイル）: モジュールの読み込みの前の情報で、コア計算に現れない。「モジュール」の行と同じく**対象外**とし、表に行を書き足す形になる（07-04:163 の決まり「範囲の外なら表に『対象外』の行を加えるか、既存の行に要素を書き足す」）。
- **`@external` の宣言**: 本体のない関数で、呼び出しはコア IR の上で組み込みの関数 `b[T̄; Ē]` と同じ形（値を返すか `error(r)`）にできる。フェーズ 1 の純粋な外部の関数は「δ の型の保存」の仮定の下に入る（型が合うことは WIT との照合で保証する、という前提を仮定に足す）。コアの構文や型付けの規則を変えないなら、表の内側の規則には触れず、仮定の表に「外部の関数」を書き足す扱いになる。型パラメータを持たない宣言に限れば「組み込みの関数の型の変数」の仮定も自明に成り立つ。
- ただし 5.2 の「外部の関数のエフェクトはハンドラで除けない」規則（フェーズ 2 以降）は「ハンドラ」（段階 B1）と性質 3（エフェクトの健全性）に触れる。フェーズ 1 で入れるなら Lean の定義を先に直す対象になる。
- Lean と処理系の差分テスト: `scripts/check-formal.sh` は `tests/desugar_export.rs`・`tests/coverage_export.rs` で処理系の脱糖と網羅性の判定を書き出して Lean と比べる。組み込みの関数の対応表は `crates/benitoite/tests/desugar_export/builtins.rs` にある。外部の関数を含むプログラムを書き出しの対象から外すか、表に対応を足す必要がある。

---

## 7. CLI

- サブコマンド: `Command`（`src/cli/mod.rs:52-71`、凍結 10-13:514）は `Run`・`Check`・`Tool { tool: ToolCommand, args }`（`test`・`fmt`・`skill`）・`Help`・`Version`・`Licenses`。振り分けは `parse_args`（`cli/mod.rs:160-`）。`test`・`fmt`・`skill` は `ToolCommand` として `tools::run_tool`（`src/cli/tools.rs:11-`）へ渡す。
- `package` は予約済みの名前（`cli/mod.rs:73-76`、06-01「予約したサブコマンドの名前（初回リリース版）」）で、今は `RESERVED_COMMAND` の誤りになる。`benitoite package …` は `ToolCommand` に `Package` を足して `tools::run_tool` に振り分け、`src/cli/tools/package/` に置くのが今の形に揃う（`skill` が同じ形）。`RESERVED_COMMANDS` から `package` を外す。
- 根の見つけ方: `run`・`check` は `pipeline::entry_spec`（1.1 節）、`test` は `test_entries`（`test_runner/mod.rs:173-197`）。`test <dir>` は根を指定したディレクトリにし、その下の `.bnt` をすべて入口にする。設定ファイルを根の直下でだけ見る規則にすると、`test <dir>` の各入口は同じ根（指定したディレクトリ）を持つので設定ファイルの位置は一つに決まる。一方、`run sub/x.bnt` は根が `sub/` になり、プロジェクトの設定ファイルを見ない（メモの 3.1 の「サブディレクトリの単体のスクリプトは別の根」と一致）。

---

## 8. 診断のコード

- 表: `src/diag/codes.rs`（`diag_codes!` のマクロ）。区分は設計書 02-10「診断コード」（`docs/design/02-impl/02-10-diagnostics.md:93-125`）。番号は区分の続きから振り、廃止した番号（`RETIRED`、`codes.rs:25-27`: E0111・E0117・E0205・E0307・E0308・E0317・E0444）は使い回さない。文言は英語で表に置き、説明（`explanation`）から同梱の Skill の診断の文書を作る（`gen_skill` で作り直す）。
- 区分ごとの最大の番号（`codes.rs` に現れるもの。廃止を含む）:

| 区分 | 内容 | 最大 | 次に振る番号 |
|---|---|---|---|
| E01 | 読み込みと字句 | E0125 | E0126 |
| E02 | 構文（属性の書き方を含む） | E0251 | E0252 |
| E03 | 名前、import、公開 | E0339 | E0340 |
| E04 | 型 | E0444（廃止） | E0445 |
| E05 | エフェクト、ハンドラ | E0510 | E0511 |
| E06 | パターン | E0609 | E0610 |
| E07 | 型クラス | E0715 | E0716 |
| E08 | 属性 | E0808 | E0809 |
| W03 / W04 / W05 | 警告 | W0301 / W0403 / W0501 | W0302 / W0404 / W0502 |
| R01〜R10 | 実行時エラー | R0103, R0202, R0301, R0402, R0502, R0701, R0801, R0903, R1002（R06 は未使用） | — |
| L01 | 処理系の制限 | L0112 | L0113 |

- 使い道の見込み: 依存の記述・設定ファイル・パッケージの探索の誤りは E01（読み込み）か E03（import）、依存の記述の構文は E02、`@external` の属性の誤りは E08、WIT との型の照合・取り込みのエフェクトの照合は E04/E05 か新しい区分。上 2 桁の未使用は `E09nn` 以降（パッケージと外部の関数の区分を新設する余地）。実行時のトラップは R の新しい区分（`R06` は空き、`R11` 以降も空き）。新しい区分を足すなら 02-10 の表に行を足す。

---

## 9. ライセンスと依存の方針

- 設計書 03-01「使う Rust のクレート」（`docs/design/03-interop/03-01-library-structure.md:44-75`）: 用途ごとの表にクレート・リポジトリ・ライセンスを書く。依存は C のコードを含まず Rust のツールチェーンだけでビルドできる、という性質を書いている（`03-01:75`）。依存のクレートが内部に持つ大域の状態もここに書く決まり（AGENTS.md「大域の状態」、`03-01:60` の jiff の例）。
- 03-01「依存のライセンス」（`03-01:77-83`）: 許可は MIT・Apache-2.0・BSD-2-Clause・BSD-3-Clause・ISC・Zlib・0BSD・Unicode-3.0。Unlicense は MIT と選べるときだけ。コピーレフトは不可。OR の選択肢に許可外が混ざるときは許可の側を選ぶ。依存を加えるときは `cargo deny` で確かめ、要るものだけ `deny.toml` に足す。配布物に第三者のライセンスの表示を同梱する（05-01）。
- `deny.toml`（リポジトリの根）: `[licenses] allow = ["MIT", "Apache-2.0", "ISC", "BSD-3-Clause"]`、`[graph] targets = ["aarch64-apple-darwin", "x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl"]`。
- `scripts/check.sh`: 検査 `licenses`（`check.sh:70-77` で `cargo deny check licenses`）。`Cargo.toml`・`Cargo.lock`・`deny.toml`・`about.toml`・`about.hbs`・`crates/*/Cargo.toml` を変えると選ばれる（`check.sh:188-190`）。cargo-deny がなければ止まる。
- 第三者のライセンスの埋め込み: 機能 `bundled-licenses`（`crates/benitoite/Cargo.toml` の `[features]`）、`benitoite --licenses`（`src/cli/tools/licenses.rs`）。
- 依存の数: 直接の依存は 17（`crates/benitoite/Cargo.toml` の `[dependencies]`。版は `=` で固定）。`cargo tree -p benitoite -e normal` の重複を除いた行は 64。`Cargo.lock` の `name =` は 110（ワークスペースと開発用の依存を含む）。
- 実行ファイルの大きさ:
  - 記録: `tools/bench/results/2026-10-08-l-merge-2c1a979.md`。L 系の取り込みの後（`2c1a979`）で `benitoite` 11,159,488 B、strip した後 9,162,048 B（Apple M4、rustc 1.98.1）。依存のうち `graviola` の機械語が 1,156 KiB で最大。設計者はこの増え方を許容範囲とした（2026-10-08）。
  - 手元の `target/release/benitoite` は 12,088,096 B（2026-10-12 20:07 のビルド。どの版のビルドかは確かめていない）。
  - `[profile.release]` は `overflow-checks = true`、`panic = "unwind"`（根の `Cargo.toml:29-31`）。

---

## 10. 変わるモジュールと変更の大きさの目安

行数は今の本番のコード（テストを除く）の行数。見積もりは調べた範囲からの粗い目安で、WASM の実行系を包む部分（別の調査）の大きさは含めない。

| 領域 | 今の行数 | 変えること | 目安 |
|---|---|---|---|
| 構文（`syntax/parser`、`ast.rs`、`token.rs`） | 9,059 | `@external` の属性の受け入れと検査（2.1 節）。依存の記述・言語の版の宣言の構文（入口の先頭と設定ファイル）。`dependency`・`language`・`package` などはキーワードでないので（`token.rs` のキーワードは 34 語）、文脈で読む語として扱うか、予約語を足すか（ADR 0093 の方針との関係）。`end dependency` の閉じ方。取り込まれるモジュールに書いたら誤り | 中（300〜600 行） |
| 読み込み（`modules/`） | 1,051 | 依存の別名表、パッケージの根ごとの探索、`find` に import した側の情報、根の外の検査の対象、`ModulePath` のパッケージの区別、設定ファイルの読み取りと「二か所に書いたら誤り」、パッケージの言語の版の照合、依存のハッシュの確かめ（フェーズ 1 で手元のパスにも行うか）、設定ファイルを import できないようにする | 大（今の倍近く。600〜1,000 行） |
| パイプライン（`pipeline.rs`） | 約 300（テスト除く） | 段の追加（外部の関数の照合）、`CheckedProgram`/`EntrySpec` に依存の情報 | 小〜中 |
| 名前解決（`resolve/`） | 3,501 | `@external` の関数の束縛（`BindingKind` に種類を足すか）、パッケージのモジュールの扱い（`ModuleKind` を見る 15 箇所ほど） | 小〜中 |
| 型検査（`typeck/`） | 11,772 | 外部の関数の宣言の型の制限（型パラメータなし、WIT と対応する型だけ。メモの 4 章の表）、`uses` の照合（フェーズ 1 は取り込みが空なら純粋）。ハンドラで除けない規則はフェーズ 2 以降 | 小〜中 |
| 中間表現・脱糖（`ir/`） | 10,268 | 外部の関数の呼び出しの節点（3.3 節の案 A）か、中継の組み込みの関数への変換（案 B）。`ir/check.rs`・`decision.rs` の対応 | 小〜中 |
| バイトコード（`bytecode/`） | 6,368 | 外部の関数の表と命令、`verify`・`disasm`・`liveness`・`codegen` | 中 |
| VM（`vm/`） | 10,978 | 外部の関数の呼び出し（純粋な経路の外に出す）、中断・予算との揃え（4.3 節） | 中 |
| ランタイム（`runtime/`） | 17,195 | 実行ごとの WASM の状態の持ち方、トラップ・メモリ不足を実行時エラー/資源の不足にする（`RuntimeError` と報告） | 中 |
| 組み込みの関数（`builtins/`） | 18,009 | 案 B なら中継の項目、値の変換（Benitoite の値 ↔ WIT の値。メモの 4 章の対応表）。値を作る前に大きさを確かめる決まり（AGENTS.md）に従う | 中 |
| 参照インタプリタ（`refinterp/`） | 3,000 | 外部の関数の呼び出し（差分テストのため） | 小 |
| CLI（`cli/`） | 5,859 | `package` のサブコマンド（先頭の記述を設定ファイルへ移す命令など）、`test`/`fmt` のディレクトリ走査から設定ファイルとパッケージを除く、整形器が新しい構文を整形する（`cli/tools/formatter`） | 中 |
| 診断（`diag/codes.rs`） | 1,088 | 新しいコード（読み込み、構文、属性、照合、実行時） | 小（ただし Skill の診断の文書の作り直しが要る） |
| 新しい依存 | — | WASM の実行系のクレート。`deny.toml`、03-01 の表、第三者のライセンスの表示、実行ファイルの大きさの記録 | 別の調査 |
| 設計書 | — | 01-02（属性、依存の記述）、01-03（モジュールの名前、根、依存の名前空間）、01-07（外部の関数のエフェクト）、01-08（トラップの実行時エラー）、02-01〜02-10 の該当節、03-01、05-01、06-01（`package`）、06-03（整形）、06-04（テストのディレクトリ走査）、07-01（条件 3、71〜75 行）、07-04（対応表・仮定の表）、00-04（用語）。外部の関数の章を新しく置くなら、欠番の 04 の部の番号は使い回さない決まり（`docs/design/README.md:13`） | 大 |
| テスト | — | ゴールデンテスト（WASM のコンポーネントのテスト用の資料をリポジトリに置く方法を含む）、`spec_examples`、`reference_examples`、Skill の文書、`tools/spec-coverage` | 中〜大 |

補足:

- `@builtin` の経路は名前・権限・引数の数をすべて静的な表で決める作りで（3.2 節）、外部の関数は「実行時に読み込む表」を初めて持ち込むことになる。凍結した型のうち変えるものを実装プランで列挙する必要がある（3.3 節）。
- 標準ライブラリの警告は `SourceKind::Prelude` のソースだけ除く（`pipeline.rs:302-311`）。パッケージのソースを `SourceKind::User` のまま読むと、パッケージの中の警告も利用者に出る。`--deny-warnings` で依存の警告が誤りになるかも決めごとになる。
- テストの実行器・`Assert` の解析は `Entry | User` のモジュールを辿る（`runtime/assert.rs:121,155`）。パッケージのモジュールを `User` にすると、ここにも含まれる。

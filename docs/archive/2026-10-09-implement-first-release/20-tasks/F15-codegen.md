# F15 コード生成の拡張

- 依存する作業: [F11](F11-desugar.md), [F12](F12-decision-tree.md), [R05](R05-liveness-and-asm.md), [R09](R09-vm-core.md)
- 難易度: 5（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）（テストを含む Rust の行数の目安）
- ブランチ: impl/F15-codegen

## 目的

初回リリース版の下位 IR から、10-07 の命令の集合でコンパイル済みプログラムを作る（02-07「コード生成」）。最小実行版の言語の分に加えて、レコード、辞書とメソッドの呼び出し、`handle`・`resume`・`escape`、`lazy` と `Lazy.force`、`Reference.update`、`with` の解放の枠、`Decimal`・`Byte` の演算、リストのパターンの取り出し、定数の記述を移す。原型をすべて作った後に、R05 の `compute_liveness` で原型ごとの生存の情報を埋める。あわせて、逆アセンブラに段が 2 の命令を加える。

コード生成は U1 と U2 の境目である。第 1 段の VM（R09）は段が 1 の命令だけを実行するので、最小実行版の言語の範囲のプログラムが段が 1 の命令だけに移ることを、本作業のテストで確かめる（10-07「第 1 段で実行するプログラム」）。C05 は、この性質を前提に、書き直した最小実行版のテストを第 1 段の VM に通す。

R09 に依存するのは、段が 1 の命令に移るプログラムを第 1 段の VM で実行して確かめるテストに使うからである。段が 2 の命令は、VM が実行するのが第 2 段（R20 以降）なので、本作業では命令の並び・表・生存の情報の形で確かめる。

## 読む設計書の節

- [バイトコードとコード生成](../../2026-10-09-design-first-release/02-impl/02-07-bytecode.md)の全体（「コンパイル済みプログラム」「原型の名前と由来の種類」「命令」「コード生成」「関数の境界」「演算子の移し方」「分岐と合流の並べ方」「値の移し方」「その場での再利用」「定数表」「レジスタの割り当て」「関数の値と捕捉」「辞書とメソッドの呼び出し」「末尾呼び出し」「処理系の制限」）
- [中間表現と脱糖](../../2026-10-09-design-first-release/02-impl/02-06-ir-and-lowering.md)の「判定の木への変換」「下位 IR からコード生成へ渡すもの」
- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「枠の種類」「実行の手順」「明示遅延」「可変のセル」「リソースの解放の枠」「ハンドラと継続」（命令が VM で何をするか）
- [コア計算と脱糖](../../2026-10-09-design-first-release/01-spec/01-12-core-calculus.md)の「末尾呼び出しの保証の読み替え」
- [診断エンジン](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「処理系の不具合と処理系の制限の報告」
- ADR: [0013](../../2026-10-09-design-first-release/decisions/0013-evaluation-order-and-tail-calls.md)、[0083](../../2026-10-09-design-first-release/decisions/0083-constant-descriptions-in-shared-program.md)、[0151](../../2026-10-09-design-first-release/decisions/0151-inherited-handlers-tail-resume-only.md)、[0158](../../2026-10-09-design-first-release/decisions/0158-type-classes-by-dictionary-passing.md)、[0159](../../2026-10-09-design-first-release/decisions/0159-pattern-extensions-in-decision-trees.md)、[0160](../../2026-10-09-design-first-release/decisions/0160-one-shot-continuations-as-stack-segments.md)、[0259](../../2026-10-09-design-first-release/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)（決定 2）、[0280](../../2026-10-09-design-first-release/decisions/0280-reuse-by-dedicated-construct-instruction.md)
- インターフェース: [バイトコード](../10-interfaces/10-07-bytecode.md)の全体（とくに「その場での再利用の命令」）、[中間表現](../10-interfaces/10-06-ir.md)の「コア IR」「下位 IR」「10-12 に求めるもの」、[組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「表を引く関数」（`list_pattern_builtin`）、[組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の `Capability` と `builtin_decl`、[診断](../10-interfaces/10-02-diagnostics.md)の「実行時エラー、資源の不足、処理系の制限」（L0101〜L0111）、[仮想機械](../10-interfaces/10-09-vm.md)の「第 1 段の実行の関数」（テストで使う）

## 作るもの

- `src/bytecode/codegen.rs`: 10-07 の `sig=src/bytecode/codegen.rs`（`CodegenError` と `codegen`）。`src/legacy/bytecode/codegen.rs` を写して広げてよい。大きくなるときは、`src/bytecode/codegen/` の下の非公開の子のモジュールに分けてよい（`codegen.rs` を `codegen/mod.rs` にする）。
- `src/bytecode/disasm.rs`: R09 が段が 1 の命令について書いた `disassemble` に、段が 2 の命令と、構成子・型クラス・実装・操作・ハンドラの記述・組み込みの関数の参照の表の表示を加える。
- 各ファイルの `#[cfg(test)] mod tests`。
- `src/diag/codes.rs` の L0101〜L0111 の型板（10-02「型板の直し方」の範囲で直す場合だけ）。

`liveness.rs`・`asm.rs`（R05）、`instr.rs`・`program.rs`（C01）は変えない。

## 手順の要点

### 表と原型の番号

1. 下位 IR の定義の並び（`Program::defs`）の順に、定義ごとの原型の番号を振り、`top_fns` に（束縛の番号, 原型の番号）を並べる。続けて、実装（`Program::impls`）のメソッドの原型の番号を、実装の順、メソッドの順に振る。
2. 定義と実装のメソッドの本体を順に移す。ラムダ・`lazy` の本体・`handle` の本体と節の原型、値として使う組み込みの関数と操作の原型は、移す途中で出会った順に原型の表の後ろに加える。
3. 構成子の表（`CON` の B と定数の記述）、型クラスの表、実装の表（`DICT` の B）、操作の表（`PERFORM` の B）、組み込みの関数の参照（`PRIM`・`IO` の B）は、使ったものだけを初めて使ったときに加え、同じものには同じ番号を使う（10-07「コード生成」の最後の箇条）。組み込みのエフェクトの操作は、`BuiltinRef::op` と `OpInfo::builtin` が互いを指すように、両方の表に載せる。
4. 型クラスの表は、使った実装の型クラス、`METHOD`・`TAILMETHOD` の辞書の型クラス（`MethodCall::dict` の `DictVal::class`）、それらの上位の型クラスを載せる。実装を一つも使わない型クラスのメソッドを辞書の引数で呼ぶ関数でも、`method_traits` の番号が型クラスの表にあるようにするためである（ADR 0310）。`MethodInfo::arity` はメソッド自身の制約の辞書の数と値の引数の数の和とする。実装の表の `supers` は、`ImplDef::supers`（`DictVal`）を `DictRecipe` に移したものである（02-07「辞書とメソッドの呼び出し」）。
5. 定数の記述は、プログラム全体で一つの並び（`CompiledProgram::consts`）に置き、同じ記述を一つの番号にまとめる（`Float` はビットの並びで比べる）。子の記述の番号を親より小さくする（子を先に加える）。原型は使う記述の番号の並び（`Proto::consts`）を持つ。移し方は 10-07「定数の記述」の二つの表のとおりである。
6. ハンドラの記述も、プログラム全体で一つの並び（`CompiledProgram::handlers`）に置き、原型は使う記述の番号の並び（`Proto::handlers`）を持つ。
7. `main` は `Program::main` の原型（`Program::main` が `None` なら `None`）、`main_kind` は `main_returns_result` から決める（`main` が `None` なら `Unit` を入れる。10-07 の `CompiledProgram::main`）。`sources` は引数の `Arc<SourceTable>` をそのまま入れる。
8. 表の名前の欄は、コード生成の入力（`LowerProgram` と `SourceTable`）から作れる名前にする。構成子の表の `CtorInfo::type_name` は `AdtDef::name`（モジュールで修飾しない名前）、型クラスの表の `MethodInfo::name` は、その型クラスの実装のメソッドの `Def::name` の最後の段（`Show[Person].show` なら `show`。どの実装でも同じ名前になるので、使った実装があればそれ、なければ `Program::impls` のうちその型クラスの最初の実装から引く。プログラムにその型クラスの実装が一つもなければ空の文字列とする）、操作の表の `OpInfo::effect` は、利用者のエフェクトの操作（`OpDef::effect` が `EffectName::User`）では `OpDef::name` の最後の `.` より前（`Log.write` なら `Log`）、組み込みのエフェクトの操作（`EffectName::Builtin`）では組み込みのエフェクトの表の項目のモジュールの最後の段と名前を `.` でつないだもの（`Console.Write`。`Ty::show` が組み込みのエフェクトを示すのと同じ形）とする。どの欄も、いまは逆アセンブラとテストだけが使う。

原型の名前、由来の種類（`ProtoOrigin`）、`span`、`boundary` は、02-07「原型の名前と由来の種類」「関数の境界」と 10-07「コード生成」の箇条に従う。定義の原型は `Def::name` と `DefOrigin`・`DefKind` から、実装のメソッドは `ImplDef::name` とメソッドの名前（`Show[Person].show`）から決める。値として使う組み込みの関数と操作の原型の名前は、操作なら `OpDef::name`、`Declared` の項目なら `builtins::builtin_decl`（`src/builtins/table.rs`）で引いた `BuiltinDecl::name`（10-11）とする。標準ライブラリのソースの中のラムダ・`handle`・`lazy` の原型は `StdlibHelper` とする。関数の境界は、トップレベルの関数・実装のメソッド・ラムダ・値として使う組み込みの関数と操作の原型であり、`handle` の本体と節、`lazy` の本体の原型は関数の境界でない。

### 計算と値の移し方

02-07「コード生成」の表と、10-07「コード生成」の補いの表に従う。最小実行版の移し方（レジスタの割り当て、末尾位置の受け渡し、`if`・`join`・`jump`・`case` の並べ方、前方への跳ぶ先の書き換え、捕捉の二種類の取り方）は、`src/legacy/bytecode/codegen.rs` のとおりに引き継ぐ。初回リリース版で加わる点を次に示す。

- 演算子: `Intrinsic::Operator { op, operand }` は、02-07「演算子の移し方」の表で `operand` の型から命令を選ぶ（`Decimal` は `ADDD` など、`Byte` は `EQBT`・`LTBT`・`LEBT`）。`Intrinsic::Eq`・`Ne` は `targs` の 0 番の型で選び、基本型でない型、`Ty::Param`・`Ty::App`・`Ty::Rigid` は `EQV` にする。表で「—」の組は `InternalError { stage: "codegen", .. }` とする。
- `Intrinsic::Force` は `FORCE r v`、`Intrinsic::Update` は `UPDATE r v w`。末尾位置なら続けて `RETURN r`。
- `App` の `func` が `Builtin` で `intrinsic` がないものは、`info.class` が `Io` なら `IO`、そうでなければ `PRIM`。引数は連続したレジスタに置く。`func` が `Op` なら `PERFORM`。`dicts` は値の引数の前の連続したレジスタに置く。
- `Method` は、辞書 V、メソッド自身の辞書 Ū、引数を連続したレジスタに置き、末尾位置なら `TAILMETHOD`、そうでなければ `METHOD`。C はメソッドの位置（`MethodCall::method`）。原型の `method_traits` のその命令の位置に、辞書の型クラス（`MethodCall::dict` の `DictVal::class`）の型クラスの表の番号を記録し、ほかの命令の位置には `None` を置く（ADR 0310）。
- `DictVal`: `Impl` は制約を持たなければ `LOADK`（`ConstDesc::Dict`）、持てば、制約の辞書を連続したレジスタに置いて `DICT`。`Super` は `SUPER`（重なれば重ねる）。`Param` は変数のレジスタか捕捉した値。`ImplParam(i)` は、メソッドの原型の中では `GETDICT r i`、メソッドの中のラムダ・`lazy`・`handle` の原型の中では捕捉した値（作る側で `GETDICT` したレジスタを捕捉する）。
- `Lazy` は本体から引数のない原型を作り、`LAZY r Bx`。`Handle` は本体から引数のない原型、各節から操作の引数と継続を引数とする原型を作り、`CLOSURE` で本体と節の関数の値を連続したレジスタに置いて `HANDLE r b c`。ハンドラの記述は、節の順に操作の番号と `tail_resumptive` を並べる。
- `Resume` は `RESUME r k v`。k は `cont` の変数のレジスタか捕捉した値。`handle` の本体と節の原型は、囲む節の継続の変数を捕捉しうる。
- `Escape` は、実行中の原型が関数の境界なら `RETURN r`、そうでなければ `ESCAPE r`。
- `Use` は `USE v`、本体を末尾位置でなく移し、`RELEASE`、末尾位置なら続けて `RETURN r`。解放の枠が残る間に `TAILCALL`・`TAILMETHOD` を置かない（02-07「末尾呼び出し」）。
- `CaseConst` の区間は、`<=` の命令で下限と上限と比べて `JMPF`。`CaseLength`・`ListGet`・`ListSlice` は、10-12 の `list_pattern_builtin` で引いた内部の項目の `PRIM`。位置は `LOADK` した `Int` の定数で渡す。長さの比較は `EQI`・`LEI` と `JMPF`。
- 値として使う組み込みの関数と操作は、呼んで戻るだけの原型を項目ごとに一つ作り（10-07「定数の記述」の表の `Func` の行）、`LOADK` する。原型の中の呼び出しは、上の命令（`PRIM`・`IO`・`PERFORM`・`FORCE`・`UPDATE`、演算子の命令）で移し、位置の表はすべて `None` とする。
- その場での再利用: 構成子を適用した値を作る位置が 02-07「その場での再利用」の条件をすべて満たすとき、`CON` の代わりに `CONR` を置く（ADR 0280、10-07「その場での再利用の命令」）。条件は下位 IR の上で判定する。構成子の `case` の対象の変数と、`let y ⇐ return x` で互いに束縛した変数（元の変数を含む）を同じ値（分けた値）として扱う。F11 は `match` の対象を常に新しい変数に束縛する（`let x ⇐ ⟦xs⟧ in Match{x}`）ので、利用者の書いた変数 `xs` と `case` の対象の変数 `x` は別の変数になり、`x` だけで判定すると `xs` の使用を見落とす。条件は次の三つである。同じ値として扱う変数のどれもが、その分岐の本体の、構成子を適用する位置より後のどの道筋でも使われず、捕捉もされないこと。作る構成子の引数の数が分けた構成子の引数の数と等しく 1 以上であること。同じ値として扱う変数のどのレジスタも、引数のレジスタのどれとも同じでないこと。`CONR` の A は、同じ値として扱う変数のどれかのレジスタとし、結果を別のレジスタに置く必要があるときは `CONR` の後に `MOVE` で移す。一つの分けた値は、一つの道筋で一度だけ `CONR` の A にする。回収の方式と `HeapConfig::reuse` によらず同じ命令を置く。
- `ConstRef` と、定数の値からの記述は 10-07「定数の記述」の表のとおり。
- 位置の表: 命令ごとに、その命令を生んだ計算か値の `origin` を入れる。
- 変数からレジスタへの対応: 判定の木への変換（F12）は、二つ以上の葉に写したガードの中の変数の `VarId` を振り直さないので、同じ `VarId` が兄弟の分岐（互いに入れ子にならない `case` の分岐や `if` の二つの側）でそれぞれ束縛されることがある（[F12](F12-decision-tree.md) の手順の要点）。変数の表は分岐ごとに有効範囲を持たせ、兄弟の分岐で同じ `VarId` を束縛しても誤りにしない。同じ `VarId` を入れ子の位置で二度束縛する IR は、処理系の不具合として `InternalError` にする。

### 生存の情報

コード生成は、生存の情報を自分で求めない。原型をすべて作り、コンパイル済みプログラムの表（組み込みの関数の参照の `arity` と `capability`、実装の表の `dict_arity`、型クラスの表の `MethodInfo::arity`、操作の表の `arity`、ハンドラの記述の節の数、原型の `captures`）を埋め終えた後に、原型ごとに R05 の `liveness::compute_liveness(&program, proto)` を呼び、結果を `Proto::live` に入れる。`reg_use` はこれらの表から命令の読むレジスタを決める（10-07「生存の情報」の規則の 1 つ目）ので、表を埋める前に呼ぶと誤った情報になる。`LivenessError` は `InternalError { stage: "codegen", .. }` にする。

二つのメモリの管理は同じ生存の情報を使う（ADR 0259 の決定 2）。コード生成は、回収の方式によって命令を変えない。

### 処理系の制限

02-07「処理系の制限」と 10-02 の L0101〜L0111 の表に従う。

- 原型ごとの制限（L0101 レジスタの数、L0102 定数の番号の並び、L0103 分岐表の数、L0104 ハンドラの記述の番号の並び）は、当たった原型の関数ごとに一つ出し、その関数の宣言の位置（`Def::span`、ラムダなどはそれを含む定義の `span`）を示す。
- プログラム全体の制限（L0105〜L0111）は表ごとに一つ出し、位置を持たない。L0109〜L0111 の `{name}` は型クラスの名前（L0111 は実装の型クラスの名前）。
- 当たってもほかの原型の生成は続け、当たったすべての制限を `CodegenError::Limit` で返す。表の文言の数と 10-07 の符号化の上限が食い違えば、10-02「型板の直し方」の範囲で型板を直す。

### 逆アセンブラ

R09 の形式に合わせて、段が 2 の命令のオペランドと、表（構成子、型クラス、実装、操作、ハンドラの記述、組み込みの関数の参照）を示す。形式はテストで比べない（10-07）。

## 受け入れテスト

入力は利用者のソース（初回リリース版の文法）とし、F11 の脱糖の補助の関数でコア IR を作り、F12 の `lower_program` を通してから `codegen` を呼ぶ。ただし、「原型ごとの制限」「制限の後も続ける」の場合と、プログラム全体の制限（L0105〜L0111）のテストは、下位 IR のプログラム（`LowerProgram`）をテストの中で手で作って `codegen` に渡してよい（リストの要素の値を `ValKind::List` に直接並べてよい）。70,000 要素のリストを利用者のソースで書くと、01-12 の脱糖で深さ 70,000 の入れ子の `Let` になり、型検査・判定の木への変換・コード生成がそれを再帰で辿ってテストのスレッドのスタックを溢れさせるからである。最小実行版の T21 も、下位 IR を手で作って制限を確かめた（`src/legacy/bytecode/codegen.rs` のテストのモジュール）。命令の並びは、命令を `(Opcode, a, b, c)` の並びにして比べる補助の関数で確かめる。入力で `Console` を使うときは、`import Benitoite.Unofficial.IO.Console` と書く（ADR 0286）。実行するテストは、第 1 段の VM（`Vm::new`・`start_main`・`run_stage1`）と R08 の第 1 段の `IoServices` の一時的な実装のテスト用の出力を使う。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 段が 1 の命令だけ | C03 が書き直した最小実行版のゴールデンテストから、`run` のもの全部（`testdata-next/` にあれば）。`testdata-next/` の `.mode` がすべて `check` なら、`crates/benitoite/testdata/` の最小実行版の `run` のテストから、最小実行版の言語の機能（関数、ラムダ、`match`、リスト、`Option`、演算子、文字列、IO）を網羅する 10 本以上を新しい構文に写し、その `.stdout` を期待値とする | どの原型の命令も 10-07 の命令の表で段が 1 の命令だけ |
| 第 1 段の VM での実行 | 上のうち標準出力を書くもの | 出力が最小実行版のテストの期待値と同じ |
| 末尾呼び出し | 末尾位置の関数・メソッド・組み込みの関数の呼び出し | `TAILCALL`・`TAILMETHOD`、組み込みの関数は命令の後に `RETURN`。末尾位置の `CALL` がない |
| `with` の中の末尾位置 | `with` の本体の最後の呼び出し | `CALL` と `RELEASE` の後に `RETURN`。`TAILCALL` がない |
| `Decimal`・`Byte` の演算 | `a + b`（`Decimal`）、`x < y`（`Byte`）、`a = b`（`Decimal`） | `ADDD`、`LTBT`、`EQD` |
| 構造の等しさ | `Option[Integer]` と型パラメータ `T: equality` の `=` | どちらも `EQV` |
| レコード | 構築とフィールドを取り出す関数 | `CON` と `FIELD`、フィールドを取り出す関数の原型 |
| 型クラス | 制約付きの関数の呼び出し、メソッドの呼び出し、上位の型クラス、制約を持つ実装 | `LOADK`（`Dict`）、`DICT`、`SUPER`、`METHOD`、メソッドの原型の中の `GETDICT`。実装の表の `supers` が `DictRecipe` になっている |
| ハンドラ | 二つの節を持つ `handle` と `resume` | 本体と節の原型（関数の境界でない）、`CLOSURE` を連続したレジスタに置いた `HANDLE`、節の順のハンドラの記述、`RESUME` |
| 途中の `return` | `handle` の本体の中の `return` と、関数の本体の中の `return` | 前者は `ESCAPE`、後者は `RETURN` |
| `lazy` と `Reference.update` | `lazy` の値を作って `Lazy.force`、`Reference.update` | `LAZY`・`FORCE`・`UPDATE` |
| 組み込みの操作 | `Console.writeLine` の呼び出しと値としての使用 | `IO` と、`BuiltinRef::op` と `OpInfo::builtin` が互いを指す表。値として使う原型は一つで位置がすべて `None` |
| リストのパターン | `[first, ..rest]`・`[.., last]` の `match` | 内部の項目の `PRIM` と `LOADK` した位置 |
| 写したガード | ガードを持つ分岐が判定の木の二つ以上の葉に写る `match`（ガードの式の中に、変数を束縛する `match` を含む） | 生成が成功し、第 1 段の VM で実行してガードの真偽どおりの分岐を選ぶ |
| 定数 | レコードとリストとマップを値に持つ定数を二つの関数から参照する | 定数の記述が一つにまとまり、子の番号が親より小さい |
| 生存の情報 | 上のどのプログラムでも | すべての原型の `live.starts` の長さが命令の数に 1 を足した数（空の原型を除く） |
| 原型の名前と由来 | 別のモジュールの関数、実装のメソッド、ラムダ、`handle` の節、標準ライブラリの補助の関数 | 02-07「原型の名前と由来の種類」の表のとおり |
| その場での再利用 | 利用者の型のリスト（`data MyList[T]` に `Nil` と `Cons(T, MyList[T])` を持つ型）を写しながら要素を変える関数 | `Cons` の分岐で `CONR`（A は分けた値のレジスタ）。第 1 段の VM で実行した結果が、`CON` で作った場合と同じ |
| 再利用しない位置 | 分けた値を構成子の適用の後に使う関数、引数の数の違う構成子を作る関数、分けた値そのものを引数に含む構成子を作る関数 | どれも `CON` で、`CONR` がない |
| 原型ごとの制限 | 70,000 個の互いに異なる整数の定数を要素とするリストを返す関数（手で作った下位 IR） | L0101 と L0102、その関数の宣言の位置 |
| 制限の後も続ける | 制限に当たる関数を二つ含むプログラム（手で作った下位 IR） | 診断が二つ |

プログラム全体の制限（L0105〜L0111）は、表を 65536 項目以上にするプログラムを作るのが重いので、表の大きさを判定する非公開の関数の単体テストで確かめてよい。

誤りのないプログラムのうち出力が仕様で決まり、段が 1 の命令だけに移るもの（上の「第 1 段の VM での実行」に使ったもののうち、C03 のテストと重ならないもの）は、`run` のゴールデンテストとして `testdata-next/eval/` に、名前の先頭に `f15_` を付けて置く（C03 と並行して走っても、C03 が書き直すテストと同じパスにならないようにする。07-03「ゴールデンテスト」の形式。`.bnt` の先頭に `// spec:` の行、`.mode` に `run`、`.exit`、`.stdout`）。実行器（C10）とパイプライン（F18）が揃うまでは実行できないので、C05 が確かめる。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 末尾位置の適用は、すべて `TAILCALL`・`TAILMETHOD` か、組み込みの関数・操作・演算子の命令と `RETURN` の組になっている
- 最小実行版の言語の範囲のプログラムが段が 1 の命令だけに移ることを確かめるテストがある
- すべての原型の `Proto::live` を `compute_liveness` で埋めている

## 確認の観点

- 末尾位置の情報が、`use` の本体では「末尾位置でない」として渡っているか。`lazy`・`handle` の原型の中では、その原型の末尾位置として扱っているか。
- 関数の境界の印が 02-07「関数の境界」のとおりか。`ESCAPE` を関数の境界の原型の中で出していないか。
- `compute_liveness` を、表をすべて埋めた後に呼んでいるか（00-04「コード生成（F15）と生存の情報（R05）」）。
- 定数の記述の番号の並びで、子が親より小さいか。同じ記述を一つにまとめているか。
- 段が 2 の命令を、最小実行版の言語の範囲のプログラムで出していないか（`CONR` は段が 1 なので、「段が 1 の命令だけ」の判定は変わらない）。
- `CONR` を置く位置が 02-07「その場での再利用」の条件をすべて満たしているか。分けた値を後で使う道筋が一つでもあれば `CON` にしているか。
- 捕捉の表に、`ImplParam` の `GETDICT` の値と継続の変数が正しく入っているか。

## 難易度の理由

最小実行版のコード生成を引き継げる部分は大きいが、辞書・ハンドラ・`lazy`・解放の枠が、原型の分け方、捕捉、関数の境界、末尾位置の受け渡しのそれぞれに絡む。誤りの多くは VM で実行して初めて表に出るが、段が 2 の命令は本作業の時点で実行できないので、命令の並びと表の形で確かめるしかなく、第 2 段の作業（R20〜R25、R34・R35）で見つかる誤りの原因にもなる。生存の情報を正しく求めるために表を埋める順序にも注意が要る。

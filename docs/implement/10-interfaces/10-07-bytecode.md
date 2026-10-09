# バイトコード

本章は、初回リリース版の命令の集合と符号化、コンパイル済みプログラムの形、コード生成が渡す生存の情報、コード生成・逆アセンブラ・読み込みのときの検証器の関数のシグネチャを定める。設計書の対応する章は[バイトコードとコード生成](../../design/02-impl/02-07-bytecode.md)であり、命令の意味（VM がどう実行するか）は[仮想機械](../../design/02-impl/02-08-vm.md)で定める。02-07 が「実装プランで定める」とした命令の種類ごとの番号、分岐表とハンドラの記述の形を、本章で決める。

本章は U1 と U2 の共有の章である。命令の集合は、U1 のコード生成（F15）と U2 の VM（R09、R20〜R25）の境目であり、第 1 段の VM が実行する命令と、第 2 段と U1 が足す命令を、一度で凍結する（[README](../README.md) の「決めたこと」の 3・4）。

コードブロックの見出しの読み方は [README](../README.md) の「インターフェースの読み方」に従う。パスは処理系のクレート `crates/benitoite/` からの相対パスである。

## 置く作業と既存のファイル

- 置く作業: C01

命令の集合、コンパイル済みプログラムの形、生存の情報は C01 が置く。第 1 段の VM（R09）と生存の情報（R05）がこれを使うからである。コード生成のシグネチャと読み込みのときの検証器は、中間表現の章（[10-06](10-06-ir.md)）の型を使うか第 3 段の作業なので、`task=C02` を付けて C02 が置く。

本章の C01 の部分は、[基本の型](10-01-base.md)のうち最小実行版から変わらない型（`BindingId`・`Span`・`SourceTable`。`src/base/` は `legacy` へ移さない）、[組み込みの関数の型付きの形](10-11-builtin-interface.md)の `Capability`、組み込みの関数の番号 `BuiltinId`（10-11 が C01 で `src/builtins/mod.rs` に置く）だけを使う。[型と型検査](10-05-types.md)の型は使わないので、`src/types/` のファイルを C01 に移す必要はない。

どのファイルも、C04 が最小実行版の同じパスのファイルを `src/legacy/` へ移して空けたパスに、新しく置く（[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」）。最小実行版の命令の集合とコード生成は `src/legacy/bytecode/` に残り、最小実行版の VM とともに、C05 までは最小実行版のテストを走らせ、C18 が消す。

| ファイル | 扱い | 置く作業 | 中身を書く作業 |
|---|---|---|---|
| `src/bytecode/mod.rs` | 置く（`file=`） | C01 | — |
| `src/bytecode/instr.rs` | 置く（`file=`） | C01 | — |
| `src/bytecode/program.rs` | 置く（`file=`） | C01 | — |
| `src/bytecode/liveness.rs` | 置く（`file=` と `sig=`） | C01 | R05 |
| `src/bytecode/disasm.rs` | 置く（`sig=`）。legacy から写して広げてよい | C01 | R09（第 1 段の命令）、F15（ほかの命令） |
| `src/bytecode/codegen.rs` | 置く（`sig=`）。legacy から写して広げてよい | C02 | F15 |
| `src/bytecode/asm.rs` | `mod.rs` の `#[cfg(test)]` の宣言に合わせて、中身のないモジュールとして置く（本章「第 1 段で実行するプログラム」） | C01 | R05 |
| `src/bytecode/verify.rs` | 置く（`sig=`） | C02 | R32 |

## 第 1 段で実行するプログラム

第 1 段の VM（R09）は、命令の表の段が 1 の命令（最小実行版の言語の分）を実行する（ADR 0268）。第 1 段のためのコード生成は作らない。最小実行版の下位 IR から本章の命令を作る経路を `legacy` の中に作ると、C18 が `legacy` とともに消す使い捨てのコードになるからである（[README](../README.md) の「決めたこと」の 5）。

F15 のコード生成が揃うまでは、第 1 段の作業は、テスト用のバイトコードの組み立て（`src/bytecode/asm.rs`）で命令列・原型・コンパイル済みプログラムを手で作り、VM と二つのメモリの管理を単体テストで確かめた。組み立ては R05 が書き、R05（生存の情報）、R09（VM）、R11（回収の強制で VM に通すテスト。第 1 段の間は二つのメモリの管理のそれぞれで通した）、R13 のテストが使う。`#[cfg(test)]` の非公開のモジュールであり、インターフェースとして凍結しない。命令の符号化（`Instr` の組み立ての関数）、原型の表、定数の記述、組み込みの関数の参照の表を埋める手間を省き、跳ぶ先を名前の付いた印で書けるようにすることだけを求める。生存の情報は、組み立てた原型に `compute_liveness` を呼んで埋める。

F15 と F18 が揃った後は、C05 が、新しい構文へ書き直した最小実行版のテストを初回リリース版のパイプラインで第 1 段の VM に通す（[作業の進め方](../00-common/00-03-workflow.md)の「構文の改めとテストの移行」）。最小実行版の言語の範囲のプログラムを F15 で移すと、段が 1 の命令だけになる。段が 2 の命令のうち、型クラスの命令は型クラスの制約がなければ現れず（標準の型クラスは prelude に含まれない。演算子と文字列補間は型クラスを使わない。組み込みの制約 `equality` は辞書を持たず `EQV` に移す。02-07「演算子の移し方」）、`ESCAPE` は関数の境界でない原型（`handle` と `lazy` の本体）の中にだけ現れ、`Decimal`・`Byte`・`lazy`・`Reference.update`・リソース・ハンドラの命令は、それぞれの機能を使わなければ現れないからである。

## 命令の符号化

命令は 64 ビットの固定長である（02-07「レジスタ型の命令」）。ビットの割り当ては、最小実行版と同じく次のとおりとする。

| ビット | 内容 |
|---|---|
| 0〜7 | 命令の種類（`Opcode` の番号） |
| 8〜23 | オペランド A |
| 24〜39 | オペランド B |
| 40〜55 | オペランド C |
| 56〜63 | 使わない（0） |

Bx は B を下位、C を上位とする 32 ビットの符号なし整数、sBx は同じ 32 ビットを 2 の補数で読んだ符号付き整数である。跳ぶ先の相対位置 sBx は、跳ぶ命令の次の命令の位置からの距離である（`JMP 0` は何もしない）。

命令の種類の番号は、分類ごとに区切って振る。番号は処理系の外に出さない（コンパイル済みプログラムをファイルに保存しない。02-01）ので、最小実行版の番号とは合わせない。

## 命令の表

段の欄は、その命令を VM が実装する時期である。「1」は第 1 段の VM（R09）が実装する最小実行版の言語の分、「2」は第 2 段と U1 に合わせて足す分である。第 1 段の VM は、段が 2 の命令に出会ったら `Stop::Internal` を返す（[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。VM の作業の欄は、段が 2 の命令の処理を書く作業である。

`R[i]` はレジスタ i、`K[i]` は原型の定数の並びの i 番目が指す定数の記述、`P[i]` は原型の表の i 番目を表す。引数の並びの数を命令が持たない命令は、数を表から読む（オペランドの欄の「数」）。

### 移動、関数、型クラス

| 番号 | 命令 | 動作 | 段 | VM の作業 |
|---|---|---|---|---|
| 0 | `MOVE A B` | `R[A] ← R[B]` | 1 | |
| 1 | `LOADK A Bx` | `R[A] ← K[Bx]` の値。Bx は原型の定数の並びの位置で 16 ビットに収める（本章「定数の記述」） | 1 | |
| 2 | `GETCAP A B` | `R[A] ←` 実行中の関数の値が捕捉した B 番目の値 | 1 | |
| 3 | `CLOSURE A Bx` | `P[Bx]` と、その捕捉の表に従って集めた値から関数の値を作り `R[A]` に入れる | 1 | |
| 4 | `CALL A B C` | `R[B]` の関数を引数 `R[B+1]`…`R[B+C]` で呼び、結果を `R[A]` に入れる | 1 | |
| 5 | `TAILCALL B C` | `R[B]` の関数を引数 `R[B+1]`…`R[B+C]` で末尾呼び出しする（A は使わない） | 1 | |
| 6 | `RETURN A` | `R[A]` を結果として呼び出し元に戻る。第 2 段では、実行中の呼び出しの枠に属する解放の枠を先に解放する（02-08「実行の手順」） | 1 | R24（解放の枠） |
| 7 | `PRIM A B C` | 組み込みの関数の参照 B（`CompiledProgram::builtins`）を、引数 `R[C]` から始まる並び（数は `BuiltinRef::arity`）で呼び、結果を `R[A]` に入れる。権限が `Io` でない関数に使う | 1 | R25（待つ、タスクの起動） |
| 8 | `IO A B C` | 権限が `Io` の組み込みの関数の参照 B を、引数 `R[C]` から始まる並び（数は `BuiltinRef::arity`）で呼び、応答を `R[A]` に入れる。第 2 段では、先に `BuiltinRef::op` の操作の節をハンドラの連鎖から探し、あれば `PERFORM` と同じく扱う | 1 | R20（節の探索）、R26（送り出しの列） |
| 9 | `ESCAPE A` | `R[A]` を結果として、最も内側の関数の境界の呼び出しの枠まで抜ける（02-08「実行の手順」） | 2 | R21 |
| 10 | `GETDICT A B` | `R[A] ←` 実行中のメソッドを引いた辞書が持つ、B 番目の実装の制約の辞書 | 2 | R34 |
| 11 | `DICT A B C` | 実装 B（`CompiledProgram::impls`）の辞書を、実装の制約の辞書 `R[C]` から始まる並び（数は `ImplInfo::dict_arity`）から作って `R[A]` に入れる | 2 | R34 |
| 12 | `SUPER A B C` | 辞書 `R[B]` の型クラスの C 番目の上位の型クラスの辞書を `R[A]` に入れる（`ImplInfo::supers` の式を計算する） | 2 | R34 |
| 13 | `METHOD A B C` | 辞書 `R[B]` のメソッド C を、引数 `R[B+1]` から始まる並び（数は、原型の `method_traits` が示す型クラスの `MethodInfo::arity`）で呼び、結果を `R[A]` に入れる | 2 | R34 |
| 14 | `TAILMETHOD B C` | 辞書 `R[B]` のメソッド C を、引数 `R[B+1]` から始まる並びで末尾呼び出しする | 2 | R34 |

### 算術

| 番号 | 命令 | 動作 | 段 |
|---|---|---|---|
| 16〜20 | `ADDI`・`SUBI`・`MULI`・`DIVI`・`MODI` | `Integer` の `+`・`-`・`*`・`div`・`mod`。`R[A] ← R[B] ⊕ R[C]` | 1 |
| 21 | `NEGI A B` | `Integer` の符号の反転 | 1 |
| 22〜25 | `ADDF`・`SUBF`・`MULF`・`DIVF` | `Float` の `+`・`-`・`*`・`/` | 1 |
| 26 | `NEGF A B` | `Float` の符号の反転 | 1 |
| 27〜30 | `ADDD`・`SUBD`・`MULD`・`DIVD` | `Decimal` の `+`・`-`・`*`・`/`（ADR 0114） | 2 |
| 31 | `NEGD A B` | `Decimal` の符号の反転 | 2 |
| 32 | `CONCAT A B C` | `String` の `+`。結果の大きさの上限を超えるときは資源の不足で止まる（ADR 0049） | 1 |

### 比較

| 番号 | 命令 | 動作 | 段 |
|---|---|---|---|
| 40〜42 | `EQI`・`LTI`・`LEI` | `Integer` の `=`・`<`・`<=`。`R[A] ← R[B] ⊕ R[C]` | 1 |
| 43〜45 | `EQF`・`LTF`・`LEF` | `Float` の `=`・`<`・`<=`（IEEE 754 の比較） | 1 |
| 46〜48 | `EQD`・`LTD`・`LED` | `Decimal` の `=`・`<`・`<=`（数の比較。小数の桁数は比べない） | 2 |
| 49〜51 | `EQS`・`LTS`・`LES` | `String` の `=`・`<`・`<=` | 1 |
| 52〜54 | `EQC`・`LTC`・`LEC` | `Character` の `=`・`<`・`<=` | 1 |
| 55〜57 | `EQBT`・`LTBT`・`LEBT` | `Byte` の `=`・`<`・`<=`（ADR 0105） | 2 |
| 58 | `EQB A B C` | `Boolean` の `=` | 1 |
| 59 | `EQV A B C` | 基本型でない等値の型の構造の `=`（10-08 の `runtime::equal::values_equal`） | 1 |
| 60 | `NOT A B` | `Boolean` の否定 | 1 |

段が 2 の算術と比較の命令（`Decimal`・`Byte`）の VM の処理は、R35 が書く。`Decimal` の算術と比較そのものは `base::decimal` の関数（F07 が自作する。[ADR 0275](../../design/decisions/0275-self-made-decimal-arithmetic.md)）を呼ぶ。

### データと分岐

| 番号 | 命令 | 動作 | 段 |
|---|---|---|---|
| 64 | `CON A B C` | 構成子 B（`CompiledProgram::ctors`）を、引数 `R[C]` から始まる並び（数は `CtorInfo::arity`。1 以上）に適用した値を `R[A]` に入れる | 1 |
| 65 | `LIST A B C` | `R[B]`…`R[B+C-1]` を要素とするリストを `R[A]` に入れる | 1 |
| 66 | `FIELD A B C` | 構成子を適用した値 `R[B]` の C 番目（0 から数える）の引数を `R[A]` に入れる | 1 |
| 67 | `CONR A B C` | `CON A B C` と同じ値を `R[A]` に入れる。参照カウントの方式では、`R[A]` の前の値の対象をほかに指す `Slot` がなければ、その対象を書き換えて使う（本章「その場での再利用の命令」、[ADR 0280](../../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)） | 1 |
| 72 | `JMP sBx` | 相対位置 sBx へ跳ぶ（A は使わない） | 1 |
| 73 | `JMPF A sBx` | `R[A]` が `false` なら相対位置 sBx へ跳ぶ | 1 |
| 74 | `SWITCH A Bx` | `R[A]` の構成子のタグで、原型の分岐表 Bx に従って跳ぶ | 1 |

### 明示遅延、可変のセル、リソース

| 番号 | 命令 | 動作 | 段 | VM の作業 |
|---|---|---|---|---|
| 80 | `LAZY A Bx` | `P[Bx]`（引数のない `lazy` の本体）と、その捕捉の表に従って集めた値から、評価の前の `Lazy` の値を作って `R[A]` に入れる（E-Lazy） | 2 | R22 |
| 81 | `FORCE A B` | `R[B]` の `Lazy` の値を求めて `R[A]` に入れる（`Lazy.force`。E-ForceDone・E-Force） | 2 | R22 |
| 82 | `UPDATE A B C` | セル `R[B]` の値を関数 `R[C]` を適用した値に変え、`R[A]` に `()` を入れる（`Reference.update`。ADR 0167） | 2 | R23 |
| 83 | `USE A` | リソース `R[A]` の解放の枠を積む（E-Use） | 2 | R24 |
| 84 | `RELEASE` | 実行中の呼び出しの枠に属する最も上の解放の枠を降ろし、そのリソースを解放する（E-Release。オペランドを持たない） | 2 | R24 |

### ハンドラ

| 番号 | 命令 | 動作 | 段 | VM の作業 |
|---|---|---|---|---|
| 88 | `HANDLE A B C` | 本体の関数 `R[B]` と、節の関数 `R[B+1]` から始まる並び（数はハンドラの記述の節の数）と、原型のハンドラの記述の並びの C 番目から `handle` の枠を積み、本体を呼ぶ。`handle` の式の値を `R[A]` に入れる | 2 | R20 |
| 89 | `PERFORM A B C` | 操作 B（`CompiledProgram::ops`）を、引数 `R[C]` から始まる並び（数は `OpInfo::arity`）で呼び、結果を `R[A]` に入れる | 2 | R20 |
| 90 | `RESUME A B C` | 継続 `R[B]` を値 `R[C]` で再開し、`handle` の式の値を `R[A]` に入れる | 2 | R20 |

命令の数は 68 である。段が 1 の命令は 43（最小実行版の命令と同じ集まりに `CONR` を加えたもの）、段が 2 の命令は 25 である。`CONR` を段 1 に置くのは、第 1 段の測定で、その場での再利用がある場合とない場合を比べるためである（ADR 0259 の決定 3、ADR 0280 の決定 5）。

タスクの起動、`Reference.new`・`get`・`set`、`Task.await`、`TaskGroup` の関数、リソースを解放する関数、`Lazy.force` と `Reference.update` を除く組み込みの関数は、専用の命令を持たず `PRIM` で呼ぶ（02-07「命令」）。タスクの起動は、`PRIM` で呼んだ組み込みの関数が「タスクの起動」の応答を返すことで行う（02-08「タスクの起動と待ち方」、10-11 の `Reply::SpawnTasks`）。組み込みのエフェクトの操作（出力、ファイル、時計など）はすべて `IO` で呼ぶ。マップ・集合・`Bytes` を作る命令はない（02-07「コード生成」）。

## その場での再利用の命令

`CONR A B C` は、参照カウントの方式の、参照の数が 1 の対象のその場での再利用を行う唯一の命令である（[ADR 0280](../../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)、02-07「その場での再利用」、02-08「実行の手順」）。

- オペランドは `CON` と同じである。A は結果のレジスタであり、同時に再利用の候補（構成子の `case` で分けた値）を置いたレジスタである。A は、C から始まる引数の並びに含まれない。
- コード生成（F15）は、02-07「その場での再利用」の条件を満たす位置にだけ `CONR` を置く（本章「コード生成」）。第 1 段の単体テストは、テスト用のバイトコードの組み立て（`asm.rs`）で `CONR` を書く。
- 生存の情報（R05）: `reg_use` は、`CONR` の `reads` の先頭に A（前の値）を置き、続けて引数の並びのレジスタを置く。`write` は A である。`compute_liveness` は、A の読み出しに `LastUse { reg: A, sole }` を付ける。A はこの命令が書くので、この読み出しはつねに最後の使用である。`sole` は、A が引数の並びにないときに真である。
- VM（R09）は、次の順に処理する。一意であることの判定は、引数のレジスタの参照がまだ数えられている間に行う（10-08「その場での再利用」）。
  1. 引数の並びを `NoGcCtx::load` で読む。
  2. `R[A]` の前の値を `NoGcCtx::load` で読む。前の値が、値の並びの種類が `FieldsKind::Ctor` で、長さが構成子 B の `CtorInfo::arity` と等しい対象でなければ、`Stop::Internal` で止まる（コード生成の誤り）。
  3. `CON` と同じく新しく確保して `R[A]` に入れる。前の値はそのまま捨てる。

  R16 の後の VM は、命令の実行の中で生存の情報を読まず（[ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md) の決定 1）、`reuse_ctor` を呼ばない。マーク・スイープの `reuse_ctor` はつねに `None` を返すので、振る舞いは変わらない。参照カウントで再利用するときの手順（前の値を `take` で取り出し、`LastUse { reg: A, sole: true }` があれば `reuse_ctor` を呼び、`LastUse` の付いた引数のレジスタを `clear` する）は、タグ `stage1-rc-final` の実装にある。

  マーク・スイープの方式と、`HeapConfig::reuse` が偽の設定では、`reuse_ctor` がつねに `None` を返すので、`CONR` は `CON` と同じに振る舞う（10-08「その場での再利用」）。第 1 段の締め（R14）が参照カウントを外したので、現在の構成では `CONR` はつねに `CON` と同じに振る舞う。候補と引数が別のレジスタで同じ対象を指すときは、手順 3 の時点で引数のレジスタがその対象を数えているので、再利用しない。
- 逆アセンブラは `CONR` を `CON` と同じ形で示す。

## オペランドの補足

- `LOADK` の Bx（定数の並びの位置）、`SWITCH` の Bx（分岐表の位置）、`HANDLE` の C（ハンドラの記述の並びの位置）は、原型ごとの並びの位置であり、16 ビットに収める（02-07「処理系の制限」）。`CLOSURE`・`LAZY` の Bx は原型の表の番号であり、32 ビットの Bx をそのまま使う。
- レジスタの数は `u16` で持つので、一つの原型のレジスタは 65535 個までである。これを超えるとき L0101 とする（最小実行版のとおり）。`CALL`・`LIST` などの C が表す個数は、同時に使うレジスタの数を超えないので、L0101 の検査を通れば 16 ビットに収まる。
- 構成子（`CON`・`CONR` の B）、組み込みの関数の参照（`PRIM`・`IO` の B）、実装（`DICT` の B）、操作（`PERFORM` の B）の番号は、プログラム全体の表の位置であり、16 ビットに収める。メソッドの位置（`METHOD` の C）、上位の型クラスの位置（`SUPER` の C）、辞書の位置（`GETDICT` の B）も 16 ビットに収める。表が 65536 項目以上になるときは、処理系の制限として診断を出して実行しない（02-07「処理系の制限」のプログラム全体の制限。診断コードは [10-02](10-02-diagnostics.md) の L0105〜L0111）。
- `METHOD` と `TAILMETHOD` の引数の並びは、メソッド自身の制約の辞書を値の引数の前に含む（02-07「コンパイル済みプログラム」の型クラスの表）。並びの長さは、原型の `method_traits` のその命令の位置にある型クラスの、C の位置のメソッドの `arity` である（ADR 0310）。
- `HANDLE` の節の関数は、節の操作の引数と継続の値を引数にとる（引数の数は操作の引数の数に 1 を足した数）。本体の関数は引数をとらない。

```rust file=src/bytecode/instr.rs
//! 命令の符号化（実装プラン 10-07「命令の符号化」「命令の表」、設計書 02-07「命令」）。

/// 命令の種類。番号は 10-07 の命令の表のとおり。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
#[repr(u8)]
pub enum Opcode {
    Move = 0,
    LoadK = 1,
    GetCap = 2,
    Closure = 3,
    Call = 4,
    TailCall = 5,
    Return = 6,
    Prim = 7,
    Io = 8,
    Escape = 9,
    GetDict = 10,
    Dict = 11,
    Super = 12,
    Method = 13,
    TailMethod = 14,
    AddI = 16,
    SubI = 17,
    MulI = 18,
    DivI = 19,
    ModI = 20,
    NegI = 21,
    AddF = 22,
    SubF = 23,
    MulF = 24,
    DivF = 25,
    NegF = 26,
    AddD = 27,
    SubD = 28,
    MulD = 29,
    DivD = 30,
    NegD = 31,
    Concat = 32,
    EqI = 40,
    LtI = 41,
    LeI = 42,
    EqF = 43,
    LtF = 44,
    LeF = 45,
    EqD = 46,
    LtD = 47,
    LeD = 48,
    EqS = 49,
    LtS = 50,
    LeS = 51,
    EqC = 52,
    LtC = 53,
    LeC = 54,
    EqBt = 55,
    LtBt = 56,
    LeBt = 57,
    EqB = 58,
    EqV = 59,
    Not = 60,
    Con = 64,
    List = 65,
    Field = 66,
    ConR = 67,
    Jmp = 72,
    JmpF = 73,
    Switch = 74,
    Lazy = 80,
    Force = 81,
    Update = 82,
    Use = 83,
    Release = 84,
    Handle = 88,
    Perform = 89,
    Resume = 90,
}

impl Opcode {
    /// 番号から命令の種類を引く。知らない番号なら `None`（処理系の不具合）。
    pub fn from_u8(n: u8) -> Option<Opcode> {
        let op = match n {
            0 => Opcode::Move,
            1 => Opcode::LoadK,
            2 => Opcode::GetCap,
            3 => Opcode::Closure,
            4 => Opcode::Call,
            5 => Opcode::TailCall,
            6 => Opcode::Return,
            7 => Opcode::Prim,
            8 => Opcode::Io,
            9 => Opcode::Escape,
            10 => Opcode::GetDict,
            11 => Opcode::Dict,
            12 => Opcode::Super,
            13 => Opcode::Method,
            14 => Opcode::TailMethod,
            16 => Opcode::AddI,
            17 => Opcode::SubI,
            18 => Opcode::MulI,
            19 => Opcode::DivI,
            20 => Opcode::ModI,
            21 => Opcode::NegI,
            22 => Opcode::AddF,
            23 => Opcode::SubF,
            24 => Opcode::MulF,
            25 => Opcode::DivF,
            26 => Opcode::NegF,
            27 => Opcode::AddD,
            28 => Opcode::SubD,
            29 => Opcode::MulD,
            30 => Opcode::DivD,
            31 => Opcode::NegD,
            32 => Opcode::Concat,
            40 => Opcode::EqI,
            41 => Opcode::LtI,
            42 => Opcode::LeI,
            43 => Opcode::EqF,
            44 => Opcode::LtF,
            45 => Opcode::LeF,
            46 => Opcode::EqD,
            47 => Opcode::LtD,
            48 => Opcode::LeD,
            49 => Opcode::EqS,
            50 => Opcode::LtS,
            51 => Opcode::LeS,
            52 => Opcode::EqC,
            53 => Opcode::LtC,
            54 => Opcode::LeC,
            55 => Opcode::EqBt,
            56 => Opcode::LtBt,
            57 => Opcode::LeBt,
            58 => Opcode::EqB,
            59 => Opcode::EqV,
            60 => Opcode::Not,
            64 => Opcode::Con,
            65 => Opcode::List,
            66 => Opcode::Field,
            67 => Opcode::ConR,
            72 => Opcode::Jmp,
            73 => Opcode::JmpF,
            74 => Opcode::Switch,
            80 => Opcode::Lazy,
            81 => Opcode::Force,
            82 => Opcode::Update,
            83 => Opcode::Use,
            84 => Opcode::Release,
            88 => Opcode::Handle,
            89 => Opcode::Perform,
            90 => Opcode::Resume,
            _ => return None,
        };
        Some(op)
    }

    /// 逆アセンブラと診断に示す名前（大文字）。
    pub fn name(self) -> &'static str {
        match self {
            Opcode::Move => "MOVE",
            Opcode::LoadK => "LOADK",
            Opcode::GetCap => "GETCAP",
            Opcode::Closure => "CLOSURE",
            Opcode::Call => "CALL",
            Opcode::TailCall => "TAILCALL",
            Opcode::Return => "RETURN",
            Opcode::Prim => "PRIM",
            Opcode::Io => "IO",
            Opcode::Escape => "ESCAPE",
            Opcode::GetDict => "GETDICT",
            Opcode::Dict => "DICT",
            Opcode::Super => "SUPER",
            Opcode::Method => "METHOD",
            Opcode::TailMethod => "TAILMETHOD",
            Opcode::AddI => "ADDI",
            Opcode::SubI => "SUBI",
            Opcode::MulI => "MULI",
            Opcode::DivI => "DIVI",
            Opcode::ModI => "MODI",
            Opcode::NegI => "NEGI",
            Opcode::AddF => "ADDF",
            Opcode::SubF => "SUBF",
            Opcode::MulF => "MULF",
            Opcode::DivF => "DIVF",
            Opcode::NegF => "NEGF",
            Opcode::AddD => "ADDD",
            Opcode::SubD => "SUBD",
            Opcode::MulD => "MULD",
            Opcode::DivD => "DIVD",
            Opcode::NegD => "NEGD",
            Opcode::Concat => "CONCAT",
            Opcode::EqI => "EQI",
            Opcode::LtI => "LTI",
            Opcode::LeI => "LEI",
            Opcode::EqF => "EQF",
            Opcode::LtF => "LTF",
            Opcode::LeF => "LEF",
            Opcode::EqD => "EQD",
            Opcode::LtD => "LTD",
            Opcode::LeD => "LED",
            Opcode::EqS => "EQS",
            Opcode::LtS => "LTS",
            Opcode::LeS => "LES",
            Opcode::EqC => "EQC",
            Opcode::LtC => "LTC",
            Opcode::LeC => "LEC",
            Opcode::EqBt => "EQBT",
            Opcode::LtBt => "LTBT",
            Opcode::LeBt => "LEBT",
            Opcode::EqB => "EQB",
            Opcode::EqV => "EQV",
            Opcode::Not => "NOT",
            Opcode::Con => "CON",
            Opcode::List => "LIST",
            Opcode::Field => "FIELD",
            Opcode::ConR => "CONR",
            Opcode::Jmp => "JMP",
            Opcode::JmpF => "JMPF",
            Opcode::Switch => "SWITCH",
            Opcode::Lazy => "LAZY",
            Opcode::Force => "FORCE",
            Opcode::Update => "UPDATE",
            Opcode::Use => "USE",
            Opcode::Release => "RELEASE",
            Opcode::Handle => "HANDLE",
            Opcode::Perform => "PERFORM",
            Opcode::Resume => "RESUME",
        }
    }

    /// 第 1 段の VM が実装する命令か（10-07 の命令の表の段の欄が 1）。
    pub fn in_stage1(self) -> bool {
        match self {
            Opcode::Move
            | Opcode::LoadK
            | Opcode::GetCap
            | Opcode::Closure
            | Opcode::Call
            | Opcode::TailCall
            | Opcode::Return
            | Opcode::Prim
            | Opcode::Io
            | Opcode::AddI
            | Opcode::SubI
            | Opcode::MulI
            | Opcode::DivI
            | Opcode::ModI
            | Opcode::NegI
            | Opcode::AddF
            | Opcode::SubF
            | Opcode::MulF
            | Opcode::DivF
            | Opcode::NegF
            | Opcode::Concat
            | Opcode::EqI
            | Opcode::LtI
            | Opcode::LeI
            | Opcode::EqF
            | Opcode::LtF
            | Opcode::LeF
            | Opcode::EqS
            | Opcode::LtS
            | Opcode::LeS
            | Opcode::EqC
            | Opcode::LtC
            | Opcode::LeC
            | Opcode::EqB
            | Opcode::EqV
            | Opcode::Not
            | Opcode::Con
            | Opcode::List
            | Opcode::Field
            | Opcode::ConR
            | Opcode::Jmp
            | Opcode::JmpF
            | Opcode::Switch => true,
            Opcode::Escape
            | Opcode::GetDict
            | Opcode::Dict
            | Opcode::Super
            | Opcode::Method
            | Opcode::TailMethod
            | Opcode::AddD
            | Opcode::SubD
            | Opcode::MulD
            | Opcode::DivD
            | Opcode::NegD
            | Opcode::EqD
            | Opcode::LtD
            | Opcode::LeD
            | Opcode::EqBt
            | Opcode::LtBt
            | Opcode::LeBt
            | Opcode::Lazy
            | Opcode::Force
            | Opcode::Update
            | Opcode::Use
            | Opcode::Release
            | Opcode::Handle
            | Opcode::Perform
            | Opcode::Resume => false,
        }
    }
}

/// 64 ビットの命令。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct Instr(pub u64);

impl Instr {
    pub fn abc(op: Opcode, a: u16, b: u16, c: u16) -> Instr {
        Instr(u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(b) << 24) | (u64::from(c) << 40))
    }

    pub fn abx(op: Opcode, a: u16, bx: u32) -> Instr {
        Instr(u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(bx) << 24))
    }

    pub fn asbx(op: Opcode, a: u16, sbx: i32) -> Instr {
        Instr::abx(op, a, u32::from_ne_bytes(sbx.to_ne_bytes()))
    }

    /// 命令の種類。知らない番号なら `None`（処理系の不具合）。
    pub fn opcode(self) -> Option<Opcode> {
        Opcode::from_u8((self.0 & 0xff) as u8)
    }

    pub fn a(self) -> u16 {
        ((self.0 >> 8) & 0xffff) as u16
    }

    pub fn b(self) -> u16 {
        ((self.0 >> 24) & 0xffff) as u16
    }

    pub fn c(self) -> u16 {
        ((self.0 >> 40) & 0xffff) as u16
    }

    pub fn bx(self) -> u32 {
        ((self.0 >> 24) & 0xffff_ffff) as u32
    }

    pub fn sbx(self) -> i32 {
        i32::from_ne_bytes(self.bx().to_ne_bytes())
    }
}
```

`as` による数値の変換は、上の符号化の関数の中だけで使う。いずれも、マスクした後の値を、それが収まる幅の型に移すものである（[実装の規約](../00-common/00-02-conventions.md)の「数値の変換」）。

## コンパイル済みプログラム

02-07「コンパイル済みプログラム」の要素を構造体の欄にする。コンパイル済みプログラムは、生成の後に変更せず、スレッドの間で共有できる（`Send` と `Sync` を満たす。ADR 0015）。これをコンパイルの時点で確かめる関数を置く。

02-07 の要素のうち、次のものは本章で形を決める。

- 定数の記述は、プログラム全体で一つの並び（`CompiledProgram::consts`）に置き、原型は使う記述の番号の並び（`Proto::consts`）を持つ。`LOADK` の Bx は原型の並びの位置である。一つの並びに置くのは、同じ記述（同じトップレベルの定数、制約を持たない実装の辞書）を、どの原型から `LOADK` しても実行ごとに一度だけ作って共有するためである（02-07「定数表」、ADR 0158）。
- ハンドラの記述も、プログラム全体で一つの並び（`CompiledProgram::handlers`）に置き、原型は使う記述の番号の並び（`Proto::handlers`）を持つ。VM のハンドラの記録（10-09 の `HandlerRecord::desc`）は、プログラム全体の番号（`HandlerIdx` の値）を持つ。
- 分岐表は、最小実行版のとおり原型ごとに持つ。タグを添字とする跳ぶ先の並びと、表にないタグのときの跳ぶ先を持つ。跳ぶ先は、`SWITCH` の次の命令の位置からの相対位置である。`_` の分岐がない `case` では `default` に `None` を入れる。VM は、`targets` にないタグで `default` が `None` なら、処理系の不具合として止まる。
- 実装の表の上位の型クラスの辞書の作り方は、02-07「辞書とメソッドの呼び出し」の辞書の式を `DictRecipe` で表す。
- 組み込みの関数の参照（`BuiltinRef`）は、引数の数、権限（10-11 の `Capability`）、組み込みのエフェクトの操作ならその操作の番号を持つ。VM は、`PRIM`・`IO` の引数の数と `IO` の節の探索を、組み込みの関数の表を引かずにこの参照から決める。生存の情報（本章「生存の情報」）と読み込みのときの検証器も、コンパイル済みプログラムだけから命令の読むレジスタを決められる。

構成子のタグは、型の宣言の中で 0 から数えた番号である（02-07「コンパイル済みプログラム」）。VM の値の引数のない構成子（10-08 の `Value::Tag`）と構成子を適用した値の対象（`FieldsKind::Ctor` の `tag`）は、どちらもこのタグを持つ。構成子の表の位置（`CtorIdx`）はタグと別であり、`CON` と定数の記述だけが使う。関数の値の対象（`FieldsKind::Func`）の `tag` は原型の番号（`ProtoIdx` の値）、辞書の対象（`FieldsKind::Dict`）の `tag` は実装の番号（`ImplIdx` の値）である。

```rust file=src/bytecode/program.rs
//! 関数の原型とコンパイル済みプログラム（設計書 02-07「コンパイル済みプログラム」、実装プラン 10-07）。
//! 生成の後に変更せず、スレッドの間で共有する（ADR 0015）。

use std::sync::Arc;

use crate::base::{BindingId, SourceTable, Span};
use crate::builtins::BuiltinId;
use crate::builtins::iface::Capability;

use super::instr::{Instr, Opcode};
use super::liveness::LiveInfo;

/// 原型の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ProtoIdx(pub u32);

/// 定数の記述の並び（`CompiledProgram::consts`）の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ConstIdx(pub u32);

/// 構成子の表の番号（構成子のタグとは別）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct CtorIdx(pub u32);

/// 型クラスの表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct TraitIdx(pub u32);

/// 実装の表の番号。辞書の対象の `tag` に入れる。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct ImplIdx(pub u32);

/// 操作の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct OpIdx(pub u32);

/// 組み込みの関数の参照の並びの番号（`PRIM`・`IO` の B）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinRefIdx(pub u32);

/// ハンドラの記述の並びの番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct HandlerIdx(pub u32);

/// 原型の由来の種類（02-07「原型の名前と由来の種類」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ProtoOrigin {
    /// 利用者のトップレベルの関数（フィールドを取り出す関数を含む）
    UserFn,
    /// 利用者の実装のメソッド
    UserMethod,
    /// 利用者のラムダ（`<lambda>` と位置）
    UserLambda,
    /// 利用者の `handle` の本体（`<handle>` と位置）
    UserHandleBody,
    /// 利用者の `handle` の節（`<case 操作の名前>` と位置）
    UserHandleClause,
    /// 利用者の `lazy` の本体（`<lazy>` と位置）
    UserLazy,
    /// 標準ライブラリの公開の関数と実装のメソッド
    StdlibPublic,
    /// 標準ライブラリの補助の関数と、標準ライブラリのソースの中のラムダ・`handle` の本体と節・`lazy` の本体
    StdlibHelper,
    /// 値として使う組み込みの関数と操作
    BuiltinValue,
}

impl ProtoOrigin {
    /// 呼び出しの履歴に示すか（02-08「実行時エラーの情報の記録」の手順 1）。
    pub fn shown_in_trace(self) -> bool {
        self != ProtoOrigin::StdlibHelper
    }
}

/// 捕捉する値の取り方（02-07「関数の値と捕捉」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum CaptureSource {
    /// 作る側の関数のレジスタ
    Reg(u16),
    /// 作る側の関数が捕捉した値
    Capture(u16),
}

/// 定数の記述（02-07「定数表」、ADR 0083）。実行中の値そのものは置かない。
/// 子の記述を指す番号は、その記述自身の番号より小さい（VM は番号の小さい順に作れば子が先にできる）。
#[derive(Clone, PartialEq, Debug)]
pub enum ConstDesc {
    Int(i64),
    Float(f64),
    Str(String),
    Char(char),
    Bool(bool),
    Unit,
    Byte(u8),
    /// `Decimal` の値 `mantissa / 10^scale`（10-01 の `base::Decimal` の仮数と小数の桁数）。
    /// `base::Decimal` は C02 で置くので、C01 の本章は同じ二つの値を直接持つ
    Decimal { mantissa: i128, scale: u8 },
    /// 構成子を適用した値。`args` が空なら引数のない構成子（`Value::Tag`）
    Ctor { ctor: CtorIdx, args: Vec<ConstIdx> },
    List(Vec<ConstIdx>),
    /// 鍵の順に並べた組。同じ鍵は現れない
    Map(Vec<(ConstIdx, ConstIdx)>),
    /// 鍵の順に並べた要素。同じ要素は現れない
    Set(Vec<ConstIdx>),
    /// 何も捕捉しない関数の原型（トップレベルの関数、値として使う組み込みの関数と操作）
    Func(ProtoIdx),
    /// 制約の辞書を持たない実装の辞書
    Dict(ImplIdx),
}

/// `SWITCH` の分岐表。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct SwitchTable {
    /// タグを添字とする跳ぶ先。そのタグの分岐がなければ `None`
    pub targets: Vec<Option<i32>>,
    /// 表にないタグのときの跳ぶ先（`_` の分岐）
    pub default: Option<i32>,
}

/// ハンドラの記述の節一つ（02-07「コンパイル済みプログラム」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ClauseDesc {
    pub op: OpIdx,
    /// 末尾で再開する節か（ADR 0151）
    pub tail_resumptive: bool,
}

/// ハンドラの記述（`HANDLE` 一つにつき一つ）。節の並びは `HANDLE` の節の関数の並びと同じ順。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct HandlerDesc {
    pub clauses: Vec<ClauseDesc>,
}

/// 関数の原型。
#[derive(Clone, PartialEq, Debug)]
pub struct Proto {
    /// 呼び出しの履歴に示す名前（02-07「原型の名前と由来の種類」）
    pub name: String,
    pub origin: ProtoOrigin,
    /// ラムダ・`handle` の本体と節・`lazy` の本体を書いた位置（名前とともに示す）。ほかの原型では `None`
    pub span: Option<Span>,
    /// 関数の境界か（02-07「関数の境界」）。`ESCAPE` はこの印の呼び出しの枠で止まる
    pub boundary: bool,
    pub code: Vec<Instr>,
    /// `LOADK` の Bx が指す、定数の記述の番号の並び
    pub consts: Vec<ConstIdx>,
    pub switch_tables: Vec<SwitchTable>,
    /// `HANDLE` の C が指す、ハンドラの記述の番号の並び
    pub handlers: Vec<HandlerIdx>,
    pub num_regs: u16,
    pub num_params: u16,
    pub captures: Vec<CaptureSource>,
    /// 命令ごとの由来位置。`code` と同じ長さ。値として使う組み込みの関数と操作の原型では `None`
    pub positions: Vec<Option<Span>>,
    /// 命令ごとのメソッドの呼び出しの型クラス。`code` と同じ長さ。`METHOD`・`TAILMETHOD` の位置に
    /// `Some(型クラスの表の番号)`、ほかの位置に `None`（ADR 0310）。引数の並びの長さを
    /// `TraitInfo::methods[C].arity` から決めるために使う
    pub method_traits: Vec<Option<TraitIdx>>,
    /// 生存の情報（10-07「生存の情報」）
    pub live: LiveInfo,
}

/// 構成子の表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CtorInfo {
    /// 型の名前（`AdtDef::name`。モジュールで修飾しない）
    pub type_name: String,
    pub ctor_name: String,
    /// 型の宣言の中で 0 から数えたタグ
    pub tag: u32,
    pub arity: u16,
}

/// 型クラスのメソッド一つ。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct MethodInfo {
    /// メソッドの名前（型クラスの実装のメソッドの `Def::name` の最後の段。`show`）
    pub name: String,
    /// 引数の数（メソッド自身の制約の辞書の引数を含む）
    pub arity: u16,
}

/// 型クラスの表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TraitInfo {
    pub name: String,
    pub methods: Vec<MethodInfo>,
    /// 上位の型クラス（宣言の順）
    pub supers: Vec<TraitIdx>,
}

/// 上位の型クラスの辞書の作り方（02-07「辞書とメソッドの呼び出し」の辞書の式）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum DictRecipe {
    /// 実装の辞書。`args` はその実装の制約の辞書の作り方（制約を持たなければ空）
    Impl { imp: ImplIdx, args: Vec<DictRecipe> },
    /// この実装の i 番目の制約の辞書
    Param(u16),
    /// 上位の型クラスの `index` 番目の辞書
    Super { of: Box<DictRecipe>, index: u16 },
}

/// 実装の表の項目。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct ImplInfo {
    /// 表示のための名前（`Show[Person]`）
    pub name: String,
    pub trait_: TraitIdx,
    /// 実装の型パラメータの制約の辞書の数
    pub dict_arity: u16,
    /// メソッドの原型（型クラスのメソッドの順）
    pub methods: Vec<ProtoIdx>,
    /// 上位の型クラスの辞書の作り方（型クラスの上位の型クラスの順）
    pub supers: Vec<DictRecipe>,
}

/// 操作の表の項目（利用者のエフェクトの操作と組み込みのエフェクトの操作）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct OpInfo {
    /// エフェクトで修飾した名前（`Log.write`、`Console.writeLine`）。引き継いだハンドラの節の誤りの報告に使う
    pub name: String,
    /// エフェクトの名前（利用者のエフェクトは `name` の最後の `.` より前の `Log`、組み込みのエフェクトは `Console.Write`）
    pub effect: String,
    pub arity: u16,
    /// 組み込みのエフェクトの操作なら、対応する組み込みの関数の参照
    pub builtin: Option<BuiltinRefIdx>,
}

/// 組み込みの関数の参照（`PRIM`・`IO` の B が指す）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinRef {
    pub id: BuiltinId,
    pub arity: u16,
    /// 権限（10-11 の `BuiltinDecl::capability` と同じ）。生存の情報と VM が、待ちうる呼び出しかを決める
    pub capability: Capability,
    /// 組み込みのエフェクトの操作なら、その操作（`IO` が節を探す鍵）
    pub op: Option<OpIdx>,
}

/// `main` の戻り値の型。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MainKind {
    Unit,
    /// `Result[Unit, String]`
    Result,
}

/// コンパイル済みプログラム。
#[derive(Debug)]
pub struct CompiledProgram {
    pub protos: Vec<Proto>,
    pub consts: Vec<ConstDesc>,
    /// トップレベルの関数（標準ライブラリのソースの関数を含む）の束縛の番号から原型への対応
    pub top_fns: Vec<(BindingId, ProtoIdx)>,
    pub ctors: Vec<CtorInfo>,
    pub traits: Vec<TraitInfo>,
    pub impls: Vec<ImplInfo>,
    pub ops: Vec<OpInfo>,
    pub builtins: Vec<BuiltinRef>,
    pub handlers: Vec<HandlerDesc>,
    /// `main` の原型。コア IR の `Program::main` が `None`（`main` を検査しない経路）なら `None`
    pub main: Option<ProtoIdx>,
    /// `main` が `None` のときは `MainKind::Unit` を入れ、読まない
    pub main_kind: MainKind,
    /// 位置の表の span が指すソース（利用者のモジュールと、読んだ標準ライブラリのソース）
    pub sources: Arc<SourceTable>,
}

/// `PRIM`・`IO` の命令の被演算子（10-10 の要求と完了の処理が、引数と結果のレジスタを決めるのに使う）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinCallOperands {
    pub result: u16,
    pub builtin: BuiltinRefIdx,
    pub args_start: u16,
    pub arg_count: u16,
}

fn at<T>(items: &[T], index: u32) -> Option<&T> {
    usize::try_from(index).ok().and_then(|i| items.get(i))
}

impl CompiledProgram {
    pub fn proto(&self, idx: ProtoIdx) -> Option<&Proto> {
        at(&self.protos, idx.0)
    }

    pub fn constant(&self, idx: ConstIdx) -> Option<&ConstDesc> {
        at(&self.consts, idx.0)
    }

    pub fn ctor(&self, idx: CtorIdx) -> Option<&CtorInfo> {
        at(&self.ctors, idx.0)
    }

    pub fn trait_info(&self, idx: TraitIdx) -> Option<&TraitInfo> {
        at(&self.traits, idx.0)
    }

    pub fn impl_info(&self, idx: ImplIdx) -> Option<&ImplInfo> {
        at(&self.impls, idx.0)
    }

    pub fn op(&self, idx: OpIdx) -> Option<&OpInfo> {
        at(&self.ops, idx.0)
    }

    pub fn builtin(&self, idx: BuiltinRefIdx) -> Option<&BuiltinRef> {
        at(&self.builtins, idx.0)
    }

    pub fn handler(&self, idx: HandlerIdx) -> Option<&HandlerDesc> {
        at(&self.handlers, idx.0)
    }

    /// `PRIM`・`IO` の命令の被演算子。ほかの命令か、参照の番号が表にないときは `None`。
    pub fn builtin_call_operands(&self, instr: Instr) -> Option<BuiltinCallOperands> {
        let op = instr.opcode()?;
        if op != Opcode::Prim && op != Opcode::Io {
            return None;
        }
        let builtin = BuiltinRefIdx(u32::from(instr.b()));
        let arg_count = self.builtin(builtin)?.arity;
        Some(BuiltinCallOperands {
            result: instr.a(),
            builtin,
            args_start: instr.c(),
            arg_count,
        })
    }
}

impl Proto {
    /// `LOADK` の Bx が指す定数の記述の番号。
    pub fn constant(&self, bx: u32) -> Option<ConstIdx> {
        at(&self.consts, bx).copied()
    }

    /// `HANDLE` の C が指すハンドラの記述の番号。
    pub fn handler(&self, c: u16) -> Option<HandlerIdx> {
        at(&self.handlers, u32::from(c)).copied()
    }

    pub fn switch_table(&self, bx: u32) -> Option<&SwitchTable> {
        at(&self.switch_tables, bx)
    }
}

/// コンパイル済みプログラムがスレッドの間で共有できることを、コンパイルの時点で確かめる（ADR 0015）。
// 呼ばれない関数で、型の性質をコンパイルの時点で確かめる（00-02「`#[allow]` を書いてよい箇所」）。
#[allow(dead_code)]
fn assert_shareable() {
    fn check<T: Send + Sync>() {}
    check::<CompiledProgram>();
}
```

## 定数の記述

`LOADK` は、記述から値を作ってレジスタに置く（02-07「定数表」、ADR 0083）。ヒープを確保する記述（`Str`・`Decimal`・引数のある `Ctor`・`List`・`Map`・`Set`・`Func`・`Dict`）から作った値は、実行ごとの定数の値の表（10-09 の `RunState`。根として辿る）に `ConstIdx` を鍵として取っておき、同じ番号の二度目以降の `LOADK` は取っておいた値を使う。即値の記述（`Int`・`Float`・`Char`・`Bool`・`Unit`・`Byte`・引数のない `Ctor`）は、`LOADK` のたびに作る。子の記述の番号は親より小さいので、VM は子を先に作って表に置きながら、明示の積み重ねで親を作れる（Rust の再帰を使わない。[実装の規約](../00-common/00-02-conventions.md)の「再帰の深さ」）。マップと集合は、記述の順（鍵の順）のまま木にし、並べ替えない。

コード生成は、同じ記述を一つの番号にまとめる（`Float` はビットの並びで比べる）。コード生成は、次のものを記述にする。

| 下位 IR の値 | 記述 |
|---|---|
| `Const::Int`・`Float`・`Str`・`Char`・`Bool`・`Unit`・`Byte` | 同じ名前の記述 |
| `Const::Decimal(d)` | `Decimal { mantissa: d.mantissa(), scale: d.scale() }`。VM は `base::Decimal::new` で値に戻す |
| 引数のない構成子 `C[T̄]()` | `Ctor { ctor, args: [] }` |
| `TopFn`（何も捕捉しない関数） | `Func(その原型)` |
| 呼ばずに値として使う `Builtin`・`Op` | `Func(呼んで戻るだけの原型)`（02-07「値の移し方」） |
| 制約を持たない実装の辞書 `DictKind::Impl`（`args` が空） | `Dict(その実装)` |
| `ConstRef(k)` | 定数の値 `ConstDef::value`（10-05 の `ConstValue`）を次の表で移した記述 |

定数の値（[型と型検査](10-05-types.md)の `ConstValue`）は、次のように記述に移す。

| `ConstValue` | `ConstDesc` |
|---|---|
| `Integer`・`Float`・`String`・`Character`・`Boolean`・`Unit`・`Byte` | `Int`・`Float`・`Str`・`Char`・`Bool`・`Unit`・`Byte` |
| `Decimal` | 上の表の `Const::Decimal` と同じ |
| `Ctor { adt, tag, args }` | `Ctor { ctor: (adt, tag) の構成子の表の番号, args: 各要素の記述の番号 }` |
| `List` | `List`（要素の記述の番号の並び） |
| `Map` | `Map`（鍵の順のまま） |
| `Set` | `Set`（鍵の順のまま） |

## 生存の情報

生存の情報は、回収の前に VM が空にするレジスタを決める情報（命令ごとの入口の生きているレジスタと、呼び出しの命令の結果のレジスタ）と、命令ごとの項目（最後の使用と使わなくなったレジスタ）からなる（[ADR 0314](../../design/decisions/0314-clear-dead-registers-at-safepoints.md)）。R16 の後の VM が使うのは前者だけであり、後者は、参照カウント（タグ `stage1-rc-final`）との対応と、生存の情報のテストのために残す。第 1 段では、二つのメモリの管理が命令ごとの項目を同じく使った（ADR 0259 の決定 2）。生存の情報は、原型の命令列から求める（R05）。コード生成は、原型をすべて作った後に、原型ごとに `compute_liveness` を呼んで `Proto::live` に入れる。中間表現によらず命令列から求めるので、F15 のコード生成と、テスト用のバイトコードの組み立て（本章「第 1 段で実行するプログラム」）で、同じ関数を使える。

命令ごとの入口の生きているレジスタ（`LiveInfo::live_in_at`）は、命令 pc 以後のどこかの道筋で、書かれる前に読まれうるレジスタの集合（流れの解析の入口の集合）である。呼び出しの命令の結果のレジスタ（`LiveInfo::call_write`）は、呼び出しの命令の `reg_use` の `write` である。呼び出しの命令は、実行した枠が中断し、再開の前に結果のレジスタが書かれてから次の命令で再開する命令であり、`CALL`・`METHOD`・`HANDLE`・`FORCE`・`UPDATE`・`PERFORM`・`IO`・`RESUME` とする。`TAILCALL`・`TAILMETHOD`・`RETURN`・`ESCAPE` は再開しないので含めない。VM は、回収のために区間を閉じる前に、各枠の窓のレジスタのうち、ADR 0314 の決定 3 の集合に含まれないものを空にする（10-09「振り分けのループの局所の状態」）。

命令ごとの項目の意味は次のとおりである。R16 の後の VM はこれを読まない。

- `LastUse { reg, sole }`: この命令は、被演算子のレジスタ `reg` の値を読み、この後どの道筋でも `reg` を書く前に読まない。参照カウントの VM は、写さずに移した（`NoGcCtx::take`・`move_slot`）。`sole` は、同じ命令のほかの被演算子に `reg` がないことであり、その場での再利用（`NoGcCtx::reuse_ctor`）の条件である。
- `Dead { reg }`: `reg` はこの命令の被演算子として読まれず、この命令の前に値を持ちうるが、この命令から後のどの道筋でも書かれる前に読まれない。第 1 段の VM は、この命令を実行する前に `reg` を空にした（`NoGcCtx::clear`）。R16 の後は、回収の前に入口の生きているレジスタの集合で空にする。

[値とヒープ](10-08-values-and-heap.md)の「コード生成から受け取る生存の情報」の求めとの対応は次のとおりである。

| 10-08 が求める内容 | 本章の項目 |
|---|---|
| 命令ごとの、最後に使う被演算子のレジスタ | `LastUse` |
| 回収の前に空にするレジスタ | 枠の命令の位置の `live_in_at` の補集合。呼び出しの途中の枠では、さらに `call_write(pc − 1)` を空にしてよい（ADR 0314 の決定 3） |
| 命令ごとの、その命令の後に使わなくなるレジスタ（被演算子でないものを含む。参照カウントの対応のために残す） | 被演算子は `LastUse`、被演算子でないものは次の命令か跳ぶ先の命令の `Dead` |
| 呼び出しの命令ごとの、呼び出しをまたいで生きているレジスタ | `live_in_at(pc + 1)` から `call_write(pc)` を除いたもの |
| 最後に使う被演算子が、同じ命令のほかの被演算子と同じレジスタでないこと | `LastUse::sole` |
| 待つ組み込みの関数の呼び出しで、引数のレジスタを完了まで生かすこと | 下の規則 |
| その場での再利用の候補のレジスタが、その命令の後に読まれないこと | `CONR` の A の `LastUse`（本章「その場での再利用の命令」） |

生存の情報を求めるときの規則を次に定める。

- 命令が読むレジスタと書くレジスタは、`reg_use` で決める。引数の並びの数を命令が持たない命令（`PRIM`・`IO`・`DICT`・`METHOD`・`TAILMETHOD`・`HANDLE`・`PERFORM`・`CON`・`CONR`）は、コンパイル済みプログラムの表から数を読む。`METHOD`・`TAILMETHOD` の型クラスは、原型の `method_traits` から読む。`CONR` は、本章「その場での再利用の命令」のとおり A も読む。`CLOSURE` と `LAZY` は、作る原型の捕捉の表の `CaptureSource::Reg` のレジスタを読む。
- `IO` の引数と、`PRIM` のうち権限が `Pure` でない組み込みの関数の引数には、`LastUse` を付けない。これらの関数は待つことがあり、完了の処理が引数のレジスタを読み直す（10-11「作業用のスレッドの仕事」）。引数のレジスタは、次の命令か跳ぶ先の命令の `Dead` に現れる（VM は回収の前に入口の生きているレジスタの集合で空にする）。完了を待つ枠では、引数は命令の入口の生きているレジスタに含まれる。権限は `BuiltinRef::capability` で決める。
- `RETURN`・`TAILCALL`・`TAILMETHOD`・`ESCAPE` の後には道筋がないので、窓の残りのレジスタは項目にしない。VM が枠を降ろすときに窓全体を空にする（10-08 の同節の最後の段落）。
- 引数のレジスタ（0 から `num_params` − 1）も、ほかのレジスタと同じく扱う。

```rust file=src/bytecode/liveness.rs
//! コード生成が VM に渡す生存の情報（設計書 02-08「枠を降ろす原因と処理」、ADR 0259 の決定 2、
//! 実装プラン 10-07「生存の情報」）。回収の方式によらず同じ情報を使う。

use super::program::ProtoIdx;

/// 命令一つに付く生存の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum LiveItem {
    /// この命令が被演算子として最後に読むレジスタ。写さずに移してよい。
    /// `sole` は同じ命令のほかの被演算子に同じレジスタがないこと（その場での再利用の条件）
    LastUse { reg: u16, sole: bool },
    /// この命令の前に空にするレジスタ（被演算子でない）
    Dead { reg: u16 },
}

/// 原型一つの生存の情報。命令 i の項目は `items[starts[i]..starts[i + 1]]` である。
/// `starts` の長さは命令の数に 1 を足した数（空の原型では空でもよい）。
/// 命令 i の入口で生きているレジスタ（昇順）は `live_in[live_in_starts[i]..live_in_starts[i + 1]]`、
/// 命令 i が呼び出しの命令なら、その結果のレジスタは `call_writes[i]` である（ADR 0314）。
/// `live_in_starts` の長さは命令の数に 1 を足した数（`starts` と同じく 0 から始める。空の原型では `[0]`）、`call_writes` の長さは命令の数である。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct LiveInfo {
    pub starts: Vec<u32>,
    pub items: Vec<LiveItem>,
    pub live_in_starts: Vec<u32>,
    pub live_in: Vec<u16>,
    pub call_writes: Vec<Option<u16>>,
}

impl LiveInfo {
    /// 命令 `pc` の項目。範囲の外なら空。
    pub fn at(&self, pc: u32) -> &[LiveItem] {
        let Ok(i) = usize::try_from(pc) else {
            return &[];
        };
        let (Some(&start), Some(&end)) = (self.starts.get(i), self.starts.get(i.saturating_add(1)))
        else {
            return &[];
        };
        let (Ok(start), Ok(end)) = (usize::try_from(start), usize::try_from(end)) else {
            return &[];
        };
        self.items.get(start..end).unwrap_or(&[])
    }

    /// 命令 `pc` の入口で生きているレジスタ（昇順）。範囲の外なら `None`。
    pub fn live_in_at(&self, pc: u32) -> Option<&[u16]> {
        let i = usize::try_from(pc).ok()?;
        let start = usize::try_from(*self.live_in_starts.get(i)?).ok()?;
        let end = usize::try_from(*self.live_in_starts.get(i.checked_add(1)?)?).ok()?;
        self.live_in.get(start..end)
    }

    /// 命令 `pc` が呼び出しの命令なら、その結果のレジスタ。呼び出しの命令でないか範囲の外なら `None`。
    pub fn call_write(&self, pc: u32) -> Option<u16> {
        let i = usize::try_from(pc).ok()?;
        self.call_writes.get(i).copied().flatten()
    }
}

/// 命令一つが読むレジスタと書くレジスタ。
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct RegUse {
    /// 読むレジスタ（被演算子の順。同じレジスタが二度現れることがある）
    pub reads: Vec<u16>,
    /// 結果を書くレジスタ
    pub write: Option<u16>,
    /// 命令の後に続く道筋がない（`RETURN`・`TAILCALL`・`TAILMETHOD`・`ESCAPE`）
    pub terminal: bool,
}

/// 生存の情報を求められないとき（命令列の不整合。処理系の不具合）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct LivenessError {
    pub proto: ProtoIdx,
    pub pc: u32,
    pub message: String,
}
```

次の関数の中身は R05 が書く。道筋は、`JMP`・`JMPF`・`SWITCH` の跳ぶ先と次の命令から作り、後ろ向きのデータフロー解析で求める。

```rust sig=src/bytecode/liveness.rs
use super::program::CompiledProgram;

/// 原型 `proto` の命令 `pc` が読むレジスタと書くレジスタ（10-07「生存の情報」の規則の 1 つ目）。
pub fn reg_use(program: &CompiledProgram, proto: ProtoIdx, pc: u32) -> Result<RegUse, LivenessError>;

/// 原型 `proto` の生存の情報を求める。
pub fn compute_liveness(program: &CompiledProgram, proto: ProtoIdx) -> Result<LiveInfo, LivenessError>;
```

## モジュールの構成

```rust file=src/bytecode/mod.rs
//! バイトコードとコード生成（設計書 02-07）。
//! instr.rs: 命令の符号化、program.rs: コンパイル済みプログラム、liveness.rs: 生存の情報、
//! codegen.rs: コード生成、disasm.rs: 逆アセンブラ、verify.rs: 読み込みのときの検証器（OPEN-064）、
//! asm.rs: テスト用のバイトコードの組み立て（10-07「第 1 段で実行するプログラム」）。

#[cfg(test)]
pub(crate) mod asm;
pub mod codegen;
pub mod disasm;
pub mod instr;
pub mod liveness;
pub mod program;
pub mod verify;
```

## コード生成

コード生成は、02-07「コード生成」の表と、「関数の境界」「演算子の移し方」「分岐と合流の並べ方」「値の移し方」「レジスタの割り当て」「関数の値と捕捉」「末尾呼び出し」に従う。10-06 の下位 IR の形に合わせて、次の点を補う。

| 下位 IR | 命令 |
|---|---|
| `App` で `func` が `Builtin` | `info.intrinsic` があれば 02-07「演算子の移し方」の命令、`FORCE`、`UPDATE`。なければ `info.class` が `Io` なら `IO`、そうでなければ `PRIM`。`Intrinsic::Eq`・`Ne` は `targs` の 0 番の型で命令を選ぶ（基本型でない型、`Ty::Param`・`Ty::App`・`Ty::Rigid` は `EQV`） |
| `App` で `func` が `Op` | `PERFORM`（操作の表の番号） |
| `App` の `dicts` | 辞書を値の引数の前に、連続したレジスタに置く |
| `Method` | 辞書、メソッド自身の辞書 Ū、引数を連続したレジスタに置き、末尾位置なら `TAILMETHOD`、そうでなければ `METHOD`。C はメソッドの位置 |
| `DictVal` | 02-07「値の移し方」の辞書の行。`Impl` は制約を持たなければ `LOADK`（`ConstDesc::Dict`）、持てば `DICT`。`Super` は `SUPER`。`Param` は変数のレジスタか捕捉した値。`ImplParam` は、メソッドの原型の中では `GETDICT`、メソッドの中のラムダ・`lazy`・`handle` の原型の中では捕捉した値（作る側で `GETDICT` したレジスタを捕捉する） |
| `ValKind::ConstRef` | `LOADK`（本章「定数の記述」） |
| `CaseConst` | 定数の判定は 02-07 の `=` の命令と `JMPF`、区間の判定は `<=` の命令で下限と上限と比べて `JMPF` |
| `CaseLength` | リストの長さを返す内部の組み込みの関数の `PRIM`、`EQI`・`LEI` と `JMPF`（10-06「10-12 に求めるもの」） |
| `ListGet`・`ListSlice` | 前から i 番目・後ろから j 番目の要素、前と後を除いた部分を返す内部の組み込みの関数の `PRIM`。位置は `LOADK` した `Int` の定数で渡す |
| `Lazy` | 本体から引数のない原型を作り（関数の境界でない）、`LAZY` |
| `Handle` | 本体から引数のない原型を、各節から操作の引数と継続を引数とする原型を作り（どれも関数の境界でない）、それぞれを `CLOSURE` で連続したレジスタに置いて `HANDLE`。ハンドラの記述は、節の順に操作の番号と `tail_resumptive` を並べる |
| `Resume` | `RESUME r k v`。k は `cont` の変数のレジスタか捕捉した値 |
| `Escape` | 02-07 のとおり。実行中の原型が関数の境界なら `RETURN`、そうでなければ `ESCAPE` |
| `Use` | `USE v`、本体を末尾位置でなく移し、`RELEASE`。末尾位置なら続けて `RETURN r` |

- 自由な変数の捕捉（02-07「関数の値と捕捉」）では、`Lazy` と `Handle` の本体・節の原型も、ラムダと同じく自由な変数を捕捉する。`handle` の本体と節の原型は、囲む節の継続の変数（`ContVar`）も捕捉しうる（`resume` は `handle` の本体の中に書けるが、ラムダと `lazy` の本体の中には書けない。ADR 0155）。
- 構成子を適用した値は `CON` で作り、02-07「その場での再利用」の条件を満たす位置では `CONR` で作る（本章「その場での再利用の命令」）。条件は下位 IR の上で判定する。`let y ⇐ return x` で互いに束縛した変数（元の変数を含む）を同じ値として扱い、そのどれもが、その分岐の本体の、構成子を適用する位置より後で使われず、捕捉もされず、どれのレジスタも引数のレジスタと違うことを確かめる。`HeapConfig::reuse` によらず同じ命令を置く。
- 原型の由来の種類は、定義の `DefOrigin` と `DefKind`、本体の種類から決める。標準ライブラリのソースの中のラムダ・`handle`・`lazy` の原型は `StdlibHelper` とする。
- 組み込みの関数の参照と操作の表は、使うものだけを載せる。組み込みのエフェクトの操作の `BuiltinRef::op` と `OpInfo::builtin` は、互いを指す。

```rust sig=src/bytecode/codegen.rs task=C02 needs=10-02,10-06
use std::sync::Arc;

use crate::base::SourceTable;
use crate::diag::Diagnostic;
use crate::ir::InternalError;
use crate::ir::lower_ir::LowerProgram;

use super::program::CompiledProgram;

/// コード生成の失敗。
#[derive(Debug)]
pub enum CodegenError {
    /// 処理系の制限（原型ごとの L0101〜L0104 と、10-07「オペランドの補足」の表の大きさの制限 L0105〜L0111）。原型ごとの制限は当たった関数ごとに一つ、表の大きさの制限は表ごとに一つ
    Limit(Vec<Diagnostic>),
    Internal(InternalError),
}

/// 下位 IR からコンパイル済みプログラムを作る（02-07「コード生成」、10-07「コード生成」）。
pub fn codegen(program: &LowerProgram, sources: Arc<SourceTable>) -> Result<CompiledProgram, CodegenError>;
```

## 逆アセンブラ

逆アセンブラは、テストの失敗を調べるときと、設計者が生成したコードを読むときに使う。第 1 段では R09 が段が 1 の命令と本章の表の形に合わせて改め、F15 がほかの命令を加える。

```rust sig=src/bytecode/disasm.rs
use super::program::CompiledProgram;

/// コンパイル済みプログラムを、原型ごとに命令を一行ずつ並べた文字列にする。
/// 各行は命令の位置、命令の名前（`Opcode::name`）、オペランドを示す。形式はテストで比べない。
pub fn disassemble(program: &CompiledProgram) -> String;
```

## 読み込みのときの検証器

振り分けのループの範囲の確かめは、検証器を通したプログラムでも省かない（[ADR 0315](../../design/decisions/0315-keep-dispatch-range-checks.md)。ADR 0263 の決定 2 の評価は第 3 段の R32 が行った）。検証器は、テストでコード生成の出力の性質（番号とレジスタの範囲、生存の情報の形、呼ばれた原型の入口で生きているのは引数だけであること）を確かめる道具として残す。本番の読み込みの経路（`pipeline`、`runtime::run`、CLI）からは呼ばない。本章は関数の形だけを定める。検証器が確かめることの一覧は、R32 の[測定の記録](../../../tools/bench/results/2026-10-06-verify-2a30ba2.md)の「検証器が確かめること」にある。

検証器が確かめる主なものは、命令の種類の番号、レジスタの番号が窓の中にあること（引数の並びを含む）、原型・定数・分岐表・ハンドラの記述・構成子・実装・操作・組み込みの関数の参照の番号が表の中にあること、跳ぶ先が命令列の中にあること、`GETCAP` の番号が捕捉の表の中にあること、`Proto::live` の形（`starts`・`live_in_starts`・`live_in`・`call_writes` の長さと範囲）である。区画の所有、確保の失敗、実行時の上限、継続の使用済みは、検証器で保証できないので実行中に確かめる（ADR 0263 の決定 2）。

```rust sig=src/bytecode/verify.rs task=C02
use super::program::{CompiledProgram, ProtoIdx};

/// 検証器が受け付けなかった箇所。
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct VerifyError {
    pub proto: ProtoIdx,
    /// 命令の位置。原型の表の不整合では `None`
    pub pc: Option<u32>,
    pub message: String,
}

/// コンパイル済みプログラムを検証する（ADR 0263 の決定 2、OPEN-064）。R32 の評価に使う。
pub fn verify(program: &CompiledProgram) -> Result<(), VerifyError>;
```

## 未定のこと

本章を書く時点で決まっていなかった表の大きさの制限（本章「オペランドの補足」の 3 つ目）の診断は、02-07「処理系の制限」がプログラム全体の制限として定め、[10-02](10-02-diagnostics.md) が L0105〜L0111 を割り当てた（10-02「実行時エラー、資源の不足、処理系の制限」）。本章に未定のことは残っていない。

## 作業の割り当て

| 作業 | 本章で受け持つもの |
|---|---|
| C01 | `bytecode/mod.rs`・`instr.rs`・`program.rs`・`liveness.rs` を置く。`disasm.rs` は `sig=` の `todo!()` の仮置き（00-02）として、`asm.rs` は `mod.rs` の宣言に合わせた中身のないモジュールとして置く |
| C02 | `codegen.rs` と `verify.rs` のシグネチャ（どちらも C01 が `mod.rs` の宣言に合わせて作った中身のないモジュールを埋める） |
| R05 | `reg_use`・`compute_liveness`（`CONR` の A の `LastUse` を含む）、テスト用のバイトコードの組み立て（`asm.rs`。`CONR` を書けるようにする） |
| R09 | 段が 1 の命令の VM の処理（`CONR` のその場での再利用を含む）、逆アセンブラ（段が 1 の命令） |
| R20〜R25、R34 | 命令の表の VM の作業の欄の命令 |
| R35 | `Decimal`・`Byte` の算術と比較の命令、`Decimal` の定数の `LOADK` |
| F15 | 初回リリース版の下位 IR からのコード生成（`CONR` を置く条件の判定を含む）、逆アセンブラのほかの命令 |
| R32 | `verify` と、範囲の確かめを省く評価 |

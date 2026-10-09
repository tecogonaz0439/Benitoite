# R05 生存の情報とテスト用のバイトコードの組み立て

- 依存する作業: [C01](C01-stage1-interfaces.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R05-liveness-and-asm

## 目的

二つを作る。

一つは、原型の命令列から求める生存の情報（命令ごとの「最後に使う被演算子」と「この命令の前に空にするレジスタ」）である。二つのメモリの管理は、同じコード生成と同じ生存の情報から、値の写し・移動・最後の使用を決める（[ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 2）。参照カウントでは移動で数の増減を省き、マーク・スイープでは使わなくなったレジスタを根から除く。どちらの方式でも生きている値の集合が同じになるのは、この情報が一つだからである。

もう一つは、テスト用のバイトコードの組み立て（`bytecode::asm`）である。第 1 段の VM と二つのメモリの管理は、F15 のコード生成が揃うまで、手で組み立てたバイトコードのプログラムで確かめる（[ADR 0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 2、[10-07](../10-interfaces/10-07-bytecode.md)「第 1 段で実行するプログラム」）。R09・R11・R13 のテストがこれを使う。

## 読む設計書の節

- [バイトコードとコード生成](../../design/02-impl/02-07-bytecode.md)の「レジスタ型の命令」「命令」「分岐と合流の並べ方」「値の移し方」「末尾呼び出し」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「枠を降ろす原因と処理」の最後から 2 つ目の段落
- [ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)（決定 2）、[ADR 0277](../../design/decisions/0277-refcount-defers-freeing-to-safepoints.md)（決定 3）、[ADR 0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md)、[ADR 0280](../../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)（決定 2）
- インターフェース: [バイトコード](../10-interfaces/10-07-bytecode.md)の全体（とくに「第 1 段で実行するプログラム」「命令の符号化」「命令の表」「オペランドの補足」「コンパイル済みプログラム」「定数の記述」「生存の情報」「その場での再利用の命令」「モジュールの構成」）、[値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「コード生成から受け取る生存の情報」
- 経緯: [相談の第 2 回](../studies/u2-runtime/consult/02-frames-and-dispatch.md)の「要点」の 6

## 作るもの

- `src/bytecode/liveness.rs`: `reg_use`・`compute_liveness` の中身（10-07「生存の情報」）。
- `src/bytecode/asm.rs`: テスト用のバイトコードの組み立て。`mod.rs` の `#[cfg(test)] pub(crate) mod asm;` の宣言のとおり、テストのときだけコンパイルされる。インターフェースとして凍結しないので、形は本作業が決める。
- 上のファイルの中のテスト。

C01 は `sig=` の宣言を `todo!()` の仮置きとして置いている。本作業はその本体を書き換え、`liveness.rs` に `todo!()` が残らなければ仮置きの許可とコメントを消す（00-02「`todo!()` の仮置き」）。

## 手順の要点

### `reg_use`

命令の表（10-07「命令の表」）の 68 の命令すべてについて、読むレジスタ・書くレジスタ・後に道筋がないか（`terminal`）を返す。第 1 段の VM が実行しない段が 2 の命令も含める。F15 のコード生成が同じ関数を使うからである。

- 引数の並びの数を命令が持たない命令（`PRIM`・`IO`・`DICT`・`METHOD`・`TAILMETHOD`・`HANDLE`・`PERFORM`・`CON`・`CONR`）は、コンパイル済みプログラムの表（`BuiltinRef::arity`、`ImplInfo::dict_arity`、`MethodInfo::arity`、ハンドラの記述の節の数、`OpInfo::arity`、`CtorInfo::arity`）から数を読む。`METHOD`・`TAILMETHOD` のメソッドの引数の数は、辞書のレジスタからは決まらないので、原型の `method_traits` のその命令の位置の型クラスを引き、`TraitInfo::methods[C].arity` を使う（ADR 0310）。`method_traits` の項目が `None` のとき、長さが `code` と違うときは `LivenessError` を返す。テスト用の組み立て（`bytecode::asm`）は、`METHOD`・`TAILMETHOD` を置くときに型クラスを指定させ、`method_traits` を埋める。
- `CONR` の `reads` は、先頭に A（再利用の候補のレジスタ）、続けて引数の並びのレジスタとする。`write` は A である（10-07「その場での再利用の命令」）。
- `CLOSURE` と `LAZY` は、作る原型の捕捉の表の `CaptureSource::Reg` のレジスタを読む。
- 表を引いて項目がないとき、レジスタの番号の計算が溢れるときは、`LivenessError` を返す（処理系の不具合）。
- `reads` は被演算子の順に並べ、同じレジスタが二度現れてよい（`LastUse::sole` の判定に使う）。

### `compute_liveness`

道筋は、`JMP`・`JMPF`・`SWITCH` の跳ぶ先（分岐表の `targets` と `default`）と次の命令から作る。`terminal` の命令の後に道筋はない。跳ぶ先が命令列の外なら `LivenessError` を返す。

1. 後ろ向きのデータフロー解析で、命令ごとの入口と出口で生きているレジスタの集合を求める。命令 i の入口で生きているのは、i が読むレジスタと、i の出口で生きていて i が書かないレジスタである。
2. `LastUse { reg, sole }`: 命令 i が読むレジスタ r のうち、i の出口で生きていないもの、または i が r を書くもの。`sole` は、i の `reads` に r が一度だけ現れること。`CONR` の A の読み出しには `LastUse { reg: A, sole }` を付け、`sole` は A が引数の並びにないときに真とする（10-07「その場での再利用の命令」。A は同じ命令が書くので、つねに `LastUse` になる）。ただし、`IO` の引数と、`PRIM` のうち `BuiltinRef::capability` が `Pure` でない関数の引数には付けない（待つ関数の完了の処理が引数のレジスタを読み直すため。10-07「生存の情報」の規則の 2 つ目）。
3. `Dead { reg }`: 前向きのデータフロー解析で、命令の入口で値を持ちうるレジスタの集合 H を求める。入口の H は、先行する命令の出口の H の和であり、原型の先頭では引数のレジスタ（0 から `num_params` − 1）である。命令 i の `Dead` は、H のうち i が読まず、i の入口で生きていないレジスタとする。出口の H は、入口の H から `Dead` と `LastUse` のレジスタを除き、i が書くレジスタを加えたものである。こうすると、使わなくなったレジスタを一度だけ空にし、`LastUse` を付けなかった待つ関数の引数も、次の命令か跳ぶ先の命令で空にする。
4. `RETURN`・`TAILCALL`・`TAILMETHOD`・`ESCAPE` の後の残りのレジスタは項目にしない（VM が窓全体を空にする）。
5. 結果は `LiveInfo` の形（`starts` は命令の数に 1 を足した長さ、`items` は命令の順）にする。

呼び出しの命令（`CALL`・`METHOD`・`HANDLE`・`FORCE`・`UPDATE`、節を呼びうる `PERFORM`・`IO`）の `Dead` は、VM が呼ぶ前に空にする（10-07「生存の情報」）。この規則は VM の側（R09）の責任であり、本作業は項目を命令に付けるだけである。

### テスト用のバイトコードの組み立て

10-07「第 1 段で実行するプログラム」の求めは、次の手間を省くことだけである。

- 命令の符号化（`Instr::abc`・`abx`・`asbx`）を手で呼ぶ手間
- 原型の表、定数の記述の表と原型の定数の番号の並び、構成子の表、組み込みの関数の参照の表を埋める手間
- 跳ぶ先の相対位置を数える手間（名前の付いた印で書けるようにする）

形の例（本作業が決めてよい）:

```text
let mut p = ProgramBuilder::new();
let fib = p.proto("fib", 1 /* 引数 */, 4 /* レジスタ */);
let done = fib.label();
fib.loadk_int(1, 2);            // 定数の記述を加え、原型の並びの位置を LOADK に入れる
fib.op(Opcode::LtI, 2, 0, 1);
fib.jmpf(2, done);              // 印までの相対位置は finish で埋める
...
fib.place(done);
fib.ret(0);
let program = p.finish(main);   // 原型ごとに compute_liveness を呼んで Proto::live を埋める
```

- `finish` は、すべての原型に `compute_liveness` を呼んで `Proto::live` を埋める。生存の情報を手で書くことはさせない（二つの方式が同じ情報を使う前提を、テストでも崩さないため）。生存の情報を意図して壊したプログラムを作るテストのために、`live` を差し替える口を別に用意してよい。
- 位置の表（`Proto::positions`）は `None` で埋めてよい。`sources` は空の `SourceTable` でよい。
- 組み込みの関数の参照は、名前（`lookup_builtin`）か `BuiltinId` と、引数の数・権限・操作の番号で加えられるようにする。R08 の表ができる前でも使えるよう、`BuiltinId` を直接与える形も持つ。
- 分岐表（`SWITCH`）は、タグごとの印と `default` の印で書けるようにする。
- `CONR` を書けるようにする（R09・R11 のテストが使う）。
- `finish` が作る `CompiledProgram` の `main` は `Some(..)`（与えた原型）にする（10-07 の `CompiledProgram::main` は `Option<ProtoIdx>`）。`main` を `None` にしたプログラムも作れるようにしてよい（R09 の `start_main` のテストが使う）。
- 何度も同じ形で作るプログラム（数え上げの末尾再帰、末尾でない再帰、リストを作って辿る、構成子の木を作って辿る、捕捉のある関数）は、組み立ての例としてテストの補助の関数にしてよい。R09・R11・R13 がそのまま使える。

### 生存の情報を確かめる独立の計算

`compute_liveness` の結果は、別のやり方で計算した結果と比べて確かめる。テストのモジュールに、命令列の道筋を印の付いた深さ優先の探索で辿り、「命令 i の後、どの道筋でもレジスタ r を書く前に読まないか」をレジスタごとに直接調べる素朴な関数を書く（明示の積み重ねで書く）。無作為に作った小さな原型（分岐、合流、跳ぶ先の後ろ向きのもの、待つ `PRIM`・`IO` を含む）で、`LastUse` の集合が一致することと、`Dead` がどの道筋でも「空にしたレジスタを後で書く前に読む」ことを起こさないことを確かめる。無作為の値は、テストの中の小さな疑似乱数（xorshift など。依存を加えない。00-02「依存するクレート」）で作り、種を固定する。

## 受け入れテスト

- `reg_use`: 命令の表の各命令について、読むレジスタと書くレジスタが表の動作の欄と一致する（`PRIM`・`IO`・`CON`・`CONR`・`METHOD`・`HANDLE`・`PERFORM`・`DICT` の数は表から読む。`CLOSURE`・`LAZY` は捕捉の表から読む）。表にない番号は `LivenessError`。
- 直線の命令列: `MOVE 1 0; ADDI 2 1 1; RETURN 2` で、`ADDI` の `LastUse { reg: 1, sole: false }`、`RETURN` の `LastUse { reg: 2, sole: true }`。
- 分岐と合流: `JMPF` の両側の一方でだけ読むレジスタは、読まない側の先頭の命令に `Dead` が付く。合流の後で読むレジスタは、分岐の中で `LastUse` にならない。
- 後ろ向きの跳躍（ループ状の制御の流れ）: 跳ぶ先で読むレジスタが、跳ぶ前の命令で `LastUse` にならない（言語にループはないが、命令列の解析として正しいことを確かめる）。
- 待つ関数: 権限が `Io` の `IO` と、権限が `State` の `PRIM` の引数には `LastUse` が付かず、次の命令に `Dead` が付く。権限が `Pure` の `PRIM` の引数には `LastUse` が付く。
- 再利用の命令: `CONR` の A に `LastUse { reg: A, sole: true }` が付く。A が引数の並びにもあるときは `sole: false` になる。
- 末尾の命令: `TAILCALL`・`RETURN` の後のレジスタに項目が付かない。
- 引数のレジスタ: 一度も読まない引数のレジスタに、原型の先頭の命令で `Dead` が付く。
- 独立の計算との比較: 前述の無作為の原型で、`compute_liveness` と素朴な関数の結果が一致する（1,000 個以上の原型）。
- 組み立て: 組み立てたプログラムの各命令を `Instr::opcode`・`a`・`b`・`c`・`sbx` で読み直すと、組み立てのときに与えた値と一致する。印までの相対位置が 10-07「命令の符号化」の定め（跳ぶ命令の次の命令からの距離）と一致する。`CompiledProgram` の `assert_shareable` の条件（`Send + Sync`）を満たす。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- `reg_use` が命令の表の 68 の命令をすべて扱い、`match` に `_` の分岐がない（lint `wildcard_enum_match_arm`）
- 組み立ての `finish` が生存の情報を `compute_liveness` で埋める

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「コード生成（F15）と生存の情報（R05）」に加えて、次の点を読む。

- `LastUse` を付けてはならない引数（`IO` と、`Pure` でない `PRIM`）に付けていないか。付けると、待つ関数の完了の処理が空のレジスタを読む。
- `Dead` を、ある道筋で後に読むレジスタに付けていないか（独立の計算との比較がこれを確かめているか）。
- 解析の反復が必ず終わるか（集合の単調な増加で止まるか）。
- 組み立ての関数が、テストのときだけコンパイルされるか（`#[cfg(test)]` の外から使える形になっていないか）。

## 難易度の理由

データフロー解析そのものは標準的だが、10-07 の規則（待つ関数の引数、末尾の命令、`sole`）が VM とメモリの管理の正しさに直結し、誤りは後の作業の VM のテストで初めて現れる。命令の表の 68 の命令すべての読み書きを、表の定めと突き合わせる量もある。

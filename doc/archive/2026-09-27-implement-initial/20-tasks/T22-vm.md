# T22 仮想機械

- 依存する作業: [T10](T10-builtin-table.md)
- 難易度: 4（1〜5。README の「難易度の目安」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/T22-vm

## 目的

コンパイル済みプログラムを実行ごとの状態の上で実行する VM を実装する。言語の関数の呼び出しと戻りは、呼び出しの枠の積み重ねを操作するだけで行い、Rust の関数を入れ子に呼ばない。末尾呼び出しは呼び出しの枠を増やさず、呼び出しの情報の合計の大きさに上限を設ける。IO の命令は、直接呼び出しと要求と応答の二つの方式で実行でき、両方の観測できる振る舞いが一致する。

## 読む設計書の節

- [仮想機械](../../2026-09-27-design-initial/02-impl/02-08-vm.md)の全体（「値の表現」「実行ごとの状態のうち VM が使うもの」「実行の手順」「呼び出しの入れ子の上限」「組み込みの関数の呼び出し」「実行時エラーの情報の記録」「IO の命令」「実行の開始と終わり」）
- [バイトコードとコード生成](../../2026-09-27-design-initial/02-impl/02-07-bytecode.md)の「命令」「値の移し方」「関数の値と捕捉」「末尾呼び出し」
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「Int」（`DIVI`・`MODI` の実行時エラーの条件）
- [バイトコード](../10-interfaces/10-07-bytecode.md)の全体（命令の符号化、分岐表の形、定数の使い回し）
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md)の「止まる理由」「実行時の値」「IO の操作とハンドラ」「VM」
- [組み込みの関数](../10-interfaces/10-10-builtins.md)の「組み込みの表の型」「実装の関数」の `ops.rs`

## 作るもの

- `src/vm/mod.rs`: 10-08 の `sig=src/vm/mod.rs` の関数（`new`・`start_main`・`run`・`resume`・`heap`・`heap_mut`）。命令ごとの処理を非公開の関数に分けてよいが、言語の関数の呼び出しで Rust の関数を入れ子に呼ばない。
- 同じファイル（またはその下のテストのモジュール）のテスト。

## 手順の要点

### 状態と窓

- `regs` はすべての呼び出しの枠のレジスタをつなげた `Vec<Value>`。枠の窓は `regs[base .. base + size]` である。窓の中のレジスタ `R[i]` は `regs[base + i]` を `get`・`get_mut` で読み書きする。範囲の外は `Stop::Internal`。
- `cost` は `FRAME_COST × 枠の数 + REG_COST × 使っているレジスタの数（すべての窓の大きさの和）` を保つ。数の計算は `checked_*` で行い、溢れたら上限を超えたものとして扱う。
- `const_cache[proto][k]` は、`ConstDesc::Str` と `ConstDesc::Proto` から作った値を、初めて `LOADK` したときに入れて使い回す（10-07）。ほかの定数は毎回作る。

### 実行の開始

`start_main` は、`program.main` の原型から何も捕捉しない関数の値を `heap.func_proto` で作り、その原型のレジスタの数だけの窓を確保して、`call_site: None` の枠を積む。確保の前に上限を確かめ、超えれば `StopInfo`（`at: None`）を返す。

### 命令の振り分け

`run` は一つのループで、現在の枠の `pc` の命令を読み、`pc` を進めてから `match` で振り分ける。`Opcode::from_u8` が `None` なら `Stop::Internal`。命令の意味は 02-07「命令」と 10-07 のオペランドの決まりに従う。

- `MOVE`・`LOADK`・`GETCAP`（現在の枠の `func` の `FuncObj::Proto` の `captures[B]`）・`CLOSURE`（原型 `P[Bx]` の `captures` の各 `CaptureSource` に従い、`Reg(r)` は現在の窓の `R[r]`、`Capture(k)` は現在の関数の捕捉の k 番目を写して `heap.func_proto`）。
- 演算は `builtins::ops` の `int_*`（`ADDI`・`SUBI`・`MULI`・`DIVI`・`MODI`・`NEGI`）と `string_concat`（`CONCAT`）を呼ぶ。`Float` の演算と比較は Rust の `f64` の演算で書く。`EQV` は `values_equal`。`NOT` は `Bool` の否定。
- `PRIM A B C`: `program.builtins[B]` の `spec` の `kind` が `Pure(f)` なら、`R[C] .. R[C + arity − 1]` を `Vec` に写して `f(&mut heap, &args)` を呼ぶ。`Io` なら `Stop::Internal`。
- `IO A B C`: 後述。
- `CON A B C`: `program.ctors[B]` の `arity` 個の引数を `R[C]` から写し、`heap.ctor(tag, args)`。`LIST A B C`: `R[B] .. R[B + C − 1]` を `heap.list_from_vec(.., "list literal")`（レジスタの数は上限より小さいので、資源の不足にはならない）。`FIELD A B C`: `R[B]` の構成子の C 番目の引数。
- `JMP sBx`・`JMPF A sBx`: 跳ぶ先は、進めた後の `pc` に `sBx` を足した位置（10-07）。`SWITCH A Bx`: `R[A]` の構成子のタグで `switch_tables[Bx]` の `targets[tag]`、なければ `default`、どちらもなければ `Stop::Internal`。跳ぶ先の計算は `i64` で行い、範囲の外なら `Stop::Internal`。

### 呼び出しと戻り（02-08「実行の手順」）

- `CALL A B C`: `R[B]` が `FuncObj::Proto` の関数の値でなければ `Stop::Internal`（`FuncObj::Ref` も同じ）。呼ばれた原型の `num_regs` を `n` とし、`cost + FRAME_COST + REG_COST × n` が `max_call_stack_bytes` を超えるなら、呼び出しを行わずに `Stop::Resource(CallStackTooDeep { frames: 現在の枠の数 })` で止める（止まった命令はこの `CALL`）。そうでなければ、現在の窓の後ろ（`base + size`）から `n` 個のレジスタを確保し、引数 `R[B+1] .. R[B+C]` を新しい窓の 0 から写し、`ret_reg = base + A`、`call_site = Some(この CALL)` の枠を積む。
- `TAILCALL B C`: 関数の値と引数の値をいったんすべて写し取る（引数のレジスタと窓の先頭は重なりうる）。窓の大きさを呼ばれた原型の `num_regs` に合わせる。窓が大きくなるときは、先に上限を確かめる。窓の先頭から引数を置き、`func`・`proto`・`pc = 0`・`call_site = Some(この TAILCALL)` を置き換える。`ret_reg` は変えない。
- `RETURN A`: 結果を読み、窓のレジスタを `Unit` にし（ADR 0078。解放が遅れないように）、枠を降ろして `regs` を縮める。降ろした枠が最初の枠なら `VmStep::Finished(結果)` を返す。そうでなければ `regs[ret_reg]` に結果を入れて、呼び出し元の枠から続ける。
- 窓を縮めたときも、使わなくなったレジスタに `Unit` を入れる（`Vec::truncate` で捨てればよい）。
- `cost` は、枠を積む・降ろす・窓の大きさを変えるたびに更新する。

### 止まるときの記録（02-08「実行時エラーの情報の記録」）

命令が `Stop` を返したら、枠を一つも降ろさずに `StopInfo { stop, at: Some(InstrRef { proto, pc: その命令の位置 }), frames }` を作って `VmStep::Stopped` で返す。`frames` は枠の積み重ねを内側から外側の順に `FrameRecord { proto, call_site }` にしたものである。主な位置と呼び出しの履歴を作るのは T23 の `stop_diagnostic` であり、VM は材料だけを記録する。

### IO の命令（ADR 0029）

- `IO A B C` の B が `Pure` の組み込みの関数を指すとき（`PRIM` が `Io` を指すときと同じく）は、`Stop::Internal` で止まる。
- 直接呼び出し（`IoDispatch::Direct(h)`）: `program.builtins[B]` の `spec` の `kind` が `Io(op)` なら、引数を写して `h.call(op, &args, &mut heap)` を呼ぶ。`Ok(v)` なら `R[A] = v`、`Err(stop)` ならその命令で止まる記録を作る。
- 要求と応答（`IoDispatch::Request`）: `pc` を次の命令に進め、`pending_io = Some(base + A)` にして `VmStep::Request(IoRequest { op, args })` を返す。`resume(Ok(v))` は `regs[pending_io]` に `v` を入れる。`resume(Err(stop))` は `pending_stop` に入れ、次の `run` の始めに、止まる記録を作って返す（止まった命令は、一つ前の位置の `IO` の命令）。
- 直接呼び出しの方式では `Request` を返さない。

### 書き込みの失敗

ハンドラが `WriteFailed` の `Stop` を返したときも、VM はほかの `Stop` と同じく記録する。主な位置と履歴を作らないのは T23 の仕事である（02-08 の最後の段落）。

## 受け入れテスト

テストは、`Instr::abc` などで命令を組み、`Proto` と `CompiledProgram` を手で作って実行する。IO は T10 の `TestIo` を使う。テスト用の小さなプログラムを組み立てる補助をテストのモジュールに書く。

- 演算: `LOADK` で 7 と 2 を読み `DIVI`・`MODI` を行って `RETURN` するプログラムが、`-7 / 2` で `-3`、`-7 % 2` で `-1` を返す。除数が 0 なら `Stopped` で、`stop` が `DivisionByZero`、`at` が `DIVI` の位置、`frames` が一つ。
- 呼び出し: 引数を二つとる関数を `CALL` して足し算の結果を返す。`GETCAP` と `CLOSURE` で、外側のレジスタと外側の捕捉の値を捕捉した関数が正しい値を読む。
- 末尾でない再帰の上限: 自分を `CALL` する関数を、`max_call_stack_bytes = 10240` で実行すると `CallStackTooDeep` で止まり、`frames` の数（`StopInfo.frames.len()`）が報告の `frames` の値と一致し、`cost` の計算（`FRAME_COST` 96 と `REG_COST` 32）から求めた枠の数と一致する。
- 末尾呼び出し: 100 万回自分を `TAILCALL` して数え上げる関数が、`max_call_stack_bytes = 1024` でも止まらずに結果を返す。
- 窓の大きさの変わる末尾呼び出し: レジスタの数の違う二つの関数が互いに `TAILCALL` し合っても、結果が正しく、上限を超えない。
- 分岐: `SWITCH` で三つの構成子に分けたプログラムが、各タグで正しい分岐を選ぶ。`default` のない表にないタグで `Stop::Internal`。`JMPF` と `JMP` で `if` を表したプログラム。
- `LIST`・`CON`・`FIELD`・`EQV` の組み合わせ（`[1, 2] == [1, 2]` と `Some(3)` の引数の取り出し）。
- IO: `Console.println` に当たる `IO` の命令を二回行うプログラムを、直接呼び出しの方式と、要求と応答の方式（`Request` を受けて `TestIo::call` を呼び `resume` する繰り返し）で実行し、`TestIo` の事象の列が同じになる。応答が `Err(Stop)` のとき、止まった命令が `IO` の位置になる。
- 知らない命令の番号で `Stop::Internal`。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- `run` の中で、言語の関数の呼び出しのたびに Rust の関数を再帰して呼んでいない（振り分けのループは一つ）

## 難易度の理由

命令の一つ一つは短いが、レジスタの窓の確保と縮小、`TAILCALL` の引数の写し方、上限の数え方、止まるときの記録が互いに絡み、どれかを誤ると末尾呼び出しの保証（ADR 0013）か、値の解放の時期が崩れる。二つの IO の方式を一つのループで扱い、同じ振る舞いにすることも求められる。命令を手で組んだテストで確かめる必要があり、テストの準備の量も多い。

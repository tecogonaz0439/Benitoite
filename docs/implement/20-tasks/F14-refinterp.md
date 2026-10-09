# F14 参照インタプリタの評価

- 依存する作業: [R10](R10-refinterp-values.md), [C02](C02-remaining-interfaces.md), [R08](R08-builtin-table.md), [F11](F11-desugar.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）（テストを含む Rust の行数の目安）
- ブランチ: impl/F14-refinterp

## 目的

初回リリース版のコア IR を、01-12 の状態 `⟨M, K, σ⟩`・`error(r̄, K, σ)`・`exit(n, r̄, K, σ)` と遷移のとおりに実行する参照インタプリタを書く（ADR 0018・0213）。参照インタプリタは、VM との差分テスト（C05・C14）の正解であり、無作為に作ったプログラムで 01-12 の規則そのものを確かめる形式検証の段階 1 の実行可能な意味論でもある。利用者の経路（`pipeline` と `cli`）からは呼ばない。

値は R10 が作った `Rc` による値の型を使い、VM の値・ヒープ・VM とは共有しない。共有するのは組み込みの関数の本体だけであり、呼ぶときだけ引数をヒープの値に変換する（ADR 0276）。本作業は、R10 の値と変換の上に、評価（遷移のループ、継続、ストア、`match` の行の手順）を書き、10-06 の `run` を実装する。

依存に R08 と F11 を加えた。R08 は `builtins::builtin_decl` の中身と組み込みの関数の本体、第 1 段の `IoServices` の一時的な実装（テスト用の出力）を書く作業であり、本作業のテストはこれらを使う。F11 は、テストの入力を利用者のソースから作るための脱糖の補助の関数（後述の「受け入れテスト」）を置く作業である。ハンドラ・`with`・レコード・型クラスを含むコア IR を手で組むと、テストの入力の誤りと実装の誤りを切り分けにくいので、入力はソースから作る。

## 読む設計書の節

- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の「実行の規則」「末尾呼び出しの保証」と、「初回リリース版の拡張」の全体（「トップレベルの定数」「基本型とコレクションの型」「リストの展開」「レコード」「文字列補間」「型クラス」「ストア：可変のセルと明示遅延」「関数の境界と `escape`：途中の `return` と `try`」「解放の枠と実行時エラーの継続：`with`」「プロセスの終了」「エフェクトの名前と開始状態」「ハンドラ」「末尾呼び出しの保証の読み替え」）
- [中間表現と脱糖](../../design/02-impl/02-06-ir-and-lowering.md)の「コア IR」「パターンの拡張」「参照インタプリタの範囲」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「参照インタプリタ」
- [代数的データ型とパターンマッチ](../../design/01-spec/01-05-data-types.md)の「パターンの拡張（初回リリース版）」「match の意味」
- [リソース管理](../../design/01-spec/01-10-resources.md)の「解放の時期と順序」「解放の失敗」
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「差分テスト」
- ADR: [0016](../../design/decisions/0016-calls-off-go-stack.md)、[0018](../../design/decisions/0018-reference-interpreter.md)、[0159](../../design/decisions/0159-pattern-extensions-in-decision-trees.md)、[0160](../../design/decisions/0160-one-shot-continuations-as-stack-segments.md)、[0161](../../design/decisions/0161-single-threaded-task-scheduler.md)、[0213](../../design/decisions/0213-formal-verification-stage-1-in-first-release.md)、[0268](../../design/decisions/0268-staged-runtime-rebuild.md)（決定 2）、[0276](../../design/decisions/0276-reference-interpreter-shares-builtin-bodies.md)
- インターフェース: [中間表現](../10-interfaces/10-06-ir.md)の「値と計算を分ける形」「型、辞書、継続」「コア IR」「参照インタプリタ」、[組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「応答と待つ理由」「ランタイムの口」「文脈」「登録と第 1 段の扱い」と `builtin_decl`、[組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「項目の種類」「10-06 との対応」、[仮想機械](../10-interfaces/10-09-vm.md)の `MainOutcome`、[値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `Stop`・`ReleaseFailure`

## 作るもの

- `src/refinterp/mod.rs`: 10-06 の `sig=src/refinterp/mod.rs`（`RefOutcome` と `run`）。
- `src/refinterp/` の下の非公開の子のモジュール（遷移のループ、継続とストア、`match` の行の照合など。分け方は実装者が決める）。
- 各ファイルの `#[cfg(test)] mod tests`。

R10 が置いた値と変換の子のモジュール（`value.rs`・`convert.rs`）には、本作業が要る選択肢（ストアの場所の番号、リソース、辞書、操作の値、`Decimal` など）と関数を加え、既存の関数（`call`・`call_decl`・`to_heap`・`from_heap` など）を本作業に合わせて変えてよい。値の型を VM の値と共有する形に変えることはしない（ADR 0268 の決定 2）。`src/legacy/refinterp/` は読んで写してよいが、変えない。ほかのファイルは変えない。

## 手順の要点

### 状態と継続

- 実行中の計算は、コア IR の `&Comp` と、その計算の環境（`VarId` から値への表）の組で表す。01-12 は置き換え `M[V/x]` で意味を定めるが、環境で実装してよい。最小実行版の参照インタプリタ（`src/legacy/refinterp/`）の決め方（定義の呼び出しごとに `var_count` の大きさの環境を作る、ラムダの値は自由な変数の値を写して持つ、実行の前に `BodyId` から本体と自由な変数を引く表を一度作る）を引き継ぐ。`lazy` の本体、`handle` の本体と節も、`BodyId` で同じ表から引く。
- 継続 K は枠の `Vec` で持つ。枠は `let`（`VarId`、続きの計算、その環境）、`mark`、`update ℓ`、`release V`、`handle □ with H`（節の並びと、節を実行するときの環境）、`drop κ` の 6 種類である（02-08「参照インタプリタ」）。
- ストア σ は、場所の番号から中身への表で持つ。中身は、可変のセルの値、`thunk`（`lazy` の本体と環境）、`done(V)`、継続 `cont(K)`、`used` である。場所の番号は実行ごとに 0 から振り、使い回さない。
- 状態は、`⟨M, K, σ⟩` のほか、`return V` を続きに渡す状態、`escape V` の状態、`error(r̄, K, σ)`、`exit(n, r̄, K, σ)` を区別する。一つの遷移を一回の繰り返しとするループで書き、言語の関数の呼び出しのために Rust の関数を入れ子に呼ばない（ADR 0016）。

### 遷移

01-12 の規則を、次のように実行する。

| 規則 | 実行 |
|---|---|
| E-Let・E-Return | 最小実行版のとおり |
| E-Lam・E-Fun・E-Meth | 継続の先頭が `mark` でなければ `mark` を積んでから本体に進む（01-12「関数の境界と `escape`」）。型の置き換え θ は実行に影響しないので行わない。E-Meth は、辞書の実装の定義（`ImplDef`）からメソッドの定義を引き、実装の制約の辞書 d̄ を `DictKind::ImplParam` の値として環境に持たせる |
| E-Mark | `return V` で先頭が `mark` なら取り除く |
| E-Super・V-Super | `DictKind::Super` の辞書は、01-12 の E-Super で上位の辞書を一段ずつ取り出す（ADR 0305） |
| E-EscLet・E-EscMark | `escape V` は、`mark` に達するまで枠を取り除く。途中の `release`・`drop` の枠は、後述の解放の規則で処理する（E-EscRel・E-EscRelErr と、01-12「ハンドラ」の `drop` の段落） |
| E-Prim・E-Err・E-IO・E-IOErr | 後述の「組み込みの関数の呼び出し」 |
| E-RefNew・E-RefGet・E-RefSet | `Reference.new`・`get`・`set` の適用は、組み込みの関数の本体を呼ばず、ストアの規則で行う（01-12 は、この五つの関数に E-Prim などを使わないとする）。どの項目かは `builtin_decl(id)` の `name` で判定する |
| `Reference.update` | `intrinsic` が `Update` の適用は、01-12 のとおり `let x ⇐ Reference.get(ℓ) in let y ⇐ V(x) in Reference.set(ℓ, y)` と同じ遷移で行う。`raw` は呼ばない（10-12 の `raw` は `Stop::Internal` を返す） |
| E-Lazy・E-ForceDone・E-Force・E-Update | `Lazy` は `thunk` を作る。`intrinsic` が `Force` の適用は、`done(V)` なら V を返し、`thunk(M)` なら `update ℓ` の枠を積んで M に進む。`update` の枠に `return V` が届いたら `done(V)` にする |
| E-Use・E-Release・E-RelErr | `use V in M` は `release V` の枠を積む。枠に `return W` が届いたら解放を行う（後述の「解放」） |
| E-Handle・E-HRet | `handle` の枠を積んで本体に進む。本体の値は枠を取り除いて返す |
| E-Op | 利用者の操作（`ValKind::Op`）の適用と、組み込みのエフェクトの操作（`BuiltinInfo::class` が `Io` で `op` を持つ適用）で、継続にその操作の節を持つ `handle` の枠があるときに使う。最も内側の該当する枠までの枠の並び（その枠を含む）を写して `cont(K1 ++ [handle 枠])` として新しい場所 κ に置き、`drop κ` を積んだ継続で節の本体に進む（ADR 0160。参照インタプリタは区画を移さずに枠を写す）。節の引数と `ContVar` を環境に入れる |
| E-Resume・E-ResumeErr | `cont(K')` なら K' を今の継続の上に戻して κ を `used` にし、値を返す。`used` なら `RuntimeError::ContinuationResumedTwice` の `error` に移る |
| E-Drop・E-DropRel | `drop κ` の枠に `return V` が届いたとき、`used` なら取り除く。`cont(K')` なら `releases(K')`（K' の中の `release` と `drop` の枠だけを順序を保って並べたもの）を継続の先頭に加え、κ を `used` にする |
| E-Exit | 組み込みの関数の応答が `Reply::Exit` なら `exit(n, ·, K, σ)` に移る |
| E-ErrPop・E-ErrRel・E-ErrRelErr、E-ExitPop・E-ExitRel・E-ExitRelErr | `error` と `exit` の状態は、`release` 以外の枠を取り除き、`release` の枠では解放を行い、解放の失敗を r̄ の末尾に加える。`drop κ` の枠は、`cont(K')` なら `releases(K')` を先頭に加えて κ を `used` にする |
| `match` | 後述の「`match`」 |
| `ConstRef` | `ConstDef::body` を実行して値を求める。一度求めた値を定数ごとに覚えて使い回してよい（02-06「コア IR」の定数の段落）。定数の本体の実行も同じループで行い、Rust の再帰を使わない |

継続を伸ばすのは、01-12「末尾呼び出しの保証の読み替え」の遷移だけである。`mark` を連続して積まないので、末尾呼び出しを続けても継続は伸びない。

### 組み込みの関数の呼び出し

- `ValKind::Builtin` の適用は、`BuiltinInfo` の欄で分ける。`intrinsic` が `Force`・`Update` のものと、`Reference.new`・`get`・`set` は前節のとおりストアの規則で行う。そのほかは、`builtin_decl(id)` の `raw` を呼ぶ（`intrinsic` が演算子・`eq`・`ne` のものも `raw` を呼ぶ）。
- `class` が `Io` の適用は、先に継続から `op` の節を持つ `handle` の枠を探し、あれば E-Op で行う。なければ `raw` を `run` に渡された `IoServices` で呼ぶ（01-12「ハンドラ」の 2 つ目の箇条）。`State` と `Pure` の適用はハンドラを調べない（ADR 0150）。
- `raw` を呼ぶときは、参照インタプリタが自分の `Heap`（10-08）を持ち、R10 の変換で引数をヒープの値にし、10-11 の文脈（`CallCtx::new`。`io` は `Io` の関数だけに渡す）を作って呼び、結果を R10 の変換で参照インタプリタの値に戻す。`runtime::heap` の公開の層の関数だけを使う（ADR 0276 の帰結）。
- 応答の扱い: `Reply::Done` は E-Prim・E-IO、`Err(Stop)` は E-Err・E-IOErr、`Reply::Exit` は E-Exit。`Reply::Wait` のうち作業用のスレッドの仕事は、第 1 段の VM と同じく、その場で仕事を実行して完了の処理（`WorkerDone::complete`）で結果を作る（10-11「登録と第 1 段の扱い」）。ほかの待つ理由は `Stop::Internal` にする。
- `Reply::SpawnTasks` を返した関数と、タスクとタスクの集まりの関数（`Task.*`・`TaskGroup.*`）に出会ったら、実行をやめて `RefOutcome::Unsupported(その関数の修飾した名前)` を返す（02-06「参照インタプリタの範囲」）。応答を見る前に名前で判定してよい。

### 解放

01-12 の `release(V)` の事象は、リソースの表の項目を解放し、成否によらず解放したことにする（02-08「リソースの解放の枠」）。10-06 の `run` は `IoServices` だけを受け取り、`IoServices`（10-11）は開いたリソースを加える `register_resource` を持つが、解放する関数を持たない。そこで本作業は、リソースの表を参照インタプリタの中に持つ（本プランの決定。凍結した型とシグネチャは変えない）。

- 組み込みの関数を呼ぶときの `CallCtx::new` には、渡された `IoServices` を包む非公開の型と、参照インタプリタの `StateServices` の実装を渡す。包む型は、`register_resource` だけを自分のリソースの表（`ResourceId` を 0 から振り、`Box<dyn OsResource>` と解放済みの印を持つ）に加え、ほかの関数は渡された `IoServices` に任せる。
- 作業用のスレッドの仕事をその場で実行するとき、`Lend::Resource` はこの表から借りる。共有の `builtins/table.rs` の `complete_worker` は `Lend::Nothing` の仕事だけを扱うので、借りる仕事では使わず、refinterp の中で `WorkerWait::lend` を見て表から借り、`WorkerWait::run(Lent::Resource(..))` と `WorkerDone::complete` を直接呼ぶ（`builtins/table.rs` は変えない）。この経路を使う組み込みの関数（`File.readLine` など）の本体は R29 が書くので、この経路の実行のテストは R29 の後の C14 に回してよい。解放済みのリソースを借りようとしたら、VM と同じ実行時エラー（`ReleasedResourceUsed`）にする。
- `release V` の枠の解放と `StateServices::begin_release`（`File.closeReader`）は、表の項目の `OsResource::release` をその場で呼び、項目を解放済みにする。失敗はリソースの型の規則（02-09「リソースの追跡」）に従って r̄ に加えるか無視する。解放済みのリソースの解放は何もしない。
- `StateServices` のうち `open_task_group` と `task_poll` は、タスクを使うプログラムを実行しない（`Unsupported`）ので呼ばれない。呼ばれたら `Stop::Internal` を返す。

### `match`

02-06「パターンの拡張」の手順で実行する（ADR 0159）。判定の木は使わない。

1. 行（`MatchRow`）を元の順に調べ、パターンが照合した最初の行を選ぶ。照合は 01-12 の `match(p, V)` に、範囲（両端を含む）とリストのパターン（`before` の要素、`rest` の残り、`after` の要素。長さが足りなければ照合しない）を加えたものである。定数どうしは `=` の意味で比べる（`String` は中身、`Decimal` は数）。
2. その行の分岐（`arms[row.arm]`）にガードがなければ、変数を束縛して本体に進む。ガードがあれば、変数を束縛した環境でガードを実行し、`true` なら本体に、`false` なら同じ分岐の残りの行を飛ばして、次の分岐の行から調べ続ける。
3. どの行も選ばれなければ `Stop::Internal`（網羅性は型検査が保証する）。

ガードの実行は、ほかの計算と同じループで行う（ガードの結果を受け取る専用の枠を一つ加えてよい）。パターンの照合そのものは、パターンの深さで Rust の再帰を使ってよい（パターンの深さは構文解析器が抑える。00-02「再帰の深さ」）。値の比較（`=`）とリストの走査は、実行時の値を辿るので明示の積み重ねで書く。

### 始まりと終わり

- `program.main` が `None` なら、実行せずに `Stop::Internal` の `Stopped` を返す（10-06 の `run`）。
- `program.main` の定義を引数なしで呼ぶ状態 `⟨main[;](), [], ∅⟩` から始める（01-12「エフェクトの名前と開始状態」）。
- `return V` が空の継続に届いたら、`main_returns_result` が偽なら `MainOutcome::Ok`、真なら `Result.Ok(())` を `Ok`、`Result.Error(msg)` を `Error(msg)` にして `Finished` を返す。構成子の判定は 10-12 の `table::tags` のタグで行う。
- `error(r̄, [], σ)` に達したら `Stopped`。`stop` は r̄ の先頭、`release_failures` は残り、`origin` は最初の r を生じた計算（組み込みの関数の適用、`resume`、解放）の由来位置とする。
- `exit(n, r̄, [], σ)` に達したら `Exited`。
- 資源の上限（呼び出しの入れ子の上限）は設けない。資源の不足で止まるプログラムは差分テストの対象から外す（07-03「差分テスト」）。作る値の大きさの上限は、組み込みの関数の本体が確かめる。

## 受け入れテスト

テストの入力は利用者のソースとし、F11 の脱糖の補助の関数（`#[cfg(test)] pub(crate)`。メモリの上のソースから `CoreProgram` を作る）で作る。IO は R08 の第 1 段の `IoServices` の一時的な実装のテスト用の出力で受ける。テストのソースは、[構文](../../design/01-spec/01-02-syntax.md)の「初回リリース版の文法の全体」で書く。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 値で終わる | `main` が `()` を返す | `Finished(MainOutcome::Ok)` |
| `main` のないプログラム | `CoreProgram::main` が `None` | `Stopped { stop: Stop::Internal(..) }` |
| `Result` の `main` | `main` が `Result.Error("bad")` を返す | `Finished(MainOutcome::Error("bad"))` |
| IO の順序 | `Console.writeLine("a")` の後に `Console.writeLine("b")` | 出力が `a`、`b` の順 |
| 深い末尾再帰 | 自分を末尾で呼ぶ関数を 1,000,000 回（debug ビルドで遅すぎるなら 100,000 回に減らしてよい） | 継続の長さが増えずに終わる（継続の最大の長さをテストの口で確かめる） |
| 末尾でない再帰 | `1 + f(n - 1)` の形を深さ 100,000 | 正しい値で終わり、Rust のスタックを使い果たさない |
| 実行時エラー | `1 div 0` | `Stopped { stop: 0 による除算, origin: その演算の由来位置 }` |
| 途中の `return` | 再帰する補助の関数を呼ぶ関数の本体の、`if` の中から `return` する | `escape` が関数の境界で止まり、呼び出し元の続きを実行する |
| `try` | `Result.Error` を返す関数に `try` を付けて呼ぶ関数 | 誤りの値がそのまま呼び出し元に返る |
| `lazy` | 同じ `Lazy` の値を二度 `Lazy.force` し、本体で値を作る | 二度とも同じ値。本体は一度だけ実行される（本体に `Reference` を使えないので、`update` の枠の数え方で確かめる） |
| `Reference` | `Reference.new`・`set`・`get`・`update` | 01-12 のストアの規則どおりの値 |
| 利用者のハンドラ | `Log.write` を二度呼ぶ本体と、`resume(())` する節 | 節が二度実行され、本体の続きが実行される |
| 再開しない節 | 節が `resume` を呼ばずに値を返す | `handle` の式の値が節の値になり、本体の続きは実行されない |
| 継続の二度目の再開 | 同じ節の中で `resume` を二度呼ぶ（型検査を通る形。条件で分けて二度目に達する） | `Stopped { stop: ContinuationResumedTwice }` |
| 組み込みの操作の差し替え | `Console.writeLine` の節を持つ `handle` の中で `Console.writeLine` | 出力されず、節が実行される |
| ハンドラの外の組み込みの操作 | 同じ本体を `handle` の外で | 出力される |
| `match` の選択肢とガード | `case 1, 2 if x > 0 -> …`、`case 1 -> …` の並びで、ガードが `false` になる値 | 同じ分岐の残りの行を飛ばし、次の分岐を選ぶ |
| 範囲とリストのパターン | `case 'a'..'z'`、`case [first, ..rest]`、`case [.., last]` | 01-05「パターンの拡張」どおりに選び、変数に正しい値が入る |
| レコード | 構築、一部を変えた値、フィールドを取り出す関数 | 01-12「レコード」どおりの値 |
| 型クラス | 上位の型クラスを持つ型クラスの制約付きの関数を、二つの実装で呼ぶ | 実装ごとのメソッドが選ばれる |
| 定数 | 定数を二つの関数から参照する | 同じ値 |
| `Process.exit` | 出力の後に `Process.exit(3)` | `Exited { status: 3 }` |
| タスク | `Task.all` を呼ぶ | `Unsupported("Task.all")` |
| 解放の順序 | 入れ子の `with`（リソースは、テストの補助が表に直接加えたテスト用の `OsResource`（解放の成否を与えられる）を指す値とする。`File.openReader` の本体は R29 が書くので使わない。前述の「解放」） | 内側から順に解放し、`escape`・実行時エラー・`Process.exit`・再開しない節の続きの中の解放も一度ずつ行う |

`Process.exit`・`with` の `File.Reader` など、本体を R29 が書く組み込みの関数を使う場合は、R29 の取り込みの前は `Stop::Internal` になる。本作業のテストは、R08 が本体を書いた関数と、利用者の操作・ハンドラで確かめ、R29 の関数を使う場合は R29 の後に C14 の差分テストで確かめる（`Process.exit` の遷移は、応答が `Reply::Exit` の関数を差し込んだテストで確かめてよい）。

組み込みの関数を差し込むテスト（`Process.exit` と、上の「解放の順序」のテスト用のリソースを返す関数）のために、refinterp の中に `#[cfg(test)]` の差し替えの表（組み込みの関数の番号から `BuiltinDecl` を引く表。`BuiltinBridge` が `builtin_decl(id)` より先に引く）を置いてよい。差し替える本体は 10-11 の `builtin!` マクロで書く（内部の共通の形を直接書かない）。リソースを返す本体は、`register_resource` でテスト用の `OsResource`（解放の成否を与えられる）を登録し、リソースの値を返す。テストのソースは、差し替えた組み込みの関数（例: `File.openReader`）を呼んでリソースを得る。マクロの制約などでこの差し替えが書けないときは、そのテストを C14 に回し、完了の報告の「残したこと」に書く（止まらない）。

`ReleaseFailure::opened_at` は、参照インタプリタが命令を持たないので `None` にする。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある（R29 の後に回した場合は、完了の報告の「残したこと」に挙げる）
- 実行のループの中で、言語の関数の呼び出しのために Rust の関数を入れ子に呼んでいない
- 値の型が VM の値の型（`runtime::heap::Value` など）と別であり、組み込みの関数を呼ぶときだけ変換している

## 確認の観点

- 01-12 の遷移の各規則に、ループの処理が一対一に対応しているか。とくに `escape`・`error`・`exit` が `release`・`drop`・`handle`・`update` の枠を通るときの処理が、規則の表のとおりか。
- E-Op が写す枠の範囲が「最も内側の該当する `handle` の枠まで（その枠を含む）」であり、`drop κ` を積んだ後の継続が `K2` になっているか。
- `mark` を連続して積んでいないか。末尾呼び出しで継続が伸びないか。
- `match` のガードが `false` のとき、同じ分岐の残りの行を飛ばしているか（ADR 0159）。
- 組み込みの関数を呼ぶ経路が、ストアの規則で行う五つ（`Reference.new`・`get`・`set`・`update`、`Lazy.force`）と、タスクの関数を除いて、すべて `raw` を通っているか。組み込みの関数の意味を参照インタプリタの中で書き直していないか（ADR 0276）。
- リソースの表を参照インタプリタの中に持ち（前述の「解放」）、凍結したシグネチャを変えていないか。

## 難易度の理由

最小実行版の参照インタプリタは `let` の枠だけを持っていたが、初回リリース版は 6 種類の枠とストアを持ち、`escape`・`error`・`exit` がそれぞれ別の規則で枠を降ろす。E-Op の継続の写しと E-DropRel の入れ子の解放は、規則を一つずつ移さないと取りこぼしやすい。差分テストの正解なので、誤りがあると VM の正しい振る舞いを誤りと判定してしまう。規則の表は 01-12 にそろっており、組み込みの関数の意味を書かずに済むので、難易度は 4 とした。

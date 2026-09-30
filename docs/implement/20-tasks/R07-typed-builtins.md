# R07 組み込みの関数の型付きの形

- 依存する作業: [R06](R06-values-and-lists.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R07-typed-builtins

## 目的

組み込みの関数を型付きの形（[ADR 0261](../../design/decisions/0261-typed-builtin-interface.md)）で書けることを、代表的な三つの関数で確かめる（決定 7）。純粋な関数、文字列を作る関数、作業用のスレッドで待つ関数を `builtin!` で一つずつ書き、内部の共通の形（`raw`）を通して呼び、誤った引数の型・結果の型・権限・捕捉がコンパイルで止まることを確かめる。あわせて、VM と参照インタプリタが組み込みの関数を呼ぶときに使う呼び出しの補助と、構成子のタグの定数を置く。

`builtin!` のマクロ、文脈（`PureCtx`・`IoCtx`・`StateCtx`）、応答、引数の読み出し（`FromValue`・`FromArg`）、結果の変換（`IntoValue`）は、C01 が 10-11 の `file=` として置いてある。本作業はそれを使って書き、形の不備が見つかったら報告する。R08 が既存の組み込みの関数をこの形へ移すので、本作業で形の使い勝手を確かめておく。

## 読む設計書の節

- [仮想機械](../../design/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」「一つの操作で作る値の大きさの上限」
- [ADR 0049](../../design/decisions/0049-size-limit-for-built-values.md)、[ADR 0261](../../design/decisions/0261-typed-builtin-interface.md)
- インターフェース: [組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の全体、[組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「構成子のタグ」、[値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「大きさを確かめる構築」
- 共通の決まり: [実装の規約](../00-common/00-02-conventions.md)の「組み込みの関数の書き方」「テストの規約」
- 経緯: [相談の第 1 回](../studies/u2-runtime/consult/01-memory-and-values.md)の「要点」の 6（内部の共通の形を実装者にそのまま見せない理由、完了の処理を閉包でなく `fn` ポインタにする理由）

## 作るもの

- `src/builtins/table.rs`:
  - 10-12 の `sig=src/builtins/table.rs task=C01` のブロック（`pub mod tags`）を、そのまま写して置く（10-12「置く作業と既存のファイル」）。
  - VM と参照インタプリタが組み込みの関数を呼ぶための補助（後述）。`pub(crate)` の関数とする。
- `src/builtins/funcs/mod.rs`: `#[cfg(test)] pub(crate) mod samples;` の宣言を加える（00-03「ブランチと並行作業」の、`funcs/mod.rs` に子のモジュールを加えてよい例外）。
- `src/builtins/funcs/samples.rs`: 三つの見本の関数と、そのテスト。テストのときだけコンパイルされる。
- `src/builtins/iface.rs` の `builtin!` の `///` のコメントに、10-11「コンパイルの失敗のテスト」の例をすべて置く（`compile_fail` と `no_run` の対）。10-11 がこの置き場所を定めている。`iface.rs` は C01 が置いた凍結したファイルであり、00-03「インターフェースの凍結」の例外の一覧にないので、コメントに例を足すこと以外は変えず、完了の報告の「判断したこと」に挙げる。

C01 は `sig=` の宣言を `todo!()` の仮置きとして置いている。本作業は受け持つ関数の本体を書き換え、ファイルに `todo!()` が残らなければ仮置きの許可とコメントを消す（00-02「`todo!()` の仮置き」）。`builtins/table.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が許可を消す。

## 手順の要点

### 三つの見本

見本は 10-11「例」の三つを写す。名前は表の名前と重ならないよう、`Sample.` で始める（例: `Sample.absolute`、`Sample.repeat`、`Sample.readText`）。本番の組み込みの関数（`Integer.absolute`・`String.repeat`・`Benitoite.IO.File.readText`）は R08 が表の中に書く。本作業の見本の本体を R08 が写してよい。

| 見本 | 権限 | 確かめること |
|---|---|---|
| 整数の絶対値 | `pure` | 溢れ（`i64::MIN`）で `Stop::Runtime(RuntimeError::IntegerOverflow)` を返す。引数の読み出しと結果の変換がマクロで作られる |
| 文字列の繰り返し | `pure` | `StrBuf` か、結果の大きさを先に計算して `CheckedLen` で確かめる形で書き、上限を超えると値を作る前に `ResourceError::ValueTooLarge` を返す（02-09 の計算の例のとおり、`n` が「上限 ÷ `s` のバイト数」を超えるかで先に判定する形が望ましい） |
| ファイルを読む | `io` | `IoReply::Wait(IoWait::Worker(WorkerWait::new(...)))` を返す。仕事の閉包は `Send + 'static` の値（`PathBuf`）だけを捕え、完了の処理は環境を捕えない `fn` ポインタで、UTF-8 と上限を確かめて `Result.Ok` か `Result.Error` を作る（`IOError` の値は `FieldsKind::IoError` と `tags` の `IO_ERROR_KIND_*` で作る） |

### 呼び出しの補助

VM（R09）と参照インタプリタ（R10・F14）は、組み込みの関数を同じ手順で呼ぶ。`BuiltinDecl` と `NoGcCtx`・`IoServices`（ない場合は `None`）・呼んだ命令・引数の並びを受け取り、`CallCtx::new` で文脈を作って `raw` を呼び、`Reply` を返す関数を `table.rs` に `pub(crate)` で置く。形は本作業が決め、`///` に使い方を書く。

- 権限と渡された口が合わない（`io` の関数に `IoServices` がない、`state` の関数に `StateServices` がない）ときは `Stop::Internal` を返す。第 1 段の VM は `StateServices` を持たないので、`state` の関数を呼ぶと `Stop::Internal` になる（第 1 段で `state` の関数を呼ぶプログラムはない）。
- 応答の処理（完了・待つ・起動・終了の振り分け）は呼び出し側が行う。この補助は `raw` を呼ぶところまでにする。
- 作業用のスレッドの仕事をその場で実行して完了の処理で結果を作る手順（10-11「登録と第 1 段の扱い」の第 1 段の列）は、VM と参照インタプリタの両方が使う。この手順も、`WorkerWait::run` と `WorkerDone::complete` を呼ぶ補助として同じファイルに置いてよい。貸すもの（`Lend`）が `Nothing` でなければ、第 1 段では `Stop::Internal` を返す（リソースと標準入力の貸し出しは第 2 段の R26 が共通の部分として作る。完了の処理の「返却 → 処理系の不具合の報告 → 配送」の順序も、そこで守る。[ADR 0266](../../design/decisions/0266-task-and-resource-state-machines.md) の決定 4）。

### コンパイルの失敗のテスト

10-11「コンパイルの失敗のテスト」の例を、`builtin!` の `///` のコメントに、`compile_fail` と対にした `no_run` の組で置く。例は `fn main() {}` を明示して、宣言をモジュールの直下に置く（10-11 の説明のとおり、rustdoc が `fn main` で包むと別の理由で失敗するため）。Rust 1.98.1 の rustdoc は `compile_fail` の誤りの番号を確かめないので、対にした `no_run` の例が通ることで、違反した一行のほかに誤りがないことを示す（10-08「コンパイルの失敗のテスト」と同じ考え方）。

## 受け入れテスト

- 見本の本体: 整数の絶対値が `-5` で `5`、`i64::MIN` で溢れの実行時エラー。文字列の繰り返しが `"ab"` と `3` で `"ababab"`、`0` と負の数で空の文字列、上限を超える回数で `ValueTooLarge`（値を作らない。`HeapStats::allocations` が増えない）。
- 包み: 各見本の `DECL` の `name`・`capability`・`arity` が宣言どおり。`raw` を呼び出しの補助で呼ぶと、本体を直接呼んだ結果と同じ応答になる。引数の数と種類が違う呼び出しは `Stop::Internal`（`arg_mismatch`）。
- 待つ関数: `Sample.readText` の応答が `Reply::Wait(WaitRequest::Io(IoWait::Worker(_)))` であり、補助で仕事をその場で実行して完了の処理を呼ぶと、存在するファイルで `Result.Ok(文字列)`、存在しないファイルで `Result.Error(IOError)`（種類が `NotFound`）、正しくない UTF-8 で `IOError` の種類が `InvalidUTF8` になる。ファイルはテストの中で一時ディレクトリに作る。
- 権限の誤り: `io` の関数を `IoServices` なしで呼ぶと `Stop::Internal`。
- コンパイルの失敗: 10-11 の `compile_fail` の例がすべてコンパイルに失敗し、対にした `no_run` の例がコンパイルできる。
- タグ: `tags` の定数が 10-12 のブロックと一致する（写しの誤りは F06 のソースとの照合でも見つかるが、ここでは値を並べて確かめるテストを書かない。`test-audit` の「価値の低いテスト」に当たるため）。

テストの中の `IoServices` は、テストのモジュールに小さな実装を書く（R08 の第 1 段の一時的な実装はまだない）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-11 のコンパイルの失敗の例と対の例が `builtin!` の `///` にある
- 見本の関数が内部の共通の形（`RawFn`）を直接書いていない

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数（R07・R08・R29）」に加えて、次の点を読む。

- `iface.rs` の変更が、`builtin!` の `///` のコメントへの例の追加だけか。
- 待つ関数の仕事の閉包と完了の処理が、言語の値を捕えていないか。
- 呼び出しの補助が、権限と口の組み合わせの誤りを `Stop::Internal` にしているか。貸し出しを伴う仕事を第 1 段で黙って実行していないか。

## 難易度の理由

書くコードの量は少ないが、マクロと寿命（`'c`・`'e`）と `fn` ポインタの組み合わせで、コンパイルが通らない原因を読み解く力が要る。コンパイルの失敗のテストは、誤りの理由を取り違えて通ることがあり、対にした例で確かめる手間を省けない。ここで見つけた形の不備は、R08 の大量の移植に響く。

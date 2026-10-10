# R08 既存の組み込みの関数の移植と組み込みの表

- 依存する作業: [R07](R07-typed-builtins.md)、[C02](C02-remaining-interfaces.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/R08-builtin-table

## 目的

最小実行版の組み込みの関数（`src/legacy/builtins/`）を、型付きの形（[ADR 0261](../../2026-10-09-design-first-release/decisions/0261-typed-builtin-interface.md)）で `src/builtins/funcs/` の下に書き直す。関数の意味は最小実行版のものを写す。最小実行版の IO の関数は、[IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)の名前（`Console.writeLine` など）に改めて移す。

あわせて、組み込みの表の全体を作る。表には、第 1 段で本体を書く項目だけでなく、[組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の項目の一覧の U1・U2 の範囲の 164 項目をすべて並べ、後の作業（R29・R35・R37）が本体を書く項目は仮の本体で宣言する（10-12「まだ書かない項目の仮の本体」）。U1 の名前解決（F06）は prelude のソースの `@builtin` を表で引くので、本体より先に項目が表にある必要があるからである。表を引く関数（`builtin_decl`・`lookup_builtin` と、10-12 の C02 のブロックの関数と定数）もここで書く。

最後に、第 1 段の実行の関数（10-09 の `Vm::run_stage1`）が使う `IoServices` の一時的な実装を書く。R26 が第 2 段の実行ごとの状態に置き換えて消す。

## 読む設計書の節

- [仮想機械](../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「組み込みの関数の呼び出し」
- [ランタイム](../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「組み込みの操作とハンドラ表」「一つの操作で作る値の大きさの上限」「出力のバッファ」（第 1 段の一時的な実装が守る範囲。後述）
- [基本型の意味論](../../2026-10-09-design-first-release/01-spec/01-04-types-basic.md)（`Integer`・`Float`・`Character`・`String`・`Boolean` の演算と変換）、[標準ライブラリ](../../2026-10-09-design-first-release/03-interop/03-06-stdlib.md)の「Integer」〜「Result」と「標準の型クラス（初回リリース版）」の `Show.show`、[IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)の `Console`・`File.readText`・`Process.arguments`
- [ADR 0049](../../2026-10-09-design-first-release/decisions/0049-size-limit-for-built-values.md)、[ADR 0157](../../2026-10-09-design-first-release/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[ADR 0261](../../2026-10-09-design-first-release/decisions/0261-typed-builtin-interface.md)、[ADR 0273](../../2026-10-09-design-first-release/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)、[ADR 0276](../../2026-10-09-design-first-release/decisions/0276-reference-interpreter-shares-builtin-bodies.md)（決定 4）
- インターフェース: [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の全体、[組み込みの関数の型付きの形](../10-interfaces/10-11-builtin-interface.md)の「宣言のマクロ」「登録と第 1 段の扱い」、[値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「値」「大きさを確かめる構築」「リスト」「構造の等しさ」、[土台](../10-interfaces/10-01-base.md)の「値の表現によらない基本型の計算」
- 移植の元: `src/legacy/builtins/`（意味を確かめるために読む。形は写さない）

## 作るもの

- `src/builtins/funcs/mod.rs`: 10-12「部分の一覧」の 21 の部分の子のモジュールの宣言と、部分を並べた `PARTS`（10-12「部分と番号」の順）。R07 が加えた `#[cfg(test)] mod samples;` は残す。
- `src/builtins/funcs/` の下の 21 の部分のファイル（`operators.rs`・`integer.rs`・…・`clock.rs`）。各ファイルは、10-12「項目の一覧」のその部分の項目を、一覧の順にすべて `builtin!` で宣言し、`pub const DECLS: &[BuiltinDecl]` に同じ順で並べる。R08 の項目は本体を書き、ほかの作業の項目は仮の本体にする。
- `src/builtins/funcs/stage1_io.rs`: 第 1 段の `IoServices` の一時的な実装（後述）。`funcs/mod.rs` に `pub mod stage1_io;` で宣言する。組み込みの関数を書く作業が `funcs/mod.rs` に子のモジュールを加えてよい例外（00-03「ブランチと並行作業」）を使う置き場所であり、表の部分ではないので `PARTS` に加えない。
- `src/builtins/table.rs`: `builtin_decl`・`lookup_builtin`（10-11 の `sig=`）と、10-12 の C02 のブロックの関数と定数（`EntryKind`・`ListPatternOp` などの型は C02 が置く。本作業は関数の中身と、定数の表の値を 10-12 のとおりに書く）。R07 が置いた `tags` と呼び出しの補助は残す。
- `src/base/prim.rs` の `float_to_text`（10-01「値の表現によらない基本型の計算」）。`Float` の値を `Float.toString` の表記の文字列にする。`src/legacy/builtins/float.rs` の表記の関数を写してよい。`Float.toString` と文字列補間の `Float` の項目は、この関数を呼ぶ。定数の評価器（F07）も同じ関数を呼ぶので、表記を組み込みの関数の中に別に書かない。
- 上のファイルの中のテスト。

C01・C02 は `sig=` の宣言を `todo!()` の仮置きとして置いている。本作業は受け持つ関数の本体を書き換え、ファイルに `todo!()` が残らなければ仮置きの許可とコメントを消す（00-02「`todo!()` の仮置き」）。`src/base/prim.rs` の `cmp_key_atom` は F07 が書くので、同じファイルの許可は F07 が消す。

## 手順の要点

### 本体を書く項目

10-12「作業ごとの項目の数」の R08 の行（`Pure` 92、`Io` 6）の項目の本体を書く。各項目の意味と実行時エラーは、10-12「項目の一覧」の各行の「意味」の欄が示す設計書の箇所で定める。最小実行版の同じ関数（名前が違うものを含む）があれば、その意味を写し、設計書と食い違うときは設計書を正とし、食い違いを完了の報告に挙げる。

- 引数と結果は、`FromArg`・`FromValue`・`IntoValue` を実装する Rust の型（`i64`・`&'c str` など）で受け取り返す。リストは `Value<'e>` で受け取り、`runtime::list` の関数で読む（表現を直接読まない。10-08「リスト」）。構成子の値（`Option`・`Result`・`IOError` など）は `tags` の定数と `alloc_fields`・`Value::Tag` で作る。
- 値を作る関数は、確保の前に結果の大きさを計算して上限を確かめる（02-09「一つの操作で作る値の大きさの上限」の箇条）。`String.repeat` のように大きさが引数から決まる関数は `checked_mul` などで先に判定し、`String.replace` のように走査が要る関数は出現を数えてから計算する。結果の大きさが引数を超えない関数は確かめなくてよい。
- 整数の演算は溢れを検査し、`RuntimeError::IntegerOverflow`・`DivisionByZero` を返す（01-04）。引数の値の範囲の外は `RuntimeError::ArgumentOutOfDomain` を、関数の修飾した名前と 0 から数えた引数の位置で返す。
- 演算子の項目（`%Integer.add` など）の本体は、参照インタプリタが呼ぶ（VM は専用の命令で実行する。10-12「演算子（`operators`）」、[ADR 0276](../../2026-10-09-design-first-release/decisions/0276-reference-interpreter-shares-builtin-bodies.md)）。同じ演算の意味を VM の命令（R09）と二か所で書くことになるので、意味の中心（溢れの検査など）を小さな非公開の関数にまとめ、R09 が同じ関数を呼べるよう `pub(crate)` にしてよい。
- 構造の等しさの項目（`%eq`・`%ne`）は `runtime::equal::values_equal` を使う。
- IO の項目の関数は、属するモジュールとともに非公式から始める（10-12「IO のモジュール」、[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)）。表の名前は標準に加えた後の名前のまま書き、スクリプトからは `import Benitoite.Unofficial.IO.Console` の形で取り込む。
- IO の項目（`Benitoite.IO.Console.write`・`writeLine`・`writeError`・`writeErrorLine`、`Benitoite.IO.File.readText`、`Benitoite.IO.Process.arguments`）の本体は、`IoCtx::services()` の `IoServices` を使う。`File.readText` は R07 の見本と同じく作業用のスレッドの仕事と完了の処理で書き、読む大きさの上限（02-09 の「読む大きさが決まっていない入力」の箇条。上限より 1 バイト多い分まで読み、超えたら `ResourceError::InputTooLarge`）を守る。出力の関数は `IoServices::write_output` を呼び、受け付けられずに待つ理由が返ったら、その理由で `IoReply::Wait` を返す。
- `Lazy.force`・`Reference.update` の項目は本作業の範囲ではない（R29）が、`raw` が呼ばれたら `Stop::Internal` を返す形（10-12「項目の種類」の最後の箇条）は、仮の本体と同じく本作業で宣言する。

### 仮の本体の項目

R29・R35・R37 の項目は、名前・権限・引数の数だけが正しい仮の本体で宣言し、呼ばれたら次の値を返す（10-12「まだ書かない項目の仮の本体」）。引数の Rust の型は `Value<'e>` でよい。

```text
Err(Stop::Internal(format!("builtin {} is not implemented yet", "Task.all")))
```

後の作業は本体と引数の Rust の型を書き換えるが、名前・権限・引数の数と、部分の中の位置は変えない。本作業は、この決まりを各部分のファイルの先頭の `//!` に書く。

### 表を引く関数

- 番号は `PARTS` の部分を順につないだ並びの中の位置である（10-12「部分と番号」）。`builtin_decl(id)` は部分の長さを引きながら位置を探し、`lookup_builtin(name)` はすべての項目を先頭から調べる。索引は作らない。表は `const` と関数で表し、大域の可変状態を持たない（ADR 0015）。
- `builtin_kind` は、名前の頭（`Benitoite.`・`%`）と権限、10-12 の定数の表から項目の種類を決める。
- `builtin_intrinsic`・`operator_builtin`・`equality_builtin`・`interpolation_builtin`・`list_pattern_builtin` は、10-12 の定数の表の名前を `lookup_builtin` で引いて返す。
- `builtin_scheme` は、ソースに宣言のない項目（`Operator`・`Equality`・`ListPattern`・`Interpolation`）にだけ型を返す。型の組み立てには 10-05 の型の表現を使う。

### 第 1 段の `IoServices` の一時的な実装

第 1 段の実行の関数（R09 の `Vm::run_stage1`）と、F18 の `runtime::run::run_program` の第 1 段の形が使う。10-11「作業の割り当て」の R08 の行のとおり、本番の出力とテスト用の出力の二つを作る。

| 実装 | 出力 | 入力と環境 |
|---|---|---|
| 本番の出力 | 標準出力と標準エラー出力。書き込みはメモリのバッファに溜め、実行の終わりか一定の量を超えたときに書き出す（最小実行版の `src/legacy/runtime/real_io.rs` の振る舞いを写す）。書き出しの失敗は記録し、以後の `write_output` で `RuntimeError::WriteFailed` を返す | 与えられた引数、スクリプトのディレクトリ、基準のディレクトリ。環境変数はプロセスのもの。時計は実時間 |
| テスト用の出力 | メモリに捕らえる（標準出力と標準エラー出力を分けて、書いた順も記録する） | 与えた値 |

- 転送していない量の上限と書き出し用のスレッド（[ADR 0265](../../2026-10-09-design-first-release/decisions/0265-output-transfer-by-writer-threads.md)）は第 2 段の R27 が作る。一時的な実装の `write_output` は常に受け付けて `Ok(None)` を返す（書き出しの失敗が記録されていれば `Err`）。
- `register_resource` は第 1 段では呼ばれない（リソースを開く関数は R29）。呼ばれたら処理系の不具合として扱える形（番号を返すが、記録を残して後で `Stop::Internal` にするなど）を決め、`///` に書く。`IoServices` のシグネチャは変えない。
- 両方の実装の型の名前と作り方は本作業が決め、`///` に「R26 が 10-10 の `IoRuntime` に置き換えて消す」と書く。
- F18 の `run_program` がこの実装を使う（F18 の文書の「実行の流れ」）。そのため、次の口を `pub(crate)` 以上で持たせる: 引数・基準のディレクトリ・スクリプトのディレクトリ（10-11 の `RunInput` の内容）から作る関数、標準出力と標準エラー出力のそれぞれについて最後の書き出しを行い失敗を `std::io::Error` で返す関数、書き出しの失敗の記録を取り出す関数、テスト用の出力が捕らえたバイト列を書いた順に取り出す関数。

## 受け入れテスト

- 表の形（10-12「確かめること」の表の最初の行の内容をすべて）: 名前が重ならない。すべての名前が 10-12「名前の付け方」の形に合う。`builtin_decl(lookup_builtin(n))` の名前が `n` になる。権限が `Io` の項目と名前が `Benitoite.` から始まる項目が一致する。`OPERATORS`・`EQUALITY`・`INEQUALITY`・`INTERPOLATION`・`LIST_PATTERN`・`INTRINSIC_FUNCTIONS` のすべての名前が表にある。`builtin_scheme` がソースに宣言のない項目にだけ型を返し、その引数の数が `arity` と一致する。部分の数と各部分の項目の数が 10-12「部分の一覧」と一致する。
- 項目ごとの単体テスト（10-12「確かめること」の 2 行目）: R08 の本体を書いた項目ごとに、本体の関数（`builtin!` が作る名前の付いた関数）を直接呼んで、設計書の意味どおりの値と実行時エラーを確かめる。境界の値（`i64::MIN`・`i64::MAX`、0 での除算、`NaN`・無限大・負のゼロ、空の文字列、多バイトの文字、空のリスト、上限を超える結果）を含める。組み込みの関数の正しさは差分テストでは確かめられないので、このテストが唯一の確かめである（ADR 0276 の決定 4）。
- `float_to_text`: [基本型の意味論](../../2026-10-09-design-first-release/01-spec/01-04-types-basic.md)の `Float.toString` の例がすべて同じ文字列になる。`Float.toString` と、文字列補間の `Float` の項目が、`float_to_text` と同じ文字列を返す。
- 仮の本体: 仮の本体の項目を呼ぶと、`is not implemented yet` を含む `Stop::Internal` を返す（部分ごとに一つ以上で確かめる）。
- 包み: 各部分から一つ以上の項目を、R07 の呼び出しの補助で `raw` を通して呼び、本体を直接呼んだ結果と一致する。
- IO: テスト用の出力の実装で、`Console.writeLine` などの書いた内容と順序が記録される。`Process.arguments` が与えた引数のリストを返す。`File.readText` が一時ディレクトリのファイルを読み、存在しないファイルで `IOError` を返す。本番の出力の実装で、書き出しの失敗を記録した後の `write_output` が `WriteFailed` を返す（失敗する出力先は、テストで差し替えられる形にして確かめる）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-12 の 164 項目すべてが表にあり、R08 の 98 項目の本体が書いてある
- どの項目も内部の共通の形（`RawFn`）を直接書いていない
- 最小実行版と意味が食い違って設計書に合わせた箇所を、完了の報告に挙げている

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数（R07・R08・R29）」に加えて、次の点を読む。

- 部分と項目の順が 10-12 の一覧と一致しているか（番号が変わると、U1 の作業と後の作業の前提が崩れる）。
- 値を作る関数が、上限を値を作る前に確かめているか。計算が溢れを検査しているか。
- 名前や番号の値をコードに書き込んでいないか（10-12「番号の振り方」）。
- 第 1 段の `IoServices` の一時的な実装が、第 2 段で消せる範囲に閉じているか（ほかのモジュールがその型に依存しすぎていないか）。

## 難易度の理由

一つ一つの関数は最小実行版の意味を写すだけで、形は R07 が確かめてある。量が多いことと、10-12 の順と名前を一つも取り違えずに並べる必要があることが主な負担である。

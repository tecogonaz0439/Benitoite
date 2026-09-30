# R35 `Decimal` と `Byte` の対象・命令・組み込みの関数

- 依存する作業: [R08](R08-builtin-table.md)、[R09](R09-vm-core.md)、[C02](C02-remaining-interfaces.md)、[F07](F07-typeck-records-constants.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満。組み込みの関数の単体テストを除く）
- ブランチ: impl/R35-decimal-byte

## 目的

`Decimal` と `Byte` の値を VM で扱えるようにする。`Decimal` の対象（`alloc_decimal`・`decimal`）、`Decimal`・`Byte` の算術と比較の命令（段が 2 の命令）、`Decimal` の定数の `LOADK`、10-12 が本作業に割り当てた 37 項目の組み込みの関数（`Decimal`・`Byte` の演算子の関数、`Byte` と `Decimal` のモジュールの関数、`Integer` のビット演算）を書く。

`Decimal` の算術と比較そのもの（`base::decimal` の `checked_add` など）は F07 が自作する（[ADR 0275](../../design/decisions/0275-self-made-decimal-arithmetic.md)）。本作業はそれを VM と組み込みの関数から呼ぶ。

本作業は、二つのメモリの管理に共通の API だけを使うので、第 1 段の測定を待たずに進めてよい（[ADR 0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 3）。R14 の前に取り込むときは、両方のメモリの管理の機能でテストを通す。

## 読む設計書の節

- [基本型の意味論](../../design/01-spec/01-04-types-basic.md)の「Byte（初回リリース版）」「Decimal（初回リリース版）」「ビット演算（初回リリース版）」「型の変換」
- [型システム](../../design/01-spec/01-06-type-system.md)の「演算子の型付け」「等値の型」
- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」の `Byte`・`Decimal` の行と、演算でヒープを確保しないこと（`Decimal` は結果ごとに対象を一つ確保する）の箇条
- [バイトコードとコード生成](../../design/02-impl/02-07-bytecode.md)の「演算子の移し方」「定数表」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「Byte（初回リリース版）」「Decimal と RoundingMode（初回リリース版）」
- [評価意味論](../../design/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」
- ADR: [0105](../../design/decisions/0105-byte-type.md)、[0106](../../design/decisions/0106-bitwise-functions.md)、[0114](../../design/decisions/0114-decimal-type.md)、[0275](../../design/decisions/0275-self-made-decimal-arithmetic.md)、[0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md)

インターフェース:

- [バイトコード](../10-interfaces/10-07-bytecode.md)の「算術」「比較」（段が 2 の行）、「定数の記述」の `Decimal`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `Decimal` の対象の関数（`task=C02` の `sig=`）、「構造の等しさ」
- [基本の型](../10-interfaces/10-01-base.md)の `base::decimal`（`Decimal`・`DecimalError`・`DecimalRounding` と F07 が書く関数）
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「演算子」「基本型のモジュール」の本作業の行、「確かめること」
- [診断](../10-interfaces/10-02-diagnostics.md)の「実行時エラー、資源の不足、処理系の制限」（R0101・R0102・R0103・R0701）

## 作るもの

- `src/runtime/heap/` の `Decimal` の対象の関数（`alloc_decimal`・`decimal`）の中身。`Decimal` の値を対象の中に置く。ヒープの公開の層の関数なので、内部の層の確保の関数だけを呼び、`unsafe` を加えない（加える必要があれば止めて報告する）。
- `src/runtime/equal.rs`: `values_equal` の `Decimal` の対象の比較（数として比べ、小数の桁数は比べない。後述）。10-08「作業の割り当て」の R35 の行のとおり本作業が書く。R37 もマップと集合の比較を同じファイルに加えるので、`Decimal` の分岐だけを加える。
- `src/vm/dispatch.rs` と、`dispatch.rs` の中で宣言する非公開の子のモジュール `src/vm/dispatch/numeric.rs`: 段が 2 の算術と比較の命令と、`LOADK` の `ConstDesc::Decimal`。`dispatch.rs` には分岐の行だけを加える（R34 の「作るもの」と同じ理由）。
- `src/builtins/funcs/` の `operators.rs`・`integer.rs`・`byte.rs`・`decimal.rs`: 本作業の 37 項目の本体（R08 の仮の本体を置き換える）と、項目ごとの単体テスト。
- `src/bytecode/disasm.rs`: 本作業の命令の表示が F15 で入っていなければ加える。
- 上のファイルのテスト。

## 手順の要点

### `Decimal` の対象

- `alloc_decimal(d)` は、`Decimal` の値（符号、96 ビットの m、小数の桁数）を持つ対象を `ObjKind::Decimal` で確保する。`decimal(v)` は、`Decimal` の対象なら値を返し、そうでなければ `None`。
- 演算の命令と組み込みの関数は、結果ごとに対象を一つ確保する（02-08「値の表現」）。

### 命令

- `ADDD`・`SUBD`・`MULD`・`DIVD`・`NEGD`: 被演算子を `decimal` で読み、`base::decimal` の関数で計算し、結果を `alloc_decimal` で作る。`DecimalError` は、01-04「Decimal」の規則に従って実行時エラーにする（溢れは `RuntimeError::DecimalOverflow`（R0103）、0 の除算は `DivisionByZero`（R0101））。`Decimal` でない値は `Stop::Internal`。
- `EQD`・`LTD`・`LED`: 数として比べる。小数の桁数は比べない（`1.0m = 1.00m` は真。10-07「比較」）。`Decimal::cmp_num` を使う。
- `EQBT`・`LTBT`・`LEBT`: `Byte` の値（即値）の比較。
- `LOADK` の `ConstDesc::Decimal { mantissa, scale }`: `base::Decimal::new` で値の表現に戻し、`alloc_decimal` で対象を作る。定数の値の表に `ConstIdx` を鍵として取っておく（10-07「定数の記述」）。`Decimal::new` が失敗したら（コード生成の誤り）`Stop::Internal`。
- 確保をする命令の後に、回収の要求の知らせを調べる（10-09 の命令の集合によらない手順の表）。

### 構造の等しさ

`values_equal` は、`Decimal` の対象どうしを数として比べる（`EQD` と同じ）。レコードや `Option` の中の `Decimal` を含む構造の `=` が、小数の桁数の違いで偽にならないようにするためである（01-06「等値の型」、01-04「Decimal」）。

### 組み込みの関数

本作業の項目は、10-12 の表の「作業」の欄が R35 の行である。意味は各行の「意味」の欄の設計書の箇所で定める。

- 演算子の関数（`%Decimal.*`・`%Byte.*`）: 値として使う演算子と、コード生成が命令に移さない場合に使う。命令と同じ関数（`base::decimal` の関数）を呼び、同じ結果と同じ実行時エラーになるようにする。
- `Integer` のビット演算: 01-04「ビット演算（初回リリース版）」に従う。シフトの量が範囲の外のときの扱い（実行時エラーか、決まった値か）は同節の規則に従う。実行時エラーにする場合は `ArgumentOutOfDomain`（R0701）とし、`index` は範囲の外の引数の位置（1 から数える）とする。
- `Byte` の関数: `Byte.fromInteger` は 0〜255 の外で `Option.None`。ビット演算とシフトは 01-04 に従う。`Byte.toString` は 10 進の表記。
- `Decimal` の関数: `round`・`absolute`・`fromInteger`・`truncate`・`toFloat`・`fromFloat`・`toString`・`parse`。`RoundingMode` の値は、10-12「構成子のタグ」の定数で読む。変換の規則（`truncate` と `fromFloat` が `Option.None` を返す条件、`toString` の表記、`parse` が受け付ける形）は 01-04「Decimal」「型の変換」と 03-06「Decimal と RoundingMode」に従い、`base::decimal` の関数（`round`・`to_text`・`parse_literal` など）を使う。`base::decimal` に要る関数がなければ、`base::decimal` に加えずに止めて報告する（`base::decimal` は F07 の受け持ちであり、シグネチャは 10-01 で凍結している）。
- 文字列を作る関数は、大きさの上限を確かめる構築（`alloc_str` など）を使う。

## 受け入れテスト

テストは、項目ごとの単体テスト（10-12「確かめること」）と、`bytecode::asm` で組み立てた命令列の VM のテストで行う。F15 と F18 が取り込まれていれば、スクリプトでの確かめを加えてよい。

- 命令: `Decimal` の四則と符号の反転が `base::decimal` の結果と一致する。溢れで R0103、0 の除算で R0101 の実行時エラーになり、止まった命令がその命令である。`EQD` が `1.0m` と `1.00m` で真。`LTD`・`LED` の境目。`Byte` の比較。
- `LOADK` の `Decimal`: 同じ定数を二度 `LOADK` して同じ対象が返る。
- 構造の `=`: `Option.Some(1.0m)` と `Option.Some(1.00m)` が等しい。
- 37 項目のそれぞれの単体テスト: 設計書の例と境目（`Byte.fromInteger(255)`・`(256)`・`(-1)`、シフトの量の 0 と 63 と 64 と負の値、`Decimal.round` の各 `RoundingMode`、`Decimal.parse` の受け付けない形、`Decimal.fromFloat` の NaN と無限大）。
- 演算子の関数と命令の一致: 同じ入力で、`%Decimal.add` と `ADDD` の結果（と実行時エラー）が一致する。
- R14 の前に取り込むときは、`gc-mark-sweep` と `gc-refcount` の両方の機能と回収の強制で、上のテストが通る。

## 完了条件

- `scripts/check.sh` が通る（R14 の前なら、両方のメモリの管理の機能と回収の強制で）
- `runtime::heap` を変えるので、`scripts/check-heap.sh` も通る（[実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 受け持つ関数に `todo!()` の仮置きが残っていない。ファイルに `todo!()` が残っていなければ、仮置きの許可とコメントを消している（00-02「`todo!()` の仮置き」。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が消す）
- 10-12 の本作業の項目の名前・権限・引数の数と位置を変えていない

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「VM」と「組み込みの関数」の行（計算が溢れを検査しているか、大きさの上限を値を作る前に確かめているか）。
- 命令と演算子の関数が、同じ `base::decimal` の関数を呼んでいるか（二つの実装で意味がずれないか）。
- `Decimal` の等しさで、小数の桁数を比べていないか。
- `as` による数値の変換を、値が収まることが明らかな箇所（`Byte` から `Integer` など）に限っているか。

## 難易度の理由

算術そのものは F07 が書くので、本作業は呼び出しと対象の確保と実行時エラーへの対応づけが中心である。項目の数は多いが、どれも短い。

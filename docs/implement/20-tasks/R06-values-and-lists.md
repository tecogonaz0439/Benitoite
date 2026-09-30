# R06 値の種類ごとの関数、リスト、構造の等しさ

- 依存する作業: [R02](R02-no-gc-region.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/R06-values-and-lists

## 目的

16 バイトの値（[ADR 0258](../../design/decisions/0258-sixteen-byte-value-enum.md)）の上で、対象の種類ごとに値を作り読む公開の層の関数（`ValueCtx::alloc_str` など）、第 1 段のリストの表現（連結リストのセル）と操作、構造の等しさ（`EQV`）を作る。VM（R09）、組み込みの関数（R07・R08）、参照インタプリタの値の変換（R10）は、これらの関数だけで値を作り読み、対象の配置を直接読まない。

値を作る関数は、確保の前に大きさの上限を確かめる（[ADR 0049](../../design/decisions/0049-size-limit-for-built-values.md)、[ADR 0261](../../design/decisions/0261-typed-builtin-interface.md) の決定 4）。文字列の値は常に正しい UTF-8 であり、外部のバイト列から作るときだけ確かめる（[ADR 0012](../../design/decisions/0012-invalid-utf8-input.md)）。

README の R06 の行にある「`Reference` のセルの対象（ヒープの単位）」は、10-08「作業の割り当て」のとおり、セルの関数を R02 が、生きているセルの表への登録と循環の回収を R04 が書く。本作業はセルを含む値の等しさの扱い（`Stop::Internal`）だけを受け持つ。

## 読む設計書の節

- [仮想機械](../../design/02-impl/02-08-vm.md)の「値の表現」、「組み込みの関数の呼び出し」の最後の段落（構造の `=` を明示の積み重ねで辿ること）
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「一つの操作で作る値の大きさの上限」
- [型システム](../../design/01-spec/01-06-type-system.md)の「等値の型」
- [基本型の意味論](../../design/01-spec/01-04-types-basic.md)の `Float`（IEEE 754 の比較）と `String`（`=` はスカラー値の列の比較）
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「作る値の大きさの上限」「List の内部の表現」（第 1 段は連結リストのセルのままであり、永続ベクタへの移行は R36）
- [ADR 0258](../../design/decisions/0258-sixteen-byte-value-enum.md)、[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md)（決定 4。リストの表現を第 1 段で変えない理由）
- インターフェース: [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「値」「大きさを確かめる構築」「作った後に変わらない対象」「リスト」「構造の等しさ」

## 作るもの

- `src/runtime/heap/ctx.rs`: `ValueCtx` の種類ごとの関数（`alloc_str`・`alloc_str_parts`・`alloc_str_utf8`・`alloc_str_buf`・`str`・`alloc_bytes`・`alloc_bytes_with`・`bytes`・`alloc_fields`・`fields_header`・`fields_len`・`field`・`alloc_opaque`・`opaque`）。`kind`・`same_object`・`object_id` は R01 が書く。
- `src/runtime/list.rs`: 10-08 の `sig=src/runtime/list.rs` の九つの関数。
- `src/runtime/equal.rs`: `values_equal`。
- 上のファイルの中のテスト。値の大きさの表明を確かめるテスト（10-08「作業の割り当て」の R06 の行）を含める。

公開の層の関数は、R01 の内部の層の安全な関数と、R02 の方式の境目だけを呼ぶ。`ctx.rs` に `unsafe` を書かない。内部の層に種類ごとの配置の読み書きの関数が足りなければ、内部の層に足してよい（そのときは R01 の規則どおり `// SAFETY:` と不変条件の番号を書く）。

## 手順の要点

### 種類ごとの関数

- 文字列: `alloc_str` と `alloc_str_parts` は `CheckedLen::bytes` で上限を確かめてから確保する。`alloc_str_parts` は合計の大きさを先に求め（溢れを検査する）、一度だけ写す。`alloc_str_utf8` は上限を確かめてから UTF-8 を確かめ、正しくなければ `Ok(None)` を返す。`alloc_str_buf` は `StrBuf::into_string` の中身を使い、もう一度上限を確かめる必要はない（`StrBuf` が追加のたびに確かめている）が、確保の関数の中で `CheckedLen` を作る形に揃えてよい。`str` は、文字列の対象にだけ `Some` を返す。
- `Bytes`: `alloc_bytes` は上限を確かめる。`alloc_bytes_with` は確かめた長さを受け取り、確保した中身を `fill` に渡す。
- 値の並び: `alloc_fields` は、並びの長さが `u32` に収まらなければ `Stop::Internal` を返す。並びの値は、R01 が決めた形（ヒープの番号を持たない 16 バイトの値）で対象の中に置き、R02 の方式の境目の「指し始めた」を通す（参照カウントの数に数える。R04 はこの関数でテストの値の並びを作る）。`fields_header`・`fields_len`・`field` は値の並びの対象にだけ `Some` を返し、`field` は範囲の外で `None` を返す。
- 中身を見せない値: `alloc_opaque` は `OpaqueData` の値を持つ対象を作り、`opaque` は型が合うときだけ共有の参照を返す。
- 引数のない構成子、空のリスト・マップ・集合は即値（`Value::Tag`・`EmptyList` など）であり、対象を作らない（10-08「値」）。

### リスト（第 1 段）

第 1 段のリストは、`FieldsKind::ListCell` の対象（並びは先頭の要素と残りのリスト、`tag` は長さ）の連結である。空のリストは `Value::EmptyList` である。

- どの関数も Rust の再帰を使わず、ループで辿る（00-02「再帰の深さ」）。
- 作る関数（`from_values`・`prepend`・`append`・`concat`・`slice`）は、結果の長さを先に計算し、`CheckedLen::elements` で上限を確かめてから作る。`prepend` は元の長さに 1 を足した長さを確かめる（02-09「一つの操作で作る値の大きさの上限」）。
- `from_values` は末尾の要素から順にセルを作る。`prepend` は元のリストを共有する。`append`・`concat`・`slice` は、元のリストを変えずに新しいセルを作る（元の値は作った後に変更しない）。共有できる末尾（`concat` の `b`、`slice` が末尾まで及ぶときの残り）は共有してよい。
- `len`・`get`・`tail`・`to_vec` は、リストでない値に `Stop::Internal` を返す。`get` と `slice` の位置の扱いは 10-08 のコメントのとおりとする。
- この表現は R36 が永続ベクタに移す。本モジュールの外にセルの形を漏らさない（VM と組み込みの関数は本モジュールの関数だけでリストを扱う）。

### 構造の等しさ

`values_equal` は、比べる組の積み重ね（`Vec`）で辿り、Rust の再帰を使わない（02-08「組み込みの関数の呼び出し」）。

- 即値は値で比べる。`Float` は IEEE 754 の `==`（`NaN` はどの値とも等しくなく、`0.0` と `-0.0` は等しい）。`Char`・`Byte`・`Bool`・`Unit`・`Tag` は値で比べる。
- 文字列はバイト列で比べる（スカラー値の列が等しいことと同じ。正規化しない）。`Bytes` はバイト列で比べる。
- 値の並びは、種類と `tag` と長さが等しく、各要素が等しいとき等しい。リストは要素の並びで比べる（表現の形では比べない。10-08 のコメント）。長さを先に比べてよい。
- 関数の値（`FieldsKind::Func`）、辞書、セル、`Host`・`Opaque` の対象、`IOError`・`NetworkError` の値に出会ったら `Stop::Internal` を返す（等値の型でないので、型検査を通ったプログラムでは起きない。[ADR 0048](../../design/decisions/0048-ioerror-not-equality-type.md)）。即値と対象、種類の違う対象の組も `Stop::Internal` である。
- `Decimal` の対象の比較は、`Decimal` の関数を加える R35 が書く（10-08 の `decimal` は C02 の後に置かれる）。本作業では、`Decimal` の対象に出会ったら `Stop::Internal` を返し、そのことをコメントに書く。マップと集合の比較は R37 が加える（10-08「作業の割り当て」）。

## 受け入れテスト

- 大きさの表明: 機能 `heap-verify` を無効にした構成で `size_of::<Value<'static>>()` と `size_of::<Slot>()` が 16 である（`#[cfg(not(feature = "heap-verify"))]` で限り、理由をコメントに書く。定数の表明と別に、値として確かめて報告に数値を残す）。
- 文字列: `alloc_str("あい")` の `str` が `Some("あい")`、`kind` が `Some(ObjKind::Str)`。`alloc_str_parts` が部分をつないだ文字列を作る。上限を超える大きさの `alloc_str_parts`（合計が溢れる大きさを含む）は `ResourceError::ValueTooLarge` を返し、確保しない（`HeapStats::allocations` が増えない）。`alloc_str_utf8` が正しくないバイト列に `Ok(None)` を返す。
- 上限そのもの: `CheckedLen::bytes` と `CheckedLen::elements` の上限ちょうどと 1 超えで、成功と `ValueTooLarge` が分かれる（大きな値を実際には作らない）。
- 値の並び: `alloc_fields(Ctor, 1, [..])` の `fields_header`・`fields_len`・`field` が作ったときの値と一致し、範囲の外の `field` が `None`。長さ 0 の並び。
- `Opaque`: 型の合う `opaque` だけが `Some` を返す。
- リスト: `from_values` の長さと要素。`prepend` が元のリストを変えず、元のリストと末尾を共有する（`same_object` で確かめる）。`append`・`concat`・`slice`（範囲の切り詰めを含む）・`tail`・`get`・`to_vec` が、`Vec` で同じ操作をした結果と一致する（無作為の操作の列で比べてよい）。長さの上限を超える `prepend` が `ValueTooLarge { function, size: 16777217, unit: Elements, limit: 16777216 }` を返す（大きなリストを作る手間を避けるため、長さの欄だけ大きいセルを作るテスト用の補助を使ってよい。補助はテストのモジュールに置く）。リストでない値に `len` が `Stop::Internal`。
- 長いリスト: 長さ 1,000 万のリストを作り、`len`・`to_vec`・`slice` を行っても、スタックを使い果たさない（Miri では数を減らす）。
- 等しさ: 同じ形の値の並びの木は `true`、`tag` の違い・長さの違い・要素の違いは `false`。`[NaN]` どうしは `false`、`0.0` と `-0.0` は `true`。関数の値・セル・`Host`・`Opaque` を含む比較は `Stop::Internal`。要素が 100 万の等しいリストどうし、深さ 100 万の入れ子の値の並びどうしの比較がスタックを使い果たさない。
- 両方の方式: 上のテストが `gc-mark-sweep` と `gc-refcount` の両方で通る。

## 完了条件

- `scripts/check.sh` と `scripts/check-heap.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 受け持つ関数に `todo!()` の仮置きが残っていない。ファイルに `todo!()` が残っていなければ、仮置きの許可とコメントを消している（00-02「`todo!()` の仮置き」。`runtime/heap/ctx.rs` のように複数の作業が受け持つファイルでは、最後に `todo!()` を書き換えた作業が消す）
- `ctx.rs`・`list.rs`・`equal.rs` に `unsafe` がない
- リストの操作と構造の等しさに Rust の再帰を使っていない

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「ヒープの内部の層」「言語の値を作る経路」に加えて、次の点を読む。

- 大きさの上限を、確保の後でなく前に確かめているか。長さの計算が溢れを検査しているか。
- リストの操作が元の値を書き換えていないか。セルの形（`ListCell` の並びの順と `tag`）を `list.rs` の外で読んでいないか。
- 等しさで `Stop::Internal` にすべき組を、`false` として返していないか。

## 難易度の理由

関数の数は多いが、どれも内部の層の確保と読み出しを呼ぶ定型の形である。上限を確保の前に確かめる規則と、リストと等しさを再帰なしで書く規則を、すべての関数で漏れなく守ることに注意が要る。

# 実装プラン

作業は T1 と、レビューの指摘を直す T2。フェーズ 2 と同じく、メインの作業ディレクトリでブランチ `mod/T1` の上で Codex（GPT-6.1-Sol、high）が実装し、取り込んだ後に Opus がレビューする。直しがあれば T2 以降で行う。`scripts/check.sh` は最後に一度だけ行う。

## 共通の決まり

フェーズ 2 の `plan.md`（`docs/archive/2026-10-13-TODO-047_212_230_232_234_235-packages-and-wasm-phase2/plan.md`）の「どの作業にも共通する決まり」と同じ（診断と文言、ゴールデンと Skill の作り直し、設計書の直し、CHANGELOG、test-audit、10 秒の上限、`unsafe` を書かない、依存を足さない）。凍結した型やシグネチャは変えない（`ExternalSpec`・`ExternalRoute`・`TypedKind` は凍結の対象外）。変える必要が出たら止めて報告する。

完了の条件にはフェーズ 2 と同じ共通のコマンドを含める。

## 作業 T1: リストの型付きの経路（Q1、R1）

1. 照合: `ExternalRoute::of`（`crates/benitoite/src/external/mod.rs`）で、R1 の型の組み合わせを型付きの経路に選ぶ。`TypedKind` に `List[Byte]`・`List[Integer]`・`List[Float]` を表すものを足す（`List[Byte]` は Wasmtime の側の型を `Bytes` と共有する）。型の別名、`List[Byte]` を `list<u8>` に照合する今の規則（03-10「型の対応」）は変えない。
2. 実行: `crates/benitoite/src/external/typed.rs` の準備で、`List[Byte]` は要素を取り出して `Vec<u8>` に詰め、`&[u8]` として渡す（`Bytes` の借用と同じ具体化を使えるよう、借用か所有かを持つ形にする）。`List[Integer]`・`List[Float]` は `Vec<i64>`・`Vec<f64>` に詰めて `&[i64]`・`&[f64]` で渡す。戻り値は `Vec<u8>`・`Vec<i64>`・`Vec<f64>` で受け取り、宣言の型に従って `Bytes` か Benitoite のリストの値を作る（リストを作る公開の層の API を使い、大きさの上限を確かめる）。要素を取り出す処理と値を作る処理は、明示の作業列かカーソルで書き、Rust の再帰を使わない。340 通りの具体化を作るマクロに `&[i64]`・`&[f64]` と `Vec<i64>`・`Vec<f64>` を足す。
3. 予算と統計: R1 の数え方にする（引数は準備で数え、コンパイル・インスタンス化の前に検査する今の順を保つ）。`--wasm-stats` の数え方も合わせる。
4. 実行ファイルの大きさ: release で作業の前と後の大きさ（strip の前と後）を測って報告する。strip の後の増分が 2 MB を超えたら、`list<s64>`・`list<f64>` の具体化を引数 2 個までに限るなど、増分を抑える案を報告に書く（実装はそのままでよい）。
5. 設計書: 03-10「実行」（速い経路の範囲、入れ子の中のリストは動的な経路のままである限界、予算の数え方）、02-09「外部の関数の実行」、言語リファレンスの 21 節、CHANGELOG の Unreleased（フェーズ 2 の速い経路の項目に足す）。
6. テスト: 型付きの経路と動的な経路が同じ結果を返すこと（`List[Byte]`・`List[Integer]`・`List[Float]` を引数と戻り値に持つ関数。空のリスト、負の数、NaN・無限大、境界の値）。6 MB の `List[Byte]` を渡すと受け渡しの量が 6,000,000 バイトで済むこと（`--wasm-stats` か単体テスト。今は 240,000,000 バイト）。予算の上限、大きさの上限、入れ子の中のリストが動的な経路のままであること。`testdata/external/` の `.wat` を足す場合は `.wasm` を作り直す。`tools/bench/wasm_bench.py --quick` が通ること（Hash の `List[Byte]` の組の受け渡しの量が減る）。

### 完了の条件

共通のコマンドに加えて、次を通す。

```sh
cargo test -p benitoite --lib -- external::
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --lib external::
python3 tools/bench/wasm_bench.py --quick
```

## 作業 T2: 具体化の削減とレビューの指摘（Q2、R2）

T1 のレビューの記録は `reviews/2026-10-13-T1/report.md`（行番号はコミット 833b8940 のもの。今のコードで場所を確かめる）。

1. 具体化の削減（Q2）: `ExternalRoute::of` と型付きの経路のマクロで、`List[Integer]`・`List[Float]` を引数に含む組は引数が 2 個以下のときだけ型付きの経路を選ぶ。3 引数の組で数のリストを含むものは動的な経路で渡す。具体化の数（642 通りの見込み）と、release の実行ファイルの大きさ（strip の前と後。T1 の前の 21,456,328 バイト（strip の後）と比べる）を報告する。03-10「実行」・02-09「外部の関数の実行」・言語リファレンスの 21 節・CHANGELOG に、この範囲と理由を書く。経路の選び方のテストに、3 引数の組（数のリストを含むものは動的、`List[Byte]` だけのものは型付き）を足す。
2. M1（R2）: `runtime::list` に、要素の数を先に `CheckedLen` で確かめ、反復子から 32 個ずつ葉を作るリストの構築の関数を足し（`pub(crate)` でよい）、`into_list` はこれを使って中間の `Vec<Value>` を作らない。`from_values` と同じ形のリスト（長さ、葉、末尾）になることを、`from_values` で作ったリストとの構造の `==` と、長さ 0・1・31・32・33・1024・1025・32×32+1 などで確かめるテストを足す。反復子が宣言より少ない・多い要素を返したら `Stop::Internal` にする。
3. L1: 戻り値を `Bytes` にするかリストにするかを `shape.result` で決める（または `TypedOut` を分ける。具体化を増やさない）。
4. L2: `collect_list` の引数の名前を `element` などに変える。
5. L3: 要素の幅を `size_of::<u8>()`・`size_of::<i64>()`・`size_of::<f64>()` から作る。
6. L4: `PreparedArg`・`collect_list`・`into_list`（と新しいリストの構築の関数）に、理由と設計書の節を示すコメントを足す。
7. L5・L6: 02-09 の段落で「入れ子の中のリストは動的な経路で渡す」の文を「理由:」の前へ移す。03-10 の「型付きの経路は、引数と戻り値に直接現れる型だけを扱う。…」の段落に【決定】と理由を付ける（1 の範囲もここに書く）。
8. L7: (a) payload 付きの NaN（`f64::from_bits(0x7ff8_0000_0000_1234)` など）をビットまで比べる。(b) 同じ呼び出しで `Bytes` と `List[Byte]` を並べ、予算の合算と結果を確かめる。(c) `list<s64>` の要素の上限を確かめない理由（既定の線形メモリの上限 64 MiB に阻まれる）を、テストの関門のコメントに一文で書く。

### 完了の条件

共通のコマンドに加えて、次を通す。

```sh
cargo test -p benitoite --lib -- external:: runtime::list
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --lib -- external:: runtime::list
python3 tools/bench/wasm_bench.py --quick
```

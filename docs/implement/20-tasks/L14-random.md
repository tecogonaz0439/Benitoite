# L14 `Random`

- 依存する作業: [L00](L00-u3-interfaces.md)、[R26](R26-dispatch-queue-and-io-executor.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L14-random

## 目的

`Benitoite.IO.Random` の 9 の関数の本体を書く。10-15 の部分 35（`random::DECLS`）である。生成器は、種を SplitMix64 で広げ、xoshiro256** で値を作る自作のものであり、範囲の中の値への変換の手順も仕様で固定する（[ADR 0172](../../design/decisions/0172-random-conversion-procedure.md)）。同じ種からは処理系の版によらず同じ列を作る。`Random.Generate` の操作が使う隠れた生成器の種は、OS の乱数（`getrandom`）で決める（10-16「隠れた乱数の生成器」）。

| 項目 | 権限 |
|---|---|
| `Random.integer`・`float`・`boolean`・`shuffle`・`choose`（隠れた生成器） | `Io` |
| `Random.fromSeed`・`nextInteger`・`nextFloat`・`shuffleWith`（純粋な生成器） | `Pure` |

依存の理由: 隠れた生成器の状態は `IoRuntime::random_state` にあり、`IoView::random_u64`（R26）で読む。

## 読む設計書の節

- [IO のモジュール](../../design/03-interop/03-07-io-modules.md)の「Random」（関数の表、`high` が `low` 以下のときの実行時エラー、中身を見せない型、アルゴリズムと変換の手順、隠れた生成器）
- [エフェクト](../../design/01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」（`Random.Generate` をハンドラで処理して値を固定できること）
- ADR: [0172](../../design/decisions/0172-random-conversion-procedure.md)、[0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)（`rand` を使わない理由）、[0168](../../design/decisions/0168-regex-match-and-stdlib-opaque-values.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表と `IO/Random.bnt`
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `getrandom`、「隠れた乱数の生成器」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の `IoRuntime::random_state`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `OpaqueData`・`alloc_opaque`・`opaque`、`runtime::list` の関数

## 作るもの

- `src/builtins/funcs/random.rs` の 9 項目の本体と単体テスト
- SplitMix64 と xoshiro256** と範囲の変換の非公開の関数（純粋な生成器と隠れた生成器で共有する）
- `runtime::run` で隠れた生成器の種を入れる数行と、`getrandom` の依存（10-16 の表の指定）
- `IoView::random_u64`（R26 が書いたもの）が本作業の xoshiro256** の一歩と同じになっていることの確かめ。違えば本作業の関数を呼ぶ形に改める

## 手順の要点

- 変換の手順は、03-07「Random」の箇条のとおりに書く。幅 n = high − low を符号なしの 64 ビットで求め（`low`・`high` の差は `i64` では溢れうるので `wrapping_sub` を `u64` にしてから計算する）、x が 2^64 − (2^64 mod n) 未満なら low + (x mod n)、そうでなければ次の x でやり直す。浮動小数は x を 11 ビット右にずらして 2^−53 を掛ける。真偽値は最上位のビット。並べ替えは i を m − 1 から 1 まで減らし、0 以上 i + 1 未満の j と入れ替える。選択は 0 以上 m 未満の位置で、空のリストでは x を使わない。
- 種は、64 ビットの 2 の補数として符号なしの値に読み替えて SplitMix64 に与え、続けて返す 4 個の値を xoshiro256** の状態とする。
- `Random.Generator` の値は、状態（`[u64; 4]`）を持つ `OpaqueData` である。`nextInteger` などは、引数の生成器を変えず、次の状態の新しい生成器を作り、値と組にした `Pair`（`tags::PAIR`）を返す。
- `Random.integer`・`nextInteger` は、`high` が `low` 以下なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は `high` の位置）。
- 隠れた生成器の操作（`Io`）は、`IoServices::random_u64` で x を得る。操作は VM のスレッドで、すぐに完了する（02-09「組み込みの操作とハンドラ表」）。
- 種: `runtime::run` が `IoRuntime` を作った直後に、`getrandom::u64()` の値を種として SplitMix64 で広げ、`random_state` に入れる。`getrandom` が失敗したら、処理系の不具合（`Stop::Internal`）として実行を止める（10-16）。テスト用の部品で作る実行（`RunEnv::parts` が `Some`）も同じく OS の乱数を使う。テストで値を固定するときは、スクリプトの `Random.Generate` のハンドラで固定する（01-07）。

## 受け入れテスト

- 決まった列（ADR 0172 が求める、版によらない列）: 種 0・1・−1・2^63 − 1 について、`fromSeed` から `nextInteger`（幅 1、幅 6、幅 2^63 を超える幅）・`nextFloat`・`shuffleWith` を続けた値の列を、03-07 の手順を別に書き下したテストの中の参照の実装（テストのモジュールの中に置く、同じ手順の素直な実装）と比べる。SplitMix64 と xoshiro256** の公開の参照の値（各アルゴリズムの作者の C の参照の実装が出す、種 0 からの最初の数個の値）とも比べる。参照の値は、出典（URL）をテストのコメントに書き、作業の中で確かめた値を使う。確かめられなければ、書き下した参照の実装との比較だけにし、完了の報告に書く。
- やり直しの経路: 幅 n が 2 の累乗でないとき、x がやり直しの範囲に入る値を与えて（xoshiro の状態を直接作る非公開の関数をテストで使う）、次の x が使われる。
- 範囲: `nextInteger(g, low, high)` の値が `low` 以上 `high` 未満、`nextFloat` の値が 0.0 以上 1.0 未満。`high = low` と `high < low` で実行時エラー。`low = Integer の最小値`、`high = Integer の最大値` で溢れない。
- 引数を変えない: `nextInteger` の前後で、同じ生成器から同じ値が得られる（純粋な関数である）。
- 隠れた生成器: 状態を与えた `IoView`（テスト用の部品で作ったもの）で `Random.integer` などが、同じ状態の純粋な生成器と同じ値を返す。空のリストの `choose` が `Option.None` で、状態を進めない。
- スクリプト: `handle` で `Random.Generate` の操作を処理して値を固定できる。二回の実行で `Random.integer(0, 1000000)` の列が（ほぼ確実に）違う（種が OS の乱数である）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `getrandom` の版と、参照の値の出典（確かめられなかった場合はその旨）を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- 変換の手順が 03-07 の文と一字一句対応しているか（とくに、やり直しの条件と、並べ替えの i の範囲）。
- `rand` などの乱数のクレートを加えていないか（ADR 0138）。外部のコードを写していないか（00-02）。

## 難易度の理由

アルゴリズムは短く、手順は仕様で固定されている。誤りやすいのは、符号なしの幅の計算と、版によらない列を確かめるテストの組み方である。

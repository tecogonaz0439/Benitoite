# L14 `Random`

- 依存する作業: [L00](L00-u3-interfaces.md)、[R26](R26-dispatch-queue-and-io-executor.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L14-random

## 目的

`Benitoite.IO.Random` の 9 の関数の本体を書く。10-15 の部分 35（`random::DECLS`）である。生成器は、種を SplitMix64 で広げ、xoshiro256** で値を作る自作のものであり、範囲の中の値への変換の手順も仕様で固定する（[ADR 0172](../../2026-10-09-design-first-release/decisions/0172-random-conversion-procedure.md)）。同じ種からは処理系の版によらず同じ列を作る。`Random.Generate` の操作が使う隠れた生成器の種は、OS の乱数（`getrandom`）で決める（10-16「隠れた乱数の生成器」）。

| 項目 | 権限 |
|---|---|
| `Random.integer`・`float`・`boolean`・`shuffle`・`choose`（隠れた生成器） | `Io` |
| `Random.fromSeed`・`nextInteger`・`nextFloat`・`shuffleWith`（純粋な生成器） | `Pure` |

依存の理由: 隠れた生成器の状態は `IoRuntime::random_state` にあり、`IoView::random_u64`（R26）で読む。

## 読む設計書の節

- [IO のモジュール](../../2026-10-09-design-first-release/03-interop/03-07-io-modules.md)の「Random」（関数の表、`high` が `low` 以下のときの実行時エラー、中身を見せない型、アルゴリズムと変換の手順、隠れた生成器）
- [エフェクト](../../2026-10-09-design-first-release/01-spec/01-07-effects.md)の「利用者が定義するエフェクトとハンドラ（初回リリース版）」（`Random.Generate` をハンドラで処理して値を固定できること）
- ADR: [0172](../../2026-10-09-design-first-release/decisions/0172-random-conversion-procedure.md)、[0138](../../2026-10-09-design-first-release/decisions/0138-crates-and-licenses-for-stdlib.md)（`rand` を使わない理由）、[0168](../../2026-10-09-design-first-release/decisions/0168-regex-match-and-stdlib-opaque-values.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「IO のモジュール」の表と `IO/Random.bnt`
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `getrandom`、「隠れた乱数の生成器」
- [スケジューラと IO 実行器](../10-interfaces/10-10-scheduler-and-io.md)の `IoRuntime::random_state`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `OpaqueData`・`alloc_opaque`・`opaque`、`runtime::list` の関数

## 作るもの

- `src/builtins/funcs/random.rs` の 9 項目の本体と単体テスト
- SplitMix64 と xoshiro256** と範囲の変換の非公開の関数（純粋な生成器と隠れた生成器で共有する）
- 隠れた生成器の種を入れる関数（`src/runtime/run.rs` の中の非公開の関数。名前は例えば `seed_hidden_random`）と、それを呼ぶ数行。`run_program` と `run_test` はどちらも `src/runtime/run.rs` の `run_entry` を通るので、`run_entry` の `IoRuntime::new` の直後でこの関数を一度呼ぶ。これで `run_program` と `run_test` の両方に種が入る
- `Cargo.toml` の依存に `getrandom = "=0.4.3"` を加える（10-16 の表の指定。既定の機能のままとし、`rand_core` は入らない）
- `IoView::random_u64`（R26 が書いたもの）は、Vigna の xoshiro256** と一致していることを事前点検で確かめたので、改める必要はない。本作業の xoshiro256** の一歩と共有の関数にまとめるかは任意とする

## 手順の要点

- 変換の手順は、03-07「Random」の箇条のとおりに書く。幅 n = high − low を符号なしの 64 ビットで求め（`low`・`high` の差は `i64` では溢れうるので `high.abs_diff(low)` で求める）、x が 2^64 − (2^64 mod n) 未満なら low + (x mod n)、そうでなければ次の x でやり直す。2^64 は `u64` に収まらないので、受け入れの判定は r = `n.wrapping_neg() % n`（2^64 mod n に等しい）を求め、`x <= u64::MAX - r` なら受け入れる形で書く。low + (x mod n) は `low.checked_add_unsigned(x % n)` で求める（結果は `high` 未満なので溢れないが、溢れたら処理系の不具合とする）。浮動小数は x を 11 ビット右にずらして 2^−53 を掛ける。真偽値は最上位のビット。並べ替えは i を m − 1 から 1 まで減らし、0 以上 i + 1 未満の j と入れ替える。選択は 0 以上 m 未満の位置で、空のリストでは x を使わない。
- 種は、64 ビットの 2 の補数として符号なしの値に読み替えて SplitMix64 に与え、続けて返す 4 個の値を xoshiro256** の状態とする。SplitMix64 は Vigna の `splitmix64.c` の形とする。一歩ごとに、状態に `0x9e3779b97f4a7c15` を先に足し（`wrapping_add`）、足した後の値を混ぜた値を返す。
- `Random.Generator` の値は、状態（`[u64; 4]`）を持つ `OpaqueData` である。`nextInteger` などは、引数の生成器を変えず、次の状態の新しい生成器を作り、値と組にした `Pair`（`tags::PAIR`）を返す。
- `Random.integer`・`nextInteger` は、`high` が `low` 以下なら実行時エラー（`ArgumentOutOfDomain`。引数の位置は `high` の位置で、`Random.integer(low, high)` では 1、`Random.nextInteger(g, low, high)` では 2）。`RuntimeError::ArgumentOutOfDomain` の `function` の欄には、その項目の宣言（`DECLS`）の `name` と同じ文字列を入れる（既存の作業の書き方に倣う）。
- 隠れた生成器の操作（`Io`）は、`IoServices::random_u64` で x を得る。操作は VM のスレッドで、すぐに完了する（02-09「組み込みの操作とハンドラ表」）。
- 種: `run_entry` が `IoRuntime` を作った直後に、上の関数で `getrandom::u64()` の値を種として SplitMix64 で広げ、`random_state` に入れる。`getrandom::u64()` を `IoRuntime::new` の前に呼んで値を保ち、作った後に入れてもよい。`getrandom` が失敗したら、処理系の不具合として実行を終える（`src/runtime/run.rs` の `internal_end` で、イベントループを作れないときと同じく終える。10-16）。テスト用の部品で作る実行（`RunEnv::parts` が `Some`）も同じく OS の乱数を使う。テストで値を固定するときは、スクリプトの `Random.Generate` のハンドラで固定する（01-07）。

## 受け入れテスト

- 決まった列（ADR 0172 が求める、版によらない列）: 種 0・1・−1・2^63 − 1 について、`fromSeed` から `nextInteger`（幅 1、幅 6、幅 2^63 を超える幅）・`nextFloat`・`shuffleWith` を続けた値の列を、03-07 の手順を別に書き下したテストの中の参照の実装（テストのモジュールの中に置く、同じ手順の素直な実装）と比べる。SplitMix64 と xoshiro256** の値は、テストの中に書き下した参照の実装（Vigna の `splitmix64.c`・`xoshiro256starstar.c` の式を素直に写したもの。式の出典の URL をテストのコメントに書く）との比較で確かめる。作者の参照の値をネットワークから取得しない。
- やり直しの経路: 幅 n が 2 の累乗でないとき、x がやり直しの範囲に入る値を与えて（xoshiro の状態を直接作る非公開の関数をテストで使う）、次の x が使われる。n = 2^63 + 1 ではやり直しの範囲がほぼ半分になるので、この幅で、最初の x がやり直しの範囲に入る種をテストの中で探して使う形でもよい。
- 範囲: `nextInteger(g, low, high)` の値が `low` 以上 `high` 未満、`nextFloat` の値が 0.0 以上 1.0 未満。`high = low` と `high < low` で実行時エラー。`low = Integer の最小値`、`high = Integer の最大値` で溢れない。
- 引数を変えない: `nextInteger` の前後で、同じ生成器から同じ値が得られる（純粋な関数である）。
- 隠れた生成器: 状態を与えた `IoView`（テスト用の部品で作ったもの）で `Random.integer` などが、同じ状態の純粋な生成器と同じ値を返す。空のリストの `choose` が `Option.None` で、状態を進めない。
- スクリプト: `handle` で `Random.Generate` の操作を処理して値を固定できる。二回の実行で `Random.integer(0, 1000000)` の列が（ほぼ確実に）違う（種が OS の乱数である）。
- `run_test` の経路: `run_test` で実行したテストの関数の中でも隠れた生成器に種が入っている（`Random.integer(0, 1000000)` を何回か呼んで、すべてが 0 ではない。種が入らず状態が 0 のままの xoshiro256** は 0 だけを返す）。
- スクリプトのテストで U3 の非公式のモジュールを取り込むときは、非公式の名前（`import Benitoite.Unofficial.IO.Random` など。ADR 0286 の決定 3）で書く。03-08 などの設計書の例の `import Benitoite.Json` の形（非公式の名前を使わない形）を写すと、E0321 になる。

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

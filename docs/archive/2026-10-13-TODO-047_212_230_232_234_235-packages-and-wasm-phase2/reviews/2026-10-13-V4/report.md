# 作業 V4 のレビュー

- 対象: コミット `b26b069c`（`san_benito` には `ba063822` で取り込み済み）。`external/typed.rs`（新規）、`external/runtime.rs`・`mod.rs`・`check.rs`・`convert.rs`、`bytecode/liveness.rs`・`verify.rs` のテストの組み立て、03-10・02-09・02-07、リファレンス 21 節、CHANGELOG。
- 根拠: `decisions.md` の Q7・R6、`plan.md` の共通の決まりと作業 V4、`reviews/preflight-V4V5.md`、`study/B-wasm.md` の 4 節、AGENTS.md、スキル test-audit、実装担当の報告。
- 方法: `git show` でコードと文書を読み、wasmtime-49.0.2 のソース（`component/func.rs` の `call_raw`、`func/typed.rs` の `TypedFunc::call`・`post_return`・`WasmStr::new`・`WasmList::new`、`func/options.rs` の `consume_fuel`、`store.rs` の `validate_sync_call`）と突き合わせた。cargo は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

正しさに関わる High・Medium の指摘はない。照合は `Integer→s64`、`Float→f64`、`String→string`、`Bytes→list<u8>` を一対一で決めるので、340 通りの具体化はどれも Wasmtime の型検査を通る。ヒープから借りた値は `NoGcCtx` の借用の中でだけ使う。予算の数え方、失敗の分類、post-return の扱いも、動的な経路と Wasmtime の実装に合う。指摘は Low の 5 件。

## 指摘

### L1（Low）共通化で、動的な経路の引数の予算の検査がインスタンス化の後へ移った

- 場所: `external/runtime.rs` の `call_with_fuel` と `call_dynamic`。変更前は `check_arguments` と `to_wasm` を `Component::from_binary`・`Store::new`・`instantiate` の前に行っていた。
- 問題: 予算を超える引数でも、先にコンパイルとインスタンス化（start 関数の実行を含む）を行ってから拒否する。インスタンス化も失敗する場合に報告する誤りが変わる（start 関数が `unreachable` を実行するコンポーネントに 7 MiB の `Bytes` を渡すと、R0905 から R0601 に変わる）。意図しない振る舞いの変化で、どのテストも順序を確かめていない。
- 修正案: 予算の検査と引数の準備を `Store::new` の前に行う。型付きの経路は、借用と予算の検査を行う処理と、呼び出す処理の二つに分ける。

### L2（Low）型付きの経路で、複数の引数の予算の合算を確かめるテストがない

- 場所: `typed.rs` の `call` の合算、テスト `typed_transfer_limits_apply_to_arguments_and_results`。
- 修正案: `(string, list<u8>) -> s64` に 600 バイトずつ渡し、`transfer: 1024` で `ExternalTransfer`、`1200` で成功することを確かめる場合を足す。

### L3（Low）テストの `call_both` が本番の Store の設定を写して持っている

- 修正案: Store を作って上限を設定する非公開の補助の関数を本番の側に切り出し、`call_with_fuel` と `call_both` の両方から呼ぶ。

### L4（Low）03-10「実行」の「理由:」の段落の構成と、例外の文の位置

- 場所: 03-10「実行」の燃料・予算の【決定】の段落（117 行付近）。02-09「外部の関数の実行」の予算の段落も同じ形。
- 問題: 速い経路の 3 文が動的な経路の数え方の列挙の間に入り、後の規則が速い経路の規則に読める。「理由:」に異なる決定の理由と決定の文が混ざっている。
- 修正案: 速い経路の文を子の値の規則の後に移し、その直後に速い経路の理由を分けて置く。02-09 も同じ位置に移す。

### L5（Low）CHANGELOG の項目の位置

- 修正案: V4 の項目を、「Packages and external functions are experimental…」の前置きの段落の後へ移す（V7 でもよい）。

## 確かめて問題がなかった点

- 経路の判定は R6 のとおり（4 個以上・戻り値なし・`List[Byte]`・V3 の型などは動的な経路）。印は照合の後の変換表から作る。`ExternalSpec` の `route` は共有できる型である。
- 340 通りの具体化は引数の順を保ち、`(7, 0.5, 2) → 5.5` のテストで取り違えを検出できる。戻り値の 4 種類は `call_raw` の前提を満たす。
- 借用と回収: 借用は `typed::call` の中で捨て、確保は借用が終わった後。`Linker` に何も登録していないので、呼び出しの間にホストへ戻らない。
- 予算: 引数は文字列と `Bytes` のバイト数の合算、戻り値は Wasmtime の `WasmStr::new`・`WasmList::new` が 1 バイトにつき 1 を消費する。動的な経路と 256 MiB は変えていない。
- 大きさの上限と UTF-8、燃料・メモリ・epoch・中断・失敗の分類は、二つの経路で共有している。
- post-return: wasmtime 49.0.2 の `TypedFunc::post_return` は非推奨で何もせず、`call_raw` が自分で呼ぶ。02-09 の記述は正しい。
- 規約（`unsafe` なし、宣言のマクロ、`unwrap` 等なし）、テスト（関門、`spec:`、NaN・無限大・空の値・3 引数の混在、10 MiB の往復は 0.12 秒）、設計書（文の配置は L4）は問題ない。
- 実行ファイルの増分: release で +907,008 B、strip の後で +646,976 B（20,657,504 → 21,304,480）。

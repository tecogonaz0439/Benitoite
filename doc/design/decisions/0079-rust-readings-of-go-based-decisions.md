# 0079. Go を前提にした処理系の判断を、Rust に合わせて読み替える

- 状態: 採択（決定 2 のうち `unsafe` を使わないことを、[0240](0240-runtime-redesign-in-first-release-plan.md) で作り直しまでの規約に改めた）
- 日付: 2026-09-27
- 関連章: [パイプライン](../02-impl/02-01-pipeline.md), [仮想機械](../02-impl/02-08-vm.md), [ランタイム](../02-impl/02-09-runtime.md), [CLI](../06-tooling/06-01-cli.md), [用語集](../00-overview/00-04-glossary.md), [性能](../07-quality/07-02-performance.md)
- 関連する未決事項: なし

## 背景

処理系を Rust で実装する（[ADR 0076](0076-initial-implementation-in-rust.md)）。処理系の設計の ADR のうち、次のものは Go の語や挙動で書かれている。判断の趣旨は実装言語によらないものが多いが、細部は Rust の挙動に合わせる必要がある。

- [ADR 0015](0015-shared-program-per-execution-state.md): goroutine
- [ADR 0016](0016-calls-off-go-stack.md): Go のスタック、Go の関数
- [ADR 0028](0028-tagged-struct-values.md): Go の構造体、`unsafe` パッケージ
- [ADR 0029](0029-two-io-execution-modes.md): Go の関数
- [ADR 0044](0044-heap-exhaustion-outside-stop-procedure.md): Go のランタイムの致命的なエラー、終了状態 2

Rust について、次のことを一次資料で確かめた（2026-09-27）。

- 標準ライブラリを使うプログラムでは、`handle_alloc_error` の既定の振る舞いは、標準エラー出力にメッセージを書いてプロセスを abort することである（[handle_alloc_error](https://doc.rust-lang.org/std/alloc/fn.handle_alloc_error.html)）。
- `catch_unwind` が捕らえるのは、巻き戻しによる panic だけであり、abort による panic は捕らえない（[catch_unwind](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html)）。
- Unix では、標準ライブラリが `main` の前に SIGPIPE を無視する設定にし、閉じたパイプへの書き込みは `ErrorKind::BrokenPipe` の誤りになる（[on-broken-pipe](https://doc.rust-lang.org/beta/unstable-book/compiler-flags/on-broken-pipe.html)）。

## 決定

1. ADR 0015 と ADR 0016 と ADR 0029 の「goroutine」は「スレッド」、「Go の関数」は「Rust の関数」、「Go のスタック」は「処理系のスタック」と読み替える。判断の内容は変えない。
2. ADR 0028 の値の表現は、Rust の列挙型で表す。数値・真偽値・文字・Unit の値はヒープを確保せず、ヒープの対象は参照カウントで指す（[ADR 0078](0078-reference-counting-in-minimal.md)）。`unsafe` は使わない。ADR 0028 の決定のうち「三つの欄を持つ構造体」を、この形に改める。
3. ADR 0044 の決定のうち、ヒープが尽きたときの終わり方を改める。ヒープの確保に失敗したときは、Rust の標準ライブラリの既定の振る舞い（標準エラー出力にメッセージを書いて abort する）で終わる。このときの終了状態は OS が決め、処理系は定めない。評価意味論の停止の手順によらずに終わってよいという判断は変えない。
4. panic 境界は、処理系を巻き戻しの panic でビルドし、VM の実行全体を `catch_unwind` で囲んで作る。捕らえた panic は、これまでと同じく処理系の不具合として報告し、終了状態 3 で終わる。
5. 閉じたパイプへの書き込みは、Rust の既定の設定のまま、書き込みの誤りとして受け取る（[ADR 0045](0045-late-detection-of-output-write-failure.md) の書き込みの失敗として扱う）。

## 検討した代替案

- **各 ADR を一件ずつ置き換える**: 判断の趣旨が変わらないものまで置き換えると、変わった判断がどれかが分かりにくくなる。読み替えを一件にまとめ、趣旨が変わるもの（値の表現、メモリが尽きたときの終わり方）だけを明示した。

## 帰結

- ADR 0015・0016・0028・0029・0044 の状態を「採択（決定の一部を 0079 で改めた）」とする。
- abort で終わると、処理系の形式の診断は出ない。利用者は、標準エラー出力のメッセージで処理系の不具合や検査の誤りと見分ける。

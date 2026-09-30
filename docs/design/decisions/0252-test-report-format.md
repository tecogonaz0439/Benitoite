# 0252. テストの結果の報告の文章の形と JSON Lines の項目を定める

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md), [診断エンジン](../02-impl/02-10-diagnostics.md)
- 関連する未決事項: [OPEN-058](../open-issues.md#open-058)

## 背景

[ADR 0208](0208-test-report-destination.md) は、テストごとの結果と集計を標準出力に書き、`--diagnostics=json` では JSON Lines で書くとし、文章の形の細部と JSON の項目の名前を [OPEN-058](../open-issues.md#open-058) に残した。初回リリース版の実装プランの前に決める必要がある。

## 決定

1. 文章の形は、Rust の `cargo test` の形に合わせる。テストごとに `test <ファイル>: <名前> ... ok` か `... FAILED` の一行を書く。名前は、`@test` の説明があれば引用符で囲んだ説明、なければ関数の名前とする。
2. 失敗したテストがあれば、すべてのテストの行の後に `failures:` の見出しを書き、失敗したテストごとに `---- <ファイル>: <名前> ----` の見出しと、失敗の詳細を書く。失敗の詳細は、失敗の理由ごとに [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)の「結果の報告」の表のものを示す。位置と呼び出しの履歴は、[診断エンジン](../02-impl/02-10-diagnostics.md)の文章の形式と同じ形で書く。テストが標準出力と標準エラー出力に書いた内容があれば、`---- captured stdout ----`・`---- captured stderr ----` の見出しに続けて示す。
3. 最後に `test result: ok.` か `test result: FAILED.` に続けて、成功の数と失敗の数を書く。検査の誤りでテストを実行しなかったファイルがあれば、その数を書く。中断の要求で終えたときは、そのことを書く。
4. テストを並行に動かしても、報告はファイルを指定した順（ディレクトリの下では、パスの辞書順）と、ファイルの中のテストの関数の宣言の順に書く。報告が実行ごとに変わらないようにするためである。
5. JSON Lines の形では、テストごとに `kind` が `"test"` の一行を書く。項目は、`file`、`name`（説明か関数の名前）、`function`（関数の名前）、`location`（関数の宣言の位置。診断の位置の形）、`outcome`（`"passed"` か `"failed"`）、`failure`（成功では `null`）、`stdout`、`stderr`（捕らえた内容の文字列）とする。
6. `failure` は、`reason`（`"assert"`・`"error"`・`"runtime"`・`"exit"`）、`message` と、理由に応じた項目を持つ。`"assert"` は失敗した確認の `primary`（位置の形）と `trace`、`Assert.equal`・`Assert.notEqual` では値を書き出した文字列 `left`・`right` を持つ。`"error"` は `Result.Error` の文字列を `message` に持つ。`"runtime"` は、実行時エラーの報告の JSON の形式の項目（`code`・`primary`・`trace`・`traceOmitted`・`taskOrigins` など）を持つ。`"exit"` は `Process.exit` の終了状態 `exitCode` を持つ。
7. 最後に `kind` が `"testSummary"` の一行を書く。項目は、`passed`、`failed`、`filesNotRun`（検査の誤りで実行しなかったファイルの数）、`interrupted`（中断の要求で終えたか）とする。

## 検討した代替案

- **大枠だけを決め、文面と項目の名前を実装プランで決める**: 設計の手間は少ない。しかし、テストの報告はエージェントと利用者が読む出力であり、ゴールデンテストの期待値にもなるので、実装の前に形を固めておく。

## 帰結

- [利用者プログラムのテスト](../06-tooling/06-04-test-runner.md)の「結果の報告」に形を書き、OPEN-058 を決着させる。

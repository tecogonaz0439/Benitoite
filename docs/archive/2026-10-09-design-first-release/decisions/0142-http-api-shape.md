# 0142. HTTP サーバを、待ち受けのリソースの層と、要求から応答への関数を渡す `Http.serve` の二層で提供し、経路の振り分けは組み込まない

- 状態: 採択（ネットワークの失敗の型を [0145](0145-network-error.md) で `NetworkError` と定めた。リダイレクトの権限の判定を [0147](0147-remove-permission-declaration-syntax.md) で [OPEN-052](../open-issues.md#open-052) に移した。`Http.Exchange` の解放の失敗の扱いを [0149](0149-http-exchange-release-failure.md) で定めた。解放する関数のエフェクトを [0150](0150-resource-release-as-state.md) で `State` に改めた。`Http.accept` の失敗の扱いを [0170](0170-http-accept-failure-classification.md) で分けた）
- 日付: 2026-09-28
- 関連章: [ネットワークのモジュール](../03-interop/03-09-network.md), [並行処理](../01-spec/01-11-concurrency.md), [リソース管理](../01-spec/01-10-resources.md), [テキストとデータの処理](../03-interop/03-08-text-and-data.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-045](../open-issues.md#open-045), [OPEN-034](../open-issues.md#open-034)

## 背景

標準ライブラリに HTTP/1.1 のサーバとクライアントを入れる（[ADR 0141](0141-http-scope-in-stdlib.md)）。並行処理の章は、接続を受け付けるたびに要求の処理をタスクとして起動する例を、仮の名前で示している（[並行処理](../01-spec/01-11-concurrency.md)）。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「標準ライブラリの HTTP」に記録した。要点は次のとおりである。

- Deno（`Deno.serve`）・Bun・Racket・Roc（basic-webserver）と、Gleam の Wisp（パッケージ）は、要求を受け取って応答を返す関数をサーバに渡す。Go・Python・Java・Dart は、応答を書き込む手続きの形をとる。
- 経路の振り分けを組み込むのは、Go 1.22 以降（`"GET /posts/{id}"`）と Bun（`routes`）である。Deno・Dart・Python は組み込まない。
- JSON の応答を作る補助の関数は、Web の標準の `Response.json`（Deno・Bun）にある。

## 決定

1. サーバは二つの層で提供する。
   - 下の層: 待ち受けのリソースの型 `Http.Listener` と、受け付けた一つの要求と応答の組を表すリソースの型 `Http.Exchange`。関数は `Http.listen`・`Http.accept`・`Http.respond` などである。
   - 上の層: 要求から応答への関数を渡す `Http.serve(host, port, handler)`。`Http.serve` は標準ライブラリのソース（言語）で、下の層と `TaskGroup` を使って書き、受け付けた要求ごとにタスクを起動して `handler` を呼ぶ。
2. 経路の振り分けは組み込まない。要求のパスを区切ったリストを、`case` のパターンで照合して振り分ける。パスを区切る関数 `Http.pathSegments` を置く。
3. 要求は `Http.Request`（method・path・query・headers・body）、応答は `Http.Response`（status・headers・body）のレコードで表す。本体（body）は `Bytes` とする。文字列との変換は `String.fromUTF8`・`String.toUTF8` で行う。
4. 応答を作る補助の関数 `Http.text`・`Http.html`・`Http.json` を置く。`Http.json` は `Benitoite.Json` の `Json.Value` を受け取る。
5. クライアントは、状態コードが 4xx や 5xx の応答でも `Result.Ok` を返す。`Result.Error` は、接続できない、時間切れになるなど、応答を得られなかったときに返す。
6. クライアントの要求には、既定の時間切れを設ける。

関数の名前と型は[ネットワークのモジュール](../03-interop/03-09-network.md)で定める。

## 検討した代替案

- **`Http.serve` だけを置く**: 利用者が覚える関数は減る。しかし、要求ごとに異なる扱い（受け付けの数を絞る、受け付けの合間に別の処理をする）ができない。並行処理の章の、受け付けを繰り返す形の例も書けなくなる。
- **下の層だけを置く**: 構造化された並行処理の書き方を利用者が直接使う。しかし、簡単なサーバでも、受け付けの繰り返しとタスクの起動を毎回書くことになる（原則 6）。
- **経路の振り分けを組み込む（Go 1.22 や Bun と同じ）**: 経路を短く書ける。しかし、`"GET /items/{id}"` のような経路の書き方は、文字列の中の小さな言語であり、型で検査できない。パターンでの照合なら、経路の書き誤りの一部（変数の使い忘れなど）を検査で見つけられ、同じ役割の書き方も増えない（原則 5）。
- **本体を `String` にする**: テキストの要求と応答は短く書ける。しかし、画像などのバイナリを扱えない。`String.fromUTF8` で変換すれば、正しくない UTF-8 の扱いも利用者のコードに現れる。
- **4xx と 5xx を `Result.Error` にする**: 失敗を `try` で扱える。しかし、404 を正常な結果として扱うスクリプトも多い。外部コマンドの起動が 0 以外の終了状態でも `Result.Ok` を返すこと（[IO のモジュール](../03-interop/03-07-io-modules.md)）と揃える。

## 帰結

- 並行処理の章の例の仮の名前を、`Http.listen`・`Http.accept` などの名前に改める。
- `Http.serve` の実装は、構造化された並行処理の実例として読める。
- ネットワークの失敗を表す `IOErrorKind` の構成子は、[OPEN-034](../open-issues.md#open-034) で構成子の一覧を確定するときに決める。
- リダイレクトを辿るときの権限の判定は、権限の宣言の書き方とあわせて [OPEN-045](../open-issues.md#open-045) で決める。

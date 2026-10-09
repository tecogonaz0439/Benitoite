# L31 `Http.serve` と、応答を作る関数・要求を調べる関数

- 依存する作業: [L30](L30-http-server.md)、[L21](L21-json.md)、[R25](R25-tasks-and-scheduler.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L31-http-serve-and-helpers

## 目的

HTTP のサーバの上の層を仕上げる。組み込みの関数 `Http.pathSegments` の本体を書き（10-15 の部分 44、`http_util::DECLS`）、L00 が置いたソースの関数 `Http.serve`・`Http.text`・`Http.html`・`Http.json`・`Http.header` を確かめる。`Http.serve` は、受け付けた要求ごとに `TaskGroup.spawn` でタスクを起動して `handler` を呼ぶ（03-09「サーバ」）。ロードマップの初回リリース版の「スクリプトで簡易な HTTP サーバを動かせる」を、スクリプトとして確かめる最初の作業である。

| 項目 | 権限 |
|---|---|
| `Http.pathSegments` | `Pure` |
| `Http.serve`・`text`・`html`・`json`・`header`（ソース） | — |

依存の理由: `Http.serve` は L30 の操作を呼ぶ。`Http.json` は `Json.stringify`（L21）を呼ぶ。`TaskGroup` と引き継いだハンドラの規則は R25 が作った。

## 読む設計書の節

- [ネットワークのモジュール](../../design/03-interop/03-09-network.md)の「サーバ」（`Http.serve` の書き方、`handler` の実行時エラー、引き継いだハンドラの節の規則）、「応答を作る関数と、要求を調べる関数」
- [並行処理](../../design/01-spec/01-11-concurrency.md)の「タスクの集まり」「タスクとハンドラ」「失敗と停止」
- ADR: [0142](../../design/decisions/0142-http-api-shape.md)、[0151](../../design/decisions/0151-inherited-handlers-tail-resume-only.md)、[0153](../../design/decisions/0153-taskgroup-open-only-in-with.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「ネットワーク」の表と `Network/Http.bnt`
- L30 の作業の文書（統合テストの組み方）

## 作るもの

- `src/builtins/funcs/http_util.rs` の `Http.pathSegments` の本体と単体テスト。L00 が置いた仮の本体の引数 `arg0: Value<'e>` は、`path: &'c str` に書き換えてよい（L20 の `path.rs` が前例。項目の名前・権限・引数の数と位置は変えない）
- ソースの関数を確かめるスクリプトの統合テスト（HTTP の要求はテストの中の Rust の `TcpStream` で送る。スクリプトからのクライアント（L32）を待たない）

## 手順の要点

- `Http.pathSegments(path)`: `/` で区切り、空の要素を除き、各要素のパーセント符号化を戻す。戻した結果が正しい UTF-8 でない要素は、戻さずに残す（03-09）。`%` の後に 16 進の 2 桁が続かない要素（`%G0`・末尾の `%`）も、戻さずに残す。これは 03-09 が定めていない場合なので、戻せない要素と同じ扱い（そのまま残す）とし、`///` のコメントと完了の報告に書く。`+` は空白に戻さない（パスの `+` は文字であり、03-09 は `+` を空白に戻す規則をクエリにだけ定める）。
- ソースの関数は L00 が置いた。変えずに、スクリプトで確かめる。ソースの誤りを見つけたら、作業を止めて報告する。
  - `Http.serve` のソースは待ち受けを `with` で解放するので、その解放の失敗は実行時エラーになる（01-10「解放の失敗」。`Http.Listener` は例外でない）。`closeListener` が解放の失敗を `Result.Error` で返す口（`StateServices::begin_close`、ADR 0321）は L12 が加え、`closeListener` の本体は L30 が書いた。本作業はどちらも変えない。
- `Http.serve` は待ち受けを終えずに要求を受け付け続け、自分からは終わらない。`Http.serve` を動かすスクリプトのテストは、次の形で終える。`main` で `Reference` を偽で作り、`handler` は `GET /stop` を受けたらその `Reference` に真を入れて応答する。`main` は `Http.serve` を `Task.race` で相手のタスクと競わせる。相手のタスクは、`Clock.sleep` を挟みながらその `Reference` が真になるのを待ち、真になったら `Result.Ok(())` を返す。相手が先に終わるので、`Task.race` が `Http.serve` のタスクを取り消して終える。Rust のテストは、確かめる要求を送り終えて応答を確かめた後に `GET /stop` を送る。
- `Task.race` は `uses Clock.Time, State, E` を持つ（01-11「タスクを起動する関数」の表）。スクリプトは `import Benitoite.Unofficial.IO.Clock` を加え、`main` を `uses Http.Listen, Clock.Time, State`（`handler` が使うほかのエフェクトがあれば加える）とする。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Network.Http`・`import Benitoite.Unofficial.Json`・`import Benitoite.Unofficial.IO.Clock`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-09 の例の `import Benitoite.Network.Http` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- `Http.pathSegments` の単体テスト: `"/"` で `[]`、`"/items/42"` で `["items", "42"]`、`"//a//b/"` で `["a", "b"]`、`"/a%20b"` で `["a b"]`、`"/%E3%81%82"` で `["あ"]`、`"/%FF"` で `["%FF"]`、`"/%G0"` で `["%G0"]`、`"/a+b"` で `["a+b"]`。
- スクリプト（統合テスト）:
  - 03-09 の `route` の例と同じ形のサーバを `Http.serve("127.0.0.1", 0, …)` では動かせない（ポートを知る手段がない）ので、`Http.listen` と `Http.listenerPort` でポートを決めた後に同じ `handler` を使う形と、テストが空いたポートを選んで `Http.serve` に渡す形（上の `GET /stop` と `Task.race` で終える）の両方で、`GET /`・`GET /items/1`・存在しない経路の応答を確かめる。
  - ポートの知り方は L30 と同じとする。前者の形では、スクリプトが `Http.listenerPort` の値を標準出力に一行で書き、テストは `OutputTarget::Capture` の `Arc<Mutex<Vec<u8>>>` を別のスレッドから短い間隔でのぞいてその行を待つ（上限はたとえば 30 秒。L30 の受け入れテストの「OS が選んだポートの知り方」）。後者の形では、テストが選んだポートをスクリプトに渡し、`Http.serve` が待ち受けを始めるまでの接続の拒否（`ConnectionRefused`）は、Rust の側で短い間隔をおいてやり直す（同じく十分に長い上限を付ける）。
  - `Http.text`・`Http.html`・`Http.json` の `content-type` と本体、`Http.header` が大文字と小文字を区別しない。
  - 多数の要求を並べて送り、すべてに応答する。
  - 一つの `handler` が長く計算している間に、別の要求に応答する（要求ごとにタスクを起動している）。要求 A の `handler` は、要求 B の `handler` が `Reference` に印を付けるまで、計算の繰り返しで待つ（`Clock.sleep` は使わない）。繰り返しには十分に大きな回数の上限を付け、上限に達したら失敗の応答（状態コード 500 など）を返す。テストは A を送った後に B を送り、A に成功の応答が来たことで、A の `handler` が計算を続けている間に B の `handler` が動いた（要求ごとにタスクを起動している）ことを確かめる。
  - `handler` の中の実行時エラーがプログラム全体を止める（03-09、01-11「失敗と停止」）。確かめるのは、実行の終わりが `RunEnd` の `Stopped` であることと、実行時エラーの報告だけとする。クライアントの側に何が返るか（応答が来ないか、接続が切れるか）は、止める手順の時機に依存するので期待に固定しない。
  - `Http.serve` を囲む `handle` で `handler` のエフェクトを処理するとき、末尾で再開する節は使え、そうでない節は実行時エラー（引き継いだハンドラの節の誤り。ADR 0151）になる。
  - 待ち受けを始められないとき（使われているポート）に `Result.Error` を返して終わる。Rust の側でポートをふさぐ待ち受けは、スクリプトと同じ `127.0.0.1` で開く（アドレスが違うと OS によってはふさがない）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- `%` の後が 16 進でない要素の扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- テストが実時間の待ちに頼らずに書けているか（ループバックの通信は実際に行うが、順序は `Task.all` の結果を受け取ってから確かめるなど、切り替えの時機によらない形で確かめる。07-03「ゴールデンテスト」の `concurrency` と `network` の方針）。

## 難易度の理由

組み込みの関数は一つで短い。仕事の中心は、サーバをスクリプトとして動かして、タスクの起動、引き継いだハンドラ、実行時エラーの扱いが 03-09 のとおりになることを確かめることである。

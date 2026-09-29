# 0181. サーバモードのサブコマンドを、その場で渡すスクリプトの `exec` と、登録したスクリプトの `job` に分ける

- 状態: 採択（`job status`・`job stop` が名前か ID を、`job logs` が ID を取る形に、[サーバモード](../06-tooling/06-07-server.md)の「サブコマンド」で細かくした）
- 日付: 2026-09-29
- 関連章: [CLI](../06-tooling/06-01-cli.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055)

## 背景

設計者は、サーバモードのサブコマンドとして、`server start`・`stop`・`restart`・`status`・`settings`・`regist`・`unregist`・`run`（文字列かファイルで渡したスクリプトを前景で実行する）・`run start`（登録したスクリプトを前景か背景で実行する）・`run status`・`run stop` を提案した（[OPEN-055](../open-issues.md#open-055)）。

この形には、次の二つの問題がある。

- `server run <ファイル>` と `server run start <名前>` は、同じ位置に、ファイルのパスとサブコマンドの名前のどちらも書ける。`start` という名前のファイルを `run` で実行しようとすると、`run start` と区別できない。
- `regist`・`unregist` は、英語の語として通じにくい。処理系の語は省略しない綴りにしている（[ADR 0092](0092-unabbreviated-keywords.md)、[ADR 0101](0101-unabbreviated-names.md)）。

## 決定

サーバモードのサブコマンドを、次の形とする。その場で渡すスクリプトの実行と、登録したスクリプトの操作を、別のサブコマンドに分ける。

```text
benitoite server start | stop | restart | status
benitoite server settings …
benitoite server register <パス> [--name <名前>]
benitoite server unregister <名前>
benitoite server exec <パス>
benitoite server exec -e '<ソース>'
benitoite server job start <名前> [--background]
benitoite server job status [<名前>] [--output]
benitoite server job stop <名前>
benitoite server job logs <名前>
```

- `exec` は、その場で渡したスクリプト（コーディングエージェントが生成したものを想定する）を実行する。出力を標準出力と標準エラー出力に逐次書くが、実行はデーモンが行う。
- `job start` は、登録したスクリプトを実行する。`--background` を付けなければ、`exec` と同じく出力を逐次書く。付ければ、実行を始めたら戻る。
- `job status` は、実行中と実行を終えたジョブの一覧を示す。`--output` を付ければ、出力も示す。`job logs` は、一つのジョブの出力を示す。

各サブコマンドのオプション、`settings` の中身、前景の実行中の中断（`Ctrl-C`）の扱い、標準入力と環境変数の受け渡しは、サーバモードの章で定める（[OPEN-055](../open-issues.md#open-055)）。

## 検討した代替案

- **提案の形のまま（`regist`・`unregist`・`run`・`run start` など）**: 背景のとおり、`run` の後の語がファイルのパスかサブコマンドの名前かを区別できない。
- **`run` のファイルのパスを、オプション（`run --file <パス>`）でだけ受け取る**: 取り違えはなくなる。しかし、その場で渡すスクリプトの実行と、登録したスクリプトの操作が、同じ `run` の下に混ざったままになる。

## 帰結

- 同じ役割のサブコマンドが一つずつになり、LLM と利用者がコマンドを取り違えにくい（原則 5）。
- スタンドアロンモードの `benitoite run` と、サーバモードの `benitoite server exec` は、名前が違う。スタンドアロンモードの `run` を省いた実行（[ADR 0135](0135-shebang-line-and-implicit-run.md)）は変えない。サブコマンドの名前には、`server` と、MCP サーバの `mcp`（[ADR 0182](0182-mcp-server-as-stdio-relay.md)）が加わる。これらと同じ名前のファイルを `run` を省いて実行するときは、`./server` のようにパスとして書く。

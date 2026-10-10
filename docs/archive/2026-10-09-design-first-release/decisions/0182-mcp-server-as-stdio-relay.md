# 0182. MCP サーバを、デーモンへ要求を中継する `benitoite mcp` とする

- 状態: 採択（決定 3 の、道具とその入出力を定める章を [0203](0203-mcp-tools-and-agent-configuration.md) と [0210](0210-mcp-in-server-chapter-and-explain-tool.md) で改め、[サーバモード](../06-tooling/06-07-server.md)とした）
- 日付: 2026-09-29
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055)

## 背景

MCP サーバは、サーバモードとあわせて、初回リリース版の後に提供する（[ADR 0177](0177-server-mode-after-first-release.md)）。コーディングエージェントのハーネスは、MCP サーバを子プロセスとして起動し、標準入出力で通信する形をとることが多い。この形では、ハーネスとの接続が切れると MCP サーバのプロセスも終わる。一方、サーバモードの狙いの一つは、SSH の接続が切れても、エージェントが始めた実行を続けることである（[OPEN-055](../open-issues.md#open-055)）。

## 決定

1. MCP サーバは、同じ実行ファイルのサブコマンド `benitoite mcp` とする。標準入出力で MCP の通信をする。
2. `benitoite mcp` は、自分ではスクリプトを実行しない。受けた要求を、デーモンのクライアントとしてデーモンに中継する。スクリプトの検査と実行は、デーモンが行う（実行は [ADR 0180](0180-server-in-same-binary-with-per-run-processes.md) の子プロセス）。
3. MCP の道具は、サーバモードのサブコマンド（[ADR 0181](0181-server-subcommands.md)）に対応させる。どの道具を設けるかと、その入出力は、「MCPサーバとLSPサーバ」の章（現在の [LSP サーバ](../06-tooling/06-02-lsp.md)）で定める。
4. HTTP で遠隔から使う MCP サーバは、初回の実装に含めず、後で検討する。

## 検討した代替案

- **デーモン自身が HTTP で MCP の要求を受ける**: 中継のプロセスが要らない。しかし、デーモンがネットワークに口を開くので、その口の認証を設計する必要がある。MCP の仕様が定める HTTP での認可の方式に合わせる作業も加わる（【要検証】）。
- **別の実行ファイル（`benitoite-mcp`）にする**: 配布物が増え、単一バイナリで配る方針（[ADR 0176](0176-first-release-targets-and-static-linux-build.md)）から外れる。

## 帰結

- ハーネスとの接続が切れて `benitoite mcp` が終わっても、デーモンが始めたジョブは続く。
- エージェントにデーモンの通信口だけを使わせる前提（[ADR 0179](0179-threat-model-and-server-mode-premise.md)）のもとで、エージェントに与える道具を MCP の道具に絞れる。
- `benitoite mcp` は、デーモンが動いていないときの振る舞い（デーモンを起動するか、誤りを返すか）を、サーバモードの章で定める。

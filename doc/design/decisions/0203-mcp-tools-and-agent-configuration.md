# 0203. MCP の道具を認証の要らない操作に限り、エージェントにはシェルからの `benitoite` の実行を拒否させて MCP だけを使わせる

- 状態: 採択（決定 1 を [0210](0210-mcp-in-server-chapter-and-explain-tool.md) と [0219](0219-mcp-job-start-returns-pending-for-approval.md) で改めた）
- 日付: 2026-09-29
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055), [OPEN-057](../open-issues.md#open-057)

## 背景

MCP サーバはデーモンへの中継とし（[ADR 0182](0182-mcp-server-as-stdio-relay.md)）、エージェントにスタンドアロンモードを使わせない制限はエージェントの側の設定で行う（[ADR 0193](0193-restricting-agents-to-server-mode-by-agent-config.md)）。

主なエージェントのサンドボックスは、既定で Unix ソケットへの接続を塞ぐ。Claude Code は、Linux と WSL2 ではすべての Unix ソケットを許す設定しか持たない（[settings](https://code.claude.com/docs/en/settings-reference)）。シェルから `server exec` を使わせると、エージェントのサンドボックスを広く緩めることになる。

## 決定

1. MCP の道具は、`check`・`exec`・`job_start`・`job_status`・`job_stop`・`job_logs`・`list_scripts` とする。認証を要する操作（`register`・`unregister`・`settings`）は、道具にしない。
2. エージェントには、MCP の道具を使わせ、シェルからの `benitoite` の実行はすべて拒否させる設定を勧める。各エージェントの設定の例を、[サーバモード](../06-tooling/06-07-server.md)と同梱の Agent Skill に載せる。

## 検討した代替案

- **シェルから `server exec` を使わせる**: MCP に対応しないエージェントでも使える。しかし、デーモンの通信口への接続を許すため、エージェントのサンドボックスを広く緩めることがある。

## 帰結

- MCP サーバとして起動した `benitoite mcp` が、エージェントのシェルのサンドボックスの外で動くことを前提とする。これは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

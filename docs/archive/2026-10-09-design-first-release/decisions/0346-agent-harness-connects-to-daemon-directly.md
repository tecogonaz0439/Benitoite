# 0346. エージェントハーネスはデーモンの通信口に直接つなぎ、LLM に見せる道具の形を MCP の道具と揃える

- 状態: 採択
- 日付: 2026-10-08
- 関連章: [エージェントハーネス](../06-tooling/06-08-agent-harness.md), [サーバモード](../06-tooling/06-07-server.md)
- 関連 ADR: [0182](0182-mcp-server-as-stdio-relay.md), [0203](0203-mcp-tools-and-agent-configuration.md), [0210](0210-mcp-in-server-chapter-and-explain-tool.md), [0342](0342-agent-harness-after-server-mode.md)
- 関連する未決事項: [OPEN-056](../open-issues.md#open-056), [OPEN-097](../open-issues.md#open-097)

## 背景

エージェントハーネスは、サーバモードを通してスクリプトを検査・実行する（[ADR 0194](0194-tui-and-own-coding-agent-with-server-mode.md) の決定 2）。サーバモードには、利用者と外部のエージェントが使う二つの口がある。`benitoite server …` のクライアントがデーモンの通信口に JSON-RPC の要求を送る口と、標準入出力で MCP の要求を受けてデーモンに中継する `benitoite mcp`（[ADR 0182](0182-mcp-server-as-stdio-relay.md)）である。

設計者は、2026-10-04 に、エージェントハーネスがどちらを使うかを決めた（[自前のエージェントハーネスの検討メモ](../sources/post-first-release/post-first-release-agent-harness.md)の「サーバモードとの接続」）。

## 決定

1. エージェントハーネスは、デーモンの通信口に直接つなぐ。エージェントハーネスは処理系と同じ実行ファイルの中にあるので、`benitoite server …` のクライアントと同じ部品で要求を送る。
2. エージェントハーネスが LLM に見せる道具の形（名前、引数、返す JSON）は、MCP の道具（[サーバモード](../06-tooling/06-07-server.md)の「MCP の道具」。[ADR 0203](0203-mcp-tools-and-agent-configuration.md)、[ADR 0210](0210-mcp-in-server-chapter-and-explain-tool.md)）と、同じ働きの道具どうしで揃える。

## 検討した代替案

- **MCP（`benitoite mcp`）を通す**: 外部のエージェントと同じ口を使うので、道具の振る舞いが揃う。しかし、同じ実行ファイルの中で MCP の中継を挟む分だけ層が増える。道具の形を揃えれば、振る舞いを揃える利点は直接つなぐ形でも得られる。

## 帰結

- Claude Code の CLI を経由する提供者（候補 L。[OPEN-097](../open-issues.md#open-097)）を採るときは、エージェントハーネスの道具を MCP で CLI に見せる必要がある。道具の形を MCP の道具と揃えておけば、その定義を流用できる。
- エージェントハーネスにしかない道具（`create_project`、`list_files`・`read_file`、`web_fetch` など。[ADR 0344](0344-agent-harness-operation-scope-and-tools.md)）は、エージェントハーネスのコードが実行し、デーモンには送らない。

# サーバモード

- 状態: 草稿
- 関連ADR: [0127](../decisions/0127-directory-run-and-root.md), [0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0179](../decisions/0179-threat-model-and-server-mode-premise.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0181](../decisions/0181-server-subcommands.md), [0182](../decisions/0182-mcp-server-as-stdio-relay.md), [0183](../decisions/0183-single-policy-for-all-permission-layers.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0185](../decisions/0185-default-policies-per-run-kind.md), [0186](../decisions/0186-run-time-policy-can-only-narrow.md), [0187](../decisions/0187-standalone-reads-user-policy-file.md), [0188](../decisions/0188-authentication-by-user-presence.md), [0189](../decisions/0189-tamper-evident-audit-log.md), [0190](../decisions/0190-ssh-signatures-for-scripts.md), [0191](../decisions/0191-server-data-storage.md), [0192](../decisions/0192-named-profiles-for-agents.md), [0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md), [0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md), [0195](../decisions/0195-daemon-as-os-user-service.md), [0196](../decisions/0196-os-sandbox-mechanisms.md), [0197](../decisions/0197-when-os-sandbox-is-unavailable.md), [0198](../decisions/0198-network-through-daemon-proxy.md), [0199](../decisions/0199-server-job-handling.md), [0200](../decisions/0200-policy-file-toml-and-locations.md), [0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md), [0202](../decisions/0202-signature-details.md), [0203](../decisions/0203-mcp-tools-and-agent-configuration.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0205](../decisions/0205-server-start-enables-linger-with-consent.md), [0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md), [0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md), [0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md), [0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md), [0217](../decisions/0217-audit-log-undetectable-cases-and-verification-start.md), [0221](../decisions/0221-audit-hash-chain-scope-corrected.md), [0218](../decisions/0218-allowed-signers-imported-copy.md), [0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md), [0220](../decisions/0220-places-referenced-by-default-policies.md), [0237](../decisions/0237-no-heap-usage-limit-in-first-release.md), [0250](../decisions/0250-run-directories-outside-daemon-data.md)
- 未決事項: [OPEN-015](../open-issues.md#open-015), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-056](../open-issues.md#open-056), [OPEN-057](../open-issues.md#open-057)
- 移行元: なし

## 目的と範囲

処理系をサーバとして動かす形（サーバモード）を定める。対象は、デーモンと関係するプロセスの構成、通信口、常駐、サブコマンドとその振る舞い、ジョブ、方針のファイル、登録と承認、認証、監査の記録、署名、保管、MCP の道具、コーディングエージェントの設定、サーバモードを加えた後のスタンドアロンモードである。

サーバモードは、初回リリース版の後に加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版の処理系は、本章のどの機能も持たない。

## 前提

保証の範囲と脅威モデルは[セキュリティモデル](../07-quality/07-01-security-model.md)で定める。サーバモードの保証は、コーディングエージェントが自身のサンドボックスの中で動き、デーモンの設定と保管したデータの置き場所に書き込めない場合に限る（[ADR 0179](../decisions/0179-threat-model-and-server-mode-premise.md)）。許可の単位と実行時の権限制御の規則は[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御（サーバモード）」で、子プロセスに掛ける OS のサンドボックスとプロキシへの経路は [OS のサンドボックス](../02-impl/02-12-os-sandbox.md)で、一回の実行の中身（検査、実行ごとの状態、止める手順）は[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)で定める。

本章で【方針】のまま残した細部（通信口、サブコマンドのオプション、実行と登録の手順）は、サーバモードを実装する前に見直す（[OPEN-055](../open-issues.md#open-055)）。

## 仕様

### 構成

【決定】サーバモードは、スタンドアロンモードと同じ実行ファイルに入れる（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。関係するプロセスは次のとおりである。

| プロセス | 起動するもの | 役割 |
|---|---|---|
| デーモン | OS のサービスの仕組み（後述の「常駐」） | 要求を受け、登録したスクリプトと方針を管理し、実行ごとの子プロセスを起動して見守り、出力と監査の記録を保存する。プロキシを持つ。OS のサンドボックスを掛けない |
| 子プロセス | デーモン | 一つのスクリプトを一回実行する。OS のサンドボックスと実行時の権限制御の中で動く（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)） |
| クライアント | 利用者、コーディングエージェント | `benitoite server …` のサブコマンド。要求をデーモンに送り、結果を示して終わる |
| MCP の中継 | コーディングエージェントのハーネス | `benitoite mcp`。標準入出力で MCP の要求を受け、デーモンに中継する（[ADR 0182](../decisions/0182-mcp-server-as-stdio-relay.md)） |
| 承認の画面 | 利用者 | `benitoite server approve`。認証を要する要求を示し、利用者の承認を受ける（後述の「認証と承認」） |
| 自前のコーディングエージェント | 利用者 | サーバモードを通してスクリプトを検査・実行するエージェントと、その TUI。設計は [OPEN-056](../open-issues.md#open-056) で決める（[ADR 0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md)） |

### 通信口

【方針】デーモンは、利用者だけが読み書きできるディレクトリ（0700）の中の Unix ソケットで要求を受ける。ネットワークのポートは開かない。

- 置き場所は、Linux では `$XDG_RUNTIME_DIR/benitoite/daemon.sock`、macOS では後述の「保管」のデータのディレクトリの下の `daemon.sock` とする。
- デーモンは、接続してきたプロセスの利用者が自分と同じかを OS から得て確かめ、違えば拒否する。自分が起動した子プロセスとその子孫からの要求も拒否する（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)の「デーモンの通信口の保護」）。
- 要求と応答は、改行で区切った JSON-RPC とする。MCP の標準入出力の形式と同じ区切り方であり、MCP の仕様はこの形式を Unix ソケットでもそのまま使えるとしている（[MCP の stdio](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio)）。
- クライアントとデーモンの版が違うときは、デーモンが誤りを返し、`server restart` を案内する。

### 常駐

【決定】デーモンは、macOS では launchd の LaunchAgent、Linux では systemd のユーザーのサービスとして動かす。`server start` は、サービスが登録されていなければ登録してから起動する（[ADR 0195](../decisions/0195-daemon-as-os-user-service.md)）。systemd がない環境（コンテナの中など）では、処理系が自分でバックグラウンドのプロセスを作る。

【方針】SSH の接続が切れた後の振る舞いは、次の事実に基づいて案内する。

- systemd のユーザーのサービスは、最後のセッションが終わってから `UserStopDelaySec`（既定 10 秒）の後に止まる。止めないには、`loginctl enable-linger` で linger を有効にする（[logind.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html)、[loginctl(1)](https://github.com/systemd/systemd/blob/main/man/loginctl.xml)）。上流の polkit の既定では、自分自身の linger を有効にするのに管理者の権限は要らない（[org.freedesktop.login1.policy](https://github.com/systemd/systemd/blob/main/src/login/org.freedesktop.login1.policy)）。配布版が既定を変えているかは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- 【決定】`server start` は、linger が無効なら、有効にする手順を示し、利用者が了承すれば `loginctl enable-linger` を実行する。失敗したときは手順を案内する（[ADR 0205](../decisions/0205-server-start-enables-linger-with-consent.md)）。
- macOS で、GUI でログインしていない SSH だけのセッションから LaunchAgent を起動できるか、切断の後も動き続けるかは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

### サブコマンド

【決定】サブコマンドの体系は [ADR 0181](../decisions/0181-server-subcommands.md) に従う。【方針】各サブコマンドのオプションは次のとおりとする。

| サブコマンド | 振る舞い | 主なオプション |
|---|---|---|
| `server start` | デーモンを起動する。初めての起動では、後述の「初めの設定」を行う | — |
| `server stop` | 実行中のジョブを止めてから（後述の「ジョブ」）、デーモンを止める | — |
| `server restart` | `stop` の後に `start` する | — |
| `server status` | デーモンの状態、実行中のジョブの数、使う OS のサンドボックスの仕組みと効く制限（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)の「効く制限の検出と表示」）、linger の状態を示す | — |
| `server settings show` | 方針のファイルの内容を示す | — |
| `server settings import <ファイル>` | 方針のファイルを検査して置き換える。認証を要する | — |
| `server settings edit` | 方針のファイルを利用者のエディタで開き、保存したら検査して置き換える。認証を要する | — |
| `server settings password` | パスワードを変える。承認の画面で古いパスワードを求める | — |
| `server register <パス>` | スクリプトを登録する（後述の「登録と承認」）。認証を要する | `--name <名前>`、`--policy <ファイル>`、`--base <ディレクトリ>`、`--signature <ファイル>`、`--autostart`、`--require-approval` |
| `server unregister <名前>` | 登録を削除する。認証を要する | — |
| `server exec <パス>` / `server exec -e '<ソース>'` | その場で渡したスクリプトを実行し、出力を逐次書く | `--profile <名前>`、`--policy <ファイル>`、`--base <ディレクトリ>`、`--env <名前>`、`-- <スクリプトの引数>` |
| `server job start <名前>` | 登録したスクリプトを実行する | `--background`、`--profile <名前>`、`--policy <ファイル>`、`--env <名前>`、`-- <スクリプトの引数>` |
| `server job status [<名前か ID>]` | ジョブの一覧、または一つのジョブの状態を示す | `--output` |
| `server job stop <名前か ID>` | ジョブを止める | — |
| `server job logs <ID>` | ジョブの出力を示す | `--follow` |
| `server audit verify` | 監査の記録のハッシュの連鎖を確かめる（後述の「監査の記録」） | — |
| `server approve` | 承認の画面を開く（後述の「認証と承認」） | — |

- `--policy` は、実行するときの方針のファイルを渡す。許可を狭める向きにだけ働く（[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)）。
- `--env <名前>` は、クライアントの環境変数のうち、名前を指定したものだけを子プロセスに渡す。方針が `Process.Environment` のその名前を許していなければ、実行の前に誤りとする。指定しない環境変数は渡さない。
- `--autostart` は、デーモンが起動したときに、そのスクリプトを背景のジョブとして実行することを表す。設計者の求めた「サーバ起動時のスクリプト自動起動」に当たる。
- 【決定】`--require-approval` は、そのスクリプトの実行に認証を要することを表す（後述の「認証と承認」）。方針のファイルのスクリプトごとの設定（後述の「方針のファイル」）でも指定できる（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。
- 各サブコマンドは、診断と結果を、スタンドアロンモードと同じ形式（`--diagnostics=text|json`。[CLI](06-01-cli.md)）で示す。

### ジョブ

【決定】`server exec` と `server job start` の一回の実行を、ジョブと呼ぶ（[ADR 0199](../decisions/0199-server-job-handling.md)）。デーモンは、ジョブごとに ID を振り、状態と出力を保存する。

| 状態 | 意味 |
|---|---|
| 待ち | 承認や検査を待っている |
| 実行中 | 子プロセスが動いている |
| 終了 | 子プロセスが終わった。終了状態（[CLI](06-01-cli.md)の「終了状態」）を持つ |
| 停止 | `job stop`、デーモンの停止、実行時間の上限で止めた |
| 拒否 | 実行の前の判定（方針、OS のサンドボックス、署名）で拒否した |

- **前景の実行**: `server exec` と、`--background` を付けない `server job start` は、ジョブの出力を逐次書く。実行はデーモンが行う。前景の実行中にクライアントが中断の要求（`Ctrl-C`）を受けたときや、クライアントとの接続が切れたときは、ジョブを止めずに切り離し、ジョブの ID を示す。ジョブを止めるには `server job stop` を使う。SSH の接続が切れても実行を続けるためである。
- **止め方**: デーモンは、子プロセスに中断の要求（`SIGTERM`）を送り、子プロセスは、リソースを解放して終わる（[ADR 0163](../decisions/0163-interrupt-releases-resources.md)、[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。一定の時間（既定 10 秒）の後も終わらなければ、`SIGKILL` を送る。
- **出力の保存**: 標準出力と標準エラー出力を、ジョブごとに分けて保存する。一つのジョブの出力の保存は、各 10 MiB を上限とし、超えたら古い部分から捨てる。終わったジョブは、新しいものから 100 件まで残す。
- **標準入力**: 子プロセスの標準入力は、空の入力につなぐ（[ADR 0165](../decisions/0165-exit-and-stdio-in-embedded-runs.md)）。
- **実行時間の上限**: `server exec` のジョブは、既定で 10 分で止める。登録したスクリプトのジョブには、既定の上限を設けない。どちらも方針のファイルで変えられる。
- **メモリ**: 子プロセスごとにメモリが分かれるので、一つのジョブのメモリの使い尽くしは、ほかのジョブとデーモンに及ばない。処理系自身はヒープの使用量に上限を設けない（[ADR 0237](../decisions/0237-no-heap-usage-limit-in-first-release.md)）。子プロセスに OS の仕組み（Linux の cgroup、`setrlimit` など）でメモリの上限を掛けるかは、[OPEN-055](../open-issues.md#open-055) で決める。

### 実行の手順

【方針】デーモンは、ジョブを次の順に進める。

1. 実行ごとの方針を決める。サーバの方針（登録したスクリプトでは、登録のときに承認した方針）、選んだプロファイル、`--policy` で渡した方針の、すべてが許す操作だけを許す（[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)、[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）。
2. スクリプトを検査する。登録したスクリプトは、保存した検査の結果を使い、処理系の版が変わっていれば検査し直す（[ADR 0191](../decisions/0191-server-data-storage.md)）。
3. `main` の型のエフェクトと、`Process.shell` の名前での参照を、方針と比べる。方針が許さないものがあれば、実行せずに拒否する（[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御（サーバモード）」）。
4. OS のサンドボックスで方針の制限を掛けられるかを確かめる。掛けられなければ、[ADR 0197](../decisions/0197-when-os-sandbox-is-unavailable.md) に従う。
5. 実行ごとの作業用のディレクトリと一時ディレクトリを作る（後述の「既定の方針が指す場所」）。
6. 子プロセスを起動する。基準のディレクトリを子プロセスの作業ディレクトリにし、`--env` で指定した環境変数、プロキシの環境変数（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)の「通信とプロキシ」）、一時ディレクトリを示す `TMPDIR` を渡す（[ADR 0220](../decisions/0220-places-referenced-by-default-policies.md)）。
7. 出力を保存しながら、前景の実行ではクライアントに逐次送る。
8. 開始と終了、拒否した操作を、監査の記録に残す。

基準のディレクトリは、`server exec` では `--base` の指定か、クライアントの作業ディレクトリとする。登録したスクリプトでは、登録のときの `--base` の指定か、登録したときのクライアントの作業ディレクトリとする。方針の相対パスは、基準のディレクトリから辿る。

### 方針のファイル

【決定】利用者は、許可する操作を一つの形の方針として書き、`server settings` が利用者単位のファイルに置く。スタンドアロンモードも、このファイルを読む（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)、[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）。

【決定】方針のファイルの書式は TOML とする（[ADR 0200](../decisions/0200-policy-file-toml-and-locations.md)）。利用者が読んで直すファイルであり、注釈を書けるからである（原則 3）。読み取りに使うクレートは、実装するときに依存の許可の一覧（[ADR 0138](../decisions/0138-crates-and-licenses-for-stdlib.md)）で確かめる。

```toml
# OS のサンドボックス
[sandbox]
linux = "landlock"                 # または "bubblewrap"
bwrap_path = "/usr/bin/bwrap"
allow_without_os_sandbox = false   # 掛けられないときに、処理系の中の判定だけで実行するか

# 秘密を置く場所。既定の一覧（後述の「既定の方針が指す場所」）に加える
[secrets]
paths = ["~/.config/example-cli"]

# 実行の種類ごとの既定の方針。次の二つの節は、書かなかったときの既定（ADR 0185）と同じ内容である
[defaults.standalone.allow]
"File.Read" = ["/"]
"File.Write" = [".", "{tmp}"]
"Process.Run" = true
shell = true
"Process.Environment" = true
"Process.Exit" = true
"Http.Listen" = true
"Http.Connect" = true
[defaults.standalone.deny]
"File.Read" = ["{secrets}"]
"File.Write" = ["{secrets}"]

[defaults.exec]
time_limit = "10m"
[defaults.exec.allow]
"File.Read" = [".", "{work}", "{tmp}"]
"File.Write" = ["{work}", "{tmp}"]
"Process.Environment" = []         # 引数とディレクトリは読めるが、環境変数は読めない
"Process.Exit" = true

# プロファイル
[profiles.codex]
select_by_client = false           # エージェントの識別で選んでよいか
[profiles.codex.allow]
"File.Read" = ["."]
"File.Write" = ["./out"]
"Process.Run" = ["git"]
shell = false
"Process.Environment" = []
"Http.Connect" = ["api.example.com"]
[profiles.codex.deny]
"File.Read" = ["./.env"]

# 登録したスクリプトごとの設定
[scripts.backup]
require_approval = true            # 実行に認証を要するか

# 登録のときの署名
[signature]
required = false
allowed_signers = "~/.ssh/allowed_signers"   # settings edit・import の時点で写しを取り込む
```

- `allow` の表の鍵は、許可の単位（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）である。シェルによる実行は `shell = true` で許す。
- 値は対象の並びである。【決定】`true` は、対象を限らずに許すことを表す（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。`Process.Exit` のように対象のない単位も `true` で許す。【決定】空の並び（`[]`）は、エフェクトを許すが、どの対象も許さないことを表す。実行の前の判定は通り、実行時にはどの対象の操作も許さない（[ADR 0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md)）。
- 表に書かない単位は許さない。許可を要しないエフェクト（`Console.Write` など）は書かない。
- 【決定】`deny` の表は、許可から除く対象を書く。除外は許可に優先する。実行ごとの方針を複数の方針の共通部分として決めるときは、どれかの方針の除外に当たる操作を許さない。`deny` に `true` を書いた単位は、エフェクトごと許さない（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。OS のサンドボックスでの強制のしかたは、[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)の「除外の強制」で定める。
- 【決定】パスには、次の記号を書ける。`{work}` と `{tmp}` は、実行ごとに場所が変わるので、記号で書く（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。

  | 記号 | 指す場所 |
  |---|---|
  | `{work}` | 実行ごとの作業用のディレクトリ |
  | `{tmp}` | 実行ごとの一時ディレクトリ |
  | `{secrets}` | 秘密を置く場所の一覧のすべて |

- パスの相対パスは、実行ごとの基準のディレクトリ（スタンドアロンモードでは作業ディレクトリ）から辿る。`~` は利用者のホームのディレクトリを表す。
- `Http.Connect` と `Http.Listen` の対象の書き方は [OPEN-052](../open-issues.md#open-052) で決める。
- 登録したスクリプトの方針は、方針のファイルではなく、登録のときに承認したものとして保存する（後述の「登録と承認」）。【決定】方針のファイルの `[scripts.<名前>]` には、登録したスクリプトごとの設定を書く。現在の項目は、実行に認証を要するか（`require_approval`）だけである（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。ほかの項目は [OPEN-055](../open-issues.md#open-055) で決める。
- ファイルが読めないときや、書式が誤っているときは、スタンドアロンモードもサーバモードも、実行せずに誤りを示す。ファイルがないときは、既定の方針（[ADR 0185](../decisions/0185-default-policies-per-run-kind.md)）を使う。

### 既定の方針が指す場所

【決定】既定の方針（[セキュリティモデル](../07-quality/07-01-security-model.md)の「既定の方針（サーバモード）」）が指す場所を、次のとおりとする（[ADR 0220](../decisions/0220-places-referenced-by-default-policies.md)）。

- **実行ごとの作業用のディレクトリ**（`{work}`）: 実行のためのディレクトリ（後述の「保管」）の下の `runs/<ジョブの ID>/work`。ジョブの記録を消すとき（前述の「ジョブ」の「出力の保存」）に、あわせて消す。
- **一時ディレクトリ**（`{tmp}`）: 実行ごとに、実行のためのディレクトリの下の `runs/<ジョブの ID>/tmp` とし、環境変数 `TMPDIR` で子プロセスに示す。

【決定】実行のためのディレクトリは、デーモンのデータのディレクトリの外に置く。デーモンのデータと方針のファイルの置き場所は、方針に含まれていても読み書きさせない（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)の「方針から導く制限」）ので、作業用のディレクトリと一時ディレクトリをその下に置くと、スクリプトはどちらも使えないからである。ある実行に許すのは、その実行の `work` と `tmp` だけであり、ほかのジョブのディレクトリは、方針が明示的に許さないかぎり許さない（[ADR 0250](../decisions/0250-run-directories-outside-daemon-data.md)）。
- **秘密を置く場所**（`{secrets}`）: 既定の一覧は次のとおりとする。利用者は、方針のファイルの `[secrets]` の `paths` で一覧に加えられる。`server settings edit`・`server settings import` による変更は認証を要する（前述の「サブコマンド」、[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。
  - `~/.ssh`、`~/.gnupg`、`~/.aws`、`~/.config/gcloud`、`~/.azure`、`~/.kube`、`~/.docker`、`~/.netrc`
  - macOS では `~/Library/Keychains`
  - ウェブブラウザのプロファイル。OS ごとの正確な場所は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
  - Benitoite 自身の設定とデータのディレクトリ（後述の「保管」）

【未決】スクリプトが作業用のディレクトリのパスを知る方法、作業用のディレクトリに書いた結果を利用者に渡す方法、スタンドアロンモードの一時ディレクトリの場所は、[OPEN-055](../open-issues.md#open-055) で決める。

### 登録と承認

【方針】`server register` は、次の順に進める。

1. 実行を始めるファイルから import で辿れるすべてのファイルを読み、検査する。検査の誤りがあれば、登録しない。
2. 方針のファイルが署名を求めるときは、署名を検証する（後述の「署名」）。
3. `main` の型のエフェクトと、シェルによる実行を要するかを求める。
4. 承認を求める。承認の画面は、スクリプトの名前、ファイルとハッシュの一覧、エフェクト、許す方針（`--policy` で渡したもの。渡さなければ、エフェクトに対象を添えない形で示し、承認の画面で対象を入れる）を示す。前に登録した版があれば、エフェクトと方針の違いを示す（[OPEN-015](../open-issues.md#open-015)）。
5. 利用者が承認したら、すべてのファイルの写しと、検査の結果と、承認した方針を保存し（[ADR 0191](../decisions/0191-server-data-storage.md)）、監査の記録に残す。

再登録でエフェクトが増えたときは、改めて承認を求める（[ADR 0185](../decisions/0185-default-policies-per-run-kind.md)）。

【決定】スクリプトの実行に認証を要するかは、`server register --require-approval` か、方針のファイルの `[scripts.<名前>]` の `require_approval` で指定する（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。

### 認証と承認

【決定】設定の変更、スクリプトの登録と削除、認証を要すると設定したスクリプトの実行は、認証を要する。認証は、コマンドの引数やコマンドを実行した端末では行わず、利用者が別の端末で開いた承認の画面で行う（[ADR 0188](../decisions/0188-authentication-by-user-presence.md)）。

【方針】

- デーモンは、認証を要する要求を待ちの列に入れる。`server approve` は、待っている要求の内容を示し、利用者がパスワードを入れて承認するか、拒否する。
- 【決定】待ちの要求は、5 分で拒否に変わる（[ADR 0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md)）。
- パスワードは、Argon2id で派生したハッシュだけを保存する。パラメータは、メモリ 19 MiB、繰り返し 2、並列度 1 とする。OWASP の推奨と、RustCrypto の `argon2` クレートの既定の値と同じである（[OWASP Password Storage Cheat Sheet](https://github.com/OWASP/CheatSheetSeries/blob/master/cheatsheets/Password_Storage_Cheat_Sheet.md)、[argon2](https://github.com/RustCrypto/password-hashes/tree/master/argon2)）。
- 生体認証と FIDO2 のキーは後の版で加える。FIDO2 の Rust のクレートは、どれも C のライブラリ（hidapi、libfido2）かシステムのライブラリに依存する（[ctap-hid-fido2](https://github.com/gebogebogebo/ctap-hid-fido2)、[authenticator-rs](https://github.com/mozilla/authenticator-rs)）。C コンパイラを避ける方針（[ADR 0143](../decisions/0143-http-and-tls-crates.md)）との関係を、加えるときに決める。

#### 初めの設定

【決定】初めての `server start` は、パスワードを決めるよう求める（[ADR 0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md)）。パスワードは、`server start` を実行した端末で入れる。この時点ではまだ承認の画面がないからである。コーディングエージェントに初めての `server start` を実行させると、エージェントがパスワードを知る。このため、初めての設定は利用者が自分で行うよう、文書で示す。

### 監査の記録

【決定】デーモンは、認証、スクリプトの登録と削除、設定の変更、実行の開始と終了、拒否した操作を、監査の記録に残す。記録は追記だけとし、各記録に直前の記録のハッシュを含める（[ADR 0189](../decisions/0189-tamper-evident-audit-log.md)）。連鎖で検出できるのは、それ以降のハッシュを計算し直していない書き換えと削除、および偶然の破損に限る（[ADR 0221](../decisions/0221-audit-hash-chain-scope-corrected.md)）。

【決定】（[ADR 0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md)）

- 記録は、1 行に一つの出来事を書く JSON Lines とする。各行は、通し番号、時刻、出来事の種類、内容、直前の行の SHA-256 のハッシュを持つ。
- 記録のファイルは 10 MiB ごとに切り替え、新しいファイルの最初の行に、前のファイルの最後の行のハッシュを書く。古いファイルを消すかは、利用者に任せる。

【決定】（[ADR 0217](../decisions/0217-audit-log-undetectable-cases-and-verification-start.md)）

- `server audit verify` は、残っている最も古いファイルの最初の行から連鎖を辿り、合わない行を示す。その最初の行が持つ、前のファイル（消したファイル）を指すハッシュは、確かめられないものとして扱う。
- `server audit verify` は、どこから確かめられたか（残っている最も古いファイルと、その最初の行の通し番号と時刻）を示す。
- 計算し直した書き換え、連鎖の末尾の切り詰め、記録のすべての削除、古いファイルの削除は、この仕組みでは検出できない（[セキュリティモデル](../07-quality/07-01-security-model.md)の「認証・監査・署名・保管（サーバモード）」）。

### 署名

【決定】登録のときの署名は、既定では求めない。署名は SSH の署名とし、スクリプトとは別のファイルに置き、読み込むすべてのファイルのハッシュの一覧に署名する（[ADR 0190](../decisions/0190-ssh-signatures-for-scripts.md)）。

【決定】（[ADR 0202](../decisions/0202-signature-details.md)）

- 署名の一覧は、根のディレクトリからの相対パスと、内容の SHA-256 のハッシュを、パスの順に 1 行ずつ並べたテキストとする。
- 署名の名前空間（SSH の署名で用途を区別する文字列）は `benitoite-script` とする。SSH の署名の形式は、空でない名前空間を必ず要求する（[PROTOCOL.sshsig](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)）。
- 署名のファイルは、実行を始めるファイルと同じディレクトリに、実行を始めるファイルの名前に `.sig` を付けた名前で置く（`main.bnt.sig`）。
- `benitoite sign <パス> --key <鍵のファイル>` は、一覧を作って署名する。`benitoite verify <パス> --allowed-signers <ファイル>` は、一覧を作り直して署名を検証する。信頼する鍵の一覧は、OpenSSH の allowed_signers の形式とする（[ssh-keygen(1)](https://github.com/openssh/openssh-portable/blob/master/ssh-keygen.1)）。
- 署名と検証は、RustCrypto の `ssh-key` クレートで行う。このクレートは pure Rust で、SSH の署名の作成と検証を持つ（[ssh-key](https://github.com/RustCrypto/SSH/tree/master/ssh-key)）。ssh-agent に置いた鍵で署名する方法は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- `ssh-keygen -Y sign -n benitoite-script` で一覧に署名しても、同じ署名になる。

【決定】デーモンが使う信頼する鍵の一覧は、利用者が認証を要する操作（`server settings edit`・`server settings import`）で方針のファイルの `allowed_signers` に指定したファイルの写しとする。デーモンは、その時点でファイルの内容をデータのディレクトリに写し、以後は写しだけを使う。元のファイルを後で変えたときは、`server settings edit` か `import` で取り込み直す。デーモンを使わない `benitoite verify` は、`--allowed-signers` で渡したファイルを使う（[ADR 0218](../decisions/0218-allowed-signers-imported-copy.md)）。

### 保管

【決定】登録したスクリプトは、すべてのファイルの写しを内容のハッシュで管理して保存する。処理系が保存する秘密はパスワードのハッシュだけであり、初めの版では OS の鍵保管庫を使わない（[ADR 0191](../decisions/0191-server-data-storage.md)）。

【決定】置き場所は次のとおりとする（[ADR 0200](../decisions/0200-policy-file-toml-and-locations.md)）。ディレクトリはどれも、利用者だけが読み書きできる権限（0700）にする。

| 中身 | Linux | macOS |
|---|---|---|
| 方針のファイル（`policy.toml`） | `$XDG_CONFIG_HOME/benitoite/`（既定 `~/.config/benitoite/`） | `~/Library/Application Support/Benitoite/` |
| 登録したスクリプト、検査の結果、ジョブの出力、監査の記録、パスワードのハッシュ | `$XDG_DATA_HOME/benitoite/`（既定 `~/.local/share/benitoite/`） | 同じ |
| 通信口 | `$XDG_RUNTIME_DIR/benitoite/` | `~/Library/Application Support/Benitoite/` |
| 実行のためのディレクトリ（実行ごとの作業用のディレクトリと一時ディレクトリ。[ADR 0250](../decisions/0250-run-directories-outside-daemon-data.md)） | `$XDG_STATE_HOME/benitoite/`（既定 `~/.local/state/benitoite/`） | `~/Library/Application Support/Benitoite/` とは別のディレクトリ。名前は実装プランで定める |

### MCP の道具

【決定】MCP サーバは、デーモンに要求を中継する `benitoite mcp` とする（[ADR 0182](../decisions/0182-mcp-server-as-stdio-relay.md)）。

【決定】MCP の道具は、サブコマンドに次のように対応させる（[ADR 0203](../decisions/0203-mcp-tools-and-agent-configuration.md)、[ADR 0210](../decisions/0210-mcp-in-server-chapter-and-explain-tool.md)）。認証を要するサブコマンド（`register`・`unregister`・`settings`）は、道具にしない（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。

| 道具 | 対応するサブコマンド |
|---|---|
| `check` | スクリプトを検査し、診断を JSON の形式で返す（`server exec` の手順 2 まで） |
| `exec` | `server exec`。ソースかパスを受け取る |
| `job_start` | `server job start` |
| `job_status` | `server job status` |
| `job_stop` | `server job stop` |
| `job_logs` | `server job logs` |
| `list_scripts` | 登録したスクリプトの名前、エフェクト、承認した方針の一覧 |
| `explain` | 診断のコードを受け取り、診断の表にある説明（意味とよくある直し方）を返す。認証を要しない |

- 各道具は、プロファイルの名前を受け取る（[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）。
- 【決定】道具で求めた実行が認証を要するとき（前述の「登録と承認」の `require_approval`）は、道具は、待ちの状態と要求の ID を返す。要求の ID は、ジョブの ID とする。エージェントは、`job_status` で結果を確かめる。利用者は、承認の画面で承認する。承認の待ちが拒否に変わったときは、`job_status` が拒否の状態を返す（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。
- MCP の仕様は、エージェントが名乗る身元（`clientInfo`）を自己申告とし、セキュリティの判断に使うべきでないとしている（[MCP の仕様](https://modelcontextprotocol.io/specification/2026-07-28/basic)）。`benitoite mcp` も、身元をプロファイルを選ぶ手がかりにしか使わない。
- 実装には、公式の Rust の SDK（`rmcp`）を使うことを検討する。`rmcp` は tokio を使う（[rust-sdk](https://github.com/modelcontextprotocol/rust-sdk)）。`benitoite mcp` は VM を動かさないので、処理系の I/O の仕組み（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）とは別に tokio を使ってよい。

### コーディングエージェントの設定

【決定】エージェントにスタンドアロンモードを使わせない制限は、エージェントの側の許可の設定で行う（[ADR 0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md)）。

【決定】エージェントには、MCP の道具を使わせ（[ADR 0203](../decisions/0203-mcp-tools-and-agent-configuration.md)）、シェルからの `benitoite` の実行はすべて拒否させる形を勧める。シェルから `server exec` を使わせるには、エージェントのサンドボックスで、デーモンの通信口への Unix ソケットの接続を許す必要がある。これは、エージェントによっては、すべての Unix ソケットを許すことになる。

| エージェント | シェルからの実行を拒否する設定 | Unix ソケットの接続の扱い |
|---|---|---|
| Claude Code | `permissions.deny` に `Bash(benitoite *)` を書く（[permissions](https://code.claude.com/docs/en/permissions)） | サンドボックスは既定で Unix ソケットを塞ぐ。macOS では `sandbox.network.allowUnixSockets` でパスごとに許せるが、Linux と WSL2 では `allowAllUnixSockets` ですべてを許すしかない（[settings](https://code.claude.com/docs/en/settings-reference)） |
| Codex CLI | 規則のファイルに `prefix_rule(pattern=["benitoite"], decision="forbidden")` を書く（[rules](https://developers.openai.com/codex/rules)。規則の機能は実験的と明記されている） | `unix_sockets` の許可の一覧で許す。Linux の既定（ネットワークなし）では、seccomp が接続そのものを拒否する（Codex のソース） |
| opencode | `permission.bash` に `"benitoite *": "deny"` を書く（[permissions](https://opencode.ai/docs/permissions/)） | サンドボックスの記述はない |

- MCP サーバとして起動した `benitoite mcp` が、各エージェントのシェルのサンドボックスの外で動くかは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- エージェントの中で動いていると推定できるとき（エージェントが設定する環境変数など）、スタンドアロンモードは警告を出す。推定に使う環境変数の一覧は、実装するときに各エージェントの文書で確かめる。

### スタンドアロンモード

【決定】サーバモードを加えた後のスタンドアロンモードは、方針のファイルを起動のたびに読み、その方針のもとで実行する（[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）。OS のサンドボックスを掛けられないときは、警告を出して処理系の中の判定だけで実行する（[ADR 0197](../decisions/0197-when-os-sandbox-is-unavailable.md)）。

【決定】スタンドアロンモードも、サーバモードと同じく（[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）、スクリプトを子プロセスで実行する。起動した `benitoite` のプロセスが親となり、OS のサンドボックスを掛けた子プロセスを起動する。親は、子プロセスの標準入出力をそのままつなぎ、方針が `Http.Connect` をホスト名で限るときは、デーモンと同じプロキシを自分の中で動かす。スクリプトの終了状態は、子プロセスの終了状態をそのまま使う。

## 未決事項

- [OPEN-055](../open-issues.md#open-055): サーバモードの設計（本章の【方針】の細部の見直し、許可したコマンドが必要とする読み取りの扱い、子プロセスのメモリの上限）
- [OPEN-056](../open-issues.md#open-056): 自前のコーディングエージェントの設計
- [OPEN-057](../open-issues.md#open-057): OS のサンドボックスとデーモンの常駐に関する事実の確認
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の対象の書き方）
- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法

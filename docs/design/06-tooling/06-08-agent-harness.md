# エージェントハーネス

- 状態: 草稿
- 関連ADR: [0127](../decisions/0127-directory-run-and-root.md), [0187](../decisions/0187-standalone-reads-user-policy-file.md), [0188](../decisions/0188-authentication-by-user-presence.md), [0192](../decisions/0192-named-profiles-for-agents.md), [0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md), [0203](../decisions/0203-mcp-tools-and-agent-configuration.md), [0209](../decisions/0209-reserved-subcommand-names.md), [0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md), [0231](../decisions/0231-skill-shows-main-effects-before-running.md), [0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md), [0336](../decisions/0336-command-substitute-library-policy.md), [0340](../decisions/0340-llm-providers-for-own-agent-harness.md), [0342](../decisions/0342-agent-harness-after-server-mode.md), [0343](../decisions/0343-agent-harness-user-config-file.md), [0344](../decisions/0344-agent-harness-operation-scope-and-tools.md), [0345](../decisions/0345-agent-harness-confirmation-and-server-approval.md), [0346](../decisions/0346-agent-harness-connects-to-daemon-directly.md), [0347](../decisions/0347-agent-harness-web-fetch.md), [0348](../decisions/0348-agent-harness-rewind-and-git.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-015](../open-issues.md#open-015), [OPEN-048](../open-issues.md#open-048), [OPEN-056](../open-issues.md#open-056), [OPEN-081](../open-issues.md#open-081), [OPEN-082](../open-issues.md#open-082), [OPEN-088](../open-issues.md#open-088), [OPEN-089](../open-issues.md#open-089), [OPEN-094](../open-issues.md#open-094), [OPEN-095](../open-issues.md#open-095), [OPEN-096](../open-issues.md#open-096), [OPEN-097](../open-issues.md#open-097), [OPEN-101](../open-issues.md#open-101), [OPEN-102](../open-issues.md#open-102), [OPEN-103](../open-issues.md#open-103)
- 移行元: なし（[自前のエージェントハーネスの検討メモ](../sources/post-first-release/post-first-release-agent-harness.md)、[LLM の提供者の検討メモ](../sources/post-first-release/post-first-release-llm-providers.md)。2026-10-04）

## 目的と範囲

本章は、エージェントハーネス（agent harness）を定める。エージェントハーネスは、Benitoite の処理系が持つ自前のコーディングエージェントであり、利用者の依頼から LLM にスクリプトを書かせ、検査と修正を繰り返し、実行して結果を示す。ADR 0194 などの「自前のコーディングエージェント」と同じものを指す。本設計書で単に「ハーネス」と書くときは、Claude Code、Codex CLI、OpenCode などの、LLM を動かして道具を実行させる外部のプログラムを指し、エージェントハーネスと区別する（[用語集](../00-overview/00-04-glossary.md)）。

対象は、作る時期、使う LLM の提供者、設定ファイル、エージェントに許す操作の範囲と道具、実行の前の確認とサーバモードの承認の関係、非対話での利用、サーバモードとの接続、ウェブの取得、送る内容、巻き戻しと git の操作、テストの用途である。本章の内容は、すべて初回リリース版の後に加える機能であり、初回リリース版の処理系は本章のどの機能も持たない。

外部のハーネスから処理系を使う場合は、使うモデルと認証をハーネスの側で設定するので、本章の対象外とする。外部のハーネスの設定は[サーバモード](06-07-server.md)の「コーディングエージェントの設定」で、同梱の Agent Skill は [Agent Skills 対応](06-06-agent-skills.md)で扱う。

## 前提

- エージェントハーネスは、サーバモード（[サーバモード](06-07-server.md)）を通してスクリプトを検査・実行する（[ADR 0194](../decisions/0194-tui-and-own-coding-agent-with-server-mode.md) の決定 2）。サーバモードは、名前を付けたプロファイルの範囲でだけ実行し（[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）、OS のサンドボックスと実行時の権限制御を掛ける。
- サーバモードの認証は、利用者が別の端末で開いた承認の画面で行う（[ADR 0188](../decisions/0188-authentication-by-user-presence.md)）。
- 同梱の Agent Skill は、実行の前に `main` のエフェクトを利用者に示させる手順を持つが、手順を守るかはエージェントに任せている（[ADR 0231](../decisions/0231-skill-shows-main-effects-before-running.md)）。
- 処理系は、プロジェクトの設定ファイルを読まず、作業ディレクトリや親のディレクトリを辿って設定ファイルを探さない（[CLI](06-01-cli.md)の「ディレクトリの指定（初回リリース版）」）。
- エージェントハーネスは言語の中核でも処理系の主要部でもないので、LLM の API のクライアントと TUI の部品には既存の OSS を使う（ADR 0194 の決定 4）。
- サブコマンドの名前 `agent` を、後で加える候補として予約している（[ADR 0209](../decisions/0209-reserved-subcommand-names.md)）。

## 仕様

### 目的

エージェントハーネスの目的は二つある。

1. 利用者の入口。利用者が作業と許可する操作を決めるだけで、言語を学ばずに作業を自動化できるようにする（[目的と設計原則](../00-overview/00-01-goals.md)の「目指す方向」）。外部のハーネスと同梱の Agent Skill の組み合わせでも同じことはできる。エージェントハーネスを作る価値は、エージェントの操作の範囲を型とエフェクトで限れることと、実行の前の確認を処理系が強制できることにある。
2. LLM を使ったテスト。構文の測定（[OPEN-012](../open-issues.md#open-012)）と Skill の評価（[Agent Skills 対応](06-06-agent-skills.md)の「Skill の評価」）を、処理系と一体で制御できるエージェントで行う（ADR 0194 の決定 3）。

### 作る時期

【決定】TUI とエージェントハーネスは、サーバモードより後に実装し、正式リリース版の前までに実装する。エージェントが使う口のうちサーバモードとあわせて実装するのは、MCP の中継（`benitoite mcp`）だけとし、承認の画面は TUI の部品でサーバモードとあわせて作る（後述の「承認の画面と TUI」。[ADR 0342](../decisions/0342-agent-harness-after-server-mode.md)）。

【決定】エージェントハーネスは、サーバモードがあることを前提にする。サーバモードのない版でエージェントハーネスを動かす経路は作らない（ADR 0342 の決定 3）。

### 使う LLM の提供者

【決定】エージェントハーネスは、次の四つの提供者を採る（[ADR 0340](../decisions/0340-llm-providers-for-own-agent-harness.md)）。

| 提供者 | 作り |
|---|---|
| A. OpenAI 互換の API | Chat Completions と Responses の両方を実装し、設定でどちらを使うかを選ぶ。ベースの URL と API キーを設定で与え、OpenAI 互換の口を持つサービスを同じ実装で呼ぶ |
| B. Sign in with ChatGPT | A の Responses の実装を使い回し、B に固有の部分は認証（OAuth とトークンの更新）だけとする |
| D. Anthropic の Messages API | OpenAI 互換の口を通さず、Messages API を直接実装する |
| E. Google の Gemini API | Gemini API の固有の形で呼ぶ専用の実装を作る。利用者が A の設定で Gemini API の OpenAI 互換の口を呼ぶことは妨げない |

- 【決定】手元の推論サーバ（Ollama など）と中継のサービス（OpenRouter など）は A の実装で扱い、設定の例として文書に載せる。自己ホスト（Rust のライブラリから処理系の中で推論する）とクラウドの基盤（Amazon Bedrock、Vertex AI、Azure OpenAI）は、実装の優先度を低くする。Apple の Foundation Models は今回は採らない。Claude は D を API のキーで使い、Claude の購読のアカウントで処理系が自らサインインする形は候補にしない（ADR 0340 の決定 5）。
- 【未決】提供者を差し替える層、実装の順、使うクレートは [OPEN-095](../open-issues.md#open-095)、各社の規約や互換の範囲などの事実の確認は [OPEN-096](../open-issues.md#open-096)、Claude Code の CLI を経由して Claude の購読で使う提供者の採否は [OPEN-097](../open-issues.md#open-097) で決める。

### 設定ファイル

【決定】使う提供者、モデル、ベースの URL は、TOML の設定ファイルに書く。モデル以外のエージェントハーネスの設定も、このファイルに書く。提供者は複数書け、そのうち一つを既定の提供者とし、起動のときのオプションで名前を指定して別の提供者に切り替える。役割ごとにモデルを分けることは、今回は対象外とする（[ADR 0343](../decisions/0343-agent-harness-user-config-file.md)）。

【決定】利用者単位の設定ファイルは、利用者の設定であり、プロジェクトに属さない。サーバが書く利用者単位の方針のファイル（[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）と同じく、決まった場所に置き、作業ディレクトリやスクリプトの場所から探さない（ADR 0343 の決定 4）。

形の例を次に示す。欄の名前とコマンドラインは仮である。

```toml
[harness]
default_provider = "openai"

[providers.openai]
kind = "openai-responses"
model = "gpt-..."

[providers.local]
kind = "openai-chat"
base_url = "http://localhost:11434/v1"
model = "gemma..."
```

```text
benitoite agent "..."                       # 既定の提供者（openai）を使う
benitoite agent --provider local "..."      # local に切り替える
```

【未決】ファイルの名前と置き場所、欄の名前、サブコマンドとオプションの名前、プロジェクトごとの設定ファイルを設けるかとその書ける欄は [OPEN-102](../open-issues.md#open-102) で決める。プロジェクトごとの設定ファイルを設けるなら、[CLI](06-01-cli.md)の「処理系は、プロジェクトの設定ファイルを読まない」の、エージェントハーネスに限った例外として扱う。`run`・`check` などが読むプロジェクトの設定ファイルを設けるかは、これとは別に [OPEN-048](../open-issues.md#open-048) で決める。API キーの書き方と保管は [OPEN-101](../open-issues.md#open-101) で決める。

### エージェントに許す操作の範囲

【決定】エージェントに許す操作は、Benitoite のスクリプトの作成・検査・実行と、エージェントハーネスのコードが行うプロジェクトのディレクトリ（根のディレクトリ）の下のファイルの一覧と読み取りとする。エージェントが書けるのは、プロジェクトのディレクトリの下の `.bnt` のファイルに限る（[ADR 0344](../decisions/0344-agent-harness-operation-scope-and-tools.md)）。外への操作は、すべて検査して利用者が確認したスクリプトを通る。ウェブの取得はこの例外であり、後述の「ウェブの取得」の制限を掛ける。

【決定】あわせて、次の二つを許す（ADR 0344 の決定 2・3）。

- プロジェクトの作成。ディレクトリを作り、雛形の `main.bnt` を置く。作ったディレクトリが、以後のプロジェクトになる。利用者が書き込めるところ（ホームディレクトリの下など）ならどこにでも作れる。格納先は利用者が依頼の文で指示する前提とし、作る前に絶対パスを示して利用者の確認を受ける。すでにあるディレクトリには作らない。
- 一時的なスクリプトの作成と実行。プロジェクトのスクリプトとは別の、Benitoite で書ける下調べや計算のスクリプトである。置き場所はプロジェクトの外の、セッションごとの一時ディレクトリとし、セッションが終わったら消す。役に立ったものは `write_script` でプロジェクトへ写せる。一時的なスクリプトも、検査と実行の前の確認を通る。

標準ライブラリにない操作（git、パッケージマネージャなど）を要する作業は、スクリプトの中の `Process.Run` か、コマンドを包むライブラリ（[ADR 0336](../decisions/0336-command-substitute-library-policy.md)）で行う。どちらも `main` のエフェクトに現れ、プロファイルと方針で拒否できる。外部のライブラリのエフェクトを権限の表示にどう出すかは [OPEN-081](../open-issues.md#open-081) で決める。

### 道具

【決定】エージェントに与える道具は次のとおりとする（ADR 0344 の決定 4）。git の道具は後述の「git の操作」で定める。

| 道具 | 内容 | 利用者の確認 |
|---|---|---|
| `create_project` | 新しいディレクトリを作り、雛形の `main.bnt` を置く | 要る（作る場所を示す） |
| `write_script` | プロジェクトのディレクトリの下に `.bnt` のファイルを書く・直す | 要らない（差分は画面に示す） |
| `run_scratch` | 一時的なスクリプトを書いて、検査し、実行する | 実行の前の確認に従う |
| `check` | スクリプトを検査し、診断を JSON で返す | 要らない |
| `explain` | 診断のコードの説明を返す（MCP の `explain` と同じ表） | 要らない |
| `read_reference` | 同梱の Skill の参照の文書（文法、標準ライブラリのリファレンス、イディオム集など。[ADR 0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md)）を読む | 要らない |
| `list_files`・`read_file` | プロジェクトのディレクトリの下のファイルの一覧と中身を読む。大きさに上限を設ける | 要らない（除外の規則に従う） |
| `run` | サーバモードのジョブとしてスクリプトを実行し、終了状態と出力を返す | 要る（実行の前の確認） |
| `web_fetch` | URL の内容を取得し、本文を文字にして返す | 一覧にないドメインは要る |
| `test` | `benitoite test` に当たる。テストの関数のエフェクトを確認してから実行する | 要る |
| `ask_user` | 利用者に質問する | — |

【決定】シェル、プロジェクトの外のファイルの読み書き、外部の MCP サーバへの接続は、道具として持たせない（ADR 0344 の決定 5）。外部の MCP サーバの道具は処理系の型とエフェクトの検査を通らないので、外への操作がすべて検査済みのスクリプトを通るという性質が崩れる。

【未決】`read_file` が既定で読まないファイルの一覧、読み取りの大きさの上限、`create_project` の雛形の中身、検査と修正を繰り返す回数の上限を含む作業の流れ、文脈の管理は [OPEN-103](../open-issues.md#open-103) で決める。

### 実行の前の確認とサーバモードの承認

【決定】エージェントハーネスは、同梱の Agent Skill の実行の前の確認（[ADR 0231](../decisions/0231-skill-shows-main-effects-before-running.md)）と同じ内容を、自らの画面で利用者から受ける。スクリプトを初めて実行するときと、`main` のエフェクトが前に確認したときより増えたときに、エフェクトを利用者の言葉で示して承認を受ける。LLM に与える道具には承認の操作を含めないので、エージェントは確認を飛ばせない（[ADR 0345](../decisions/0345-agent-harness-confirmation-and-server-approval.md) の決定 1）。

【決定】エージェントハーネスの確認と、サーバモードの承認の画面での認証は、別のものとして扱う（ADR 0345 の決定 2）。

- エージェントハーネスの確認は「このエフェクトで実行してよいか」の同意であり、エージェントハーネスの画面で受ける。
- サーバモードは、確認を通った実行も、エージェント用のプロファイル（[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）の範囲でだけ行い、範囲を超える操作は拒否する。
- `require_approval` を付けたスクリプト（[ADR 0219](../decisions/0219-mcp-job-start-returns-pending-for-approval.md)）は、ほかのクライアントと同じく、承認の画面での認証も要る。

【決定】一時的なスクリプト（`run_scratch`）には、確認なしで実行できるエフェクトの範囲を設ける。範囲の既定は、エフェクトなし（純粋な計算）と `Console.Write` だけとする。利用者の設定で範囲を広げられる（`File.Read`、`Clock.Time` など）が、プロジェクトの設定では広げられない。範囲を超えるスクリプトは、プロジェクトのスクリプトと同じく確認を受ける。`File.Read` を範囲に加えるときは、エージェント用のプロファイルで読める場所を限ることを、利用者向けの文書で勧める（ADR 0345 の決定 3）。

【未決】確認の画面に示す内容の細部（`Process.Run` を含むときに起動するコマンドの名前を示すかなど）と、既存のスクリプトを直すときに `main` のエフェクトと公開の関数の型の変化を示す形（[OPEN-015](../open-issues.md#open-015)）は [OPEN-103](../open-issues.md#open-103) で決める。

### 承認の画面と TUI

【決定】サーバモードの承認の画面（`benitoite server approve`）は、TUI の部品（画面の枠組み）で作り、サーバモードとあわせて実装する。後で作る TUI と、見た目と操作を揃えるためである（[ADR 0342](../decisions/0342-agent-harness-after-server-mode.md) の決定 2）。

エージェントハーネスの対話の画面（TUI）は、依頼、エージェントの進み具合、差分、実行の前の確認、結果を示す。承認の画面は、エージェントハーネスの確認とは別の画面のままである。

秘密の情報（パスワード、アクセス用のトークンなど）は、エージェントハーネスの入力欄では受け取らない形が見込まれる。入力欄に入れた文は LLM へ送られるからである。エージェントハーネスが実行するスクリプトはサーバモードを通して動くので、秘密はサーバモードの承認の画面で受け取る経路の候補（[OPEN-089](../open-issues.md#open-089) の C）に当たる。

【未決】TUI の画面の構成と承認の画面の関係は [OPEN-056](../open-issues.md#open-056)、秘密を受け取る経路と画面は [OPEN-089](../open-issues.md#open-089)、入力の履歴・キャンセル・`/` で始まるコマンドの一覧は [OPEN-103](../open-issues.md#open-103) で決める。

### 非対話での利用

エージェントハーネスは、一回の依頼を処理して終わる非対話の形でも使える。テストの用途と、ほかのスクリプトからの利用に使う。

【決定】非対話では、実行の前の確認を対話で受けられないので、次のように扱う（ADR 0345 の決定 4）。

- 許可するエフェクトを、起動のときのオプション（`--allow`）で指定する。エフェクトがその範囲に収まるスクリプトだけを実行し、超えるスクリプトは実行せずに、理由を示して終わる。
- `--allow` を省いたときは、一時的なスクリプトの確認なしの範囲だけを許す。指定を忘れても、狭い範囲に収まる。
- ウェブの取得は、利用者の設定の一覧にあるドメインだけを行う。プロジェクトの作成は、起動のときのオプション（`--dir`）で指定した場所にだけ行う。

オプションの正確な名前と書き方は [OPEN-102](../open-issues.md#open-102) で決める。

### サーバモードとの接続

【決定】エージェントハーネスは、デーモンの通信口に直接つなぎ、`benitoite server …` のクライアントと同じ部品で要求を送る。LLM に見せる道具の形（名前、引数、返す JSON）は、[サーバモード](06-07-server.md)の「MCP の道具」と、同じ働きの道具どうしで揃える（[ADR 0346](../decisions/0346-agent-harness-connects-to-daemon-directly.md)）。

エージェントハーネスにしかない道具（`create_project`、`list_files`・`read_file`、`web_fetch`、git の道具など）は、エージェントハーネスのコードが実行し、デーモンには送らない。Claude Code の CLI を経由する提供者（[OPEN-097](../open-issues.md#open-097)）を採るときは、道具を MCP で CLI に見せる必要があり、MCP の道具と揃えた形を流用できる。

### ウェブの取得

【決定】エージェントハーネスに、URL の内容を取得して本文を文字にして返す道具（`web_fetch`）を加える（[ADR 0347](../decisions/0347-agent-harness-web-fetch.md)）。

- 利用者の設定の一覧にあるドメインは、確認なしで取得する。それ以外のドメインは、初めて取得するときに利用者の確認を受け、確認したドメインはセッションの間は確認を省く。
- 確認なしで取得するドメインの一覧は、プロジェクトの設定では広げられない。
- 取得の方法は GET だけとし、クッキーと認証の情報を送らず、大きさに上限を設け、HTML は本文の文字にして返す。

ウェブの取得は、外への操作がすべて確認済みのスクリプトを通るという性質の例外である。LLM は URL を自由に組み立てられるので、プロジェクトで読んだ内容を URL に載せて外のサーバへ送れる。一覧とドメインごとの確認は、送り先を利用者が認めたドメインに限るための制限である。取得したページに埋め込まれた指示は防げない（[セキュリティモデル](../07-quality/07-01-security-model.md)の「エージェントハーネスの保証の範囲（初回リリース版の後）」）。

【未決】一覧の既定、確認したドメインを利用者の設定に書いて以後も確認を省く操作、大きさの上限の値、URL を知らずに探すための検索の手段（【要検証】）は [OPEN-103](../open-issues.md#open-103) で決める。

### 送る内容と秘密

`read_file` で読んだ内容、スクリプトの出力、診断は、LLM の提供者へ送られる。

【未決】次の点は未決である。

- 使う提供者とモデル、外部へ送ること、送る内容、購読の使用量が減ることを利用者にどう示すか。API キーと OAuth のリフレッシュトークンの保管（設定ファイルにはキーの参照だけを書く、OS のキーストアを第一にする、スクリプトと外部コマンドの環境からキーを消す、などの見立て）（[OPEN-101](../open-issues.md#open-101)）。
- `read_file` が既定で読まない、秘密を含みやすいファイル（`.env`、秘密鍵、`.git/` の中など）の一覧と、スクリプトの出力を LLM に返す量の上限（[OPEN-103](../open-issues.md#open-103)）。
- 秘密を出力するスクリプトの出力を、利用者の画面にだけ出して LLM には伏せる仕組み（[OPEN-103](../open-issues.md#open-103)、秘密の型は [OPEN-088](../open-issues.md#open-088)）。

ファイルや実行結果に埋め込まれた指示（プロンプトインジェクション）で、エージェントが意図しないスクリプトを書くことは防げない。前述の確認とサーバモードのプロファイルが防ぐのは、そのスクリプトが確認を受けていない操作や、プロファイルが許さない操作を行うことである。

### 巻き戻しと git の操作

【決定】巻き戻しは、プロジェクトのディレクトリの状態をまるごと記録して、その状態に戻す形とする。スクリプトがプロジェクトの中に書いたファイルも戻せる。戻せないもの（スクリプトがプロジェクトの外に書いたファイル、外部への操作、ウェブの取得）は、巻き戻しの画面で、戻す区間に含まれる実行とあわせて示す（[ADR 0348](../decisions/0348-agent-harness-rewind-and-git.md) の決定 1・2）。

【決定】ブランチの作成（新しいプロジェクト用）、コミット、コミットの時点に戻すことを、エージェントハーネスの道具にする（ADR 0348 の決定 3〜5）。

- 道具はエージェントハーネスのコードが実行し、対象はプロジェクトのリポジトリに限る。ネットワークを使う操作（`push`・`fetch` など）は道具に含めず、必要なら Benitoite のスクリプトで行う。
- git の操作は、git の CLI ではなく git のライブラリで行い、hooks・`core.fsmonitor`・diff driver などの別のプログラムを起動しない。他人のリポジトリで仕込まれたプログラムが確認なしに動くことを避けるためである。使うのは、hooks などを実行しないことを確かめたライブラリに限る。
- コミットの時点に戻す道具は、作業ツリーの中身だけを戻し、履歴は消さない。戻す直前の状態を巻き戻しの記録に残し、戻したこと自体も取り消せるようにする。

【決定】git の道具の一覧は次の案とし、実装の前に改めて見直す（ADR 0348 の決定 6）。

| 道具 | 内容 | 利用者の確認 |
|---|---|---|
| `git_init` | `create_project` で作ったプロジェクトを git のリポジトリにし、最初のコミットを作る | `create_project` の確認に含める |
| `git_status`・`git_log`・`git_diff` | 状態、履歴、差分を読む | 要らない |
| `git_commit` | 変更をコミットする。メッセージは LLM が書き、画面に示す。作者は利用者の git の設定（`user.name`・`user.email`）を使う | 要らない（後で戻せるので） |
| `git_restore` | 作業ツリーを、指定したコミットの時点の中身に戻す | 要る |

巻き戻しは、エージェントハーネスが自動で記録したものを使う。`git_restore` は、利用者が意味のある区切りとして作ったコミットに戻す。

【未決】記録する時点、記録の置き場所（影の git リポジトリか写しか）、大きさの上限と残す期間、戻すものの選び方、`create_project` を戻すときの扱い、確認の記録を戻すか、ブランチの操作、戻した状態を新しいコミットにするか、利用者が自分の hooks を動かしたい要望、使う git のライブラリ（【要検証】。依存の基準は [OPEN-094](../open-issues.md#open-094)）は [OPEN-103](../open-issues.md#open-103) で決める。Benitoite のスクリプトから使う git のライブラリは、別に [OPEN-082](../open-issues.md#open-082) で扱う。

### テストの用途

【未決】LLM を使ったテストで要る機能（課題の与え方、記録する内容、同じ条件での繰り返し、`read_reference` が返す文書の差し替え）は [OPEN-056](../open-issues.md#open-056) で決める。構文の案ごとの測定は [OPEN-012](../open-issues.md#open-012) で扱う。

## 未決事項

- [OPEN-056](../open-issues.md#open-056): 自前のコーディングエージェントの設計（TUI の画面の構成と承認の画面の関係、テストの用途で要る機能）
- [OPEN-102](../open-issues.md#open-102): エージェントハーネスの設定ファイルの細部と、プロジェクトごとの設定ファイル
- [OPEN-103](../open-issues.md#open-103): エージェントハーネスの操作・画面・記録の細部
- [OPEN-095](../open-issues.md#open-095): エージェントハーネスの提供者を差し替える層、実装の順、使うクレート
- [OPEN-096](../open-issues.md#open-096): LLM の提供者に関する事実の確認
- [OPEN-097](../open-issues.md#open-097): Claude Code の CLI を経由して Claude の購読で使う提供者（候補 L）の採否
- [OPEN-101](../open-issues.md#open-101): LLM の提供者の認証の情報の保管と、利用者への表示
- [OPEN-048](../open-issues.md#open-048): プロジェクトの設定ファイルと、根のディレクトリの指定（エージェントハーネスの例外とは別に決める）
- [OPEN-089](../open-issues.md#open-089): 人間から秘密を受け取る経路
- [OPEN-088](../open-issues.md#open-088): 秘密の値の型と、秘密を扱うエフェクト
- [OPEN-081](../open-issues.md#open-081): 外部のライブラリのエフェクトを、権限の表示にどう出すか
- [OPEN-082](../open-issues.md#open-082): git の提供のしかたと、エフェクトの分け方
- [OPEN-094](../open-issues.md#open-094): 依存のクレートの基準を一般の方針とするか
- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度

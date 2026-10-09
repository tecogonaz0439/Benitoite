# Agent Skills 対応

- 状態: 確定
- 関連ADR: [0003](../decisions/0003-license.md), [0127](../decisions/0127-directory-run-and-root.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0179](../decisions/0179-threat-model-and-server-mode-premise.md), [0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md), [0229](../decisions/0229-bundled-skill-contents-and-japanese-translations.md), [0230](../decisions/0230-skill-embedded-and-installed-by-subcommand.md), [0231](../decisions/0231-skill-shows-main-effects-before-running.md), [0232](../decisions/0232-skill-evaluation-with-tasks-and-harnesses.md), [0235](../decisions/0235-third-party-licenses-generated-and-shown-by-option.md), [0236](../decisions/0236-compatibility-during-0x.md), [0241](../decisions/0241-command-name-and-extension.md), [0243](../decisions/0243-signal-exit-code-and-posix-shell.md), [0246](../decisions/0246-syntax-measurement-in-two-stages.md), [0249](../decisions/0249-skill-test-procedure-without-check.md), [0251](../decisions/0251-contract-change-display-not-in-first-release.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0256](../decisions/0256-data-keyword-for-algebraic-types.md), [0257](../decisions/0257-match-with-case-arms.md), [0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md), [0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md)
- 未決事項: [OPEN-012](../open-issues.md#open-012), [OPEN-047](../open-issues.md#open-047), [OPEN-055](../open-issues.md#open-055), [OPEN-060](../open-issues.md#open-060), [OPEN-080](../open-issues.md#open-080)
- 移行元: [設計メモ](../sources/fp-language-design.md) 23.1–23.4

## 目的と範囲

処理系に同梱する Agent Skill（Benitoite のスクリプトをコーディングエージェントに書かせるための Skill）について、次のものを定める。

- Skill の構成と、各ファイルの作り方
- Skill を利用者の環境に導入するサブコマンド `skill`
- Skill がエージェントに求める、実行の前の確認の手順
- Skill の評価の方法
- LLM 向けと設計者向けの言語の文書（英語の言語リファレンスと、日本語の訳）の位置付け

現在の版は、初回リリース版の範囲を定める。サーバモードを加えたときに Skill に加えるもの（エージェントにスタンドアロンモードを使わせない設定の例。[ADR 0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md)）は、サーバモードとあわせて加える（[OPEN-055](../open-issues.md#open-055)）。設計メモ 23.1 の構文の制約付きの生成（tree-sitter の文法などを使うもの）と、23.2 の学習データに入るための取り組み（`llms.txt` など）は、初回リリース版では扱わない。

## 前提

【決定】初回リリース版の処理系は、実行時の権限制御も OS のサンドボックスも持たない。スクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行え、スクリプトが触れる範囲の制限は、処理系を起動する側（ハーネスのサンドボックス、コンテナ、OS の権限）に委ねる（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[セキュリティモデル](../07-quality/07-01-security-model.md)の「ハーネスとの分担」）。

Agent Skills の仕様（[Specification](https://agentskills.io/specification)、2026-09-29 に確認）では、Skill は `SKILL.md` を置いたディレクトリである。`SKILL.md` は YAML の前付けと Markdown の本文からなり、前付けの `name` と `description` は必須である。`name` は英小文字・数字・ハイフンで書き、親のディレクトリの名前と一致させる。任意の欄に `license` と `metadata` がある。エージェントは、起動のときに `name` と `description` だけを読み、Skill を使うと決めたときに `SKILL.md` の本文を読み、`references/` などのほかのファイルは必要になったときに読む。仕様は、`SKILL.md` を 500 行より短くし、詳しい参照の資料を別のファイルに分けることを勧めている。

利用者が作る Skill の中の Benitoite のスクリプトは、Skill のディレクトリの下の一つのファイル（と、その下のモジュール）として実行し、スクリプトの置き場所を基準にファイルを扱うには `Process.scriptDirectory()` を使う（[ADR 0127](../decisions/0127-directory-run-and-root.md)、[ADR 0131](../decisions/0131-script-directory-and-permission-base.md)、[CLI](06-01-cli.md)の「ディレクトリの指定（初回リリース版）」）。本章の Skill は、これとは別に、エージェントに Benitoite の書き方を教えるための Skill である。

## 仕様

### 同梱の Agent Skill の構成

【決定】同梱の Agent Skill は、手で書く短い `SKILL.md` と、必要なときに読む参照の文書（`references/` の下のファイル）からなる（[ADR 0229](../decisions/0229-bundled-skill-contents-and-japanese-translations.md)）。Skill の名前は、コマンドの名前（[ADR 0241](../decisions/0241-command-name-and-extension.md)）に合わせて `benitoite` とする。

| ファイル | 内容 | 作り方 |
|---|---|---|
| `SKILL.md` | 作業の手順と、主な言語の規則の要約。後述の「実行の前の確認」の手順を含む | 手で書く |
| 文法 | EBNF による文法の全体 | [構文](../01-spec/01-02-syntax.md)の「初回リリース版の文法の全体」から生成する。日本語の注釈（`(* … *)`）は除く |
| 標準ライブラリのリファレンス | モジュールごとの関数・型・エフェクトの宣言と説明。モジュールごとに、標準か非公式かの状態と、取り込みの名前（`import Benitoite.Unofficial.IO.Console` など）を示す（[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)） | 標準ライブラリのソースの宣言の型とドキュメントコメントから生成する（[ADR 0157](../decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[ADR 0125](../decisions/0125-doc-comments.md)） |
| 診断コードの説明 | 診断コードごとの誤りの意味と、よくある直し方 | 処理系の中の診断の表のコードの説明から生成する（[診断エンジン](../02-impl/02-10-diagnostics.md)の「診断コード」） |
| イディオム集 | よく行う処理（ファイルの読み書き、JSON・CSV の処理、外部コマンドの起動、HTTP、テストなど）の書き方 | 手で書く |
| よくある誤り集 | ほかの言語の書き方を持ち込んだ誤りと、その直し方 | 手で書く |
| 既知の言語との対応表 | ほかの言語の構文・関数と、Benitoite の書き方の対応 | 手で書く |
| ライセンス文 | Skill のライセンス（`MIT OR Apache-2.0`）の文 | 処理系のリポジトリのライセンス文を写す（[ADR 0003](../decisions/0003-license.md)、[ADR 0235](../decisions/0235-third-party-licenses-generated-and-shown-by-option.md)） |

- 【決定】Skill は英語で書く。
- 【決定】生成は、処理系のクレートを使う生成の道具で行い、生成物をリポジトリに置く。処理系のビルドは、置いた生成物と手で書く文書を処理系の実行ファイルに埋め込む。配る Skill は、同じ実行ファイルの処理系と同じ版になる。生成物が、いまの構文の章・標準ライブラリのソース・診断の表から生成したものと一致することを、処理系のテストで確かめる（[ADR 0288](../decisions/0288-skill-documents-generated-by-tool-and-committed.md)）。
- 【決定】手で書くイディオム集、よくある誤り集、既知の言語との対応表に載せたコードの例は、ゴールデンテスト（[処理系のテスト戦略](../07-quality/07-03-compiler-testing.md)の「ゴールデンテスト」）と同じ仕組みで検査する。期待する出力を書いた例は、実行して出力も比べる。標準ライブラリのドキュメントコメントの例は、初回リリース版では検査しない（[OPEN-047](../open-issues.md#open-047)）。
- 【方針】`SKILL.md` の前付けは、`name: benitoite`、Skill を使う場面を書いた `description`、`license: MIT OR Apache-2.0` と、`metadata` の欄に処理系の版を持つ。
- 【方針】参照の文書のファイルの名前と分け方（標準ライブラリのリファレンスをモジュールごとのファイルに分けるかなど）は、実装プランで定める。仕様の勧めに従い、一つのファイルを一つの主題に絞る。

【方針】`SKILL.md` には、次のものを書く。

1. 作業の手順。スクリプトとテストで手順を分ける（[ADR 0249](../decisions/0249-skill-test-procedure-without-check.md)）。診断コードの意味が分からないときは、診断コードの説明の文書を読む。
   - スクリプト: スクリプトを書く、`benitoite check` で検査する、診断を読んで直す、を検査が通るまで繰り返し、後述の「実行の前の確認」を行ってから、`benitoite run` で実行する。
   - テスト: `check` は `main` のないファイルを誤りとする（[型検査器](../02-impl/02-05-typechecker.md)の「`main`」）ので、テストのファイルには使わない。テストを書いたら、後述の「実行の前の確認」を行ってから、`benitoite test` を呼ぶ。`test` は、検査の誤りがあるファイルのテストを実行せずに、`check` と同じく誤りを報告する（[利用者プログラムのテスト](06-04-test-runner.md)の「テストの実行」）。エージェントは、誤りを直して `test` を呼び直す。
2. 主な言語の規則の要約。ほかの言語と違い、LLM が書き誤りやすい規則（ブロックを `end` で閉じること、局所の束縛を `let` ではなく `bind x <- e` と書き、局所の名前として見えている名前を隠すときだけ `shadow x <- e` と書くこと、パターンで分岐する式を `match 対象 with` と `case パターン -> 本体` で書き、ハンドラの節も `with` と `case 操作(引数) -> 節` で書くこと、戻り値の型を `->` の後に書くこと、代数的データ型を `data … end data` で宣言すること、`Option` と `Result` の構成子を型名で修飾すること、IO のモジュールを import すること、非公式のモジュールを `Benitoite.Unofficial` の下の名前で取り込むこと（[ADR 0286](../decisions/0286-unofficial-modules-imported-under-unofficial.md)）、関数のシグネチャに `uses` でエフェクトを書くことなど）を短く並べる。
3. 参照の文書の一覧と、それぞれを読む場面。
4. 版の確認。エージェントは `benitoite --version` の版と、`SKILL.md` の前付けの版を比べる。違うときは、利用者に `benitoite skill install` を実行し直すよう伝える（[ADR 0236](../decisions/0236-compatibility-during-0x.md)）。

【決定】主な言語の規則の要約には、`Process.shell` に渡す文字列を POSIX の sh の範囲で書き、bash などに固有の書き方（配列、`[[ ]]` など）を使わないことを含める（[ADR 0243](../decisions/0243-signal-exit-code-and-posix-shell.md)）。`/bin/sh` の実装は OS と設定によって違う（[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」）ので、POSIX の sh の範囲に限れば、どの機械でも同じ意味になる。

### 言語の文書と日本語の訳

【決定】LLM 向けと利用者向けの文書は英語で書き、英語の版を正とする（[ADR 0229](../decisions/0229-bundled-skill-contents-and-japanese-translations.md)）。

- `docs/reference/` の英語の言語リファレンスは、現在は最小実行版の範囲だけを扱う。初回リリース版の範囲に書き直すことは、初回リリース版の作業に含める。
- 設計者が読むために、Skill の内容（`SKILL.md` と参照の文書）と言語リファレンスの日本語の訳を作る。日本語の版は、リリースのたびに英語の版から LLM が訳して作る。
- 日本語の版の各ファイルの先頭に、訳であること、訳した元の版、英語の版を正とすること、エージェントが使うためのものではないことを書く。
- 日本語の版は Skill のディレクトリの外に置き、`benitoite skill install` が書き出すものに含めない。`SKILL.md` からも日本語の版を参照しない。
- 【方針】日本語の版は `docs/ja/` の下に置く。

### Skill の導入（初回リリース版）

【決定】同梱の Agent Skill は処理系の実行ファイルに埋め込み、サブコマンド `skill` で各エージェントの置き場所に書き出す（[ADR 0230](../decisions/0230-skill-embedded-and-installed-by-subcommand.md)）。

```text
benitoite skill install   [--user | --project] [--agent <名前>]...
benitoite skill uninstall [--user | --project] [--agent <名前>]...
```

- `install` は、埋め込んだ Skill を、指定したエージェントの置き場所の `benitoite/` に書き出す。`uninstall` は、`install` が書き出した Skill を消す。
- `--user` は利用者の単位の置き場所に、`--project` は作業ディレクトリの下の置き場所に書き出す。既定は `--user` である。`--project` は、リポジトリの根を探して辿らない。
- `--agent` は複数指定できる。省いたときは、次の表のすべてのエージェントの置き場所に書き出す。書き出す先が同じエージェントを重ねて指定したときは、一度だけ書き出す。

| `--agent` | `--user` | `--project` |
|---|---|---|
| `claude-code` | `~/.claude/skills/benitoite/` | `./.claude/skills/benitoite/` |
| `codex` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |
| `opencode` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |

表の置き場所は、2026-09-29 に各エージェントの文書で確かめた、エージェントが Skill を読み込む場所である（Claude Code は [Extend Claude with skills](https://code.claude.com/docs/en/skills)、Codex CLI は [Build skills](https://learn.chatgpt.com/docs/build-skills)、opencode は [Agent Skills](https://opencode.ai/docs/skills/)）。2026-10-08 に同じ三つの文書で確かめ直し、表の置き場所が変わっていないことを確かめた（[試行の記録](../../implement/studies/u4-release/open-060.md)の「Skill の置き場所」）。opencode は `.claude/skills` と `.agents/skills` の両方を読むので、`--agent` を省くと、同じ名前の Skill を二か所から読む。opencode v2.0.21 のソース（タグ `v2.0.21` の `packages/core/src/config/plugin/compatibility.ts`。2026-10-08 に確認）では、`.claude` の置き場所を先に、`.agents` の置き場所を後に読み、Skill のディレクトリの名前を鍵にして、後に読んだものが先のものを置き換える。したがって、二か所の `benitoite` は一つの Skill として扱われ、`.agents/skills/benitoite/` の中身が使われる。`install` は二か所に同じ中身を書き出すので、どちらが使われても結果は変わらない。opencode を実際に動かしての確認は、開発機の opencode の既定のモデルの接続先が使えず済んでいないので【要検証】のまま残す。置き場所は、リリースのたびに文書で確かめ直す（[OPEN-060](../open-issues.md#open-060)）。

- 書き出す先に `benitoite/` がすでにあるとき、それが `install` の書き出したもの（`SKILL.md` の前付けの `metadata` に処理系の版の欄があるもの）なら置き換える。そうでなければ書き出さずに失敗とする。`uninstall` も、`install` が書き出したものだけを消す。
- 置き換えは、同じ親のディレクトリの一時ディレクトリに書き出してから名前を変えて行う。途中で止まっても、半端な Skill を残さない。
- `skill` は、書き出した先と消した先のディレクトリのパスを標準出力に書く。
- 終了状態は、成功が 0、ファイルを書けない・消せない場合と、既存の `benitoite/` を置き換えないと決めた場合が 1、使い方の誤りが 2、処理系の不具合が 3 である。

`skill` のコマンドラインの位置付け（`run` を省いた実行との関係）は [CLI](06-01-cli.md)の「`skill` のコマンドライン（初回リリース版）」で定める。

### 実行の前の確認

【決定】`SKILL.md` に、エージェントがスクリプトを実行する前の確認の手順を書く（[ADR 0231](../decisions/0231-skill-shows-main-effects-before-running.md)）。

1. エージェントは、スクリプトを初めて実行する前と、`main` のエフェクトが前に利用者に示したときより増えたときに、`main` の `uses` のエフェクトを、利用者に分かる言葉で示す（「ファイルを書き換える（`File.Write`）」「外部のコマンドを起動する（`Process.Run`）」など）。テストでは、`main` の代わりに、実行するテストの関数の `uses` のエフェクトを合わせたものを示す（[ADR 0249](../decisions/0249-skill-test-procedure-without-check.md)）。
2. 書き込み（`File.Write`）、外部コマンドの起動（`Process.Run`）、ネットワーク（`Http.Connect`・`Http.Listen`）のエフェクトを含むときは、実行の前に利用者に確かめる。
3. `SKILL.md` には、初回リリース版の処理系は実行中に操作を制限しないことを書き、エージェントのサンドボックスの中で実行することを勧める。

エフェクトを読むことは、`main`（テストではテストの関数）のシグネチャを読むことである。検査を通ったスクリプトは、`main` の `uses` にない組み込みの操作を行わない（[ロードマップ](../00-overview/00-03-roadmap.md)の「各マイルストーンで宣言する保証」）。テストの関数も同じく、その `uses` にない組み込みの操作を行わない。テストでは検査を通る前にシグネチャを読むが、検査の誤りがあるファイルのテストは実行されず、直した後にエフェクトが増えたときは示し直す。したがって、実行されるテストのエフェクトは、利用者に示したものの範囲に収まる。処理系に、権限を表示する機能は加えない。

【方針】手順を成り立たせるために、`SKILL.md` に次のことも書く。

- `main` の `uses` には、`IO.All` ではなく細かいエフェクトを並べて書く。`IO.All` と書いたスクリプトは、書き込みと外部コマンドの起動を含むものとして扱う。
- 組み込みのエフェクトごとに、利用者に示す言葉の対応表を載せる（[エフェクト](../01-spec/01-07-effects.md)の組み込みのエフェクトの表に対応させる）。
- `Process.Run` を含むときは、起動するコマンドの名前も利用者に示す。起動したコマンドが行う操作は、処理系の検査の外にあるからである（[セキュリティモデル](../07-quality/07-01-security-model.md)の「ハーネスとの分担」）。
- `benitoite test` で実行するテストの関数も外部の操作を行いうるので、テストの関数のエフェクトにも同じ手順を当てる。

この手順は、利用者が操作を理解するためのものであり、隔離の代わりにならない。手順を守るかはエージェントに依存し、処理系は強制しない。エフェクトは操作の種類だけを表し、どのファイルやコマンドを対象にするかは表さない。対象の確認と実行時の権限制御は、サーバモードとあわせて加える（[OPEN-055](../open-issues.md#open-055)）。

### Skill の評価

【決定】同梱の Agent Skill は、次の方法で評価する（[ADR 0232](../decisions/0232-skill-evaluation-with-tasks-and-harnesses.md)）。

- 約 10 の課題を用意し、各課題に入力と期待する出力を添える。ロードマップの完了条件の JSON の集計の課題（[ロードマップ](../00-overview/00-03-roadmap.md)の「完了条件」）を含め、ファイルの処理、CSV、外部コマンドの起動、HTTP、テストを書くことを題材に含める。
- 評価は、二つ以上のハーネスで行う。使えるハーネスは、Claude Code、Codex CLI、OpenCode である（[ADR 0246](../decisions/0246-syntax-measurement-in-two-stages.md)）。エージェントには同梱の Skill だけを与え、ほかの文書とインターネットを使わせない。
- 課題の成功は、エージェントの書いたスクリプトが、決めた回数（例えば 10 回）以内の検査と修正の繰り返しで `check` を通り、期待する出力を得ることとする。
- 課題ごとに複数回試行し、成功率と、成功までの検査と修正の回数を記録する。記録には、処理系と Skill の版、ハーネスとモデルの版を残す。
- 課題と記録は `tools/` の下に置き、評価の手順はプロジェクトのスキルとして書く。
- 同じ仕組みを [OPEN-012](../open-issues.md#open-012) の測定の第二段階（初回リリース版の検査器ができた後の、期待結果までの測定）にも使い、構文の案ごとに Skill を差し替えて評価する（[ADR 0246](../decisions/0246-syntax-measurement-in-two-stages.md)）。
- 評価は、初回リリース版の完了の判定のときと、構文・標準ライブラリ・Skill を変えたリリースのときに行う（[配布形態](../05-platform/05-01-distribution.md)の「リリースの試験」）。

【方針】評価の細部は次のとおりとする。

- 課題は `tools/skill-eval/` に、記録はその下の `results/` に置く。評価の手順のスキルの名前は `skill-eval` とする。
- 検査と修正の回数は、エージェントが処理系を起動した回数として数える。評価では、処理系の起動を記録する包みのコマンドを `benitoite` の名前で `PATH` に置く。
- HTTP の課題の接続先は、評価の道具が同じ機械の上に立てるサーバとする。
- ロードマップの完了条件の JSON の集計の課題は、各ハーネスで、試行の過半数が成功したときに満たしたものとする。ほかの課題の成功率は、Skill を改めるための材料として記録し、合格の基準を設けない。

### 外部コマンドを使う操作の選び方の指示（初回リリース版の後）

初回リリース版の `SKILL.md` は、シェルの機能が要らなければ `Process.shell` より `Process.run` を使うよう指示するが、標準ライブラリにある操作を `Process.run` で外部コマンドに任せないよう指示することはしない。`Process.run` で起動したコマンドが中で行う操作は、エフェクトと権限の表示に現れない（[IO のモジュール](../03-interop/03-07-io-modules.md)の「外部コマンドの起動とシェル」）。

【未決】初回リリース版の後に、外部コマンドに当たる操作を、標準ライブラリの関数、コマンドを包むライブラリ、`Process.run` の順で選ぶよう「主な言語の規則の要約」で指示するか、処理系の警告で示すかは、[OPEN-080](../open-issues.md#open-080) で決める。

## 未決事項

- [OPEN-012](../open-issues.md#open-012): 構文の種類ごとの LLM の生成精度（Skill の評価の仕組みで測る）
- [OPEN-047](../open-issues.md#open-047): ドキュメントコメントに書いた例の実行
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計（Skill に加えるエージェントの設定の例を含む）
- [OPEN-060](../open-issues.md#open-060): 配布と Agent Skill の導入に関する事実の確認
- [OPEN-080](../open-issues.md#open-080): 外部コマンドを使う操作の選び方と、エージェントへの示し方

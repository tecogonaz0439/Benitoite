# 0230. 同梱の Agent Skill を処理系の実行ファイルに埋め込み、サブコマンド `skill` で各エージェントの置き場所に書き出す

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [Agent Skills 対応](../06-tooling/06-06-agent-skills.md), [CLI](../06-tooling/06-01-cli.md), [配布形態](../05-platform/05-01-distribution.md)
- 関連する未決事項: [OPEN-060](../open-issues.md#open-060), [OPEN-011](../open-issues.md#open-011)

## 背景

設計メモは、Agent Skills の文脈での実運用上の最大の論点を、スキルを実行する環境に処理系がどう入るかだとした（[設計メモ](../sources/fp-language-design.md) 20）。初回リリース版では、処理系を単一の実行ファイルとして配る（[ADR 0176](0176-first-release-targets-and-static-linux-build.md)）。同梱の Agent Skill は処理系のビルドで作り、処理系と同じ版にする（[ADR 0229](0229-bundled-skill-contents-and-japanese-translations.md)）。

Skill を読み込む場所は、エージェントごとに決まっている。2026-09-29 に各エージェントの文書で確かめた結果は次のとおりである。

| エージェント | 利用者の単位 | プロジェクトの単位 | 出典 |
|---|---|---|---|
| Claude Code | `~/.claude/skills/<名前>/SKILL.md` | `.claude/skills/<名前>/SKILL.md` | [Extend Claude with skills](https://code.claude.com/docs/en/skills) |
| Codex CLI | `$HOME/.agents/skills` | 作業ディレクトリ、その親、リポジトリの根の `.agents/skills` | [Build skills](https://learn.chatgpt.com/docs/build-skills)（`https://developers.openai.com/codex/skills` からの転送先） |
| opencode | `~/.config/opencode/skills/`、`~/.claude/skills/`、`~/.agents/skills/` の下の `<名前>/SKILL.md` | `.opencode/skills/`、`.claude/skills/`、`.agents/skills/` の下の `<名前>/SKILL.md` | [Agent Skills](https://opencode.ai/docs/skills/) |

Agent Skills の仕様（[Specification](https://agentskills.io/specification)）は Skill の形式を定めるが、置き場所は定めていない。

## 決定

1. 同梱の Agent Skill は、処理系の実行ファイルに埋め込んで配る。
2. 初回リリース版に、サブコマンド `skill` を加える。
   - `benitoite skill install [--user | --project] [--agent <名前>]...` は、埋め込んだ Skill を、指定したエージェントの置き場所の `benitoite/` に書き出す。
   - `benitoite skill uninstall [--user | --project] [--agent <名前>]...` は、`skill install` が書き出した Skill を消す。
3. `skill` は、`run` を省いた実行（[ADR 0135](0135-shebang-line-and-implicit-run.md)）で、`run`・`check`・`test`・`fmt` と同じくサブコマンドの名前として扱う。名前が `skill` のファイルを `run` を省いて実行するときは、`./skill` と書く。
4. `--agent` の名前と書き出す先は次のとおりとする。`--agent` は複数指定できる。書き出す先が同じエージェントを重ねて指定したときは、一度だけ書き出す。

   | `--agent` | `--user`（既定） | `--project` |
   |---|---|---|
   | `claude-code` | `~/.claude/skills/benitoite/` | `./.claude/skills/benitoite/` |
   | `codex` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |
   | `opencode` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |

   `--agent` を省いたときは、表のすべてのエージェントの置き場所（`.claude/skills` と `.agents/skills` の二つ）に書き出す。`--project` の `./` は作業ディレクトリであり、リポジトリの根を探して辿ることはしない。
5. `skill install` は、書き出す先に `benitoite/` がすでにあるとき、それが `skill install` の書き出したもの（`SKILL.md` の前付けの `metadata` に処理系の版の欄があるもの）なら置き換える。そうでなければ書き出さずに失敗とする。`skill uninstall` も、`skill install` が書き出したものだけを消す。
6. 置き換えは、同じ親のディレクトリの一時ディレクトリに書き出してから名前を変えて行い、途中で止まっても半端な Skill を残さない。
7. `skill` は、書き出した先と消した先のディレクトリのパスを標準出力に書く。終了状態は、成功が 0、ファイルを書けない・消せない場合と、5 で書き出さないと決めた場合が 1、使い方の誤りが 2、処理系の不具合が 3 とする。

## 検討した代替案

- **アーカイブに Skill のディレクトリを入れ、置き場所に写す手順を文書に書く**: 処理系に機能を加えずに済む。しかし、利用者はエージェントごとの置き場所を調べて写す必要があり、処理系を更新したときに Skill を写し忘れると、版の違う Skill が残る。サブコマンドなら、処理系を更新した後に同じコマンドを実行し直すだけで済む。
- **`--agent` を省けないようにする**: 書き出す先が一つに決まり、opencode が同じ名前の Skill を二か所から読む状況を作らない。しかし、利用者は自分のエージェントの名前を調べて指定する必要がある。二か所に書く Skill は中身が同じなので、どちらが読まれても振る舞いは変わらない見込みである。同じ名前の Skill が二か所にあるときの opencode の振る舞いは確かめていない（[OPEN-060](../open-issues.md#open-060)）。
- **`skill` を予約した名前（[ADR 0209](0209-reserved-subcommand-names.md)）に加えるだけにし、後の版で実装する**: 初回リリース版の作業が減る。しかし、初回リリース版は Agent Skills から作業を自動化できる最初の版であり（[ロードマップ](../00-overview/00-03-roadmap.md)）、Skill を導入する手段を持たずに提供すると、利用者は写す手順に頼ることになる。

## 帰結

- [CLI](../06-tooling/06-01-cli.md) のサブコマンドに `skill` が加わる。[ADR 0209](0209-reserved-subcommand-names.md) の予約した名前とは別に、初回リリース版で実装するサブコマンドである。
- 各エージェントの置き場所は、エージェントの版によって変わりうる。リリースのたびに文書で確かめ直す（[OPEN-060](../open-issues.md#open-060)）。
- 処理系を更新したら、利用者は `benitoite skill install` を実行し直す。Skill は処理系と同じ版だけを対象にする（[ADR 0236](0236-compatibility-during-0x.md)）ので、`SKILL.md` は、エージェントに処理系の版と Skill の版を比べさせ、違えば実行し直すよう利用者に伝えさせる（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)）。

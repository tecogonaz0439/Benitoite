---
name: skill-eval
description: 同梱の Agent Skill（crates/benitoite/skill/）を、tools/skill-eval/ の課題とコーディングエージェントのハーネス（Claude Code・Codex CLI・Antigravity の CLI）で評価するときに使う。設計者の了承の取り方、ハーネスの設定、エージェントに同梱の Skill だけを与える条件、試行の回数、記録の書き方を定める。Skill の評価、初回リリース版の完了条件の JSON の集計の確かめ、構文の案ごとの評価（OPEN-012 の第二段階）を頼まれたときに使う。
---

# Skill の評価

同梱の Agent Skill を、設計書 06-06「Skill の評価」（ADR 0232・0246）に従って評価する手順である。道具は `tools/skill-eval/` にあり、使い方は `tools/skill-eval/README.md` に書いてある。

## 1. 設計者の了承を得る

LLM を呼ぶ評価は、利用料と時間がかかる。`--harness` で評価を始める前に、必ず設計者に次を示して了承を得る。了承を得るまでは、LLM を呼ばない `--self-test` と `--dry-run` だけを行う。

- 使うハーネスとモデル、課題、課題ごとの試行の回数
- 試行の総数と、所要時間の見込み（README の「所要時間と回数の見込み」）
- 確かめていないハーネスの設定（README の「ハーネスの設定」の表）があれば、その点

## 2. 準備

1. 評価する版の処理系を作る（`cargo build --release`）。`--benitoite` で別の処理系を指定してもよい。
2. `python3 tools/skill-eval/skill_eval.py --self-test` を実行し、すべて `ok` であることを確かめる。失敗があれば、評価を始めず、課題か処理系を直す。
3. `python3 tools/skill-eval/skill_eval.py --dry-run --agent <エージェント>` を、使うハーネスの数だけ実行し、すべての試行が成功と判定されることを確かめる。

## 3. 使うハーネスと、同梱の Skill だけを与える条件

評価は二つ以上のハーネスで行う。既定の対象（`--harness default`）は、設計者の決定（2026-10-08）により、Claude Code（`claude-code`。Opus 5.5、effort medium）、Codex CLI（`codex`。GPT-6-Luna、reasoning effort max）、Antigravity の CLI（`antigravity-gemini`。Gemini 3.8 Flash high と、`antigravity-gpt-oss`。GPT-OSS 120B medium）である。OpenCode（`opencode`）は設計者が解約したので使わない。GPT-6-Luna と GPT-OSS 120B の結果は、オープンウェイトのモデルでもうまく書けるかの目安として扱う。`antigravity-gpt-oss` は、短い試行で動きを見てから本番に含めるかを設計者と決める。起動のコマンドは `tools/skill-eval/harnesses.json` にある。

エージェントには同梱の Skill だけを与え、ほかの文書とインターネットを使わせない。

- 作業ディレクトリはリポジトリの外に作る（道具の既定。`--work-root` もリポジトリの外に限る）。リポジトリの設計書やゴールデンテストを読ませないためである。
- インターネットを使わせない設定は、`harnesses.json` に書いてある（Codex はサンドボックスと web 検索の無効化、Claude Code は `--disallowedTools`、Antigravity は `--sandbox`。Antigravity でウェブの検索を止める方法は確かめていない）。
- 利用者の設定にある、ほかの Skill と MCP のサーバと、利用者の指示のファイル（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、Antigravity の `~/.gemini/config/` の `skills.json`・`plugins.json`・`mcp_config.json` と大域の `GEMINI.md`・`AGENTS.md`）を外す。外せないなら、評価のための別の利用者の設定でハーネスを起動する。案として、Claude Code は環境変数 `CLAUDE_CONFIG_DIR`、Codex は `CODEX_HOME` で空の設定のディレクトリを指し、Antigravity は別の `HOME` で起動する（どれも確かめていないので、最初の評価で確かめる）。
- `harnesses.json` の `verified` が `false` のハーネスは、最初の評価の前に、設計者と一緒に一つの課題・一回の試行で起動し、次を確かめる。道具は `verified` が `false` のハーネスを、`--allow-unverified` を付けたときだけ起動する。確かめたら `verified` を `true` にし、確かめた版を `harnesses.json` の `_comment` か README に書く。
  - Skill を読んだこと（ハーネスの出力に Skill のファイルを読んだ跡がある）
  - 包みのコマンドが呼ばれたこと（`<試行>/benitoite.log` に行がある）
  - web の取得や検索の道具を呼んでいないこと

## 4. 最初の短い試行

最初の評価は、本番の前に、既定の対象の各組で `json_summary` を 1 回ずつ試す短い試行から始める（設計者の方針）。

```sh
python3 tools/skill-eval/skill_eval.py --harness default --task json_summary --trials 1 --allow-unverified --work-root <リポジトリの外>
```

試行の後、組ごとに次を確かめる。一つでも満たさない組は、`harnesses.json` を直して短い試行をやり直し、満たすまで本番に進めない。

- ハーネスが起動し、終わったこと（`harness.stderr`、記録の理由の欄）
- 解が見えないこと: ハーネスの出力に、作業ディレクトリと Skill の外（リポジトリ、`tasks/`、`reference.bnt`、設計書、利用者の指示のファイル）を読んだ跡がない
- 回数が記録されたこと: `<試行>/benitoite.log` に `check`・`run` の行がある（ない試行は、道具が警告を書いて失敗にする）
- 外部に接続しないこと: ハーネスの出力に、ウェブの取得や検索の道具の呼び出しがない

確かめたら、組の `verified` を `true` にする（3 節）。

## 5. 試行の回数

- 初回リリース版の完了条件の確かめは、`json_summary` を各ハーネスで 5 回試行する。各ハーネスで過半数（3 回以上）が成功したら、完了条件を満たしたとする。
- 全課題の評価は、各課題を各ハーネスで 3 回以上試行する。成功率は Skill を改める材料として記録し、合格の基準を設けない。
- 構文の案ごとの評価（OPEN-012 の第二段階）は、案ごとの Skill のディレクトリを `--skill-dir` で渡し、すべての案を同じハーネス・モデル・課題・試行の回数で評価する。
- 一つの試行の検査と修正の回数の上限は、課題の `task.json` の `attempt_limit`（既定 10）である。評価の途中で変えない。

## 6. 記録

- 道具は `tools/skill-eval/results/<日時>-<ハーネス>.md` に記録を書く。記録には、処理系と Skill の版、ハーネスとモデルの版、課題ごとの成功率と検査と修正の回数が入る。記録の表（課題ごとの結果と試行ごとの結果）を書き換えない。
- 失敗した試行は、`--work-root` に残した作業ディレクトリと `harness.stdout` を読み、失敗の原因（Skill の説明の不足、処理系の診断の分かりにくさ、課題の指示の曖昧さ、ハーネスの不具合）を記録の末尾に「所見」として書き足す。
- 生の対話の記録と作業ディレクトリは、リポジトリに入れない。
- 成功した試行のスクリプトを受け入れテストに加えるときは、設計書 07-03「受け入れ例と仕様の項目の対応」に従う（`json_summary` の入力と期待する出力は、受け入れテスト `testdata/acceptance/json_summary` と同じである）。
- 記録の「診断のコードの集計」から、警告の有効性を読む（README の「診断のコードの統計」）。よく出てよく解消される警告は効いている。出るのに解消されない警告は、文言が伝わっていない可能性がある。一度も出ない警告は、課題で測れていない。所見に書き、設計者に示す。
- 評価の結果を設計者に報告する。完了条件の確かめでは、ハーネスごとの `json_summary` の成功の数を示す。

# D23 Skill の評価の道具

- 依存する作業: [D21](D21-skill-handwritten-docs.md), [D22](D22-skill-install.md)
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。課題のデータを含む）
- ブランチ: impl/D23-skill-eval

## 目的

同梱の Agent Skill を評価する道具と課題を作る（06-06「Skill の評価」、ADR 0232）。課題（約 10）、処理系の起動を記録する包みのコマンド、HTTP の課題の接続先のサーバ、評価を行う道具、評価の手順を書いたプロジェクトのスキル `skill-eval` である。

本作業は、LLM を呼ばない。道具が LLM を呼ばずに動く部分（課題の準備、包みのコマンド、期待する出力との比較、記録の集計）を確かめるまでを行う。LLM を呼ぶ評価そのものは、設計者の了承を得てから、U3・U4 を終えた後に行う（[90-after-completion.md](../90-after-completion.md)。AGENTS.md の「LLM を呼ぶ測定は設計者の了承を得てから行う」と同じ扱い）。

## 読む設計書の節

- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 「Skill の評価」
- [ロードマップ](../../design/00-overview/00-03-roadmap.md): 「初回リリース版」の「完了条件」
- [ADR 0232](../../design/decisions/0232-skill-evaluation-with-tasks-and-harnesses.md)、[ADR 0246](../../design/decisions/0246-syntax-measurement-in-two-stages.md)
- 既存の道具: `tools/syntax-measure/README.md`（ハーネスの呼び方と、生の記録をリポジトリの外に置く扱い）

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `tools/skill-eval/README.md` | 道具の使い方、課題の一覧、記録の形 |
| `tools/skill-eval/tasks/<課題>/` | 課題ごとの指示の文（`task.md`。英語）、入力のファイル（`input/`）、期待する出力（`expected.stdout` と、必要なら `expected.files/`）、試行の上限の回数 |
| `tools/skill-eval/bin/benitoite` | 包みのコマンド（POSIX の sh）。起動のたびに、引数・終了状態・時刻を記録のファイル（環境変数 `SKILL_EVAL_LOG` のパス）に一行ずつ加え、本物の `benitoite`（環境変数 `SKILL_EVAL_REAL_BENITOITE`）を実行する |
| `tools/skill-eval/http_server.py` | HTTP の課題の接続先。同じ機械の上のループバックで決まった応答を返す（Python の標準ライブラリだけ）。待ち受けのポートは空いているものを選び、解のスクリプト（とエージェントが書くスクリプト）には環境変数で渡す。スクリプトは `Process.environmentVariable` で読む（03-07「Process」）。課題の指示の文に、その環境変数の名前を書く |
| `tools/skill-eval/skill_eval.py` | 評価の道具（Python の標準ライブラリだけ）。課題ごとに作業ディレクトリを作り、Skill を `benitoite skill install --project --agent <エージェント>` で置き、ハーネスを起動し、書かれたスクリプトを実行して期待する出力と比べ、検査と修正の回数（`check`・`run`・`test` の起動の回数）を記録から数える。`--dry-run` はハーネスを起動せず、課題の準備と比較だけを行う |
| `tools/skill-eval/results/` | 記録の置き場所（`.gitkeep`）。記録には処理系と Skill の版、ハーネスとモデルの版、課題ごとの成功率と回数を書く。生の対話の記録はリポジトリの外に置く（`tools/syntax-measure/` と同じ扱い） |
| `.claude/skills/skill-eval/SKILL.md`（本作業で作る。オーケストレータが許可した） | 評価の手順のスキル。設計者の了承を得ること、使えるハーネス（Claude Code・Codex CLI・OpenCode）、エージェントに同梱の Skill だけを与えてほかの文書とインターネットを使わせない設定、試行の回数、記録の書き方 |
| `.agents/skills/skill-eval` | 上のスキルへの相対パスのシンボリックリンク（AGENTS.md「Agent Skills の運用」） |
| `AGENTS.md`（本作業で直す。オーケストレータが許可した） | 「ディレクトリ構成」の表に `tools/skill-eval/` の行を加え、`.claude/skills/` の行のスキルの一覧に `skill-eval` を加える |

## 手順の要点

1. 課題は約 10 とし、次を含める（06-06「Skill の評価」）: ロードマップの完了条件の JSON の集計（JSON ファイルを読んで集計する）、ファイルの処理（読んで書く）、CSV、外部コマンドの起動（`Process.run`）、シェル（`Process.shell`）、HTTP（`http_server.py` に接続するクライアント）、テストを書くこと（組み込みの操作のハンドラでの差し替えを含む）、テキストの処理（正規表現）、ディレクトリの走査、エラー処理（読めないファイルの扱い）。JSON の集計の課題は、D34 が受け入れテストに置いた課題をそのまま使う。入力は `crates/benitoite/testdata/acceptance/json_summary.files/orders.json`、期待する出力は `crates/benitoite/testdata/acceptance/json_summary.stdout` である（90-after-completion で、成功した試行のスクリプトを受け入れテストに加えるとき、期待値が噛み合うようにするため）。
2. Python の道具（`skill_eval.py`・`http_server.py`）は、開発機の python3（3.9.6）で動く書き方にする。3.10 以降の構文（`match` 文、型注釈の `X | Y`）を使わない。型注釈が要るときは `typing` の `Optional`・`Union` を使う。
3. 各課題に、正しい解のスクリプトを `tools/skill-eval/tasks/<課題>/reference.bnt` として置き、`skill_eval.py --self-test` がそれを実行して期待する出力と一致することを確かめる。課題そのものが解けることを、LLM を呼ばずに確かめるためである。解のスクリプトはエージェントに見せない（作業ディレクトリに写さない）。
4. 成功の判定は、決めた回数（既定 10 回）以内の検査と修正の繰り返しで `check` を通り、期待する出力を得ることとする（ADR 0232 の決定 3）。テストを書く課題は、テストのファイルに `check` を使わない（06-06 の作業の手順、ADR 0249）ので、決めた回数以内に `benitoite test` が成功し、期待するテストの数（または期待する出力）になることを成功とする。期待するテストの数は課題のファイルに書く。道具は、ハーネスが終わった後に `benitoite test --diagnostics=json` を実行し直し、JSON Lines の集計の行（06-04「結果の報告」）から成功の数を読んで比べる。JSON の集計の課題は、各ハーネスで試行の過半数が成功したときに完了条件を満たしたとする（06-06）。
5. ハーネスの起動のコマンドは、`tools/syntax-measure/` の呼び方（`bntmeasure/agents.py` の型板）に合わせ、道具の設定のファイルに置く。ハーネスごとに、Skill の置き場所（`--agent`）とインターネットを使わせない設定を書く。設定が確かめられないハーネスは、README にそのことを書き、評価の手順のスキルで設計者に確かめるよう書く。`tools/syntax-measure/` には Codex と opencode の型板しかなく、Claude Code の型板はない。Claude Code の起動のコマンドと設定は、案を書いたうえで README に「確かめられない」と書けば足りる。
6. OPEN-012 の第二段階（構文の案ごとの評価）に同じ仕組みを使えるよう、Skill のディレクトリを差し替える選択肢（`--skill-dir`）を持たせる（ADR 0246）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `skill_eval.py --self-test` | すべての課題の解のスクリプトが期待する出力を出す |
| `skill_eval.py --dry-run` | 課題ごとの作業ディレクトリに Skill が置かれ、包みのコマンドの記録が作られ、解のスクリプトを置いた場合に成功と判定される。テストを書く課題は、`benitoite test` の成功と期待するテストの数で成功と判定される |
| 包みのコマンド | 起動の回数と終了状態が記録され、本物の処理系の終了状態がそのまま返る |
| HTTP の課題 | `http_server.py` を起動し、解のスクリプトが接続して期待する出力を得る |
| スキルのリンク | `.agents/skills/skill-eval` が `.claude/skills/skill-eval` を指す |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- `skill_eval.py --self-test` と `--dry-run` の結果を完了の報告に書いている
- LLM を呼んでいない

## 難易度の理由

道具は Python の標準ライブラリで書く小さなものの組み合わせだが、課題を約 10 作り、それぞれの解と期待する出力をそろえる量がある。ハーネスの設定の細部は、実際に呼ばずに書くので、確かめられない点を README に残す判断が要る。

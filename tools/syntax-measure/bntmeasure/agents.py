# -*- coding: utf-8 -*-
"""コーディングエージェントを呼ぶコマンドの型板。測定の設定を変えるときは、この表だけを直す。

型板の中の {workspace}・{model}・{prompt}・{session} と、options の各キー（{reasoning_effort} など）は、
実行のときに値で置き換える。cwd はコマンドを実行するディレクトリである。
start は 1 回目の呼び出し、resume は同じセッションを続ける呼び出し（診断を渡して直させる）である。
session_keys は、エージェントの JSON の出力からセッションの ID を探すときの鍵の名前である。

codex（codex-cli 0.158.0 の `codex exec --help` で確かめた選択肢）:
- `--json` でイベントを JSON Lines で出す。`thread.started` の `thread_id` がセッションの ID になる。
- `--sandbox workspace-write` と `--cd` で、作業場所だけに書けるようにする。`codex exec resume` は
  `--cd` と `--sandbox` を受け付けないので、cwd と `-c sandbox_mode=...` で同じ設定にする。
- `-c notify=[]` は、利用者の設定の通知（ターンの終わりの通知）を測定の間だけ止める。
- 作業場所はリポジトリの外にあり、git のリポジトリではないので `--skip-git-repo-check` を付ける。
opencode（opencode v2.0.18 の `opencode run --help` で確かめた選択肢）:
- 作業ディレクトリを指定する選択肢はないので、cwd を作業場所にする。
- `--format json` でイベントを JSON で出し、`sessionID` がセッションの ID になる。`-s` で続ける。
- `--auto` で、明示に拒否していない操作の許可を自動で与える。
モデルの ID `opencode-go/longcat-2.5-preview-free` は `opencode models` の一覧で確かめた。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FAKE = os.path.join(HERE, 'fake_agent.py')

AGENTS = {
    'codex': dict(
        model='gpt-6-luna',
        options={'reasoning_effort': 'max'},
        start=['codex', 'exec', '--json', '--skip-git-repo-check', '--sandbox', 'workspace-write',
               '--cd', '{workspace}', '-m', '{model}', '-c', 'model_reasoning_effort="{reasoning_effort}"',
               '-c', 'notify=[]', '{prompt}'],
        resume=['codex', 'exec', 'resume', '--json', '--skip-git-repo-check', '-m', '{model}',
                '-c', 'model_reasoning_effort="{reasoning_effort}"', '-c', 'sandbox_mode="workspace-write"',
                '-c', 'notify=[]', '{session}', '{prompt}'],
        cwd='{workspace}',
        version=['codex', '--version'],
        session_keys=('thread_id', 'session_id', 'conversation_id'),
    ),
    'opencode': dict(
        model='opencode-go/longcat-2.5-preview-free',
        options={},
        start=['opencode', 'run', '--standalone', '-m', '{model}', '--format', 'json', '--auto', '{prompt}'],
        resume=['opencode', 'run', '--standalone', '-m', '{model}', '--format', 'json', '--auto', '-s', '{session}', '{prompt}'],
        cwd='{workspace}',
        version=['opencode', '--version'],
        session_keys=('sessionID', 'session_id', 'sessionId'),
    ),
    # 測定の道具を確かめるための偽のエージェント（LLM を呼ばない）
    'fake': dict(
        model='fake-1',
        options={},
        start=[sys.executable, FAKE, 'start', '{prompt}'],
        resume=[sys.executable, FAKE, 'resume', '{session}', '{prompt}'],
        cwd='{workspace}',
        version=[sys.executable, FAKE, '--version'],
        session_keys=('thread_id',),
    ),
}

# 1 回目の依頼。エージェントには、参照の文書と課題のファイルだけを読ませる
FIRST_PROMPT = (
    'You are writing a script in the Benitoite programming language.\n'
    'Read the language reference in `reference.md` and the task in `task.md`, both in the current directory. '
    'Then write the complete program to the file `main.bnt` in the current directory.\n'
    'There is no Benitoite compiler, interpreter or checker on this machine. Do not try to run, compile or test '
    'the program, do not install anything, and do not look for other files. Only read the two files and write '
    '`main.bnt`.'
)

# 検査で誤りが見つかったときの、修正の依頼（1 回だけ）
FIX_PROMPT = (
    'The Benitoite checker found an error in `main.bnt`. It reports only the first error:\n\n'
    '```\n{diagnostic}\n```\n\n'
    'Fix `main.bnt` and write the corrected complete program to `main.bnt` in the current directory. '
    'As before, do not run any tools other than reading files and writing `main.bnt`.'
)


def render(template, values):
    return [part.format(**values) for part in template]

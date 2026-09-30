# -*- coding: utf-8 -*-
"""測定の道具を確かめるための偽のエージェント。LLM を呼ばない。

作業場所（カレントディレクトリ）の reference.md から最初の例のプログラムを取り出して main.bnt に書く。
作業場所のパスから決まる擬似乱数で、1 回目に誤りを混ぜることがある（波括弧、for、end の取り違え、
end の書き忘れ、==、fn、括弧の組など）。2 回目（resume）は、誤りのない例を書く。
ただし stubborn の場合は同じ誤りを残し、no-script の場合は 1 回目に main.bnt を書かない。
環境変数 BENITOITE_FAKE_SLEEP を与えると、その秒数だけ待ってから書く（時間切れの確認用）。
出力は codex の --json に似せたイベントの JSON Lines である。
"""
import hashlib
import json
import os
import re
import sys
import uuid

MODES = ['none', 'none', 'brace', 'for', 'end-mismatch', 'missing-end', 'eqeq', 'fn', 'tuple', 'stubborn',
         'no-script', 'none']


def example_program():
    text = open('reference.md', encoding='utf-8').read()
    part = text.split('## 10. Example programs', 1)[-1]
    m = re.search(r'```benitoite\n(.*?)```', part, re.S)
    return m.group(1)


def inject(src, mode):
    lines = src.split('\n')
    first_fn = next((k for k, ln in enumerate(lines) if re.match(r'^(public |pub )?(function|fn) ', ln)), 0)
    if mode in ('brace', 'stubborn'):
        lines[first_fn] += ' {'
    elif mode == 'for':
        lines.insert(first_fn + 1, '  for x in xs')
    elif mode == 'end-mismatch':
        for k in range(len(lines) - 1, -1, -1):
            if re.match(r'^end (function|fn)$', lines[k]):
                lines[k] = 'end if'
                break
    elif mode == 'missing-end':
        while lines and not lines[-1].strip():
            lines.pop()
        lines.pop()
    elif mode == 'eqeq':
        lines.insert(first_fn + 1, '  Console.writeLine("${1 == 1}")')
    elif mode == 'fn':
        lines[first_fn] = re.sub(r'^function ', 'fn ', lines[first_fn])
    elif mode == 'tuple':
        lines.insert(first_fn + 1, '  Console.writeLine(Pair.first((1, 2)))')
    return '\n'.join(lines)


def mode_for_workspace():
    h = int(hashlib.sha256(os.getcwd().encode('utf-8')).hexdigest(), 16)
    return MODES[h % len(MODES)]


def emit(events):
    for e in events:
        print(json.dumps(e))
    sys.stdout.flush()


def main(argv):
    if argv[:1] == ['--version']:
        print('fake-agent 1.0')
        return 0
    cmd = argv[0]
    # 時間切れの処理を確かめるために、環境変数で指定した秒数だけ待てるようにする
    if os.environ.get('BENITOITE_FAKE_SLEEP'):
        import time
        time.sleep(float(os.environ['BENITOITE_FAKE_SLEEP']))
    mode = mode_for_workspace()
    good = example_program()
    if cmd == 'start':
        session = str(uuid.uuid4())
        if mode != 'no-script':
            with open('main.bnt', 'w', encoding='utf-8') as f:
                f.write(inject(good, mode))
    elif cmd == 'resume':
        session = argv[1]
        with open('main.bnt', 'w', encoding='utf-8') as f:
            f.write(inject(good, mode) if mode == 'stubborn' else good)
    else:
        print('unknown command', file=sys.stderr)
        return 2
    sys.stderr.write('fake agent: mode=%s\n' % mode)
    emit([{'type': 'thread.started', 'thread_id': session},
          {'type': 'item.completed', 'item': {'type': 'agent_message', 'text': 'Wrote main.bnt.'}},
          {'type': 'turn.completed', 'usage': {'input_tokens': 1000, 'cached_input_tokens': 200,
                                               'output_tokens': 300}}])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

# -*- coding: utf-8 -*-
"""参照の文書（variants/<ID>/reference.md）を雛形（template/reference.md）から作る。

雛形は英語で書き、コードは基準の構文（V00）で書く。雛形の記法は次のとおりである。
- 行 `@@if 機能[,機能...]` / `@@elif ...` / `@@else` / `@@end`: 案がその機能のどれかを持つとき
  （`!機能` はその機能を持たないとき）だけ、間の行を残す。入れ子にできる。
- ```` ```benitoite ```` のコードの塊: convert.py で案の構文に書き換える。
- `{{code:コード}}`: コードを案の構文に書き換え、インラインのコードにする。
- `{{kw:語}}`: 案でのキーワードの綴り（V02 の fn など）。
- `{{KEYWORDS}}`・`{{RESERVED}}`・`{{RULE2}}`・`{{RULE3}}`・`{{EBNF}}`: 案の定義から作る一覧と文法。
"""
import os
import re

from . import variants as V
from .convert import convert

TEMPLATE = os.path.join(V.ROOT, 'template', 'reference.md')


def _cond(v, spec):
    for item in spec.split(','):
        item = item.strip()
        if item.startswith('!'):
            if item[1:] not in v.features:
                return True
        elif item in v.features:
            return True
    return False


def _select(v, lines):
    out = []
    stack = []  # (この枝を出すか, すでにどれかの枝を出したか, 外側を出すか)
    active = True
    for ln in lines:
        m = re.match(r'^@@(if|elif|else|end)\b\s*(.*)$', ln)
        if not m:
            if active:
                out.append(ln)
            continue
        op, arg = m.group(1), m.group(2)
        if op == 'if':
            c = _cond(v, arg)
            stack.append([c, c, active])
            active = active and c
        elif op == 'elif':
            top = stack[-1]
            c = (not top[1]) and _cond(v, arg)
            top[0] = c
            top[1] = top[1] or c
            active = top[2] and c
        elif op == 'else':
            top = stack[-1]
            c = not top[1]
            top[0] = c
            top[1] = True
            active = top[2] and c
        else:
            top = stack.pop()
            active = top[2]
    if stack:
        raise ValueError('unclosed @@if in template')
    return out


def _words(xs):
    return ', '.join('`%s`' % x for x in sorted(xs))


def build(vid):
    v = V.get(vid)
    lines = open(TEMPLATE, encoding='utf-8').read().split('\n')
    text = '\n'.join(_select(v, lines))

    def code_block(m):
        return '```benitoite\n' + convert(m.group(1), vid) + '```'
    text = re.sub(r'```benitoite\n(.*?)```', code_block, text, flags=re.S)
    text = re.sub(r'\{\{code:(.*?)\}\}', lambda m: '`%s`' % convert(m.group(1), vid), text)
    text = re.sub(r'\{\{kw:(\w+)\}\}', lambda m: v.kw(m.group(1)), text)
    text = text.replace('{{KEYWORDS}}', _words(v.keyword_list()))
    text = text.replace('{{RESERVED}}', _words(v.reserved_words()))
    text = text.replace('{{RULE2}}', _words(x for x in v.rule2))
    text = text.replace('{{RULE3}}', _words(x for x in v.rule3))
    unused = [x for x in ('{', '}', ';', '?', '#', '|', '=>', '==', '!=', '&&', '||', '!', '%', '$')
              if x not in v.symbols]
    text = text.replace('{{UNUSED_SYMBOLS}}', ', '.join('`%s`' % x for x in unused))
    text = text.replace('{{EBNF}}', '```ebnf\n' + v.helpers.strip() + '\n\n' + v.ebnf.strip() + '\n```')
    if '{{' in text or '@@' in text:
        raise ValueError('unexpanded template markup in %s: %s' % (vid, re.findall(r'\{\{.*?\}\}|@@\w+', text)[:5]))
    return re.sub(r'\n{3,}', '\n\n', text).strip() + '\n'


def path_of(vid):
    return os.path.join(V.ROOT, 'variants', vid, 'reference.md')


def code_blocks(text):
    """参照の文書のコードの塊（```benitoite）を (行番号, コード) の並びで返す。"""
    out = []
    for m in re.finditer(r'```benitoite\n(.*?)```', text, re.S):
        out.append((text[:m.start()].count('\n') + 1, m.group(1)))
    return out


def write_all():
    paths = []
    for vid in V.VARIANT_IDS:
        p = path_of(vid)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w', encoding='utf-8') as f:
            f.write(build(vid))
        paths.append(p)
    return paths

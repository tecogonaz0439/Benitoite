"""登録名だけに必要な単純マクロを展開し、全DECL参照の名前を解決する。"""
import json
import re
from inventory import FUNCS, ROOT, HERE, population, write


def clean(text):
    # 文字列を保ち、コメントを除く。URL中の // はコメントにしない。
    return re.sub(r'''r(?P<hash>\#{0,16})".*?"(?P=hash)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])'|//[^\n]*|/\*.*?\*/''',
        lambda m: m[0] if not m[0].startswith('/') else " " * len(m[0]), text, flags=re.S)


def group(text, start):
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack = [pairs[text[start]]]
    i = start + 1
    while stack:
        c = text[i]
        if c == "r" and (m := re.match(r'r(\#{0,16})"', text[i:])):
            i = text.index('"' + m[1], i + m.end()) + 1 + len(m[1])
            continue
        if c == "'" and (m := re.match(r"'(?:\\.|[^'\\])'", text[i:])):
            i += m.end()
            continue
        if c == '"':
            m = re.match(r'"(?:\\.|[^"\\])*"', text[i:])
            assert m
            i += m.end()
            continue
        if c in pairs:
            stack.append(pairs[c])
        elif c in ")}]":
            assert c == stack.pop()
        i += 1
    return text[start+1:i-1], i


def arguments(text):
    chunks, last, i = [], 0, 0
    while i < len(text):
        if text[i] in "([{":
            _, i = group(text, i)
        elif text[i] == '"':
            i += re.match(r'"(?:\\.|[^"\\])*"', text[i:]).end()
        elif text[i] == ',':
            chunks.append(text[last:i].strip()); last = i+1; i += 1
        else:
            i += 1
    chunks.append(text[last:].strip())
    return [c for c in chunks if c]


def expand(text):
    text = clean(text)
    # テストの後に登録の続きがあるファイルもある。モジュールだけを除く。
    while (m := re.search(r"\bmod tests\s*([;{])", text)):
        end = m.end() if m[1] == ";" else group(text, m.end()-1)[1]
        text = text[:m.start()] + text[end:]
    macros = {}
    while (m := re.search(r"macro_rules!\s*(\w+)\s*\{", text)):
        body, end = group(text, m.end()-1)
        args_start = body.index("(")
        params, params_end = group(body, args_start)
        template_start = body.index("{", params_end)
        template, _ = group(body, template_start)
        macros[m[1]] = (re.findall(r"\$(\w+):\w+", params), template)
        text = text[:m.start()] + text[end:]
    for _ in range(5):
        changed = False
        for name, (params, template) in macros.items():
            pattern = re.compile(r"\b" + name + r"!\s*([({])")
            while (m := pattern.search(text)):
                args, end = group(text, m.end()-1)
                values = arguments(args)
                assert len(values) == len(params), (name, values, params)
                mapping = dict(zip(params, values))
                value = re.sub(r"\$(\w+)", lambda m: mapping[m[1]], template)
                text = text[:m.start()] + value + text[end:]
                changed = True
        if not changed:
            return text
    raise AssertionError("マクロ展開が収束しない")


def builtin_names(file):
    text = expand(file.read_text())
    scopes = []
    for m in re.finditer(r"\bmod\s+(\w+)\s*\{", text):
        _, end = group(text, m.end()-1)
        scopes.append((m.start(), end, m[1]))
    result = {}
    for m in re.finditer(r"\bbuiltin!\s*\{", text):
        body, _ = group(text, m.end()-1)
        name = re.search(r'\bname\s*=\s*("(?:\\.|[^"\\])*")', body)
        function = re.search(r"\b(?:pure|io|state)\s+fn\s+(\w+)", body)
        assert name and function, (file.name, body[:180])
        parents = [n for start, end, n in scopes if start < m.start() < end]
        key = "::".join(parents + [function[1]])
        assert key not in result, (file.name, key)
        result[key] = json.loads(name[1])
    return result


def registrations():
    pop = population()
    rows = []
    for part in pop["parts"]:
        file = ROOT / part["file"]
        prefix = ""
        if part["part"] == "http_client::PURE_DECLS":
            file = FUNCS / "http_client/checked_request.rs"
        names = builtin_names(file)
        for i, ref in enumerate(part["references"]):
            assert ref in names, (part["part"], ref, sorted(names))
            rows.append({"id": f"R{len(rows)+1:03}", "part": part["part"], "index": i,
                "reference": ref + "::DECL", "name": names[ref], "source": str(file.relative_to(ROOT))})
    assert len(rows) == 523
    return rows


if __name__ == "__main__":
    rows = registrations()
    for offset in range(0, len(rows), 160):
        write(HERE / f"rust-part-{offset//160+1}.json", rows[offset:offset+160])
    print(len(rows), len({r['name'] for r in rows}))

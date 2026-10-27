"""保存したRange入力のSurface先行順。型・パターン・容器には番号を付けない。"""


def block_expressions(block):
    if block == "empty":
        return
    tag, fields = next(iter(block.items()))
    assert tag in {"last", "bind", "discard", "lastBind", "lastDiscard"}, tag
    yield from expressions(fields["expr"])
    if "rest" in fields:
        yield from block_expressions(fields["rest"])


def expressions(expr):
    yield expr
    if isinstance(expr, str):
        assert expr == "unit", expr
        return
    tag, fields = next(iter(expr.items()))
    if tag == "call":
        yield from expressions(fields["callee"])
        for arg in fields["args"]:
            yield from expressions(arg)
    elif tag == "returnE" or tag == "paren":
        yield from expressions(fields["inner"])
    elif tag == "block":
        yield from block_expressions(fields["body"])
    elif tag == "matchE":
        yield from expressions(fields["scrutinee"])
        for arm in fields["arms"]:
            arm = arm["mk"]
            if arm["guard"] is not None:
                yield from expressions(arm["guard"])
            yield from block_expressions(arm["body"])
    elif tag == "binary":
        yield from expressions(fields["lhs"])
        yield from expressions(fields["rhs"])
    elif tag == "list" or tag == "conCall":
        for arg in fields["elems" if tag == "list" else "args"]:
            yield from expressions(arg)
    else:
        assert tag in {"literal", "negInt", "local", "funName", "nullCon"}, tag


def numbered(surface):
    # 本体の根blockも式として占める。根の容器の中身は1から始まる。
    return enumerate([{"block": {"body": surface["body"]}}, *block_expressions(surface["body"])])

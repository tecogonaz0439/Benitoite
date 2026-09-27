import sys


def line_count(text):
    if text == "":
        return 0
    lines = text.split("\n")
    if text.endswith("\n"):
        lines.pop()
    return len(lines)


with open(sys.argv[1], "r", encoding="utf-8", newline="") as source:
    print(line_count(source.read()))

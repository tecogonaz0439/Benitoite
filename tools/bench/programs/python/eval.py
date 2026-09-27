import sys


def build_expression(depth):
    if depth == 0:
        return ("lit", 1)
    smaller = build_expression(depth - 1)
    branch = depth % 3
    if branch == 0:
        return ("add", smaller, ("lit", depth))
    if branch == 1:
        return ("inc", smaller)
    return ("scale", smaller, 1)


def evaluate(expression):
    if expression[0] == "lit":
        return expression[1]
    if expression[0] == "add":
        return evaluate(expression[1]) + evaluate(expression[2])
    if expression[0] == "inc":
        return evaluate(expression[1]) + 1
    return evaluate(expression[1]) * expression[2]


# 式の深さは固定し、入力の回数だけ評価を繰り返す（Benitoite の版と同じ）。
expression = build_expression(500)
total = 0
for _ in range(int(sys.argv[1])):
    total += evaluate(expression)
print(total)

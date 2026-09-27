import sys


def build_tree(depth):
    if depth == 0:
        return ("leaf", 1)
    return ("branch", build_tree(depth - 1), build_tree(depth - 1))


def sum_leaves(tree):
    if tree[0] == "leaf":
        return tree[1]
    return sum_leaves(tree[1]) + sum_leaves(tree[2])


print(sum_leaves(build_tree(int(sys.argv[1]))))

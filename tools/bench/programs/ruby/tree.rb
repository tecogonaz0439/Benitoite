def build_tree(depth)
  return [:leaf, 1] if depth == 0
  [:branch, build_tree(depth - 1), build_tree(depth - 1)]
end

def sum_leaves(tree)
  return tree[1] if tree[0] == :leaf
  sum_leaves(tree[1]) + sum_leaves(tree[2])
end

puts sum_leaves(build_tree(Integer(ARGV.fetch(0))))

local function build_tree(depth)
  if depth == 0 then
    return { "leaf", 1 }
  end
  return { "branch", build_tree(depth - 1), build_tree(depth - 1) }
end

local function sum_leaves(tree)
  if tree[1] == "leaf" then
    return tree[2]
  end
  return sum_leaves(tree[2]) + sum_leaves(tree[3])
end

print(sum_leaves(build_tree(tonumber(arg[1]))))

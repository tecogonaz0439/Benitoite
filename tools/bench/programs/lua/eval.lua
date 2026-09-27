local function build_expression(depth)
  if depth == 0 then
    return { "lit", 1 }
  end
  local smaller = build_expression(depth - 1)
  local branch = depth % 3
  if branch == 0 then
    return { "add", smaller, { "lit", depth } }
  elseif branch == 1 then
    return { "inc", smaller }
  else
    return { "scale", smaller, 1 }
  end
end

local function evaluate(expression)
  if expression[1] == "lit" then
    return expression[2]
  elseif expression[1] == "add" then
    return evaluate(expression[2]) + evaluate(expression[3])
  elseif expression[1] == "inc" then
    return evaluate(expression[2]) + 1
  else
    return evaluate(expression[2]) * expression[3]
  end
end

-- 式の深さは固定し、入力の回数だけ評価を繰り返す（Benitoite の版と同じ）。
local expression = build_expression(500)
local total = 0
for _ = 1, tonumber(arg[1]) do
  total = total + evaluate(expression)
end
print(total)

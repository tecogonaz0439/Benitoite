def build_expression(depth)
  return [:lit, 1] if depth == 0
  smaller = build_expression(depth - 1)
  case depth % 3
  when 0 then [:add, smaller, [:lit, depth]]
  when 1 then [:inc, smaller]
  else [:scale, smaller, 1]
  end
end

def evaluate(expression)
  case expression[0]
  when :lit then expression[1]
  when :add then evaluate(expression[1]) + evaluate(expression[2])
  when :inc then evaluate(expression[1]) + 1
  else evaluate(expression[1]) * expression[2]
  end
end

# 式の深さは固定し、入力の回数だけ評価を繰り返す（Benitoite の版と同じ）。
expression = build_expression(500)
total = 0
Integer(ARGV.fetch(0)).times { total += evaluate(expression) }
puts total

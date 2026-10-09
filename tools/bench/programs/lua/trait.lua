local Step = {}
function Step:step(value)
  return (value * 17 + 11) % 65521
end
local function repeat_step(step, count, value)
  for _ = 1, count do value = step:step(value) end
  return value
end
print(repeat_step(Step, tonumber(arg[1]), 1))

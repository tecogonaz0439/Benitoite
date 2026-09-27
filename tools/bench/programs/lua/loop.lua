local finish = tonumber(arg[1])
local current = 0
local total = 0
while current < finish do
  total = total + current
  current = current + 1
end
print(total)

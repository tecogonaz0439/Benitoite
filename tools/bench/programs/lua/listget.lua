local length, count = tonumber(arg[1]), tonumber(arg[2])
local values = {}
for i = 0, length - 1 do values[i + 1] = i end
local seed, total = 1, 0
for _ = 1, count do
  seed = (seed * 48271 + 11) % 2147483647
  total = total + values[(seed % length) + 1]
end
print(total)

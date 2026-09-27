local count = tonumber(arg[1])
local values = {}
for value = 0, count - 1 do
  values[#values + 1] = value
end

local mapped = {}
for _, value in ipairs(values) do
  mapped[#mapped + 1] = value * 3
end

local filtered = {}
for _, value in ipairs(mapped) do
  if value % 2 == 0 then
    filtered[#filtered + 1] = value
  end
end

local total = 0
for _, value in ipairs(filtered) do
  total = total + value
end
print(total)

local count = tonumber(arg[1])
local seed, keys = 1, {}
for index = 1, count do
  seed = (seed * 48271 + 11) % 2147483647
  keys[index] = seed
end
local m, s = {}, {}
for _, key in ipairs(keys) do m[key] = key end
for _, key in ipairs(keys) do s[key] = true end
local mapFound, setFound = 0, 0
for _, key in ipairs(keys) do if m[key] ~= nil then mapFound = mapFound + 1 end end
for _, key in ipairs(keys) do if s[key] then setFound = setFound + 1 end end
for index = 1, count, 2 do m[keys[index]], s[keys[index]] = nil, nil end
local mapSize, setSize = 0, 0
for _ in pairs(m) do mapSize = mapSize + 1 end
for _ in pairs(s) do setSize = setSize + 1 end
print(mapSize)
print(setSize)
print(mapFound)
print(setFound)

local source = assert(io.open(arg[1], "rb"))
local text = source:read("*a")
source:close()

local count = 0
if #text > 0 then
  for _ in string.gmatch(text, "[^\n]*\n") do
    count = count + 1
  end
  if string.sub(text, -1) ~= "\n" then
    count = count + 1
  end
end
print(count)

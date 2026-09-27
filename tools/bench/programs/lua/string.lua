local count = tonumber(arg[1])
local text = "start," .. string.rep("x,", count) .. "end"
local fields_count = 1
for _ in string.gmatch(text, ",") do
  fields_count = fields_count + 1
end
print(fields_count)

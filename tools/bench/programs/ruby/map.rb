count = ARGV[0].to_i
seed = 1
keys = Array.new(count) do
  seed = (seed * 48271 + 11) % 2147483647
end
m = {}
s = {}
keys.each { |key| m[key] = key }
keys.each { |key| s[key] = true }
map_found = keys.count { |key| !m[key].nil? }
set_found = keys.count { |key| s.key?(key) }
(0...count).step(2) do |index|
  m.delete(keys[index])
  s.delete(keys[index])
end
puts m.size, s.size, map_found, set_found

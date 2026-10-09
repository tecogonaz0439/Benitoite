import sys

count = int(sys.argv[1])
seed = 1
keys = []
for _ in range(count):
    seed = (seed * 48271 + 11) % 2147483647
    keys.append(seed)
m = {}
s = set()
for key in keys:
    m[key] = key
for key in keys:
    s.add(key)
map_found = sum(m.get(key) is not None for key in keys)
set_found = sum(key in s for key in keys)
for index in range(0, count, 2):
    m.pop(keys[index], None)
    s.discard(keys[index])
print(len(m), len(s), map_found, set_found, sep="\n")

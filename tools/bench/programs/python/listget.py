import sys
length, count = map(int, sys.argv[1:3])
values = list(range(length))
seed, total = 1, 0
for _ in range(count):
    seed = (seed * 48271 + 11) % 2147483647
    total += values[seed % length]
print(total)

import sys


end = int(sys.argv[1])
current = 0
total = 0
while current < end:
    total += current
    current += 1
print(total)

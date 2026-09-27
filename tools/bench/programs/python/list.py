import sys
from functools import reduce


count = int(sys.argv[1])
values = list(range(count))
mapped = list(map(lambda value: value * 3, values))
filtered = list(filter(lambda value: value % 2 == 0, mapped))
total = reduce(lambda accumulator, value: accumulator + value, filtered, 0)
print(total)

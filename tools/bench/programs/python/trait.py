import sys

class Step:
    def step(self, value):
        return (value * 17 + 11) % 65521

def repeat(step, count, value):
    for _ in range(count):
        value = step.step(value)
    return value

print(repeat(Step(), int(sys.argv[1]), 1))

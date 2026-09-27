import sys


count = int(sys.argv[1])
text = "start," + "x," * count + "end"
print(len(text.split(",")))

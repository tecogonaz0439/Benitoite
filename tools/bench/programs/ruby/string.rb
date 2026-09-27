count = Integer(ARGV.fetch(0))
text = "start," + "x," * count + "end"
puts text.split(",", -1).length

finish = Integer(ARGV.fetch(0))
current = 0
total = 0
while current < finish
  total += current
  current += 1
end
puts total

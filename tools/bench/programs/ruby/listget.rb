length, count = ARGV.take(2).map { |arg| Integer(arg) }
values = (0...length).to_a
seed, total = 1, 0
count.times do
  seed = (seed * 48271 + 11) % 2147483647
  total += values[seed % length]
end
puts total

count = Integer(ARGV.fetch(0))
values = (0...count).to_a
mapped = values.map { |value| value * 3 }
filtered = mapped.select { |value| value % 2 == 0 }
total = filtered.reduce(0) { |accumulator, value| accumulator + value }
puts total

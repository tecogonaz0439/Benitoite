text = File.read(ARGV.fetch(0), encoding: "UTF-8")
lines = text.split("\n", -1)
lines.pop if text.end_with?("\n")
puts text.empty? ? 0 : lines.length

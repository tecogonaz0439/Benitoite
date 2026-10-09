class Step
  def step(value)
    (value * 17 + 11) % 65521
  end
end

def repeat(step, count, value)
  count.times { value = step.step(value) }
  value
end
puts repeat(Step.new, Integer(ARGV[0]), 1)

trait Step {
    fn step(&self, value: i64) -> i64;
}
struct IntegerStep;
impl Step for IntegerStep {
    fn step(&self, value: i64) -> i64 { (value * 17 + 11) % 65521 }
}
#[inline(never)]
fn repeat(step: &dyn Step, count: i64, mut value: i64) -> i64 {
    for _ in 0..count { value = step.step(value); }
    value
}
fn main() {
    let count = std::env::args().nth(1).unwrap().parse().unwrap();
    let step: Box<dyn Step> = Box::new(IntegerStep);
    println!("{}", repeat(std::hint::black_box(step.as_ref()), count, 1));
}

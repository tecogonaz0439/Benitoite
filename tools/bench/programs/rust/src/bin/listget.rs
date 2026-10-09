fn main() {
    let mut args = std::env::args().skip(1);
    let length: usize = args.next().unwrap().parse().unwrap();
    let count: usize = args.next().unwrap().parse().unwrap();
    let values: Vec<i64> = (0..length).map(|n| n as i64).collect();
    let mut seed: usize = 1;
    let mut total: i64 = 0;
    for _ in 0..count {
        seed = (seed * 48271 + 11) % 2147483647;
        total += values[seed % length];
    }
    println!("{total}");
}

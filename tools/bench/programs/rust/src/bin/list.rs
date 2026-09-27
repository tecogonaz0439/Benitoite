use std::error::Error;

fn count_arg() -> Result<i64, Box<dyn Error>> {
    let raw = std::env::args().nth(1).ok_or("missing integer argument")?;
    let count = raw.parse::<i64>()?;
    if count < 0 {
        return Err("expected a non-negative integer".into());
    }
    Ok(count)
}

fn main() -> Result<(), Box<dyn Error>> {
    let count = count_arg()?;
    let values: Vec<i64> = (0..count).collect();
    let mapped: Vec<i64> = values.iter().map(|value| value * 3).collect();
    let filtered: Vec<i64> = mapped.into_iter().filter(|value| value % 2 == 0).collect();
    let total = filtered
        .into_iter()
        .fold(0, |accumulator, value| accumulator + value);
    println!("{total}");
    Ok(())
}

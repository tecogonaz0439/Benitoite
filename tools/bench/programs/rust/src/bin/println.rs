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
    for current in 0..count {
        println!("line {current}");
    }
    println!("done {count}");
    Ok(())
}

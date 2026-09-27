use std::error::Error;

fn count_arg() -> Result<i64, Box<dyn Error>> {
    let raw = std::env::args().nth(1).ok_or("missing integer argument")?;
    let count = raw.parse::<i64>()?;
    if count < 0 {
        return Err("expected a non-negative integer".into());
    }
    Ok(count)
}

fn fibonacci(n: i64) -> i64 {
    if n < 2 {
        n
    } else {
        fibonacci(n - 1) + fibonacci(n - 2)
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("{}", fibonacci(count_arg()?));
    Ok(())
}

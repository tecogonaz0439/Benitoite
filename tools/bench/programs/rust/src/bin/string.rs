use std::error::Error;

fn count_arg() -> Result<usize, Box<dyn Error>> {
    let raw = std::env::args().nth(1).ok_or("missing integer argument")?;
    Ok(raw.parse::<usize>()?)
}

fn main() -> Result<(), Box<dyn Error>> {
    let count = count_arg()?;
    let mut text = String::from("start,");
    text.push_str(&"x,".repeat(count));
    text.push_str("end");
    println!("{}", text.split(',').count());
    Ok(())
}

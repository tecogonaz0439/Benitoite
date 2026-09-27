use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let path = std::env::args()
        .nth(1)
        .ok_or("missing file path argument")?;
    let text = std::fs::read_to_string(path)?;
    println!("{}", text.lines().count());
    Ok(())
}

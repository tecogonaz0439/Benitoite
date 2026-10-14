//! 比較用の手書きゲストを再生成し、保存したバイナリとの一致を確かめる。

use std::{error::Error, fs, path::Path};

fn main() -> Result<(), Box<dyn Error>> {
    let arguments: Vec<_> = std::env::args().skip(1).collect();
    let check = match arguments.as_slice() {
        [] => false,
        [option] if option == "--check" => true,
        _ => return Err("usage: wit-transfer-fixtures [--check]".into()),
    };
    let directory = Path::new(env!("CARGO_MANIFEST_DIR")).join("../guests");
    let mut paths = fs::read_dir(directory)?
        .map(|entry| entry.map(|entry| entry.path()))
        .collect::<Result<Vec<_>, _>>()?;
    paths.sort();
    let mut count = 0;
    for source in paths {
        if source
            .extension()
            .is_some_and(|extension| extension == "wat")
        {
            let bytes = wat::parse_file(&source)?;
            let binary = source.with_extension("wasm");
            if check {
                if fs::read(&binary)? != bytes {
                    return Err(format!("fixture differs: {}", binary.display()).into());
                }
            } else {
                fs::write(binary, bytes)?;
            }
            count += 1;
        }
    }
    if count == 0 {
        return Err("no component sources found".into());
    }
    println!(
        "{count} component fixtures {}",
        if check { "verified" } else { "generated" }
    );
    Ok(())
}

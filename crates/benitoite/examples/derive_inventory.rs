//! 外部生成へ解決済みの宣言を version 1 の JSON で渡す（設計書 03-06「外部生成の宣言情報」）。
#[path = "derive_inventory/mod.rs"]
mod derive_inventory;

fn main() {
    let mut args = std::env::args().skip(1);
    let (mut root, mut config) = (None, None);
    while let Some(arg) = args.next() {
        let slot = match arg.as_str() {
            "--root" => &mut root,
            "--config" => &mut config,
            _ => usage(),
        };
        if slot.is_some() {
            usage();
        }
        *slot = Some(args.next().unwrap_or_else(|| usage()));
    }
    let (Some(root), Some(config)) = (root, config) else {
        usage()
    };
    let bytes = match std::fs::read(&config) {
        Ok(bytes) => bytes,
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    };
    let config = match derive_inventory::config::read(&bytes) {
        Ok(config) => config,
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(2);
        }
    };
    match derive_inventory::inventory(std::path::Path::new(&root), &config, &bytes) {
        Ok(value) => println!("{value}"),
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    }
}
fn usage() -> ! {
    eprintln!("{}", text::USAGE);
    std::process::exit(2)
}

mod text {
    pub const USAGE: &str = "usage: derive_inventory --root <dir> --config <path>";
}

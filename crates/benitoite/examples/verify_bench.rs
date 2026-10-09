//! 読み込みのときの検証だけを測り、比較する命令列の指紋を出す
//! （設計書 07-02「測る項目」、実装プラン R32）。

use std::path::Path;
use std::process::ExitCode;
use std::time::Instant;

use benitoite::bytecode::verify::verify;
use benitoite::pipeline::{self, CheckOptions};

fn main() -> ExitCode {
    match execute() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(2)
        }
    }
}

fn execute() -> Result<(), String> {
    let path = std::env::args().nth(1).ok_or(text::USAGE)?;
    let checked = pipeline::check_path(
        Path::new(&path),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    )
    .map_err(|e| format!("{e:?}"))?;
    let checked_program = checked
        .program
        .ok_or_else(|| format!("{:?}", checked.diagnostics))?;
    let core = pipeline::desugar_checked(&checked_program).map_err(|e| format!("{e:?}"))?;
    let compiled = pipeline::compile(&core, checked.sources).map_err(|e| format!("{e:?}"))?;
    // 指紋には原型の区切りと窓の大きさも含め、命令列の連結だけの一致にしない。
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    let mut instructions = 0_usize;
    for proto in &compiled.protos {
        let len = u64::try_from(proto.code.len()).map_err(|e| e.to_string())?;
        for byte in len
            .to_le_bytes()
            .into_iter()
            .chain(proto.num_regs.to_le_bytes())
            .chain(proto.num_params.to_le_bytes())
            .chain(proto.code.iter().flat_map(|i| i.0.to_le_bytes()))
        {
            hash = (hash ^ u64::from(byte)).wrapping_mul(0x100_0000_01b3);
        }
        instructions = instructions.saturating_add(proto.code.len());
    }
    println!("{}{hash:016x}", text::CODE_HASH);
    println!("{}{}", text::PROTOS, compiled.protos.len());
    println!("{}{instructions}", text::INSTRUCTIONS);
    for _ in 0..10 {
        let started = Instant::now();
        verify(std::hint::black_box(&compiled)).map_err(|e| format!("{e:?}"))?;
        println!("{}{}", text::VERIFY_NANOS, started.elapsed().as_nanos());
    }
    Ok(())
}

mod text {
    pub const USAGE: &str = "usage: verify_bench SCRIPT";
    pub const CODE_HASH: &str = "code_hash=";
    pub const PROTOS: &str = "prototypes=";
    pub const INSTRUCTIONS: &str = "instructions=";
    pub const VERIFY_NANOS: &str = "verify_nanos=";
}

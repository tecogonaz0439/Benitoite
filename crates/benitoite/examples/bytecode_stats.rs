//! スクリプトをコンパイルし、バイトコードの大きさを表示する開発用の道具。
//!
//! 性能の測定（設計書 07-02「測る項目」の命令の長さ）で、各ベンチマークのバイトコードの大きさを記録するために使う。
//! 使い方: `cargo run --release --example bytecode_stats -- <スクリプト>`
//! 出力は一行で、利用者のコード（利用者の関数とラムダ）と全体（prelude と値として使う組み込みの関数を含む）の
//! 原型の数・命令の数・定数の数を示す。1 命令は 8 バイトである（10-07「命令の形」）。

use std::path::Path;
use std::process::ExitCode;

use benitoite::bytecode::program::{CompiledProgram, ProtoOrigin};
use benitoite::pipeline::{check_path, compile, desugar_checked};

/// 原型の数・命令の数・定数の数。
#[derive(Default)]
struct Counts {
    protos: usize,
    instrs: usize,
    consts: usize,
}

impl Counts {
    fn add(&mut self, instrs: usize, consts: usize) {
        self.protos = self.protos.saturating_add(1);
        self.instrs = self.instrs.saturating_add(instrs);
        self.consts = self.consts.saturating_add(consts);
    }
}

fn count(program: &CompiledProgram) -> (Counts, Counts) {
    let mut user = Counts::default();
    let mut total = Counts::default();
    for proto in &program.protos {
        let instrs = proto.code.len();
        let consts = proto.consts.len();
        total.add(instrs, consts);
        match proto.origin {
            ProtoOrigin::UserFn | ProtoOrigin::UserLambda => user.add(instrs, consts),
            ProtoOrigin::PreludePublic | ProtoOrigin::PreludeHelper | ProtoOrigin::BuiltinValue => {
            }
        }
    }
    (user, total)
}

fn main() -> ExitCode {
    let mut args = std::env::args_os().skip(1);
    let (Some(path), None) = (args.next(), args.next()) else {
        eprintln!("usage: bytecode_stats <script>");
        return ExitCode::from(2);
    };
    let checked = check_path(Path::new(&path));
    let Some(program) = checked.program else {
        eprintln!(
            "the script has {} diagnostic(s); run `benitoite check` for details",
            checked.diagnostics.len()
        );
        return ExitCode::from(2);
    };
    let core = match desugar_checked(&program) {
        Ok(core) => core,
        Err(error) => {
            eprintln!("internal error while desugaring: {error:?}");
            return ExitCode::from(3);
        }
    };
    let compiled = match compile(&core, checked.sources) {
        Ok(compiled) => compiled,
        Err(error) => {
            eprintln!("compile error: {error:?}");
            return ExitCode::from(2);
        }
    };
    let (user, total) = count(&compiled);
    println!(
        "bytecode-stats user_protos={} user_instrs={} user_consts={} total_protos={} total_instrs={} total_consts={}",
        user.protos, user.instrs, user.consts, total.protos, total.instrs, total.consts
    );
    ExitCode::SUCCESS
}

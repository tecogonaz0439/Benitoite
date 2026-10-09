//! スクリプトをコンパイルし、バイトコードの大きさを表示する開発用の道具。
//!
//! 性能の測定（設計書 07-02「測る項目」の命令の長さ）で、各ベンチマークのバイトコードの大きさを記録するために使う。
//! 使い方: `cargo run --release --example bytecode_stats -- <スクリプト>`
//! 出力は一行で、利用者のコード（`ProtoOrigin` の `User` で始まる原型）と全体（prelude と値として使う組み込みの関数を含む）の
//! 原型の数・命令の数・定数の数を示す。1 命令は 8 バイトである（10-07「命令の形」）。

use std::path::Path;
use std::process::ExitCode;

use benitoite::bytecode::program::{CompiledProgram, ProtoOrigin};
use benitoite::pipeline::{CheckOptions, CompileError, check_path, compile, desugar_checked};

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
            ProtoOrigin::UserFn
            | ProtoOrigin::UserMethod
            | ProtoOrigin::UserLambda
            | ProtoOrigin::UserHandleBody
            | ProtoOrigin::UserHandleClause
            | ProtoOrigin::UserLazy => user.add(instrs, consts),
            ProtoOrigin::StdlibPublic | ProtoOrigin::StdlibHelper | ProtoOrigin::BuiltinValue => {}
        }
    }
    (user, total)
}

fn main() -> ExitCode {
    let mut args = std::env::args_os().skip(1);
    let (Some(path), None) = (args.next(), args.next()) else {
        eprintln!("{}", text::USAGE);
        return ExitCode::from(2);
    };
    let checked = match check_path(
        Path::new(&path),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    ) {
        Ok(checked) => checked,
        Err(error) => {
            eprintln!("{}: {error:?}", text::ENTRY_ERROR);
            return ExitCode::from(2);
        }
    };
    let Some(program) = checked.program else {
        eprintln!(
            "{} {} {}",
            text::DIAGNOSTICS_PREFIX,
            checked.diagnostics.len(),
            text::DIAGNOSTICS_SUFFIX
        );
        return ExitCode::from(2);
    };
    let core = match desugar_checked(&program) {
        Ok(core) => core,
        Err(error) => {
            eprintln!("{}: {error:?}", text::DESUGAR_ERROR);
            return ExitCode::from(3);
        }
    };
    let compiled = match compile(&core, checked.sources) {
        Ok(compiled) => compiled,
        Err(CompileError::Limit(diagnostics)) => {
            eprintln!("{}: {diagnostics:?}", text::COMPILE_ERROR);
            return ExitCode::from(2);
        }
        Err(CompileError::Internal(error)) => {
            eprintln!("{}: {error:?}", text::COMPILE_ERROR);
            return ExitCode::from(3);
        }
    };
    let (user, total) = count(&compiled);
    println!(
        "{} user_protos={} user_instrs={} user_consts={} total_protos={} total_instrs={} total_consts={}",
        text::STATS_PREFIX,
        user.protos,
        user.instrs,
        user.consts,
        total.protos,
        total.instrs,
        total.consts
    );
    ExitCode::SUCCESS
}

mod text {
    pub const USAGE: &str = "usage: bytecode_stats <script>";
    pub const ENTRY_ERROR: &str = "cannot select the entry file";
    pub const DIAGNOSTICS_PREFIX: &str = "the script has";
    pub const DIAGNOSTICS_SUFFIX: &str = "diagnostic(s); run `benitoite check` for details";
    pub const DESUGAR_ERROR: &str = "internal error while desugaring";
    pub const COMPILE_ERROR: &str = "compile error";
    pub const STATS_PREFIX: &str = "bytecode-stats";
}

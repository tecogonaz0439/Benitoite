//! スクリプトをコンパイルし、バイトコードを逆アセンブルして表示する開発用の道具。
//!
//! 設計者が処理系を読んで学ぶとき（実装プラン 90「学習のための読み方」）に、小さなスクリプトが
//! どの命令になるかを確かめるために使う。
//! 使い方: `cargo run --example disasm -- [--all] <スクリプト>`
//! 出力は `bytecode::disasm::disassemble` の形式である（形式はテストで比べない。10-07）。prelude の原型は
//! 数百行になり、利用者の関数を探しにくいので、既定では利用者のコードの原型だけを示す。
//! `--all` を付けると、prelude と値として使う組み込みの関数の原型も示す。

use std::path::Path;
use std::process::ExitCode;

use benitoite::bytecode::disasm::disassemble;
use benitoite::bytecode::program::{CompiledProgram, ProtoOrigin};
use benitoite::pipeline::{CheckOptions, CompileError, check_path, compile, desugar_checked};

fn main() -> ExitCode {
    let mut args: Vec<_> = std::env::args_os().skip(1).collect();
    let all = args.first().is_some_and(|a| a == "--all");
    if all {
        args.remove(0);
    }
    let [path] = args.as_slice() else {
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
    let text = disassemble(&compiled);
    if all {
        print!("{text}");
    } else {
        print!("{}", user_protos_only(&text, &compiled));
    }
    ExitCode::SUCCESS
}

// 原型を消して逆アセンブルすると原型番号が変わるので、元の番号のまま出力を選ぶ。
// 出所は表示名から推測せず、コンパイル済みの表を引く（実装プラン C18「手順の要点」）。
fn user_protos_only(disassembly: &str, program: &CompiledProgram) -> String {
    let mut out = String::new();
    let mut show = false;
    for line in disassembly.lines() {
        if let Some(header) = line.strip_prefix(text::PROTOTYPE_PREFIX) {
            show = header
                .split_whitespace()
                .next()
                .and_then(|index| index.parse::<usize>().ok())
                .and_then(|index| program.protos.get(index))
                .is_some_and(|proto| match proto.origin {
                    ProtoOrigin::UserFn
                    | ProtoOrigin::UserMethod
                    | ProtoOrigin::UserLambda
                    | ProtoOrigin::UserHandleBody
                    | ProtoOrigin::UserHandleClause
                    | ProtoOrigin::UserLazy => true,
                    ProtoOrigin::StdlibPublic
                    | ProtoOrigin::StdlibHelper
                    | ProtoOrigin::BuiltinValue => false,
                });
        } else if !line.starts_with(' ') {
            show = false;
        }
        if show {
            out.push_str(line);
            out.push('\n');
        }
    }
    out
}

mod text {
    pub const USAGE: &str = "usage: disasm [--all] <script>";
    pub const ENTRY_ERROR: &str = "cannot select the entry file";
    pub const DIAGNOSTICS_PREFIX: &str = "the script has";
    pub const DIAGNOSTICS_SUFFIX: &str = "diagnostic(s); run `benitoite check` for details";
    pub const DESUGAR_ERROR: &str = "internal error while desugaring";
    pub const COMPILE_ERROR: &str = "compile error";
    pub const PROTOTYPE_PREFIX: &str = "prototype ";
}

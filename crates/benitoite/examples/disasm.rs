//! スクリプトをコンパイルし、バイトコードを逆アセンブルして表示する開発用の道具。
//!
//! 設計者が処理系を読んで学ぶとき（実装プラン 90「学習のための読み方」）に、小さなスクリプトが
//! どの命令になるかを確かめるために使う。
//! 使い方: `cargo run --example disasm -- [--all] <スクリプト>`
//! 出力は `bytecode::disasm::disassemble` の形式である（形式はテストで比べない。10-07）。prelude の原型は
//! 数百行になり、利用者の関数を探しにくいので、既定では利用者の関数とラムダの原型だけを示す。
//! `--all` を付けると、prelude と値として使う組み込みの関数の原型も示す。

use std::path::Path;
use std::process::ExitCode;

use benitoite::bytecode::disasm::disassemble;
use benitoite::pipeline::{check_path, compile, desugar_checked};

fn main() -> ExitCode {
    let mut args: Vec<_> = std::env::args_os().skip(1).collect();
    let all = args.first().is_some_and(|a| a == "--all");
    if all {
        args.remove(0);
    }
    let [path] = args.as_slice() else {
        eprintln!("usage: disasm [--all] <script>");
        return ExitCode::from(2);
    };
    let checked = check_path(Path::new(path));
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
    let text = disassemble(&compiled);
    if all {
        print!("{text}");
    } else {
        print!("{}", user_protos_only(&text));
    }
    ExitCode::SUCCESS
}

/// 逆アセンブルの結果から、利用者の関数とラムダの原型だけを残す。
/// 逆アセンブラは、先頭のプログラムの概要と原型ごとのまとまりを空行で区切り、原型の見出しの行に
/// 原型の出所（`ProtoOrigin`）を括弧で書く。その形に頼って選ぶ（開発用の道具なので、形が変わったら合わせる）。
fn user_protos_only(text: &str) -> String {
    let mut blocks = text.split("\n\n");
    let mut out = String::new();
    if let Some(summary) = blocks.next() {
        out.push_str(summary);
        out.push('\n');
    }
    for block in blocks {
        let header = block.lines().next().unwrap_or_default();
        if header.contains("(UserFn)") || header.contains("(UserLambda)") {
            out.push('\n');
            out.push_str(block);
            if !block.ends_with('\n') {
                out.push('\n');
            }
        }
    }
    out
}

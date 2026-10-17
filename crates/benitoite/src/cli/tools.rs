//! CLI の補助のコマンド（設計書 06-01「サブコマンドの振る舞い」）。

//! `test`・`fmt`・`skill`・`package` と `--licenses` の入口。

use std::ffi::OsString;

use super::{CliEnv, DiagFormat, ToolCommand};

/// `benitoite test|fmt|skill|package` の後の引数を解釈して実行し、終了状態を返す（06-01 の「`test` のコマンドライン」
/// 「`fmt` のコマンドライン」「`skill` のコマンドライン」「`package` のコマンドライン」の終了状態）。
pub fn run_tool(tool: ToolCommand, args: Vec<OsString>, env: CliEnv) -> u8 {
    match tool {
        ToolCommand::Test => match args::parse_test_invocation(args) {
            Ok((parsed, _)) if parsed.report.is_some() => {
                test_runner::run_test_command(parsed, env)
            }
            Ok((parsed, _)) if parsed.check => run_body(
                test_runner::text::STAGE_TEST,
                parsed.diagnostics,
                env,
                |env| test_runner::run_test_command(parsed, env),
            ),
            Ok((parsed, wasm)) => {
                let execution = wasm.execution();
                let stderr = env.stderr.clone();
                let code = run_body(
                    test_runner::text::STAGE_TEST,
                    parsed.diagnostics,
                    env,
                    |env| test_runner::run_test_with_externals(parsed, env, execution.clone()),
                );
                wasm.report(&execution, &stderr);
                code
            }
            Err(error) if error.report.is_some() => {
                test_runner::check_usage_error(&env, &error.paths, &error.detail)
            }
            Err(error) => super::usage_error(&env, &error.detail),
        },
        ToolCommand::Fmt => match args::parse_path_args(args::PathTool::Fmt, args) {
            Ok(parsed) => run_body(formatter::text::STAGE_FMT, parsed.diagnostics, env, |env| {
                formatter::run_fmt(parsed, env)
            }),
            Err(detail) => super::usage_error(&env, &detail),
        },
        ToolCommand::Package => match package::parse_args(args) {
            Ok(parsed) => run_body(
                package::text::STAGE_PACKAGE,
                parsed.diagnostics,
                env,
                |env| package::run(parsed, env),
            ),
            Err(detail) => super::usage_error(&env, &detail),
        },
        ToolCommand::Skill => run_body(skill::text::STAGE_SKILL, DiagFormat::Text, env, |env| {
            skill::run_skill_cli(args, env)
        }),
    }
}

fn run_body(stage: &str, format: DiagFormat, env: CliEnv, body: impl FnOnce(CliEnv) -> u8) -> u8 {
    // 本体が環境を所有するため、巻き戻しの後の報告に要る出力先と色だけを残す
    // （設計書 02-09「panic 境界」）。既存のファイルごとの境界は本体の中に残る。
    let stderr = env.stderr.clone();
    let color = env.color;
    match crate::runtime::panic::catch(|| {
        if env.dev_panic == super::DevPanic::Tool {
            super::development_tool_panic();
        }
        body(env)
    }) {
        Ok(code) => code,
        Err(panic) => super::write_tool_panic(&stderr, color, format, stage, &panic),
    }
}

/// 埋め込んだ第三者のライセンスを `env.stdout` に書き、終了状態を返す（06-01「コマンドラインの形」）。
pub fn print_licenses(env: &CliEnv) -> u8 {
    let mut out = String::from(licenses::text::OWN_LICENSE);
    // リリースのスクリプトを通さないビルドは一覧を持たないことを伝える（05-01「ライセンスの表示」）
    match licenses::third_party_licenses() {
        Some(bundled) => {
            out.push_str(licenses::text::THIRD_PARTY_HEADER);
            out.push_str(bundled);
        }
        None => out.push_str(licenses::text::NOT_BUNDLED),
    }
    super::write_plain(&env.stdout, &out)
}

pub mod args;
pub mod formatter;

pub mod test_runner;

pub mod licenses;
pub mod skill;

mod package;

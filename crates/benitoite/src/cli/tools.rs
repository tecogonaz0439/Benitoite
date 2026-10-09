//! 中身は作業で書く（10-interfaces の sig=src/cli/tools.rs を参照）。

//! U4 のサブコマンド（`test`・`fmt`・`skill`）と `--licenses` の入口（設計書 06-01）。中身は U4 の作業が書く。

use std::ffi::OsString;

use super::{CliEnv, ToolCommand};

/// `benitoite test|fmt|skill` の後の引数を解釈して実行し、終了状態を返す（06-01 の「`test` のコマンドライン」
/// 「`fmt` のコマンドライン」「`skill` のコマンドライン」の終了状態）。
pub fn run_tool(tool: ToolCommand, args: Vec<OsString>, env: CliEnv) -> u8 {
    match tool {
        ToolCommand::Test => match args::parse_path_args(ToolCommand::Test, args) {
            Ok(parsed) => test_runner::run_test_command(parsed, env),
            Err(detail) => super::usage_error(&env, &detail),
        },
        ToolCommand::Fmt => match args::parse_path_args(ToolCommand::Fmt, args) {
            Ok(parsed) => formatter::run_fmt(parsed, env),
            Err(detail) => super::usage_error(&env, &detail),
        },
        ToolCommand::Skill => {
            // ホームは環境変数 `HOME` から求めて渡す（10-19「`skill install`・`uninstall`」）
            let home = std::env::var_os("HOME")
                .filter(|home| !home.is_empty())
                .map(std::path::PathBuf::from);
            skill::run_skill(args, env, home)
        }
    }
}

/// 埋め込んだ第三者のライセンスを `env.stdout` に書き、終了状態を返す（06-01「コマンドラインの形」、ADR 0235）。
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

//! プログラムの実行の流れ（設計書 02-09「プログラムの実行の流れ」、06-01「終了状態」）。
//!
//! 引数の検査、IO 実行器による `main` の実行、出力のバッファの書き出し、終わり方に応じた報告と終了状態を扱う。
//! 報告を標準エラー出力に書くのは呼び出し側（CLI、テストの実行器）である。

use std::ffi::OsString;

use super::executor::{ExecEnd, ExecOptions, execute};
use super::heap::AllocStats;
use super::io::IoHandlers;
use super::report::{internal_diagnostic, stop_diagnostic};
use super::value::Value;
use super::{RuntimeError, Stop, Stream};
use crate::bytecode::program::{CompiledProgram, MainKind};
use crate::diag::codes::{fill_template, text as diag_text};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::vm::StopInfo;

/// 報告に埋める値の文（ADR 0033）。
mod text {
    /// `FLUSH_FAILED_NOTE` の `{stream}` に埋める出力の呼び名
    pub const STDOUT_NAME: &str = "standard output";
    pub const STDERR_NAME: &str = "standard error";
}

/// `main` の結果の形が型と合わないとき（処理系の不具合）の説明。
/// 不具合を調べるための文なので `text` に置かない（00-02「文言」）。
const BAD_MAIN_RESULT: &str = "main returned a value of an unexpected shape";

/// 終了状態（ADR 0037、06-01「終了状態」）。
const EXIT_OK: u8 = 0;
const EXIT_FAILURE: u8 = 1;
const EXIT_INTERNAL: u8 = 3;

/// prelude の `Result` の構成子のタグ。
const RESULT_OK: u32 = 0;
const RESULT_ERR: u32 = 1;

/// プログラムの実行の流れの結果（02-09「プログラムの実行の流れ」）。
/// 出力のバッファの書き出しは `run_with` の中で済ませてある。呼び出し側（CLI）は、
/// `main_error` があればその文字列と改行を、続けて `reports` を、この順に標準エラー出力に書き、`exit_code` で終わる。
#[derive(Debug)]
pub struct RunEnd {
    pub exit_code: u8,
    /// `main` が返した `Err` の文字列
    pub main_error: Option<String>,
    /// 実行時エラー・資源の不足・処理系の不具合の報告
    pub reports: Vec<Diagnostic>,
    /// 実行を終えたときの確保の統計（`execute` の二つ目の戻り値。CLI の `BENITOITE_DEV_ALLOC_STATS` が使う）
    pub alloc: AllocStats,
}

/// 02-09「プログラムの実行の流れ」の手順 1。コマンドライン引数が正しい UTF-8 でなければ、
/// 最初に見つけた引数の位置（1 から数える）を示す R0301 の報告を返す。呼び出し側は終了状態 1 で終える。
pub fn check_args(args: Vec<OsString>) -> Result<Vec<String>, Box<Diagnostic>> {
    let mut out = Vec::with_capacity(args.len());
    for (i, a) in args.into_iter().enumerate() {
        match a.into_string() {
            Ok(s) => out.push(s),
            Err(_) => {
                let index = i.saturating_add(1);
                return Err(Box::new(
                    DiagBuilder::new(DiagCode::R0301)
                        .arg("index", index.to_string())
                        .build(),
                ));
            }
        }
    }
    Ok(out)
}

/// 終わり方の分類。書き出しの失敗の扱いを決める（02-09 の四つの場合）。
enum Outcome {
    /// `main` が `()`・`Ok(())`・`Err(msg)` を返した
    Returned,
    /// 実行時エラーか資源の不足で止まった
    Stopped,
    /// 処理系の不具合
    Internal,
}

/// 02-09「プログラムの実行の流れ」の手順 3〜5。`io` は、手順 2 で作ったハンドラ表
/// （CLI は `RealIo`、ゴールデンテストは `TestIo`）。手順 4 の書き出しは `io.flush_all()` で行う。
pub fn run_with(program: &CompiledProgram, io: &mut dyn IoHandlers, opts: ExecOptions) -> RunEnd {
    let (end, alloc) = execute(program, io, opts);
    // 処理系の不具合でも、報告の前に出力のバッファを書き出す（02-09「panic 境界」）。
    let failures = io.flush_all();

    let mut main_error = None;
    let mut reports = Vec::new();
    let outcome = match end {
        ExecEnd::Returned(v) => match main_result(program.main_kind, &v) {
            Some(err) => {
                main_error = err;
                Outcome::Returned
            }
            None => {
                reports.push(internal_diagnostic("run", BAD_MAIN_RESULT, None));
                Outcome::Internal
            }
        },
        ExecEnd::Stopped(info) => {
            reports.push(stop_diagnostic(program, &info));
            if matches!(info.stop, Stop::Internal(_)) {
                Outcome::Internal
            } else {
                Outcome::Stopped
            }
        }
        ExecEnd::Panicked(p) => {
            reports.push(internal_diagnostic("run", "", Some(&p)));
            Outcome::Internal
        }
    };

    let exit_code = match outcome {
        Outcome::Internal => EXIT_INTERNAL,
        _ if main_error.is_some() || !failures.is_empty() => EXIT_FAILURE,
        Outcome::Stopped => EXIT_FAILURE,
        Outcome::Returned => EXIT_OK,
    };
    match outcome {
        // 書き込みの失敗の報告を新たに加える（`Err(msg)` の `main_error` は残す）。
        Outcome::Returned => {
            for (stream, reason) in failures {
                reports.push(write_failed(program, stream, reason));
            }
        }
        // 先の報告に注記として加える。末尾呼び出しの注記が最後に残るよう、その直前に入れる。
        Outcome::Stopped => {
            if let Some(report) = reports.last_mut() {
                for (stream, reason) in failures {
                    add_flush_note(report, stream, reason);
                }
            }
        }
        // 処理系の不具合の報告だけを書く。
        Outcome::Internal => {}
    }

    RunEnd {
        exit_code,
        main_error,
        reports,
        alloc,
    }
}

/// `main` の結果を調べる。形が型と合えば `Some(Err の文字列)`、合わなければ `None`。
fn main_result(kind: MainKind, v: &Value) -> Option<Option<String>> {
    match kind {
        MainKind::Unit => matches!(v, Value::Unit).then_some(None),
        MainKind::Result => match v.as_ctor()? {
            (RESULT_OK, [Value::Unit]) => Some(None),
            (RESULT_ERR, [msg]) => Some(Some(msg.as_str()?.to_owned())),
            _ => None,
        },
    }
}

fn write_failed(program: &CompiledProgram, stream: Stream, reason: String) -> Diagnostic {
    let info = StopInfo {
        stop: Stop::Runtime(RuntimeError::WriteFailed { stream, reason }),
        at: None,
        frames: Vec::new(),
    };
    stop_diagnostic(program, &info)
}

fn add_flush_note(report: &mut Diagnostic, stream: Stream, reason: String) {
    let name = match stream {
        Stream::Stdout => text::STDOUT_NAME,
        Stream::Stderr => text::STDERR_NAME,
    };
    let note = fill_template(
        diag_text::FLUSH_FAILED_NOTE,
        &[("stream", String::from(name)), ("reason", reason)],
    );
    let at = if report.notes.last().map(String::as_str) == Some(diag_text::TRACE_TAIL_NOTE) {
        report.notes.len().saturating_sub(1)
    } else {
        report.notes.len()
    };
    report.notes.insert(at, note);
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    // 手で組んだプログラムを `run_with` で実行し、終わり方と終了状態、書き出しの失敗の扱いを確かめる（02-09）。
    use std::collections::BTreeMap;
    use std::sync::Arc;

    use super::{check_args, run_with};
    use crate::base::SourceTable;
    use crate::builtins::BuiltinId;
    use crate::bytecode::instr::{Instr, Opcode};
    use crate::bytecode::program::{
        CompiledProgram, ConstDesc, CtorInfo, MainKind, Proto, ProtoIdx, ProtoOrigin,
    };
    use crate::diag::DiagCode;
    use crate::diag::codes::text;
    use crate::runtime::executor::{ExecMode, ExecOptions};
    use crate::runtime::real_io::RealIo;
    use crate::runtime::real_io::tests::{BrokenSink, SharedSink};
    use crate::runtime::test_io::TestIo;
    use crate::vm::DEFAULT_MAX_CALL_STACK;

    #[derive(Clone, Copy)]
    enum Ending {
        Unit,
        Ok,
        Err,
        DivZero,
        /// 表にない命令で止まる（処理系の不具合）
        Internal,
    }

    /// `Console.println("hi")` の後、`ending` に応じて `()`・`Err("bad")` を返すか 0 で割る `main`。
    fn program(ending: Ending) -> CompiledProgram {
        let mut code = vec![
            Instr::abx(Opcode::LoadK, 0, 0),
            Instr::abc(Opcode::Io, 1, 0, 0),
        ];
        let mut consts = vec![ConstDesc::Str(String::from("hi"))];
        let main_kind = match ending {
            Ending::Unit => {
                code.push(Instr::abc(Opcode::Return, 1, 0, 0));
                MainKind::Unit
            }
            Ending::Ok => {
                code.push(Instr::abc(Opcode::Con, 1, 0, 1));
                code.push(Instr::abc(Opcode::Return, 1, 0, 0));
                MainKind::Result
            }
            Ending::Internal => {
                code.push(Instr(0xff));
                MainKind::Unit
            }
            Ending::Err => {
                consts.push(ConstDesc::Str(String::from("bad")));
                code.push(Instr::abx(Opcode::LoadK, 0, 1));
                code.push(Instr::abc(Opcode::Con, 1, 1, 0));
                code.push(Instr::abc(Opcode::Return, 1, 0, 0));
                MainKind::Result
            }
            Ending::DivZero => {
                consts.push(ConstDesc::Int(1));
                consts.push(ConstDesc::Int(0));
                code.push(Instr::abx(Opcode::LoadK, 0, 1));
                code.push(Instr::abx(Opcode::LoadK, 1, 2));
                code.push(Instr::abc(Opcode::DivI, 0, 0, 1));
                code.push(Instr::abc(Opcode::Return, 0, 0, 0));
                MainKind::Unit
            }
        };
        let positions = vec![None; code.len()];
        let main = Proto {
            name: String::from("main"),
            origin: ProtoOrigin::UserFn,
            lambda_span: None,
            code,
            consts,
            switch_tables: Vec::new(),
            num_regs: 2,
            num_params: 0,
            captures: Vec::new(),
            positions,
        };
        let ctor = |name: &str, tag| CtorInfo {
            type_name: String::from("Result"),
            ctor_name: String::from(name),
            tag,
            arity: 1,
        };
        CompiledProgram {
            protos: vec![main],
            top_fns: Vec::new(),
            ctors: vec![ctor("Ok", 0), ctor("Err", 1)],
            builtins: vec![BuiltinId::ConsolePrintln],
            main: ProtoIdx(0),
            main_kind,
            sources: Arc::new(SourceTable::new()),
        }
    }

    fn opts(mode: ExecMode) -> ExecOptions {
        ExecOptions {
            mode,
            max_call_stack_bytes: DEFAULT_MAX_CALL_STACK,
        }
    }

    #[test]
    fn endings_map_to_exit_codes_in_both_modes() {
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let end = run_with(&program(Ending::Unit), &mut io, opts(mode));
            assert_eq!(
                (end.exit_code, end.main_error, end.reports.len()),
                (0, None, 0)
            );
            assert_eq!(io.stdout, "hi\n");

            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let end = run_with(&program(Ending::Ok), &mut io, opts(mode));
            assert_eq!(
                (end.exit_code, end.main_error, end.reports.len()),
                (0, None, 0)
            );

            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let end = run_with(&program(Ending::Err), &mut io, opts(mode));
            assert_eq!(end.exit_code, 1);
            assert_eq!(end.main_error.as_deref(), Some("bad"));
            assert!(end.reports.is_empty());

            let mut io = TestIo::new(Vec::new(), BTreeMap::new());
            let end = run_with(&program(Ending::DivZero), &mut io, opts(mode));
            assert_eq!(end.exit_code, 1);
            assert_eq!(end.reports.len(), 1);
            assert_eq!(end.reports[0].code, Some(DiagCode::R0101));
        }
    }

    fn broken_stdout() -> RealIo {
        RealIo::with_sinks(
            Vec::new(),
            Box::new(BrokenSink),
            Box::new(SharedSink::default()),
        )
    }

    #[test]
    fn flush_failure_after_main_returns_adds_a_write_failure_report() {
        for ending in [Ending::Unit, Ending::Err] {
            let mut io = broken_stdout();
            let end = run_with(&program(ending), &mut io, opts(ExecMode::Direct));
            assert_eq!(end.exit_code, 1);
            assert_eq!(end.reports.len(), 1);
            assert_eq!(end.reports[0].code, Some(DiagCode::R0201));
            let expected = matches!(ending, Ending::Err).then(|| String::from("bad"));
            assert_eq!(end.main_error, expected);
        }
    }

    #[test]
    fn flush_failure_after_a_runtime_error_becomes_a_note() {
        let mut io = broken_stdout();
        let end = run_with(&program(Ending::DivZero), &mut io, opts(ExecMode::Direct));
        assert_eq!(end.exit_code, 1);
        assert_eq!(end.reports.len(), 1);
        let report = &end.reports[0];
        assert_eq!(report.code, Some(DiagCode::R0101));
        let n = report.notes.len();
        assert!(
            report.notes[n - 2].starts_with("also failed to write to standard output: "),
            "{:?}",
            report.notes
        );
        assert_eq!(report.notes[n - 1], text::TRACE_TAIL_NOTE);
    }

    #[test]
    fn flush_failure_after_an_internal_error_is_not_reported() {
        // 処理系の不具合の報告だけを書き、終了状態 3 で終える（02-09「プログラムの実行の流れ」）。
        let mut io = broken_stdout();
        let end = run_with(&program(Ending::Internal), &mut io, opts(ExecMode::Direct));
        assert_eq!(end.exit_code, 3);
        assert_eq!(end.reports.len(), 1);
        assert_eq!(end.reports[0].kind, crate::diag::ReportKind::Internal);
        assert!(
            !end.reports[0]
                .notes
                .iter()
                .any(|n| n.starts_with("also failed to write"))
        );
    }

    #[cfg(unix)]
    #[test]
    fn invalid_utf8_argument_is_reported_with_its_position() {
        use std::ffi::OsString;
        use std::os::unix::ffi::OsStringExt;

        let ok = check_args(vec![OsString::from("a"), OsString::from("b")]).unwrap();
        assert_eq!(ok, vec![String::from("a"), String::from("b")]);
        let d = check_args(vec![
            OsString::from("a"),
            OsString::from_vec(vec![0xff]),
            OsString::from_vec(vec![0xfe]),
        ])
        .unwrap_err();
        assert_eq!(d.code, Some(DiagCode::R0301));
        assert_eq!(d.message, "command-line argument 2 is not valid UTF-8");
    }
}

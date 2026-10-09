//! Process の組み込みの操作（設計書 03-07「Process」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::iface::{IoCtx, IoReply, IoWait, Lend, WorkerWait};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::CheckedLen;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::Value;
use crate::runtime::io::services::ProcessStdio;
use std::io::{self, Read, Write};
use std::os::unix::process::ExitStatusExt;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus, Stdio};

builtin! {
    /// `Benitoite.IO.Process.arguments` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Benitoite.IO.Process.arguments",
    io fn arguments(ctx) -> IoReply<'e> {
        let mut ctx = ctx;
        // 環境の文字列を確保する前に、リストと全要素の上限を確かめる（設計書 02-09）。
        let args = ctx.services().arguments();
        CheckedLen::elements(super::count(args.len())?, "Benitoite.IO.Process.arguments")?;
        for arg in args {
            CheckedLen::bytes(super::count(arg.len())?, "Benitoite.IO.Process.arguments")?;
        }
        let args = args.to_vec();
        let mut items = Vec::with_capacity(args.len());
        for arg in args {
            items.push(ctx.alloc_str(&arg, "Benitoite.IO.Process.arguments")?);
        }
        Ok(IoReply::Done(crate::runtime::list::from_values(
            &ctx,
            &items,
            "Benitoite.IO.Process.arguments",
        )?))
    }
}

builtin! {
    /// `Benitoite.IO.Process.exit` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Benitoite.IO.Process.exit",
    io fn exit(ctx, code: i64) -> IoReply<'e> {
        let _ = ctx;
        let code = u8::try_from(code).map_err(|_| Stop::Runtime(
            crate::runtime::RuntimeError::ArgumentOutOfDomain {
                function: "Benitoite.IO.Process.exit",
                argument: 0,
            },
        ))?;
        Ok(IoReply::Exit(crate::builtins::iface::ExitStatus(code)))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[arguments::DECL, exit::DECL];

#[cfg(test)]
mod external_tests;
#[cfg(test)]
mod tests;

builtin! {
    /// `Benitoite.IO.Process.scriptDirectory` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Process.scriptDirectory",
    io fn script_directory(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let path = ctx.services().script_directory().to_str()
            .ok_or_else(|| Stop::Internal("script directory is not UTF-8".into()))?.to_owned();
        Ok(IoReply::Done(ctx.alloc_str(&path, "Benitoite.IO.Process.scriptDirectory")?))
    }
}

builtin! {
    /// `Benitoite.IO.Process.environmentVariable` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Process.environmentVariable",
    io fn environment_variable(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        const FUNCTION: &str = "Benitoite.IO.Process.environmentVariable";
        let name = ctx.str(arg0).ok_or_else(|| Stop::Internal("environment variable name is not String".into()))?;
        if name.is_empty() || name.contains(['\0', '=']) {
            return Ok(IoReply::Done(super::file::result_error(&ctx,
                std::io::Error::new(std::io::ErrorKind::InvalidInput, text::INVALID_NAME).into(), FUNCTION)?));
        }
        let name = name.to_owned();
        let value = ctx.services().environment_variable(&name);
        let value = match value {
            Some(value) => match ctx.alloc_str_utf8(value.as_encoded_bytes(), FUNCTION)? {
                Some(value) => Some(value),
                None => return Ok(IoReply::Done(super::file::result_error(&ctx,
                    std::io::Error::new(std::io::ErrorKind::InvalidData, text::INVALID_UTF8).into(), FUNCTION)?)),
            },
            None => None,
        };
        let value = super::option(&ctx, value)?;
        Ok(IoReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])?))
    }
}

builtin! {
    /// `Benitoite.IO.Process.workingDirectory` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Process.workingDirectory",
    io fn working_directory(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        const FUNCTION: &str = "Benitoite.IO.Process.workingDirectory";
        let path = ctx.services().working_directory().as_os_str().as_encoded_bytes().to_vec();
        let value = match ctx.alloc_str_utf8(&path, FUNCTION)? {
            Some(value) => ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])?,
            None => super::file::result_error(&ctx,
                std::io::Error::new(std::io::ErrorKind::InvalidData, text::INVALID_UTF8).into(), FUNCTION)?,
        };
        Ok(IoReply::Done(value))
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const ENVIRONMENT_DECLS: &[BuiltinDecl] = &[
    script_directory::DECL,
    environment_variable::DECL,
    working_directory::DECL,
];

mod text {
    pub const INVALID_NAME: &str = "environment variable name is empty or contains NUL or '='";
    pub const INVALID_UTF8: &str = "environment value or directory is not valid UTF-8";
    pub const INVALID_COMMAND: &str = "program, arguments, or environment contain invalid input";
    pub const INVALID_OUTPUT: &str = "command output is not valid UTF-8";
}

builtin! {
    /// `Benitoite.IO.Process.run` の本体（設計書 03-07「Process」）。
    /// 子の終わりまで作業用のスレッドを一本占める。最大 64 本が埋まるとほかの仕事も待つ。
    /// 取り消しと中断の要求でも子を終わらせない（設計書 02-09「タスクの待ちと取り消し」）。
    name = "Benitoite.IO.Process.run",
    io fn run(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let command = read_command(&mut ctx, arg0)?;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing, move |_| execute(command, ProcessStdio::default()), run_done,
        ))))
    }
}

builtin! {
    /// `Benitoite.IO.Process.runAttached` の本体（設計書 03-07「Process」）。
    /// `input: Option.Some` は標準入力の継承と空の入力より優先する（ADR 0322 の決定 5）。
    /// 出力のつなぎ先は `input` によらず実行の環境で決める。
    /// 子の終わりまで作業用のスレッドを一本占める。最大 64 本が埋まるとほかの仕事も待つ。
    /// 取り消しと中断の要求でも子を終わらせない（設計書 02-09「タスクの待ちと取り消し」）。
    name = "Benitoite.IO.Process.runAttached",
    io fn run_attached(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let command = read_command(&mut ctx, arg0)?;
        let stdio = ctx.services().runtime_view()
            .ok_or_else(|| Stop::Internal("Process.runAttached requires runtime view".into()))?
            .rt.process_stdio;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing, move |_| execute(command, stdio), attached_done,
        ).after_output_flush())))
    }
}

builtin! {
    /// `Benitoite.IO.Process.shell` の本体（設計書 03-07「外部コマンドの起動とシェル」、ADR 0243）。
    /// 子の終わりまで作業用のスレッドを一本占める。最大 64 本が埋まるとほかの仕事も待つ。
    /// 取り消しと中断の要求でも子を終わらせない（設計書 02-09「タスクの待ちと取り消し」）。
    name = "Benitoite.IO.Process.shell",
    io fn shell(ctx, arg0: Value<'e>) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let command_line = string(&ctx, arg0)?;
        let command = OwnedCommand {
            program: "/bin/sh".into(),
            arguments: vec!["-c".into(), command_line],
            directory: ctx.services().working_directory().to_owned(),
            environment: Vec::new(),
            input: None,
        };
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Nothing, move |_| execute(command, ProcessStdio::default()), shell_done,
        ))))
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const RUN_DECLS: &[BuiltinDecl] = &[run::DECL, run_attached::DECL, shell::DECL];

// 欄は宣言順で扱う。位置を一箇所に集める（実装プラン 10-15「レコードの値の作り方」）。
mod command_fields {
    pub const PROGRAM: u32 = 0;
    pub const ARGUMENTS: u32 = 1;
    pub const DIRECTORY: u32 = 2;
    pub const ENVIRONMENT: u32 = 3;
    pub const INPUT: u32 = 4;
}

struct OwnedCommand {
    program: String,
    arguments: Vec<String>,
    directory: PathBuf,
    environment: Vec<(String, String)>,
    input: Option<String>,
}

struct CommandOutput {
    status: ExitStatus,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
}

fn string<'e>(ctx: &IoCtx<'_, 'e>, value: Value<'e>) -> Result<String, Stop> {
    ctx.str(value)
        .map(str::to_owned)
        .ok_or_else(|| Stop::Internal("Process command field is not String".into()))
}

fn optional_string<'e>(ctx: &IoCtx<'_, 'e>, value: Value<'e>) -> Result<Option<String>, Stop> {
    if matches!(
        value,
        Value::Tag(crate::runtime::heap::CtorTag(tags::OPTION_NONE))
    ) {
        return Ok(None);
    }
    if ctx.fields_header(value) != Some((FieldsKind::Ctor, tags::OPTION_SOME))
        || ctx.fields_len(value) != Some(1)
    {
        return Err(Stop::Internal(
            "Process command field is not Option[String]".into(),
        ));
    }
    string(
        ctx,
        ctx.field(value, 0)
            .ok_or_else(|| Stop::Internal("Process option payload missing".into()))?,
    )
    .map(Some)
}

fn read_command<'e>(ctx: &mut IoCtx<'_, 'e>, command: Value<'e>) -> Result<OwnedCommand, Stop> {
    if ctx.fields_header(command) != Some((FieldsKind::Ctor, tags::RECORD))
        || ctx.fields_len(command) != Some(5)
    {
        return Err(Stop::Internal("Process command is not Command".into()));
    }
    let field = |index| {
        ctx.field(command, index)
            .ok_or_else(|| Stop::Internal("Process command field missing".into()))
    };
    let program = string(ctx, field(command_fields::PROGRAM)?)?;
    let arguments = crate::runtime::list::to_vec(ctx, field(command_fields::ARGUMENTS)?)?
        .into_iter()
        .map(|value| string(ctx, value))
        .collect::<Result<Vec<_>, _>>()?;
    let directory = optional_string(ctx, field(command_fields::DIRECTORY)?)?;
    let environment = crate::runtime::map::map_to_vec(ctx, field(command_fields::ENVIRONMENT)?)?
        .into_iter()
        .map(|(key, value)| Ok((string(ctx, key)?, string(ctx, value)?)))
        .collect::<Result<Vec<_>, Stop>>()?;
    let input = optional_string(ctx, field(command_fields::INPUT)?)?;
    let base = ctx.services().working_directory();
    let directory = directory.map_or_else(|| base.to_owned(), |path| base.join(path));
    Ok(OwnedCommand {
        program,
        arguments,
        directory,
        environment,
        input,
    })
}

fn execute(
    command: OwnedCommand,
    stdio: ProcessStdio,
) -> Result<CommandOutput, super::file::IoFailure> {
    if command.program.contains('\0')
        || command.arguments.iter().any(|arg| arg.contains('\0'))
        || command.environment.iter().any(|(name, value)| {
            name.is_empty() || name.contains(['\0', '=']) || value.contains('\0')
        })
    {
        return Err(io::Error::new(io::ErrorKind::InvalidInput, text::INVALID_COMMAND).into());
    }
    let program = Path::new(&command.program);
    // 基準のディレクトリも相対の場合を含めて絶対化し、current_dir との組み合わせに
    // OS ごとの差を残さない（ADR 0327 の決定 4）。名前だけの場合は PATH から探させる。
    let program = if command.program.contains('/') && program.is_relative() {
        std::path::absolute(command.directory.join(program))?
    } else {
        program.to_owned()
    };
    let mut child = Command::new(program)
        .args(command.arguments)
        .current_dir(command.directory)
        .envs(command.environment)
        .stdin(if command.input.is_some() {
            Stdio::piped()
        } else if stdio.inherit_stdin {
            Stdio::inherit()
        } else {
            Stdio::null()
        })
        .stdout(if stdio.inherit_stdout {
            Stdio::inherit()
        } else {
            Stdio::piped()
        })
        .stderr(if stdio.inherit_stderr {
            Stdio::inherit()
        } else {
            Stdio::piped()
        })
        .spawn()?;
    std::thread::scope(|scope| {
        // 入力と二つの出力を同時に進める。片方のパイプの満杯でほかも止まるのを防ぐ
        // （設計書 03-07「Process」、実装プラン L13）。子は取り消しでも終わらせない。
        let input = command
            .input
            .zip(child.stdin.take())
            .map(|(input, mut pipe)| {
                std::thread::Builder::new().spawn_scoped(scope, move || {
                    // 03-07「Process」が定めない途中の入力の閉鎖は、オーケストレータの判断で
                    // 書けた分で入力を終えたものとする。子の終了状態と集めた出力を捨てない。
                    match pipe.write_all(input.as_bytes()) {
                        Ok(()) => Ok(()),
                        Err(error) if error.kind() == io::ErrorKind::BrokenPipe => Ok(()),
                        Err(error) => Err(error.into()),
                    }
                })
            });
        let stdout = child.stdout.take().map(|mut pipe| {
            std::thread::Builder::new().spawn_scoped(scope, move || collect_output(&mut pipe))
        });
        let stderr = child.stderr.take().map(|mut pipe| {
            std::thread::Builder::new().spawn_scoped(scope, move || collect_output(&mut pipe))
        });
        let status = child.wait();
        // エラーの有無によらずすべて join し、パイプを使う仕事を残さない。
        let input = join_pipe(input);
        let stdout = join_pipe(stdout);
        let stderr = join_pipe(stderr);
        let status = status?;
        input?;
        Ok(CommandOutput {
            status,
            stdout: stdout?.unwrap_or_default(),
            stderr: stderr?.unwrap_or_default(),
        })
    })
}

fn join_pipe<T>(
    job: Option<io::Result<std::thread::ScopedJoinHandle<'_, Result<T, super::file::IoFailure>>>>,
) -> Result<Option<T>, super::file::IoFailure> {
    let Some(job) = job else { return Ok(None) };
    match job?.join() {
        Ok(result) => result.map(Some),
        // panic は外側の作業用のスレッドの境界に渡し、共通の停止手順に任せる（設計書 02-09「panic 境界」）。
        Err(payload) => std::panic::resume_unwind(payload),
    }
}

/// EOF まで待つため、孫プロセスが出力のパイプを持ち続けると、子が終わっても run は返らない。
/// Rust の Command::output と同じ性質である（設計書 03-07「Process」の出力の収集）。
fn collect_output(reader: &mut impl Read) -> Result<Vec<u8>, super::file::IoFailure> {
    let bytes = super::file::read_all_limited(reader)?;
    // 上限を超えても EOF まで読み捨てる。子が満杯のパイプで止まらずに終わるためである。
    io::copy(reader, &mut io::sink())?;
    Ok(bytes)
}

fn check_output(output: &CommandOutput, function: &'static str) -> Result<(), Stop> {
    if super::count(output.stdout.len())? > crate::runtime::MAX_STRING_BYTES
        || super::count(output.stderr.len())? > crate::runtime::MAX_STRING_BYTES
    {
        return Err(Stop::Resource(
            crate::runtime::ResourceError::InputTooLarge {
                function,
                unit: crate::runtime::SizeUnit::Bytes,
                limit: crate::runtime::MAX_STRING_BYTES,
            },
        ));
    }
    Ok(())
}

fn exit_code(status: ExitStatus) -> Result<i64, Stop> {
    if let Some(code) = status.code() {
        return Ok(i64::from(code));
    }
    // Unix の wait は終了コードかシグナルのどちらかを返す（設計書 03-07「Process」、ADR 0243）。
    let signal = status
        .signal()
        .ok_or_else(|| Stop::Internal("child status has neither exit code nor signal".into()))?;
    Ok(i64::from(signal).saturating_add(128))
}

fn complete_output<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<CommandOutput, super::file::IoFailure>,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let output = match output {
        Ok(output) => output,
        Err(error) => return super::file::result_error(ctx, error, function),
    };
    check_output(&output, function)?;
    let (Ok(stdout), Ok(stderr)) = (
        std::str::from_utf8(&output.stdout),
        std::str::from_utf8(&output.stderr),
    ) else {
        return super::file::result_error(
            ctx,
            io::Error::new(io::ErrorKind::InvalidData, text::INVALID_OUTPUT).into(),
            function,
        );
    };
    // 全出力を検査してから宣言順でレコードを作る（実装プラン 10-15「レコードの値の作り方」）。
    let fields = [
        Value::Int(exit_code(output.status)?),
        ctx.alloc_str(stdout, function)?,
        ctx.alloc_str(stderr, function)?,
    ];
    let output = ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &fields)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[output])
}

fn run_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<CommandOutput, super::file::IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_output(ctx, output, "Benitoite.IO.Process.run")
}

fn shell_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<CommandOutput, super::file::IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    complete_output(ctx, output, "Benitoite.IO.Process.shell")
}

fn attached_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<CommandOutput, super::file::IoFailure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.Process.runAttached";
    let output = match output {
        Ok(output) => output,
        Err(error) => return super::file::result_error(ctx, error, FUNCTION),
    };
    check_output(&output, FUNCTION)?;
    // 完了は待てない。容量待ちになっても預けた書き込みの順は保たれる（実装プラン 10-16）。
    for (stream, bytes) in [
        (crate::runtime::Stream::Stdout, output.stdout),
        (crate::runtime::Stream::Stderr, output.stderr),
    ] {
        let _wait = ctx
            .services()
            .write_output(stream, &String::from_utf8_lossy(&bytes))?;
    }
    ctx.alloc_fields(
        FieldsKind::Ctor,
        tags::RESULT_OK,
        &[Value::Int(exit_code(output.status)?)],
    )
}

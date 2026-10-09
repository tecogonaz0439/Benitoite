//! 外部コマンドの結果と引数の契約（設計書 03-07「Process」、実装プラン L13）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used, clippy::panic)]

use super::*;
use crate::builtins::funcs::runtime_test_support::{error_kind, payload, worker};
use crate::builtins::funcs::stage1_io::TestIo;
use crate::builtins::iface::{CallCtx, Lent};
use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx, ValueCtx};
use crate::runtime::io::services::RunInput;
use std::os::unix::fs::PermissionsExt;

fn services(directory: &Path) -> TestIo {
    TestIo::new(RunInput {
        arguments: vec![],
        working_directory: directory.to_owned(),
        script_directory: directory.to_owned(),
    })
}

fn command<'e>(
    ctx: &ValueCtx<'e>,
    program: &str,
    arguments: &[&str],
    directory: Option<&str>,
    environment: &[(&str, &str)],
    input: Option<&str>,
) -> Value<'e> {
    let string = |s| ctx.alloc_str(s, "test").unwrap();
    let args: Vec<_> = arguments.iter().map(|s| string(s)).collect();
    let mut env = Value::EmptyMap;
    for (name, value) in environment {
        env =
            crate::runtime::map::map_insert(ctx, env, string(name), string(value), "test").unwrap();
    }
    ctx.alloc_fields(
        FieldsKind::Ctor,
        tags::RECORD,
        &[
            string(program),
            crate::runtime::list::from_values(ctx, &args, "test").unwrap(),
            super::super::option(ctx, directory.map(string)).unwrap(),
            env,
            super::super::option(ctx, input.map(string)).unwrap(),
        ],
    )
    .unwrap()
}

fn finish<'e>(ctx: &mut NoGcCtx<'e>, io: &mut TestIo, reply: IoReply<'e>) -> Value<'e> {
    let done = worker(reply).run(Lent::Nothing);
    done.complete(
        &mut CallCtx::new(ctx, Some(io), None, None).io_ctx().unwrap(),
        &[],
    )
    .unwrap()
}

fn invoke<'e>(ctx: &mut NoGcCtx<'e>, io: &mut TestIo, cmd: Value<'e>) -> Value<'e> {
    let reply = run(
        CallCtx::new(ctx, Some(io), None, None).io_ctx().unwrap(),
        cmd,
    )
    .unwrap();
    finish(ctx, io, reply)
}

fn invoke_script<'e>(ctx: &mut NoGcCtx<'e>, io: &mut TestIo, cmd: Value<'e>) -> Value<'e> {
    // Linux ではほかのテストの fork が書き込みの fd を一時的に継いで ETXTBSY になりうる。
    // 本体は errno を IOError の理由に変換するため、raw_os_error が 26 の誤りを同じ経路で
    // 表した文字列との完全一致で判定する。起動の再試行はテストだけで行う。
    let busy = io::Error::from_raw_os_error(26).to_string();
    let mut result = invoke(ctx, io, cmd);
    for _ in 0..4 {
        let is_busy = ctx.fields_header(result) == Some((FieldsKind::Ctor, tags::RESULT_ERROR))
            && ctx
                .field(result, 0)
                .and_then(|error| ctx.field(error, 0))
                .and_then(|reason| ctx.str(reason))
                == Some(busy.as_str());
        if !is_busy {
            break;
        }
        std::thread::yield_now();
        result = invoke(ctx, io, cmd);
    }
    result
}

fn output<'e>(ctx: &ValueCtx<'e>, result: Value<'e>) -> (i64, String, String) {
    let record = payload(ctx, result, tags::RESULT_OK);
    assert_eq!(
        ctx.fields_header(record),
        Some((FieldsKind::Ctor, tags::RECORD))
    );
    (
        ctx.field(record, 0).unwrap().as_int().unwrap(),
        ctx.str(ctx.field(record, 1).unwrap()).unwrap().to_owned(),
        ctx.str(ctx.field(record, 2).unwrap()).unwrap().to_owned(),
    )
}

// 関門: 実際の起動と完了の値を境界にし、終了状態・二つの出力・引数の保存を守る。
// 既存の L10 は Command を作るだけで、起動の退行を捕まえない。新しい差し込み口は使わない。
#[test]
fn run_preserves_arguments_streams_and_nonzero_exit_status() {
    let mut io = services(Path::new("/"));
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (script, args, expected) in [
            ("printf out; printf err >&2", vec![], (0, "out", "err")),
            ("printf failure; exit 7", vec![], (7, "failure", "")),
            (
                "printf '%s\\n' \"$@\"",
                vec!["$X", "*", "a b", "X=abc; printf '%s' \"$X\" | wc -c"],
                (0, "$X\n*\na b\nX=abc; printf '%s' \"$X\" | wc -c\n", ""),
            ),
        ] {
            let mut arguments = vec!["-c", script, "sh"];
            arguments.extend(args);
            let cmd = command(ctx, "sh", &arguments, None, &[], None);
            let result = invoke(ctx, &mut io, cmd);
            let actual = output(ctx, result);
            assert_eq!(actual, (expected.0, expected.1.into(), expected.2.into()));
        }
    });
}

// 関門: 二つの出力がパイプの容量を超えた後に入力を読む子で、循環する待ちを捕まえる。
// 小さい入出力だけのテストでは、順番に読み書きする誤りが通ってしまう。
#[test]
fn input_and_both_outputs_progress_without_filling_pipes() {
    let mut io = services(Path::new("/"));
    let input = "入力\n".repeat(32768);
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let cmd = command(ctx, "sh", &["-c",
            "i=0; while [ \"$i\" -lt 8192 ]; do printf 'abcdefghABCDEFGH'; printf '0123456789abcdef' >&2; i=$((i+1)); done; cat"],
            None, &[], Some(&input));
        let result = invoke(ctx, &mut io, cmd);
        let actual = output(ctx, result);
        assert_eq!(actual.0, 0);
        assert_eq!(actual.1, format!("{}{input}", "abcdefghABCDEFGH".repeat(8192)));
        assert_eq!(actual.2, "0123456789abcdef".repeat(8192));
    });
}

// 関門: 入力を読み切らない子でも終了状態と出力を返す契約を、実際のパイプで守る。
// 1 MiB はパイプに収まらず、子が先に閉じる場合の BrokenPipe を再現する。
#[test]
fn closed_child_input_preserves_exit_status_and_output() {
    let mut io = services(Path::new("/"));
    let input = format!("first line\n{}", "x".repeat(1048565));
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (program, args, expected) in [
            ("sh", vec!["-c", "exit 0"], (0, "", "")),
            ("head", vec!["-n", "1"], (0, "first line\n", "")),
            (
                "sh",
                vec!["-c", "printf out; printf err >&2; exit 7"],
                (7, "out", "err"),
            ),
        ] {
            let cmd = command(ctx, program, &args, None, &[], Some(&input));
            let result = invoke(ctx, &mut io, cmd);
            assert_eq!(
                output(ctx, result),
                (expected.0, expected.1.into(), expected.2.into())
            );
        }
    });
}

// 関門: OS の失敗と引数の不正と UTF-8 の失敗は、Result.Error の種類で区別する。
// 他のモジュールの IOError のテストは、コマンドに渡す文字列の検査を通らない。
#[test]
fn run_reports_not_found_invalid_input_and_invalid_utf8() {
    let mut io = services(Path::new("/"));
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (program, args, env, kind) in [
            (
                "benitoite-l13-command-that-does-not-exist",
                vec![],
                vec![],
                tags::IO_ERROR_KIND_NOT_FOUND,
            ),
            (
                "sh",
                vec!["-c", "printf '\\377'"],
                vec![],
                tags::IO_ERROR_KIND_INVALID_UTF8,
            ),
            (
                "sh",
                vec!["-c", "printf '\\377' >&2"],
                vec![],
                tags::IO_ERROR_KIND_INVALID_UTF8,
            ),
            ("sh\0", vec![], vec![], tags::IO_ERROR_KIND_INVALID_INPUT),
            (
                "sh",
                vec!["bad\0arg"],
                vec![],
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (
                "sh",
                vec![],
                vec![("", "value")],
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (
                "sh",
                vec![],
                vec![("a=b", "value")],
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (
                "sh",
                vec![],
                vec![("a\0b", "value")],
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
            (
                "sh",
                vec![],
                vec![("a", "value\0")],
                tags::IO_ERROR_KIND_INVALID_INPUT,
            ),
        ] {
            let cmd = command(ctx, program, &args, None, &env, None);
            let result = invoke(ctx, &mut io, cmd);
            assert_eq!(
                error_kind(ctx, result),
                kind,
                "{program:?} {args:?} {env:?}"
            );
        }
    });
}

// 関門: シェルの解釈とシグナルの終了状態を本体の境界で守る。run の引数のテストと役割が異なる。
#[test]
fn shell_interprets_pipes_variables_and_signal_exit_status() {
    let mut io = services(Path::new("/"));
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (line, code, stdout) in [
            ("X=abc; printf '%s' \"$X\" | wc -c", 0, "3"),
            ("kill -TERM $$", 143, ""),
            ("cat", 0, ""),
        ] {
            let arg = ctx.alloc_str(line, "test").unwrap();
            let reply = shell(
                CallCtx::new(ctx, Some(&mut io), None, None)
                    .io_ctx()
                    .unwrap(),
                arg,
            )
            .unwrap();
            let result = finish(ctx, &mut io, reply);
            let actual = output(ctx, result);
            assert_eq!(actual.0, code);
            assert_eq!(actual.1.trim(), stdout);
            assert_eq!(actual.2, "");
        }
    });
}

// 関門: 基準のディレクトリと子のディレクトリからの program の解決、environment の追加を守る。
// 親の cwd と環境を変えず、テスト専用の公開の口も要しない。
#[test]
fn command_resolves_directory_relative_program_and_environment() {
    let base = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target/l13-unit");
    std::fs::create_dir_all(&base).unwrap();
    let base = base.canonicalize().unwrap();
    let directory = (0..10000)
        .find_map(|n| {
            let path = base.join(format!("{}-{n}", std::process::id()));
            match std::fs::create_dir(&path) {
                Ok(()) => Some(path),
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => None,
                Err(e) => panic!("create directory: {e}"),
            }
        })
        .unwrap();
    let sub = directory.join("sub");
    std::fs::create_dir(&sub).unwrap();
    let path = sub.join("tool");
    std::fs::write(
        &path,
        "#!/bin/sh\nprintf '%s\\n' \"$PWD\" \"$BENITOITE_L13_VALUE\"\n",
    )
    .unwrap();
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
    let cwd = std::env::current_dir().unwrap();
    let common = cwd
        .ancestors()
        .find(|path| directory.starts_with(path))
        .unwrap();
    let mut relative_directory = PathBuf::new();
    for _ in cwd.strip_prefix(common).unwrap().components() {
        relative_directory.push("..");
    }
    relative_directory.push(directory.strip_prefix(common).unwrap());
    for base_directory in [&directory, &relative_directory] {
        let mut io = services(base_directory);
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (program, args, wd, expected_dir) in [
                ("./tool", vec![], Some("sub"), &sub),
                (
                    "sh",
                    vec!["-c", "printf '%s\\n' \"$PWD\" \"$BENITOITE_L13_VALUE\""],
                    None,
                    &directory,
                ),
            ] {
                let cmd = command(
                    ctx,
                    program,
                    &args,
                    wd,
                    &[("BENITOITE_L13_VALUE", "added")],
                    None,
                );
                let result = if program == "./tool" {
                    invoke_script(ctx, &mut io, cmd)
                } else {
                    invoke(ctx, &mut io, cmd)
                };
                let actual = output(ctx, result);
                assert_eq!(
                    actual,
                    (0, format!("{}\nadded\n", expected_dir.display()), "".into())
                );
            }
        });
    }
    std::fs::remove_dir_all(directory).unwrap();
}

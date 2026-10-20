//! セルのコード生成と VM の組み合わせ（設計書 01-07「可変のセル（初回リリース版）」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::unwrap_used)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

// 呼び直しで更新関数の RETURN が呼び出し位置になる退行を、報告の trace で捕まえる
// （設計書 02-08「実行時エラーの情報の記録」）。
#[test]
fn retried_update_trace_keeps_the_update_call_site() {
    let source = r#"
function busy(n: Integer) -> Integer
 if n = 0 then return 42 end if
 return busy(n - 1)
end function
function main() -> Unit uses State
 bind r <- Reference.new(1)
 with group = TaskGroup.open() do
  bind _ <- TaskGroup.spawn(group: group, action: lambda()
   Reference.set(reference: r, value: 0)
   return ()
  end lambda)
  Reference.update(reference: r, f: lambda(value: Integer) -> Integer
   bind _ <- busy(100000)
   return 10 div value
  end lambda)
 end with
 return ()
end function
"#;
    // 小さい入力でも更新中に別タスクへ譲り、同じ競合と呼び直しを起こす。
    let source = if cfg!(feature = "gc-stress") {
        source.replace("busy(100000)", "busy(16)")
    } else {
        source.to_owned()
    };
    let checked = pipeline::check_text(
        "retry.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
    let program = pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let env = RunEnv {
            input: RunInput {
                arguments: vec![],
                working_directory: "/".into(),
                script_directory: "/".into(),
            },
            stdin: StdinSource::Empty,
            stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
            interrupt: Box::new(NoInterrupt),
            parts: None,
            mode,
            vm: VmConfig {
                call_budget: if cfg!(feature = "gc-stress") { 3 } else { 100 },
                ..VmConfig::default()
            },
            heap: HeapConfig::default(),
            dev_panic_after_first_write: false,
        };
        let end = run::run_program(&program, env);
        let report = end.reports.first().unwrap();
        assert_eq!(report.code, Some(benitoite::diag::DiagCode::R0101));
        let site = report
            .trace
            .as_ref()
            .unwrap()
            .frames
            .first()
            .unwrap()
            .call_site
            .unwrap();
        assert_eq!(
            usize::try_from(site.start.0).unwrap(),
            source.find("Reference.update(").unwrap()
        );
    }
}

// 関門: 型検査・脱糖・コード生成から実行した結果を確かめる。ヒープと組み込みの
// 単体テストでは UPDATE の結果、末尾再帰での枠の蓄積、循環の回収を捕まえない。
// 準備は共有し、外部の出力だけを置き換える。
#[test]
fn scripts_update_values_return_unit_and_release_frames_and_cycles() {
    let cases = [
        (
            "string builder snapshots and evaluation order",
            r#"import Benitoite.StringBuilder
function piece(count: Reference[Integer]) -> String uses State
 Reference.set(reference: count, value: Reference.get(count) + 1)
 return "é"
end function
"#,
            r#"bind count <- Reference.new(0)
 bind b: StringBuilder <- StringBuilder.new()
 StringBuilder.append(text: piece(count), builder: b)
 bind before <- StringBuilder.copy(b)
 StringBuilder.appendAll(texts: [piece(count), "!"], builder: b)
 bind after <- StringBuilder.copy(b)
 StringBuilder.append(builder: b, text: if true then
  StringBuilder.append(builder: b, text: "x")
  StringBuilder.copy(b)
 else "unreachable" end if)
 bind action <- lambda() return before end lambda
 return if before = "é" and after = "éé!" and action() = "é"
  and StringBuilder.copy(b) = "éé!xéé!x"
  and StringBuilder.byteLength(b) = 12 and Reference.get(count) = 2
 then Result.Ok(()) else Result.Error("builder evaluation") end if"#,
        ),
        (
            "list builder snapshots shared references and nested argument evaluation",
            r#"import Benitoite.ListBuilder
function collect[T](value: T) -> List[T] uses State
 bind b: ListBuilder[T] <- ListBuilder.new()
 ListBuilder.append(builder: b, value: value)
 return ListBuilder.copy(b)
end function
"#,
            r#"bind r <- Reference.new(1)
 bind b: ListBuilder[Reference[Integer]] <- ListBuilder.new()
 ListBuilder.append(value: r, builder: b)
 bind before <- ListBuilder.copy(b)
 ListBuilder.appendAll(values: collect(r), builder: b)
 bind after <- ListBuilder.copy(b)
 ListBuilder.appendAll(builder: b, values: if true then
  ListBuilder.append(builder: b, value: r)
  ListBuilder.copy(b)
 else [] end if)
 Reference.set(reference: r, value: 42)
 bind f <- lambda() return List.length(before) end lambda
 bind observed <- match before with
 case [cell] -> Reference.get(cell)
 case _ -> 0
 end match
 return if f() = 1 and List.length(after) = 2 and ListBuilder.length(b) = 6
  and observed = 42 and List.length(collect("generic")) = 1
 then Result.Ok(()) else Result.Error("list builder snapshots") end if"#,
        ),
        (
            "bytes builder fragments and argument effects",
            r#"import Benitoite.BytesBuilder
function piece(count: Reference[Integer]) -> Byte uses State
 Reference.set(reference: count, value: Reference.get(count) + 1)
 return 0xafu8
end function
"#,
            r#"bind count <- Reference.new(0)
 bind b: BytesBuilder <- BytesBuilder.new()
 BytesBuilder.append(value: piece(count), builder: b)
 bind before <- BytesBuilder.copy(b)
 BytesBuilder.appendAll(bytes: Bytes.fromList([piece(count), 0x00u8]), builder: b)
 bind after <- BytesBuilder.copy(b)
 BytesBuilder.appendAll(builder: b, bytes: if true then
  BytesBuilder.append(builder: b, value: 0xffu8)
  BytesBuilder.copy(b)
 else Bytes.empty() end if)
 bind f <- lambda() return before end lambda
 bind cached <- lazy Bytes.toHex(before) end lazy
 return if Lazy.force(cached) = "af" and Bytes.toHex(f()) = "af" and Bytes.toHex(after) = "afaf00"
  and Bytes.toHex(BytesBuilder.copy(b)) = "afaf00ffafaf00ff"
  and BytesBuilder.length(b) = 8 and Reference.get(count) = 2
 then Result.Ok(()) else Result.Error("bytes builder evaluation") end if"#,
        ),
        (
            "builder continuation resume and drop with multiple cells",
            r#"import Benitoite.ListBuilder
import Benitoite.BytesBuilder
effect Ask
 function ask() -> Integer
end effect
"#,
            r#"bind xs: ListBuilder[Integer] <- ListBuilder.new()
 bind bs: BytesBuilder <- BytesBuilder.new()
 ListBuilder.append(builder: xs, value: 1)
 bind n <- handle
  ListBuilder.append(builder: xs, value: ask())
  BytesBuilder.append(builder: bs, value: 0x02u8)
  ListBuilder.length(xs)
 with
 case ask() ->
  bind local: BytesBuilder <- BytesBuilder.new()
  BytesBuilder.append(builder: local, value: 0x03u8)
  bind snapshot <- BytesBuilder.copy(local)
  bind result <- resume(2)
  result + BytesBuilder.length(local) + Bytes.length(snapshot)
 end handle
 bind dropped <- handle
  ListBuilder.appendAll(builder: xs, values: [ask(), 99])
  BytesBuilder.append(builder: bs, value: 0xffu8)
  1000
 with
 case ask() ->
  bind local: ListBuilder[Integer] <- ListBuilder.new()
  ListBuilder.append(builder: local, value: 7)
  ListBuilder.length(local)
 end handle
 return if n = 4 and dropped = 1 and ListBuilder.copy(xs) = [1, 2]
  and Bytes.toHex(BytesBuilder.copy(bs)) = "02"
 then Result.Ok(()) else Result.Error("builder continuation") end if"#,
        ),
        (
            "builders survive return fail and task cancellation",
            r#"import Benitoite.ListBuilder
import Benitoite.BytesBuilder
import Benitoite.Unofficial.Failure
effect Abort
 function abort() -> Unit
end effect
function early() -> List[Integer] uses State
 bind b: ListBuilder[Integer] <- ListBuilder.new()
 ListBuilder.append(builder: b, value: 5)
 return ListBuilder.copy(b)
end function
function fail(saved: Reference[Bytes]) -> Unit uses State, Failure.Fail[String]
 bind b: BytesBuilder <- BytesBuilder.new()
 BytesBuilder.append(builder: b, value: 0x06u8)
 Reference.set(reference: saved, value: BytesBuilder.copy(b))
 Failure.raise("expected")
end function
function wait(ready: Reference[Boolean]) -> Unit uses State
 if Reference.get(ready) then return () end if
 return wait(ready)
end function
function spin() -> Unit
 return spin()
end function
"#,
            r#"bind saved <- Reference.new(Bytes.empty())
 bind result <- Failure.toResult(body: lambda() return fail(saved) end lambda)
 bind ready <- Reference.new(false)
 bind _ <- handle
  with group = TaskGroup.open() do
   bind _ <- TaskGroup.spawn(group: group, action: lambda()
    bind b: ListBuilder[Integer] <- ListBuilder.new()
    ListBuilder.appendAll(builder: b, values: [7, 8])
    Reference.set(reference: ready, value: ListBuilder.length(b) = 2)
    spin()
    return ListBuilder.copy(b)
   end lambda)
   wait(ready)
   abort()
  end with
 with
 case abort() -> ()
 end handle
 bind after: BytesBuilder <- BytesBuilder.new()
 BytesBuilder.append(builder: after, value: 0x09u8)
 return if early() = [5] and result = Result.Error("expected")
  and Bytes.toHex(Reference.get(saved)) = "06" and Reference.get(ready)
  and Bytes.toHex(BytesBuilder.copy(after)) = "09"
 then Result.Ok(()) else Result.Error("builder control cleanup") end if"#,
        ),
        (
            "update result",
            "",
            "bind r <- Reference.new(3)\n bind u <- Reference.update(reference: r, f: lambda(value: Integer) -> Integer return value + 7 end lambda)\n Reference.set(reference: r, value: Reference.get(r) * 2)\n return if u = () and Reference.get(r) = 20 then Result.Ok(()) else Result.Error(\"update\") end if",
        ),
        (
            "large allocated result",
            "function grow(xs: List[Integer], n: Integer) -> List[Integer]\n if n = 0 then return xs end if\n return grow(xs: List.append(xs: xs, x: n), n: n - 1)\nend function\n",
            "bind r <- Reference.new([0])\n bind u <- Reference.update(reference: r, f: lambda(value: List[Integer]) -> List[Integer] return grow(xs: value, n: 2048) end lambda)\n return if u = () and List.length(Reference.get(r)) = 2049 then Result.Ok(()) else Result.Error(\"list\") end if",
        ),
        (
            "100000 updates",
            "function repeat(r: Reference[Integer], n: Integer) -> Unit uses State\n if n = 0 then return () end if\n Reference.update(reference: r, f: lambda(value: Integer) -> Integer return value + 1 end lambda)\n return repeat(r: r, n: n - 1)\nend function\n",
            "bind r <- Reference.new(0)\n repeat(r: r, n: 100000)\n return if Reference.get(r) = 100000 then Result.Ok(()) else Result.Error(\"frames\") end if",
        ),
        (
            "discarded cycles",
            "data Node\n Link(Reference[Option[Node]])\nend data\nfunction cycles(n: Integer) -> Unit uses State\n if n = 0 then return () end if\n bind r <- Reference.new(Option.None)\n bind v <- Node.Link(r)\n Reference.set(reference: r, value: Option.Some(v))\n return cycles(n - 1)\nend function\n",
            "cycles(10000)\n return Result.Ok(())",
        ),
    ];
    for (name, extra, body) in cases {
        // 反復回数と期待する長さを一緒に縮め、結果・枠・循環の検査は全て残す。
        let body = if cfg!(feature = "gc-stress") {
            body.replace("100000", "16")
                .replace("10000", "16")
                .replace("2048", "64")
                .replace("2049", "65")
        } else {
            body.to_owned()
        };
        let source = format!(
            "{extra}\nfunction main() -> Result[Unit, String] uses State\n {body}\nend function\n"
        );
        let checked = pipeline::check_text(
            "cells.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{name}: {:?}",
            checked.diagnostics
        );
        let core = pipeline::desugar_checked(&checked.program.unwrap()).unwrap();
        let program = pipeline::compile(&core, checked.sources).unwrap();
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let env = RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: "/".into(),
                    script_directory: "/".into(),
                },
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                interrupt: Box::new(NoInterrupt),
                parts: None,
                mode,
                vm: VmConfig {
                    max_call_stack_bytes: 8192,
                    call_budget: 3,
                },
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            };
            let end = run::run_program(&program, env);
            assert_eq!(end.exit_code, 0, "{name}: {end:?}");
            assert!(end.main_error.is_none(), "{name}: {end:?}");
            assert!(end.reports.is_empty(), "{name}: {end:?}");
        }
    }
}

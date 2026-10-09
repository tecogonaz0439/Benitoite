//! Json のソースの関数と ParseError の欄をスクリプトで確かめる（設計書 03-08「Json」）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::sync::{Arc, Mutex};

// 関門: 8 個のソースの関数、Json.Value の等値、ParseError の宣言順を公開の経路で守る。
// 単体テストが届かないソースの分岐、フィールドの脱糖、辞書の解決の退行を捕まえる。
// 本番の差し込み口を増やさず、型検査から VM まで本物をつなぎ、回収の強制でも走らせる。
fn run_script(source: &str) {
    let checked = pipeline::check_text(
        "l21.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let script = ScheduleHandle::new([], false);
        let result = run::run_program(
            &program,
            RunEnv {
                input: RunInput {
                    arguments: vec![],
                    working_directory: "/".into(),
                    script_directory: "/".into(),
                },
                stdin: StdinSource::Empty,
                stdout: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
                interrupt: Box::new(NoInterrupt),
                parts: Some(script.parts()),
                mode,
                vm: VmConfig::default(),
                heap: HeapConfig {
                    stress: true,
                    ..HeapConfig::default()
                },
                dev_panic_after_first_write: false,
            },
        );
        assert_eq!(result.end, EndKind::Returned, "{mode:?}: {result:?}");
        assert_eq!(result.exit_code, 0, "{mode:?}: {result:?}");
        assert!(result.main_error.is_none(), "{mode:?}: {result:?}");
        assert!(result.reports.is_empty(), "{mode:?}: {result:?}");
    }
}

#[test]
fn source_queries_and_value_equality() {
    run_script(
        r#"
import Benitoite.Unofficial.Json
function main() -> Result[Unit, String]
  bind value <- try Json.parse("{\"title\":\"é😀\",\"items\":[7,1.5,true,null]}") |> Result.mapError(_, Json.ParseError.message)
  if Json.get(value, "title") <> Option.Some(Json.Value.String("é😀"))
    or Json.get(value, "missing") <> Option.None
    or Json.get(Json.Value.Null, "title") <> Option.None then
    return Result.Error("get")
  end if
  bind items <- Json.get(value, "items") |> Option.unwrapOr(_, Json.Value.Null)
  if Json.at(items, 0) <> Option.Some(Json.Value.Integer(7))
    or Json.at(items, 1) <> Option.Some(Json.Value.Float(1.5))
    or Json.at(items, 3) <> Option.Some(Json.Value.Null)
    or Json.at(items, -1) <> Option.None
    or Json.at(items, 4) <> Option.None
    or Json.at(Json.Value.Null, 0) <> Option.None then
    return Result.Error("at")
  end if
  if Json.asString(Json.Value.String("é😀")) <> Option.Some("é😀")
    or Json.asInteger(Json.Value.Integer(-7)) <> Option.Some(-7)
    or Json.asFloat(Json.Value.Integer(7)) <> Option.Some(7.0)
    or Json.asFloat(Json.Value.Float(1.5)) <> Option.Some(1.5)
    or Json.asBoolean(Json.Value.Boolean(true)) <> Option.Some(true)
    or Json.asBoolean(Json.Value.Boolean(false)) <> Option.Some(false)
    or Json.asArray(items) <> Option.Some([Json.Value.Integer(7), Json.Value.Float(1.5), Json.Value.Boolean(true), Json.Value.Null])
    or Json.asArray(Json.Value.Array([])) <> Option.Some([])
    or Json.asObject(Json.Value.Object(Map.empty())) <> Option.Some(Map.empty()) then
    return Result.Error("projections")
  end if
  if Json.asString(Json.Value.Integer(7)) <> Option.None
    or Json.asInteger(Json.Value.Float(7.0)) <> Option.None
    or Json.asFloat(Json.Value.String("7")) <> Option.None
    or Json.asBoolean(Json.Value.Null) <> Option.None
    or Json.asArray(value) <> Option.None
    or Json.asObject(items) <> Option.None then
    return Result.Error("wrong kinds")
  end if
  bind object <- Json.asObject(value) |> Option.unwrapOr(_, Map.empty())
  if Map.get(object, "title") <> Option.Some(Json.Value.String("é😀")) then
    return Result.Error("asObject")
  end if
  bind same <- try Json.parse("{\"items\":[7,1.5,true,null],\"title\":\"é😀\"}") |> Result.mapError(_, Json.ParseError.message)
  bind changed <- try Json.parse("{\"items\":[7,1.5,true,null],\"title\":\"other\"}") |> Result.mapError(_, Json.ParseError.message)
  if value <> same or value = changed then
    return Result.Error("value equality")
  end if
  return Result.Ok(())
end function
"#,
    );
}

#[test]
fn total_amount_and_parse_error_accessors() {
    run_script(
        r#"
import Benitoite.Unofficial.Json
function totalAmount(text: String) -> Result[Integer, String]
  bind value <- try Json.parse(text) |> Result.mapError(_, Json.ParseError.message)
  bind items <- Json.asArray(value) |> Option.unwrapOr(_, [])
  return Result.Ok(List.fold(items, 0, lambda(sum, item)
    return match Json.get(item, "amount") with
      case Option.Some(Json.Value.Integer(n)) -> sum + n
      case _ -> sum
    end match
  end lambda))
end function
function main() -> Result[Unit, String]
  if totalAmount("[{\"amount\":10},{\"amount\":-3},{\"amount\":1.5},{\"other\":99},null,{\"amount\":2}]") <> Result.Ok(9)
    or totalAmount("[]") <> Result.Ok(0)
    or totalAmount("{}") <> Result.Ok(0) then
    return Result.Error("totalAmount")
  end if
  bind error <- match Json.parse("[\n\"é😀\",]") with
    case Result.Error(e) -> Option.Some(e)
    case Result.Ok(_) -> Option.None
  end match
  bind fields <- match error with
    case Option.Some(e) -> Json.ParseError.line(e) = 2 and Json.ParseError.column(e) = 6 and Json.ParseError.message(e) = "trailing comma"
    case Option.None -> false
  end match
  if not fields then
    return Result.Error("ParseError fields")
  end if
  bind eof <- match Json.parse("[1,\n") with
    case Result.Error(e) -> Json.ParseError.line(e) = 2 and Json.ParseError.column(e) = 1 and Json.ParseError.message(e) = "EOF while parsing a value"
    case Result.Ok(_) -> false
  end match
  bind overflow <- match Json.parse("[\n  -1e400]") with
    case Result.Error(e) -> Json.ParseError.line(e) = 2 and Json.ParseError.column(e) = 3 and Json.ParseError.message(e) = "number out of range"
    case Result.Ok(_) -> false
  end match
  if not eof or not overflow then
    return Result.Error("ParseError positions")
  end if
  return Result.Ok(())
end function
"#,
    );
}

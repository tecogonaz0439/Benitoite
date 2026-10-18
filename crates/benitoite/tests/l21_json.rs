//! Json のソースの関数と ParseError の欄をスクリプトで確かめる（設計書 03-08「Json」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
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
  bind value <- try Json.parse("{\"title\":\"é😀\",\"items\":[7,1.5,true,null]}") |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)
  if Json.get(value: value, k: "title") <> Option.Some(Json.Value.String("é😀"))
    or Json.get(value: value, k: "missing") <> Option.None
    or Json.get(value: Json.Value.Null, k: "title") <> Option.None then
    return Result.Error("get")
  end if
  bind items <- Json.get(value: value, k: "items") |> Option.unwrapOr(o: _, fallback: Json.Value.Null)
  if Json.at(value: items, index: 0) <> Option.Some(Json.Value.Integer(7))
    or Json.at(value: items, index: 1) <> Option.Some(Json.Value.Float(1.5))
    or Json.at(value: items, index: 3) <> Option.Some(Json.Value.Null)
    or Json.at(value: items, index: -1) <> Option.None
    or Json.at(value: items, index: 4) <> Option.None
    or Json.at(value: Json.Value.Null, index: 0) <> Option.None then
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
  bind object <- Json.asObject(value) |> Option.unwrapOr(o: _, fallback: Map.empty())
  if Map.get(m: object, k: "title") <> Option.Some(Json.Value.String("é😀")) then
    return Result.Error("asObject")
  end if
  bind same <- try Json.parse("{\"items\":[7,1.5,true,null],\"title\":\"é😀\"}") |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)
  bind changed <- try Json.parse("{\"items\":[7,1.5,true,null],\"title\":\"other\"}") |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)
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
import Benitoite.Trait
import Benitoite.Unofficial.Json
function totalAmount(text: String) -> Result[Integer, String]
  bind document <- try Json.parse(text) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)
  bind items <- Json.asArray(document) |> Option.unwrapOr(o: _, fallback: [])
  return Result.Ok(List.fold(xs: items, initial: 0, f: lambda(acc, value)
    return match Json.get(value: value, k: "amount") with
      case Option.Some(Json.Value.Integer(n)) -> acc + n
      case _ -> acc
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
    case Option.Some(e) -> Json.ParseError.line(e) = 2 and Json.ParseError.column(e) = 6 and Json.ParseError.message(e) = "trailing comma" and Trait.Show.show(e) = Json.ParseError.message(e)
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
  bind original <- Json.ParseError(line: 4, column: 7, message: "original")
  bind updated <- Json.ParseError(..original, message: "updated")
  if Json.ParseError.line(updated) <> 4 or Json.ParseError.column(updated) <> 7
    or Json.ParseError.message(updated) <> "updated" or Json.ParseError.message(original) <> "original" then
    return Result.Error("ParseError construction and update")
  end if
  if Trait.Show.show(original) <> "original" or Trait.Show.show(updated) <> "updated"
    or Trait.Show.show(Json.ParseError(line: 9, column: 2, message: "")) <> ""
    or Trait.Show.show(Json.ParseError(line: 9, column: 2, message: "failure \"é😀\"\nnext")) <> "failure \"é😀\"\nnext" then
    return Result.Error("ParseError Show")
  end if
  return Result.Ok(())
end function
"#,
    );
}

// 関門: Codec の純粋な公開 API の往復・厳密な種類・最初の失敗の相対経路を守る。
// Json の既存テストは任意の Value の問い合わせだけで、変換の順序や数の拒否に届かない。
// 文字列への検索や内部の補助関数の検査を加えず、既存の実行経路を共有する。
#[test]
fn codec_roundtrips_strict_numbers_and_relative_paths() {
    run_script(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec
import Benitoite.Unofficial.Failure
function main() -> Result[Unit, String]
  if Codec.encodeString("é😀") <> Result.Ok(Json.Value.String("é😀"))
    or Codec.decodeString(Json.Value.String("é😀")) <> Result.Ok("é😀")
    or Codec.encodeBoolean(false) <> Result.Ok(Json.Value.Boolean(false))
    or Codec.decodeBoolean(Json.Value.Boolean(true)) <> Result.Ok(true)
    or Codec.encodeInteger(-9223372036854775808) <> Result.Ok(Json.Value.Integer(-9223372036854775808))
    or Codec.decodeInteger(Json.Value.Integer(9223372036854775807)) <> Result.Ok(9223372036854775807)
    or Codec.encodeFloat(-0.0) <> Result.Ok(Json.Value.Float(-0.0))
    or Codec.decodeFloat(Json.Value.Float(1.25)) <> Result.Ok(1.25) then
    return Result.Error("primitive conversions")
  end if
  bind numbers <- [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0]
  if not List.all(xs: numbers, p: lambda(value)
    return Result.isError(Codec.encodeFloat(value)) and Result.isError(Codec.decodeFloat(Json.Value.Float(value)))
  end lambda) then
    return Result.Error("nonfinite float")
  end if
  if not Result.isError(Codec.decodeFloat(Json.Value.Integer(1)))
    or not Result.isError(Codec.decodeInteger(Json.Value.Float(1.0)))
    or not Result.isError(Codec.decodeString(Json.Value.Null))
    or not Result.isError(Codec.decodeBoolean(Json.Value.Integer(1)))
    or not Result.isError(Codec.decodeList(value: Json.Value.Null, decode: Codec.decodeInteger))
    or not Result.isError(Codec.decodeMap(value: Json.Value.Array([]), decode: Codec.decodeInteger)) then
    return Result.Error("strict kinds")
  end if
  if Codec.encodeOption(value: Option.None, encode: Codec.encodeString) <> Result.Ok(Json.Value.Null)
    or Codec.decodeOption(value: Json.Value.Null, decode: Codec.decodeString) <> Result.Ok(Option.None)
    or Codec.encodeOption(value: Option.Some("x"), encode: Codec.encodeString) <> Result.Ok(Json.Value.String("x"))
    or Codec.decodeOption(value: Json.Value.String("x"), decode: Codec.decodeString) <> Result.Ok(Option.Some("x")) then
    return Result.Error("option")
  end if
  bind original <- Map.fromList([Pair("z", [3, 4]), Pair("a", [])])
  bind encoded <- try Codec.encodeMap(value: original, encode: Codec.encodeList(value: _, encode: Codec.encodeInteger)) |> Result.mapError(r: _, f: lambda(error) return Trait.Show.show(error) end lambda)
  if Codec.decodeMap(value: encoded, decode: Codec.decodeList(value: _, decode: Codec.decodeInteger)) <> Result.Ok(original) then
    return Result.Error("container roundtrip")
  end if
  bind broken <- Json.Value.Object(Map.fromList([Pair("z", Json.Value.Null), Pair("a", Json.Value.Array([Json.Value.Integer(1), Json.Value.String("secret-input")]))]))
  bind result <- Codec.decodeMap(value: broken, decode: Codec.decodeList(value: _, decode: Codec.decodeInteger))
  bind goodError <- match result with
    case Result.Error(e) -> Codec.ConversionError.path(e) = [Codec.PathPart.Key("a"), Codec.PathPart.Index(1)]
      and Codec.ConversionError.expected(e) = "integer" and Codec.ConversionError.found(e) = "string"
      and Trait.Show.show(e) = "$[\"a\"][1]: expected integer, found string"
    case Result.Ok(_) -> false
  end match
  if not goodError then
    return Result.Error("decode path or payload leak")
  end if
  bind invalidEncode <- Codec.encodeList(value: [1.0, 1.0 / 0.0, 0.0 / 0.0], encode: Codec.encodeFloat)
  if not (match invalidEncode with
    case Result.Error(e) -> Codec.ConversionError.path(e) = [Codec.PathPart.Index(1)]
    case Result.Ok(_) -> false
  end match) then
    return Result.Error("encode path")
  end if
  bind boundary <- Failure.toResult(lambda() return Failure.fromResult(Codec.decodeInteger(Json.Value.Integer(7))) end lambda)
  if boundary <> Result.Ok(7) then
    return Result.Error("explicit Failure boundary")
  end if
  return Result.Ok(())
end function
"#,
    );
}

// 入力の鍵による偽の経路と改行を、公開のエラー表示で拒む。
#[test]
fn codec_extra_key_path_escapes_untrusted_key() {
    run_script(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.Json
import Benitoite.Unofficial.Json.Codec
function main() -> Result[Unit, String]
  bind key <- "a.b\n[0]: expected integer, found string\t\"\\"
  bind result <- Codec.rejectExtra(members: Map.fromList([Pair(key, Json.Value.String("secret-input"))]), keys: [])
  return match result with
    case Result.Error(error) ->
      if Codec.ConversionError.path(error) = [Codec.PathPart.Key(key)]
        and Trait.Show.show(error) = "$[\"a.b\\n[0]: expected integer, found string\\t\\\"\\\\\"]: expected known field, found extra key" then
        Result.Ok(())
      else
        Result.Error("extra key must be an escaped Key path")
      end if
    case Result.Ok(_) -> Result.Error("extra key accepted")
  end match
end function
"#,
    );
}

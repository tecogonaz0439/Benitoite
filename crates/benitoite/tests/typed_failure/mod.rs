//! Result との変換と非再開の実行の対照（設計書 01-09「型付きの失敗と Result の変換」）。

/// 名前、追加宣言、整数を返す式、独立に求めた期待値、停止の診断。
pub const CASES: &[(
    &str,
    &str,
    &str,
    i64,
    Option<benitoite::diag::codes::DiagCode>,
)] = &[
    (
        "result conversion and original error without Show",
        r#"record Hidden
 payload: List[String]
end record
"#,
        r#"bind ok: Result[Integer, Hidden] <- Failure.toResult(body: lambda()
 return Failure.fromResult(Result.Ok(21)) * 2
end lambda)
bind failed: Result[Integer, Hidden] <- Failure.toResult(body: lambda()
 bind error <- Hidden(payload: [String.repeat(s: "error", n: 30), "tail"])
 bind _ <- Failure.fromResult(Result.Error(error))
 return 1 div 0
end lambda)
match failed with
 case Result.Error(error) ->
  bind pad <- String.repeat(s: "allocation", n: 100)
  if Hidden.payload(error) = [String.repeat(s: "error", n: 30), "tail"] and Result.unwrapOr(r: ok, fallback: 0) = 42 then 42 else String.characterCount(pad) end if
 case Result.Ok(value) -> value
end match"#,
        42,
        None,
    ),
    (
        "map stops at first failure and converts each argument once",
        r#"effect Trace
 function visit(n: Integer) -> Unit
end effect
function convert(value: Integer) -> Integer uses Trace, Failure.Fail[String]
 visit(value)
 return Failure.fromResult(if value = 2 then Result.Error("bad") else Result.Ok(value) end if)
end function
"#,
        r#"handle
 bind result: Result[List[Integer], String] <- Failure.toResult(body: lambda()
  return List.map(xs: [1, 2, 3], f: convert)
 end lambda)
 if result = Result.Error("bad") then 0 else 10000 end if
with
 case visit(n) -> resume(()) * 10 + n
end handle"#,
        21,
        None,
    ),
    (
        "success and result expression evaluated once",
        r#"effect Trace
 function tick() -> Unit
end effect
"#,
        r#"handle
 bind result: Result[Integer, String] <- Failure.toResult(body: lambda()
  tick()
  return Failure.fromResult(result: if true then
   tick()
   Result.Ok(40)
  else Result.Error("bad") end if)
 end lambda)
 Result.unwrapOr(r: result, fallback: 1000)
with
 case tick() -> resume(()) + 1
end handle"#,
        42,
        None,
    ),
    (
        "return and try keep their lambda boundary",
        "",
        r#"bind returned: Result[Integer, String] <- Failure.toResult(body: lambda()
 return 20
end lambda)
bind tried: Result[Result[Integer, String], Integer] <- Failure.toResult(body: lambda() -> Result[Integer, String]
 bind _ <- try Result.Error("early") or return
 return Result.Ok(1 div 0)
end lambda)
bind converted: Result[Integer, String] <- Failure.toResult(body: lambda()
 return Failure.fromResult(result: Result.Error("early"))
end lambda)
if returned = Result.Ok(20) and tried = Result.Ok(Result.Error("early")) and converted = Result.Error("early") then 42 else 0 end if"#,
        42,
        None,
    ),
    (
        "nested conversion preserves distinct errors and latent effects",
        "",
        r#"bind outer: Result[Integer, String] <- Failure.toResult(body: lambda()
 bind inner: Result[Integer, Integer] <- Failure.toResult(body: lambda()
  return Failure.raise(error: 17)
 end lambda)
 return if inner = Result.Error(17) then Failure.raise(error: "outer") else 0 end if
end lambda)
bind closure: Result[(function() -> Integer uses Failure.Fail[String]), Integer] <- Failure.toResult(body: lambda()
 return lambda() return Failure.raise(error: "latent") end lambda
end lambda)
bind last: Result[Integer, String] <- Failure.toResult(body: Result.unwrapOr(r: closure, fallback: lambda() return 0 end lambda))
if outer = Result.Error("outer") and last = Result.Error("latent") then 42 else 0 end if"#,
        42,
        None,
    ),
    (
        "child handles failure locally",
        "",
        r#"bind values <- Task.all([lambda() -> Result[Integer, String]
 return Failure.toResult(body: lambda() return Failure.raise(error: "child") end lambda)
end lambda, lambda() -> Result[Integer, String]
 return Failure.toResult(body: lambda() return 42 end lambda)
end lambda])
if values = [Result.Error("child"), Result.Ok(42)] then 42 else 0 end if"#,
        42,
        None,
    ),
    (
        "child cannot inherit failure handler",
        "",
        r#"bind result: Result[List[Integer], String] <- Failure.toResult(body: lambda()
 return Task.all([lambda() return Failure.raise(error: "child") end lambda])
end lambda)
Result.unwrapOr(r: Result.map(r: result, f: lambda(value) return List.length(value) end lambda), fallback: 42)"#,
        0,
        Some(benitoite::diag::codes::DiagCode::R0502),
    ),
    (
        "runtime error is not a failure value",
        "",
        r#"bind result: Result[Integer, String] <- Failure.toResult(body: lambda() return 1 div 0 end lambda)
Result.unwrapOr(r: result, fallback: 42)"#,
        0,
        Some(benitoite::diag::codes::DiagCode::R0101),
    ),
];

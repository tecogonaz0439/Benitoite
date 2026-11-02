import Lean
import Benitoite
set_option maxHeartbeats 4000000

-- 文書から抽出した識別子を、既定環境の宣言・名前空間・モジュールへ照合する。
open Lean Elab Command in
run_cmd do
  let some input ← IO.getEnv "L20_STAGE_TOKENS" | throwError "STAGE_TOKENS_REQUIRED"
  let text ← IO.FS.readFile input
  let tokens := (text.splitOn "\n").filter (! ·.isEmpty)
  let wanted : Std.HashSet String := .ofList tokens
  let env ← getEnv
  let globals := env.constants.toList.map (fun (n, _) => (n, n.toString))
  let ordered := globals.filter (fun (_, s) => s.startsWith "Benitoite.Release.Refinement.") ++
    globals.filter (fun (_, s) => !s.startsWith "Benitoite.Release.Refinement.")
  let mut found : Std.HashMap String Name := {}
  for (name, s) in ordered do
    let mut suffix := ""
    for part in (s.splitOn ".").reverse do
      suffix := if suffix.isEmpty then part else part ++ "." ++ suffix
      if wanted.contains suffix && !found.contains suffix then
        found := found.insert suffix name
  for token in tokens do
    if let some name := found[token]? then
      logInfo m!"STAGE_DECL {token} {name}"
    else if let some mod := env.header.moduleNames.find? (fun n =>
        n.toString == token || n.toString.endsWith ("." ++ token)) then
      logInfo m!"STAGE_MODULE {token} {mod}"
    else
      let scope := if token.startsWith "Benitoite." then token else
        "Benitoite.Release.Refinement." ++ token
      if globals.any (fun (_, s) => s.startsWith (scope ++ ".")) then
        logInfo m!"STAGE_NAMESPACE {token} {scope}"
      else logInfo m!"STAGE_UNRESOLVED {token}"

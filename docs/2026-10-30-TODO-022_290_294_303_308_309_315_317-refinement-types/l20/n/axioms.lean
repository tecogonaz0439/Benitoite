import Lean
import Benitoite

-- 対象の一覧は同じディレクトリの audit-modules.txt と audit-declarations.txt。
-- 再帰的な値の関係・選択・腕の接続・具体例を含め、生成された補助定数もモジュール単位で監査する。生の出力は <tmp>。
-- 既定ビルドの外の H04 の反例と候補の証明は、h04-counterexample.lean 自身でも公理依存を印字する。
-- 実行は formal/ で lake env lean -M 12288。環境変数で別の一覧も指定できる。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let modulesPath := (← IO.getEnv "L20_AXIOM_MODULES").getD "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/n/audit-modules.txt"
  let declarationsPath := (← IO.getEnv "L20_AXIOM_DECLARATIONS").getD "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/n/audit-declarations.txt"
  let modules ← IO.FS.lines modulesPath
  let declarations ← IO.FS.lines declarationsPath
  unless modules.size > 0 && declarations.size > 0 do throwError "AUDIT_INPUT_EMPTY"
  for moduleText in modules do
    let mod := moduleText.toName
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if mod == `Benitoite.Release.Refinement.ClosureTyping && name.toString.endsWith "._unsafe_rec" then
        logInfo m!"AUDIT_EXISTING_COMPILER_REC {name} unsafe={ci.isUnsafe} partial={ci.isPartial}"
      else if ci.isUnsafe || ci.isPartial then throwError "AUDIT_UNSAFE {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      logInfo m!"AUDIT_TYPE {name} : {ci.type}"
      elabCommand (← `(#print axioms $(mkIdent name)))
  for declarationText in declarations do
    let name := declarationText.toName
    unless (env.find? name).isSome do throwError "AUDIT_DECL_MISSING {name}"
    elabCommand (← `(#print axioms $(mkIdent name)))

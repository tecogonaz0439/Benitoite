import Benitoite.Release.Refinement.ProofReplayExamples

def main : IO Unit := do
  let rows := Benitoite.Release.Refinement.ProofReplayExamples.rows
  for (label,passed) in rows do
    IO.println s!"{label}: {passed}"
    unless passed do throw (IO.userError s!"再生不一致: {label}")
  unless rows.length == 22 do throw (IO.userError "再生の件数が異なる")

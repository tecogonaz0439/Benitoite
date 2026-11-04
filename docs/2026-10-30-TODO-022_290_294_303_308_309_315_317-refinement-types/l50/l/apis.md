# 段末の十三 API の照合

完全名の先頭は Benitoite.Release.Refinement である。純粋六行は同じ決定的δ、IO七行は同じ関係の全応答と存在を区別する。

| API | 全型付き入力の入口 | 実δ又は応答関係 | 全応答の充足 | 応答存在 | 読者 |
|---|---|---|---|---|---|
| Scope.checkPathIn | `ScopeDelta.response` | `ScopeDelta.delta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| Http.checkRequestIn | `RequestDelta.response` | `RequestDelta.delta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| Scope.pathInValue | `ScopeDelta.pathInValue_response` | `ScopeDelta.valueDelta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| Http.requestInValue | `RequestDelta.requestInValue_response` | `RequestDelta.valueDelta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| Scope.widenPathIn | `ScopeDelta.widenPathIn_response` | `ScopeDelta.valueDelta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| Http.widenRequestIn | `RequestDelta.widenRequestIn_response` | `RequestDelta.valueDelta` | `ScopeResponse.outcome_typed` | `ScopeResponse.delta_typed` | `ScopedTargetInputs.pure_steps` |
| File.readTextIn | `ScopedIOResponse.readTextIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| File.readBytesIn | `ScopedIOResponse.readBytesIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| File.writeTextIn | `ScopedIOResponse.writeTextIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| File.writeBytesIn | `ScopedIOResponse.writeBytesIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| File.appendTextIn | `ScopedIOResponse.appendTextIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| File.appendBytesIn | `ScopedIOResponse.appendBytesIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |
| Http.sendIn | `ScopedIOResponse.sendIn` | `ScopedIOResponse.ioResponse` | `ScopedIOResponse.io_typed` | `ScopedIOResponse.io_exists` | `ScopedTargetInputs.io_steps` |

各行の範囲変数は一度具体化した入力である。正常成功の存在と実IOの成功を保証しない。原署名・valKind/valContent・対象位置は [群Eの全16署名](../e/signatures.md)、実際の完全型は段末のsignatures-partへ対応する。

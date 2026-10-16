# try の移行候補の確認表

既定は読み取りのみ。die の契約と処置は人が確認する。候補ごとの変更後のハッシュは単独編集、ファイルの最終ハッシュは file_changes に記す。

分類の件数: `{"change": 136, "hold": 9}`

## try-000001 — crates/benitoite/examples/stack_probe/support.rs:43

```json
{
  "id": "try-000001",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 20,
  "host_kind": "rust_string",
  "role": "sample",
  "line": 43,
  "start": 2320,
  "end": 2323,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [
    "Some(E0201)"
  ],
  "check_codes": [],
  "holds": [
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000002 — crates/benitoite/examples/stack_probe/support.rs:160

```json
{
  "id": "try-000002",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 109,
  "host_kind": "rust_string",
  "role": "sample",
  "line": 160,
  "start": 6929,
  "end": 6932,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [],
  "check_codes": [],
  "holds": [
    "generated_or_concatenated_rust",
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000003 — crates/benitoite/examples/stack_probe/support.rs:172

```json
{
  "id": "try-000003",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 120,
  "host_kind": "rust_string",
  "role": "sample",
  "line": 172,
  "start": 7402,
  "end": 7405,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [
    "Some(E0201)"
  ],
  "check_codes": [],
  "holds": [
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000004 — crates/benitoite/examples/stack_probe/support.rs:172

```json
{
  "id": "try-000004",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 121,
  "host_kind": "rust_string",
  "role": "sample",
  "line": 172,
  "start": 7416,
  "end": 7419,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [
    "Some(E0201)"
  ],
  "check_codes": [],
  "holds": [
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000005 — crates/benitoite/examples/stack_probe/support.rs:190

```json
{
  "id": "try-000005",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 149,
  "host_kind": "rust_string",
  "role": "sample",
  "line": 190,
  "start": 8224,
  "end": 8227,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [
    "Some(E0201)"
  ],
  "check_codes": [],
  "holds": [
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000006 — crates/benitoite/examples/stack_probe/support.rs:37

```json
{
  "id": "try-000006",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 152,
  "host_kind": "host_text",
  "role": "sample",
  "line": 37,
  "start": 2000,
  "end": 2003,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [],
  "check_codes": [],
  "holds": [
    "review_embedded_example",
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000007 — crates/benitoite/examples/stack_probe/support.rs:42

```json
{
  "id": "try-000007",
  "path": "crates/benitoite/examples/stack_probe/support.rs",
  "source_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "after_sha256": "849c6cb15687b29ede24a1ccaf698522582e5c35e13e24b6b894982c090cea55",
  "snippet": 153,
  "host_kind": "host_text",
  "role": "sample",
  "line": 42,
  "start": 2231,
  "end": 2234,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "スタック検査用の入力・形の名前・深さの説明として保持する。手本を出力する生成器ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [],
  "check_codes": [],
  "holds": [
    "review_embedded_example",
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000008 — crates/benitoite/examples/try_actions_inventory.rs:1

```json
{
  "id": "try-000008",
  "path": "crates/benitoite/examples/try_actions_inventory.rs",
  "source_sha256": "ce320a7cea289af348f853754f1235c4c8432070f6b87b9983dc0aaf30a0be84",
  "after_sha256": "ce320a7cea289af348f853754f1235c4c8432070f6b87b9983dc0aaf30a0be84",
  "snippet": 58,
  "host_kind": "host_text",
  "role": "sample",
  "line": 1,
  "start": 26,
  "end": 29,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "移行器の役割と AST の説明であり、実行例ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [],
  "check_codes": [],
  "holds": [
    "review_embedded_example",
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000009 — crates/benitoite/examples/try_actions_inventory.rs:2

```json
{
  "id": "try-000009",
  "path": "crates/benitoite/examples/try_actions_inventory.rs",
  "source_sha256": "ce320a7cea289af348f853754f1235c4c8432070f6b87b9983dc0aaf30a0be84",
  "after_sha256": "ce320a7cea289af348f853754f1235c4c8432070f6b87b9983dc0aaf30a0be84",
  "snippet": 59,
  "host_kind": "host_text",
  "role": "sample",
  "line": 2,
  "start": 172,
  "end": 175,
  "operand_end": null,
  "operand_host_end": null,
  "action": null,
  "owner": null,
  "classification": "hold",
  "proposed_action": null,
  "reason": "移行器の役割と AST の説明であり、実行例ではない。",
  "before": "try",
  "after": "try",
  "typed": false,
  "parse_errors": [],
  "check_codes": [],
  "holds": [
    "review_embedded_example",
    "non_ast_example_or_text"
  ],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": false,
  "confirmation": "rejected"
}
```

## try-000010 — crates/benitoite/src/prelude/stdlib/IO/File.bnt:68

```json
{
  "id": "try-000010",
  "path": "crates/benitoite/src/prelude/stdlib/IO/File.bnt",
  "source_sha256": "fef0b8b27622af88fa7c9e0595d589b69cb1d389806dbc6e7e6ff70e33cb9b57",
  "after_sha256": "c4b14ed92036f0199260333be84761d9fcdb172cdbdfc128cb182be24ec344ce",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "library",
  "line": 68,
  "start": 3962,
  "end": 3981,
  "operand_end": 3981,
  "operand_host_end": 3981,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "copy",
    "public": true,
    "return_type": "Result[Unit, IOError]",
    "uses": "uses Read, Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "再利用する標準関数の Result と失敗値を変換せず呼び出し元へ返し、公開の uses を保つ。",
  "before": "try readBytes(from)",
  "after": "try readBytes(from) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000011 — crates/benitoite/src/prelude/stdlib/Network/Http.bnt:73

```json
{
  "id": "try-000011",
  "path": "crates/benitoite/src/prelude/stdlib/Network/Http.bnt",
  "source_sha256": "722bc0782f79b86fbda039c6f8b1ed75d020a075e74127bbb56b47b89d2d834e",
  "after_sha256": "c1ae05f484b3fb93da745f04d6bbf50767eb09ee96afb81728fd995e2067c36a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "library",
  "line": 73,
  "start": 3376,
  "end": 3410,
  "operand_end": 3410,
  "operand_host_end": 3410,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "serve",
    "public": true,
    "return_type": "Result[Unit, NetworkError]",
    "uses": "uses Listen, State, E"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "再利用する標準関数の Result と失敗値を変換せず呼び出し元へ返し、公開の uses を保つ。",
  "before": "try listen(host: host, port: port)",
  "after": "try listen(host: host, port: port) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000012 — crates/benitoite/src/prelude/stdlib/Network/Http.bnt:80

```json
{
  "id": "try-000012",
  "path": "crates/benitoite/src/prelude/stdlib/Network/Http.bnt",
  "source_sha256": "722bc0782f79b86fbda039c6f8b1ed75d020a075e74127bbb56b47b89d2d834e",
  "after_sha256": "8c1efef518d97743e6c37939cf7f27f5e706b615f6175d00bec441bfb9036ec5",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "library",
  "line": 80,
  "start": 3736,
  "end": 3756,
  "operand_end": 3756,
  "operand_host_end": 3756,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "serveLoop",
    "public": false,
    "return_type": "Result[Unit, NetworkError]",
    "uses": "uses Listen, State, E"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "再利用する標準関数の Result と失敗値を変換せず呼び出し元へ返し、公開の uses を保つ。",
  "before": "try accept(listener)",
  "after": "try accept(listener) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000013 — tools/bench/programs/http.bnt:23

```json
{
  "id": "try-000013",
  "path": "tools/bench/programs/http.bnt",
  "source_sha256": "2d575080d3fbf04c1a1d6a2ab0d530e79392d7e6c6d28a27d51fa4ae95fa5c7a",
  "after_sha256": "a32b53a58b2ec253d1677edd695f53e8118d7a28a77369bfedb3ee0c86dc1d2f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 23,
  "start": 1275,
  "end": 1282,
  "operand_end": 1282,
  "operand_host_end": 1282,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1240",
    "return_type": null,
    "uses": null
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try acc",
  "after": "try acc or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000014 — tools/bench/programs/http.bnt:27

```json
{
  "id": "try-000014",
  "path": "tools/bench/programs/http.bnt",
  "source_sha256": "2d575080d3fbf04c1a1d6a2ab0d530e79392d7e6c6d28a27d51fa4ae95fa5c7a",
  "after_sha256": "cca55e0622c3a88eff12c8bb2822704dd4ed1180b3ecd8b4ca3996409b5ecfa1",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 27,
  "start": 1358,
  "end": 1472,
  "operand_end": 1472,
  "operand_host_end": 1472,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "serve",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Http.Listen, State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Http.accept(listener) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda)",
  "after": "try Http.accept(listener) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000015 — tools/bench/programs/http.bnt:38

```json
{
  "id": "try-000015",
  "path": "tools/bench/programs/http.bnt",
  "source_sha256": "2d575080d3fbf04c1a1d6a2ab0d530e79392d7e6c6d28a27d51fa4ae95fa5c7a",
  "after_sha256": "bc14aaaf774d01286a87a3a5c561a45696c57de7a76ba7f06bf041c653fbec26",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 38,
  "start": 2021,
  "end": 2039,
  "operand_end": 2039,
  "operand_host_end": 2039,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Http.Listen, Console.Write, Process.Environment, State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try readInteger(0)",
  "after": "try readInteger(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000016 — tools/bench/programs/http.bnt:39

```json
{
  "id": "try-000016",
  "path": "tools/bench/programs/http.bnt",
  "source_sha256": "2d575080d3fbf04c1a1d6a2ab0d530e79392d7e6c6d28a27d51fa4ae95fa5c7a",
  "after_sha256": "ae292159b4c49af188644a0de0dcd580cf0517465d2bae934f9c0c925b231677",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 39,
  "start": 2055,
  "end": 2073,
  "operand_end": 2073,
  "operand_host_end": 2073,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Http.Listen, Console.Write, Process.Environment, State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try readInteger(1)",
  "after": "try readInteger(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000017 — tools/bench/programs/http.bnt:40

```json
{
  "id": "try-000017",
  "path": "tools/bench/programs/http.bnt",
  "source_sha256": "2d575080d3fbf04c1a1d6a2ab0d530e79392d7e6c6d28a27d51fa4ae95fa5c7a",
  "after_sha256": "15b33b00eeeca850aac2ba7a8103c52c7326a67c119a7dfab444c4609f17a6ee",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 40,
  "start": 2092,
  "end": 2224,
  "operand_end": 2224,
  "operand_host_end": 2224,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Http.Listen, Console.Write, Process.Environment, State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Http.listen(host: \"127.0.0.1\", port: 0) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda)",
  "after": "try Http.listen(host: \"127.0.0.1\", port: 0) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000018 — tools/bench/wasm/Runner.bnt:14

```json
{
  "id": "try-000018",
  "path": "tools/bench/wasm/Runner.bnt",
  "source_sha256": "a2f76d4d2cd00894b2b593cf9dda6996f3aa44a3dd62cb30c22dcda1ccd5be29",
  "after_sha256": "3ad1e17d9c029fc8c730413c7ba297bed413f53074da32391c17962e42056a6b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 14,
  "start": 658,
  "end": 677,
  "operand_end": 677,
  "operand_host_end": 677,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "rounds",
    "public": true,
    "return_type": "Result[Integer, String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try argument(index)",
  "after": "try argument(index) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000019 — tools/bench/wasm/Runner.bnt:15

```json
{
  "id": "try-000019",
  "path": "tools/bench/wasm/Runner.bnt",
  "source_sha256": "a2f76d4d2cd00894b2b593cf9dda6996f3aa44a3dd62cb30c22dcda1ccd5be29",
  "after_sha256": "6ba8acca4914de48b91f0924dd68126b36b0e45b93465bfdb87e34e2b24debe1",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 694,
  "end": 764,
  "operand_end": 764,
  "operand_host_end": 764,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "rounds",
    "public": true,
    "return_type": "Result[Integer, String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Integer.parse(text), error: \"invalid repeat count\")",
  "after": "try Option.okOr(o: Integer.parse(text), error: \"invalid repeat count\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000020 — tools/bench/wasm/Runner.bnt:21

```json
{
  "id": "try-000020",
  "path": "tools/bench/wasm/Runner.bnt",
  "source_sha256": "a2f76d4d2cd00894b2b593cf9dda6996f3aa44a3dd62cb30c22dcda1ccd5be29",
  "after_sha256": "138f38922e919584537ebff3bb581719b0d629a9cb18c05b29e58b308b442f78",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 21,
  "start": 1080,
  "end": 1090,
  "operand_end": 1090,
  "operand_host_end": 1090,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "repeat",
    "public": false,
    "return_type": "Result[A, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try work()",
  "after": "try work() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000021 — tools/bench/wasm/Runner.bnt:29

```json
{
  "id": "try-000021",
  "path": "tools/bench/wasm/Runner.bnt",
  "source_sha256": "a2f76d4d2cd00894b2b593cf9dda6996f3aa44a3dd62cb30c22dcda1ccd5be29",
  "after_sha256": "48b55abfd9d3fdec8d32367b5fec851ba0f41ee5e6cc20527679f64357ec88ca",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 29,
  "start": 1528,
  "end": 1538,
  "operand_end": 1538,
  "operand_host_end": 1538,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "measure",
    "public": true,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, Clock.Time, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try work()",
  "after": "try work() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000022 — tools/bench/wasm/Runner.bnt:31

```json
{
  "id": "try-000022",
  "path": "tools/bench/wasm/Runner.bnt",
  "source_sha256": "a2f76d4d2cd00894b2b593cf9dda6996f3aa44a3dd62cb30c22dcda1ccd5be29",
  "after_sha256": "a1af68fb9429ee0f3ad5eb0aad305aa794b3c539f7594204d4bfad5ce1899303",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 31,
  "start": 1603,
  "end": 1660,
  "operand_end": 1660,
  "operand_host_end": 1660,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "measure",
    "public": true,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, Clock.Time, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try repeat(remaining: count - 1, last: first, work: work)",
  "after": "try repeat(remaining: count - 1, last: first, work: work) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000023 — tools/bench/wasm/hash-a.bnt:10

```json
{
  "id": "try-000023",
  "path": "tools/bench/wasm/hash-a.bnt",
  "source_sha256": "0487d125c415039d841dcec3a9f1b331dc1126802c84d1636b55051136d4fdff",
  "after_sha256": "2c64d305371eeaf8a92523c7911a3a1df86255cf4d1d2ca2673fab50ce2aeb6a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 412,
  "end": 434,
  "operand_end": 434,
  "operand_host_end": 434,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000024 — tools/bench/wasm/hash-a.bnt:11

```json
{
  "id": "try-000024",
  "path": "tools/bench/wasm/hash-a.bnt",
  "source_sha256": "0487d125c415039d841dcec3a9f1b331dc1126802c84d1636b55051136d4fdff",
  "after_sha256": "d955018ab50b30f25d6d0b6f7cac7a35d1271ae2b05b747452d78ad6c56a3f89",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 11,
  "start": 451,
  "end": 471,
  "operand_end": 471,
  "operand_host_end": 471,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(1)",
  "after": "try Runner.rounds(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000025 — tools/bench/wasm/hash-a.bnt:12

```json
{
  "id": "try-000025",
  "path": "tools/bench/wasm/hash-a.bnt",
  "source_sha256": "0487d125c415039d841dcec3a9f1b331dc1126802c84d1636b55051136d4fdff",
  "after_sha256": "53d4361fa55210ac27c8c7ec548987f12480e56c78cc05d758c4ba00015d8e33",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 488,
  "end": 610,
  "operand_end": 610,
  "operand_host_end": 610,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000026 — tools/bench/wasm/hash-c-fast.bnt:15

```json
{
  "id": "try-000026",
  "path": "tools/bench/wasm/hash-c-fast.bnt",
  "source_sha256": "0e5acb60420ec79c575c3417919bda5d72751a59b430ee1db2d87f389274313c",
  "after_sha256": "16b0f073f24e27cfa98669edfbfb1f283ba1e72babcb2e07439ea94fd5bb3134",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 550,
  "end": 572,
  "operand_end": 572,
  "operand_host_end": 572,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000027 — tools/bench/wasm/hash-c-fast.bnt:16

```json
{
  "id": "try-000027",
  "path": "tools/bench/wasm/hash-c-fast.bnt",
  "source_sha256": "0e5acb60420ec79c575c3417919bda5d72751a59b430ee1db2d87f389274313c",
  "after_sha256": "c5c577d11fc846b871f7fd0e929254a23d844d0bc8b216f2c3a8acc4cd927fa3",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 16,
  "start": 589,
  "end": 609,
  "operand_end": 609,
  "operand_host_end": 609,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(1)",
  "after": "try Runner.rounds(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000028 — tools/bench/wasm/hash-c-fast.bnt:17

```json
{
  "id": "try-000028",
  "path": "tools/bench/wasm/hash-c-fast.bnt",
  "source_sha256": "0e5acb60420ec79c575c3417919bda5d72751a59b430ee1db2d87f389274313c",
  "after_sha256": "5ec72015861113e0fc5bf5fbfd2fd98dcb2d9495e07a0818c18108e75814a219",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 626,
  "end": 748,
  "operand_end": 748,
  "operand_host_end": 748,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000029 — tools/bench/wasm/hash-c-list.bnt:15

```json
{
  "id": "try-000029",
  "path": "tools/bench/wasm/hash-c-list.bnt",
  "source_sha256": "209868fa66227b6bc413c4fd3d597b2f6de60eff946f92095c0a1a3d8453625c",
  "after_sha256": "0fb30af5db2388f4439f6654b17b27315828b541ca0df449a9c693432eac3d8b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 550,
  "end": 572,
  "operand_end": 572,
  "operand_host_end": 572,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000030 — tools/bench/wasm/hash-c-list.bnt:16

```json
{
  "id": "try-000030",
  "path": "tools/bench/wasm/hash-c-list.bnt",
  "source_sha256": "209868fa66227b6bc413c4fd3d597b2f6de60eff946f92095c0a1a3d8453625c",
  "after_sha256": "ddb78fbeb654e7bf313100d07e9de249279e80682ce3ca9beef0feb85f7ee600",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 16,
  "start": 589,
  "end": 609,
  "operand_end": 609,
  "operand_host_end": 609,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(1)",
  "after": "try Runner.rounds(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000031 — tools/bench/wasm/hash-c-list.bnt:17

```json
{
  "id": "try-000031",
  "path": "tools/bench/wasm/hash-c-list.bnt",
  "source_sha256": "209868fa66227b6bc413c4fd3d597b2f6de60eff946f92095c0a1a3d8453625c",
  "after_sha256": "94068dbebd282b1f736f1b86a33fa9ffaff35baa6d6206ea5eb92db87b170bee",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 626,
  "end": 748,
  "operand_end": 748,
  "operand_host_end": 748,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readBytes(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000032 — tools/bench/wasm/json-a.bnt:17

```json
{
  "id": "try-000032",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "e8089417c68c9cd86bae386ef931ac7293ee78d2acd47db2b36b20b5a22eb659",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 802,
  "end": 824,
  "operand_end": 824,
  "operand_host_end": 824,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000033 — tools/bench/wasm/json-a.bnt:18

```json
{
  "id": "try-000033",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "5cb349588a3c5fd14746f7bb4cdce9752600fe4f053ad0afd8fc7e87fafee39a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 18,
  "start": 840,
  "end": 862,
  "operand_end": 862,
  "operand_host_end": 862,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000034 — tools/bench/wasm/json-a.bnt:19

```json
{
  "id": "try-000034",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "ff8176d6c958f4599469d1ff8661aa7c752579c85ed6e1b26c764083503f741d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 19,
  "start": 879,
  "end": 899,
  "operand_end": 899,
  "operand_host_end": 899,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000035 — tools/bench/wasm/json-a.bnt:20

```json
{
  "id": "try-000035",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "e0723fb7281c7c0b304967b461652ba5d5756f797cbc25711f583cb231c7c4b0",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 20,
  "start": 917,
  "end": 1038,
  "operand_end": 1038,
  "operand_host_end": 1038,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000036 — tools/bench/wasm/json-a.bnt:29

```json
{
  "id": "try-000036",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "daa09f80de25c71b6a00fe4e3336bee72557270b4909be7b131095666dd3ab94",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 29,
  "start": 1847,
  "end": 1956,
  "operand_end": 1956,
  "operand_host_end": 1956,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000037 — tools/bench/wasm/json-a.bnt:34

```json
{
  "id": "try-000037",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "c01a8c8006605704a440ced1f556753f40fd9b9688fe82e91a43127a284bc94d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 34,
  "start": 2313,
  "end": 2422,
  "operand_end": 2422,
  "operand_host_end": 2422,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@2246",
    "return_type": "Result[String, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000038 — tools/bench/wasm/json-a.bnt:40

```json
{
  "id": "try-000038",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "7f187d46fc728e9c58859790f2d7e47e4608308c19409ff980d67698ac98910f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 40,
  "start": 2689,
  "end": 2798,
  "operand_end": 2798,
  "operand_host_end": 2798,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@2622",
    "return_type": "Result[String, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000039 — tools/bench/wasm/json-a.bnt:48

```json
{
  "id": "try-000039",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "995e98bb82749e66f445a9cb5e48a3b18c0416d48c74a37022a543d8b2bc31ca",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 48,
  "start": 3381,
  "end": 3490,
  "operand_end": 3490,
  "operand_host_end": 3490,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000040 — tools/bench/wasm/json-a.bnt:53

```json
{
  "id": "try-000040",
  "path": "tools/bench/wasm/json-a.bnt",
  "source_sha256": "b1edbb7c5bb1e02049f64e1efc986b0d65af5fd24c7371e2dc660e853d83e6c0",
  "after_sha256": "ae5fefdfbc1e2c0a9cba7b06db88c51b28a9fe128b124dbc3812f34f44d09432",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 53,
  "start": 3616,
  "end": 3725,
  "operand_end": 3725,
  "operand_host_end": 3725,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000041 — tools/bench/wasm/json-b.bnt:22

```json
{
  "id": "try-000041",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "30924535353cdd2ee53e78378549c178a469ca28eefdf188d5f76133f5c0cb7f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 22,
  "start": 940,
  "end": 962,
  "operand_end": 962,
  "operand_host_end": 962,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000042 — tools/bench/wasm/json-b.bnt:23

```json
{
  "id": "try-000042",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "82b408668e5a58318b1cbc4a2e1163d6d6bfe4ce08d515b689569c39418ac632",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 23,
  "start": 978,
  "end": 1000,
  "operand_end": 1000,
  "operand_host_end": 1000,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000043 — tools/bench/wasm/json-b.bnt:24

```json
{
  "id": "try-000043",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "bb06eb74509c267a8a1542c92344d66cedcb5b41eb0944904c15cf4f225a128c",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 24,
  "start": 1017,
  "end": 1037,
  "operand_end": 1037,
  "operand_host_end": 1037,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000044 — tools/bench/wasm/json-b.bnt:25

```json
{
  "id": "try-000044",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "dee08385854308bcfa920afec2830f39534010fe80f9c80cd3cb8c18091a6d9f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 25,
  "start": 1055,
  "end": 1176,
  "operand_end": 1176,
  "operand_host_end": 1176,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000045 — tools/bench/wasm/json-b.bnt:34

```json
{
  "id": "try-000045",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "9459bd1425e19146d51304b18f42dcf82ac0e949b5618338fa7415886b79a548",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 34,
  "start": 1989,
  "end": 2098,
  "operand_end": 2098,
  "operand_host_end": 2098,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000046 — tools/bench/wasm/json-b.bnt:39

```json
{
  "id": "try-000046",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "e2c982498b6fa9eee3d6cd1f2693013d97d9006f5d0103d7d8068ae85b5e71ab",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 39,
  "start": 2457,
  "end": 2568,
  "operand_end": 2568,
  "operand_host_end": 2568,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@2390",
    "return_type": "Result[String, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000047 — tools/bench/wasm/json-b.bnt:45

```json
{
  "id": "try-000047",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "ebdb65efad415a89e36b72cf893de3bf2dcda9273ee75c72e05bf5262de52111",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 45,
  "start": 2835,
  "end": 2946,
  "operand_end": 2946,
  "operand_host_end": 2946,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@2768",
    "return_type": "Result[String, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000048 — tools/bench/wasm/json-b.bnt:53

```json
{
  "id": "try-000048",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "2d3712eb7952d8f974a70d55bdca3ae4c466984b8003d2ea585d5abb4db68f30",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 53,
  "start": 3533,
  "end": 3644,
  "operand_end": 3644,
  "operand_host_end": 3644,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000049 — tools/bench/wasm/json-b.bnt:58

```json
{
  "id": "try-000049",
  "path": "tools/bench/wasm/json-b.bnt",
  "source_sha256": "66c9f953bfc6cfd40da2d38ef89f7e646006a0e64e3235ea6c94c95acbbf4315",
  "after_sha256": "1af3a02fb7352e51f2a4101e38cc35fbae2f9efc6f161f7e91e59913ead1ae0d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 58,
  "start": 3772,
  "end": 3883,
  "operand_end": 3883,
  "operand_host_end": 3883,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Parser.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000050 — tools/bench/wasm/json-c.bnt:15

```json
{
  "id": "try-000050",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "407d54d7c2f0b9c4b70124d4f7291de5a038af64c76ab7ff476fa9d6db5d341b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 558,
  "end": 580,
  "operand_end": 580,
  "operand_host_end": 580,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000051 — tools/bench/wasm/json-c.bnt:16

```json
{
  "id": "try-000051",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "d0ba741fb844dcd3a875a8b1438f0ae3742e047ff22e5eba0fc70756f2aeb87f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 16,
  "start": 596,
  "end": 618,
  "operand_end": 618,
  "operand_host_end": 618,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000052 — tools/bench/wasm/json-c.bnt:17

```json
{
  "id": "try-000052",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "f18c8b576b31925b8fec6e465cc8b5f2074e7bc71f21defb1a017a3a23c4e383",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 635,
  "end": 655,
  "operand_end": 655,
  "operand_host_end": 655,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000053 — tools/bench/wasm/json-c.bnt:18

```json
{
  "id": "try-000053",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "2afd9799873c3892ccf1f4995bb882c171c7e82f85fc1e751462dee9e49b9581",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 18,
  "start": 673,
  "end": 794,
  "operand_end": 794,
  "operand_host_end": 794,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000054 — tools/bench/wasm/json-c.bnt:23

```json
{
  "id": "try-000054",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "f6aa8a35c7eddd655078f83067ad48205dda7322eda1934e672118be1c85ea2a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 23,
  "start": 1172,
  "end": 1281,
  "operand_end": 1281,
  "operand_host_end": 1281,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Json.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000055 — tools/bench/wasm/json-c.bnt:28

```json
{
  "id": "try-000055",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "1ad56c53829efa85b5d4e3779154f0fa0d39083c051e0d2290fe55189bf31a70",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 28,
  "start": 1625,
  "end": 1738,
  "operand_end": 1738,
  "operand_host_end": 1738,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1561",
    "return_type": "Result[String, String]",
    "uses": "uses State"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Codec.document(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Codec.document(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000056 — tools/bench/wasm/json-c.bnt:41

```json
{
  "id": "try-000056",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "ea0bba8c1016412255dee5c2c3768c407be00be40143c5cfd376a9265b5350b7",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 41,
  "start": 2793,
  "end": 2903,
  "operand_end": 2903,
  "operand_host_end": 2903,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Codec.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Codec.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000057 — tools/bench/wasm/json-c.bnt:42

```json
{
  "id": "try-000057",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "52050c74eca4bca542341eac61d02304d087e031fa3e49207f30c163322092e0",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 42,
  "start": 2926,
  "end": 2953,
  "operand_end": 2953,
  "operand_host_end": 2953,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Codec.stringify(parsed)",
  "after": "try Codec.stringify(parsed) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000058 — tools/bench/wasm/json-c.bnt:46

```json
{
  "id": "try-000058",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "596f0d4f3b3214221ddc03440aee639af8ee84fe31b1bf35f7f0b1d9701e2560",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 46,
  "start": 3034,
  "end": 3144,
  "operand_end": 3144,
  "operand_host_end": 3144,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: Codec.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Result.mapError(r: Codec.parse(source), f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000059 — tools/bench/wasm/json-c.bnt:47

```json
{
  "id": "try-000059",
  "path": "tools/bench/wasm/json-c.bnt",
  "source_sha256": "cc16048444c2a31c86fa9ee3a5c7e2b7c73e2b1309bf936c3e5573c8368e439e",
  "after_sha256": "626e4caf8654983856f12b87f5fb55b9ed602d26e2640652a9ec79b7e1090304",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 47,
  "start": 3164,
  "end": 3191,
  "operand_end": 3191,
  "operand_host_end": 3191,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Codec.stringify(parsed)",
  "after": "try Codec.stringify(parsed) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000060 — tools/bench/wasm/regex-a.bnt:10

```json
{
  "id": "try-000060",
  "path": "tools/bench/wasm/regex-a.bnt",
  "source_sha256": "150cb0453ed700e8360ece404e052157eef48eb4d32a6faf6370edeefe062c7c",
  "after_sha256": "85c67dd17765b6765986d074dcc0ea1a4cb333e7154c0b1a29c3352ce61fff34",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 432,
  "end": 454,
  "operand_end": 454,
  "operand_host_end": 454,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000061 — tools/bench/wasm/regex-a.bnt:11

```json
{
  "id": "try-000061",
  "path": "tools/bench/wasm/regex-a.bnt",
  "source_sha256": "150cb0453ed700e8360ece404e052157eef48eb4d32a6faf6370edeefe062c7c",
  "after_sha256": "495d74da0d1302365ed1404d19fe240aa6839cd3f21270ac9441f8afbd22f55d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 11,
  "start": 470,
  "end": 492,
  "operand_end": 492,
  "operand_host_end": 492,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000062 — tools/bench/wasm/regex-a.bnt:12

```json
{
  "id": "try-000062",
  "path": "tools/bench/wasm/regex-a.bnt",
  "source_sha256": "150cb0453ed700e8360ece404e052157eef48eb4d32a6faf6370edeefe062c7c",
  "after_sha256": "d7ed9cd5f320d4f1615d169d3d29cc3e6f5c2198ac61873db1f9ab3b0b3d324f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 509,
  "end": 529,
  "operand_end": 529,
  "operand_host_end": 529,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000063 — tools/bench/wasm/regex-a.bnt:14

```json
{
  "id": "try-000063",
  "path": "tools/bench/wasm/regex-a.bnt",
  "source_sha256": "150cb0453ed700e8360ece404e052157eef48eb4d32a6faf6370edeefe062c7c",
  "after_sha256": "b5d980837b962d866453866f3112b6f991405932d4a06e33f73198852b0a8178",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 14,
  "start": 578,
  "end": 699,
  "operand_end": 699,
  "operand_host_end": 699,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000064 — tools/bench/wasm/regex-a.bnt:15

```json
{
  "id": "try-000064",
  "path": "tools/bench/wasm/regex-a.bnt",
  "source_sha256": "150cb0453ed700e8360ece404e052157eef48eb4d32a6faf6370edeefe062c7c",
  "after_sha256": "d8fd6f3524cf22ab579f895fb9b308e8724ecd5fd49ec4506efdc3a3a08b2489",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 718,
  "end": 743,
  "operand_end": 743,
  "operand_host_end": 743,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Regex.compile(source)",
  "after": "try Regex.compile(source) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000065 — tools/bench/wasm/regex-c-once.bnt:15

```json
{
  "id": "try-000065",
  "path": "tools/bench/wasm/regex-c-once.bnt",
  "source_sha256": "2a49cd81ea4e8a8d49c4202c9d3503f2bff63ca22f6f41a855c9f0c8983d3de7",
  "after_sha256": "c766b709c21f379b180f3d6bcaa38fbe60c9e358cd578b369d12cfadd1f6e6e8",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 574,
  "end": 596,
  "operand_end": 596,
  "operand_host_end": 596,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000066 — tools/bench/wasm/regex-c-once.bnt:16

```json
{
  "id": "try-000066",
  "path": "tools/bench/wasm/regex-c-once.bnt",
  "source_sha256": "2a49cd81ea4e8a8d49c4202c9d3503f2bff63ca22f6f41a855c9f0c8983d3de7",
  "after_sha256": "603b6bce67565a2e0ac0b0542a69a710c19cfe74acdc70f091d6aa8b5dd61d8a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 16,
  "start": 612,
  "end": 634,
  "operand_end": 634,
  "operand_host_end": 634,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000067 — tools/bench/wasm/regex-c-once.bnt:17

```json
{
  "id": "try-000067",
  "path": "tools/bench/wasm/regex-c-once.bnt",
  "source_sha256": "2a49cd81ea4e8a8d49c4202c9d3503f2bff63ca22f6f41a855c9f0c8983d3de7",
  "after_sha256": "8d7d663f9dfc3e195163dc36901c678f9637b1cd3260cb6f85896e305a696037",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 651,
  "end": 671,
  "operand_end": 671,
  "operand_host_end": 671,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000068 — tools/bench/wasm/regex-c-once.bnt:19

```json
{
  "id": "try-000068",
  "path": "tools/bench/wasm/regex-c-once.bnt",
  "source_sha256": "2a49cd81ea4e8a8d49c4202c9d3503f2bff63ca22f6f41a855c9f0c8983d3de7",
  "after_sha256": "33dcbc6876509f9c74942f716c957422c1ef65d21fee1b9b10290ab0355ad8bb",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 19,
  "start": 720,
  "end": 841,
  "operand_end": 841,
  "operand_host_end": 841,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000069 — tools/bench/wasm/regex-c-resource.bnt:15

```json
{
  "id": "try-000069",
  "path": "tools/bench/wasm/regex-c-resource.bnt",
  "source_sha256": "d59bff625ae3b50c410c0b36de19ff64284aabbbff70a36f9ce2f4a7b8dd278e",
  "after_sha256": "281b8ed434c4f3af176419ee993a4e9d3af48884c4118328b11b6c0cd8b3d1df",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 574,
  "end": 596,
  "operand_end": 596,
  "operand_host_end": 596,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(0)",
  "after": "try Runner.argument(0) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000070 — tools/bench/wasm/regex-c-resource.bnt:16

```json
{
  "id": "try-000070",
  "path": "tools/bench/wasm/regex-c-resource.bnt",
  "source_sha256": "d59bff625ae3b50c410c0b36de19ff64284aabbbff70a36f9ce2f4a7b8dd278e",
  "after_sha256": "b77e21383a12b7b9ababa4547741b81d88f4ba60e7d4b3a18323383844348602",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 16,
  "start": 612,
  "end": 634,
  "operand_end": 634,
  "operand_host_end": 634,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.argument(1)",
  "after": "try Runner.argument(1) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000071 — tools/bench/wasm/regex-c-resource.bnt:17

```json
{
  "id": "try-000071",
  "path": "tools/bench/wasm/regex-c-resource.bnt",
  "source_sha256": "d59bff625ae3b50c410c0b36de19ff64284aabbbff70a36f9ce2f4a7b8dd278e",
  "after_sha256": "0c382fcaf765dbc8c5a01417ce4bd8813828e9ec620756dd1310e7d6542c2acc",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 17,
  "start": 651,
  "end": 671,
  "operand_end": 671,
  "operand_host_end": 671,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.rounds(2)",
  "after": "try Runner.rounds(2) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000072 — tools/bench/wasm/regex-c-resource.bnt:19

```json
{
  "id": "try-000072",
  "path": "tools/bench/wasm/regex-c-resource.bnt",
  "source_sha256": "d59bff625ae3b50c410c0b36de19ff64284aabbbff70a36f9ce2f4a7b8dd278e",
  "after_sha256": "dee6fef6a67ebf5c5aa1283797e2b2c2b35ca21d844de88fb3260807506dd0b6",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 19,
  "start": 720,
  "end": 841,
  "operand_end": 841,
  "operand_host_end": 841,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda)",
  "after": "try Result.mapError(r: File.readText(path), f: lambda(error: IOError) -> String return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000073 — tools/bench/wasm/regex-c-resource.bnt:20

```json
{
  "id": "try-000073",
  "path": "tools/bench/wasm/regex-c-resource.bnt",
  "source_sha256": "d59bff625ae3b50c410c0b36de19ff64284aabbbff70a36f9ce2f4a7b8dd278e",
  "after_sha256": "9753e0ff2c9695718d60a1736419a6bb0aacab1405c92a46cc85ba1f0a9da171",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 20,
  "start": 860,
  "end": 887,
  "operand_end": 887,
  "operand_host_end": 887,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses State, File.Read, Clock.Time, Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Pattern.compile(source)",
  "after": "try Pattern.compile(source) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000074 — tools/bench/wit-transfer/Runner.bnt:8

```json
{
  "id": "try-000074",
  "path": "tools/bench/wit-transfer/Runner.bnt",
  "source_sha256": "4688aa1d6dd93a0d5afab89722e15a108a4d24834b588b3e60a256645acd1fac",
  "after_sha256": "8b1749322a8061aa56ff5d61d3a7f09835769f17a02259b9f61138ddb1c9e6fb",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 8,
  "start": 397,
  "end": 475,
  "operand_end": 475,
  "operand_host_end": 475,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "settings",
    "public": true,
    "return_type": "Result[Pair[Integer, Integer], String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: List.get(xs: arguments, i: 0), error: \"missing input size\")",
  "after": "try Option.okOr(o: List.get(xs: arguments, i: 0), error: \"missing input size\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000075 — tools/bench/wit-transfer/Runner.bnt:9

```json
{
  "id": "try-000075",
  "path": "tools/bench/wit-transfer/Runner.bnt",
  "source_sha256": "4688aa1d6dd93a0d5afab89722e15a108a4d24834b588b3e60a256645acd1fac",
  "after_sha256": "3fff48261e658b3fbb9672a8ee6c2b4dc7d6a0be976e15ef25518f255979e9b7",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 9,
  "start": 492,
  "end": 560,
  "operand_end": 560,
  "operand_host_end": 560,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "settings",
    "public": true,
    "return_type": "Result[Pair[Integer, Integer], String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Integer.parse(text), error: \"invalid input size\")",
  "after": "try Option.okOr(o: Integer.parse(text), error: \"invalid input size\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000076 — tools/bench/wit-transfer/Runner.bnt:10

```json
{
  "id": "try-000076",
  "path": "tools/bench/wit-transfer/Runner.bnt",
  "source_sha256": "4688aa1d6dd93a0d5afab89722e15a108a4d24834b588b3e60a256645acd1fac",
  "after_sha256": "706c4bb81989d3ee86306971ad0b6d238734e4c561f6318f6b5f2134cb472d57",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 582,
  "end": 662,
  "operand_end": 662,
  "operand_host_end": 662,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "settings",
    "public": true,
    "return_type": "Result[Pair[Integer, Integer], String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: List.get(xs: arguments, i: 1), error: \"missing repeat count\")",
  "after": "try Option.okOr(o: List.get(xs: arguments, i: 1), error: \"missing repeat count\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000077 — tools/bench/wit-transfer/Runner.bnt:11

```json
{
  "id": "try-000077",
  "path": "tools/bench/wit-transfer/Runner.bnt",
  "source_sha256": "4688aa1d6dd93a0d5afab89722e15a108a4d24834b588b3e60a256645acd1fac",
  "after_sha256": "ceceb075429f7aed8af79846a0dca951018d1f219a738ab2c82caae660a41c7e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 11,
  "start": 680,
  "end": 756,
  "operand_end": 756,
  "operand_host_end": 756,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "settings",
    "public": true,
    "return_type": "Result[Pair[Integer, Integer], String]",
    "uses": "uses Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Integer.parse(roundsText), error: \"invalid repeat count\")",
  "after": "try Option.okOr(o: Integer.parse(roundsText), error: \"invalid repeat count\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000078 — tools/bench/wit-transfer/flags.bnt:122

```json
{
  "id": "try-000078",
  "path": "tools/bench/wit-transfer/flags.bnt",
  "source_sha256": "6fa6991b8be4b956d6e6ebd7e3c1fa7296efcd869de879f6df572d3f8b8306bd",
  "after_sha256": "19f3c084fca4a80ff531af5910011dac9ed8aab02f0c9c017fe157df73da7d5c",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 122,
  "start": 1514,
  "end": 1535,
  "operand_end": 1535,
  "operand_host_end": 1535,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000079 — tools/bench/wit-transfer/large-bytes-adapter.bnt:10

```json
{
  "id": "try-000079",
  "path": "tools/bench/wit-transfer/large-bytes-adapter.bnt",
  "source_sha256": "34f1dc6b892833beb1552fe00c887bf0afec8afb732bfe0636723b378b98ad24",
  "after_sha256": "d1314d988723883ce1deb0885bf64d90908d6318f91431acc9ee7bd3c610655e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 385,
  "end": 406,
  "operand_end": 406,
  "operand_host_end": 406,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000080 — tools/bench/wit-transfer/large-bytes-typed.bnt:10

```json
{
  "id": "try-000080",
  "path": "tools/bench/wit-transfer/large-bytes-typed.bnt",
  "source_sha256": "b25e1d165b9d0a7c811b4bdf28321007b9455ea8b6f2161eaca86eec483192a3",
  "after_sha256": "191023231eda3d4edc082d89b770d973b4b7315568198447dda6a92bca73f4a3",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 380,
  "end": 401,
  "operand_end": 401,
  "operand_host_end": 401,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000081 — tools/bench/wit-transfer/large-bytes-typed.bnt:11

```json
{
  "id": "try-000081",
  "path": "tools/bench/wit-transfer/large-bytes-typed.bnt",
  "source_sha256": "b25e1d165b9d0a7c811b4bdf28321007b9455ea8b6f2161eaca86eec483192a3",
  "after_sha256": "12ce9aa71950ffeb8c4b8e1b9aeab59af7d03a6f37192d9047583415d6de073a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 11,
  "start": 416,
  "end": 483,
  "operand_end": 483,
  "operand_host_end": 483,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Byte.fromInteger(0), error: \"byte out of range\")",
  "after": "try Option.okOr(o: Byte.fromInteger(0), error: \"byte out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000082 — tools/bench/wit-transfer/large-bytes-typed.bnt:12

```json
{
  "id": "try-000082",
  "path": "tools/bench/wit-transfer/large-bytes-typed.bnt",
  "source_sha256": "b25e1d165b9d0a7c811b4bdf28321007b9455ea8b6f2161eaca86eec483192a3",
  "after_sha256": "ee3140160c26e087503d557ee45011935f51b7cb7d43a0eb0240d81a0f5a22b4",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 501,
  "end": 570,
  "operand_end": 570,
  "operand_host_end": 570,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Byte.fromInteger(128), error: \"byte out of range\")",
  "after": "try Option.okOr(o: Byte.fromInteger(128), error: \"byte out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000083 — tools/bench/wit-transfer/large-bytes-typed.bnt:13

```json
{
  "id": "try-000083",
  "path": "tools/bench/wit-transfer/large-bytes-typed.bnt",
  "source_sha256": "b25e1d165b9d0a7c811b4bdf28321007b9455ea8b6f2161eaca86eec483192a3",
  "after_sha256": "cfa0dbfd265c7b232fe23fa5ec86fa6bde5807d4415f63d7c86901bf05cb5d4b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 13,
  "start": 586,
  "end": 655,
  "operand_end": 655,
  "operand_host_end": 655,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Byte.fromInteger(255), error: \"byte out of range\")",
  "after": "try Option.okOr(o: Byte.fromInteger(255), error: \"byte out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000084 — tools/bench/wit-transfer/large-bytes-typed.bnt:14

```json
{
  "id": "try-000084",
  "path": "tools/bench/wit-transfer/large-bytes-typed.bnt",
  "source_sha256": "b25e1d165b9d0a7c811b4bdf28321007b9455ea8b6f2161eaca86eec483192a3",
  "after_sha256": "d01e113c9f36c1b7494afa37445d49fb5326d25b7b40be529a2c2af56993b65d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 14,
  "start": 680,
  "end": 749,
  "operand_end": 749,
  "operand_host_end": 749,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: Byte.fromInteger(127), error: \"byte out of range\")",
  "after": "try Option.okOr(o: Byte.fromInteger(127), error: \"byte out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000085 — tools/bench/wit-transfer/large-bytes.bnt:12

```json
{
  "id": "try-000085",
  "path": "tools/bench/wit-transfer/large-bytes.bnt",
  "source_sha256": "56427bd41af1ca70cefeee798b4b4348f6f24acc40cf481ca03670c3a826cf23",
  "after_sha256": "e0211cf01761b949ee621a8dfdd1eb7df974a13ca2debf849b617909142fab29",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 470,
  "end": 491,
  "operand_end": 491,
  "operand_host_end": 491,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000086 — tools/bench/wit-transfer/maps.bnt:13

```json
{
  "id": "try-000086",
  "path": "tools/bench/wit-transfer/maps.bnt",
  "source_sha256": "63506619538a00303694af591c09769bb8de89b991135479cab442e61835a7df",
  "after_sha256": "f3f1660649af20547b94160df7656f2a71e8779acea1f91659cdad9b2a8d3636",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 13,
  "start": 604,
  "end": 625,
  "operand_end": 625,
  "operand_host_end": 625,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000087 — tools/bench/wit-transfer/nested.bnt:10

```json
{
  "id": "try-000087",
  "path": "tools/bench/wit-transfer/nested.bnt",
  "source_sha256": "8cba6064b419a2cd7603504ebdadc992bb4dfa589749cc8f8e27b9e44434b6cc",
  "after_sha256": "70d3ccc505260f0e581f821a3b5038cdda043ff473fe91b3f112b29c7d3d07f4",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 407,
  "end": 428,
  "operand_end": 428,
  "operand_host_end": 428,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000088 — tools/bench/wit-transfer/numbers.bnt:43

```json
{
  "id": "try-000088",
  "path": "tools/bench/wit-transfer/numbers.bnt",
  "source_sha256": "7c431fed446ca3b12d41addeca71515c3704514a0a34a02ada3778ed5efd452a",
  "after_sha256": "be61381546e2e4aeafb3dbdc00fb5588bf56a284faed894dfa3c1b90ec4c8af6",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 43,
  "start": 2287,
  "end": 2308,
  "operand_end": 2308,
  "operand_host_end": 2308,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000089 — tools/bench/wit-transfer/primitives.bnt:18

```json
{
  "id": "try-000089",
  "path": "tools/bench/wit-transfer/primitives.bnt",
  "source_sha256": "87ffd762a0a9cc1de0a44972c645a3eab6338a767ca6b93ee69e107c354fc532",
  "after_sha256": "d7888bbebcd7cf8d0b0cf6679e1f50555595ba965184fa48cd18a90a542a5ad2",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 18,
  "start": 779,
  "end": 800,
  "operand_end": 800,
  "operand_host_end": 800,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000090 — tools/bench/wit-transfer/records.bnt:30

```json
{
  "id": "try-000090",
  "path": "tools/bench/wit-transfer/records.bnt",
  "source_sha256": "77c2252d5d0076cd93ca54a3eaa2dad8c8be3b68120b488322ead5803fa9cde3",
  "after_sha256": "4ea18dabc636e9f86395a18ada542a87b285f7663896ac0cebb034761c276137",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 30,
  "start": 860,
  "end": 881,
  "operand_end": 881,
  "operand_host_end": 881,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000091 — tools/bench/wit-transfer/short-numbers-adapter.bnt:10

```json
{
  "id": "try-000091",
  "path": "tools/bench/wit-transfer/short-numbers-adapter.bnt",
  "source_sha256": "9f2a06ad7ef998bbd5ace910ac65f8d38645ccda8816757d059a1cea134ac9b5",
  "after_sha256": "995f3da5eb3f779344fdec85292f02731734d27f72a2bd423fe09fe8bae473fe",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 384,
  "end": 405,
  "operand_end": 405,
  "operand_host_end": 405,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000092 — tools/bench/wit-transfer/short-numbers-adapter.bnt:11

```json
{
  "id": "try-000092",
  "path": "tools/bench/wit-transfer/short-numbers-adapter.bnt",
  "source_sha256": "9f2a06ad7ef998bbd5ace910ac65f8d38645ccda8816757d059a1cea134ac9b5",
  "after_sha256": "837883fa7daf76c939c3f5caa53aa543594f1cae0837b0ba8314790a9b430b17",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 11,
  "start": 421,
  "end": 503,
  "operand_end": 503,
  "operand_host_end": 503,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: UnsignedInteger64.fromInteger(n), error: \"number out of range\")",
  "after": "try Option.okOr(o: UnsignedInteger64.fromInteger(n), error: \"number out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000093 — tools/bench/wit-transfer/short-numbers-adapter.bnt:13

```json
{
  "id": "try-000093",
  "path": "tools/bench/wit-transfer/short-numbers-adapter.bnt",
  "source_sha256": "9f2a06ad7ef998bbd5ace910ac65f8d38645ccda8816757d059a1cea134ac9b5",
  "after_sha256": "7eaaa5e692ddebe155414a3297b27956883446adb8dcb2b1f80debf7d2fbb706",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 13,
  "start": 590,
  "end": 679,
  "operand_end": 679,
  "operand_host_end": 679,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: UnsignedInteger64.fromInteger(expected), error: \"number out of range\")",
  "after": "try Option.okOr(o: UnsignedInteger64.fromInteger(expected), error: \"number out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000094 — tools/bench/wit-transfer/short-numbers-typed.bnt:10

```json
{
  "id": "try-000094",
  "path": "tools/bench/wit-transfer/short-numbers-typed.bnt",
  "source_sha256": "98ff885356cf843f5131280ccb06a100154c3e6346b60444a74b62a4778fc030",
  "after_sha256": "734d5b7d19dd79ff7e92d6aebb90b1d6b5fae71aa6772f0efc4d75f74a421a8e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 10,
  "start": 389,
  "end": 410,
  "operand_end": 410,
  "operand_host_end": 410,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000095 — tools/bench/wit-transfer/short-numbers.bnt:12

```json
{
  "id": "try-000095",
  "path": "tools/bench/wit-transfer/short-numbers.bnt",
  "source_sha256": "f3e0b075088d5fea1bba1b9fa1e4e75bba6c96f4d5c0013d694d0f0ddd4d4835",
  "after_sha256": "5172b426b465b78034f0c1ed0067f01f0366f31e9bc4eef6c16873c6dc1b5c92",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 466,
  "end": 487,
  "operand_end": 487,
  "operand_host_end": 487,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000096 — tools/bench/wit-transfer/short-numbers.bnt:13

```json
{
  "id": "try-000096",
  "path": "tools/bench/wit-transfer/short-numbers.bnt",
  "source_sha256": "f3e0b075088d5fea1bba1b9fa1e4e75bba6c96f4d5c0013d694d0f0ddd4d4835",
  "after_sha256": "87d7e476412b4d3c6931db753cae49e47f1a5ab9fd3dac7113db53790fd1a726",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 13,
  "start": 503,
  "end": 585,
  "operand_end": 585,
  "operand_host_end": 585,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: UnsignedInteger64.fromInteger(n), error: \"number out of range\")",
  "after": "try Option.okOr(o: UnsignedInteger64.fromInteger(n), error: \"number out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000097 — tools/bench/wit-transfer/short-numbers.bnt:15

```json
{
  "id": "try-000097",
  "path": "tools/bench/wit-transfer/short-numbers.bnt",
  "source_sha256": "f3e0b075088d5fea1bba1b9fa1e4e75bba6c96f4d5c0013d694d0f0ddd4d4835",
  "after_sha256": "6159665f76c381436aaeb5abe9790c4cb4562cd7c31929abe70554b22b663f6e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 15,
  "start": 672,
  "end": 761,
  "operand_end": 761,
  "operand_host_end": 761,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Option.okOr(o: UnsignedInteger64.fromInteger(expected), error: \"number out of range\")",
  "after": "try Option.okOr(o: UnsignedInteger64.fromInteger(expected), error: \"number out of range\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000098 — tools/bench/wit-transfer/tuples.bnt:29

```json
{
  "id": "try-000098",
  "path": "tools/bench/wit-transfer/tuples.bnt",
  "source_sha256": "1595d9523ceb277e3dc39d750ac18fb0ef8a83001873bbbd30f031e379367a7c",
  "after_sha256": "7cb7c57e1ac12831bb9e1b1d90633584f55b12d5c5955c6ee79fcdeb61f62cb5",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 29,
  "start": 856,
  "end": 877,
  "operand_end": 877,
  "operand_host_end": 877,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000099 — tools/bench/wit-transfer/utf16.bnt:12

```json
{
  "id": "try-000099",
  "path": "tools/bench/wit-transfer/utf16.bnt",
  "source_sha256": "48c00c623feebd469fb8a13f02d220d3ca02741afac928f0223c9473bccb9423",
  "after_sha256": "70905346dece7229d8bb86f30d3b8b2d01a6b70df22c05ebde5b41ec86d43084",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 12,
  "start": 477,
  "end": 498,
  "operand_end": 498,
  "operand_host_end": 498,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000100 — tools/bench/wit-transfer/variants.bnt:42

```json
{
  "id": "try-000100",
  "path": "tools/bench/wit-transfer/variants.bnt",
  "source_sha256": "44302a834558e2855c5d8b0333b543e89311da1ba9eeb044b0c25b53f3f7625b",
  "after_sha256": "8ea833a87c9b275824c2f098e9b7b59932c0dfb961c446795b480dd04e206ff8",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "benchmark",
  "line": 42,
  "start": 937,
  "end": 958,
  "operand_end": 958,
  "operand_host_end": 958,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Console.Write, Process.Environment"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "比較用の戻り値・失敗値・uses・仕事量を保つ。main とコールバックにも同じ処置を使う（R1）。",
  "before": "try Runner.settings()",
  "after": "try Runner.settings() or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000101 — tools/skill-eval/tasks/csv_report/reference.bnt:13

```json
{
  "id": "try-000101",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "b8455f142dae58c16d05a6f8d12047d7b361a2cf9934fcba7ef1bce1c8a80872",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 13,
  "start": 607,
  "end": 685,
  "operand_end": 685,
  "operand_host_end": 685,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "addRow",
    "public": false,
    "return_type": "Result[Map[String, Pair[Integer, Integer]], String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try Option.okOr(o: Map.get(m: row, k: \"region\"), error: \"a row has no region\")",
  "after": "try Option.okOr(o: Map.get(m: row, k: \"region\"), error: \"a row has no region\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000102 — tools/skill-eval/tasks/csv_report/reference.bnt:14

```json
{
  "id": "try-000102",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "e0f02e0e29ee9d29cd054ace3bd823040e9f2b8390eada0b46818b3bd3d97291",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 14,
  "start": 705,
  "end": 742,
  "operand_end": 742,
  "operand_host_end": 742,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "addRow",
    "public": false,
    "return_type": "Result[Map[String, Pair[Integer, Integer]], String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try field(row: row, name: \"quantity\")",
  "after": "try field(row: row, name: \"quantity\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000103 — tools/skill-eval/tasks/csv_report/reference.bnt:15

```json
{
  "id": "try-000103",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "cb5f4aab583652ae182dc7eda865a6107cce0dba2c6afbac2048e05386050599",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 15,
  "start": 759,
  "end": 798,
  "operand_end": 798,
  "operand_host_end": 798,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "addRow",
    "public": false,
    "return_type": "Result[Map[String, Pair[Integer, Integer]], String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try field(row: row, name: \"unit_price\")",
  "after": "try field(row: row, name: \"unit_price\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000104 — tools/skill-eval/tasks/csv_report/reference.bnt:21

```json
{
  "id": "try-000104",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "1cb22df1986d5029de5e8b96f4a6abf17c6f322589ccf2c7f470062e7571ffb0",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 21,
  "start": 1134,
  "end": 1248,
  "operand_end": 1248,
  "operand_host_end": 1248,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readText(\"sales.csv\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readText(\"sales.csv\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000105 — tools/skill-eval/tasks/csv_report/reference.bnt:22

```json
{
  "id": "try-000105",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "7914dd3ae34073a6400953a341167c463a3cfc4f2390ea56a389ed784df0dfb0",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 22,
  "start": 1264,
  "end": 1384,
  "operand_end": 1384,
  "operand_host_end": 1384,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Csv.parseWithHeader(text) |> Result.mapError(r: _, f: lambda(error) return Csv.ParseError.message(error) end lambda)",
  "after": "try Csv.parseWithHeader(text) |> Result.mapError(r: _, f: lambda(error) return Csv.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000106 — tools/skill-eval/tasks/csv_report/reference.bnt:23

```json
{
  "id": "try-000106",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "5b6730456cbea3a0ac8d0348f6ad2c0bf5e388cc88fb10b7eb58c3965439db65",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 23,
  "start": 1402,
  "end": 1569,
  "operand_end": 1569,
  "operand_host_end": 1569,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try List.fold(xs: rows, initial: Result.Ok(Map.empty()), f: lambda(acc, value)\n    bind current <- try acc\n    return addRow(totals: current, row: value)\n  end lambda)",
  "after": "try List.fold(xs: rows, initial: Result.Ok(Map.empty()), f: lambda(acc, value)\n    bind current <- try acc\n    return addRow(totals: current, row: value)\n  end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000107 — tools/skill-eval/tasks/csv_report/reference.bnt:24

```json
{
  "id": "try-000107",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "11285b86814917694d1abf3ea2abefce2a251a48932f2461b564825dbe1d2a73",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 24,
  "start": 1501,
  "end": 1508,
  "operand_end": 1508,
  "operand_host_end": 1508,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1462",
    "return_type": null,
    "uses": null
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try acc",
  "after": "try acc or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000108 — tools/skill-eval/tasks/csv_report/reference.bnt:31

```json
{
  "id": "try-000108",
  "path": "tools/skill-eval/tasks/csv_report/reference.bnt",
  "source_sha256": "aa629fc01138b04aaf11724649cd66c26c895c15dcb13bf64160473d30948e43",
  "after_sha256": "0a35d94e63d07a7daefba8ea5db6858e181fa46d0434236c54d4ef913473c8be",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 31,
  "start": 1820,
  "end": 2022,
  "operand_end": 2022,
  "operand_host_end": 2022,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.writeText(path: \"summary.csv\", text: Csv.format(List.prepend(xs: table, x: [\"region\", \"orders\", \"revenue\"]))) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.writeText(path: \"summary.csv\", text: Csv.format(List.prepend(xs: table, x: [\"region\", \"orders\", \"revenue\"]))) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000109 — tools/skill-eval/tasks/dir_walk/reference.bnt:5

```json
{
  "id": "try-000109",
  "path": "tools/skill-eval/tasks/dir_walk/reference.bnt",
  "source_sha256": "b3185302c4849efd5021dff57a20ace18a9bd57aff6ce61d9bb779fdd53f0673",
  "after_sha256": "b4e3454273d535d1ccc257845d44d970be4e0d2a8d899987b779cbed21788825",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 5,
  "start": 168,
  "end": 286,
  "operand_end": 286,
  "operand_host_end": 286,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "countLines",
    "public": false,
    "return_type": "Result[Integer, String]",
    "uses": "uses File.Read"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try File.readLines(\"docs/\" + path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readLines(\"docs/\" + path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000110 — tools/skill-eval/tasks/dir_walk/reference.bnt:11

```json
{
  "id": "try-000110",
  "path": "tools/skill-eval/tasks/dir_walk/reference.bnt",
  "source_sha256": "b3185302c4849efd5021dff57a20ace18a9bd57aff6ce61d9bb779fdd53f0673",
  "after_sha256": "4a04ffe05926233a69893f77d9e3dccb5975d25c3fe24c4fdcb036120cbbca4f",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 11,
  "start": 520,
  "end": 633,
  "operand_end": 633,
  "operand_host_end": 633,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "isMarkdownFile",
    "public": false,
    "return_type": "Result[Boolean, String]",
    "uses": "uses File.Read"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try File.info(\"docs/\" + path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.info(\"docs/\" + path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000111 — tools/skill-eval/tasks/dir_walk/reference.bnt:21

```json
{
  "id": "try-000111",
  "path": "tools/skill-eval/tasks/dir_walk/reference.bnt",
  "source_sha256": "b3185302c4849efd5021dff57a20ace18a9bd57aff6ce61d9bb779fdd53f0673",
  "after_sha256": "6b4face246dace16f6b5f0cc03b1cad932bb520d415387a9936ee0d03ae8c515",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 21,
  "start": 1021,
  "end": 1045,
  "operand_end": 1045,
  "operand_host_end": 1045,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "report",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try isMarkdownFile(path)",
  "after": "try isMarkdownFile(path) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000112 — tools/skill-eval/tasks/dir_walk/reference.bnt:23

```json
{
  "id": "try-000112",
  "path": "tools/skill-eval/tasks/dir_walk/reference.bnt",
  "source_sha256": "b3185302c4849efd5021dff57a20ace18a9bd57aff6ce61d9bb779fdd53f0673",
  "after_sha256": "9828cf9efde6c1cd1492cb70d1c899e0621ac0e00b59cf3eec1fe3d978c39872",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 23,
  "start": 1155,
  "end": 1175,
  "operand_end": 1175,
  "operand_host_end": 1175,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "report",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try countLines(path)",
  "after": "try countLines(path) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000113 — tools/skill-eval/tasks/dir_walk/reference.bnt:30

```json
{
  "id": "try-000113",
  "path": "tools/skill-eval/tasks/dir_walk/reference.bnt",
  "source_sha256": "b3185302c4849efd5021dff57a20ace18a9bd57aff6ce61d9bb779fdd53f0673",
  "after_sha256": "201a4ccb4631462e776264b572d9557e872b2a59a52747f1ea98c2a8b9b9c45e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 30,
  "start": 1405,
  "end": 1510,
  "operand_end": 1510,
  "operand_host_end": 1510,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.walk(\"docs\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.walk(\"docs\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000114 — tools/skill-eval/tasks/error_handling/reference.bnt:16

```json
{
  "id": "try-000114",
  "path": "tools/skill-eval/tasks/error_handling/reference.bnt",
  "source_sha256": "1ef5aac3fc7697bb47be8a6eacff4253661f8ba4552bd3ac339a985342a2c831",
  "after_sha256": "2991708d9306c28562ab731fb21764a0ec859e8872396d6e0dfa57ecf06f308e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 16,
  "start": 685,
  "end": 800,
  "operand_end": 800,
  "operand_host_end": 800,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readLines(\"files.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readLines(\"files.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000115 — tools/skill-eval/tasks/file_process/reference.bnt:12

```json
{
  "id": "try-000115",
  "path": "tools/skill-eval/tasks/file_process/reference.bnt",
  "source_sha256": "23908cc729502402ed797c946a8d3bf56965fd009235a05e60bc9d1ab7e523a8",
  "after_sha256": "7c7b5f7c0cfdb61dd92ba84e1956575d6c5665e25cafde86c4adab04104958fd",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 12,
  "start": 470,
  "end": 584,
  "operand_end": 584,
  "operand_host_end": 584,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readLines(\"todo.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readLines(\"todo.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000116 — tools/skill-eval/tasks/file_process/reference.bnt:15

```json
{
  "id": "try-000116",
  "path": "tools/skill-eval/tasks/file_process/reference.bnt",
  "source_sha256": "23908cc729502402ed797c946a8d3bf56965fd009235a05e60bc9d1ab7e523a8",
  "after_sha256": "d285c1285ff8ad89fee809bd339460637ea979f8b04f5f004c1588cd0f476268",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 15,
  "start": 853,
  "end": 996,
  "operand_end": 996,
  "operand_host_end": 996,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.writeText(path: \"todo-numbered.txt\", text: output) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.writeText(path: \"todo-numbered.txt\", text: output) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000117 — tools/skill-eval/tasks/http_client/reference.bnt:13

```json
{
  "id": "try-000117",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "41ef8cbca88a66fe5658c7e227c6c39cf0eff985cd4d92ca6c04c481fa640373",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 13,
  "start": 300,
  "end": 420,
  "operand_end": 420,
  "operand_host_end": 420,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "itemOf",
    "public": false,
    "return_type": "Result[Item, String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"name\"), f: Json.asString), error: \"an item has no name\")",
  "after": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"name\"), f: Json.asString), error: \"an item has no name\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000118 — tools/skill-eval/tasks/http_client/reference.bnt:14

```json
{
  "id": "try-000118",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "7582d4e54c573935624ef6af39ff0d88c6f46bc28fc8af27b5a89235edd942cd",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 14,
  "start": 437,
  "end": 560,
  "operand_end": 560,
  "operand_host_end": 560,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "itemOf",
    "public": false,
    "return_type": "Result[Item, String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"stock\"), f: Json.asInteger), error: \"an item has no stock\")",
  "after": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"stock\"), f: Json.asInteger), error: \"an item has no stock\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000119 — tools/skill-eval/tasks/http_client/reference.bnt:15

```json
{
  "id": "try-000119",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "56cba69b6a33707756359d1216aee5a7cb23fc17949fb5f7f513dee816be18f4",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 15,
  "start": 577,
  "end": 700,
  "operand_end": 700,
  "operand_host_end": 700,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "itemOf",
    "public": false,
    "return_type": "Result[Item, String]",
    "uses": ""
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"price\"), f: Json.asInteger), error: \"an item has no price\")",
  "after": "try Option.okOr(o: Option.andThen(o: Json.get(value: value, k: \"price\"), f: Json.asInteger), error: \"an item has no price\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000120 — tools/skill-eval/tasks/http_client/reference.bnt:24

```json
{
  "id": "try-000120",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "47a851186a48b5fa82a46d5eaef2a5e1f7e7d42faeaf834c213c3e372172a36a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 24,
  "start": 1045,
  "end": 1246,
  "operand_end": 1246,
  "operand_host_end": 1246,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Option.okOr(o: try Process.environmentVariable(\"SKILL_EVAL_HTTP_BASE\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda), error: \"SKILL_EVAL_HTTP_BASE is not set\")",
  "after": "try Option.okOr(o: try Process.environmentVariable(\"SKILL_EVAL_HTTP_BASE\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda), error: \"SKILL_EVAL_HTTP_BASE is not set\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000121 — tools/skill-eval/tasks/http_client/reference.bnt:24

```json
{
  "id": "try-000121",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "236a7a082e8da61b66321b4238a7e6be0772db85e13e2576351ff1e8e239df88",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 24,
  "start": 1064,
  "end": 1203,
  "operand_end": 1203,
  "operand_host_end": 1203,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Process.environmentVariable(\"SKILL_EVAL_HTTP_BASE\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try Process.environmentVariable(\"SKILL_EVAL_HTTP_BASE\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000122 — tools/skill-eval/tasks/http_client/reference.bnt:25

```json
{
  "id": "try-000122",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "c8ed59a692612d31209c3e7e92e9c7dcd527bf4700b356b66b03cdb7e474a18d",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 25,
  "start": 1264,
  "end": 1383,
  "operand_end": 1383,
  "operand_host_end": 1383,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Http.get(base + \"/status\") |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda)",
  "after": "try Http.get(base + \"/status\") |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000123 — tools/skill-eval/tasks/http_client/reference.bnt:27

```json
{
  "id": "try-000123",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "b0dc3302ec3d41e988d56442421b220a47f4307230c09f91d6f30495ad88d061",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 27,
  "start": 1455,
  "end": 1577,
  "operand_end": 1577,
  "operand_host_end": 1577,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Http.get(base + \"/inventory\") |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda)",
  "after": "try Http.get(base + \"/inventory\") |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000124 — tools/skill-eval/tasks/http_client/reference.bnt:28

```json
{
  "id": "try-000124",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "b167368a9de4343b6a6b065b1ee4ef6fd8b1d8df74833c780c664b21f16b39d6",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 28,
  "start": 1595,
  "end": 1722,
  "operand_end": 1722,
  "operand_host_end": 1722,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Json.parse(bodyText(inventory)) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Json.parse(bodyText(inventory)) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000125 — tools/skill-eval/tasks/http_client/reference.bnt:29

```json
{
  "id": "try-000125",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "fee899de9628ac64e8bbecb1853344fb41287a363f5ccb55c52c78dfb27f55be",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 29,
  "start": 1739,
  "end": 1819,
  "operand_end": 1819,
  "operand_host_end": 1819,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Option.okOr(o: Json.asArray(parsed), error: \"the inventory is not an array\")",
  "after": "try Option.okOr(o: Json.asArray(parsed), error: \"the inventory is not an array\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000126 — tools/skill-eval/tasks/http_client/reference.bnt:30

```json
{
  "id": "try-000126",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "497161781b656dd8190793508cb10310acf72d4d66626054cae1320c9cc22ff1",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 30,
  "start": 1836,
  "end": 2120,
  "operand_end": 2120,
  "operand_host_end": 2120,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try List.fold(xs: array, initial: Result.Ok([]), f: lambda(acc, value)\n    bind collected <- try acc\n    bind item <- try itemOf(value)\n    return Result.Ok(List.prepend(xs: collected, x: item))\n  end lambda) |> Result.map(r: _, f: lambda(value) return List.reverse(value) end lambda)",
  "after": "try List.fold(xs: array, initial: Result.Ok([]), f: lambda(acc, value)\n    bind collected <- try acc\n    bind item <- try itemOf(value)\n    return Result.Ok(List.prepend(xs: collected, x: item))\n  end lambda) |> Result.map(r: _, f: lambda(value) return List.reverse(value) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000127 — tools/skill-eval/tasks/http_client/reference.bnt:31

```json
{
  "id": "try-000127",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "22ad8575f0854be228b6d1ca15f3491fd16ec1094b6aeb847e7df17cebaf41a6",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 31,
  "start": 1929,
  "end": 1936,
  "operand_end": 1936,
  "operand_host_end": 1936,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1888",
    "return_type": null,
    "uses": null
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try acc",
  "after": "try acc or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000128 — tools/skill-eval/tasks/http_client/reference.bnt:32

```json
{
  "id": "try-000128",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "ddf6d7d0390c05fd42c1cc6d22155364e87d7193788b3cc3b65cd2a0051c48da",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 32,
  "start": 1954,
  "end": 1971,
  "operand_end": 1971,
  "operand_host_end": 1971,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1888",
    "return_type": null,
    "uses": null
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try itemOf(value)",
  "after": "try itemOf(value) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000129 — tools/skill-eval/tasks/http_client/reference.bnt:40

```json
{
  "id": "try-000129",
  "path": "tools/skill-eval/tasks/http_client/reference.bnt",
  "source_sha256": "e6503adf70ecc5904037ca7fee3e26161a14e231b2f497a0122892c899dad965",
  "after_sha256": "674aaafe15d6f59b93d3045c4047b997b6325b97558fb20e35da9c6a93e61578",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 40,
  "start": 2829,
  "end": 2940,
  "operand_end": 2940,
  "operand_host_end": 2940,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Environment, Http.Connect, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Http.send(request) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda)",
  "after": "try Http.send(request) |> Result.mapError(r: _, f: lambda(error) return NetworkError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000130 — tools/skill-eval/tasks/json_convert/reference.bnt:19

```json
{
  "id": "try-000130",
  "path": "tools/skill-eval/tasks/json_convert/reference.bnt",
  "source_sha256": "18b5274909e58aeb896a42ab152d5a9d2c9ba77ecf4b5806475e68a87edcaf2a",
  "after_sha256": "da6108f0abe6ab5d28a9c83c4bc6e647aebac8986eac7c7e7e4d7a152fc41e57",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 19,
  "start": 640,
  "end": 756,
  "operand_end": 756,
  "operand_host_end": 756,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readText(\"members.csv\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readText(\"members.csv\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000131 — tools/skill-eval/tasks/json_convert/reference.bnt:20

```json
{
  "id": "try-000131",
  "path": "tools/skill-eval/tasks/json_convert/reference.bnt",
  "source_sha256": "18b5274909e58aeb896a42ab152d5a9d2c9ba77ecf4b5806475e68a87edcaf2a",
  "after_sha256": "0a4592cd2894c38e02f932d24c58683654d7baa5a76aefc1f47b0412600fccef",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 20,
  "start": 772,
  "end": 892,
  "operand_end": 892,
  "operand_host_end": 892,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Csv.parseWithHeader(text) |> Result.mapError(r: _, f: lambda(error) return Csv.ParseError.message(error) end lambda)",
  "after": "try Csv.parseWithHeader(text) |> Result.mapError(r: _, f: lambda(error) return Csv.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000132 — tools/skill-eval/tasks/json_convert/reference.bnt:28

```json
{
  "id": "try-000132",
  "path": "tools/skill-eval/tasks/json_convert/reference.bnt",
  "source_sha256": "18b5274909e58aeb896a42ab152d5a9d2c9ba77ecf4b5806475e68a87edcaf2a",
  "after_sha256": "810ed58a8842f845428212791f3948b1ecc53c4f5a8a3441ecd53f2d707d5304",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 28,
  "start": 1369,
  "end": 1526,
  "operand_end": 1526,
  "operand_host_end": 1526,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.writeText(path: \"teams.json\", text: Json.stringify(json) + \"\\n\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.writeText(path: \"teams.json\", text: Json.stringify(json) + \"\\n\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000133 — tools/skill-eval/tasks/json_convert/reference.bnt:30

```json
{
  "id": "try-000133",
  "path": "tools/skill-eval/tasks/json_convert/reference.bnt",
  "source_sha256": "18b5274909e58aeb896a42ab152d5a9d2c9ba77ecf4b5806475e68a87edcaf2a",
  "after_sha256": "0ae6f37ea9080ec0ba29da76a96c893a4ed51698ee5c8c0c2c2005dc01c8856c",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 30,
  "start": 1623,
  "end": 1692,
  "operand_end": 1692,
  "operand_host_end": 1692,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, File.Write, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Option.okOr(o: List.head(rows), error: \"members.csv has no rows\")",
  "after": "try Option.okOr(o: List.head(rows), error: \"members.csv has no rows\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000134 — tools/skill-eval/tasks/json_summary/reference.bnt:21

```json
{
  "id": "try-000134",
  "path": "tools/skill-eval/tasks/json_summary/reference.bnt",
  "source_sha256": "288e1446476929cf0280711c9b31f141bfb77e41118ff1780fc017c8e3946295",
  "after_sha256": "9a121ffad58a6d11e9ba5bfad71ea6e40e4ccaf90ae36fd36e7b75131674581b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 21,
  "start": 1274,
  "end": 1390,
  "operand_end": 1390,
  "operand_host_end": 1390,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readText(\"orders.json\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readText(\"orders.json\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000135 — tools/skill-eval/tasks/json_summary/reference.bnt:22

```json
{
  "id": "try-000135",
  "path": "tools/skill-eval/tasks/json_summary/reference.bnt",
  "source_sha256": "288e1446476929cf0280711c9b31f141bfb77e41118ff1780fc017c8e3946295",
  "after_sha256": "caa4cb884e4e2ec916f1cb8121275410bb261bda540b7fc66caab976bdb5249b",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 22,
  "start": 1408,
  "end": 1520,
  "operand_end": 1520,
  "operand_host_end": 1520,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Json.parse(text) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda)",
  "after": "try Json.parse(text) |> Result.mapError(r: _, f: lambda(error) return Json.ParseError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000136 — tools/skill-eval/tasks/json_summary/reference.bnt:27

```json
{
  "id": "try-000136",
  "path": "tools/skill-eval/tasks/json_summary/reference.bnt",
  "source_sha256": "288e1446476929cf0280711c9b31f141bfb77e41118ff1780fc017c8e3946295",
  "after_sha256": "0a61e566eb93dc0b4f71c66edd760a9588dc2fc139397479784e0efe636d20fd",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 27,
  "start": 1711,
  "end": 1884,
  "operand_end": 1884,
  "operand_host_end": 1884,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try List.fold(xs: orders, initial: Result.Ok(Map.empty()), f: lambda(acc, value)\n    bind current <- try acc\n    return addOrder(totals: current, order: value)\n  end lambda)",
  "after": "try List.fold(xs: orders, initial: Result.Ok(Map.empty()), f: lambda(acc, value)\n    bind current <- try acc\n    return addOrder(totals: current, order: value)\n  end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000137 — tools/skill-eval/tasks/json_summary/reference.bnt:28

```json
{
  "id": "try-000137",
  "path": "tools/skill-eval/tasks/json_summary/reference.bnt",
  "source_sha256": "288e1446476929cf0280711c9b31f141bfb77e41118ff1780fc017c8e3946295",
  "after_sha256": "6986e33c01aa1fe43919e628c72b429b010cdd7b5753ca12ebf3c66a80cdb58c",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 28,
  "start": 1812,
  "end": 1819,
  "operand_end": 1819,
  "operand_host_end": 1819,
  "action": "implicit_return",
  "owner": {
    "kind": "callback",
    "name": "lambda@1773",
    "return_type": null,
    "uses": null
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try acc",
  "after": "try acc or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000138 — tools/skill-eval/tasks/process_run/reference.bnt:6

```json
{
  "id": "try-000138",
  "path": "tools/skill-eval/tasks/process_run/reference.bnt",
  "source_sha256": "40697ffff7e4e61aeaeb81c0d99fcdfe438e488f259af23f9b357ffbe34f0306",
  "after_sha256": "b7a4f376428c9106c4b71cd94cacd81417317cfcf70b3d57fefdb59c0e591e53",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 6,
  "start": 213,
  "end": 328,
  "operand_end": 328,
  "operand_host_end": 328,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Process.Run, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readText(\"fruits.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readText(\"fruits.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000139 — tools/skill-eval/tasks/process_run/reference.bnt:8

```json
{
  "id": "try-000139",
  "path": "tools/skill-eval/tasks/process_run/reference.bnt",
  "source_sha256": "40697ffff7e4e61aeaeb81c0d99fcdfe438e488f259af23f9b357ffbe34f0306",
  "after_sha256": "f8741611d8a65d6ee95fa0c608b1001fbf0dd9462750e1e999f3f6c10b68cde8",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 8,
  "start": 511,
  "end": 619,
  "operand_end": 619,
  "operand_host_end": 619,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Process.Run, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Process.run(command) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try Process.run(command) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000140 — tools/skill-eval/tasks/process_shell/reference.bnt:5

```json
{
  "id": "try-000140",
  "path": "tools/skill-eval/tasks/process_shell/reference.bnt",
  "source_sha256": "27f14a2f7723de5f04431f2481f4215c16f39bfc440c8b2ec23f8973d81d0ed2",
  "after_sha256": "76df524e1b6959685d5d22c5f8764ac8eb079ec601f94d951fb3723ee435912a",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 5,
  "start": 168,
  "end": 332,
  "operand_end": 332,
  "operand_host_end": 332,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Run, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Process.shell(\"grep ' ERROR ' app.log | cut -d ' ' -f 3 | LC_ALL=C sort -u\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try Process.shell(\"grep ' ERROR ' app.log | cut -d ' ' -f 3 | LC_ALL=C sort -u\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000141 — tools/skill-eval/tasks/process_shell/reference.bnt:9

```json
{
  "id": "try-000141",
  "path": "tools/skill-eval/tasks/process_shell/reference.bnt",
  "source_sha256": "27f14a2f7723de5f04431f2481f4215c16f39bfc440c8b2ec23f8973d81d0ed2",
  "after_sha256": "a2c50607a5c740434846cdf70eb4c34cff0ed6635d6eaf00901aba9c7a234c1c",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 9,
  "start": 581,
  "end": 711,
  "operand_end": 711,
  "operand_host_end": 711,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses Process.Run, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Process.shell(\"grep -q ' FATAL ' app.log\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try Process.shell(\"grep -q ' FATAL ' app.log\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000142 — tools/skill-eval/tasks/regex_text/reference.bnt:6

```json
{
  "id": "try-000142",
  "path": "tools/skill-eval/tasks/regex_text/reference.bnt",
  "source_sha256": "58b2689c64faa75ad12872595c1aacd58ab9de7c235094881df16dd524fdb023",
  "after_sha256": "845ee961655908aa3ec7bf10945a91cb0ddb651afadf92973b4af559f706810e",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 6,
  "start": 195,
  "end": 312,
  "operand_end": 312,
  "operand_host_end": 312,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try File.readText(\"messages.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readText(\"messages.txt\") |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000143 — tools/skill-eval/tasks/regex_text/reference.bnt:7

```json
{
  "id": "try-000143",
  "path": "tools/skill-eval/tasks/regex_text/reference.bnt",
  "source_sha256": "58b2689c64faa75ad12872595c1aacd58ab9de7c235094881df16dd524fdb023",
  "after_sha256": "9cdcc3972dbb20b5a629c33d1a30f8f9ac6a56afb80107c58e6fdc91c91e1de3",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 7,
  "start": 329,
  "end": 396,
  "operand_end": 396,
  "operand_host_end": 396,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Regex.compile(r\"[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\\.[A-Za-z]+)\")",
  "after": "try Regex.compile(r\"[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\\.[A-Za-z]+)\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000144 — tools/skill-eval/tasks/regex_text/reference.bnt:8

```json
{
  "id": "try-000144",
  "path": "tools/skill-eval/tasks/regex_text/reference.bnt",
  "source_sha256": "58b2689c64faa75ad12872595c1aacd58ab9de7c235094881df16dd524fdb023",
  "after_sha256": "314f507d801ae97901a7a69c7cb4ec34cfcccb0a6149ad80132227bfbece84ae",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 8,
  "start": 412,
  "end": 451,
  "operand_end": 451,
  "operand_host_end": 451,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "main",
    "public": false,
    "return_type": "Result[Unit, String]",
    "uses": "uses File.Read, Console.Write"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "既存の Result[Unit, String] と失敗値・uses・出力の契約を保つ R1 の例外。mapError と最後の Result.Ok も維持する。",
  "before": "try Regex.compile(r\"\\d{4}-\\d{2}-\\d{2}\")",
  "after": "try Regex.compile(r\"\\d{4}-\\d{2}-\\d{2}\") or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

## try-000145 — tools/skill-eval/tasks/write_tests/reference.bnt:13

```json
{
  "id": "try-000145",
  "path": "tools/skill-eval/tasks/write_tests/reference.bnt",
  "source_sha256": "52abd1a8b740d7ba90b00d0580db1148e2842a8ab91c4c2f6ba4ee58b1230324",
  "after_sha256": "4611dfbf7935fe0fe6ca331eec2a34001ede9777f6c99a8cbc8ef336b9ff6271",
  "snippet": 0,
  "host_kind": "bnt",
  "role": "sample",
  "line": 13,
  "start": 595,
  "end": 703,
  "operand_end": 703,
  "operand_host_end": 703,
  "action": "implicit_return",
  "owner": {
    "kind": "function",
    "name": "loadSettings",
    "public": false,
    "return_type": "Result[Map[String, String], String]",
    "uses": "uses File.Read"
  },
  "classification": "change",
  "proposed_action": "return",
  "reason": "参照解の再利用する関数・コールバックが失敗値を返す契約を保つ。",
  "before": "try File.readLines(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda)",
  "after": "try File.readLines(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error) end lambda) or return",
  "typed": true,
  "parse_errors": [],
  "check_codes": [],
  "holds": [],
  "contract_changes": {
    "uses": "unchanged",
    "return": "unchanged",
    "output": "unchanged"
  },
  "contract_reviewed": true,
  "confirmation": "approved"
}
```

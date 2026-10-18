# Benitoite.Failure

Status: unofficial. Import it with `import Benitoite.Unofficial.Failure`. When the module becomes standard, the import name changes to `import Benitoite.Failure`.

Refer to its declarations as `Failure.<name>`, for example `Failure.fromResult`.

Typed, non-resumable failures. Import Benitoite.Unofficial.Failure explicitly.

```text
Failure.raise[T, E]: function(error: E) -> T uses Failure.Fail[E]
```

The standard effect `Failure.Fail[E]` takes one error type. `Failure.raise` aborts to the nearest failure clause; `resume` is forbidden in that clause. A handle may contain either one failure clause or ordinary operation clauses. Catching removes only the body failure; a clause may raise a different error type. A row beside an explicit Failure.Fail in any part of a declared signature excludes failures (for example `Rest excludes Failure.Fail`). This condition is retained through higher-order values and modules, and is never inferred from a function body. Other effects take no type arguments. Handle every failure before main or a test returns. The error type requires neither Show nor equality.

```benitoite
public function fromResult[T, E](result: Result[T, E]) -> T uses Fail[E]
```

Returns the success value, or raises the original error without requiring Show.

```benitoite
public function toResult[T, E, effect Rest](body: function() -> T uses Fail[E], Rest) -> Result[T, E] uses Rest
```

Runs body once, returning Ok on success or Error when it raises a failure.
Rest excludes Fail; other effects and runtime stops keep their usual behavior.

# Benitoite.Range

Status: unofficial. Import it with `import Benitoite.Unofficial.Range`. When the module becomes standard, the import name changes to `import Benitoite.Range`.

Refer to its declarations as `Range.<name>`, for example `Range.CheckedInteger`.

Pure inclusive Integer range checks. Success retains both bounds and the value; bounds may differ between values of the same CheckedInteger type.

```benitoite test
import Benitoite.Unofficial.Range
@test
function rangeExample() -> Unit uses Assert.Check
  match Range.checkInteger(minimum: 1, maximum: 10, value: 10) with
    case Result.Ok(value) ->
      Assert.equal(actual: Range.minimum(value), expected: 1)
      Assert.equal(actual: Range.maximum(value), expected: 10)
      Assert.equal(actual: Range.value(value), expected: 10)
    case Result.Error(_) -> Assert.fail("inclusive bound did not match")
  end match
  match Range.checkInteger(minimum: 10, maximum: 1, value: 0) with
    case Result.Error(Range.RangeError.InvalidBounds(low, high)) ->
      Assert.equal(actual: low, expected: 10)
      Assert.equal(actual: high, expected: 1)
    case _ -> Assert.fail("reversed bounds must take priority")
  end match
end function
```

Invalid constant inputs are still Result.Error values, so this checks successfully.

```benitoite check
import Benitoite.Unofficial.Range
function main() -> Unit
  bind result <- Range.checkInteger(minimum: 1, maximum: 10, value: 11)
  return ()
end function
```

```benitoite error
import Benitoite.Unofficial.Range
function main() -> Unit
  bind value <- Range.CheckedInteger(minimum: 1, maximum: 10, value: 5)
  return ()
end function
```
```diagnostic
E0340
```

```benitoite
@opaque
public record CheckedInteger
  minimum: Integer
  maximum: Integer
  value: Integer
end record
```

An Integer together with the inclusive bounds it satisfies. Use checkInteger and the public projections.

```benitoite
public data RangeError
  InvalidBounds(Integer, Integer)
  OutOfRange(Integer, Integer, Integer)
end data
```

InvalidBounds takes priority over OutOfRange. Failures retain the original inputs.

```benitoite
public function checkInteger(minimum: Integer, maximum: Integer, value: Integer) -> Result[CheckedInteger, RangeError]
```

Checks minimum <= value <= maximum, rejecting reversed bounds first. Constant invalid inputs still return Result.Error. No upper-bound addition is used.

```benitoite
public function minimum(value: CheckedInteger) -> Integer
```

Returns the inclusive lower bound retained by the check.

```benitoite
public function maximum(value: CheckedInteger) -> Integer
```

Returns the inclusive upper bound retained by the check.

```benitoite
public function value(value: CheckedInteger) -> Integer
```

Returns the checked Integer. Call checkInteger again to check it against different bounds.

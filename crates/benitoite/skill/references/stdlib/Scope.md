# Benitoite.Scope

Status: unofficial. Import it with `import Benitoite.Unofficial.Scope`. When the module becomes standard, the import name changes to `import Benitoite.Scope`.

Refer to its declarations as `Scope.<name>`, for example `Scope.CheckedHost`.

Checks host and absolute-path spelling against an explicit scope. Success preserves the condition and target; it does not grant permission or guarantee DNS resolution, filesystem identity, isolation, or IO success.

`PathIn` is a built-in opaque type. Its optional path scope is an invariant index; the bare type has the unrestricted scope.
Use the public checks and projections. These checks do not authorize IO.

```benitoite test
import Benitoite.Unofficial.Scope
@test
function scopeExample() -> Unit uses Assert.Check
  match Scope.checkHost(pattern: "*.example.com", host: "API.EXAMPLE.COM") with
    case Result.Ok(value) -> Assert.equal(actual: Scope.host(value), expected: "api.example.com")
    case Result.Error(_) -> Assert.fail("host did not match")
  end match
  match Scope.checkPath(pattern: "/data/**", path: "/data/report.txt") with
    case Result.Ok(value) -> Assert.equal(actual: Scope.path(value), expected: "/data/report.txt")
    case Result.Error(_) -> Assert.fail("path did not match")
  end match
  match Scope.checkEndpoint(hostPattern: "example.com", host: "example.com", minimumPort: 443, maximumPort: 443, port: 443) with
    case Result.Ok(value) -> Assert.equal(actual: Scope.endpointPort(value), expected: 443)
    case Result.Error(_) -> Assert.fail("endpoint did not match")
  end match
end function
```

```benitoite error
import Benitoite.Unofficial.Scope
function main() -> Unit
  bind value <- Scope.CheckedHost(pattern: "example.com", host: "example.com")
  return ()
end function
```
```diagnostic
E0340
```

```benitoite error
import Benitoite.Unofficial.Scope
function main() -> Unit
  bind result <- Scope.checkHost(pattern: "*.example.com", host: "example.com")
  return ()
end function
```
```diagnostic
E0462
```

```benitoite
@opaque
public record CheckedHost
  pattern: String
  host: String
end record
```

A host name or IP address and the host or CIDR pattern it satisfies, stored in normalized form.

```benitoite
@opaque
public record CheckedPath
  pattern: String
  path: String
end record
```

An absolute path and its exact or tree pattern, with spelling preserved.

```benitoite
@opaque
public record CheckedEndpoint
  hostPattern: String
  host: String
  minimumPort: Integer
  maximumPort: Integer
  port: Integer
end record
```

A lowercase host and an inclusive port range, retaining all five inputs.

```benitoite
public data ScopeError
  InvalidPattern(String, String)
  InvalidTarget(String, String)
  InvalidPortRange(Integer, Integer)
  InvalidPort(Integer)
  OutsideScope(String, String)
  PortOutsideScope(Integer, Integer, Integer)
end data
```

Failures retain original inputs. Forms are checked before membership.

```benitoite
public function checkHost(pattern: String, host: String) -> Result[CheckedHost, ScopeError]
```

Checks an exact host name or IP address, a CIDR network, *.host (one label), or **.host (one or more labels). Wildcards exclude the stem itself. Known invalid direct arguments are rejected before execution.

```benitoite
public function checkPath(pattern: String, path: String) -> Result[CheckedPath, ScopeError]
```

Checks an exact absolute path or a trailing /** tree, which includes its stem. This does not resolve links or access the filesystem.

```benitoite
public function checkPathIn(pattern: String, path: String) -> Result[PathIn, ScopeError]
```

Checks an exact absolute path or a trailing /** tree and retains the same path. A known direct pattern determines the static scope; otherwise the static scope is unrestricted. Known invalid direct arguments are rejected before execution. Dynamic spelling and membership are always checked. This does not access the filesystem or authorize IO.

```benitoite
public function pathInValue(path: PathIn) -> String
```

Returns the same path retained by checkPathIn, preserving its static scope in the argument.

```benitoite
public function widenPathIn(path: PathIn) -> PathIn
```

Explicitly widens the static scope to the annotated return scope when it covers the input scope. Returns the same checked value.

```benitoite
public function checkEndpoint(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer) -> Result[CheckedEndpoint, ScopeError]
```

Checks host forms, inclusive bounds 0..65535, the port, host membership, then port membership. Known invalid parts of a direct call are rejected even if other arguments are dynamic.

```benitoite
public function host(value: CheckedHost) -> String
```

Returns the lowercase host.

```benitoite
public function hostPattern(value: CheckedHost) -> String
```

Returns the lowercase host pattern.

```benitoite
public function path(value: CheckedPath) -> String
```

Returns the path as accepted.

```benitoite
public function pathPattern(value: CheckedPath) -> String
```

Returns the path pattern as accepted.

```benitoite
public function endpointHost(value: CheckedEndpoint) -> String
```

Returns the lowercase endpoint host.

```benitoite
public function endpointHostPattern(value: CheckedEndpoint) -> String
```

Returns the lowercase endpoint host pattern.

```benitoite
public function endpointPort(value: CheckedEndpoint) -> Integer
```

Returns the checked port.

```benitoite
public function endpointMinimumPort(value: CheckedEndpoint) -> Integer
```

Returns the inclusive lower port bound.

```benitoite
public function endpointMaximumPort(value: CheckedEndpoint) -> Integer
```

Returns the inclusive upper port bound.

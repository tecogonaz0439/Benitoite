# Benitoite.Log

Status: unofficial. Import it with `import Benitoite.Unofficial.Log`. When the module becomes standard, the import name changes to `import Benitoite.Log`.

Refer to its declarations as `Log.<name>`, for example `Log.Level`.

Explicit structured logging. Unhandled events at Info or above go to stderr.
Log is independent of IO.All; locations and attributes are always explicit.

```benitoite
public data Level
  Debug
  Info
  Warn
  Error
end data
```

Ordered logging levels. Error does not terminate execution.

```benitoite
public data Value
  Text(String)
  Boolean(Benitoite.Boolean)
  Integer(Benitoite.Integer)
  UnsignedInteger(UnsignedInteger64)
  Float(Benitoite.Float)
end data
```

Structured scalar values; conversion from arbitrary Show instances is not implicit.

```benitoite
public record Attribute
  key: String
  value: Value
end record
```

One attribute. Lists preserve order and duplicate keys.

```benitoite
public record Record
  level: Level
  message: String
  attributes: List[Attribute]
  location: SourceLocation.Location
end record
```

One explicit log event, including its caller-supplied location.

```benitoite
public effect Log
  /// Sends one event to the selected handler.
  function emit(record: Record) -> Unit
  /// Asks whether the selected handler accepts this level.
  function enabled(level: Level) -> Benitoite.Boolean
end effect
```

Structured logging, independent of Console.Write and IO.All.

```benitoite
public trait ToLogValue[T]
  /// Converts once without implicit Show conversion.
  function toLogValue(value: T) -> Value
end trait
```

Values that have an explicit structured scalar representation.

```benitoite
public function attribute[T: ToLogValue](key: String, value: T) -> Attribute
```

Converts `value` once and associates it with `key`.

```benitoite
public function debug(message: String, attributes: List[Attribute], location: SourceLocation.Location) -> Unit uses Log
```

Emits one Debug event. Argument evaluation is eager.

```benitoite
public function info(message: String, attributes: List[Attribute], location: SourceLocation.Location) -> Unit uses Log
```

Emits one Info event. Argument evaluation is eager.

```benitoite
public function warn(message: String, attributes: List[Attribute], location: SourceLocation.Location) -> Unit uses Log
```

Emits one Warn event. Argument evaluation is eager.

```benitoite
public function error(message: String, attributes: List[Attribute], location: SourceLocation.Location) -> Unit uses Log
```

Emits one Error event. Argument evaluation is eager.

```benitoite
public function withAttributes[T, effect E](attributes: List[Attribute], body: function() -> T uses Log, E) -> T uses Log, E
```

Prepends common attributes, preserving duplicates, event location, and outer effects.

```benitoite
public function withTextLogger[T, effect E](minimum: Level, body: function() -> T uses Log, E) -> T uses Console.Write, E
```

Handles both Log operations and writes accepted events to stderr in the default format.

```benitoite
public function withSinks[T, effect E](sinks: List[Pair[Level, (function(record: Record) -> Unit uses E)]], body: function() -> T uses Log, E) -> T uses E
```

Calls accepted sinks once each in list order. An empty list discards every event.
A sink's failure or stop propagates before any following sink is called.

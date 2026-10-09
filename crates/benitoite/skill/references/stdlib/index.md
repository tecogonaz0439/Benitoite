# Benitoite standard library

The modules of the standard library. Each module has its own file in this directory. Unofficial modules may change; their import name changes when they become standard.

| Module | Status | Import | Description |
|---|---|---|---|
| [Integer](Integer.md) | standard (prelude) | not needed | Functions on `Integer`, the 64-bit signed integer type. |
| [Float](Float.md) | standard (prelude) | not needed | Functions on `Float`, the IEEE 754 double-precision type. |
| [Decimal](Decimal.md) | standard (prelude) | not needed | Functions on `Decimal`, the 128-bit decimal fraction type. |
| [RoundingMode](RoundingMode.md) | standard (prelude) | not needed | Rounding directions for `Decimal.round`. |
| [Byte](Byte.md) | standard (prelude) | not needed | Functions on `Byte`, the integers from 0 to 255. |
| [Character](Character.md) | standard (prelude) | not needed | Functions on `Character`, a Unicode scalar value. |
| [String](String.md) | standard (prelude) | not needed | Functions on `String`, a sequence of Unicode scalar values. |
| [Boolean](Boolean.md) | standard (prelude) | not needed | The type `Boolean` with the values `true` and `false`. |
| [List](List.md) | standard (prelude) | not needed | Functions on `List`. |
| [Map](Map.md) | standard (prelude) | not needed | Functions on `Map`, a persistent map ordered by its keys. |
| [Set](Set.md) | standard (prelude) | not needed | Functions on `Set`, a persistent set ordered by its elements. |
| [Option](Option.md) | standard (prelude) | not needed | Optional values. |
| [Result](Result.md) | standard (prelude) | not needed | Results of operations that may fail. |
| [Pair](Pair.md) | standard (prelude) | not needed | Pairs of two values. |
| [Triple](Triple.md) | standard (prelude) | not needed | Triples of three values. |
| [IOError](IOError.md) | standard (prelude) | not needed | Failures of IO operations. |
| [IOErrorKind](IOErrorKind.md) | standard (prelude) | not needed | Kinds of IO failures. |
| [Reference](Reference.md) | standard (prelude) | not needed | Mutable cells. |
| [Lazy](Lazy.md) | standard (prelude) | not needed | Explicitly delayed values, made with `lazy ... end lazy`. |
| [Task](Task.md) | standard (prelude) | not needed | Running tasks concurrently and waiting for their results. |
| [TaskGroup](TaskGroup.md) | standard (prelude) | not needed | Groups of tasks started one by one. |
| [IO](IO.md) | standard (prelude) | not needed | The effect `IO.All`, which stands for all the effects of the modules under `Benitoite.IO`. |
| [IO.Clock](IO.Clock.md) | unofficial | `import Benitoite.Unofficial.IO.Clock` | Reading the clock and waiting for time to pass. |
| [IO.Console](IO.Console.md) | unofficial | `import Benitoite.Unofficial.IO.Console` | Standard input, standard output, and standard error. |
| [IO.File](IO.File.md) | unofficial | `import Benitoite.Unofficial.IO.File` | Reading and writing files. |
| [IO.Process](IO.Process.md) | unofficial | `import Benitoite.Unofficial.IO.Process` | The running process: its arguments and its exit. |
| [Trait](Trait.md) | standard | `import Benitoite.Trait` | Standard type classes. |
| [Assert](Assert.md) | standard (prelude) | not needed | Checks of expected values in tests. |
| [Bytes](Bytes.md) | standard (prelude) | not needed | Functions on `Bytes`, an immutable sequence of `Byte` values. |
| [ByteOrder](ByteOrder.md) | standard (prelude) | not needed | Byte orders for reading and writing integers in `Bytes`. |
| [NetworkError](NetworkError.md) | standard (prelude) | not needed | Failures of network operations. |
| [NetworkErrorKind](NetworkErrorKind.md) | standard (prelude) | not needed | Kinds of network failures. |
| [Time](Time.md) | unofficial | `import Benitoite.Unofficial.Time` | Points in time and calendar dates with a fixed offset from UTC. |
| [IO.Random](IO.Random.md) | unofficial | `import Benitoite.Unofficial.IO.Random` | Random numbers. |
| [Path](Path.md) | unofficial | `import Benitoite.Unofficial.Path` | Joining and splitting paths as strings. |
| [Json](Json.md) | unofficial | `import Benitoite.Unofficial.Json` | JSON values, parsing, and writing. |
| [Regex](Regex.md) | unofficial | `import Benitoite.Unofficial.Regex` | Regular expressions with matching time linear in the input. |
| [Csv](Csv.md) | unofficial | `import Benitoite.Unofficial.Csv` | Reading and writing CSV as in RFC 4180. |
| [Encoding](Encoding.md) | unofficial | `import Benitoite.Unofficial.Encoding` | Base64 encoding of bytes. |
| [Hash](Hash.md) | unofficial | `import Benitoite.Unofficial.Hash` | Hash values of bytes. |
| [Network.Http](Network.Http.md) | unofficial | `import Benitoite.Unofficial.Network.Http` | HTTP/1.1 servers without TLS and clients for http and https URLs. |

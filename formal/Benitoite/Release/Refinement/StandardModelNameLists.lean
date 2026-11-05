/-! # 組込みの表の完成が読む名前の一覧

利用者のプログラムの組込みの表を、合成表の行と仮定側の行で完成させるときの、仮定側の名前の区分と資源の種類の名前で
ある（設計書 07-04「01-12 との対応」）。台帳から生成する（手で直さない）。合成側の名前は合成表の行から作る
（`StandardModel.nameLists`）。 -/
namespace Benitoite.Release.Refinement.StandardModel

/-- δ の応答の条件で量化する名前（80）。 -/
def deltaNames : List String :=
  ["%Boolean.toString", "%List.length", "%List.getBack", "%List.slice", "IOError.message", "IOError.kind",
   "Trait.showString", "Trait.showCharacter", "NetworkError.kind", "NetworkError.message", "Random.fromSeed",
   "Random.nextInteger", "Random.nextFloat", "Random.shuffleWith", "Path.join", "Path.joinAll", "Path.parent",
   "Path.fileName", "Path.stem", "Path.extension", "Path.withExtension", "Path.isAbsolute", "Path.components",
   "Path.normalize", "Json.parse", "Json.stringify", "Json.stringifyPretty", "Regex.compile", "Regex.isMatch",
   "Regex.find", "Regex.matchText", "Regex.matchByteStart", "Regex.matchByteEnd", "Regex.group",
   "Regex.namedGroup", "Regex.replaceFirst", "Regex.findAt", "Regex.spanAt", "Regex.maxStringBytes",
   "Csv.parse", "Csv.parseWith", "Csv.parseWithHeader", "Csv.format", "Csv.formatWith",
   "Time.fromUnixSeconds", "Time.fromUnixMilliseconds", "Time.toUnixSeconds", "Time.toUnixMilliseconds",
   "Time.addMilliseconds", "Time.differenceMilliseconds", "Time.toDateTime", "Time.fromDateTime",
   "Time.formatISO8601", "Time.parseISO8601", "Time.format", "Encoding.base64Encode", "Encoding.base64Decode",
   "Encoding.base64UrlEncode", "Encoding.base64UrlDecode", "Hash.sha256", "Network.Http.pathSegments",
   "Scope.checkHost", "Scope.checkPath", "Scope.checkEndpoint", "SourceLocation.here", "Log.formatRecord",
   "%Format.Integer", "%Format.Integer8", "%Format.Integer16", "%Format.Integer32", "%Format.Byte",
   "%Format.UnsignedInteger16", "%Format.UnsignedInteger32", "%Format.UnsignedInteger64", "%Format.Float",
   "%Format.Float32", "%Format.Decimal", "%Format.String", "%Format.Character", "%Format.Boolean"]

/-- IO 応答の条件で量化する名前（47）。 -/
def ioNames : List String :=
  ["Console.write", "Console.writeLine", "Console.writeError", "Console.writeErrorLine", "Console.readLine",
   "Console.readAll", "File.writeText", "File.appendText", "Process.arguments", "Process.exit", "Clock.sleep",
   "Clock.monotonicMilliseconds", "Assert.equal", "Assert.notEqual", "Assert.isTrue", "Assert.fail",
   "Console.readAllLines", "Console.readAllBytes", "Process.scriptDirectory", "Process.environmentVariable",
   "Process.workingDirectory", "Clock.now", "Clock.localOffsetMinutes", "File.readBytes", "File.readLines",
   "File.exists", "File.info", "File.listDirectory", "File.walk", "File.canonicalize", "File.writeBytes",
   "File.appendBytes", "File.createDirectory", "File.remove", "File.removeTree", "File.rename", "Process.run",
   "Process.runAttached", "Process.shell", "Random.integer", "Random.float", "Random.boolean",
   "Random.shuffle", "Random.choose", "Http.send", "Log.emit", "Log.enabled"]

/-- 通常資源の作成・参照・解放の名前（分類と抽象の解放の境界だけを受ける）（16）。 -/
def stateNames : List String :=
  ["File.openReader", "File.readLine", "File.closeReader", "File.readChunk", "File.openWriter", "File.write",
   "File.writeLine", "File.writeChunk", "File.closeWriter", "Http.listen", "Http.listenerPort", "Http.accept",
   "Http.respond", "Network.Http.requestOf", "Network.Http.closeListener", "Network.Http.closeExchange"]

/-- 形式化の外の名前（署名を持たせない）（7）。 -/
def outsideNames : List String :=
  ["Task.all", "Task.allOk", "Task.race", "Task.withTimeout", "Task.await", "TaskGroup.open",
   "TaskGroup.spawn"]

/-- 通常資源の状態の名前が作る資源の種類の名前（形式化の外の TaskGroup を除く）。 -/
def resourceNames : List String :=
  ["File.Reader", "File.Writer", "Http.Listener", "Http.Exchange"]

end Benitoite.Release.Refinement.StandardModel

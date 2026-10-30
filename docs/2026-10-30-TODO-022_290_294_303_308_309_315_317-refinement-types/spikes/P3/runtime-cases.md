# P3: 本番の入力と期待する結果

## 使い方と検査の境界

以下は本番の実装プランへ渡す受け入れ入力であり、今回実行していない。篩の字面 `Integer{v | ...}` と `range R: path`、`--proof-steps`、関数ごとの上限指定は提案または暫定である。新しい構文の解析に成功したという記録ではない。既存の構文で書ける入力も、本担当は再実行していない。

型検査の期待は本番の `check`、評価順・値の保持の期待は通常の `run`/VM/参照インタプリタの比較を境界にする。表層の型検査だけ通して終えず、受理入力は脱糖したコアの独立検査も通す。テストは以下の行を既存の表へ加えることを基本とし、同じ契約を各層へ重複して追加しない。新規の差し込み口は要らない。CLIの表示は実際のCLI境界、オブジェクトの同一性は既存raw呼出しと`same_object`の境界にだけ置く。

診断の意味を先に固定し、新しい番号を本書で発行しない。現行の `E0519 unknownSource` などは現行の期待を示す。新しい拒否には「要求した契約・分かった条件・証明できなかった条件・失敗した引数/結果/欄・反例かunknownか」を出す。unknownを反例や範囲外と表示しない。

## 名前付き引数と値の代入

N1〜N4は新しい篩構文の提案・未実行である。各変種は関数定義と呼出しを一つのファイルに置く。

```text
function bounded(n: Integer{v | 0 <= v},
                 i: Integer{v | 0 <= v and v < n}) -> Integer
  return i
end function

function sample() -> Integer
  return bounded(i: 2, n: 3)
end function
```

| ID | 入力の変種 | 型検査・実行の期待 | 捕まえる退行 |
|---|---|---|---|
| N1 | 上のまま | 受理、2を返す。iの端点へ宣言上のn=3を代入 | ソースの先頭i=2をnへ代入して誤拒否する |
| N2 | `bounded(n: 3, i: 2)`へ順を替える | N1と同じ公開契約・受理理由、2 | 制約の登録順でT/述語の具体化が変わる |
| N3 | `bounded(i: 3, n: 3)` | 拒否。i引数で`3 < 3`が成り立たない。検証済みの定数反例 | 等号境界の取り違え、仮定して証明する注釈 |
| N4 | nとiのラベルを`max`/`index`へ一貫して付け替え、ローカル名にnを別途使う | 元と同じ受理。内部番号は名前の偶然一致に依存しない | 束縛の捕獲、名前による代入 |

値の評価順は、既存のConsole効果を使う次の入力で観測する（篩の部分だけ提案・未実行）。`mark`の引数ラベルは現在の通常の名前付き引数である。

```text
import Benitoite.IO.Console

function mark(label: String, value: Integer) -> Integer uses Console.Write
  Console.writeLine(label)
  return value
end function

function bounded(n: Integer{v | 0 <= v},
                 i: Integer{v | 0 <= v and v < n}) -> Integer
  return i
end function

function sample() -> Integer uses Console.Write
  return bounded(i: mark(label: "i", value: 2),
                 n: mark(label: "n", value: 3))
end function
```

このままではmarkの公開契約が結果とvalueの関係を持たないため、N5は自動的には受理を要求しない。**受理版**ではmarkの戻りを `Integer{v | v = value}` と明示して本体を検査する。受理版の出力は`i`、`n`が各一回、この順であり、結果は2である。N6として順を逆にすれば出力は`n`、`i`、結果は2とする。述語を求めるためmarkを再実行する実装、宣言順に並べてからmarkを実行する実装が失敗する。本番の実行入口がmainにUnitを要求する場合は、このsampleをmainから呼び出してAssertで値を確認し、出力はsampleの二行だけを比較する。

N7は部分適用の評価時点である。同じ受理版markとboundedを用い、次のsampleを検査・実行する。

```text
function sample() -> Integer uses Console.Write
  bind f <- bounded(i: _, n: mark(label: "n", value: 3))
  bind first <- f(i: 2)
  bind second <- f(i: 1)
  return first + second
end function
```

期待は受理、出力`n`が呼出しごとに一回の計二回、結果3である。現行の部分適用は固定引数も生成ラムダの本体へ置く（`ir/desugar/exprs.rs:450–469,486–488`、設計書01-02「部分適用のプレースホルダ」の431行）。したがって、部分適用作成時にnを一回評価して捕捉するように変えてはならない。依存する型に使うnも各回の同じ評価値へ結ぶ。

## callbackの反変と本体の検査

H1〜H7は新しい篩構文の提案・未実行である。

```text
type Small = Integer{v | 0 <= v and v <= 10}

function wide(value: Integer) -> Integer
  return value
end function

function narrow(value: Small) -> Integer
  return value
end function

function useSmall(f: function(value: Small) -> Integer) -> Integer
  return f(5)
end function

function useAll(f: function(value: Integer) -> Integer) -> Integer
  return f(-1)
end function
```

| ID | sampleの本体/変種 | 期待 | 捕まえる退行 |
|---|---|---|---|
| H1 | `return useSmall(f: wide)` | 受理、5 | 関数入力を等号または共変で比較 |
| H2 | `return useAll(f: narrow)` | 拒否、callbackの入力契約が合わない。-1は許される呼出しの具体例 | 反変の向きを逆にする |
| H3 | `return useSmall(f: lambda(value: Integer) -> Integer return value end lambda)` | H1と同じ | 名前付き関数と注釈ラムダで規則が変わる |
| H4 | `useSmall`のcallback結果もSmallにし、`lambda(value: Integer) -> Small return value end lambda`を渡す | 拒否。ラムダ自身の入力Integerの文脈では結果Smallを示せない。value=-1 | 期待する狭い入力で注釈ラムダ本体を検査し直す |
| H5 | H4のラムダの引数・戻り注釈を両方外し`lambda(value) return value end lambda`とする | 受理。期待するSmall入力とSmall結果で本体を検査 | 無注釈への期待型を渡さず先にIntegerへ固定 |
| H6 | `useSmall`の宣言する引数名fは保ち、callbackの名前を期待側`item`、実際側`value`にする | 拒否。引数名の契約はF3でも維持。新しい篩の反例とは区別して名前の食い違いを診断 | 反変にした結果、名前の契約を消す |
| H7 | Small→Smallを返す関数を、Small→Integerを返す関数として渡す | 受理。関数の結果の中の関数も共変/反変で再帰照合 | F3を最外だけに適用 |

H8は篩を含まない既存構文の変更である。`function(value: Integer) -> Unit`の純粋な関数を、`List[function(value: Integer) -> Unit uses Console.Write]`の要素へ渡す形を、Listの変数を介して比較する。F3とListの共変を採ったため受理とする。同じ内容をReferenceの内側やFailの失敗型へ入れたH9は構造等号が合わなければ拒否とする。ここでのListの要素の違いを、本体のConsole効果の有無で代用しない。

## try・mapError・パイプへの期待型

T1〜T7は新しい篩構文の提案・未実行である。API名に依存する組込み認定を避け、利用者の通常のcheck関数で確かめる。

```text
type Port = Integer{v | 1 <= v and v <= 65535}

function checkedPort(value: Integer) -> Result[Port, String]
  if 1 <= value and value <= 65535 then
    return Result.Ok(value)
  else
    return Result.Error("outside port range")
  end if
end function

function load(value: Integer) -> Result[Port, String]
  bind port: Port <- try checkedPort(value: value)
  return Result.Ok(port)
end function
```

| ID | 入力の変種 | 期待する静的/動的結果 | 捕まえる退行 |
|---|---|---|---|
| T1 | 上のまま、value=443 / 0 | 受理。loadはOk(443) / Error文字列。内側Resultの型注釈は不要 | Try構造を解く前に篩を失う |
| T2 | bind右辺を `try Result.mapError(r: checkedPort(value: value), f: lambda(error) return error end lambda)` | T1と同じ。成功のPortを保つ | mapErrorのTがIntegerへ先に固定される |
| T3 | `checkedPort(value: value) |> Result.mapError(r: _, f: lambda(error) return error end lambda)`をtryの対象にする | T1と同じ | 穴の関数型とpipeの制約が期待型を遮る |
| T4 | `value |> checkedPort()`をtryの対象にする | T1と同じ。pipeの左辺を一度だけ評価 | 先頭挿入と穴付きの二形で差が出る |
| T5 | `import Benitoite.Unofficial.IO.Process`を足し、`function load(value: Integer) -> Port uses Process.Exit`、`bind port: Port <- try checkedPort(value: value) or die`、`return port` | 受理。443は443。0の終了は既存or dieの仕様に従う。篩を導くため正常実行を再試行しない | or dieで成功値の期待型が消える |
| T6 | `checkedPort`の正常枝を無条件`Result.Ok(value)`にする | 拒否。公開のPort契約は本体で示す必要がある | 関数の宣言結果を無検査で信用する |
| T7 | 失敗型を変換せず、loadの結果を`Result[Port, Integer]`にする | 拒否、失敗型の食い違い。Portのunknownとは区別 | Resultの共変をFail/or returnの不変な契約へ無差別に使う |

T8は呼出し制約を並べ替えた同値入力、T9はifの両枝の順を替えた同値入力とする。使う公開契約、受理の理由、checkの静的範囲、型の表示を比較する。内部変数番号や探索の訪問順の完全一致までは要求しない。

## PathInの関数・戻り値・通常の式位置

S1〜S12は現在の範囲構文で書ける。新しい受理の期待はU1の提案・未実行である。各変種は独立のファイルとする。

```text
import Benitoite.Unofficial.Scope

function project(path: Scope.PathIn["/data/**"]) -> String
  return Scope.pathInValue(path: path)
end function

function keep(path: Scope.PathIn["/data/a"]) -> Scope.PathIn["/data/a"]
  return path
end function

function widen(path: Scope.PathIn["/data/a"]) -> Scope.PathIn["/data/**"]
  return path
end function
```

| ID | 入力/変種 | 期待と現在の根拠 | 独立した契約 |
|---|---|---|---|
| S1 | project | U1で受理。現行の同等入力は`tests/scoped_calls.rs:191–194`がE0519 unknownSourceを期待 | 検査済み関数引数の型から射影 |
| S2 | keepの結果をprojectへ直接渡す | 受理、同じ保持パス | 宣言結果と入れ子の通常呼出しから所属 |
| S3 | widen | 受理。同じPathIn値を再包装しない | 明示APIなしの共変 |
| S4 | widenの元と先を逆にする | 拒否。`/data/b`は元に属し先に属さない | 狭める受渡しの拒否 |
| S5 | projectの中を`bind text <- Scope.pathInValue(path: path)`、`return text`へ変更 | S1と同じ。bind位置の有無で受理差を作らない | TODO-308の位置制限の除去 |
| S6 | `return [Scope.pathInValue(path: path)]`、戻り`List[String]` | 受理 | List要素の通常の式位置 |
| S7 | `return path |> Scope.pathInValue()` | 受理 | pipe左辺でも型から所属 |
| S8 | `return "${Scope.pathInValue(path: path)}"` | 受理。現行の補間構文は01-02の580行と一致 | 補間の通常の式位置 |
| S9 | `function hide(path: Scope.PathIn) -> Scope.PathIn return path end function`を別モジュールに置き、project内で`bind top <- hide(path: path)`、`bind narrow: Scope.PathIn["/data/a"] <- top` | 拒否。公開契約はTopなので、本文を解析せず狭い型を与えない。元の値と同じという公開の依存契約は持たない | 公開契約を越えた由来の信用を拒否 |
| S10 | `function forged(path: String) -> Scope.PathIn["/data/a"] return path end function` | 拒否、前の型が違う。Stringからの暗黙の包装なし | 所属以前のopaque境界 |
| S11 | `function forged(path: Scope.PathIn) -> Scope.PathIn["/data/a"] return path end function` | 拒否、Top→狭い範囲の証拠なし | TODO-308 A5の反例 |
| S12 | checkPathInの実行時入力を動的に`/outside`とし静的Rを`/data/**`へ具体化する | 成功値を作らずResult.Error。型検査で受理するなら必ずその静的Rへの検査を実施 | runtime-builtinの静的添字の検査。既存raw期待`tests/runtime_builtins.rs:1986–2023`へ合流 |

S13は関数境界のモジュール分割である。keepを別モジュールの公開関数へ移し、呼出し元が本文を解析しなくてもS2を受理する。S14は再帰で、宣言した狭い引数・結果契約を使って同じ保持値を返す正常経路を検査する。正常な結果の契約から停止性を結論しない。

## IO範囲を拡大前の入力から選ぶ

以下は現行構文のまま、新しいU1での選択期待を固定する。検査だけなら実ファイルに接触しない。実行を確かめる場合も、既存の外部IOのハンドラ表で実対象を置き換える。

```text
import Benitoite.Unofficial.Scope
import Benitoite.IO.File

function direct(path: Scope.PathIn["/data/a"]) -> Result[String, IOError]
  uses File.Read["/data/**"]
  return File.readTextIn(path: path)
end function

function stored(path: Scope.PathIn["/data/a"]) -> Result[String, IOError]
  uses File.Read["/data/**"]
  bind wide: Scope.PathIn["/data/**"] <- path
  return File.readTextIn(path: wide)
end function
```

| ID | 入力 | 期待する添字と結果 | 捕まえる退行 |
|---|---|---|---|
| I1 | direct | 当該IOの入力添字は`/data/a`。外側の宣言上限は`/data/**`のまま | 許容効果からRを広げる/狭める |
| I2 | stored | 当該IOの添字は明示保存した`/data/**` | 以前の狭い由来を、広い型で保存した後も勝手に使う |
| I3 | directの入力を裸のScope.PathInにし、usesを狭いままにする | 拒否。R=Topを狭いFile.Readで覆えない | 周囲のusesから入力を逆算する |
| I4 | `bind f: function(path: Scope.PathIn["/data/a"]) -> Result[String, IOError] uses File.Read["/data/a"] <- File.readTextIn`の後にfを呼ぶ | 入力契約から一度具体化し受理 | 関数値化を常にTopへ固定する |
| I5 | I4の注釈を除き、後の呼出しの入力だけをPathIn["/data/a"]にする | 後の入力制約から同じRを具体化し受理 | 直接呼出しだけの特例 |
| I6 | File.readTextInを無制約の関数値として保存し外へ渡す | 入力も期待も最後までなければTop。狭い効果で認定しない | 無制約のTop規則 |
| I7 | 比較不能な候補があり、唯一の入力契約を選べない形 | 注釈を求めて拒否。無制約Topと同じ診断にしない | 不足した情報をTopへの黙った既定化で隠す |

I7の具体的な入力は本番solverが選ぶ合流の表現に依存する。`if flag then File.readTextIn else File.readBytesIn`は結果型自体も違って別の理由で拒否されるので、この目的の否定例に使わない。同じ結果型・同じ名前の契約の関数だけで反変入力の合流を作り、どの候補も単独で選べないことを確かめてから固定する残件である。

## handler節の具体化とRequestInの保持

L1は現在の構文である。U1での受理を提案する。

```text
import Benitoite.Unofficial.Scope
import Benitoite.IO.File

function sample(path: Scope.PathIn["/data/a"]) -> Result[String, IOError]
  uses File.Read["/data/a"]
  return handle File.readTextIn(path: path) with
    case File.readTextIn(captured) ->
      bind text <- Scope.pathInValue(path: captured)
      resume(Result.Ok(text))
  end handle
end function
```

| ID | 入力・変種 | 期待 | 現行の根拠・検査する境界 |
|---|---|---|---|
| L1 | 上のまま | 受理、同じ保持パスが節に入る。resumeへ正しいResultを渡す | `tests/scoped_calls/file_io.rs:225–269`は現在unknownSourceを期待 |
| L2 | 節内で`bind wide: Scope.PathIn["/data/**"] <- captured`して射影 | 受理、同じ保持パス | 型の部分型と節型の具体化を接続 |
| L3 | sample入力を裸のPathIn、効果もFile.Readにし、節内だけ狭い注釈へ渡す | 拒否。節名だけから狭い添字を作れない | 旧Top節射影の受理と、Top→狭い導入を分ける |
| L4 | 節内の射影をresumeの引数の中へ直接書く | L1と同じ受理と値 | bind位置の特例を除く |
| L5 | `resume(Result.Ok(123))`へ変える | 拒否、操作の結果型と違う | 節所属の拡張で再開の型契約を消さない |

R1はHttp版の節の入力である（現在の範囲構文、新しい受理は提案・未実行）。

```text
import Benitoite.Unofficial.Network.Http

function sample(request: Http.RequestIn["api.example", 443])
  -> Result[Http.Response, NetworkError] uses Http.Connect["api.example", 443]
  return handle Http.sendIn(request: request) with
    case Http.sendIn(captured) ->
      bind original <- Http.requestInValue(request: captured)
      resume(Result.Ok(Http.text(status: 200, s: Http.ClientRequest.url(original))))
  end handle
end function
```

| ID | 入力・変種 | 期待 | 独立した契約 |
|---|---|---|---|
| R1 | 上のまま | 受理。節は保持した同じ要求を読む | `tests/scoped_calls/http_io.rs:202–238`のunknownSource期待をU1へ更新 |
| R2 | 節で`bind wide: Http.RequestIn["**.example", 400..500] <- captured`、wideを射影 | 受理。host/port/要求全欄を維持 | 共変が保持endpointを作り直さない |
| R3 | 射影したClientRequestのURLを`https://other.example/`へ更新してsendInに直接渡す | 拒否。ClientRequestはRequestInでない | 生の要求と保持要求を暗黙変換しない |
| R4 | 更新した要求をcheckRequestInで再検査 | 元の範囲がapi.exampleならError。other.exampleを許す新しいcheckなら新しいRequestInを作る。元のcapturedはapi.exampleのまま | 再包装のチェックと不変性 |
| R5 | Method=POST、URLにquery、body、headers、timeoutを持つ要求をcheck→暗黙拡大→射影 | 全欄一致。raw境界では元の要求と同じobject、保持wrapperも拡大前後で同じobject | 既存`tests/runtime_builtins.rs:1911–1978`を拡張。構造の等値だけで済ませない |
| R6 | HostヘッダがURLと違う要求を純粋check後にsendInする | checkの成功だけで送信成功を主張しない。sendInがInvalidInputを返し、異なる宛先へ送らない | `builtins/funcs/http_client.rs:56–63,314–334`の送信前検査 |
| R7 | 3xx応答、proxy設定のある環境 | scoped sendInは別endpointへ追従/自動proxy接続しない。DNS/TLSの副次通信をこの期待へ含めない | `builtins/funcs/http_client.rs:115–123,153–167`。既存の実通信テストの外部境界を再利用 |

## ストア・閉包・変性の反例

C1〜C7は新しい篩構文の提案・未実行である。

```text
type Nonnegative = Integer{v | 0 <= v}

function overwrite(cell: Reference[Integer]) -> Unit uses State
  Reference.set(reference: cell, value: -1)
end function

function bad() -> Nonnegative uses State
  bind narrow: Reference[Nonnegative] <- Reference.new(value: 0)
  overwrite(cell: narrow)
  return Reference.get(reference: narrow)
end function
```

| ID | 入力・変種 | 期待 | 破れる場合 |
|---|---|---|---|
| C1 | 上のbad | overwriteへの引数で拒否 | Referenceの共変により-1をNonnegativeとして読む |
| C2 | overwriteを除きnew→get | 受理、0 | 保存された値の篩をgetで失う |
| C3 | `Reference.update`のfが`lambda(value: Nonnegative) -> Nonnegative return -1 end lambda` | 拒否、callback結果契約 | updateが保存する結果だけ型検査を飛ばす |
| C4 | 同じfが`return value + 1` | 正常結果のNonnegativeを示せる場合に受理。最大値では既存の溢れStopを許す。成功を常に保証しない | 数学上の結果と機械整数の正常値を同一視 |
| C5 | Nonnegativeの保存値を閉包から返す、Lazyへ入れforceする、継続から再開する | 同じ条件を維持。GC stressでも対象を失わない。各境界は既存の差分/GCテストに接続 | 型内の自由な局所値、取り落とした根、再開契約の消失 |
| C6 | `List[Nonnegative]`→`List[Integer]`、`Map[String, Nonnegative]`→`Map[String,Integer]` | 受理。同じ構築済み成分を広く読む | 全Conを等号比較するまま |
| C7 | `Set[Nonnegative]`→`Set[Integer]`、Mapの鍵の変更、`Reference[Nonnegative]`→`Reference[Integer]` | 拒否。各不変位置の契約を示す | Listの共変を全型構成子へ無条件に広げる |

C8はsnapshotの検査である。`bind n <- Reference.get(reference: cell)`の値に`n>=0`を示した後、セルへ-1を書き込む。保存したnには元の条件を使えるが、再びgetした値へ元の条件を使ってNonnegativeを返す関数は拒否する。Referenceそのものの現在値を不変のmeasureとして登録する実装を捕まえる。レコードの不変なListの長さは、要素にReferenceを含んでも同じ長さを保つという別の入力も置く。

## JSON・Codec・derive・外部入力

D1〜D7は新しい篩構文・変換方針の提案であり未実行である。生成器の実際の設定形式は`tools/derive/README.md`と確認済みmanifestに従い、本書から架空のmanifestを作らない。

| ID | 本番へ渡す入力 | 期待 | 持ち主の境界と理由 |
|---|---|---|---|
| D1 | Json.parseの`"/outside"`をCodec.decodeString後、結果へPathIn["/data/**"]注釈だけを付ける | 拒否。String→PathInにはcheckが必要 | 通常の型検査。parseのfixtureでPathInを直接作らない |
| D2 | decodeString→checkPathIn、ScopeErrorをCodec.ConversionErrorへ明示変換 | 静的受理、/data/aはOk、/outsideはError | 手書きdecodeの実際の成功/失敗と同じ型契約 |
| D3 | opaque対象にJSON/Property生成を依頼 | 現在どおり拒否、手書きのchecked構築を求める | `tools/derive/derive.py:723–725`。opaque境界を新構文で迂回しない |
| D4 | 非opaque record `Bounds(lo:Integer, hi:Integer)`の外側に`lo<=hi`の篩を付け、JSON `{lo:9,hi:2}`をdecode | 全体の検査でErrorか、検査器を生成できず事前に明確に拒否。無条件Okは禁止 | 欄ごとのdecodeは成功するが、record全体の条件は偽 |
| D5 | D4の入力を`{lo:2,hi:9}`に変更 | 生成/手書きの全体checkを実装した構成ならOk。入力内容をエラーへ不用意に埋めない | 成功/失敗双方で全体checkが実物として通る |
| D6 | D4のProperty縮小器がloだけを縮める/hiだけを縮める結果 | 出力が全体の条件を満たすか、明示のcustom shrinkerを要求する。条件を壊した成功値を返さない | 一欄ずつの縮小の限界を全体条件へ接続 |
| D7 | 外部関数の結果にPathIn/RequestInを直接、record/List/Option/Result内へ入れて宣言 | 現在のABIでは型対応の拒否。篩ABIを採る場合は全入れ子の受信後checkを必須にする | `external/types.rs:56–64,170–194`の全ノードvalidate。WIT型が同形だけでは所属なし |

D4〜D6の二つの許容形は実装プランで一つへ決める。生成できないのに黙って通常recordだけを返す形は、どちらの方針でも受け入れない。処理系の中の段をテストダブルで置換してdecodeの成功値を先に作るテストは置かない。

## unknown・反例・ステップ数の上限

U1〜U9は判定の手続きと診断の受け入れ入力である。新しい篩構文・CLI引数・関数指定の正確な字面は提案・未実行である。P2の探索だけのoperation数を本番stepsの固定期待にしない。

| ID | 入力と操作 | 期待 | 誤った分類・計数を捕まえる条件 |
|---|---|---|---|
| U1 | `function half(x: Integer{v | 2*v = 1}) -> Integer{v | false} return x end function` | 入力領域が空なので、整数の矛盾を証明できれば受理。整数解なしを有理解x=1/2で覆さない | gcd丸め/整数分枝の証明を使う。空型自体を宣言エラーにしない |
| U2 | `function zero(x: Integer) -> Integer{v | 0 <= v} return x end function` | 拒否。x=-1など、ソースで表現できる検証済み反例を報告可能 | unknownと反例を区別 |
| U3 | List長さを独立変数へ純化した候補モデルでlength=-1 | ソースの反例と表示しない。非負性を登録して除くか、実現性未確認モデルとする | P2 RV M6/L4。JSONにもverified等の分類を残す |
| U4 | 下記16本の線形条件の生成増加例、各幅の上下限、10の無関係な`<>`を含む関数。拡張版は32本とmeasureの非負性も加える | ステップ上限内で証明成功か、上限超過unknownで拒否。Topへ変更して受理しない | P2の生成爆発とOrの展開。実用分布を測ったとは扱わない |
| U5 | U4の一つを十分な上限で通し、報告の使用数Nを取得。N-1/N/N+1の上限で再実行 | 完全に同じ入力・計数版でN以下のどちらを許すかを上限の定義に合わせ固定。N-1はunknown、NとN+1は同じ受理/証明結果となることを基本の期待にする | 境界の1ステップ漏れ、上限の出所、決定性。途中打切りの実際の値も記録 |
| U6 | CLIなし、根package指定、CLI指定、関数指定の各組合せ | 決定した優先順で有効上限と出所を表示。同じ制約が受けた上限をJSONで照合 | 既定100,000は仮。ソースの関数指定がその関数のproof stepsだけ上書き |
| U7 | 同じ依存パッケージを根の上限だけ変えて検査 | 依存側は自分のpackageのproof steps設定で検査。根のCLIが依存の設定をどう扱うかはREADME決定を計画で明確化してから期待を固定 | 全体の既定と各packageの検査責任の混同 |
| U8 | 実行時Integerの上端/下端、UnsignedInteger64の上端、19〜20桁を含む係数と端点 | 既存の機械値は表現可能な範囲内。数学上の端点をそのまま実行時リテラルとして構築しない。中間算術が未対応ならunknownで拒否しラップしない | 試作digits18を流用して既存の標準型の境界を拒む、またはoverflowを受理 |
| U9 | JSONで、unknownの理由、stepsの消費、有効上限、出所、計数版を比較 | 反例・候補不足・型構造未定・上限超過を区別し、上限超過で契約の意味を変えない | 曖昧なE0519 unknownSourceへの一括集約 |

U4の先行する短い本番入力は次である（新しい篩構文の提案・未実行）。P2の`rust/src/fixtures.rs:108–121`の`layered_explosion(8)`の16行をifの経路条件へ写した。全行を足すとxとyが消え、zの和が16以下となる。結果契約は16本の和から独立に定めた。無関係なaの`<>`は選言を増やす退行を確かめるためである。Benitoiteの不等号は`<>`であり、P2/RVの説明用の`!=`をソースへ写さない（`crates/benitoite/src/syntax/lexer.rs:671`）。

```text
function rows(
  x: Integer, y: Integer,
  z0: Integer, z1: Integer, z2: Integer, z3: Integer,
  z4: Integer, z5: Integer, z6: Integer, z7: Integer,
  z8: Integer, z9: Integer, z10: Integer, z11: Integer,
  z12: Integer, z13: Integer, z14: Integer, z15: Integer,
  a0: Integer, a1: Integer, a2: Integer, a3: Integer, a4: Integer,
  a5: Integer, a6: Integer, a7: Integer, a8: Integer, a9: Integer
) -> Integer{v | v <= 16}
  if (x + y + z0 <= 1 and x + y + z1 <= 1
     and x + y + z2 <= 1 and x + y + z3 <= 1
     and x - y + z4 <= 1 and x - y + z5 <= 1
     and x - y + z6 <= 1 and x - y + z7 <= 1
     and -x + y + z8 <= 1 and -x + y + z9 <= 1
     and -x + y + z10 <= 1 and -x + y + z11 <= 1
     and -x - y + z12 <= 1 and -x - y + z13 <= 1
     and -x - y + z14 <= 1 and -x - y + z15 <= 1
     and a0 <> 0 and a1 <> 0 and a2 <> 0 and a3 <> 0 and a4 <> 0
     and a5 <> 0 and a6 <> 0 and a7 <> 0 and a8 <> 0 and a9 <> 0) then
    return z0 + z1 + z2 + z3 + z4 + z5 + z6 + z7 + z8 + z9 + z10 + z11 + z12 + z13 + z14 + z15
  else
    return 0
  end if
end function
```

この条件のソース算術に溢れStopがあれば、正常な返却の契約に反しない。各幅の上下限はcheckerがΦへ入れるものも含めて計数する。まずaの10条件を除いた版、その後に加えた版を測り、U5の境界入力へ使う。16→64→288というP2の行数は、否定した結果条件と各幅の上下限を足したこの入力の行数の期待ではない。32行版はm=16へ同じ符号配置を広げる拡張入力として残す。

U6のpackage・関数指定の構文も未確定である。架空の設定キーを本番入力の成功例として固定しない。上限の優先関係は決定済みREADMEを正とし、設定構文が決まった時点で完全な入力へ落とす。

## 診断と受け入れの記録

各行の検査結果には、入力の実体、処理系の版、構成、ソースSHA-256、終了状態、診断JSON、選択した範囲の表示、使用steps/有効上限/出所を残す。受理の例には期待した値または効果を、拒否の例には失敗した契約の位置と理由を固定する。新構文未対応によるparseエラーや、import/効果漏れだけによる拒否を、狙った篩の拒否の成功として数えない。

現行テストの期待を引く箇所はruntime-audit.mdのファイルと行に従う。P3では本番テストを追加せず、Rust・Leanの実行もしていないため、上の全行の実行状態は未実行である。比較不能合流I7、生成器D4〜D6の方針、U4の32行への拡張、package/関数指定U6〜U7の字面は、入力の固定まで残す未完了項目であり、成功例の件数へ数えない。

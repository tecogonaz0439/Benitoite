# U02に提示する公開エラーの二案

2026-11-04。L50の[detail第9節](detail.md)から分けた比較材料である。名前と型は候補であり、公開契約の決定でも実装の記録でもない。U02の期限はL70前のままとする。L50はD61の内部保存と既存読者の追随までを行い、公開名・完全署名・観測形への写しはU02確定後・L70前に取りまとめが割り当てる。

両案とも、元の生入力、解析済み入力、解決後の原子列と対象、両起点、失敗種別を内部に持つ。保存値の切詰め、reprStr保存、解析失敗時の仮入力への置換は認めない。通常のShowではsecretsを一覧名/件数に抑え、引用・エスケープ・4096バイト上限を保つ。PathBasesとAtの公開名・完全署名もU02で別に確定する。

## 1. 七Stringと型付きrecordの比較

案Aは、暫定の七String観測に対応する`Scope.ScopeError.At`の7引数を公開する。案Bは`Scope.ScopeError.At(Scope.AtDetail)`を足し、`Scope.AtDetail`を次表のB列の9欄を持つ公開recordとする。表の順序は、Aでは公開欄のない2行を飛ばして7引数、Bでは9欄の宣言順となる。

| 欄名 | 案Aの型と内容 | 案Bの型 |
|---|---|---|
| failure | String：outsideScope/unbound:root等/secretsUnbound/invalidPattern/invalidTarget/dynamicCondition/staticIndex | Scope.AtFailure |
| originalPattern | String：元入力のタグ付きJSON。文字列は元の内容を完全に復元可能とする | Scope.AtInput |
| originalTarget | String：同じ符号化。要求は5欄をすべて保存 | Scope.AtInput |
| parsedPattern | 公開欄なし。内部の解析結果は保持 | Option[Scope.RangeExpr] |
| parsedTarget | 公開欄なし。内部の解析結果は保持 | Option[Scope.TargetInput] |
| resolvedPatterns | String：解決後の原子列をタグ付きJSON。未解決nullと空列[]を区別 | Option[List[Scope.RangeAtom]] |
| resolvedTarget | String：解決後の対象をタグ付きJSON。未解決はnull | Option[Scope.Target] |
| patternBase | String：none/root/cwd/home/work/tmp | Option[Scope.PathBase] |
| targetBase | String：同上 | Option[Scope.PathBase] |

Aは解析済み入力を独立した公開欄として提供しない。元入力が既に解析済みのPatternならその値は元入力のJSONに含むが、文字列入力を解析した結果は内部に残る。解析済み入力も一般に利用者が読む必要があるなら、AのJSONに欄を追加するか公開引数を増やす判断が別に要る。

Bの`AtInput`はText(String)/Pattern(Scope.RangeExpr)/Request(Http.ClientRequest)の和、`PathBase`はRoot/Cwd/Home/Work/Tmp、`AtFailure`は現行内部の7失敗（UnboundはPathBase引数）に対応する。RangeExpr/TargetInput/RangeAtom/Targetは内部の同名概念を型付きの公開dataへ写す案で、RangeAtomは`Scope.Domain.Range`に対応する。入れ子の型は第4節に列挙する。

次は静的添字への不所属から元のpatternを読む例である。候補名を用いた書き方の比較であり、現行CLIで検査したコードではない。Aで返すpatternは元入力そのものを表すJSON文字列となる。

```benitoite
match error with
  case Scope.ScopeError.At("staticIndex", pattern, _, _, _, _, _) -> pattern
  case _ -> "other"
end match
```

Bでは、失敗種別と元入力の種類をdataの構成子で照合し、recordの欄を型付きで読む。Pattern/Requestもそれぞれの型で取り出せる。

```benitoite
match error with
  case Scope.ScopeError.At(detail) ->
    match Scope.AtDetail.failure(detail) with
      case Scope.AtFailure.StaticIndex ->
        match Scope.AtDetail.originalPattern(detail) with
          case Scope.AtInput.Text(pattern) -> pattern
          case _ -> "non-text input"
        end match
      case _ -> "other"
    end match
  case _ -> "other"
end match
```

## 2. 既存ScopeErrorの6構成子との対応

既存の公開形は[英語リファレンスのScope](../../reference/benitoite.md#scope)と[標準ソースScope.bnt](../../../crates/benitoite/src/prelude/stdlib/Scope.bnt)で照合した。Rustでは公開ScopeErrorを同名enumで定義していない。[builtins/table.rsのtags](../../../crates/benitoite/src/builtins/table.rs)が6構成子のタグ0〜5を定め、[checked_scope.rsのFailureとencoded/check_endpoint](../../../crates/benitoite/src/builtins/checked_scope.rs)が失敗の分類・英文reason・判定順を実装する。[funcs/scope.rs](../../../crates/benitoite/src/builtins/funcs/scope.rs)のpath_in_resultと[checked_request.rs](../../../crates/benitoite/src/builtins/funcs/http_client/checked_request.rs)のscope_errorが、タグと保持値へ写す読者である。

両案の基本案は、既存6構成子を変えず、Atのすべての失敗を新しいAtの内側へ置く。この選択では次の対応が生じる。各表の矢印は意味の対応であり、現行Atが旧構成子を実際に返すという記述ではない。Atの解析済み表現には不正なポート整数を入れられず、準備の拒否も含むため、旧6構成子とAtの7失敗は一対一ではない。

### 案Aの対応

| 既存の公開構成子と保持欄 | 既存の意味 | Atのfailure Stringとの対応・重複 |
|---|---|---|
| InvalidPattern(String pattern, String reason) | 条件の形式不正。元patternと英文reason | `"invalidPattern"`。patternの解析失敗は同じ役割。Atにはbound形成不適合も含まれる。元入力はoriginalPatternのJSONから読む。reason欄はない |
| InvalidTarget(String target, String reason) | 対象の形式不正。元targetと英文reason | `"invalidTarget"`。対象の解析失敗は同じ役割。Atにはground/reqTarget/valKind/basesの不適合も含まれる。元入力はoriginalTargetのJSONから読む。reason欄はない |
| InvalidPortRange(Integer minimumPort, Integer maximumPort) | 範囲端点が0〜65535外、又は上下逆転 | endpoint条件の解析拒否を`"invalidPattern"`へ分類するなら対応するが、現行Atには専用失敗がない。旧2整数はAtの専用欄にないため、元入力の符号化と解析器の拒否理由を別途確定する |
| InvalidPort(Integer port) | portが0〜65535外 | endpoint対象の解析拒否を`"invalidTarget"`へ分類するなら対応する。旧port専用欄はなく、元要求等をJSONに完全保存する。Atの全invalidTargetをInvalidPortとは扱えない |
| OutsideScope(String pattern, String target) | 形式は正しいが、動的なhost/path条件に不所属 | checkAtの対応する枝は`"dynamicCondition"`。`"staticIndex"`とは分ける。AtFailure.outsideScopeは構成子として存在するが、現行checkAtは返さず、旧OutsideScopeからの自動写像にも使わない |
| PortOutsideScope(Integer minimumPort, Integer maximumPort, Integer port) | 正しいportが条件の閉区間に不所属 | 動的endpoint条件のport不所属は`"dynamicCondition"`へ意味上対応。静的boundのport不所属は`"staticIndex"`で別の役割。現行Atはhost/port不所属を分けず、旧3整数の専用欄もない |

### 案Bの対応

| 既存の公開構成子と保持欄 | AtFailureとの対応 | AtDetailで読める値・重複 |
|---|---|---|
| InvalidPattern(String pattern, String reason) | InvalidPattern | 解析失敗の役割が重なる。originalPatternとparsedPatternの有無を型付きで読む。bound形成不適合もこの失敗種別。旧英文reasonに対応する欄はない |
| InvalidTarget(String target, String reason) | InvalidTarget | 解析失敗の役割が重なる。originalTarget/parsedTargetを読む。ground/reqTarget/valKind/basesの拒否まで含むため、旧対象文字列の形式不正より広い。旧英文reasonに対応する欄はない |
| InvalidPortRange(Integer minimumPort, Integer maximumPort) | endpoint条件の解析拒否をInvalidPatternへ分類するなら対応 | 正しい解析済み値ならEndpointPattern.portsのPortRangeで端点を読む。不正な端点はparsedPatternに入らないので元入力が根拠となる。旧2整数の専用欄はない |
| InvalidPort(Integer port) | endpoint対象の解析拒否をInvalidTargetへ分類するなら対応 | 正しい解析済みportはTarget.Endpointの中で読む。不正なportは元入力に残す。旧portの専用欄はない |
| OutsideScope(String pattern, String target) | checkAtではDynamicCondition。OutsideScopeというAtFailureも存在するが現行checkAtは返さない | original/parsed/resolvedのpattern/targetを読む。旧OutsideScopeの意味は維持し、StaticIndexやUnboundへ広げない |
| PortOutsideScope(Integer minimumPort, Integer maximumPort, Integer port) | 動的endpoint条件ならDynamicCondition、静的boundならStaticIndex | 解決後のRangeAtom.EndpointのPortRangeとTarget.Endpointから正しい端点/portを読む。ただし動的patternと静的boundのどちらの不所属かはfailureで区別し、旧構成子へ潰さない |

Atの全7失敗から見た残りの対応も示す。出どころは[ScopeSyntax.leanのAtFailure](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean)と[PathResolution.leanのcheckAt](../../../formal/Benitoite/Release/Refinement/PathResolution.lean)である。

| 内部の失敗 | 案A | 案B | 旧6構成子との関係 |
|---|---|---|---|
| outsideScope | `"outsideScope"` | OutsideScope | 同名の旧構成子とは別。現行checkAtの返却枝にはなく、内部値の観測・網羅性では残す。公開時に残す範囲と意味もU02で確定 |
| unbound b | `"unbound:root"`等5種 | Unbound(PathBase) | 対応なし。起点が未束縛で、形式不正/不所属とは区別 |
| secretsUnbound | `"secretsUnbound"` | SecretsUnbound | 対応なし。未指定と空一覧を区別 |
| invalidPattern | `"invalidPattern"` | InvalidPattern | 条件の解析失敗で旧InvalidPatternと重なる。port範囲不正を専用分類していない |
| invalidTarget | `"invalidTarget"` | InvalidTarget | 対象の解析失敗で旧InvalidTargetと重なる。port不正を専用分類していない |
| dynamicCondition | `"dynamicCondition"` | DynamicCondition | 旧OutsideScope/PortOutsideScopeと動的な不所属の役割が重なる |
| staticIndex | `"staticIndex"` | StaticIndex | 対応なし。準備の未具体化indexと検査時のbound不所属を混同しない |

旧APIでは、pattern形式→target形式→port範囲→port形式→host/path所属→port所属の順に最初の失敗を報告する。AtはprepareCore/finishPreparation/checkAtの順なので、旧APIと同じ入力拒否の順序を持つとは断定しない。AtFailureには拒否位置や英文reasonがなく、両案の基本案もそれを追加していない。旧reasonをAtでも読める要件を選ぶなら、次節の既存エラーを原因として持つ案、又は別のreason欄が要る。後者はAの七String規則又はBの9欄/AtFailure引数の変更となり、現案の署名や見込みへ黙って加えない。

### 同じ形式エラーを照合する例

Aでは旧APIとAt APIを横断して形式不正を処置すると、次の4枝になる。旧APIのreasonとAtのJSONは異なる情報なので、一方を他方の代用として表示しない。

```benitoite
match error with
  case Scope.ScopeError.InvalidPattern(pattern, reason) -> reason
  case Scope.ScopeError.InvalidTarget(target, reason) -> reason
  case Scope.ScopeError.At("invalidPattern", patternJson, _, _, _, _, _) -> patternJson
  case Scope.ScopeError.At("invalidTarget", _, targetJson, _, _, _, _) -> targetJson
  case _ -> "other"
end match
```

Bでも旧構成子とAt内の構成子の2段階を扱う。型付きの元入力は読めるが、旧APIと同じreasonが得られるわけではない。

```benitoite
match error with
  case Scope.ScopeError.InvalidPattern(pattern, reason) -> reason
  case Scope.ScopeError.InvalidTarget(target, reason) -> reason
  case Scope.ScopeError.At(detail) ->
    match Scope.AtDetail.failure(detail) with
      case Scope.AtFailure.InvalidPattern ->
        match Scope.AtDetail.originalPattern(detail) with
          case Scope.AtInput.Text(pattern) -> pattern
          case _ -> "non-text pattern"
        end match
      case Scope.AtFailure.InvalidTarget ->
        match Scope.AtDetail.originalTarget(detail) with
          case Scope.AtInput.Text(target) -> target
          case _ -> "non-text target"
        end match
      case _ -> "other"
    end match
  case _ -> "other"
end match
```

## 3. 役割の重複と、重ならない形の選択肢

基本案のA/Bは、同じ解析の失敗を旧InvalidPattern/InvalidTargetとAt内の同名分類で二通りに表す。動的不所属も旧OutsideScope/PortOutsideScopeとDynamicConditionに分かれる。[設計原則5](../../design/00-overview/00-01-goals.md#設計原則)に照らし、表現の重複を無条件に採用できない。重複を認める理由の候補は、既存APIの互換性を保ちながら、AtではD61の複数原子・両起点・失敗段階を利用者が確認できるようにすること（原則3/4）である。候補の妥当性は設計者がU02で判断する。AtFailure.outsideScopeも、返却先がないまま公開名だけを増やさないよう同時に判断する。

重複を減らす第一の選択肢は、共通の形式不正を旧構成子だけへ写し、Atには未束縛・動的条件・静的添字等の固有の失敗だけを残すことである。横断的な照合は簡単になる一方、旧InvalidPattern/InvalidTargetには片方の元入力とreasonしか入らず、D61の全保存内容をそのエラー値から読めなくなる。保存場所を別に公開するなどの再設計がなければD61を満たさないため、今回の担当の裁量でこの写像を採用しない。動的不所属も旧構成子へ写すなら同じ問題がある。

第二の選択肢は、Atを詳細情報の包みとし、重なる失敗の原因には既存の6構成子そのものを再利用することである。例えばBのAtFailureから独立したInvalidPattern/InvalidTargetを除き、Legacy(Scope.ScopeError)を置く。Aもfailureを固定タグだけのStringから、既存構成子のタグと引数を含む原因JSONへ変える。これなら形式不正の分類とreasonは旧構成子一つに統一し、Atは全入力・起点等を添える別の役割を持つ。動的不所属も同じ方針で旧OutsideScope/PortOutsideScopeを原因にできるが、静的添字への不所属との区別を残す。

この第二案では、発行するLegacyの中身を旧6構成子に限定し、Atの再帰的な入れ子を返さない規則が必要となる。BでScopeError型をそのまま引数に使えば、その制限は型だけでは保証されない。専用の原因型へ分けるなら公開型が増え、旧宣言との共有方法も再検討する必要がある。以下はBで旧InvalidPatternを一つの原因分類として読む例であり、この変更もU02の追加判断である。

```benitoite
match Scope.AtDetail.failure(detail) with
  case Scope.AtFailure.Legacy(cause) ->
    match cause with
      case Scope.ScopeError.InvalidPattern(pattern, reason) -> reason
      case Scope.ScopeError.InvalidTarget(target, reason) -> reason
      case _ -> "other legacy cause"
    end match
  case _ -> "At-specific failure"
end match
```

以上の選択は、A/Bの「Stringか型付きか」とは別の判断である。公開するAtの詳細を保つことと、共通の失敗分類を一度だけ定義することを両立できるかで比べる。基本案のまま重複を認めるか、共通原因を再利用するか、保存場所も含めて再設計するかをU02で確定する。

## 4. 案Bで新しく公開する型の数

ここでは、表の9欄を型付きにする基本案を、既存の言語の型へ末端まで写して数える。候補を曖昧な「など」で止めないため、次の具体的な射影を仮に置く。WordはList[String]、Portとprefix長はInteger、IPのビット列はBytes（V4で4、V6で16バイト）に写す。LeanのFinや依存するrecordを利用者へそのまま公開しない。各数値/列の有効性と正規形は公開変換が満たす条件として別に記述する。これらの射影は未確定であり、型付きの形だけで全不変条件を保証する案ではない。

| 区分 | 新しい公開型と内容の候補 | 数 | 根拠の内部定義 |
|---|---|---:|---|
| 詳細と入力・失敗 | AtDetail（9欄record）、AtInput（Text/Pattern/Request）、PathBase（5構成子）、AtFailure（7構成子） | 4 | Refinement.ScopeSyntaxのPathBase/AtFailure/AtErrorとD61の生入力保存 |
| 範囲と対象 | RangeExpr（Absolute/Based/Secrets）、TargetInput（Absolute/RelativePath/HomePath）、RangeAtom（Top/Path/Host/Endpoint）、Target（Path/Host/Endpoint） | 4 | Refinement.ScopeSyntaxのRangeExpr/TargetInput、Scope.DomainのRange/Target |
| パスと名前 | PathPattern（Exact/Tree）、NamePattern（Exact/One/Many） | 2 | Scope.Domain.PathPattern/NamePattern |
| IP | Family（V4/V6）、IPAddr（family/bits）、CIDR（family/network/prefixLen）、IPPattern（Exact/Cidr） | 4 | Scope.Domain.Family/IPAddr/CIDR/IPPattern |
| ホスト | HostTarget（Name/Ip）、HostPattern（Name/Ip） | 2 | Scope.Domain.HostTarget/HostPattern |
| endpoint | PortRange（lo/hi）、Endpoint（host/port）、EndpointPattern（host/ports） | 3 | Scope.Domain.PortRange/Endpoint/EndpointPattern |
| 計 | エラーの9欄から必要になる新しい名前付き型 | 19 | 入れ子も含め重複なし |

入れ子の一覧は[ScopeSyntax.lean](../../../formal/Benitoite/Release/Refinement/ScopeSyntax.lean)と[Scope/Domain.lean](../../../formal/Benitoite/Scope/Domain.lean)を辿って確認した。ScopeErrorへのAt構成子の追加は新しい型一つとは数えない。Word/Portの別名型、Kind、PathEnv、RangeIx、証明用のWF/Canonical等はこの射影では公開しない。既存のString/Integer/Bytes/List/Option/Pairと、[Http.ClientRequest](../../../crates/benitoite/src/prelude/stdlib/Network/Http.bnt)は新規に数えない。Requestのheadersは既存List[Pair[String, String]]であり、別のHeader型は追加しない。

したがってエラー表現だけの差は、Aが新規0型、Bが新規19型である。両案に共通して新しい不透明PathBases型を一つ公開するなら、比較の対象をそこまで広げた総数はAが1、Bが20となる。PathBases以外のAt APIに別の型を足す判断、Port等を専用の型にする判断、前節の専用原因型はこの基本案の数に含まない。U02でその変更を選べば数と完全署名を更新する。

## 5. 案AのJSONで文書化する公開規則

Aの文字列は、内部値のReprではなく利用者が解析する公開形式である。候補は「構成子を文字列タグ、引数を宣言順の配列」とするタグ付きJSONである。未解決はnull、解決済みの空原子列は[]とし、元入力Textと解析済みPatternとRequestを区別する。例えばTextの元入力が`/data/**`なら`["Text","/data/**"]`であり、単なる表示文字列へは戻さない。

| 文書化するもの | U02で固定し、D10で公開する内容 |
|---|---|
| 七引数の契約 | 順序、欄名、failureの7分類とunboundの5起点、baseの6文字列。StringのうちJSONである4欄と固定タグの3欄を区別 |
| 構成子の完全な符号表 | AtInput/RangeExpr/TargetInput/RangeAtom/Targetと、第4節の入れ子に対応するタグ・引数の個数・順序・型。公開名と内部名の対応も固定 |
| 元入力と解析結果 | Textでは元の文字列を正規化せず保存。Patternでは解析済み構造を保存。失敗でparsed値がない場合の意味と、Aに解析済み専用欄がない制約 |
| 要求の5欄 | method、url、headers、body、timeoutMillisecondsをこの順で保存。headersは順序と重複を保つ文字列対の列。bodyは0〜255の整数列。元要求の欄を省かない |
| 数値とIP | port/端点/prefix/timeout等の整数の範囲と十進表記、IP familyと4/16バイトの整数列、CIDR network/prefixを明記。IPv6をホスト整数へ押し込まない |
| Optionと列 | 未解決null、解決した空列[]、未指定secretsと空一覧、原子順序・重複を含めて保持する規則 |
| 文字列の復元 | JSONエスケープ、改行/NUL/引用符/非ASCIIの扱い、元のUTF-8内容の復元と、符号化後のバイト列の等号を契約にするかの区別。JSON文字列の見た目を元入力の保存値にしない |
| 互換性とエラー | 版をどの単位で固定するか、未知タグ/将来の欄追加の扱い、JSONの解析失敗の扱い。公開デコーダを提供するかも判断し、提供するなら型/実装を別途計上 |
| 保存と表示 | 完全保存するJSONとShowの引用/エスケープ/4096バイト制限を分離。secretsの通常要約から全原子が消えていないことを照合 |
| 原因の共有を選ぶ場合 | 第3節の既存エラー原因を入れるタグ・reason・port整数の保持方法を追加し、上の固定failureタグ契約を更新 |

これらは文書化すべき項目の一覧であり、全符号表が既に確定したという意味ではない。Bでも公開19型の完全宣言・構成子・欄・有効性・入力保存と表示の関係の説明が必要となる。Aは公開する型の数が少ない代わりに、同じ情報を読むためのJSON規則を利用者とLLMが理解する必要がある。

## 6. U02後の写しと後段への影響の見込み

次の見込みは所要時間（能動時間）である。L70の数値は再開1の仮見込みを保つが、入れ子19型と失敗分類の選択を踏まえた短い代表1件で改める。R30/R60/D10はまだ詳細化していないので時間は不明とする。未知の欄を0時間として合計しない。

| 担当と範囲 | 案A | 案B |
|---|---|---|
| Lean・U02後/L70前 | 仮1時間30分〜3時間。七Stringへの明示符号化、宣言・Term観測・RuntimeMatch・TypedFacts・網羅性の読者、保存とShowの分離 | 仮3〜6時間。9欄recordと入れ子を含む19型の宣言/観測、V_AtError・三At遷移と読者の追随、欄の型/網羅性の照合。19型を数えた後の幅の十分性は未確認 |
| R30：宣言・builtins・保持値と実行 | 不明。ScopeError.Atの7引数とタグ、元入力の完全保存、JSON符号化、VM/refinterp/heapでの構築・読み出し、局所heap/stressの確認。公開デコーダを選ぶなら追加 | 不明。ScopeError.At、AtDetailと19型の宣言・構築/射影、内部の型から公開値への変換、VM/refinterp/heapでの保持と局所heap/stress。旧6構成子のタグ/引数の互換も両案で照合 |
| R60：表示・診断/JSON・fmt | 不明。外側の診断JSONとAtのString内JSONの区別・二重エスケープ、Showの制限、secretsの要約、失敗の説明。fmtは確定した公開宣言/照合例への影響を点検 | 不明。record/dataを読む診断・JSON出力、入れ子19型の表示とShowの制限、secretsの要約。fmt/診断で欄名と失敗種別を同じ公開契約に合わせる |
| D10：文書・Skill | 不明。第5節の完全符号表・復元規則・版と互換・解析例、旧6構成子とAtの使い分け、生成Skill/英語referenceの実例を照合 | 不明。19型の完全宣言/欄/構成子/有効性、入れ子の読取り例、旧6構成子とAtの使い分け、生成Skill/英語referenceの実例を照合 |
| 案全体の合計 | 不明。既知の部分はLeanの仮1時間30分〜3時間だけ | 不明。既知の部分はLeanの仮3〜6時間だけ |

両案とも、既存の失敗原因を再利用する選択やreason欄の追加を選べば、公開宣言・観測・例・符号表が変わるため再見積もりする。独立レビュー/ビルド/設計者の回答待ちは不明であり、上の能動時間とは別である。

L50の60単位と積上げには加算していない。R30/R60/D10の作業範囲は[planの段の表](../plan.md#作業の組み方と段のレビュー)に従い、取りまとめが各段の詳細化で既存枠との重複を確認して割り当てる。文書本体がR60の内数である部分をD10にも二重に加算しない。L50.53は内部保存の実署名・全失敗の証拠・公開写しの残りを渡し、U02の回答を先取りしない。

# 0.0.9 の詳しい設計（C1）

## 1. 目的・決定・読み方

2026-10-18、設計者が回答した68問のAを具体化する。対象は docs/todo の TODO-021・022・026・032・087・088・142・164・248・257・258・259・260 の13件である。回答の正は [decisions.md](decisions.md)、段と依存は [plan.md](plan.md) にある。本書は実装前の設計であり、現在の処理系が実装済みの仕様ではない。C2は作業別の実装プラン・依頼文・検査の割り当てを作成済みであり、P2でRV1の全指摘を反映した。C1とP2では処理系・現行設計書・テスト・formal/・docs/todo/を変更しない。

処理系の基準は0.0.8公開後の `6b0568a3ddcc46b0a0e64504139ce286a27fd86a`、C1の開始HEADは `af13dc2c029e3b829091321338f0f02fd1a6a9fe`、ブランチは `mod009/design` である。その間の改造文書を処理系の変更とは数えない。設計原則は [00-01](../../design/00-overview/00-01-goals.md)、用語は [00-04](../../design/00-overview/00-04-glossary.md) に従う。外部言語の事実は本書へ追加しない。study/の外部比較は調査時の記録として残し、実装根拠は現在の仕様・コードと今回の決定に置く。

構文のコードは0.0.9で受理すべき例、型と手順のコードは設計上の定義である。Leanのコードは言明の案であり、ビルド済みの証明ではない。新しい補助の型・関数の具体名は本書で固定し、公開シグネチャや保証を変える必要が出たら判断を記録する。既存の公開型・関数は、明記した破壊的変更以外では保つ。

### 対象ごとの変更の全体

| 対象 | 構文・型・脱糖 | 実行・標準ライブラリ・道具 | 主な接続先 |
|---|---|---|---|
| 142・022共通 | `@opaque`、型の公開と構築の境界を分離。通常のdata/recordの型を保つ | Scope・Range。通常の値とResult、独自のVM値は不要 | 名前解決、公開契約、inventory、doctest |
| 142・026共通 | 解決済みの直接呼び出しと定数式の追加検査。Callのまま渡す | 実行時と共通の純粋な判定本体 | 定数評価、診断、移行案内 |
| 164・021 | 既存の二引数の型構成子と辞書渡し（dictionary passing） | Functor2・Applicative2・Monad2、Resultの実装、Skillの推奨 | 上位辞書、値化、既存tryとFailの説明 |
| 248 | 局所名の別文脈、専用の宣言と直接操作、Referenceへの脱糖（desugaring） | 三種類の構築器。全操作にStateを残す | 表層検査器、交換、既存VM・継続 |
| 088・260 | docの元の位置、例の抽出、Failだけの案内 | `test --doc`、標準例、英日11節 | test runner、生成Skill、公開境界 |
| 087・259 | 通常のimplementを生成。型の計算を増やさない | inventory版2、Show/Order、生成記録版2 | 型付き宣言、ハッシュ、Propertyの移行 |
| 032・257 | 受理・型・効果・診断順・辞書を保つ | 本体内の疎な表、制約の索引、Fail型の確定 | Rust/Leanの比較と原因別の測定 |
| 258 | 通常のdata/record/関数 | 小刻みな縮小候補、作業予算、生成テンプレート | Property・derive・再現情報 |

TODO-191のIntegerの網羅は含めない。範囲付きエフェクト、静的な篩型（refinement type）、型構成子の部分適用、局所エフェクト消去、ネイティブの可変バッファも加えない。Show/OrderとPropertyの自動生成は非循環・型パラメータなしのレコードに限る。Propertyの専用実行器を設けず、普通の `@test` を使う。これは回答済みのR10〜R12の範囲であり、13件を途中で減らす判断ではない。

## 2. 不透明型（142・022、A1・A2）

### 2.1 構文と公開するもの

不透明型（opaque type）は、構成子を宣言したモジュールの外へ公開しない型である。ここで追加する宣言は、、引数なしの `@opaque` を `public data`・`public record` または `public(package)` の同宣言へ一度だけ付けて書く。非公開宣言への指定はE0820、他の宣言への指定はE0802、重複はE0803、引数ありはE0818、`@extensible` または `@external` との併用はE0819で拒否する。`@deprecated` との併用は許す。型パラメータを持つ型にも使える。型の別名への指定は許さない。

```benitoite
// Positive.bnt
@opaque
public record Positive
  raw: Integer
end record

public function make(value: Integer) -> Option[Positive]
  return if value > 0 then Option.Some(Positive(raw: value)) else Option.None end if
end function

public function value(x: Positive) -> Integer
  return Positive.raw(x)
end function
```

型名の可視性は従来の三段階のままである。宣言モジュール外では型注釈・型引数・受け渡し・変数束縛・ワイルドカードの照合を許す。構成子の参照・値化・呼び出し・部分適用、構成子パターン、レコード構築・更新・レコードパターン、自動アクセサへの参照を拒否する。同じパッケージの別モジュールも外部である。宣言モジュール内で定義した公開の関数やimplementは、内部表現を使える。公開した値や関数が何を漏らすかはそのモジュールの契約である。

理由: 型の受け渡しと値の作成の境界を分ければ、検査を行う公開関数へ作成を集められる。属性だけでは内部の公開関数が正しいことまで保証しない。

### 2.2 名前解決・型表・生成の境界

`resolve::Binding`は既に宣言元の`module`を持つ。opaqueの印はData/Recordの型の束縛に一つだけ保持し、Ctor.data・Field.recordから親型を引く。Recordの束縛は型名と構築子を兼ねるため、種類だけで遮断せず、「使用位置（Value・Record構築・構成子/レコードパターン・Fieldを指すValue）×束縛の種類×親型と使用元のModuleId」で共通に判定する。`lookup.rs`の`checked_name`・`record_call_name`と、`shadow.rs`のパターン解決を接続し、`collect.rs`で属性を収集する。型注釈からの参照は許す。自動アクセサ・パイプ・部分適用・値化はValueの入口を通り、式にフィールドを取り出す別構文はないため、`typeck/records.rs`へ同じ遮断を重ねない。別名展開後の親型へ判定し、import別名、再公開した関数値、型別名を構築の迂回にしない。遮断した既知のメンバーにはE0340を返し、通常の存在しない名前のE0301/E0303と区別する。

`resolve/checks.rs`の公開契約の検査では、隠した構成子の引数・欄の型を型自身の外部契約から外す。公開関数・公開メソッドの署名には従来のE0329の検査を残す。内部の非公開の補助型を持つ公開の不透明型であるレコードを認めても、その補助型を返す公開関数を自動で認めない。

内部の型表と網羅性の表には全構成子・欄を残す。型は名目型のままであり、新しい `Ty.opaque` へ置換しない。外部から中身が見えなくても、等値・key等の可否は従来の内部構造の規則で決める。外部のmatchは変数か `_` で覆える。`@opaque` を理由に構成子がゼロ個の型として網羅扱いしない。formatterは属性を保存し、ヘッダ・docとの順序は既存属性に揃える。`cli/tools/skill/generate.rs`の宣言ヘッダ抽出も、現在のextensibleと同様にopaqueを表示する（R120）。

inventoryは `opaque`、宣言元、生成先での `canConstruct`・`canInspect` を明示する。同じモジュール内でも不透明型そのもののJSON復号・Property生成は自動生成しない。検査を通す手書きの全体関数を利用者が用意する。不透明型を欄に持つ通常レコードでは、当該欄のカスタム復号・生成・縮小関数を明示した場合だけ使う。Show/Orderは宣言モジュール内で明示要求した場合に限る。Showによる中身の表示もその要求の確認対象とする。

VM・バイトコード・ヒープは通常のdata/recordを使う。07-04上の公開境界の遮断は名前解決として外側である。構成子表を減らす案や新しい型を導入する案に変われば、形式化の内側へ戻して段1から再判断する。

## 3. 条件と対象を保持するScope（142、A3〜A11）

### 3.1 公開APIと失敗の値

明示importは `Benitoite.Unofficial.Scope`、利用者の修飾名は `Scope` とする。内部の解決済みの標準モジュール名は登録表の `Benitoite.Scope` とする。preludeには入れない。次の三型は引数なしの `@opaque public record` とし、構成子・欄名は内部用とする。

| 型 | 内部に保存する欄（宣言順） |
|---|---|
| CheckedHost | `pattern: String`、`host: String` |
| CheckedPath | `pattern: String`、`path: String` |
| CheckedEndpoint | `hostPattern: String`、`host: String`、`minimumPort: Integer`、`maximumPort: Integer`、`port: Integer` |

```text
public data ScopeError
  InvalidPattern(String, String)
  InvalidTarget(String, String)
  InvalidPortRange(Integer, Integer)
  InvalidPort(Integer)
  OutsideScope(String, String)
  PortOutsideScope(Integer, Integer, Integer)
end data

checkHost(pattern: String, host: String) -> Result[CheckedHost, ScopeError]
checkPath(pattern: String, path: String) -> Result[CheckedPath, ScopeError]
checkEndpoint(hostPattern: String, host: String, minimumPort: Integer,
              maximumPort: Integer, port: Integer) -> Result[CheckedEndpoint, ScopeError]
host(value: CheckedHost) -> String
hostPattern(value: CheckedHost) -> String
path(value: CheckedPath) -> String
pathPattern(value: CheckedPath) -> String
endpointHost(value: CheckedEndpoint) -> String
endpointHostPattern(value: CheckedEndpoint) -> String
endpointPort(value: CheckedEndpoint) -> Integer
endpointMinimumPort(value: CheckedEndpoint) -> Integer
endpointMaximumPort(value: CheckedEndpoint) -> Integer
```

表の関数はすべてpublicで純粋である。失敗の構成子の引数は順にパターン/対象とreason、minimumPort/maximumPort、port、パターンと対象、minimumPort/maximumPort/portであり、既存どおり位置引数を使う。ScopeErrorは公開の閉じたdataとし、標準の `Trait.Show` を手書きで実装する。reasonは英語、表示では引用と既存のエスケープを使う。入力の任意の長さを診断へそのまま貼らず、実行時Regexと同じ4096バイトの表示上限を使う。引用後の各引数を2000バイト以内へ収め、長ければ引用前の入力をUTF-8の境目で半分に縮めて `...` を付けて引用し直す。完成したエスケープ・引用符・構成子名・括弧を残し、省略時には閉じ括弧の後にも `...` を付ける（R172）。

実行時の失敗の優先順は、パターンの形式、対象の形式、端点の妥当性、port自体の妥当性、ホスト/パスの所属、ポートの所属とする。複数が誤っていても最初の一つを返す。ホスト・パスの文法、正規化、所属判定をRustの純粋な共通部 `builtins/checked_scope.rs`（新規）へ置き、VM用の値の組み立てと型検査用の診断から分離する。共通部の返り値はRustの構造化した列挙値と正規化した文字列であり、言語のヒープの値を含めない。`.bnt`には型と公開関数を置く。私有の`@builtin`関数の返り値は、成功時が正規化した条件/対象の`Pair[String, String]`、失敗時が番号/reasonの`Pair[Integer, String]`である通常のResultに固定する。失敗番号は1=InvalidPattern、2=InvalidTarget、3=InvalidPortRange、4=InvalidPort、5=OutsideScope、6=PortOutsideScopeとする。Host/Pathでは1・2・5だけを返す。Endpointの判定本体は整数も受け取り、上記の失敗順を一か所で決める。`Scope.bnt`の公開ラッパーが入力の整数と返された文字列からopaque recordを作り、失敗番号と元入力からScopeErrorを作る。Rust側は新しい構成子の固定タグを持たず、既存のResult/Pairだけを組み立てる（R122）。新しいVM命令は不要である。

### 3.2 ホストの形式と所属

Scope固有の文法として、ホストはASCIIの英数字・ハイフンの空でないラベルを `.` で区切る。ラベルの先頭と末尾のハイフン、空ラベル、末尾ドット、非ASCII、NUL、URL、ポート付き、IPv6を拒否する。四つのラベルがすべて十進数字だけなら数の範囲を問わずIPv4形式として拒否する。`localhost`は認める。DNSの長さの規格への適合は約束せず、処理系のStringの上限を使う。解析成功後、対象とパターンの英大文字を小文字へ揃えて保存する。

パターンは完全一致 `example.com`、一段だけの `*.example.com`、一段以上の `**.example.com` の三形に限る。`*`単独、途中のワイルドカード、和・否定を認めない。後二者の幹は同じホスト文法を満たす必要があり、頂点 `example.com` を含まない。

ラベル列の意味は、幹をs、対象をhとすると、完全一致は `h = s`、一段は `h = [x] ++ s`、多段は `h = xs ++ s ∧ xs ≠ []` である。実装では逆順ラベルの接頭辞比較を使ってもよい。一段と多段の長さの条件を別に検査する。

### 3.3 パス・ポート・保証の範囲

パスは `/` 区切りの絶対形式の字面として扱う。根 `/`、および `/data/report` のような空でない要素列を認める。根以外の末尾 `/`、空の中間要素、`.`・`..`、NUL、逆斜線を拒否し、それ以外の要素のUnicode文字は変換せず保つ。パターンの末尾以外に `*` を認めず、パターンは完全一致か末尾 `/**` だけとする。対象の要素に含む `*` は普通の文字として保つ。パターン側のワイルドカードの意味を対象側へ適用しない。

`/data/reports/**` は `/data/reports` 自身と任意段の子を含み、`/data/reports-old` を含まない。`/**` は根とすべての受理したパスを含む。要素列の接頭辞で照合し、文字列の単なる前方一致にしない。パターンも対象も受理した表記のまま保存する。

ポートの有効範囲は `0 ≤ minimumPort ≤ maximumPort ≤ 65535`、対象の有効範囲は `0 ≤ port ≤ 65535`、所属は `minimumPort ≤ port ≤ maximumPort` である。等しい端点を一点として認め、逆転を空集合として成功させない。加算で上端を変換しない。

新APIの成功は、値が保存した条件への字面の適合だけを表す。特定の利用者の許可、DNSの解決先、URL、HTTPのリダイレクト、実ファイルの存在、リンク先、検査後の変更、IOの成功は保証しない。既存のIOはString・Integerを受ける契約を保つ。対象を取り出してIOへ明示的に渡す例でも、別の文字列の使用を全入口で禁止したとは説明しない。

## 4. 整数の閉区間を確かめるRange（022、C1〜C7）

明示importは `Benitoite.Unofficial.Range`、修飾名は `Range`、内部登録名は `Benitoite.Range` とする。`CheckedInteger` は `@opaque public record` とし、`minimum: Integer`・`maximum: Integer`・`value: Integer` をこの順で保存する。

```text
public data RangeError
  InvalidBounds(Integer, Integer)
  OutOfRange(Integer, Integer, Integer)
end data

checkInteger(minimum: Integer, maximum: Integer, value: Integer)
  -> Result[CheckedInteger, RangeError]
minimum(value: CheckedInteger) -> Integer
maximum(value: CheckedInteger) -> Integer
value(value: CheckedInteger) -> Integer
```

全関数をpublicかつ純粋とする。`checkInteger`は通常の `.bnt` の比較とifで実装する。`minimum > maximum` ならInvalidBounds、そうでなく `value < minimum or value > maximum` ならOutOfRange、それ以外は入力の三つの値をそのまま保存してOkを返す。RangeErrorには手書きのShowを付ける。成功型からIntegerへの暗黙変換、範囲付きの加減算は設けない。再検査は取り出した値と新しい端点でcheckIntegerを呼ぶ。

閉区間 `[minimum, maximum]` はIntegerの最小値・最大値をそのまま端点にできる。`maximum + 1` を計算しない。同じCheckedInteger型の端点は値ごとに異なるため、特定区間を要求する利用側は端点を確かめるか再検査する。成否だけ要る場合は既存の `Result.ok` でOptionへ変換する。定数の範囲外も通常のResult.Errorであり、次節の静的拒否表にはRangeを登録しない。

脱糖・VMは既存のレコード・data・比較・Callを使う。長さ、非空リスト、添字、ifによる静的な範囲の絞り込み、SMT、部分型、演算の検査除去は今回の範囲に加えない。

## 5. 定数の引数の追加検査（142・026、A8・A9・A12〜A15）

### 5.1 対象を決める時点と定数の取得

型と引数の対応を確定し、定数を評価した後、脱糖より前に追加検査を行う。通常のCallのソース上の形を失う前に、解決済みのBindingId、直接呼び出しか否か、ソース順と契約順の引数位置を記録する。対象の固定表にはRegex.compileとScopeの三つのcheck関数だけを登録する。文字列の綴りによる照合や利用者の検証属性の登録は行わない。

同じ標準束縛へのimport別名は対象に含める。局所関数値、同じ綴りの利用者関数、部分適用、穴、高階、パイプ、利用者のラッパーは対象外とし実行時検査へ残す。対象外の呼び方を失敗テスト専用の規則として扱わず、呼び出し形の一般の境界として記す。

`typeck/consts.rs`の定数の形と値の評価を共用する。リテラル・トップレベルconst参照・基本演算・定数補間等の既存の閉じた式だけを得る。任意の純粋関数、局所bindの値の伝播、if/matchを追加しない。トップレベルconstでRegex.compileを呼べるようにも変えない。トップレベルで許さない呼び出しは従来のE0433を返す。

内部の取得結果を `Known { value, argumentSpan, constOrigins }`、`Unknown`、`BudgetExceeded`、`Invalid` に分ける。UnknownとBudgetExceededは不適合ではない。型・名前の誤りがある式はInvalidとして追加評価せず、元の診断だけを残す。定数評価の失敗が既に診断済みなら重ねない。既知の部分だけは下表に従って検査する。

追加検査専用の状態`CheckedArgsState`を一回の型検査の`Decls`に置き、全対象呼び出しで64 MiBの評価予算を共有する。トップレベルconstの既存の全体予算と、`warnings`が式ごとに作る既存の警告用予算は別に保つ。既存の警告の有無を追加検査の消費順で変えない。消費順は既存のモジュール・本体の検査順、その本体内のソース位置順、同じ呼び出しではソース順とする。評価済みconstを再評価せず使い、追加の値の作成・複製は共通EvalBudgetの規則で数える。`eval`の私有の追跡部で直接参照だけを収集し、constごとに保存する。直接参照の新しい要素は64バイトとして評価予算へ計上し、集合は複製せず移して保存する。推移的な由来は診断時だけ訪問済み集合と明示の積み重ねで辿る（R169）。引数自身の位置は呼び出し側から渡す。束縛の同定と引数の取得は`consts::std_call`・`standard_argument`を共通化し、`checked_args.rs`へ別の同定規則を作らない（R121）。Regexの組み立ては別の仕事なので、1パターン1 MiB・全体8 MiBのソース長と、異なるパターン256件を追加検査の上限とし、同じバイト列と設定の結果を1検査内で再利用する（R101・R171）。キャッシュ済みの結果は件数上限到達後も使う。上限を超えた追加検査はUnknownとして実行時へ残す。資源上限を「正しい」や「範囲外」と判定しない。実行時のString/Regexの既存上限は変更しない。

### 5.2 追加で拒否する条件

| 解決済みの標準束縛 | 既知の一部だけでも検査するもの | 必要な入力が揃ったとき |
|---|---|---|
| Regex.compile | sourceが既知なら共通RegexBuilderで組み立てる | 構文不良E0457、RegexBuilderが返すコンパイル資源制限E0458 |
| Scope.checkHost | patternの形式E0459、hostの形式E0460 | 両方既知なら所属不良E0462 |
| Scope.checkPath | patternの形式E0459、pathの形式E0460 | 両方既知なら所属不良E0462 |
| Scope.checkEndpoint | hostPatternとhostの形式、各端点が既知なら0〜65535の形式E0461、両方既知なら端点順もE0461、portが既知なら0〜65535の形式E0461 | ホストの二入力が既知ならホスト所属、三つの整数が既知ならポート所属をそれぞれE0462 |

不変条件は「静的に拒否した呼び出しは、未知の引数をどの値にしても、実行時には必ずResult.Errorを返す」である。未知の引数により失敗の種類が先行することはあるので、Errorの種類まで同じとは主張しない。複数の既知の不良は実行時の優先順に一つだけ報告する。たとえば動的hostでも定数の逆転した端点は拒否できるが、未知のhostが範囲内かは判定しない。両方の形式が正しいホストの組はポートが動的でも所属を調べられる。「全部定数」は各所属判定に必要な引数が揃う意味とする（R102の案）。

Regexは `builtins/funcs/regex.rs` の組み立てをヒープとruntimeに依存しない`builtins/checked_regex.rs`（新規）へ切り出し、実行時と静的検査で設定・失敗分類を共通にする。エラーの表示文字列を検索して分類せず、regexクレートが返す構造化したエラーの種類を使う。既存の既定設定を保ち、静的だけ設定を緩めない。SyntaxをE0457、CompiledTooBigをE0458とし、それ以外のエラーの種類はUnknownとして静的には拒否せず、実行時のErrorへ残す。Cargo.lockのregexは1.13.1であり、Errorは将来の種類の追加を認める`#[non_exhaustive]`である（[regexのErrorの一次資料](https://docs.rs/regex/latest/regex/enum.Error.html)、2026-10-18確認、表示版1.13.1）。typeckからbuiltinsへの新しい依存は、この純粋な判定部と`builtins/checked_scope.rs`だけに許し、VM用の値の組み立てやヒープを参照しない（R122）。Regex.Patternの埋め込み、Okへの書き換え、Resultの除去を行わず、実行時も必ず検査する。

### 5.3 位置と互換性

一次位置は不良の引数とする。constの補助位置は直接参照した宣言を優先し、連鎖の起点と合わせて最大8件とする。途中の宣言も含めて残りを数え、noteで `N other constant declarations omitted` と示す（R169）。所属不良では対象の引数を一次位置、条件の引数を補助位置とする。逆転した端点はmaximumPortを一次位置、minimumPortを補助位置とする。復号後のRegexのバイト位置は、エスケープ・補間との対応を確実に戻せる場合だけ細かい位置に使い、それ以外は引数全体を示す。

0.0.8で `Regex.compile("[")` のErrorを処理していたプログラムは0.0.9でE0457になる。matchで処理する場合、doctest、通常テストにも例外は設けない。失敗の値を検査する例は `function parse(source: String) ... Regex.compile(source)` のような動的入力の関数へ移す。Scopeの新APIにも同じ静的拒否を最初から適用する。Rangeはこの表に含めない。

## 6. 二引数の型クラスと推す書き方（164・021、M1〜M10）

### 6.1 宣言とResultの実装

`Benitoite.Trait`へ次の三クラスを加える。明示importだけで使い、既存Monadを改名しない。Fは二引数の型構成子（type constructor）、Xは変えない型、Eはコールバックのエフェクト変数である。

```benitoite
public trait Functor2[F[_, _]]
  function map[A, B, X, effect E](x: F[A, X], f: function(value: A) -> B uses E) -> F[B, X] uses E
end trait

public trait Applicative2[F[_, _]: Functor2]
  function pure[A, X](x: A) -> F[A, X]
  function apply[A, B, X, effect E](fs: F[(function(value: A) -> B uses E), X], x: F[A, X]) -> F[B, X] uses E
end trait

public trait Monad2[F[_, _]: Applicative2]
  function flatMap[A, B, X, effect E](x: F[A, X], f: function(value: A) -> F[B, X] uses E) -> F[B, X] uses E
end trait
```

applyの関数型の括弧は、`uses E, X` をエフェクトの並びとして読む既存の文法との区切りである。新しい構文で解決しない。Resultの三implementを同じTrait.bntへ置く。mapはResult.map、flatMapはResult.andThenへ委ね、pureはResult.Okを返す。applyは次の分岐とする。

```benitoite
implement Applicative2[Result]
  function pure[A, X](x: A) -> Result[A, X]
    return Result.Ok(x)
  end function
  function apply[A, B, X, effect E](fs: Result[(function(value: A) -> B uses E), X], x: Result[A, X]) -> Result[B, X] uses E
    return match fs with
      case Result.Error(error) -> Result.Error(error)
      case Result.Ok(f) -> Result.map(r: x, f: f)
    end match
  end function
end implement
```

mapとflatMapの実装の引数名は宣言と同じ `x, f` とする。Resultの既存関数への呼び出しのラベルは、その関数の宣言に合わせる。applyで両方Errorならfs側を返し、fsがOkでxがErrorならx側を返す。両方Okならfを一度だけ呼ぶ。引数式自体は通常の呼び出しと同じソース順で先に評価する。Errorによって後の引数式が省かれるとは約束しない。

### 6.2 種類・辞書・失敗との区別

種類（kind）は既存の `F[_, _]` の検査を使う。Fの一方の引数を固定する型の計算を追加しない。完全適用した透明な別名は展開後の型として扱い、裸の別名を型構成子として渡すことや、別名ごとの辞書を許さない。同じクラス・型構成子への実装の一意性、クラスか型の宣言モジュールで実装する規則を保つ。成功型が先の利用者の二引数dataにも実装できる。

上位辞書の順序、辞書を値引数より先に渡す脱糖、メソッドを値にしたラムダの捕捉を既存の `ir/desugar/dicts.rs` に通す。新しいVM命令・実行時のクラス検索・単相化は導入しない。操作の高カインド引数も追加しない。pureのXを推論できない使用では結果の型注釈を案内する。異なるXはResult.mapError等で明示的に揃える。

一引数Monad向けの関数やTraversable.traverseへResultを直接渡せるようにはならない。二引数側のFoldable・Traversable・Bifunctorも増やさない。既存のtry・bind・Failure.toResultの意味は保つ。

二引数の型構成子は種類の検査で受理できるが、現行の正例には受理から辞書・VM・交換まで通した前例がない。M1の最初に最小の正例を全経路へ通し、不具合が既存の規則の変更を要するなら依存部分を止めて段1への戻しを設計者に相談する（R119）。

### 6.3 Skillの推奨（021）

手書きの `crates/benitoite/skill/SKILL.md` と `references/idioms.md` に次の判断を加える。全APIは生成する標準参照へ残す。

| 用途 | 推す書き方 |
|---|---|
| List・Option・Resultが決まっている処理 | List.map/fold、Option.map/andThen、Result.map/andThen/mapError |
| 複数の容器で同じ関数を使う | 必要最小限のFunctor/Applicative/Monadまたは二引数版の制約 |
| 成功値を続けて処理する | andThen/flatMap。戻り値のエラー型を揃える |
| 失敗を呼び出し元へ返す・実行を終える | `try … or return`・`or die` |
| 型付きFailを値へ戻す | Failure.toResultで受け止め、入口のusesから未処理Failを除く |
| 表示・比較・結合 | 意味を確かめて具体関数かShow・Order等を選ぶ。Showと数のtoString、Order[Float]と組み込み比較を機械的に交換しない |

既存関数を非推奨にしない。辞書の費用は同条件で未分離であり、推奨の根拠を速度としない。必要な比較は同じ計算・入力・コールバック・構成で別に記録するが、今回の性能合格条件にはしない。

## 7. 関数内の構築器（248、B1〜B12）

### 7.1 専用の局所宣言と操作

`Benitoite.StringBuilder`・`Benitoite.ListBuilder`・`Benitoite.BytesBuilder`を明示importする。第二級の値である構築器を提供し、通常のTy・Referenceの公開別名・preludeの型にしない。STDLIBの末尾へdocだけの`StringBuilder.bnt`・`ListBuilder.bnt`・`BytesBuilder.bnt`を`prelude: false, unofficial: false`で加え、既存のモジュール探索でimportする。宣言を偽の通常型や関数として.bntに置かず、resolveの私有の専用登録表に、ロード済みの標準ModuleIdと分類名・操作名・ラベルを結び付ける。import別名もModuleIdで照合する。修飾操作名は通常のメンバー検索の前でこの表へ解決し、分類名はbindの専用注釈の位置だけで受理する。その他の位置ではE0464、操作の間接使用はE0466とする。gen_skillはSTDLIBのdocと同じ専用表から標準参照・索引・bundleへ契約を出す（R123）。次の注釈と専用newの組だけを受理する。

```benitoite
bind text: StringBuilder <- StringBuilder.new()
bind items: ListBuilder[Integer] <- ListBuilder.new()
bind bytes: BytesBuilder <- BytesBuilder.new()
```

ブロックの最後が構築器のbindでも受理し、結果はUnit、効果はStateとする。型付き表層は`builderBind kind refs .empty`とし、通常の`lastBind`に混ぜない。

注釈なし、newの値化、newの戻り値を他の関数から得る宣言、型別名による注釈はE0463で拒否する。ListBuilderのTを明記し、Tには通常の型だけを許す。構築器の種類の名前を通常の型注釈・型引数・dataの欄・Failの引数に書けばE0464とする。import別名は解決済みの同じ標準束縛なら認める。既存のbind/shadowの名前の重複・範囲の規則は保つが、既存局所名のshadowによる構築器の別名化は認めない。

| 専用操作 | StringBuilder | ListBuilder[T] | BytesBuilder |
|---|---|---|---|
| `new()` | 空String | 空List[T] | 空Bytes |
| `append(builder: b, …) -> Unit` | `text: String` | `value: T` | `value: Byte` |
| `appendAll(builder: b, …) -> Unit` | `texts: List[String]`、区切りなし | `values: List[T]` | `bytes: Bytes` |
| `copy(b)` | String | List[T] | Bytes |
| 長さ | `byteLength(b) -> Integer` | `length(b) -> Integer` | `length(b) -> Integer` |

全操作にStateを含める。上の表は専用の検査規則の契約であり、構築器を引数に取る普通の関数型の宣言ではない。標準モジュール表に専用の種類・操作・引数ラベルを登録し、標準docとSkill生成部もその契約を表示できるようにする。利用者が同じ綴りの型・関数を作っても特別扱いしない。clear・reserve・finish・構築器どうしの結合はない。

### 7.2 通常値への混入と捕捉の検査

名前解決では通常のBindingIdから参照できる局所構築器の印と宣言元の境界を保持する。型付き表層では通常値の環境Γと第二級の値の種類の表Δを区別するが、番号の空間は共有する。Γの構築器の位置をnoneとし、Δの同じ位置へ種類を置く。RustのBuilderIdは解決済みの局所束縛の識別に使い、交換時にはこの共通の局所番号へ写す。通常の変数式を作る前に局所名を専用操作の対象として判定する。推論前の署名だけの検査や、型検査後に返り値だけを見る検査にはしない。

| 場所 | 規則・診断 |
|---|---|
| 専用操作の直接のbuilder引数 | 同じ境界のΔに存在し、種類が操作と一致すれば許す |
| return、通常のbind、利用者関数の引数、data/record/List/Map/Referenceへの格納、比較・補間 | E0464。通常値へ変換する規則を持たない |
| 外側の構築器のlambda・lazy・部分適用・task・handle節からの参照 | E0465。宣言と捕捉境界を補助位置にする。普通の関数や構成子の部分適用の中の専用操作も含む |
| 専用new/append等の値化・部分適用・穴・パイプ | E0466。通常の直接呼び出しへ書き直す案内 |
| lambda・lazy・節（handleFailの節を含む） | 空のΔで検査する。内側で宣言した構築器だけを使える |
| 部分適用（partial application） | partialCallの呼び出し先と固定引数、partialConの固定引数を空Δで検査する。これらは作った関数を呼ぶたびに評価される |
| tryResultDie・tryOptionDieの説明、matchのガード | hideConts Γに同じΔを渡す。説明はその場で評価し持ち出さない。説明もガードも純粋を要求するのでStateを持つ専用操作は書けない |
| それ以外の部分式 | withの本体、if/matchの分岐、handle本体、通常の呼び出しの引数、tryの対象、returnを含め同じΔを引き継ぐ。通常束縛を増やす場所ではその個数のnoneをΔの先頭へ置く。枝内の宣言は枝外へ出ない |
| lambda等の内側で自分でnewし、copyした値を返す | 新しい空Δから始めるため許す |
| copyで得たString/List/Bytesの捕捉 | 通常値として許す |

タスクがライブラリ関数のコールバックで表される場合も、その関数値を作るlambdaまたは部分適用の境界で同じ規則を適用する。handleの節はresume/drop用の通常の規則と独立に外側のΔを消す。節の内側のnewは許す。ソースの同じ綴りではなく解決済みの束縛を比較する。E0466は専用操作自体の値化や穴に、E0465は普通の部分適用の中からの外側参照に使い分ける（R131・R139）。

現行にはループ文がない。外側の構築器をList.forEachのlambdaへ捕捉する形も拒否する。動的な断片列はList.map等で先に作りappendAllへ渡す。逐次ストリームの高速構築まで提供したとは説明しない。

### 7.3 型付き表層とReferenceへの展開

Rustには `BuilderKind::{String, List(Ty), Bytes}`、`BuilderDecl { id, kind, span }`、`BuilderOp::{Append, AppendAll, Copy, Length}` とソース順の通常引数を保持する情報を追加する。通常の型表へBuilder型を加えない。構文の形は既存bind/Callを使い、型付きの結果と交換へ専用の宣言・操作を残す。脱糖前にReferenceだけへ消して、形式化した禁止を検査したことにはしない。

変換するセルはString・List[T]・BytesそれぞれのReferenceである。普通の変数とセルは同じ局所番号を使い、専用宣言が入った位置をセルのletに置き換える。普通の`.local i`は`.var i`のまま脱糖する。引数評価の合成letの下で参照するセルは、既存のrenameでそのletの個数だけ移す。別の番号空間の対応表を脱糖へ渡さない。

```text
new String       => let cell = Reference.new("") in continuation
new List[T]      => let cell = Reference.new([] : List[T]) in continuation
new Bytes        => let cell = Reference.new(Bytes.empty()) in continuation
copy(b)          => Reference.get(cell_b)
length(b)        => lengthFunction(Reference.get(cell_b))
append(b, arg)   => let a = arg in
                    let old = Reference.get(cell_b) in
                    let next = pureAppend(old, a) in
                    Reference.set(reference: cell_b, value: next)
```

appendAllも引数を一度だけソース順に評価してからgetする。Stringの単一追記は `+`、複数追記は `String.join(xs: texts, separator: "")` で一つの断片を作ってから `+`、Listの単一追記はList.append、複数追記はList.concatenateを使う。Bytesの単一追記は `Bytes.fromList([a])` とのBytes.concatenate、複数追記はBytes.concatenateを使う。Bytes全体をList[Byte]へ直さない。実装時には既存の宣言の正確なラベルに合わせる。

純粋な追記と既存の大きさの検査が成功した後だけsetする。途中の上限超過は既存の実行時エラーのままであり、途中までセルを更新しない。新FailやResultを足さない。getとsetの間で利用者のコールバックは呼ばない。引数を評価中に保存継続を作る場合も、評価後のgetによりその時点のセルから追記を始める。

copyは現在の不変値を返す。後の追記ではセルを別の不変値へ置き換えるため、先に取り出した構造は変化しない。内部共有を許し、物理コピーや要素の深い複製は必須にしない。List[Reference[T]]の要素のセルの変化は見える。

VM・独立IR検査・参照インタプリタには、通常のlet・Call・Referenceとして渡す。レジスタ割当、生存判定、根の保存、取消、保存継続の所属を既存規則に通す。関数末での手動解放、局所ストア、Stateを外す規則を足さない。新しいVM値を要することが判明したら段1へ戻って相談する。コピー量や速度の改善は受け入れ条件にしないが、三種類の短い構築・多数の断片・一括操作・copyの比較を最終測定に残す。

## 8. docの例とFailの案内（088・260、R1〜R6）

### 8.1 抽出の文法と位置

宣言の `///` とモジュールの `//!` の両方から、明示したフェンス付きのコード例を集める。フェンスは行頭の空白を除いた三連バッククォートとし、閉じも同じとする。印は `benitoite test`・`benitoite check`・`benitoite error`、または `benitoite` と直後の `output` を使う。errorの直後の `diagnostic` は既存どおり各非空行が診断報告に含まれることを確かめる。コメントの例では少なくとも一行を実在するEコードだけの行とし、静的な誤りによる拒否を必須にする。追加の説明の部分一致の行は許すが、全コードの一致や診断順の指定へ強めない。stdout/stderrを混ぜない。outputは標準出力のUTF-8バイト列と一致させ、最終改行も含める。既存のリポジトリ文書検査の期待の読み方に合わせ、表現が異なる箇所は共通の抽出型へ変換する。

無印・textのフェンスは実行しない。隠す行の印、対話プロンプト、実行時エラーを成功とする印、コメント内のfiles、非零のexit期待は認めない。output後の明示stderrは既存どおり照合できるが、省略時は空を要求する。認識したbenitoiteの印の誤り、閉じ忘れ、errorのdiagnostic欠落、runのoutput欠落はE0260とする。E02xxを使う理由は、これはdocの実行用入力を抽出する構文解析の段の形式不良だからである（R126）。通常の `test` ではdocの本文を実行用に解析せず、`--doc`のときにこの誤りを報告する。

DocCommentへ、結合後のtextの各範囲と元ソースのUTF-8バイト範囲の対応を保持する。`///`等の接頭辞、任意の直後の一空白、CRLFを除く前の位置を記録する。補間・Unicode・空行の列番号を結合文字列から推測しない。仮想ソースからの一次・補助位置と修正案を元のコメントへ戻す。戻せない合成範囲は例全体を示す。修正案がコメントの接頭辞を壊す自動編集は出さず、診断位置と説明に留める。

### 8.2 仮想モジュールと実行の契約

各例を独立した仮想モジュールにする。例にはimport・宣言・mainまたは@test・usesを明記し、元ファイルのimport・私有宣言をコピーしない。宣言元モジュールを通常のimportで参照するため、公開APIと@opaqueの境界を通る。モジュール探索の根・パッケージ・language/dependencyは入口の環境を引き継ぐが、元モジュール自身へ例を挿入しない。仮想名は利用者モジュールと衝突しない予約した内部ID、報告名は `path:line:doc:index` とする。

元ファイルが実行を始めるモジュールでimportできない場合、例はそのmainや私有宣言を暗黙に参照しない。自己完結した例かimport可能な公開モジュールの例として書く。この制約を、実行モジュールのimport禁止を緩める例外で解決しない。

`benitoite test --doc <entry>`は入口で発見した通常@testの後、コメントのソース位置順の例を追加する。入口の選び方・ディレクトリ走査・別パッケージ・シンボリックリンクは既存testと同じであり、import先や標準ライブラリの例を再帰的に追加しない。`--check`・effects報告・実行は同じ発見一覧を使う。

| 例 | `test --doc` | `test --doc --check` |
|---|---|---|
| test | 通常@testと同じ実行・Assertの扱い | 検査と署名の確認だけ |
| check | 型・エフェクト検査だけ | 同じ |
| error | 静的な拒否と期待の診断行の包含を確認し成功と数える | 同じ |
| run＋output | mainを実行しstdout/stderrと照合、stderr省略時は空を要求 | mainの検査だけ。期待出力を実測済みにしない |

全入口・全実行例を準備して、許可するエフェクトの上限を最初の一つの実行より前に照合する。mainのrun例も@testと同じ入口の未処理効果の制限を受ける。Failと未処理の利用者エフェクトは既存のE0506で拒否する。Assertは既存の仕組み、IOの差し替えは例の明示したhandleを使う。例ごとに新しいヒープ・タスク・リソースを使い、stdinは空、stdout/stderrを捕捉する。`--allow-effects`は静的な上限の照合であり、実行時のOS隔離ではない。

通常テスト・実行例・検査だけ・拒否例・対象外ブロックの数を区別して報告する。例がない利用者ファイルは既存どおり0例で成功してよい。実装の標準doc検査では、固定した代表例一覧が非空であることと分類ごとの期待件数を確認し、抽出漏れの0件を成功としない。

`--doc`なしの既存のtestCheckReport版1とtest/testSummaryのJSON Linesは保つ。`test --doc --check --report=json`の報告は版2とする（R109、2026-10-18 設計者が決定）。版2は版1の共通欄とTarget.testsを保ち、Targetへ `docExamples` を追加する。各例は `id`、`mode`（test/check/error/run）、元の `location`、仮想ソースの `sourceId`、`status`、`complete`、`effects`、`tests`、`expectedDiagnosticCodes` を持つ。未確定の配列・効果はnull、成功した空は空配列とする。error例の期待した拒否は例の成功であり、通常の診断の失敗へ混ぜず例内の `observedDiagnostics` に保存する。予期しない拒否はTargetと全体のcompleteをfalseにする。aggregateEffectsは通常テストと実行例の宣言上限の和だけであり、check/error例の効果を実行権限へ足さない。sources/sourceSetsとdiagnosticTargetsは例の元と仮想ソースも対応させる。

実行時のJSON Linesのdoc結果は新しい `kind: "docExample"` とし、id/mode/location/outcome/stdout/stderr/failureを持つ。例内の@testが複数ならtests配列へ通常のテスト結果を入れる。通常testSummaryのpassed/failedは通常テストとdoc例単位の和とし、通常testSummaryの前に別の `kind: "docSummary"` でmode別件数を出し、最後の行はtestSummaryとする。`--check`ではこれらの実行結果を出さない。`--version=json`のformats.testCheckReportとformats.testResultsをともに`[1,2]`とする。現行06-01と英語リファレンスの規約は、成功の解釈を変える分類の追加で版を上げると定めており、未知の行を無視してよいという規定はない。--docのJSON LinesはtestResults版2、--docなしは従来の版1としてオプションで区別する。行へschemaVersionや開始行は足さず、版1だけを読むハーネスは--docを付けない（R109、2026-10-18 設計者が決定）。既存の `--check`なしの `--report=json` の使い方の拒否も保つ。

### 8.3 共通部・標準例・生成物

`cli/tools/doc_examples/`に抽出・元位置・仮想入力と期待の型を置き、test_runnerから呼ぶ。現在の `tests/doc_examples/mod.rs` はその公開された読み取り用APIを使う。リポジトリのMarkdownに限るfiles等の機能は別の入力アダプタに残し、doc用の実行規則を拡張しない。新統合ターゲット名は `stdlib_doc_examples` とし、STDLIB元のdocを共通の抽出・実行部へ渡す。利用者testから標準例を毎回実行しない。

代表例はList/Option/Result/Stringの純粋な値、Failure.toResult、Property、Scope/Rangeの公開API、IOの明示handleを含める。生成された宣言の一覧を実行例として収集しない。公開・非公開のコメント、構成子・欄・メソッド・操作のdocも元の位置順で収集する。生成Skillが公開のdocを載せるときは、フェンスの印と期待をそのまま保つ。

### 8.4 E0506とリファレンス11節（260）

`typeck/effects/declarations.rs`で標準Failの解決済みIDに一致した場合だけ、既存のhandleのhelpに `or convert the failure with Failure.toResult inside {function}` を追加する。同じ綴りの利用者エフェクトやLogへ付けない。import `Benitoite.Unofficial.Failure` と、入口のusesから受け止めたFailを除くことを説明する。新しい診断番号は設けない。

英語・日本語リファレンス11節を、effect/handleの導入、Logの例とoutput、制約付き操作の二段落、組み込み操作・名前の修飾の順へ揃える。この段落移動は同じ作業で英日を直す。Failの対処後の成功例は18節にも反映し、Resultの連結とFailの捕捉の違いをSkillと揃える。diagnosticsの生成文書も更新する。

## 9. 宣言のinventory版2（259、R13）

### 9.1 入口・共通の情報・版

読み取り用exampleの入口は既存の `derive_inventory --root <root> --config <config>` を保つ。宣言の収集だけを行い、本体の検査や実行の成功とはしない。標準出力は成功時に一つのJSONだけ、失敗時は空、終了状態は宣言/対象/IOの失敗1・引数/設定の失敗2を保つ。公開するJSONをRust内部のSerializeやDebugに依存させない。

出力の `version` を2へ上げる。設定のversionは1を保って選択キーを追加し、生成記録のversionは別に2へ上げる。型の木の変更だけで設定のversionまで上げない。入力の同じパスを異なる内容で読んだ場合の拒否、元のbytesからのハッシュ、仮想入口の除外、spansのUTF-8バイト位置と終端を含まない範囲を保つ。

| 最上位キー | 版2の契約 |
|---|---|
| version / configSha256 | `2`、元の設定のbytesのSHA-256 |
| targets | 設定順。既存のsource/region/config/type/module/name/span/public/package/typeParams/fields/dependencies/customFunctionsにopaque/canConstruct/canInspectを追加 |
| records | 解決済みの名前をキーにしたrecord情報。fieldsは宣言順、型は下の木。非対象の再帰・多相レコードも表現できる |
| functions | 解決済みの名前・span・可視性・signature。本体は未検査 |
| types（新規） | 解決済みの名目型と組み込み型の名前、種類（data/record/builtin/external）、arity、宣言元、visibility、opaque、extensible。組み込みの正の名前と表の同一性を対応させる |
| classes（新規） | 解決済みクラス名、paramKind、宣言順のsuperclasses、メソッド名とsignature |
| implementations（新規） | 宣言順。class、対象の型の木target、typeParams、constraints、宣言元module/span、methods（メソッド名とsignature）、sourceRegion（管理領域外ならnull） |
| modules / declarations / inputs | 版1の契約を保つ。declarationsのkindは固定の英小文字タグを列挙し、専用構築器の分類を追加。モジュールのimportPathと解決済み名を区別する |

canConstruct/canInspectは対象の生成先モジュールを基準とした判定値であり、属性から勝手に推測しない。public/packageに加えて `visibility: "private" | "package" | "public"` を各宣言へ置き、ハッシュはこの正規化した値を使う。旧public/packageは版2の表示用の互換欄とし、両者が矛盾する出力は失敗とする。package名自体はメタデータであり、構築の判断結果と宣言元の型の同一性を意味の入力に含める。

### 9.2 型・種類・署名の木

全型を次の三形と二つの頭の形で表す。TypeとHeadは区別し、未知のタグと未知のキーを拒否する。頭だけの型構成子と、値の型としてのゼロ引数の適用も区別する。型別名は通常の宣言収集で展開済みとする。

```text
Kind = {tag: "value"} | {tag: "constructor", arity: 正整数}
BuiltinConstraint = null | "equality" | "key" | "ordered"
Head = {tag: "named", name: 解決済み名}
     | {tag: "parameter", index: 署名内の型パラメータ番号}
Type = {tag: "application", head: Head, arguments: Typeの列}
     | {tag: "parameter", index: 署名内の値の型パラメータ番号}
     | {tag: "function", params: [{name: 契約名, type: Type}, ...],
        returnType: Type, effects: Effects}
Effects = {names: [{tag: "builtin", name: 正の効果名} |
                   {tag: "named", name: 解決済み名}, ...],
           vars: 署名内のエフェクト番号の列, failures: Typeの列}
```

Typeの選択肢は上記三つであり、Headと合わせて五つのタグの使い分けになる。Ty::ConとTy::Appはいずれもapplication、Ty::Paramはparameter、Ty::Fnはfunctionとする。Ty::Rigidは宣言署名に存在してはならず、Debugへ逃がさず読み取り失敗とする。エラー回復中の型も出力しない。

namedの名前は組み込みも完全修飾した解決済みの宣言名を使う。たとえばStringは `Benitoite.String.String`、Listは `Benitoite.List.List`、通常のレコードは `People.Person`、標準Optionは登録された正の解決名を使う。Integer64等の別名は組み込みの表の正の宣言名へ揃える。各名前はtypesに一度だけ現れ、消費側がarityと種類を照合できるようにする。BindingId・BuiltinTypeIdの数値を同一性として出さない。Effectのbuiltin名は `State`・`Console.Write` 等の表に定めた正の綴りであり、IO.Allは展開済みとする。

signatureは版1のparams/returnType/typeParams/effectParams/noFail/constraints/effectsを保ち、型だけを上の木へ置き換える。typeParamsは宣言順で `{name, kind, builtin}`、effectParamsは宣言順の名前列、noFailは昇順のeffectParams内の番号、constraintsは宣言順の `{param, class}` とする。function型内に独立の全称束縛はなく、番号は外側の署名を参照する。契約名の一意性、番号の範囲、kindと引数数の一致を出力時と読取時の両方で確認する。

namesは文字列の固定順、varsは数値順、failuresはメタデータを除いた型の正準JSONのUTF-8バイト順で整列・重複除去する。RustのBindingId順やDebugの表示順を外部契約へ持ち込まない。クラス制約と引数の列の順序は辞書と呼び出しの契約なので整列しない。表示のresolved/original/span/typeSpanは `metadata` に分離し、生成側は表示文を解析しない。

### 9.3 実装の重複の読み取り

implement一覧は通常の型クラスの宣言収集から得る。対象型を解決してから比較し、同じクラス・型構成子に多相実装が存在すれば、単相record向けの生成とも衝突とする。クラス・対象型の解決済み同一性が鍵であり、implementに表示名を作って重複の鍵にしない。宣言名がないimplementも一覧に含める。

生成対象と同じ管理領域の、前回記録にあるimplementだけは置換の候補にできる。領域外・別領域・手書きのimplementは重複を報告して生成しない。宣言の収集自体がE0702で止まる入力はその診断を返す。生成前に生じる重複は道具の `derive.overlapping_implementation` とし、既存実装の位置を併記する。言語の診断と道具のエラーIDを混同しない。

## 10. Show・Orderの生成と記録の移行（087・259、R7〜R14）

### 10.1 設定と生成コード

設定の各targetに `"show": true`・`"order": true` を追加する。省略またはfalseなら生成しない。JSON・Property・Show・Orderを独立に選べる。Show/Orderだけのtargetではjson/propertyを必須にしない。未知のキー・重複キー・真偽以外は設定失敗2とする。選択された場合だけ仮想入口にBenitoite.Traitを読み込み、依存の標準ソースもinputsへ含める。

対象は非循環・型パラメータなしのレコードであり、生成先は宣言モジュールの管理領域に限る。欄ごとに必要なShow/Orderの解決済みの実装があるか確認する。別の生成対象のレコードへ依存する場合は依存順に生成し、要求がない依存へ暗黙にShow/Orderを足さない。欄の型が関数、Reference、data等でも手書きの対応クラス実装があれば使える。レコード依存の循環は従来どおり拒否する。

```benitoite
record Person
  name: String
  age: Integer
end record

implement Trait.Show[Person]
  function show(x: Person) -> String
    return "Person(name: " + Trait.Show.show(Person.name(x))
      + ", age: " + Trait.Show.show(Person.age(x)) + ")"
  end function
end implement

implement Trait.Order[Person]
  function compare(x: Person, y: Person) -> Trait.Ordering
    bind nameOrder <- Trait.Order.compare(x: Person.name(x), y: Person.name(y))
    return match nameOrder with
      case Trait.Ordering.Equal -> Trait.Order.compare(x: Person.age(x), y: Person.age(y))
      case other -> other
    end match
  end function
end implement
```

Personの例では `import Benitoite.Trait` も生成または既存importとして必要である。実際の生成は通常のformatterを通す。Showは型の局所名・欄名・宣言順を使い、String等の引用・エスケープを各Showへ委ねる。PersonのnameがAdaなら `Person(name: "Ada", age: 7)` となる。空レコードは `Empty()`、OrderはEqualとする。Orderは最初の非Equalを返し、全欄EqualならEqualである。OrderのEqualから組み込み等値やkeyを導かない。表示を復元形式として保証しない。

private/package/publicの型に同じ方式を使う。implementは既存の公開規則に従い、存在しないpublic修飾を生成しない。opaque recordへのShow/Orderは同モジュールの明示要求だけとする。型を表示する判断をpreviewの確認表に出す。opaqueへのJSON復号・Property生成を同じ選択に混ぜたらその生成だけを黙って落とさず、要求全体を拒否する。

### 10.2 構造ハッシュ・生成記録版2

GENERATOR_VERSIONは `2.0.0-syntax-batch3`、生成記録のversionは2、inventoryVersionは2、hashVersionは `2` とする。Property.libraryVersionは独立に更新する。これらを処理系の0.0.9で代用しない。

意味のハッシュは、出力JSON全体から不要なキーを削る方式をやめ、意味を持つキーを明示して構築する。型の木、正の名前、可視性とopaque境界、欄順、解決したクラス/対象/辞書依存、カスタム関数の署名、選択したテンプレートと版、設定の意味を含める。位置・説明文・元の綴り・表示のresolved・packageの表示名・Rustの内部名を除く。SHA-256の入力はUTF-8、キーの辞書順、空白なし、ensure_ascii=false、非有限数なしの正準JSONとする。元入力ファイルのbytesのハッシュは意味のハッシュとは別に保持する。

記録には既存の宣言・依存・カスタム署名・設定・生成本文のハッシュに、inventoryVersion/hashVersion、クラスと対象型、欄順、依存するimplementの同一性、テンプレート別の版、Property.libraryVersionを追加する。設定で選んだ依存だけをハッシュし、無関係なfunctionsの増減で全targetを無効にしない。書式・表示だけの変更と意味の変更を区別し、生成本文のbytesのハッシュによる手書き保護は保つ。

### 10.3 旧記録・旧manifestからの移行

preview/apply/checkの既存の入口と、確認済みmanifestのハッシュ一致を保つ。新版applyは旧版manifest/receiptを拒否し、自動の読み替え・forceを設けない。新版checkも旧記録を更新せず `derive.migration_required` を返す。

移行は次の順序に固定する。

1. 未完の旧applyがあれば、保存した旧版の道具とmanifest/receiptで復旧を終える。
2. 新previewが旧記録の出力ハッシュと現存する管理領域本文のbytesを照合する。不一致なら `derive.modified_region` で止め、手書きの差分を残す。旧入力が変わった事実は新previewの差分へ出すが、古い意味のハッシュを新版で再計算して承認済みにしない。
3. 版2のinventory、258の新API、Show/Orderの要求を使って一つの新preview・確認表・diffを作る。本文が同じでも記録とハッシュの版の変更を示す。
4. 設計者または生成道具の利用者がその具体的な差分を確認し、新manifestのハッシュを指定してapplyする。通常のcheck/testとderive checkを行う。

Peopleの同梱例・設定例・README・inventoryの契約書も一度の切り替えで更新する。移行後も同じmanifestの再適用の検証と失敗時の復旧を保つ。再帰・多相レコード、専用Property実行はR10〜R12のAに従い加えない。

## 11. 小刻みな縮小と作業予算（258、R20〜R22）

### 11.1 公開API

明示import `Benitoite.Unofficial.Test.Property` とGen/checkの基本の型を保ち、次の通常のdata/recordへ切り替える。すべて純粋であり、State・新しい遅延VM機構は要らない。

```benitoite
public data ShrinkStep[T]
  Done
  Yield(T, function() -> ShrinkStep[T])
  Skip(function() -> ShrinkStep[T])
end data

public record Shrinker[T]
  candidates: function(value: T) -> ShrinkStep[T]
end record

public record Config
  seed: Integer
  trials: Integer
  size: Integer
  maxShrinks: Integer
  maxShrinkWork: Integer
end record
```

Counterexampleの従来の欄は順序を保ち、shrinksの直後に `shrinkWork: Integer` を加える。libraryVersionを `"2.0.0"` にし、formatFailureへmaxShrinkWork/shrinkWorkを表示する。checkの型は従来どおり `check[T](config: Config, gen: Gen[T], shrinker: Shrinker[T], property: function(value: T) -> Result[Unit, String]) -> Result[Unit, CheckFailure[T]]` とし、Tへequalityを加えない。

trials/size/maxShrinksの既存範囲は保ち、maxShrinkWorkは0〜1000000とする。明示のConfigに既定値は存在しない。Skill・同梱例で推す値を10000とするのがR20の初期案であり、本測定後に確定する。誤設定は既存のInvalidConfigを返し、generator/shrinker/propertyを呼ばない。

### 11.2 一段の仕事・重複・予算の数え方

初回の `candidates(value)`、Yield/Skipが保持した続きを作る関数の一回の呼び出しを、それぞれ作業量1として実行直前に数える。一段は候補を一つ作る、等値を一回比較する、内部の状態を一つ進める、またはDoneを得る処理に限る。組み込みの縮小器は一つの段で候補全体のListや重複除去全体を作らない。

重複除去は、原値との比較、既出の候補との比較を一回ずつ行う状態に分ける。比較した段はSkipを返し、次の比較位置を続きを作る関数へ保存する。最後の比較で重複なしと分かればYieldを返してよい。この段は比較一回の1だけを数え、Skip/Yieldの構成をもう1とは数えない。比較なしの候補生成・Yieldも一段1である。propertyの候補に対する呼び出しは別に作業量1、shrinksを1として数える。通常のtrialsのproperty呼び出しと最初の失敗はこの縮小予算に含めない。

maxShrinksまたはmaxShrinkWorkが0なら縮小器も呼ばない。予算が尽きたら次の生成・比較・propertyの呼び出しを始めず、残りが不明ならlimitReachedをtrueにする。Doneを既に得ていれば、数が上限と等しくてもfalseで終える。上限を使い切った後、Doneかどうかを知るためだけに続きを呼ばない。打ち切り時に未試行のYieldがあっても失敗値へ採用しない。

候補のpropertyがErrorなら、reduced/messageをその候補へ更新して候補列を作り直す。shrinksとshrinkWorkは累積し、予算をリセットしない。Okなら現在の続きを進める。要素のコールバック一回や構造比較一回の内部のCPU時間・確保量は値の大きさに依存する。任意の利用者コールバックの停止性もこの予算では保証しない。

縮小の駆動・mapSteps・appendStepsは末尾呼び出しで書く。言語にループはなくmaxShrinkWorkは最大1,000,000なので、次段を戻り待ちの呼び出しに重ねない。合成の長いSkip列と上限に近い駆動でもスタックが溢れないことをG3/G4の既存property_libraryの境界で確認する（R128）。

### 11.3 候補の順序と生成コード

既存の組み込み縮小器のequalityと初出順を保つ。Set/key・OrderのEqual・Show文字列を同一性の代わりにしない。Listは空候補、既存の半分ずつの削除幅と左からの位置順、要素位置と要素の縮小順で候補を作る。OptionはNoneの後でSomeの要素候補、StringはUnicodeスカラー値列の同じ順、Mapは鍵順を保つ。元値と重複を除く比較の途中状態をSkipとして露出する。Property.checkの利用者定義の縮小器へ暗黙の等値比較を足さない。

公開の合成補助として次を追加する。mapSteps/appendStepsは入力を先に全走査せず、元のSkipを保ち、一回の続きを呼ぶために一段を返す。通常の関数内で再帰してDoneまで走り切る実装にはしない。

```text
mapSteps[A, B](steps: ShrinkStep[A], f: function(value: A) -> B) -> ShrinkStep[B]
appendSteps[T](left: ShrinkStep[T], right: function() -> ShrinkStep[T]) -> ShrinkStep[T]
```

tools/deriveのrecord縮小器は、欄の宣言順に一欄ずつ変える現在の順を保ち、各欄のstepsをmapStepsでrecordへ戻してappendStepsでつなぐ。各欄のcandidatesの呼び出しも遅らせる。利用する縮小器の関数の評価を一段の外で全部先に行わない。equalityを要求しない手書きのrecord縮小器にもcheckは使える。

古いListを返す手書き縮小器は新しいShrinkStepへ書き直す。全Listを先に作るだけのアダプタを移行の既定にしない。Propertyの生成テンプレート・Config・Counterexample・記録を同時に移す。同じseedだけでは旧版の反例を再現しない。再現にはlibraryVersion、GENERATOR_VERSION、設定、手書き関数のソース、具体的な反例を保存する。専用CLIやseed上書きは加えない。

## 12. 型検査の費用を減らす変更（032・257、R15〜R19）

### 12.1 本体内の疎な表（032）

`typeck/context.rs`のBodyが持つ式の型・効果・補助情報のNodeMapと、局所のBindingMapを、本体に実在する番号だけを持つBTreeMapベースの私有の表へ替える。base::NodeMap自体は変えず、Body専用の私有型`BodyNodeMap`/`BodyBindingMap`を置く。現行NodeMapにはget_mutがないため、必要なAPIはまず`get/insert/iter`とし、既存の呼び出しが必要とするときだけ私有型へget_mutを足す。iterはNodeId/BindingIdの昇順を保つ。挿入・更新の意味、欠けた番号の扱いは旧表と同じにする。全体の構文の番号、TypeckOutputの密な表、他の段のNodeMapは変更しない。

check_type_limitsとfinishは実在する要素だけを辿り、全体の出力表へ同じ番号で書き戻す。全体の番号の再付番、容量だけ再利用して全域をclearする案、世代管理を相乗りさせない。関数・lambda・節の所有と局所束縛を照合する。`traits/solve.rs::ClauseBounds`も私有表の参照へそろえる。`decls.rs::Scope`のparams/effectsも全体BindingIdを鍵に本体ごとに作る密な表なので、T1で私有の疎な表へ替え、宣言側とBody側の両方の読者を移す（R127）。大きな一つの本体の検索費用が増える場合は本体内の番号を詰める代案と比較するが、R17の目標を外す判断は設計者へ返す。

今回の完了範囲は小さな関数の数に対する二乗の初期化・走査・解放の削減である。多列match、長いletのコード生成、テスト用のIR検査のEnv複製までTODO-032全体を閉じたとはしない。

### 12.2 Fail型の確定（257）

`typeck/solve.rs::finalize_failure_type`は入口で一度zonkし、正規化済みの木を辿る `finalize_failure_type_normalized` へ渡す。子で再び全部分木をzonkしない。関数型の引数・返り値・契約名・潜在効果のFail内部も同じ方針で辿る。未知型、エラー回復の型、既定の型構成子、剛な型の拒否は現行の確定と同じにする。

記憶は一回の確定または宣言集合を固定した一検査内に限る。単一化中の変数を永続キャッシュの鍵にしない。型変数・行の変更で結果が古くなる場合は再計算する。型の深さ・大きさ・推論の予算を小さくして速度を得ない。

### 12.3 制約の索引と再処理（257）

effect制約のVecを初回登録順の正本として残し、重複照合の索引と待ち行列（worklist）を追加する。equal_function_effectsのcontainsを索引へ替えるが、キーは現行のEffectConstraintの等号と同じ欄を含める。reason・使用位置を捨てて型の対だけにまとめない。ITy/IEffect/Reasonは現在Clone・PartialEq・Debugだけを持つため、索引用の私有の構造キーEffectConstraintKeyを作る。生の推論変数IDと全構造を写し、関数の契約名・Fail列の順・位置・reason・優先度・関連位置・整数字面・型の対まで現行PartialEqと同じ意味で含める。キー側だけEq/Hashを実装し、ITy等の公開の導出を広げず、Debug文字列や可変の正規化結果を鍵にしない。ハッシュが衝突した場合も完全なキーの等号で区別する（R127）。

初期の処理順は登録順、同じ制約は一巡で一回だけとする。次の巡へ回す番号も登録順へ整列し、行・Fail型の結び付きが変わった制約を再処理する。依存の追跡を確実にできない変更は、全登録番号を再投入する保守的な方式を残す。毎回Vec全体をcloneせず、制約の番号から必要な一項だけを借用または複製する。新規の制約は次の巡に登録順で処理する。従来より前に診断を確定しない。

型クラスの上位クラスのpathは、宣言集合を固定した一回の検査で `(fromClass, toClass)` を鍵に記憶できる。候補の辞書・制約の走査順は宣言順のままにする。辞書番号、値化の捕捉、reasonの位置、単一Fail/NoFail、剛な型の脱出、拒否の診断順を前後で比較する。順序が異なることによる反例は期待値を変更して済ませず、必要なら索引だけを残して全巡を保つ代案を選ぶ。

型付き表層・脱糖・VM・標準APIの意味は変えない。新しい診断コードも設けない。032だけ、032+257、全機能後を分けて測り、型の規則を変える必要が判明したら段1へ戻る。

## 13. 診断の割り当て

C1開始版の `crates/benitoite/src/diag/codes.rs` の有効な表とRETIREDを読み、次の番号がどちらにもないことを確認した。E03の最終はE0339、E04はE0456まで、E08はE0817までであり、E0260も未使用である。E0444・E0445は廃止したままにする。C2で処理系の開始版を固定するときに再照合し、他の作業が先に使っていれば番号だけを再割り当てする。本書では以下を割り当て、コードへ登録済みとは扱わない。

| コード | 条件・一次位置 | 英語の本文の案・主なhelp |
|---|---|---|
| E0260 | docの認識済みの実行形式が不正。フェンスか期待の位置 | `invalid documentation example: {reason}`。対応する印と必須の期待を示す |
| E0340 | 外部から不透明型の構築・更新・パターン・アクセサ等。使用位置 | `the representation of opaque type {type} is private to {module}`。公開の検査/読み取り関数を使う |
| E0457 | 定数Regexの構文不良。source引数 | `invalid constant regular expression: {reason}` |
| E0458 | 同じRegex判定本体が返すコンパイル資源制限。source引数 | `constant regular expression exceeds the compilation limit: {reason}`。定数取得の予算超過には使わない |
| E0459 | Scope定数パターンの形式不良。パターン引数 | `invalid constant scope pattern: {reason}` |
| E0460 | Scope定数対象の形式不良。対象引数 | `invalid constant scope target: {reason}` |
| E0461 | Scope定数ポート/端点の形式不良。該当整数引数 | `invalid constant scope port bounds or port`。0〜65535と端点順を示す |
| E0462 | Scopeの既知の対象が条件に不適合。対象引数 | `constant target is outside the supplied scope`。条件は補助位置 |
| E0463 | 専用の局所宣言とnewの組でない。宣言/newの位置 | `a builder requires an annotated local bind and a direct new call` |
| E0464 | 構築器の型/名を通常値として使用。使用位置 | `a local builder cannot be used as an ordinary type or value`。copyで取り出す |
| E0465 | 外側の局所名をlambda・lazy・部分適用・節から捕捉。使用位置 | `a local builder cannot be captured across {boundary}`。宣言/境界を補助位置とし、copyを境界の前で通常値へ束縛する案を示す |
| E0466 | 専用操作の値化・穴・パイプ等。操作/呼び出しの位置 | `builder operations require a direct call` |
| E0818 | @opaqueに引数。属性位置 | `@opaque takes no arguments` |
| E0819 | @opaqueとextensible/externalの併用。後の属性位置 | `@opaque cannot be combined with @{other}` |
| E0820 | private宣言への@opaque。属性位置 | `@opaque requires a public or package-public data or record declaration` |

既存の名前の誤り、型の不一致、引数ラベル、クラスの種類/重複、State不足、未処理Failには既存コードを使う。新しい専用コードで既存の契約の診断を覆わない。docの実行失敗・output不一致はテストの失敗報告であり、静的なE番号を作らない。derive/inventoryの失敗も道具のIDと終了状態で示し、E番号を偽って出さない。

## 14. 段1で先行する形式化

### 14.1 内外・既存定理・仮定の固定

判定の正は [07-04「01-12との対応」](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) である。版に含むLeanの定義・証明・交換のLean側・01-12の写し・対応表を段1でまとめて完了し、既定のビルドを `sorry` なしで通して独立レビューを閉じる。Rustの処理系・標準ライブラリ・性能最適化はその後に進める。以下の名前は追加する名前の案であり、段1で実在する型に合わせて引数を確定する。

| 対象 | 内外の判定 | 段1で作るもの・対象外の境界 |
|---|---|---|
| opaque公開境界 | 名前解決は外側 | 解決済みの宣言元による遮断の小モデル、型表に全構成子を残す条件。ソースの全名前解決の検証はしない |
| Scope/Range | 本体の通常型の外に置くAPI固有の意味 | 下の成功・失敗・入力保存・証拠の消去。文字列parserとRustの実装の全体証明はしない |
| Scope/Regex定数検査 | 定数評価・標準束縛の同定として外側 | Call/型/効果/脱糖を保つ追加拒否の境界。Regexエンジンの健全性は仮定へ足さない |
| Monad2 | 既存の型クラス規則の範囲 | 通常宣言と上位辞書の具体例、純粋なResultの法則。種類検査と任意の実装の法則は対象外 |
| 構築器 | 型付き表層・規則・検査器・脱糖は内側 | Δ、捕捉境界、検査の健全性、Referenceへの型/Stateの保存、交換のLean側 |
| 032/257 | 規則を保つRustの実装変更 | Lean規則は変えず、比較用の独立入力と六入口の契約を段1で準備 |
| doctest/derive/inventory/Property | CLI・抽出・外部生成・普通のライブラリとして外側 | 通常の表層を使う境界を対応表へ追記。Property全体の停止・最小性の定理は加えない |

01-12と07-04の対応表にも、Checked.*とLibrary.ResultLawsは主定理の外にある独立した小証明であり、Rust・.bntとの対応は独立した期待値との照合であると明記する。Monad2Examplesだけが本体の判断へ接続する（R143）。

ReleaseのTy/Eff/Stepと組み込みの仮定の欄を保つ。既存の進行・保存・effect_soundness、Surface.desugar_typed、surface_effect_soundness、検査器の健全性とプログラム全体、網羅性の健全性の前提・結論を変更しない。新構文にも同じ保証を適用する。新構文をWellTypedから除外する、純粋なmainへ新しい「構築器なし」の条件を足す等で見た目の言明だけを保つことも認めない。

小モデルで使う解析済みの要素列、数学上のInt、通常のResultの意味は定義で与える。文字列解析や外部IOが正しいという仮定を本体のBuiltins.Assumptionsへ追加しない。セル操作は既存のストア操作の型の仮定を使い、更新や結合の参照先の型は表層の型付けの条件として宣言表から検査する。これは新しい外部仮定ではない。

### 14.2 公開境界とScopeの意味（A15）

新規モジュール案を `Benitoite.Checked.Access`・`Benitoite.Checked.Scope` とする。Accessは `Module := String`、解決済みの `Owner` と操作の種類を定義し、`mayInspect owner caller := decide (owner = caller)` とする。この二補題は所有元と別名の意味を文書として明示するためのもので、定義からほぼ直接従う。L1の主な時間は所属・保存・失敗の証明へ配分する。`mayInspect_iff`、`importAlias_preservesOwner`は、同じ解決済み型を参照する別名では境界が変わらないことを小モデルで示す。型を普通の値として渡せることと、内部構成子を使えることを別にする。Rustの名前解決全体の証明とはしない。

Scopeは文字列parserの後のラベル/要素列を入力にする。

```lean
-- namespace Benitoite.Checked.Scope の案
abbrev Word := List String
inductive HostPattern where
  | exact (stem : Word)
  | one (stem : Word)
  | many (stem : Word)
inductive PathPattern where
  | exact (stem : Word)
  | tree (stem : Word)

def HostMatches : HostPattern → Word → Prop
  | .exact s, h => h = s
  | .one s, h => ∃ x, h = x :: s
  | .many s, h => ∃ xs, xs ≠ [] ∧ h = xs ++ s
def PathMatches : PathPattern → Word → Prop
  | .exact s, p => p = s
  | .tree s, p => ∃ rest, p = s ++ rest
def PortBounds (lo hi : Int) : Prop := 0 ≤ lo ∧ lo ≤ hi ∧ hi ≤ 65535
def PortMatches (lo hi port : Int) : Prop := lo ≤ port ∧ port ≤ hi
```

モデルでは空の幹や空のラベルも表せるため、`ValidHostWord`（非空の列、各ラベルが3.2のASCII文法、正規化済み、IPv4形式でない）と`ValidHostPattern`、`ValidPathWord`/`ValidPathPattern`（3.3の要素文法、空列は根だけ）を定義する。makeHost/Endpointの解析済み入力とRust parserの対応はこれらを前提にし、Pathの根の空列を誤って除かない。HostMatches等の純粋な照合の同値は任意の列で示せるが、構文として妥当な具体例や成功値の仕様との対応では妥当性を明示する（R125）。

Host/PathのChecked構造はパターンと対象をともに持ち、その所属の証拠を持つ。Endpointはさらにlo/hi/portとPortBounds/PortMatchesの証拠を持つ。`makeHost`・`makePath`・`makeEndpoint`はExceptで成功値または構造化した失敗を返す。rawMakeは証拠を含まない通常のレコード/失敗を返し、APIの格納する欄に対応させる。

| 定理名の案 | 言明の形・仮定 |
|---|---|
| `hostMatch_spec` / `pathMatch_spec` | Boolの照合がtrue ↔ 対応するMatches。任意の解析済みパターン・要素列について |
| `makeHost_ok` / `makePath_ok` | make p input = .ok v → v.pattern = p ∧ v.target = input ∧ Matches p input |
| `makeEndpoint_ok` | 成功 → ホスト/条件/端点/portの保存 ∧ HostMatches ∧ PortBounds ∧ PortMatches |
| `makeHost_error_iff` / `makePath_error_iff` | 解析済みで所属しない場合に限りOutsideScope。文字列の形式不良の分類はparser側で別に照合 |
| `makeEndpoint_invalidBounds_iff` | 端点の妥当性の判定段へ到達した入力について、InvalidPortRange ↔ ¬PortBounds |
| `makeEndpoint_invalidPort_iff` | 形式と端点の判定を通った入力について、InvalidPort ↔ ¬ (0 ≤ port ∧ port ≤ 65535) |
| `makeEndpoint_outside_iff` | 形式・端点・portの妥当性の判定をすべて通った入力について、ホスト・ポートの所属失敗を実行時の優先順で分類 |
| `erase_makeHost` / `erase_makePath` / `erase_makeEndpoint` | `(make ...).map erase = rawMake ...`。成功/失敗と全保存欄の一致 |
| `projection_preserves` | host/path/port/条件の取り出しが保存した欄を返す |
| `one_excludes_apex` / `one_excludes_deep` / `many_excludes_apex` / `path_tree_includes_self` | 一段・多段・パスの境界の具体的な非空性と区別 |

試作のScope.leanのtree(stem,1)を一段の定義に流用しない。ポートのNat上の比較を負数も拒否するIntへ直す。範囲の包含、行の代入、範囲付きエフェクトの52定理全体を取り込まず、検査済み値の作成に必要な部分だけを再構成する。`unindexed_policy_counterexample`相当の例を残し、別の範囲への適合が型名だけでは導けないことを確認する。

実装との対応表は、parserの正規化結果、パターンの形、対象の保存、失敗の優先順、各取り出しを列にする。大小文字、空ラベル、IPv4形式、パス要素の境界、端点0/65535を独立した期待値でRust/CLIへ結ぶ。小モデルの証明から実際の文字列の解析や全IOの対象安全を導かない。

### 14.3 Rangeの小さな証明（C6）

新規 `Benitoite.Checked.Range` で次の定義を置く。Leanの証拠をBenitoiteの実行値へ持たせる提案ではない。

```lean
def InRange (lo hi value : Int) : Prop := lo ≤ value ∧ value ≤ hi
inductive RangeError where
  | invalidBounds (lo hi : Int)
  | outOfRange (lo hi value : Int)
structure CheckedInteger where
  minimum : Int
  maximum : Int
  value : Int
  bounded : InRange minimum maximum value
-- make : (lo hi value : Int) → Except RangeError CheckedInteger
-- 逆転を先に検査し、その後にInRangeを検査する。
```

`make_ok`は `make lo hi v = .ok r` から三入力の保存とInRangeを導く。`make_invalidBounds_iff`は `make lo hi v = .error (.invalidBounds lo hi) ↔ hi < lo`、`make_outOfRange_iff`は `make lo hi v = .error (.outOfRange lo hi v) ↔ lo ≤ hi ∧ ¬InRange lo hi v` とする。`erase_make`は証拠を消した三欄のレコードを返すrawMakeとの一致、`project_value/minimum/maximum`は射影の一致を示す。

`singleton_ok`・`maxInteger_endpoint_ok`・`minInteger_endpoint_ok`を具体例として加える。実装と結ぶ際は全入力が符号付き64ビットIntegerで表現可能である条件を明示し、比較はIntの比較と一致することを期待値で照合する。加算を含まないため、上端+1のあふれの仮定を要しない。

試作Contracts.leanのInRangeの `< hi` を `≤ hi` へ変え、OptionをExceptへ替えて逆転と範囲外を分ける。make_none_iffを単純な失敗の同値として移さず、上記二定理へ分ける。試作の加算・添字・記号式・証明書の定理は初版APIの保証へ含めない。Intervals/Arithmetic/Symbolic/Certificatesの半開区間・中間のあふれの反例は、検査の除去を採らない理由として読む。

### 14.4 Resultの法則と二引数辞書（M10）

新規 `Benitoite.Library.ResultLaws` に成功型が先の `Result A X` とmap/pure/apply/flatMapを定義する。純粋な関数だけを量化し、次を示す。

```lean
-- a : A, x : Result A X, f : A → Result B X, g : B → Result C X
theorem flatMap_left_identity : flatMap (.ok a) f = f a
theorem flatMap_right_identity : flatMap x Result.ok = x
theorem flatMap_associativity :
  flatMap (flatMap x f) g = flatMap x (fun a => flatMap (f a) g)
theorem map_identity : map x id = x
theorem map_composition : map (map x f) g = map x (g ∘ f)
theorem map_flatMap : map x f = flatMap x (fun a => .ok (f a))
-- applyはfsのErrorを優先し、両方Okなら一回適用する定義との一致。
theorem apply_flatMap : apply fs x = flatMap fs (fun f => map x f)
```

Functor2/Applicative2/Monad2の三辞書と上位射影を小モデルで作り、上位射影で選んだmap/pure/applyと直接の定義の一致を示す。任意の二引数の辞書の型だけでは法則が得られない反例も残す。

別に `Surface.Monad2Examples` を本体のProgram/Declarations/Checkへ接続する。最初に`.ctor (.data "Result")`のTy.WFと、型クラスの対象にこの型構成子を渡すSatAllを実際の宣言表で閉じる。種類の受理だけでは辞書・実行の接続の前例にならないため、この最小の入口をL2の最初の区切りとする。実際の三クラスの署名、Resultのimplement、`F[_, _]: Monad2`の関数、Functor2への上位辞書射影、値化したmap/flatMapの捕捉、利用者の二引数型の実装を入力にし、検査成功と脱糖後の型・辞書の位置を確認する。具体的なOk/Errorの実行も両側を含める。

試作Dictionaries.leanのBinaryMonadDictはこの小証明の出発点に限る。同試作のOpPacketは高カインド引数を操作へ許す広いモデルなので取り込まない。本体で種類を検査しない広いLeanの型付けを、Rustのkind検査の証明と呼ばない。既存の型クラス・辞書規則を変えず、主定理やBuiltins.Assumptionsを増やさない。

### 14.5 構築器の局所規則・検査器・脱糖（B10）

既存の脱糖は環境を引数に取らず、`.local i`を`.ret (.var i)`へ写す。型保存も同じΓを使う（`Surface/Desugar.lean`のdesugarExpr、`Surface/Lemmas/Typing.lean`のHasTypeQ.desugar）。この接続を保つため、構築器と普通の変数は一つのde Bruijnの番号空間を共有する。型の分類は別の表Δで管理し、ReleaseのTy/Eff/Stepへ構築器を加えない（R116）。

```lean
inductive BuilderKind where
  | string | list (element : Ty) | bytes
abbrev BuilderCtx := List (Option BuilderKind)
def BuilderKind.contents : BuilderKind → Ty
-- string ↦ String、list T ↦ List[T]、bytes ↦ Bytes
def BuilderKind.cell : BuilderKind → Ty
-- Reference[contents]
def BuilderCtx.kindAt (Δ : BuilderCtx) (i : Nat) := (Δ[i]?).join
-- 範囲外とnoneは、どちらも構築器なしとして読む。
inductive BuilderOp where
  | append | appendAll | copy | length
-- Block.builderBind : BuilderKind → BuilderRefs → Block → Block
-- Expr.builderOp : BuilderOp → Nat → Exprs → BuilderRefs → Expr
-- Nat は普通の変数と共有するΓ上の位置である。
```

ΔはΓの先頭にそろえ、Γより短くてよい。Δの範囲外には構築器がない。整列の条件`BuilderCtx.Aligned Γ Δ`は、`Δ.length ≤ Γ.length`かつ`Δ.kindAt i = some k`なら`Γ[i]? = some none`とする。内部補題には、整列のほか、`BuilderCtx.Clean C.length Δ`（種類の中の型のTyOK）、`BuilderCtx.AtomsIn q.atoms Δ`（その型の原子の支持）、`BuilderCtx.Single Q Δ`（その型のSingleTy）を必要な箇所で課す。通常束縛の追加・専用束縛の追加・hideContsと空Δの境界での保存をL3で示す。公開入口のΔは[]で、四条件は自明に成り立つため、公開の主定理に前提を足さない（R135）。通常変数を一つ束縛するときは`some t :: Γ`と`none :: Δ`、構築器の宣言では`none :: Γ`と`some k :: Δ`へ進む。パターンの束縛・withも増やす通常変数の個数だけnoneをΔへ積む。discardは表層の位置を増やさない。

コア環境`fillBuilders Γ Δ`はΓと同じ長さで、Δのsome kの位置だけを`some k.cell`に置き換え、残りを保つ。整列から`RenOk Γ (fillBuilders Γ Δ) id`を導ける。builderOpはΔからセルの型を引き、通常のlocalは従来の`Γ[i]? = some (some a)`で型を引くので、構築器の位置を普通の値として読めない。境界の内側でΔを空にしてもΓのnoneは残り、外側の構築器を普通の値として捕捉する道は生じない。

七判断HasTypeQ/HasTypesQ/HasEachQ/HasHoleArgsQ/HasArmsQ/HasClausesQ/HasBlockQへ、同じ名前のままΔの添字を直接追加する。位置はパラメータQの直後、Cより前の最初の添字に固定する。例は`HasTypeQ D B op Q Δ C Γ R p e a ε`、公開abbrevは`HasType D B op := HasTypeQ D B op Qempty []`とする。二重の帰納型と旧新の同値証明は作らない。Def.WellTyped・ImplDecl.WellTypedのHasBlockQの呼び出しにはQsigの直後に[]を足す。公開の健全性11件の言明の文字列は保ち、WellTypedの定義の文字列の変更はl4a/results.mdへR132とともに記録する。Program.WellTyped・Input.Sound・WellFormedも定義を辿って比較する。

規則はΔの各位置をkindAtだけで読む。七判断について、すべてのiでkindAtが一致すれば導出を移せる`HasTypeQ.congrΔ`等と、構築器の構文を含まない入力では任意のΔでの判断と空Δでの判断が同値になる補題をL4aで証明する。後者は新構文の追加後も旧構文の意味を確かめる証拠として保つ。checkerのR/Q付き内部関数もΔを受け取り、公開入口は空Δの従来署名を保つ（R117・R132）。

| 規則名の案 | 前提と結論 |
|---|---|
| `B_BuilderBind` | kindの通常型の条件、Refs.Ok、`none :: Γ; some kind :: Δ ⊢ body : T ! ε` → `Γ; Δ ⊢ builderBind kind refs body : T ! (State ∪ ε)` |
| `E_BuilderAppend` | `Δ.kindAt i = some kind`、通常引数の型が単一/複数の追記型、Refs.Ok → 結果Unit、引数の効果∪State |
| `E_BuilderCopy` | 同じ位置の条件とRefs.Ok → 結果contents(kind)、効果State |
| `E_BuilderLength` | 同じ位置の条件とRefs.Ok → 結果Integer、効果State |
| 捕捉の境界 | lambda・lazy・節（handleFailの節を含む）の本体は空Δ。Γの型のshift・hideConts・節引数の追加は従来どおり |
| 部分適用の境界 | E_PartialCallの呼び出し先fとHasHoleArgsQ、E_PartialConのHasHoleArgsQへ[]を渡す。hideConts Γ・some rは既存どおり |
| 説明・ガード | E_TryResultDie・E_TryOptionDieの説明はhideConts Γ・R=none、matchのガードは通常束縛を加えたhideConts Γで同じΔを使う。いずれもEff.emptyを要求する |
| それ以外の部分式 | with本体、分岐、handle本体、通常の呼び出しの引数、tryの対象、returnは同じΔ。通常束縛を増やす位置だけ先頭へnoneを加える |
| 最後の構築器bind | `builderBind kind refs .empty`。結果Unit・効果State |

BuilderKindは通常のTyではなく、型変数の像・関数の潜在効果・Fail内部・辞書へ入れる規則もない。Δが型束縛を越える箇所はない。型パラメータを増やす通常節とhandleFail節では空Δへ切り替えるため、kind・fillBuildersと型/行のshift・代入の交換は予定しない。表層のExpr.rename/substも現行にはない。必要と分かった補題はL4bで根拠をR番号へ残して追加する。定数の本体は既存のΓを空にする規則に合わせてΔも空にする。これは局所名を捕捉する追加の構文境界ではなく、もともと閉じたトップレベル定数の扱いである（R137）。

BuilderRefsは種類別の帰納型`string … | list (T : Ty) … | bytes …`にする。Reference.new/get/setと純粋な追記・長さの参照先、その具体化の型引数を保持する。環境を受け取らない脱糖もこの構文だけでStringの+、List.append/concatenate、Bytes.fromList/concatenateを選べる。

`BuilderRefs.Ok D B C Q Δ i refs`は、操作対象のrefsの種類とΔ.kindAt iとの一致、各参照先の宣言の存在とrefNew/refGet/refSet/pureの種類、NamesWF、dictParams=[]（通常関数）、neffs=0、型引数の個数と整形式・非継続型の条件、admits/SatAll、PrimitiveAdmissible/Admissible、SingleTy、具体化後の型とcontents/cell・引数名・効果の一致を明示する。new用はiでの照合を新しい先頭`some k :: Δ`へ行う。同じ検査を純粋なString.join等にも行う。宣言のScopedとneffs=0からQに依存する行の条件を閉じる補題を使い、B.sig/D.funsとfunDecl_desugaredからコアの参照を型付けする。refNewの存在をBuiltins.Assumptionsへ足さず、これらを宣言表から検査する条件として扱う（R134）。

脱糖の関数の引数へ番号の対応表を加えない。`builderBind k refs rest`は空の内容を作るReference.newのletとrestの脱糖、`builderOp op i`は同じiの`.var i`を参照するCall/letへ写す。引数を一度ソース順に評価し、生成letの下への移動は既存のrenameで扱う。一般化した型保存の内部補題の結論は環境`fillBuilders Γ Δ`であり、公開入口は`fillBuilders Γ [] = Γ`で従来の結論に戻る。空Δの境界や通常の部分式で得たコアの導出をセル付き環境へ移すときは、`HasTypeCQ.rename (ξ := id)`と既存のRenOk.up/shiftを使う。`BuilderLayout`、二つの単射、underValue/underBuilderは置かない。

| 補題名の案 | 言明の形・既存定理への役割 |
|---|---|
| `BuilderCtx.aligned_value` / `aligned_builder` | 通常/専用束縛をΓとΔへ同時に追加して整列を保つ |
| `BuilderCtx.clean_*` / `atomsIn_*` / `single_*` | Clean/AtomsIn/Singleを通常・専用束縛の追加と境界で保存する。追加するkindの条件を前提とし、空Δの成立も示す |
| `fillBuilders.value_lookup` / `cell_lookup` / `renOk` | 通常の型の保持、セル位置の型の取得、`RenOk Γ (fillBuilders Γ Δ) id` |
| `fillBuilders.under_value` / `under_builder` / `empty` | 先頭への追加とfillの一致、空ΔではΓ |
| `fillBuilders_hideConts` / `BuilderCtx.aligned_hideConts` | `fillBuilders (hideConts Γ) Δ = hideConts (fillBuilders Γ Δ)`、整列をhideContsの下でも保つ。説明・ガードで使う |
| `HasTypeQ.congrΔ`等 / 旧構文のΔの任意性 | kindAtが全位置で一致すれば七判断が移る。構築器を含まない入力では空Δと任意Δの判断が同値 |
| `builders_no_capture` | 整列と上記の通常型の条件のもとで型が付く式/ブロックを脱糖すると、その中のすべてのコアのlam・lazyC・ハンドラの節の本体は、Δの構築器の位置に当たる外側のセル番号を自由に参照しない |
| `builders_ordinary_result` | 結果はRelease.TyでありBuilderIdを通常値として返す導出がない。Reference値一般の不在は主張しない |
| `builderRefs_typed` | Refs.Okから既存new/get/set・通常関数の参照の型付けを導く |
| `builderOp_desugar_typed` | 専用操作の型付け・整列・通常型の条件 → fillBuilders環境で7.3のコアの同じ型と効果 |
| `builderBlock_desugar_typed` | builderBindを含むブロックの型とStateの保存。先頭のセルのletと後続の環境を一致させる |
| `builderCheck_sound` | strictの内部検査成功、既存の入力/支持条件、内部のAligned/Clean/AtomsIn/Single → Δ付きの七判断と結果の型・効果の支持。公開入口は[]で四条件を満たす |
| `builderCheck_single` | 新規則でも単一Failが保たれる。StateはFail型を増やさない |
| `builder_examples_run` | 追記/copy/分岐/handle本体と継続を既存Referenceの有限実行へ通す |

builders_no_captureは表層の境界名の一覧を結論に使わない。コアの束縛を辿って外側の番号を換算し、内側で束縛された番号を自由変数から除く。専用宣言を追加した先も含む各部分導出のΓ・Δについて言明し、公開入口が空Δだから全体が自明になる言明を避ける。内側のnewはその局所のセルとして区別する。部分適用から生成されたlamも対象なので、境界への空Δの渡し忘れを検出できる（R131）。L4bでfillBuildersへの型保存・clean・scopedの一般化を規則ごとの帰納で閉じ、単に従来の導出をrenOkで移した証明だけでは完了としない。L4cではCheckInductionのmutualSoundnessの帰納法で示す性質（motive）とstrict/relaxedの支持保存へ、必要なΔの内部条件を加える（R133・R135）。

ShiftClean/SubstClean/Scoped/AtomsIn/WFの読者、strict/relaxed、支持、最小効果の合流、NoFail/単一Fail、再帰と継続の要求をそろえる。checkExpr/Block/Types/Each/HoleArgs/Arms/Clauses/Dict/Dicts/Def/Implの11件のsound、checkProgram_sound/checkProgram_empty/checkProgram_under/contracts、desugar_typedとsurface_effect_soundnessを、新構文を含めて閉じる。内部補題のΔへの一般化とコア環境の変更はR116へ記録し、公開の主定理の前提・結論、公理、Builtins.Assumptionsは維持する。定義を通じた意味の変更が必要なら設計者に確認する。ここで証明の成立を報告しているわけではない。

試作LocalBuilderのlocal印の消去・popHeap、Regionsの領域消去を採らず、Stateとセルの寿命は既存Referenceと保存継続へ委ねる。Loweringの純粋letの証明は本番Referenceへの証明へ流用せず、整列・fillBuilders・Refs.Okから示し直す。Escapeの型代入と捕捉の反例は、通常型と専用分類を区別した規則の確認材料に限る。

### 14.6 交換形式・032/257の照合・定数検査の境界

構築器の型付き表層を交換するcorpusを11から12へ上げ、builtins/stdlib/coverageの包みの版4は形が変わらない限り保つ（R108の案）。corpus12はbuilderBind/builderOp/kind/局所番号/Refsを明示し、旧版に新フィールドや新タグがあれば深い内側も拒否する。corpusは8/9/10/11/12を明示的に受理し、他の形式の2/3/4と版の判定を分ける。batch2の欄の拒否・既定補完はcorpusでは11未満、他形式では4未満に限り、11と12の双方をvalidateBatch2へ通す。構築器のタグ/欄はcorpus12だけに許す。sidecarVersionは11以上を4、9/10を3、8を2とする。旧corpus11以下は構築器なしとして読み、勝手にnewやΔを補わない。L7がVersion.leanと旧版の自己検査を担当し、B3がRustのlib.rs/named.rsの版11の書き出しとcheck_named.pyの版照合を12へ切り替える（R118）。inventory版2とは別の契約である。

独立した交換入力を段1で用意する。三種類、複数の構築器、値のbindとの交互、型/行の変数、名前付き引数のソース順、return、if/match、handle本体、節境界の正負を含める。部分適用の固定引数/calleeの専用操作、partialCon、return/タスク用関数への引き渡しを拒否入力に加える。構築器の宣言をまたぐ.local i・.resume k・辞書の.local j・.clause s i depthはすべてセルの位置を数え、節の辞書・受け取った辞書・resumeを使う入力で番号とΓ.lengthを手計算して固定する。外側セルの節からの参照は拒否し、節の内側で自分で宣言したセルを越えたresumeと辞書の参照は受理する。validateConstantBodyはbuilderBindタグを既存の束縛タグと同じく拒否し、builderOpも定数の本体では拒否する。番号を一つ数え落とし、型の異なる位置または範囲外を指す変種も拒否入力にする（R141）。Rustの書き出しを期待コアとして丸写ししない。Monad2も上位辞書・メソッド値化・利用者型の期待を独立入力で持つ。

Rust段では、ソース→型付き表層→専用情報→コア→独立IR検査→VM/参照実行をつなぐ。六入口はcoverageDiff、coverageProgramDiff、desugarDiff、builtinCheck、surfaceCheck、surfaceCheckAllである。実ソースの受理/拒否・推論型・効果・NoFail・辞書の位置、独立入力の脱糖、組み込みの署名、網羅性の結果/反例/拒否/対象外件数を照合する。

032と257は旧版と変更ごとに同じ固定の小中規模corpusを出し、全体番号・型・効果・診断の列・辞書・NoFail・コアが一致することを局所比較で確かめる。大きい性能入力の全量をLeanへ渡す費用は時間測定に混ぜず、縮めた同形の入力も独立に用意する。診断の英語文面や元位置はLeanの保証外なので、CLIの前後比較を別に保つ。

Scope/Regexの定数拒否は名前解決と定数評価の外側にあるため、不正な定数をLeanの通常Callへ渡すと受理しうる。この差を不一致から隠すのではなく、ソース段の追加拒否と交換段の検査の責任の違いとして列を分ける。受理された呼び出しは従来と同じCall/Result/実行時検査へ渡すことを比較する。A/Cの公開境界も同じ扱いとし、型表には全内部構成子を保持する。

接続時はこれらの局所比較をstageの対象にし、check-formal.sh全体は最終の関係状態で一度行う。途中に全体比較を次の作業の必須前提とする理由が生じた場合は、07-03の引用条件を満たす記録を残し、最終でその状態から入力が変わらなければ引用する。単に段数の区切りを理由に全体比較を繰り返さない。

### 14.7 難しさ・代案・停止点

| 懸念 | 最初に試す同じ保証の代案 | 止まる条件 |
|---|---|---|
| Δ追加で七判断と相互帰納法の変更が広がる | 公開入口は空Δのラッパー、内部補題だけ任意Δへ一般化し、表現変更の前提をR番号へ記録 | 主定理の前提追加、構築器を保証から除外、Builtins.Assumptionsの追加が必要 |
| 通常bindとセルの位置の整列が保てず、脱糖の型が付かない | ΓとΔの整列・fillBuildersと束縛追加の補題を先に閉じ、既存renameによる移行と有限例で確認する | 性質1に新しい外部仮定や型付きの後付け検査だけを要する |
| handleの節・保存継続と局所禁止が一致しない | 節は空Δ、本体は同Δ、実行は既存Referenceとする。既存のresume/dropの規則へ戻して照合 | 保存継続や解放の所属を変える、Stateを外す、主定理を弱める必要 |
| Scopeの文字列parserと小モデルがずれる | 解析結果の対応と独立期待値を先に直す。一段/多段を分け、parser全体の証明を約束しない | 新しい範囲付き型/効果を採る、対象安全を本体の定理へ追加する必要 |
| Monad2の署名/辞書例が通らない | 既存二引数の宣言・上位射影・完全適用の規則の範囲で例を直す | 型の部分適用・型の等号の計算・操作の高カインド引数が必要 |
| 最適化の順序で型/診断/辞書が変わる | 依存が不明なら全制約を登録順に再投入し、索引/clone削減だけを残す | 規則や既存の拒否を変えないと目標へ達しない |

いずれも処理系へ進む前に、通らない言明・最小の反例・規則/書き写し/表現の都合の分類と代案を設計者へ示す。証明失敗を仮定へ移す案、禁止をRustだけへ狭める案、範囲を落とす案は自動では採らない。形式化の重い追加を二つに増やさず、構築器をこの版の主な不確実性として扱う。

## 15. 受け入れの例

以下は実装後に確認する独立した期待であり、C1で実行した検査ではない。断片と明記したもの以外は、importを含むライブラリ/テストモジュールとして保存できる形である。拒否例の一行置換は元の例のその行だけを置き換える。各例の型検査とCLIの診断・実行結果を結び、実装の表の形だけを確かめる重複テストにしない。テスト作成時の関門はC2以後にtest-auditで行う。

### 15.1 公開境界とScope（142）

```benitoite
import Benitoite.Unofficial.Scope

@test
function scopeExample() -> Unit uses Assert.Check
  bind checked <- Scope.checkHost(pattern: "*.example.com", host: "API.EXAMPLE.COM")
  match checked with
    case Result.Ok(value) ->
      Assert.equal(actual: Scope.host(value), expected: "api.example.com")
      Assert.equal(actual: Scope.hostPattern(value), expected: "*.example.com")
    case Result.Error(_) -> Assert.equal(actual: true, expected: false)
  end match
  Assert.equal(actual: Result.isOk(Scope.checkPath(pattern: "/data/reports/**", path: "/data/reports")), expected: true)
end function
```

同じ位置のcheckHostを以下の前三つへ替えると、上から順にE0459・E0460・E0462で拒否する。四つ目のcheckPathは返す型がCheckedPathで後続のScope.hostと合わないので、同じ位置へは置き換えず、独立した関数の中の `bind _ <- ...` で書く。これもE0462で拒否する（R192）。

```benitoite
Scope.checkHost(pattern: "api.*.com", host: "api.example.com")
Scope.checkHost(pattern: "example.com", host: "example.com.")
Scope.checkHost(pattern: "*.example.com", host: "a.b.example.com")
Scope.checkPath(pattern: "/data/reports/**", path: "/data/reports-old")
```

```benitoite
import Benitoite.Unofficial.Scope

// 形式は動的な引数として渡すため、結果は実行時のErrorになる。
function dynamicHost(pattern: String, host: String) -> Result[Scope.CheckedHost, Scope.ScopeError]
  return Scope.checkHost(pattern: pattern, host: host)
end function

@test
function endpointExample() -> Unit uses Assert.Check
  bind endpoint <- Scope.checkEndpoint(hostPattern: "**.example.com", host: "a.b.example.com", minimumPort: 0, maximumPort: 65535, port: 443)
  Assert.equal(actual: Result.isOk(endpoint), expected: true)
  Assert.equal(actual: Result.isError(dynamicHost(pattern: "*.example.com", host: "example.com")), expected: true)
end function
```

端点のmaximumPortを `-1` にすればE0461、portを `65536` にすればE0461、範囲を443〜443、portを444にすればE0462である。内部構成子 `Scope.CheckedHost(pattern: "*", host: "x")` を外部から構築する式は、内部の欄名を知っていてもE0340である。2.1のPositiveをimportした別モジュールで `Positive.Positive(raw: -1)`、`Positive.Positive(..value, raw: -1)`、`Positive.Positive.raw(value)`、レコードパターンによる取得もE0340とする。型注釈 `Option[Positive.Positive]` と公開make/valueの利用は受理する。

追加の意味の対照は `*.example.com` の頂点拒否、`**.example.com` の一段/多段受理、四数字ラベルの拒否、`localhost`受理、`/**`と根、`/data/../secret`拒否、同パッケージ別モジュールとimport別名・型別名の境界である。静的拒否と動的Errorをそれぞれ確認する。

### 15.2 Range（022）

```benitoite
import Benitoite.Unofficial.Range

@test
function rangeExample() -> Unit uses Assert.Check
  match Range.checkInteger(minimum: 0, maximum: 10, value: 10) with
    case Result.Ok(value) -> Assert.equal(actual: Range.value(value), expected: 10)
    case Result.Error(_) -> Assert.equal(actual: true, expected: false)
  end match
  match Range.checkInteger(minimum: 10, maximum: 0, value: 5) with
    case Result.Error(Range.RangeError.InvalidBounds(10, 0)) -> ()
    case _ -> Assert.equal(actual: true, expected: false)
  end match
  match Range.checkInteger(minimum: 0, maximum: 10, value: 11) with
    case Result.Error(Range.RangeError.OutOfRange(0, 10, 11)) -> ()
    case _ -> Assert.equal(actual: true, expected: false)
  end match
end function
```

後二つは定数でも静的に拒否しない。`Range.CheckedInteger(minimum: 0, maximum: 10, value: 11)` の外部構築・更新・パターン・自動アクセサによる取得はE0340とする。公開のRange.valueは受理する。最小/最大Integerを含む閉区間、一点区間、端点の取り出しと再検査も成功例に含める。

### 15.3 Regexと定数の境界（026）

```benitoite
import Benitoite.Unofficial.Regex

const stem: String = "[a-z]"

function valid() -> Result[Regex.Pattern, String]
  return Regex.compile(stem + "+")
end function

function dynamic(source: String) -> Result[Regex.Pattern, String]
  return Regex.compile(source)
end function

@test
function regexExample() -> Unit uses Assert.Check
  Assert.equal(actual: Result.isOk(valid()), expected: true)
  Assert.equal(actual: Result.isError(dynamic("[")), expected: true)
end function
```

validの引数を `"["` にすればE0457であり、Resultをmatchしても同じである。実行時と同じRegexBuilderがコンパイル上限を返す定数はE0458である。取得の予算を超えた式はE0458にせず実行時へ残す。`const p: Result[Regex.Pattern, String] = Regex.compile("x")` は既存のE0433である。標準束縛のimport別名での直接呼び出しはE0457の対象、`bind compile <- Regex.compile` からの間接呼び出しは動的結果とする。一次位置は呼び出しの引数、constは補助位置として観察する。

### 15.4 Monad2とSkillの推奨（164・021）

```benitoite
import Benitoite.Trait

function twice[F[_, _]: Trait.Monad2, X](x: F[Integer, X]) -> F[Integer, X]
  return Trait.Functor2.map(x: x, f: lambda(value) return value * 2 end lambda)
end function

@test
function monad2Example() -> Unit uses Assert.Check
  bind ok: Result[Integer, String] <- twice(Result.Ok(3))
  bind error: Result[Integer, String] <- twice(Result.Error("bad"))
  Assert.equal(actual: ok, expected: Result.Ok(6))
  Assert.equal(actual: error, expected: Result.Error("bad"))
end function
```

Xを保てない次の関数はE0401で拒否する。

```benitoite
import Benitoite.Trait

function wrong(x: Result[Integer, String]) -> Result[Integer, String]
  return Trait.Monad2.flatMap(x: x, f: lambda(value)
    bind other: Result[Integer, Integer] <- Result.Error(value)
    return other
  end lambda)
end function
```

一引数Monadへの二引数Fの制約や、引数の個数が違う型構成子への実装はE0427で拒否する。一引数Fの汎用関数をResult値で呼ぶ場合は、現行の推論でFを決められないE0407と値引数の不一致E0401になる。外部からの標準Monad2[Result]の再実装は所属の規則が先に働きE0701となり、宣言元で許される同じクラス・型構成子への重複はE0702となる（R164）。applyは両方Errorでfs側、関数のコールバックの回数は両方Okなら1・どちらかErrorなら0を期待する。引数式の副作用は両方ともソース順で実行される。pureの型注釈、メソッド値化、上位辞書、利用者二引数dataの成功と誤り側を含める。

021の具体型の成功例は `Result.map(r: Result.Ok(3), f: lambda(value) return value * 2 end lambda)` である。上のtwiceは汎用関数の成功例であり、両者をSkillに並べる。021自体に新しい静的拒否は設けない。既存Monadへ二引数Fを制約する例をE0427の案内として示し、Show/toStringやFloatの比較の無条件な置換を推奨例にしない。

### 15.5 三種類の構築器（248）

```benitoite
import Benitoite.StringBuilder
import Benitoite.ListBuilder
import Benitoite.BytesBuilder
import Benitoite.Bytes

@test
function builderExample() -> Unit uses State, Assert.Check
  bind b: StringBuilder <- StringBuilder.new()
  StringBuilder.append(builder: b, text: "a")
  bind before <- StringBuilder.copy(b)
  StringBuilder.appendAll(builder: b, texts: ["b", "c"])
  Assert.equal(actual: before, expected: "a")
  Assert.equal(actual: StringBuilder.copy(b), expected: "abc")
  bind xs: ListBuilder[Integer] <- ListBuilder.new()
  ListBuilder.append(builder: xs, value: 1)
  ListBuilder.appendAll(builder: xs, values: [2, 3])
  Assert.equal(actual: ListBuilder.copy(xs), expected: [1, 2, 3])
  bind bs: BytesBuilder <- BytesBuilder.new()
  BytesBuilder.append(builder: bs, value: 65u8)
  BytesBuilder.appendAll(builder: bs, bytes: Bytes.fromList([66u8]))
  Assert.equal(actual: Bytes.toHex(BytesBuilder.copy(bs)), expected: "4142")
end function
```

拒否する断片は、同じ関数内で `bind alias <- b` がE0464、`bind f <- lambda() return StringBuilder.copy(b) end lambda` がE0465、`bind append <- StringBuilder.append` または `StringBuilder.append(builder: b, text: _)` がE0466、注釈を消した `bind b <- StringBuilder.new()` がE0463である。`uses State`を消しただけの関数は既存のE0501である。

普通の関数・構成子の部分適用も捕捉の負例にする。以下は、bを宣言済みの関数本体の断片である。gはStringとUnit、fはIntegerとUnitを受け取る純粋な関数、chooseはStringからUnit一引数の純粋な関数値を返す関数とする。startはUnit一引数・Stateを許す関数を受け取り、タスク内で呼ぶ補助関数である。戻り値の注釈とusesはその関数値の型・効果に合わせ、別の型不一致やState不足で拒否される例にしない。

| 拒否する断片 | 検査する境界と期待 |
|---|---|
| `return g(text: StringBuilder.copy(b), unit: _)` | partialCallの固定引数からの捕捉をE0465 |
| `return (choose(StringBuilder.copy(b)))(_)` | partialCallの呼び出し先の式からの捕捉をE0465 |
| `return Pair.Pair(StringBuilder.copy(b), _)` | partialConの固定引数からの捕捉をE0465。Pairを明示importする |
| `start(f(size: StringBuilder.byteLength(b), unit: _))` | 作った関数をタスク用関数へ渡す前の捕捉をE0465 |

対応する正例は、部分適用より前に`bind snapshot <- StringBuilder.copy(b)`または`bind size <- StringBuilder.byteLength(b)`で通常値を取り出し、上の固定引数/calleeにその通常値を使う形である。部分適用の固定式は呼び出すまで評価されないため、copyを固定式に直接書く形と、この先行する束縛を区別する。Rustの診断はB1/B2、Leanの境界はL6、交換入力はL7/B3の責任とし、型保存だけで捕捉の禁止を確認したとはしない（R131）。

さらにdata/List/Referenceへの格納、型引数、省略した型を通る利用者関数への引数、パイプ、lazy、task、handle節からの外側参照を拒否する。if/match/handle本体、内側のlambdaで自分でnewする形、完成した値の捕捉は受理する。既存の保存継続のresume/drop、失敗/取消、copy後のList[Reference[T]]の要素の共有、上限超過がset前であることを確認する。

### 15.6 docの例（088）

四つのバッククォートの外枠は、この文書でコメントの三連フェンスを表示するためのものである。

````benitoite
/// ```benitoite test
/// @test
/// function lengthExample() -> Unit uses Assert.Check
///   Assert.equal(actual: List.length([1, 2]), expected: 2)
/// end function
/// ```
/// ```benitoite error
/// function bad() -> Integer
///   return "wrong"
/// end function
/// ```
/// ```diagnostic
/// E0401
/// ```
public function documented() -> Unit
  return ()
end function
````

`test --doc`はtest一例と拒否一例を成功として報告し、通常testはその二例を実行しない。`--doc --check`ではtestのAssertを実行しない。diagnosticを消すとE0260、期待をE0402へ変えると期待不一致のテスト失敗になる。private宣言を暗黙に使う例はE0301、外部opaqueの構築はE0340とする。後の実行例が許可上限を超える場合はE0512となり、前の例も実行されていないことを出力で確認する。元コメントのファイル・行・Unicodeを含む列への位置の復元も観察する。

### 15.7 Failの案内（260）

```benitoite
import Benitoite.Unofficial.Failure

function work() -> Integer uses Failure.Fail[String]
  return Failure.raise("bad")
end function

@test
function failureExample() -> Unit uses Assert.Check
  bind result: Result[Integer, String] <- Failure.toResult(lambda() return work() end lambda)
  Assert.equal(actual: result, expected: Result.Error("bad"))
end function
```

次はE0506であり、handleとFailure.toResultの両方のhelpを期待する。mainの代わりに同署名の@testでも同じである。

```benitoite
import Benitoite.Unofficial.Failure

function main() -> Unit uses Failure.Fail[String]
  return Failure.raise("bad")
end function
```

Log等の一般の利用者エフェクトのE0506にはtoResultのhelpを出さない。英日11節の段落移動は内容とLogのoutputを保つこと、生成diagnosticsと実CLIのhelpが一致することを受け入れる。

### 15.8 Show・Orderの生成（087）

```json
{"version":1,"targets":[{"source":"Person.bnt","type":"Person.Person","region":"traits","show":true,"order":true}]}
```

```benitoite
// Person.bnt。生成先の管理領域は既存のbegin/endの印で用意する。
public record Person
  name: String
  age: Integer
end record
```

生成後、公開APIとして次を実行する。

```benitoite
import Person
import Benitoite.Trait

@test
function generatedTraits() -> Unit uses Assert.Check
  bind ada <- Person.Person(name: "Ada", age: 7)
  Assert.equal(actual: Trait.Show.show(ada), expected: "Person(name: \"Ada\", age: 7)")
  Assert.equal(actual: Trait.Order.compare(x: ada, y: Person.Person(name: "Ada", age: 8)), expected: Trait.Ordering.Less)
end function
```

管理領域外に同じimplementがあればpreviewは終了1・`derive.overlapping_implementation`、生成物を手で二重に置いて通常checkへ通せばE0702とする。自己を欄に持つrecordは `derive.cyclic_dependency`、型パラメータのあるtargetは `derive.unsupported_type_parameters`、欄に必要な辞書がなければ `derive.missing_implementation` で拒否する。生成後の言語検査でも辞書がなければE0705である。不透明型そのもののProperty生成要求は `derive.opaque_construction`、同モジュールで明示要求したShowは受理する。

### 15.9 inventoryと生成記録（259）

次は版2のsignatureの一部分であり、完全なinventoryは9.1の必須キーを持つ。

```json
{"typeParams":[{"name":"F","kind":{"tag":"constructor","arity":2},"builtin":null},{"name":"A","kind":{"tag":"value"},"builtin":"equality"}],"returnType":{"tag":"application","head":{"tag":"parameter","index":0},"arguments":[{"tag":"parameter","index":1},{"tag":"application","head":{"tag":"named","name":"Benitoite.String.String"},"arguments":[]}]}}
```

`{"kind":"Ctor { arity: 2 }"}` や `{"tag":"unsupported","resolved":"Fn(..)"}` は版2のschema不良として拒否し、Debugの表示から復元しない。未知タグ、範囲外のparameter、kindの引数数不一致は消費側で `derive.invalid_inventory`、宣言にないRigidの出力はinventoryの終了1とする。これらは道具の失敗でありEコードはない。

構造が同じままmetadata.resolvedやspanだけを変えても意味のハッシュは同じ、欄順・可視性・型・クラス実装・選択設定を変えると該当ハッシュが変わる。管理本文の一文字の手書き変更は移行前の出力ハッシュで拒否する。旧manifestの新版applyは `derive.incompatible_manifest`、旧記録のcheckは `derive.migration_required` である。新previewの確認とapply後はcheck/test/derive checkが成功する。

### 15.10 小さな関数と制約の最適化（032・257）

032の最小の成功/拒否の対照は次である。大規模の入力は16節の生成規則を使う。

```benitoite
function f0(x: Integer) -> Integer
  bind y <- x + 1
  return y
end function

function main() -> Unit
  bind _ <- f0(1)
  return ()
end function
```

f0のreturnを `return "wrong"` へ替えるとE0401であり、位置・順序を前後で保つ。引数・局所束縛・複数モジュール・lambda・節を含めても番号を保つ。

257では次の高階の成功を固定する。

```benitoite
function apply[A, B, effect E](value: A, f: function(value: A) -> B uses E) -> B uses E
  return f(value)
end function

function successful() -> Integer
  bind x <- apply(value: 1, f: lambda(value) return value + 1 end lambda)
  return apply(value: x, f: lambda(value) return value + 1 end lambda)
end function
```

関数型の潜在効果を無視して成功させる最適化を拒む対照として、純粋な関数内で `Reference.new(1)` を呼ぶ例はE0501、二つの異なるFail型を同じ効果集合へ合流する入力はE0514、NoFailを満たさない行の具体化はE0515を保つ。17節の更新表の既存の型クラス/Failの入力も使い、最適化のために診断順・辞書の選択・拒否範囲を変えない。

### 15.11 縮小予算と移行（258）

```benitoite
import Benitoite.Unofficial.Test.Property

@test
function propertyBudget() -> Unit uses Assert.Check
  bind config <- Property.Config(seed: 1, trials: 1, size: 1, maxShrinks: 20, maxShrinkWork: 1000)
  bind result <- Property.check(config: config, gen: Property.constant([1, 2, 3]), shrinker: Property.shrinkList(Property.shrinkInteger()), property: lambda(value)
    return if List.isEmpty(value) then Result.Ok(()) else Result.Error("nonempty") end if
  end lambda)
  Assert.equal(actual: Result.isError(result), expected: true)
end function
```

旧縮小器 `Property.Shrinker(candidates: lambda(value) return [0] end lambda)` をInteger用に使うと返す型の不一致E0401、旧ConfigからmaxShrinkWorkを省くとE0428である。maxShrinkWorkを `-1` にした例は静的には受理し、checkがInvalidConfigを返してコールバックを呼ばない。0のときは縮小器を呼ばずshrinks/shrinkWorkが0、1のときは初回candidatesだけで次の比較/propertyを呼ばない。両方の予算、同値の候補の初出順、失敗候補からの再開でも累積値がリセットされないことを具体的なCounterexampleで照合する。

## 16. 性能の受け入れ（R16〜R22）

### 16.1 比較する状態と測定の共通条件

本測定の前にbenchmarkスキルの静かな計算機の条件と了承を得る。C1では測らない。最終の一つの測定枠で次の版を同じ計算機・同じRust toolchain・Cargo.lock・releaseの既定機能・同じ入出力設定でビルドして比較する。heap-verify/gc-stress/alloc-statsを時間の構成へ混ぜない。

| 識別名 | 比較する処理系 |
|---|---|
| old | `6b0568a3ddcc46b0a0e64504139ce286a27fd86a` から再ビルドした0.0.8 |
| map | 032だけを取り込んだ最終状態。完全なコミットと差分を実装時に固定 |
| solve | mapへ257を取り込んだ状態。新しいA/C/構築器の検査をまだ含めない |
| final | 全機能・レビュー修正後の0.0.9候補 |

時間は準備1回の後、old/map/solve/finalを一組として順序を交互に変えて各10標本採り、中央値と全標本を残す。最小値だけを合否に使わない。入力ファイルの生成・ビルドは計時外、CLIの起動から終了までを実時間として測る。空mainの対照を同じ組で測る。出力と終了状態が一致することを時間の比較より先に確認する。

同じ解析済み入力を使う補助の段別測定で読み込み・lex/parse・resolve・typeckを分ける。計時用の補助を使ったバイナリは識別し、公開CLIの実時間と混同しない。段別の回数計数・最大RSS・alloc-stats・CPUプロファイルは別の実行で取得する。samplyが使えない場合は未取得と記し、原因の断定をしない。

測定入力の生成器・パラメータ・ソースのSHA-256と入力manifest、バイナリのSHA-256・HEAD・差分・機能・Rust/OS/CPU情報・終了状態・全標本を `tools/bench/results/<実測日>-<候補短ID>-syntax-batch3/` に保存する。Markdownと線形目盛の図付きHTMLもそこに置く。生プロファイルは同名のprofiles下、D/results.mdからその記録を参照する。大きい生入力を追跡しない場合も、生成器・manifest・ハッシュ・再現手順を追跡する。S3の参考値はoldの再測定の代用にしない。

### 16.2 関数数に対する伸び（032、R16・R17）

Pythonの生成器はNを0/1250/2500/5000/10000/20000として、i=0..N-1について次のテンプレートを連結し、最後に空のmainを置く。

```text
function f{i}() -> Integer
  return {i}
end function
```

主系列のほか、`f{i}(x: Integer)`で `bind y <- x + {i}; return y` とする系列、100関数ごとにモジュールへ分けて入口が明示importする系列を同じNで作る。セミコロンは実ソースでは改行にする。これらは未使用の関数の本体も検査することを観察するため、実行時間や最適化された呼び出し時間を測らない。`benitoite check <entry>`を使い、成功入力と意図した型エラーを一つ持つ入力を分ける。

T(n)を10標本の中央値、I(n)=T(n)-T(0)とする。主系列のmapとoldについて、`I_map(10000) ≤ I_old(10000)/4`、`I_map(10000)/I_map(5000) ≤ 2.5`、`I_map(20000)/I_map(10000) ≤ 2.5` を目標とする。差し引きが計時のぶれ以下なら比を捏造せず再測定または判定不能とする。finalでも同じ伸びを確認し、新規の定数/局所検査の費用を分けて示す。

小さい入力は0/10/100/1000関数と代表的な既存のスクリプトを使い、`T_new-T_old ≤ max(0.1*T_old, 0.002秒)` を目標とする。引数/モジュールの系列は主系列と同じ数値の達成を無根拠に前提にせず、二乗の空き走査が消えていること・退行・最大RSSを報告する。多列match等の残る費用を今回の達成へ混ぜない。

### 16.3 制約数とFail型の深さ（257、R18・R19）

関数数を二つの補助と一つの測定本体へ固定し、15.10のapplyを使う高階呼び出しを100/300/450/900/1800個、`bind x{i} <- apply(value: 前の値, f: lambda(value) return value + 1 end lambda)` として並べる。Failureのimportなし/ありを別系列にする。クラス系列は型付きのTrait.Show.showとOrder.compare、独立した上位クラス三段のメソッド使用を100/300/900/1800回並べる。文字列表示の計算自体は実行せずcheckで制約生成・辞書の確定を測る。

深さ系列は `T0=String, T(d+1)=Option[Td]` の別名を生成し、Fail[Td]を持つ関数とtoResultで受け止める関数をd=8/16/32/64で作る。別名宣言の解析費用は段別に分け、幅を固定する。同じTdを引数/返り値/関数型の潜在Failにも置く対照を作り、外側Failだけの改善と区別する。NoFail違反・単一Fail違反の拒否系列は別に時間と診断を保存する。深さ上限に拒否された場合は件数とコードを報告し、成功の標本へ入れない。

主な比較はmap対solveとして032の効果を除く。大きい成功入力（900/1800）の型検査時間をmapの75%以下、450→900→1800の型検査の基準差し引き後の倍増を各2.5倍以内とする。100/300/900は既存の調査との傾向比較にも残す。Failの正規化後の訪問節数は深さに比例して増え、子でzonkを繰り返さないことを計数する。プロファイルから制約のclone/contains・上位path・型確定の寄与を分ける。小さい入力の退行幅は16.2と同じである。最終候補はold/map/solveからの差も記録する。

### 16.4 縮小候補とProperty全体（258、R20〜R22）

元入力は長さ24/88/256のList[Integer]とし、全要素7、0..n-1の異なる要素、全要素0、最大Integerを並べた四系列を作る。固定した値から組み込みの候補を進める時間と、constantのGenを使うProperty.check全体を分ける。propertyは縮小候補が全部Okになる形と、最初から常にErrorになる形を使い、初回の失敗を確実に作る。全部Okの形では元の固定値だけError、他をOkにする。

maxShrinks=0/1/20/1000、maxShrinkWork=0/1/1000/10000の境界と主系列を測る。全組合せの時間を合算せず、n=88・maxShrinks=20・maxShrinkWork=1000を主な前後比較とする。旧版には作業予算がないためmaxShrinksと入力を揃え、同じCPU作業量の比較とは呼ばない。新しい打ち切りの効果も含む利用者の待ち時間の改善として、旧版の半分以下を目標とする。候補順の比較は両版の共通の、打ち切り前の先頭部分で別に行う。

同予算で88→256の時間を4倍以内とし、成功した性質の呼び出しも含め `shrinks ≤ maxShrinks`、`shrinkWork ≤ maxShrinkWork` を全例で確認する。生成段数・比較数・性質の呼び出し数・最終reduced/message/limitReachedを保存する。比が不安定な短時間は同じ純粋計算を同じ回数だけ繰り返す測定本体へし、その回数を両版で揃える。時間を作るためsizeや分布を勝手に変えない。

Stringの非ASCIIスカラー値、Mapの鍵順、生成recordの欄順でも先頭の候補・反例・打ち切りを照合する。keyやOrderへ制約を強めて速度を得ない。maxShrinkWork=10000という推奨値と上限1000000の妥当性は本測定の結果で確定し、変更が要ればdecisionsへ理由と影響を記録する。

### 16.5 目標未達と追加する比較

構築器のString/List/Bytesについて、空/短い追記、多数の等長の断片、appendAll、copy前後を、既存の `+`・String.join・Listのfold/concatenate・Bytes.concatenateと比べる。copyの回数も独立に変える。B12に従い速さを合否にせず、累積のコピーとセルの費用を記録する。Monad2と直接Result関数も同じ計算/コールバックで比較できるが、M9の推奨の根拠へ遡って使わない。

R17/R19/R22の目標に届かなければ、全標本・原因の見立て・残る処理・代案を示して設計者に判断を戻す。上限・期待値・候補の意味・形式化の保証を緩めて合格にしない。本測定とchange/releaseは改造末にまとめ、通常のwork/stageでは必要な小規模の局所確認だけを行う。

## 17. 実装時に更新する文書・生成物・変更箇所

以下は実装後の反映先であり、C1では変更しない。現行設計書には機能が接続してから実装内容だけを書く。形式化の写しだけは07-04に従って段1でLeanと同じ変更へ置き、未接続の状態を改造の結果に明示する。既存の見出しをむやみに改名せず、改名する場合はコードのコメント・spec印・道具の参照を同じ変更で直す。

| 対象 | 現行設計の章・節と反映内容 | 主な実装・文書・生成物 |
|---|---|---|
| opaque | 01-02「属性」、01-03「公開」、01-06「型」「等値の型」、02-04「束縛と表」「宣言の検査」「名前の引き方」 | syntax/ast・parser/items・formatter、resolve/collect・checks・lookup・walk、typeck/recordsとパターンの入口。英日リファレンスの型/公開/属性 |
| Scope/Range | 03-06へ「Scope」「Range」を追加し、非公式モジュール表・公開API・失敗・保証を記す。01-06の型の保証との境界を明示 | prelude/stdlib/Scope.bnt・Range.bnt、標準モジュール表、Scopeの純粋helper/組み込み登録。VM/heapの新値は不要 |
| 定数の追加検査 | 01-02「定数」、01-06「定数の型」、02-05「定数の検査と評価」「本体の後の検査」、03-06のRegex | typeck/consts・定数引数の共通部、CallPlanに直接形の情報、builtins/funcs/regexと共通helper、diagnostics。英日リファレンスのRegex/定数と移行 |
| Monad2/021 | 01-06「高カインド型」「標準の型クラス」、03-06「標準の型クラス」、02-06「辞書の引数」には既存方式を使う対応例 | Trait.bnt、traitの宣言/実装/解決とdictsの読者。Skill/idioms、英日リファレンスの型クラス/Result |
| 構築器 | 01-02「ブロックと文」に局所宣言、01-03「局所の束縛の有効範囲」、01-06へ「関数内の構築器」、01-07のState、02-05「出力」「制約の生成」「書く位置の検査」、02-06「脱糖」 | 標準専用名の表・doc、resolveの局所名、typeck/context・表層情報、ir/desugarのbuilder変換・exchange。01-12の新規則、07-04の内外と保証 |
| doctest | 01-01のdocの位置情報、01-02「ドキュメントコメント」、02-02の位置対応、06-01のtest/報告/形式一覧、06-04「テストの実行」「非実行の検査」「結果の報告」、06-06の標準doc | DocComment/DocStore、cli/tools/doc_examples・test_runner、tests/doc_examples、stdlib_doc_examples、CLI help、英日testの説明 |
| 260 | 02-10「修正案」、06-04のFail、英日リファレンス11節と18節 | effects/declarations・diag/codes、生成diagnostics、SkillのFail案内 |
| 259/087 | 03-06「外部生成の宣言情報」「外部生成の管理と照合」、Show/Orderの契約 | examples/derive_inventoryのreader/config/README、tools/deriveの設定/schema/テンプレート/ハッシュ/記録/README/People例、手書きSkillの開発用案内 |
| 258 | 06-04「プロパティベーステスト」、03-06のPropertyの契約と生成管理 | Test/Property.bnt、Property生成テンプレートと記録、同梱例、英日リファレンス、Skillのsize/予算/再現の説明 |
| 032 | 02-05「検査の単位と手順」「出力」「型とエフェクトの表現」、07-02の測定記録 | Body内の表とfinish/check_type_limits、全体表の読者は保持 |
| 257 | 02-05「制約の解決」「型クラスの制約の解決」、07-02の測定記録 | typeck/solve・traits/solve。型と効果の規則は変更しない |
| 段1/全比較 | 01-12、07-04「01-12との対応」「証明する性質」、07-03の対象の割り当て | SurfaceのSyntax/Typing/Desugar/WellFormed/Check/CheckSound/Programと関連Lemmas、Checked/Libraryの小証明、Exchange版12のreaderと独立入力 |

`docs/design/README.md`は節の追加だけなら章の目次を変更しない。章を増やす必要が判明したときは目次・全リンクも更新する。本書へのリンクやdocs/todoへのリンクを現行設計書へ追加しない。

英語の `docs/reference/benitoite.md` を正として公開APIと移行の例を更新する。`docs/ja/reference/benitoite.md`とinstallの該当箇所、`docs/ja/skill/`の訳は候補の最終APIで揃える。260の11節の段落移動だけは英日同時に行う。手書きSkillのSKILL/idioms/common-mistakes/inspectionに、公開境界、動的失敗のテスト、構築器の制限、予算・生成の移行を反映する。

生成したgrammar/diagnostics/stdlib参照と埋め込みbundleは手で直さずgen_skillで作り直す。新しい標準モジュール・専用の構築器の契約・docの実行例を生成対象へ加える。Propertyとderiveの例は同じ新記録へ移し、生成物の一致と例の実行の双方を確認する。言語の受理を狭めるRegex/Scopeの定数拒否はlanguage宣言の0.0.9の非互換表にも登録する。

## 18. 移行・C2への引き渡し・確認を要する点

利用者向けの0.0.9の案内は、Regexの不正な定数が実行時Errorから静的拒否へ変わること、新しいScopeにも同じ規則があること、Rangeは定数でもResultであることを並べて示す。@opaqueは既存型へ一括で後付けしない。既存公開型へ利用者が付ける場合は構築/更新/パターン/アクセサの利用を壊すことを説明する。

開発用の案内はinventory版2、生成記録版2/hashVersion2、新manifestの再確認、Propertyの新Shrinker/Config/CounterexampleとlibraryVersionを一つの移行手順に集める。再現情報には具体的な反例と版を残し、同seedだけの一致を約束しない。構築器のState・捕捉禁止と性能の限界、doctestの公開境界と実行効果の事前照合も明記する。処理系の版は最終の一作業で一度だけ上げる。

C2は本書と回答済みのdecisionsを基に、共通依頼文と計画の雛形を写して具体化する。作業別のRustの型/主要シグネチャ、変更ファイル、30〜60分を目安にした担当単位、正確な検査コマンド・構成・対象・基準・見込み時間をplanの「検査の割り当て」へ集める。Leanは長くてよい。段1の全Lean先行、032→257→新検査、公開境界→Scope/Range、259→087、258→Property生成の順を保つ。

workは途中の局所確認と末尾一度、stageは新しい受け渡しだけを名指しし、Opusの独立レビューは4〜5回にまとめる。change・check-formal全体・本測定・releaseは最後に一度とする。07-03の安全点/ヒープの例外に当たる変更があれば、局所heap-verify/gc-stress・doc_defaultと必要なcheck-heapを次の作業の前提へ加える。既存Referenceへの脱糖だけを理由に、合成した値の保存や根の変更を確認から外さない。再実行と結果の引用は07-03の関係入力の一致で決める。

R109のdoctestの機械可読報告の形式とR112の作業時間・引き継ぎの区切りは、2026-10-18に設計者が推す案で決定した。P1では、R109にtestResults版2の必要性、R112にS3と対象コードを照合した見積もりの改訂を追記した。R3は同じ発見結果を報告に使うと決めたが、既存の版1へどう載せるかまでは決めていない。--docの報告は版2とする。

R20のmaxShrinkWorkの推奨値は本測定後に確定する。段1で証明が通るか、R17/R19/R22の性能目標を達成できるかは未検証であり、採用済みの事実として扱わない。14.7の停止条件に当たれば設計者に確認する。C1では範囲を落とす案や主定理の変更を承認したことにはしない。

# 内部保存の形と既存読者

固定した内部形は [internal-save.lean](internal-save.lean) の `Detail Raw` である。元入力二つ、解析済み入力二つ、解決した全原子列と対象、両起点、失敗種別の九欄を持つ。生の入力には閉じた `Val` をそのまま使い、要求の五欄や不正な入力も構造のまま残す。文字列への変換を保存に使わない。`save_exact` は任意の Raw、全入力、全 snapshot、全失敗について九欄の等号を返す。

パターンの解析前は両 parsed 欄を none、対象の解析前は parsedTarget を none とする。解析に成功した欄だけを some にし、解決結果は snapshot による `resolveSnapshot`・`resolveTargetSnapshot` の結果と一致させる。none と some [] を区別し、secrets の全原子を保持する。既存の `checkAt` はすでに解析済み入力を受けるため、準備した元入力を持つ記録を同じ呼出しから渡す必要がある。

既存 AtError は Val より前にある。元の Val を保持するには、Raw に関して正の構造体を先に定義し、相互の構文の `Val.atError` に `Detail Val` を持たせる。台本の `Stored.error (Detail Stored)` がこの入れ子の正値性を型検査する。元入力は診断用の不活性な構文として保持し、閉じる処理が実行時に再評価しない。実行時に元入力を保存するのは `closeVal cap pattern/input` を各一回使う準備の入口である。捕捉前の変数番号を利用者の元入力として保存しない。

| 現在の生産箇所 | 不足・実装時に渡すもの |
|---|---|
| AtPrepare.prepareCore の pattern parse 失敗 | .top と空の絶対パスを代用している。閉じた元の二値を最初から保持し、parsed は none |
| 同じ input parse/ground/reqTarget の三失敗 | target を空パスで代用する。parsedPattern=some、parsedTarget=none と元の二値を保持 |
| bases の非Valid/別値、finishPreparation の拒否 | 成功済みの解析値は some のまま、元の値とその snapshot における解決結果を保持 |
| AtPrepare の rvar | .top と空パスを代用している。元の二値を保持し、解析に進んでいない欄は none |
| PathResolution.atDetail/checkAt の全8葉 | parsed 値だけを original としている。準備の記録の元入力と解析値を保って、同じ失敗と解決結果を入れる |

全失敗の生産箇所への実装は .20、全失敗と読者の照合は .53 である。この単位では本番の AtError・AtPrepare・checkAt・読者を切り替えていない。型検査した候補と、実装済みの保存を区別する。

全読者の所在と行番号は [reader-inventory.json](reader-inventory.json)、再生成は [reader-inventory.py](reader-inventory.py) に置く。検索語は `AtError`・`atError`・`atDetail`・`atErrorType`・`atErrorFields`・`atErrorPattern`・`Scope.ScopeError`・`textFields` と九欄の各名前、`reprStr` である。formal 全体の Lean ソースを走査し、.lake を除く。仮入力は AtPrepare と PathResolution の上表の箇所を別に読んだ。型だけを持ち回る読者も落とさない。

| 読者の族 | 追随する内容 |
|---|---|
| ScopeSyntax、Syntax | 型の位置、保存値、textFields、values、Val.toTerm? |
| AtContracts、AtTyping、Typing | 内部の七 String 観測の宣言・値の型付け。保存形そのものを String に戻さない |
| RuntimeMatch、AtPatterns、Patterns、MatchFacts、TypedFacts、PatternBindings*、CanonicalValues | 同じ textFields/values の観測、欄数、型付き照合、事実 |
| AtStateLeaves、StoreReplyLeaves、Semantics、Step | 同じ準備の元入力・失敗記録を三遷移へ渡す |
| Capture、Subst、LocalResolve、Ground、ReadLocalRefs、Source、SourceScope | 不活性な保存値を変更せず持ち回る扱い、ソースからの直接生成の拒否 |
| LegacyPattern*、LegacyEmbeddingExamples、ValueMeaning*、TypedMeaning、MeaningTransport、PatternNormalForm、StandardKeySound、CaptureApplicationAlgebra | 現行の七 String 観測を使う意味・消去・鍵・網羅性と、その代数 |

`AtError.textFields` の reprStr は現在は観測の生成に使われ、保存する元データの型は RangeExpr/TargetInput である。そのため「reprStr が保存値である」という一括した指摘はしない。ただし元の生入力の欠落を reprStr では補えず、公開 JSON や Show の契約にもならない。七 String の暫定内部観測の追随と、U02 による公開形への写しを別の作業として扱う。

U02 に依存する PathBases・At・ScopeError の公開名・署名・観測形は選択していない。公開への写しは U02 確定後・L70 前に取りまとめが割り当てる。表示の引用・エスケープ・4096バイト上限・secrets の要約は保存値とは分けて後段で照合する。旧 OutsideScope の構成子と内部の outsideScope を消さない。

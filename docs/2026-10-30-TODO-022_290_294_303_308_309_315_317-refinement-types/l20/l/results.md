# L20 群 L・M の結果


## 再開3: 独立レビューの軽い所見への対応

2026-11-02。[独立レビュー RV-L20.l](../../reviews/RV-L20.l.md) は可（重0、中0、軽6）である。本再開では軽1〜軽4と宣言の記録を直し、指定された公理の再検査と RSS の計測を行った。既存の言明・型付けの規則・公理を変更していない。本再開の修正に対する再レビューと受け入れは未実施である。

| 所見 | 処置 | 判定 |
|---|---|---|
| 軽1 | results・01-12・07-04 を修正。Closure.LocalRefs の Ξ はすべての閉包で捕捉元の Φ と関係付けられておらず、R/Rs/a/e の元の ClosureTy との一致と TypeAnnotations も条件に含まない。条件は、同じ捕捉の CaptureOk、ある経路条件の下の導出、コードと局所参照の解決の対応を持つ。経路条件・型注釈の一致は併せて持つ StateTyE の ClosureTy が持つ | 対応済み。定義と証明は変更なし |
| 軽2 | NormalReplyExamples.concrete_normal_replies を既定ビルドへ追加。同じ P・B・有効な σ で WellFormed・WellTyped・CoreAssumptions と四つの正常応答への store_reply の適用を同時に構成 | 四例すべて追加。残り0 |
| 軽3 | source_state が作るのは初期状態の StateTy であり、Ready と ExternalWF は入力をそのまま返すと明記。StateTy の σ.Valid も InitialPrepared.ready から取り出す。具体の準備の証明とは区別 | 対応済み。入口の言明は変更なし。準備の例の置き場所は CaptureReadBoundary のまま |
| 軽4 | audit-modules.txt と audit-declarations.txt を同じディレクトリへ保存。合計4,974 bytes。axioms.lean は既定でこの二つを読み、環境変数がなくても再実行できる | 対応済み。26モジュール・77明示対象。重複していた resume_all は HandlerGeneral の全定数列挙で引き続き検査 |
| 軽5 | 指定どおり公理検査を /usr/bin/time -l で包んだ。検査本体は終了0、計測器は sandbox の kern.clockrate 取得禁止で終了1。正式な最大常駐量は未取得。Python getrusage による補助値は別記 | 実行環境の制約を記録。補助値を正式値として扱わない |
| 軽6 | δ・IO・解放・外部の応答と捕捉の内部の形の観測を、処理系との接続の担当へ申し送る | 下記の確認点を記録。信頼条件の追加・比較対象の除外はしていない |

### 足した具体例

四例は一つの NormalReplyExamples の表を使う。プログラムには、引数なし・結果 Unit の外部関数一つと、At の結果と標準エラーの三構成子を置いた。組み込みの表には Reference.get/set の必須の署名、Unit を返す pure の署名、Unit を返す io の署名を置いた。sat と解放の応答は常に真、IO は対象のない一つの事象、外部の正常応答は Unit と空の対象列である。各応答の型付け・存在・種別、署名の形成、外部宣言と構成子の整形式、同じ表の WellTyped/CoreAssumptions を証明した。これらを独立の仮定で受けていない。

| store_reply の入力 | 具体の計算 | 実際の応答と結論 |
|---|---|---|
| E_Prim | Example.unit に引数なしで適用 | δ が正常値 Unit を返す。Step、返却後の StateTyE と LocalStateInvariant |
| E_IO | Example.ioUnit に引数なしで適用 | Unit を返し、対象列が空の IO 事象を一つ出す。同じ三つの結論 |
| E_External | 名目ID 0 の外部関数を型引数・値引数なしで呼ぶ | 正常応答 Unit が externalReceive の検査を通る。同じ三つの結論 |
| E_AtOk | snapshot なし、パターンと静的な範囲は絶対の Top、入力は文字列 `/` | AtPrepared と checkAt の成功を具体に証明。成功の構成子に、絶対パス `/` を表す checkedAt を返す。同じ三つの結論 |

従来の CaptureReadBoundary の具体の store_reply の適用は E_Err だけであった。今回の四例は別の表であり、既存のエラーの例・開始準備の例を変更していない。例の追加は、最初の時刻採取20:13:25から四例を含む既定ビルドまで1時間未満で終了した。この時間は外側の時間で、能動時間と待ちは分離していない。全実表の充足と処理系の実行との一致を証明したとはしない。

追加は41ソース宣言（定理25、定義16。private 40、公開の具体例1）である。signatures.md と宣言の集計を更新し、合計334ソース宣言（定理267、定義60、帰納的な条件7）になった。完全署名は97,971 bytesで100 KB以下である。新しい公開入口 concrete_normal_replies は、四例と同じ P・B・有効な σ の証拠を同時に結論する具体の適用例である。追加の仮定を持つ行先の型付けの葉は置いていない。

### 公理の監査の再実行

対象は [audit-modules.txt](audit-modules.txt)（1,193 bytes）と [audit-declarations.txt](audit-declarations.txt)（3,781 bytes）である。追加の NormalReplyExamples は全生成定数を含めて監査する。StateTyE.resume_all の明示指定の重複一つを除いたが、HandlerGeneral の全定数列挙で同じ宣言を検査している。監査の対象を除外したものではない。

リポジトリの formal/ から次で再実行できる。環境変数を省略しても、axioms.lean は同じ保存済みの一覧を使う。

```sh
l20_audit_dir=../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/l
L20_AXIOM_MODULES="$l20_audit_dir/audit-modules.txt" \
L20_AXIOM_DECLARATIONS="$l20_audit_dir/audit-declarations.txt" \
/usr/bin/time -l lake env lean -M 12288 "$l20_audit_dir/axioms.lean"
```

当環境では、/usr/bin/time -l が `sysctl kern.clockrate: Operation not permitted` を返した。初回と補助値を採った再実行のどちらも、Lean 本体は終了0、計測器は終了1であった。正式な time -l の最大常駐量は未取得である。補助値は、同じ time -l で包んだ再実行の内側で Python resource.getrusage(RUSAGE_CHILDREN) により取得した。原単位は macOS の bytes、対象は lake env lean と子孫の最大常駐量で、**1,739,063,296 bytes（約1.62 GiB）**である。本体と計測器の状態、正式値の欠落と補助値を分けて記録する。機械・構成は手元の arm64/macOS、Lean の -M は12288である。

公理依存は26モジュールの1,661定数と77の明示対象を印字した。依存あり1,242件、依存なし496件で、propext・Classical.choice・Quot.sound 以外は0件、sorryAx・新しい公理は0件である。ClosureTyping の既存のコンパイラ生成の再帰の定数二つも型と依存を印字した。二回の stdout は同じ bytes と SHA-256 であり、計測器の失敗を公理検査の失敗へ読み替えていない。

### 申し送り

閉包の構文の観測を許す抽象的な応答と、未使用の捕捉を刈り込む処理系の対応は、本段の型付きの値と専用セルの有効性とは別に扱う。接続の担当は、δ・IO・解放・外部の各実装が閉包の内部の形を読むかを照合し、捕捉の刈り込みを含む対応関係の証拠を供給する必要がある。この確認点の計画への配置は取りまとめに残し、本再開で新しい信頼条件・主な言明の変更・比較対象の除外を追加していない。


### 再開3の検査結果

既定ビルドは852 jobs、終了0。NormalReplyExamples の単独検査（lake env lean -M 12288）は最終の診断0件である。途中は閉性の簡約、外部 lookup/受信と At の暗黙引数で診断を返したが、元の具体の表と構文を明示して閉じた。前提・型付けの規則・公理の追加はない。

work の dry-run で仕様対応の自己検査・集計、仕様例、既定 Lean ビルドと sorry の拒否が選ばれることを確認した後、`scripts/check.sh --level work --base 2f2a27900721ad93b0189930359fc48f8c887db0` を --only なしで本再開の最後に一度実行した。終了0、外側3.739秒、仕様例7件が成功し、失敗・無視は0件である。

| 検査 | 本体の終了 | 計測器の終了 | 外側の時間 |
|---|---:|---:|---:|
| 既定 lake build（追加例を含む） | 0 | — | 未採取 |
| 公理依存 A-L（time -l） | 0 | 1（kern.clockrate の取得禁止） | 8.609秒 |
| 公理依存 A-L（同じ包み方＋getrusage 補助値） | 0 | 1（同じ理由） | 8.965秒 |
| 作業末の work | 0 | — | 3.739秒 |

[checks-resume3.json](checks-resume3.json) にコマンド・状態・時刻・入力のハッシュの記録、[logs-resume3.json](logs-resume3.json) に生ログの一覧の要約と大きさ・SHA-256 を置いた。公理の二回の stdout は4,261,667 bytes、SHA-256 は `46eee67fb87b1d98bbffd6b37bd8fea55a697f1ad88dc9c389a037823459ccb8`。work の stdout は5,757 bytes、SHA-256 は `1eb7cd866a9bb6b8ef8c64576c48d1b4e80709e18797fe5c0e9c24a7ff193792`。生の出力と大きな補助の集計は <tmp>、監査の小さな入力と[追加宣言の一覧](declarations-added.txt)は改造内に残す。

署名97,971 bytes、追加41宣言、既定 import の読者、監査の26モジュールと77明示対象、4,974 bytes の入力の保存と再実行方法を照合した。既存の言明・型付け・公理、plan/detail・レビュー記録・処理系・旧 Release は変更せず、git の操作は行っていない。最後の work の後に変更したのは結果と検査のメタデータだけである。正式な RSS の採取だけは上記の環境の理由で未取得であり、補助値と区別する。

## 再開2以前の記録

以下は各提出時点の記録である。現在の修正の判定は上の再開3を正とする。

## 再開2: 実行に使う範囲を確定した結果

2026-11-02。取りまとめが確定した範囲（専用セルの参照・更新、捕捉のコードを本体として実行すること）で点検を通過した。L20.110/.112 の残り、.113、.114 の当担当の証明を実装した。.106〜.109/.111 の当担当の証明を継承し、計9単位の当担当分を閉じた。これは L20 全体、全76遷移の保存・進行、表層から開始への合成、独立レビューと受け入れの完了ではない。

### 応答が型付けを経る経路

δ/IO と外部の応答は実行中の Store を引数に受け取らない。全76行の点検表の「ストアの参照・更新」「コードの実行」の二列を、この範囲で埋め直した。None の位置のコードが型付けを経ずに専用セルの操作や本体の実行へ入る経路は見つからなかった。表はソース点検の結果であり、全76遷移の保存の証明とは数えない。

| 入口・応答 | 実際に入る場所 | 型付けを経る根拠 |
|---|---|---|
| E_Prim / E_IO の val | 空の捕捉の ret v。その後の値束縛・セルへの格納・関数呼出しは既存の型付きの入口を使う | 元の app と捕捉から BuiltinArgs を構成。delta_typed/io_typed の Outcome.Typed が v の型と Ground を返し、AdequateResult は有効な同じ σ の下で適格性を返す。HasTypeVQ.localRefs は同じ値の条件を導く |
| E_Err / E_IOErr / E_Exit | error/exit の理由・終了値のみ | 捕捉や実行コードへ値を追加せず、同じ StoreOk/ContTy と閉性を使う |
| E_External の正常受信 | externalReceive が返した ret v | 元の C_External と CaptureOk から ExternalArgs を得る。三条件・ExternalWF・受信検査を使う received_value が型・Ground・全 σ の適格性を返す。carrier は closure や専用場所を実行コードとして返さない |
| E_ExternalErr | error の理由のみ | 応答値を捕捉・コードへ追加しない。正常値の存在を新しい前提にしない |
| E_AtOk | 結果の構成子に入る checkedAt と、必要なら元の request | 元の C_CheckAt・CaptureOk から閉じた要求の型を得る。AtPrepared.request の groundVal と端点、checkAt.sound の所属、固定した snapshot の一致から CheckedWitness を作る |
| E_AtError / E_AtPrepareError | 結果の error 構成子と atError | 元の結果の宣言・型の像を使う。準備失敗には元の固定添字、検査失敗には準備の固定添字を使う。応答から任意のコードは入らない |
| PathBases の発行 | ret (pathBases σ) | 実際の署名・kind・opEff と σ.Valid から V_PathBases を作る |
| E_Return / E_Lam / E_Force / 操作・resume | 保存した本体、閉包、thunk、節・保存継続 | 元の ClosureTy/DependentClosureTy、CellOk の thunk/cont、節の導出を使う。None の位置は V_Var の通常の像や呼び出す関数の導出を供給しない |
| 解放・drop・handler の pop | release/drop 枠だけ、又は残継続 | releases は保存継続の枠を走査するが、let/guard/handler の捕捉の値は実行しない。解放の応答は値やコードを返さない |

CaptureReadBoundary の場所7/8の例は残す。δ が番号を読み異なるエラーを選べることと、専用セルの参照・更新を実行することを区別する。hidden_capture_reply_states は、同じ具体表のこの二つの呼出しが同じストア・継続の型付けと新しい局所参照の条件へ戻ることを、公開した23遷移の読者により構成する。

### 導出が読む位置の条件

ReadLocalRefs は値・値列・計算・腕・節・捕捉の6判断を相互に定義する。LocalRef.Allowed は bound を深さ内、loc を同じ Ψ の builder の場所に制限する。HasTypeVQ/HasTypeCQ と相互判断の導出の構造から条件を導く。計算は元の局所文脈 L と CaptureLocals が指定する解決 ρ を用い、binder ごとに upLocalSubst と深さを進める。通常の値・閉包・lazy・節の境界では builder を隠した Ψ を使う。

Capture.LocalRefs は捕捉元の Γ・Φ と Transport を残し、Γ の some の通常値の像に値の条件を要求する。値の閉包の証人は同じ CaptureOk と TelBodyTy を持つ。実行の Closure.LocalRefs は、同じ捕捉の CaptureOk と、ある経路条件 Ξ の下の導出、および元のコードと局所参照の解決の対応を持つ。すべての閉包で Ξ と Φ は関係付けられておらず、R・Rs・a・e の元の ClosureTy との一致と TypeAnnotations もこの条件に含まない。経路条件・型注釈の一致は、併せて持つ StateTyE の ClosureTy が持つ。捕捉の Transport による Γ・Φ と述語の参照、および元の型付けの型注釈・snapshot の検査を用いることと、この局所参照の条件の証人を区別する。継続の像は通常値として検査せず、同じ StoreOk の cont セルと ContTy を使う。Capture.Closed と Capture.Adequate の全位置の条件はそのままである。

LocalInvariant は実行の閉包・guard 本体・ContTy10構成子・CellOk6形を接続し、四状態の StateTyE から LocalStateInvariant を導く。StateTyE.builder_live の結論は、現在の view の専用操作が指す場所に実際の builder セルがあることである。

| 対照 | 既定ビルドの証明 |
|---|---|
| None の位置に、空のストアの場所7を本体で指す閉包を保存し、外側は return Unit | 既存 hidden_slot_counterexample を残す。hidden_slot_read_localrefs は同じ状態が新条件を満たし、全位置を検査する SlotBuilderLive を満たさないことを示す |
| 空の捕捉から return Unit | 既存 empty_capture_accepts を残す |
| 場所7の専用操作の閉包を直接実行する | reject_executed_stale_builder は StateTyE を否定する。builder_live から空のストアにセルがあるという矛盾を得る |
| δ が7/8の番号を読んでエラーを選ぶ | 既存の読み取りの例を残し、hidden_capture_reply_states は両方の行先の StateTyE と LocalStateInvariant を示す |

### 単位と一般化した遷移

| 単位 | 当担当分の判定 | 実物と範囲 |
|---|---|---|
| L20.106 | 完了を継承 | 使用済みの再開は error、任意値と未使用の保存継続の再開は J の一般の葉。resume_const を全場合へ読み替えない |
| L20.107 | 完了を継承 | 任意値の正常/escape の used/cont の破棄、error/exit の used と解放付きの破棄 |
| L20.108 | 完了を継承 | use、全資源値の解放の存在、正常/escape/error/exit の解放の成功・失敗、handler の error/exit の pop |
| L20.109 | 完了を継承 | EffectsOk と State の含意、継続末尾への所属・対象の被覆と解放枠。effect/target の主定理の合成は L70 |
| L20.110 | 完了 | 既存の builder3葉と全セル応答に、元の導出と CaptureLocals から得る条件、StoreOk.builder_places と builder_live を接続 |
| L20.111 | 完了を継承 | finite/domain/WF/Sorted/Declared・空き場所・汎用更新と割当て。既存の Reference/Lazy/cont の移送を引用 |
| L20.112 | 完了 | 継続の末尾・framesOk/drop_releases に加え、閉包・guard・10継続・6セル・四状態の局所参照の条件を接続 |
| L20.113 | 完了 | Reference4遷移、Lazy6遷移。新しい一般の葉は任意の捕捉の new/get/set/update/force-done/force-thunk/書戻しの7本。Lazy の作成・error/exit の更新枠の破棄の3本は既存の一般の葉を使う |
| L20.114 | 完了 | δ/IO5、外部の適用・正常/エラー3、At3、PathBases2の計13遷移。元の導出から型・行の像を得る。InitialPrepared とソースの型付けから同じ初期状態の StateTy を構成。Ready と ExternalWF は入力をそのまま返す |

Reference.update は任意の型付き関数値を受け、closure に限定しない。遷移の行先の get/set は元の生の ts を使う。元の V_Prim の SignatureInstance と kind・注釈からそれを型付ける補助を作り、既存の一般の reference_update_body を使った。ClosedRename の5相互成分は任意の Ground な値の rename と深さの拡張を扱う。行先の型付けを仮定していない。

応答の正常値の葉では、元の StateTyE と WellFormed・WellTyped・CoreAssumptions を使う。δ/IO の正常値と At の成功には σ.Valid も使う。これは StateTy に含まれる前提であり、新しい信頼条件ではない。エラーと exit の葉は値を入れず、規則の実際の条件と元状態だけを使う。At の失敗は元の C_CheckAt の宣言と結果の像を使う。外部の正常値の適格性は受信の三条件から全 σ で得る。前提の違いは署名と01-12/07-04の表に分けて記した。

StoreReplyInputs は、これら23構成子の同名の Step のソース入力を束ねる補助である。store_reply は実際の Step と行先の StateTyE/LocalStateInvariant を構成し、各公開の葉の本番の読者となる。InitialPrepared.source_state が作るのは StateTy であり、Ready と ExternalWF は入力をそのまま返す。StateTy の σ.Valid も InitialPrepared.ready から取り出す。初期状態の source_state の読者は prepared_unit_source と prepared_unit_concrete である。後者は有効な σ も具体化する。同じモデルの WellFormed・WellTyped・CoreAssumptions・空の ExternalWF・初期準備・StateTy を同時に構成しており、表の条件を満たせるかを独立の未証明の仮定にしていない。この具体表は検査のためのモデルであり、全実表の充足や IO/外部の応答の存在の証明ではない。

### 義務を一行ずつ判定

担当分を判定する。義務全体の後段は残る。

| 義務 | 再開2の判定 | 後段と限界 |
|---|---|---|
| O003 | 当担当分を接続。元の導出・捕捉・型/行の像と局所参照の解決、10継続・6セルの条件を証明 | 全位置の条件は採用しない。表層と全76葉の対応は .115/L40/L70 |
| O007 | 当担当分を接続。任意の型付き値の Reference への格納・読出し、正常形と生の型引数の update を扱う | Reference の現在の内容と snapshot の事実の同一視はしない。算術/δ の実表は L40/L50 |
| O008 | 当担当分を接続。元の CaptureOk/ClosureTy から任意の値とコードをストア・継続の同じ σ/Eb へ接続 | L40 の残る開始逆転と L70 の主定理の合成 |
| O038 | 当担当の全セル・継続・Reference/Lazy・応答を接続。23葉の読者は実 Step も返す | 全76遷移の保存・進行、実表は .115/L40/L50/L60/L70 |
| O051 | .106〜.109 を継承し、.110〜.114 でも元の注釈と像を供給。強い Ctx.WF、行先の型付けを追加しない | 後続の一般の読者と主定理の合成 |
| O058 | 任意値のストアと継続・固定 Eb、依存する型/行の像を当担当の葉へ接続 | L70 の全保存 |
| O065 | sig_scoped と応答の既存の契約を使用。開始準備を同じ初期状態へ接続 | 実表の充足・旧埋め込み・表層の開始合成は各担当 |
| O159 | 同じ具体 P/B で三 WellTyped 等の条件と準備・StateTy を同時に構成 | 表層からの供給と L70 の切替 |
| O016 | 公理依存 A-L を新しい全モジュールと従来の明示対象へ再実行 | 検査の件数・許可公理は下の記録。主定理と独立レビューは後段 |
| O084 | 当担当9単位と後段を分け、代表と一般の葉、二つの旧停止の記録を残す | 独立レビュー・受け入れと群全体の取りまとめは未実施 |
| O027 | arm64/macOS 27.2。RSS は本体と計測器とも未取得、引用なし。作業の開始・能動/待ちの分離採取もなし | 段全体の測定や後段の未取得を埋めた扱いにしない |
| O118 | コメントは役割・規則・証拠の説明とし、作業ID・手元の絶対パス・docs/todo へのリンクを加えていない | 全L共通の受け入れは取りまとめ |

### 完了条件の照合と計画との差

[signatures.md](signatures.md) は各まとまりを実装前に記録し、最終の実物とそろえた完全署名・定義の一覧である。再開2で118宣言を加え、初回・再開1と合わせて293ソース宣言（相互定理の全成分を別々に数える）。242定理・44定義・7帰納的な条件、private は151宣言である。正確な内訳は declarations.json の最終値を正とする。帰納的な条件の構成子とコンパイラ生成定数はこのソース宣言数と別であり、公理監査では生成定数も列挙する。

公開した入口には、各相互証明・ストアと継続の読者・23遷移の読者、又は具体の適用例がある。hidden_slot_read_localrefs と reject_executed_stale_builder、既存の空の捕捉との対照は同時に既定ビルドに含む。未使用の hq の前提を内部の返却値の補助から取り除き、成功/エラー/終了で前提を分けた。sorry・新しい公理・新しい信頼条件・型付け規則・ValueMeaning・主な10言明の変更、既定 import の除外はない。plan/detail・レビュー記録・処理系・旧 Release・git の操作は行っていない。新しい行の支持や kind の欠けは見つからなかった。

計画上の配置からは、相互の局所参照・閉じた rename・応答・At・外部・開始準備と23遷移の読者を、StateLeaves から役割ごとのモジュールへ分けた。既定 import に全て含める。内部の update_body の署名の内容は変えず、任意値・生の型引数で再使用するため公開名を reference_update_body にした。二つの過去の停止は、取りまとめの案1と再開2の範囲確定に従って解消した。新しい停止や提供範囲の縮小はない。

4時間の条件に備える区切りの既定ビルドを、局所参照・ストア・各応答の接続ごとに通した。初回の点検開始、能動時間、待ちは分離採取していない。今回最初に採取した時刻19:21:37（JST）は作業開始時刻ではない。定義・言明・仮定の独立レビュー、受け入れ、Rust/Lean の全比較は未実施である。L60 の外部応答の存在と L70 の表層から開始への合成は担当へ残す。


### 再開2の検査結果

既定の lake build は851 jobs、終了0で成功した。新しいモジュールの単独検査は lake env lean -M 12288 を用い、最終の診断は0件である。既存の ClosureApply 等の warning とリンク時の既存の警告は既定ビルドで再表示される。新しいモジュールの最終の warning は0件である。

work の dry-run は仕様対応の自己検査・集計、仕様例、既定 Lean ビルドと sorry の拒否を選んだ。その内容を照合した後、`scripts/check.sh --level work --base 2f2a27900721ad93b0189930359fc48f8c887db0` を --only なしで本再開の最後に一度実行した。仕様例は7件成功、失敗0、無視0である。Rust 本体・依存は変更せず、work の自動選択に従った。

| 検査 | 終了 | 外側の時間 | ログの bytes | SHA-256 |
|---|---:|---:|---:|---|
| 既定ビルド | 0 | 1.463秒 | 42,831 | `91b0a810e1b3fd03034d9c156c964001ee759ceaf97f988b9fe91a274c0573c7` |
| 公理依存 A-L | 0 | 8.415秒 | 4,155,390 | `c64ffe65af595a477f8c7a5c565e9768fb6af6d3ec2b9e7fd7b69feb57d6915c` |
| work の選択 | 0 | 0.115秒 | 759 | `dd863c2ce24b4262390b18f65cbd2b628c17b72bc5f519e419c65bc39e1ccfe0` |
| 作業末の work | 0 | 3.791秒 | 5,757 | `598d78664a7d0338ba2c050048cfd1e33e1074ee3a4a0706d969e367ddec90da` |

公理依存の監査は25モジュールの1,513定数と従来の78明示対象を印字した。依存の印字は1,163件、依存なしは428件で、propext・Classical.choice・Quot.sound 以外は0件である。ClosureTyping の既存の Tel.effect/Tel.result のコンパイラ生成の再帰の定数二つは、型と公理依存を印字した。新しい公理・sorryAx・source の unsafe/partial はない。A-L の共通台本は1,903 bytes に縮め、対象の完全名の一覧は <tmp> に置いた。監査の要約と一覧の大きさ・SHA-256 は [audit-summary.json](audit-summary.json) に残す。

[checks-resume2.json](checks-resume2.json) は今回の完全なコマンド・実行時刻・終了値・外側の時間と、入力の生の一覧の大きさ・SHA-256、[logs-resume2.json](logs-resume2.json) は全61ログの要約と生の一覧の大きさ・SHA-256 を記録する。過去の checks/logs と全76行の補助JSONも、生の一覧を <tmp> に置き、改造内を要約へ縮めた。現在の76行の表は results の本文に残す。

途中の単独 Lean は、名前解決・捕捉と型引数の等号・閉性の構造帰納・mutual 定義の簡約と従属射影・構成子の引数で診断を返した。前提の追加や規則の変更で穴を隠さず、元の導出の証拠と等号を明示して修正した。集計台本には検査の結果を保存した後の変数名の誤りもあり、実際の検査の終了0と集計台本の例外を区別して記録した。修正後の work の呼出しと実検査はいずれも終了0である。

完全署名は90,530 bytes、293ソース宣言で100 KB以下である。署名と全ソース入力のハッシュ、既定 import、禁止宣言、76行の集合、23構成子と Semantics.Step の前提・行先の一致を作業末の前に照合した。最後の検査の後に変更したのは結果・検査のメタデータだけであり、証明・例・型付けの規則・設計書の本文を変更していない。

| 残る手順 | 見込み |
|---|---|
| 当担当の定義・言明・仮定の独立レビューと指摘への対応 | レビューの待ちと指摘の量によるため不明 |
| .115 の全76葉との対応、L40/L50/L60 の供給、L70 の主定理と表層の開始の合成・段の検査 | 各担当の計画による。今回の完了へ算入しない |
| 取りまとめと設計者の受け入れ | 所要時間・待ちは不明 |

## 初回・再開1の記録

以下は各提出時点の記録である。現在の判定は上の再開2を正とする。

### 初回提出

2026-11-02。**L20.112 で停止した。L20.106〜.109 と .111 は当担当の範囲を実装し、.110 の三つの状態の葉と .112 の継続の補題は証明した。捕捉の全位置の局所参照の接続は閉じていない。L20.113・.114 は未着手である。** 停止条件に従った提出であり、群 L・M 全体の完了や受け入れを意味しない。

| 固定した入力 | 値 |
|---|---|
| ブランチ | 依頼の `m014/l20.l`。切替・作成・コミットをしていない |
| B_WORK | `2f2a27900721ad93b0189930359fc48f8c887db0` |
| 前提 | 共通依頼文、detail の S04・S05・S10 と分担・義務、plan の停止条件と Closure.view の判断、F・J の引継ぎ、RV-L20.j の末尾 |
| 勧告 | 共通依頼文の既存の照合と判断を継承。依存とツールチェーンを変更していない |
| 完全署名 | 初回は150宣言・33,642バイト。再開1は25宣言を加え、[signatures.md](signatures.md) は計175宣言・36,703バイト（100 KB以下）。新規174、内部の既存署名の変更1。内訳とSHA-256は [declarations.json](declarations.json) |
| 変更しない対象 | plan・detail・レビュー記録・処理系・旧 Release の実装は編集していない。ValueMeaning、型付けの規則、主な10言明、新しい信頼条件を変更していない |

## 停止の内容

[停止票](stop.md)に、定義・導けない正の言明・現在の前提との差・具体の反例と対照・代案・見込みを記した。None の捕捉位置に任意の Ground な値を保存できるため、存在しない builder の場所7を本体で参照する閉包も残せる。外側を return Unit としストアと継続を空にすると、任意の P・B・σ について StateTyE を構成できる。その全位置を調べる LocalRefs に必要な一段の条件 SlotBuilderLive は成り立たない。空の捕捉と同じ返却本体では両方が成り立つ。

反例と受理側は既定 import の `HiddenCaptureBoundary.hidden_slot_counterexample`・`empty_capture_accepts` で証明した。型付きの実行の保存の反例とは数えず、表層からの到達性も主張しない。slot の範囲を無断で変えず、CaptureOk 等を強めず、残る場合を正の定理として宣言していない。新しい行の支持や kind の欠けは確認していない。

## 単位の判定

| 単位 | 判定と証拠 |
|---|---|
| L20.106 | 完了。既存の任意入力の resume_used を引用し、resume_used_concrete が List 値の元状態から使用済みのエラーへ適用する。resume_const は全場合の証拠にしない |
| L20.107 | 完了。drop_used_all・drop_release_all・escape_drop_used・escape_drop_release、error_drop・exit_drop と既存 err_drop_rel・exit_drop_rel で8形を扱う。元の R と末尾の Eb、保存継続の解放の順、場所型を使う。drops_concrete と exceptional_drops は全ての入力の型付けを構成する |
| L20.108 | 完了。use_all、return_release・escape_release と各 failure、error/exit の release と failure、error_handler・exit_handler を元状態から構成する。release_response_exists は既存 release_exists の全資源値の量化を使う。解放の失敗で既存の error 列の末尾へ理由を加える。resource_existence_and_effect・exceptional_pops・release_returns・use_concrete が具体の読者 |
| L20.109 | 当担当分完了。既済み Handle/HRet/Op/OpFail/OpPrim/Resume と、既存 ResumeErr、8形の drop、2形の handler の pop の17遷移を区別した。EffectsOk.noStateHandled と state_effect を再使用し、name_end_ix が非 handled の同名の原子の被覆を末尾へ返す。framesOk/drop_releases の State の含意にもつなぐ。L70 の全 effect/target の合成は未実施 |
| L20.110 | 一部。builder_new・builder_operation・builder_error の三つの実際の行先を証明。String/List/Bytes の全操作の成功応答の型・上限・Byte の範囲、実際の引数の closeVals、元コードと実行コードの交換、局所参照の CaptureLocals の再構成、束縛を除く閉性と適格性は済み。捕捉の全位置を調べる局所参照の閉鎖は .112 の停止票に残る |
| L20.111 | 完了。StoreGeneral の write_cell・allocate_cell・fresh・set_cell と有限性の補助。finite/domain/WF/Sorted/Declared と全セルを保つ。allocate_reference・allocate_lazy・allocate_continuation は既存のものを引用し、再実装していない。新しい追加セルの CellOk は呼出し側の構築器の空のセルと具体例で構成している |
| L20.112 | 一部。ContTy10構成子の name_end_ix・mono_end と FramesOk・framesOk・drop_releases は証明済み。ContTy.store と CellOk.store は再使用。Frame/Cont/Cell の捕捉の全位置への LocalRefs の接続で停止。正の未証明の定理や独立前提を追加していない |
| L20.113 | 未着手。.112 の停止により、任意の closeVal と Reference4/Lazy6 の接続は行っていない。既存の葉が残ることと一般化の完了を区別する |
| L20.114 | 未着手。BuiltinArgs・ExternalArgs・AtPrepared のソースからの接続、InitialPrepared/ready と固定 σ・ExternalWF の開始準備への合成は行っていない。外部応答の存在は L60、表層から開始への合成は L70 に残す |

## 定義・言明・前提と読者

新しい7モジュールを既定の Benitoite の import に追加した。既存の ClosureTyping と HandlerGeneral を変更し、旧 Release の主定理とモデルの import は保った。

| モジュール | 追加又は変更した役割と読者 |
|---|---|
| HandlerGeneral | 新24宣言。任意の通常返却・escape の導出を C_Sub/C_Normal/C_Eff を通して閉じ、drop・use・release の状態を構成する。例は HandlerStoreExamples |
| ClosureTyping | 既存 builderBody_image から強い Ctx.WF を除く。非通常かつ生の cont でもない型は既存 ImageOk.hidden を使う。BuilderStateLeaves.builder_new が使用 |
| RuntimeBuilderScope | 新11宣言。WFImages、型・行と局所参照の範囲、値・値列・計算・腕・節の閉性と Adequate の相互証明。Comp の成分は builder_new が使用し、残る相互成分も帰納内の読者を持つ |
| StoreGeneral | 新5宣言。任意のセルの更新と追加、finite/domain と三条件、空き場所、ストアの閉性。構築器の葉と具体例が使用 |
| BuilderValueTyping | 新11宣言。全操作の成功応答の内容型・返却値・上限・Byte の範囲と閉性・適格性。builder_operation が使用 |
| BuilderStateLeaves | 新18宣言。元の source の導出と CaptureOk を ClosureTy.open_zero から取り出し、ClosureViewTy に保持するものと同じ証拠で kind/型/行の像を得る。全3葉は具体例へ適用。行先コードを型付けの前提にしない |
| ContinuationGeneral | 新8宣言。name_end_ix・mono_end と全解放枠の条件。framesOk は drop_releases に、他は具体例に読者がある |
| HandlerStoreExamples | 新62宣言。表の条件と元状態を全て構成し、List 値、used/cont、通常/escape/error/exit、解放の両応答と理由の順、三種類の構築器の割当て、String の copy、List の上限超過へ適用 |
| HiddenCaptureBoundary | 新10宣言。閉じない全位置の条件の反例と受理側。SlotBuilderLive は全 LocalRefs の採用定義ではなく、その全位置版に必要な一段の条件 |

元状態を逆転する葉には、行先コードの型付けを仮定するものがない。構築器の成功操作の型と kind の像は、C_BuilderOp を含む元の導出と CaptureOk/CaptureLocals から得る。builder_new に WellFormed・WellTyped の不要な前提を加えていない。正常値・escape を閉じる葉が受ける WellFormed・WellTyped・CoreAssumptions、解放付き drop の EffectsOk、その他の error/exit の元状態と応答だけの入口は signatures で分けた。

具体例の modelProgram・modelBuiltins は、WellFormed・WellTyped・CoreAssumptions・EffectsOk を同じ表で証明する。sat と releaseResponse は常に真、isResource は常に true という弱い表であり、実際の表での L50/L60 の充足ではない。外部応答の存在をこの表で空虚に満たすことを、L60 の完了に数えない。上限の List は記号的な長さで証明し、実行による大きな列の生成や性能測定を行っていない。

旧 HandlerPreservation の定数返却の handler_return_const・drop_used_const・resume_const・drop_rel_const・esc_drop_rel_const と HandlerOperation.operation_one は代表として残る。任意値の葉との区別を01-12・07-04の写しにも反映した。既存 resume_used・err_drop_rel・exit_drop_rel の一般性はそのまま使う。

## 義務の一行ずつの判定

判定は今回の担当分であり、L20 全体や後段までの閉鎖ではない。

| 義務 | 今回の判定と証拠 | 残り |
|---|---|---|
| O003 | 一部。builderBody_resolve と CaptureLocals の像、汎用ストアと K_Sub を含む継続の末尾の補題を接続 | 捕捉の全位置を検査する LocalRefs は停止票。表層の読者は L70 |
| O007 | 未実施。.113 の Reference/Fail の正規化後の等号の格納・読出しへの接続を今回閉じていない | .113、L40 の逆転と δ |
| O008 | 一部。任意値の drop・use・release、構築器の三葉を元捕捉の同じ σ/Eb へ接続 | 全位置の局所参照、Reference/Lazy、δ/At/external、L40/L70 の合成 |
| O038 | 一部。handler の残り、全解放の応答、builder の全3葉、汎用 StoreOk と継続の末尾を証明 | 全位置の局所参照、.113/.114、L40/L50/L60/L70 |
| O051 | 当担当の .106〜.109 は完了。元の注釈・CaptureOk と ContTy から必要な型・戻り先を供給。強い Ctx.WF や戻り先の注釈を独立に追加していない | 他の状態の使用先と L70。全位置の LocalRefs の不足は O003/O038 と停止票に分ける |
| O058 | 一部。任意値の handler の残り、ストアの拡張と builder、K_Sub と同じ Eb の全解放枠を接続 | 全位置の局所参照、Reference/Lazy と応答の接続、L70 全保存 |
| O065 | 既済みの sig_scoped と三条件の定義を継承し使用。今回新しい移行を完了したとはしない | .114 の開始準備、実表と旧埋め込み・L70 は各担当 |
| O159 | 三 WellTyped の定義を継承。具体のプログラムで WellFormed・WellTyped と表の条件を同時に構成 | InitialPrepared と開始の合成は .114/L70 |
| O016 | 当担当の監査を実行。許可された三公理だけ。既存 ClosureTyping のコンパイラ生成の再帰の定数二つも省略せず印字 | 主な定理の合成と独立レビューは後段 |
| O084 | 既定新旧 import、成功した葉、停止した未証明の場合、独立レビューと受け入れを区別 | 群全体・全体系の受け入れは未完 |
| O027 | 記録済み。arm64/macOS 27.2。RSS は本体・計測器とも未取得（部分作業では計画上の非採取）、引用なし、単位は該当なし | 他段の未取得を埋めた扱いにしない |
| O118 | 新しい Lean コメントに作業 ID はない。役割・規則・不変条件の説明を使用 | 全 L の共通の最終点検は取りまとめ |

## 検査

既定の `lake build` は839 jobsで成功した。対象を絞った lake build や既定 import の除外はしていない。単独の Lean は全て `lake env lean -M 12288` を使った。直近の単独検査では追加した各モジュールの診断は0件である。既定ビルドには既存の warning の再表示がある。

途中の局所検査の初回の失敗と修正も [logs.json](logs.json) に対応する生出力へ残した。HandlerGeneral は暗黙の局所文脈と resolveLocals の等号、RuntimeBuilderScope は WFImages の型注記と束縛下の添字、BuilderValueTyping は成功応答の等号と候補の内容の型注記、BuilderStateLeaves は closeTy/closeEff の展開と内部の像の推論を修正した。具体例は元状態の暗黙の R/効果、純粋な構築器の kind の正規化、ストアの上書きの等号を明示した。HiddenCaptureBoundary は Unit と空のストアの引数を明示した。いずれも最終の単独検査と既定ビルドで再確認し、型付けの規則や期待する行先を変更する修正はしていない。

作業末のコマンドは `scripts/check.sh --level work --base 2f2a27900721ad93b0189930359fc48f8c887db0`。終了0、8.342秒。--only は指定していない。仕様例7件、参照集計の自己検査と集計、既定 Lean と sorry の拒否を含む。

| 検査 | 終了 | 外側の時間 | ログの bytes | SHA-256 |
|---|---:|---:|---:|---|
| 公理依存 A-L | 0 | 3.914秒 | 1,586,672 | `c3d0dc8c143276d07cc3065f298432c1f61a5ea26559477b06364562d04bef10` |
| work の選択 | 0 | 0.114秒 | 759 | `a7b232e76732b13f678cd7bdf4754fd1c20442617824eea14a21a13ae8db3032` |
| 作業末の work | 0 | 8.342秒 | 5,757 | `d01023b0050623e97616d3033c74b6950b29289bb44fc2f2fae4b963aadad354` |

コマンド・開始終了・ログの名前は [checks.json](checks.json)、全中間ログの大きさと SHA-256 は [logs.json](logs.json) に置く。生の出力は全て `<tmp>` に置いた。最後の単独の既定ビルドの外側の時間は未採取（計測ラッパーを置いていなかったため）であり、work 全体の外側の時間とは区別する。約4時間での途中報告の条件には達していない。読取りの開始からの能動時間と待ち時間は分離採取していない。署名初稿の作成は17:06:59（JST）であり、最初の読取りの開始時刻ではない。

A-L は既定 import にある12モジュールの生成宣言を含む758定数と、旧モデル・旧主定理・実際に使う定義の明示した印字を対象にした。[audit-summary.json](audit-summary.json) は許可公理 propext・Classical.choice・Quot.sound だけで、sorryAx と新しい公理は0件である。初回と二回目は、既存 ClosureTyping のコンパイラ生成の Tel.effect._unsafe_rec・Tel.result._unsafe_rec を一律に unsafe/partial として拒否して終了1だった。この二つは source の partial/unsafe の追加ではなく、既存の全域定義のコンパイラ生成物である。最終の台本はその名前を記録し、他と同様に型と公理依存を全て印字する。宣言やモジュールを監査から外していない。二つとも isUnsafe=false・isPartial=true と記録される。最終の終了0とこの区別を、二回の失敗を消さずに残した。

テストの作成時の関門は、形式化した StateTyE/Step の状態の葉を境界にした。捕捉された通常値、used/cont、解放の成功/失敗と理由の順、場所型の保持、構築器の種類と上限を不変条件として検査する。定数だけの既存代表では List 値への接続と全 error/exit の行先を確かめないため、同じ具体の表と状態の構成を共有した。差し込み口・実行のためだけの本番コードは追加していない。捕捉の全位置の条件は、実際の反例と空捕捉の受理側を対にし、実行の保存の反例と取り違えない。新しい7モジュールは1,527行、HandlerGeneral は370行増、ClosureTyping は Ctx.WF の不要な前提と枝の整理で変更した。テストや旧代表は削除していない。

署名と150宣言の一覧、9ファイルの大きさ・SHA-256、既定 import、記録の相対リンク、手元の絶対パスと新しい作業 ID のコメントを自己点検した。検査後に変更したのは結果と検査のメタデータであり、証明・例・規則は変えていない。

## 計画との差と受渡し

L20.112 の全位置の LocalRefs の読み取りで止まり、.113 と .114 は実装していない。builder の三葉の成功を、全セル・捕捉・開始準備の結果にしていない。S05 の元の導出を ClosureTy.open_zero から取り出して構築器の kind・型・行像を証明したが、externalCall・checkAt の取り出しは未実施である。

構築器の実行コードの閉性と適格性、全操作の成功応答、具体例と停止の境界を、主なモジュールに加えて RuntimeBuilderScope・BuilderValueTyping・HandlerStoreExamples・HiddenCaptureBoundary に分けた。これらも既定 import に含む。builderBody_image の内部署名は依頼が認める範囲で Ctx.WF を除いた。署名の初稿をまとまりごとに先に置き、検査中の内部の型注記・未使用の引数・ストア型の一般化を最終の署名へそろえた。

01-12 と07-04の写しは、実際の葉ごとに前提を分けて更新し、変更の経緯を加えていない。既存代表の位置づけと、現行 StateTyE が全捕捉位置の専用参照の有効性を結論しない事実も書いた。停止後はこの検査・適用例と文書の整合だけを行った。独立レビュー、設計者の受け入れ、Rust/Lean の全比較は未実施である。

| 残る手順 | 担当・見込み |
|---|---|
| 全位置又は参照する位置という対象範囲、完全署名と供給元の判断 | 取りまとめ。停止票の候補を読む。所要時間・待ちは不明 |
| 定義と署名の短い点検、必要な計画・規則の見直しの判断 | 設計者と取りまとめが範囲を確定してから。最初30〜60分の案、全体不明 |
| 残る証明・既定ビルド・公理依存・作業末の work | 指定し直した担当。未確定の範囲なので全体の見込みは不明 |
| 定義・言明・仮定の独立レビューと受け入れ | 取りまとめと設計者。所要時間・待ちは不明 |


## 再開1: 全76遷移の捕捉の読取りの点検

2026-11-02。取りまとめは plan の先頭の判断で案1を採用し、実行が導出の読まない捕捉位置の値を読む場合は止める条件を指定した。本再開はその条件に従って、Semantics.Step の76構成子と補助操作を点検した。下表はソースの点検の結果であり、全76遷移について読まないことを証明した一般定理ではない。実際の読取りの反例だけを Lean で再現した。構成子名の集合と表の集合に過不足はない。入力のサイズ・SHA-256 と行番号は [capture-read-audit.json](capture-read-audit.json) に残す。

### 点検の結論と停止の範囲

E_Err は、型付きの実引数の閉包を δ へ丸ごと渡す。δ の契約は結果の型付け・no-exit・適格性であり、実引数の閉包内の捕捉を読む範囲は制限しない。具体の表の `hiddenTag` は、実引数の閉包の捕捉位置0にある閉包のコードから builder の場所の番号を取り出し、7なら HiddenBuilder7、それ以外なら HiddenBuilderOther を返す。元の Γ は [none]、Φ は空、外側の閉包の本体は return Unit、型注釈は閉じた Unit の依存列である。Γ・Φ・型注釈・snapshot の参照を数えても、この位置を読む導出はない。

[CaptureReadBoundary.lean](../../../../formal/Benitoite/Release/Refinement/CaptureReadBoundary.lean) の `primitive_reads_hidden_capture` は、以下を同時に結論する。

| 項目 | 証拠 |
|---|---|
| 同じプログラムと組み込みの表 | WellFormed・WellTyped・CoreAssumptions を全て構成。独立の仮定として受けていない |
| 実際の組み込み | Example.inspect は、引数に零引数の Unit を返す関数を一つ受け、Unit を返す pure の署名。Reference.get/set の必須の署名も構成 |
| 捕捉元 | 場所7版と8版の双方の CaptureOk を、Γ=[none]・Φ=[] で構成 |
| 元状態 | 双方の StateTyE を、空のストア・継続、同じ固定 σ・Eb=empty で構成。表層からの到達性は前提にも結論にも加えていない |
| 読取りの影響 | 二つの実引数に対する δ の応答が異なることを結論 |
| 実行の遷移 | E_Err の実際の行先が、それぞれ error [HiddenBuilder7] と error [HiddenBuilderOther] になることを結論 |
| 応答の契約の充足 | δ は常に error を返すので、結果の型や適格性を破らずに番号を読める。型付き入力が存在する実呼出しを構成しており、pure の署名がないことによる空虚な充足ではない |

この例で「実行に使う」としたのは、局所参照の番号の読取りが遷移の行先の選択に影響することである。δ にストアは渡されず、存在しない builder セルの参照・更新を実行する反例は示していない。新しい LocalRefs の有効性自体が偽であるとも、型安全性や主な10言明が偽であるとも結論していない。取りまとめの判断と再開依頼が求めた、未使用位置の値を実行が読まないという点検条件がそのままでは成り立たないため、ここで止めた。

### 全遷移の点検表

再開2の二列は、取りまとめが確定した専用セルの参照・更新と捕捉されたコードの実行だけを対象にする。既存の構文読取りの列とは区別する。76件の名前の集合を Semantics.Step と照合した。

「直接の全位置走査なし」はその構成子と明示した補助操作の読取りについての判定であり、受け渡した値を後の抽象的な応答が読まないという意味ではない。

| 遷移 | 構文の読取り（再開1） | 読むもの・渡すもの | ストアの参照・更新（再開2） | コードの実行（再開2） |
|---|---|---|---|---|
| `E_BuilderNew` | 直接の全位置走査なし | view は kind を閉じる。本体への builderValueSubst と builderLocalSubst はコードを置換し、元の捕捉はそのまま渡す。 | 新しい builder セルへの割当て | 元の型付き本体を専用場所で置換 |
| `E_BuilderOp` | 直接の全位置走査なし | view が閉じた引数と明示した局所場所を使う。builderApply は内容と引数を扱い、閉包の捕捉を走査しない。 | 明示した専用場所の読出し・更新 | 新しい本体の実行なし |
| `E_BuilderErr` | 直接の全位置走査なし | view が閉じた引数と明示した局所場所を使う。builderApply は内容と引数を扱い、閉包の捕捉を走査しない。 | 明示した専用場所の読出し | 新しい本体の実行なし |
| `E_Let` | 直接の全位置走査なし | 同じ捕捉を計算と let 枠の本体へ渡す。値の内容は取り出さない。 | なし | 元の型付き計算。後続は let 枠の ClosureTy |
| `E_Return` | 直接の全位置走査なし | view の返却値を let 枠の Closure.apply で前置する。既存の捕捉位置は走査しない。 | なし | let 枠の ClosureTy の本体を適用 |
| `E_Lam` | 直接の全位置走査なし | view の関数と引数を使い、arity を照合して body.apply で前置する。渡された閉包の捕捉は保持する。 | なし | 型付き関数値の DependentClosureTy の本体を適用 |
| `E_ExternalApply` | 直接の全位置走査なし | view の externalRef と引数を pure の externalCall へ渡す。 | なし | 型付き externalRef から externalCall を構成 |
| `E_External` | 外部の応答へ値を渡す | view の実引数を externalResponse と externalReceive へ渡す。宣言 lookup・キャリア検査と応答の型の契約を使う。捕捉配列は遷移で直接走査しない。 | なし | 受信検査後に型付く返却値だけ。carrier は実行コードを返さない |
| `E_ExternalErr` | 外部の応答へ値を渡す | view の実引数を externalResponse と externalReceive へ渡す。宣言 lookup・キャリア検査と応答の型の契約を使う。捕捉配列は遷移で直接走査しない。 | なし | 新しい本体の実行なし |
| `E_PathBasesApply` | 直接の全位置走査なし | 署名と NoHandler を照合し、同じ捕捉を issuePathBases へ渡す。 | なし | 閉じた署名の issuePathBases を構成 |
| `E_IssuePathBases` | 直接の全位置走査なし | 署名・固定 σ.Valid を照合し、σ の token を返す。捕捉値は読まない。 | なし | 新しい本体の実行なし |
| `E_AtOk` | 直接の全位置走査なし | raw code の指定した bases/pattern/input と errorType を AtPrepare/closeVal/closeTy で閉じる。snapshot と固定 σ の一致を照合する。 | なし | CheckedWitness と入力の型から作る checkedAt。コードを実行しない |
| `E_AtError` | 直接の全位置走査なし | raw code の指定した bases/pattern/input と errorType を AtPrepare/closeVal/closeTy で閉じる。snapshot と固定 σ の一致を照合する。 | なし | 新しい本体の実行なし |
| `E_AtPrepareError` | 直接の全位置走査なし | AtPrepare の指定された値と型注釈を閉じる。RangeIx は raw のまま結果の型に残る。 | なし | 新しい本体の実行なし |
| `E_Fun` | 直接の全位置走査なし | view の実引数を新しい Capture.empty に前置し、宣言本体を型置換する。 | なし | lookup した型付き宣言本体を具体化 |
| `E_Meth` | 直接の全位置走査なし | view の辞書の実引数と値の実引数を新しい捕捉へ前置し、宣言本体を型置換する。 | なし | lookup した型付きメソッド本体を具体化 |
| `E_Super` | 直接の全位置走査なし | superStep は辞書を取り出し、宣言した上位辞書を型置換して instantiate する。捕捉の元値を一括走査しない。 | なし | 宣言した上位辞書を具体化 |
| `E_IfT` | 直接の全位置走査なし | view の条件値で枝を選び、同じ捕捉を本体へ渡す。 | なし | 元の真の枝の導出 |
| `E_IfF` | 直接の全位置走査なし | view の条件値で枝を選び、同じ捕捉を本体へ渡す。 | なし | 元の偽の枝の導出 |
| `E_Match` | 直接の全位置走査なし | view の被検査値と元の捕捉を matchRun へ渡す。 | なし | 新しい本体の実行なし |
| `E_MatchSkip` | 直接の全位置走査なし | 現在の腕と被検査値だけを firstAlt で照合し、捕捉はそのまま渡す。 | なし | 新しい本体の実行なし |
| `E_MatchBody` | 直接の全位置走査なし | firstAlt の束縛を cap.extendMany で前置し、本体と組み合わせる。 | なし | 腕の導出を成功した束縛で具体化 |
| `E_MatchGuard` | 直接の全位置走査なし | 同じ束縛を guard と本体へ前置し、元の捕捉を guard 枠に保存する。 | なし | guard の導出を成功した束縛で具体化 |
| `E_GuardT` | 直接の全位置走査なし | view の Bool に従い保存本体又は元の matchRun へ戻る。保存捕捉の内容を走査しない。 | なし | GuardBodyTy に保存した真の本体 |
| `E_GuardF` | 直接の全位置走査なし | view の Bool に従い保存本体又は元の matchRun へ戻る。保存捕捉の内容を走査しない。 | なし | 新しい本体の実行なし |
| `E_ErrPopGuard` | 直接の全位置走査なし | guard 枠を捨て、保存した捕捉と本体を走査しない。 | なし | 新しい本体の実行なし |
| `E_ExitPopGuard` | 直接の全位置走査なし | guard 枠を捨て、保存した捕捉と本体を走査しない。 | なし | 新しい本体の実行なし |
| `E_Prim` | δへ値を丸ごと渡す | view が閉じた関数と実引数を δ へ渡す。δ の実引数の閉包の捕捉に対する読取り制限はない。成功側での具体の読取りは今回証明していない。 | なし | 契約で型付く返却値だけ。閉包の本体はここでは実行しない |
| `E_Err` | None の位置の読取りを確認 | view が閉じた実引数を δ へ渡す。CaptureReadBoundary の適格な表で、None の位置の閉包の builder の場所7/8が異なるエラーを選ぶ。 | なし | 新しい本体の実行なし |
| `E_IO` | IOの応答へ値を丸ごと渡す | view が閉じた実引数を ioResponse へ渡す。ioResponse の契約は型・適格性・応答種別であり、閉包内の読取り範囲を制限しない。今回の具体の反例は δ の失敗側である。 | なし | 契約で型付く返却値だけ。閉包の本体はここでは実行しない |
| `E_IOErr` | IOの応答へ値を丸ごと渡す | view が閉じた実引数を ioResponse へ渡す。ioResponse の契約は型・適格性・応答種別であり、閉包内の読取り範囲を制限しない。今回の具体の反例は δ の失敗側である。 | なし | 新しい本体の実行なし |
| `E_Exit` | IOの応答へ値を丸ごと渡す | view が閉じた実引数を ioResponse へ渡す。ioResponse の契約は型・適格性・応答種別であり、閉包内の読取り範囲を制限しない。今回の具体の反例は δ の失敗側である。 | なし | 新しい本体の実行なし |
| `E_RefNew` | 直接の全位置走査なし | view の値を val セルへ保存する。捕捉した値の内部を走査しない。 | 新しい val セルへの割当て | 新しい本体の実行なし |
| `E_RefGet` | 直接の全位置走査なし | 指定された場所の val セルの値を返す。内部の閉包はそのまま返す。 | 明示した ref 場所の読出し | 新しい本体の実行なし |
| `E_RefSet` | 直接の全位置走査なし | 指定された場所へ view の値を書き込む。内部の閉包はそのまま保存する。 | 明示した ref 場所の更新 | 新しい本体の実行なし |
| `E_RefUpdate` | 直接の全位置走査なし | view の関数と場所から get/app/set のコードを作る。Val.rename は既存の closure の捕捉を変更しない。 | なし | 元の型付き関数値から get/app/set を構成 |
| `E_Lazy` | 直接の全位置走査なし | 同じ捕捉と lazy 本体を thunk セルへ保存する。 | 新しい thunk セルへの割当て | 新しい本体の実行なし |
| `E_ForceDone` | 直接の全位置走査なし | 指定された done セルの値をそのまま返す。 | 明示した lazy 場所の読出し | 新しい本体の実行なし |
| `E_Force` | 直接の全位置走査なし | 指定された thunk セルの閉包をそのまま実行へ戻し、update 枠を置く。 | 明示した lazy 場所の読出し | CellOk の thunk の ClosureTy |
| `E_Update` | 直接の全位置走査なし | view の返却値を done セルへ書き戻す。値内の捕捉は走査しない。 | update 枠の場所への書戻し | 新しい本体の実行なし |
| `E_Mark` | 直接の全位置走査なし | view の値を返し、mark 枠を外す。 | なし | 新しい本体の実行なし |
| `E_EscLet` | 直接の全位置走査なし | view の escape の値を渡し、let/handler 枠の捕捉を捨てる。 | なし | 新しい本体の実行なし |
| `E_EscHandle` | 直接の全位置走査なし | view の escape の値を渡し、let/handler 枠の捕捉を捨てる。 | なし | 新しい本体の実行なし |
| `E_EscMark` | 直接の全位置走査なし | view の値を返し、mark 枠を外す。 | なし | 新しい本体の実行なし |
| `E_Use` | 直接の全位置走査なし | view の資源値だけを release 枠へ保存し、本体へ元の捕捉を渡す。 | なし | 元の use 本体の導出 |
| `E_Release` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_RelErr` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_EscRel` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_EscRelErr` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_ErrPopLet` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ErrPopMark` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ErrPopUpdate` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ErrPopHandle` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ErrRel` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_ErrRelErr` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_ExitPopLet` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ExitPopMark` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ExitPopUpdate` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ExitPopHandle` | 直接の全位置走査なし | 先頭枠を捨てる。枠の本体・捕捉・セルの内容は走査しない。 | なし | 新しい本体の実行なし |
| `E_ExitRel` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_ExitRelErr` | 保存資源を解放の応答へ渡す | release 枠の資源値だけを releaseResponse へ渡す。枠や閉包の捕捉の全位置を走査する操作はない。 | なし | 新しい本体の実行なし |
| `E_Handle` | 直接の全位置走査なし | 同じ捕捉を本体と handler 枠に保存する。 | なし | 元の保護本体の導出 |
| `E_HRet` | 直接の全位置走査なし | view の返却値を渡して handler 枠を捨てる。節の捕捉は読まない。 | なし | 新しい本体の実行なし |
| `E_Op` | 直接の全位置走査なし | SplitAt/findClause/NoHandler は枠と節の操作名を選ぶ。選んだ hcap に値と継続の場所を前置し、節のコードを型置換する。既存 closure の捕捉は型置換で変更しない。 | 空き場所へ cont セルを割当て | 選択した型付き節本体を具体化 |
| `E_OpFail` | 直接の全位置走査なし | SplitAt/findClause/NoHandler は枠と節の操作名を選ぶ。選んだ hcap に値と継続の場所を前置し、節のコードを型置換する。既存 closure の捕捉は型置換で変更しない。 | 空き場所へ cont セルを割当て | 選択した型付き失敗節本体を具体化 |
| `E_OpPrim` | 直接の全位置走査なし | SplitAt/findClause/NoHandler は枠と節の操作名を選ぶ。選んだ hcap に値と継続の場所を前置し、節のコードを型置換する。既存 closure の捕捉は型置換で変更しない。 | 空き場所へ cont セルを割当て | 選択した型付き節本体を具体化 |
| `E_Resume` | 直接の全位置走査なし | view の継続の場所と値を読み、指定された cont/used セルを照合する。保存捕捉の内容は走査しない。 | 明示した cont 場所を読み used に更新 | CellOk の ContTy に保存した枠を接続 |
| `E_ResumeErr` | 直接の全位置走査なし | view の継続の場所と値を読み、指定された cont/used セルを照合する。保存捕捉の内容は走査しない。 | 明示した used 場所の照合 | 新しい本体の実行なし |
| `E_Drop` | 直接の全位置走査なし | drop 枠の指定した場所が used であることだけを照合し、枠を外す。 | drop 枠の used 場所の照合 | 新しい本体の実行なし |
| `E_DropRel` | 直接の全位置走査なし | 指定された cont セルを used に変え、releases が保存継続の release/drop 枠だけを選ぶ。let/guard/handler の捕捉は走査しない。 | drop 枠の cont 場所を読み used に更新 | 新しい本体の実行なし |
| `E_EscDrop` | 直接の全位置走査なし | drop 枠の指定した場所が used であることだけを照合し、枠を外す。 | drop 枠の used 場所の照合 | 新しい本体の実行なし |
| `E_EscDropRel` | 直接の全位置走査なし | 指定された cont セルを used に変え、releases が保存継続の release/drop 枠だけを選ぶ。let/guard/handler の捕捉は走査しない。 | drop 枠の cont 場所を読み used に更新 | 新しい本体の実行なし |
| `E_ErrDrop` | 直接の全位置走査なし | drop 枠の指定した場所が used であることだけを照合し、枠を外す。 | drop 枠の used 場所の照合 | 新しい本体の実行なし |
| `E_ErrDropRel` | 直接の全位置走査なし | 指定された cont セルを used に変え、releases が保存継続の release/drop 枠だけを選ぶ。let/guard/handler の捕捉は走査しない。 | drop 枠の cont 場所を読み used に更新 | 新しい本体の実行なし |
| `E_ExitDrop` | 直接の全位置走査なし | drop 枠の指定した場所が used であることだけを照合し、枠を外す。 | drop 枠の used 場所の照合 | 新しい本体の実行なし |
| `E_ExitDropRel` | 直接の全位置走査なし | 指定された cont セルを used に変え、releases が保存継続の release/drop 枠だけを選ぶ。let/guard/handler の捕捉は走査しない。 | drop 枠の cont 場所を読み used に更新 | 新しい本体の実行なし |

### 捕捉・型注釈・snapshot と補助操作

| 操作・証拠 | 点検の結果 |
|---|---|
| Capture.env / closeVal / closeVals | env は指定された添字を取り出す。closeVal は構文に現れる値だけを閉じる。lam/dependentLam は元の捕捉を保持する closure を作り、既存 closure はそのまま返す。値の内部の捕捉を一括して閉じない |
| Closure.view の全16形 | 現在の値・引数・kind・型／行注釈だけを閉じ、内側のコードは元の捕捉と一緒に保持する。checkAt の遷移は raw code と AtPrepare を読む |
| closeTy / closeEff / closeTel | 型の値依存の観測を cap.env で閉じる。型付けの References と SubstAgree の既存の相互証明は、通常値・継続の some の位置、型注釈の参照と snapshot を含む。None の位置を無条件で消す操作を加えていない |
| Γ・Φ・型注釈・snapshot | 元の CaptureOk の ImageOk と Transport、型注釈と述語の Sorted/References が参照元である。None の位置を通常変数として読む V_Var と resume は構成できない。局所文脈 L の some は Γ の None と重なりうるので、値の読取りと CaptureLocals の局所参照の解決を区別する |
| resolveLocals / subst / substTy | コード内の専用参照・型・行を扱う。既存の Val.closure の捕捉には入らない。CaptureLocals は L の some の位置の解決先とストア型を照合する |
| findClause / handles / SplitAt / NoHandler | 操作名と節・枠の順を調べる。cap.values を走査しない |
| releases / markPush / Closure.apply | releases は release/drop の枠だけを選ぶ。markPush は先頭枠を読む。apply は新しい値を前置し、既存の位置の値を取り出さない |
| Capture.Closed / Capture.Adequate / StateTyE | 全位置に及ぶ条件だが、型付けの証拠の条件である。実行の遷移がこれらを計算する規則はない。新しい局所参照の条件で置き換えていない |
| PreparationNode.Child | 捕捉の全 some の位置をたどる。これは開始準備の構文参照の関係で、Semantics.Step の76遷移ではない。InitialPrepared/Ready を変更・縮小していない |
| δ / ioResponse / releaseResponse / externalResponse | 抽象的な関数・関係へ実際の値を渡す境界。結果の型付けや適格性は入力の閉包の構造を読まない保証ではない。今回確定した反例は δ/E_Err である。その他にも読取りの反例があると主張していない |

### 未定義の条件と残る単位

点検が通過しなかったため、「導出が読む位置」の新しい条件は定義していない。CaptureOk・ClosureTy・StateTyE・ValueMeaning・型付けの規則・主な10言明は変えていない。新しい公理や独立の信頼条件も加えていない。HiddenCaptureBoundary の既存の反例と受理側を残し、新しい条件を満たすという未証明の対照は追加していない。

| 単位・義務 | 再開1の判定 |
|---|---|
| 再開依頼1の全76遷移の点検 | 完了。E_Err に具体の読取りがあり、通過と判定しない |
| 再開依頼2の新しい条件と既存反例との対照 | 未実施。点検通過が前提のため |
| L20.106〜.109・.111 | 初回の当担当分の完了から変更なし |
| L20.110・.112 | 初回の一部実装のまま。局所参照の残りを閉じていない |
| L20.113・.114 | 未着手。外部応答の存在 L60 と表層から開始 L70 を先取りしていない |
| O003 | 一部。全位置に代わる新条件は未定義。δ の読取りと局所参照の有効性を区別して取りまとめへ戻す |
| O007 | 未実施。.113 の Reference/Lazy の一般値の接続は今回も未着手 |
| O008 | 一部。初回の葉から変更なし。捕捉の新条件と .113/.114 が残る |
| O038 | 一部。読取りの点検と反例を追加したが、残る葉の保存の証拠には数えない |
| O051 | 初回の .106〜.109 の当担当分の判定を継承。新条件の証明へ読み替えない |
| O058 | 一部。新しい局所参照の接続と .113/.114 は残る |
| O065 | 初回の定義の継承から変更なし。開始準備は未着手 |
| O159 | 初回の三条件の区別を継承。今回も具体の同じ表の条件と元状態を同時に構成。InitialPrepared の合成は未着手 |
| O016 | 公理依存を再実行し、許可された三公理だけと確認。下の検査記録を参照 |
| O084 | 読取りを再現した具体例と、未実施の新条件・保存・独立レビュー・受け入れを区別 |
| O027 | RSS は未取得（部分作業の計画上の非採取）。他段の未取得を埋めた扱いにしない |
| O118 | 新しい Lean コメントに作業 ID はない。型付けと抽象的な応答の境界を説明 |

### 足した宣言・署名と検査の関門

追加は CaptureReadBoundary の25宣言、297行である。24宣言は非公開の表・入力の構成と証拠で、公開の入口は具体の適用例 primitive_reads_hidden_capture 一つである。完全署名を先に追記し、局所検査の型注記・未使用の simp 引数の整理と、内部の SignatureInstance が読む Tel.instR を最終の署名へそろえた。追加後の完全署名は175宣言・36,703バイトである。既定 import からの除外はない。

追加する具体例の境界は、現在の Builtins.ResponseAssumptions と Semantics.Step である。確認する性質は、型付きの閉包の未使用位置の値の構造を読む δ が現行の契約で許されることである。以前の HiddenCaptureBoundary は、その位置の局所参照の有効性を否定するだけで、実際の応答の読取りを再現しないため、この境界を一つ追加した。組み込みの表を未知の仮定で受けず、実際の契約の全欄の充足と非空の入力を構成した。応答が未使用の位置を読まないという仮定を黙って導入した場合に、この例との両立が問題になる。本番の実行コード、型付け規則、差し込み口、旧の例を追加・変更・削除していない。

局所検査の初回は、捕捉の添字の型注記、AdequateResult の引数、隠した空のストア型の等号、閉じた型と行の正規化、SignatureInstance の Tel.instR に関する証拠で失敗した。型注記と正規化の等号を明示して修正し、現在の契約と行先は変えていない。最後の単独 Lean 検査は終了0・診断0件である。各生ログは <tmp>、大きさと SHA-256 は検査記録に残す。

### 取りまとめへ戻す判断

指定された点検条件の「読む」「実行に使う」が、未使用位置の局所参照の番号を読んで応答を選ぶことも含むなら、上の E_Err が反例である。専用セルの参照・更新だけを対象にする意図なら、その区別を判断に反映してから続ける必要がある。この反例だけを根拠に、案1の局所参照の有効性が不可能であると結論しない。

| 残る手順 | 見込み |
|---|---|
| δ の値の構造の読取りと、専用セルの参照・更新の区別を取りまとめで確定する | 所要時間・待ちは不明 |
| 現行の応答の型付けから、選択した局所参照の条件を応答へ接続できるかを点検する | 範囲確定後、最初30〜60分の点検の案。全証明は不明 |
| .110/.112 の残り、.113/.114 の証明、既定ビルド・公理依存・作業末の検査 | 範囲確定後に見積もる。現時点では不明 |
| 定義・言明・仮定の独立レビューと設計者の受け入れ | 所要時間・待ちは不明 |

いずれの追加案も採用していない。δ や IO の契約に未使用位置の読取りを禁止する欄を新設することは、独立の信頼条件を増やすため本担当では行わない。利用者が書けるソースの制限は提案していない。plan・detail・レビューの記録・処理系・旧 Release の変更、git の操作は行っていない。


### 再開1の検査結果

既定の lake build は840 jobs、終了0、外側1.570秒で成功した。新規モジュールの単独検査は lake env lean -M 12288 で終了0、診断0件である。既定ビルドは既存モジュールの warning を再表示し、新しいモジュールの warning はない。

work の dry-run で spec_tally・spec_examples・formal_build が選ばれることを確認した後、`scripts/check.sh --level work --base 2f2a27900721ad93b0189930359fc48f8c887db0` を --only なしで本再開の最後に一度実行した。終了0、外側3.786秒。仕様例7件が成功し、仕様対応の自己検査と集計、既定 Lean ビルド、sorry の拒否を含む。

| 検査 | 終了 | 外側の時間 | ログの bytes | SHA-256 |
|---|---:|---:|---:|---|
| 既定ビルド | 0 | 1.570秒 | 42,831 | `a5c14b5e748182cfd3e4cb4f4924c16c3ab501586286c40c445a1f4088a05693` |
| 公理依存 A-L | 0 | 4.091秒 | 1,649,533 | `4bea42b8c68c788da9c96a59716546552cc10ee69f91b2cf820505d620980773` |
| work の選択 | 0 | 0.115秒 | 759 | `06079419bc8ccd286e6c1ac0e80fc550fba376764125b445be214872031da6cc` |
| 作業末の work | 0 | 3.786秒 | 5,757 | `3d884a90387cd90205223d1feb05330dd99695a59f0fd91b928c7deb79ec8a7e` |

[checks-resume1.json](checks-resume1.json) に完全なコマンド・開始終了・入力ハッシュ、[logs-resume1.json](logs-resume1.json) に全中間ログの大きさ・SHA-256・終了状態を記録した。生のログは全て <tmp> に置いた。初回の checks.json/logs.json は当時の記録として残し、今回の入力と区別する。

公理依存の再監査は、追加したモジュールの生成宣言84定数を含む13モジュール842定数と、既存の明示した印字を対象にした。依存の印字711件、依存なし209件で、許可された propext・Classical.choice・Quot.sound 以外は0件である。既存 ClosureTyping のコンパイラ生成の再帰の定数二つは前回と同じく型と公理依存を印字し、監査から除外していない。新しい公理・sorryAx・source の unsafe/partial はない。最新の要約は [audit-summary.json](audit-summary.json) に置く。

01-12/07-04 の写しは、現在の応答の契約とこの具体例が証明する範囲だけを同じ変更で反映し、変更の経緯を書いていない。最後の検査の後に変えたのは結果と検査のメタデータだけであり、証明・例・型付け規則・設計書の本文は変更していない。点検開始の時刻と能動時間／待ちは分離採取していない。最初の時刻採取18:18:10（JST）は読取り開始時刻ではない。4時間の途中報告の条件には達していない。RSS は未取得（部分作業の計画上の非採取）である。定義・言明・仮定の独立レビュー、受け入れ、Rust/Lean の全比較は未実施である。

## 作業末の work

取りまとめが再開3の後に実行した。

| 項目 | 値 |
|---|---|
| コマンド | `scripts/check.sh --level work --base 2f2a27900721ad93b0189930359fc48f8c887db0` |
| 終了状態 | 0 |
| 外側の時間 | 145.18 秒 |
| 最大常駐量 | 1,535,950,848 バイト |

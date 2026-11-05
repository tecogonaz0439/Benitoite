# RV-L70.u: L70 群 U（L70.01・.02、公開形・名前の対応と旧 API の静的拒否）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.u` の未コミットの作業木である。基準は `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` で、HEAD と一致する。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは群 U の本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 依頼文 `L70.u-prompt.md` と、[担当の報告](../l70/u/results.md)の初回・停止理由・再開1・署名の差14行・申し送り・検査の記録。
- `l70/detail.md` の第2.8節、L70.01・.02、群 U の完了条件、`l70/signatures.md`、`u02/decisions.md`、`u02/candidates.md` の S16 の完全宣言、`l50/u02-options.md`。目的と保証の範囲は 00-01 で確認した。
- plan.md の「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の判断。本体の作業木の未コミットの最新版を正とし、旧 API の静的拒否、上限のポート範囲、内部の outsideScope、要求の At、単射性と整数欄の申し送りに関する決定を確認した。
- `l50/stage-results.md` の H20・H21 と後段の受け口、`l60/stage-results.md` の合成表の結論と後段へ渡す署名。
- `git diff 657b3ae7 -- formal docs/design` の全差分と、新規の `ScopePublic.lean`・`ScopePublicValues.lean`・`ScopePublicTyping.lean`・`PublicNames.lean` の全文。比較のため、At の入力・型付け・準備・保存・三遷移、`StoreReplyInputs`、範囲への所属、旧 API の応答、合成表の core・targets・WellTyped・WellFormed の読者も読んだ。
- `l70/u/verify.py`・`axioms.lean`・audit-modules.json・required-names.json・audit-summary.json と、指定の一時領域に残る群末の build.log・axioms.log。

本書以外のリポジトリ内のファイルは変更していない。git の書き込み操作、`lake build`・cargo・`scripts/check.sh` の実行はしていない。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、`-o` は使っていない。確認ファイルとソースの写しは `<tmp>/rv-l70-u/` に置いた。大きな具体値を作る評価はしていない。記録を書き換える verify.py などは実行せず、読んで判定した。担当の既定ビルド・全宣言の公理監査は、保存された生出力の照合と、本レビューで実行した Lean の確認を区別した。

## 結論

**条件付き可**（重0・中1・軽0・情報0）。

承認された δ の変更は旧 API の静的拒否の値に限られ、Step と StoreReplyInputs の構成子・前提・量化、型付けの構成子は変わっていない。公開形の型付け・観測・照合・網羅性は、同じ P の必要な宣言条件と完全性を受け取り、全診断・全公開型について接続できる。合成表の core・targets と、ExternalWF を前提に取る WellTyped・WellFormed も、任意の外部宣言表について保たれる。新しい公理、sorry、未承認の書ける形や提供範囲の削減は見つからなかった。

条件は、担当の報告にあるモジュール数と宣言数の記述を、実差分と監査記録に合わせることだけである。公理監査の実際の対象に漏れはなく、本番の証明の修正を求める所見ではない。整数欄の飽和と公開変換の単射性は、最新版の plan.md が収集の前へ送ると決めた残件であり、群 U で証明済みとは判定していない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|---|
| 中1 | 中 | `l70/u/results.md` 196行の署名の差の表、204行「足した宣言」、228行「再開1の検査」 | 変更した Refinement のモジュールを32とするが、実差分と audit-summary.json の changed は33であり、追加4と合わせた監査対象は37モジュールである。また、`ScopeDeclarations.http` の「6宣言の追加（Option と19）」は実物の数と合わない。既存5に Option 1と新公開19を追加した計25宣言、追加分は20宣言である。5989宣言の監査自体は37モジュールをすべて覆っており、漏れではない | 32を33へ直し、監査対象を追加4＋変更33＝37と明記する。http の行は「既存5＋Option 1＋新公開19＝25宣言（追加20）」とする。既存の audit-summary.json・audit-modules.json と本番は変更せず、報告の数を揃える | 読めば確定。独立集計と検査3でも確認 |

## 観点ごとの根拠

### 1. δ の変更と L50 の証拠

`ScopeDelta.run` と `RequestDelta.run` の成功・解析拒否・動的拒否の処理は保たれ、変更は動的成功後の静的拒否で返す値とその読者である。パスは `OutsideScope(pattern, target)` を返す。要求は、上限が endpoint でホストが合う場合に上限の minimum・maximum と対象の port を持つ `PortOutsideScope`、それ以外に元のホスト条件と要求のホストの綴りを持つ `OutsideScope` を返す。based・secrets もこの拒否へ入り、暗黙に起点を解決しない。

PortOutsideScope の分類は、具体例だけから判断していない。任意の bound・endpoint について、上限のホストに所属し、同じ上限への `Range.MemK .endpoint` が不成立なら、その上限のポート区間へ不所属であることを検査3の `upperPortOutside` で確認した。動的な pattern は既に通過しているため、そのポート区間では拒否の理由を示せない。違反した上限の区間を返す選択は、最新版の plan.md の取りまとめの判断と合う。

二つの staticError は旧構成子を作る `ScopeDelta.errorValue` を使う。パスの static_safe は同じ HasFile P のまま、要求の static_safe は既存の HasHttp P から error_safe を使う。run_safe・response は全入力又は型付きの全入力と任意の範囲を量化したままであり、正常応答だけに限定していない。run_absolute・run_endpoint と、正常・拒否の対照例も新しい値へ追随している。値の旧構成子への変更を、At の三遷移の変更で代用していない。

`Typing.lean`・`Semantics.lean`・`Step.lean`・`StoreReplyLeaves.lean` は基準とバイト単位で同じである。従って、`V_AtError`・`C_CheckAt` と、Step／StoreReplyInputs の E_AtOk・E_AtError・E_AtPrepareError の構成子、前提、量化は変わっていない。`StateTyE.store_reply` の公理依存も検査3で許可した三公理の範囲にある。旧 API の静的と動的の拒否が同じ旧構成子になることは設計者が承認した意味の変更であり、At API の DynamicCondition と StaticIndex の区別は残る。

### 2. 同じ P.cons での公開形・照合・網羅性

`ScopePublic.declarations` は案 B の19型で、構成子名と各引数の順序・型は S16 の完全宣言と一致する。既存 ScopeError の7構成子を含む all の構成子は52、新公開分だけでは45である。PathBases は `Ty.pathBases` に対応する不透明な型として別に数えるため、19型にこれを加える20型という完了条件とも合う。AtInput は Text と Pattern の二構成子だけであり、Request と公開の AtFailure.OutsideScope は追加していない。

`Detail.publicTree` は九欄の木を一つの AtDetail の値へ写し、`Detail.values`・`Val.toTerm?`・matchVal が同じ形を読む。`PublicTree.toVal_toTerm` と `Detail.values_toTerm` が観測の一致を示す。`Detail.publicTree_typed` は退避する場合も含む全診断を扱い、`PublicTree.Typed.val` は任意の P・B・ストア・文脈について HasScopePublic から同じ型を構成する。PublicTree の bytes・list・Option・con の場合も含む帰納であり、部分の例だけではない。

At の外側の照合は変数一つを束縛し、その値を AtDetail として型付ける。内側の各公開構成子は constructor_match が全欄を順に束縛する。新公開19型の網羅性は `P.ScopePublicComplete`、ScopeError の網羅性は従来の `P.StandardErrorComplete` を別に受け取る。二つの完全性を HasScopePublic だけで得たとみなしていない。検査3の publicClosure では、これらを同じ任意の P に揃え、全 AtError の束縛列の型・照合・宣言と、全公開型および ScopeError の網羅性を一つの言明にした。

HasScopePublic は宣言の lookup・arity・Option の一致を要求する条件であり、未検査の信頼条件ではない。`ScopePublic.program_public` は宣言条件と新公開型の完全性を具体の同じプログラムで満たす。`ScopeDeclarations.HasHttp.scopePublic` と合成表の http_declarations は同じ宣言条件を実物の表から供給する。利用者の関数や外部宣言のない P に制限する条件は足していない。

### 3. D61 の内部保存と固定値への退避

`AtError.save`・`AtError.fromCheck` の元入力の保持、AtPrepare.error_saved・save_exact の保存の結論は変わっていない。AtPrepare の差分は outsideScope を返さない補題の追加だけである。公開形を作る前の保存値を、空の文字列や Top へ置き換えてはいない。原子列は map で要素・並び・重複を保ち、Option は none と some [] を区別する。At の欄を照合して返すのは新しく構築した公開の値であり、不活性な元の Val をそのまま返す入口ではない。`Adequate.lean` の元入力へ再帰しない定義を変える必要もない。

七 String の観測を廃止すると、元入力を任意に置き換えても観測が不変という旧 originals_unobserved は成立しなくなる。新しい originals_observed は、元入力の公開形が等しい場合に限って公開形・値列・項観測・任意パターンの束縛列の項観測が等しいことを述べる。この変更は新しい観測の意味と合い、元入力を読めるようにする U02 の判断を打ち消していない。ただし、この定理は公開変換の単射性を示すものではない。

固定値への退避を避ける証拠も、失敗の具体例だけではない。AtPrepare.no_outsideScope と checkAt_no_outsideScope は準備・検査の全失敗を扱う。`StateTyE.at_public_inputs` は型付きの状態から捕捉後の pattern と input の型を取り出し、内容型を持たない名前では pattern が scopePattern、input が String であることを canonical forms から示す。そのため、同じ状態の at_prepare_public と at_check_public は detailTree? の成功と、その木が実際の publicTree に等しいことを結論する。

公開の checkPathInAt は名前 Scope.PathIn を使い、標準の表でその valContent は none である。要求の名前 Http.RequestIn は内容型を持ち、公開の At 入口は設けない。旧 API の δ も要求を保存した atError を作らなくなった。従って、公開入口が生成する準備・検査の失敗に、要求の元入力を写せず退避する経路はない。この判断は、任意に作った内部の atError がすべて完全に観測できるという言明ではない。内部の要求の At の暫定値と R30・R60 の照合を残す扱いは、plan.md の承認と合う。

`natural` は任意の Nat を Integer の上端に飽和させる。公開形を持つことと元の内部値が一意に復元できることは別であり、後者は今回の証拠から結論しない。ポートでは Fin の上限から natural_exact を適用できる。CIDR などを含めた単射性と必要な有効性の全体は、plan.md の指定どおり L70.17〜.19 の収集の前に扱う残件として保持する。

### 4. 前段の署名と合成表の結論

署名の差14行には、七欄から一欄への変更、StandardError の新しい条件、values_typed・match_pattern_typed の前提、originals_observed への変更、result_declared の十分条件、宣言表と例の変更が記される。`atError_declaration` は前提を追加したのではなく、型付きの atError から取り出す**結論**に HasScopePublic を加えている。PatternBindings と PatternMatchAnnotations はこの結論から新しい values_typed の前提を得ており、独立の条件を仮定し直していない。

StandardError の意味は公開の宣言全体と Option を要求する形に変わるため、V_AtError のテキストが同じというだけで前段と同じ意味とは判定できない。しかし、この変更は J50-1 の公開形への切り替えとして明記され、必要な宣言は有限表の証明で供給される。既存の補助の導出や例を除外して通す変更はない。LegacyPatternMatch の公開木への写し、LegacyPatternCoverage の旧 Inhabits への接続、CanonicalValues・TypedFacts・MatchFacts・ValueBinding の観測の追随も確認した。

ScopeDelta.result_declared は HasFile から HasHttp へ十分条件を変え、PublicNames に読者を置く。これは Scope の公開の型規則へ Http の import を要求する変更ではない。検査3の pathShape_withoutHttp では、任意の P の HasFile と HasScopePublic だけから同じ ResultShape.Declared を構成できた。旧 API の run_safe・response が使う HasFile の範囲は保たれる。

合成表は `baseDeclarations ++ publicDecls` とし、Option は既存の標準宣言を使う。新しい45構成子を末尾へ置くので、既存の構成子名の相対順序は変わらない。variance_valid・map_set_declarations・field_rows・http_declarations は新しい分を場合分けして処理し、旧の構成子の閉包の証拠も残す。検査3の composedContracts は、外部宣言表を任意に量化したまま core・targets・HasScopePublic と、前段と同じ ExternalWF を前提とする WellTyped・WellFormed をまとめて適用できた。CoreAssumptions や TargetAgreement へ新しい欄を足していない。

### 5. 公開名と完全署名の対応

安全な入口の表は InternalContracts.all と同じ19行であり、既存15・一本化2・新規2、異なる公開名17という数が一致する。head・tail の一本化は同じ依存列に基づく。合成表の鍵を持つ17行は任意の externals について lookup でき、精密側の本体をまだ持たないのは tail の二行だけである。この残りを L70.19 へ渡す扱いも報告されている。

PathBases の型、Process.pathBases の内部の発行名・効果・引数なしの署名、checkPathInAt の path・Scope.PathIn・ResultShape の対応は S13・S14 と一致する。発行の内部名 Example.pathBases の改名を R40 に送る扱いは plan.md の判断どおりである。一般 check の名前・CheckError の String 一欄・型引数の許容は signatures.md の形と合い、checkAdmits は既存 PrimSig.admits の型で表せる。置換の五契約や実 δ の行の完成は L70.38 の担当であり、今回の対応の例をその証明の代用にしていない。

Float と Float32 は同じ七名を持ち、六類への一対一の名前と、正負の無限の or としての isInfinite が J70-11 に合う。追加名は Float が6、Float32 が5である。charactersIn は両端のリテラル、memberPredicate はリテラルの絶対形と種類の一致を要求し、constructorPredicate は constructorIs に写す。J70-9 の結果型の篩と実 δ の契約を今回実装済みとはしていない。公開型19名、record 六つの欄の順序、改名した欄、PathBase の五構成子の綴りも決定と一致する。

### 6. 公理・既定 import・写しと記録

追跡差分は Refinement の33モジュール、根の import、01-12、07-04 で、新規は四モジュールである。旧 Release と処理系、計画・前段の記録への変更はない。根の import は基準の末尾へ四モジュールを各一回追加するだけで、既存 import を除いていない。追加ソースと差分の追加行に、新しい axiom・sorry・native_decide・#eval・#reduce・maxHeartbeats／maxRecDepth はない。ScopeDelta・RequestDelta の上限設定は基準からあるものである。新規の private 補助は後続の定理から使われる。

保存された監査の対象5989件と公理出力5989件は一対一に一致し、重複・未知の公理・sorryAx・監査エラーは0である。依存の組は、なし3770、propext 1256、propext と Quot.sound 106、許可した三公理857である。対象37モジュールのソースハッシュはすべて現物と一致する。追加四モジュールの宣言780件と private 1460件の数も保存記録と合う。中1は報告本文の数の誤りであり、これらの実際の監査集合を縮めるものではない。

01-12 は観測・元入力の置換・二つの δ、07-04 は対応する説明と四モジュールの位置付けを変更している。本番の現在の条件・値の形と一致し、工程の経緯を規範へ写していない。変更箇所に新しい text の仕様例はない。Rust・実 CLI・Show・JSON・交換との一致は今回の検査対象ではなく、報告も R30・R50・R60 等への申し送りと分けている。

## 実行した検査

すべて読み取り又は一時領域への出力であり、既定のビルド出力を上書きしていない。

| 番号 | 検査 | 実行と結果 |
|---|---|---|
| 1 | 作業木と差分、監査記録の独立照合 | HEAD・追跡差分・未追跡を読み取った。監査対象の37ソースの SHA-256 は全件一致。build.log は49704バイト・SHA-256 `19763d30e717f13c045947978cfa69e296f43bcfa67587565342345cd0742b1c`、axioms.log は2023274バイト・SHA-256 `a5731dfaa2590335e0ff9d577c01e6615db500fe10bb459c28aa594632163d88` で保存記録と一致した。監査対象・公理出力は5989件ずつで一対一、許可した三公理の外は0。結果は `<tmp>/rv-l70-u/independent-audit.json` |
| 2 | 追加四モジュールと変更した二つの δ のソースの検査 | 現物と同じ内容を `<tmp>/rv-l70-u/` へ写した ScopePublic.lean・ScopePublicValues.lean・ScopePublicTyping.lean・PublicNames.lean・ScopeDelta.lean・RequestDelta.lean を、`formal/` から `lake env lean -M 12288 <file>` で一つずつ確認した。六ファイルすべて終了0。依存には担当の既定ビルドの olean を使った |
| 3 | 全称的な接続・上限の分類・前段の結論・宣言数 | `<tmp>/rv-l70-u/Checks.lean` を同じコマンドで確認した。任意の P の全診断・全公開型、Http を要求しない宣言の構成、任意の外部宣言表の合成契約、任意の端点の上限ポート不所属、宣言数5＋1＋19＝25と既存の構成子順序を確認した。最終は終了0。最初の実行は確認ファイル内の ConName・NoFailCtx の名前修飾不足で終了1となり、両名を修飾して直した。本番の反例ではない。最終の四確認定理と At の三補題・store_reply の `#print axioms` に sorryAx と未知の公理はない |
| 4 | 規則・合成の主要ファイルの基準照合 | Typing・Semantics・Step・StoreReplyLeaves・Adequate・StandardModelCore・StandardModelProgram・ScopeResponse の八ファイルが、基準とバイト単位で同じことを確認した。結果は `<tmp>/rv-l70-u/critical-sources.json` |
| 5 | レビューの変更範囲と記録の表記 | 担当の保存した changed・untracked と作業末の一覧を照合し、新しく追加したリポジトリ内のファイルが本書だけであることを確認した。本書の絶対パス表記と docs/todo へのリンクは0。`git diff --check 657b3ae7 -- formal docs/design` は終了0 |

担当の build.log の終了0と1334 jobs は保存記録として確認したものであり、本レビューで既定ビルドを実行したという意味ではない。cargo・scripts/check.sh・記録を更新する台本・Rust との全比較は実行していない。

## 取りまとめの追記

2026-11-06。群 U は Claude の実装担当が実装し、独立レビューは Codex が本レビューの一回だけ行った。中1（報告のモジュール数と宣言数）は記録の数の誤りであり、取りまとめが `l70/u/results.md` の3か所を実差分（変更33、監査の対象37モジュール、`ScopeDeclarations.http` は25宣言で追加20）に合わせて直した。本番と監査の記録は変えていないので、再レビューを起こさなかった。旧 API の静的拒否を旧構成子で返す δ の変更は設計者の決定（plan.md）に従う。処置の後に取りまとめが `scripts/check.sh --level work --base 657b3ae713040e78826d2f19cd7b8ac9f415a6d6` を実行し、終了0（810.23秒）であった。

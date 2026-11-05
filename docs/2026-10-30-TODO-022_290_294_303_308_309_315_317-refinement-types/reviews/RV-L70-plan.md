# RV-L70-plan: L70 の詳細の下書きの独立レビュー（本レビュー）

2026-11-06。対象はブランチ `m014/l70-plan` の未コミットの作業木にある [detail.md](../l70/detail.md)・[tables.md](../l70/tables.md)・[results.md](../l70/results.md) と試行の入力3件である。基準は `3bf88a9c208af7b09b487efd2b598d74c0f09f27` で、HEAD と一致する。本書の `<repo>` はレビュー対象の worktree、`<tmp>` は指定の scratchpad、C は本書を置く改造ディレクトリを表す。本レビューは一回だけとし、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 依頼 `<home>/src/Benitoite/work/m014/L70-plan-prompt.md`、C の共通依頼文、下書き3文書と `counts-trial.lean`・`shapes-trial.lean`・`axioms-trial.lean`。
- [plan.md](../plan.md) の L70 の行、全 L 作業の停止条件、切替の完了条件、義務の担当と状態、検査の割当、残りの見込み、U05、取りまとめへの確認点の先頭の判断。README の設計者の決定、`u02/decisions.md`、公開 API に関わる `u02/candidates.md`、関係する `decisions.md` の決定も照合した。目的と保証の範囲は `docs/design/00-overview/00-01-goals.md` で確認した。
- `l60/stage-results.md` の旧主定理12件との対応、受け口、仮定側150名、義務と申し送り、計画との差。`l20/`〜`l50/` の段末資料の L70 に残る行、`l00b.15/theorems.md` の新旧の量化も照合した。記録の形式は `reviews/RV-L60.h.md` の初回部分に倣った。
- 本番の `Refinement/FiniteStepPreservation.lean`、状態と型付け、プログラムの形成・型付け・変性・網羅性の定義、合成表の Core・応答・対象・組込みの定義、At の解析・準備と開始状態の接続。旧主定理、旧表層の主定理、交換の Convert・Builtins・CheckInput、実行入口と `Surface/CheckAccept.lean` の受理の接続を読んだ。前段の個々の算法の証明をすべて再レビューする扱いにはしていない。

本書以外のリポジトリ内のファイルは変更していない。git の書き込み操作、`lake build`・cargo・`scripts/check.sh`・`scripts/check-formal.sh` は実行していない。Lean は `<repo>/formal/` で `lake env lean -M 12288 <file>` により一つずつ実行し、`-o` は使っていない。補助入力は指定の `<tmp>/rv-l70-plan/` に置いた。大きな具体値を作る評価はしていない。下書きが記した既定ビルドの成功は担当の記録として読み、本レビューによる再実行と区別した。

## 結論

**条件付き可**（重4・中2・軽0・情報1）。

主定理を一度閉じて表層・交換を切り替える構成と、保存の既済み分を差し引く判断は妥当である。保存については、同じ σ・Eb を保つ前段の定理から公開の保存を導けることを独立に確かめた。主要な件数、申し送り78行、義務59行、見込みの積上げにも集計の食い違いは見つからなかった。

条件は、重1〜重4・中1〜中2を処置してから、この詳細を起動の指定として確定することである。収集の二つの不足を、後で埋める無名の前提にして群 C を起動してはならない。群 A で固定する収集の契約に必要な制約と組込みの表の受け口を示し、交換の実際の受理経路を群 E・G へ割り当てる必要がある。これらは主定理の保証を削る要求でも、形式化の外に残した算法を新たに証明する要求でもない。既に決めた提供範囲のプログラムへ主定理を適用し、既存の入口の保証を維持して切り替えるための補完である。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | detail.md §2.3・F03（238〜264行）、L70.05・.17・.18、tables.md の Map/Set・O005・O033 | 提案した8欄の `Program.Extends` は、既存 lookup の保存だけである。同じ data 型に新しい構成子を加えることを禁じず、網羅性も data の arity も保存しない。さらに `Program.WellTyped`・`WellFormed` は追加された定義・実装・宣言にも義務を持つため、元のプログラムから全体を「移す」だけでは成立しない。網羅性が失われる例を Lean で確認した | 旧宣言の移送と、追加宣言を検査した後の全体の合成を分ける。既存 data の全構成子について逆向きの条件を置き、arity・変性・宣言の読み方も照合する。追加の defs/impls 等の型付け・形成・EffectsOk の供給元を表層の検査または明示した入力へ割り当てる。修正した完全署名を群 A の完了条件にする | 実行で確定（検査1）、全体の合成の不足は読めば確定 |
| 重2 | 重 | detail.md C06・§2.3・F03 の `user_core`・L70.19・§5、tables.md「L60-仮定150」 | 主定理の利用者への系は `B = StandardModel.builtins P` に固定されているが、この B は仮定側の `Process.exit`・`Json.parse` の署名を持たない。P の拡張や、150名についての引数の追加だけでは B の lookup は増えない。従って、記録に名前を残しても、それらを使うプログラムにこの系を適用する受け口にはならない | 合成済みの行と、既存の信頼条件で扱う行を同じ P/B 上に置く契約を群 A で固定する。任意の完全な B を受け取り、合成行の対応と未証明の δ/IO/解放条件を分けて合成する形などを示す。150名は δ80・IO47・資源状態16・形式化外7の区別を維持し、後二者を新しい Task 遷移等の実装へ読み替えない。L70.19 と後段へ渡す署名に反映する | 実行で確定（検査2）、受け口の欠落は読めば確定 |
| 重3 | 重 | detail.md §2.5〜2.6・F06・L70.29〜.31・.40〜.42、§8.4 | checker の健全性を旧17定理、交換を主に Convert の72定義と7入口で数えているが、実際の `surfaceCheck` は `CheckAccept.checkProgramAccepted` を呼ぶ。その健全性が返す `CheckedUnder ∧ Accepted`、必須の判定の受理、`Exchange.CheckInput.prepare`・`Exchange.Builtins`・`CheckTables` の変換と入力形成の層が、規則・葉の表と作業単位の完了条件に現れない。7個の Main の切替だけでは、この経路を新判断で閉じたことにならない | 群 A の棚卸しで7入口から判断を読む経路を列挙し、Convert 以外の層も「移植／新判断を使わず継承／互換専用」に分けて受持単位へ割り当てる。群 E の健全性に実入口の型付けと受理の両結論を含め、群 G はその新入口を読むことを条件にする。旧版の reader の便宜で現行の必須判定を `noRules` に置き換えない | 読めば確定 |
| 重4 | 重 | detail.md §8.3「Rust の開始を許可する条件」4（486行）、§8.2、群 G・H の完了条件 | Rust 開始の必要条件は「F-REG を実行し、結果を保存した」とだけ書かれている。失敗した比較の結果を保存してもこの項を満たす。全コーパスの成功、各比較の不一致、除外の増加を判定する条件がここに無く、plan の「F-REG を通して Rust 開始を許可」と一致しない | 変えていない処理系の所定の全コーパスで、全比較が成功し、不一致と未処置の失敗が無く、未承認の入力省略・除外追加が無いことを必須にする。旧外部除外の実数・理由は保存し、R50 の両理由0件と区別する。最終の定義・交換器・入力・manifest・設定と結果の対応も確認してから Rust 開始を諮る、と明記する | 読めば確定 |
| 中1 | 中 | detail.md §2.8・L70.02・§8.4、u02/decisions.md「後段への申し送り」1 | U02 が「L70 の詳細化で固定する」とした新しい関数の完全署名を、下書きでは今後の L70.02 の作業へ送っている。Float の分類、`String.charactersIn`、所属の2関数、生成判定関数、一般 check の型・引数・結果の形を下書きから一式で読めず、後段へ渡す表も名称だけである | 詳細の確定前に完全署名の表を置く。一般 check の期待型と基の型・篩の関係、生成判定関数の型引数と結果の篩、所属関数の引数型とリテラル制限も示す。L70.02 は、その確定済みの表を Lean の宣言と対応させる作業にする。設計者の選択が残る欄だけを J として分ける | 読めば確定 |
| 中2 | 中 | detail.md J70-5・F09・L70.44、plan.md「L70 の切替の完了条件」 | J70-5 の推す案 A は旧 Release の主定理と旧 Surface 全体を互換モジュールとして残すが、plan は残すものを「旧導出の適格な埋め込みだけを述べる互換モジュール」としている。旧の全主定理を残す案を、既存の切替条件のまま選べるとは扱えない | plan の条件に合わせて旧主定理・旧表層の処置を定めるか、残す宣言の役割・利用者・既定 import と依存監査の扱いを示して、切替条件の例外として設計者へ明示する。いずれも新主定理・交換から旧判断への逆戻りを許さない | 読めば確定 |
| 情報1 | 情報 | detail.md C01・L70.09、`Refinement/FiniteStepPreservation.lean` | 保存の控除は正しい。`step_preserved` は特定の有限コーパスの定理ではなく、任意の新 `Step` に対して同じ σ・Eb を保つ。`StateTy` の包装も同じ前提で証明できる | C01 の控除と L70.09 の小さい作業を維持する。J70-2 等で読者を変更した後も、この実署名と依存を再確認する。76遷移を別々に再証明する作業を戻す必要はない | 実行で確定（検査1） |

## 観点ごとの根拠

### 1. 差し引きと主定理の保存

`StateTyE.step_preserved` は `P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`σ.Valid` を受け、任意の `Step P B σ source event dest` について `StateTyE P B σ Eb source` から同じ Eb の行先を返す。証明本体は Step の全構成子を場合分けし、各保存葉へ実入力を分配する。`steps_preserved` は任意の有限の `Steps` について反復する。ファイル名の Finite は、特定の入力群への限定を意味しない。

公開の `StateTy` は `σ.Valid ∧ ∃ Eb, BuiltinOnly P B Eb ∧ StateTyE P B σ Eb s` である。P/B/σ/Eb は一段で変わらないので、`BuiltinOnly` と `σ.Valid` をそのまま保持して包装できる。検査1では次の形の証明を実行した。

```lean
theorem rv_preservation {P B σ}
    (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.CoreAssumptions P) :
    ∀ s l s', StateTy P B σ s → Step P B σ s l s' → StateTy P B σ s' := by
  intro s l s' ⟨hv, Eb, hEb, hs⟩ hstep
  exact ⟨hv, Eb, hEb, hs.step_preserved hwf hwt hdecl hb hv hstep⟩
```

公理依存は `propext`・`Classical.choice`・`Quot.sound` だけである。したがって C01・C02 を全遷移の保存から差し引く判断は妥当であり、O038・O058 の L70 の残りを包装と最終照合にすることにも問題はない。進行、計算から関係への一歩、開始状態、効果、対象の一段・到達・表層はこの定理からは得られず、下書きも各単位に残している。

C03 の選択の葉、C08〜C12 の外部・At・事象と対象の葉、C13 の意味による網羅性は、主定理・全表層・判定器の完成として差し引かれていない。C04・C05 の置換と旧導出の埋め込みも、全表層の性質1や `embedStep` の証明と混同していない。C14 の区間、C15〜C17 の論理・経路条件・変性、C18 の名前の写像は、それぞれの後続の接続を残す。この控除の仕方そのものに範囲を失う誤りは見つからなかった。C06 を利用者のプログラムへ適用する部分には、重1・重2の補完が要る。

### 2. プログラムの収集と組込みの表

`Program.Extends` が保つものと、全プログラムが検査を通ることは別である。`Program.WellTyped.defs` は P の全成功 lookup に、`impls` も全成功 lookup に義務を持つ。`WellFormed` は cons・ops・classes・metadata 等にも全称の義務を持つ。既存の定義の証拠を移せても、後から加えた利用者の定義がそれだけで型付くことにはならない。L70.17・.18 では、表層から追加宣言の証拠を受け取る合成を明示する必要がある。

網羅性については、実際の反例を確認した。補助入力では F03 と同じ8欄の `RVExtends` を定義し、他の表が空で、構成子だけが次のように異なる二つの Program を置いた。

```lean
def rvOne : Program := {rvEmpty with
  cons := fun c => if c = "D.A" then some ⟨"D", 0, []⟩ else none }
def rvTwo : Program := {rvOne with
  cons := fun c => if c = "D.B" then some ⟨"D", 0, []⟩ else rvOne.cons c }
```

`RVExtends rvOne rvTwo`、`Exhaustive rvOne (.data "D" []) [.con "D.A" []]`、および同じパターン列が rvTwo で網羅しないことをすべて証明した。最後の反例の値は `.con "D.B" [] []` である。これは8欄だけによる網羅性の移送の反例であり、主定理の反例ではない。既存の cons の lookup を保つことは、同じ data の構成子の全一覧を保つことではない。`Program.DataArity` も同じ data に属するすべての構成子を量化するため、別の arity の構成子を追加できる8欄だけでは不変にならない。下書きは網羅性と変性の読み方を未確認と明記しているが、既にこの形で偽になる点は、起動後の短い試行へ残さず契約へ反映できる。

組込みの表については、P を引数に取ることだけでその表が全登録を含むわけではない。`StandardModel.builtins P` は既存の有限の署名表を使い、P に応じて外部応答の部分を構成する。検査2では、任意の P に対して次の等式を `rfl` で確認した。

```lean
example (P : Program) : (StandardModel.builtins P).sig "Process.exit" = none := rfl
example (P : Program) : (StandardModel.builtins P).sig "Json.parse" = none := rfl
example (P : Program) : (StandardModel.builtins P).isResource "TaskGroup" = false := rfl
```

これは前段の誤りではない。L60 は J60-3=(a) に従い、証拠のある行だけを合成した。問題は、この固定の B を使う F03 の利用者への系と、L70.19 の「仮定側150名を引数で量化」が接続されていないことである。一般の主定理は任意の B と既存の信頼条件について述べればよいが、その B と合成済みの行の証拠を合わせる契約が要る。

特に、150名すべてを同種の Lean の仮定として加える案は採れない。L60 の段末は δ80・IO47について応答条件との照合を残し、Task/TaskGroup の7名を形式化外、通常資源16名を実状態との境界として区別している。重2の修正ではこの区別を保ち、新しい外部状態や Task の実行規則を主定理の範囲へ加えない。

### 3. 全場合・申し送り・義務と、交換の実際の読者

構成子の件数は下書きの入力を再実行して一致した。Step76、14判断76枝、State4・Frame7・ContTy10、Comp16・Val25、Ty21・Pred14・Term20・LeQ14、PatTy9・Inhabits24である。旧表層の98構成子・85規則、旧 Step68、旧 CoverageWitness11、交換の Expr54・Ty14・Comp14・Val12も一致した。`Eff.Covers` は帰納型ではなく、その点も構成子数に混ぜていない。

義務の担当列で L70 を含む34行はすべて tables.md にある。前段の義務表の「残る段」の L70 を合わせた和集合は58行で、表にある59行との差は明記された O135 の1行である。欠落は見つからなかった。分類49・6・3・1の和も59である。申し送りは78行で、群別の32・16・10・2・13・4・1とも一致する。衝突18名、`Val.Source`、Map/Set、`%List.getFront`、丸め方式は、完了と後段の照合を分けた受け口を持つ。仮定150名の行は、数と所在は正しいが、重2のとおり技術的な受け口を補う必要がある。

U02 の決定も S1〜S16、推す案と異なる6件、Q2、R11に受持がある。動的な pattern は核の解析と `AtCallAdmissible` の変更として J70-2 に分け、record の依存は核の ConDecl を替える案と表層で全体の篩へ写す案を J70-4 に分けている。R2・R3・R5・R9(a)・R9(b)・R10を枠の外の増分に分ける計上にも漏れは見つからなかった。ただし、新規 API の完全署名そのものは中1のとおり未提示である。

これらの集計と、7入口の依存先の網羅は別に確認する必要がある。`formal/lakefile.toml` の既定の実行入口7件は下書きと一致する。一方で、現在の `SurfaceCheck/Main.lean` の `timedCheck` は `CheckAccept.checkProgramAccepted`、選択した一関数では `Check.checkDef` と `CheckAccept.acceptDef` を使う。`CheckAccept.checkProgramAccepted_sound` は型付け側の `CheckedUnder` と受理側の `Accepted` の両方を返す。後者は全定義・全実装メソッドの必須の判定の受理であり、通常の表層の `HasTypeQ` の85規則とは別の対象である。

また、`Exchange.CheckInput.Prepared` は `Materials`・`Check.Input`・原子の一致・受理の入力を保持する。`Exchange.Builtins` は署名と data の material、組込みの表、許容判定を構成する。`Convert` の写しと新しい `checkProgram_sound` だけでは、これらの旧 Ty/Builtins/Surface を読む層の処置は決まらない。全2123宣言という参考値に含めて読むだけで、個別の受持と保証の対応を済ませたとは判定できない。重3は、この実入口からの経路を群 E・G の作業と健全性へ割り当てる指摘であり、一般の Scope 推論の独立した算法を無条件に作り直す要求ではない。

### 4. 分岐する判断と最初の群

J70-1 の新版と旧版の reader、J70-2 の動的 pattern、J70-3 の18名の対応、J70-4 の record の表現、J70-6 の見込みの扱いは、独立した判断として立てられている。未回答を採用済みとはしていない。F01 の主定理の種類と外部応答・σ の扱いも、前段の対照の方向に合う。`shapes-trial.lean` の成功は言明の型検査であり、その主定理を証明したことや R10 の述語の Sorted/Declared を確認したことではない。この限界は §7.1〜7.2 が明記している。

J70-5 だけは既存の切替条件の変更を伴う。plan は二体系の並置を移植の手順とし、L70 後に残す互換モジュールを適格な旧導出の埋め込みに限っている。全旧主定理と旧 Surface を残す推す案は、その条件のままの実装上の選択ではない。中2は、旧判断の型や埋め込みの定義域まで消す要求ではなく、残すものの範囲を承認済みの条件に合わせる指摘である。

最初に公開形・主定理の言明・表層・動的 pattern・交換版を固定する構成は、後続への波及を抑える順序である。ただし、群 A の収集の形には重1・重2を反映し、読者の棚卸しには重3の層を含める必要がある。R10 の述語の形成や構築・射影の代表を確認する際も、型検査できる Ty の値を作れたことと、性質1に使える導出を作れたことを区別する。未承認の規則や前提が必要なら plan の停止条件へ戻す。

### 5. 群の依存、完了の判定と Rust の開始

U→A、A の後の B/C/D/F1、C の後の F2、D と B を受ける E、D/E を受ける G、最後の Hという大きな順序は妥当である。C の最終の L70.19 が B を待つこと、消去の L70.33 が新しい check の L70.38 を待つことも、単位表には書かれている。「B と C が並行できる」は、C 全体が B に依存しないという意味ではなく、前半を並行できる意味で読む。

C と F2 が既存の合成表を変えるため直列とする判断も正しい。別の worktree の並行作業について、現状の表から衝突が確定する同一の本体ファイルは見つからなかった。ただし、重1〜重3の処置で触るモジュールが増えるので、その範囲を確定した時点で並行表を更新する必要がある。各群の既定 import の追加と取り込みは、既存の取りまとめの手順で調整する。

四分類、最終状態の型または値の定数の依存による読者の照合、private・生成宣言・構造体の欄を含む全宣言の差分は、L60の教訓を適切に取り込んでいる。名前が同じという理由だけで利用済みとせず、前段の分類の差も残す条件になっている。これらを段末で行う方針を維持してよい。

F-REG と F-CONN の区別、変えていない処理系と旧版の reader を使うこと、旧外部除外を保存することは正しい。重4は、その実行を受け入れる条件の欠けである。全比較の失敗は結果を保存しても解消しない。Rust 開始には、合成した主定理・表層・交換のレビュー、最終状態の監査と規範の一致に加え、所定の全入力の比較に成功した証拠が要る。

### 6. 見込みと枠の外の増分

49単位を再集計すると、全体は2840〜5005分、すなわち47時間20分〜83時間25分である。群別の見込みとも一致する。U02 の6件と Q2 の分は285〜540分、J50-1 は60〜120分、差し引いた枠の内は2495〜4345分、すなわち41時間35分〜72時間25分となる。plan の上端62時間を10時間25分超えるという J70-6 の計算も正しい。

枠を当面保ち、同種の本番追随の実績で見直す推す案は、過去の設計者の決定と同じ扱いである。短い型検査の秒数を証明の能動時間へ換算せず、L60 の実績比を一律に掛けない点もよい。今回の所見の処置で収集・受理と交換の担当範囲が具体化されるため、その範囲を既存の単位の内数に含めるか、増分にするかを再集計し、J70-6 に反映する必要がある。所要の実測を本レビューでは行っていない。

## 実行した検査

すべて読み取りの照合または指定の補助入力の検査である。Lean の補助入力は既存の `import Benitoite` を使い、既定ビルドの出力を上書きしていない。

| 検査 | コマンド・入力 | 結果 | 確認した範囲と限界 |
|---|---|---|---|
| 1 | `<repo>/formal/` で `lake env lean -M 12288 <tmp>/rv-l70-plan/review-check.lean` | 最終版は終了0、外側約0.7秒 | 公開 StateTy の保存の包装、F03と同じ8欄の拡張関係、空表と構成子1個／2個の網羅性の反例を確認。保存と反例の `#print axioms` は許可三公理だけ。主定理の残りを証明した検査ではない |
| 2 | 同、`providers-check.lean` | 終了0、外側約0.9秒 | 任意の P で合成表の Process.exit・Json.parse の署名が none、TaskGroup の isResource が false であることを rfl で確認。150名すべてを実行したという意味ではない |
| 3 | 同、下書きから複写した `counts-trial.lean` | 終了0、外側約0.6秒 | 下書きの新旧の構成子数を独立に再実行。場合の受持や健全性の証明とは区別する |
| 4 | 同、下書きから複写した `shapes-trial.lean` | 終了0、外側約0.6秒 | 言明と型の値の形を再確認。oracle の条件・開始の条件・述語の形成の不足を証明したものではない |
| 5 | 読み取り用 Python で plan の担当列・前段の残る段・tables の ID を照合 | 欠落0 | 担当34行、前段を含む和集合58行、追加O135で59行。申し送り78行と群別内訳も一致 |
| 6 | 同、単位表の見込みを再集計 | 一致 | 49単位、2840〜5005分。見積もりの実現性そのものの測定ではない |
| 7 | `git rev-parse HEAD`、`git status --short`、ソースと下書きの検索・読み取り | HEADは指定基準と一致 | レビュー前の未追跡変更は l70/。本書以外の追跡ファイルの変更は作っていない |

検査1の補助入力は計6回検査した。途中の4回の終了1は、補助証明の dependent elimination、ConDecl の暗黙引数の指定、簡約後の目標、照合関数の名前の修正による。途中の未完成の証明にはエラーに伴う sorryAx が表示されたが、それを反例や公理監査の成功の根拠には使っていない。最終入力は全宣言をエラーなしで検査し、表示した証明の公理依存から sorryAx が消えたことを確認した。本番のソースを変えてこれらの失敗を処置したものではない。

最終の補助入力の SHA-256 は次である。実行時の入力は指定の一時領域にあり、主要な言明と反例の構成は本書にも記した。

| 入力 | SHA-256 |
|---|---|
| review-check.lean | `0d2ddcbc4367507112b5e94d708a4323c27d09479a8e83c10ae7dd2868f2f5e6` |
| providers-check.lean | `c7c066af215a31ccac3c6146ec6ed712dea8a9a90045abe777dbae24b9d8e554` |
| counts-trial.lean | `35766b9bb7fc2125af7ec8ca78252adaefe02690eb30600e0eedcbbdf2d387f5` |
| shapes-trial.lean | `f9d3709cc2f356c5cfbd55475e23ceca303551a3c386878c45c040fcd1e1561c` |

最大常駐量は未取得であり、正式な RSS の採取はしていない。F-REG の成功、L70 の主定理の閉鎖、Rust 開始の許可は本レビューでは判定していない。

## 再レビュー（2026-11-05）

**結論: 不可**。重2の処置に、完全な B から主定理の信頼条件を供給する契約の不足が残る。重1・重3・重4・中1・中2の処置は可とする。

対象は [results.md](../l70/results.md) の「再開1」（2026-11-06）、[detail.md](../l70/detail.md) の指定箇所と [tables.md](../l70/tables.md) の修正行である。本体の作業木の plan「計画の変更と取りまとめへの確認点」の先頭にある J70-1〜6 は決定として扱い、詳細への反映だけを照合した。J70-7〜11 の選択と決定は評価していない。初回の6件の処置だけを確認し、新しい中・軽の所見は挙げていない。

### 処置ごとの判定

| 所見 | 判定 | 確認した処置と根拠 |
|---|---|---|
| 重1 | 可 | F03 (1)(2) が既存宣言の移送と追加宣言の検査後の合成を分け、`consClosed`・`dataInfoOld` と性質1からの `Additions` の供給を置いた。L70.05a は元の反例の拒否、網羅性・arity・変性・宣言の各読者の照合を要求し、完全署名を群 A の完了条件にした。L70.17〜.19 と tables の Map/Set・O005・O033 への受け渡しも対応する。移送の証明が既に閉じたとの判定ではない。 |
| 重2 | 不可（未完了） | 任意の B を受ける `Completion` と四区分を置き、固定の合成表だけでは仮定側の署名を持てない点は処置した。しかし F03 (3) の名前ごとの分割では、表全体の条件と仮定側の署名の条件を供給できる契約になっていない。下表の再重1を残す。 |
| 重3 | 可 | L70.03 が7入口から `CheckAccept`・`CheckInput.prepare`・`Exchange.Builtins`・`CheckTables` 等への経路を棚卸しし、受持単位へ割り当てる。L70.31b は型付けと受理の両結論を要求し、`noRules` を実入口に使わない。L70.40b・.41 と群 E・G が入力形成の層と新しい実入口への切替を受け持つ。 |
| 重4 | 可 | 第8.3節4・5が、所定の全コーパスの全比較の成功、不一致・未処置の失敗・未承認の省略と除外追加が無いこと、旧外部除外の保存、最終の定義・交換器・書き出し・入力・manifest・設定と結果の対応を Rust 開始の必要条件にした。tables の O086・O121 も対応する。J70-1 に従う書き出しだけの変更と、R10a 以降の開始も区別されている。 |
| 中1 | 可（指定の確認範囲） | 第2.9節に署名表を置き、一般 check の期待型 U と基の型 T、結果とエラーの形、生成判定関数の型引数と引数型、所属関数の引数型、述語へ写す際のリテラル制限を記した。L70.02 は表と Lean の宣言の対応に改まった。設計者の選択が残る欄を J70-9〜11 に分けたことを確認し、その選択自体は本判定に含めていない。 |
| 中2 | 可 | J70-5 に合わせ、F09・L70.03・.44 と群 G が旧 Surface・旧主定理の削除を要求し、残す旧 Release を C05 の依存の閉包に限定した。削除後の閉包、旧判断への逆戻り、残すモジュールの役割と読者の三条件があり、tables の O042・O159・L20-J5・plan-1103・L60-群D も整合する。 |

### 新たに特定した重の不足（重2の処置内）

| 番号 | 重さ | 場所 | 問題と根拠 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 再重1（重2の残り） | 重 | detail.md F03 (3)（321〜334行）、L70.05b・.18・.19、群 A・C、tables.md「L60-仮定150」 | 「`CoreAssumptions` の欄はどれも `B.sig b = some s` なら…」は現行の宣言と一致しない。`ConstraintAssumptions.lean` の `sat_unconstrained` は B.sat 自体の条件、`ref_get`・`ref_set` は B.refGet・B.refSet の lookup の存在、`effect_ops` は効果表から署名への逆向きの条件である。継承する `ExternalAssumptions` の3欄も B.externalResponse を読む。ところが `Completion` の一致の一覧に B.sat・B.refGet・B.refSet・B.externalResponse の条件がなく、C06 は固定の表についての証明なので、そのまま任意の B の証拠にはならない。仮定側の欄も δ/IO の応答等に限られ、成功 lookup に必要な `sig_scoped`・`admits_*`・`admits_sat` 等の供給元を示していない。従って、記した契約から `completion_core` の全結論を組み立てる方針が欠け、主定理を利用者へ当てる重2の処置は完了していない。 | 表全体の固定・一致または証拠で受ける条件と、名前ごとの署名・許容・応答の条件を分ける。`CoreAssumptions` の28欄と `TargetAgreement` の1欄について、合成済みの証明を移す欄、仮定側から受ける欄、表全体から供給する欄の対応を明記し、漏れのない `Completion`・`completion_core` の完全署名を L70.05b と群 A の必須条件にする。L70.18・.19 と tables の完了判定もこの契約を読む形にそろえる。四区分の扱いや J70-7〜11 の選択は変更しない。 | 読めば確定（提示契約と現行宣言の対応の欠け）。未実行の反例を根拠にはしていない。 |

この不足の照合では、`formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean`（108〜133行）、`SubstitutionContracts.lean` の `ValueAssumptions`・`TypeAssumptions`、`ExternalResponse.lean` の `ExternalAssumptions`、`BuiltinResponse.lean` の `ResponseAssumptions`・`TargetAgreement`、`StandardModelCore.lean` の `core`、`StandardModelResponse.lean` の表の構成を読んだ。新しい規則や公理を要求する指摘ではなく、既存の全条件を同じ P/B に供給する契約の補完である。

確認は文書・ソースの読み取りだけで行った。Lean・cargo・`scripts/check.sh`・記録を書き換える台本は実行せず、git の書き込みもしていない。本書の末尾以外は変更していない。実装の証明、F-REG の実行結果、L70 の段末の受け入れは判定していない。

## 3回目のレビュー（2026-11-06）

**結論: 不可**。再重1の処置は未完了である。29欄の供給元は示されたが、完成した表で合成済みの `io_op` を保つ条件が不足し、提示した `Completion` から `completion_core` を得る方針に反例が残る。

対象は [results.md](../l70/results.md) の「再開2」、[detail.md](../l70/detail.md) の F03 (3)・L70.05b・.18・.19・群 A・C・F2、[tables.md](../l70/tables.md) の該当行、[completion-trial.lean](../l70/completion-trial.lean) である。設計者の指示による最後の詳細レビューとして、前回の再重1の処置だけを確認した。既に可とした他の所見と J70-1〜11 の決定は再検討していない。中・軽の所見は挙げていない。

### 再重1の処置の判定

名前ごとの条件と表全体の条件を分け、`RowConditions`・`ReleaseOn`・`TableConditions` へ全29欄を割り当てた点は確認した。前回欠けていた `sat`・`refGet`・`refSet`・外部応答と、仮定側の署名・許容の条件にも供給元がある。外部の3欄は、任意の base を受ける `ExternalModel.external_assumptions` の適用例と合う。L70.05b と群 A の必須条件、L70.18・.19 と群 C・F2、tables の「L60-仮定150」「L60-S05」「L60-受口5」への反映も確認した。

ただし、同じ P/B で条件を満たすために必要な `effKind` の保存が、表の構成にも契約にも足りない。これは証明の実装が残ることだけを指す所見ではない。次表のとおり、現在の契約を満たす表について、予定した結論の一欄が偽になる。

### 重の所見（再重1の処置内）

| 番号 | 重さ | 場所 | 問題と根拠 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 3回目-重1（再重1の残り） | 重 | detail.md F03 (3) の `io_op` の行（326行）、`Completion.effKindFresh` と `composed_rows`・`completion_core`（354〜379行）、L70.05b・.18・.19、群 A・C・F2。completion-trial.lean の103・112行 | `complete.effKind l = (base.effKind l).or (A.effKind l)` は、既存の値が `none` のラベルでは A の `some` を採る。`effKindFresh` が保護するのは既存の `some` だけであり、対象なしの既存効果の `none` を保護しない。合成表の `print` は対象なしの `Console.Write` を使い、`ShapeOk` はその `effKind = none` を要求する。ところが、署名を足さず `A.effKind "Console.Write" = some .path` とした A は `Completion` と本番予定の `kinds` を満たせる一方、合成済みの `print` の `io_op` を満たせない。従って `composed_rows` と `completion_core` の予定の言明はこの契約では閉じない。 | 合成済みの操作が使う効果ラベルについて、`none` も含め `effKind` が一致する構成または明示した条件を置く。例えば既存の `base.effects l` が成功するラベルでは A の `effKind` を追加しない条件とし、`composed_rows` の完全署名にもその条件を渡す。任意の B への一般化も、合成済みの署名の一致だけでなく、`ShapeOk` が読む効果表の所属と `effKind` の保存を前提にする。L70.05b の完全署名と群 A の条件に反映し、L70.18 の `io_op` と `completion_core`、群 C・F2、tables の完了判定がその契約を読むようそろえる。 | 単独の Lean で反例を確認（下記）。本番予定の効果表の作り直しだけでは解消しないことも確認。 |

### 確かめた反例と検査の限界

指定の一時領域に `completion-trial.lean` を写した `completion-third.lean` を置き、次の A を補助定義した。名前の一覧 L は固定の小さい代用品にせず、合成済みと仮定側が交わらず、`"print" ∈ L.composed` を満たす任意の一覧として量化した。この二条件は、本番用の一覧に要求された条件でもある。

```lean
sig := fun _ => none
delta := fun _ _ _ _ _ => none
ioResponse := fun _ _ _ _ _ _ => False
isResource := fun _ => false
releaseResponse := fun _ _ => True
effKind := fun l => if l = "Console.Write" then some .path else none
```

`rvCompletion` は任意の P と externals について試行の `Completion L externals P A` を証明する。仮定側の署名は空なので `rows`・`domain` は満たされ、`release` は A の解放関係から供給できる。`rvFresh` は `effKindFresh`、`rvKinds` は本番予定の pure・io・exit の制限を証明する。`rvRowsImpossible` は、同じ表の合成済みの `RowConditions` が成り立たないことを `print` の `io_op` から証明する。

さらに、`rvCoreImpossibleAnyEffects` は、完成した表の `effects` を任意の関数に差し替えても `CoreAssumptions` が成り立たないことを証明する。`print` の署名を保つ限り、その `ShapeOk` の対象なしの条件は `effKind "Console.Write" = none` であるが、構成した表では `some .path` だからである。従って、results と detail が明記した「試行では効果表を合成表のまま置いた」という限界だけでは、この反例を説明できない。P も任意なので、`Includes` を後から加えるだけでは解消しない。

照合には `ConstraintAssumptions.lean`・`SubstitutionContracts.lean`・`ExternalResponse.lean`・`BuiltinResponse.lean`・`StandardModelCore.lean` を読み、関係する `StandardModelResponse.lean`・`StandardModelSignatures.lean`・`StandardModelSubstitution.lean`・`ModelConstraints.lean`・`ModelTargets.lean`・外部応答の構成と移送の定義も確認した。

元の `completion-trial.lean` の写しは、単独の `lake env lean -M 12288` で終了0を確認した。その後の補助証明は、最初に `release` の存在量化の証人を渡していなかったため終了1となり、その補助証明だけを修正して終了0を確認した。任意の効果表への差し替えと `kinds` の確認を加えた最終入力も終了0である。最終の `rvCompletion`・`rvRowsImpossible`・`rvKinds`・`rvCoreImpossibleAnyEffects` の公理依存は `propext`・`Classical.choice`・`Quot.sound` の範囲であり、`sorryAx` はない。SHA-256 は次のとおりである。

| 入力 | SHA-256 |
|---|---|
| completion-trial.lean（元の入力） | `fbb2a96ff60d385f35c20bd845ec7d69f83042776fe3f5c86c3d3ce601a780e2` |
| completion-third.lean（最終の補助入力） | `54d614aa2aae1adef86a8fed888c67d6c3588fff07145dc244485a93d3e585ae` |

元の試行は契約と言明の型検査であり、`completion_core` の証明ではない。本レビューも、主定理・利用者への系の実装の完成、F-REG、L70 の段末の受け入れは判定していない。記録を書き換える台本・cargo・`scripts/check.sh`・git の書き込みは実行していない。リポジトリ内の変更は本節の追記だけである。

## 取りまとめの追記

2026-11-06。L70 の詳細の下書きは Claude の計画担当が書き、独立レビューは Codex が行った。本レビュー（重4・中2）と処置の確認の再レビュー（重2 の残り）の後、設計者の指示で3回目を行い、`effKind` の上書きの反例が見つかった。再開3で完成した表の全14欄を確かめて穴4つを構成で閉じ、反例の A が新しい `Completion` を満たさないことを `reviewA_not_completion` で示した。取りまとめは `completion-trial.lean` を単独の Lean（`-M 12288`）で型検査し、終了0・sorry なしを確かめた。4回目のレビューは行わない。設計者の J70-1〜11 の決定は plan.md の「計画の変更と取りまとめへの確認点」にあり、plan の L70 の行・F-REG の行・切替の完了条件・見込み・結果の管理の行を results.md の案に従って改めた。

# B5 定義・言明・対象範囲の対応

## 比較の基準とレビューの状態

B1 直前の `cdd0cdc2` と B4 取り込み後の `d91a7e3f` を比較した。Lean の変更は 22 モジュールである。以下のパスは `formal/` からの相対であり、`Surface/`・`Release/`・`Exchange/` は `Benitoite/` の下を指す。

これは Codex による自己確認である。07-04「レビューと、見つかった誤りの扱い」に定める Claude Code（Opus 5.5）のレビューと設計者の合意は、この記録では未了とする。B1〜B4 の定義・言明をレビューできる資料と再現結果を揃える。G4 を閉じる判断はオーケストレータへ渡す（R51）。

## 型・エフェクト・境界

| 定義・言明と場所 | 前提・検査 | 結論と保証の範囲 |
|---|---|---|
| `Surface/Syntax.lean` の `tryResultDie`・`tryOptionDie` | 成功型 T、解決済みの構成子・exit、入力、任意の説明。Result だけ辞書とメソッドを持つ | 囲む戻り値 R を構文に固定しない。辞書・説明の局所参照は元の字句スコープにある |
| `Surface/Typing.lean` の `DieShowOk` | `DictEv.HasType … dict (Dict cl E)`、同じ cl のメソッド宣言、型パラメータなし、エフェクトパラメータなし、契約名 `[x]`、引数型 `[tvar 0]`、結果 String、効果は空 | 対象は成功型 T ではなくエラー型 E。辞書を実装・局所・上位辞書の既存の規則で検査する。標準の `Trait.Show` の束縛への名前解決そのものは証明しない（R49） |
| 同ファイルの `DieExitOk` | B.sig の種類 exit、所属 Process.Exit、型引数一つ・効果引数なし、NamesWF、`admits C [T]`、具体化後の `(code: Integer) → T ! {Process.Exit}` | 失敗側を任意の T にできる。Never と別の終了操作は追加しない。標準参照の選択は Rust の責務 |
| `E_TryResultDie` | 同じ data の二構成子、型引数二つ、引数が第 0・第 1 型変数、入力 `Result[T,E] ! ε`、閉じた現在の値の Exhaustive、DieShowOk、DieExitOk、説明の条件 | 任意の R・位置で結果 T、効果 `ε ∪ {Process.Exit}`。囲む R が Result であることも、R=T であることも要求しない |
| `E_TryOptionDie` | 同じ data、型引数一つ、成功の第 0 型変数と引数なしの失敗、入力 `Option[T] ! ε`、現在の Exhaustive、DieExitOk、説明の条件 | 同じ結果 T と効果の和。Show を要求しない。構成子の名前は既存の try と同じく抽象名 |
| 両規則の説明 | 同じ制約 C、`hideConts Γ`、R=None、非末尾位置、String、空の効果 | 直接 return と外側の resume を型付けできない。明示 lambda は自身の戻り先を作れる。直接の try 全般を禁じる構文検査は型付き表層の対象外 |
| 既存の `E_TryResult`・`E_TryOption` | 同じエラー型を持つ最内の Result/Option の R | 前提・結論を変更していない。Show のないエラー型の伝播を維持する。裸／明示 return は交換で同じ場合へ写る |
| `Expr.Exits`・`CheckPredicates.exprExits` | die の成功時には値が返り、終了操作は処理されうる | die 自体を必ず抜ける文に数えない。Unit の本体・末尾の既存の条件を緩めない |

01-12「die の先行モデル」の元の二規則・説明・脱糖表を照合した。末尾への別規則の追記による上書きはない。B5 では同節の「exit の参照の正しさ」を「exit の種類と型」に限定し、既存の応答・停止性に関する保証の範囲をその場で補足した。07-04 の交換契約の説明も同じ範囲に揃えた。Lean の規則を変える補正は不要だった。

## 脱糖・型保存・既存の終了

| 定義・言明と場所 | 前提 | 結論・実装で確認する事項 |
|---|---|---|
| `Surface/Desugar.lean` の二場合と `desugar_tryResultDie`・`desugar_tryOptionDie` | 任意の位置と表層式 | 入力を一つの let にし、成功側で内容を返す。失敗側だけに説明と原因を置くというコアの等式。具体的な評価結果や停止までの意味保存は結論しない |
| `dieFailure` | 失敗側の環境にある原因、元の環境で脱糖した任意の説明 | 説明ありは説明→原因→`exit[T](1)`、なしは原因→`exit[T](1)`。Option の原因は固定の文字列。説明や原因の計算を消さない |
| 同じ定義の rename | Result は入力と Error の二束縛、Option は入力の一束縛。説明の let があれば原因をさらに一つ移す | 元の自由変数と辞書を保ち、lambda 内の束縛は upRen で保護する。B1 の独立した展開例と corpus 10 の独立コアで比較する |
| `Lemmas/ReturnTry.lean` の `HasTypeC.withReturn` と相互補題 | 空のストア、元の R=None の型付け | 任意の R で同じ計算の型付けを得る。型付けなしに escape/resume を許す新しい外部仮定を置かない |
| `dieMessage_typed` | 隠した継続の環境、R=None の説明のコア型付け | 分岐の束縛を加え、自由変数を付け替えても型を保つ |
| `DieExitOk.app_typed`・`dieFailure_typed` | 既存 exit の条件、原因と任意の説明が純粋な String | 失敗側が T と Process.Exit の型を保つ。終了の実行・ホストの報告は結論しない |
| `tryResultDie_typed`・`tryOptionDie_typed`、`Lemmas/Typing.lean` の `HasType.desugar` | 元の表層型付け、整形式・範囲条件、組み込みシグネチャの範囲条件 | 脱糖後の型 T と効果の和を保つ。既存の全構文の型保存の前提・結論を維持する |
| `Lemmas/Scoped.lean`・`Invariants.lean` | T・入力・辞書・任意の説明の範囲条件 | 型・効果変数の範囲と clean の不変条件を新しい二場合でも保つ。`ShiftClean`・`SubstClean` は変更していないコアへの既存の補題を使う |
| `Release/Semantics.lean` の `E_Exit` と解放・ハンドラの遷移 | 既存の Builtins の署名、NoHandler、ioResponse | die 専用の遷移・事象・終了操作はない。exit に渡す整数は 1 だが、応答の n と引数の関係は既存の組み込みの応答に委ねる。型保存は、必ず 1 で停止するという定理ではない |

説明と Show が純粋でも、停止性は保証しない。ハンドラが終了を処理・再開・破棄する場合も既存の規則に従う。ホストの報告、タスク全体の取消、Direct/Request の所有、解放や flush の補足、報告の順序と一回性はコアの型保存の対象に追加していない。これらは B8〜B12 の Rust の実装と実行テストで確かめる。型・エフェクト・脱糖を Rust の die の「対象外」へ移す必要はない。

## checker と最終定理

| 定義・言明と場所 | 前提 | 結論と変えていない条件 |
|---|---|---|
| `Surface/Check.lean` の二場合 | 構成子・型引数の形、入力の型 T/E、閉じた網羅性、下記の三検査 | 成功した型は T、入力の効果と Process.Exit の和。R の一致を要求しない |
| `checkDieShow`・`checkDieShow_sound` | 辞書の型と対象 E、同じクラスのメソッドの契約、Input.Sound と原子の範囲 | DieShowOk。文字列 Show という名前の一致で代用しない |
| `checkDieExit`・`checkDieExit_sound` | 署名の種類・所属・数・名前・admits・具体化した型、原子集合に Process.Exit があること | DieExitOk と集合への包含。効果を有限の集合から落として受理しない |
| `checkDieMessageR`・`checkDieMessageR_sound` | `hideConts Γ`・R=None・非末尾位置・純粋な String、子の健全性 | 表層の説明の型付け。誤りの経路は入力 0・説明 1・Result の辞書 2 |
| `CheckSoundDie.lean` の二つの case と `checkCasesSound` | 既存の強い相互帰納法、Input.Sound と表層・環境・R の原子の範囲 | 新しい二場合も checkExpr の成功から HasType を導く。辞書や終了操作を信頼する新しい前提は加えない |
| `Surface/Theorems.lean` の `desugar_typed` | p.WellFormed、p.WellTyped、組み込みシグネチャの Scoped | 脱糖後の WellFormed・WellTyped・EffectsOk。以前の定理の言明を維持し、新しい二規則の項も扱う |
| `surface_effect_soundness` | 同じ型保存の前提、既存の Builtins.Assumptions、純粋な main | 到達状態から外部事象を伴う遷移と UnhandledOp がない。Process.Exit を含む main の停止をこの定理から主張しない |
| `Check.checkExpr_sound`・`checkDef_sound`・`checkImpl_sound` | 元の健全性・原子・入力の前提 | 表層の型付けと範囲を得る。実装メソッドの実名の契約条件を保つ |
| `CheckTables.checkProgram_sound`・`checkProgram_empty` と contracts の二系 | 構成子一覧・宣言の原子・本体の原子・実名・検査成功。empty は信頼表が空 | CheckedUnder、または Program.WellTyped。contracts は射影前の実装メソッドの実名一致も返す。標準ライブラリの信頼した本体の型付けまで証明しない |

Core/Release 全体、`Surface/Theorems`・`Lemmas/Program`・`Lemmas/Extensions*`・`Lemmas/ShiftClean`・`Lemmas/SubstClean`・`CheckSound`・`CheckInduction`・`CheckProgramSound`・`CheckTablesSound`、`Exchange/CheckInput`・`Builtins` は、基準と B4 の間でファイル全体に差分がない。変更された型付け関係は二規則の追加だけであり、既存の Return の前提を弱めていない。最終定理のシグネチャが同じという事実と、帰納型が新しい項を含むという意味の拡張を区別した。

## 交換形式と六入口

| 境界 | 検査する契約 | 信頼の範囲・後続作業 |
|---|---|---|
| `Exchange/Syntax`・`Version` | corpus 10 の新しい四タグ。die の型・構成子・辞書・メソッド・exit・入力・説明は必須。説明なしも null。別処置の欄・複数タグを拒否 | 9 は新処置なし、8 はさらに後の版の情報なしで互換にする。新版の欄を既定値で補わない。型表・網羅性は 3 |
| `Exchange/Convert`・`Expr.lambdaEffects` | 裸／明示 return は既存の表層、die は新しい二場合。入力→説明の順に lambda の効果を辿る | JSON の変換自体の意味保存・停止は証明していない。局所・実装辞書名と解決済み参照を独立入力で確認する |
| `desugarDiff` | 独立の期待コアとの比較。入力一回・説明→原因→exit、自由変数と辞書の移動 | B4 の 11 定義で確認。Rust の通常出力はまだ 9/3/3 であり、本物の die の出力との比較は B10a-3 |
| `builtinCheck`・`CheckInput.prepare` | 同じ corpus と型表 3、組み込みの署名、信頼表を照合 | ソースの標準束縛への名前解決は Rust の責務。R49 の抽象名を未検査の任意の署名と混同しない |
| `surfaceCheck`・`surfaceCheckAll`・`SurfaceCheck.walkExpr` | 型付けの受理と条件別の拒否。入力と説明を別の子として辿る。説明の R・位置・期待型を保持 | 既存の対象外 19 件と q11 1 件の分類を保ち、die の定義を除外へ移して成功させない |
| `coverageDiff`・`coverageProgramDiff` | 版 3 の網羅性を独立入力と全件の入力で比較 | corpus の新しい処置を直接入力とする入口ではない。これらが成功しただけで die の型や評価を検査したとはしない |

## 公理依存

[audit_axioms.py](audit_axioms.py) は `git ls-files formal` の全 Lean モジュールを選び、実際に import したことを環境の moduleNames で確認する。private・自動生成されたものを含む全宣言へ `Lean.collectAxioms` を呼ぶ。六入口は root の main が重なるため別々の環境で読む。未 import のモジュールと標準三公理以外の依存は失敗にする。通常の検査は改造ディレクトリの道具を参照しない。

全 115 モジュール（B1〜B4 の変更 22 モジュールを含む）、15,427 宣言を監査した。`propext`・`Quot.sound`・`Classical.choice` 以外の依存と sorryAx は 0。モジュールごとの結果と公理集合別の件数は [axioms-summary.json](axioms-summary.json) に残す。代表 44 宣言は [theorems.lean](theorems.lean) で直接照会し、結果を [theorems-axioms.txt](theorems-axioms.txt) に残す。

公理の一覧からは、定理の引数として置かれた動作の仮定や結論の弱化までは分からない。上の前提・結論の比較と、Core/Release の Assumptions・Semantics が変更されていないことも別に確認した。partial な交換処理の公理依存が標準の範囲でも、変換の正しさや停止性を証明したとは扱わない。

## 所定レビューへ渡す確認事項

1. R49 の抽象識別名と標準束縛への名前解決の境界で、E の辞書の契約と exit の種類・型の検査が意図どおりか。
2. 任意の R、成功型 T、純粋な説明と Show、外側の継続の隠蔽、lambda の独立した境界が、二規則と 01-12 の写しで一致するか。
3. 元のスコープからの rename と、説明→原因→exit のコアの定義が R3 を表すか。
4. 型保存・エフェクト健全性・checker の健全性の前提と結論が保たれ、報告の一回性・停止性・実行全体の意味保存を過大に主張していないか。
5. corpus 10 の必須欄・旧版の拒否・全走査・六入口の独立比較が、B10a-3 で Rust を接続するための契約として十分か。

自己確認では Lean の定義・言明の修正を要する不整合は見つからなかった。所定レビューの回答・修正・設計者の合意を記録してから G4 を完了し、B6 へ進む。

# D4 定義・言明の前提、結論、対象範囲

## 比較の基準

D の直前の `dc2c15a1`（G1 の修正後）と、D3 取り込み後の `c6d48439` を比較した。D1〜D3 で変わった Lean の 35 モジュールを対象とする。パスは `formal/` からの相対であり、`Release/`・`Surface/`・`Exchange/` は `Benitoite/` の下を指す。

これは Codex による自己確認である。07-04 所定の Claude Code（Opus 5.5）によるレビューと設計者の合意の完了記録ではない。G2 のレビューと設計者の合意（2026-10-16）を受けた Z2 の修正を以下に反映した。Z2 の修正後の確認はオーケストレータへ渡す。

## 定義と、現在の値に対する保証

| 定義・言明と場所 | 前提 | 結論・変更前との差 | 対象範囲と写し |
|---|---|---|---|
| `Release/Coverage.lean` の `CoverageView`・`closedView`・`shapesWithView` | `P`、構成子の一覧、型、パターン列、本体に有効な `DataName → Bool` | 元の形を同じ順序で残し、指定された data にだけ末尾の `future d` を足す。型引数や列のパターンから指定を推測しない | 01-12「網羅性」、02-05「本体の後の検査」。属性とパッケージから view を求める Rust の処理は未接続 |
| 同ファイルの `Shape.future`・`CoverageWitness.future`・`specialize_future_iff` | 判定用の将来の形 | 欄は 0 個、変数か `_` だけが覆う。既知の構成子、`other`、ガード付き包括分岐で代用しない | 現在の `Val`・`Inhabits`・`Pat.matchVal`・実行の規則には追加しない。`future` は反例になっても実在の値とは限らない |
| 同ファイルの `CtorsComplete`・`shapesWithView_cover` | 宣言された全構成子を含む一覧、現在の `Inhabits`、問いへの照合 | 任意の view でも、現在の値に対応する形と特殊化の証拠を得る。`CtorsComplete` は従来と同じ定義であり、future を実在する構成子として一覧へ要求しない | 余分な構成子名と重複は従来どおり許す。この定理単独は拡張後の値を量化しない。拡張後の網羅性は下記の別定理が扱う |
| 同ファイルの `usefulFuelWithView_none_sound`・`usefulWithView_none_sound` | 任意の view と燃料、`CtorsComplete`、判定が `none`、現在の型の値が問いに照合 | 元の行列のどれかに照合する。閉じた view という前提は加えない | 再帰では列を落とす経路も特殊化する経路も同じ view。燃料 0 は反例と打ち切りを返し、成功と数えない。燃料の十分性は従来同様に主張しない |
| 同ファイルの `checkMatchWithView_exhaustive_sound`・`irrefutableWithView_sound` | 完全な構成子一覧、任意の view、判定の成功 | 現在の値について元の `Exhaustive` を導く | ガードなしの選択肢だけを網羅に数える。`Result`・`Option` 自体を開く規則ではない |
| 同ファイルの `checkMatchWithView_unreachable_sound` と `Release/Lemmas/CoverageRuntime.lean` の二つの view 付き runtime 系 | 同じ view の判定が位置を報告、現在の値の型。runtime 系は `SlotsOk` または元の C-Match の型付け等も要求 | その位置の `AlternativeSelected`・`RuntimeSelected` を否定する。現在の実行に関する元の結論を保つ | 全既知構成子の後の外部の包括分岐は、future のために有用。先行する `_` による重複は引き続き検出する |
| `*WithView_closed` と `shapesWithView_closed` | 閉じた view | 旧入口と反例・位置・覆う分岐・燃料切れを含む結果全体が一致する | 判定の互換入口は閉じた指定を渡すラッパー。旧手順の列挙との等式は `shapesWithView_closed`。ラッパーの等式だけで過去の全入力の一致を主張しない |
| `Release/CoverageShow.lean` の `CoverageTypeDisplay`・`showWithTypes` | DataName ごとの型名と record の印、従来の構成子表示表 | `<future constructor of TypeName>` と `<future shape of TypeName>` を区別し、入れ子の表示を保つ | 表示の関数と独立入力で確認。表示文字列を解析して型の同一性を決めない |

`Release/Syntax.lean`・`Typing.lean`・`Semantics.lean`・`Assumptions.lean`・`Theorems.lean` と `Surface/Desugar.lean`・`WellFormed.lean` は、比較した二つのコミット間で差分がない。コアの値・型付け・遷移、組み込み動作の仮定、性質 2・3、脱糖の構成そのものを変更していない。

## 拡張後の値に対する保証（Z2）

`Release/CoverageExtension.lean` の `ConstructorExtension P P' view` は、既存の構成子の宣言を変えず、`P.cons c = none` である新しい構成子を view が真の型にだけ追加する関係である。構成子以外の表は `Inhabits` が参照しないため制約しない。

`usefulWithView_extension_exhaustive` は、`CtorsComplete P ctors`、`CtorsComplete P' ctors'`、この拡張関係、および `usefulWithView P ctors view [A] (ps.map (fun p => [p])) [wild] = none` から `Exhaustive P' A ps` を導く。入れ子とリストを含み、将来の実行結果の一致は主張しない。`Represents.future` は証明内で追加後の値を将来の形に対応させる関係であり、現在の `Val` と `Inhabits` には新しい場合を足さない。

## 表層の受理条件と、型保存への接続

| 定義・言明と場所 | 前提と選ぶ view | 結論・変更前との差 |
|---|---|---|
| `Surface/Syntax.lean` の `ViewExhaustive`・`.exhaustive` | 完全な構成子一覧の存在と、指定した view の有用性が `none` であること | 元の `Exhaustive D.patternProgram a ps` を導く。外部の「Rust が網羅と判定した」という仮定を加えていない |
| `Surface/Typing.lean` の `E_Match`・`B_LastPat`・`B_BindPat` と `CheckPatterns.lean` の `matchExhaustive`・`bindingExhaustive` | ソースの照合には `D.view`。checker は `CtorsComplete` と判定成功から `ViewExhaustive` を作る | 以前の意味的な `Exhaustive` だけの条件から、判定手順も要求する条件へ強まる。guard・lambda・lazy・入れ子にも同じ `D` を渡す |
| `CheckPatterns.lean` の `recordUpdateExhaustive`・`tryResultExhaustive`・`tryOptionExhaustive` | 合成した内部照合は明示的な `closedView` | ソース側の制限を内部の取得・更新・二分岐へ課さない。現在の `Exhaustive` を導く |
| `Surface/Lemmas/Records.lean` の `accessorPattern_exhaustive` と `Lemmas/Program.lean` | 現在の record の構成子の一意性等、従来の前提 | getter が直接生成するコア照合の `Exhaustive`。ソースの `ViewExhaustive` を通らない |
| `Surface/Syntax.lean` の `declarationsFor`・`withView_*`・`declarationsFor_*` | 任意の view | `patternProgram` と funs/cons/conFields/ops/effects/classes/impls の各射影は不変。`declarations` は閉じた互換入口 |
| `Program.WellTyped`・`ImplDecl.WellTyped`、`CheckTables.checkProgram`・`Check.checkImpl` | 関数は関数名、メソッドは実装名とメソッド名で view を選ぶ。上位辞書は本体ごとの指定に置き換えない | 同じ型を作者側と外部の本体で使い分ける。全体で一つの bool を共有しない。`checkImpl_sound` は任意の `views` を前提・結論の両方へ渡す |
| `Surface/Theorems.lean` の `desugar_typed` | `p.WellFormed`・`p.WellTyped B opPrim`・組み込みシグネチャの範囲条件 | 脱糖後の元のコアの `WellFormed ∧ WellTyped ∧ EffectsOk`。定理のシグネチャの外形は変更前と同じ。ただし `p.WellTyped` の意味には上記の追加条件を含む |
| 同ファイルの `surface_effect_soundness` | 表層の整形式と型付け、従来の `Builtins.Assumptions`、純粋な main | 到達状態から外部事象を伴う遷移と `UnhandledOp` がないという元の結論。将来の構成子の存在を仮定しない |
| `CheckProgramSound.lean` の `checkProgram_sound`・`checkProgram_empty`・contracts の系 | 従来の atoms/構成子/実名/検査成功の前提。empty の系は信頼するシグネチャ表が空であることも要求 | `CheckedUnder` は本体の view ごとの型付け、宣言の拡張、効果名の非衝突を返す。empty の系は本体ごとの `Program.WellTyped`。契約名の一致の結論も保持 |

旧 `Exhaustive` を持つあらゆる表層項が、新しい `ViewExhaustive` を満たすとは証明していない。閉じた view でも、判定が打ち切られる入力や値を作れない型の扱いでは、この逆向きを無条件に主張できない。D の保証は、追加の受理条件を満たしたソースから従来のコアの型付けを導くことであり、旧表層の型付け関係との同値性ではない。

旧入口・最終定理・checker の既存の定理 28 件の宣言を `:=` の前まで取り出し、空白を正規化して比較した。27 件は一致し、`Check.checkImpl_sound` の一件だけが `views` の追加で変わる。上の表のとおり、シグネチャが一致するものでも、参照する `WellTyped`・`CheckedUnder` の意味の変更は別に確認した。

## 交換形式と六入口の信頼範囲

| 場所 | 検査する情報と接続 | 保証しないこと |
|---|---|---|
| `Exchange/Syntax.lean`・`Version.lean` | corpus 9 の型の所属・標準型の識別、各本体の所属と view は必須。Lean で extensible かつ所属が異なる型を計算し view と完全照合。Result/Option の extensible を拒否し、現れる data 型の metadata の欠落、関数/メソッドの view の鍵の重複を拒否する | 原ソースから属性・所属・標準型の識別を解決する Rust の処理は信頼境界に残る。解決済みの情報から view を選ぶ規則は Lean でも検査する |
| `exchangeJson`・`closedDefaults`・`rejectFields` | 8/2/2 は新情報のない場合だけ閉じた既定を補う。旧版に新版の欄を空・false で混ぜても拒否する。網羅性 2 の従来の `typeName` は保持 | 版が古いことだけを拒否理由にしない。新版の必須欄を推測して補わない |
| `Exchange/Builtins.lean`・`CheckInput.lean` と各 JSON の入口 | 型表 3 の型表示と record/fields を照合し、corpus と型表の全宣言の六欄・順序を照合する。空表を含む新版の対応は入口で検査する | `CheckInput.prepare` 単独では旧版の空表も扱う。新版の整合をこの関数単独の保証としない |
| `Input.operationProgram`・`CheckInput.prepare` | 通常の関数と実装メソッドの指定をそれぞれ Program と Materials へ渡す。上位辞書の合成単位を関数の指定に数えない | 脱糖単独の入口は型表を引数に持たず、全構成子の型表との照合までは行わない |
| `CoverageDiff`・`CoverageProgramDiff` | 各 match/binding の view を再帰・網羅性・到達可能性・反例表示と燃料監査へ渡す | Rust が返した網羅性の答えを Lean の判定の前提にしない |
| `DesugarDiff`・`BuiltinCheck`・`SurfaceCheck.Main`・`SurfaceCheck.Batch` | 単独と全件の検査は同じ view を使い、通常の関数と実装メソッドを区別する | trusted な標準ライブラリの本体、型クラスを持つ一部の組み込み、外部宣言等の既存の対象外は証明しない |

JSON の読み取り・変換・六入口の実装は、正式モデルへ情報を渡す処理である。公理依存の検査を通ったことだけで、これらの partial な変換の停止性やソースとの対応まで証明したとは扱わない。正負の独立入力と Rust との比較が、この境界の検査を担う。現在の Rust の通常出力は 8/2/2 のままであり、9/3/3 の独立入力の成功と区別する。

## 公理依存の確認

[audit_axioms.py](audit_axioms.py) は、D1〜D3 で変わった 35 モジュールを Lean の環境の所属情報で選び、private と自動生成された宣言も含めて `Lean.collectAxioms` を呼ぶ。これは現在の Lean の `#print axioms` と同じ依存収集関数である。六入口は root の `main` が衝突するため一つずつ import し、所属モジュールと宣言名の組で重複を除く。通常の検査はこの道具や改造文書に依存しない。

実測は 7,003 宣言であり、依存は `propext`・`Quot.sound`・`Classical.choice` の範囲だけだった。内訳は公理なし 4,320、`propext` だけ 1,401、`propext` と `Quot.sound` が 453、`Quot.sound` だけ 1、三つ全てが 828。`sorryAx` その他の公理は 0。モジュールごとの件数と依存は [axioms-summary.json](axioms-summary.json)、代表 40 件と変更していない Core/Release の最終定理への直接の照会は [theorems.lean](theorems.lean) に残す。

これは D 前の記録（`formal/README.md`）と同じ標準公理の範囲であり、D 前の全宣言を別にビルドして公理集合の一対一の同一性を測定したものではない。組み込みの動作の仮定は Lean の axiom ではなく定理の引数であるため、公理一覧とは別に前提の表と宣言の差分を確認した。新しい `axiom`・`sorry`・`admit`・`native_decide` は加えていない。

## Z2 の交換と定数の範囲

corpus 9 の `Input.dataTypes` は、型の識別名ごとの `name`・`typeName`・`isRecord`・`extensible`・`package`・`builtin` を必須とし、属性しか使われない宣言も含む。`package` は解決済みの所属パッケージの識別名である。`builtin` は表示名とは独立した標準型の識別（`"result"`・`"option"`、それ以外は `"ordinary"`）であり、標準の Result・Option に extensible を指定した入力を Lean でも拒否する。型表 3 の `DataEntry` に同じ情報を保持し、型表を使う入口では corpus と全件・順序を含めて一致を確かめる。D6b は同じ宣言の並びから両方を出力する。

record の印は構成子のフィールドの有無と照合する。`SurfaceDef.coverageView` は関数・実装メソッドごとの型の識別名（`DataTypeInfo.name`）の一覧であり、表示名 `typeName` は使わない。

各 `SurfaceDef.package` と `ConstantEntry.package` は本体の宣言側の所属である。網羅性 3 は独立入力の各 case、プログラム単位の各 match/binding に `package` と同じ一覧を持つ。Lean は宣言の extensible が真で所属が本体と異なる型を計算し、受け取った view の集合と完全に一致することを検査する。未知・閉じた型・重複・指定漏れ・作者側の余分な指定を拒否する。関数名、実装名とメソッド名の組に重複した view も拒否する。

原ソースから所属・標準型の識別を解決するのは Rust の責務であり、その解決自体は証明しない。corpus 9 は型引数や定数の本体を含め、入力に現れる data 型がすべて dataTypes にあることを検査する。旧版は形式ごとの既知の欄を辿って閉じた既定を補い、新版の必須欄を補完しない。

定数は `public const` によってパッケージの外から参照できる。ただし、Rust の定数式の形の検査（`typeck/consts.rs` の `bad_shape`）は `match`・`if`・ラムダ等を E0433 で拒否する。

Lean の `E_Const` は定数式の形の制限を形式化せず、使用側の `D.view` で展開した本体を検査する。したがって任意の交換入力では、宣言側の view で検査する Rust と同じ受理結果を保証しない。現在の Rust が書き出す定数にはソース照合がなく、この違いは拡張可能型の網羅性の結果を変えない。corpus 9 の `ConstantEntry.package` は宣言側の所属を保持するが、`E_Const` の指定の切り替えには使わない。


## Z2 の公理依存の再確認

D4 と同じ環境からの依存収集を、作業ツリーの変更と新しい CoverageExtension を含む 36 モジュールへ適用した。import だけの Benitoite.lean は宣言を持たないため集計から外した。7,108 宣言の依存は引き続き propext・Quot.sound・Classical.choice の範囲で、予期しない公理は 0 だった。[Z2 の集計](z2-axioms-summary.json) に内訳を残す。追加定理と交換の定義への直接の照会は [z2-theorems.lean](z2-theorems.lean) で再実行できる。前節の 7,003 宣言は D4 時点の記録として保持する。

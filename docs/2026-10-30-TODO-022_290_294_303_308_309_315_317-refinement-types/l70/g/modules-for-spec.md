# 形式化のモジュールの表

以下の名前は `Benitoite.` の下を表す。

## 篩付き表層と区間の接続

| モジュール | 役割 | 読者 |
|---|---|---|
| `Exchange.CanonicalNames` | 同じ交換入力の標準ライブラリの属性・型と構成子の対応・公開宣言名の有限表から識別名を定める。文字列の値と型引数付きの不透明型の区別を保つ | `Exchange.CheckInput` |
| `Release.Refinement.Surface.SourceRename` | 表層の値の参照と型注釈を同じ改名で移す。内側の束縛を保護する。 | `Exchange.Convert`、`Interval.SurfaceSyntax`、`Interval.SurfaceCode` |
| `Interval.SurfaceSyntax` | 篩と範囲の注釈を消して区間の構文へ写し、照合対象の追加スロットを除く。旧構文を篩付き表層へ持ち上げる。 | `Interval.Exchange`、`Interval.SurfaceCode` |
| `Interval.SurfaceCode` | 区間の構文を篩付き表層へ持ち上げ、篩付き核の脱糖結果を作る。照合の腕の束縛を揃える。 | `Release.Refinement.IntervalConnection`、`FirstFailure`、`IntervalReport`、接続の具体例 |
| `Interval.ReportFlow` | 実解析の報告から正常値と失敗成分を読み、記録されていない return の値を未知とする。三成分の所属の証拠を添える。 | `Release.Refinement.IntervalReport` |
| `Release.Refinement.IntervalReport` | 実報告に条件付きの新核の接続を添える。同じ入力の解析・独立評価・型付き有限実行を結び、return の mark と同じ trace の失敗を扱う。 | `Interval.Exchange` と具体の正常値・return の適用 |

## 埋め込みの定義域と共有の定義

旧 `Release` の判断は埋め込みの定義域であり、篩付き核の言明を旧判断の言明へ戻す規範ではない。保持する74モジュールは、埋め込みの定義域の31、共有の定義とその依存の19、保持するモジュールの全宣言を閉じる24からなる。以下の三表は重ならない。

### 埋め込みの定義域（31）

`Release.Refinement.LegacyProgramTyping` と `LegacyStateTyping` は、プログラム・定義・impl・ストア・継続・状態の判断を篩付き核へ埋め込む。

| モジュール | 役割 | 読者 |
|---|---|---|
| `Release.Atom` | 埋め込みの定義域。型に依存しないエフェクトの原子 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.BuilderContents` | 埋め込みの定義域。専用セルの内容と論理上限 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Effect` | 埋め込みの定義域。型を保持するエフェクトの操作 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.EffectCoverDef` | 埋め込みの定義域。原子と効果の被覆の定義 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Lemmas.Canonical` | 埋め込みの定義域。閉じた値の形と、パターンの照合（契約名を持つコア） | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Lemmas.Inversion` | 埋め込みの定義域。型付けの逆転の補題（契約名を持つコア） | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.LocalRef` | 埋め込みの定義域。局所参照の番号と置換 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.NoFail` | 埋め込みの定義域。署名由来の NoFail 文脈と行の代入 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Normalize` | 埋め込みの定義域。型とエフェクトの正規形 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.Atoms` | 埋め込みの定義域。名前と行の関数の固定順序 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.Labels` | 埋め込みの定義域。型の木が持つラベル | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.Range` | 埋め込みの定義域。範囲と範囲の位置の符号と固定順序 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.SortUnique` | 埋め込みの定義域。全順序による整列と重複除去 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.Tree` | 埋め込みの定義域。ラベル付きの多分木の辞書式順序 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Order.Types` | 埋め込みの定義域。共有する型の辞書式順序 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.RangeInst` | 埋め込みの定義域。署名の範囲の変数の具体化と範囲の具体化の許容 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.RangeInstDef` | 埋め込みの定義域。署名の範囲の変数の具体化の定義 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.RangeWF` | 埋め込みの定義域。範囲の変数の整形式性と旧の定義との対応 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Semantics` | 埋め込みの定義域。実行の規則 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Subst` | 埋め込みの定義域。置き換えとパターンの照合 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Syntax` | 埋め込みの定義域。契約名を持つコア計算の構文 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeBounds` | 埋め込みの定義域。正規化前の型の範囲と整形式 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeRegularity` | 埋め込みの定義域。型の整形式と正規形 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeRows` | 埋め込みの定義域。Fail の内部を含む行の範囲 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeShift` | 埋め込みの定義域。型とエフェクトの変数移動 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeSubst` | 埋め込みの定義域。型と行の同時代入 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeSubstLemmas` | 埋め込みの定義域。正規化と同時代入の接続 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.TypeVariables` | 埋め込みの定義域。型と効果に現れる変数 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Types` | 埋め込みの定義域。共有する型とエフェクトの表現 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.Typing` | 埋め込みの定義域。型付け規則 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |
| `Release.WellFormed` | 埋め込みの定義域。型とエフェクトの変数の範囲 | `Release.Refinement.LegacyProgramTyping`・`LegacyStateTyping` の埋め込みと、その依存 |

### 共有の定義とその依存（19）

| モジュール | 役割 | 読者 |
|---|---|---|
| `Release.ApproxAdapter` | 共有の定義。旧 Release の値から、整数と Boolean だけを読む共有近似への写し | `Release.Refinement.ApproxAdapter` |
| `Release.Assumptions` | 共有の定義。形式化で仮定するもの | `Release.Lemmas.ContLemmas`、`Release.Lemmas.Regularity`、`Release.ShapeOk` |
| `Release.BuilderExec` | 共有の定義。専用内容に対する一操作 | `Release.Refinement.BuilderExec`、`Release.Semantics` |
| `Release.BuiltinTable` | 共有の定義。組み込みの制約とデータ型の要約の計算 | `Exchange.Builtins`、`Release.Refinement.StandardKeyTyping`、`Release.Refinement.Surface.Basic`、`Surface.Syntax` |
| `Release.Coverage` | 共有の定義。契約名を持つ型の網羅性判定と健全性 | `Release.Refinement.Surface.Syntax`、`Surface.Syntax` |
| `Release.EffectCover` | 共有の定義。効果の許可の関係と被覆 | `Release.Lemmas.TargetSound` |
| `Release.Examples` | 共有の定義。抽象機械の実行の例（契約名を持つコア） | `Release.Refinement.CurrentSignatureRows` |
| `Release.Finite` | 共有の定義。再帰的な有限支持の上で計算する型の比較と正規化 | 保持する定義の宣言の依存 |
| `Release.Lemmas.Basic` | 共有の定義。エフェクトの集合と型の包含の基本の補題 | `Release.Lemmas.Inversion`、`Release.Lemmas.Rename`、`Release.Lemmas.TyLemmas` |
| `Release.Lemmas.Closed` | 共有の定義。項が閉じていることの保存 | `Release.Lemmas.ContLemmas` |
| `Release.Lemmas.PresHelpers` | 共有の定義。保存の証明の補助（契約名を持つコア） | `Release.Model`、`Release.Refinement.LegacyStateInputs` |
| `Release.Lemmas.Rename` | 共有の定義。環境とストアの型付けの弱化 | `Release.Lemmas.ContLemmas`、`Release.Lemmas.Irrelevant`、`Release.Lemmas.NoFailContext`、`Release.Lemmas.Regularity` |
| `Release.Lemmas.TySubst` | 共有の定義。型とエフェクトの置き換えで型付けが保たれること（契約名を持つコア） | `Release.Coverage`、`Release.CoverageTypes`、`Release.Lemmas.StoreLemmas`、`Release.Lemmas.TySubstMain`、`Release.Refinement.TypeArgumentRegularity` |
| `Release.Model` | 共有の定義。仮定を満たす組み込みの関数の例 | `Release.Lemmas.Membership`、`Release.Refinement.CurrentSignatureRows`、`Release.TargetTable` |
| `Release.ModelHttp` | 共有の定義。検査済みの要求の値と Http の項目の実例 | `Release.Refinement.CurrentSignatureRows`、`Release.Refinement.ModelHttp` |
| `Release.Order.FiniteAtoms` | 共有の定義。有限支持での比較。入力の順序と重複によらず、符号が最小の相違点を選ぶ | `Release.Finite`、`Release.Refinement.FiniteCompare` |
| `Release.TargetTable` | 共有の定義。範囲付きの組み込みの関数の表の項目 | `Release.ModelHttp`、`Release.ModelTargets`、`Release.Refinement.ScopeLegacyContracts`、`Release.Refinement.TargetTable` |
| `Release.TypeComposition` | 共有の定義。一般の代入の一致と合成 | `Release.EffectCoverDef`、`Release.NoFail`、`Release.SubstEnv`、`Release.TypeCongruence`、`Release.TypeSupport` |
| `Release.TypeSupport` | 共有の定義。型と効果の再帰的な支持 | `Release.Finite` |

### 保持するモジュールの全宣言の依存（24）

| モジュール | 役割 | 読者 |
|---|---|---|
| `Release.Admissible` | 保持する定義の依存。宣言の全行を具体化する許容条件 | `Release.Lemmas.NoFailContext` |
| `Release.CoverageTypes` | 保持する定義の依存。網羅性が観察する型の形 | `Release.Coverage` |
| `Release.FailureEffects` | 保持する定義の依存。Fail の一要素の効果と型代入の対応。型の内部の正規化も保持する | `Release.Lemmas.TySubstMain` |
| `Release.Lemmas.ContLemmas` | 保持する定義の依存。継続の型付けの補題（契約名を持つコア） | `Release.Lemmas.FailureCont`、`Release.Lemmas.StoreLemmas` |
| `Release.Lemmas.FailureBase` | 保持する定義の依存。Fail 節の形と保存継続の末尾 | `Release.Lemmas.ContLemmas` |
| `Release.Lemmas.FailureCont` | 保持する定義の依存。Fail の伝播と捕捉するエラー型の一致 | `Release.Lemmas.Canonical` |
| `Release.Lemmas.Irrelevant` | 保持する定義の依存。利用不能な変数の位置と値置換 | `Release.Lemmas.FailureBase` |
| `Release.Lemmas.Membership` | 保持する定義の依存。値の所属の葉の規則（V-Checked）の補題 | `Release.ModelHttp`、`Release.ModelTargets` |
| `Release.Lemmas.MembershipBase` | 保持する定義の依存。値の所属の葉の規則（V-Checked）の逆転と範囲の拡大 | `Release.Lemmas.Membership`、`Release.Lemmas.TargetSound` |
| `Release.Lemmas.Names` | 保持する定義の依存。型付けから従うラムダの契約名 | `Release.Model` |
| `Release.Lemmas.NoFailContext` | 保持する定義の依存。NoFail の文脈を広げる弱化。Q は型付け判断のパラメータである | `Release.Lemmas.SubstTyping` |
| `Release.Lemmas.OuterC` | 保持する定義の依存。外側の型パラメータの並びを加える弱化（契約名を持つコア） | `Release.Lemmas.SubstTyping` |
| `Release.Lemmas.Regularity` | 保持する定義の依存。型の正しさの伝播（契約名を持つコア） | `Release.Lemmas.FailureCont`、`Release.Lemmas.OuterC` |
| `Release.Lemmas.StoreLemmas` | 保持する定義の依存。ストアの更新と、状態の型付けの補助の補題（契約名を持つコア） | `Release.Lemmas.PresHelpers` |
| `Release.Lemmas.SubstTyping` | 保持する定義の依存。値の置き換えで型付けが保たれること（契約名を持つコア） | `Release.Lemmas.PresHelpers`、`Release.Lemmas.TySubst` |
| `Release.Lemmas.TargetSound` | 保持する定義の依存。対象一致の条件から観測の許可を導く | `Release.Model`、`Release.ModelHttp`、`Release.ModelTargets` |
| `Release.Lemmas.TyLemmas` | 保持する定義の依存。型の正しさ、ずらし、置き換えの補題 | `Release.Lemmas.Closed`、`Release.Lemmas.Regularity` |
| `Release.Lemmas.TySubstMain` | 保持する定義の依存。型とエフェクトの置き換えで型付けが保たれること：本体（契約名を持つコア） | `Release.Lemmas.Canonical` |
| `Release.LocalTyping` | 保持する定義の依存。局所参照の種類と共有番号の対応 | `Release.Lemmas.Rename` |
| `Release.ModelTargets` | 保持する定義の依存。二つの信頼条件を満たす組み込みの関数の実例 | `Release.ModelHttp`、`Release.Refinement.CurrentSignatureRows` |
| `Release.ShapeOk` | 保持する定義の依存。IO の項目の形の検査と旧の `io_op` | `Release.Lemmas.TargetSound`、`Release.Lemmas.TySubstMain`、`Release.TargetTable` |
| `Release.SubstEnv` | 保持する定義の依存。型と行の一般の代入 | `Release.RangeInst`、`Release.TypeScopedSubst` |
| `Release.TypeCongruence` | 保持する定義の依存。変数の範囲を用いる代入の一致 | `Release.TypeScopedSubst` |
| `Release.TypeScopedSubst` | 保持する定義の依存。範囲内の型と行の代入 | `Release.EffectCover`、`Release.FailureEffects`、`Release.Lemmas.TyLemmas` |

## 区間の入力となる表層の構文

次の3モジュールは型注釈を消した区間の入力データを定める。表層の checker・型付け・脱糖の判断を含まない。

| モジュール | 役割 | 読者 |
|---|---|---|
| `Surface.Syntax` | 型とエフェクトの注釈を持つ式・文・腕・節、パターンと位置のデータ。区間へ渡す構文を定める | `Interval.Identity`、`Interval.SurfaceSyntax`、区間の独立評価と解析 |
| `Surface.BuilderSyntax` | 構築器の種類・操作・スロットの構文データ | `Surface.Syntax` |
| `Surface.FormatSpec` | 解析済みの文字列補間の書式と、書式化の内部頭のデータ | `Surface.Syntax` |

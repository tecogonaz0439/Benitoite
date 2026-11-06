# 入力形成と実入口の接続

基準は `d9cf242d97ac3b93c439177da0e67a625a87f626`。開始は2026-11-07 04:50:08 JSTである。能動時間と待ちは分離していない。

## 先行確認

旧の入力形成の層は、`Exchange.CheckInput`・`Builtins`・`Observe` と旧 `Surface.CheckTables`・`CheckTablesSound`・`Release.CoverageShow` の六層である。新しい `CheckTables`・`CheckMaterials`・`CheckMaterialsSound` が既定の新表層にあり、宣言材料の全件性と成功からの型付け・受理の接続を持つ。単に旧表を名前の置換で写さず、これらの材料を使う。

新しい `Check.Input.B` は `.custom B`・`.standard P`・`.unrestrictedRanges B` の構成元から表を返す。`.standard P` が非計算的な応答の定義も含む標準表を返すため、選択する関数全体が `noncomputable` であり、新しい実入口もそのままでは実行ファイルのコードにできない。既存の定義本文を変えず、`.custom B` に特化した式を定義上の等号だけで展開して通常の定義として生成できるか、確認用入力 [native-specialize.lean](native-specialize.lean) で確かめる。未証明の実装の置換は使わない。

親担当が固定ソースと生成済み環境の不一致を見つけたため、先行する生成済み環境での結果を完成の証拠にしない。ソースを揃える既定ビルドが終わるまで、単独の Lean は実行していない。

## 入力の署名

| 境界 | 予定する形と根拠 |
|---|---|
| 交換の準備 | 交換の新しい型を変換し、同じ材料から `Program`・`Declarations`・有限名一覧・原子一覧・受理入力を作る |
| 表の構成元 | `.custom (StandardModel.complete L T A)`。完成した表と checker の表を別の未証明の等号で接続しない |
| checker の支持 | 仮定側の署名の支持と、合成側の全署名の支持を分け、`Check.Input.Sound` の全欄を供給する。`StandardSupport.complete` は仮定側が空のときだけ使える |
| 実入口 | `CheckAccept.checkProgramAccepted` と、同じ入力の `CheckDeclarations.checkDef`・`CheckAccept.acceptDef` を読む。規則なしの受理を実入力の代わりにしない |

## 未完の義務

| 単位・義務 | 状態 | 残る接続 |
|---|---|---|
| L70.40b 六層の移植・継承 | 調査中 | 新交換の Convert と材料の接続 |
| L70.41 七入口 | 未着手 | 実行可能な checker と `q.Sound`、新網羅性・新脱糖・新区間の接続 |
| 完成表の名前と署名 | 調査中 | 交換側の data の識別名と、合成署名の標準名の対応 |

## 有限な許容判定の契約

[finite-admits-obstruction.lean](finite-admits-obstruction.lean) は、有限の原子一覧に現れないエフェクトを関数型の内部に置く反例である。`normTyEq [] source targetBase = true` でも、`PublicNames.checkAdmits [] [source,target]` は偽となる。任意の生の型の関数を有限の比較で一致したことにせず、実際の呼出しが元から持つ有限支持を使う。

| 公開する内部契約 | 変更前 | 変更後 | 理由と範囲のない場合の系 |
|---|---|---|---|
| `Check.Input.Sound.admits` と二つの `head_sound` の許容の前提 | `AdmitsSound B dec := ∀ b s C ts, B.sig b = some s → dec b C ts = true → s.admits C ts` | `AdmitsSoundOn atoms B dec := ∀ b s C ts, B.sig b = some s → dec b C ts = true → Ty.SupportList (· ∈ atoms) ts → s.admits C ts` | 前提の支持は `HeadInputsSupport` と `normalizedArguments_support` から供給する。型付けの規則、Step、主な十言明を変更しない。元の強い `AdmitsSound` を残し、`AdmitsSound.on` が任意の有限一覧について新しい前提を供給する。範囲パラメータを持たない元の適用も同じ系で得る |
| 材料からの健全性 | `Materials.input_sound` が強い許容の前提を受ける | 同じ公開署名を保持し、新しい `Materials.input_sound_on` を追加する。元の入口は `ha.on` で新しい入口を呼ぶ | 元の関数の全引数と結論を保持する。実入力は、ソースから供給する有限支持を持つ新しい入口を使える |

変更は CheckArguments・CheckInput・CheckOpenArguments・CheckMaterials の四ファイルに限った。親担当が並行する群Dの現行ファイルと監査対象を読み取りで比べ、この四つが再開10の本文の対象でないと確認した後に行った。四ファイルの局所 Lean は2026-11-07 05:22:15〜05:22:20 JST、全て終了0・警告0、合計5.21秒であった。入力と出力の指紋は [admits-local.json](admits-local.json) にある。依存全体の再検査は群末の既定ビルドで行う。

## 計算する入力と規範の入力

構成元の全定義をメタ処理で展開する案は採らない。再帰関数を `Nat.brecOn` まで展開すると、通常の実行コードの生成を使えず、定義上の等号だけではコード生成の問題を解決できなかったためである。未証明の `implemented_by` は追加していない。

代わりに、表を直接持つ `NativeCheck.Input` と規範の `.custom B` 入力への射影を置き、計算部分を同じ構造再帰で再生成する。生成元の規範のソースは変更しない。[generate_native.py](generate_native.py) が計算の定義だけを写し、元のコメントと証明は写さない。元の式とブロックの再検査との等号を `CheckNativeConnection` で確かめる。現時点は最小の組の局所検査中であり、実入口の切替の完了ではない。

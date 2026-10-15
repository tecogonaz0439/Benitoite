# N7 コアのレビュー

## 範囲と結論

N2〜N7 の `NamedRelease` の定義と言明を、旧 `Release` と design.md「Lean の型とコア」・「標準ライブラリと組み込みの契約名（Q10）」に照合した。名前の保持、既存の前提・結論、証明の対象、具体モデル、ビルド登録について、N7 の範囲に未解消の所見はない。処理系と新しい交換形式の対応は後続作業で検査する。

## 定義と保証の対応

| 対象 | 確認した内容 | 結果 |
|---|---|---|
| 共有型と宣言 | `Ty.fn`・`Val.lam`・関数・操作・メソッド・組み込みに名前を保持し、`NamesWF` で長さと一意性を要求する。型付きコアの局所変数は de Bruijn の番号である | 一致。契約名を局所変数名へ読み替えない |
| 適合・置換 | `Ty.Le` は名前と引数型・戻り値型を同じに保ち、エフェクトだけの包含を認める。型・項の置換と変数移動は名前を変更しない | 一致。旧型への変換や名前の消去を使わない |
| 型付け・整形式 | ラムダ・宣言の参照・メソッド・ハンドラの節で名前の整形式を要求し、型付けの反転・正則性・置換で保持する | 一致。名前の正しさを主定理の新しい外部の仮定にしない |
| 実行と保存 | `Step` の全 64 場合を維持し、名前付きコアの `preservationE` で証明する。実行は位置で値を置換する | 一致。名前は実行時の分岐・並べ替えの条件にならない |
| 進行 | 実行・分岐選択・エラー・終了の四状態、関数・操作・辞書・メソッド・ハンドラ・再開・セル・遅延値・解放を含める | 一致。`progressE` から元と同じ形の `progress` を導く |
| エフェクト健全性 | 空の末尾エフェクトの無事象と未処理の操作の否定を、初期状態と遷移列の保存から導く。IO・終了・解放の全事象を対象にする | 一致。停止性や外部操作の成功は結論に加えない |
| 組み込みの境界 | `Builtins.Assumptions.sig_scoped` は名前を含む整形式を要求する。`StoreShape` は公開名と `update` の内側の `value` を持つ | 一致。N2 の `Model.assumptions` が具体的に前提を満たす |
| 具体例 | `Examples` 26 例、`BuiltinTable` 17 例、`Model` の最終定理を使う二例について、旧入力の型・応答・期待結果を保持する | 一致。名前の欄だけを追加し、負の例も維持 |
| ビルドと公理 | 新モジュールをルートに登録し、N7 の定理の公理依存を旧モデルと比較する | 一致。全 29 定理で同じ依存。新しい公理・`sorryAx` なし |

## 最終定理の前提と結論

名前空間の接頭辞以外は、四定理の明示・暗黙の引数と結論の形を旧モデルと同じに保つ。共有型を `NamedRelease` のものに替えており、旧型を経由しない。

| 元の定理名 → 新しい定理名 | 維持する前提 | 維持する結論 |
|---|---|---|
| `Release.step_sound` → `NamedRelease.step_sound` | `Builtins.Assumptions`、可能な IO・解放の応答を選ぶ条件、有限ストアの空き場所を選ぶ条件、`StateTy`、`step = some (l, s')` | `Step P B s l s'` |
| `Release.progress` → `NamedRelease.progress` | `Program.WellTyped`・`EffectsOk`・`Builtins.Assumptions`、`StateTy P B s` | `s.Final ∨ ∃ l s', Step P B s l s'` |
| `Release.preservation` → `NamedRelease.preservation` | `Program.WellFormed`・`WellTyped`・`EffectsOk`・`Builtins.Assumptions`、`StateTy P B s`、`Step P B s l s'` | `StateTy P B s'` |
| `Release.effect_soundness` → `NamedRelease.effect_soundness` | 同じ四つのプログラム・組み込みの条件、空のストア・環境・エフェクトかつ `R = none` の `HasTypeC`、`ClosedNoEffVars`、初期状態から任意の `s` への `Steps` | `(∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s` |

`Progress` の 19 定理、`EffectSound` の 6 定理、`Theorems` の 4 定理の名前の一覧を照合した。全 29 言明の差は、共有型の名前空間と `HasTypeV.canonical_fn` の関数型・ラムダの名前の欄だけである。全 29 定理の `#print axioms` は同名の旧定理と一致し、既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。

## 所見と対処

旧 `BuiltinTable` がシグネチャの表を持たないことと、N7 の列挙された対象に `Model`・ビルドのルートが含まれないことを確認した。R30 に従い、制約・要約の計算を移し、具体例の組み込み表に契約名を付け、R25 の二例とビルド登録を追加した。公開・内部の全宣言の読み込みは N15 の範囲に保つ。

R29 の二補題を再定義せず、同じ `Progress` に残りの証明を加えた。`StepSound` の import は変更せず、`Theorems` が `EffectSound` を直接 import することで最終定理を接続した。

検査結果と後続作業は [N7 実装記録](../n7-implementation.md) に記す。

# N34 の成果物と N34a への申し送り

N34 は一般入力の交換形式を統一し、正式モデルを切り替える差分を準備する。現在の正式モデルと設計書の写しには patch を適用しない。

## 全入力の基準

`prepare_exchange.py` は N33 の manifest から新しい基準を導く。引数を省くと基準だけを作り、書き出し先を引数に渡すと、実出力の全入力について版以外が不変であることも厳密に比較する。対象外理由や期待件数を実際の報告から作らない。

```sh
python3 docs/2026-10-14-TODO-247-lambda-and-named-arguments/n34/prepare_exchange.py target/desugar-diff/n34-final
```

| 成果物 | 内容 |
|---|---|
| `exchange-manifest.json` | 新形式と旧入口の独立入力の版・件数・単一入口の結果・対象外理由 |
| `routing-manifest.json` | 全一般入力の識別子・除外理由・対象内の定義数・網羅性の件数 |
| `routing-changes.json` | N33 から版だけを移した 399 件 |
| `exchange-derivation.json` | N33 の新旧の基準を合算した件数と保持した条件 |
| `implementation.md` | テストの作成時の関門、実行した検査と結果 |

全一般入力は `named-programs-*`、独立した網羅性の全件は `named-all-corpus.json`、関数型の独立した二件は `named-corpus.json` に出す。幅付きの Rust 出力は `width-smoke/` に分ける。旧形式の root の corpus と各表は、旧入口だけを検査する独立入力であり、一般入力の manifest に加えない。R99・R100 に判断の理由を記した。

## 切り替え patch のレビュー

`prepare_switch.py` は現在の作業ツリーを読み、`n34a-switch.patch`・`switch-manifest.json`・`theorem-correspondence.json` を作る。モデルは読み取りだけである。`core-rules.md` は 01-12 に反映する規則の写しで、独立した設計変更を加えない。

```sh
python3 docs/2026-10-14-TODO-247-lambda-and-named-arguments/n34/prepare_switch.py
git apply --check docs/2026-10-14-TODO-247-lambda-and-named-arguments/n34/n34a-switch.patch
```

機械的な移動は `switch-manifest.json` の `moves` の 95 ファイルである。各ソースと移動後のハッシュを記す。定義・言明・証明は名前空間と実行ファイル名の置き換えだけであり、定理を弱めない。`theorem-correspondence.json` は 793 宣言について元と移動後のファイル・名前・言明を対応付ける。主な保証の前提・結論・範囲の対応は、既存の formal-rules.md「N16 の最終定理の前提・結論・範囲の照合」と合わせて確認する。

| 保証 | 移動後の名前 | 前提・結論の扱い |
|---|---|---|
| 進行・保存・遷移・エフェクトの健全性 | `Release.progress`・`preservation`・`step_sound`・`effect_soundness` | 名前を含む型付け・整形式と既存の組み込みの仮定を維持する |
| ラムダ名を型付けから導くエフェクト健全性 | `Release.effect_soundness_noLamNames` | 外部のラムダ名の条件を不要とする既存の結論を保持する |
| 性質 1 と表層のエフェクト健全性 | `Surface.desugar_typed`・`surface_effect_soundness` | 全表層の範囲条件と型付けを保持する |
| 実行可能な表層検査の健全性 | `Surface.Check.checkExpr_sound`・`checkBlock_sound` など、`Surface.CheckTables.checkProgram_sound` | 表層の型付けへの接続を保持する |
| 実装側の実名一致 | `Surface.Check.checkImpl_contracts`・`Surface.CheckTables.checkProgram_contracts` | 射影前の実装名を検査する境界を保持する |
| 網羅性・選ばれない選択肢・束縛 | `Release.checkMatch_exhaustive_sound`・`checkMatch_unreachable_sound`・`irrefutable_sound` | 構成子の完全性と有用性の既存の条件を保持する |
| ソース位置から宣言位置への値の配置 | `Surface.CallOk.recordFields_source` | 挿入を含む保存値の配置の等式を保持する |

手動の差分は、lake とルートの登録、六つの Main とラッパー、検査の接続、01-12・07-04・07-03、独立入力のテストの移行である。01-12 の写しには、宣言名の `NamesWF` が整形式から従うこと、型注釈内部・`coreNames`・未使用の `conFields` の範囲条件、実装名の検査の境界、値の配置の保証と評価順の確認の区別を含める。

別のディレクトリ `target/n34-switch/` に patch を適用し、正式名の `lake build`・独立入力テスト・`guarantees.lean` の公理依存を確認する。`guarantees.lean` はビルド済みの検査先の formal/ から `lake env lean` で実行する。許す公理は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲とし、`sorryAx` を認めない。

## N34a と N34b

N34a では patch のレビュー後に、正式モデル・全入口・規則の写しを同じ変更で切り替える。適用時には manifest の変更前のハッシュと `git apply --check` を確認し、途中の変更で古くなっていれば再生成する。patch には生成済みの参照と幅付きの正常・異常入力のテストの切り替えも含む。既存の期待値を緩めない。

N34b の削除対象は `cleanup-manifest.json` に列挙する。N34a では Named の一時ファイルの登録を外し、実体は次の作業に残す。Rust の旧形式の分岐と独立入力も同様である。段階 A の Core と、一般入力・独立した新形式の入力・破損入力の検査は保持する。

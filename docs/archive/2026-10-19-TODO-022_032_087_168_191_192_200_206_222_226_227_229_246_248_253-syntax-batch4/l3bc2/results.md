# L3bc2 の実装結果

## 状態と基準

L3b 全体を完了した。専用項の型付けと実行を全主定理へ接続し、既定 import と六実行ファイルを含む既定ビルドが sorry なしで通った。前回の [l3b/results.md](../l3b/results.md) の未完了部分を本作業で閉じた。

B_WORK と開始時 HEAD は `a73eba2c14dcdbead08b8e19335faec64ca812c4`（開始時の `git merge-base HEAD san_benito`）である。開始時の差分はなかった。コミットと docs/todo/ の編集は行っていない。

## 変更

- 前回の typing-draft.patch を基に C_BuilderLet/C_BuilderOp を接続した。旧 not_builderLet/not_builderOp は新しい規則では成立しないため、専用宣言・操作の逆転へ替えた。既存の通常値と計算の型付け規則は変更していない。
- 付け替え・通常置換・置換の一致・整形式・型代入・局所範囲・ラムダ名・通常参照の捕捉の全読者を更新した。LocalSubstOk/LocalSubstAgree は分類された専用番号の対応を要求する。instantiate_local は通常引数と同じ数だけ残る専用番号を詰める。LocalCtx.substTyAt は List の要素型も写し、StoreFix の専用場所の条件は StoreTy.WF から証明する。
- PresMain と Progress の専用項の枝を、ストア拡張・二種類の置換・一操作の全域性/型保存/閉性へ接続した。上限超過と抽象 Byte の範囲外は元のストアの error へ進む。通常 State/Fail/escape/release と ContTy を保った。
- 新しい LocalInvariant は、現在の項・枠・ストア内の保存継続の専用参照の有効性、通常セルの値・専用 List の要素・同じ Ψ の型付き通常値の捕捉禁止を StateTy から導く。local_steps_invariant は任意の有限接頭辞へ接続する。capture_local_valid/resume_local_valid は後続の型と局所有効性に加え、既存の専用セルの場所・内容を保つことを示す。既存の破棄・解放枠・copy の構造の補題は保持した。
- BuilderExamples に、専用 new と通常 let の番号対応、実在する Model での全有限接頭辞、節内の別セルを越える保存・再開、専用 loc の捕捉拒否とラムダ内の新しい宣言を加えた。01-12・07-04・formal/README と公理一覧を同じ状態へ更新し、Exchange のコメントを現在の Reference 脱糖に合わせた。

## 検査

途中は関係する Lean 対象だけをビルドした。Inversion/Rename/LocalScope/NoFailContext、Regularity/OuterC/SubstTyping/Irrelevant/TySubstMain、Progress/EffectSound/Theorems、LocalInvariant/BuilderExamples、Surface.Theorems/CheckSound/BuilderCapture/BuilderNoCapture、Release.Model を順に確認した。途中の全実行の時間・出力は保存していない。

途中の失敗は、新しい導出の場合分けの不足、局所環境の対象の推論不足、局所分類表への型代入と通常束縛の追加の交換、依存する match の簡約不足であった。各読者の専用の場合と対応の証明を追加して修正した。初めのリポジトリ根での lake 起動は作業ディレクトリが誤っており、formal/ へ直した。未証明の宣言・追加仮定・import の除外で通していない。

完了検査は次の指定の dry-run と実行を各一度行った。

```sh
scripts/check.sh --level work --base a73eba2c14dcdbead08b8e19335faec64ca812c4 --only formal_build,spec_examples,spec_tally
```

| コマンド・確認 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| 上記に --dry-run | 0、計画の三単位を選択 | 0.016秒 |
| 上記の実行（rtk proxy 経由） | 0。仕様集計・自己検査、仕様例7件、既定 lake build と sorry 拒否が成功 | 90.066秒 |
| formal/ で lake env lean l3bc2 の七つの公理入力（各 rtk proxy 経由） | すべて0、合計202件。sorryAxなし、標準の三公理だけ | 各1.404〜1.454秒、並行実行 |
| 主定理・公開検査器・Assumptions・Model の15ファイル、判断の定義と既存規則の比較 | 基準と一致 | 未計測 |
| git diff --check と Lean ソースの穴・公理宣言の検索 | 成功、穴と公理宣言なし | 未計測 |

実コマンド・作業ディレクトリ・終了状態・外側の時間は各 *-timing.json、出力は同名の .log、公理の正確な import と名前は七つの *axioms.lean に保存した。公理の比較は [axioms-comparison.json](axioms-comparison.json)、契約は [public-contract-comparison.json](public-contract-comparison.json)、ソースの検索と確認は [source-audit.json](source-audit.json) にある。元の l3b の入力・出力は変更していない。

公理確認の内訳は、主定理/公開検査器等40件、有界整数3件、Coverage10件、局所環境27件、専用項28件、既存の専用内容/ストア69件、新しい接続25件である。旧 not_builder の2件を除く既存175件の公理出力は l3b と一致する。新しい逆転2件と新しい接続25件にも標準の propext・Classical.choice・Quot.sound 以外を使わない。toolchain は leanprover/lean4:v4.34.1 である。

Rust のソースと生成 Skill の入力（01-02・標準ソース・診断表）は変更していない。Rust の全 lib/clippy/fmt、gc-stress、check-formal.sh、stage/change/release は実行していない。

## 判断と仮定の意味

[decisions.md の R149](../decisions.md#r149-専用項の型付けと局所対応を既存の補助証明へ通す) に、局所対応・置換の一致・型代入と StoreFix の内部の一般化を記録した。計画の機能の範囲からのずれはない。主定理の前提・結論、Builtins.Assumptions の欄・量化、公理を変更していない。StoreTy.Sub は同じ定義を Typing へ移し、局所の対応を Rename より前から使えるようにした。

HasTypeVQ の既存規則と Def/ImplDecl/Program.WellTyped・StateTy・StoreOk・ContTy の定義の文字列は基準と一致する。ただし C_BuilderLet/C_BuilderOp の追加により、ラムダ内部で新しい構築器を使う導出も値の判断に入る。外側の bound/専用 loc は引き続き空 Δ と hideBuilders で拒否する。したがって R133 の Assumptions の意味の比較には、この内部の導出の拡張も含める。

既存の Release.Model.assumptions はファイル全体が基準と同一であり、新しい判断でも通った。このモデルは Reference.get/set だけを宣言するため delta/io の該当条件には対象がなく、release は none を返せる。モデルの証拠へ値の強化を追加していない。強化を使うのは SubstOk.hideBuilders と FailureExamples.toResult_typed の捕捉境界である。主定理とこの定義を通じた意味の比較は RV2 に渡す。

## テストの作成時の関門

専用コアの型付けと run を境界にする。通常 let の後の専用番号を詰め忘れる退行は dedicatedProgram_run、再開時に外側のセルを節内のセルと取り違える退行は resumedProgram_run が捕まえる。後者は戻り値 beforeafter、外側と節内の二つの専用セル、継続セルの used、解放事象のないことを独立した期待値で確認する。専用 loc の捕捉を許す退行と、内側の新しい宣言まで一律に拒否する退行も別々に確認する。Model 上の全有限接頭辞の例は、新しい型付きプログラムを既存の主定理と局所不変条件へ接続する。

既存の操作ごとの例には new と通常 let の番号対応がなく、表層の継続の例は Reference 脱糖なので専用コアを通らない。新しいテスト用の入口・フラグ・差し込み口は設けていない。既存の例・期待値・assert・ignore は変更していない。実行例は燃料5/40、専用セルは最大2個であり、大きさを性能の判定に使わない。Rust の本番とテストの行数の増減は0、既存 BuilderExamples への追加は69行、新規 LocalInvariant は164行である。

## 後の作業への申し送り

- L4a は State/refs を保って表層の Reference 脱糖だけを専用コアへ切り替える。C_BuilderLet/C_BuilderOp、LocalRenOk/LocalSubstOk と instantiate_local、LocalCtx.substTyAt を使う。表層とコアの番号の対応は恒等である。
- 現行交換は専用コアを表現せず、fromComp は unsupported を返す。表層が Reference 脱糖の間は既存出力を保つ。新しい交換と State/refs の除去を完了したとは扱わない。
- LocalStateInvariant の保証は論理セルと通常値の捕捉禁止である。物理 GC・即時返却、参照先まで含む copy の不変は主張しない。

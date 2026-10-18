# L1a: 効果の参照APIの機械的な整理

基準 B は `e0530ec1db05a90ec2f22cb2659b06386409b7c1`（開始時 HEAD）である。開始時の作業ツリーは空であった。plan.md の L1a・共通の関門 K と、design.md・decisions.md の R6・R13・R16 に従った。コミットと docs/todo/ の変更は行っていない。

## 変更

`Release/Syntax.lean` に `Eff.mem`・`Eff.test`・`Eff.ofAtoms`・`Eff.ext`・`Eff.ext_test`・`Eff.shift`・`Eff.substAt c ts es` と、四つの所属補題を置いた。`Eff.test` は判定器と交換器が使う真偽値の参照、`Eff.ext_test` は既存の真偽値の等式による証明を `Eff.ext` へ渡す補助である。`mem_substRho` へ既存の所属の展開の証明をまとめ、`substRho_true` はその補題を使う。

Release・Surface・Exchange の直接の効果への適用を `mem` または `test` へ、関数による効果の構築を `ofAtoms` へ、効果の `funext` を外延性のAPIへ移した。APIの定義と補題の外に残る `funext` は、環境・操作表・型の変換等についてのものである。`Ty.shift` と検査器の対応する操作から `Eff.shift` を呼び、型と項の代入と検査器の写しから `Eff.substAt` を呼ぶ。01-12 に所属の記法、07-04 に現在のAPIと表現の対応を反映した。

`Eff := Atom → Bool`、型付け・実行の規則、定理の前提は保った。`shift` は恒等、`substAt` は c と ts を使わず `substRho` を呼ぶ。新公理・仮定・sorry は追加していない。Rust は変更していない。

## 既存例の変更の関門

1. 守る契約は、有限支持上の所属・包含・等号・行の置き換えと、既存の型付け・脱糖・実行の例の成立である。
2. 所属の極性、支持集合の外の原子の除外、置き換え後の原子、潜在効果の保持を変える退行で、既存の正負の例または一般の定理の証明が失敗する。
3. 既存例を同じ入力・同じ命題のAPI記法へ移し、新しい例は追加しない。変更対象の7ファイルにある `example` は変更前後とも287件であり、削除・期待値の緩和・ignoreへの変更はない。
4. テスト専用の差し込み口は加えていない。追加したAPIは型・項の代入、型付け、判定器、交換器と既存証明が使う。

## 検査

作業途中は formal/ で、変更した構文、代入・型付けの補題、Release/Surface の定理、検査器の健全性と例、交換器の関連ターゲットだけを `lake build <ターゲット…>` で検査した。最初の参照APIの証明と機械的な置換には、式の括弧とAPIの展開の不足があり、該当箇所を修正した。途中にリポジトリの根からlakeを呼んだ一回は `Operation not permitted` で終了1となり、実行場所をformal/へ直した。後半の次の指定は、整理前・整理後とも成功した。途中の外側の時間は計測していない。

```sh
cd formal
lake build Benitoite.Release.Theorems Benitoite.Surface.Theorems \
  Benitoite.Surface.CheckProgramSound Benitoite.Surface.CheckToolsExamples \
  Benitoite.Surface.CheckExamples Benitoite.Surface.CheckCounterexamples \
  Benitoite.Exchange.Convert
```

作業末の指定は次のとおりである。実行前に同じ B と選択へ `--dry-run` を付け、名指しした検査だけが選ばれることを確認した。外側の時間は `/usr/bin/time -p` の real である。

| コマンド（リポジトリの根で実行） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base e0530ec1db05a90ec2f22cb2659b06386409b7c1 --only formal_build,spec_examples,spec_tally` | 1 | 17.54秒 | spec_tallyの自己検査と集計、spec_examplesの7件は成功。formal_buildでModelの所属の記法の修正漏れを検出 |
| 同じ基準で `--only formal_build`（修正後） | 1 | 3.48秒 | Modelは成功。続いてSurface/Examplesの所属の記法の修正漏れを検出 |
| 同じ基準で `--only formal_build`（再修正後） | 0 | 3.66秒 | 既定の `lake build` がライブラリと六入口を含めて成功し、sorryの宣言を検出しなかった |
| `git diff --check` | 0 | 0.02秒 | 空白の診断なし |

Modelの失敗は、`Eff.mem` の仮定に真偽値の補題 `single_no_rho` を適用する際の展開不足であり、所属の命題を展開して修正した。Surface/Examplesの失敗は、単集合の所属を原子の等号へ移す証明の展開不足であり、`Eff.mem_single` を適用して修正した。両方とも命題と前提を維持している。成功済みの仕様集計と仕様例は再実行していない。

## 計画からのずれと申し送り

実装範囲とAPIの意味に計画からのずれはなく、Rの判断の追加は不要であった。作業末の三検査は一度実行し、失敗した formal_build だけを修正後に二度再実行した。途中の関連ターゲットにModelとSurface/Examplesを含めなかったため、この二箇所の修正漏れは作業末に検出された。

L1bはこのAPIと既存の規則を基準に、R14・R15の決定に従って表現と正規形を移行できる。`Eff.substAt` の c と ts、`Eff.shift` の k と c は署名を先に用意したものであり、型を含む効果の処理はL1bへ残す。Rustの全lib・clippy・fmt、gc-stress、check-formal.shの全比較は今回の割り当てに含めず、実行していない。

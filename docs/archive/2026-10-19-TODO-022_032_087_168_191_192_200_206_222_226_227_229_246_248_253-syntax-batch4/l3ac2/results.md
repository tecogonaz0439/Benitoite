# L3ac2 の実装結果

## 完了した範囲と基準

L3a の残作業を完了した。前回の [L3a の記録](../l3a/results.md) に続く実装であり、専用計算項の構文・全走査・局所環境・範囲・捕捉の補助と、既存の全定理・モデルを同じ既定 import へ接続した。専用項の型付け規則と Step の規則は追加していない。CellOk の builder は偽、実行関数 step の専用項は none のままである。

B_WORK と開始時 HEAD は `6330ab4b6368c9e1bdc75dd2c0763cefa09be8bf`（開始時の `git merge-base HEAD san_benito`）である。開始時の差分はなかった。コミットと docs/todo/ の編集は行っていない。

## 変更

- `Release.Syntax/Subst/Semantics/WellFormed` と全構文読者へ Comp.builderLet/builderOp を追加した。σ/ρを同時に持ち上げ、通常束縛の instantiate でも残る局所番号を詰める。型代入は List の要素型へ通す。VarsIn/VarsInNoLamNames、宣言、枠、セルに共有番号の局所深さを通した。
- `Typing` の計算・分岐・通常節・Fail節へ局所環境を追加した。HasTypeCL は内部の入口、既存の HasTypeC と省略表記は空Δである。通常束縛で LocalCtx.extend、捕捉境界で空Δ、handle 本体で同じΔを使う。通常値の判断にはΔを足していない。
- 付け替え・σ/ρの置換・型代入・弱化・逆転・NoFail の内部補題を一般化し、進行・保存と実行関数の健全性、旧 Reference 脱糖・表層の性質1・公開検査器・既存モデルへ接続した。新項が型付き計算に現れないことは not_builderLet/not_builderOp で示す。
- `Release.LocalScope` に LocalScoped/NoFreeBuilders と builder_value_no_free_local を追加した。ラムダの内部も調べ、NoFreeBuilders 自体は内側の専用束縛を許す。現在の型付けからの補助の帰納は、専用項がまだ型付けされない段階の帰結である。
- 通常変数の Reads/Captures と交換の fromComp にも両項を明記した。交換は現行形式で専用項を unsupported とし、旧出力を保つ。01-12・07-04 と formal/README を実装済みの定義へそろえた。生成 Skill の入力である構文の章・診断の表・標準ソースは変えていない。

## 検査

作業末の名指し work は dry-run と実行を各一度行った。Rust のソースは変更していないため、Rust の全 lib/clippy/fmt、gc-stress、check-formal.sh、段・改造全体の検査は追加していない。

| コマンド・確認 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 6330ab4b6368c9e1bdc75dd2c0763cefa09be8bf --only formal_build,spec_examples,spec_tally --dry-run` | 0、名指しの三単位と理由を確認 | 0.009秒 |
| 上と同じ指定の実行（dry-run なし） | 0、spec_tally の自己検査と集計・仕様例7件・既定 lake build、sorry 警告なし | 19.982秒 |
| `lake env lean ../D/l3ac2/axioms.lean`（formal/ 内、Dは本改造のディレクトリ） | 0、40件が前回の一覧と完全一致 | 1.027秒 |
| 同 `integer-axioms.lean` | 0、3件が前回と完全一致 | 0.997秒 |
| 同 `coverage-axioms.lean` | 0、10件が前回と完全一致 | 1.024秒 |
| 同 `local-axioms.lean` | 0、29件が前回と完全一致 | 0.985秒 |
| 同 `dedicated-axioms.lean` | 0、新しい局所補題・具体例28件。標準の三公理の範囲、sorryAx なし | 0.992秒 |
| 主定理・仮定・公開検査器の言明の照合 | 関係する14ファイルが基準とファイル全体で同一 | 未計測 |
| `git diff --check` と formal/Benitoite の sorry/admit/追加公理の検索 | 差分検査0、sorry/admit と追加の公理宣言なし | 未計測 |

実コマンド・作業ディレクトリ・終了状態・時間は `*-timing.json`、全出力は対応する `*.log` に保存した。公理の正確な import と名前は五つの `*-axioms.lean` と `axioms.lean`、比較は [axioms-comparison.json](axioms-comparison.json)、公開の契約の照合は [public-contract-comparison.json](public-contract-comparison.json) にある。[work.log](work.log) と [work-dry-run.log](work-dry-run.log) が完了検査の記録である。toolchain は `leanprover/lean4:v4.34.1` である。

途中は関係する対象だけの `lake build <対象>` を使った。Closed、Names、Rename、SubstTyping、Irrelevant、TySubstMain、Inversion、LocalScope、SubstExamples、Surface の Scoped/Sequence/Theorems/BuilderExamples/CheckSound、Release の Theorems/Model、Exchange.Convert を局所で確認し、最後に既定 import を集める `lake build Benitoite` が182 jobsで成功した。後者と交換の局所成功の出力は `local-imports.log`・`local-exchange.log` に保存した。途中の各試行の外側の時間は未計測であり、作業末の時間に合算していない。

途中の失敗は、深さを固定した範囲補題、局所環境を固定した相互帰納の構造再帰、持ち上げたρの不一致、末尾の既定のΔ/ρを省略した局所の have の推論失敗、構文を場合分けする読者の不足であった。それぞれ、範囲と添字の一般化・束縛数からの不等式・正しい持ち上げ・必要な添字の明記・両項の場合の追加で修正した。代表の失敗出力は `local-*-failed.log` に保存した。未証明の穴、公理の追加、import の除外、期待値の緩和で通す処置はない。

## R133 と既存モデル

Release/Assumptions と主定理のファイルは B_WORK と同一である。通常値のラムダ本体は空Δかつ隠したΨで検査する。既存の全モデルの探索で、Release の Assumptions の構成は `Release.Model.assumptions` の一件であった。同じ任意の Program について証明が通り、公理の出力も前回と一致した。Reference.get/set だけの宣言なので delta/io の欄には対象がなく、release は none を返せる。今回もモデルのこの証拠に値の強化を使っていない。モデルのメソッドの具体例には空Δの注釈を一つ明記しただけで、既存の定理の言明と期待値は保った。Core のモデルは変更していない。

前回と同じく、値の強化を使うのは捕捉境界への通常置換を準備する SubstOk.hideBuilders と、任意Ψの Fail 節を作る FailureExamples.toResult_typed である。通常値を返す組み込みの仮定は追加していない。

## 計画上の判断と申し送り

表現上の小さい判断は [decisions.md](../decisions.md) の R144〜R146 に記録した。R144 は末尾の利用不能な分類位置の省略と末尾の既定Δ、R145 は局所深さと通常束縛を除くρ、R146 は専用項を型付けしない段階の補助の一般化である。主定理の前提・結論、Builtins.Assumptions の欄・量化、公理は変えていない。

後続の L3b は、専用項の型付け・Step/step・BuilderCellOk を接続する。`not_builderLet/not_builderOp` と、任意の深さ・場所の条件を結論する `localRefs` の中間の補助は、その接続時に型付けから得る種類対応・空Δと hideBuilders の捕捉境界からの証明へ替える。置換と付け替えにもΔの対応を追加し、型代入を List の種類へ通す。これらを、専用項の実行・保存が既に証明されたことの根拠にしない。表層の Reference 脱糖は L4a まで維持する。現行交換形式の専用項の書き出しは L7 の版の切り替えまで未対応である。

前回保存した dedicated-comp-draft.patch は当時の未採用案の記録として残す。続行の際に再適用する必要はない。

## テストの作成時の関門

既存の置換例の持ち主 `Release.SubstExamples` に、通常束縛除去後の残る局所番号と、new のσ 0=Unit/ρ 0=専用の場所の二例を追加した。いずれも通常/専用の束縛を交互に置き、カーネルの等式で期待する出力を直接確かめる。ρを接続し忘れると前者の番号が残り、後者では場所に変わらない。従来の型だけの置換例は専用参照を持たないため、この失敗を捕まえない。追加の公開入口やテスト用の差し込み口は作っていない。旧 assert・例・期待値・ignore は変更していない。

formal/ のソースとREADMEの差分は追加1166行・削除729行（新しいLocalScopeを含む。記録ファイルを除く）である。このうち具体例は二件の追加であり、既存のテストを削除したものはない。

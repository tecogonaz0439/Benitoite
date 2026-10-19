# L4b 実装結果

2026-10-18、Codex。作業L4bを完了した。基準B_WORKは `65b5073d10f9ded82d21be685701aa47b4a3bc46`（L4a取り込み）、ブランチは `mod009/L4b`。開始時の作業ツリーはクリーンだった。

## 変更と完了条件

- `Surface/Lemmas/Typing.lean`: 七判断のdesugarを、Aligned Γ ΔとClean C.length ΔのもとでfillBuilders Γ Δを結論する相互再帰へ移した。同じΔの子の帰納自体がセル環境を結論する。通常束縛・パターン束縛・説明/ガード・空Δの捕捉境界と型束縛のある節を接続し、脱糖の関数と番号を保った。HasType/HasBlock.desugarは空Δの系とした。
- `Invariants.lean`: cleanの相互帰納へClean Δを渡し、通常束縛とlazyの空Δの境界で保存した。`Scoped.lean`は既に任意Δ・nt/pe/nvについて環境に依存しない結論を示す相互帰納だったため、強い言明と全証明をそのまま保ち、セル環境でも使える根拠をコメントへ加えた。
- `Builders.lean`: up_id・aligned_binds・under_binds・HasTypeCQ.renameId・CompTypesQ.renameIdの5補題を証明した。`CallHead`・`Dict`・`Extensions`・`ReturnTry`は、表層の辞書がΓ、式の帰納がセル環境である場合を恒等のRenOkで接続した。辞書だけを移し、セル環境でコアの値化と呼び出しを組み立てる。
- 式列・各要素・穴・ブロックのdesugar_of_exprの4補題も、preserveの仮定と帰納の結論をセル環境へ移した。`BlockSequence.lean`は独立したブロックの帰納を保ち、`Program.lean`は空Δの系へ接続した。01-12・07-04へ規則と保証の対応を写し、具体化をdecisions.mdのR149に記録した。

[規則ごとの照合](rule-review.md)に七判断の全78規則と、clean/scoped・関連補題・関門Kの確認を残した。全体を従来のΓで帰納した後でrenOkにより移す証明にはしていない。

## 言明と前提の意味の比較

[contracts-comparison.json](contracts-comparison.json)の11ファイルは開始版とバイト単位で一致する。Surface/Typing.lean全体が同一であり、七判断・公開abbrev・Def/ImplDecl/Program.WellTypedの文字列も変更していない。WellFormed、Input.Soundを含むCheckLemmas、公開11件とprogramの健全性、性質1・表層のエフェクト健全性、Builtins.Assumptionsを保った。ReleaseのTy/Eff/Step、表層の脱糖の関数、ShiftClean/SubstCleanも変更していない。

内部のHasTypeQ/HasBlockQ等のdesugarは必要なAligned/Cleanを前提とする。空Δの入口ではその条件を内部で閉じ、fillBuilders Γ [] = Γにより従来の環境で結論する。主定理の前提/結論の変更、公理・Builtins.Assumptionsの追加、結論の弱化はない。

## 検査

作業末の計画指定を一度実行した。コマンドの完全な引数・作業ディレクトリ・基準・終了状態・外側の時間は [check-times.json](check-times.json)を正とする。以下のDは本改造のディレクトリである。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| `scripts/check.sh --level work --base 65b5073d10f9ded82d21be685701aa47b4a3bc46 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.010秒 | [指定の三単位を選択](work-dry-run.txt) |
| 同じ指定から`--dry-run`を除いたwork | 0、18.950秒 | [spec_tallyの自己検査・集計、仕様例7件成功・失敗0・ignore 0、既定のlake build成功・sorryなし](work.txt) |
| `lake env lean <D>/l4b/axioms.lean`（formal/） | 0、0.790秒 | [READMEの全30定理](axioms.txt)の公理依存は開始版と一致 |
| `lake env lean <D>/l4b/internal-axioms.lean`（formal/） | 0、0.795秒 | [新規5補題・一般化した帰納・関連の系と補助・scopedの計31件](internal-axioms.txt)は標準三公理の範囲内 |
| `git diff --check`、規則・前提・文書の読み取り照合 | 0 | 差分と対応に問題なし |

公理依存は [axioms-comparison.json](axioms-comparison.json)のとおり、[開始版に含まれるL4aの出力の写し](axioms-start.txt)と、L1開始時の保存出力にバイト単位で一致した。axioms.leanはREADMEの全一覧とL4aの入力に一致する。開始版で新たに実行した出力とは扱っていない。過去のビルド結果を今回の検査の代わりには引用していない。sorryAx・Lean.ofReduceBool・独自公理の依存はない。

途中はInvariants、Typing、BlockSequence、Theorems、CheckSound、CheckProgramSound、Examples、FailureExamples、Monad2Examplesとその依存対象だけを局所ビルドした。最終の局所ビルドは成功した。途中の失敗は、内部前提追加後の呼び出し、Γとセル環境の辞書、bindsの長さと通常束縛の分類表、空Δの導出と節の接頭部の一致、補助のimportと証明の構文によるものであり、上記の対応補題と全読者の更新で修正した。途中の外側の時間は未集計である。最初のrtk proxyはOperation not permittedで起動できず、以後はスキルのフォールバックに従って通常のコマンドを使った。

Rustを変更していないため、Rust全lib・clippy・fmt、全統合・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表は変更しておらず、gen_skillの再生成は不要である。

## 計画からのずれと申し送り

R149は補助補題と辞書の環境の具体化、および既に任意Δだったscopedの扱いを記録する。scopedには不要な内部条件を追加せず、ShiftClean/SubstCleanにもΔを加えなかった。型束縛を越える節では空Δを使うため、fillと型のshift/代入の新しい交換補題は要らない。AtomsIn/Singleはこの作業の型保存・clean・scopedには不要であり、検査器の内部の帰納へ接続するL4cの担当とする。範囲・停止条件・検査割り当ての変更はない。

次はL4c。CheckInductionのmutualSoundnessのmotiveとstrict/relaxedの支持保存へ、Aligned/Clean/AtomsIn/Singleを通す。L4bの七判断のdesugarはhAlign・hΔを先頭の明示引数として受ける。空Δの利用側はHasType/HasBlock.desugarを使える。通常束縛はaligned_value/clean_value、パターン束縛はaligned_binds/all_values、境界はaligned_empty/clean_empty、説明・ガードはaligned_hideContsとfillBuilders_hideContsを使う。

L5/L6では専用構文の新しい場合を今回の相互帰納へ追加する。専用操作・宣言、捕捉禁止の定理、検査器の四条件、Rustとの接続は今回の完了に含めない。BuilderFreeを使うL4aの検査器の移行用証拠はこの作業では変更していない。

テストの削除・assert削除・期待値の緩和・ignoreの追加は0件である。Typing.leanの既存3例は主張の文字列が開始版と一致し、一般化した補助補題へ反射的なRenOkの証明を追加しただけである。例の意味・入力・実行結果は変えていない。有限テストを追加せず、全導出を対象とする一般の補題で契約を確認した。Rust本体・Rustテストの行数差分は0、形式化ソースの差分は追加405行・削除286行である。

コミット、取り込み、docs/todo/の変更は行っていない。

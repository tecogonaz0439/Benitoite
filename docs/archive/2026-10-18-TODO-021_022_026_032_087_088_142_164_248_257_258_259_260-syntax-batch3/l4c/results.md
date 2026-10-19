# L4c 実装結果

2026-10-18、Codex。L4cを完了した。基準B_WORKは `319cc56c0f39da57c9c0f4db7aae275af2bf3150`（L4b取り込み）、ブランチは `mod009/L4c`。開始時の作業ツリーはクリーンだった。

## 変更

- `CheckLemmas.lean`: Aligned/Clean/AtomsIn/Singleの組をBuilderInvariantとして定義し、空Δ・通常束縛1個/複数・hideContsで保存する補題を、L3の補題から導いた。acceptと成功経路の分解の補題も任意Δへ一般化した。
- `Check.lean`: design 14.5の表に従い、子へ同じΔ、通常束縛を増やしたΔ、捕捉境界の[]を渡すようにした。検査条件・返す値・状態操作・失敗の文言と経路・順序は変えていない。
- `CheckComputeAtoms/Cases/Calls/Control/Pipe/Sound.lean`: strict/relaxedの支持保存の帰納を任意Δと四条件へ移した。節の型探索、反復、継続の要求も同じ契約で支持を保つ。
- `CheckInduction.lean`・`CheckSoundBasicExpr/Sequence/Calls/Collections/Control/Die.lean`: 健全性の七判断と節の型探索のmotiveへ四条件を通し、子の帰納から必要なΔの型付けを直接得るようにした。mutualSoundnessとcheckCasesSoundを接続し、内部の式/ブロックの単一Failも任意Δで導いた。R_builders/of_builderFreeによる移行は健全性の証明から除いた。
- `CheckSound.lean`・`CheckSoundDicts.lean`: 公開11件・単一Fail2件と宣言本体で、空Δの四条件を内部で閉じるようにした。programの読者は既存の署名のまま接続できた。
- 01-12と07-04に現在の証明範囲を反映し、実装時の具体化をdecisions.mdのR150へ記録した。

[帰納・束縛・境界・関門Kの照合](rule-review.md)を保存した。任意Δでの相互帰納を完了し、公開入口だけの検査や、旧構文で得た全体の導出の移行では代用していない。

## 言明と定義の意味

[contracts-comparison.json](contracts-comparison.json)に次を記録した。

- 公開の健全性11件と単一Fail2件は、前提・結論の文字列が開始版と一致する。
- 七判断・公開abbrev・Def/ImplDecl/Program.WellTypedの実体を持つTyping.lean、WellFormed、programの健全性、性質1・表層のエフェクト健全性、Builtins.Assumptions等のファイルは開始版と一致する。Input.Soundの全欄も一致する。主定理と公開契約の前提/結論を、定義を通じた意味も含めて保つ。
- 検査器の九つの相互再帰関数は、再帰に渡す分類表の引数だけを[]へ戻すと本体全体が開始版と一致する。専用構文はまだなく分類表を読む葉もない。これはソースの比較であり、新しい計算全体の同値定理とは扱わない。
- 既存の正負を含む8ファイル・333例は、ソースが開始版とバイト単位で一致する。assert削除・期待値の緩和・ignore追加は0件である。

公理・Builtins.Assumptionsの追加や、主定理・公開の保証の弱化はない。内部の四条件は公開入口の[]で閉じる。

## 検査

作業末の計画指定を一度実行した。コマンドの完全な引数、作業ディレクトリ、基準、終了状態、外側の時間は[check-times.json](check-times.json)を正とする。Dは本改造のディレクトリである。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| `scripts/check.sh --level work --base 319cc56c0f39da57c9c0f4db7aae275af2bf3150 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.010秒 | [計画指定の三単位を選択](work-dry-run.txt) |
| 同じ指定から`--dry-run`を除いたwork | 0、17.405秒 | [spec_tally自己検査と集計、仕様例7件成功・失敗0・ignore0、既定のlake build成功・sorryなし](work.txt) |
| `lake env lean <D>/l4c/axioms.lean`（formal/） | 0、0.610秒 | [READMEの全30定理](axioms.txt)の公理依存が開始版と一致 |
| `lake env lean <D>/l4c/internal-axioms.lean`（formal/） | 0、0.612秒 | [新規4補題と一般化した帰納・内部入口等26件](internal-axioms.txt)は標準三公理の範囲内 |
| `git diff --check`、規則・前提・文書の読み取り照合 | 0 | 差分、契約、対応に問題なし |

[公理の比較](axioms-comparison.json)では、今回の出力が[開始版に含まれるL4b出力の写し](axioms-start.txt)およびL1のaxioms-before.txtにバイト単位で一致する。axioms.leanはREADMEの全一覧とL4bの入力に一致する。開始版の保存出力を今回新たに実行した出力とは扱わず、過去のビルド結果も今回のworkの代用として引用していない。sorryAx・Lean.ofReduceBool・独自公理の依存はない。

途中はCheckInduction、CheckSound、CheckProgramSound、CheckExamples、CheckCounterexamplesとその依存対象に限って局所ビルドした。途中の失敗は、内部引数の追加後の全読者、acceptの分解の[]固定、bindsの長さ、境界の空ΔとhideContsの対応によるもので、任意Δへの一般化と全読者の更新で修正した。pipe_caseは失敗する候補の定義を展開する照合で長時間かかったため、右辺の構文を明示する場合分けに変え、局所ビルド成功を確認した。これらの途中の外側の時間は未集計である。rtk proxyはOperation not permittedで起動できず、スキルのフォールバックに従って通常のコマンドを使った。

Rustは変更していないため、Rust全lib・全統合・clippy・fmt・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表を変更しておらず、gen_skillの再生成は不要である。新しい有限テストは追加せず、全構文と任意の環境に対する一般の補題で契約を確認した。Rust本体・Rustテストの行数差分は0、形式化ソースは追加622行・削除632行である。

## 計画からのずれと申し送り

R150として、四条件をBuilderInvariantにまとめることと、Check.lean/CheckLemmas.leanの再帰・補助も同じ作業で更新することを具体化した。L4aの移行用の九つのR_builders補題は、直接の帰納へ接続したため除いた。旧構文の七判断のof_builderFree/builderFree_iffは保っている。公開の契約、停止条件、検査の割り当ての変更はない。

次はL5。専用操作の新しい場合を、今回のCheckComputeの支持保存とCheckSoundの健全性の帰納へ追加する。内部のhB.aligned/clean/atoms/singleから内容の型の条件を得られる。通常束縛ではhB.value、パターン束縛ではhB.values、説明/ガードではhB.hide、捕捉境界ではBuilderInvariant.emptyを使う。Q付きの七つのof_mutual入口は任意ΔとhBを受け、公開の入口は[]の証明を渡す。辞書自体は従来のΓの判断のままである。

L5/L6の専用操作・宣言、捕捉禁止の定理、Rustとの接続は今回の完了に含めない。コミット、取り込み、docs/todo/の変更は行っていない。

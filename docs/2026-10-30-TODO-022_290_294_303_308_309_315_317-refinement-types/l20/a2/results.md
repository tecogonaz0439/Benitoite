# L20 群 A2 の結果

2026-11-02。**関門 (a) は通過**。本番の V29/CQ24 全53枝、補助判断の全枝、捕捉への二系、弱い5 case、必要な効果供給を証明した。A2 の未証明枝は **0**。独立レビュー・取り込み・設計者の受け入れは未実施であり、実装担当の自己照合と区別する。

指定ブランチは `m014/l20.a2`、B_WORK は **`3cdec1565a0526a9617e766ca5feb3bbad362ca4`**。起動依頼の値を正とし、直接の git の照合・切替・作成・コミットはしていない。検査入口は指定基準からの変更を内部で読み取る。共通依頼文、detail の S01/S01a/S01b・A2/各単位・J20-1、plan の停止条件と先頭三判断、指定レビュー、A1 結果、L10 の CaptureWF/ImageOk の受渡し、現行 Lean を読んだ。既存の勧告の引継ぎを維持し、依存・固定版を更新していない。

## 成果物と判定

- [gate.md](gate.md): 定義・言明・差・反例・代案・時間・実用への影響を含む関門票。
- [signatures.md](signatures.md): 最初の60分以内に保存した完全署名、当時の未証明枝、追加する効果補題の署名、見込みの見直し。
- [public-signatures.log](public-signatures.log): 公開33宣言の elaboration 後の完全署名。検査入力は [public-signatures.lean](public-signatures.lean)。
- [annotation-sources.md](annotation-sources.md)・[rule-inventory.json](rule-inventory.json): 53規則と補助判断、S01b の全7行の供給元と証拠。
- [boundary.lean](boundary.lean): 真の捕捉を必要としない開いた帰納と、任意効果の形成との境界を確かめる7言明。
- [axioms.lean](axioms.lean)・[大きな記録の照合情報](large-records.md): private・生成宣言を含む公理依存。

## 53規則の集計と閉じた枝

| 結果形成の主な供給元 | 件数 |
|---|---:|
| 規則に既存の注釈 | 16 |
| 子の帰納 | 13 |
| 型の定義 | 8 |
| 場所の三条件 | 4 |
| SignatureInstance.result | 4 |
| 文脈の三条件 | 3 |
| 標準型の宣言 | 2 |
| TelArgs | 2 |
| 腕の末尾 | 1 |
| 合計 | **53（V29＋CQ24）** |

全53枝は表で供給を示しただけでなく、本番の構造帰納を Lean が検査した。V/CQ は相互に、Vs/Each/Arms/TelArgs は必要な結果へ構造再帰する。14成分の recursor の不要な8成分を True として列挙する代わりに、使う判断だけを証明した。空 Each の無条件の形成は結論しない。

`C_Let` は前半の結果の Annotation で CaptureContextRegular を extend し、後半の Annotation を WF/Sorted/Declared の逆 shift で戻す。`C_BuilderLet` は extendNone と None から unit への TypeMap、規則の Declared を使う。extendNone の WF/Sorted/Declared の逆 shift も本番に置いた。`C_ResumeL` と `V_LocRef` は A1 の場所三条件から、`V_Checked` は fixed absolute index の定義から閉じた。対応する case 補題を本番の枝で実際に使う。

E_Handle の供給は、外側の閉包全体の効果 es と handler の結論の効果 ec を区別する。r1 で追加した handle_inv が C_Sub/C_Eff/C_Normal を通して ec と被覆を取り出し、done_inner が外側の注釈・被覆・内側の結果型の注釈から ec の done を構成する。その後、capture_handle_body_annotation が元包含と handled の空の Fail 列から本体の効果を形成する。節は元の eb のままであり、独立の潜在効果の注釈は不要である。初回の記録で省いた段は中2として本番へ追加した。

E_Handle_Fail は failure.one の既存 E/t と NoFail rest から上限を形成する。ec は同じ one の RowAnnotations から閉じる。NoFail の正規化・値置換の保存は既存の補題を使用できる。Let の前半と後半の一束縛、通常関数の結果/効果、依存列の任意個数の done/param、捕捉した継続の contLoc の効果も閉じた。contVar は捕捉先 [] の lookup と矛盾する。新しい場所の Sorted を先に仮定して元の効果を得る循環はない。

## 初回の本番の変更と追加宣言（r1 の増減は末尾）

追加したファイルは `formal/Benitoite/Release/Refinement/CaptureRegularity.lean`。**ソース上41宣言＝定義1＋定理40（公開33、private8）**。Lean の生成宣言を含む同モジュールの監査対象は54件である。全名は [declarations.json](declarations.json) に置いた。

| 宣言の群 | 主な名前と役割 |
|---|---|
| 開いた文脈 | CaptureContextRegular、extend、extendNone、variable、CaptureOk.contextRegular |
| 弱い case と逆 shift | let_annotation、builder_annotation、used_annotation、locref_annotation、checked_annotation、extendNone の三逆補題 |
| 全結果と捕捉 | open_value/comp/values/each/arms/telArgs_annotation、capture_value/comp_annotation |
| handler の効果 | capture_handle_body_annotation、failure_effect_upper_annotation、capture_failure_body_annotation、HasTypeClausesQ.same_input_atoms、handle_body_normalize、failure_body_widen |
| let・関数・継続の効果 | CaptureOk.continuation_annotation/result_effect、capture_let_effect_annotations、capture_tel_annotation、capture_function_result_effect、HasFailureClause.capture_result_effect |

`formal/Benitoite.lean` は新モジュールの import を1件追加した。既存 import の削除は0件。01-12「閉じた述語の評価と捕捉」と07-04「篩を含む形式化の範囲」及び対応表へ、実装した形成の言明と保証の範囲を写した。見出しと text のコード例は変更していない。

既存 Typing・StateTyping・ClosureTyping、十移送を含む SubstTyping/TypingShift/TypeShiftTyping/Narrowing、lakefile と lean-toolchain は開始時の SHA-256 と一致する（[開始時](baseline.json)・[照合](baseline-comparison.json)）。CaptureWF/ImageOk/StoreOk・主な定理の前提を強めず、型付け規則も変えていない。plan/detail/reviews と Rust は変更していない。docs/todo と archive も編集していない。

## 検査

全て固定の Lean を用いた。単独は `lake env lean -M 12288`、既定 build の moreLeanArgs と targets は不変。RSS は **未取得（計画上の非採取）**。clean・並列数の上書き・プロセスの名前一致による停止は行っていない。

| 検査 | 結果 | 外側の時間と証拠 |
|---|---|---|
| K: `lake build Benitoite.Release.Refinement.CaptureRegularity` | 終了0、166 jobs。新モジュールに新しい警告なし | 2.455秒。[local-build.json](local-build.json)・[local-build.log](local-build.log) |
| K: 単独 Lean による境界7言明 | 終了0、警告0。非Top の rest まで含む最終入力 | 0.344秒。[boundary-final.json](boundary-final.json)・[boundary-final.log](boundary-final.log) |
| K: 公開33完全署名 | 終了0、33件 | 0.356秒。[public-signatures.json](public-signatures.json)・[出力](public-signatures.log) |
| W-L dry-run: `scripts/check.sh --level work --base 3cdec1565a0526a9617e766ca5feb3bbad362ca4 --dry-run` | 終了0。spec_tally/spec_examples/formal_build を選択 | [work-dry-run.json](work-dry-run.json)・[出力](work-dry-run.log) |
| W-L: 同じ基準の `scripts/check.sh --level work --base 3cdec1565a0526a9617e766ca5feb3bbad362ca4` を一度 | 終了0。対応表の自己検査、完了条件の未記入0、仕様例7成功、既定 lake build と sorry 拒否成功 | **8.212秒**。[work.json](work.json)・[work.log](work.log) |
| 上記 W-L 内の既定 `lake build` | 終了0。増分ビルドで、既定全 targets/import を保持。入口は成功時の内部出力を表示しないため jobs・単独時間は未採取 | 一式の時間に含む。追加の既定ビルドを重ねていない |
| A2 の公理依存 | 終了0。14モジュールの全宣言と旧五主定理・三モデル・十移送。**1,820印字／1,810固有宣言** | **1.897秒**。[axioms-run.json](axioms-run.json)・[生出力・集計の大きさとSHA-256](large-records.md) |

公理依存の和集合は **propext・Quot.sound・Classical.choice のみ**。sorryAx・独自公理・未承認依存0。新モジュールの private と生成宣言を除外していない。これは A2 とその供給元の監査であり、L20 段末 .148 の全体系の A-L 又は独立レビューを済ませた意味ではない。

最初の局所コマンドは根から formal 内の相対パスを渡して終了1になり、formal で同じ -M を付けて再実行した。証明の初期の型検査では、型推論の明示化、Annotation の三射影の再構築、DeclarationImages と TypeMap の区別、List.length の簡約を直した。既存定義や固定した主な署名の変更は不要だった。この途中の本番検査の全生出力は保存していない。最終成功のビルドを保存した。

初回の境界は、証明の括弧・Ordinary の shift の展開・EffR の構成子名・型引数の明示不足で終了1だった（[boundary-initial.log](boundary-initial.log)・[JSON](boundary-initial.json)）。修正後に全言明が成功し、最後に非Top の rest の具体例へ直して再確認した。前の成功は [boundary-before-nontop.log](boundary-before-nontop.log) に保つ。署名の初回印字は存在しない pp.width を指定して終了1で、format.width に直して終了0を得た（[初回](public-signatures-initial.log)）。これらは検査入力の修正であり、成功させるために本番の契約や規則を緩めていない。

work の spec_tally の未参照節の列挙は既存の表示であり、完了条件の未記入や検査失敗ではない。依存モジュールの既存の警告は local-build.log に再表示されるが、新しい本番宣言と最終境界に警告はない。

## 完了条件・ずれ・申し送り

| 単位 | 自己照合 | 後続 |
|---|---|---|
| L20.04 | 完了。開いた motive の完全署名、CaptureContextRegular と二延長を本番で証明 | 独立レビュー・受け入れ |
| L20.05 | 完了。逆三条件と extendNone 三補題、弱い5 case を本番で使用 | 同上 |
| L20.06 | 完了。全53行の供給表と構成子照合。依頼が許す全帰納も閉じた | 同上 |
| L20.07 | 完了。S01b の供給元と E_Handle/Fail の一般補題、ClauseSig の整合を閉じた | 状態の逆転・全保存・新しい場所への全 split の合成は .101〜.104 等 |

計画からの実装上の違いは三点である。第一に、現行の C の型 List TParam を明記し、A3 の TypeCtx 変更を先取りしていない。第二に、全53枝を後の .66/.67 まで未証明に残さず、今回の指示に従って全結果形成を閉じた。第三に、E_Handle の効果は開いた生の上限へ一律に拡大する案より、閉じた正規行の Fail の包含から直接得た。C_Eff と ClauseSig の整合も別に証明した。いずれも主な定理の仮定・結論や型付け定義の変更はない。

後の .66/.67 は全結果形成の再証明をせず、今回の成果を読んで必要な接続を照合できる。ただし .68 全体の CaptureOk.normConts の使用先、型置換、全値の意味、全状態保存、旧埋め込み、Rust の接続と全比較は今回完了していない。担当と時期は既存 detail/plan の割り当てのままである。未証明の A2 の義務を後へ移したものではない。

開始 UTC 2026-11-01 17:26:04 から本記録 `2026-11-01T17:44:22.014655+00:00` までの外側の時間は **1098.0秒（約18.3分）**。読取り・実装・道具の待ちを含み、能動時間と待ちの完全な分離ではない。最初の60分以内に signatures と全枝の結果を保存した。今回の当初見込み2時間45分〜6時間45分を下回った。既存の逆 shift・場所の補題と、形成が Fail 内部を読む性質により全枝が短く閉じたためである。後続の未経験の全型置換・全状態保存の見込みへ、この比を適用しない。時間上限・定義の強化による停止は発生していない。

| 残る手順 | 担当 | 見込み |
|---|---|---|
| A2 の定義・言明・仮定と供給元の独立レビュー、必要な指摘修正 | 取りまとめ／指定の独立レビュアー。修正が必要なら実装担当 | 不明 |
| 受け入れ・取り込み、後続群の起動と見込みの見直し | 設計者／取りまとめ | 不明 |

## r1: RV-L20.a2 の全6所見への対応

2026-11-02。関門 (a) の通過を維持する。RV-L20.a2 は条件付き可であり、今回の自己照合を修正版の独立レビュー済みとは扱わない。指定ブランチと B_WORK は初回と同じ `m014/l20.a2` / `3cdec1565a0526a9617e766ca5feb3bbad362ca4`。git の直接操作、計画・詳細・レビュー記録・Rust の変更はしていない。全6所見を同じ群で処置し、後続への所見の移管は0。

| 所見 | 処置と自己照合 |
|---|---|
| 中1 | 初回 axioms.log（212,662バイト）と axioms-summary.json（308,349バイト）を `<tmp>/l20-a2-r1-large-records/` へ移した。[large-records.md](large-records.md) に大きさ・SHA-256・入力・集計を記し、本文の参照と artifact-manifest を修正した。r1 の大きな出力も最初から同じ一時領域へ保存し、改造内の小さい集計に宣言ごとの配列は置かない |
| 中2 | 付録 inv1 の handle_inv・done_inner を本番へ移し、e_handle_supply を公開した。外側の閉包効果 es から、C_Sub/C_Eff/C_Normal を通す逆転と閉じた被覆、内側の結果型の注釈の差替えを経て本体の効果を供給する。外側 es と結論 ec を同一視していた本文・供給表・関門票を修正した |
| 軽1 | 付録 rest の split_fail_annotated を本番へ追加した。元 split_fail の切り出しの型付け・被覆・包含に done t ec の注釈を付ける。K_Handle_Fail の空 prefix の枝で、内側にある捕捉と節を使って注釈を得て、帰納で外へ返す |
| 軽2 | 付録 let1 に従い、e_let_post を公開した。前半 m と後半 n を外側 es へ C_Eff と Covers.shiftV で広げてから capture_let_effect_annotations を呼ぶ。ContTy.return_wf が Re=none の継続から R の閉性を導き、R.map shift=R を用いて二閉包・包含・K_Let まで構成する。Adequate は包装の明示入力であり、全状態の保存とは区別する |
| 軽3 | rv_real_closure と rv_thunk_body を既存 boundary.lean へ追加した。前者は通常値と Fail を持つ継続の場所を実際に捕捉する非空 CaptureOk から、contextRegular を経る結果形成と潜在効果の形成を確かめる。後者は store・hideConts_any・三条件の hide を合成する。必要な準備の定義・補題も同じ境界に置いた |
| 軽4 | 設計者の今回の指示を署名変更の承認として、公開7定理から使用しない Program.WellFormed・WellTyped・CoreAssumptions の三前提を除いた。使用先のない HasTypeClausesQ.same_input_atoms・handle_body_normalize・failure_body_widen を削除した。07-04 の変更の経緯の一文を削除し、現行の供給定理の内容を記した |

本番の追加は **公開定理6件**（done_inner・handle_inv・e_handle_supply・ContTy.return_wf・e_let_post・split_fail_annotated）と private 補助2件（cover_close・let_inv）。削除は公開定理3件。r1 後のソースは **46宣言（定義1・定理45、公開36・private10）** で、Lean の生成宣言を含む新モジュールの監査対象は61件となった。全名は [r1/declarations.json](r1/declarations.json)、現行の完全署名は [r1/public-signatures.log](r1/public-signatures.log)。初回の41宣言・33署名とそのログは初回時点の記録である。

署名を簡略化した7件は open_value_annotation・open_comp_annotation・open_values_annotation・open_each_annotation・capture_value_annotation・capture_comp_annotation・capture_let_effect_annotations である。実装前に signatures.md の r1 節へ完全署名を保存した。CaptureWF/ImageOk/StoreOk と既存型付け規則、主な十移送、固定版、メモリ設定、既定 import は r1 の開始時から不変である（[r1/baseline-comparison.json](r1/baseline-comparison.json)）。01-12 と07-04 の写しも同じ供給経路にそろえた。

| 再確認 | 結果 | 外側の時間・証拠 |
|---|---|---|
| 本番の初回局所型検査 | 終了0、警告0 | [r1/local-initial.json](r1/local-initial.json)・[出力](r1/local-initial.log) |
| 局所ビルド | 終了0、182 jobs。新規警告0 | 3.992秒。[r1/local-build.json](r1/local-build.json)・[出力](r1/local-build.log) |
| 既存境界と追加した実捕捉・thunk の境界 | 終了0、警告0。主な境界は既存7＋追加2件、準備の補題を含め14定理 | 0.355秒。[r1/boundary-final.json](r1/boundary-final.json)・[出力](r1/boundary-final.log) |
| 現行の公開署名36件 | 終了0 | 0.315秒。[r1/public-signatures.json](r1/public-signatures.json)・[印字](r1/public-signatures.log) |
| 指定 B_WORK の work dry-run | 終了0。仕様対応表の自己検査・仕様例・既定全 Lean を選択 | [r1/work-dry-run.json](r1/work-dry-run.json)・[出力](r1/work-dry-run.log) |
| 同じ基準の work を r1 末に一度実行 | **終了0**。自己検査成功・完了条件未記入0・仕様例7成功・既定 lake build と sorry 拒否成功。Rust の全 lib は対象外 | **4.401秒**。[r1/work.json](r1/work.json)・[出力](r1/work.log) |
| 公理依存の再監査 | **終了0**。14モジュールの全宣言と旧五主定理・三モデル・十移送、**1,827印字／1,817固有宣言**。propext・Quot.sound・Classical.choice のみ | **1.896秒**。[r1/axioms-run.json](r1/axioms-run.json)・[小さい集計](r1/axioms-summary.json)・[大きな記録](large-records.md) |

最初の境界検査は、三前提の削除後に B が結論から推論できなくなった一箇所で終了1だった。呼出しに B を明示して終了0を得た（初回は [r1/boundary-initial.log](r1/boundary-initial.log)）。署名の初回検査は削除した三宣言を古い入力が参照して終了1で、現行36宣言の入力に更新して終了0を得た（[r1/public-signatures-initial.log](r1/public-signatures-initial.log)）。途中の編集用 Python の入力符号化エラーでは書込み前に終了し、入力を分けて修正した。本番の証明の前提を足す修正はない。

RSS は未取得（計画上の非採取）。単独 Lean は -M 12288、既定ビルドの設定と対象は不変。work 内の既定ビルドは増分であり、単独の時間・jobs は入口の成功時の非表示により未採取である。追加の既定ビルドは重ねていない。sorryAx・独自公理・未承認依存は0。53規則の結果形成と関門の判定は維持し、外側の効果からの接続と切り出し・let の包装の不足を同じ群で閉じた。全状態保存・Rust 接続・全比較の完了範囲は増やしていない。

今回の読み取り開始 UTC 2026-11-01 18:02:55 から本追記までの外側の時間は約 6.7 分。能動時間と待ち時間は未分離である。見込みの上端の2倍に達していない。残る独立レビューの確認・受け入れ・取り込みは取りまとめと設計者の担当で、待ち時間は不明である。

## 作業末の work

`scripts/check.sh --level work --base 3cdec1565a0526a9617e766ca5feb3bbad362ca4` を、Refinement の生成物を消した状態で実行した。終了0、外側94.75秒、最大常駐量1,374,928,896バイト。

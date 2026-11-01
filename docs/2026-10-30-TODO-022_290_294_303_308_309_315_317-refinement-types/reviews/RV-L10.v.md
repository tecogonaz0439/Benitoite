# RV-L10.v: 群 V（L10.01〜.13）の実装の独立レビュー

判定: **条件付き可**。所見は重0・中3・軽3、計6件である。偽の値の型を導く反例はなかった。中1・中2は群 X の入口の契約に関わるので、群 X の起動の前に処置する。五つの境界に触れる所見はない。

2026-11-01。対象はブランチ `m014/l10.v` の未コミットの作業ツリー、基準は `c668ff02`。Opus 5.5 のサブエージェントが行った。リポジトリの変更はこのファイルだけである。

## 確かめた方法

読めば確定した事項と、Lean で動かした事項を分ける。補助の入力は `<tmp>/rvl10v/` に置き、`cd <repo>/formal && lake env lean -M 12288 <入力>` で検査した。どれも終了0で、`sorry` はなく、依存は `propext`・`Quot.sound`・`Classical.choice` だけである。

| 入力 | 確かめた内容 | 結果 |
|---|---|---|
| `rv-v-t2.lean` | 正例。`Box[Integer{0≤self}]` の値を `V_Con` で作り `V_Sub` で `Box[Integer]` へ広げ、`con_field_by_type` で欄を読む | 規則の入口を通り、広い型の欄が得られる。両側の欄の Annotation は具体の型について手で与えた |
| `rv-v-t3.lean` | `legacy_valid`。`dataInfo` が全て none のとき、欄の Annotation と kind だけから `VarianceValid` を得る | 証明した。既定 none の表で変性の検査は追加の制限にならない |
| `rv-v-t4.lean` | `sort_reflect_aux`。検証済みの欄で、`DataObservationLe` の行き先の sort が元の型引数の sort へ戻る | 証明した。`widen` で読む sort は偽にならない（軽2） |
| `rv-v-t5.lean` | `field_mono'`。`variance_field_mono` から像の Annotation を外し、総称の欄の `Sorted` と型引数の `Ordinary` だけで単調性を示す | 証明した（中2） |
| `rv-v-t6.lean` | Set・Map 鍵・辞書・継続の両引数・外部型・tapp・Fail・依存の位置・不変の data への入れ子・反変の data への入れ子の拒否。二重の反転の受理。`T{true}` と `T` の同一視。不変の位置で篩の差を広げないこと。Token の観測の取り替えの不可能 | いずれも意図どおり。ただし List の子を消す観測は Token の引数の中の要素を区別しない（軽2） |

既定の `lake build` は 742 ジョブで成功した。`l10/v/boundary.lean` は 33 定数、`l10/v/axioms.lean` は 5470 件を再実行し、`sorryAx` は0件である。`source-state.json` の 45 ファイルの SHA-256、境界とビルドの出力の SHA-256 は現物と一致した。`git diff c668ff02 -- formal` から `P` の追加を機械的に除いた残りは、`.data` の場合の追加、移送の補題、`variable` 宣言、`widen` の追随だけで、主な 10 定理の前提と結論に差はない。`TypeShiftTyping`・`SubstTyping` は差分に現れない。

## 所見

### 中1: 欄への型代入の形成の補助がなく、後段が具体化した欄の Annotation を供給できない

- 箇所: `ValueFacts.lean` の `HasTypeVQ.inv_con`・`con_field_by_type`・`field_facts_by_type`。`results.md` の L10.07 の行、「補助の契約で決めたことと計画との差」の3。`detail.md` の「V」の欄の単調性の段落、L10.07 の行。
- 問題: detail は「VarianceValid で constructor 欄の Annotation/kind を検査し、欄への型代入の形成と使用先の注釈から両前提を供給する。この形成の補助も .05〜.07/.08 に含める」と定める。実装にあるのは正規化後の `Sorted` を元へ戻す `Ty.sorted_norm_rev` 系だけで、`P.VarianceValid` の総称の欄と型引数から `Ty.Annotation P C Γ (a.subst ts [])` を導く補題がない。型置換についての `Ty.Annotation`・`Ty.Declared`・`Term.HasData` の移送も `shiftTypes` 以外にない。results は L10.07 を完了とし、計画との差の3を補助の契約の決定として記すが、detail の担当の未達である。「型引数の Annotation から無条件に結論しない」は detail の「不適格な欄の述語まで得られるとはしない」とは別の話で、VarianceValid の下での形成まで外す根拠にならない。
- 別に、`inv_con` は `V_Con` が持つ `TypeArgsKinded` と `Ty.Annotation P C Γ (.data cd.data ts)` を返さない。値の側の型引数 `ts` は型付けの導出の中にしかないので、呼出し元は `VarianceSubstInput` と `sourceField` を作る材料を持たない。現在 `con_field_by_type` の呼出し元が0件であることが、この不足を隠している。
- 再現: 読めば確定する。`rv-v-t2.lean` は補題がないので、両側の Annotation を具体の型について手で与えた。形成が偽になる反例は探したが見つからなかった。総称の欄で sort を持つ carrier は型変数の根を持たず、型置換で sort が保たれる。`Eff.Canonical` は `Ty.bind` の正規化で保たれ、`.refined` の `NotContCore` は型引数の `Ordinary` で保たれる。`Term.HasData.widen` の型置換は `observationType` と一般の型置換が可換でないので、`shiftTypes` の証明をそのまま使えない。像を `observationType` で写した環境で `TypeArgsLe.rawBind` を使い、もう一度 `observationType` を掛ければ閉じる見込みだが、これは未検証である。
- 修正案: `inv_con` の結論に `TypeArgsKinded` と `Annotation` を足す。`Program.VarianceValid` と型引数の入力から `Ty.Annotation P C Γ (a.subst ts [])` を導く補題を、`Term.HasData`・`Pred.Declared` の型置換とともに本番へ入れる。群 V の中で閉じない場合は、detail の担当の変更として見込みとともに記録する。L20 へ黙って送らない。

### 中2: `variance_field_mono` の両側の Annotation は過剰で、群 X の `valueMeaning_sub` から供給できない

- 箇所: `VarianceTransport.lean` の `Ty.VarianceOK.mono`・`Tel.VarianceOK.mono`・`variance_field_mono`。`detail.md` の `valueMeaning_sub`（L10.18 で言明を固定、全証明は G09）。`results.md` の「残りと送り先」の群 X の行。
- 問題: 予定の `valueMeaning_sub` の前提は `P.VarianceValid`・`Ty.LeQ P Γ Φ a b`・モデルの真・`ValueMeaning` だけで、型の Annotation を持たない。その `.data` の場合は「欄の単調性を使い、子値にも同じ意味の移送を行う」が、現行の `variance_field_mono` は `a.subst as` と `a.subst bs` の Annotation を要求する。導出の `trans` の中間の型には Annotation がなく、端の型に前提を足しても足りない。`Ty.LeQ` は `Sorted` を保たない（`fn_effect` の `Eff.Covers` は新しい Fail の型の `Sorted` を要求しない）ので、導出から回復することもできない。
- 単調性の証明が `Sorted` を使うのは `Polarity.Rel.refined` の述語の `Sorted` と依存列の文脈だけで、これは総称の欄の `Sorted` から得られる。
- 再現: `rv-v-t5.lean` の `field_mono'` で証明した。前提は `occurs`・`wf`・`a.Sorted []`・型引数の `Ordinary`・`TypeArgsLe` だけである。`SortMap` を総称の文脈から実の文脈への写像に使い、既存の相互証明の形をほぼ保って約 170 行で閉じた。型引数の `Ordinary` は `V_Con` の kind と `Ty.LeQ.notContCore` から得られる。
- 修正案: `Ty.VarianceOK.mono` と `Tel.VarianceOK.mono` を `field_mono'` の形へ替える。`variance_field_mono` の未使用の `_valid`・`_inputs` と `sourceField`・`targetField` を外す。`con_field_by_type` は `V_Sub` の結論に要る `targetField` だけを残す。`valueMeaning_sub` に足す前提は `Ordinary` の入力だけで済むかを L10.18 の言明の固定で確かめる。群 X の起動の前に入れれば、X の署名を作り直さずに済む。

### 中3: 01-12 の写しと 07-04 の対応表が追随せず、担当もない

- 箇所: `docs/design/01-spec/01-12-core-calculus.md` の「篩の正規形と制約の読み方」の部分型の段落と `scoped` の写し（`Ty.LeQ Γ Φ`）、状態の型付けの `K_Sub`（`Ty.LeQ [] [] a a'`）。`docs/design/07-quality/07-04-formal-semantics.md` の対応表。`docs/design/00-overview/00-04-glossary.md`。
- 問題: 07-04 の「形式化した規則を変えるときは、Lean の定義と 01-12 の写しを同じ変更で直す」に対し、`Ty.LeQ` の型と規則（`P` の追加、data の規則、`TypeArgsLe`）、`Term.HasData.widen`、`Program.dataInfo` を変えたが写しは旧のままである。部分型の段落は data の型引数に触れない。対応表に新しい5モジュールの行がない。用語集に「変性」がない（AGENTS.md「文章の規範」）。detail の文書の単位 L10.56・.57 は幅・Top・Request と改名だけを担当し、この変更の担当がない。results の「残りと送り先」にもない。
- 再現: 読めば確定する。
- 修正案: 群 V の取り込みで写しを直す。規約の例外として群 W の末までまとめるなら、取りまとめが判断として記録し、担当の単位を detail へ足す。

### 軽1: 実績と見込みの差の読み方がない

- 箇所: `l10/v/results.md`「外側の時間」、`effort-ledger.md` の L10 群 V の行。
- 問題: 外側 44 分 33 秒（台帳は約 45 分）は、単位あたり 0.5〜1 時間の 13 単位、計 6.5〜13 時間の見込みの 6〜11% だが、results は比較も理由も書かない。実際の読み方としては、差分 457 行の大半が `P` の機械的な追随で、新規の中身は 877 行であること、自動で通った 304 枝を証明の作業量に数えないこと、中1の形成の補助が含まれないことが要る。この実績から群 X・W の見込みを単純に比例で縮めない。
- 再現: 読めば確定する。
- 修正案: results に上の読みを一段落足す。

### 軽2: `Term.HasData` の型引数は実の型引数でなくなったが、説明と申し送りがない

- 箇所: `Declared.lean` の `Term.HasData` の docstring（「data の受け手が持つ名目型と型引数」）、`results.md` の L30/L40 への受け渡し。
- 問題: `widen` の後の `ts` は、観測の射影で関係する型引数である。`rv-v-t6.lean` の末尾のとおり、不変の `Token[List[Read]]` の受け手は `Token[List[Write]]` の `HasData` も持つ。観測が List の子へ下りないので偽の事実にはならず、`rv-v-t4.lean` で検証済みの欄の sort の反映も確かめた。ただしこの反映は `Program.VarianceValid` を使う。`Declared` は検証なしで成り立つので、不正な表では行き先の sort が元へ戻らない。観測の準備の後段の証明がこの前提を要することが書かれていない。
- 再現: `rv-v-t4.lean`・`rv-v-t6.lean`。
- 修正案: docstring を改める。`sort_reflect_aux` を本番へ入れるか、L30/L40 の申し送りに `VarianceValid` の要否を書く。

### 軽3: 未使用の宣言

- 箇所: `VarianceSyntax.lean` の `Polarity.join`。
- 問題: Lean の中に読者がない。detail の「有限表」の一部で、候補表の推論は R20 の担当なので害はないが、検証の健全性に寄与しない定義である。
- 再現: 読めば確定する。
- 修正案: R20 の照合の入力として残す理由を signatures に書くか、外す。

## 確かめて問題がなかった重点

- **変性の健全性**: `Ty.VarianceOK.mono` の相互証明に信頼欄や公理はない。関数の引数と Tel の依存の位置は反転し、Reference・Set・Map 鍵・辞書・継続・外部型・tapp・Fail は両方向を要求する（`rv-v-t6.lean`）。不変の data へ渡すと両方向になり、反変の data へ渡すと負になる。相互再帰は `P.varianceFor` の候補表全体を読む。data の型パラメータは値の kind だけで、`HasKind` が tapp の欄を拒む。これは 01-05「型の宣言とレコードの型パラメータは、どれも値の型を表す」と一致する。篩の述語は `Ty` を含まないので型変数の出現はなく、carrier の検査と総称の欄の Annotation で足りる。
- **既定 none**: `varianceFor` は none・arity の不一致・列長の不一致で不変の列を返す。`embedProgram_varianceFor` と `rv-v-t3.lean` で確かめた。旧の受理は `embedLe` が任意の `P` で読める。`dataCore` の変更は受理を広げる側である。
- **不変の位置**: `T{true}` と `T` は norm 等号で同じになり、篩の差は広げない（`rv-v-t6.lean`）。旧の `.convert` の範囲と同じで、書ける形を狭めない。
- **`unused`**: 置いていない。`Program.VarianceValid` の第一節が非出現の引数を不変に限る。`Token[Read] ≤ Token[Write]` は境界で否定され、`DataObservationLe` でも否定される（`rv-v-t6.lean`）。
- **dataCore と逆転**: `dataCore`・`dataCore_source` は元の等号を要求しない。`inv_con` は `normTys ts` と `us` の `TypeArgsLe` を返す。`V_Sub` の推移で `length` の書き換えが正しい。`rv-v-t2.lean` で正例が入口を通るので空虚でない。
- **観測**: `observationType` は `Ty` の全構成子を覆う。`Ty.sort?` は射影で変わらず（`sort_obs`）、`LeQ` は射影へ移る。Reference・関数の欄は子を消すが、`Term.HasData` の `field` は data の根しか辿らないので、消した子に下りる経路がない。`.constructorIs` は data の名だけを読み、`widen` は名を変えない。`atErrorType` は型引数を持たない。
- **判断の言明**: 規則は 14+2+2+4=22 件、`case-matrix.tsv` は 76 行 4 列で全て passed である。`Eff.Covers` と `Eff.Sub` は `P` なしのままで、`V_Sub`・`C_Sub`・`K_Sub` は同じ `P` を読む。主な 10 定理の前提と結論は基準と同じである。新しい `.data` の場合が `trivial`・`exact hv` で閉じる読者（`RootShape`・`ExternalLeafShape`・`holds`・`contView`・`notContCore`）は、いずれも型の根だけを読む定義である。
- **Byte と七幅**: `Ty.sort?` と `Pred.Sorted` は差分になく、比較は維持される。
- **五つの境界**: `P` の追加と `VarianceValid` の位置のほかに、主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態の変更はない。`VarianceValid` の Annotation と kind の要求は、01-05 の規則と既存の `V_Con` の条件の範囲である。
- **記録**: 件数、ハッシュ、絶対パス（0件）、docs/todo へのリンク（0件）は問題ない。`results.md` の追加1342行・削除281行は開始時の写しとの比較の値で、`git diff` と新規ファイルの行数の和（1334行・276行）と少し違うが、比較の方法の差であり判定に影響しない。requirements/publicBoundary の収集の完全性を証明したと読める記述はない。L70/R10b への申し送りはある。

## 設計者へ示す点

- 主な定理の前提と利用者の書ける形に変更はなく、問う判断はない。
- 取りまとめの判断が要るのは二つである。第一に、中1の形成の補助を群 V の修正で閉じるか、担当を移すか。第二に、中3の写しの更新を「同じ変更」の規約どおりに行うか、群の末までの例外とするか。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/v/rv-v-t2.lean`〜`t6.lean` へ写した。中1は群 V の修正で閉じる。担当を移さない理由は、detail が .05〜.08 に含めた義務であり、群 X の入口の契約だからである。中2は本文の案のとおり `variance_field_mono` の前提を弱める。中3は規約どおり同じ変更で 01-12・07-04・用語集を更新する。軽1〜3 も同じ再開で処置する。五つの境界に触れないので、plan.md の判断の行は足さない。

# A4 r2 関門 (d) の判定

2026-11-02。**通過：案Aで三枝と任意の部分型に対する意味の移送を証明した。** `ValueMeaning` の定義と valueMeaning_sub の署名を保つ。型像の Ordinary を主定理又は S07 の独立入力へ足していない。案Bは実施していない。RV-L20.a4 はこの判定に同意した。r2で中1・軽1〜5を処置し、既定ビルド、公理依存、valueMeaning_sub の署名の機械的照合も成功した。最大常駐量は取りまとめが作業末の検査で採取・追記する。検査は [results.md](results.md)、完全署名は [signatures.md](signatures.md) にある。

## 定義と言明

`MeaningOrder` の `MeaningLe` と `MeaningArgs` は値の意味の移送に使う帰納的な補助関係である。`of_le`・`of_args` は元の LeQ と TypeArgsLe の導出を写す。この関係を型付けの部分型判断として用いない。関数・依存関数・lazy・map は、ValueShapeMeaning の内部を観測しない構成子に対応する。篩は述語の含意、data は同じ P の変性に従う引数の比較を保つ。

`variance_meaning` と `variance_meaning_args` は総称型と型引数列の構造に再帰する。tvar は比較した型像の該当する成分に進む。不変の位置は既存の `Ty.VarianceOK.invariant` による正規形の等号を使う。refined は基底へ下り、同じ値の置換による述語を両側に保つ。入れ子の data は各引数の変性で極性を合成し、引数列へ下る。これらから `field_order` が具体化した欄の新しい MeaningLe を構成する。

外側の motive は、値の大きさ n と、任意のプログラム・文脈・型・MeaningLe・モデル・事実の真・元の意味を量化する。内側は MeaningLe と MeaningArgs の相互帰納であり、引数列の motive は True とする。依存関数の本体の意味を要求しないため、TelLe・TelClosure の導出には帰納しない。外側を強めたことにより、新しく作った欄の比較も IH の対象になる。Prop の導出から Nat のサイズを作らない。

`order_step` と自然数の強い帰納による `outer_complete` が全場合を閉じる。`meaning_order_sound` と元の LeQ の写しから、元の S07 と同じ `valueMeaning_sub` を導く。`valueMeaning_field_mono` は直接の意味の単調性の補助であり、構成子の宣言の欄の VarianceOK・型引数の比較・同じ P の VarianceValid・事実の真・元の欄の意味から先の欄の意味を返す。

## 三枝と下降

| 枝・義務行 | 結果 | 本番の証拠と下降 |
|---|---|---|
| L20.25 | 完了 | Outer・Below・MOrder とMeaningArgsのTrueのmotive。order_step は内側の相互帰納、outer_complete は外側の強い帰納を閉じる |
| L20.26 / data | 完了 | order_data → data_shape_meaning → fields_meaning。field_order が返す新しい比較へ、各子値の sizeOf が親の sizeOf より小さいことを使って外側 IH を適用する。元の MeaningArgs の IH は使わない |
| L20.27 / trans | 完了 | order_trans は同じ値に対する左右の内側 IH を合成する。中間型の Annotation を要求しない |
| L20.27 / refine | 完了 | order_refine は source を基底と p の真に分け、基底の内側 IH と既存 valueMeaning_refine を使う。Γ.facts と Φ の真を Pred.interpret_lift_self で selfModel へ渡し、Entails.sound で q の真を導く |

data の構成子の意味が持つ欄の WF は保持する。VarianceOK は同じ P の VarianceValid から得る。型引数を正規化した比較は MeaningArgs.norm で作る。構成子の arity と両側の引数列の長さを照合し、特別な atError の data も省略しない。List の各要素にも値の大きさの外側 IH を適用する。

## Ordinary と Sorted の結論

初回に求めた両側の型像の Ordinary は、S07 の入力からは供給できない。既定 import の `MeaningTransportObstruction.ordinary_supply_counterexample` はその証拠として残す。検証済みの共変な MeaningBox の構成子の宣言の欄は tvar 0 であり、継続型 K に閉じた真の述語 0 = 0 を付けた型から K へ述語を忘れる部分型と、元の data の意味が成り立つが、両側の型引数は Ordinary でない。

案Aは Ordinary を要求しない。構成子の宣言の欄の Sorted [] は VarianceValid が持つが、構造による field_order とその意味の移送はこれを入力に要求しない。使わない field_inputs は削除した。意味の定義は変えていない。初回の反例は、任意の部分型に対する意味の移送の反例ではない。axioms.lean の a4_nonordinary_transport は、その同じ元の意味に完成した S07 を追加前提なしで適用し、先の data の意味を得る。

## 関門と後続の義務の境界

今回閉じたのは任意の部分型に対する意味の移送である。型付けの V29/Vs2/Each2 の全33場合を組む typed_value_meaning_closed、そこからの inhabits_of_typed/raw、捕捉と腕への全接続は後続の担当へ残る。これらを独立の仮定として追加していない。元の S07 のまま V_Sub の枝で使え、型付き入力の呼出し元へ新しい前提の供給を要求しない。P.WellTyped.variance から同じ P の検証を得る契約も保つ。

O005・A と O039 の G09 のうち、欄の意味の単調性と全部分型の意味移送の葉を閉じた。型付けから所属と網羅性へ至る全接続の完了、独立レビュー、設計者の受け入れはこの関門の通過と区別する。群H以降の起動と、後続の義務の担当・時期は取りまとめが指定する。

## 計画との差、所要時間、実用への影響

取りまとめの r1 の指示に従い、Ordinary の供給と variance_field_mono の新しい LeQ 導出を使う方式を撤回した。代わりに、構造から新しい MeaningLe を作り、外側の motive を強めた。これは O005・A の欄単調性を再実装しない方針の例外である。理由: variance_field_mono の Ordinary を S07 の入力から供給できないため、variance_meaning を意味の側に別に持つ必要がある。P.VarianceValid の定義と不変な位置の等号の証明は再使用する。valueMeaning_sub と主な10言明の字面、ValueMeaning、LeQ、Exhaustive、旧 Release、処理系は保つ。

r2 の指示で l20/detail.md を実装した経路へ直し、群Hの .85〜.88 を済み（群A4）、追加0分とした。重複の2時間45分〜6時間15分を差し引き、全体95時間〜213時間30分、G09は5時間〜13時間25分とした。.89〜.91は.27直後へ前倒し可能で、.92は従来の依存を保つ。後続の型付けから意味と所属への三署名から不要な B.CoreAssumptions を外した。plan.md・レビューの記録は変更していない。

再開から最初の下降の局所検査の成功までは約4分、記録と検査を含む今回の外側の時間は results.md に示す。能動時間と待ちは厳密に分離していない。当初の2時間30分〜7時間10分の上端を超えていない。この実績を、未実装の型付け33場合の見込みへ比率で掛けない。

新しい受理・拒否・診断・実行時の振る舞いの変更はない。実用への影響は、網羅性の健全性に必要な任意の部分型に対する意味の移送を、意味や主定理に新しい信頼条件を足さずに利用できるようになったことである。処理系と Lean の全比較や、型付けから網羅性への全接続の完成は主張しない。

# 高階の静的型位置と依存結果の照合

2026-11-03。対象は[StandardHigherPositions](../../../../formal/Benitoite/Release/Refinement/StandardHigherPositions.lean)である。基準は `548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8` と開始時の未コミット状態であり、旧740Leanの識別は[開始記録](inputs-r1-u27.json)と同記録の分割ファイルへ保存してある。今回の自己点検は独立レビューではない。

## 守る契約と既存の境界

本モジュールは既存のHasTypeVQ・LeQ・TelClosure.apply・Transportの具体的な読者である。新しい型規則、主定理の前提、信頼条件を追加せず、値の受理には実V_Var/V_Subを構成する。拒否は同じ型と文脈のinv_var/coreの逆転から導く。空文脈の型比較の否定だけを、元型のある変数の拒否として用いない。

| 位置 | 本番の公開入口 | 受理と拒否の根拠 |
|---|---|---|
| 関数入力 | callback_checked | Integerから自己値7の篩への入力の制限を反変として受理し、逆向きは自己値8のモデルで拒否 |
| 関数結果 | result_checked | 篩付き整数結果から通常整数結果を受理。逆向きは結果の文脈を保持した逆転と8のモデルで拒否 |
| 潜在効果 | effect_checked | emptyからFail[Integer]への効果の拡大を受理し、逆はFail所属の不一致で拒否 |
| List内関数 | list_checked | 同じList変数について、内部関数の入力反変と結果共変を同時に適用。逆はlistCore/fnCoreの逆転から拒否 |
| 正のdata | option_checked | 実OptionのVarianceValid・実SomeのDataArityを使用し、同じPのOption[R]からOption[Integer]を受理 |
| 負のdata | consumer_checked | 実Consumer.Makeの欄は(value:T)→Unit。全有限構成子に対するVarianceValidを証明し、Consumer[Integer]からConsumer[R]を受理 |
| Reference | reference_checked | 通常fnとdependentFnの同じ正規形を受理し、参照先の篩を忘れる変換は正規形等号の不一致で拒否 |
| Fail | fail_checked | 同じ正規形の関数viewをエラー型として受理し、Fail[Integer]でFail[R]を覆う変換は拒否。同じ潜在Failを持つ関数変数も対照 |
| 名前と個数 | names_arity_checked | 元型・改名・追加引数のNamesWFをすべて確認。fnとdependentFnの同じviewを受理し、名前又は個数だけが異なる型への変換は拒否 |
| 同じ実引数の依存列 | dep_apply | 入力の反変関係へ同じ実引数[2,5]をTelClosure.applyで適用。依存結果と非空Failを同時に得る。10*2+5の構文を保持し、実25を10*5+2へ型付けすることと、交換したFailで覆うことを拒否 |
| 四種の置換像 | length_all_images | 元Γの差を補うTransportを既存length_leへ適用。移送先のvar2+1=7から正数性を導く。条件なしの拒否は元Γの空List/n=0に限る |

全位置の両型にWF・Sorted・Declaredの注釈を形成する。逆向きの拒否にも実文脈で同じ形成を確かめる。新しい公開定理は同じ既定内の匿名読者から具体的に使用する。四像のうち長さ型に現れない型・行・範囲がそこで変わったとは主張せず、既存all_open_derivation/all_open_coversも別読者で読む。既存の一般帰納証明を再実装していない。

テスト監査の作成時の関門として、守る契約は各型位置の受理・拒否と同時代入の向きである。現実的な退行は入力の反変の逆転、Failのエラー型への共変の誤導入、名前・個数の見逃し、二実引数の代入順の交換である。既存の一般定理だけでは、これらの具体的な型位置・注釈・同じ変数・実引数の組合せを読まないため、当該利用境界へ具体読者を置いた。テスト専用の公開フックは追加していない。

## 境界に依らない理由と残る範囲

- .23のFirstReturnと二反例は、この静的な型付けと置換の前提に含まれない。正常返却を使う追加読者は**境界の決定待ち**である。
- 精密getter06〜14の未生成の欄等号は、関数変数の変換、実Option/Consumerの変性、二実引数の代入、既存length_leのいずれの前提にも含まれない。[安全な入口の記録](sources-u26.md)の未証明9行を保持する。
- 固定19行のmapの強い本体は、今回の依存列の例に使用しない。一般行とmapの正常関係は**境界の決定待ち**のままである。
- 全標準ソースのBindingId/tag/ABI、本体の収集、Program.WellTyped又は全モデルCoreAssumptionsの充足は今回の到達範囲に含まれない。

## 入力と修復の記録

準備入力の最終成功は[準備の識別](preparation-u27.json)へ必要な数値とハッシュを保存した。本番の証明は上記Leanファイルに残り、一時領域を恒久的な根拠リンクにしない。準備入力は23680 bytes、SHA-256 `472e70e5ff9feb57630003894045f76d12fe34bd9dbaf39737f60a2a10a0fd7b` である。

本番の全試行は[checks-r1-u27.json](checks-r1-u27.json)へ追記している。中断前annotations01の後、未使用simp引数の整理でbasic_annの閉じ括弧を失いclean01が失敗した。継続clean02で元のブロックだけを復元し終了0。clean03で隣接削除範囲の重複により同じ構文エラーが再発したため、削除範囲を併合してclean04で修復した。readers01では不要なsimpa警告も整理し、終了0かつ出力0 bytesだった。失敗記録を削除せず、型の言明を緩めていない。

最終の既定ビルドdefault01は対象なしlake buildで991ジョブ、終了0。旧740Lean/root旧prefix・新import/olean・全public読者・義務64行・記録100KB以下・追加対象指定build0は[verify-u27.py](verify-u27.py)と[局所照合の証拠](source-evidence-u27.json)で検査する。全private/生成宣言の公理監査・全体照合・独立レビュー・設計者の受け入れは取りまとめの担当であり、この局所検査で代替しない。

# RV-C1R への対応

2026-10-25、作業C1R2。基準は `7fa8aabc036bb0873b5ba8e2c23d47535ceb051e`。対象は[再レビュー](RV-C1R.md)の中1〜中5・軽1〜軽6である。plan.mdに「計画の変更（2026-10-25、C1 の再レビューを受けて）」とwork行を加え、各所見の期限も記した。

| 所見 | 対応 | 状態・後続の確認 |
|---|---|---|
| 中1 | `IndependentResult.Sound`のsome envの場合へ`forget env = env`を加え、`run_contract`は忘却済み入口についてこの強い保証を与える。`captureIndependent_saves`が忘却の冪等性から条件を供給し、既存の`analysis_savesInputs`・本体入口の全入力のSoundへつなぐ。`Sound.integer_top`で全整数位置のTopを取り出せる。新しい`BudgetIndependentPosition`の`InputSegment`・`analysis_inputWalk`は入力全体の番号列が元の番号列の連続部分であることを合成する。`analyzeBody_independent_segment`・`analyzeBody_independent_located`は任意の予算・途中停止で全保存入力と候補を本体の元位置・対象演算へ結び付ける。01-12と07-04へ写した | C1R2対応済み。A07はこの対応から元NodeIdを引く。中心命題・本体入口の系の前提は増やしていない |
| 中2 | 独立入力の忘却した環境を保存保持へ移さず、子の解析中だけtemporaryで保持し、scopeの終了で返す。結果のinitialは証明用であり、Rustは環境項目を保存しないと契約に明記した。親と別本体のseedは後続が読むため保存を保つ。発見の`reidentify`はnumberingだけ計上し、対応表の二組目を作らずidentityの確保を行わない。`discover_manifest`は発見順・次キーと空の対応列を示す。「予算の交換」も同じ計上へ変更した | C1R2対応済み。D16に対する増え方と小入力での新旧の保持数は[結果](../c1r2/results.md)へ記載。A11/X02は変更後の定義を写し、U01は実入力を棚卸しする |
| 中3 | `comparisonEligible`をBodyOutputごとに変更し、`excludedBodies`で除外した本体を残す。段の深さ停止はphaseStopsで別に報告し、manifestの完了を装わない。fuelは列の長さでも減ると01-12・07-04・契約へ記した。planはsurfaceSize総和の4倍+32から始め、深さ停止時に倍増して固定corpusを再実行し、選択値を保存する。L28/X02の完了条件は除外0件、または件数と理由を報告して取りまとめが受け入れることとした | C1R2対応済み。深さ停止がないという一般定理は加えていない。L27〜L29/X02が実入力のfuel・本体と段の除外を報告する |
| 中4 | `BudgetWhole`へ`inputDefinitionCount`・`unsupportedBodies`・`bodyBudgetExceeded`・`wholeBudgetSkipped`・`unidentifiedBodies`を追加した。phaseStops/stopCountは停止事象であり同じ全体上限を重ねて数えうること、wholeBudgetSkippedの既知の単位と未発見本体を数えないことを01-12・契約へ明記した。親と独立入力のunsupportedは本体で一度だけ数える。入口・発見などだけの本体上限/番号未取得は段停止として別に読む | C1R2対応済み。L27〜L29/X02/A12は射影を共通の正とする。件数0だけでcoverageをallにせず、段停止・pending・元入力の残りも読む |
| 中5 | consts::check、decls::check、generate::check_functionを読み、定数は全モジュールで先に検査し値を依存順で評価する一方、関数とimplのメソッドはast.decls/i.fns順で検査することを確認した。finish前は具体化した入力を収集し、全本体検査後にモジュール/宣言順で駆動する契約とした。Definitionには定数・本体付き関数・implメソッド・検査用生成関数を含め、メソッド名はmoduleとimplの宣言位置・メソッド位置・名前から一意にする | C1R2で方針・契約を固定。A01/A02の実装は後続担当。LeanのDefinitionとBudgetWholeの駆動順序自体は変更せず、呼び出し側の入力順を固定した |
| 軽1 | 01-12へ、concreteRuleのmatchの腕には非整数の照合値の場合も入り、この補助定理では区別できない限界を明記した。A09とX02へ「近似が整数だけでない照合値のmatchの腕に親の警告を出さない」を追加した | 文書対応済み。A09/X02で照合する |
| 軽2 | 現行01-12・07-04の構文的な到達可能性を指す「領域」の略記を直し、IndependentInputの旧名regionをsyntacticReachへ直した。planの契約も揃えた。整数の領域と作業領域のregionは保った | 対応済み。過去のreviews/resultsの記録は変更していない |
| 軽3 | 用語集の07-04へのアンカーを`#01-12-との対応`へ修正した | 対応済み |
| 軽4 | 契約「警告」と01-12へ、未到達は各入力が持つ事実に対する判定であり、独立入力で外の事実を忘れた結果、外の事実なら未到達の枝にも警告しうることを記した | C1R2の文書対応済み。U01でこの種の警告の件数を観察する |
| 軽5 | 新候補の統合順を本体順、surfacePreorder昇順、同じキーでは親を先、続いてindependentRev.reverseの記録順、各列内はwarningsRev.reverseの順とした。旧定数警告の優先を保ち、保存時刻を復元する必要をなくした | C1R2の契約対応済み。A07とX02がこの順序を使う |
| 軽6 | BudgetReachのmaxHeartbeatsへ、全構成子の相互帰納と番号列の書き換えのための証明器の枠であり、解析のfuel・予算を変えない理由を注記した | 注記済み。全駆動の順序の一般定理は追加していない。01-12・07-04は既存どおり実行比較の範囲とする |

指定のworkは一度で三単位とも成功し、仕様例は7成功・0失敗・0無視。既定Leanビルドとsorry拒否、仕様集計も成功した。17宣言の公理依存はpropext・Classical.choice・Quot.soundの範囲だけである。外側の実時間は59.81秒、最大常駐量はtimeのsysctlがサンドボックスで拒否され取得できなかった。詳細は[作業結果](../c1r2/results.md)に記す。独立レビューとC1R2の受け入れは取りまとめの担当である。

# RV-L00b.14b: 所見への対応の再確認依頼

2026-11-01。RV-L00b.14b（条件付き可）の中3件・軽4件への対応の再確認を依頼する。指定ブランチは `m014/l00b.14b`、B_WORK は `b32ef9c93b89e43131a1c96831a4eadfb6fa9512` である。担当は Git の操作を行っていない。現在の未コミットの作業を対象とし、基準との Git による独立照合は取りまとめが行う。開始時のハッシュと現在の比較は [source-delta.json](../l00b.14b/source-delta.json) にある。

## 対象と主張

分類は「閉じた」である。現行の規則は Φ を増やさないので、この代表の Φ は実プログラムから生じない。実行が条件を真にする接続は未検査である。規則の追加と K_Guard の変更は別作業 L00b.14b-paths で行う。評価成功から捕捉 Φ の閉じた導出を構成し、非空の引数 facts と一緒に閉包本体で使う代表が閉じた。状態の定理は、開始の StateTyE の逆転を含まない同時構成である。全状態の保存、開始の V_Closure/V_Sub/TelClosure の一般逆転は主張しない。

本番は新規の [CapturedFacts.lean](../../../formal/Benitoite/Release/Refinement/CapturedFacts.lean) の7補題と、既存 `formal/Benitoite.lean` の import 1行である。既存の判断・遷移・主定理・信頼条件は変えていない。新しい定義と Lean の公理は0である。[signatures.md](../l00b.14b/signatures.md)は、レビューに従い evaluated_fact の前提削除と addEntailed の追加を先に記してから実装した。

## 読む順と確認点

1. plan の2026-10-31以降の変更、L00b.14b の行と分類、O008・O051・O160。README の設計者の決定、decisions の D19/D24、l00a.06a/contracts と l00a.16a/lemmas。いずれも今回変更していない。
2. 前段の l00b.14a/signatures・results、RV-L00b.14a と取りまとめの追記。closure_one・hideConts_any・extend・facts_extend の使い方が今回の捕捉の契約と合うか。
3. 今回の [完全署名](../l00b.14b/signatures.md)、[結果](../l00b.14b/results.md)、本番の CapturedFacts、[境界](../l00b.14b/boundary.lean)。補助契約の決定と残件表を含む。

特に次を確認してほしい。

- `evaluated_fact` が評価器自身の WF/Sorted の検査を使い、評価成功だけから D19 の閉じた導出を得ること。旧の hc・hp と不要な暗黙引数を外したこと。
- 新しい `addEntailed` の8欄と事実の3場合が保たれ、addEvaluated がその系であり、`close_entails` が bind/cut で仮定なしの有限導出を返すこと。欠落した観測を既定の整数へ変えて成功としていないこと。
- `captured_beta_one` が実際の `.closure` の値を E_Lam へ通し、同じ捕捉環境の延長で結果・効果・return を閉じること。開始と到達の Ψ・μ・σ・b・ε・Eb が同じであること。主張は同時構成であること。
- 境界の `argument_facts_nonempty`・`extended_facts`・`extended_ok` が、`Integer{0 ≤ self}` の空でない facts を使うこと。`return_argument`・`return_zero` の篩導入が Φ を読み、`body_requires_phi` がその必要性を示すこと。
- `execution c` が c=true/false の E_IfT/F の前後を StateTy で構成し、`selected_view`・`returned_typed` が同じ実行の実際の値3/0に `Integer{0 ≤ self ∧ 7 < 8}` を与えること。値の型付けは StateTy の逆転ではなく、同じ本体から別に構成すること。
- `environment_counterexample` が、同じ Γ と型付き像を持つ7/8の実環境で Φ の保持が異なる反例になっていること。`no_wrong_phi` と `wrong_return_untyped` が、整形式の条件・型について誤った事実を否定すること。
- 現行の全規則が Φ を増やさないという限定を明記したこと。規則追加と K_Guard の変更を paths、遷移との一般の接続と組み込みの事実・O054 を L20/L30/L40 に分けたこと。
- 分類・場合の数・残る言明・依存・能動時間・L20/L40 の配分が妥当であり、全状態の保存を代表の残件の表へ混ぜていないこと。

## 検査済みの範囲

担当は [verify.py](../l00b.14b/verify.py) を実行した。既定の `cd formal && lake build` は717 jobs、終了0、sorry なし。境界・公理依存・公開署名・実行版の確認も終了0である。全ての Lean プロセスは -M 12288 を使う。

公理依存は14,012宣言で、Refinement全135モジュールと集約、旧モデル/主定理12宣言、境界97宣言を含む。依存は propext・Quot.sound・Classical.choice だけで、sorryAx・未承認公理・未監査モジュールは0。[axioms-summary.json](../l00b.14b/axioms-summary.json)と[verification.json](../l00b.14b/verification.json)を参照する。

既定ビルドを繰り返すかどうかはレビューの必要に応じて判断してほしい。境界を再実行する入口は、formal 内の `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14b/boundary.lean` である。大きい生記録は [large-records.md](../l00b.14b/large-records.md) に `<tmp>` の名前・大きさ・SHA-256 を記した。

work・Rust/Lean の全比較・RSS 採取・独立レビュー・受け入れは未実施である。work は指定どおり取りまとめが行う。今回の範囲で止め、L00b.14c の作業は行っていない。

## 所見ごとの再確認点

| 所見 | 今回の処置 |
|---|---|
| 中1 | 分類と O051/O160 に実プログラムから非空 Φ が生じない限定を明記。残件を規則追加と遷移の接続に分けた |
| 中2 | guard を同じ Φ の再構成の行から外し、K_Guard の変更と x=9 の再現を paths に配分した。今回未実装 |
| 中3 | addEntailed を本番へ追加し、addEvaluated をその系にした。評価成功だけで全条件を扱えるという記述を撤回した |
| 軽1 | evaluated_fact の入力を p.evalClosed=some true だけにした |
| 軽2 | 呼出し元の捕捉と .lam→.closure の型保存の行を加えた |
| 軽3 | T2 の return_capture・returned_capture_typed・returned_capture_fact・closed_gamma_fact を境界へ移した |
| 軽4 | get後snapshotのΦをset後も保つ確認と、Reference欄の欠落観測の確認を14cへ申し送った |

T2 の主な証拠は、Φ だけを使う開いた本体の型付け return_capture と、値7に Integer{self<8} を与える returned_capture_typed の組である。closed_gamma_fact は Γ.facts 側の仮定を close_entails へ渡す。これらを含む97宣言を境界の公理監査で確認した。実行から新しい Φ が生じる例ではない。

初回の結果・署名・集計は initial-*、初回の検査ログと入力の照合は first-* に保管した。rv-14b-t1/t2 は読み取り専用で、変更していない。本番と重複する宣言を持つ rv-t1 をそのまま再実行せず、移した補題と境界を監査した。work と paths/14c は実行していない。

## ファイルの全一覧

パスは本改造からの相対位置とする。本番はリポジトリの根から示す。files.json に大きさと SHA-256 を記録する。初回の一覧は initial-files.json に保管した。今回の本番の差は CapturedFacts の1ファイルだけで、集約の import は初回から変えていない。

| ファイル | 内容・扱い |
|---|---|
| formal/Benitoite/Release/Refinement/CapturedFacts.lean | 初回の新規本番。今回7補題へ更新 |
| l00b.14b/axiom-targets.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/axioms-summary.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/axioms.lean | 全モジュールと旧主定理の公理監査入口 |
| l00b.14b/axioms.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/boundary.lean | 正例・負例と97宣言の監査入口 |
| l00b.14b/boundary.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/build.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/case-inventory.txt | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/environment.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/first-axiom-targets.log | 初回の記録の保管 |
| l00b.14b/first-axioms.log | 初回の記録の保管 |
| l00b.14b/first-boundary.log | 初回の記録の保管 |
| l00b.14b/first-build.log | 初回の記録の保管 |
| l00b.14b/first-environment.json | 初回の記録の保管 |
| l00b.14b/first-input-stability.json | 初回の記録の保管 |
| l00b.14b/first-inputs-sha256.json | 初回の記録の保管 |
| l00b.14b/first-large-records.md | 初回の記録の保管 |
| l00b.14b/first-lean-version.log | 初回の記録の保管 |
| l00b.14b/first-protected-inputs.json | 初回の記録の保管 |
| l00b.14b/first-public-api.log | 初回の記録の保管 |
| l00b.14b/first-source-delta.json | 初回の記録の保管 |
| l00b.14b/initial-axioms-summary.json | 初回の記録の保管 |
| l00b.14b/initial-files.json | 初回の記録の保管 |
| l00b.14b/initial-results.md | 初回の記録の保管 |
| l00b.14b/initial-signatures.md | 初回の記録の保管 |
| l00b.14b/initial-verification.json | 初回の記録の保管 |
| l00b.14b/input-stability.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/inputs-sha256.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/large-records.md | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/lean-version.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/protected-inputs.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/public-api.lean | 公開7補題の署名出力入口 |
| l00b.14b/public-api.log | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/results.md | 分類・対応・検査・時間 |
| l00b.14b/review-reference-updates.json | レビュー対応の入力・差・照合 |
| l00b.14b/review-source-delta.json | レビュー対応の入力・差・照合 |
| l00b.14b/review-start-inputs.json | レビュー対応の入力・差・照合 |
| l00b.14b/rv-14b-t1.lean | 取りまとめが提供した読み取り専用の補助入力 |
| l00b.14b/rv-14b-t2.lean | 取りまとめが提供した読み取り専用の補助入力 |
| l00b.14b/signatures.md | 完全署名・決定・残件・pathsへの申し送り |
| l00b.14b/source-delta.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/start-inputs.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/verification.json | 入力・出力・検査の証拠（詳細はresults） |
| l00b.14b/verify.py | 既定ビルドと監査・入力照合の台本 |
| l00b.14b/files.json | 全成果物のハッシュ一覧（自己ハッシュを除く） |
| reviews/RV-L00b.14b-request.md | 本依頼文。今回更新 |

既存ファイル formal/Benitoite.lean の import 1行は初回の追加であり、今回は変えていない。処理系・設計書・plan・レビュー本文・rv-* と型付け規則は変更していない。

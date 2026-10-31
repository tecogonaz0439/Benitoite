# RV-L00b.14a: 所見対応後の再確認依頼

2026-11-01。RV-L00b.14a の条件付き可（重なし・中3・軽6）と取りまとめの追記、plan の先頭の判断への対応を確認してほしい。分類は「閉じた」。開始の StateTyE からの逆転を含まない同時構成である。今回の変更後の独立した再確認と受け入れは未実施である。

## 対象と前提

ブランチ指定は m014/l00b.14a、B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e`。今回の開始は2026-10-31 17:17:24 UTC、上限は2時間。git・work・L00b.14b の作業は行っていない。

今回の本番変更は [DependentBeta.lean](../../../formal/Benitoite/Release/Refinement/DependentBeta.lean) だけである。[review-source-delta.json](../l00b.14a/review-source-delta.json) が今回の開始との照合、[source-delta.json](../l00b.14a/source-delta.json) が初回の開始との照合である。初回からの既定 import は維持した。処理系・設計書・plan・レビュー本文・rv-* は変更していない。

現在の契約は [signatures.md](../l00b.14a/signatures.md)、所見ごとの処置・限界・検査は [results.md](../l00b.14a/results.md)、実際の境界は [boundary.lean](../l00b.14a/boundary.lean)。初回の文面は initial-results.md・initial-signatures.md・initial-review-request.md に分けた。

## 所見への処置と確認点

| 所見 | 実装・文書の処置と確認してほしい点 |
|---|---|
| 中1 | mark_inv と任意の R の markPush を本番へ置き、状態の二定理から R=none を外した。hR は開始の ClosureTy.pure の WF/Declared/Normal を供給する証拠である。hideConts_any と closure_one を本番へ置いた。呼ばれる側の `.dependentLam` の直書きなど残る限定と、`.closure` の状態の接続の残件を明示した |
| 中2 | 分類の段落に、開始の StateTyE からの逆転を含まない同時構成と記した。O160 の再提示も同じ意味で扱う |
| 中3 | 二つの残件表の保存の行を β の遷移に限った。全状態の保存は L20/L40 の既存の枠のままで表の外である |
| 軽1 | 本体を hideBuilders Ψ で受け、既存の ValueAssumptions と StoreOk の WF から Ψ へ移す。hideBuilders Ψ=Ψ を前提から外した。builder を持つ有限ストアの両状態で確認した |
| 軽2 | 残件表を同じ内容にし、hcv を外すための closeVal の型保存と、開始/到達の型・効果の契約の一致を記した |
| 軽3 | concrete_result・returned_typed・wrong_result_untyped・wrong_received の組を主な証拠とした。7=7だけを接続の証拠にしない |
| 軽4 | closure_one と hideConts_any、篩のある引数型で空でない facts の境界を L00b.14b へ申し送った。今回その作業はしていない |
| 軽5 | StateTy と値の型付けを同じ本体から別々に作ること、received_step と received_facts は receive_success を共有し、前者は StateTy を作らないことを明記した |
| 軽6 | markPush の判定を eq_cons_or_merge にまとめ、ContTy と Closed の両方で使う。旧の not_mark を削除し、StateTy の ht の再束縛を hstep に直した |

特に、一般の R で mark の入力の LeQ を K_Sub と K_Mark で組み直す箇所、hideConts_any が隠した継続の ImageOk を使わず R を付け替えられる箇所、closure_one の捕捉と本体の hideConts Γ の一致を確認してほしい。主な定理・信頼条件の欄・新しい公理・提供範囲・書ける形・精密な外部状態は変更していない。

## 実際に使った入口

- 元の結果型と Fail の型の両方への代入、および具体化した型付けと誤った型付けの否定の組を維持した。
- Review.beta_with_builder は、旧の hideBuilders の等号が偽である実際の builder ストアで、一般化した定理の開始と到達を構成する。
- Review.beta_with_existing_mark は、R=some の開始と mark の併合を持つ両状態を構成する。
- Review.captured_application は、外側の7を捕捉して返す閉包の本体に closure_one を適用する。captured_hidden は hideConts_any の入口、captured_step は同じ閉包を実際の E_Lam へ渡す入口である。ここでの StateTy の一般化は未完である。

## 検査と記録

更新した verify.py で五検査を全て再実行した。既定 cd formal && lake build は716 jobs、終了0、0.807447秒。境界は終了0で私有・生成を含む95宣言。公開17補題の完全署名も終了0。Lean のプロセスは既定の lakefile と単独実行の双方が -M 12288。

公理監査は14,003宣言で、Refinement全134モジュール・集約・旧モデル/主定理12宣言・現在の境界を含む。新しい本番の私有・生成を含む28宣言も全て対象とし、依存は propext・Quot.sound・Classical.choice だけ。sorryAx・未承認公理・未監査モジュールは0。[verification.json](../l00b.14a/verification.json)、[axioms-summary.json](../l00b.14a/axioms-summary.json)、[public-api.log](../l00b.14a/public-api.log)、[case-inventory.txt](../l00b.14a/case-inventory.txt) を参照する。

[inputs-sha256.json](../l00b.14a/inputs-sha256.json) の147入力は検査中の変更0。今回の開始の plan・レビュー本文・rv-* など保護対象97入力も変更0。更新を指示された本依頼だけは保護対象から除いた。大きい生出力と対象名は tmp に保存し、[large-records.md](../l00b.14a/large-records.md) に大きさとSHA-256を残した。局所検査の初回失敗と修正は [local-checks.md](../l00b.14a/local-checks.md)。RSSは計画上の非採取で未取得。

rv-14a-t1/t2/t4 は本番へ移した同名宣言を持つ読み取り専用の入力として保管した。本番への移植後にそのまま実行すると重複宣言になるため、元のファイルを改変せず、本番と更新した境界で検査した。

## ファイルの一覧

今回増やした本番ファイルはなく、初回に追加した DependentBeta.lean を改めた。初回の既定集約の import は維持した。成果物の全一覧とSHA-256は [files.json](../l00b.14a/files.json)。この一覧では、本作業の成果物と設計者から渡された rv-* を区別する。files.json 自体は自己参照のハッシュを持たない。

改造の l00b.14a/ の現在の全ファイルは次のとおりである。初回の記録を保存するために今回作った initial-* も省いていない。

| ファイル | 扱い・リンク |
|---|---|
| `axiom-targets.log` | [axiom-targets.log](../l00b.14a/axiom-targets.log) |
| `axioms-summary.json` | [axioms-summary.json](../l00b.14a/axioms-summary.json) |
| `axioms.lean` | [axioms.lean](../l00b.14a/axioms.lean) |
| `axioms.log` | [axioms.log](../l00b.14a/axioms.log) |
| `boundary.lean` | [boundary.lean](../l00b.14a/boundary.lean) |
| `boundary.log` | [boundary.log](../l00b.14a/boundary.log) |
| `build.log` | [build.log](../l00b.14a/build.log) |
| `case-inventory.txt` | [case-inventory.txt](../l00b.14a/case-inventory.txt) |
| `files.json` | [files.json](../l00b.14a/files.json) |
| `final-checks.json` | [final-checks.json](../l00b.14a/final-checks.json) |
| `first-inputs-sha256.json` | [first-inputs-sha256.json](../l00b.14a/first-inputs-sha256.json) |
| `first-large-records.md` | [first-large-records.md](../l00b.14a/first-large-records.md) |
| `first-public-api.log` | [first-public-api.log](../l00b.14a/first-public-api.log) |
| `first-verification.json` | [first-verification.json](../l00b.14a/first-verification.json) |
| `initial-axiom-targets.log` | [initial-axiom-targets.log](../l00b.14a/initial-axiom-targets.log) |
| `initial-axioms-summary.json` | [initial-axioms-summary.json](../l00b.14a/initial-axioms-summary.json) |
| `initial-axioms.log` | [initial-axioms.log](../l00b.14a/initial-axioms.log) |
| `initial-boundary.lean` | [initial-boundary.lean](../l00b.14a/initial-boundary.lean) |
| `initial-boundary.log` | [initial-boundary.log](../l00b.14a/initial-boundary.log) |
| `initial-build.log` | [initial-build.log](../l00b.14a/initial-build.log) |
| `initial-case-inventory.txt` | [initial-case-inventory.txt](../l00b.14a/initial-case-inventory.txt) |
| `initial-files.json` | [initial-files.json](../l00b.14a/initial-files.json) |
| `initial-final-checks.json` | [initial-final-checks.json](../l00b.14a/initial-final-checks.json) |
| `initial-input-stability.json` | [initial-input-stability.json](../l00b.14a/initial-input-stability.json) |
| `initial-inputs-sha256.json` | [initial-inputs-sha256.json](../l00b.14a/initial-inputs-sha256.json) |
| `initial-large-records.md` | [initial-large-records.md](../l00b.14a/initial-large-records.md) |
| `initial-local-checks.md` | [initial-local-checks.md](../l00b.14a/initial-local-checks.md) |
| `initial-protected-inputs.json` | [initial-protected-inputs.json](../l00b.14a/initial-protected-inputs.json) |
| `initial-public-api.lean` | [initial-public-api.lean](../l00b.14a/initial-public-api.lean) |
| `initial-public-api.log` | [initial-public-api.log](../l00b.14a/initial-public-api.log) |
| `initial-results.md` | [initial-results.md](../l00b.14a/initial-results.md) |
| `initial-review-request.md` | [initial-review-request.md](../l00b.14a/initial-review-request.md) |
| `initial-signatures.md` | [initial-signatures.md](../l00b.14a/initial-signatures.md) |
| `initial-source-delta.json` | [initial-source-delta.json](../l00b.14a/initial-source-delta.json) |
| `initial-verification.json` | [initial-verification.json](../l00b.14a/initial-verification.json) |
| `initial-verify.py` | [initial-verify.py](../l00b.14a/initial-verify.py) |
| `input-stability.json` | [input-stability.json](../l00b.14a/input-stability.json) |
| `inputs-sha256.json` | [inputs-sha256.json](../l00b.14a/inputs-sha256.json) |
| `large-records.md` | [large-records.md](../l00b.14a/large-records.md) |
| `lean-version.log` | [lean-version.log](../l00b.14a/lean-version.log) |
| `local-checks.md` | [local-checks.md](../l00b.14a/local-checks.md) |
| `protected-inputs.json` | [protected-inputs.json](../l00b.14a/protected-inputs.json) |
| `public-api.lean` | [public-api.lean](../l00b.14a/public-api.lean) |
| `public-api.log` | [public-api.log](../l00b.14a/public-api.log) |
| `results.md` | [results.md](../l00b.14a/results.md) |
| `review-first-boundary.log` | [review-first-boundary.log](../l00b.14a/review-first-boundary.log) |
| `review-source-delta.json` | [review-source-delta.json](../l00b.14a/review-source-delta.json) |
| `review-start-inputs.json` | [review-start-inputs.json](../l00b.14a/review-start-inputs.json) |
| `rv-14a-t1.lean` | 提供された読み取り専用の入力。[rv-14a-t1.lean](../l00b.14a/rv-14a-t1.lean) |
| `rv-14a-t2.lean` | 提供された読み取り専用の入力。[rv-14a-t2.lean](../l00b.14a/rv-14a-t2.lean) |
| `rv-14a-t3.lean` | 提供された読み取り専用の入力。[rv-14a-t3.lean](../l00b.14a/rv-14a-t3.lean) |
| `rv-14a-t4.lean` | 提供された読み取り専用の入力。[rv-14a-t4.lean](../l00b.14a/rv-14a-t4.lean) |
| `rv-14a-t5.lean` | 提供された読み取り専用の入力。[rv-14a-t5.lean](../l00b.14a/rv-14a-t5.lean) |
| `signatures.md` | [signatures.md](../l00b.14a/signatures.md) |
| `source-delta.json` | [source-delta.json](../l00b.14a/source-delta.json) |
| `start-inputs.json` | [start-inputs.json](../l00b.14a/start-inputs.json) |
| `verification.json` | [verification.json](../l00b.14a/verification.json) |
| `verify.py` | [verify.py](../l00b.14a/verify.py) |


本レビュー依頼 reviews/RV-L00b.14a-request.md も更新対象である。L00b.14b には進んでいない。所見対応の再確認・work・取り込み・受け入れは取りまとめと設計者へ委ねる。

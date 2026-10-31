# RV-L00b.14a: 一引数の依存βのレビュー依頼

2026-11-01。実装担当から取りまとめへの群末レビューの入力である。分類は「閉じた」で、記した代表の言明を閉じた意味である。全β・全状態の保存は未完である。レビュー本文と rv-* の入力は変更していない。

## 固定した条件と対象

指定ブランチは `m014/l00b.14a`、B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e`。git の操作・work・L00b.14b の作業はしていない。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変えていない。

本番の新規ファイルは [DependentBeta.lean](../../../formal/Benitoite/Release/Refinement/DependentBeta.lean) の1ファイル、既存の変更は [既定の集約](../../../formal/Benitoite.lean) の import 1行である。開始時とのハッシュ比較は [source-delta.json](../l00b.14a/initial-source-delta.json)。新規・変更ファイルの最終一覧とハッシュは [files.json](../l00b.14a/initial-files.json) にある。

[完全署名](../l00b.14a/initial-signatures.md)、[結果](../l00b.14a/initial-results.md)、[完全署名の出力](../l00b.14a/initial-public-api.log)、[正負の境界](../l00b.14a/initial-boundary.lean) を本番と合わせて読んでほしい。読み取りの前提は共通依頼文、plan の2026-10-31以降の変更・当該行と O008/O051、L00b.11/.13 の申し送り、README の設計者の決定、decisions、L00a.06a の契約、L00a.16a の補題のままである。

## 確かめてほしい点

1. open_one が任意の Γ/Φ を保ち、SubstOk.openValue と既存の相互置換から、結果型・行・return 契約を同時に移しているか。局所参照が空の代表と、一般の L20 の残りを混ぜていないか。
2. Capture.instantiate_one と ClosureTy.dependent_one が、実際の Closure.apply に実引数を保持し、ソースの本体を置換済みの本体へ取り替えていないか。
3. StateTyE.dependent_beta_one の前後の Ψ/μ、具体化した型、継続の結果 b、現在の行 ε、固定 Eb と σ が同じか。R=none から関数自身の return 契約と mark を構成する箇所が正しいか。
4. Normal・hideBuilders Ψ=Ψ・closeVal Capture.empty v=v が代表の条件として明示され、一般の主定理の前提を強めたことにしていないか。残る closeVal の型保存と fn/dependentFn の逆転が L20/L40 の残件にあるか。
5. ret_value が C_Sub/C_Eff/C_Normal を含む24場合を尽くすか。実際の依存βで得た return の値に L00b.13 の facts を適用しているか。StateTy 自体からの一般の逆転の完成と取り違えていないか。
6. 境界が結果と Fail の型の両方へ7を代入し、Fail の処置を持つ継続と Eb=empty を実際に構成しているか。7=8 と falsity の負例が、別の整形式違反で拒まれた例ではないか。
7. received_facts と Received の境界が、三つの応答仮定と受信成功後の元の型付けを使っているか。同じ値について誤った篩の Carrier が構成できても受信検査が拒むこと、外部の精密な状態を加えていないことを確認してほしい。
8. O008/O051/O160 の今回の代表と、捕捉Φ・Reference・Lazy・節/resume・全保存の残りの分類が適切か。全βへの残る言明・依存・能動時間・送り先の表に漏れがないか。

## 検査の証拠と限界

既定 `cd formal && lake build` は716 jobs、終了0、0.816039秒の増分ビルド。単独の Lean は全て -M 12288、既定ビルドは lakefile の同じ値である。境界は終了0で、私有・生成を含む71宣言を監査した。公理依存は全 Refinement134モジュール・集約・旧モデル/主定理12宣言・境界を含む13,965宣言で、propext・Quot.sound・Classical.choice のみである。新モジュール14宣言を含み、未監査・sorryAx・未承認公理は0。

[verification.json](../l00b.14a/initial-verification.json)、[axioms-summary.json](../l00b.14a/initial-axioms-summary.json)、[case-inventory.txt](../l00b.14a/initial-case-inventory.txt)、[入力のハッシュ](../l00b.14a/initial-inputs-sha256.json)、[大きい記録](../l00b.14a/initial-large-records.md) を残した。plan と既存レビュー・rv-* を含む91入力は不変である。

最初の記録付き検査は署名列挙器だけが失敗した。Name.isPrivate の参照を直し、公開10補題を明示して所属を照合した。成功した三検査は本番・境界・監査の入力と生出力が同じため引用した。初回の失敗と修正理由は [local-checks.md](../l00b.14a/initial-local-checks.md) と first-* に残している。自己点検を独立レビュー済みとは記録していない。RSS は計画上の非採取、Rust/Lean の全比較と全状態の保存は未実施である。

## 新規ファイルの一覧

本番は上記 DependentBeta.lean、本レビュー依頼は本書 `reviews/RV-L00b.14a-request.md` である。改造の `l00b.14a/` に新規作成したファイルは次の全件である。files.json 自体は自己参照のハッシュを持たず、一覧の項目として載せる。

| 新規ファイル | 相対リンク |
|---|---|
| `axiom-targets.log` | [axiom-targets.log](../l00b.14a/initial-axiom-targets.log) |
| `axioms-summary.json` | [axioms-summary.json](../l00b.14a/initial-axioms-summary.json) |
| `axioms.lean` | [axioms.lean](../l00b.14a/axioms.lean) |
| `axioms.log` | [axioms.log](../l00b.14a/initial-axioms.log) |
| `boundary.lean` | [boundary.lean](../l00b.14a/initial-boundary.lean) |
| `boundary.log` | [boundary.log](../l00b.14a/initial-boundary.log) |
| `build.log` | [build.log](../l00b.14a/initial-build.log) |
| `case-inventory.txt` | [case-inventory.txt](../l00b.14a/initial-case-inventory.txt) |
| `files.json` | [files.json](../l00b.14a/initial-files.json) |
| `final-checks.json` | [final-checks.json](../l00b.14a/initial-final-checks.json) |
| `first-inputs-sha256.json` | [first-inputs-sha256.json](../l00b.14a/first-inputs-sha256.json) |
| `first-large-records.md` | [first-large-records.md](../l00b.14a/first-large-records.md) |
| `first-public-api.log` | [first-public-api.log](../l00b.14a/first-public-api.log) |
| `first-verification.json` | [first-verification.json](../l00b.14a/first-verification.json) |
| `input-stability.json` | [input-stability.json](../l00b.14a/initial-input-stability.json) |
| `inputs-sha256.json` | [inputs-sha256.json](../l00b.14a/initial-inputs-sha256.json) |
| `large-records.md` | [large-records.md](../l00b.14a/initial-large-records.md) |
| `lean-version.log` | [lean-version.log](../l00b.14a/lean-version.log) |
| `local-checks.md` | [local-checks.md](../l00b.14a/initial-local-checks.md) |
| `protected-inputs.json` | [protected-inputs.json](../l00b.14a/initial-protected-inputs.json) |
| `public-api.lean` | [public-api.lean](../l00b.14a/initial-public-api.lean) |
| `public-api.log` | [public-api.log](../l00b.14a/initial-public-api.log) |
| `results.md` | [results.md](../l00b.14a/initial-results.md) |
| `signatures.md` | [signatures.md](../l00b.14a/initial-signatures.md) |
| `source-delta.json` | [source-delta.json](../l00b.14a/initial-source-delta.json) |
| `start-inputs.json` | [start-inputs.json](../l00b.14a/start-inputs.json) |
| `verification.json` | [verification.json](../l00b.14a/initial-verification.json) |
| `verify.py` | [verify.py](../l00b.14a/initial-verify.py) |

L00b.14b は未着手である。受け入れ後の起動・work・取り込みは取りまとめへ委ねる。

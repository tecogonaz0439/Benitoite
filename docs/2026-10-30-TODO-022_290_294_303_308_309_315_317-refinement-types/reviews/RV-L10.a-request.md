# RV-L10.a: 共有近似と実解析の写しのレビュー依頼

2026-11-01。L10.52〜L10.54 の初回レビューは条件付き可（中2・軽3）であった。全所見を処置した版について、定義・言明・仮定と、01-12・07-04・用語集の写しの変更箇所を確認してほしい。担当の自己照合を終え、処置後の既定ビルド・境界・公理依存は成功した。処置の確認と受け入れは未実施である。

指定ブランチは `m014/l10.a`、B_WORK は `a0dc79a7a0014d1b4d4f61f8ac817beffec2f030`。担当は git 操作をしていない。[結果](../l10/a/results.md)に単位別・義務別の判定と残り、[完全署名](../l10/a/signatures.md)に補助の契約の判断を記した。[入力の識別](../l10/a/inputs-sha256.json)で対象を固定する。

## 特に確かめてほしい点

1. `ValueApprox.WF` が空の三表現を許し、格納済みの区間の証拠から全近似の WF が導かれること。possible が所属する値の存在と同値で、normal の空だけから returned/failed の非所属を結論していないこと。
2. `normalToShared_iff` の逆向きが明示の型一致の下で成り立つこと。旧正常域の定義・既存定理を弱めていないこと。
3. `baseToShared` が非整数・非Boolean でも other と nonIntegerOther の両フラグを読み、正常値なしを保つこと。`Report.sharedFlow` が同じ Report の実データを読み、任意 Prop から範囲を計算で取り出していないこと。returned は明示引数で、normal に混ざらず、mayFail の射影を失敗の意味の健全性と説明していないこと。
4. `constOK_toApprox` が七整数だけを条件とし、Byte・Decimal・String の非 other を主張していないこと。境界の14端点と値域外2件に独立した期待値があること。Byte256、Decimal の係数下端・下端外・scale29も確認していること。∃ n だけでは元の定数の値との一致を結論しないことを L40 の入力へ記したこと。
5. 境界の正例が結論を仮定せず、実解析した加算・u64上端・Boolean/Unitの位置のreturn・あふれを通ること。u64上端とUnitの位置のreturnは coverage=complete も確認すること。抽象的な Report の非公開補助へ渡す成分の等式を、具体例で計算していること。
6. 主な定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態の五つの境界を変えていないこと。設計書が今置いた定義と証明だけを記し、工程 ID や未実施の予告を含まないこと。

## 変更した既存ファイル

| ファイル | 内容 |
|---|---|
| `formal/Benitoite/Shared/Approximation.lean` | WF・possible と所属の同値・全近似の WF |
| `formal/Benitoite/Interval/ApproxAdapter.lean` | 旧正常域の限定逆方向、実 BaseApprox の正常値の有無を保つ写しと所属保存 |
| `formal/Benitoite/Interval/BudgetAnalyze.lean` | 実 Report の共有フローと正常値・returned・mayFail の接続 |
| `formal/Benitoite/Release/Refinement/ApproxAdapter.lean` | 七整数に限る適格な定数の写し |
| `docs/design/01-spec/01-12-core-calculus.md` | 共有近似・空・実解析の写しの定義と言明 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 形式化との対応と保証の範囲 |
| `docs/design/00-overview/00-04-glossary.md` | 既存の形式化の定義名 ValueApprox・FlowApprox の説明 |

## 新規ファイルの全一覧

以下はすべて本改造を根とする相対パスである。生出力はすべて100,000バイト以下であり、large-records.md は作成していない。

| 新規ファイル | 内容 |
|---|---|
| `l10/a/signatures.md` | 完全署名、補助の契約、境界例の関門 |
| `l10/a/boundary.lean` | 名前付き境界定理15件と、補助・生成宣言を含む監査 |
| `l10/a/axioms.lean` | 変更四モジュール全宣言、旧主定理・モデル・相互補題・旧区間定理の監査 |
| `l10/a/verify.py` | 検査、時間・出力・公理依存・ハッシュの記録の入口 |
| `l10/a/results.md` | 単位・義務・場合の数・検査・時間・残りの記録 |
| `l10/a/build-output.txt` | 既定ビルドの生出力 |
| `l10/a/build-result.json` | ビルドのコマンド・終了・時間・出力ハッシュ |
| `l10/a/boundary-output.txt` | 境界入力と公理依存の生出力 |
| `l10/a/boundary-result.json` | 境界入力のコマンド・終了・時間・出力ハッシュ |
| `l10/a/boundary-axioms.json` | 境界327宣言の完全名・公理依存 |
| `l10/a/axioms-output.txt` | 四モジュールと既存定理の公理依存の生出力 |
| `l10/a/axioms-result.json` | 公理依存のコマンド・終了・時間・出力ハッシュ |
| `l10/a/axioms-axioms.json` | 512宣言の完全名・公理依存 |
| `l10/a/inputs-sha256.json` | ソース・設定・文書・検査入力の識別 |
| `l10/a/regression-before-output.txt` | 修正前の adapter で Unit の normal の空の境界が失敗する生出力 |
| `l10/a/regression-before-result.json` | 修正前の失敗のコマンド・時間・境界入力と adapter 成果物のハッシュ |
| `l10/a/rv-a-t1.lean` | 取りまとめが保存したレビューの補助入力。変更していない |
| `l10/a/rv-a-t2.lean` | 取りまとめが保存したレビューの補助入力。変更していない |
| `reviews/RV-L10.a-request.md` | 本依頼 |

## 検査の証拠と残り

既定の `cd formal && lake build` は終了0、774ジョブ、外側48.162秒。最終の境界は1.298秒、公理依存は0.970秒、どちらも終了0である。変更四モジュール492宣言と既存定理20件、境界327宣言の監査は、propext・Quot.sound・Classical.choice のみで、sorryAx・独自公理・許可外依存は0件である。既定 build と単一ファイルは `-M 12288`、RSS は計画上の非採取である。

work は依頼の指定に従って担当は実行せず、取りまとめへ渡す。L10.55 へ進まず本群で止めた。O169 のうち残る独立評価と Release の意味の接続、returned/failed の条件付き所属は L20/L40、全合成は L70 の範囲である。


## 今回の処置の照合

| 所見 | 処置 |
|---|---|
| 中1 | baseToShared の最後の枝をフラグの連言による unknown/bottom へ変更。precise_mem を本番の所属保存へ移し、Unit の位置の return の境界を追加 |
| 中2 | results の義務表へ O011・O124・O129 を追加し、Byte/Decimal の不足する境界4件を追加 |
| 軽1 | constOK_toApprox の言明を保ち、元の値と n.toInt の一致が必要なら L40 で補題を加えることを signatures/results に明記 |
| 軽2 | report_width に coverage=complete を追加 |
| 軽3 | 01-12 の指す先を Release.Refinement と明記 |

修正前の adapter では、Unit の normal の空を主張する境界が意図した箇所の1件で失敗し、修正後の同じ境界は成功した。レビュー原本 RV-L10.a.md と rv-a-t1/t2 は変更していない。rv-a-t1 は修正前の定義を読む例も含むため、原本全体の再実行を成功の条件とはせず、所属保存を本番へ移した上で具体的な境界と全宣言の公理依存を検査した。検査台本は処置後の記録に revision を付け、入力の識別にレビュー原本と補助入力を含める形へ更新した。

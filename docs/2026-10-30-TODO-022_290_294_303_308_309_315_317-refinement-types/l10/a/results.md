# 共有近似と実解析の写しの実装結果

2026-11-01。L10.52〜L10.54 は、担当の実装・局所検査・既定ビルド・公理依存の確認を完了した。初回の独立レビューは条件付き可（中2・軽3）であり、所見を処置した版を取りまとめへ渡す。処置の確認と受け入れは未実施である。L10.55 には進んでいない。

指定ブランチは `m014/l10.a`、B_WORK は **`a0dc79a7a0014d1b4d4f61f8ac817beffec2f030`**。git の読取り・変更操作は行わず、値は依頼から記した。対象はこの基準へ加える未コミットの担当差分である。入力の識別は [inputs-sha256.json](inputs-sha256.json) に保存する。処理系・plan・detail・既存レビュー・rv-* は変更していない。

## 単位ごとの完了の判定

| 単位 | 判定 | 閉じた定義・補題と証拠 |
|---|---|---|
| L10.52 | 閉じた | `ValueApprox.possible`・`WF`、`FlowApprox.WF`、`ValueApprox.possible_iff`・`not_possible_iff`・`wf`、`FlowApprox.wf`、`normalToShared_iff`。空の三表現を許し、所属と空判定を結んだ。normal の空から全制御の非所属を結論しない |
| L10.53 | 閉じた | `baseToShared`・`baseToShared_mem`、`Report.sharedFlow`・`shared_normal`・`shared_returned`・`shared_mayFail`。実 Report の同じ `approx` から normal を写し、非整数・非Boolean の正常値なしも保持する。returned は明示引数、mayFail は射影である |
| L10.54 | 閉じた | `constOK_toApprox`。七整数という条件の下で、同じ幅の証拠付き整数へ写る。Byte・Decimal の other を残し、上下端14件と値域外2件、Byte の値域外、Decimal の係数下端・下端外・scale 29 を確認した |

新しい公開宣言は定義5件・定理10件の計15件である。完全署名と補助の契約の判断は、実装に先立って置いた [signatures.md](signatures.md) にある。これらは既定 import に含まれる既存の四モジュールへの追加であり、既存の主定理や例を import から外していない。

## 義務の自己照合

detail の A 節、単位表 .52〜.54、検査・レビュー・受け入れの表と照合した。以下は群 A の担当分の判定であり、O169 全体の完了ではない。

| 義務 | 判定と証拠 | 残りと送り先 |
|---|---|---|
| O011 の .54 の分 | 七整数の `ConstOK`・`IntegerValue`・`toApprox` の幅を `integer_endpoints` と `integer_endpoint_entry` で確認。Byte の255の受理・256の拒否、Decimal の係数と scale の境界、other の写しも境界で確認 | .56 の提供表の最終照合、L40 の標準δ・正常結果の葉。V_Bytes と旧入力の担当分をこの群で閉じたとは扱わない |
| O124 の .54 の分 | signed4種・unsigned3種の上下端14件について、適格性・幅・数学上の値との一致を確認。群 A の分は閉じた | L40 の規則、R10a/R10b/R40/R50 の処理系・交換、V10 の CLI |
| O129 の .54 の分 | `non_integer_other` の係数上端・scale28と other、`decimal_bounds` の係数下端・下端外・scale29を確認。群 A の ConstOK の境界と写しの分は閉じた | decimalRepresented・比較・丸めの義務全体をこの境界の成功とは同一視しない。L40 の正常結果・丸めの葉、R10b/R40/R50、V10 |
| O169 の共有値近似の WF・空判定 | 本番の二つの WF と可能性の同値が閉じた。[境界](boundary.lean)の `three_empty` は三表現の WF・空判定・全値の非所属を示す | 段内文書の集約は .58 |
| O169 の旧正常域の限定逆方向 | `normalToShared_iff` が閉じた。境界の Integer・Boolean の往復と、型一致を省く逆向きの反例がある | 独立評価と Release の意味の接続は L20/L40 |
| O169 の BaseApprox・実 Report | `baseToShared_mem`・`Report.shared_normal` が閉じた。`report_sum` は実解析の `2 + 3` に 5 が属し 6 が属さないことを示し、`report_width` は u64 上端の実出力を写し、coverage=complete も確認する | returned の推論と failed の意味の健全性は L20/L40 H04。mayFail の複写を失敗の健全性と呼ばない |
| O169 の数値の写し | 七整数に条件を限る定理が閉じた。独立した端点表14件、Byte・Decimal 2件、値域外2件と、端点表から定理を適用する入口を検査 | 同じ契約の全合成は L70、処理系との照合は R10b/R50 |
| normal と returned/failed の区別 | `report_return`・`report_unit_return`・`report_failure` は実解析の normal が空でも、returned/failed が共有近似に属することを示す。Unit の位置の return は coverage=complete も確認する | 具体評価の返却・失敗の所属はこの反例から結論しない |
| O016 の群 A の公理依存 | 四モジュール全宣言と既存定理20件、境界入力の全宣言を実際に監査した。許可外0件 | 段全体の A-L と独立レビューは .59・取りまとめ |
| O084 の形式化の内外 | 本番へ追加した定義と証明だけを 01-12・07-04・用語集へ反映。Rust/Lean の全比較済みとは扱わない | 例外台帳・全比較・最終受け入れは既定の後段 |

`HasTypeVQ`・`HasTypeCQ` の主な定理の前提と結論、旧の区間解析の定理の言明は変更していない。新公理・信頼条件・精密な外部状態・提供範囲・利用者の書ける形の変更はない。

## 場合の数の予定と実際

予定欄は detail の義務と既存のデータ型から数える分類である。すべての tactic が生成する枝の総数ではない。型の内部の再分解を別の機能の場合として加算しない。

| 分類 | 予定 | 実際 |
|---|---:|---:|
| possible の意味上の場合（bottom、整数2、Boolean4、unknown） | 8 | 8、すべて閉じた |
| WF の場合（整数2、その他3） | 5 | 5、すべて閉じた |
| normalToShared の所属を読む型の分類（Integer64・Boolean・その他） | 3 | 3、型一致を保持して閉じた |
| baseToShared_mem の ConcreteValue の構成子 | 12 | 12、Boolean は内部で真偽2通りを確認 |
| constOK_toApprox の Const の構成子 | 16 | 整数7件が成功、その他9件は種類の条件で除外 |
| 境界の空の表現 | 3 | 3、整数の幅 k は任意 |
| 境界の旧正常域の往復と型一致の必要性 | 2正例＋1反例 | 2＋1 |
| 境界の実 Report（加算・u64上端・Boolean/Unitの位置のreturn・あふれ） | 初回4＋処置1 | 5 |
| 境界の七整数の上下端 | 14 | 14 |
| 境界の Byte・Decimal と値域外の整数 | 初回2＋2、処置でByte/Decimalを4件追加 | 6＋2 |

境界は名前付き定理15件で、上表の独立した境界の分類は33件である（初回12定理・28分類から、Unit の return 1分類と Byte/Decimal の4分類を追加）。端点表から `constOK_toApprox` を呼ぶ入口は、同じ14入力の再利用であり、新しい14件とは数えない。正例は所属の結論を仮定せず、具体計算又は具体的な表への所属から前提を構成する。

## 補助の契約で決めたこと

1. 空の表現を正規化せず、`possible` と `Mem` の存在・非所属で扱う。
2. WF は閉区間に格納済みの証拠を読む。全近似の WF を証明して、主定理の独立した仮定にしない。フローの WF の系を追加した。
3. 旧正常域への逆向きは `value.type = type` を明示して保つ。
4. `baseToShared` は七整数の成分・Boolean の二フラグを読む。それ以外は `other && nonIntegerOther` が true のとき unknown、false のとき bottom にする。レビューの中1と取りまとめの判断を受け、非整数・非Boolean の正常値なしを保つ形へ改めた。片方向の所属保存の署名は維持する。
5. Report の変換は実データを入力にする。returned は明示引数、mayFail はそのまま、警告・キー・停止・追跡は元の Report に残す。returned と mayFail の射影の補題を追加した。
6. 定数の非 other の定理は七整数に限る。Byte・Decimal・String の写しを変えない。新しい ID・エラー・数値表現は加えない。
7. 境界の具体的な Report の全展開を避けるため、制御成分の証明を抽象的な Report の非公開補助で閉じ、具体例から実計算した成分の等式を渡す。本番の契約や検査のメモリ上限は変えない。

## 検査の記録

再実行の入口は [verify.py](verify.py) である。リポジトリの根から `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/a/verify.py build boundary axioms` を実行すると、次の三コマンドを順に実行する。初回の build に続き、レビュー処置後の build を一度実行した。下表と JSON は処置後の最終状態を示す。

| 中身・formal を cwd とする実コマンド | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| 既定全 Lean と既定実行ファイルのビルド：`lake build` | 0、774ジョブ | 48.162秒 | [結果](build-result.json)、[生出力](build-output.txt) |
| 実 Report・空・端点・other・制御の境界と公理依存：`lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/a/boundary.lean` | 0 | 1.298秒 | [結果](boundary-result.json)、[生出力](boundary-output.txt)、[全宣言名と依存](boundary-axioms.json) |
| 変更四モジュールと既存定理の公理依存：`lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/a/axioms.lean` | 0 | 0.970秒 | [結果](axioms-result.json)、[生出力](axioms-output.txt)、[全宣言名と依存](axioms-axioms.json) |

道具は Lean **4.34.1**（arm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52`）。既定 build は変更していない lakefile の `moreLeanArgs = ["-M", "12288"]` を使った。単一ファイルにも `-M 12288` を指定した。最大常駐量は未取得（計画上の非採取）である。交換器・manifest・比較入力を使う Rust/Lean の全比較は今回実行していない。依頼の指定に従い work 検査は取りまとめへ渡し、Rust の全 lib 検査を追加していない。

公理依存は、変更四モジュールの全宣言492件（Shared.Approximation 159、Interval.ApproxAdapter 94、Interval.BudgetAnalyze 187、Refinement.ApproxAdapter 52）と、旧三モデル・旧五主定理・HasTypeVQ/CQ の subst/none/値移動/型移動/narrow の10定理・旧区間解析の正常値/警告の2定理の計20件を合わせた **512件**を確認した。境界入力は非公開補助・生成された式の等式も含む **327件**を確認した。二つの監査の件数は重複を含みうるので、和を固有の宣言数とは呼ばない。依存の和集合は **propext・Quot.sound・Classical.choice のみ**であり、sorryAx・独自公理・許可外依存は0件である。

途中の局所検査では、共有層・区間 adapter・Refinement adapter・BudgetAnalyze を個別に確認した。初回の区間 adapter は逆向きの Bool の場合分けと整数の二つの toInt の展開が不足し、BudgetAnalyze は NormalMem の展開が不足したため失敗した。いずれも補助の証明だけを直し、終了0を確認した。境界の初回は名前空間の指定、決定可能性の展開、具体的な Report の型合わせで失敗した。Report 全体の展開による heartbeat・メモリ超過と長い試行の中断（終了130）もあった。成分の等式を計算する形へ直し、最終版は上表の時間で成功した。制限の緩和と native_decide は使っていない。一度、根で formal 相対の局所コマンドを実行してファイル未発見となったが、formal に直して再確認した。

100,000バイトを超える保存出力はなく、大きな生の記録の移送は生じていない。生出力には終了と時間を添え、入力と出力の SHA-256 は JSON に保存した。

## 計画からのずれ、時間、引き渡し

本番の対象範囲・公開署名・停止条件のずれはない。追加した補助は `FlowApprox.wf` と Report の二つの射影、および境界だけの非公開補助である。設計書には工程 ID と未実施の予告を書かず、実装した定義と保証の範囲を写した。仕様の text コードブロック・構文・生成 Skill は変更していない。

着手時の厳密な時刻は採取していない。最初の時計確認は **2026-11-01 20:45:24 JST**、実装前の署名作成は **20:45:57 JST**、最終の三検査は **20:56:53〜20:57:55 JST** である。本結果の初稿までの時計確認後の外側の時間は約16分であり、それ以前の読込み時間は未取得である。能動時間と待ちを分離した値ではなく、後段の実装の単価に使わない。独立レビュー・受け入れの待ちは未計測である。

| 残り | 担当・時期 | 見込み |
|---|---|---|
| 群 A の定義・言明・仮定、設計書の写しの独立レビュー | 取りまとめが本群の受け入れ前に依頼 | 不明 |
| work の既定全 Lean・変更分類と記録の照合、受け入れ | 取りまとめ・設計者 | 不明 |
| .55 以降の起動、.58 の文書集約、.59 の段全体の公理依存 | 次の群・取りまとめ。今回は進めない | 不明 |
| 定数の値の一致を要する場合の補題 | L40 の正常結果・算術の葉の担当。constOK_toApprox の存在だけから値の一致を仮定しない | 既定の葉の範囲で判断 |
| 独立評価と Release の意味の接続、returned/failed の入力条件と所属 | L20/L40 H04、全合成 L70 | 既定計画の範囲。追加分はない |

次の群には、`normalToShared_iff` の型一致、`Report.sharedFlow` の returned の明示性、非整数・非Boolean で `other && nonIntegerOther` に従って正常値なしを保つ定義を渡す。警告の健全性は旧定理を使い、`shared_mayFail` の等式を失敗の意味の健全性へ読み替えない。


## RV-L10.a の所見の処置

2026-11-01、開始の時計確認は21:08:28 JST。上限は今回の開始から2時間である。レビュー原本と補助入力 rv-a-t1.lean・rv-a-t2.lean は変更していない。今回の入力ハッシュへ三ファイルも含める。

| 所見 | 処置 | 証拠・送り先 |
|---|---|---|
| 中1 | 非整数・非Boolean の枝を `bif (b.other && b.nonIntegerOther) then .unknown else .bottom` へ変更。rv-a-t1 の precise_mem を本番の baseToShared_mem へ移植して同じ署名の所属保存を閉じた | Unit の位置で Integer 7 を返す `report_unit_return` は完走、normal の空・全値の非所属、明示した returned の所属を示す |
| 中2 | 義務の表に O011・O124・O129 を追加。群 A で閉じた分と .56/L40 以降の残りを区別 | `integer_endpoints`・`integer_endpoint_entry`・`non_integer_other`・`byte_outside`・`decimal_bounds`。Decimal の係数上端/下端、下端外、scale28/29を境界で確認した |
| 軽1 | constOK_toApprox の言明を維持し、∃ n だけでは元の整数値との一致が得られないことを L40 の入力として記録 | L40 の正常結果・算術の葉で値の一致を使うなら、元の値と n.toInt の等式を結論する補題を同段の担当が加える。ofInt_bounded を使える。14端点の一致を任意の定数の値保存の証明とはしない |
| 軽2 | report_width に coverage=complete を追加 | u64 上端のリテラルが未対応の Top へ退く退行を検出する |
| 軽3 | 01-12 を「Release.Refinement の constOK_toApprox は」へ変更 | 直前の Interval・BudgetAnalysis の宣言との指示対象の混同を解消 |

修正前の adapter の olean を使って、Unit の正常値なしを保つ境界が意図した箇所で失敗することを確認した（終了1、1.336秒、エラーは unit_return_witness の空判定の1件）。[修正前の出力](regression-before-output.txt)と[コマンド・時刻・入力/成果物の識別](regression-before-result.json)を保存した。最初の境界の試行には returned の所属の証明で幅一致の連言を展開し忘れた誤りもあったため、その補助の証明を直してから、修正前の adapter で失敗理由を一つに絞った。修正後は同じ境界で終了0を確認した。

rv-a-t1 には修正前の unknown への写しを前提とした例があるため、原本全体を修正後の検査入力として再実行しない。precise_mem は本番へ移し、具体的な境界と変更モジュール全宣言の監査で修正後の契約を検査する。五つの境界と constOK_toApprox の言明は変更していない。


処置後の最終検査は21:11:14〜21:12:10 JSTで、既定 build は774ジョブ・48.162秒、境界は1.298秒、公理依存は0.970秒、すべて終了0である。境界は327宣言、本番側は初回と同じ512件を監査し、許可外依存は0件、baseToShared_mem の依存は propext のみである。今回の再開の開始から記録更新までの外側の時間は約6分で、能動時間と待ちは未分離である。最終の入力・出力とレビュー依頼のハッシュを更新した。修正前の失敗記録は再現した退行の証拠として残し、修正後の成功の証拠は上の三検査の結果とする。

## 作業末の work

取りまとめが実行した。基準は `a0dc79a7a0014d1b4d4f61f8ac817beffec2f030`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 101.09 秒である。実行の前に Refinement の生成物を消した。

# L29 の実装結果

着手（最初の時刻取得）: **2026-10-26 18:14:38 JST**。終了: **2026-10-26 18:48:12 JST**。所要時間: **33分34秒**。時刻取得より前の指示の読み込みは含めない。

**状態: L29 の全profileの読者・解析／評価の報告・局所検査・manifest・設計書の対応・指定 work を完了した。C5 の独立レビューと受け入れは取りまとめへ引き渡す。Rust／VMとの接続と全比較は未完であり、X01〜X05の担当である。**

B_WORK・HEAD は `12cd0bc513b515872b3e31033bc238174415bdab`、ブランチは `mod012/L29`。着手時の未コミット差分はなかった。AGENTS.md、共通依頼文、plan の前提・契約・L27〜L29・X01〜X05・検査割り当てと変更の優先順位、decisions の D4 の変更・D5・D15 の追記・D17・D20、README の設計者の決定、preflight、study の9.3〜9.4、L26・L27a・L27b・L28・L25T・A21d の結果と現行の定義を確認した。private/ とそこを指すリンクは読まず、担当の委任と git の変更操作を行っていない。

## 変更した範囲

| ファイル | 変更と接続先 |
|---|---|
| [Exchange.lean](../../../../formal/Benitoite/Interval/Exchange.lean) | width・range・domain を読者へ追加した。既存の `BudgetWhole.analyze` と `evalClosed` に、解決済みの二表を渡す。整数幅、構造値、Range の Error、固定域の失敗と標準事象を復号・報告する。解析器・評価関係・予算の定義は変更しない |
| 同上の正常値 | width・range・domain で六種の `widths` と `nonIntegerOther` を必須にした。Integer64 は既存の integer 欄とする。親だけでなく独立入力・別本体も比較する。base・flow の既存の期待を保つ |
| 同上の標準表・対応 | 標準宣言の完全名、解決済みID、明示した規則、引数型を分けて照合する。Range の record は既存の構成子宣言の形で渡し、owner・型引数0・欄順・三つの Integer 型を検査する。IDから構成子名を組み立てない。sourceKeys は `targetOperationAt` による算術・標準callと一致させる。親・独立入力・別本体の候補のキーと演算も照合する |
| 同上のmanifest・Top判定 | 両モードの `profileManifest` に必須五profileと、今回のprofile・入力・元定義・全本体・比較・除外件数を記録する。幅付きの別本体のTop判定は元の型表にある末尾の型を参照し、他の型のBottomを非Topと数えない |
| [test_interval_exchange.py](../../../../formal/tests/test_interval_exchange.py) | 既存の境界に表形式で独立期待値を追加した。最終は87回の実行器起動。全五profile、七種の算術、シフト27宣言、Range の三欄・拒否優先・射影、深い不正入力、除外、型ごとのTop判定を実CLIで検査する。PythonからLeanのビルドを起動しない |
| [01-12](../../../design/01-spec/01-12-core-calculus.md#区間解析の独立交換の読者)・[07-04](../../../design/07-quality/07-04-formal-semantics.md#区間解析の独立交換の読者) | 実装した欄・規則・受理範囲・比較と除外・manifest・信頼範囲を同じ状態へそろえた。既存の見出しは変更していない |

`IntervalDiff/Main.lean` は既存の `analyzeCorpus`／`evalCorpus` の分岐をそのまま使えるため変更していない。既存の入口から全profileを実行し、依存更新後に Main と実行ファイルを作り直した。`formal/lakefile.toml` と既定ターゲット、既存六入口・corpus14・sidecar6 は変更していない。

固定域の読者はシフトの27宣言だけを認める。組み込みの primName と包みの funName の実際の分類を独立入力へ反映した。操作・HTTPの欄・存在しない unsigned／Byte の rightUnsigned は規則として登録できない。域内の unknown の失敗を成功値へ置き換えず、既存の unknownFailure の除外と observed の報告を保った。mayFail は観測だけとし、診断・一致・受け入れには使わない。

## 全profileの件数と除外

[profile-manifest.json](profile-manifest.json) は必須集合と両モードの実件数、[comparison-summary.json](comparison-summary.json) は一致・受け入れ・非Top・深さ停止・除外理由、[fuel-selection.json](fuel-selection.json) は選択過程を保存する。manifestの必須集合を出しただけで、別profileを実施済みとは数えない。局所検査で五profileが全て存在し、それぞれの比較が0件でないことも確認した。

| profile | 元定義／解析の比較本体 | 非Topの本体 | 解析の深さ除外／段の深さ停止 | 評価器の比較／除外 | 使用fuel |
|---|---:|---:|---:|---:|---:|
| base | 8／8 | 6 | 0／0 | 8／0 | 132 |
| flow | 9／10（別本体1を含む） | 8 | 0／0 | 7／3 | 292 |
| width | 41／41 | 41 | 0／0 | 41／0 | 580 |
| range | 7／7 | 2 | 0／0 | 7／0 | 200 |
| domain | 108／108 | 54 | 0／0 | 46／62 | 2192 |

主となる固定コーパスは解析174本体、評価器109本体を比較し、評価65本体を理由付きで除外した。全五profileの両モードで matched・accepted が真である。これらは **Lean の解析／閉じた評価器と独立期待値の比較件数** であり、Rust の解析・実 VM との比較件数は0である。

- flow の除外3件は従来どおり、未対応の pipe と lazy の親（notClosedOrFuel 2件）、環境を作っていない lazy の別本体（embeddedEnvironment 1件）である。
- domain の除外62件は、整数のシフトの域内で評価器が unknown の失敗を選んだ46件（unknownFailure）と、Byte・UnsignedInteger8 のリテラルを含む16件（notClosedOrFuel）である。Byteは算術の七種に含めず、既存の閉じた評価器にはそのリテラルの具体規則がない。解析の未対応の印も保つ。除外を実行比較済みの件数へ足していない。
- domain は27宣言それぞれに量−1・w・0・w−1を置く。量wの行は名前付き引数の逆順、他は通常順とする。シフト量が域外のときだけoutsideDomain候補を比較する。左シフトの捨てるビットをoverflowとする規則は加えていない。
- range は成功・一点・逆転と範囲外が重なる場合のInvalidBounds優先・範囲外・Integer64最小端・同じ成功値の直接射影を含む。Resultの正常なErrorと、traceの包む前の拒否を区別する。射影後の正常区間は `[0,10]`、閉じた評価の値は5である。単独のcheckの未知の正常値を、射影の精度と混同しない。
- width は六種の上下端・加算／減算／定数倍・符号付きの最小値への負号と、Integer64の減算／乗算を追加した。最大u64とその積は、数学上の整数と十進文字列のまま扱う。

既存の長い容器の検査も保ち、初期fuel40で深さ停止、80へ倍にした再実行で停止0・一致を確認した。選択した同じfuelを各本体と発見に渡す。空、全Top、除外だけ、深さ停止が残る入力は受け入れない。幅付きの独立入力の全Topでも、比較の一致と受け入れ失敗を区別する。

## 中心二命題・参照定義・既存主定理・公理の照合

[audit.py](audit.py) がB_WORKのblobと作業ツリーを照合した。既存の対象4,492ファイル中、変更したのは交換のLeanとPython検査の2ファイルであり、残る4,490ファイルはバイト単位で一致する。[検査前](audit-report-before.json)と[検査後](audit-report-after.json)に詳細を保存する。既存の名前付きLean定理3,434件は、言明だけでなく本文と参照する定義のファイル全体が不変である。新しいLeanの定理・公理・sorryはない。

| 言明・参照定義 | B_WORKからの差分と意味の向き |
|---|---|
| NormalSoundness・WarningSoundness の本文・前提・結論 | Eval.lean 全体が一致。中心二命題の変更・弱化なし |
| EvalPartial・EvalBlock・EvalInput・Unmodeled・UnknownAt | 同上。未知を具体規則へ置き換える変更もなし。交換は既存の規則へ表を渡すだけである |
| ConcreteValue・StandardRule・StandardBinding・EvalStandard・standardCallHead | 同上。値・標準規則・認定する頭・操作の扱いを変更していない |
| evalClosed と健全性定理 | EvalClosed.lean 全体が一致。域内の unknown の選択、Byte の未対応、traceの構築を変更していない |
| targetOperationAt・arithmeticOperationAt・WarningLocated | Sound.lean 全体が一致。公開の警告位置の集合を拡大・縮小していない。交換の sourceKeys を既存の targetOperationAt に接続した |
| concreteRule・syntacticReachChildren・CallReach | SyntacticReach.lean・CallReach.lean 全体が一致。構文的な到達可能性、未認定callの除外を変更していない |
| AbstractSlot・AbstractEnv・SlotModels・LocalsModels・Models | Domain.lean・Environment.lean 全体が一致。Modelsを強めず、具体環境と抽象環境の二表の一致という既存条件を保った |
| RangeState.Models と由来 | RangeState.lean 全体が一致。保存関係・同じ成功値の条件を変更していない |
| 解析・予算・全体駆動・識別と公開の入口の主定理 | Analyze・BudgetAnalyze・BudgetSound・BudgetNormal・BudgetWhole・BudgetRange・BudgetDomainScan・BudgetSelect・Identityを含む既存Leanは一致。解析の順序、保持、停止位置を変更していない |
| 旧主定理・Builtins.Assumptions・公理 | 交換以外の既存Leanは全て一致。前提・結論・公理の追加・変更なし |
| Rust・VM・予算固定表・既存六入口・設定 | crates・fuzz・scripts・既存manifest・ツールチェーン指定・lakefile.toml が一致。`-M 12288` を保持 |
| 01-12 の写し・07-04 の対応 | 交換の型・欄・表・値と失敗・Top分類・manifestの写しだけを更新した。中心二命題・評価関係・型／エフェクト・既存主定理の写しを変更していない |

[axioms.lean](axioms.lean) と[照会結果](axioms.log)で中心二命題と14の公開定理等、計16宣言の依存公理を照会した。既存のpropext・Classical.choice・Quot.soundの範囲であり、fixed_at_disjoint_failedはpropext・Quot.soundだけだった。言明の文字列の一致だけで、定義の変更による弱化を見逃していない。

[work-inputs-sha256.json](work-inputs-sha256.json) に、変更したLean・Python・設計書と、変更していないMain・既定の読者例の6ファイルを固定した。指定work後にこれらは変更していない。

## A1の限界とXへの申し送り

| 境界 | この枝で確かめた範囲 | 残る信頼・接続と担当 |
|---|---|---|
| 対象構文の評価関係に対する健全性 | 既存の定義・中心二命題・公開定理を不変とし、既定ビルドと公理を点検した | C5の定義・言明・仮定の独立レビューと受け入れは取りまとめ |
| 型付きSurface・名前解決・標準表 | 版、全型キー、元演算キー、明示した役割と型、二表の対応、Rangeのレコードの形、深い不正入力を検査した | 解決済みID・役割・構成子宣言の実ソースへの由来は入力の信頼範囲である。自己整合した入力だけから名前解決の正しさは証明できない。X01〜X02で実交換と照合する |
| Rangeの実本体 | 対象構文の評価関係の三欄・Error・優先順・射影を独立期待値と照合した | Range.bnt・脱糖・Release・VMとの意味の一致は証明していない。X03bで実交換・実VMと比較する |
| 固定域 | 純粋なシフトのみ。二種類の頭、27宣言の役割、域外候補と評価の拒否、域内unknownの除外を確認した | X03cで実VMの値・失敗・位置を照合する。unknownとByteの評価不能をVM比較件数へ加えない。操作とHTTPの欄を対象へ戻さない |
| 全ての入力の意味 | 独立した固定入力との一致、空・全Top・0件成功の拒否、除外と理由を保存した | 差分テストは全入力の意味保存の証明ではない。旧脱糖の型保存から算術の意味保存も導いていない |
| 全関係定義・全比較 | Leanの各profileのmanifestと件数を保存した | Rust解析・元NodeId/span・重複をまとめた利用者警告・実VM・既存六入口との全比較・check-formal.shへの接続はX01〜X05で閉じる。この枝の例だけでK1完了としない |

## 検査と計測

実行場所は `<repo>`、Leanの入口は `<repo>/formal`。[run.py](run.py) が各コマンド・開始時刻・終了状態・外側時間を同名のJSONとlogへ保存した。シェルはrtk proxyを通した。Cargoには既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。手元の絶対パスは記録から伏せた。

| 検査 | 結果と外側時間 | 記録 |
|---|---|---|
| 読者の最初の単体検査 | 終了1、1.383秒。JSON容器の括弧、Tyの比較、構造体の欄等の誤りを検出 | [reader-first.json](reader-first.json)・[出力](reader-first.log) |
| 読者の修正後の単体検査 | 終了0、1.245秒。後続の厳密化・Top分類の修正後も成功 | reader-third／reader-fourth／reader-hardened／reader-valid／reader-bodytype のJSON・log |
| 最初の依存順の逐次ビルド | 終了0、46.725秒。258モジュールを一つずつ処理 | [全体](sequential-build.json)・[モジュール別](module-build.json)・[出力](module-build.log) |
| 最終の逐次更新 | 読者・既定例・Main・root・実行器、各終了0。3.363・1.036・0.685・0.679・0.592秒 | reader／examples／main／root／link-ready-build のJSON・log |
| 公理の照会 | 終了0、0.634秒、16宣言 | [JSON](axioms.json)・[出力](axioms.log) |
| 局所比較の最終実行 | **終了0、2.934秒、87起動の期待した結果を確認** | [JSON](tests-final.json)・[要約](tests-final.log) |
| 指定workのdry-run | 終了0、0.013秒。基準と三単位を確認 | [JSON](dry-run.json)・[出力](dry-run.log) |
| 指定work本体 | **終了0、3.427秒、三単位全て成功** | [本体の結果](work-check.json)・[出力](work.log) |
| 外側の `/usr/bin/time -l` | **終了1、3.457秒。検査後の資源統計取得を拒否された** | [外側の結果](work.json)・[出力](work.log) |

```sh
scripts/check.sh --level work --base 12cd0bc513b515872b3e31033bc238174415bdab --only formal_build,spec_examples,spec_tally
```

上記の同じ指定へ先に `--dry-run` を付けた。検査本体は [work-check.py](work-check.py) から一度だけ実行し、その外側を `/usr/bin/time -l` で包んだ。仕様集計の自己検査と集計、仕様例7件（失敗0・ignored 0、テスト本体2.95秒）、既定lake buildとsorry拒否を通過した。初回リリース版の完了条件の未記入はnoneだった。

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体が終了0となった後、timeが `sysctl kern.clockrate: Operation not permitted` を報告して終了1になった。real/user/sysは3.45/3.77/0.28秒である。検査の失敗やメモリ超過と取り違えず、最大常駐量を0とも記録していない。統計のためだけに検査を再実行していない。

Leanは常に一プロセスずつ実行した。[build.py](build.py) が依存順に一モジュールずつ native object まで更新し、その後も読者→例→Main→root→実行器の順で更新した。終了状態を確認してから次へ進み、ビルドを背景へ残して編集していない。単体検査は `lake env lean -M 6144` と300秒の上限、例のビルドは25秒、Soundは175秒、ビルド全体の各Leanには既存の `-M 12288` が適用される。時間・メモリ上限、終了143による停止はなかった。解析器・評価器をrfl・decide・simp・norm_numで展開する検査を追加していない。局所の新検査は実行ファイルを実行するPythonの境界にまとめた。

[生の入力・報告ZIP](test-records.zip)・[各ファイルのSHA-256](test-records-index.json)に、初回の失敗・再現・最終成功を含む1,271ファイルを保存した。[summarize.py](summarize.py) がZIP内の全内容とハッシュを元の内容に照合した後、生成した検査出力のディレクトリだけを片付けた。最終の生記録はZIPの `tests-final/` にある。ビルドの生成物を削除していない。

## 途中の失敗とテストの作成時の関門

- 最初の読者の検査はJSONのListとJson.mkObjの括弧、TyのBEq／DecidableEqを仮定した比較、構造体の欄とmetadata名、rangeKindの名前で失敗した。交換用の型JSONによる比較と正しい欄へ直した。深い期待の検証ではExprの名前空間の曖昧さとlambdaのdoの欠落を直した。コンパイルエラーに伴う一時的なsorry依存の警告は、エラーの修正後に消え、ソースへsorryを加えていない。
- 最初の拡張コーパスは、既存のSurface交換が配列で表すargsをExprsの帰納形で準備して失敗した。既存形式の配列へ直した。次にRangeのsourceKeysから標準callを落としていたため拒否され、呼び出しキーを明示した。元のキー・定義の照合を緩めていない。
- 新しい消費の手計算で、最大同時保持の外側のbodyWorkの一枠を落としていた。Range単独checkのピークを14から15、通常／逆順シフトを12／13から13／14へ訂正した。操作数はそれぞれ37、43／45のままである。例の期待の訂正であり、予算の定義・固定表・上限を変更していない。Byteの未対応の印と評価不能も、既存の規則に従う期待にした。
- 幅のある別本体をInteger64欄だけで非Topと数える誤りは、修正前の実行器で再現した。[再現の結果](tests-embedded-regression.json)・[失敗の出力](tests-embedded-regression.log)を残した。元の型表で末尾の型を取得する報告側の修正後、同じ入力でInteger8のTopを非Topと数えなくなり、最終検査が成功した。この回帰検査では消費等に意図した不一致を残し、Top分類とacceptanceReasonsを直接検査するため、別の不一致による終了1だけを根拠にしていない。

作成時の関門で守る契約は、実CLIの入力・出力と終了状態、各幅の区間、Rangeの構造値と拒否の優先順、標準宣言・二表・演算対応、親と独立入力の候補、必須profileと実件数、unknownの除外、型ごとのTop分類である。幅を潰す・u64を丸める・三欄や構成子を失う・操作に固定域を付ける・逆順の引数をソース順のまま契約位置と混同する・深い不正欄を読み捨てる・除外を比較件数へ足す退行で失敗する。従来のbase／flowと読者の例だけではこの境界の失敗に届かないため、同じPython実行器の表を拡張した。準備は共通関数と表へまとめ、解析器の出力から期待値を生成・更新する処理や、本番のテスト専用の差し込み口を足していない。既存のテスト・上限・ignore・期待値を緩めず、低価値テストの削除もしていない。基準との差分は本番の交換のLeanが346行追加・101行削除、Python検査が266行追加・6行削除である。

## 計画との差と引き渡し

担当範囲の拡大、D15の停止条件への該当、見込み上端の2倍による中断はない。中心二命題・旧主定理・Models・公理を変えなければ進めない点は見つからなかった。交換の報告に必要なTop分類の誤りを同じ枝で直した。Main・既定例・lakefileは既存の接続を再利用し、不要な変更を加えていない。別状態の検査結果を引用して省いた検査はない。

| 残る手順 | 担当と引き渡す内容 | 見込み |
|---|---|---|
| C5の独立レビュー・受け入れ、コミット・取り込み | 取りまとめ。全profileの読者と境界、定義・言明・仮定、manifestと除外、A1の信頼範囲を本記録と照合する | 不明 |
| 実交換・全関係定義・Rust解析・警告・VMの比較と検査 | X01〜X03。型と二表を実交換から渡し、標準callをsourceKeysへ含める。Rangeのrecordと八つの同定、シフトの27宣言、候補と利用者警告、除外理由を保つ | 計画による。今回の測定からは不明 |
| 全比較への接続・K1・独立レビュー・受け入れ | X04〜X05／取りまとめ。既存六入口と新独立入口を同じ関係状態で閉じる。Leanの局所例を実VMの証拠にしない | 計画による。今回の測定からは不明 |

Rust・VM・予算の固定表・stage・short・change・release・check-formal.sh全体は、この枝では変更・実施していない。コミット・取り込み・docs/todoの更新・保管・公開は取りまとめの担当である。

## 取りまとめのレビュー（2026-10-26）

受け入れて区切り C5 の独立レビュー（RV-C5）へ渡す。区間解析の定義・定理と中心二命題は変わらず、sorry・公理・`decide +kernel` の追加はない。domain の評価の除外62件のうち16件の「Byte 系のリテラルを含む評価不能」は、閉じた評価器の対応の範囲の問題かを RV-C5 の観点に加える。

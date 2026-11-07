# 担当 scope-rules の記録（必須の判定の受理の規則の移植）

- 開始 2026-11-07 07:17 JST、終了 2026-11-07 07:35 JST（外側の時間 約18分）。
- 作業木 `Benitoite-l70g`（ブランチ `m014/l70.g`、基準 `eb4f0ef9`）。git の書き込み操作はしていない。

## 変えたファイル

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/Refinement/Surface/ScopeRules.lean`（新規、322行） | 規則の表と健全性を `Refinement.Val` で書き直した |
| `formal/Benitoite/Release/Refinement/Surface/ScopeSound.lean`（新規、268行） | 実例の表の δ による六つの項目と健全性 |
| `formal/Benitoite/Exchange/Observe.lean` | `acceptInput` を新しい `CheckAccept.AcceptInput` へ。健全性を新しい型で述べ直し、表の健全性の系を足した。旧 `import Benitoite.Surface.CheckAccept` を除いた。冒頭の説明の工程 ID と、表を信頼するという記述を直した |
| `formal/Benitoite/Exchange/ObserveExamples.lean` | 受理の入力の `#guard` 7件と適用例2件を足した。見出しの工程 ID を除いた |
| `formal/Benitoite.lean` | 新しい2モジュールの import を2行足しただけ |

## 足した宣言の主な名前

- `Release.Refinement.Surface.ScopeState`（`ScopeRules.lean`）: `okPayload`・`CheckedModels`・`checkedModels_iff`・`ResultModels`・`factModel`・`LitModels`・`litModels_of_none`・`models`・`models_lit`・`argIndex`・`CheckSpec`・`CheckSpec.BoundSound`・`CheckSpec.Contract`・`checkRule`・`checkRule_sound`・`pathCheck`・`pathCheck_boundSound`・`requestCheck`・`requestLitBound`・`requestLitBound_boundSound`・`projectRule`・`projectRule_sound`・六つの宣言の名前・`Rules`・`Rules.lookup`・`Rules.Sound`・`Rules.lookup_sound`。
- `Release.Refinement.Surface.ScopeSound`（`ScopeSound.lean`）: `deltaRun`・`deltaRun_eq_some`・`okPayload_error`・`okPayload_ok`・`pathPattern`・`pathTarget`・`reqEndpoint`・`agreed`・`agreed_sound`・`pathRun_ok`・`modelTargets_contract`・`requestRun_ok`・`modelHttp_contract`・`productionRules`・`productionRules_sound`（private は `makePath_ok`・`makeEndpoint_ok` の2件。どちらも読者あり）。
- `Exchange`: `ScopeAcceptanceEntry.acceptInput`（型を変更）・`acceptInput_sound`（述べ直し）・`acceptInput_tableSound`（新規）・`acceptInput_none_noRules`（述べ直し）。
- 健全性の言明: `productionRules_sound pattern host (hne : ok ≠ "Result.Error") facts : (productionRules pattern host).Sound (models ok facts)`。表の条件はない。

移していないもの（受け持ちの範囲外）: 旧 `ScopeState` の一段の評価の健全性（`absArgs_models`・`absStep_sound` など）、予算の状態の健全性（`Run.*_models`・`Run.Good` など）、`Boundary`・`checkDelta`、旧 `ScopeSound` の接続定理（`scope_check_connection` など）と旧 Scope の小モデルとの対応。新しい受理（`CheckAccept`）はこれらを読まない。

## 局所検査

| コマンド（`formal/` から） | 終了 | 所要（外側） |
|---|---|---|
| 二つの新しいモジュールを一つの確認用ファイルに合わせて `lake env lean -M 12288`（共有ロック下、`.olean` を書かない） | 0・警告0 | 約15秒 |
| 既定ビルド `lake build`（共有ロック下、3回目 07:33:14〜07:33:32） | 1。失敗は `SurfaceCheck.Main`・`SurfaceCheck.Validation`（他の担当）だけ。`ScopeRules`・`ScopeSound`・`Exchange.Observe`・`Exchange.ObserveExamples` は ✔（警告0）。`Exchange.CheckInput` も ✔ | 約18秒 |
| `#print axioms`（確認用ファイル、既定ビルドに置かない）: `productionRules_sound`・`modelTargets_contract`・`modelHttp_contract`・`acceptInput_sound`・`acceptInput_tableSound`・`Rules.lookup_sound` | 0。`propext`・`Classical.choice`・`Quot.sound` だけ | 1秒 |

1回目・2回目の既定ビルドは、`Observe` の `by decide`（自由変数を含む期待型）と `ObserveExamples` の `Block` の名前の解決で失敗し、直した。

## 止めずに進めた変更

| 理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 旧の検査の δ は交換の解析の表を引数に取ったので、型検査器の既知の範囲と δ の動的なパターンが同じ表で一致した。新しい実例の表の δ（`ScopeResponse.delta`）は形式化した解析（`ScopeDelta.parsePattern`・`RequestDelta.parseHostPattern`）を固定で使うので、交換の表をそのまま既知の範囲に使うと、表と解析が食い違う項目で契約（`BoundSound`）が成り立たない | 交換の表の項目のうち形式化した解析と同じ結果の項目だけを既知の範囲に使い（`agreed`）、食い違う項目は未知（Top）にする（保守的な側）。健全性は表の条件なしに成り立つ | 表と解析の一致を健全性の前提に置く案（新しい独立の信頼条件になる）。表を使わず形式化した解析だけで既知の範囲を作る案（表にない綴りまで既知にし、旧と処理系より多く受理しうる） | 表と解析が一致する入力では、受理は旧と同じ範囲の判定を返す（例: `agreeingEntry`）。必須の判定の入力を持たない入力は規則のない受理の入力のまま |
| 新しい実例の表の δ の Result の構成子の名前は `Result.Ok`・`Result.Error` であり、交換の Ok の名前 `"Ok"` と違う | 健全性を Ok の名前 `ok ≠ "Result.Error"` の全てについて示した。交換の入口は依頼どおり `ok := "Ok"` | Ok の名前を `"Result.Ok"` に固定する案（交換の表層の照合の腕の名前と合わず、受理が変わる）。交換の名前を標準の名前へ写す案（取りまとめの判断で採らない） | 受理の結果は `ok` だけで決まり、旧と同じ `"Ok"` を使う |
| 旧の射影・拡大の規則の実行は、拡大は被覆の確かめ（`widenRun`）、パスの射影は値なし（旧の実例の表に δ がなかった）であった | 四つの射影・拡大の項目の実行を、同じ名前の新しい実例の表の δ にした。射影と拡大は添字と転送が同じなので、一つの形 `projectRule run` で書いた | 旧の `widenRun` を写す案 | 規則の添字と転送は旧と同じであり、受理は実行を読まないので、受理の結果は変わらない |

公開の関数の契約の変更: `pathCheck` は旧の `Parsers` の代わりに、実行時の解析（`pattern`・`target`）と型検査器の読む表（`known`）を別の引数に取る。`pathCheck_boundSound`・`requestLitBound_boundSound` は「型検査器の読む表の項目は実行時の解析の結果に含まれる」を前提に取る（同じ関数を渡せば前提は自明で、旧の形に戻る）。`models` は旧の `Parsers` の代わりにパターンの解析だけを取る（旧も対象の解析を読まなかった）。

## 残りと申し送り

- `Exchange/CheckInput.lean`（他の担当）の `Prepared.accept` は新しい `CheckAccept.AcceptInput` の型であり、`ScopeAcceptanceEntry.acceptInput` の新しい型で既定ビルドを通っている。
- F-REG への申し送り: 処理系がリテラルのパターンを読んだ表（`scopeAcceptance` の `patterns`・`hosts`）と、形式化した解析（`ScopeDelta.parsePattern`・`RequestDelta.parseHostPattern`）が食い違う入力では、新しい入口はその項目を未知（Top）として読み、Top でない契約を断る（旧は受理した）。既存コーパスでの食い違いの有無は調べていない（手元の交換の要求の写しは `scopeAcceptance` が空であった）。
- 判断を求める点: Ok の名前の食い違い（上の表の2行目）により、交換の入口（`ok := "Ok"`）での検査の規則の健全性は、新しい δ の出力に対しては成功値の対応を何も主張しない（`Result.Ok` の値は `okPayload "Ok"` で読めない）。成功値の対応が意味を持つのは `ok = "Result.Ok"` の場合である。交換の構成子の名前と実例の表の名前の対応をどこで結ぶかは、7入口の切替と接続定理の移植（旧 `ScopeSound` の接続定理は未移植）のときに決める必要がある。

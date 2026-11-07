# L70 群 H4: 表層の具体例3行の述べ直し

担当: Claude（Opus 5.5）。作業木 `Benitoite-l70h`（ブランチ `m014/l70.h`）。基準は前の担当（群 H3 の Lean の担当）の未コミットの変更を載せた作業木（HEAD `7069a03ff`）で、その変更は変えず、下の2モジュールと記録を足した。段の開始版 B_STAGE は `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` で、旧の言明は `git show <B_STAGE>:formal/Benitoite/Surface/CoverExamples.lean`・`Monad2Examples.lean` の全文を読んだ。git の書き込み操作・サブエージェントの起動・`scripts/check.sh`・`scripts/check-formal.sh` の実行はしていない。

## 結論

群 H3 が述べ直していない表層の具体例3行（`main_never_passwd`・`program_target_sound`・`desugared_typed`）を、篩付きの表層の型付けの導出を直接与えて述べ直した。新しい公理・`sorry`・既存の言明と規則の変更・heartbeat の設定はない。旧の保証が篩付きの規則の下で成り立たない例はなかった。足した2モジュールは既定 import に入れた。

## 時刻

外側の時間（`date` の読み）である。能動時間と待ち時間は分けていない。

| 単位 | 開始 | 終了 |
|---|---|---|
| 読む（依頼文・共通依頼文・群 H3 の依頼文と報告・results-lean.md・legacy-recheck.md・旧の例の全文・群 H2・H3 の表層の例） | 2026-11-07 22:45 | 22:50 |
| `SurfaceTargetCoverExamples`（呼出しの頭と型付け・照合の腕・網羅性・整形式と型付け・δ・到達・対象健全性の適用、g と h） | 22:50 | 23:00 |
| 検査器の評価の試行（下の「desugared_typed の型付けの与え方」） | 23:00 | 23:05 |
| `Surface.Monad2Examples`（依存列の具体化・式と照合の補題・四つのメソッドの本体・汎用の関数・実装・整形式と型付け・性質1） | 23:05 | 23:32 |
| 既定ビルド・公理監査 | 23:33 | 23:35 |
| 01-12・07-04・`formal/README.md`・stage-results.md・本書 | 23:35 | 23:45 |

## 述べ直した例（接頭辞 `Benitoite.Release.Refinement.` を省く）

| 旧の名前 | 述べ直した例 | 旧との違い |
|---|---|---|
| `main_never_passwd`（旧 `Surface/CoverExamples.lean`） | `Surface.TargetWriteExamples.main_never_passwd`（`passwd_not_allowed`）。読取りの版 `Surface.TargetCoverExamples.main_never_passwd` も置いた | 下の「旧との違い」の4・5（書き込みの版） |
| `program_target_sound`（同） | `Surface.TargetWriteExamples.program_target_sound`。前提の非空疎は `main_reach`・`main_reach_allowed`。型付けは `wellFormed`・`wellTyped`・`hasMain`・`ready`・`hasFile`、被覆だけで型付くことは `mainEff_covers`・`narrow_not_sub`、Result の二つの腕の網羅性は `arms_exhaustive`・`result_ctor` | 同上 |
| `desugared_typed`（旧 `Surface/Monad2Examples.lean`） | `Surface.Monad2Examples.desugared_typed`（`program_wellFormed`・`program_wellTyped`・`value_assumptions`） | 下の「旧との違い」の6〜9 |

旧の `main_reach`・`main_reach_allowed`・`passwd_not_allowed` に当たる例も同じ名前で置いた。

### `SurfaceTargetCoverExamples` の中身

- プログラム: 標準の型の宣言を収集した表層のプログラム（`MainExamples.source positiveExternals` の型の宣言）に、main・g・h を置く。
  - `main() -> Unit with {File.Read["/data/**"]}` の本体は `match Scope.checkPathIn["/data/a.txt"](pattern: "/data/**", path: "/data/a.txt") { Result.Ok(p) => { File.readTextIn["/data/a.txt"](path: p); } _ => { } }`。
  - `g(path: PathIn["/data/a.txt"]) -> Unit with {File.Read["/data/a.txt"]}` は同じ読取りを本体に持つ（狭い効果）。
  - `h(path: PathIn["/data/a.txt"]) -> Unit with {File.Read["/data/**"]}` は `g(path: path)` を呼ぶ（狭い効果の関数を広い効果から呼ぶ）。
- 表は範囲付きのパス操作を持つ実例の表 `ExternalModels.targets`、環境は `TargetReachExamples.environment`。
- 照合の規則 `E_Match`・`HasArmsQ.plain` の前提を直接与えた。照合する値の観測 `scrutObs` は番号0の変数（`armCtx_obs`）、経路の事実は `constructorIs (var 0) "Result.Ok"` とその否定で、`FactsWF` を宣言・sort・変数の範囲から示した。欄の事実はリンクなし、網羅性は `_` の腕から示した（`arms_exhaustive`）。
- 範囲付きの組み込みの呼び出しは `CallHeadTy.prim` に `RangeAdmissible`・`PrimitiveAdmissible`・`SignatureInstance` を与えた（`check_typed`・`read_typed`）。読取りの効果は `{File.Read["/data/a.txt"]}` で、main と h の宣言の効果 `{File.Read["/data/**"]}` へ一原子の被覆で広げる。
- 到達: main の呼出し・検査の二つの実引数の束縛・検査の δ・照合の `Result.Ok` の腕の選択・読取りの実引数の束縛の13遷移の後、観測 `/data/a.txt` の読取りの事象（失敗の応答）を伴う遷移へ進む（`main_reach`）。各遷移の規則を直接適用し、`step` の評価は使わない。δ の値は `check_delta` で、二つの文字列の解析だけを `decide +kernel` で計算した。

### `Surface.Monad2Examples` の中身

- 三つの型クラス `Functor2`（map）・`Applicative2`（上位 `Functor2`。pure・apply）・`Monad2`（上位 `Applicative2`。flatMap）。引数の種類は `.constructor 2`、F はメソッドの型パラメータの直後に束縛される。
- 二つの data 型 `Result`・`UserResult`（各 `Ok`・`Error`）と、各型への三つの実装（上位の辞書は `.impl` で同じ型の一つ下のクラスの実装）。メソッドの本体は旧と同じ map・pure・apply（入れ子の照合）・flatMap で、照合する値の二つの構成子で分岐する。
- `genericMap[A, B, X, F[_, _]: Monad2]` は辞書を値引数より前に受け取り、`super(super(d, Applicative2), Functor2)` の map を直接呼ぶ（`functor_dict`・`generic_body`）。
- 補題: 依存列の具体化（`map_tel`・`pure_tel`・`apply_tel`・`flatMap_tel`・`generic_instantiated`）、構成子の呼出し（`ok_typed`・`err_typed`）、関数の値の呼出し（`call_typed`）、二つの構成子の照合（`cases_typed`。腕の本体の型付けは事実の列によらない形で受ける）。
- 組み込みの表は空で、型パラメータの制約の判定は空の制約だけを満たす（`sat := fun _ _ p => p = {}`）。値の信頼条件は判定が型によらないことから示した（`value_assumptions`）。

## 旧との違い

1. 旧の範囲付きの IO は書き込み `File.writeTextIn`、述べ直しは読取り `File.readTextIn` である。結論の形（到達したどの IO の事象の観測にも `/etc/passwd` が現れない、到達した事象の観測を上限が許す）は同じで、IO の事象の種類で量化を狭めていない。
2. 旧の照合の第二の腕は `Err(e) => ()`、述べ直しは `_ => { }` である。網羅性は `_` の腕から示した。標準の宣言の表で `Result` の構成子が二つだけであることの網羅性は、標準の表の構成子の全件の反転か大きな表の上の被覆の判定の評価が要るので使っていない。照合の規則の前提（観測・経路の事実・`FactsWF`）は、`Result.Ok` の腕で旧と同じく与えた。
3. 旧の main は被覆だけで型付く f を呼び、述べ直しは main 自身が被覆だけで型付く（群 H3 の引継ぎのとおり）。旧の g・h の役割は同じ形で置いた。
4. 旧の到達は遷移を計算する関数 `step` をカーネルで18回評価して示した。述べ直しは遷移の規則を直接適用する（大きな具体値を作る評価を避けるため）。
5. 旧の表は L20.7 の実例の表で、述べ直しは篩付きの実例の表 `ExternalModels.targets` と環境の束縛 `σ.Ready` を前提に持つ（篩付きの表層の対象健全性の前提の形）。
6. 旧の型付けは検査器の評価（`checkProgram … = .ok ()` を `rfl`、`maxHeartbeats 4000000`・`maxRecDepth 8192`）から得た。述べ直しは導出を直接与え、検査器がこのプログラムを受理することは結論しない（旧の `program_checked` は本書の3行に含まれない）。
7. 篩付きの表層の照合は照合する値を腕の文脈に束縛するので、腕の本体の局所の番号が一つずれる（旧の `.local 1` が `.local 2`）。プログラムの意味は同じである。
8. 旧のコールバックの型は `.fn`、述べ直しは依存列 `(value: A) -> B with ρ` で書き、宣言の具体化の正規化で `.fn` に畳む（`foldFn_value`）。
9. 旧の組み込みの表は検査器の材料から作った表、述べ直しは空の表である。

## desugared_typed の型付けの与え方

検査器の評価を先に試した（作業領域の一時ファイル。既定ビルドには置いていない）。同じ形の材料で `#eval` は受理を返すが、`with_unfolding_all rfl` は定義の展開が止まり、既定の heartbeat の内で失敗した（timeout ではない）。止まる箇所は後の切り分けで値の頭の呼出しの実引数の推論と分かった（下の「取りまとめの判断への対応」の3）。失敗は約1秒で返り、heartbeat の上限に達したのではない。heartbeat を上げた試しはしていない。heartbeat の設定が要ると確かめていないので設定は置かず、表層の型付けの導出を直接与えた（依頼文の指定のとおり）。

## 小さな評価

- `decide +kernel`: `ScopeDelta.parsePattern "/data/**"` と `parseAtInput` の `/data/a.txt` の二つの文字列の解析だけ（`check_delta` の中）。
- `with_unfolding_all rfl`: 二つのパターン `Ok(_)`・`Error(_)` の被覆の判定 `exhaustiveWithView`（`cases_exhaustive`）。構成子の一覧は名前ごとの2件である。
- `decide`: 範囲の被覆・所属、パスの語の整形式、名前の一意性など。

## 既定ビルドと公理監査

| 検査 | コマンド | 開始 | 終了状態 | 外側の時間 |
|---|---|---|---|---|
| 既定ビルド | 共有ロックの下で `/usr/bin/time -l lake build`（`formal`） | 23:33:37 | 0（2347 ジョブ。足した2モジュールの警告・`sorry` なし） | 6秒（最大常駐量 2,195,259,392 バイト、補助値） |
| 公理監査 | `python3 audit-lean.py prepare|run|analyze`（共有ロックの下で `lake env lean -M 12288` を一度） | 23:34:43 | 0 | 14.7秒 |

公理監査（[audit-lean.json](audit-lean.json)、実行の記録 [audit-run-lean.json](audit-run-lean.json)、入力 [changes-lean.json](changes-lean.json)、台本 [audit-lean.py](audit-lean.py)）: 2モジュールの全宣言436（private 224、マクロのスコープを持つ名前0、未解決0）。公理依存は許可した三公理の部分集合だけで、`sorryAx`・`axiom` の宣言は0。必須の名前59名の型の SHA-256 と公理依存は同書の `required` にある。監査の担当が必須の名前に入れる一覧は [required.json](required.json) に置いた。

局所の検査は `lake env lean -M 12288 <ファイル>` を共有ロックの下で同時に一つだけ実行した。

## 文書

- 01-12「確かめる性質」に `Surface.TargetCoverExamples` の段落、「Resultの法則と二引数辞書の具体例」に `Surface.Monad2Examples` の段落を足した。
- 07-04「証明する性質」の表層の対象健全性の例の段落と、性質1の段落の後に同じ例を足した。
- `formal/README.md` の公理依存の確認の一覧に、`main_reach`・`program_target_sound`・`main_never_passwd`・`desugared_typed` を足した。
- stage-results.md「旧の性質の照合」に群 H4 の行と件数（述べ直していない行は2）を反映した。

## 申し送り

- 旧の `program_checked`（検査器がこのプログラムを受理する）に当たる例は置いていない。止まる箇所は下の「取りまとめの判断への対応」の3（構成子のパターンではなく、値の頭の呼出しの実引数の推論 `inferArg` の整礎再帰）。
- 標準の宣言の表の上の `Result` の二つの構成子による網羅性は、書き込みの版で示した（下の「取りまとめの判断への対応」の2）。

## 取りまとめの判断（2026-11-07）への対応

1. **IO の種類**: 旧と同じ形の `Surface.TargetWriteExamples`（`SurfaceTargetWriteExamples`）を足した。f（`{File.Write["/data/**"]}`、本体は `File.writeTextIn["/data/a.txt"](path: path, text: "x")` で被覆でだけ型付く）・g（狭い効果）・h（g を呼ぶ）・main（検査の結果を照合して f を呼ぶ）を置く。開始状態から main の呼出し・検査の δ・`Result.Ok` の腕の選択・f の呼出しを経て、観測 `/data/a.txt` の書き込みの事象へ到達する（18遷移の後の書き込みの事象。`main_reach`）。読取りの版 `Surface.TargetCoverExamples` は残した。上の「旧との違い」の1・3はこの版で解消した。
2. **照合の第二の腕 `Result.Error(e)`**: 書き込みの版で旧と同じ `Result.Error(e) => ()` にした（上の「旧との違い」の2を解消）。標準の宣言の表で Result に属する構成子が二つだけであることを、表の全体の評価・反転なしに示した（`result_ctor`）。既存の `StandardModel.table`（`StandardKeyTyping.Table`）の欄 `dataNames`（宣言の名前の重複のなさ）と `StandardModel.cons_mem` を使い、lookup の行が属する宣言を名前から Result の宣言に決める（`nodup_map_inj`・`result_mem`）。Result の宣言が一覧に入ること（`result_mem`）は、一覧の連結の該当の部分と Result の名前の一つの比較（`decide`）だけで示した。網羅性は、Result に二つ・ほかに全構成子の名前を置く一覧（`ctors_complete`）で、二つのパターンの被覆の判定 `exhaustiveWithView` を `with_unfolding_all rfl` で計算した（`arms_exhaustive`）。
3. **`program_checked`（検査器の受理）**: 置けなかった。止まる箇所は次のとおりである（作業領域の一時ファイルでの切り分け。既定ビルドには置いていない）。
   - `#eval` では全体の検査が受理を返す。`with_unfolding_all rfl` は、メソッドの本体の検査（`CheckDeclarations.checkDef` の `bodyResult`）のうち推論 `CheckInfer.inferBlockExpected` で止まる。照合の部品（`CheckPatterns.altsTy`・`linksValid`・`factsWF`・`scrutObservation`・`CheckInfer.inferFieldLinks`）、事実の列を持つブロック、構成子の呼出し、局所の値、関数の型の正規化 `Ty.normWith` はそれぞれ通る。
   - 止まるのは値の頭の呼出し `f(v)` の推論で、実引数を依存列に沿って渡す `CheckInfer.inferValsTel` の中の `CheckInfer.inferArg`（`Surface/CheckInferCertificates.lean`）である。`inferArg` と `inferElems` は `termination_by (sizeOf v, sizeOf expected)`・`decreasing_by … omega` の整礎再帰で定義され、定義の展開では整礎再帰の展開が進まない。`inferArg` 単独は、`simp only [CheckInfer.inferArg]` で等式の補題を使って一段展開すると `with_unfolding_all rfl` が通る。
   - 等式の補題による段ごとの展開は、群 G の `Surface.CheckedMainExamples.call_inferred` と同じ手法（呼出しごとに `inferExprFuel` を `simp only` で開き、非公開の `valTelInfo` を名前で展開して値の具体化の補題を当てる）である。`inferValsTel` に `simp only [Ty.toTel, Tel.shiftV, CheckInfer.inferValsTel, CheckInfer.inferArg]` を当てた後の `with_unfolding_all rfl` もまだ止まる。このプログラムは六つの実装の四つのメソッドの本体（照合の入れ子と値の頭の呼出し）と汎用の関数を持ち、検査器の全体（推論・有限の案内への変換・再検査・実装の検査・プログラムの検査）をこの手法で段ごとに開く証明は上限の内に置けなかった。所要は見積もっていない。
   - `native_decide` は使っていない。`decide +kernel` は依頼文が小さな等式に限るので試していない。
4. **必須の名前**: 書き込みの版の30名を足し、[required.json](required.json) を89名に更新した。

### この作業の検査

| 検査 | 開始 | 終了状態 | 外側の時間 |
|---|---|---|---|
| 既定ビルド（共有ロックの下で `/usr/bin/time -l lake build`） | 23:56:33 | 0（2348 ジョブ。足した3モジュールの警告・`sorry` なし） | 4秒（最大常駐量 2,196,488,192 バイト、補助値） |
| 公理監査（`audit-lean.py prepare|run|analyze`） | 23:56:52 | 0 | 14.6秒 |

公理監査: 3モジュール（`SurfaceTargetCoverExamples`・`SurfaceTargetWriteExamples`・`Surface.Monad2Examples`）の全宣言629（private 326、マクロのスコープを持つ名前0、未解決0）。許可した三公理の外・`sorryAx`・`axiom` の宣言は0。必須の名前89名。上の「既定ビルドと公理監査」の表は最初の作業の値であり、[audit-lean.json](audit-lean.json)・[audit-run-lean.json](audit-run-lean.json) はこの作業の値に置き換わった。

### 時刻（外側の時間）

| 単位 | 開始 | 終了 |
|---|---|---|
| Result の構成子の補題と網羅性 | 23:39 | 23:42 |
| 書き込みの版 | 23:42 | 23:48 |
| 検査器の止まる箇所の切り分け | 23:48 | 23:55 |
| 既定ビルド・公理監査・文書 | 23:56 | 00:02 |

Lean の変更の終わり

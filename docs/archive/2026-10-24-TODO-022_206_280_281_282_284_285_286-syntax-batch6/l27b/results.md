# L27b の実装結果

着手: **2026-10-26 17:15:03 JST**（着手時の時刻取得）。終了: **2026-10-26 17:25:02 JST**。所要時間: **9分59秒**。

**状態: L27b の実行器の接続、読者の正負例の確認、指定 work、差分点検を完了した。独立レビュー・受け入れは取りまとめへ引き渡す。**

B_WORK と HEAD はともに `9f857805dab73e6253a3574d237b5c9b83711a87`、ブランチは `mod012/L27b`。着手時の差分はなかった。共通依頼文、L27〜L29・X01〜X05、契約表、D4 の変更・D5・D15・D17・D20、README の設計者の決定、preflight、study の9.4、L26・L27a・L25T・A21d の結果と現行の読者・実行器を確認した。

## 実装した範囲

| ファイル | 変更 |
|---|---|
| [IntervalDiff/Main.lean](../../../../formal/IntervalDiff/Main.lean) | `intervalDiff INPUT` の入口を追加した。ファイルの生の文字列を `Benitoite.Interval.Exchange.readCorpus` へ渡し、受理した入力の件数を `accepted inputs=N (reader only)` と表示して終了0とする。引数の誤り、読み込み失敗、不正な交換入力は標準エラー出力に理由を表示して終了2とする |
| [lakefile.toml](../../../../formal/lakefile.toml) | `intervalDiff` と root `IntervalDiff.Main` を登録し、既定ターゲットの末尾へ追加した。既存の六つの実行器・ライブラリの登録・`moreLeanArgs = ["-M", "12288"]` は保持した |

生入力に `Json.parse` を先に適用していないため、重複欄を消す前の読者の検査を実行器からも通る。受理済み profile は L27a と同じ base だけである。端点・回数・保持数・番号の変換を実行器に追加していない。空入力の受理を含め、終了0は読者による受理だけを表す。期待結果との一致や、全ての結果が Top であるだけの比較の受け入れを表さない。

解析・具体評価の比較報告、`analyze|eval INPUT REPORT`、Python 経由の解析比較は L28 の範囲であり、本枝には含めていない。数学的な定義・言明・読者の受理規則を変更していないため、01-12・07-04 の写しの変更もない。実行器と全比較の文書への接続は計画の X04b に従う。

## 検査と計測

実行場所は `<repo>`、Lean のコマンドは `<repo>/formal`。固定版は Lean 4.34.1・Rust 1.98.1。作業末の Cargo には既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。シェル操作は rtk proxy を通した。記録は [run.py](run.py) がパスを伏せて保存し、各コマンドの開始時刻・終了状態・外側の時間は対応する JSON に記録した。

| 検査・コマンド | 終了・時間 | 結果・記録 |
|---|---|---|
| `lake env lean -M 6144 IntervalDiff/Main.lean` | 0、0.626秒 | [記録](main-first.json)。300秒上限、新しい入口の単体検査 |
| `lake env lean -M 6144 Benitoite/Interval/ExchangeExamples.lean` | 0、0.872秒 | [記録](reader-examples.json)。25秒上限。既定 import に含まれる既存の33組の `#guard` を変更せず確認 |
| 依存順の `lake build MODULE:o` | 全体0、54.909秒 | [実行器](build.py)・[全体の記録](sequential-build.json)・[全体の出力](sequential-build.log)。依存121モジュールを一つずつ native object までビルドした |
| `lake build intervalDiff` | 0、1.113秒 | [記録](executable-build.json)・[出力](executable-build.log)。実行器のリンクまで成功 |
| `lake --no-build build` | 0、0.150秒 | [記録](ready.json)・[出力](ready.log)。既定ターゲット全体が更新済み（409 jobs）であることを確認 |
| 指定と同じ dry-run | 0、0.009秒 | [記録](dry-run.json)・[出力](dry-run.log)。仕様集計・仕様例・既定 Lean ビルドの三単位だけを選択 |
| 指定 work の検査本体 | **0、3.306秒** | [記録](work-check.json)・[出力](work.log)。三単位すべて成功、各単位は work から一度実行 |
| 外側の `/usr/bin/time -l` | **0、3.333秒** | [記録](work.json)。資源統計も取得成功。real/user/sys は3.32/3.74/0.28秒 |

作業末検査の最大常駐量（maximum resident set size）は **78,036,992バイト（74.421875 MiB）** である。これは依存をビルド済みの状態で実行した作業末検査の値であり、先行した native object の生成全体のピークを表さない。

指定のコマンドは次のとおりである。先に同じ指定へ `--dry-run` を付けた。[work-check.py](work-check.py) が検査本体の終了状態を保存し、その外側を `/usr/bin/time -l` で包んだ。

```sh
scripts/check.sh --level work --base 9f857805dab73e6253a3574d237b5c9b83711a87 --only formal_build,spec_examples,spec_tally
```

仕様集計の自己検査と集計は成功し、初回リリース版の完了条件の未記入は none だった。仕様例は **7件成功・失敗0件・ignored 0件**（テスト本体2.91秒）。formal_build は既定の lake build と sorry 拒否を通過した。既存の Lean の lint 警告の再表示と、リンク時の `/usr/local/lib` の不在の警告はあるが、新しい入口の Lean 警告・ビルド失敗はない。

Lean の起動は逐次とし、依存順の各モジュールの終了状態を確認してから次を起動した。未ビルドの複数モジュールを Lake へ一括で渡していない。ビルドの `-M 12288` を保ち、試しの単体検査は `-M 6144` と時間上限を付けた。既存の例を変更せず、解析器・評価器の計算を新しい証明へ展開していない。時間上限・メモリ上限・終了143による停止はなかった。プロセス一覧の照会はサンドボックスに拒否されたが、実行器は共有ロックと逐次の待機を使い、起動したビルドを背景に残して別の作業を進めていない。

## 実 CLI の受理・拒否

入力は既存 `ExchangeExamples.lean` の sample から一時ファイルを作った。負例は深い binary の重複欄とヘッダの未知の版だけを変更した。[入力の出どころと SHA-256](cli-inputs.json)を保存した。解析結果との比較や新しい期待結果の生成はしていない。

| 入力・呼び出し | 期待した終了・実際の終了 | 観測した出力・記録 |
|---|---|---|
| base の正常な1入力 | 0・0 | `intervalDiff: accepted inputs=1 (reader only)`。[記録](cli-valid.json)・[出力](cli-valid.log) |
| 深い位置の `op` 欄の重複 | 2・2 | `duplicate JSON field: op`。[記録](cli-duplicate.json)・[出力](cli-duplicate.log) |
| interval-corpus の未知の版2 | 2・2 | `unsupported interval corpus version`。[記録](cli-version.json)・[出力](cli-version.log) |
| 引数なし | 2・2 | `usage: intervalDiff INPUT`。[記録](cli-usage.json)・[出力](cli-usage.log) |
| 存在しない入力ファイル | 2・2 | ファイル不在の理由を表示。[記録](cli-missing.json)・[出力](cli-missing.log) |
| 未接続の `analyze INPUT REPORT` | 2・2 | usage を表示し、比較成功を装わない。[記録](cli-analyze-unavailable.json)・[出力](cli-analyze-unavailable.log) |

test-audit の作成時の関門では、実 CLI が生の入力を読者へ渡し、拒否と IO の失敗を非0へ接続することを確認対象とした。先に Json.parse して重複を消す退行、例外を成功へ変える退行、ファイルを読まず成功する退行を検出する。読者内の既存の正負例だけでは、ファイル IO・引数・終了状態まで通らないため、この接続の観測を追加した。既存の読者の準備を再利用し、本番の差し込み口・フラグ・公開範囲の拡大や、新しい永続的なテストターゲットは加えていない。

## 中心二命題・参照定義・旧主定理・公理の照合

[audit.py](audit.py) が B_WORK の git blob と作業ツリーの内容を照合した。[検査前](audit-before.json)・[検査後](audit-after.json)とも、対象 **4,538ファイル**のうち差は `formal/lakefile.toml` だけだった。残る4,537ファイルはバイト単位で一致する。既存 Lean の名前付き定理 **3,434件の言明と本文はファイル全体として不変**である。新設 Main に theorem・公理・sorry はない。

| 言明・参照定義 | 差分と意味の向き |
|---|---|
| `NormalSoundness`・`WarningSoundness` の本文・前提・結論 | `Interval/Eval.lean` 全体が不変。中心二命題の弱化なし |
| `EvalPartial`・`EvalBlock`・`EvalInput`・`Unmodeled`・`UnknownAt` | 同上。未知を具体規則へ置き換える変更もなし |
| `ConcreteValue`・`StandardRule`・`StandardBinding`・`EvalStandard`・`standardCallHead` | 同上。値・評価規則・認定する頭・操作の扱いの変更なし |
| `targetOperationAt`・`arithmeticOperationAt`・`WarningLocated` | `Interval/Sound.lean` 全体が不変。警告位置と演算の同定の集合は同じ |
| `concreteRule`・`syntacticReachChildren`・CallReach の定義と定理 | 該当する既存 Lean ファイル全体が不変。構文的な到達可能性の拡張・縮小なし |
| `AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models` | `Interval/Domain.lean`・`Environment.lean` 全体が不変。Models を強めていない |
| `RangeState.Models` と由来の表現 | `Interval/RangeState.lean` 全体が不変。成功値と内部の保存関係の変更なし |
| 公開入口・既存主定理・公理・`Builtins.Assumptions` | 既存 formal の全 Lean ファイルが不変。新しい仮定・公理・言明の変更なし |
| 既存六入口・corpus/sidecar・Rust・予算の固定表 | 既存 formal の設定以外、crates・fuzz・scripts が不変。既存六入口の登録と既定指定も保持 |

[work-inputs-sha256.json](work-inputs-sha256.json)には Main・lakefile・読者・正負例・既定 import のハッシュを保存した。作業末検査の前後で一致し、検査後に Lean・設定・入力・期待値は変更していない。`git diff --check` も成功した。

## 記録器の補正と申し送り

Lean の実装・正負例・work に予期しない失敗はない。点検器の最初の起動は環境の Python に tomllib がないため失敗した。追加依存を入れず、標準ライブラリで既定ターゲットの追加と設定ファイル全体の一致を検査する形へ直した。逐次ビルドの記録名が外側の実行器の記録名と重なり、モジュールごとの詳細ログは全体の成功・時間・121モジュールの要約で上書きされた。上表は残った全体記録だけを根拠にしており、失われたモジュールごとの時間は主張しない。保存先を別名に補正した。記録を作り直すためのビルドや work の再実行はしていない。

範囲の変更、停止条件への該当、4時間上限による中断はない。言語規則・中心二命題・公開の主定理の意味・公理に関する未決の判断は残っていない。private/ とそこを指すリンク、git の変更操作、担当の委任は利用していない。コミット・取り込み・docs/todo の更新は取りまとめの担当である。stage・change・release・check-formal.sh 全体、実 VM と Rust/Lean の比較は本枝の割り当てでは実施していない。別の状態の検査結果を引用して省いた検査はない。

| 残る手順 | 担当・受け渡す内容 | 見込み |
|---|---|---|
| L27b の独立レビュー・受け入れ・コミット・取り込み | 取りまとめ。読者への生入力の接続、既定ターゲット、既存定理・参照定義・六入口の不変を確認 | 不明 |
| 解析と具体評価の報告・局所比較・検査・受け入れ | L28。今回の `run` を `analyze|eval INPUT REPORT` へ接続する。読者は `readCorpus` を使う。sample の after=0 を解析の実消費の期待値へ転用しない | 計画による。今回未測定の時間は不明 |
| 全 profile・C5、Rust の独立交換・全関係定義・VM の比較、各検査・受け入れ | L29・X01〜X05。組み込みの関数・操作は primName、利用者関数と包みのシフトは funName を保つ。固定域は純粋なシフトだけであり、操作・HTTP の欄を対象へ戻さない | 計画による。今回未測定の時間は不明 |

## 取りまとめのレビュー（2026-10-26）

受け入れる。`formal/lakefile.toml` の変更は intervalDiff の登録と既定ターゲットへの追加だけで、既存の六つの入口と `moreLeanArgs` の `-M 12288` は変わらない。既存の Lean のファイルは変わらない。L28 へ進む。

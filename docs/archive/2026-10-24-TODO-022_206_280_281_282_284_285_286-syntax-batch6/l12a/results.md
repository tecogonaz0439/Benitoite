# L12a の結果

- 基準（B_WORK）: `21ee7e98e3f190a5ab582c56f9da97769912a55d`。
- 対象: plan.md「作業群 L12」の L12a。`EvalClosed.lean` の評価関数と `EvalPartial` への対応証明、既定 import、01-12 の定義と言明の写し、07-04 の対応を更新した。
- 作業開始時の HEAD は基準と一致し、差分はなかった。

## 実行した検査

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `cd formal` の下で `lake env lean Benitoite/Interval/EvalClosed.lean`（局所の反復） | 初期の試行は1、修正後の最終試行は0 | 各試行1秒未満（ツールの返却値）。合計は未計時 | 最終試行にエラー・警告なし。計算した結果に評価導出を添える関数と4定理、入口での独立例3件を検査した |
| `scripts/check.sh --level work --base 21ee7e98e3f190a5ab582c56f9da97769912a55d --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 未計時 | 名指しの `spec_tally`・`spec_examples`・`formal_build` を選択。自動分類は行わない部分選択であることを確認した |
| `scripts/check.sh --level work --base 21ee7e98e3f190a5ab582c56f9da97769912a55d --only formal_build,spec_examples,spec_tally` | 0 | 9.480秒 | 仕様集計の自己検査・集計、仕様例7件、既定 `lake build` と `sorry` 拒否を実行し、選択した検査が成功した |
| `git diff --check` | 0 | 未計時 | 追跡済み差分の空白の誤りなし。新設ファイルの空白と差分の範囲は別途読み取りで確認した |

局所の初期試行では、依存した結果型のパターン照合、trace の接頭辞の伝播、基本型の等号の計算、guard の型合わせ、独立例の計算結果を命題へ簡約する箇所に Lean の型エラーがあった。依存した証拠を値と組にして照合し、右辺の異常終了にも左辺の trace を付け、基本型の等号だけを計算する形に修正した。関数型を含む型全体の非計算的な比較を実行可能な評価器へ使う案は取り除いた。主定理・中心命題・公理の変更では解決していない。

## 計画からのずれと申し送り

- 言語の規則、既存の `EvalPartial`、中心二命題、主定理、公理、`Builtins.Assumptions` は変更していない。判断を取りまとめへ戻す停止条件は生じなかった。
- `evalClosed env input fuel` は `Option (ClosedRun (EvalPartial env input))` を返す。`ClosedRun` は outcome・trace と、その結果の評価導出を持つ。`some` の中の `failed` と、評価不能の `none` を区別する。fuel は評価器の深さであり、区間解析の操作数・保持項目数の予算とは別である。
- 到達した一般呼び出し、未知の値、境界、後続 profile の式は `none` にする。`evalClosed_call`・`evalClosed_unsupported` で一般呼び出しと境界について任意の fuel を量化した。未到達の未知式を含む短絡・分岐は評価できる。未知の関数を一つの値や失敗へ固定していない。
- `evalClosed_sound` は返した結果から `EvalPartial` の導出を得る。`evalClosed_trace_keys` は既存の trace の定理へ接続する。全入力の導出存在や、評価関係との双方向の同値は主張しない。
- 具体的に扱うのは土台の Integer64・Boolean・Unit、局所参照、定数・括弧・return、加算・整数除算・剰余・六比較、短絡・条件分岐、全 Block 形、整数 match・guard である。型の一致を計算するのは基本型同士に限る。期待型のない位置では構文から型候補を得て、別に評価導出を構築する。構造の内部のパターン束縛値や非整数 match の結果を任意に選ばない。詳しい受理範囲と `none` の意味は 01-12「区間解析の閉じた対象入力の評価」に記した。
- 新しい入口の例は、正常な左辺の trace を残した右辺失敗、未知の右辺を飛ばす短絡と到達時の評価不能・深さ0、偽の guard の後の腕選択を検査する。既存の評価関係の導出例だけでは、実行可能な関数が常に `none` を返す退行を捕まえないため、`evalClosed` の入口に固定した値・キー列の期待を置いた。既存の段の置換や、テスト専用の差し込み口は加えていない（test-audit の作成時の関門）。
- L12b が担当する広い独立例、C1 の定義・言明・仮定の独立レビューと受け入れは未実施である。Rust/VM との比較も本作業の範囲ではなく、計画の後続作業へ残る。L12a の検査失敗を後へ送るものはない。
- 開始時のブランチ名の確認で、禁止指定に含まれる `git branch --show-current` を一度実行した。これは指示からの逸脱である。読み取りのみであり、ブランチや履歴、index を変更する git 操作は行っていない。その後は `git branch` を使っていない。

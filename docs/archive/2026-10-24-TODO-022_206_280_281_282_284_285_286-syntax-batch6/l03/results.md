# L03 の結果

2026-10-24。基準 B_WORK は `f635f26dafadd39b90de19f6efa085c689718d29`。開始時の HEAD も同じであり、ブランチは `mod012/L03`、作業差分はなかった。

## 実行した検査

コマンドの作業ディレクトリは、lake の行だけ `formal/`、それ以外はリポジトリの根である。rtk は出力の仲介に用いた。work 本実行の外側の時間は Python の `time.monotonic()` で計測した。初期の局所試行と dry-run は外側の時間を計測していない。

| コマンド | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `lake env lean Benitoite/Interval/Environment.lean`（局所試行） | 初回1、修正後0 | 未計時 | 同梱環境には `List.Forall₂` がなく、局所列の対応を `LocalsModels` として定義した。具体環境の欄をそのまま帰納法の添字にできない箇所は列を一般化し、`1 + index` の簡約と append の添字条件を明示した。最終の局所確認は警告なし |
| `lake build Benitoite.Interval.Analyze`（局所試行） | 初回1、その後0 | 未計時 | 独立例の `OpRef.name` は存在しないため、実在する `OpRef.user` に修正。追加の混在例を含む最終の局所ビルドも成功 |
| `scripts/check.sh --level work --base f635f26dafadd39b90de19f6efa085c689718d29 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 未計時 | spec_tally・spec_examples・formal_build を指定どおり選択 |
| `scripts/check.sh --level work --base f635f26dafadd39b90de19f6efa085c689718d29 --only formal_build,spec_examples,spec_tally` | 0 | 9.072秒 | 集計の自己検査・仕様集計、仕様例7件、既定の lake build と sorry 使用の拒否をすべて通過 |
| `git diff --check` | 0 | 未計時 | 追跡済みの差分に空白の問題なし |

初期の修正用 Python を `formal/` から実行した際、根からの相対パスを指定して FileNotFoundError になった。一切書き込まれず、根から実行し直した。仕様集計は新節「区間解析の局所環境と本体境界」を Rust テスト参照のない節として表示する。未記入の初回リリース受け入れ条件はなし。新定義・補題・独立例は既定の Lean ビルドが検査している。

## 計画からのずれと申し送り

- L03 の範囲を実装した。`Environment.lean` は Models、lookup・extend・shift、パターンの位置数、忘却の保存、束縛番号の土台を持つ。`Analyze.lean` は53構成子と全相互帰納容器からの本体列挙と Top 開始を持つ。両方を既定 import へ接続し、01-12 に定義と言明を写した。
- 公開の型・エフェクトの規則、既存主定理、`NormalSoundness`・`WarningSoundness` の言明、公理、Builtins.Assumptions は変更していない。取りまとめへ判断を戻す必要のある点はなかった。
- `BodySeed` は構文と初期環境だけで、式の識別番号はまだ持たない。列挙は未到達・未対応の部分木にも入り、評価や警告の生成とは区別する。先行順番号と本体名への接続は L26、予算は L11、実行可能な解析への接続は後続 L 作業が担当する。
- `patternSlots` は単独の変数以外ではコアの束縛数だけ unknown を置く。match の腕も slots の位置数だけを保持する。パターン照合で得た具体値・区間と slots の並べ替えの接続は L09、bind・shadow の右辺区間の保存と別名の扱いは L06、Rust の BindingId との対応は A04 の担当である。`BindingScope` の位置列を字句スコープの復元に使う場合も nextId は戻さない。
- 独立例は、捕捉値の忘却、節の継続・引数・辞書の位置、穴と guard 内の本体、builder・shadow・wildcard の混在、構造のパターン、Reference の位置を検査する。test-audit の作成時の関門では、既存の領域・未知評価の例が扱っていない束縛数と捕捉境界の契約を対象とし、専用の差し込み口を足さないことを確認した。
- 指定の work 検査は本作業で一度実行した。Rust/Lean の全比較は本作業では未実施であり、計画の X05a/K1 と Z01b/K2 が担当する。独立レビューと受け入れは取りまとめが担当する。git の変更操作、private の読取り、docs/todo の更新は行っていない。

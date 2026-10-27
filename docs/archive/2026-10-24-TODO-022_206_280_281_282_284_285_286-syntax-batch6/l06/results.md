# L06 の結果

2026-10-24。基準 B_WORK は `067c72733f1e2e0780efa0381857b412ed09193e`、作業ブランチは `mod012/L06` である。開始時の HEAD は基準と一致し、未コミットの差分はなかった。L06 の実装と指定の work 検査を完了した。独立レビュー・取り込み・受け入れは取りまとめが行う。

## 実行した検査

`lake` のコマンドは `formal/`、`scripts/check.sh` と git の読み取りのコマンドはリポジトリの根で実行した。`rtk proxy` は出力を変更せずに通す。時間は `/usr/bin/time -p` の real である。

| コマンド・段階 | 終了状態 | 外側の時間 | 結果・修正 |
|---|---:|---:|---|
| `rtk proxy lake build Benitoite.Interval.Environment`（局所参照の評価規則追加後） | 0 | 1.29秒 | 成功。同じシェルで先行した編集用 Python は、作業ディレクトリからの相対パスを誤って FileNotFoundError となった。Environment の変更はこの時点では入っておらず、リポジトリの根から編集を適用し直した |
| `rtk proxy lake build Benitoite.Interval.Environment`（保存・更新の補題追加後） | 1 | 0.56秒 | Ty の等値に Decidable がなく、narrowAt のパターン照合も変数のままで簡約できなかった。型の構成子による分岐と、番号を先に読む定義へ直した |
| 同上（修正後） | 1 | 0.57秒 | 簡約で証明が閉じた後に不要な tactic が残っていた。その一行を削除した |
| 同上（再修正後） | 0 | 0.56秒 | 成功 |
| `rtk proxy lake build Benitoite.Interval.Flow`（初回） | 1 | 0.76秒 | 帰納法のケース名・変数名、constE の型の分岐、excludePoint の簡約で証明が失敗した。構文と証明での簡約・ケースの指定を修正した |
| 同上（証明修正1） | 1 | 0.97秒 | 帰納法の等式の置換と、constE の型の分岐に不足があった。結果の等式を先に消去し、型の分岐を明示した |
| 同上（証明修正2） | 1 | 1.08秒 | 等式の消去で変わったケースの引数名を修正した |
| 同上（証明修正3） | 0 | 1.08秒 | 成功。未使用の simp 引数の警告が一つ出たため、その引数を除いた |
| 同上（包含の補題・独立例・既定importの追加後） | 0 | 1.08秒 | 警告なく成功 |
| 同上（同型const・負号付き最小値の独立例追加後） | 0 | 1.09秒 | 警告なく成功 |
| `rtk proxy scripts/check.sh --level work --base 067c72733f1e2e0780efa0381857b412ed09193e --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | 計画どおり spec_tally・spec_examples・formal_build のみを選択 |
| `rtk proxy scripts/check.sh --level work --base 067c72733f1e2e0780efa0381857b412ed09193e --only formal_build,spec_examples,spec_tally` | 0 | 9.67秒 | 指定の work を一度実行し、全選択項目が成功 |
| `rtk git diff --check` | 0 | 未計測 | 空白の誤りなし |

work は、仕様集計の自己検査と集計、仕様書の例7件、既定の `lake build` と sorry の拒否を含む。仕様集計では参照印のない節が列挙され、今回の01-12の新節も含むが、初回リリースの完了条件の未記入はなく、終了0である。Rust の新機能や警告の期待を仕様例に先取りせず、Lean の独立例で今回の定義を確認した。局所検査の失敗は上表のとおり修正済みであり、期待値や主張する性質を緩めていない。

## 計画との差と申し送り

- `Environment.lean` に `bindRange`・`narrowAt` と環境の対応を保存する補題を追加した。新設の `Flow.lean` には同型リテラル・const・局所参照の区間、六比較の反転・否定、真偽ごとの絞り込み、環境の更新を置いた。`formal/Benitoite.lean` の既定 import に接続し、01-12の写しと07-04の保証範囲・対応表を同じ変更で更新した。
- 計画の対象ファイルに加え、`Eval.lean` に局所参照の評価規則を追加した。L05までの評価関係には local の具体値を読む規則がなく、`atomRange_sound` を具体評価と接続するために必要だった。通常値のある同じ de Bruijn 位置だけを読み、専用位置から通常値を取り出さず、trace を生成しない。
- 言語の規則、旧主定理、`NormalSoundness`・`WarningSoundness` の言明、公理、`Builtins.Assumptions` は変更していない。停止条件に該当する判断はなかった。
- `models_bindRange` は、任意の右辺の正常整数がその近似区間に属するなら bind/shadow の後も Models が保たれる、という局所の契約である。`models_bindAtom` はその契約を原子式の具体評価へ接続する。shadow は新しい位置を追加し、既存の `BindingScope.fresh_distinct`・`fresh_shift`・`fresh_valid` により番号の新規性と古い番号の保存を保つ。
- `integerConstant` は、同型のリテラル・負号付きリテラル・括弧・`constE Integer64` だけから定数を読む。任意の算術式を独自に定数評価しない。`atomRange` は const の中を空の局所環境で読み、対象外の式を Top とする。別幅のリテラルや const を Integer64 の定数と扱わない。
- `refineRange_sound` は実際の比較結果を満たす値の所属を示し、`models_refineEnv` はその具体値の lookup と結果の下で環境の対応を保存する。等値の偽枝は、内部の穴なら元の閉区間を残し、端点なら一点を除く。`lookup_refineEnv_other` は比較した位置以外の lookup が変わらないことを一般に示し、別名への逆伝播と古い shadow の位置の変更を行わない。
- 独立例は、六比較の両枝、最小値・最大値と k±1、等値の偽枝の穴・端点・一点、同型constと負号付き最小値、比較の左右反転・括弧、別幅・二変数・算術式の逆算の除外、別名のコピーと shadow の独立、Reference・builder位置の保持を確認する。既存の領域・加算・除算の例では比較固有の誤りを捕らえられないため、Flow の定義の境界に独立期待値を置いた。期待値を解析関数から作らず、テスト専用の差し込み口を加えていない。
- L07は、今回の `bindRange`・`atomRange`・`comparisonAt`・`refineEnv` をBlock全体の評価順と単一ifの解析へ接続し、具体的な条件式の評価から lookup と比較結果を渡す。今回の局所の補題から、Block全体・分岐・警告を合成した解析全体の健全性を証明済みとはしない。中心定理への合成は計画のL07b以後、Rust/VMとの接続と全比較はX作業の担当である。
- 独立レビューと受け入れは、取りまとめが本結果を受け取った後に行う。stage・change・releaseやRust/VMの全比較は今回の担当外であり、先取りしていない。
- private/とそこを指すスキルのリンクは読んでいない。git のadd・commit・branch・merge・stash・reset・checkout等の変更操作は行っていない。

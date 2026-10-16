# P2 の作業結果

## 実施した範囲

2026-10-15、plan.md の P2「型・依存・診断・形式化の事前確認」を行った。開始時の HEAD は `daa50081364b9cbd3962ed473390d7cdf61d18af`、作業ツリーは clean であり、P1 の記録は取り込み済みであった。

| ファイル | 内容 |
|---|---|
| `p2/types-and-dependencies.md` | design の型変更表の全行と構築・呼び出し・消費側の対応。prelude と明示/内部依存の区別、具体的なモジュール列、四つの Show の孤児規則と実装先 |
| `p2/formal.md` | D/B の定義・型規則・脱糖・定理の前提/結論の差分案、六入口・版・生成元・件数と破損入力の持ち主 |
| `p2/diagnostics.md` | 新四番号の未使用の確認、登録先、旧→新のコード/主文/help/位置/終了状態と既存の誤りの維持先 |
| `p2/inventory.py`、`p2/uses.json` | 再実行できる読み取り調査。16 組の検索位置、Rust/Lean/Python/shell の 259 ファイルと標準ソース 52 ファイルのハッシュ、52 モジュールの明示 import 全辺 |
| `decisions.md`、`design.md` | R19（循環検査の起点）・R20（RefOutcome の表の明記漏れ）を推す案として追加し、型変更表と開始時のレビュー対象を補足 |
| `README.md` | P2 の記録へのリンク |

処理系・テスト・期待値・現行設計書・formal・docs/todo は変更していない。公開の型/シグネチャと診断の仕様の実変更は 0 件。コミットは作成していない。

## test-audit の作成時の関門

テストの追加・変更はない。四問への回答は次のとおりである。

1. 守る独立した契約は、P1 の裸の try の成功/失敗と最内の戻り境界、公開の型の受け渡し、依存の循環、診断の出力、形式化の対象範囲である。後続の主となる境界と検査の持ち主は三つの対応表に記した。
2. 想定する退行は、Body::new の補助の制約検査の呼び出し漏れ、prelude の内部依存の循環の見落とし、record の生成照合へ外部 view を適用すること、要求/停止結果での原因の混入や消失、checker の対象内件数の縮小である。
3. P2 は振る舞いを変えないため、新しいテストを追加しない。現在の lib と関連する統合テストをそのまま使う。後続は既存表の拡張を優先し、六入口の正常/破損入力を tests/formal/tests に置く。
4. 本番の公開範囲・フラグ・引数・差し込み口は追加していない。inventory.py は調査専用で、通常の検査から読み込ませない。

既存 assert の削除、期待値の緩和、skip/ignore 化、予算・時間制限・対象内件数の変更はない。テストを削除していない。

## 実行した検査

実行する検査の範囲は開始前に設計者へ報告した。コマンドは rtk を経由し、下表には内側のコマンドを記す。通常の構成だけを使い、ランダム差分の種や件数・予算を上書きしていない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,155 passed、既存の ignored 21、70.56 秒 |
| `cargo test -p benitoite --test golden --test fmt_command --test package_command --test desugar_export --test skill_docs` | 成功。5 ターゲット、52 passed、既存の ignored 1、61.93 秒 |
| `cargo test -p benitoite --test coverage_export` | 成功。1 passed、既存の ignored 1、0.06 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `rg -n 'E0258\|E0259\|E0511\|E0817' crates/benitoite`（正規表現の選択） | 使用 0 件、終了状態 1。codes.rs の定義行でも未登録 |
| `python3 -B .../p2/inventory.py` の再出力と uses.json の比較 | 一致。収録 311 ファイルの SHA-256 を照合 |
| P1 の inputs.json のハッシュ照合 | 4,272 入力の不一致 0。symlink はリンク先の文字列として比較 |
| Python の AST 構文確認、追加文書の相対リンク・表の列数・記載したパスの確認 | 成功 |
| `git diff --check`、追加ファイルの `git diff --no-index --check /dev/null <file>` | 空白エラーなし。no-index は追加差分による終了状態 1、エラー出力なし |

scripts/check.sh（dry-run を含む）と gc-stress 構成は依頼に従い実行していない。共通の関門 K7 の最終実行はオーケストレータが担当する。formal は変更していないので lake build/check-formal は未実行。通常構成の coverage_export/desugar_export の成功を、六入口の Lean との比較の成功とは扱わない。診断の表も変えていないので gen_skill の再生成は不要である。

## 計画との差と後続への申し送り

調査対象は P2 の範囲内である。実態と計画の明記との差は、R19 と R20 に推す案として残した。R19 は現在の入口だけの循環探索では prelude の内部辺を取り逃すことへの補足、R20 は設計で要求する参照実行の報告比較に必要な公開結果型の明記である。G1 で R2・R7 とともにレビューする。所定の Lean の規則・言明のレビューは D1〜D4/B1〜B5 へ残し、今回の擬似定義を検証済みの仕様として扱わない。

D5 は Body::new の三つ目の使用箇所（traits の check_bounds）も更新する。D2b/D6a は source の view と record/try/getter の合成した照合を分ける。B10-3 は ParseError の表示にトップレベルの message 関数を仮定せず、生成した `ParseError.message(x)` を使う。R2 の属性対象四型と Show 対象四型を混同しない。B10-1/B10-2 は Request の Copy、停止の採用と消去、RefOutcome と差分比較を一緒に確認する。

新しい公開の変更がさらに必要なら R7 に従って具体的な差分を報告する。六入口の新版の対象内件数・対象外理由・破損入力の拒否は D3/D6b/B4/B10a-3 の実行時に記録し、今回の使用位置一覧から成功したと推測しない。

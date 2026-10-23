# C2 の結果

2026-10-23。基準B_WORKは `a4d2b6b54f78565a7df9d6f81c240bf810f2baaa`。ブランチは `mod011/C2`。作業C2の実装・関連するテスト・設計書を変更し、割り当てられた検査を、初回の失敗を修正したうえで完了した。`private/` と、それを指すSkillのリンクは読まず、gitの変更操作は行っていない。

## 実行した検査

コマンドは出力の中継用の `rtk proxy` を省略して記す。外側の時間は、workではPythonのmonotonic時計で測定した。途中の直接実行で外側を計測していないものは未計測と記す。

| コマンド | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `cargo build -p benitoite --bin benitoite`（変更前） | 0。基準のソースからCLIをビルド | 未計測（Cargo表示10.58秒） |
| `cargo test -p benitoite --test declarations diagnosed_recovery_preserves_partial_structure -- --nocapture`（修正前・実装中） | 修正前は101。`[SourceLocation.here]`をList[Integer]とList[String]へ使った場合の余分なE0401で失敗することを確認。実装中は外側の不一致の欠落・パターンへの伝播漏れ・遅延した不一致を順に確認して修正 | 未計測 |
| `cargo test -p benitoite --test declarations diagnosed_binding_recovery_preserves_own_contracts -- --nocapture` | 0、C1の既存の表形式テスト1件成功 | 未計測（Cargo表示検査0.95秒） |
| `cargo test -p benitoite --lib typeck::tests::diagnostics_batch4::declaration_provenance_preserves_causes_and_independent_errors -- --nocapture` | 0、既存の宣言由来の回復1件成功 | 未計測（Cargo表示ビルド14.05秒、検査1.51秒） |
| `cargo test -p benitoite --lib typeck::tests:: -- --nocapture` | 0、既存44件成功。この後の後検査の変更も、最終workのlib全件で検査する | 未計測（Cargo表示検査10.12秒） |
| `cargo test -p benitoite --test declarations diagnosed_recovery_ -- --nocapture`（途中に複数回） | 最後は0、追加した2件成功。テスト入力の`lambda`の戻り値省略、名前の隠蔽、`==`、Consoleのimport漏れによる別の診断を直し、意図した検査へ到達することを確認 | 未計測（最後のCargo表示ビルド2.90秒、検査3.59秒） |
| `scripts/check.sh --level work --base a4d2b6b54f78565a7df9d6f81c240bf810f2baaa --test declarations --test checked_args --test golden --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択 | 1秒未満 |
| 上と同じ指定の実行（`--dry-run`なし） | 1。fmt成功後、列挙型の分岐の明記不足7箇所とテストモジュール後の関数配置によりclippyで停止。lib以降は未実施 | 6.010秒 |
| `scripts/check.sh --level work --base a4d2b6b54f78565a7df9d6f81c240bf810f2baaa --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test declarations --test checked_args --test golden --dry-run` | 0。修正後に古くなったfmt・clippyと、未実施の残りを名指した | 1秒未満 |
| 上と同じ指定の実行（`--dry-run`なし） | 1。fmt・clippy成功。libは1,262件成功・21件ignore、checked_argsは10件成功、declarationsは20件成功。goldenは803入力を処理し、1入力の期待値差で1件成功・1件失敗。source_rules以降は未実施 | 186.535秒 |
| `BENITOITE_GOLDEN_FILTER=patterns/match_on_error_type cargo test -p benitoite --test golden golden_suite -- --nocapture`（期待値修正後） | 0。失敗した入力1件と、その整形の性質が成功 | 0.295秒 |
| `scripts/check.sh --level work --base a4d2b6b54f78565a7df9d6f81c240bf810f2baaa --only tests_related,source_rules,skill_generated,spec_tally --test golden --dry-run` | 0。変更した期待値を読むgoldenと、まだ実行していない残りだけを選択 | 1秒未満 |
| 上と同じ指定の実行（`--dry-run`なし） | 0。goldenは2件成功（803入力、VM/参照評価の一致285件、checkのコアIR照合65件、整形の性質649件）。ソース規約・Skill生成物照合・仕様集計も成功。生成物の差分なし | 61.880秒 |
| 変更した設計書3文書と本記録の相対Markdownリンク・フェンス・末尾空白、既存の見出しの維持をPythonで静的確認。診断fixtureのJSONと`git diff --check`も確認 | 0 | 1秒未満 |

本番のコードは初回workのclippy修正後には変えていない。goldenの期待値だけを変えた後は、その入力を読むgoldenと未実施の単位だけを実行し、成功したlib全件・checked_args・declarations・clippy・fmtを重ねて実行していない。最終の静的確認まで成功した。

## 計画からのずれと修正

- 既存Provenanceの値から束縛への関係を、型の各部分の合成・射影に拡張した。単一化の連結成分を使った一律の抑制は加えていない。原因の追跡は既存の型の深さ・節数の予算内とし、打ち切った部分を理由に追加の診断を抑えない。元の原因IDは残す。
- 計画にある必要な後検査として、`records.rs`・`pattern_ext.rs`・`traits/solve.rs`も変更した。正常な関数の宣言した結果と、型パラメータを通じて値から決まる結果を分けるため、呼び出しの制約を解く前のシグネチャも保持する。ヒープ、実行用Ty、交換形式、Leanの定義・主定理・公理は変更していない。
- 追加のテストは`tests/declarations.rs`の二つの表にまとめた。複合型の表はE0467・位置引数E0403・名前付き引数の遅延E0403の3経路と17種類の入力、原因修正後・成功入力の2対照を持つ。後検査の表は2経路と9種類の入力を持つ。根の診断、独立した不一致、誤り入力の実行拒否、正常な宣言した結果、部分の取り出し、演算子・補間・比較・型クラス・網羅性・個数・ラベル・禁止効果を公開の検査入口で確かめる。テスト用の公開APIは追加していない。goldenの`.bnt`入力は変えず、既存の`match_on_error_type.diag.json`へ独立したE0601の期待値を追加した。
- 正常な要素もあるリストでは、その要素を型の根拠として残す。遅延した呼び出しを含むこの入力の不一致は、制約の解決順によって元の束縛か使用の位置で報告されるため、テストはその二位置を許す。
- 初回workのclippyの失敗は分岐と配置を規約に合わせて修正した。その後のgoldenの失敗は、型の誤りを持つListを包んだOptionについて、外側の`Option.None`の不足を独立に検出したことによる。今回の既知の外側を検査する方針どおりであるため、元のE0401を保持し、E0601の位置・文言・修正案を期待値へ追加した。期待する診断の削除、入力の大きさ・ignore・時間制限の緩和はしていない。

- 本番のコードは500行追加・76行削除、テストは203行追加・削除なし（Rustの表202行、goldenの期待値1行）。低価値のテストを整理する監査は行っていない。

## 申し送り

- F4aは、`diagnosed_cause`で値全体の診断済み原因を確認できる。複合型の部分は`Provenance.diagnosed`の経路と値側の形を通じてzonkに反映する。書式の型集合の判定では、外側の既知の型と、その一部分の未知を区別する。
- 後検査の限界を02-05に記した。部分が未知のパターンでは、内側を変数かワイルドカードとする外側だけの照合に限って網羅性等を検査する。内側も照合する場合は見送る。型クラスの複数の要求では、先の未知の部分により後の部分の診断が残らない場合がある。失敗入力のすべての独立した診断を抽出する一般的な保証は加えていない。
- 言語の規則とLeanの主定理・公理を変更する判断は生じていない。ヒープの不変条件と安全点を越える保持方式も変えていないため、C2末尾のheap/stress・Miri・Lean全比較の追加実行は不要である。
- 取り込み後のshort測定と独立レビュー・受け入れ、S-Cでの結果の引用は取りまとめの担当である。改造全体のchangeと公開候補のreleaseは、今回の作業C2の担当外である。

## 取りまとめの性能の比較 short（C2 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=121f42e675da43362d0664a3be40539f36824856 --name batch5-c2`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 108 秒（ビルドを含む）。
- 判定: 47 点が「判定不能」、19 点が「達成」（しきい値の内側）。ただし型検査に重い入力が W1 比で増えた（higher-0-300 は A6 の後 +2.2%、C1 の後 +3.4%、C2 の後 +8.4%。classes-300 は +5.3%、functions-modules-1000-1 は +5.2%）。しきい値（10% か 2 ms の大きい方）は越えていないが、誤りのない入力でも回復の追跡の費用を払っている疑いがあるので、C1・C2 のレビューで原因を調べる。
- 記録: `tools/bench/results/2026-10-23-121f42e6-batch5-c2/`（手元の絶対パスは `<repo>` に伏せた）。

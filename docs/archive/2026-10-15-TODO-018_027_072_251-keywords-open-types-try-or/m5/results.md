# M5 生成物・裸の検査の保持・移行の段末検査

2026-10-16、開始時の HEAD は `3bfece321c21`（完全な値は audit.json）、作業ツリーに変更はなかった。M5 の生成物の再現性と裸の検査の照合を終え、G7 の確認表を揃えた。旧移行器の既知の失敗 R75 と、依頼で委任された check.sh・gc-stress の検査は残るため、G7 全体の合格とは報告しない。

## 変更と確認結果

追加したファイルはこの m5 ディレクトリだけである。

- [review.md](review.md): G7 の確認表。P1 全646候補・166ファイルの扱い、裸の検査の各境界、全追跡入力の自動分類と保留理由、通常の検査の依存を対応付けた。
- [audit.py](audit.py)・[audit.json](audit.json): P1 の比較元のハッシュ、候補ごとの index・元の位置、golden 66入力と関連254ファイル、Rust の復号済み断片、M3/M4 の最終308入力を照合する道具と記録である。通常の検査には接続しない。
- [reconciliation.json](reconciliation.json): 全追跡2,987入力のハッシュと3,721候補の集計、hold/change 170候補の位置・周囲の行・最終の扱いを記録した。英語の現行サンプルの未確認は0件、日本語訳46候補は M8 へ対応付けた。
- [generation.json](generation.json): gen_skill 二度の実行について、Skill 全59ファイルと bundle の計60ファイルのハッシュを比較した。開始時・一度目・二度目がすべて一致した。
- [diagnostics.md](diagnostics.md): 実装済みの診断変更と各作業の厳密な対応表、M3 の E0211 の旧→新、元の誤りの保持先を集約した。M5 による診断変更は0件である。

P1 の golden の入力・期待値・付属入力は254ファイルすべて完全一致した。Rust の try を含む復号済み断片は163件が完全一致し、変更された5件は、資源解放の共通入力、Json の追加の観測、生成元の説明と修正例へ個別に対応付けた。assert の意味は review.md の境界ごとの表で確認した。既存の assert の削除・比較の緩和・ignore の追加はない。処理系の本番の Rust とテストの Rust の行数の増減はともに0行、テストの削除は0件である。

## test-audit の関門

1. 守る契約は裸の try の固定した失敗の返却である。公開 parser/typecheck/desugar、VM と参照実行、CLI golden、formatter を主となる境界とし、成功/失敗、最内の戻り先、型の不一致、解放、診断位置、再整形を既存の検査で確認した。
2. 捕まえる退行は、全手本の一律移行で裸の入力も書き換えること、失敗の理由や副位置を別の診断へ付け替えること、早期戻り後の評価・解放を変えること、生成物の再生成漏れである。
3. 新しい処理系のテストは加えていない。入力のハッシュと復号済みの断片の比較を、既存の assert の差分確認と実行結果に組み合わせた。audit.py はこの作業の照合記録を作る道具であり、字面を探すだけの新しい通常テストにはしていない。
4. 本番の API・フラグ・ラッパー・テスト用の差し込み口を追加していない。通常の検査は独立した入力を使い、この改造の記録を読まない。旧移行器の既知の BASE 依存は R75 として区別した。

## 検査

依頼に従い check.sh は dry-run も含めて実行せず、M5 の段末に選ぶ名前が含む検査のうち、以下を個別に実行した。gc-stress の構成・長い ignore の検査・全体の検査は実行していない。正式な段末の check.sh の結果には代用しない。

| コマンド・照合 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、80.50秒 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test golden --test desugar_export --test random_programs --test runtime_builtins --test l21_json --test fmt_command` | 成功。10スイート・66 passed、既存1 ignored、123.83秒。乱択差分の件数・種・時間制限は変更なし |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `cargo run -p benitoite --example gen_skill`（二度） | 成功。60ファイルの全ハッシュが開始時から一致 |
| `cargo build -p benitoite --example named_arguments_inventory --example try_actions_inventory` | 成功 |
| `python3 -B tools/source-migrate/test_source_migrate.py` | 成功、6件 |
| `python3 -B tools/try-actions-migrate/test_migrate.py` | 成功、6件 |
| `python3 -B tools/named-arguments-migrate/test_migrate.py` | **失敗**。8件中2件成功・6件失敗。全失敗が旧 BASE の n1/joins.json の欠落（R75）。ログは `/tmp/benitoite-m5-old-migrate.log` |
| `python3 -B tools/skill-eval/skill_eval.py --self-test --benitoite target/debug/benitoite` | 成功。11課題と wrapper の計12件。LLM は呼んでいない |
| `python3 -B tools/spec-coverage/spec_coverage.py --self-test` | 成功 |
| `python3 -B tools/spec-coverage/spec_coverage.py` | 成功。未充足の初回リリース完了条件なし。テスト参照印のない既存の節の一覧は出力された |
| check.sh の check_python_tools と同じ8種の glob の `ast.parse` | 成功、32ファイル。check.sh 自体は呼んでいない |
| 全追跡入力の inventory、audit.py の再実行と JSON/実ファイルのハッシュ照合 | 成功。未分類0、英語の現行サンプルの未確認0 |
| `git diff --check`、新規記録の JSON・リンク・末尾の空白・Python の構文 | 成功 |

最後の Rust の検査と Skill の生成の後、Rust・標準ライブラリ・実行する入力・生成物に変更はない。形式化に触れていないため、lake build と check-formal は実行していない。コミットと docs/todo の変更はしていない。

## 計画との差と申し送り

新たな仕様判断や計画からの設計上のずれはなく、新しい R は追加していない。旧移行器の失敗と過去の基準への依存は既存の R75 に従って残件として報告する。基準データの仮置き、旧構文の環境の復元、assert の変更は行っていない。

オーケストレータは M5 の段末の `check.sh --only rust,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python` と gc-stress を含む必要な検査を行い、旧移行器の残件を含めて G7 の完了を判断する。M6 は E0908、M6a/M7 は版と固定ハッシュ、M8 は日本語訳を扱う。M3/M4 の manifest はそれぞれの適用時点の入力用であり、後続の入力へ再利用しない。

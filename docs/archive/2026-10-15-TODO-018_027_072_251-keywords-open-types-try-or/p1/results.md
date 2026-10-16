# P1 の作業結果

## 実装した範囲

2026-10-15、plan.md の P1「基準と対象一覧の確定」を行った。開始時の HEAD は `dc375420073cf71f8fcd0a85aa4c29c19078715e`、作業ツリーは clean であった。目的は Q6 の手本と裸の検査の区別、および Q12 の四失敗型の適用範囲を、後続が比較できる形で固定することである。

| 変更ファイル | 内容 |
|---|---|
| `README.md` | P1 の記録へのリンクを追加 |
| `p1/baseline.md` | HEAD・入力ハッシュの照合、四失敗型と既存 6 照合、追加分岐 0 件、裸の検査の契約、前回 G1〜G8b と今回の関門の対応 |
| `p1/migration.md` | 646 候補 / 166 ファイルの確認表。手本・実装・検査・記法・歴史資料・生成元を区別し、次の担当を記載 |
| `p1/inputs.json` | 4,272 入力の役割と SHA-256、Cargo 46 ターゲット、旧抽出の候補と版宣言、補完の字面の候補、golden の入力と期待値の対応 |
| `p1/inventory.py` | P1 の追加一覧を標準出力へ出す読み取り専用の調査。通常の検査への依存は追加しない |
| `p1/results.md` | 本記録 |

処理系・テスト・期待値・現行設計書・formal・docs/todo は変更していない。本番の Rust とテストの行数の増減はいずれも 0 である。コミットは作成していない。

## test-audit の作成時の関門

テストの追加・変更はない。四問の確認を次のように記録する。

1. 守る契約は、裸の try の成功/失敗、早期戻り、最内側の関数・ラムダ・穴の境界、入れ子、型の不一致、解放と整形である。持ち主と既存の観測は baseline.md に列挙した。
2. 現実的な退行は、処置追加による operand の境界変更、囲む戻り型の取り違え、別の誤りによる負の入力の早期拒否、失敗後の続行、解放漏れである。
3. P1 は振る舞いを変えないため、新しいテストを加える理由はない。既存の表・golden・差分実行を使い、入力と期待のハッシュを比較元として残した。
4. 本番の公開範囲・フラグ・引数・差し込み口は追加していない。調査用 Python はこの改造ディレクトリだけに置き、通常のテストから読ませない。

既存の assert の削除、期待値の緩和、skip/ignore 化、時間制限や生成件数の変更はない。今回消したテストはない。

## 実行した検査

シェルでは rtk を経由した。下表はその内側で実行したコマンドである。検査前に実行する範囲を設計者へ報告した。

| コマンド・確認 | 結果 |
|---|---|
| `python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/study/inventory.py` | 成功。既存 JSON と head 以外の全項目が一致。1,195 入力・646 候補・166 ファイルを維持 |
| `python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/study/failure-types.py` | 成功。既存 JSON と head 以外の全項目が一致。22 宣言・163 候補・6 照合を維持 |
| `python3 -B docs/2026-10-15-TODO-018_027_072_251-keywords-open-types-try-or/p1/inventory.py` | 成功。入力ハッシュ不一致 0。二度目の出力も inputs.json とバイト単位で一致 |
| `cargo metadata --no-deps --format-version 1` | 成功。lib 1・bin 1・example 9・統合テスト 35 の計 46 ターゲットを一覧化 |
| `cargo test -p benitoite --lib` | 成功。1,155 passed、既存の ignored 21、実行 72.05 秒 |
| `cargo test -p benitoite --test golden --test fmt_command --test desugar_export --test random_programs --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test runtime_builtins --test package_command` | 成功。10 ターゲット、73 passed、既存の ignored 1、実行 115.74 秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check`、非追跡の追加ファイルも `git diff --no-index --check /dev/null <file>` で確認 | 空白エラーなし。通常の diff は成功。no-index は追加差分による終了状態 1 で、エラーの出力なし |
| Python の AST による構文確認、JSON の件数・ハッシュ・確認表・ローカルリンクの照合 | 成功 |

golden の通常の全入力を実行した。ランダム差分の件数・種・時間予算の上書きはしていない。新たな診断の仕様変更はなく、旧→新の診断対応は今回は 0 件である。

scripts/check.sh（dry-run を含む）と gc-stress 構成の検査は、今回の依頼に従い実行していない。共通の関門 K7 の最終実行はオーケストレータへ委ねる。formal は変更していないため、lake build と check-formal は今回実行していない。両構成の全ターゲット実行と六入口の比較は、計画が指定する後続の作業に残る。

## 計画との差と申し送り

P1 の範囲・仕様の判断に変更はない。開始時の HEAD と study の HEAD の差は、今回の設計資料 16 ファイルだけで説明でき、調査対象の入力は一致した。raw_hits の追加は、計画にある全サンプル・全ターゲットの入力一覧を補うものである。新しい R 番号を要する計画外の判断はない。

P2 は baseline.md と inputs.json から型・依存・診断・定理の対応を具体化する。M2〜M4 は migration.md の候補の実行例/記法と処置を個別に確定し、特に IO/File.bnt と Network/Http.bnt の三つは return で契約を維持する。M5 は裸の検査の入力・assert・観測を照合する。M6a/M7 は language と固定ハッシュを現在のツリーで再抽出し、通常入力と版/ハッシュの負の検査を区別する。

追加分岐 0 件は旧入力の字句候補と本文の確認による結論であり、変更後の型付き網羅性の結果ではない。D6c〜D9 で改めて確認する。P1 の候補表を適用用 manifest として使わず、通常の検査から改造ディレクトリへ依存を追加しない。

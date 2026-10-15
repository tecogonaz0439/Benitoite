# N35 の実装記録

## 範囲

設計者が 2026-10-15 に決めた `0.0.5` を、クレートの版、互換性の表、現行の language 宣言、英語の案内へ反映する。R90 の診断の旧→新対応表も、同日の設計者の承認を記録する。日本語訳は N35a、公開前の全体検査は N36 に残す。

## テストの作成時の関門

1. 入口・根の設定・依存の設定を読み込む公開の境界で、0.0.5 より古い版の E0908、同じ版の受理、未来版の E0907 と移行案内を守る。通常の既存入力は元の出力・診断まで到達することを守る。
2. BREAKING_CHANGES の登録漏れ、比較の境界の誤り、設定の種類による検査漏れ、通常入力に残った旧版が本来の診断を隠す退行を捕まえる。
3. 比較アルゴリズムの既存テストは合成の表を使うため、実際の登録漏れを検出しない。実際の表を使う検査を modules の公開の読み込みへ一つの表として加える。CLI では E0908 が最終の JSON・終了状態 2 へ伝わることを、旧版の一入力の golden で確かめる。language なしの E0449・E0257 は既存の検査を維持する。既存の assert・終了状態・期待値の厳密さを維持する。
4. ファイルの差し替えには既存の MemFs と公開の load_program を使い、本番の API・公開範囲・フラグを追加しない。

language-updates.json は通常入力の宣言の修正前後を記録する（60 ファイル・99 行）。各ファイルのハッシュは最終の内容に対応し、changes は宣言の変更箇所を示す。N1 の 113 件との対応は n1-reconciliation.json に記録する。版の比較アルゴリズムの合成入力、未来版、過去の文書と記録、日本語訳は一括更新しない。固定ハッシュの入力は、読み込みと共用しているため R104 に従って更新した。hash-change.json に三つの固定ハッシュの修正前後を、expectation-changes.json に診断・ハッシュ・解析値の期待値の修正理由を記録した。

処理系は、互換性の表に 0.0.5 の一件と英語の変更説明を加えた。版比較と読み込みの順序は変えない。現行の設計書の「表は空」という記述を更新し、英語のリファレンス・導入手順・CHANGELOG に版と移行手順を揃えた。Skill の再生成は成功し、生成物に差分はなかった。配布する Skill の版は既存の埋め込みの置換により 0.0.5 となる。

## 検査

- `cargo test -p benitoite --lib`: 1,155 件成功、既存の ignore 21 件。72.12 秒。
- `cargo test -p benitoite --lib modules::`: 38 件成功。入口・根の設定・依存の設定の版の境界を含む。
- `cargo test -p benitoite --test golden`: 2 件成功。741 ケースで元の出力・診断を検査した。追加した older-language は E0908 の JSON と終了状態 2 を厳密に比較する。
- `cargo test -p benitoite --test package_command --test reference_examples --test skill_docs --test spec_examples --test fmt_command --test test_command`: 13・1・8・7・15・17 件成功。
- `cargo run -p benitoite --example gen_skill`: 成功、生成物の差分なし。
- `cargo clippy --all-targets`: 成功。
- K の `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` と `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`: 成功。
- `cargo fmt --all --check` と `git diff --check`: 成功。移行一覧の全ファイルの修正前後のハッシュは HEAD と最終ファイルに一致し、CRLF も維持した。変更した英語のリリース文書の相対リンクの対象は存在する。
- CLI の確認: `--version` は `benitoite 0.0.5` と `Unicode 17.0.0`。language なしと 0.0.5 の入力は成功し、0.0.4 は E0908、0.0.6 は E0907、language なしの複数位置指定は E0449、名前のない関数型は E0257 となる。旧版と旧関数型を組み合わせると、ソース位置の順で E0908・E0257 の二件だけを出す。入力・コード列・終了状態は version-smoke.json に記録した。解析の後に版検査を行う既存の順を保ち、後段の型検査には進まない。

初回のライブラリ検査は 4 件失敗した。共用のハッシュ入力の旧版による三件と、構文解析の入力だけを更新して期待する値を旧版のまま残した一件である。共用入力と独立に計算した固定ハッシュを更新し、解析値の厳密な期待を 0.0.5 へ揃え、全体を再実行して成功した。golden の初回は共用パッケージの hash-mismatch の computed の期待値が旧ハッシュだったため失敗し、同じ独立した計算値へ揃えて全体を再実行して成功した。package_command の初回も入力の変更に伴う固定ハッシュだけが不一致だったため、独立に再計算した値へ揃えて全件の成功を確認した。期待値の一括生成、assert の削除、ignore の追加は行わない。

Rust の本番コードは差し引き 5 行増、Rust のテストは 68 行増である。新しい CLI の golden は 8 行である。既存のテストと本番の API は削除しない。

## 申し送り

計画の範囲は変えず、N1 の固定ハッシュ入力の分類と共用の実態の違いだけを R104 に記録した。日本語訳の版・例・移行案内は N35a に残す。N36 は最終の訳と版で公開前の全体検査を行う。依頼に従い scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は行わない。formal/ の変更はない。コミット・タグ・公開・docs/todo/ の変更は行わない。

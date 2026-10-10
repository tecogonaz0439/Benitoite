# 実装プラン

小さな改造なので、オーケストレータ（Claude Code）が直接実装する。判断は [decisions.md](decisions.md) にある。

## 手順

1. 長いテストに印を付ける: 大きさそのもので確かめる単体テスト 16 件に `#[ignore = "long: ..."]` を付ける。ヒープのモジュールの 2 件は `#[cfg_attr(not(miri), ignore = "long: ...")]` とする。
2. ゴールデンテストを並べる: `tests/golden.rs` の `golden_suite` で、ケースをスレッドに分けて走らせ、結果をケースの順に集める。
3. 仕様の網羅の集計を直す: `secf1-*.bnt` の印を 2 行に分け、期待値の行番号を作り直す。道具の完了条件の行の数を、今のロードマップに合わせる。
4. `scripts/check.sh` を書き直す: 選んだ検査と全体の検査の 2 段、`--base`・`--dry-run`、検査を始める前の表示。
5. 文書を直す: 07-03「実装の規約と静的な検査」「受け入れ例と仕様の項目の対応」、07-04 の `lake build` の扱い、AGENTS.md の `scripts/` の行と「テストの運用」、`check-heap.sh` の頭のコメント、`tools/spec-coverage/README.md`。
6. 確かめる: 長いテストを除いたテストと回収の強制の時間を測り、`scripts/check.sh --full` を通す。選んだ検査の選び方を、文書だけの変更・処理系の変更などの場合で `--dry-run` で確かめる。結果を [measurements.md](measurements.md) に書き足す。
7. 終える: TODO-171 の扱った部分を docs/todo から除き（残りの論点は TODO-171 に残す）、このディレクトリを `docs/archive/` へ移す。

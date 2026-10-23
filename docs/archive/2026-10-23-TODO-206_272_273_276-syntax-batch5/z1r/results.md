# 作業 Z1R の結果

2026-10-24、Z1R 実装担当 Codex。対象は [RV-Z1](../reviews/RV-Z1.md) の M1・L1〜L5 の文書修正である。L6 は指示どおり後の改造の課題として取りまとめへ渡す。

## 基準と範囲

- B_WORK と HEAD: `1d64e44c7f91c18d5dc3c3b9554ba22547b8a431`。ブランチは `mod011/Z1R`、開始時の作業ツリーに差分はなかった。
- 変更は CHANGELOG、英語・日本語のリファレンス、設計書、改造の記録に限る。処理系の文言・ソース、標準ソース、テスト入力、Lean、check-formal の道具を変更していない。
- private・private を指すスキルのリンク・docs/todo は読まず、git の変更操作、履歴の集約・タグ・push は行っていない。言語の規則や Lean の主定理・公理の変更を要する停止事項はない。

## RV-Z1 の各指摘への対応

| 指摘 | 対応と確認 |
|---|---|
| M1 | `docs/reference/benitoite.md` と `docs/ja/reference/benitoite.md` に、`e0ed5eb2` の 0.0.10 の移行小節を本文を変えずに復元した。並びは 0.0.11・0.0.10・0.0.9。名前付き引数の移行道具の復元手順へのリンクを含む。install の英語・日本語の「0.0.9 から 0.0.10 への更新」と、版・移行事項・リンクの対応を確認した。install の本文は変更していない。 |
| L1 | CHANGELOG の 0.0.11 の表示の幅の項目に、直接の依存 unicode-width 0.2.2（Unicode 17.0.0、`cjk` 機能）と第三者表示について、既存の依存の書き方に合わせて一文を加えた。 |
| L2 | `z1/manual-cli-table.md` の33番を「値の型の位置を副位置に表示、受け付ける型を注記に表示」へ訂正した。保存済みの生の JSON 出力の secondary と notes に一致する。 |
| L3 | 06-09 と 01-03 を、各版は CHANGELOG を参照し、0.0.5・0.0.8〜0.0.11 は節を名指し、0.0.6・0.0.7 は節を名指さないという記述へそろえた。既存の help の定数と照合し、処理系の文言は変更していない。 |
| L4 | `z1/results.md` の計画との差に、変更したテストのファイルに ignored のテストがないため long_only を再実行しない理由と、build_info の ignored 5件は別途実行済みであることを追記した。 |
| L5 | 同じ節に「取りまとめが 2026-10-24 に承認（RV-Z1 の L5）」と追記した。対象は plan.md の work Z1 の行と続行の節である。Z1R では plan.md を変更していない。 |
| L6 | 今回は変更しない。01-spec に置く版ごとの道具の記述の整理は、取りまとめが後の改造の課題として docs/todo へ登録する。Z1R では docs/todo を読まず、登録しない。 |

改造の [results.md](../results.md#レビューと追加修正の対応) のレビュー表にも RV-Z1 の行を加えた。

## 検査と結果

| コマンド・確認 | 終了状態と結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| `scripts/check.sh --level work --base 1d64e44c --dry-run` | 0。spec_tally・spec_examples・reference_examples の三単位を選択。Rust の全 lib は選ばない | 0.063秒 | [work-dry.json](work-dry.json) |
| `scripts/check.sh --level work --base 1d64e44c` | 0。一度実行して全選択単位が成功。spec_examples 7件、reference_examples 1件が成功し、失敗・ignored は各0件。仕様集計の自己検査が成功し、初回リリースの受け入れ条件の未記入は0件 | 32.024秒 | [work.json](work.json) |
| `python3 -` による文書の静的確認、初回 | Python の終了は0、確認結果の判定は1。コードをリンクと誤認し、install の inventory の大小文字を区別し、本文にない State という語まで要求した補助スクリプトの誤り | 0.216秒 | [document-check-initial.json](document-check-initial.json) |
| 同じ文書の静的確認、確認側を修正後 | 0。相対リンク・アンカー328件、フェンス・末尾空白・編集範囲、復元本文の同一性、対訳のコード100/11ブロック、install の移行事項、E0468 の生の出力との対応を確認 | 0.219秒 | [document-check.json](document-check.json) |
| `python3 -` による K2 の全入力の SHA-256 照合 | 0。4,449ファイルすべてが K2 時点と一致し、関係パスのバイナリ差分ハッシュも一致。未追跡入力なし | 0.265秒 | [k2-input-check.json](k2-input-check.json) |
| `git diff --check` と結果確定後の文書・状態確認 | 0。空白、相対リンク、記録内の手元の絶対パス、許可範囲外の編集に問題なし | 1秒未満 | [final-check.json](final-check.json) |

work の失敗はない。静的確認の初回の誤判定は、フェンスとインラインコードをリンク抽出から除外し、inventory の綴りを大小文字に依らず照合し、構築器のエフェクト契約の実際の説明を確認するよう直した。これを理由とする本文の変更はない。以後の編集は結果の記録だけであり、work が読む設計書とリファレンスの入力を変更していないので work を重ねない。

## 再実行しない検査と申し送り

K2・release_stack・実 CLI の照合は、処理系のソース・標準ソース・テスト入力・Lean・check-formal の道具を変更していないため、指示に従って再実行しない。今回変更した文書例の入力は work で検査する。元の記録は [Z1 の結果](../z1/results.md)、[K2 の入力状態](../z1/input-state-final.json)、[K2 の要約](../z1/k2-summary.json)、[実 CLI の観察記録](../z1/manual-cli-observations.json) にある。

K2 の入力の一致は、K2 の基準 `e0ed5eb2888349dbb0d251843627c527d7ffc0b0` の全 blob の SHA-256 に、保存済みの changedFiles を重ねて求めた期待値と、現行の全4,449ファイルを比較して確認した。K2 の関係パスの `git diff --binary e0ed5eb2888349dbb0d251843627c527d7ffc0b0 -- <関係パス>` の SHA-256 は、元の記録と同じ `8ca62ce9b1d5fdd34bbd70e6f9615b3d09b6c3144b6e195e7c637efa9203948c` である。元の全入力の集約ハッシュは `7da0ff460e10379663510d4908e02d8d010831c529a1b10c016d98796de1c866` であり、その対象となる各ファイルのハッシュに変更はない。照合の関係パスと現在の入力辞書の独立した集約ハッシュは [k2-input-check.json](k2-input-check.json) に残した。

元の K2 は `scripts/check-formal.sh` 全体、release は B0 を基準とした `release_stack` の10件、実 CLI は53呼び出しである。構成・ツールチェーン・件数・除外・終了状態・時間・環境の制限は [Z1 の検査と結果](../z1/results.md#検査と結果) と [K2 の最終の関係状態](../z1/results.md#k2-の最終の関係状態) に保存されている。今回の差分は文書と記録だけであり、関係状態が一致するため再実行しないと、Z1R 実装担当 Codex が2026-10-24に判断した。現在の HEAD・差分一覧・未コミット差分と未追跡記録の SHA-256 は [final-check.json](final-check.json) に保存する。

Z1R の計画からのずれはない。設計者の判断を要する停止事項、処理系の文言や入力を変える必要、未完了の担当検査はない。

委任範囲の受け入れは取りまとめが判断する。L6 の課題登録と、履歴の集約・タグ時の候補表示・ビルド情報・Skill producer の再照合も取りまとめへ引き渡す。

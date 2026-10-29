# S8b の根拠と点検

2026-10-27。対象文書は改造の study/language-rules.md。開始版3597b310、修正時のHEAD b0675576。RV-S8.md は変更していない。

| ファイル | 内容 |
|---|---|
| evidence.md、handlers.json、handlers.grep.txt | 14ファイルの検索範囲・件数・行と限界。全操作ハンドラとHttp.sendの節は0件 |
| handlers-all-current.grep.txt | docs/archiveを除く基準版の追跡ファイル全体の追加検索。翻訳と検討文書を分けて読む |
| before.json | HEAD・ブランチ・開始時の差分・RV-S8のハッシュ。S8初版の基準と3597b310、修正時HEADの設計書・Rust・Lean・検査スクリプトの差分が空である記録 |
| source-locations.md | 追加確認した19箇所のファイル・行と入力のSHA-256。新実装の実行結果ではない |
| external-sources.md | 外部の一次資料5件のURL・確認日・使う事実と限界 |
| time-budget.json | B6/C1のLean46〜110時間・220予約枠、処理系48〜118時間・236予約枠と、並行作業の算術 |
| verify_document.py、document-check.json | 問い14件と旧R番号の対応、指摘への対応表、リンクと見出し、用語、絶対パス、差分と変更範囲の静的な点検 |
| revise.py、revise_lean.py、revise_questions.py | 本文に順に適用した修正のスクリプト。修正前の節を前提とするため、適用済み本文へ再実行するものではない |

点検は `python3 work/m013/scratch/S8b/verify_document.py` で行う。このスクリプトが実行するgit操作は読み取り専用であり、記録の書き込み先はS8bの下に限る。

private配下とそこを指すスキルのリンクは読んでいない。cargo、checkスクリプト、Lean、LLM評価、状態を変えるgit操作は行っていない。文書の提案がビルド・実行で検証済みだとは扱わない。

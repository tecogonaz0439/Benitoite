# CHANGELOG の文案

CHANGELOG 本体は変更していない。H20 は README の DET-09 の決定に従い、追加した七操作と旧 send の完全性の事実を記す。以下の英文を V10.3a の最終編集へ渡す。移行手順・前後コード・移行例・性能の増減は含めない。

## H20: Added / Changed

- Added `File.readTextIn`, `File.readBytesIn`, `File.writeTextIn`, `File.appendTextIn`, `File.writeBytesIn`, `File.appendBytesIn`, and `Http.sendIn`. These operations use retained checked targets and carry their input types' target scopes in their effects.
- A handler with only an `Http.send` clause is a partial handler; `Http.Connect` remains unhandled because the effect also contains `Http.sendIn`.

## H21 の項目を外した理由

H21 の修正項目は文案から外した。50個・200個の完全ハンドラを含む lambda を後の節から呼ぶ Top の入力を再構成して調べたところ、公開 0.0.12 は両方を終了0・診断なしで受理した。現在版でも追加操作の節を含む完全ハンドラの形を受理した。[実行前の期待値](h21-reproduction/expectations.json)と[再現の結果](h21-reproduction/execution.json)を保存した。

0.0.12 の公開版ではこの拒否がなく、0.0.13 の開発の途中で入って直したものである。CHANGELOG は前の公開版との差を書くため、公開版の利用者が遭遇しなかった拒否の解消を Fixed として載せない。[レビューの取りまとめの判断](../reviews/RV-V10.2b.md#対応取りまとめ)に従った扱いであり、R20 の開発中の修正記録は維持する。

この編集案は新しい仕様の採否を求めるものではない。公開候補の CHANGELOG への反映・版の整合・最終の受け入れは V10.3a/c が受け持つ。

# S8b 外部の一次資料の再確認

確認日: 2026-10-27。webのopen/findで本文を確認した。OS・HTTP・新APIの実験は行っていない。

| 一次資料のURL | 本文に使う事実と確認位置 | 限界 |
|---|---|---|
| https://docs.scala-lang.org/sips/42.type.html | SIP-23 の型位置・Id[23] 等の型引数のリテラルの例 | Benitoiteの新構文の成功率を示さない |
| https://fstar-lang.org/papers/indexedeffects/indexedeffects.pdf | 冒頭でindexed monadsに基づく型とエフェクトの仕組みをF*で実装したと説明する | Benitoiteと同じ閉じたパス・ホストの文法の実装例とはしない |
| https://doc.rust-lang.org/std/fs/fn.canonicalize.html | 絶対化・リンク解決。Errorsに対象不存在等を挙げる。閲覧表示は1.99.1 | 固定版1.98.1や全OSでの最深親の解決は確認しない |
| https://www.rfc-editor.org/rfc/rfc3986 | §3.2.2のhostのIP-literal・IPv4address・reg-nameの区別と大小文字を区別しない規則 | Scopeのワイルドカードの規則を定める資料ではない |
| https://www.rfc-editor.org/rfc/rfc9110.html | §4.2.1・4.2.2のhttpの80・httpsの443、§4.3.1のoriginのscheme・host・portの組 | 新URL parserの規範への一致は未確認 |

訳語は今回の依頼とREADMEの設計者の決定に従った。非機密化（declassification）、エンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）を用い、新しい訳語の判断は加えていない。

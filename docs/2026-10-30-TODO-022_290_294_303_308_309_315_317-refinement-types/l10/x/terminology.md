# RV-L10.x 軽4の用語の照合

2026-11-01 に一次資料を照合した。日本語の定着した訳語を確認できない場合に原語か説明へ替えるという今回の依頼に従い、新しい訳語の選定は求めず、用語集から二つの見出し語を除いた。

| 以前の見出し語 | 確認できた呼び名と出典 | 採用した表記と理由 |
|---|---|---|
| 値の意味 | [Lau Skorstengaard, *An Introduction to Logical Relations*](https://cs.au.dk/~birke/papers/AnIntroductionToLogicalRelations.pdf), 2019-08-30。7.3節の value interpretation。型に対して値の述語を与える用途 | `ValueMeaning` という実際の判断名を使い、内容は説明する。今回の関数型などは上側近似なので、文献の完全な論理関係と同じと断定しない。「値の意味」を定着した訳語とする根拠は確認できなかった |
| 観測の情報の順序 | [Yue Niu, *Cost-sensitive programming, verification, and semantics*](https://www.cs.cmu.edu/~rwh/students/niu.pdf), 2024-09-30。第6章、本文72頁（PDFの87頁）の information order | 原語 information order を用い、今回の判断は `Observation.InfoLE` と明記する。「観測の情報の順序」を訳語として登録しない |

日本語の関連用例として、お茶の水女子大学の [平成25年度博士学位論文の本文](https://teapot.lib.ocha.ac.jp/record/41350/files/k_126_ri_honbun.pdf) の検索索引で、2.2節「λlet s/r と論理述語」に、強正規化性の証明に使う「論理述語」の用例を確認した。PDF本文の取得は503で失敗しており、確認の範囲は一次資料の索引の同節に限る。この用例は「値の意味」という訳語の根拠にはしない。日本語で「情報順序」「情報の順序」を領域理論の術語として採用するに足る一次資料は、今回の照合では確認できなかった。不存在を結論するものではない。

用語集には、取得できた英語の二つの一次資料を出典として直接記載した。01-12 の見出し「篩を読む網羅性と値の意味」の末尾は内容を説明する普通の表現であり、新語の定義とはしない。Lean の判断名、利用者の構文、提供範囲、主な定理の前提・結論は変えない。

# RV-IF20 への対応

2026-10-27、IF20.07。基準 B_WORK とソース読解対象の HEAD は `d94d970baca8b21c2d33a62f3380c3562fb0cc57` である。[レビュー原本](RV-IF20.md)と IF20.01〜.06 の結果記録は変更していない。以下は棚卸しの候補と記述の整合を直した記録であり、0.0.14 の規則を採択した記録ではない。

| 指摘 | 採った・採らなかった | 直したファイルと行の ID | 理由 |
|---|---|---|---|
| 中1 | 採った | [console-process.md](../inventory/console-process.md) E03、[failure-exit.md](../inventory/failure-exit.md) D11・件数表、[remaining-and-examples.md](../inventory/remaining-and-examples.md) 候補差表・補助経路集計 | E02 の入力分類を保ち、E03 と D11 を同じ報告の出口として「契約を設ける」にそろえた。D11 の方向も両方から出口へ変えた。生値がなくても位置・開始の有無・終了状態を観測できるためである |
| 中2 | 採った | [file.md](../inventory/file.md) 補助経路「解放の失敗の報告」「入力上限・引数・解放後使用による停止」、[remaining-and-examples.md](../inventory/remaining-and-examples.md)「枝によって候補が違う経路」 | 後の枝の S09・S13・S20 の契約、S10 の拒否を正とすることを明記した。File の初期候補は調査段階の記録として残し、延べ集計にも残す。資源の入口の拒否と、その失敗の報告の契約を分けるためである。中1・軽4 の組も同じ表へ載せた |
| 中3 | 第一案を採った。第二案は採らなかった | [file.md](../inventory/file.md) 欄の定義とその説明、[display-json-log.md](../inventory/display-json-log.md) C07〜C09・C11〜C14・C18・C19・C21・C22・C24・C25、[failure-exit.md](../inventory/failure-exit.md) S21・T13・D02〜D09・D12・H02・H03・H05、[remaining-and-examples.md](../inventory/remaining-and-examples.md) 候補差表の後の説明 | 出口の保守的は、材料の入力の結びを保ち、受け手の照合を IF30 へ送る意味とした。該当する出口全27行へ明記し、方向が両方の行の出口側も共通定義に従う。材料の分類の不足と、受け手の契約の不足を分けて残せるため、出口を別候補へ変えて材料の分類を入口行へ移す第二案は採らない。この指摘による件数変更はない |
| 軽4 | 採った（本文で参照する案） | [display-json-log.md](../inventory/display-json-log.md) C29、[remaining-and-examples.md](../inventory/remaining-and-examples.md) 候補差表 | 捕捉した内容は H03 の保守的、捕捉外は H09 の未確認を正とした。C29 は捕捉外を含む総括行として残し、内訳の候補を一律に未確認へ戻さない。行を二分しないため延べ件数は変わらない |
| 軽5 | 採った | [failure-exit.md](../inventory/failure-exit.md) A01〜A03 | `evaluate` は成立時に Passed を返すだけであり、成功の報告はテスト単位の T10 へ反映される。A02 も同じ誤読を避けるため表現をそろえた |
| 軽6 | 採った | [remaining-and-examples.md](../inventory/remaining-and-examples.md) EX01〜EX03・EX07・EX08 | EX07 の入口と出口を行の方向どおりに並べ直し、X22 は入口側だけに置いた。EX03 と、同じ構造の EX01 の S01 等は入口を成否として参照する注記を加えた。EX02 に送信の H05 と NetworkError の入口 S02 を加えた |
| 軽7 | 採った | [display-json-log.md](../inventory/display-json-log.md) D037・D038・D043〜D046・D094・D097〜D104 | 大文字小文字の変換と表示幅の空白補充を、関数ごとに書き分けた。Log の既定 stderr、Debug の破棄、外側への再送、Console の stderr、任意の sink の別を記し、D101 の純粋な整形とも分けた |
| 軽8 | 採った | [console-process.md](../inventory/console-process.md) X04・X22・X23、[file.md](../inventory/file.md) U-F04、[http.md](../inventory/http.md) U-H05・U-H06、[display-json-log.md](../inventory/display-json-log.md) P31・P32・U-D04、[failure-exit.md](../inventory/failure-exit.md) U-FE04、[remaining-and-examples.md](../inventory/remaining-and-examples.md) E02・E03・前枝の申し送り・U-R01・U-R02・U-R05・U-R06 | 未登録の略記を情報フロー制御へ直した。実行の比較を表す14か所は「二つの実行」とし、各文書の初出に比較対象である説明を添えた。IFC-D など既存の問いの ID は維持した |
| 軽9 | 採った | [remaining-and-examples.md](../inventory/remaining-and-examples.md) G03 | 位置へ STRING_OPERATIONS・LIST_OPERATIONS・BYTES_OPERATIONS を記し、文字列以外の構築器も一般の派生の範囲に含むことを明示した |

九件のうち対応を見送った指摘はない。中3 は二つの代案のうち第一案を選び、軽4 は本文で参照する案を選んだ。

確かめないと分からない二点も、[ソース読解の補足](../if20.07/source-findings.md)へ記録した。F24 の通常の待ち完了値は `Result.Ok(())` と読解できた。取り消し・停止との競合や特殊な環境の実挙動と、U-F02・U-H04・U-CP04・U-D02・U-FE03 の全文は未確認として残す。[結果と件数](../if20.07/results.md)を参照する。

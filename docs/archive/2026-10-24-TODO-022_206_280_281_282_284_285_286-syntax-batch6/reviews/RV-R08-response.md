# RV-R08 への対応（R08R）

2026-10-24。判断の正は README の設計者の決定と decisions.md の D7・D9〜D14、および今回の取りまとめの方針である。

| 所見 | 対応 | 直した箇所 |
|---|---|---|
| 中1 | S-R1 の証拠を R08 の直接実行22件に統一した。基準・HEAD と、stage の入口・dry-run を通していないが同じ単位・コマンドであることを明記した | [集約結果](../results.md)「stage S-R1」「stage と独立レビューへの引き渡し」、[R08 の結果](../r08/results.md)「計画からのずれと申し送り」 |
| 中2 | 現行の説明を生成器 `3.1.0-syntax-batch5`・inventory 版3へ訂正し、06-06 に JSON/Property の事前拒否を補った。git grep で現行説明と過去の移行節を区別し、後者の旧版は保持した。Z01a の訳の確認も申し送った | [06-06](../../../design/06-tooling/06-06-agent-skills.md#実行の前の確認)、[03-08](../../../design/03-interop/03-08-text-and-data.md#レコードのproperty生成器)、集約結果・R08 の結果の訳の申し送り |
| 中3 | 06-09 の derive 節を削除し、対処・同じ生成器版でも旧 manifest を拒否しうる注意・旧道具の保存を03-06へ統合した。版と復旧の既存の決定は重ねていない。参照を git grep で確認し、削除節を案内する箇所を直した。06-09 の目的と範囲は保持した | [03-06](../../../design/03-interop/03-06-stdlib.md#外部生成の管理と照合)、[06-09](../../../design/06-tooling/06-09-packages.md)、集約結果、[レビュー依頼](RV-R08-request.md)、[R04 の結果](../r04/results.md)。Skill・英語リファレンス・道具の README に削除節への参照はなかった |
| 中4 | JSON/Property の既存署名表でカスタム関数を別の Custom モジュールに置き、ファイル単位の `uses Log` を合併した署名を `custom .*must be pure` で拒否することと非書き込みを検査する。対象側は純粋に保ち、事前拒否の表と役割を分けた。各表のコメントに契約・退行・既存行との差・本番の差し込み口不要を記した | [derive 自己検査](../../../../tools/derive/test_derive.py) の JsonGeneration / PropertyGeneration の既存署名表 |
| 軽1 | 0.0.9 の行へ language 宣言・依存のハッシュの見直しを戻した。表の後の説明を text.rs の案内に合わせ、更新を促す版・見直す版・促さない版を書き分けた | [06-09](../../../design/06-tooling/06-09-packages.md#設定ファイルの検査) |
| 軽2 | `format_record` に報告名を渡し、公開関数は `Log.formatRecord`、既定 emit は従来の `Log.emit` とした。withTextLogger は公開の `formatRecord` を呼ぶので、その上限超過も `Log.formatRecord` と報告する（担当は非公開の入口 formatTextRecord を足して従来の `Log.emit` を保ったが、1 GiB を超える場合の報告名のために組み込みの表を広げないよう、取りまとめが追加を戻した）。整形処理は共通のままである | [log.rs](../../../../crates/benitoite/src/builtins/funcs/log.rs) |
| 軽3 | TypeGraph 構築の並べ替えと、拒否する入力の報告順だけが変わることを追記した | [R02 の結果](../r02/results.md) |
| 軽4 | 指示代名詞を “The derive tool's declaration inventory” に替えた。Z01a の同期へ申し送った | [SKILL.md](../../../../crates/benitoite/skill/SKILL.md)、集約結果・R08 の結果 |
| 軽5 | 二つの一時スクリプトのパスを `<tmp>/...` に伏せ、保存していないことを明記した | [R03 の結果](../r03/results.md)、[R04 の結果](../r04/results.md) |
| 軽6 | 03-07 の二段落を標準 JSON 形式なし・Log の Json 非依存・実行時の許可と事前の上限確認に絞り、例の内容は英語リファレンスの節へ参照した | [03-07](../../../design/03-interop/03-07-io-modules.md#log-と-sourcelocation) |

軽2では test-audit の作成時の関門を確認した。文字列上限の診断名は独立した契約だが、既存の StrBuf に上限を小さくする仕組みはない。1 GiB の入力やテスト専用の本番の差し込み口は追加せず、既存の lib と文書例・Log の交換テストで通常の経路を確認する。

derive 自己検査49件、関連統合50件と、lib 全件の確認を完了した。初回 work で登録表の固定件数が古く1件失敗したが、修正後の局所再検査と残りの work 単位はすべて成功した。検査のコマンド・終了状態・外側の時間と計画との差は [R08R の結果](../r08r/results.md)に記録した。日本語訳の同期は計画どおり Z01a、取り込みと段の受け入れは取りまとめの担当である。

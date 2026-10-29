# H28: 取りまとめに渡す複写・所在確認

2026-10-30。次の固定名22ファイルの写しが必要である。加えて4ディレクトリと1ワイルドカードの内容を取りまとめが棚卸しする。これらの集合は固定名の行と重なるため、足して総ファイル数とはしない。指定した旧 scratch と remote のディレクトリはこの作業ディレクトリには存在しない。外部原本は読まず、改造内の保存物だけと照合した。private と docs/todo は読んでいない。

| 元のパス | 要る理由 | 最初の参照元（基準時） |
|---|---|---|
| [`work/m013/scratch/P1b/verify_documents.py`（写し）](../evidence/work-copies/m013/scratch/P1b/verify_documents.py) | WP-01bのリンク・判断21件・細則9件・母集団と書込み範囲の静的点検を再現する台本が必要である | `evidence/P1b/results.md:13` |
| [`work/m013/scratch/P1b/`（写し）](../evidence/work-copies/m013/scratch/P1b/) | 当該段が本文で根拠・検索結果・取得資料・開始状態の保存先として引く集合である。既存の写しを除く個別ファイルの一覧を取りまとめが確定する | `evidence/P1b/results.md:17` |
| `work/scratch/IF10.04/dry-run.json` | 同所のdry-run.logを補う正確なコマンド・開始終了・終了状態・外側時間の記録が必要である | `if10.04/results.md:43` |
| `work/scratch/IF10.05/dry-run.json` | 同所のdry-run.logを補う正確なコマンド・開始終了・終了状態・外側時間の記録が必要である | `if10.05/results.md:43` |
| `work/scratch/IF10.06/dry-run.json` | 同所のdry-run.logを補う正確なコマンド・開始終了・終了状態・外側時間の記録が必要である | `if10.06/results.md:45` |
| `work/scratch/IF10.07/dry-run.json` | 同所のdry-run.logを補う正確なコマンド・開始終了・終了状態・外側時間の記録が必要である | `if10.07/results.md:47` |
| `work/scratch/IF10.08/dry-run.json` | 同所のdry-run.logを補う正確なコマンド・開始終了・終了状態・外側時間の記録が必要である | `if10.08/results.md:49` |
| [`work/m013/remote-lean.sh`（写し）](../evidence/work-copies/m013/remote-lean.sh) | 別機へ送った入力とLeanの起動・メモリ上限・時間制限・出力採取の条件を同定する台本が必要である | `spikes/SA/findings.md:205` |
| [`work/m013/spike-common.md`（写し）](../evidence/work-copies/m013/spike-common.md) | 各独立試作が従った共通条件・仮定・禁止範囲を元のハッシュで確かめるため必要である | `spikes/SA/provenance.json:4` |
| [`work/m013/remote/run-lean.sh`（写し）](../evidence/work-copies/m013/remote/run-lean.sh) | 別機側の実際のLean起動と終了・ログ採取を、呼出し側の記録から分けて保全する必要がある | `spikes/SA/provenance.json:13` |
| [`work/m013/scratch/S1/`（写し）](../evidence/work-copies/m013/scratch/S1/) | 当該段が本文で根拠・検索結果・取得資料・開始状態の保存先として引く集合である。既存の写しを除く個別ファイルの一覧を取りまとめが確定する | `study/higher-order-effects.md:859` |
| [`work/m013/scratch/S8b/`（写し）](../evidence/work-copies/m013/scratch/S8b/) | 当該段が本文で根拠・検索結果・取得資料・開始状態の保存先として引く集合である。既存の写しを除く個別ファイルの一覧を取りまとめが確定する | `study/language-rules.md:15` |
| [`work/m013/scratch/S9/baseline.json`（写し）](../evidence/work-copies/m013/scratch/S9/baseline.json) | S9の開始HEADと設計書・Rust・Lean・検査台本に差がないという本文の根拠が必要である | `study/language-rules.md:15` |
| [`work/m013/scratch/S9/`（写し）](../evidence/work-copies/m013/scratch/S9/) | 当該段が本文で根拠・検索結果・取得資料・開始状態の保存先として引く集合である。既存の写しを除く個別ファイルの一覧を取りまとめが確定する | `study/language-rules.md:15` |
| [`work/m013/scratch/S9/ip-research.md`（写し）](../evidence/work-copies/m013/scratch/S9/ip-research.md) | IP/CIDR・zone ID等の細則を確認した一次資料の節・事実・確認日の対応が必要である | `study/language-rules.md:126` |
| [`work/m013/scratch/S8b/evidence.md`（写し）](../evidence/work-copies/m013/scratch/S8b/evidence.md) | 14ファイルのハンドラ検索・実行可能件数と翻訳/検討文書の別集計の範囲・検索式・位置が必要である | `study/language-rules.md:399` |
| [`work/m013/scratch/S9/time-budget.json`（写し）](../evidence/work-copies/m013/scratch/S9/time-budget.json) | 30〜60分枠への換算・予約番号の算術と旧表との差を再確認するため必要である | `study/language-rules.md:601` |
| [`work/m013/scratch/S9/q9-lean-inventory.py`（写し）](../evidence/work-copies/m013/scratch/S9/q9-lean-inventory.py) | 利用者エフェクトの棚卸しの母集団・入力ハッシュ・宣言別位置・検索式と生結果を一組で保全するため必要である | `study/user-effect-scopes.md:194` |
| [`work/m013/scratch/S9/q9-lean-inventory.json`（写し）](../evidence/work-copies/m013/scratch/S9/q9-lean-inventory.json.gz) | 利用者エフェクトの棚卸しの母集団・入力ハッシュ・宣言別位置・検索式と生結果を一組で保全するため必要である | `study/user-effect-scopes.md:194` |
| [`work/m013/scratch/S9/q9-lean-inventory.md`（写し）](../evidence/work-copies/m013/scratch/S9/q9-lean-inventory.md) | 利用者エフェクトの棚卸しの母集団・入力ハッシュ・宣言別位置・検索式と生結果を一組で保全するため必要である | `study/user-effect-scopes.md:194` |
| `work/m013/scratch/S9/q9-lean-*.grep.txt` | 利用者エフェクトの棚卸しの母集団・入力ハッシュ・宣言別位置・検索式と生結果を一組で保全するため必要である | `study/user-effect-scopes.md:194` |

| [`work/m013/TODO-283_287-permission-and-effect-mechanisms/study/synthesis.md`（写し）](../evidence/work-copies/m013/TODO-283_287-permission-and-effect-mechanisms/study/synthesis.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `bf134c4d30ee910b8dd3876416dcded431b298bd080da8a1d243c558e4370312` と一致しない。当時の内容を保全するため | `spikes/SK/provenance.json` |
| [`work/m013/TODO-283_287-permission-and-effect-mechanisms/study/targets-and-capabilities.md`（写し）](../evidence/work-copies/m013/TODO-283_287-permission-and-effect-mechanisms/study/targets-and-capabilities.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `a2f32e1ae409fc642b962873f3827e7cf90777ec01baf4519572532c7f1e08b3` と一致しない。当時の内容を保全するため | `spikes/SA/provenance.json` |
| [`work/m013/spikes/SG/findings.md`（写し）](../evidence/work-copies/m013/spikes/SG/findings.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `35415441528bbdf5047e5432548151d348347a023494745c01ac47fea176daf3` と一致しない。当時の内容を保全するため | `spikes/SD/provenance.json` |
| [`work/m013/spikes/SF/findings.md`（写し）](../evidence/work-copies/m013/spikes/SF/findings.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `38f5f79dad5e0ad86ec1673c0adffd302bb85530bb4ebb810ce7157ee21812ed` と一致しない。当時の内容を保全するため | `spikes/SD/provenance.json` |
| [`work/m013/TODO-283_287-permission-and-effect-mechanisms/study/questions.md`（写し）](../evidence/work-copies/m013/TODO-283_287-permission-and-effect-mechanisms/study/questions.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `e433d0d830e4b414681afacc700449738889bbff9024f2bb93f54cb48322b1d7` と一致しない。当時の内容を保全するため | `spikes/SD/provenance.json` |
| [`work/m013/TODO-283_287-permission-and-effect-mechanisms/study/information-flow-generality.md`（写し）](../evidence/work-copies/m013/TODO-283_287-permission-and-effect-mechanisms/study/information-flow-generality.md) | 改造内の同名文書は後の版であり、来歴のSHA-256 `f8142e4923249f037406b9bddd99cf917984a0fb1795787e15e2b839d61c2af1` と一致しない。当時の内容を保全するため | `spikes/SD/provenance.json` |
実際の新しい保存先が定まるまで旧パスの来歴を残す。S8 の63件の複写は保存済みハッシュと照合し、一覧・台本・結果は相対リンクへ対応付けた。出力先だけの `reproduced/` や古い書き込み範囲は複写対象に数えない。README末尾の広い案内にあった共通条件は `spike-common.md`、実行器は二つの remote 台本として個別に挙げた。依頼文の全件保存の要否と、ディレクトリ内の追加記録の取捨は取りまとめが前提の欠落を確かめて決める。

外部へ移した137単位・二つのレビュー生記録は [V10.1ab の照合](../v10.1a/results.md#v101ab-の外部保管記録の確認)を引き継ぐ。恒久保管先の決定・外部原本との再照合は未確認であり、本作業で保管完了にはしない。担当・モデルの名前は過去の役割の記録として一括削除せず、公開前に取りまとめが固有名の扱いを点検する。

[来歴のハッシュの照合](h28-provenance-check.json)は開始版のファイル内容に対して行った。今回のリンク追記による差と、開始時から異なっていた内容を分けた。同名の後の文書へのリンクは現在の参照先であり、当時の原本と同一という証拠ではない。

## 取りまとめの複写（2026-10-30）

取りまとめが上の一覧の固定名とディレクトリを本線の `work/` から [evidence/work-copies/](../evidence/work-copies/README.md) へ写し、改造の Markdown の文書が逆引用符で引いていた35か所（7文書）を写しへの相対リンクに直した。`work/scratch/IF10.04/`〜`IF10.08/` の `dry-run.json` の5件は `work/` に残っておらず、写せなかった（同所の dry-run.log と results.md の記録は残る）。第三者の Web ページの HTML・ライブラリのソースと README、2 MB の `P1b/start.json` は写さず、大きさと SHA-256 を残した。論文の PDF の5件は、設計者の指示（2026-10-30）で写した。来歴の JSON（provenance.json など）が記録する元のパスとハッシュは、当時の記録として書き換えていない。

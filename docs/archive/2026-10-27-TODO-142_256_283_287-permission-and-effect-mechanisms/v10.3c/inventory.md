# 0.0.13 の候補一覧の照合

2026-10-30 JST。候補は `5de2594ad523fba4f38fa63f7a1b306e8a23eb0c` である。[照合結果と全入力ハッシュ](inventory-audit.json)、[読取り用の照合台本](audit-inventory.py)、[Skill 全件の照合](skill-audit.json)を保存した。候補のソースを変更せず、生成器を起動して追跡ファイルを書き直す操作もしていない。

| 対象 | 照合した内容 | 結果 |
|---|---|---|
| 処理系の版 | `crates/benitoite/Cargo.toml`、実 CLI の `--version=json` | ともに0.0.13 |
| 二つの lock | `Cargo.lock` と `fuzz/Cargo.lock` の benitoite 項目 | 各一つ、0.0.13。R の照合の前後で全文ハッシュ一致。一般の依存更新なし |
| README | 現在版、CHANGELOG のリンク、配布形態 | 0.0.13、リンク先の見出しあり。ソースだけを配布し、実行ファイルは0.1.0からと明記 |
| CHANGELOG | 0.0.13 の事実とREADMEのJ2訂正 | 七操作、File.Read 13・File.Write 16・Http.Connect 2、旧操作だけのハンドラの部分性、IP/CIDR、報告の bounds、宣言情報と意味ハッシュ版4、言語版の境界に一致。今回分に移行案内・例・性能増減なし |
| 英語のリファレンスと導入文書 | `docs/reference/benitoite.md`・`install.md` | 現在版0.0.13。導入文書は0.0.13の実行ファイルのアーカイブとSHA256SUMSを提供しないと明記 |
| 日本語訳 | リファレンス2件、Skill本文と手書き参照4件の計7組 | 翻訳元0.0.13。V10.3aの独立対照後の英日全文ハッシュが全件一致し、同対照の252組のコードフェンス・14出現の版固定URLの証拠を引用できる。日本語を同梱Skillへ加えていない |
| 同梱のSkill | 全73論理名、索引、物理ファイル、許諾本文、producer、byteLength、contentHash | 列挙漏れ0・余分0・重複0、全件の本文とSHA-256一致。`SKILL.md`だけ版の印を0.0.13へ置換して比較。他の文書はバイト一致 |
| 生成物 | grammar・diagnostics・stdlibの生成文書66件とbundle索引1件、計67件 | V10.3aの生成後のハッシュに全件一致。生成元・生成器もF-Qの関係状態と一致し、changeのskill_generated成功を引用。診断文書のE0908の説明は三効果の事実に一致 |
| 許諾一覧 | `scripts/release/about.toml`のacceptedと`deny.toml`のallow | 7種を順序まで一致確認。MIT、Apache-2.0、ISC、BSD-3-Clause、Apache-2.0 WITH LLVM-exception、Zlib、Unicode-3.0 |
| 本体とSkillのライセンス | ルートのMIT・Apache-2.0、Cargoのworkspaceライセンス、Skillに埋め込む二本文 | 二重ライセンスの表示と本文が一致。許諾一覧自体に製品版の数字を付ける必要はない。依存のlicenses検査はchangeの成功を引用 |
| ソースだけの配布 | 候補の追跡木と英語・訳・README・CHANGELOGの記述 | 追跡21,026ファイル。private/・docs/todo/・reference/・work/・target/の収録0件。実際のソースarchiveは作成していない。集約・タグ後の正式出力はV10.3eの担当 |

古い版の変更履歴、最小実行版のリファレンス、既存必須欄を指すv0.0.12の固定参照は、現在版の表示とは区別して保つ。まだ作成していないv0.0.13タグのURLを取得済みとはしていない。ソースをビルドして確認した今回の実行ファイルを、配布済みの実行ファイルとして扱わない。

生成物の鮮度と文書例の実行は、[三回目のchange](../v10.1c/results.md#三回目の-change取りまとめ2026-10-30)のskill_generatedとtest_default_all等の成功を引用する。候補までの差分はテストの期待値2件と記録であり、通常文書・訳・生成元・生成物・依存はその検査後に変わっていない（[関係状態](relation-audit.json)）。本作業はその回帰全件を反復していない。

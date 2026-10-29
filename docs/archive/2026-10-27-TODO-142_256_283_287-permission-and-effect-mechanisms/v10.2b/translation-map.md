# 英語の変更と日本語訳の対応

日本語訳は変更していない。英語7ファイルの20箇所を次表へ対応付けた。同一ファイルの同一見出しを一箇所とし、空行だけの差を除く。新しい見出し5件は既存の訳に対応節がないため、新設位置と訳の見出し案を示す。翻訳と訳元の版の更新は V10.3a が行う。既存の見出しは開始版の英日順序と実際の見出し名を照合した。[対応の JSON](translation-map.json) に英語・日本語のパスと見出しを保存した。

| 英語のファイル | 日本語のファイル | 箇所数 |
|---|---|---:|
| `docs/reference/benitoite.md` | `docs/ja/reference/benitoite.md` | 12 |
| `docs/reference/install.md` | `docs/ja/reference/install.md` | 1 |
| `crates/benitoite/skill/SKILL.md` | `docs/ja/skill/SKILL.md` | 2 |
| `crates/benitoite/skill/references/inspection.md` | `docs/ja/skill/references/inspection.md` | 1 |
| `crates/benitoite/skill/references/idioms.md` | `docs/ja/skill/references/idioms.md` | 2 |
| `crates/benitoite/skill/references/common-mistakes.md` | `docs/ja/skill/references/common-mistakes.md` | 1 |
| `crates/benitoite/skill/references/language-comparison.md` | `docs/ja/skill/references/language-comparison.md` | 1 |

| ファイル | 英語の見出し | 対応する日本語の見出し・追加位置 |
|---|---|---|
| reference/benitoite | Benitoite Language Reference | Benitoite 言語リファレンス（冒頭） |
| 同上 | Inspection reports | 検査報告 |
| 同上 | Declared target bounds | 新設。検査報告の後、区間解析の検査範囲の前。見出し案「宣言した対象の上限」 |
| 同上 | Effect limits before execution | 実行前のエフェクトの上限 |
| 同上 | 8. Constants and type aliases | 8. 定数と型の別名 |
| 同上 | 10. Effects | 10. エフェクト |
| 同上 | Scoped effects | 新設。10. エフェクト内、ファイル単位のエフェクトの宣言の前。見出し案「範囲付きのエフェクト」 |
| 同上 | Complete and partial handlers | 新設。11. エフェクトハンドラ内。見出し案「完全ハンドラと部分ハンドラ」 |
| 同上 | Record generators and shrinkers | レコードの生成器と縮小器 |
| 同上 | Scope | Scope |
| 同上 | Scoped values and IO | 新設。Scope の後。見出し案「範囲付きの値と IO」 |
| 同上 | Checked HTTP requests | 新設。範囲付きの値と IO の下。見出し案「検査済みの HTTP 要求」 |
| reference/install | 3. Install the Agent Skill | 3. Agent Skill をインストールする |
| skill/SKILL | Checked values and local builders | 検査済みの値と局所の構築器 |
| 同上 | Reference documents | 参照の文書 |
| skill/references/inspection | Inspecting before execution | 実行前の検査 |
| skill/references/idioms | HTTP | HTTP |
| 同上 | Writing tests | テストの書き方 |
| skill/references/common-mistakes | Treating a checked scope as permission | 検査済みの Scope を権限と見なす |
| skill/references/language-comparison | Functions | 関数 |

reference の新設例（PathIn の検査・射影・明示拡大・狭い入力の IO 転送、RequestCheckError の match）と idioms の既存 HTTP 例への match 関数追加を、コードとフェンスの検査モードを保って訳す。型・引数名・文字列と期待出力を一緒に照合する。

固定参照の14出現は [固定参照表](pinned-references.md) と対にする。既存必須欄・区間解析の旧版リンクを機械的に新しい版へ変えない。候補の6見出しを指す新しい10出現は、対応する訳にも同じ英語の固定 URL を使う。

製品版の表示、導入の現在版、三つの language 宣言の実行例、訳元の表示は変更していない。[版の棚卸し](../v10.1b/j2-rewrite-inventory.md#文書の例) の区分に従い V10.3a が扱う。過去の移行節や旧版を狙う説明は一括置換しない。

生成参照66ファイル（文法・診断・標準ライブラリ）には対応する日本語訳がない。再生成は内容差分0件であり、訳を新設しない。全出力の SHA-256 と生成元の一致は [生成物の照合](generated-audit.json) に記録する。日本語を同梱 Skill に加えていない。

## レビュー後の訳への追補

V10.3a の訳でも、reference「Record generators and shrinkers」と Skill「Reference documents」から、旧ツールで保留中の apply/recovery を終える文、旧本文のハッシュを照合する文、apply 後に通常の check/test と derive check を行う文を消す。英語での削除は `tools/derive/README.md` との重複を避けるための意図した削除である。

Functions の比較表は assert の行まで一つの表とし、範囲付き IO の段落を表の後に置く。inspection の参照は候補という段階の語を使わず v0.0.13 と書く。reference の File.Write の操作列は宣言順にそろえ、Skill の埋め込み文書の説明は文法・診断・標準ライブラリの参照に限定する。これらも同じ見出しの訳へ反映する。

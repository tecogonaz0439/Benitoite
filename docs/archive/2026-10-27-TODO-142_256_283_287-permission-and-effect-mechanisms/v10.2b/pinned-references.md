# 固定参照の照合

候補の新しい契約は `v0.0.13` に固定した。ローカルの同名タグは存在せず、タグの取得・公開先の到達を確認したとは扱わない。対応する作業ツリーの見出しと本文を照合した。既存必須欄と区間解析だけを指す `v0.0.12` はローカルタグの本文を照合し、意味を保って残した。版表示や language 宣言の更新とは区別する。見出しの改名・削除はない。

| 参照元（リポジトリ相対） | 固定版 | 見出し・契約 | 照合した状態 |
|---|---|---|---|
| `crates/benitoite/skill/SKILL.md:65` | `v0.0.12` | Inspection reports (`#inspection-reports`) | 既存タグ |
| `crates/benitoite/skill/SKILL.md:168` | `v0.0.13` | Scoped effects (`#scoped-effects`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/SKILL.md:168` | `v0.0.13` | Scoped values and IO (`#scoped-values-and-io`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/SKILL.md:176` | `v0.0.13` | Complete and partial handlers (`#complete-and-partial-handlers`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/inspection.md:42` | `v0.0.13` | Declared target bounds (`#declared-target-bounds`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/inspection.md:42` | `v0.0.13` | Scoped effects (`#scoped-effects`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/inspection.md:52` | `v0.0.12` | Inspection reports (`#inspection-reports`) | 既存タグ |
| `crates/benitoite/skill/references/inspection.md:127` | `v0.0.12` | Interval analysis coverage (`#interval-analysis-coverage`) | 既存タグ |
| `crates/benitoite/skill/references/inspection.md:127` | `v0.0.12` | Local interval warnings (`#local-interval-warnings`) | 既存タグ |
| `crates/benitoite/skill/references/idioms.md:558` | `v0.0.13` | Checked HTTP requests (`#checked-http-requests`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/idioms.md:756` | `v0.0.13` | Complete and partial handlers (`#complete-and-partial-handlers`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/common-mistakes.md:550` | `v0.0.13` | Scope (`#scope`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/common-mistakes.md:550` | `v0.0.13` | Scoped values and IO (`#scoped-values-and-io`) | 候補の作業ツリー（タグなし） |
| `crates/benitoite/skill/references/language-comparison.md:159` | `v0.0.13` | Scoped values and IO (`#scoped-values-and-io`) | 候補の作業ツリー（タグなし） |

リンクの出現は14件、固定版・パス・見出しの組は9件である。各本文の SHA-256 と既存タグの完全 ID は [pinned-references.json](pinned-references.json) に保存した。

既存タグの Inspection reports は checkReport 1・testCheckReport 1/2 の必須欄と受け入れ規則だけを引く。Interval analysis coverage・Local interval warnings も区間解析の説明だけを引く。bounds・範囲の構文・六純粋宣言と七 IO・ハンドラの完全性・IP/CIDR・要求の検査は候補の対応する見出しを引く。

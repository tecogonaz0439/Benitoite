# H28: 元の検索全行の分類

2026-10-30。基準は `03ad23bef73ab265cdced5336e6b9f21ce7b7166`。検索は編集前の追跡木に対して一度採取し、全1,607行を排他的に分類した。一行に複数の種類がある場合は実際の根拠参照 d を優先する。生の長い JSON の行も省略せず、[JSON](h28-references.json)に元の行番号と行本文の SHA-256 を残した。全文は基準の追跡木から復元できる。表の F 番号は下のファイル対応表による。以後に加えた本棚卸し自体は母集団へ再帰的に含めない。

| 分類 | 内容 | 行数 |
|---|---|---:|
| a | 別の語の一部 | 753 |
| b | 通常の文書のパス | 657 |
| c | 禁止・運用・来歴の記述 | 42 |
| d | 実際の入力・根拠・保存物の参照 | 155 |

## 対応と不足

[詳細](h28-reference-details.json)に d の参照先と写しの有無を列挙した。[既存複写63件](h28-existing-copies.json)は保存済み sanitized SHA-256 と全件一致した。元の source の文字列は来歴として残す。機械の記録・過去の実行コマンド・ハッシュは書き換えず、本文の参照を現在の写しへ結んだ。

| 修正した文書 | 内容 |
|---|---|
| [README.md](../README.md) | 末尾の旧作業領域への案内を受け入れ材料と不足資料の一覧への相対リンクへ置換。決定は全件保持 |
| [evidence/README.md](../evidence/README.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [reviews/RV-P1.md](../reviews/RV-P1.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [spikes/SA/findings.md](../spikes/SA/findings.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [spikes/SB/findings.md](../spikes/SB/findings.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [spikes/SK/findings.md](../spikes/SK/findings.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [study/language-rules.md](../study/language-rules.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |
| [study/synthesis.md](../study/synthesis.md) | 過去の配置・コマンドを保持し、保管した写しの相対リンクを併記 |

複写が必要な固定名は22ファイル、ほかに4ディレクトリと1ワイルドカードの棚卸しが残る。総ファイル数は未確定である。

[試作の来歴ハッシュ](h28-provenance-check.json)を開始版と照合したところ、同名の現在文書と異なる6原本があった。現在の文書へのリンクと当時の同一内容の複写を分け、複写不足へ加えた。

## 担当・モデルの名前の点検

RV-V10.1a軽4の保管前点検として、改造内Markdown本文（本棚卸しを除く）の担当・モデル名を検索し、119行を [一覧](h28-author-names.json)に残した。役割・独立レビュー・検査環境の来歴を表すものがあるため一括削除しない。固有名の公開可否は取りまとめが確認する。

## ファイル対応表

| 番号 | 基準時のパス（改造内） |
|---|---|
| F000 | `README.md` |
| F001 | `evidence/P1/dry_runs.py` |
| F002 | `evidence/P1b/results.md` |
| F003 | `evidence/README.md` |
| F004 | `evidence/copy-manifest.json` |
| F005 | `evidence/reproduce.py` |
| F006 | `if10.04/results.md` |
| F007 | `if10.05/results.md` |
| F008 | `if10.06/results.md` |
| F009 | `if10.07/results.md` |
| F010 | `if10.08/results.md` |
| F011 | `if20.02/results.md` |
| F012 | `if20.04/operations.json` |
| F013 | `if20.04/pathways.json` |
| F014 | `if20.04/results.md` |
| F015 | `if20.05/results.md` |
| F016 | `if20.06/results.md` |
| F017 | `if20.07/results.md` |
| F018 | `inventory/display-json-log.md` |
| F019 | `inventory/http.md` |
| F020 | `k10.2/k10.2b-known-comparison/nul-direct.log` |
| F021 | `k10.2/k10.2b-known-comparison/nul-dynamic.log` |
| F022 | `k10.2/k10.2b-rejections-second.log` |
| F023 | `k10.2/k10.2b-source-comparison/report-subset/connect-complete-check.log` |
| F024 | `k10.2/k10.2b-source-comparison/report-subset/connect-complete-test.log` |
| F025 | `k10.2/k10.2b-source-comparison/report-subset/connect-missing-upper-check.log` |
| F026 | `k10.2/k10.2b-source-comparison/report-subset/connect-missing-upper-test.log` |
| F027 | `k10.2/k10.2b-source-comparison/report-subset/connect-partial-check.log` |
| F028 | `k10.2/k10.2b-source-comparison/report-subset/connect-partial-test.log` |
| F029 | `k10.2/k10.2b-source-comparison/report-subset/non-top-check.log` |
| F030 | `k10.2/k10.2b-source-comparison/report-subset/non-top-test.log` |
| F031 | `k10.2/k10.2b-source-comparison/report-subset/pure-check.log` |
| F032 | `k10.2/k10.2b-source-comparison/report-subset/pure-test.log` |
| F033 | `k10.2/k10.2b-source-comparison/report-subset/read-complete-check.log` |
| F034 | `k10.2/k10.2b-source-comparison/report-subset/read-complete-test.log` |
| F035 | `k10.2/k10.2b-source-comparison/report-subset/read-missing-upper-check.log` |
| F036 | `k10.2/k10.2b-source-comparison/report-subset/read-missing-upper-test.log` |
| F037 | `k10.2/k10.2b-source-comparison/report-subset/read-partial-check.log` |
| F038 | `k10.2/k10.2b-source-comparison/report-subset/read-partial-test.log` |
| F039 | `k10.2/k10.2b-source-comparison/report-subset/redundant-check.log` |
| F040 | `k10.2/k10.2b-source-comparison/report-subset/redundant-test.log` |
| F041 | `k10.2/k10.2b-source-comparison/report-subset/show-match-check.log` |
| F042 | `k10.2/k10.2b-source-comparison/report-subset/show-match-test.log` |
| F043 | `k10.2/k10.2b-source-comparison/report-subset/show-rejected-check.log` |
| F044 | `k10.2/k10.2b-source-comparison/report-subset/show-rejected-test.log` |
| F045 | `k10.2/k10.2b-source-comparison/report-subset/top-check.log` |
| F046 | `k10.2/k10.2b-source-comparison/report-subset/top-test.log` |
| F047 | `k10.2/k10.2b-source-comparison/report-subset/write-complete-check.log` |
| F048 | `k10.2/k10.2b-source-comparison/report-subset/write-complete-test.log` |
| F049 | `k10.2/k10.2b-source-comparison/report-subset/write-missing-upper-check.log` |
| F050 | `k10.2/k10.2b-source-comparison/report-subset/write-missing-upper-test.log` |
| F051 | `k10.2/k10.2b-source-comparison/report-subset/write-partial-check.log` |
| F052 | `k10.2/k10.2b-source-comparison/report-subset/write-partial-test.log` |
| F053 | `k10.2/known-differences/cli-main/nul-direct.log` |
| F054 | `k10.2/known-differences/cli-main/nul-dynamic.log` |
| F055 | `k10.2/range-source-comparison/report-subset/connect-complete-check.log` |
| F056 | `k10.2/range-source-comparison/report-subset/connect-complete-test.log` |
| F057 | `k10.2/range-source-comparison/report-subset/connect-missing-upper-check.log` |
| F058 | `k10.2/range-source-comparison/report-subset/connect-missing-upper-test.log` |
| F059 | `k10.2/range-source-comparison/report-subset/connect-partial-check.log` |
| F060 | `k10.2/range-source-comparison/report-subset/connect-partial-test.log` |
| F061 | `k10.2/range-source-comparison/report-subset/non-top-check.log` |
| F062 | `k10.2/range-source-comparison/report-subset/non-top-test.log` |
| F063 | `k10.2/range-source-comparison/report-subset/pure-check.log` |
| F064 | `k10.2/range-source-comparison/report-subset/pure-test.log` |
| F065 | `k10.2/range-source-comparison/report-subset/read-complete-check.log` |
| F066 | `k10.2/range-source-comparison/report-subset/read-complete-test.log` |
| F067 | `k10.2/range-source-comparison/report-subset/read-missing-upper-check.log` |
| F068 | `k10.2/range-source-comparison/report-subset/read-missing-upper-test.log` |
| F069 | `k10.2/range-source-comparison/report-subset/read-partial-check.log` |
| F070 | `k10.2/range-source-comparison/report-subset/read-partial-test.log` |
| F071 | `k10.2/range-source-comparison/report-subset/redundant-check.log` |
| F072 | `k10.2/range-source-comparison/report-subset/redundant-test.log` |
| F073 | `k10.2/range-source-comparison/report-subset/show-match-check.log` |
| F074 | `k10.2/range-source-comparison/report-subset/show-match-test.log` |
| F075 | `k10.2/range-source-comparison/report-subset/show-rejected-check.log` |
| F076 | `k10.2/range-source-comparison/report-subset/show-rejected-test.log` |
| F077 | `k10.2/range-source-comparison/report-subset/top-check.log` |
| F078 | `k10.2/range-source-comparison/report-subset/top-test.log` |
| F079 | `k10.2/range-source-comparison/report-subset/write-complete-check.log` |
| F080 | `k10.2/range-source-comparison/report-subset/write-complete-test.log` |
| F081 | `k10.2/range-source-comparison/report-subset/write-missing-upper-check.log` |
| F082 | `k10.2/range-source-comparison/report-subset/write-missing-upper-test.log` |
| F083 | `k10.2/range-source-comparison/report-subset/write-partial-check.log` |
| F084 | `k10.2/range-source-comparison/report-subset/write-partial-test.log` |
| F085 | `k10.3/k10.3b-source-diff.patch` |
| F086 | `k10.3/source-diff.patch` |
| F087 | `l00.01/candidate-i/results.md` |
| F088 | `l00.01/candidate-i/tools/trial.sh` |
| F089 | `l00.01/candidate-ii/results.md` |
| F090 | `l00.02/results.md` |
| F091 | `l00.03/results.md` |
| F092 | `l00.04/results.md` |
| F093 | `l00.05/results.md` |
| F094 | `l00.06/results.md` |
| F095 | `l00.06b/results.md` |
| F096 | `l00.06c/results.md` |
| F097 | `l00.06c/tools/build.sh` |
| F098 | `l00.07/results.md` |
| F099 | `l00.08/results-placement.md` |
| F100 | `l00.08/results.md` |
| F101 | `l10.1/results.md` |
| F102 | `l10.2/results.md` |
| F103 | `l10.3/results.md` |
| F104 | `l10.4/results.md` |
| F105 | `l10.5/results.md` |
| F106 | `l20.1/results.md` |
| F107 | `l20.2/results.md` |
| F108 | `l20.3/results.md` |
| F109 | `l20.4/results.md` |
| F110 | `l20.5/results.md` |
| F111 | `l20.6/results.md` |
| F112 | `l20.7/results.md` |
| F113 | `l30.1/results.md` |
| F114 | `l30.3/results.md` |
| F115 | `l30.4/results.md` |
| F116 | `l30.5/results.md` |
| F117 | `l40.1/results.md` |
| F118 | `l40.2/results.md` |
| F119 | `l40.3/results.md` |
| F120 | `l40.3b/results.md` |
| F121 | `l40.3c/results.md` |
| F122 | `l40.3d/results.md` |
| F123 | `l40.4/results.md` |
| F124 | `l40.5/results.md` |
| F125 | `l40.6/results.md` |
| F126 | `l40.6b/results.md` |
| F127 | `l40.6c/results.md` |
| F128 | `l50.2/results.md` |
| F129 | `l50.4/results.md` |
| F130 | `plan-r10-r40.md` |
| F131 | `plan-v10.md` |
| F132 | `plan.md` |
| F133 | `r10.3/cli-scopes-before.log` |
| F134 | `r10.5/changed-files.json` |
| F135 | `r10.5/implementation.patch` |
| F136 | `r10.5/line-counts.json` |
| F137 | `r10.5/results.md` |
| F138 | `r10.6/extra-after.json` |
| F139 | `r10.6/extra-b0.json` |
| F140 | `r10.6/extra-bwork.json` |
| F141 | `r10.6/extra-initial-after.json` |
| F142 | `r10.6/extra-initial-b0.json` |
| F143 | `r10.6/extra-initial-bwork.json` |
| F144 | `r10.6/results.md` |
| F145 | `r10.7/r10.7b-comparison-retry.log` |
| F146 | `r10.7/r10.7b-comparison-retry2.log` |
| F147 | `r10.7/r10.7b-comparison.log` |
| F148 | `r20.0b/changed-files.json` |
| F149 | `r20.0b/implementation.patch` |
| F150 | `r20.0b/line-counts.json` |
| F151 | `r20.0b/results.md` |
| F152 | `r20.3/changed-files.json` |
| F153 | `r20.3/implementation.patch` |
| F154 | `r20.3/inventory.md` |
| F155 | `r20.3/line-counts.json` |
| F156 | `r20.4/golden-after.log` |
| F157 | `r20.4/w-r-complete.log` |
| F158 | `r20.6/r20.6b-after-inputs.json` |
| F159 | `r20.6/r20.6b-before-inputs.json` |
| F160 | `r30.1/r30.1b-integrity.json` |
| F161 | `r30.1/r30.1b-protected-before.json` |
| F162 | `r30.1/results.md` |
| F163 | `r30.2/handler-inventory.md` |
| F164 | `r30.2/r30.2b-inventory-check.log` |
| F165 | `r30.2d/work-recheck.log` |
| F166 | `r30.3/inputs.json` |
| F167 | `r30.3/r20.3-commit-comparison.json` |
| F168 | `r30.3/r20.3-input-comparison.json` |
| F169 | `r30.3/results.md` |
| F170 | `r30.4/changed-inputs.json` |
| F171 | `r30.4/final-state.json` |
| F172 | `r30.4/handler-inventory.md` |
| F173 | `r30.4/implementation.patch` |
| F174 | `r30.4/r30.4b-review.json` |
| F175 | `r30.4/r30.4b-start-state.json` |
| F176 | `r30.4/r30.4c-before.patch` |
| F177 | `r30.4/r30.4c-documentation.patch` |
| F178 | `r30.4/r30.4c-review-fixed.log` |
| F179 | `r30.4/r30.4c-review.json` |
| F180 | `r30.4/r30.4c-review.py` |
| F181 | `r30.4/r30.4c-sdk-source.json` |
| F182 | `r30.4/r30.4c-start-state.json` |
| F183 | `r30.4/results.md` |
| F184 | `r30.4/sectrust-aia-sources.json` |
| F185 | `r30.4/sectrust-aia.md` |
| F186 | `r30.5/design-followup.md` |
| F187 | `r30.5/effect-module-aliases.log` |
| F188 | `r30.5/handler-input-hashes.json` |
| F189 | `r30.5/handlers-boundaries.md` |
| F190 | `r30.5/operation-clauses.log` |
| F191 | `r30.5/operations-cost.md` |
| F192 | `r30.5/outside-crate-file-http.log` |
| F193 | `r30.5/results.md` |
| F194 | `r30.5/work-inputs.json` |
| F195 | `r40.2/r40.2b-h1.json` |
| F196 | `r40.2/report-report-matrix-user-retry.log` |
| F197 | `r40.2/report-report-matrix-user.log` |
| F198 | `r40.3/final-inputs.json` |
| F199 | `r40.3/handoff-check-initial-reports/connect-complete-main.stdout.json` |
| F200 | `r40.3/handoff-check-initial-reports/connect-complete-test.stdout.json` |
| F201 | `r40.3/handoff-check-initial-reports/connect-missing-upper-main.stdout.json` |
| F202 | `r40.3/handoff-check-initial-reports/connect-missing-upper-test.stdout.json` |
| F203 | `r40.3/handoff-check-initial-reports/connect-partial-main.stdout.json` |
| F204 | `r40.3/handoff-check-initial-reports/connect-partial-test.stdout.json` |
| F205 | `r40.3/handoff-check-initial-reports/non-top-main.stdout.json` |
| F206 | `r40.3/handoff-check-initial-reports/non-top-test.stdout.json` |
| F207 | `r40.3/handoff-check-initial-reports/pure-main.stdout.json` |
| F208 | `r40.3/handoff-check-initial-reports/pure-test.stdout.json` |
| F209 | `r40.3/handoff-check-initial-reports/read-complete-main.stdout.json` |
| F210 | `r40.3/handoff-check-initial-reports/read-complete-test.stdout.json` |
| F211 | `r40.3/handoff-check-initial-reports/read-missing-upper-main.stdout.json` |
| F212 | `r40.3/handoff-check-initial-reports/read-missing-upper-test.stdout.json` |
| F213 | `r40.3/handoff-check-initial-reports/read-partial-main.stdout.json` |
| F214 | `r40.3/handoff-check-initial-reports/read-partial-test.stdout.json` |
| F215 | `r40.3/handoff-check-initial-reports/redundant-main.stdout.json` |
| F216 | `r40.3/handoff-check-initial-reports/redundant-test.stdout.json` |
| F217 | `r40.3/handoff-check-initial-reports/show-match-main.stdout.json` |
| F218 | `r40.3/handoff-check-initial-reports/show-match-test.stdout.json` |
| F219 | `r40.3/handoff-check-initial-reports/show-rejected-main.stdout.json` |
| F220 | `r40.3/handoff-check-initial-reports/show-rejected-test.stdout.json` |
| F221 | `r40.3/handoff-check-initial-reports/top-main.stdout.json` |
| F222 | `r40.3/handoff-check-initial-reports/top-test.stdout.json` |
| F223 | `r40.3/handoff-check-initial-reports/write-complete-main.stdout.json` |
| F224 | `r40.3/handoff-check-initial-reports/write-complete-test.stdout.json` |
| F225 | `r40.3/handoff-check-initial-reports/write-missing-upper-main.stdout.json` |
| F226 | `r40.3/handoff-check-initial-reports/write-missing-upper-test.stdout.json` |
| F227 | `r40.3/handoff-check-initial-reports/write-partial-main.stdout.json` |
| F228 | `r40.3/handoff-check-initial-reports/write-partial-test.stdout.json` |
| F229 | `r40.3/handoff-check-reports/connect-complete-main.stdout.json` |
| F230 | `r40.3/handoff-check-reports/connect-complete-test.stdout.json` |
| F231 | `r40.3/handoff-check-reports/connect-missing-upper-main.stdout.json` |
| F232 | `r40.3/handoff-check-reports/connect-missing-upper-test.stdout.json` |
| F233 | `r40.3/handoff-check-reports/connect-partial-main.stdout.json` |
| F234 | `r40.3/handoff-check-reports/connect-partial-test.stdout.json` |
| F235 | `r40.3/handoff-check-reports/non-top-main.stdout.json` |
| F236 | `r40.3/handoff-check-reports/non-top-test.stdout.json` |
| F237 | `r40.3/handoff-check-reports/pure-main.stdout.json` |
| F238 | `r40.3/handoff-check-reports/pure-test.stdout.json` |
| F239 | `r40.3/handoff-check-reports/read-complete-main.stdout.json` |
| F240 | `r40.3/handoff-check-reports/read-complete-test.stdout.json` |
| F241 | `r40.3/handoff-check-reports/read-missing-upper-main.stdout.json` |
| F242 | `r40.3/handoff-check-reports/read-missing-upper-test.stdout.json` |
| F243 | `r40.3/handoff-check-reports/read-partial-main.stdout.json` |
| F244 | `r40.3/handoff-check-reports/read-partial-test.stdout.json` |
| F245 | `r40.3/handoff-check-reports/redundant-main.stdout.json` |
| F246 | `r40.3/handoff-check-reports/redundant-test.stdout.json` |
| F247 | `r40.3/handoff-check-reports/show-match-main.stdout.json` |
| F248 | `r40.3/handoff-check-reports/show-match-test.stdout.json` |
| F249 | `r40.3/handoff-check-reports/show-rejected-main.stdout.json` |
| F250 | `r40.3/handoff-check-reports/show-rejected-test.stdout.json` |
| F251 | `r40.3/handoff-check-reports/top-main.stdout.json` |
| F252 | `r40.3/handoff-check-reports/top-test.stdout.json` |
| F253 | `r40.3/handoff-check-reports/write-complete-main.stdout.json` |
| F254 | `r40.3/handoff-check-reports/write-complete-test.stdout.json` |
| F255 | `r40.3/handoff-check-reports/write-missing-upper-main.stdout.json` |
| F256 | `r40.3/handoff-check-reports/write-missing-upper-test.stdout.json` |
| F257 | `r40.3/handoff-check-reports/write-partial-main.stdout.json` |
| F258 | `r40.3/handoff-check-reports/write-partial-test.stdout.json` |
| F259 | `r40.3/pinned-reference.json` |
| F260 | `r40.3/r40.3b-final-inputs.json` |
| F261 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-complete-main.stdout.json` |
| F262 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-complete-test.stdout.json` |
| F263 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-missing-upper-main.stdout.json` |
| F264 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-missing-upper-test.stdout.json` |
| F265 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-partial-main.stdout.json` |
| F266 | `r40.3/r40.3b-handoff-after-work-check-reports/connect-partial-test.stdout.json` |
| F267 | `r40.3/r40.3b-handoff-after-work-check-reports/non-top-main.stdout.json` |
| F268 | `r40.3/r40.3b-handoff-after-work-check-reports/non-top-test.stdout.json` |
| F269 | `r40.3/r40.3b-handoff-after-work-check-reports/pure-main.stdout.json` |
| F270 | `r40.3/r40.3b-handoff-after-work-check-reports/pure-test.stdout.json` |
| F271 | `r40.3/r40.3b-handoff-after-work-check-reports/read-complete-main.stdout.json` |
| F272 | `r40.3/r40.3b-handoff-after-work-check-reports/read-complete-test.stdout.json` |
| F273 | `r40.3/r40.3b-handoff-after-work-check-reports/read-missing-upper-main.stdout.json` |
| F274 | `r40.3/r40.3b-handoff-after-work-check-reports/read-missing-upper-test.stdout.json` |
| F275 | `r40.3/r40.3b-handoff-after-work-check-reports/read-partial-main.stdout.json` |
| F276 | `r40.3/r40.3b-handoff-after-work-check-reports/read-partial-test.stdout.json` |
| F277 | `r40.3/r40.3b-handoff-after-work-check-reports/redundant-main.stdout.json` |
| F278 | `r40.3/r40.3b-handoff-after-work-check-reports/redundant-test.stdout.json` |
| F279 | `r40.3/r40.3b-handoff-after-work-check-reports/show-match-main.stdout.json` |
| F280 | `r40.3/r40.3b-handoff-after-work-check-reports/show-match-test.stdout.json` |
| F281 | `r40.3/r40.3b-handoff-after-work-check-reports/show-rejected-main.stdout.json` |
| F282 | `r40.3/r40.3b-handoff-after-work-check-reports/show-rejected-test.stdout.json` |
| F283 | `r40.3/r40.3b-handoff-after-work-check-reports/top-main.stdout.json` |
| F284 | `r40.3/r40.3b-handoff-after-work-check-reports/top-test.stdout.json` |
| F285 | `r40.3/r40.3b-handoff-after-work-check-reports/write-complete-main.stdout.json` |
| F286 | `r40.3/r40.3b-handoff-after-work-check-reports/write-complete-test.stdout.json` |
| F287 | `r40.3/r40.3b-handoff-after-work-check-reports/write-missing-upper-main.stdout.json` |
| F288 | `r40.3/r40.3b-handoff-after-work-check-reports/write-missing-upper-test.stdout.json` |
| F289 | `r40.3/r40.3b-handoff-after-work-check-reports/write-partial-main.stdout.json` |
| F290 | `r40.3/r40.3b-handoff-after-work-check-reports/write-partial-test.stdout.json` |
| F291 | `r40.3/r40.3b-handoff-check-reports/connect-complete-main.stdout.json` |
| F292 | `r40.3/r40.3b-handoff-check-reports/connect-complete-test.stdout.json` |
| F293 | `r40.3/r40.3b-handoff-check-reports/connect-missing-upper-main.stdout.json` |
| F294 | `r40.3/r40.3b-handoff-check-reports/connect-missing-upper-test.stdout.json` |
| F295 | `r40.3/r40.3b-handoff-check-reports/connect-partial-main.stdout.json` |
| F296 | `r40.3/r40.3b-handoff-check-reports/connect-partial-test.stdout.json` |
| F297 | `r40.3/r40.3b-handoff-check-reports/non-top-main.stdout.json` |
| F298 | `r40.3/r40.3b-handoff-check-reports/non-top-test.stdout.json` |
| F299 | `r40.3/r40.3b-handoff-check-reports/pure-main.stdout.json` |
| F300 | `r40.3/r40.3b-handoff-check-reports/pure-test.stdout.json` |
| F301 | `r40.3/r40.3b-handoff-check-reports/read-complete-main.stdout.json` |
| F302 | `r40.3/r40.3b-handoff-check-reports/read-complete-test.stdout.json` |
| F303 | `r40.3/r40.3b-handoff-check-reports/read-missing-upper-main.stdout.json` |
| F304 | `r40.3/r40.3b-handoff-check-reports/read-missing-upper-test.stdout.json` |
| F305 | `r40.3/r40.3b-handoff-check-reports/read-partial-main.stdout.json` |
| F306 | `r40.3/r40.3b-handoff-check-reports/read-partial-test.stdout.json` |
| F307 | `r40.3/r40.3b-handoff-check-reports/redundant-main.stdout.json` |
| F308 | `r40.3/r40.3b-handoff-check-reports/redundant-test.stdout.json` |
| F309 | `r40.3/r40.3b-handoff-check-reports/show-match-main.stdout.json` |
| F310 | `r40.3/r40.3b-handoff-check-reports/show-match-test.stdout.json` |
| F311 | `r40.3/r40.3b-handoff-check-reports/show-rejected-main.stdout.json` |
| F312 | `r40.3/r40.3b-handoff-check-reports/show-rejected-test.stdout.json` |
| F313 | `r40.3/r40.3b-handoff-check-reports/top-main.stdout.json` |
| F314 | `r40.3/r40.3b-handoff-check-reports/top-test.stdout.json` |
| F315 | `r40.3/r40.3b-handoff-check-reports/write-complete-main.stdout.json` |
| F316 | `r40.3/r40.3b-handoff-check-reports/write-complete-test.stdout.json` |
| F317 | `r40.3/r40.3b-handoff-check-reports/write-missing-upper-main.stdout.json` |
| F318 | `r40.3/r40.3b-handoff-check-reports/write-missing-upper-test.stdout.json` |
| F319 | `r40.3/r40.3b-handoff-check-reports/write-partial-main.stdout.json` |
| F320 | `r40.3/r40.3b-handoff-check-reports/write-partial-test.stdout.json` |
| F321 | `r40.3/r40.3b-work-inputs.json` |
| F322 | `r40.3/r40.3b-work-inputs.patch` |
| F323 | `r40.3/results.md` |
| F324 | `r40.3/work-inputs.json` |
| F325 | `r40.3/work-inputs.patch` |
| F326 | `reviews/RV-K10.2.md` |
| F327 | `reviews/RV-P1.md` |
| F328 | `reviews/RV-R30.1.md` |
| F329 | `reviews/RV-R30.2.md` |
| F330 | `reviews/RV-R30.4.md` |
| F331 | `reviews/RV-S8.md` |
| F332 | `reviews/RV-V10.1a.md` |
| F333 | `reviews/RV-V10.1b.md` |
| F334 | `reviews/RV-V10.2b.md` |
| F335 | `reviews/RV-V10P.md` |
| F336 | `reviews/S4-notes.md` |
| F337 | `rv-l20-fix/results.md` |
| F338 | `spikes/SA/findings.md` |
| F339 | `spikes/SA/provenance.json` |
| F340 | `spikes/SB/findings.md` |
| F341 | `spikes/SB/qa.json` |
| F342 | `spikes/SB/verify.py` |
| F343 | `spikes/SD/conditions-run-1-run.json` |
| F344 | `spikes/SD/examples-run-1-run.json` |
| F345 | `spikes/SD/final-run.json` |
| F346 | `spikes/SD/findings.md` |
| F347 | `spikes/SD/model-run-1-run.json` |
| F348 | `spikes/SD/provenance.json` |
| F349 | `spikes/SD/run.py` |
| F350 | `spikes/SD/verify.py` |
| F351 | `spikes/SF/final-run.json` |
| F352 | `spikes/SF/findings.md` |
| F353 | `spikes/SF/run.py` |
| F354 | `spikes/SG/combined-run-1-run.json` |
| F355 | `spikes/SG/compatibility-run-1-run.json` |
| F356 | `spikes/SG/failure-run-1-run.json` |
| F357 | `spikes/SG/final-run.json` |
| F358 | `spikes/SG/findings.md` |
| F359 | `spikes/SG/generic-run-1-run.json` |
| F360 | `spikes/SG/integrity-run-1-run.json` |
| F361 | `spikes/SG/integrity-run-2-run.json` |
| F362 | `spikes/SG/phase-run-1-run.json` |
| F363 | `spikes/SG/phase-run-2-run.json` |
| F364 | `spikes/SG/run.py` |
| F365 | `spikes/SG/verify.py` |
| F366 | `spikes/SH/findings.md` |
| F367 | `spikes/SH2/findings.md` |
| F368 | `spikes/SH2/verification.json` |
| F369 | `spikes/SK/findings.md` |
| F370 | `spikes/SK/provenance.json` |
| F371 | `st-cr/results.md` |
| F372 | `study/higher-order-effects.md` |
| F373 | `study/information-flow.md` |
| F374 | `study/language-rules.md` |
| F375 | `study/questions.md` |
| F376 | `study/synthesis.md` |
| F377 | `study/targets-and-capabilities.md` |
| F378 | `study/usage-and-flow.md` |
| F379 | `study/user-effect-scopes.md` |
| F380 | `v10.1b/j2-complete.log` |
| F381 | `v10.1b/j2-rewrite-inventory.json` |
| F382 | `v10.1b/j2-rewrite-inventory.md` |
| F383 | `v10.1b/j2-send-only.log` |
| F384 | `v10.1b/results.md` |
| F385 | `v10.1b/rv-probes/grep-lang.txt` |
| F386 | `v10.1b/rv-probes/j2-complete.json` |
| F387 | `v10.1b/rv-probes/j2-send-only.json` |
| F388 | `v10.1b/v10.1bb-inventory.py` |
| F389 | `v10.1d/changes-after-k10.3.json` |
| F390 | `v10.1d/f-q.md` |
| F391 | `v10.1d/results.md` |
| F392 | `v10.2b/final-state.json` |
| F393 | `v10.2b/generated-audit.json` |
| F394 | `v10.2b/handler-audit.json` |
| F395 | `v10.2b/initial-state.json` |
| F396 | `v10.2b/pinned-references.json` |
| F397 | `v10.2b/post-check-prose.json` |
| F398 | `v10.2b/results.md` |
| F399 | `v10.2b/supplement-final-state.json` |
| F400 | `v10.2b/supplement-initial-state.json` |
| F401 | `v10.2b/supplement-link-table-audit.json` |
| F402 | `v10.2b/supplement-publication-terms.json` |
| F403 | `v10.2b/translation-map.json` |
| F404 | `v10.2b/translation-map.md` |
| F405 | `v10.3a/ab-change-audit.json` |
| F406 | `v10.3a/ab-operation-counts.json` |
| F407 | `v10.3a/audit-translation.py` |
| F408 | `v10.3a/audit.py` |
| F409 | `v10.3a/changed-files.json` |
| F410 | `v10.3a/edit-version.py` |
| F411 | `v10.3a/inventory-audit.json` |
| F412 | `v10.3a/results.md` |
| F413 | `v10.3a/translation-audit.json` |
| F414 | `v10.3c/audit-inventory.py` |
| F415 | `v10.3c/inventory-audit.json` |
| F416 | `v10.3c/inventory.md` |
| F417 | `v10.3c/outputs-attempt1/old-send-plain-0012.stdout` |
| F418 | `v10.3c/outputs-attempt1/old-send-plain-none.stdout` |
| F419 | `v10.3c/outputs-attempt1/range-request-widen-rejected.stdout` |
| F420 | `v10.3c/outputs-attempt1/report-connect-complete-check.stdout` |
| F421 | `v10.3c/outputs-attempt1/report-connect-complete-test.stdout` |
| F422 | `v10.3c/outputs-attempt1/report-connect-missing-upper-check.stdout` |
| F423 | `v10.3c/outputs-attempt1/report-connect-missing-upper-test.stdout` |
| F424 | `v10.3c/outputs-attempt1/report-connect-partial-check.stdout` |
| F425 | `v10.3c/outputs-attempt1/report-connect-partial-test.stdout` |
| F426 | `v10.3c/outputs-attempt1/report-non-top-check.stdout` |
| F427 | `v10.3c/outputs-attempt1/report-non-top-test.stdout` |
| F428 | `v10.3c/outputs-attempt1/report-pure-check.stdout` |
| F429 | `v10.3c/outputs-attempt1/report-pure-test.stdout` |
| F430 | `v10.3c/outputs-attempt1/report-read-complete-check.stdout` |
| F431 | `v10.3c/outputs-attempt1/report-read-complete-test.stdout` |
| F432 | `v10.3c/outputs-attempt1/report-read-missing-upper-check.stdout` |
| F433 | `v10.3c/outputs-attempt1/report-read-missing-upper-test.stdout` |
| F434 | `v10.3c/outputs-attempt1/report-read-partial-check.stdout` |
| F435 | `v10.3c/outputs-attempt1/report-read-partial-test.stdout` |
| F436 | `v10.3c/outputs-attempt1/report-redundant-check.stdout` |
| F437 | `v10.3c/outputs-attempt1/report-redundant-test.stdout` |
| F438 | `v10.3c/outputs-attempt1/report-show-match-check.stdout` |
| F439 | `v10.3c/outputs-attempt1/report-show-match-test.stdout` |
| F440 | `v10.3c/outputs-attempt1/report-show-rejected-check.stdout` |
| F441 | `v10.3c/outputs-attempt1/report-show-rejected-test.stdout` |
| F442 | `v10.3c/outputs-attempt1/report-top-check.stdout` |
| F443 | `v10.3c/outputs-attempt1/report-top-test.stdout` |
| F444 | `v10.3c/outputs-attempt1/report-write-complete-check.stdout` |
| F445 | `v10.3c/outputs-attempt1/report-write-complete-test.stdout` |
| F446 | `v10.3c/outputs-attempt1/report-write-missing-upper-check.stdout` |
| F447 | `v10.3c/outputs-attempt1/report-write-missing-upper-test.stdout` |
| F448 | `v10.3c/outputs-attempt1/report-write-partial-check.stdout` |
| F449 | `v10.3c/outputs-attempt1/report-write-partial-test.stdout` |
| F450 | `v10.3c/outputs-attempt2/old-send-plain-0012.stdout` |
| F451 | `v10.3c/outputs-attempt2/old-send-plain-none.stdout` |
| F452 | `v10.3c/outputs-attempt2/range-request-widen-rejected.stdout` |
| F453 | `v10.3c/outputs-attempt2/report-connect-complete-check.stdout` |
| F454 | `v10.3c/outputs-attempt2/report-connect-complete-test.stdout` |
| F455 | `v10.3c/outputs-attempt2/report-connect-missing-upper-check.stdout` |
| F456 | `v10.3c/outputs-attempt2/report-connect-missing-upper-test.stdout` |
| F457 | `v10.3c/outputs-attempt2/report-connect-partial-check.stdout` |
| F458 | `v10.3c/outputs-attempt2/report-connect-partial-test.stdout` |
| F459 | `v10.3c/outputs-attempt2/report-non-top-check.stdout` |
| F460 | `v10.3c/outputs-attempt2/report-non-top-test.stdout` |
| F461 | `v10.3c/outputs-attempt2/report-pure-check.stdout` |
| F462 | `v10.3c/outputs-attempt2/report-pure-test.stdout` |
| F463 | `v10.3c/outputs-attempt2/report-read-complete-check.stdout` |
| F464 | `v10.3c/outputs-attempt2/report-read-complete-test.stdout` |
| F465 | `v10.3c/outputs-attempt2/report-read-missing-upper-check.stdout` |
| F466 | `v10.3c/outputs-attempt2/report-read-missing-upper-test.stdout` |
| F467 | `v10.3c/outputs-attempt2/report-read-partial-check.stdout` |
| F468 | `v10.3c/outputs-attempt2/report-read-partial-test.stdout` |
| F469 | `v10.3c/outputs-attempt2/report-redundant-check.stdout` |
| F470 | `v10.3c/outputs-attempt2/report-redundant-test.stdout` |
| F471 | `v10.3c/outputs-attempt2/report-show-match-check.stdout` |
| F472 | `v10.3c/outputs-attempt2/report-show-match-test.stdout` |
| F473 | `v10.3c/outputs-attempt2/report-show-rejected-check.stdout` |
| F474 | `v10.3c/outputs-attempt2/report-show-rejected-test.stdout` |
| F475 | `v10.3c/outputs-attempt2/report-top-check.stdout` |
| F476 | `v10.3c/outputs-attempt2/report-top-test.stdout` |
| F477 | `v10.3c/outputs-attempt2/report-write-complete-check.stdout` |
| F478 | `v10.3c/outputs-attempt2/report-write-complete-test.stdout` |
| F479 | `v10.3c/outputs-attempt2/report-write-missing-upper-check.stdout` |
| F480 | `v10.3c/outputs-attempt2/report-write-missing-upper-test.stdout` |
| F481 | `v10.3c/outputs-attempt2/report-write-partial-check.stdout` |
| F482 | `v10.3c/outputs-attempt2/report-write-partial-test.stdout` |
| F483 | `v10.3c/outputs-attempt2/skill-2.stdout` |
| F484 | `v10.3c/outputs-attempt2/skill-3.stdout` |
| F485 | `v10.3c/outputs-attempt2/skill-6.stdout` |
| F486 | `v10.3c/outputs-attempt2/skill-7.stdout` |
| F487 | `v10.3c/outputs-attempt2/skill-8.stdout` |
| F488 | `v10.3c/outputs/old-send-plain-0012.stdout` |
| F489 | `v10.3c/outputs/old-send-plain-none.stdout` |
| F490 | `v10.3c/outputs/range-request-widen-rejected.stdout` |
| F491 | `v10.3c/outputs/report-connect-complete-check.stdout` |
| F492 | `v10.3c/outputs/report-connect-complete-test.stdout` |
| F493 | `v10.3c/outputs/report-connect-missing-upper-check.stdout` |
| F494 | `v10.3c/outputs/report-connect-missing-upper-test.stdout` |
| F495 | `v10.3c/outputs/report-connect-partial-check.stdout` |
| F496 | `v10.3c/outputs/report-connect-partial-test.stdout` |
| F497 | `v10.3c/outputs/report-non-top-check.stdout` |
| F498 | `v10.3c/outputs/report-non-top-test.stdout` |
| F499 | `v10.3c/outputs/report-pure-check.stdout` |
| F500 | `v10.3c/outputs/report-pure-test.stdout` |
| F501 | `v10.3c/outputs/report-read-complete-check.stdout` |
| F502 | `v10.3c/outputs/report-read-complete-test.stdout` |
| F503 | `v10.3c/outputs/report-read-missing-upper-check.stdout` |
| F504 | `v10.3c/outputs/report-read-missing-upper-test.stdout` |
| F505 | `v10.3c/outputs/report-read-partial-check.stdout` |
| F506 | `v10.3c/outputs/report-read-partial-test.stdout` |
| F507 | `v10.3c/outputs/report-redundant-check.stdout` |
| F508 | `v10.3c/outputs/report-redundant-test.stdout` |
| F509 | `v10.3c/outputs/report-show-match-check.stdout` |
| F510 | `v10.3c/outputs/report-show-match-test.stdout` |
| F511 | `v10.3c/outputs/report-show-rejected-check.stdout` |
| F512 | `v10.3c/outputs/report-show-rejected-test.stdout` |
| F513 | `v10.3c/outputs/report-top-check.stdout` |
| F514 | `v10.3c/outputs/report-top-test.stdout` |
| F515 | `v10.3c/outputs/report-write-complete-check.stdout` |
| F516 | `v10.3c/outputs/report-write-complete-test.stdout` |
| F517 | `v10.3c/outputs/report-write-missing-upper-check.stdout` |
| F518 | `v10.3c/outputs/report-write-missing-upper-test.stdout` |
| F519 | `v10.3c/outputs/report-write-partial-check.stdout` |
| F520 | `v10.3c/outputs/report-write-partial-test.stdout` |
| F521 | `v10.3c/outputs/skill-2.stdout` |
| F522 | `v10.3c/outputs/skill-3.stdout` |
| F523 | `v10.3c/outputs/skill-6.stdout` |
| F524 | `v10.3c/outputs/skill-7.stdout` |
| F525 | `v10.3c/outputs/skill-8.stdout` |

## 全行

| ファイル | 基準時の行 | 分類 |
|---|---:|---|
| F000 | 3 | c |
| F000 | 21 | c |
| F000 | 48 | c |
| F000 | 249 | d |
| F001 | 3 | c |
| F002 | 13 | d |
| F002 | 15 | c |
| F002 | 17 | d |
| F003 | 7 | d |
| F003 | 9 | d |
| F003 | 10 | d |
| F003 | 19 | c |
| F004 | 3 | d |
| F004 | 9 | d |
| F004 | 15 | d |
| F004 | 21 | d |
| F004 | 27 | d |
| F004 | 33 | d |
| F004 | 39 | d |
| F004 | 45 | d |
| F004 | 51 | d |
| F004 | 57 | d |
| F004 | 63 | d |
| F004 | 69 | d |
| F004 | 75 | d |
| F004 | 81 | d |
| F004 | 87 | d |
| F004 | 93 | d |
| F004 | 99 | d |
| F004 | 105 | d |
| F004 | 111 | d |
| F004 | 117 | d |
| F004 | 123 | d |
| F004 | 129 | d |
| F004 | 135 | d |
| F004 | 141 | d |
| F004 | 147 | d |
| F004 | 153 | d |
| F004 | 159 | d |
| F004 | 165 | d |
| F004 | 171 | d |
| F004 | 177 | d |
| F004 | 183 | d |
| F004 | 189 | d |
| F004 | 195 | d |
| F004 | 201 | d |
| F004 | 207 | d |
| F004 | 213 | d |
| F004 | 219 | d |
| F004 | 225 | d |
| F004 | 231 | d |
| F004 | 237 | d |
| F004 | 243 | d |
| F004 | 249 | d |
| F004 | 255 | d |
| F004 | 261 | d |
| F004 | 267 | d |
| F004 | 273 | d |
| F004 | 279 | d |
| F004 | 285 | d |
| F004 | 291 | d |
| F004 | 297 | d |
| F004 | 303 | d |
| F004 | 309 | d |
| F004 | 315 | d |
| F004 | 321 | d |
| F004 | 327 | d |
| F004 | 333 | d |
| F004 | 339 | d |
| F004 | 345 | d |
| F004 | 351 | d |
| F004 | 357 | d |
| F004 | 363 | d |
| F004 | 369 | d |
| F004 | 375 | d |
| F005 | 14 | c |
| F005 | 24 | c |
| F005 | 25 | c |
| F006 | 24 | c |
| F006 | 43 | d |
| F007 | 24 | c |
| F007 | 43 | d |
| F008 | 24 | c |
| F008 | 45 | d |
| F009 | 24 | c |
| F009 | 47 | d |
| F010 | 24 | c |
| F010 | 49 | d |
| F011 | 68 | a |
| F011 | 78 | a |
| F012 | 2136 | a |
| F013 | 198 | a |
| F013 | 426 | a |
| F014 | 22 | d |
| F014 | 86 | a |
| F014 | 102 | a |
| F015 | 18 | c |
| F016 | 18 | c |
| F017 | 16 | c |
| F018 | 144 | a |
| F018 | 166 | a |
| F018 | 185 | a |
| F019 | 19 | a |
| F020 | 1 | a |
| F021 | 1 | a |
| F022 | 8 | a |
| F022 | 10 | a |
| F022 | 12 | a |
| F023 | 1 | a |
| F024 | 1 | a |
| F025 | 1 | a |
| F026 | 1 | a |
| F027 | 1 | a |
| F028 | 1 | a |
| F029 | 1 | a |
| F030 | 1 | a |
| F031 | 1 | a |
| F032 | 1 | a |
| F033 | 1 | a |
| F034 | 1 | a |
| F035 | 1 | a |
| F036 | 1 | a |
| F037 | 1 | a |
| F038 | 1 | a |
| F039 | 1 | a |
| F040 | 1 | a |
| F041 | 1 | a |
| F042 | 1 | a |
| F043 | 1 | a |
| F044 | 1 | a |
| F045 | 1 | a |
| F046 | 1 | a |
| F047 | 1 | a |
| F048 | 1 | a |
| F049 | 1 | a |
| F050 | 1 | a |
| F051 | 1 | a |
| F052 | 1 | a |
| F053 | 1 | a |
| F054 | 1 | a |
| F055 | 1 | a |
| F056 | 1 | a |
| F057 | 1 | a |
| F058 | 1 | a |
| F059 | 1 | a |
| F060 | 1 | a |
| F061 | 1 | a |
| F062 | 1 | a |
| F063 | 1 | a |
| F064 | 1 | a |
| F065 | 1 | a |
| F066 | 1 | a |
| F067 | 1 | a |
| F068 | 1 | a |
| F069 | 1 | a |
| F070 | 1 | a |
| F071 | 1 | a |
| F072 | 1 | a |
| F073 | 1 | a |
| F074 | 1 | a |
| F075 | 1 | a |
| F076 | 1 | a |
| F077 | 1 | a |
| F078 | 1 | a |
| F079 | 1 | a |
| F080 | 1 | a |
| F081 | 1 | a |
| F082 | 1 | a |
| F083 | 1 | a |
| F084 | 1 | a |
| F085 | 74 | c |
| F086 | 56 | c |
| F087 | 138 | b |
| F088 | 13 | b |
| F089 | 31 | b |
| F089 | 104 | b |
| F089 | 118 | b |
| F090 | 173 | b |
| F091 | 188 | b |
| F092 | 174 | b |
| F093 | 184 | b |
| F094 | 227 | b |
| F095 | 65 | b |
| F095 | 172 | b |
| F095 | 187 | b |
| F095 | 201 | d |
| F096 | 28 | b |
| F096 | 149 | b |
| F096 | 156 | b |
| F096 | 175 | b |
| F097 | 10 | b |
| F098 | 133 | b |
| F099 | 37 | b |
| F099 | 38 | b |
| F099 | 127 | b |
| F100 | 64 | d |
| F101 | 78 | b |
| F102 | 100 | b |
| F103 | 69 | b |
| F104 | 114 | b |
| F105 | 116 | b |
| F106 | 104 | b |
| F107 | 104 | b |
| F107 | 107 | b |
| F108 | 96 | b |
| F108 | 98 | b |
| F109 | 117 | b |
| F109 | 120 | b |
| F110 | 130 | b |
| F110 | 132 | b |
| F110 | 316 | b |
| F110 | 318 | b |
| F111 | 115 | b |
| F111 | 119 | b |
| F112 | 156 | b |
| F112 | 158 | b |
| F113 | 111 | b |
| F114 | 82 | b |
| F115 | 106 | b |
| F115 | 110 | b |
| F116 | 107 | b |
| F116 | 111 | b |
| F117 | 106 | b |
| F118 | 68 | b |
| F118 | 70 | b |
| F118 | 72 | b |
| F119 | 89 | b |
| F119 | 91 | b |
| F119 | 92 | b |
| F120 | 136 | b |
| F121 | 200 | b |
| F121 | 202 | b |
| F121 | 282 | b |
| F122 | 66 | b |
| F123 | 128 | b |
| F123 | 131 | b |
| F124 | 106 | b |
| F125 | 110 | b |
| F126 | 121 | b |
| F127 | 127 | b |
| F128 | 124 | b |
| F129 | 94 | b |
| F130 | 70 | b |
| F130 | 211 | a |
| F130 | 264 | a |
| F130 | 346 | a |
| F131 | 55 | c |
| F131 | 127 | b |
| F131 | 135 | b |
| F131 | 164 | c |
| F131 | 251 | b |
| F131 | 296 | c |
| F131 | 298 | c |
| F132 | 77 | a |
| F132 | 80 | b |
| F132 | 225 | c |
| F133 | 14 | a |
| F134 | 63 | a |
| F135 | 442 | a |
| F135 | 444 | a |
| F135 | 445 | a |
| F136 | 63 | a |
| F137 | 20 | a |
| F137 | 67 | a |
| F138 | 133 | a |
| F138 | 331 | a |
| F139 | 133 | a |
| F139 | 331 | a |
| F140 | 133 | a |
| F140 | 331 | a |
| F141 | 133 | a |
| F141 | 331 | a |
| F142 | 133 | a |
| F142 | 331 | a |
| F143 | 133 | a |
| F143 | 331 | a |
| F144 | 55 | a |
| F145 | 34 | a |
| F146 | 63 | a |
| F146 | 65 | a |
| F146 | 67 | a |
| F147 | 9 | a |
| F148 | 28 | a |
| F149 | 157 | a |
| F149 | 159 | a |
| F149 | 160 | a |
| F150 | 28 | a |
| F151 | 114 | a |
| F152 | 141 | a |
| F153 | 965 | a |
| F153 | 967 | a |
| F153 | 968 | a |
| F154 | 39 | a |
| F155 | 506 | a |
| F156 | 14 | a |
| F156 | 15 | a |
| F156 | 16 | a |
| F156 | 17 | a |
| F156 | 18 | a |
| F156 | 19 | a |
| F156 | 20 | a |
| F156 | 21 | a |
| F156 | 22 | a |
| F156 | 23 | a |
| F157 | 1678 | a |
| F157 | 1679 | a |
| F157 | 1680 | a |
| F157 | 1681 | a |
| F157 | 1682 | a |
| F157 | 1683 | a |
| F157 | 1684 | a |
| F157 | 1685 | a |
| F157 | 1686 | a |
| F157 | 1687 | a |
| F158 | 1703 | a |
| F158 | 12178 | a |
| F158 | 12183 | a |
| F158 | 12188 | a |
| F158 | 12193 | a |
| F158 | 12198 | a |
| F158 | 12203 | a |
| F158 | 12208 | a |
| F158 | 12213 | a |
| F158 | 12218 | a |
| F158 | 12223 | a |
| F158 | 12228 | a |
| F158 | 12233 | a |
| F158 | 12238 | a |
| F158 | 12243 | a |
| F158 | 12248 | a |
| F158 | 12253 | a |
| F158 | 12258 | a |
| F158 | 12263 | a |
| F158 | 12268 | a |
| F158 | 12273 | a |
| F158 | 12278 | a |
| F158 | 12283 | a |
| F158 | 12288 | a |
| F158 | 12293 | a |
| F158 | 12298 | a |
| F158 | 12303 | a |
| F158 | 12308 | a |
| F158 | 12313 | a |
| F158 | 12318 | a |
| F158 | 12323 | a |
| F158 | 12328 | a |
| F158 | 12333 | a |
| F158 | 12338 | a |
| F158 | 12343 | a |
| F158 | 12348 | a |
| F158 | 12353 | a |
| F158 | 12358 | a |
| F158 | 12363 | a |
| F158 | 12368 | a |
| F158 | 12373 | a |
| F158 | 21163 | b |
| F158 | 21168 | b |
| F158 | 21198 | b |
| F158 | 21203 | b |
| F158 | 21208 | b |
| F159 | 1703 | a |
| F159 | 12178 | a |
| F159 | 12183 | a |
| F159 | 12188 | a |
| F159 | 12193 | a |
| F159 | 12198 | a |
| F159 | 12203 | a |
| F159 | 12208 | a |
| F159 | 12213 | a |
| F159 | 12218 | a |
| F159 | 12223 | a |
| F159 | 12228 | a |
| F159 | 12233 | a |
| F159 | 12238 | a |
| F159 | 12243 | a |
| F159 | 12248 | a |
| F159 | 12253 | a |
| F159 | 12258 | a |
| F159 | 12263 | a |
| F159 | 12268 | a |
| F159 | 12273 | a |
| F159 | 12278 | a |
| F159 | 12283 | a |
| F159 | 12288 | a |
| F159 | 12293 | a |
| F159 | 12298 | a |
| F159 | 12303 | a |
| F159 | 12308 | a |
| F159 | 12313 | a |
| F159 | 12318 | a |
| F159 | 12323 | a |
| F159 | 12328 | a |
| F159 | 12333 | a |
| F159 | 12338 | a |
| F159 | 12343 | a |
| F159 | 12348 | a |
| F159 | 12353 | a |
| F159 | 12358 | a |
| F159 | 12363 | a |
| F159 | 12368 | a |
| F159 | 12373 | a |
| F159 | 21163 | b |
| F159 | 21168 | b |
| F159 | 21198 | b |
| F159 | 21203 | b |
| F159 | 21208 | b |
| F160 | 10 | a |
| F161 | 64 | b |
| F161 | 65 | b |
| F162 | 137 | b |
| F163 | 39 | b |
| F163 | 40 | b |
| F163 | 56 | b |
| F164 | 7 | b |
| F164 | 10 | b |
| F164 | 60 | b |
| F164 | 63 | b |
| F165 | 1693 | a |
| F165 | 1694 | a |
| F165 | 1695 | a |
| F165 | 1696 | a |
| F165 | 1697 | a |
| F165 | 1698 | a |
| F165 | 1699 | a |
| F165 | 1700 | a |
| F165 | 1701 | a |
| F165 | 1702 | a |
| F166 | 1703 | a |
| F166 | 12178 | a |
| F166 | 12183 | a |
| F166 | 12188 | a |
| F166 | 12193 | a |
| F166 | 12198 | a |
| F166 | 12203 | a |
| F166 | 12208 | a |
| F166 | 12213 | a |
| F166 | 12218 | a |
| F166 | 12223 | a |
| F166 | 12228 | a |
| F166 | 12233 | a |
| F166 | 12238 | a |
| F166 | 12243 | a |
| F166 | 12248 | a |
| F166 | 12253 | a |
| F166 | 12258 | a |
| F166 | 12263 | a |
| F166 | 12268 | a |
| F166 | 12273 | a |
| F166 | 12278 | a |
| F166 | 12283 | a |
| F166 | 12288 | a |
| F166 | 12293 | a |
| F166 | 12298 | a |
| F166 | 12303 | a |
| F166 | 12308 | a |
| F166 | 12313 | a |
| F166 | 12318 | a |
| F166 | 12323 | a |
| F166 | 12328 | a |
| F166 | 12333 | a |
| F166 | 12338 | a |
| F166 | 12343 | a |
| F166 | 12348 | a |
| F166 | 12353 | a |
| F166 | 12358 | a |
| F166 | 12363 | a |
| F166 | 12368 | a |
| F166 | 12373 | a |
| F167 | 141 | a |
| F168 | 141 | a |
| F169 | 17 | a |
| F169 | 174 | c |
| F170 | 48 | a |
| F171 | 8 | a |
| F172 | 20 | b |
| F173 | 630 | a |
| F173 | 632 | a |
| F173 | 633 | a |
| F174 | 7 | a |
| F174 | 64 | a |
| F174 | 202 | a |
| F175 | 7 | a |
| F175 | 19 | a |
| F176 | 630 | a |
| F176 | 632 | a |
| F176 | 633 | a |
| F177 | 34 | a |
| F177 | 35 | a |
| F177 | 72 | a |
| F178 | 1 | a |
| F179 | 8 | a |
| F179 | 89 | a |
| F179 | 1173 | a |
| F180 | 19 | a |
| F181 | 3 | a |
| F182 | 16 | a |
| F182 | 43 | a |
| F183 | 38 | a |
| F183 | 115 | a |
| F183 | 226 | a |
| F183 | 227 | a |
| F184 | 43 | a |
| F185 | 19 | a |
| F186 | 34 | b |
| F186 | 35 | b |
| F186 | 40 | b |
| F187 | 16 | b |
| F188 | 19 | a |
| F189 | 48 | b |
| F189 | 56 | a |
| F189 | 131 | b |
| F190 | 45 | b |
| F190 | 48 | b |
| F191 | 27 | a |
| F192 | 5 | b |
| F192 | 8 | b |
| F193 | 34 | a |
| F193 | 85 | b |
| F194 | 1720 | a |
| F194 | 12200 | a |
| F194 | 12205 | a |
| F194 | 12210 | a |
| F194 | 12215 | a |
| F194 | 12220 | a |
| F194 | 12225 | a |
| F194 | 12230 | a |
| F194 | 12235 | a |
| F194 | 12240 | a |
| F194 | 12245 | a |
| F194 | 12250 | a |
| F194 | 12255 | a |
| F194 | 12260 | a |
| F194 | 12265 | a |
| F194 | 12270 | a |
| F194 | 12275 | a |
| F194 | 12280 | a |
| F194 | 12285 | a |
| F194 | 12290 | a |
| F194 | 12295 | a |
| F194 | 12300 | a |
| F194 | 12305 | a |
| F194 | 12310 | a |
| F194 | 12315 | a |
| F194 | 12320 | a |
| F194 | 12325 | a |
| F194 | 12330 | a |
| F194 | 12335 | a |
| F194 | 12340 | a |
| F194 | 12345 | a |
| F194 | 12350 | a |
| F194 | 12355 | a |
| F194 | 12360 | a |
| F194 | 12365 | a |
| F194 | 12370 | a |
| F194 | 12375 | a |
| F194 | 12380 | a |
| F194 | 12385 | a |
| F194 | 12390 | a |
| F194 | 12395 | a |
| F194 | 21195 | b |
| F194 | 21200 | b |
| F194 | 21230 | b |
| F194 | 21235 | b |
| F194 | 21240 | b |
| F195 | 521 | a |
| F196 | 10 | a |
| F197 | 10 | a |
| F198 | 1384 | a |
| F198 | 9768 | a |
| F198 | 9772 | a |
| F198 | 9776 | a |
| F198 | 9780 | a |
| F198 | 9784 | a |
| F198 | 9788 | a |
| F198 | 9792 | a |
| F198 | 9796 | a |
| F198 | 9800 | a |
| F198 | 9804 | a |
| F198 | 9808 | a |
| F198 | 9812 | a |
| F198 | 9816 | a |
| F198 | 9820 | a |
| F198 | 9824 | a |
| F198 | 9828 | a |
| F198 | 9832 | a |
| F198 | 9836 | a |
| F198 | 9840 | a |
| F198 | 9844 | a |
| F198 | 9848 | a |
| F198 | 9852 | a |
| F198 | 9856 | a |
| F198 | 9860 | a |
| F198 | 9864 | a |
| F198 | 9868 | a |
| F198 | 9872 | a |
| F198 | 9876 | a |
| F198 | 9880 | a |
| F198 | 9884 | a |
| F198 | 9888 | a |
| F198 | 9892 | a |
| F198 | 9896 | a |
| F198 | 9900 | a |
| F198 | 9904 | a |
| F198 | 9908 | a |
| F198 | 9912 | a |
| F198 | 9916 | a |
| F198 | 9920 | a |
| F198 | 9924 | a |
| F198 | 16976 | b |
| F198 | 16980 | b |
| F198 | 17004 | b |
| F198 | 17008 | b |
| F198 | 17012 | b |
| F199 | 1 | a |
| F200 | 1 | a |
| F201 | 1 | a |
| F202 | 1 | a |
| F203 | 1 | a |
| F204 | 1 | a |
| F205 | 1 | a |
| F206 | 1 | a |
| F207 | 1 | a |
| F208 | 1 | a |
| F209 | 1 | a |
| F210 | 1 | a |
| F211 | 1 | a |
| F212 | 1 | a |
| F213 | 1 | a |
| F214 | 1 | a |
| F215 | 1 | a |
| F216 | 1 | a |
| F217 | 1 | a |
| F218 | 1 | a |
| F219 | 1 | a |
| F220 | 1 | a |
| F221 | 1 | a |
| F222 | 1 | a |
| F223 | 1 | a |
| F224 | 1 | a |
| F225 | 1 | a |
| F226 | 1 | a |
| F227 | 1 | a |
| F228 | 1 | a |
| F229 | 1 | a |
| F230 | 1 | a |
| F231 | 1 | a |
| F232 | 1 | a |
| F233 | 1 | a |
| F234 | 1 | a |
| F235 | 1 | a |
| F236 | 1 | a |
| F237 | 1 | a |
| F238 | 1 | a |
| F239 | 1 | a |
| F240 | 1 | a |
| F241 | 1 | a |
| F242 | 1 | a |
| F243 | 1 | a |
| F244 | 1 | a |
| F245 | 1 | a |
| F246 | 1 | a |
| F247 | 1 | a |
| F248 | 1 | a |
| F249 | 1 | a |
| F250 | 1 | a |
| F251 | 1 | a |
| F252 | 1 | a |
| F253 | 1 | a |
| F254 | 1 | a |
| F255 | 1 | a |
| F256 | 1 | a |
| F257 | 1 | a |
| F258 | 1 | a |
| F259 | 4 | b |
| F259 | 10 | b |
| F259 | 14 | b |
| F259 | 18 | b |
| F259 | 22 | b |
| F260 | 1387 | a |
| F260 | 9771 | a |
| F260 | 9775 | a |
| F260 | 9779 | a |
| F260 | 9783 | a |
| F260 | 9787 | a |
| F260 | 9791 | a |
| F260 | 9795 | a |
| F260 | 9799 | a |
| F260 | 9803 | a |
| F260 | 9807 | a |
| F260 | 9811 | a |
| F260 | 9815 | a |
| F260 | 9819 | a |
| F260 | 9823 | a |
| F260 | 9827 | a |
| F260 | 9831 | a |
| F260 | 9835 | a |
| F260 | 9839 | a |
| F260 | 9843 | a |
| F260 | 9847 | a |
| F260 | 9851 | a |
| F260 | 9855 | a |
| F260 | 9859 | a |
| F260 | 9863 | a |
| F260 | 9867 | a |
| F260 | 9871 | a |
| F260 | 9875 | a |
| F260 | 9879 | a |
| F260 | 9883 | a |
| F260 | 9887 | a |
| F260 | 9891 | a |
| F260 | 9895 | a |
| F260 | 9899 | a |
| F260 | 9903 | a |
| F260 | 9907 | a |
| F260 | 9911 | a |
| F260 | 9915 | a |
| F260 | 9919 | a |
| F260 | 9923 | a |
| F260 | 9927 | a |
| F260 | 16979 | b |
| F260 | 16983 | b |
| F260 | 17007 | b |
| F260 | 17011 | b |
| F260 | 17015 | b |
| F261 | 1 | a |
| F262 | 1 | a |
| F263 | 1 | a |
| F264 | 1 | a |
| F265 | 1 | a |
| F266 | 1 | a |
| F267 | 1 | a |
| F268 | 1 | a |
| F269 | 1 | a |
| F270 | 1 | a |
| F271 | 1 | a |
| F272 | 1 | a |
| F273 | 1 | a |
| F274 | 1 | a |
| F275 | 1 | a |
| F276 | 1 | a |
| F277 | 1 | a |
| F278 | 1 | a |
| F279 | 1 | a |
| F280 | 1 | a |
| F281 | 1 | a |
| F282 | 1 | a |
| F283 | 1 | a |
| F284 | 1 | a |
| F285 | 1 | a |
| F286 | 1 | a |
| F287 | 1 | a |
| F288 | 1 | a |
| F289 | 1 | a |
| F290 | 1 | a |
| F291 | 1 | a |
| F292 | 1 | a |
| F293 | 1 | a |
| F294 | 1 | a |
| F295 | 1 | a |
| F296 | 1 | a |
| F297 | 1 | a |
| F298 | 1 | a |
| F299 | 1 | a |
| F300 | 1 | a |
| F301 | 1 | a |
| F302 | 1 | a |
| F303 | 1 | a |
| F304 | 1 | a |
| F305 | 1 | a |
| F306 | 1 | a |
| F307 | 1 | a |
| F308 | 1 | a |
| F309 | 1 | a |
| F310 | 1 | a |
| F311 | 1 | a |
| F312 | 1 | a |
| F313 | 1 | a |
| F314 | 1 | a |
| F315 | 1 | a |
| F316 | 1 | a |
| F317 | 1 | a |
| F318 | 1 | a |
| F319 | 1 | a |
| F320 | 1 | a |
| F321 | 1387 | a |
| F321 | 9771 | a |
| F321 | 9775 | a |
| F321 | 9779 | a |
| F321 | 9783 | a |
| F321 | 9787 | a |
| F321 | 9791 | a |
| F321 | 9795 | a |
| F321 | 9799 | a |
| F321 | 9803 | a |
| F321 | 9807 | a |
| F321 | 9811 | a |
| F321 | 9815 | a |
| F321 | 9819 | a |
| F321 | 9823 | a |
| F321 | 9827 | a |
| F321 | 9831 | a |
| F321 | 9835 | a |
| F321 | 9839 | a |
| F321 | 9843 | a |
| F321 | 9847 | a |
| F321 | 9851 | a |
| F321 | 9855 | a |
| F321 | 9859 | a |
| F321 | 9863 | a |
| F321 | 9867 | a |
| F321 | 9871 | a |
| F321 | 9875 | a |
| F321 | 9879 | a |
| F321 | 9883 | a |
| F321 | 9887 | a |
| F321 | 9891 | a |
| F321 | 9895 | a |
| F321 | 9899 | a |
| F321 | 9903 | a |
| F321 | 9907 | a |
| F321 | 9911 | a |
| F321 | 9915 | a |
| F321 | 9919 | a |
| F321 | 9923 | a |
| F321 | 9927 | a |
| F321 | 16979 | b |
| F321 | 16983 | b |
| F321 | 17007 | b |
| F321 | 17011 | b |
| F321 | 17015 | b |
| F322 | 48 | b |
| F322 | 49 | b |
| F323 | 70 | c |
| F324 | 1384 | a |
| F324 | 9768 | a |
| F324 | 9772 | a |
| F324 | 9776 | a |
| F324 | 9780 | a |
| F324 | 9784 | a |
| F324 | 9788 | a |
| F324 | 9792 | a |
| F324 | 9796 | a |
| F324 | 9800 | a |
| F324 | 9804 | a |
| F324 | 9808 | a |
| F324 | 9812 | a |
| F324 | 9816 | a |
| F324 | 9820 | a |
| F324 | 9824 | a |
| F324 | 9828 | a |
| F324 | 9832 | a |
| F324 | 9836 | a |
| F324 | 9840 | a |
| F324 | 9844 | a |
| F324 | 9848 | a |
| F324 | 9852 | a |
| F324 | 9856 | a |
| F324 | 9860 | a |
| F324 | 9864 | a |
| F324 | 9868 | a |
| F324 | 9872 | a |
| F324 | 9876 | a |
| F324 | 9880 | a |
| F324 | 9884 | a |
| F324 | 9888 | a |
| F324 | 9892 | a |
| F324 | 9896 | a |
| F324 | 9900 | a |
| F324 | 9904 | a |
| F324 | 9908 | a |
| F324 | 9912 | a |
| F324 | 9916 | a |
| F324 | 9920 | a |
| F324 | 9924 | a |
| F324 | 16976 | b |
| F324 | 16980 | b |
| F324 | 17004 | b |
| F324 | 17008 | b |
| F324 | 17012 | b |
| F325 | 43 | b |
| F325 | 44 | b |
| F326 | 31 | c |
| F327 | 20 | d |
| F328 | 11 | b |
| F328 | 13 | a |
| F329 | 12 | b |
| F330 | 12 | a |
| F331 | 3 | a |
| F332 | 25 | c |
| F333 | 21 | b |
| F333 | 39 | c |
| F334 | 14 | b |
| F334 | 15 | b |
| F334 | 16 | b |
| F335 | 31 | c |
| F336 | 23 | b |
| F337 | 53 | b |
| F338 | 205 | d |
| F338 | 206 | d |
| F339 | 4 | d |
| F339 | 10 | d |
| F339 | 11 | d |
| F339 | 12 | d |
| F339 | 13 | d |
| F339 | 16 | d |
| F339 | 22 | d |
| F340 | 145 | d |
| F340 | 146 | d |
| F340 | 147 | d |
| F340 | 148 | d |
| F340 | 153 | c |
| F341 | 23 | d |
| F341 | 48 | d |
| F342 | 47 | d |
| F343 | 4 | d |
| F344 | 4 | d |
| F345 | 4 | d |
| F346 | 35 | d |
| F347 | 4 | d |
| F348 | 7 | d |
| F348 | 8 | d |
| F348 | 9 | d |
| F348 | 10 | d |
| F348 | 11 | d |
| F348 | 12 | d |
| F348 | 13 | d |
| F348 | 15 | d |
| F348 | 16 | d |
| F348 | 17 | d |
| F348 | 18 | d |
| F348 | 19 | d |
| F348 | 24 | d |
| F349 | 17 | d |
| F350 | 77 | d |
| F350 | 78 | d |
| F350 | 79 | d |
| F350 | 80 | d |
| F350 | 82 | d |
| F350 | 83 | d |
| F350 | 84 | d |
| F350 | 85 | d |
| F351 | 4 | d |
| F352 | 32 | d |
| F353 | 16 | d |
| F354 | 4 | d |
| F355 | 4 | d |
| F356 | 4 | d |
| F357 | 4 | d |
| F358 | 28 | d |
| F359 | 4 | d |
| F360 | 4 | d |
| F361 | 4 | d |
| F362 | 4 | d |
| F363 | 4 | d |
| F364 | 17 | d |
| F365 | 34 | d |
| F366 | 30 | d |
| F366 | 131 | c |
| F367 | 102 | d |
| F367 | 250 | c |
| F368 | 4 | d |
| F369 | 222 | d |
| F369 | 223 | d |
| F370 | 7 | d |
| F370 | 13 | d |
| F370 | 14 | d |
| F370 | 15 | d |
| F370 | 17 | d |
| F370 | 20 | d |
| F371 | 23 | a |
| F372 | 471 | b |
| F372 | 855 | b |
| F372 | 859 | d |
| F372 | 866 | c |
| F373 | 509 | c |
| F374 | 9 | c |
| F374 | 15 | d |
| F374 | 126 | d |
| F374 | 387 | a |
| F374 | 399 | d |
| F374 | 601 | d |
| F374 | 744 | d |
| F375 | 13 | c |
| F376 | 27 | d |
| F377 | 327 | b |
| F378 | 61 | b |
| F378 | 376 | b |
| F379 | 194 | d |
| F380 | 1 | a |
| F381 | 1196 | b |
| F381 | 1264 | b |
| F381 | 1276 | b |
| F381 | 1337 | b |
| F381 | 1366 | b |
| F381 | 1374 | b |
| F381 | 1461 | b |
| F381 | 1474 | b |
| F381 | 1479 | b |
| F381 | 1497 | b |
| F381 | 1541 | b |
| F381 | 1546 | b |
| F382 | 148 | b |
| F382 | 149 | b |
| F382 | 150 | b |
| F382 | 151 | b |
| F383 | 1 | a |
| F384 | 165 | b |
| F385 | 59 | b |
| F385 | 60 | b |
| F385 | 61 | b |
| F386 | 1 | a |
| F387 | 1 | a |
| F388 | 45 | b |
| F388 | 48 | b |
| F388 | 51 | b |
| F388 | 54 | b |
| F389 | 2773 | b |
| F389 | 2779 | b |
| F389 | 2815 | b |
| F389 | 2821 | b |
| F390 | 12 | c |
| F391 | 216 | c |
| F391 | 217 | c |
| F392 | 16 | b |
| F392 | 17 | b |
| F392 | 64 | b |
| F392 | 65 | b |
| F393 | 656 | a |
| F394 | 43 | b |
| F394 | 64 | b |
| F395 | 8 | b |
| F395 | 9 | b |
| F396 | 6 | b |
| F396 | 17 | b |
| F396 | 28 | b |
| F396 | 39 | b |
| F396 | 50 | b |
| F396 | 61 | b |
| F396 | 72 | b |
| F396 | 83 | b |
| F396 | 94 | b |
| F396 | 105 | b |
| F396 | 116 | b |
| F396 | 127 | b |
| F396 | 138 | b |
| F396 | 149 | b |
| F397 | 3 | b |
| F398 | 13 | b |
| F398 | 17 | a |
| F398 | 22 | a |
| F398 | 32 | b |
| F398 | 33 | b |
| F399 | 9 | b |
| F399 | 95 | b |
| F399 | 96 | b |
| F399 | 97 | b |
| F400 | 78 | b |
| F400 | 79 | b |
| F400 | 80 | b |
| F401 | 7 | b |
| F401 | 8 | b |
| F401 | 12 | b |
| F401 | 13 | b |
| F401 | 17 | b |
| F401 | 18 | b |
| F401 | 22 | b |
| F401 | 23 | b |
| F401 | 27 | b |
| F401 | 28 | b |
| F401 | 32 | b |
| F401 | 33 | b |
| F401 | 37 | b |
| F401 | 38 | b |
| F401 | 42 | b |
| F401 | 43 | b |
| F401 | 47 | b |
| F401 | 48 | b |
| F401 | 52 | b |
| F401 | 53 | b |
| F401 | 57 | b |
| F401 | 58 | b |
| F401 | 62 | b |
| F401 | 63 | b |
| F401 | 67 | b |
| F401 | 68 | b |
| F401 | 72 | b |
| F401 | 73 | b |
| F401 | 77 | b |
| F401 | 78 | b |
| F401 | 82 | b |
| F401 | 83 | b |
| F401 | 87 | b |
| F401 | 88 | b |
| F401 | 92 | b |
| F401 | 93 | b |
| F401 | 97 | b |
| F401 | 98 | b |
| F401 | 102 | b |
| F401 | 103 | b |
| F401 | 107 | b |
| F401 | 108 | b |
| F401 | 112 | b |
| F401 | 113 | b |
| F401 | 117 | b |
| F401 | 118 | b |
| F401 | 122 | b |
| F401 | 123 | b |
| F401 | 127 | b |
| F401 | 128 | b |
| F401 | 132 | b |
| F401 | 133 | b |
| F401 | 137 | b |
| F401 | 138 | b |
| F401 | 142 | b |
| F401 | 143 | b |
| F401 | 147 | b |
| F401 | 148 | b |
| F401 | 152 | b |
| F401 | 153 | b |
| F401 | 157 | b |
| F401 | 158 | b |
| F401 | 162 | b |
| F401 | 163 | b |
| F401 | 167 | b |
| F401 | 168 | b |
| F401 | 172 | b |
| F401 | 173 | b |
| F401 | 177 | b |
| F401 | 178 | b |
| F401 | 182 | b |
| F401 | 183 | b |
| F401 | 187 | b |
| F401 | 188 | b |
| F401 | 192 | b |
| F401 | 193 | b |
| F401 | 197 | b |
| F401 | 198 | b |
| F401 | 202 | b |
| F401 | 203 | b |
| F401 | 207 | b |
| F401 | 208 | b |
| F401 | 212 | b |
| F401 | 213 | b |
| F401 | 217 | b |
| F401 | 218 | b |
| F401 | 222 | b |
| F401 | 223 | b |
| F401 | 227 | b |
| F401 | 228 | b |
| F401 | 232 | b |
| F401 | 233 | b |
| F401 | 237 | b |
| F401 | 238 | b |
| F401 | 242 | b |
| F401 | 243 | b |
| F401 | 247 | b |
| F401 | 248 | b |
| F401 | 252 | b |
| F401 | 253 | b |
| F401 | 257 | b |
| F401 | 258 | b |
| F401 | 262 | b |
| F401 | 263 | b |
| F401 | 267 | b |
| F401 | 268 | b |
| F401 | 272 | b |
| F401 | 273 | b |
| F401 | 277 | b |
| F401 | 278 | b |
| F401 | 282 | b |
| F401 | 283 | b |
| F401 | 287 | b |
| F401 | 288 | b |
| F401 | 292 | b |
| F401 | 293 | b |
| F401 | 297 | b |
| F401 | 298 | b |
| F401 | 302 | b |
| F401 | 303 | b |
| F401 | 307 | b |
| F401 | 308 | b |
| F401 | 312 | b |
| F401 | 313 | b |
| F401 | 317 | b |
| F401 | 318 | b |
| F401 | 322 | b |
| F401 | 323 | b |
| F401 | 327 | b |
| F401 | 328 | b |
| F401 | 332 | b |
| F401 | 333 | b |
| F401 | 337 | b |
| F401 | 338 | b |
| F401 | 342 | b |
| F401 | 343 | b |
| F401 | 347 | b |
| F401 | 348 | b |
| F401 | 352 | b |
| F401 | 353 | b |
| F401 | 357 | b |
| F401 | 358 | b |
| F401 | 362 | b |
| F401 | 367 | b |
| F401 | 368 | b |
| F401 | 372 | b |
| F401 | 377 | b |
| F401 | 382 | b |
| F401 | 383 | b |
| F401 | 387 | b |
| F401 | 392 | b |
| F401 | 397 | b |
| F401 | 402 | b |
| F401 | 407 | b |
| F401 | 412 | b |
| F401 | 413 | b |
| F401 | 417 | b |
| F401 | 418 | b |
| F401 | 422 | b |
| F401 | 427 | b |
| F401 | 432 | b |
| F401 | 437 | b |
| F401 | 442 | b |
| F401 | 447 | b |
| F401 | 452 | b |
| F401 | 453 | b |
| F401 | 457 | b |
| F401 | 458 | b |
| F401 | 462 | b |
| F401 | 463 | b |
| F401 | 467 | b |
| F401 | 468 | b |
| F401 | 472 | b |
| F401 | 473 | b |
| F401 | 477 | b |
| F401 | 478 | b |
| F401 | 482 | b |
| F401 | 483 | b |
| F401 | 487 | b |
| F401 | 488 | b |
| F401 | 492 | b |
| F401 | 493 | b |
| F401 | 497 | b |
| F401 | 502 | b |
| F401 | 503 | b |
| F401 | 507 | b |
| F401 | 512 | b |
| F401 | 513 | b |
| F401 | 517 | b |
| F401 | 522 | b |
| F401 | 523 | b |
| F401 | 527 | b |
| F401 | 532 | b |
| F401 | 537 | b |
| F401 | 542 | b |
| F401 | 543 | b |
| F401 | 547 | b |
| F401 | 548 | b |
| F401 | 552 | b |
| F401 | 553 | b |
| F401 | 1570 | b |
| F401 | 1576 | b |
| F401 | 1582 | b |
| F401 | 1588 | b |
| F401 | 1594 | b |
| F401 | 1600 | b |
| F401 | 1606 | b |
| F401 | 1612 | b |
| F401 | 1618 | b |
| F401 | 1624 | b |
| F401 | 1630 | b |
| F401 | 1636 | b |
| F401 | 1642 | b |
| F401 | 1648 | b |
| F401 | 1662 | b |
| F402 | 109 | b |
| F402 | 115 | b |
| F402 | 121 | b |
| F402 | 127 | b |
| F402 | 133 | b |
| F402 | 139 | b |
| F402 | 145 | b |
| F402 | 151 | b |
| F402 | 157 | b |
| F402 | 163 | b |
| F402 | 169 | b |
| F402 | 175 | b |
| F402 | 181 | b |
| F402 | 187 | b |
| F402 | 193 | b |
| F402 | 199 | b |
| F403 | 3 | b |
| F403 | 5 | b |
| F403 | 10 | b |
| F403 | 12 | b |
| F403 | 17 | b |
| F403 | 19 | b |
| F403 | 24 | b |
| F403 | 26 | b |
| F403 | 31 | b |
| F403 | 33 | b |
| F403 | 38 | b |
| F403 | 40 | b |
| F403 | 45 | b |
| F403 | 47 | b |
| F403 | 52 | b |
| F403 | 54 | b |
| F403 | 59 | b |
| F403 | 61 | b |
| F403 | 66 | b |
| F403 | 68 | b |
| F403 | 73 | b |
| F403 | 75 | b |
| F403 | 80 | b |
| F403 | 82 | b |
| F403 | 87 | b |
| F403 | 89 | b |
| F404 | 7 | b |
| F404 | 8 | b |
| F404 | 17 | b |
| F404 | 29 | b |
| F405 | 123 | b |
| F405 | 124 | b |
| F405 | 130 | b |
| F405 | 131 | b |
| F406 | 48 | a |
| F407 | 78 | b |
| F408 | 49 | b |
| F408 | 72 | b |
| F409 | 89 | b |
| F409 | 90 | b |
| F409 | 93 | b |
| F409 | 94 | b |
| F409 | 478 | b |
| F409 | 483 | b |
| F409 | 513 | b |
| F409 | 518 | b |
| F410 | 71 | b |
| F410 | 80 | b |
| F411 | 22 | b |
| F411 | 27 | b |
| F411 | 32 | b |
| F411 | 37 | b |
| F412 | 16 | b |
| F412 | 178 | a |
| F413 | 4 | b |
| F413 | 5 | b |
| F413 | 14 | b |
| F413 | 15 | b |
| F413 | 76 | b |
| F413 | 78 | b |
| F413 | 83 | b |
| F413 | 85 | b |
| F413 | 90 | b |
| F413 | 92 | b |
| F413 | 97 | b |
| F413 | 99 | b |
| F413 | 104 | b |
| F413 | 106 | b |
| F413 | 111 | b |
| F413 | 113 | b |
| F413 | 118 | b |
| F413 | 120 | b |
| F413 | 125 | b |
| F413 | 127 | b |
| F413 | 132 | b |
| F413 | 134 | b |
| F413 | 139 | b |
| F413 | 141 | b |
| F413 | 146 | b |
| F413 | 148 | b |
| F413 | 153 | b |
| F413 | 155 | b |
| F413 | 160 | b |
| F413 | 162 | b |
| F413 | 221 | b |
| F413 | 225 | b |
| F413 | 229 | b |
| F413 | 233 | b |
| F413 | 237 | b |
| F413 | 241 | b |
| F413 | 245 | b |
| F413 | 249 | b |
| F413 | 253 | b |
| F413 | 257 | b |
| F413 | 261 | b |
| F413 | 265 | b |
| F413 | 269 | b |
| F413 | 273 | b |
| F413 | 277 | b |
| F413 | 281 | b |
| F413 | 285 | b |
| F413 | 289 | b |
| F413 | 293 | b |
| F413 | 297 | b |
| F413 | 301 | b |
| F413 | 305 | b |
| F413 | 309 | b |
| F413 | 313 | b |
| F413 | 317 | b |
| F413 | 321 | b |
| F413 | 325 | b |
| F413 | 329 | b |
| F413 | 333 | b |
| F413 | 337 | b |
| F413 | 341 | b |
| F413 | 345 | b |
| F413 | 349 | b |
| F413 | 353 | b |
| F413 | 357 | b |
| F413 | 361 | b |
| F413 | 365 | b |
| F413 | 369 | b |
| F413 | 373 | b |
| F413 | 377 | b |
| F413 | 381 | b |
| F413 | 385 | b |
| F413 | 389 | b |
| F413 | 393 | b |
| F413 | 397 | b |
| F413 | 401 | b |
| F413 | 405 | b |
| F413 | 409 | b |
| F413 | 413 | b |
| F413 | 417 | b |
| F413 | 421 | b |
| F413 | 425 | b |
| F413 | 429 | b |
| F413 | 433 | b |
| F413 | 437 | b |
| F413 | 441 | b |
| F413 | 445 | b |
| F413 | 449 | b |
| F413 | 453 | b |
| F413 | 457 | b |
| F413 | 461 | b |
| F413 | 465 | b |
| F413 | 469 | b |
| F413 | 473 | b |
| F413 | 477 | b |
| F413 | 481 | b |
| F413 | 485 | b |
| F413 | 489 | b |
| F413 | 493 | b |
| F413 | 497 | b |
| F413 | 501 | b |
| F413 | 505 | b |
| F413 | 509 | b |
| F413 | 513 | b |
| F413 | 517 | b |
| F413 | 521 | b |
| F413 | 525 | b |
| F413 | 529 | b |
| F413 | 533 | b |
| F413 | 537 | b |
| F413 | 541 | b |
| F413 | 545 | b |
| F413 | 549 | b |
| F413 | 553 | b |
| F413 | 557 | b |
| F413 | 561 | b |
| F413 | 565 | b |
| F413 | 569 | b |
| F413 | 573 | b |
| F413 | 577 | b |
| F413 | 581 | b |
| F413 | 585 | b |
| F413 | 589 | b |
| F413 | 593 | b |
| F413 | 597 | b |
| F413 | 601 | b |
| F413 | 605 | b |
| F413 | 609 | b |
| F413 | 613 | b |
| F413 | 617 | b |
| F413 | 621 | b |
| F413 | 625 | b |
| F413 | 629 | b |
| F413 | 633 | b |
| F413 | 637 | b |
| F413 | 641 | b |
| F413 | 645 | b |
| F413 | 649 | b |
| F413 | 653 | b |
| F414 | 39 | b |
| F414 | 40 | b |
| F414 | 41 | b |
| F414 | 76 | a |
| F414 | 85 | c |
| F415 | 42 | b |
| F415 | 49 | b |
| F415 | 56 | b |
| F415 | 63 | b |
| F415 | 148 | b |
| F415 | 149 | b |
| F415 | 155 | b |
| F415 | 156 | b |
| F416 | 11 | b |
| F416 | 17 | c |
| F417 | 1 | a |
| F418 | 1 | a |
| F419 | 1 | a |
| F420 | 1 | a |
| F421 | 1 | a |
| F422 | 1 | a |
| F423 | 1 | a |
| F424 | 1 | a |
| F425 | 1 | a |
| F426 | 1 | a |
| F427 | 1 | a |
| F428 | 1 | a |
| F429 | 1 | a |
| F430 | 1 | a |
| F431 | 1 | a |
| F432 | 1 | a |
| F433 | 1 | a |
| F434 | 1 | a |
| F435 | 1 | a |
| F436 | 1 | a |
| F437 | 1 | a |
| F438 | 1 | a |
| F439 | 1 | a |
| F440 | 1 | a |
| F441 | 1 | a |
| F442 | 1 | a |
| F443 | 1 | a |
| F444 | 1 | a |
| F445 | 1 | a |
| F446 | 1 | a |
| F447 | 1 | a |
| F448 | 1 | a |
| F449 | 1 | a |
| F450 | 1 | a |
| F451 | 1 | a |
| F452 | 1 | a |
| F453 | 1 | a |
| F454 | 1 | a |
| F455 | 1 | a |
| F456 | 1 | a |
| F457 | 1 | a |
| F458 | 1 | a |
| F459 | 1 | a |
| F460 | 1 | a |
| F461 | 1 | a |
| F462 | 1 | a |
| F463 | 1 | a |
| F464 | 1 | a |
| F465 | 1 | a |
| F466 | 1 | a |
| F467 | 1 | a |
| F468 | 1 | a |
| F469 | 1 | a |
| F470 | 1 | a |
| F471 | 1 | a |
| F472 | 1 | a |
| F473 | 1 | a |
| F474 | 1 | a |
| F475 | 1 | a |
| F476 | 1 | a |
| F477 | 1 | a |
| F478 | 1 | a |
| F479 | 1 | a |
| F480 | 1 | a |
| F481 | 1 | a |
| F482 | 1 | a |
| F483 | 1 | b |
| F484 | 1 | b |
| F485 | 1 | b |
| F486 | 1 | b |
| F487 | 1 | b |
| F488 | 1 | a |
| F489 | 1 | a |
| F490 | 1 | a |
| F491 | 1 | a |
| F492 | 1 | a |
| F493 | 1 | a |
| F494 | 1 | a |
| F495 | 1 | a |
| F496 | 1 | a |
| F497 | 1 | a |
| F498 | 1 | a |
| F499 | 1 | a |
| F500 | 1 | a |
| F501 | 1 | a |
| F502 | 1 | a |
| F503 | 1 | a |
| F504 | 1 | a |
| F505 | 1 | a |
| F506 | 1 | a |
| F507 | 1 | a |
| F508 | 1 | a |
| F509 | 1 | a |
| F510 | 1 | a |
| F511 | 1 | a |
| F512 | 1 | a |
| F513 | 1 | a |
| F514 | 1 | a |
| F515 | 1 | a |
| F516 | 1 | a |
| F517 | 1 | a |
| F518 | 1 | a |
| F519 | 1 | a |
| F520 | 1 | a |
| F521 | 1 | b |
| F522 | 1 | b |
| F523 | 1 | b |
| F524 | 1 | b |
| F525 | 1 | b |

# Skill の評価の記録

- 日時: 2026-10-08 22:09
- 処理系: benitoite 0.0.0
- Skill: 0.0.0 (sha256 306763a04d8e)
- ハーネス: antigravity-gemini（1.3.1）
- モデル: gemini-3.8-flash-high {"effort": "high"}
- 試行の回数: 3
- 生の記録: /private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/64b61341-f5f5-4028-85d6-1daa8642db48/scratchpad/skill-eval-main-all/antigravity-gemini（リポジトリの外）

| 課題 | 成功 / 試行 | 成功した試行の検査と修正の回数 |
|---|---|---|
| csv_report | 3 / 3 | 5, 2, 4 |
| dir_walk | 3 / 3 | 2, 2, 2 |
| error_handling | 3 / 3 | 4, 3, 5 |
| file_process | 3 / 3 | 2, 2, 2 |
| http_client | 3 / 3 | 3, 3, 4 |
| json_convert | 3 / 3 | 2, 2, 2 |
| json_summary | 3 / 3 | 9, 7, 2 |
| process_run | 3 / 3 | 2, 2, 2 |
| process_shell | 3 / 3 | 2, 2, 2 |
| regex_text | 3 / 3 | 2, 2, 2 |
| write_tests | 3 / 3 | 1, 1, 1 |

## 試行ごとの結果

| 課題 | 成功 | 回数 | 理由 |
|---|---|---|---|
| csv_report | yes | 5 | ok |
| csv_report | yes | 2 | ok |
| csv_report | yes | 4 | ok |
| dir_walk | yes | 2 | ok |
| dir_walk | yes | 2 | ok |
| dir_walk | yes | 2 | ok |
| error_handling | yes | 4 | ok |
| error_handling | yes | 3 | ok |
| error_handling | yes | 5 | ok |
| file_process | yes | 2 | ok |
| file_process | yes | 2 | ok |
| file_process | yes | 2 | ok |
| http_client | yes | 3 | ok |
| http_client | yes | 3 | ok |
| http_client | yes | 4 | ok |
| json_convert | yes | 2 | ok |
| json_convert | yes | 2 | ok |
| json_convert | yes | 2 | ok |
| json_summary | yes | 9 | ok |
| json_summary | yes | 7 | ok |
| json_summary | yes | 2 | ok |
| process_run | yes | 2 | ok |
| process_run | yes | 2 | ok |
| process_run | yes | 2 | ok |
| process_shell | yes | 2 | ok |
| process_shell | yes | 2 | ok |
| process_shell | yes | 2 | ok |
| regex_text | yes | 2 | ok |
| regex_text | yes | 2 | ok |
| regex_text | yes | 2 | ok |
| write_tests | yes | 1 | ok |
| write_tests | yes | 1 | ok |
| write_tests | yes | 1 | ok |

## 診断のコードの集計

「解消」と「残った」は、そのコードが出た起動の次の check・run・test で、コードが消えたか残ったかの回数である。「最後に残った試行の数」は、判定のときに最後のスクリプトの check（テストの課題では test）でそのコードが出た試行の数である。警告（W）は diag::codes の全件を載せ、出なかったものも 0 とする。

### antigravity-gemini（gemini-3.8-flash-high）

| コード | 出た回数 | 出た試行の数 | 解消 | 残った | 解消率 | 最後に残った試行の数 |
|---|---|---|---|---|---|---|
| W0301 | 0 | 0 | 0 | 0 | - | 0 |
| W0401 | 0 | 0 | 0 | 0 | - | 0 |
| W0402 | 0 | 0 | 0 | 0 | - | 0 |
| W0403 | 0 | 0 | 0 | 0 | - | 0 |
| W0501 | 0 | 0 | 0 | 0 | - | 0 |

### 試行ごとの最初の check のコードと最後の警告

| ハーネス | 課題 | 試行 | 最初の check | 最後の check の警告 |
|---|---|---|---|---|
| antigravity-gemini | csv_report | 1 | - | - |
| antigravity-gemini | csv_report | 2 | - | - |
| antigravity-gemini | csv_report | 3 | - | - |
| antigravity-gemini | dir_walk | 1 | - | - |
| antigravity-gemini | dir_walk | 2 | - | - |
| antigravity-gemini | dir_walk | 3 | - | - |
| antigravity-gemini | error_handling | 1 | - | - |
| antigravity-gemini | error_handling | 2 | - | - |
| antigravity-gemini | error_handling | 3 | - | - |
| antigravity-gemini | file_process | 1 | - | - |
| antigravity-gemini | file_process | 2 | - | - |
| antigravity-gemini | file_process | 3 | - | - |
| antigravity-gemini | http_client | 1 | - | - |
| antigravity-gemini | http_client | 2 | - | - |
| antigravity-gemini | http_client | 3 | - | - |
| antigravity-gemini | json_convert | 1 | - | - |
| antigravity-gemini | json_convert | 2 | - | - |
| antigravity-gemini | json_convert | 3 | - | - |
| antigravity-gemini | json_summary | 1 | - | - |
| antigravity-gemini | json_summary | 2 | - | - |
| antigravity-gemini | json_summary | 3 | - | - |
| antigravity-gemini | process_run | 1 | - | - |
| antigravity-gemini | process_run | 2 | - | - |
| antigravity-gemini | process_run | 3 | - | - |
| antigravity-gemini | process_shell | 1 | - | - |
| antigravity-gemini | process_shell | 2 | - | - |
| antigravity-gemini | process_shell | 3 | - | - |
| antigravity-gemini | regex_text | 1 | - | - |
| antigravity-gemini | regex_text | 2 | - | - |
| antigravity-gemini | regex_text | 3 | - | - |
| antigravity-gemini | write_tests | 1 | - | - |
| antigravity-gemini | write_tests | 2 | - | - |
| antigravity-gemini | write_tests | 3 | - | - |

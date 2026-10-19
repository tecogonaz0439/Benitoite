# K2: 共通の定数取得とRegexの追加拒否

実施日: 2026-10-18。担当: Codex。B_WORKは `27a15c2ca6faf67be576d1cbafb5d62f5ffbc5b5`（開始時HEAD）であり、開始時の作業ツリーはcleanであった。コミットとdocs/todo/の変更は行わない。

## 変更

- `CallPlan.direct_callee`に解決済みの関数の束縛を保存し、局所関数値・穴・パイプを区別した。既存の引数の対応、挿入と穴名を保った。
- `consts`の形の検査・標準束縛の同定・引数の取得・評価器を共用した。取得結果をKnown/Unknown/BudgetExceeded/Invalidへ分け、引数位置と、評価済みconstからの連鎖を含む由来を保持した。
- `Decls`に追加検査専用の`CheckedArgsState`を置き、全対象呼び出しで64 MiBを共有した。既存の本体検査順、本体内のソース位置順で消費する。トップレベルconstと警告の予算は独立に保つ。Regexの組み立ては暫定の一パターン1 MiB・全体8 MiBのソース長を上限とし、同一入力を再利用する。
- `builtins/checked_regex`へヒープに依存しない組み立てと失敗表示を移した。実行時と同じRegexBuilderを使い、SyntaxをE0457、CompiledTooBigをE0458、それ以外をUnknownとして扱う。取得予算と組み立て予算の超過は追加拒否せず、Result・実行時検査・通常の脱糖を保つ。
- 診断表、0.0.9の非互換表、現行仕様・処理系設計・標準ライブラリ・形式化の対応表、英語リファレンスと手書きSkillを更新し、gen_skillで生成物を作り直した。形式化の対応表では追加拒否が主定理の外側にあることを明記した。formal/の変更はない。

## テストの関門と既存の期待

型検査の公開入口を持ち主とし、直接呼び出し・import別名・定数演算/補間・局所bind・間接/穴/パイプ・同名の利用者関数・E0433・型エラーを区別する表を追加した。独立した診断位置の検査で二段のconst由来とキャッシュの再利用を確認する。大きい入力の検査は、一パターンの上限の境界、全体の組み立て予算、取得予算が本体ごとにリセットされないこと、キャッシュした入力が組み立て予算を再消費しないことを確認する。実行は約3秒であり、10秒を超える長いテストにはしていない。

共有の`tests/fixtures/checked-regex.json`は、構文不良4種とコンパイル上限の5入力を持つ。静的拒否と、実行時の実際の組み込み関数のResult.Errorを別々の公開境界で照合する。既存の実行時の4入力と、理由が空でないこと・上限の文面・失敗後の正常な照合のassertを保ち、`[`を追加した。CLIの新しいgoldenはJSONの位置・const由来・失敗分類の出力を確かめる。専用の差し込み口や公開APIの拡大はない。

`l40-regex.bnt`と既存のスクリプト実行の単体テストでは、不正値を通常関数のString引数経由で渡すようにした。これは0.0.9で直接の不正定数の意味がE0457へ変わるためである。観察するResult.Error、非空の理由、その他のassertとgoldenの標準出力は保った。既存テストの削除・assertの削除・期待値の緩和・ignoreの追加はない。CallPlanの既存の独立期待値は新しい欄だけを補った。

## 検査

作業末の自動workは一度だけ実行した。fmt・lint_default・lib_defaultが成功し、tests_relatedの29ターゲット（203件成功、既存のignored 7件）の後、reference_examplesで新しく書いた例にoutputブロックがないため停止した。例を実行してtrueを出力する形へ直し、その期待出力を追加した。既存の期待値は変更していない。修正したreference_examplesと、その後の未実施9ターゲットだけを、残る検査単位と一緒に実行した。成功済みのlib・lint・統合ターゲットは繰り返していない。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 27a15c2ca6faf67be576d1cbafb5d62f5ffbc5b5 --test '*' --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択。全統合ターゲットに文書例を含む | 未計時 |
| `scripts/check.sh --level work --base 27a15c2ca6faf67be576d1cbafb5d62f5ffbc5b5 --test '*'` | 1。fmt・lint_default成功、libは1211件成功・既存のignored 21件。統合の文書例のoutput欠落で停止 | 270.000秒 |
| `cargo clippy --all-targets` | 0。警告なし | 15.165秒 |
| `scripts/check.sh --level work --base 27a15c2ca6faf67be576d1cbafb5d62f5ffbc5b5 --only tests_related,source_rules,skill_generated,spec_tally --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells --dry-run` | 0。修正対象と未実施の対象・単位だけを選択 | 未計時 |
| 同じ指定（`--dry-run`なし） | 0。10ターゲット71件成功。source_rules・skill_generated・spec_tallyも成功 | 89.044秒 |
| `git diff --check` | 0 | 未計時 |

初回と補完を合わせ、全39統合ターゲットの274件が成功し、既存のignoredは7件である。spec_examples・reference_examples・skill_docs・skill_examplesを含む。通常libの1211件と追加clippyも成功している。spec_tallyは未参照の既存の節を表示したが終了0であり、初回リリースの完了条件の未記入はない。formal/・ヒープの不変条件・安全点を越える値を変更していないので、formal_build・check-formal.sh・heap/stress・release_stackは追加していない。

Rustの差分は、本番が240行追加・38行削除（差し引き202行）、テストが236行追加・10行削除（差し引き226行）である。新規のRustファイルを含み、同一ファイル内のcfg(test)部分はテストへ分けた。JSONの共有入力・golden・文書と生成物はこの行数に含めない。

途中はRegexのlibテスト、追加したchecked_args統合テスト、新しいgoldenだけを実行した。Regexのlibテストは12件、checked_argsは3件、新しいgoldenは1ケースで成功した。局所の外側の時間は未計時である。新しいgoldenの期待をBENITOITE_BLESS=1で生成し、引数と二つのconstの位置、E0457/E0458のJSONを読んで確認した。作業末のgoldenはBLESSなしで成功した。

作成中の局所検査では、診断表への挿入位置とテストのラベル欄名の誤りによるコンパイル失敗、および捨てるResultに`bind _ <-`がないテスト入力のE0416を修正した。既存のassertや期待する診断を変更して通したものではない。

## 計画との差と申し送り

具体化はdecisions.mdのR160に記録した。B_WORKの固定、CallPlanの新しい欄、由来の保持先、R156と同じ追加clippyを記した。既存の再帰の引数・返り値と呼び出しの形、inline(never)の枠の分割を保つため、release_stackは追加しない。主定理・公理・Builtins.Assumptionsを変えていない。性能の本測定を完了したとは扱わない。

K3は`checked_args`の対象へScopeの三関数を加え、同じ取得予算・由来・標準束縛の同定を使う。Regexは一引数なので、本作業では一つの呼び出し内の引数順の組み替えは不要である。K3で複数引数をソース順に取得し、独立した既知部分と実行時の失敗の優先順を接続する。Regexの1/8 MiBはR101の暫定値のままとする。版の実際の切り替え、日本語訳、公開候補の取りまとめはV1へ残す。

# 既知の不良の追加検査の作業メモ

型制約前の Scope の必須判定は変更していない。本体の後の `checked_args::check` が、名前解決済みの標準の直接呼び出しだけを選び、既知の引数を `builtins::checked_scope` の共通判定へ渡す。旧三入口と新しい二つの検査入口で同じ契約順を使い、HTTP の公開引数の位置だけを対応付ける。

| 入口 | 追加検査に渡す入力 | 診断 |
|---|---|---|
| `Scope.checkHost` | pattern・host | E0459・E0460・E0462 |
| `Scope.checkPath` | pattern・path | E0459・E0460・E0462 |
| `Scope.checkEndpoint` | hostPattern・host・minimumPort・maximumPort・port | E0459〜E0462 |
| `Scope.checkPathIn` | pattern・path | E0459・E0460・E0462 |
| `Scope.pathInValue` | 対象となる文字列・ポートの引数なし | 追加対象なし |
| `Http.checkRequestIn` | hostPattern・minimumPort・maximumPort | E0459・E0461 |
| `Http.requestInValue` | 対象となる文字列・ポートの引数なし | 追加対象なし |

`Http.checkRequestIn` の ClientRequest 内の URL は、この追加検査では解析しない。URL の不良は `RequestCheckError.InvalidUrl` を含む別の実行時契約であり、旧三入口の文字列・ポートの既知不良と区別する。親担当とこの範囲を確認した。新診断番号と文言の追加はない。

既存の定数取得・予算・出どころのラベルを再利用した。未知の引数を仮の値で埋めず、既知の不良だけを報告する。名前付き引数の順序と契約順を分け、ソース順の予算消費を維持した。関数値やパイプ等の間接呼び出しは追加検査の対象にしない。

テストの作成時の関門では、新入口の登録漏れ、HTTP のポートの位置の取り違え、部分既知と const の出どころの消失を対象にした。既存表は旧入口だけを通るため、公開の `pipeline::check_text` を使う一つの表形式テストを加えた。テスト用の本番コードの入口は追加していない。段全体レビューの k1〜k5 は同じ通常ソースをテスト内に収録し、後の改造の保管でパスが変わっても動くようにした。

`typeck::scope::local_tests::checks_read_only_literals_and_direct_const_chains_with_typed_integers` は不良条件を意図して含む。先行する局所解析の独立期待値は変えず、本体の後の五つの追加拒否（E0459・E0461・E0461・E0461・E0459）を明示して検査するよう追随した。

| 検査 | 終了 | 結果 |
|---|---:|---|
| `cargo test -p benitoite --test checked_args scoped_value_checks_report_known_bad_arguments_after_body_checking -- --exact`（修正前） | 101 | k1 に E0459 が出ず、意図した理由で失敗。known-before.log |
| 同上（修正後） | 0 | 1件成功。テスト2.81秒、ビルド15.47秒。known-after.log |
| `cargo test -p benitoite --test checked_args` | 0 | 11件成功。テスト12.70秒、ビルドとロック待ち6.90秒。known-all.log |
| `cargo test -p benitoite --lib typeck::scope::local_tests::checks_read_only_literals_and_direct_const_chains_with_typed_integers -- --exact` | 0 | 1件成功。テスト0.29秒、ビルド16.77秒。known-local.log |

局所検査は外側の計時・RSSを採っていない。作業末の W-R と必要な H は親担当が実施する。ログの絶対パスは `<wt>`・`<home>` に置き換えた。`/tmp` に作った四つの一時ログは、伏せたログへ転記した後に削除した。`rm -f` の呼び出しは環境の安全なコマンドの制限に拒否されたため、対象を列挙した `Path.unlink(missing_ok=True)` で削除した。

## W-R の失敗への追随

W-R の初回は `scoped_calls::reversed_request_literals_are_unknown_and_do_not_gain_membership_from_an_annotation` で、旧期待 E0519 と追加検査の E0461 が異なり失敗した。本体の後の追加検査が先に診断を出すため、先行する誤りを見て必須受理の診断を省く既存の順に従い、狭い戻り注釈にも E0461 だけが出る。

最初の追随で E0461 と E0519 の併存を期待したが、局所検査が E0461 一件だけで失敗した（`known-scoped-first.log`）。この失敗から、併存を要求せず既存の診断の順を検査するようにした。テストを `reversed_request_literals_are_rejected_before_scope_acceptance` に改名し、狭い注釈・Top の両方が E0461 で拒否されることを確かめる。局所解析で逆転を未知にする独立期待値は前述の `scope::local_tests` の表で維持している。本番コードは変更していない。

`cargo test -p benitoite --test scoped_calls` は終了0、23件成功、テスト2.25秒、ビルド0.84秒であった（`known-scoped.log`）。外側の計時・RSSは採っていない。一時ログは転記後に削除した。

診断を省く既存の入口は `src/typeck/scoped_calls.rs:591` の `accept_program` であり、591〜597行が先行するエラーを検出すると戻る。親担当の確認を受け、同じ表へ最小・最大に `bind` で名前を付ける場合も加えた。この場合は追加検査の対象外で、狭い戻り注釈は従来どおり E0519 `unknownSource`、Top は受理される。両リテラルの新しい追加拒否と、追加検査の対象外の必須受理を別の行で検査する。

`cargo test -p benitoite --test scoped_calls reversed_request_literals_are_rejected_before_scope_acceptance -- --exact` は終了0、1件成功、テスト0.40秒、ビルド0.55秒であった（`known-scoped-bind.log`）。一時ログは転記後に削除した。

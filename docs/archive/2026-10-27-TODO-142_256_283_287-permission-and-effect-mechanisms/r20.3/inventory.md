# 四入口の既存利用の棚卸し

R20.0a・R20.0b の裸の注釈と Top の説明の一覧、および R20.1・R20.2 の追加分を含む。検索対象は `crates/benitoite/` の tests・testdata・examples・skill と `docs/design/`、局所解析の入力を含む `src/typeck/scope/` である。検索は四入口の公開名 `checkPathIn`・`pathInValue`・`checkRequestIn`・`requestInValue` で行い、[出現の一覧](inventory-occurrences.tsv)に相対パス・行・本文を保存した。行番号は検索時点の値であり、編集後の位置は下表のテスト名・見出しで特定する。

## 通常ソースと交換の独立期待値

| 位置 | 変更／維持の判断 | 理由 |
|---|---|---|
| `tests/runtime_builtins.rs` の `scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok`、`accepted`・`rejected` | 動的な引数の利用を維持する | pattern は関数の引数なので Top を選ぶ。動的な字面・所属・失敗の順序を引き続き確かめる |
| 同テストの main の `/data/**` の直接検査から `retain` を介した射影 | 同じ Result の直接照合へ変更した | 検査の成功型は `/data/**` へ変わる一方、未知の呼び出し `retain` の後には局所の事実がない。末尾は `match direct` として同じ Ok を直接照合し、if の条件内の射影を直接の bind へ出す。binary の中は記録がなく、狭い成功値の射影は事実を得ないためである。動的な条件の accepted 内の retain と GC の検査は維持する |
| `tests/runtime_builtins.rs` の `http_request_in_checks_endpoints_and_retains_the_same_request` | 維持する | pattern と両端は関数の引数なので Top を選ぶ。保持した五欄・URL の更新と再検査・URL の境界の期待値は変わらない |
| 同ファイルの `http_request_in_projection_and_widen_return_the_original_objects` | 変更する | raw 呼び出しへ明示した確定列を渡す。静的な所属の不一致も拒否し、widen 後も成功値・元レコード・実効の host/port が同じであることを確かめる |
| 同ファイルの `scope_path_in_checks_static_membership_and_widen_preserves_the_object` | 追加する | raw 境界で動的条件が成功しても静的範囲外なら失敗すること、widen が同じ不透明値と同じ String を返すことを確かめる。言語の構造上の等値だけでは同一性を観測できない |
| `tests/scope_annotations.rs` の `opaque_standard_value_types_keep_their_invariant_scope`、利用者関数間の五つの範囲の比較 | 維持する | 不変の添字を持つ通常の引数の比較であり、自動拡大はしない |
| 同テストの旧 `Scope.CheckedPath` を `pathInValue` に渡す例 | 維持する | 旧 Checked 型は新しい範囲付きの型へ変換しない。E0401 を期待する |
| 同テストの `Scope.PathIn["/data/**"]` の引数を `pathInValue` に渡す例 | E0519 へ期待を変更し、同じ Ok の直接射影の受理例を追加した | 注釈だけでは成功値の局所の事実を得ない。R20.0a の「非 Top の射影を受理へ変更」の申し送りは、同じ Ok の直接射影の受理例で満たし、未知の引数の例を誤って受理しない |
| `tests/desugar_export/scope_tables.rs` の `exports_used_path_checks_with_range_variables_only_in_signatures` | 動的なソースと署名の期待を維持する | pattern 引数からは Top を選ぶ。署名にだけ rvar 0、通常の項と型には閉じた Top を書く独立した契約である |
| 同ファイルの `exports_request_content_as_the_same_record_type_in_declarations_and_signatures` | 動的なソースと内容の型の期待を維持する | host/port の条件は引数なので Top。実 ClientRequest の data 名・五欄・二署名・valContents の対応は変えない |
| 同ファイルの合成した13入口の署名と `scope-tables-expected.json` | 維持する | 合成入力は既に二つの widen の rvar 0/1、被覆の向き、六つの純粋な宣言を含む。実登録の範囲選択を理由に期待値を算出し直さない |
| `testdata/`・`examples/` | 四入口の既存利用なし | 四つの公開名による検索に一致する入力はなかった |

## 型制約生成前の入力と局所解析の検査

| 位置 | 変更／維持の判断 | 理由 |
|---|---|---|
| `src/typeck/scope/tests.rs` の `standard_identity_and_contract_order_use_resolved_declarations`、sample の `path: Scope.PathIn`・`checked: Http.RequestIn` | 裸の注釈を維持する | R20.1 が追加した二箇所である。引数は既知の成功値ではなく、標準の同定と契約順の検査なので Top が適切である |
| 同ファイルの番号・入れ子・guard・const 展開・名前付き引数・パイプ・予算の入力 | 番号と独立期待値を維持する | 範囲選択の接続で先行順の定義を変えない。既知の条件は非 Top になるが結果を捨てる検査の形と番号には影響しない |
| `src/typeck/scope/local_tests.rs` の `direct_projections_distinguish_instances_aliases_rewrap_and_unknown_calls`、`other: Scope.PathIn` | 裸の注釈を維持する | R20.2 が追加した未知の別個体を表す。注釈から由来を得ないため Top が適切である |
| 同ファイルの `request_ok_keeps_its_own_origin_and_projection_has_no_result_fact`、`other: Http.RequestIn` | 裸の注釈を維持する | 上記と同じく、別の要求を既知にしない検査である |
| 同ファイルの成功の記録・定数の読取り・合流・本体の境界・try・パイプ・予算の入力 | 局所解析の独立期待値を維持し、通常型検査の拒否との境界を分けて追随する | 忘却後の狭い成功値の直接射影など、R20.2 では局所解析へ入力できた形が必須受理に拒否される。事実の期待値を新しい受理に合わせて書き換えず、E0519 で拒否された入力であることを明示する補助処理から解析する。成功の記録・別個体・要求・合流・本体・try の6ケースをこの扱いにする |

| `src/typeck/interval/identity/tests.rs` の `scope_and_interval_preorders_share_origins_without_lambdas_or_clauses` | if の三腕を同じ `/**` の条件へ変更した | 範囲の添字が異なる結果型を一つの if の値型へ暗黙に広げない。番号と元の NodeId を照合する目的と独立期待値は維持する。最初の W-R の lib 検査で E0401 を再現してから直した |

## 宣言・生成物・設計書

| 位置 | 変更／維持の判断 | 理由 |
|---|---|---|
| `src/prelude/stdlib/Scope.bnt` の checkPathIn・pathInValue | 裸の PathIn を維持し、説明を変更する | 公開ソースに範囲変数を書く構文はない。登録時に対象位置へ rvar 0 を入れる生成元である。説明は既知の直接の pattern と未知の Top を区別する |
| `src/prelude/stdlib/Network/Http.bnt` の checkRequestIn・requestInValue | 裸の RequestIn を維持し、説明を変更する | 同じく登録時の rvar 0 の生成元。host と port の組は一つの範囲である |
| 上記二ソースの widenPathIn・widenRequestIn | 宣言を追加する | 入力の rvar 0 と戻りの rvar 1、行き先が元を覆う追加条件を登録する。保持する値・要求・端点を変えない |
| `skill/references/stdlib/Scope.md`・`Network.Http.md` | 生成し直す | 標準ソースの説明と追加宣言に追随する。裸の型は署名の生成元と同じ役割なので維持する。手では編集しない |
| 03-06「Scope」 | 変更する | 常に Top の説明を削り、既知の pattern による非 Top、未知の Top、同じ Ok からの射影、戻り注釈による明示拡大と例へ改める |
| 03-09「クライアント」 | 変更する | 既知の host/port の非 Top、未知・逆転時の Top、要求・端点を変えない明示拡大、実行時の二重の所属検査へ改める |
| 01-06、02-05、02-06、02-08、01-12 と 07-04 の対応の記述 | 接続済みの範囲へ変更する | 四入口と二つの widen の型選択・受理・確定列を反映する。七 IO、ハンドラの節の添字、全体の予算、Rust/Lean 全比較は後続の担当である |
| 02-09「メモリの管理」の二つの保持の説明 | 維持する | 一欄の PathIn と三欄の RequestIn の表現、回収しない区間、根・障壁は変えていない。widen は同じ Value を返す |
| 07-01「エフェクトとハンドラの保証」の純粋な要求の検査の説明 | 維持する | 既に Top でも動的検査を省かないこと、同じ要求・端点の保持、保証しない事項を定めており、静的に常に Top とする記述はない |

## 先行の申し送りとの対応

R20.0a・R20.0b の結果が列挙した標準ソース・生成物・03-06/03-09・01-06・02-05/02-06/02-08・07-04をすべて表へ含めた。R20.0a・R20.0b が追加した裸の注釈は0件、R20.1 の二箇所と R20.2 の二箇所は表の理由で維持する。未知の引数の注釈だけから非 Top を得ないことを優先し、R20.0a の非 Top の射影の例の扱いは新しい受理の規則に照らして具体化した。

## 接続後に追加した検査

| 位置 | 変更／維持の判断 | 理由 |
|---|---|---|
| `tests/scoped_calls.rs` | 6件の通常の入口の検査を追加した | 非 Top の列、明示拡大の戻り注釈、未知・被覆不足・パイプ・逆転ポート・予算より後の呼び出し・間接と穴・行き先未指定・通常定義とメソッドの受理順を独立した期待値で照合する |
| `tests/runtime_builtins.rs` の `scoped_widen_calls_round_trip_through_both_evaluators` | 通常ソースの実行の往復を追加した | 二つの widen を明示の Top へ広げ、射影した元のパス・要求の欄が一致することを両 IO 方式と VM／参照実行器で確かめる。狭い値の所属の事実を widening が作ると仮定しない |
| `src/typeck/scope/accept_tests.rs` | 4件を追加した | 全状態の被覆と列不足・選ばない位置、予算より後の規則の一覧、PipeLeft、補間の番号確定と予算の不変を守る |
| コード生成と `tests/desugar_export/scope_tables.rs` | 各1件を追加した | 同一組み込みの異なる確定列を混ぜず、表層とコアの非 Top の JSON を手で書いた期待値と照合する |

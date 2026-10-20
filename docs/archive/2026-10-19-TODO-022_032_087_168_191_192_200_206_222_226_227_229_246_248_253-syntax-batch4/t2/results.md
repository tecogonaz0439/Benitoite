# T2 の実装結果

T2を完了した。基準 B_WORK は開始時の `git merge-base HEAD san_benito` の `1346ad55ce4474ccf6db0c8df48f7083cd899164`。開始時の未コミット差分はなかった。コミットと docs/todo/ の変更は行っていない。

## 変更

- `ir/desugar/exprs.rs`: 引数を `ArgPlan<C>::Direct(Val<C>) / Evaluate(C)` に分け、sequence_args が Evaluate だけを束縛する。callee と固定式の必要な Let は生成ラムダの本体に残し、穴の値だけを直接渡す。ソース順の値列を既存の CallPlan で宣言順へ配置する。戻り先・継続の捕捉境界と公開 API は変えない。
- `ir/check.rs`: 宣言の型パラメータ・NoFail・実装辞書の制約は借用する。局所変数・節の辞書・剛体型の節・継続・戻り先は更新ログと開始時のログ長で復元する。未登録と上書き前の値を区別し、継続は可視範囲の開始位置を切り替える。Let の右辺・本体・復帰を明示した作業列で検査し、環境全体の clone と Let 鎖に比例する再帰を除く。
- テスト: 独立した期待コアで二つの穴がある場合の Let を5個から3個へ、四つの穴だけの場合を5個から1個へ減らす契約を検査する。新しい golden は逆順の名前付き引数・間接callee・二つの穴・固定式の Log/State を同時に扱い、作成時の未評価と二回の呼び出しの順序・回数を確かめる。公開 check_program の独立した IR は、If・match・右辺の局所束縛、上書き・未登録、ガード/右辺の誤りの後の復元、lambda/lazy の継続の隠蔽と復帰、Some/None の戻り先を検査する。
- 文書: 現行の02-05/06へ実装を反映し、plan の T2 の lint を R161 に合わせた。局所交換の集約を改造の results.md へ追記した。Rust 本体は差引129行、Rust テストは差引291行増であり、別に38行の実行例とその期待出力を加えた。

## 作業末の検査

コマンド・終了状態・外側時間は [commands.jsonl](commands.jsonl)、出力は各ラベルと同名の `.log` に保存した。固定した基準と指定へ dry-run を付けて選択を確認し、次の work を一度実行した。

```sh
scripts/check.sh --level work --base 1346ad55ce4474ccf6db0c8df48f7083cd899164 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test desugar_export --test named_arguments --test verify --test golden
cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep
```

dry-run は終了0、0.013秒。clippy は初回に不要な可変参照を一件検出して終了101（6.605秒）、修正後は警告なしで終了0（6.621秒）であった。修正は読み取り専用の辞書検査への `&mut env` を `&env` にした一箇所であり、その後に work を開始した。

work は終了0、外側312.543秒（約5分13秒）で完了した。fmt、lib 1,224件（既存ignore 21件）、desugar_export 26件（既存ignore 1件）、golden 2テスト、named_arguments 21件、verify 2件、規約・生成物・仕様集計、release_stack 10件が成功した。release_stack の成功件数は専用の実行器が10件ちょうどであることを確認した。生成 Skill の差分はない。最後の `git diff --check` と局所交換用Pythonの構文確認も終了0である。

途中の検査は `cargo check -p benitoite --lib`、`cargo test -p benitoite --lib ir::check::tests -- --nocapture`、同じ指定の `ir::desugar::tests`、追加の scope の一件、穴の交換例と静的な独立期待値の各一件、`BENITOITE_GOLDEN_FILTER=hole_effect_order cargo test -p benitoite --test golden -- --nocapture` に限定した。全lib・全統合・clippy・fmt --check を途中で重ねていない。変更した IR 検査の27件、脱糖の19件、新しい実行例、厳密な期待コアが成功した。初期のコンパイル時には参照の可変性と余分なセミコロンを直し、交換テストの手書きの関数参照タグは `fun` から既存形式の `fnRef` へ訂正した。

## 局所の交換

`BENITOITE_DESUGAR_DIFF_DIR=target/t2-local cargo test -p benitoite --test desugar_export export_hole_argument_plans -- --nocapture` と、同じ指定の `export_named_static_calls_smoke` で入力を生成した。[check_local_exchange.py](check_local_exchange.py) が保存した二組を四つの関係する Lean CLI へ渡す。完全なコマンド・時間と入力の SHA-256 は [exchange/commands.json](exchange/commands.json)、実ソースと入力・報告は [exchange/](exchange/) に保存した。

| 入力 | desugarDiff | builtinCheck | surfaceCheck | surfaceCheckAll |
|---|---|---|---|---|
| 新しい二穴/四穴と固定式、3定義 | 3件一致、終了0 | エラー0、終了0 | 3定義成功、終了0 | 3件成功、終了0 |
| 静的な穴/固定式/パイプ、3定義 | 3件一致、終了0 | エラー0、終了0 | 3定義成功、終了0 | 3件成功、終了0 |

全件で不一致・対象外・除外は0である。各CLIは0.020〜0.172秒で成功した。これらは版12/sidecar4の互換読者へ渡す穴の局所交換であり、構築器の専用コアの版切り替えはB2へ残す。Coverageの二入口は穴の脱糖を読まず、この入力には照合もないため対象外である。旧corpus全体や版全体の形式化比較の成功は主張しない。

## 期待値・計画との差と失敗の確認

新しい厳密なコア検査は、変更前の exprs.rs へ一時的に戻した状態で実行し、余分な穴の Let と変数番号の相違により終了101となることを確認した（外側7.800秒、[hole-before.log](hole-before.log)）。直後に変更後の実装へ戻し、同じ検査の成功を確認した。

既存の静的交換入力の partial は、callee の Let を残して穴の Let 二個を除き、mixed は callee と固定式の Let を残して穴の Let 一個を除いた。変数番号もその束縛数に合わせた厳密な期待へ更新した。これはL5/R155の新しい脱糖に合わせた意味のあるコア構造の変更であり、Letを無視する正規化や期待値の緩和を加えていない。既存のassertの削除・ignore化はない。

計画との差はR161のlintの対象拡張だけである。公開の型・シグネチャ、型付け規則、診断番号、Lean・主定理・公理は変えていない。

## 入力の大きさとテストの関門

既存の IR 検査の深さ 1000 は通常構成で保ち、stress は 64 とする。同じ既存テストで Let の本体側と右辺側を検査する。これは実行時の再帰でなく、検査器の作業列と復帰を確認する入力である。新しい実行例・交換例は二つまたは四つの穴と二つの固定式だけを持ち、深い再帰・長いリスト・共有合成を加えない。

穴の余分な Let と変数番号は公開脱糖の厳密な期待コアで、評価時点・ソース順・一回性は golden の VM と参照評価で検査する。IR の範囲復元は公開 check_program への独立した不正 IR で確かめ、通常の脱糖が作らない上書き・未登録・検査エラー後の復帰を含む。本番の API・フラグ・大域状態を追加しない。

## 後の作業への申し送り

- T3/T4は既存の公開check_programをそのまま使える。局所の更新を加える場合は、範囲の開始時のログ長まで戻す規約を保つ。辞書の宣言表は読み取り専用であり、ラムダ/lazyの継続は開始位置で隠す。
- B2の交換の版切り替えと最後の全corpus再生成では、今回の穴の新しい期待コアと追加した golden も対象にする。routing-manifest はT1を含む新版の全件の振り分けと合わせて更新する。今回の局所入力だけから全corpusの一致を主張しない。
- 版全体のstage/change/release、gc-stress・heap、check-formal.sh全体、性能比較は取りまとめの割り当てに残す。formal/は変更しておらず、lake build は本作業では追加していない。

# RV-R20.3: 型制約への接続と範囲の列の確定の独立レビュー

2026-10-29。対象は R20.3 の未コミットの差分（未追跡の4ソースを含む）と `r20.3/` の results.md・ログ。Lean の `ScopeAccept.lean` の `Required.ofIndex`・`acceptRange(s)`・`acceptHead`・`factFree`・`statesAt`・`acceptCall`・`acceptOccurrence`・`acceptBody`、`ScopeState.lean` の `widenRule`・`widenRun`・`ruleDeclarations`、`CheckAccept.lean` の `acceptProgram` と照合した。scratchpad の一つの target でビルドし、CLI の `check` で約35本の入力を通した。作業用のディレクトリと git の状態は変えていない。`changed-files.json` の63ファイルの SHA-256 は今の作業用のディレクトリと全件一致した。

結論: 重大0・中2・軽7。健全性と Lean との一致に誤りは見つからなかった。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `typeck/scoped_calls.rs` の `resolve`（最後の回で検査を先に `fallback` で確定する） | 検査の成功型を規則が選んだ狭い範囲で先に確定するので、後から Top を必須とする射影や拡大と食い違って拒否される。範囲の注釈を一つも書かない次のプログラムが拒否された（R20.0a/.0b の時点では受理していた）: 既知の検査の成功値を別名にして `pathInValue`、再包装した後の射影、lambda が捕えて中で射影、`v \|> Scope.pathInValue()`（いずれも E0519 `unknownSource`）、`if` の二腕で異なるリテラルの検査を合流（E0401。注記「argument 1 must match the parameter type」が原因と合わない）。Lean では検査の範囲の列を Top とする型付けでこれらは全て受理される（Lean の受理は与えられた範囲の列の判定で、型の付け方は決めていない）。健全性の問題ではなく、受理できる入力が Lean より狭い問題。同じ成功値を裸の `Scope.PathIn` の引数へ渡す形は受理され、結果が経路の順序で変わる | (a) 射影・拡大の元の位置の必須判定が Unknown／Exceeded なら、Top しか受理しない位置なので、検査の確定より前に `Equal(source, Top)` の制約を加える。(b) 同じ変数を共有する複数の検査の既定値が食い違うときは Top にするか Scope 用の診断を出す。採らないなら帰結を 01-06・03-06 に書き E0519 の help で案内する |
| 中2 | 中 | `typeck/scoped_calls.rs` の `PendingIo`（`scope_shape` の `IoShape::Single` の分岐と `resolve` の後半） | 計画の R20.3 の「期待型の入力で一意に決まる新 IO の関数値の具体化を R10 の署名機構へ接続する」に当たり範囲の先回りではないが、`IoShape::Single` を持つ登録は一つもなく、`PendingIo` を通る検査もない。W-R 全体の成功の後に補った部分で、02-05 は実装済みとして書く。内部エラーへ落ちる経路（具体化の失敗で効果の変数が拘束されない）も検査されていない | テストのビルドだけで `Single` の署名を持つ仮の組み込みを使う lib の単体検査を一つ加える（直接呼び出し・関数値・期待型なしで Top）。できなければ R30.2 の完了条件へ「この機構の最初の検査」と明記して移す |
| 軽1 | 軽 | 03-06「Scope」の例、03-09 の例 | 「成功型は `Scope.PathIn["/data/**"]` である。裸の型へ渡すには `widenPathIn` を呼ぶ」は、注釈や利用の制約で決まらない場合の既定にすぎない（成功値を直接、裸の `Scope.PathIn` の引数へ渡す形は受理される） | 「型の制約で決まらなければ規則の選択」と直す |
| 軽2 | 軽 | E0519 の文言 | 主文が射影をエフェクトとして述べる（「effect `Scope.pathInValue` is not covered…」）。同じ文が note と help で二度出る。範囲の制約の理由が戻り値の制約にも一律に `CallArg { index: 1 }` を使う | 最低限、主文の型板を Scope 用に分ける。残りは R40.1 と計画に明記する |
| 軽3 | 軽 | `accept_program` の `preorder: analysis.stopped.is_none()…` | 番号付けが完了していて最後の Run だけが超過した本体でも番号を捨てて「surface preorder unavailable」と出す。Lean は超過の時も既知の位置を `known` のまま判定するので、最初に拒否する出現と鍵が Lean と異なりうる（全件に Top を要求する扱いは健全） | Run だけの超過では番号を残すか、02-05 を実装に合わせ、K10.2 の比較方法の申し送りに差を加える |
| 軽4 | 軽 | `scope/accept.rs` の `accept_body` | 本番の受理は `scoped_calls::accept_program` が独自のループで行い `accept_body` を呼ばず、`accept_tests` は本番が通らない経路を検査している。`accept_program` の改番の失敗の後の `if …is_error { continue }` は到達せず、`let _stop = stop;` も不要 | 本番を `accept_body` に寄せるか、`accept_body` を消してテストを `accept_program` の側へ移す。到達しない分岐と不要な束縛を除く |
| 軽5 | 軽 | `refinterp/convert.rs` の worker の `done.complete` の `CallCtx` | 範囲の列を渡していない（VM の `complete` は `call_ranges` を渡す）。今は完了で列を読む組み込みがないので害はないが R30 で効く | 同じ列を渡すか R30.2 へ申し送る |
| 軽6 | 軽 | 検査の範囲 | W-R 全体の成功の後に型検査の共通の経路（`scope_shape` はすべての組み込みの参照で呼ばれ、`solve` のループの件数も変わった）を変え、再実行は lib と関連10の統合ターゲットだけ。レビューアが今の状態で `golden`・`spec_examples`・`reference_examples`・`random_programs`・`checked_args`・`named_arguments`・`skill_examples`・`stdlib_doc_examples` と `skill_docs` を走らせ、すべて成功したが、正式の記録に欠ける | これらに `test_command` と `cli_process` を足して `--only tests_related` で一度実行し results に載せる |
| 軽7 | 軽 | 07-04 の対応表の受理の行、02-08 | 「置かない Rust は」の間に句点がない。「取り替えたりしない。 `Scope.widen…」に余分な空白 | 直す |

## 問題がなかった点

- 受理の健全性: 未知のパターン・注釈だけの引数・補間・範囲外や負のポート・逆転した組では、狭い契約を `unknownSource`、覆わない契約を `notCovered` で拒否し、Top を受理した。合流は契約が両方を覆えば受理、覆わなければ拒否。入れ子の呼び出し・名前付き引数の入れ替え・const の鎖も正しい。lambda の中の検査は受理し、捕えた値は Top を要求した。handle の節・二段の widen・widen の後の射影は事実がないので拒否した（Lean と同じ）。範囲の外の対象を範囲の内として受理する入力は見つからなかった。実行時も静的に選んだ範囲への所属を検査本体が確かめる。記録のない呼び出しは事実のない状態で読み、`stopped` は最後の Run の超過として読み、予算で止まった本体では全規則に Top を要求し、パイプの右辺は Top を要求する。
- Lean との一致: `rule_index`・`arg_index`・`of_index`、列が足りない時の `notCovered`、規則が選ばない位置に制約を置かないこと、全ての記録の状態で確かめることは `acceptCall` と一致する。最初の拒否は先行順で最小の出現で、通常の定義を全て受理してから実装メソッドへ進む順も `acceptProgram` と一致する。逆転したリテラルに狭い契約を付けた例は E0461 を出さずに E0519 `unknownSource`、Top なら受理。
- widen: 二つの宣言は純粋で、元を rvar 0・行き先を rvar 1 とし、被覆を `Covers { outer: 1, inner: 0 }` で要求する。行き先は戻り値で一意に決まった時だけ確定し、決まらなければ E0407。実行本体は種類と被覆を確かめて同じ値を返し、要求のレコードと endpoint を変えない。六宣言は `ruleDeclarations` と一致する。
- 範囲の列の接続: `call_ranges` → `ValKind::Builtin.ranges`（欠ければ誤り。Top で補わない）→ 下位 IR → `BuiltinRef.ranges` → 検証器の `admits` → VM の pure/state/IO と再開 → 参照実行器とつながる。範囲変数0個の頭は明示の空列で未登録と区別する。`ir::check` は確定した列で具体化し、節は Top を保つ。
- 棚卸しと互換: 四入口の利用は `git grep` で一覧と一致した。旧 Scope の入口と同じ綴りの利用者の関数には新しい規則を付けていない。中1 を除けば Top だけのプログラムの受理は変わらない。
- 規約と記録: 新しいコードに再帰・`unwrap`・添字・`as` はない。01-12 から実装の記述を除いた。設計書は軽1・軽3 を除き実装と一致し、未実装の機能を実施済みと書いていない。gen_skill の生成物・H・比較器の自己検査（39件）・初回の失敗の記録はそろう。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 採る。推す案として (a) と (b) を両方行い、Lean と同じ入力を受理させる（範囲の注釈を書かない利用を断らない。設計原則 6）。レビューの5つの例を通常の入口のテストに置く | R20.3b |
| 中2 | 採る（仮の組み込みの lib の単体検査） | R20.3b |
| 軽1・軽3〜軽7 | 採る。軽3 は Lean に合わせて Run だけの超過では番号を残す形を推す | R20.3b |
| 軽2 | 主文の型板を Scope 用に分ける最低限を R20.3b で行い、残り（note と help の重複、戻り値の制約の理由）は R40.1 の依頼文に明記する | R20.3b と R40.1 |

R20.3b（同じ枝）で中1・中2・軽1〜軽7 を直した。中1 は未確定の元の型への Top の制約を検査の既定値より先に解き、共有する変数の既定値が食い違う場合も Top にする。レビューの5つの例は通常の入口ですべて受理され、Top の列を付けた対応の入力は Lean の受理の判定でも全件受理された（局所の照合で、全比較ではない）。既存の狭い契約の拒否は保つ。中2 はテスト専用の `IoShape::Single` の仮の署名で4つの経路を確かめた（本番の登録には加えていない）。軽2 の残り（note と help の重複、戻り値の制約の理由）は R40.1 へ申し送った。W-R は終了0、外側464.63秒、lib 1,383件・全統合42ターゲット437件。取りまとめが入力で確かめた: 注釈のない別名の射影は受理、未知のパターンに `/data/**` の契約は E0519 `unknownSource`、`/data/**` の検査を `/data/a` の契約で受けると `notCovered`、主文は「the range arguments of check … do not cover the required scope」。

# RV3 処理系の中ほどのレビュー（T1〜T5・B1〜B3）

対象は `git diff be7dc868..376cc390`（Z1 の後に T1〜T5・B1〜B3 を取り込んだ状態）、plan.md の T・B の作業の節と検査の割り当て、decisions.md の R158〜R179、t1〜t5・b1・b2・b2c2・b3 の results.md と D/results.md（stage2）である。RV2 で済んだ論点は扱わない。重い検査（cargo test の全件、check.sh、check-formal.sh、lake build）は実行していない。疑いを確かめるために、HEAD と be7dc868 でビルドした `benitoite check` に小さな .bnt を与えて比べた。所見ごとに、確かめた事実か推測かを記す。

件数は重 0・中 2・軽 10 である。

## 中

### 中1 宣言由来の誤りと同じ式にある真の誤りが隠れる（T5、確かめた事実）

- 場所: `crates/benitoite/src/typeck/solve/provenance.rs` の `provenance_failure`。`crates/benitoite/src/typeck/solve.rs` の `dependent_late` の後処理（`recovered_type`・`poison_redirected`）。
- 問題点: 宣言から型を移した変数を含む使用は、値の側の型に置き換えても失敗するなら、独立した誤りとして残さなければならない（design 10.1）。しかし実装は、宣言由来の変数を含む使用の誤りを一括して保留し、そのまま抑制している。
- 失敗の筋書き: `gl` は `List[Integer]` を受け取る関数とする。

  ```
  function f(n: Integer) -> String
    bind s <- n
    bind _ <- gl([s, "x"])
    return s
  end function
  ```

  - HEAD は `return s` の E0401 だけを報告する。
  - be7dc868 は `[s, "x"]` の `expected List[Integer], found List[String]` も報告していた。
  - `[s, "x"]` は、s が値の側の Integer でも宣言の側の String でも型が合わない。報告すべき独立した誤りである。
  - 戻り型を Integer に直すと、HEAD でも `"x"` に E0401 が出る。修正の往復が一回増える。原則 1（静的に検出できる誤りを実行前に報告する）が弱まる。
  - 対照として、s を含まない `gl(["y"])` の誤りは HEAD でも残る。
- テストの不足: `typeck/tests/diagnostics_batch4.rs` には、宣言由来の変数と独立した誤りが同じ式に混ざる場合がない。
- 修正案:
  - 保留した使用は、回復した型と元の型の両方で失敗するときに報告する。
  - 上の入力と、s を含まない対照を golden か diagnostics_batch4 に加える。

### 中2 成功する型検査の時間が文の数の二次になる（T5、debug ビルドで確かめた事実）

- 場所: `typeck/solve.rs` の bounds のループ。条件は `!final_pass && !self.has_recovery(&ty) && self.provisional_dependency(&ty, &r)`。`typeck/solve/provenance.rs` の `record_provenance`・`origin_recovery`・`origin_declaration`・`origin_confirmed`。
- 問題点: `equal` と `flow` が成功するたびに、辺と型の形を加える。そのうえ、制約ごとに連結成分の全体を BFS で辿る。成分は文の数に比例して大きくなるので、時間は二次になる。
- 失敗の筋書き: `bind x{i} <- x{i-1} + i` を N 行並べた入力で `check` の時間を測った。

  | N | be7dc868 | HEAD |
  |---|---|---|
  | 250 | 0.04秒 | 0.15秒 |
  | 500 | 0.05秒 | 0.49秒 |
  | 900 | 0.06秒 | 1.73秒 |

  - `x + x * i` を 400 行並べた入力は 0.05秒から 1.09秒になった。
  - 入れ子の深さの上限（E0208）があるので、一つの本体は約 1000 文までに収まる。遅さにも上限はあるが、30 倍前後遅い。
  - design 10.1 の「使用ごとに全履歴を複製しない」の意図にも合わない。
  - release ビルドでは測っていない。比率は同程度と推測する。
- 修正案:
  - 回復の情報（recovered）が空なら探索しない。
  - 宣言への到達と確定の有無を、union-find の根ごとに記憶する。
  - BFS は失敗した制約についてだけ行う。
  - M1 か compare の short で、型検査の時間を測る入力に加える。

## 軽

### 軽1 命令の上限の L0112 の見出しが match に限られる（T3、推測）

- 場所: `bytecode/codegen/state.rs` の `FnGen::emit`。`diag/codes.rs` の L0112 の `instructions` の注記。
- 問題点: 定義ごとの 4,194,304 命令の上限を超えると L0112 を出す。しかし見出しは "the `match` in `{name}` is too large to compile" に固定されている。
- 失敗の筋書き: match のない巨大な定義（非常に長いリテラルなど）で上限に届くと、「match が大きすぎる」と誤った案内が出る。この入力が上限に届くかは確かめていない。
- 修正案: 命令の上限には別の見出しを使う。または見出しを「定義が大きすぎる」の意味へ一般化する。

### 軽2 到達しなくなった L0112 の注記が残っている（T3、コードで確かめた事実）

- 場所: `ir/decision.rs` の `tree` の冒頭（845〜850 行付近）が出す `limit` と `definition`。
- 問題点: tree() はすべて試行の中で呼ばれる。そこで出た Limit は捕えられ、行照合へ切り替わる。このため二つの注記は最終の診断として出ない。`definition` の文面は今も "including copies of guards" と書いている。
- 修正案: 二つの注記を診断の表から除く。または試行の内部だけで使う印に替える。

### 軽3 共有した判定の成功後の最終予算超過では行照合へ戻らない（T3、推測）

- 場所: `ir/decision.rs` の match_comp の `reserve_output` と `arena.table(nodes*32)`。
- 問題点: ここで出る Limit は試行の失敗として扱われず、そのまま最終の L0112 になる。
- 失敗の筋書き: 共有した節の数は上限以内でも、Join と Jump を足すと超える入力がありうる。行照合なら収まるかもしれない入力が拒否される。
- 修正案: この Limit も巻き戻して行照合へ切り替える。切り替えないなら、その旨を 02-06 に明記する。

### 軽4 行照合への切り替えのテストが、通った経路を確かめていない（T3、一部推測）

- 場所: `tests/random_programs.rs` の `row_fallback_preserves_guard_alternatives_and_list_bindings`。
- 問題点: 行照合を通ったことを assert していない。
  - 既定の構成の 400 要素は、t3/results.md で R164 の失敗を再現しているので、行照合を通る。
  - gc-stress の構成の 64 要素は予算に届かず、共有の経路だけを通る見込みが高い（推測）。
- 修正案: block_tests.rs（R177）と同じく、私有の欄で予算を消費済みにする版を足す。または、gc-stress では共有の経路だけを確かめることをコメントで明記する。

### 軽5 GC と無関係な深さの検査まで gc-stress で縮めている（T1〜T3、事実）

- 場所:
  - `typeck/pattern_ext.rs`: 深い入れ子 450/900 → 16
  - `ir/decision.rs` のテスト: 連鎖 64 → 16、リスト 4096 → 64
  - `ir/check.rs` の `deep_ir_is_checked_without_changing_the_thread_stack`: 1000 → 64
- 問題点: どれも型検査・下位化・IR 検査の深さを確かめるテストで、GC の構成とは関係しない。既定の構成では元の大きさを保つので、弱化は限られる。それでも gc-stress の構成では深さの検査の意味がほぼなくなる。
- 修正案: 縮めない。縮めるなら理由を記す。

### 軽6 最終予算のテストが注記を区別しない（T3、事実）

- 場所: `ir/decision.rs` の `final_decision_budget_reports_one_limit_at_the_match`。
- 問題点: assert の `contains("budget") || contains("64 MiB")` は、table・nodes・edges・definition_final のどの注記でも通る。予算の種類を取り違えても検出できない。
- 修正案: この入力で期待する注記を一つに固定する。

### 軽7 局所交換の照合で、独立した期待値を全体に書き換えている（B3、事実）

- 場所: `D/b3/check_local_exchange.py` の 24〜35 行。
- 問題点: L7 の手書きの 301〜303 と照合する前に、期待値の表層にあるすべての `returnE` の `ret` を Unit に書き換えている。R178 が合わせるとしたのは、到達しない続きの型だけである。
  - コアは書き換えずに厳密に比べ、六入口の検査も通っているので、Lean の規則との食い違いではない。
  - ただし、期待値の独立性は弱まる。
- 修正案: 書き換えを到達しない続きの位置に限る。または L7 の期待値の側を Unit にそろえ、照合のスクリプトでは書き換えない。

### 軽8 修飾名の前置きを関数の中に直接書いている（T5、事実）

- 場所: `typeck/context.rs` の 292・296・302 行。
- 問題点: 前置きの `"main"` と `"Benitoite"` を処理の関数の中に書いている。AGENTS.md「文言」は、型板に埋める値を `text` の子モジュールの定数に置くと定める。
- 修正案: `typeck::text` の定数へ移す。

### 軽9 テストに作業 ID を引いている（B2・T1、事実）

- 場所: `vm/builder_tests.rs` の 98 行のコメント「B1 の Host 単体検査では…」。`typeck/patterns.rs` の 2130 行の失敗の文言 "T1 scalar …"。
- 問題点: AGENTS.md「コメントと名前」は、コメントに作業 ID を引かないと定める。
- 修正案: 作業 ID を除き、根拠は設計書の節で示す。

### 軽10 B2 の検査の細部（事実）

- `tests/verify.rs` の `reference_sets_depend_on_successful_size_checked_combination` に、使わなくなった `annotation` を捨てる `let _ = annotation;` が残っている。表の欄ごと除けば済む。
- `bytecode/builders.rs` の `analyze` は、専用入力を持つ本体の Closure を作った原型の中で、source の局所欄の定義と種類を確かめる。しかし、その原型が本体を生成した親であることは照合していない。plan の B2（handle 本体、R132）の行は「生成元の親Protoとの対応」の検査を求めている。別の原型が同じ番号・同じ種類の局所欄を持てば、手で作った不正なプログラムが通る。検証器は本番の経路から呼ばないので実害はない。親の対応を表に持たせて照合するか、現状の検査範囲を 02-07 に記す。
- 同じ verify のテストの変異は、本体の site の種類の違いを確かめている。一方、親の局所欄と `BuilderInput.kind` の種類が違う場合（"handle builder source is undefined or has wrong kind"）の変異はない。一件足すとよい。

## 確認した内容（指摘なし）

### 1. 共有 DAG と T3 のガード・束縛・予算

- 共有の鍵（`ir/decision/arena.rs` の MatrixKey）:
  - 新しく振った番号だけを出現順に正規化し、照合前の変数は区別したまま保つ。
  - 束縛元と case 番号（ガードを決める）を鍵に含む。したがって、別の束縛・入力・ガードを誤って共有しない。
- 節の作り方:
  - 共有した節を上書きしない。
  - Join は子を外側に置く。
  - Jump の引数と params は、個数も順も一致する。
- ガード:
  - 共有の経路でも行照合でも、一 case で一度だけ評価し、偽なら次の case へ進む。
  - B3 の block-guards の例が、VM と独立参照評価の両方で `gh/ghi/i` を確かめている（R177）。
- 試行の巻き戻し: 番号・join・本体・予算の計数を戻し、arena を作り直してから行照合へ進む。
- R164（末尾の行で長さの検査を省く）の前提は成り立つ。
  - ガード付きの行は網羅性に数えない。
  - 到達しない分岐は E0602 で拒否する。
  - 末尾の行には失敗先がない。
- Integer の全域で既定の分岐を省く判定は安全である。
- 予算はすべて checked の演算で、確保の前に検査している。

### 2. 解析の根（T4）

- BodyAnalysis は、下位 IR を明示の作業列で一度だけ辿る。
- 使用位置の区間と束縛位置の区間最小値で「範囲の外で束縛され、範囲の中で読む」を判定する。区間最小値は segment tree で引き、その実装を読んで確かめた。
- 節の同一性は借用中の下位 IR のアドレスで区別し、アドレスは逆参照しない。
- 本体の終了時に、外側の束縛で親の捕捉へ伝える。
- 命令の生存解析は、出口の集合を後続の入口から直接求める形へ変えた。旧版と同じ式（後続の入口の和から書き込みを除き、読み出しを加える）であり、最後の使用の判定も同値である。
- 専用保持先の生存は、通常のレジスタと別の後ろ向きの固定点で求める。`LiveItem::Builder` はその入口で不要な欄である。

### 3. 三つの Host バッファ・障壁・停止・継続

確かめた点:

- 予約の順序:
  - `runtime/heap/builders.rs` は、checked 加算 → 論理上限（CheckedLen、R0902）→ 予約（`try_reserve_exact`、失敗は R0907）→ 書き込み、の順を守る。
  - List の appendAll は、入力の表現を予約の前に走査し、途中での部分追記を防ぐ。
  - String の予約前の走査は、R171 のとおり見出しの長さだけを読む。
- 障壁と容量:
  - Host の可変借用は `with_host_mut` の一か所を通る。容量の増減はそこで記録と合計へ反映する。
  - List の Slot は SlotOps で作り、障壁はその一か所にある。
  - `ValueCtx` は Host を読む入口を持たないので、可変借用中の Host への別名は作れない。
- copy:
  - 新しい不変の値を作るので、後の追記の影響を受けない。
  - List の copy は、一時の Slot を使った後に破棄する。
- VM の枠:
  - CallFrame の専用 Slot 配列は Trace と Discard の対象である。
  - 通常の呼び出し・末尾呼び出し・lazy・タスク・update・main の枠は空の配列から始める。
  - 末尾呼び出しは古い配列を破棄する。
  - 資源の計数（`frame_slots` = num_regs + builder_slots）は、grow・fits・shrink・`reg_count` の全経路で一致する。
- handle 本体への受け渡し:
  - HANDLE は、親の枠（`state.frame()`）の source の Slot を、本体の枠の target へ同じ Host として写す。
  - precall で安全点へ戻る場合も、HANDLE の入口では source が生きている（analyze が source を読み出しとして数える）ので、根から外れない。
- 生存しなくなった欄の整理: 安全点（clear_stack）と継続の捕捉（clear_captured）で、生存しなくなった専用欄を空にする。
- 取消・停止: タスクの取消は枠の破棄で Slot を手放す。b2c2 の取消のテストは、子の要求が実際に出たことを assert している。
- 検証器:
  - UserHandleBody 以外の専用入力を拒否する。
  - 本体を Lazy にすること、HANDLE 以外の命令で読み出して持ち出すことを拒否する。
  - 合流で不明になった本体（`ProtoIdx(u32::MAX)`）は HANDLE で拒否する。
- 独立参照評価は、独自の場所の表と不変の内容の置き換えで実装しており、VM の Host を呼ばない。
- 推測: 参照評価の追記は毎回全体を複製するので二次になる。テストの入力は小さいので問題にならない。

### 4. block … end block の全走査と return

- `Expr` を網羅する全ファイル（src・tests・examples）で、`Expr::Lazy` と `Expr::Block` の出現数が一致する。
- 実行して確かめた:
  - ガードや lazy の中の block で return を使うと E0218 になる。
  - 全経路が抜ける block の後の文は E0439 になる。
  - ラムダの中の block の `try … or return` はラムダから抜ける。
  - 構築器を block の値として持ち出すと E0464、block の中のラムダで捕捉すると E0465、block の外から参照すると E0301 になる。
  - 整形は冪等である。

### 5. 診断の真偽

- 中1 のほかに偽の診断や漏れは見つからなかった。
- W0401・W0402 は解決済みの束縛と幅の表で判定する。`floorModulo(min, -1)` には警告を出さない。符号なしの値を i64 へ変換しない。
- E0609 の新しい文面は四つの上限を示す。
- R0907 は Stop から報告への表に一行加えたもので、R0902 と区別される。
- E0467 は G1 の範囲でまだ実装していないので、今出ないのは計画どおりである。
- 交換の出力の `_` と、利用者向けの E0601 の具体的な値の二層は、R157・R158 のとおりである。

### 6. Lean との局所照合

- 01-12 の「body.Exits のときだけ block が必ず抜ける」は、Rust の `always_block`・`reach` に一致する。
- 「lazy とガードには R なしの検査を内側へ渡す」は、parser の escape の文脈に一致する。
- 局所交換:
  - B2 は 9 入力 52 定義、B3 は 2 入力 10 定義を六入口で照合した。
  - 構築器 5 定義と block 3 定義は、L7 の手書きの期待コアにも一致した（軽7 の留保つき）。
- formal 側の変更は Python の読み込み器（12/4 と 13/5 の対応の判定）だけで、Lean の定義・定理・仮定は変わっていない。
- 07-04 の追記は局所の接続に限った書き方であり、版全体の比較が済んだとは書いていない。

### 実装の規約

- 本番のコードに新しい unwrap・expect・添字・panic・数値の `as` の変換はない。`isize::MAX as usize` は明らかに収まる。
- unsafe の場所と大域の状態は変わっていない。
- 実行時の値を再帰で辿るコードはない。provenance の再帰は型の形を辿るものである。
- 新しい文言は diag::codes にある（軽8 を除く）。

### テストの弱化

- B2 で除いた assert は、旧 refs を書き出す補助 `builder_pure` の中の `BindingKind::Fn` の assert 一箇所である。補助そのものが、新しい経路にない参照先を書き出すためのものだったので、除いたのは妥当である（R172）。
- Reference の合成順序のテストは、明示した Reference の計算へ移し、assert を保った（R174）。
- L0112 の拒否を受理へ変えたのは R162 に従った変更で、最終予算の拒否は別の入力で残している。
- spec_examples の変更（R179）は件数と添字を移し、キーワード一覧の 1 行の字面を合わせただけである。
- 新しい ignore はない。
- 縮小の問題は軽5 に挙げた。

### 結果の記録と検査の割り当て

- t1〜t5・b1・b2・b2c2・b3 の work は、plan の各行に対応する。lint_default を全ターゲットの clippy に置き換えたことは R159〜R177 に記してある。
- B1 は heap_checks（check-heap 全体）を実行した。
- B2 は check-heap 全体と、特殊構成の局所の lib・4 統合を実行した。
- B3 は特殊構成の局所の lib・両経路の 1 件・4 統合を実行した。
- 再実行は、失敗後に古くなった単位に絞り、その理由を記してある。

### TODO-263〜265（組込み向けの構成）

- 新しい依存のクレートはない。
- 新しい上限値はすべて 32 ビットの usize に収まる。
- u64 から usize への変換は try_from で失敗を扱っている。
- 64 ビットだけを前提にする新しいコードは見つからなかった。

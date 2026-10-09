# 相談 第 8 回: 第 1 段の VM の性能の回復

- 状態: [ADR 0313](../../../../design/decisions/0313-vm-performance-recovery-before-stage-2.md)（提案）と作業 R15・R16 の文書に反映した（2026-10-05）
- 対象: 振り分けのループと呼び出しの手順の改善の順序、生存の情報の処理を安全点へ移す案、第 2 段の前に固定する呼び出しの規約と性能の関門

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-10-05 |
| 検証者 | Codex（codex-cli 0.160.0）＋ GPT-6.1-Sol。推論の度合い high、サンドボックスは読み取りだけ |
| 渡した資料 | 依頼文（下記）。リポジトリを読ませた |
| 問いの数 | 3 |
| トークン | 120,781 |

## 送った依頼文

````text
あなたは言語処理系の VM の設計の相談相手である。ファイルを変えず、コードを書かず、意見だけを日本語で述べてほしい。リポジトリ /Users/tecogonaz/src/Benitoite（ブランチ san_benito）を読んでよい。

## 背景
Benitoite は Rust で書いた関数型スクリプト言語の処理系である。初回リリース版でランタイムを作り直した（docs/design/decisions/0258〜0269、docs/implement/10-interfaces/10-07〜10-09）。レジスタ VM（10-07 の CALL A B C は R[B] が関数、R[B+1..] が引数）、16 バイトの Value、ヒープの値は Slot に入れ、Value<'epoch> は回収しない区間の寿命を持つ（ADR 0260）。生存の情報（10-07「生存の情報」: 命令ごとの LastUse・Dead）に従い、VM は命令ごとに最後の使用の引数を take し、死んだレジスタを clear する（ADR 0259 の決定 2。参照カウントの精度と回収の精度のため）。第 1 段でマーク・スイープと参照カウントを比べ、マーク・スイープ（k=1）を暫定に採った（参照カウントは R14 で外す。tools/bench/results/2026-10-05-stage1-5b300d4-summary.md）。

## 問題
初回リリース版の VM が最小実行版の VM（crates/benitoite/src/legacy/vm/）より 5〜6.6 倍遅い（fib(35) 10.1 s 対 2.06 s、loop 6.6 s 対 1.0 s。CPython の fib は 1.27 s）。調査（Claude）の結論:
- 実装が ADR 0263 の決定 1（振り分けのループの局所の状態）を守っていない: レジスタのアクセスごとに state.frame() で区画と枠を 2〜3 回引き直す、JMP でも Reload、収集の信号を全命令の後に調べる、CALL・算術で Vec<Value>/Vec<u16> を毎回確保する、Opcode::from_u8 が非インライン、LOADK が BTreeMap を先に引く、RETURN で regs を truncate して CALL で伸ばし直す、heap の Slot の load/store が非インライン。
- 試作（凍結したシグネチャを変えずに dispatch.rs と #[inline] だけ）: (a) 命令ごとに窓のスライスを一度作る＋CALL の引数を直接写す＋算術の Vec をなくす で 2.6〜2.85 倍、(b) CALL・RETURN の後の Reload をやめて局所を直接設定、JMP の Reload をやめる、収集の信号を確保の後に限る で +13%、(c) Slot・HeapCore・NoGcCtx の小さな操作に #[inline] で +11%。a〜c で fib 3.65 倍・loop 4.4 倍だが、fib35 換算 2.8 s で最小実行版の 2.06 s に届かない。
- 残りの大きな費用: 生存の情報による命令ごとの take/clear の書き込み（除くと 20〜26% 速い。走査だけなら費用はない）。Slot の読み出しごとのヒープの番号の比較（ADR 0281）。from_u8 と定数の引き方（推定 10%）。

## 相談したいこと
1. マーク・スイープだけになった後、命令ごとの take/clear をやめ、回収の安全点で生存の情報（pc ごとの Dead・生きているレジスタ）から死んだレジスタを空にする（または根として数えない）形に改めるのは妥当か。正しさの上の落とし穴（LastUse で take した値の所有、例外・継続（第 2 段の R20 のハンドラと一度だけ再開できる継続、R21 の枠を降ろす処理）、組み込みの関数の呼び出しの間の安全点、Lazy・Reference の書き込みの障壁）は何か。代わりの案（即値を書くレジスタだけ専用の安い経路にする等）との比較。
2. 上の a〜c と、f（from_u8 を表にする、LOADK を添字で引く）、g（RETURN で truncate しない。窓の後ろを Unit に保つ不変条件）の順で進め、最後に OPEN-063（窓を重ねる CALL。R13 の試作で CALL 中心の負荷が 9〜20% 速い）と OPEN-064（検証器で範囲の確かめを省く unsafe）を測って決める、という計画は妥当か。抜けている大きな要因はないか（例: Value の 16 バイトの enum の match の費用、Result の伝播、Slot と Value の変換）。
3. 「最小実行版と同等以上」を確実にするために、第 2 段（ハンドラ・継続・タスク）を入れる前に決めておくべき VM の構造（枠と区画の表現、呼び出しの規約）は何か。第 2 段でまた遅くならないための指標や関門の置き方。

80 行以内で、根拠のファイルと行があれば添えて。
````

## 回答

回答は検証者の出力のままである。リンクは検証者が書いた絶対パスと行番号で、2026-10-05 の時点（R14 を取り込む前後の `san_benito`）のファイルを指す。

**マーク・スイープだけになった後なら、命令ごとの `take/clear` を回収の安全点へ移す案は妥当である。** ただし、生存情報を「逐次消去するための差分」から「各停止状態で根を決める情報」へ改める必要がある。改善の順序にもおおむね賛成するが、第 2 段の前に、根の規約と普通の CALL/RETURN の経路を確定させたい。

**1. `take/clear` の延期は、まず安全点で実際に `Unit` にする形を勧める。**

現行の `Dead` だけを安全点で処理しても足りない。生存情報の生成は、先行命令で `Dead/LastUse` を消したことを前提に、保持しうる集合を更新している。逐次消去をやめると、以前死んだ値が現在の `Dead` に現れず、残り続ける。安全点用に、生きている集合またはその補集合を別途生成すべきである。[liveness.rs:306](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/bytecode/liveness.rs:306)

正しさの条件は、次のとおりである。

- **`LastUse` は所有権の唯一性を意味しない。** MS では通常の読み出しを `load` に変えてよいが、得た `Value<'epoch>` は区間内だけで使う。回収をまたぐ引数・結果・一時値は、レジスタ、枠、根の保存領域へ置く。現行 MS の `reuse_ctor` は常に `None` なので、RC 用の再利用条件も現時点では利益を生まない。[ヒープの契約:21](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-08-values-and-heap.md:21)、[mark_sweep.rs:69](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/runtime/heap/core/mark_sweep.rs:69)
- **根は pc だけで決めない。** 呼び出し前は関数と引数が必要、呼び出し成立後の親枠は呼び出しをまたぐ値だけが必要である。結果の宛先は、書かれるまで旧値を根から外せる。「次の命令の生存集合」をそのまま使うと、結果として読む予定のレジスタに残る旧値を余分に保持する。入口・呼び出し中・完了待ちの区別を定めたい。[呼び出し前の手順:697](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-09-vm.md:697)
- **組み込みの関数の完了待ちでは、引数を追加の根として残す。** 現行規約も、待ちうる `IO/PRIM` の引数に `LastUse` を付けない。完了処理が読み直す引数を、通常の「命令実行後」の集合だけで消してはいけない。組み込みの関数の区間内では回収せず、待ちへ移る前に保存を完了する。[10-07:934](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-07-bytecode.md:934)
- **捕まえた継続、停止中のタスク、枠を降ろす途中も対象である。** 実行中の窓だけ清掃しても不十分である。継続には再開に必要な値、後始末には枠が使う値を残す。`RETURN/ESCAPE` の値は、窓を消す前に `ReturnWork::value` へ保存する。区画を移す途中に回収や失敗を挟まない規約も維持する。[R20:84](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R20-handlers-and-continuations.md:84)、[戻りの再開状態:1060](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-09-vm.md:1060)
- **根から除くだけの案には、回収済み対象を指す古い `Slot` が残る。** その後の読み出し・再走査・上書き・破棄が旧対象に触れない契約まで必要になる。ヒープ番号は同じヒープ内の回収済み参照を防がない。現行 `Segment::trace` は全レジスタを辿るため、まず回収前に死んだ値を `Unit` にする方が、継続を含む既存の `Trace` と整合させやすい。[frame.rs:181](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/frame.rs:181)、[ADR 0281:決定3](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0281-heap-number-in-slot-and-contract-safety.md:決定)
- **Lazy・Reference の更新 API は維持する。** 現行の停止して行う MS では、逐次レジスタ消去を延期するために新たな障壁は要らない。ただし、セル・Lazy・タスク結果・継続状態の更新箇所を分散させると、将来の世代別・増分回収に必要な障壁を入れにくくなる。[ADR 0259:26](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md:26)

代案として、**即値の `take/clear` だけを省く案を先に測る価値がある。** 即値は対象を保持しないので、ヒープ値の消去規約を変えずに書き込みを減らせる。実行時の種類の判定が増える場合と、静的に即値と分かる場合は分けて測りたい。ただし「即値を書き込む宛先」には旧ヒープ値がありうるため、宛先の処理まで無条件に省略することはできない。

**2. 改善の順序は、a〜c → f → g → 生存処理の改善 → OPEN-063 → OPEN-064 を勧める。**

RC を外した後の単純化を前提に、一つずつ同じ負荷で比較する。命令ごとの生存処理が測定上 20〜26% を占めるなら、`unsafe` の検討より先に扱う理由がある。ただし、安全点へ費用を移した結果は、fib/loop と確保の多い負荷の両方で評価する必要がある。

- **a の直接コピーは、通常 CALL と末尾 CALL を分けて設計する。** 通常 CALL は独立した窓へ直接写せる。末尾 CALL は移動元と先が重なりうるので、書き込みや窓の清掃で未読の引数を壊さない手順が必要になる。
- **b の Reload 削減には賛成する。** CALL/RETURN は確定した遷移先から局所状態を設定し、JMP は局所 pc を変えればよい。一方、回収・待ち・継続移動・停止へ出る境界では、pc と根の状態を保存する。収集信号の確認を確保後へ限定しても、続けて戻る処理と後始末での回収要求の確認は残す。[ADR 0263:決定](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0263-dispatch-loop-locals-and-verifier.md:決定)
- **f は表化を先に決めず、インライン化した `from_u8` と比較したい。** LOADK は即値の記述を先に引く小変更と、実行ごとの添字付きキャッシュを分けて測る。ヒープ定数の根と、未構築の状態は維持する。[dispatch.rs:875](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:875)
- **g では、使用中の終端と保持する記憶域の長さを分離する。** CALL の base、上限の計数、清掃範囲、根の走査は使用中の範囲に従わせる。現在の `truncate` は容量を捨てていないため、主な利益は再初期化の省略である。RETURN ごとに保持領域の末尾まで清掃すると逆効果になりうる。[dispatch.rs:1011](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:1011)

抜けている候補として、毎命令の `program.proto` の引き直しと、算術命令を大きな `binary` 関数内で再判定する処理がある。原型・生存情報・定数情報も局所に保持し、型別算術命令の判定が重複していないか確認したい。[dispatch.rs:161](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:161)、[dispatch.rs:715](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/vm/dispatch.rs:715)

`Slot → Value` の変換では、同じ Slot の種類を複数回解釈している点も候補である。ただしヒープ番号の比較は対象を指す場合だけなので、即値中心の loop の残差全体をそれで説明できない。16 バイト enum や `Result` の費用は、生成した機械語と改善後のプロファイルで判断したい。[core.rs:725](/Users/tecogonaz/src/Benitoite/crates/benitoite/src/runtime/heap/core.rs:725)

OPEN-063 の効果は、引数の Vec をなくした VM で測り直すべきである。総移動量・最大レジスタ量・長い末尾再帰を比較し、重なる Slot の所有者を一つにし、区画境界を越えて共有しない条件を守る。OPEN-064 はその後で、静的な範囲保証と動的な所有・上限・使用済み継続の検査を分けて決める。[R13:34](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R13-overlapping-windows.md:34)

**3. 第 2 段の前には、枠の配置よりも「普通の呼び出しに何を追加しないか」を確定したい。**

ADR 0262 の区画ごとの三つの Vec と相対位置は維持してよい。普通の CALL は既存区画へ枠を積み、普通の RETURN は関連する解放・包む枠がなければ直接戻る経路を持たせる。毎回の `ReturnWork` の構築や一般の枠を降ろす状態機械を避けるには、10-09 の現行記述に対する例外を ADR で定める必要がある。[ADR 0262:決定](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0262-segment-frames-split-call-and-wrapping.md:決定)

呼び出し規約として、引数の位置、独立窓／重なる窓の所有範囲、末尾 CALL の移動手順、未完成の結果レジスタ、停止状態別の根、局所状態の保存境界を固定したい。待ち・継続捕捉・後始末の途中状態は保存可能にし、その生成費用は該当する経路で払う。これらは R20〜R25 が共有する契約になる。

性能の関門は、次のように置くことを勧める。

- **第 2 段の開始前:** 同じ機械・設定で legacy を測り直し、fib/loop が同等以下の時間であることを確認する。可能なら 10〜20% の余裕を目標にする。VM 比較では命令数・MOVE 数・窓の大きさも確認し、コード生成の差を区別する。
- **各作業の取り込み時:** 改善後の第 1 段を固定基準として残し、機能を使わない fib/loop と既存負荷を再測定する。例えば測定のばらつきを超える 5% の悪化を、原因の説明と合意が必要な関門にする。
- **構造上の関門:** 容量確保後の普通の CALL/RETURN に Rust の動的確保がないこと、引数のコピー量、清掃する Slot 数、走査する根の数を確認する。
- **第 2 段固有の関門:** ハンドラ深度、捕捉・再開・破棄、待つタスク数、後始末を変え、時間だけでなく保持量・最大 RSS・GC 停止時間を測る。回収の強制で、完了待ちの引数・捕まえた継続・`ReturnWork/UnwindWork` の値が保たれることも確認する。

「最小実行版と同等以上」は構造の選択だけでは保証できない。対象負荷と測定条件を明示した受け入れ条件にし、第 2 段の各変更がその条件を満たす運用にするのが確実である。
## 試作の差分

依頼文の「試作」の (a)〜(b) を入れた `src/vm/dispatch.rs` の差分（R14 を取り込んだ `san_benito`（894e1d3）の `dispatch.rs` と同じ内容のファイルに対するもの。(c) の `#[inline]` は `runtime::heap` の側の変更で、この差分に含まない）は、[08-prototype-dispatch.diff](08-prototype-dispatch.diff) に残す。命令の一部（`MOVE`・`LOADK`・整数の算術と比較・`JMP`・`JMPF`・`CALL`・`TAILCALL`・`RETURN`）だけを速い経路に分けた測定のための形であり、遅い経路の一部（予算の遅い経路でタスクを切り替える場合、`main` の `RETURN`）を省いている。本番の実装の手本ではない。

# 0.0.10 の実装プラン（C2）

## 前提と依存

15件とB17を、一つの改造「構文の第4弾」として実装する。範囲と公開APIは[詳しい設計](design.md)1〜15節、採用する判断は[決定記録](decisions.md)の63件のA・B17・R101以降を正とする。静的な篩型、暗黙のLog、専用Property CLI、TODO-262の本測定など、design 1節の対象外を加えない。builders族の修正は今回の測定に必要な範囲を含める。

検査の正は[07-03「実装の規約と静的な検査」](../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、形式化の内外と順序の正は[07-04「01-12 との対応」](../design/07-quality/07-04-formal-semantics.md#01-12-との対応)である。[共通依頼文](implementation-request.md)とともに使う。Dは本書のあるディレクトリ、Rustのパスは断りがなければ`crates/benitoite/`からの相対パスである。

| 基準・担当 | 固定する内容 |
|---|---|
| `B_CHANGE` | `c31e64b03d2810343e1779926bea4ebc958b6164`（0.0.9）。change/releaseと比較beforeの基準 |
| P1の記録の基準 | `f4a8bec2fb5a746ca80487a60355f1a34b797bd5`。P1の文書検査だけの基準として保つ |
| P2開始時HEAD、文書検査の`B_WORK` | `5847491b4e4565a344a9461d1532646192752865`。mod010/design。P1は`580ad65d3c4e9e1d06e8f24ae0bf9696169a0306`としてコミット済み。処理系・formalとB_CHANGEの差分はP2の文書検査で照合する |
| 最初のL1の`B_WORK` | `7279140720c9aac817f3d4661de244f6470e040d`（P2までの設計を san_benito へ取り込んだコミット、2026-10-19）。改造開始版 c31e64b0 から処理系・formal・scripts・tools の差分はない（文書だけ）ことをオーケストレータが確かめた。L1 の作業のブランチは mod010/L1 |
| 以後の`B_WORK` | 直前の作業と必要なレビュー修正の取り込みの完全なID。取りまとめが依頼文へ実値を記入する。未来のIDを仮造しない |
| `B_STAGE2` | T1の開始直前の取り込みの完全なID。段の開始時に取りまとめが固定する |
| 実装 | Codex。各作業の変更・局所検査・現行設計への反映・生成物・結果記録を担当する |
| 取りまとめ | オーケストレータ（Claude）。依頼の基準・入力と出力・順序、レビュー修正の引き渡し、最後の全体検査と測定を担当する |
| 独立レビュー | Opus。preflight・RV1・RV2は実施済み。P2でRV1を反映し、Z1でRV2を反映する。残りはRV3〜RV5の3回。定義・言明・仮定と境界を読み、証明本文の逐語レビューはしない |
| 受け入れ | 設計者。範囲の変更、保証の変更、未達・判定不能、最終候補を判断する |

C1（詳しい設計）とC2（本書・依頼文・目標JSON）の後、P1で[事前点検](reviews/preflight.md)の15指摘を反映した。対応は[preflight-response](reviews/preflight-response.md)とR117〜R131に記す。preflightとは別に[RV1](reviews/RV1.md)を実施済みであり、P2で全9指摘を反映する。対応は[RV1-response](reviews/RV1-response.md)とR132〜R140に記す。実装の開始は別の指示による。今回のP2ではDの文書だけを変更し、実装・Leanビルド・測定は行わない。docs/todoのTODO-250、試作と方向のメモは経緯の資料として読み、要る契約はdesign・study・todo-itemsへ集めてある。公開文書から非公開資料へリンクしない。

## 段の順序とレビュー

機能を閉じる28作業とする。P1の26作業のL3とL4だけを、それぞれL3a/L3bとL4a/L4bへ分ける（R134）。Lは形式化、Tは検査と診断、Bは構築器とblock、Hは実行の共有、Gはライブラリと道具、Mは測定の準備、Vは最終の版と文書である。実装作業にZ・A・Q・S・Cで始まるIDを使わない。task.shは作業IDごとに動くため、この四つは別の作業IDとして依頼・検査・結果を持たせる。一作業内の続きはL3ac2のように付け、別作業へ数えない。本書の「L1〜L7」は分割後の9作業を含む範囲を指す。

| 段 | 作業・順序 | 先行条件 | 新しく接続するもの | レビュー |
|---|---|---|---|---|
| 0 詳しい設計と点検反映 | C1・C2・P1・P2 | 63問のAとB17、preflight・RV1と設計者の回答 | 公開契約、定理、検査と測定の割り当て、各指摘の対応 | preflight・RV1実施済み。P2でRV1を反映 |
| 1 全Lean | L1→L2→L3a→L3b→L4a→L4b→L5→L6→L7 | P2でRV1の指摘を反映 | 有界Integer、局所コアと継続、表層、block/穴、小証明と交換のLean側 | RV2後までRustへ進まない |
| 2 検査と診断 | T1→T2→T3→T4→T5 | 全LeanとRV2 | Coverage、脱糖/IR検査、DAG/T3、自由変数と診断 | stage2。RV3は次段末 |
| 3 構築器とblock | B1→B2→B3 | T1〜T5 | Hostバッファ、専用コアからVM/参照評価、blockの全走査 | RV3 |
| 4 実行の共有 | H1→H2 | B3・RV3の指摘反映 | 通常値の双方向変換、test起動内の外部準備 | 次段と一緒にRV4 |
| 5 ライブラリと道具 | G1→G2→G3→G4→G5→G6→G7 | H2 | Log/位置、検査済みの値、derive、旧道具の保管、Writerの中断 | RV4 |
| 6 共通測定器の準備 | M1 | G7・RV4の指摘反映 | 既存compareの族、計時境界、目標の全指標 | 段末検査は置かずV1へ |
| 7 版・同梱物 | V1 | M1、未解決指摘なし | 0.0.10、英日、Skill、移行案内 | 取りまとめの全検査・測定・照合後にRV5 |

この順序を標準とし、並行実装の指示にはしない。M1の入力仕様は本書で固定し、測定器の実装は後段へ置く。Rustの交換出力は各機能で順に実装するが、版全体の正式な接続完了はV1後の全比較で宣言する。途中で全比較を済ませた扱いにしない。

## Leanを先に完了する範囲と区切り

内外の判定はdesign 12.8節に従う。248の専用コア・局所文脈・ストア/継続、191、192、blockは内側である。022は独立した小証明、Logは既存の操作/ハンドラの適用例であり、本体の新しい仮定ではない。位置の事前展開、DAGと行ごとの照合、物理GC、生成道具等は対象外の理由を07-04へ反映する。未実装のRust機能を現行設計へ先に書かず、次の担当が実装の完了時に07-04「01-12との対応」の表へ対象外の行を追加して確定する。各行には実装した対象、形式化の対象外とする理由、抽象意味との対応を別に確かめる検査を記す。V1でdesign 12.8の全項目と照合する（RV2軽1）。

| 07-04へ確定する対象外の行 | 担当 | 抽象意味との境界と実装の照合 |
|---|---|---|
| Logの位置の事前展開・名前解決・CLI | G1 | 展開済みの通常レコードを既存規則へ渡す前の処理。元位置・標準束縛の識別・許可とCLI報告を照合 |
| Logの既定書式とIO | G2 | 通常操作の型とハンドラの例から、実出力の書式・回数・順序・失敗を導いたことにはしない。両IO方式と実CLIで照合 |
| 判定の共有と行ごとの照合 | T3 | 下位IRのDAG・行ごとの照合と予算は外側。Core MatchとCoverageの意味、選択肢とガードの順を維持 |
| 自由変数・生存の解析とIR検査の表 | T4 | T2のir/checkの表とT4の索引・根は実装上の処理。型付け・脱糖と安全点を越える保持を別に照合 |
| 構築器の物理バッファ・容量と予約失敗 | B1 | 抽象の不変内容と論理上限だけでは、実バッファ・capacity・heap_bytes・OOMを保証しない。実Hostとヒープで照合 |
| 構築器のGC・継続の保持とタスク取消 | B2 | 抽象ストア・継続から物理GCや根の解除を導かない。専用Slot・同じHostの保持・破棄・取消をヒープで照合 |
| Writerの解放と中断 | G7 | 抽象のreleaseや事象は実Writerの同期・flush・一度目/二度目の中断を保証しない。実プロセスで照合 |
| deriveの宣言グラフと生成器 | G4 | 生成道具自体は外側。生成した通常コードには既存の型・効果・脱糖を適用し、有限基底と予算を別に照合 |
| deriveの縮小と生成記録 | G5 | 縮小の候補順・署名・記録移行は外側。生成した通常コードと管理領域・hashを照合 |
| 旧移行道具の保管 | G6 | 道具の保管・復元手順は形式化した言語の判断を変えない。移動前後のhashと現役の参照を照合 |
| 参照値とヒープ値の橋渡し | H1 | 双方向変換の共有・循環拒否・epoch内の対応表は外側。物理表現の共有と書き換えを独立期待値で照合 |
| Engine・Componentの共有 | H2 | 外部実行基盤の共有・Storeの隔離・制限・中断は外側。コンパイル回数と実行ごとの状態を照合 |
| 宣言由来の診断と型名・整数の警告 | T5 | 診断の由来・抑制・表示は形式化した型付けの外側。独立の誤りとJSON/テキストを照合 |

各L作業は既定import全体がビルド可能な単位で終える。Leanは`formal/`で実行する。01-12の写しと07-04の対応表は、後のL7にまとめて先送りせず、その定義を切り替える作業で更新する。01-12のtext例を変えた場合だけ仕様例も検査する。構成子を先に追加するL3aも、その全読者と既存証明を同じ作業で直し、壊れた取り込みを作らない。

L3aは新しい構成子を先に追加するが、その型付けと関係`Step`の規則はまだ追加しない。L3bで型付け・実行と全定理を接続する。L4aはState/refsを保って脱糖だけを専用コアへ替え、L4bでState/refsを除く。各作業末に既定のlake buildがsorryなしで通ることを必須とする。続きへ渡すときは、通った区切り・未採用の案・残る全読者・公理一覧・次の一手を当該resultsへ残す。未証明の定理を宣言して穴を埋める方法、既定importから難しいファイルを外す方法は採らない。下の四区切りを保てない場合だけ、R111を具体化したR134に従い設計者に相談する。

| 区切り | ビルド可能な到達点 | そこで相談する条件 |
|---|---|---|
| L1 | Integerだけの有界定数、全読者と従来定理が新しい表現で通る | I1/I2が閉じない、全状態への新仮定、第二の重い形式化。191を外す案は承認を待つ |
| L2 | 全域/穴/ガード/相関と補題U・各系が通る | 網羅性の定理の保証対象を狭める必要 |
| L3a | Comp.builderLet/builderOp・Cell.builder・LocTy.builderと全構文走査を追加。新項の型付け/StepはなくCellOkのbuilderは偽。hideBuildersの強化/弱化・冪等性/単調性、σ/ρと範囲・上限の補助、旧主定理が通る | 新項を型付き状態から排除しても既存定理やモデルを保てない |
| L3b | 専用の型付け/Step/BuilderCellOkと全主定理、継続・破棄が通る。旧表層のReference脱糖もこのコア上で通る | 主定理の条件変更、通常releaseのStateの除去、新公理/Assumptions |
| L4a | 表層のrefs・Stateとcheckerを保ち、専用コアへ脱糖。C_EffでStateを含む表層の効果まで広げ、性質1と全定理が通る | 共有番号の対応や効果拡大を外部仮定にしないと通らない |
| L4b | 表層の操作/宣言からState・refsを除き、全読者と公開checker11件/programが通る | 未検査の表層を成功扱いにする必要 |
| L5 | blockとArgPlanの全走査・型保存・checkerが通る | B17が主定理の条件かLean段の大幅増加へ響く |
| L6 | 独立小モデルとLogの通常宣言/ハンドラ例が通る | 小証明を本体の公理へ取り込む必要 |
| L7 | 新版の六入口と独立入力、写し・全体importが通る | 旧交換の非互換を黙った読み替えで隠す必要 |

全区切りでsorryなしの既定ビルドを条件とする。L1前にformal/READMEの公理確認一覧で開始版を記録し、各切り替え後に同じ一覧と追加定理を比較する。型付け・WellTyped・StateTyの定義を通じた意味もRV2で比較する。R133のBuiltins.Assumptionsの意味の変化は形を保ったまま既存全モデルで確認し、強化を使った箇所と対象のない箇所を区別してL3a/L3bの結果に残す。主な定理の前提/結論変更、公理/Builtins.Assumptionsの追加、既存結論の弱化は停止条件である。補助補題の表現に伴う前提の拡張は、導出元とともにdecisionsの続きのR番号へ記す。

## 共通の関門K

依頼文の共通部は[implementation-request](implementation-request.md#依頼する内容)を正とし、ここではこの改造に固有の条件を定める。

| 関門 | 各作業が満たす条件 |
|---|---|
| K範囲 | designのAPI・失敗の優先順・受け入れ例を守る。変更した保証と実装済みの章・生成Skillを同じ状態へそろえる。版はV1で一度だけ上げる |
| K形式化 | 上表とRV2をRustの前提にする。通常State/Fail/Log/IOと通常リソースの解放を残す |
| K捕捉と制御 | blockはreturnの境界を作らない。構築器を普通の値/辞書/クロージャへ持ち出さず、保存継続から必要なセルは残す |
| Kヒープ | HostData/Trace・SlotOps/host_mut・既存H1〜H7を使い、新ObjKind/unsafeを加えない。安全点を越す値は根で保持する。容量のchecked演算と失敗前の内容不変を確かめる |
| K入力の大きさ | GCを伴う実行の深い再帰・長いリスト・共有構造は、長いテストも含め`cfg!(feature = "gc-stress")`で縮める。型検査・下位化・IR検査だけで深さを確かめる入力は縮めない（RV3軽5）。新規の標準値は、再帰深さ128/16、リスト長4096/64、共有合成の深さ12/6（既定・heap / stress）。契約上さらに大きさが要る場合は実装前に理由と両構成の大きさをresultsへ固定する。既存対象はこの改造で触るものを作業開始時に点検する。大きさ自体の性能判定はcompareへ置く |
| K入力の読者 | goldenの変更はgolden・verify・codegen corpus、コア/下位IR・標準宣言の変更は全読者、生成記録はpreviewからcheckまでを対象にする。機能の主なテストはdesign 14節の契約の持ち主に集める |
| K予算 | R102の上限と計数単位を使用し、確保前に検査する。E0609とL0112、失敗/停止と比較不能を区別する |
| K測定 | [目標JSON](bench-targets.json)とdesign 15節を使う。計時/alloc/RSSを別実行にし、欠測を0にしない。targetsの本測定前に設計者の準備の合図を待つ |

## 内部の受け渡しと型・シグネチャ

公開の言語APIはdesign 3・5・7・8節の署名をそのまま使う。下表はC2で固定する新設の内部契約であり、既存インターフェースを無断で変える許可ではない。既存の`check_program`・`lower_program`・`codegen`等の公開の入口とエラー型は維持する。既存の型や署名の変更が下表にないのに必要になれば、該当箇所と利用側を示して取りまとめへ戻す。

| 所有作業 | 固定する内部契約 |
|---|---|
| L3a/L3b/L4a/L4b | Leanの新名・型付けはdesign 12.1〜12.3のHasTypeCL/HasTypeC、LocalRef、BuilderCellOkを使う。公開定理は空Δの入口を保つ。表層/コアで番号を共有し、builderLetはΓへnone・Δへsome k、通常束縛はΔへnoneを積む。bound iとvar iは同じ番号、環境対応は恒等とし、射影の補題は置かない。σ/ρの置換は既存補題へ統合し、builderLetのσ 0は.const .unitとする。HasTypeVQへΔを足さず、隠す位置はdesign 3.3の表に限定する。値の強化・hideBuildersの冪等性/単調性・弱化を証明し、Assumptionsの意味を全モデルで確認する。BuilderCellOkは種類ごとの論理上限を含み、超過時はR0902相当のerrorへ進む |
| T2 | `ArgPlan<C> = Direct(Val<C>) / Evaluate(C)`。sequenceはEvaluateだけLetを作る。ir/checkは借用する宣言表と、局所更新ログの長さを印にする復元を使い、公開check_programの型を変えない |
| T3 | 私有`NodeId(u32)`、`DecisionArena { nodes: Vec<Node> }`と同型の辺/節の計数。公開LowerProgramは既存Join/Jumpへ一度だけ書き出し、共有先はjoinの本体一つとする。T2試行の前の番号・節・予算の印へ戻してからT3を生成する |
| T4 | 本体ごとの私有`BodyAnalysis`に使用位置と捕捉順の索引を持つ。通常値と専用保持先の索引を分ける。問い合わせで残りの本体を再走査しない |
| B2 | `core_ir::BuilderId(pub u32)`（既存の`resolve::builders::BuilderId(pub BindingId)`から別表で対応付ける）、`BuilderKind { String, List(Ty), Bytes }`をcore_irへ置く。`CompKind::BuilderLet { id, kind, body: Box<Comp> }`、`BuilderOp { id, kind, op: resolve::builders::BuilderOp, args: Vec<CoreVal> }`を追加。下位IRにも同じ宣言/操作を写し、argsだけ通常値とする。別のBuilder値をValKindへ追加しない |
| B2（命令） | Opcodeの末尾へBuilderNew=91/Append=92/AppendAll=93/Copy=94/Length=95を追加。各命令はABxでA=通常結果（Newは未使用0）、Bx=Proto内`builder_sites`の添字。`BuilderSite { local: u16, kind: BuilderClass, args: Vec<u16> }`を新設し、append等のUnitもAへ書く。Listの要素Tyはコンパイル時の宣言/検査に持ち、実行kindは三分類。Protoへ`builder_slots: u16`と`builder_sites: Vec<BuilderSite>`を追加する。検証器はA/Bx・局所欄・引数個数・種類・定義と支配関係を検査する |
| B2（根） | Frameの専用保持先は通常レジスタと別のSlot配列。`LiveItem::Builder(u16)`で通常値と区別し、保存継続/タスクの枠が同じ配列を保持する。確保前に局所欄数/サイト添字の符号化上限を検査し、専用Slotの容量を呼び出し枠のREG_COSTとmax_call_stack_bytesの計数に含める。生存しなくなった専用Slotを既存の根の解除に合わせてclearし、別スコープのHostを枠の終了まで保持し続けない。joinの専用保持先はBuilderIdの対応で継承し、通常のjump引数へ偽装しない。UserHandleBodyの例外は次行の専用欄だけで扱い、通常のクロージャのCaptureSourceへ追加しない |
| B2（handle本体、R132） | Protoへ`builder_inputs: Vec<BuilderInput>`、`BuilderInput { source: u16, target: u16, kind: BuilderClass }`を追加する。sourceは親の枠、targetは本体の枠の専用Slot番号。`ProtoOrigin::UserHandleBody`だけが非空の欄を持てる。Handle命令が本体を起動するとき、同じHostを指す根付きSlotを親から本体へ渡す。バッファをcopyせず、通常のClosure/CaptureSourceには保存しない。コード生成と検証器は生成元の親Protoとの対応、source/targetの範囲・種類・定義/生存、targetの重複なしを検査し、本体のProtoをHandle以外の通常呼び出し・値の持ち出しへ使うことを拒否する。handleFailも同じ入口を使い、入れ子は直近の親から渡す。追加Slotと欄の容量/符号化上限は既存の資源計数へ含める。保存継続は本体の枠を保持し、親と本体のSlotは各々の生存に従い解除する |
| B1 | 私有StringBuilderData/BytesBuilderData/ListBuilderDataはdesign 4節の構造。操作はNoGcCtxの区間内でValueを扱い、外へは既存Slot/根だけを渡す。非公開の補助は`new<'e>(&NoGcCtx<'e>, BuilderClass) -> Result<Value<'e>, Stop>`、`apply<'e>(&NoGcCtx<'e>, BuilderClass, BuilderOp, Value<'e>, &[Value<'e>]) -> Result<Value<'e>, Stop>`相当とし、host_mutのSlotOpsで書く。Heapの公開署名は変えない |
| H1 | 私有ToHeapSession/FromHeapSessionを一呼び出しの引数全体/戻り値の区間ごとに作る。行きは保持したRcの同一性と種類/タグ、戻りはObjIdと種類で引く。対応表はepoch内で破棄し、通常関数・外部関数の双方へ同じ区間を渡す |
| H2 | 新設`ExternalSession`が遅延Engine・Component表・見張りを所有し、`ExternalRuntime`は実行ごとのStore/Instance/handles/limits/run_idを持つ。既存`ExternalRuntime::new`は単独sessionの便宜入口として保つ。共有入口`new_in(session: Rc<ExternalSession>, options: ExecutionOptions) -> Result<Self, Stop>`をcrate内に加える。test起動が一つのsessionを通常/doc/複数入口へ渡し、`external::stats::ExecutionOptions`へcrate内の`session: Option<Rc<ExternalSession>>`を追加し、既存のrun_program_with_externals/run_test_with_externals→VM設定→configuredの流れで渡す。session本体のEngine/表は内部可変の遅延領域に置き、実行状態を入れない。公開RunEnv/VmConfigに欄を加えない |
| G1/G2 | SourceLocation.hereは解決済み標準束縛の直接呼び出しをtyped AST前に通常レコードへ展開する。Logは既存IO操作表/要求とstderrの出力バッファへ接続し、専用の出力スレッドや大域ロガーを作らない |
| G4/G5 | inventory版2を維持。Pythonの型グラフは宣言ID/型引数付きの辺、基底の最小量、SCC番号を持つ。生成の内部補助は`予算・乱数 -> 値・実消費量・次の乱数`、公開Gen/Shrinkerは既存型を保つ。記録版3と生成規則3.0.0-syntax-batch4へ一度切り替える |

B2は共有型の欄追加を受け持ち、asm/disasm・検証・liveness・統計・VM・参照評価・交換を同時に更新する。上記の型名はRustの既存importと衝突しない範囲で私有名を合わせてよいが、番号・欄の意味・保持の契約を変える場合はR番号へ記録する。新設の外部準備所有者の共有は同一起動内の逐次実行に限る。

## 作業L1: Integer定数の有界化

- 目的: Integer定数の有界化をdesignの契約に合わせて閉じる。
- 触るファイル: `Const.integer`の全読者。formal/Benitoite/Release/{Syntax,Types,BuiltinTable,CoverageTypes,Coverage,Examples,Model}.lean、Surface/{Syntax,Typing,CheckPatterns,Desugar,Examples,CheckToolsExamples,CheckCounterexamples,CheckExamples,Monad2Examples,BuilderExamples}.lean、Exchange/{Convert,Syntax}.leanと整数読者、CoverageDiff/Main.lean、関連補題、01-12・07-04。開始時に全参照を検索して一覧を補い、既定import全体のビルドを保つ。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: Integer64Valueと、構文側の正の大きさmax64以下・直接負号2^63以下の証明付きの型を入れる。型付けの規則へ範囲前提を足さず、交換の読者で検査して作る。Literal.toConst/Pattern.toCore/脱糖を全域に保つ。全ての定数作成（DesugarのnegInt・dieFailureの整数1を含む）・δの結果の型・区間への射影を直し、別幅は触らない。Coverageの例も新しい表現へ移すが、全域の判定の期待は旧結果のまま通し、otherをなくす期待変更はL2で行う。
- 完了の条件: 境界両端・直接負号・範囲外の交換拒否が揃い、主定理の条件/仮定を増やさない。閉じない場合は191を自動で外さず相談する。 検査は後述のwork L1行と当該補完行を使う。
- 依存: RV1の指摘反映。
- 見込み: 3〜5時間（全読者の移行を含む。作業末の検査を含む予定枠。実測ではない）。

## 作業L2: Integer全域とCoverageの健全性

- 目的: Integer全域とCoverageの健全性をdesignの契約に合わせて閉じる。
- 触るファイル: formal/Benitoite/Release/{Coverage,CoverageExtension,CoverageTypes}.lean、Order/、Lemmas/CoverageRuntime.lean、01-12・02-05・07-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: 全域内の小区間の分割とotherの条件、補題Uと網羅/非選択の系を直す。ガード・入れ子の相関・一点の穴・上端+1・燃料切れを独立例へ置く。032に必要な意味の変更はここまでに閉じる。
- 完了の条件: 全域の被覆時だけotherをなくし、選択肢の順序とガードの扱いを維持する。 検査は後述のwork L2行と当該補完行を使う。
- 依存: L1。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業L3a: 専用コアの構文・全走査と捕捉の補題

- 目的: 新しい構成子と補助を、まだ型の付かない構文として追加し、既存の全定理が通る区切りを作る。
- 触るファイル: formal/Benitoite/Release/{Syntax,Typing,Subst,Semantics,WellFormed,Assumptions,Model,Theorems}.lean、Type*・Lemmas/と全モデル・Surfaceのコアを読む全読者、01-12・07-04。仕様を変える生成Skillも同じ変更で作り直す。
- 手順: BuilderKind/LocalRef/BuilderContents、Comp.builderLet/builderOp・Cell.builder・LocTy.builderを追加する。rename・σ/ρの置換・型代入・VarsIn/VarsInNoLamNames/ClosedNoEffVars・Frame.Closed/Cell.Closed・WellFormedと実行関数stepの構文上の場合をそろえる。この時点では新項の型付けと関係Stepの規則を足さず、CellOkのbuilderの場合は偽、stepの新項は未対応としてnoneを返す。型付き状態では新項/セルが現れないことから既存定理を保つ。内部HasTypeCLへの移行も専用項を型付けしない範囲で行う。builderLetのσ 0は閉じた.const .unitとし、LocalRef.boundの範囲を全述語へ通す（R135）。
- 手順（補題）: design 3.3の列挙どおりV_Lam/C_Lazy/節/thunk/ContTyの節をhideBuildersへ替え、冪等性・単調性・hideBuilders_sub・値/値列/各要素の強化・弱化、rename/置換と上限の補助を閉じる。値の強化のV_Lamは冪等性を使い、計算の強化を仮定しない。型付きストアのdomにはbuilderがないので、そこでのhideは恒等と一致する。任意のΨについて恒等とは主張しない。Assumptionsを作る全モデルの証拠を新しい判断で確認し、意味の変更をR133に対応させて結果へ残す。
- 完了の条件: 新項に型付け/Stepがないこと、旧表層のReference脱糖と全主定理・全モデル・写しがそろい、既定lake buildがsorryなしで通る。専用操作の実行や保存を証明済みとは扱わない。検査はwork L3a行と補完行を使う。
- 依存: L2。
- 見込み: 5〜10時間（全構文読者と補題・作業末の検査を含む未実測の枠）。

## 作業L3b: 専用コアの型付け・実行と保存継続の全定理

- 目的: L3aの新構文へ型付けと実行を与え、全主定理を接続する。
- 触るファイル: L3aのRelease/全モデル・Type*・Lemmas/とSurfaceのコアを読む全読者、01-12・07-04、関係する生成Skill。
- 手順: 専用の型付け/Stepと実行関数stepを一緒に接続し、CellOkの偽の場合をBuilderCellOkへ替える。通常置換/型代入・ストア拡張・ContTyと全主定理を更新する。BuilderCellOkへruntime/mod.rsと同じ論理上限を含め、超過は内容不変のR0902相当のerror、lengthは上限から有界整数を作る規則にする。進行/保存/無事象でエラーの一歩も扱う。capture/resume/drop・Fail/escape/release、Referenceの.valセルだけの不変、copyの安定性を閉じる。builder_frames_releases_nilと、drop後に解放枠を積まず.run (.ret v) k (σ.set κ .used)となるdrop_local_silentを別々に証明する（R136）。Assumptionsの既存全モデルの証拠を再確認する。表層は既存Reference脱糖で通す。
- 完了の条件: 全主定理と旧表層・モデルが通る。専用locは通常Valへ現れず、保存継続は同じ専用セルを参照する。既定lake buildがsorryなしで通り、物理GCの証明とはしない。検査はwork L3b行と補完行を使う。
- 依存: L3a。
- 見込み: 8〜16時間（専用規則と全定理・作業末の検査を含む未実測の枠）。

## 作業L4a: Stateとrefsを保った専用コアへの脱糖

- 目的: 表層の受理と効果を保ったまま、脱糖先だけを専用コアへ替える。
- 触るファイル: formal/Benitoite/Surface/{Builders,BuilderLower,BuilderFree,Desugar,Typing}.lean、Lemmas/Builder*・Typing*・Scoped*と全読者、Exchange/の期待コア、01-12・07-04、関係する生成Skill。
- 手順: 表層とコアのΓ/Δの恒等対応、共有番号のshift/renameと捕捉の補題を接続する。builderBindはΓへnone・Δへsome k、通常束縛はΔへnoneを積む。六関数へ環境を足さず、builderOpの番号i+ms.lengthを専用コアへ渡す。fillBuildersと二つの射影を新脱糖から除く。表層のrefs/BuilderRefs/refs.Ok、E_BuilderOp/B_BuilderBindのState、checkerはまだ保つ。専用操作にないStateはC_Effで表層の効果まで広げて型保存を示す。通常のReference脱糖へ読み替えてStateを消した扱いにしない。
- 完了の条件: 性質1・surface_effect_soundness・公開checkerの健全性が、State付き表層と専用コアの組で通る。既定lake buildがsorryなしで通る。最終のState除去と交換13/5の完了とはしない。検査はwork L4a行と補完行を使う。
- 依存: L3b。
- 見込み: 4〜8時間（全脱糖の読者と作業末の検査を含む未実測の枠）。

## 作業L4b: 表層のState・refsの除去と検査器の接続

- 目的: 専用コアへ接続済みの表層から、構築器に由来するStateと旧参照先を除く。
- 触るファイル: formal/Benitoite/Surface/{Syntax,BuilderSyntax,Builders,BuilderLower,BuilderFree,BuilderCheck,Typing,Check*,Finite*}.lean、Lemmas/Builder*・Scoped*、SurfaceCheck/、Exchange/{Syntax,Convert,Version}.lean等の全読者、01-12・07-04、関係する生成Skill。
- 手順: E_BuilderOp/B_BuilderBindから専用操作のStateを外し、通常引数の効果だけを残す。Expr.builderOp/Block.builderBindのrefsとBuilderRefs/refs.Okを全読者から除く。七判断・全構成子・strict/relaxed・支持/範囲/捕捉・公開checker11件/programを一緒にそろえる。通常Stateを残す対照と関数/遅延/節のbound/locの捕捉拒否を用意する。必要な交換13/5の分岐も直し、版12の構築器を「版13で再生成」で拒否する。
- 完了の条件: 性質1・surface_effect_soundness・検査器健全性が最終の新規則で通り、既定lake buildがsorryなしで通る。通常Reference/解放のStateとFail/Log等を消さない。旧builderを黙って受ける暫定変換は作らず、L7へ既存batch3の期待変更と新入力への移行を渡す。検査はwork L4b行と補完行を使う。
- 依存: L4a。
- 見込み: 4〜8時間（全表層読者と作業末の検査を含む未実測の枠）。

## 作業L5: 穴の直接参照とブロック式

- 目的: 穴の直接参照とブロック式をdesignの契約に合わせて閉じる。
- 触るファイル: formal/Benitoite/Surface/{Syntax,Typing,Desugar,Check*,SingleFail,BuilderFree}.lean、Lemmas/{Sequence,BlockSequence,Calls,Scoped*,Builder*}.lean、SurfaceCheck/、Exchange/{Syntax,Convert}.leanと版の読者、01-12・07-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: ArgPlan/sequenceArgsへ替え、固定式だけLetにする。既存BlockへのExpr.blockを追加し、Rとposをそのまま渡す。Expr.Exitsへ`.block body => body.Exits`を加え、BuilderFree/Scoped/AtomsIn/SingleFail/捕捉を含む相互帰納の全述語とcheckerへblockの場合を足す。末尾のblock内のreturnを持つラムダの受理も確認する。穴/固定式の番号と評価順、blockの通常値/return/持ち出し拒否を独立期待コアへ記す。Exchangeは版13だけでblockを受け、旧版の同じ欄を拒否する（R138）。L7へその独立入力を渡す。E0439はRust側の検査とする。
- 完了の条件: 余分なLetを正規化で隠さず性質1とcheckerを維持する。block専用のmark/コア/効果消去を足さない。 検査は後述のwork L5行と当該補完行を使う。
- 依存: L4b。
- 見込み: 3〜6時間（作業末の検査を含む予定枠。実測ではない）。

## 作業L6: 検査済みListの小証明とLogの適用例

- 目的: 検査済みListの小証明とLogの適用例をdesignの契約に合わせて閉じる。
- 触るファイル: formal/Benitoite/Checked/{ListLength,ListIndex,NonEmptyList}.lean（新規）、Surface/の例、Benitoite.lean、01-12・07-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: design 12.7の成功の同値・失敗の同値/優先順・射影・head/tail/mapを独立小モデルで証明し既定importへ入れる。Logの標準宣言とemit/enabled/送り直し/外側Console.Writeの例を既存checkerで検査する。位置は展開済みレコードとする。
- 完了の条件: 小モデルと通常コードの実装保証を区別し、Log用の新公理・効果消去規則を足さない。 検査は後述のwork L6行と当該補完行を使う。
- 依存: L5。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業L7: 交換13/5・独立入力とLean段の引き渡し

- 目的: 交換13/5・独立入力とLean段の引き渡しをdesignの契約に合わせて閉じる。
- 触るファイル: formal/Benitoite/Exchange/{Version,Syntax,Convert,CheckInput,Builtins}.lean、六入口のMain/SurfaceCheck、formal/tests/、formal/README.md、01-12・07-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: corpus 8〜13・sidecar 2〜5を受ける全読者を揃え、sidecarVersionを13→5、11/12→4、8〜10は既存の対応へ分岐させる。版13の構築器はL4bでrefsを除いた表層と専用コアで読み、旧refs/newRef/getRef/setRefは持ち込まない。corpus 12の構築器の欄は「版13で再生成」の理由で拒否し、構築器なしのcorpus 12は整数の範囲検査後に受ける。test_batch3_exchange.pyとbatch3-exchange/corpus.jsonの構築器の意味の受理/拒否を版13のtest_batch4_exchange.pyと新corpusへ移す。batch3は版12の構築器の拒否理由を確認する形へ替え、構築器なしの検査は変えない（R137）。L5が接続したblockの版13での受理と旧版での拒否、有界整数の拒否も新独立入力へ含める。本番Rust入力の予定件数と六入口への割り当てを記し、公理一覧・Assumptionsの意味とモデルの証拠・写しを照合する。
- 完了の条件: 既定importの全ビルド、独立交換検査、写しが揃いRV2へ渡せる。旧batch3の構築器は受理から拒否へ変わることと、新版へ移した意味の検査の対応が明確であり、それ以外の旧版の扱いを保つ。Rust全比較は未実施と明記し、tests/desugar_exportの13/5への切り替えはB2、全比較の件数変更は各Rust作業とV1に渡す。 検査は後述のwork L7行と当該補完行を使う。
- 依存: L6。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業T1: Integer全域・Coverageの列挙と資源予算

- 目的: Integer全域・Coverageの列挙と資源予算をdesignの契約に合わせて閉じる。
- 触るファイル: src/typeck/patterns.rs・pattern_ext.rs・limits.rs（既存MAX_COVERAGE_WORKとR102の三つの新しい上限）、tests/coverage_export.rs・golden入力、設計01-05・02-05。整数全域の実行への接続としてsrc/ir/decision.rsと設計02-06も対象にする（R159）。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: Leanで決めた列と順に合わせて境界の整列とStringの出現順集合を実装する。match内の記憶と列挙/キー予算を確保前に検査し、超過時は当該matchの中途診断をE0609へ替える。Integer全域とcase _の移行を現行章へ反映する。
- 完了の条件: design 6・9.1・14節の全域/穴/ガード/相関と予算拒否、独立の別の誤りが残る。局所のcoverage交換を照合する。一点の穴の交換出力はotherの表示 `_`、利用者向けE0601の診断は具体値 `0` とし、複数の未被覆区間では昇順の最初の区間の下端を示す（design 14.3、R157）。交換と診断の独立した厳密な期待値を両方確かめる。 検査は後述のwork T1行と当該補完行を使う。
- 依存: L7・RV2。
- 見込み: 1〜2時間（作業末の検査を含む予定枠。実測ではない）。

## 作業T2: 穴の脱糖とIR環境の復元

- 目的: 穴の脱糖とIR環境の復元をdesignの契約に合わせて閉じる。
- 触るファイル: src/ir/desugar/{exprs,tests}.rs・src/ir/check.rs、tests/desugar_export*・named_arguments.rs・verify.rs、設計02-05/06。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: L5のArgPlanへ一致させ、calleeと固定式の評価順/一回性を保つ。Envの宣言表を借用し局所の復元ログと明示の作業列へ替える。成功/失敗/早期戻りと兄弟枝で未登録とnoneを区別して戻す。
- 完了の条件: 穴の数だけLetが減り必要なLetは残る。不正IRを公開check_programが拒否し、捕捉制限とスタックの保証を保つ。 検査は後述のwork T2行と当該補完行を使う。
- 依存: T1。
- 見込み: 2〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業T3: 判定の共有と行ごとの照合への切り替え

- 目的: 判定の共有と行ごとの照合への切り替えをdesignの契約に合わせて閉じる。
- 触るファイル: src/ir/{decision,lower_ir}.rs・src/bytecode/codegen/、tests/golden*・verify.rs・random_programs.rs、設計02-06/07。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: Treeを私有arenaへ替え、正規化した取り出し元/束縛元/失敗先で共有する。Join/Jumpへ一度書き出し、共有本体をcloneで再展開しない。T2予算時に当該試行だけ巻き戻してT3へ替える。直積を事前展開せず選択肢/ガードの順を維持し最終上限を確保前に検査する。
- 完了の条件: L0112だった指定入力がT3で成功し、最終上限はL0112、Coverage不足はE0609のまま。ガードは一caseで一度、偽なら次case。Core Matchを変更しない。07-04の対象外の「判定の共有と行ごとの照合」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork T3行と当該補完行を使う。
- 依存: T2。
- 見込み: 3〜5時間（作業末の検査を含む予定枠。実測ではない）。

## 作業T4: 本体ごとの使用位置・捕捉と生存の解析

- 目的: 本体ごとの使用位置・捕捉と生存の解析をdesignの契約に合わせて閉じる。
- 触るファイル: src/bytecode/codegen/{analysis,state,emit,tables}.rs・liveness.rs、tests/verify.rs・vm_handlers.rs・vm_lazy.rs、設計02-07/08。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: Letの後ろから使用を増減し、本体の索引を一度作る。初出の捕捉順、辞書、join、終了報告を含め、分岐ごとの全集合の複製をなくす。後のB2の専用保持先を分けて加えられる索引とする。
- 完了の条件: 同じ入力の結果と根の保持を維持し、安全点を越える値を落とさない。索引だけの自己比較で完了にしない。07-04の対象外の「自由変数・生存の解析とIR検査の表」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork T4行と当該補完行を使う。
- 依存: T3。
- 見込み: 2〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業T5: 宣言由来の診断・同名型・幅付き整数の警告

- 目的: 宣言由来の診断・同名型・幅付き整数の警告をdesignの契約に合わせて閉じる。
- 触るファイル: src/typeck/{generate,solve,infer,context,text,consts}.rs・traits/、src/diag/・cli/mod.rs、tests/golden*・declarations.rs、設計02-05/10。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: 宣言からの制約の出どころと型部分への辺を残し、根を無効化してから依存する偽診断だけを保留/抑制する。診断内の全型の衝突だけを同じ修飾表で表示する。解決済み標準束縛の幅別表でW0401/W0402を判定する。
- 完了の条件: design 10節の再現全種と独立の真の誤り、JSON/テキスト、別名/利用者同名関数、min/-1/moduloの対照を満たす。07-04の対象外の「宣言由来の診断と型名・整数の警告」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork T5行と当該補完行を使う。
- 依存: T4。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業B1: 三種類のHostバッファ・容量・予約失敗

- 目的: 三種類のHostバッファ・容量・予約失敗をdesignの契約に合わせて閉じる。
- 触るファイル: src/runtime/heap/のHost操作と新設builders.rs、src/runtime/mod.rsのStop/ResourceError、src/diag/codes.rs・runtime/report.rs、設計02-09/10。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: 新ObjKindなしで三型を作り、capacityとheap_bytesを計上する。new/append/appendAll/copy/長さをNoGc区間へ実装し、checked加算/乗算/上限/予約/書き込みの順を守る。Listの書き込みをSlotOpsへ集め、R0907を接続する。既存の実行経路はB2で一度切り替える。
- 完了の条件: 実Hostの操作をヒープの境界で確認する。上限超過は確保前、予約失敗は内容不変、copy後の追記がsnapshotを変えない。B2へ渡す前に局所ヒープ/doc/check-heapを通す。07-04の対象外の「構築器の物理バッファ・容量と予約失敗」行を、実装と上の境界・検査に合わせて確定する。BuilderInvalidByteはLeanのByteをNatで表したことによる失敗であり、Rustの診断・停止・交換の期待値に加えない。Rustの論理上限超過はR0902、物理予約失敗はR0907として区別する。 検査は後述のwork B1行と当該補完行を使う。
- 依存: T5。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業B2: 構築器の専用コアからVM・独立参照評価まで

- 目的: 構築器の専用コアからVM・独立参照評価までをdesignの契約に合わせて閉じる。
- 触るファイル: src/typeck/builders.rs・ir/{core_ir,lower_ir,check,decision}.rs・ir/desugar/builders.rs、bytecode/全読者、vm/、refinterp/、tests/desugar_export*（版の書き出しを含む）・golden*・verify.rs・vm_*.rs、src/prelude/stdlib/{StringBuilder,ListBuilder,BytesBuilder}.bnt、生成Skill、設計01-06/07/08/10・02-05〜09。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: まず既定のReference経路を保ったまま、内部契約の型・命令・検証器と参照評価の独自ストア/不変内容を追加し、ビルドと追加部分の局所検査が通る区切りを作る。UserHandleBodyだけのbuilder_inputsとHandle起動時のSlot受け渡しもこの追加段階へ含める。続きb2c2でState除去・専用コア・命令・実バッファを既定経路へ一度切り替え、専用Slotの生存/継続/破棄、引数一回、早期return/Fail/Stop/取消を接続する。交換13/5の本番出力（tests/desugar_exportの版）と新独立期待値を更新する。三つの標準ソース先頭の「Every operation uses State.」を局所操作の規則へ直し、同じ変更でgen_skillを作り直す。
- 完了の条件: 三種類と制御の全経路が実行できる。design 14.1の外側の構築器へhandle本体で追記し外でcopyする例をVMと独立参照評価で照合する。再開・未再開・handleFailの非再開・入れ子で同じHostの変更が残り、節で外側の構築器を使う変種はE0465のままである。本体の保存/破棄・親の生存/根の解除を局所特殊構成でも確認し、UserHandleBody以外の専用入力欄を検証器が拒否する。一般Stateは残る。未接続命令や一種類だけで完了にしない。保持の局所特殊構成と必要なcheck-heapを先に通す。構築器をガード/説明で観測する例はblockが必要なのでB3へ割り当てる。07-04の対象外の「構築器のGC・継続の保持とタスク取消」行を、実装と上の境界・検査に合わせて確定する。BuilderInvalidByteはLeanのByteをNatで表したことによる失敗であり、Rustの診断・停止・交換の期待値に加えない。Rustの論理上限超過はR0902、物理予約失敗はR0907として区別する。String・Bytes・Listのcopy後に元の構築器へ追記し、取り出した値の物理表現（共有したバッファを含む）の内容が変わらないことを、実ヒープと独立した期待値で確かめる。snapshot_structure_stableやcapture_local_valid/resume_local_validの第三の結論だけを物理表現の証拠にしない。 検査は後述のwork B2行と当該補完行を使う。
- 依存: B1のヒープ検査成功。
- 引き継ぎ: 追加段階はb2/results.mdに既定経路/通った検査/残る全読者/次の切り替えを記録し、続きはb2c2/results.mdを参照する。未接続の追加段階でB2完了としない。切り替え後は全読者とヒープの検査まで閉じる。続きは作業数に加えない。
- 見込み: 7〜12時間（追加段階とb2c2の切り替え、handle本体への専用入力と根の検査を含む。作業末の検査を含む予定枠。実測ではない）。

## 作業B3: block式の解析・名前・型・整形・交換

- 目的: block式の解析・名前・型・整形・交換をdesignの契約に合わせて閉じる。
- 触るファイル: src/syntax/・resolve/・typeck/・ir/desugar/・cli/tools/formatter/の全走査、tests/named_arguments.rs・fmt_command.rs・desugar_export*・vm_handlers.rs・verify.rs・golden入力、設計00-04・01-01/02/03・02-03/04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: blockを予約しprimaryへ追加、閉じる語/深さ/改行・到達不能を既存規則へ接続する。新スコープと既存R/posを渡し、既存Blockへ脱糖する。全走査・formatter・元位置・表層交換を揃える。
- 完了の条件: design 14の式位置・空/末尾束縛/Unit/return/lazy/ガード/捕捉拒否を満たす。通常ReferenceのStateがblock外に残る。14.1のガード内のappendをT2の共有した判定とT3の行ごとの照合の両経路で実行し、caseごとに一度、失敗時の追記の残存、ソース順をVM/独立参照評価で確かめる。両経路を通った根拠を結果へ残す。or dieの説明にcopy(b)を直接書く受理と、blockで追記してcopyする説明を失敗時だけ一度評価することも確かめる（R139）。T3時点では新構築器がないため、この観点の完了をT3の結果で代用しない。検査は後述のwork B3行と当該補完行を使う。
- 依存: B2。
- 見込み: 3〜4時間（ガードと説明の観測、T2/T3の両経路の確認と作業末の検査を含む予定枠。実測ではない）。

B3の作業末のlintはR177の全ターゲットclippyを一度実行する。R177の両経路の局所lib一件を、補完のheap-verifyとheap-verify+gc-stressでも実行する。

## 作業H1: 参照値とヒープ値の双方向の共有

- 目的: 参照値とヒープ値の双方向の共有をdesignの契約に合わせて閉じる。
- 触るファイル: src/refinterp/{convert,value,eval}.rs、tests/golden/differential.rs・random_programs.rs、設計02-08/09・07-03。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: 引数全体/戻り値の区間ごとの対応表と明示の作業列を入れる。Rcの保持・ObjId/世代・処理中の循環拒否・RootStackを保ち、外部入口も同じ変換区間を使う。構築器内部Slotは通常変換へ入れない。
- 完了の条件: 共有入力を差分から外さず、小さい観察結果で往復を照合する。対応表がepochを越えず、深い共有構造を再展開しない。07-04の対象外の「参照値とヒープ値の橋渡し」行を、実装と上の境界・検査に合わせて確定する。String・Bytes・Listのcopy後に元の構築器へ追記し、取り出した値の物理表現（共有したバッファを含む）の内容が変わらないことを、実ヒープと独立した期待値で確かめる。snapshot_structure_stableやcapture_local_valid/resume_local_validの第三の結論だけを物理表現の証拠にしない。 検査は後述のwork H1行と当該補完行を使う。
- 依存: B3・RV3の指摘反映。
- 見込み: 2〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業H2: test起動内のEngine/Component共有

- 目的: test起動内のEngine/Component共有をdesignの契約に合わせて閉じる。
- 触るファイル: src/external/{runtime,stats,check}.rs・adapter/runtime.rs、src/pipeline.rs（静的照合の計数、R186）、src/runtime/run.rs・vm/state.rs・vm/dispatch.rs・src/cli/tools/test_runner/、tests/test_command.rs・external_signals.rs、設計02-09/11・03-10・06-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: ExternalSessionをtest通常/doc/複数入口へ渡し、実行用キーをbytes/hash/Engine/ABIで照合する。Store/Instance/言語ヒープ/出力を実行ごとに作り、燃料と転送量を呼び出しごとに戻す。一つの見張りを最後の所有者が終了させる。
- 完了の条件: 同じキーの実行用コンパイルは一回。statefulの初期値は別testへ漏れず、制限/中断/静的な型拒否を維持する。07-04の対象外の「Engine・Componentの共有」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork H2行と当該補完行を使う。
- 依存: H1。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G1: Logの標準束縛と一般の位置の式

- 目的: Logの標準束縛と一般の位置の式をdesignの契約に合わせて閉じる。
- 触るファイル: src/prelude/・builtins/の宣言表、src/resolve/・typeck/・cli/check_report.rs・effect_limit.rs、tests/declarations.rs・checked_args.rs・test_command.rs、設計01-03/07・02-04/05・03-07・06-01。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: Log.Logを標準の識別で解決し、E0326の例外とE0339の禁止をR110の範囲に留める。SourceLocationの型と直接hereの展開/E0467を加える。元コメントへの位置復元、正規名Logの許可/報告、IO.All除外を揃える。既定処理の接続はG2へ渡す。
- 完了の条件: hereの値化/パイプ/別名と利用者同名を区別し、Logの宣言と報告のschemaVersion=1を維持する。G2前は実行機能の完了とはしない。07-04の対象外の「Logの位置の事前展開・名前解決・CLI」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G1行と当該補完行を使う。
- 依存: H2。
- 見込み: 1〜2時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G2: Logの既定出力と標準ハンドラ

- 目的: Logの既定出力と標準ハンドラをdesignの契約に合わせて閉じる。
- 触るファイル: src/prelude/stdlib/のLog/SourceLocation新モジュール、src/builtins/・vm/dispatch/のIOとrefinterp/、tests/io_modes.rs・runtime_builtins.rs・vm_handlers.rs・test_command.rs、設計03-07・02-08/09・06-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: emit/enabledと水準/ToLogValue/補助関数/withAttributes/withTextLogger/withSinksを通常の規則で実装する。探索後の未処理だけを既定Info以上のstderrへ送り、同じバッファ/中断/失敗経路を使う。標準宣言の本番交換を更新する。
- 完了の条件: 両IO方式で一回性・順序・エスケープ・水準・空sink・送り直し・失敗と外側効果を満たす。捕捉されたログを重ねて出力しない。07-04の対象外の「Logの既定書式とIO」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G2行と当該補完行を使う。
- 依存: G1。
- 見込み: 2〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G3: 長さ・添字・非空Listの不透明API

- 目的: 長さ・添字・非空Listの不透明APIをdesignの契約に合わせて閉じる。
- 触るファイル: src/prelude/stdlib/Range.bnt・NonEmptyList.bnt（新規）・登録、tests/runtime_builtins.rs・declarations.rs・stdlib_doc_examples.rs、設計03-06/07。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: design 7節の公開名/エラー/優先順を通常の@opaqueと関数で実装する。CheckedIndexは対象と成功要素を保持し、NonEmptyList.mapは順序と効果を保つ。小モデルと実装を同じ入力で照合しMAX_LIST_LENとIntegerの対応を記す。
- 完了の条件: 外部構築/更新/パターン/アクセサの拒否、成功/失敗境界、別Listへの流用不可とmapの順序を満たす。 検査は後述のwork G3行と当該補完行を使う。
- 依存: G2・L6。
- 見込み: 1〜2時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G4: 再帰・多相の宣言グラフと生成器

- 目的: 再帰・多相の宣言グラフと生成器をdesignの契約に合わせて閉じる。
- 触るファイル: examples/derive_inventory.rs・関連helper、tools/derive/の収集/生成と自己検査、設計03-08・06-06。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: 版2の解決済みinventoryからSCC/型引数の辺/有限基底を求め、正則性と機能別の拒否を検査する。sizeから総節点予算を作り実消費量を引く補助を生成する。型パラメータのGenを使用分だけ宣言順に渡し、子の作成をrun内へ遅らせる。
- 完了の条件: 自己/相互再帰・List/Option/String鍵Map・size0の基底と予算、phantom、基底なし/非正則の拒否を通常の生成コードで照合する。既存JSONの範囲は保つ。07-04の対象外の「deriveの宣言グラフと生成器」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G4行と当該補完行を使う。
- 依存: G3。
- 見込み: 2〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G5: 縮小・Show/Order・生成記録の移行

- 目的: 縮小・Show/Order・生成記録の移行をdesignの契約に合わせて閉じる。
- 触るファイル: tools/derive/の署名/生成/記録/preview-review-apply-check・README、examples/derive_inventory.rsの必要読者、tests/property_library.rs・declarations.rs、設計03-08・06-06。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: Shrinkerをcandidates内へ遅らせ、候補順/自己候補除去/節点数非増加を守る。Show/Orderの再帰制約を既存解決で閉じる。意味ハッシュとreceipt版3、生成規則版、旧本文照合→新preview→確認hash→apply/checkを一度切り替える。
- 完了の条件: 多相の署名/制約と深さの境界、旧manifest拒否・管理領域改変拒否・再適用/依存変更を満たす。閉じない辞書制約は新コアで救済せず相談する。07-04の対象外の「deriveの縮小と生成記録」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G5行と当該補完行を使う。
- 依存: G4。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G6: 名前付き引数の旧移行道具の保管

- 目的: 名前付き引数の旧移行道具の保管をdesignの契約に合わせて閉じる。
- 触るファイル: tools/named-arguments-migrate/・examples/named_arguments_inventory.rs・examples/named_inventory/index.rsの移動先D/historical-tools/、AGENTS.md、scripts/check.sh（python_syntaxのglob・分類・dry-run表示）、scripts/check/の必要な自己検査、tools/source-migrate/README.md、tools/try-actions-migrate/migrate.py（除外一覧）、docs/design/07-quality/07-03-compiler-testing.md、関係READMEと必要なworkflow。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: git mvする実装時に移動前のhash一覧を保存し、内容を変えず履歴資料へ移す。復元先/開始版/旧parserを使う説明を付け、Cargo自動発見と上の現役案内/除外一覧から参照を外す。python_syntaxのglobが消えたディレクトリを指さないようにし、分類とdry-run表示もそろえる。source/try-actions移行器の契約を保ち、policy_selftestで三つのシェルの構文を含めて確かめる。
- 完了の条件: 全ファイルがhash一致し、現役のビルド/検査が旧helperを要求しない。保管先で壊れた自己検査の成功を約束しない。07-04の対象外の「旧移行道具の保管」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G6行と当該補完行を使う。
- 依存: G5。
- 見込み: 0.5〜1時間（作業末の検査を含む予定枠。実測ではない）。

## 作業G7: 実Writerの解放と一度目/二度目の中断

- 目的: 実Writerの解放と一度目/二度目の中断をdesignの契約に合わせて閉じる。
- 触るファイル: tests/interrupt_process.rs・共通Process/FIFOの準備、必要な既存File.Writerの不具合修正、設計07-03・06-04。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。07-04の対象外の対応表も更新する。
- 手順: 最初に解放中のFIFO同期を試作する。両IO方式で準備行/未flushの短文→SIGINT/SIGTERM→130と全内容を確認する。二つのwithの解放開始と外側flushが完了不能な証拠を得てから二度目SIGINTを送り、シグナル終了を確認する。全失敗でも子/読み手/FIFOを片付ける。
- 完了の条件: 固定sleepやkill成功を同期の証拠にせず実Writerを検査する。FIFO同期が成立しなければ未達として相談し、テスト専用の本番フラグを加えない。07-04の対象外の「Writerの解放と中断」行を、実装と上の境界・検査に合わせて確定する。 検査は後述のwork G7行と当該補完行を使う。
- 依存: G6。
- 見込み: 1〜3時間（作業末の検査を含む予定枠。実測ではない）。

## 作業M1: 共通compareの族と観測の整備

- 目的: 共通compareの族と観測の整備をdesignの契約に合わせて閉じる。
- 触るファイル: tools/bench/compare/{model,analysis,run,validation,features}.py・timing_probe.rsとscenarios/・自己検査・README、D/bench-targets.json、設計07-02。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: 成功する型検査の退行を追跡するため、`bind x{i} <- x{i-1} + i` の連鎖（N=250/500/900）と `x + x * i` 400行を、compareの型検査時間の入力へ加える（RV3中2）。buildersのrequires/importをbuilder手法だけへ移す。design 15節と目標JSONの全点/計時境界/独立期待値、四つの新族を共通登録へ追加する。R/2R・IR検査・橋渡し・外部コンパイルの不足する観測を共通probeへ加え、IQR/2msと非正の差を判定不能にする。
- 完了の条件: 全目標が存在するCase/metricへ解決され、誤出力・欠測・標本不足・状態別拒否を正しく扱う。測定用CLIの起動やquick/本測定は取りまとめへ渡し、この作業で測定成功を記録しない。 検査は後述のwork M1行と当該補完行を使う。
- 依存: G7・RV4の指摘反映。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## 作業V1: 0.0.10・英日・同梱物と移行案内

- 目的: 0.0.10・英日・同梱物と移行案内をdesignの契約に合わせて閉じる。
- 触るファイル: Cargo.toml・Cargo.lock・CHANGELOG、docs/reference/benitoite.md・install.md・対応docs/ja/、crates/benitoite/skill/とdocs/ja/skill/、docs/design/の漏れ・目次、実装例/配布案内、Dの結果。この機能で変える仕様/診断/標準ソースの生成Skillも同じ変更で作り直す。
- 手順: 版を0.0.9から0.0.10へ一度上げる。block/構築器State/Integerのcase _/Logと許可/警告/生成記録/旧道具の移行を英日へ反映する。手書きSkillと訳を揃え、gen_skillで生成参照を作り直す。六入口と二manifestの件数/版/独立入力を照合する。
- 完了の条件: 全統合の読者と生成物・版・移行が揃い、取りまとめへ渡せる。design 12.8と本書の対象外の行の割り当てを、07-04の対応表の全行と照合し、担当13行の実装・対象外の理由・検査との対応、未記載や未実装の記述がないことを確認する。change・全形式化比較・short/targets・releaseの手動照合は取りまとめの責任であり、V1担当が先取りしない。 検査は後述のwork V1行と当該補完行を使う。
- 依存: M1、全レビュー修正の反映。
- 見込み: 2〜4時間（作業末の検査を含む予定枠。実測ではない）。

## レビュー（Opus、事前点検＋RV1〜RV5）

事前点検preflight・RV1・RV2は実施済みであり、別々のレビューとして数える。P1はpreflightの全15指摘、P2はRV1の全9指摘、Z1はRV2の中1・軽4件を反映し、それぞれの対応表をreviews/へ置く。残りはRV3〜RV5の3回である。レビュー修正はP2などの別IDで結果を管理し、実装28作業へ細分化して加えない。指摘で古くなった検査は修正担当が更新する。レビューで新しい公開判断が必要ならR番号へ記し、停止条件に当たれば設計者に戻す。

| 回 | 時期・範囲 | 観点・次へ進む条件 | 見込み・記録 |
|---|---|---|---|
| preflight | C2後、実施済み。design/plan/decisions/依頼文/目標JSONと現行コード・Leanを照合 | 重1・中4・軽10。修正はP1へ、段1へ進む条件の充足はRV1で改めて確認する | reviews/preflight.md。実測時間の記録なし。将来の5回には含めない |
| RV1 | P1後、L1前に実施済み。preflight-response、design 12節、本書の定義/型/命令/区切り、目標JSONを照合 | 重1・中2・軽6。重1は設計者の案Aで処理系のUserHandleBodyへの専用入力を認め、Leanは変えない。全指摘の対応はP2とR132〜R140へ | reviews/RV1.md・RV1-response.md。実測時間の記録なし。将来の時間に含めない |
| RV2 | L7後、実施済み。全Lean、01-12/07-04、公理一覧、独立入力、RV1-response | 定義と写し、主定理の前提/結論と仮定の比較、ordinaryと局所参照の隔離、通常State/releaseの維持、11件/program、191・block・192、内外と未接続箇所を確認する。R133の値の強化/弱化・冪等性/単調性、隠す位置、Assumptionsの意味と全モデルの証拠も比較する。sorryなしの既定ビルドと指摘反映をRust開始の条件にする | reviews/RV2.md・RV2-response.md。重0・中1・軽4。Z1で中1・軽3の写しと軽2の位置付けを直し、軽1・軽2・軽4の実装検査を担当へ割り当てる。T1前にZ1を取り込む |
| RV3 | B3後。T/B全体と結果 | 処理系の中ほどのレビュー。共有DAGとT3のガード/束縛/予算、解析の根、三バッファ/障壁/停止/継続、blockの全走査とreturn、診断の真偽、Leanとの局所照合を確認する | 1〜2時間、reviews/RV3.md |
| RV4 | G7後。H/GとT/Bの共有契約の変更 | 変換区間と世代、外部Storeの隔離、Logの既定/ハンドラ/位置/許可、三不透明型、生成の有限性/制約/記録移行、保管hash、Writerの同期/後片付けを確認する | 1〜2時間、reviews/RV4.md |
| RV5 | V1と取りまとめの全証拠が揃った候補 | 15件+B17、英日/同梱物/移行、change/六入口全比較/short/releaseと候補の一致、未達・比較不能・保留の扱いを確認する。targetsの本測定を行わない設計者判断（R222）、TODO-248の費用の測定をdocs/todoのTODO-275へ、TODO-032の数値目標をdocs/todoのTODO-262へ引き継ぐ記録も確認する。受け入れは設計者 | 1〜2時間、reviews/RV5.md |

## 検査の割り当て

### 基準・入口・時間

具体的なコマンドの正は本節一箇所とし、依頼文と作業節は当該行を参照する。`B_WORK`/`B_STAGE2`/`AFTER`/`D`は取りまとめが実値へ固定してから実行するシェル変数であり、B_WORKは上の基準表に従う。Dは本書のある相対パス、AFTERは実装とV1を取り込んだ候補の完全IDである。未コミットのコードをcompareのafterへ指定しない。

各check.shの実行前に同じ指定の末尾へ`--dry-run`を付けて選択と理由を確認する。Leanのformal_buildは`formal/`の既定`lake build`とsorryの拒否であり、別に同じビルドを重ねない。LeanだけのworkへRustの全libを加えない。下の仕様例は01-12の写しの例のための検査である。Rustの名指しworkは、既定のlib全件・関連統合・clippy・fmtと生成物/集計を含む。名指しにする理由は、ヒープ全比較を必要な区切りへ固定し、内部交換/保管資料など自動分類だけで読者を選べない変更を扱うためである。

検査時間は初回ビルドを除く予定枠である。ヒープ/全件/長い対象の前に取りまとめが現在の見込みを伝える。B2等の重い機能は目安の30〜60分を超えるが、意味を持つ一回の切り替えを保つため作業数を増やさない。上の見込みには作業末の待ちを含める。

### 各作業のwork

結果はDの`<小文字ID>/results.md`へ保存する。L3a/L3b/L4a/L4bはそれぞれl3a/l3b/l4a/l4bへ記録する。続きは例えば`l3ac2/results.md`とし、l3aから参照する。担当は各実装担当Codexである。

| 作業 | 契約・入力の読者 | コマンド・構成・対象 | 検査の予定枠 |
|---|---|---|---|
| L1 | 変更した規則・全import・主定理/写し。formal/でlake build、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L2 | 変更した規則・全import・主定理/写し。formal/でlake build、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L3a | 新構文は型の付かない状態。全import・旧主定理・モデル/写し、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L3b | 専用規則・全import・全主定理・モデル/写し、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L4a | State/refs付き表層と専用脱糖・全定理/写し、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L4b | State/refs除去後の全表層読者と全定理/写し、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L5 | 変更した規則・全import・主定理/写し。formal/でlake build、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L6 | 変更した規則・全import・主定理/写し。formal/でlake build、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| L7 | 変更した規則・全import・主定理/写し。formal/でlake build、sorry拒否 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | 5〜30分 |
| T1 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test coverage_export --test golden --test verify --test spec_examples`。同じ作業末の枠で `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（今回の依頼に合わせたlint_defaultの置換、R159） | 10〜30分 |
| T2 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test desugar_export --test named_arguments --test verify --test golden`。同じ作業末の枠で `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（今回の依頼に合わせたlint_defaultの置換、R161） | 10〜30分 |
| T3 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test golden --test verify --test random_programs --test vm_handlers --test cli_process --test test_command --test desugar_export`。同じ作業末の枠で `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R162・R163） | 10〜30分 |
| T4 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack,doc_default,heap_local,stress_local --test verify --test golden --test vm_handlers --test vm_lazy --test vm_reference_cells --test call_allocations`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R166） | 暫定30〜60分（ビルド別）。短いquickの実測はt4/resultsへ記し、全対象の確定値とはしない |
| T5 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test declarations --test checked_args --test test_command`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R168） | 10〜30分 |
| B1 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,doc_default,heap_local,stress_local,lint_heap,heap_checks --test runtime_builtins` | 15〜45分（Miri初回別） |
| B2 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack,doc_default,spec_examples,reference_examples,skill_docs --test '*'` | 15〜45分の仮枠。局所補完を含み、試走後に更新 |
| B3 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack,doc_default,spec_examples,reference_examples,skill_docs --test '*'` | 15〜45分の仮枠。局所補完を含み、試走後に更新 |
| H1 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,doc_default,heap_local,stress_local --test golden --test random_programs --test runtime_builtins --test l13_external_commands`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R185） | 10〜30分 |
| H2 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,doc_default,heap_local,stress_local --test test_command --test external_signals --test l13_external_commands --test declarations`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R186） | 10〜30分 |
| G1 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'` | 10〜30分 |
| G2 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,doc_default,spec_examples,reference_examples,skill_docs --test '*'`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R191） | 作業末の計測分約12.0分（初回の失敗・修正後の継続と局所補完を含む）。局所修正確認の一部は未計時。g2/results.md参照 |
| G3 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test runtime_builtins --test declarations --test stdlib_doc_examples --test property_library --test desugar_export`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R193） | 10〜30分 |
| G4 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations --test property_library --test stdlib_doc_examples` | 10〜30分 |
| G5 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations --test property_library --test test_command --test stdlib_doc_examples` | 10〜30分 |
| G6 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests,policy_selftest --test skill_docs`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R196） | 10〜30分 |
| G7 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test interrupt_process --test external_signals --test io_modes`。同じ作業末に `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` を一度実行する（R197） | 10〜30分 |
| Z4 | RV4-checkの軽5件。文法・誤りの式の回復・欄名・Logの修正案・包みの鍵 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test spec_examples --test reference_examples --test random_programs --test desugar_export`。同じ作業末に `cargo clippy --all-targets` を一度補う（R206）。B_WORKはaed9c6fe35e28b54f05da5543f844fc58fa1af11 | 5〜15分。z4/results.md |
| M1 | 共通compareのPythonと一時probeのコンパイル。補完の自己検査も必須 | `scripts/check.sh --level work --base "$B_WORK" --only python_syntax,migrate_selftests` | 2〜10分 |
| Z5 | 最終の実出力のbatch2版照合。現在の13/5だけを受理し、旧版と版ずれを拒否する | `python3 -I crates/benitoite/tests/desugar_export/check_named.py target/desugar-diff/run-62334 target/coverage-diff/run-62334`、`python3 -B formal/tests/test_batch2_exchange.py`、formal/で`lake build`、`scripts/check.sh --level work --base "$B_WORK" --only python_syntax,policy_selftest`を各一度。workの前に同じ指定のdry-runを行う。B_WORKは9b4012b8b39c1bdc038c7e26446805f63eb3ea4c（R211） | 1〜5分の見込み。z5/results.md |
| Z6 | check-formal.shのbatch4独立入力と4つのprofileの呼び出し・出力先・失敗時の停止 | `python3 -B scripts/check/test_policy.py`、`scripts/check.sh --level work --base "$B_WORK" --only python_syntax,policy_selftest`を作業末に各一度。workの前に同じ指定のdry-runを行う。B_WORKは605b81db783d816ab66f8254d40a7685bf9d5964（R212） | 1分程度の見込み。z6/results.md |
| Z7 | 決定木の出力の再帰枠。16 MiBで上限入力を通す。最大容量は25形の最小容量と残る1形がその容量以内で成功することから確かめる（R216） | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules --test golden --test random_programs`のdry-run後に同指定を一度実行し、`cargo clippy --all-targets`を一度補う。`cargo test -p benitoite --lib stages_fit_the_measured_stack_ -- --include-ignored`、`cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --lib stages_fit_the_measured_stack_ -- --include-ignored`を各一度実行する。workが時間超過で止まった場合は失敗した1件と未実行の単位だけを補う（R215）。通常5件とignored5件の全10件を対象にする（R214）。B_WORKは76ed2d5ede197d112284b753fcf67d2ea21e40bb | workは5〜15分、上限入力は両構成合計5〜15分の見込み。z7/results.md |
| Z8 | 共通compareの独立IRの宣言型とprobe失敗の識別。比較afterとB_WORKは270a717c670d9640d4c08f10bc400afa6e3fcef2に固定（R217・R218） | `python3 -B tools/bench/compare/test_compare.py`、`python3 -B tools/bench/compare/test_scenarios.py`、`rustfmt --edition 2024 --check tools/bench/compare/timing_probe.rs`。`scripts/check.sh --level work --base "$B_WORK" --only python_syntax,migrate_selftests`のdry-run後、同指定を一度実行する。Rustの補完は`cargo test -p benitoite --lib`、`cargo test -p benitoite --test verify`、`cargo clippy --all-targets`、`cargo fmt --check`を各一度 | 自己検査・work・Rustの補完は5〜15分の見込み。下記の試走と合わせz8/results.mdへ記録 |
| Z9 | RV5の中3件・軽5件の文書・記録・同梱Skillと英日の訳。B_WORKは98c3572acbaee1dee561547ff812399b3965cb18（R224） | `scripts/check.sh --level work --base "$B_WORK" --only fmt,reference_examples,skill_docs,skill_generated,spec_examples` のdry-run後、同指定を一度実行する。formalのMarkdownを変えるため `(cd formal && lake build)` も一度実行する。Rust・Lean・テストの中身は変えない | 5〜15分の見込み。z9/results.md、reviews/RV5-response.md |
| V1 | 機能の公開入口と上の対象ファイル。共有型/標準宣言の行の*は全統合の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'` | 10〜30分 |

`'*'`はCargoへ単一の引数として渡す全統合ターゲットの指定である。B2/B3/G1/G2/V1は既定構成のtests_relatedで共有入力の全読者を意図して選ぶ。B2/B3/G2のheap-verify・gc-stressは下の補完で対象を分け、全統合ターゲットを特殊構成で繰り返さない。spec_examples等が同じtests_relatedへ含まれる場合はcheck.shが包含として省く。その他の行で現行設計01-spec/08-04のtext例まで変更した場合は、その行へ`spec_examples`を追加してから実行する。構文の章を変えた行には`skill_docs`も加える。処理系を変更しないM1はRustのlib全件を要求しない。

### workに含める補完・局所交換・安全点

以下は同じ作業末の検査枠の続きであり、別のworkを再度起動する指示ではない。途中の実装では関係するテストだけを使う。

| 作業 | 補完する具体的な検査と理由 | 記録・受け渡し |
|---|---|---|
| L1前・L1〜L7（分割後9作業） | formal/READMEの`#print axioms`の主定理/公開11件/programの一覧を同じ入力で実行し、開始版と比較する。追加した局所定理/小証明も一覧に足す。`lake env lean /private/tmp/batch4-axioms.lean`（formal/を作業ディレクトリにし、正確なimportと名前を記録）。基準側はL1開始前に既存一覧を保存する。L3a/L3bはR133のAssumptionsの全モデルの証拠も照合する | 各小文字ID/results。公理・仮定と定義の比較をRV2へ |
| L7 | `python3 -B formal/tests/test_batch4_exchange.py`（L7が追加する新しい独立入力の自己検査）、既存の`test_batch3_exchange.py`・`test_named_exchange.py`・`test_try_exchange.py`・`test_extensible_exchange.py`・`test_batch2_exchange.py`・`test_width_exchange.py`を同じディレクトリから順に実行する。新入口は先行作業で既に存在すると扱わない | l7/results。各版の受理/拒否と六入口の独立入力を保存 |
| T1・T2・B2・B3・G2・G3 | それぞれのcoverage_export/desugar_exportの通常検査と、変更した機能の新しい独立入力を六入口の関係する読者へ渡して局所比較する。生成/読み込みコマンド・件数をD/resultsの局所接続表へ残す。旧corpusが未更新の間に全比較の成功を宣言しない | 各結果→最後の全比較。T1=Coverage、T2=穴、B2=専用局所コア、B3=block、G2=Log標準宣言、G3=検査済み値の通常コード |
| T4・B1・B2・B3・H1・H2・G2 | work行のdoc_defaultと、heap_local/stress_localのある行または下の名指し補完が、根・保持先・変換区間の統合境界を確認する。libの固有の不変条件は次の二コマンドで補う。`cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify <filter>`、同じ指定のfeaturesを`gc-mark-sweep,heap-verify,gc-stress`へ替えたもの。filterはT4=`bytecode::`、B1=`runtime::heap::`、B2/B3=`vm::`、H1=`refinterp::`、H2=`external::`、G2=`vm::`。全libの特殊構成をここで重ねない | 当該結果。次の作業へ渡す前に成功。Kのstress用サイズを使う |
| B2・B3・G2 | workのtests_relatedは全統合の既定構成だけとし、特殊構成は直接のCargoで対象を分ける。B2: `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_handlers --test vm_lazy --test vm_reference_cells --test verify`。B3: `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test desugar_export --test named_arguments --test vm_handlers --test verify`。G2: `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test io_modes --test vm_handlers --test runtime_builtins`。各コマンドのfeaturesを`gc-mark-sweep,heap-verify,gc-stress`へ替えたものも一度実行する。既定構成のlib/統合/lint/fmtは重ねない | 各結果。Kのstress用サイズを事前に確認し、局所libと合わせて次の作業へ渡す前に成功させる |
| B2・B3（RV1の観測） | B2の外側の構築器とhandle/handleFail本体のSlot・保存/破棄、B3のガード/説明とT2/T3の経路の例はvm_handlersのVM/参照評価とverifyの拒否境界へ集める。上のworkの既定構成と名指し特殊構成で覆い、同じ検査を別コマンドで重ねない。T2/T3の到達経路と入力の対応を結果へ記す | b2/b2c2・b3/results。B3完了前に両経路の順序/回数を確認 |
| T4 | work行はgoldenを含む名指し対象をheap-verify/gc-stressでも実行する。T4開始時にKのサイズを点検し、関係する短い入力で試走（quick）してから所要時間の見込みを更新する。例: `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test golden <関係する入力のfilter>`。実在するfilter・件数・外側時間を結果に残す。全対象の待ちをこの短い試走から確定した値とはしない。実装途中の試走は作業末の全名指し対象の検査を代用しない | t4/results。T4でc12-lazy-deferred一件を試走し、外側10.920秒・テスト本体0.26秒だった。workのgolden全件のstressは546.54秒、workは外側1131.204秒、補完とlintを含む完了検査は1294.350秒だった。試走を全件の確定値にせず、実行前にはビルド別30〜60分の仮枠を提示した |
| B1 | workのheap_checksが`scripts/check-heap.sh`全体（Miri二構成と到達可能性比較）を実行する。Hostの根/障壁/容量の新しい不変条件の初回の根拠とする | b1/results。後のVM/根の変更で同じ状態とみなさない |
| B2・H1 | 根/継続と変換表が変わるため作業末に`scripts/check-heap.sh`全体も実行する。B3/H2/G2は既存の根の仕組みへの接続であり上の局所検査を使う。GC本体/障壁まで変更するなら当該行にも全体を加える | 各結果、10分を予定し初回Miriは別途知らせる。最終changeでは最後の関係状態の成功を引用する |
| G4・G5 | `cargo build -p benitoite --example derive_inventory --bin benitoite`の後、`python3 -B tools/derive/test_derive.py`。自己検査の実生成コードを本番CLIで検査・実行する。旧記録/新preview/review/apply/checkは同じ自己検査へまとめる | 各結果。helperとCLIは直前のソースからビルドする |
| G6 | work内のpolicy_selftest/migrate_selftestsに加え、`cargo check -p benitoite --examples`。移動前後の全hashと現役参照を照合し、保管Pythonを現役の検査に混ぜない。既存archiveは変更しない | g6/resultsと保管README。単なるテスト削除の成功扱いにしない |
| M1 | `python3 -B tools/bench/compare/test_scenarios.py`、`python3 -B tools/bench/compare/test_compare.py`。compareの共通build経由でtiming_probeを両状態向けにコンパイルする自己検査もここに含める。実測はせず、欠測・単位・全caseと目標参照・不正期待値・IQR・非正差の自己検査を行う | m1/results。afterの測定IDはV1後に固定し直す |
| Z8 | `B_BEFORE=c31e64b03d2810343e1779926bea4ebc958b6164`、`B_AFTER=270a717c670d9640d4c08f10bc400afa6e3fcef2`を固定する。`python3 tools/bench/compare/run.py --tier short --quick --state before="$B_BEFORE" --state after="$B_AFTER" --out target/bench/z8/short`、`python3 tools/bench/compare/run.py --tier targets --targets "$D/bench-targets.json" --quick --alloc --state before="$B_BEFORE" --state after="$B_AFTER" --out target/bench/z8/targets`を順に完走させる。それぞれのコマンドから`--quick --out <出力先>`を外し、`--estimate-from <同じ試走の出力先>`を加えて本測定を見積もる。本測定は行わずquickで合否を判断しない | z8/results。ビルドの再利用時は各試走2〜10分の仮枠、allocの初回ビルドは別途。実時間と節別の見込みを取りまとめへ渡す |
| V1 | `cargo build -p benitoite --examples --bin benitoite`と、`cargo clippy --all-targets`（R209。workのlint_defaultを置換）、formal内の案内の更新に伴う`(cd formal && lake build)`、G5/M1のPython自己検査、英日/Skill/ローカルリンク/配布一覧・二manifestの件数照合。版の例が手書きSkillへ増えた場合はskill_examples/stdlib_doc_examplesも全統合の読者に含まれていることを確認する | v1/results、全検査と測定を取りまとめへ |

命令/保持先の変更はB2のworkでrelease_stackも確認する。最終候補の最適化した構成は最後のreleaseで改めて対応を確認する。全体の回帰や形式化比較を、これらの局所検査の成功で代用しない。

### stageの配置と省略

| 区切り | 指定・理由 | 担当・時間・保存先 |
|---|---|---|
| Lean段末 | stageは置かない。L7の既定ビルド/独立入力とRV2を条件にする。Rust未接続なので本番全比較の成功ではない | 取りまとめ。l7/results・RV2をresults.mdへ対応付ける |
| stage2（T5後） | `scripts/check.sh --level stage --base "$B_STAGE2" --only tests_related --test coverage_export --test desugar_export --test named_arguments --test golden --test verify --test vm_handlers`。Coverage/穴/環境/DAG/捕捉と診断の複数作業の接続を確認する | 取りまとめ、5〜20分、D/results.md |
| B/H/G段末 | 独立のstageは置かない。B3/G2は全読者のwork、H1/H2は区間と隔離の局所特殊構成まで実行する。RV3/RV4で同じ接続の結果と後続差分を確認して引き渡す。結果が古ければ該当分を修正担当が再検査する | 各work結果・RV3/RV4、取りまとめが省略理由と関係状態をD/results.mdへ記す |
| M1後（最後のV1直前） | 段末検査を省く。M1の自己検査を引き渡し、直後のV1とchange/全比較/測定で最終の入力を確認する | m1/results→D/results.md。最後の段の直前に重い検査を重ねない |

### 改造末の全件・形式化・測定・release

V1後に取りまとめが順に実行する。実装担当の最後のworkへ含めない。候補と証拠が一致してからRV5へ渡す。修正が入った場合は古くなった結果だけを更新する。

| 水準・検査 | 基準と対象 | コマンド・構成と手動照合 | 担当・見込み・保存先 |
|---|---|---|---|
| change | B_CHANGE、V1後の全変更 | `scripts/check.sh --level change --base c31e64b03d2810343e1779926bea4ebc958b6164`。下の全件構成を含む。heap_checksだけ成功を引用する場合はdry-runの選択を保存し、残る単位を具体的な`--only`へ列挙して計画と記録を更新する | 取りまとめ、1〜4時間（stressサイズ調整後の仮枠）、D/results.md |
| 全形式化比較 | 同じ最終の関係状態。版全体の最後の接続完了の区切りを兼ねる | `scripts/check-formal.sh`全体を一度。desugarDiff/builtinCheck/coverageDiff/coverageProgramDiff/surfaceCheck/surfaceCheckAll、独立入力、本番parser/書き出し、corpus13/sidecar5、二manifestの件数を照合する。T/B/Gの全読者の件数をV1が揃え、取りまとめが全体で再確認する | 取りまとめ、30〜90分（初回Lean構築別）、D/results.md。正式接続と最終状態を同じ実行で閉じる |
| 性能の試走と見込み | before=B_CHANGE、after=AFTER。入力hash・R・casesと目標を固定 | `python3 tools/bench/compare/run.py --tier short --quick --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after="$AFTER"`。続いて`--tier targets --targets "$D/bench-targets.json" --quick --alloc`で同じ二状態を試走し、同じtargets指定に`--estimate-from <quick記録>`を付けて見込みを得る。quickを合否に使わない | 取りまとめ。ビルド別10〜30分の仮枠。quickはtarget/の記録、採用Rと見込み・hashはD/results.mdへ転記 |
| 性能short | 同じ二状態・共通Case生成器 | `python3 tools/bench/compare/run.py --tier short --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after="$AFTER"`。全族代表・5標本。10%か2msは調査の合図 | 取りまとめ、ビルド別15分以内。設計者の静かな計算機の合図後、tools/bench/results/とD/results.md |
| 性能targets（本測定は行わない） | R222の設計者判断。全採用目標、同じ状態とRを後の測定用に保つ | `python3 tools/bench/compare/run.py --tier targets --targets "$D/bench-targets.json" --alloc --samples 10 --state before=c31e64b03d2810343e1779926bea4ebc958b6164 --state after="$AFTER"`。これは当初の計画コマンドであり、0.0.10では実行しない。時間/alloc/RSSの測定入力と目標を保管する | 本測定は未実施。三種類の構築器の費用（design 15.2、bench-targets 16.5）はdocs/todoのTODO-275、TODO-032の数値目標の判定はdocs/todoのTODO-262へ。性能の直しはTODO-275（親TODO-028）へ。D/results.md |
| release | B_CHANGE、実際の0.0.10候補のID/差分/構成/同梱物 | `scripts/check.sh --level release --base c31e64b03d2810343e1779926bea4ebc958b6164`。最適化構成release_stack成功10件。下記の実CLI/版/同梱/生成/移行/配布を手動照合する | 取りまとめ、30〜90分、D/results.md。判定者は設計者、RV5も参照 |

changeの自動選択を実行前のdry-runで確認する。Dに保管する旧道具のパスはdocs配下なので現役Pythonの分類へ入れない。想定外のファイルで終了3となれば、依頼文の停止の扱いへ従い、成功を装わない。

| 必要な検査 | 実行または引用の割り当て |
|---|---|
| 既定・heapのworkspace all-targets | changeのtest_default_all/test_heap_all。全examples/binを含む |
| doc、全件stress、二構成lint、規約/生成物 | changeのdoc_default・test_stress・lint_default/lint_heap・fmt・source_rules・skill_generated/spec_tally。文書例はall-targetsに含まれる同一対象を重ねない |
| long_only | changeでheap-verifyとheap-verify+gc-stressを各一括実行。成功0件を拒否しformal書き出しを件数へ混ぜない。長い対象もKの小さいstress入力を適用する |
| 局所heap/stress・compile_fail | 上のT4/B/H/G2のworkと補完行。次作業へ渡す前に成功させる |
| check-heap全体 | B1/B2/H1と、後でGC本体/障壁を変えた作業。最後の関係状態の成功をchangeへ引用できれば重ねない。入力・構成・未コミット差分のhashを含む引用条件を満たすこと |
| Lean既定ビルドとレビュー | L1〜L7のformal_build、公理比較、RV1/RV2。最終changeのformal_buildは全比較の代わりではない |
| check-formal全体 | 上のV1後の最終接続で一度。後で関係する標準宣言/交換/構文が変われば古い結果を引用せず該当証拠を更新する |
| 性能の段 | shortは実施済み。targetsの本測定は設計者判断で行わない（R222）。CHANGELOGに性能の増減は書かない（R223）。今後は改造の途中にshortをこまめに測り、リリースの準備の後には測らない。fullは今回の必須ではなく、必要になれば`--confirm-full`と見込み/了承を別に割り当てる。TODO-262の四状態比較へ広げない |
| release_stack | T2/T3/T4/B2/B3の局所の枠・再帰/解析変更と、最後の最適化した候補。最後のreleaseで成功10件を要求する |
| licenses・道具の自己検査 | changeの差分選択へ対応させる。derive/compareの追加自己検査はV1の補完結果と関係状態を照合し、同じなら引用する |

releaseの手動照合は、CLIの`--version`とCargoの版/lock/CHANGELOG、`skill`の同梱版とgen_skillの一致、英日と配布一覧/許諾/移行案内、予約語blockの配布入力の再走査を対象とする。実CLIでdesign 14.1の純粋な構築器+block、14節のInteger全域、Logの既定stderrと捕捉/許可/JSON報告、三検査済み型、生成済み再帰レコード、test通常/doc/外部共有、Writer中断の代表を実行し、出力・診断・終了状態を照合する。移行案内に0.0.9のコードからの前後の例を載せ、旧uses Stateは受理されることも確認する。タグ/push/配布の公開操作は別の明示の指示に従う。

## 性能目標JSONと入力の固定

[bench-targets.json](bench-targets.json)はdesign 15節を式へ写した計画入力である。C2時点では新しいCaseとmetricの一部がまだない。M1で全参照を実装したが、0.0.10では設計者判断で本測定を行わない（R222）。目標JSONは後の測定用に保管し、達成済みとは扱わない。schema_version=1/min_samples=10を使い、既存のmedian/difference/ratio/regression/invariantで表す。

R/2Rは当初64/128としてIDへr64/r128を入れる。識別できない差ならquickだけで倍増し、目標JSONの同じ二点とCase.paramsを取りまとめが本測定前に一括更新してR番号とhashを残す。閾値・対象の計算・開始版は変えない。時間差2ms未満/非正/IQR和以下は判定不能とする共通analysisの追加をM1が担う。確保量と整数計数に2msの規則を適用しない。

- buildersは既存点を維持し、新しいrepeat/single-all/prepared/copy-onlyを追加する。method別の末尾、preparedの有無、同じ内容をCase.paramsにも保持する。String/Bytesの一括対照は準備済みjoin/concatenate、Listの完成済み入力の返却は倍率の合否を付けない。中間snapshotを後の追記の後に照合する。
- patternsのbeforeでtree13/16/24はL0112を期待する状態別Caseとし、速度比へ使わない。afterは全点で先頭/末尾/不一致が正しいことを独立validatorで確かめる。
- bridge-nodes16/32/64は独立した節数/辺数とheap対象数の対応を保存する。深さだけの比を節数二倍の比としない。to/fromを別々に計時し、構造の等値の再走査を含めない。
- 外部の実行用コンパイル回数は通常/補助キーごとに一回である。静的検査のコンパイルを混ぜない。multiple-entry/doc/statefulの正しさの点もcasesへ置く。キー数と回数の一致はvalidatorで両向きに確認し、表の上限のinvariantだけで0回を合格させない。
- 穴のLetは全Let数をbefore/afterで数え、固定式/calleeのLetを残したまま穴数だけ減った差を二方向の比<=1で確認する。計時は同一ソースのR/2Rで行う。

## 規模の見込みと引き継ぎの区切り

見込みは実測ではない。実装・局所検査・作業末の待ちを含む時間と、レビュー/取りまとめの待ちを分ける。C1/C2・preflight・P1・RV1・P2は準備として下の28件に数えない。C1のdesign本文にある「C2で作る」「S4の見込み」という案内は作成時の引き渡しであり、現在の順序と件数は本書を正とする。

| 段 | 数 | 作業別の時間（時間単位） | 小計 |
|---|---:|---|---:|
| 1 Lean | 9 | L1 3〜5、L2 2〜4、L3a 5〜10、L3b 8〜16、L4a 4〜8、L4b 4〜8、L5 3〜6、L6 2〜4、L7 2〜4 | 33〜65時間 |
| 2 検査/診断 | 5 | T1 1〜2、T2 2〜3、T3 3〜5、T4 2〜3、T5 2〜4 | 10〜17時間 |
| 3 構築器/block | 3 | B1 2〜4、B2 7〜12、B3 3〜4 | 12〜20時間 |
| 4 実行の共有 | 2 | H1 2〜3、H2 2〜4 | 4〜7時間 |
| 5 ライブラリ/道具 | 7 | G1 1〜2、G2 2〜3、G3 1〜2、G4 2〜3、G5 2〜4、G6 0.5〜1、G7 1〜3 | 9.5〜18時間 |
| 6 測定器 | 1 | M1 2〜4 | 2〜4時間 |
| 7 版と文書 | 1 | V1 2〜4 | 2〜4時間 |
| 実装計 | 28 | 続きのセッションを新しい作業として数えない | 72.5〜135時間 |
| Opusレビュー | preflight・RV1実施済み＋残り4回 | RV2〜RV5各1〜2時間。済んだレビューの実測時間と今後の指摘修正の規模は未確定 | 残り4〜8時間 |
| 取りまとめ | 作業数に含めない | stage2、全検査/比較、試走/本測定、プロファイル/所見、候補の照合 | 暫定5〜12時間。全targetsはquickで校正 |
| これからの全体 | 28作業+RV2〜RV5 | 済んだ準備とRV1を除き、形式化と測定の未試作部分を含む予定枠 | 暫定81.5〜155時間 |

P2で作業数は26から28へ増える。L3は強化と全モデルの確認、追加した区切りの検査を含め12〜24から計13〜26時間、L4は分割しても計8〜16時間を保つ。B2は専用入力の受け渡しで6〜10から7〜12時間、B3はガード/説明の観測で2〜3から3〜4時間へ改める。実装計は69.5〜130から72.5〜135時間（3〜5時間増）。RV1が済んだため将来のレビュー枠を1〜2時間減らし、全体は79.5〜152から81.5〜155時間（2〜3時間増）となる。T4とB2/B3/G2の検査、全targetsは未校正であり、上表は確約した所要時間ではない。

L3a/L3b/L4a/L4bはそれぞれ全読者と既定ビルドを閉じる別作業であり、task.shも四つのIDを使う。B2は一作業内の追加段階からb2c2へ渡す。その他の作業も機能を閉じるため超過を認めるが、実装に入ってさらに作業数を増やす方法で調整しない。見込みの上限に達して閉じない、または見込みの2倍に達する見通しになったら、現状・原因・残る読者と代案を示し取りまとめから設計者へ戻す。待ち時間だけを理由に期待値や規則を変えない。

## 範囲を絞る区切りと相談する点

範囲を減らさない決定を優先する。下表は自動の縮小手順ではなく、問題が現実になった場合に設計者が選ぶ区切りである。現時点で新しい公開構文の回答待ちはない。

| 区切り | 停止条件 | 提示する代案・影響 |
|---|---|---|
| RV1・L1/L2 | 191の有界化が第二の重い形式化になる/主定理に新仮定が要る | 191だけ外して従来のotherを保つ。設計者の了承後にL1/L2の差分・交換/写し・T1の整数変更/移行案内/目標を一緒に外す。032の意味を保つ最適化と200は続けられる。勝手に外さない |
| L3a/L3b/L4a/L4b | 保存継続や局所置換が閉じない、主定理/公理/Assumptionsの追加が必要、R133の意味の変更で既存モデルが満たせない | 0.0.9のState付きReference展開へ戻る案と未達を提示する。State付きバッファや表示だけのState除去へ自動変更しない |
| Lean各区切り | sorryなしの既定ビルドを保つ区切りを作れない | 作業を細分化して増やさず、全読者を切り替える範囲と見込みを示して相談する |
| L5 | B17が主定理の条件/段の大幅増加に響く | 表層Blockへの接続の不足を示して相談する。blockの効果除去境界化やラムダへの置換を代用しない |
| T1/T3・B1/B2 | 初期予算が標準ソース/受け入れに不足、容量/障壁の契約を守れない | 計数と入力を示し再判断する。上限を事後に引き上げない |
| G4/G5 | 再帰implementの辞書制約が既存解決で閉じない | 対応形の制限と手書き案を示す。新しい型計算/再帰辞書コアを加えない |
| G7の最初の試作 | Writer解放中の同期の二条件が成立しない | 未達を記録し相談する。固定sleepや別リソースの成功へ置換しない |
| 測定・RV5 | 目標未達/判定不能、beforeで指定点を実行できない、候補と証拠不一致 | 生の記録と原因の見立てを示す。目標/入力を測定後に変えず受け入れを相談する |

## 結果とレビュー修正の管理

| 結果ID | 保存先 | 後の変更で古くなるもの | 確認/再実行の担当 |
|---|---|---|---|
| L1〜L7（分割後9作業）・preflight/P1・RV1/P2・RV2 | 各小文字ID/results.md、reviews/preflight.md・preflight-response.md・RV1.md・RV1-response.md・RV2.md | 定義/写し/仮定とモデル、公理一覧、交換の独立入力と全読者 | Lean担当、Opus、取りまとめ |
| T/B・RV3 | 各結果、reviews/RV3.md | Coverage/下位IR/命令・保持先/捕捉・局所交換・ヒープ構成 | 当該修正担当 |
| H/G・RV4 | 各結果、reviews/RV4.md | 変換/外部共有/標準宣言/生成/移行/FIFOの入力と構成 | 当該修正担当 |
| M1/V1・全体 | 各結果、D/results.md、追跡するtools/bench/results/、reviews/RV5.md | 候補の版・完全ID/差分、Case/metric/目標hash・同梱物と全証拠 | 取りまとめ、受け入れは設計者 |

普通の作業の記録は基準のコミット、走らせたコマンド、終了状態、外側の時間、ずれと申し送りとし、失敗の原因と修正も残す。段・全体はD/results.mdへ集約する。引用するときだけ07-03の全欄を揃える。基準/HEADの完全ID、未コミットを含む差分一覧、コマンド/構成/入力/toolchain/件数/終了状態/時間/制限、元記録、後の変更、関係状態の一致理由、判断者/日付を残す。別の状態へ引用する場合は未コミット差分と未追跡入力のSHA-256も残す。一時的なtargetのログだけを引用元にしない。

終了2は指定を修正し、終了1は担当の失敗として直す。分類不能/基準不明の終了3は該当箇所と停止までの選択を示し、依頼文に従って設計者へ選択を求める。選んだ検査の終了0だけで水準全体やreleaseの受け入れ完了にはしない。


## C2の文書確認記録

2026-10-19、基準は`d3657abd5db029a1eb2261e0b5aba6e7123dd629`、ブランチはmod010/designである。変更は本書・decisions・README・新規implementation-request・bench-targetsの5ファイルに限る。これは将来の実装/証明/測定の成功へ引用する記録ではない。

| 確認 | 結果 |
|---|---|
| 文書の照合（Pythonによる一時的な確認） | 終了0。26作業とwork行の一対一、必須欄、禁止ID、既存統合ターゲット/検査名、R番号の重複なし、ローカルリンク106か所、非公開へのリンクなし、166点/55目標と式の参照先、変更5ファイルを確認した |
| 目標JSONの語彙と欠測 | 既存compare.analysis.evaluateで55式を読み込み、測定入力がないと全て判定不能となることを確認した。Case/新metricの実装と測定は未実施である |
| `scripts/check.sh --level work --base d3657abd5db029a1eb2261e0b5aba6e7123dd629 --dry-run` | 終了0。変更5ファイル、文書だけ、選択する実行単位なし |
| 同じ指定からdry-runを外したwork | 終了0、外側0.058秒。作業末に一度実行した。Rust/Leanのビルド/テストは選ばれていない |
| 変更範囲と空白 | `git diff --check`終了0。新規ファイルも別に行末空白を確認した。B_CHANGEからcrates/benitoite・formal・scriptsの差分がないことを確認した |

work後の変更はこの確認記録の追記だけであり、選択する実行単位を変えない。処理系・現行設計書・テスト・formal/・docs/todo/は変更せず、コミットしていない。

## P1の文書確認の割り当て

P1は基準`f4a8bec2fb5a746ca80487a60355f1a34b797bd5`からDの6文書だけを変更する。作業末に`scripts/check.sh --level work --base f4a8bec2fb5a746ca80487a60355f1a34b797bd5 --dry-run`で選択を確認し、同じ指定からdry-runを外したworkを一度実行する。26作業とwork行、時間の合計、R番号、15指摘の対応、リンク、目標JSONと点検本文が不変であること、変更範囲と空白も照合する。記録は[preflight-response](reviews/preflight-response.md#p1の文書確認)へ残す。文書だけの検査であり、Rust/Leanのビルドと性能測定は実施しない。

## P2の文書確認の割り当て

P2は基準`5847491b4e4565a344a9461d1532646192752865`からDの指定5文書と新規reviews/RV1-response.mdだけを変更する。作業末に`scripts/check.sh --level work --base 5847491b4e4565a344a9461d1532646192752865 --dry-run`で選択を確認し、同じ指定からdry-runを外したworkを一度実行する。28作業とwork行の対応・依存・見込みの合計、R132〜R140、全9指摘、ローカルリンク、変更範囲と空白、RV1/preflight本文・目標JSON・studyが不変であることを照合する。記録は[RV1-response](reviews/RV1-response.md#p2の文書確認)へ残す。Rust/Leanのビルド・テストと性能測定は実施しない。

## Z1のレビュー反映の割り当て

RV2の指摘とT1前の反例表示の層の区別を文書だけで反映する。結果は `z1/results.md`、指摘ごとの対応は `reviews/RV2-response.md` に置く。Lean/Rustのソースとテスト、docs/todoは変えない。基準は開始時の `git merge-base HEAD san_benito` で固定した `499444e5e618eda048629b1c85185deafa9f158f` とする。

完了の条件は、中1の仮定の意味と唯一のモデルの範囲、軽3の整形式の前提、軽2の抽象補題の位置付けが写しに揃い、後続の対象外の行と物理表現の検査、BuilderInvalidByteの除外が各作業へ割り当てられていることである。R157とdesign 14.3・T1は診断の具体値と交換のotherを区別する。作業末に次の指定をdry-runで確認してから一度実行する（5〜30分の予定枠。Rustのlib・clippy・fmtや全形式化比較は追加しない）。

```sh
scripts/check.sh --level work --base 499444e5e618eda048629b1c85185deafa9f158f --only formal_build,spec_examples,spec_tally
```

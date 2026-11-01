# L20 群 A1 の実装結果

2026-11-02。L20.01〜.03 の担当による実装と自己点検の記録である。独立レビュー・設計者の受け入れは含まない。

## 基準と結果

- 指定ブランチ: `m014/l20.a1`。B_WORK: **`67135be26f4a1ceab11d25e23effbb4285ddda71`**。
- ブランチの照合・作成・切替・コミットは行っていない。指定された検査入口による読み取りの分類だけを実行した。
- [完全署名](signatures.md)を先に保存してから実装した。S00 の LocTy.Sorted・StoreTy.Sorted・StoreOk の定義を採用どおりに置いた。cont の r は Sorted に含めない。
- 型付けの76構成子、四本の304枝、主な十言明、利用者の書ける形を変えていない。新公理・sorry・既定 import からの除外はない。`formal/lakefile.toml` と `formal/Benitoite.lean` も開始時から不変である。
- Lean 本番9ファイルと設計書2ファイルを変更した。本番宣言は **新規17（定義2・定理15）、既存の変更22（定義1・定理21）**。既存公開署名の変更は `StoreOk.allocate_continuation` の Sorted 三引数だけである。A1 の文書・検査入力・実行証拠は本ディレクトリに置いた。

## 変更したファイルと宣言

本番ファイルは `formal/Benitoite/Release/Refinement/` 以下である。数はソースに明記した宣言であり、Lean が生成する宣言を含めない。新規と既存変更の全名は [new-declarations.json](new-declarations.json) と [modified-declarations.json](modified-declarations.json) に保存した。

| ファイル | 新規宣言 | 既存変更 |
|---|---:|---:|
| `HandlerOperation.lean` | 0 | 1 |
| `ReferencePreservation.lean` | 0 | 1 |
| `StoreTransport.lean` | 3 | 0 |
| `HandlerStore.lean` | 0 | 2 |
| `StateTyping.lean` | 14 | 6 |
| `LazyPreservation.lean` | 0 | 3 |
| `HandlerPreservation.lean` | 0 | 5 |
| `LazyStore.lean` | 0 | 2 |
| `ReferenceStore.lean` | 0 | 2 |
| 合計 | 17 | 22 |

本番 Lean の行数は計97行増である。設計書の変更は `docs/design/01-spec/01-12-core-calculus.md` の「篩を含む状態の型付け」と、`docs/design/07-quality/07-04-formal-semantics.md` の「篩を含む形式化の範囲」「01-12 との対応」である。前者に新しい不変条件と r の除外を写し、後者に現在の局所定理と移送の範囲を記した。Rust・計画・詳細・レビューの記録は変えていない。

`DependentBeta.lean` と `CapturedFacts.lean` は、既存 hs の再使用で新しい欄も保持するため編集を要しなかった。関係する四状態・二包装を読み、再ビルドと公理依存で追随を確認した。`CaptureOk.reference_write_snapshot` も既存の包装のまま再ビルドを通った。

## S00 の表の全行の自己照合

### 六つの場所生成規則

この表は、A1 のストア API への供給と、後続が所有する一般の遷移証明を区別する。後続の全状態の保存を A1 の完了とは数えない。

| S00 の行 | A1 での照合と証拠 | 後続が所有する範囲 |
|---|---|---|
| E_RefNew | `allocate_reference` は既存 ht.sorted を使う。`StateTyE.reference_new` の Annotation と引数は不変で、領域読み取りだけを修正。境界 `reference_allocate_write` と既定ビルドで確認 | .113/S05 の任意の実行の選択への接続 |
| E_Lazy | `allocate_lazy` は既存 ht.sorted を使う。`StateTyE.lazy_transition` の元の閉じた Annotation を使う経路を維持。境界 `lazy_allocate_done` と既定ビルドで確認 | .113 の一般の状態への接続 |
| E_BuilderNew | String/Bytes の Sorted は True、List a は a.Sorted []。新しい定義と `hide_builder_boundary` を確認。A1 に既存の builder の直接構成はない | .110/.111 の元の kind.contents の Annotation を閉じる全証明 |
| E_Op | 唯一の既存呼出し `StateTyE.operation_one` は、割当て前の hra.sorted と han.sorted.1/.2 を追加引数へ渡す。割当て後の Ψ を証拠の供給に使っていない。境界 `continuation_allocate_use` も handler で終わる継続を割当て・更新する | .101/.102 の多相・任意捕捉への一般化 |
| E_OpFail | 共通 `allocate_continuation` は b/t/e の三条件だけを要求する。r は要求しない。A1 に既存の別呼出しはない | .104 が元の raise/K_Handle_Fail/RowAnnotations から供給する |
| E_OpPrim | 同じ共通 API を用意した。A1 に既存の別呼出しはない | .103 が元の SignatureInstance/handler の Annotation から供給する |

### 現行の構成・利用箇所

| S00 の行 | 自己照合の結果 |
|---|---|
| ReferenceStore: write_reference/allocate_reference（直接2） | write は h.sorted を再使用、allocate は ht.sorted から新項を構成する。追加引数0。finite/domain/cell を名前付き補題に統一。snapshot 包装1件は変更なしで通る |
| LazyStore: write_done/allocate_lazy（直接2） | 同じ保持と新項の供給。追加引数0。finite/domain/cell を名前付き補題に統一 |
| HandlerStore: use_continuation/allocate_continuation（直接2） | used への書換えも h.sorted を保持。allocate へ a/t/ec の Sorted 三引数を追加。r は追加しない |
| StateTyping: StoreOk.empty（直接1） | StoreTy.Sorted.empty を追加して空ストアを構成。公開 StoreOk.sorted を追加。wf/declared の射影位置と reference_read/adequate/resume_raw_return の読者を追随。raw 射影は六つの名前付き accessor の定義本体だけに集約 |
| DependentBeta: StateTyE.dependent_beta_one（状態2・包装1） | 前後で同じ hs を再使用しているため無修正。StateTy の包装も同じ証拠を使う。既定ビルドで確認 |
| CapturedFacts: StateTyE.captured_beta_one（状態2・包装1） | 同上。環境の Φ や捕捉の条件を強めていない |
| HandlerPreservation（raw 5） | resume_const/drop_rel_const/esc_drop_rel_const/err_drop_rel/exit_drop_rel の全5箇所を hs.cell に変更 |
| HandlerOperation（raw 1・呼出し1） | 領域を hs.domain に変更し、割当てへ既存注釈の三つの Sorted を供給 |
| 合計 | **直接7、状態4、包装3、追加読者の raw 6、割当て呼出し1** を全て照合した |

全検索では、表のほかに `ReferencePreservation` の raw 領域1箇所、`LazyPreservation` の raw セル2箇所・領域1箇所を見つけた。この追加4箇所も同じ domain/cell へ追随した。残る数字の射影は、StoreOk accessor 自身、他の判断、または状態の閉性等の別の証拠であり、StoreOk の raw 読者とは混同していない。

## 公開定理と境界

`StoreOk.cont_result_annotation` は任意の C/Γ で結果 t の Annotation を返す。`StoreOk.cont_annotation` は閉じた `dependentFn (done t e)` の Annotation を返す。両者はセルが `.used` でも場所の型の不変条件から成り立つ。`StoreOk.no_unsorted_cont_result` は、不適格な sort の t を持つストアを否定する公開定理である。

`Ty.Sorted.closed_context` は空の Ctx.TypeMap を使い、WF を前提にしない。WF と全 Annotation の文脈変更も既存の移動・Declared.closed_context を合成した公開補題として同じ場所へ置いた。`StoreTy.Sorted.hide`・`StoreTy.Declared.hide` を既存の WF.hide と併用できる。

[boundary.lean](boundary.lean) には次の独立した境界を置いた。

- レビュー重1の同じ badT・使用済みセルを使う負例。旧 StoreOk の Sorted 以外の全欄と、C_ResumeL による同じコードの型付けを同時に閉じ、拒否が新しい Sorted によることを示した。
- Sorted でない r を持つ使用済みストアの正例と、任意 C/Γ での結果および閉じた潜在効果の注釈。
- 新鮮な ref/lazy の割当てと更新、handler で終わる cont の割当てから used への更新までの正例。
- WF でない型変数の Sorted の文脈変更と、閉じた篩の任意 Γ への文脈変更。前者が Sorted の移送に不要な WF を足す退行を捕まえる。
- builder のセルを持つ元の StoreOk から、hide 後の WF/Sorted/Declared の三条件を得る正例と、同じ μ のまま隠した Ψ の StoreOk は成立しない負例。

`.ref badT` のセルは構成しておらず、反例と記録していない。RV-L20-plan の r1 軽1を踏まえ、ストアの型の大きさによる帰納の負担と `.used` の確定した反例を区別した。r1 軽2は hide の三条件の境界で確認した。境界を作る前の test-audit の関門は signatures.md に記した。既存テストの削除はない。

## 検査と実行記録

全て既存の固定 Lean と既定設定で実行した。単独の Lean は `-M 12288`、lake は変更していない `moreLeanArgs = ["-M", "12288"]` を使う。並列数の上書きや clean は行っていない。RSS は **未取得（計画上の非採取）**。

| 検査 | 終了と件数 | 外側の時間・証拠 |
|---|---|---|
| K: `lake build Benitoite.Release.Refinement.StateTyping` | 0、153 jobs。定義と形成補題を局所確認 | 正確な総時間は未採取。ツールの分割出力で確認した初回の局所実行であり、最終 work の代わりにはしていない |
| K: HandlerOperation/LazyPreservation/CapturedFacts の対象を指定した `lake build` | 0、187 jobs | 29.669秒。[local-build.json](local-build.json)・[local-build.log](local-build.log) |
| K: `lake env lean -M 12288 …/l20/a1/boundary.lean` | 0、正例・負例の全言明が通る。最終実行の警告0 | 0.352秒。[boundary-final.json](boundary-final.json)・[boundary-final.log](boundary-final.log) |
| W-L dry-run: `scripts/check.sh --level work --base 67135be26f4a1ceab11d25e23effbb4285ddda71 --dry-run` | 0。spec_tally/spec_examples/formal_build を選択 | [work-dry-run.json](work-dry-run.json)・[work-dry-run.log](work-dry-run.log) |
| W-L: 同じ基準の `scripts/check.sh --level work --base 67135be26f4a1ceab11d25e23effbb4285ddda71` をA1一式末に一度 | 0。対応集計の自己検査成功、完了条件の未記入0、仕様例7成功、既定 Lean 全体成功。Rust の全 lib は選択されない | 14.867秒。[work.json](work.json)・[work.log](work.log) |
| 上の W-L 内の既定 `lake build` | 0、**774 jobs**（今回再構築31、残りは既存成果物）。既定の8対象を保持。sorry の警告なし | **6.929秒**。[default-build.json](default-build.json)・[default-build.log](default-build.log)。増分ビルドであり clean の所要時間ではない |
| A1 の公理依存: `lake env lean -M 12288 …/l20/a1/axioms.lean` | 0、11モジュール＋明示18件、676印字・676固有宣言 | 1.604秒。[axioms.lean](axioms.lean)・[axioms-run.json](axioms-run.json)・[axioms.log](axioms.log)・[集計](axioms-summary.json) |
| 主な十言明と既存署名の照合 | 十言明を含む4ファイルが開始時SHA-256と一致。既存200宣言の署名字句の差は allocate_continuation の三引数だけ | [ten-statements.json](ten-statements.json)・[signature-comparison.json](signature-comparison.json)・[declarations-before.json](declarations-before.json) |

公理監査は11モジュールの全宣言を対象にし、private と生成宣言を除いていない。旧五主定理と三モデル、HasTypeVQ/CQ の subst・subst_under_none・shift_values・shift_types・narrow の十定理も明示した。依存の和集合は **propext・Quot.sound・Classical.choice のみ**。sorryAx・独自公理・未承認依存は0である。段末 .148 の全体系の A-L と独立レビューを、この A1 の監査だけで済ませたとはしない。

最初の境界実行は、write_reference の型の推論と閉じた述語の References の展開不足で終了1だった（boundary-initial）。追加した cont の正例は、開いた暗黙引数、closeEff が定義上の rfl でないこと、use_continuation の型推論を順に直した（boundary-second/third/fourth）。本番の定義や署名は変えず、型引数の明示と既存の補題の適用で閉じた。各失敗の json/log と最終の終了0を残した。一度、補助実行器の作業ディレクトリを誤って指定して記録の保存に失敗したため、formal から再実行した。公理出力と署名の集計では、名前の末尾のアポストロフィを扱う読み取りを修正し、全件数の一致を確認した。

spec_tally が列挙する仕様節の未参照は、実行器の既存の表示である。対応表の未記入や検査失敗を表すものとは区別する。既存の Lean モジュールには未使用 simp 等の警告が再表示されるが、新しい本番宣言と最終の境界入力に新しい警告はない。

## 単位の完了条件と申し送り

| 単位 | 判定・証拠 | 残り |
|---|---|---|
| L20.01 | 担当作業完了。S00 の定義、empty/sorted accessor/context、used の拒否と両注釈、二つの hide が本番で閉じた。上の K/W-L・境界・公理依存 | 群の独立レビューと受け入れ |
| L20.02 | 担当作業完了。直接6構成の保持・供給と named accessor、追加する署名は continuation の三引数だけ。ref/lazy/cont の具体的な割当て・更新を確認 | 同上 |
| L20.03 | 担当作業完了。四状態・三包装、表の raw 6・呼出し1、追加で見つけた raw 4 の全読者を追随して既定 build 成功。十言明は字面不変 | 同上 |

A1 は G04 のうち場所の型の形成の土台を閉じた。S01 の全53規則の開いた結果形成、捕捉の全正則性、後続群の全型置換・全保存・旧導出の埋め込み・全比較・Rust の接続は、この作業の完了範囲ではない。後続の担当と時期は detail.md の既存の割り当てを維持する。

計画との差は、S00 表に明記されていなかった ReferencePreservation/LazyPreservation の追加4読者の追随である。これは「全 StoreOk 使用先の列挙・全 raw 射影の照合」に含めて実施した。S00 の定義、型付け規則、四移送、宣言済みの署名からの逸脱はない。三単位はS00一式でビルドを閉じる同じ群として扱い、最後の work は一回にまとめた。上限到達・未承認の仮定変更による停止はない。

署名の保存からこの記録までの計時区間は 2026-11-02T02:02:24.372631+09:00 から 2026-11-02T02:11:56.227948+09:00（571.9秒）である。冒頭の依頼文等の読み取りはこの区間の外で、全作業の外側の時間と能動時間は確定していない。記録したコマンドの時間は各 JSON の外側の値であり、能動時間と待ちの完全な分離ではない。

独立レビューと取り込みは取りまとめ、受け入れは設計者が担当する。実装担当の自己照合を独立レビュー済みとは記録しない。

## r1: RV-L20.a1 の全3所見の処置

2026-11-02。指定ブランチと B_WORK は初回と同じ `m014/l20.a1` / `67135be26f4a1ceab11d25e23effbb4285ddda71`。Git 操作は行っていない。取りまとめから全所見を同じ群で直す指示を受け、追加する完全署名六件を signatures.md に先に追記してから実装した。独立レビューの再判定・設計者の受け入れは担当していない。

| 所見 | 処置と自己点検 |
|---|---|
| 中1 | `StoreTy.reference_annotation`・`lazy_annotation`・`cont_result_annotation`・`cont_annotation` を公開した。入力は Ψ.WF・Ψ.Sorted・StoreTy.Declared P Ψ と場所の lookup だけであり、B/σ/μ/StoreOk を要求しない。既存 StoreOk 四定理は署名を保ってその包装にした。`StoreTy.cont_type_annotation` は `.cont b t e` 全体の Annotation を任意 C/Γ で返す。閉じた場合の WF は ImageOk.contLoc の入力の形になり、Sorted・Declared も同時に得られる。`hidden_store_annotations` は List builder・ref・lazy・cont の四場所を持つ具体的な Ψ で、builder を隠した後の三条件から五つの形成補題を全て使う。隠したストアの StoreOk は受け取らない |
| 軽1 | `rejected_input`・`rejected_effect`・`rejected_reference`・`rejected_lazy`・`rejected_builder_list` の負例を追加した。既存の t の負例と合わせ、S00 の型を読む全欄を照合した。List builder の要素型を読む本番の公開定理 `StoreTy.builder_list_annotation` も追加し、同じ具体的な Ψ の builder を隠す前に呼び出す正例を置いた。r の Sorted は追加していない。ref/lazy の負例は新条件による拒否の言明であり、旧 StoreOk を満たすセルを構成した反例とは扱わない |
| 軽2 | 07-04 の「篩を含む形式化の範囲」から、指定された変更の経緯の一文を削除した。前後の比較は本結果文書に残す |

本番の追加は **公開定理6件**、既存の包装への変更は4件で、全て StateTyping.lean にある。A1 全体の新規本番宣言は初回17件＋今回6件＝**23件**となる。上の初回の集計は初回時点の記録である。定義、型付け規則、四移送、既存公開署名、既定 import、メモリ上限は不変である。境界の所有する契約と追加前の test-audit の関門は signatures.md の r1 節に記した。

| 再確認 | 結果 | 外側の時間・証拠 |
|---|---|---|
| 局所 `lake build Benitoite.Release.Refinement.StateTyping` | 終了0、153 jobs | 0.690秒。[記録](r1/local-build.json)・[出力](r1/local-build.log) |
| `lake env lean -M 12288 …/l20/a1/boundary.lean` | 終了0、追加した五負例・隠した Ψ の正例と既存全言明が成功。最終実行の警告0 | 0.427秒。[記録](r1/boundary-final.json)・[出力](r1/boundary-final.log) |
| 指定 B_WORK の work dry-run | 終了0。spec_tally/spec_examples/formal_build を選択 | [記録](r1/work-dry-run.json)・[出力](r1/work-dry-run.log) |
| 同じ基準の work を一度実行 | 終了0。仕様の対応集計の自己検査成功、完了条件の未記入0、仕様例7件成功、既定 Lean 全体成功 | 26.609秒。[記録](r1/work.json)・[出力](r1/work.log) |
| work 内の既定 `lake build` | 終了0、**774 jobs**。増分ビルド、既定の8対象を維持し sorry の警告なし | **22.711秒**。[記録](r1/default-build.json)・[出力](r1/default-build.log) |
| A1 公理依存を現行の成果物で再実行 | 終了0。11モジュールの全宣言（private/生成宣言を含む）と旧五主定理・三モデル・十移送、計**682宣言**。propext/Quot.sound/Classical.choice のみ。sorryAx・独自公理・未承認依存0 | 1.646秒。[記録](r1/axioms-run.json)・[出力](r1/axioms.log)・[集計](r1/axioms-summary.json) |
| 既存署名と主な十言明 | 既存200署名の初回開始版からの差は、当初の allocate_continuation 三引数だけ。r1 で既存署名の変更0、主な十言明の四ファイルのSHA-256は初回開始時から不変 | [照合](r1/signature-comparison.json) |

初回の追加境界は、Eff の原子の欄に列を渡した入力の誤りと、場所の型の等号から x を置換する処理の不足で終了1だった（[記録](r1/boundary-initial.json)・[出力](r1/boundary-initial.log)）。原子の欄を既存定義どおりの関数へ直し、等号による置換を明示して終了0を得た。本番の定義や固定した署名の変更は不要だった。この修正は境界入力だけなので、本番の既定ビルドと公理監査を重ねて実行していない。

RSS は未取得（計画上の非採取）。Lean 単独は -M 12288、既定ビルドは変更していない moreLeanArgs を使った。S00 の全構成・全読者は上記の初回の照合を維持し、今回の変更箇所を再ビルド・境界・公理監査で確認した。新しい仮定や停止条件に触れるずれはない。全3所見をこの群で処置し、後続単位への移管はない。

初回の manifest とログは初回時点の記録として保持した。r1 の入力・変更ファイル・出力の SHA-256 は [r1/artifact-manifest.json](r1/artifact-manifest.json) に保存する。冒頭の読み取りを含む全作業の外側の時間と能動時間は未分離であり、各検査の実測時間だけを表に示した。

## 作業末の work

`scripts/check.sh --level work --base 67135be26f4a1ceab11d25e23effbb4285ddda71` を、Refinement の生成物を消した状態で実行した。終了0、外側94.62秒、最大常駐量1,369,456,640バイト。

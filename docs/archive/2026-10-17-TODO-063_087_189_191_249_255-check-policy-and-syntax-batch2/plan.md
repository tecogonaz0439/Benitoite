# 0.0.8 の実装プラン

## 前提と依存

本書は [design.md](design.md) と [decisions.md](decisions.md) の47問の回答、R1〜R5、R6〜R17の決定と具体化を前提とする。TODO-255・189・249・191・063・087を一つの0.0.8として実装する。今回の作業は詳しい設計と計画の作成までであり、実装・現行設計・テスト・formal/・docs/todoの変更、コミットは行わない。段1は完了済みである。

| 基準 | 完全なコミットIDと用途 |
|---|---|
| 改造の調査開始版 | `0027a22c171269cf5e5d975ee86bfd568efebb49`（0.0.7公開後）。今回のchange/releaseで段1も含めた差を調べる基準A |
| 段1の実装開始版 | `1294ba9706e17ce3b6613bbe6040924d740a4648`。段1の既存記録だけに使う |
| 段2の開始版 | `677f99447c63f996d0de71458afba34c51b8e23d`（段1とZ1の取り込み）。今回の文書作成と最初の試作L0の基準 |
| 二つ目以降のwork | 直前の作業を取り込んだ完全なコミットID。実装依頼時にBへ固定し、結果に実値を記す。未来のIDを本書で捏造しない |

共通依頼文は、[実装依頼文の写し](implementation-request.md) に作業ID・基準・担当・結果先を具体化する。実装担当はCodex、取りまとめと取り込みはオーケストレータ、レビューはOpus、採否の判断は設計者とする。これは今回エージェントを起動する指示ではない。実装担当はコミットせず、コミット・取り込み・公開は後の明示の指示に従う。

形式化の内側は189の辞書、249の型・効果・節、191の有用性である。段2で全項目のLean・01-12の写し・02-05の判定の写し・07-04の対応表・交換のLean側を先行させる。Coreは保ちRelease/Surfaceの現行モデルを直接改め、旧試験枝の取り込みはしない。段3以降へLeanの未実装を残さない。外部生成の編集と照合、JSON往復、乱数分布と縮小、並行処理、VMの実装は外側として理由を対応表へ記す。

C13の30〜60分と全体15〜20作業は目安であり、設計者はL0後にこの目安の超過と60分を超えるLean作業を認め、範囲を減らさないと決めた（R12）。下表はL0のB案、R13の正規形の補題、RV2初回の指摘修正（R14〜R17）を加えた未実測の幅である。検査・レビュー待ちは別で、証明を書く時間は作業時間に含める。60分を超えることだけを理由に再確認は求めず、60分ごとに状態を報告する。見積もりの2倍を超えそうなとき、R14で了承済みの整形式・ストアWFの強化の範囲外で前提（仮定）を足す必要が出たとき、層の区切りでsorryなしの全体ビルドを保てないときは、動く状態と未完の条件を記録して止め、設計者へ相談する。未証明の状態を取り込んで時間だけを合わせない。

## 段とレビュー

| 段 | 作業・順序 | 作業時間の目安 | 先行条件・新しい接続 | レビュー |
|---|---|---:|---|---|
| 1（済） | W1・W2a・W2b・W3、修正Z1 | 当初4作業180〜235分。実績は既存記録 | 検査の入口と規約。677f9944へ取り込み済み | RV1済（記録名はreviews/R1.md） |
| 2 | L0（済）→Bと正規形の文書レビュー→L1a〜d→L2a〜c→L3a/b→L4a/b | 12作業、2040〜3900分（L0込み、R50/R52反映） | 全項目のLean・写し・全読者。Rustの新機能へはまだ接続しない | RV2。初回・L2a後・閉鎖を区別 |
| 3 | O1→O2 | 2作業、135〜270分 | 操作の辞書をVM・参照実行器・11/4の書き出しへ接続 | RV3の前半 |
| 4 | F1→F2→F3 | 3作業、225〜450分 | 型付きFail・標準関数・解放・シグネチャ由来のQ・CLIと交換 | RV3 |
| 5 | P1 | 1作業、60〜120分 | Characterの判定・診断・移行、三項目のRust/Lean全比較 | RV4の前半 |
| 6 | G1a→G1b→G2→G3→G4 | 5作業、420〜840分 | 宣言API→管理→JSON→Property→通常@testの接続 | RV4 |
| 7 | V1 | 1作業、45〜90分 | 一度の版更新・訳・CHANGELOG、changeと公開候補の照合 | RV5 |
| 段1後 | 24作業（L0は実施済みの取り込まない試作） | 2925〜5670分（48時間45分〜94時間30分、L0込み、R50反映） | L0を除く23作業の計画上の合計は2880〜5610分。先行作業の実績は各results、検査・レビュー待ちは別 | 残り4区切り |

全体は段1の4＋段1後の24＝28作業、実施済みの修正Z1も含め29作業である。L0を除く取り込み対象の主作業は27である。C13の15〜20を超える数と時間はR12とREADMEの決定へ明記する。A1・A2等のレビュー修正は主作業数と区別して実績へ記す。レビューはRV1〜RV5の5区切りとし、判断のR1〜R17と区別する。段1の既存ファイル `reviews/R1.md` は改名しない。

段2の最初のレビューはL0の後、選択済みのBと正規形の定義・全言明・仮定を `l0/statements.md` にLeanのコード片として載せて行う。これは既定のビルドの外の文書であり、未証明の定理をformal/に置く方式ではない。[RV2初回のレビュー](reviews/RV2-initial.md) の指摘はA2で反映する。L1aは拡張したAPIの範囲で開始でき、R14・R15の決定をL1bの先行条件にする。L2aは捕捉規則を文書で具体化して再確認し、L2b/cで定義と証明を同時に取り込む。RV2はL4b後に実際の定義・証明・写しと照合して閉じる。レビューの複数時点の費用は一回の短い応答とは見積もらない。

## 作業に共通する条件

- 各作業は本番の読者と接続し、次の作業の仮置きなしでコンパイルと当該検査を通す。形式化の途中も既定のlake buildを通る単位にする。L2b/cの失敗の規則はL1a〜dの表現の移行と分ける。L0は取り込まない試作、L2aは文書だけの作業である。
- 処理系へ進む前に全Leanを終える。定義と言明をレビューしてから証明に入り、仮定の追加は設計者と合意する。証明本体はLeanの検査で確かめる。
- 途中は関係するテストだけを直接実行し、作業末は下のwork行を一度実行する。Rustのlib全件・関連統合・clippy・fmtを別コマンドで重ねない。失敗や追加変更の後は古くなった検査だけをやり直す。
- テストの追加時はtest-auditの四問を記録する。主な境界は公開の型検査・IR検査、VM/参照実行器の結果、CLIの出力、道具のCLIである。辞書の実装形や生成文字列の固定だけを目的にしない。既存の表へ正負の対照を加え、特殊構成は根の保持に固有の危険を守る。
- 各機能の現行設計・英語の契約・生成元を同じ作業でそろえる。Skillの生成元を変えたら同じ作業で再生成する。翻訳と版全体の整合だけをV1へまとめる。未実装の機能を現行設計へ先に書かない。段2はLeanの写しと未接続の対応を明示する例外である。
- 公開リポジトリからdocs/todoへリンクせず番号を文字で参照する。archiveとreference/は変更しない。項目の閉鎖・保管・公開はこの計画だけでは実行しない。

## 作業A1: L0後の決定と段2の下書きの反映

- 目的: 設計者の2026-10-17の回答を記録し、Bと正規形によるRV2初回確認用の下書きを完成させる。
- 触るファイル: Dのdecisions.md・l0/statements.md・design.md・plan.md・README.mdと `a1/results.md`。formal/・処理系・テスト・docs/todoは変更しない。
- 手順: R6/R7/R8/R10/R12を決定へ改め、R13に全順序・正規化する操作・補題・代替案を採らない理由を記す。L1a〜L4bの下書きを選んだ案へそろえ、L1b/cの工数と合計を更新する。L0のresultsは当時の記録として保つ。
- 完了の条件と検査: 決定と未証明の目標を区別し、変更文書のローカルリンク（見出しを含む）を確認して `git diff --check` を一度実行する。この作業ではcheck.sh・Lean・Rustの検査は追加しない。
- 依存: L0の結果と設計者の回答。RV2の初回確認は後の担当へ渡す。

## 作業A2: RV2初回の指摘の文書への反映

- 目的: 重大2件・中7件・軽6件の指摘と設計者の回答を、段2の下書きと計画へ反映する。
- 触るファイル: Dのl0/statements.md・decisions.md・design.md・plan.md・README.md、reviews/RV2-initial.mdと `a2/results.md`。formal/・処理系・テスト・docs/todoは変更しない。コミットしない。
- 手順: 正規形を整形式へ含める案(A)と計算可能性・Legacyの一時的な拒否の案(b)をR14・R15へ記録する。API・比較の言明・順序モジュールの区切り・L2aの検討事項・文字の写し・見積もりをR16・R17と各文書へ反映し、レビュー全文をそのまま保存する。
- 完了の条件と検査: 変更文書のローカルリンク（見出しを含む）の確認と `git diff --check` を最後に一度だけ実行する。check.sh・Lean・Rustの検査は行わない。
- 依存: RV2初回の本文と設計者の回答（2026-10-17）。未証明の補題の成立とRV2の閉鎖は後の作業へ残す。

## 作業L0: 効果の二案の短い試作と選択資料（実施済みの計画）

- 目的: R6の案A（全有限列）と案B（name/rhoの関数＋Failの列）を比べ、設計者が選べる材料を作る。
- 触るファイル: 取り込まない `/private/tmp/benitoite-batch2-l0/` の独立Leanファイル。追跡する成果はDの `l0/results.md` と `l0/statements.md`（定義・言明・仮定の下書き）だけ。formal/と現行の写しは変えない。
- 手順: 各案で型と効果のshift/subst、束縛の内側でesをずらす処理、合成の補題一つ、effEq_sound相当を試す。関数型のエラー、二Failの順序、atomsの外に生じるFailを含め、l0/results.mdに残す五基準で比較する。試作コードは取り込まない。オーケストレータが比較と未達を報告し、設計者が案を選んだ後、下書きを選択した案へそろえてRV2の初回確認を受ける。
- 完了の条件: 45〜60分の試作で何を確かめ何が未達かを区別した比較表がある。設計者の選択とRV2の初回確認をL1aの前提にする。試作の成功を本体の保証の証明としない。
- 止まる条件: 60分に達した、どちらでも型の等しさと検査器の健全性を結べない、合成が通らない、有限の原子の外を落とす、または選択/レビューが未了。勝手に一案へ進まない。
- 依存・時間の根拠: 実装開始の別指示。段2開始版を照合する。二案の最小の定義と各二補題に時間を区切るため45〜60分であり、未達で終わる可能性を含む。

L0の結果は [l0/results.md](l0/results.md) に残す。設計者のBと正規形の選択は済みであり、選択前の上記の停止条件は当時の記録とする。A1で [l0/statements.md](l0/statements.md) を選んだ案にそろえ、A2でRV2初回の指摘を反映する。L0の試作の記録は変更しない。

## 作業L1a: 効果の参照APIの機械的な整理

- 目的: 意味を変えずに、表現へ直接依存する利用箇所を減らす。
- 触るファイル: Release/Surface/Exchangeの効果への適用と補題、01-12・07-04の対応する記法。結果は `l1a/results.md`。
- 手順: `ε a = true` をEff.mem等のAPIへ移し、mem_empty・mem_union・mem_single・mem_substRhoを用意する。Eff.extで効果のfunextを隠し、Eff.ofAtomsでhandled・singleEff・unionEff等の関数構築を隠す。署名を先行させたEff.substAt c ts es（c/tsはまだ使わない）とEff.shift k c（まだ恒等）を加え、Ty.shiftもEff.shiftを呼ぶ形へ直す。旧表現・旧規則のまま全利用側を置き換える。L0の新表現への切り替えやFail操作の追加は行わない。
- 完了の条件: APIの定義と補題の外に `ε a` の直接の適用と効果についてのfunextが残らず、旧入力の意味と既存の全証明が変わらず、work L1aが通る。
- 止まる条件: 機械的な置換で意味や定理の前提が変わる、全体ビルドを保てない、または共通の時間の停止条件に達する。
- 依存・時間の根拠: R6/R13の決定とRV2初回確認。点検時の約700のEff利用と82ファイル、R16で追加する等号・構築・置換署名・shiftのAPIを含め90〜150分（A1から30分増）。

## 作業L1b: Releaseの型・効果と代入の移行

- 目的: 選択した表現でReleaseの型と効果を同時に辿り、既存の型付け・進行・保存を保つ。
- 触るファイル: ReleaseのSyntax/Subst/Typing/WellFormed/SemanticsとTySubst・TySubstMain・TyLemmas群、既存定理と共有型を読む利用側、01-12・07-04。結果は `l1b/results.md`。
- 手順（L1b1、切り替え前）: 独立モジュールに、atomsCompareの全順序と外延性、ラベル付きの多分木の辞書式順序、汎用sortUniqueのmem・集合による一意性・冪等性の補題を作る。Tyの表現を変える前にsorryなしの既定ビルドが通る区切りとして状態を報告する。これは途中の局所検査であり、作業末のworkを重ねない。
- 手順（L1b2、切り替えと接続）: Bと正規形へ切り替え、Tyから木への単射で全順序を引き戻す。非計算的な選択はatomsCompareだけに限り、tyCompare・型列の比較・sortUnique・normは構造的な相互再帰とする。sortUniqueは0・1要素で比較しない挿入ソートとし、切り替えの冒頭で数例のrfl/decideを直接確認する。normの停止/意味保存/冪等性、norm_shift・norm_substAt・bind_comp・norm_legacy・canonical_of_failsLeOne・sub_normを証明する。shift_compare・shift_canonicalを証明してnorm_shiftへ使う。
- 手順（整形式と既存証明）: Ty.WF/WFList・新しいEff.WF、VarsIn/VarsInList・Eff.RhosIn・NamesWF・ClosedNoEffVars・SupportをFail内部まで広げ、型に埋め込んだ効果とストアWFのCanonicalをR14どおり要求する。norm_WF・norm_VarsIn・norm_RhosIn・norm_supportとNamesWF/ClosedNoEffVarsの保存を証明する。最上位の効果にCanonicalは求めず、恒等式は必要な整形式かEff.Subの両向きで回復する。空代入・約1600行の代入補題群・型の包含・ストアと継続を移す。01-12の写しと07-04の前提の一覧・「01-12 との対応」を同じ変更で更新し、了承済みの前提の強化を明示する。
- 手順（L1b末の検査器）: R15の案(b)に従い、入力の全型と効果を再帰検査してLegacyでないものを一時的に拒否する。計算できるshiftTy・substTyAt・applyToTy・unionEffを残し、Legacyの保存とnorm_legacyからReleaseとの等式を条件付きで示す。検査成功からその条件を導き、健全性11件の言明は変更しない。Surface/Check.leanのmethNameのEff.substRho（レビュー時213行）、SurfaceCheck/Batch.leanのnormalizeのsubstTyAt（同102行）、Surface/Desugar.leanとExchange/Convert.leanの呼び出しを計算できる写しへ替え、六実行ファイルへ非計算的なRelease操作を残さない。Failの捕捉規則とnormWithの実装はそれぞれL2b・L1cへ残す。
- 完了の条件: Releaseの既存の性質・共有型の読者・検査器の健全性11件・六実行ファイルを含む既定の全体ビルドがsorryなしで通り、既存のrfl/decideの例（約360箇所、レビュー時の概数）がカーネルで簡約でき、work L1bが通る。既存の例の証明を弱めて通さない。現在のRustの旧入力の受理は保つ。
- 止まる条件: R14の範囲外の既存定理の前提の追加、Builtins.Assumptionsの追加、層の区切りでの全体ビルド不成立、または共通の時間の停止条件。R14の整形式・ストアWFの強化は了承済みであり、この範囲内ではR12の停止条件に当たらない。
- 依存・時間の根拠: L1aとR14・R15の決定。L1b1は120〜240分、L1b2は360〜600分、計480〜840分（A1の420〜720分から60〜120分増）とする。順序の証明を独立させ、約1600行の代入補題・一般の行の合成・整形式の強化・一時的なLegacyの拒否と六入口の接続を含むため、上端に近づく見込みが高い。L1b1/2は主作業を増やさない内部の区切りで、結果はl1b/results.mdへ集める。60分ごとの報告とL1b1末のビルドで未完の条件を確認する。

## 作業L1c: Surface・脱糖・検査器の移行

- 目的: 表層の型の等しさと有限の原子の判定を新表現へ結び、既存の保証を維持する。
- 触るファイル: Surfaceの型・型付け・脱糖・CheckTools/CheckSound関係と各Lemmas、01-12・07-04。結果は `l1c/results.md`。
- 手順: 再帰的な支持の収集/代入保存、compareWith_eq_compare・normWith_eq_normと支持集合の選び方への不変性を証明する。effEq_sound/tyEq_soundは位置ごとの比較の成功から生のLeanの `=` を返し、支持だけを条件にする。注釈をchecker内で正規化せず、計算した型だけnormWithで正規化する。読者が渡した元のプログラムについてcheckProgram_soundを保つ。L1bのLegacyでない型の一時的な拒否を外し、写しの等式をnormWithと支持の条件で証明する。desugar_typed・surface_effect_soundness・健全性11件を移す。入力から集めたatomsの外を黙って落とさず、代入後の型内部の原子まで扱う。旧表層の受理範囲と名前/行の並びに依存しない判定を保つ。
- 完了の条件: Legacyでない型への一時的な拒否が消え、一般のFailを含む型について写し・正規化・比較の接続と既存の表層/脱糖の保証を保ち、work L1cが通る。新しいFailの規則はL2cへ残す。
- 止まる条件: 健全性11件のどれかが通らない、AtomsInの前提を根拠なく強める、または共通の時間の停止条件。
- 依存・時間の根拠: L1b。11件の健全性と同時再帰の脱糖・代入、型内部の支持の接続を含むL0のB案240〜480分へ、有限支持上の順序/正規化と数学上の定義の一致、位置ごとの比較成功から等号を導く証明と全呼び出し元の支持への接続60〜120分を加え、300〜600分とする。L1cへnormWithの実装を残すため、この作業の幅はA1から変えない。

## 作業L1d: 旧交換入力と六入口の互換性

- 目的: 表現の移行後も今の交換入力をすべて読め、並びだけで差分を作らないことを確かめる。
- 触るファイル: Exchangeの型と効果の読者・比較、六入口、既存独立入力の読者、07-04・formal/README。結果は `l1d/results.md`。
- 手順: corpus8/9/10と他四形式2/3を読む既存入力で、型・効果・desugarDiffの比較を確認する。表現の違いで順序だけの不一致を作らず、旧入力を対象外へ分類し直さない。Rustの並びをLeanのAtom符号順へ合わせず、両辺をLeanの読者で正規化する。Rustに同じ符号を実装しない。旧読者の整理をここで閉じる。新規11/4と全体のcheck-formalはL4bにまとめる。
- 完了の条件: work L1dと既存の独立入力の自己検査が通り、旧入力の受理/拒否/対象外が同じである。
- 止まる条件: 今のcorpusの比較で一件でも不一致、未知の形の読み飛ばし、または共通の時間の停止条件。
- 依存・時間の根拠: L1c。六入口の読者と正規化の境界に絞るため45〜90分。

## 作業L2a: Failの規則と言明の文書レビュー

- 目的: 捕捉の定義と言明を証明の前に具体化する。
- 触るファイル: Dの `l2a/statements.md` と `l2a/results.md`、比較した案を記録するdecisions.md、L2b/cと合計の再見積もりを反映する本書。ビルド対象のLeanや現行の写しには未証明の定義・言明を置かない。
- 手順: L0の下書きと実際の表現を合わせ、Fail操作・E固定の中断節・C_Handle_Fail・K_Handle_Fail、署名からのQ、Admissible(Qcallee,Qcaller,θ)、noFail_substをコード片で示す。K1のFailの伝播からE′=Eとv:Eを導く言明をRV2へ回す。C_Sub/Ty.Leは変えず、Releaseに単一Failを課さない。ReleaseのHasTypeClausesでも通常節にraiseを禁じ、HasFailureClauseはFailの節ちょうど一つに限る。handledのFail列が空であることは定義からの補題とし、K_Handle_Failの前提から外す。QをHasTypeC等の添字へ加える案と定義の表から規則が引く案を比較し、採る判断の形とQsigからQcallerへ写す代入補題をコード片で決める。Admissibleには対象効果eの全ρがes.length未満という範囲条件を含める。Fail節の型束縛はTの一つとし、E-OpでTだけを代入する規則か、閉じた状態で余分なE′の代入が無害となる補題かを選ぶ。0番を環境のnoneで隠し、Ψ κのcont型の各引数・保存継続k1++[.handleF h]のContTy（末尾のK_Handle_Failとその下のK_Empty）・CellOk・K_Dropをコード片で決める。判断と代入の変更範囲を踏まえL2bの見積もりを見直す。
- 完了の条件: 定義・全言明・仮定の確認を終え、L2b/cへ渡せる。work L2aの既定ビルドは未変更の正式モデルを確認するもので、文書の言明の証明とはしない。
- 止まる条件: レビューで前提の追加を求められる、定義の不足がある、または共通の時間の停止条件。設計者と合意するまで証明へ進まない。
- 依存・時間の根拠: L1d。枠・代入・節の束縛・Qの置き場所・継続のストア型の比較と既存の前提の照合に60〜120分（A1から15〜30分増）。レビュー待ちは別。

## 作業L2b: Releaseの失敗捕捉・保存と進行

- 目的: 型を消して最も内側の節を選んでもエラー型を取り違えないことを示す。
- 触るファイル: ReleaseのSyntax/Typing/Semantics/SubstとLemmas/既存Theorems、SurfaceのTyping/Desugar/Checkと呼び出し・値化・メソッドの健全性、01-12・07-04。RV2-L2aの全指摘をl2a/statements.mdへ先に反映する。結果は `l2b/results.md`。
- 手順: R51の了承済みBuiltinOnlyの強化とR53のQのパラメータ化を反映する。表層・脱糖・検査器のAdmissibleと署名由来のQをL2cから移し、性質1・健全性11件の呼び出し側も同時に接続する。確認済みのFail操作・中断節・C_Handle_Fail/K_Handle_Failを定義と既存証明の修正と同時に追加する。K1がFail枠を含まずFail原子を外へ渡す補題、failure_clause_selected_typed、noFail_subst、resume禁止、進行・保存・効果の健全性を証明する。通常のmatch/handleのfromResult/toResultの例を置く。
- 完了の条件: E′=Eとv:Eを継続の規則から導き、work L2bが通る。捕捉安全を仮定に移さない。
- 止まる条件: K1の補題が通らない、別型を誤捕捉する閉じた反例が出る、resume禁止や既存の性質が通らない、または共通の時間の停止条件。ここがF4の停止点である。
- 依存・時間の根拠: L2aの文書レビュー。R46〜R50と [l2a/statements.md](l2a/statements.md) のQ付きの七判断、Tだけの代入、保存継続のcapを前提に450〜900分へ再見積もりした（R52により表層・脱糖・検査器の呼び出し側90〜180分をL2cから移す）。内部の目安は移した表層・脱糖・健全性の呼び出し側90〜180分、Q・通常の呼び出しと七判断の補助の移行120〜240分、Failの捕捉・K1・分割・ストアと解放150〜300分、主な三性質・step_sound・例・写し90〜180分である。既存の判断の補助33件と新判断へ変更が及ぶためであり、検査・独立レビュー待ちは別。正式なモデルへの取り込みは定義と証明を同時に行い、未証明の判断を先に取り込まない。

L2bc4はL2bの続行として、基準Bを `635877cb2bae6b5384b455d4576cb10389ad3836` に固定する。前の区切りのQの接続を保ち、保存したFailの差分と、設計者が了承したR57の空制約の法則を取り込む。今回の完了条件と検査は上のL2bおよび検査の割り当てのwork L2bを使い、記録は引き続き `l2b/results.md` へ集める。L2cの範囲は変えない。

## 作業L2c: Surfaceと検査器の失敗の規則

- 目的: L2bで接続したシグネチャ由来のQのもとで、Failの節と具体化後の単一Failの制限を表層の規則と検査器で検査する。
- 触るファイル: SurfaceのSyntax/Typing/Desugar/Checkと健全性、Examples・CheckCounterexamples、01-12・07-04。結果は `l2c/results.md`。
- 手順: 呼び出し・値化・合流に具体化後の単一Failを前提として置き、その位置で直接検査する。本体からQを増やさず、不足は拒否する。Failと普通の節の混在とresumeを拒否する。直接・高階・部分適用・別モジュール・持ち出したラムダ・再raiseの正負例を置き、健全性11件と脱糖の型保存を通す。
- 完了の条件: `{R1,R2}` へ異なるFailを渡す例を拒否し、通常の行多相は保つ。work L2cが通る。
- 止まる条件: 健全性11件が一つでも通らない、本体推論が必要になる、単一FailをReleaseへ要求する、または共通の時間の停止条件。
- 依存・時間の根拠: L2b。R52により呼び出し側90〜180分をL2bへ移し、150〜300分とする。内訳はFail節・strict/relaxed・支持・最小効果と単一Failの判定90〜180分、健全性11件のFail節の接続とプログラム全体・正負の例・写し60〜120分である。L2b/c合計600〜1200分は変えない。辞書の証拠の二判断はQを消費せず、健全性の外側の前提と結論は保つ。検査・独立レビュー待ちは別。

## 作業L3a: 操作と節の辞書の束縛

- 目的: 操作へ渡した辞書を節の局所束縛へ正しく写す。
- 触るファイル: SurfaceのSyntax/Typing/WellFormed/Desugarと辞書・節のLemmas/CheckSound、Releaseの宣言の一般引数、01-12・07-04。結果は `l3a/results.md`。
- 手順: dictParams・所属を持つ根拠・節の辞書数を加え、0番の継続、逆順の値・辞書・外側の環境を定義する。操作は効果パラメータを持たない（E0510）ので行の具体化はes=[]とし、instantiate (ws ++ [.loc κ])とws=辞書++値に番号が一致することを確かめる。直接の操作と節を接続し、op_dicts_typed/clause_dict_scopeと既存証明を同時に通す。
- 完了の条件: 外側と節の辞書が同番号でも混ざらず、work L3aが通る。
- 止まる条件: 所属の混同の反例、未使用の辞書を落とす必要、既存保証の弱化、または共通の時間の停止条件。
- 依存・時間の根拠: L2c。型と値の二種類の番号のずらし、辞書の所属、節の健全性の接続から90〜180分。

## 作業L3b: 操作の値化と全呼び出しの辞書

- 目的: 値化・穴・パイプ・節内ラムダでも同じ辞書の根拠を使う。
- 触るファイル: Surfaceの呼び出し・辞書・ラムダの脱糖/検査と各証明、例、01-12・07-04。結果は `l3b/results.md`。
- 手順: 操作値を辞書を捕えるラムダへ写し、ソース順の引数の配置へ接続する。複数/上位クラスと内側ラムダの例を置き、性質1〜3と検査器の結論を保つ。
- 完了の条件: 189の全形が型付け・脱糖・独立検査を通り、work L3bが成功する。
- 止まる条件: 外側と節の辞書の混同、呼ぶ時点の効果の消失、既存の結論の弱化、または共通の時間の停止条件。
- 依存・時間の根拠: L3a。値化と三つの呼び出し形の共通化・型保存から90〜180分。

## 作業L4a: 文字の区間と有用性の証明

- 目的: Character全域の判定を補題Uとその系へ接続する。
- 触るファイル: ReleaseのCoverage/CoverageShow/CoverageExtensionとLemmas/CoverageRuntime、SurfaceのCheckPatternsと健全性、01-12・02-05・07-04。結果は `l4a/results.md`。
- 手順: 分割の端へ0・0xD800・0xE000・0x110000と入力パターンの端点およびその隣を加え、LeanのChar上のchar_partition_coverを証明する。文字の列は.otherを外し、整数の列は.otherを残す場合分けを補題Uに加える。07-04「01-12 との対応」の脱糖の行にあるCharacter全域のリテラル列・範囲を01-05より広いとする記述も写しの更新対象にする。補題U、網羅性・束縛・非選択と拡張後の系を更新する。相関・ガード・全域後の分岐・整数据え置きの正負例を置く。反例の表示は実際の比較で確かめ、表示の正しさの全体定理は加えない。
- 完了の条件: 将来の構成子の保証と燃料切れの扱いを維持し、work L4aが通る。
- 止まる条件: サロゲートを値とする、viewの将来の構成子の保証が崩れる、補題U/系が通らない、または共通の時間の停止条件。
- 依存・時間の根拠: L3b。区間の被覆と行列の再帰、拡張後の保証への接続から120〜240分。

## 作業L4b: 交換11/4・六入口と段2の回帰

- 目的: 三項目をRustへ渡す交換契約を確定し、旧出力との回帰を閉じる。
- 触るファイル: Exchangeの全読者/Version、六入口のMain/Walk/Validation、formal/tests/の独立入力と `test_batch2_exchange.py`、lakefile・README・07-04、Dの `l4b/exchange-contract.md`・`l4b/results.md`。
- 手順: corpus11/他四形式4の型・行・辞書・Failを読む。旧版corpus8/9/10、他四形式2/3の受理を維持し、新欄の混入と不正な個数・番号・NoFailを拒否する。六入口の独立した正負入力と自己検査を用意する。契約書へ全版・全必須欄・Rustの切り替え担当O2・Fail実値担当F3を記す。Rustの列順をLeanの符号順へ合わせる必要はなく、両辺をLeanの読者で正規化し、同じAtom符号のRust実装を求めない。末尾で今のRustの10/3出力のcheck-formal全体を一度実行し、RV2を閉じる。
- 完了の条件: work L4b、六入口の独立入力、旧Rust出力の全比較を確認し、定義・言明・仮定と写しをRV2で確認する。R66の取りまとめの判断により、通常とview付きの網羅性の不一致は、すべての不一致の照合対象の型（型引数を含む）にcharacterが含まれると機械的に確かめた場合だけ、P1までの既知差として受け入れる。件数・確かめ方・道具と結果をresults.mdから参照できる形で保存する。脱糖・組み込み・プログラム内の網羅性・表層検査・routing・exchangeは全件一致を要求する。この結果は新機能のRustの証拠へ引用しない。
- 止まる条件: 旧入力を対象外へ逃がさないと通らない、characterを含まない網羅性の不一致が一件でもある、脱糖・組み込み・プログラム内の網羅性・表層検査・routing・exchangeに不一致がある、六入口の欠落、または共通の時間の停止条件。
- 依存・時間の根拠: L4aとL1d〜L3b。五形式・六入口・独立入力の契約の照合から120〜240分。全比較の実行待ち15〜35分は別。

L4bc3はL4bの続行である。基準BはL4bc2取り込みの `4740417fc4c71aad0f83418d2757e368fc0f58e2`、記録先は `l4bc3/results.md` とする。R66・R68の取りまとめの判断を反映し、二つのmanifestへE0908を加える。check_named.pyは既存の検査と期待を維持して全件の独立網羅性を末尾へ移す（R70）。work L4bの名指し、六入口の独立入力、check-formal.sh全体を作業末に各一度実行する。共通の関門Kは本書の「作業に共通する条件」を指す（R69）。

## 段2の停止点とRV2

L0後のBと正規形の選択はR6/R13で決定済みである。[RV2初回の指摘](reviews/RV2-initial.md) はA2で下書きと計画へ反映する。L1aは拡張したAPIの範囲で開始でき、R14・R15の決定をL1bの前提にする。L2aでも文書を確認し、未証明の言明を正式なLeanへ取り込まない。全作業の終わりはsorryを拒む既定の全体ビルドを保つ。層の切り替えでこれを保てなければ、その区切りで止めて取り込み単位を再見積もりする。R14の了承済みの前提の強化以外は、新公理・仮定の追加や対象外への分類で通さない。L1b末のLegacyでない型の一時的な拒否はR15の範囲に限り、L1c末に外す。

設計者へは最小の反例、失敗した言明、規則の不足/書き写し/表現の都合の分類と代案を示す。境界識別値・型を含む実行時選択・公開のNoFail構文は候補であり、自動で採用しない。189だけのRust先行もC14に反する。

RV2では、固定全順序と有限支持上の計算の一致、正規化の冪等/代入との交換/Legacyでの恒等性、一般の合成と正規形からの等号、Qcallee/Qcallerと置換、署名から計算するQ、C_Handle_Fail/K_Handle_FailとK1の伝播、具体化後の表層の単一Fail、EとrigidなT、辞書の所属、文字の全域と将来の構成子、検査器の有限の原子の完全性、写しと全交換の対応を確認する。L4bの検査・旧出力の全比較と実際の定義の照合で閉じ、段全体の再実行は重ねない。

## 作業O1: 制約付き操作を実行まで接続

- 目的: 辞書を渡した操作の節が、任意の型について宣言したメソッドを使えるようにする。
- 触るファイル: `src/syntax/parser/effects.rs`、`src/types/mod.rs`、`src/typeck/{decls,traits/solve,effects/handle}.rs`、`src/ir/{core_ir,check,desugar/*}.rs`、低位IRへの走査・自由変数、`src/bytecode/codegen/{emit,tables}.rs`、VMのhandlersと参照インタプリタ、`tests/vm_handlers.rs`、関係するgolden、01-06・02-05/06/08/09、Skill生成物。srcは `crates/benitoite/src/`。
- 手順: 宣言の制約順の辞書と所属を持つ局所根拠を追加する。節のdict_paramsとIRの独立検査、直接呼び出しと辞書ラムダ、arityとPERFORMの引数、継続・辞書の根の保持を一度に接続する。parserの禁止をtraitだけ解除する。再帰するAST/IRの分岐を増やす場合は既存の枠の分け方を守る。
- 完了の条件: 同じ節で異なる型、複数クラス、上位クラスを使え、値化も内部エラーにならない。公開引数の名前・数とソース順を保つ。work O1と局所heap/stressを次の前提より先に通す。GC本体も変える場合だけ下の条件付き検査を加える。
- 依存: L4bとRV2。結果は `o1/results.md`。
- 止まる条件: 辞書の所属や根を保てない、または共通の時間の停止条件。
- 時間の目安と根拠: 90〜180分。宣言・節・IR・VMの辞書の配置と根の保持の接続からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業O2: 辞書の全呼び出しと交換への接続

- 目的: 値化・穴・パイプ・入れ子とLeanへの書き出しまで189を閉じる。
- 触るファイル: O1の呼び出し・辞書・IR検査の関係箇所、`tests/{named_arguments,vm_handlers,desugar_export,verify,random_programs}.rs` とdesugar_export/の交換器・manifest、英語リファレンスとSkillの説明・生成物。O1で不足のあった箇所だけ直す。
- 手順: 節内ラムダが辞書を捕える例、外側の制約0番と節の0番、名前付き引数の評価順を既存表へ加える。Rustの五形式の版を10/3から11/4へこのO2で切り替える。版一覧・check_named.py・manifestも同時に更新し、L4bの辞書付き宣言・節・根拠へ合わせる。Failの欄はF3までは空、failureTypeはnull、各行のnoFailはfalseとして必ず書く。`desugar_export` にbatch2の辞書の書き出しを追加し、独立入力と実ソースのdesugarDiff・surfaceCheckへの局所接続を確認する。Failの新しいRust入力はまだ作らない。
- 完了の条件: 189の全形がVM/参照結果・IRの独立検査・Leanの局所比較を通る。書き出しの不足を対象外へ分類しない。work O2が通る。段3は同じ接続の結果を引用し、stageの再実行は置かない。check-formal.sh全体の扱いはF3と同じとする。
- 依存: O1。結果は `o2/results.md`。RV3で段4と合わせてレビューする。
- 止まる条件: 11/4への切り替えで旧対象を失う、または共通の時間の停止条件。
- 時間の目安と根拠: 45〜90分。呼び出し形と五形式の版の切り替えからの未実測の見積もり。検査・レビュー待ちは別である。

## 作業F1: 型付きFailの型検査とhandle

- 目的: エラー型・行の条件・非再開の節を表層から実行まで保持する。
- 触るファイル: `src/syntax/{ast,parser/*}.rs`、`src/resolve/`、`src/types/{mod,builtin}.rs`、`src/typeck/{infer,solve,decls,generate,effects/*,traits/*}.rs`、`src/ir/` とVM/参照の必要箇所、preludeの標準宣言表、formatter、diag/codes.rs、golden・vm_handlers・verify、01-02/06/07・02-05/06、Skill生成物。
- 手順: 型引数付きEffectRefと標準Failの同一性を導入し、型と効果の代入・単一化・包含・NoFailのSchemeへの保持と具体化を実装する。普通の操作の型引数と、Failの固定E・rigidなTを分ける。標準raiseと手書きhandleを有効にし、typed clauseとIRの独立検査へ渡し、既存の非再開実行を利用する。シグネチャからだけNoFailを計算し、本体が追加条件を要せばE0515、Failと普通の節の混在はE0518とする。具体化後の単一Failは、01-12「型付きの失敗の表層検査」に従い、関数・辞書付き関数・メソッド・組み込みの値化、呼び出しとパイプ、部分適用で構築する関数型、if・else ifの結果型と合流後の効果、期待型の受け入れ・型の結び・許容効果への包含の各位置で直接検査し、E0513〜E0518を実装する。標準専用の宣言は実際の読者と同時に登録する。
- 完了の条件: 手書きの捕捉と別型への再raiseが動き、高階と別モジュールでNoFailを失わず、resumeを拒否する。単一Failの各検査位置の負例をgoldenに置く。標準表に未接続のtoResultを置かない。work F1が通る。F1で継続の保存領域や根そのものの変更が必要になったらO1/F2と同じ局所特殊構成を先に計画へ加え、F2へ確認を先送りしない。
- 依存: O2と段2の失敗の証明。結果は `f1/results.md`。
- 止まる条件: 署名外のNoFail推論や動的な型の選択が必要、または共通の時間の停止条件。
- 時間の目安と根拠: 120〜240分。共有の型・効果・Schemeとhandleの全読者の変更からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業F2: Resultの変換と解放・タスク・lazy

- 目的: fromResult/toResultを提供し、打ち切りと既存の解放・停止の契約を保つ。
- 触るファイル: `src/prelude/stdlib/Failure.bnt` とモジュール登録、F1の型検査・脱糖、VM handlers・runtimeの解放に必要な箇所、`tests/{vm_handlers,vm_lazy,io_modes,l10_console_clock_process}.rs` とgolden、01-09/10/11・02-08/09・03-06、英語例とSkill。
- 手順: fromResultのmatchとtoResultのhandleを普通のソースで作り、必要なNoFailを宣言表から得る。bodyの成功だけをOkで包み節のErrorを外へ返す。List.map外側の捕捉、入れ子withと解放失敗、return/tryの交差、子内のResult・親の非再開継承の拒否、lazyの純粋性と内側変換、dieの非捕捉を対照にする。
- 完了の条件: error型を失わずShowを求めず、二重評価・後続の実行・二重解放がない。解放失敗をErrorへ隠さない。work F2と局所特殊構成を次の前提より先に通す。GC本体を変えた場合だけ条件付き検査を追加する。
- 依存: F1。結果は `f2/results.md`。
- 止まる条件: 二重解放や誤捕捉、停止の契約の変更が必要、または共通の時間の停止条件。
- 時間の目安と根拠: 60〜120分。通常の標準関数とwith・タスク・lazyの解放の接続からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業F3: Failの交換とCLI入口の整合

- 目的: 受理したmain/@testの契約と、Leanが読む型・行・節を一致させる。
- 触るファイル: `src/cli/{inspection,effect_limit,check_report}.rs` とtest_runnerの入口、`src/typeck/effects/declarations.rs`、`tests/{cli_process,test_command,desugar_export}.rs`、交換manifest、必要なgen_skillと英語文書・06-01/04。
- 手順: Failが未処理なら静的診断で止め、許可名やexpandedへ追加しない。check/testの受理した入口は従来の形式を保つ。O2で切り替えた交換11/4へRustの全型・Scheme・節の実際のFailと行の条件を書き、batch2の独立の正負入力と本番ソースの対応を追加する。toResultのRest違反を、型検査から交換まで局所比較する。
- 完了の条件: 新形式の欠落や対象外で成功としない。既存try/die・allow-effects・非実行のtest --checkを保ち、work F3が通る。RV3で段3〜4をレビューする。三項目の全比較はP1へ残す。O2・F3ではcheck-formal.sh全体を実行せず、割り当てた局所比較だけを実行する。追加の調査で全体を実行する場合はR66の条件とl4bc3/check_character_mismatches.pyで全不一致を分類し、characterを含まない不一致が一件でもあれば停止する。
- 依存: F2。結果は `f3/results.md`。
- 止まる条件: 対象内のFailを対象外にしないと通らない、または共通の時間の停止条件。
- 時間の目安と根拠: 45〜90分。CLI入口と全型・Scheme・節の交換からの未実測の見積もり。検査・レビュー待ちは別である。

## RV3: 段3・4のレビュー

辞書の選択と所属、公開引数の契約と評価順、エラー型の不変性、シグネチャだけから導くNoFailと後の具体化、節から外への再raise、Tのrigid性、resumeの禁止、根の保持・解放と二つの失敗、子とlazy、CLIの未処理の拒否を確認する。独立のIR検査とLeanの書き出しが型検査の判断をそのまま信じていないかも見る。段4のstage全件は置かず、O2/F3の局所接続とP1末の全比較に分ける。レビュー修正で古くなった結果だけを更新する。

## 作業P1: 文字の判定・診断・移行と全比較

- 目的: Characterの全域と不足を正しく判定し、従来必要だった後続分岐の破壊を案内する。
- 触るファイル: `src/typeck/{patterns,pattern_ext}.rs`、`src/ir/{desugar/patterns,decision}.rs` の必要箇所、`tests/{coverage_export,desugar_export}.rs`、goldenと読者、`tests/desugar_export/check_named.py` とmanifest、`scripts/check-formal.sh` のbatch2局所入力の接続、01-02/05・02-05・英語例・Skill、`p1/migration.md`。
- 手順: L4aの文字の区間分割と実在の反例を実装し、相関・ガード・viewを保つ。P3の移行候補を本番ソースの診断で調べ、既存テストの意図を保って期待を更新する。文字のE0601の反例が `_` から最小の有効な文字（例: `'\u{0}'`）へ変わるgolden・Skillの診断例とCHANGELOGを更新する。反例の表示はR64とCoverageShowに合わせ、ASCIIの可視文字はリテラル、改行・復帰・タブ・逆斜線・単一引用符は対応するエスケープ、それ以外は桁を埋めない小文字の十六進のUnicodeエスケープとする。boundary/surrogateで全域の後の分岐が選ばれないことと、全域の束縛が必ず照合することも対照にする。ir/decision.rsは `_` なしで網羅した文字を許し、到達しない最後の分岐を内部エラーとして扱う（調査版2584行目付近のテストも確認する）。全比較の既存の六入口と件数・独立入力・交換manifestへbatch2を接続し、全体を実行する。変更は本番判定の反映に限り、Lean規則の不足を見つけたら段2へ戻る。
- 完了の条件: 文字の全域・束縛を受理し、一文字欠けと後続分岐を適切に拒否する。Integerは据え置き。work P1と独立のcheck-formal全体が成功し、通常とview付きの網羅性の不一致がともに0件となり、189・249・191の接続を閉じる。L4bで受け入れたcharacterの既知差を残さない。証拠の関係状態を記録する。
- 依存: F3とRV3、L4a/b。結果は `p1/results.md`、接続全体はDのresults.mdへ集約。RV4は段6と合わせる。
- 止まる条件: Leanと判定が一致しない、または共通の時間の停止条件。
- 時間の目安と根拠: 60〜120分。文字の区間・IRの既定分岐・診断と移行の照合からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業G1a: 宣言の読み取りAPIとexample

- 目的: 未生成関数を含む本体の型検査に依存せず、宣言の解決した構造を取得する。
- 触るファイル: `src/pipeline.rs` と新規 `src/pipeline/declarations.rs`、既存のresolve/typeckの宣言収集の共通部、`examples/derive_inventory.rs`、関連統合テスト、02-01・03-06・06-04/06。これは処理系の公開APIの追加でもある。結果は `g1a/results.md`。
- 手順: designのcollect_declarationsとDeclarationResultを追加し、読み込み・宣言だけの解決と検査を共用する。本体は解決・型検査・評価しない。exampleで解決した型の木と位置・可視性・依存・関数のシグネチャ・全入力ハッシュをversion1のJSONへ書く。本体の未生成参照は読め、宣言の誤りは拒否する正負例を置く。
- 完了の条件: 後続が別の型解決器を作らずにJSON契約を利用でき、work G1aが通る。通常のcheckの成功とは区別する。
- 止まる条件: 宣言だけの解決のため既存checkの型や契約の変更が必要、本体の実行/評価を要する、宣言の誤りを見逃す、または共通の時間の停止条件。
- 依存・時間の根拠: P1（編集の重複を避ける順序）。既存の宣言収集の分離と公開境界の接続から60〜120分。189/249への機能上の依存はない。

## 作業G1b: 生成領域の管理と照合

- 目的: preview・確認済みmanifestのapply・checkで手書きと古い出力を保護する。
- 触るファイル: `tools/derive/{derive.py,README.md,test_derive.py}` と設定、source-migrateとの接続、03-06・06-04/06。結果は `g1b/results.md`。
- 手順: G1aの入力を読み、設定/型の構造のハッシュ、管理印・manifest・receipt、formatter後のハッシュを実装する。自己検査は小さな固定の生成関数を入力として編集・照合の契約を観測し、利用者向けのgenerationInfo関数は作らない。JSON/Propertyの意味の生成はG2/G4まで未提供と明記する。診断は説明文と終了0/1/2に絞る。管理解除は印・設定・記録を手で外す手順としてREADMEに書く。
- 完了の条件: 初回/再適用・入力変更・手書き保護・衝突・未対応設定を区別し、work G1bが通る。未実装の生成機能を使えると説明しない。
- 止まる条件: ハッシュ不一致でも書く、領域外を書き換える、source-migrateの保証を超える仕組みが必要、または共通の時間の停止条件。
- 依存・時間の根拠: G1a。既存の編集の共通部を再利用しても管理印・全入力・整形・再適用の境界があるため90〜180分。

## 作業G2: JSONの変換ライブラリと生成

- 目的: 通常のResultの変換を型から作り、欠落・数・経路と再生成を検査できるようにする。
- 触るファイル: `src/prelude/stdlib/Json/Codec.bnt`・登録、tools/deriveのJSON生成部と自己検査、`tests/l21_json.rs`、例と生成記録、03-08・英語例とSkillの生成元/生成物。
- 手順: ConversionErrorと基本型・コンテナの純粋な補助関数、欄順の変換、キーの改名とカスタム関数を実装する。型の宣言からpreview/applyし、生成された通常のコードをcheck/testする。None/null、余分なキー、入れ子Option、数の暗黙変換と非有限、型変更後も通る古いencodeを対照にする。
- 完了の条件: 往復の条件と失敗の経路がdesignどおりで、生成checkが欄追加と設定変更を検出する。work G2が通る。CodecがFailに依存しない。
- 依存: G1b。結果は `g2/results.md`。
- 止まる条件: 往復の条件や失敗の順を満たせない、または共通の時間の停止条件。
- 時間の目安と根拠: 90〜180分。Codecの基本型/コンテナとレコード生成の接続からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業G3: 純粋な生成・縮小と性質の試行

- 目的: 手書きでも利用できるPropertyの値と試行の関数を提供する。
- 触るファイル: `src/prelude/stdlib/Test/Property.bnt` と登録、`tests/property_library.rs`（新規の統合ターゲット）、06-04・03-06・英語例とSkill。既存Randomの内部の乱数方式は変えない。
- 手順: Gen/Shrinker/Config/CheckFailure、基本とコンテナの生成、縮小、check/formatFailureを通常のソースで実装する。誤設定での非実行、seed、整数両端、size=0、有限Float、循環縮小の上限と失敗の保持を公開関数から確認する。@test一件からResultとして返す例を使う。
- 完了の条件: 縮小するのは純粋な性質のErrorだけで、実行時エラー・exit・中断を変換しない。再現情報とoriginal/reducedを持ち最小性を約束しない。work G3が通る。
- 依存: G2（順序上のみ）。結果は `g3/results.md`。
- 止まる条件: 有界の候補試行で止まらない、再現情報が不足する、または共通の時間の停止条件。
- 時間の目安と根拠: 120〜240分。基本生成・コンテナ・縮小・試行上限と再現の契約からの未実測の見積もり。検査・レビュー待ちは別である。

## 作業G4: レコードの生成器・縮小と利用の接続

- 目的: 型からGenとShrinkerを作り、JSONの往復を既存@testで試す用途を閉じる。
- 触るファイル: tools/deriveのProperty生成部・自己検査・設定例、`tests/property_library.rs`・l21_jsonと例・生成記録、`tests/desugar_export/` の標準宣言とmanifestの必要箇所、tools/derive/README・06-04/06・英語リファレンス・Skill。
- 手順: 欄順のGeneratorの受け渡し、一欄ずつの縮小、カスタムGen/Shrinkerを指定した関数を生成し、版と設定ハッシュは生成記録に残す。非循環の依存と未対応型の拒否をJSONと共用する。実型からJSONとPropertyを同じ領域へ生成し、再生成check→通常のcheck→@testの流れを確認する。新しい通常の標準宣言を書き出し、最終全比較の入力をそろえる。
- 完了の条件: 欄の追加と設定変更を検出し、同じseedと版で再現し、型の構造だけから欄間の条件を保証しない。work G4が通る。RV4で段5〜6をレビューする。
- 依存: G3とG2。結果は `g4/results.md`。
- 止まる条件: 生成checkが型の変更を検出しない、または共通の時間の停止条件。
- 時間の目安と根拠: 60〜120分。レコードの欄順の生成とJSON/@testとの接続からの未実測の見積もり。検査・レビュー待ちは別である。

## RV4: 段5・6のレビュー

Characterの区間と相関、実在の反例、ガードとview、P3の後続分岐と移行を確認する。生成では型の同一性・可視性・依存・管理印・全入力の検証、再生成の漏れ、Optionと数の情報の損失、カスタム関数、JSONの失敗の順と経路、生成の順と縮小の上限を見る。test --checkが生成器を実行せず、普通の@test一件の結果として報告することを確認する。段6末の新しい接続はstage表へ名指しする。G4が同じ関係状態を検査済みなら引用し再実行しない。

## 作業V1: 一度の版更新・文書と最終候補の確認

- 目的: 六項目を0.0.8の一つの候補へまとめ、回帰の証拠と実際の配布候補を対応づける。
- 触るファイル: Cargo.toml/Cargo.lock、言語版の定数、通常のlanguage宣言・固定ハッシュ、CHANGELOG、README・docs/reference・docs/ja、同梱Skillと生成物、toolsの通常入力・生成記録、Dのresults.md。archiveとreference/は変えない。
- 手順: rgで版の全読者を調べ、通常入力と旧/未来/不正版の負の入力を分類し、一度だけ版を上げる。各機能で保守した英語の正から訳を作り、再生成を照合する。change、最終関係状態のcheck-formal、必要なheap、性能の測定、候補のreleaseとCLI・配布の照合を下表どおり行う。結果の引用可否を判断し、RV5へ渡す。
- 完了の条件: change全体の所定集合と最終の形式化の関係状態、候補のrelease_stack、実CLI、版・生成物・同梱物・移行の照合がそろう。未実施を成功とせず、タグ・push・公開・保管・docs/todoの更新は別の明示の指示に従う。検査成功だけで公開済みとしない。
- 実装担当の範囲（R105）: Z2 取り込み後の版・文書・訳・生成物の照合と作業末の work まで。change・最終 check-formal・性能の本測定・release と候補の照合は V1 取り込み後に取りまとめ担当が行う。
- 依存: G4とRV4、全レビュー修正。結果は `v1/results.md`、全体と候補の集約はDの `results.md`。RV5で受け入れを判定する。
- 止まる条件: 回帰・候補の証拠が不足、または共通の時間の停止条件。
- 時間の目安と根拠: 45〜90分。既に整えた英語版からの訳・版と生成物の照合からの未実測の見積もり。検査・レビュー待ちは別である。

## 検査の割り当て

### 基準とコマンドの読み方

実行前に取りまとめ担当がBを直前の取り込みの完全なIDに固定する。L0だけは上の段2開始版である。設計文書だけを先に取り込んだ場合も、この固定した基準からの差分を確認して使い、処理系の開始状態が変わったら実装前に計画を改める。Aは `0027a22c171269cf5e5d975ee86bfd568efebb49` とする。各行のcheck.shは同じ指定へ `--dry-run` を付けて選択・理由を確認してから一度実行する。文書のリンク・表・差分は各行に付随して確認する。O1/F1/F2の手書きの統合ターゲット一覧は調査時の36件である。各作業の開始時に `rg --files crates/benitoite/tests -g "*.rs"` の直下のターゲットから作り直し、追加・改名・削除を反映して検査行を固定する。下の `src/` や標準ソースを共有するRust作業は、全統合ターゲットがその入力の読者となりうるため、`--test` の省略による自動workで全統合を選ぶ。段末で同じ全件を重ねる指定ではない。

Rustの自動workはfmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyに、変更した文書と生成元の条件付き検査を加える。下表で `--only` を名指しした行はこの自動集合を使わず、表の全名を実行する。存在しないtestや誤指定2は計画を直す。分類不能・基準不明3はAGENTS.mdに従って設計者へ選択を求める。既に名指しした行はその指定で進める。

| 水準 | 基準・契約と読者 | 具体的なコマンド・対象 | 担当・見込み時間 | 保存先 |
|---|---|---|---|---|
| work A1 | L0後の設計者の回答、文書だけ | 変更文書のローカルリンク（見出しを含む）の確認と `git diff --check` だけ | 実装担当、数秒 | a1/results.md |
| work L0（済、当時の計画） | 段2開始版、独立試作と選択資料 | formalを作業ディレクトリとして `lake env lean /private/tmp/benitoite-batch2-l0/A.lean` と同B.lean。正式モデルは変えない。文書末はリポジトリの根へ戻り `scripts/check.sh --level work --base "$B"` の文書のみの自動選択 | Codex、試作は60分の内数。文書検査は数秒 | l0/results.md |
| work L1a | Bと正規形の選択済み、RV2初回確認。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l1a/results.md |
| work L1b | L1a取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l1b/results.md |
| work L1c | L1b取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l1c/results.md |
| work L1d | L1c取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally`。既存の独立入力は `python3 -B formal/tests/test_named_exchange.py`・`python3 -B formal/tests/test_extensible_exchange.py`・`python3 -B formal/tests/test_try_exchange.py`・`python3 -B formal/tests/test_width_exchange.py` | Codex、5〜20分（再証明の執筆時間とは別） | l1d/results.md |
| work L2a | L1d取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l2a/results.md |
| work L2b | L2a取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l2b/results.md |
| work L2c | L2b取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l2c/results.md |
| work L3a | L2c取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l3a/results.md |
| work L3b | L3a取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l3b/results.md |
| work L4a | L3b取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分（再証明の執筆時間とは別） | l4a/results.md |
| work L4b | L4a取り込み。目的と読者は各作業の節 | `scripts/check.sh --level work --base "$B" --only formal_build,spec_examples,spec_tally`。続いて `python3 -B formal/tests/test_batch2_exchange.py`、独立の全比較は次表 | Codex、5〜20分（再証明の執筆時間とは別） | l4b/results.md |
| work O1 | L4b取り込み。AST・型・IR・VM、入力の全読者 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,release_stack --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。依頼の指定に従い `cargo clippy --all-targets` を別に一度実行する（R73）。Bは `8604e358d68e9f19897903afeb5c5b3635a97c18`。局所の二構成のCargoは次表 | Codex、10〜25分。根の保持と再帰の枠の変更を次へ持ち越さない | o1/results.md |
| work O2 | O1取り込み `0583575376a305930dd8097922b6901670b70871`。全形とRustの交換器 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`（統合は全36件）と `cargo clippy --all-targets`。開始時の自動選択からlint_defaultだけを後者へ置き換える（R77）。局所の交換の実行は下の表 | Codex、5〜15分＋局所比較 | o2/results.md |
| work F1 | O2取り込み。共有の型・Scheme・formatter・IRと入力の全読者 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,release_stack --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。R79 に従い `cargo clippy --all-targets` を別に一度実行 | Codex、10〜25分 | f1/results.md |
| work F2 | F1取り込み `2b962263861d836364dc332e543d327cbed2cbb4`（R82）。解放と安全点を越えるエラー値 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。`cargo clippy --all-targets` を別途一度実行する（R82）。局所の二構成のCargoは次表 | Codex、10〜25分 | f2/results.md |
| work F3 | F2取り込み `3a3ef9e73b460b0d89f3ae039147a0e6a61cc9b1`。CLI・型・全交換の読者 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。R85 に従い `cargo clippy --all-targets` を別に一度実行。局所の交換は下表 | Codex、5〜15分＋局所比較 | f3/results.md |
| work P1 | F3・RV3取り込み `04e82f6f8d7510b0aca968c4573fee0e249cd62e`。判定・移行で共有入力を変更 | `scripts/check.sh --level work --base 04e82f6f8d7510b0aca968c4573fee0e249cd62e --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。R88 に従い `cargo clippy --all-targets` を別に一度実行。独立の全比較は下表 | Codex、5〜15分＋全比較 | p1/results.md |
| work G1a | P1取り込み。宣言APIとexample | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test build_info --test call_allocations --test cli_process --test coverage_export --test declarations --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。自動 dry-run の7単位から lint_default を除き、依頼の `cargo clippy --all-targets` を別に一度実行する（R92）。全37統合ターゲットを指定。`cargo build -p benitoite --example derive_inventory`。B は `95902e535c2f777d426e0a14df51d8b924baf274` | Codex、5〜20分 | g1a/results.md |
| work G1b | G1a取り込み。Pythonの管理と照合 | `scripts/check.sh --level work --base "$B"`（文書/Pythonのみ。Rust全libは追加しない）、`python3 -B tools/derive/test_derive.py` | Codex、1〜5分 | g1b/results.md |
| work G2 | G1b取り込み `8fc101a8e17c630ca0e54449ab1e4bb169fda4cf`。標準ソース・生成・JSONの読者 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*'`。R96に従い `cargo clippy --all-targets` を別に一度実行。`python3 -B tools/derive/test_derive.py`、例の `benitoite check/test tools/derive/examples/People.bnt` と `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | Codex、5〜20分 | g2/results.md |
| work G3 | G2取り込み `71803f7370d170187d8550e7cee5e4b17b2d8624`。標準ソース・Property | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`。R100に従い `cargo clippy --all-targets` を別に一度実行（全統合に新規property_libraryも含む） | Codex、5〜15分 | g3/results.md |
| work G4 | G3取り込み `ccb282dec3d1722f1378b43981b5bcf9280af27e`。共通生成・標準宣言・通常@test | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test '*'` と `cargo clippy --all-targets`（R103。自動選択のlintだけを置き換え、統合は全件）、`python3 -B tools/derive/test_derive.py`、`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | Codex、5〜20分 | g4/results.md |
| work V1 | Z2 取り込み `443e1faff532a66352986150d3f36e8e72be3319`。版と入力の全読者 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'` と `cargo clippy --all-targets`（R105）。`cargo build -p benitoite --example derive_inventory --bin benitoite`、`python3 -B tools/derive/test_derive.py`、`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json`、変更文書のリンクと差分の照合 | Codex、5〜20分。change・全形式化比較・性能本測定・release は取りまとめへ残す | v1/results.md |
| stage 2〜4 | Leanの全契約、189/249の局所接続 | stageは省く。L4b（旧出力の全比較を含む）、O2、F3の結果を同じ関係状態で引用。三項目の全比較はP1へ担当を残す | 取りまとめ、RV2/RV3で根拠を記す | results.md |
| stage 5 | 189・249・191をRust/Leanへ初めてすべて接続 | check.shのstageは省く。P1の `scripts/check-formal.sh` 全体を接続の検査にする | 取りまとめ、15〜35分（見込み） | results.md |
| stage 6 | 生成管理・JSON・生成と縮小・@testの接続 | `scripts/check.sh --level stage --base "$S6" --only tests_related --test property_library --test l21_json --test test_command`、deriveの再生成check。G4で同じ接続を確認済みなら引用し再実行しない | 取りまとめ、2〜8分。S6はG1a直前の取り込み | results.md |
| change | AからV1統合後。段1のスクリプトも含む全変更 | 下の「changeの名指し」の一回を使う。自動分類はcheck-heap.shで停止する既知のため名指しを固定 | 取りまとめ、60〜120分＋独立全比較・測定 | results.md |
| release | 実際の0.0.8候補・構成・同梱物 | `scripts/check.sh --level release --base "$A"` と下の手動照合 | 受け入れは設計者、実行は取りまとめ、10〜20分＋ビルド | results.md |

### 全件・特殊構成・局所比較の担当

| 必要な検査 | 割り当てと具体的な対象 | 担当・時期・保存先 |
|---|---|---|
| 既定/heapのall-targets、doc、stress、両lint | changeの名指しにすべて含める。all-targetsにworkspaceの通常testを重ねない。docは独立に実行する | 取りまとめ、V1、results.md |
| long_only | changeの名指し。heapとstressのignoredを一括し、formalの書き出しを成功件数に含めない | 同上。長い検査として事前に知らせる |
| 局所のheap/stressと条件付きのdoc | 特殊構成は下の局所Cargoを各一回。辞書とエラー値が継続・解放を通り安全点を越えるため。ほかの作業で根を変えたら計画の行を改訂してから依存にする | Codex、次の作業より先、o1/f2の結果 |
| check-heap.sh | O1/F2はGC本体を変えなければworkに加えない。runtime/heapの回収・根・障壁の不変条件も変える場合だけ、その作業のworkへheap_checks・lint_heap・doc_defaultを加え、次の前提にする前に実行する。changeにはheap_checksを名指しする。最後の関係状態への結果を引用できる場合だけ、changeの名指しからheap_checksを外して根拠を記す | 取りまとめ、results.md |
| Lean既定ビルド・レビュー | L1a〜L4bのformal_build・spec_examples・spec_tally。既定の `lake build` がライブラリと六入口を含みsorryなしで成功することを確認する。新公理や弱い仮定への置換はRV2で拒否 | Codex・Opus、段3より前、各作業の結果とreviews/RV2.md |
| 189の局所交換 | O2の作業末の書き出しでbatch2辞書のcorpus/builtins/stdlib/coverageを生成し、`python3 -B formal/tests/test_batch2_exchange.py --rust-dir target/formal-batch2-op` を実行する。このオプションと出力先はL4b/O2で実装する契約である | Codex、O2。六入口で辞書の対象内入力が落ちないことを記録 |
| 249の局所交換 | F3も同じ自己検査を `--rust-dir target/formal-batch2-failure` で実行する。L4bが用意した独立入力とRustの書き出しを対応づける。続いて `python3 -B crates/benitoite/tests/desugar_export/check_failure.py --rust-dir target/formal-batch2-failure --report "$D/f3/exchange-results.json"` で実ソースと同じ Rest 違反・宣言の Q の不一致を確認する（R85） | Codex、F3。p1で全比較する担当を残す |
| check-formal.sh全体 | L4b末は今のRustの10/3出力で回帰だけを一度確認する（新機能の証拠には引用しない）。P1末とV1の最終関係状態で `scripts/check-formal.sh`。六入口・独立の正負入力・全本番corpus・件数と対象外・交換manifestを確認。後の標準ソース・版・生成例は入力を変えるので、P1の成功をV1へ無条件に引用しない | 取りまとめ、L4b/P1/V1、results.md。各15〜35分、実測を記す |
| release_stack | O1とF1では再帰の枠・型の走査の変更の局所の前提。最終はreleaseに含める。途中の成功を候補の構成の成功にしない | Codex/取りまとめ、各結果・最終results.md |
| 外部生成の自己検査 | G1b/G2/G4のworkとV1。`cargo build -p benitoite --example derive_inventory` はG1aで必要な読み取り用バイナリをビルド。以後はそのexampleの入力が変わったら再ビルドし、V1のchangeのall-targetsでも確認 | Codex、g1a/g1b/g2/g4とv1の結果 |
| deriveの再生成check | G4のworkとV1最終候補。`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | Codex、生成記録・例を変える前に引用しない |
| 性能 | 型・操作・VMを変えるためV1の最終状態でbenchmarkスキルの出力照合・本測定・CPUプロファイルを一度実施。機能検査と並行しない。下の条件に従う | 取りまとめ、tools/bench/resultsのMarkdown/HTMLとresults.md |

O1/F2では `--test` を通常と特殊構成で分けられないため、check.shでは既定構成の全読者を検査し、同じ作業末に次の局所Cargoをそれぞれ一回実行する。check.shの呼び出しを二回に分けず、全統合のheap/stressも追加しない。これは既存入口の対象共有による計画上の直接指定である。O1はvm_handlers、F2はvm_handlersとvm_lazyを対象とする。doc_default・lint_heap・heap_checksはGC本体の変更を伴う場合だけwork本体へ加える。通常は局所heap/stressとchangeの担当に従う。

```sh
# O1
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_handlers
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_handlers
# F2
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_handlers --test vm_lazy
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_handlers --test vm_lazy
```

局所交換のRust書き出しは、既存 `desugar_export` の通常のテストへ `export_batch2_op`・`export_batch2_failure` を追加し、workのtests_relatedで一度生成する。上のPythonはCargoを再起動せず、その出力を読む。新しい引数をL4bで受理する段ではRust出力がないため独立入力だけを使い、存在しないRust出力を成功扱いしない。六入口の旧入力・新入力の拒否・対象外を区別する。

L4bの旧出力の全比較は段2の移行の回帰を示すだけで、P1の三項目の新機能の比較を代行しない。`formal_build` の成功を `check-formal.sh` 全体の成功とは呼ばない。P1末は形式化とRustが初めて全部つながったため全比較が必要である。G2〜G4とV1で標準宣言・例が変わるため、最終関係状態でも全比較を実行する。もし入力・生成物・道具・構成がすべて同じと説明できる区切りなら07-03の全欄で引用できるが、実行していない現在の計画に引用済みの欄は作らない。

### changeの名指し

段1でcheck-heap.shの説明を変更したため、改造開始版Aからの自動changeは分類不能で終了3になる。段1の既知の停止を新しい設計者への選択に持ち越さず、全変更の読者を補った次の名指しを計画で固定する。`--level change --only` は分類せず、この集合だけを実行する。release_stackは実際の公開候補で確認するためここには重ねない。

```sh
scripts/check.sh --level change --base "$A" --only fmt,lint_default,lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,skill_eval_selftest,licenses,policy_selftest,long_only,heap_checks,formal_build
```

spec_examples/reference_examples/skill_docsはtest_default_allに含まれる場合、入口の包含規則で同じ構成の再実行を省く。新しいtools/deriveの構文と自己検査は既存のpython_syntax/migrate_selftestsに含まれるとは仮定せず、V1で `python3 -m py_compile tools/derive/*.py` と `python3 -B tools/derive/test_derive.py` を別の読者の検査として実行する。tools/derive/*は既存のtools/*の分類でpythonとなるが、構文検査の列挙とmigrate_selftestsの呼び出し先には含まれないため、この直接指定を残す。別の新規パスで分類不能が出た場合は規約どおり停止する。check.shの分類や実行単位を導出のためだけに広げない。

C8に従ってheap_checksやformal_buildの結果を引用する場合は、この具体的なonlyから当該名を外した残りの全名をresults.mdに記す。改造全体の回帰の結果の記録がそろうまでは、部分選択の終了0をchangeの完了にしない。

### 最終候補の受け入れとRV5

V1の最後の差分を含む候補の完全なHEAD、dirtyの有無と一覧、版、ツールチェーンとビルド構成、ソースアーカイブの対象を固定する。段1〜6の結果の引用とその後の変更を確認し、最終候補からビルドした実CLIで次を照合する。回帰全件を新しい受け入れスイートとして複製しない。

- `benitoite --version=json` の版・ビルド情報・formatsと、通常/旧/未来/不正版のlanguageの受理・E0908の案内。
- check/run/test/test --check、allow-effects、Skillの一覧と取得。未処理Failは検査段階で拒否し、処理済みのcheck/test報告と許可名は0.0.7の形式を保つ。
- 制約付き操作の表示、List.map外側のtoResultと既存のtry/die、文字の全域と後続の `_` の拒否、生成したJSONの往復の@testを、保存済みの代表例から実行する。
- derive preview/apply/checkの手順、型変更後の再生成の拒否、版・設定・生成記録、同梱標準ソース・Skill・英語と訳・移行案内の対応。
- ソースだけを配布する候補にtools/derive、examples、生成に必要なソースと手順が含まれ、秘密の入力・未追跡の生成記録へ依存せず、候補のソースからビルド・生成checkを行えること。公開を行わず `/private/tmp` の候補用ディレクトリへ追跡済み内容とレビュー対象の差分を写して照合する。未コミットの候補をgit archive HEADだけで作ったと誤記しない。

性能は既存のbenchmarkスキルに従う。最終の `cargo build --release -p benitoite`、examplesとalloc-stats、比較対象Rustのビルド後、`python3 tools/bench/run.py --benitoite target/release/benitoite --verify`、同スキルの本測定、handler/traitを含む対象のCPUプロファイルと所見を記録する。測定時に他の作業を止め、電源と負荷を整える了承は、その時点で同スキルの明示の手順に従う。今回は測定しない。実行環境が整わなければ担当と時期を記してV1を未完とし、無測定を成功へ置き換えない。LLMを呼ぶskill-evalや構文測定はこの計画の許可に含めない。

RV5では、実際の候補・同梱物・所定の検査・移行の範囲・性能の所見の対応と、未実施・失敗の処置を確認する。releaseの自動検査の終了0はrelease_stackの成功であり、受け入れはこの照合を終えて設計者が判断する。公開・タグ・pushの操作は別の明示の指示に従う。

## 結果とレビュー修正の管理

| 結果ID | 保存先 | 後の変更と引用の判断 | 再実行の担当 |
|---|---|---|---|
| 段1 | 既存のw1/w2a/w2b/w3/z1とresults.md | 道具の契約の証拠。今回の型・VM・Leanの成功へ転用しない | 取りまとめ |
| L0・L1a〜L4b | 各小文字ID/results.md、reviews/RV2.md | Leanの定義・言明・写しと独立入力。後のLean修正で古くなる | Codex、RV2を再確認 |
| O1〜P1 | 各小文字ID/results.md、reviews/RV3.md | 根の保持と実行、交換の接続。P1の全比較後も標準宣言の変更を追う | Codex/取りまとめ |
| G1a/G1b〜G4 | 各小文字ID/results.md、reviews/RV4.md | 生成の道具・設定・型・管理領域・標準宣言。版と生成物の変更を含めて判断 | Codex |
| change・最終形式化・性能 | v1/results.mdとDのresults.md | 正確な候補と構成・件数を記録し、その後の修正で古くなる検査だけを更新 | 取りまとめ |
| release | Dのresults.md、reviews/RV5.md | 候補を固定して照合。公開の操作とは別 | 設計者/取りまとめ |

普通の作業のresults.mdは基準のコミット・走らせたコマンド・終了状態・外側の時間と、計画からのずれ・申し送りだけを記す。失敗時は原因と修正を残す。結果を引用するときだけ07-03の全欄（HEAD・差分一覧・入力・構成・件数・元の記録・一致する理由・判断者と日付、別状態なら未コミット差分と未追跡入力のSHA-256）を保存する。一時的なtarget/のログだけを引用元にしない。

レビュー修正はまず同じ作業の完了条件へ戻す。追加の独立作業が必要なら実績の数へ加え、29件の見込みを超えることを隠さない。設計の変更、証明の不成立、見積もりの2倍超過の見通し、R14の範囲外の前提の追加、層ごとの全体ビルド不成立はR12に従って止めて設計者へ報告する。

## 段1の実施計画の保存

以下は段1実施時の記録である。段1完了後の順序・件数・検査は上の具体計画を正とする。段1末からの「後で設計する」という記述は当時の状態である。

## 段1の共通条件と作業数

依頼文の「共通の関門 K」は、以下の六項目を指す（decisions.md の実装時の判断 R1）。共通依頼文と計画の雛形は [docs/workflow/](../../workflow/implementation-request.md) に置く。段1の検査は引き続き本書の名指しを使い、RV1までは一般へ適用しない。

段1は次の4作業とする。W2は削減後も引数・work/stageとchange/releaseへの接続を一つで60分以内に終えるのが難しいため、W2aとW2bに分ける。文書の更新は続くW3へまとめる。表の時間は実装・整理・軽い自己検査を含む目安であり、冷えたキャッシュでの実Cargoの列挙とRV1の待ち時間は別に記録する。

| 作業 | 受け持つまとまり | 見込み時間 |
|---|---|---:|
| W1 | 長い対象の実行器・旧指定と引数なしの基準・実Cargoの列挙 | 50〜60分 |
| W2a | 引数の解析・旧指定の保持・work/stage・既定の切り替え | 45〜60分 |
| W2b | change/release・長い対象への接続・包含 | 40〜55分 |
| W3 | 規約・説明・共通依頼文・雛形と段1の照合 | 45〜60分 |
| 合計 | 4作業 | 180〜235分 |

設計は [design.md](design.md) を正とし、範囲外の機能は足さない。作業記録は `w1/results.md`・`w2a/results.md`・`w2b/results.md`・`w3/results.md`、段の集約はDの `results.md` とする。実績ファイルは各作業で作成する。

1. 本物のcheck.shの入口・出力・終了状態で契約を確かめる。test-auditの作成時の四問を記録し、代用するのはcargo・lake・check-heap.shだけとする。gitとpython3は本物を使う。
2. 既存13名のonlyとfullを保持する。引数なしもW1で改造前の基準を採るが、W2aではworkへの意図した変更を照合する。引数なしの集合まで旧形式と一致するとは要求しない。
3. W2aでコードの既定を切り替え、W2bの後のW3でAGENTS.md・07-03・07-04を実装へそろえる。RV1までは一般の作業へ新方針を適用しない。段1では01-12・formal/・Rustの処理系やテストを変えない。07-04は検査時期の説明だけを直す。
4. 対象はシェル・Python・規約と文書である。検査は下表へ一度だけ割り当て、Rustの全lib・clippy・全件の特殊構成を一律に追加しない。長い対象の列挙でビルドが起きることと、テスト本体の実行を区別する。
5. オーケストレータが走らせる検査を設計者へ知らせ、同じ基準と選択のdry-runを確認して走らせる。段1の具体的な選択は下表を使い、別の承認欄は設けない。まだ使えないlevel指定を実行した記録にしない。各作業で下表に割り当てた検査を実行し、結果を記録する。
6. 普通の作業は基準のコミット・コマンド・終了状態・外側の時間と計画からのずれ・申し送りだけを残す。失敗した場合は原因と修正も残す。結果を引用するときだけ design.md と 07-03 の全欄を記録し、関係状態が同じなら C8 に従って引用する。

### W1 長い対象の実行器と互換性の基準

以下は W1 実施時の範囲の記録である。一覧と列挙・個別実行は RV1 の中4を受けて Z1 で廃止し、現行の契約は design.md「長い対象の一括実行」と Z1 に従う。

- 目的: 長い対象だけを選ぶ実行器と、既存指定を保持するための基準を作る。
- 触るファイル: `scripts/check/run_ignored.py`・`ignored-tests.json`・`test_policy.py`・`fixtures/legacy-commands.json` を新設する。`scripts/check.sh` にはpolicy_selftestの名前と、check.sh・scripts/check/の限定した分類だけを加える。`w1/results.md` を作る。現行設計の改訂はW3へまとめる。
- 手順: 最初に改造前のcheck.shを一時Gitリポジトリで動かし、旧only13名・fullに加え、引数なしの文書・Rust・heap・分類不能・存在しない基準と各dry-runのコマンド・順序・終了状態を採取する。期待値は後の実装から作り直さない。四欄の一覧を作り、long/formalの分離、完全名の実行、0件・実行漏れ・失敗の検出を実装する。一時リポジトリの最低限のファイルと代用の境界はdesignに従う。自己検査の中で三つのシェルにbash -nを行い、policy_selftestを実際のcheck.shから実行できるようにする。
- 完了の条件: 長い対象・形式化の書き出し・通常の対象を混ぜてもlongだけを選び、未知・消失・重複・0件・実行漏れ・外部失敗を成功にしない。改造前の基準がそろう。実Cargoの四構成の列挙との一致をW1自身の契約として確認する。Rustのテスト本体とMiriは実行しない。具体的な検査は下表のW1行に従う。
- 依存: 後の実装開始の指示。本書の段1の設計。W2には依存しない。

### W2a 旧指定の保持・引数の解析・workとstage

- 目的: 既存の分類を保ち、作業末の検査と名指しの接続確認を一つの入口へまとめる。
- 触るファイル: `scripts/check.sh`、`scripts/check/test_policy.py`、`w2a/results.md`。AGENTS.md・現行設計・他のスクリプトの説明はW3で直す。
- 手順: work/stage、値と競合の検査、base、繰り返せるtest、dry-runを実装する。引数なしを直ちにworkへ切り替える。旧only/fullの実行部とclassifyを保ち、既存の種類からworkの単位を選ぶ薄い対応表を足す。stageはonlyを必須とする。libの局所検査は計画のCargoコマンドへ任せ、cargo metadataと通常テストの件数解析は作らない。bash 3.2・set -uの下の空配列も確認する。change/releaseはW2bで実装するまで未対応の値として終了2で拒否し、実行可能とは説明しない。
- 完了の条件: 旧only13名・fullと、それぞれにdry-runを付けた実行集合はW1の基準に一致する。引数なしはworkへ変わり、分類不能・基準不明のdry-runは3へ変わる。stageのonly欠落・局所対象の欠落は2、level+onlyは分類せず名指しだけを選ぶ。testの空・重複・不要な併用を拒否し、存在の判断はCargoへ任せる。workのlib・関連統合・clippy・fmtを重ねない。検査は下表のW2a行に従う。
- 依存: W1。RV1までは段1の指定で検査し、一般には使わない。

### W2b change・releaseと長い対象への接続

- 目的: 改造全体の回帰と、実際の公開候補の確認を分ける。
- 触るファイル: `scripts/check.sh`、必要な `scripts/check/` の道具・自己検査、`w2b/results.md`。
- 手順: 既存の種類からchangeへの対応を足し、Rustの全構成、doc・stress・lint、条件付きのheap_checks・formal_build・licenses・道具の自己検査を接続する。long_onlyとrelease_stackを実行器へ接続する（Z1 で構成ごとの一括実行と件数確認へ簡素化）。releaseは分類せず、Rustの変更がなくてもrelease_stackだけを自動選択し、候補と証拠の手動照合を求める。同一構成で包含できるlib・文書例だけを省く。dry-runの見込み時間は検査ごとの固定の文字列とする。
- 完了の条件: 四水準と旧指定の選択・非実行・失敗伝播がdesignの表に一致する。旧only/fullと各dry-runの互換性を維持する。changeの条件付き検査の漏れがなく、済んだ検査をonlyで除いて引用できる。releaseの成功を受け入れ完了とは表示しない。検査は下表のW2b行に従う。
- 依存: W2a。次のW3で規約を必ずそろえ、RV1まで一般には使わない。

### W3 規約・共通の依頼文・計画の雛形と照合

- 目的: 検査の入口・規約・依頼文をそろえ、以後の段で全件の反復を求めない形にする。
- 触るファイル: `AGENTS.md`、`docs/design/07-quality/07-03-compiler-testing.md`・同07-04、`scripts/check-heap.sh`・`scripts/check-formal.sh` の先頭コメント、`.claude/skills/test-audit/SKILL.md`・`.claude/skills/clean-build/SKILL.md`。`docs/workflow/implementation-request.md`・`change-plan-template.md` を新設する。必要な現在の呼び出し元、DのREADME・plan、`w3/results.md`・`results.md` もそろえる。git-workflow、archive、docs/todoは変えない。
- 手順:
  1. AGENTS.mdと07-03をworkの既定・条件付きの段・change・release・互換指定・終了2と3・結果の引用へそろえる。AGENTS.mdのscriptsの行の「--fullで全体の検査」「公開前は--full」「default_libを選ぶ条件」を、新しい水準と旧互換指定が分かる文へ直す。
  2. AGENTS.mdの表にdocs/workflow/の行を加え、共通依頼文と実装プランの雛形、check.sh・07-03と同じ変更で保守すること、改造のディレクトリへ写して使うこと、docs/todoへリンクしないことを書く。scripts/check/の行も加え、検査方針の自己検査と長い対象の一括実行と件数確認の場所を示す。「改造の進め方」の2に雛形を写して使う一文を加える。
  3. 07-04と二つのスクリプトの説明は検査時期だけをそろえる。Lean先行、01-12との対応、証明の保証と実行集合を変えない。check-heap.shは分類不能、check-formal.shはformalという分類を保つ。
  4. designの共通依頼文と雛形を移す。作業末はworkがあればcheck.shを一度、なければ計画の直接のコマンドとする。作業の検査は割り当て表のwork行にだけ置く。docs/workflow/の指定はW2で実装済みのものに限る。
  5. test-auditの「確かめる」を当該水準の計画へ合わせ、作成時の関門は保つ。clean-buildへ生成物と検査記録の区別を加え、削除の規則は変えない。rgで現在使うonly/fullと過去の実装プランの共通の検査の節の複写を調べ、実装した指定と矛盾する説明を直す。
- 完了の条件: 文書のリンク・表・差分と実装した指定が一致する。下表のW3行と段末の期待表で道具と規約の接続を確認する。W1 の列挙は当時の実装の確認として保持する。Z1 で一覧と列挙を廃止し、現在の実行方法は Z1 の自己検査で確かめる。重い検査は段7へ割り当てたままとする。
- 依存: W2b。RV1のレビューと指摘修正を終えて段1を閉じる。

### Z1 RV1 の指摘修正

- 目的: 中1・中3・中4と軽1〜7を修正し、長い対象の実行と普通の作業の記録を簡素化する。中2・軽6の一覧に関する指摘は一覧の廃止で解消する。
- 範囲: check.sh と scripts/check/、AGENTS.md・07-03・共通依頼文と雛形、移行器の README、D の design・plan・decisions。Rust・Lean・docs/todo は変えず、コミットしない。
- 判断: decisions.md の R5。long_only は構成ごとに一回の Cargo 呼び出しと成功1件以上、release_stack は名前の前置きと成功10件を要求する。work の heap に doc_default を追加し、examples のビルドは change で行うと明記する。
- 完了の条件: 停止時の案内・誤指定の理由・分類・件数と失敗伝播が自己検査で通り、文書と実装が一致する。RV1 の全文を reviews/R1.md、結果を z1/results.md に置く。検査は次の表の Z1 行だけを作業末に一度実行する。
- 基準: `d281836fdaea44c1bee31b7eba36495b3a8b62f8`（W3 の取り込み後）。

### 段1の検査の割り当て

`<直前>` は前の作業の取り込みのコミットを指す。W1だけは段1開始版を使う。段1開始版は実装を始めるときのsan_benitoの完全なコミットIDとして固定する。各行のcheck.shは、同じ指定へ `--dry-run` を付けて確認してから一度実行する。policy_selftestの直接実行や別のbash -nは重ねない。

| work | コマンド・対象 | 期待する結果 | 担当・見込み |
|---|---|---|---|
| W1 | `scripts/check.sh --base <直前> --only policy_selftest`。続いて当時の四構成の列挙（記録は w1/results.md） | policy_selftestだけを一度実行して0。実Cargoの列挙が一覧に一致し0。本体は実行しない | オーケストレータが知らせて実行。自己検査と列挙の実績は w1/results.md |
| W2a | `scripts/check.sh --level work --base <直前> --only policy_selftest` | policy_selftestだけ、分類しない。終了0 | 同上。数秒〜1分 |
| W2b | `scripts/check.sh --level work --base <直前> --only policy_selftest` | policy_selftestだけ、分類しない。終了0 | 同上。数秒〜1分 |
| W3 | `scripts/check.sh --level work --base <直前> --only policy_selftest`、文書のリンク・表・差分の確認 | policy_selftestだけ。シェルの説明の変更にも構文検査が掛かり0。文書に矛盾とリンク切れがない | 同上。1〜3分 |
| Z1 | `scripts/check.sh --level work --base d281836fdaea44c1bee31b7eba36495b3a8b62f8 --only policy_selftest`、変更文書のリンクの確認、`git diff --check` | 自己検査と三つのシェルの構文が成功。変更文書にリンク切れと空白の誤りがない | 実装担当。1〜3分 |

W1 の四構成の列挙は実施済みの記録として w1/results.md に残す。Z1 は一覧・列挙を廃止するため、旧 `--list-only` を再実行しない。Rust・Lean のテスト本体と Miri も実行しない。

## 段1末の検査と Opus のレビュー

段1では道具と規約が初めて接続するため、C3の確認を行う。実行する検査は `scripts/check.sh --level stage --base <段1開始版> --only policy_selftest` と文書の照合である。最後の Z1 で同じ接続まで確認済みなら C8 の根拠を記して引用し、再実行しない。W1 の旧一覧の列挙は Z1 の新方式の証拠には引用しない。Rust・Leanのテスト本体とMiriは実行しない。

次表は、段1全体の差分に対するdry-runの期待である。基準は全行で段1開始版とし、check.sh・scripts/check/、check-heap.sh・check-formal.shの説明、規約・スキル・docs/workflow/・Dの文書を変更した状態を使う。check-heap.shは分類不能のままなので、自動選択のwork/changeは意図どおり停止する。名指しの入口で段1を検査したことを結果に記す。この終了3は停止の契約を確かめる予定した観察であり、実行する検査は前節の名指しに従う。

| 指定（共通の `--base <段1開始版> --dry-run` に追加） | 期待する検査名 | 停止・終了状態 |
|---|---|---|
| 指定なし／`--level work` | 停止前の既知の集合はpolicy_selftest・formal_build。分類不能の印はcheck-heap.sh | `== stop:`、3。検査を実行しない |
| `--level work --only policy_selftest` | policy_selftestのみ。分類しない | 停止なし、0 |
| `--level stage --only policy_selftest` | policy_selftestのみ。分類しない | 停止なし、0 |
| `--level stage` | なし | 指定の誤り、2。設計者への選択の質問を出さない |
| `--level change` | 停止前の既知の集合はpolicy_selftest・formal_build。分類不能の印はcheck-heap.sh | `== stop:`、3。Rust全件を選ばない |
| `--level change --only policy_selftest` | policy_selftestのみ。引用・部分選択と表示 | 停止なし、0 |
| `--level release` | release_stackのみ。Rustの変更がなくても選ぶ | 停止なし、0。手動の候補照合を別に要求 |
| 水準なしの `--only policy_selftest` | policy_selftestのみ | 停止なし、0 |
| 水準なしの `--only rust` | rust（fmt・両lint・heap-verifyのworkspace test・gc-stress・規約）、そこからSkill再生成と仕様集計。W1の旧rustの基準と一致 | 停止なし、0。実行はしない |
| 水準なしの `--full` | rust・default_lib・long・release_stack・licenses・spec_examples・spec_coverage・reference_examples・skill・skill_eval・python。W1の旧fullの基準と一致 | 停止なし、0。実行はしない |

dry-runは選択の確認であり、列挙・long_only・release_stack・旧fullの本体の成功には数えない。段1を終えた時点では、その道具の契約だけを確認したと記録する。0.0.8全体のchange、必要なheap/formal、候補のreleaseは段7の担当へ残す。

RV1のOpusレビューでは次を確認する。

- C1〜C14と今回の簡素化が一致し、作業末は一度、全Leanは段2で先行するか。
- 旧only/fullと各dry-runの実行集合がW1の独立した基準を保つか。引数なしのworkへの切り替えとdry-runの停止3が意図した変更として扱われているか。
- 既存のclassifyを保ち、水準への対応だけを足したか。changeの条件付き検査、skill_docs、lint_heap、文書例の包含に漏れがないか。
- 指定の誤り2、分類不能・基準不明3、level+onlyで分類しない規則が、実装・依頼文・規約で一致するか。
- 未コミット・未追跡・削除・改名、入力の利用側、引用後の変更を扱えるか。長い対象はW1で実Cargoと照合済みか。
- releaseの終了0を受け入れ完了とせず、Lean先行・ヒープの局所検査・分類不能時の設計者の選択を保つか。

指摘を直したら、変わった契約の自己検査と文書照合だけを再実行する。実行器の対象を直したら必要な実Cargo列挙もやり直す。RV1の完了と切り替えの記録の後、段2以降の詳しい設計・実装プランを作る。


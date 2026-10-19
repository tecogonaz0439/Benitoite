# P2: RV1の指摘の反映

## 範囲と基準

2026-10-18、ブランチはmod009/design、開始版は`8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3`である。開始時の作業ツリーに変更がなく、処理系の基準`6b0568a3ddcc46b0a0e64504139ce286a27fd86a`からの差はD内の文書22件だけであることを確認した。design.md・plan.md・decisions.md・implementation-request.md・README.mdを修正し、本書を追加した。レビュー本文RV1.mdは保ち、処理系・現行設計・テスト・formal/・docs/todo/へ書き込まず、コミットしない。

AGENTS.md、00-01、07-03の四水準と結果の保存、07-04の内外・Lean先行、docs/todoのTODO-250を読んだ。試作の142/022/164/248のfindings、Scope・Intervals・Dictionaries・LocalBuilder/Escape等の定義と限界を確認した。前回のREADME/decisions/plan/results/reviews/studyの構成と、L2bが450〜900分へ改訂されL2bc4まで続いた記録を参考にした。過去の証明やレビューの成功を今回の検査の成功とは数えない。使用スキルはjapanese-tech-writing・rtk・test-auditである。

## 指摘ごとの対応

14件をすべて採った。不採用の指摘はない。以下の文書の節・作業IDはD内、コードのパスはリポジトリの根からの相対表記であり、読み取りで確認した。

| 指摘 | 自分で確認した根拠 | 判断・反映先 |
|---|---|---|
| 重1 | formal/Benitoite/Surface/Desugar.leanのpartialCall/partialCon、Typing.leanのE_PartialCall/E_PartialCon、Check.leanの同分岐、Release/Lemmas/Rename.leanのRenOk.up。Rustのresolve/walk.rsのCall、typeck/calls.rsの部分適用の潜在効果、ir/desugar/exprs.rsのplaceholderは本体の中でcallee/固定引数を評価する | R131、R123の境界の訂正、design 7.2・13・14.5・15.5、plan L4a/b・L6・L7・B1〜B3、依頼文。部分適用は空Δ、E0465、no_captureはコアのlam/lazyC/節の自由なセル参照の不在について述べる。固定引数/callee/partialCon/タスク用関数への引き渡しの負例と先行copyの正例を割り当てた |
| 中1 | Surface/Typing.leanの七判断・公開abbrev・Def/ImplDecl/Program.WellTyped、CheckSound.leanの公開11件。Rustの型付き表層からの書き出しはdesugar_exportの読者である | R132、design 14.5、L4a/L6/L7・RV2。ΔはQ直後、公開abbrevは[]。WellTypedの文字列の変更をl4a/resultsへ残し、congrΔと旧構文のΔの任意性で意味を機械的に確かめる |
| 中2 | Lemmas/Typing.leanのHasTypeQ/HasBlockQ.desugar、Check.leanのR/Q/公開の三層、CheckInduction.leanとCheckSoundControl.leanのmutualSoundness、前回のL2bの計画と結果。Rust接続の前に全Leanを閉じる依存を再点検 | R133、R112/R113/R117の現行案への導線、plan L4a/b/c・依存/検査/レビュー/見積もり表、README・依頼文。全体ビルドを保つ三作業とし、帰納の一般化をL5へ持ち越さない。Z/Aで始まる作業IDは使わない |
| 中3 | Release/Typing.leanのV_Prim/V_Fun、Surface/Typing.leanのE_Prim/E_Fun、Release/Admissible.leanのof_noRows、Assumptions.leanのref_get/ref_setとrefNew存在の欄の不在、Surface/Lemmas/CallHead.leanのfunDecl_desugared。既存RustのReference/純粋な連結への展開との対応を確認 | R134、design 14.5・L3。種類別Refsと、宣言の存在/種類/名前/型/効果、辞書なし・行なし・Scoped・許容条件・SingleTyまで列挙。脱糖が構文から種類と型引数を決め、refNewの存在を仮定へ追加しない |
| 中4 | Lemmas/Typing.leanのEnvClean、CheckSound.leanのEnv.AtomsIn、CheckInduction.leanのExprSound等。Rustの専用分類を通常Tyへ入れず公開空Δへ戻す設計と照合 | R135、design 14.5・L3/L4b/L4c/L5/L6・RV2。Aligned/Clean/AtomsIn/Singleを内部の前提に限定し、束縛・境界で保存する。公開11件に前提を追加しない理由を[]の成立で示す |
| 中5 | formal/lakefile.tomlのdefaultTargets、formal/SurfaceCheck/Walk.leanのwalkExprの既定分岐とwalkBlockの網羅的分岐、Surface/CheckPredicates/CheckSupport/CheckSoundSequence。後のRust出力をsurfaceCheck二入口が読む接続も確認 | R136、L5/L6の触るファイルと完了条件。専用操作の引数/宣言の本体を明示的に辿り、既定分岐も含む全読者の対応をresultsに残す |
| 中6 | Surface/Typing.leanのE_HandleFailと節、Surface/Lemmas/SubstClean/ShiftClean、Release/Lemmas/Rename.lean。表層にExpr.rename/substがなく、型束縛の節では空Δになる点を確認。Rustは既存renameによる合成letの下の移動を保つ | R137、design 14.5・L3/L4b/L6。kind/fillのshift/代入の交換とbuilders_scoped_rename/substを外し、fillBuilders_hideContsとaligned_hideContsへ置き換えた |
| 軽1 | formal/README.mdの#print axiomsの一覧、formal/lean-toolchain、同版Leanの同梱Init/Core.leanのofReduceBoolとnative_decideの説明。Rust側の変更は不要 | R138、planの検査の割り当てとRV2、依頼文。L1変更前の出力を固定し、各Lean作業で同じ一覧を比較する。具体例はdecide/omega/simp等で閉じる |
| 軽2 | Surface/Typing.leanのE_TryResultDie/E_TryOptionDieとガードはhideConts・R=none・Eff.emptyを使う。Rustで説明をその場で評価するir/desugarの経路とも照合 | R139、design 7.2/14.5とL4a/b/c。説明・ガードは同じΔ、通常束縛のnoneを加え、hideContsの交換を使う |
| 軽3 | 試作Scope.leanのポートはNat、現行RustにはScope APIは未実装。design 3.1のScopeErrorと失敗順を14.2の言明案へ照合 | R140、design 14.2・L1。invalidPort_iffと負数/70000の区別、outside_iffの前提を追加。実APIとの照合はK3 |
| 軽4 | Surface/Typing.leanのDictEv.HasType.local/clauseとE_Resume、Exchange/Version.leanのvalidateConstantBody。Rustのdesugar_export/named.rsのlocalと交換経路 | R141、design 14.6・L7/B3。構築器宣言をまたぐ辞書/resume/depth/Γ.lengthの手計算と番号の誤りの負例、定数本体のbuilderBind/builderOp拒否を追加 |
| 軽5 | Releaseの型適用/代入、表層の例、Rustのtraits/collect.rsのarityとtraits/tests.rsの既存例、試作Dictionariesの独立性 | R142、R119・L2・見積もり表・README/依頼文。3〜6時間に増額し、Ty.WF/SatAllの区切りで再評価する |
| 軽6 | Checked/ResultLawsは追加予定で既存のSurfaceの主定理から独立。試作のimportとRust/.bntへの未接続、07-04の対応表の役割 | R143、design 14.1・L1/L2・依頼文。小証明と独立期待値との照合、本体の判断へ接続するMonad2Examplesを写しでも区別する |
| 軽7 | L5ではbuilderOpだけ、L6でbuilderBindを追加する依存。公開入口[]では操作対象を得られず、Rustへの接続はさらに後である | R144、L5/L6・依頼文。01-12/07-04の写しに中間状態の一文を置き、L6完了時に消す |

test-auditの作成時の関門は、追加する負例の計画にも適用した。守る契約は関数値への外側セルの捕捉の禁止であり、現実的な退行は普通の部分適用のcallee/固定引数へ外側のΔを渡すことである。既存の0.0.8には構築器がなく、従来のlambdaだけの負例やReferenceへの型保存ではこの漏れを捕まえない。Rustの主な観察はCLIのE0465と対応する受理例、Leanは規則とコアのno_capture、交換は共有番号の誤りを担当し、同じ主張を各層で重ねない。差し込み口や本番のコードは追加していない。今回はテストの実装・実行も行っていない。

## 作業と見込みの変更・申し送り

| 対象 | P1 | P2 |
|---|---|---|
| L4 | 1作業、4〜8時間 | L4a 2〜4、L4b 3〜6、L4c 1〜2時間の3作業、計6〜12時間 |
| L2 | 2〜4時間 | 3〜6時間 |
| 段1 | 7作業、22〜44時間 | 9作業、25〜50時間 |
| 計画上の全作業 | 28（残り26） | 30（残り28）。準備のP1/P2と5回のレビューは別枠 |
| 残りの能動作業 | 86〜154時間 | 89〜160時間 |
| 検査待ち・レビュー・本測定を含む計画枠 | 約100〜188時間 | 約103〜195時間 |

残りの一覧はL1・L2・L3・L4a・L4b・L4c・L5・L6・L7、T1〜T3、K1〜K4、M1、B1〜B3、G1〜G4、H1〜H3、V1である。見積もりは未実測であり、今回の文書作業の時間は将来の実装へ加算しない。L4a/b/cの個別の上限や2倍の相談基準、全体ビルドが閉じない場合の停止点も明記した。

設計者への追加の確認事項はない。R109・R112は回答済みのまま保ち、今回依頼された分割と見積もりをR133/R142で改訂した。主定理の前提・結論、公理、Builtins.Assumptionsの追加が必要と判明した場合の「設計者に確認」の停止条件は維持する。実装開始の指示と、今後の証明・Rust接続・RV2以降の検査は未実施である。

## 文書の照合と検査

planの「各作業のwork」のP2行に従い、文書の対応・リンク・作業ID・時間集計・変更範囲を照合した後、同じ開始版でdry-runと文書だけのworkを行った。Lean/Rustのビルドや実装テストは実行していない。

| コマンド・照合 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---|---|
| 読み取り用Pythonによる6文書の照合 | 0 | 最終の照合0.103921秒 | ローカルリンク196件（見出しも含む）、30作業とwork行、残り28作業の89〜160時間・Lean9作業の25〜50時間、R101〜R144の連番、68問の回答の不変、14指摘の対応、変更6文書を照合 |
| `git diff --check`と差分・HEADの照合 | 0 | 単独の時間は未計時 | 空白の誤りなし、指定の5文書と本結果だけを変更。HEADとブランチを保ち、RV1.mdは開始版の内容とバイト単位で一致 |
| `scripts/check.sh --level work --base 8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3 --dry-run` | 0 | 次のworkと一括で約0.2秒 | 変更6件を文書だけと判定し、実行する検査なし |
| `scripts/check.sh --level work --base 8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3` | 0 | 上の一括時間に含む | 同じ指定で作業末に一度実行。`selected checks passed` |

文書照合の初回は、読み取り用スクリプトが見出しの「・」をアンカーから消すため終了1になった。既存リンクの不具合ではなく、アンカーの作り方を直して文書を変えずに終了0を得た。執筆全体の時間は計時しておらず、実装の見積もりへ混ぜない。

work後の変更は本節の結果の追記だけである。この文書作業の成功を、Leanの証明・既定ビルド・Rustの実装・交換・性能の成功へ転用しない。計画からの範囲の逸脱はなく、次への申し送りは上のL1以降の担当と停止条件のとおりである。

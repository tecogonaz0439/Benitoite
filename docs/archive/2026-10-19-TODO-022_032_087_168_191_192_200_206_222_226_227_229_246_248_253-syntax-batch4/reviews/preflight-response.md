# 0.0.10 の事前点検の指摘への対応（P1）

2026-10-19。[preflight](preflight.md)の重1・中4・軽10、計15指摘をすべて反映した。点検本文は変更しない。本書は文書の修正記録であり、Leanの証明・処理系の実装・性能目標の達成を示すものではない。基準はP1開始時HEAD `f4a8bec2fb5a746ca80487a60355f1a34b797bd5`、ブランチは`mod010/design`である。

設計者の回答は中1=案A、軽2=推す案、軽10=preflightとは別にRV1を行う、の三点である。その他の追加判断は[decisions](../decisions.md)の推す案として記録し、回答済みとは扱わない。採らない指摘はない。

## 指摘ごとの対応

| 指摘 | 対応の要約 | 修正先・判断 | 実装時に確かめること |
|---|---|---|---|
| 重1 | コアも表層と番号を共有。builderLetはΓにnone・Δにsome k、通常束縛はΔにnone。bound i=var iの番号とし、環境対応を恒等にした。σ/ρの置換を既存補題へ統合し、射影の補題を除いた | design 3.3・12.2/12.4、planの内部契約・L3/L4・区切り、decisions R101/R111/R117、依頼文 | 脱糖の六関数に環境を足さず型保存を閉じる。RustのBuilderIdの区別は保つ |
| 中1 | 種類ごとの論理上限をLeanにも置き、BuilderCellOkへ含めた。append/appendAllの超過は内容不変のR0902相当のerrorの一歩、lengthは上限から有界定数を作る | design 12.2、plan L3・内部契約、R121、依頼文。設計者の案A | 進行・保存・無事象で超過も扱い、主定理とBuiltins.Assumptionsの形を保つ |
| 中2 | lam/lazy/節と通常値に入る計算、CellOkのthunkを空Δ・Ψ.hideBuildersで検査。元のΨへの弱化を足し、通常値の非出現を導く根拠にした | design 3.3・12.2/12.3、plan L3・内部契約、R118、依頼文 | 自由なboundだけでなくlocの捕捉も禁じる。内側の新しい構築器は受ける |
| 中3 | Expr.Exitsのblockの場合を明記し、全相互帰納とcheckerへ通す。末尾のblock内でreturnするラムダを受理の例にした | design 12.6、plan L5、R123、依頼文 | Rust/Leanの受理一致。E0439はRustの外側の検査 |
| 中4 | B2/B3/G2のworkからheap_local/stress_localを外し、全統合は既定構成だけにした。特殊構成は局所libと名指し統合の直接Cargoへ分けた。T4のgoldenのstress時間は実装時quick後に更新する | planのwork・補完・見込み、R124、依頼文 | 全統合の特殊構成を三作業で重ねない。局所GC/doc/check-heapは次作業の前提として残す |
| 軽1 | OrdinaryStoreEqをReferenceの.valセルだけの比較へ限定。drop_local_silentをreleases k'=[]かつσ'=σ.set κ .usedの形へ直した | design 12.2/12.3、plan L3、R119 | 遅延のメモ化・継続のused更新を不変と主張しない |
| 軽2 | 正の整数はmax64以下、直接負号は2^63以下の証明を構文へ持たせ、交換の読者で作る。型付けへ前提を足さない | design 6.2・12.5、plan L1、R120、依頼文。設計者の選択 | toConst/toCore/脱糖の全域性と旧交換の範囲拒否 |
| 軽3 | L1へCoverage/Model/Examples・Desugar・Surfaceの例・Exchange・CoverageDiffなどConst.integerの全読者を列挙した。Coverageの旧期待はL1で保ちL2で変える | plan L1、R125、依頼文 | 既定importを外さずL1単体でビルドを保つ |
| 軽4 | refs/BuilderRefs/refs.OkをL4で除き、L7の版判定をcorpus 8〜13・sidecar 2〜5へ具体化。13→5、11/12→4、旧版の構築器は再生成要求、構築器なしは範囲検査後に受ける | design 12.8、plan L4/L7/B2、R122 | 既存test_*_exchange.pyの旧版の受理/拒否、B2のtests/desugar_exportの版切り替え |
| 軽5 | G6へcheck.shのglob/分類/dry-run、source-migrateのREADME、try-actionsの除外一覧、07-03とAGENTSを必須の対象として加えた | plan G6、R126 | 消えたglobが残らず、policy_selftestで三つのシェルの構文も通る |
| 軽6 | B2内に既定経路を保った追加段階と、続きb2c2の一度の切り替えを定めた。未接続の追加だけでは完了にしない | plan B2・見込み、R127、依頼文 | 各区切りのビルド/局所検査と残る全読者をresultsへ引き継ぐ。作業数は増やさない |
| 軽7 | T1の対象にsrc/typeck/limits.rsを追加し、既存予算と三つの新しい上限を同じ場所で扱う | plan T1、R128 | R102の計数/上限と確保前の判定を照合 |
| 軽8 | 三つの標準構築器の先頭説明をB2で新規則へ直し、同じ変更でgen_skillを作り直す | design 13.3、plan B2、R129 | 生成SkillにState必須の古い説明が残らない |
| 軽9 | 現在のB_WORKをP1開始時HEADへ更新。L1はsan_benitoへの取り込みの完全IDを取りまとめが直前に差し替えると明記 | planの基準表、依頼文、README、R130 | B_CHANGEと処理系/formalの差分と実際のブランチも照合 |
| 軽10 | preflight実施済み＋RV1〜RV5未実施とした。P1後のRV1を別に行い、L1の先行条件として残す | planの段/レビュー/時間、README、依頼文、R131。設計者の回答 | preflightをRV1の代わりに引用しない |

## 作業数と見込み

26作業を保つ。L1は2〜4から3〜5時間、L3は10〜20から12〜24時間、B2は5〜8から6〜10時間へ改めた。L4は環境の射影を除き8〜16時間を保つ。実装計は65.5〜123から69.5〜130時間、残りのRV1〜RV5・取りまとめ込みで75.5〜145から暫定79.5〜152時間となり、ともに4〜7時間増える。

preflightは済んだ別枠であり、実測時間の記録はない。残りのレビューは従来どおり5回・5〜10時間である。T4のgoldenを含むstress検査とB2/B3/G2の局所検査、全targetsは未校正であり、実装時の試走後に見込みを更新する。今回その試走は行わない。

## RV1で特に確認する点

1. 共有番号・σ/ρの置換・空Δの公開入口と、環境を取らない脱糖の整合。射影を除くことで性質1の保証を保てるか。
2. hideBuildersでlam/lazy/節とthunkの自由なlocを禁じる規則、および弱化・置換の補題が循環せず閉じるか。値の判断にはΔを足さないこと。
3. BuilderCellOkの論理上限、R0902相当のエラー、lengthの有界性と、Referenceだけの不変/継続のused更新の言明。主定理とBuiltins.Assumptionsの意味を弱めていないか。
4. 証明付きの整数構文とL1の全読者、Exitsのblock、交換13/5と旧版拒否の範囲が十分か。
5. B2の追加段階からb2c2へ渡す区切り、全統合と局所特殊構成の分担、未校正の時間と実装前の停止条件が妥当か。

設計者への追加の必須質問はない。R117以降の推す案はRV1の確認対象とし、主定理の変更・仮定の追加・第二の重い形式化・区切りや見込みの大幅な増加が実際に必要になった場合は、従来どおり設計者へ戻す。L1前の基準の差し替えは取りまとめの作業である。

## P1の文書確認

変更はdesign・plan・decisions・implementation-request・READMEと本書の6文書に限る。bench-targets.jsonの166点・55目標と入力/指標/比率は指摘への対応で変わらないため、変更しない。処理系・現行設計書・テスト・formal/・docs/todo/と既存のarchiveは変更せず、コミットしない。

| 確認 | 結果 |
|---|---|
| 文書の照合（Pythonによる一時的な確認） | 終了0。26作業とwork行の一対一、見込み69.5〜130時間の合計、R番号の重複なしとR117〜R131、15指摘の対応、125か所のローカルリンクと見出し、非公開へのリンクなし、空白とコードブロックの対応、変更6文書を確認した |
| 点検本文と目標JSON | HEADとバイト単位で同じ。SHA-256はpreflight.md=`d87bb358817ea888b52a2594db8615329e1590c9a749a02c348d0481e9035dd8`、bench-targets.json=`88f5fcf22f57dcc273f4870ff0efd0b3c7fceaea4ce29a77d2c760bd8b0696ac` |
| plan末尾で指定したP1のwork＋dry-run | 終了0。変更6文書、文書だけ、選択する実行単位なし |
| 同じ指定からdry-runを外したwork | 終了0、外側0.077秒。作業末に一度実行した。Rust/Leanのビルド・テストは選ばれていない |
| 差分の空白 | git diff --checkは終了0。未追跡の本書の行末空白も上のPythonで確認した |

work後の変更は本記録の追記だけであり、選択する実行単位を変えない。将来の実装・証明・測定の成功へ引用する記録ではない。

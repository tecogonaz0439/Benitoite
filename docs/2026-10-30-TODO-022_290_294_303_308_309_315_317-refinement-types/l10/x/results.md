# L10 群 X の実装結果

2026-11-01。L10.14〜L10.20の担当範囲と、RV-L10.x の中1・軽1〜5の処置を完了し、修正箇所の確認へ渡す。L10.21には進んでいない。全7単位の義務の照合は [obligations.md](obligations.md) にある。[独立レビュー](../../reviews/RV-L10.x.md) は条件付き可であり、今回の処置はその6件に対する担当の完了判定である。修正箇所の独立確認と設計者の受け入れを代行しない。

ブランチの指定は `m014/l10.x`、B_WORKは `efbc8ebf58b0a64320f375e663ad929a29e73e86` である。gitの操作による照合・切替・作成・コミットは行っていない。[source-state.json](source-state.json) に、変更したソースと規範の開始時・完了時のSHA-256、検証入力、主な定理を持つ不変のファイルを記録した。処理系、plan、detail、既存のレビューの記録、rv-l10-t1/t2は変更していない。指定された旧パス `formal/Benitoite/Release/Patterns.lean` は現行に存在せず、実体の `Release/Refinement/Patterns.lean` を照合した。

## レビューの所見ごとの処置

RV-L10.x の全文と末尾の「取りまとめの追記」を読み、中1・軽1〜5を処置した。レビュー原本と補助入力 rv-x-t1〜t4 は変更していない。

| 所見 | 判定 | 処置と確認 |
|---|---|---|
| 中1 | 完了 | `ValueShapeMeaning.scoped` に `ScopedValue ix v` を要求。添字と成功値の3形を結ぶ。`ScopedValue.covers/forget` と `ValueMeaning.scoped_covers/scoped_forget` を本番で証明。境界では G09 の完全署名を scoped_forget へ特殊化し、旧反例の unit の排除、成功値3形、変数添字への checked の混入の否定を証明。01-12・07-04・signatures の決定1/11を同期 |
| 軽1 | 完了 | G03 に `PatTy`・`AltsTy`・`Exhaustive` の型置換、旧 `Exhaustive.substAt` に当たる義務を申し送った。値置換・移動の既存証明で閉じた扱いにはしない |
| 軽2 | 完了 | G06 の束縛の型保存を、`v : a.norm` を入力とし `δ.map Ty.norm` を結論とする形で申し送った。raw な束縛型へ戻すには形成の証拠が要る |
| 軽3 | 完了 | L70/R10b に Rust の束縛型と `P_Var`・`P_Refined`・`P_Convert` の照合を追加 |
| 軽4 | 完了 | [terminology.md](terminology.md) に value interpretation / information order と日本語の関連用例、確認の限界を記録。用語集から新語「値の意味」「観測の情報の順序」を除き、判断名 `ValueMeaning` と原語 information order に替え、取得できた一次資料の出典を添えた |
| 軽5 | 完了 | detail X1 と10規則の記述との差を本書に明記。未実装契約 `inhabits_of_typed_raw` の不要な WF を外した。rv-x-t4 の開いた入口の実例と rv-x-t1 の値依存の等号の負例を boundary へ写した |

今回の本番ソースの変更は `ValueMeaning.lean` と `ValueMeaningInhabits.lean` の2ファイルである。`Inhabits`・`Exhaustive`・`PatTy` を定義する Patterns と、主な定理などの保護対象は再開前からハッシュ不変である。`valueMeaning_sub` に値の型付けなどの新しい前提は加えていない。一般の場合の証明は G09 に残す。

## 単位ごとの完了の判定

| 単位 | 判定 | 閉じた定義・補題と証拠 |
|---|---|---|
| L10.14 | 完了 | `selfObservation`・`selfModel`・`RefinementPossible`、falseの確定だけを除くrefined、checkedAtOpaque、P_Refined、正規形のExhaustive、ValueMeaningの相互四族と、scoped の意味を限定する ScopedValue。B/Γ/Φの引数の追加は0 |
| L10.15 | 完了 | 内部slotのInfoLEと反射・推移・反対称性、位置/数/sort、鍵の確定コードとMap/Setの大きさ、Term.observe_mono・Pred.evalWith_mono。部分的なtermBind?と既定値を持つtermBindを分けてbind_observe_infoを証明し、close_preserves_decidedを導出 |
| L10.16 | 完了 | 有限連言の可能性と二値の真、true消去とrefineNorm、Inhabitsの正規化、関数畳込みと子型、ValueMeaning.norm_iff。要求されたWF付きのInhabits.norm_iffを残した |
| L10.17 | 完了 | 全型の述語の反映とInhabits.subst_values_reflect_normal、所属の値・型の移動、Exhaustive三本、PatTy/AltsTyの値置換・値移動・型移動。無条件のof_coreとcoreだけで篩へ戻すof_subst_values_coreを廃止。AtPatterns・MatchFacts、C_Match四枝とguard/matchの読者が通過 |
| L10.18 | 完了 | ValueMeaningの全子値と最外の全述語の真、valueMeaning_inhabits_normal。valueMeaning_refineがpとcarrierの事実/Γ/Φの真からEntails.soundでqの真を返す。HasTypeVQ.sub_refine_representativeが実際のV_Subと意味の双方を構成。全導出の帰納はG09に残す |
| L10.19 | 完了 | month_exhaustive・empty_refinement_exhaustive・nonempty_exhaustiveが実際のmatchValへの照合を証明。観測不能な関数を持つListを含む。boundaryのunknown_not_exhaustive・strong_kleene・unknown_with_false_excluded・month_13_excludedで偽の除外を否定 |
| L10.20 | 完了 | 任意のInt nについてlength_refinement_representativeが等号の篩と非空の篩をV_Refineで構成し、length_refinement_coverageが同じ非空型の網羅性を渡す。任意の正のk個のラムダを実際に型付けするunobservable_length_coverageも閉じた。開いた有限Entailsの入口、Capture.meaning_coverageの反映、CaptureOk.variable_coverageの型付き捕捉の代表を証明 |

新しい8モジュールは `CoverageRefinement` の依存として既定の `Benitoite` から読む。01-12・07-04・用語集を同じ変更で更新した。01-specのtextブロックは変えていないので、spec_examplesは実行していない。

## 場合の数の予定と実際

| 対象 | 予定 | 実際と照合 |
|---|---:|---|
| Inhabits/InhabitsAll/InhabitsEach | 28 | 24+2+2=28。refinedの前提を変更しcheckedAtOpaqueを追加 |
| PatTy/PatTys | 10 | 9+2=11。P_Refinedに加え、正規形の等号で移すP_Convertを補助契約として追加 |
| ValueMeaningの四族 | 四族 | 1+23+2+2=28。dataの全欄とListの全要素は完全な意味を要求 |
| ScopedValue | レビューで追加 | 3。fixed の checked/checkedRequest、任意の添字の checkedAt。Covers と forget の両方で意味を移送 |
| 情報の順序の三族 | slot内部を含む | 5+2+2=9。反射・推移・反対称性と観測/評価の移送を証明 |
| Term/Pred | 全有限構文 | 20/14。And/Orは三値の3×3=9の組合せ、Notは3通りを含む |
| 型付けの相互14判断 | 76×4=304枝 | 値29・計算24を含む76構成子と、値移動・型移動・値置換・narrowingの4本。四つの本体ファイルは不変で、変更後の全importで再検査 |
| C_Matchの読者 | 4枝 | 上の四本が通過。B/Γ/Φの追加は0。guard/matchの状態の既存の読者も通過 |
| 網羅性の代表 | Month・空篩・非空List・値依存長 | 四種を実証明。Monthの整数とListの長さを有限の固定値だけに限定しない |

完全な構成子名は [case-matrix.tsv](case-matrix.tsv)、76行×4欄は [typing-transports.tsv](typing-transports.tsv) にある。304は新しく作った304個の証明ではなく、既存の相互証明の照合件数である。代表のforallの量化を、実行した具体値の件数へ置き換えていない。

## 補助の契約で決めたことと計画からのずれ

完全署名と全11項目の記録は [signatures.md](signatures.md)、Leanで確認した109の公的な定義・補題の完全な型は [signatures-output.txt](signatures-output.txt) にある。主な判断は次のとおりである。

1. `ValueMeaning` はInhabitsをIHにせず、正規形・全子値・最外の全述語の二値の真から作る。正規化によるconvertはnorm_idemを通す。
2. 情報の順序はslotの内部まで比較し、scalar・snapshot・構成子名・slotの位置と数を保つ。未知の鍵が確定した場合の符号と、既に確定した符号の安定性を区別する。情報の追加に対する全域のinterpretの無条件の不変性は仮定しない。
3. 所属の値置換は、coreの形を反映する補助と、全型の述語の確定値を反映する補助を組み合わせる。`reflect_subst_core` の結論はa.coreに限り、篩へ戻すには全述語の可能性を要求する。
4. detail X1 は `a.norm.assume` と、不適格な継続型上の篩を正規化が消すことを記述するが、現行の `Ty.norm` はそれを消さない。この差を取り込み時に結果を正として注記する必要がある（detail 自体は変更していない）。ValueMeaningの事実を `a.norm.refinementPredicates` へ替えた。assumeは継続型の事実を空にするが、normは不適格な継続型上の篩を消さない。そのままではCont{false}の意味を空の事実から作れて所属への系が偽になる。適格な篩型では両列は一致する。主な定理へWFなどの新しい前提を足す案は採っていない。
5. PatTyにP_Convertを追加したため、予定10規則は11規則になった。`Integer{self==self}{self<=self}` において、P_Refined P_Varは途中の `Integer{self==self}` を束縛できる。値置換は篩を平坦化するので、元の10規則だけでは同じ束縛を導けない。boundaryのflattened_requires_conversionは実際のPatTyの導出についてこの点を示し、flattened_pattern/substituted_patternは変換後の導出を示す。P_Convertは正規形の構造の等号だけを読み、出力の束縛型も正規形にする。生の不適格な束縛型を正規形の入力へ渡す規則にしない。
6. Inhabits.norm_all_iffは実際の族について任意の型で閉じた。要求されたWF付きのnorm_iffは維持した。G09 の `inhabits_of_typed_raw` は `norm_all_iff` の系として WF を要求しない署名へ直した。無条件のcoreからの復元ではない。
7. 開いた長さの算術は有限のEntailsを受ける入口を置き、静的に非空型へ強めてから網羅性を使う。unknownで空Listを除く方法や、暗黙の実行時検査は追加しない。
8. 捕捉は、任意の開いた型の意味からの反映と、CaptureOkの実際の型付き像/条件による変数の代表を閉じた。任意のcloseValの型保存と全腕への接続はG09の担当のままとする。
9. レビュー後、`scoped` の意味を `ScopedValue` に絞り、範囲の拡大・忘却に対する意味の移送を閉じた。今回の補助契約の決定は signatures の決定11である。
10. 主なHasTypeVQ/HasTypeCQのsubst・subst_under_none・shift_values・shift_types・narrowの10定理の前提と結論は変えていない。Typing・StateTyping・MatchPaths・ClosedEvaluationとlakefileも不変である。新しい公理、提供範囲、利用者の書ける形の制限、精密な外部状態は追加していない。

途中の失敗は、assumeと全述語の違い、P_Refinedだけの移送の反例、P_Convertの束縛型の正規化、局所のLeanの型推論/停止性/構文の修正である。検証台本の最初の根の解決も訂正した。初回実装では最終のP_Convertへ替えた後、境界の変換先と正規化した束縛列を明示する必要があり一度失敗したが、境界を修正して再確認した。この初回の境界修正では成功した既定ビルドを保持し、境界から後を再実行した。今回のレビュー修正後は既定ビルドから全手順を再実行している。エラー時にLeanが表示した未完成の宣言を成功や許可した公理依存に数えていない。

## ビルドと公理依存

現在のソースに対する結果は [verification.json](verification.json) を正とする。検証台本 [verify.py](verify.py) はソース・入力と保護対象のハッシュ、lakefile の各 Lean のメモリ上限を先に照合し、既定ビルド、境界、完全署名、公理依存の順に実行する。失敗した手順を飛ばして再開することを拒む。今回の最終検証は全手順を先頭から実行した。

| 対象と実行 | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formalで既定の `lake build` | 0 | 42.640秒 | 全751ジョブ。sorryなし。既存の主定理やモデル、交換器をimportから外していない |
| `lake env lean -M 12288` でboundary.lean | 0 | 0.767秒 | 境界の全43宣言の公理依存も確認 |
| 同じ入口でsignatures.lean | 0 | 0.648秒 | 109の完全署名を出力 |
| 同じ入口でaxioms.lean | 0 | 1.941秒 | 変更した15モジュール全宣言と旧五主定理/三モデルの計1,359宣言 |

公理依存は `propext`・`Quot.sound`・`Classical.choice` だけであり、sorryAx・独自公理・未承認依存は0件である。[axioms-summary.md](axioms-summary.md) と二つのsummary JSONに集計した。184,818 bytesの公理依存の生の記録は一時領域へ保存し、[large-records.md](large-records.md) に大きさとSHA-256を記した。変更した全モジュールのprivate/生成した宣言も省いていない。先に通った63.935秒のビルドは補助の契約を直す前の記録として `build-initial-output.txt` に分け、現在の証拠へ混ぜない。初回完了時のビルドは53.610秒・公理依存は1,344宣言・境界33宣言であり、上表はレビュー修正後の結果である。

既定ビルドの各Leanプロセスは不変のlakefileの `moreLeanArgs = ["-M", "12288"]`、直接の各入力は `-M 12288` を用いた。RSSは未取得（計画上の非採取）である。workは取りまとめが実行する指定なので、dry-runも本実行も行っていない。RustとLeanの全比較、Rustの全lib、性能測定、LLMの呼出しも行っていない。

## 残りと送り先、群 W への申し送り

| 送り先 | 残る義務 | 見込み |
|---|---|---|
| 群W、L10.21〜.23 | Program/Def/ImplのWellTyped、Qの一致、WellFormedの定義。同じPのVarianceValidを供給し、ValueMeaningや型付け→所属を信頼する欄として追加しない | detailの1.5〜3時間を据置き |
| L20 G03 | `PatTy`・`AltsTy`・`Exhaustive` の型置換（旧 `Exhaustive.substAt` 相当）。所属の型置換反映を閉じ、正規化する `Ty.subst` に対して P_Refined/P_Convert を扱う | 不明（既存の担当枠） |
| L20 G06 | パターン束縛の型保存。PatTy P p a δ と入力 v : a.norm、照合成功から δ.map Ty.norm の型付けを結論する。raw な束縛型へは形成が分かる場合に戻す | 不明（既存の担当枠） |
| L20 G09 | 閉じた型付けの全導出→ValueMeaning→Inhabits、valueMeaning_subの全場合、任意の値/腕/捕捉への全接続。完全署名はsignatures。data/Listの子値への下降とLeQの導出への下降を分ける | detailの4〜8時間を据置き |
| L30 | 値依存長の開いた等号/線形の有限のEntailsの証明書 | 不明（既存の担当枠） |
| L70/R10b、R50 | ソースからのscrutineeの型の静的な合成、guard/unknown、篩付きの同じ結果型/効果、全表層と交換の接続。Rust の束縛型と P_Var/P_Refined/P_Convert（篩型・途中の型・正規化した束縛列）の照合 | 不明（既存の担当枠） |
| 取りまとめ | RV-L10.x の中1の修正箇所と軽1〜5の記録の確認、work、受け入れ、必要な取り込み。detail X1 の assume/正規化と、10規則に対する実際11規則の差の注記 | 不明 |

G09へ残す完全署名はLeanの未証明宣言や公理として置いていない。群Xの代表の意味への入力を、主な定理の独立の前提として取り込まない。型付けから意味を供給する全帰納は後段で閉じる。群Wをこの作業で開始していない。

## 外側の時間

初回実装は、最初に時計を確認した2026-11-01 06:09:41 UTC（15:09:41 JST）から、結果の文書を確定した 06:53:46 UTCまで、外側44分5秒である。入口の読取り、署名、局所の反例と補助契約の判断、実装、検査の待ち、規範と記録を含む。能動時間と待ち時間を分離していないため、能動時間の確定値にしない。独立レビューと設計者の受け入れの待ちは含まない。14時間の停止条件には達していない。この時間と304枝の既存証明の照合から、未着手のG09の見込みを比例で縮めない。

初回に、全7単位の義務、新規ファイルの完全な一覧、相対リンク、検証入力とソースのハッシュ、保護対象9ファイルの不変、100,000 bytesの上限と手元の絶対パスの不在を点検した。レビュー修正後の同じ点検と6件の所見の照合も通過した。

今回のレビュー修正は2026-11-01 07:16:21 UTC（16:16:21 JST）に開始し、07:27:00 UTC に最終の照合と記録を終えた。外側10分39秒であり、今回の上限4時間に達していない。規則の修正、境界、用語の調査、規範と申し送り、既定ビルドと公理依存、原本と入力の不変の照合を含む。レビュー原本と rv 入力を含む再開後の保護対象27件、および初回から保護する主定理等9件は全て不変である。

## 作業末の work

取りまとめが実行した。基準は `efbc8ebf58b0a64320f375e663ad929a29e73e86`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 94.65 秒である。実行の前に Refinement の生成物を消した。

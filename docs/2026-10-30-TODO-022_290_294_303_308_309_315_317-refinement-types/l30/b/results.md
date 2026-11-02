# L30 群B・Cの結果

2026-11-03。指定ブランチ `m014/l30.b`、基準 B_WORK は `13a27bb960e336332add2e9eed55c5b99c876fb5`。群Aの[固定署名](../a/signatures.md)と案(ii)checkedAtを引き継いだ。対象はL30.07〜.18の12単位である。担当による実装と自己点検の記録であり、独立レビューと設計者の受け入れを代用しない。

## 完了条件の照合

| 単位 | 担当分の判定 | 本番の証拠と具体の読者 |
|---|---|---|
| L30.07 | 完了 | 群AのLinear/encode_bindを再利用。Linearizationの各出力で列長を照合し、linearize_lengthで一致を証明。LinearizationExamplesで不正な長さの成功を否定し、既存の符号化と意味を実際に使用 |
| L30.08 | 完了 | EqualityModeの完全名・定義を保って独立。TermStructuralEqは20/14形の構成的比較、CertificateSyntaxはKeyTable/keyIndex/keyIndex_soundとNNF。重複の最初の位置・未知鍵・snapshotのnone・Float分類の相違を具体に照合。facts/todoに対する証明書の先行参照の検査は群D/Gの担当 |
| L30.09 | 完了 | 整数定数は係数0と定数項、変数は登録鍵の単位係数。linearize_sound_atのinteger枝と鍵枝。定数7、整数varのsort、重複鍵を具体に確認 |
| L30.10 | 完了 | 左右の列長を照合してzipWithで係数を加算。linearDot_addとsoundのadd枝が本番の意味へ接続 |
| L30.11 | 完了 | neg/scaleの係数列と定数項、既存linearDot_scaleと整数射影を合成。負係数を含む実入力で意味を確認 |
| L30.12 | 完了 | soundのTerm20形を合成。既存Term.HasSortで13形が整数sortを満たさないこと、七measure、宣言した整数欄と範囲外欄を確認。鍵のsortを検査するcheckInは群Eの.29・群Gの.38の担当 |
| L30.13 | 完了 | normalizeのtruth/falsity×2とsoundの定数枝、具体表の4行 |
| L30.14 | 完了 | normalizeBound_sound_atと整数eq/le/ltの6場合。定数項をboundへ移し、負側の−1と両向きを同じν上で証明 |
| L30.15 | 完了 | compare/floatClass×2をliteralで保持。NaNのnot ltとgeが異なる実例、negativeZeroの具体入力 |
| L30.16 | 完了 | decimalRepresented/charactersIn/member/constructorIs×2をliteralで保持。未観測のmemberも原子のまま残す |
| L30.17 | 完了 | And/Or×2、Not×2。極性とDe Morganを全場合の一つの帰納で合成。DNF全列を生成しない |
| L30.18 | 完了 | Predの構造再帰で停止。normalize_sound_atを合成し、恒等置換からnormalize_sound。全28場合の独立に記した期待出力と既定importの読者を確認。四つのνの像は一般の健全性を適用できることを示す |

固定した二つの健全性の完全署名は[signatures.md](signatures.md)に記す。数学の係数はIntのままであり、U03の保存幅128ビット・実際の基本操作の一回ずつの計上・proof-steps-v1・個別予約は群L/R20へ引き継ぐ。今回、それらを独立の上限や前提にしていない。

## Term20形の対応

すべて `linearize_sound_at` の同じ任意のνの上の帰納で閉じた。rawの鍵の受理と、既存Term.HasSortで成り立つ性質を分ける。鍵のsortを検査するcheckInは群Eの.29と群Gの.38の担当であり、B/Cで実装した入口ではない。

| Termの形 | 線形化 | 既存Term.HasSort Γ .integerの性質 |
|---|---|---|
| var | keyIndexの最初の位置の単位係数、定数項0 | 既存Term.HasSortの文脈の整数sort |
| integer | 鍵数分の0、定数項が元の整数 | 整数sort |
| character | 登録した場合だけ鍵の整数射影 | 成り立たない |
| float64 | 同上 | 同上 |
| float32 | 同上 | 同上 |
| decimal | 同上 | 同上 |
| boolean | 同上 | 同上 |
| unitValue | 同上 | 同上 |
| string | 同上 | 同上 |
| listValue | 同上 | 同上 |
| bytesValue | 同上 | 同上 |
| mapValue | 同上 | 同上 |
| setValue | 同上 | 同上 |
| dataValue | 同上 | 同上 |
| targetValue | 同上 | 同上 |
| field | 登録した鍵の単位係数、定数項0 | 受け手のdata sortと整数resultを要求。FieldRef.Declaredの性質は別に確認 |
| measure | 同上。七種を同じ入口で扱う | 受け手のsortを要求。内部snapshotは受け手になりうる。宣言照合は別の性質 |
| add | 同じ鍵列の係数ごとの和、定数項の和 | 子は整数sort |
| neg | 全係数を−1倍、定数項を反転 | 子は整数sort |
| scale | 全係数と定数項を同じ整数倍 | 子は整数sort。変数同士の積を追加しない |

整数・add・neg・scaleを先に分解するので、それらが鍵列にも含まれていても構文の意味を優先する。残る16形は鍵の整数射影を使う。13形についてTerm.HasSort Γ .integerが成り立たないことを示した。raw核の成功はsortや宣言の検査成功を意味しない。鍵列の相異性や、νの像の形・sortを仮定しない。

## NNF28場合の対応

a/bは同じνの像の整数射影とする。表の不等式は線形化の定数項を右辺へ移して符号化する。

| Predの形 | 正側 | 負側 | 場合数 |
|---|---|---|---:|
| truth | truth | falsity | 2 |
| falsity | falsity | truth | 2 |
| eq a b | a−b≤0 And b−a≤0 | a−b≤−1 Or b−a≤−1 | 2 |
| le a b | a−b≤0 | b−a≤−1 | 2 |
| lt a b | a−b≤−1 | b−a≤0 | 2 |
| compare | literal false | literal true | 2 |
| floatClass | 同上 | 同上 | 2 |
| decimalRepresented | 同上 | 同上 | 2 |
| charactersIn | 同上 | 同上 | 2 |
| member | 同上 | 同上 | 2 |
| constructorIs | 同上 | 同上 | 2 |
| and p q | 子の正側のAnd | 子の負側のOr | 2 |
| or p q | 子の正側のOr | 子の負側のAnd | 2 |
| not p | 子の負側 | 子の正側 | 2 |
| 合計 | 14形 | 2極性 | 28 |

六原子は内部を読まずに同じ構文と符号を保持する。literalの意味にもpredBind νを適用する。Floatの順序の否定、部分観測のnone、対象のmemberを別の原子や定数に置換しない。全28入力の検査はLogicNormalizationExamplesのcases28を使い、期待値はnormalizeから生成していない。整数の未知鍵はnoneとなり、同じ入力で鍵が登録済みなら成功する。

## 追加・移動した宣言と読者

| モジュール | 宣言と用途 | 既定ビルドの読者 |
|---|---|---|
| EqualityMode | EqCertificateから同じ定義を移動 | EqCertificateのRewritePosition |
| TermStructuralEq | termEq/slotEq/slotsEq/predEqと、それぞれ構文の等号との同値 | keyIndex、具体のsnapshot/Float/NNFの比較 |
| CertificateSyntax | KeyTable、keyIndex/keyIndex_sound、NNF/toPred | Linearization、LogicNormalizationとその具体例 |
| Linearization | keyCoefficients/linearDot_keyCoefficients、linearDot_add、linearize/length/sound_at。privateのcheckAffine/bind_checkAffine/linearDot_zero/keyEnv_lookup | normalizeBoundとその健全性、LinearizationExamples |
| LogicNormalization | normalizeBound/sound_at、normalize/sound_at/sound。privateのliteral_soundと整数3比較の補助 | 全28場合と四つの像への健全性の適用 |
| LinearizationExamples | 定数・負係数・未知/重複鍵・長さ・13形・七measure・宣言した欄の受理と拒否 | formal/Benitoite.lean |
| LogicNormalizationExamples | 全28場合、NaN/none/未知鍵、四つの像への健全性の適用と恒等置換の系 | formal/Benitoite.lean |

全宣言の監査はprivate・コンパイラの生成宣言も対象とする。対象一覧はaudit.leanが環境から再生成し、改造には台本と件数・SHA-256だけを保存する。追加モジュールは7本、変更した本番の既存モジュールはEqCertificate（移動とimport）と既定Benitoiteのimportである。旧Releaseと処理系の変更は0。

## 内部の署名と計画との差

初回実装での群Aの完全署名の変更は0。再開1では軽2の指示に従い、linearTerm_integerAs・Linear.toPred_sound・Linear.toPred_sound_atの列長の前提を外した。群AのLinear/符号化/置換の補助を再実装せずに使用した。EqualityModeを独立させたのは群Aの固定済みの移動である。内部の補助として、長さ検査checkAffineとその成功の逆転、鍵の単位係数と内積、等長の係数和、整数比較に共通のnormalizeBoundを追加した。初回実装で旧の内部補題の署名を変更した件数は0。新補助の完全署名はsignatures.mdに記した。

主な十言明の形、新しい公理、独立の信頼条件、書ける形の制限、提供範囲の削減、精密な外部状態の追加は0。案(ii)のまま全20/28場合が閉じた。Certificate/Refutationの全構成子、Entails.checkedAt、型域の切替、保存幅とstepsのモデルは今回の完了に含めない。D/G/H以降の担当である。

各単位の証明を順に別ファイルで閉じる実装にはせず、線形化・NNFそれぞれの共通の定義と一つの帰納にまとめた。時間の分離は下記の制限を持つ。計画の見込みを担当が変更したり、この短い実績の比を未知の帰納へ掛けたりしていない。

## 義務の一行ずつの判定

35行を照合した。完了とするのはB/Cに割り当てられた部分であり、義務行全体の閉鎖は0。

| 義務 | B/Cの担当分の判定・証拠 | 残る担当・時期 |
|---|---|---|
| O015 | 完了。Term20形の整数sort境界、六原子の12場合を保持 | E/F/J/Kの有限規則、L40/L50 |
| O017 | 今回の実装対象なし。U03の決定を引継ぎ | Lの計上、R20/R50/R60 |
| O019 | 完了。構成的比較、鍵の位置と未知鍵、線形化の健全性 | D〜G/Kの全証明書・反証、R20/R50 |
| O020 | 今回の実装対象なし | D/GのdiscardとOr展開前の反証、L/R20/R70 |
| O021 | 今回の実装対象なし。B/Cの時間の区間を記録した。見込みの更新は取りまとめ | 担当の単位は.06/.48/.72/.80。L40/R20と合わせた取りまとめの更新 |
| O022 | 今回の実装対象なし。数値射影と既存のsort/宣言の性質を分離 | E/F/H〜Kの葉、L40/L50/L60 |
| O023 | 今回の実装対象なし。具体のby decideはあるが全証明書の実行再生と数えない | G.42/M.74、R50 |
| O026 | 今回の実装対象なし。noneと二値の射影の境界を維持 | J/L、R20/R60 |
| O034 | 今回の実装対象なし。七measureを鍵として使うだけで正常結果の全対応としない | J/K、L40/L50/L60/R50 |
| O043 | 今回の実装対象なし | G/Kのactual CertificateとLeQ、L40/L70 |
| O050 | 今回の実装対象なし。構造比較は数としての等号に拡大しない | E/G/J、L40 |
| O054 | 今回の実装対象なし。符号付き原子を保持 | F/G/KのBoolean相異、L40/L70/R10b |
| O071 | 完了。NNF28場合とν上の意味保存。探索の完全性を前提にしない | D〜G/Lの反証、R20/D10 |
| O072 | 完了。var/field/measureの鍵、検査した最初の位置と実像の射影 | E/Jの限定合同・有限別名、R10b/R20 |
| O127 | 完了。charactersInの正負を保持。区間包含の規則は未実施 | F/I/J/K、L40/R段/V10 |
| O130 | 今回の実装対象なし。二つのString長の鍵を区別 | F/J/K、L40/R段/V10 |
| O131 | 今回の実装対象なし。List長の鍵を確認 | F/G/J/K、L40標準本体/R段/V10 |
| O132 | 今回の実装対象なし。Bytes長の鍵を確認 | F/J/K、L40/R段/V10 |
| O133 | 今回の実装対象なし。MapSizeを鍵として使うことと鍵の言語上の等値を分離 | J/K、L40/R段/V10 |
| O134 | 今回の実装対象なし。SetSizeの鍵と整数射影を分離 | J/K、L40/R段/V10 |
| O135 | 今回の実装対象なし。宣言した整数欄の具体入力を確認 | E/J/Kの限定合同と変性、L40/R段/V10 |
| O136 | 今回の実装対象なし。任意のνを保つ下層を用意 | D/G/Kの依存端点、L40/L70/R段/V10 |
| O137 | 今回の実装対象なし。数学Intを機械算術やStopへ読み替えない | I/J/K、L40/R段/V10 |
| O144 | 完了。線形化20形、NNF28場合、traceなしの構造再帰とν上の意味保存 | D〜Kの全有限規則、L40/L50/R段/V10 |
| O158 | 今回の実装対象なし。独立unknown/深さ/枝数の上限なし | L、R20/R70/V10 |
| O161 | 今回の実装対象なし。数学の幅の契約を維持 | Lの数学対応、R20/R60/V10 |
| O167 | B/C担当分完了。raw整数射影の受理と、既存Term.HasSortで13形が整数sortを満たさない性質、未知鍵/宣言不一致、NaN/noneの対照 | 鍵に整数sortを要求するcheckInはE.29/G.38。E〜K/Lの全対照、L40/L70/R段/V10 |
| O046 | 今回の実装対象なし | F/G/J/K、L40/L70 |
| O079 | 今回の実装対象なし | Kのactual Certificate、L70/R10b/R50 |
| O138 | 今回の実装対象なし。正負の意味を保存 | F/G/K、L40/L70/R段/V10 |
| O143 | 今回の実装対象なし | K、L40/L70/R段/V10 |
| O016 | 今回の全追加/移動宣言と群A・旧主定理を公理監査する。最終結果は下欄 | 独立レビュー、Nの全段A-L、L70 |
| O084 | 完了。実装・自己点検・独立レビュー・全体の受け入れを分離 | M/Nと全L/R/K/V |
| O027 | 完了。既定/局所Leanとも-M12288。正式RSSは未取得（計画上の非採取） | Nの同じ最後のworkへ取りまとめが採取 |
| O118 | 完了。01-12/07-04の写しと対応表、新本番コメントを現行の意味に合わせた | Nの全段照合、L70/R50/R60/D10/V10 |

## 検査と失敗の記録

適用例にはtest-auditの作成時の関門を適用した。守る契約は、構成的な構造比較、有限鍵の位置、線形化の定数項・列長・整数射影、既存のsort/宣言の性質との区別、NNFの整数境界と原子の符号、任意のνの像の意味である。鍵の位置の取り違い、zipWithの切り詰め、定数項の消失、NaNのnot ltをgeへ変えること、noneを偽へ変えることをこの境界で検出する。群Aの代表は全線形化/NNFを実装していないため、今回の契約を覆わない。本番の入力と意味を使い、専用の差し込み口を設けていない。Rustテストの追加/変更/削除0。

局所検査はTermStructuralEq・CertificateSyntax・EqCertificate、Linearization、LogicNormalization、二つの具体例のモジュールだけを対象にした。途中の失敗は、相互帰納の論理積の結合、Optionのbindの展開、projectionの簡約、Boolの補題名、具体のProgramの欄数とprivate定義の展開を直した。最初のlinearizeは整礎再帰の定義で核内のdecideが展開できなかったため、停止の根拠を同じTermの構造再帰として明示し、具体例をdecideで再生できる形にした。公開署名・意味・許可する形の変更はない。生成器の初回実行もcwdの指定を直した。失敗した出力を成功の証拠へ混ぜていない。

新規ソースの警告は0。TypeSubst/RangeSubstのunusedSimpArgsは既存の警告であり、担当の範囲外として保持した。局所の試行の生ログは`<tmp>`に置き、最終検査の識別は下欄に保存する。

## 時間記録の精度

最初の時計取得は07:34:25（+0900）。それ以前の依頼文・既定事項の読取り時間は未採取である。記録は[times.json](times.json)。単位ごとの独立した時計をその都度取得していないため、下表は作成ファイルと成功ログの時刻から再構成した区間であり、単位の全能動時間を表さない。同じ帰納に含まれる単位は区間が重なる。合算や、一件あたりの所要時間としての外挿をしない。Cの定義・証明の後にBの欄の具体例を補った時間も別の単位へ二重に配賦しない。要求された個別の時間の分離にはこの欠けがある。

<!-- 単位の時間表と最終検査は台本の出力を下に記す。 -->

| 単位 | 観測した区間（+0900） | 区間の長さ | 精度・重複 |
|---|---|---:|---|
| L30.07 | 07:34:25〜07:36:58 | 153.292秒 | 列長検査と共通の線形化。読取りの開始前は未採取 |
| L30.08 | 07:34:25〜07:35:29 | 63.931秒 | 構造比較・鍵・EqualityModeの移動 |
| L30.09 | 07:36:12〜07:36:58 | 45.994秒 | L30.09〜.11と共通の帰納。個別分離不能 |
| L30.10 | 07:36:12〜07:36:58 | 45.994秒 | L30.09〜.11と共通の帰納。個別分離不能 |
| L30.11 | 07:36:12〜07:36:58 | 45.994秒 | L30.09〜.11と共通の帰納。個別分離不能 |
| L30.12 | 07:37:59〜07:42:02 | 243.618秒 | 20形の合成・型付きの境界・具体の宣言。Cの時間も重なる |
| L30.13 | 07:39:01〜07:39:24 | 23.947秒 | L30.13〜.17の共通の定義・枝補題・帰納。個別分離不能 |
| L30.14 | 07:39:01〜07:39:24 | 23.947秒 | L30.13〜.17の共通の定義・枝補題・帰納。個別分離不能 |
| L30.15 | 07:39:01〜07:39:24 | 23.947秒 | L30.13〜.17の共通の定義・枝補題・帰納。個別分離不能 |
| L30.16 | 07:39:01〜07:39:24 | 23.947秒 | L30.13〜.17の共通の定義・枝補題・帰納。個別分離不能 |
| L30.17 | 07:39:01〜07:39:24 | 23.947秒 | L30.13〜.17の共通の定義・枝補題・帰納。個別分離不能 |
| L30.18 | 07:39:24〜07:40:18 | 53.058秒 | 全場合の具体表・恒等置換の系・既定import |

## 取りまとめへの申し送り

Dの.19は本番linearize_sound_atとnormalize_sound_atを同じkeys/ν/ηで合成できる。normalizeの出力の線形の葉は、列長を仮定しないLinear.toPred_sound_atでHoldsとして読める。linearize_lengthは直接の線形化の出力形の性質として保持する。正規化済みのliteralの意味もpredBind νで読む。像での鍵の再配列や、証明書の再生成を追加しない。CertificateSyntaxにはKeyTableとNNFを置いた。EqProof/BuiltinLemma/PreparedLeaf/Refutation/Certificateの移動と追加は後続の担当であり、今回下書きのfalse枝や未証明の構成子を置いていない。

主な定理や方式について、新しく取りまとめへ判断を求める点はない。担当分の独立レビュー、時間記録の精度を含む結果の確認、次の群Dの起動は取りまとめへ渡す。群全体の個別の能動時間が分離できないため、B/Cの短い区間から後続の未知の帰納を一律に短縮しない。所要の上端の2倍・4時間の途中報告条件には達していない。

## 初回の最終検査・公理依存・関係状態

作業末のworkは次の一回である。only/個別testは指定しなかった。既定のlake buildはこのwork内のformal_buildで実行した。lakefileのdefaultTargetsはBenitoiteと七つの交換・検査の実行ファイルを含む既定の8対象である。check_formalは成功したlakeの出力を抑え、同じ出力にsorryの使用があれば拒否する。

```text
scripts/check.sh --level work --base 13a27bb960e336332add2e9eed55c5b99c876fb5
```

| 検査 | 終了 | 外側の時間 | 内容 |
|---|---:|---:|---|
| dry-run | 0 | 0.113秒 | 基準と自動選択を事前確認 |
| work | 0 | 8.958秒 | 仕様対応の自己検査/集計、仕様例7件成功・失敗0・無視0、既定lake全対象とsorry拒否 |
| 公理監査 | 0 | 2.144秒 | 群A〜Cの17モジュール・旧主定理5・三モデル・十移送、計1029宣言 |
| 具体読者の修正後の既定ビルド | 0 | 1.143秒 | formal/でlake build。既定8対象、912 jobs、sorryの使用なし |

公理監査の再生成は、リポジトリの根から `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/b/audit.py --tmp <tmp>` とする。実行するLeanは `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/b/audit.lean` である。17モジュールの全定数を所属モジュールから列挙し、private・生成宣言を除外しない。対象名の重複・欠落・axiomの新規宣言を拒否し、print axiomsの件数と対象一覧を照合した。

公理の依存は以下の通りである。許可三公理以外、新しい公理、sorryAxの依存は0。linearize_sound_at/normalize_sound_at/normalize_soundはpropext・Classical.choice・Quot.soundに依存し、termEq_spec/predEq_specはpropextだけに依存する。

| 依存集合 | 宣言数 |
|---|---:|
| Classical.choice + Quot.sound + propext | 140 |
| none | 406 |
| propext | 460 |
| Quot.sound + propext | 23 |

初回の新しい7モジュールの全定数は422宣言であり、うち22宣言はEqualityModeとその生成宣言の移動、新規は400宣言である。これはprivate・生成宣言を含む数で、手書きの補題の数や具体例の件数ではない。

### 生出力の識別

生出力と対象一覧は`<tmp>`に置いた。改造内には台本と以下の識別を残す。各保存ファイルは100 KB以下である。

| 出力 | bytes | SHA-256 |
|---|---:|---|
| dry-run.log | 759 | `686f2bf44f14b410ed0983d2fcd148b190cc64eb993212c47227e807186074a2` |
| work.log | 5757 | `5eab60c13b6661d4540cf9351b9f8f01f346b270c43c47ebcc374f282294b7ea` |
| default-build.log | 43394 | `8d6fc5551f847e2352fa3fe66a873064a36bd21f83c3646e3d6341b4e93fe28e` |
| axioms.log | 201676 | `356d3353e632dd6fdc20ee288630cdc95d50acb9e871dd5d928c927cbb690eeb` |
| audit-targets.txt | 75188 | `1105e26a4e1259aa7f290b0ad78f23ac0abd3de270cf8419fc95332f50b78f2d` |

### 入力と後の変更

基準とHEADは同じB_WORKであり、担当の差分は未コミットである。[inputs-before-resume1.json](inputs-before-resume1.json)に初回の本番Lean・設計書の写し・固定した依頼/計画/署名/レビュー・道具・設定のbytes/SHA-256と、全formalソースの再生成可能なmanifestのSHA-256を置いた。既定構成の増分ビルドで、交換器/manifest/処理系のコードは変更していない。Rust/Leanの全比較を実施済みとも引用済みともしていない。最大常駐量は未取得（計画上の非採取）。

work後の自己点検で、具体読者二ファイルから使わない所属前提を除いた。全28行では正規化の実際の成功・構造一致から期待する出力の意味を導き、四つの像は各々のνへ直接適用する形にした。predEq_specも具体のFloat分類の相違へ適用した。公開定義・完全署名・01-12/07-04・仕様例は不変である。古くなったLeanの検査は、同じ既定のlake buildと公理監査を再実行し、最後の関係状態を確認した。workの入口は一回であり、仕様例/集計は後の変更の影響を受けない。初回の公理監査1024宣言・2.152秒はaudit-initial.jsonへ分け、最終の件数と混ぜない。担当Codex、2026-11-03の自己点検である。独立レビューと設計者の受け入れは取りまとめが別に行う。

最初の時計取得から最後の資料照合まで1140.97秒（約19.0分）。読取りの未採取分は含まず、能動時間と待ちは分離していない。単位表の重複する区間の和ではない。

## 再開1: RV-L30.bの軽1〜5

2026-11-03。[独立レビュー](../../reviews/RV-L30.b.md)（可、重0・中0・軽5）に従って処置した。新しい主定理・公理・信頼条件・提供範囲の判断は追加していない。以下は担当の修正と自己点検であり、独立レビューを実行した記録ではない。

| 所見 | 処置 | 本番と記録の対応 |
|---|---|---|
| 軽1 | 01-12・07-04・本書L30.12/Term20表/O167を修正。13形は既存Term.HasSort Γ .integerが成り立たないこととして記した | B/Cには鍵のsortを検査するcheckInはない。checkInの検査は群Eの.29・群Gの.38の担当。線形化のraw整数射影と、sort/宣言の性質を区別する |
| 軽2 | linearTerm_integerAs・Linear.toPred_sound・Linear.toPred_sound_atから列長の前提を除き、全読者を更新した | 同名の三署名を強めた。列長を要求する旧版や別名を残していない。normalizeBound_sound_atはlinearize_lengthを前提の供給に使わず、直接符号化の意味を読む |
| 軽2の群Dへの接続 | normalizeの実際の成功から線形の葉の真を得てHoldsへ写す例と、Andの二葉をHoldsとして読んで非負結合する例を既定importに追加 | LogicNormalizationExamplesのbelowOneとbounds。後者は1≤x≤2から2*x+1*(-x)≤2*2+1*(-1)、従ってx≤3を同じ鍵の整数環境で示す。.21/.22が出力葉の列長を別に導く必要はない |
| 軽3 | CertificateSyntaxの未使用EqualityMode importを削除し、読者表をEqCertificateだけに直した | EqualityModeは実際に使うRewritePositionから読まれる。完全名・定義は不変 |
| 軽4の欄 | 一般の欄の例からhdとそれを返す連言を除いた。コメントをlinearizeは宣言を読まないことに合わせた | 受け手のsortとresultのsortは結論を構成するために使う。具体のfieldProgramで宣言を満たす例と範囲外の欄の拒否は維持 |
| 軽4の論理 | cases28のAnd/Orの正負4行を、整数比較belowOneと、整数等号を否定するdifferentThreeへ変更した。外側にNotも持つDe Morganの計算例を追加 | cases28は14形×2極性の28行のまま。x<1とnot(x=3)を組み合わせ、負側の−1と等号の両向きを照合する |
| 軽4の四つの像 | 結果の表現を修正した | 四つの像の例はnormalize_sound_atを各νに当てはめたものである。像ごとの意味の計算結果を検査した例ではなく、任意のνを受ける署名の具体の読者である |
| 軽5 | O021を「今回の実装対象なし」に修正した | B/Cは時間の区間を記録した。全79単位の積上げ・見込みの更新は.06/.48/.72/.80と取りまとめの担当 |

出力の列長を照合するcheckAffineは整形の検査として保持し、linearize_lengthはその性質を使う既存の具体例で読まれる。線形式の符号化の意味の前提としては要求しない。完全署名の差はsignatures.mdの「再開1」に記した。linearize_sound_at・normalize_sound_atの固定署名は不変である。

test-auditの作成時の関門では、鍵と係数の両方向の列長不一致を読める契約、正規化の葉とHoldsの接続、整数の厳密境界とDe Morganの合成を対象とした。旧版の列長の前提が残れば新しい適用は型が合わず、境界や極性を誤ればcases28の期待出力との照合が失敗する。群Dの規則やcheckInを代用する差し込み口は作っていない。Rustのテスト変更は0。

局所の関係モジュールのビルドは終了0。新規ソースのエラー・警告はなく、TypeSubst/RangeSubstの既存のunusedSimpArgsはそのまま残した。初回の入力・監査・自己点検のJSONは*-before-resume1.jsonへ分けて保管し、現行のaudit-summary.json/inputs.json/validation.jsonは再開1の最後の状態へ更新する。

### 再開1の検査

本番Leanと01-12/07-04の変更を終えてから、既定のlake build、公理監査、指定のworkを順に実行した。workの入口は再開1で一回、--onlyと個別testの指定はない。初回の実行とは分けて[checks-resume1.json](checks-resume1.json)へ記録した。

```text
(cd formal && lake build)
python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/b/audit.py --tmp <tmp>
scripts/check.sh --level work --base 13a27bb960e336332add2e9eed55c5b99c876fb5
```

| 検査 | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| 既定lake build | 0 | 1.244秒 | 既定8対象・912 jobs、sorryの使用なし |
| workのdry-run | 0 | 0.114秒 | 同じ基準と指定で仕様対応の自己検査/集計・仕様例・既定Leanとsorry拒否を確認 |
| 作業末のwork | 0 | 3.699秒 | 仕様例7件成功・失敗0・無視0、仕様対応の自己検査/集計、既定Leanとsorry拒否 |
| 公理監査 | 0 | 2.140秒 | 17モジュール・旧主定理5・三モデル・十移送、計1031宣言 |

公理監査の実行で上書きされた現行audit-summary.jsonを、終了状態・件数・公理の集合・対象一覧と生出力のbytes/SHA-256まで照合した。初回の1029宣言の要約はaudit-summary-before-resume1.jsonに保管した。再開1の依存の集合は次のとおりで、許可三公理以外・新しい公理・sorryAxの依存は0。

| 依存集合 | 宣言数 |
|---|---:|
| Classical.choice + Quot.sound + propext | 140 |
| none | 409 |
| propext | 459 |
| Quot.sound + propext | 23 |

対象一覧は従来のaudit.lean/audit.pyから再生成できる。private・生成宣言も除外しない。本番の署名の変更は前提の除去だけであり、数学Int・案(ii)checkedAt・linearize_sound_at/normalize_sound_at・主な十言明の形は維持した。

### 再開1の生出力と入力

生出力は初回と別の`<tmp>`に置き、改造には以下の識別だけを残す。

| 出力 | bytes | SHA-256 |
|---|---:|---|
| default-build.log | 43308 | `689d03741138ef43660368f345149e5f7a6d7d2eab0104d4a916e2f804ea5652` |
| dry-run.log | 759 | `ac563f479eb948b7647d3d4c618e81215adf741b6d9b4bfc8b6da1e16c15433a` |
| work.log | 5757 | `5fdb0601fec9f1fc7e0190904fa7e67456c8e7e24663edf1ce6e8260cd2f8b6a` |
| axioms.log | 202447 | `fb72d748d792e5d98a239f2bff3bf5d331b35dcbef988923d75759295b4b633a` |
| audit-targets.txt | 75528 | `d6bf1970249a59c24a1ebc1beae5d1bb4165099d1b7449b815ed610bfee283c6` |

inputs.jsonを再開1の本番Lean・設計書の写し・署名・レビュー・監査台本のハッシュへ更新した。既定の設定、Lean 4.34.1、-M12288は同じである。初回の入力はinputs-before-resume1.jsonを正とし、現行の入力と混ぜない。最後のwork後に本番Lean・01-12・07-04・署名・監査台本の変更はなく、検査の結果は記録した最後の関係状態に適用できる。Rust/Leanの全比較と正式RSSは今回の対象外であり、実施済みとしない。

### 再開1の外側の時間と申し送り

最初の時計取得は2026-11-03T08:02:34.108931+09:00、最後の資料照合は2026-11-03T08:07:23.608369+09:00、観測した外側の時間は289.53秒（約4.8分）。[times-resume1.json](times-resume1.json)に記録した。取得前の依頼文・レビューの読取り時間は未採取である。能動時間と待ちは分離していない。検査の時間は上表に別記し、初回の単位ごとの区間へ加算していない。

軽1〜5を担当分完了として照合した。新しい判断を取りまとめに求める点はない。群Dの.21/.22は列長を要求しないLinear.toPred_sound_atで葉を読む。群Eの.29・群Gの.38は鍵のsortを検査するcheckInを担当する。O021の見込みの更新は.06/.48/.72/.80と取りまとめが受け持つ。plan/detail/README/レビューの記録/処理系/旧Releaseを変更せず、gitの状態を変える操作も行っていない。担当Codex、2026-11-03の自己点検である。

## 作業末の work

取りまとめが、RV-L30.b（可。所見は軽だけで、レビューは再レビューを要しないとした）の処置の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 13a27bb960e336332add2e9eed55c5b99c876fb5` | 0 | 149.15秒 | 1,526,775,808 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。

# 再開9・再開10の記録

本書は [results.md](results.md) の続きである。

## 再開9（RV-L70.d3 の処置）

公開呼出しの収集と書き換えを `CheckTables.checkProgram` の実入口へ組み込み、`checkProgramAccepted` も同じ経路を通す。閉じた範囲のパラメータと範囲変数を同じ規則で選び、文列の全出現について転送を判定する。詳細と全ての言明の名前・前提は[実入口と転送の受理](resume9-details.md)に置く。再開8の制限と未充足の型付けの仮定の記述は、その時点の記録として残し、本節と詳細に今回の到達点を書く。

### RV-L70.d3 の各所見

| 所見 | 処置 |
|---|---|
| 重1 | `CheckPreparation.prepare` を実入口へ接続。公開呼出しのままのscalarと投影の全プログラムを受理し、素のBooleanの対照を拒否。公開ソースの意味を解決後のプログラムで定めるレビューの代案を採り、`PredicateProgramSemantics.observations_preserved` と `accepted_property1` を追加 |
| 中1 | 標準392行と内部行の支持、scalar・投影の全 `Input.Sound` を構成。`path_typed`・`source_typed`、`text_source_derivation`・`open_number_source_derivation` で検査の成功から実際の型付けへ接続 |
| 中2 | 空の範囲文脈でも固定範囲を持つパラメータを同じ選択器で扱う。`OpenScopeForwardExamples.closed_entry` と `range_decision_sound` で標準の合成表の実際の許容規則と実入口の成功を確認。型付け済みのパラメータと未検査の注釈の違いを01-12へ記載 |
| 中3 | 前置きの束縛・結果の束縛・ブロック末尾・複数引数の書き込みを全出現で扱う。五形ごとの受理と範囲変数の取り違えの拒否を `open_entry`・`different_source`・`different_entry` に置く |
| 軽1 | `CheckPredicateExamples.float32_infinite_branches` と実入口の `CheckPredicateProgramExamples.floating_entry .binary32 .infinite` を追加 |
| 軽2 | パイプは公開署名の素のBooleanになることを01-12と詳細の表へ記載。直接呼出しの解決とは評価順・引数位置の条件が異なるため、今回の対象へ加えない |
| 情1 | 既存の述語とδの対応を保持し、`public_deltas` をプログラムの観測の言明の読者とした。動的な条件の公開Booleanを保つ |
| 情2 | 対象を一度だけ渡す二規則と通常・開いた性質1を保持。今回のプログラムの接続はその既存の規則を使う。通常と開いた97規則の名前と順序を照合 |
| 情3 | 五形とも、受理の単位ではunknownSource、実入口では型付けの段のrejectedであることを正確に区別 |
| 情4 | 固定規則を七から十一へ広げ、引数位置0と並べ替えを扱う。`DefinitionRanges` は全出現で記号側の全具体化か局所の由来かを区別し、選べない出現は既存の保守的な受理へ渡す |

### 言明の差と止めずに進めた変更

再開8の終了時のSurface全1,948言明に対し、変更20件、追加477件、削除0件である。変更の内訳は、プログラムの型付けと停止の六言明、内部の分解一件、受理の三言明、有限材料の六言明、選択無しを明記した四つの互換の系である。元の六言明を `checkPreparedProgram_*` として名前だけ変えて保持し、見出しのハッシュの一致を照合する。群Dの旧308件は承認済み二差以外に追加差0、群Eの旧617件では再開8の二件を含め累計18件の差となる。主な十言明と核のStepの形は変えない。

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 公開ソースの意味 | 型付けと実行で表がずれる | 解決を型付け・通常の脱糖に先行させて意味を定義 | 未証明の旧脱糖との双模倣を信頼 | 収集行が無ければ元の通常の脱糖 |
| `checkProgram` と材料の前段 | 解決後の本体の型付けが必要 | 準備後の入力・本体を返し、宣言と一覧を保存 | 新しいInput.Soundや一覧の完全性を信頼 | 旧六言明を保持。恒等の準備なら元の形 |
| `checkProgramAccepted` | 内部形では出現番号が変わる | 型付けは準備後、受理と診断は元の本体 | 内部の番号を返す、受理を省く | 恒等の準備なら同じ両結論 |
| `BuiltinSource.resolved` | 独自の表へ包むと標準の具体化保存を失う | 元の構成と欄を保ち、内部行の支持・許容を証明 | 任意の表の保存を新しく信頼 | 範囲引数のない内部行と元の許容 |
| 閉じた転送 | 範囲パラメータの有無による逆転 | 型付け済みのパラメータから固定範囲も選ぶ | 無意味な範囲パラメータを足す、Topへ捨てる | 範囲を選ばない本体は元の受理 |
| 全出現と十一規則 | 前置き・結果束縛・書き込みを扱えない | 元のパラメータ参照を追い全出現を検査 | 局所注釈を由来とする、末尾以外を見落とす | 選択無しなら元の閉じた受理。固定範囲も同じ新規則 |
| `DefinitionRanges` と互換の四系 | 旧の局所解析はパラメータをTopとする | 記号側と閉じた由来の結論を分ける | 新しい受理から旧BodyRangesを断定 | 空の種類列かつ選択無しで旧結論。ScopeAcceptは保持 |

停止条件に当たる新しい公理・sorry・独立の信頼条件、提供範囲の削減、合成表が満たさない前提は要しなかった。型付け・Stepの規則は今回増減しない。01-12・07-04は実入口、意味、型付けの証人、転送の受理と前提に当たる箇所だけ更新した。群E後半のSafeCheck・SurfaceMain・SurfaceLibraryとの結合は、このworktreeの検査に含めない。

### 作業末の検査と監査の記録の補完

既定ビルドと公理依存の監査は、指定共有ロックの下で各一度だけ実行した。途中の単独Leanは一つずつとし、作業末の照合も一度で終了0となった。Gitの操作、処理系と旧Releaseの変更、scripts/check.shの実行は行っていない。

| 検査 | 結果 | 所要 |
|---|---|---:|
| 既定ビルド | `formal/` で対象を指定せず `lake build`。終了0、1,577ジョブ成功 | 163.264秒 |
| 全環境の公理依存の監査 | 全120,931宣言の出力を取得。出力後の必須名の照合で終了1。公理依存の検査自体の欠落ではない | 153.508秒 |
| 宣言一覧の補完・初回 | 生成名を文字列からNameへ解析し直す方法が衛生的な名前で失敗。終了1 | 65.334秒 |
| 宣言一覧の補完・訂正後 | 同じ既定環境の実際のNameを文字列で照合。終了0。公理依存の再検査はしない | 64.555秒 |
| 最終照合 | `resume9/verify.py`。終了0。全公理依存の対象と補完した全宣言の一覧が完全一致 | 5.747秒 |

監査末尾の失敗は、privateの `source_input_sound` を公開名として必須名へ記した担当の誤りである。当該宣言はprivateの修飾名で公理依存の監査に含まれていた。必須名を訂正し、取得済みの全対象から所属・種類・依存先・必須名だけを `declarations.lean` で補完した。補完の初稿では、生成名の `_@` と数値成分を `String.toName` に渡して匿名名となったため、実際の環境のNameを読み出す方法へ直した。本番ソースと写しは変更せず、公理監査を繰り返していない。初回の補完の要約も `declarations-initial-summary.json` に残す。最終照合は、監査の終了1がこの一つの必須名の誤りだけであること、全宣言に公理依存の出力が一つずつあること、同じ全宣言が補完の一覧に過不足なくあることを確認する。

全120,931宣言について新しい公理・sorryAxはなく、依存公理は `propext`・`Classical.choice`・`Quot.sound` の部分集合だけである。対象66モジュールの全15,069宣言（private 9,345件、生成宣言を含む）を照合した。対象名の一覧は9,343,150バイト、SHA-256 `4cc204643d3334be1fd8ef6ae5444cd74c9629b4675b826f38df9278762e33ae`。対象モジュールの全宣言の記録は3,680,059バイト、SHA-256 `77fcfaa44ab8851e872bd5b085c0bdcf9bbe0ada42c491628f1c925c74241a4b`。大きな生の記録は一時領域に置き、改造には写さない。

| 生出力 | 大きさ（バイト） | SHA-256 |
|---|---:|---|
| `<tmp>/build.log` | 196,783 | `e7ca824449cad1c4a4ede867b073e178879e16a87878c71230a608b6ac42d7c4` |
| `<tmp>/axioms.log` | 25,118,610 | `cc039440cc2167ef08de753968bb6700c3ff15f8bb3302797cb3bc11d01b569c` |
| `<tmp>/declarations-initial.log` | 330,297 | `385af477f65edd26f9db3f18342fcd9cf4526fbc86976cc1239032c562fa94a7` |
| `<tmp>/declarations.log` | 124,099,478 | `855d369e84a9dc5dc0f1c842a56686811b1b6a47006a6afc798388de62886898` |
| `<tmp>/verify.log` | 1,330 | `93549c2089c61cc04d978bb3ee0950b9598816cfb2138fabace01a1bb68ce8d4` |

本番ソースと二つの写しの1,402ファイルの指紋は、ビルド・監査・補完・最終照合の前後で一致した。SHA-256は `d617194664ddd7b1a607b3f12c4d88b71cb93f821839bd9db1915389e37c434d`。追加11モジュールが既定importへ入り、再開8・9の和集合66モジュールが既定importから到達することも照合した。全ての記録は一ファイル100KB以下である。

台本と差の一覧は [resume9](resume9/verification.json) にまとめる。`inventory.py` は開始時の全言明と指紋から対象と差を作り直し、`axioms.lean` は全環境の公理依存を列挙する。記録の補完は `run_check.py --kind declarations` が監査の対象名を一時ファイルへ取り出し、環境変数で `declarations.lean` へ渡す。対象名の再解析でなく、実際の環境のNameと照合する。`verify.py` が取得済みの公理依存と補完を結合する。

### 所要と取りまとめの見直し対象

資料の読解から結果の記録まで、概算で約1時間40分。開始時の指紋の保存は11月7日00:35:04、最終照合は01:54:22であり、その間は1時間19分18秒である。冒頭の読解と末尾の報告を含めても上限10時間の内側である。

取りまとめの見直し対象は、(1)公開ソースの意味を解決後に定めるレビューの代案、(2)型付けは準備後・受理と診断は元ソースとする実入口の契約、(3)固定範囲の転送の拡張と四つのno_rangesの系の選択無しの条件、(4)監査後の記録の補完の扱いである。停止条件の例外や新しい信頼条件の承認を求める点は無い。独立レビューの再判定と群E後半との結合の受け入れは、取りまとめで行う。

## 再開10（結合の追随と処置の再確認）

開始版 B_WORK と確認した HEAD は `1395ebfb01be54bc53299c610c70477c1231898c` で一致した。ブランチは読み取りによる参照先の確認で `m014/l70.d3` と一致した。共通依頼文を最初に読み、指定のレビュー、再開9の依頼・報告、群 E の後半の結果とレビューを読み合わせた。依存と固定ツールチェーンの勧告照合は共通依頼文の引継ぎどおりで、更新を加えていない。

### 正常な閉包の観測の境界

確認用入力は [obstruction.lean](resume10/obstruction.lean) である。以下の `S` は `Benitoite.Release.Refinement.Surface`、`N` は `Benitoite.Release.Refinement.PredicateResolutionBoundary` を表す。

`N.actual_exact_observation_boundary` は、実際の入力の `Sound` と実入口の成功、解決前の定義の型付けと準備後の `CheckedUnder` を満たす `factory` について、群 E の `SafeCheckErasure.terminal` と同じ正常観測の厳密な等号が成り立たないことを示す。元の核は通常の `desugarProgram op surfaceProgram` と固定の標準表、準備後の核は実際の `CheckPreparation.prepare` のプログラムの脱糖と同じ準備後の表である。

```text
factory() は次のラムダを返す。
  λ(x: Float). Float.isFinite(x) の結果を捨て、() を返す。

通常の脱糖では、公開呼出しの引数を let で束縛する。
準備後は、同じ判定を内部行へ直接渡す。
返る閉包のコードが異なるため、Val そのものの等号による正常観測は異なる。
```

前者は元の閉包の正常観測を持つ。後者からその同じ正常観測へ到達する実行はない。両方の開始状態が既に終端であり、事象のない段を加減してもこの差は消えない。`N.returned_iff_terminal` は、確認用の正常値抽出を本物の `SafeCheckErasure.terminal` の `.value` 観測へ結ぶ。

この反例は関数本体を起点とする。`main` の開始から非関数の結果が変わる反例でも、閉包をコードの模倣の対応で比較する言明の反例でもない。閉包の本体はどちらも判定結果を捨てて Unit を返す。main の結果が Unit 又は Result[Unit,String] に限られることと、関数一般の終端値を Val そのもので観測することは区別する。

同じ入力の `N.counterexample` は、閉包構文を読む仮定側の応答による失敗 payload の差も示す。その完成した表は `Completion` と `ProgramGuarantees` を満たすが、独自の表では実入口の解決が無効になるため、これを実入口で有効な固定標準表の反例としては用いない。

正常値はコードの模倣の対応で比較する方針を利用者へ明示して作業を進める。`PredicateSimulationObservations` は、値の対応の反射・対称・推移閉包の商を使い、正常値を共通の観測へ写す。定数の区別と `toTerm?` の有限な観測を保つことを局所検査した。失敗の全payloadと終了コードは等号で比較し、群 E の既存の生の観測の定義は変更しない。この観測を全状態の模倣へ接続した結果は「模倣の完成と観測の同値」に記す。

### 各所見の処置

| 所見 | 現在の処置 |
|---|---|
| D10.1 結合の追随 | `S.checkProgramAccepted_guarantees`・`S.checkProgramAccepted_main` の前提と保証対象を準備後へ追随。群 E の後半の3モジュールを修正し、既存の仮定なしの main 証人を保持した |
| 重1・D10.2 公開の行での実行との模倣 | 値・コード・捕捉・継続・ストア・状態の対応を構成し、全 Step の規則で両方向の模倣を証明した（`Setting.forward`・`Setting.backward`）。全表層構文の脱糖の対応、プログラムの対応、実入口からの観測の同値まで接続した（「模倣の完成と観測の同値」） |
| 中4 `observations_preserved` | 定義を展開しただけの旧言明を除去し、模倣から導く同値を `PredicateProgramObservations.observations_preserved` に置いた。`execution`・`infinite` は元のプログラムを標準の本体と結合した核と元の表を読む。01-12・07-04 の写しを合わせた |
| 重2・D10.3 重ねた表 | `PredicateOverlayValues` が値の四条件を供給。`PredicateOverlayTable.builtins_eq` が外部応答を含む全欄の一致を証明。仮定なしの公開呼出しの main が実入口の受理・`ProgramGuarantees`・`MainGuarantees` を結論する |
| 中5・D10.4 範囲のない定義 | 旧規則の成功から新規則の成功と同じ旧結論を保つ系を追加。旧拒否・新受理と旧成功の保存を全五形で確認。既存四つの `no_ranges` の署名を保持 |
| 軽3 記録の分割 | 再開9以降を本書へ移し、results.md は要約とリンクにした |
| 情5 `zip` の長さ | `contextsBlock_length`・`occurrences_zip_contexts_length` と、五形で切り捨てと順序を確認する読者を追加 |
| 情6 監査記録 | 前回の監査後の所属一覧の補完を、今回の監査とは分けて扱う。今回の最終監査は全宣言の所属と公理依存を同じ一回で採取する |

### 受理の保存的な拡張と列の長さ

`S.OpenScopeAccept.acceptBody_no_ranges_of_closed` は、任意の規則表・規則の一覧・パラメータ型について、閉じた由来を読む `ScopeAccept.acceptBody` の成功から、空の範囲文脈を持つ `OpenScopeAccept.acceptBody` の同じ成功を導く。`S.CheckAccept.acceptDef_no_ranges_of_closed` が定義へ、`S.CheckAccept.Accepted.of_no_ranges` が全定義と全メソッドへ接続する。`S.CheckAccept.accepted_no_ranges_of_closed` は、新しい `Accepted` と各定義の同じ閉じた `BodyRanges` を同時に返す。

`OpenScopeAccept.acceptBody` は、空の種類列で閉じた由来の判定が成功すればそれを保持する。`BodyRanges` は、その閉じた全被覆と、各出現の記号側の全適格具体化の被覆を選言で分ける。任意の旧規則表の成功だけから、別に選んだ記号側の範囲の被覆は導けないためである。非空の種類列の判定は変えていない。

`S.OpenScopeForwardExamples.closed_extension` は全五形について旧 `acceptFn` の `unknownSource` と新 `acceptDef` の成功を結論する。`closed_conservative` は Top の閉じた契約の全五形で旧成功を計算し、保存的拡張の系から新 `Accepted` と旧 `BodyRanges` を得る。既存の `acceptBody_no_ranges`・`acceptDef_no_ranges`・`Accepted.def_body_no_ranges`・`Accepted.def_ranges_no_ranges` は、選択なしの前提を持つ同じ署名を保つ。最初の等号系の旧成功側は新しい保存的拡張の系を使い、残る系はこの等号系を使う。

`S.OpenScopeAccept.contextsBlock_length` は任意の局所文脈と本体で、文脈列と元の先行順の列が同じ長さであることを示す。`occurrences_zip_contexts_length` は出現列との zip が元の出現を切り捨てないことを示す。同じ五形の匿名例は、その zip の先頭射影が元の出現列に等しいことを示し、順序も確かめる。

### 止めずに進めた変更

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 群 E の実入口の二つの系 | 型付けの結論は準備後だが、結合した系が元の入力・本体を読んでいた | 支持・完成表・実現・整形式・main と保証の対象を準備後へそろえ、元の入力の健全性と名前の完全性を移す | 元の本体の型付けを新たに仮定する、準備後の型付けを元の型付けとして扱う | 準備が恒等なら元の形。既存の custom 表の main 証人と空の main の適用が読む |
| 空の種類列の受理 | 任意の旧規則表が受理しても、記号側が選ぶ別の範囲の被覆は導けない | 閉じた由来の成功を優先し、その同じ結論を保持して受理を広げる | 旧成功を失うままにする、旧成功から記号側の被覆を断定する | 任意の旧成功から新成功と同じ旧 `BodyRanges`。固定範囲の新受理も全五形で保つ |
| `DefinitionRanges` の内部契約 | 閉じた由来の被覆と、記号側の全具体化の被覆は前提が異なる | 二つの結論を選言で明示し、各成功分岐の既存の証明から構成する | 型注釈から局所の由来を作る、新しい被覆の信頼条件を足す | 空の種類列で閉じた由来が成功すれば同じ旧結論。選択なし四系も維持 |
| 内部行の名前の生成 | 元の核に同じ名前があると、解決しない呼出しまで新しい行を読む | 元の全定義・全実装メソッド・上位辞書の核と構成済みの行の名前を避け、最大の既存番号の次から必要な行だけを生成する | 生成番号を0へ固定する、元の内部名の呼出しを制限する | 型付けと範囲の規則は同じ。行を収集しない準備は恒等。既存行7と演算子が挿入する行12を避ける実準備の例が13を選ぶ |
| `BuiltinSource.resolved` の解決の有効性 | 手で構成した行が公開名を上書きすると、その公開名の固定のδを使えない | 内部行の接頭辞を満たす構成でだけ追加の解決を有効とし、満たさない構成の入力と本体をそのまま返す | 上書きされた公開名でも標準のδを仮定する、独自構成の検査自体を拒む | 範囲によらず同じ恒等分岐。公開名を上書きする構成の実準備の例が読む |
| `execution`・`infinite` の実行対象 | 準備後の脱糖を元の実行と呼ぶだけでは公開行の意味の保存を示さない | 元のプログラムの通常の脱糖と元の表で実行し、準備後との観測の対応を別に証明する | 処理系に解決済みの実行を前提とする、定義の展開だけで観測保存を結論する | 範囲によらず元の公開行を読む。準備が恒等なら同じ実行対象になる |
| 正常値の共通の観測 | 実入口を通る関数返却の例でも、名前解決は閉包の本体を変える | 値の対応の同値閉包を正常観測とし、失敗・終了・事象は厳密な一致を保持する | 生の閉包のコードの等号を同じ正常値とする、正常値をすべて同じ観測へ落とす | 既存の主な十言明と群 E の生の観測は保持。定数を区別し有限の項をそのまま読む具体の読者がある |
| 模倣の根の値引数 | 任意のラムダ構文を管理用の束縛へ持ち込むと、捕捉環境が増えて生の閉包の形が変わる | 実際の `valueOf?` が返す局所参照・定数・空の構成子を根の前提にし、実解析からその前提を証明する | 利用者の構文を制限する、元のプログラムの型付けを追加する | 範囲によらず同じ実解析から前提を供給。builder の実規則の置換像も同じ形であり、対応の保存に使う |
| `observations_preserved` の前提 | 収集した欄の行の適格性 `collected_valid_of_core` が、元のプログラムの宣言の型と取り出しの関数の条件を整形式から読む | 元のプログラムの整形式 `p.WellFormed` を前提に加える。具体の main では証明して供給する | 準備後の整形式から元の整形式を導く（本体の `Scoped` は解決で元の引数の一部を落とすため直接は従わない）、`Rows.Valid` を独立の仮定にする | 準備が恒等でも同じ前提を受け取る。恒等の分岐では使わない |
| `execution`・`infinite` の定義 | 群 E の主保証は標準の本体を結合した核で述べるため、観測の同値も同じ核で述べる必要がある | 元のプログラムを標準の本体と結合した核 `original` で定義し、`PredicateProgramObservations` へ移す | 結合しない `desugarProgram` の核のまま比べる（標準の関数本体を呼ぶ実行を対象にできない） | 標準の本体を引数で受ける。準備が恒等なら `resolved` と同じ核になる |
| 値・コード・状態の対応の構成子 | 初期の試作の `Code.floating`・`StateRel.floatingArgument`・`floatingApplication` は一つの公開判定だけを扱い、`Code.scalar`・`StateRel.scalarPhase` が全15 API を同じ形で扱う | 試作の構成子と、それだけを読む補題を除き、浮動小数点の判定も `Code.scalar` で表す | 二重の構成子を残す（全規則の場合分けが重複する） | 範囲によらない内部の関係の変更 |
| `structural_fail_operation` | `E_OpFail` は raise の誤りの型と節の誤りの型を別に持つ。補題は両者を同じ型に限っていた | 二つの型を別の変数にした | 補題を使わず個別に書く | 内部の補題の一般化 |
| `CheckInfer`・`CheckOpenInfer` の外側の型 `outerType` | 篩が束縛した実引数を指す結果型を外側へ移すと、別の値を指す篩になり、部分型の問い合わせが証明できない。取り出しの関数の呼出しを期待型のない位置に書くと、整数・String・Float などの欄で拒否された | 束縛した値を指す篩の層を除いてから番号を戻す。推論の案内の生成だけを変え、再検査は変えない | 実引数の項を代入する（前提に束縛した値と実引数の等号がなく、問い合わせは閉じない）、利用者に証明書を求める（書ける形を狭める）、検査器の部分型の規則を変える | 範囲によらない。篩が束縛した値を指さない型は以前と同じ型になる |

この表の受理の拡大は、取りまとめが設計者の見直しの対象として集める。内部の長さ補題と値の四条件の証明は、型付け・Step の規則を変更しない。

### 重ねた表から公開呼出しの main への接続

`S.PredicateOverlayValues.standard_values`・`predicates_values` は、重ねた表の `Builtins.ValueAssumptions` の四条件を構成する。`prepared_standard_values`・`prepared_predicates_values` は実準備の分岐を扱う。`S.PredicateProgramGuarantees.accepted_standard_property1` が前者を `PredicateProgramSemantics.accepted_property1` の `hvalues` へ供給し、`S.CheckPredicateProgramExamples.path_property1` は公開の取り出しの呼出しを含むプログラムで実際の受理と性質1を結論する。

`S.PredicateOverlayExternal.response_eq` は、型とエフェクトの意味が一致する表の間で、外部の引数と受信値の形を運ぶ。公開と内部の署名の等号は仮定しない。`S.PredicateOverlayTable.builtins_eq` はこれを使い、内部の行の `rows.Valid` とプログラムの整形式の下で、`predicateOverlay (Table.builtins T []) rows = Table.builtins T rows` を全欄について示す。値の四条件と表の条件は別の証明である。

`S.PredicateMainExamples.entry_succeeds` と `main_guarantees` は仮定なしである。main の条件に公開名の `String.charactersIn("a", 'a', 'z')` を書き、両分岐は Unit を返す。標準の関数本体と外部宣言を含むプログラムで実入口を通し、群 E の `checkProgramAccepted_main` から `Accepted`・`ProgramGuarantees`・空の効果での `MainGuarantees` を同時に結論する。外部宣言のないプログラムへの制限は加えていない。

### 模倣の補助の局所検査

`S.PredicateSimulation.Trace` は、一段の実行の対応を有限の `Steps` によって表す。対応する側が段を進めないときは、元の段が事象を出さず順位を減らすことを要求する。両方向の対応から、同じ有限の事象列、非停止、無限実行の存在、有限の事象列の後の非停止、終端観測と効果の保存を導く補題を単独の Lean で検査した。これは実際の公開行と内部行の模倣の前提を証明する部分とは区別し、独立の信頼条件を実入口の系へ残す根拠とはしない。

`ScalarPhase.forward`・`backward` は全15 APIの公開行について、引数の管理用の束縛の全途中状態から実際の段を対応させる。`ScalarInputs.public_delta` は `public_deltas.path`・`host`・`characters`・`floating` を使い、`public_delta_values` がそれらを実際の標準行へ接続する。Float32.isInfinite は既存の標準行も同じ対応に含める。必要な対象の型は、対応先の実状態の `StateTyE` と同じ対応先の整形式・型付け・Coreから、登録行の実引数の逆転で供給する。元のプログラムの型付けは仮定しない。

`PredicateSimulationLookup.table_lookup` は判定の完成表の合成済みの標準行が常に優先されることを、`overlay_lookup`・`overlay_fresh_lookup` は接頭辞又は未登録性で標準行を保持することを示す。`source_lookup` は解決が有効な全構成の `RowLookup`、`prepared_lookup` は実準備の新鮮さから準備後の同じ条件を供給する。内部行の `Rows.Valid` はこの標準行のlookupには要しない。

`PredicateSimulationHttpShape.request_shape` は、標準の `Includes.extends_.consClosed` を使って要求とヘッダの全構成子を固定し、型付きの要求全体の構造を導く。`request_value_equal` は対応先の要求の型付けと変性の適格性から両側の生の値の等号を得る。`HasHttp` だけでは同じデータ型の別構成子を排除しないため、既存の `Includes` の条件を実際に使う。新しい宣言の信頼条件や外部宣言の制限は足していない。

`PredicateSimulationAt.at_inputs_equal` は、対応先の At の許容と捕捉・ストアの型付けから、閉じた起点・pattern・入力の等号を構成する。`at_prepare_equal` は核の実際の準備を展開し、両表の `valKind` と `valContent` が一致するとき、その全結果を等しくする。`at_ok_forward`・`at_error_forward`・`at_prepare_error_forward` は、それぞれ具体の元の結果の状態と、対応先の実際の段を対応させる。`at_prepare_noMint`・`at_check_noMint` は、保存する原入力にない組込み名を作らないことを示す。これらは局所検査で終了0・警告なしである。

投影の形成の境界を[型パラメータの欄の確認用入力](resume10/generic-field.lean)で調べた。`Box[a]` の欄 `value: a` を Float で具体化して取り出し、公開の `Float.isFinite` へ渡す形は、投影の解析も行の候補も `none` となり、呼出しを保つ。元の公開署名で `Check.checkExpr` が成功することも確認した。解析は宣言の欄の sort を読むため、この例は不適格な投影の行を収集する反例にならない。全プログラムの実入口の検査とは区別する。最終の全環境の監査には、この確認用入力の全宣言も含める。

`PredicateSimulationPatternAvoid` は、`ValueAvoid.matchVal`・`ValuesAvoid.matchList`・`ValueAvoid.firstAlt`・`ValuesAvoid.selectSlots` と腕・節・解放する継続の検索について、元の値とコードにない内部名を作らないことを証明した。公開診断の木の値と保存された原入力を区別し、後者から名前の不在を無条件に結論しない。単独 Lean は終了0・警告なしである。

`AdministrativePath` は束縛・返却・取り出しの呼出し・照合開始・腕の本体の選択・返却の印の六つの具体規則からなる。全ての対象のプログラム・表・環境に対する実行の一段、一意な到達先、自然数の順位の下降を証明し、経路全体を実際の事象なしの有限実行へ写す。`StateRel.administrative` は、この経路を元の状態の前に置く。`terminal_forward` は原終端の同じ観測を、`terminal_backward` はその経路を経た同じ終端観測を返す。`GetterEnvironment` は同じ取り出しの実定義を供給し、独立の実行の信頼条件を要求しない。管理経路と追随後の Runtime・Terminal は局所検査で終了0・警告なしである。

`PredicateSimulationProgramAvoid` は、実collectorから元の核の全本体と標準の本体を結合した核へ `ProgramAvoid` を供給する。`source_program_avoid` は元の定義・実装・メソッドの有限な名前の完全性を読む。上位辞書は実際の辞書の生成が組込み名を持たない補題から閉じる。標準の130本体は、関数名の付替が組込み名の一覧を変えないことを構文の相互帰納で示してから、各元本体の短い一覧を照合する。番号の範囲や台帳の件数をLeanで評価していない。`collected_linked_avoid` は実収集の新鮮さと接頭辞を使い、`main_start_avoid` は実mainの初状態の `NoGeneratedKeys` を仮定なしで供給する。局所検査は終了0・警告なしである。

異なるdata型の取り出しをつないだ[確認用入力](resume10/mismatched-projection.lean)では、実解析が投影の候補を作り、実収集がその1行を作ることと、実入口が `call signature is invalid` で拒否することを確認した。拒否の位置は `[0,0,1,0,1,0]` である。この入力は受理される反例にならず、拒否した署名の箇所を一般の局所の型導出の証明と取り違えない。`Ty.LeQ` の実規則では、篩の含意はデータ型の名前を変更しない。全行の経路の適格性は、元のプログラム全体の型付けではなく、符号化した内部呼出しが保存する元の取り出しの局所の型導出から供給する作業が残る。

`PredicateSimulationPipeSafety`・`PredicateSimulationOpenPipeSafety` は、閉じた表層と開いた表層の全74の式の規則、各七つの相互判断と関数本体から、内部にあるパイプの形の条件を供給する。`BodyTyR.predicate_pipe_safe` が空と非空の範囲文脈を同じ `SafeBlock` へ結ぶ。interpolation の変換の関数の未使用の尾部は型付けで制約されないため走査せず、実脱糖が読む直接の頭の一致で扱う。受理や利用者の構文は変えていない。両モジュールは局所Lean終了0・警告なしである。既定の200000 heartbeatのwhnf timeoutを再現したため、閉じた七相互の証明、開いた二つの形の反転と七相互の証明に限って400000を指定した。

`PredicateSimulationProjectionDeclared.projection_route_declared` は、既存の `PrimSig.Scoped` の宣言の条件から、Booleanの自己値と受け手の文脈における同じ `routeTerm (.var 1)` の `Term.Declared` を取り出す。任意の型パラメータ数を記号のまま保ち、文脈を二度拡張する値の変数の移動も補題で消去する。局所検査は終了0・警告なしであり、表の経路の条件の集約へ渡した。

`checked_method_names`・`collected_linked_avoid_checked` は、元の実装の名前の完全性と準備後の実装の型導出から、元のメソッドの名前の完全性も供給する。結合した元の核の `ProgramAvoid` の系へ、独立のメソッドの完全性を新たな信頼条件として残さない。局所検査は終了0・警告なしである。

### 中間の結合確認

全担当の本番の編集と単独Leanを止め、新しい模倣の補助全件を既定importへ接続して、共有ロックを取った既定の `lake build` を実行した。初回は投影の既存の例の `source_prepared` が失敗した。生成名を避ける元の核の名前の収集が、例の局所的な `cbv_opaque` 指定で止まるためである。実際の名前の一覧が `["String.charactersIn"]` である `rfl` の補題を、準備の計算の前に書換で供給した。公開した例の言明や準備の定義は、この追随で変更していない。

修正後の対象の単独Leanは終了0・警告なしで、既定ビルドの再実行も **終了0（1660 jobs、33.81秒）** で通った。検査の前後の入力のfingerprintは一致した。初回は143.33秒・終了1である。生の出力は一時領域に置き、成功時の188730バイトとSHA-256 `4e79721128d1430a4eaa6ffae9f2b9f33efaee9a310f5683739458f4105199c7`、失敗時の485310バイトとSHA-256 `fef714e2e88810f24cf1f7b4f8f20656ca0eb58dd86016921dcf85f566b3bc3a` をそれぞれの小さい記録に残す（[成功](resume10/checkpoint-summary.json)・[初回](resume10/checkpoint-attempt1-summary.json)）。既存の実行ファイルのリンクでは、システムのライブラリの検索ディレクトリがない旨の警告が再表示された。

この区切りでは、全構文の脱糖の対応、全 `StateRel` の実一段の集約、収集した欄の行の適格性の接続、実入口からの観測の同値が残っていた。これらは後の区間で完成した。この区切りの既定ビルドを最終の検査・監査・照合の代わりとは数えない。

### 言明の差と検査

群 E の後半は3モジュールを追随させ、既存の言明の署名は `S.checkProgramAccepted_guarantees` と `S.checkProgramAccepted_main` の2件を変更した。`Accepted Ai q p` と実入口の成功は元ソースのまま、型付けと保証の対象は準備後へ移した。既存の `CheckedMainExamples.main_guarantees` は仮定なしの同じ言明を保つ。ほかの追随は証明の変更と private な準備の恒等性の補題である。

群 D の旧308言明は承認済み2差、群 E の旧617言明は再開9までの18差と一致し、今回の追加差は0である。主な十言明、核の Step、通常と開いた表層の規則は変えていない。新しい言明の一覧と最終監査の件数は「作業末の検査」に記す。

局所検査では、群 E の未生成の依存のため最初の import が失敗した後、必要な依存を単独の Lean で一つずつ構築した。実入口の系・既存の仮定なしの main 証人・値の四条件の二モジュール・path の性質1の例・受理の四モジュール・確認用入力は、修正後の対象検査で終了0を確認した。これらを既定ビルドや全環境の監査の代用とは数えない。最終の既定ビルド・全環境の監査・照合はコードと写しを固定してから各一度実行する。

RSS は未取得（計画上の非採取）。指定からの操作のずれとして、受理担当が読み取り専用の `git diff --check` を一度実行した。状態を変える Git 操作はなく、その後は Git を呼ばない指示を再確認した。

単独 Lean の終了確認前に次の検査を起動する逸脱も一件あった。`PredicateSimulationCongruence` の running 応答の後、終了を回収せず `PredicateSimulationSourceRoots` を起動した。両方は終了0・警告なしで、重複時間は未計測である。依存が古かった可能性を除くため、前者の終了0（0.69秒）を回収してから後者を起動し、後者の終了0（0.73秒）を確認した。以後は終了コードの回収まで検査枠を保持する。これらの担当の自己確認を独立レビュー済みとは扱わない。

### 担当の区間

再開10は二つの担当が続けて行った。Codex の担当は 02:04 に起動し、06:03 に利用の上限で停止した（約4時間）。上の各節のうち「各所見の処置」の表の重1・中4の行と、「止めずに進めた変更」の後半の四行を除く部分は、この区間の記録である。Claude の担当は 06:14 から引き継ぎ、作業木の途中の成果を捨てずに続けた（以下の各節）。Claude の区間の終わりは「所要」に記す。

引き継いだ時点の作業木は既定ビルドを通らなかった。`PredicateSimulationInvariant` の `Value.simple_of_close_constant` が構成子の不一致を閉じておらず（`reduceCtorEq` の指定の不足）、既定 import に入っていない `PredicateSimulationSource`・`SourceShape`・`ProjectionValidity` は単独の検査だけを経ていた。前者を直し、三つを既定 import に加えた。

### 模倣の完成と観測の同値

以下の `S` は `Benitoite.Release.Refinement.Surface`、`M` は `S.PredicateSimulation` を表す。

`M.Setting` は、元の核と準備後の核の本体の対応 `ProgramRel`、元の核の生成名の不在、準備後の核の整形式・型付け・効果の条件・表の核の条件、起点環境の妥当性、変性の適格性、生成した欄の行の `Valid`、標準の包含を束ねる。どれも実入口の受理から供給する（下の `observations_preserved`）。

`M.Setting.forward` は `Trace.Forward P B Q D σ (InvariantRel …) (administrativeRank source)` を示す。`M.StateRel.forward` が、元の状態の全ての `Step` の規則について、準備後の対応する有限実行・到達先の対応・元の到達先の生成名の不在・準備後の到達先の型付けを構成する。構造の規則は `forward_ret`・`forward_let`・`forward_app` など表層の対応 `Code` の構成子ごとの補題が扱い、`Code.scalar`・`Code.projected` と `StateRel.scalarPhase`・`projectedApplication`・`administrative` は既存の段の補題（`ScalarPhase.forward_invariant`・`projected_root_forward`・`projected_application_forward`・`ForwardResult.administrative`）へ渡す。準備後が段を進めないのは管理用の段だけであり、そのとき `administrativeRank` が減る。

`M.Setting.backward` は逆向きの `Trace.Forward` を示す。`M.StateRel.backward` は、準備後の全ての規則について、元の状態から同じ事象を出す空でない有限実行を構成する。元が管理用の途中にあるときは `BackwardResult.prepend` で管理用の段を先に実行する。応答を読む段は、公開の行と内部の行の δ の等式 `public_deltas` を `ScalarInputs.public_delta` を通して使う。どちらの向きも元のプログラムの型付けを要求しない。

`M.source_expr`・`source_exprs`・`source_holes`・`source_arms`・`source_clauses`・`source_block` は、表層の全ての構文の相互帰納で `Code p rows (desugarExpr op pos e) (desugarExpr op pos (resolveExpr rows p e))` などを示す。前提は解決後の構文の `SafeExpr` である。公開の行の呼出しは `resolveCall_source_code`、パイプの右辺の呼出しは `pipe_call_resolution`、部分適用の内部呼出しの直接形は `directValueCall_resolve` が扱う。`M.ResolvedSafe.of_checked` は準備後の全本体の型付けから全本体の `SafeBlock` を得る。`M.resolved_program_rel` は `ProgramRel p rows (linkProgram base op p) (linkProgram base op (resolveProgram rows p))` を構成する。

`S.PredicateProgramSemantics.observations_preserved` は、`checkProgramAccepted_main` と同じ前提に `p.WellFormed` を加え、main の開始 `.run mainClosure [] Store.empty` から次の四つを結論する。

- 全ての有限の事象列と終端の観測 `observe q p` について、`execution base q p σ start events last` と、`resolved base q p` と準備後の表での `Steps` の同値
- 無限の実行の存在の同値（`infinite` と `InfiniteExecution`）
- 同じ有限の事象列の後の非停止の同値
- 同じ事象列・終端の観測に加え、全事象の `Event.Covered` の同値（元の表と準備後の表）

準備が恒等なら二つの核と表は一致する。内部行を重ねる準備では、`prepare_resolved` が解決の有効と収集した行の表を与え、`Setting` を構成して `InvariantRel.observations`・`Trace.infinite`・`Trace.diverging_prefixes`・`InvariantRel.effects` を適用する。効果の被覆の一致は `overlay_coverage` が生成名の新鮮さから供給する。`S.PredicateMainExamples.main_observations` は、公開の `String.charactersIn` を条件に書いた main に適用した、仮定なしの事象列と終端の観測の同値である。元のプログラムの整形式もこの例で証明した。

処理系は名前解決を行わず、公開の呼出しを公開の行の δ で実行してよい。その実行は `execution` の実行関係であり、`observations_preserved` によって解決後の実行と同じ観測を持つ。型付けと主保証は解決後の核について述べる。意味を解決後のプログラムで定めることを処理系への前提にしない。01-12 にも同じことを書いた。

### 不要になった補題の整理

全規則の集約で使わなかった補題と、初期の試作の構成子を除いた。`Code.floating`・`StateRel.floatingArgument`・`floatingApplication`・`FiniteRegion` と、それだけを読む `finite_*` の補題、`floating_code` の旧い形を除き、浮動小数点の判定も `Code.scalar` で表した。宣言の本文中の名前の出現を数える台本で読者のない宣言を探し、二度の走査と一件の手作業で50件を除いた（固定の応答の `*_provider_delta` 群、`structural_resume` など一般形に置き換えた構造の補題、`prepared_lookup`・`prepared_coverage` など）。一度目の走査は名前に続く `.mp` などを別の名前として数えたため、読者のある三件（`valuesNames_avoid`・`values_names`・`simple_cons`）を誤って除き、元の本文に戻した。除いた後の既定ビルドは警告なしで通った。`GetterEnvironment.link` は `resolved_program_rel` が読む。

### 作業末の検査

`resume10/checks.py` で既定ビルド・全環境の公理監査・照合を一度ずつ実行した。生の出力は一時領域に置き、要約を `resume10/*-summary.json` と `verification.json` に置いた。

| 検査 | 結果 |
|---|---|
| 既定ビルド | 終了0（1678 jobs）。直前のビルドで全モジュールを構築済みのため 0.40 秒。188591 バイト、SHA-256 `505c5b04e85f21f566dfdd9c8e6713b35746c7f0c041f839ec5e98f0be2e068c` |
| 公理監査 | 終了0、142.36 秒。128566 宣言、所属を記録した対象 156 モジュールの 22008 宣言（private 13761）と確認用入力の 649 宣言。公理は `propext`・`Classical.choice`・`Quot.sound` だけ。204385741 バイト、SHA-256 `63250543904b1afc61ee1695ce3028461904d97431bddac2d507c2f8c908a9d4` |
| 照合 | 終了0。対象モジュールの既定 import、各ファイル 100 KB 以下、群 D の旧308言明の追加差0、群 E の旧617言明の追加差0、再開9の2425言明の変更0・移動2（`public_deltas`・`observations_preserved`）・削除0・追加1257 |

公理監査の台本は二点を改めた。`#print axioms` が実行中に実現する照合の補助名のうち、マクロのスコープを持つ名と、監査のファイル自身の private の名前空間（`_private._stdin.0`）にできて lookup できない 62 件（`CheckInfer` の照合の等式と splitter）は対象に数えず、`AUDIT_UNRESOLVED` として名前を記録した。どれも元のソースの宣言ではない。最初の二回の起動はこの名で終了1となり、改めた三回目を作業末の監査とした。

`PredicateSimulationAlgebra`・`Typing`・`PipeSafety`・`OpenPipeSafety` の `maxHeartbeats 400000` の指定は、除いた写しを単独の Lean で検査し、四つとも既定の 200000 で timeout することを確かめた。

### 言明の差（再開10の分）

再開9の言明のうち変えたものはない。`observations_preserved` は、定義の展開だけの旧言明を除いた後、模倣から導く同値として `PredicateProgramObservations` に置いた（移動・変更）。`execution`・`infinite` は再開10で導入した定義であり、結合した核の定義に改めて同じモジュールへ移した。群 E の後半の二言明の変更は上の「言明の差と検査」のとおりである。主な十言明、核の Step、通常と開いた表層の規則は変えていない。

### 所要と取りまとめに判断を求める点

Claude の区間は 06:14〜07:45 頃（約1時間30分）であり、再開10の全体は約5時間40分である。上限の16時間の内にある。RSS は計画どおり採取していない。

- `observations_preserved` は元のプログラムの整形式 `p.WellFormed` を前提に加えた。準備後の整形式は既存の主保証の前提である。元の整形式を実入口の検査から導くか、前提のまま残すかの判断を求める（止めずに進めた変更の表）。
- 再開10で受理を広げた変更（空の種類列での閉じた由来の成功の保存）は、引き続き設計者の見直しの対象である。
- 公理監査で数えなかった 62 件の補助名の扱い（上の検査の節）の確認を求める。

## 取りまとめの追記（再開10の処置の確認の後）

- RV-L70.d3 の「再開10の処置の確認」は可（軽4・情7・情8）。
- 軽4: 再開10で足した `maxHeartbeats 400000` の指定は、4つのモジュール（`PredicateSimulationAlgebra`・`PredicateSimulationTyping`・`PredicateSimulationPipeSafety`・`PredicateSimulationOpenPipeSafety`）に計8か所ある（2・2・1・3）。上の段落の「四つ」はモジュールの数である。既定の上限での timeout はモジュールごとに確かめたもので、指定ごとには確かめていない。読者のない補題を除いた件数（50件）は、担当の数えたものであり、独立には確かめていない。
- 情8: 監査の台本は、マクロのスコープを持つ名前を対象から外している。外した件数の記録と、どれも `axiom` でないことの照合は、群 H の段全体の公理監査（L70.46）で行う。

### 結合の追随（群 K2 との結合 e9f7522a の後）

取りまとめが m014/l70.d3 に san_benito（d9cf242d、群 K2 を含む）を結合した後、既定ビルドが失敗した。群 K2 は取り出しの関数の宣言 `accessorDecl`・`accessorDef`・`accessorLink` に構成子の列の引数を足し、`Program.declarationsFor` と脱糖はその列に `accessorConstructors p.dataConstructors cd k` を渡す。`accessorRet` は String・Float などの全 sort の欄で、結果を欄との関係で篩う。群 K2 の定義は変えずに、次を追随させた（08:10〜08:25）。

| モジュール | 追随 |
|---|---|
| `PredicateProjectionFixture` | 取り出しの署名を `accessorConstructors program.declarations.dataConstructors` を渡す形にした。String・Float の欄が観測できる欄になったので、`AccessorOk` の照合の経路の事実と欄の関係の事実の `FactsWF`（WF・Sorted・Declared）を二つの欄について構成した。data の欄は構成子の列が空なので観測しない |
| `PredicateGeneratedNames` | `accessor_names` を任意の構成子の列について述べる形にした（本体は列によらない） |
| `PredicateSimulationProjectionInputs` | `GetterEnvironment.lookup` の取り出しの定義に、元のプログラムの構成子の列を渡す |
| `PredicateSimulationAdministrativePath` | `getter_specialized` を任意の構成子の列について述べ、取り出しの呼出しの段で同じ列を使う |
| `PredicateSimulationProgram` | 脱糖の取り出しの定義の lookup の式を新しい形に合わせた |
| `FieldCheckerExamples`（群 K2 の例） | 群 D が足した `AcceptInput.openRules` の既定値を使うため、無名の構成子を欄名の構成に改めた。値は変えていない |

これらの後の既定ビルド（共有ロック、08:18〜08:20）は、`CheckPredicateProjectionExamples` だけで失敗した（他の全モジュールは構築済み。この例を import するのは根だけである）。失敗した言明は、欄の判定を条件に置いた両枝の受理の例 `text_branches`・`nested_float_branches` などである。原因を局所の評価で確かめた。String の欄の取り出しの関数の呼出し `Predicate.Box.text[Unit](x)` は、単独の `Check.checkExpr` でも `type or certificate check failed` で拒否される。推論が作る問い合わせは一件で、前提は結果の篩 `x0 =ₛ field(x1) ∧ …`、目標は同じ形で受け手が `x2` を指す `x0 =ₛ field(x2) ∧ …` であり、`guideDecision` は rejected になる。Float の欄 `Predicate.Box.number` も同じく拒否され、篩のない data の欄 `Predicate.Outer.inner` の呼出しは受理される。群 K2 で String・Float の欄の結果が篩われる前は、この問い合わせは生じなかった。群 K2 の受理の例は、交換の証明書を入力に与え、期待型のある末尾位置で同じ形の呼出しを検査している。

この例を通すには、検査器の呼出しの規則が作る問い合わせの番号の対応を直すか、例の入力に交換の証明書を与える必要がある。前者は検査器（群 D の受け持ちの外）の変更、後者は String・Float の欄の取り出しを条件に書く利用者のプログラムが証明書なしには受理されなくなることを例で認めることになり、利用者の書ける形を狭める。どちらも依頼の止める条件に当たるので、08:25 に止めて取りまとめの判断を求めた。

#### 取り出しの関数の呼出しの拒否の原因と修正（08:25〜）

取りまとめの判断（案1、検査器の問い合わせの生成を直す）を受けて、原因を確かめた。`CheckInfer` の呼出しの規則は、実引数を k 個束縛した文脈で結果型 r を計算し、外側の文脈の型を `outerType k r`（値の番号を k だけ戻す改名）とする。再検査は r から外側の型を k だけ持ち上げた型への部分型を求める。r の篩が束縛した実引数を指すとき、番号を戻す写像 `unshiftValue k 0` は自然数の引き算で束縛の番号を 0 に潰すので、篩は外側の文脈の番号 0 の値を指すようになる。そのため部分型の問い合わせは、前提が束縛した実引数 `x1`、目標が外側の値を持ち上げた `x2` を指す。二つの値を結ぶ事実はないので、問い合わせは証明できない。番号の持ち上げ自体は正しく、外側の型を作るときに束縛した値を指す篩を持ち出したことが誤りである。

整数の欄の取り出しも同じ誤りを持っていた。基準の版の `CheckInfer` に一時的に戻して検査すると、期待型のない位置と条件の判定の実引数に整数の欄の取り出しを書いた本体は、String の欄と同じく `checkProgram` で拒否された（確認の後に修正した版へ戻した）。群 K2 より前の例は、取り出しを期待型のある末尾位置（`exprAs` の経路）でだけ呼んでいた。この経路は期待型への問い合わせを作るので、誤りは現れなかった。線形算術で偶然に閉じていたのではない。群 K2 が String・Float などの欄の結果を篩ったことで、条件の判定の例が初めてこの経路を通った。

修正は `CheckInfer` と `CheckOpenInfer` の `outerType` に限る。外側へ移す前に、束縛した値（篩の中の番号 1〜k）を指す篩の層を除く（`dropBound`）。除いた後の型は元の型の篩の一部だけを持ち、再検査の部分型は篩を捨てる規則で閉じる。束縛した値を指さない篩はそのまま残す。`CheckInfer` は案内を作るだけで、受理から型付けへの健全性は `checkExprAt` の再検査と `guideSound` が保つ。検査器の規則・`Entails`・群 K2 の定義（`FieldFacts`・`FieldRelations`・`accessorRet`）は変えていない。証明の追随は要らなかった。

`Surface.FieldAccessorEntryExamples` を足した。交換の証明書を持たない入力で、整数・String・Float・Decimal・構成子の関係を持つ data の欄の取り出しを、期待型のない位置（評価して捨てる）と条件の判定の実引数に書いた本体を、`checkProgram` と `checkProgramAccepted` が受理する（`integer_accessor_checked` など五件）。欄について何も知らない値の取り出しを文字集合の契約の戻り値に置いた本体は拒否する（`unproved_contract_rejected`）。`CheckPredicateProjectionExamples` の欄の判定の両枝の例と、群 K2 の `FieldCheckerExamples` の受理の例は、修正後も通る。

修正の判断は「止めずに進めた変更」の表の最後の行に記す。

#### 修正後の検査（08:46〜）

検査の台本は [resume10/merge_checks.py](resume10/merge_checks.py) である。変えたモジュールは、上の表の六つに `CheckInfer`・`CheckOpenInfer`・`FieldAccessorEntryExamples`（新規）・`CheckPredicateProjectionExamples`（証明の追随なし）を加えた十である（[resume10/merge/audit-modules.json](resume10/merge/audit-modules.json)）。生の出力は大きさと SHA-256 だけを残す。

| 検査 | 時刻 | 外側の時間 | 終了 | 生の出力 |
|---|---|---|---|---|
| 既定ビルド `lake build`（共有ロック、1684 の作業） | 08:46:24〜08:52:51 | 386.57 秒 | 0 | 188554 バイト、`bd5c82317ae4edc54d187c8a5b4a5608c60719ea8b02b1ec4d8186f0602c360f` |
| 公理監査（共有ロック、`lake env lean -M 12288`、全環境から十モジュールの宣言を選ぶ） | 08:53:01〜08:55:06 | 125.60 秒 | 0 | 94885207 バイト、`8905d619332cb50e586e55537f1b6e5ca385bbd8ce6a33864b8a57b8fc423b10` |
| 照合（[resume10/merge/verification.json](resume10/merge/verification.json)） | 08:56 | — | 0 | — |

ビルドの記録に `error:` はなく、変えたモジュールの警告もない。検査の前後で formal/ と二つの設計書の章の SHA-256 の指紋は一致した（`6a6d9ab3b769ca5b5dfb838af2129e3787dab7cabd780613e36595aff22ae1ac`）。公理監査は到達する 130969 件の宣言を対象とし、十モジュールが持つ 6290 件の公理の集合は、なし 2449・`propext` 3334・`Quot.sound, propext` 9・`Classical.choice, Quot.sound, propext` 498 である。`sorryAx` と新しい公理はなく、解決できない名前は 0 件であった。必須の名前（[resume10/merge/required-names.json](resume10/merge/required-names.json)）はすべて対象に含まれる。結合の版 e9f7522a との言明の差は、`PredicateGeneratedNames.accessor_names` と `PredicateSimulationAdministrativePath.getter_specialized` の変更（構成子の列の引数を足した）と、新規のモジュールの六件だけである。`CheckInfer`・`CheckOpenInfer`・`CheckPredicateProjectionExamples`・`FieldCheckerExamples` の言明は変わっていない。

#### 依存する篩を代入で残す案の確認と停止（09:05〜）

取りまとめの判断（実引数が外側の変数か閉じた値なら、結果型の篩の束縛した番号へ代入して外側へ移す）を受けて、実装の前に、再検査がその案内を受理できるかを確かめた。代入した外側の型 b に対し、呼出しの規則 `E_CallDirect` の再検査が求めるのは、実引数を束縛した文脈での `r ≤ b.shiftV k 0` である。r の篩は束縛した実引数 `x1` の欄を指し、b の篩は外側の受け手 `x2` の欄を指す。文脈の事実は、束縛した値の型の篩と外側の事実だけであり、`x1` と `x2` を結ぶ事実はない。

この問い合わせは、期待型のある末尾位置で戻り値の契約を欄の関係そのもの（`accessorRet` と同じ篩）にした本体が作る問い合わせと同じ形である。局所の確認（[resume10/merge/substitution-probe.lean](resume10/merge/substitution-probe.lean)、`lake env lean -M 12288`、終了0、約4秒）で次を確かめた。

- String と整数の欄のどちらでも、その本体を証明書なしの `checkProgram` は拒否する。
- 実引数の型を自己の等号で篩って `x1 =data x2` を前提に足しても、自動の候補 `CheckPropositional.candidate` は、String と整数のどちらの欄の関係も移さない。

論理の核の等号の証拠 `EqProof.checkRaw` は、仮定の等号を整数の等号（`.integer` の型式）でだけ使い、欄の合同 `.field` は内側を構造の一致でしか認めない。そのため、data の値の等号から欄の観測の等号を導く証明書は、証明書を与えても作れない。

したがって、代入で作った型は再検査で常に断られ、取り出しの呼出しは再び拒否される。断られたら `dropBound` に戻す形にすると、結果は今の版と変わらない。依存する篩を残すには、呼出しの規則で実引数の束縛に外側の値との関係を与えるか、論理の核に data の等号による欄の合同を加える必要がある。どちらも既存規則・`Entails` の変更であり、止める条件に当たるので、実装せずに止めた。この区間では formal/ と設計書を変えていない。

レビューの軽5の処置（09:40〜10:21）: `FieldAccessorEntryExamples.unproved_argument_rejected` を足した。条件の実引数の位置で、欄について何も知らない値の取り出しを `String{charactersIn}` を要求する引数へ渡す本体を、証明書なしの `checkProgram` が断る。その後の検査はすべて終了0である。外側の時間は共有ロックの待ちを含む。既定ビルドは 789.40 秒（188560 バイト、`50307031d4a29dc524b9bee23ede9eec0f205e5a603a021e5070648d67d6ad34`）。変えた十モジュールの公理監査は 1142.26 秒（95264007 バイト、`0196bcf9aedf869f88f6d8ce0ff591d355a190ab7144a1c1bd67153d87375fbc`）で、6306 件に `sorryAx` も新しい公理もなく、解決できない名前は 0 件だった。照合も通った（指紋 `191ad74fef5a2f256d222f1ab0f839122aa206d3635031f98c0027993b2f6d76`）。`resume10/merge/` の要約は、この検査の結果で置き換えた。

# L40 群 G の作業記録

2026-11-04。実装担当の自己点検であり、段末の独立レビュー・設計者の受け入れは未実施である。

- 指定ブランチ: `m014/l40.g`。切り替え・作成・コミットなし。
- B_WORK: `fcde6fe216d35c3c74fcaa8d28164df063b6aa8b`。
- 群の開始: 2026-11-04 12:45:39 JST（03:45:39 UTC）。
- 見込み: 1時間45分〜3時間10分、上限6時間20分。
- 最大常駐量: 未取得（取りまとめが別に採取）。全比較は行わない。

| 単位 | 開始（JST） | 終了（JST） | 判定 |
|---|---|---|---|
| L40.36 | 2026-11-04 12:45:39 | 2026-11-04 12:54:33 | 照合済み。O135 の従来未完を保持 |
| L40.37 | 2026-11-04 12:54:33 | 2026-11-04 12:56:55 | 写し・読者・既定 import の照合済み |
| L40.38 | 2026-11-04 12:56:55 | 2026-11-04 13:08:02 | 監査・既定ビルド・最後のwork・レビュー資料を作成 |
| L40.39 | 別起動 | 未了 | 受け口を準備する。応答は今回の対象外 |
| L40.40 | 2026-11-04 13:08:02 | 2026-11-04 13:21:14 | 残件付きの集約資料・受渡し・最終照合を作成 |

## 変更の一覧

群 G の記録、段末の監査入力・台本・集約資料を新設した。01-12と07-04を各2箇所修正した。本番Lean・処理系の変更は0。

## L40.36 の照合

[集合](sets.json)・[全表](cases.md)・[64義務](obligations.md)・[33申し送り](handoffs.md)・[本番の証拠161箇所](unit-evidence.json)を生成した。再生成は `python3 -B <改造>/l40/g/reconcile.py --tmp <tmp>` と `python3 -B <改造>/l40/g/evidence.py`。型検査・公理監査の完了とはまだ数えない。

O135 の欄連鎖・decode済み Result の後処理は本番にあるが、任意の通常 decoder からの接続は E の sources-u25.md と obligations.md で従来から未完として残っている。再開6で閉じた16行は精密 getter9と正常篩7であり、この接続を含まない。従来の未完を閉じたと読み替えず、O135 と O022/O034/O144への影響を記録した。群が閉じたと記録した言明への反例を発見したという扱いではない。取りまとめに段末の扱いを確認する。

再生成台本の初回は、response の正しい名前が response_math/minMax_response である二箇所と、二つ目の表の見出し／行数を修正して再実行した。本番の修正はない。最終の両台本は終了0。単位時刻の最初の追記用 Python は文字コードの構文誤りで起動せず、同時点で修正して書き直した。

## L40.37 の写しと読者

01-12 と 07-04 の StandardSignatureExamples・StandardEqualityResponse の説明で、工程の略号 F06 を「応答契約」へ置き換えた（二文書各2箇所）。宣言や保証の範囲は変えない。`text` ブロックは変更0。変更前後の SHA-256 は [snapshot-changes.json](snapshot-changes.json)。本番の Lean の変更0。

[snapshots.py](snapshots.py) は十移送の言明を群 E の固定記録と照合し、10件とも一致した。写しの18個の Lean ブロックは、12個が全体の字面、5個が途中の補題・構成子を省略した抜粋、1個が本文で定める像 ν を使った close_value_typed の説明である。後者は式の各前提と像の定義を本文と本番で照合した。規則・事実の形成、同じ捕捉・固定 σ、正常値と失敗、全体と局所の範囲を読んだ。旧主定理・未知の失敗例を取り除かず、O135 の未完を写しで実装済みに変えない。

既定8対象のプロジェクト内の import 閉包は1001モジュール、Benitoite 自体は991モジュールである。開始版からの新303モジュールと変更26モジュールはすべて Benitoite の既定閉包にある。全329モジュールの直接の読者を readers-part-*.json に記録した。七つの交換実行ファイルの閉包は Refinement を含まず、既定ビルドと処理系との全比較を区別する（各閉包の件数・大きさ・SHA-256 は import-closure.json）。

写しと変更された本番329モジュールに、工程の ID・手元の絶対パス・新しい公理の宣言は0。sorry/native_decide/implemented_by/#evalも0。再生成台本の初回は、インデントのある theorem の抽出と、隣接する def の抜粋の区切りを修正した。元のコードや定理を修正して合わせていない。最終の snapshots.py は終了0、約5.0秒。これは公理依存の環境監査と独立レビューの代わりにはしない。

## L40.38 の監査と検査

段末の [axioms.lean](../axioms.lean) と [audit.py](../audit.py) を新設した。Benitoiteの既定の新旧991モジュール・78,801宣言を監査し、全名と#print axiomsの一対一を確認した。private・生成宣言と印字時の実体化を2周して追う。依存はpropext・Quot.sound・Classical.choiceの部分集合だけで、新公理0。変更329モジュールの13,660宣言と、新303モジュールの10,854宣言を区別する。全対象一覧の大きさ・SHA-256、仮定と定義の所在、旧主定理・未知の失敗例、監査の失敗と修正は [stage-results.md](../stage-results.md) の確定値を正とする。

監査は終了0、71.187秒。生出力16,967,327バイト、SHA-256 `75e1535eb61c1821348576b445efa608649c0f9759935ea2799c6d798c79a435`。全対象一覧5,144,266バイト、SHA-256 `3155dd9dcb642cc1ce1b2ba377ac9586e44c1c95bebf14f69e0639f6874f0014`。同じ生出力の一覧の分割形式だけを--collectで作り直し、全監査を重ねて実行していない。実署名153件と入口・定義・腕の二規則の実型15件を保存した。最初の補足署名入力はnormal_reply_factsの名前空間を誤り、実際のRefinement直下へ直した。

作業末の既定 `lake build` はformal/から対象指定なしで一度実行し、終了0、1252 jobs、0.265秒となった。workのdry-runは今回の文書差分にspec_tally・spec_examplesを選び、formal_buildを選ばなかったため、この別の既定ビルドをLeanの検査の証拠とする。work自体は `scripts/check.sh --level work --base fcde6fe216d35c3c74fcaa8d28164df063b6aa8b` を一度実行し、終了0、7.424秒。仕様対応の自己検査・集計、仕様例7成功・失敗0・無視0である。生出力の識別はbuild-check.json・selection-check.json・work-check.jsonに保存する。正式RSSは未取得（今回の指定により取りまとめが別採取）。全比較・Rust全lib/clippy・性能測定・大きな具体値を作る評価は実行していない。

## L40.40 の集約

段末の [stage-results.md](../stage-results.md) に64義務・33申し送り、59行の全表、F01〜F07の実署名、J40-1〜4、設計者の見直しの対象、後段の実署名、群ごとの外側の時間と未取得を集めた。[review-intake.md](review-intake.md) はL40.39の受け口だけであり、レビュー応答は未着手である。

技術50行のうち44行の局所証拠を照合し、O135・O022/O034/O144と、328外の未完に関わるO062/O065の6行は一部として保持した。継承6・運用3・他段1・共通4を区別し、全体の閉鎖は0行。通常decoderの同じResultから後処理へ接続する担当・時期と段末での扱いを取りまとめへ確認する。提供範囲の削減、新公理、主な十言明や型付けの変更を提案していない。

表の各行がその構文・演算に対応する宣言を直接指すように、case-evidence.jsonへ完全名と所在を追加した。Leなど変更のないモジュールも全監査の環境に名前があることを確認する。初回の宣言抽出は、変更モジュールだけの一覧を使ったための漏れと、Ty.VarianceOKの実所在がVarianceValidationである点を修正した。最終の再生成とverifyは終了0。本番の変更はない。

最終報告前の条件を [completion.md](completion.md) に一行ずつ照合した。記録の再生成はreconcile.py・evidence.py・snapshots.py、公理監査は一段上のaudit.py、最終の入力・リンク・記録サイズの照合は `python3 -B <改造>/l40/g/verify.py --tmp <tmp>`。verifyには開始時に一時領域へ置いた保護対象・本番のmanifestと、検査の生出力を使う。開始manifestの大きさ・SHA-256はstart-inputs.json、最終の全formal入力はaudit-inputs-part-*.jsonに保存した。

最終の分類表との照合で、328公開APIと別母集団の演算子107行のうち34行、構造値全体の%eq/%neも、Eの旧記録で独立未完とされ、後続の閉鎖の証拠を一行ずつ対応できていないことを追補した。additional-unresolved.jsonへ実名と元の不足を写し、O062/O065と全契約を読む行へ反映した。L40.29の整数の局所意味を、全BuiltinArgsの応答契約の代用としない。L40.36の初回照合の後の再点検であり、この追補の外側の時間は.40の内数として記録し、二重計上しない。

群Gの開始から終了までの外側の時間は単位の表に記す。読取り・編集・計算待ちを能動時間へ分離していない。初回の見込み1時間45分〜3時間10分と上限6時間20分は変更せず、この短い外側の時間から他段へ単価を掛けない。A〜F2の概数約18時間6分40秒、計画の約53分、レビュー・独立調査の約2時間28分50秒は段末資料で算入範囲を分けた。

## 単位ごとの外側の時間と最後の確認

| 単位 | 外側の時間 |
|---|---:|
| L40.36 | 8分54秒 |
| L40.37 | 2分22秒 |
| L40.38 | 11分7秒 |
| L40.40 | 13分12秒 |
| 群の合計 | 35分35秒 |

終了: 2026-11-04 13:21:14 JST。最終の記録照合はverification.jsonを正とする。独立レビュー・正式RSS・設計者の受け入れと、上記の独立未完は未実施／未了として引き渡す。


## 再開1: 既存 δ の算術名の受け口の調査

開始: 2026-11-04 13:24:02 JST（04:24:02 UTC）。指定された未コミット作業木を継承し、git の操作は行わない。

### 最初の30分以内の見込み

2026-11-04 13:26:14 JST。既存の定義と群D/E/F2の記録を読んだ時点の見込みであり、実装の完了を表さない。

| 単位 | 見込み | 前提・未確定の点 |
|---|---:|---|
| 演算子34行 | 整数14行は30〜60分。Float/Decimal/String20行は未確定 | 整数は既存integerDeltaとF2の分岐を使用できる。Float/Decimalの部分δに算術名の枝がなく、既存δだけという条件で閉じるかを先に判定する |
| 構造値全体のEquality | 45〜90分。ただし既存δの選定が必要 | structuralEqualはOption Boolの部分計算であり、全型付き入力でsomeとなること、実名のδへの接続は未証明 |
| O135通常decoder | 読み取り15〜25分、実装60〜120分（暫定） | recordProgram.defsは全てnone。postprocess_wellTyped/row_typedは実行の登録・通常decoderの返却との合成を含まない。通常decoderの同じResultをletFへ渡す接続と登録の有無を調べる必要がある |
| 照合・写し・公理監査・verify・work | 20〜40分 | 三件の閉鎖後に行う。独立レビューと設計者の受け入れの所要は不明 |

上の既知部分だけでも2時間50分〜5時間35分であり、Float/Decimal/Stringの未確定部分を加える前に停止条件を照合する。6時間を超える作業には進まない。

### 停止判定の準備

2026-11-04 13:26:14 JST。群DのStandardFloatのfloat32Delta/float64Deltaは分類と比較の部分表であり、算術名を受けない。StandardDecimal.decimalDeltaも比較・丸め・変換の部分表であり、%Decimal.add/subtract/multiply/divide/negateの枝がない。formal内の実名と演算定義を検索したが、これらの算術を受け持つ別の既存δは見つからなかった。この差を、小さな型付き入力と既存δの計算により確かめてから停止理由として確定する。新しい演算の算法・δは追加しない。


### 再開1の停止理由と反例

修正した反例が型検査を通り、13:28:18 JSTにprivateを含む7宣言の公理依存の確認も終了0となった。旧反例の台本（現在の[対照](resume2-contrast.lean)とは異なる）と[検査の記録](resume1-obstruction-check.json)を保存した。本番Leanへの追加・変更は0である。

- `float_add_missing` は、任意のP/B/Ψについて、原署名の二つのFloatゼロを持つBuiltinArgsを構成し、`float64Delta "%Float.add" [] [] [] ws`の応答が存在しないことを証明する。
- `decimal_add_missing` は、同様に表現可能なDecimalの0/scale 0を二つ与え、`decimalDelta "%Decimal.add" [] [] [] ws`の応答が存在しないことを証明する。
- `no_float_response` と `no_decimal_response` は、それぞれ「全BuiltinArgsから同じ既存δの応答存在」を否定する。型/Ground/AdequateResult/非exitを弱めても、応答存在の不足は解消しない。
- `addSignature` はoperators-r1-u28.jsonにあるleft/right・二入力・同じ結果型・空の型/行/範囲引数・空効果をそのまま使う。篩、型付けの規則、公理、安全19契約を変えて反例を避けていない。

この反例は「Float/Decimalの算術そのものをL40で形式化できない」ことを証明するものではない。**指定された既存の部分δをそのまま使うだけでは閉じない**ことを証明する。群Dの正常応答はFloatの比較とDecimalの丸め等を供給するが、該当する算術のδを供給していない。新しい名前の枝を既存δへ置くだけでは、Decimalの加減乗除の計算本体が得られない。新算法を作らない条件の下で、未定義の計算を仮定する・任意の正常値へ置き換える・一律errにする、のいずれも行わない。

取りまとめに求める判断は、使うべき別の既存算術δの所在と実名を指定するか、Rustの既存の演算算法をLeanへ写し、そのnamedδと応答契約をL40の同じ範囲で追加する案を認めるか、である。後者は新しい算法の考案を含めない案だが、現依頼の「既存のδを使う」から広がるため実装前に判断を要する。R段への繰延べで完了とはしない。

| 再開案の作業 | 所要の暫定見込み | 判断・検査の条件 |
|---|---:|---|
| 既存δの指定・照合 | 所在の提示後15〜30分 | 指定されたδが同じ原署名・全入力を受けることを調べる。閉じれば当初見込みへ戻す |
| 既存Rust算法のLeanへの写しの短い調査 | 30〜60分 | Floatの既存Model演算とDecimalの丸め・仮数/scale・overflow/zeroの扱いを読む。全量の実装時間はこの調査前には確定できない |
| 算術の写し・応答契約 | 不明 | 接続だけで足りるか、Decimalの算法の写しとその正常/Stopの証明が要るかで変わる。6時間枠へ収まると現時点では保証できない |
| 構造Equality・O135 | 当初の暫定見込みを保持 | 未実装。停止後に独立の実装を増やさない |
| 段末の全環境公理監査・写し・独立レビュー・受け入れ | 閉鎖後に実施。監査等20〜40分、レビュー・受け入れは不明 | 今回の反例7宣言の確認を段末監査の再実行と数えない |

### 単位の状態

| 単位 | 開始（JST） | 終了（JST） | 状態 |
|---|---|---|---|
| 依頼・固定条件と三件の初期見積り | 13:24:02 | 13:26:14 | 読取りと見積りを記録 |
| 演算子の既存δの調査・停止反例 | 13:26:14 | 13:28:18 | 原署名BuiltinArgsからの応答不存在を2実名で確認。実装停止 |
| 構造Equality | 未着手 | 未着手 | 既存structuralEqualとpartialScalarDeltaを予備確認しただけ。全入力の閉鎖0 |
| O135の15〜25分調査 | 未着手 | 未着手 | defsがnoneである点等を予備確認しただけ。停止条件を先に確定したため、指定の調査を完了したと数えない |

64義務のO022/O034/O062/O065/O135/O144は6行とも「一部」を維持し、44局所照合済み/6一部、全体閉鎖0を変えない。申し送り33行と三つの独立未完を後段へ移して閉じた行は0。additional-unresolved.jsonに停止の証拠だけを追記する。

新しい本番モジュール・本番宣言は0。上の反例用台本の7宣言だけを追加した。台本は本番の定義を追加するモジュールではなく、改造内に保管する停止の証拠である。01-12/07-04の写しと既定importは変更しない。

初回の反例検査は、未簡約のBを含むConstOKにdecideを使って失敗した。decimalRepresentableへのchangeで修正した。修正用Pythonの相対パスも一度誤り、編集されなかったため訂正した。最終の型検査はerror/sorryAxなし。7宣言の公理依存はpropext/Quot.sound/Classical.choiceの部分集合だけであり、新しい公理0。段末の全環境の監査は、三件が閉じていないため再実行していない。


### 再開1の停止末の検査

| 検査 | 結果 |
|---|---|
| `lake env lean -M 12288`による停止反例 | 終了0。最終1.000秒。7宣言を印字し許可三公理の部分集合だけ。実コマンド・失敗・出力の識別はresume1-obstruction-check.json |
| `verify-resume1.py --tmp <tmp>` | 一度実行して終了0。formalの本番入力1076ファイル不変、64義務・33申し送り・34演算子の未完を維持。三件の閉鎖を認定するverifyではない。記録はresume1-verification.json |
| `scripts/check.sh --level work --base fcde6fe216d35c3c74fcaa8d28164df063b6aa8b` | 一度実行して終了0。3.691秒。仕様対応表の自己検査・集計、仕様例7成功・失敗0・無視0。formal_buildは選ばれていない。記録はresume1-work-check.json |
| 既定build・段末全環境公理監査 | 再実行していない。本番Lean変更0。三件を閉じる前に停止したため、閉鎖後の監査・検査とはしない |
| 正式RSS・全比較・独立レビュー・受け入れ | 未実施。RSSは取りまとめの限定採取。全比較は今回の依頼範囲外 |

work開始・終了は13:29:30〜13:29:34 JST。停止記録と照合の単位は13:28:18〜13:30:47 JST。再開1の終了は2026-11-04 13:30:47 JST、外側の所要は約6.8分である。能動時間と待ちは分離していない。最初の見積りと停止理由を30分以内に記録した。6時間超過なし。O135の15〜25分調査を実施したという記録は置いていない。

最終状態: 閉じた未完0、残り三件。取りまとめには、別の既存算術δの指定、又は新算法の考案を含めず既存Rust算法をLeanへ写してnamedδを追加する範囲の判断を求める。根拠は再開1の依頼の「新しい演算の算法を作らず、既存のδを使う」と「どれかがL40の手段では閉じないと分かったら止める」であり、スキルによる追加の承認条件ではない。


## 再開2: 算術δ・構造等号・通常decoderの接続

開始: 2026-11-04 13:33:05 JST（04:33:05 UTC）。未コミットの作業木を継承した。git の操作は行わない。今回の依頼と plan の先頭二項目を根拠に、既存の Float 模型と Rust 算法を写した名前付きδの追加を行う。Lean の模型と Rust の浮動小数点演算の一致は R50 の交換へ渡す。

### 最初の30分以内の見込み

初期の読み取りにより、次の見込みを置いた。能動時間と待ちは分離しない。独立レビューと受け入れは今回の起動外であり、所要は不明である。

| 単位 | 見込み | 調べた接続と未確定の点 |
|---|---:|---|
| 演算子34行 | 75〜120分 | 整数14はStandardIntegerFailure。Float二幅10はModelのビット列。Decimal5はbase/decimal.rsのfitと桁ごとの除算、String5は長さ検査と文字列順序。原署名の全BuiltinArgsを入口とする |
| 構造Equality全入力 | 45〜60分 | 既存structuralEqualを同実名へ接続。通常値はBoolean、構造走査の失敗はRustのInternal Stopに対応させ、scalar条件を前提にしない |
| O135通常decoder | 読み取り15〜25分、実装60〜100分 | recordProgram.defsは空。postprocess_wellTyped/row_typedは登録・通常decode実行を含まない。同じlet継続の実Steps/FirstReturnと同じResultを結び、任意lo/hiへ具体例を一般化する |
| 写し・照合・監査・verify・work | 30〜45分 | 三件の閉鎖後に段末監査をやり直す。全比較と正式RSSは担当外 |

合計の見込みは225〜350分である。6時間を超える見通しになれば停止する。decoderの読み取りの調査は13:33:05 JSTから行い、結果を記録するまでdecoder本体は変更しない。

### O135の読み取りの調査の結果

13:33:05〜13:48:16 JST、外側の15分11秒。関連するStandardDecodeBodies/Comparison、recordProgram.defs、FirstReturn、Steps、E_Let/E_Return、型付き構成子の逆転とcon_field_by_typeを読んだ。この区間では独立な演算子・構造等号の実装と局所検査も進めており、純粋な読取り時間は分離していない。decoder本体の変更はこの記録の後に始める。

接続は後処理関数の登録ではなく、通常decoderのCompの後に既存postprocessBodyをletInで置く方法を用いる。通常実行が同じlet枠の下で返したResultを、E_Returnがそのまま後処理へ渡す。任意の型付きResultについて、Errorの同じpayload又はRawの同じ二整数を逆転し、実比較δによるlo→hi→全体条件の有限な列へ接続する。事象列とdecoder終了時のストアを保持する。postprocess_wellTyped/postprocess_row_typedは同じ本体の静的な根拠として保持し、生成器の全実装や全モデルの充足とは区別する。

新公理・型付けの規則・主な十言明・安全19契約の変更は不要と判断した。任意lo/hiの四枝と型付きResultの形の証明、同じResultのletへの受渡しが実装の残りであり、60〜100分と見積もる。FirstReturnは既存の構文上の境界を用い、同じ呼出しの識別を新しく保証したとはしない。

### 旧反例の置き換え前の識別

旧resume1-obstruction.leanは5,044バイト、SHA-256 `de21aa11bb2812f30f619610a41ea6b5347b95eef37f0d387d10edfbf2390f6c`。再開1の検査記録が指すのはこの旧入力である。削除に代えて同じファイルを、新しい名前付きδの全BuiltinArgsからFloat.add/Decimal.addの応答存在を得る対照へ置き換える。旧部分δについての応答不存在の言明自体を偽とするのではなく、新δには同じ不足がないことを示す。

### 再開2で閉じたものと本番の宣言

演算子34行は[原署名の全行](resume2-operators.json)に、名前付きδ・response・表のtable_responseを対応させた。既存integerDeltaの名前表にもdiv/modの枝がないので、新しいStandardIntegerOperatorResponse.deltaから群F2の同じintegerBinaryDeltaを呼ぶ。Float・Decimal・Stringも今回の指定の範囲で名前付きδを追加した。[Rustの関数と算法の対応](resume2-sources.md)を、出どころの一覧とする。

Full構造Equalityは `StandardStructuralEqualityResponse.table_response` で閉じた。元のT・Equality sat・注釈・Ordinaryを保持し、scalar-domainを前提にしない。同じstructuralEqualを呼び、正常値はBoolean、不適格構造はInternalComparisonである。`reply_normal` は正常値がBooleanであることを別に結論し、失敗をfalseへ置き換えない。

O135は `StandardDecode.postprocess_all` と `decodeThen_normal/decodeThen_firstReturn` で閉じた。任意の型付きResultを同じError又は同じRaw二整数へ逆転し、lo→hi→全体条件の実δ/Step列へ接続する。`DecodeResult` と `checkedRawResult` が入力との同一性と最初の違反を指定する。通常decoderの実行の終点で得た同じ型付きResultをletで渡し、事象列・更新後のストアを保持する。`decodeThen_typed` は合成本体の型付け、`decodeThen_failed` は通常decoder自身のStopの伝播である。recordProgram.defsは空のまま、後処理をinlineしたcoreの接続を証明する。全生成器・任意の宣言表の収集・全モデル充足を証明済みとはしない。

本番への追加は次の8モジュールである。宣言数は最新監査の環境に保持されるprivate・生成宣言を含む。全名と所在は一段上のaudit-summary.jsonのdeclaration_partsを正とし、別の全名の写しは作らない。

| モジュール | 主な宣言 | 宣言数 |
|---|---|---:|
| StandardOperatorArguments | signature、arguments | 4 |
| StandardFloatOperatorResponse | API、bits、delta、response | 69 |
| StandardDecimalOperatorResponse | API、wide、make、roundMagnitude、fit、divDigits、divide、calculate、outcome、reply、delta、response | 87 |
| StandardStringOperatorResponse | API、reply、delta、response | 55 |
| StandardIntegerOperatorResponse | base、name、signature、delta、response | 20 |
| StandardOperatorResponse | Entry、entries、entries_count、entries_unique、dispatch_name、response、table_response | 50 |
| StandardStructuralEqualityResponse | reply、delta、reply_normal、response、table_response | 21 |
| StandardDecodeConnection | decoderInputType、decoderOutputType、decodeThen、decodeThen_typed、decodeThen_normal、decodeThen_firstReturn、decodeThen_failed、private steps_trans | 8 |
| 合計 | 既定importの閉包に全て含む | 314 |

既存StandardEqualityResponseにはfull_arguments、StandardDecodeBodiesにはcheckedRawResult・DecodeResult・comparison_boolean・checkedRawResult_typed・postprocess_raw_general_steps・postprocess_all・decode_let_typedを追加した。生成分を合わせた既存モジュール等の増分は41、全環境の増分は355である。01-12・07-04と既定importを同じ変更で更新した。型付けの規則・主な十言明・安全19契約・旧Release・処理系・計画・他群・レビューは変更していない。gitの操作なし。

64義務はO022/O034/O062/O065/O135/O144の6行を「一部」から「担当分の局所証拠を照合」へ変更した。技術50の局所照合、独立未完0、継承6・運用3・他段1・共通4、全体閉鎖0である。33申し送りの出どころ（今回25・継承3・他段5）は維持し、H02/H03の不足を解消した。後段へ三件を移して閉鎖した扱いにはしていない。局所の証拠181箇所・第2節の59行も最新の全名と所在へ再生成した。

### 再開2の監査と検査

| 検査・監査 | 結果 |
|---|---|
| 追加・変更した各Leanモジュールの局所検査 | 最終は全て終了0、-M12288。新しい依存の読込みには単独Leanの-oを使用。対象指定のlake buildは行わない |
| 旧反例から置き換えた対照 | 終了0。新δの全入力の応答存在を二宣言で確認。公理依存は許可三公理だけ |
| 既定importの局所型検査 | Benitoite.leanを-M12288で検査して終了0。既定ビルドの実行とは数えない |
| 段末の公理監査（一回） | 終了0、79.311秒。既定999モジュール・79,156宣言、private・生成と実体化2周。許可三公理の部分集合のみ、新公理・sorryAxは0 |
| 段内の変更・新モジュールの区別 | 変更337モジュール14,015宣言、新311モジュール11,209宣言。全てを今回の新規宣言とは呼ばない |
| 署名と読者 | 最新170署名を環境から印字。既定8対象の閉包の和1009、Benitoiteの閉包999。新8モジュールを除外しない |
| 指定のwork（一回） | 13:59:40〜13:59:49 JST、終了0、8.990秒。仕様対応の自己検査・集計、仕様例7成功・失敗0・無視0、formal_buildの既定lake buildとsorry拒否。onlyなし |
| verify | verify-resume2.pyで最終照合する。現在の結果はresume2-verification.jsonを正とする |
| 全比較・正式RSS・独立レビュー・受け入れ | 未実施。RSSは取りまとめの別採取、独立レビュー応答は別起動 |

公理の集合ごとの件数は、none 36,808、Classical.choice 1、三公理すべて19,784、Classical.choice+propext 2、Quot.sound 9、Quot.sound+propext 3,848、propext 18,704である。生出力は17,135,923バイト、SHA-256 `c7d4bf43918285f102588efa9c5d09adf678234bdf16cd1d42cd899a34df6da4`。全対象一覧は5,176,154バイト、SHA-256 `f78f2b5f64dd96f18c32b00ddc32e0b089cfa95a389d05d180775d8c615b3f15`。宣言の写しは最新の段末監査一回分へ更新した。workの出力は5,848バイト、SHA-256 `2092a30587ef37a7f6d195c8b0dce38a4dbdf01f8fa12154f8de911974d26be5`。実コマンドと終了・時間はaudit-execution.json・resume2-work-check.jsonにある。check.shは成功時のlake出力を表示しないためjobs数は未取得とする。

途中の局所検査では、存在量化する結果の指定不足、Decimalのimport不足、既存のprivate補題名の使用、比較結果のBoolへの書換え、Stepsの括弧、型の正規化と局所文脈の移送を修正した。最後の各モジュールの型検査は警告・error・sorryなしである。文書の編集用Pythonの文字コードの誤りと、同じパスの削除・追加を同時に行うpatchの拒否もあったが、その呼出しではファイルを変更していない。公理監査とworkは最初の実行で成功し、重ねて実行していない。

### 再開2の時間と申し送り

| 単位 | 開始（JST） | 終了又は確認（JST） | 外側の時間・扱い |
|---|---|---|---|
| 初期の読取り・見込み | 13:33:05 | 13:36:24 | 約3分19秒。最初の30分以内に記録 |
| 演算子34行 | 13:36:24 | 13:44:53 | 約8分29秒。最初の本番ファイルの作成時刻と局所検査後の時刻 |
| 構造Equality | 13:42:00 | 13:44:53 | 約2分53秒。演算子の区間と重なるため加算しない |
| O135の調査 | 13:33:05 | 13:48:16 | 外側15分11秒。上記の独立作業も含む。純粋な読取り時間は未分離 |
| O135の実装・局所検査 | 13:48:16 | 13:55:31 | 約7分15秒。最終の接続の検査後の確認時刻 |
| 資料・監査・work・最終照合 | 13:55:31 | 最終行に記録 | 独立レビュー・受け入れは含まない |

取りまとめへ新たな停止条件に当たる変更の判断は求めない。今回の指定どおり、算術δを足した方針を設計者の見直しの対象として渡す。R50にはFloatのModelとRustの算術・NaN、Decimalの係数/scaleとWideの拒否、Stringの長さ上限・順序、全構造等号とmalformed拒否を渡す。R40の生成器全体、L60の全実表のCoreAssumptions、L70の主定理の合成は元の担当に残す。F2の最初の失敗の理由との接続、%Map.replaceValues、欄の等号とhead/tailの処理系への反映等の既存の申し送りも保持する。

再開2の最終照合は2026-11-04 14:05:15 JSTに一度実行して終了0。保護対象2,263ファイル不変、本番の追加8モジュール・既存3ファイルの変更だけ、34原署名・64義務・33申し送り・170署名・全監査入力・45相対リンクを照合した。記録は約3.17MB、各100KB以下である。[resume2-verification.json](resume2-verification.json)を正とする。本番Leanと写しは監査・work以後に変更していない。

資料・監査・work・最終照合の単位は13:55:31〜14:05:16 JST、約9分45秒。再開2の終了を14:05:16 JSTと記録する。今回の外側の所要は32分11秒、初回35分35秒・再開1の6分45秒を含む作業区間の合計は1時間14分31秒である。能動時間と待ちは未分離で、単位の重なりを合計へ重ねて加えていない。最初の見込み225〜350分より短く終え、6時間超過の見通しは生じなかった。独立レビュー・正式RSS・設計者の受け入れは未実施のまま取りまとめへ渡す。

## 再開3（L40.39）

2026-11-04 14:20:43 JST に開始した（最初の時計の取得時刻）。[段末の独立レビュー](../../reviews/RV-L40.g.md)の中2件・軽4件・情報4件へ応答する。git の操作は行わず、開始時の未コミット作業木を引き継いだ。plan.md の注記は取りまとめが済ませたため変更しない。

### 中1の試行と見積もり

最初の20分以内、14:23:04 JST までに (a) の残りを2時間30分〜4時間と見積もり、指定された条件に従って (b) へ切り替えた。[部分試行](resume3-equality-trial.lean)では、観測の深さが正、列の要素の深さが列の深さ以下、整数の比較の燃料、子の比較が成功するときの列の比較の存在を Lean で確かめた。これは型付き Equality 全体の正常性の証明ではない。試行の初回では所属の分岐の変数名と補助定義の簡約を修正し、最終の部分補題は成功した。

残りは、Equality の型から閉じた値の観測を構成する List・data・Bytes・Map・Set の帰納、二値の観測の形の対応、Map の重複縮約と整列の後の各値が元の値側スロットに由来すること、その深さ境界から snapshotDepth の燃料が足りることの合成である。StandardKeySound.value_key の有限な値の帰納と key_table_sound は鍵用であり、Float を含む Equality 全体の二値比較にはそのまま使えない。既存の鍵の定理は同じ宣言表・satB との対応・分散の妥当性を取り、現在の response は任意の P/B を量化するため、その接続の整理も要る。新しい独立の信頼条件や値の大きさの上限は追加していない。

処置 (b) では、正常の枝だけ Boolean を結論し、型の付いた Equality の入力で structuralEqual が none にならないことは未証明と明記した。R50 には StandardStructuralEqualityResponse、snapshotDepth の燃料の十分性と values_equal の共有走査・深さの境界を申し送った。この失敗に当たる処理系の経路は Stop::Internal であり、言語の停止ではない。応答の存在・型・Ground・AdequateResult・非 exit の既存の局所契約と、失敗枝の排除を分けた。

### 所見への処置

所見ごとの request/report/response/handling は[応答](review-response.md)に置く。中2の算術 δ の追加と Float の NaN の payload・符号の正準化を設計者の見直しの表と一覧へ加えた。軽1は六つの義務の役割ごとに再開2の証拠を割り付け、L60 へ渡す実署名を response とした。軽2と情報1〜3は R50・L70・R40・L60 の表へ具体の境界を加えた。軽3は StandardDecode の名前空間へ直した。軽4は確定値の節を参照し、対照を resume2-contrast.lean へ改名した。旧反例の5,044バイトと SHA-256、再開1の実行時刻・出力は履歴として保持し、現行の対照の検査記録と混ぜない。情報4は処置不要で、64義務・33申し送りの分類を維持する。

01-12 と07-04には正常枝の限定を同じ変更で反映した。本番の Lean・型付けの規則・主な十言明・公理・既定 import・提供範囲は変更していない。追加の Lean は部分試行の資料だけで、本番の既定 import へは入れていない。段末の監査は既存の新旧全環境を一度再実行し、宣言の写しはその一回分へ更新する。

### 再開3の群末検査

検査の確定値は以下へ記す。既定ビルドと指定の work は別に一度ずつ実行し、work が内部で選ぶ formal_build も記録する。正式 RSS・全比較・独立の再確認・設計者の受け入れは取りまとめ・設計者に残す。文書の編集用 Python が文字コードの誤りで一度終了1となったが、その実行ではファイルを変更していない。apply_patch に切り替えて記録した。

| 検査 | 結果・範囲 | 外側の時間 |
|---|---|---:|
| 既定 `lake build`（一回） | 終了0。formal/ から対象指定なし、1260 jobs。増分ビルド。既存の linter・deprecated・リンク先ディレクトリの警告は残る | 0.253秒 |
| 中1(a) の部分試行 | `lake env lean -M 12288` で深さ二補題・整数・列の補題を確認、終了0。型付き全構造の正常性の証明とは区別 | 0.797秒 |
| 改名後の対照 | 同じ `-M 12288` で二つの応答存在と `#print axioms` を確認、終了0。許可三公理だけ | 0.617秒 |
| 段末の公理監査（一回） | 終了0。999モジュール・79,156宣言、private・生成と印字時の実体化2周。170署名。新公理・sorryAx は0 | 75.661秒 |
| 指定の work（一回） | `scripts/check.sh --level work --base fcde6fe216d35c3c74fcaa8d28164df063b6aa8b`。終了0。仕様対応表の自己検査・集計、仕様例7成功・失敗0・無視0、既定 lake build と sorry 拒否。only なし | 4.292秒 |
| verify | `python3 -B <改造>/l40/g/verify-resume2.py --resume3 --tmp <tmp>`。開始入力、監査入力・宣言・全名、34原署名、64義務・33申し送り、所見の証拠の割付け、正常枝の限定、対照の改名、相対リンク、各記録100 KB以下を照合する。確定結果は resume3-verification.json と末尾に記す | 末尾に記録 |

work の実行時刻は14:29:44〜14:29:48 JSTである。選択の表示だけの dry-run と、検査を実行する work 一回を区別する。上の独立した既定ビルド一回に加えて、work 内の formal_build が既定ビルドを一回呼ぶため、lake build の起動数は合計2である。Rust 全 lib・clippy・全比較・大きな具体値を作る評価は実行していない。

公理依存の件数は none 36,808、Classical.choice 1、三公理すべて19,784、Classical.choice+propext 2、Quot.sound 9、Quot.sound+propext 3,848、propext 18,704である。変更337モジュールの宣言14,015、新311モジュールの宣言11,209を区別する。これらは段全体の集計であり、今回の新規の本番宣言は0である。生出力・全対象のハッシュは再開2と一致したが、再開2の実行を流用せず、14:28:17〜14:29:33 JST に再監査した。宣言の写しは今回の一回分だけである。

| 生出力・一覧 | bytes | SHA-256 |
|---|---:|---|
| 段末の公理監査 | 17,135,923 | `c7d4bf43918285f102588efa9c5d09adf678234bdf16cd1d42cd899a34df6da4` |
| 全対象一覧 | 5,176,154 | `f78f2b5f64dd96f18c32b00ddc32e0b089cfa95a389d05d180775d8c615b3f15` |
| 既定ビルド | 45,474 | `da63757831677bae1663740941e555164137cf1a368badd2819bec0107f83f12` |
| work | 5,848 | `6e4194d6ad373a575363b78e714c5de348a97440eedea0d5d4a3601ddc8fbc44` |

実コマンド・入力・出力の識別・開始終了は audit-execution.json、resume3-build-check.json、resume3-trial-check.json、resume3-contrast-check.json、resume3-work-check.json に保存した。開始入力の識別は resume3-start-inputs.json にある。生出力は一時領域に置き、この記録から手元の絶対パスでは参照しない。

### 再開3の最終照合と終了

verify は14:30:51 JST に一度実行して終了0。保護対象6,031ファイルと本番 Lean 1,010ファイルが開始時から不変である。34原署名、64義務（技術50の局所照合、継承6・運用3・他段1・共通4）、33申し送り、79,156宣言、170署名、59相対リンクを照合した。型付き Equality の失敗枝の排除は false と明示し、応答契約の照合と分けて記録した。義務全体の閉鎖は0のままである。

照合時の g の記録は3,193,886バイト（約3.19 MB）、各ファイル100 KB以下であった。全名の写しは最新の監査一回分だけである。verify 後は本番入力・写し・検査台本を変えず、この終了記録だけを追記した。

終了は 2026-11-04 14:31:21 JST、今回の外側の所要は10分38秒である。開始から中1の選択までの記録区間は2分21秒、残りは文書・参照の修正、群末検査、最終照合と記録である。能動時間と待ちは分離していない。初回・再開1・再開2の作業区間1時間14分31秒を含む合計は1時間25分9秒。独立レビューの所要・正式 RSS・設計者の受け入れ待ちは加えていない。

## L40 段末の work の検査と正式な最大常駐量（取りまとめ）

- 基準: `fcde6fe216d35c3c74fcaa8d28164df063b6aa8b`。作業木は再開3（L40.39）の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base fcde6fe216d35c3c74fcaa8d28164df063b6aa8b`。選ばれた単位は spec_tally・spec_examples・formal_build。
- 結果: 終了0。外側 456.52秒、最大常駐量 2,931,425,280 バイト（L40 の段末の正式な値）。仕様例7件が通り、形式化のビルドに sorry はない。

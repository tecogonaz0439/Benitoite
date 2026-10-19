# L6c2の定義・言明・読者の点検

## 残っていた言明と全体の帰納

前回の式の捕捉保存を仮定として受ける補助を、仮定なしのHasBlockQ.capturesへ置き換えた。HasTypeQ/HasTypesQ/HasEachQ/HasArmsQ/HasBlockQの相互帰納をBuilderNoCaptureに置き、穴の列も固定式の定理とrenameから接続する。builders_no_captureとbuilders_block_no_captureは任意のΓ・Δを受け、Alignedから得るEnvReadsで具体化する。公開入口の空Δへの制限、型付けの後の再検査、未対応構文の拒否へ逃がしていない。

| 脱糖の読者・場合 | 捕捉の証明への接続 |
|---|---|
| local・直接の名前・リテラル・raise・nullCon | 新しいクロージャを作らない。通常値の捕捉条件を展開して証明 |
| funDicts・methName・opDicts・conValue | closure_emptyと既存の型保存からReadsを導く。生成したlamも実際のコアで検査 |
| lambda・lazy・partialCall・partialCon | 同じ生成境界のReads。callee/固定引数/穴を含む脱糖全体を対象にする |
| const・paren・Sub | 定数本体は空環境へ、その他は同じ子の導出へ帰納 |
| call・三種のpipe | calleeと引数を帰納しcallCompへ合成。直接の頭の辞書証拠も参照を持つ通常値であり、新しいlamは作らない |
| Exprs/Each/HoleArgs | 各子へ帰納。穴の列では全引数の下へ固定式をshiftする。穴自身の変数は新しいlamを含まない |
| レコードの構築と更新 | 評価する子の帰納。フィールドの並べ替え・既存フィールドのパターン・一時変数の追加は合成補題で扱う |
| 二項・単項・not/and/or・List・展開・補間 | 評価する子は同じΔへ帰納。letChain、spread/interpolateの有限の組み立てへ合成 |
| if/elseIf/ifOnly・match | 条件/対象の式、各ブロックと分岐へ帰納。対象のletをshiftし、パターン束縛はshiftUnderで保護 |
| Arms | ガードはhideConts、パターン変数はbindsへ追加。ガード/本体/後続へ直接帰納 |
| return・tryResult/Option・die | 入力を帰納。失敗分岐の束縛数を換算し、任意の説明の部分導出をhideContsで帰納。原因の辞書値とexitの頭はlamを作らない |
| with・resume | 通常の子を帰納。withの通常束縛をΓ・Δへ追加し、resumeは継続位置を追加letの分だけずらす |
| 通常handle | 本体は同じΔで帰納。通常節はclosure_emptyから型保存とReadsを導く |
| handleFail | 本体は同じΔで帰納。節はshiftEnvと予約継続/エラーの二位置を加えた空Δでの型保存とReadsを使う |
| 専用操作 | 通常引数は同じΔで帰納。get・合成・setを行うbuilderFinishは新しいlamを含まない |
| 全Block | すべての構成子を明示。通常/パターン束縛、discard/seqの一時let、専用宣言の後続にも直接帰納 |
| 専用宣言 | builderNewの捕捉条件と、none :: Γ・some kind :: Δの後続の帰納を組み合わせる。その部分導出には、その場所のΔで全体の定理を再び適用できる |
| 正式import | Benitoite.leanとBuilderExamplesからBuilderNoCaptureをimportし、BuilderCaptureAllとBuilderCaptureComposeも既定ビルドに含める |

型付け・checker・Walkの構成子は今回変えていない。これらの全読者の接続は前回のl6/rule-review.mdの一覧に対応する。110ファイルの開始版との同一性とReads/Captures定義の保存をcontracts-comparison.jsonへ記録した。公開11件・program・性質1とエフェクト健全性を含むファイルの全体が一致するため、シグネチャだけでなく前提の定義も同じである。

## 共通の関門K

- K契約: Δの専用位置を通常の値として返す道を追加していない。通常のReferenceと先行copyの不変値は許す。評価順・失敗順・APIは変更していない。
- K形式化: Reads/Capturesの定義を維持し、新しい全体の捕捉定理を証明した。公理・Builtins.Assumptions・主定理の前提/結論は追加/変更しない。新しい定理もREADMEの公理検査に含める。
- K接続: 既定分岐を使って新しい構成子を落とすことはない。式/ブロック/並び/分岐の全場合を明示し、合成関数の不正な入力の既定値もそのまま扱う。
- K文書: 01-12・07-04とformal/READMEを実際の定理に合わせた。構文の章・標準ソース・診断表は変更せず、生成Skillの入力は変わらない。
- K安全点/K性能: Rust・VM・GCとベンチマークは変更していない。追加の性能や隔離の主張はない。
- K境界: Stateと既存Referenceの規則を保つ。全体の捕捉定理を、Rustとの接続の完了とは扱わない。

## 新しい具体例の作成時の関門

1. 守る不変条件は、コアのCapturesが通常のセル利用とクロージャの捕捉を区別し、自由番号を束縛数で正しく戻すことである。
2. Capturesを恒真にする、let/lamの下で番号を一つ数え間違える、Fail節の予約位置を省く退行で負例が崩れる。通常利用と通常値の正例は、すべての変数を拒否する述語への退行も検出する。
3. 既存27個のexampleはchecker/型付け/実行の境界を確かめるが、新しいコアの自由参照の述語を検査していない。同じBuilderExamplesのcaptureBoundariesを再利用し、lambda/lazy/partialCallのcallee/固定引数の4行を一つの例で照合する。通常のセル利用・通常値の捕捉・Fail節を合わせて4個のexampleを追加した。
4. 新しい公開のフラグ・差し込み口は不要であり、既存の脱糖から実際のコアを得る。期待する番号の条件は独立に0番/1番として書き、脱糖から期待述語を生成しない。

既存のexampleと期待値はすべて保つ。Rustのテスト/assert/ignoreに変更はない。これらは証明範囲を閉じるための具体例であり、処理系の不具合を修正したという主張はしない。

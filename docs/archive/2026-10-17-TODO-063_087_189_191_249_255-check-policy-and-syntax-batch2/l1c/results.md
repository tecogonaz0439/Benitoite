# L1cの作業記録

基準Bと開始時HEADは `35a77b5367c15465ce6e0e39c2c97992250e1494` である。開始時の作業ツリーは空であった。コミットとdocs/todo/の変更は行わない。

以下の最初の区切りは前回の記録であり、その時点ではL1cは未完了だった。続行の結果と現在の完了状態は末尾のL1cc2の記録に示す。

## 追加する有限支持の確認例の関門

1. 守る契約は、一般のFail列の比較が生の位置と重複を区別すること、正規化が内部まで整列・重複除去すること、型・行の代入像が持ち込む潜在効果の原子を保持すること、注釈の整形式の検査が入力を書き換えないことである。
2. 原子の一覧をそのまま比較順に使う、Failを空列扱いする、比較の前に注釈を正規化する、代入した型内部の効果を落とす、最上位だけ整列する、支持の外の原子を和から切り捨てる変更を検出する。
3. L1bの既存例はLegacy制限と0/1要素での簡約を検査する。有限支持上の一般の複数のFail、内部の潜在効果、非正規形の生の比較には到達しない。この新しい境界にだけ確認例を置き、既存の入力と期待値は保つ。
4. 共有するTy/Effと計算用APIを使い、テスト専用の差し込み口や型モデルは加えない。期待する構成子・型・順序は手で指定し、対象の正規化で生成しない。今回はL1cの契約を確認する例であり、既存の不具合の退行テストと称さない。

## 今回の区切りで正式に残したもの

文脈の残量による区切りであり、**L1cは未完了**である。正式な検査器のLegacy制限はまだ残っている。主な定理・健全性11件・Builtins.Assumptionsの前提と結論は変えていない。

- `Release/Order/FiniteAtoms.lean`: 候補中の最小符号の相違点と、その比較が数学上のatomsCompareに一致すること。
- `Release/Finite.lean`: 型・型列・効果の計算できる比較と正規化、数学上の定義との一致、一般の整列・重複除去、支持の選び方への不変性、Canonical・冪等性・Legacyの保持。型と型列の比較・正規化は構造再帰である。最上位の効果の正規化の一致にはFail内部の支持だけを使う。
- `Release/FiniteSupport.lean`: Fail内部までの支持収集の十分性と、実際に現れる原子だけを収集すること。正規化による支持の保存・反映、意味上の包含からの支持の取り出し。
- `Surface/FiniteTools.lean`: 生の型・効果の等号、型操作の支持条件付きの一致、Failの包含の健全性と完全性、型の包含と結び、通常の名前の捕捉の保証。和と捕捉で支持外の原子を切り捨てない。tyEq_sound/effEq_soundにCanonicalはない。
- `Surface/FinitePredicates.lean`: 一般のFailを含む整形式・型変数の範囲・内部のCanonicalの計算できる判定と、数学上の述語との一致。注釈を書き換えない。
- `Surface/FiniteExamples.lean`: 関門に挙げた13件の計算例。すべてrflによる確認を含む。既存の例は変更していない。

六モジュールを `formal/Benitoite.lean` の既定のビルドへ登録した。新しい型モデルは作っていない。通常のソースと証明の追加は913行、計算例は57行である。01-12・07-04・formal/README.mdには、この証明済みAPIの範囲を反映し、正式な検査器にはLegacy制限が残ると明記した。主要定理の言明や新しいFailの捕捉規則は変更していない。

## 保存した検査器の移行

[checker-migration.patch](checker-migration.patch) は、CheckTools・CheckPredicates・CheckPatterns・CheckSupport・Check・CheckTablesの六ファイルを開始版から移す差分である。[checker-migration-state.json](checker-migration-state.json) に基準、patchのSHA-256、各ファイルの開始版と適用後のハッシュ、必要な六つの新モジュールのハッシュを残した。正式な六ファイルは開始版へ復元し、保存差分は適用していない。

保存差分は、再帰的なAtomsIn、有限支持を明示する計算用の型操作、Legacyによる入口・注釈・宣言材料の拒否の除去、パターンの型操作、R41の通常の節の効果の戻しと再検査までを含む。保存前の `lake build Benitoite.Surface.FiniteExamples Benitoite.Surface.CheckTables` は終了0であった。ただしCheckLemmas以降の証明は未移行であり、この差分を適用した全体のビルドはまだ通らない。

途中にCheckLemmasをビルドした [出力](migration-local-build.log) は終了1・real 5.72秒である。旧wfTy/cleanTyの成功からLegacyとの組を得る箇所、effSub_legacy、guardInferred_legacy、引数が増えた型操作、和と結びの支持の前提が未移行であった。その後に判定と結びを正式な有限APIへ委譲する整理を行ったため、この失敗ログの行番号・件数を最終保存差分のものとは扱わない。成功した局所ビルドも移行完了の証拠として正式な状態へ引用しない。その他の局所ビルドは外側の時間を計測していない。

R42の [反例](join-support-counterexample.lean) は、左入力の型の効果が空でも、右入力から支持外の潜在効果を持つFailが結びへ残ることを示す。左入力の支持だけから深い支持を証明する方針は使わない。これは新しい再帰的な支持に必要な内部の補助の前提を確かめる例であり、公開する健全性11件の反例ではない。

## 復元後の検査

以下は、保存差分を外し、六モジュールを既定ビルドへ登録した正式な状態での結果である。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド（formal/） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `rtk proxy lake build` | 0 | 9.56秒 | [出力](boundary-build.log)。220 jobs、警告なし。既存の証明・例・六入口と新しい計算例を含む。既定ビルドはこの区切りで一度だけ実行 |
| `rtk proxy lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1c/axioms.lean` | 0 | 0.62秒 | [確認ファイル](axioms.lean)、[出力](axioms.log)。既存の24件と追加の21件。Lean標準のpropext・Classical.choice・Quot.soundだけ。型・効果の比較の健全性にCanonicalがないことも表示 |
| `rtk proxy lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1c/join-support-counterexample.lean` | 0 | 0.34秒 | [出力](join-support-counterexample.log)。R42の両入力の支持の必要性 |

公理確認の初回は、流用した既存の確認ファイルが新モジュールをimportしていなかったため終了1（0.32秒）となった。[初回の出力](axioms-initial.log) を保存し、import Benitoiteを加えて確認ファイルだけを再実行した。ソースの証明の変更は不要であり、既定ビルドは繰り返していない。

執筆中は、構造再帰の対象の明示、有限支持の型引数、matchで定義したEff.Supportの展開、相互再帰のsimpの引数、Leanの予約語を修正した。sorry・公理・仮定の追加で通していない。既存のassertの削除、期待値の緩和、ignoreはない。Rustは変更していないため、lib・統合・clippy・fmtは追加していない。spec_examples/spec_tallyを含むL1cの完了検査、gc-stress、all-targets、check-formal.sh全体も実行していない。

## 次に続ける手順

1. stateの基準と各ハッシュ、保存差分の `git apply --check` を確認し、六ファイルの差分を適用する。正式な六モジュールは作り直さない。R36〜R43と本記録を前提にする。
2. CheckLemmasを移す。Legacyの成功の補助を除き、cleanTy/wfTyには入力の再帰的な支持を渡す。acceptEffの移動先には `Finite.effSub_sound_of_fails` を使えばFail内部の支持だけで足りる。通常のhandledはFail列が空であり、原子の一覧の外の名前を消す必要はない。和の一致には `unionEff_eq_of_fails`、Fail列の支持には `unionEff_fails_support`、包含からの支持には `Eff.support_of_sub` を使える。
3. R42どおり、strict/relaxedの計算について、型・効果・要求の支持を保存する内部の証明を先に用意する。結びには両入力、反復にはstep、要求の集計には各要求の支持を渡し、型探索は節・環境・戻り先・宣言から支える。公開する健全性11件とcheckProgram_soundの外部の前提へ追加して済ませない。反復と型探索は空の状態から実行する箇所を使い、外側の状態の要求の支持と区別する。
4. CheckDictSupportと各CheckSoundのLegacy由来の等式を支持由来のものへ替える。R41の節は、移動した許容効果の下で本体を型付けし、外へ戻した実際の効果の再検査から外側への包含を導く。部分適用した構成子では計算した潜在効果をnormWithで正規化する。既存の具体例の意味を変える場合は理由を記し、期待を弱めない。
5. SurfaceCheck/Batch・WalkとExchange/Convertの型操作に支持一覧を渡し、Legacyの一時的な拒否を外す。Surface.LegacyInputの接続と有限材料・lookup・入力・計算結果の各制限が残っていないことを確認する。脱糖・主要定理・健全性11件・元のプログラムについてのcheckProgram_sound・六入口をそろえる。注釈をcheckerで正規化しない。
6. 同じ変更で01-12・07-04の現在の検査器の説明を更新する。L1cを完了したときに、固定した基準Bでplanの `--level work --only formal_build,spec_examples,spec_tally` のdry-runと本実行を一度行う。今回の区切りのビルドを、Legacyを外した状態の完了検査へ引用しない。新しいFailの構文・捕捉・NoFailはL2cへ残す。

記録末に、正式なLeanソース138件をコメント・文字列を除いて走査し、sorry/sorryAx/admitとaxiom宣言がないことを確認した。変更文書のローカルリンク170件を見出しまで確認した。保存差分と六ファイルの開始版、必要な新モジュールのハッシュと再適用のcheckも一致した。リンク確認の初回はコード中の構文をリンクとして拾ったため停止し、コードブロックとインラインコードを除いて確認し直した。git diff --checkも終了0であった。

## L1cc2: 検査器の接続とL1cの完了

今回の開始時HEADは `94a332f9f22f3942310d1818eb3aaabb0875b826`、L1c全体の基準Bは冒頭の `35a77b5367c15465ce6e0e39c2c97992250e1494` のままである。開始時の作業ツリーは空で、保存差分と六ファイルの開始版・適用後、必要な六モジュールのハッシュを確認してから適用した。

### 既存例を移す前の関門

1. 守る契約は、有限支持による計算が支持外の原子を消さないこと、Legacyでない型を理由に公開入口が一律に拒否しないこと、元の注釈の意味を保つことである。
2. 以前の原子一覧による切り捨て、入力全体のLegacy拒否、未参照の有限材料だけに残るLegacy拒否を再導入すると失敗する。
3. CheckToolsExamplesの二つの原子の例と、CheckExamplesの四つの拒否の例は、一時的なR15の挙動を固定していた。R40の原子の保持とR15の制限の撤去に合わせて、同じ入力の具体的な結果へ更新する。既存の正常対照、全プログラムの対照と全assertを残す。これは合意済みの意味の変更であり、不具合修正の退行テストとは称さない。
4. 本番の型・公開入口を使い、テスト用の差し込み口は加えない。型操作へatomsを渡す変更はAPIの移行だけであり、他の入力と期待値とrfl/decideの証明方式を保つ。削除したtyConEqの二例は、同じ構成子を持つTyの比較で同じ不一致を確認する。

支持外のsingleEffとunionEffは従来のfalseからtrueへ変える。切り捨てを廃し、実際に持っていた原子を保持するためである。使わない環境の型、末尾returnの使わない注釈、空のcheckEachの期待型、未参照の有限宣言に一般のFailを含む四例は、拒否からそれぞれの完全なok値へ変える。一時的なLegacy拒否を外すためであり、結果をisOkだけで判定する形には緩めない。

追加例は、公開入口で実際に返すFailを含む型、呼び出しの潜在効果、正規形でない注釈の拒否、型束縛を一つ増やした通常の節の効果の戻しを守る。入力全体の拒否だけを外して結果の拒否を残す変更、呼び出しからFailを落とす変更、注釈を検査前に正規化する変更、節の効果をshiftしたまま外側で集計する変更を検出する。前の有限APIの例と、使わないFail型の対照だけでは公開入口のこれらの接続へ到達しない。CheckExamplesの既存の型とrunを使い、節のstrict/relaxedは同じ入力・期待効果を並べて確認する。期待型・効果は手で指定し、検査器の正規化から生成しない。


### 完了した変更

- 保存していた六ファイルの検査器の移行を正式に適用した。CheckTools・判定・パターン・表・入力・計算結果・交換の変換に残っていたLegacy由来の拒否とraw等式を、有限支持上の計算とその一致の証明へ置き換えた。使われなくなったSurface/LegacyInput.leanを削除した。
- `CheckComputeAtoms`・`Cases`・`Calls`・`Control`・`Pipe`・`Sound`の六モジュール（1399行）は、strict・relaxedの全構文と節の型探索について、結果と継続への要求の支持を保存する。和・結び・反復・要求の集計は、両入力またはstepの支持から接続した。空の状態からの探索と、外側の状態への要求の転記を区別した。
- CheckLemmasから各CheckSound、健全性11件、元のプログラムのcheckProgram_soundまで接続した。通常の節の効果の戻しと外側での再検査はR41どおりである。注釈を書き換えず、型操作の結果だけをnormWithで正規化する。主要定理・健全性11件・Builtins.Assumptionsのファイルの前提と結論は変更していない。
- SurfaceCheck/Walk・Batch、Exchange/Convertへ支持一覧を渡し、六入口を計算可能なまま保った。01-12・07-04・formal/README.mdに現在の保証を反映し、内部の支持保存の証明の具体化をR44へ記録した。
- CheckToolsExamplesの173例をすべて残し、支持を渡すAPIへ移した。CheckExamplesは58例から63例になった。既存の四つのLegacy拒否は合意済みの受理結果へ更新し、五つの新例で結果・呼び出し・注釈・型束縛下の節の接続を検査する。型束縛下の節の新例は、名前・行の関数の外延性が必要だったためEff.ext_testで両モードの完全なok値を示した。期待値は変えず、有限一覧での比較だけに緩めていない。

### 検査と結果

途中は変更に関係するLeanターゲットだけを直接ビルドした。[検査器の最初の失敗](l1cc2-initial-build.log) は終了1・6.87秒であり、Legacyの補助と型操作の引数の未移行を確認した。その後、[全計算の支持保存](l1cc2-compute-sound-final.log) は終了0・1.09秒、[プログラム全体の健全性](l1cc2-program-build.log) は終了0・1.19秒となった。各局所ビルドの成功後に共有部を変更したため、これらを最終状態へ引用せず、最終の関係状態は次のworkで確かめた。

局所の執筆中は、支持の前提と新しい引数、doの分岐が共有する継続の展開、相互再帰の式の明示的な書き換え、未確定の暗黙の型引数を修正した。六入口と既存例の初回は、古いAPIの呼び出しと一時的な制限の期待が未移行で失敗し、変更後は完了検査に含めた。新しい通常の節の例の初回のrfl失敗は [記録](l1cc2-public-examples-build.log) に残し、期待値を変えずに関数の外延性を使って [成功](l1cc2-public-examples-final.log) した（終了0・2.01秒）。ログ先の相対パスを誤った二つの呼び出しはビルド自体が始まっておらず、成功に数えない。

完了検査の基準Bは `35a77b5367c15465ce6e0e39c2c97992250e1494` のままである。外側の時間は `/usr/bin/time -p` のrealである。

| コマンド（特記以外はリポジトリの根） | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `scripts/check.sh --level work --base 35a77b5367c15465ce6e0e39c2c97992250e1494 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | [選択](l1cc2-work-dry-run.log)。計画の三単位だけを選択 |
| 同じ指定から `--dry-run` を外して実行 | 1 | 60.36秒 | [出力](l1cc2-work.log)。spec_tallyの自己検査と集計、仕様例7件は成功。formal_buildはSurface.Examplesの既存の支持条件の証明で失敗 |
| formal/で `lake build Benitoite.Surface.Examples` | 0 | 3.48秒 | [修正の確認](l1cc2-surface-examples-fix.log)。命題・入力・期待値を変えず、simpに再帰的なSupportの展開を加えた |
| `scripts/check.sh --level work --base 35a77b5367c15465ce6e0e39c2c97992250e1494 --only formal_build --dry-run` | 0 | 0.01秒 | [再選択](l1cc2-formal-retry-dry-run.log)。古くなったformal_buildだけを選択 |
| 同じ指定から `--dry-run` を外して実行 | 0 | 0.78秒 | [出力](l1cc2-formal-retry.log)。既定のlake buildが全証明・全例・六実行ファイルを含めて成功。sorryなし |
| formal/で `lake env lean ../docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l1c/l1cc2-axioms.lean` | 0 | 0.68秒 | [確認ファイル](l1cc2-axioms.lean)、[出力](l1cc2-axioms.log)。既存45件と新しい支持保存6件。Lean標準のpropext・Classical.choice・Quot.soundだけ |

完了検査三単位の初回は一度だけ実行し、失敗の修正後はformal_buildだけをやり直した。成功済みのspec_examplesとspec_tallyは繰り返していない。Rustのソースは変更しておらず、全lib・clippy・fmt、gc-stress、all-targets、check-formal.sh全体は実行していない。旧版の独立交換入力の確認はL1d、全比較は計画で割り当てた後の作業へ残す。

### 計画からの具体化と申し送り

R44はR42の支持保存を具体化した内部の補助の契約であり、公開する主要定理や健全性11件の適用範囲を狭めていない。公理・仮定・sorryの追加はない。既存のassertの削除・期待値の緩和・ignoreはない。合意済みの意味の変更による六つの既存例の期待値の変更と、新しい節の例の証明方法は前述のとおりである。

L1cは正式な接続済みの状態で完了した。`checker-migration.patch` とstateの元のハッシュ・対象一覧は、前回の区切りの履歴として残す。stateには接続済みで再適用しないことを記した。次はL1dの読者の正規化境界と旧版の独立入力を確認する。Failの新しい構文・捕捉・NoFailはL2へ残す。コミットとdocs/todo/の変更は行っていない。

記録末の確認では、変更したMarkdown五ファイルのローカルリンク182件を見出しまで確認した。正式なLeanソース153件に未完の証明語とaxiom宣言がなく、主要定理・健全性11件・仮定のファイルに差分がないことを確認した。最後に直したSurface.Examplesも既存の命題・例数を維持し、変更はsimpの展開の一覧だけである。git diff --checkは終了0であった。

行数の増減（開始時HEADとの差分。生成したログと文書は除く）は、Leanの定義と証明が+2046/−1476行、Leanの既存例と追加例が+75/−48行である。例の削除はなく、使われなくなった一時的なLegacy入力走査とLegacy専用の補助を整理した。

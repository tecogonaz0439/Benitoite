# L17 の結果

状態: **L17 の実装・指定検査・仮定の照合は完了した。** 七種の整数を通す独立表五つと、計算した評価導出を任意の解析予算の中心定理へ渡す例を既定ビルドに含めた。全248モジュールの直列ビルドと指定 work の三単位は成功した。C2 の独立レビューと受け入れは、依頼どおり取りまとめが本枝の後に行う。

## 基準と変更範囲

- 作業日: 2026-10-25。ブランチ: `mod012/L17`。
- B_WORK・開始時と終了時の HEAD: `5b491e3f549b505b58ece01f8953bbca8642b45f`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提と依存・契約表・L13〜L17・L16 の分割変更・work L17、D2・D15・D20、README の設計者の決定、preflight、study 9.4、L13〜L16・L16b・L16b2・L16c の申し送りと取りまとめのレビューを確認した。
- `private/` と、それを指すスキルのリンクは読んでいない。公開の rtk・japanese-tech-writing・test-audit を適用した。本枝は指定された実装担当の範囲を主担当が直列に実施し、C2 の独立レビューを代行していない。
- 開始時に読み取り照会として `git branch --show-current` を一度使った。禁止されたコマンド名を用いた点は手順上の逸脱である。HEAD・index・ブランチの変更はない。それ以後の git の使用は status・diff・show・rev-parse・ls-files の読み取り照会だけである。add・commit・merge・stash・reset・checkout・tag・push は行っていない。
- Rust、依存・lock、検査設定、`formal/lakefile.toml`、A11 の固定 TSV は変更していない。docs/todo の更新・コミット・取り込み・公開は行っていない。

| ファイル | 変更内容 |
|---|---|
| `formal/Benitoite/Interval/Examples.lean` | 既存の具体値の観察に Integer64 の分岐を加え、七種で観察処理を共用した。独立表五つと任意の Parameters を扱う正常値の例を追加した。既存の例の本文・期待・上限は保持した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 追加した例の範囲と、数学上の Int と Rust・ホストの演算の区別を記した。六幅の match を未知としていた本文を、L16c の実装と同章の対応表に合わせた。相互帰納の一覧へ既存の EvalWidthArms を補った |
| 本ディレクトリ | 検査の実行器・生ログ、差分と公理依存の照合入力・結果、および本記録 |

01-12 の写しに変更を要する定義・言明は追加していない。言語の規則と形式化の実行定義・証明本体は変更していない。07-04 の見出しと text フェンスは基準と同じである。

## 独立例と作成時の関門

期待する型・十進の端点・具体値・演算・引数・原因・キーを、解析結果や型の上下限の関数から作らずに固定した。小さいリテラルの共通準備は `Fin 4` に限り、境界のリテラルと十進の期待値は表へ直接記した。証明は `decide +kernel` を使い、大きな計算を rfl で展開していない。

| 独立表 | 対象と件数 | 検出する退行 |
|---|---|---|
| 上下端と中間失敗 | 七種×6入力＝42入力。上下端から内側の一点、外側へのあふれ、`(max+1)-1` と `(min-1)+1` の子の失敗 | 幅の取り違え、値域外の正常値の復活、数学上の最終値だけによる誤った成功、子の失敗を親の演算や番号で報告する誤り |
| 相関を使わない減算・正と0の定数倍 | 七種×5入力＝35入力。局所の正常区間は `[1,3]`、具体値は2。`x-x` は符号付きで `[-2,2]`、符号なしで `[0,2]`。左右の3倍は `[3,9]`、0倍は `[0,0]` | 相関の無断追加、片側だけの定数倍への接続、変数が複数値のときの誤った Top、0倍で正常値を失う誤り |
| 負の定数倍と一般負号 | 符号付き四種×3入力＝12入力。局所の正常区間 `[-2,4]` に対し左右の−3倍は `[-12,6]`、負号は `[-4,2]` | 負の係数・負号の端点交換漏れ、Integer64 と小さい符号付き幅の経路差 |
| 合流・束縛・match・guard | 七種の入力を真偽の具体環境で各一度、計14実行。0と2を `[0,2]` へ合流し、guard の後の減算・後続腕の加算を評価する。具体値はどちらも1、解析は `[1,3]`。比較は key 7、選択した加算・減算はそれぞれ key 13・10 | 合流から種類付きの腕への接続漏れ、guard の束縛や復帰の誤り、未選択の部分木を飛ばした際の番号の詰め直し、後続腕への否定事実の無断伝播 |
| 合流後の部分的なあふれ | 七種の入力を真偽の具体環境で各一度、計14実行。型の上下端を合流して1を引く。下端では失敗、上端では成功。解析は `[min,max-1]` と警告なし | 片端の失敗から全域外の警告を出す誤り、正常区間を消す誤り、値域との交差を忘れる誤り |

有限表は計103入力形・117回分の具体評価の期待を持つ。これらに加えて、七種それぞれの `2-1` の実際の閉じた評価から EvalPartial の導出を得て、任意の `Parameters` の `analyze_normal_sound` へ渡す例を置いた。深さ0・初期消費あり・上限超過を排除する前提はない。

test-audit の作成時の関門では、入口を `evalClosed` と予算付き `analyzeExpr` にそろえた。既存の葉と局所算術の例、六幅の小さい演算の例だけでは、境界での中間失敗や、合流から種類付き match への連続した接続を検出できない。既存の準備と観察を共用し、本番へのテスト専用の入口・公開範囲・欄・引数は加えていない。削除したテスト、緩めた期待・規模・ignore・時間制限はない。Byte の算術、符号なしの一般負号、一般の積や商・剰余の結果区間の精密化も加えていない。

本番の定義・証明の行数の増減は0である。独立例の Examples は170行追加・1行削除（章題の変更）、対応文書は7行追加・3行削除である。結果と検査記録のファイルはこの集計に含めていない。

## 検査と結果

途中は関係する Lean の局所検査だけを行い、作業末は同じ基準・指定の dry-run の後に work を一度実行した。Cargo には既存の書き込み可能なキャッシュ `/private/tmp/benitoite-a01a-cargo` を使用した。formal の固定版は Lean 4.34.1、arm64-apple-darwin24.6.0、commit `5045d0056413266e57c625dcd7c365b10e377c52` だった。

```sh
python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/local-build.py Benitoite.Interval.Examples
python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/local-build.py

# 以下の三つは formal/ で実行。
lake env lean -M 12288 Benitoite/Interval/Examples.lean
lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/axioms.lean
lake --no-build build

# 以下はリポジトリの根で実行。
scripts/check.sh --level work --base 5b491e3f549b505b58ece01f8953bbca8642b45f --only formal_build,spec_examples,spec_tally --dry-run
python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/run-work.py
python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/contract-check.py
git diff --check
```

run-work.py が実行した検査本体は、次の指定である。シェルは検査の終了状態をログへ記してから、その同じ終了状態で終える。

```sh
env CARGO_HOME=/private/tmp/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l17/run-work.sh
```

| 確認 | 結果・終了状態 | 時間・記録 |
|---|---|---|
| 関係する Examples の初回局所ビルドとファイル単体の確認 | 0。五表と、続いて追加した任意予算の例が成功 | 個別の外側の時間は未計測。[sequential-build.log](sequential-build.log)・[local-example.log](local-example.log) |
| 全248モジュールの依存順のビルド | 0。各モジュールの依存を先に作り、順番に一つずつ実行 | 外側44.096秒。[local-build.py](local-build.py)・[sequential-build.log](sequential-build.log) |
| `lake --no-build build` | 0。既定の全340タスクが up-to-date。既定 build が新たな並行ビルドを要しないことを確認 | ツールの表示0.048秒。[default-up-to-date.log](default-up-to-date.log) |
| 33宣言の公理依存 | 0。Lean 標準の propext・Classical.choice・Quot.sound の範囲 | ツールの表示0.503秒。[axioms.lean](axioms.lean)・[axioms.log](axioms.log) |
| 指定三単位の dry-run | 0。仕様集計・仕様例・既定 Lean ビルドだけを選択 | 外側未計測。[dry-run.log](dry-run.log) |
| 指定三単位の work（一度） | **検査本体0**。`L17_CHECK_EXIT_STATUS=0`。計測器の終了は1 | 実行器の外側3.357秒。time の real/user/sys は3.35/3.74/0.26秒。[run-work.sh](run-work.sh)・[run-work.py](run-work.py)・[work.log](work.log)・[work.json](work.json) |
| 基準との定義・定理・設定・固定入力の照合 | 0 | 外側未計測。[contract-check.py](contract-check.py)・[contract-check.log](contract-check.log) |
| `git diff --check` と変更箇所の読み取り点検 | 0。既存の例の本文、文書の見出し・text フェンスを保持 | 外側未計測。本枝の点検は C2 の独立レビューとは区別する |

仕様例は **7件成功・失敗0件・ignored 0件**、テスト時間2.95秒だった。仕様集計の自己検査は成功し、初回リリースの完了条件の未記入は0件だった。参照のない仕様節の一覧は失敗と区別して生ログに残した。formal_build は既定の `lake build` と sorry の拒否を通った。既存の Flow・Sound・BudgetAnalyze・BudgetNormal の linter 表示は局所ビルドのログへ残し、本枝では抑制していない。追加した例に linter の表示はなかった。

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` は `sysctl kern.clockrate: Operation not permitted` で終了1となり、常駐量を出力しなかった。検査本体の終了0と計測環境の制限を区別し、常駐量を測定済みとは扱わない。

`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を保った。ファイル単体の検査には `lake env lean -M 12288` を使用した。Lean のプロセスとビルド呼出しを並行させていない。局所ビルドは依存順に一モジュールずつ行い、既定の全ターゲットが作成済みであることを `--no-build` でも確認してから作業末の入口へ進んだ。

## 定義・言明・仮定の照合（C2 への受け渡し）

`git diff` と開始版のファイルの直接比較により、**NormalSoundness・WarningSoundness の定義全文は基準と一致**した。Examples を除く formal の追跡ファイル305個はすべてバイト単位で一致し、そこにある名前付きの theorem・lemma 2713宣言も本文とともに不変である。旧主定理、公理、Builtins.Assumptions、領域・評価関係・解析・予算の定義に変更はない。Examples の旧本文も、章題と観察用の Integer64 の一分岐、追加例だけを除いた直接比較で一致した。sorry・admit・新しい公理の追加はない。

公理依存の検査と、定理の引数として要求する仮定は区別した。`#print axioms` の33宣言には独自の公理と sorryAx がない。これだけを理由に、旧主定理の Builtins.Assumptions や、新しい二命題の Models・評価導出などの前提が不要とは扱わない。

| 定理・定義 | 必要な前提・定義との対応 | 結論と限界 |
|---|---|---|
| `IntegerValue kind`・`Interval kind` | 端点・具体値は数学上の Int。具体値は種類ごとの有限値域の証拠を持ち、closed は順序と型域の証拠を持つ。Integer は integer64 の別名、Byte は IntKind に含まれない | 有界な七種の整数を定義の内側で表す。Rust の型・変換・ホストの幅は表していない |
| `add_normal_sound`・`sub_normal_sound`・`mul_normal_sound`・`neg_normal_sound` | 実際の正常引数が子の区間に所属することと、検査付き演算が当該正常値を返すこと。負号には `kind.min < 0`。定数倍の端点の補題は片辺が一点であるとの認定を使う | 正常結果の区間所属。mul_normal_sound 自体は両辺が複数値の場合も型内 Top として覆う。x-x の相関、一般の積の精密化を結論しない |
| `*_always_overflows_sound`・`divMod_always_zero_sound` | 正常に得た引数の子の区間への所属と、全域外・一点0の判定が真であること。除数0の判定は intDiv/mod だけを認める | 原因どおりの検査付き演算の拒否。子の失敗は親への到達ではなく、部分的なあふれは全域外ではない |
| `checkedWidthBinary_contains`・`checkedWidthNeg_contains` | `kind ≠ integer64`、子の BaseApprox.Contains、具体演算の正常結果。負号は符号付きであることも要求。Integer64 は既存の補題に分岐する | 六幅の具体演算を同じ種類の解析へ接続する。七種全体の中心定理へ六幅専用の追加仮定を持ち込まない |
| `Models`・`models_bindRangeKind`・`conditionEnv_sound` | Models は局所の長さと各位置の対応、具体・抽象の standards と apiAt の一致。束縛は型と正常区間を保存。条件の補題は Models と正常な Boolean の評価導出を要求する | 選ばれた条件環境の存在と同じ具体環境との対応。別名への逆伝播や名前解決自体の正しさを証明しない。表の一致は標準 API の意味や δ の一致の仮定ではない |
| `models_matchKindArmEnv`・`match_width_selection_models` | 正常区間所属、実際の照合成功、局所位置の lookup、PatternLocals、slots の選択と共通束縛数、選択肢への所属。後者は具体的な照合値の評価と WidthSelection を受け、前者の条件を導く | 束縛順・反転と腕入口の Models を保存する。六幅は束縛・wild と guard に限る。言語で許さない幅付き定数・範囲パターンを新しく受理しない。構造内部の値は推測しない |
| `analyzeBase_normal_sound`・`BudgetAnalysis.analyze_normal_sound` | NormalSoundness の同じ文面。任意の抽象・具体環境・入力・予算・正常値・trace について Models と正常な EvalPartial の導出。予算付きの Parameters は上限・初期消費・深さを持つ | 正常値の型の一致と解析近似への所属。完走・予算内を要求せず、全実行の成功・停止・returned の値・mayFail の完全性は結論しない |
| `analyzeBase_warning_sound`・`BudgetAnalysis.analyze_warning_sound` | WarningSoundness の同じ文面。Models、任意の outcome の EvalPartial、出力の警告への所属、同じ trace の `Reached`。Reached は事象への所属・キー・対象演算の一致だけであり、拒否原因の一致を仮定しない | `event.result = rejected warning.cause.toFailure`。警告位置へ到達すること、全体の異常終了、停止性は結論しない。正常な引数を得ていない親は Reached の根拠にならない |
| `BudgetAnalysis.analyzeBody_normal`・`analyzeBody_warning_sound` | Models は入口の forget 後の環境に対して要求する。本体の bodyRoot と bodyRootKey に対する評価導出。警告の系は出力への所属と Reached も要求する | 入口の計上・忘却・全体上限による事前停止を含める。捕捉元の整数の事実を仮定として持ち込まない |
| `analyzeBase_warning_located`・`BudgetAnalysis.analyze_warning_located`・`analyze_warning_syntactic_reach` | 出力の警告への所属。具体環境や EvalPartial は要求しない | 同じ先行順の出現で対象演算が一致し、具体規則だけで辿れる構文上の範囲にある。元 AST/span との対応や、実際にその位置へ到達できることは証明しない |
| `analyzeExpr_independent_sound`・`analyzeBody_independent_sound` | 保存列の各 entry への所属から entry.Sound を与える。その正常値・原因の保証を使うときは、保存された initial と Models、および**独立入力自身**の Evaluates を要求する。原因にはその trace の Reached も必要 | 未知の親の空 trace を子の警告の根拠にせず、忘却後の独立入力として保証する。未保存・未解析の入力を解析済みにしない |
| `evalClosed_sound`・`evalClosed_trace_keys`・`widthArms_trace_keys` | 閉じた評価の some の結果に付いた EvalPartial の導出、または当該評価・腕の導出 | 計算結果の対応と trace の番号範囲・一意性。none は深さ不足や評価不能も含み、言語の失敗や導出不存在とは同一視しない。型付けから全入力の導出存在、評価関係との双方向の同値は証明しない |
| 旧 `Release.progress`・`preservation`・`effect_soundness` | WellTyped・EffectsOk・Builtins.Assumptions。保存・エフェクト健全性は WellFormed も要求する。進行・保存は状態の型付け、保存は実際の遷移も必要。エフェクト健全性は閉じた純粋な初期計算などの既存条件を持つ | 既存の意味・言明・仮定を維持した。抽象 δ の型の仮定から、各幅の具体的な算術と VM の一致を導かない |
| 旧 `Surface.desugar_typed`・`surface_effect_soundness` | 前者は表層の WellFormed・WellTyped と組み込みシグネチャの Scoped。後者は既存の Builtins.Assumptions と純粋な main も要求する | 脱糖の型保存と表層のエフェクト健全性。区間解析の対象構文の評価関係から Release の実行への意味保存を新しく証明したものではない |

L16c 後の matchWidth・EvalWidthArms と、matchOtherNormal/Failed から七種を除外する条件も読み取りで照合した。07-04 の対応表は既にこの状態だったが、同章の本文の二段落と相互帰納の一覧に旧記述が残っていたため、本文を直した。定義や中心命題を本文の旧記述へ合わせて戻す変更はしていない。

最大 u64 同士の積も数学上の Int で扱う保証であり、Rust の i128・u128 や usize による計算を検証したものではない。D20 の「符号付きは i128、UnsignedInteger64 の積は u128 で値域と比較してから戻す」境界、32ビットと64ビットのホストでのカウンタ・変換、解決済み標準束縛の取得、VM との値・失敗・到達の一致は、後続の実装・比較の担当範囲である。

## A11 の固定表と後続への申し送り

body.tsv・whole.tsv・summary.tsv は作り直していない。三表は B_WORK とバイト単位で一致し、SHA-256 を contract-check.log に保存した。今回の差分は独立例と対応文書だけで、解析・評価・費用・生成器の定義に変更がないため、**本枝が新たに期待値を変える形は0件**である。新しい期待値の算出や固定表の生成は実行していない。

| 表・形 | 本枝からの新しい変更 | 引き継ぐ状態 |
|---|---|---|
| body: unsupported・negate | なし | L16a の `l16/results.md` にある差を保持する。保存済みの表はその接続前の値のままであり、現在の Lean と全行一致したと扱わない |
| body のその他、whole、summary | なし | 本枝から追加の差分値は渡さない。Rust と三表をそろえるのは計画どおり A13〜A15 と取りまとめの担当 |

mayFail を診断や受け入れへ使わない契約、一般の積と商・剰余の結果は型内 Top にする境界、標準 div・absolute の旧定数警告の境界を維持した。Rust 全 lib・全統合・clippy・fmt、heap、stage・change・release、性能測定、Rust/Lean・VM の全比較は本枝の割り当て外であり実施していない。

## 初回の失敗と修正・計画からのずれ

- 差分記録用の contract-check.py の初稿で、WarningSoundness の後にも次の doc コメントがあると仮定して抽出し、ValueError になった。定義直後の空行で区切り、定義の本文全体を比較するように直した。
- 同じ記録器へ公理依存の検査を加えた際、Lean の複数行表示の余分な空白を除去せず集合比較し、AssertionError になった。依存名を strip してから比較するように直した。修正後は33宣言すべて成功した。これらは記録器の失敗であり、Lean の証明や指定 work の失敗ではない。
- 開始時の `git branch --show-current` の読み取り照会、および常駐量の取得不能は上記のとおりである。git の状態や権限・検査設定を変える回避はしていない。
- 言語の規則、中心二命題、既存の主定理の前提・結論、公理を変えないと進められない問題はなかった。L17 の範囲を閉じ、指定検査の未実施・不合格は残っていない。

| 残る手順 | 担当・受け渡すもの | 見込み |
|---|---|---|
| C2 の独立レビューと受け入れ | 取りまとめ。既定ビルド・指定 work・上の仮定表・公理と差分の照合・七種の独立例を渡す | 不明 |
| A13〜A15 の実装と比較 | 後続担当。七種の型域、左右の定数倍、子の中間失敗とキー、部分失敗と全域外の区別、保存済み三表の既知の差を反映する | 計画の各枝に従う。本枝での再見積もりは行っていない |
| コミット・取り込み、改造全体の検査・受け入れ・公開 | 取りまとめ。C2 の結果と後続作業の完了を確認する | 不明 |

作業末の work 開始後は、Examples・設計書・その他の実装や証明を変更していない。以後は本記録と照合の記録器・ログだけを編集した。別状態の検査結果の引用は行っていない。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。差分は独立例の追加と 07-04 の範囲の記述だけである。C2 の独立レビューは取りまとめが依頼する（`reviews/RV-C2.md`）。受け入れる。

# Q1: 0.0.10 の short の退行調査

## 結論

元のshortが示した遅延は、比較器を介さない直接実行でも再現した。調べた範囲では、M1・Z8によるビルド条件の違いが原因とは考えにくい。両状態のビルド設定とCargo fingerprintは一致し、新たにビルドした実行ファイルでも同じ傾向になった。

大きな増加が入った取り込みは **G2（ebd22a93）** である。直前のG1との差は、空に近い入力で約2.12 ms、関数1,000個で約14.14 ms、引数付き関数1,000個で約25.95 msだった。既定で読むLogに12個の型クラス実装が加わり、型検査が関数ごとにその実装の索引を作り直す既存の処理で、空欄を含む大きな表を繰り返し走査するようになっていた。

これとは別に、T5（379d2f93）の前後にも小さな増加がある。成功時にも診断のための型の依存情報を記録する変更と整合するが、個別関数のCPU時間の割合は取得できていない。固定費の増加全体を一つの取り込みだけに帰属させず、主な増加をG2、小さな増加を別に記す。

処理系・formal・共通測定器・テスト・docs/todoは変更していない。修正案の効果は未測定である。元の66点のうち代表7点を直接確認し、取り込みの探索と段別測定は指定の3点に絞った。他の59点の個別の原因は追跡していない。

## 対象と測定条件

- before: `c31e64b03d2810343e1779926bea4ebc958b6164`（0.0.9）。
- after: `270a717c670d9640d4c08f10bc400afa6e3fcef2`（Z7まで）。Z8を含む作業HEADとは区別した。
- 作業HEAD: `9cce9775e1dba6ed0044b8093ca0a54655e7923e`。
- 元の記録: [2026-10-21-270a717c-comparison](../../../tools/bench/results/2026-10-21-270a717c-comparison/results.md) と同ディレクトリのmanifest.json、section-*.json。
- Apple M4、macOS 27.0.1、aarch64-apple-darwin、rustc 1.98.1（48a229cea、LLVM 22.1.8）、cargo 1.98.1、Python 3.9.6。
- 各状態・各点を2回準備実行した後、30回採取した。同じ入力の状態を順に実行し、次の回は状態の順を逆にした。同時には実行せず、測定中にビルドも重ねていない。
- CLIの時間はPythonの`perf_counter_ns()`でsubprocess.runの呼び出しから終了までを測った。stdout/stderrを取得し、終了0・stderrが空・stdoutが元のCaseの期待値と一致することを全回確認した。CLIを起動する前のPythonによる入力hashの確認時間は含まない。
- 環境は比較器と同じくRUSTFLAGS、CARGO_ENCODED_RUSTFLAGS、CARGO_BUILD_RUSTFLAGS、CARGO_BUILD_TARGET、CARGO_TARGET_DIRを除き、`BENITOITE_DEV_IO_MODE=direct`を設定した。

性能の表はミリ秒、標本の中央値である。末尾のコマンドの時間だけは秒で示す。絶対時間は採取の時刻によって動くため、取り込み前後の差は最後の同じ交互測定で比較した。今回の調査は設計者が指示した追加確認であり、正式なtargetsの受け入れ測定には代用しない。

## ビルド条件の照合

| 項目 | beforeとafterの確認結果 |
|---|---|
| profile | 両方release。元のログも`release profile [optimized]` |
| opt-level | 両方3。Cargo.tomlに上書きなし。Q1のverboseビルドで`-C opt-level=3`も確認 |
| LTO | 両方Cargo既定のfalse。クレートをまたぐLTOの指定なし。falseは同じクレート内のThin local LTOを許す |
| codegen-units | 両方releaseの既定16。設定ファイル・環境・コマンドに上書きなし |
| overflow / panic | 両方overflow-checks=true、panic=unwind。workspaceの明示設定は同一 |
| Cargoの機能 | manifestは両方default。fingerprintの実際の集合も両方`["default", "gc-mark-sweep"]`。alloc-stats等なし |
| target / compiler | 両方hostのaarch64-apple-darwin。rustc -Vvとcargo -Vが同一 |
| 依存 | Cargo.lockの差はbenitoite自身の版だけ。正規化した依存のSHA-256が同一 |
| Cargo設定 | 作業ディレクトリ・親とユーザーの設定にprofile/targetの上書きなし。リポジトリの.cargo/config.tomlは両状態ともwarnings=denyだけ |
| fingerprint | 両方profile=`1957810092726506406`、rustc=`17329007180185699724`、rustflags=`[]` |

releaseの既定値とLTO=falseの意味は[Cargo公式文書](https://doc.rust-lang.org/cargo/reference/profiles.html#release)で確認した。実際の設定との照合にはリポジトリのCargo.toml・.cargo/config.toml・各archive・元のmanifest・fingerprintとQ1のverboseビルドを使った。

正規化した依存のSHA-256は`f443d0615bb664564cf73208bb1878318ce49fb8179e0f29ce4ad67e4d1b8591`である。workspaceのCargo.toml、.cargo/config.toml、rust-toolchain.tomlは同一だった。crates/benitoite/Cargo.tomlは版だけが違う。各archiveのcrates/benitoite/srcの全追跡ファイルも、対応するコミットのバイト列と一致した。

M1のbuild.pyの変更は、CLIのビルド後に行う独立probeのコンパイルと変換用ソースの抽出に関わる。CLI本体の`cargo build --release --locked -p benitoite --manifest-path ... --target-dir ...`、機能の指定、clean_envは0.0.9の道具から変わっていない。features.pyは、小さいプログラムを実行して利用できる機能とCaseの対象状態を決めるもので、Cargoの機能を切り替えない。Z8のprobeの修正も別の実行ファイルへの変更である。元のmanifestのbuild.py・features.pyのhashは現存する道具と一致した。

元のキャッシュ記録のキーにはCargo設定ファイルのhashまでは入っていないため、その記録だけで過去の外部設定を完全に証明できるわけではない。そこでQ1では両端を改めてビルドし、元の実行ファイルとの同時期の比較も行った。次節の一致は、この記録上の限界を補う確認である。

元の実行ファイルのSHA-256もmanifestと一致した。

| 状態 | SHA-256 |
|---|---|
| before | `e21ce5b9569aa1cf3ea90e4e31a04d10586326e74879aed3dec561102e540de1` |
| after | `ae91ca6b7f7a5bb6c6c95d78fbe333037dc6b9d3d0d40b739113d428fda36a2f` |

## CLIを直接実行した結果

functions・higher・classesは元のCaseと同じ`check --diagnostics=json`、runtime-fib-shortは元の`run --diagnostics=json`と引数を用いた。空に近い入力のfunctions-main-0-0はmainだけの37バイトである。

| 入力 | 元のshort before | 元のshort after | 直接 before | 直接 after | 直接の差 | 直接の倍率 |
|---|---:|---:|---:|---:|---:|---:|
| functions-main-0-0 | 11.477 | 13.979 | 9.833 | 12.459 | +2.626 | 1.27 |
| functions-main-1000-0 | 15.786 | 32.064 | 15.423 | 30.211 | +14.788 | 1.96 |
| functions-args-1000-0 | 19.860 | 48.972 | 19.567 | 46.627 | +27.060 | 2.38 |
| functions-modules-1000-0 | 16.212 | 25.288 | 15.822 | 23.904 | +8.082 | 1.51 |
| higher-0-300 | 19.669 | 27.498 | 19.240 | 26.176 | +6.935 | 1.36 |
| classes-300 | 30.167 | 39.349 | 29.027 | 37.560 | +8.533 | 1.29 |
| runtime-fib-short | 15.295 | 18.287 | 14.142 | 17.550 | +3.408 | 1.24 |

元のshortと絶対時間には差があるが、約2〜5 msの増加と大きな入力での倍率の増加は再現した。比較器の時間集計だけが遅延を作ったとは考えにくい。

さらに、元のキャッシュの実行ファイルとQ1で新しくビルドした実行ファイルを、4状態で交互に30回測った。

| 入力 | 元のbefore | 新ビルドbefore | 元のafter | 新ビルドafter |
|---|---:|---:|---:|---:|
| functions-main-0-0 | 10.908 | 10.929 | 13.711 | 13.681 |
| functions-main-1000-0 | 16.457 | 16.427 | 31.705 | 31.683 |
| functions-args-1000-0 | 21.056 | 21.046 | 48.908 | 48.999 |

この3点では、新ビルドと元の実行ファイルの中央値の差は約0.1 ms以内だった。依存クレートの生成物はQ1専用target内で再利用したが、両端ともbenitoite本体を再コンパイルしており、元のcompareのCLIビルドを取り込んでいない。

## 取り込みの二分探索

`git log --first-parent --oneline c31e64b0..270a717c`の41コミットを対象にした。主な増加の探索順はT5→G3→Z2→G1→G2であり、最後に隣り合うG1/G2まで絞った。その後、T5以前の小さな差を確かめるためL4bとT4を加えた。下表は時系列順であり、全9状態を同じループで30回交互に測り直した最終の値である。

| コミット | 取り込み | 空に近い入力 | 関数1,000個 | 引数付き1,000個 |
|---|---|---:|---:|---:|
| `c31e64b0` | 開始版 | 10.579 | 16.143 | 20.532 |
| `04f6fca9` | L4b | 10.586 | 16.073 | 20.493 |
| `cd850d53` | T4 | 10.579 | 16.207 | 20.873 |
| `379d2f93` | T5 | 11.038 | 17.055 | 22.519 |
| `498943fe` | Z2 | 11.211 | 17.191 | 22.494 |
| `367ef026` | G1 | 11.388 | 17.322 | 22.530 |
| `ebd22a93` | G2 | 13.508 | 31.466 | 48.481 |
| `bb5ade0e` | G3 | 13.519 | 31.428 | 48.592 |
| `270a717c` | Z7（比較のafter） | 13.527 | 31.462 | 48.764 |

G1→G2の差は、3点とも標本のばらつきより大きい。両点のIQRの和は順に約0.79、0.74、0.58 msであり、増加は約2.12、14.14、25.95 msだった。固定費と大きな入力の双方で、主な増加の取り込みをG2に特定できる。

T4→T5の差は約0.46、0.85、1.65 msである。空に近い点の差は両点のIQRの和（約0.50 ms）以下なので、固定費の小さな増加をここだけで確定しない。G2以前にも小さな差は残るが、shortの調査目安の2 msより小さい。T5以外の小さな差をすべて個別の取り込みへ分解する探索までは行っていない。

二分探索の初期のG3ビルドでは、同じ展開先でgit archiveの古い更新日時が保持され、Cargoが直前のT5の生成物を再利用した。0.109秒で終わりバイナリのhashもT5と一致したため検出した。その測定を*.invalid.jsonへ分け、すべての展開入力の更新日時を更新してG3を再ビルドした。以後のビルドは各ログにbenitoiteのコンパイルがあり、最終表に無効な点は含めていない。元のcompareはコミット別の展開先とtargetを持つため、このQ1の一時スクリプトの問題とは別である。

## 段別の時間

既存のtools/bench/compare/timing_probe.rsから作られた各状態のprobeを直接使った。まずcheckモードを30回交互に測り、CLIのcheckに関わる段を比べた。

| 入力 | 読み込み・解析 before→after | 名前解決 before→after | 型検査 before→after | 再解析 before→after（参考） |
|---|---:|---:|---:|---:|
| functions-main-0-0 | 1.655 → 1.872 | 0.804 → 0.921 | 3.361 → 5.707 | 1.221 → 1.387 |
| functions-main-1000-0 | 2.777 → 2.993 | 1.308 → 1.446 | 6.925 → 21.661 | 2.308 → 2.515 |
| functions-args-1000-0 | 3.815 → 4.012 | 2.034 → 2.219 | 9.233 → 36.546 | 3.320 → 3.434 |

大きな入力のCLIの増加分と、型検査の増加分の大きさが一致する。空に近い入力でも型検査が約2.35 ms増えた。読み込み・解析はファイルの読み込みと標準ソースの解析を含む。再解析は読んだ全ソースをもう一度解析する参考値であり、読み込み・解析に加算しない。標準ライブラリの準備だけを分離する既存の段はないため、後述のソース数・宣言・呼び出し箇所も合わせて判断した。

脱糖以降も確認するため、別のstagesモードで同じ3点を30回測った。

| 入力 | 脱糖 before→after | IR検査 before→after | 判定の木への変換 before→after | コード生成 before→after | VM実行 before→after |
|---|---:|---:|---:|---:|---:|
| functions-main-0-0 | 0.937 → 1.600 | 1.034 → 1.158 | 0.549 → 0.873 | 1.581 → 2.199 | 0.202 → 0.225 |
| functions-main-1000-0 | 0.812 → 1.100 | 0.680 → 0.861 | 0.458 → 0.626 | 1.906 → 2.439 | 0.133 → 0.146 |
| functions-args-1000-0 | 2.432 → 2.614 | 2.275 → 2.196 | 1.273 → 1.352 | 4.056 → 4.715 | 0.102 → 0.113 |

stagesモードは単独の型検査と再解析の後で公開pipelineのcheckも通す。この表をCLIの内訳として足し合わせることはできず、checkの入力には本来ない後段の観測である。各段の失敗なし、IR拒否なし、VMの終了0をprobeが確認した。大きな入力で10〜30 ms増える箇所は、これらの後段には見当たらなかった。

## 原因について確認できたこと

### G2で追加した実装と、関数ごとの索引作成

次の処理は、差分と現在のソースの双方で確認した。

1. G1はprelude/mod.rsにSourceLocationとLogをprelude=trueで登録した。modules/load.rsのload_programはpreludeのモジュールを入口の直後に読み、後から明示importのモジュールを読む。
2. G2はLog.bntにToLogValueの12実装、attribute、各レベルの関数、3種のハンドラ等を加え、IO.Consoleをimportした。Logを使わないmainだけでもLogとその依存を読む。
3. typeck/decls.rsのcheckは読み込んだ全ASTの関数・実装メソッドをcheck_functionで検査する。標準ソースの追加分も起動のたびに検査する。
4. typeck/solve.rsのSolver::solveは、各本体についてsolve_ready_classesとsolve_classesを呼ぶ。typeck/traits/solve.rsのsolve_classesは、制約があるかを調べる前にtable(ctx.decls)を呼ぶ。
5. tableは`d.out.impls.iter()`から全実装の索引をBTreeMapへ作り直す。implsはNodeMapであり、base/mod.rsのNodeMap::iterはVec<Option<T>>の全欄を走査してSomeだけを返す。実装の数が12でも、最後の実装のノード番号までの空欄を読む。

実際に公開APIで同じ入力をload・resolve・typecheckし、実装数と最後のノード番号を観測した。さらに、既存tableと同じ走査・索引作成だけを公開出力に対して1,000回行った。5回の交互測定の中央値を示す。この補助のRustはtarget/q1/typeck_probe.rsだけに置き、処理系を変更していない。

| 入力 | beforeの実装数 | afterの実装数 | afterの最後の番号 | afterの表の欄数 | 索引作成1,000回 before | 索引作成1,000回 after |
|---|---:|---:|---:|---:|---:|---:|
| functions-main-0-0 | 0 | 12 | 3,820 | 3,821 | 0.0018 | 1.919 |
| functions-main-1000-0 | 0 | 12 | 8,820 | 8,821 | 0.0017 | 4.515 |
| functions-args-1000-0 | 0 | 12 | 15,820 | 15,821 | 0.0017 | 8.953 |
| functions-modules-1000-0 | 0 | 12 | 3,830 | 3,831 | 0.0017 | 1.921 |

空に近い入力の読んだソース数は41→44、束縛数は1,250→1,372だった。増えたソースはSourceLocation、Log、IO.Consoleである。

入口に1,000個の関数を書くと、それらのノード番号がLogの解析より先に割り当てられる。引数とbindがあると番号もさらに増える。一方、別モジュールの関数はpreludeより後で解析されるため、実装表の末尾の番号は小さいままである。この番号の違いは、functions-modulesの増加がmain・argsより小さいこととも整合する。

コードからは、各本体で少なくとも2回、空欄を含む表の索引を作り直すと分かる。関数数をF、最後の実装までの番号をNとすると、その走査量は少なくともF×Nに比例する。入口の関数を増やす場合はNも増えるため、この部分が関数数の二乗に比例して増え得る。これはコードと番号から分かる構造であり、複数の入力サイズで二乗の曲線を測ったという意味ではない。

**確認した事実**は、G2の前後で遅延が増えること、型検査に集中すること、実装表が空から12実装へ変わること、各本体で全欄の走査と索引の確保を繰り返すこと、その走査自体にも観測できる費用があることである。**見立て**は、その不要な走査と索引の作り直しが、大きな入力の増加の主因であることだ。修正して測り直していないため、増加分の何%をこの関数で説明できるか、修正後に何ms戻るかは確定しない。

### 固定費として増えた標準ソースの検査

Logの追加された関数本体・12実装・ハンドラは、利用者がLogを呼ばなくても検査される。G2では既定で読むIO.Consoleも増えた。これは読み込み・名前解決・型検査と、runの脱糖・コード生成にも費用を加える。空に近い入力でのload_parse約0.22 ms増、resolve約0.12 ms増、typeck約2.35 ms増はこの処理と整合する。固定費の増加に占めるLogの個々の関数の割合は未測定である。

### T5の成功時の診断情報

T5はSolver::equalとflowの成功後にもrecord_provenanceを呼ぶ。record_provenanceは型の複製、形の追跡、型変数間の辺の記録を行う。この処理は誤りがない入力にも必要な情報を作る。T4→T5で大きい2入力の時間が小幅に増えることとは整合する。ただし後のZ2では情報の要約と回復なしの場合の短絡も加わっており、T5の最初の実装とafterの内部費用を同一視しない。この部分の個別の寄与は見立てにとどめる。

### プロファイラの制約

本測定と別に、標準ソースを準備して公開typecheckを繰り返す補助プログラムをsamplyで観測しようとした。6試行すべてが終了1・Unknown(1100)で失敗した。続いてmacOSのsampleで同じ補助の子プロセスを調べたが、終了255で対象を調べられなかった。sudo等による権限変更は行っていない。したがってCPUプロファイルの標本数や関数ごとの割合は報告しない。手順の補完はdecisions.mdのR220に記した。

## 修正案（未実装）

手間は実装と関係する検査・測り直しを含む着手前の目安であり、約束ではない。

| 案 | 変更の考え方と見込む効果 | 手間の目安 | 危険・確認すべきこと | 0.0.10の判断材料 |
|---|---|---|---|---|
| 型クラス制約がない本体で索引を作らない | solve_classesでClass制約がない場合は索引作成へ進まない。単純な関数でも発生する2回の走査・確保を避ける | 小、数時間〜半日 | 低〜中。Try/Resource等の残る制約と、部分的に確定した辞書・エラー後の状態を保つ。成功・拒否の診断が変わらないことを確認する | 変更範囲を狭くしやすく、今回の大きな増加に直接対応する第一候補 |
| 実装の索引を宣言の検査ごとに共有する | 実装の頭部とキーが確定してから索引を一度作り、各本体から参照する。状態はその検査の中に置く | 中、半日〜1日 | 中。宣言の検査中・不正実装・super辞書の更新との整合が必要。大域キャッシュは使わない | 上の短絡と組み合わせる候補。Classを使う本体にも効果を見込める |
| 実装を列挙する表の空欄を走査しない | impls専用の登録済み番号の一覧等を持つ。全NodeMapの表現変更へ広げず、実装の列挙を実装数に比例させる | 中、半日〜1日 | 中。並び順・登録の更新・重複や不正実装の扱いを維持する | 今回の空欄の問題に対応するが、索引を毎回作る費用は別に残る |
| 標準ソースの準備を事前に済ませるか、読む本体を減らす | Log等を起動のたびに解析・検査する固定費を減らす | 大、数日以上、設計の検討を含む | 高。preludeの契約、ノード番号、利用者の実装との整合、診断の位置、版と依存の照合が必要 | 今回の即時修正へまとめず、設計者が後の課題にするか判断する候補 |
| T5の依存情報の記録を軽くする | 同じ型の複製や形の展開を減らし、必要な情報を局所的に記憶する | 中、1〜2日 | 中〜高。独立した誤りを消さず、宣言へ移す診断と回復後の検査を保つ。誤りが起きたら全記録を省く、といった変更にはしない | 増加はG2より小さい。0.0.10へ急いで含める根拠は今回の数値だけでは弱い |

0.0.10で対処するなら、最初の2案を検討し、指定3点と型クラスを使う点で時間と診断を確かめることを推す。固定費をゼロに近づける設計変更や診断の規則を変える案は、今回の調査からそのまま着手する範囲にはしない。今回TODOの作成・変更はしていない。

## 入力のSHA-256

元のmanifestが指す各状態の入力は同じバイト列であり、直接測定の前に下表と照合した。modulesのPart0〜Part9もすべて照合した。入口の絶対パスは生の各測定のcommandに保存し、元のsectionのcommandsからそのまま取得した。入力の生成・修正は行っていない。

| Case / ファイル | SHA-256 |
|---|---|
| functions-main-0-0 / main.bnt | `ffabb71ea7b0966ea745713a207a811a6afcdf587e6fa597579e1bd4df338c7f` |
| functions-main-1000-0 / main.bnt | `6a0cb15728480a6bdea82cf2a7628500b94770794199cc689cc7e1718d4ba0aa` |
| functions-args-1000-0 / main.bnt | `958efba8d73b73ee8eef7caa8f93dda2c1f33282416345ebcea11a4a3654b060` |
| functions-modules-1000-0 / main.bnt | `d9a107c4669a89433ee26cf449bddcd801e81d45007f9ee22623f589fc02cd6c` |
| functions-modules-1000-0 / Part0.bnt | `3f23c733f5f3337e4811162d05cde175d835c756af1c89a6b52ac0b11f5ed8d9` |
| functions-modules-1000-0 / Part1.bnt | `6ec0a4b45988607bd8b8eec35435126dd6d313d07278d0015297a030e4528408` |
| functions-modules-1000-0 / Part2.bnt | `d5e66927b9e00a419cded20b05d6aa2ddffd39155068933f41b63ca856752bcc` |
| functions-modules-1000-0 / Part3.bnt | `8b229cd13fc2f39408875064f8eceead09dee9bf942b801560be462741308744` |
| functions-modules-1000-0 / Part4.bnt | `0b3c06728b9566e26f8e45faf02ed44a7c0289c1a79ca4ad9566761c09561c56` |
| functions-modules-1000-0 / Part5.bnt | `0102b476efed9edaa126e406d6a094947213734dd8ed69e1096c5f52bb2c4e32` |
| functions-modules-1000-0 / Part6.bnt | `6ad1526ab4f20775644aaf7dfb06513920c5dfb7de7c47f295e86f0a279b3d37` |
| functions-modules-1000-0 / Part7.bnt | `1973ccf0ed664e11414d956930a710d8baa8cd15ef9f090d6b2e2dcd9afca4f8` |
| functions-modules-1000-0 / Part8.bnt | `5483fddc688c103249825e9439a27ba420b51a525121670b20a2378c6fd9f273` |
| functions-modules-1000-0 / Part9.bnt | `cadde86de0bed439fc0584891606271287f68f0cfa900a9563cff08c4888021c` |
| higher-0-300 / main.bnt | `687cdb723237bb12672abb6379b7f3fb7b701ff9b26186c2c520d5885987e0d9` |
| classes-300 / main.bnt | `34289c37c68bd1a610a60b5e7447ae92d621a672ba6ac0fc19b6ebceab92d355` |
| runtime-fib-short / main.bnt | `f2926e736c27a924989257274ccc281d2ff58e48e562e1235bbc553ecd78089c` |

## コマンド・時間・終了状態

調査専用のPython/Rustと生の記録はtarget/q1/に置いた。性能の採取には共通compareのrun.pyを呼んでいない。測定用スクリプトが読むのは既存manifestとsectionのcommands・期待出力だけである。

直接測定の実体は、次のループである。実際にはCaseごとに両状態のファイルのhashを確認し、終了状態と出力も確認する。

```python
for i in range(32):  # 最初の2回を準備実行として除く
    order = states if i % 2 == 0 else list(reversed(states))
    for state in order:
        start = time.perf_counter_ns()
        result = subprocess.run(commands[state], env=env, capture_output=True)
        elapsed_ms = (time.perf_counter_ns() - start) / 1e6
        # 終了状態・stdout・stderrを照合し、commandと全時間をJSONへ保存
```

| 実行 | 外側の時間 | 終了状態 / 記録 |
|---|---:|---|
| `python3 target/q1/measure.py endpoints` | 10.191秒 | 0 / direct-endpoints.json |
| `python3 target/q1/measure.py stages` | 12.423秒 | 0 / stages-endpoints.json |
| Pythonのrun(..., probe="check")、両状態・指定3点・各30回 | 5.024秒 | 0 / check-stages-endpoints.json |
| Pythonのrun("bisect-final", ...) 、全9状態・指定3点・各30回 | 18.473秒 | 0 / bisect-final.json |
| Pythonのrun("fresh-versus-cache", ...) 、4状態・指定3点・各30回 | 9.188秒 | 0 / fresh-versus-cache.json |
| `python3 target/q1/table_scan.py`および同じ処理の5回の交互実行 | 最終40実行の合計0.997秒 | 0 / table-scan.json、table-scan-final.json |
| samply record --save-only --unstable-presymbolicate -- typeck-{before,after} <入口> 100 | 各約0.01秒で失敗 | 各1 / profile-*.json.log |
| sample <補助の子プロセスPID> 2 1 -file target/q1/sample-after.txt | 約0.01秒で失敗 | 255 / sample-status.json |

checkモードと二つの交互測定はPythonのhere documentからmeasure.runを呼び出した。再現する呼び出しは次の形である（各辞書のパスはmanifest、または下のビルドで保存した実行ファイルから取得した）。

```python
run("check-stages-endpoints", {s: b["probe"] for s, b in M["builds"].items()}, CASES[:3], 30, "check")
run("bisect-final", states_with_7_intermediate_commits, CASES[:3], 30)
run("fresh-versus-cache", cached_and_fresh_endpoints, CASES[:3], 30)
```

各取り込みの実行コマンドは`python3 target/q1/build_point.py <コミット>`である。内部では`git archive <完全ID>`を展開し、次を実行して実行ファイルを保存した後、measure.pyで指定3点を各30回測った。時間はログ読み取り等を含めないビルド呼び出しの外側の時間と、3点の測定時間を分けて示す。すべて終了0。

```sh
cargo build --release --locked -p benitoite --bin benitoite   --manifest-path "$PWD/target/q1/scratch/source/Cargo.toml"   --target-dir "$PWD/target/q1/scratch/build" -v
```

| コミット完全ID | ビルド秒 | 3点の測定秒 |
|---|---:|---:|
| `04f6fca90592247208c7e633b6e03725db294589` | 29.448 | 2.072 |
| `270a717c670d9640d4c08f10bc400afa6e3fcef2` | 29.014 | 3.491 |
| `367ef0268ed92d6ee8b0b751be32f6c02ddaf8ff` | 29.387 | 2.154 |
| `379d2f93cf92c267489b861c606620a59cacf461` | 78.111 | 2.042 |
| `498943fe6f1b87db71178354e65ba573e46cf492` | 27.438 | 2.071 |
| `bb5ade0eddafaedcc78d3af8d64f9bbf80d71603` | 29.135 | 3.227 |
| `c31e64b03d2810343e1779926bea4ebc958b6164` | 28.511 | 1.849 |
| `cd850d5313e31c37b4c47f8defca28ba2a3f95c7` | 28.501 | 1.972 |
| `ebd22a9361cc5b5bc1dba38382f944b4d522d45a` | 29.043 | 3.503 |

初回は依存クレートもビルドし、以後はQ1専用targetの依存だけを再利用した。生のコマンド・CLIのSHA-256・ビルド時間はbuild-*.json、コンパイラへの引数はbuild-*.logに残した。無効な最初のG3の0.109秒のビルドは上表から除外した。

公開APIの補助プログラムのコンパイルは、両版それぞれのrlibとdepsを指定して次の形で行い、いずれも終了0だった。

```sh
rustc --edition=2024 -O target/q1/typeck_probe.rs   --extern benitoite=<各状態>/release/libbenitoite.rlib   -L dependency=<各状態>/release/deps -o target/q1/typeck-<状態>
```

`git diff c31e64b0 270a717c -- tools/bench/compare/build.py tools/bench/compare/features.py Cargo.toml .cargo rust-toolchain.toml`、crates/benitoite/Cargo.toml・Cargo.lockの差分、関連する取り込みのfirst-parentの差分を読み、元のmanifestのhashと実行ファイル、入力、全archiveのsrcをPythonで照合した。照合の要点はaudit.jsonにも保存した。

## 計画との差・検査・申し送り

notes/Q1.mdとplanのQ1行は存在しなかったため、依頼に添付されたQ1の本文を用いた。プロファイラの取得失敗と、その代わりに行った公開APIからの観測を含め、decisions.mdのR220へ推す案として記した。処理系を変更していないため、作業末の検査は依頼どおり差分の空白の検査だけとした。追跡済みの変更に`git diff --check`を実行し、終了0（0.018秒）を確認した。新規のq1/results.mdは`git diff --no-index --check /dev/null <結果ファイル>`で確認し、差分ありを示す終了1、空白エラーの出力なしだった。最初の集約スクリプトは終了0だけを成功としたため、この終了1を誤って失敗と扱った。集約の判定とこの説明を直し、変更した結果ファイルの空白の検査だけを再実行した。追跡済みの変更の検査は繰り返していない。Rustの一時probeのコンパイルは調査の準備であり、処理系のRustの変更・テストの変更はない。

オーケストレータには、G2の実装表の索引作成を直すか、0.0.10では許容して後の課題へ回すかの判断を引き渡す。採用目標の閾値は変更せず、今回の小幅な差や未測定の修正案を目標達成として扱わない。修正を選ぶ場合は、その差分に対する検査と同じ指定3点・型クラスを使う点の測定を別作業へ割り当てる。元のshortの記録は変更していない。

調査専用のtarget/q1/scratch・binaries・typeck-before・typeck-afterを削除した。生のJSON・ログと調査用ソースはtarget/q1へ残した。削除の外側の時間は0.576秒、削除後の空きは45.47 GBである。各ビルドの完了時に記録した空きの最小値は44.24 GBであり、30 GBを下回っていない。測定の準備を始めたtarget/q1作成時刻は2026-10-21 01:08 JST、調査と記録は約20分で終え、2時間の目安以内だった。

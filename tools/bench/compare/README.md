# 版どうしの性能比較

`run.py` は任意のコミットを同じ入力で交互に測る。Python 3.9 以降の標準ライブラリ、git、Cargo、rustc を使う。他の言語との比較は親の `run.py` に残す。実時間には公開 CLI の起動・検査・実行・終了を含み、入力生成とビルドは含めない。本測定の前に所要時間を示し、benchmark スキルに従って静かな計算機の条件と設計者の了承を得る。

## 段の選び方

| 段 | 使う場面 | 見込み時間（ビルドは別） | 内容 |
|---|---|---|---|
| short | 通常の改造の末。性能に関わる改造では必須、それ以外は任意 | ビルドを使い回せる状態で15分以内 | 開始版と候補の2状態、全族の代表点、既定5標本。退行の疑いと判定不能を一覧にする |
| targets | 性能目標を約束した改造 | 目標ファイルによる | JSON が名指しする点と式の参照先、既定10標本。段別時間と RSS を別実行で取る。alloc は `--alloc` で追加する |
| full | バイナリを配る版のリリース前、性能の大きな改造の受け入れ | 数時間 | 全族・全点、既定10標本、段別時間と RSS/alloc の別実行。`--confirm-full` 必須 |

`--quick` は段とは別の試走指定であり、小さい入力・既定2標本で出力照合と道具の全経路を通す。性能の受け入れには使わない。targets の quick は目標の大きい点を測らないため、数値目標は判定不能になる。full の quick も確認指定を必要とする。標本数は `--samples N` で明示的に変えられるが、目標ファイルの `min_samples` を満たさない標本を達成とはしない。

short は出力照合を校正として、選んだ実入力の時間から準備・CLI/空 main の標本・別実行を見積もる。2倍の余裕と60秒を加え、15分を超えれば標本採取の前に停止し、族の代表点を減らすよう促す。見込みは実行時間の上限ではない。short は既定では段別補助・RSS/alloc を省く。既定の退行幅は `T_new - T_old > max(0.1*T_old, 0.002秒)` であり、合否でなく調査の合図である。差がばらつき以下のものは判定不能とする。機能が片側にしかない点も、機能不足と判定不能を残す。

## 実行例

リポジトリの根で実行する。状態は指定順に記録し、最後を候補として出力先の名前に使う。short では最初が基準、次が候補である。名前と数は固定しない（short だけ2状態）。

```sh
python3 tools/bench/compare/run.py --tier short --quick \
  --state before=<開始版> --state after=<候補> \
  --out target/bench/compare-trial
python3 tools/bench/compare/run.py --tier short \
  --state before=<開始版> --state after=<候補> --name my-change
```

`--section runtime` は既存の8本（fib/loop/list/tree/eval/string/println/lines）だけを run で比較する。関数数は `16.2`、制約と Fail の深さは `16.3`、縮小は `16.4`、構築器は `16.5` である。族の中の各系列も manifest の family として記録する。シナリオの節名は歴史上の番号を引き継ぐが、ランナーはその番号から測定点や機能を決めない。

```sh
python3 tools/bench/compare/run.py --tier targets --targets <改造>/bench-targets.json \
  --state old=<ID> --state map=<ID> --state solve=<ID> --state final=<候補> \
  --name syntax-batch3 --alloc --section 16.2
# 同じ引数に --resume を加えて、--section を 16.3 等へ変える
python3 tools/bench/compare/run.py --tier full --confirm-full \
  --state before=<ID> --state after=<ID> --name release-comparison
```

状態のリビジョンは呼び出し側で完全なコミット ID に固定する。目標のファイルの例は、0.0.9 の改造の `docs/archive/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/bench-targets.json` にある。

`--section` は繰り返せる。`--resume` は完了した節を飛ばし、未完了の節を最初から測る。途中の標本は合算しない。状態の順序、完全 ID、道具と入力のハッシュ、toolchain/環境、標本数と構成、バイナリのハッシュが違えば停止する。既存の記録は無指定では上書きしない。`--work` は生成入力、`--out` は記録の保存先を指定する。既定のプロセス上限時間は600秒（`--timeout`）。

## ビルドと機能の違い

各リビジョンを完全なコミット ID へ解決し、`git archive` から `target/bench/builds/<完全ID>-default/source/` へ展開する。release ビルドは同じディレクトリの `release/` に置き、alloc-stats は `<完全ID>-alloc-stats/` へ分ける。キャッシュの鍵はコミット・構成・rustc の詳細・Cargo の版・元の Cargo.lock の SHA-256。バイナリのハッシュも照合する。元の lock は書き換えず `--locked` で使い、状態間で自己パッケージ benitoite の版だけを除いて依存が一致することを要求する。既定構成から heap-verify/gc-stress/alloc-stats を外し、`BENITOITE_DEV_IO_MODE=direct` を使う。利用者の Cargo 設定も本測定前に確認する。

`--import-build <JSON>` は既存ビルドの明示的な取り込みである。commit/binary/sha256/features/rustc/cargo/cargo_lock_sha256/seconds の証拠を要求し、鍵とバイト列を照合してからキャッシュへコピーする。Q1 のように Cargo の版と lock ハッシュが別の manifest にある記録は、そちらの証拠からこの2欄を補って使う。

`features.py` の小さいプログラムを各状態で check し、実際の JSON 診断と終了状態から構築器・縮小の新 API を判定する。コミット ID や状態名では判定しない。縮小は旧 API の入力へ切り替え、構築器を持たない状態は対象から外して理由を残す。旧 API と新 API の縮小の比較は、予算と打ち切りを含む待ち時間の比較であり、同じ CPU 作業量の比較ではない。

## 標本と出力の照合

選んだ全節を、計時の前に照合する。準備1回の後、状態順を正順・逆順と交互にして N 標本を取る。各組で空 main を前後交互に測る。全標本、中央値、全幅の半分を保存する。差し引きの絶対値が両標本集合の半幅の和以下なら判定不能とし、その差から比を作らない。型エラーの系列は診断コードと終了値も検査する。深さ上限で拒否された成功入力は別に記録し、成功の時間へ入れない。

局所区間解析の check 費用を比べる入力は、既存の `16.2`（functions）と `16.3`（constraints）に含める。追加入力はすべて check 専用で、正常域内の算術だけを使う。HTTP はレコードを構築し、通信を呼ばない。

| 系列 | quick の追加点 | short の追加点・対照 | 出力の照合 |
|---|---|---|---|
| `functions-main` | 1/8/32 関数 | 64/256 関数。既存の0関数を対照に使う | 終了0・標準出力なし・診断なし |
| `interval-bind` / `interval-add` / `interval-flow` | 1/8/32 単位 | 64/256 単位。`control-16.3` を対照に使う | 同上 |
| `interval-width-<型名>`（算術を持つ整数七種） | 各幅1/8/32 群 | 各幅64/256 群。`control-16.3` を対照に使う | 同上 |
| `interval-range` / `interval-http` | 0/1/8/32 単位 | 0/64/256 単位。0は同じ import だけを持つ空 main | 同上 |

`n` は関数宣言数、別名束縛数、加算数、比較と合流を伴う束縛数、幅ごとの算術式群数、成功する Range の match 数、Response/ClientRequest の組数を表す。AST の節点数や解析の操作数ではない。`Case.params` の `input_unit` と `source_bytes` に反復単位と生成した UTF-8 バイト数を残す。constraints の追加系列は `control_case` で対照を指定する。標準ソースの固定費は Range/HTTP の0単位と、import のない空 main を別々に読んで確認する。既存系列の点と拒否入力は保つ。

全族の short は既存の15分の事前見積もりで止める。最初の quick/short で実入力から校正し、上限を超える場合は採取前に代表点を減らした理由を記録する。check 全体の CLI 時間と、既存 probe の `load_parse` / `resolve` / `typeck` は別の観測として扱う。short は従来どおり段別の補助実行を省くため、段別時間は未取得である。解析の操作回数・補助記憶の消費もこの入力生成器では取得せず、0として表示しない。

縮小は候補順、反例、message、shrinks/shrinkWork、予算0/1の境界、Unicode スカラー値、Map の鍵順、record の欄順を照合する。Q1 の93個の quick 入力と同じ生成を保つ。構築器は String/List/Bytes の append/appendAll/copy と既存関数の比較を含み、速さを合否にはしない。実行時族の期待出力は Python で独立に計算する。

段別時間は公開 API だけを使う `timing_probe.rs` の別バイナリで取る。公開 API の変化でコンパイルできない場合は未取得を記録し、CLI の比較を続ける。load_parse は公開 loader の区間、resolve/typeck はその後の区間、reparse は同じバイト列を再解析する別の区間であり、load_parse と加減しない。RSS は親の `rss.py`、alloc は別構成の別実行で取得する。Fail 正規化の内部訪問節数と縮小内部の生成/比較回数は未取得。CPU プロファイルは出力の `profile.sh` で別に取得し、取得していない原因分析を実測とは扱わない。

`build.py` は各状態の archive の `parse` 宣言を調べ、保留診断の引数を持つ版だけに
`--cfg benitoite_parser_pending` を渡す。同じ archive の `types/mod.rs` の `Ty::Con` 宣言を調べ、
範囲の添字 `RangeIndex` を持つ版だけに `--cfg benitoite_range_index` を渡す。
probe の型の構築は、この指定で旧版の2引数と新版の3引数を切り替える。
同じ archive の `ir/core_ir.rs` の `Program` 宣言も調べ、`range_signatures` の欄を持つ版だけに
`--cfg benitoite_range_signatures` を渡す。probe の `Program` の構築では、この指定がある場合だけ
同欄を空で初期化する。
呼び出し側の作業ツリーの API で版を判定しない。
判定と宣言元のハッシュは `builds` の `probe_api` に残し、probe のキャッシュの鍵にも含める。
最終的な利用可否はその版に対するコンパイルの結果で決め、`capabilities` の
`timing_probe` に結果と失敗理由を記録する。

`bridge`・`irenv` など `command=probe` の点は、`timing_probe` を持つ状態だけを測る。
持たない状態は `manifest.json` の `skipped` に理由を残す。両側で使えなくても節の記録を
空の測定として保存し、残りの CLI の比較を続ける。片側の欠測をゼロや成功へ置き換えず、
その値を必要とする目標は判定不能とする。CLI の点は段別時間を取れなくても測る。
既定の probe が使えて alloc-stats の probe だけが使えない場合は、CLI と通常の probe の
測定を続け、確保量の未取得を `skipped` の `scope=alloc` に記録する。

## 見込みと記録

```sh
python3 tools/bench/compare/run.py --tier targets --targets <改造>/bench-targets.json \
  --state old=<ID> --state map=<ID> --state solve=<ID> --state final=<ID> \
  --estimate-from target/bench/compare-trial
python3 tools/bench/compare/run.py --tier full --confirm-full \
  --state before=<ID> --state after=<ID> --estimate-from <同じ状態のquick記録>
```

`--estimate-from` は見込みの表示だけを行い、ビルドも測定もしない。同じ系列の最大 quick 入力から、入力の大きさ・反復数・標本数へ比例させる。runtime の quick は short の代表サイズを使い、fib は黄金比の深さ差の累乗、tree は生成する節数の比で仕事量を補正する。全体・節・族ごとに、照合、準備、CLI、空 main、段別補助、RSS、alloc を分ける。ビルドを使い回せる場合と初回ビルドの費用も分ける。Cargo は比較を起動したリポジトリの根で走らせ、archive 内の rust-toolchain.toml による切り替えを避ける。alloc を試走していない場合は未校正と明示する。二乗や指数の伸び、予算に依存する仕事量の上限を予測するものではなく、未測定の族は missing_cases に出す。

既定の記録先は `tools/bench/results/<実測日>-<候補短ID>-<名前>/`。quick は既定で `target/bench/compare/quick-results/` へ置く。大きい入力とビルドは追跡しない。

| ファイル | 内容 |
|---|---|
| manifest.json | 完全 ID、lock とバイナリのハッシュ、環境、機能の探り、除外理由、生成器と各入力のハッシュ、構成 |
| verification-*.json | 計時前の全出力・診断・終了状態 |
| section-*.json | CLI/空 main/段別の全標本、別実行、実行コマンドと照合出力 |
| partial-*.json | 中断時の参考。完了の証拠にはしない |
| result-manifest.json / alerts.json | 目標の判定と、short の退行の疑い・判定不能の一覧 |
| results.md / results.html | 条件・未取得・中央値とばらつき、共通のゼロから描く線形目盛の SVG |
| estimate.json / short-estimate.json | quick からの見込み／short の実入力での事前見込み |
| invocation.json / profile.sh | 外側の時間と呼び出し／独立したプロファイル取得の補助 |

## シナリオの族の追加

1. `scenarios/` にモジュールを置き、`cases(quick, repeats, fixtures)` で `model.Case` の列を返す。ID は全族で一意とする。格子と生成器を同じモジュールに置き、乱数を使う場合は seed を固定する。check/run/test、arguments、期待終了値と stdout または診断コードを宣言する。
2. `short_point(case)` で代表点を選ぶ。通常の点と quick の点を宣言し、全点の生成は full とする。`scenarios/__init__.py` の FAMILIES へ登録すると、short にも入る。短い代表点を増やしたら15分の見込みを確認する。
3. 必要な機能を `requires` に列挙し、`features.py` に小さい探りのプログラムを加える。代替入力を持つ場合は legacy/modern のソースと `variant_feature` を宣言する。独自の照合が必要なら VALIDATORS へ登録する。
4. 同じ入力の生成が決定的であること、誤った出力で止まることを自己検査し、2状態の quick と short で確認する。

既存スクリプトの run は `runtime.py` を例にする。全状態で同じ入力を使い、期待出力を独立に求める。基準のスクリプトを旧コミットから取り出す必要がある場合は `fixtures` の archive を使う。

## 目標ファイルの書き方

改造ディレクトリに JSON を置く。状態名と閾値はランナーへ埋め込まない。`cases` は観察したい入力の ID、`targets` 内の median の参照先も自動で測定対象となる。`sections` は実行する節の既定値、`states` は必要な状態名の集合であり、省略できる。`min_samples` は数値判定に必要な標本数である。

```json
{
  "schema_version": 1,
  "min_samples": 10,
  "cases": ["functions-main-0-0"],
  "targets": [
    {
      "label": "検査時間の比", "kind": "ratio", "limit": 0.75,
      "expression": {"op": "ratio",
        "left": {"op": "median", "case": "functions-main-10000-0", "state": "new"},
        "right": {"op": "median", "case": "functions-main-10000-0", "state": "old"}}
    },
    {
      "label": "縮小の予算", "kind": "invariant", "select": {"section": "16.4"},
      "field": "shrinks", "parameter": "ms", "minimum": 0
    }
  ]
}
```

式は数値の定数、`median`、`difference`、`ratio` を再帰的に組み合わせる。median の `metric` は既定 cli、段別なら typeck 等を指定する。kind は ratio/difference/growth（式と上限 limit）、regression（old/new の式、relative、absolute_seconds）、invariant（出力の field とパラメータ parameter、または定数 limit）を持つ。伸びは同じ状態の異なるパラメータ点を ratio で指定し、基準差し引きは difference で指定する。invariant の select は section/family 等、states は適用する状態名である。必要な出力がなければ判定不能となる。invariant だけを指定する場合も、対象点を cases に列挙する。

## 自己検査

```sh
PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'
```

構文検査は `scripts/check.sh` の python_syntax が compare と scenarios の Python を含む。

M1 で追加した族は `patterns`（16.6）、`codegen`（16.7）、`bridge`（16.8）、
`external-tests`（16.9）である。short は各族の宣言した代表点を含む。
`Case.state_expectations` は状態ごとの期待拒否を保持し、期待拒否の CLI 時間を
成功した点の時間へ混ぜない。`state_requires` による対象外も manifest に記録する。

新しい builders の `-r64-` / `-r128-` は同じソースへ異なる実行引数を渡す。
構築器の生成から最後の copy までは通常の補助関数の中で行う。入力内容は位置ごとに
変え、途中の snapshot を追記完了まで保持し、最後に Python が独立に作った全文と照合する。
`single-all` と `prepared` の入力は反復の前に一度作る。VM 時間の Q は R/2R の差なので、
その共通準備の費用を含まない。copy-only は一括追加後の snapshot を並べる点であり、補助関数内の new と一括追加も含む費用として報告する。`prepared` の List は完成済み入力を返す観察点である。

probe の `stages` は脱糖・コア IR 検査・下位化・コード生成をそれぞれの公開関数で測り、
`vm_run` はコンパイル済みプログラムを `run_program` に渡してから戻るまでを測る。
読み込み、検査、VM の出力捕捉、段の関係は section JSON のコマンドと出力に残す。
`hole_lets` は利用者の全定義のコア IR を構造で走査し、固定式と callee の Let も数える。
`irenv` は空／500／1000 個の Let を持つ独立のコア IR を作り、公開 `check_program`
だけを計時する。兄弟の枝から局所変数を読む不正 IR の拒否は計時後に確認する。

`bridge` は各コミットの archive にある変換関数と値の定義をその版の公開ヒープへ接続する。
公開範囲は変えず、旧版の自由関数と新版の session メソッドへの呼び出しだけを合わせる。
元のソース、変換単位、観測用 wrapper の hash は build 記録へ残す。
入力グラフの準備、ヒープ対象の数え上げ、小さい結果の確認は二つの計時区間から除く。
実在する節と辺（対象間の参照）の独立な期待値は `graph.json` と Case.params に保存する。
ヒープ上の対象数は物理的な表現から数え、after の独立期待値と照合する。

外部 test の時間は `--wasm-stats` なしで測る。同じ入力を別に起動した統計から
通常／補助の実行用コンパイル数を読む。静的な宣言のコンパイル数は加えない。
after は経路別の実行用キー数とコンパイル数の一致を両方向に確認する。旧版に欄がなければ
欠測のまま保存する。test の全件成功と stateful Store の隔離も独立に検査する。

時間・確保量・RSS は別プロセスで取得する。確保量も目標に必要な標本数だけ別実行する。
時間差の比率は、差が非正、2 ms 未満、両標本集合の IQR（inclusive 法）の和以下なら
判定不能とする。確保量と整数計数には 2 ms を適用しない。符号付き difference 単体は
既存の契約を保ち、負の差を改善量として表現できる。欠測・非有限値・標本数不足は合格にしない。

`test_compare.py` は共通 build を通して開始版と現在の HEAD の probe をコンパイルし、
short の quick に含まれる独立 IR・グラフの全点を、対象状態ごとに一度実行して検査する。
通常の short の代表点 `bridge-shared-8` も同じ検査に含める。
これにより、保留診断の引数を持たない旧 API と現在の API の両方の呼び出しを確かめる。
縮小器の段別出力も各版で利用可能な API の専用 validator で検査し、誤出力を拒否する。
外部コンパイラの失敗を与える自己検査では、片側・両側の probe が使えない場合も CLI の
標本と全節の記録が残り、欠測の目標が判定不能になることを確かめる。alloc-stats の
probe だけが使えない場合も同じ検査に含める。
標本採取と性能の合否判定は行わない。ビルド済みの archive/cache がなければ数分を要する。
正式な after の完全 ID は版と同梱物をそろえた後に固定し直す。

# Range の区間比較入力

`interval::export_interval_range` は、実ソースの型検査・脱糖と既存の corpus 14 / sidecar 6 の交換を通す。Range の境界・逆転優先・範囲外・入れ子・別個体・算術・偽の同定、既存の batch3 の Range、固定表の8形を別の11入力として書き出す。独立期待値は `range-expectations.json` に保存する。最小値はソースの直接負号で書き、名前付き引数は value・maximum・minimum の順とする。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-range-inputs cargo test -p benitoite --test desugar_export interval::export_interval_range -- --exact --nocapture
python3 crates/benitoite/tests/desugar_export/interval/prepare-range.py target/interval-range-inputs
```

同じ出力先へ複数の書き出しを並行させない。書き出しは `corpus.json`・`builtins.json`・`stdlib-decls.json` と元ソース、`range-bindings.json` を保存する。後者は解決済みの標準宣言のIDから `dataDecls` の所有元と構成子宣言を照合し、RangeNames の八つの同定を得る。CheckedInteger の構成子名を型名から組み立てない。表示名を置換しても同じ同定になることと、実際の call・引数の型が現行の StandardRule の型に一致することを同じ書き出しで確認する。

`prepare-range.py` は元の Surface の根を番号0とし、フィールド順・リスト順の先行順を `surface_keys.py` で保存する。型・パターン・相互帰納の容器に番号を付けない。L21 の固定番号は `l21TraceRaw`・`l21TraceProjection` に残し、実ソースの番号を `definitions` の `expectedTrace` に別に保存する。射影後の加算では、先行順の加算位置より先に射影が評価される。`range-inputs.json` は X01 が作る最終の interval-corpus に接続するための入力一覧であり、未実装の読者に受理された成果とは扱わない。

X02 は成功枝の区間と候補、X03b は VM と小モデルの値・三欄・Error の構成子と保存引数・失敗・到達を比較する。`OnlyOk` の Error の腕は明示的な return で抜け、番兵値を正常な継続の区間へ合流させない。成功側の独立期待区間は `intervalObservation` が示す match 式の normal 成分である。関数全体の returned 成分には Error の早期 return も含まれるので、その全体を成功側だけの区間と比較しない。`Fields` は公開の minimum・maximum・value の観察用であり、minimum/maximum を Lean の標準規則へ加えない。`unrelated` は引数で受けた別個体を射影し、閉じた呼び出し元 `unrelatedCaller` を別に置く。関数本体の解析へ呼び出し元の由来を渡さない。偽の同定は未知の入力とし、閉じた実行の一致件数に入れない。

この書き出しは入力の保存を受け持つ。閉じた評価と実 VM の比較には、末尾の `--vm-dir` を使う。

## 独立交換の識別と読者の検査

`desugar_export::export_interval_identity` は、本物の読み込み・名前解決・型検査・脱糖を使い、通常解析の出現と Surface の元 NodeId・span・先行順を照合する。合成した本体の根、定数の複数回の展開、else-if、リスト展開の concatenate、文字列補間の変換関数、入れ子の with、別本体を同じ入口で扱う。根は `syntheticBodyRoot` として元位置を持たず、対象演算は元位置を必須とする。六比較を含む七種の整数の全対象演算と四種の負号、Range の二つの標準宣言、シフト27宣言を `sourceKeys` に含める。シフトは宣言順と逆順の名前付き引数をそれぞれ通す。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-identity-inputs cargo test -p benitoite --test desugar_export export_interval_identity -- --exact --nocapture
python3 -B formal/tests/test_interval_exchange.py --source-dir target/interval-identity-inputs --output target/interval-identity-check
```

Lean の実行ファイル `formal/.lake/build/bin/intervalDiff` は先にビルドしておく。Python は Lean のビルドを起動しない。`--source-dir` を省いた場合も、従来の五 profile の独立期待値と負例の検査を行う。

書き出しは元ソース、`correspondence.json`、`reader-corpus.json`、`point.json` を保存する。標準表は読み込み済みの解決済み宣言と署名、Range の構成子宣言から作る。組み込みの関数と操作の頭は `primName`、包みを含む利用者の関数は `funName`、利用者の操作は `opName` を保つ。操作を固定域へ登録しない。本文中の標準 call と表の実名が一致するときだけ `apiAt` を作り、型引数・エフェクト引数のある頭を認定しない。

`reader-corpus.json` は識別と読者の契約を検査するため、全体の操作上限0による未着手を期待する。読者は実行前に全型表・全対象キー・標準表・本文の深い位置を検査し、正しい入力では `matched=true`、比較本体数0、全 Top による `accepted=false` を返す。Python はこの終了1を明示的に検査し、解析の一致件数へ加えない。未知欄・未知構成子、重複欄、型や対象演算の対応の欠落、非正準の番号は、同じ正しい入力を一箇所ずつ変えて終了2になることを確かめる。通常予算の `point.json` は独立した手計算の区間・消費・識別対応と照合し、終了0を要求する。

全関係定義の通常予算での比較は、以下の `--rust-dir` から実行する。算術・フロー・Range の実 VM の比較は末尾の `--vm-dir` から実行する。シフトも末尾の `--vm-dir` から実行する。全比較への接続は別に扱う。

## 全関係定義の manifest

`export_interval_identity` は、上記の出力に全関係定義の manifest と通常解析の観測を加える。`export_interval_manifest` は、空入力・空モジュール・複数モジュール・宣言順と異なる定数の依存順・型検査失敗・他の型の Top・既定の本体予算と全体予算の停止、全件入口と同じ生成器の一入力を検査する。新しい予算入力の二件は `interval-budget` の群として区間の交換だけへ渡す。既存六入口の交換へは追加しない。テストスレッドのスタックは変更しない。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-manifest-inputs cargo test -p benitoite --test desugar_export export_interval_manifest -- --exact --nocapture
python3 -B crates/benitoite/tests/desugar_export/interval/check-manifest.py --source-dir target/interval-manifest-inputs/manifest-interval --independent-dir target/interval-identity-check --legacy-corpus target/interval-manifest-inputs/manifest-corpus.json --supplemental-group interval-budget --output target/interval-manifest-check
```

`--independent-dir` は、先に `test_interval_exchange.py --output` で作った独立期待値の入力と報告を指す。`check-manifest.py` は、五 profile と容器の fuel の固定例の全定義をそれぞれの Lean の報告と照合し、実ソースとは別に件数を記録する。実ソースでは、元 AST の全定義、Surface の完全な先行順から得る別本体の一覧、通常解析の観測、Lean の全列挙を照合する。未解析の本体には入口・発見・待ち行列の停止または残る元定義等の根拠を要求する。全 Top だけの集合を受け入れない。

| ファイル | 内容 |
|---|---|
| `interval-manifest.json` | 型検査の成功・失敗、元 AST のモジュール・宣言位置・メソッド位置、元定義と全別本体の順、全対応、解析済み・未解析・Top・Bottom・未対応・本体予算超過・全体予算での未着手・番号未取得・深さ停止の別々の件数。型検査失敗は定義0件の成功にしない |
| `interval-summary.json` | 深い本文を含めずに読むための、元定義と件数の要約 |
| `interval-material.json` | 通常解析と同じモジュール順・元定義順、fuel、予算、全型表・定数・標準表・apiAt・本文。解析結果の照合に使う材料であり、期待値のない本ファイルを有効な interval-corpus として渡さない |
| `interval-observations.json` | 通常解析の値、親と独立入力の候補、解析終了直後の `contextBudget`、発見後の `usage`、まとめた後の利用者の診断。`kind: whole` と空の `definition` を持つ末尾の一行は検査全体の記録であり、本体に数えない。`legacyWarnings` は新解析より前の W0401・W0402・W0404 の診断と、採用済みの NodeId・原因・一次位置の組である |
| `interval-manifest-corpus.json` | Lean の全列挙との照合に使う正規の独立交換。全体操作上限0による全元定義・全別本体の未着手を独立に期待する。終了1・matched=true・accepted=false・比較0件を要求し、通常解析の一致へ加えない |

型検査の成功数は検査の入力数、`inputDefinitions` は元定義数、`allBodies` は元定義と数学的に列挙した別本体の和である。Top と Bottom は、Lean の `Exchange.reportedBodyType` と `informative` に合わせ、根の型の正常成分で分類する。ほかの型の Integer64 成分が Bottom であることを非 Top の根拠にしない。停止した解析は未知の Top、未解析は値未取得として分ける。`unsupportedBodies`・`bodyBudgetExceeded`・`wholeBudgetSkipped`・`unidentifiedBodies` は処理系の専用の射影から読み、段停止や独立入力を重ねて足さない。これらの分類は互いに排他的な分割ではない。

対象モジュールは通常解析と同じく Prelude・Stdlib を除くソースのモジュールであり、空モジュールも保つ。定数・本体のある関数・impl の各メソッドを元の順で含める。型・trait の署名・外部宣言・生成されたアクセサや上位辞書の単位を元定義へ加えない。検査が生成した関数は AST の Item::Fn として同じ扱いになる。外部型だけを理由に書き出せない元定義は `excluded`、理由 `externalType` と元定義・別本体の名前と件数を残す。比較器は全本体の親候補・独立入力の候補が空で、整数区間が Top または Bottom だけであり、発見と観測が揃うことを要求する。他の交換不能は `enumerationComplete: false` を残し、完全な比較の成功にしない。

共有の `CorpusStream` は、既存の golden と無作為1000入力の全件入口にもこの独立した書き出しを接続する。既存六入口の本文・sidecar・入力の選択は変えない。全件の書き出しと六入口の実行は K1/K2 の担当であり、局所検査では ignored の全件を起動しない。

## 通常予算での解析結果の比較

`formal/tests/test_interval_exchange.py --rust-dir DIR` は、上の材料・manifest・観測を読み、実ソースの型検査一入力ずつを Lean の `intervalDiff analyze` へ逐次渡す。指定は繰り返せる。Range の11入力は `export_interval_range` が出力する `interval/` からも渡せる。

```sh
python3 -B formal/tests/test_interval_exchange.py --source-dir target/interval-identity-inputs --rust-dir target/interval-identity-inputs --rust-dir target/interval-manifest-inputs/manifest-interval --rust-dir target/interval-range-inputs/interval --output target/interval-analysis-check
```

各入力は通常 checker と同じ fuel 4096、本体10万・全体100万の操作数と保持項目数で比較する。親・独立入力・別本体の正常値、候補のキー・原因・演算・保存順、解析直後の状態と次番号・取得済みの対応、検査全体の消費・最大同時保持・停止理由・段・進捗・未着手を照合する。mayFail は判定に使わない。段停止の位置も照合し、未検査の停止形を推測で受け入れない。

利用者向け警告は、Lean の候補を元位置へ戻し、旧定数警告を先に採用して NodeId・原因・一次位置でまとめたコード・一次位置・順序を照合する。旧定数警告は未到達にも出るため、新解析の候補から作り直さず、解析前の独立した記録を使う。旧定数警告そのものの正しさと、診断の文言・注記・補助位置は既存 checker のテストで検査する。

手計算の独立期待値の五 profile は従来どおり別に比較し、実ソースの観測から更新しない。実ソースの正常予算の入力と報告は `real-source-N/`、件数・候補数・段停止と未発見の範囲は `real-source-summary.json` に保存する。空・全 Top の個々の入力は終了1と受け入れ理由を保ち、集合全体には非 Top を要求する。本体と段の深さ停止は別に記録し、成功として除外しない。非整数の可能性がある match の腕の親候補を出さない固定入力と、値・消費・番号・候補・統合後の診断・停止位置を一箇所ずつ壊す負例も含む。

## 算術・フロー・Range・シフトの実 VM との比較

`interval::vm::export_interval_vm` は `vm-arithmetic.bnt` を読み、元のソースと標識を加えたソースをそれぞれ通常の型検査・脱糖・交換へ通す。

```sh
BENITOITE_DESUGAR_DIFF_DIR=target/interval-vm-inputs cargo test -p benitoite --test desugar_export interval::vm::export_interval_vm -- --exact --nocapture
python3 -B formal/tests/test_interval_exchange.py --vm-dir target/interval-vm-inputs --cli target/debug/benitoite --output target/interval-vm-check
```

先に `intervalDiff` と実 CLI をビルドしておく。Python はビルドを起動しない。`--vm-dir` は一つの書き出し先を受け、既存の五 profile の独立期待値の検査も維持する。全関係定義の解析比較を同じ起動で行うには、既存の `--rust-dir` も指定する。

元のソースは39関数・80対象演算で、七種の整数の加減乗算・整数除算・剰余、符号付きの負号、六比較、短絡の実行・未実行、if、shadow、match・真偽値の guard、早期 return を含む。`interval_vm_compare.py` の手計算の表が、元位置から選んだ演算について値・失敗・引数・到達順を固定する。各演算の子を左から局所束縛へ取り出し、両方の正常値を得た直後に `REACH:<元の定義名>:<元番号>` を出す。標識追加後の番号は文字列の元番号から推測せず、別の交換の対応表で得る。元の Surface と、追加した束縛だけを代入して標識を除いた Surface の構造も照合する。

`original/` と `instrumented/` は、それぞれ通常予算の材料・観測・manifest を保存する。評価専用の入力では、根と根の型対応だけを、宣言の戻り型から本体を検査した Unit へ戻す。末尾の return の型が Unit であることを元の型対応から確認し、本文・子の型・元キーと、解析比較用の材料は保つ。返された具体値は宣言の戻り型を用いた独立期待値と比較する。

Python は関数ごとの main を追加し、実 CLI の標識列・文字列補間による最終値・終了状態・実行時診断の種類と位置を読む。`vm/vm-summary.json` は、元キー・標識追加後のキー・二つの位置、比較件数、実行ごとの到達列、負例を保存する。標準出力の失敗 R0201 と標識位置の失敗は対象算術の失敗に数えない。実際に読み手を閉じた pipe へ出力する検査を、正の比較件数と分けて記録する。標識・最終値・失敗位置を壊す負例も、正しい実 VM の観測から作る。

未知を含む入力、評価不能、unknown の失敗はこの実行比較へ入れない。既存の独立期待値・所属の検査と、その理由付きの評価除外を維持する。guard に Console.Write を追加することは通常の検査が拒否するため、ここでの guard は対象演算を含まない。既存六入口への全比較の接続は、この比較の一致から結論しない。

Range は既存の `range.bnt` と `vm-range.bnt` を合わせ、import の別名 `R` を通した元ソースと標識付きソースを `range/` に書き出す。元ソース46関数のうち、未知を含まない37関数を閉じた評価と実 CLI で比較する。既存の9組の境界の raw Result と value、成功側だけの腕、入れ子、一度保存した Result、射影後の正常な加算とあふれを含む。名前付き引数は value・maximum・minimum のソース順に評価し、trace は契約順に照合する。追加した引数順・第一/第二引数の失敗・引数の return の例で、後続と親への未到達も照合する。

`formal/tests/interval_range_vm.py` は既存の `range-expectations.json` と手計算の順序を使う。成功した raw Result の main は公開の minimum・maximum・value を順に呼び、三欄を十進文字列で出す。Error は構成子と全引数を出す。minimum/maximum の呼び出しは VM 側の観察専用であり、Lean の具体規則を増やさない。引数付き・一般の call・観察専用の9本体は `selectedOut` に理由を残し、閉じた評価の一致へ数えない。`unrelatedCaller` の VM の105だけは独立期待値と別に照合する。偽の同定は既存の解析比較で扱い、実行比較へ入れない。

Range の元・標識付きソースの通常解析も同じ起動で比べる場合は、上のコマンドへ次を追加する。

```sh
--rust-dir target/interval-vm-inputs/original --rust-dir target/interval-vm-inputs/instrumented --rust-dir target/interval-vm-inputs/range/original --rust-dir target/interval-vm-inputs/range/instrumented
```

`vm/range/range-vm-summary.json` は、選んだ演算の数、実際の到達、元キー・標識追加後のキーと位置、実行比較前に分けた本体、独立の VM 観察、負例を保存する。三欄・Error の構成子・逆転優先を壊した観測と、出現の同定がない Range の call を比較器が拒否することも確認する。標識出力の失敗は算術と同じ規則で一致から除く。

シフトは `vm.rs` の生成器が27宣言×4行の元ソースと標識付きソースを `shifts/` へ書き出す。`formal/tests/interval_shift_vm.py` は、別に定めた宣言・幅・ビット列の独立期待値を使う。整数23宣言の域外 -1・w の46行だけを `evalClosed` と実 CLI で厳密に比較する。整数の域内0・w−1の46行は unknownFailure、Byte・UnsignedInteger8 の全16行は notClosedOrFuel として評価比較から除き、実 VM の値または R0701 を独立期待値へ照合する。Byte の域外8行も厳密な比較の件数へ足さない。左シフトのビットの切り捨てをあふれと数えない。

包みの7宣言は、R0701 の文言が内側の組み込みの名前を示し、一次位置が呼び出し元の call を指すことをファイルとオフセットで照合する。`vm/shifts/shift-vm-summary.json` は厳密比較46行・独立照合だけの62行、評価除外の二理由、包みの位置、全108実行と元キーの対応を分けて保存する。値・到達・診断コード・ファイル・位置を壊した観測と、出現の同定を欠いた call を比較器が拒否することも確かめる。操作と HTTP の欄は比較しない。Range・固定域の評価規則と実本体の一致は A1 の信頼の範囲であり、この有限の実行比較は全入力の意味保存の証明ではない。

シフトの元・標識付きソースの通常解析も同時に比較するには、上の指定へ次を追加する。

```sh
--rust-dir target/interval-vm-inputs/shifts/original --rust-dir target/interval-vm-inputs/shifts/instrumented
```

全件と独立プログラムを連結する `programs/interval-*.json` は、`interval-source-index` 版1の索引である。`sources` の相対パスで元の二ファイルを参照し、`scripts/check/interval_artifacts.py` がヘッダの一致を確認して元の順に読む。実ソース比較で作る入力は、実行後に `.json.gz` として全文を保存する。Lean の報告は `.report.json` のまま残す。

外部型を除外した入力でも、残る全定義を元の消費・保存・最大保持を引き継ぐ初期状態で比較する。比較報告の `budgetLedger` は元定義順の入口と出口を持ち、各観測の `usage` と検査全体の `after` を照合する。除外した元定義・別本体は `excludedDefinitions`・`excludedBodies` に数え、通常解析済みの総数から区別する。

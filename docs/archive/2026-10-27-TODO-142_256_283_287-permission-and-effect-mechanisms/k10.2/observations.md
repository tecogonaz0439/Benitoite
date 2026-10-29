# 観測・互換層と既知の差の照合

2026-10-29。B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。本記録の担当は、観測の既存の持ち主の境界を読み、必要な三つの局所検査を実行した。処理系・テスト・Lean のソースは変更していない。新しいテストを重ねず、既存の実ファイルとループバックの試験を用いた。

## 観測の意味と期待値

観測の単位は、プログラムの IO が作用する path または接続する endpoint である。DNS の問い合わせと、TLS の証明書の取得・失効の問い合わせなど OS が行う副次的な通信は、この単位に含めない。README の2026-10-29の設計者の決定を保つ。

[手書きの期待値](observations-expected.json)と [SHA-256](observations-expected.json.sha256)を、三つの局所検査を実行する前に固定した。SHA-256 は `7155330a43deddcf7abaa264a5d5db30e2408a7ad9c25f235b94733e48c4122e` である。生成元は Rust と Lean の出力ではなく、保持値の契約と制御した外部対象である。実ファイルのディレクトリと HTTP のポートは OS が割り当てるため、JSON の `encodingTemplate` は変数を含む対応の表であり、実測された観測の報告とはしない。

`formal/Benitoite/Exchange/Observe.lean` の `encodeObservation` は対象を配列で書き、path はラベルの配列、endpoint は host と port の組として書く。IP は `family` と自然数 `bits` で書く。`decodeObservation` は読み戻して同じ形にならない対象を拒否する。`observationAllowed` は、観測の各対象が、同じエフェクト名の閉じた原子の範囲に属するかを確かめる。対象を持たないエフェクトは空の観測だけを許し、範囲変数の原子は対象を許さない。

B-Lean の [ログ](b-lean.log)は573ジョブ成功、time の real/user/sys は0.39/0.10/0.13秒である。`formal/Benitoite.lean` は `Exchange.ObserveExamples` を既定のライブラリへ import している。その `#guard` は、path・host・endpoint の encode/decode の往復、余分な欄の拒否、`File.Write[/data/**]` が `/data/a.txt` を許し `/etc/passwd` を拒否すること、`Http.Connect[api.example.com,443]` が同じ endpoint を許し IPv4 の別 endpoint を拒否することを確かめる。Top・異なる種類・対象なし・範囲変数の境界も含む。今回 Lean の単一ファイルの評価や `lake build` は実行していない。B-Lean の全引用条件と Lean 入力の一致は親の results で集約する。

現存する六つの交換の CLI 入口には、観測を実行して報告するモードがない。Rust の実行器も形式化の観測の JSON を報告しない。そのため、ここでの照合は B-Lean で検査した encode/decode・許否の独立例と、以下の実ファイル・実通信の対象を同じ意味に対応付けたものである。新しい CLI 経由で `observationAllowed` を評価した、または VM から形式化の観測を抽出した、とは記録しない。

## 六つの File と sendIn の実対象

| 対象 | 既存の公開境界の検査と独立した確認 |
|---|---|
| 六 File | `runtime_builtins::file_in_operations_use_the_retained_path_and_preserve_values_and_errors` は `readTextIn`・`readBytesIn`・`writeTextIn`・`appendTextIn`・`writeBytesIn`・`appendBytesIn` の全てを、同じ `Scope.PathIn` が保持した path へ実行する。検査済みの木の範囲を持つ `operate` を通し、書き換え・追記・読み取りのバイト列を独立した固定値で確認する。最後の内容は `[255,0,65,66,10]` であり、別の `decoy` の `untouched` は変わらない。存在しない親の path は六入口とも NotFound となり、別 path へ作用しない |
| File の対象の保持 | 同じ試験の handler が捕捉した値を、確保を挟んで `Scope.pathInValue` へ渡し、保持 path が元の文字列と同じであることを確認する。Direct/Request の二つの VM の方式と参照実行器で実ファイルの内容を照合する。観測の path はこの保持 path 一つに対応する |
| sendIn | `l32_http_client::send_in_returns_redirects_without_connecting_to_location` はループバックの実通信を行い、要求を保持した後に射影した別のレコードを DELETE・別 URL・空の本体へ更新しても、送信は元の POST・URL/query・二つの同名 header・`posted猫` の本体を使うことを確認する。timeout も元の要求に置く。301/302/303/307/308、Location のない302/304の7条件を Direct/Request で実行する。各条件で受信は1件、redirect または更新先の別 endpoint への接続は0件である。観測の endpoint は保持した要求の実効 endpoint 一つに対応する |
| 実効 endpoint と Host | `l32_http_client::send_in_matches_effective_endpoint_and_explicit_host` は名前の大小、IPv6 の表記、先頭0付きportなど字面の異なる同じ対象を送信できることと、別 Host/port・不正 Host で通信前に失敗することを確認する。失敗の場合、元と別対象の二つの listener とも未接続である |

上の検査の入力とアサートは既存の Rust のテストに手で書かれている。期待値JSONの finalActualBytes・decoyBytes・HTTP の欄と、試験の独立した期待値が同じであることも読解で照合した。テスト用の差し込み口や本番の観測機構は追加していない。型の範囲を、symlink・特殊ファイル・実体の隔離として扱わない。

| 局所検査 | 終了 | 件数 | 外側秒 | time real/user/sys秒 | 補助最大常駐量 |
|---|---:|---|---:|---|---|
| [六 File](observation-file.log)・[計時](observation-file.json) | 0 | 1成功・失敗0・無視0・除外28 | 2.480003 | 2.47/1.74/0.46 | 679,034,880 bytes = 647.578125 MiB |
| [sendIn の非追従](observation-http.log)・[計時](observation-http.json) | 0 | 1成功・失敗0・無視0・除外13 | 3.893065 | 3.89/3.47/0.37 | 同上 |
| [実効 endpoint](observation-endpoint.log)・[計時](observation-endpoint.json) | 0 | 1成功・失敗0・無視0・除外13 | 1.876037 | 1.87/1.79/0.06 | 同上 |

正確なコマンドは各JSONの argv と [実行器](run-observations.py)にある。外側の `/usr/bin/time -p cargo test ... -- --exact --nocapture` の終了状態を直接保存した。getrusage(RUSAGE_CHILDREN) の補助値は実行器の子全体の累積最大値であり、後の行を個別試験固有の最大値とはしない。macOS の ru_maxrss の原値は bytes である。三試験の初回失敗・再実行はない。

## 互換層の使用箇所

| 定義 | 使用箇所と残す理由 |
|---|---|
| `AcceptInput.noRules` | `Surface/CheckAccept.lean` の定義と旧の像の定理、`Exchange/Observe.lean::ScopeAcceptanceEntry.acceptInput` の `none` 分岐、`Surface/CheckAcceptExamples.lean` の旧入力の例、`SurfaceCheck/Validation.lean` の型の正規化の独立例で使う。corpus14以前では `Version.legacyRangeDefaults` が `scopeAcceptance=null` を加えるため `none` 分岐が必要である。corpus15には scopeAcceptance が必須で、欠けた入力を noRules へ落とさない |
| 旧版 reader | `Exchange/Version.lean::exchangeJson` は corpus8〜15・sidecar2〜7 を読み、世代の組は `sidecarVersion` が決める。corpus14以前/sidecar6以前は範囲欄を先に拒否し、既知の節点だけへ `Range.legacyRangeNode` で明示Top・空の ranges を加える。旧 builtins へは空の範囲の表を加える。corpus15/sidecar7 は範囲の正規形・変数の位置と必須欄を検査し、旧既定値の変換を通らない。区間の `legacyRangeNodeMissing` は旧Surface14の補完と、新Surface15の欠落検出の両方に必要である |
| `fromEffNames` の既定候補 | `Exchange/Convert.lean` の既定引数は `atoms.filterMap Atom.toRelease` であり、旧の名前だけの利用と独立の完全性の補題・旧像の往復の補題を支える。`Convert.Comp.writeEff` は受け取った `univ` を明示して呼び、`CheckInput.Prepared.writeEffNames` も `p.input.atoms` を明示する。本番の準備した新範囲の入力を既定候補だけで照合しているわけではない。定理中の省略呼び出しと旧互換の使用を一括置換しない |
| `Release.ModelTargets` | `Scope.checkPathIn`・`File.writeTextIn` と旧Topの `File.readText`、対象なしの print/exit、Reference の実例を持つ。旧 readText の応答は `Ok("")` 等であり、対象健全性の前提を満たす実例である。全Rust File表・六つの新入口・実ファイルの内容の完全な対応の証拠とはしない。Http の項目は `ModelHttp` に別に置く |

互換層は変更していない。規則や候補の意味を変更する必要は見つからなかった。旧Topの「作用した対象を全て含む」は実装レビューの信頼条件として残し、今回の有限の制御した例を、旧Topの完全な外部観測を新たに証明したことへ広げない。

## 既知の差を適用する対象

| 差 | 固定する対象と照合方法 |
|---|---|
| k3 の束縛番号 | 対象は `batch3/k3/{corpus,builtins,stdlib}.json` である。既存 [R10.5 の対応表](../r10.5/binding-renumbering.json)は、所属モジュール・宣言の種類・所有する型クラス等の名前・宣言名で旧506宣言と新507宣言を対応させ、追加を標準 `Scope.PathIn` 一件に限る。未importの補充型は builtins の supplementalData の修飾名で対応させる。全整数へ一律に -1 する処理は用いない。現在の k3 の交換/型検査は通常の読者で別に照合し、生ハッシュの版・新欄の差まで同一とはしない。既存の [206件の比較結果](../r10.5/export-comparison.json)は既知の番号差を識別する根拠であり、今回の新形式の全比較の成功へ引用しない |
| E0711 | 対象は型クラスのメソッドの宣言が `uses File.Read["/data/**"]`、実装の宣言が `uses File.Read["/data/a"]` の形である。Rust の `typeck/traits/impls.rs` は宣言同士を `is_subset` で照合するため E0711 となる。Lean の `Surface/Check.lean::checkMethods` は型クラスの宣言の下で本体を検査し、`acceptEffCover` で被覆を許す。実装宣言の構造上の包含という Rust の追加制約は新交換のために緩めない。E0711 の除外を Required の四理由の同じ鍵の一致へ合算しない。既存 RV-R10.4 の軽4の扱いを保つ |
| U+0000 | 対象は、先頭が U+0000 で残りが符号付き整数と読める文字列のリテラルを、局所解析が条件引数として読む場合である。Lean の `ScopeState.absArg` はこれを未知へ落とす。整数リテラルを同じ文字列表現 `intLitText` で表すためである。Rust の `ScopeArgument::String` と `Integer(i64)` は分かれており、文字列を整数として扱わない。除外はこの精度差の入力を名指しし、通常の整数ポート・通常の文字列・要求レコード全体へ広げない。検査済み実行値の交換の `unsupported` は別の除外理由である。今回の実ファイルのバイナリに含む0byteも、この局所解析の除外とは関係しない |

既知の差の根拠の入力・実装・定義と各ハッシュは [observations-inputs.json](observations-inputs.json)へ保存した。K10.3は新形式の全関係定義を照合し、既知の差だけを名指しして扱う。処理系の保証や Lean の規則の変更を要する停止条件には当たらない。

## 片付けと時間

既存 target を使い、新しい CARGO_TARGET_DIR、target 外の一時ビルド、基準版の展開は作っていない。実ファイル試験の制御ディレクトリはテスト末尾で削除され、HTTP の listener/thread も終了した。`private/` とそこを指すスキル、`docs/todo/` は読んでいない。git の状態を変える操作をしていない。

本担当の最初の読解は2026-10-29 12:10 UTCごろ、三検査は12:12:36〜12:12:44 UTCであった。読解・対応表・記録を含む能動時間と終了は親の最終集約へ返す。K10.2全体の時間へ並行分を単純に加算しない。

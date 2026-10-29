# IF20.04 の結果

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | IF20.04、情報フロー制御（information-flow control）の表示・JSON・ログと CLI の入口と出口の棚卸し |
| 状態 | 棚卸しと扱いの候補、担当の自己確認を完了した。候補の採択、本番実装、独立レビュー、設計者の受け入れは行っていない |
| B_WORK | `3a5daaf388b04e579698c9ff5810cfe6dd753be2` |
| HEAD | `3a5daaf388b04e579698c9ff5810cfe6dd753be2`。`git rev-parse HEAD` で取得した |
| 閉じた範囲 | 明示的な公開関数118件と対応する組み込み75件・通常の関数43件、Show/ToLogValue の標準実装43件、補助経路37行、CLI の経路29行。宣言と登録、内部の派生と実際の出口、値と長さ・件数・形・成否を分けた |
| 未完の範囲 | IFC-D3・D4・D6・D8 の回答による候補の確定。U-D01〜U-D08 の設計・接続・実行確認。後続の独立レビューと設計者の受け入れは本枝の完了範囲に含めない |

## 変更と接続

[inventory/display-json-log.md](../inventory/display-json-log.md)を作成した。[File の欄と数え方](../inventory/file.md#表の欄と数え方)を参照させ、定義を写していない。公開関数、補助経路、CLI の出力の母集団を分け、同じ宣言と組み込みを二重に数えていない。数の別名の通常のラッパーは一関数として数え、型クラスのメソッド、誤りの表示、アクセサ、StringBuilder の専用操作は補助経路とした。

文字列補間は Show を使わず、書式なしの基本型の変換と14個の書式の内部頭を使う。Show は標準実装・手書き・生成したレコードの実装に分け、ToLogValue も別に記録した。JSON は stringify だけでなく、解析・要素の取得・Codec の種類・欠落・最初の失敗の位置を追った。ログは本文・属性の値に加え、鍵・件数・重複・位置・水準・出力先の選択と後続の非実行を含めた。Writer を捕捉したログと任意のハンドラで接続を閉じられない使用は、未対応で拒否する候補を残した。

CLI は、正常な main の値を汎用表示しない。一方、main が返す Result.Error(String) は JSON 診断の指定があっても素の文字列と改行で stderr に出る。非実行の報告も、ソースの表示名・ハッシュ・診断・解析件数を出す。W0403 は定数評価した重複キー、W0301 は非推奨の説明を報告へ埋め込む。テストの独自の値表示、成功時も捕捉出力を含む JSON の結果、統計の数値をそれぞれ別の経路にした。

変更は `inventory/display-json-log.md` と `if20.04/` の文書・照合データ・dry-run の記録だけである。集計用の作業ファイルは指定された `work/scratch/IF20.04/` の下へ置いた。本番ソース、現行設計書、生成 Skill、依存・固定版は変えていない。`private/`・`docs/todo/` と、それらを指すリポジトリのスキルのリンク先は読んでいない。git の状態を変える操作も行っていない。公開の japanese-tech-writing と rtk を読んだ。ソースの行・名前と読解結果を保存する検索は、生の rg を主に使った。手元の絶対パスを記録へ含めていない。

## 件数と扱いの候補

| 母集団 | 件数と方向 | 0.0.14 の扱いの候補 |
|---|---|---|
| 明示的な公開関数（D001〜D118） | 118件。入口だけ0、出口だけ0、両方8、内部の派生110。入口を含む8、出口を含む8 | 契約を設ける118、保守的0、未対応で拒否0、未確認0 |
| 補助経路（P01〜P37） | 37行。入口だけ0、出口だけ2、両方3、内部の派生32。入口を含む3、出口を含む5 | 契約を設ける34、保守的0、未対応で拒否3、未確認0 |
| CLI の経路（C01〜C29） | 29行。入口だけ1、出口だけ28、両方0、内部の派生0。入口を含む1、出口を含む28 | 契約を設ける12、保守的（秘密の結びとする）14、未対応で拒否2、未確認1 |
| 宣言と実装 | 組み込み75件、言語内の通常の関数43件。宣言と登録の不足は見つからなかった | 契約は内部の派生の依存保存も含む。118件を無条件で公開の出力へ許す意味ではない |
| 標準の型クラスの実装 | Show 31件、ToLogValue 12件。D の118件と合算しない | すべて補助経路で契約を設ける候補。通常の実装へ非機密化の特権を与えない |
| 未確認事項 | U-D01〜U-D08 の8件 | 候補の未採択と、未確認の事実・未接続を分けた |

公開関数の内訳は、数・文字の表示と別名のラッパー18、String 28、Time 11、IOError/NetworkError 4、Json 11、Json.Codec 21、Log 11、SourceLocation 1、Encoding 4、Csv 5、Bytes の二つの文字列化2、Test.Property.formatFailure 1、Http.json 1である。Http.json は前の Http 棚卸しにもある一関数なので、全枝を通した数へ重ねて加えない。

内部の派生は新しい外部入力ではない。Log の両方8件は、既定の出力失敗と、本文・sink の実際の IO を含める。enabled の既定処理は比較だけであり、内部の派生とした。withSinks の E が純粋な使用まで IO と扱う集計ではない。P/C は同じ操作の異なる段階や観測を含むため、三表を合算して操作の総数と呼ばない。

照合データは [operations.json](operations.json)、標準実装の一覧は [methods.json](methods.json)、補助と CLI の経路は [pathways.json](pathways.json)、集計は [counts.json](counts.json)に保存した。

## 検査

依頼で指定された次の dry-run だけを一回実行した。対象は B_WORK からの変更の分類と、選択される検査・理由の表示である。cargo のビルド・テスト、lake build・lean、LLM を呼ぶ評価は実行していない。

```sh
scripts/check.sh --level work --base 3a5daaf388b04e579698c9ff5810cfe6dd753be2 --dry-run
```

実行結果は [標準出力](work-dry-run.stdout.txt)・[標準エラー](work-dry-run.stderr.txt)・[終了状態・時間・常駐量](work-dry-run.measurement.json)に保存した。git の任意のロックを抑えるため、子プロセスに `GIT_OPTIONAL_LOCKS=0` を渡した。

| 選択と理由 | 終了状態 | 外側の所要 |
|---|---|---|
| 文書だけの変更8ファイルと分類され、`nothing to check: only documents changed`。選択された検査は0件 | 0。標準エラーは空 | 0.078559666秒 |

8ファイルは実行時点の棚卸し、本結果、照合用JSON四つ、実行前に開いた標準出力・標準エラーである。計測JSONは実行後に増えた。以後の変更も指定範囲の文書と照合データの修正だけであり、再実行していない。dry-run の選択の成功を実検査の成功として数えない。

## 最大常駐量

IF20.01 の外側の `/usr/bin/time -l` がサンドボックスの sysctl 拒否で失敗した申し送りに従い、同枝の代替方法を初めから使う。Python の subprocess.run で同じコマンドを待ち、time.monotonic の差と resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss を採取する。macOS の原値はバイト、換算は MiB（2^20バイト）・GiB（2^30バイト）とする。

原値は **10,059,776バイト**、換算は **9.59375 MiB、0.009368896484375 GiB** であった。これは OS の time が表示する値の代替の補助計測であり、測定プロセスの子についての最大値である。並行する全プロセスの RSS の合計、読解と文書作成全体、実行していない Rust/Lean のビルドの最大常駐量を表さない。取得不能を0とした値でもない。

## 検索と読解・文書の自己確認

ソースの検索に使ったコマンドを示す。リポジトリの根からの相対パスであり、同じ検索式を rtk proxy で実行した箇所もある。位置を絞った本文は cat と sed -n で読み、名前の想定を根拠にしていない。

```sh
rg --files crates/benitoite/src docs/design | rg '(display|format|show|json|log|cli|Trait|String|Time|error|03-06|03-07|01-07|07-01|00-01)'
rg --files crates/benitoite/src/prelude/stdlib | rg '(Log|SourceLocation|IOError|NetworkError)'
rg --files crates/benitoite/src/prelude/stdlib | rg '(Json|Log|Number|Integer|Float|Decimal|Time|Bytes)'
rg -n 'name = |fn |pub fn ' crates/benitoite/src/builtins/funcs/{format,json,log,io_error,network_error}.rs
rg -n 'public function' crates/benitoite/src/prelude/stdlib/{String,StringBuilder,Time,Encoding}.bnt
rg -n 'public function .*toString' crates/benitoite/src/prelude/stdlib/{Integer64,Float64,UnsignedInteger8,UnsignedInteger}.bnt
rg -n 'name = .*toString|name = .*Trait.show|pure fn to_string|pure fn show|fn to_string|fn show_' crates/benitoite/src/builtins/funcs --glob '*.rs'
rg -n 'Interpolate|interpolat|%Format|toString|StringBuilder|BuilderOp::' crates/benitoite/src/ir --glob '*.rs' | head -90
rg -n 'implement.*Show' crates/benitoite/src/prelude/stdlib --glob '*.bnt'
rg --files crates/benitoite/src | rg '(builders|builder|projection|accessor)'
rg -n 'Getter|getter|GetField|Field|Proj' crates/benitoite/src/ir/desugar.rs crates/benitoite/src/ir/desugar/*.rs | head -70
rg -n 'format_value|render_value|show_value|ValueDisplay|display_value|fn .*display|bounded.*value|MAX.*(DISPLAY|PRINT)' crates/benitoite/src --glob '*.rs' --glob '!**/tests/**' --glob '!**/tests.rs' | head -70
rg -n 'print|write|format|json|RunValue|inspect|check|Command::|fn ' crates/benitoite/src/cli/mod.rs
rg -n 'render_json_line|json_string|escape_terminal|pub fn|primary|message|notes|helps|source_line' crates/benitoite/src/diag/render.rs | head -105
rg -n 'pub fn|print|write_bytes|json_|report|fn ' crates/benitoite/src/cli/tools/{formatter/mod.rs,skill/mod.rs,package/mod.rs,licenses.rs} | head -110
rg -n '^pub|^fn|value|summary|stdout|stderr|counterexample|render' crates/benitoite/src/cli/tools/test_runner/report.rs | head -100
rg -n 'warning|warn|eprintln!|println!|write_output' crates/benitoite/src/runtime crates/benitoite/src/builtins/funcs --glob '*.rs' --glob '!**/tests/**' --glob '!**/tests.rs' | head -85
rg -n 'stats|write_bytes|serialize' crates/benitoite/src/runtime/run.rs crates/benitoite/src/external/stats.rs crates/benitoite/src/cli/tools/test_runner/mod.rs | head -65
rg -n '^public record|^  [A-Za-z]+:' crates/benitoite/src/prelude/stdlib/Network/Http.bnt
rg -n 'Show|show|counterexample|試行|trials|shrink' crates/benitoite/src/prelude/stdlib/Test/Property.bnt | tail -25
rg -n '^def .*|Trait.Show|Show.show|function show|custom|encode' tools/derive/derive.py | tail -45
rg -n 'Json.stringify|Trait.Show.show|Log.formatRecord|toLogValue' crates/benitoite/src/prelude/stdlib --glob '*.bnt' | tail -38
rg -n 'deprecated|Deprecated|W.*[0-9]|DUPLICATE|duplicate.*(key|element)|show.*(value|key)|display.*(value|key)' crates/benitoite/src/typeck/consts.rs crates/benitoite/src/resolve --glob '*.rs' --glob '!**/tests/**' --glob '!**/tests.rs' | head -55
rg -n 'dry.run|mkdir|target|log_dir|git.*status|untracked' scripts/check.sh | head -50
```

改造の文書では、README、共通依頼文、decisions の表記と判断8/19/21・IFC-D3/4/6/8、plan の IF20 と文書作業の検査割り当て、四つの study の情報フロー制御と典型例を読み、前の三枝と File の欄の定義へ合わせた。現行設計書は棚卸しの冒頭にリンクをまとめた。過去の改造や未公開の項目を現在の実装の根拠にしていない。

Python の標準ライブラリで宣言と組み込みの名前・行、通常の関数、標準の implement の一覧を抽出し、各表の8欄・ID・方向・候補の件数を照合した。118件の宣言の名前と行、75件の組み込みの名前と DECLS、43件のメソッドの定義の位置を確認した。補助・CLI の66行も同じ8欄である。棚卸し内の相対リンク347件の参照先に欠落はなかった。これは文書とソース位置の自己確認であり、処理系のビルド・テストや独立レビューではない。

最終の再読で Json の各射影、Codec の各変換、Csv/Encoding を、それぞれの実際の引数・戻り値・成否に分けて具体化した。件数と候補は変わらず、184行の8欄・IDと照合データ、棚卸しと本結果の相対リンク356件に不一致や欠落はなかった。読み取り用の git コマンドは `git rev-parse HEAD`・`git status --short` と、作業末の `GIT_OPTIONAL_LOCKS=0 git status --short --untracked-files=all`・`GIT_OPTIONAL_LOCKS=0 git diff --name-only 3a5daaf388b04e579698c9ff5810cfe6dd753be2 --` を使った。開始時の変更はなく、作業末も追跡済みの差分はなく、指定範囲の新規9ファイルだけであった。HEAD は上記の完全IDのままである。

## 失敗と修正

読解中に Log を IO/Log.bnt、Http を Http.bnt または Net/Http.bnt、構築器の本体を runtime/builders.rs 等と仮定した検索が、対象なしを返した。rg --files で Log.bnt・Network/Http.bnt・runtime/heap/builders.rs と resolve/builders.rs を確かめ直した。tools/derive/generate*.py の検索も zsh の一致なしになり、実在する derive.py の generate_trait/generate_json を読んだ。これらは本番実行や検査の失敗ではない。

初稿の String.repeat の負数の説明を、実際の「回数が0以下、または元が空なら空文字列」へ直した。書式付き補間に Show の引用があるかのような語を除き、String をそのまま幅の補充へ使うことを確認した。Property の formatFailure は Show 型クラスへの固定の呼び出しではなく、利用者が渡す show 関数を呼ぶと直した。HTTP の各欄と Process.Output の standardOutput/standardError は実在する宣言へ合わせた。

全公開関数の列挙を読み直し、値を文字列化する Test.Property.formatFailure と Http.json を D 表にも明示した。これにより最初の116件から118件となった。前の Http 棚卸しとの重複は全枝の集計で除く旨を明記した。補助経路は、HTTP の JSON 応答の構築と警告の独自の定数表示を追加して35行から37行とした。件数の変化を処理系の変更と扱っていない。

dry-run は初回で終了0、失敗・再実行はなかった。実検査を起動していないので、処理系のテストの成功・失敗として報告するものはない。

## ずれと申し送り

依頼の読み取りと文書作業に限り、候補を決定や現行設計書へ転記していない。数・文字の表示、String の変換とメタデータ、Time、Csv・Encoding、Property.formatFailure と Http.json は、JSON とログへ至る文字列化の経路を落とさないために含めた。一般の Path・Regex・Hash や任意の純粋な関数の全件は担当外であり、内部の派生の共通条件と IF20.06 への申し送りを記した。長い実検査・性能測定を追加していない。

| 後続 | 申し送り |
|---|---|
| IF20.05 | main_error の素の stderr、IOError/NetworkError と Json/Csv/Time の文言、Scope/Range/Codec のキー・端点・位置、Assert の Show を使わない表示、Property の元/縮小後の反例を、die・テスト失敗・診断・終了状態へつなぐ。内容を伏せても失敗の事実・件数・出力の有無を残す |
| IF20.05 | C07〜C09 の警告・文章/JSON・ソースの抜粋と修正案、C28 の実行時/解放/die の描画、HTTP accept の自動警告、出力失敗とホストの異常終了を照合する。JSON の指定だけでは main_error や fmt/skill の文章の報告は変わらない |
| IF20.06 | 任意のハンドラの非再開・再送と pc、Task、Writer と暗黙の解放、外部コマンド/WASM/ハーネス、一般の純粋な派生と残る入口・出口を照合する。統計の明示的な数値の出力を物理資源量の保証外へ一括して捨てない |
| IF20.06 | 公開 CSV の集計は入力契約→Csv→要素/件数→数の表示→Console、トークンによる件数表示は固定 API の値・成否・用途の契約→Json/Codec→件数→表示、機密ファイル送信は許した送信と失敗文・ログの表示を別に照合する |
| IF10/IF30・取りまとめ | IFC-D3・D4・D6・D8 の回答後に候補を確定する。未知のソース・設定・起動引数を含む CLI の報告の分類と受け手の所有も決める。方針の新書式や非機密化/エンドースメントの新 API を本枝の候補から先に確定しない |
| 0.0.14・接続を閉じる改造の担当 | U-D01〜08 を担当へ割り当てる。特殊構成・32ビット・OS 差・失敗文の実出力は、対象を確定してから再現する。本枝のソース読解を実行済みの根拠として引用しない |

後続の検査・測定・レビュー・受け入れは次のとおりである。本枝へ実検査や性能測定を追加する予定はない。

| 手順 | 担当と時期 | 見込み時間 |
|---|---|---|
| 本枝の文書の独立レビュー | 取りまとめが割り当てる担当、取り込み前 | 不明 |
| IFC-D3・D4・D6・D8 の回答、候補の採否と受け入れ | 設計者・取りまとめ、IF10/IF30 | 不明 |
| 未確認の実装・再現検査と必要な測定 | 0.0.14 または接続を閉じる改造の担当、対象を確定した後 | 不明 |

## 時間

| 区分 | 記録 |
|---|---|
| 開始の最初の時計 | 2026-10-27 18:34:16 JST（09:34:16 UTC）。AGENTS.md とスキルの最初の読解後であり、その前の短い読解を含む正確な着手時刻ではない |
| 完了時の時計 | 2026-10-27 18:54:49 JST（09:54:49 UTC）。最終の本文・件数・欄・リンクを自己確認した時点であり、この時刻と結果の転記が続く |
| 外側の所要 | 最初の時計から20分33秒と、上の転記の短い時間。最初の時計より前の読解を含む全所要は正確には取得していない |
| 能動時間 | 個別の計時なし。読解・文書作成・集計・自己確認を含む。待ち時間との差を厳密には算出していない |
| 検査・測定・待ち | 指定の dry-run 一回、0.078559666秒。ビルド・テスト・性能測定・LLM 評価・設計者の回答待ちはなし |

見込みの上端1時間の2倍は超えていない。時間超過による中断や未完の繰り越しはない。

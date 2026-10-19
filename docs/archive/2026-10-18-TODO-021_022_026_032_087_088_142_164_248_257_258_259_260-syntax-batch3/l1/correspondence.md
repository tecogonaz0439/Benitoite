# L1から実装側へ渡す対応と独立期待値

本表はdesign 14.2・14.3の対応表である。L1はLeanの小モデルだけを実装した。以下の字面からの解析・正規化、元の字面とreasonの保存、実際の公開関数の結果は、K1・K3・K4で照合する。Rust/CLIで観察済みの結果ではない。

## Scopeの対応

表の `s` は `["example", "com"]`、`h` は `["a", "b", "example", "com"]`、`d` は `["data", "reports"]` とする。成功時の失敗欄は「なし」と記す。ホストとパスの対象は区切りを除いた要素列であり、元の字面ではない。

| parserへ渡す入力・正規化の期待 | パターンの形／対象 | 保存する欄 | 失敗と優先順 | 射影の期待 |
|---|---|---|---|---|
| Host `*.EXAMPLE.COM`, `API.EXAMPLE.COM` → 小文字化 | `.one s` / `["api"] ++ s` | 正規化した条件と対象 | なし | host=`api.example.com`, hostPattern=`*.example.com` |
| Host `*.example.com`, `example.com` | `.one s` / `s` | 失敗の元入力 | OutsideScope | 成功値なし |
| Host `*.example.com`, `a.b.example.com` | `.one s` / `h` | 失敗の元入力 | OutsideScope。一段と多段を混同しない | 成功値なし |
| Host `**.example.com`, `api.example.com` または `a.b.example.com` | `.many s` / 一段または `h` | 正規化した条件と対象 | なし | 入力の正規化結果を返す |
| Host `**.example.com`, `example.com` | `.many s` / `s` | 失敗の元入力 | OutsideScope。頂点は含まない | 成功値なし |
| Host `localhost`, `localhost` | `.exact ["localhost"]` / 同じ列 | 条件と対象 | なし | 両射影とも `localhost` |
| Hostの対象 `api..example.com`, `example.com.`, `-api.example.com`, `api-.example.com`, `日本語.example.com` | parserの形式不良。空ラベル・ハイフン端・非ASCII | InvalidTargetの元の字面とreason | 所属より先のInvalidTarget | 成功値なし |
| Hostの対象 `127.0.0.1` または `999.999.999.999` | 四つの十進数字ラベル | InvalidTargetの元の字面とreason | 数の値の範囲によらずInvalidTarget | 成功値なし |
| Path `/**`, `/` | `.tree []` / `[]` | 条件 `/**` と対象 `/` | なし。根は妥当 | path=`/`, pathPattern=`/**` |
| Path `/data/reports/**`, `/data/reports` または `/data/reports/日報` | `.tree d` / `d` または `d ++ ["日報"]` | Unicodeも変換せず保存 | なし。幹自身を含む | 入力の条件と対象を返す |
| Path `/data/reports/**`, `/data/reports-old` | `.tree d` / `["data", "reports-old"]` | 失敗の元入力 | OutsideScope。文字列の前方一致にしない | 成功値なし |
| Path `/資料/**`, `/資料/*.txt` | `.tree ["資料"]` / `["資料", "*.txt"]` | 対象の `*` をそのまま保存 | なし | path=`/資料/*.txt`, pathPattern=`/資料/**` |
| Pathのパターン `/資料/*.txt` | 幹内に `*` がある | InvalidPatternの元の字面とreason | InvalidPattern | 成功値なし |
| Pathの対象 `/data/`, `/data//x`, `/data/..`, 相対形式、逆斜線またはNULを含む字面 | parserの形式不良 | InvalidTargetの元の字面とreason | 所属より先のInvalidTarget | 成功値なし |
| Endpoint `**.example.com`, `a.b.example.com`, 0, 65535, 0 または65535 | `.many s` / `h` / Intの三入力 | 正規化した二欄と整数の三欄 | なし。両端を含む | endpointHost/Pattern/MinimumPort/MaximumPort/Portが五欄と一致 |
| Endpoint 同じホスト、443, 443, 443 | 同上、一点区間 | 同上 | なし | 端点とportはいずれも443 |
| Endpoint `**.example.com`, `elsewhere`, 0, 65535, -1 または70000 | 妥当な形式と端点、無効なport | エラーのportを保持 | InvalidPort。ホスト所属より先 | 成功値なし |
| Endpoint 同じ条件、443, 0, 70000 | 逆転した端点と無効なport | 二端点を保持 | InvalidPortRange。InvalidPortより先 | 成功値なし |
| Endpoint `**.example.com`, `elsewhere`, 443, 443, 444 | ホストとポートがともに不所属 | エラーの条件と対象を保持 | OutsideScope。PortOutsideScopeより先 | 成功値なし |
| Endpoint `**.example.com`, `a.b.example.com`, 443, 443, 444 | ホストは所属、ポートだけ不所属 | 二端点とportを保持 | PortOutsideScope | 成功値なし |
| Endpoint 不正パターン・不正対象・逆転端点・無効portの組 | 解析の時点で不正 | 元の字面とreasonを保持 | InvalidPattern→InvalidTarget→InvalidPortRange→InvalidPortの順 | 成功値なし |

Leanの構造化した失敗は、元の字面とreasonを持たず、解析済みのパターン・対象または整数を持つ（R145）。表のparserの拒否を、小モデルへ架空の正常入力として渡して成功比較しない。特に大文字はparserの正規化後に `ValidHostWord` を確かめる。

## 公開境界とRangeの対応

| 対象 | 小モデルの条件 | 実装側で照合する期待 |
|---|---|---|
| 公開境界 | ownerとcallerは解決済みの宣言元・使用元 | 同一モジュールでは内部操作を許し、同じパッケージ内の別モジュールでは拒否する。import別名・型別名でもownerは変わらない。型注釈と通常値の受け渡しは許す |
| Range 0, 10, 10 | 三入力がIntegerで表現可能、`InRange 0 10 10` | Ok。minimum=0、maximum=10、value=10 |
| Range 10, 0, 5 | 逆転した端点 | InvalidBounds(10, 0)。OutOfRangeより先 |
| Range 0, 10, 11 | 正常な端点、範囲外 | OutOfRange(0, 10, 11)。定数でも通常のResult.Error |
| Range n, n, n | nは符号付き64ビットで表現可能 | 一点区間のOk。三欄ともn |
| Range -9223372036854775808, 9223372036854775807, 最小値または最大値 | 三入力ともIntegerで表現可能 | 両端でOk。上端+1を計算しない。三射影が入力と一致 |

ScopeもRangeも新しい実行時表現や範囲付きの型・効果を要求しない。Leanの証拠は実行値へ入れず、rawレコードと失敗の値を対応させる。K3/K4で照合することは、RustとLeanの本体の型保存の全比較とは別の証拠である。

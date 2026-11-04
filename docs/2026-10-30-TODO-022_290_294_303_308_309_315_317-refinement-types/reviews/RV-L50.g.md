# RV-L50.g: L50 群 G（L50.31〜.35）の独立レビュー

2026-11-04。対象はブランチ `m014/l50.g` の未コミットの作業木で、基準は `38a98b76258171b96ee73091d8c25833030d776d`（HEAD と一致）である。見たものは次のとおりである。
- 本番の変更3ファイル: `git diff 38a98b76 -- formal docs/design` で追加13行・削除0行。`formal/Benitoite.lean` の import 2行、01-12 の3段落、07-04 の2段落と表の1行である。
- 新規2モジュール: `ScopedIOResponse`（472行）・`ScopedIOExamples`（211行）。
- `l50/g/` の記録。

読んだもの:
- 依頼と報告: 担当への依頼、担当の報告。
- `l50/detail.md`: 第2節の13 API の表、第3節 F04・F05・F07、第4節の ResponseAssumptions・TargetAgreement の行、第5節の L50.31〜.35 と群 G の完了条件、第11節の L60 へ渡す名前。
- `l50/g/`: results.md・actual-signatures.md・contracts.lean・verification.json・build-check.json。
- 前の群のレビュー: `reviews/RV-L50.a.md`（情報4）・`RV-L50.e.md`（中3、情報1）・`RV-L50.f.md`。

Lean で読んだもの:
- 新規2モジュールの全文。
- `BuiltinResponse.lean` の `ResponseAssumptions`・`TargetAgreement`・`shapeAt`。
- `ScopeSignatures.lean` の `entries`・`effects`・`builtins`・`io_op`。
- `EffectTargets.lean` の `Builtins.TargetAgreement.obs_allowed`（内部で `ShapeOk.single_target` を使うこと）。

処理系で読んだもの:
- `builtins/funcs/file.rs` の `retained_path` と範囲付きの6入口。
- `builtins/funcs/http_client.rs` の `send_in`・`start_send`・`validate_host`・`Failure`・`complete`。
- `builtins/funcs/http_client/checked_request.rs` の `retained_request`・`matches_endpoint`。
- `builtins/table.rs` の `FILE_IN_OPERATIONS` と `builtin_range_positions`。
- `prelude/stdlib/IO/File.bnt`・`Network/Http.bnt` の署名と効果。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l50-g/` に置いた。

## 結論

**可**（重0・中0・軽2・情報6）。

完了の判定は満たす。主な点は次のとおりである。
- 応答の関係 `ioResponse` は、型付けの判断を含まない具体の構築（`Payload`・`Reply`）で定義されている。循環はない。
- 七つの入口と `response` は、任意の P・B・Ψ、元の全 `BuiltinArgs`、同じ関係の全 out・obs を量化する。
- 関係は処理系が返しうる三つの形（Ok・Error・停止）を含み、型の違う Ok・別の対象・空の観測・exit を含まない。
- 存在の証人は `Result.Error` で、正常の成功や外部状態の精密化を前提にしない。

処置を勧める点は、写しの正確さの2件だけである。どちらも完了の判定を左右しない。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 軽1 | 軽 | 01-12 の追加の第2段落（4036行）、07-04 の追加の第1段落（157行） | 二つの写しは、型付き応答の前提を「HasFile P」等と書き、その直後に `responseAssumptions` が同じ表の応答条件を構成すると続ける。しかし本番の `responseAssumptions` の前提は `HasHttp P` である（純粋6行の `ScopeResponse.delta_typed` が要する）。`io_typed`・`io_exists` は `HasFile P` で足りる。写しの並びでは、`responseAssumptions` も `HasFile P` で成り立つと読める | 01-12・07-04 の該当の文に「responseAssumptions は HasHttp P の下で」と前提を書き分ける | 読めば確定 |
| 軽2 | 軽 | 01-12 の追加の第3段落の末尾（4038行）、07-04 の追加の第2段落（159行） | 写しは「ScopedIOExamples は……非 Top・Top の両方の全前提を供給する」と書く。実際に全前提（NamesWF・lookup・ShapeOk・BuiltinArgs・適格性・TargetAgreement・実応答）を具体に供給したのは `File.readTextIn` の一行だけである。他の六行は、BuiltinArgs を仮定する全称の適用例と、BuiltinArgs なしの応答の例だけである。results.md は一行であることを明記しているが、写しでは七行すべてに具体例があると読める | 写しに「File.readTextIn の行で」と対象の行を書く | 読めば確定 |
| 情報1 | 情報 | `ScopedIOResponse.ioResponse`・`Reply`・`Payload`（29〜40行、129〜132行）と処理系 | 関係の形と処理系の結果を照らした。<br>・File の Ok: 任意の String、各要素が0〜255の Bytes、Unit。<br>・Http の Ok: `complete` が作る Response のレコード。<br>・Error: IOError、又は `Failure::Network` から作る NetworkError。<br>・`Outcome.err`: `Failure::InputTooLarge` などの `Stop::Resource` に当たる。<br>関係はこの三つを含む。逆に、型の違う Ok（readTextIn の Bytes の Ok、write の String の Ok）、別の対象の観測、空の観測、型引数のある呼出し、256 を含む Bytes、Reference.get の IO 応答を含まないことを検査2で確かめた。exit を含まないことは `io_kind` が示す。広すぎも狭すぎもしない | 不要 | 実行で確定（検査2） |
| 情報2 | 情報 | `Payload.http`・`Reply.error` と `ScopeSignatures` の原署名 | Http.Response は `.bnt` では record（status・headers・body）であり、IOError・NetworkError も欄を持つ。Lean ではこれらを番号付きの不透明な定数で表す。これは群 E で固定した原署名（`.opaque "Http.Response" .top` 等）に合わせたもので、群 G が新しく抽象化したものではない。欄の値は観測の対象に関わらず、結論の型付け・適格性は不透明型で足りる。欄の中身を比べる必要は R 段の比較の担当である | 不要 | 読めば確定 |
| 情報3 | 情報 | `ioResponse` の File の行 | 関係は第二引数（text・content）を見ず、`ws` の長さも制約しない。例えば `File.writeTextIn` に `[.checked t]` だけを渡した場合も関係に入る（検査2の例 e）。結論は全て `BuiltinArgs` の下で読まれ、型付き入力では第二引数の型が `inputs` から決まるので、言明の正しさには影響しない。処理系も第二引数は書く内容にだけ使い、観測の対象に使わない | 不要 | 実行で確定（検査2） |
| 情報4 | 情報 | 観測の対象と処理系 | File の6入口は、処理系では `retained_path` が PathIn の一欄の String を取り出し、既存の `start_read_text`・`start_read_bytes`・`start_write` へ渡す。追記は `start_write(…, true, …)` である。Lean は `ws[0]?` の `target?` 一つを obs とし、書込みと追記は別の実名（`Operation.writeText`・`appendText` 等）で `entries` の別の行を引く。`effects` の File.Write は追記の2行を含み、`.bnt` の `effect Write` の宣言と一致する。`Http.sendIn` は、処理系では `retained_request` が保持欄の host・port から endpoint を作り、`start_send` が送信用 URI を `matches_endpoint` で照合する（不一致は `Stop::Internal`）。Lean の `RequestSent` は保持形を `checkedRequest` 又は要求を持つ `checkedAt` に限り、`valueRun`・`groundVal`・`reqTarget` で同じ endpoint を確かめる。不一致と要求なしの値は関係に入らない（既定ビルドの例）。群 E の中3で直した IPv4 射影形の拒否は、同じ `reqTarget` を使うので引き継がれる。Host ヘッダの不一致（`validate_host`）は処理系では NetworkError になり、Lean の任意の Error に含まれる | 不要 | 読めば確定 |
| 情報5 | 情報 | `ScopedIOExamples` の最初の例、群 A の情報4 | 実際の `builtins ScopeResponse.delta ioResponse` と `ScopeDeclarations.program` で、`File.readTextIn` に `/data/a` の checked 値を渡す。`wide` の真偽で範囲は Top と `/data/**` の両方になり、Ψ・σ は任意である。結論は次を同時に含む。<br>・NamesWF、lookup、ShapeOk、BuiltinArgs の全欄。<br>・全引数の Adequate、TargetAgreement、実際の Error の応答。<br>・F04 の範囲・対象・shapeAt と、F05 の File.Read の許容。<br>群 A の情報4の「単一対象の全前提を満たす具体例を一つ」を満たす。一般の主張は `response`・`target_member`・`io_exists` の全称の定理が担い、具体例から推していない | 不要 | 読めば確定 |
| 情報6 | 情報 | 既存の定義・言明・公理、L60 への署名 | `formal/` の既存のファイルの変更は `Benitoite.lean` の import 2行だけで、削除は0行である。既存の定義・型付けの規則・主な十言明・旧 `Release` は差分にない。`#print axioms` の6件は全て `propext`・`Classical.choice`・`Quot.sound` の範囲内だった。新しい2モジュールは生成物を書かない単独の検査でも誤りなく通り（各約1秒）、`sorry`・`axiom`・`admit` の語は0件である。L60 へ渡す署名は、任意の P・B についての `ScopedIOResponse.response`（前提は `entries.lookup`、表の分類の欄、`HasFile P`）と七つの入口であり、results.md と actual-signatures.md（195行〜）に記録がある。contracts.lean の第3例が、`HasHttp P` からの呼出しで同じ形をそのまま使えることを示す。担当の230宣言の監査は引用し、再実行していない | 不要 | 実行で確定（検査1・3） |

## 観点ごとの根拠

### 1. 応答の関係

- **空疎でないこと**:
  - `ioResponse` は存在量化した `Operation` と `Reply`・`RequestSent` からなる。`HasTypeVQ`・`Outcome.Typed` を含まない。型付けは `reply_safe` が `Payload` の場合分けと `ScopeDelta.result_safe` から別に証明する。
  - 何でも導ける形ではない。検査2の否定の例（情報1）が、関係に入らない応答を具体に示す。
  - 存在は `file_response`・`sendIn` の第二成分が `.error 0` で構成する。必要な対象 t は型付き入力から `ScopeDelta.path_target`・`RequestDelta.retained_request` で取り出す。外部の状態や成功は仮定しない。
- **処理系の写し**: 情報1・2・4のとおりである。
- **計画の条件の形**:
  - `io_typed`・`io_kind`・`io_exists` は `ResponseAssumptions` の欄の型のまま構成され、`responseAssumptions` が純粋6行の `delta_typed` と合わせて構造体を作る。
  - `targetAgreement` は任意の P と任意の純粋 δ について `TargetAgreement.io_target` を作り、CoreAssumptions を要求しない。
  - contracts.lean の第1例は、群 A の F07IO の全称の型を七操作すべてへ適用する。
  - 三モデルの25条件のうち IO に関わる4欄（io_typed・io_kind・io_exists・io_target）が、共通表で揃う。モデルの部分表への適用は群 H〜J の担当である。

### 2. 観測の対象

情報3・4のとおりである。File の6本は最初の引数の保持パス一つ、`Http.sendIn` は同じ保持要求の endpoint 一つを obs にする。`targets` はこれを `ShapeTargets` の single の枝へ渡し、Top への fallback を使わない。`response` は `entries` の16行を全て場合分けし、IO の7行を各入口へ振り分け、残りの9行を kind で除く。追記の2行は書込みと別の場合として現れ、登録の漏れはない。

### 3. L50.35 の具体例

情報5のとおりである。全称の適用例（118〜129行）は、任意の IO 行の lookup と元の BuiltinArgs から、存在・型・適格性・非 exit・`target_member` の結論を同時に読む。写しの記述の範囲は軽2のとおりである。

### 4. 既存の定義・言明・公理

情報6のとおりである。

### 5. L60 へ渡す署名

情報6のとおりである。単独の表の定理（`table_response` の形）ではなく、任意の P・B の `response` が渡される。

### 6. 設計書の写しと記録

- **写し**: 01-12 の3段落と 07-04 の2段落・表の1行は、本番の宣言名と結論に一致する。不足は軽1（`responseAssumptions` の前提）と軽2（具体例の行）である。経緯の文や工程の ID はない。
- **記録の大きさ**: `l50/g/` の最大のファイルは final-manifest-part-02.json の55,782バイトで、全体は約0.4 MB である。
- **禁止の参照**: 手元の絶対パス・`private/` の内容・docs/todo へのリンクは0件だった。照合の正規表現（verify.py 113〜114行）は検出から除いた。

## 実行した検査

| # | 検査 | 結果 |
|---|---|---|
| 1 | `<tmp>/rv-l50-g/Probe.lean` で `#print axioms` を6件に実行した。対象は `ScopedIOResponse.response`・`sendIn`・`target_member`・`responseAssumptions`・`io_exists`・`appendBytesIn` | 全て `propext`・`Classical.choice`・`Quot.sound` の範囲内（情報6） |
| 2 | 同じファイルで次を証明した。<br>(a) readTextIn の関係は Bytes の Ok を含まない。<br>(b) 保持対象と違う対象を観測しない。<br>(c) 空の観測を含まない。<br>(d) 256 を含む Bytes は `Payload` にならない。<br>(e) writeTextIn は第二引数がなくても関係に入る。<br>(f) writeTextIn は String の Ok を含まない。<br>(g) 型引数のある呼出しを含まない。<br>(h) 共通表で Reference.get は IO 関係に入らない | 全て通る（情報1・3）。最初の実行では、(a)(f) の `cases reply` が添字の文字列の不一致を解けず失敗した。各 `Reply` の構成子ごとに等号の否定を示す形に直して再実行した |
| 3 | `ScopedIOResponse.lean`・`ScopedIOExamples.lean` を `lake env lean -M 12288` で `-o` なしに単独で検査した。あわせて二つのファイルの `sorry`・`axiom`・`admit` の語を数えた | 誤りなく、実時間で約1.1秒と約0.7秒。語は0件（情報6） |

各回の外側の時間は約1秒以内だった。大きな具体値を作る評価はしていない。

## 取りまとめの追記

- 軽1・軽2は写しの文の書き分けだけなので、取りまとめが 01-12・07-04 で直した（`responseAssumptions` の前提を HasHttp P と書き、全前提を具体に供給した行を File.readTextIn と明記した）。Lean は変えていない。情報1〜6は処置しない。
- 群 G の作業末の work は終了0、454.06秒、最大常駐量 2,879,176,704 バイト（篩の部分の生成物を消して再ビルド。l50/g/results.md）。

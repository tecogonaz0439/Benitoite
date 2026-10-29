# 正規表示・bounds と名前による照合

## 作業と状態

R40.2 の実装・局所検査・作業末の W-40 を完了した。B_WORK と HEAD は `a2fd2b6abaaa6c11d0b8dcb480fc701710953edb`、ブランチは `m013/r40.2` である。開始時の作業差分はなかった。コミット・ブランチ・index を変える操作は行っていない。

## 表示と bounds

`types/mod.rs` の表示は、既に原子と値型の添字の suffix を保持し、`IO.All` への省略も Top の原子だけに限っていた。この共通表現は変更していない。既存の公開型表示のテストと今回の CLI の表で、宣言上限と本体の推論を取り違えないことを確かめる。

`cli/inspection.rs` に、検査済みの宣言上限を所有する `EffectSummary` を加えた。`FunctionContract` は名前の ID 集合を名前による照合に使い、範囲付きの原子を報告に使う。どちらも確定した Scheme から得る。本体が純粋でも宣言した上限を残す。通常・test・doc と集約は同じ直列化を使う。公開 API と型の共通表現は変更していないため、W-R への拡大条件に当たらない。

`effects.expanded` と `aggregateEffects.expanded` は、範囲を含まない名前の辞書順の集合のままである。範囲は任意欄 `bounds` へ加える。RV-R30.2 の参考は、expanded を範囲付き文字列へ置き換えず、bounds の役割を設計書に明記して閉じた。例えば次の形になる。

```json
{
  "basis": "declaredUpperBound",
  "expanded": ["File.Write", "Http.Connect"],
  "bounds": [
    {"name": "File.Write", "scope": {"kind": "pathTree", "path": "/data"}},
    {"name": "Http.Connect", "scope": {"kind": "endpoint", "host": {"kind": "cidr", "family": "v4", "address": "192.168.1.0", "prefixLength": 24}, "ports": {"minimum": 443, "maximum": 445}}}
  ]
}
```

DET-06 の構造を使う。Top は `all`、パスは `pathExact`・`pathTree`、接続先は `endpoint` と host・ports である。ホスト名は `exact`・`one`・`many` と name、IP は `exact`・`cidr` と family・address、CIDR だけ prefixLength を持つ。`/32`・`/128` は完全一致へ正規化される。木の path は幹であり、ホストの name はワイルドカードを含まない。endpoint は HTTP と HTTPS の両方を覆うホスト・ポートの上限であり、scheme や送信内容の契約ではない。

名前の重複は expanded で除く。bounds は構造上同じ原子だけをまとめ、被覆で原子を省かない。Top と同名の狭い原子を併記した契約も保持する。未知の対象は Top の要素であり、空配列にしない。この処理系は Effects を出すとき常に bounds を置き、契約の解析が未完了なら Effects 全体を null とする。受け手は bounds がない旧版などの Effects を expanded の各名前の全対象の上限として読む。純粋と確定した契約は空の expanded/bounds となるが、期待どおりに拒否された error の doc 例も契約を持たず同じ空を返す。この例の空は純粋を意味しない（R40.2b で説明を訂正）。通常形式1、test 形式1、doc 形式2と、報告の成功条件は維持した。

## 名前による照合と全読者

`effect_limit.rs` は既に名前の ID で照合しており、その意味をコメントに補った。名前一つは、その種類の Top と任意の狭い原子を許す全対象の上限である。範囲付きの CLI 引数は従来の正規名の解析で使い方の誤りになる。名前の不足は E0512・終了2、宣言の不足は E0501 のままである。

`tests/cli_process/scoped_reports.rs` の表は、純粋・Top・根の木・冗長原子・exact/one/many のホスト名・IPv4/IPv6 の完全一致・CIDR・処理済み Ask の11例を、通常・test・doc の報告へ通す。各例は単一 JSON、終了0、status/complete/executed、形式の版と独立した expanded/bounds の期待値を確かめる。純粋な本体に宣言上限を付け、推論した本体の効果へ置き換える退行を検出する。名前だけを実行へ渡す旧読者の照合も確かめた。処理済み Ask は bounds と名前の上限のどちらにも戻らない。複数入口の和、未完了時の null、範囲付き allow-effects の終了2も同じ CLI 境界で確認した。

File.Read 13・File.Write 16・Http.Connect 2 の全操作は、`scoped_diagnostics.rs` の一つの表で照合した。完全な3例と、各一節を欠く31例について、通常 check と test --check の個別 effects・aggregateEffects が独立の期待値に一致した。File は pathTree `/data`、Connect は endpoint `api.example:443` であり、完全に処理した後は空である。各一節の不足では同じ名前と範囲が残り、run/test とも名前の allow-effects で受理し、空指定では E0512・終了2となる。宣言上限を持つ純粋な protected 関数を保護本体に使い、実通信や全ファイル操作の実行まで確認したとは扱わない。

既存の任意欄を無視する厳密比較も保持し、名前の全上限と範囲の構造の検査を分けた。test/doc の集約は通常テストと test/run 例だけを含み、check/error 例を実行の上限へ加えない既存規則を保つ。

## 資源停止と診断

`builtins/funcs/file.rs` は、`readText`/`readTextIn` と `readBytes`/`readBytesIn` の開始処理で実際の報告名を渡す。worker の出力と完了処理、bytes の metadata による上限検査にも同じ名前を渡す。資源停止の主文は呼び出した入口の名前となる。

実 CLI の退行検査は、1 GiB+1 の sparse file を metadata の検査で停止させ、R0903・`Benitoite.IO.File.readBytesIn`・終了1を確認する。内容は読まない。`readTextIn` の停止名も共有処理へ接続したが、1 GiB超の内容を実際に読んで停止させる追加検査は行っていない。

E0407 は、拡大の行き先を確定できない場合だけ専用の help を使う。既に注釈がある場合にも、対応する検査済みの型 `Scope.PathIn`/`Http.RequestIn` と行き先の範囲を確認するよう案内する。両型で誤った戻り注釈の拒否と、正しい型へ直した後の受理を確認した。R40.1b の E0401 ScopeResult の expected/found の修正は開始版に含まれており、今回変更していない。

worker に追加したのは Rust の static な名前と元からの結果の組だけであり、言語の値・安全点を越える保持・ヒープの不変条件を変えていない。既存の完了関数を使うため、新たな heap/stress/Miri の割り当ては不要と判断した。

## 設計書・生成物・探査

設計書 02-10・06-01・06-04 に、正規表示、宣言上限と推論の区別、bounds の構造と互換、名前による照合、資源停止名と E0407 の案内を反映した。作業 ID は設計書へ書いていない。同梱 Skill の手書きの inspection・common-mistakes・SKILL.md も、名前の全対象の上限と任意 bounds の説明へそろえた。処理系を正とする既存の版固定の参照を保ち、今回の追加欄だけを説明した。通常の英語リファレンスと訳の最終整合は V10 の担当のままである。

`diag/codes.rs` の変更に伴い `cargo run -p benitoite --example gen_skill` で診断の生成物を作り直した。終了0、外側3.769744333秒であった（[記録](gen-skill.json)・[ログ](gen-skill.log)）。整形は終了0、外側2.862122625秒（[記録](format.json)）である。

計時探査は既存の公開 API のアダプタで足り、`tools/bench/compare/` の変更は不要である。README「自己検査」の次のコマンドを一度実行し、39件成功・終了0、外側102.451022417秒となった。

```sh
PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'
```

開始版 `6124775788579e60530f55fb85570f26ef7fa900` の既存 probe キャッシュを照合し、B_WORK は release と probe を初回ビルドした。両版の独立 IR・グラフ入力の検査も成功した。[ログ](compare-selftest.log) と [両版の API 判定・コマンド・ハッシュと記録](compare-selftest.json)を保存する。自己検査に含まれる擬似コンパイラの measured 表示は性能の標本採取ではなく、short 比較は行っていない。初回失敗はない。

## 検査と初回の失敗

[差分の自己確認](review.json) にファイルごとの SHA-256 と行数を記録した。本番は147行追加・70行削除、テストは520行追加・5行削除であり、生成物と手書きの Skill、設計書は別に計上した。新しいテスト5件と既存の表の補強を含む。

新しいテストは公開 test-audit の作成時の関門を通した。守るものは実 CLI の JSON・診断・終了・宣言上限の抽出と全読者の一致である。既存の型規則のテストだけでは、所有する報告へ範囲を写す際の消失、全操作の節不足から最終報告までの接続を守れない。実装を模倣する期待値や本番専用の差し込み口は加えていない。低価値のテストの削除は今回の対象ではなく、既存のテストの削除はない。

- bounds の修正前に、既存の CLI テストへ新しい欄の期待値を加え、欠落で失敗することを確認した（[修正前](report-bounds-before.log)・[修正後](report-bounds-after.log)）。
- Ask の表の入力は、import の順序による E0219、操作名を修飾したことによる E0304 を記録し、入力を直して成功した。本番規則は変えていない（[初回](report-report-matrix-user.log)・[次の試行](report-report-matrix-user-retry.log)・[成功](report-report-matrix-user-final.log)）。
- E0407 の注釈済み入力でも一般の help となる失敗と、readBytesIn の旧名による失敗を修正前に確認した。資源停止の終了状態を5と仮定した初回のテスト、test の進捗行と非実行時の要約を考慮しなかった二回の失敗も残した。テストの観察を既存の CLI 契約に合わせて修正している（[局所の実行記録](resource-diagnostics-local.json)）。
- 局所の報告3テストは最終9.20秒、診断の3テストは4.78秒、通常/test へ広げた全操作表は1テスト39.10秒で成功した。これらはテスト実行器の時間であり、外側の計時ではない。旧受け手の通常5件・test 1件も成功した（`report-*.log`）。

作業末の正確な指定は次のとおりである。基準は B_WORK に固定し、同じ引数に `--dry-run` を加えた実行は終了0、外側0.132571917秒であった。[選択と理由](work-dry-run.log)・[記録](work-dry-run.json)を残す。選択は fmt、clippy、既定 lib 全件、下記8統合対象、source_rules、skill_generated、spec_tally であり、Lean・依存の検査は選ばれていない。

```sh
scripts/check.sh --level work --base a2fd2b6abaaa6c11d0b8dcb480fc701710953edb --test cli_process --test test_command --test golden --test spec_examples --test reference_examples --test skill_docs --test package_command --test desugar_export
```

初回の W-40 は fmt に成功した後、clippy の `indexing_slicing` により終了1となった。IP の JSON へ `value["prefixLength"]` で代入していたためであり、CIDR と完全一致の JSON を分岐ごとに構築する形へ直した。形式・欄・判定の意味は変えていない。初回は外側9.289680709秒、`time -p` の real は9.31秒であり、[ログ](work-initial.log)・[終了と RSS の記録](work-initial.json)・[time の記録](work-initial-time.log)に残す。lib・統合はまだ実行されていなかったため、同じ W-40 の指定で必要な全選択を再実行した。

最初の修正後は、本番の clippy は通ったが、テストの JSON の再帰処理の `_` 分岐が `wildcard_enum_match_arm`、テスト名を作る `map_or` が `map_or_identity` に当たり、終了1となった。JSON の残る四種類を列挙し、`unwrap_or` へ直した。この回も lib・統合はまだ実行されていない。外側14.019662875秒、`time -p` の real は14.05秒である（[ログ](work-retry-1.log)・[記録](work-retry-1.json)・[time](work-retry-1-time.log)）。

[run-record.py](run-record.py) が check.sh を直接の子として起動して終了状態を取得し、この記録器を `/usr/bin/time -p` で包む。`time -l` は使わない。検査の出力と最大常駐量の補助値は、[work.log](work.log)・[work.json](work.json)・[work-time.log](work-time.log)へ保存した。

最終の W-40 は check.sh 自身の終了0、外側264.566912541秒（約4分25秒）、`time -p` の real は264.62秒であった。初回の2失敗を含む正式入口の実行時間は合計287.876256125秒である。dry-run から増えたファイルは結果のログなどであり、選択した検査と理由は同じである。

| 対象 | 成功 | 失敗 | ignored・補足 |
|---|---:|---:|---|
| 既定 lib 全件 | 1,392 | 0 | 22 |
| cli_process | 45 | 0 | 0 |
| desugar_export | 44 | 0 | 1。形式化の全書き出しは対象外 |
| golden | 2 | 0 | 0 |
| package_command | 16 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| skill_docs | 8 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |
| test_command | 52 | 0 | 0 |
| fmt・clippy | 終了0 | 0 | clippy は lib/tests/examples、no-default-features + gc-mark-sweep |
| source_rules・skill_generated・spec_tally | 終了0 | 0 | 規約・生成物・仕様集計 |

統合8対象は175件成功・1件 ignored、lib と合わせて1,567件成功・23件 ignored である。W-40 の各選択は最終状態で成功しており、既知の失敗を後の枝へ送っていない。

最大常駐量の補助値は 4,690,001,920 bytes = 4472.734375 MiB = 4.367905 GiB である。macOS の `getrusage(RUSAGE_CHILDREN)` による子孫プロセスの最大値であり、一括実行全体の常駐量の合計ではない。初回2回の値も各 JSON に残した。`/usr/bin/time -p` 自身は RSS を出さないため、この補助値と区別した。

## 範囲・申し送り・時間

報告形式の版、既存の受け手の成功条件、Lean の意味・規則・公開契約を変更していない。停止条件への該当はない。依存・scripts・formal は変更せず、`check-formal.sh`・`lake build`・short 比較を実行していない。外した構成・32ビットの実行を確認済みへ変えていない。

R40.3 は段の最終照合と S-40・独立レビューを、K10 は Rust/Lean の全比較を受け持つ。R40.1 からの E0521 の自然な上限到達例と案内の解消効果の未確認、atomFailure の理由の比較、RequestCheckError の Show を追加しない判断、V10 の通常文書・訳・候補の照合を引き継ぐ。今回の表示と bounds の実装は実行時の権限制御・実体の隔離・情報フロー制御を追加するものではない。

`private/`・`docs/todo/` と private を指すスキルは読んでいない。変更は許可された crates・設計書の3章・本ディレクトリに限る。新しい CARGO_TARGET_DIR は設定していない。探査の展開とビルドは既定の target 内を使い、target 外の一時のビルド・基準版の展開は作っていない。局所検査の一時ファイルと元の一時ログは削除済みである。保存するログは `<wt>`・`<home>`・`<tmp>` へ伏せている。

最初の時計取得は2026-10-29 09:53:14 UTCであり、それに先行する規約の読解を含めて開始は約09:51 UTCである。最終照合は2026-10-29T10:11:05.945306+00:00、取得時計間の外側は1071.9秒（約17.9分）、冒頭の読解を含めると約20分である。能動時間は厳密な計測を行っておらず、主担当で約15〜20分、分担を含む合算で約30〜40分の概算である。正式検査の待ちと探査の自己検査102.451秒、局所検査の時間は各記録に分けた。並行して実装・記録を進めたため、待ちと能動時間を単純に足した値を外側の時間とはしない。設計者の回答待ちはなく、見込みの上端2倍（10時間）の停止条件を超えていない。

最終照合では、[review.json](review.json) の全ソース・テスト・Skill・設計書の SHA-256 が作業末の検査の前後で一致し、HEAD・ブランチ・index の不変、`git diff --check` の終了0、ログの伏せ字、記録 JSON の構文を確認した。独立レビューと設計者の受け入れを、この自己確認で済んだことにはしていない。

## R40.2b: RV-R40.2 への対応

B_WORK と HEAD は引き続き `a2fd2b6abaaa6c11d0b8dcb480fc701710953edb`、ブランチは `m013/r40.2` である。R40.2 の未コミット差分を引き継ぎ、[レビュー](../reviews/RV-R40.2.md)の「対応（取りまとめ）」に従って中1・軽1〜軽3・参考1を対応した。開始時の入力は [r40.2b-start.json](r40.2b-start.json)に記録した。

| 項目 | 対応 |
|---|---|
| 中1（案 A） | 06-01・06-04・手書きの inspection.md に、期待どおりに拒否された error の doc 例は契約を持たず空の Effects を返し、純粋を意味しないことを明記した。契約を例の報告に保持する説明は check 例に限った。JSON の形と意味・版・集約規則を変更せず、null にしていない |
| 軽1 | 06-01 と inspection.md で、作り手は Effects に常に bounds を置き、契約解析が未完了なら Effects 全体を null にすること、受け手は bounds のない Effects の expanded を名前ごとの全対象の上限として読むことを分けた |
| 軽2 | diag::codes の E0407 の help を scope_widen_path / scope_widen_request に分け、pending.kind から選ぶ。PathIn の拡大には Scope.PathIn だけ、RequestIn の拡大には Http.RequestIn だけを案内する |
| 軽3 | scope_value の Range::Host は `internal("host-only scope in effect contract")` を返す。EffectSummary::value から通常・test・doc・集約の報告まで Result を伝播し、囲みのない Host の JSON を出さない。変更した補助関数は CLI 内部であり、公開 API・型の共通表現は変えていない |
| 参考1 | writeTextIn・appendTextIn・writeBytesIn・appendBytesIn と旧入口は start_write に実際の操作名を渡し、worker の出力に名前を保持して write_path_done → write_done → result_error へ渡す。テキストとバイト列の書込みを既存の write_bytes_job に揃え、4個の完了関数を1個にまとめた。worker へ新たに渡すのは static な Rust の名前だけで、言語の値を渡していない |

中1・軽3は [r40.2b-probes.py](r40.2b-probes.py)で変更しないレビュー入力を実 CLI に通した。[実行記録](r40.2b-probes.json)、[docerr の報告](r40.2b-docerr.json)、[h1 の報告](r40.2b-h1.json)を保存した。docerr は形式2、status ok、complete true、executed false、E0401 の期待一致で終了0となり、例の effects は次の形であった。aggregateEffects も空である。

```json
{"basis":"declaredUpperBound","expanded":[],"bounds":[]}
```

Host 単独の `Http.Connect["a.example"]` は E0520・終了2、main と aggregateEffects は null となった。コード上も function_contract が原子ごとに `indices_valid(0)` を必須にし、EffectName::indices_valid は名前の scope_kind と Range::fits_kind を照合する。BuiltinEffectId::scope_kind が許す非 Top は File.Read/Write の Path と Http.Connect の Endpoint だけであり、Host はこの経路で EffectSummary に入らない。今回の腕は、この不変条件が将来破れた場合にも未定義の JSON を返さないための防御である。

参考1の名前が表に出るのは失敗理由の文字列の確保も失敗した場合である。この二重失敗を大きな入力で強制する新しいテストは加えていない。4入口から worker・完了・result_error までの引数の接続を読み、既存の runtime_builtins と io_modes で書込み・追記・値・IO の誤り・方式の実行を確認する。共通処理の整理は小さく収まり、参考1を V10 へ残していない。

軽2は公開 test-audit の作成時の関門に従い、既存の CLI 診断テストの表に「他方の型を案内しない」という検査を追加した。独立して守る契約は E0407 の修正案であり、既存の「正しい型が含まれる」だけでは両型を並べる退行を捕まえられない。既存の2行と準備を共有し、本番の差し込み口や新しいテスト関数は加えていない。[修正前](r40.2b-help-before.log)は意図した両型の案内で失敗し、[修正後](r40.2b-help-after.log)は1件成功・44件除外、終了0、外側11.753925167秒だった。テストと本番コードの削除を目的とする監査は行っていない。

診断表と手書きの Skill の変更後に gen_skill を実行した。[生成の記録](r40.2b-gen-skill.json)は終了0、外側0.726446709秒であり、診断の生成物に2種類の help を反映した。[整形](r40.2b-format.json)は終了0、外側2.607842333秒だった。

### R40.2b の作業末の検査

[選択と理由](r40.2b-work-dry-run.log)・[dry-run の記録](r40.2b-work-dry-run.json)は終了0、外側0.110433417秒である。基準は B_WORK のまま、参考1で File の実行を変えたため runtime_builtins と io_modes を加えた。

```sh
scripts/check.sh --level work --base a2fd2b6abaaa6c11d0b8dcb480fc701710953edb --test cli_process --test test_command --test golden --test spec_examples --test reference_examples --test skill_docs --test package_command --test desugar_export --test runtime_builtins --test io_modes --dry-run
/usr/bin/time -p python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r40.2/run-record.py r40.2b-work scripts/check.sh --level work --base a2fd2b6abaaa6c11d0b8dcb480fc701710953edb --test cli_process --test test_command --test golden --test spec_examples --test reference_examples --test skill_docs --test package_command --test desugar_export --test runtime_builtins --test io_modes
```

選択は fmt、lib/tests/examples の clippy（no-default-features + gc-mark-sweep）、既定 lib 全件、上記10統合対象、source_rules、skill_generated、spec_tally の7項目である。既存の run-record.py が check.sh を直接の子として起動して終了状態と外側時間を記録し、その外側を time -p で包む。time -l は使わない。

[W-40 のログ](r40.2b-work.log)・[直接取得した終了と外側時間](r40.2b-work.json)・[time -p](r40.2b-work-time.log)を残した。実検査は一度だけ実行し、check.sh 自身の終了0、外側248.561222417秒（約4分9秒）だった。time -p の real/user/sys は248.58/1189.08/42.18秒である。

| 対象 | 成功 | 失敗 | ignored |
|---|---:|---:|---:|
| 既定 lib 全件 | 1,392 | 0 | 22 |
| cli_process | 45 | 0 | 0 |
| desugar_export | 44 | 0 | 1 |
| golden | 2 | 0 | 0 |
| io_modes | 13 | 0 | 0 |
| package_command | 16 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| runtime_builtins | 29 | 0 | 0 |
| skill_docs | 8 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |
| test_command | 52 | 0 | 0 |

統合10対象は217件成功・1件 ignored、lib と合わせて1,609件成功・23件 ignored、失敗0件である。fmt・clippy・source_rules・skill_generated・spec_tally もすべて成功した。desugar_export の ignored 1件は形式化の全書き出しであり、今回の実行対象外である。

最大常駐量の補助値は 3,598,893,056 bytes = 3432.171875 MiB = 3.351730 GiB である。macOS の getrusage(RUSAGE_CHILDREN) による子孫の最大値であり、同時に常駐した全プロセスの合計ではない。time -p の外側時間と区別する。

### R40.2b の失敗・申し送り・範囲

意図した修正前の失敗のほか、文書の編集用 Python は初回に標準入力の UTF-8 指定不足で書込み前に停止し、coding 指定を加えて実行した。局所照合の初回は main を report 直下にあると誤認して KeyError となった。処理系は既に E0520 を返しており、検査側を targets[0].main に直して成功した。これらを処理系の失敗や W-40 の失敗とは数えない。

参考2は R40.3 への申し送りである。06-06 のハーネスが読む欄（レビュー時の133行・143行）に、今回の bounds の構造・宣言上限・欠落時の保守的な読み方をそろえる。R40.3 の段の照合・独立レビュー、K10 の全比較、V10 の通常文書・訳の最終整合は従前どおり取りまとめが割り当てる。

報告形式の版・既存受け手の意味と成功条件・Lean の規則・公開契約を変えておらず、停止条件への該当はない。lake build・check-formal.sh・short は実行していない。private/・docs/todo/ と private を指すスキルは読んでいない。新しい CARGO_TARGET_DIR、target 外の一時ビルドや基準版の展開は作っていない。変更範囲は指定された crates・06-01/06-04・r40.2/ に限る。

[最終照合](r40.2b-verification.json)と[照合のスクリプト](r40.2b-verify.py)に、検査対象20ファイルのハッシュ不変、レビュー本文・rv-probes の18ファイル不変、HEAD・ブランチ・index 不変、範囲外の変更なし、git diff --check の終了0を記録した。今回の本番コードの行数は開始時の R40.2 の差分から差引き38行減、テストは6行増である。新しいテスト関数は0件、既存の表の補強1件である。ログの絶対パスはプレースホルダへ置き換えた。検査後の編集は結果と補助記録だけで、検査対象の実装・文書・生成物を変えていない。公開 API・比較器は変えておらず、R40.2 の探査の自己検査は繰り返していない。

開始は2026-10-29 19:19:32 JST、完了は同日19:28 JST頃であり、外側の所要は約9分である。能動時間は厳密な分離計時をしておらず約5分、主な検査待ちは W-40 の約4分9秒で、局所検査・記録と一部重なる。設計者の回答待ちはない。見込み30分〜1時間と2時間で停止する条件を変更しておらず、停止条件への該当はない。独立した再レビューと受け入れ・取り込みは取りまとめへ渡す。

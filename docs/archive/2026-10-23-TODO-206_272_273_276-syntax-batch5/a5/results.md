# 作業 A5 の結果

2026-10-23、A5実装担当。基準B_WORKとHEADは、ともに`5b616f66ac2b39cdab9eeee2a0298478471713f0`、ブランチは`mod011/A5`である。開始時の差分はなかった。gitの変更操作、private・その参照リンクの読み取り、docs/todoの操作は行っていない。

## 実行と終了状態

コマンドの作業ディレクトリはリポジトリの根である。表の`B_WORK`は上記の完全IDを表す。実行時には完全IDを渡した。時間は外側の計測値であり、局所試行で計測していないものは不明と記した。

| コマンド | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `rtk cargo build -p benitoite --bin benitoite --example derive_inventory`（変更前・変更後の2回） | 各0。変更後のinventoryを自己検査に使用 | 個別の全体時間は不明。Cargo表示は3.27秒・0.68秒 |
| `python3 -B tools/derive/test_derive.py FileEffects`（作成途中の5回） | 各1。下記の局所試行の修正を参照 | 個別の全体時間は不明。unittest表示は0.241〜4.070秒 |
| `python3 -B tools/derive/test_derive.py FileEffects Management.test_batch4_record_requires_new_review_and_protects_old_body` | 0、5件成功 | 個別の全体時間は不明。unittest表示5.997秒 |
| 下記の同梱例のpreview | 0、旧記録を含む新manifestを作成。ソース編集は両ファイルとも0件 | 約0.26秒（Manager呼出しの外側） |
| 下記の同梱例のapply、check、再適用 | 各0。ソース編集0件、記録一致、receiptの検証による再適用成功 | 3コマンド合計約0.95秒 |
| `/usr/bin/time -p python3 -B tools/derive/test_derive.py` | 0、47件成功 | 71.54秒 |
| `scripts/check.sh --level work --base B_WORK --test declarations --test property_library --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftestsを選択 | 約0.1秒未満 |
| `/usr/bin/time -p scripts/check.sh --level work --base B_WORK --test declarations --test property_library` | 1。fmt・lint_default成功、libは1263件成功・21件ignore。declarationsは16件成功・1件失敗で停止 | 98.05秒 |
| `scripts/check.sh --level work --base B_WORK --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations --test property_library --dry-run` | 0。成功済みのlib以外を名指し | 約0.1秒未満 |
| `/usr/bin/time -p scripts/check.sh --level work --base B_WORK --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations --test property_library` | 0。declarationsは17件成功、property_libraryは15件成功・2件ignore。fmt・clippy・規約・Skill生成物・仕様集計・Python構文・移行器自己検査も成功。source-migrateとtry-actionsは各6件成功 | 20.92秒 |
| 文書4件の相対リンク、フェンス、末尾空白を読むPythonの静的確認 | 初回1、修正後0。初回はコード内の関数型をリンクと誤認したため、確認用スクリプトでフェンスとインラインコードを除いた。文書の不備ではない。104相対リンクの参照先を確認 | 修正後約0.003秒 |
| `rtk git diff --check` | 0 | 約0.1秒未満 |

仕様集計が表示する「テスト参照のない節」は集計の報告であり、未記入の初回リリース受け入れ条件は0件、検査は終了0である。既存のignore指定、期待する診断、テストの大きさと制限は緩めていない。

## 失敗と修正

局所試行の最初は、importされるファイルに置けない`language`を準備に含めていたためE0909になった。これを除いた後、変更前の実装がファイルusesを暫定防御で拒否することを確認した。実装途中にはPythonの検証ラッパーからrootを渡していない箇所を修正した。また、固定期待値を既存の正規名`Log.Log`に合わせ、Propertyの準備に必要なRandomのimportとmainを加えた。生成コードの純粋さ違反は、通常CLIの既存の終了2・E0401で確認する。ファイルのusesを除いた同じ生成コードは通常checkに成功する。

初回workの失敗は、`crates/benitoite/tests/declarations.rs`の`inventory_json_preserves_resolved_types_order_spans_and_input_hashes`がinventory版2を期待していたためである。版3の契約に合わせてこの1行だけを更新した。作成時の関門では、既存の外部JSON契約のテストの更新として扱い、同じ内容のRustテストは追加していない。古くなったfmt・lintと関連統合テスト、停止で未実行だった単位だけを再実行した。

## 同梱例の再生成

`tools/derive/examples`のManagerで新previewを作り、旧記録がinventory2・生成器`3.0.0-syntax-batch4`、新記録がinventory3・生成器`3.1.0-syntax-batch5`であることと、両ソースの編集が空であることを確認した。manifestは次の場所へ作成した。

`/private/var/folders/by/gjbhttdj721blp8kyvstknh40000gn/T/benitoite-a5-example-review-_w9ay7x9/manifest.json`

確認済みSHA-256は`9ec33c8b91dd1249426a1a8e147a4f4a6a188d616284f32f1b2445e622127031`である。次を順に実行した。

```sh
python3 -B tools/derive/derive.py apply --root tools/derive/examples --config tools/derive/examples/derive.json --manifest /private/var/folders/by/gjbhttdj721blp8kyvstknh40000gn/T/benitoite-a5-example-review-_w9ay7x9/manifest.json --manifest-sha256 9ec33c8b91dd1249426a1a8e147a4f4a6a188d616284f32f1b2445e622127031
python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json
python3 -B tools/derive/derive.py apply --root tools/derive/examples --config tools/derive/examples/derive.json --manifest /private/var/folders/by/gjbhttdj721blp8kyvstknh40000gn/T/benitoite-a5-example-review-_w9ay7x9/manifest.json --manifest-sha256 9ec33c8b91dd1249426a1a8e147a4f4a6a188d616284f32f1b2445e622127031
```

記録と管理領域のハッシュは手で変更していない。新版の生成結果が同じため、`People.bnt`と`Address.bnt`には差分が残らず、`derive.generated.json`だけが更新された。両ソースが基準と同一であることも確認した。SHA-256はPeopleが`88aa1cf97c4e2a12da4c3206af49e8e39ae99c08c1cc7dc338c06f194b74fb90`、Addressが`b003b5e8c5a4855a1dbe4a91f3d22d64e4365fd67bfc8a7b206ea8ca3a4837ed`である。

## 成功済みlibの結果の使用

初回work内の`cargo test -p benitoite --lib`の成功を使用し、同じlib全件は繰り返していない。元の結果は本書「実行と終了状態」の初回work行であり、1263成功・0失敗・21ignore・0filter、lib単独の表示時間83.32秒、work全体98.05秒である。基準とHEADは冒頭の完全ID、構成は計画のlib_default（既定機能）である。

実行環境はDarwin arm64、rustc `1.98.1 (48a229cea 2026-09-01)`、cargo `1.98.1 (797e8a9bc 2026-08-05)`、Python `3.9.6`である。必要な道具は利用でき、A5の割り当てに環境による未実施はない。入力は当該差分を含む作業ツリー、通常のCargo入力、libのソース・埋め込み標準ソース・テスト入力である。

初回workの未コミット差分の一覧は次の11件で、未追跡の検査入力はなかった。

```text
crates/benitoite/examples/derive_inventory.rs
crates/benitoite/examples/derive_inventory/README.md
crates/benitoite/examples/derive_inventory/mod.rs
crates/benitoite/examples/derive_inventory/schema.rs
crates/benitoite/examples/derive_inventory/text.rs
docs/design/03-interop/03-06-stdlib.md
docs/design/07-quality/07-04-formal-semantics.md
tools/derive/README.md
tools/derive/derive.py
tools/derive/examples/derive.generated.json
tools/derive/test_derive.py
```

この状態の`git diff --binary`のSHA-256は`418acca2148cc1a6838a01eea88223626ad5d722536daaf2063273aa42b0e467`である。後に変更したのは、declarationsの版の期待値1行、deriveのREADMEの案内1文、本結果記録だけである。declarationsの修正直後に同ファイルを除いた差分から初回状態のハッシュを求めた。READMEの修正と本結果記録も検査するコードや入力を変えず、libの関係状態が同一であるため引用できるとA5実装担当が2026-10-23に判断した。修正後の全追跡済み差分のSHA-256は`81af1f23ed8c820b99d4e7404ad1d54ba81ce1b47943e78bf460e78e00dbabe9`であり、本結果記録は検査入力に含まれない。

## 計画からのずれと申し送り

- A5の関連する検証入力として、対象ファイルの列挙外だった`tests/declarations.rs`の版の期待値1行も変更した。既存の検査対象には含まれている。初回work失敗のため、計画どおりの一回に、古くなった検査と未実行の検査だけの再実行が加わった。
- inventory3は`fileUses`と`importInsertLimit`を必須とし、元UTF-8の範囲・元文字列・preambleEnd・importとの順序をPythonで検証する。署名はA2の合併済みSchemeを維持した。旧manifestの無確認適用は拒否し、旧記録は本文ハッシュを保護した新previewでのみ再確認する。生成記録・manifest/receipt版3と意味ハッシュ算法版3は維持した。
- importと生成宣言を一領域へ置く既存の方式では、ファイルusesをまたぐ新規配置ができない。計画にある理由付き拒否を採用した。新しいimportが必要なら、示したimportを既存importの後・ファイルusesの前へ手書きして再previewする。usesの後の既存領域にimportを足さず、usesの前の既存領域に通常宣言を生成することも拒否する。手書き部分の自動移動はしていない。
- LF/CRLF・日本語コメント・importなし・既存領域の前後・既存別名の再利用、追加後のJSON/Propertyカスタム関数の純粋さ、生成トップレベル関数の通常checkでの拒否、batch4記録からの移行と改変本文の保護を自己検査で確認した。新規テストは5件と既存の表の行追加である。本番コードは49行追加・16行削除、テストは170行追加・9行削除で、テストの削除はない。
- 03-06・07-04と両READMEを実装に合わせた。言語規則、Leanの定理・仮定・公理、処理系本体、Cargoの依存は変更していない。未解決の設計判断はない。A5はexamples/toolsだけの変更なので、計画どおり性能shortは対象外である。
- 独立レビューと段S-Aの接続検査は取りまとめ担当がA6後に行う。本担当は段・改造全体・公開候補の検査、コミット、取り込み、公開を先取りしていない。

## セッション再開時の照合と完了確認

2026-10-23、A5実装担当が前セッションの差分と本記録を読み、plan.mdの作業A5・前提と依存・内部の契約・work A5、decisions.mdのD18・D32・D33・D39、指定のstudyとpreflightを照合した。再開後に実装・テスト・生成物・設計書を変更する必要は見つからず、本記録だけを追記した。A5の実装と割り当てられた検査は完了している。

再開時の基準とHEADはともに`5b616f66ac2b39cdab9eeee2a0298478471713f0`、ブランチは`mod011/A5`である。`git diff --binary`のSHA-256は`81af1f23ed8c820b99d4e7404ad1d54ba81ce1b47943e78bf460e78e00dbabe9`で、本書に保存した最後の検査後の差分と完全に一致した。追跡済みの差分は次の12件である。

```text
crates/benitoite/examples/derive_inventory.rs
crates/benitoite/examples/derive_inventory/README.md
crates/benitoite/examples/derive_inventory/mod.rs
crates/benitoite/examples/derive_inventory/schema.rs
crates/benitoite/examples/derive_inventory/text.rs
crates/benitoite/tests/declarations.rs
docs/design/03-interop/03-06-stdlib.md
docs/design/07-quality/07-04-formal-semantics.md
tools/derive/README.md
tools/derive/derive.py
tools/derive/examples/derive.generated.json
tools/derive/test_derive.py
```

未追跡のファイルは本記録だけであり、未追跡の検査入力はない。追記前の本記録のSHA-256は`1c6bb9e41007c6d17c6c3a2f40fcce20b2d74ac0104f3a8f4573248cf239fa3d`である。rustc・cargo・Pythonの版も上記の実行環境と一致した。同梱のPeople.bntとAddress.bntは基準の内容および本書に保存したSHA-256と一致し、生成記録だけが更新されている。

引用元は本書「実行と終了状態」「同梱例の再生成」「成功済みlibの結果の使用」である。derive自己検査47件、work内のlib1263件、修正後のdeclarations17件・property_library15件（2件ignore）と残る検査単位の終了0を使用する。コマンド・構成・件数・終了状態・時間・失敗と修正は各節のとおりである。関係するソース、テスト、入力・期待値、Cargo設定、生成元・生成物、設定、検査道具への追加変更がなく、再開時の差分全体が保存済みの最終状態と一致するため、検査結果は古くなっていない。再開後に変えた本記録は検査入力ではない。依頼の「済んだ検査は、その後に変えたファイルがなければやり直さなくてよい」に従い、同じビルド・自己検査・workは再実行しないとA5実装担当が2026-10-23に判断した。

| A5の完了条件 | 差分と既存の成功記録で確認した内容 |
|---|---|
| inventoryと有効な契約 | inventory3のfileUses/importInsertLimitを必須化し、元UTF-8の文字列・範囲・preambleEnd・importの順序を検証する。署名はA2の合併済みSchemeを使用し、derive入口の暫定防御を除去した |
| importの挿入境界 | LF/CRLF、日本語コメント、importなし、新規領域とuses前後の既存領域を対照にする。importと通常宣言を一領域へ置けない場合は、必要なimportと手動準備の案内を示して書き込み前に拒否する |
| 純粋さ | カスタムJSON/Property関数のファイル効果を有効な署名で検出する。生成されたProperty関数は通常CLIでE0401となり、ファイルの宣言を除いた対照は成功する |
| 旧版と本文の保護 | 旧manifestのapplyと旧記録のcheckを拒否する。旧本文のハッシュ検証、新preview、確認済みハッシュでのapply、check、再適用、本文改変時の拒否を確認した |
| 同梱物と文書 | 同梱例の新preview→確認済みハッシュでapply→check→再適用を完了し、生成記録だけを更新した。03-06・07-04と両READMEも現在の契約に一致する |

再開後の軽量な確認は次のとおりである。これらは成功済みの機能検査の再実行ではない。

| コマンド・確認 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `git diff --binary`をPythonの`hashlib.sha256`で照合、`git rev-parse HEAD`・`git branch --show-current`・`git ls-files --others --exclude-standard`、両同梱ソースを`git show B_WORK:<path>`とバイト比較 | 0。上記の状態とハッシュに一致 | 約0.1秒未満 |
| `rtk git diff --check` | 0 | 約0.1秒未満 |
| `rtk proxy python3 -B -`による文書4件の相対リンク・フェンス・末尾空白の静的確認 | 0。フェンスとインラインコードを除いて104相対リンクの参照先を確認 | 0.003秒 |

再開後もgitの変更操作、privateとその参照リンクの読み取り、docs/todoの操作は行っていない。未解決の設計判断、A5担当の未実施検査はない。独立レビューとA6後の段S-Aの接続検査は、計画どおり取りまとめへ渡す。

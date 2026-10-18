# 0.0.8 の改造の結果

## 段1の実装と適用の状態

2026-10-17、TODO-255のW1・W2a・W2bに続いてW3で規約・現行設計・共通依頼文と計画の雛形をそろえた。実装開始版は `1294ba9706e17ce3b6613bbe6040924d740a4648`、W3の基準HEADは `7820f7a412d847c78669cec162c69fb532809ed3` である。対象の差分と入力のハッシュは [W3](w3/results.md) に記録する。

| 作業 | 結果の参照先 | 確認した契約と範囲 |
|---|---|---|
| W1 | [w1/results.md](w1/results.md) | 長い対象の一覧・実行器と旧指定の固定記録。実Cargoの四構成の列挙との一致。本体は実行していない |
| W2a | [w2a/results.md](w2a/results.md) | 引数・work/stage・引数なしの切り替え、停止3と誤指定2、旧集合の保持、Skill生成の失敗伝播 |
| W2b | [w2b/results.md](w2b/results.md) | change/release・包含・条件付き検査・実行器への接続。自己検査18件成功。cargo・lake・check-heapは代用 |
| W3 | [w3/results.md](w3/results.md) | 規約・文書・依頼文・雛形と道具の接続。検査と段末のdry-runを同記録へ残す |

コードの既定はworkへ切り替わっているが、一般の作業への新方針の適用はR1のOpusレビューと指摘修正の完了後である。段1の作業はplan.mdの名指しで確認する。R1は未実施であり、段1を閉じたことや0.0.8の受け入れを完了したことにはしない。コミット・取り込みはオーケストレータが行う。

## 段1の検査の引用と後の担当

W3のpolicy_selftestは18件成功し、道具と規約をつないだ最終の関係状態を確認した（終了0、外側13.941秒）。段末のstageが求める同じ接続はW3から引用し、同じpolicy_selftestを再実行しない。実Cargoの四構成の列挙はW1から引用する。対象・一覧・実行器・構成が不変である根拠はW3に残す。レビュー修正が入力を変えたら、古くなった自己検査・列挙・文書照合だけをやり直す。

| 後に必要な確認 | 担当・時期・引用の条件 |
|---|---|
| R1のレビューと指摘修正 | オーケストレータ。完了と一般への切り替えを本記録へ追記する |
| 189・249・191のLeanの定義・証明・写し・レビュー | 段2。既定lake buildがsorryなしで通り、定義・言明・仮定のレビューを終えてからRustへ進む |
| RustとLeanの新しい接続・六入口と独立入力の全比較 | 段3〜5の詳しい計画で名指しし、段5末を土台とする。Lean先行だけの結果で接続済みとはしない |
| 局所のheap-verify・gc-stressと必要なcheck-heap | 不変条件・安全点を越える値を変える作業。次の作業の前提にする前に通す |
| 改造全体のchange、全件の特殊構成・長い対象 | 段7の取りまとめ。段1の道具の自己検査で代用しない |
| 必要なheap/formalの最終の関係状態への成功 | 段7で実行または条件付きの引用。関係入力の変更があれば再検査する |
| 実際の候補のrelease・版・CLI・同梱物・生成物・移行案内・配布の照合 | 段7の公開担当。release_stackと手動の証拠照合を分けて記録し、タグ・公開は別の明示指示に従う |

段1で成功したのは検査方針を実行する道具の契約である。実際の長いテスト・スタック対象・Miri・形式化全比較・改造全体の回帰の成功と読み替えない。W1〜W2bの初回の失敗と修正は各作業の結果に保持し、段1だけから削減率や検出漏れの確率を推定しない。


## 段1末のdry-runの照合

共通指定は `--base 1294ba9706e17ce3b6613bbe6040924d740a4648 --dry-run` である。

| 追加する指定 | 選んだ検査 | 終了状態・観察 |
|---|---|---|
| 指定なし | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level work | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level work --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level stage --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level stage | なし | 2。指定の誤り。設計者への質問なし |
| --level change | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level change --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level release | release_stack | 0。手動の候補照合を要求 |
| --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --only rust | rust | 0。停止なし。検査本体は非実行 |
| --full | default_lib・licenses・long・python・reference_examples・release_stack・rust・skill・skill_eval・spec_coverage・spec_examples | 0。停止なし。検査本体は非実行 |

全11件がplan.mdの期待表に一致した（合計0.233秒）。自動work/changeの終了3は計画した停止の観察であり、実行する検査は既に名指し済みのため追加の選択を求めていない。旧fullと旧rustは表示だけで、実検査を走らせていない。段末のstageの接続はW3の自己検査から引用し、再実行しない。引用の判断者はCodex、日付は2026-10-17。W3以後に自己検査の入力を変更しておらず、baseは名指しのstageでは表示にのみ使う。R1のレビューはこの成功とは別に未実施である。

## W3の文書と差分の確認

変更した文書12ファイルのローカルリンク140件・見出し・表56個・末尾改行・行末空白、実装の各水準の許可名と07-03の表を照合し、すべて一致した。三つのシェルの実行部分、07-03・07-04の既存の章見出し、W1の列挙に関係する実装・設定・一覧・実行器は不変である。git diff --checkも成功した。新たな失敗や計画からのずれはなく、結果記録の追記だけで自己検査を再実行していない。


## 段2の閉鎖（2026-10-18、O1の先行作業）

基準はRV2-final取り込みの8604e358d68e9f19897903afeb5c5b3635a97c18である。RV2-finalの重1・中1・軽1〜6を反映した。設計者のDictionaryScopedの前提強化の了承とAdmissibleの前提の意味の変化はR71に記録し、07-04・R63の説明をそろえた。F1・P1とO2/F3の計画を具体化した。

既定のformal/での`lake build`は終了0（外側76.72秒）。native_decideの三例はdecideへの置換を経てrflへ改めた。最初のビルド中の変更で古くなった二ファイルを含む既定の`lake build`を再実行し、終了0（外側4.73秒）。三例の期待値は不変であり、公理・sorry・Builtins.Assumptionsを追加していない。実際の表の`satB S [] t {} = true`はrflで証明した。独立レビューRV2-finalとこの修正・ビルドにより段2を閉じ、O1のRustへ進む。全比較は再実行せず、段2の新しいRustの接続の証拠とも扱わない。


## 段3のO1の完了（2026-10-18）

段2を閉じた後、制約付き操作の辞書を型検査・脱糖・独立IR検査・低位IR・コード生成・VMと参照実行器へ接続した。結果は [o1/results.md](o1/results.md)。作業末のworkを一度実行し、追加修正と検査構成の混在で古くなった対象を更新した。最終状態のlib 1201件、統合36ターゲット、release_stack 10件、vm_handlersの局所heap/stressはすべて成功した。判断とずれはR71〜R75に記録した。段3全体の閉鎖はO2の交換11/4と局所比較へ残し、O1の成功で代用しない。コミットとdocs/todoの変更は行っていない。


## 段3〜5の接続の閉鎖（2026-10-18、P1）

基準はF3・RV3取り込み後の04e82f6f8d7510b0aca968c4573fee0e249cd62eである。RV3中1・軽1・軽2を直し、文字の全域判定・反例・束縛・既定分岐をRustへ接続した。結果と失敗の修正は [p1/results.md](p1/results.md)、移行の分類は [p1/migration.md](p1/migration.md)、判断はR86〜R90に記した。

workのリファレンス例の不備を修正し、失敗した対象と未実行の残りだけを再開した。最終的にlib1,208件・全36統合ターゲット・fmt・規約・生成Skill・仕様集計・sorryなしのLeanビルド・全targetのclippyが成功した。独立のcheck-formal.sh全体は一度実行して終了0（972.693秒）。通常10,020件・view付き10,028件の網羅性は不一致・燃料切れとも0件で、L4bの文字の既知差を解消した。脱糖73,761定義、組み込みの効果要約72,736比較、プログラム内22,456照合、表層51,658件と既存の対象外19件・Q11の1件、全1,770入力の固定記録が一致した。六入口の独立入力と辞書・Fail・文字の実ソースも成功した。

件数・ログと関係状態のSHA-256はp1/formal-summary.json・p1/formal.log・p1/relation-state.jsonに残す。これは同じ作業ツリーで新たに実行した結果であり、段2の旧Rustの全比較を新機能の証拠へ引用したものではない。G2以降の標準宣言・生成例・版の変更後には、V1の最終関係状態の全比較を別に判断する。Integerの全域判定、項目の閉鎖、コミット、docs/todoの変更は行っていない。RV4と公開前の検査は後続へ残す。

## 段7のV1の実装範囲の完了（2026-10-18）

Z2取り込みの443e1faff532a66352986150d3f36e8e72be3319を基準に、依頼された版の更新・文書・訳・生成物の照合を終えた。詳細と各コマンドの記録は [v1/results.md](v1/results.md) に置いた。Cargoと言語宣言を0.0.8へそろえ、Characterの移行案内をE0908へ追加し、CHANGELOGと英語の文書・日本語訳を更新した。別ワークスペースのfuzzの古いlockも、根と共通の依存の版をそろえて更新した（R106）。

workは一度だけ実行した。途中でZ2の共通入力のCharacterの定義の件数の更新漏れ（R107）と、版の変更に伴うpackage_commandの固定ハッシュの更新漏れ（R108）を直し、失敗・未実行の対象だけを続けた。最終状態でlib1209件、全38統合ターゲットの通常267件、all-targetsのclippy、fmt、ソース規約、仕様集計、deriveの23自己検査と管理領域・生成記録のcheckが成功した。Skillの再生成と同梱物・生成物・例の68ファイルのSHA-256が一致し、英語と訳のコード・期待出力等のブロックも一致した。既存のassertを削らず、ignoreを追加していない。

今回の担当と検査の割り当てはR105とplanのwork V1行に記した。change・最終のcheck-formalと全件manifest・性能の本測定・releaseと実候補のCLI/配布の照合・RV5は、V1の取り込み後に取りまとめ担当が行う。全件manifestのbatch2Characterの定義件数2も、追加された二関数を含めて4へ照合する必要がある。これらは未実施であり、V1の実装担当の検査の成功を公開候補全体の受け入れと読み替えない。formal/・docs/todoの変更、コミット・タグ・push・保管は行っていない。

## 段7の取りまとめ: change・全比較・本測定・release と候補の照合（2026-10-18）

取りまとめ担当（Claude）が、V1 取り込みの後に次を順に行った。基準 A は計画で固定した `0027a22c171269cf5e5d975ee86bfd568efebb49` である。生のログは一時の作業領域に置いたので、件数と終了状態をここに写す。

| 検査 | HEAD | コマンド | 終了状態 | 外側の時間 |
|---|---|---|---|---:|
| change | `79e32e13` | plan の名指しの `scripts/check.sh --level change --base "$A" --only fmt,lint_default,lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,skill_eval_selftest,licenses,policy_selftest,long_only,heap_checks,formal_build` | 0 | 71 分 |
| check-formal（1 回目） | `79e32e13` | `scripts/check-formal.sh` | 1。全比較は一致。固定記録 `exchange-manifest.json` の batch2Character の定義の件数が Z2 の二関数を数えていなかった（2→4） | 約 13 分 |
| check-formal（2 回目） | `1c545d8f`（上の直し） | 同上 | 1。全比較は一致。`routing-manifest.json` と `exchange-manifest.json` の p1-character-domain.bnt の項目（定義 2→4、照合 1→3）と集計（定義 73,761→73,763、表層の検査 51,678→51,680、網羅性の照合 22,456→22,458、脱糖 983→985、表層の一致 51,658→51,660）が古かった | 約 13 分 |
| check-formal（3 回目） | `2afe2d46`（上の直し） | 同上 | 0 | 16 分 |
| release | `2afe2d46` | `scripts/check.sh --level release --base "$A"`（dry-run で release_stack だけを確認してから実行） | 0。release_stack 10 件成功 | 1 分 |

3 回目の全比較の件数: 網羅性 10,020 件・view 付き 10,028 件の不一致と燃料切れ 0。脱糖は golden 355 プログラム・985 関数、生成 1,000 プログラム・72,778 関数で不一致 0。組み込みの検査は 1,355 入力・98,801 項目。プログラム内の網羅性 22,458 照合で不一致 0。表層 51,660 件一致（既存の対象外 19 件・Q11 の 1 件）。全 1,770 入力の固定記録と六入口の名前付きの書き出しが一致した。1・2 回目の失敗は固定記録の数え漏れだけである。比較の範囲を縮めず、実際の出力の件数へ合わせた。


### 候補への引用（07-03「結果の保存と引用」）

change と V1 の結果は、候補 `2afe2d46` へ次の条件で引用する。判断者は取りまとめ担当（Claude）、日付は 2026-10-18 である。RV5 が差分と読み手を独立に確かめた。

| 欄 | change | V1 |
|---|---|---|
| 走らせた HEAD | `79e32e13`（V1 の取り込み） | `a20715fa`（V1 の作業の HEAD、`79e32e13` で取り込み） |
| 候補との差分 | `git diff --stat 79e32e13 2afe2d46` は 10 ファイル。`exchange-manifest.json`・`routing-manifest.json` の期待の数と、性能の記録（`tools/bench/results/` の .md・.html・profiles） | change の差分と同じ。V1 の後に変えたのは、全比較の固定記録・性能の記録・本記録だけ |
| 影響しない理由 | 二つの manifest を読むのは `check-formal.sh` の `check_named.py` だけであり、change が選ぶ検査はどれも読まない。性能の記録は検査の入力ではない。候補でビルドした実行ファイルは処理系のソースが同じである | 版・文書・訳・同梱物・生成物の入力は変えていない。gen_skill の作り直しは候補のソースでも差分なしだった |
| 入力・構成 | plan の名指しの集合（上の表）。既定と heap の構成、stress、Miri（mark-sweep）、long_only の二構成 | v1/results.md の work と補完の検査 |
| 件数 | test_default_all 2,683 成功・49 ignored、test_heap_all 2,697 成功・49 ignored、test_stress 1,482 成功・28 ignored、doc_default 34 成功・1 ignored、long_only 26 件成功を二構成、Miri 52 件・Miri per-object 46 件・heap random 45 件成功。失敗 0 | lib 1,209 件、統合 38 ターゲットの 267 件成功。失敗 0 |
| 元の記録 | 一時の作業領域の change.log（726,961 bytes。リポジトリには入れない） | v1/results.md と同じディレクトリの JSON・ログ |
| 未コミットの差分 | なし（各回とも作業ツリーは clean） | なし |

### 性能の本測定

benchmark スキルに従い、設計者が並行の作業を止めた後、電源につないで測った（76 分）。記録は [tools/bench/results/2026-10-18-1c545d8f5c5d.md](../../../tools/bench/results/2026-10-18-1c545d8f5c5d.md)（コミット `7b0433fb`）。trait・handler-tail と 1 万関数の check の CPU プロファイル、0.0.7 との比較を含む。

- 0.0.7 と交互に測った 11 の対象（fib・loop・追加の 7 本・二つの check）の時間の差は、すべて ±1.3 % 以内だった。確保の数と命令の数は 14 本で一致した。0.0.8 の型検査の費用（RV4 観察1、TODO-257）が出る制約の多い入力は、測定の対象に入っていない。
- 1 万関数の check は、関数の数を倍にするごとに 3.2・3.6・3.9 倍になり、二乗に近づく。0.0.7 も交互の測定で同じ時間であり、0.0.8 で生じたものではない。docs/todo の TODO-032 に書き足した。

### 候補の手動の照合

候補は `2afe2d46`（未コミットの差分なし）である。`cargo build --release -p benitoite` で作った実行ファイルの `--version=json` は、版 0.0.8、commit `2afe2d46…`、dirty は未収集、target aarch64-apple-darwin を示した。formats は 0.0.7 と同じ版 1 の 9 種類である。

| 照合 | 結果 |
|---|---|
| language の宣言 | 0.0.8 を受理した。0.0.7 は E0908 で、0.0.8 の文字の移行案内が出た（0.0.5 では注記 3 件）。0.0.9 は E0907、`"zz"` は E0905 |
| 型付き Fail | リファレンスの二例が期待どおりに出力した（`3`、`failed at 2`）。main と @test の未処理の Fail は check・test --check・test のどれでも E0506 になった |
| 許可の名前 | `--allow-effects=Console.Write` で実行できた。空の指定は E0512（終了 2）。`Failure.Fail` を書くと、許可の名前として誤りになった |
| 検査の報告 | `check --report=json` の形は、0.0.7 の実行ファイルの出力と同じだった。違いは producer の版と commit の値だけである。Fail は aggregateEffects に現れない |
| 制約付き操作 | `render[T: Trait.Show]` の操作を Integer と String で呼び、`42/"x"` を得た |
| 文字の全域 | 全域の区間で網羅になった。後続の `case _` は E0602 で拒否された。`'a'` だけの match の反例は `'\u{0}'` だった |
| JSON と Property | リファレンスの Codec の往復と Property の @test が成功した。test --check はコールバックを呼ばない |
| Skill | `skill list`（text と json）と `skill show` で、SKILL.md と references/inspection.md を取得できた |
| derive | リポジトリの例で derive check が一致し、test も 2 件成功した。例の写しで Address に欄を足すと、derive check が終了 1 で古い生成を報告した。preview の後、誤ったハッシュの apply は終了 1、正しいハッシュの apply で再生成でき、derive check も一致した。手書きの JSON を検査するテストは、新しい必須の欄の不足を報告した（利用者のテストを直す範囲であり、期待どおり） |
| ソースの候補 | `git archive HEAD` を `/private/tmp/benitoite-candidate-0.0.8/` に展開した。中身は追跡中の 6,786 項目（ファイル 6,780 とシンボリックリンク 6）で、docs/todo と reference は含まない。tools/derive と examples を含む。展開した候補で derive_inventory と benitoite をビルドし（54 秒）、derive check の一致・People.bnt の test 2 件の成功・gen_skill の作り直しで同梱の Skill が変わらないことを確かめた。この候補には git がないので、commit は unknown と表示される |

英語と訳の対応、同梱物と生成物の 68 ファイルの SHA-256 は V1（[v1/results.md](v1/results.md)）から引用する。V1 の後に変えたのは、全比較の固定記録・性能の記録・この結果の記録だけであり、これらの入力は変えていない。

### 残り

- RV5（Opus、[reviews/RV5.md](reviews/RV5.md)）は「軽い直しの後に受け入れてよい」。中1（上の引用の欄）・軽1（この節）・軽2（性能の書き方）・軽3（tools/derive/README.md の注意）を直した。軽4（E0506 の案内に toResult がない）と軽5（リファレンス第 11 節の段落の順）は docs/todo の TODO-260 に送った。
- RV4 の指摘のうち後へ送ったもの: 中1（Property の縮小の費用）は TODO-258、観察1（型検査の費用）は TODO-257、観察2（derive_inventory の Debug の書式）は TODO-259。
- skill-eval と構文の測定は LLM を呼ぶので、この計画の許可に含まれず実施していない（plan.md「最終候補の受け入れとRV5」）。
- 受け入れの判断、TODO の閉鎖、改造のディレクトリの保管、タグ、push は設計者の指示による。

## 受け入れと保管（2026-10-18）

設計者は、RV5 の直しの後の候補を 0.0.8 として受け入れた。docs/todo の TODO-063・189・249・255 を閉じ、TODO-087（標準の型クラスの導出・再帰と型パラメータのレコード・専用の実行）と TODO-191（Integer）は残りの論点に書き換えた。この改造のディレクトリを `docs/archive/` へ移し、外を指す相対リンクを移した先から直した。

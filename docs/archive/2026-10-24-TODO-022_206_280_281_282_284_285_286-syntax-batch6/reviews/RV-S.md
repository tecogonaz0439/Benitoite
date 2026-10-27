# RV-S: セキュリティの作業群（S01〜S05）の独立レビュー

- 日付: 2026-10-25
- 担当: Claude Code のサブエージェント（Opus 5.5）
- 対象: `git diff 661dbdd3^ 31960eb2` のうち S 群のコミット。`d0ef480e`（S01）、`7fa8aabc`（S02a）、`d142e5a0`（S02b の停止と D28 の追記）、`ac992bde`（S02b）、`661dbdd3`（short の基準の記録）、`100ab375`（S03）、`2247d960`（S04）、`31960eb2`（S05）。docs/todo の TODO-284・285・286 に当たる。
- 照合した文書: README の「設計者の決定（2026-10-24、Lean の作業の途中）」、`decisions.md` の「セキュリティの追加項目」と D23〜D30（D28 の 2026-10-25 の追記を含む）、`plan.md` の「セキュリティ作業群の共通条件」・S01〜S05・検査の割り当て（S01〜S05 の行、T-S、change・release の行）、`preflight.md` の P2 と S03 の追記、`s01/`〜`s05/` の `results.md` と S03・S04 の保存記録、集約の `results.md` の S02b・S04・S05 の節。
- 方法: `git show`・`git diff` と読み取りだけで確かめた。cargo のビルド・テスト、`scripts/check*.sh`、`cargo deny` は実行していない。上流の事実は、Cargo のキャッシュにある Wasmtime 49.0.2・49.0.4 と cargo-deny 0.20.2 の配布ソース、および S04 が取得した RustSec の DB の写しで確かめた。Web は参照していない。`private/` と `docs/todo/` は読んでいない。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 3（うち実行で確かめる点 1） |
| 軽 | 9 |

判定: S01・S02 の既知の19件への対応は受け入れてよい。両 lock の版は勧告の修正版の範囲に入り、機能の拡大もない。取っ手の上限と R0906 の実装は D28 の追記どおりで、分類の順序の変更による既存の分類の変化は読みでは見つからない。S03〜S05 の表示だけの照合・公開手順・スキルは設計者の指示（最初の照合で組み込みを決める、最後の検査では表示だけで不合格にしない、改造がないときも手動・周期的に呼べる）を満たし、互いに矛盾しない。

受け入れの前後に扱うべき点は中の三件である。中1（版上げ後の fuzz の lock の同期）は Z01a の手順に入れないと、公開候補で fuzz の照合が必ず未照合になる。中2（02-09 の「従来」の誤りと 0.0.11 からの受理範囲の縮小）は文書の訂正と、Z01a での CHANGELOG の扱いの判断を要する。中3（勧告ありの経路の実出力での未確認）は A01 の妨げにはならないが、Z01b の前に一度確かめておくことを推す。

## 重大

なし。

## 中

### 中1: 版を上げた後に fuzz の lock を同期する手順がなく、公開候補の fuzz の照合が未照合になる

- 箇所: `.claude/skills/git-workflow/SKILL.md` の「ソースだけのリリース」の手順 1（38行目）と手順 2、`plan.md` の Z01a、`scripts/check/advisories.py` の `classify`（76〜80行目と 84〜85行目）。
- 問題（読めば確定する部分）: `fuzz/Cargo.lock` はパス依存の `benitoite` の版を記録する。S01 の記録どおり、この lock は 0.0.9 のまま 0.0.10・0.0.11 の公開を経ており、S01 で初めて 0.0.11 と `unicode-width` に同期された（`d0ef480e` の差分）。Z01a が版を 0.0.12 へ上げると、同じ食い違いが再び生じる。公開の手順 1 は「版・CHANGELOG・`docs/reference/`・`docs/ja/` の版の記述」をそろえるだけで、fuzz の lock の同期に触れていない。新しい `advisories` は fuzz に `--locked` を付けて照合するので、同期しないまま release を実行すると、fuzz の対象は照合できない。
- 問題（実行で確かめる部分）: cargo-deny 0.20.2 は `cargo metadata` の失敗を `real_main` の誤りとして `log::error!` で出して終了1にする（`src/cargo-deny/main.rs` の `main`）。`advisories.py` はこれを ERROR ログ・完了要約なしとして「UNVERIFIED」に分類し、単位を終了0にすると読める。表示はされるが、lock の食い違いという入力の誤りが「取得不能・照合不能」と同じ扱いになり、D26 の「設定の誤り・実行器の不具合は終了1」との区別があいまいになる。
- 修正案: (1) git-workflow の手順 1 と plan の Z01a に、版を上げた後に `cargo update --manifest-path fuzz/Cargo.toml -p benitoite` で fuzz の lock を同期し、二 lock の差分を確かめる手順を加える（広い一括更新はしない）。(2) `--locked` による lock の更新の拒否は、取得不能ではなく入力の誤りとして ERROR（終了1）に分類するか、少なくとも理由を「lock needs update」と区別して表示する。(2) を採るなら方針自己検査に一件加える。

### 中2: 02-09 の「従来の 100,000 個の範囲を保つ」は事実と異なり、0.0.11 からの受理範囲の縮小が CHANGELOG で区別されていない

- 箇所: `docs/design/02-impl/02-09-runtime.md` の「外部の関数の実行」の取っ手の【決定】（375行目）、`CHANGELOG.md` の Unreleased の二つ目の項目（8行目）。
- 問題: Wasmtime 49.0.2 の配布ソースには `HandleCounter` も `max_component_handles` もなく、Store ごとの生存する取っ手の上限はなかった。上限は 49.0.3 以降の `DEFAULT_MAX_COMPONENT_HANDLES = 100_000`（49.0.4 の `runtime/component/store.rs` 33行目）で入ったもので、RUSTSEC-2026-0363 の修正版の範囲（`>= 49.0.3`）とも合う。したがって 0.0.11 の利用者から見れば「従来の範囲を保つ」ではなく、100,000 を超える取っ手を同時に持つゲストが新たに R0906 で止まる。理由の文は 49.0.4 の既定と同じ値を明示したことを述べたいと読めるが、「従来」は誤りである。CHANGELOG も「explicitly」と書くだけで、0.0.11 には上限がなかったことを示していない。
- 修正案: 02-09 の理由を「Wasmtime 49.0.4 の既定と同じ 100,000 を処理系の定数で明示し、既定値の変更に依存させない。49.0.2 には上限がなかった」の趣旨に直す。CHANGELOG には 0.0.11 では上限がなかったことを加え、「Incompatible changes and migration」に載せるかを Z01a で判断する（勧告への対応で避けられない縮小であることと、対処はゲストが取っ手を解放することを添える）。D28 の理由の「既定より下げる根拠はまだなく」とは矛盾しない。

### 中3（実行で確かめる点）: 勧告ありの経路を、実際の cargo-deny の出力で一度も通していない

- 箇所: `scripts/check/advisories.py` の `classify` の勧告の診断の処理（96〜111行目）と完了要約の照合（117〜127行目）、`s03/results.md`「実際の二照合」、`s04/results.md`「作業末の検査」。
- 問題: 実行器が加わった S03 以降、実際の照合はすべて検出0件だった。勧告ありの経路は方針自己検査のダブルだけで確かめており、ダブルの JSON の形（`advisory.id`・`advisory.package`、`graphs[].Krate.name/version`、`Solution:` の注記、要約の件数と終了1の一致）は cargo-deny のソースの読みから作られている。読みとしては、0.20.2 の `diag_to_json` は `graphs` と `advisory` を `fields` に入れ、`GraphNode` は `NodeInner` を flatten するので `{"Krate": {...}}` の形になり、注記にも `Solution: Upgrade to ...` が入る（`src/diag/grapher.rs`、`src/advisories/diags.rs`）。ダブルと矛盾する点は見つからなかったが、実際の勧告の診断では `unmaintained`・`unsound` の重大度や `bug` の重大度、要約の件数との一致が想定と違う可能性が残る。違えば勧告ありが「UNVERIFIED」と表示され、件数・ID・修正版が表に出ない（不合格にはならない）。
- 修正案: 依存を変えずにできる確認として、19件を含む状態（例: `73d12d06`）の二 lock と現在の `deny.toml` を一時の作業ツリーに置き、現行の `advisories.py` で一度照合して「ADVISORIES FOUND」と14件・19件の ID・修正版が表示されることを確かめる。得た JSON の一部を方針自己検査の固定の入力として保存すれば、cargo-deny の版を上げたときの形の変化も捕まえられる。時期は Z01b の前でよい。

## 軽

### 軽1: 集約の results.md の S05 の節がリンクの未作成のままである

- 箇所: 集約の `results.md`「S05: 公開スキルの作成とリンクの未完（2026-10-25）」の二段落目（68行目）。
- 問題: `31960eb2` には `.agents/skills/security-advisories`（mode 120000、`../../.claude/skills/security-advisories`）が含まれ、`s05/results.md` の「取りまとめの追記」も作成と確認を記している。集約の節だけが「作成できなかった」「取りまとめが作成する必要がある」のまま残り、見出しも「リンクの未完」である。
- 修正案: 集約の節に、取りまとめがリンクを作って追跡対象にしたことと日付を追記し、見出しを改める。

### 軽2: S02b の記録に手元の絶対パスが残っている

- 箇所: `s02b/probe-output.txt` の1行目（ホームの下のリポジトリの絶対パス）、`s02b/results.md` の 56・97・113・117・118・127・137 行目（`/private/tmp/benitoite-s02a/...`・`/private/tmp/benitoite-s02b/...`）。
- 問題: S04 の置換は `advisories.py` の保存記録が対象で、S02b の手書きの記録と生の出力は対象外だった。S01・S03・S04 の記録は `<scratch>`・`<tmp>`・`<repo>` で伏せており、表記がそろっていない。特に `probe-output.txt` はユーザー名を含むホームのパスを公開の改造の記録に残す。
- 修正案: `probe-output.txt` の該当行を `<repo>` へ、`results.md` の一時パスを `<tmp>/benitoite-s02a/...` などへ置き換える。生の記録を書き換えた旨を results.md に一文添える。

### 軽3: 端末の表示に絶対パスが出るが、保存するときに伏せる手順がない

- 箇所: `scripts/check/advisories.py` の 209・276 行目と `invoke` の `command:` の表示、07-03「advisories」の「端末への表示と実行に使う設定は元のパスを使う」の段落、スキル `security-advisories`「ワークスペースと fuzz の二照合」。
- 問題: 端末には証拠のディレクトリと `--config` の絶対パスが出る。S03・S04 の `work.log` は `<repo>` に伏せてあり、手で置き換えたと読めるが、07-03 とスキルは「results.md の隣へ出力の記録を保存する」とだけ書き、端末の記録を伏せる手順を示していない。
- 修正案: 表示のパスをリポジトリの根からの相対パスにするか、07-03 とスキルに「端末の記録を保存するときは同じ置換を行う」と書き足す。

### 軽4: fuzz の manifest と lock で licenses も選ぶようになった

- 箇所: `scripts/check.sh` の `classify`（297行目）、07-03 の分類の段落、`test_policy.py` の work・change の表。
- 問題: 計画の S03 は advisories の選択だけを求め、「既存の rust/licenses の選択を保つ」としていた。実装は `fuzz/Cargo.toml`・`fuzz/Cargo.lock` を既存の行へ加えたため、licenses も選ばれる。`check_licenses` はルートの `cargo deny check licenses` だけを実行するので、fuzz の依存の許諾は確かめていない。害はなく 07-03 にも書かれているが、選んだ理由と実際に確かめる範囲が一致しない。
- 修正案: fuzz の二ファイルは rust と advisories だけを選ぶ別の行に分けるか、licenses を残すなら 07-03 に「ルートの許諾だけを確かめる」と添える。

### 軽5: testdata/external の README に component-handles の説明がない

- 箇所: `crates/benitoite/testdata/external/README.md`。
- 問題: 新しい `component-handles.wat`・`.wasm` は各ケースのディレクトリでなく直下に置かれ、ゴールデンのケースではなく単体テスト用の入力である。README は各入力の役割を列挙しているが、この入力の説明がない。`wasm-tools` がなく `wat` クレートで生成した経緯（`s02b/results.md`）も README の再生成手順と異なる。
- 修正案: README に「`component-handles` は取っ手の上限の単体テスト（`external::runtime::tests`）の入力」と一文加える。

### 軽6: S03 の結果のインラインコードが閉じていない

- 箇所: `s03/results.md`「検査と終了状態」の最初の段落（14行目）「`CARGO_HOME=<tmp> である。」。
- 修正案: 「`CARGO_HOME=<tmp>` である。」に直す。

### 軽7: 勧告の照合の扱いの指示が README の「設計者の決定」にない

- 箇所: README「設計者の決定（2026-10-24、Lean の作業の途中）」（51行目〜）、`decisions.md` の「セキュリティの追加項目」の冒頭と D25・D26 の出どころ。
- 問題: 最初の照合で組み込みを決める、最後の検査では表示だけで不合格にしない、改造がないときも呼べるスキルを作る、の三つの指示は `decisions.md` に「2026-10-24 の設計者の追加指示」として書かれているが、README の「設計者の決定」には TODO-284〜286 を含める決定と着手時期しかない。`decisions.md` の冒頭は「README の全ての設計者の決定を正とする」としており、正の置き場所が逆になっている。
- 修正案: README の同じ節に三つの指示を箇条で加え、D25・D26・D30 から参照する。

### 軽8: 取っ手の超過と中断・燃料・メモリが同時に起きたときの優先は、読みだけで確かめた

- 箇所: D28（「中断・燃料・メモリの分類の優先を確かめる」）、`s02b/results.md`「テストの関門と調査資料の整理」。
- 問題: `failure` の順序（メモリ・表 → 中断・燃料 → 取っ手 → 補助の報告 → 受け渡し → コアの数 → トラップ）と `has_priority_failure` の一致は読みで確かめられるが、テストは各分類を個別に確かめるだけで、取っ手の超過との優先は確かめていない。同時に起こすゲストは作りにくく、記録もその旨を書いていない。
- 修正案: `s02b/results.md` に「優先は `failure` と `has_priority_failure` の順序の読みで確かめ、同時の超過を起こすテストはない」と一文残す。テストの追加は求めない。

### 軽9: 手順 1 で TODO の番号を含む名前を付けた後、手順 2 で範囲が増えたときの扱いがない

- 箇所: AGENTS.md「改造の進め方」の手順 1・2。
- 問題: 新しい手順 2 は、照合の結果を見て改造へ組み込むかを決める。組み込むと扱う TODO の番号が増え、手順 1 の名前と合わなくなる（第6弾では実際にディレクトリを改名した）。
- 修正案: 手順 2 に「組み込むと決めた TODO の番号を手順 1 の名前に加える」と一文足すか、照合を手順 1 の名前を決める前に置く。必須ではない。

## 確かめた主な事実

- 依存の版と勧告: RustSec の DB の写しで、rustls の 0346〜0349 は `>= 0.23.46`、rustls-webpki の 0382 は `>= 0.103.16, < 0.104.0-alpha.1`、webpki-root-certs の 0383 は `>= 1.0.10`、Wasmtime の 0353〜0364 は `>= 49.0.3`、0378・0379 は `>= 49.0.4` が修正版である。両 lock の rustls 0.23.46・rustls-webpki 0.103.16・webpki-root-certs 1.0.10・Wasmtime と内部クレート・Pulley 49.0.4・Cranelift 0.136.4 はすべてこの範囲に入る。
- 二 lock: `31960eb2` の二 lock の版の差は、fuzz 側だけの `benitoite-fuzz`・`libfuzzer-sys`・`jobserver`・`arbitrary` の版と、ルート側だけの開発用の `wat`・`wast`・`wasmparser`/`wasm-encoder` 0.261.0 であり、S 群の対象のクレートは一致する。S02a の lock の差分は版と checksum の行だけで、依存の列の追加・削除はない。`crates/benitoite/Cargo.toml` の機能指定（rustls の `std`・`tls12`、ureq の `rustls-no-provider`・`platform-verifier`、Wasmtime の `default-features = false` と四機能）は変わっていない。fuzz の lock の `benitoite` 0.0.11 と `unicode-width` の同期は S01 の記録どおりである。
- Wasmtime の上流: 49.0.4 の `HandleTable::insert` は `counter.live >= counter.limit` で `cannot allocate another handle: store handle limit exceeded` を返し、`text::COMPONENT_HANDLE_LIMIT` と完全に一致する。`set_max_component_handles` は Store ごとに働く。03-01 の行のアンカー（signals.rs の 72・131・459、machports.rs の 75・133・496、config.rs の 312）、03-10 の `config.rs` 2547〜2568（例外の既定が `gc` 機能に連動）と `types_builder.rs` 970〜980（平らな型の合流）、02-09 の `HostcallFuelExhausted` と `bump_resource_counts` は 49.0.4 の該当箇所を指す。
- 取っ手の実装: `ExternalComponentHandles { function, component, limit }`、R0906 の `component_handles` の文言、`reached_limits.component_handles`、共通の `new_store` での設定（`reset_limits` では戻さない）は D28 の追記と一致する。補助の経路も `new_store` を使い、本番で `Store::new` を直接呼ぶのは `new_store` だけである。
- 分類の順序: 中断・燃料を補助の報告・受け渡し・コアの数の前へ移しても、補助の報告は `reported_failure` が `has_priority_failure`（中断・燃料を含む）で先に除くので結果は変わらない。受け渡しの予算の枯渇とコアの数の超過はホスト側の誤りで `Trap` ではないので、`Trap::Interrupt`・`OutOfFuel` と同時に成り立たず、読みでは分類は変わらない。S02b の work で既存の R0904・R0905・R0906・R0601 のテストも通っている。
- テスト: 新しいテストは動的・stateful・補助の三経路と統計の有無で R0906・文言・注記・統計を確かめ、stateful では上限直下・上限・drop 後の再利用・呼び出しを越えた超過を確かめる。修正前に Runtime となって失敗したことが記録されており、R0601 への退行を捕まえる形である。上限より小さい値や大きい値への変更も、stateful の 99,999・100,000 の成功と 100,001 の失敗で捕まえる。関数名に原因の文言を含むトラップの行は、部分一致への退行を捕まえる。
- cargo-deny 0.20.2: 設定の読み込みの失敗は `failed to read config from`・`failed to parse config from`・`failed to deserialize config from`・`failed to validate configuration file` で、`advisories.py` の正規表現と一致する。DB の取得の失敗は `log::error!` と終了1になり、完了要約がないので「UNVERIFIED」に分類される。勧告の検査の失敗の終了状態は1である。
- 検査の選択: work は依存の manifest・二 lock・`deny.toml` の変更でだけ advisories を選び、change は差分によらず、release は `release_stack` と `advisories` を選ぶ。水準なしの `--only advisories` は終了2で、旧 `--full` の集合と `legacy-commands.json` は変わらない。07-03、AGENTS.md、二つの雛形、`test_policy.py` の期待はこの選択と一致する。
- 公開手順とスキル: AGENTS.md の手順 2（対象と実装プランの確定前の照合と設計者の判断）、雛形の「前提と依存」と段の最初の行、共通依頼文の起動前の確認、git-workflow の候補での再照合、スキルの三つの時点（改造の最初・作業中と公開候補・改造がないとき）と手動・周期の呼び出しは、互いに同じ記録先（改造の `security-advisories.md`、改造がないときは docs/todo の項目）と扱い（新しい勧告は表示・記録・報告し、不合格や停止の条件にしない）を示す。スキルは `private/` を参照せず、公開の文書から docs/todo へのリンクもない。`.agents/skills/security-advisories` は `../../.claude/skills/security-advisories` への相対のシンボリックリンクとして追跡され、`.gitignore` の除外にも当たらない。
- CHANGELOG と設計書: CHANGELOG の Unreleased と 02-09・02-10・03-01・03-10・07-03 に性能の増減の記述はない。設計書の追加は常体で、手元の絶対パスと docs/todo へのリンクはない。日付付きの過去の実測（02-09 の Fuzzy の燃料）は 49.0.2 の記録のまま保たれている。

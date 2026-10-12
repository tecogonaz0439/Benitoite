# 調査

2026-10-11 に、ブランチ `san_benito` の先頭（コミット 7dc2806）のファイルを読み、`cargo build -p benitoite` で作った `target/debug/benitoite` に小さな `.bnt` と入力を与えて確かめた。再現に使ったファイルと、serde_json の振る舞いを確かめる小さな試しのクレートは、リポジトリの外（作業用の一時ディレクトリ）に置き、リポジトリには残していない。行番号はこの版のものである。処理系のファイルは `crates/benitoite/src/` からの相対パスで、テストは `crates/benitoite/tests/`、ゴールデンテストは `crates/benitoite/testdata/` からの相対パスで書く。「（推測）」と書いた箇所は、コードを読んだだけで実行していない。重いテスト（`cargo test` の全体、`scripts/check.sh`、`scripts/check-formal.sh`）は走らせていない。

扱う項目は、docs/todo の TODO-165・166・167・169・194 と、TODO-177 のうち機械的な点（D-2〜D-6 と A-3・A-6・A-9 と内部の不具合の文言）である。TODO-177 の `uses` の表示の偽装（F-2）と、`tools/bench/results/` の 33 MB 前後の JSON を消すか（A-8）は、設計者の判断が要るので、この改造に含めない。docs/todo の TODO-179 の「診断の表示の小さな点」の (e)（診断の抜粋の端末の制御文字）は、TODO-177 の fmt の出力の制御文字と同じ論点なので、含めるかを問いの候補にした（後述の Q5）。

## 要点

- 所見はすべて今のコードでも成り立つ。実行して確かめたもの: E0441 の修正案の `Result.toOption`、E0313 の文言（prelude の名前と import の名前でも「top-level declaration」と示す）、`--licenses` の文、`Decimal.parse("01.5")` が `Option.Some(1.5)` を返すこと、`Json.parse` の特殊なキー（`"123"` の値が整数 123 に変わり、`"1e9999"` で終了状態 3）、fmt が 0444 のファイルを置き換え、固いリンクを切ること、fmt と診断がファイル名とソースの ESC をそのまま書くこと、`check`・`fmt`・`skill install` が FIFO で止まること。
- 記述より広かったもの: FIFO で止まるのは、モジュールの読み込み（D-2）と `skill install` の `is_ours`（D-3）だけでなく、コマンドラインで直接与えた FIFO を読む `fmt` も同じである。panic の境界は `skill` だけでなく、`test` と `fmt` も本体の一部（ファイルの集め方、結果の報告、ファイルの読み書き）を囲んでいない。
- TODO-194 は、`arbitrary_precision` を外し、`float_roundtrip` を付け、serde_json の `serde_json::Value` でなく自前の Visitor で値を組み立てる直し方を推奨する。serde は数の字面を Visitor に渡さず、`arbitrary_precision` なしでは `-0` を `-0.0` の浮動小数点数として渡すので、今の規則（`-0` は `Json.Value.Integer(0)`）を保つには、入力を字句として走査して得た数の字面を、Visitor が受け取る数と文書の順に対応させる。試しのクレートで、この形が特殊なキーを普通の object のまま読み、`-0` と `-0.0` を分けることを確かめた。

## 1. TODO-165 E0441 の修正案の `Result.toOption`

### 所見の確かめ

`diag/codes.rs:669-672` の E0441 の注記 `convert` は「convert the value with `Option.okOr` or `Result.toOption` before `try`」である。診断は `typeck/effects/special.rs:149-161` が作り、常に `help("convert")` を付ける。標準ライブラリの `Result` から `Option` への変換は `Result.ok`（`prelude/stdlib/Result.bnt:58`）で、`Result.toOption` はない。`function f(r: Result[Integer, String]) -> Option[Integer]` の中の `try r` を `check` に渡すと、この修正案が出ることを確かめた。

### 直し方

文言の `Result.toOption` を `Result.ok` にする。項目の直し方はそのまま成り立つ。向きに応じて修正案を一つに絞る（`try` を `Result` に使い戻り値が `Option` なら `Result.ok`、逆なら `Option.okOr`）改善もできるが、戻り値が `Option` でも `Result` でもない場合（`Integer` など）の修正案をどうするかの判断が増えるので、この改造では文言を直すだけにする（docs/todo の TODO-179 の診断の補助の改善と同じ種類の話である）。

### 影響

- 設計書: 01-09「`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`」の 46 行の注記（docs/todo の TODO-165）を消す。
- ゴールデン: `types/todo178-placeholder-try-error.diag.json` の helps の文。
- 単体テスト: `typeck/effects/tests.rs:375-388` は修正案に `Option.okOr` を含むかだけを見るので、変えなくても通る。`Result.ok` を含むことの確かめを足すかは作業で決める。
- Skill の生成物: `skill/references/diagnostics.md:1340`。`cargo run -p benitoite --example gen_skill` で作り直す。

## 2. TODO-166 `Decimal.parse` の先頭の 0

### 所見の確かめ

`builtins/funcs/decimal.rs:84-96` の `parse` は、先頭の `-` を外して `Decimal::parse_literal`（`base/decimal.rs:74-90`）を呼ぶ。`parse_literal` は字句解析が先頭の 0 を確かめた後の字面を受け取る前提で、先頭の 0 を確かめない。実行して、`Decimal.parse` が `"01.5"`・`"007"`・`"00.5"`・`"-01.5"` をそれぞれ `Option.Some(1.5)`・`Option.Some(7)`・`Option.Some(0.5)`・`Option.Some(-1.5)` と読み、`Integer.parse("01")` と `Float.parse("01.5")` は `Option.None` を返すことを確かめた。リテラル `01.5m` は E0124 になる。

### 直し方

`parse` の本体で、`-` を外した後の整数部（`.` の前）に `Integer.parse` と同じ検査 `decimal_integer`（`builtins/funcs/mod.rs:30-32`。空でない・`0` 自身を除き `0` で始まらない・数字だけ）を先に行う。`parse_literal` は字句解析も使うので変えない。項目の直し方はそのまま成り立つ。

### 影響

- 設計書: 01-04「型の変換」の 287 行の注記（docs/todo の TODO-166）を消す。
- 単体テスト: `decimal.rs:262-310` の `text_conversion_preserves_scale_and_parse_rejects_non_literals` の拒む表に `"01"`・`"007"`・`"00.5"`・`"-01.5"` を、受け付ける表に `"0"`・`"0.5"`・`"-0.5"` を加える。`"-0.00"` が `"0.00"` になる既存の確かめは残る。
- CHANGELOG: 0.0.2 が受け付けた入力を `Option.None` にするので、互換でない変更でもある。「Fixed」に書くか「Incompatible changes」の表に書くかは、Q7 にした。

## 3. TODO-167 `skill`・`test`・`fmt` の panic の境界

### 所見の確かめ

`cli/tools.rs:11-29` の `run_tool` は、`Test`・`Fmt`・`Skill` の分岐をどれも panic の境界（`runtime::panic::catch`）で囲まない。`main`（`cli/mod.rs:309-342`）も `invoke` を囲まない。panic hook（`runtime/panic.rs:63`）は記録するだけなので、境界の外の panic は報告を書かずに Rust の既定の終了状態 101 で終わる（推測。panic を起こす手段がないので実行していない）。

- `skill`（`cli/tools/skill/mod.rs`）は、どこにも境界がない。
- `test`（`cli/tools/test_runner/mod.rs`）は、ファイルごとの検査とコンパイル（`run_file` の 324-326 行）と、IO 実行器の中の実行だけを囲む。テストのファイルを集める処理（`run_test_command` の 108 行から）、結果と集計を書く処理は囲まない。
- `fmt`（`cli/tools/formatter/mod.rs`）は、ファイルごとの整形（180 行の `format`）だけを囲む。ファイルの読み込み（`read_source`、222 行）、置き換え（`replace_file`、266 行）、診断の表示は囲まない。
- `run`・`check` も、検査の段の外の処理（診断の表示など）は囲まない。02-09「panic 境界」が囲むよう定めるのは検査の各段と VM の実行であり、この部分は規則の外である。

### 直し方

`run_tool` で、各分岐の本体を `catch` で囲み、捕らえたら処理系の不具合の報告（`report::internal_diagnostic`）を書いて終了状態 3 で終える。段の名前は `skill`・`test`・`fmt` とし、`test`・`fmt` は解釈した引数の `--diagnostics` の形式で書き、`skill` は文章の形で書く。`test`・`fmt` の中の既存の境界はそのまま残る（入れ子の `catch` は問題にならない）。`test`・`fmt` も囲むかは Q4 にした。

テスト: 02-09 と 07-03 は、hook の出力が出ないことと報告の順を、CLI を別のプロセスとして起動するテスト（`tests/cli_process.rs:89-130` の `BENITOITE_DEV_PANIC` の例）で確かめるとする。`skill` の中で panic を起こすには、`BENITOITE_DEV_PANIC` に新しい値（たとえば `tool`）を加え、`DevPanic`（`cli/mod.rs:80`）に要素を足す必要がある。`DevPanic` は初回リリース版の実装プランの 10-13 が凍結した型なので、AGENTS.md の「型とシグネチャを変えない」に当たる。設計者に知らせてから変える（仕様の判断ではないので問いにはしない）。

### 影響

- 設計書: 06-01「`skill` のコマンドライン（初回リリース版）」の 88 行の注記（docs/todo の TODO-167）を消す。02-09「panic 境界」の CLI の段落（331 行）に、`test`・`fmt`・`skill` の本体も囲むことを加える。07-03 の 14 行（`BENITOITE_DEV_PANIC`）は値を足すなら合わせる。
- テスト: `tests/cli_process.rs` に `skill`（と、直すなら `test`・`fmt`）の panic の例を加える。

## 4. TODO-169 E0313 と `--licenses` の文言

### 所見の確かめ

E0313 の文言（`diag/codes.rs:405-407`）は「the type parameter `{name}` has the same name as a top-level declaration」、補助の位置のラベル `declared` は「the top-level declaration is here」である。判定（`resolve/walk.rs:14-28` の `type_parameters` が呼ぶ `resolve/lookup.rs:114-133` の `upper`）は、同じモジュールのトップレベルの名前、import で付けた名前、prelude の名前、`Benitoite` を引く。01-03「型パラメータとエフェクト変数の有効範囲」の 106 行も同じ範囲を定める。`function f[List, J]` を `import Benitoite.Unofficial.Json as J` の下で書くと、prelude の `List` にも、import の別名 `J` にも「top-level declaration」と示し、`J` では import の行を「the top-level declaration is here」と指すことを確かめた。説明の文（「cannot reuse top-level uppercase names or `Benitoite`」）も import と prelude の名前を書いていない。

`--licenses` の機能 `bundled-licenses` のないビルドの文（`cli/tools/licenses.rs:9` の `text::NOT_BUNDLED`）は、2 行目に「The release archives built by scripts/release.sh include it.」と書く。`scripts/` に `release.sh` はなく、`scripts/release/` には `licenses.sh`・`about.hbs`・`about.toml` だけがある。05-01「ライセンスの表示」の 59 行は、生成と埋め込みをまとめて行うリリースのスクリプトを初回リリース版に含めないとする（docs/todo の TODO-073）。実行して、この 2 行目が出ることを確かめた。

### 直し方

- E0313: 文言を判定の範囲に合わせる。案は「the type parameter `{name}` has the same name as a top-level declaration, an imported name, or a prelude name」、ラベルは「the other declaration is here」、説明の文は「Type parameters and effect variables cannot reuse the uppercase names of the module, imported names, prelude names, or `Benitoite`.」である。prelude の名前は位置を持たないので、補助の位置は付かない（今のまま）。
- `--licenses`: 2 行目を消し「This build does not include the list of third-party licenses.」だけにする案と、配る経路を名指さずに「Release builds include it.」とする案がある。Q6 にした。

### 影響

- ゴールデン: `names/type_param_toplevel.diag.json`（2 件の message）。
- 単体テスト: `resolve/tests.rs:689-695` はコードと名前だけを見るので変えなくてよい。`cli/mod.rs:918-933` の `licenses_in_development_build_say_list_is_not_bundled` は定数と比べるので変えなくてよい。
- Skill の生成物: `skill/references/diagnostics.md:745-749`。
- 設計書: 01-03 と 05-01 は実装に合わせて直してあり、注記もないので変えない。`docs/reference/install.md:127` の説明は、どちらの案とも合う。

## 5. TODO-177 の機械的な点

### D-2 モジュールの読み込み

`modules/mod.rs:138-141` の `RealFs::read_file` は `std::fs::read` で全体を読み、大きさは読んだ後に `modules/load.rs:203-214` の `check_size` が確かめる。実行して、`check` に FIFO を与えると止まる（3 秒の alarm で終わらせた）ことを確かめた。大きなファイルの RSS は確かめていない（外部のレビューの記録による）。

直し方: `RealFs::read_file` の中で、`O_NONBLOCK` を付けて開き（`rustix::fs::OFlags::NONBLOCK` を `OpenOptionsExt::custom_flags` に渡す。rustix は機能 `fs` で依存にある）、開いた記述子の `metadata` で普通のファイルであることを確かめ、`take(MAX_SOURCE_BYTES + 1)` で読む。開く前に `metadata` で確かめる順では、確かめた後に FIFO へ差し替えられると開くところで止まるので、開いてから確かめる。普通のファイルでなければ入出力の誤りを返し、今の E0101 の経路に乗る。上限を 1 バイト超えて読めたら、`check_size` が今のまま「size limit」の理由にする。`ModuleFs::read_file` のシグネチャは 10-04 が凍結したものなので変えず、上限は `RealFs` の中で `MAX_SOURCE_BYTES` を使う。

### D-3 `skill install` の `is_ours`

`cli/tools/skill/mod.rs:158-169` の `is_ours` は、ディレクトリ自体は `symlink_metadata` で確かめるが、`SKILL.md` はリンクを辿って `read_to_string` で全体を読む。プロジェクトの `.claude/skills/benitoite/SKILL.md` を FIFO にして `skill install --project --agent claude-code` を実行すると止まることを確かめた。

直し方: `SKILL.md` を `symlink_metadata` で確かめ、普通のファイル（リンクでない）だけを、D-2 と同じ読み方で上限付きで読む。上限は埋め込んだ `SKILL.md` の大きさに余裕を持たせた値（たとえば 1 MiB）とする。普通のファイルでないか、上限を超えたら、`install` が書き出したものでないとみなす（今の読めない場合と同じく `false`）。D-2・D-3・D-4 の読み込みは同じ形なので、共通の補助の関数（普通のファイルだけを上限付きで読む）を一つ置く。

### D-4〜D-6 fmt の一時ファイルと出力

`cli/tools/formatter/mod.rs:266-311` の `replace_file` は、一時ファイルを `create_new` で既定の許可（umask に従い 0644 相当）で作って書き、書いた後に元の許可を写して（299 行）、`rename` で置き換える（301 行）。次を確かめた。

- 0444 のファイルを整形すると置き換わり、許可は 0444 のまま中身が変わる（ディレクトリに書き込めれば `rename` は成功する）。
- 固いリンクの片方を整形すると、整形したほうだけが新しい inode になり、もう片方は古い中身のまま残る（リンクの数が 2 から 1 に変わる）。
- 所有者は fmt を実行した利用者になる（推測。別の利用者のファイルでは試していない）。
- 書いている間に一時ファイルを読めること（FE-04）は、作り方から明らかなので再現していない。
- `fmt` に FIFO を直接与えると、`read_source`（222 行）が `File::open` で止まる（項目に書いていない点）。ディレクトリを与えた場合は、`args::bnt_files`（`cli/tools/args.rs:110-131`）が普通のファイルだけを集めるので止まらない。
- ファイル名に ESC を含むと、`--check` の「would reformat」の行（208 行）と、診断の `-->` の行にそのまま出る。

直し方:

- 一時ファイルを `OpenOptionsExt::mode(0o600)` で作る（項目の直し方のとおり）。書いた後に元の許可を写す今の順は残す。
- 0444 のファイル、固いリンクを持つファイル（`MetadataExt::nlink() > 1`）、実行した利用者と所有者が違うファイルの扱いは、拒むか文書に書くかを Q3 にした。拒むなら、E0125 の注記 `reason` に理由の文を入れ、文は fmt の `text` に置く。所有者の比較は、作った一時ファイルの所有者（`fstat`）と元のファイルの所有者を比べれば、新しい依存の機能なしにできる。
- `read_source` は D-2 と同じ補助の関数で読む。
- ファイル名の制御文字は、後述の「6. 端末の制御文字」の逃がし方を「would reformat」の行にも使う。

### A-3・A-6・A-9 と内部の不具合の文言

- A-3（絶対パス）: `git grep -l '/Users/'` は 40 ファイルを示す。`docs/archive/` の外は `tools/syntax-measure/results/` の 8 ファイル（`stage1-codex.*`・`stage1-opencode.*`。jsonl がそれぞれ 720 行）だけで、中身は `~/.cache/benitoite-syntax-measure/...`（作業ディレクトリの位置と保管の tar の位置）である。測定の道具（`tools/syntax-measure/bntmeasure/harness.py:32`）が `os.path.expanduser('~')` を展開した絶対パスを記録する。`formal/reviews/` はもうない。`docs/archive/` の中は 32 ファイル（初回リリース版の実装プランの `formal-reviews/` と `studies/` が 16、TODO-162 の三つの改造の `reviews/` が 16）である。直し方は、記録の接頭辞を `~` に置き換え、道具が記録するときに `~` に戻して書くことである。記録を書き換えるか、`docs/archive/` の中も直すかは Q8 にした。
- A-6（`.gitignore`）: 根の `.gitignore` は `/__pycache__/` を根だけに限り、`*.pyc`・`.env`・`*.pem`・`.claude/settings.local.json` を持たない。今これらに当たるファイルは追跡されていない（`git ls-files` で確かめた）。`__pycache__/`（どの深さでも）・`*.pyc`・`.env`・`*.pem`・`.claude/settings.local.json` を加える。
- A-9（メールアドレス）: `tools/skill-eval/tasks/regex_text/input/messages.txt:2` の `carol@test.org` の `test.org` は予約されたドメインでない。`carol@example.org` に変え、`expected.stdout` の `test.org: 1` を `example.org: 1` にして、鍵の順（`example.com`・`example.org`・`sub.example.net`）に並べ直す。課題の期待が変わるので、過去の評価の記録とは比べられなくなる。
- 内部の不具合の文言: `diag/codes.rs:1023-1024` の `INTERNAL_REPORT` は「this is a bug in the implementation; please report it with the script that caused it」で、報告先と秘密を除く注意がない。`SECURITY.md` には、公開の issue に貼る前に秘密を除く注意がすでにある。文言は Q9 にした。`runtime/report.rs:1296` の単体テストは定数と比べるので変えなくてよい。02-10「処理系の不具合と処理系の制限の報告」（343 行）は「処理系の不具合として報告するよう求める文を添える」とだけ書くので、文言を変えても設計書は変わらない。

### 影響

- 設計書: 06-01「`fmt` のコマンドライン（初回リリース版）」に、一時ファイルの許可と、Q3 の答え（拒むなら、拒む場合と診断）を書く。モジュールと Skill の読み込みで普通のファイルだけを読むことを、02-04「モジュールの探し方」と 06-06「Skill の導入（初回リリース版）」に一文ずつ足す（推測。該当の節の今の文は確かめていない）。
- 言語リファレンス: `docs/reference/benitoite.md:741` の fmt の置き換えの説明に、Q3 の答えを足す。
- テスト: `cli/tools/formatter/tests.rs`（`replace_file` の許可の写し）、`tests/fmt_command.rs`、`cli/tools/skill/tests.rs`、`modules/tests.rs` に、FIFO（unix だけ）、0600 の一時ファイル、Q3 の場合を加える。

## 6. 端末の制御文字（docs/todo の TODO-179 の (e)）

ソースの文字列に ESC を書くと、E0108（閉じていない文字列）と E0114（逃がしていない制御文字）の抜粋に `ESC[2J`・`ESC[H` がそのまま出ることを確かめた（docs/todo は E0103 と書くが、今の版で出るのはこの二つである）。JSON の診断は `\u001b` のように逃がしている。抜粋の行は `diag/render.rs:452-462` の `render_source_line` が、幅は `render.rs:411-450` の `visit_source_units` と `display_width` が作り、正しくない UTF-8 だけを U+FFFD に置き換え、タブだけを空白 4 つにする。`-->` と `:::` の行のファイル名（`append_location`、546 行）も、そのまま書く。

直し方: `visit_source_units` で、タブを除く C0（U+0000〜U+001F）、DEL（U+007F）、C1（U+0080〜U+009F）を `\u{1B}` の形に置き換え、その文字数を幅として返す。これで `^`・`~` の位置も揃う。逃がし方は字句の誤りの修正案（「write it as `\u{1B}`」）と同じ形にする。ファイル名を書く箇所と、fmt の「would reformat」の行も同じ関数で逃がす。双方向の書式の制御文字（U+202E など）は、この改造では扱わない。

影響: 02-10「診断の文章の形式」の 182 行（タブの置き換え）に、制御文字の置き換えを一文足す。`diag/render.rs` の単体テストに、ESC・C1・タブの混じった抜粋の例を加える。

## 7. TODO-194 `Json.parse` の特殊なキー

### 所見の確かめ

`crates/benitoite/Cargo.toml:32` は `serde_json = { version = "=1.0.151", features = ["arbitrary_precision"] }` である。`builtins/funcs/json.rs:20-41` の `parse` は `serde_json::from_str::<serde_json::Value>` で読み、`overflow_position`（89-129 行）で生の入力の数を確かめた後、`convert`（141 行から）で言語の値に変える。`convert` は `Value::Number` を `number_value(n.as_str())`（77-87 行）で変え、失敗を `Stop::Internal("unchecked JSON number")` にする（149-151 行）。

実行して次を確かめた。

| 入力 | 今の結果 |
|---|---|
| `{"$serde_json::private::Number":"123"}` | `Result.Ok` で、値は整数 `123`（object でなくなる） |
| 同じキーの `$` を `\u0024` と書いた形 | 同じく `123` |
| `[{"$serde_json::private::Number":"-0"}]` | `[0]` |
| 値が `"abc"` | `Result.Error`（1 行 1 列、「invalid number」） |
| 値が `"1e9999"` | 処理系の不具合、終了状態 3（報告は「the panic occurred in the VM thread」と書くが、原因は `Stop::Internal` である） |

serde_json は数を字面のまま持つために、このキーを持つ一要素の object を内部の数の表現として読む。`overflow_position` は文字列の中を読み飛ばすので、この数は確かめを通り抜ける。

### なぜ `arbitrary_precision` を使っているか

`json.rs` の 35-36 行のコメントと 03-08「Json」の規則から、使う理由は次の三つである。

1. 数の分類を字面で決める。03-08 は、小数点と指数を持たず `Integer` に収まる数を `Json.Value.Integer`、それ以外を `Json.Value.Float` とし、`-0` を `Integer(0)`、`-0.0` を `Float(-0.0)` とする。`number_value` は字面に `.`・`e`・`E` がなければ `i64` として読み、そうでなければ Rust の `str::parse::<f64>` で読む（`i64` に収まらない整数の字面も `Float` になる）。
2. 範囲外の数を、重複した鍵で捨てられた値も含めて、数の始まりの位置で報告する。`arbitrary_precision` の serde は範囲外の数も字面のまま受け付けるので、`overflow_position` が後から入力を走査して最初の範囲外の数を探す。単体テスト（`json.rs` の `parse_errors_report_character_columns_and_separate_reasons`）は、`1e400` の列を 1、`{"a":1e400,"a":0}` の列を 6 と確かめる。
3. `Json.stringify` が `serde_json::Number::from_f64(n)` の `as_str()`（306-310 行）で一つの浮動小数点数を書く。`as_str` は `arbitrary_precision` のときだけある。

### serde_json 1.0.151 の振る舞い（ソースと試しのクレートで確かめた）

`arbitrary_precision` を外し、`float_roundtrip` を付けた serde_json 1.0.151 で、次を確かめた。

- 特殊なキーの object は、普通の object のまま読む。
- `-0` は浮動小数点数 `-0.0` になる。`src/de.rs:509-527` の `parse_number` が、負の整数の字面で値が 0 以上になる場合（`-0`）を「Convert into a float if we underflow, or on `-0`」として `F64` にする。`serde_json::Value` からも、Visitor が受け取る `visit_f64` からも、`-0` と `-0.0` は区別できない。
- `i64` を超え `u64` に収まる整数は `u64`、`u64` を超える整数は `f64` になる。`u64` から `f64` への変換は最も近い値への丸めなので、今の `str::parse::<f64>` と同じ値になる（推測。境目の値は確かめていない）。
- 範囲外の数（`1e400`）は serde が先に誤りにし、文言は今と同じ「number out of range」、列は数の終わり（`1e400` で 5）になる。誤りの順も変わる。今は、構文の誤りがあれば範囲外の数より先に報告する（`[1e400,}` は 1 行 8 列の「expected value」）。外した後は、文書の順で最初の誤りを報告する（同じ入力で 2 列目の範囲外の数）。
- `float_roundtrip` は、Cargo.toml の説明で「f64 -> JSON -> f64 produce output identical to the input」とされ、浮動小数点数の読み方の精度を上げる。付けないと「best-effort precision」になる。Cargo.lock の依存は変わらない（試しのクレートが `--offline` でビルドできた）。
- `Number::from_f64(n)` の `Display`（`to_string()`）は、`arbitrary_precision` のときの `as_str` と同じく zmij の `format_finite` で書く（`src/number.rs:192・356`）。`1.0`・`-0.0`・`1e+300`・`9.223372036854776e+18`・`5e-324`・`100.0` が今のテストの期待と同じ文字列になることを確かめた。ryu は Cargo.lock になく、使う必要もない。
- 入れ子の深さの上限 128（「recursion limit exceeded」）は、`Deserializer` が持つ（`src/de.rs:63`）ので、Visitor を替えても変わらない。

### 直し方の選択肢

**A. `arbitrary_precision` を外し、自前の Visitor と数の字面の対応で値を組み立てる（推奨）。** Cargo.toml の機能を `float_roundtrip` に替える。`serde_json::Deserializer::from_str` に、言語の値の材料（自前の列挙型）を組み立てる `DeserializeSeed` と `Visitor` を渡す。object は Visitor が `BTreeMap` に後勝ちで入れるので、重複した鍵で捨てられる値も Visitor を通る。入力を `overflow_position` と同じ規則で字句として走査し、文字列の外にある数の字面を文書の順に並べておく。serde は値を文書の順に Visitor に渡すので、`visit_i64`・`visit_u64`・`visit_f64` が呼ばれるたびに次の字面を取り出し、今の `number_value` で分類する。serde が渡した数の値は使わない。字面の数と呼ばれた数が合わないときや、`number_value` が値を返さないときは、Visitor から `de::Error::custom("number out of range")` を返す。serde がこの誤りに行と列を付けるので、`Stop::Internal` の経路はなくなる（(d) の直しを兼ねる）。serde が範囲外の数で誤りを返したら、`overflow_position` で数の始まりの位置を求めて報告する。serde が最初に止まる誤りより前の部分は正しい JSON なので、`overflow_position` が見つける最初の範囲外の数は、serde が止まった数と同じである。`Json.stringify` は `as_str()` を `to_string()` に替える。

試しのクレートで、`-0` 分だけを対応させる簡略形を動かし、`[-0, -0.0, -0e3, -1e-9999, -0]` が `[Int(0), Float(-0.0), Float(-0.0), Float(-0.0), Int(0)]` に、`{"a":-0.0,"a":-0}` が `{"a": Int(0)}` に、特殊なキーの object（`\u0024` の形と入れ子を含む）が object のままになることを確かめた。

今の規則を保てるか: 数の分類（`-0`・`-0.0`・`u64` を超える整数）、範囲外の数を誤りにすること、重複した鍵で捨てられた範囲外の数を誤りにすること、Float の往復、範囲外の数の列（数の始まり）、構文の誤りの文言と位置は保つ。変わるのは、構文の誤りと範囲外の数がどちらもあるときに、文書の順で先の誤りを報告するようになる点だけである。03-08 はこの順を定めていない。

懸念: 字面の対応は、serde が値を文書の順に Visitor に渡すことに頼る。読みながら値を渡す構文解析器ではこの順は変わりようがないが、serde の文書が約束する性質ではない（確かめていない）。対応が崩れたら、上の custom の誤りで `Result.Error` になり、処理系の不具合にはならない。

**A'. A と同じく外し、`-0` を `Float(-0.0)` にするよう 03-08 を変える。** 字面の対応が要らず、`serde_json::Value` をそのまま使える。ただし 03-08 の規則を変える互換でない変更であり、`Json.asInteger` で `-0` を読むスクリプトの結果が変わる。範囲外の数の列も、数の終わりに変わる（今の単体テストを改めるか、位置を求め直す処理が要る）。

**B. 自前の JSON の構文解析器を書く。** 字面をそのまま扱えるので、数の規則と位置を直接書ける。serde_json を処理系の依存から外し、テストだけの依存（`[dev-dependencies]`）にできる。一方で、文字列の逃がし方（サロゲートの対を含む）、空白、数の文法、深さの上限、誤りの文言（今は serde の文言をそのまま返し、単体テストが「trailing comma」「EOF while parsing a string」「EOF while parsing a value」「recursion limit exceeded」を確かめる）をすべて決めて書く必要があり、作業が A より大きい。AGENTS.md の「目的の衝突」は、言語の中核と処理系の主要部の外の基盤には既存の OSS を使うとしており、JSON の構文解析器はその外に当たる。B を採るなら、serde_json との差分を比べるテスト（無作為な JSON で受け付けと値が一致すること）を加えることになる。設計書は 03-01 の 51 行、03-08 の 24 行、08-03 の 1144 行（serde_json の依存の表）が変わる。

**C. 特殊なキーの文字列だけを拒む。** 逃がし方と入れ子と、そのキーを持つ正当な object の扱いが残るので採らない（項目と外部のレビューのとおり）。

| | A | A' | B | C |
|---|---|---|---|---|
| 特殊なキーを object として読む | 保つ | 保つ | 保つ | 拒む |
| `-0` は `Integer(0)` | 保つ | 変わる | 保つ | 保つ |
| 範囲外の数の列（数の始まり） | 保つ | 変わる（直せば保てる） | 保つ | 保つ |
| 誤りの文言 | 保つ | 保つ | 書き直す | 保つ |
| 変える量 | `json.rs` の解析と Cargo.toml | 少ない | 大きい | 少ない |

### (c) 形式化の交換形式への響き

`tests/coverage_export.rs`・`tests/desugar_export.rs`・`tests/desugar_export/exchange.rs` は、同じクレートの依存の serde_json を使うので、機能の変更がそのまま効く。読んだ範囲では響かない（推測）。浮動小数点数はビット列の文字列（`exchange.rs:88` の `{"bits": ...}`）で書き、整数は `i64` の範囲（`coverage_export.rs:24-32` の境目の値）である。`arbitrary_precision` の有無にかかわらず、整数は itoa で同じ文字列になり、`coverage_export.rs:549-551` の往復の比較も、`i64` を正なら `PosInt`、負なら `NegInt` として読み書きするので一致する。`desugar_export.rs:223-224` の `as_u64` も変わらない。作業で、`cargo test --test coverage_export --test desugar_export`（長いテストを除く）を走らせて確かめる。`check-formal.sh` は形式化した範囲に触れないので、この改造の完了条件には入らない（Lean の側は JSON を自前で読む）。B を採っても、テストの serde_json は `[dev-dependencies]` に残せばよい。

### (d) 変換できない数を `Result.Error` にする

`json.rs` の解析の経路で、外部の入力によって起きうる `Stop::Internal` は 151 行の「unchecked JSON number」だけである。ほかの `Stop::Internal`（変換の積み重ねの不整合など）は、入力によらない内部の不変条件なので残す。A では上のとおり Visitor の誤りとして `Result.Error` になる。

### (e) テスト

既存のテストの場所:

- 単体テスト: `json.rs` の `mod tests`（数の分類と負のゼロ、往復と逃がし方と重複した鍵、整形と非有限の数、誤りの列と文言、深さの境目 127・128 と深い値の書き出し）。
- 統合テスト: `tests/l21_json.rs`（ソースの関数と ParseError の欄）、`tests/l31_http_serve_and_helpers.rs`（`Http.json` と組み合わせたサーバ）。
- ゴールデン: `stdlib/l40-json.bnt`、`io/l40-json-total.bnt`、`acceptance/json_summary.bnt`、`network/routes-and-post.bnt`（`Http.json`）。
- fuzz に JSON の対象はない（`fuzz/fuzz_targets/` は検査と整形だけ）。

加えるテスト:

- 単体テスト: 特殊なキーの object（値が `"123"`・`"1e9999"`・`"-0"`・`"abc"`、`$` を `\u0024` と書いた形、配列と object の中の入れ子）が object のまま読め、`Json.stringify` で同じ object に戻ること。`-0` と `-0.0` が同じ入力の中に混じる形と、重複した鍵で捨てられる `-0` の形。構文の誤りと範囲外の数がどちらもある入力の誤り（文書の順の先のもの）。
- サーバ: `tests/l31_http_serve_and_helpers.rs` の形で、要求の本体を `Json.parse` に渡すサーバに、特殊なキーの入力を送った後、普通の要求に応えることを確かめる。外部のレビューの `json_server.bnt`（誤りを 400 にし、成功を `Http.json` で返すサーバ）と同じ形である。
- fuzz の対象（`Json.parse` が `Stop::Internal` を返さないこと）を加えるかは、この改造の範囲の外とする。

### 影響

- 設計書: 03-08「Json」に、オブジェクトの鍵はどの文字列でもよく、鍵によって値の読み方を変えないことと、`Json.parse` は入力によって処理系の不具合にならないことを足すか（足さなくても規則とは矛盾しない）。誤りの順が変わる件は、03-08 が定めていないので書かなくてよい。A' を採るなら 03-08 の `-0` の規則を変える。B を採るなら 03-01・03-08・08-03 の依存の表を変える。
- CHANGELOG: 「Fixed」に、特殊なキーの object が object のまま読めることと、処理系の不具合で止まらないことを書く。A' なら「Incompatible changes」に `-0` を書く。
- 言語リファレンス: `docs/reference/benitoite.md` の Json の節は数の規則を書いていない（828 行の例だけ）ので、A・B では変えない（推測。節の全体は読んでいない）。

## 作業の分け方の案

同じファイルを触る作業は分ける作業にしない。CHANGELOG と設計書の注記の削除は、どの作業も触るので、オーケストレータが最後にまとめて書く案とする。

1. **作業 J（TODO-194、最優先）**: `crates/benitoite/Cargo.toml`、`builtins/funcs/json.rs`、`tests/l31_http_serve_and_helpers.rs`（か `testdata/network/` の新しいゴールデン）。ほかの作業と同じファイルを触らないので、先に始められる。
2. **作業 W（文言と値の小さな直しと衛生）**: TODO-165・TODO-169（`diag/codes.rs`、`cli/tools/licenses.rs`）、TODO-166（`builtins/funcs/decimal.rs`）、内部の不具合の文言（`diag/codes.rs`）、A-3（`tools/syntax-measure/`）、A-6（`.gitignore`）、A-9（`tools/skill-eval/tasks/regex_text/`）、ゴールデン 2 件、`gen_skill` による Skill の作り直し。Q3 で fmt が拒むことにして E0125 の説明の文を直すなら、それも `diag/codes.rs` なのでこの作業に入れる。
3. **作業 C（CLI の入出力と panic の境界）**: TODO-167（`cli/tools.rs`、`cli/mod.rs` の `DevPanic`、`tests/cli_process.rs`）、D-2（`modules/mod.rs`）、D-3（`cli/tools/skill/mod.rs`）、D-4〜D-6（`cli/tools/formatter/mod.rs`）、端末の制御文字（`diag/render.rs`）。大きければ二つに分け、C1（`cli/tools.rs`・`cli/mod.rs`・`diag/render.rs`。panic の境界と、制御文字を逃がす関数）を先に、C2（`modules/mod.rs`・`skill/mod.rs`・`formatter/mod.rs`。普通のファイルを上限付きで読む補助の関数、fmt の置き換え、「would reformat」の行に C1 の関数を使う）を後にする。C2 は C1 の関数を使うので、並べずに順に行う。

依存: J は独立している。W と C は、W が E0125 の説明を直す場合を除き、ファイルが重ならない。C2 は C1 の後である。Codex のビルドの並列は 3 までなので、J・W・C1 を並べ、C2 を C1 の後に回せる。

## 設計者に決めてもらう問いの候補

- **Q1（TODO-194 の直し方）**: A（`arbitrary_precision` を外し、自前の Visitor と数の字面の対応）、A'（外し、`-0` を `Float(-0.0)` に変える）、B（自前の構文解析器）。推奨は A。理由: 03-08 の規則と誤りの文言と位置を保ち、JSON の文法の検査は既存の OSS に任せたまま、変える範囲が `json.rs` に収まる。字面の対応が崩れても `Result.Error` になり、処理系の不具合には戻らない。
- **Q2（誤りの順）**: A では、構文の誤りと範囲外の数がどちらもあるとき、文書の順で先の誤りを報告するよう変わる。受け入れるか（推奨。03-08 は順を定めておらず、先の位置を示すほうが直しやすい）、今の順（構文の誤りを先）を保つ処理を足すか。
- **Q3（fmt の 0444・固いリンク・所有者）**: (a) 拒んで E0125 で報告する、(b) 置き換えることを 06-01 とリファレンスに書く、(c) 0444 と所有者違いは拒み、固いリンクは書く。推奨は (a)。理由: 0444 は利用者が書き換えを望まない印であり、固いリンクを黙って切ると、もう片方の名前に古い中身が残ったことに気付く機会がない。拒んでも、許可を変えれば整形できる。
- **Q4（TODO-167 の範囲）**: `skill` だけを囲むか、`test`・`fmt` の本体も囲むか。推奨は三つとも囲む。理由: 06-01 は三つとも処理系の不具合を終了状態 3 とし、`test`・`fmt` にも境界の外の処理がある。変える箇所は `run_tool` の一か所で済む。
- **Q5（端末の制御文字を含めるか）**: 診断の抜粋とファイル名、fmt の「would reformat」の行の制御文字を、この改造で逃がすか。推奨は含める。理由: TODO-177 の fmt の出力の制御文字と同じ直し方で、変える箇所が `diag/render.rs` の文字の訪問に集まる。含めるなら、docs/todo の TODO-179 の (e) をこの改造で閉じる。
- **Q6（`--licenses` の文）**: 「This build does not include the list of third-party licenses.」の 1 行にする（推奨。TODO-073 でリリースの形が決まってから足せばよい）か、配る経路を名指さない 2 行目を残すか。
- **Q7（`Decimal.parse` の CHANGELOG）**: 「Fixed」に書くか、「Incompatible changes」の表に移行の仕方（先頭の 0 を除いてから渡す）とともに書くか。推奨は表に書く。理由: CHANGELOG の冒頭は、互換でない変更をすべて移行の仕方とともに書くとしている。
- **Q8（絶対パス）**: `tools/syntax-measure/results/` の記録の `/Users/<名前>` を `~` に書き換えるか、記録は残して道具だけを直すか。`docs/archive/` の中の 32 ファイルは、読み取り専用の扱いのまま残すか。推奨は、`tools/` の記録を書き換え、`docs/archive/` は残す。理由: 含まれるのは利用者の名前と作業ディレクトリの位置で、公開のリポジトリの持ち主の名前と同じであり、保管した写しを書き換える理由として弱い。
- **Q9（内部の不具合の文言）**: 報告先（公開のリポジトリの issue）と、秘密を除く注意を加えるか。案は「this is a bug in the implementation; please report it at https://github.com/tecogonaz0439/Benitoite/issues with the script that caused it, after removing any secrets」。URL は外部のレビューの資料の固定リンクから取ったもので、README と Cargo.toml には書いていない。報告先の URL を処理系に埋め込むか（リポジトリを移すと古くなる）、注意だけを加えるかを決める。

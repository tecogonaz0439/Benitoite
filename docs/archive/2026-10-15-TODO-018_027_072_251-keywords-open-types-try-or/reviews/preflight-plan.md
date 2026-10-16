# 実装プランの事前点検（2026-10-15、Opus 5.5 のサブエージェント 2 つ）

## 準備・段 1 A・段 2 D（P1・P2、A1〜A3、D1〜D9）

【重大】
1. design.md「判定の手順と診断」と plan D1・D6 の Shape::Other: 「view が指定する ADT に `Shape::Other` を加える」とあるが、Shape::Other は Rust（typeck/patterns.rs:219、表示は 276 行で `"_"`）にも Lean（Release/Coverage.lean:175 の Shape.other、CoverageWitness.other は CoverageShow.lean で `"_"` と表示）にも既にある。Integer と String の残りの値や未知の型に使っているものである。これを流用すると反例が `_` になり、`<future constructor of T>` の表示や、型の出どころを持つ help と食い違う。修正案: 新しい場合（Rust は `Shape::Future(BindingId)`、Lean は `Shape.future d` と `CoverageWitness.future d`）を設けると明記する。Lean の CoverageDisplay は ConName で引く表なので、DataName ごとの表示名と record かどうかを交換形式（D3 の網羅性 3）に加える。あわせて「QualifiedType」の綴りの作り方（E0607 の `{ty}` と同じ show_type か、def.name か）も決める。
2. plan D6（Rust の出力を corpus 9 へ切り替える作業）で触るファイルの漏れ: tests/desugar_export/check_named.py:169 が `width corpus version == 8` を固定しており、exchange-manifest.json の namedVersions（corpus 8・table 2・coverage 2）も照合に使っている。これを直さないと、D6 の check-formal が必ず失敗する。Rust 側の desugar_export.rs:324・424、named.rs:49 の version 8 と、coverage_export.rs:610・673 の version 2 も書き換える対象になる。修正案: D6 の触るファイルに check_named.py・exchange-manifest.json を加える。formal/tests の test_width_exchange.py・width-exchange.json・named-exchange の固定入力を、旧版の負の入力として残すのか更新するのかを明記する。
3. plan D2 の大きさと漏れ: Lean の Surface では、Program.declarations を一つにまとめて使っており、22 ファイルで 129 箇所から参照している。本体ごとの view（declarationsFor）に切り替えると、多くの証明に「view に依存しない」補題を足す必要があり、30〜60 分には到底収まらない。触るファイルにも、Surface/CheckPatterns.lean（exhaustive_sound など）、CheckLemmas.lean、CheckTablesSound.lean、Check.lean（matchExhaustive・bindingExhaustive・recordUpdateExhaustive・tryResult/OptionExhaustive）が抜けている。修正案: 次のように先に枝番へ分ける。D2a は Release の useful/checkMatch を view 付きにして健全性を示す。D2b は Declarations に view の欄（既定は閉じた型。こうしておけば D3 の前でも Exchange.Convert がそのままコンパイルできる）と、match/bind の規則・checker を加える。D2c は Program と declarationsFor、型保存と desugar_typed への接続。あわせて「record の更新と try の Exhaustive は閉じたままにする」を、どの補助関数で保つかを書く。

【中】
4. plan A1 の触るファイル: キーワードを `matches!` で並べた箇所が parser/decls.rs:138（parse_item）、types.rs:58、exprs.rs:297（parse_primary）、lexer/tests.rs:929 にもある。網羅しない matches! なので、漏れてもコンパイラは知らせない。修正案: `git grep -n KwTry` の全件を確認表にする。新しい字句の名前は既存に合わせて `KwDie` とする（design の表は `Die`）。KwDie は newline::is_keyword に入れ、continues_after には入れない、と明記する（continues_after に KwReturn が入っている点は B7 の点検者へ回す）。
5. design「属性の文法と適用先」の「個別の構成子への指定は E0802」: 属性は宣言の頭でしか解析していない（decls.rs:35、items.rs:433）。そのため、data の本体の中の `@` は E0201 になる。E0802 を出すには新しい解析の経路が要るのに、計画にない。修正案: E0201 のままとするか、構成子の前の属性を読む作業を D6 に加えるかを決める。
6. plan D7「生成した stdlib 文書から属性が消えないように」: cli/tools/skill/generate.rs の decl_head は `public` から切り出し、属性を含めないことを 06-06 の規則として明記している（391 行）。修正案: D7 の触るファイルに generate.rs・skill の tests.rs・06-06 を加え、@builtin などは出さず @extensible だけを出す、と規則を書き直す。
7. plan D6 の大きさ: 解析、typeck の view、反例と help、交換形式の出力、文書、Skill を一度に行う計画で、目安を超える。修正案: 三つに分ける。D6a は view の判定と診断で、AdtDef に extensible: true を直接入れた単体テストと coverage_export で確かめる。D6b は交換形式 9 の出力（ソースからは常に false）。D6c は属性の受理と E0817・文書で、受理した時点から判定を必ず適用するという条件を保つ。
8. CoverageView を作るためのモジュールの情報: typeck の Body（context.rs:50）にはモジュールの欄がない。修正案: D5 で、本体の持ち主の束縛から module を引くのか、Body::new に渡すのかを決めて書く。check_match・check_binding は統合テスト tests/coverage_export.rs が公開 API として使っている。シグネチャを変える作業に、このテストを含める。
9. 選ばれない分岐を含むプログラムの実行: これまでは E0602 が誤りなので、型検査を通ったプログラムに選ばれない分岐は無かった。外部から書く「全既知構成子 + case other」は、初めてその形で後段（ir/decision.rs の count==0 の本体の省略、liveness、refinterp、desugarDiff）へ進む。壊れるかどうかは確かめておらず、推測である。修正案: D8 に、この形を実際に実行する golden と `--test random_programs` を加える。
10. plan D7 の検査に `--test package_command` が無い: testdata/packages の pure-json・wasm-json は、外部のパッケージとして Json.ParseError を作り、返している。

【軽】
11. plan D5 の AdtDef の構築箇所: ir/check.rs:1473・1505、ir/decision.rs:1824・3506、types/mod.rs:867、typeck/patterns.rs:1189・1353 も直す必要がある（コンパイラが知らせる）。
12. coverage_export の 1 万件の乱択の入力は、型を拡張可能にするかどうかを変えていない。入れ子の将来の形を差分検査で確かめるため、乱択に extensible の印を加えるとよい。
13. 診断の表には E0602 しか書いていないが、選択肢の中の選ばれない形 `case A | other` の E0608 も同じ扱いにすると明記する。
14. A2 は、フォーマッタにキーワードの表が無く（roles/walk.rs に KwEnd などが数箇所あるだけ）、段 1 では die を受理しないので、実際の作業がほとんど無い。A1 か A3 へ併せるか、行うことを具体的に書く。A1 で、まだ受理しない `or die` を勧める help を加えない、とも明記する。
15. E0601・E0607 に、標準ライブラリのソースの宣言を副位置として付けるとき、組み込みのソースの位置が文章と JSON に正しく描画されるかを確かめていない（推測）。D6 で golden を一件確かめる。

## 段 3 B2・移行（B1〜B14、B10a、M1〜M9、M6a）

【重大】
1. `or return` の後で改行しても文が終わらない。design.md「文法と式の境界」の最後の段落（「改行継続は現行の規則を保つ…処置の return/die の後の改行は文を終える」）、plan B6・B7。いまの改行の規則では `return` の後の改行は継続になる（crates/benitoite/src/syntax/newline.rs:175 の `continues_after` に `K::KwReturn`、220 行）。このため `bind x <- try r or return` の次の行が同じ式に取り込まれ、E0258 などになる。B6 は `or return` を本番で受理するので、B6 の時点で複数行の普通の使い方が壊れる。「現行の規則を保つ」と「return の後の改行は文を終える」は両立しない。修正案: 「`or` の直後の `return` は継続しない」という字句の規則を design に明記する。B7 ではなく B6 に newline.rs の変更と改行の正負の表を入れる。`die` は `continues_after` に入れないことも書く。
2. die を受理する前の作業（B6〜B10a）が、die の経路を検査できない。plan B6・B8・B10a、B12 の「新しいフラグや公開 API をテストのためだけに足さない」。B6 で `TryAction::Die` を足すが、parser が受理するのは B11 からである。それまで resolve・typeck・desugar の Die の分岐が何をするかが決まっていない。B10a の完了の条件は「各分岐の実装を完成」だが、`cargo test --lib typeck::` は parse から始まるので Die に届かない。B8 の CLI と test runner の描画も本物の入口では確かめられない。修正案: B6 の時点では Die の分岐は InternalError を返す、`#[cfg(test)]` の parser の補助だけが die を受理してよい（テスト専用の公開 API に当たらない例外として書く）、と plan に明記する。あるいは B10a と B11 を「cfg(test) で入力する typeck」「desugar と IR」「本番での受理」の 3 作業に分け直す。

【中】
3. `.value` だけを辿る走査が多く、説明の式を黙って落とす（欄を足してもコンパイルの誤りにならない）。計画が挙げていない走査: runtime/assert.rs:611、typeck/effects/tail.rs:38,63、typeck/consts.rs:249,417,900、tests/random_programs/shrink.rs:171、examples/named_inventory/index.rs:214、examples/named_arguments_inventory.rs:341。tail.rs の `escape()` は `Expr::Try(_) => true` で、die は抜け出しではなく exit の呼び出しなので扱いを決める（直接の Process.exit と揃えるなら value と説明の式を辿る）。修正案: B6 に `git grep "Expr::Try\|TryExpr"` の一覧を載せ、走査は `TryExpr { value, action, .. }` を分解する形で書かせる。
4. import の名前が実態と違う。design.md の例と「AST・フォーマッタ・名前解決」の最後の文（`import Benitoite.IO.Process`）。正しくは `import Benitoite.Unofficial.IO.Process` など（prelude/mod.rs:161、docs/reference/benitoite.md:981）。die を書いた利用者は Process を import していないことが多いのに、E0501 の help（diag/codes.rs:812）は `uses Process.Exit` を足す案内だけで、従うと名前解決の誤りになる。修正案: 例と本文を直し、die による E0501 では import も案内すると決め、B11 の担当にする。
5. 「両構成の all-targets」が同じ構成を二度走らせる。plan「作業とレビューの順序」の表の後の段落（B14・M7）。Cargo.toml は default = ["gc-mark-sweep"] なので二つは同じ。修正案: 二つ目を check.sh と同じ `gc-mark-sweep,heap-verify`（または gc-stress）にする。
6. M3 の検査にゴールデンテストがない。診断の修正例 `E0201 question: "... such as \`try parse(text)\`"`（codes.rs:223）は testdata/lexical/unknown_symbol.diag.json に入っている。M3 で直すと golden と diag/render/help_tests.rs が落ちる。修正案: M3 の検査に `--test golden` を足し、この help を明示形に変えるかを R1 に書く。
7. 説明の中の脱出の診断の持ち主が決まっていない。E0218 は parser の check_escape（parser/effects.rs:474）で、文脈の鍵は lazy_body と guard だけ。resume の禁止は typeck の E0509（codes.rs:835）の受け持ちで、design の「resume も E0218」は既存の分担と食い違う。修正案: 新しい文脈の鍵（例: die_message）、説明文の更新、resume のコードを design で決め、入れる作業を一つに決め、触るファイルに diag/codes.rs・parser/effects.rs・gen_skill を加える。
8. B10・B10a・B11 は大きすぎ、担当も重なっている。TryInfo の Return/Die と解決の順は B10a と B11 の両方にある。B10 だけでも VM と IO の二方式、refinterp、四型、5 章の文書を含み 60 分に収まらない見込み（推測）。修正案: 作業ごとに持ち主を一つにして分割する（例: B10 を VM・IO の所有と四型の Show に分ける）。
9. E0908 の「変更ごとの help」を作る手段がない。DiagBuilder の note と help は静的な鍵の型板で、引数を全体で共有する（diag/mod.rs:224-235）。既存の検査も help が 1 件で固定の文言であることを確かめている（modules/tests.rs:69-76、codes.rs:1012-1014、testdata/packages/older-language.diag.json）。修正案: 方式を design で決める（例: 組み立てた後で Diagnostic.notes・helps に modules::text の文を足す）。説明文の「earliest」も直す。

【軽】
10. design.md「文書と生成物の更新先」の表に 06-04（test runner の結果の表と JSON）、06-01（CLI の報告）、06-09（language と E0908）がない。
11. R1 は標準ライブラリのソースにある裸の try（stdlib/IO/File.bnt:68、Network/Http.bnt:73,80）の扱いを分類していない。
12. IOError・NetworkError（prelude）が Trait を import すると、どのプログラムも Trait（526 行）を毎回読み込む。B10 で起動時間を短く測ることを勧める。
13. CLI での die の報告と、解放の失敗の報告の順が決まっていない。いまは main_error を reports より先に書いている（cli/mod.rs:747-752）。
14. 交換形式の版を決め打ちしている検査がある（formal/tests/test_width_exchange.py:72 の version 8、test_named_exchange.py:115 の旧い版 7）。B4 で直すファイルとして挙げる。
15. 新しく作る tools/source-migrate/ と tools/try-actions-migrate/ について、AGENTS.md のディレクトリの表を直す作業がない。check.sh の python の検査は決め打ちの glob なので、新しい道具は構文の検査にもかからない。
16. design の「空行を越えて次の文の括弧を取り込まない」は、空行のない改行なら取り込むようにも読めて「改行は文を終える」と食い違う。「改行を越えて」に揃える。


## 対応

2026-10-15、現行ソースと改造文書を照合して以下を反映した。実装・処理系のテストの実行によって指摘の危険を再現したという記録ではない。全 31 件を文書へ反映し、指摘自体を不適合として退けたものはない。選択肢のある指摘は R9〜R18 の推す案で具体化し、設計者の回答済みとは扱わない。既存の作業 ID は親の完了確認としても残し、実装 47 作業と親の完了確認 4 件へ整理した。README.md の作業数などは前回の文書作成の記録を保ち、今回の計画と推奨案は plan.md・design.md・decisions.md を正とする。

### 準備・段 1 A・段 2 D

| 指摘 | 直した箇所・方針 |
|---|---|
| 重大 1 | R9、design「変更する型と受け渡し」「判定の手順と診断」「形式化と受け渡し」、D1/D3/D6a/b に Future/future、DataName の型表示表と網羅性 3 の必須欄を追加し、型名は AdtDef.name、help は future_ty として E0607 の ty から分離した。 |
| 重大 2 | D3/D6b に check_named.py・exchange-manifest.json・Rust の各版の出力元を明記し、通常の width/named の固定入力は新版へ、旧版の閉じた正の入力と新版の欄を混ぜた負の入力は互換入口の独立検査へ分けた。 |
| 重大 3 | R10 と design「形式化と受け渡し」で D2a/b/c に分割し、CheckPatterns/CheckLemmas/CheckTablesSound/Check と全 declarations 参照、view に依存しない補題、record 更新/getter/try の閉じた検査を明記した。 |
| 中 4 | A1 に git grep -n KwTry の全 14 件の確認表を追加し、decls/types/exprs/lexer の非網羅の列挙、KwDie、is_keyword への追加と continues_after への非追加を明記した。 |
| 中 5 | R11、design「属性の文法と適用先」、D6c で構成子の前の属性は解析せず E0201 を保つ案を採り、E0802 の適用先から外した。 |
| 中 6 | D7 と design「形式化と受け渡し」に generate.rs・skill/tests.rs・06-06 を追加し、public の前には @extensible だけを出力する規則とした。 |
| 中 7 | R12、D6a/b/c、G3a/b に判定/交換/受理を分け、型表の直接入力→属性 false の通常出力→受理と同時の判定の順を定めた。 |
| 中 8 | R12 と design の型変更表、D5/D6a で Body::new に ModuleId を明示的に渡して保持する案を選び、内側の文脈と coverage_export の公開 API の呼び出し元も更新対象にした。 |
| 中 9 | D8 に全既知構成子 + case other を実行する golden と --test random_programs を追加し、decision の枝の省略・liveness・refinterp・desugarDiff までの確認を指定した。 |
| 中 10 | D7 の検査に --test package_command を追加し、pure-json/wasm-json の ParseError の構築・返却を含めて確認する。 |
| 軽 11 | D5 の構築箇所に ir/check.rs・ir/decision.rs・types/mod.rs・typeck/patterns.rs と全 AdtDef 構築元を明記した。 |
| 軽 12 | D6a の coverage_export の 1 万件の乱択に extensible/view を加え、入れ子の将来の形の差分を確認する。 |
| 軽 13 | design「判定の手順と診断」と診断表、D6a に E0608 と E0602 の共通の view と、本物の重複だけを拒否する条件を明記した。 |
| 軽 14 | A2 を既存の整形/診断の具体的な確認作業へ直し、差分不要なら根拠を記録する形にした。A1/design に未受理の or die を help で案内しない条件も加えた。 |
| 軽 15 | design「判定の手順と診断」、D7 に標準ライブラリの宣言を副位置に持つ E0601/E0607 の文章/JSON の golden を指定した。標準の属性を導入して本物の入力が作れる D7 に置く。 |

### 段 3 B2・移行

| 指摘 | 直した箇所・方針 |
|---|---|
| 重大 1 | R13、design「文法と式の境界」、B6 で or の直後の return の改行を文末にする例外と正負の表を受理と同時に追加し、通常の return の継続と括弧内の省略は維持した。 |
| 重大 2 | R14 と B6/B8/B10a-1〜3/B11/B12 で Die の追加を B10a-1 へ遅らせ、cfg(test) の内部の parser の補助から型/脱糖を検査し、本番受理前の暫定処理と本物の入口の証拠を区別した。 |
| 中 3 | B6 に全 Expr::Try/TryExpr のファイルの確認表、B10a-1 にその再点検を追加し、runtime/assert・tail・consts・shrinker・inventory を含む説明の走査と Return/Die の tail の違いを design に定めた。 |
| 中 4 | design の本文と例を Benitoite.Unofficial.IO.* へ直し、B11 と診断表に die の E0501 の uses/import（または既存の別名）の両方の案内を指定した。 |
| 中 5 | plan の段末の all-targets を既定と gc-mark-sweep,heap-verify の二構成へ直し、同じ構成の重複を除いた。 |
| 中 6 | R1 に E0201 question の明示 return の help を指定し、M3 に unknown_symbol.diag.json・help_tests.rs と --test golden を加えた。 |
| 中 7 | R15、design「型・エフェクト・書く位置」と診断表、B10a-1 に InDieMessage、E0218 の return/try、E0509 の resume、各 die_message の help・説明文・gen_skill の担当をまとめた。 |
| 中 8 | R16、B10-1〜3/B10a-1〜3 と G5a/b で VM/Direct・Request/採用・Show・型・脱糖・交換を分割し、B11 は本番受理と本物の入力の統合確認だけを担当する形にした。 |
| 中 9 | R17、design「E0908・TODO-252・0.0.6」、M6 で build 後の Diagnostic.notes/helps へ modules::text の文を加える方式を選び、earliest の説明と一件固定の検査も更新対象にした。 |
| 軽 10 | design「文書と生成物の更新先」に 06-01・06-04・06-09 を加え、B8 に CLI/test runner の章、M6 に language と診断の章を割り当てた。 |
| 軽 11 | R1/P1/M4 で標準ライブラリの IO/File・Network/Http などの裸の try を再利用する実装として分類し、契約を保った or return と生成物の更新を指定した。 |
| 軽 12 | B10-3 に prelude からの Trait の常時読み込みの起動/検査時間の短い比較を指定し、benchmark スキルに従って条件と結果を記録する形にした。今回は測定しない。 |
| 軽 13 | R18、design「終了・報告・テストの実行器」、B8/B12 で転送後に die→reports の順とし、文章/JSON と終了状態 1 を本物の入力で確かめる計画にした。 |
| 軽 14 | B4 に test_width_exchange.py・test_named_exchange.py・固定入力の新版/旧版の役割を明記し、B10a-3 の Rust の corpus 10 の切り替えでも manifest と check_named.py を揃える。 |
| 軽 15 | M1/M2 と design「サンプルの移行の道具と確認表」に AGENTS.md のディレクトリ表、check.sh の Python の glob・変更分類・自己検査の登録を追加した。 |
| 軽 16 | design「文法と式の境界」を「改行を越えて」に統一し、説明の開始括弧は同じ物理行、括弧内は通常の継続、短い lambda は既存の物理行の条件とした。 |

設計者に尋ねる価値が大きい点は、R13 の利用者に見える改行の文法と R18 の複数の失敗の報告順である。以前からの R2（record への属性の意味と将来の拡張の保証の差）も実装開始時の確認点として維持する。ここでは推す案を設計と計画へ反映し、回答を得たことにはしない。

文書の検査: 元の 39 個の作業 ID の保持、枝を含む 47 作業と親の完了確認 4 件、R1〜R18 の連続性、対応表 31 行、必須欄・依存の順・相対リンク・コードブロック・表の列数を確認した。`scripts/check.sh --dry-run` は文書のみの変更と判定し、続く `scripts/check.sh` は成功した。`git diff --check` も通った。処理系のビルド・テスト・Lean の検査を実行したという意味ではない。

# R40.3: 報告の接点・生成物と段の閉鎖

## 作業と状態

B_WORK と対象 HEAD は `867a36713aa30520be4d5ea8dff0d57b846c919c`、ブランチは `m013/r40.3`、B_STAGE は `c2debc9200e7db6aacf4dde10b94eaf330270654` である。開始時は差分なしであった。[開始状態](start-state.json)に基準と index のハッシュを保存した。実装・通常検査・接続の判定と、取りまとめが行う独立レビュー・受け入れを区別する。検査の確定値は末尾に記す。

AGENTS.md、共通依頼文、計画の指定節、README の決定、前段の結果・レビューを読んだ。`private/`・`docs/todo/` と private を指すスキルは読んでいない。公開の test-audit の作成時の関門と japanese-tech-writing に従った。git の状態を変える操作、依存・scripts・formal の変更は行っていない。

## 変更と全接点の照合

前段の必須修正は R40.1b と R40.2b に実装され、各結果に通常検査の成功が記録されている。RV-R40.1 の中1〜中3・軽1〜軽8、RV-R40.2 の中1・軽1〜軽3・参考1の未修正を見つけなかった。参考2の 06-06 は今回そろえた。前段の失敗・修正の記録は変更していない。

| 接点・対象 | 通常の検査・報告 | test と集約 | 証拠・限界 |
|---|---|---|---|
| 非 Top・Top・純粋・同名の冗長な原子 | 名前は expanded、構造上異なる宣言原子は bounds。Top は all、純粋は空 | 各契約と aggregateEffects も同じ形。複数範囲と Top を被覆で間引かない | 固定入力 pure/top/non-top/redundant、既存 `declared_bounds_preserve_normal_forms_in_all_report_readers`。本体が空でも宣言上限を保持 |
| File.Read 13・File.Write 16・Http.Connect 2 の全操作 | 完全な3例は空、各一節を欠く31例は同じ名前と範囲を残す。上限も省くと E0501 | 同じ34例の各 test と集約が独立期待値に一致。名前だけの上限は受理、空の上限は E0512 | W-40 の `complete_handler_names_and_every_missing_clause_reach_reports_and_limits`。保護関数は宣言上限付きの純粋本体であり、全操作の実 IO を行った意味にはしない |
| 固定範囲の利用者操作の値引数から実際の標準 IO へ渡す例 | Report.save の節で File.writeTextIn を呼ぶ契約は File.Write の木 `/data/reports` だけ | 通常 test と純粋な別ファイルを加えた集約にも同じ原子だけが残る | 新しい `handled_user_value_preserves_only_the_scoped_io_contract`、[固定ソース](inputs/handled-scoped-write.bnt)。非実行検査だけであり `/data` に書き込まない |
| 処理済みの利用者名、利用者の範囲引数、未処理の利用者原子 | 処理後に純粋なら空、File へ渡すなら標準の原子だけ。範囲引数は E0513、未処理は E0506 | 成功の名前集合・bounds・集約に利用者名を戻さない。拒否時は集約 null | handled-user-pure/handled-scoped-write/user-unhandled/user-scope-rejected。UB20.02 の最終読者の未確認のうち報告側を閉じる |
| 四理由と修正案 | E0519 の notCovered/atomicCoverOnly/unknownSource/budgetExceeded を通常の JSON Lines と単一報告で保持 | test の報告でも同じコード・理由、complete:false・集約 null | [固定入力の照合](handoff-check.json)、W-40 の診断の二つの表。戻り注釈、入れ子から bind、狭い引数から範囲付き IO、呼び出し元での拡大も前段の修正を保持 |
| 資源停止の主文 | readBytesIn の metadata による R0903 は実際の入口名 | 同じ入力を test で実行し、failure.code が R0903、主文が run と同一 | 既存 `scoped_file_input_limit_reports_the_called_operation` を補強。sparse file の長さは1 GiB+1、内容は読まない。readTextIn の1 GiB超の内容を読む停止、書込み失敗理由の確保も失敗する二重失敗は強制していない |
| doc の例と解析未完了 | 未完了は Effects 全体が null。確定した未知対象は all | 期待した error 例は空の Effects を返すが純粋を意味しない。check/error は実行用の集約へ加えない | doc-error、既存の doc/test 報告の表、06-01・06-04。拒否を純粋と説明しない |
| 名前だけの受け手と名前による照合 | 任意 bounds を無視しても各名前の全対象の上限が残る | 通常/test の上限照合の成功と E0512、範囲付きオプションの使い方の誤りを保持 | `scoped_allow_effect_arguments_are_usage_errors_before_execution` と旧読者の既存テスト。範囲による実行時の拒否へ意味を変えていない |
| Show の判断 | RequestCheckError の直接 Show は E0705、構成子の match と内側 ScopeError の Show は受理 | 同じソースの test --check も同じ受理／拒否 | show-rejected/show-match。標準 Show を加えない R40.1 の判断を保つ |

新しいテストは、固定範囲の値引数を持つ利用者操作から標準 IO へ渡すとき、CLI の所有契約への抽出で標準原子が消える、または利用者名が復活する退行を守る。純粋に再開する既存例だけではこの接続を守れない。資源停止の補強は test の失敗報告へ渡す際の名前の欠落を守る。いずれも実 CLI の観察可能な契約であり、本番の差し込み口を加えていない。新しいテスト関数は1件、既存テストの補強は1件、削除は0件である。

## 由来の追加欄の境界

`inspection::function_contract` は確定した Scheme から標準原子を所有し、名前の ID 集合を照合へ、EffectSummary を報告へ渡す。`function_contract` は利用者原子や不正な添字を内部エラーとし、`file_origins` は E0512 の補助位置だけに使う。標準原子の和へ由来の名前を追加する処理はない。

通常の `main_value` と test の `inspect_value` は `bounds.value()` を使い、集約も同じ EffectSummary の構造上の和を使う。診断の source は notes に残り、effects とは別である。固定入力の照合では、対象の sourceId、sourceSets、sources の全バイトの SHA-256 が元入力と対応することも確認した。AST と型表の破棄後に名前だけから由来を復元していない。

後の任意の由来欄は今回追加していない。既存の受け手が追加説明や bounds を無視しても、expanded の保守的な名前上限を得る境界を保つ。将来の説明に利用者名を載せることと、その名前を許可の集合へ加えることを区別する。交換の user/prim/fail の分離、新版の読者と manifest、六入口の比較は K10.1/.2/.3 に残す。報告側のこの結果と固定入力を UB30 へ渡し、交換まで確認済みとはしない。

## 説明の範囲・生成物と参照

| 説明する場所 | 確認した範囲 |
|---|---|
| 01-07 の閉じた範囲、02-05 の必須判定、02-10 の診断 | 型・エフェクトの規則と宣言上限である。包含を確認できない拒否を「対象が必ず範囲外」と説明せず、診断の source を許可へ加えない |
| 06-01・06-04 の報告 | basis は declaredUpperBound。Top と null と純粋な空を分け、error の doc 例の空も純粋としない。endpoint は host/port だけで scheme・内容の契約ではない |
| 06-06 のハーネスが読む欄 | expanded/bounds の役割、作り手の規則、任意欄のない報告を名前の全対象として読む受け手の規則を追加した。従来の「エフェクトは種類だけ」という文も範囲付き原子と一致するよう直した |
| 同梱 Skill | inspection.md に bounds と診断の由来の分離、source のハッシュが後の実行内容を固定しないことを明記した。SKILL.md と idioms.md の狭い引数の案内を、範囲付きの IO への転送、または由来のある呼び出し元での拡大へそろえた |

型の範囲を実行時の権限・実体の隔離・情報フロー制御と説明する記述を加えていない。endpoint を固定 origin と同一視せず、DNS・OS の変換・TLS の副次的な通信を型の対象保証へ含めない。新しい用語・範囲の規則・JSON の意味や版を定めていない。

`gen_skill` を実行し、既存の生成元と生成物の一致を確認した（[記録](gen-skill.json)・[ログ](gen-skill.log)）。今回の変更は手書きの説明であり、生成物の内容差分はない。W-40 でも生成物の照合に成功した。設計書に作業 ID は書いていない。W-40 後の実 CLI の `skill show` でも、手書き・生成文書7件について本文・JSON の text・byteLength・contentHash が生成元と一致した（[照合](embedded-skill.json)）。SKILL.md の版の型板だけは既存の規則に従い実行ファイルの版へ置き換えて比べた。

既存の必須欄・受け入れ規則への参照は `v0.0.12` に固定したままで、追加の bounds と今回の診断案内は実行ファイルに同梱する文書を正とする。[版固定の照合](pinned-reference.json)にタグの完全 ID、参照先 blob と SHA-256、4か所の参照を残した。タグ内の Inspection reports・Interval analysis coverage・Local interval warnings の見出しも確認した。未公開のタグへリンクせず、通常文書・訳・最終版の整合と固定参照の更新は V10 に残す。

## K10 と候補 CLI への受け渡し

[handoff.md](handoff.md) に25入力のファイル・期待値・SHA-256、[handoff.json](handoff.json)に機械で読める独立期待値、[handoff.sha256](handoff.sha256)に一覧そのもののハッシュを固定した。期待値は処理系の出力から作らず、公開契約から先に定めた。通常・test・集約・doc と四理由の JSON Lines を含む53コマンドの実出力は [handoff-check-reports/](handoff-check-reports/) に残す。期待値だけを書き換えず、相違は入力・理由・後続の判断とともに返す。

K10.1 は13署名・認定表・具体化列・corpus15/sidecar7・scopeAcceptance/limits を接続する。K10.2 は固定入力を非 Top と拒否を含む比較へつなぎ、必須判定の四理由の直接比較と、効果上限の atomicCoverOnly に対する Rust E0519／Lean の型付け拒否を分ける。今回の atomic-cover-only は後者の入力であり、「両者が同じ四理由を返した」と扱わない。番号付け停止、最後の Run と内側だけの超過、既知不良 E0459〜E0462、U+0000、同じ要求と保持 endpoint の観測、形式化の限界は従来の申し送りを保つ。K10.3 が六入口・区間・profile/VM 等を含む全比較を閉じる。

## 初回の失敗と修正

固定入力の初回は53コマンド中46一致・7不一致だった（[記録](handoff-check-initial.json)・[全出力](handoff-check-initial-reports/)）。不足する上限の3入力は、入力作成器の一括置換が保護関数の上限も消したため、想定した E0501 を生じなかった。main と test の宣言だけから上限を除く形に直した。doc の拒否例は fence の後にコードを書いたため E0260 となったので、既存の error と diagnostic の二つの fence へ直した。

いずれも処理系の不具合ではない。初稿の25入力と一覧・作成器を [initial-inputs/](initial-inputs/) に残し、[訂正の照合](input-corrections.json)で4ソースの変更と期待値の変更0件を記録した。最終は53コマンドすべて一致した（[確定した照合](handoff-check.json)・[修正後の最初の計時](handoff-final.json)）。W-40 後にも同じ固定入力を実 CLI へ通し、最後にビルドした実行ファイルで一致を確認した（[計時](handoff-after-work.json)）。本番の規則・期待する拒否・入力規模・予算・ignore は変更していない。

06-06 のリンク追加時に、見出しでない文の先頭を anchor とした初稿を読解で見つけ、既存の「main の非実行の検査報告」の anchor へ訂正した。補助のリンク照合は初回にインラインコードの関数型をリンクと誤認し、コード部分を除く形へ直した。同梱文書の補助照合も初回に SKILL.md の版の型板を置換前のまま比較したため不一致となり、既存の render_document の規則へそろえた。これらは本番の不具合や W-40/S-40 の失敗ではない。正式検査の失敗と再実行の有無は、末尾の確定値に記す。

## 探査・範囲・申し送り

公開構造は変更しておらず、比較器の追随修正は不要である。README の自己検査を一度実行し、39件成功・終了0・外側97.958483125秒だった（[記録](compare-selftest.json)・[ログ](compare-selftest.log)・[time](compare-selftest-time.log)）。[両版のビルド記録](probe-builds.json)に開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK のコマンド・API 判定・実行ファイルと探査の SHA-256 の一致を残した。独立 IR・グラフと bridge-shared-8 の検査を含み、性能の標本採取ではない。

`check-formal.sh`・`lake build`・short の性能比較は実行していない。前段の short の要約は [段の結果](../r40/results.md)と [集計](short-summary.json)に置く。今回の手書き Skill は実行ファイルに埋め込まれるが、検査・実行の本体の規則と公開 API は変更していない。取り込み後の M の要否と段の性能の判断は取りまとめへ渡す。

新しい CARGO_TARGET_DIR は設定していない。比較器の基準版の展開・ビルドは既存の `target/bench/` の下にある。自己検査と CLI テストの一時ディレクトリは終了時に削除され、target 外の一時ビルド・基準版の展開は残っていない。保存する入力と出力は本ディレクトリに置き、work/reference を根拠として参照していない。手元のパスは `<wt>`・`<home>`・`<tmp>` に伏せる。

変更は許可された crates と06-06、本ディレクトリ、および依頼で明示された `r40/results.md` に限る。Lean の意味・信頼条件・公開契約・保証の変更を必要とせず、前段の通常検査の失敗・仮置き・必須修正を持ち越す停止条件にも該当しない。外した構成・32ビット・外部ハンドラの件数、E0521 の自然な上限到達例と案内の解消効果は未確認のまま V10 へ渡す。独立レビューと受け入れは取りまとめが行う。

## 検査の確定値と時間

正確なコマンド・開始／終了時計・直接の終了状態・外側時間・RSS の原値は、各 JSON に保存した。`run-record.py` が検査を直接の子として起動し、check.sh の returncode を `checkExitCode` に記録する。この記録器を `/usr/bin/time -p` で包み、time の出力は別ログへ残した。`time -l` は使っていない。

```sh
scripts/check.sh --level work --base 867a36713aa30520be4d5ea8dff0d57b846c919c \
  --test cli_process --test test_command --test golden --test spec_examples \
  --test reference_examples --test skill_docs --test package_command --test desugar_export

scripts/check.sh --level stage --base c2debc9200e7db6aacf4dde10b94eaf330270654 \
  --only tests_related --test runtime_builtins --test vm_handlers --test io_modes \
  --test l32_http_client --test network_faults
```

それぞれ同じ指定に `--dry-run` を付けた確認も終了0である。[W-40 の選択](work-dry-run.log)は fmt、既定構成の lib/tests/examples の clippy、lib 全件、指定8統合対象、source_rules、skill_generated、spec_tally だった。[S-40 の選択](stage-dry-run.log)は指定5統合対象を実行する tests_related だけだった。Lean・依存の検査は選ばれていない。

| 検査・作業 | 直接の終了 | 外側の時間（秒） | time -p の real（秒） | 記録 |
|---|---:|---:|---:|---|
| 固定範囲の利用者操作から IO への局所 CLI テスト | 0 | 9.179701 | 9.20 | [JSON](local-user-io.json)・[ログ](local-user-io.log) |
| run/test の資源停止の主文の局所テスト | 0 | 4.914254 | 4.94 | [JSON](local-resource.json)・[ログ](local-resource.log) |
| gen_skill | 0 | 0.769193 | 0.80 | [JSON](gen-skill.json)・[ログ](gen-skill.log) |
| 固定入力の初回53コマンド | 1 | 5.341752 | 5.37 | [JSON](handoff-initial.json)・[ログ](handoff-initial.log)。上記の入力の誤り |
| 固定入力の修正後53コマンド | 0 | 5.199400 | 5.22 | [JSON](handoff-final.json)・[ログ](handoff-final.log) |
| 比較器の自己検査 | 0 | 97.958483 | 97.99 | [JSON](compare-selftest.json)・[ログ](compare-selftest.log) |
| 整形 | 0 | 6.035458 | 6.09 | [JSON](format.json)・[ログ](format.log) |
| W-40 の dry-run | 0 | 0.271615 | 未計測 | [JSON](work-dry-run.json)・[ログ](work-dry-run.log) |
| W-40 | 0 | 231.409172 | 231.44 | [JSON](work.json)・[ログ](work.log)・[time](work-time.log) |
| S-40 の dry-run | 0 | 0.031535 | 未計測 | [JSON](stage-dry-run.json)・[ログ](stage-dry-run.log) |
| S-40 の残る五対象 | 0 | 39.972322 | 40.01 | [JSON](stage.json)・[ログ](stage.log)・[time](stage-time.log) |
| W-40 後の実 CLI による固定入力の再照合 | 0 | 5.164236 | 5.19 | [JSON](handoff-after-work.json)・[ログ](handoff-after-work.log) |

W-40 と S-40 の正式検査はそれぞれ一度で成功し、失敗や再実行はない。途中の局所テストも初回で成功した。各局所作業の time の原出力は同名の `*-time.log` に保存している。

| W-40 の対象 | 成功 | 失敗 | ignored |
|---|---:|---:|---:|
| 既定 lib 全件 | 1,392 | 0 | 22 |
| cli_process | 46 | 0 | 0 |
| desugar_export | 44 | 0 | 1 |
| golden | 2 | 0 | 0 |
| package_command | 16 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| skill_docs | 8 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |
| test_command | 52 | 0 | 0 |

統合8対象は176成功・1 ignored、lib と合わせて1,568成功・23 ignored、失敗0件だった。fmt・clippy・source_rules・skill_generated・spec_tally も成功した。ignored は既存の長い対象と形式化の全書き出しであり、今回増やしていない。[件数](work-counts.json)は Cargo のテスト関数の件数であり、golden などの内部ケース数とは区別する。

| S-40 の対象 | 成功 | 失敗 | ignored・除外 | 実行または引用 |
|---|---:|---:|---:|---|
| runtime_builtins | 29 | 0 | 0 | 今回実行 |
| vm_handlers | 5 | 0 | 0 | 今回実行 |
| io_modes | 13 | 0 | 0 | 今回実行 |
| l32_http_client | 14 | 0 | 0 | 今回実行 |
| network_faults | 3 | 0 | 0 | 今回実行 |
| cli_process | 46 | 0 | 0 | W-40 を引用 |
| test_command | 52 | 0 | 0 | W-40 を引用 |
| golden | 2 | 0 | 0 | W-40 を引用 |
| 合計 | 164 | 0 | 0 | 五対象64成功＋引用100成功 |

残る五対象の [件数](stage-counts.json)と生ログで64成功・失敗0・無視0・測定0・除外0を確認した。R30 の古い結果は引用していない。これは計画の S-40 の対象を満たす判定であり、stage の名指しの部分選択の終了0を stage 全体の完了と呼ばない。

### W-40 の三対象を引用する根拠

[07-03「結果の保存と引用」](../../../design/07-quality/07-03-compiler-testing.md#結果の保存と引用)の全欄を次のとおり保存した。

| 欄 | 状態・根拠 |
|---|---|
| 基準・対象 HEAD | W-40 の B_WORK と対象 HEAD は `867a36713aa30520be4d5ea8dff0d57b846c919c`。引用先 HEAD も同じ、S-40 の B_STAGE は `c2debc9200e7db6aacf4dde10b94eaf330270654` |
| 差分の有無と一覧 | 未コミットの追跡差分は Skill の3文書、scoped_diagnostics.rs・scoped_reports.rs、06-06 の6ファイル。未追跡の検査入力は handled-scoped-write.bnt の1ファイル。[入力一覧](work-inputs.json.gz)に各全文の大きさと SHA-256 を保存。結果・台本・ログは別の成果物である |
| 未コミット差分・未追跡入力のハッシュ | [保存差分](work-inputs.patch)は23,914 bytes、SHA-256 `23a2d947c26be5b54b7255b37056ba3fa43f596e051eb13eb19e2e98f2765617`。未追跡の fixture の全文ハッシュも上の一覧と handoff.json に保存した |
| 検査の入力 | ソース・テスト・入力と期待値、標準宣言・生成元/生成物、設計書・通常文書・訳、設定・Cargo manifest/lock・固定版・scripts・比較器等4,286ファイルを記録。[最終照合](final-inputs.json.gz)で全ファイル・差分・道具・HEAD/ブランチ/index の一致を確認した |
| 実行 | 上記 W-40 の正確な指定、既定 gc-mark-sweep、フィルタなし、cli_process/test_command/golden の100成功・失敗0・無視0・測定0・除外0を引用。元の lib と他統合を S-40 の対象として水増ししない |
| 道具・環境と制限 | macOS27.0.1/arm64、rustc1.98.1 `48a229ceaefd4985c50990b14116b6d856af0985`、Cargo1.98.1 `797e8a9bc`、Python3.9.6。設定と道具の記録は入力一覧、実行時の記録器の全文とハッシュは [計測の道具](measurement-tools.json)と [その写し](run-record-at-checks.py)に保存。外した構成・32ビット・全 OS・実候補・Rust/Lean 全比較はこの引用の対象外 |
| 終了・時間・RSS・失敗 | 元の W-40 は check.sh 自身の終了0、外側231.409172458秒、time real/user/sys=231.44/1131.64/38.80秒。RSS は下記。正式検査の初回失敗・修正・再実行なし。入力準備の初回の失敗は上に別記した |
| 元結果・以後の変更・判断 | 元結果は work.json/work.log/work-counts.json。以後は結果と補助記録だけを変更し、関係する入力・期待値・生成物・設定・道具へ影響しない。担当 Codex が2026-10-29に同じ関係状態として引用を判断した。独立レビュー・取り込み後の引用の再判定は取りまとめが行う |

### 最大常駐量と所要時間

W-40 の最大常駐量の補助値は2,378,170,368 bytes = 2,268 MiB = 2.21484375 GiB、S-40 は1,382,416,384 bytes = 1,318.375 MiB = 1.287475586 GiBである。macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` による子孫の最大値であり、同時常駐した全プロセスの合計ではない。`time -p` 自体は RSS を表示しない。二つの値を合計しない。自己検査などの値も各 JSON に原値・単位・方法を残した。

着手時の規約と計画の読解の開始時計は採取していない。最初の時計は2026-10-29 10:32:20 UTC（19:32:20 JST）であり、それ以前に読解を始めている。入力の最後の一致確認は10:46:31 UTC（19:46:31 JST）で、取得時計間は約14分11秒だった。先行する読解と記録の仕上げを含む外側の所要は約20分、担当1人の能動時間は約15〜20分の概算である。厳密な能動時間の分離計時は行っていない。正式検査は W-40 約3分51秒と S-40 約40秒、自己検査は約1分38秒で、文書の作業と一部重なるため単純に足さない。その他の局所検査・生成・固定入力の照合は各記録に分けた。設計者の回答待ちはない。計画の2〜5時間と上端の2倍10時間の停止基準を変更しておらず、時間による中断はない。

最終の補助照合は、まだ自分が生成していない verification.json のリンクを先に要求して停止したため、その一ファイルだけは書き出し後に存在を確認する順序へ直した。さらに比較器のログに OS の一時ディレクトリの接頭辞が残ることを検出し、`<tmp>` へ伏せた。置換前後の大きさ・ハッシュと置換件数は [伏せ字の記録](redaction.json)に残した。検査の内容・終了・時間は変えていない。

最後の [照合の台本](verify-delivery.py)と [結果](verification.json)に、実 CLI の文書、固定入力、相対リンク、変更範囲、伏せ字、git diff --check の終了0を残す。[段の結果](../r40/results.md)を作成し、独立レビュー・取り込み・受け入れ、K10 の全比較と V10 の最終照合へ渡す。


## R40.3b: RV-R40 の対応（2026-10-29）

B_WORK と対象 HEAD は `867a36713aa30520be4d5ea8dff0d57b846c919c`、ブランチは `m013/r40.3` のままである。B_STAGE は `c2debc9200e7db6aacf4dde10b94eaf330270654`。R40.3 の未コミット差分を引き継ぎ、今回の差分は手書き Skill 3文書、設計書の06-01・06-04・06-06、固定入力・照合台本と結果記録に限る。Rust の本番・テスト・公開構造は今回変更していない。以下を現在の固定入力・引用・検査の追補とし、上の R40.3 実行時点の記録は履歴として残す。

| RV-R40 の指摘 | 対応 |
|---|---|
| 中1（案 A） | 06-01・06-04・inspection.md を、check/error 例は入口の選択によらず空の Effects と `tests: []` を返し、この空は純粋な契約を意味しない、とそろえた。check 例の契約を保持するという文を削除した。報告の意味・形・版・実行の和は変えていない |
| 中2 の記録 | 段の結果と [一覧](handoff.md) を「報告側の固定入力（K10.2 が比較する群の部分集合）」と限定した。欠けている群と Lean の独立期待値を一覧と段の結果に列挙し、K10.2 が実行前に固定する条件を申し送った |
| 軽3 | SKILL.md と idioms.md で、関数引数は由来のある呼び出し元で拡大し引数を広い型にする案内、節引数は操作の宣言の引数型を変える案内に分けた。Top の節引数には保護本体の Top も必要で、`uses` を広げる必要がありうることを明記した |
| 軽4 | 06-06 の「名前解決後の実体」を、シンボリックリンクを解決した後のファイルと DNS で解決した後の接続先に具体化した |
| 軽5（V10 へ） | E0519 の説明句 `the annotated scope contract (requiredUpperBound)` を逆引用符で囲む表示と、`scope call: .sample at surface preorder 0` の先頭の点・内部の語を、利用者向けの文言として見直す候補にする。今回は診断を変更していない |
| 軽2（取りまとめ） | [段の結果](../r40/results.md#short-の記録と判断)の short 欄は「取り込みの後に取りまとめが記録する」とだけ記した |

### check 例の固定と検査の関門

既存25件の入力・期待値を変えず、`r40/rv-probes/docs2.bnt` の最初の check 例と同じ形の [doc-check.bnt](inputs/doc-check.bnt) を1件追加した。例には `main() uses File.Read["/data/**"]` と `@test` の `uses File.Read["/data/a"]` がある。実行前に手で定めた期待値は、終了0・complete:true・例と集約の Effects が `{"basis":"declaredUpperBound","expanded":[],"bounds":[]}`、例の tests が `[]` である。

[追加前の一覧](r40.3b-before-handoff.json)と [実行前の固定記録](r40.3b-frozen-expectations.json)に、旧25件がそのままであること、追加例の本文ハッシュと期待値、固定日時を保存した。[handoff.json](handoff.json) は全26件で、[SHA-256](handoff.sha256) は `c8bfe176ea31e0098f29063424f722845f3193b7c7106b11a033d88cef1254bc`。実行後の期待値変更は0件である。元の freeze-inputs.py は初回25件を作成した台本として残し、再実行して一覧を上書きしない。

公開の test-audit の作成時の関門は次のとおり通した。観察する契約は、実 CLI の check 例の終了・Effects・tests である。実行対象外の例に main/test の契約を誤って報告する変更があれば失敗する。既存の doc-error は静的拒否を通るため、受理された check 例が main と @test を同時に含む場合を検出しない。主な検査は既存の一覧と check-handoff.py の表に加え、本番の差し込み口は増やしていない。処理系の不具合修正ではなく、既存の互換契約を固定する入力追加である。

### Skill の生成と対象外

`cargo run -p benitoite --example gen_skill` は終了0、外側22.400894秒。[計測](r40.3b-gen-skill.json)・[ログ](r40.3b-gen-skill.log)に保存した。生成された参照と bundle.rs の本文に追加差分はない。手書き文書は実行ファイルへ埋め込むため、実行ファイル全バイトの一致は主張しない。

依存・scripts・formal・比較器と公開構造は変更していない。`lake build`・check-formal.sh・short は実行していない。計時の探査の追随は不要で、比較器の自己検査も重ねていない。新しい CARGO_TARGET_DIR や target 外の一時ビルド・基準版の展開は作成していない。取りまとめの RV-R40.md、rv-probes 全件、ベンチ記録の軽1の訂正は書き換えていない。git の HEAD・ブランチ・index を変える操作、private とそこを指すスキル、docs/todo の読み取りは行っていない。

### S-40 の五対象の引用

2026-10-29、担当 Codex が R40.3 の stage の五対象を同じ関係状態として引用した。[差分の全比較と元証拠のハッシュ](r40.3b-stage-citation.json)、[今回の検査入力](r40.3b-work-inputs.json.gz)・[未コミット差分](r40.3b-work-inputs.patch)を保存した。

| 引用の欄 | 記録・根拠 |
|---|---|
| 元・先の基準と HEAD | 元の W の基準・元の実行 HEAD・今回の HEAD は B_WORK の完全 ID、stage の基準は上記 B_STAGE。ブランチ・index のハッシュも一致する |
| 差分と未追跡入力 | 元の4,286入力と今回の4,286入力を全文ハッシュで比較し、差は Skill の3文書と設計書の3章だけ。元の未追跡 fixture は同じ。追跡差分・未追跡入力の一覧と全文 SHA-256、差分 SHA-256 は今回の検査入力に保存した |
| 影響の判断 | 本番 Rust、五対象のテストと入力・期待値、標準宣言、生成物、設定・manifest/lock・固定版、交換器・scripts・道具は同じ。五対象は Skill 文書の抽出や照合を行わず、変更した文書は実行の意味を変えない。変更した Skill と文書は今回の W-40 で照合する |
| 正確な元の指定 | `scripts/check.sh --level stage --base c2debc9200e7db6aacf4dde10b94eaf330270654 --only tests_related --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client --test network_faults`。既定 gc-mark-sweep、テスト名のフィルタなし。[元の全コマンド](stage.json) |
| 元の件数 | runtime_builtins 29、vm_handlers 5、io_modes 13、l32_http_client 14、network_faults 3、計64成功。失敗・無視・測定・除外は各0。[件数](stage-counts.json)・[生ログ](stage.log) |
| 元の終了・時間・RSS・失敗 | check.sh 自身の終了0、外側39.972321625秒、time real/user/sys=40.01/90.41/5.21秒。補助 RSS 1,382,416,384 bytes＝1,318.375 MiB＝1.287475586 GiB。初回失敗・再実行なし。[直接の記録](stage.json)・[time](stage-time.log)。RSS は子孫の最大値で合計ではない |
| 道具・環境・制限 | macOS27.0.1/arm64、rustc1.98.1（48a229ceaefd4985c50990b14116b6d856af0985）、Cargo1.98.1（797e8a9bc）、Python3.9.6。元と今回の固定版・環境の記録は一致。外した構成・32ビット・他 OS・実候補・Rust/Lean の全比較は引用に含めない |
| 以後の変更と受け入れ | 文書・Skill・固定入力と記録だけが追加され、元の実行契約と五対象の関係状態は同じ。取りまとめの独立レビュー・受け入れは別に行う |

重なる cli_process・test_command・golden は今回の W-40 の結果を使う。五対象は再実行せず、古い R30 の結果も引用していない。

### R40.3b の W-40 と最終照合

リポジトリの根で、次の同じ指定を dry-run と実行で一度ずつ使った。`--dry-run` は実行時だけ外した。

```sh
scripts/check.sh --level work --base 867a36713aa30520be4d5ea8dff0d57b846c919c --test cli_process --test test_command --test golden --test spec_examples --test reference_examples --test skill_docs --test package_command --test desugar_export --dry-run
/usr/bin/time -p python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/r40.3/run-record.py r40.3b-work scripts/check.sh --level work --base 867a36713aa30520be4d5ea8dff0d57b846c919c --test cli_process --test test_command --test golden --test spec_examples --test reference_examples --test skill_docs --test package_command --test desugar_export
```

外側の time は終了0。記録器は check.sh を直接の子として実行し、その終了状態を取得した。time の標準エラーは別ファイルに保存した。[dry-run の選択と理由](r40.3b-work-dry-run.log)・[直接の終了と時間](r40.3b-work.json)・[全ログ](r40.3b-work.log)・[time の原出力](r40.3b-work-time.log)を残した。fmt、clippy、既定 lib 全件、指定統合8対象、source_rules、skill_generated、spec_tally を選び、取りまとめの既存のベンチ記録訂正を理由として python_syntax と migrate_selftests も選んだ。移行器の自己検査は6件と10件が成功した。

| 検査 | 終了 | 外側の時間 |
|---|---:|---:|
| W-40 dry-run | 0 | 0.131443秒 |
| W-40 本体 | 0 | 275.079986042秒（time real 275.11秒） |
| 更新後の実 CLI で26入力を再照合 | 0 | 5.281984秒 |

W-40 の time real/user/sys は275.11/1223.61/40.88秒である。補助の最大常駐量は getrusage(RUSAGE_CHILDREN) の原値5,012,111,360 bytes＝4,779.921875 MiB＝4.667892456 GiB。子孫の最大値の補助値であり、同時常駐量の合計ではない。time -p 自体は RSS を表示しない。

| W-40 の対象 | 成功 | 失敗 | 既存 ignored | 除外 |
|---|---:|---:|---:|---:|
| lib | 1392 | 0 | 22 | 0 |
| cli_process | 46 | 0 | 0 | 0 |
| desugar_export | 44 | 0 | 1 | 0 |
| golden | 2 | 0 | 0 | 0 |
| package_command | 16 | 0 | 0 | 0 |
| reference_examples | 1 | 0 | 0 | 0 |
| skill_docs | 8 | 0 | 0 | 0 |
| spec_examples | 7 | 0 | 0 | 0 |
| test_command | 52 | 0 | 0 | 0 |

計1,568成功・失敗0・既存 ignored 23・除外0である。[件数](r40.3b-work-counts.json)は Cargo のテスト関数の件数で、golden 等の内部入力数とは区別する。W-40 は初回の一度で成功し、失敗・修正後の再実行はない。途中の固定入力照合は54コマンド一致、更新後の [最終54コマンド](r40.3b-handoff-after-work-check.json)もすべて一致し、期待値は変えていない。

S-40 は今回の W-40 の cli_process 46・test_command 52・golden 2 の100成功と、上記の引用64成功を合わせた164成功で、失敗・無視・除外は0である。名指しの部分選択を stage 全体の完了とは呼ばない。[検査入力の最終照合](r40.3b-final-inputs.json.gz)で、4,286ファイル・差分・道具・HEAD・ブランチ・index の一致を確認した。

最初の採時計は10:57:00 UTC（19:57:00 JST）で、それ以前に依頼文と規約の読解を始めている。W-40 は10:59:11.219〜11:03:46.299 UTC、更新後の CLI の最終照合は11:04:00.522 UTCに終了した。先行読解と記録の仕上げを含む所要は約10分、能動時間は約5〜6分の概算で、厳密な分離計時は行っていない。W-40 約4分35秒、Skill 生成約22秒、固定入力の前後の照合約5秒ずつを含み、一部の記録作業と重なるため単純合計しない。設計者の回答待ちはなく、見込み30分〜1時間と2時間の停止条件を変えていない。停止条件への該当はない。独立レビュー・取り込み・受け入れと取り込み後の short は取りまとめへ渡す。

最終の [照合台本](r40.3b-verify.py) と [照合結果](r40.3b-verification.json)に、保護対象9ファイル、HEAD・ブランチ・index、既存25件と追加例の期待値、全26入力の本文ハッシュ、相対リンク、伏せ字、git diff --check の終了0を残した。最終照合は11:05:06 UTCに成功した。

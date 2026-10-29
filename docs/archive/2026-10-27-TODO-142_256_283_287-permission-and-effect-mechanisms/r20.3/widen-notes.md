# widen の登録と実行本体の記録

## 変更

`Scope.widenPathIn` と `Http.widenRequestIn` を標準ソースと組み込みの登録表へ追加した。入力は範囲変数0、戻りは範囲変数1であり、`RangeAdmission::Covers { outer: 1, inner: 0 }` を登録する。既存の `RangeSignature` と型の範囲の表現を使い、公開の範囲引数の構文は増やしていない。標準ソースにある裸の型は登録時に範囲変数を入れるための生成元として維持する。

`CallCtx::with_ranges` と `PureCtx::ranges`・`IoCtx::ranges` を追加し、確定した列を実行本体から読めるようにした。`call_builtin_scoped` は列を変更せず文脈へ渡す。従来の列なしの補助処理 `call_builtin` はテストだけに残し、空の列で委譲する。空の列を Top の列に読み替えない。

検査の二入口は列の長さ1と種類を確かめ、動的な条件への所属に加えてその静的範囲への所属を検査する。拡大の二入口は列の長さ2・種類・行き先による被覆を確かめ、同じ `Value` を返す。パスの文字列、要求のレコード、実効の host/port は作り直さない。新しい言語の値の保持、確保器・根・障壁・安全点の変更はない。

03-06 と 03-09、および標準ソースの説明を、既知の直接の条件は非 Top、未知なら Top とする記述へ改めた。生成 Skill の再生成は取りまとめが行う。利用と裸の注釈の判断は [棚卸し](inventory.md)にまとめた。

## テストの作成時の関門

`runtime_builtins` の既存の要求の同一性の検査を拡大まで延ばし、パスの静的所属と拡大の同一性の検査を一つ加えた。守るのは、動的条件が成功しても静的範囲外の値を成功させないことと、widen が同じ値・要求・端点を返すことである。通常の言語ソースでは構造上の等値と物理的な同一性を区別できず、型検査が受理しない不一致の列を実行できないため、既存の公開の raw 呼び出しと `same_object` の境界で確かめる。テストのための公開の口とフラグは加えていない。成功と失敗では動的な条件・入力を共通にし、静的な範囲だけを変える。

`scope_annotations` の既存の不変性のテストでは、旧 CheckedPath の拒否を E0401 のまま維持し、注釈だけの非 Top の引数の射影を E0519 へ追随した。同じ Result の Ok を直接照合した値なら非 Top のまま射影できる受理例を同じテストへ加えた。通常の runtime_builtins の既知のパスの例は、未知の関数 retain を挟まず同じ Result を直接照合する形へ直した。動的な条件の例にある retain と GC の検査は維持した。

## 局所検査と初回の失敗

最初の `cargo check -p benitoite --lib` と `cargo test -p benitoite --test runtime_builtins scope_path_in_checks_static_membership_and_widen_preserves_the_object -- --exact` は、並行編集の途中の後段の構造と TypeckOutput.call_ranges が未整合で終了101になった。前者では BuiltinRef の Copy、builtin_value の引数、call_ranges、accept の未使用取り込み、後者では decision の ranges の二重指定、call_ranges、accept の未使用取り込みが報告され、テストは実行されていない。各所有者へ連絡して対応した。

その後の `cargo test -p benitoite --test runtime_builtins widen -- --nocapture` は、追加テストが Option<Value> に assert_eq を使っていたためコンパイルで終了101になった。Value は PartialEq を持たないので、ポートの確認を `matches!(..., Some(Value::Int(443)))` へ直した。これらの最初の出力はターミナルで確認した要約であり、生ログとして保存していない。

修正後に同じコマンドを実行し、2件成功・失敗0件・終了0、外側11.185105秒であった。[生ログ](widen-runtime.log)と[コマンド・終了・時間](widen-runtime-outcome.json)を保存した。手元の絶対パスは `<wt>`・`<home>` へ伏せた。通常ソースと全体の検査は取りまとめの W-R、実行本体と文脈の接続は H で確認する。

`private/` と `docs/todo/` は読んでいない。git の状態を変える操作は行っていない。新しい CARGO_TARGET_DIR と target 外の一時のビルドは作っていないため、削除する生成物はない。

## W-R の登録件数の失敗への追随

W-R の lib の検査で `builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` が失敗し、登録した二つの widen への独立件数の追随漏れを確認した。`scope::DECLS` の既存の三つの検査と checkPathIn・pathInValue に widenPathIn が一つ加わるため5件から6件、`http_client::PURE_DECLS` の checkRequestIn・requestInValue に widenRequestIn が一つ加わるため2件から3件とした。二つとも引数一つの pure 宣言であり、PARTS の部分自体は増えない。したがって名前の総数は514から516、pure の件数は439から441へ変更し、state16件・io59件と部分59件は維持した。実際の件数から期待値を生成せず、公開署名と実行本体の二宣言を手で照合した。W-R 全体の再開は取りまとめが行う。

修正後の `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent -- --exact` は1件成功・1402件選択外・終了0であった。`git diff --check` も成功した。この局所の再実行の出力はターミナルで確認し、生ログは追加していない。

## 単一対象の操作の関数値の具体化

取りまとめの追加依頼で、R20.3 に割り当てられた新七 IO の関数値の具体化の機構を `typeck/scoped_calls.rs` と `context.rs` へ接続した。新七 IO の宣言・登録・実行は加えていない。認定した標準署名の `IoShape::Single { kind, position }` を使い、直接の呼び出しでも関数値でも、対象位置の入力型が持つ閉じた範囲から一意の R を得る。入力が未指定なら最後に Top を用い、別の型を渡した場合は不透明型との等しさで E0401 にする。

型の生成では対象の不透明型全体と潜在効果だけを一時的な型変数・行変数に置き換える。制約の解決では元の `RangeSignature::instantiate` を通し、その同じ R で具体化した署名の効果へ既存の型／行引数を代入して、潜在効果と構造上の両向きの包含で一致させる。呼び出しの列にも同じ `[R]` を残す。操作の署名に要求する、範囲付きの結果を持たないこと・行のパラメータがないこと・失敗型がないことなどの既存の検査は変えていない。効果の制約は、型の `solve_pair` に捨てられないよう、既存の行の制約の登録入口へ渡す。

この処理は六つの純粋な規則の pending から分けた。検査の成功型を先に一括で確定する位相を維持し、その候補を使って単一対象の操作の入力と効果を同じ R へ確定する。結果の成功型から新しい所属を作る処理は加えていない。現時点で `Single` の実ソースの標準操作は未登録であるため、この分岐の実ソースからの検査は R30.2・R30.4 が担当する。今回のコンパイルや既存の型署名メタデータの独立期待値を、その実ソースの検証済みの証拠とは数えない。専用のテスト用の公開口は追加していない。

`cargo check -p benitoite --lib`、`cargo test -p benitoite --test scope_annotations --test scoped_calls`（24件成功）、`cargo clippy -p benitoite --lib -- -D warnings` はいずれも終了0であった。テスト指定の初回は存在しない `scope_rules` を名指ししたため、テスト実行前に終了101になり、既存の `scoped_calls` へ修正した。これらの局所検査の出力はターミナルで確認し、生ログは追加していない。最後の差分を含む更新の検査と H は取りまとめが行う。

# RV-R30.2d: File の import の費用の手当てと、宣言情報の JSON の範囲の対応の独立レビュー

2026-10-29。対象は R30.2c・R30.2d の未コミットの差分と、`r30.2c/`・`r30.2d/` の results.md・design.md・ログ。作業用のディレクトリは書き換えず、基準版（`42d22f72` を git archive で展開したもの）と修正版（作業木の写し）を scratchpad の target で release ビルドして比べた（同じ相対パスと mtime で cargo が作り直さなかったので、`cargo clean -p benitoite --release` の後に作り直した）。再現の入力と出力は `r30.2d/rv-probes/` に写した（絶対パスは `<probes>` などに伏せた）。

結論: 取り込んでよい。重大0・中1・軽5。中1 は記録に一段落を足せば済む。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `r30.2c/results.md`「import だけの check の費用」 | 追加の費用を「Trait だけの利用には…1.71 ms」と書くが、Trait を import する標準モジュールを使うプログラムもすべて新たに Scope を読む。Json（+1.39 ms）と Csv（+1.42 ms）を実測した。Json.Codec・Range・NonEmptyList も同じ構造で同じ費用がかかるはずだが測っていない | 費用がこれらのモジュールの利用者にも及ぶことを表と一文で記録する。必要なら設計者に知らせる |
| 軽2 | 軽 | 私有の関数を名指ししたときの診断 | `Trait.limited` は E0303「no member」から E0330「not public」になり `<benitoite>/Trait.bnt:99` を指すようになった。`Scope.limited` は「no member」になる。私有の関数を移した当然の結果で、公開の契約は変わらない | 記録に一言書く |
| 軽3 | 軽 | 組込み向けの構成の境界（docs/todo の TODO-263〜265） | 公式の `Benitoite.Trait` が `Benitoite.Unofficial.Scope` に依存するようになった。将来、構成でモジュールを外すときに、Trait を含めるなら Scope も外せない。Scope は純粋なので今は問題ない | 後の課題として控える |
| 軽4 | 軽 | `tools/derive/derive.py` の `effect_kind` | 組み込みのエフェクトの範囲の種類を名前の固定の表で推測している（Rust の `BuiltinEffectId::scope_kind` の写し）。型では `rangeKind` を出して推測させない方針と一貫しない。新しい範囲付きのエフェクトを足すと宣言情報が拒否される（安全側） | エフェクトの原子にも種類を出す。重ければ同期の箇所を README に明記する |
| 軽5 | 軽 | `shape` の `single`・`topTargeted` | 実際の出力に現れない（543 関数がすべて `untargeted`。効果の操作は一覧の外）。Rust の `ranges::shape` の二つの分岐と Python の `single` の制約は、書き換えた入力を拒否するテストでしか確かめていない | 今は到達しないことを README に書くか、正しい形の合成例を受理するテストを一つ加える |
| 軽6 | 軽 | 03-06 の 804 行 | 「範囲パラメータを含む合併済みの有効な署名」の「範囲パラメータ」が用語集にない | 用語集の「範囲変数」にそろえる |

## 問題がなかった点

- Show の出力: 実装担当の入力 `r30.2c/scope-show.bnt` は両版の出力が全バイト一致した（SHA-256 `05001ee5…`）。自作の境界の入力（引用後 2000 バイトの境目、多バイト文字の 4096 バイトの境目、絵文字の UTF-8 の切れ目、制御文字、Integer64 の両端、`checkHost` の実行時エラー3種、`List`・`Option` の入れ子）も全バイト一致した（`c593f9b8…`）。
- 可視性: Trait だけ・File だけを import したプログラムからは `Scope.*` が見えず、両版とも E0332。Trait を import したプログラムに同名の `prefix`・`quoted` を書いても名前の解決は変わらない。Scope だけを import して ScopeError を補間すると両版とも E0422 で同じ。
- 循環: Scope は何も import せず、Trait → Scope の一方向だけ。孤立した実装の規則に合い、ゴールデンの secondary の位置（13行14〜18列）が `Show` を指すことを確かめた。
- 費用（各組 31 回の交互の中央値、ms、B_WORK → 修正版）: なし 13.41→13.37、File 19.70→14.63、Scope 19.45→14.50、Trait 17.93→19.44、Http 21.11→21.26、Json 18.66→20.05、Csv 18.22→19.64。results の傾向を再現した。
- JSON の設計: `ix`・`rkinds`・`admission`・`shape` は `tests/desugar_export/scope.rs` の交換の書き出しの表現と同じ（Top・閉じた範囲・`rvar`・`lo`/`hi`・`prefixLen`）で、IPv6 は u128 の整数。Python の検証の正規化は Rust（`types/scope.rs`）と一致し、整列とエスケープも一致する。意味のハッシュは範囲を含み、範囲だけを替えるとハッシュが変わることをテストで確かめている。版 4 への移行（旧 manifest の拒否、旧記録の本文の認証と移行、`semanticHashesComparable: false`）は妥当。同梱例の生成記録の差分は版の値・`ix`・ハッシュと `implementationDependencies` の並べ替えだけ。
- 実行した検査: `cargo test --test declarations` 33 件成功・1 件無視。写しの木での `test_derive.py` 50 件成功（91 秒）。File・Scope・Http を加えた例の `derive_inventory` は終了 0、543 関数。
- 記録: 最終の W-R は check.sh 自身の終了 0、外側 467.756 秒で、変更の最終の更新はその開始より前。clippy の分岐とゴールデンの位置の修正は妥当。`ranges.rs` に `unwrap`・添字・`as` はない。辞書の件数の追随の理由は正しく、loader の退行テストは修正前に失敗し修正後に成功する。利用者の JSON のキーを誤って整数にする不具合の修正にもテストがある。03-06・03-07・両 README は実装と一致する。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 設計者に知らせ、採るとの確認を受けた（2026-10-29）。影響するモジュールを記録に書く | R30.2e・README |
| 軽2・軽4・軽5・軽6 | 採る（軽4 は README に同期の箇所を明記する形でよい） | R30.2e |
| 軽3 | docs/todo の TODO-263 に書き足す | docs/todo |

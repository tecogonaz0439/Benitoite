# RV-P3: 捨てる試作 P3・P3b のレビュー

2026-10-30。レビュー担当は Opus 5.5 のサブエージェント（effort medium、所要約30分）。対象は試作 P3 と続きの P3b の全体（後で改造の `spikes/P3/` へ写す。下のパスはその写しの中の位置）。レビュー担当はリポジトリのファイルを書き換えず、報告を応答で返した。取りまとめが要点を保存した。

## 再検査で確かめたこと

`lake env lean -M 12288` で最終の8ファイル（P3b-Derivations・P3b-Heartbeat200k・P3b-Nat・P3b-BoundaryProofs・P3b-RequestSnapshot・P3b-ImportProbe・Syntax・M6）はすべて終了0（各0〜8秒）。`#print axioms` は propext・Quot.sound・Classical.choice だけ。`sorry`・`admit`・独自の `axiom`・`native_decide`・`implemented_by` は0件。

## 重大

- **S1. S1・S2 が閉じたと言えるのは、「葉の含意と Γ を意味の述語とする表現」の範囲に限られ、本番へ移すと名前の付いていない大きな義務が残る**: TyLe の帰納そのものは構文の導出であり、RV-P1 S1 の「意味上の Subtype に落としている」は解消した。ただし葉の前提は `∀ η ρ, Γ η ρ → Φ η ρ → …` で、`Γ` は意味の述語である。`introduce`/`refine` の置換の証明は `Valid` と `Ty.mem_bind` で葉を運んでいるだけで、S2 の `V_Sub` の枝で要る `Valid` は `HasTypeV.sound`（var・int・add・length・sub の5規則の純粋な式の判断の意味の健全性）から作っている。`Ty.Mem` の関数型と Reference は固定した託宣 `World` で定義している。本番の Γ は `List (Option Ty)` の構文の文脈なので、この表現をそのまま移すには、本番の全ての値の型（閉包、Ψ の下の Reference、data、RequestIn の保持値）に意味の所属を定め、`HasTypeVQ` の値の型付けがその所属を含意することを示す必要があり、可変のストアと再帰を含むので実質的に Kripke 型か step-indexed な論理関係の構築になる。この義務は findings にも estimates にも名前がない。修正案: 骨格の独立の判断として問う。(i) 葉の文脈を、篩の sort を持つ束縛の述語だけを並べた論理の埋め込み（有限の式の列。P3b-Nat の `Entails Φ` の形）にし、Φ の保存を篩の canonical forms の補題（閉じた型付き値 v : {a | p} なら p[v]）で示す。(ii) 意味のモデルを作り、その費用を別の行に見込む。findings の「S1・S2 を閉じた」に「意味の葉と意味の Γ を採る表現の範囲で」と限定を付ける。

## 中

- **M1. 変数の表現の比較は葉の表現の違いと混ざっている**: Nat 版の葉は構文の含意、一般の骨格の葉は意味の含意で、Nat 版は最外の篩のアダプタだけ（交換の補題は5件）。「Nat 維持が第一候補」は妥当だが、根拠は「全面移行が要るという証拠がない」まで。修正案: 「変数の表現」と「葉の文脈の表現」を別々の判断として並べ、較正の一群を同じ葉の表現で書いて比べる。
- **M2. 試作の import が古い定義を読んだ原因は、手元の `formal/.lake` の成果物が古いことである**（読めば確定）: `.lake/build/lib/lean/Benitoite/Release/Syntax.olean` は Oct 28 09:17、ソースは Oct 29 02:00 で、成果物より新しい `.lean` が80ファイルある。現行のソースは `Syntax.lean:269` の `checkedRequest (t) (req : Val)` と `TargetTable.lean:135` の `valContent : OpaqueName → Option Ty` で、試作が import した旧い形と食い違う。`lake env lean` は依存を作り直さない。P3b-Nat と P3b-BoundaryProofs は HEAD より前の定義に対して通ったことになり、HEAD で通るかは再ビルドして検査しないと分からない（P3b-RequestSnapshot は影響が小さく、Derivations は Std だけを import するので影響を受けない）。これは本番の check.sh の `formal_build` とは別の、手元の作業ツリーの状態である。修正案: 較正の最初の段で `lake build` を行い、二つのファイルを検査し直すことを受け入れの条件として計画に明記する。
- **M3. 較正 8〜16 時間は、Ty.Le の型を変えたときの下流のビルド破損を見込んでいない**: 本番の `Ty.Le` に Γ;Φ と `refined` を加えると、優先集合の419件を含む下流がコンパイルできなくなる。修正案: 較正では新しい判断（例: `Ty.LeQ`）を並べて置き、旧の `Ty.Le` から埋め込む補題を一つ用意して既存のビルドを保つ。切り替えの作業は較正の後の本体の行に置く。
- **M4. M6 の接続と P3b の一般の骨格は別々の TyLe の上で閉じている**: `M6Body.lean:151` の `checked_subtype` の結論は P1 の TyLe（η を固定し Φ だけを持つ）で、P3b の TyLe（`∀ η ρ`、Γ;Φ）への接続は検査していない。修正案: 計画には「M6 の三条件の言明 → P1 の refine の葉」として写し、P3b の形への持ち上げ（重大 S1 に依存）は本番に残る命題とする。
- **M5. V_Checked・V_CheckedRequest の量化は保証の穴ではなく、0.0.13 で記録済みの抽象化の決定の範囲である。ただし 0.0.14 では前提として効く**（読めば確定）: `Typing.lean:581–591` の V_Checked は `valKind o = some t.kind` と `R.Mem t` だけを前提にし、RequestIn にも要求なしの値を型付けでき、V_CheckedRequest は URL と t の一致を求めない。07-04 は287行で、要求を持たない V-Checked の値を Rust の RequestIn として作らない保証は処理系の構築経路に置くこと、一般の V-CheckedRequest が端点の一致まで求めないこと、その対応を `ModelHttp` の契約と Rust の照合に置くことを決定として書いている。`ModelHttp.valueRun:188–190` は要求なしの値に `defaultRequest` を返して `delta_typed` を保ち、Rust の sendIn は URI と保持した endpoint の一致を確かめる。0.0.13 の主定理の言明に対する欠陥ではない。ただし 0.0.14 で `requestInValue(r).url` などに篩の述語を書けるようにするなら、型の意味に「要求の保持と端点の一致」を入れる必要がある。修正案: findings に 07-04 の287行の段落を出典として添え、設計者には「0.0.14 で改める既存の決定」として報告する。

## 軽

- L1. `/usr/bin/time -l` の最大常駐量は sandbox の制限で取れていない（補助値を明記）。本番の較正では sandbox の外で測る手順を入れる。
- L2. findings の「最終のLean6ファイル」は、P3 の Syntax・M6 を合わせると8ファイル。
- L3. TyLe の `reference (h : a = b)` と `Eff.Covers` の Fail の `∈` は、RV-P1 M4（正規化の後の等号）の未完を引き継ぐ（明記されている）。
- L4. `solve.rs:1582–1588`・`1615–1621` と runtime-audit の `1578–1588`・`1611–1621` は同じ二箇所。

## 処理系の調べの抜き取り

`solve.rs:854–922` の `flow_inner`、`solve.rs:1580–1590`・`1612–1621`、`calls.rs:594–632`、`ir/desugar/exprs.rs:1327–1355`、`generate.rs:684–713`・`1413–1424`、`scoped_calls.rs:504–531`、`scope/accept.rs:137–143`、`ir/check.rs:201–209` は、runtime-audit の記述とすべて一致した。構築経路の10行のうち check2・widen/射影・sendIn の行は根拠と合っていた（JSON・外部の関数・GC の行は抜き取っていない）。

## 見込み

合計は再計算と一致（Lean 180〜420、本体 363.2〜836.8・中心600）。行1・2・4・5・6を上げ行3を維持する方向は妥当で、小さな試作の速さから費用を下げていない。M5 で中心112を維持することに同意。不足は重大 S1 で、(ii) を採るなら行1・2の上端を超える規模の未計上の作業になりうる（見込みは不明）、(i) なら篩の canonical forms と埋め込みの保存が行2・4の内数として要る。どちらかを決めるまで行2の幅は確定扱いにしない。較正 8〜16 は M3 の並置の方針を入れたうえで維持してよい。

## 計画の入力として使ってよいもの

`P3b-Derivations.lean` の証明の形（導出の相互帰納による `TyLe/TelLe/FieldsLe.bind`、`Sub.up`/`valid_up`、`Eff.cover_bind`、`listCore`/`fnCore` を介した構文の逆転、反例 `cannot_split_one_atom`・`negative_not_valid`・`type/row_image_depends_on_value`）、棚卸しの419・807・819件と台本（点検の集合）、runtime-audit の変更点の表、V_Checked・V_CheckedRequest の抽象化を 0.0.14 で改めるという整理、M5 の中心112の維持。

## 直してから使うもの

「S1・S2 を閉じた」の表現（重大 S1）、変数の表現の比較（M1）、P3b-Nat と P3b-BoundaryProofs の結果（M2。HEAD で `lake build` した後に検査し直すまで HEAD の証拠として引用しない）、較正の手順（M3）、M6 の接続（M4）。

## 本番に残る命題

1. Γ の論理の埋め込み（または意味のモデル）の定義と、置換・移動での保存。2. 篩の canonical forms。3. 本番の Nat/cutoff での `Ty.Le.substAt/subst/shift` と `Eff.Covers` の置換、`HasTypeVQ.subst`/`HasTypeCQ.subst` の V_Sub・C_Sub の枝。4. 正規化の後の等号での Reference・Fail の不変。5. data の変性。6. M6 の三条件を本番の全 sort・鍵・幅から導き、P3b の形の葉へ持ち上げること。7. RequestIn の型の意味への「要求の保持と端点の一致」の導入と、`delta_typed`・`TargetAgreement`・`io_exists` の新しい量化の範囲。8. 型付き入力の上での shapeAt の一致。9. 全表層の literal・checker と性質1。10. 全ストア・継続・ハンドラの保存と主定理。

## 設計者に報告すべきもの

重大 S1（葉の文脈を論理の埋め込みにするか意味のモデルを作るか）、M5（V_Checked・V_CheckedRequest の抽象化を 0.0.14 で改める既存の決定として扱う）、M2（手元の `formal/.lake` が HEAD より古く、較正の前に再ビルドが要る）。

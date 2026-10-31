# 局所検査で直した点

記録付きの最終検査より前の Lean の局所実行には、構文と証明の組立ての失敗があった。以下は会話内の出力から残した要点であり、各局所実行の外側の時間を計測した記録ではない。

| 箇所 | 失敗と修正 |
|---|---|
| 一引数の閉じ方の等号 | Tel.instantiate の done は型と行を再び norm する。生の定義的一致とせず、bind が作る正規形の冪等性で消した |
| 空文脈の extend | `[].extend` だけでは Ctx と推論されない箇所を `Ctx.extend [] x` にした |
| 捕捉の拡張 | Context の集約だけでは CaptureOk.extend が import されないため、Context.Capture を明示して読んだ |
| 評価済みの値 | Ground なソースの lam は closeVal で closure に変わる。Ground だけから値の不変を主張する案を捨て、評価済みの実引数の等号 hcv を代表に明記した。一般の closeVal の型保存は L20 |
| return の逆転 | 現行の24構成子を照合し、C_Normal を含めた。存在しない C_CheckAtDynamic 等の名前を使わない形にした |
| 境界の注釈と効果 | Tel の WF/Sorted/Declared と Eff の Canonical を明示した。Fail の型の置換は substEffValues_singleFail で示し、原子関数を生の rfl で比較しない |
| 外部の宣言の照合 | List.lookup が読む ExternalKey の BEq を、固定したキーの等否へ展開して照合した。宣言表の整形式と三つの応答仮定を最後まで構成した |

記録付き検査の初回は既定ビルド・境界・公理監査が成功し、署名列挙器が存在しない `Lean.Name.isPrivate` を参照して終了1となった。[first-public-api.log](first-public-api.log) と [first-verification.json](first-verification.json) がその記録である。手書きの公開10補題を明示し、全てが新モジュールに属することを確認する形に直した。私有・生成宣言の公理監査は全件のまま保った。

その後に本番の Lean・境界入力・公理監査の台本・lakefile・toolchain は変更していない。署名列挙器・検査実行器・署名文書だけの変更を SHA-256 で確かめ、成功した三検査と生出力を引用し、署名列挙だけを実行し直した。最終の [verification.json](initial-verification.json) に各引用の理由を記した。検査の終了0を、独立レビュー又は全状態の保存の完成とは扱わない。

# 未具体化の定義の入力に関する固定署名の停止

## 固定された入口と反例

`Def.WellTyped.inputs` は、前段の `l40/c/start-inputs.md` の B15-Def と `l40/g/declarations-part-02.json` に記録された入口である。現行の完全署名は次のとおりである。

```lean
theorem Def.WellTyped.inputs {P B d} (h : Def.WellTyped P B d) :
    Ctx.Regular P d.tparams (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect []
```

[反例の入力](definition-inputs-resume-trial.lean)は、本番の `RangeFunctionExamples.reader_wellTyped` を使う。定義は path の範囲パラメータ一つと、`Scope.PathIn[rvar 0]` の引数一つを持ち、本体は同じ範囲変数を `File.readTextIn` へ渡す。種類に合う全ての閉じた範囲列で本体が型付くことを `TelBodyTyR` が要求し、この定義は新しい `Def.WellTyped` を満たす。

一方、旧結論の `Ctx.Regular` は、その `wf` 欄で `Ctx.WF 0 d.tparams.length` を要求する。引数の位置0の型の `WF` を取ると `RangeIx.WF 0 (.rvar 0)`、すなわち `0 < 0` が必要になる。`not_reader_regular` はこの矛盾を示す。`reader_obstruction` は本番の定義の型付けと旧結論の否定を組み合わせ、`old_inputs_statement_false` は全プログラム・全定義を量化した旧言明そのものを否定する。関数参照の正準形の枝を広げるだけでは、この矛盾は除けない。

反例は、型の付かない候補や矛盾した前提を使わない。`concrete_call` は、適格な Top の範囲で根のパスの通常値を渡す呼出しが、同じ本番の判断で型付く証人である。`range_context_inhabited` は全種類列に適格な具体化を与える。主な十言明の反例ではない。

## 署名の変更案

推す案は、全ての適格な範囲の具体化後に文脈の形成と本体の入力を取り出す形である。次は完全署名の案であり、本番の固定署名へ適用していない。

```lean
theorem Def.WellTyped.inputs {P B d} (h : Def.WellTyped P B d) :
    ∀ rs : List RangeExpr, d.RangeAdmissible rs →
      Ctx.Regular P d.tparams ((d.instTel rs).context []) ∧
      (d.body.instR rs).Inputs P B StoreTy.empty (QTel d.tel) d.tparams
        ((d.instTel rs).context []) (liftMany (d.instTel rs).arity [])
        (some (d.instTel rs).result) (d.instTel rs).result (d.instTel rs).effect []
```

`TelBodyTyR.instR` で具体化した本体を読み、具体化した署名の注釈から文脈の形成を得て、既存の `TelBodyTy.inputs` で同じ本体の入力を取り出す案である。空の範囲列では元の形へ戻せる。独立した信頼条件・公理・言語の制限は加えない。ただし、未具体化の `d.body` という結論の対象を具体化後の本体へ変えるので、今回許可された「増えた構成子の欄を存在量化や場合分けへ足すだけ」の範囲には入れない。証明はまだ実装していない。

| 案 | 必要な差 | 実用への影響 | 所要の見込み |
|---|---|---|---|
| 全ての適格な具体化の後で入力を取る（推す） | 上の完全署名へ変更し、直接の読者も具体化した署名と本体で読む。必要なら範囲なしの系を別に保つ | 範囲付きの利用者の関数を制限せず、本番の実行先と同じ本体の入力を得る | 接続の最初の確認30〜60分。K.2の全閉包、K.3〜K.5の所要は未実測であり、既承認の群全体50時間以内で再見積もりする |
| 範囲なしの定義に旧形を限る | `d.rkinds = []` の前提を固定署名へ追加し、範囲付きには別の入口を置く | 言語は制限しないが、この入口だけでは範囲付きの定義を扱えない | 一般形の入口も必要なので、短縮の見込みを立てない |
| 旧結論のために利用者の関数の範囲を禁止する | `Def.WellTyped` の入力を狭める | 承認済みの提供範囲を削る。採らない | 見積もらない |

## 残る候補と再現

停止時点のpatchと目録は再開5で除いた。内容の一覧と大きさ・SHA-256は [削除の台帳](removed-records.json) に残す。[完全な定義の候補](resume3-definition-candidates.md)は構文・値の型付け・宣言の型付けと形成・関数適用・正準形・項の範囲置換・十四判断を記す。これらは未完・未採用である。

当時の `replay_resume3.py --tmp <tmp> --lock <lock>` は、現在の開始状態のハッシュと保存差分を照合し、一時領域に候補の依存閉包を再構成し、反例と新規五モジュールの宣言の公理依存を検査する。本番ファイルや本番の成果物へ出力しない。既定 import を削除して候補を成功に見せる台本ではなく、停止の反例の依存閉包だけを検査する台本である。既定の候補全体のビルドの失敗とは区別する。この再構成だけの台本は、候補のpatchと一緒に再開5で除いた。停止の反例とその完全な定義の候補は本ディレクトリに残す。

候補全体の最後の既定ビルドは `LeafInputs` と `FirstFailure` で失敗した。前者には固定署名の問題と、空の範囲引数の指定漏れがある。後者には、`closedRanges` を加えた実行関数の分解への追随漏れがある。停止を確定した後はどちらも直していない。K.3の照合の宣言前提、K.4のhandledSelectedと発行の規則、K.5の効果の健全性は未着手である。

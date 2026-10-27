import Benitoite.Interval.CallReach

/-!
# call の認定に使う二表の保存

局所位置・Range の由来・条件の絞り込みが変わっても、標準表と出現表は保たれる。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis.CallReach
open Benitoite.Surface Benitoite.Release Budget

theorem expr_tables {left right : AbstractEnv} (same : rangeTables left = rangeTables right) (source : Expr) :
    expr left source = expr right source := congrArg (fun tables => exprTables tables source) same

theorem exprs_tables {left right : AbstractEnv} (same : rangeTables left = rangeTables right) (sources : Exprs) :
    exprs left sources = exprs right sources := congrArg (fun tables => exprsTables tables sources) same

theorem block_tables {left right : AbstractEnv} (same : rangeTables left = rangeTables right) (body : Block) :
    block left body = block right body := congrArg (fun tables => blockTables tables body) same

theorem armList_tables {left right : AbstractEnv} (same : rangeTables left = rangeTables right) (arms : Arms) :
    armList left arms = armList right arms := congrArg (fun tables => armListTables tables arms) same

end Benitoite.Interval.BudgetAnalysis.CallReach

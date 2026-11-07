import Benitoite.Release.Refinement.Surface.CheckPreparation

/-! # 標準の組込み署名を支持する効果原子 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport

/-- 標準の署名が使う名前付きの原子と行変数。内部の判定の署名は原子を加えない。 -/
def atoms : List Atom :=
  [.rho 0, .rho 1,
   .name "State" .top, .name "Console.Write" .top, .name "Process.Exit" .top,
   .name "File.Read" .top, .name "File.Write" .top, .name "Http.Connect" .top,
   .name "Process.Environment" .top,
   .name "File.Read" (.rvar 0), .name "File.Write" (.rvar 0), .name "Http.Connect" (.rvar 0)]

end Benitoite.Release.Refinement.Surface.PredicateStandardSupport

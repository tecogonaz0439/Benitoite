import Benitoite.Checked.Scope
import Benitoite.Checked.Range
import Benitoite.Scope.Domain

namespace Benitoite.Checked.Scope
#check (HostPattern : Type)
#check (Scope.Domain.HostPattern : Type)
#check (Scope.Domain.Range : Type)
example : HostPattern = Benitoite.Checked.Scope.HostPattern := rfl
example : Scope.Domain.HostPattern = Benitoite.Scope.Domain.HostPattern := rfl
end Benitoite.Checked.Scope

namespace Benitoite.Checked
#check @Scope.Domain.Range.Mem
end Benitoite.Checked

section
open Benitoite.Checked.Scope Benitoite.Scope.Domain
#check (HostPattern : Type)
end

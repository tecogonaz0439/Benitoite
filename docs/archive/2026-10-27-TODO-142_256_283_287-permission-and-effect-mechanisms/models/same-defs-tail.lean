
-- 写した定義と第一項の定義の同一性の確かめ（PM20.04）。二つのモデルを一つのファイルへ連結した後に置き、
-- 定義の等式を `rfl`（定義の展開による一致）で確かめる。定理は証明の無関係性により `rfl` で一致する。
example : @Benitoite.Models.Policy.KindSet = @Benitoite.Models.PermissionKinds.KindSet := rfl
example : @Benitoite.Models.Policy.KindSet.Subset = @Benitoite.Models.PermissionKinds.KindSet.Subset := rfl
example : @Benitoite.Models.Policy.KindSet.Subset.trans = @Benitoite.Models.PermissionKinds.KindSet.Subset.trans := rfl
example : @Benitoite.Models.Policy.traceKinds = @Benitoite.Models.PermissionKinds.traceKinds := rfl
example : @Benitoite.Models.Policy.mem_traceKinds = @Benitoite.Models.PermissionKinds.mem_traceKinds := rfl
example : @Benitoite.Models.Policy.KindCheck = @Benitoite.Models.PermissionKinds.KindCheck := rfl
#check @Benitoite.Models.Policy.KindCheck
#check @Benitoite.Models.PermissionKinds.KindCheck
#check @Benitoite.Models.Policy.traceKinds
#check @Benitoite.Models.PermissionKinds.traceKinds
#check @Benitoite.Models.Policy.mem_traceKinds
#check @Benitoite.Models.PermissionKinds.mem_traceKinds

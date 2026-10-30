from pathlib import Path
p=Path(__file__).with_name('Skeleton.lean');s=p.read_text().removesuffix('end P1\n')
carriers=[('int','', '.int'), ('bytes','', '.bytes'),
 ('opaque','(name : String) (ix : Ix R)', '.opaque name ix'), ('var','(x : T)', '.var x'),
 ('list','(a : Ty T E R V)', '.list a.embed'), ('record','(fs : Fields T E R V)', '.record fs.embed'),
 ('reference','(a : Ty T E R V)', '.reference a.embed'), ('fn','(ts : Tel T E R V)', '.fn ts.embed')]
# `int` と `bytes` は範囲・長さの専用構成子を持つ。全carrierで条件を表せるよう揃える。
for ns in ['Dedicated','Indexed']:
 s+='\nnamespace '+ns+'\nmutual\n  inductive Ty (T E R : Type) : Type → Type 1 where\n'
 for name,args,out in carriers:
  if ns=='Dedicated': s+=f'    | {name} {args} : Ty T E R V\n    | {name}Where {args} (p : Pred (Option V)) : Ty T E R V\n'
  else: s+=f'    | {name} {args} (p : Pred (Option V)) : Ty T E R V\n'
 s+='''  inductive Eff (T E R : Type) : Type → Type 1 where
    | empty : Eff T E R V
    | atom (name : String) (ix : Ix R) : Eff T E R V
    | row (x : E) : Eff T E R V
    | fail (error : Ty T E R V) : Eff T E R V
    | union (a b : Eff T E R V) : Eff T E R V
  inductive Tel (T E R : Type) : Type → Type 1 where
    | done (ret : Ty T E R V) (latent : Eff T E R V) : Tel T E R V
    | param (name : String) (arg : Ty T E R V) (rest : Tel T E R (Option V)) : Tel T E R V
  inductive Fields (T E R : Type) : Type → Type 1 where
    | nil : Fields T E R V
    | cons (name : String) (a : Ty T E R V) (rest : Fields T E R V) : Fields T E R V
end
mutual
  def Ty.embed : Ty T E R V → P1.Ty T E R V
'''
 for name,args,out in carriers:
  argnames={'int':'','bytes':'','opaque':'name ix','var':'x','list':'a','reference':'a','record':'fs','fn':'ts'}[name]
  if ns=='Dedicated':
   s+=f'    | .{name} {argnames} => {out}\n    | .{name}Where {argnames} p => .refined ({out}) p\n'
  else: s+=f'    | .{name} {argnames} p => .refined ({out}) p\n'
 s+='''  def Eff.embed : Eff T E R V → P1.Eff T E R V
    | .empty => .empty
    | .atom n ix => .atom n ix
    | .row x => .row x
    | .fail a => .fail a.embed
    | .union a b => .union a.embed b.embed
  def Tel.embed : Tel T E R V → P1.Tel T E R V
    | .done a f => .done a.embed f.embed
    | .param n a rest => .param n a.embed rest.embed
  def Fields.embed : Fields T E R V → P1.Fields T E R V
    | .nil => .nil
    | .cons n a rest => .cons n a.embed rest.embed
end
end '''+ns+'\n'
s+='end P1\n';p.write_text(s)

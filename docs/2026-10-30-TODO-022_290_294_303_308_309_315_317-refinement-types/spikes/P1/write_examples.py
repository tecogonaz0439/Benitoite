from pathlib import Path
p=Path(__file__).with_name('Skeleton.lean');s=p.read_text();a=s.index('def openType :');b=s.index('\ntheorem dedicated_same_syntax',a)
exprs=[]
for ns,name in [('', 'openType'),('Dedicated.','dedicatedType'),('Indexed.','indexedType')]:
 def ty(kind,*args,pred=None):
  argstr=' '.join(args)
  if ns=='Indexed.':return f'(.{kind} {argstr} {pred or ".truth"})'
  if ns=='Dedicated.' and pred:return f'(.{kind}Where {argstr} {pred})'
  node=f'(.{kind} {argstr})'
  return f'(.refined {node} {pred})' if pred else node
 elem=ty('var','()');ls=ty('list',elem)
 captured='(lengthIs (.var (some (some ()))))'
 cell=ty('reference',ty('list',elem,pred=captured))
 fields=f'(.cons "values" {ls} (.cons "index" {ty("int")} (.cons "cell" {cell} .nil)))'
 ret=ty('record',fields,pred='recordRelation')
 eff=f'(.union (.atom "Read" (.var ())) (.union (.row ()) (.fail {ty("list",elem,pred=captured)})))'
 first=ty('list',elem,pred='(lengthIs (.var ()))');second=ty('int',pred='(validIndex (.var none))')
 tel=f'(.param "xs" {first} (.param "i" {second} (.done {ret} {eff})))'
 exprs.append(f'def {name} : {ns}Ty Unit Unit Unit Unit :=\n  {ty("fn",tel)}\n')
s=s[:a]+'\n'.join(exprs)+s[b:];p.write_text(s)

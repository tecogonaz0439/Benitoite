import Benitoite.Release.Typing
import Benitoite.Surface.Desugar

-- 現行ソースとのimportの差を記録する読み取り用の検査。
-- 現行Release/Syntax.leanではreq:Val、Typing.leanではvalContent:Option Ty。
#check Benitoite.Release.Val.checkedRequest
#check Benitoite.Release.Builtins.valContent
#check Benitoite.Surface.Literal.toConst
#print Benitoite.Surface.Literal.toConst

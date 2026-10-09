//! テスト用のバイトコードの組み立て（実装プラン 10-07「第 1 段で実行するプログラム」）。
//! 印の相対位置と表の番号を埋め、すべての原型に本番と同じ生存解析を適用する。

use std::sync::Arc;

use crate::base::SourceTable;
use crate::builtins::iface::Capability;
use crate::builtins::{BuiltinId, lookup_builtin};

use super::instr::{Instr, Opcode};
use super::liveness::{LiveInfo, compute_liveness};
use super::program::{
    BuiltinRef, BuiltinRefIdx, CompiledProgram, ConstDesc, ConstIdx, CtorIdx, CtorInfo, MainKind,
    OpIdx, Proto, ProtoIdx, ProtoOrigin, SwitchTable, TraitIdx,
};

/// 原型の中の名前付きの印。別の原型の印は使えない。
#[derive(Clone, Copy, Debug)]
pub(crate) struct Label {
    proto: ProtoIdx,
    index: usize,
}

enum Fixup {
    Jump {
        pc: usize,
        label: Label,
    },
    Switch {
        pc: usize,
        table: usize,
        targets: Vec<Option<Label>>,
        default: Option<Label>,
    },
}

/// 一つの原型の組み立て。追加の捕捉やハンドラの記述の番号は `proto` に置ける。
pub(crate) struct ProtoBuilder {
    pub(crate) proto: Proto,
    index: ProtoIdx,
    labels: Vec<(String, Option<usize>)>,
    fixups: Vec<Fixup>,
}

impl ProtoBuilder {
    /// 命令のオペランドをそのまま指定する。METHOD は `method` を使う。
    pub(crate) fn op(&mut self, opcode: Opcode, a: u16, b: u16, c: u16) {
        self.emit(Instr::abc(opcode, a, b, c), None);
    }

    /// 32 ビットの表の番号を指定する（CLOSURE・LAZY など）。
    pub(crate) fn abx(&mut self, opcode: Opcode, a: u16, bx: u32) {
        self.emit(Instr::abx(opcode, a, bx), None);
    }

    /// 結果を返す。
    pub(crate) fn ret(&mut self, reg: u16) {
        self.op(Opcode::Return, reg, 0, 0);
    }

    /// 再利用の候補に結果を書く。
    pub(crate) fn conr(&mut self, candidate: u16, ctor: CtorIdx, args: u16) -> Result<(), String> {
        let ctor = u16::try_from(ctor.0).map_err(|_| "constructor index exceeds u16")?;
        self.op(Opcode::ConR, candidate, ctor, args);
        Ok(())
    }

    /// メソッドの型クラスを命令の位置に記録する。末尾の場合は TAILMETHOD を指定する。
    pub(crate) fn method(
        &mut self,
        opcode: Opcode,
        trait_: TraitIdx,
        a: u16,
        b: u16,
        c: u16,
    ) -> Result<(), String> {
        if opcode != Opcode::Method && opcode != Opcode::TailMethod {
            return Err("method annotation requires METHOD or TAILMETHOD".to_owned());
        }
        self.emit(Instr::abc(opcode, a, b, c), Some(trait_));
        Ok(())
    }

    fn emit(&mut self, instr: Instr, trait_: Option<TraitIdx>) {
        self.proto.code.push(instr);
        self.proto.positions.push(None);
        self.proto.method_traits.push(trait_);
    }

    /// 前方または後方への跳躍に使う名前付きの印を作る。
    pub(crate) fn label(&mut self, name: &str) -> Result<Label, String> {
        if self.labels.iter().any(|(existing, _)| existing == name) {
            return Err(format!("duplicate label: {name}"));
        }
        let label = Label {
            proto: self.index,
            index: self.labels.len(),
        };
        self.labels.push((name.to_owned(), None));
        Ok(label)
    }

    /// 現在の次の命令を印の位置にする。
    pub(crate) fn place(&mut self, label: Label) -> Result<(), String> {
        if label.proto != self.index {
            return Err("label belongs to another prototype".to_owned());
        }
        let (_, position) = self.labels.get_mut(label.index).ok_or("label is missing")?;
        if position.is_some() {
            return Err("label was already placed".to_owned());
        }
        *position = Some(self.proto.code.len());
        Ok(())
    }

    /// 印へ無条件に跳ぶ。
    pub(crate) fn jmp(&mut self, label: Label) {
        self.jump(Opcode::Jmp, 0, label);
    }

    /// 条件が偽なら印へ跳ぶ。
    pub(crate) fn jmpf(&mut self, condition: u16, label: Label) {
        self.jump(Opcode::JmpF, condition, label);
    }

    fn jump(&mut self, opcode: Opcode, a: u16, label: Label) {
        self.fixups.push(Fixup::Jump {
            pc: self.proto.code.len(),
            label,
        });
        self.emit(Instr::asbx(opcode, a, 0), None);
    }

    /// タグを添字とする印の並びから分岐表を作る。
    pub(crate) fn switch(
        &mut self,
        reg: u16,
        targets: Vec<Option<Label>>,
        default: Option<Label>,
    ) -> Result<(), String> {
        let table = self.proto.switch_tables.len();
        let bx = u16::try_from(table).map_err(|_| "too many switch tables")?;
        self.fixups.push(Fixup::Switch {
            pc: self.proto.code.len(),
            table,
            targets,
            default,
        });
        self.proto.switch_tables.push(SwitchTable {
            targets: Vec::new(),
            default: None,
        });
        self.emit(Instr::abx(Opcode::Switch, reg, u32::from(bx)), None);
        Ok(())
    }

    fn offset(&self, pc: usize, label: Label) -> Result<i32, String> {
        if label.proto != self.index {
            return Err("label belongs to another prototype".to_owned());
        }
        let (name, position) = self.labels.get(label.index).ok_or("label is missing")?;
        let target = position.ok_or_else(|| format!("unplaced label: {name}"))?;
        let target = i64::try_from(target).map_err(|_| "label position exceeds i64")?;
        let next = i64::try_from(pc)
            .map_err(|_| "pc exceeds i64")?
            .checked_add(1)
            .ok_or("pc overflow")?;
        let distance = target.checked_sub(next).ok_or("jump distance overflow")?;
        i32::try_from(distance).map_err(|_| "jump distance exceeds i32".to_owned())
    }

    fn finish(mut self) -> Result<Proto, String> {
        for fixup in &self.fixups {
            match fixup {
                Fixup::Jump { pc, label } => {
                    let offset = self.offset(*pc, *label)?;
                    let instr = self
                        .proto
                        .code
                        .get_mut(*pc)
                        .ok_or("jump instruction is missing")?;
                    let opcode = instr.opcode().ok_or("unknown opcode")?;
                    *instr = Instr::asbx(opcode, instr.a(), offset);
                }
                Fixup::Switch {
                    pc,
                    table,
                    targets,
                    default,
                } => {
                    let targets = targets
                        .iter()
                        .map(|label| label.map(|l| self.offset(*pc, l)).transpose())
                        .collect::<Result<Vec<_>, _>>()?;
                    let default = default.map(|l| self.offset(*pc, l)).transpose()?;
                    let slot = self
                        .proto
                        .switch_tables
                        .get_mut(*table)
                        .ok_or("switch table is missing")?;
                    *slot = SwitchTable { targets, default };
                }
            }
        }
        Ok(self.proto)
    }
}

/// プログラム全体の組み立て。型クラス・実装・操作・ハンドラなどの追加の表は `program` に置ける。
pub(crate) struct ProgramBuilder {
    pub(crate) program: CompiledProgram,
    protos: Vec<ProtoBuilder>,
    builtin_names: Vec<(BuiltinRefIdx, String)>,
}

impl ProgramBuilder {
    /// 空のプログラムを作る。sources は空、main の戻り値の種類は Unit。
    pub(crate) fn new() -> Self {
        Self {
            program: CompiledProgram {
                protos: Vec::new(),
                consts: Vec::new(),
                top_fns: Vec::new(),
                ctors: Vec::new(),
                traits: Vec::new(),
                impls: Vec::new(),
                ops: Vec::new(),
                builtins: Vec::new(),
                handlers: Vec::new(),
                main: None,
                main_kind: MainKind::Unit,
                sources: Arc::new(SourceTable::new()),
            },
            protos: Vec::new(),
            builtin_names: Vec::new(),
        }
    }

    /// 原型を加える。先に番号を取れるので、自分自身や後から作る原型を参照できる。
    pub(crate) fn proto(
        &mut self,
        name: &str,
        num_params: u16,
        num_regs: u16,
    ) -> Result<ProtoIdx, String> {
        let index = ProtoIdx(u32::try_from(self.protos.len()).map_err(|_| "too many prototypes")?);
        self.protos.push(ProtoBuilder {
            proto: Proto {
                name: name.to_owned(),
                origin: ProtoOrigin::UserFn,
                span: None,
                boundary: true,
                code: Vec::new(),
                consts: Vec::new(),
                switch_tables: Vec::new(),
                handlers: Vec::new(),
                num_regs,
                num_params,
                captures: Vec::new(),
                positions: Vec::new(),
                method_traits: Vec::new(),
                live: LiveInfo::default(),
            },
            index,
            labels: Vec::new(),
            fixups: Vec::new(),
        });
        Ok(index)
    }

    /// 指定した原型の命令を組み立てる。
    pub(crate) fn code(&mut self, proto: ProtoIdx) -> Result<&mut ProtoBuilder, String> {
        let index = usize::try_from(proto.0).map_err(|_| "prototype index exceeds usize")?;
        self.protos
            .get_mut(index)
            .ok_or_else(|| "prototype is missing".to_owned())
    }

    /// 定数の記述を加える。子の記述を先に加え、返った番号で親の記述を作れる。
    pub(crate) fn constant(&mut self, desc: ConstDesc) -> Result<ConstIdx, String> {
        let index =
            ConstIdx(u32::try_from(self.program.consts.len()).map_err(|_| "too many constants")?);
        self.program.consts.push(desc);
        Ok(index)
    }

    /// 既存の定数の番号を原型の並びに加え、LOADK を置く。
    pub(crate) fn loadk_ref(
        &mut self,
        proto: ProtoIdx,
        reg: u16,
        constant: ConstIdx,
    ) -> Result<(), String> {
        if self.program.constant(constant).is_none() {
            return Err("constant is missing".to_owned());
        }
        let code = self.code(proto)?;
        let bx =
            u16::try_from(code.proto.consts.len()).map_err(|_| "too many prototype constants")?;
        code.proto.consts.push(constant);
        code.abx(Opcode::LoadK, reg, u32::from(bx));
        Ok(())
    }

    /// 定数の記述を加えて LOADK を置く。
    pub(crate) fn loadk(
        &mut self,
        proto: ProtoIdx,
        reg: u16,
        desc: ConstDesc,
    ) -> Result<(), String> {
        let constant = self.constant(desc)?;
        self.loadk_ref(proto, reg, constant)
    }

    /// 整数の定数をロードする。
    pub(crate) fn loadk_int(
        &mut self,
        proto: ProtoIdx,
        reg: u16,
        value: i64,
    ) -> Result<(), String> {
        self.loadk(proto, reg, ConstDesc::Int(value))
    }

    /// 構成子の表に項目を加える。
    pub(crate) fn ctor(
        &mut self,
        type_name: &str,
        ctor_name: &str,
        tag: u32,
        arity: u16,
    ) -> Result<CtorIdx, String> {
        let index = CtorIdx(u32::from(
            u16::try_from(self.program.ctors.len()).map_err(|_| "too many constructors")?,
        ));
        self.program.ctors.push(CtorInfo {
            type_name: type_name.to_owned(),
            ctor_name: ctor_name.to_owned(),
            tag,
            arity,
        });
        Ok(index)
    }

    /// 組み込みの関数を番号で参照する。R08 の表が完成する前でも使える。
    pub(crate) fn builtin(
        &mut self,
        id: BuiltinId,
        arity: u16,
        capability: Capability,
        op: Option<OpIdx>,
    ) -> Result<BuiltinRefIdx, String> {
        let index = BuiltinRefIdx(u32::from(
            u16::try_from(self.program.builtins.len())
                .map_err(|_| "too many builtin references")?,
        ));
        self.program.builtins.push(BuiltinRef {
            id,
            arity,
            capability,
            op,
        });
        Ok(index)
    }

    /// 名前で組み込みの関数を参照する。finish で R08 の lookup_builtin を呼ぶ。
    pub(crate) fn named_builtin(
        &mut self,
        name: &str,
        arity: u16,
        capability: Capability,
        op: Option<OpIdx>,
    ) -> Result<BuiltinRefIdx, String> {
        let index = self.builtin(BuiltinId(0), arity, capability, op)?;
        self.builtin_names.push((index, name.to_owned()));
        Ok(index)
    }

    /// 跳躍を解決してから、すべての原型の生存の情報を同じ解析で埋める。
    pub(crate) fn finish(mut self, main: ProtoIdx) -> Result<CompiledProgram, String> {
        self.program.protos = self
            .protos
            .into_iter()
            .map(ProtoBuilder::finish)
            .collect::<Result<_, _>>()?;
        if self.program.proto(main).is_none() {
            return Err("main prototype is missing".to_owned());
        }
        self.program.main = Some(main);
        for (index, name) in self.builtin_names {
            let id = lookup_builtin(&name).ok_or_else(|| format!("unknown builtin: {name}"))?;
            let index = usize::try_from(index.0).map_err(|_| "builtin index exceeds usize")?;
            self.program
                .builtins
                .get_mut(index)
                .ok_or("builtin reference is missing")?
                .id = id;
        }
        for index in 0..self.program.protos.len() {
            let proto = ProtoIdx(u32::try_from(index).map_err(|_| "too many prototypes")?);
            let live = compute_liveness(&self.program, proto).map_err(|err| format!("{err:?}"))?;
            self.program
                .protos
                .get_mut(index)
                .ok_or("prototype is missing")?
                .live = live;
        }
        Ok(self.program)
    }
}

#[cfg(test)]
// 組み立ての契約を実際の CompiledProgram で確かめる。準備と失敗の表現には添字・算術を使う。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::bytecode::liveness::LiveItem;
    use crate::bytecode::program::{CaptureSource, MethodInfo, TraitInfo};

    // 関門: 表の番号・原型の番号・命令の符号化と印の基点が組み立ての契約である。
    // 生存解析のテストでは、この補助が表を埋めるときの誤りを検出できない。
    #[test]
    fn assembly_resolves_tables_labels_and_liveness_for_every_prototype() {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 3, 6).unwrap();
        let captured = builder.proto("captured", 0, 1).unwrap();
        let method = builder.proto("method", 2, 3).unwrap();
        let tailmethod = builder.proto("tailmethod", 2, 2).unwrap();
        let ctor = builder.ctor("Node", "Node", 7, 1).unwrap();
        let builtin = builder
            .builtin(BuiltinId(123), 1, Capability::Io, Some(OpIdx(4)))
            .unwrap();
        builder.program.traits.push(TraitInfo {
            name: "Trait".to_owned(),
            supers: vec![],
            methods: vec![MethodInfo {
                name: "call".to_owned(),
                arity: 1,
            }],
        });
        let start = builder.code(main).unwrap().label("start").unwrap();
        let otherwise = builder.code(main).unwrap().label("else").unwrap();
        let done = builder.code(main).unwrap().label("done").unwrap();
        builder.code(main).unwrap().place(start).unwrap();
        builder.loadk_int(main, 3, 9).unwrap();
        let code = builder.code(main).unwrap();
        code.op(Opcode::Move, 4, 0, 0);
        code.jmpf(1, otherwise);
        code.conr(2, ctor, 3).unwrap();
        code.abx(Opcode::Closure, 5, captured.0);
        code.jmp(done);
        code.place(otherwise).unwrap();
        code.switch(0, vec![Some(start), None], Some(done)).unwrap();
        code.place(done).unwrap();
        code.ret(2);
        let code = builder.code(captured).unwrap();
        code.proto.captures = vec![CaptureSource::Reg(2)];
        code.op(Opcode::GetCap, 0, 0, 0);
        code.ret(0);
        let code = builder.code(method).unwrap();
        code.method(Opcode::Method, TraitIdx(0), 2, 0, 0).unwrap();
        code.ret(2);
        builder
            .code(tailmethod)
            .unwrap()
            .method(Opcode::TailMethod, TraitIdx(0), 0, 0, 0)
            .unwrap();
        // 原型の定数の位置と全体の番号を別々に数えることも確かめる。
        let constant = builder.constant(ConstDesc::Bool(true)).unwrap();
        builder.loadk_ref(captured, 0, constant).unwrap();
        builder.code(captured).unwrap().ret(0);

        let program = builder.finish(main).unwrap();
        let p = program.proto(main).unwrap();
        let expected = [
            (Opcode::LoadK, 3, 0, 0),
            (Opcode::Move, 4, 0, 0),
            (Opcode::JmpF, 1, 3, 0),
            (Opcode::ConR, 2, 0, 3),
            (Opcode::Closure, 5, 1, 0),
            (Opcode::Jmp, 0, 1, 0),
            (Opcode::Switch, 0, 0, 0),
            (Opcode::Return, 2, 0, 0),
        ];
        for (instr, (op, a, b, c)) in p.code.iter().zip(expected) {
            assert_eq!(
                (instr.opcode(), instr.a(), instr.b(), instr.c()),
                (Some(op), a, b, c)
            );
        }
        assert_eq!(p.code.len(), expected.len());
        assert_eq!(p.code[2].sbx(), 3);
        assert_eq!(p.code[5].sbx(), 1);
        assert_eq!(
            p.switch_tables,
            vec![SwitchTable {
                targets: vec![Some(-7), None],
                default: Some(0)
            }]
        );
        assert_eq!(p.consts, vec![ConstIdx(0)]);
        assert_eq!(program.protos[1].consts, vec![ConstIdx(1)]);
        assert_eq!(
            program.consts,
            vec![ConstDesc::Int(9), ConstDesc::Bool(true)]
        );
        assert_eq!(program.ctors[0].tag, 7);
        assert_eq!(
            program.builtin(builtin).unwrap(),
            &BuiltinRef {
                id: BuiltinId(123),
                arity: 1,
                capability: Capability::Io,
                op: Some(OpIdx(4)),
            }
        );
        assert_eq!(program.main, Some(main));
        for p in &program.protos {
            assert_eq!(p.positions, vec![None; p.code.len()]);
            assert_eq!(p.live.starts.len(), p.code.len() + 1);
        }
        assert!(
            p.live
                .at(7)
                .contains(&LiveItem::LastUse { reg: 2, sole: true })
        );
        assert_eq!(
            program.protos[1].live.at(1),
            &[LiveItem::LastUse { reg: 0, sole: true }]
        );
        assert_eq!(
            program.protos[2].method_traits,
            vec![Some(TraitIdx(0)), None]
        );
        assert_eq!(program.protos[3].method_traits, vec![Some(TraitIdx(0))]);
        for index in [2, 3] {
            let live = program.protos[index].live.at(0);
            assert_eq!(live.len(), 2);
            for reg in [0, 1] {
                assert!(live.contains(&LiveItem::LastUse { reg, sole: true }));
            }
        }
        fn share<T: Send + Sync>(_: &T) {}
        share(&program);
    }

    #[test]
    fn assembly_rejects_bad_labels_and_propagates_analysis_failures() {
        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 1, 1).unwrap();
        let code = builder.code(main).unwrap();
        let label = code.label("missing").unwrap();
        assert!(code.label("missing").unwrap_err().contains("duplicate"));
        code.jmp(label);
        assert!(builder.finish(main).unwrap_err().contains("unplaced"));

        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 1, 1).unwrap();
        let other = builder.proto("other", 1, 1).unwrap();
        let label = builder.code(other).unwrap().label("foreign").unwrap();
        builder.code(other).unwrap().place(label).unwrap();
        builder.code(other).unwrap().ret(0);
        builder.code(main).unwrap().jmp(label);
        assert!(
            builder
                .finish(main)
                .unwrap_err()
                .contains("another prototype")
        );

        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 1, 1).unwrap();
        let label = builder.code(main).unwrap().label("end").unwrap();
        builder.code(main).unwrap().jmp(label);
        builder.code(main).unwrap().place(label).unwrap();
        assert!(
            builder
                .code(main)
                .unwrap()
                .place(label)
                .unwrap_err()
                .contains("already placed")
        );
        assert!(builder.finish(main).unwrap_err().contains("jump target"));

        let mut builder = ProgramBuilder::new();
        let main = builder.proto("main", 1, 1).unwrap();
        builder.code(main).unwrap().op(Opcode::Method, 0, 0, 0);
        assert!(
            builder
                .finish(main)
                .unwrap_err()
                .contains("method trait is missing")
        );
    }
}

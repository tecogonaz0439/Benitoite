//! 命令の符号化（本章「命令の符号化」）。

/// 命令の種類。番号は本章の表のとおり。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
#[repr(u8)]
pub enum Opcode {
    Move = 0,
    LoadK = 1,
    GetCap = 2,
    Closure = 3,
    Call = 4,
    TailCall = 5,
    Return = 6,
    Prim = 7,
    Io = 8,
    AddI = 16,
    SubI = 17,
    MulI = 18,
    DivI = 19,
    ModI = 20,
    NegI = 21,
    AddF = 24,
    SubF = 25,
    MulF = 26,
    DivF = 27,
    NegF = 28,
    Concat = 30,
    EqI = 32,
    LtI = 33,
    LeI = 34,
    EqF = 35,
    LtF = 36,
    LeF = 37,
    EqS = 38,
    LtS = 39,
    LeS = 40,
    EqC = 41,
    LtC = 42,
    LeC = 43,
    EqB = 44,
    EqV = 45,
    Not = 46,
    Con = 48,
    List = 49,
    Field = 50,
    Jmp = 56,
    JmpF = 57,
    Switch = 58,
}

impl Opcode {
    pub fn from_u8(n: u8) -> Option<Opcode> {
        let op = match n {
            0 => Opcode::Move,
            1 => Opcode::LoadK,
            2 => Opcode::GetCap,
            3 => Opcode::Closure,
            4 => Opcode::Call,
            5 => Opcode::TailCall,
            6 => Opcode::Return,
            7 => Opcode::Prim,
            8 => Opcode::Io,
            16 => Opcode::AddI,
            17 => Opcode::SubI,
            18 => Opcode::MulI,
            19 => Opcode::DivI,
            20 => Opcode::ModI,
            21 => Opcode::NegI,
            24 => Opcode::AddF,
            25 => Opcode::SubF,
            26 => Opcode::MulF,
            27 => Opcode::DivF,
            28 => Opcode::NegF,
            30 => Opcode::Concat,
            32 => Opcode::EqI,
            33 => Opcode::LtI,
            34 => Opcode::LeI,
            35 => Opcode::EqF,
            36 => Opcode::LtF,
            37 => Opcode::LeF,
            38 => Opcode::EqS,
            39 => Opcode::LtS,
            40 => Opcode::LeS,
            41 => Opcode::EqC,
            42 => Opcode::LtC,
            43 => Opcode::LeC,
            44 => Opcode::EqB,
            45 => Opcode::EqV,
            46 => Opcode::Not,
            48 => Opcode::Con,
            49 => Opcode::List,
            50 => Opcode::Field,
            56 => Opcode::Jmp,
            57 => Opcode::JmpF,
            58 => Opcode::Switch,
            _ => return None,
        };
        Some(op)
    }
}

/// 64 ビットの命令。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct Instr(pub u64);

impl Instr {
    pub fn abc(op: Opcode, a: u16, b: u16, c: u16) -> Instr {
        Instr(
            u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(b) << 24) | (u64::from(c) << 40),
        )
    }

    pub fn abx(op: Opcode, a: u16, bx: u32) -> Instr {
        Instr(u64::from(op as u8) | (u64::from(a) << 8) | (u64::from(bx) << 24))
    }

    pub fn asbx(op: Opcode, a: u16, sbx: i32) -> Instr {
        Instr::abx(op, a, u32::from_ne_bytes(sbx.to_ne_bytes()))
    }

    /// 命令の種類。知らない番号なら `None`（処理系の不具合）。
    pub fn opcode(self) -> Option<Opcode> {
        Opcode::from_u8((self.0 & 0xff) as u8)
    }

    pub fn a(self) -> u16 {
        ((self.0 >> 8) & 0xffff) as u16
    }

    pub fn b(self) -> u16 {
        ((self.0 >> 24) & 0xffff) as u16
    }

    pub fn c(self) -> u16 {
        ((self.0 >> 40) & 0xffff) as u16
    }

    pub fn bx(self) -> u32 {
        ((self.0 >> 24) & 0xffff_ffff) as u32
    }

    pub fn sbx(self) -> i32 {
        i32::from_ne_bytes(self.bx().to_ne_bytes())
    }
}

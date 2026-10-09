//! 命令の符号化（実装プラン 10-07「命令の符号化」「命令の表」、設計書 02-07「命令」）。

/// 命令の種類。番号は 10-07 の命令の表のとおり。
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
    Escape = 9,
    GetDict = 10,
    Dict = 11,
    Super = 12,
    Method = 13,
    TailMethod = 14,
    AddI = 16,
    SubI = 17,
    MulI = 18,
    DivI = 19,
    ModI = 20,
    NegI = 21,
    AddF = 22,
    SubF = 23,
    MulF = 24,
    DivF = 25,
    NegF = 26,
    AddD = 27,
    SubD = 28,
    MulD = 29,
    DivD = 30,
    NegD = 31,
    Concat = 32,
    EqI = 40,
    LtI = 41,
    LeI = 42,
    EqF = 43,
    LtF = 44,
    LeF = 45,
    EqD = 46,
    LtD = 47,
    LeD = 48,
    EqS = 49,
    LtS = 50,
    LeS = 51,
    EqC = 52,
    LtC = 53,
    LeC = 54,
    EqBt = 55,
    LtBt = 56,
    LeBt = 57,
    EqB = 58,
    EqV = 59,
    Not = 60,
    Con = 64,
    List = 65,
    Field = 66,
    ConR = 67,
    Jmp = 72,
    JmpF = 73,
    Switch = 74,
    Lazy = 80,
    Force = 81,
    Update = 82,
    Use = 83,
    Release = 84,
    Handle = 88,
    Perform = 89,
    Resume = 90,
}

impl Opcode {
    /// 番号から命令の種類を引く。知らない番号なら `None`（処理系の不具合）。
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
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
            9 => Opcode::Escape,
            10 => Opcode::GetDict,
            11 => Opcode::Dict,
            12 => Opcode::Super,
            13 => Opcode::Method,
            14 => Opcode::TailMethod,
            16 => Opcode::AddI,
            17 => Opcode::SubI,
            18 => Opcode::MulI,
            19 => Opcode::DivI,
            20 => Opcode::ModI,
            21 => Opcode::NegI,
            22 => Opcode::AddF,
            23 => Opcode::SubF,
            24 => Opcode::MulF,
            25 => Opcode::DivF,
            26 => Opcode::NegF,
            27 => Opcode::AddD,
            28 => Opcode::SubD,
            29 => Opcode::MulD,
            30 => Opcode::DivD,
            31 => Opcode::NegD,
            32 => Opcode::Concat,
            40 => Opcode::EqI,
            41 => Opcode::LtI,
            42 => Opcode::LeI,
            43 => Opcode::EqF,
            44 => Opcode::LtF,
            45 => Opcode::LeF,
            46 => Opcode::EqD,
            47 => Opcode::LtD,
            48 => Opcode::LeD,
            49 => Opcode::EqS,
            50 => Opcode::LtS,
            51 => Opcode::LeS,
            52 => Opcode::EqC,
            53 => Opcode::LtC,
            54 => Opcode::LeC,
            55 => Opcode::EqBt,
            56 => Opcode::LtBt,
            57 => Opcode::LeBt,
            58 => Opcode::EqB,
            59 => Opcode::EqV,
            60 => Opcode::Not,
            64 => Opcode::Con,
            65 => Opcode::List,
            66 => Opcode::Field,
            67 => Opcode::ConR,
            72 => Opcode::Jmp,
            73 => Opcode::JmpF,
            74 => Opcode::Switch,
            80 => Opcode::Lazy,
            81 => Opcode::Force,
            82 => Opcode::Update,
            83 => Opcode::Use,
            84 => Opcode::Release,
            88 => Opcode::Handle,
            89 => Opcode::Perform,
            90 => Opcode::Resume,
            _ => return None,
        };
        Some(op)
    }

    /// 逆アセンブラと診断に示す名前（大文字）。
    pub fn name(self) -> &'static str {
        match self {
            Opcode::Move => "MOVE",
            Opcode::LoadK => "LOADK",
            Opcode::GetCap => "GETCAP",
            Opcode::Closure => "CLOSURE",
            Opcode::Call => "CALL",
            Opcode::TailCall => "TAILCALL",
            Opcode::Return => "RETURN",
            Opcode::Prim => "PRIM",
            Opcode::Io => "IO",
            Opcode::Escape => "ESCAPE",
            Opcode::GetDict => "GETDICT",
            Opcode::Dict => "DICT",
            Opcode::Super => "SUPER",
            Opcode::Method => "METHOD",
            Opcode::TailMethod => "TAILMETHOD",
            Opcode::AddI => "ADDI",
            Opcode::SubI => "SUBI",
            Opcode::MulI => "MULI",
            Opcode::DivI => "DIVI",
            Opcode::ModI => "MODI",
            Opcode::NegI => "NEGI",
            Opcode::AddF => "ADDF",
            Opcode::SubF => "SUBF",
            Opcode::MulF => "MULF",
            Opcode::DivF => "DIVF",
            Opcode::NegF => "NEGF",
            Opcode::AddD => "ADDD",
            Opcode::SubD => "SUBD",
            Opcode::MulD => "MULD",
            Opcode::DivD => "DIVD",
            Opcode::NegD => "NEGD",
            Opcode::Concat => "CONCAT",
            Opcode::EqI => "EQI",
            Opcode::LtI => "LTI",
            Opcode::LeI => "LEI",
            Opcode::EqF => "EQF",
            Opcode::LtF => "LTF",
            Opcode::LeF => "LEF",
            Opcode::EqD => "EQD",
            Opcode::LtD => "LTD",
            Opcode::LeD => "LED",
            Opcode::EqS => "EQS",
            Opcode::LtS => "LTS",
            Opcode::LeS => "LES",
            Opcode::EqC => "EQC",
            Opcode::LtC => "LTC",
            Opcode::LeC => "LEC",
            Opcode::EqBt => "EQBT",
            Opcode::LtBt => "LTBT",
            Opcode::LeBt => "LEBT",
            Opcode::EqB => "EQB",
            Opcode::EqV => "EQV",
            Opcode::Not => "NOT",
            Opcode::Con => "CON",
            Opcode::List => "LIST",
            Opcode::Field => "FIELD",
            Opcode::ConR => "CONR",
            Opcode::Jmp => "JMP",
            Opcode::JmpF => "JMPF",
            Opcode::Switch => "SWITCH",
            Opcode::Lazy => "LAZY",
            Opcode::Force => "FORCE",
            Opcode::Update => "UPDATE",
            Opcode::Use => "USE",
            Opcode::Release => "RELEASE",
            Opcode::Handle => "HANDLE",
            Opcode::Perform => "PERFORM",
            Opcode::Resume => "RESUME",
        }
    }

    /// 第 1 段の VM が実装する命令か（10-07 の命令の表の段の欄が 1）。
    pub fn in_stage1(self) -> bool {
        match self {
            Opcode::Move
            | Opcode::LoadK
            | Opcode::GetCap
            | Opcode::Closure
            | Opcode::Call
            | Opcode::TailCall
            | Opcode::Return
            | Opcode::Prim
            | Opcode::Io
            | Opcode::AddI
            | Opcode::SubI
            | Opcode::MulI
            | Opcode::DivI
            | Opcode::ModI
            | Opcode::NegI
            | Opcode::AddF
            | Opcode::SubF
            | Opcode::MulF
            | Opcode::DivF
            | Opcode::NegF
            | Opcode::Concat
            | Opcode::EqI
            | Opcode::LtI
            | Opcode::LeI
            | Opcode::EqF
            | Opcode::LtF
            | Opcode::LeF
            | Opcode::EqS
            | Opcode::LtS
            | Opcode::LeS
            | Opcode::EqC
            | Opcode::LtC
            | Opcode::LeC
            | Opcode::EqB
            | Opcode::EqV
            | Opcode::Not
            | Opcode::Con
            | Opcode::List
            | Opcode::Field
            | Opcode::ConR
            | Opcode::Jmp
            | Opcode::JmpF
            | Opcode::Switch => true,
            Opcode::Escape
            | Opcode::GetDict
            | Opcode::Dict
            | Opcode::Super
            | Opcode::Method
            | Opcode::TailMethod
            | Opcode::AddD
            | Opcode::SubD
            | Opcode::MulD
            | Opcode::DivD
            | Opcode::NegD
            | Opcode::EqD
            | Opcode::LtD
            | Opcode::LeD
            | Opcode::EqBt
            | Opcode::LtBt
            | Opcode::LeBt
            | Opcode::Lazy
            | Opcode::Force
            | Opcode::Update
            | Opcode::Use
            | Opcode::Release
            | Opcode::Handle
            | Opcode::Perform
            | Opcode::Resume => false,
        }
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
    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn opcode(self) -> Option<Opcode> {
        Opcode::from_u8((self.0 & 0xff) as u8)
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn a(self) -> u16 {
        ((self.0 >> 8) & 0xffff) as u16
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn b(self) -> u16 {
        ((self.0 >> 24) & 0xffff) as u16
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn c(self) -> u16 {
        ((self.0 >> 40) & 0xffff) as u16
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn bx(self) -> u32 {
        ((self.0 >> 24) & 0xffff_ffff) as u32
    }

    #[cfg_attr(debug_assertions, inline)]
    #[cfg_attr(not(debug_assertions), inline(always))]
    pub fn sbx(self) -> i32 {
        i32::from_ne_bytes(self.bx().to_ne_bytes())
    }
}

//! 組み込みの型とエフェクトの表（設計書 02-04「標準ライブラリのソースの持ち方」、01-07「組み込みのエフェクト」、
//! ADR 0128・0130・0140・0157・0168）。
//! 初期化の後に変更しないので `const` の表にする（ADR 0015）。項目は末尾にだけ加える。

/// 組み込みの型の表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinTypeId(pub u16);

/// 組み込みの型の種類。等値の型と鍵の型の判定（01-06）と、`with` のリソースの判定（01-10）に使う。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum BuiltinTypeClass {
    /// 基本型（01-04）。`Float` は鍵の型でない
    Basic,
    /// `List`・`Map`・`Set`・`Bytes`。等値かどうかは要素の型で決まる（`Bytes` は常に等値）
    Collection,
    /// 中身を見せない型。等値の型でない
    Opaque,
    /// リソースの型。中身を見せない型であり、`with` で束縛できる
    Resource,
}

/// 組み込みの型の表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinTypeDef {
    /// 属する標準ライブラリのモジュールの、`Benitoite` を除いた名前の段。空は `Benitoite` の直下
    pub module: &'static [&'static str],
    pub name: &'static str,
    /// 型引数の個数
    pub arity: u8,
    pub class: BuiltinTypeClass,
}

impl BuiltinTypeId {
    pub const INTEGER: BuiltinTypeId = BuiltinTypeId(0);
    pub const FLOAT: BuiltinTypeId = BuiltinTypeId(1);
    pub const STRING: BuiltinTypeId = BuiltinTypeId(2);
    pub const CHARACTER: BuiltinTypeId = BuiltinTypeId(3);
    pub const BOOLEAN: BuiltinTypeId = BuiltinTypeId(4);
    pub const UNIT: BuiltinTypeId = BuiltinTypeId(5);
    pub const BYTE: BuiltinTypeId = BuiltinTypeId(6);
    pub const DECIMAL: BuiltinTypeId = BuiltinTypeId(7);
    pub const LIST: BuiltinTypeId = BuiltinTypeId(8);
    pub const MAP: BuiltinTypeId = BuiltinTypeId(9);
    pub const SET: BuiltinTypeId = BuiltinTypeId(10);
    pub const BYTES: BuiltinTypeId = BuiltinTypeId(11);
    pub const REFERENCE: BuiltinTypeId = BuiltinTypeId(12);
    pub const LAZY: BuiltinTypeId = BuiltinTypeId(13);
    pub const TASK: BuiltinTypeId = BuiltinTypeId(14);
    pub const TASK_GROUP: BuiltinTypeId = BuiltinTypeId(15);
    pub const IO_ERROR: BuiltinTypeId = BuiltinTypeId(16);
    pub const NETWORK_ERROR: BuiltinTypeId = BuiltinTypeId(17);

    /// 表の項目。
    pub fn def(self) -> Option<&'static BuiltinTypeDef> {
        BUILTIN_TYPES.get(usize::from(self.0))
    }
}

/// 組み込みの型の表。位置が番号である。
pub const BUILTIN_TYPES: &[BuiltinTypeDef] = &[
    BuiltinTypeDef {
        module: &["Integer"],
        name: "Integer",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Float"],
        name: "Float",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["String"],
        name: "String",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Character"],
        name: "Character",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Boolean"],
        name: "Boolean",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &[],
        name: "Unit",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Byte"],
        name: "Byte",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Decimal"],
        name: "Decimal",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["List"],
        name: "List",
        arity: 1,
        class: BuiltinTypeClass::Collection,
    },
    BuiltinTypeDef {
        module: &["Map"],
        name: "Map",
        arity: 2,
        class: BuiltinTypeClass::Collection,
    },
    BuiltinTypeDef {
        module: &["Set"],
        name: "Set",
        arity: 1,
        class: BuiltinTypeClass::Collection,
    },
    BuiltinTypeDef {
        module: &["Bytes"],
        name: "Bytes",
        arity: 0,
        class: BuiltinTypeClass::Collection,
    },
    BuiltinTypeDef {
        module: &["Reference"],
        name: "Reference",
        arity: 1,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["Lazy"],
        name: "Lazy",
        arity: 1,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["Task"],
        name: "Task",
        arity: 1,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["TaskGroup"],
        name: "TaskGroup",
        arity: 0,
        class: BuiltinTypeClass::Resource,
    },
    BuiltinTypeDef {
        module: &["IOError"],
        name: "IOError",
        arity: 0,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["NetworkError"],
        name: "NetworkError",
        arity: 0,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["IO", "File"],
        name: "Reader",
        arity: 0,
        class: BuiltinTypeClass::Resource,
    },
    BuiltinTypeDef {
        module: &["IO", "File"],
        name: "Writer",
        arity: 0,
        class: BuiltinTypeClass::Resource,
    },
    BuiltinTypeDef {
        module: &["IO", "Random"],
        name: "Generator",
        arity: 0,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["Regex"],
        name: "Pattern",
        arity: 0,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["Regex"],
        name: "Match",
        arity: 0,
        class: BuiltinTypeClass::Opaque,
    },
    BuiltinTypeDef {
        module: &["Network", "Http"],
        name: "Listener",
        arity: 0,
        class: BuiltinTypeClass::Resource,
    },
    BuiltinTypeDef {
        module: &["Network", "Http"],
        name: "Exchange",
        arity: 0,
        class: BuiltinTypeClass::Resource,
    },
];

/// 組み込みのエフェクトの表の番号。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct BuiltinEffectId(pub u16);

/// 組み込みのエフェクトの表の項目。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BuiltinEffectDef {
    /// 宣言したモジュールの、`Benitoite` を除いた名前の段。空は `Benitoite` の直下（`State`）
    pub module: &'static [&'static str],
    pub name: &'static str,
    /// `IO.All` に含むか（01-07「組み込みのエフェクト」）
    pub in_io_all: bool,
    /// ソースに宣言があるか。`false` の項目（`State`・`IO.All`）は名前解決が表から束縛を作る
    pub declared_in_source: bool,
}

impl BuiltinEffectId {
    pub const STATE: BuiltinEffectId = BuiltinEffectId(0);
    /// `IO.All`。型検査が宣言の型と型注釈を内部の型に移すときに、`in_io_all` の項目の集合に置き換える。
    /// `EffectSet` には現れない
    pub const IO_ALL: BuiltinEffectId = BuiltinEffectId(1);

    /// 表の項目。
    pub fn def(self) -> Option<&'static BuiltinEffectDef> {
        BUILTIN_EFFECTS.get(usize::from(self.0))
    }
}

/// 組み込みのエフェクトの表。位置が番号である。
pub const BUILTIN_EFFECTS: &[BuiltinEffectDef] = &[
    BuiltinEffectDef {
        module: &[],
        name: "State",
        in_io_all: true,
        declared_in_source: false,
    },
    BuiltinEffectDef {
        module: &["IO"],
        name: "All",
        in_io_all: false,
        declared_in_source: false,
    },
    BuiltinEffectDef {
        module: &["IO", "Console"],
        name: "Write",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Console"],
        name: "Read",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "File"],
        name: "Read",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "File"],
        name: "Write",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Process"],
        name: "Run",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Process"],
        name: "Exit",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Process"],
        name: "Environment",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Clock"],
        name: "Time",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["IO", "Random"],
        name: "Generate",
        in_io_all: true,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["Network", "Http"],
        name: "Listen",
        in_io_all: false,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["Network", "Http"],
        name: "Connect",
        in_io_all: false,
        declared_in_source: true,
    },
    BuiltinEffectDef {
        module: &["Assert"],
        name: "Check",
        in_io_all: false,
        declared_in_source: true,
    },
];

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みの型を引く。
pub fn find_builtin_type(module: &[&str], name: &str) -> Option<BuiltinTypeId> {
    let index = BUILTIN_TYPES
        .iter()
        .position(|d| d.module == module && d.name == name)?;
    u16::try_from(index).ok().map(BuiltinTypeId)
}

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みのエフェクトを引く。
/// 標準ライブラリのソースで宣言したエフェクトを `EffectName::Builtin` にするときに使う。
pub fn find_builtin_effect(module: &[&str], name: &str) -> Option<BuiltinEffectId> {
    let index = BUILTIN_EFFECTS
        .iter()
        .position(|d| d.module == module && d.name == name)?;
    u16::try_from(index).ok().map(BuiltinEffectId)
}

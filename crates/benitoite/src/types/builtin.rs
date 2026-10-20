//! 組み込みの型とエフェクトの表（設計書 02-04「標準ライブラリのソースの持ち方」、01-07「組み込みのエフェクト」）。
//! 初期化の後に変更しないので `const` の表にする（02-01「コンパイル済みプログラムと実行ごとの状態」）。項目は末尾にだけ加える。

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
    /// 等値を持たない組み込みの不透明型
    Opaque,
    /// リソースの型。不透明型であり、`with` で束縛できる
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
    pub const INTEGER8: BuiltinTypeId = BuiltinTypeId(25);
    pub const INTEGER16: BuiltinTypeId = BuiltinTypeId(26);
    pub const INTEGER32: BuiltinTypeId = BuiltinTypeId(27);
    pub const UNSIGNED_INTEGER16: BuiltinTypeId = BuiltinTypeId(28);
    pub const UNSIGNED_INTEGER32: BuiltinTypeId = BuiltinTypeId(29);
    pub const UNSIGNED_INTEGER64: BuiltinTypeId = BuiltinTypeId(30);
    pub const FLOAT32: BuiltinTypeId = BuiltinTypeId(31);

    pub const INTEGER64: BuiltinTypeId = Self::INTEGER;
    pub const FLOAT64: BuiltinTypeId = Self::FLOAT;
    pub const UNSIGNED_INTEGER8: BuiltinTypeId = Self::BYTE;
    pub const UNSIGNED_INTEGER: BuiltinTypeId = Self::UNSIGNED_INTEGER64;

    /// 表の項目。
    pub fn def(self) -> Option<&'static BuiltinTypeDef> {
        BUILTIN_TYPES.get(usize::from(self.0))
    }

    /// 数の正の名前とは別に、既存の診断と型の書き出しの表示を保つ。
    pub(crate) fn display_name(self) -> Option<&'static str> {
        NUMBER_TYPE_NAMES
            .iter()
            .find(|names| names.id == self)
            .map(|names| names.display)
            .or_else(|| self.def().map(|def| def.name))
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
    BuiltinTypeDef {
        module: &["Integer8"],
        name: "Integer8",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Integer16"],
        name: "Integer16",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Integer32"],
        name: "Integer32",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["UnsignedInteger16"],
        name: "UnsignedInteger16",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["UnsignedInteger32"],
        name: "UnsignedInteger32",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["UnsignedInteger64"],
        name: "UnsignedInteger64",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
    BuiltinTypeDef {
        module: &["Float32"],
        name: "Float32",
        arity: 0,
        class: BuiltinTypeClass::Basic,
    },
];

/// 数の正の名前・別名・表示名。型の定義のモジュールは既存の型クラスの実装の所属を保つ。
pub(crate) struct BuiltinTypeNames {
    pub(crate) id: BuiltinTypeId,
    pub(crate) canonical: &'static str,
    pub(crate) aliases: &'static [&'static str],
    pub(crate) display: &'static str,
}

/// 別名にも同じ型の番号を使い、型クラスの実装や値の種類を増やさない。
pub(crate) const NUMBER_TYPE_NAMES: &[BuiltinTypeNames] = &[
    BuiltinTypeNames {
        id: BuiltinTypeId::INTEGER8,
        canonical: "Integer8",
        aliases: &[],
        display: "Integer8",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::INTEGER16,
        canonical: "Integer16",
        aliases: &[],
        display: "Integer16",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::INTEGER32,
        canonical: "Integer32",
        aliases: &[],
        display: "Integer32",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::INTEGER,
        canonical: "Integer64",
        aliases: &["Integer"],
        display: "Integer",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::BYTE,
        canonical: "UnsignedInteger8",
        aliases: &["Byte"],
        display: "Byte",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::UNSIGNED_INTEGER16,
        canonical: "UnsignedInteger16",
        aliases: &[],
        display: "UnsignedInteger16",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::UNSIGNED_INTEGER32,
        canonical: "UnsignedInteger32",
        aliases: &[],
        display: "UnsignedInteger32",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::UNSIGNED_INTEGER64,
        canonical: "UnsignedInteger64",
        aliases: &["UnsignedInteger"],
        display: "UnsignedInteger64",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::FLOAT32,
        canonical: "Float32",
        aliases: &[],
        display: "Float32",
    },
    BuiltinTypeNames {
        id: BuiltinTypeId::FLOAT,
        canonical: "Float64",
        aliases: &["Float"],
        display: "Float",
    },
];

/// 標準モジュールに登録する型名。既存の定義にない正の名前と別名を同じ番号へ追加する。
pub(crate) fn builtin_types_in<'a>(
    module: &'a [&'a str],
) -> impl Iterator<Item = (BuiltinTypeId, &'static str)> + 'a {
    let definitions = BUILTIN_TYPES
        .iter()
        .enumerate()
        .filter(move |(_, def)| def.module == module)
        .filter_map(|(index, def)| Some((BuiltinTypeId(u16::try_from(index).ok()?), def.name)));
    let names = NUMBER_TYPE_NAMES.iter().flat_map(move |names| {
        std::iter::once(names.canonical)
            .chain(names.aliases.iter().copied())
            .filter(move |name| {
                module == [*name] && !names.id.def().is_some_and(|def| def.name == *name)
            })
            .map(move |name| (names.id, name))
    });
    definitions.chain(names)
}

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

/// 組み込みのエフェクトを報告・上限の解析・型表示に共通の正規名へ写す。
/// `IO.All` は型表示のために保ち、原子的な契約への混入は呼び出し側が拒否する
/// （設計書 06-01「main の非実行の検査報告」、02-05「出力」）。
pub(crate) fn effect_name(id: BuiltinEffectId) -> Option<String> {
    let definition = id.def()?;
    if definition.module == ["Log"] && definition.name == "Log" {
        return Some("Log".into());
    }
    let module = match definition.module {
        ["IO" | "Network", rest @ ..] if !rest.is_empty() => rest,
        module => module,
    };
    Some(
        module
            .iter()
            .copied()
            .chain(std::iter::once(definition.name))
            .collect::<Vec<_>>()
            .join("."),
    )
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
    BuiltinEffectDef {
        module: &["Log"],
        name: "Log",
        in_io_all: false,
        declared_in_source: true,
    },
];

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みの型を引く。
pub fn find_builtin_type(module: &[&str], name: &str) -> Option<BuiltinTypeId> {
    builtin_types_in(module).find_map(|(id, candidate)| (candidate == name).then_some(id))
}

/// モジュールの名前の段（`Benitoite` を除く）と名前から、組み込みのエフェクトを引く。
/// 標準ライブラリのソースで宣言したエフェクトを `EffectName::Builtin` にするときに使う。
pub fn find_builtin_effect(module: &[&str], name: &str) -> Option<BuiltinEffectId> {
    let index = BUILTIN_EFFECTS
        .iter()
        .position(|d| d.module == module && d.name == name)?;
    u16::try_from(index).ok().map(BuiltinEffectId)
}

/// ソースに一般のパラメータ付き effect 宣言を追加せずに提供する標準の失敗宣言。
/// 名前解決・型検査・Skill の生成が同じ表を読む。
#[derive(Clone, Copy)]
pub struct FailureDeclaration {
    pub module: &'static str,
    pub effect: &'static str,
    pub operation: &'static str,
}

/// 型付きの非再開の失敗。prelude へは公開しない。
pub const FAILURE: FailureDeclaration = FailureDeclaration {
    module: "Failure",
    effect: "Fail",
    operation: "raise",
};

impl FailureDeclaration {
    /// 型引数は戻り値 T、固定するエラー型 E の順である。
    pub fn scheme(self) -> super::Scheme {
        let mut effects = super::EffectSet::empty();
        effects.insert_failure(super::Ty::Param(1));
        super::Scheme {
            param_names: vec!["error".into()],
            type_params: ["T", "E"]
                .into_iter()
                .map(|name| super::TypeParamInfo {
                    name: name.into(),
                    kind: super::ParamKind::Value,
                    builtin: None,
                })
                .collect(),
            effect_params: vec![],
            no_fail: vec![],
            class_constraints: vec![],
            params: vec![super::Ty::Param(1)],
            ret: super::Ty::Param(0),
            effects,
            wrote_io_all: false,
        }
    }
}

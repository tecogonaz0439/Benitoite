//! 標準署名の範囲の個数・種類・対象の位置と具体化の許容
//! （設計書 02-05「型とエフェクトの表現」）。利用者の型／行パラメータとは別に扱う。

use super::builtin::RangeIndex;
use super::scope::{Kind, Range};
use super::{EffectName, Scheme, Ty, TyCon};

/// 範囲の列に対する標準項目ごとの追加条件。個数と種類は別に必ず検査する。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RangeAdmission {
    /// 個数・種類を満たす任意の列。
    Any,
    /// outer 番目の範囲が inner 番目を一原子で覆う。
    Covers { outer: u32, inner: u32 },
}

/// IO の対象の形。純粋な署名では Untargeted を用いる。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum IoShape {
    /// 対象を持たない旧来の操作。
    Untargeted,
    /// 指定の種類の対象に作用する旧来の Top の操作。
    TopTargeted(Kind),
    /// 一つの検査済みの対象を引数の位置に持つ操作。
    Single { kind: Kind, position: u32 },
}

/// 認定した標準署名だけが持つ範囲の情報。呼び出しごとの範囲の列は含まない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RangeSignature {
    /// 宣言内の範囲変数の番号の順。長さが個数である。
    pub kinds: Vec<Kind>,
    pub admission: RangeAdmission,
    pub shape: IoShape,
}

impl Default for RangeSignature {
    fn default() -> Self {
        Self {
            kinds: vec![],
            admission: RangeAdmission::Any,
            shape: IoShape::Untargeted,
        }
    }
}

impl RangeSignature {
    /// 宣言した範囲変数の個数。
    pub fn range_count(&self) -> usize {
        self.kinds.len()
    }

    fn index_valid(&self, ix: &RangeIndex, kind: Option<Kind>) -> bool {
        match (ix.variable(), ix.range()) {
            (Some(i), None) => {
                usize::try_from(i)
                    .ok()
                    .and_then(|i| self.kinds.get(i))
                    .copied()
                    == kind
            }
            (None, Some(Range::Top)) => true,
            (None, Some(range)) => kind.is_some_and(|k| range.fits_kind(k)),
            _ => false,
        }
    }

    fn type_valid(&self, ty: &Ty) -> bool {
        let mut pending = vec![ty];
        while let Some(ty) = pending.pop() {
            match ty {
                Ty::Con(con, args, ix) => {
                    let kind = match con {
                        TyCon::Builtin(id) => id.value_kind(),
                        TyCon::Adt(_) | TyCon::External(_) => None,
                    };
                    if !self.index_valid(ix, kind) {
                        return false;
                    }
                    pending.extend(args);
                }
                Ty::Fn(f) => {
                    if !self.effects_valid(&f.effects) {
                        return false;
                    }
                    pending.extend(&f.params);
                    pending.push(&f.ret);
                }
                Ty::App(_, args) => pending.extend(args),
                Ty::Param(_) | Ty::Rigid { .. } => {}
            }
        }
        true
    }

    fn effects_valid(&self, effects: &super::EffectSet) -> bool {
        effects.names.iter().all(|atom| {
            let kind = match atom {
                EffectName::Builtin(id, _) => id.scope_kind(),
                EffectName::User(_, _) => None,
            };
            self.index_valid(atom.index(), kind)
        }) && effects.failures.iter().all(|ty| self.type_valid(ty))
    }

    /// 宣言の変数番号、種類、対象の位置、操作の戻り値の制限を検査する。
    /// 引数の範囲変数は最上位の不透明な値型だけに置ける。操作の戻り値には置けない。
    pub fn signature_valid(&self, scheme: &Scheme, operation: bool) -> bool {
        let Ok(count) = u32::try_from(self.kinds.len()) else {
            return false;
        };
        self.declaration_valid(scheme, count, operation)
            && self.admission_valid()
            && self.io_shape_valid(scheme, count, operation)
    }

    fn declaration_valid(&self, scheme: &Scheme, count: u32, operation: bool) -> bool {
        let names = scheme
            .param_names
            .iter()
            .collect::<std::collections::BTreeSet<_>>();
        let valid_param = |ty: &Ty| {
            ty.indices_valid(count)
                && self.type_valid(ty)
                && (matches!(ty, Ty::Con(TyCon::Builtin(id), args, _)
                    if id.value_kind().is_some() && args.is_empty())
                    || ty.indices_valid(0))
        };
        scheme.param_names.len() == scheme.params.len()
            && names.len() == scheme.param_names.len()
            && scheme.params.iter().all(valid_param)
            && scheme.ret.indices_valid(count)
            && self.type_valid(&scheme.ret)
            && scheme.effects.indices_valid(count)
            && self.effects_valid(&scheme.effects)
            && (!operation || (scheme.ret.indices_valid(0) && scheme.effect_params.is_empty()))
    }

    fn admission_valid(&self) -> bool {
        match self.admission {
            RangeAdmission::Any => true,
            RangeAdmission::Covers { outer, inner } => {
                let outer = usize::try_from(outer).ok().and_then(|i| self.kinds.get(i));
                let inner = usize::try_from(inner).ok().and_then(|i| self.kinds.get(i));
                outer.is_some() && outer == inner
            }
        }
    }

    fn io_shape_valid(&self, scheme: &Scheme, count: u32, operation: bool) -> bool {
        if operation
            && (scheme.effects.names.len() != 1
                || !scheme.effects.vars.is_empty()
                || !scheme.effects.failures.is_empty())
        {
            return false;
        }
        match self.shape {
            IoShape::Untargeted => {
                !operation
                    || (count == 0
                        && matches!(scheme.effects.names.as_slice(),
                [EffectName::Builtin(id, ix)] if id.scope_kind().is_none() && ix == &RangeIndex::TOP))
            }
            IoShape::TopTargeted(kind) => {
                operation
                    && count == 0
                    && matches!(scheme.effects.names.as_slice(), [EffectName::Builtin(id, ix)] if id.scope_kind() == Some(kind) && ix == &RangeIndex::TOP)
            }
            IoShape::Single { kind, position } => {
                if !operation
                    || self.kinds != [kind]
                    || !scheme.effects.vars.is_empty()
                    || !scheme.effects.failures.is_empty()
                {
                    return false;
                }
                let Some(Ty::Con(TyCon::Builtin(id), args, ix)) = usize::try_from(position)
                    .ok()
                    .and_then(|i| scheme.params.get(i))
                else {
                    return false;
                };
                args.is_empty()
                    && id.value_kind() == Some(kind)
                    && ix == &RangeIndex::var(0)
                    && matches!(scheme.effects.names.as_slice(), [EffectName::Builtin(id, ix)] if id.scope_kind() == Some(kind) && ix == &RangeIndex::var(0))
            }
        }
    }

    /// 個数・種類と項目の追加条件を照合する。Top の列も個数と種類は検査する。
    pub fn admits(&self, ranges: &[Range]) -> bool {
        if !self.admission_valid() {
            return false;
        }
        if ranges.len() != self.kinds.len()
            || !ranges
                .iter()
                .zip(&self.kinds)
                .all(|(range, kind)| range.fits_kind(*kind))
        {
            return false;
        }
        if ranges.iter().all(|range| range == &Range::Top) {
            return true;
        }
        match self.admission {
            RangeAdmission::Any => true,
            RangeAdmission::Covers { outer, inner } => {
                let outer = usize::try_from(outer).ok().and_then(|i| ranges.get(i));
                let inner = usize::try_from(inner).ok().and_then(|i| ranges.get(i));
                matches!((outer, inner), (Some(outer), Some(inner)) if outer.covers(inner))
            }
        }
    }

    /// 許容される範囲で署名を具体化する。範囲変数が残る結果は返さない。
    /// 型／行の代入はこの前後で独立して行い、その像にも確定した添字を要求する。
    pub fn instantiate(
        &self,
        scheme: &Scheme,
        ranges: &[Range],
        operation: bool,
    ) -> Option<Scheme> {
        if !self.signature_valid(scheme, operation) || !self.admits(ranges) {
            return None;
        }
        let mut out = scheme.clone();
        out.params = scheme
            .params
            .iter()
            .map(|ty| match ty {
                Ty::Con(TyCon::Builtin(id), args, ix) if id.value_kind().is_some() => {
                    Ty::Con(TyCon::Builtin(*id), args.clone(), ix.instantiate(ranges))
                }
                Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) | Ty::App(..) | Ty::Rigid { .. } => {
                    ty.clone()
                }
            })
            .collect();
        out.ret = scheme.ret.instantiate_ranges(ranges);
        out.effects = scheme.effects.instantiate_ranges(ranges);
        (out.params.iter().all(|ty| ty.indices_valid(0))
            && out.ret.indices_valid(0)
            && out.effects.indices_valid(0))
        .then_some(out)
    }

    /// 宣言した個数の Top で具体化する。範囲のない旧署名では空の列になる。
    pub fn instantiate_top(&self, scheme: &Scheme, operation: bool) -> Option<Scheme> {
        self.instantiate(scheme, &vec![Range::Top; self.kinds.len()], operation)
    }

    /// 節を調べる前の保護本体から添字を選ぶ（設計書 01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」）。
    /// 同名の閉じた原子が一つで行がない場合だけ、その範囲を使う。
    pub fn clause_ranges(&self, scheme: &Scheme, body: &super::EffectSet) -> Vec<Range> {
        let range = if self.kinds.is_empty() || !body.vars.is_empty() {
            Range::Top
        } else if let [EffectName::Builtin(name, _)] = scheme.effects.names.as_slice() {
            let mut matching = body.names.iter().filter_map(|atom| match atom {
                EffectName::Builtin(id, index) if id == name => Some(index),
                EffectName::Builtin(_, _) | EffectName::User(_, _) => None,
            });
            match (matching.next(), matching.next()) {
                (Some(index), None) => index.range().cloned().unwrap_or(Range::Top),
                _ => Range::Top,
            }
        } else {
            Range::Top
        };
        vec![range; self.range_count()]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId};
    use crate::types::scope::PathPattern;
    use crate::types::{EffVar, EffectSet, FnTy, TypeArg};

    fn path(index: RangeIndex) -> Ty {
        Ty::Con(TyCon::Builtin(BuiltinTypeId::PATH_IN), vec![], index)
    }
    fn unit() -> Ty {
        Ty::Con(TyCon::Builtin(BuiltinTypeId::UNIT), vec![], RangeIndex::TOP)
    }
    fn pure(params: Vec<Ty>, ret: Ty) -> Scheme {
        Scheme {
            param_names: params
                .iter()
                .enumerate()
                .map(|(i, _)| format!("arg{i}"))
                .collect(),
            type_params: vec![],
            effect_params: vec![],
            no_fail: vec![],
            class_constraints: vec![],
            params,
            ret,
            effects: EffectSet::empty(),
            wrote_io_all: false,
        }
    }

    // 関門: 標準署名の許容・具体化の公開境界を守る。個数不足をTopにする退行、
    // 種類を無視する退行、拡大を逆向きに認める退行を捕まえる。旧テストは署名を扱わない。
    #[test]
    fn range_signature_admission_and_closed_instantiation() -> Result<(), String> {
        let narrow =
            Range::Path(PathPattern::parse("/data/input").map_err(|error| format!("{error:?}"))?);
        let wide =
            Range::Path(PathPattern::parse("/data/**").map_err(|error| format!("{error:?}"))?);
        let signature = RangeSignature {
            kinds: vec![Kind::Path, Kind::Path],
            admission: RangeAdmission::Covers { outer: 1, inner: 0 },
            shape: IoShape::Untargeted,
        };
        let scheme = pure(vec![path(RangeIndex::var(0))], path(RangeIndex::var(1)));
        assert!(signature.signature_valid(&scheme, false));
        assert!(!signature.signature_valid(&scheme, true));
        for ranges in [
            vec![],
            vec![Range::Top],
            vec![Range::Top; 3],
            vec![wide.clone(), narrow.clone()],
        ] {
            assert!(signature.instantiate(&scheme, &ranges, false).is_none());
        }
        let closed = signature
            .instantiate(&scheme, &[narrow.clone(), wide.clone()], false)
            .ok_or("signature did not instantiate")?;
        assert_eq!(closed.params, vec![path(RangeIndex::fixed(narrow))]);
        assert_eq!(closed.ret, path(RangeIndex::fixed(wide)));
        assert!(closed.fn_ty().indices_valid(0));
        let top = signature
            .instantiate_top(&scheme, false)
            .ok_or("Top did not instantiate")?;
        assert_eq!(top.params, vec![path(RangeIndex::TOP)]);
        assert_eq!(top.ret, path(RangeIndex::TOP));
        let wrong_kind = Range::Host(
            crate::types::scope::HostPattern::parse("example.com")
                .map_err(|error| format!("{error:?}"))?,
        );
        assert!(!signature.admits(&[wrong_kind, Range::Top]));
        let mut invalid = signature.clone();
        invalid.admission = RangeAdmission::Covers { outer: 2, inner: 0 };
        assert!(!invalid.signature_valid(&scheme, false));
        assert!(!invalid.admits(&[Range::Top, Range::Top]));
        let mut invalid = signature.clone();
        invalid.kinds = vec![Kind::Path, Kind::Endpoint];
        assert!(!invalid.signature_valid(&scheme, false));
        assert!(!invalid.admits(&[Range::Top, Range::Top]));
        Ok(())
    }

    // 関門: 引数の対象位置と潜在効果・Failの中のrvarの境界。単なる型の具体化では
    // callback内の変数・操作の戻り値・効果側の種類の食い違いを捕まえられない。
    #[test]
    fn io_signature_validates_target_position_and_all_effect_indices() -> Result<(), String> {
        let read = BuiltinEffectId::FILE_READ;
        let mut scheme = pure(vec![path(RangeIndex::var(0))], unit());
        scheme
            .effects
            .insert_name(EffectName::Builtin(read, RangeIndex::var(0)));
        let signature = RangeSignature {
            kinds: vec![Kind::Path],
            admission: RangeAdmission::Any,
            shape: IoShape::Single {
                kind: Kind::Path,
                position: 0,
            },
        };
        assert!(signature.signature_valid(&scheme, true));
        let missing_shape = RangeSignature {
            shape: IoShape::Untargeted,
            ..signature.clone()
        };
        assert!(!missing_shape.signature_valid(&scheme, true));
        let closed = signature
            .instantiate_top(&scheme, true)
            .ok_or("Top did not instantiate")?;
        assert_eq!(
            closed.effects.names,
            vec![EffectName::Builtin(read, RangeIndex::TOP)]
        );
        let old_shape = RangeSignature {
            shape: IoShape::TopTargeted(Kind::Path),
            ..RangeSignature::default()
        };
        assert!(old_shape.signature_valid(&closed, true));
        let mut polymorphic = closed.clone();
        polymorphic.effect_params = vec!["E".into()];
        polymorphic.params.push(Ty::Fn(Box::new(FnTy {
            param_names: vec![],
            params: vec![],
            ret: unit(),
            effects: EffectSet {
                names: vec![],
                failures: vec![],
                vars: vec![EffVar(0)],
            },
        })));
        polymorphic.param_names.push("callback".into());
        assert!(!old_shape.signature_valid(&polymorphic, true));
        let mut mixed = closed.clone();
        mixed.effects.insert_var(EffVar(0));
        assert!(!old_shape.signature_valid(&mixed, true));
        mixed.effects = closed.effects.clone();
        mixed.effects.insert_failure(unit());
        assert!(!old_shape.signature_valid(&mixed, true));
        mixed.effects = closed.effects.clone();
        mixed.effects.insert_name(EffectName::Builtin(
            BuiltinEffectId::HTTP_CONNECT,
            RangeIndex::TOP,
        ));
        assert!(!old_shape.signature_valid(&mixed, true));
        for (target, effect) in [(1, 0), (0, 1)] {
            let mut invalid = scheme.clone();
            invalid.params = vec![path(RangeIndex::var(target))];
            invalid.effects.names = vec![EffectName::Builtin(read, RangeIndex::var(effect))];
            assert!(!signature.signature_valid(&invalid, true));
        }
        let wrong_position = RangeSignature {
            shape: IoShape::Single {
                kind: Kind::Path,
                position: 1,
            },
            ..signature.clone()
        };
        assert!(!wrong_position.signature_valid(&scheme, true));
        let mut callback = pure(
            vec![Ty::Fn(Box::new(FnTy {
                param_names: vec!["path".into()],
                params: scheme.params.clone(),
                ret: unit(),
                effects: EffectSet::empty(),
            }))],
            unit(),
        );
        let pure_signature = RangeSignature {
            shape: IoShape::Untargeted,
            ..signature.clone()
        };
        assert!(!pure_signature.signature_valid(&callback, false));
        callback.params = vec![Ty::Fn(Box::new(FnTy {
            param_names: vec![],
            params: vec![],
            ret: unit(),
            effects: scheme.effects.clone(),
        }))];
        assert!(!pure_signature.signature_valid(&callback, false));
        let mut failure = pure(vec![], unit());
        failure.effects.insert_failure(path(RangeIndex::var(1)));
        assert!(!pure_signature.signature_valid(&failure, false));
        failure.effects = scheme.effects.clone();
        failure.effects.names = vec![EffectName::Builtin(
            BuiltinEffectId::HTTP_CONNECT,
            RangeIndex::var(0),
        )];
        assert!(!pure_signature.signature_valid(&failure, false));
        for id in [
            BuiltinTypeId::IO_ERROR,
            BuiltinTypeId::NETWORK_ERROR,
            BuiltinTypeId::TASK,
            BuiltinTypeId::REFERENCE,
            BuiltinTypeId::LAZY,
            BuiltinTypeId::TASK_GROUP,
            BuiltinTypeId::REGEX_PATTERN,
        ] {
            assert!(!Ty::Con(TyCon::Builtin(id), vec![], RangeIndex::var(0)).indices_valid(1));
        }
        Ok(())
    }

    // 関門: 原子の範囲変数は構造等号で識別し、同番号だけが被覆する。範囲具体化と
    // 型／行の同時代入の合成を公開境界で確かめ、潜在効果・Failを取り落とす退行を捕まえる。
    #[test]
    fn atom_ranges_remain_structural_and_substitution_is_independent() -> Result<(), String> {
        let range =
            Range::Path(PathPattern::parse("/data/input").map_err(|error| format!("{error:?}"))?);
        let atom = |id, ix| EffectName::Builtin(id, ix);
        let atoms = [
            atom(BuiltinEffectId::FILE_READ, RangeIndex::TOP),
            atom(BuiltinEffectId::FILE_READ, RangeIndex::fixed(range.clone())),
            atom(BuiltinEffectId::FILE_READ, RangeIndex::var(0)),
            atom(BuiltinEffectId::FILE_READ, RangeIndex::var(1)),
            atom(BuiltinEffectId::FILE_WRITE, RangeIndex::var(0)),
        ];
        for a in &atoms {
            for b in &atoms {
                if a.index().variable().is_some() || b.index().variable().is_some() {
                    assert_eq!(a.covers(b), a == b);
                }
            }
        }
        assert_eq!(
            atoms.iter().collect::<std::collections::HashSet<_>>().len(),
            5
        );
        let mut effects = EffectSet::empty();
        effects.insert_name(atom(BuiltinEffectId::FILE_READ, RangeIndex::var(0)));
        effects.insert_name(atom(
            BuiltinEffectId::FILE_READ,
            RangeIndex::fixed(range.clone()),
        ));
        effects.insert_var(EffVar(0));
        effects.insert_failure(Ty::Fn(Box::new(FnTy {
            param_names: vec!["value".into()],
            params: vec![Ty::Param(0)],
            ret: path(RangeIndex::var(0)),
            effects: effects.clone(),
        })));
        assert!(!effects.indices_valid(0));
        assert!(effects.indices_valid(1));
        assert_eq!(effects.instantiate_ranges(&[]), effects);
        let mut image = EffectSet::empty();
        image.insert_name(atom(BuiltinEffectId::FILE_READ, RangeIndex::var(0)));
        let images = [image];
        let types = [TypeArg::Ty(path(RangeIndex::TOP))];
        let ranges = [range];
        let a = effects
            .subst_types(&types, &images)
            .instantiate_ranges(&ranges);
        let b = effects.instantiate_ranges(&ranges).subst_types(
            &types,
            &images
                .iter()
                .map(|effect| effect.instantiate_ranges(&ranges))
                .collect::<Vec<_>>(),
        );
        assert_eq!(a, b);
        assert!(a.indices_valid(0));
        assert_eq!(a.names.len(), 1);
        Ok(())
    }
}

//! R02 が個別に指定する方式の通知の計数。テストの構成だけに置く。
//! H6・H11: Slot を手放す通知の漏れと二重の通知を、公開層の操作から確かめる。

use std::cell::Cell;

#[derive(Default)]
pub(super) struct Events {
    pub(super) retained: Cell<u64>,
    pub(super) released: Cell<u64>,
}

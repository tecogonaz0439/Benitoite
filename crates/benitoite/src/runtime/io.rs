//! IO の操作とハンドラ表（設計書 02-09「ハンドラ表」）。

use super::Stop;
use super::Stream;
use super::heap::Heap;
use super::value::Value;

/// IO の操作（01-07「IO を行う組み込み関数」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum IoOp {
    /// `Console.print`
    Print,
    /// `Console.println`
    Println,
    /// `Console.eprintln`
    Eprintln,
    /// `File.readText`
    ReadText,
    /// `Process.args`
    Args,
}

/// ハンドラ表。
pub trait IoHandlers {
    /// IO の操作を行い、応答の値か止まる理由を返す。
    fn call(&mut self, op: IoOp, args: &[Value], heap: &mut Heap) -> Result<Value, Stop>;

    /// 出力のバッファを、標準出力、標準エラー出力の順にすべて書き出す（02-09「出力のバッファ」）。
    /// 書き出しに失敗した出力と理由を返す。バッファを持たないハンドラ表は何もしない。
    fn flush_all(&mut self) -> Vec<(Stream, String)> {
        Vec::new()
    }
}

/// テスト用のハンドラ表が記録する IO の事象（差分テストで比べる。07-03「差分テスト」）。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum IoEvent {
    Write { stream: Stream, text: String },
    ReadFile { path: String, ok: bool },
    Args,
}

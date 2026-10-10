//! HTTP/1.1 のサーバの接続の層（設計書 02-09「IO 実行器」、03-09「実装に使うクレート」「サーバ」「失敗の種類」）。
//! `mio` の型は、このモジュールと `runtime::io::event` の外に出さない（実装プラン 10-16）。

use super::event::{self, Wakeup};
use super::resources::{ResourceContent, ResourceState, ResourceTable};
use crate::builtins::iface::{Interest, OsResource};
use crate::builtins::table::tags;
use crate::runtime::heap::ResourceId;
use crate::runtime::sched::{ExtOpId, TimerId};
use crate::runtime::{ResourceKind, RuntimeError, Stop};
use crate::vm::TaskId;
use std::collections::{BTreeMap, BTreeSet};
use std::io::{self, Read, Write};
use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::time::{Duration, Instant};

/// 受け付ける要求の本体の大きさの上限（16 MiB。03-09「要求と応答の型」）。
/// 超えた要求には、処理系が状態コード 413 の応答を返す。
pub const MAX_REQUEST_BODY_BYTES: u64 = 16_777_216;
/// 資源の不足で受け付けをやり直すまで待つ時間の最初の値（ミリ秒。03-09「失敗の種類」）。
pub const ACCEPT_RETRY_INITIAL_MILLIS: u64 = 5;
/// 資源の不足で受け付けをやり直すまで待つ時間の上限（ミリ秒）。
pub const ACCEPT_RETRY_MAX_MILLIS: u64 = 1_000;
const MAX_HEAD_BYTES: usize = 65_536;
const MAX_HEADERS: usize = 100;
// 解放は利用者の timeout とは独立に終える（設計書 03-09「サーバ」）。
const RELEASE_TIMEOUT: Duration = Duration::from_secs(3);

mod text {
    pub const RETRY: &str = "HTTP accept temporarily failed; retrying: ";
    pub const INVALID_HOST: &str = "invalid listening address";
    pub const EMPTY_ADDRESSES: &str = "host resolved to no addresses";
    pub const WRITE_ZERO: &str = "connection closed during response";
    pub const RELEASE_TIMEOUT: &str = "HTTP exchange release timed out";
    // 理由の句を RFC 9110 の表に揃える（実装プラン 10-16「実装プランで決める値」）。
    pub(super) fn reason(status: u16) -> &'static str {
        match status {
            100 => "Continue",
            101 => "Switching Protocols",
            200 => "OK",
            201 => "Created",
            202 => "Accepted",
            203 => "Non-Authoritative Information",
            204 => "No Content",
            205 => "Reset Content",
            206 => "Partial Content",
            300 => "Multiple Choices",
            301 => "Moved Permanently",
            302 => "Found",
            303 => "See Other",
            304 => "Not Modified",
            305 => "Use Proxy",
            307 => "Temporary Redirect",
            308 => "Permanent Redirect",
            400 => "Bad Request",
            401 => "Unauthorized",
            402 => "Payment Required",
            403 => "Forbidden",
            404 => "Not Found",
            405 => "Method Not Allowed",
            406 => "Not Acceptable",
            407 => "Proxy Authentication Required",
            408 => "Request Timeout",
            409 => "Conflict",
            410 => "Gone",
            411 => "Length Required",
            412 => "Precondition Failed",
            413 => "Content Too Large",
            414 => "URI Too Long",
            415 => "Unsupported Media Type",
            416 => "Range Not Satisfiable",
            417 => "Expectation Failed",
            421 => "Misdirected Request",
            422 => "Unprocessable Content",
            426 => "Upgrade Required",
            500 => "Internal Server Error",
            501 => "Not Implemented",
            502 => "Bad Gateway",
            503 => "Service Unavailable",
            504 => "Gateway Timeout",
            505 => "HTTP Version Not Supported",
            _ => "",
        }
    }
}

/// ネットワークの失敗の種類と理由。組み込みの関数が言語の NetworkError に変える（設計書 03-09）。
#[derive(Debug)]
pub(crate) struct Failure {
    pub kind: u32,
    pub reason: String,
}
impl From<io::Error> for Failure {
    fn from(e: io::Error) -> Self {
        let kind = if e.kind() == io::ErrorKind::ConnectionRefused {
            tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED
        } else if matches!(
            e.kind(),
            io::ErrorKind::ConnectionReset
                | io::ErrorKind::ConnectionAborted
                | io::ErrorKind::BrokenPipe
                | io::ErrorKind::UnexpectedEof
        ) {
            tags::NETWORK_ERROR_KIND_CONNECTION_RESET
        } else if e.kind() == io::ErrorKind::TimedOut {
            tags::NETWORK_ERROR_KIND_TIMED_OUT
        } else if e.kind() == io::ErrorKind::AddrInUse {
            tags::NETWORK_ERROR_KIND_ADDRESS_IN_USE
        } else if matches!(
            e.kind(),
            io::ErrorKind::InvalidInput | io::ErrorKind::AddrNotAvailable
        ) {
            tags::NETWORK_ERROR_KIND_INVALID_INPUT
        } else if e.kind() == io::ErrorKind::PermissionDenied {
            tags::NETWORK_ERROR_KIND_PERMISSION_DENIED
        } else {
            tags::NETWORK_ERROR_KIND_OTHER
        };
        Self {
            kind,
            reason: e.to_string(),
        }
    }
}

/// 接続から読んだ要求の写し。言語の値を含めず、リソースの添え物に保存する（実装プラン 10-16）。
#[derive(Clone, Debug)]
pub(crate) struct RequestData {
    pub method: String,
    pub path: String,
    pub query: Vec<(String, String)>,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

#[derive(Debug)]
struct Registration {
    registry: std::sync::Arc<mio::Registry>,
    token: usize,
}
impl Registration {
    fn arm(
        slot: &mut Option<Self>,
        source: &mut impl mio::event::Source,
        wakeup: &Wakeup,
        interest: mio::Interest,
    ) -> Result<io::Result<usize>, Stop> {
        // 起こし口の欠落やトークンの溢れと、OS が返す接続・資源の失敗を区別する。
        // 前者だけを Stop にし、後者は呼ぶ側が操作に応じて扱う（02-09、03-09）。
        if let Some(reg) = slot {
            Ok(event::reregister(wakeup, source, reg.token, interest).map(|()| reg.token))
        } else {
            let token = event::next_token(wakeup)?;
            let registry = event::registry(wakeup).map_err(internal_io)?;
            if let Err(e) = event::register(wakeup, source, token, interest) {
                return Ok(Err(e));
            }
            *slot = Some(Self { registry, token });
            Ok(Ok(token))
        }
    }
    fn remove(slot: &mut Option<Self>, source: &mut impl mio::event::Source) -> io::Result<()> {
        if let Some(reg) = slot.as_ref() {
            // 解除の失敗でも登録の所有を失わない。次の再登録か資源の解放でやり直す。
            reg.registry.deregister(source)?;
        }
        *slot = None;
        Ok(())
    }
}
fn internal_io(e: io::Error) -> Stop {
    Stop::Internal(format!("HTTP readiness registration failed: {e}"))
}

/// 非同期の待ち受けと、要求を読みかけている接続を所有する（設計書 03-09「サーバ」）。
#[derive(Debug)]
pub(crate) struct Listener {
    socket: Option<mio::net::TcpListener>,
    #[cfg(test)]
    injected: std::collections::VecDeque<io::Error>,
    registration: Option<Registration>,
    connections: Vec<Connection>,
    retry_at: Option<u64>,
    retry_millis: u64,
    registration_failure: Option<io::Error>,
}
impl OsResource for Listener {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(mut self: Box<Self>) -> Result<(), String> {
        // ブロックしない解放は VM から直接呼ばれるので Registry を資源に持つ（実装プラン L30）。
        self.disarm().map_err(|e| e.to_string())
    }
}
impl Drop for Listener {
    fn drop(&mut self) {
        drop(self.disarm());
    }
}

/// 名前の解決と待ち受けの開始を行う。作業用のスレッドから呼ぶ（設計書 02-09「IO 実行器」）。
pub(crate) fn listen(host: &str, port: u16) -> Result<Listener, Failure> {
    if host.is_empty() || host.contains(['/', '\0', ' ', '[', ']']) {
        return Err(Failure {
            kind: tags::NETWORK_ERROR_KIND_INVALID_INPUT,
            reason: text::INVALID_HOST.into(),
        });
    }
    let addresses = (host, port).to_socket_addrs().map_err(|e| Failure {
        kind: if e.kind() == io::ErrorKind::InvalidInput {
            tags::NETWORK_ERROR_KIND_INVALID_INPUT
        } else {
            tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND
        },
        reason: e.to_string(),
    })?;
    let mut last = None;
    for address in addresses {
        match std::net::TcpListener::bind(address) {
            Ok(socket) => {
                socket.set_nonblocking(true)?;
                return Ok(Listener {
                    socket: Some(mio::net::TcpListener::from_std(socket)),
                    #[cfg(test)]
                    injected: std::collections::VecDeque::new(),
                    registration: None,
                    connections: Vec::new(),
                    retry_at: None,
                    retry_millis: ACCEPT_RETRY_INITIAL_MILLIS,
                    registration_failure: None,
                });
            }
            Err(e) => last = Some(e.into()),
        }
    }
    Err(last.unwrap_or_else(|| Failure {
        kind: tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
        reason: text::EMPTY_ADDRESSES.into(),
    }))
}

fn resource<T: OsResource>(
    table: &mut ResourceTable,
    id: ResourceId,
    kind: ResourceKind,
) -> Result<&mut T, Stop> {
    if table.kind(id) != Some(kind) {
        return Err(Stop::Internal("HTTP resource kind mismatch".into()));
    }
    if table.state(id) != Some(ResourceState::Open) {
        return Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind }));
    }
    let entry = table
        .entries
        .get_mut(&id)
        .ok_or_else(|| Stop::Internal("HTTP resource missing".into()))?;
    if entry.kind != kind {
        return Err(Stop::Internal("HTTP resource kind mismatch".into()));
    }
    if entry.state != ResourceState::Open {
        return Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind }));
    }
    let ResourceContent::Os(Some(handle)) = &mut entry.content else {
        return Err(Stop::Internal("HTTP resource handle missing".into()));
    };
    handle
        .as_any_mut()
        .downcast_mut()
        .ok_or_else(|| Stop::Internal("HTTP resource handle kind mismatch".into()))
}
/// 開いている待ち受けのポートを読む（実装プラン 10-16）。
pub(crate) fn listener_port(table: &mut ResourceTable, id: ResourceId) -> Result<u16, Stop> {
    resource::<Listener>(table, id, ResourceKind::HttpListener)?
        .socket
        .as_ref()
        .ok_or_else(|| Stop::Internal("HTTP listener socket missing".into()))?
        .local_addr()
        .map(|a| a.port())
        .map_err(internal_io)
}

#[derive(Debug)]
struct Connection {
    socket: Option<mio::net::TcpStream>,
    registration: Option<Registration>,
    reader: RequestReader,
    rejection: Option<WriteBuffer>,
    retry_registration: bool,
}
impl Connection {
    fn new(socket: mio::net::TcpStream) -> Self {
        Self {
            socket: Some(socket),
            registration: None,
            reader: RequestReader::default(),
            rejection: None,
            retry_registration: false,
        }
    }
    fn disarm(&mut self) -> io::Result<()> {
        match &mut self.socket {
            Some(socket) => Registration::remove(&mut self.registration, socket),
            None => Ok(()),
        }
    }
    fn advance(&mut self) -> ConnectionStep {
        let Some(socket) = &mut self.socket else {
            return ConnectionStep::Dropped;
        };
        if self.rejection.is_none() {
            loop {
                match self.reader.advance() {
                    ParseStep::Complete(request) => return ConnectionStep::Request(request),
                    ParseStep::Reject(code) => {
                        self.rejection = Some(WriteBuffer::new(error_response(code)));
                        break;
                    }
                    ParseStep::NeedMore => {}
                }
                let mut bytes = [0; 8192];
                match socket.read(&mut bytes) {
                    Ok(0) => return ConnectionStep::Dropped,
                    Ok(n) => {
                        if let Some(bytes) = bytes.get(..n) {
                            self.reader.input.extend_from_slice(bytes);
                        }
                    }
                    Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                    Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                        return ConnectionStep::Waiting;
                    }
                    Err(_) => return ConnectionStep::Dropped,
                }
            }
        }
        match self.rejection.as_mut().map(|buffer| buffer.advance(socket)) {
            Some(Ok(false)) => ConnectionStep::Waiting,
            Some(Ok(true) | Err(_)) | None => ConnectionStep::Dropped,
        }
    }
}
impl Drop for Connection {
    fn drop(&mut self) {
        drop(self.disarm());
    }
}
enum ConnectionStep {
    Waiting,
    Dropped,
    Request(RequestData),
}

pub(crate) enum AcceptStep {
    Waiting,
    Accepted(Box<Exchange>, RequestData),
    Failed(Failure),
}
/// 接続を WouldBlock まで進め、要求か再試行の待ちを返す（設計書 03-09「失敗の種類」）。
pub(crate) fn accept(
    table: &mut ResourceTable,
    id: ResourceId,
    now: u64,
) -> Result<(AcceptStep, Option<String>), Stop> {
    let listener = resource::<Listener>(table, id, ResourceKind::HttpListener)?;
    // 登録は VM が待ちを公開した後に行う。そこでの OS の失敗も、この入口で
    // accept と同じ分類・警告・タイマーの規則に従って扱う（03-09「失敗の種類」）。
    let mut warning = if let Some(e) = listener.registration_failure.take() {
        if resource_shortage(&e) {
            listener.retry(now, &e)?
        } else {
            return Ok((AcceptStep::Failed(e.into()), None));
        }
    } else {
        None
    };
    if listener.retry_at.is_none_or(|deadline| now >= deadline) {
        listener.retry_at = None;
        for connection in &mut listener.connections {
            connection.retry_registration = false;
        }
        loop {
            match listener.next_connection() {
                Ok((socket, _)) => {
                    listener.retry_millis = ACCEPT_RETRY_INITIAL_MILLIS;
                    listener.connections.push(Connection::new(socket));
                }
                Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => break,
                Err(e)
                    if e.kind() == io::ErrorKind::ConnectionAborted
                        || e.kind() == io::ErrorKind::ConnectionReset =>
                {
                    continue;
                }
                Err(e) if resource_shortage(&e) => {
                    warning = listener.retry(now, &e)?;
                    break;
                }
                Err(e) => return Ok((AcceptStep::Failed(e.into()), warning)),
            }
        }
    }
    let mut index = 0;
    while index < listener.connections.len() {
        let step = listener
            .connections
            .get_mut(index)
            .ok_or_else(|| Stop::Internal("HTTP connection missing".into()))?
            .advance();
        match step {
            ConnectionStep::Waiting => index = index.saturating_add(1),
            ConnectionStep::Dropped => {
                listener.connections.remove(index);
            }
            ConnectionStep::Request(request) => {
                let mut connection = listener.connections.remove(index);
                if let Err(e) = connection.disarm() {
                    // 接続を閉じれば OS の登録も消える。外部の解除の失敗で実行全体を止めない。
                    if resource_shortage(&e) && listener.retry_at.is_none() {
                        warning = listener.retry(now, &e)?;
                    }
                    continue;
                }
                let socket = connection
                    .socket
                    .take()
                    .ok_or_else(|| Stop::Internal("accepted connection has no socket".into()))?;
                return Ok((
                    AcceptStep::Accepted(
                        Box::new(Exchange {
                            socket: Some(socket),
                            release_socket: None,
                            registration: None,
                            response: None,
                            response_owner: None,
                            responded: false,
                            registration_failure: None,
                        }),
                        request,
                    ),
                    warning,
                ));
            }
        }
    }
    Ok((AcceptStep::Waiting, warning))
}
impl Listener {
    fn disarm(&mut self) -> io::Result<()> {
        match &mut self.socket {
            Some(socket) => Registration::remove(&mut self.registration, socket),
            None => Ok(()),
        }
    }
    fn next_connection(&mut self) -> io::Result<(mio::net::TcpStream, std::net::SocketAddr)> {
        #[cfg(test)]
        if let Some(error) = self.injected.pop_front() {
            return Err(error);
        }
        self.socket
            .as_mut()
            .ok_or_else(|| io::Error::other("HTTP listener socket missing"))?
            .accept()
    }
    fn retry(&mut self, now: u64, e: &io::Error) -> Result<Option<String>, Stop> {
        let warning = (self.retry_millis == ACCEPT_RETRY_INITIAL_MILLIS)
            .then(|| format!("{}{e}\n", text::RETRY));
        self.retry_at = Some(
            now.checked_add(self.retry_millis)
                .ok_or_else(|| Stop::Internal("accept retry deadline overflow".into()))?,
        );
        self.retry_millis = self
            .retry_millis
            .saturating_mul(2)
            .min(ACCEPT_RETRY_MAX_MILLIS);
        Ok(warning)
    }
}
fn resource_shortage(e: &io::Error) -> bool {
    // errno の値は macOS と Linux で異なる（設計書 02-09「組み込みの操作とハンドラ表」）。
    #[cfg(target_os = "macos")]
    const ERRORS: &[i32] = &[24, 23, 55, 12];
    #[cfg(not(target_os = "macos"))]
    const ERRORS: &[i32] = &[24, 23, 105, 12];
    e.raw_os_error().is_some_and(|code| ERRORS.contains(&code))
}

/// 一つの要求に対応する接続と書きかけの応答を所有する（設計書 03-09「サーバ」）。
#[derive(Debug)]
pub(crate) struct Exchange {
    socket: Option<mio::net::TcpStream>,
    release_socket: Option<Arc<std::net::TcpStream>>,
    registration: Option<Registration>,
    response: Option<WriteBuffer>,
    response_owner: Option<TaskId>,
    responded: bool,
    registration_failure: Option<Failure>,
}
impl OsResource for Exchange {
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
    fn release(mut self: Box<Self>) -> Result<(), String> {
        // 途中の応答を完送すると、読まない相手が作業用スレッドを塞ぐ。
        // 既に送った応答へ 500 も重ねない（設計書 03-09「サーバ」）。
        if self.responded
            || self
                .response
                .as_ref()
                .is_some_and(|buffer| buffer.written > 0)
        {
            return self.close().map_err(|e| e.to_string());
        }
        self.response = None;
        let Some(socket) = self.prepare_release().map_err(|e| e.to_string())? else {
            return Ok(());
        };
        let result = write_release_response(&socket);
        let closed = self.close();
        result.and(closed).map_err(|e| e.to_string())
    }
}

fn write_release_response(socket: &std::net::TcpStream) -> io::Result<()> {
    let started = Instant::now();
    socket.set_nonblocking(false)?;
    let bytes = error_response(500);
    let mut remaining = bytes.as_slice();
    let mut writer = socket;
    while !remaining.is_empty() {
        // 部分書き込みと EINTR のたびに期限を更新せず、総時間を制限する。
        let timeout = RELEASE_TIMEOUT.saturating_sub(started.elapsed());
        if timeout.is_zero() {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                text::RELEASE_TIMEOUT,
            ));
        }
        socket.set_write_timeout(Some(timeout))?;
        match writer.write(remaining) {
            Ok(0) => return Err(io::Error::new(io::ErrorKind::WriteZero, text::WRITE_ZERO)),
            Ok(n) => remaining = remaining.get(n..).unwrap_or(&[]),
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e),
        }
    }
    Ok(())
}
impl Exchange {
    /// 書き込み用の接続を VM と共有する。停止時に作業用スレッドを待たず shutdown するためである。
    /// 記述子を複製せず、通常の応答の間は共有のための領域も作らない（02-09「リソースの追跡」）。
    pub(super) fn prepare_release(&mut self) -> io::Result<Option<Arc<std::net::TcpStream>>> {
        self.disarm()?;
        if let Some(socket) = self.socket.take() {
            self.release_socket = Some(Arc::new(socket.into()));
        }
        Ok(self.release_socket.as_ref().map(Arc::clone))
    }
    fn close(&mut self) -> io::Result<()> {
        let disarmed = self.disarm();
        self.registration = None;
        let closed = if let Some(socket) = self.socket.take() {
            socket.shutdown(std::net::Shutdown::Both)
        } else if let Some(socket) = self.release_socket.take() {
            socket.shutdown(std::net::Shutdown::Both)
        } else {
            Ok(())
        };
        self.response = None;
        disarmed.and(closed)
    }
    fn disarm(&mut self) -> io::Result<()> {
        match &mut self.socket {
            Some(socket) => Registration::remove(&mut self.registration, socket),
            None => Ok(()),
        }
    }
}
impl Drop for Exchange {
    fn drop(&mut self) {
        drop(self.close());
    }
}

/// 停止中の Exchange は 500 を送らず閉じる。既に始めた解放の完了も待たない（02-09「リソースの追跡」）。
pub(crate) fn stop_exchange(table: &mut ResourceTable, id: ResourceId) -> bool {
    let Some(entry) = table.entries.get_mut(&id) else {
        return false;
    };
    if entry.kind != ResourceKind::HttpExchange {
        return false;
    }
    let ResourceContent::Os(handle) = &mut entry.content else {
        return false;
    };
    if let Some(os) = handle.as_mut() {
        let Some(exchange) = os.as_any_mut().downcast_mut::<Exchange>() else {
            return false;
        };
        drop(exchange.close());
        *handle = None;
    } else if let Some(socket) = table
        .attachments
        .get(&id)
        .and_then(|value| value.downcast_ref::<Option<Arc<std::net::TcpStream>>>())
    {
        if let Some(socket) = socket {
            drop(socket.shutdown(std::net::Shutdown::Both));
        }
        // 作業の記録は完了まで保つ。shutdown 後の完了を共通の経路で受け取る。
    } else if entry.state != ResourceState::Released {
        return false;
    }
    table.finish_release(id, Ok(()));
    true
}

/// 応答の途中の位置を保存し、書き終えたら接続を閉じる（実装プラン 10-16）。
pub(crate) fn respond(
    table: &mut ResourceTable,
    id: ResourceId,
    owner: TaskId,
    response: Vec<u8>,
) -> Result<Option<Result<(), Failure>>, Stop> {
    let exchange = resource::<Exchange>(table, id, ResourceKind::HttpExchange)?;
    if exchange.responded || exchange.response_owner.is_some_and(|task| task != owner) {
        return Err(Stop::Runtime(RuntimeError::ResponseSentTwice));
    }
    if let Some(failure) = exchange.registration_failure.take() {
        exchange.responded = true;
        exchange.response = None;
        exchange.socket = None;
        exchange.registration = None;
        return Ok(Some(Err(failure)));
    }
    if exchange.response.is_none() {
        exchange.response = Some(WriteBuffer::new(response));
        exchange.response_owner = Some(owner);
    }
    let result = match (&mut exchange.response, &mut exchange.socket) {
        (Some(buffer), Some(socket)) => buffer.advance(socket),
        _ => return Err(Stop::Internal("HTTP response state missing".into())),
    };
    match result {
        Ok(false) => Ok(None),
        result => {
            exchange.responded = true;
            exchange.response = None;
            let disarmed = exchange.disarm();
            exchange.socket = None;
            exchange.registration = None;
            Ok(Some(
                result.and(disarmed).map(|_| ()).map_err(Failure::from),
            ))
        }
    }
}

#[derive(Debug)]
struct WriteBuffer {
    bytes: Vec<u8>,
    written: usize,
}
impl WriteBuffer {
    fn new(bytes: Vec<u8>) -> Self {
        Self { bytes, written: 0 }
    }
    fn remaining(&self) -> &[u8] {
        self.bytes.get(self.written..).unwrap_or(&[])
    }
    fn advance(&mut self, socket: &mut mio::net::TcpStream) -> io::Result<bool> {
        while !self.remaining().is_empty() {
            match socket.write(self.remaining()) {
                Ok(0) => return Err(io::Error::new(io::ErrorKind::WriteZero, text::WRITE_ZERO)),
                Ok(n) => self.written = self.written.saturating_add(n),
                Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => return Ok(false),
                Err(e) => return Err(e),
            }
        }
        Ok(true)
    }
}

#[derive(Debug, Default)]
struct RequestReader {
    input: Vec<u8>,
    request: Option<RequestData>,
    body: BodyRead,
}
#[derive(Debug, Default)]
enum BodyRead {
    #[default]
    Head,
    Length(usize),
    ChunkSize,
    ChunkData(usize),
    Trailers(usize),
}
enum ParseStep {
    NeedMore,
    Complete(RequestData),
    Reject(u16),
}
impl RequestReader {
    fn advance(&mut self) -> ParseStep {
        loop {
            match self.body {
                BodyRead::Head => {
                    let mut headers = [httparse::EMPTY_HEADER; MAX_HEADERS];
                    let mut request = httparse::Request::new(&mut headers);
                    let count = match request.parse(&self.input) {
                        Ok(httparse::Status::Partial) => {
                            return if self.input.len() > MAX_HEAD_BYTES {
                                ParseStep::Reject(431)
                            } else {
                                ParseStep::NeedMore
                            };
                        }
                        Ok(httparse::Status::Complete(n)) => n,
                        Err(httparse::Error::TooManyHeaders) => return ParseStep::Reject(431),
                        Err(_) => return ParseStep::Reject(400),
                    };
                    if count > MAX_HEAD_BYTES {
                        return ParseStep::Reject(431);
                    }
                    let Some(method) = request.method else {
                        return ParseStep::Reject(400);
                    };
                    let Some(target) = request.path else {
                        return ParseStep::Reject(400);
                    };
                    let (path, query) = target.split_once('?').unwrap_or((target, ""));
                    let Some(query) = parse_query(query) else {
                        return ParseStep::Reject(400);
                    };
                    let mut result = RequestData {
                        method: method.into(),
                        path: path.into(),
                        query,
                        headers: Vec::new(),
                        body: Vec::new(),
                    };
                    let mut length = None;
                    let mut chunked = false;
                    for header in request.headers.iter() {
                        let Ok(value) = std::str::from_utf8(header.value) else {
                            return ParseStep::Reject(400);
                        };
                        let name = header.name.to_ascii_lowercase();
                        if name == "content-length" {
                            if length.is_some()
                                || value.is_empty()
                                || !value.bytes().all(|b| b.is_ascii_digit())
                            {
                                return ParseStep::Reject(400);
                            }
                            let Ok(n) = value.parse::<u64>() else {
                                return ParseStep::Reject(413);
                            };
                            length = Some(n);
                        }
                        if name == "transfer-encoding" {
                            if chunked || !value.eq_ignore_ascii_case("chunked") {
                                return ParseStep::Reject(400);
                            }
                            chunked = true;
                        }
                        result.headers.push((name, value.into()));
                    }
                    if chunked && length.is_some() {
                        return ParseStep::Reject(400);
                    }
                    if length.is_some_and(|n| n > MAX_REQUEST_BODY_BYTES) {
                        return ParseStep::Reject(413);
                    }
                    self.body = if chunked {
                        BodyRead::ChunkSize
                    } else {
                        BodyRead::Length(usize::try_from(length.unwrap_or(0)).unwrap_or(usize::MAX))
                    };
                    self.request = Some(result);
                    self.input.drain(..count);
                }
                BodyRead::Length(length) => {
                    if self.input.len() < length {
                        return ParseStep::NeedMore;
                    }
                    if let Some(request) = &mut self.request {
                        request.body.extend(self.input.drain(..length));
                    }
                    return self.complete();
                }
                BodyRead::ChunkSize => {
                    let Some(end) = line_end(&self.input) else {
                        return if self.input.len() > MAX_HEAD_BYTES {
                            ParseStep::Reject(400)
                        } else {
                            ParseStep::NeedMore
                        };
                    };
                    let Some(line) = self
                        .input
                        .get(..end)
                        .and_then(|s| std::str::from_utf8(s).ok())
                    else {
                        return ParseStep::Reject(400);
                    };
                    let size = line.split(';').next().unwrap_or("");
                    if size.is_empty() || !size.bytes().all(|b| b.is_ascii_hexdigit()) {
                        return ParseStep::Reject(400);
                    }
                    let Ok(size) = u64::from_str_radix(size, 16) else {
                        return ParseStep::Reject(413);
                    };
                    let Some(request) = &self.request else {
                        return ParseStep::Reject(400);
                    };
                    if size.saturating_add(u64::try_from(request.body.len()).unwrap_or(u64::MAX))
                        > MAX_REQUEST_BODY_BYTES
                    {
                        return ParseStep::Reject(413);
                    }
                    self.input.drain(..end.saturating_add(2));
                    self.body = if size == 0 {
                        BodyRead::Trailers(0)
                    } else {
                        BodyRead::ChunkData(usize::try_from(size).unwrap_or(usize::MAX))
                    };
                }
                BodyRead::ChunkData(size) => {
                    if self.input.len() < size.saturating_add(2) {
                        return ParseStep::NeedMore;
                    }
                    if self.input.get(size..size.saturating_add(2)) != Some(b"\r\n") {
                        return ParseStep::Reject(400);
                    }
                    if let Some(request) = &mut self.request {
                        request.body.extend(self.input.drain(..size));
                    }
                    self.input.drain(..2);
                    self.body = BodyRead::ChunkSize;
                }
                BodyRead::Trailers(total) => {
                    let Some(end) = line_end(&self.input) else {
                        return if total.saturating_add(self.input.len()) > MAX_HEAD_BYTES {
                            ParseStep::Reject(431)
                        } else {
                            ParseStep::NeedMore
                        };
                    };
                    if end == 0 {
                        return self.complete();
                    }
                    if total.saturating_add(end) > MAX_HEAD_BYTES {
                        return ParseStep::Reject(431);
                    }
                    if !self
                        .input
                        .get(..end)
                        .is_some_and(|line| line.contains(&b':'))
                    {
                        return ParseStep::Reject(400);
                    }
                    self.input.drain(..end.saturating_add(2));
                    self.body = BodyRead::Trailers(total.saturating_add(end).saturating_add(2));
                }
            }
        }
    }
    fn complete(&mut self) -> ParseStep {
        self.request
            .take()
            .map_or(ParseStep::Reject(400), ParseStep::Complete)
    }
}
fn line_end(bytes: &[u8]) -> Option<usize> {
    bytes.windows(2).position(|w| w == b"\r\n")
}
fn decode_query(s: &str) -> Option<String> {
    let mut output = Vec::with_capacity(s.len());
    let mut bytes = s.bytes();
    while let Some(byte) = bytes.next() {
        if byte == b'+' {
            output.push(b' ');
        } else if byte == b'%' {
            let mut look = bytes.clone();
            let decoded = look
                .next()
                .and_then(|a| char::from(a).to_digit(16))
                .zip(look.next().and_then(|b| char::from(b).to_digit(16)));
            if let Some((a, b)) = decoded {
                output.push(u8::try_from(a.saturating_mul(16).saturating_add(b)).ok()?);
                bytes = look;
            } else {
                output.push(byte);
            }
        } else {
            output.push(byte);
        }
    }
    String::from_utf8(output).ok()
}
fn parse_query(s: &str) -> Option<Vec<(String, String)>> {
    s.split('&')
        .filter(|s| !s.is_empty())
        .map(|part| {
            let (name, value) = part.split_once('=').unwrap_or((part, ""));
            Some((decode_query(name)?, decode_query(value)?))
        })
        .collect()
}

/// 全長の上限を検査してから応答を組み立て、処理系が付けるヘッダを置き換える（02-09「一つの操作で作る値の大きさの上限」、10-16）。
pub(crate) fn response_bytes(
    status: u16,
    headers: &[(String, String)],
    body: &[u8],
) -> Result<Vec<u8>, Stop> {
    let mut head = format!("HTTP/1.1 {status} {}\r\n", text::reason(status));
    // 応答の全長を調べてから大きな領域を作る（02-09「一つの操作で作る値の大きさの上限」）。固定の頭だけを先に作る。
    let tail = format!(
        "content-length: {}\r\nconnection: close\r\n\r\n",
        body.len()
    );
    let mut length = head
        .len()
        .checked_add(tail.len())
        .and_then(|n| n.checked_add(body.len()));
    for (name, value) in headers {
        if !name.eq_ignore_ascii_case("content-length") && !name.eq_ignore_ascii_case("connection")
        {
            length = length
                .and_then(|n| n.checked_add(name.len()))
                .and_then(|n| n.checked_add(value.len()))
                .and_then(|n| n.checked_add(4));
        }
    }
    let length = length
        .and_then(|n| u64::try_from(n).ok())
        .ok_or_else(|| Stop::Internal("HTTP response size overflow".into()))?;
    crate::runtime::heap::CheckedLen::bytes(length, "Benitoite.Network.Http.respond")?;
    for (name, value) in headers {
        if !name.eq_ignore_ascii_case("content-length") && !name.eq_ignore_ascii_case("connection")
        {
            head.push_str(name);
            head.push_str(": ");
            head.push_str(value);
            head.push_str("\r\n");
        }
    }
    head.push_str(&tail);
    let mut bytes = head.into_bytes();
    bytes.extend_from_slice(body);
    Ok(bytes)
}
fn error_response(status: u16) -> Vec<u8> {
    format!(
        "HTTP/1.1 {status} {}\r\ncontent-length: 0\r\nconnection: close\r\n\r\n",
        text::reason(status)
    )
    .into_bytes()
}

/// 待ちの対応は言語の値を含まない。取り消しでは配送先だけを外し、準備の後に登録を手放す（02-09「タスクの待ちと取り消し」）。
#[derive(Debug, Default)]
pub(crate) struct ReadinessState {
    pub tokens: BTreeMap<usize, BTreeSet<ExtOpId>>,
    pub resources: BTreeMap<ExtOpId, ResourceId>,
    pub retries: BTreeMap<TimerId, ExtOpId>,
    pub op_tokens: BTreeMap<ExtOpId, Vec<usize>>,
    pub op_timers: BTreeMap<ExtOpId, TimerId>,
    pub resource_ops: BTreeMap<ResourceId, BTreeSet<ExtOpId>>,
}
/// 登録した準備のトークンと、資源不足で再試行する期限（実装プラン 10-16）。
pub(crate) struct Armed {
    pub tokens: Vec<usize>,
    pub deadline: Option<u64>,
}
/// リソースの接続を登録し、VM が操作と対応付けるトークンと期限を返す（実装プラン 10-16）。
pub(crate) fn arm(
    table: &mut ResourceTable,
    id: ResourceId,
    wakeup: &Wakeup,
    interest: Interest,
) -> Result<Armed, Stop> {
    let kind = table
        .entries
        .get(&id)
        .ok_or_else(|| Stop::Internal("readiness resource missing".into()))?
        .kind;
    match kind {
        ResourceKind::HttpListener => {
            let listener = resource::<Listener>(table, id, kind)?;
            let mut tokens = Vec::new();
            if listener.retry_at.is_none() {
                let socket = listener
                    .socket
                    .as_mut()
                    .ok_or_else(|| Stop::Internal("HTTP listener socket missing".into()))?;
                match Registration::arm(
                    &mut listener.registration,
                    socket,
                    wakeup,
                    mio::Interest::READABLE,
                )? {
                    Ok(token) => tokens.push(token),
                    Err(e) => {
                        listener.registration_failure = Some(e);
                        return Ok(Armed {
                            tokens,
                            deadline: Some(0),
                        });
                    }
                }
            } else {
                // 失敗した解除は登録を保持する。再試行の期限で再登録できる。
                drop(listener.disarm());
            }
            let mut index = 0;
            while index < listener.connections.len() {
                let connection = listener
                    .connections
                    .get_mut(index)
                    .ok_or_else(|| Stop::Internal("HTTP connection missing".into()))?;
                if connection.retry_registration {
                    index = index.saturating_add(1);
                    continue;
                }
                if let Some(socket) = &mut connection.socket {
                    let interest = if connection.rejection.is_some() {
                        mio::Interest::WRITABLE
                    } else {
                        mio::Interest::READABLE
                    };
                    match Registration::arm(&mut connection.registration, socket, wakeup, interest)?
                    {
                        Ok(token) => tokens.push(token),
                        Err(e) if resource_shortage(&e) => {
                            connection.retry_registration = true;
                            if listener.retry_at.is_some() {
                                // 別の接続の準備で早く戻っても、既に決めた再試行の期限を保つ。
                                index = index.saturating_add(1);
                                continue;
                            }
                            listener.registration_failure = Some(e);
                            // 即時のタイマーで Http.accept に戻し、通常の警告と再試行へ接続する。
                            // 登録の失敗した接続は、資源が戻るまで所有を保つ（03-09「失敗の種類」）。
                            return Ok(Armed {
                                tokens,
                                deadline: Some(0),
                            });
                        }
                        Err(_) => {
                            // 読みかけの一つの接続の失敗は、ほかの要求の待ちを終えない（03-09）。
                            listener.connections.remove(index);
                            continue;
                        }
                    }
                }
                index = index.saturating_add(1);
            }
            if listener.retry_at.is_none() {
                // 登録まで成功したら資源不足の連続は終わる。次の不足では再び一度だけ警告する。
                listener.retry_millis = ACCEPT_RETRY_INITIAL_MILLIS;
            }
            Ok(Armed {
                tokens,
                deadline: listener.retry_at,
            })
        }
        ResourceKind::HttpExchange => {
            let exchange = resource::<Exchange>(table, id, kind)?;
            let socket = exchange
                .socket
                .as_mut()
                .ok_or_else(|| Stop::Internal("readiness exchange missing socket".into()))?;
            let interest = match interest {
                Interest::Readable => mio::Interest::READABLE,
                Interest::Writable => mio::Interest::WRITABLE,
            };
            match Registration::arm(&mut exchange.registration, socket, wakeup, interest)? {
                Ok(token) => Ok(Armed {
                    tokens: vec![token],
                    deadline: None,
                }),
                Err(e) => {
                    // 応答の失敗は次の Http.respond で NetworkError として返す（03-09）。
                    exchange.registration_failure = Some(e.into());
                    Ok(Armed {
                        tokens: Vec::new(),
                        deadline: Some(0),
                    })
                }
            }
        }
        ResourceKind::FileReader | ResourceKind::FileWriter | ResourceKind::TaskGroup => {
            Err(Stop::Internal("unsupported readiness resource".into()))
        }
    }
}
/// 最後の準備の待ちを除いたリソースの登録を外す（実装プラン L30）。
pub(crate) fn disarm(
    table: &mut ResourceTable,
    id: ResourceId,
    _wakeup: &Wakeup,
) -> Result<(), Stop> {
    let Some(entry) = table.entries.get_mut(&id) else {
        return Ok(());
    };
    let ResourceContent::Os(Some(handle)) = &mut entry.content else {
        return Ok(());
    };
    if let Some(listener) = handle.as_any_mut().downcast_mut::<Listener>() {
        // 待ちの配送先を外す処理で OS の解除の失敗を内部エラーに変えない。
        // Registration は失敗した登録を保持し、再登録か資源の解放で処理する。
        drop(listener.disarm());
        for connection in &mut listener.connections {
            drop(connection.disarm());
        }
    } else if let Some(exchange) = handle.as_any_mut().downcast_mut::<Exchange>() {
        drop(exchange.disarm());
    }
    Ok(())
}

#[cfg(test)]
mod tests;

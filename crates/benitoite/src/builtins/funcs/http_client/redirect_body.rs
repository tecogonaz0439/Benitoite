//! 3xx の本体を、ureq のリダイレクト処理より前に検査する（設計書 03-09「失敗の種類」）。

use std::io;
use std::time::Instant;
use ureq::http::{Method, Request};
use ureq::unversioned::transport::time::Duration;
use ureq::unversioned::transport::{Buffers, ConnectionDetails, Connector, NextTimeout, Transport};
use ureq_proto::client::state::{RecvBody, RecvResponse};
use ureq_proto::client::{Call, RecvResponseResult, SendRequestResult};

// ureq 3.4.2 は 0\r\n の直後の切断を許し、その後の consume_redirect_body で panic
// する。TLS の復号後のバイト列で同じ解析器の can_proceed を確かめ、終端の欠落を
// InvalidHTTPData にする。URL・方法・ヘッダ・時間の規則は従来の ureq に任せる。
#[derive(Debug)]
pub(super) struct CheckedConnector<C>(pub(super) C);

impl<C: Connector> Connector for CheckedConnector<C> {
    type Out = CheckedTransport<C::Out>;

    fn connect(
        &self,
        details: &ConnectionDetails,
        chained: Option<()>,
    ) -> Result<Option<Self::Out>, ureq::Error> {
        Ok(self
            .0
            .connect(details, chained)?
            .map(|inner| CheckedTransport {
                inner,
                check: BodyCheck::Idle,
                pending: Vec::new(),
                size: 0,
                header_limit: details.config.max_response_header_size(),
            }))
    }
}

#[derive(Debug)]
pub(super) struct CheckedTransport<T> {
    inner: T,
    check: BodyCheck,
    pending: Vec<u8>,
    size: u64,
    header_limit: usize,
}

#[derive(Debug)]
enum BodyCheck {
    Idle,
    Headers(Call<RecvResponse>),
    Body(Call<RecvBody>),
}

impl<T: Transport> Transport for CheckedTransport<T> {
    fn buffers(&mut self) -> &mut dyn Buffers {
        self.inner.buffers()
    }

    fn transmit_output(&mut self, amount: usize, timeout: NextTimeout) -> Result<(), ureq::Error> {
        if matches!(self.check, BodyCheck::Idle) {
            // 3xx の本体の有無に関係する方法は HEAD だけである。要求を変更せず、
            // 検査用の解析器だけを同じ本体の受信規則で初期化する。
            let method = if self.inner.buffers().output().starts_with(b"HEAD ") {
                Method::HEAD
            } else {
                Method::GET
            };
            self.check = BodyCheck::Headers(response_parser(method)?);
            self.pending.clear();
            self.size = 0;
        }
        self.inner.transmit_output(amount, timeout)
    }

    fn await_input(&mut self, timeout: NextTimeout) -> Result<bool, ureq::Error> {
        let started = Instant::now();
        loop {
            // 頭が分割されても、この呼び出しに渡された時間の上限を延ばさない。
            let mut remaining = timeout;
            if let Duration::Exact(after) = timeout.after {
                let after = after.saturating_sub(started.elapsed());
                if after.is_zero() {
                    return Err(ureq::Error::Timeout(timeout.reason));
                }
                remaining.after = Duration::Exact(after);
            }
            let previous = self.inner.buffers().input().len();
            let result = self.inner.await_input(remaining);
            let input = self.inner.buffers().input();
            // 未消費のバイトを二度数えず、新しく読んだ部分だけを検査に渡す。
            let added = input.get(previous..).ok_or_else(invalid_body)?;
            self.pending.extend_from_slice(added);
            self.check_input()?;
            let closed = matches!(&result, Ok(false))
                || matches!(&result, Err(ureq::Error::Io(error)) if matches!(error.kind(),
                    io::ErrorKind::UnexpectedEof | io::ErrorKind::ConnectionAborted | io::ErrorKind::ConnectionReset));
            let partial_redirect = matches!(self.check, BodyCheck::Headers(_))
                && self.pending.starts_with(b"HTTP/")
                && self.pending.get(9) == Some(&b'3');
            if closed
                && (partial_redirect
                    || matches!(&self.check, BodyCheck::Body(call) if !call.can_proceed()))
            {
                return Err(invalid_body());
            }
            // ureq の部分的なリダイレクトの解析は、Location の後のヘッダを待たない。
            // 3xx では頭を読み終えてから渡し、後から届く Transfer-Encoding を見落とさない。
            if partial_redirect && matches!(result, Ok(true)) {
                continue;
            }
            return result;
        }
    }

    fn is_open(&mut self) -> bool {
        self.inner.is_open()
    }

    fn is_tls(&self) -> bool {
        self.inner.is_tls()
    }
}

impl<T> CheckedTransport<T> {
    fn check_input(&mut self) -> Result<(), ureq::Error> {
        let mut consumed = 0;
        let mut scratch = [0; 8192];
        loop {
            let input = self.pending.get(consumed..).ok_or_else(invalid_body)?;
            match &mut self.check {
                BodyCheck::Idle => {
                    self.pending.clear();
                    return Ok(());
                }
                BodyCheck::Headers(call) => {
                    let (used, response) = call.try_response(input, false)?;
                    consumed = consumed.saturating_add(used);
                    let Some(response) = response else {
                        if used > 0 {
                            continue;
                        }
                        if input.len() > self.header_limit {
                            return Err(ureq::Error::LargeResponseHeader(
                                input.len(),
                                self.header_limit,
                            ));
                        }
                        break;
                    };
                    if !response.status().is_redirection() {
                        self.check = BodyCheck::Idle;
                        continue;
                    }
                    let BodyCheck::Headers(call) =
                        std::mem::replace(&mut self.check, BodyCheck::Idle)
                    else {
                        return Err(invalid_body());
                    };
                    if let Some(RecvResponseResult::RecvBody(call)) = call.proceed() {
                        if matches!(call.body_mode(), ureq_proto::BodyMode::LengthDelimited(length)
                            if length > crate::runtime::MAX_STRING_BYTES)
                        {
                            return Err(ureq::Error::BodyExceedsLimit(
                                crate::runtime::MAX_STRING_BYTES,
                            ));
                        }
                        self.check = BodyCheck::Body(call);
                    }
                }
                BodyCheck::Body(call) => {
                    let (used, decoded) = call.read(input, &mut scratch)?;
                    consumed = consumed.saturating_add(used);
                    self.size = self
                        .size
                        .saturating_add(u64::try_from(decoded).unwrap_or(u64::MAX));
                    // 読み捨てる本体は言語の値を作らない。上限超過は応答を得られない
                    // 失敗として Other にする（設計書 03-09「クライアント」）。
                    if self.size > crate::runtime::MAX_STRING_BYTES {
                        return Err(ureq::Error::BodyExceedsLimit(
                            crate::runtime::MAX_STRING_BYTES,
                        ));
                    }
                    if call.can_proceed() {
                        self.check = BodyCheck::Idle;
                    } else if used == 0 {
                        break;
                    }
                }
            }
        }
        self.pending.drain(..consumed);
        // チャンクの長さ・トレーラがいつまでも終わらない場合も、保持を制限する。
        if u64::try_from(self.pending.len()).unwrap_or(u64::MAX) > crate::runtime::MAX_STRING_BYTES
        {
            return Err(ureq::Error::BodyExceedsLimit(
                crate::runtime::MAX_STRING_BYTES,
            ));
        }
        Ok(())
    }
}

fn response_parser(method: Method) -> Result<Call<RecvResponse>, ureq::Error> {
    let request = Request::builder()
        .method(method)
        .uri("http://localhost/")
        .body(())?;
    let mut call = Call::new(request)?.proceed();
    let mut scratch = [0; 256];
    call.write(&mut scratch)?;
    match call.proceed()? {
        Some(SendRequestResult::RecvResponse(call)) => Ok(call),
        _ => Err(invalid_body()),
    }
}

fn invalid_body() -> ureq::Error {
    ureq::Error::Io(io::Error::new(
        io::ErrorKind::InvalidData,
        text::INCOMPLETE_BODY,
    ))
}

mod text {
    pub const INCOMPLETE_BODY: &str = "HTTP redirect response body did not finish correctly";
}

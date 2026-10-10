//! HTTP のサーバの操作と要求の値（設計書 03-09「サーバ」、実装プラン 10-15・10-16）。
use crate::builtins::iface::{
    BuiltinDecl, CloseStep, Interest, IoCtx, IoReply, IoServices, IoWait, Lend, StateCtx,
    StateReply, WorkerWait, builtin,
};
use crate::builtins::table::tags;
use crate::runtime::heap::{FieldsKind, ResourceId, Value, ValueCtx};
use crate::runtime::io::http::{self, AcceptStep, Failure, RequestData};
use crate::runtime::io::resources::ResourceState;
use crate::runtime::sched::parts::NetworkFault;
use crate::runtime::{ResourceKind, RuntimeError, Stop, Stream};

builtin! {
    /// `Benitoite.Network.Http.listen` の本体（実装プラン 10-15）。
    name = "Benitoite.Network.Http.listen",
    io fn listen(ctx, host: &'c str, port: i64) -> IoReply<'e> {
        let mut ctx = ctx;
        let port = u16::try_from(port).map_err(|_| domain("Benitoite.Network.Http.listen"))?;
        let fault = ctx.services().runtime_view().ok_or_else(|| internal("HTTP runtime unavailable"))?.rt.parts.network_faults.lookup(host);
        if let Some(fault) = fault {
            let kind = match fault {
                NetworkFault::HostNotFound => tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND,
                NetworkFault::ConnectionRefused => tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
                NetworkFault::ConnectionReset => tags::NETWORK_ERROR_KIND_CONNECTION_RESET,
                NetworkFault::TimedOut => tags::NETWORK_ERROR_KIND_TIMED_OUT,
            };
            return Ok(IoReply::Done(error(&ctx, Failure { kind, reason: text::INJECTED.into() }, "Benitoite.Network.Http.listen")?));
        }
        let host = host.to_owned();
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(Lend::Nothing,
            move |_| http::listen(&host, port), listen_done))))
    }
}
fn listen_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<http::Listener, Failure>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    match output {
        Ok(listener) => {
            let site = ctx.site();
            let id = ctx.services().register_resource(
                ResourceKind::HttpListener,
                Box::new(listener),
                site,
            );
            ok(ctx, Value::Resource(id))
        }
        Err(failure) => error(ctx, failure, "Benitoite.Network.Http.listen"),
    }
}
builtin! {
    /// `Benitoite.Network.Http.listenerPort` の本体（実装プラン 10-15）。
    name = "Benitoite.Network.Http.listenerPort",
    io fn listener_port(ctx, listener: ResourceId) -> IoReply<'e> {
        let mut ctx = ctx;
        let view = ctx.services().runtime_view().ok_or_else(|| internal("HTTP runtime unavailable"))?;
        Ok(IoReply::Done(Value::Int(i64::from(http::listener_port(view.resources, listener)?))))
    }
}
builtin! {
    /// `Benitoite.Network.Http.accept` の本体（実装プラン 10-15）。
    name = "Benitoite.Network.Http.accept",
    io fn accept(ctx, listener: ResourceId) -> IoReply<'e> {
        let mut ctx = ctx;
        let site = ctx.site();
        let step = {
            let mut view = ctx.services().runtime_view().ok_or_else(|| internal("HTTP runtime unavailable"))?;
            let now = view.rt.parts.clock.monotonic_millis();
            let (step, warning) = http::accept(view.resources, listener, now)?;
            if let Some(warning) = warning { drop(view.write_output(Stream::Stderr, &warning)?); }
            match step {
                AcceptStep::Accepted(exchange, request) => {
                    let id = view.register_resource(ResourceKind::HttpExchange, exchange, site);
                    view.resources.attachments.insert(id, Box::new(request));
                    Ok(id)
                }
                AcceptStep::Waiting => return Ok(IoReply::Wait(IoWait::Readiness { resource: listener, interest: Interest::Readable })),
                AcceptStep::Failed(failure) => Err(failure),
            }
        };
        Ok(IoReply::Done(match step {
            Ok(id) => ok(&ctx, Value::Resource(id))?,
            Err(failure) => error(&ctx, failure, "Benitoite.Network.Http.accept")?,
        }))
    }
}
builtin! {
    /// `Benitoite.Network.Http.respond` の本体（実装プラン 10-15）。
    name = "Benitoite.Network.Http.respond",
    io fn respond(ctx, exchange: ResourceId, response: Value<'e>) -> IoReply<'e> {
        let mut ctx = ctx;
        let status = ctx.field(response, 0).and_then(Value::as_int).ok_or_else(|| internal("HTTP response status missing"))?;
        if !(100..=599).contains(&status) { return Err(domain("Benitoite.Network.Http.respond")); }
        let headers = read_pairs(&ctx, ctx.field(response, 1).ok_or_else(|| internal("HTTP response headers missing"))?)?;
        // 応答の分割を防ぐため、置き換えるヘッダも書き込み前に検査する（設計書 03-09「サーバの接続と要求の読み方」）。
        if headers.iter().any(|(name, value)| {
            name.is_empty() || !name.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'!' | b'#' | b'$' | b'%' | b'&' | b'\'' | b'*' | b'+' | b'-' | b'.' | b'^' | b'_' | b'`' | b'|' | b'~'))
                || !value.bytes().all(|b| matches!(b, b'\t' | b' '..=b'~' | 0x80..=0xff))
        }) { return Err(domain(respond::DECL.name)); }
        let body = ctx.field(response, 2).and_then(|body| ctx.bytes(body)).ok_or_else(|| internal("HTTP response body missing"))?;
        let bytes = http::response_bytes(u16::try_from(status).map_err(|_| internal("validated HTTP status overflow"))?, &headers, body)?;
        let view = ctx.services().runtime_view().ok_or_else(|| internal("HTTP runtime unavailable"))?;
        let step = http::respond(view.resources, exchange, view.rt.output_task, bytes)?;
        match step {
            None => Ok(IoReply::Wait(IoWait::Readiness { resource: exchange, interest: Interest::Writable })),
            Some(Ok(())) => Ok(IoReply::Done(ok(&ctx, Value::Unit)?)),
            Some(Err(failure)) => Ok(IoReply::Done(error(&ctx, failure, "Benitoite.Network.Http.respond")?)),
        }
    }
}
builtin! {
    /// `Network.Http.requestOf` の本体（実装プラン 10-15）。
    name = "Network.Http.requestOf",
    state fn request_of(ctx, exchange: ResourceId) -> StateReply<'e> {
        let mut ctx = ctx;
        let request = {
            let resources = ctx.services().resource_table().ok_or_else(|| internal("HTTP resource table unavailable"))?;
            let kind = resources.kind(exchange).ok_or_else(|| internal("HTTP exchange missing"))?;
            if kind != ResourceKind::HttpExchange { return Err(internal("HTTP request resource kind mismatch")); }
            if resources.state(exchange) != Some(ResourceState::Open) { return Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind })); }
            resources.attachments.get(&exchange).and_then(|r| r.downcast_ref::<RequestData>()).ok_or_else(|| internal("HTTP request attachment missing"))?.clone()
        };
        let function = "Network.Http.requestOf";
        let method = ctx.alloc_str_utf8(request.method.as_bytes(), function)?.ok_or_else(|| internal("validated HTTP method is not UTF-8"))?;
        let path = ctx.alloc_str_utf8(request.path.as_bytes(), function)?.ok_or_else(|| internal("validated HTTP path is not UTF-8"))?;
        let query = pairs(&ctx, &request.query, function)?;
        let headers = pairs(&ctx, &request.headers, function)?;
        let body = ctx.alloc_bytes(&request.body, function)?;
        Ok(StateReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[method, path, query, headers, body])?))
    }
}
builtin! {
    /// `Network.Http.closeListener` の本体（実装プラン 10-15）。
    name = "Network.Http.closeListener",
    state fn close_listener(ctx, listener: ResourceId) -> StateReply<'e> {
        close(ctx, listener, "Network.Http.closeListener")
    }
}
builtin! {
    /// `Network.Http.closeExchange` の本体（実装プラン 10-15）。
    name = "Network.Http.closeExchange",
    state fn close_exchange(ctx, exchange: ResourceId) -> StateReply<'e> {
        close(ctx, exchange, "Network.Http.closeExchange")
    }
}
fn close<'c, 'e>(
    mut ctx: StateCtx<'c, 'e>,
    resource: ResourceId,
    function: &'static str,
) -> Result<StateReply<'e>, Stop> {
    match ctx.services().begin_close(resource)? {
        CloseStep::Wait(wait) => Ok(StateReply::Wait(wait)),
        CloseStep::Done(reason) => Ok(StateReply::Done(match reason {
            None => ok(&ctx, Value::Unit)?,
            Some(reason) => error(
                &ctx,
                Failure {
                    kind: tags::NETWORK_ERROR_KIND_OTHER,
                    reason,
                },
                function,
            )?,
        })),
    }
}
fn read_pairs<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Vec<(String, String)>, Stop> {
    let mut output = Vec::new();
    let mut iter = crate::runtime::list::cursor(ctx, value)?;
    while let Some(pair) = iter.next(ctx)? {
        let a = ctx
            .field(pair, 0)
            .and_then(|v| ctx.str(v))
            .ok_or_else(|| internal("HTTP header name missing"))?;
        let b = ctx
            .field(pair, 1)
            .and_then(|v| ctx.str(v))
            .ok_or_else(|| internal("HTTP header value missing"))?;
        output.push((a.to_owned(), b.to_owned()));
    }
    Ok(output)
}
fn pairs<'e>(
    ctx: &ValueCtx<'e>,
    items: &[(String, String)],
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    crate::runtime::heap::CheckedLen::elements(super::count(items.len())?, function)?;
    let mut values = Vec::with_capacity(items.len());
    for (a, b) in items {
        let a = ctx
            .alloc_str_utf8(a.as_bytes(), function)?
            .ok_or_else(|| internal("validated HTTP pair name is not UTF-8"))?;
        let b = ctx
            .alloc_str_utf8(b.as_bytes(), function)?
            .ok_or_else(|| internal("validated HTTP pair value is not UTF-8"))?;
        values.push(ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[a, b])?);
    }
    crate::runtime::list::from_values(ctx, &values, function)
}
fn ok<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Value<'e>, Stop> {
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}
fn error<'e>(
    ctx: &ValueCtx<'e>,
    failure: Failure,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let reason = ctx.alloc_str(&failure.reason, function)?;
    let error = ctx.alloc_fields(FieldsKind::NetworkError, failure.kind, &[reason])?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
}
fn internal(message: &str) -> Stop {
    Stop::Internal(message.into())
}
fn domain(function: &'static str) -> Stop {
    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
        function,
        argument: 1,
    })
}
mod text {
    pub const INJECTED: &str = "injected network failure";
}
/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    listen::DECL,
    listener_port::DECL,
    accept::DECL,
    respond::DECL,
    request_of::DECL,
    close_listener::DECL,
    close_exchange::DECL,
];

#[cfg(test)]
mod tests;

//! HTTP の応答と準備の待ち、資源不足の再試行（設計書 03-09「サーバ」「失敗の種類」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::*;

// 本物の拒否の経路で閉じる途中の接続を作る。期限は accept の時計で進め、実時間は待たない。
fn lingering_connection() -> (
    ResourceTable,
    ResourceId,
    Wakeup,
    event::EventLoop,
    std::net::TcpStream,
) {
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpListener,
        ResourceContent::Os(Some(Box::new(listen("127.0.0.1", 0).unwrap()))),
        None,
    );
    let wakeup = event::wakeup_with_poll().unwrap();
    let mut events = event::EventLoop::take(&wakeup).unwrap();
    let mut client =
        std::net::TcpStream::connect(("127.0.0.1", listener_port(&mut table, id).unwrap()))
            .unwrap();
    client
        .set_write_timeout(Some(Duration::from_secs(8)))
        .unwrap();
    client
        .write_all(b"POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 16777217\r\n\r\n")
        .unwrap();
    let deadline = Instant::now() + Duration::from_secs(8);
    loop {
        assert!(matches!(
            accept(&mut table, id, 0).unwrap(),
            (AcceptStep::Waiting, None)
        ));
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        if listener.connections.len() == 1 && listener.connections[0].lingering.is_some() {
            break;
        }
        let remaining = deadline.saturating_duration_since(Instant::now());
        assert!(
            !remaining.is_zero(),
            "rejection did not enter lingering close"
        );
        arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
        events.wait(Some(remaining));
        event::take_ready(&wakeup);
    }
    (table, id, wakeup, events, client)
}

// 関門: 応答を送り終えた接続の期限と、受け付けの再試行の期限を独立に保つ契約を守る。
// 統合テストでは時計を直接進められず、登録の再試行中に期限を忘れる退行を捕まえない。
#[test]
fn rejected_connection_deadline_survives_registration_retry() {
    let (mut table, id, wakeup, _events, _client) = lingering_connection();
    for (retry_at, retry_registration, expected) in [
        (None, false, 2_000),
        (Some(1_000), false, 1_000),
        (Some(3_000), true, 2_000),
    ] {
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        listener.retry_at = retry_at;
        listener.connections[0].retry_registration = retry_registration;
        assert_eq!(
            arm(&mut table, id, &wakeup, Interest::Readable)
                .unwrap()
                .deadline,
            Some(expected)
        );
    }
    assert!(matches!(
        accept(&mut table, id, 1_999).unwrap(),
        (AcceptStep::Waiting, None)
    ));
    assert_eq!(
        resource::<Listener>(&mut table, id, ResourceKind::HttpListener)
            .unwrap()
            .connections
            .len(),
        1
    );
    assert!(matches!(
        accept(&mut table, id, 2_000).unwrap(),
        (AcceptStep::Waiting, None)
    ));
    let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
    assert!(listener.connections.is_empty());
    assert_eq!(listener.retry_at, Some(3_000));
}

// 関門: 時計を進めず、読み捨てた量だけで閉じる契約を境目の両側で守る。
// 小さい残りしか送らない統合テストでは量の上限の欠落を捕まえられない。
#[test]
fn rejected_connection_closes_only_after_discard_limit() {
    let (mut table, id, wakeup, mut events, mut client) = lingering_connection();
    let (send_extra, receive_extra) = std::sync::mpsc::channel();
    let writer = std::thread::spawn(move || {
        client.write_all(&vec![b'x'; 1_048_576]).unwrap();
        receive_extra.recv_timeout(Duration::from_secs(8)).unwrap();
        // 上限を超えて閉じた後の書き込みの失敗は許す。EOF で閉じたことにはしない。
        drop(client.write_all(b"x"));
        client
    });
    let deadline = Instant::now() + Duration::from_secs(8);
    for exceeded in [false, true] {
        loop {
            assert!(matches!(
                accept(&mut table, id, 0).unwrap(),
                (AcceptStep::Waiting, None)
            ));
            let listener =
                resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
            if exceeded && listener.connections.is_empty() {
                break;
            }
            assert_eq!(listener.connections.len(), 1);
            let connection = &listener.connections[0];
            assert!(connection.reader.input.is_empty());
            if !exceeded && connection.lingering.as_ref().unwrap().discarded == 1_048_576 {
                break;
            }
            let remaining = deadline.saturating_duration_since(Instant::now());
            assert!(!remaining.is_zero(), "lingering discard limit timeout");
            arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
            events.wait(Some(remaining));
            event::take_ready(&wakeup);
        }
        if !exceeded {
            send_extra.send(()).unwrap();
        }
    }
    drop(writer.join().unwrap());
}

// 関門: 相手の FIN で接続を除き、期限まで保持しない契約を守る。
// 時間と量の上限のテストでは EOF による解放を確かめられない。
#[test]
fn rejected_connection_closes_when_peer_shuts_down_write() {
    let (mut table, id, wakeup, mut events, client) = lingering_connection();
    client.shutdown(std::net::Shutdown::Write).unwrap();
    let deadline = Instant::now() + Duration::from_secs(8);
    loop {
        assert!(matches!(
            accept(&mut table, id, 0).unwrap(),
            (AcceptStep::Waiting, None)
        ));
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        if listener.connections.is_empty() {
            break;
        }
        let remaining = deadline.saturating_duration_since(Instant::now());
        assert!(!remaining.is_zero(), "peer FIN did not close connection");
        arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
        events.wait(Some(remaining));
        event::take_ready(&wakeup);
    }
}

// 関門: 100 の送信が WouldBlock で止まった後、未読の本体で空回りせず、書き込みの準備で
// 再開して 100 を一度だけ送り切る契約を実ソケットで守る。既存の小さい応答では待ちを通らない。
// 本番の差し込み口は加えず、送りのバッファが埋まるまで書く（設計書 03-09「サーバの接続と要求の読み方」、RFC 9110 §10.1.1）。
#[test]
fn continue_waits_for_writable_before_reading_body_and_sends_once() {
    use std::time::Instant;

    let started = Instant::now();
    let deadline = started + Duration::from_secs(8);
    let remaining = || {
        let duration = deadline.saturating_duration_since(Instant::now());
        assert!(!duration.is_zero(), "100-continue readiness timeout");
        duration
    };
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpListener,
        ResourceContent::Os(Some(Box::new(listen("127.0.0.1", 0).unwrap()))),
        None,
    );
    let wakeup = event::wakeup_with_poll().unwrap();
    let mut events = event::EventLoop::take(&wakeup).unwrap();
    let mut client =
        std::net::TcpStream::connect(("127.0.0.1", listener_port(&mut table, id).unwrap()))
            .unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(8)))
        .unwrap();
    client
        .set_write_timeout(Some(Duration::from_secs(8)))
        .unwrap();
    loop {
        assert!(matches!(
            accept(&mut table, id, 0).unwrap(),
            (AcceptStep::Waiting, None)
        ));
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        if !listener.connections.is_empty() {
            assert_eq!(listener.connections.len(), 1);
            break;
        }
        arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
        events.wait(Some(remaining()));
        event::take_ready(&wakeup);
    }

    let mut filler_bytes = 0;
    let fill = |table: &mut ResourceTable, filler_bytes: &mut usize| {
        let filler = [b'x'; 64 * 1024];
        let mut last_write = Instant::now();
        // 一度の WouldBlock では、後から届く ACK による空きを除けない。空きが戻れば
        // 埋め直し、短い 100 も書けないことを 1 バイトの書き込みで確かめる。
        loop {
            let listener = resource::<Listener>(table, id, ResourceKind::HttpListener).unwrap();
            let socket = listener.connections[0].socket.as_mut().unwrap();
            let before = *filler_bytes;
            let mut bytes = filler.as_slice();
            loop {
                remaining();
                match socket.write(bytes) {
                    Ok(0) => panic!("filling the send buffer wrote zero bytes"),
                    Ok(n) => *filler_bytes += n,
                    Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                    Err(error) if error.kind() == io::ErrorKind::WouldBlock && bytes.len() > 1 => {
                        bytes = &filler[..1];
                    }
                    Err(error) if error.kind() == io::ErrorKind::WouldBlock => break,
                    Err(error) => panic!("filling the send buffer failed: {error}"),
                }
            }
            if *filler_bytes != before {
                last_write = Instant::now();
            } else if last_write.elapsed() >= Duration::from_millis(300) {
                break;
            }
            std::thread::sleep(Duration::from_millis(20));
        }
    };
    fill(&mut table, &mut filler_bytes);
    assert!(filler_bytes > 0);
    client.write_all(b"POST / HTTP/1.1\r\nHost: 127.0.0.1\r\nExpect: 100-continue\r\nContent-Length: 3\r\n\r\n").unwrap();
    loop {
        arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
        events.wait(Some(remaining()));
        event::take_ready(&wakeup);
        fill(&mut table, &mut filler_bytes);
        assert!(
            matches!(
                accept(&mut table, id, 0).unwrap(),
                (AcceptStep::Waiting, None)
            ),
            "100 was fully written; send buffer space returned after refilling"
        );
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        if let Some(interim) = &listener.connections[0].interim {
            assert!(
                !interim.remaining().is_empty(),
                "100 was written in one pass; the waiting path was not exercised"
            );
            break;
        }
        assert!(
            listener.connections[0].reader.request.is_none(),
            "100 was written in one pass; the waiting path was not exercised"
        );
    }

    client.write_all(b"abc").unwrap();
    {
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        let socket = listener.connections[0].socket.as_mut().unwrap();
        let mut body = [0; 3];
        loop {
            remaining();
            match socket.peek(&mut body) {
                Ok(3) => break,
                Ok(_) => (),
                Err(error)
                    if error.kind() == io::ErrorKind::WouldBlock
                        || error.kind() == io::ErrorKind::Interrupted => {}
                Err(error) => panic!("peeking at the request body failed: {error}"),
            }
            std::thread::sleep(Duration::from_millis(1));
        }
        assert_eq!(&body, b"abc");
    }
    // 本体の到着待ちの間にも ACK で空きが戻りうる。accept の前に再び埋める。
    fill(&mut table, &mut filler_bytes);
    assert!(
        matches!(
            accept(&mut table, id, 0).unwrap(),
            (AcceptStep::Waiting, None)
        ),
        "100 was fully written; send buffer space returned after refilling"
    );
    {
        let listener = resource::<Listener>(&mut table, id, ResourceKind::HttpListener).unwrap();
        let connection = &listener.connections[0];
        assert!(
            connection.reader.input.is_empty(),
            "body was read before 100 was sent"
        );
        assert!(connection.interim.is_some());
    }
    arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
    let token = resource::<Listener>(&mut table, id, ResourceKind::HttpListener)
        .unwrap()
        .connections[0]
        .registration
        .as_ref()
        .unwrap()
        .token;
    // 本体は既に届いている。READABLE を誤って登録したら、この待ちで接続の準備が来る。
    events.wait(Some(Duration::from_millis(200)));
    assert!(
        !event::take_ready(&wakeup).contains(&token),
        "pending 100 woke on unread body bytes"
    );

    let received = std::thread::spawn(move || {
        let mut bytes = Vec::new();
        client.read_to_end(&mut bytes).unwrap();
        bytes
    });
    let mut writable_seen = false;
    let exchange = loop {
        arm(&mut table, id, &wakeup, Interest::Readable).unwrap();
        events.wait(Some(remaining()));
        writable_seen |= event::take_ready(&wakeup).contains(&token);
        match accept(&mut table, id, 0).unwrap() {
            (AcceptStep::Accepted(exchange, request), None) => {
                assert_eq!(request.body, b"abc");
                break exchange;
            }
            (AcceptStep::Waiting, None) => (),
            _ => panic!("unexpected accept result while sending 100"),
        }
    };
    assert!(
        writable_seen,
        "connection did not resume on writable readiness"
    );
    drop(exchange);
    let bytes = received.join().unwrap();
    let interim = b"HTTP/1.1 100 Continue\r\n\r\n";
    assert_eq!(bytes.len(), filler_bytes + interim.len());
    assert!(bytes[..filler_bytes].iter().all(|byte| *byte == b'x'));
    assert_eq!(&bytes[filler_bytes..], interim);
    assert_eq!(
        bytes
            .windows(interim.len())
            .filter(|window| *window == interim)
            .count(),
        1
    );
    eprintln!(
        "100-continue waited and resumed: {filler_bytes} filler bytes, {:?}",
        started.elapsed()
    );
}

#[test]
fn request_continue_requires_http11_body_and_no_received_body_bytes() {
    #[derive(Debug)]
    enum ExpectedStep {
        NeedMore,
        Complete,
        Reject(u16),
    }
    use ExpectedStep::{Complete, NeedMore, Reject};

    for (version, expect, framing, body, pending, expected) in [
        (
            "1.1",
            "100-continue",
            "Content-Length: 3\r\n",
            "",
            true,
            NeedMore,
        ),
        (
            "1.1",
            "100-CoNtInUe",
            "Transfer-Encoding: chunked\r\n",
            "",
            true,
            NeedMore,
        ),
        (
            "1.0",
            "100-continue",
            "Content-Length: 3\r\n",
            "",
            false,
            NeedMore,
        ),
        (
            "1.0",
            "100-continue",
            "Transfer-Encoding: chunked\r\n",
            "",
            false,
            NeedMore,
        ),
        ("1.1", "other", "Content-Length: 3\r\n", "", false, NeedMore),
        ("1.1", "100-continue", "", "", false, Complete),
        (
            "1.1",
            "100-continue",
            "Content-Length: 0\r\n",
            "",
            false,
            Complete,
        ),
        (
            "1.1",
            "100-continue",
            "Content-Length: 3\r\n",
            "a",
            false,
            NeedMore,
        ),
        (
            "1.1",
            "100-continue",
            "Content-Length: 3\r\n",
            "abc",
            false,
            Complete,
        ),
        (
            "1.1",
            "100-continue",
            "Transfer-Encoding: chunked\r\n",
            "1",
            false,
            NeedMore,
        ),
        (
            "1.1",
            "100-continue",
            "Content-Length: 16777217\r\n",
            "",
            false,
            Reject(413),
        ),
        (
            "1.1",
            "100-continue",
            "Content-Length: 18446744073709551616\r\n",
            "",
            false,
            Reject(413),
        ),
    ] {
        let mut reader = RequestReader {
            input: format!("POST / HTTP/{version}\r\nHost: localhost\r\nExPeCt: {expect}\r\n{framing}\r\n{body}").into_bytes(),
            ..Default::default()
        };
        let step = reader.advance();
        assert!(
            match (&expected, step) {
                (NeedMore, ParseStep::NeedMore) | (Complete, ParseStep::Complete(_)) => true,
                (Reject(code), ParseStep::Reject(actual)) => actual == *code,
                _ => false,
            },
            "{version}, {expect}, {framing:?}, {body:?}: expected {expected:?}"
        );
        assert_eq!(
            reader.take_continue(),
            pending,
            "{version}, {expect}, {framing:?}, {body:?}"
        );
        assert!(!reader.take_continue());
        if pending {
            assert!(matches!(reader.advance(), ParseStep::NeedMore));
            assert!(!reader.take_continue());
            reader
                .input
                .extend_from_slice(if framing.starts_with("Content-Length") {
                    b"abc"
                } else {
                    b"3\r\nabc\r\n0\r\n\r\n"
                });
            let ParseStep::Complete(request) = reader.advance() else {
                panic!("body incomplete")
            };
            assert_eq!(request.body, b"abc");
            assert!(!reader.take_continue());
        }
    }
}

#[cfg(target_os = "linux")]
#[test]
fn per_connection_accept_errnos_continue_until_listener_failure() {
    use rustix::io::Errno;
    let mut injected = [
        Errno::NETDOWN,
        Errno::PROTO,
        Errno::NOPROTOOPT,
        Errno::HOSTDOWN,
        Errno::NONET,
        Errno::HOSTUNREACH,
        Errno::OPNOTSUPP,
        Errno::NETUNREACH,
    ]
    .into_iter()
    .map(|errno| io::Error::from_raw_os_error(errno.raw_os_error()))
    .collect::<std::collections::VecDeque<_>>();
    injected.push_back(io::Error::from(io::ErrorKind::PermissionDenied));
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpListener,
        ResourceContent::Os(Some(Box::new(Listener {
            socket: None,
            injected,
            registration: None,
            connections: Vec::new(),
            retry_at: None,
            retry_millis: ACCEPT_RETRY_INITIAL_MILLIS,
            registration_failure: None,
        }))),
        None,
    );
    let Ok((AcceptStep::Failed(failure), warning)) = accept(&mut table, id, 0) else {
        panic!("listener failure missing")
    };
    assert_eq!(failure.kind, tags::NETWORK_ERROR_KIND_PERMISSION_DENIED);
    assert!(warning.is_none());
}

// 関門: 要求の解析の規則は TCP なしで入力と結果を突き合わせる。
// 実通信のテストは、拒否した後の accept の継続と handler への到達を受け持つ。
#[test]
fn request_host_count_and_value_follow_http_version() {
    for (version, headers, accepted) in [
        ("1.1", "", false),
        ("1.1", "Host: localhost\r\n", true),
        ("1.1", "hOsT: localhost\r\n", true),
        ("1.1", "Host:\r\n", true),
        ("1.1", "Host: a\r\nhOsT: b\r\n", false),
        ("1.0", "", true),
        ("1.0", "Host: localhost\r\n", true),
        ("1.0", "Host:\r\n", true),
        ("1.0", "Host: a\r\nHost: b\r\n", false),
        ("1.1", "Host: AZaz09-._~!$&'()*+,;=:[::1]%\r\n", true),
        ("1.1", "Host: a b\r\n", false),
        ("1.1", "Host: a\tb\r\n", false),
        ("1.1", "Host: a/b\r\n", false),
        ("1.1", "Host: a@b\r\n", false),
        ("1.1", "Host: a?b\r\n", false),
        ("1.1", "Host: a#b\r\n", false),
        ("1.1", "Host: café\r\n", false),
        ("1.0", "Host: a/b\r\n", false),
    ] {
        let mut reader = RequestReader {
            input: format!("GET / HTTP/{version}\r\n{headers}\r\n").into_bytes(),
            ..Default::default()
        };
        let step = reader.advance();
        assert!(
            if accepted {
                matches!(step, ParseStep::Complete(_))
            } else {
                matches!(step, ParseStep::Reject(400))
            },
            "HTTP/{version}, {headers:?}"
        );
    }
    // Host の誤りを本体の上限より先に報告する。
    let mut reader = RequestReader {
        input: b"POST http://h/ HTTP/1.1\r\nContent-Length: 16777217\r\n\r\n".to_vec(),
        ..Default::default()
    };
    assert!(matches!(reader.advance(), ParseStep::Reject(400)));
}

#[test]
fn request_trailers_use_header_syntax_and_limits() {
    let head =
        b"POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n1\r\na\r\n0\r\n";
    for (trailers, code) in [
        (b"\r\n".to_vec(), None),
        (b"X-T: yes\r\nOther: \tvalue\t\r\n\r\n".to_vec(), None),
        (b"X-T: a\0b\r\n\r\n".to_vec(), Some(400)),
        (b"X-T: a\x01b\r\n\r\n".to_vec(), Some(400)),
        (b"X-T: a\x7fb\r\n\r\n".to_vec(), Some(400)),
        (b"X-T : yes\r\n\r\n".to_vec(), Some(400)),
        (b" X-T: yes\r\n\r\n".to_vec(), Some(400)),
        (b"X-T: yes\r\n folded\r\n\r\n".to_vec(), Some(400)),
        (
            format!("{}\r\n", "X: a\r\n".repeat(MAX_HEADERS)).into_bytes(),
            None,
        ),
        (
            format!("{}\r\n", "X: a\r\n".repeat(MAX_HEADERS + 1)).into_bytes(),
            Some(431),
        ),
        (
            format!("X: {}\r\n\r\n", "a".repeat(MAX_HEAD_BYTES)).into_bytes(),
            Some(431),
        ),
        (
            format!("X: {}", "a".repeat(MAX_HEAD_BYTES)).into_bytes(),
            Some(431),
        ),
    ] {
        let mut reader = RequestReader {
            input: [head.as_slice(), &trailers].concat(),
            ..Default::default()
        };
        match (reader.advance(), code) {
            (ParseStep::Complete(request), None) => {
                assert_eq!(request.body, b"a");
                assert_eq!(request.headers.len(), 2);
            }
            (ParseStep::Reject(actual), Some(expected)) => assert_eq!(actual, expected),
            _ => panic!("unexpected trailer result: {trailers:?}, {code:?}"),
        }
    }
    let mut reader = RequestReader {
        input: head.to_vec(),
        ..Default::default()
    };
    reader.input.extend_from_slice(b"X-T: value\r\n");
    assert!(matches!(reader.advance(), ParseStep::NeedMore));
    reader.input.extend_from_slice(b"\r\n");
    assert!(matches!(reader.advance(), ParseStep::Complete(_)));
}

// 関門: 解析した要求の path・query と 400 を守る。対象の文法と絶対形の変換は、
// 既存の表に足し、補助の判定だけを直接呼ぶテストを重ねない（設計書 03-09「サーバの接続と要求の読み方」）。
#[test]
fn request_absolute_target_becomes_origin_path_and_query() {
    for (method, target, path, query) in [
        ("GET", "http://h/path", "/path", vec![]),
        ("GET", "http://[::1]:8080/p?x=1", "/p", vec![("x", "1")]),
        ("GET", "http://h", "/", vec![]),
        ("GET", "http://h?x=1", "/", vec![("x", "1")]),
        (
            "GET",
            "HTTP://Example.COM/path?x=1",
            "/path",
            vec![("x", "1")],
        ),
        ("GET", "hTtPs://h/path?x=a+b", "/path", vec![("x", "a b")]),
        ("GET", "https://h", "/", vec![]),
        ("GET", "https://h?x=1", "/", vec![("x", "1")]),
        ("CONNECT", "h:443", "h:443", vec![]),
        ("CONNECT", "[::1]:443", "[::1]:443", vec![]),
        ("CONNECT", "h:0", "h:0", vec![]),
        ("CONNECT", "h:65535", "h:65535", vec![]),
        ("CONNECT", "h:0443", "h:0443", vec![]),
        ("OPTIONS", "*", "*", vec![]),
        ("OPTIONS", "http://h:8001", "*", vec![]),
        ("OPTIONS", "https://h", "*", vec![]),
        ("OPTIONS", "http://h/", "/", vec![]),
        ("OPTIONS", "http://h?x=1", "/", vec![("x", "1")]),
        ("OPTIONS", "http://h?", "/", vec![]),
        ("options", "http://h", "/", vec![]),
        ("GET", "/p%23f", "/p%23f", vec![]),
        ("GET", "//a", "//a", vec![]),
        ("GET", "/%G0", "/%G0", vec![]),
        ("GET", "/?q=%", "/", vec![("q", "%")]),
        // WHATWG URL Standard の符号化の集合では、これらの文字は少なくとも
        // クエリに生で残りうるため、パスでも受け付ける。
        ("GET", "/a|b", "/a|b", vec![]),
        ("GET", "/?a[]=1", "/", vec![("a[]", "1")]),
        ("GET", "/{x}", "/{x}", vec![]),
        ("GET", "/a\\b", "/a\\b", vec![]),
        ("GET", "/a^b", "/a^b", vec![]),
        ("GET", "/a`b", "/a`b", vec![]),
    ] {
        let mut reader = RequestReader {
            input: format!("{method} {target} HTTP/1.1\r\nHost: localhost\r\n\r\n").into_bytes(),
            ..Default::default()
        };
        let ParseStep::Complete(request) = reader.advance() else {
            panic!("{target}")
        };
        assert_eq!(request.path, path, "{target}");
        assert_eq!(
            request.query,
            query
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect::<Vec<_>>(),
            "{target}"
        );
    }
    let mut unexpected_targets = Vec::new();
    for (method, target) in [
        ("GET", "http://"),
        ("GET", "http:///p"),
        ("GET", "http://?x=1"),
        ("GET", "http://u@h/p"),
        ("GET", "http://h\\p"),
        ("GET", "http://h|x/p"),
        ("GET", "http://café/p"),
        ("GET", "https://u@h/p"),
        ("GET", "http://#f"),
        ("GET", "http://h/p#f"),
        ("GET", "http://h#f"),
        ("GET", "/p#f"),
        ("GET", "/p?x=1#f"),
        ("OPTIONS", "*#f"),
        ("CONNECT", "h:443#f"),
        ("GET", "*"),
        ("options", "*"),
        ("OPTIONS", "*x"),
        ("OPTIONS", "*?x"),
        ("GET", "foo"),
        ("GET", "?x"),
        ("GET", "%2Fa"),
        ("GET", "h:443"),
        ("connect", "h:443"),
        ("CONNECT", "/x"),
        ("CONNECT", "http://h/"),
        ("CONNECT", "*"),
        ("CONNECT", "h"),
        ("CONNECT", "h:"),
        ("CONNECT", "h:65536"),
        ("CONNECT", "h:x"),
        ("CONNECT", "h:+443"),
        ("CONNECT", ":443"),
        ("CONNECT", "h/p:443"),
        ("GET", "ftp://h/p"),
        ("GET", "urn:x"),
        ("GET", "http:/x"),
        ("GET", "/a\"b"),
        ("GET", "/<x>"),
        ("GET", "/?q=>"),
        ("GET", "http://h/a\"b"),
        ("GET", "/café"),
        ("GET", "/?q=日本"),
    ] {
        let mut reader = RequestReader {
            input: format!("{method} {target} HTTP/1.1\r\nHost: localhost\r\n\r\n").into_bytes(),
            ..Default::default()
        };
        if !matches!(reader.advance(), ParseStep::Reject(400)) {
            unexpected_targets.push((method, target));
        }
    }
    assert!(
        unexpected_targets.is_empty(),
        "targets not rejected with 400: {unexpected_targets:?}"
    );
}

// 関門: 応答のバイト列で接続の実際と食い違うヘッダの除去を守る。
// 判定の補助関数だけを確かめず、長さの検査と書き出しの入口を通す（設計書 03-09「サーバの接続と要求の読み方」）。
#[test]
fn response_replaces_framing_headers_and_uses_known_reason_phrases() {
    let bytes = response_bytes(
        200,
        &[
            ("Content-Length".into(), "999".into()),
            ("CONNECTION".into(), "keep-alive".into()),
            ("tRaNsFeR-EnCoDiNg".into(), "chunked".into()),
            ("TRAILER".into(), "X-T".into()),
            ("Keep-Alive".into(), "timeout=5".into()),
            ("Upgrade".into(), "example".into()),
            ("Proxy-Connection".into(), "keep-alive".into()),
            ("TE".into(), "trailers".into()),
            ("X".into(), "a".into()),
        ],
        b"abc",
        ResponseFraming::Other,
    )
    .unwrap();
    assert_eq!(
        bytes,
        b"HTTP/1.1 200 OK\r\nX: a\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc"
    );
    for (connections, remaining) in [
        (vec![("Connection", "x-foo")], "x-bar: b\r\n"),
        (vec![("Connection", " , X-Foo ,,\tx-bar ")], ""),
        (vec![("Connection", "x-foo"), ("cOnNeCtIoN", "X-BAR")], ""),
        (vec![("Connection", "a,,b")], "X-Foo: a\r\nx-bar: b\r\n"),
        // OWS 以外の空白を取り除いて名前を一致させない。
        (
            vec![("Connection", "\u{a0}x-foo\u{a0}")],
            "X-Foo: a\r\nx-bar: b\r\n",
        ),
    ] {
        let mut headers = vec![
            ("X-Foo".into(), "a".into()),
            ("x-bar".into(), "b".into()),
            ("".into(), "v".into()),
        ];
        headers.extend(
            connections
                .iter()
                .map(|(name, value)| (name.to_string(), value.to_string())),
        );
        assert_eq!(
            response_bytes(200, &headers, b"abc", ResponseFraming::Other).unwrap(),
            format!("HTTP/1.1 200 OK\r\n{remaining}: v\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc").as_bytes(),
            "{connections:?}"
        );
    }
    assert!(
        response_bytes(599, &[], &[], ResponseFraming::Other)
            .unwrap()
            .starts_with(b"HTTP/1.1 599 \r\n")
    );
    for (status, reason) in [
        (428, "Precondition Required"),
        (429, "Too Many Requests"),
        (431, "Request Header Fields Too Large"),
    ] {
        assert_eq!(
            response_bytes(status, &[], &[], ResponseFraming::Other).unwrap(),
            format!("HTTP/1.1 {status} {reason}\r\ncontent-length: 0\r\nconnection: close\r\n\r\n")
                .as_bytes()
        );
    }
    assert!(error_response(431).starts_with(b"HTTP/1.1 431 Request Header Fields Too Large\r\n"));
}

// 関門: 区切りの表の出力バイトを守る。従来はすべての状態と方法で本体を送っていた。
#[test]
fn response_body_and_content_length_follow_status_and_method() {
    for (method, status, body, expected) in [
        (
            "GET",
            204,
            "abc",
            "HTTP/1.1 204 No Content\r\nconnection: close\r\n\r\n",
        ),
        (
            "GET",
            205,
            "abc",
            "HTTP/1.1 205 Reset Content\r\ncontent-length: 0\r\nconnection: close\r\n\r\n",
        ),
        (
            "GET",
            304,
            "abc",
            "HTTP/1.1 304 Not Modified\r\nconnection: close\r\n\r\n",
        ),
        (
            "HEAD",
            200,
            "abc",
            "HTTP/1.1 200 OK\r\ncontent-length: 3\r\nconnection: close\r\n\r\n",
        ),
        (
            "HEAD",
            200,
            "",
            "HTTP/1.1 200 OK\r\nconnection: close\r\n\r\n",
        ),
        (
            "HEAD",
            204,
            "abc",
            "HTTP/1.1 204 No Content\r\nconnection: close\r\n\r\n",
        ),
        (
            "HEAD",
            205,
            "abc",
            "HTTP/1.1 205 Reset Content\r\ncontent-length: 0\r\nconnection: close\r\n\r\n",
        ),
        (
            "HEAD",
            304,
            "abc",
            "HTTP/1.1 304 Not Modified\r\nconnection: close\r\n\r\n",
        ),
        (
            "CONNECT",
            200,
            "abc",
            "HTTP/1.1 200 OK\r\nconnection: close\r\n\r\n",
        ),
        (
            "CONNECT",
            204,
            "abc",
            "HTTP/1.1 204 No Content\r\nconnection: close\r\n\r\n",
        ),
        (
            "CONNECT",
            205,
            "abc",
            "HTTP/1.1 205 Reset Content\r\nconnection: close\r\n\r\n",
        ),
        (
            "CONNECT",
            404,
            "abc",
            "HTTP/1.1 404 Not Found\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc",
        ),
        (
            "GET",
            200,
            "abc",
            "HTTP/1.1 200 OK\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc",
        ),
        (
            "GET",
            200,
            "",
            "HTTP/1.1 200 OK\r\ncontent-length: 0\r\nconnection: close\r\n\r\n",
        ),
        (
            "head",
            200,
            "abc",
            "HTTP/1.1 200 OK\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc",
        ),
        (
            "connect",
            200,
            "abc",
            "HTTP/1.1 200 OK\r\ncontent-length: 3\r\nconnection: close\r\n\r\nabc",
        ),
    ] {
        assert_eq!(
            response_bytes(
                status,
                &[],
                body.as_bytes(),
                ResponseFraming::from_method(method)
            )
            .unwrap(),
            expected.as_bytes(),
            "{method} {status}"
        );
    }
}

use crate::builtins::iface::{IoReply, builtin};
use crate::runtime::Stream;
use crate::runtime::heap::{FieldsKind, HeapConfig, Value};
use crate::runtime::io::ops::{Completion, WorkerJob};
use crate::runtime::io::output::OutputPort;
use crate::runtime::io::services::{IoRuntime, RunInput};
use crate::runtime::sched::parts::{IdleWake, WorkerExec};
use crate::runtime::sched::testing::ScheduleHandle;
use crate::vm::{ExecMode, MainOutcome, Vm, VmConfig, VmStep};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, Mutex};

builtin! {
    name = "Benitoite.Network.Http.listen",
    io fn injected_listen(ctx, host: &'c str, port: i64) -> IoReply<'e> {
        let mut ctx = ctx;
        let _ = (host, port);
        // OS の上限を実際に使い切らず、非公開の注入で資源不足を確かめる。
        let no_buffers = if cfg!(target_os = "macos") { 55 } else { 105 };
        let errors = [24, 23, no_buffers, 12].into_iter().cycle().take(11).map(io::Error::from_raw_os_error)
            .chain([io::Error::from(io::ErrorKind::PermissionDenied)]).collect();
        let listener = Listener { socket: None, injected: errors, registration: None, connections: Vec::new(), retry_at: None, retry_millis: ACCEPT_RETRY_INITIAL_MILLIS, registration_failure: None };
        let site = ctx.site();
        let id = ctx.services().register_resource(ResourceKind::HttpListener, Box::new(listener), site);
        Ok(IoReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[Value::Resource(id)])?))
    }
}
#[derive(Debug)]
struct TimedWorkers {
    inner: Box<dyn WorkerExec>,
    script: ScheduleHandle,
    waits: Rc<RefCell<Vec<u64>>>,
}
impl WorkerExec for TimedWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        self.script.allow_worker(job.op);
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        let now = self.script.parts().clock.monotonic_millis();
        if let Some(deadline) = deadline {
            self.waits.borrow_mut().push(deadline - now);
            self.script.allow_time(deadline - now);
        }
        self.inner.idle(deadline)
    }
}
#[derive(Debug)]
struct Capture(Arc<Mutex<Vec<u8>>>);
impl Write for Capture {
    fn write(&mut self, data: &[u8]) -> io::Result<usize> {
        self.0.lock().unwrap().extend(data);
        Ok(data.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
struct Evidence {
    end: VmStep,
    stdout: Vec<u8>,
    stderr: Vec<u8>,
    waits: Vec<u64>,
}
fn run_injected(program: &crate::bytecode::program::CompiledProgram, mode: ExecMode) -> Evidence {
    let script = ScheduleHandle::new([], false);
    let mut parts = script.parts();
    let waits = Rc::new(RefCell::new(Vec::new()));
    parts.workers = Box::new(TimedWorkers {
        inner: parts.workers,
        script: script.clone(),
        waits: Rc::clone(&waits),
    });
    let stdout = Arc::new(Mutex::new(Vec::new()));
    let stderr = Arc::new(Mutex::new(Vec::new()));
    let wake = script.wakeup();
    let outputs = (
        OutputPort::start(
            Stream::Stdout,
            Box::new(Capture(Arc::clone(&stdout))),
            false,
            wake.clone(),
        ),
        OutputPort::start(
            Stream::Stderr,
            Box::new(Capture(Arc::clone(&stderr))),
            false,
            wake.clone(),
        ),
    );
    let mut rt = IoRuntime::new(
        RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        mode,
        outputs,
        Box::new(io::Cursor::new(Vec::<u8>::new())),
        parts,
        Box::new(crate::runtime::run::NoInterrupt),
        wake,
    );
    rt.builtin_overrides.insert(
        crate::builtins::table::lookup_builtin("Benitoite.Network.Http.listen").unwrap(),
        &injected_listen::DECL,
    );
    let mut vm = Vm::new(
        program,
        VmConfig::default(),
        HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
    );
    vm.start_main().unwrap();
    let end = loop {
        match vm.run(&mut rt) {
            VmStep::Requests(ids) => {
                for id in ids {
                    vm.serve_request(&mut rt, id);
                }
            }
            end @ (VmStep::Finished(_) | VmStep::Stopped(_)) => break end,
        }
    };

    rt.stdout.finish().unwrap();
    rt.stderr.finish().unwrap();
    assert!(rt.readiness.resources.is_empty());
    assert!(rt.readiness.retries.is_empty());
    assert!(script.record().error.is_none(), "{:?}", script.record());
    let stdout = stdout.lock().unwrap().clone();
    let stderr = stderr.lock().unwrap().clone();
    let waits = waits.borrow().clone();
    Evidence {
        end,
        stdout,
        stderr,
        waits,
    }
}

// 関門: 再試行の期限が VM の idle に届き、満了で本物の accept を再実行する契約。
// retry の数値だけの検査では、満了後の要求の置き直しと他タスクの進行を検出できない。
#[test]
fn shortage_retries_use_vm_timers_and_one_warning_in_both_modes() {
    let checked = crate::pipeline::check_text("l30.bnt", br#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Http.Listen, Console.Write, Clock.Time, State
  with listener = try Result.mapError(Http.listen("fake", 0), NetworkError.message), group = TaskGroup.open() do
    bind child <- TaskGroup.spawn(group, lambda()
      bind _ <- Clock.sleep(1)
      bind _ <- Console.writeLine("child")
      return ()
    end lambda)
    bind result <- Http.accept(listener)
    bind _ <- Task.await(child)
    return match result with
      case Result.Error(error) -> if NetworkError.kind(error) = NetworkErrorKind.PermissionDenied then Result.Ok(()) else Result.Error("wrong kind") end if
      case Result.Ok(_) -> Result.Error("unexpected accepted request")
    end match
  end with
end function
"#, crate::pipeline::CheckOptions { require_main: true, deny_warnings: false });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = crate::pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let evidence = run_injected(&program, mode);
        assert_eq!(evidence.end, VmStep::Finished(MainOutcome::Ok));
        assert_eq!(evidence.stdout, b"child\n");
        assert_eq!(
            evidence
                .stderr
                .split(|b| *b == b'\n')
                .filter(|s| !s.is_empty())
                .count(),
            1
        );
        // 子の sleep が最初の 5 ms の待ちを 1 と 4 に分ける。
        assert_eq!(
            evidence.waits,
            [1, 4, 10, 20, 40, 80, 160, 320, 640, 1000, 1000, 1000]
        );
    }
}

// 関門: Poll のないテストの部品を準備の待ちで黙って使うと待ち続ける。
#[cfg(unix)]
#[test]
fn registration_without_poll_is_internal_error() {
    use std::os::fd::AsRawFd;
    let (reader, _writer) = std::os::unix::net::UnixStream::pair().unwrap();
    let mut source = mio::unix::SourceFd(&reader.as_raw_fd());
    assert!(matches!(
        Registration::arm(
            &mut None,
            &mut source,
            &event::wakeup_without_poll(),
            mio::Interest::READABLE
        ),
        Err(Stop::Internal(_))
    ));
}

// 関門: 二度目の応答と解放後の操作は HTTP の失敗の値でなく実行時エラー（03-09）。
#[test]
fn exchange_respond_twice_and_releasing_checks_precede_socket_access() {
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(Exchange {
            socket: None,
            release_socket: None,
            registration: None,
            response: None,
            response_owner: None,
            responded: true,
            registration_failure: None,
        }))),
        None,
    );
    let owner = TaskId {
        index: 0,
        generation: 0,
    };
    assert!(matches!(
        respond(&mut table, id, owner, vec![]),
        Err(Stop::Runtime(RuntimeError::ResponseSentTwice))
    ));
    table.request_release(id, ExtOpId(2));
    assert!(matches!(
        respond(&mut table, id, owner, vec![]),
        Err(Stop::Runtime(RuntimeError::ReleasedResourceUsed {
            kind: ResourceKind::HttpExchange
        }))
    ));
}

// 関門: CLI の部分応答の停止は、まだ始まっていない解放を通る。
// この境界では、解放が既に待ちの列か作業用スレッドに渡った場合を確かめる。
// 同じ実ソケットを使い、停止時の unwind_release の結果・EOF・遅い完了の受理を守る。
#[test]
fn stopping_an_exchange_with_a_pending_or_dispatched_release_closes_without_waiting() {
    use crate::runtime::heap::Heap;
    use crate::runtime::io::ops::{
        Accepted, LentOwned, OpKind, OpRecord, OpTable, Outcome, accept_completion,
        check_completion,
    };
    use crate::vm::state::RunState;
    use crate::vm::unwind::{ReleaseLog, UnwindCause, UnwindStep, unwind_release};
    use std::time::Duration;

    for dispatched in [false, true] {
        let listener = std::net::TcpListener::bind(("127.0.0.1", 0)).unwrap();
        let mut client = std::net::TcpStream::connect(listener.local_addr().unwrap()).unwrap();
        client
            .set_read_timeout(Some(Duration::from_secs(30)))
            .unwrap();
        let (socket, _) = listener.accept().unwrap();
        socket.set_nonblocking(true).unwrap();
        let mut rt = RunState::new(VmConfig::default(), 0);
        let id = rt.resources.insert(
            ResourceKind::HttpExchange,
            ResourceContent::Os(Some(Box::new(Exchange {
                socket: Some(mio::net::TcpStream::from_std(socket)),
                release_socket: None,
                registration: None,
                response: None,
                response_owner: None,
                responded: false,
                registration_failure: None,
            }))),
            None,
        );
        let op = rt.scheduler.new_ext_op_id();
        rt.resources.check_release(id).unwrap();
        assert!(matches!(
            rt.resources.request_release(id, op),
            super::super::resources::ReleaseStart::Blocking
        ));
        let job = dispatched.then(|| rt.resources.take_release_job().unwrap());
        let mut heap = Heap::new(HeapConfig::default());
        let mut log = ReleaseLog::default();
        let stopped = heap.epoch(|ctx| {
            unwind_release(
                ctx,
                &mut rt,
                TaskId {
                    index: 0,
                    generation: 0,
                },
                id,
                crate::vm::InstrRef {
                    proto: crate::bytecode::program::ProtoIdx(0),
                    pc: 0,
                },
                UnwindCause::Stop,
                &mut log,
            )
        });
        assert!(matches!(stopped, Ok(UnwindStep::Popped)), "{stopped:?}");
        assert_eq!(rt.resources.state(id), Some(ResourceState::Released));
        assert!(rt.resources.take_release_job().is_none());
        assert!(rt.resources.attachments.is_empty());
        let mut bytes = Vec::new();
        client.read_to_end(&mut bytes).unwrap();
        assert!(bytes.is_empty(), "stopping sent a 500 response: {bytes:?}");
        if let Some((_, _, handle)) = job {
            let mut ops = OpTable::default();
            ops.insert(
                op,
                OpRecord {
                    kind: OpKind::Release(id),
                    deliver_to: None,
                    lent: None,
                    site: None,
                },
            );
            let completion = Completion {
                op,
                outcome: Outcome::Released(handle.release()),
                returned: LentOwned::Nothing,
            };
            check_completion(&ops, &rt.resources, &completion).unwrap();
            assert!(
                matches!(accept_completion(&mut ops, &mut rt.resources, &mut None, completion).as_slice(), [Accepted::ReleaseFinished(resource)] if *resource == id)
            );
        }
    }
}

// 関門: 登録を外した Listener には新しい準備が来ないので、待ちを解放で起こす。
// 仮想時計は VM が idle になるまで進まないため、close より前に accept が待つ。
#[test]
fn closing_listener_wakes_parked_accept_without_waiting_for_retry_deadline() {
    let checked = crate::pipeline::check_text("l30-close.bnt", br#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.IO.Clock
function main() -> Result[Unit, String] uses Http.Listen, Clock.Time, State
 with listener = try Http.listen("fake", 0) |> Result.mapError(_, NetworkError.message), group = TaskGroup.open() do
  bind _ <- TaskGroup.spawn(group, lambda()
   Clock.sleep(1)
   bind _ <- Http.closeListener(listener)
   return ()
  end lambda)
  bind _ <- Http.accept(listener)
  return Result.Ok(())
 end with
end function
"#, crate::pipeline::CheckOptions { require_main: true, deny_warnings: false });
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = crate::pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    let program = crate::pipeline::compile(&core, checked.sources).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let evidence = run_injected(&program, mode);
        assert!(
            matches!(evidence.end, VmStep::Stopped(crate::vm::StopEnd { reason: crate::vm::StopReason::Error(ref info), .. }) if info.stop == Stop::Runtime(RuntimeError::ReleasedResourceUsed { kind: ResourceKind::HttpListener }))
        );
        assert_eq!(evidence.waits, [1]);
    }
}

// 関門: 覗く入口は未開始と別のタスクの呼び出しの誤り順序を保ち、所有者の再開と登録の失敗だけを処理する。
#[test]
fn resume_peeks_before_validation_and_checks_pending_owner_and_registration_failure() {
    let mut table = ResourceTable::default();
    let owner = TaskId {
        index: 0,
        generation: 0,
    };
    assert!(matches!(
        resume(&mut table, ResourceId(99), owner),
        Ok(Resume::NotStarted)
    ));
    let id = table.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(Exchange {
            socket: None,
            release_socket: None,
            registration: None,
            response: Some(WriteBuffer::new(b"saved".to_vec())),
            response_owner: Some(TaskId {
                index: 1,
                generation: 0,
            }),
            responded: false,
            registration_failure: None,
        }))),
        None,
    );
    assert!(matches!(
        resume(&mut table, id, owner),
        Ok(Resume::NotStarted)
    ));
    let exchange = resource::<Exchange>(&mut table, id, ResourceKind::HttpExchange).unwrap();
    exchange.response_owner = Some(owner);
    exchange.registration_failure = Some(io::Error::from(io::ErrorKind::PermissionDenied).into());
    assert!(matches!(
        resume(&mut table, id, owner),
        Ok(Resume::Writing(Some(Err(_))))
    ));
    assert!(matches!(
        resume(&mut table, id, owner),
        Ok(Resume::NotStarted)
    ));
    table.request_release(id, ExtOpId(2));
    assert!(matches!(
        resume(&mut table, id, owner),
        Ok(Resume::NotStarted)
    ));
    let wrong = table.insert(
        ResourceKind::TaskGroup,
        ResourceContent::TaskGroup(vec![]),
        None,
    );
    assert!(matches!(
        resume(&mut table, wrong, owner),
        Ok(Resume::NotStarted)
    ));
}

// 関門: 実際の部分送信から、組み立て済みのバイト列を受け取らずに再開して全量と EOF を送る。
#[test]
fn resume_finishes_pending_response_without_replacement_bytes() {
    let listener = std::net::TcpListener::bind(("127.0.0.1", 0)).unwrap();
    let mut client = std::net::TcpStream::connect(listener.local_addr().unwrap()).unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(30)))
        .unwrap();
    let (socket, _) = listener.accept().unwrap();
    socket.set_nonblocking(true).unwrap();
    let mut socket = mio::net::TcpStream::from_std(socket);
    let mut poll = mio::Poll::new().unwrap();
    poll.registry()
        .register(&mut socket, mio::Token(0), mio::Interest::WRITABLE)
        .unwrap();
    let mut table = ResourceTable::default();
    let id = table.insert(
        ResourceKind::HttpExchange,
        ResourceContent::Os(Some(Box::new(Exchange {
            socket: Some(socket),
            release_socket: None,
            registration: None,
            response: None,
            response_owner: None,
            responded: false,
            registration_failure: None,
        }))),
        None,
    );
    let owner = TaskId {
        index: 0,
        generation: 0,
    };
    let bytes: Vec<u8> = (0u8..=255).cycle().take(16 * 1024 * 1024).collect();
    let expected = bytes.clone();
    assert!(respond(&mut table, id, owner, bytes).unwrap().is_none());
    let received = std::thread::spawn(move || {
        let mut bytes = Vec::new();
        client.read_to_end(&mut bytes).unwrap();
        bytes
    });
    let mut events = mio::Events::with_capacity(4);
    loop {
        match resume(&mut table, id, owner).unwrap() {
            Resume::Writing(Some(result)) => {
                result.unwrap();
                break;
            }
            Resume::Writing(None) => {
                poll.poll(&mut events, Some(Duration::from_secs(30)))
                    .unwrap();
                assert!(!events.is_empty(), "response readiness timeout");
            }
            Resume::NotStarted => panic!("pending response lost"),
        }
    }
    assert_eq!(received.join().unwrap(), expected);
    assert!(matches!(
        resume(&mut table, id, owner),
        Ok(Resume::NotStarted)
    ));
    assert!(matches!(
        respond(&mut table, id, owner, vec![]),
        Err(Stop::Runtime(RuntimeError::ResponseSentTwice))
    ));
}

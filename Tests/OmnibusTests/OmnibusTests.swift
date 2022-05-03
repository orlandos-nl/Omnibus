import XCTest
import NIO
import NIOHTTP1
import TypedChannels
import Omnibus

public final class StringReader: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = String
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var data = unwrapInboundIn(data)
        let string = data.readString(length: data.readableBytes)!
        context.fireChannelRead(wrapInboundOut(string))
    }
}

public final class StringEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = String
    public typealias OutboundOut = ByteBuffer
    
    public init() {}
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let string = unwrapOutboundIn(data)
        let buffer = ByteBuffer(string: string)
        context.write(wrapOutboundOut(buffer), promise: promise)
    }
}

public final class StringPrinter: ChannelInboundHandler {
    public typealias InboundIn = String
    public typealias InboundOut = Never
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let string = unwrapInboundIn(data)
        print(string)
    }
}

public final class HTTPRequestLogger: ChannelInboundHandler {
    public typealias InboundIn = HTTPClientRequestPart
    public typealias InboundOut = Never
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        print(part)
    }
}

public final class HTTPResponseLogger: ChannelInboundHandler {
    public typealias InboundIn = HTTPClientResponsePart
    public typealias InboundOut = HTTPClientResponsePart
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        print(part)
        context.fireChannelRead(data)
    }
}

final class HTTPProxyServerResponseMapper: ChannelOutboundHandler {
    typealias OutboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPServerResponsePart
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let out: OutboundOut
        
        switch unwrapOutboundIn(data) {
        case .head(let head):
            out = .head(head)
        case .body(let body):
            out = .body(.byteBuffer(body))
        case .end(let end):
            out = .end(end)
        }
        
        context.write(wrapOutboundOut(out), promise: nil)
    }
}

public final class OutputToChannelHandler<Payload>: ChannelInboundHandler {
    public typealias InboundIn = Payload
    public typealias InboundOut = Never
    
    let write: (Payload) async throws -> ()
    
    public init<C: WritableChannel>(channel: C) where C.OutboundIn == Payload {
        self.write = channel.write
    }
    
    public init(
        channel: Channel,
        payloadType: Payload.Type = Payload.self
    ) {
        self.write = { payload in
            try await channel.writeAndFlush(payload)
        }
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = unwrapInboundIn(data)
        Task {
            try await write(data)
        }
    }
}

public final class ProxyChannelHandler<
    Proxy: ReadableChannel & WritableChannel & ClosableChannel
>: ChannelDuplexHandler {
    public typealias OutboundIn = Proxy.OutboundOut
    public typealias OutboundOut = Proxy.OutboundOut
    public typealias InboundIn = Proxy.OutboundIn
    public typealias InboundOut = Never
    public typealias BuildProxyChannel = (Channel) async throws -> Proxy
    
    // TODO: Real backpressure
    private var queue = [InboundIn]()
    private let buildChannel: BuildProxyChannel
    private var otherChannel: Proxy?
    
    public init(buildChannel: @escaping BuildProxyChannel) {
        self.buildChannel = buildChannel
    }
    
    public func channelActive(context: ChannelHandlerContext) {
        let channel = context.channel
        Task {
            do {
                let otherChannel = try await buildChannel(channel)
                self.otherChannel = otherChannel
                for item in queue {
                    try await otherChannel.write(item)
                }
            } catch {
                context.fireErrorCaught(error)
            }
        }
    }
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: promise)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = unwrapInboundIn(data)
        
        if let otherChannel = otherChannel {
            Task {
                try await otherChannel.write(data)
            }
        } else {
            queue.append(data)
        }
    }
}

final class HTTPProxyServerRequestMapper: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPClientRequestPart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let out: InboundOut

        switch unwrapInboundIn(data) {
        case .head(let head):
            out = .head(head)
        case .body(let body):
            out = .body(.byteBuffer(body))
        case .end(let headers):
            out = .end(headers)
        }

        context.fireChannelRead(wrapInboundOut(out))
    }
}

final class DeclarativeTestTests: XCTestCase {
    func testExample() async throws {
        let httpSpoof = try await TCPClient<String>.buildPosixClient(
            host: "example.com",
            port: 80
        ) {
            IODataDuplexHandler()
            StringEncoder()
            StringReader()
            StringPrinter()
        }

        try await httpSpoof.write("""
        GET / HTTP/1.1\r
        Host: example.com\r
        Accept: text/html\r
        \r\n
        """)

        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 10)
        try await httpSpoof.close()
    }

//    func testSSHProxiedHTTP() async throws {
////        let string = try String(contentsOfFile: "/Users/joannisorlandos/.ssh/...")
//
//        let server = try await TCPServer.buildServer(host: "127.0.0.1", port: 8082) {
//            IODataInboundDecoder()
//            HTTPResponseEncoder()
//            ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes))
//            HTTPProxyServerRequestMapper()
//            HTTPProxyServerResponseMapper()
//            ProxyChannelHandler { baseChannel in
//                return try await SSHClient.connect(
//                    host: "orlandos.nl",
//                    authenticationMethod: .rsa(username: "joannis", privateKey: .init(sshRsa: string)),
//                    hostKeyValidator: .acceptAnything()
//                ).buildTunnel(host: "example.com", port: 80) {
//                    IODataOutboundDecoder()
//                    HTTPRequestEncoder()
//                    HTTPResponseDecoder(leftOverBytesStrategy: .dropBytes)
//                    HTTPResponseLogger()
//                    OutputToChannelHandler(channel: baseChannel, payloadType: HTTPClientResponsePart.self)
//                }
//            }
//        }
//
//        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 100)
//        try await server.close()
//    }
}

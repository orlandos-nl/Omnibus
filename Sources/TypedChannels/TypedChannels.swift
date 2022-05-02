import NIO

@resultBuilder struct IntToStringBuilder {
    public static func buildBlock(_ components: Int...) -> String {
        components.map(String.init).joined(separator: ",")
    }
    
}

@resultBuilder public struct ChannelBuilder<InboundOut, OutboundIn> {
    public static func buildPartialBlock<Handler: ChannelDuplexHandler>(
        first handler: Handler
    ) -> ModifiedTypedChannel<Handler.InboundOut, Handler.OutboundIn> where InboundOut == Handler.InboundIn, OutboundIn == Handler.OutboundOut {
        ModifiedTypedChannel<_, _>(handlers: [ handler ])
    }
    
    public static func buildPartialBlock<
        PartialIn, PartialOut,
        Handler: ChannelDuplexHandler
    >(
        accumulated base: ModifiedTypedChannel<PartialIn, PartialOut>,
        next handler: Handler
    ) -> ModifiedTypedChannel<Handler.InboundOut, Handler.OutboundIn> where PartialIn == Handler.InboundIn, OutboundIn == Handler.OutboundOut
    {
        ModifiedTypedChannel<_, _>(handlers: base.handlers + [handler])
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<Handler: ChannelInboundHandler>(
        first handler: Handler
    ) -> ModifiedTypedChannel<Handler.InboundOut, OutboundIn> where InboundOut == Handler.InboundIn {
        ModifiedTypedChannel<_, _>(handlers: [ handler ])
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<Handler: ChannelOutboundHandler>(
        first handler: Handler
    ) -> ModifiedTypedChannel<InboundOut, Handler.OutboundIn> where OutboundIn == Handler.OutboundOut {
        ModifiedTypedChannel<_, _>(handlers: [ handler ])
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<
        PartialIn, PartialOut,
        Handler: ChannelInboundHandler
    >(
        accumulated base: ModifiedTypedChannel<PartialIn, PartialOut>,
        next handler: Handler
    ) -> ModifiedTypedChannel<Handler.InboundOut, PartialOut> where PartialIn == Handler.InboundIn
    {
        ModifiedTypedChannel<_, _>(handlers: base.handlers + [handler])
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<PartialOut, Decoder: ByteToMessageDecoder>(
        accumulated base: ModifiedTypedChannel<ByteBuffer, PartialOut>,
        next decoder: Decoder
    ) -> ModifiedTypedChannel<Decoder.InboundOut, PartialOut> {
        ModifiedTypedChannel<_, _>(
            handlers: base.handlers + [ByteToMessageHandler(decoder)]
        )
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<PartialIn, Encoder: MessageToByteEncoder>(
        accumulated base: ModifiedTypedChannel<PartialIn, ByteBuffer>,
        next encoder: Encoder
    ) -> ModifiedTypedChannel<PartialIn, Encoder.OutboundIn> {
        ModifiedTypedChannel<_, _>(
            handlers: base.handlers + [MessageToByteHandler(encoder)]
        )
    }
    
    @_disfavoredOverload
    public static func buildPartialBlock<
        PartialIn, PartialOut,
        Handler: ChannelOutboundHandler
    >(
        accumulated base: ModifiedTypedChannel<PartialIn, PartialOut>,
        next handler: Handler
    ) -> ModifiedTypedChannel<PartialIn, Handler.OutboundIn> where PartialOut == Handler.OutboundOut
    {
        ModifiedTypedChannel<_, _>(handlers: base.handlers + [handler])
    }
    
//    public static func buildPartialBlock<PartialIn, PartialOut, C>(
//        accumulated base: ModifiedTypedChannel<PartialIn, PartialOut>,
//        next handler: GlueHandler<C>
//    ) -> ConfiguredChannel<InboundOut, Never, Never, OutboundIn> where C.OutboundIn == PartialOut {
//        ConfiguredChannel<_, _, _, _>(
//            handlers: base.handlers + [handler.makeHandler()]
//        )
//    }
    
    @_disfavoredOverload
    public static func buildFinalResult<Input, Output>(
        _ component: ConfiguredChannel<InboundOut, Output, Input, OutboundIn>
    ) -> ConfiguredChannel<InboundOut, Output, Input, OutboundIn> {
        component
    }
    
    public static func buildFinalResult<Input, Output>(
        _ component: ModifiedTypedChannel<Never, Input>
    ) -> ConfiguredChannel<InboundOut, Output, Input, OutboundIn> {
        ConfiguredChannel<_, _, _, _>(handlers: component.handlers)
    }
}

//public struct GlueHandler<C: WritableChannel> {
//    let channel: C
//
//    public init(to channel: C) {
//        self.channel = channel
//    }
//
//    func makeHandler() -> OutputToChannelHandler<C> {
//        OutputToChannelHandler(channel: channel)
//    }
//}

public struct ConfiguredChannel<InboundIn, InboundOut, OutboundIn, OutboundOut> {
    let handlers: [ChannelHandler]
    
    func addHandlers(to channel: Channel) async throws {
        try await channel.pipeline.addHandlers(handlers)
    }
    
//    public func glue<C: WritableChannel>(
//        to channel: C
//    ) -> ConfiguredChannel<InboundIn, Never, OutboundIn, OutboundOut> where C.OutboundIn == InboundOut {
//        let outputHandler = OutputToChannelHandler(channel: channel)
//        return .init(handlers: handlers + [outputHandler])
//    }
}

public struct ModifiedTypedChannel<In, Out> {
    let handlers: [ChannelHandler]
}

extension ClientBootstrap {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    public func buildHandlers<InboundOut, OutboundIn>(
        @ChannelBuilder<InboundIn, OutboundOut> build: @escaping () -> ConfiguredChannel<InboundIn, InboundOut, OutboundIn, OutboundOut>
    ) -> ClientBootstrap {
        return channelInitializer { channel in
            channel.pipeline.addHandlers(build().handlers)
        }
    }
}

public protocol ReadableChannel {
    associatedtype OutboundOut
}

public protocol WritableChannel {
    associatedtype OutboundIn
    
    func write(_ data: OutboundIn) async throws
}

public protocol ClosableChannel {
    func close() async throws
}

public final class IODataOutboundEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = IOData
    
    public init() {}
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}

public final class IODataOutboundDecoder: ChannelOutboundHandler {
    public typealias OutboundIn = IOData
    public typealias OutboundOut = ByteBuffer
    
    public init() {}
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}

public final class IODataInboundEncoder: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = IOData
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
}

public final class IODataInboundDecoder: ChannelInboundHandler {
    public typealias InboundIn = IOData
    public typealias InboundOut = ByteBuffer
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
}

public final class IODataDuplexHandler: ChannelDuplexHandler {
    public typealias InboundIn = IOData
    public typealias InboundOut = ByteBuffer
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = IOData
    
    public init() {}
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: nil)
    }
}

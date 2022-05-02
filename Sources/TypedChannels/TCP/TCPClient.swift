import NIO
// TODO: import NIOTransportServices

public struct TCPClient<OutboundIn>: WritableChannel, ClosableChannel {
    public typealias InboundIn = IOData
    public typealias OutboundOut = IOData
    
    private let channel: Channel
    
    public static func buildPosixClient<OutboundIn>(
        host: String,
        port: Int,
        group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1),
        @ChannelBuilder<InboundIn, OutboundOut> buildHandlers: @escaping () -> ConfiguredChannel<InboundIn, Never, OutboundIn, OutboundOut>
    ) async throws -> TCPClient<OutboundIn> {
        let channel = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers(buildHandlers().handlers)
            }
            .connect(host: host, port: port)
            .get()
        
        return TCPClient<_>(channel: channel)
    }
    
    // TODO: NIOTS
    
    public func write(_ data: OutboundIn) async throws {
        try await channel.writeAndFlush(data)
    }
    
    public func close() async throws {
        try await channel.close()
    }
}

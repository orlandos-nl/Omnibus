import NIO
// TODO: import NIOTransportServices

public struct TCPServer: ClosableChannel {
    public typealias InboundIn = IOData
    public typealias OutboundOut = IOData
    
    private let channel: Channel
    
    public static func buildServer<OutboundIn>(
        host: String,
        port: Int,
        group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1),
        @ChannelBuilder<InboundIn, OutboundOut> buildHandlers: @escaping () -> ConfiguredChannel<InboundIn, Never, OutboundIn, OutboundOut>
    ) async throws -> TCPServer {
        let channel = try await ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers(buildHandlers().handlers)
            }
            .bind(host: host, port: port)
            .get()
        
        return TCPServer(channel: channel)
    }
    
    public func close() async throws {
        try await channel.close()
    }
}

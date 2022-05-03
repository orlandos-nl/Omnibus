# ⚠️ Requires Swift 5.7

Omnibus is a set of helpers for SwiftNIO that allow you to leverage Swift's generics type system to create NIO Channels.

It depends on Swift 5.7's new ResultBuilder feature, [Partial Blocks](https://github.com/apple/swift-evolution/blob/main/proposals/0348-buildpartialblock.md), and leverages this to enable type-checked channel building.

Channels are written in the same order as they're used in NIO normally. Inbound data comes in from the top, using the channel's read (Inbound) types. For official NIO channels that's IOData, and official channels also write (Outbound) IOData.

Each handler transforms either the Inboud, Outbound or both types using `ChannelInboundHandler`, `ChannelOutboundHandler` or `ChannelDuplexHandler` respectively.

Omnibus' channel builder type checks each handler, so that the InboundOut of one handler must match the InboundIn of the next. Likewise, it checks if the OutboundIn and OutboundOut match up as well.

When writing channels using this system, or NIO in general, the input (read data) comes in at the first handler. However, outbound data comes in at the bottom of the chain, and works its way back to the front.

### Example

```swift
let myPrivateKey: Insecure.RSA.PrivateKey = ..

// Create a TCP Server that accepts clients on localhost:8082
let server = try await TCPServer.buildServer(host: "127.0.0.1", port: 8082) {
  // InboundHandler that maps NIO's IOData to ByteBuffer
  IODataInboundDecoder()
  // OutboundHandler that encodes HTTPServerResponsePart to IOData
  HTTPResponseEncoder()
  // InboundHandler that decodes ByteBuffer
  ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes))
  // InboundHandler that maps HTTPServerRequestPart to HTTPClientRequestPart
  HTTPProxyServerRequestMapper()
  // OutboundHandler that maps HTTPClientResponsePart to HTTPServerResponsePart
  HTTPProxyServerResponseMapper()
  
  // DuplexHandler that consumes all Inbound data
  ProxyChannelHandler { baseChannel in
    // baseChannel is the client connected to TCPServer
    // 1. Connect to an SSHServer and start an SSH tunnel
    // 2. Configure that tunnel's channel
    // 3. Return the configured (typed) channel
    return try await SSHClient.connect(
        host: "orlandos.nl",
        authenticationMethod: .rsa(username: "joannis", privateKey: myPrivateKey),
        hostKeyValidator: .acceptAnything()
    ).buildTunnel(host: "example.com", port: 80) {
      // OutboundHandler that maps IOData to ByteBuffer. SSHTunnel reads/writes ByteBuffer, not IOData.
      IODataOutboundDecoder()
      // OutboundHandler that Encodes Ooutbound HTTPClientRequestPart to IOData
      HTTPRequestEncoder()
      // InboundHandler that decodes incoming ByteBuffer into HTTPClientResponsePart
      HTTPResponseDecoder(leftOverBytesStrategy: .dropBytes)
      // InboundHandler that consumes HTTPClientResponsePart, and writes it to the TCPServer's client
      OutputToChannelHandler(channel: baseChannel, payloadType: HTTPClientResponsePart.self)
    }
  }
}
```

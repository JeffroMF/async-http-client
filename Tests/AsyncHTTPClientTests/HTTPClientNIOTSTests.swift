//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHTTPClient open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the AsyncHTTPClient project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AsyncHTTPClient project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AsyncHTTPClient
#if canImport(Network)
    import Network
#endif
import NIO
import NIOSSL
import NIOTransportServices
import XCTest

class HTTPClientNIOTSTests: XCTestCase {
    var clientGroup: EventLoopGroup!

    override func setUp() {
        XCTAssertNil(self.clientGroup)
        self.clientGroup = getDefaultEventLoopGroup(numberOfThreads: 3)
    }

    override func tearDown() {
        XCTAssertNotNil(self.clientGroup)
        XCTAssertNoThrow(try self.clientGroup.syncShutdownGracefully())
        self.clientGroup = nil
    }

    func testCorrectEventLoopGroup() {
        let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
        defer {
            XCTAssertNoThrow(try httpClient.syncShutdown())
        }
        #if canImport(Network)
            if #available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
                XCTAssertTrue(httpClient.eventLoopGroup is NIOTSEventLoopGroup)
                return
            }
        #endif
        XCTAssertTrue(httpClient.eventLoopGroup is MultiThreadedEventLoopGroup)
    }

    func testTLSFailError() {
        guard isTestingNIOTS() else { return }
        #if canImport(Network)
            let httpBin = HTTPBin(ssl: true)
            let httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.clientGroup))
            defer {
                XCTAssertNoThrow(try httpClient.syncShutdown(requiresCleanClose: true))
                XCTAssertNoThrow(try httpBin.shutdown())
            }

            do {
                _ = try httpClient.get(url: "https://localhost:\(httpBin.port)/get").wait()
                XCTFail("This should have failed")
            } catch let error as HTTPClient.NWTLSError {
                XCTAssertEqual(error.status, errSSLHandshakeFail)
            } catch {
                XCTFail("Error should have been NWTLSError not \(type(of: error))")
            }
        #endif
    }

    func testConnectionFailError() {
        guard isTestingNIOTS() else { return }
        let httpBin = HTTPBin(ssl: true)
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.clientGroup))
        defer {
            XCTAssertNoThrow(try httpClient.syncShutdown(requiresCleanClose: true))
        }
        let port = httpBin.port
        XCTAssertNoThrow(try httpBin.shutdown())

        do {
            _ = try httpClient.get(url: "https://localhost:\(port)/get").wait()
            XCTFail("This should have failed")
        } catch ChannelError.connectTimeout {
        } catch {
            XCTFail("Error should have been ChannelError.connectTimeout not \(type(of: error))")
        }
    }

    func testTLSVersionError() {
        guard isTestingNIOTS() else { return }
        #if canImport(Network)
            let httpBin = HTTPBin(ssl: true)
            let httpClient = HTTPClient(
                eventLoopGroupProvider: .shared(self.clientGroup),
                configuration: .init(tlsConfiguration: TLSConfiguration.forClient(minimumTLSVersion: .tlsv11, maximumTLSVersion: .tlsv1, certificateVerification: .none))
            )
            defer {
                XCTAssertNoThrow(try httpClient.syncShutdown(requiresCleanClose: true))
                XCTAssertNoThrow(try httpBin.shutdown())
            }

            do {
                _ = try httpClient.get(url: "https://localhost:\(httpBin.port)/get").wait()
                XCTFail("This should have failed")
            } catch let error as HTTPClient.NWTLSError {
                XCTAssertEqual(error.status, errSSLHandshakeFail)
            } catch {
                XCTFail("Error should have been NWTLSError not \(type(of: error))")
            }
        #endif
    }
}
import XCTest
@testable import DashCast

@MainActor
final class DLNAReceiverTests: XCTestCase {

    // MARK: - SSDP Packet Formatting & Discovery

    func testParseValidSSDPMSearchAndMatchTargets() {
        let uuid = "12345678-90ab-cdef-1234-567890abcdef"
        let raw = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "MAN: \"ssdp:discover\"",
            "MX: 3",
            "ST: urn:schemas-upnp-org:device:MediaRenderer:1",
            "",
            ""
        ].joined(separator: "\r\n")

        let request = DLNAProtocol.parseSSDPRequest(Data(raw.utf8))
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.method, "M-SEARCH")
        XCTAssertEqual(request?.searchTarget, "urn:schemas-upnp-org:device:MediaRenderer:1")
        XCTAssertEqual(request?.mx, 3)

        XCTAssertTrue(DLNAProtocol.shouldRespond(toSearchTarget: "ssdp:all", deviceUUID: uuid))
        XCTAssertTrue(DLNAProtocol.shouldRespond(toSearchTarget: "upnp:rootdevice", deviceUUID: uuid))
        XCTAssertTrue(DLNAProtocol.shouldRespond(toSearchTarget: "uuid:\(uuid)", deviceUUID: uuid))
        XCTAssertTrue(DLNAProtocol.shouldRespond(toSearchTarget: "urn:schemas-upnp-org:service:AVTransport:1", deviceUUID: uuid))
        XCTAssertFalse(DLNAProtocol.shouldRespond(toSearchTarget: "urn:schemas-upnp-org:device:InternetGatewayDevice:1", deviceUUID: uuid))

        XCTAssertEqual(DLNAProtocol.searchResponseTargets(for: "ssdp:all", deviceUUID: uuid).count, 5)
    }

    func testParseSSDPRejectsNonSearchOrMissingMan() {
        let notify = "NOTIFY * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nST: ssdp:all\r\n\r\n"
        XCTAssertNil(DLNAProtocol.parseSSDPRequest(Data(notify.utf8)))

        let missingMan = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nST: ssdp:all\r\n\r\n"
        XCTAssertNil(DLNAProtocol.parseSSDPRequest(Data(missingMan.utf8)))
    }

    func testSSDPMSearchResponseAndNotifyPacketFormatting() {
        let uuid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        let location = "http://172.20.10.1:8090/description.xml"

        let responseData = DLNAProtocol.mSearchResponse(
            location: location,
            searchTarget: DLNAProtocol.mediaRendererDeviceType,
            deviceUUID: uuid,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let responseText = String(decoding: responseData, as: UTF8.self)
        XCTAssertTrue(responseText.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(responseText.contains("LOCATION: \(location)\r\n"))
        XCTAssertTrue(responseText.contains("ST: \(DLNAProtocol.mediaRendererDeviceType)\r\n"))
        XCTAssertTrue(responseText.contains("USN: uuid:\(uuid)::\(DLNAProtocol.mediaRendererDeviceType)\r\n"))
        XCTAssertTrue(responseText.hasSuffix("\r\n\r\n"))

        let aliveText = String(decoding: DLNAProtocol.notifyPacket(
            subtype: .alive,
            location: location,
            notificationType: "uuid:\(uuid)",
            deviceUUID: uuid
        ), as: UTF8.self)
        XCTAssertTrue(aliveText.hasPrefix("NOTIFY * HTTP/1.1\r\n"))
        XCTAssertTrue(aliveText.contains("NTS: ssdp:alive\r\n"))
        XCTAssertTrue(aliveText.contains("LOCATION: \(location)\r\n"))
        XCTAssertTrue(aliveText.contains("USN: uuid:\(uuid)\r\n"))

        let byebyeText = String(decoding: DLNAProtocol.notifyPacket(
            subtype: .byebye,
            location: "",
            notificationType: DLNAProtocol.avTransportServiceType,
            deviceUUID: uuid
        ), as: UTF8.self)
        XCTAssertTrue(byebyeText.contains("NTS: ssdp:byebye\r\n"))
        XCTAssertFalse(byebyeText.contains("LOCATION:"))
    }

    func testDeviceDescriptionXMLContainsMediaRendererAndEscapesName() {
        let xml = DLNAProtocol.deviceDescriptionXML(
            friendlyName: "Alex & Sara's <Car>",
            deviceUUID: "11111111-2222-3333-4444-555555555555",
            baseURL: "http://192.168.1.42:8090"
        )
        XCTAssertTrue(xml.contains("<deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>"))
        XCTAssertTrue(xml.contains("<friendlyName>Alex &amp; Sara&apos;s &lt;Car&gt;</friendlyName>"))
        XCTAssertTrue(xml.contains("<controlURL>/upnp/AVTransport/control</controlURL>"))
        XCTAssertTrue(xml.contains("<controlURL>/upnp/RenderingControl/control</controlURL>"))
    }

    // MARK: - SOAP Parsing & Scheme Validation

    func testParseSetAVTransportURIWithDIDLLiteTitle() throws {
        let didl = """
        <DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <item id="1" parentID="0" restricted="1">
            <dc:title>Road Trip Movie</dc:title>
          </item>
        </DIDL-Lite>
        """
        let soap = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
          <s:Body>
            <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
              <InstanceID>0</InstanceID>
              <CurrentURI>http://192.168.1.55:8200/media/movie.mp4?token=abc&amp;hd=1</CurrentURI>
              <CurrentURIMetaData>\(DLNAProtocol.escapeXML(didl))</CurrentURIMetaData>
            </u:SetAVTransportURI>
          </s:Body>
        </s:Envelope>
        """

        let action = try DLNAProtocol.parseSOAPAction(
            body: Data(soap.utf8),
            soapActionHeader: "\"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI\""
        )
        guard case .setAVTransportURI(let uri, let title, _) = action else {
            XCTFail("Expected setAVTransportURI action")
            return
        }
        XCTAssertEqual(uri.absoluteString, "http://192.168.1.55:8200/media/movie.mp4?token=abc&hd=1")
        XCTAssertEqual(title, "Road Trip Movie")
    }

    func testRejectsNonHTTPAndUnsafeSchemes() {
        let unsafeURIs = [
            "file:///etc/passwd",
            "javascript:alert(1)",
            "ftp://192.168.1.10/video.mp4",
            "data:text/html,<script>alert(1)</script>",
            "smb://nas.local/movies/film.mkv"
        ]

        for uri in unsafeURIs {
            let soap = """
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
              <s:Body>
                <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
                  <InstanceID>0</InstanceID>
                  <CurrentURI>\(DLNAProtocol.escapeXML(uri))</CurrentURI>
                  <CurrentURIMetaData></CurrentURIMetaData>
                </u:SetAVTransportURI>
              </s:Body>
            </s:Envelope>
            """
            XCTAssertThrowsError(
                try DLNAProtocol.parseSOAPAction(
                    body: Data(soap.utf8),
                    soapActionHeader: "\"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI\""
                ),
                "Expected unsafe scheme rejection for \(uri)"
            ) { error in
                guard case DLNAProtocol.SOAPParseError.unsafeOrInvalidScheme = error else {
                    XCTFail("Expected unsafeOrInvalidScheme for \(uri), got \(error)")
                    return
                }
            }
        }
    }

    func testParsePlayPauseStopAndMuteActions() throws {
        func envelope(_ inner: String) -> Data {
            Data("""
            <?xml version="1.0" encoding="utf-8"?>
            <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
              <s:Body>\(inner)</s:Body>
            </s:Envelope>
            """.utf8)
        }

        let play = try DLNAProtocol.parseSOAPAction(
            body: envelope("<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>"),
            soapActionHeader: "\"urn:schemas-upnp-org:service:AVTransport:1#Play\""
        )
        XCTAssertEqual(play, .play(speed: "1"))

        let pause = try DLNAProtocol.parseSOAPAction(
            body: envelope("<u:Pause xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Pause>"),
            soapActionHeader: nil
        )
        XCTAssertEqual(pause, .pause)

        let stop = try DLNAProtocol.parseSOAPAction(
            body: envelope("<u:Stop xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Stop>"),
            soapActionHeader: nil
        )
        XCTAssertEqual(stop, .stop)

        let mute = try DLNAProtocol.parseSOAPAction(
            body: envelope("<u:SetMute xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><InstanceID>0</InstanceID><DesiredMute>1</DesiredMute></u:SetMute>"),
            soapActionHeader: "\"urn:schemas-upnp-org:service:RenderingControl:1#SetMute\""
        )
        XCTAssertEqual(mute, .setMute(muted: true))
    }

    // MARK: - Parked Guard & Entitlement Enforcement

    func testReceiverFeedsPlayerWhenParkedAndBlocksWhenMoving() {
        let suite = "DLNAReceiverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        var loadedChannels: [ChannelModel] = []
        var commands: [DLNATransportCommand] = []
        let service = DLNAReceiverService(
            defaults: defaults,
            entitlementChecker: { true },
            externalParkedChecker: { true },
            playbackHandler: { loadedChannels.append($0) },
            transportControlHandler: { commands.append($0) },
            observeSharedController: false
        )

        let t0 = Date()
        service.updateMotionState(speedKmh: 0, automotiveMoving: false, at: t0)

        let streamURL = URL(string: "https://media.example.com/clip.mp4")!
        let result = service.processSOAPAction(
            .setAVTransportURI(uri: streamURL, title: "Passenger Clip", metadata: nil),
            senderAddress: "192.168.1.44"
        )
        XCTAssertEqual(result, .success(()))
        XCTAssertEqual(loadedChannels.count, 1)
        XCTAssertEqual(loadedChannels.first?.name, "Passenger Clip")
        XCTAssertEqual(loadedChannels.first?.streamURL, streamURL)
        XCTAssertEqual(service.incomingQueue.count, 1)
        XCTAssertEqual(service.currentTransportState, .playing)

        // Transitioning to moving pauses active playback and blocks subsequent Play.
        service.updateMotionState(speedKmh: 35, automotiveMoving: true, at: t0.addingTimeInterval(2))
        XCTAssertTrue(service.blockedByMotion)
        XCTAssertEqual(service.currentTransportState, .paused)
        XCTAssertEqual(commands, [.pause])

        let blockedPlay = service.processSOAPAction(.play(speed: "1"))
        XCTAssertEqual(blockedPlay, .failure(.blockedWhileMoving))
        XCTAssertEqual(loadedChannels.count, 1)

        // Setting a new URI while moving queues the item without starting playback.
        let secondURL = URL(string: "http://192.168.1.44:8000/next.m3u8")!
        let blockedSet = service.processSOAPAction(.setAVTransportURI(uri: secondURL, title: "Next Clip", metadata: nil))
        XCTAssertEqual(blockedSet, .failure(.blockedWhileMoving))
        XCTAssertEqual(service.incomingQueue.count, 2)
        XCTAssertEqual(loadedChannels.count, 1)

        // Once parked for >= hold interval, playback is permitted again.
        service.updateMotionState(speedKmh: 0, automotiveMoving: false, at: t0.addingTimeInterval(3))
        service.updateMotionState(speedKmh: 0, automotiveMoving: false, at: t0.addingTimeInterval(15))
        XCTAssertFalse(service.blockedByMotion)

        let resumedPlay = service.processSOAPAction(.play(speed: "1"))
        XCTAssertEqual(resumedPlay, .success(()))
        XCTAssertEqual(loadedChannels.count, 2)
        XCTAssertEqual(loadedChannels.last?.streamURL, secondURL)
    }

    func testReceiverEnforcesEntitlementGate() {
        let suite = "DLNAReceiverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        var loadedChannels: [ChannelModel] = []
        var entitled = false
        let service = DLNAReceiverService(
            defaults: defaults,
            entitlementChecker: { entitled },
            externalParkedChecker: { true },
            playbackHandler: { loadedChannels.append($0) },
            observeSharedController: false
        )

        let url = URL(string: "https://media.example.com/gated.mp4")!
        let blocked = service.processSOAPAction(.setAVTransportURI(uri: url, title: "Gated", metadata: nil))
        XCTAssertEqual(blocked, .failure(.entitlementRequired))
        XCTAssertTrue(service.blockedByEntitlement)
        XCTAssertTrue(loadedChannels.isEmpty)

        entitled = true
        let allowed = service.processSOAPAction(.play(speed: "1"))
        XCTAssertEqual(allowed, .success(()))
        XCTAssertFalse(service.blockedByEntitlement)
        XCTAssertEqual(loadedChannels.count, 1)
    }
}

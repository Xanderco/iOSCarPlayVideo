import Foundation
import Network
import Darwin
import Combine

// MARK: - DLNA / UPnP Protocol Helpers

/// Pure SSDP, UPnP XML, and SOAP parser/formatter for the DLNA MediaRenderer receiver.
/// Isolated from UI and socket state so all protocol logic is deterministically unit-testable.
public enum DLNAProtocol {
    public static let ssdpMulticastHost = "239.255.255.250"
    public static let ssdpPort: UInt16 = 1900
    public static let defaultHTTPPort: UInt16 = 8090
    public static let serverProductHeader = "iOS/17.0 UPnP/1.1 DashCast/1.0"

    public static let rootDeviceType = "upnp:rootdevice"
    public static let mediaRendererDeviceType = "urn:schemas-upnp-org:device:MediaRenderer:1"
    public static let avTransportServiceType = "urn:schemas-upnp-org:service:AVTransport:1"
    public static let renderingControlServiceType = "urn:schemas-upnp-org:service:RenderingControl:1"

    public enum NotificationSubtype: String, Sendable {
        case alive = "ssdp:alive"
        case byebye = "ssdp:byebye"
    }

    public struct SSDPRequest: Equatable, Sendable {
        public let method: String
        public let searchTarget: String
        public let man: String
        public let mx: Int?
    }

    public enum SOAPAction: Equatable, Sendable {
        case setAVTransportURI(uri: URL, title: String?, metadata: String?)
        case play(speed: String?)
        case pause
        case stop
        case getTransportInfo
        case getPositionInfo
        case getMute
        case setMute(muted: Bool)
    }

    public enum SOAPParseError: Error, Equatable, LocalizedError, Sendable {
        case invalidEncoding
        case missingSOAPAction
        case unsupportedAction(String)
        case missingTransportURI
        case unsafeOrInvalidScheme(String)
        case invalidURI
        case malformedXML

        public var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Invalid SOAP request encoding."
            case .missingSOAPAction:
                return "Missing SOAPAction header or action element."
            case .unsupportedAction(let name):
                return "Unsupported UPnP action: \(name)"
            case .missingTransportURI:
                return "Missing CurrentURI in SetAVTransportURI request."
            case .unsafeOrInvalidScheme(let scheme):
                return "Rejected unsafe or unsupported media URL scheme: \(scheme)"
            case .invalidURI:
                return "Invalid media stream URL."
            case .malformedXML:
                return "Malformed SOAP XML envelope."
            }
        }
    }

    // MARK: - SSDP Parsing & Formatting

    public static func notificationTypes(deviceUUID: String) -> [String] {
        [
            rootDeviceType,
            "uuid:\(deviceUUID)",
            mediaRendererDeviceType,
            avTransportServiceType,
            renderingControlServiceType
        ]
    }

    public static func usn(for notificationType: String, deviceUUID: String) -> String {
        let uuidPrefix = "uuid:\(deviceUUID)"
        if notificationType == uuidPrefix {
            return uuidPrefix
        }
        return "\(uuidPrefix)::\(notificationType)"
    }

    public static func parseSSDPRequest(_ data: Data) -> SSDPRequest? {
        guard let text = String(data: data.prefix(4096), encoding: .utf8) else { return nil }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first?.trimmingCharacters(in: .whitespaces),
              requestLine.uppercased().hasPrefix("M-SEARCH ") else {
            return nil
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        guard let man = headers["man"],
              man.lowercased().contains("ssdp:discover"),
              let st = headers["st"], !st.isEmpty else {
            return nil
        }

        let mx = headers["mx"].flatMap { Int($0) }
        return SSDPRequest(method: "M-SEARCH", searchTarget: st, man: man, mx: mx)
    }

    public static func shouldRespond(toSearchTarget st: String, deviceUUID: String) -> Bool {
        let trimmed = st.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "ssdp:all" { return true }
        return notificationTypes(deviceUUID: deviceUUID).contains(trimmed)
    }

    public static func searchResponseTargets(for st: String, deviceUUID: String) -> [String] {
        let trimmed = st.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "ssdp:all" {
            return notificationTypes(deviceUUID: deviceUUID)
        }
        return shouldRespond(toSearchTarget: trimmed, deviceUUID: deviceUUID) ? [trimmed] : []
    }

    public static func mSearchResponse(
        location: String,
        searchTarget: String,
        deviceUUID: String,
        serverHeader: String = serverProductHeader,
        maxAge: Int = 1800,
        date: Date = Date()
    ) -> Data {
        let usnValue = usn(for: searchTarget, deviceUUID: deviceUUID)
        let dateString = rfc1123DateFormatter.string(from: date)
        let payload = [
            "HTTP/1.1 200 OK",
            "CACHE-CONTROL: max-age=\(max(60, maxAge))",
            "DATE: \(dateString)",
            "EXT:",
            "LOCATION: \(location)",
            "SERVER: \(serverHeader)",
            "ST: \(searchTarget)",
            "USN: \(usnValue)",
            "",
            ""
        ].joined(separator: "\r\n")
        return Data(payload.utf8)
    }

    public static func notifyPacket(
        subtype: NotificationSubtype,
        location: String,
        notificationType: String,
        deviceUUID: String,
        serverHeader: String = serverProductHeader,
        maxAge: Int = 1800
    ) -> Data {
        let usnValue = usn(for: notificationType, deviceUUID: deviceUUID)
        var lines = [
            "NOTIFY * HTTP/1.1",
            "HOST: \(ssdpMulticastHost):\(ssdpPort)"
        ]
        if subtype == .alive {
            lines.append("CACHE-CONTROL: max-age=\(max(60, maxAge))")
            lines.append("LOCATION: \(location)")
        }
        lines.append("NT: \(notificationType)")
        lines.append("NTS: \(subtype.rawValue)")
        if subtype == .alive {
            lines.append("SERVER: \(serverHeader)")
        }
        lines.append("USN: \(usnValue)")
        lines.append("")
        lines.append("")
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    private static let rfc1123DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()

    // MARK: - UPnP Device & SCPD XML

    public static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    public static func deviceDescriptionXML(friendlyName: String, deviceUUID: String, baseURL: String) -> String {
        let safeName = escapeXML(friendlyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DashCast Car Display" : friendlyName)
        let safeUUID = escapeXML(deviceUUID)
        let safeBaseURL = escapeXML(baseURL)
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <root xmlns="urn:schemas-upnp-org:device-1-0">
          <specVersion>
            <major>1</major>
            <minor>0</minor>
          </specVersion>
          <URLBase>\(safeBaseURL)</URLBase>
          <device>
            <deviceType>\(mediaRendererDeviceType)</deviceType>
            <friendlyName>\(safeName)</friendlyName>
            <manufacturer>DashCast</manufacturer>
            <manufacturerURL>https://dashcast.app</manufacturerURL>
            <modelDescription>DashCast Automotive Media Renderer</modelDescription>
            <modelName>DashCast Car Display</modelName>
            <modelNumber>1.0</modelNumber>
            <UDN>uuid:\(safeUUID)</UDN>
            <serviceList>
              <service>
                <serviceType>\(avTransportServiceType)</serviceType>
                <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
                <SCPDURL>/upnp/AVTransport.xml</SCPDURL>
                <controlURL>/upnp/AVTransport/control</controlURL>
                <eventSubURL>/upnp/AVTransport/event</eventSubURL>
              </service>
              <service>
                <serviceType>\(renderingControlServiceType)</serviceType>
                <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
                <SCPDURL>/upnp/RenderingControl.xml</SCPDURL>
                <controlURL>/upnp/RenderingControl/control</controlURL>
                <eventSubURL>/upnp/RenderingControl/event</eventSubURL>
              </service>
            </serviceList>
          </device>
        </root>
        """
    }

    public static func avTransportSCPDXML() -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <actionList>
            <action>
              <name>SetAVTransportURI</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>CurrentURI</name><direction>in</direction><relatedStateVariable>AVTransportURI</relatedStateVariable></argument>
                <argument><name>CurrentURIMetaData</name><direction>in</direction><relatedStateVariable>AVTransportURIMetaData</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>Play</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Speed</name><direction>in</direction><relatedStateVariable>TransportPlaySpeed</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>Pause</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>Stop</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>GetTransportInfo</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>CurrentTransportState</name><direction>out</direction><relatedStateVariable>TransportState</relatedStateVariable></argument>
                <argument><name>CurrentTransportStatus</name><direction>out</direction><relatedStateVariable>TransportStatus</relatedStateVariable></argument>
                <argument><name>CurrentSpeed</name><direction>out</direction><relatedStateVariable>TransportPlaySpeed</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>GetPositionInfo</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Track</name><direction>out</direction><relatedStateVariable>CurrentTrack</relatedStateVariable></argument>
                <argument><name>TrackDuration</name><direction>out</direction><relatedStateVariable>CurrentTrackDuration</relatedStateVariable></argument>
                <argument><name>TrackMetaData</name><direction>out</direction><relatedStateVariable>CurrentTrackMetaData</relatedStateVariable></argument>
                <argument><name>TrackURI</name><direction>out</direction><relatedStateVariable>CurrentTrackURI</relatedStateVariable></argument>
                <argument><name>RelTime</name><direction>out</direction><relatedStateVariable>RelativeTimePosition</relatedStateVariable></argument>
                <argument><name>AbsTime</name><direction>out</direction><relatedStateVariable>AbsoluteTimePosition</relatedStateVariable></argument>
              </argumentList>
            </action>
          </actionList>
          <serviceStateTable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_InstanceID</name><dataType>ui4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>AVTransportURI</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>AVTransportURIMetaData</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="yes"><name>TransportState</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>TransportStatus</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>TransportPlaySpeed</name><dataType>string</dataType><defaultValue>1</defaultValue></stateVariable>
            <stateVariable sendEvents="no"><name>CurrentTrack</name><dataType>ui4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>CurrentTrackDuration</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>CurrentTrackMetaData</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>CurrentTrackURI</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>RelativeTimePosition</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>AbsoluteTimePosition</name><dataType>string</dataType></stateVariable>
          </serviceStateTable>
        </scpd>
        """
    }

    public static func renderingControlSCPDXML() -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <scpd xmlns="urn:schemas-upnp-org:service-1-0">
          <specVersion><major>1</major><minor>0</minor></specVersion>
          <actionList>
            <action>
              <name>GetMute</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>CurrentMute</name><direction>out</direction><relatedStateVariable>Mute</relatedStateVariable></argument>
              </argumentList>
            </action>
            <action>
              <name>SetMute</name>
              <argumentList>
                <argument><name>InstanceID</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable></argument>
                <argument><name>Channel</name><direction>in</direction><relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable></argument>
                <argument><name>DesiredMute</name><direction>in</direction><relatedStateVariable>Mute</relatedStateVariable></argument>
              </argumentList>
            </action>
          </actionList>
          <serviceStateTable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_InstanceID</name><dataType>ui4</dataType></stateVariable>
            <stateVariable sendEvents="no"><name>A_ARG_TYPE_Channel</name><dataType>string</dataType></stateVariable>
            <stateVariable sendEvents="yes"><name>Mute</name><dataType>boolean</dataType></stateVariable>
          </serviceStateTable>
        </scpd>
        """
    }

    // MARK: - SOAP Parsing & Validation

    public static func validateMediaURL(_ rawURI: String) throws -> URL {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SOAPParseError.missingTransportURI
        }

        // Reject raw control characters or whitespace inside URI
        if trimmed.rangeOfCharacter(from: .controlCharacters) != nil {
            throw SOAPParseError.invalidURI
        }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            throw SOAPParseError.invalidURI
        }

        guard scheme == "http" || scheme == "https" else {
            throw SOAPParseError.unsafeOrInvalidScheme(scheme)
        }

        guard let host = url.host, !host.isEmpty else {
            throw SOAPParseError.invalidURI
        }

        return url
    }

    public static func extractActionName(fromSOAPActionHeader header: String?) -> String? {
        guard let header else { return nil }
        let cleaned = header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard let hash = cleaned.lastIndex(of: "#") else { return nil }
        let name = String(cleaned[cleaned.index(after: hash)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    public static func parseSOAPAction(body: Data, soapActionHeader: String?) throws -> SOAPAction {
        guard !body.isEmpty else {
            throw SOAPParseError.malformedXML
        }

        let parserDelegate = SOAPEnvelopeParser()
        let parser = XMLParser(data: body)
        parser.shouldProcessNamespaces = true
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw SOAPParseError.malformedXML
        }

        let actionName = extractActionName(fromSOAPActionHeader: soapActionHeader) ?? parserDelegate.actionName
        guard let actionName, !actionName.isEmpty else {
            throw SOAPParseError.missingSOAPAction
        }

        switch actionName {
        case "SetAVTransportURI":
            guard let rawURI = parserDelegate.fields["CurrentURI"],
                  !rawURI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SOAPParseError.missingTransportURI
            }
            let url = try validateMediaURL(rawURI)
            let metadata = parserDelegate.fields["CurrentURIMetaData"]
            let title = extractTitleFromDIDLLite(metadata)
            return .setAVTransportURI(uri: url, title: title, metadata: metadata)

        case "Play":
            return .play(speed: parserDelegate.fields["Speed"])

        case "Pause":
            return .pause

        case "Stop":
            return .stop

        case "GetTransportInfo":
            return .getTransportInfo

        case "GetPositionInfo":
            return .getPositionInfo

        case "GetMute":
            return .getMute

        case "SetMute":
            let raw = (parserDelegate.fields["DesiredMute"] ?? "0").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let muted = raw == "1" || raw == "true"
            return .setMute(muted: muted)

        default:
            throw SOAPParseError.unsupportedAction(actionName)
        }
    }

    public static func extractTitleFromDIDLLite(_ metadata: String?) -> String? {
        guard let metadata, !metadata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let data = metadata.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        let delegate = DIDLTitleParser()
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        guard parser.parse(), let title = delegate.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        return title
    }

    public static func soapSuccessResponse(actionName: String, serviceType: String, bodyElements: String = "") -> Data {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:\(actionName)Response xmlns:u="\(serviceType)">\(bodyElements)</u:\(actionName)Response>
          </s:Body>
        </s:Envelope>
        """
        return httpResponse(status: "200 OK", contentType: "text/xml; charset=\"utf-8\"", body: Data(xml.utf8))
    }

    public static func soapFaultResponse(upnpErrorCode: Int, description: String) -> Data {
        let safeDescription = escapeXML(description)
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <s:Fault>
              <faultcode>s:Client</faultcode>
              <faultstring>UPnPError</faultstring>
              <detail>
                <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
                  <errorCode>\(upnpErrorCode)</errorCode>
                  <errorDescription>\(safeDescription)</errorDescription>
                </UPnPError>
              </detail>
            </s:Fault>
          </s:Body>
        </s:Envelope>
        """
        return httpResponse(status: "500 Internal Server Error", contentType: "text/xml; charset=\"utf-8\"", body: Data(xml.utf8))
    }

    public static func httpResponse(status: String, contentType: String, body: Data) -> Data {
        var response = Data((
            "HTTP/1.1 \(status)\r\n" +
            "Content-Type: \(contentType)\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "EXT:\r\n" +
            "Server: \(serverProductHeader)\r\n" +
            "Connection: close\r\n\r\n"
        ).utf8)
        response.append(body)
        return response
    }
}

private final class SOAPEnvelopeParser: NSObject, XMLParserDelegate {
    var actionName: String?
    var fields: [String: String] = [:]

    private var insideBody = false
    private var currentFieldName: String?
    private var currentBuffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if local == "Body" {
            insideBody = true
            return
        }
        guard insideBody else { return }
        if actionName == nil {
            actionName = local
        } else {
            currentFieldName = local
            currentBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentFieldName != nil {
            currentBuffer += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if local == "Body" {
            insideBody = false
            return
        }
        if let field = currentFieldName, field == local {
            fields[field] = currentBuffer
            currentFieldName = nil
            currentBuffer = ""
        }
    }
}

private final class DIDLTitleParser: NSObject, XMLParserDelegate {
    var title: String?
    private var capturingTitle = false
    private var buffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if local == "title", title == nil {
            capturingTitle = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingTitle {
            buffer += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if capturingTitle, local == "title" {
            title = buffer
            capturingTitle = false
        }
    }
}

// MARK: - Queue & Transport Models

public enum DLNATransportState: String, Equatable, Sendable {
    case stopped = "STOPPED"
    case playing = "PLAYING"
    case paused = "PAUSED_PLAYBACK"
    case transitioning = "TRANSITIONING"
}

public enum DLNATransportCommand: Equatable, Sendable {
    case play
    case pause
    case stop
}

public struct DLNAQueueItem: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let streamURL: URL
    public let senderAddress: String?
    public let receivedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        streamURL: URL,
        senderAddress: String? = nil,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.streamURL = streamURL
        self.senderAddress = senderAddress
        self.receivedAt = receivedAt
    }

    public func asChannelModel() -> ChannelModel {
        ChannelModel(
            id: "dlna-\(id.uuidString)",
            name: title,
            streamURL: streamURL,
            groupTitle: "DLNA Cast"
        )
    }
}

// MARK: - DLNA / UPnP Receiver Service

/// Local network DLNA/UPnP MediaRenderer receiver allowing passengers on the car's
/// Wi-Fi hotspot or LAN to push media directly to DashCast without pasting URLs.
@MainActor
public final class DLNAReceiverService: ObservableObject {
    public static let shared = DLNAReceiverService()

    public static let enabledDefaultsKey = "dashcast_dlna_enabled_v1"
    public static let friendlyNameDefaultsKey = "dashcast_dlna_friendly_name_v1"
    public static let deviceUUIDDefaultsKey = "dashcast_dlna_device_uuid_v1"
    public static let defaultFriendlyName = "DashCast Car Display"

    @Published public var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            defaults.set(isEnabled, forKey: Self.enabledDefaultsKey)
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }

    @Published public var friendlyName: String {
        didSet {
            let trimmed = friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? Self.defaultFriendlyName : trimmed, forKey: Self.friendlyNameDefaultsKey)
        }
    }

    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var serverURLString: String?
    @Published public private(set) var incomingQueue: [DLNAQueueItem] = []
    @Published public private(set) var activeItemID: UUID?
    @Published public private(set) var currentTransportState: DLNATransportState = .stopped
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var lastSenderAddress: String?
    @Published public private(set) var blockedByMotion: Bool = false
    @Published public private(set) var blockedByEntitlement: Bool = false
    @Published public private(set) var isMuted: Bool = false

    public let deviceUUID: String
    public let httpPort: UInt16

    private let defaults: UserDefaults
    private var parkedEvaluator: ParkedStateEvaluator
    private let entitlementChecker: @MainActor () -> Bool
    private let externalParkedChecker: @MainActor () -> Bool
    private let playbackHandler: @MainActor (ChannelModel) -> Void
    private let transportControlHandler: @MainActor (DLNATransportCommand) -> Void
    private let muteHandler: @MainActor (Bool) -> Void

    private var httpServer: DLNAHTTPServer?
    private var ssdpResponder: SSDPMulticastResponder?
    private var cancellables = Set<AnyCancellable>()

    init(
        defaults: UserDefaults = .standard,
        httpPort: UInt16 = DLNAProtocol.defaultHTTPPort,
        parkedEvaluator: ParkedStateEvaluator = ParkedStateEvaluator(),
        entitlementChecker: (@MainActor () -> Bool)? = nil,
        externalParkedChecker: (@MainActor () -> Bool)? = nil,
        playbackHandler: (@MainActor (ChannelModel) -> Void)? = nil,
        transportControlHandler: (@MainActor (DLNATransportCommand) -> Void)? = nil,
        muteHandler: (@MainActor (Bool) -> Void)? = nil,
        observeSharedController: Bool = true
    ) {
        self.defaults = defaults
        self.httpPort = httpPort
        self.parkedEvaluator = parkedEvaluator
        self.entitlementChecker = entitlementChecker ?? { EntitlementGate.shared.request(.startCasting) }
        self.externalParkedChecker = externalParkedChecker ?? {
            CarVideoOutputController.shared.canStartVideoOutput() &&
            CarVideoOutputController.shared.parkedGuard.state != .moving
        }
        self.playbackHandler = playbackHandler ?? { VideoPlayerService.shared.load(channel: $0) }
        self.transportControlHandler = transportControlHandler ?? { command in
            switch command {
            case .play:
                VideoPlayerService.shared.play()
            case .pause:
                VideoPlayerService.shared.pause()
            case .stop:
                VideoPlayerService.shared.stop()
            }
        }
        self.muteHandler = muteHandler ?? { VideoPlayerService.shared.isMuted = $0 }

        if let savedUUID = defaults.string(forKey: Self.deviceUUIDDefaultsKey), !savedUUID.isEmpty {
            self.deviceUUID = savedUUID
        } else {
            let newUUID = UUID().uuidString.lowercased()
            defaults.set(newUUID, forKey: Self.deviceUUIDDefaultsKey)
            self.deviceUUID = newUUID
        }

        let savedName = defaults.string(forKey: Self.friendlyNameDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.friendlyName = (savedName?.isEmpty == false) ? savedName! : Self.defaultFriendlyName
        self.isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)

        if observeSharedController {
            CarVideoOutputController.shared.parkedGuard.$state
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] motionState in
                    self?.handleExternalMotionChange(motionState)
                }
                .store(in: &cancellables)
        }
    }

    public var effectiveFriendlyName: String {
        let trimmed = friendlyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultFriendlyName : trimmed
    }

    public var currentLocationURL: String {
        let host = LocalNetworkAddress.preferredIPv4() ?? "127.0.0.1"
        return "http://\(host):\(httpPort)/description.xml"
    }

    public var currentBaseURL: String {
        let host = LocalNetworkAddress.preferredIPv4() ?? "127.0.0.1"
        return "http://\(host):\(httpPort)"
    }

    // MARK: - Lifecycle

    public func startIfEnabled() {
        if isEnabled {
            start()
        }
    }

    public func start() {
        guard !isListening else { return }
        lastErrorMessage = nil

        let server = DLNAHTTPServer(port: httpPort) { [weak self] method, path, headers, body, remoteAddress in
            guard let self else {
                return DLNAProtocol.httpResponse(status: "503 Service Unavailable", contentType: "text/plain", body: Data("Unavailable".utf8))
            }
            return await self.handleHTTPRequest(
                method: method,
                path: path,
                headers: headers,
                body: body,
                remoteAddress: remoteAddress
            )
        }
        server.start { [weak self] active, errorMessage in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isListening = active
                self.serverURLString = active ? self.currentLocationURL : nil
                if let errorMessage {
                    self.lastErrorMessage = errorMessage
                }
            }
        }
        self.httpServer = server

        let responder = SSDPMulticastResponder(
            deviceUUID: deviceUUID,
            locationProvider: { [weak self] in
                await MainActor.run { self?.currentLocationURL ?? "http://127.0.0.1:\(DLNAProtocol.defaultHTTPPort)/description.xml" }
            }
        )
        responder.start()
        self.ssdpResponder = responder
        self.isListening = true
        self.serverURLString = currentLocationURL
    }

    public func stop() {
        ssdpResponder?.sendByeByeAndStop()
        ssdpResponder = nil
        httpServer?.stop()
        httpServer = nil
        isListening = false
        serverURLString = nil
    }

    // MARK: - Motion / Parked Guard

    @discardableResult
    func updateMotionState(speedKmh: Double?, automotiveMoving: Bool?, at now: Date = Date()) -> VehicleMotionState {
        let state = parkedEvaluator.update(speedKmh: speedKmh, automotiveMoving: automotiveMoving, at: now)
        handleMotionState(state)
        return state
    }

    private func handleExternalMotionChange(_ state: VehicleMotionState) {
        handleMotionState(state)
    }

    private func handleMotionState(_ state: VehicleMotionState) {
        if state == .moving {
            blockedByMotion = true
            if currentTransportState == .playing {
                currentTransportState = .paused
                transportControlHandler(.pause)
            }
        } else {
            blockedByMotion = false
        }
    }

    private func isParkedAllowed() -> Bool {
        !parkedEvaluator.blocksVideo && externalParkedChecker()
    }

    // MARK: - Queue Management

    public func playQueueItem(_ item: DLNAQueueItem) {
        guard canStartPlayback() else { return }
        activeItemID = item.id
        currentTransportState = .playing
        playbackHandler(item.asChannelModel())
    }

    public func removeQueueItem(_ item: DLNAQueueItem) {
        incomingQueue.removeAll { $0.id == item.id }
        if activeItemID == item.id {
            activeItemID = nil
            currentTransportState = .stopped
            transportControlHandler(.stop)
        }
    }

    public func clearQueue() {
        incomingQueue.removeAll()
        if currentTransportState != .stopped {
            activeItemID = nil
            currentTransportState = .stopped
            transportControlHandler(.stop)
        }
    }

    // MARK: - SOAP / UPnP Request Dispatch

    @discardableResult
    public func processSOAPAction(_ action: DLNAProtocol.SOAPAction, senderAddress: String? = nil) -> Result<Void, DLNAActionFailure> {
        switch action {
        case .setAVTransportURI(let url, let title, _):
            lastSenderAddress = senderAddress
            let resolvedTitle = title ?? Self.fallbackTitle(for: url)
            let item = DLNAQueueItem(title: resolvedTitle, streamURL: url, senderAddress: senderAddress)
            enqueue(item)
            activeItemID = item.id

            guard canStartPlayback() else {
                currentTransportState = .stopped
                if blockedByMotion {
                    return .failure(.blockedWhileMoving)
                }
                return .failure(.entitlementRequired)
            }

            currentTransportState = .playing
            playbackHandler(item.asChannelModel())
            return .success(())

        case .play:
            guard canStartPlayback() else {
                if blockedByMotion {
                    return .failure(.blockedWhileMoving)
                }
                return .failure(.entitlementRequired)
            }
            if let activeID = activeItemID, let item = incomingQueue.first(where: { $0.id == activeID }) {
                currentTransportState = .playing
                playbackHandler(item.asChannelModel())
            } else {
                currentTransportState = .playing
                transportControlHandler(.play)
            }
            return .success(())

        case .pause:
            currentTransportState = .paused
            transportControlHandler(.pause)
            return .success(())

        case .stop:
            currentTransportState = .stopped
            transportControlHandler(.stop)
            return .success(())

        case .getTransportInfo, .getPositionInfo, .getMute:
            return .success(())

        case .setMute(let muted):
            isMuted = muted
            muteHandler(muted)
            return .success(())
        }
    }

    private func canStartPlayback() -> Bool {
        if !isParkedAllowed() {
            blockedByMotion = true
            lastErrorMessage = String(localized: "DLNA playback paused while the vehicle is moving.")
            return false
        }
        blockedByMotion = false

        if !entitlementChecker() {
            blockedByEntitlement = true
            lastErrorMessage = String(localized: "Free casting limit reached. Upgrade to DashCast Pro for unlimited DLNA casting.")
            return false
        }
        blockedByEntitlement = false
        lastErrorMessage = nil
        return true
    }

    private func enqueue(_ item: DLNAQueueItem) {
        incomingQueue.removeAll { $0.streamURL == item.streamURL }
        incomingQueue.insert(item, at: 0)
        if incomingQueue.count > 25 {
            incomingQueue.removeLast(incomingQueue.count - 25)
        }
    }

    private static func fallbackTitle(for url: URL) -> String {
        let candidate = url.deletingPathExtension().lastPathComponent
        if candidate.isEmpty || candidate == "/" {
            return url.host ?? "DLNA Stream"
        }
        return candidate
    }

    // MARK: - HTTP Routing

    func handleHTTPRequest(
        method: String,
        path: String,
        headers: [String: String],
        body: Data,
        remoteAddress: String?
    ) -> Data {
        if method == "GET" {
            return handleHTTPGet(path: path)
        }
        if method == "POST", path == "/upnp/AVTransport/control" || path == "/upnp/RenderingControl/control" {
            return handleSOAPControl(headers: headers, body: body, remoteAddress: remoteAddress)
        }
        return DLNAProtocol.httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
    }

    private func handleHTTPGet(path: String) -> Data {
        switch path {
        case "/", "/description.xml", "/upnp/description.xml":
            let xml = DLNAProtocol.deviceDescriptionXML(
                friendlyName: effectiveFriendlyName,
                deviceUUID: deviceUUID,
                baseURL: currentBaseURL
            )
            return DLNAProtocol.httpResponse(status: "200 OK", contentType: "text/xml; charset=\"utf-8\"", body: Data(xml.utf8))
        case "/upnp/AVTransport.xml":
            return DLNAProtocol.httpResponse(
                status: "200 OK",
                contentType: "text/xml; charset=\"utf-8\"",
                body: Data(DLNAProtocol.avTransportSCPDXML().utf8)
            )
        case "/upnp/RenderingControl.xml":
            return DLNAProtocol.httpResponse(
                status: "200 OK",
                contentType: "text/xml; charset=\"utf-8\"",
                body: Data(DLNAProtocol.renderingControlSCPDXML().utf8)
            )
        default:
            return DLNAProtocol.httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
        }
    }

    private func handleSOAPControl(headers: [String: String], body: Data, remoteAddress: String?) -> Data {
        do {
            let action = try DLNAProtocol.parseSOAPAction(body: body, soapActionHeader: headers["soapaction"])
            if case .failure(let failure) = processSOAPAction(action, senderAddress: remoteAddress) {
                return DLNAProtocol.soapFaultResponse(upnpErrorCode: 701, description: failure.localizedDescription)
            }
            return soapResponse(for: action)
        } catch let error as DLNAProtocol.SOAPParseError {
            return DLNAProtocol.soapFaultResponse(upnpErrorCode: 402, description: error.localizedDescription)
        } catch {
            return DLNAProtocol.soapFaultResponse(upnpErrorCode: 501, description: error.localizedDescription)
        }
    }

    private func soapResponse(for action: DLNAProtocol.SOAPAction) -> Data {
        switch action {
        case .setAVTransportURI:
            return DLNAProtocol.soapSuccessResponse(actionName: "SetAVTransportURI", serviceType: DLNAProtocol.avTransportServiceType)
        case .play:
            return DLNAProtocol.soapSuccessResponse(actionName: "Play", serviceType: DLNAProtocol.avTransportServiceType)
        case .pause:
            return DLNAProtocol.soapSuccessResponse(actionName: "Pause", serviceType: DLNAProtocol.avTransportServiceType)
        case .stop:
            return DLNAProtocol.soapSuccessResponse(actionName: "Stop", serviceType: DLNAProtocol.avTransportServiceType)
        case .getTransportInfo:
            let bodyXML = "<CurrentTransportState>\(currentTransportState.rawValue)</CurrentTransportState><CurrentTransportStatus>OK</CurrentTransportStatus><CurrentSpeed>1</CurrentSpeed>"
            return DLNAProtocol.soapSuccessResponse(actionName: "GetTransportInfo", serviceType: DLNAProtocol.avTransportServiceType, bodyElements: bodyXML)
        case .getPositionInfo:
            let activeURL = activeItemID.flatMap { id in incomingQueue.first(where: { $0.id == id })?.streamURL.absoluteString } ?? ""
            let bodyXML = "<Track>1</Track><TrackDuration>00:00:00</TrackDuration><TrackMetaData></TrackMetaData><TrackURI>\(DLNAProtocol.escapeXML(activeURL))</TrackURI><RelTime>00:00:00</RelTime><AbsTime>00:00:00</AbsTime>"
            return DLNAProtocol.soapSuccessResponse(actionName: "GetPositionInfo", serviceType: DLNAProtocol.avTransportServiceType, bodyElements: bodyXML)
        case .getMute:
            let muted = isMuted ? "1" : "0"
            return DLNAProtocol.soapSuccessResponse(actionName: "GetMute", serviceType: DLNAProtocol.renderingControlServiceType, bodyElements: "<CurrentMute>\(muted)</CurrentMute>")
        case .setMute:
            return DLNAProtocol.soapSuccessResponse(actionName: "SetMute", serviceType: DLNAProtocol.renderingControlServiceType)
        }
    }
}

public enum DLNAActionFailure: Error, Equatable, LocalizedError, Sendable {
    case blockedWhileMoving
    case entitlementRequired

    public var errorDescription: String? {
        switch self {
        case .blockedWhileMoving:
            return "Playback is disabled while the vehicle is moving."
        case .entitlementRequired:
            return "DashCast Pro is required after using today's free casting allowance."
        }
    }
}

// MARK: - HTTP Control & XML Server

private final class DLNAHTTPServer: @unchecked Sendable {
    typealias RequestHandler = @Sendable (_ method: String, _ path: String, _ headers: [String: String], _ body: Data, _ remoteAddress: String?) async -> Data

    private let port: UInt16
    private let handler: RequestHandler
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.dlna.http")
    private var listener: NWListener?

    init(port: UInt16, handler: @escaping RequestHandler) {
        self.port = port
        self.handler = handler
    }

    func start(onState: @escaping @Sendable (Bool, String?) -> Void) {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: parameters, on: nwPort) else {
            onState(false, "Unable to bind DLNA HTTP port \(port).")
            return
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                onState(true, nil)
            case .failed(let error):
                onState(false, error.localizedDescription)
            case .cancelled:
                onState(false, nil)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveFullHTTPRequest(on: connection, accumulated: Data())
    }

    private func receiveFullHTTPRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }

            if let parsed = Self.parseHTTPMessage(buffer) {
                let remote = Self.endpointHost(connection.endpoint)
                Task {
                    let response = await self.handler(parsed.method, parsed.path, parsed.headers, parsed.body, remote)
                    connection.send(content: response, isComplete: true, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
                return
            }

            if isComplete || error != nil || buffer.count > 262_144 {
                connection.cancel()
                return
            }

            self.receiveFullHTTPRequest(on: connection, accumulated: buffer)
        }
    }

    private static func endpointHost(_ endpoint: NWEndpoint) -> String? {
        if case .hostPort(let host, _) = endpoint {
            return "\(host)"
        }
        return nil
    }

    private struct ParsedHTTPMessage {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private static func parseHTTPMessage(_ data: Data) -> ParsedHTTPMessage? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }

        let headerData = data[..<range.lowerBound]
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0]).uppercased()
        let rawPath = String(parts[1])
        let path = rawPath.split(separator: "?").first.map(String.init) ?? "/"

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = val
        }

        let bodyStart = range.upperBound
        let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
        let availableBody = data[bodyStart...]
        guard availableBody.count >= contentLength else { return nil }

        let body = Data(availableBody.prefix(contentLength))
        return ParsedHTTPMessage(method: method, path: path, headers: headers, body: body)
    }
}

// MARK: - SSDP Multicast Responder

private final class SSDPMulticastResponder: @unchecked Sendable {
    private let deviceUUID: String
    private let locationProvider: @Sendable () async -> String
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.dlna.ssdp")

    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var announceTimer: DispatchSourceTimer?

    init(deviceUUID: String, locationProvider: @escaping @Sendable () async -> String) {
        self.deviceUUID = deviceUUID
        self.locationProvider = locationProvider
    }

    func start() {
        queue.async { [weak self] in
            self?.setupSocket()
        }
    }

    func sendByeByeAndStop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.broadcastNotify(.byebye, location: "")
            self.teardown()
        }
    }

    private func setupSocket() {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = DLNAProtocol.ssdpPort.bigEndian
        bindAddr.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

        let bindResult = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(fd)
            return
        }

        var mreq = ip_mreq()
        mreq.imr_multiaddr.s_addr = inet_addr(DLNAProtocol.ssdpMulticastHost)
        mreq.imr_interface.s_addr = INADDR_ANY.bigEndian
        setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, socklen_t(MemoryLayout<ip_mreq>.size))

        let flags = fcntl(fd, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        }

        self.socketFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleIncomingDatagram()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        self.readSource = source

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .seconds(30))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                let location = await self.locationProvider()
                self.queue.async { [weak self] in
                    self?.broadcastNotify(.alive, location: location)
                }
            }
        }
        timer.resume()
        self.announceTimer = timer
    }

    private func teardown() {
        announceTimer?.cancel()
        announceTimer = nil
        readSource?.cancel()
        readSource = nil
        socketFD = -1
    }

    private func handleIncomingDatagram() {
        guard socketFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        var senderAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let bytesRead = withUnsafeMutablePointer(to: &senderAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(socketFD, &buffer, buffer.count, 0, $0, &addrLen)
            }
        }
        guard bytesRead > 0 else { return }
        let data = Data(buffer.prefix(bytesRead))
        guard let request = DLNAProtocol.parseSSDPRequest(data) else { return }
        let targets = DLNAProtocol.searchResponseTargets(for: request.searchTarget, deviceUUID: deviceUUID)
        guard !targets.isEmpty else { return }

        let capturedAddr = senderAddr
        Task {
            let location = await locationProvider()
            self.queue.async { [weak self] in
                guard let self, self.socketFD >= 0 else { return }
                for target in targets {
                    let response = DLNAProtocol.mSearchResponse(
                        location: location,
                        searchTarget: target,
                        deviceUUID: self.deviceUUID
                    )
                    self.send(response, to: capturedAddr)
                }
            }
        }
    }

    private func broadcastNotify(_ subtype: DLNAProtocol.NotificationSubtype, location: String) {
        guard socketFD >= 0 else { return }
        var multicastAddr = sockaddr_in()
        multicastAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        multicastAddr.sin_family = sa_family_t(AF_INET)
        multicastAddr.sin_port = DLNAProtocol.ssdpPort.bigEndian
        multicastAddr.sin_addr.s_addr = inet_addr(DLNAProtocol.ssdpMulticastHost)

        for nt in DLNAProtocol.notificationTypes(deviceUUID: deviceUUID) {
            let packet = DLNAProtocol.notifyPacket(
                subtype: subtype,
                location: location,
                notificationType: nt,
                deviceUUID: deviceUUID
            )
            send(packet, to: multicastAddr)
        }
    }

    private func send(_ data: Data, to address: sockaddr_in) {
        guard socketFD >= 0 else { return }
        var addr = address
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    _ = sendto(socketFD, baseAddress, data.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}

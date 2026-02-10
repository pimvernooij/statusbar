import Foundation

actor StatusPageClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func fetchSummary(for service: MonitoredService) async -> ServiceResult {
        switch service.provider {
        case .statusPage:
            return await fetchStatusPageSummary(for: service)
        case .incidentIO:
            return await fetchIncidentIOSummary(for: service)
        }
    }

    // MARK: - StatusPage (JSON API)

    private func fetchStatusPageSummary(for service: MonitoredService) async -> ServiceResult {
        guard let url = service.apiURL else {
            return .error(service: service, message: "Invalid URL for domain: \(service.domain)")
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error(service: service, message: "Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .error(service: service, message: "HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let summary = try decoder.decode(StatusPageSummary.self, from: data)

            let components = summary.components.map { component in
                ComponentResult(
                    id: component.id,
                    name: component.name,
                    status: OverallStatus(componentStatus: component.status),
                    isGroup: component.group,
                    onlyShowIfDegraded: component.onlyShowIfDegraded
                )
            }

            return ServiceResult(
                id: service.id,
                service: service,
                status: OverallStatus(indicator: summary.status.indicator),
                statusDescription: summary.status.description,
                components: components,
                error: nil
            )
        } catch is CancellationError {
            return .error(service: service, message: "Request cancelled")
        } catch let error as URLError {
            return .error(service: service, message: error.localizedDescription)
        } catch let error as DecodingError {
            return .error(service: service, message: "Failed to parse response: \(error.localizedDescription)")
        } catch {
            return .error(service: service, message: error.localizedDescription)
        }
    }

    // MARK: - incident.io (RSS Feed)

    private func fetchIncidentIOSummary(for service: MonitoredService) async -> ServiceResult {
        guard let url = service.apiURL else {
            return .error(service: service, message: "Invalid URL for domain: \(service.domain)")
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error(service: service, message: "Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .error(service: service, message: "HTTP \(httpResponse.statusCode)")
            }

            let parser = RSSFeedParser(data: data)
            let incidents = parser.parse()

            let activeIncidents = incidents.filter { !$0.isResolved }

            if activeIncidents.isEmpty {
                return ServiceResult(
                    id: service.id,
                    service: service,
                    status: .operational,
                    statusDescription: "All Systems Operational",
                    components: [],
                    error: nil
                )
            }

            // Use the most recent active incident to derive component statuses
            let mostRecent = activeIncidents[0]
            let components = mostRecent.componentStatuses.enumerated().map { index, cs in
                ComponentResult(
                    id: "\(service.id)-\(index)",
                    name: cs.name,
                    status: cs.status,
                    isGroup: false,
                    onlyShowIfDegraded: false
                )
            }

            let worstStatus = components.map(\.status).max() ?? .degradedPerformance

            return ServiceResult(
                id: service.id,
                service: service,
                status: worstStatus,
                statusDescription: mostRecent.title,
                components: components,
                error: nil
            )
        } catch is CancellationError {
            return .error(service: service, message: "Request cancelled")
        } catch let error as URLError {
            return .error(service: service, message: error.localizedDescription)
        } catch {
            return .error(service: service, message: error.localizedDescription)
        }
    }

    func fetchAll(services: [MonitoredService]) async -> [ServiceResult] {
        await withTaskGroup(of: ServiceResult.self, returning: [ServiceResult].self) { group in
            for service in services {
                group.addTask {
                    await self.fetchSummary(for: service)
                }
            }

            var results: [ServiceResult] = []
            for await result in group {
                results.append(result)
            }

            // Sort results to match the order of input services
            return services.compactMap { service in
                results.first { $0.id == service.id }
            }
        }
    }
}

// MARK: - RSS Feed Parser

private struct RSSIncident {
    let title: String
    let pubDate: String
    let description: String
    var isResolved: Bool {
        description.localizedCaseInsensitiveContains("resolved") &&
        !description.localizedCaseInsensitiveContains("not resolved")
    }
    var componentStatuses: [RSSComponentStatus] {
        RSSFeedParser.parseComponentStatuses(from: description)
    }
}

private struct RSSComponentStatus {
    let name: String
    let status: OverallStatus
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var incidents: [RSSIncident] = []

    private var inItem = false
    private var currentElement = ""
    private var currentTitle = ""
    private var currentPubDate = ""
    private var currentDescription = ""

    init(data: Data) {
        self.data = data
    }

    func parse() -> [RSSIncident] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return incidents
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentPubDate = ""
            currentDescription = ""
        }
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "pubDate": currentPubDate += string
        case "description": currentDescription += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, currentElement == "description" else { return }
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentDescription += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" {
            let incident = RSSIncident(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            incidents.append(incident)
            inItem = false
        }
    }

    // MARK: Component Status Parsing

    /// Parses component statuses from HTML description like:
    /// `<li>API (Degraded performance)</li>`
    static func parseComponentStatuses(from html: String) -> [RSSComponentStatus] {
        // Match patterns like "ComponentName (Status)" inside <li> tags or as plain text lines
        let pattern = #"<li[^>]*>\s*(.+?)\s*\(([^)]+)\)\s*</li>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        return matches.compactMap { match in
            guard match.numberOfRanges >= 3,
                  let nameRange = Range(match.range(at: 1), in: html),
                  let statusRange = Range(match.range(at: 2), in: html) else {
                return nil
            }

            let name = String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let statusString = String(html[statusRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip any remaining HTML tags from the name
            let cleanName = name.replacingOccurrences(
                of: "<[^>]+>", with: "", options: .regularExpression
            )

            let status = mapIncidentIOStatus(statusString)
            return RSSComponentStatus(name: cleanName, status: status)
        }
    }

    private static func mapIncidentIOStatus(_ status: String) -> OverallStatus {
        switch status.lowercased() {
        case "operational": return .operational
        case "degraded performance": return .degradedPerformance
        case "partial outage": return .partialOutage
        case "full outage", "major outage": return .majorOutage
        default: return .unknown
        }
    }
}

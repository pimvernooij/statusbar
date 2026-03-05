import Foundation

actor StatusClient {
    private let session: URLSession
    private var statusIOPageIDs: [String: String] = [:]

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
        case .statusIO:
            return await fetchStatusIOSummary(for: service)
        case .cachet:
            return await fetchCachetSummary(for: service)
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

    // MARK: - incident.io (JSON API)

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

            let decoder = JSONDecoder()
            let parsed = try decoder.decode(IncidentIOResponse.self, from: data)
            let summary = parsed.summary

            // Build a lookup of affected component IDs to their status
            let affectedLookup = Dictionary(
                summary.affectedComponents.map { ($0.componentId, $0.status) },
                uniquingKeysWith: { _, last in last }
            )

            // Build components from the structure (groups with nested components)
            var components: [ComponentResult] = []
            if let structure = summary.structure {
                for item in structure.items {
                    guard let group = item.group, !group.hidden else { continue }

                    // Add the group header
                    components.append(ComponentResult(
                        id: group.id,
                        name: group.name,
                        status: .operational,
                        isGroup: true,
                        onlyShowIfDegraded: false
                    ))

                    // Add each component in the group
                    for gc in group.components where !gc.hidden {
                        let status: OverallStatus
                        if let affected = affectedLookup[gc.componentId] {
                            status = OverallStatus(incidentIOStatus: affected)
                        } else {
                            status = .operational
                        }
                        components.append(ComponentResult(
                            id: gc.componentId,
                            name: gc.name,
                            status: status,
                            isGroup: false,
                            onlyShowIfDegraded: false
                        ))
                    }
                }
            }

            // Determine overall status
            let hasIncidents = !summary.ongoingIncidents.isEmpty
            let worstComponent = components.filter { !$0.isGroup }.map(\.status).max() ?? .operational
            let overallStatus = hasIncidents ? max(worstComponent, .degradedPerformance) : worstComponent

            let description: String
            if let incident = summary.ongoingIncidents.first {
                description = incident.name
            } else {
                description = "All Systems Operational"
            }

            return ServiceResult(
                id: service.id,
                service: service,
                status: overallStatus,
                statusDescription: description,
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

    // MARK: - status.io (Public Status API)

    private func discoverStatusIOPageID(domain: String) async throws -> String {
        if let cached = statusIOPageIDs[domain] {
            return cached
        }

        guard let url = URL(string: "https://\(domain)") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Look for: var defined  = '...' or statuspageId = '...'
        guard let range = html.range(of: #"statuspageId\s*=\s*['\"]([a-f0-9]+)['\"]"#, options: .regularExpression),
              let idRange = html[range].range(of: #"[a-f0-9]{20,}"#, options: .regularExpression) else {
            throw URLError(.cannotParseResponse)
        }

        let pageID = String(html[idRange])
        statusIOPageIDs[domain] = pageID
        return pageID
    }

    private func fetchStatusIOSummary(for service: MonitoredService) async -> ServiceResult {
        do {
            let pageID = try await discoverStatusIOPageID(domain: service.domain)
            guard let url = URL(string: "https://api.status.io/1.0/status/\(pageID)") else {
                return .error(service: service, message: "Invalid status.io API URL")
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error(service: service, message: "Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .error(service: service, message: "HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let parsed = try decoder.decode(StatusIOResponse.self, from: data)
            let result = parsed.result

            // Build components: each status.io component becomes a group,
            // each container becomes a visible component under it
            var components: [ComponentResult] = []
            for component in result.status {
                // Add the component as a group header
                components.append(ComponentResult(
                    id: component.id,
                    name: component.name,
                    status: OverallStatus(statusIOCode: component.statusCode),
                    isGroup: true,
                    onlyShowIfDegraded: false
                ))

                // Add each container (region) as a child component
                for container in component.containers {
                    components.append(ComponentResult(
                        id: container.id,
                        name: container.name,
                        status: OverallStatus(statusIOCode: container.statusCode),
                        isGroup: false,
                        onlyShowIfDegraded: false
                    ))
                }
            }

            let overallStatus = OverallStatus(statusIOCode: result.statusOverall.statusCode)

            let description: String
            if let incident = result.incidents.first {
                description = incident.name
            } else if !result.maintenance.active.isEmpty {
                description = result.maintenance.active[0].name
            } else {
                description = result.statusOverall.status
            }

            return ServiceResult(
                id: service.id,
                service: service,
                status: overallStatus,
                statusDescription: description,
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

    // MARK: - Cachet (API v1)

    private func fetchCachetSummary(for service: MonitoredService) async -> ServiceResult {
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
            let parsed = try decoder.decode(CachetGroupsResponse.self, from: data)

            var components: [ComponentResult] = []
            var worstStatus: OverallStatus = .operational

            for group in parsed.data where group.visible == 1 {
                // Add group header
                components.append(ComponentResult(
                    id: String(group.id),
                    name: group.name,
                    status: .operational,
                    isGroup: true,
                    onlyShowIfDegraded: false
                ))

                // Add each enabled component in the group
                for component in group.enabledComponents where component.enabled {
                    let status = OverallStatus(cachetStatus: component.status)
                    if status > worstStatus {
                        worstStatus = status
                    }
                    components.append(ComponentResult(
                        id: String(component.id),
                        name: component.name,
                        status: status,
                        isGroup: false,
                        onlyShowIfDegraded: false
                    ))
                }
            }

            let description = worstStatus == .operational
                ? "All Systems Operational"
                : worstStatus.description

            return ServiceResult(
                id: service.id,
                service: service,
                status: worstStatus,
                statusDescription: description,
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

    // MARK: - Provider Auto-Detection

    struct DetectedService: Sendable {
        let name: String
        let provider: ServiceProvider
    }

    func detectProvider(domain: String) async throws -> DetectedService {
        // 1. Try StatusPage: GET /api/v2/summary.json
        if let url = URL(string: "https://\(domain)/api/v2/summary.json") {
            if let (data, response) = try? await session.data(from: url),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let summary = try? JSONDecoder().decode(StatusPageSummary.self, from: data) {
                return DetectedService(name: summary.page.name, provider: .statusPage)
            }
        }

        // 2. Try Cachet: GET /api/v1/components/groups
        if let url = URL(string: "https://\(domain)/api/v1/components/groups") {
            if let (data, response) = try? await session.data(from: url),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               (try? JSONDecoder().decode(CachetGroupsResponse.self, from: data)) != nil {
                let name = await fetchPageTitle(domain: domain) ?? domain
                return DetectedService(name: name, provider: .cachet)
            }
        }

        // 3. Try incident.io: GET /proxy/{domain}
        if let url = URL(string: "https://\(domain)/proxy/\(domain)") {
            if let (data, response) = try? await session.data(from: url),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let parsed = try? JSONDecoder().decode(IncidentIOResponse.self, from: data) {
                return DetectedService(name: parsed.summary.name, provider: .incidentIO)
            }
        }

        // 4. Try status.io: look for statuspageId in HTML
        if let _ = try? await discoverStatusIOPageID(domain: domain) {
            let name = await fetchPageTitle(domain: domain) ?? domain
            return DetectedService(name: name, provider: .statusIO)
        }

        throw URLError(.cannotParseResponse)
    }

    private func fetchPageTitle(domain: String) async -> String? {
        guard let url = URL(string: "https://\(domain)") else { return nil }
        guard let (data, _) = try? await session.data(from: url),
              let html = String(data: data, encoding: .utf8) else { return nil }

        // Extract <title>...</title>
        guard let titleRange = html.range(of: #"<title[^>]*>([^<]+)</title>"#, options: .regularExpression) else {
            return nil
        }
        let titleTag = String(html[titleRange])
        // Strip the tags
        let title = titleTag
            .replacingOccurrences(of: #"<title[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "</title>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Clean common suffixes like "Status", "Status Page", "- Status"
        let cleaned = title
            .replacingOccurrences(of: #"\s*[-–|·]\s*(Status|Status Page)$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+Status Page$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+Status$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
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

import Foundation

actor StatusClient {
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
                summary.affectedComponents.map { ($0.id, $0.status) },
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

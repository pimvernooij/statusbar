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

import Foundation
import os
import RedisConnection

actor Timeit {
    @TaskLocal
    static var shared = Timeit()

    private var starts: [String: CFAbsoluteTime] = [:]

    nonisolated
    func start(_ label: String) {
        let current = CFAbsoluteTimeGetCurrent()
        Task {
            await update(label: label, start: current)
        }
    }

    func finish(_ label: String) {
        let current = CFAbsoluteTimeGetCurrent()
        guard let start = starts[label] else {
            return
        }
        starts[label] = nil

        let s = FloatingPointFormatStyle().format(current - start)
        print("⌛ \(label): \(s)")
    }

    private func update(label: String, start: CFAbsoluteTime) {
        starts[label] = start
    }
}

func log(_ connection: RedisConnection, _ values: Any...) {
    let message = values.map(String.init(describing:)).joined(separator: " ")
    print("\(connection.label ?? "-"): \(message)")
}

extension Task where Success == () {
    func wait() async throws {
        try await value
    }
}

import Foundation
import HTML

private let isoDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [ .withYear, .withMonth, .withDay, .withDashSeparatorInDate ]
    formatter.timeZone = .current
    return formatter
}()

func format(_ date: Date) -> Node {
    time(datetime: isoDateFormatter.string(from: date)) {
        isoDateFormatter.string(from: date)
    }
}

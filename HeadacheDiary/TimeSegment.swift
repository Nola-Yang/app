import Foundation

struct TimeSegment: Codable, Identifiable, Hashable {
    let id: UUID
    var start: Date
    var end: Date?

    init(id: UUID = UUID(), start: Date, end: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
    }
}

extension HeadacheRecord {
    var timeSegments: [TimeSegment] {
        get {
            guard let data = timeSegmentsData else {
                if let start = startTime {
                    let segment = TimeSegment(start: start, end: endTime)
                    return [segment]
                }
                return []
            }
            do {
                return try JSONDecoder().decode([TimeSegment].self, from: data)
            } catch {
                print("❌ Decode timeSegments failed: \(error)")
                return []
            }
        }
        set {
            do {
                timeSegmentsData = try JSONEncoder().encode(newValue)
                startTime = newValue.map { $0.start }.min()
                endTime = newValue.compactMap { $0.end }.max()
            } catch {
                print("❌ Encode timeSegments failed: \(error)")
                timeSegmentsData = nil
            }
        }
    }

    func addTimeSegment(_ segment: TimeSegment) {
        var segments = timeSegments
        segments.append(segment)
        segments.sort { $0.start < $1.start }
        timeSegments = segments
    }
}

import Foundation
import CoreGraphics

enum EventConstants {
    static let syntheticEventMarker: Int64 = 0x4D43524654
}

struct MouseEventSample {
    let type: CGEventType
    let buttonNumber: Int?
    let deltaY: Int32
    let timestamp: UInt64
    let sourceUserData: Int64

    var isSynthetic: Bool {
        sourceUserData == EventConstants.syntheticEventMarker
    }
}

enum EventProcessingDecision: Equatable {
    case passThrough
    case suppressOriginal
}

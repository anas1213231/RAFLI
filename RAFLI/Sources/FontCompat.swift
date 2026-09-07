import SwiftUI

// Compatibility helper for the fluent `.title2.black()` style used by the RAFLI UI.
extension Font {
    func black() -> Font {
        self.weight(.black)
    }
}

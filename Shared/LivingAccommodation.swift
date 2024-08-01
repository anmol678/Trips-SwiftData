/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The model class of a living accommodation.
*/

import Foundation
import SwiftData

@Model class LivingAccommodation {
    var address: String
    var name: String
    var isConfirmed: Bool = false
    var trip: Trip?

    init(address: String, name: String, isConfirmed: Bool) {
        self.address = address
        self.name = name
        self.isConfirmed = isConfirmed
    }
}

extension LivingAccommodation {
    var displayAddress: String {
        address.isEmpty ? "No Address" : address
    }

    var displayPlaceName: String {
        name.isEmpty ? "No Place" : name
    }
    
    static var preview: [LivingAccommodation] {
        [.init(address: "Yosemite National Park, CA 95389", name: "Yosemite", isConfirmed: true)]
    }
}

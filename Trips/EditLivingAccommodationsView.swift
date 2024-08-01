/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A SwiftUI view that edits living accommodations.
*/

import SwiftUI
import WidgetKit
import SwiftData

struct EditLivingAccommodationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var isConfirmed = false
    
    var trip: Trip
    
    var body: some View {
        TripForm {
            Section(header: Text("Name of Living Accommodation")) {
                TripGroupBox {
                    TextField(namePlaceholder, text: $name)
                }
            }
            
            Section(header: Text("Address of Living Accommodation")) {
                TripGroupBox {
                    TextField(addressPlaceholder, text: $address)
                }
            }
            
            Section(header: Text("Confirmation")) {
                TripGroupBox {
                    Toggle(isOn: $isConfirmed) {
                        Text("Get confirmed")
                    }
                }
            }
        }
        .background(Color.tripGray)
        .navigationTitle("Edit Living Accommodations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    addLiving()
                    dismiss()
                }
                .disabled(name.isEmpty || address.isEmpty)
            }
        }
        .onAppear {
            name = trip.livingAccommodation?.name ?? ""
            address = trip.livingAccommodation?.address ?? ""
            isConfirmed = trip.livingAccommodation?.isConfirmed ?? false
        }
    }

    var namePlaceholder: String {
        trip.livingAccommodation?.name ?? "Enter place name here…"
    }
    
    var addressPlaceholder: String {
        trip.livingAccommodation?.address ?? "Enter address here…"
    }
    
    private func addLiving() {
        withAnimation {
            if let livingAccommodation = trip.livingAccommodation {
                livingAccommodation.address = address
                livingAccommodation.name = name
                livingAccommodation.isConfirmed = isConfirmed
            } else {
                let newLivingAccommodation = LivingAccommodation(address: address,
                                                                 name: name,
                                                                 isConfirmed: isConfirmed)
                newLivingAccommodation.trip = trip
            }
            /**
             Save the context immediately to make sure that the widget gets the latest data.
             */
            do {
                try modelContext.save()
            } catch {
                print("Failed to save model context: \(error)")
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "TripsWidget")
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var trips: [Trip]
    EditLivingAccommodationsView(trip: trips.first!)
}

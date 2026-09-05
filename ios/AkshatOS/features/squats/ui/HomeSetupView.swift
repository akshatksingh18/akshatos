import MapKit
import SwiftUI

struct HomeSetupView: View {
    @EnvironmentObject private var store: SquatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let boundary = store.homeDraft {
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: boundary.latitude,
                                                           longitude: boundary.longitude),
                            latitudinalMeters: max(500, boundary.radius * 3),
                            longitudinalMeters: max(500, boundary.radius * 3)))) {
                            Marker("Home", coordinate: CLLocationCoordinate2D(
                                latitude: boundary.latitude, longitude: boundary.longitude))
                            MapCircle(center: CLLocationCoordinate2D(latitude: boundary.latitude,
                                longitude: boundary.longitude), radius: boundary.radius)
                                .foregroundStyle(.green.opacity(0.22))
                        }.frame(height: 280).clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Map showing the chosen Home boundary")
                            .accessibilityValue("Radius \(Int(boundary.radius)) meters")
                        Stepper("Radius: \(Int(boundary.radius)) m",
                                value: Binding(get: { boundary.radius },
                                    set: { store.updateHomeDraftRadius($0) }),
                                in: HomeBoundary.allowedRadius, step: 25)
                            .accessibilityIdentifier("home-radius-stepper")
                    } else {
                        ContentUnavailableView("Location unavailable", systemImage: "location.slash")
                    }
                } header: { Text("Confirm the Home boundary") }
                footer: {
                    Text("After confirmation, iOS will ask for Always access so the single boundary can work while AkshatOS is closed. The coordinate and radius stay protected on this device and are excluded from Squats backups.")
                }
            }.navigationTitle("Home auto-pause")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { store.cancelHomeDraft(); dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            Task { await store.confirmHome(); dismiss() }
                        }.disabled(store.homeDraft == nil || store.busy)
                    }
                }
        }.tint(Palette.lime)
    }
}

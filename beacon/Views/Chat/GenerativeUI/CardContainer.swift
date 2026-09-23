#if os(iOS)
import CoreLocation
import MapKit
import SwiftUI

struct NearbySpot: Identifiable {
	let id = UUID()
	let name: String
	let detail: String
	let category: String
	let color: Color
	let coordinate: CLLocationCoordinate2D
}

struct CardContainer: View {
	let title: String
	let spots: [NearbySpot]

	var body: some View {
		VStack(alignment: .leading, spacing: 22) {
			Text(title)
				.font(.beaconFont(size: 24, weight: .bold))
				.foregroundStyle(.primary)
				.lineSpacing(-2)

			VStack(spacing: 16) {
				ForEach(spots) { spot in
					spotRow(spot)
				}
			}
		}
		.padding(24)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
	}

	private func spotRow(_ spot: NearbySpot) -> some View {
		HStack(spacing: 14) {
			VStack(alignment: .leading, spacing: 3) {
				Text(spot.name)
					.font(.beaconFont(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(spot.detail)")
                        .font(.beaconFont(size: 16))
                        .foregroundStyle(.secondary)

                    Text("\(spot.category)")
                        .font(.beaconFont(size: 16))
                        .foregroundStyle(.secondary)
                }
			}

			Spacer(minLength: 8)

			Button {
				openInMaps(spot)
			} label: {
				Text("Open in Maps")
					.font(.beaconFont(size: 16, weight: .medium))
			}
				.foregroundStyle(.primary)
				.padding(.horizontal, 18)
				.frame(minHeight: 42)
				.background(Color(uiColor: .systemGray6), in: Capsule())
				.buttonStyle(.plain)
				.accessibilityLabel("Open \(spot.name) in Apple Maps")
		}
	}

	private func openInMaps(_ spot: NearbySpot) {
		let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
		item.name = spot.name
		item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
	}
}

#Preview {
	CardContainer(
		title: "Find the best spots\nin Portland",
		spots: [
			NearbySpot(name: "Rangoon Bistro", detail: "Open until 10pm", category: "Restaurant", color: .indigo, coordinate: CLLocationCoordinate2D(latitude: 45.5231, longitude: -122.6765)),
			NearbySpot(name: "Lovejoy Bakery", detail: "Open until 5pm", category: "Bakery", color: .brown, coordinate: CLLocationCoordinate2D(latitude: 45.5298, longitude: -122.6848)),
			NearbySpot(name: "Wallflower Coffee Co", detail: "Open until 11pm", category: "Cafe", color: .orange, coordinate: CLLocationCoordinate2D(latitude: 45.5254, longitude: -122.6812))
		]
	)
	.padding()
	.background(Color(uiColor: .systemGray6).opacity(0.5))
}
#endif

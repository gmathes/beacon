//
//  ARView.swift
//  beacon
//
//  Created by Gavin Mathes on 2/20/23.
//

import SwiftUI
import RealityKit
import ARKit
import MapKit
import CoreLocation

struct ARPinView: View {
    @Binding var destinationLocation: CLLocationCoordinate2D
    @StateObject private var locationDelegate = LocationDelegate()
    @State private var isLoading = true

    var body: some View {
        #if targetEnvironment(simulator)
        VStack {
            Spacer()
            Text("AR View requires a physical device")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
            Text("ARKit is not available in the simulator")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        #else
        ZStack {
            ARViewContainer(pinPosition: $locationDelegate.pinPosition, destinationLocation: destinationLocation)
                .edgesIgnoringSafeArea(.all)

            // AR Overlay with distance and bearing info - fixed at top
            VStack {
                if locationDelegate.distance > 0 {
                    VStack(spacing: 4) {
                        Text(formatDistance(locationDelegate.distance))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(distanceColor(locationDelegate.distance))
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        Text("\(Int(locationDelegate.bearing))° \(bearingToDirection(locationDelegate.bearing))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        Text(distanceLabel(locationDelegate.distance))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        // Show warning if compass accuracy is poor
                        if locationDelegate.headingAccuracy < 0 {
                            Text("⚠️ Compass Invalid")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.red)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                        } else if locationDelegate.headingAccuracy > 20 {
                            Text("⚠️ Poor Compass - Go Outdoors")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.orange)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.top, 60)
                }

                Spacer()
            }

            // Loading screen
            if isLoading {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Initializing AR Session...")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("Point your camera around to track your environment")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
        .onAppear {
            locationDelegate.destinationLocation = destinationLocation
            locationDelegate.startTracking()

            // Hide loading screen after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isLoading = false
                }
            }
        }
        .onDisappear {
            locationDelegate.stopTracking()
        }
        #endif
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }

    private func bearingToDirection(_ bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }

    private func distanceColor(_ distance: Double) -> Color {
        if distance < 100 {
            return .green  // Very close
        } else if distance < 500 {
            return .yellow  // Close
        } else if distance < 1000 {
            return .orange  // Medium
        } else {
            return .red  // Far
        }
    }

    private func distanceLabel(_ distance: Double) -> String {
        if distance < 100 {
            return "Very Close"
        } else if distance < 500 {
            return "Close"
        } else if distance < 1000 {
            return "Medium Distance"
        } else {
            return "Far"
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var pinPosition: SIMD3<Float>
    let destinationLocation: CLLocationCoordinate2D

    class Coordinator: NSObject {
        var parent: ARViewContainer

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session for better heading tracking
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading  // ARKit handles heading
        configuration.planeDetection = []
        arView.session.run(configuration)

        print("🔵 AR Session started with worldAlignment=.gravityAndHeading")
        print("🔵 Note: ARKit will use its own heading tracking, not device compass")

        // add pin node to scene
        let pinNode = makePinNode()
        arView.scene.addAnchor(pinNode)
        print("🔵 Pin node created and added to scene")
        print("🔵 Initial pin position: \(pinPosition)")

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // update position of pin node
        if !uiView.scene.anchors.isEmpty {
            let anchor = uiView.scene.anchors[0]
            anchor.transform.translation = pinPosition
            print("🔵 Pin position updated to: x=\(pinPosition.x), y=\(pinPosition.y), z=\(pinPosition.z)")
        } else {
            print("🔴 No anchors in scene!")
        }
    }
    
    private func makePinNode() -> AnchorEntity {
        let pinNode = AnchorEntity()

        // Create a tall pin shape - like a map pin
        // Top sphere (pin head)
        let pinHead = MeshResource.generateSphere(radius: 1.5)
        let headMaterial = SimpleMaterial(color: .systemCyan, roughness: 0.15, isMetallic: false)
        let pinHeadModel = ModelEntity(mesh: pinHead, materials: [headMaterial])
        pinHeadModel.position = SIMD3<Float>(0, 3, 0)  // Top of the pin

        // Pin shaft (long cylinder pointing down)
        let shaft = MeshResource.generateCylinder(height: 6.0, radius: 0.3)
        let shaftMaterial = SimpleMaterial(color: .systemCyan, roughness: 0.15, isMetallic: false)
        let shaftModel = ModelEntity(mesh: shaft, materials: [shaftMaterial])
        shaftModel.position = SIMD3<Float>(0, 0, 0)

        // Pin point (small cone at bottom)
        let point = MeshResource.generateCone(height: 2.0, radius: 0.4)
        let pointMaterial = SimpleMaterial(color: .systemCyan, roughness: 0.15, isMetallic: false)
        let pointModel = ModelEntity(mesh: point, materials: [pointMaterial])
        pointModel.position = SIMD3<Float>(0, -4, 0)

        // Glow ring around the pin head for visibility
        let glowRing = MeshResource.generateBox(size: [4.0, 4.0, 0.2])
        let glowMaterial = SimpleMaterial(color: .systemCyan.withAlphaComponent(0.7), roughness: 0.1, isMetallic: false)
        let glowModel = ModelEntity(mesh: glowRing, materials: [glowMaterial])
        glowModel.position = SIMD3<Float>(0, 3, 0)  // At pin head level

        pinNode.addChild(pinHeadModel)
        pinNode.addChild(shaftModel)
        pinNode.addChild(pointModel)
        pinNode.addChild(glowModel)

        return pinNode
    }
}

class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pinPosition: SIMD3<Float> = SIMD3<Float>(0, 0, -50)  // Start 50m in front
    @Published var distance: Double = 0
    @Published var bearing: Double = 0
    @Published var headingAccuracy: Double = 0

    private let locationManager = CLLocationManager()
    var destinationLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    private var currentHeading: Double = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 1  // Update only when heading changes by 1 degree
        print("🔵 LocationDelegate initialized - beacon at (0, 0, -50)")
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        print("🔵 Started tracking - destination: \(destinationLocation.latitude), \(destinationLocation.longitude)")

        // If we already have location, update immediately
        if let location = locationManager.location {
            print("🔵 Initial location available")
            updatePinPosition(userLocation: location)
        }
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        updatePinPosition(userLocation: userLocation)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        headingAccuracy = newHeading.headingAccuracy

        print("🔵 Heading: \(Int(currentHeading))°, Accuracy: \(Int(newHeading.headingAccuracy))° \(newHeading.headingAccuracy < 0 ? "(INVALID)" : newHeading.headingAccuracy > 20 ? "(POOR)" : "(GOOD)")")

        if let userLocation = locationManager.location {
            updatePinPosition(userLocation: userLocation)
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        print("🔵 Compass calibration requested")
        return true  // Show calibration screen if needed
    }

    private func updatePinPosition(userLocation: CLLocation) {
        let destinationCLLocation = CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)
        let distanceMeters = userLocation.distance(from: destinationCLLocation)

        // Update published values
        self.distance = distanceMeters
        self.bearing = angleHeading(start: userLocation.coordinate, end: destinationLocation)

        // Position the pin in the AR world based on the true bearing.
        // The AR world is aligned with the real world's compass, so we use the
        // bearing directly.
        let bearingRadians = Float(bearing * .pi / 180)

        // FIXED DISTANCE: Place beacon at a constant visible distance on the horizon
        // Far enough to be stable with phone movement, close enough to be visible
        let fixedDistance: Float = 50.0  // 50 meters in AR space - visible but stable

        // Position pin on horizon at eye level
        // ARKit coordinate system with .gravityAndHeading:
        // - X: positive is EAST
        // - Y: positive is UP
        // - Z: positive is SOUTH (negative is NORTH)
        //
        // Bearing: 0° = North, 90° = East, 180° = South, 270° = West
        //
        // For bearing = 0° (North): x=0, z=-50
        // For bearing = 90° (East):  x=50, z=0
        // For bearing = 180° (South): x=0, z=50
        // For bearing = 270° (West): x=-50, z=0
        let x = fixedDistance * sin(bearingRadians)
        let z = -fixedDistance * cos(bearingRadians)
        let y: Float = 0  // Eye level

        pinPosition = SIMD3<Float>(x, y, z)

        // The relative bearing is still useful for UI display
        let relativeBearing = bearing - currentHeading

        print("🔵 Updated beacon: distance=\(Int(distanceMeters))m, bearing=\(Int(bearing))°, heading=\(Int(currentHeading))°, relative=\(Int(relativeBearing))°")
        print("🔵 AR position: x=\(String(format: "%.2f", x)), y=\(String(format: "%.2f", y)), z=\(String(format: "%.2f", z))")

        // Debug: show what direction this should be
        let direction: String
        if relativeBearing >= -22.5 && relativeBearing < 22.5 {
            direction = "AHEAD"
        } else if relativeBearing >= 22.5 && relativeBearing < 67.5 {
            direction = "AHEAD-RIGHT"
        } else if relativeBearing >= 67.5 && relativeBearing < 112.5 {
            direction = "RIGHT"
        } else if relativeBearing >= 112.5 && relativeBearing < 157.5 {
            direction = "BEHIND-RIGHT"
        } else if relativeBearing >= 157.5 || relativeBearing < -157.5 {
            direction = "BEHIND"
        } else if relativeBearing >= -157.5 && relativeBearing < -112.5 {
            direction = "BEHIND-LEFT"
        } else if relativeBearing >= -112.5 && relativeBearing < -67.5 {
            direction = "LEFT"
        } else {
            direction = "AHEAD-LEFT"
        }
        print("🔵 Beacon should be: \(direction)")
    }
}

func angleHeading(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> Double {
    let startLat = start.latitude * Double.pi / 180
    let startLon = start.longitude * Double.pi / 180
    let endLat = end.latitude * Double.pi / 180
    let endLon = end.longitude * Double.pi / 180
    
    let y = sin(endLon - startLon) * cos(endLat)
    let x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(endLon - startLon)
    let radians = atan2(y, x)
    let degrees = radians * 180 / Double.pi
    
    return (degrees + 360).truncatingRemainder(dividingBy: 360)
}


//struct ARView_Previews: PreviewProvider {
//    static var previews: some View {
//        ARPinView(destinationLocation: CLLocationCoordinate2D())
//    }
//}

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

            // AR Overlay with distance and bearing info
            VStack {
                VStack(spacing: 4) {
                    if locationDelegate.distance > 0 {
                        Text(formatDistance(locationDelegate.distance))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(distanceColor(locationDelegate.distance))
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        Text("\(Int(locationDelegate.bearing))° \(bearingToDirection(locationDelegate.bearing))")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        Text(distanceLabel(locationDelegate.distance))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .padding(.top, 60)

                Spacer()
            }
        }
        .onAppear {
            locationDelegate.destinationLocation = destinationLocation
            locationDelegate.startTracking()
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

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        arView.session.run(configuration)

        // add pin node to scene
        let pinNode = makePinNode()
        arView.scene.addAnchor(pinNode)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // update position of pin node
        if !uiView.scene.anchors.isEmpty {
            uiView.scene.anchors[0].transform.translation = pinPosition
        }
    }
    
    private func makePinNode() -> AnchorEntity {
        let pinNode = AnchorEntity()

        // Create main sphere (larger and more visible)
        let sphere = MeshResource.generateSphere(radius: 0.15)
        let material = SimpleMaterial(color: .systemPink, roughness: 0.3, isMetallic: true)
        let sphereModel = ModelEntity(mesh: sphere, materials: [material])

        // Create a cone pointing down
        let cone = MeshResource.generateCone(height: 0.3, radius: 0.1)
        let coneMaterial = SimpleMaterial(color: .systemPink, roughness: 0.3, isMetallic: true)
        let coneModel = ModelEntity(mesh: cone, materials: [coneMaterial])
        coneModel.position = SIMD3<Float>(0, -0.225, 0)  // Position below sphere

        // Create outer glow ring
        let torus = MeshResource.generateBox(size: [0.4, 0.4, 0.02])
        let glowMaterial = SimpleMaterial(color: .systemYellow.withAlphaComponent(0.5), roughness: 0.1, isMetallic: false)
        let glowModel = ModelEntity(mesh: torus, materials: [glowMaterial])

        pinNode.addChild(sphereModel)
        pinNode.addChild(coneModel)
        pinNode.addChild(glowModel)

        return pinNode
    }
}

class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pinPosition: SIMD3<Float> = .zero
    @Published var distance: Double = 0
    @Published var bearing: Double = 0

    private let locationManager = CLLocationManager()
    var destinationLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    private var currentHeading: Double = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
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
        if let userLocation = locationManager.location {
            updatePinPosition(userLocation: userLocation)
        }
    }

    private func updatePinPosition(userLocation: CLLocation) {
        let destinationCLLocation = CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)
        let distanceMeters = userLocation.distance(from: destinationCLLocation)

        // Update published values
        self.distance = distanceMeters
        self.bearing = angleHeading(start: userLocation.coordinate, end: destinationLocation)

        // Calculate bearing from user to destination
        let bearing = angleHeading(start: userLocation.coordinate, end: destinationLocation)

        // Adjust bearing relative to device heading (so pin stays in correct compass direction)
        let relativeBearing = bearing - currentHeading
        let radians = Float(relativeBearing * .pi / 180)

        // Scale distance based on actual distance (closer = closer in AR, farther = fixed far distance)
        // Distance ranges: <100m = very close, 100-500m = close, 500-1000m = medium, >1000m = far
        let scaledDistance: Float
        if distanceMeters < 100 {
            scaledDistance = Float(distanceMeters) / 5  // Scale 0-100m to 0-20 units
        } else if distanceMeters < 500 {
            scaledDistance = 20 + Float(distanceMeters - 100) / 20  // Scale 100-500m to 20-40 units
        } else if distanceMeters < 1000 {
            scaledDistance = 40 + Float(distanceMeters - 500) / 25  // Scale 500-1000m to 40-60 units
        } else {
            scaledDistance = 60 + min(Float(distanceMeters - 1000) / 100, 40)  // Scale >1000m to 60-100 units max
        }

        // Position pin on horizon at eye level
        // x/z form the horizontal plane, y is vertical
        let x = scaledDistance * sin(radians)
        let z = -scaledDistance * cos(radians)  // negative z is forward in AR
        let y: Float = 0  // Eye level

        pinPosition = SIMD3<Float>(x, y, z)
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

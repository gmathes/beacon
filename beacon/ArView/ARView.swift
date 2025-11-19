import SwiftUI
import RealityKit
import ARKit
import MapKit
import CoreLocation

// MARK: - ARSessionManager
class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var errorMessage: String?

    let session = ARSession()

    override init() {
        super.init()
        session.delegate = self
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            self.trackingState = camera.trackingState
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "AR Session Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - ARPinView
struct ARPinView: View {
    @Binding var destinationLocation: CLLocationCoordinate2D
    @StateObject private var locationDelegate = LocationDelegate()
    @StateObject private var arSessionManager = ARSessionManager()
    @State private var showErrorAlert = false

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
            ARViewContainer(
                pinPosition: $locationDelegate.pinPosition,
                destinationLocation: destinationLocation,
                arSessionManager: arSessionManager
            )
            .edgesIgnoringSafeArea(.all)

            // AR Overlay with distance and bearing info
            VStack {
                if locationDelegate.distance > 0 {
                    arInfoOverlay
                }
                Spacer()
            }

            // Loading/Status screen
            if arSessionManager.trackingState != .normal {
                arStatusView
            }
        }
        .onAppear {
            locationDelegate.destinationLocation = destinationLocation
            locationDelegate.onError = { error in
                arSessionManager.errorMessage = error.localizedDescription
            }
            locationDelegate.startTracking()
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravityAndHeading
            arSessionManager.session.run(configuration)
        }
        .onDisappear {
            locationDelegate.stopTracking()
            arSessionManager.session.pause()
        }
        .onChange(of: arSessionManager.errorMessage) { _, newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                arSessionManager.errorMessage = nil
            }
        } message: {
            Text(arSessionManager.errorMessage ?? "An unknown error occurred.")
        }
        #endif
    }

    private var arInfoOverlay: some View {
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

    private var arStatusView: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                switch arSessionManager.trackingState {
                case .notAvailable:
                    Text("AR Session Not Available")
                case .limited(let reason):
                    Text("AR Session Limited")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    switch reason {
                    case .excessiveMotion:
                        Text("Move your device more slowly.")
                    case .insufficientFeatures:
                        Text("Point your device at a well-lit area with more details.")
                    case .initializing:
                         Text("Point your camera around to help the AR session initialize")
                    case .relocalizing:
                        Text("Relocalizing AR session...")
                    @unknown default:
                        Text("An unknown tracking error occurred.")
                    }
                case .normal:
                    EmptyView()
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }

    // Helper functions for formatting
    private func formatDistance(_ distance: Double) -> String {
        let feet = distance * 3.28084 // Convert meters to feet

        if feet < 1000 {
            return "\(Int(feet))ft"
        } else {
            let miles = feet / 5280 // Convert feet to miles
            return String(format: "%.1fmi", miles)
        }
    }

    private func bearingToDirection(_ bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }

    private func distanceColor(_ distance: Double) -> Color {
        if distance < 100 {
            return .green
        } else if distance < 500 {
            return .yellow
        } else if distance < 1000 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func distanceLabel(_ distance: Double) -> String {
        let feet = distance * 3.28084 // Convert meters to feet
        if feet < 300 {
            return "Very Close"
        } else if feet < 1500 {
            return "Close"
        } else if feet < 3000 {
            return "Medium Distance"
        } else {
            return "Far"
        }
    }
}


// MARK: - ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    @Binding var pinPosition: SIMD3<Float>
    let destinationLocation: CLLocationCoordinate2D
    @ObservedObject var arSessionManager: ARSessionManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arSessionManager.session
        arView.session.delegate = arSessionManager

        let pinNode = makePinNode()
        arView.scene.addAnchor(pinNode)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if let anchor = uiView.scene.anchors.first {
            anchor.transform.translation = pinPosition
        }
    }
    
    private func makePinNode() -> AnchorEntity {
        let pinNode = AnchorEntity()

        // Create a flag shape
        // Flagpole (tall, thin cylinder)
        let pole = MeshResource.generateCylinder(height: 10.0, radius: 0.2)
        let poleMaterial = SimpleMaterial(color: .systemGray, roughness: 0.3, isMetallic: true)
        let poleModel = ModelEntity(mesh: pole, materials: [poleMaterial])
        poleModel.position = SIMD3<Float>(0, 0, 0)

        // Flag (thin box)
        let flag = MeshResource.generateBox(size: [5.0, 3.0, 0.1])
        let flagMaterial = SimpleMaterial(color: .systemRed, roughness: 0.1, isMetallic: false)
        let flagModel = ModelEntity(mesh: flag, materials: [flagMaterial])
        flagModel.position = SIMD3<Float>(2.5, 3.5, 0) // Positioned at the top of the pole

        pinNode.addChild(poleModel)
        pinNode.addChild(flagModel)

        return pinNode
    }
}

// MARK: - LocationDelegate
class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pinPosition: SIMD3<Float> = SIMD3<Float>(0, 0, -50)
    @Published var distance: Double = 0
    @Published var bearing: Double = 0
    @Published var headingAccuracy: Double = 0

    private let locationManager = CLLocationManager()
    var destinationLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    private var currentHeading: Double = 0
    var onError: ((Error) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 1
    }

    func startTracking() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        if let location = locationManager.location {
            updatePinPosition(userLocation: location)
        }
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        updatePinPosition(userLocation: userLocation)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        headingAccuracy = newHeading.headingAccuracy

        if let userLocation = locationManager.location {
            updatePinPosition(userLocation: userLocation)
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }

    private func updatePinPosition(userLocation: CLLocation) {
        let destinationCLLocation = CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)
        let distanceMeters = userLocation.distance(from: destinationCLLocation)

        self.distance = distanceMeters
        self.bearing = angleHeading(start: userLocation.coordinate, end: destinationLocation)
        
        let bearingRadians = Float(bearing * .pi / 180)
        let fixedDistance: Float = 50.0

        let x = fixedDistance * sin(bearingRadians)
        let z = -fixedDistance * cos(bearingRadians)
        let y: Float = 0

        pinPosition = SIMD3<Float>(x, y, z)
    }
}

// MARK: - Helper Functions
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

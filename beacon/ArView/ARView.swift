import SwiftUI
import RealityKit
import ARKit
import MapKit
import CoreLocation
import Combine

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

            // AR Overlay
            VStack(spacing: 0) {
                // Compass Ribbon at top
                CompassRibbon(heading: locationDelegate.currentHeading)
                    .padding(.top, 50)
                
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
            
            // Enable occlusion if supported
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                configuration.frameSemantics.insert(.personSegmentationWithDepth)
            }
            
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

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(locationDelegate.bearing))° \(bearingToDirection(locationDelegate.bearing))")
                    .font(.system(size: 16, weight: .medium))
                
                Text(String(format: "(Mag: %+.1f°)", locationDelegate.magneticDeclination))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
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


// MARK: - CompassRibbon
struct CompassRibbon: View {
    let heading: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let segmentWidth: CGFloat = 2.0 // Pixels per degree
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 44)
                
                // Markers
                HStack(spacing: 0) {
                    // Render markers for -180 to 540 to handle wrapping
                    ForEach(-180..<540, id: \.self) { degree in
                        if degree % 5 == 0 {
                            VStack(spacing: 2) {
                                Rectangle()
                                    .fill(Color.white.opacity(degree % 15 == 0 ? 0.9 : 0.4))
                                    .frame(width: 1, height: degree % 45 == 0 ? 16 : 8)
                                
                                if degree % 45 == 0 {
                                    Text(markerLabel((degree + 360) % 360))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: segmentWidth * 5)
                        }
                    }
                }
                // Center the current heading
                .offset(x: (width / 2) - (CGFloat(heading) * segmentWidth))
                
                // Center pointer
                VStack(spacing: 0) {
                    Image(systemName: "triangle.fill")
                        .resizable()
                        .frame(width: 12, height: 8)
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(180))
                    Spacer()
                }
                .frame(height: 44)
                .padding(.top, 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
    }
    
    private func markerLabel(_ degree: Int) -> String {
        switch degree {
        case 0: return "N"
        case 45: return "NE"
        case 90: return "E"
        case 135: return "SE"
        case 180: return "S"
        case 225: return "SW"
        case 270: return "W"
        case 315: return "NW"
        default: return "\(degree)°"
        }
    }
}

// MARK: - ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    @Binding var pinPosition: SIMD3<Float>
    let destinationLocation: CLLocationCoordinate2D
    @ObservedObject var arSessionManager: ARSessionManager

    class Coordinator {
        var subscription: AnyCancellable?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = arSessionManager.session
        arView.session.delegate = arSessionManager

        let pinNode = makePinNode()
        arView.scene.addAnchor(pinNode)

        // Subscribe to scene updates to update the billboard effect every frame
        let subscription = arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            self.updateFlagOrientation(in: arView)
        }
        context.coordinator.subscription = AnyCancellable(subscription)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if let anchor = uiView.scene.anchors.first {
            anchor.transform.translation = pinPosition
        }
    }
    
    private func updateFlagOrientation(in arView: ARView) {
        guard let anchor = arView.scene.anchors.first else { return }
        
        // Billboard effect: Make the flag face the camera
        let cameraPosition = arView.cameraTransform.translation
        let anchorPosition = anchor.transform.translation
        
        // To keep the pole vertical, we only rotate around the Y axis.
        var targetPosition = cameraPosition
        targetPosition.y = anchorPosition.y
        
        // look(at:) points the -Z axis of the entity at the target.
        anchor.look(at: targetPosition, from: anchorPosition, relativeTo: nil)
        
        // Pulsing animation for the flag
        if let flagModel = anchor.findEntity(named: "flag") {
            let time = Float(Date().timeIntervalSince1970)
            let scale = 1.0 + 0.1 * sin(time * 3.0) // Pulse between 0.9 and 1.1
            flagModel.scale = SIMD3<Float>(repeating: scale)
        }
    }
    
    private func makePinNode() -> AnchorEntity {
        let pinNode = AnchorEntity()

        // Create a flag shape
        // Flagpole (tall, thin cylinder)
        let pole = MeshResource.generateCylinder(height: 20.0, radius: 0.2)
        let poleMaterial = SimpleMaterial(color: .systemGray, roughness: 0.3, isMetallic: true)
        let poleModel = ModelEntity(mesh: pole, materials: [poleMaterial])
        poleModel.position = SIMD3<Float>(0, 10, 0) // Adjusted to start from ground

        // Flag (thin box)
        let flag = MeshResource.generateBox(size: [5.0, 3.0, 0.1])
        let flagMaterial = SimpleMaterial(color: .systemRed, roughness: 0.1, isMetallic: false)
        let flagModel = ModelEntity(mesh: flag, materials: [flagMaterial])
        flagModel.position = SIMD3<Float>(2.5, 18.5, 0) // Positioned at the top of the pole
        flagModel.name = "flag" // Name it for easier access later

        // Light Beam (tall, semi-transparent unlit cylinder)
        let beam = MeshResource.generateCylinder(height: 1000.0, radius: 0.5)
        var beamMaterial = UnlitMaterial(color: .white)
        beamMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        let beamModel = ModelEntity(mesh: beam, materials: [beamMaterial])
        beamModel.position = SIMD3<Float>(0, 500, 0) // Centered tall cylinder

        pinNode.addChild(poleModel)
        pinNode.addChild(flagModel)
        pinNode.addChild(beamModel)

        return pinNode
    }
}

// MARK: - LocationDelegate
class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var pinPosition: SIMD3<Float> = SIMD3<Float>(0, 0, -50)
    @Published var distance: Double = 0
    @Published var bearing: Double = 0
    @Published var headingAccuracy: Double = 0
    @Published var magneticDeclination: Double = 0
    @Published var currentHeading: Double = 0

    private let locationManager = CLLocationManager()
    var destinationLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
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

        if newHeading.trueHeading >= 0 {
            // Magnetic declination is the difference between true north and magnetic north
            var declination = newHeading.trueHeading - newHeading.magneticHeading
            // Normalize to -180 to 180
            if declination > 180 { declination -= 360 }
            if declination < -180 { declination += 360 }
            magneticDeclination = declination
        }

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

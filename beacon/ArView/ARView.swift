//
//  ARView.swift
//  beacon
//
//  Created by Gavin Mathes on 2/20/23.
//

import SwiftUI
import RealityKit
import MapKit

struct ARPinView: View {
    @Binding var destinationLocation: CLLocationCoordinate2D
    @State private var pinPosition: SIMD3<Float> = .zero
    
    var body: some View {
        ARViewContainer(pinPosition: $pinPosition)
            .onAppear {
                let locationManager = CLLocationManager()
                locationManager.requestWhenInUseAuthorization()
                locationManager.delegate = CLLocationDelegateImpl(pinPosition: $pinPosition, destinationLocation: destinationLocation)
                locationManager.startUpdatingLocation()
            }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var pinPosition: SIMD3<Float>
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // add pin node to scene
        let pinNode = makePinNode()
        arView.scene.addAnchor(pinNode)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // update position of pin node
        uiView.scene.anchors[0].transform.translation = pinPosition
    }
    
    private func makePinNode() -> AnchorEntity {
//        let pinNode = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])
        let pinNode = AnchorEntity()
        let sphere = MeshResource.generateSphere(radius: 0.02)
        let material = SimpleMaterial(color: .red, roughness: 0.5, isMetallic: false)
        let model = ModelEntity(mesh: sphere, materials: [material])
        pinNode.addChild(model)
        return pinNode
    }
}

class CLLocationDelegateImpl: NSObject, CLLocationManagerDelegate {
    @Binding var pinPosition: SIMD3<Float>
    
    let destinationLocation: CLLocationCoordinate2D
    
    init(pinPosition: Binding<SIMD3<Float>>, destinationLocation: CLLocationCoordinate2D) {
        self._pinPosition = pinPosition
        self.destinationLocation = destinationLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.first else { return }
        
        let distance = Float(userLocation.distance(from: CLLocation(latitude: destinationLocation.latitude, longitude: destinationLocation.longitude)))
        
        let heading = angleHeading(start: userLocation.coordinate, end: destinationLocation)
        
        let pinVector = SIMD3<Float>(distance, 0, -0.1)
        let rotation = simd_quatf(angle: Float(heading) * .pi / 180, axis: SIMD3<Float>(0, 1, 0)).angle
        pinPosition = pinVector * rotation
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

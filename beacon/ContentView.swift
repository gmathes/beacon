import SwiftUI
import MapKit

struct ContentView: View {
    @State private var address = ""
    @State private var coordinate: CLLocationCoordinate2D?
    
    var body: some View {
        VStack {
            TextField("Enter address", text: $address)
                .padding()
            
            MapView(coordinate: $coordinate, address: address)
                .frame(height: 300)
                .padding()
            
            if let coordinate = coordinate {
                Text("Latitude: \(coordinate.latitude), Longitude: \(coordinate.longitude)")
            }
        }
    }
}

struct MapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    let address: String
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ view: MKMapView, context: Context) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                print("Error: \(String(describing: error))")
                return
            }
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = placemark.location!.coordinate
            view.removeAnnotations(view.annotations)
            view.addAnnotation(annotation)
            
            coordinate = annotation.coordinate
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.canShowCallout = true
            return view
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

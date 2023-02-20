import SwiftUI
import MapKit

struct ContentView: View {
    @State private var coordinate = CLLocationCoordinate2D()
    @State private var annotation = MKPointAnnotation()
    @State private var showTextField = false
    @State private var address = ""

    var body: some View {
        ZStack(alignment: .top) {
            MapView(coordinate: $coordinate, annotation: $annotation)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if showTextField {
                        TextField("Enter a label", text: $address, onCommit: {
                            self.showTextField = false
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    }
                    
                    VStack {
                        Button(action: {
                            self.showTextField.toggle()
                        }) {
                            Image(systemName: "keyboard.badge.eye")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .padding()
                        Button(action: {
                            self.showTextField = true
                        }) {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

struct MapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var annotation: MKPointAnnotation

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.addGestureRecognizer(UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapLongPressed(gestureRecognizer:))))
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        view.removeAnnotations(view.annotations)
        view.addAnnotation(annotation)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        @objc func mapLongPressed(gestureRecognizer: UIGestureRecognizer) {
            if gestureRecognizer.state == .began {
                let mapView = gestureRecognizer.view as! MKMapView
                let coordinate = mapView.convert(gestureRecognizer.location(in: mapView), toCoordinateFrom: mapView)
                parent.coordinate = coordinate
                parent.annotation.coordinate = coordinate
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Annotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? MKPointAnnotation {
                parent.coordinate = annotation.coordinate
                parent.annotation = annotation
            }
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            if let annotationView = views.first {
                annotationView.setSelected(true, animated: true)
            }
        }
    }
}

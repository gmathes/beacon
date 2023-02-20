import SwiftUI
import Combine
import MapKit

struct ContentView: View {
    @State private var coordinate = CLLocationCoordinate2D()
    @State private var annotation = MKPointAnnotation()
    @State private var showAddressSearch = false
    @StateObject private var mapSearch = MapSearch()
    @State private var selectedLocation: MKLocalSearchCompletion?

    var body: some View {
        ZStack(alignment: .top) {
            MapView(coordinate: $coordinate, annotation: $annotation)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if showAddressSearch {
                        Form {
                            Section {
                                TextField("Address", text: $mapSearch.searchTerm)
                            }
                            Section {
                                ForEach(mapSearch.locationResults, id: \.self) { location in
                                    Button(action: {
                                        self.updateAnnotation(with: location)
                                        self.showAddressSearch = false
                                    }) {
                                        VStack(alignment: .leading) {
                                            Text(location.title)
                                            Text(location.subtitle)
                                                .font(.system(.caption))
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color.white.opacity(0.7))
                        .frame(height: 400)
                    }
                    
                    VStack {
                        Button(action: {
                            self.showAddressSearch.toggle()
                            mapSearch.searchTerm = ""
                        }) {
                            Image(systemName: "keyboard.badge.eye")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .padding()
                        Button(action: {
                            self.showAddressSearch = true
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
    private func updateAnnotation(with location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            if error == nil, let coordinate = response?.mapItems.first?.placemark.coordinate {
                self.coordinate = coordinate
                self.annotation.coordinate = coordinate
                self.annotation.title = location.title
                self.annotation.subtitle = location.subtitle
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
                parent.annotation.title = "Dropped pin"
                parent.annotation.subtitle = "Latitude: \(coordinate.latitude)\nLongitude: \(coordinate.longitude)"
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Annotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
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

class MapSearch : NSObject, ObservableObject {
    @Published var locationResults : [MKLocalSearchCompletion] = []
    @Published var searchTerm = ""
    
    private var cancellables : Set<AnyCancellable> = []
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var currentPromise : ((Result<[MKLocalSearchCompletion], Error>) -> Void)?
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        
        $searchTerm
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap({ (currentSearchTerm) in
                self.searchTermToResults(searchTerm: currentSearchTerm)
            })
            .sink(receiveCompletion: { (completion) in
            }, receiveValue: { (results) in
                self.locationResults = results
            })
            .store(in: &cancellables)
    }
    
    func searchTermToResults(searchTerm: String) -> Future<[MKLocalSearchCompletion], Error> {
        Future { promise in
            self.searchCompleter.queryFragment = searchTerm
            self.currentPromise = promise
        }
    }
}

extension MapSearch : MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            currentPromise?(.success(completer.results))
        }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    }
}

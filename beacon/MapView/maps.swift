//
//  maps.swift
//  beacon
//
//  Created by Gavin Mathes on 2/19/23.
//

import SwiftUI
import Combine
import MapKit


struct MapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var annotation: MKPointAnnotation
    @Binding var recenterTrigger: Bool
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var destinationName: String
    @Binding var hasSelectedDestination: Bool
    @Binding var errorMessage: String?
    @Binding var showErrorAlert: Bool
    var onMapTapped: () -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        mapView.addGestureRecognizer(UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapLongPressed(gestureRecognizer:))))

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        // Annotation management should happen regardless of region changes
        view.removeAnnotations(view.annotations)
        view.addAnnotation(annotation)

        let isRecenter = context.coordinator.lastRecenterTrigger != recenterTrigger
        if isRecenter {
            context.coordinator.lastRecenterTrigger = recenterTrigger
        }
        
        var coordinateChangedToDefault = false
        var coordinateChangedToNew = false

        if let last = context.coordinator.lastCoordinate {
            if (last.latitude != coordinate.latitude || last.longitude != coordinate.longitude) {
                if coordinate.latitude == 43.0 && coordinate.longitude == -89.0 {
                    coordinateChangedToDefault = true
                } else {
                    coordinateChangedToNew = true
                }
            }
        } else { // first run
            if coordinate.latitude == 43.0 && coordinate.longitude == -89.0 {
                coordinateChangedToDefault = true
            } else {
                coordinateChangedToNew = true
            }
        }
        
        if isRecenter, let userLocation = userLocation {
            // Recenter wins
            view.setRegion(MKCoordinateRegion(center: userLocation, latitudinalMeters: 1000, longitudinalMeters: 1000), animated: true)
        } else if coordinateChangedToDefault {
            // Then reset to global
            let coordinateRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360))
            view.setRegion(coordinateRegion, animated: true)
        } else if coordinateChangedToNew {
            // Then new destination
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            view.setRegion(region, animated: true)
        }

        context.coordinator.lastCoordinate = coordinate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var lastRecenterTrigger: Bool
        var lastCoordinate: CLLocationCoordinate2D?

        init(_ parent: MapView) {
            self.parent = parent
            self.lastRecenterTrigger = parent.recenterTrigger
            self.lastCoordinate = nil
        }

        @objc func mapLongPressed(gestureRecognizer: UIGestureRecognizer) {
            if gestureRecognizer.state == .began {
                let mapView = gestureRecognizer.view as! MKMapView
                let coordinate = mapView.convert(gestureRecognizer.location(in: mapView), toCoordinateFrom: mapView)

                // Set initial values
                parent.coordinate = coordinate
                parent.annotation.coordinate = coordinate
                parent.annotation.title = "Dropped pin"
                parent.annotation.subtitle = "Lat: \(coordinate.latitude.rounded()), Lon: \(coordinate.longitude.rounded())"

                // Reverse geocode to get location name
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.parent.errorMessage = "Failed to get address: \(error.localizedDescription)"
                            self.parent.showErrorAlert = true
                        }
                        return
                    }
                    
                    if let placemark = placemarks?.first {
                        let name = placemark.name ?? "Dropped pin"
                        DispatchQueue.main.async {
                            self.parent.annotation.title = name
                            self.parent.destinationName = name
                            self.parent.hasSelectedDestination = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.parent.errorMessage = "Could not find an address for this location."
                            self.parent.showErrorAlert = true
                        }
                    }
                }
            }
        }

        @objc func mapTapped() {
            parent.onMapTapped()
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            parent.userLocation = userLocation.coordinate
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Annotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
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
                // Just select the annotation, don't set the region
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
                if case .failure(let error) = completion {
                    print("Error searching for location: \(error.localizedDescription)")
                }
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
        currentPromise?(.failure(error))
    }
}


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
                parent.annotation.subtitle = "Latitude: \(coordinate.latitude.rounded()) Longitude: \(coordinate.longitude.rounded())"
            }
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
                annotationView.setSelected(true, animated: true)
                if let annotation = annotationView.annotation {
                    if annotation.title != "Dropped Pin" {
                        let region = MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
                        mapView.setRegion(region, animated: true)
                    }
                }
            }
            
        }
        
//        func mapView(_ mapView: MKMapView, didChange views: [MKAnnotationView]) {
//            if let annotationView = views.first {
//                annotationView.setSelected(true, animated: true)
//                if let annotation = annotationView.annotation {
//                    if annotation.title != "Dropped Pin" {
//                        let region = MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
//                        mapView.setRegion(region, animated: true)
//                    }
//                }
//            }
//            
//        }
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


//
//  ContentView.swift
//  beacon
//
//  Created by Gavin Mathes on 1/8/23.
//

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
                        .frame(height: 400)
                    }
                    
                    ControlGroup {
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
                        Button(action: {
                            mapView?.setRegion(<#T##MKCoordinateRegion#>, animated: <#T##Bool#>)
                        }) {
                            Image(systemName: "keyboard.badge.eye")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                }
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    Button(action: {
                        self.showAddressSearch = true
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
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

struct Previews_ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


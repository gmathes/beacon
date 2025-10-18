//
//  ContentView.swift
//  beacon
//
//  Created by Gavin Mathes on 1/8/23.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation

struct ContentView: View {
    @State private var coordinate = CLLocationCoordinate2D(latitude: 43.0, longitude: -89.0)
    @State private var annotation = MKPointAnnotation()
    @State private var showAddressSearch = false
    @StateObject private var mapSearch = MapSearch()
    @State private var selectedLocation: MKLocalSearchCompletion?
    @State private var showARView = false
    @State private var recenterTrigger = false
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var destinationName: String = ""
    @State private var hasSelectedDestination = false
    @State private var showLocationPermissionAlert = false
    @StateObject private var locationPermissionManager = LocationPermissionManager()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
            MapView(coordinate: $coordinate, annotation: $annotation, recenterTrigger: $recenterTrigger, userLocation: $userLocation, destinationName: $destinationName, hasSelectedDestination: $hasSelectedDestination, onMapTapped: {
                showAddressSearch = false
            })
                .edgesIgnoringSafeArea(.all)

                // Empty state message
                if !hasSelectedDestination && !showAddressSearch {
                    VStack {
                        Spacer()
                        Text("Search for a location or long-press to drop a pin")
                            .font(.callout)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 120)
                    }
                }

                // Selected destination info card
                if hasSelectedDestination, let userLoc = userLocation {
                    VStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text(destinationName)
                                .font(.headline)
                            if coordinate.latitude != 43.0 || coordinate.longitude != -89.0 {
                                let distance = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                                Text(formatDistance(distance))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 120)
                    }
                }

                // Search bar at top
                VStack(spacing: 0) {
                    if showAddressSearch {
                        VStack(spacing: 0) {
                            // Search field
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)

                                TextField("Search for a place or address", text: $mapSearch.searchTerm)
                                    .textFieldStyle(PlainTextFieldStyle())

                                if !mapSearch.searchTerm.isEmpty {
                                    Button(action: {
                                        mapSearch.searchTerm = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }

                                Button(action: {
                                    showAddressSearch = false
                                    mapSearch.searchTerm = ""
                                }) {
                                    Text("Cancel")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 2)
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // Results list
                            if !mapSearch.searchTerm.isEmpty {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        if mapSearch.locationResults.isEmpty {
                                            HStack {
                                                Text("No results found")
                                                    .foregroundColor(.secondary)
                                                    .padding()
                                                Spacer()
                                            }
                                        } else {
                                            ForEach(mapSearch.locationResults, id: \.self) { location in
                                                Button(action: {
                                                    self.updateAnnotation(with: location)
                                                    self.showAddressSearch = false
                                                    mapSearch.searchTerm = ""
                                                }) {
                                                    HStack {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .foregroundColor(.red)
                                                            .font(.title2)

                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(location.title)
                                                                .foregroundColor(.primary)
                                                                .font(.body)
                                                            Text(location.subtitle)
                                                                .foregroundColor(.secondary)
                                                                .font(.caption)
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding()
                                                    .background(Color(UIColor.systemBackground))
                                                }
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .frame(maxHeight: 400)
                            }
                        }
                        .background(Color.black.opacity(0.3))
                    }

                    Spacer()
                }

                    HStack(spacing: 16) {
                        Button(action: {
                            self.showAddressSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        Button(action: {
                            recenterTrigger.toggle()
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        #if DEBUG
                        Button(action: {
                            // Set test beacon 100m north of current location
                            if let userLoc = userLocation {
                                // Move 100m north (~0.0009 degrees latitude)
                                let testCoordinate = CLLocationCoordinate2D(
                                    latitude: userLoc.latitude + 0.0009,
                                    longitude: userLoc.longitude
                                )
                                self.coordinate = testCoordinate
                                let testAnnotation = MKPointAnnotation()
                                testAnnotation.coordinate = testCoordinate
                                testAnnotation.title = "Test Beacon"
                                testAnnotation.subtitle = "100m North"
                                self.annotation = testAnnotation
                                self.destinationName = "Test Beacon (100m N)"
                                self.hasSelectedDestination = true
                            }
                        }) {
                            Image(systemName: "target")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        #endif
                        Button(action: {
                            self.coordinate = CLLocationCoordinate2D(latitude: 43.0, longitude: -89.0)
                            self.annotation = MKPointAnnotation()
                            self.hasSelectedDestination = false
                            self.destinationName = ""
                        }) {
                            Image(systemName: "gobackward")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 80)
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    if hasSelectedDestination {
                        Button(action: {
                            showARView = true
                        }) {
                            HStack {
                                Image(systemName: "location.north.circle.fill")
                                Text("Show Beacon")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(25)
                        }
                        .shadow(radius: 5)
                    }
                }
            }
            }
            .navigationDestination(isPresented: $showARView) {
                ARPinView(destinationLocation: $coordinate)
            }
            .alert("Location Access Required", isPresented: $showLocationPermissionAlert) {
                Button("Settings", role: nil) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This app requires location access to show your position and navigate to destinations. Please enable location access in Settings.")
            }
            .onAppear {
                locationPermissionManager.checkPermission()
            }
            .onChange(of: locationPermissionManager.authorizationStatus) { _, newStatus in
                if newStatus == .denied || newStatus == .restricted {
                    showLocationPermissionAlert = true
                }
            }
        }
        }
    
    private func updateAnnotation(with location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            if error == nil, let coordinate = response?.mapItems.first?.placemark.coordinate {
                annotation = MKPointAnnotation(coordinate: coordinate, title: location.title, subtitle: location.subtitle)
                self.coordinate = coordinate
                self.annotation = annotation
                self.destinationName = location.title
                self.hasSelectedDestination = true
            }
        }
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1

        if distance < 1000 {
            let measurement = Measurement(value: distance, unit: UnitLength.meters)
            return formatter.string(from: measurement)
        } else {
            let measurement = Measurement(value: distance / 1000, unit: UnitLength.kilometers)
            return formatter.string(from: measurement)
        }
    }
}

class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    func checkPermission() {
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

struct Previews_ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


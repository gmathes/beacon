//
//  LaunchScreen.swift
//  Beacon AR Navigator
//
//  Created by Gavin Mathes
//

import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.4, blue: 0.9)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "location.north.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)

                Text("Beacon AR Navigator")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Find your way")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}

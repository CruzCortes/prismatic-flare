//
//  AppIcon.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI

struct AppIcon: View {
    var body: some View {
        VStack {
            ZStack {                
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            }
        }
    }
}

#Preview {
    AppIcon()
}

//
//  SplashBody.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI

struct SplashBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Prismatic Burst Flare")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("An open-source Metal shader effect with a custom window compositor. Feel free to use it, get inspired, or build upon it. A follow would be appreciated!")
                .foregroundColor(.gray)
                .font(.body)
            
            Button(action: {
                if let url = URL(string: "https://x.com/the_cruzcortes") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("follow me on X")
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.white)
                    .cornerRadius(25)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 10)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SplashBody()
}

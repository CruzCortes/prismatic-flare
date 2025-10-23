//
//  SplashHeader.swift
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI

struct SplashHeader: View {
    @State private var prismaticConfig = PrismaticBurstConfig(
        intensity: 2.0,
        speed: 0.5,
        animationType: .rotate3d,
        colors: [
            Color(red: 0.5, green: 0.0, blue: 1.0),  // Purple
            Color(red: 0.0, green: 0.5, blue: 1.0),  // Cyan
            Color(red: 1.0, green: 0.0, blue: 0.5),  // Magenta
            Color(red: 0.0, green: 1.0, blue: 0.5),  // Mint
            Color(red: 1.0, green: 0.5, blue: 0.0)   // Orange
        ],
        distortion: 2.0,
        isPaused: false,
        offset: .zero,
        hoverDampness: 0.3,
        rayCount: 6,
        noiseAmount: 0.8
    )

    var body: some View {
        ZStack {
            PrismaticBurstView(config: $prismaticConfig)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            
            AppIcon()
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            prismaticConfig.isPaused = false
        }
        .onDisappear {
            prismaticConfig.isPaused = true
        }
    }
}

#Preview {
    SplashHeader()
        .frame(height: 400)
        .preferredColorScheme(.dark)
}

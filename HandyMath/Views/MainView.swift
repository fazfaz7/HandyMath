//
//  MainView.swift
//  HandPoseDetection
//
//  Created by Adrian Emmanuel Faz Mercado on 25/05/25.
//

import SwiftUI

struct MainView: View {
    let startAction: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                Color.skyblue
                
                VStack(spacing: 30) {
                    Text("Finger Math Challenge")
                        .font(.system(size: 45))
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Use your fingers to solve math problems!")
                        .font(.system(size: 24))
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        startAction()
                    } label: {
                        Text("Start!")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                            .frame(width: geometry.size.width*0.7, height: geometry.size.height*0.08)
                            .background(RoundedRectangle(cornerRadius: 25).fill(.goldenyellow))
                    }.padding(.vertical)
                }
                
            }.ignoresSafeArea()
        }
       
    }
}

#Preview {
    //MainView()
}

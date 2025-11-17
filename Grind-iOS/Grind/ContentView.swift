//
//  ContentView.swift
//  Grind
//
//  Main content view - delegates to DashboardView
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DashboardView()
            .statusBarHidden(true)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
       ContentView()
    }
}
#endif

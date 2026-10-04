import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VPNViewModel()

    var body: some View { VPNRootView(viewModel: viewModel) }
}

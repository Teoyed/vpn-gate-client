import SwiftUI

struct VPNRootView: View {
    @ObservedObject var viewModel: VPNViewModel
    var body: some View {
        Group {
            if viewModel.isOnboarded {
                main
            } else {
                OnboardingView { viewModel.isOnboarded = true }
            }
        }
        .tint(.indigo)
        .preferredColorScheme(.light)
        .sheet(isPresented: $viewModel.isPermissionSheetPresented) { PermissionView { viewModel.allowVPNAccess() } }
    }
    private var main: some View { HomeView(viewModel: viewModel) }
}

struct HomeView: View {
    @ObservedObject var viewModel: VPNViewModel
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 16) { Text(viewModel.vpnState.title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(viewModel.vpnState == .failed ? .orange : .primary); Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 24); ConnectControl(state: viewModel.vpnState, action: viewModel.requestConnection); if viewModel.vpnState == .failed { Button("Try Again") { viewModel.connect() }.buttonStyle(.borderedProminent) } }.frame(maxWidth: .infinity).padding(.vertical, 18)
            HomeSection(title: "Server") {
                NavigationLink { ServersView(viewModel: viewModel) } label: { ServerSummary(server: viewModel.selectedServer, connected: viewModel.vpnState == .connected, seconds: viewModel.connectionSeconds) }
                .buttonStyle(.plain)
            }
            if viewModel.vpnState == .connected { ConnectionStats() }
            }.padding(.top, 18).padding(.bottom, 40) }
            .background(Color(uiColor: .systemGroupedBackground), ignoresSafeAreaEdges: .all)
            .navigationTitle("VPN Gate")
        }
    }
    private var subtitle: String { switch viewModel.vpnState { case .disconnected: "Connect to protect your internet traffic."; case .connecting: "Establishing a secure connection..."; case .connected: "Your connection is private and secure."; case .disconnecting: "Closing your secure connection..."; case .failed: viewModel.connectionError ?? "We couldn’t connect to this server. Try again or choose another." } }
}

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal, 20)
            content
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
        }
    }
}

struct ConnectControl: View {
    let state: VPNState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(state == .connected ? Color.green.opacity(0.14) : Color.indigo.opacity(0.1))
                    .frame(width: 190, height: 190)
                Circle()
                    .stroke(state == .connected ? Color.green.opacity(0.55) : Color.indigo.opacity(0.3), lineWidth: 1)
                    .frame(width: 158, height: 158)
                Circle().fill(.thinMaterial).frame(width: 132, height: 132)
                Image(systemName: state == .connected ? "checkmark.shield.fill" : "power")
                    .font(.system(size: 43, weight: .semibold))
                    .foregroundStyle(state == .connected ? .green : .indigo)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .connecting || state == .disconnecting)
    }
}
struct ServerSummary: View {
    let server: VPNServer
    let connected: Bool
    let seconds: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(server.flag).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current server").font(.caption).foregroundStyle(.secondary)
                    Text("\(server.city), \(server.country)").font(.headline)
                    Text(server.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(server.ping) ms", systemImage: "bolt.fill").font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))

            if connected {
                HStack(spacing: 20) {
                    Label("185.23.41.8", systemImage: "network")
                    Label(formatTime(seconds), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 14)
            }
        }
    }
}
struct ConnectionStats: View { var body: some View { HStack(spacing: 12) { StatPill(title: "Download", value: "24.8 MB", icon: "arrow.down"); StatPill(title: "Upload", value: "8.1 MB", icon: "arrow.up") }.padding(.horizontal, 20).padding(.top, 18) } }
struct StatPill: View { let title, value, icon: String; var body: some View { HStack { Image(systemName: icon).foregroundStyle(.indigo); VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)) } }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16)) } }

struct ServersView: View {
    @ObservedObject var viewModel: VPNViewModel

    var body: some View {
        List {
            Section {
                if viewModel.isLoadingServers {
                    HStack { Spacer(); ProgressView("Updating servers…"); Spacer() }.padding(.vertical, 24)
                } else if let error = viewModel.serverError {
                    VStack(spacing: 10) { Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center); Button("Retry") { Task { await viewModel.refreshServers(force: true) } }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity).padding(.vertical, 24)
                } else if viewModel.filteredServers.isEmpty {
                    EmptyState()
                } else {
                    ForEach(viewModel.filteredServers) { server in
                        ServerRow(server: server, selected: server.id == viewModel.selectedServer.id) {
                            viewModel.select(server: server)
                        }
                    }
                }
            } header: {
                Text("Choose a server")
            } footer: {
                Text("\(viewModel.filteredServers.count) servers available")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, prompt: "Search countries or cities")
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await viewModel.refreshServers(force: true) } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingServers)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.sortByPing.toggle() } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await viewModel.refreshServers() }
    }
}
struct ServerRow: View { let server: VPNServer; let selected: Bool; let action: () -> Void; var body: some View { Button(action: action) { HStack(spacing: 12) { Text(server.flag).font(.title2); VStack(alignment: .leading, spacing: 3) { Text(server.country).font(.body.weight(.semibold)); Text("\(server.city) · \(server.name)").font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing, spacing: 4) { Text("\(server.ping) ms").font(.caption); HStack(spacing: 4) { Circle().fill(server.status.color).frame(width: 7, height: 7); Text(server.status.rawValue).font(.caption2).foregroundStyle(.secondary) } }; if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo) } }.padding(.vertical, 7) }.buttonStyle(.plain) } }
struct EmptyState: View { var body: some View { VStack(spacing: 10) { Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary); Text("No servers found").font(.headline); Text("Try another country, city, or server name.").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 40) } }

struct StatisticsView: View { @ObservedObject var viewModel: VPNViewModel; var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) { Text("Today").font(.headline); LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { MetricCard(title: "Connected", value: viewModel.vpnState == .connected ? formatTime(viewModel.connectionSeconds) : "—", icon: "clock"); MetricCard(title: "Download", value: viewModel.vpnState == .connected ? "24.8 MB" : "—", icon: "arrow.down"); MetricCard(title: "Upload", value: viewModel.vpnState == .connected ? "8.1 MB" : "—", icon: "arrow.up"); MetricCard(title: "Speed", value: viewModel.vpnState == .connected ? "18.4 Mbps" : "—", icon: "gauge") }; Text("Current connection").font(.headline); HStack { Text(viewModel.selectedServer.flag).font(.title); VStack(alignment: .leading) { Text(viewModel.selectedServer.name).font(.headline); Text("185.23.41.8").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }.padding().background(.white, in: RoundedRectangle(cornerRadius: 18)) }.padding(20) }.background(Color(uiColor: .systemGroupedBackground), ignoresSafeAreaEdges: .all).navigationTitle("Statistics") } } }
struct MetricCard: View { let title, value, icon: String; var body: some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).foregroundStyle(.indigo); Text(value).font(.title3.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18)) } }
#if false
// Settings screen temporarily disabled. Restore this block and its TabView item when needed.
struct SettingsView: View { @ObservedObject var viewModel: VPNViewModel; var body: some View { NavigationStack { List { Section("VPN") { Toggle("Auto-connect", isOn: $viewModel.autoConnect); Toggle("Connect on Wi-Fi", isOn: $viewModel.connectOnWiFi); Toggle("Connect on cellular", isOn: $viewModel.connectOnCellular); Toggle("Kill switch", isOn: $viewModel.killSwitch); Text("Protocol\nAutomatic").foregroundStyle(.primary) }; Section("General") { Toggle("Notifications", isOn: $viewModel.notifications); Text("Language\nEnglish").foregroundStyle(.primary); Text("About\nVPN Gate 1.0").foregroundStyle(.primary) }; Section("Support") { Text("Help"); Text("Privacy"); Text("Terms of Service") } }.scrollContentBackground(.hidden).background(Color(uiColor: .systemGroupedBackground)).listStyle(.insetGrouped).navigationTitle("Settings") } } }
#endif

struct OnboardingView: View { let finish: () -> Void; @State private var page = 0; private let pages = [("shield.fill", "Secure your connection", "Keep your personal data private wherever you go."), ("globe.americas.fill", "Choose a server", "Connect through a fast, reliable server around the world."), ("bolt.fill", "Connect with one tap", "Simple protection that stays out of your way.")]; var body: some View { VStack(spacing: 20) { Spacer(); Image(systemName: pages[page].0).font(.system(size: 70)).foregroundStyle(.indigo).frame(width: 150, height: 150).background(.indigo.opacity(0.1), in: Circle()); Text(pages[page].1).font(.system(size: 30, weight: .bold, design: .rounded)).multilineTextAlignment(.center); Text(pages[page].2).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 45); Spacer(); Button(page == pages.count - 1 ? "Get Started" : "Continue") { if page < pages.count - 1 { page += 1 } else { finish() } }.buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom, 24) }.padding(.top, 40).background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea()) } }
struct PermissionView: View { let allow: () -> Void; var body: some View { VStack(spacing: 20) { Spacer(); Image(systemName: "lock.shield.fill").font(.system(size: 58)).foregroundStyle(.indigo); Text("Allow VPN Access").font(.title.bold()); Text("VPN Gate needs permission to configure a secure connection on your iPhone. Your data stays private and protected.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal, 28); Spacer(); Button("Allow VPN Access", action: allow).buttonStyle(.borderedProminent).controlSize(.large); Text("Not now").foregroundStyle(.secondary).padding(.bottom, 14) }.padding(24).presentationDetents([.medium]) } }

import SwiftUI

/// Root content of the notch panel. The window is fixed at the full size and
/// top-anchored; this view draws the black notch shape top-centered and
/// animates its *size* between states, so the dashboard physically drops down
/// out of the notch instead of snapping open.
struct NotchView: View {
    @Environment(AppState.self) private var app
    private let controller = NotchController.shared
    @State private var dropTargeted = false

    var body: some View {
        let expanded = controller.isExpanded
        let size = shapeSize
        let radius: CGFloat = expanded ? 22 : 12

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background(expanded: expanded, radius: radius)
                    .overlay(
                        NotchShape(bottomRadius: radius)
                            .stroke(dropTargeted ? app.accentColor.opacity(0.9)
                                                 : Color.white.opacity(expanded ? 0.12 : 0),
                                    lineWidth: dropTargeted ? 1.5 : 0.5)
                    )
                    .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 16, y: 8)

                content(expanded: expanded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipShape(NotchShape(bottomRadius: radius))
            }
            .frame(width: size.width, height: size.height)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(app.accentColor)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: controller.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: controller.liveActivityActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: controller.hud)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            controller.requestExpand()
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    Task { @MainActor in app.shelf.add([url]) }
                }
            }
            return true
        }
        .environment(app)
    }

    /// Collapsed = solid black (blends with the physical notch); expanded = a
    /// dark translucent panel that lets the wallpaper faintly through, like
    /// MacNotch.
    @ViewBuilder private func background(expanded: Bool, radius: CGFloat) -> some View {
        if expanded {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.black.opacity(0.55))
            }
            .clipShape(NotchShape(bottomRadius: radius))
        } else {
            NotchShape(bottomRadius: radius).fill(.black)
        }
    }

    @ViewBuilder private func content(expanded: Bool) -> some View {
        if expanded {
            ExpandedView()
                .padding(.horizontal, 18)
                .padding(.top, notchInset)
                .padding(.bottom, 12)
        } else {
            CollapsedView()
        }
    }

    /// The shape's size for the current state.
    private var shapeSize: CGSize {
        guard let geo = controller.currentGeometry else { return CGSize(width: 200, height: 32) }
        if controller.isExpanded { return geo.expandedSize }
        if controller.hud != nil { return geo.hudSize }
        if controller.liveActivityActive { return geo.liveActivitySize }
        return geo.collapsedSize
    }

    private var notchInset: CGFloat {
        (controller.currentGeometry?.notchHeight ?? 32) - 4
    }
}

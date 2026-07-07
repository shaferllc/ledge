import SwiftUI

/// Root content of the notch panel. Draws the black notch silhouette and swaps
/// between the collapsed hint / live activity / HUD and the expanded dashboard.
struct NotchView: View {
    @Environment(AppState.self) private var app
    private let controller = NotchController.shared
    @State private var dropTargeted = false

    var body: some View {
        let expanded = controller.isExpanded
        let radius: CGFloat = expanded ? 22 : 12

        ZStack(alignment: .top) {
            NotchShape(bottomRadius: radius)
                .fill(.black)
                .overlay(
                    NotchShape(bottomRadius: radius)
                        .stroke(dropTargeted ? app.accentColor.opacity(0.9)
                                             : Color.white.opacity(expanded ? 0.10 : 0),
                                lineWidth: dropTargeted ? 1.5 : 0.5)
                )
                .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 12, y: 6)

            // Content is pinned to the top and masked to the notch shape, so as
            // the panel grows downward the dashboard is revealed top-to-bottom
            // (a shade dropping from the notch) rather than blooming from center.
            Group {
                if expanded {
                    ExpandedView()
                        .padding(.horizontal, 16)
                        .padding(.top, notchInset)
                        .padding(.bottom, 14)
                } else {
                    CollapsedView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipShape(NotchShape(bottomRadius: radius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .tint(app.accentColor)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: controller.isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: controller.liveActivityActive)
        .animation(.easeOut(duration: 0.2), value: controller.hud)
        // Drag files toward the notch → it opens as a drop target for the Shelf.
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

    private var notchInset: CGFloat {
        (controller.currentGeometry?.notchHeight ?? 32) - 4
    }
}

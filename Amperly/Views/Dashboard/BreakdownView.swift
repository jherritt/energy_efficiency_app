import SwiftUI
import EnergyKit

/// Retired. The six-line points ledger now renders inside `PointsCardView` as a
/// single unified POINTS card. This wrapper remains only so the file (and any
/// stale references) keep compiling; it draws nothing.
struct BreakdownView: View {
    let points: PointsBreakdown

    var body: some View {
        EmptyView()
    }
}

#Preview {
    BreakdownView(points: PointsBreakdown())
}

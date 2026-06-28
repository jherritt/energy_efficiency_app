// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnergyKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Shared by the main app target and the widget extension so scoring logic
        // and HealthKit access live in exactly one place.
        .library(name: "EnergyKit", targets: ["EnergyKit"])
    ],
    targets: [
        .target(
            name: "EnergyKit",
            path: "Sources/EnergyKit"
        ),
        .testTarget(
            name: "EnergyKitTests",
            dependencies: ["EnergyKit"],
            path: "Tests/EnergyKitTests"
        )
    ]
)

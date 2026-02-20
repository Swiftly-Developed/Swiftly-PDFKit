// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftlyPDFKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "SwiftlyPDFKit",
            targets: ["SwiftlyPDFKit"]
        ),
        .library(
            name: "SwiftlyPDFKitUI",
            targets: ["SwiftlyPDFKitUI"]
        ),
        .library(
            name: "DemoPDFKit",
            type: .dynamic,
            targets: ["DemoPDFKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/fwcd/swift-qrcode-generator.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftlyPDFKit",
            dependencies: [
                .product(name: "QRCodeGenerator", package: "swift-qrcode-generator"),
            ],
            path: "Sources/SwiftlyPDFKit",
            linkerSettings: [
                .linkedFramework("PDFKit", .when(platforms: [.macOS, .iOS])),
            ]
        ),
        .target(
            name: "SwiftlyPDFKitUI",
            dependencies: ["SwiftlyPDFKit"],
            path: "Sources/SwiftlyPDFKitUI",
            linkerSettings: [
                .linkedFramework("PDFKit", .when(platforms: [.macOS, .iOS])),
            ]
        ),
        .target(
            name: "DemoPDFKit",
            dependencies: ["SwiftlyPDFKit", "SwiftlyPDFKitUI"],
            path: "Sources/DemoPDFKit",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
            ]
        ),
        .executableTarget(
            name: "GenerateDemos",
            dependencies: ["SwiftlyPDFKit"],
            path: "Sources/GenerateDemos"
        ),
    ]
)

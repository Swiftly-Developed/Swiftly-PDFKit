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
        .executable(
            name: "HelloWorldPDF",
            targets: ["HelloWorldPDF"]
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
        .executableTarget(
            name: "HelloWorldPDF",
            dependencies: ["SwiftlyPDFKit"],
            path: "Sources/HelloWorldPDF"
        ),
    ]
)

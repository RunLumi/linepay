// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "LinePayDomain",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "LinePayDomain", targets: ["LinePayDomain"]),
    ],
    targets: [
        .target(name: "LinePayDomain"),
        .testTarget(
            name: "LinePayDomainTests",
            dependencies: ["LinePayDomain"]
        ),
    ]
)

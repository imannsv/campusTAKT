// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CampusZeitStudents",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CampusZeitStudents",
            targets: ["CampusZeitStudents"]
        ),
    ],
    targets: [
        .target(
            name: "CampusZeitStudents",
            dependencies: ["StudentCore"],
            resources: [
                .copy("Resources/Logo.png"), .copy("Resources/Mark.png"),
                .copy("Resources/CampusLeibnizFH.jpg"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(name: "StudentCore"),
        .testTarget(name: "StudentCoreTests", dependencies: ["StudentCore"]),
    ]
)

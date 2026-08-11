// swift-tools-version: 6.4
import PackageDescription

func releasedDependency(named name: String, exactVersion: Version) -> Package.Dependency {
    .package(
        url: "https://github.com/1amageek/\(name).git",
        exact: exactVersion
    )
}

let package = Package(
    name: "ParasiticDesignDatabaseIntegration",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "ParasiticDesignDatabaseSchema",
            targets: ["ParasiticDesignDatabaseSchema"]
        ),
        .library(
            name: "ParasiticDesignDatabaseRuntimeAdapter",
            targets: ["ParasiticDesignDatabaseRuntimeAdapter"]
        ),
    ],
    dependencies: [
        releasedDependency(
            named: "CircuiteFoundation",
            exactVersion: "26.812.0"
        ),
        releasedDependency(
            named: "DesignDatabase",
            exactVersion: "26.812.1"
        ),
        releasedDependency(
            named: "PDKKit",
            exactVersion: "26.812.0"
        ),
        releasedDependency(named: "PEXEngine", exactVersion: "26.812.0"),
        .package(url: "https://github.com/1amageek/PDKDesignDatabaseIntegration.git", exact: "26.812.0"),
        .package(url: "https://github.com/1amageek/LayoutDesignDatabaseIntegration.git", exact: "26.812.0"),
        .package(
            url: "https://github.com/1amageek/database-kit.git",
            exact: "26.0809.4"
        ),
        .package(
            url: "https://github.com/1amageek/database-types.git",
            exact: "26.0730.0"
        ),
        .package(
            url: "https://github.com/1amageek/database-framework.git",
            exact: "26.0809.1",
            traits: ["SQLite"]
        ),
    ],
    targets: [
        .target(
            name: "ParasiticDesignDatabaseSchema",
            dependencies: [
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "PEXCore", package: "PEXEngine"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutDesignDatabaseSchema", package: "LayoutDesignDatabaseIntegration"),
                .product(name: "DatabaseKit", package: "database-kit"),
                .product(name: "DatabaseTypes", package: "database-types"),
                .product(name: "DatabaseTypesFoundation", package: "database-types"),
            ]
        ),
        .target(
            name: "ParasiticDesignDatabaseRuntimeAdapter",
            dependencies: [
                "ParasiticDesignDatabaseSchema",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "CircuiteFoundationCrypto", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "DesignDatabaseRuntime", package: "DesignDatabase"),
                .product(name: "PEXCore", package: "PEXEngine"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "PDKDesignDatabaseRuntimeAdapter", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutDesignDatabaseSchema", package: "LayoutDesignDatabaseIntegration"),
                .product(name: "LayoutDesignDatabaseRuntimeAdapter", package: "LayoutDesignDatabaseIntegration"),
                .product(name: "Database", package: "database-framework"),
            ]
        ),
        .testTarget(
            name: "ParasiticDesignDatabaseIntegrationTests",
            dependencies: [
                "ParasiticDesignDatabaseSchema",
                "ParasiticDesignDatabaseRuntimeAdapter",
                .product(name: "CircuiteFoundation", package: "CircuiteFoundation"),
                .product(name: "DesignDatabaseCore", package: "DesignDatabase"),
                .product(name: "PEXCore", package: "PEXEngine"),
                .product(name: "PDKDesignDatabaseSchema", package: "PDKDesignDatabaseIntegration"),
                .product(name: "LayoutDesignDatabaseSchema", package: "LayoutDesignDatabaseIntegration"),
            ]
        ),
    ]
)

import CircuiteFoundation
import DesignDatabaseCore
import LayoutDesignDatabaseSchema
import ParasiticDesignDatabaseSchema
import PDKDesignDatabaseSchema
import PEXCore
import Testing
@testable import ParasiticDesignDatabaseRuntimeAdapter

@Suite("Parasitic DesignDatabase schema")
struct ParasiticDatabaseSchemaTests {
    @Test("corner-bound parasitics canonicalize identity-keyed collections")
    func canonicalRoundTrip() throws {
        let fixture = try makeFixture()
        let data = try ParasiticDatabaseCanonicalCodec.encode(fixture)
        let decoded = try ParasiticDatabaseCanonicalCodec.decode(data)

        #expect(decoded == fixture)
        #expect(decoded.parasitics.nets.map(\.name.value) == ["a", "z"])
        #expect(decoded.parasitics.elements.map(\.id) == ["r1", "r2"])
    }

    @Test("layout and PDK bindings must name one exact base revision")
    func sourceRevisionMustMatch() throws {
        let fixture = try makeFixture()
        let otherDatabase = try DesignDatabaseID(high: 8, low: 9)
        let otherRevision = DesignRevisionReference(
            databaseID: otherDatabase,
            revisionID: DesignRevisionID(high: 10, low: 11)
        )
        let mismatchedPDK = try PDKDatabaseFacetSourceBinding(
            sourceRevision: otherRevision,
            sourceRootDigest: fixture.sourcePDK.sourceRootDigest
        )

        #expect(throws: ParasiticDatabaseSchemaError.self) {
            try ParasiticDatabaseState(
                sourceLayout: fixture.sourceLayout,
                sourcePDK: mismatchedPDK,
                sourceArtifact: fixture.sourceArtifact,
                parasitics: fixture.parasitics
            )
        }
    }

    @Test("invalid ParasiticIR never becomes canonical state")
    func invalidIRIsRejected() throws {
        let fixture = try makeFixture()
        let dangling = ParasiticElement(
            id: "dangling",
            kind: .resistor,
            nodeA: NodeRef(netName: NetName("a"), nodeName: NodeName("missing")),
            nodeB: NodeRef(netName: NetName("a"), nodeName: NodeName("a2")),
            value: 1,
            source: .extracted
        )
        let invalid = ParasiticIR(
            version: fixture.parasitics.version,
            cornerID: fixture.parasitics.cornerID,
            units: fixture.parasitics.units,
            nets: fixture.parasitics.nets,
            elements: fixture.parasitics.elements + [dangling],
            metadata: [:]
        )

        #expect(throws: ParasiticDatabaseSchemaError.self) {
            try ParasiticDatabaseState(
                sourceLayout: fixture.sourceLayout,
                sourcePDK: fixture.sourcePDK,
                sourceArtifact: fixture.sourceArtifact,
                parasitics: invalid
            )
        }
    }

    @Test("transitive PDK compatibility follows database and content identity")
    func transitivePDKCompatibilityUsesContentIdentity() throws {
        let databaseID = try DesignDatabaseID(high: 13, low: 14)
        let layout = try PDKDatabaseFacetSourceBinding(
            sourceRevision: DesignRevisionReference(
                databaseID: databaseID,
                revisionID: DesignRevisionID(high: 15, low: 16)
            ),
            sourceRootDigest: digest("21")
        )
        let laterRevision = try PDKDatabaseFacetSourceBinding(
            sourceRevision: DesignRevisionReference(
                databaseID: databaseID,
                revisionID: DesignRevisionID(high: 17, low: 18)
            ),
            sourceRootDigest: layout.sourceRootDigest
        )
        let changedContent = try PDKDatabaseFacetSourceBinding(
            sourceRevision: laterRevision.sourceRevision,
            sourceRootDigest: digest("22")
        )
        let otherDatabase = try PDKDatabaseFacetSourceBinding(
            sourceRevision: DesignRevisionReference(
                databaseID: DesignDatabaseID(high: 19, low: 20),
                revisionID: laterRevision.sourceRevision.revisionID
            ),
            sourceRootDigest: layout.sourceRootDigest
        )

        #expect(ParasiticTransitivePDKCompatibility.matches(
            parasitic: laterRevision,
            layout: layout
        ))
        #expect(!ParasiticTransitivePDKCompatibility.matches(
            parasitic: changedContent,
            layout: layout
        ))
        #expect(!ParasiticTransitivePDKCompatibility.matches(
            parasitic: otherDatabase,
            layout: layout
        ))
    }
}

private func makeFixture() throws -> ParasiticDatabaseState {
    let databaseID = try DesignDatabaseID(high: 1, low: 2)
    let revision = DesignRevisionReference(
        databaseID: databaseID,
        revisionID: DesignRevisionID(high: 3, low: 4)
    )
    let layoutRoot = try digest("10")
    let pdkRoot = try digest("11")
    let sourceLayout = try LayoutDatabaseFacetSourceBinding(
        sourceRevision: revision,
        sourceRootDigest: layoutRoot
    )
    let sourcePDK = try PDKDatabaseFacetSourceBinding(
        sourceRevision: revision,
        sourceRootDigest: pdkRoot
    )
    let netA = ParasiticNet(
        name: NetName("a"),
        nodes: [
            ParasiticNode(
                name: NodeName("a2"),
                kind: .internal,
                instancePath: nil,
                coordinate: nil
            ),
            ParasiticNode(
                name: NodeName("a1"),
                kind: .pin,
                instancePath: nil,
                coordinate: nil
            ),
        ],
        totalGroundCapF: 0,
        totalCouplingCapF: 0,
        totalResistanceOhm: 1
    )
    let netZ = ParasiticNet(
        name: NetName("z"),
        nodes: [
            ParasiticNode(
                name: NodeName("z2"),
                kind: .internal,
                instancePath: nil,
                coordinate: nil
            ),
            ParasiticNode(
                name: NodeName("z1"),
                kind: .pin,
                instancePath: nil,
                coordinate: nil
            ),
        ],
        totalGroundCapF: 0,
        totalCouplingCapF: 0,
        totalResistanceOhm: 1
    )
    let elements = [
        ParasiticElement(
            id: "r2",
            kind: .resistor,
            nodeA: NodeRef(netName: NetName("z"), nodeName: NodeName("z1")),
            nodeB: NodeRef(netName: NetName("z"), nodeName: NodeName("z2")),
            value: 1,
            source: .extracted
        ),
        ParasiticElement(
            id: "r1",
            kind: .resistor,
            nodeA: NodeRef(netName: NetName("a"), nodeName: NodeName("a1")),
            nodeB: NodeRef(netName: NetName("a"), nodeName: NodeName("a2")),
            value: 1,
            source: .extracted
        ),
    ]
    return try ParasiticDatabaseState(
        sourceLayout: sourceLayout,
        sourcePDK: sourcePDK,
        sourceArtifact: ArtifactReference(
            id: try ArtifactID(digest: try digest("12"), byteCount: 100),
            descriptor: ArtifactDescriptor(
                role: .input,
                kind: .parasitics,
                format: .spef
            )
        ),
        parasitics: ParasiticIR(
            version: ParasiticIR.currentVersion,
            cornerID: PEXCornerID("tt"),
            units: .canonical,
            nets: [netZ, netA],
            elements: elements,
            metadata: [:]
        )
    )
}

private func digest(_ byte: String) throws -> ContentDigest {
    try ContentDigest(
        algorithm: .sha256,
        hexadecimalValue: String(repeating: byte, count: 32)
    )
}

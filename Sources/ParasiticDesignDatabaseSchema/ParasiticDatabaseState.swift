import CircuiteFoundation
import LayoutDesignDatabaseSchema
import PDKDesignDatabaseSchema
import PEXCore

public struct ParasiticDatabaseState: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let sourceLayout: LayoutDatabaseFacetSourceBinding
    public let sourcePDK: PDKDatabaseFacetSourceBinding
    public let sourceArtifact: ArtifactReference
    public let parasitics: ParasiticIR
    public let metadata: [String: String]

    public init(
        sourceLayout: LayoutDatabaseFacetSourceBinding,
        sourcePDK: PDKDatabaseFacetSourceBinding,
        sourceArtifact: ArtifactReference,
        parasitics: ParasiticIR,
        metadata: [String: String] = [:]
    ) throws(ParasiticDatabaseSchemaError) {
        schemaVersion = Self.currentSchemaVersion
        self.sourceLayout = sourceLayout
        self.sourcePDK = sourcePDK
        self.sourceArtifact = sourceArtifact
        self.parasitics = Self.canonical(parasitics)
        self.metadata = metadata
        try validate()
    }

    public func validate() throws(ParasiticDatabaseSchemaError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        do {
            try sourceLayout.validate()
        } catch {
            throw .invalidLayoutSourceBinding(reason: String(describing: error))
        }
        do {
            try sourcePDK.validate()
        } catch {
            throw .invalidPDKSourceBinding(reason: String(describing: error))
        }
        guard sourceLayout.sourceRevision == sourcePDK.sourceRevision else {
            throw .missingIdentity
        }
        guard sourceArtifact.descriptor.role == .input,
              sourceArtifact.descriptor.kind == .parasitics,
              sourceArtifact.descriptor.format == .spef
                || sourceArtifact.descriptor.format == .dspf else {
            throw .invalidSourceArtifactDescriptor
        }
        guard parasitics.version == ParasiticIR.currentVersion,
              !parasitics.cornerID.value.isEmpty else {
            throw .missingIdentity
        }
        let report = ParasiticIRValidator().validate(parasitics)
        guard report.isValid else {
            throw .invalidParasiticIR(report.errors.map(String.init(describing:)))
        }
        guard parasitics == Self.canonical(parasitics) else {
            throw .nonCanonicalParasiticOrdering
        }
    }

    private static func canonical(_ source: ParasiticIR) -> ParasiticIR {
        let nets = source.nets.map { net in
            ParasiticNet(
                name: net.name,
                nodes: net.nodes.sorted { $0.name.value < $1.name.value },
                totalGroundCapF: net.totalGroundCapF,
                totalCouplingCapF: net.totalCouplingCapF,
                totalResistanceOhm: net.totalResistanceOhm
            )
        }.sorted { $0.name.value < $1.name.value }
        return ParasiticIR(
            version: source.version,
            cornerID: source.cornerID,
            units: source.units,
            nets: nets,
            elements: source.elements.sorted { $0.id < $1.id },
            metadata: source.metadata
        )
    }
}

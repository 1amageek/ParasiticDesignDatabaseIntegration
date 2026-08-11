public enum ParasiticDatabaseSchemaError: Error, Sendable, Hashable {
    case unsupportedSchemaVersion(Int)
    case missingIdentity
    case invalidLayoutSourceBinding(reason: String)
    case invalidPDKSourceBinding(reason: String)
    case invalidSourceArtifactDescriptor
    case invalidParasiticIR([String])
    case nonCanonicalParasiticOrdering
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case nonCanonicalPayload
    case invalidPageByteCount(Int)
    case pageCountOverflow
}

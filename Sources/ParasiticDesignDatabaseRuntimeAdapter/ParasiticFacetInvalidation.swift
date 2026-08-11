import CircuiteFoundation

public struct ParasiticFacetInvalidation: Sendable, Hashable, Codable {
    public enum Reason: String, Sendable, Hashable, Codable {
        case sourceLayoutMissing
        case sourceLayoutRootChanged
        case sourcePDKMissing
        case sourcePDKRootChanged
    }

    public let observedRevision: DesignRevisionReference
    public let expectedRootDigest: ContentDigest
    public let actualRootDigest: ContentDigest?
    public let reason: Reason

    public init(
        observedRevision: DesignRevisionReference,
        expectedRootDigest: ContentDigest,
        actualRootDigest: ContentDigest?,
        reason: Reason
    ) {
        self.observedRevision = observedRevision
        self.expectedRootDigest = expectedRootDigest
        self.actualRootDigest = actualRootDigest
        self.reason = reason
    }
}

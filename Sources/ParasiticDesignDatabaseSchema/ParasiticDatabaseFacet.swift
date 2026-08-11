import CircuiteFoundation
import DesignDatabaseCore

public enum ParasiticDatabaseFacet: String, Sendable, Hashable, Codable, CaseIterable {
    case parasitics = "parasitic.corner-bound"

    public var designFacetID: DesignFacetID {
        get throws {
            try DesignFacetID(rawValue: rawValue)
        }
    }
}

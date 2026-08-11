import CircuiteFoundation
import DesignDatabaseCore

public enum ParasiticDesignDatabaseSchema {
    public static let adapterVersion = "1.0.0"
    public static let bindingManifest = """
    lsi.parasitic-design-database-schema/v1
    entity=ParasiticDatabaseFacetPage
    directory=design-database/parasitic-facets/{facetID}/{documentDigest}/pages
    fields=id,facetID,ordinal,pageCount,documentByteCount,documentDigest,payload
    facets=parasitic.corner-bound
    sourceBinding=exact-base-layout+exact-base-pdk+corner
    canonicalState=ParasiticIR-without-extraction-verdict
    pageByteCount=65536
    """

    public static var schemaID: DesignSchemaID {
        get throws {
            try DesignSchemaID(rawValue: "lsi.parasitic")
        }
    }
}

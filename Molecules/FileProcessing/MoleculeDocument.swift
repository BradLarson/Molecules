import Gzip
import SwiftUI
import UniformTypeIdentifiers

/// The central viewer document that takes in three file formats: PDB, SDF, and XYZ. It also can
/// process gzip-compressed .pdb.gz files, although that type registration is currently via fairly
/// broad .gz associations.
struct MoleculeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdb, .sdf, .xyz, .gzip] }
    
    let molecule: MolecularStructure

    /// The initializer as used by SwiftUI.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data, contentType: configuration.contentType, filename: configuration.file.filename ?? "")
    }

    /// A more general initializer that can be used in construction of previews.
    /// - Parameters:
    ///   - data: The binary data for the molecule file, as loaded from disk.
    ///   - contentType: One of the supported UTTypes for molecules.
    ///   - filename: The string filename, used for later processing.
    init(data: Data, contentType: UTType, filename: String) throws {
        switch contentType {
        case .pdb:
            molecule = try PDBFile(data: data)
        case .sdf:
            molecule = try SDFFile(data: data)
        case .xyz:
            molecule = try XYZFile(data: data)
        case .gzip:
            guard filename.hasSuffix("pdb.gz") else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }
            let uncompressedData = try data.gunzipped()
            molecule = try PDBFile(data: uncompressedData)
        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        fatalError()
    }
}

extension UTType {
    static var pdb: UTType {
        UTType(exportedAs: "com.sunsetlakesoftware.molecules.pdb")
    }

    static var sdf: UTType {
        UTType(exportedAs: "com.sunsetlakesoftware.molecules.sdf")
    }

    static var xyz: UTType {
        UTType(exportedAs: "com.sunsetlakesoftware.molecules.xyz")
    }
}


extension Bundle {
    /// A helper function that lets us load molecule files that have been embedded in the
    /// application or test bundles.
    /// - Parameters:
    ///   - forResource: The base filename of the molecule file to load.
    ///   - withExtension: The extension of the file to load.
    ///   - compressed: Whether the file is gzip-compressed.
    func loadData(forResource: String, withExtension: String, compressed: Bool = false) throws -> Data {
        guard let url = self.url(forResource: forResource, withExtension: withExtension) else {
            throw PDBFileError.missingResource
        }

        let loadedData = try Data(contentsOf: url)
        if compressed {
            return try loadedData.gunzipped()
        } else {
            return loadedData
        }
    }
}

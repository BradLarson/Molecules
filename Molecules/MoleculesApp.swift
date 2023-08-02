import SwiftUI

@main
struct MoleculesApp: App {
    init() {
        copyBuiltInMoleculesIfNeeded()
        // TODO: Determine previously loaded molecule, set that to display on startup
        // TODO: If no previous structure, load transfer RNA
    }

    var body: some Scene {
        DocumentGroup(viewing: MoleculeDocument.self) { file in
            MoleculeDisplayView(document: file.document)
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

func copyBuiltInMoleculesIfNeeded() {
    guard !UserDefaults.standard.bool(forKey: "copiedInitialFiles") else { return }

    do {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        guard let gzippedPDBs = Bundle.main.urls(forResourcesWithExtension: ".pdb.gz", subdirectory: nil) else {
            return
        }
        guard let unzippedPDBs = Bundle.main.urls(forResourcesWithExtension: ".pdb", subdirectory: nil) else {
            return
        }
        guard let unzippedSDFs = Bundle.main.urls(forResourcesWithExtension: ".sdf", subdirectory: nil) else {
            return
        }
        let builtInMolecules = gzippedPDBs + unzippedPDBs + unzippedSDFs
        for builtInMolecule in builtInMolecules {
            let filename = builtInMolecule.lastPathComponent
            let destinationInDocuments = documents.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: destinationInDocuments.path) {
                try FileManager.default.copyItem(at: builtInMolecule, to: destinationInDocuments)
            }
        }
    } catch {
        print("Error copying built-in molecules: \(error)")
    }
    UserDefaults.standard.setValue(true, forKey: "copiedInitialFiles")
}

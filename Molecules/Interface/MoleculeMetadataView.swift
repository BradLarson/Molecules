import SwiftUI

struct MoleculeMetadataView: View {
    let molecule: MolecularStructure

    var body: some View {
        List {
            // TODO: Titlecase these strings.
            if let metadata = molecule.metadata {
                Section(header: Text("Name")) {
                    Text(metadata.compound)
                }
                Section(header: Text("Description")) {
                    Text(metadata.title)
                }
            }
            Section(header: Text("Statistics")) {
                MoleculeStatisticsRow(title: "Number of atoms", value: molecule.atoms.count)
                MoleculeStatisticsRow(title: "Number of bonds", value: molecule.bonds.count)
                MoleculeStatisticsRow(title: "Number of structures", value: molecule.structureCount)
                MoleculeStatisticsRow(title: "Current structure", value: 1)
            }
            if let metadata = molecule.metadata {
                Section(header: Text("Author(s)")) {
                    Text(metadata.authors)
                }
                Section(header: Text("Journal")) {
                    Text(metadata.journal)
                }
                Section(header: Text("Source")) {
                    Text(metadata.source)
                }
                Section(header: Text("Sequence")) {
                    Text(metadata.sequence)
                }
            }
        }
        .padding()
    }
}

struct MoleculeStatisticsRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)").foregroundColor(.secondary)
        }
    }
}

struct MoleculeMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        let data = try! Bundle.main.loadData(forResource: "DNA", withExtension: "pdb")
        let document = try! MoleculeDocument(data: data, contentType: .pdb, filename: "DNA.pdb")
        NavigationStack {
            MoleculeMetadataView(molecule: document.molecule)
                .navigationTitle("DNA")
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }

        let buckyData = try! Bundle.main.loadData(forResource: "Buckminsterfullerene", withExtension: "sdf")
        let buckyDocument = try! MoleculeDocument(data: buckyData, contentType: .sdf, filename: "Buckminsterfullerene.sdf")
        NavigationStack {
            MoleculeMetadataView(molecule: buckyDocument.molecule)
                .navigationTitle("Buckminsterfullerene")
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

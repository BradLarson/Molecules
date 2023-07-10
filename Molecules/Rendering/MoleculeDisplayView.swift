import SwiftUI

struct MoleculeDisplayView: View {
    @Binding var document: MoleculeDocument
    @State private var autorotate = true

    var body: some View {
        ZStack {
            MetalView(molecule: .constant(document.molecule))
            VStack(alignment: .trailing) {
                Spacer()
                HStack {
                    Button {
                        autorotate.toggle()
                    } label: {
                        Image(systemName: autorotate ? "arrow.uturn.backward.circle.fill" : "arrow.uturn.backward.circle")
                            .imageScale(.large)
                            .foregroundColor(.accentColor)
                    }

                    Spacer()
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // TODO: Rendering options
                    print("Show rendering options")
                } label: {
                    Image(systemName: "rotate.3d")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    MoleculeMetadataView()
                } label: {
                    // TODO: Popover on iPad?
                    Image(systemName: "info.circle")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct MoleculeDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        let data = try! Bundle.main.loadData(forResource: "Caffeine", withExtension: "pdb")
        let document = try! MoleculeDocument(data: data, contentType: .pdb, filename: "Caffeine.pdb")
        NavigationStack {
            MoleculeDisplayView(document: .constant(document))
                .navigationTitle("Caffeine")
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

import SwiftUI

struct MoleculeDisplayView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @Binding var document: MoleculeDocument
    @State private var autorotate = true
    @State private var showingMetadata = false

    var body: some View {
        ZStack {
            MetalView(molecule: .constant(document.molecule), autorotate: $autorotate)
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
                if (horizontalSizeClass == .regular) && (verticalSizeClass == .regular) {
                    // Popover on full screen for iPad.
                    Button {
                        showingMetadata = true
                    } label: {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                            .foregroundColor(.accentColor)
                    }
                    .popover(isPresented: $showingMetadata) {
                        MoleculeMetadataView(molecule: document.molecule)
                            .frame(width: 300, height: 600)
                    }
                } else {
                    // Navigate to a new view for smaller sizes.
                    NavigationLink {
                        MoleculeMetadataView(molecule: document.molecule)
                            .navigationTitle("Details")
                            .toolbarRole(.automatic)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                            .foregroundColor(.accentColor)
                    }
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
        .previewDevice(PreviewDevice(rawValue: "iPhone 14"))
        .previewDisplayName("iPhone 14")

        NavigationStack {
            MoleculeDisplayView(document: .constant(document))
                .navigationTitle("Caffeine")
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }
        .previewDevice(PreviewDevice(rawValue: "iPad (10th generation)"))
        .previewDisplayName("iPad")

        NavigationStack {
            MoleculeDisplayView(document: .constant(document))
                .navigationTitle("Caffeine")
                .toolbarRole(.automatic)
                .navigationBarTitleDisplayMode(.inline)
        }
        .previewDevice(PreviewDevice(rawValue: "iPad (10th generation)"))
        .previewInterfaceOrientation(.landscapeLeft)
        .previewDisplayName("iPad landscape")
    }
}

import SwiftUI

struct MoleculeRenderingOptions: View {
    @Binding var visualizationStyle: MoleculeVisualizationStyle
    @State var selectedVisualizationStyle: MoleculeVisualizationStyle = .spacefilling
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Visualization Style")
                .font(.subheadline)
            Picker("Visualization Style", selection: $selectedVisualizationStyle) {
                Text("Spacefilling").tag(MoleculeVisualizationStyle.spacefilling)
                Text("Ball-and-stick").tag(MoleculeVisualizationStyle.ballAndStick)
            }
            .pickerStyle(.segmented)
            Spacer()
            Button {
                if visualizationStyle != selectedVisualizationStyle {
                    visualizationStyle = selectedVisualizationStyle
                }
                dismiss()
            } label: {
                Text(visualizationStyle == selectedVisualizationStyle ? "Cancel" : "Render")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.fraction(0.25)])
        .onAppear {
            selectedVisualizationStyle = visualizationStyle
        }
    }
}

struct MoleculeRenderingOptions_Previews: PreviewProvider {
    static var previews: some View {
        MoleculeRenderingOptions(visualizationStyle: .constant(.spacefilling))
            .frame(height: 150)
    }
}

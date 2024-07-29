import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    
    
    var body: some View {
        ZStack{
            ARViewContainer(arViewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)
            Circle()
                .frame(width: 100, height: 50)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2 - 25)
            Button(action: {
//                arViewModel.placeSphere()
                arViewModel.placeRectangleOnFloor(width: 0.25, height: 0.5, rotationAngle: .pi / 4)

            }) {
                Text("Place Sphere")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }.position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 200)

    
        }
    }
}

class ARViewModel: ObservableObject {
    @Published var arView: ARView?
    @Published var placedSpheres: [(UUID, SIMD3<Float>)] = []
    
    func placeRectangleOnFloor(width: Float, height: Float, rotationAngle: Float) {
        guard let arView = arView else { return }
        
        // Create the rectangle mesh
        let mesh = MeshResource.generatePlane(width: width, height: height)
        let material = SimpleMaterial(color: .black, roughness: 0.5, isMetallic: true)
        let rectangleEntity = ModelEntity(mesh: mesh, materials: [material, material])
        
        let raycastResult = arView.raycast(from: arView.center,
                                           allowing: .estimatedPlane,
                                           alignment: .horizontal)
        
        if let result = raycastResult.first {
            let anchor = AnchorEntity(world: result.worldTransform)
            
            // Create a translation that lifts the plane above the surface
            let liftTranslation = SIMD3<Float>(0, 0.01, 0)  // Lift by 1cm
            
            // Rotate 90 degrees around X-axis to make it horizontal
            let rotationX = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            
            // Set the transform
            rectangleEntity.transform = Transform(
                scale: .one,
                rotation: rotationX,
                translation: liftTranslation
            )
            
            // Add the rectangle to the anchor
            anchor.addChild(rectangleEntity)
            
            // Add the anchor to the scene
            arView.scene.addAnchor(anchor)
        }
    }

    func placeSphere() {
        guard let arView = arView else { return }
        
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])
        
        let raycastResult = arView.raycast(from: arView.center,
                                           allowing: .estimatedPlane,
                                           alignment: .horizontal)
        
        if let result = raycastResult.first {
            let anchor = AnchorEntity(world: result.worldTransform)
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)
            
            // Save the position of the placed sphere
            let position = result.worldTransform.columns.3
            let spherePosition = SIMD3<Float>(position.x, position.y, position.z)
            print(spherePosition)

            // Generate a new UUID for this sphere
            let sphereId = UUID()

            // Add the UUID to the model's name for future reference
            model.name = sphereId.uuidString

            placedSpheres.append((sphereId, spherePosition))
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arViewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        arViewModel.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    ContentView()
}

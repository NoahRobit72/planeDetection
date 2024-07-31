import SwiftUI
import RealityKit
import ARKit
import Foundation

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    
    
    var body: some View {
        ZStack{
            ARViewContainer(arViewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)
            Circle()
                .frame(width: 100, height: 50)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2 - 25)
            HStack{
                // Place Sphere Button
                Button(action: {
                    arViewModel.placeSphere()

                }) {
                    Text("Place Sphere")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Place Lines Button
                Button(action: {
                    let (point1, point2) = arViewModel.getTwoPoints()
                    print("The first point is: \(point1)")
                    print("The second point is: \(point2)")

                    arViewModel.createFrame()
//                    arViewModel.drawLineBetweenPoints(point1: point1, point2: point2)

                }) {
                    Text("Place Lines")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

            }
            .background(.gray)
            .position(x: UIScreen.main.bounds.width / 2, y: (UIScreen.main.bounds.height) - 150) // Set the position within the ZStack
        }
    }
}

class ARViewModel: ObservableObject {
    @Published var arView: ARView?
    @Published var placedSpheres: [(UUID, SIMD3<Float>)] = []
    @Published var waypointSpheres: [(UUID, SIMD3<Float>)] = []    
    
    func printTwoPoints(){
        // Safely unwrap the optional returned by `placedSpheres.first`
        let sphere1 = placedSpheres[0].1
        print("First Sphere - x: \(sphere1.x), z: \(sphere1.z)")
        
        let sphere2 = placedSpheres[1].1
        print("First Sphere - x: \(sphere2.x), z: \(sphere2.z)")
        
        
        // 3D distance is accurate enough
        let distanceXZ = distance(sphere1, sphere2)
        print(String(format: "XZ Distance: %.6f", distanceXZ))
        
        // Z Check
//        print(String(format: "The Y difference is: %.6f", (sphere1.y - sphere2.y)))

    }
    
    func getTwoPoints() -> (point1: SIMD3<Float>, point2: SIMD3<Float>){
        let point1 = placedSpheres[0].1

        let point2 = placedSpheres[1].1
        
        return (point1, point2)
    }
    
    
    func angleAndTranslation(point1: SIMD3<Float>, point2: SIMD3<Float>) -> (returnAngle: Float, xdif: Float, zdif: Float){
        let xdif = point2.x - point1.x
        let zdif = point2.z - point1.z
        
        let returnAngle: Float = atan(xdif/zdif)
        
        return (returnAngle, xdif, zdif)
    }
    
    // Testing Function
    func printArray(){
        for (uuid, position) in placedSpheres {
            print("UUID: \(uuid), Position: \(position)")
        }
    }
    
    func createFrame(){
        var nextPoint = 1
        for i in 0...3 {
            print("=========================================")
            print("Iteration \(i)")
            print("The current sphere is: \(placedSpheres[i])")
            print("The next sphere is: \(placedSpheres[nextPoint])")
            
            // Create Lines
            drawLineBetweenPoints(point1: placedSpheres[i].1, point2: placedSpheres[nextPoint].1)
            
            nextPoint = nextPoint + 1
            if(nextPoint == 4) {nextPoint = 0}
        }
        
        // create 4 lines
    }
    
    func drawLineBetweenPoints(point1: SIMD3<Float>, point2: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        // Create an anchor at the origin of the world coordinate system
        let anchorEntity = AnchorEntity(world: point1)
                
        // Call the createLine function with the two points
        createLine(from: point1, to: point2, parent: anchorEntity )
        
        
        
        // Add the anchor to the scene
        arView.scene.addAnchor(anchorEntity)
    }
    
    func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, parent: Entity) {
        let (angle, xdif, zdif) = angleAndTranslation(point1: start, point2: end)
        
        let length = distance(start, end)
        let boxMesh = MeshResource.generateBox(size: 0.02)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let lineEntity = ModelEntity(mesh: boxMesh, materials: [material])
        lineEntity.scale = [1, 1, (length / 0.02)]
        lineEntity.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
        lineEntity.transform.translation = [(xdif/2), 0, (zdif/2)]

        parent.addChild(lineEntity)
    }
    
    
    // Not used
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
    
    
    // Test Function
    func placeSphereAt(point1: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])
        
//        // Create an AnchorEntity at the specified position
//        let transform = Transform(scale: .one, rotation: simd_quatf(), translation: position)
//        let anchor = AnchorEntity(world: transform)
        
        let anchor = AnchorEntity(world: point1)

        
        anchor.addChild(model)
        arView.scene.addAnchor(anchor)
        
        // Print the sphere's position
//        print("Sphere placed at: \(position)")

//        // Generate a new UUID for this sphere
//        let sphereId = UUID()
//
//        // Add the UUID to the model's name for future reference
//        model.name = sphereId.uuidString
//
//        // Add the sphere's ID and position to the placedSpheres array
//        placedSpheres.append((sphereId, position))
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

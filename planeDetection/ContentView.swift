import SwiftUI
import RealityKit
import ARKit
import Foundation

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @State private var buttonText: String = "Delete Mode: OFF"
    @State private var buttonColor: Color = .green
    @State private var placeSphereText: String = "Place Sphere"


        
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
                    if(buttonText == "Delete Mode: OFF"){arViewModel.placeSphere()}
                    else{
                        print("delete sphere mode")
                        arViewModel.deleteSphere()
                    }
                }) {
                    Text(placeSphereText)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Place Lines Button
                Button(action: {
                    arViewModel.createFrame()
                }) {
                    Text("Place Lines")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Change Delete Mode
                Button(action: {
                    // Change app state
                    changeButtonAppearance()
                }) {
                    Text(buttonText)
                        .padding()
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Send Data
                Button(action: {
                    // Change app state
                    print("Sending waypoints now")
//                        arViewModel.printWaypoints()
                    Task{
                        await arViewModel.sendRequest()
                    }

                }) {
                    Text("Send Waypoints")
                        .padding()
                        .background(buttonColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

            }
            .background(.gray)
            .position(x: UIScreen.main.bounds.width / 2, y: (UIScreen.main.bounds.height) - 150) // Set the position within the ZStack
        }
    }
    
    // Function to change the button text and color
    func changeButtonAppearance() {
        // Toggle the button text and color for demonstration
        if buttonText == "Delete Mode: OFF" {
            buttonText = "Delete Mode: ON"
            placeSphereText = "Delete Sphere"
            buttonColor = .red
        } else {
            buttonText = "Delete Mode: OFF"
            placeSphereText = "Place Sphere"
            buttonColor = .green
        }
    }
}



class ARViewModel: ObservableObject {
    @Published var arView: ARView?
    // Types of structures
    
    // FRAME:
    // frame spheres: UUID, position, model
    // frame lines: UUID, models
    @Published var frameSpheres: [(UUID, SIMD3<Float>, ModelEntity)] = []
    @Published var frameLines: [(UUID, ModelEntity)] = []

    // WAYPOINTS:
    // waypoint spheres: UUID, position, model
    // Waypoint lines: UUID, models
    @Published var waypointSpheres: [(UUID, SIMD3<Float>, ModelEntity)] = []
    @Published var waypointLines: [(UUID, ModelEntity)] = []
    
    var waypointsArray: [[String: Float]] = []
    
    var centerPoint: SIMD2<Float> = SIMD2<Float>(0,0)
    let xBounds: [(Int, Int)] = [(-1000, 1000)]
    let zBounds: [(Int, Int)] = [(-1000, 1000)]
    
    //                  //
    // Helper Functions //
    //                  //
    
    func angleAndTranslation(point1: SIMD3<Float>, point2: SIMD3<Float>) -> (returnAngle: Float, xdif: Float, zdif: Float){
        let xdif = point2.x - point1.x
        let zdif = point2.z - point1.z
        let returnAngle: Float = atan(xdif/zdif)
        return (returnAngle, xdif, zdif)
    }
    
    func returnWayPointsArray() -> [[String: Float]] {
        print("Waypoint Coordinates (x, z):")
        waypointsArray = []
        
        for (_, position, _) in waypointSpheres {
            let x = position.x
            let z = position.z
            
            waypointsArray.append(["x":x, "z":z])
        }
        
//        print(waypointsArray)
        return waypointsArray
    }
    
    // Asynchronous function to send a request

    func sendRequest () async {
        // Define the URL you want to request
        let apiUrlStr = "http://192.168.0.226:8080/test"
        // Create a URL object from the string
        if let apiUrl = URL(string: apiUrlStr) {
            
            // Create a URLSession instance
            let session = URLSession.shared
            
            // Define the data you want to upload
//            let jsonPayload = ["key": "value"]
            let jsonPayload = returnWayPointsArray()
            
            // Convert the JSON payload to Data
            do {
                
                // Create a URLRequest with the URL and set the HTTP method to POST
                var request = URLRequest(url: apiUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let jsonData = try? JSONSerialization.data(withJSONObject: jsonPayload)
                request.httpBody = jsonData

                // Create an upload task using URLSessionUploadTask
                let task = session.dataTask(with: request) { (data, response, error) in
                    // Handle the response here
                    
                    // Check for errors if received from server
                    if let error = error {
                        print("Error: \(error)")
                        return
                    }
                    
                    // Check if data is available
                    if let responseData = data {
                        // Process the response data as needed
                        let responseString = String(data: responseData, encoding: .utf8)
                        print(responseString)
                    }
                }
                // Resume the upload task to initiate the request
                task.resume()
            }
        } else {
            print("URL is invalid")
        }

    }
    
    //                       //
    //      Line Creators    //
    //                       //
    
    // Create the lines for the field of play
    func createFrame(){
        guard let arView = arView else { return }
        
        var nextPoint = 1
        for i in 0...3 {
            print("=========================================")
            print("Iteration \(i)")
//            print("The current sphere is: \(frameSpheres[i])")
//            print("The next sphere is: \(frameSpheres[nextPoint])")
            
            // Create Lines
            let anchorEntity = AnchorEntity(world: frameSpheres[i].1)
            let lineID = UUID()
            let lineEntity = createLine(from: frameSpheres[i].1, to:  frameSpheres[nextPoint].1, parent: anchorEntity )
            
            frameLines.append((lineID, lineEntity))

            // Add the anchor to the scene
            arView.scene.addAnchor(anchorEntity)
            
            nextPoint = nextPoint + 1
            if(nextPoint == 4) {nextPoint = 0}
        }
    }
    
    // Create the lines for the robot path
    func createPath(){
        guard let arView = arView else { return }
        
        print("=========================================")
        print("Creating a new path with \(waypointLines.count) lines")
        
        // if line entieies is not 0, delete lines
        if(waypointLines.count != 0){
            for (uuid, _) in waypointLines {
                deleteLine(lineID: uuid)
            }
        }
        
        if(waypointSpheres.count == 1){return}
        var nextPoint = 1
        for i in 0...(waypointSpheres.count - 1) {
            print("--------------------------")
            print("Iteration \(i)")
//            print("The current sphere is: \(waypointSpheres[i])")
//            print("The next sphere is: \(waypointSpheres[nextPoint])")
            
            // Create Line
            
            let anchorEntity = AnchorEntity(world: waypointSpheres[i].1)
            let lineID = UUID()
            let lineEntity = createLine(from: waypointSpheres[i].1, to: waypointSpheres[nextPoint].1, parent: anchorEntity)
            
            waypointLines.append((lineID, lineEntity))
                    
            // Add the anchor to the scene
            arView.scene.addAnchor(anchorEntity)
            
            nextPoint = nextPoint + 1
            if(nextPoint == waypointSpheres.count) {nextPoint = 0}
        }
        print("=========================================")
    }
    
    
    
    //                                  //
    //              Delete              //
    //                                  //
    
    // Delete lines for the robot path
    func deleteLine(lineID: UUID) {
        guard let lineEntity = waypointLines.first(where: { $0.0 == lineID })?.1 else {return}
                
        lineEntity.removeFromParent()
        waypointLines = waypointLines.filter { $0.0 != lineID }
    }
    
    // Delete poiint for the robot path
    func deleteWaypoint(lineID: UUID) {
        guard let pointEntity = waypointSpheres.first(where: { $0.0 == lineID })?.2 else {return}
        
        pointEntity.removeFromParent()
        waypointSpheres = waypointSpheres.filter { $0.0 != lineID }
    }
    
    // This function will be to delete a sphere
    func deleteSphere(){
        guard let arView = arView else { return }
        
        var smallestUUID = UUID()
        var smallestDistance: Float = 10000;

        
        print("Delete Function Called")
        
        // check to see if there are any waypoints
        print("There are \(waypointSpheres.count) waypoints in the robot path")
        
        if (waypointSpheres.count < 1){print("No points to delete")}
        
        //find the closest point
        else{
            // shoot out a raycast
            let raycastResult = arView.raycast(from: arView.center,
                                               allowing: .estimatedPlane,
                                               alignment: .horizontal)
            
            if let result = raycastResult.first {
                let anchor = AnchorEntity(world: result.worldTransform)
                
                // Save the position of the placed sphere
                let position = result.worldTransform.columns.3
                let spherePosition = SIMD3<Float>(position.x, position.y, position.z)
                
                for (uuid, position, _) in waypointSpheres {
                    let currentDistance = distance(spherePosition, position)
                    
                    if (currentDistance < smallestDistance){
                        smallestUUID = uuid
                        smallestDistance = currentDistance
                    }
                }
            }
            
            print("Deleting Sphere with UUID: \(smallestUUID)")
            
            // Delete the sphere
            guard let pointEntity = waypointSpheres.first(where: { $0.0 == smallestUUID })?.2 else {return}
            pointEntity.removeFromParent()
            waypointSpheres = waypointSpheres.filter { $0.0 != smallestUUID }
            
            // Recreate the path
            createPath()

        }
    }
    
    //                                  //
    //              Draw                //
    //                                  //

    // Draw the lines for the robot path
    func drawPath(point1: SIMD3<Float>, point2: SIMD3<Float>) {

        
    }
    
    // Create a line given two paths
    func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>, parent: Entity) -> ModelEntity {
        let (angle, xdif, zdif) = angleAndTranslation(point1: start, point2: end)
        
        let length = distance(start, end)
        let boxMesh = MeshResource.generateBox(size: 0.02)
        let material = SimpleMaterial(color: .red, isMetallic: false)
        let lineEntity = ModelEntity(mesh: boxMesh, materials: [material])
        
        lineEntity.scale = [1, 1, (length / 0.02)]
        lineEntity.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
        lineEntity.transform.translation = [(xdif/2), 0, (zdif/2)]

        parent.addChild(lineEntity)
        
        return lineEntity
    }
    

    
    
    // Place a sphere
    // if there are +4 spheres, make them green and add them to an entity array
    func placeSphere() {
        guard let arView = arView else { return }
        
        let frameCount = frameSpheres.count
        
        // If you are placing a sphere for the frame
        if (frameCount < 4){
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

                print("The length of frameSpheres is: \(frameCount)")
                
                frameSpheres.append((sphereId, spherePosition, model))
            }
        }
        
        // Else, you are placing a sphere for the path
        // This means there are 4+ points
        else{
            
            // Setup the Sphere
            let mesh = MeshResource.generateSphere(radius: 0.05)
            let material = SimpleMaterial(color: .green, roughness: 0.15, isMetallic: false)
            let model = ModelEntity(mesh: mesh, materials: [material])
            
            // Shoot a raycast out to get the position
            let raycastResult = arView.raycast(from: arView.center,
                                               allowing: .estimatedPlane,
                                               alignment: .horizontal)
            
            // If the raycast works continue
            if let result = raycastResult.first {
                
                // Get the position of the sphere
                let position = result.worldTransform.columns.3
                let anchor = AnchorEntity(world: result.worldTransform)
                anchor.addChild(model)
                arView.scene.addAnchor(anchor)
                
                // Save the position of the placed sphere
                let spherePosition = SIMD3<Float>(position.x, position.y, position.z)
                print(spherePosition)

                // Generate a new UUID for this sphere
                let sphereId = UUID()

                // Add the UUID to the model's name for future reference
                model.name = sphereId.uuidString

                print("The length of frameSpheres is: \(frameCount)")
                
                waypointSpheres.append((sphereId, spherePosition, model))
                
                // This is different from frame because the path automically generates
                if(waypointSpheres.count > 1){
                    createPath()
                }
                
            }
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

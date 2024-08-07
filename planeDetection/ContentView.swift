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
//                    arViewModel.placeTriangleSpheresFAKE()
                    arViewModel.placeTriangleSpheres()
                }) {
                    Text("Create Triangle")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    arViewModel.calculateFrameFromTriangle()
                }) {
                    Text("Calculate Frame")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                
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
    let apiUrlStr = "http://192.168.0.15:8080/test"
    
    @Published var arView: ARView?
    // Types of structures
    
    // FRAME:
    // frame spheres: UUID, position, model
    // frame lines: UUID, models
    @Published var frameSpheres: [(UUID, SIMD3<Float>, ModelEntity)] = []
    @Published var frameLines: [(UUID, ModelEntity)] = []
    var frameArray: [[String: Float]] = [] // if Needed, not necessary


    // WAYPOINTS:
    // waypoint spheres: UUID, position, model
    // Waypoint lines: UUID, models
    @Published var waypointSpheres: [(UUID, SIMD3<Float>, ModelEntity)] = []
    @Published var waypointLines: [(UUID, ModelEntity)] = []
        

    // bounds
    // Reminder this is in meters
    let xBounds: [Float] = [-1, 1]
    let zBounds: [Float] = [-1, 1]
    
    var centerPoint4: SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    // NewSetup:
    // waypoint spheres: UUID, position, model
    // Waypoint lines: UUID, models
    @Published var tripleSpheres: [(UUID, SIMD3<Float>, ModelEntity)] = []
    
    
    
    //                  //
    // Helper Functions //
    //                  //
    func translatePoints(oldPoint: Float, dimensionIndex: String) -> Float{
        var newpoint: Float = 0.0
        
        if(dimensionIndex == "x"){newpoint = oldPoint - centerPoint4.x}
        if(dimensionIndex == "y"){newpoint = oldPoint - centerPoint4.y}
                
        return newpoint
    }
    
    
    
    func calculateFrame (leftBall1: SIMD3<Float>, rightBall2: SIMD3<Float>, topBall3: SIMD3<Float>) -> [[String: SIMD3<Float>]] {
        print("In CalculateFrame *************************************")
        // Width
        var wSlope: Float = 0
        var wVector: SIMD3<Float> = SIMD3<Float>(0,0,0)

        // Height
        var hSlope: Float = 0
        var hVector: SIMD3<Float> = SIMD3<Float>(0,0,0)
                
        wSlope = (leftBall1.z - rightBall2.z) / (leftBall1.x - rightBall2.x)
        
        hSlope = -1 / wSlope
        
        let numerator = ((hSlope * topBall3.x) - topBall3.z - (wSlope * leftBall1.x) + leftBall1.z)
        let denumerator = (hSlope - wSlope)
        
        let xAverage = ((leftBall1.y + rightBall2.y + topBall3.y) / 3)
        
        centerPoint4.x = numerator / denumerator
        centerPoint4.z = wSlope * (centerPoint4.x - leftBall1.x) + leftBall1.z
        centerPoint4.y = xAverage
        
                                      
//        print("On the nemurator side: A is \(hSlope), x3 is \(topBall3.x), z3 is \(topBall3.z), x1 is \(leftBall1.x), and z1 is \(leftBall1.z)")
//        print("The wSlope is: \(wSlope) and the hSlope is \(hSlope)")
//        print("The numerator is: \(numerator) and the denumerator is \(denumerator)")
        
        
        // normalize the vectors
        let wDenominator = sqrt( ((rightBall2.x - leftBall1.x)*(rightBall2.x - leftBall1.x)) + ((rightBall2.z - leftBall1.z)*(rightBall2.z - leftBall1.z)) )
        let hDecominator = sqrt( ((topBall3.x - centerPoint4.x)*(topBall3.x - centerPoint4.x)) + ((topBall3.z - centerPoint4.z)*(topBall3.z - centerPoint4.z)) )
                                 
//        let wDistance = distance(rightBall2, leftBall1)
//        let hDistnace = distance(topBall3, centerPoint4)
        
        
        print("The xAverage is: \(xAverage)")
//        print("The manual wdistance is: \(wDenominator)")
//        print("The function wdistance is: \(wDistance)")
                                 
        wVector = (rightBall2 - leftBall1) / wDenominator
        hVector = (topBall3 - centerPoint4) / hDecominator
        
        wVector.y = 0.0
        hVector.y = 0.0
        
        var returnPointsArray: [[String: SIMD3<Float>]] = []
        var nextPoint: SIMD3<Float> = SIMD3<Float>(0,0,0)
        var xChange: SIMD3<Float> = SIMD3<Float>(0,0,0)
        var zChange: SIMD3<Float> = SIMD3<Float>(0,0,0)
        
        // Point 1
        xChange =  (xBounds[0] * wVector)
        zChange = (zBounds[0] * hVector)
        nextPoint = (centerPoint4 + xChange + zChange)
        returnPointsArray.append(["Point1": nextPoint])
        
        // Point 2
        xChange =  (xBounds[0] * wVector)
        zChange = (zBounds[1] * hVector)
        nextPoint = (centerPoint4 + xChange + zChange)
        returnPointsArray.append(["Point2": nextPoint])
        
        // Point 3
        xChange =  (xBounds[1] * wVector)
        zChange = (zBounds[1] * hVector)
        nextPoint = (centerPoint4 + xChange + zChange)
        returnPointsArray.append(["Point3": nextPoint])
        
        // Point 4
        xChange =  (xBounds[1] * wVector)
        zChange = (zBounds[0] * hVector)
        nextPoint = (centerPoint4 + xChange + zChange)
        returnPointsArray.append(["Point4": nextPoint])
        
        
        print("wSlope is: \(wSlope)")
        print("wVector is: \(wVector)")
        print("hVector is: \(hVector)")
        print("The Centroid is: \(centerPoint4)")
        
        print("Out of CalculateFrame *************************************")


        return returnPointsArray
    }
    
    
    func angleAndTranslation(point1: SIMD3<Float>, point2: SIMD3<Float>) -> (returnAngle: Float, xdif: Float, zdif: Float){
        let xdif = point2.x - point1.x
        let zdif = point2.z - point1.z
        let returnAngle: Float = atan(xdif/zdif)
        return (returnAngle, xdif, zdif)
    }
    
    
    
    // This function returns the waypoints for the path of the robot
    // To add, add the recentering
    // This is structured so that it is easy to jsonify to send to the flask api
    func returnWayPointsArray() -> [[String: Float]] {
        print("Waypoint Coordinates (x, z):")
        var waypointsArray: [[String: Float]] = []
        
        for (_, position, _) in waypointSpheres {
            let x = translatePoints(oldPoint: Float(position.x), dimensionIndex: "x")
            let z = translatePoints(oldPoint: Float(position.z), dimensionIndex: "z")
            
            waypointsArray.append(["x":x, "z":z])
        }
        return waypointsArray
    }
    

    
    //                                         //
    //              API Functions              //
    //                                         //

    // Asynchronous function to send a request
    func sendRequest () async {
        print("The waypoints array is: \(returnWayPointsArray()) and I am sending it now")
        
cle        // Create a URL object from the string
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
    
    // Delete poiint for the robot path
    func deleteTrianglePoint(lineID: UUID) {
        guard let pointEntity = tripleSpheres.first(where: { $0.0 == lineID })?.2 else {return}
        
        pointEntity.removeFromParent()
        tripleSpheres = tripleSpheres.filter { $0.0 != lineID }
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
    
    
    
    
    
    
    //                                                  //
    //              Create Line Functions               //
    //                                                  //
    
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
    
    // This functions calculated the frame using the three ball method
    // This functions calls calculateFrame() to compute the calculation
    func calculateFrameFromTriangle (){
        let (uuid0, coordinates1, _) = tripleSpheres[0]
        let (uuid1, coordinates2, _) = tripleSpheres[1]
        let (uuid2, coordinates3, _) = tripleSpheres[2]

        let frameArray: [[String: SIMD3<Float>]] = calculateFrame(leftBall1: coordinates1, rightBall2: coordinates2, topBall3: coordinates3)

        print("++++++++++++++++++++++++++++++++++++++++++")
        print("The triangle points are: \(tripleSpheres)")
        print("The waypoints for the frame are: \(frameArray)")
        
        for i in 0...3{
            // Place the Spheres
            let itemInArray = frameArray[i]
            if let cordinates = itemInArray["Point" + String(i+1)] {
                print("Placing Sphere at point: \(cordinates)")
                let model = placeSphereAt(point1: cordinates)
                frameSpheres.append((UUID(), cordinates, model))
//                print("The size of frame spheres is: \(frameSpheres.count)")
            }
            else {print("Point" + String(i) + " not found in the dictionary")}
        }
        
//        print("Not its time to create the frame")
//        print("FrameSpheres is \(frameSpheres)")
        print("++++++++++++++++++++++++++++++++++++++++++")
        createFrame()
        
        deleteTrianglePoint(lineID: uuid0)
        deleteTrianglePoint(lineID: uuid1)
        deleteTrianglePoint(lineID: uuid2)
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
    
    
    
    
    
    
    
    //                                                    //
    //              Place Sphere  Functions               //
    //                                                    //
    
    func placeSphereAt(point1: SIMD3<Float>) -> ModelEntity{
        guard let arView = arView else { return ModelEntity() }

        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])

        let anchor = AnchorEntity(world: point1)

        anchor.addChild(model)
        arView.scene.addAnchor(anchor)

        return model
    }

    
    func placeTriangleSpheres(){
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

//            placeSphereAt(point1: spherePosition)
            tripleSpheres.append((sphereId, spherePosition, model))
            
        }
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

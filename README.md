# ARDemo
_Working With ARKit_

Augmented Reality (AR) has been around for a number of years, but it has only been in the past year that AR has finally been making some inroads into the mainstream, starting with the mobile game Pokémon GO.

Now Apple is opening up the capabilities of AR to developers and millions of AR-ready iOS devices with the introduction of the new ARKit framework.  Developers have quickly embraced the new capabilities provided by ARKit by developing useful utilities to games enhanced by the AR experience.  

There are numerous articles currently available about how to initially set up an ARKit project, so this post will focus more on specific topics when developing with ARKit and SceneKit.

This article makes use of a [sample AR demo project](https://github.com/edenwaith/ARDemo) which detects a plane, loads in a 3D model of a dragon, places the model on the plane, and then animates the dragon when it has been tapped.


## Plane Detection ##

One of the key aspects to AR is for the device to be able to inspect its environment so it can learn how to interact with its surroundings, especially when trying to place virtual objects on a flat surface.  Since ARKit does not come with a [Hervé Villechaize](http://www.imdb.com/name/nm0898199/?ref_=fn_al_nm_1) module, your AR app will need to implement the `ARSCNViewDelegate` to help find "da plane".

Plane detection is initially disabled, so it needs to be set, otherwise the device will not look for available surfaces.
To enable plane detection, ensure that the `ARWorldTrackingConfiguration` object's `planeDetection` property has been set to `.horizontal`.  

```swift
// Create a session configuration
let configuration = ARWorldTrackingConfiguration()
configuration.planeDetection = .horizontal
configuration.isLightEstimationEnabled = true

// Run the view's session
sceneView.session.run(configuration)
```

ARKit currently only supports the detection of horizontal planes, but there is the potential of vertical plane detection in a future version of iOS.  

Plane detection is far from a precise science at this point, and it usually takes at least several seconds to detect a suitable plane.  You might need to move your iOS device around so it gains knowledge of its environment so it can better estimate the distance to surrounding objects.

To aid in detecting a plane, set the  `sceneView.debugOptions = [ ARSCNDebugOptions.showFeaturePoints ]` to provide the yellow dots, which indicates that the camera is trying to detect reference points in the environment.  Objects which are shiny or lack any proper definition make it difficult for the device to obtain a decent reference point and to be able to distinguish unique points in the environment.  Areas with poor lighting conditions can also compound these problems.  If you are not seeing many yellow feature points, slowly move around the area and point the device's camera at different objects to help determine which surfaces can be identified.  

![](detecting_plane.png "Detecting a plane")

Once a plane is detected, the `ARSCNViewDelegate` method `renderer(_:didAdd:for:)` is called.  In this example, we check if the argument `anchor` is an `ARPlaneAnchor`, and if so, we then save this as our `planeAnchor`, which will be used as the base where to place the 3D model.

```swift
func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
	
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
	
    if self.planeAnchor == nil {
        self.planeAnchor = planeAnchor
        self.loadDragonScene(with: planeAnchor)
    }
}
```


## 3D Models in SceneKit ##

ARKit integrates well with SpriteKit and SceneKit, Apple's respective 2D and 3D frameworks, which have been available for macOS and iOS for a number of years.  Due to these years of development, Apple already has mature platforms which can be quickly hooked into an AR project to add 2D or 3D virtual elements. 

There's a wide variety of 3D model formats available, but for this project, we are working with [COLLADA](https://en.wikipedia.org/wiki/COLLADA) (.dae) files.  COLLADA is an open 3D format which many 3D modeling apps support.  It was originally intended as an interchange format between competing 3D standards, but it has gained the support of a number of software tools, game engines and applications.  COLLADA is also well supported in the Apple ecosystem, including the macOS Finder, Preview, and Xcode.

If your model has image textures which are referenced in the model file, then copy the `.dae` file and its associated image assets into the `art.scnassets` folder.  One of the advantages of COLLADA being an open XML format is that the model file can be opened and edited with a standard text editor, which can be particularly useful if the image paths were improperly referenced (absolute path versus a relative path).

```swift
let dragonScene = SCNScene(named: "art.scnassets/Dragon_Baked_Actions_fbx_6.dae")!
let position = anchor.transform

// Iterate through all of the nodes and add them to the dragonNode object
for childNode in dragonScene.rootNode.childNodes {
    self.dragonNode.addChildNode(childNode)
}

// Scale and position the node
let scale:Float = 0.01
self.dragonNode.scale = SCNVector3(x: scale, y: scale, z: scale)
self.dragonNode.position = SCNVector3(x: position.columns.3.x, y: position.columns.3.y, z: position.columns.3.z)

// Add the dragonNode to the scene
sceneView.scene.rootNode.addChildNode(self.dragonNode)
self.dragonNode.isPaused = true // Initially pause any animations
```

![](dragon_model.png "Loading in the dragon model")
 

## Clearing Out Old Scenes ##
Loading in 3D models and the associated textures can be extremely memory intensive, so it is essential that any unused resources are properly released.

When removing a child node from a scene, it is not good enough to just call the node's `removeFromParentNode()` method.  Any material objects from the node's geometry also need to be set to `nil` before removing the node from it's parent.

```swift
func clearScene() {

    sceneView.session.pause()
    sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
        // Free up memory when removing the node by removing any textures
        node.geometry?.firstMaterial?.normal.contents = nil
        node.geometry?.firstMaterial?.diffuse.contents = nil
        node.removeFromParentNode()
    }
}
```

## Hit Detection ##

Being able to add objects to a scene is a key element for creating an augmented experience, but it does not provide much usefulness if one cannot interact with the environment.  For this demonstration, tapping on the dragon will toggle its animation.

Upon tapping the screen, the `sceneView` will perform a hit test by extending a ray from where the screen was touched and will return an array of all of the objects which intersected the ray.  The first object in the array is selected, which represents the object closest to the camera.

Since a 3D object might be comprised of multiple smaller nodes, the selected node might be a child node of a larger object.  To check if the dragon model was tapped, the selected node's parent node is compared against the dragon node.  If so, this will then call a method to toggle the model's animation.

```swift
func registerTapRecognizer() {
    let tapGestureRecognizer =  UITapGestureRecognizer (target:self ,action : #selector (screenTapped))
    self.sceneView.addGestureRecognizer(tapGestureRecognizer)
}

@objc func screenTapped(tapRecognizer: UITapGestureRecognizer) {
	
    let tappedLocation = tapRecognizer.location(in: self.sceneView)
    let hitResults = self.sceneView.hitTest(tappedLocation, options: [:])
    
    if hitResults.count > 0 {
        guard let firstHitResult = hitResults.first else {
            return
        }
        
        if self.dragonNode == firstHitResult.node.parent {
            self.toggleDragonAnimation()
        }
    }
}
```

## Animations ##

Not all 3D models are static entities and some include animation effects.  There are a variety of ways to start and stop  animations, whether it is for a particular object or for the entire scene.

To toggle all animations for the scene requires just a single line of code:

`self.sceneView.scene.isPaused = !self.sceneView.scene.isPaused`

Toggling the animations for just a single node has similar functionality:

`self.dragonNode.isPaused = !self.dragonNode.isPaused`

<!-- https://stackoverflow.com/questions/29692388/scenekit-stop-continuously-looping-collada-animation -->
These are simple methods to toggle the overall animation, but if you need more fine-grained control of the animations, then you will need to iterate through your `SCNNode` and modify each of the embedded animations.

![](arkit-animation.gif "Animated dragon model")

## Conclusion ##

Augmented Reality is in its nascent stages of development, which  will provide many new and interesting ways for us to be able to use our mobile devices to interact with the world, whether it is for information, utility, or fun.

As the possibilities of what can be achieved with AR are explored further, more and more developers will delve into this new realm and see what they can create.  Documentation and blog posts are invaluable in helping to reduce the initial learning curve and avoid some of the more troublesome hurtles that others have previously encountered, as this post aimed to accomplish by providing some tips on how to implement several common tasks when working with ARKit.
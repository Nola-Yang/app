//
//  HeadModel3DView.swift
//  HeadacheDiary
//
//  Created by 俟岳安 on 2025-06-29.
//

import SwiftUI
import SceneKit
import ModelIO

struct HeadModel3DView: View {
    @Binding var selectedLocations: Set<HeadacheLocation>
    @Binding var selectedCustomLocations: Set<String>
    @State private var scene = SCNScene()
    @State private var cameraNode = SCNNode()
    @State private var headNode = SCNNode()
    @State private var locationNodes: [HeadacheLocation: SCNNode] = [:]
    @State private var isRotating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 3D头部模型
            ZStack {
                InteractiveSceneView(
                    selectedLocations: $selectedLocations,
                    scene: scene,
                    pointOfView: cameraNode
                )
                .frame(height: 300)
                .cornerRadius(12)
                .shadow(radius: 8)
                
                // 控制按钮覆盖层
                VStack {
                    HStack {
                        Button(action: {
                            resetCamera()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            toggleRotation()
                        }) {
                            Image(systemName: isRotating ? "pause.circle" : "play.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            
            // 位置说明
            VStack(alignment: .leading, spacing: 8) {
                Text("点击头部模型上的区域选择疼痛位置")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 可以旋转和缩放模型以获得更好的视角")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("📦 支持导入3D模型文件：将.scn或.obj文件添加到应用包中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("🔴 点击任何区域都会短暂变红并映射到头痛位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 选中的位置显示
                if !selectedLocations.isEmpty || !selectedCustomLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已选择的位置:")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 4) {
                            ForEach(Array(selectedLocations), id: \.self) { location in
                                Text(location.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                            
                            ForEach(Array(selectedCustomLocations).sorted(), id: \.self) { location in
                                Text(location)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .onAppear {
            setupScene()
        }
        .onChange(of: selectedLocations) {
            updateLocationHighlights()
        }
    }
    
    private func setupScene() {
        // 创建更逼真的大脑/头部模型
        createBrainModel()
        
        // 设置摄像机
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // 创建可点击的大脑区域
        createBrainRegions()
        
        // 添加环境光照
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 400
        scene.rootNode.addChildNode(ambientLight)
        
        // 添加主光源
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.intensity = 800
        mainLight.light?.castsShadow = true
        mainLight.position = SCNVector3(3, 3, 3)
        mainLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(mainLight)
        
        // 添加补光
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 300
        fillLight.position = SCNVector3(-2, 1, 2)
        fillLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLight)
    }
    
    private func createBrainModel() {
        // 尝试加载外部3D模型，如果失败则使用程序生成的模型
        if !loadExternalModel() {
            print("📦 使用程序生成的头骨模型")
            createSkullBase()
            createBrainRegionsDetailed()
        }
        scene.rootNode.addChildNode(headNode)
    }
    
    private func loadExternalModel() -> Bool {
        // 尝试从应用包中加载3D模型文件
        let modelNames = ["skull_model.scn", "brain_model.scn", "head_anatomy.scn", "skull.obj", "brain.obj"]
        
        for modelName in modelNames {
            if let modelPath = Bundle.main.path(forResource: modelName.components(separatedBy: ".").first, 
                                               ofType: modelName.components(separatedBy: ".").last) {
                
                print("📦 找到3D模型文件: \(modelName)")
                
                if modelName.hasSuffix(".scn") {
                    return loadSCNModel(path: modelPath)
                } else if modelName.hasSuffix(".obj") {
                    return loadOBJModel(path: modelPath)
                }
            }
        }
        
        print("📦 未找到外部3D模型文件，将使用内置模型")
        return false
    }
    
    private func loadSCNModel(path: String) -> Bool {
        do {
            let modelScene = try SCNScene(url: URL(fileURLWithPath: path))
            
            // 获取模型的根节点
            if let modelRootNode = modelScene.rootNode.childNodes.first {
                // 设置模型的材质和缩放
                setupImportedModelMaterials(node: modelRootNode)
                
                // 添加到头部节点
                headNode.addChildNode(modelRootNode)
                
                // 为导入的模型创建可点击区域
                createClickableRegionsForImportedModel(modelNode: modelRootNode)
                
                print("✅ 成功加载SCN模型")
                return true
            }
        } catch {
            print("❌ 加载SCN模型失败: \(error)")
        }
        return false
    }
    
    private func loadOBJModel(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        // 创建MDLAsset来加载OBJ文件
        let asset = MDLAsset(url: url)
        
        // 使用SceneKit的内置方法加载3D资源
        let sceneSource = SCNSceneSource(url: url, options: nil)
        
        if let scene = sceneSource?.scene() {
            // 遍历场景中的节点
            for childNode in scene.rootNode.childNodes {
                if childNode.geometry != nil {
                    // 设置模型的材质和缩放
                    setupImportedModelMaterials(node: childNode)
                    
                    // 添加到头部节点
                    headNode.addChildNode(childNode)
                    
                    // 为导入的模型创建可点击区域
                    createClickableRegionsForImportedModel(modelNode: childNode)
                    
                    print("✅ 成功加载OBJ模型")
                    return true
                }
            }
        }
        
        print("❌ OBJ文件加载失败或没有找到有效的几何体")
        return false
    }
    
    private func setupImportedModelMaterials(node: SCNNode) {
        // 递归设置所有子节点的材质
        node.enumerateChildNodes { childNode, _ in
            if let geometry = childNode.geometry {
                // 为每个几何体设置半透明材质
                for material in geometry.materials {
                    material.transparency = 0.85
                    material.cullMode = .back
                    
                    // 如果没有设置颜色，使用默认的骨骼色
                    if material.diffuse.contents == nil {
                        material.diffuse.contents = UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 0.9)
                    }
                }
            }
        }
        
        // 调整模型大小以适应场景
        let boundingBox = node.boundingBox
        let modelSize = max(boundingBox.max.x - boundingBox.min.x, 
                           max(boundingBox.max.y - boundingBox.min.y, 
                               boundingBox.max.z - boundingBox.min.z))
        
        // 将模型缩放到适当大小（大约2个单位）
        let targetSize: Float = 2.0
        let scale = targetSize / modelSize
        node.scale = SCNVector3(scale, scale, scale)
        
        // 居中模型
        let center = SCNVector3(
            (boundingBox.max.x + boundingBox.min.x) / 2,
            (boundingBox.max.y + boundingBox.min.y) / 2,
            (boundingBox.max.z + boundingBox.min.z) / 2
        )
        node.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
    }
    
    private func createClickableRegionsForImportedModel(modelNode: SCNNode) {
        // 为导入的模型创建不可见的点击区域覆盖层
        let clickableRegions: [(HeadacheLocation, SCNVector3, Float)] = [
            (.forehead, SCNVector3(0, 0.5, 0.9), 0.3),     // 前额区域
            (.leftSide, SCNVector3(-0.8, 0, 0.2), 0.25),   // 左侧太阳穴
            (.rightSide, SCNVector3(0.8, 0, 0.2), 0.25),   // 右侧太阳穴
            (.temple, SCNVector3(0.8, 0.1, 0.6), 0.2),     // 太阳穴
            (.face, SCNVector3(0, -0.2, 1.0), 0.25)        // 面部区域
        ]
        
        for (location, position, radius) in clickableRegions {
            // 创建不可见的球体作为点击区域
            let clickSphere = SCNSphere(radius: CGFloat(radius))
            let clickMaterial = SCNMaterial()
            clickMaterial.diffuse.contents = UIColor.clear
            clickMaterial.transparency = 0.0
            clickSphere.materials = [clickMaterial]
            
            let clickNode = SCNNode(geometry: clickSphere)
            clickNode.position = position
            clickNode.name = location.rawValue
            
            // 添加到模型节点
            modelNode.addChildNode(clickNode)
            locationNodes[location] = clickNode
        }
        
        // 为整个导入的模型添加通用点击检测
        addUniversalClickDetection(to: modelNode)
    }
    
    private func addUniversalClickDetection(to modelNode: SCNNode) {
        // 为模型的所有子节点添加名称，以便点击检测
        modelNode.enumerateChildNodes { childNode, _ in
            if childNode.name == nil && childNode.geometry != nil {
                // 根据节点位置推断解剖区域
                let position = childNode.position
                
                if position.z > 0.5 {
                    childNode.name = "frontal_region"
                } else if position.x < -0.3 {
                    childNode.name = "left_temporal_region"
                } else if position.x > 0.3 {
                    childNode.name = "right_temporal_region"
                } else if position.z < -0.5 {
                    childNode.name = "occipital_region"
                } else {
                    childNode.name = "parietal_region"
                }
            }
        }
    }
    
    private func createSkullBase() {
        // 1. 主要颅骨结构 - 使用多个几何体组合
        
        // 颅顶 - 椭球形但更精确
        let craniumTop = SCNSphere(radius: 1.0)
        craniumTop.segmentCount = 128 // 超高分辨率
        
        let craniumMaterial = SCNMaterial()
        craniumMaterial.diffuse.contents = UIColor(red: 0.98, green: 0.96, blue: 0.94, alpha: 0.9)
        craniumMaterial.specular.contents = UIColor.white
        craniumMaterial.shininess = 0.3
        craniumMaterial.transparency = 0.85
        craniumTop.materials = [craniumMaterial]
        
        let craniumNode = SCNNode(geometry: craniumTop)
        craniumNode.name = "cranium"
        craniumNode.scale = SCNVector3(0.95, 1.15, 1.05) // 更真实的头骨比例
        craniumNode.position = SCNVector3(0, 0.1, 0)
        
        // 2. 额骨 - 前额部分
        let frontalBone = createCustomSkullPart(
            radius: 0.7,
            position: SCNVector3(0, 0.35, 0.8),
            scale: SCNVector3(1.3, 0.6, 0.7),
            name: "frontal_bone",
            color: UIColor(red: 0.96, green: 0.94, blue: 0.92, alpha: 0.9)
        )
        
        // 3. 顶骨 - 头顶部分
        let parietalBone = createCustomSkullPart(
            radius: 0.8,
            position: SCNVector3(0, 0.7, 0),
            scale: SCNVector3(1.5, 0.4, 1.2),
            name: "parietal_bone",
            color: UIColor(red: 0.97, green: 0.95, blue: 0.93, alpha: 0.9)
        )
        
        // 4. 颞骨 - 两侧太阳穴
        let leftTemporalBone = createCustomSkullPart(
            radius: 0.5,
            position: SCNVector3(-0.9, 0.1, 0.2),
            scale: SCNVector3(0.7, 1.1, 1.3),
            name: "left_temporal_bone",
            color: UIColor(red: 0.95, green: 0.93, blue: 0.91, alpha: 0.9)
        )
        
        let rightTemporalBone = createCustomSkullPart(
            radius: 0.5,
            position: SCNVector3(0.9, 0.1, 0.2),
            scale: SCNVector3(0.7, 1.1, 1.3),
            name: "right_temporal_bone",
            color: UIColor(red: 0.95, green: 0.93, blue: 0.91, alpha: 0.9)
        )
        
        // 5. 枕骨 - 后脑勺
        let occipitalBone = createCustomSkullPart(
            radius: 0.6,
            position: SCNVector3(0, 0.2, -1.0),
            scale: SCNVector3(1.2, 0.9, 0.6),
            name: "occipital_bone",
            color: UIColor(red: 0.94, green: 0.92, blue: 0.90, alpha: 0.9)
        )
        
        // 6. 蝶骨 - 侧面眼眶区域
        let leftSphenoidBone = createCustomSkullPart(
            radius: 0.3,
            position: SCNVector3(-0.6, 0.0, 0.7),
            scale: SCNVector3(0.8, 0.6, 0.8),
            name: "left_sphenoid_bone",
            color: UIColor(red: 0.93, green: 0.91, blue: 0.89, alpha: 0.9)
        )
        
        let rightSphenoidBone = createCustomSkullPart(
            radius: 0.3,
            position: SCNVector3(0.6, 0.0, 0.7),
            scale: SCNVector3(0.8, 0.6, 0.8),
            name: "right_sphenoid_bone",
            color: UIColor(red: 0.93, green: 0.91, blue: 0.89, alpha: 0.9)
        )
        
        // 添加所有骨骼部分
        headNode.addChildNode(craniumNode)
        headNode.addChildNode(frontalBone)
        headNode.addChildNode(parietalBone)
        headNode.addChildNode(leftTemporalBone)
        headNode.addChildNode(rightTemporalBone)
        headNode.addChildNode(occipitalBone)
        headNode.addChildNode(leftSphenoidBone)
        headNode.addChildNode(rightSphenoidBone)
    }
    
    private func createCustomSkullPart(radius: Float, position: SCNVector3, scale: SCNVector3, name: String, color: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: CGFloat(radius))
        geometry.segmentCount = 64
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.25
        material.transparency = 0.88
        geometry.materials = [material]
        
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position
        node.scale = scale
        
        return node
    }
    
    private func createBrainRegionsDetailed() {
        // 在头骨内创建详细的大脑区域
        let brainRegions = [
            // 大脑皮层区域
            ("frontal_cortex", SCNVector3(0, 0.3, 0.6), SCNVector3(1.1, 0.7, 0.8), UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 0.6)),
            ("parietal_cortex", SCNVector3(0, 0.5, -0.1), SCNVector3(1.3, 0.6, 1.0), UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 0.6)),
            ("temporal_cortex_left", SCNVector3(-0.7, 0, 0.3), SCNVector3(0.7, 0.9, 1.1), UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 0.6)),
            ("temporal_cortex_right", SCNVector3(0.7, 0, 0.3), SCNVector3(0.7, 0.9, 1.1), UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 0.6)),
            ("occipital_cortex", SCNVector3(0, 0.2, -0.8), SCNVector3(1.0, 0.7, 0.6), UIColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.6)),
            
            // 深层结构
            ("cerebellum", SCNVector3(0, -0.2, -0.7), SCNVector3(0.8, 0.6, 0.6), UIColor(red: 0.95, green: 0.85, blue: 0.9, alpha: 0.7)),
            ("brain_stem", SCNVector3(0, -0.3, 0), SCNVector3(0.3, 0.8, 0.3), UIColor(red: 0.9, green: 0.95, blue: 0.85, alpha: 0.7))
        ]
        
        for (name, position, scale, color) in brainRegions {
            let region = SCNSphere(radius: 0.4)
            region.segmentCount = 32
            
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.transparency = 0.7
            material.specular.contents = UIColor.white
            material.shininess = 0.1
            region.materials = [material]
            
            let regionNode = SCNNode(geometry: region)
            regionNode.name = name
            regionNode.position = position
            regionNode.scale = scale
            
            headNode.addChildNode(regionNode)
        }
    }
    
    private func createBrainRegions() {
        // 创建可点击的大脑区域标记，与大脑解剖位置对应
        let regions: [(HeadacheLocation, SCNVector3, UIColor, Float)] = [
            (.forehead, SCNVector3(0, 0.3, 1.2), .systemRed, 0.15),      // 额头 - 对应额叶前部
            (.leftSide, SCNVector3(-1.0, 0, 0.5), .systemGreen, 0.12),   // 左侧 - 对应左颞叶
            (.rightSide, SCNVector3(1.0, 0, 0.5), .systemBlue, 0.12),    // 右侧 - 对应右颞叶
            (.temple, SCNVector3(0.9, 0.1, 0.8), .systemOrange, 0.10),   // 右太阳穴
            (.face, SCNVector3(0, -0.1, 1.3), .systemPurple, 0.13)       // 面部 - 前额下部
        ]
        
        for (location, position, color, radius) in regions {
            // 创建发光的区域标记
            let regionGeometry = SCNSphere(radius: CGFloat(radius))
            regionGeometry.segmentCount = 16
            
            let regionMaterial = SCNMaterial()
            regionMaterial.diffuse.contents = color.withAlphaComponent(0.3)
            regionMaterial.emission.contents = color.withAlphaComponent(0.6)
            regionMaterial.transparency = 0.7
            regionMaterial.fillMode = .fill
            regionGeometry.materials = [regionMaterial]
            
            let regionNode = SCNNode(geometry: regionGeometry)
            regionNode.position = position
            regionNode.name = location.rawValue
            
            // 设置初始状态
            let isSelected = selectedLocations.contains(location)
            regionNode.opacity = isSelected ? 1.0 : 0.4
            regionNode.scale = isSelected ? SCNVector3(1.3, 1.3, 1.3) : SCNVector3(1.0, 1.0, 1.0)
            
            headNode.addChildNode(regionNode)
            locationNodes[location] = regionNode
            
            // 添加悬浮动画
            let floatAction = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 2.0),
                SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 2.0)
            ])
            let repeatFloatAction = SCNAction.repeatForever(floatAction)
            regionNode.runAction(repeatFloatAction)
            
            // 添加发光脉动效果
            let glowAction = SCNAction.sequence([
                SCNAction.customAction(duration: 3.0) { node, elapsedTime in
                    let intensity = 0.6 + 0.4 * sin(elapsedTime * 2.0)
                    if let material = node.geometry?.materials.first {
                        material.emission.contents = color.withAlphaComponent(intensity)
                    }
                }
            ])
            let repeatGlowAction = SCNAction.repeatForever(glowAction)
            regionNode.runAction(repeatGlowAction)
        }
        
        // 添加左太阳穴
        let leftTempleGeometry = SCNSphere(radius: 0.10)
        leftTempleGeometry.segmentCount = 16
        
        let leftTempleMaterial = SCNMaterial()
        leftTempleMaterial.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.3)
        leftTempleMaterial.emission.contents = UIColor.systemOrange.withAlphaComponent(0.6)
        leftTempleMaterial.transparency = 0.7
        leftTempleGeometry.materials = [leftTempleMaterial]
        
        let leftTempleNode = SCNNode(geometry: leftTempleGeometry)
        leftTempleNode.position = SCNVector3(-0.9, 0.1, 0.8) // 左太阳穴
        leftTempleNode.name = HeadacheLocation.temple.rawValue + "_left"
        
        let isTempleSelected = selectedLocations.contains(.temple)
        leftTempleNode.opacity = isTempleSelected ? 1.0 : 0.4
        leftTempleNode.scale = isTempleSelected ? SCNVector3(1.3, 1.3, 1.3) : SCNVector3(1.0, 1.0, 1.0)
        
        headNode.addChildNode(leftTempleNode)
        
        // 为左太阳穴添加相同的动画
        let leftFloatAction = SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 2.0),
            SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 2.0)
        ])
        let leftRepeatFloatAction = SCNAction.repeatForever(leftFloatAction)
        leftTempleNode.runAction(leftRepeatFloatAction)
        
        let leftGlowAction = SCNAction.sequence([
            SCNAction.customAction(duration: 3.0) { node, elapsedTime in
                let intensity = 0.6 + 0.4 * sin(elapsedTime * 2.0)
                if let material = node.geometry?.materials.first {
                    material.emission.contents = UIColor.systemOrange.withAlphaComponent(intensity)
                }
            }
        ])
        let leftRepeatGlowAction = SCNAction.repeatForever(leftGlowAction)
        leftTempleNode.runAction(leftRepeatGlowAction)
        
        // 添加标签文字（可选）
        addRegionLabels()
    }
    
    private func addRegionLabels() {
        let labels: [(String, SCNVector3, UIColor)] = [
            ("额头", SCNVector3(0, 0.5, 1.4), .systemRed),
            ("左侧", SCNVector3(-1.3, 0.2, 0.7), .systemGreen),
            ("右侧", SCNVector3(1.3, 0.2, 0.7), .systemBlue),
            ("太阳穴", SCNVector3(1.2, 0.3, 1.0), .systemOrange),
            ("面部", SCNVector3(0, -0.3, 1.5), .systemPurple)
        ]
        
        for (text, position, color) in labels {
            let textGeometry = SCNText(string: text, extrusionDepth: 0.02)
            textGeometry.font = UIFont.systemFont(ofSize: 0.1, weight: .medium)
            textGeometry.flatness = 0.01
            
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = color
            textMaterial.emission.contents = color.withAlphaComponent(0.3)
            textGeometry.materials = [textMaterial]
            
            let textNode = SCNNode(geometry: textGeometry)
            textNode.position = position
            textNode.scale = SCNVector3(0.8, 0.8, 0.8)
            textNode.opacity = 0.8
            
            // 让文字始终面向摄像机
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = [.Y]
            textNode.constraints = [billboardConstraint]
            
            headNode.addChildNode(textNode)
        }
    }
    
    private func updateLocationHighlights() {
        for (location, node) in locationNodes {
            let isSelected = selectedLocations.contains(location)
            
            // 更新透明度
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            node.opacity = isSelected ? 1.0 : 0.5
            
            // 更新大小
            node.scale = isSelected ? SCNVector3(1.3, 1.3, 1.3) : SCNVector3(1.0, 1.0, 1.0)
            SCNTransaction.commit()
        }
        
        // 更新左太阳穴
        if let leftTempleNode = headNode.childNode(withName: HeadacheLocation.temple.rawValue + "_left", recursively: false) {
            let isSelected = selectedLocations.contains(.temple)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            leftTempleNode.opacity = isSelected ? 1.0 : 0.5
            leftTempleNode.scale = isSelected ? SCNVector3(1.3, 1.3, 1.3) : SCNVector3(1.0, 1.0, 1.0)
            SCNTransaction.commit()
        }
    }
    
    private func resetCamera() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        cameraNode.position = SCNVector3(0, 0, 4)
        cameraNode.eulerAngles = SCNVector3(0, 0, 0)
        SCNTransaction.commit()
    }
    
    private func toggleRotation() {
        isRotating.toggle()
        
        if isRotating {
            let rotateAction = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 8)
            let repeatAction = SCNAction.repeatForever(rotateAction)
            headNode.runAction(repeatAction, forKey: "rotation")
        } else {
            headNode.removeAction(forKey: "rotation")
        }
    }
}

// SceneView的UIViewRepresentable包装器，支持点击检测
struct InteractiveSceneView: UIViewRepresentable {
    @Binding var selectedLocations: Set<HeadacheLocation>
    let scene: SCNScene
    let pointOfView: SCNNode
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.pointOfView = pointOfView
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor.clear
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 更新视图
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: InteractiveSceneView
        
        init(_ parent: InteractiveSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [:])
            
            if let hitResult = hitResults.first {
                if let nodeName = hitResult.node.name {
                    // 处理点击的位置
                    handleLocationTap(nodeName)
                }
            }
        }
        
        private func handleLocationTap(_ nodeName: String) {
            // 处理不同类型的节点点击并显示红色高亮
            
            // 移除"_left"后缀（如果存在）
            let cleanNodeName = nodeName.replacingOccurrences(of: "_left", with: "")
            
            // 首先让点击的区域变红
            highlightClickedRegion(nodeName)
            
            // 处理直接的头痛位置标记
            if let location = HeadacheLocation(rawValue: cleanNodeName) {
                toggleLocationSelection(location)
                return
            }
            
            // 处理头骨和大脑区域到头痛位置的映射
            switch nodeName {
            case "cranium", "frontal_bone", "frontal_cortex", "frontal_region":
                toggleLocationSelection(.forehead)
            case "left_temporal_bone", "temporal_cortex_left", "left_temporal_region":
                toggleLocationSelection(.leftSide)
            case "right_temporal_bone", "temporal_cortex_right", "right_temporal_region":
                toggleLocationSelection(.rightSide)
            case "parietal_bone", "parietal_cortex", "parietal_region":
                // 顶叶对应头顶，映射到多个位置
                toggleLocationSelection(.forehead)
                toggleLocationSelection(.leftSide)
                toggleLocationSelection(.rightSide)
            case "occipital_bone", "occipital_cortex", "occipital_region":
                // 枕叶对应后脑勺
                toggleLocationSelection(.leftSide)
                toggleLocationSelection(.rightSide)
            case "left_sphenoid_bone", "right_sphenoid_bone":
                // 蝶骨对应太阳穴和面部
                toggleLocationSelection(.temple)
                toggleLocationSelection(.face)
            case "cerebellum":
                // 小脑对应后脑勺
                toggleLocationSelection(.leftSide)
                toggleLocationSelection(.rightSide)
            case "brain_stem":
                // 脑干对应中央区域
                toggleLocationSelection(.face)
            default:
                // 处理其他可能的节点
                if let location = HeadacheLocation(rawValue: cleanNodeName) {
                    toggleLocationSelection(location)
                } else {
                    // 如果没有特定映射，根据位置推断
                    inferLocationFromNodeName(nodeName)
                }
            }
        }
        
        private func highlightClickedRegion(_ nodeName: String) {
            // 找到被点击的节点并将其暂时变红
            guard let scnView = parent.scene.rootNode.childNodes.first?.childNode(withName: nodeName, recursively: true) else { return }
            
            // 保存原始材质
            let originalMaterial = scnView.geometry?.materials.first?.copy() as? SCNMaterial
            
            // 创建红色高亮材质
            let highlightMaterial = SCNMaterial()
            highlightMaterial.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.8)
            highlightMaterial.emission.contents = UIColor.systemRed.withAlphaComponent(0.5)
            highlightMaterial.transparency = 0.6
            
            // 应用红色材质
            scnView.geometry?.materials = [highlightMaterial]
            
            // 1秒后恢复原始材质
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let original = originalMaterial {
                    scnView.geometry?.materials = [original]
                }
            }
        }
        
        private func inferLocationFromNodeName(_ nodeName: String) {
            // 根据节点名称推断疼痛位置
            let name = nodeName.lowercased()
            
            if name.contains("front") || name.contains("frontal") {
                toggleLocationSelection(.forehead)
            } else if name.contains("left") {
                toggleLocationSelection(.leftSide)
            } else if name.contains("right") {
                toggleLocationSelection(.rightSide)
            } else if name.contains("temple") || name.contains("temporal") {
                toggleLocationSelection(.temple)
            } else if name.contains("face") || name.contains("facial") {
                toggleLocationSelection(.face)
            } else if name.contains("back") || name.contains("occipital") {
                toggleLocationSelection(.leftSide)
                toggleLocationSelection(.rightSide)
            } else {
                // 默认映射到额头
                toggleLocationSelection(.forehead)
            }
        }
        
        private func toggleLocationSelection(_ location: HeadacheLocation) {
            if parent.selectedLocations.contains(location) {
                parent.selectedLocations.remove(location)
            } else {
                parent.selectedLocations.insert(location)
            }
            
            // 添加触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}

#Preview {
    struct HeadModel3DPreview: View {
        @State private var selectedLocations: Set<HeadacheLocation> = []
        @State private var selectedCustomLocations: Set<String> = []
        
        var body: some View {
            HeadModel3DView(
                selectedLocations: $selectedLocations,
                selectedCustomLocations: $selectedCustomLocations
            )
            .padding()
        }
    }
    
    return HeadModel3DPreview()
}
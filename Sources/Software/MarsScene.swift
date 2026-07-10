import SceneKit
import AppKit

// MARK: - Simplex noise (same algorithm as SimpleNoise in EarthScene)

private final class SimplexNoise {
    private var perm: [Int]
    private let grad3: [(Double,Double,Double)] = [
        (1,1,0),(-1,1,0),(1,-1,0),(-1,-1,0),
        (1,0,1),(-1,0,1),(1,0,-1),(-1,0,-1),
        (0,1,1),(0,-1,1),(0,1,-1),(0,-1,-1),
    ]
    init(seed:String){var h=0;for c in seed.utf8{h=h&*31&+Int(c)};perm=(0..<256).map{($0&+h)&255}.shuffled()}
    private func fade(_ t:Double)->Double{t*t*t*(t*(t*6-15)+10)}
    private func lerp(_ a:Double,_ b:Double,_ t:Double)->Double{a+(b-a)*t}
    func noise3D(_ x:Double,_ y:Double,_ z:Double)->Double{
        let X=Int(floor(x))&255,Y=Int(floor(y))&255,Z=Int(floor(z))&255
        let fx=x-floor(x),fy=y-floor(y),fz=z-floor(z),u=fade(fx),v=fade(fy),w=fade(fz)
        func h(_ x:Int,_ y:Int,_ z:Int)->Int{perm[(perm[(perm[x&255]&+y)&255]&+z)&255]}
        func g(_ h:Int,_ dx:Double,_ dy:Double,_ dz:Double)->Double{let g=grad3[h%12];return g.0*dx+g.1*dy+g.2*dz}
        let n0=g(h(X,Y,Z),fx,fy,fz),n1=g(h(X+1,Y,Z),fx-1,fy,fz),nx0=lerp(n0,n1,u)
        let n2=g(h(X,Y+1,Z),fx,fy-1,fz),n3=g(h(X+1,Y+1,Z),fx-1,fy-1,fz),nx1=lerp(n2,n3,u),ny0=lerp(nx0,nx1,v)
        let n4=g(h(X,Y,Z+1),fx,fy,fz-1),n5=g(h(X+1,Y,Z+1),fx-1,fy,fz-1),nx2=lerp(n4,n5,u)
        let n6=g(h(X,Y+1,Z+1),fx,fy-1,fz-1),n7=g(h(X+1,Y+1,Z+1),fx-1,fy-1,fz-1),nx3=lerp(n6,n7,u),ny1=lerp(nx2,nx3,v)
        return lerp(ny0,ny1,w)
    }
}

final class MarsScene: SCNScene {
    let interactionNode=SCNNode();let spinNode=SCNNode();let atmosNode=SCNNode()
    let cameraNode=SCNNode();var targetZoom:CGFloat=30

    // MARK: - Reactive animation (driven by SoftwareView state)
    /// 0 = idle, 0.6 = scanning/loading, 0.3 = done
    var animationIntensity: CGFloat = 0

    func updateForLoading(_ isLoading: Bool) {
        animationIntensity = isLoading ? 0.6 : 0.0
        targetZoom = isLoading ? 38 : 30
        interactionNode.eulerAngles.x = isLoading ? 0.35 : 0.2
    }

    func pulseDone() {
        animationIntensity = 0.3
        targetZoom = 26
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.animationIntensity = 0
            self?.targetZoom = 30
            self?.interactionNode.eulerAngles.x = 0.2
        }
    }

    private struct Moon{let orbitNode:SCNNode;let meshNode:SCNNode;let radius:Float;let speed:Float;var angle:Float;let spinNode:SCNNode}
    private var moons:[Moon]=[];private var lastTime:TimeInterval=0

    override init(){super.init();setupScene()}
    required init?(coder:NSCoder){super.init(coder:coder);setupScene()}

    private func setupScene(){
        background.contents=NSColor.clear
        let cam=SCNCamera();cam.zNear=0.1;cam.zFar=200;cam.fieldOfView=35
        cameraNode.camera=cam;cameraNode.position=SCNVector3(0,2,30)
        rootNode.addChildNode(cameraNode)
        rootNode.addChildNode(interactionNode);interactionNode.eulerAngles.x=0.2
        let tilt=SCNNode();tilt.eulerAngles.z=25.19*(.pi/180)
        interactionNode.addChildNode(tilt)
        tilt.addChildNode(spinNode);tilt.addChildNode(atmosNode)
        buildSurface();buildAtmos();buildMoons()
    }

    private func buildSurface(){
        let noise=SimplexNoise(seed:"mars-surface-v2");let count=5_000
        var p=[Float](repeating:0,count:count*3);var c=[Float](repeating:0,count:count*3)
        let colBase=SIMD3<Float>(0.58,0.33,0.30)//#94544d
        let colDark=SIMD3<Float>(0.42,0.26,0.24)//#6b433c
        let colLight=SIMD3<Float>(0.85,0.55,0.42)//#d98c6b
        var idx=0
        while idx<count{
            let theta=Double.random(in:0...(2 * .pi)),phi=acos(2*Double.random(in:0...1)-1)
            let x=5.0*sin(phi)*cos(theta),y=5.0*cos(phi),z=5.0*sin(phi)*sin(theta)
            let nBase=noise.noise3D(x*0.3,y*0.3,z*0.3)
            let nDetail=noise.noise3D(x*1.5,y*1.5,z*1.5)
            let nCrater=abs(noise.noise3D(x*2.5,y*2.5,z*2.5))
            let canyon=x>0&&abs(y) < 0.5 ? abs(z/5.0)*0.3:0.0
            let h=nBase*0.04+nDetail*0.02-nCrater*0.05-canyon*0.03
            let r=5.0+h
            p[idx*3]=Float(r*sin(phi)*cos(theta));p[idx*3+1]=Float(r*cos(phi));p[idx*3+2]=Float(r*sin(phi)*sin(theta))
            let v=Float.random(in:0.9...1.1);var cc=SIMD3<Float>()
            if nCrater>0.7{cc=colDark}
            else if nBase>0.6||canyon>0{cc=colLight*0.7+colBase*0.3}
            else{cc=colBase}
            c[idx*3]=min(1,max(0,cc.x*v));c[idx*3+1]=min(1,max(0,cc.y*v));c[idx*3+2]=min(1,max(0,cc.z*v))
            idx+=1
        }
        spinNode.addChildNode(SCNNode(geometry:makeGeo(p:p,col:c,count:idx)))
        //Wireframe
        let w=SCNBox(width:10.02,height:10.02,length:10.02,chamferRadius:5.01)
        w.widthSegmentCount=24;w.heightSegmentCount=16;w.lengthSegmentCount=24
        let wm=SCNMaterial();wm.diffuse.contents=NSColor(calibratedRed:0.87,green:0.31,blue:0.19,alpha:0.06);wm.isDoubleSided=true;w.materials=[wm]
        spinNode.addChildNode(SCNNode(geometry:w))
    }

    private func buildAtmos(){
        let count=3_000;var p=[Float](repeating:0,count:count*3)
        var idx=0
        while idx<count{
            let theta=Double.random(in:0...(2 * .pi)),phi=acos(2*Double.random(in:0...1)-1)
            let r=5.1+Double.random(in:0...0.3)
            p[idx*3]=Float(r*sin(phi)*cos(theta));p[idx*3+1]=Float(r*cos(phi));p[idx*3+2]=Float(r*sin(phi)*sin(theta))
            idx+=1
        }
        let g=makeGeo(p:p,col:[Float](repeating:0.78,count:count*3),count:idx,ps:3.0,opacity:0.08)
        let node=SCNNode(geometry:g);atmosNode.addChildNode(node)
    }

    private func buildMoons(){
        let configs:[(name:String,radius:Float,speed:Float,size:Float,color:NSColor,count:Int)]=[
            ("Phobos",7.5,0.008,0.25,NSColor(white:0.8,alpha:1),600),
            ("Deimos",12.0,0.003,0.18,NSColor(white:0.67,alpha:1),400)]
        for cfg in configs{
            let noise=SimplexNoise(seed:"mars-moon-"+cfg.name)
            var p=[Float](repeating:0,count:cfg.count*3);var c=[Float](repeating:0,count:cfg.count*3)
            for i in 0..<cfg.count{
                let theta=Double.random(in:0...(2 * .pi)),phi=acos(2*Double.random(in:0...1)-1)
                let r=Double(cfg.size)*(0.85+Double.random(in:0...0.15))
                let x=r*sin(phi)*cos(theta),y=r*cos(phi),z=r*sin(phi)*sin(theta)
                let n=noise.noise3D(x,y,z)
                let rr=Double(cfg.size)*(0.85+(n < -0.2 ? 0.05:0.15))
                p[i*3]=Float(rr*sin(phi)*cos(theta));p[i*3+1]=Float(rr*cos(phi));p[i*3+2]=Float(rr*sin(phi)*sin(theta))
                let v=Float.random(in:0.8...1.2);let cc=n < -0.2 ? SIMD3<Float>(0.2,0.2,0.2):SIMD3<Float>(0.5,0.5,0.5)
                c[i*3]=min(1,cc.x*v);c[i*3+1]=min(1,cc.y*v);c[i*3+2]=min(1,cc.z*v)
            }
            let g=makeGeo(p:p,col:c,count:cfg.count)
            let body=SCNNode(geometry:g)
            //Orbit ring
            let orb=SCNTorus(ringRadius:CGFloat(cfg.radius),pipeRadius:0.01);orb.ringSegmentCount=96
            let om=SCNMaterial();om.diffuse.contents = NSColor(white:0.67,alpha:0.06);om.isDoubleSided=true;orb.materials=[om]
            let on=SCNNode(geometry:orb);on.eulerAngles.x = .pi/2;interactionNode.addChildNode(on)
            //Container
            let mc=SCNNode();mc.addChildNode(body);body.position=SCNVector3(cfg.radius,0,0);interactionNode.addChildNode(mc)
            let sn=SCNNode();body.addChildNode(sn)
            moons.append(Moon(orbitNode:mc,meshNode:body,radius:cfg.radius,speed:cfg.speed,angle:Float.random(in:0...(2 * .pi)),spinNode:sn))
        }
    }

    private func makeGeo(p:[Float],col:[Float],count:Int,ps:Float=1.5,opacity:Float=1)->SCNGeometry{
        let pd=Data(bytes:p,count:count*3*4),cd=Data(bytes:col,count:count*3*4)
        let psrc=SCNGeometrySource(data:pd,semantic:.vertex,vectorCount:count,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:0,dataStride:12)
        let csrc=SCNGeometrySource(data:cd,semantic:.color,vectorCount:count,usesFloatComponents:true,componentsPerVector:3,bytesPerComponent:4,dataOffset:0,dataStride:12)
        let el=SCNGeometryElement(data:nil,primitiveType:.point,primitiveCount:count,bytesPerIndex:0)
        let g=SCNGeometry(sources:[psrc,csrc],elements:[el]);let m=SCNMaterial()
        m.isDoubleSided=true;m.writesToDepthBuffer=opacity>=1
        if opacity<1{m.transparency=CGFloat(opacity);m.transparencyMode = .dualLayer}
        m.shaderModifiers=[.geometry:"#pragma body\n_geometry.pointSize = \(ps);"];g.materials=[m];return g
    }

    func animate(at time:TimeInterval){
        if lastTime==0{lastTime=time;return};let dt=min(time-lastTime,0.05);lastTime=time;let d=CGFloat(dt)
        let cz=cameraNode.position.z;let df=targetZoom-CGFloat(cz)
        if abs(df)>0.01{cameraNode.position.z=cz+df*min(1,CGFloat(dt)*4)}
        // Camera lateral sway during loading
        if animationIntensity > 0 {
            cameraNode.position.x = sin(time * 0.4) * animationIntensity * 0.8
        } else {
            cameraNode.position.x = 0
        }
        // Speed boosted by animationIntensity: idle 1x → scanning ~8x
        let speedMul=1.0+animationIntensity*7.0
        spinNode.eulerAngles.y+=d*0.15*speedMul
        atmosNode.eulerAngles.y+=d*0.18*(1.0+animationIntensity*4.0)
        let moonBoost=1.0+animationIntensity*4.0
        for i in 0..<moons.count{
            moons[i].angle+=moons[i].speed*Float(dt)*60*Float(moonBoost)
            moons[i].orbitNode.eulerAngles.y=CGFloat(moons[i].angle)
            moons[i].spinNode.eulerAngles.z+=d*0.6;moons[i].spinNode.eulerAngles.y+=d*0.3
        }
    }
}

extension MarsScene:SCNSceneRendererDelegate{
    func renderer(_:SCNSceneRenderer,updateAtTime time:TimeInterval){animate(at:time)}
}

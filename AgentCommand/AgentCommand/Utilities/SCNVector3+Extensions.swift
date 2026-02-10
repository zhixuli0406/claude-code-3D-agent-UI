import SceneKit

extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: CGFloat) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        lhs * CGFloat(rhs)
    }

    var length: Float {
        let fx = Float(x)
        let fy = Float(y)
        let fz = Float(z)
        return sqrtf(fx * fx + fy * fy + fz * fz)
    }

    var normalized: SCNVector3 {
        let len = CGFloat(length)
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }

    func distance(to other: SCNVector3) -> Float {
        (self - other).length
    }
}

extension ScenePosition {
    func toSCNVector3() -> SCNVector3 {
        SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
    }
}

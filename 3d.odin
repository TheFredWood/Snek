package snek

import "core:math"

Point :: struct {
	x:		f64,
	y:		f64,
	z:		f64 // Height
}

Triangle :: struct {
	point1:		Point,
	point2:		Point,
	point3:		Point,
	color:		u32
}

Plane :: struct {
	startPoint: Point,
	normalVector: Point
}

CrossProduct :: proc(v1: Point, v2: Point) -> Point {	// 9 MathOps
	return Point{
		v1.y * v2.z - v1.z * v2.y,
		v1.z * v2.x - v1.x * v2.z,
		v1.x * v2.y - v1.y * v2.x
	}
}

DotProduct :: proc(v1: Point, v2: Point) -> f64 {	// 5 MathOps
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
}

GetDistance :: proc(point1: Point, point2: Point) -> Point {	// 3 MathOps
	return Point{point2.x - point1.x, point2.y - point1.y, point2.z - point1.z}	
}

Add :: proc(point1: Point, point2: Point) -> Point {
	return Point{point2.x + point1.x, point2.y + point1.y, point2.z + point1.z}
}

Mult :: proc(p: Point, a: f64) -> Point {
	return Point{p.x * a, p.y * a, p.z * a}
}

NormalizeVector :: proc(vec: Point) -> Point{
	totalLength := math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
	return {vec.x / totalLength, vec.y / totalLength, vec.z / totalLength}
}

Length :: proc(point:Point) -> f64 {
	return math.sqrt(point.x * point.x + point.y * point.y + point.z * point.z)
}


SplitShapeToTriangles :: proc(shape: [dynamic]Node) {
	for i := 0; i < len(nodes); i = i + 1 {
		firstPoint := nodes[i]
		midPoint := nodes[i + 1]

		
	}
	//TODO: Implement
}

CheckCollision :: proc(start: Point, direction: Point, triangle: Triangle) -> f64{ // 47 MathOps
	v1 := GetDistance(triangle.point1, triangle.point2)
	v2 := GetDistance(triangle.point1, triangle.point3)
	//zwei Variablen eliminieren, indem das skalarprodukt mit einem mit v2 und d orthogonalen Vektoren genommen wird, wodurch die Terme wefallen
	pvec := CrossProduct(direction, v2)
	det := DotProduct(pvec, v1)

	if (det < 0.00001 && det > -0.00001){ //direction parallel zur Ebene
		return -1
	}

	tvec := GetDistance(triangle.point1, start)
	length1 := DotProduct(tvec, pvec) / det

	if (length1 < 0.0 || length1 > 1.0) {
		return -1
	}
	qvec := CrossProduct(tvec, v1)
	length2 := DotProduct(direction, qvec) / det
	if (length2 < 0.0 || length1 + length2 > 1.0){
		return -1
	}
	lengthBeam := DotProduct(v2, qvec) / det
	return lengthBeam
}

CollisionWithPlane :: proc(start: Point, direction: Point, plane: Plane) -> f64 {
	length: f64 = DotProduct(GetDistance(start, plane.startPoint), plane.normalVector) / DotProduct(direction, plane.normalVector)
	return length
}

PointOnPlane :: proc(point: Point, plane: Plane) -> f64 {
	return CollisionWithPlane(point, plane.normalVector, plane)
}

PointInFrustum :: proc(point: Point, frustum: [6]Plane) -> bool {
	playerDirection: Point = GetDirectionFromAngle(playerDirectionHorizontal, playerDirectionVertical)
	isInside: bool = true
	for plane in frustum {
		length := PointOnPlane(point, plane) //Positive value means within frustum
		if (length < 0) {
			isInside = false
		}
	}
	return isInside
}

GetDirectionFromAngle :: proc(angleHorizontal: f64, angleVertical: f64) -> Point{
	//TODO: normalize Vector length
	aH := math.mod(angleHorizontal, 2 * math.PI)

	if (aH < 0){
		aH = aH + 2 * math.PI
	}

	aV := angleVertical
	if (aV < 0){
		aV = 0
	}

	if (angleVertical > math.PI){
		aV = math.PI
	}

	x: f64 = math.cos(aH)
	y: f64 = math.sin(aH)
	length :f64 = math.sqrt(x * x + y * y)
	z: f64 = math.tan(aV - 0.5 * math.PI) * length //default height is 0.5 * PI
	res := NormalizeVector(Point{x, y, z})
	return res
}

CreateFrustum:: proc(start: Point, direction: Point) -> [6]Plane{
	renderDistance: f64 = 100

	upVec: Point = Point{0, 0, 1}
	horVec: Point = CrossProduct(direction, upVec)
	horVec = NormalizeVector(horVec)
	vertVec := CrossProduct(direction, horVec)
	vertVec = NormalizeVector(vertVec)
	vertVec = Mult(vertVec, -1)

	//pixelDirection: Point = Add(Add(direction, Mult(horVec, (f64(j) - f64(windowWidth) / 2.0) / 400.0)), Mult(vertVec, (f64(i) - f64(windowHeight) / 2.0) / 400))
	leftOffset: Point = Mult(horVec, (- f64(windowWidth) / 2.0) / 400.0)
	upOffset: Point = Mult(vertVec, (f64(windowHeight) / 2.0) / 400.0)
	nearPlane: Plane = Plane{Add(start, Mult(direction, 0.01)), NormalizeVector(Mult(direction, -1))}
	farPlane: Plane = Plane {Add(start, Mult(direction, renderDistance)), NormalizeVector(direction)}
	leftPlane: Plane = Plane {start, NormalizeVector(Mult(CrossProduct(Add(direction, leftOffset), vertVec), -1))}
	rightPlane: Plane = Plane {start, NormalizeVector(CrossProduct(Add(direction, Mult(leftOffset, -1)), vertVec))}
	topPlane: Plane = Plane {start, NormalizeVector(Mult(CrossProduct(Add(direction, upOffset), horVec), -1))}
	bottomPlane: Plane = Plane {start, NormalizeVector(CrossProduct(Add(direction, Mult(upOffset, -1)), horVec))}
	res: [6]Plane = {nearPlane, farPlane, leftPlane, rightPlane, topPlane, bottomPlane}
	return res
}

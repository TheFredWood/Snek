package snek

import "core:math"
import "core:simd"

Point :: struct {
	x:		f64,
	y:		f64,
	z:		f64 // Height
}

PointSoA :: struct {
	x:		[dynamic]f64,
	y:		[dynamic]f64,
	z:		[dynamic]f64 // Height
}

Triangle :: struct {
	point1:		Point,
	point2:		Point,
	point3:		Point,
	color:		u32
}

TriangleSoA :: struct {
	point1:		PointSoA,
	point2:		PointSoA,
	point3:		PointSoA,
	color:		[dynamic]u32
}

Plane :: struct {
	startPoint: Point,
	normalVector: Point
}

AppendTriangleSoA :: proc(triangles: ^TriangleSoA, triangle: Triangle) {
	append(&triangles.point1.x, triangle.point1.x)
	append(&triangles.point1.y, triangle.point1.y)
	append(&triangles.point1.z, triangle.point1.z)
	append(&triangles.point2.x, triangle.point2.x)
	append(&triangles.point2.y, triangle.point2.y)
	append(&triangles.point2.z, triangle.point2.z)
	append(&triangles.point3.x, triangle.point3.x)
	append(&triangles.point3.y, triangle.point3.y)
	append(&triangles.point3.z, triangle.point3.z)
	append(&triangles.color, triangle.color)
}
GetTriangleFromSoA :: proc(triangles: ^TriangleSoA, index: int) -> Triangle{
	t := triangles
	return Triangle{
		Point{t.point1.x[index], t.point1.y[index], t.point1.z[index]},
		Point{t.point2.x[index], t.point2.y[index], t.point2.z[index]},
		Point{t.point3.x[index], t.point3.y[index], t.point3.z[index]},
		t.color[index]
	}
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

CrossProductSIMD :: proc(x1: simd.f64x4, y1: simd.f64x4, z1: simd.f64x4, x2: simd.f64x4, y2: simd.f64x4, z2: simd.f64x4) -> (simd.f64x4, simd.f64x4, simd.f64x4) {
	/*
	return Point{
		v1.y * v2.z - v1.z * v2.y,
		v1.z * v2.x - v1.x * v2.z,
		v1.x * v2.y - v1.y * v2.x
	}
	*/
	return 	simd.sub(simd.mul(y1, z2), simd.mul(z1, y2)),
		simd.sub(simd.mul(z1, x2), simd.mul(x1, z2)),
		simd.sub(simd.mul(x1, y2), simd.mul(y1, x2))
}

DotProductSIMD :: proc(x1: simd.f64x4, y1: simd.f64x4, z1: simd.f64x4, x2: simd.f64x4, y2: simd.f64x4, z2: simd.f64x4) -> simd.f64x4 {
	return 	simd.add(simd.add(simd.mul(x1, x2), simd.mul(y1, y2)), simd.mul(z1, z2))
}

CheckCollisionSIMD :: proc(s: S) -> (simd.f64x4, simd.u64x4) { // 47 MathOps
	//start := Point{s.ppx[0], s.ppy[0], s.ppz[0]}
	//direction := Point{s.pppx[0], s.pppy[0], s.pppz[0]}
	//triangle := Triangle{Point{s.tx1[0], s.ty1[0], s.tz1[0]}, Point{s.tx2[0], s.ty2[0], s.tz2[0]}, Point{s.tx3[0], s.ty3[0], s.tz3[0]}, s.tc[0]}
	//v1 := GetDistance(triangle.point1, triangle.point2)
	v1x: #simd[4]f64 = simd.sub(s.tx2, s.tx1)
	v1y: #simd[4]f64 = simd.sub(s.ty2, s.ty1)
	v1z: #simd[4]f64 = simd.sub(s.tz2, s.tz1)

	//v2 := GetDistance(triangle.point1, triangle.point3)
	v2x: #simd[4]f64 = simd.sub(s.tx3, s.tx1)
	v2y: #simd[4]f64 = simd.sub(s.ty3, s.ty1)
	v2z: #simd[4]f64 = simd.sub(s.tz3, s.tz1)
	//zwei Variablen eliminieren, indem das skalarprodukt mit einem mit v2 und d orthogonalen Vektoren genommen wird, wodurch die Terme wefallen
	//pvec := CrossProduct(direction, v2)
	pvecx, pvecy, pvecz := CrossProductSIMD(s.pppx, s.pppy, s.pppz, v2x, v2y, v2z)

	//det := DotProduct(pvec, v1)
	det := DotProductSIMD(pvecx, pvecy, pvecz, v1x, v1y,v1z)
	/*
	if (det < 0.00001 && det > -0.00001){ //direction parallel zur Ebene
		return -1, 0
	}
	*/
	mask1 := simd.lanes_gt(det, 0.00001)
	mask2 := simd.lanes_lt(det, -0.00001)
	//mask is 1 if result valid
	mask: #simd[4]u64 = simd.bit_or(mask1, mask2)

	//tvec := GetDistance(triangle.point1, start)
	tvecx: #simd[4]f64 = simd.sub(s.ppx, s.tx1)
	tvecy: #simd[4]f64 = simd.sub(s.ppy, s.ty1)
	tvecz: #simd[4]f64 = simd.sub(s.ppz, s.tz1)
	
	//length1 := DotProduct(tvec, pvec) / det
	length1 := simd.div(DotProductSIMD(tvecx, tvecy, tvecz, pvecx, pvecy, pvecz), det)

	/*
	if (length1 < 0.0 || length1 > 1.0) {
		return -1, 0
	}
	*/
	mask1 = simd.lanes_ge(length1, 0.0)
	mask2 = simd.lanes_le(length1, 1.0)
	masks := simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)

	//qvec := CrossProduct(tvec, v1)
	qvecx, qvecy, qvecz := CrossProductSIMD(tvecx, tvecy, tvecz, v1x, v1y, v1z)
	//length2 := DotProduct(direction, qvec) / det
	length2 := simd.div(DotProductSIMD(s.pppx, s.pppy, s.pppz, qvecx, qvecy, qvecz), det)

	/*
	if (length2 < 0.0 || length1 + length2 > 1.0){
		return -1, 0
	}
	*/
	mask1 = simd.lanes_ge(length2, 0.0)
	mask2 = simd.lanes_le(simd.add(length1, length2), 1.0)
	
	masks = simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)

	//lengthBeam := DotProduct(v2, qvec) / det
	lengthBeam := simd.div(DotProductSIMD(v2x, v2y, v2z, qvecx, qvecy, qvecz), det)
	mask1 = simd.lanes_ge(lengthBeam, 0.0)
	mask = simd.bit_and(mask, mask1)
	return lengthBeam, mask
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

CreateFrustum :: proc(start: Point, direction: Point) -> [6]Plane{
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

CompareBeams :: proc(beams: [4]f64, beamColors: [4]u32, mask: [4]u64, previousShortestBeam: f64, previousShortestBeamColor: u32) -> (f64, u32) {
	shortestBeam := previousShortestBeam
	shortestBeamColor := previousShortestBeamColor

	for i: int = 0; i < 4; i = i + 1 {
		if (mask[i] == 0) {
			continue
		}
		if (beams[i] < 0) {
			continue
		}
		if (beams[i] < shortestBeam || shortestBeam < 0) {
			shortestBeam = beams[i]
			shortestBeamColor = beamColors[i]
		}
	}
	return shortestBeam, shortestBeamColor
}

CompareBeamsSingle :: proc(beam1: f64, color1: u32, beam2: f64, color2: u32) -> (f64, u32) {
	if (beam1 < beam2 && beam1 >= 0 || beam2 < 0) { return beam1, color1}
	else if (beam2 < 0){return 0, 0}
	else { return beam2, color2}
}

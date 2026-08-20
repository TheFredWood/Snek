package snek

import "core:math"
import "core:simd"

Point :: struct { x:		f64,
	y:		f64,
	z:		f64 // Height
}

PointSoA4 :: struct {
	x:		[4]f64,
	y:		[4]f64,
	z:		[4]f64 // Height
}

Triangle :: struct {
	point1:		Point,
	point2:		Point,
	point3:		Point,
	color:		u32
}

TriangleSoA4 :: struct {
	point1:		PointSoA4,
	point2:		PointSoA4,
	point3:		PointSoA4,
	color:		[4]u32
}

Plane :: struct {
	startPoint: Point,
	normalVector: Point
}

MakeTriangleSoA4 :: proc(t1: ^Triangle, t2: ^Triangle, t3: ^Triangle, t4: ^Triangle) -> TriangleSoA4 {
	return TriangleSoA4{
		PointSoA4{
			{t1.point1.x, t2.point1.x, t3.point1.x, t4.point1.x},
			{t1.point1.y, t2.point1.y, t3.point1.y, t4.point1.y},
			{t1.point1.z, t2.point1.z, t3.point1.z, t4.point1.z},
		},
		PointSoA4{
			{t1.point2.x, t2.point2.x, t3.point2.x, t4.point2.x},
			{t1.point2.y, t2.point2.y, t3.point2.y, t4.point2.y},
			{t1.point2.z, t2.point2.z, t3.point2.z, t4.point2.z},
		},
		PointSoA4{
			{t1.point3.x, t2.point3.x, t3.point3.x, t4.point3.x},
			{t1.point3.y, t2.point3.y, t3.point3.y, t4.point3.y},
			{t1.point3.z, t2.point3.z, t3.point3.z, t4.point3.z},
		},
		{t1.color, t2.color, t3.color, t4.color}
	}
}


GetTrianglesFromSoA4 :: proc(triangles: ^TriangleSoA4) -> [4]Triangle{
	t := triangles
	return {
			Triangle{
				Point{t.point1.x[0], t.point1.y[0], t.point1.z[0]},
				Point{t.point2.x[0], t.point2.y[0], t.point2.z[0]},
				Point{t.point3.x[0], t.point3.y[0], t.point3.z[0]},
				t.color[0]
			},
			Triangle{
				Point{t.point1.x[1], t.point1.y[1], t.point1.z[1]},
				Point{t.point2.x[1], t.point2.y[1], t.point2.z[1]},
				Point{t.point3.x[1], t.point3.y[1], t.point3.z[1]},
				t.color[1]
			},
			Triangle{
				Point{t.point1.x[2], t.point1.y[2], t.point1.z[2]},
				Point{t.point2.x[2], t.point2.y[2], t.point2.z[2]},
				Point{t.point3.x[2], t.point3.y[2], t.point3.z[2]},
				t.color[2]
			},
			Triangle{
				Point{t.point1.x[3], t.point1.y[3], t.point1.z[3]},
				Point{t.point2.x[3], t.point2.y[3], t.point2.z[3]},
				Point{t.point3.x[3], t.point3.y[3], t.point3.z[3]},
				t.color[3]
			}
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

CrossProductSIMD :: #force_inline proc(x1: simd.f64x4, y1: simd.f64x4, z1: simd.f64x4, x2: simd.f64x4, y2: simd.f64x4, z2: simd.f64x4) -> (simd.f64x4, simd.f64x4, simd.f64x4) {
	return 	simd.sub(simd.mul(y1, z2), simd.mul(z1, y2)),
		simd.sub(simd.mul(z1, x2), simd.mul(x1, z2)),
		simd.sub(simd.mul(x1, y2), simd.mul(y1, x2))
}

DotProductSIMD :: #force_inline proc(x1: simd.f64x4, y1: simd.f64x4, z1: simd.f64x4, x2: simd.f64x4, y2: simd.f64x4, z2: simd.f64x4) -> simd.f64x4 {
	return 	simd.add(simd.add(simd.mul(x1, x2), simd.mul(y1, y2)), simd.mul(z1, z2))
}

CheckCollisionSIMD :: #force_inline proc(s: S) -> (simd.f64x4, simd.u64x4) { // 47 MathOps
	v1x: #simd[4]f64 = simd.sub(s.tx2, s.tx1)
	v1y: #simd[4]f64 = simd.sub(s.ty2, s.ty1)
	v1z: #simd[4]f64 = simd.sub(s.tz2, s.tz1)


	v2x: #simd[4]f64 = simd.sub(s.tx3, s.tx1)
	v2y: #simd[4]f64 = simd.sub(s.ty3, s.ty1)
	v2z: #simd[4]f64 = simd.sub(s.tz3, s.tz1)
	pvecx, pvecy, pvecz := CrossProductSIMD(s.pppx, s.pppy, s.pppz, v2x, v2y, v2z)

	det := DotProductSIMD(pvecx, pvecy, pvecz, v1x, v1y,v1z)
	mask1 := simd.lanes_gt(det, 0.00001)
	mask2 := simd.lanes_lt(det, -0.00001)

	//mask is 1 if result valid
	mask: #simd[4]u64 = simd.bit_or(mask1, mask2)
	if simd.reduce_or(mask) == 0 {
	    return simd.f64x4(0.0), mask
	}

	tvecx: #simd[4]f64 = simd.sub(s.ppx, s.tx1)
	tvecy: #simd[4]f64 = simd.sub(s.ppy, s.ty1)
	tvecz: #simd[4]f64 = simd.sub(s.ppz, s.tz1)
	
	invDet := simd.div(simd.f64x4(1.0), det)
	length1 := simd.mul(DotProductSIMD(tvecx, tvecy, tvecz, pvecx, pvecy, pvecz), invDet)

	mask1 = simd.lanes_gt(length1, 0.0)
	mask2 = simd.lanes_le(length1, 1.0)
	masks := simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)
	if simd.reduce_or(mask) == 0 {
	    return simd.f64x4(0.0), mask
	}

	qvecx, qvecy, qvecz := CrossProductSIMD(tvecx, tvecy, tvecz, v1x, v1y, v1z)
	length2 := simd.mul(DotProductSIMD(s.pppx, s.pppy, s.pppz, qvecx, qvecy, qvecz), invDet)

	mask1 = simd.lanes_gt(length2, 0.0)
	mask2 = simd.lanes_le(simd.add(length1, length2), 1.0)
	
	masks = simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)
	if simd.reduce_or(mask) == 0 {
	    return simd.f64x4(0.0), mask
	}

	lengthBeam := simd.mul(DotProductSIMD(v2x, v2y, v2z, qvecx, qvecy, qvecz), invDet)
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

package snek

import "core:math"
import "core:simd"

Point :: struct { x:		f32,
	y:		f32,
	z:		f32 // Height
}

PointSoA8 :: struct {
	x:		[8]f32,
	y:		[8]f32,
	z:		[8]f32 // Height
}

Triangle :: struct {
	point1:		Point,
	point2:		Point,
	point3:		Point,
	color:		u32
}

TriangleSoA8 :: struct {
	point1:		PointSoA8,
	point2:		PointSoA8,
	point3:		PointSoA8,
	color:		[8]u32
}

Plane :: struct {
	startPoint: Point,
	normalVector: Point
}

MakeTriangleSoA8 :: proc(t: [8]Triangle) -> TriangleSoA8 {
	return TriangleSoA8{
		PointSoA8{
			{t[0].point1.x, t[1].point1.x, t[2].point1.x, t[3].point1.x, t[4].point1.x, t[5].point1.x, t[6].point1.x, t[7].point1.x},
			{t[0].point1.y, t[1].point1.y, t[2].point1.y, t[3].point1.y, t[4].point1.y, t[5].point1.y, t[6].point1.y, t[7].point1.y},
			{t[0].point1.z, t[1].point1.z, t[2].point1.z, t[3].point1.z, t[4].point1.z, t[5].point1.z, t[6].point1.z, t[7].point1.z},
		},
		PointSoA8{
			{t[0].point2.x, t[1].point2.x, t[2].point2.x, t[3].point2.x, t[4].point2.x, t[5].point2.x, t[6].point2.x, t[7].point2.x},
			{t[0].point2.y, t[1].point2.y, t[2].point2.y, t[3].point2.y, t[4].point2.y, t[5].point2.y, t[6].point2.y, t[7].point2.y},
			{t[0].point2.z, t[1].point2.z, t[2].point2.z, t[3].point2.z, t[4].point2.z, t[5].point2.z, t[6].point2.z, t[7].point2.z},
		},
		PointSoA8{
			{t[0].point3.x, t[1].point3.x, t[2].point3.x, t[3].point3.x, t[4].point3.x, t[5].point3.x, t[6].point3.x, t[7].point3.x},
			{t[0].point3.y, t[1].point3.y, t[2].point3.y, t[3].point3.y, t[4].point3.y, t[5].point3.y, t[6].point3.y, t[7].point3.y},
			{t[0].point3.z, t[1].point3.z, t[2].point3.z, t[3].point3.z, t[4].point3.z, t[5].point3.z, t[6].point3.z, t[7].point3.z},
		},
		{t[0].color, t[1].color, t[2].color, t[3].color, t[4].color, t[5].color, t[6].color, t[7].color}
	}
}


GetTrianglesFromSoA8 :: proc(triangles: ^TriangleSoA8) -> [8]Triangle{
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
			},
			Triangle{
				Point{t.point1.x[4], t.point1.y[4], t.point1.z[4]},
				Point{t.point2.x[4], t.point2.y[4], t.point2.z[4]},
				Point{t.point3.x[4], t.point3.y[4], t.point3.z[4]},
				t.color[4]
			},
			Triangle{
				Point{t.point1.x[5], t.point1.y[5], t.point1.z[5]},
				Point{t.point2.x[5], t.point2.y[5], t.point2.z[5]},
				Point{t.point3.x[5], t.point3.y[5], t.point3.z[5]},
				t.color[5]
			},
			Triangle{
				Point{t.point1.x[6], t.point1.y[6], t.point1.z[6]},
				Point{t.point2.x[6], t.point2.y[6], t.point2.z[6]},
				Point{t.point3.x[6], t.point3.y[6], t.point3.z[6]},
				t.color[6]
			},
			Triangle{
				Point{t.point1.x[7], t.point1.y[7], t.point1.z[7]},
				Point{t.point2.x[7], t.point2.y[7], t.point2.z[7]},
				Point{t.point3.x[7], t.point3.y[7], t.point3.z[7]},
				t.color[7]
			},
		}
}

CrossProduct :: proc(v1: Point, v2: Point) -> Point {	// 9 MathOps
	return Point{
		v1.y * v2.z - v1.z * v2.y,
		v1.z * v2.x - v1.x * v2.z,
		v1.x * v2.y - v1.y * v2.x
	}
}

DotProduct :: proc(v1: Point, v2: Point) -> f32 {	// 5 MathOps
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
}

GetDistance :: proc(point1: Point, point2: Point) -> Point {	// 3 MathOps
	return Point{point2.x - point1.x, point2.y - point1.y, point2.z - point1.z}	
}

Add :: proc(point1: Point, point2: Point) -> Point {
	return Point{point2.x + point1.x, point2.y + point1.y, point2.z + point1.z}
}

Mult :: proc(p: Point, a: f32) -> Point {
	return Point{p.x * a, p.y * a, p.z * a}
}

NormalizeVector :: proc(vec: Point) -> Point{
	totalLength := math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
	return {vec.x / totalLength, vec.y / totalLength, vec.z / totalLength}
}

Length :: proc(point:Point) -> f32 {
	return math.sqrt(point.x * point.x + point.y * point.y + point.z * point.z)
}

CheckCollision :: proc(start: Point, direction: Point, triangle: Triangle) -> f32{ // 47 MathOps
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

CrossProductSIMD :: #force_inline proc(x1: simd.f32x8, y1: simd.f32x8, z1: simd.f32x8, x2: simd.f32x8, y2: simd.f32x8, z2: simd.f32x8) -> (simd.f32x8, simd.f32x8, simd.f32x8) {
	return 	simd.sub(simd.mul(y1, z2), simd.mul(z1, y2)),
		simd.sub(simd.mul(z1, x2), simd.mul(x1, z2)),
		simd.sub(simd.mul(x1, y2), simd.mul(y1, x2))
}

DotProductSIMD :: #force_inline proc(x1: simd.f32x8, y1: simd.f32x8, z1: simd.f32x8, x2: simd.f32x8, y2: simd.f32x8, z2: simd.f32x8) -> simd.f32x8 {
	return 	simd.add(simd.add(simd.mul(x1, x2), simd.mul(y1, y2)), simd.mul(z1, z2))
}

CheckCollisionSIMD :: #force_inline proc(s: S) -> (simd.f32x8, simd.u32x8) { // 47 MathOps
	v1x: #simd[8]f32 = simd.sub(s.tx2, s.tx1)
	v1y: #simd[8]f32 = simd.sub(s.ty2, s.ty1)
	v1z: #simd[8]f32 = simd.sub(s.tz2, s.tz1)


	v2x: #simd[8]f32 = simd.sub(s.tx3, s.tx1)
	v2y: #simd[8]f32 = simd.sub(s.ty3, s.ty1)
	v2z: #simd[8]f32 = simd.sub(s.tz3, s.tz1)
	pvecx, pvecy, pvecz := CrossProductSIMD(s.pppx, s.pppy, s.pppz, v2x, v2y, v2z)

	det := DotProductSIMD(pvecx, pvecy, pvecz, v1x, v1y,v1z)
	mask1 := simd.lanes_gt(det, 0.0000001)
	mask2 := simd.lanes_lt(det, -0.0000001)

	//mask is 1 if result valid
	mask: #simd[8]u32 = simd.bit_or(mask1, mask2)
	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	tvecx: #simd[8]f32 = simd.sub(s.ppx, s.tx1)
	tvecy: #simd[8]f32 = simd.sub(s.ppy, s.ty1)
	tvecz: #simd[8]f32 = simd.sub(s.ppz, s.tz1)
	
	invDet := simd.div(simd.f32x8(1.0), det)
	length1 := simd.mul(DotProductSIMD(tvecx, tvecy, tvecz, pvecx, pvecy, pvecz), invDet)

	mask1 = simd.lanes_gt(length1, 0.0)
	mask2 = simd.lanes_le(length1, 1.0)
	masks := simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)
	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	qvecx, qvecy, qvecz := CrossProductSIMD(tvecx, tvecy, tvecz, v1x, v1y, v1z)
	length2 := simd.mul(DotProductSIMD(s.pppx, s.pppy, s.pppz, qvecx, qvecy, qvecz), invDet)

	mask1 = simd.lanes_gt(length2, 0.0)
	mask2 = simd.lanes_le(simd.add(length1, length2), 1.0)
	
	masks = simd.bit_and(mask1, mask2)
	mask = simd.bit_and(mask, masks)
	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	lengthBeam := simd.mul(DotProductSIMD(v2x, v2y, v2z, qvecx, qvecy, qvecz), invDet)
	mask1 = simd.lanes_ge(lengthBeam, 0.0)
	mask = simd.bit_and(mask, mask1)
	return lengthBeam, mask
}

CollisionWithPlane :: proc(start: Point, direction: Point, plane: Plane) -> f32 {
	length: f32 = DotProduct(GetDistance(start, plane.startPoint), plane.normalVector) / DotProduct(direction, plane.normalVector)
	return length
}

PointOnPlane :: proc(point: Point, plane: Plane) -> f32 {
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

GetDirectionFromAngle :: proc(angleHorizontal: f32, angleVertical: f32) -> Point{
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

	x: f32 = math.cos(aH)
	y: f32 = math.sin(aH)
	length :f32 = math.sqrt(x * x + y * y)
	z: f32 = math.tan(aV - 0.5 * math.PI) * length //default height is 0.5 * PI
	res := NormalizeVector(Point{x, y, z})
	return res
}

CreateFrustum :: proc(start: Point, direction: Point) -> [6]Plane{
	renderDistance: f32 = 100

	upVec: Point = Point{0, 0, 1}
	horVec: Point = CrossProduct(direction, upVec)
	horVec = NormalizeVector(horVec)
	vertVec := CrossProduct(direction, horVec)
	vertVec = NormalizeVector(vertVec)
	vertVec = Mult(vertVec, -1)

	leftOffset: Point = Mult(horVec, (- f32(windowWidth) / 2.0) / 400.0)
	upOffset: Point = Mult(vertVec, (f32(windowHeight) / 2.0) / 400.0)
	nearPlane: Plane = Plane{Add(start, Mult(direction, 0.01)), NormalizeVector(Mult(direction, -1))}
	farPlane: Plane = Plane {Add(start, Mult(direction, renderDistance)), NormalizeVector(direction)}
	leftPlane: Plane = Plane {start, NormalizeVector(Mult(CrossProduct(Add(direction, leftOffset), vertVec), -1))}
	rightPlane: Plane = Plane {start, NormalizeVector(CrossProduct(Add(direction, Mult(leftOffset, -1)), vertVec))}
	topPlane: Plane = Plane {start, NormalizeVector(Mult(CrossProduct(Add(direction, upOffset), horVec), -1))}
	bottomPlane: Plane = Plane {start, NormalizeVector(CrossProduct(Add(direction, Mult(upOffset, -1)), horVec))}
	res: [6]Plane = {nearPlane, farPlane, leftPlane, rightPlane, topPlane, bottomPlane}
	return res
}

CompareBeams :: proc(beams: [8]f32, beamColors: [8]u32, mask: [8]u32, previousShortestBeam: f32, previousShortestBeamColor: u32) -> (f32, u32) {
	shortestBeam := previousShortestBeam
	shortestBeamColor := previousShortestBeamColor

	for i: int = 0; i < 8; i = i + 1 {
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

CompareBeamsSingle :: proc(beam1: f32, color1: u32, beam2: f32, color2: u32) -> (f32, u32) {
	if (beam1 < beam2 && beam1 >= 0 || beam2 < 0) { return beam1, color1}
	else if (beam2 < 0){return 0, 0}
	else { return beam2, color2}
}

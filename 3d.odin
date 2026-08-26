package snek

import "core:math"
import "core:simd"

Point :: struct { x:		f32,
	y:		f32,
	z:		f32 // Height
}

PointSoA8 :: struct {
	x:		#simd[8]f32,
	y:		#simd[8]f32,
	z:		#simd[8]f32 // Height
}

Triangle :: struct {
	point1:		Point,
	point2:		Point,
	point3:		Point,
	color:		u32
}

TriangleSoA8Diff :: struct {
	point1:		PointSoA8,
	edge1:		PointSoA8, //Point1 to Point2
	edge2:		PointSoA8, //Point1 to Point3
	color:		#simd[8]u32
}

TriangleSoA8 :: struct {
	point1:		PointSoA8,
	point2:		PointSoA8,
	point3:		PointSoA8,
	color:		#simd[8]u32
}


Plane :: struct {
	startPoint: Point,
	normalVector: Point
}

GetTriangleFromSoA8 :: proc(t: TriangleSoA8, index: int) -> Triangle {
	p1x := transmute([8]f32)t.point1.x
	p1y := transmute([8]f32)t.point1.y
	p1z := transmute([8]f32)t.point1.z

	p2x := transmute([8]f32)t.point2.x
	p2y := transmute([8]f32)t.point2.y
	p2z := transmute([8]f32)t.point2.z

	p3x := transmute([8]f32)t.point3.x
	p3y := transmute([8]f32)t.point3.y
	p3z := transmute([8]f32)t.point3.z

	tc := transmute([8]u32)t.color
	
	return Triangle{
		Point{
			p1x[index],
			p1y[index],
			p1z[index],
		},
		Point{
			p2x[index],
			p2y[index],
			p2z[index],
		},
		Point{
			p3x[index],
			p3y[index],
			p3z[index],
		},
		tc[index]
	}
}

GetTriangleFromSoA8Diff :: proc(t: TriangleSoA8Diff, index: int) -> Triangle {
	p1x := transmute([8]f32)t.point1.x
	p1y := transmute([8]f32)t.point1.y
	p1z := transmute([8]f32)t.point1.z

	p2x := transmute([8]f32)t.edge1.x
	p2y := transmute([8]f32)t.edge1.y
	p2z := transmute([8]f32)t.edge1.z

	p3x := transmute([8]f32)t.edge2.x
	p3y := transmute([8]f32)t.edge2.y
	p3z := transmute([8]f32)t.edge2.z

	tc := transmute([8]u32)t.color
	
	return Triangle{
		Point{
			p1x[index],
			p1y[index],
			p1z[index],
		},
		Point{
			p1x[index] + p2x[index], 
			p1y[index] + p2y[index], 
			p1z[index] + p2z[index], 
		},
		Point{
			p1x[index] + p3x[index], 
			p1y[index] + p3y[index], 
			p1z[index] + p3z[index], 
		},
		tc[index]
	}
}

AddTriangleDiff :: proc(t: ^[dynamic]TriangleSoA8Diff, spareTriangleIndex: ^int, triangle: Triangle) {
	if (spareTriangleIndex^ == 0) {
		append(t, MakeTriangleSoA8Diff({
			triangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle
		}))
		spareTriangleIndex^ += 1
		return
	}

	lastSoA8 := &t[len(t) - 1]

	p1x := transmute(^[8]f32)&(lastSoA8.point1.x)
	p1y := transmute(^[8]f32)&(lastSoA8.point1.y)
	p1z := transmute(^[8]f32)&(lastSoA8.point1.z)

	p2x := transmute(^[8]f32)&(lastSoA8.edge1.x)
	p2y := transmute(^[8]f32)&(lastSoA8.edge1.y)
	p2z := transmute(^[8]f32)&(lastSoA8.edge1.z)

	p3x := transmute(^[8]f32)&(lastSoA8.edge2.x)
	p3y := transmute(^[8]f32)&(lastSoA8.edge2.y)
	p3z := transmute(^[8]f32)&(lastSoA8.edge2.z)

	tc := transmute(^[8]u32)&(lastSoA8.color)

	p1x[spareTriangleIndex^] = triangle.point1.x
	p1y[spareTriangleIndex^] = triangle.point1.y
	p1z[spareTriangleIndex^] = triangle.point1.z

	p2x[spareTriangleIndex^] = triangle.point2.x - triangle.point1.x
	p2y[spareTriangleIndex^] = triangle.point2.y - triangle.point1.y
	p2z[spareTriangleIndex^] = triangle.point2.z - triangle.point1.z

	p3x[spareTriangleIndex^] = triangle.point3.x - triangle.point1.x
	p3y[spareTriangleIndex^] = triangle.point3.y - triangle.point1.y
	p3z[spareTriangleIndex^] = triangle.point3.z - triangle.point1.z

	tc[spareTriangleIndex^] = triangle.color
	spareTriangleIndex^ += 1
	if (spareTriangleIndex^ == 8) {
		spareTriangleIndex^ = 0
	}
}

AddTriangle :: proc(t: ^[dynamic]TriangleSoA8, spareTriangleIndex: ^int, triangle: Triangle) {
	if (spareTriangleIndex^ == 0) {
		append(t, MakeTriangleSoA8({
			triangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle,
			spareTriangle
		}))
		spareTriangleIndex^ += 1
		return
	}

	lastSoA8 := &t[len(t) - 1]

	p1x := transmute(^[8]f32)&(lastSoA8.point1.x)
	p1y := transmute(^[8]f32)&(lastSoA8.point1.y)
	p1z := transmute(^[8]f32)&(lastSoA8.point1.z)

	p2x := transmute(^[8]f32)&(lastSoA8.point2.x)
	p2y := transmute(^[8]f32)&(lastSoA8.point2.y)
	p2z := transmute(^[8]f32)&(lastSoA8.point2.z)

	p3x := transmute(^[8]f32)&(lastSoA8.point3.x)
	p3y := transmute(^[8]f32)&(lastSoA8.point3.y)
	p3z := transmute(^[8]f32)&(lastSoA8.point3.z)

	tc := transmute(^[8]u32)&(lastSoA8.color)

	p1x[spareTriangleIndex^] = triangle.point1.x
	p1y[spareTriangleIndex^] = triangle.point1.y
	p1z[spareTriangleIndex^] = triangle.point1.z

	p2x[spareTriangleIndex^] = triangle.point2.x
	p2y[spareTriangleIndex^] = triangle.point2.y
	p2z[spareTriangleIndex^] = triangle.point2.z

	p3x[spareTriangleIndex^] = triangle.point3.x
	p3y[spareTriangleIndex^] = triangle.point3.y
	p3z[spareTriangleIndex^] = triangle.point3.z

	tc[spareTriangleIndex^] = triangle.color
	spareTriangleIndex^ += 1
	if (spareTriangleIndex^ == 8) {
		spareTriangleIndex^ = 0
	}
}

MakeTriangleSoA8Diff :: proc(t: [8]Triangle) -> TriangleSoA8Diff {
	return TriangleSoA8Diff{
		PointSoA8{
			transmute(simd.f32x8){t[0].point1.x, t[1].point1.x, t[2].point1.x, t[3].point1.x, t[4].point1.x, t[5].point1.x, t[6].point1.x, t[7].point1.x},
			transmute(simd.f32x8){t[0].point1.y, t[1].point1.y, t[2].point1.y, t[3].point1.y, t[4].point1.y, t[5].point1.y, t[6].point1.y, t[7].point1.y},
			transmute(simd.f32x8){t[0].point1.z, t[1].point1.z, t[2].point1.z, t[3].point1.z, t[4].point1.z, t[5].point1.z, t[6].point1.z, t[7].point1.z},
		},
		PointSoA8{
			transmute(simd.f32x8){
				t[0].point2.x - t[0].point1.x,
				t[1].point2.x - t[1].point1.x,
				t[2].point2.x - t[2].point1.x,
				t[3].point2.x - t[3].point1.x,
				t[4].point2.x - t[4].point1.x,
				t[5].point2.x - t[5].point1.x,
				t[6].point2.x - t[6].point1.x,
				t[7].point2.x - t[7].point1.x,
			},
			transmute(simd.f32x8){
				t[0].point2.y - t[0].point1.y,
				t[1].point2.y - t[1].point1.y,
				t[2].point2.y - t[2].point1.y,
				t[3].point2.y - t[3].point1.y,
				t[4].point2.y - t[4].point1.y,
				t[5].point2.y - t[5].point1.y,
				t[6].point2.y - t[6].point1.y,
				t[7].point2.y - t[7].point1.y,
			},
			transmute(simd.f32x8){
				t[0].point2.z - t[0].point1.z,
				t[1].point2.z - t[1].point1.z,
				t[2].point2.z - t[2].point1.z,
				t[3].point2.z - t[3].point1.z,
				t[4].point2.z - t[4].point1.z,
				t[5].point2.z - t[5].point1.z,
				t[6].point2.z - t[6].point1.z,
				t[7].point2.z - t[7].point1.z,
			},
		},
		PointSoA8{
			transmute(simd.f32x8){
				t[0].point3.x - t[0].point1.x,
				t[1].point3.x - t[1].point1.x,
				t[2].point3.x - t[2].point1.x,
				t[3].point3.x - t[3].point1.x,
				t[4].point3.x - t[4].point1.x,
				t[5].point3.x - t[5].point1.x,
				t[6].point3.x - t[6].point1.x,
				t[7].point3.x - t[7].point1.x,
			},
			transmute(simd.f32x8){
				t[0].point3.y - t[0].point1.y,
				t[1].point3.y - t[1].point1.y,
				t[2].point3.y - t[2].point1.y,
				t[3].point3.y - t[3].point1.y,
				t[4].point3.y - t[4].point1.y,
				t[5].point3.y - t[5].point1.y,
				t[6].point3.y - t[6].point1.y,
				t[7].point3.y - t[7].point1.y,
			},
			transmute(simd.f32x8){
				t[0].point3.z - t[0].point1.z,
				t[1].point3.z - t[1].point1.z,
				t[2].point3.z - t[2].point1.z,
				t[3].point3.z - t[3].point1.z,
				t[4].point3.z - t[4].point1.z,
				t[5].point3.z - t[5].point1.z,
				t[6].point3.z - t[6].point1.z,
				t[7].point3.z - t[7].point1.z,
			},
		},
		transmute(simd.u32x8){t[0].color, t[1].color, t[2].color, t[3].color, t[4].color, t[5].color, t[6].color, t[7].color}
	}
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

GetTrianglesFromSoA8Diff :: proc(t: ^TriangleSoA8Diff) -> [8]Triangle{
	p1x := transmute([8]f32)t.point1.x
	p1y := transmute([8]f32)t.point1.y
	p1z := transmute([8]f32)t.point1.z

	p2x := transmute([8]f32)t.edge1.x
	p2y := transmute([8]f32)t.edge1.y
	p2z := transmute([8]f32)t.edge1.z

	p3x := transmute([8]f32)t.edge2.x
	p3y := transmute([8]f32)t.edge2.y
	p3z := transmute([8]f32)t.edge2.z

	tc := transmute([8]u32)t.color
	return {
			Triangle{
				Point{p1x[0], p1y[0], p1z[0]},
				Point{p1x[0] + p2x[0], p1y[0] + p2y[0], p1z[0] + p2z[0]},
				Point{p1x[0] + p3x[0], p1y[0] + p3y[0], p1z[0] + p3z[0]},
				tc[0]
			},
			Triangle{
				Point{p1x[1], p1y[1], p1z[1]},
				Point{p1x[1] + p2x[1], p1y[1] + p2y[1], p1z[1] + p2z[1]},
				Point{p1x[1] + p3x[1], p1y[1] + p3y[1], p1z[1] + p3z[1]},
				tc[1]
			},
			Triangle{
				Point{p1x[2], p1y[2], p1z[2]},
				Point{p1x[2] + p2x[2], p1y[2] + p2y[2], p1z[2] + p2z[2]},
				Point{p1x[2] + p3x[2], p1y[2] + p3y[2], p1z[2] + p3z[2]},
				tc[2]
			},
			Triangle{
				Point{p1x[3], p1y[3], p1z[3]},
				Point{p1x[3] + p2x[3], p1y[3] + p2y[3], p1z[3] + p2z[3]},
				Point{p1x[3] + p3x[3], p1y[3] + p3y[3], p1z[3] + p3z[3]},
				tc[3]
			},
			Triangle{
				Point{p1x[4], p1y[4], p1z[4]},
				Point{p1x[4] + p2x[4], p1y[4] + p2y[4], p1z[4] + p2z[4]},
				Point{p1x[4] + p3x[4], p1y[4] + p3y[4], p1z[4] + p3z[4]},
				tc[4]
			},
			Triangle{
				Point{p1x[5], p1y[5], p1z[5]},
				Point{p1x[5] + p2x[5], p1y[5] + p2y[5], p1z[5] + p2z[5]},
				Point{p1x[5] + p3x[5], p1y[5] + p3y[5], p1z[5] + p3z[5]},
				tc[5]
			},
			Triangle{
				Point{p1x[6], p1y[6], p1z[6]},
				Point{p1x[6] + p2x[6], p1y[6] + p2y[6], p1z[6] + p2z[6]},
				Point{p1x[6] + p3x[6], p1y[6] + p3y[6], p1z[6] + p3z[6]},
				tc[6]
			},
			Triangle{
				Point{p1x[7], p1y[7], p1z[7]},
				Point{p1x[7] + p2x[7], p1y[7] + p2y[7], p1z[7] + p2z[7]},
				Point{p1x[7] + p3x[7], p1y[7] + p3y[7], p1z[7] + p3z[7]},
				tc[7]
			},
		}
}

GetTrianglesFromSoA8 :: proc(t: ^TriangleSoA8) -> [8]Triangle{
	p1x := transmute([8]f32)t.point1.x
	p1y := transmute([8]f32)t.point1.y
	p1z := transmute([8]f32)t.point1.z

	p2x := transmute([8]f32)t.point2.x
	p2y := transmute([8]f32)t.point2.y
	p2z := transmute([8]f32)t.point2.z

	p3x := transmute([8]f32)t.point3.x
	p3y := transmute([8]f32)t.point3.y
	p3z := transmute([8]f32)t.point3.z

	tc := transmute([8]u32)t.color
	return {
			Triangle{
				Point{p1x[0], p1y[0], p1z[0]},
				Point{p2x[0], p2y[0], p2z[0]},
				Point{p3x[0], p3y[0], p3z[0]},
				tc[0]
			},
			Triangle{
				Point{p1x[1], p1y[1], p1z[1]},
				Point{p2x[1], p2y[1], p2z[1]},
				Point{p3x[1], p3y[1], p3z[1]},
				tc[1]
			},
			Triangle{
				Point{p1x[2], p1y[2], p1z[2]},
				Point{p2x[2], p2y[2], p2z[2]},
				Point{p3x[2], p3y[2], p3z[2]},
				tc[2]
			},
			Triangle{
				Point{p1x[3], p1y[3], p1z[3]},
				Point{p2x[3], p2y[3], p2z[3]},
				Point{p3x[3], p3y[3], p3z[3]},
				tc[3]
			},
			Triangle{
				Point{p1x[4], p1y[4], p1z[4]},
				Point{p2x[4], p2y[4], p2z[4]},
				Point{p3x[4], p3y[4], p3z[4]},
				tc[4]
			},
			Triangle{
				Point{p1x[5], p1y[5], p1z[5]},
				Point{p2x[5], p2y[5], p2z[5]},
				Point{p3x[5], p3y[5], p3z[5]},
				tc[5]
			},
			Triangle{
				Point{p1x[6], p1y[6], p1z[6]},
				Point{p2x[6], p2y[6], p2z[6]},
				Point{p3x[6], p3y[6], p3z[6]},
				tc[6]
			},
			Triangle{
				Point{p1x[7], p1y[7], p1z[7]},
				Point{p2x[7], p2y[7], p2z[7]},
				Point{p3x[7], p3y[7], p3z[7]},
				tc[7]
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

CheckCollisionSIMDDiff :: #force_inline proc(t: ^TriangleSoA8Diff, pp: ^PointSoA8, ppd: ^PointSoA8) -> (simd.f32x8, simd.u32x8) {
	pvecx := ppd.y * t.edge2.z - ppd.z * t.edge2.y
	pvecy := ppd.z * t.edge2.x - ppd.x * t.edge2.z
	pvecz := ppd.x * t.edge2.y - ppd.y * t.edge2.x

	det := pvecx * t.edge1.x + pvecy * t.edge1.y + pvecz * t.edge1.z

	//mask is 1 if result valid
	mask := (simd.lanes_gt(det, 0.00001) | simd.lanes_lt(det, -0.00001))

	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	tvecx := simd.sub(pp.x, t.point1.x)
	tvecy := simd.sub(pp.y, t.point1.y)
	tvecz := simd.sub(pp.z, t.point1.z)
	
	invDet := simd.div(simd.f32x8(1.0), det)
	
	length1 := simd.mul(tvecx * pvecx + tvecy * pvecy + tvecz * pvecz, invDet)
	mask = mask & simd.lanes_gt(length1, 0.0) & simd.lanes_le(length1, 1.0)
	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	qvecx := tvecy * t.edge1.z - tvecz * t.edge1.y
	qvecy := tvecz * t.edge1.x - tvecx * t.edge1.z
	qvecz := tvecx * t.edge1.y - tvecy * t.edge1.x
	length2 := simd.mul(ppd.x * qvecx + ppd.y * qvecy + ppd.z * qvecz, invDet)

	mask = mask & simd.lanes_gt(length2, 0.0) & simd.lanes_le(simd.add(length1, length2), 1.0)
	if simd.reduce_or(mask) == 0 {
	    return simd.f32x8(0.0), mask
	}

	lengthBeam := simd.mul(t.edge2.x * qvecx + t.edge2.y * qvecy + t.edge2.z * qvecz, invDet)

	mask = mask & simd.lanes_ge(lengthBeam, 0.0)

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

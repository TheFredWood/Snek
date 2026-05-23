package snek

import "core:slice"
import "core:fmt"

nodes: [dynamic]Node

BoundingBox :: struct {
	lowerBounds:		Position,
	upperBounds:		Position,
	triangle:	^Triangle
}

Node :: struct {
	x:		f16,
	y:		f16,
}

Position :: struct {
	x:		u32,
	y:		u32,
}

GetScreenPosition :: proc(point: Point, direction: Point, horVec: Point, vertVec: Point, nearPlane: Plane) -> (x: u32, y: u32) {
	length := DotProduct(direction, GetDistance(playerPosition, point))
	xPosition := DotProduct(horVec, GetDistance(playerPosition, point)) / length
	yPosition := DotProduct(vertVec, GetDistance(playerPosition, point)) / length
	xPosition = f64(windowWidth) / 2.0 + xPosition * 400.0
	yPosition = f64(windowHeight) / 2.0 - yPosition * 400.0
	return u32(xPosition), u32(yPosition)
}

CullTriangleToFrustum :: proc (triangle: ^Triangle, frustum: [6]Plane) -> (bool, BoundingBox) {
	playerDirection: Point = GetDirectionFromAngle(playerDirectionHorizontal, playerDirectionVertical)
	upVec: Point = Point{0, 0, 1}
	horVec: Point = CrossProduct(playerDirection, upVec)
	horVec = NormalizeVector(horVec)
	vertVec := CrossProduct(playerDirection, horVec)
	vertVec = NormalizeVector(vertVec)
	vertVec = Mult(vertVec, -1)

	points: [dynamic]Point
	append(&points, triangle.point1)
	append(&points, triangle.point2)
	append(&points, triangle.point3)
	i := 0
	for plane in frustum {


		newPoints: [dynamic]Point
		isInside:= true
		lastPoint := points[0]

		//first point
		length := PointOnPlane(points[0], plane) //Positive value means on the frustum side of the plane
		isInside = length >= 0
		if (length >= 0) {
			append(&newPoints, points[0])
		} else {
		}

		//all other points
		for i := 1; i < len(points); i = i + 1 {
			point := points[i]
			lastPoint := points[i - 1]
			length := PointOnPlane(point, plane) //Positive value means on the frustum side of the plane
			if (length >= 0) {
				if (!isInside) {
					distance := GetDistance(point, lastPoint)
					length := CollisionWithPlane(point, distance, plane)
					pointOnPlane := Add(Mult(distance, length), point)
					append(&newPoints, pointOnPlane)
				}
				append(&newPoints, point)
				isInside = true
			} else if (isInside) {
				distance := GetDistance(point, lastPoint)
				length := CollisionWithPlane(point, GetDistance(point, lastPoint), plane)
				pointOnPlane := Add(Mult(distance, length), point)
				append(&newPoints, pointOnPlane)
				isInside = false
			} else {
			}
			if (i == len(points) - 1){
				firstLength := PointOnPlane(points[0], plane) //Positive value means on the frustum side of the plane
				if (firstLength >= 0 && length < 0 || firstLength < 0 && length >= 0){
					distance := GetDistance(point, points[0])
					length := CollisionWithPlane(point, distance, plane)
					pointOnPlane := Add(Mult(distance, length), point)
					append(&newPoints, pointOnPlane)
				}
			}
		}

		if (len(newPoints) == 0){
			return false, BoundingBox{Position{0, 0}, Position{0, 0}, triangle}
		}

		points = newPoints
		i = i + 1
	}
	pointX, pointY := GetScreenPosition(points[0], playerDirection, horVec, vertVec, frustum[0])
	smallestX: u32 = pointX
	biggestX: u32 = pointX
	smallestY: u32 = pointY
	biggestY: u32 = pointY
	for i := 1; i < len(points); i = i + 1 {
		pointX, pointY := GetScreenPosition(points[i], playerDirection, horVec, vertVec, frustum[0])
		if pointX < smallestX {
			smallestX = pointX
		}
		if pointY < smallestY {
			smallestY = pointY
		}
		if (pointY > biggestY){
			biggestY = pointY
		}
		if (pointX > biggestX){
			biggestX = pointX
		}
		if (pointY < 0 || pointY > windowHeight){
			fmt.println("out of bounds Y:", pointY, points[i])
			fmt.println(points)
			fmt.println("directions:", playerDirectionHorizontal, playerDirectionVertical)
		}
		if (pointX < 0 || pointX > windowWidth){
			fmt.println("out of bounds X:", pointX, points[i])
			fmt.println(points)
			fmt.println("directions:", playerDirectionHorizontal, playerDirectionVertical)
		}
	}
	return true, BoundingBox{Position{smallestX, smallestY}, Position{biggestX, biggestY}, triangle}
}

DrawDynamicAreaCentered :: proc(
	screenOccupiedRatio: f16,
	widthToHeight: f16,
	color: u32,
) -> (
	u32,
	u32,
	u32,
	u32,
) {
	width: u32 = cast(u32)(screenOccupiedRatio * cast(f16)bitmapHeight * widthToHeight)
	height: u32 = cast(u32)(screenOccupiedRatio * cast(f16)bitmapHeight)
	startX: u32
	startY: u32
	if (width < cast(u32)(cast(f16)bitmapWidth * screenOccupiedRatio)) {
		startX = ((bitmapWidth - width) / 2)
		startY = cast(u32)((1 - screenOccupiedRatio) * cast(f16)bitmapHeight / 2)
		DrawRectangle(startX, startY, width, height, color)
	} else {
		startX = (bitmapWidth - width) / 2
		startY = (bitmapHeight - height) / 2
		width = cast(u32)(cast(f16)bitmapWidth * screenOccupiedRatio)
		height = cast(u32)(cast(f16)width / widthToHeight)
		DrawRectangle(startX, startY, width, height, color)
	}
	return startX, startY, width, height
}

DrawHollowRectangle :: proc(x: u32, y: u32, width: u32, height: u32, thickness: u32) {
	color: u32 = 0x0088FFFF
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	counter: u32 = 0
	for i: u32 = 0; i < thickness; i = i + 1 {
		section := pixels[x + (i + y) * bitmapWidth:x + width + (i + y) * bitmapWidth]
		for &pixel in section {
			pixel = color
		}
	}
	for i: u32 = 0; i < height - 2 * thickness; i = i + 1 {
		section := pixels[x +
		(i + y + thickness) * bitmapWidth:x +
		width +
		(i + y + thickness) * bitmapWidth]
		counter: u32 = 0
		for &pixel in section {
			if (counter < thickness || counter > u32(width - thickness)) {
				pixel = color
			}
			counter = counter + 1
		}
	}
	for i: u32 = 0; i < thickness; i = i + 1 {
		section := pixels[x +
		(i + y + height - thickness) * bitmapWidth:x +
		width +
		(i + y + height - thickness) * bitmapWidth]
		for &pixel in section {
			pixel = color
		}
	}
}

DrawRectangle :: proc(x: u32, y: u32, width: u32, height: u32, color: u32) {
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	counter: u32 = 0
	for i: u32 = 0; i < height; i = i + 1 {
		section := pixels[x + (i + y) * bitmapWidth:x + width + (i + y) * bitmapWidth]
		for &pixel in section {
			pixel = color
		}
	}
}

RenderWeirdGradient :: proc(blueOffset: u8, greenOffset: u8) {
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	counter: u32 = 0
	for &pixel in pixels {
		x: u32 = counter % bitmapWidth
		y: u32 = (counter - x) / bitmapWidth
		blue: u8 = u8(x) + blueOffset
		green: u8 = u8(y) + greenOffset
		pixel = ((u32(green) << 8) | u32(blue))
		counter = counter + 1
	}
}

CheckCollisionOnNodes :: proc(
	firstLineStart: Node,
	firstLineEnd: Node,
	secondLineStart: Node,
	secondLineEnd: Node,
) -> bool {
	if (firstLineStart.x == secondLineStart.x && firstLineStart.y == secondLineStart.y ||
		   firstLineStart.x == secondLineEnd.x && firstLineStart.y == secondLineEnd.y ||
		   firstLineEnd.x == secondLineEnd.x && firstLineEnd.y == secondLineEnd.y ||
		   firstLineEnd.x == secondLineStart.x && firstLineEnd.y == secondLineStart.y) {
		return true
	}

	x1 := firstLineEnd.x - firstLineStart.x
	lambdaX := (secondLineEnd.x - secondLineStart.x) / x1
	restX := (secondLineStart.x - firstLineStart.x) / x1

	y1 := firstLineEnd.y - firstLineStart.y
	lambdaY := (secondLineEnd.y - secondLineStart.y) / y1
	restY := (secondLineStart.y - firstLineStart.y) / y1

	mu := -(restX - restY) / (lambdaX - lambdaY)
	lambda := lambdaX * mu + restX
	collides := mu >= 0 && mu <= 1 && lambda >= 0 && lambda <= 1
	return collides
}
CheckCollisionOnShape :: proc() -> bool {
	if (len(nodes) < 4) {
		return false
	}
	lastNode := nodes[len(nodes) - 1]
	secondLastNode := nodes[len(nodes) - 2]
	for i := 1; i < len(nodes) - 2; i = i + 1 {
		collides := CheckCollisionOnNodes(nodes[i - 1], nodes[i], lastNode, secondLastNode)
		if (collides) {
			remove_range(&nodes, 0, i)
			return true
		}
	}
	return false

}
DrawPixel :: proc(x: u32, y: u32, color: u32) {
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	pixels[y * bitmapWidth + x] = color
}

DrawLine :: proc(x: u32, y: u32, otherX: u32, otherY: u32) {
	x1 := otherX
	y1 := otherY
	x2 := x
	y2 := y
	if (x > otherX) {
		x1 = x
		y1 = y
		x2 = otherX
		y2 = otherY
	}
	lastY: i32 = cast(i32)y2

	for i := x2; i <= x1; i = i + 1 {
		newY: i32
		if (x2 == x1) {
			newY = cast(i32)y1
		} else {
			gradient: f16 = (cast(f16)y1 - cast(f16)y2) / (cast(f16)x1 - cast(f16)x2)
			newY = (cast(i32)(gradient * cast(f16)(i - x2))) + cast(i32)y2

		}
		if (newY > lastY) {
			DrawRectangle(i, cast(u32)(lastY), 1, cast(u32)(newY - lastY) + 1, 0x0000FF00)
		} else {
			DrawRectangle(i, cast(u32)(newY), 1, cast(u32)(lastY - newY) + 1, 0x0000FF00)
		}
		lastY = newY
	}
}

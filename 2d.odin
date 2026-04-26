package snek

import "core:slice"

Node :: struct {
	x:		f16,
	y:		f16,
	accountedFor:	bool,
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
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	counter: u32 = 0
	for i: u32 = 0; i < thickness; i = i + 1 {
		section := pixels[x + (i + y) * bitmapWidth:x + width + (i + y) * bitmapWidth]
		for &pixel in section {
			pixel = 0x00FFFFFF
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
				pixel = 0x00FFFFFF
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
			pixel = 0x00FFFFFF
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

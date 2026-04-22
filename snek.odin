package snek


import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import win "core:sys/windows"
import "core:time"

running: bool

walkingForward: bool = false
walkingBackwards: bool = false
walkingLeft: bool = false
walkingRight: bool = false
flying: bool = false
descending: bool = false

lastTime: time.Time = time.now()
shapeFinished: bool
nodes: [dynamic]Node
triangles: [dynamic]Triangle 
mouseIsDown: bool
bitmapHandle: win.HBITMAP
bitmapInfo: win.BITMAPINFO
bitmapDeviceContext: win.HDC
bitmapMemory: ^rawptr
bitmapWidth: u32
bitmapHeight: u32
bytesPerPixel: u8 = 4

fovVertical: f64 = 90 / 360.0 * 2 * math.PI
fovHorizontal: f64

playerPosition: Point = {0, 0, 1}
playerDirectionHorizontal: f64 = 0.0 / 360.0 * 2 * math.PI // Angle from 1, 0 clockwise
playerDirectionVertical: f64 = 90.0 / 360.0 * 2 * math.PI // Angle from the bottom (0) to top (180)

windowX: u32
windowY: u32
windowWidth: u32
windowHeight: u32

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

CrossProduct :: proc(v1: Point, v2: Point) -> Point {
	return Point{
		v1.y * v2.z - v1.z * v2.y,
		v1.z * v2.x - v1.x * v2.z,
		v1.x * v2.y - v1.y * v2.x
	}
}

DotProduct :: proc(v1: Point, v2: Point) -> f64 {
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
}

SplitShapeToTriangles :: proc(shape: [dynamic]Node) {
	for i := 0; i < len(nodes); i = i + 1 {
		firstPoint := nodes[i]
		midPoint := nodes[i + 1]

		
	}
	//TODO: Implement
}

CheckCollision :: proc(direction: Point, triangle: Triangle) -> f64{
	v1 := Point{triangle.point2.x - triangle.point1.x, triangle.point2.y - triangle.point1.y, triangle.point2.z - triangle.point1.z}
	v2 := Point{triangle.point3.x - triangle.point1.x, triangle.point3.y - triangle.point1.y, triangle.point3.z - triangle.point1.z}
	//zwei Variablen eliminieren, indem das skalarprodukt mit einem mit v2 und d orthogonalen Vektoren genommen wird, wodurch die Terme wefallen
	pvec := CrossProduct(direction, v2)
	det := DotProduct(pvec, v1)

	if (det < 0.00001 && det > -0.00001){ //direction parallel zur Ebene
		return -1
	}
	length1 := DotProduct(Point{playerPosition.x - triangle.point1.x, playerPosition.y - triangle.point1.y, playerPosition.z - triangle.point1.z}, pvec) / det

	if (length1 < 0.0 || length1 > 1.0) {
		return -1
	}
	tvec := Point{playerPosition.x - triangle.point1.x, playerPosition.y - triangle.point1.y, playerPosition.z - triangle.point1.z}
	qvec := CrossProduct(tvec, v1)
	length2 := DotProduct(direction, qvec) / det
	if (length2 < 0.0 || length1 + length2 > 1.0){
		return -1
	}
	lengthBeam := DotProduct(v2, qvec) / det
	return lengthBeam
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
	totalLength := math.sqrt(x * x + y * y + z * z)
	return {x / totalLength, y / totalLength, z / totalLength}
}

MovePlayer :: proc () {
	speed: f64 = 1 //units per second
	d := time.duration_seconds(time.since(lastTime))
	direction: Point
	if (walkingForward) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal, playerDirectionVertical)
	}
	if (walkingBackwards) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal + math.PI, playerDirectionVertical)
	}
	if (walkingLeft) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal + 0.5 * math.PI, playerDirectionVertical)
	}
	if (walkingRight) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal - 0.5 * math.PI, playerDirectionVertical)
	}
	if (flying) {
		direction = {0, 0, 1}
	}
	if (descending) {
		direction = {0, 0, -1}
	}
	playerPosition = {playerPosition.x +  direction.x * speed * d, playerPosition.y + direction.y * speed * d, playerPosition.z + direction.z * speed * d}

}

RenderWindow :: proc() {
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	windowX, windowY, windowWidth, windowHeight = DrawDynamicAreaCentered(1, 16.0/9.0, 0x00FFFFFF)
	fovHorizontal = f64(windowWidth) / f64(windowHeight) * f64(fovVertical)
	for i: u32 = 0; i < windowHeight; i = i + 1 {
		section := pixels[windowX + (i + windowY) * bitmapWidth:windowX + windowWidth + (i + windowY) * bitmapWidth]
		angleVertical: f64 = (-f64(i) / f64(windowHeight) + 0.5) * fovVertical + playerDirectionVertical
		for j: u32 = 0; j < windowWidth; j = j + 1 {
			angleHorizontal: f64 = (-f64(j) / f64(windowWidth) + 0.5) * fovHorizontal + playerDirectionHorizontal
			direction: Point = GetDirectionFromAngle(angleHorizontal, angleVertical)
			shortestBeam : f64 = -1
			shortestBeamColor: u32 = 0x00000000
			for triangle in triangles {
				beamLength: f64 = CheckCollision(direction, triangle)
				if (beamLength > 0 && (beamLength < shortestBeam || shortestBeam < 0)) {
					shortestBeam = beamLength
					shortestBeamColor = triangle.color
				}
			}
			if (shortestBeam > 0) {
				section[j] = shortestBeamColor
			}
		}
	}
}

main :: proc() {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))
	//prevInstance is totally useless
	CommandLine: win.LPCTSTR = win.GetCommandLineW()
	//ShowCode is pretty useless

	windowClass: win.WNDCLASSW = {}
	windowClass.lpfnWndProc = Win32MainWindowCallback
	windowClass.hInstance = instance
	windowClass.lpszClassName = "HandmadeHeroWindowClass"

	if (win.RegisterClassW(&windowClass) != 0) {
		window: win.HWND = win.CreateWindowExW(
			0,
			windowClass.lpszClassName,
			"Handmade Hero",
			win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
			win.CW_USEDEFAULT,
			win.CW_USEDEFAULT,
			win.CW_USEDEFAULT,
			win.CW_USEDEFAULT,
			nil,
			nil,
			instance,
			nil,
		)
		if (window != nil) {


			triangle: Triangle = Triangle{Point{3.0, -1.0, 0.0}, Point{3.0, 1.0, 0.0}, Point{3.0, 0.0, 2.0}, 0x00FF00FF }
			floor: Triangle = Triangle{Point{-100, -100, 0.0}, Point{100, -100, 0.0}, Point{100, 100, 0.0}, 0x0000FF00 }
			floor2: Triangle = Triangle{Point{-100, -100, 0.0}, Point{-100, 100, 0.0}, Point{100, 100, 0.0}, 0x0000FF00 }
			append(&triangles, triangle)
			append(&triangles, floor)
			append(&triangles, floor2)

			running = true
			secondTimer: time.Time = time.now()
			currentTime: time.Time = time.now()
			rect : win.RECT
			win.GetClientRect(window, &rect)
			topLeft := win.POINT{rect.left, rect.top}
			bottomRight := win.POINT{rect.right, rect.bottom}
			win.ClientToScreen(window, &topLeft)
			win.ClientToScreen(window, &bottomRight)
			screenRect : win.RECT = {
				left = topLeft.x,
				top = topLeft.y,
				right = bottomRight.x,
				bottom = bottomRight.y,
			}


			//win.MapWindowPoints(window, nil, win.LPPOINT(&rect), 2)
			win.ClipCursor(&screenRect)
			for running {
				message: win.MSG
				for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
					if (message.message == win.WM_QUIT) {
						running = false
					}
					win.TranslateMessage(&message)
					win.DispatchMessageW(&message)
				}
				MovePlayer()
				RenderWindow()

				deviceContext: win.HDC = win.GetDC(window)
				clientRect: win.RECT
				win.GetClientRect(window, &clientRect)
				windowWidth: i32 = clientRect.right - clientRect.left
				windowHeight: i32 = clientRect.bottom - clientRect.top
				Win32UpdateWindow(deviceContext, &clientRect, 0, 0, windowWidth, windowHeight)
				win.ReleaseDC(window, deviceContext)

				if (time.since(secondTimer) >= time.Second){
					fmt.println("done, took", time.since(currentTime))
					fmt.println(playerPosition)
					secondTimer = time.now()

				}
				lastTime = currentTime
				currentTime = time.now()
			}

		} else {
			//logging
		}
	} else {
		//logging
	}

}

Win32MainWindowCallback :: proc "std" (
	window: win.HWND,
	message: win.UINT,
	wParam: win.WPARAM,
	lParam: win.LPARAM,
) -> win.LRESULT {
	context = runtime.default_context()
	result: win.LRESULT = 0
	switch message {
	case win.WM_CREATE: 
		Rid: win.RAWINPUTDEVICE 

		Rid.usUsagePage = 0x01
		Rid.usUsage = 0x02
		Rid.dwFlags = win.RIDEV_INPUTSINK
		Rid.hwndTarget = window
		if(win.RegisterRawInputDevices(&Rid, 1, size_of(Rid)) == false) {
			//Error handling
		}
	case win.WM_INPUT:
		data :win.RAWINPUT
		pcbSize: u32 = size_of(win.RAWINPUT)
		win.GetRawInputData(win.HRAWINPUT(lParam), win.RID_INPUT, &data, &pcbSize, size_of(win.RAWINPUTHEADER))
		deltaX := data.data.mouse.lLastX
		deltaY := data.data.mouse.lLastY
		playerDirectionHorizontal = playerDirectionHorizontal - f64(deltaX) /1000
		playerDirectionVertical = playerDirectionVertical - f64(deltaY) /1000
	case win.WM_SIZE:
		clientRect: win.RECT
		win.GetClientRect(window, &clientRect)
		width := clientRect.right - clientRect.left
		height := clientRect.bottom - clientRect.top
		Win32ResizeDIBSection(u32(width), u32(height))
	case win.WM_CLOSE:
		running = false
	case win.WM_DESTROY:
		running = false
	case win.WM_PAINT:
		paint: win.PAINTSTRUCT
		deviceContext: win.HDC = win.BeginPaint(window, &paint)
		x := paint.rcPaint.left
		y := paint.rcPaint.top
		width := paint.rcPaint.right - paint.rcPaint.left
		height := paint.rcPaint.bottom - paint.rcPaint.top

		clientRect: win.RECT
		win.GetClientRect(window, &clientRect)

		Win32UpdateWindow(deviceContext, &clientRect, x, y, width, height)
		win.EndPaint(window, &paint)
	case win.WM_KEYDOWN:
		switch wParam {
			case win.VK_W:
				walkingForward = true	
			case win.VK_S:
				walkingBackwards = true	
			case win.VK_A:
				walkingLeft = true	
			case win.VK_D:
				walkingRight = true	
			case win.VK_SPACE:
				flying = true	
			case win.VK_SHIFT:
				descending = true	
		}

	case win.WM_KEYUP:
		switch wParam {
			case win.VK_W:
				walkingForward = false	
			case win.VK_S:
				walkingBackwards = false	
			case win.VK_A:
				walkingLeft = false	
			case win.VK_D:
				walkingRight = false	
			case win.VK_SPACE:
				flying = false	
			case win.VK_SHIFT:
				descending = false	
		}

	case win.WM_LBUTTONUP:
	case win.WM_LBUTTONDOWN:
		clear_dynamic_array(&nodes)
	//win.GET_X_LPARAM(lParam)
	//win.GET_Y_LPARAM(lParam)
	case win.WM_MOUSEMOVE:
	case:
		result = win.DefWindowProcW(window, message, wParam, lParam)
	}
	return result
}

Win32ResizeDIBSection :: proc(width: u32, height: u32) {
	if (bitmapHandle != nil) {
		win.VirtualFree(bitmapMemory, 0, win.MEM_RELEASE)
	}

	bitmapWidth = width
	bitmapHeight = height

	bitmapInfo.bmiHeader.biSize = size_of(bitmapInfo.bmiHeader)
	bitmapInfo.bmiHeader.biWidth = i32(bitmapWidth)
	bitmapInfo.bmiHeader.biHeight = i32(-bitmapHeight)
	bitmapInfo.bmiHeader.biPlanes = 1
	bitmapInfo.bmiHeader.biBitCount = 32
	bitmapInfo.bmiHeader.biCompression = win.BI_RGB

	bitmapMemorySize: i32 = i32(bitmapWidth) * i32(bitmapHeight) * i32(bytesPerPixel)
	bitmapMemory = cast(^rawptr)win.VirtualAlloc(
		nil,
		uint(bitmapMemorySize),
		win.MEM_COMMIT,
		win.PAGE_READWRITE,
	)

}

Win32UpdateWindow :: proc(
	deviceContext: win.HDC,
	clientRect: ^win.RECT,
	x: i32,
	y: i32,
	width: i32,
	height: i32,
) {
	windowWidth: i32 = clientRect.right - clientRect.left
	windowHeight: i32 = clientRect.bottom - clientRect.top
	win.StretchDIBits(
		deviceContext,
		//x, y, width, height,
		//x, y, width, height,
		0,
		0,
		i32(bitmapWidth),
		i32(bitmapHeight),
		0,
		0,
		windowWidth,
		windowHeight,
		bitmapMemory,
		&bitmapInfo,
		win.DIB_RGB_COLORS,
		win.SRCCOPY,
	)
}

//----------------------------------------------2D------------------------------------------------

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
		//pixel = 0x8F0000FF
		//pixel = u32(blue)
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
	//cast(u32)(newY - lastY)

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

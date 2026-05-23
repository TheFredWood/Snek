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
triangles: [dynamic]Triangle 
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

TimeFunction :: proc(func: proc(), repititions: int){
	startTime := time.now()	

	times := make([dynamic]time.Duration, 0, repititions)
	newTime := time.now()
	oldTime := time.now()
	for i := 0; i < repititions; i = i + 1 {
		func()
		append(&times, time.since(oldTime))
		oldTime = time.now()
	}
	maxValue: time.Duration = times[0]
	minValue: time.Duration = times[0]
	sum : time.Duration = times[0]
	for i := 1; i < repititions; i = i + 1 {
		sum = sum + times[i]
		if (times[i] > maxValue) {
			maxValue = times[i]
		}
		if (times[i] < minValue) {
			minValue = times[i]
		}
	}
	average := sum / time.Duration(repititions)
	fmt.println("max:", maxValue, "min:", minValue, "average:", average)
}

MovePlayer :: proc () {
	speed: f64 = 4 //units per second
	d := time.duration_seconds(time.since(lastTime))
	direction: Point
	if (walkingForward) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal, 0.5 * math.PI)
	}
	if (walkingBackwards) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal + math.PI, 0.5 * math.PI)
	}
	if (walkingLeft) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal + 0.5 * math.PI, 0.5 * math.PI)
	}
	if (walkingRight) {
		direction = GetDirectionFromAngle(playerDirectionHorizontal - 0.5 * math.PI, 0.5 * math.PI)
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
	boundingBoxes: [dynamic]BoundingBox
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	windowX, windowY, windowWidth, windowHeight = DrawDynamicAreaCentered(1, 16.0/9.0, 0x00FFFFFF)
	fovHorizontal = f64(windowWidth) / f64(windowHeight) * f64(fovVertical)
	playerDirection: Point = GetDirectionFromAngle(playerDirectionHorizontal, playerDirectionVertical)
	upVec: Point = Point{0, 0, 1}
	horVec: Point = CrossProduct(playerDirection, upVec)
	horVec = NormalizeVector(horVec)
	vertVec := CrossProduct(playerDirection, horVec)
	vertVec = NormalizeVector(vertVec)
	vertVec = Mult(vertVec, -1)
	

	frustum: [6]Plane = CreateFrustum(playerPosition, playerDirection)
	for &triangle in triangles {
		isInside, boundingBox := CullTriangleToFrustum(&triangle, frustum)
		if (isInside){
			append(&boundingBoxes, boundingBox)
		}
	}

	for i: u32 = 0; i < windowHeight; i = i + 1 {
		section := pixels[windowX + (i + windowY) * bitmapWidth:windowX + windowWidth + (i + windowY) * bitmapWidth]
		relevantTriangles: [dynamic]Triangle
		for boundingBox in boundingBoxes {
			if (boundingBox.lowerBounds.y < i && boundingBox.upperBounds.y > i) {
				append(&relevantTriangles, boundingBox.triangle^)
			}
		}
		for j: u32 = 0; j < windowWidth; j = j + 1 {
			shortestBeam : f64 = -1
			shortestBeamColor: u32 = 0x00000000
			for triangle in relevantTriangles {
				pixelplayerDirection: Point = Add(Add(playerDirection, Mult(horVec, (f64(j) - f64(windowWidth) / 2.0) / 400.0)), Mult(vertVec, (f64(windowHeight) / 2.0 - f64(i)) / 400))
				beamLength: f64 = CheckCollision(playerPosition, pixelplayerDirection, triangle)
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
	windowClass.lpszClassName = "SnekWindowClass"

	if (win.RegisterClassW(&windowClass) != 0) {
		window: win.HWND = win.CreateWindowExW(
			0,
			windowClass.lpszClassName,
			"Snek",
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


			triangle: Triangle = Triangle{Point{3.0, -1.0, 0.0}, Point{3.0, 1.0, 0.0}, Point{4.0, 0.0, 2.0}, 0x00FF00DF }
			triangle2: Triangle = Triangle{Point{5.0, -1.0, 0.0}, Point{3.0, -1.0, 0.0}, Point{4.0, 0.0, 2.0}, 0x00FF00AF }
			triangle3: Triangle = Triangle{Point{5.0, 1.0, 0.0}, Point{3.0, 1.0, 0.0}, Point{4.0, 0.0, 2.0}, 0x00FF009F }
			triangle4: Triangle = Triangle{Point{5.0, -1.0, 0.0}, Point{5.0, 1.0, 0.0}, Point{4.0, 0.0, 2.0}, 0x00FF007F }
			floor: Triangle = Triangle{Point{-100, -100, 0.0}, Point{100, -100, 0.0}, Point{100, 100, 0.0}, 0x0000FF00 }
			floor2: Triangle = Triangle{Point{-100, -100, 0.0}, Point{-100, 100, 0.0}, Point{100, 100, 0.0}, 0x0000FF00 }
			append(&triangles, triangle)
			append(&triangles, triangle2)
			append(&triangles, triangle3)
			append(&triangles, triangle4)
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

			win.ShowCursor(false)
			//win.MapWindowPoints(window, nil, win.LPPOINT(&rect), 2)
			//TimeFunction(proc(){RenderWindow()}, 100)
			//TimeFunction(proc(){RenderWindow2()}, 100)
			fmt.println(bitmapWidth, bitmapHeight)


			for running {
				//win.ClipCursor(&screenRect)
				message: win.MSG
				for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
					if (message.message == win.WM_QUIT) {
						running = false
					}
					win.TranslateMessage(&message)
					win.DispatchMessageW(&message)
				}


				deviceContext: win.HDC = win.GetDC(window)
				clientRect: win.RECT
				win.GetClientRect(window, &clientRect)
				windowWidth: i32 = clientRect.right - clientRect.left
				windowHeight: i32 = clientRect.bottom - clientRect.top
				Win32UpdateWindow(deviceContext, &clientRect, 0, 0, windowWidth, windowHeight)
				win.ReleaseDC(window, deviceContext)

				RenderWindow()
				MovePlayer()

				if (time.since(secondTimer) >= time.Second){
					fmt.println("done, took", time.since(currentTime))

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


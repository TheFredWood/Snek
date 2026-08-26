package snek


import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import win "core:sys/windows"
import "core:time"
import "base:intrinsics"
import "core:simd"

running: bool
walkingForward: bool = false
walkingBackwards: bool = false
walkingLeft: bool = false
walkingRight: bool = false
flying: bool = false
descending: bool = false

lastTime: time.Time = time.now()
shapeFinished: bool
globalTriangles: [dynamic]TriangleSoA8Diff
spareTriangleIndex := 0 //index from where there are spare triangles in globalTriangles ASoA8
spareTriangle := Triangle{ Point{0, 0, 0}, Point{0, 0, 0}, Point{0, 0, 0}, 0}

bitmapHandle: win.HBITMAP
bitmapInfo: win.BITMAPINFO
bitmapDeviceContext: win.HDC
bitmapMemory: ^rawptr
bitmapWidth: u32
bitmapHeight: u32
bytesPerPixel: u8 = 4

fovVertical: f32 = 90 / 360.0 * 2 * math.PI
fovHorizontal: f32
playerPosition: Point = {0, 0, 1}
playerDirectionHorizontal: f32 = 0.0 / 360.0 * 2 * math.PI // Angle from 1, 0 clockwise
playerDirectionVertical: f32 = 90.0 / 360.0 * 2 * math.PI // Angle from the bottom (0) to top (180)

windowX: u32
windowY: u32
windowWidth: u32
windowHeight: u32

startRenderingEvent: win.HANDLE
workerDoneCounter: u32
frameInfo: FrameInfo
resetThreads: u32 = 0


TimeFunction2 :: proc(func: proc(), repititions: int){
	for i := 0; i < 50; i = i + 1 {
		func()
	}

	startTime := time.now()

	for i := 0; i < repititions; i = i + 1 {
		func()
	}

	endTime := time.now()

	average := time.diff(startTime, endTime) / time.Duration(repititions)
	fmt.println("time:", time.diff(startTime, endTime), "average:", average)
}

TimeFunction :: proc(func: proc(), repititions: int){
	for i := 0; i < 50; i = i + 1 {
		func()
	}
	startTime := time.now()	

	times := make([dynamic]time.Duration, 0, repititions)
	defer delete(times)
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
	speed: f32 = 4 //units per second
	d := time.duration_seconds(time.since(lastTime))
	direction: Point = {0, 0, 0}
	if (walkingForward) {
		direction = Add(direction, GetDirectionFromAngle(playerDirectionHorizontal, 0.5 * math.PI))
	}
	if (walkingBackwards) {
		direction = Add(direction, GetDirectionFromAngle(playerDirectionHorizontal + math.PI, 0.5 * math.PI))
	}
	if (walkingLeft) {
		direction = Add(direction, GetDirectionFromAngle(playerDirectionHorizontal + 0.5 * math.PI, 0.5 * math.PI))
	}
	if (walkingRight) {
		direction = Add(direction, GetDirectionFromAngle(playerDirectionHorizontal - 0.5 * math.PI, 0.5 * math.PI))
	}
	if (flying) {
		direction = Add(direction, {0, 0, 1})
	}
	if (descending) {
		direction = Add(direction, {0, 0, -1})
	}
	if (direction != {0, 0, 0}){
		direction = NormalizeVector(direction)
	}
	playerPosition = {playerPosition.x +  direction.x * speed * cast(f32)d, playerPosition.y + direction.y * speed * cast(f32)d, playerPosition.z + direction.z * speed * cast(f32)d}
}

RenderWindow :: proc() {
	windowX, windowY, windowWidth, windowHeight = DrawDynamicAreaCentered(1, 16.0/9.0, 0x00FFFFFF)
	fovHorizontal = f32(windowWidth) / f32(windowHeight) * f32(fovVertical)
	playerDirection: Point = GetDirectionFromAngle(playerDirectionHorizontal, playerDirectionVertical)
	
	blockSize: u32 = 16
	blocks := make([dynamic]Block, 0, u32(math.ceil(f32(windowWidth) / f32(blockSize)))* u32(math.ceil(f32(windowHeight) / f32(blockSize))))

	for j: u32 = 0; j < u32(math.ceil(f32(windowWidth) / f32(blockSize))); j = j + 1 {
		for i: u32 = 0; i < u32(math.ceil(f32(windowHeight) / f32(blockSize))); i = i + 1 {
			endX : u32 = (j + 1) * blockSize
			endY : u32 = (i + 1) * blockSize
			if (endY > windowHeight){
				endY = windowHeight
			}
			if (endX > windowWidth){
				endX = windowWidth
			}
			append(&blocks, Block{Position{j * blockSize, i * blockSize}, Position{endX, endY}})
		}
	}

	frustum: [6]Plane = CreateFrustum(playerPosition, playerDirection)
	boundingBoxes := make([dynamic]BoundingBoxSoA8, 0, len(globalTriangles))
	defer delete(boundingBoxes)
	upVec: Point = Point{0, 0, 1}
	horVec: Point = CrossProduct(playerDirection, upVec)
	horVec = NormalizeVector(horVec)
	vertVec := CrossProduct(playerDirection, horVec)
	vertVec = NormalizeVector(vertVec)
	vertVec = Mult(vertVec, -1)
	for &triangleSoA8 in globalTriangles {
			isInside, boundingBoxSoA8 := CullTriangleToFrustumSIMD(triangleSoA8 , frustum, playerDirection, horVec, vertVec)
			if simd.reduce_or(transmute(simd.u32x8)isInside) == 1 {
				append(&boundingBoxes, boundingBoxSoA8)
		}
	}
	//fmt.println(len(boundingBoxes))
	win.ResetEvent(startRenderingEvent)
	intrinsics.atomic_thread_fence(.Release)
	frameInfo.blocks = blocks
	frameInfo.blockCounter = 0
	frameInfo.horVec = horVec
	frameInfo.vertVec = vertVec
	frameInfo.playerDirection = playerDirection
	frameInfo.boundingBoxes = boundingBoxes

	sysInfo: win.SYSTEM_INFO
	win.GetSystemInfo(&sysInfo)
	workerDoneCounter = sysInfo.dwNumberOfProcessors - 1


	for (intrinsics.atomic_load(&resetThreads) < sysInfo.dwNumberOfProcessors - 1){
		//Wait
	}
	resetThreads = 0
	win.SetEvent(startRenderingEvent)

	for (intrinsics.atomic_load(&workerDoneCounter) > 0){
		//wait
		win.Sleep(0)
	}
}

ThreadArgs :: struct {
	ctx: runtime.Context,
	frameInfo: ^FrameInfo
}

FrameInfo :: struct {
	blocks: [dynamic]Block,
	blockCounter: int,
	horVec: Point,
	vertVec: Point,
	playerDirection: Point,
	boundingBoxes: [dynamic]BoundingBoxSoA8,
}

RenderBlockIfAvailable :: proc "stdcall" (param: win.LPVOID) -> win.DWORD {
	args := (^ThreadArgs)(param)
	context = args.ctx
	intrinsics.atomic_add(&resetThreads, 1)
	//Wait for Task to arrive with the FrameInfo
	win.WaitForSingleObject(startRenderingEvent, win.INFINITE)
	relevantTriangles := make ([dynamic]TriangleSoA8Diff , 0, len(args.frameInfo.boundingBoxes))

	defer delete(relevantTriangles)
	for true {

		win.WaitForSingleObject(startRenderingEvent, win.INFINITE)
		oldValue := intrinsics.atomic_add(&args.frameInfo.blockCounter, 1)
		if (oldValue < len(args.frameInfo.blocks)){
			clear(&relevantTriangles)
			RenderBlock(param, oldValue, &relevantTriangles)
		} else {
			intrinsics.atomic_sub(&workerDoneCounter, 1)
			for (win.WaitForSingleObject(startRenderingEvent, 0) == win.WAIT_OBJECT_0){
				win.Sleep(0)
			}
			intrinsics.atomic_add(&resetThreads, 1)
		}
	}
	return 0
}

RenderBlock :: proc (param: win.LPVOID, blockIndex: int, relevantTriangles: ^[dynamic]TriangleSoA8Diff) {
	args := (^ThreadArgs)(param)
	block := args.frameInfo.blocks[blockIndex]
	horVec := args.frameInfo.horVec
	vertVec := args.frameInfo.vertVec
	playerDirection := args.frameInfo.playerDirection
	boundingBoxes := args.frameInfo.boundingBoxes
	counter := 0
	triangles: [8]Triangle
	for &boundingBox in boundingBoxes {
		/*
		fmt.println(simd.reduce_or(simd.lanes_le(transmute(simd.u32x8)boundingBox.lowerBounds.y, cast(simd.u32x8)block.end.y) &
			simd.lanes_ge(transmute(simd.u32x8)boundingBox.upperBounds.y, cast(simd.u32x8)block.start.y) &
			simd.lanes_le(transmute(simd.u32x8)boundingBox.lowerBounds.x, cast(simd.u32x8)block.end.x) &
			simd.lanes_ge(transmute(simd.u32x8)boundingBox.upperBounds.x, cast(simd.u32x8)block.start.x)
			))
		if simd.reduce_or(simd.lanes_le(transmute(simd.u32x8)boundingBox.lowerBounds.y, cast(simd.u32x8)block.end.y) &
			simd.lanes_ge(transmute(simd.u32x8)boundingBox.upperBounds.y, cast(simd.u32x8)block.start.y) &
			simd.lanes_le(transmute(simd.u32x8)boundingBox.lowerBounds.x, cast(simd.u32x8)block.end.x) &
			simd.lanes_ge(transmute(simd.u32x8)boundingBox.upperBounds.x, cast(simd.u32x8)block.start.x)
			) >= 1 {
			append(relevantTriangles, boundingBox.triangles)
		}
		*/
		t := GetTrianglesFromSoA8Diff(&boundingBox.triangles)
		for i := 0; i < 8; i += 1 {
			if (	boundingBox.lowerBounds.x[i] <= block.end.x &&
				boundingBox.lowerBounds.y[i] <= block.end.y &&
				boundingBox.upperBounds.x[i] >= block.start.x &&
				boundingBox.upperBounds.y[i] >= block.start.y) {

				triangles[counter] = t[i]
				counter += 1
				if (counter == 8) {
					append(relevantTriangles, MakeTriangleSoA8Diff(triangles))
					counter = 0
				}
					
			}

		}

		//AddTriangleDiff(relevantTriangles, &counter, boundingBox.triangle)
	}
	if (counter != 0){
		for i := counter; i < 8; i = i + 1 {
			triangles[i] = spareTriangle
		}
		append(relevantTriangles, MakeTriangleSoA8Diff(triangles))
	}

	if (len(relevantTriangles) == 0){ 
		return
	}
	playerPositionSoA8 := PointSoA8{cast(simd.f32x8)playerPosition.x, cast(simd.f32x8)playerPosition.y, cast(simd.f32x8)playerPosition.z}
	pixels := slice.from_ptr(cast(^u32)bitmapMemory, cast(int)(bitmapHeight * bitmapWidth))
	for i: u32 = block.start.y; i < block.end.y; i = i + 1 {
		section := pixels[windowX + (i + windowY) * bitmapWidth:windowX + windowWidth + (i + windowY) * bitmapWidth]
		yOffset := Mult(vertVec, (f32(windowHeight) / 2.0 - f32(i)) / 400)
		yOffsetDirection := Add(playerDirection, yOffset)
		for j: u32 = block.start.x; j < block.end.x; j = j + 1 {
			shortestBeam : f32 = -1
			shortestBeamColor: u32 = 0x00FFFFFF
			xOffset := Mult(horVec, (f32(j) - f32(windowWidth) / 2.0) / 400.0)
			pixelPlayerDirection := Add(yOffsetDirection, xOffset)
			pixelPlayerDirectionSoA8 := PointSoA8{cast(simd.f32x8)pixelPlayerDirection.x, cast(simd.f32x8)pixelPlayerDirection.y, cast(simd.f32x8)pixelPlayerDirection.z}

			for k := 0; k < len(relevantTriangles); k = k + 1 {

				beamLength, maskResult := CheckCollisionSIMDDiff(
					&relevantTriangles[k],
					&playerPositionSoA8,
					&pixelPlayerDirectionSoA8)	

				if maskResult != 0 {
					shortestBeam, shortestBeamColor = CompareBeams(transmute([8]f32)beamLength, transmute([8]u32)relevantTriangles[k].color, transmute([8]u32)maskResult, shortestBeam, shortestBeamColor)
				}
			}

			section[j] = shortestBeamColor
		}
	}
}

main :: proc() {
	sysInfo: win.SYSTEM_INFO
	win.GetSystemInfo(&sysInfo)
	threadArgs: ThreadArgs
	threadArgs.ctx = context
	threadArgs.frameInfo = &frameInfo
	startRenderingEvent = win.CreateEventW(nil, true, false, nil)
	handles := make([dynamic]win.HANDLE, 0, sysInfo.dwNumberOfProcessors)
	defer delete(handles)
	for i: u32 = 0; i < sysInfo.dwNumberOfProcessors - 1;i = i + 1 {
		threadId: win.DWORD
		threadHandle := win.CreateThread(
			nil,
			0,
			RenderBlockIfAvailable,
			&threadArgs,
			0,
			&threadId,
		)
		if (threadHandle == nil) {
			fmt.println("error with thread")
		}
		append(&handles, threadHandle)
	}

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
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, triangle)
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, triangle2)
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, triangle3)
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, triangle4)
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, floor)
			AddTriangleDiff(&globalTriangles, &spareTriangleIndex, floor2)

			rand.reset(1)
			for i := 0; i < 1000; i = i + 1 {
				p1 := Point{rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100)}
				p2 := Point{rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100)}
				p3 := Point{rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100), rand.float32_range(-100.0, 100)}
				AddTriangleDiff(&globalTriangles, &spareTriangleIndex, Triangle{p1, p2, p3, rand.uint32()})
			}

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
			benchmarking := false
			if (benchmarking) {
				TimeFunction2(proc(){RenderWindow()}, 100)
				return
			}else {
				fmt.println(bitmapWidth, bitmapHeight)

				i := 0
				//RenderWindow()
				//fmt.println(globalTriangles)
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

					clientRect: win.RECT
					win.GetClientRect(window, &clientRect)
					windowWidth: i32 = clientRect.right - clientRect.left
					windowHeight: i32 = clientRect.bottom - clientRect.top
					MovePlayer()
					if (i % 2 == 1) {
						//RenderWindow2()
					} else {
						RenderWindow()
					}

					deviceContext: win.HDC = win.GetDC(window)
					Win32UpdateWindow(deviceContext, &clientRect, 0, 0, windowWidth, windowHeight)
					win.ReleaseDC(window, deviceContext)

					if (time.since(secondTimer) >= time.Second){
						fmt.println("done, took", time.since(currentTime))

						secondTimer = time.now()

					}

					lastTime = currentTime
					currentTime = time.now()
					//i = i + 1
				}


			}
		} else {
			//logging
		}
	} else {
		//logging
	}

	//win.WaitForMultipleObjects(win.DWORD(len(handles)), &handles[0],  true, win.INFINITE)
	for handle in handles {
		win.WaitForSingleObject(handle, win.INFINITE)
		win.CloseHandle(handle)
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
		playerDirectionHorizontal = playerDirectionHorizontal - f32(deltaX) /1000
		playerDirectionVertical = playerDirectionVertical - f32(deltaY) /1000
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
		x := paint.rcPaint.left
		y := paint.rcPaint.top
		width := paint.rcPaint.right - paint.rcPaint.left
		height := paint.rcPaint.bottom - paint.rcPaint.top

		clientRect: win.RECT
		win.GetClientRect(window, &clientRect)

		deviceContext: win.HDC = win.BeginPaint(window, &paint)
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


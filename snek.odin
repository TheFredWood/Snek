package snek


import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import win "core:sys/windows"
import "core:time"

running: bool
shapeFinished: bool
nodes: [dynamic]Node
mouseIsDown: bool
bitmapHandle: win.HBITMAP
bitmapInfo: win.BITMAPINFO
bitmapDeviceContext: win.HDC
bitmapMemory: ^rawptr
bitmapWidth: u32
bitmapHeight: u32
bytesPerPixel: u8 = 4


windowX: u32
windowY: u32
windowWidth: u32
windowHeight: u32

current: f64 = 20.0
mu0: f64 = 4 * math.PI * 1e-7

Node :: struct {
	x:            f16,
	y:            f16,
	accountedFor: bool,
}
Vector :: struct {
	x: f64,
	y: f64,
}
CalculateResult :: proc() {
	integralSumme: f64 = 0
	for i := 0; i < len(nodes); i = i + 1 {
		node1 := nodes[i]
		node2 := nodes[(i + 1) % len(nodes)]
		ds := Vector{cast(f64)(node2.x - node1.x), cast(f64)(node2.y - node1.y)}
		mittelpunkt := Vector{cast(f64)(node1.x + node2.x) / 2, cast(f64)(node1.y + node2.y) / 2}
		r_quadrat: f64 =
			(cast(f64)mittelpunkt.x - 0.5) * (cast(f64)mittelpunkt.x - 0.5) +
			(cast(f64)mittelpunkt.y - 0.5) * (cast(f64)mittelpunkt.y - 0.5)
		b_feld := Vector {
			(mu0 * current / (2 * math.PI * r_quadrat)) * -(mittelpunkt.y - 0.5),
			(mu0 * current / (2 * math.PI * r_quadrat)) * (mittelpunkt.x - 0.5),
		}
		integralSumme = integralSumme + b_feld.x * ds.x + b_feld.y * ds.y
	}
	fmt.println(integralSumme)
}

CheckCollisionOnNodes :: proc(
	firstLineStart: Node,
	firstLineEnd: Node,
	secondLineStart: Node,
	secondLineEnd: Node,
) -> bool {
	//fmt.println("checking")
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
	//fmt.println("checked")
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
			//fmt.print("collided")
			//fmt.print(i)
			//fmt.print(" with ")
			//fmt.println(len(nodes))
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
RenderWindow :: proc() {

	//DrawRectangle(30, 30, 200, 200)
	//DrawHollowRectangle(100, 100, 500, 300, 20)
	windowX, windowY, windowWidth, windowHeight = DrawDynamicAreaCentered(0.8, 1, 0x00FFFFFF)
	for i: u32 = 1; i < 10; i = i + 1 {
		DrawRectangle(windowX + windowWidth / 10 * i, windowY, 1, windowHeight, 0x00888888)
	}
	for i: u32 = 1; i < 10; i = i + 1 {
		DrawRectangle(windowX, windowY + windowWidth / 10 * i, windowWidth, 1, 0x00888888)
	}
	for i := 0; i < len(nodes); i = i + 1 {
		node := nodes[i]
		if (i > 0) {
			lastNode := nodes[i - 1]
			DrawLine(
				cast(u32)(node.x * cast(f16)windowWidth) + windowX,
				cast(u32)(node.y * cast(f16)windowHeight) + windowY,
				cast(u32)(lastNode.x * cast(f16)windowWidth) + windowX,
				cast(u32)(lastNode.y * cast(f16)windowHeight) + windowY,
			)
		}
		DrawPixel(
			cast(u32)(node.x * cast(f16)windowWidth) + windowX,
			cast(u32)(node.y * cast(f16)windowHeight) + windowY,
			0x000000FF,
		)
	}
	DrawRectangle(
		windowX + (windowWidth - 5) / 2,
		windowY + (windowHeight - 5) / 2,
		5,
		5,
		0xFFF00FFF,
	)
	//DrawLine(100, 300, 100, 100)
	//DrawLine(100, 100, 300, 102)
	//DrawPixel(50, 50, 0x000000FF)
	//DrawPixel(300, 300, 0x000000FF)
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

RenderOtherWeirdGradient :: proc(blueOffset: u8, greenOffset: u8) {
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

RenderWeirdGradient :: proc(blueOffset: u8, greenOffset: u8) {
	width: u32 = bitmapWidth
	height: u32 = bitmapHeight

	pitch: u32 = width * u32(bytesPerPixel)
	row: ^u8 = cast(^u8)bitmapMemory

	for y: u32 = 0; y < bitmapHeight; y = y + 1 {
		pixel: ^u32 = cast(^u32)row
		for x: u32 = 0; x < bitmapWidth; x = x + 1 {
			blue: u8 = u8(x) + blueOffset
			green: u8 = u8(y) + greenOffset
			pixel^ = ((u32(green) << 8) | u32(blue))
			pixel = mem.ptr_offset(pixel, 1)
		}
		row = mem.ptr_offset(row, pitch)
	}


}

main :: proc() {
	fmt.println("Die Optimale Lösung ist mu0 * I, hier 1e-7 * 20 ~ 2,51e-5")
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

			xOffset: u8 = 0
			yOffset: u8 = 0

			running = true
			currentTime: time.Time = time.now()
			for running {
				message: win.MSG
				for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
					if (message.message == win.WM_QUIT) {
						running = false
					}
					win.TranslateMessage(&message)
					win.DispatchMessageW(&message)
				}
				if (time.duration_milliseconds(time.diff(currentTime, time.now())) > 16) {
					RenderOtherWeirdGradient(xOffset, yOffset)
					RenderWindow()
					currentTime = time.now()
					xOffset = xOffset + 1
					yOffset = yOffset + 2

				}
				deviceContext: win.HDC = win.GetDC(window)
				clientRect: win.RECT
				win.GetClientRect(window, &clientRect)
				windowWidth: i32 = clientRect.right - clientRect.left
				windowHeight: i32 = clientRect.bottom - clientRect.top
				Win32UpdateWindow(deviceContext, &clientRect, 0, 0, windowWidth, windowHeight)
				win.ReleaseDC(window, deviceContext)

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
	case win.WM_SIZE:
		clientRect: win.RECT
		win.GetClientRect(window, &clientRect)
		width := clientRect.right - clientRect.left
		height := clientRect.bottom - clientRect.top
		Win32ResizeDIBSection(u32(width), u32(height))
	case win.WM_CLOSE:
		running = false
	case win.WM_ACTIVATEAPP:
		win.OutputDebugStringA("WM_ACTIVATEAPP\n")
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
	case win.WM_LBUTTONUP:
		//fmt.println("Left Mouse Button up")
		mouseIsDown = false
		shapeFinished = true
		CalculateResult()
	case win.WM_LBUTTONDOWN:
		shapeFinished = false
		clear_dynamic_array(&nodes)
		mouseIsDown = true
	//fmt.println("Left Mouse Button down")
	//fmt.println(win.GET_X_LPARAM(lParam))
	//fmt.println(win.GET_Y_LPARAM(lParam))
	case win.WM_MOUSEMOVE:
		//fmt.println("Mouse move")
		if (mouseIsDown &&
			   !shapeFinished &&
			   cast(u32)win.GET_X_LPARAM(lParam) < windowX + windowWidth &&
			   cast(u32)win.GET_X_LPARAM(lParam) > windowX &&
			   cast(u32)win.GET_Y_LPARAM(lParam) < windowY + windowHeight &&
			   cast(u32)win.GET_Y_LPARAM(lParam) > windowY) {

			node: Node
			node.x =
				(cast(f16)(cast(u32)win.GET_X_LPARAM(lParam) - windowX)) / cast(f16)windowWidth
			node.y =
				(cast(f16)(cast(u32)win.GET_Y_LPARAM(lParam) - windowY)) / cast(f16)windowHeight
			node.accountedFor = false
			append(&nodes, node)
			if (false) {
				fmt.print("Neue Node: ")
				fmt.print(node.x)
				fmt.print(", ")
				fmt.println(node.y)

			}
		}

		if (!shapeFinished) {
			collides := CheckCollisionOnShape()
			if (collides) {
				fmt.println("finished")
				shapeFinished = true
			}
		} else {
			//fmt.println("finished")
		}
		if (shapeFinished) {
			//CalculateResult()
		}

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

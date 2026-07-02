import SwiftUI

@available(macOS 13.0, *)
struct ControllerVisualizer: View {
 @ObservedObject var viewModel: GameMacViewModel
 
 var body: some View {
 VStack(spacing: 10) {
 Text("HARDWARE VISUALIZER (60HZ THROTTLED)")
 .font(.system(size: 10, weight: .bold))
 .foregroundColor(.gray)
 .tracking(1.2)
 .frame(maxWidth: .infinity, alignment: .leading)
 
 ZStack {
 // Outer Card background
 RoundedRectangle(cornerRadius: 14)
 .fill(Color(white: 0.05))
 .overlay(
 RoundedRectangle(cornerRadius: 14)
 .stroke(Color.white.opacity(0.04), lineWidth: 1)
 )
 
 // Main Controller Container
 VStack(spacing: 16) {
 // Bumpers & Triggers row
 HStack(spacing: 120) {
 // Left trigger/bumper
 VStack(spacing: 4) {
 TriggerBar(value: viewModel.gamepadState.leftTrigger, isPressed: viewModel.gamepadState.leftTriggerButton, label: "LT")
 BumperBar(isPressed: viewModel.gamepadState.leftBumper, label: "LB")
 }
 
 // Right trigger/bumper
 VStack(spacing: 4) {
 TriggerBar(value: viewModel.gamepadState.rightTrigger, isPressed: viewModel.gamepadState.rightTriggerButton, label: "RT")
 BumperBar(isPressed: viewModel.gamepadState.rightBumper, label: "RB")
 }
 }
 .padding(.top, 14)
 
 // Face layout
 HStack(spacing: 40) {
 // Left side: LS & D-pad
 VStack(spacing: 16) {
 AnalogStickView(x: viewModel.gamepadState.leftStickX, y: viewModel.gamepadState.leftStickY, label: "LS")
 DpadView(up: viewModel.gamepadState.dpadUp, down: viewModel.gamepadState.dpadDown, left: viewModel.gamepadState.dpadLeft, right: viewModel.gamepadState.dpadRight)
 }
 
 // Center side: Select, Home, Start
 VStack(spacing: 12) {
 Spacer()
 HStack(spacing: 10) {
 CenterButton(isPressed: viewModel.gamepadState.select, icon: "chevron.left.square.fill", label: "Select")
 
 Circle()
 .fill(viewModel.gamepadState.home ? Color.green : Color.white.opacity(0.08))
 .frame(width: 22, height: 22)
 .overlay(
 Image(systemName: "g.circle.fill")
 .font(.system(size: 12, weight: .bold))
 .foregroundColor(viewModel.gamepadState.home ? .black : .white.opacity(0.4))
 )
 .shadow(color: viewModel.gamepadState.home ? .green.opacity(0.5) : .clear, radius: 4)
 
 CenterButton(isPressed: viewModel.gamepadState.start, icon: "chevron.right.square.fill", label: "Start")
 }
 Spacer()
 }
 .frame(width: 80)
 
 // Right side: Face buttons & RS
 VStack(spacing: 16) {
 FaceButtonsView(a: viewModel.gamepadState.buttonA, b: viewModel.gamepadState.buttonB, x: viewModel.gamepadState.buttonX, y: viewModel.gamepadState.buttonY)
 AnalogStickView(x: viewModel.gamepadState.rightStickX, y: viewModel.gamepadState.rightStickY, label: "RS")
 }
 }
 .padding(.bottom, 16)
 }
 }
 .frame(height: 250)
 }
 }
}

// Subview components for Visualizer
struct BumperBar: View {
 let isPressed: Bool
 let label: String
 
 var body: some View {
 Text(label)
 .font(.system(size: 9, weight: .bold))
 .foregroundColor(isPressed ? .black : .white.opacity(0.5))
 .frame(width: 60, height: 16)
 .background(
 RoundedRectangle(cornerRadius: 4)
 .fill(isPressed ? Color.purple : Color.white.opacity(0.08))
 )
 .shadow(color: isPressed ? .purple.opacity(0.5) : .clear, radius: 4)
 .animation(.easeInOut(duration: 0.1), value: isPressed)
 }
}

struct TriggerBar: View {
 let value: Double
 let isPressed: Bool
 let label: String
 
 var body: some View {
 VStack(spacing: 2) {
 ZStack(alignment: .bottom) {
 RoundedRectangle(cornerRadius: 3)
 .fill(Color.white.opacity(0.03))
 .frame(width: 50, height: 28)
 
 RoundedRectangle(cornerRadius: 3)
 .fill(
 LinearGradient(
 colors: [Color.purple.opacity(0.4), Color.purple],
 startPoint: .bottom,
 endPoint: .top
 )
 )
 .frame(width: 50, height: max(0, CGFloat(value) * 28))
 .shadow(color: isPressed ? .purple.opacity(0.6) : .clear, radius: 4)
 
 Text(String(format: "%d%%", Int(value * 100)))
 .font(.system(size: 7, weight: .bold, design: .monospaced))
 .foregroundColor(.white.opacity(0.7))
 .padding(.bottom, 2)
 }
 Text(label)
 .font(.system(size: 8, weight: .bold))
 .foregroundColor(.gray)
 }
 }
}

struct AnalogStickView: View {
 let x: Double
 let y: Double
 let label: String
 
 private let maxLimit: CGFloat = 12
 
 var body: some View {
 VStack(spacing: 2) {
 ZStack {
 Circle()
 .stroke(Color.white.opacity(0.08), lineWidth: 1)
 .background(Circle().fill(Color.white.opacity(0.01)))
 .frame(width: 48, height: 48)
 
 Circle()
 .fill(Color.white.opacity(0.15))
 .frame(width: 3, height: 3)
 
 Circle()
 .fill(
 RadialGradient(
 colors: [Color.white, Color.white.opacity(0.4)],
 center: .center,
 startRadius: 0,
 endRadius: 8
 )
 )
 .frame(width: 18, height: 18)
 .shadow(color: .cyan.opacity(x != 0 || y != 0 ? 0.5 : 0), radius: 4)
 .offset(x: CGFloat(x) * maxLimit, y: CGFloat(-y) * maxLimit)
 .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: x)
 .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: y)
 }
 Text(label)
 .font(.system(size: 8, weight: .bold))
 .foregroundColor(.gray)
 }
 }
}

struct DpadView: View {
 let up: Bool
 let down: Bool
 let left: Bool
 let right: Bool
 
 var body: some View {
 ZStack {
 RoundedRectangle(cornerRadius: 4)
 .fill(Color.white.opacity(0.04))
 .frame(width: 48, height: 16)
 RoundedRectangle(cornerRadius: 4)
 .fill(Color.white.opacity(0.04))
 .frame(width: 16, height: 48)
 
 VStack {
 Image(systemName: "triangle.fill")
 .font(.system(size: 7))
 .foregroundColor(up ? .cyan : .white.opacity(0.3))
 Spacer()
 Image(systemName: "triangle.fill")
 .font(.system(size: 7))
 .foregroundColor(down ? .cyan : .white.opacity(0.3))
 .rotationEffect(.degrees(180))
 }
 .frame(width: 16, height: 48)
 .padding(.vertical, 2)
 
 HStack {
 Image(systemName: "triangle.fill")
 .font(.system(size: 7))
 .foregroundColor(left ? .cyan : .white.opacity(0.3))
 .rotationEffect(.degrees(-90))
 Spacer()
 Image(systemName: "triangle.fill")
 .font(.system(size: 7))
 .foregroundColor(right ? .cyan : .white.opacity(0.3))
 .rotationEffect(.degrees(90))
 }
 .frame(width: 48, height: 16)
 .padding(.horizontal, 2)
 }
 }
}

struct CenterButton: View {
 let isPressed: Bool
 let icon: String
 let label: String
 
 var body: some View {
 VStack(spacing: 2) {
 Image(systemName: icon)
 .font(.system(size: 10))
 .foregroundColor(isPressed ? .white : .white.opacity(0.4))
 .padding(.horizontal, 6)
 .padding(.vertical, 3)
 .background(
 Capsule()
 .fill(isPressed ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
 )
 Text(label)
 .font(.system(size: 7, weight: .bold))
 .foregroundColor(.gray)
 }
 }
}

struct FaceButtonsView: View {
 let a: Bool
 let b: Bool
 let x: Bool
 let y: Bool
 
 var body: some View {
 ZStack {
 FaceButton(isPressed: y, label: "Y", color: .yellow)
 .offset(y: -16)
 FaceButton(isPressed: x, label: "X", color: .blue)
 .offset(x: -16)
 FaceButton(isPressed: b, label: "B", color: .red)
 .offset(x: 16)
 FaceButton(isPressed: a, label: "A", color: .green)
 .offset(y: 16)
 }
 .frame(width: 52, height: 52)
 }
}

struct FaceButton: View {
 let isPressed: Bool
 let label: String
 let color: Color
 
 var body: some View {
 Circle()
 .fill(isPressed ? color : Color.white.opacity(0.08))
 .frame(width: 15, height: 15)
 .overlay(
 Text(label)
 .font(.system(size: 8, weight: .bold, design: .rounded))
 .foregroundColor(isPressed ? .black : .white.opacity(0.6))
 )
 .shadow(color: isPressed ? color.opacity(0.6) : .clear, radius: 4)
 .animation(.easeInOut(duration: 0.08), value: isPressed)
 }
}


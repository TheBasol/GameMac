import SwiftUI

@available(macOS 13.0, *)
struct PermissionView: View {
 @ObservedObject var viewModel: GameMacViewModel
 
 var body: some View {
 VStack(spacing: 12) {
 Text("SYSTEM PERMISSIONS")
 .font(.system(size: 10, weight: .bold))
 .foregroundColor(.gray)
 .tracking(1.2)
 .frame(maxWidth: .infinity, alignment: .leading)
 
 VStack(alignment: .leading, spacing: 12) {
 Text("GameMac maps your controller events to system keyboard keystrokes and mouse movements. This requires macOS OS-level authorizations:")
 .font(.system(size: 11.5))
 .foregroundColor(.white.opacity(0.85))
 .lineSpacing(3)
 
 // Permission states
 VStack(spacing: 6) {
 PermissionRow(
 title: "Accessibility (Keystroke Injection)",
 isGranted: viewModel.hasAccessibilityPermission,
 action: { PermissionChecker.shared.openAccessibilitySettings() }
 )
 
 PermissionRow(
 title: "Input Monitoring (Controller Detection)",
 isGranted: viewModel.hasInputMonitoringPermission,
 action: { PermissionChecker.shared.openInputMonitoringSettings() }
 )
 }
 
 // Test injection block
 VStack(spacing: 6) {
 HStack {
 VStack(alignment: .leading, spacing: 1) {
 Text("Adaptive Verification")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.white)
 Text("Checks event injection status directly.")
 .font(.system(size: 9.5))
 .foregroundColor(.gray)
 }
 
 Spacer()
 
 Button(action: {
 viewModel.performTestInjection()
 }) {
 Text("Verify Injection")
 .font(.system(size: 10.5, weight: .bold))
 .foregroundColor(.cyan)
 .padding(.horizontal, 10)
 .padding(.vertical, 5)
 .background(Color.cyan.opacity(0.12))
 .cornerRadius(6)
 .overlay(
 RoundedRectangle(cornerRadius: 6)
 .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
 )
 }
 .buttonStyle(PlainButtonStyle())
 }
 
 HStack(spacing: 6) {
 Text("Diagnostics result:")
 .font(.system(size: 9.5, weight: .bold))
 .foregroundColor(.gray)
 
 Text(viewModel.testInjectionStatus)
 .font(.system(size: 9.5, weight: .bold, design: .monospaced))
 .foregroundColor(viewModel.testInjectionStatus == "Success" ? .green : (viewModel.testInjectionStatus == "Not Tested" ? .gray : .red))
 
 Spacer()
 }
 .padding(6)
 .background(Color.black.opacity(0.15))
 .cornerRadius(6)
 }
 
 // Workaround instructions
 VStack(alignment: .leading, spacing: 5) {
 HStack(spacing: 6) {
 Image(systemName: "exclamationmark.triangle.fill")
 .foregroundColor(.orange)
 .font(.system(size: 12))
 
 Text("macOS Signature Fix Workaround")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.orange)
 }
 
 Text("If permissions stop working after updating or recompiling the app, macOS caches are corrupted. Follow these exact steps to fix it:")
 .font(.system(size: 10))
 .foregroundColor(.white.opacity(0.8))
 
 VStack(alignment: .leading, spacing: 3) {
 Text("1. Open System Settings → Privacy & Security → Accessibility / Input Monitoring.")
 Text("2. Find GameMac in the list, highlight it, and click the minus (-) button to delete it completely.")
 Text("3. Drag and drop the GameMac application bundle back into the list.")
 }
 .font(.system(size: 9.5, weight: .bold))
 .foregroundColor(.white.opacity(0.85))
 .padding(.leading, 4)
 }
 .padding(10)
 .background(Color.orange.opacity(0.06))
 .cornerRadius(8)
 .overlay(
 RoundedRectangle(cornerRadius: 8)
 .stroke(Color.orange.opacity(0.15), lineWidth: 1)
 )
 }
 .padding(12)
 .background(Color.white.opacity(0.02))
 .cornerRadius(12)
 .overlay(
 RoundedRectangle(cornerRadius: 12)
 .stroke(Color.white.opacity(0.04), lineWidth: 1)
 )
 }
 .onAppear {
 viewModel.checkPermissions()
 }
 }
}

struct PermissionRow: View {
 let title: String
 let isGranted: Bool
 let action: () -> Void
 
 var body: some View {
 HStack {
 Image(systemName: isGranted ? "checkmark.seal.fill" : "xmark.shield.fill")
 .foregroundColor(isGranted ? .green : .red)
 .font(.system(size: 12))
 
 Text(title)
 .font(.system(size: 11, weight: .semibold))
 .foregroundColor(.white)
 
 Spacer()
 
 Button(action: action) {
 Text(isGranted ? "Granted" : "Grant...")
 .font(.system(size: 10, weight: .bold))
 .foregroundColor(isGranted ? .gray : .white)
 .padding(.horizontal, 8)
 .padding(.vertical, 4)
 .background(isGranted ? Color.white.opacity(0.04) : Color.blue)
 .cornerRadius(5)
 }
 .buttonStyle(PlainButtonStyle())
 .disabled(isGranted)
 }
 .padding(6)
 .background(Color.white.opacity(0.02))
 .cornerRadius(6)
 }
}

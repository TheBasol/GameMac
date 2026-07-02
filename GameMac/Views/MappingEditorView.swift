import SwiftUI
import AppKit

@available(macOS 13.0, *)
struct MappingEditorView: View {
 @ObservedObject var viewModel: GameMacViewModel
 @State private var listeningElementId: String? = nil
 @State private var keyMonitor: Any? = nil
 @State private var searchText = ""
 
 struct ControllerElement: Identifiable {
 let id: String
 let displayName: String
 let category: String
 }
 
 let controllerElements = [
 ControllerElement(id: "buttonA", displayName: "A Button", category: "Face Buttons"),
 ControllerElement(id: "buttonB", displayName: "B Button", category: "Face Buttons"),
 ControllerElement(id: "buttonX", displayName: "X Button", category: "Face Buttons"),
 ControllerElement(id: "buttonY", displayName: "Y Button", category: "Face Buttons"),
 
 ControllerElement(id: "leftBumper", displayName: "Left Bumper (LB)", category: "Bumpers & Triggers"),
 ControllerElement(id: "rightBumper", displayName: "Right Bumper (RB)", category: "Bumpers & Triggers"),
 ControllerElement(id: "leftTriggerButton", displayName: "Left Trigger (LT) Click", category: "Bumpers & Triggers"),
 ControllerElement(id: "rightTriggerButton", displayName: "Right Trigger (RT) Click", category: "Bumpers & Triggers"),
 
 ControllerElement(id: "dpadUp", displayName: "D-Pad Up", category: "D-Pad"),
 ControllerElement(id: "dpadDown", displayName: "D-Pad Down", category: "D-Pad"),
 ControllerElement(id: "dpadLeft", displayName: "D-Pad Left", category: "D-Pad"),
 ControllerElement(id: "dpadRight", displayName: "D-Pad Right", category: "D-Pad"),
 
 ControllerElement(id: "leftStickUp", displayName: "Left Stick Up", category: "Left Stick"),
 ControllerElement(id: "leftStickDown", displayName: "Left Stick Down", category: "Left Stick"),
 ControllerElement(id: "leftStickLeft", displayName: "Left Stick Left", category: "Left Stick"),
 ControllerElement(id: "leftStickRight", displayName: "Left Stick Right", category: "Left Stick"),
 
 ControllerElement(id: "rightStickUp", displayName: "Right Stick Up", category: "Right Stick"),
 ControllerElement(id: "rightStickDown", displayName: "Right Stick Down", category: "Right Stick"),
 ControllerElement(id: "rightStickLeft", displayName: "Right Stick Left", category: "Right Stick"),
 ControllerElement(id: "rightStickRight", displayName: "Right Stick Right", category: "Right Stick"),
 
 ControllerElement(id: "start", displayName: "Start Button", category: "System Buttons"),
 ControllerElement(id: "select", displayName: "Select Button", category: "System Buttons"),
 ControllerElement(id: "home", displayName: "Home/Logo Button", category: "System Buttons")
 ]
 
 var filteredElements: [ControllerElement] {
 if searchText.isEmpty {
 return controllerElements
 } else {
 return controllerElements.filter {
 $0.displayName.localizedCaseInsensitiveContains(searchText) ||
 $0.category.localizedCaseInsensitiveContains(searchText)
 }
 }
 }
 
 var validationWarnings: [String] {
 var warnings: [String] = []
 var reverseMapping: [UInt16: [String]] = [:]
 
 for (element, keyCode) in viewModel.activeProfile.buttonMapping {
 reverseMapping[keyCode, default: []].append(element)
 }
 
 for (keyCode, elements) in reverseMapping {
 if elements.count > 1 {
 let names = elements.map { displayName(for: $0) }.joined(separator: " & ")
 warnings.append("'\(KeyCodes.name(for: keyCode))' is mapped to multiple inputs (\(names))")
 }
 }
 
 return warnings
 }
 
 var body: some View {
 VStack(spacing: 12) {
 // Header with filter text box
 HStack {
 Text("MAPPINGS EDITOR")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.gray)
 .tracking(1.5)
 
 Spacer()
 
 HStack {
 Image(systemName: "magnifyingglass")
 .foregroundColor(.gray)
 .font(.system(size: 11))
 TextField("Filter controls...", text: $searchText)
 .textFieldStyle(PlainTextFieldStyle())
 .font(.system(size: 11))
 .foregroundColor(.white)
 if !searchText.isEmpty {
 Button(action: { searchText = "" }) {
 Image(systemName: "xmark.circle.fill")
 .foregroundColor(.gray)
 }
 .buttonStyle(PlainButtonStyle())
 }
 }
 .padding(.horizontal, 8)
 .padding(.vertical, 4)
 .background(Color.white.opacity(0.05))
 .cornerRadius(6)
 .frame(width: 180)
 }
 
 // Diagnostics checklist
 let warnings = validationWarnings
 if let bindingMessage = viewModel.lastHardwareBindingMessage {
 VStack(alignment: .leading, spacing: 4) {
 HStack(alignment: .top, spacing: 6) {
 Image(systemName: "checkmark.circle.fill")
 .foregroundColor(.green)
 .font(.system(size: 12))
 Text(bindingMessage)
 .font(.system(size: 10, weight: .medium, design: .monospaced))
 .foregroundColor(.white.opacity(0.9))
 }
 }
 .padding(10)
 .background(Color.green.opacity(0.08))
 .cornerRadius(8)
 .overlay(
 RoundedRectangle(cornerRadius: 8)
 .stroke(Color.green.opacity(0.2), lineWidth: 1)
 )
 }
 if !warnings.isEmpty {
 VStack(alignment: .leading, spacing: 4) {
 HStack(alignment: .top, spacing: 6) {
 Image(systemName: "exclamationmark.triangle.fill")
 .foregroundColor(.yellow)
 .font(.system(size: 12))
 
 VStack(alignment: .leading, spacing: 2) {
 Text("Validation Warnings")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.yellow)
 
 ForEach(warnings, id: \.self) { warning in
 Text("• \(warning)")
 .font(.system(size: 10))
 .foregroundColor(.white.opacity(0.8))
 }
 }
 }
 }
 .padding(10)
 .background(Color.yellow.opacity(0.08))
 .cornerRadius(8)
 .overlay(
 RoundedRectangle(cornerRadius: 8)
 .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
 )
 }
 
 // List of Mappings
 ScrollView {
 VStack(spacing: 8) {
 let grouped = Dictionary(grouping: filteredElements, by: { $0.category })
 let categories = ["Face Buttons", "Bumpers & Triggers", "D-Pad", "Left Stick", "Right Stick", "System Buttons"]
 
 ForEach(categories.filter { grouped[$0] != nil }, id: \.self) { category in
 VStack(alignment: .leading, spacing: 4) {
 Text(category.uppercased())
 .font(.system(size: 9, weight: .bold))
 .foregroundColor(.gray)
 .padding(.horizontal, 4)
 .padding(.top, 6)
 
 ForEach(grouped[category] ?? []) { element in
 mappingRow(for: element)
 }
 }
 }
 }
 }
 }
 .onDisappear {
 stopListening()
 }
 }
 
 private func mappingRow(for element: ControllerElement) -> some View {
      let isKeyboardListening = listeningElementId == element.id
      let isGamepadListening = viewModel.bindingGamepadElementId == element.id
      let isAnyListening = isKeyboardListening || isGamepadListening
      let mappedCode = viewModel.activeProfile.buttonMapping[element.id]
      let hardwareKey = hardwareBindingLabel(for: element.id)
      
      return HStack {
          VStack(alignment: .leading, spacing: 2) {
              Text(element.displayName)
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(.white)
              if let hwKey = hardwareKey {
                  Text("HW: \(hwKey)")
                      .font(.system(size: 8, weight: .bold, design: .monospaced))
                      .foregroundColor(.green.opacity(0.85))
              }
          }
          
          Spacer()
          
          HStack(spacing: 6) {
              if isKeyboardListening {
                  Text("PRESS ANY KEY...")
                      .font(.system(size: 10, weight: .bold, design: .rounded))
                      .foregroundColor(.cyan)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Capsule().fill(Color.cyan.opacity(0.12)))
                      .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1))
              } else if isGamepadListening {
                  Text("PRESS GAMEPAD BUTTON...")
                      .font(.system(size: 10, weight: .bold, design: .rounded))
                      .foregroundColor(.green)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Capsule().fill(Color.green.opacity(0.12)))
                      .overlay(Capsule().strokeBorder(Color.green.opacity(0.5), lineWidth: 1))
              } else if let code = mappedCode {
                  Text(KeyCodes.name(for: code))
                      .font(.system(size: 10, weight: .bold, design: .rounded))
                      .foregroundColor(.white)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Capsule().fill(LinearGradient(colors: [Color.purple.opacity(0.7), Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
              } else {
                  Text("NO KEY")
                      .font(.system(size: 9, weight: .regular))
                      .foregroundColor(.gray)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Capsule().fill(Color.white.opacity(0.03)))
              }
              
              // Keyboard recording trigger
              Button(action: {
                  if isKeyboardListening {
                      stopListening()
                  } else {
                      // Cancel gamepad listen if active
                      viewModel.bindingGamepadElementId = nil
                      startListening(for: element.id)
                  }
              }) {
                  Image(systemName: isKeyboardListening ? "xmark" : "keyboard")
                      .font(.system(size: 10))
                      .foregroundColor(isKeyboardListening ? .red : .gray)
                      .frame(width: 22, height: 22)
                      .background(Color.white.opacity(0.06))
                      .clipShape(Circle())
              }
              .buttonStyle(PlainButtonStyle())
              .disabled(isGamepadListening)
              
              // Gamepad physical button recording trigger
              Button(action: {
                  if isGamepadListening {
                      viewModel.bindingGamepadElementId = nil
                  } else {
                      // Cancel keyboard listen if active
                      stopListening()
                      viewModel.bindingGamepadElementId = element.id
                  }
              }) {
                  Image(systemName: isGamepadListening ? "xmark" : "gamecontroller")
                      .font(.system(size: 10))
                      .foregroundColor(isGamepadListening ? .red : .gray)
                      .frame(width: 22, height: 22)
                      .background(Color.white.opacity(0.06))
                      .clipShape(Circle())
              }
              .buttonStyle(PlainButtonStyle())
              .disabled(isKeyboardListening)
              
              // Action Menu
              Menu {
                  Button(action: { viewModel.updateMapping(for: element.id, to: 1000) }) {
                      Label("Left Mouse Click", systemImage: "mouse")
                  }
                  Button(action: { viewModel.updateMapping(for: element.id, to: 1001) }) {
                      Label("Right Mouse Click", systemImage: "mouse")
                  }
                  Button(action: { viewModel.updateMapping(for: element.id, to: 1002) }) {
                      Label("Middle Mouse Click", systemImage: "mouse")
                  }
                  if mappedCode != nil {
                      Divider()
                      Button(role: .destructive, action: { viewModel.updateMapping(for: element.id, to: nil) }) {
                          Label("Unmap", systemImage: "trash")
                      }
                  }
              } label: {
                  Image(systemName: "ellipsis")
                      .font(.system(size: 10))
                      .foregroundColor(.gray)
                      .frame(width: 22, height: 22)
                      .background(Color.white.opacity(0.06))
                      .clipShape(Circle())
              }
              .menuStyle(BorderlessButtonMenuStyle())
              .frame(width: 22, height: 22)
          }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
          RoundedRectangle(cornerRadius: 8)
              .fill(isAnyListening ? Color.cyan.opacity(0.03) : Color.white.opacity(0.01))
      )
  }
 
 private func startListening(for elementId: String) {
 listeningElementId = elementId
 if let monitor = keyMonitor {
 NSEvent.removeMonitor(monitor)
 keyMonitor = nil
 }
 
 keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
 viewModel.updateMapping(for: elementId, to: event.keyCode)
 stopListening()
 return nil
 }
 }
 
 private func stopListening() {
 listeningElementId = nil
 if let monitor = keyMonitor {
 NSEvent.removeMonitor(monitor)
 keyMonitor = nil
 }
 }
 
 private func displayName(for id: String) -> String {
 controllerElements.first(where: { $0.id == id })?.displayName ?? id
 }
 
 private func hardwareBindingLabel(for elementId: String) -> String? {
 guard let layout = viewModel.activeControllerLayout else { return nil }
 
 if let buttonKey = layout.buttonMap.first(where: { $0.value == elementId })?.key {
 return HIDInputParser.formatElementKey(buttonKey)
 }
 
 let axisName: String?
 switch elementId {
 case "leftTriggerButton": axisName = "leftTrigger"
 case "rightTriggerButton": axisName = "rightTrigger"
 default: axisName = nil
 }
 
 if let axisName = axisName,
 let axisKey = layout.axisMap.first(where: { $0.value == axisName })?.key {
 return "axis \(HIDInputParser.formatAxisKey(axisKey))"
 }
 
 return nil
 }
}


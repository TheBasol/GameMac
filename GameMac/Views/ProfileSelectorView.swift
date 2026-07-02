import SwiftUI

@available(macOS 13.0, *)
struct ProfileSelectorView: View {
 @ObservedObject var viewModel: GameMacViewModel
 @State private var showingCreateAlert = false
 @State private var newProfileName = ""
 
 var body: some View {
 VStack(spacing: 8) {
 Text("PROFILES MANAGER")
 .font(.system(size: 10, weight: .bold))
 .foregroundColor(.gray)
 .tracking(1.2)
 .frame(maxWidth: .infinity, alignment: .leading)
 
 HStack(spacing: 8) {
 // Dropdown menu showing all profiles
 Menu {
 ForEach(viewModel.profiles, id: \.profileName) { profile in
 Button(action: {
 withAnimation {
 viewModel.selectProfile(profile)
 }
 }) {
 HStack {
 Text(profile.profileName)
 if profile.profileName == viewModel.activeProfile.profileName {
 Image(systemName: "checkmark")
 }
 }
 }
 }
 } label: {
 HStack {
 Image(systemName: "doc.plaintext.fill")
 .foregroundColor(.purple)
 .font(.system(size: 11))
 
 Text(viewModel.activeProfile.profileName)
 .font(.system(size: 12, weight: .bold))
 .foregroundColor(.white)
 
 Spacer()
 
 Image(systemName: "chevron.up.chevron.down")
 .font(.system(size: 9))
 .foregroundColor(.gray)
 }
 .padding(.horizontal, 10)
 .padding(.vertical, 7)
 .background(Color.white.opacity(0.05))
 .cornerRadius(8)
 }
 .menuStyle(BorderlessButtonMenuStyle())
 
 // Duplicate button
 Button(action: {
 viewModel.duplicateProfile(viewModel.activeProfile)
 }) {
 Image(systemName: "plus.square.on.square")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.white.opacity(0.8))
 .frame(width: 28, height: 28)
 .background(Color.white.opacity(0.05))
 .cornerRadius(8)
 }
 .buttonStyle(PlainButtonStyle())
 .help("Duplicate Active Profile")
 
 // Delete button
 Button(action: {
 viewModel.deleteProfile(viewModel.activeProfile)
 }) {
 Image(systemName: "trash")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(viewModel.profiles.count > 1 ? .red : .gray.opacity(0.3))
 .frame(width: 28, height: 28)
 .background(Color.white.opacity(0.05))
 .cornerRadius(8)
 }
 .buttonStyle(PlainButtonStyle())
 .disabled(viewModel.profiles.count <= 1)
 .help("Delete Active Profile")
 
 // Create Button
 Button(action: {
 newProfileName = ""
 showingCreateAlert = true
 }) {
 Image(systemName: "plus")
 .font(.system(size: 11, weight: .bold))
 .foregroundColor(.black)
 .frame(width: 28, height: 28)
 .background(Color.cyan)
 .cornerRadius(8)
 }
 .buttonStyle(PlainButtonStyle())
 .help("Create New Profile")
 }
 }
 .sheet(isPresented: $showingCreateAlert) {
 VStack(spacing: 16) {
 Text("Create New Profile")
 .font(.system(size: 13, weight: .bold))
 .foregroundColor(.white)
 
 TextField("Profile name...", text: $newProfileName)
 .textFieldStyle(RoundedBorderTextFieldStyle())
 .frame(width: 200)
 
 HStack(spacing: 10) {
 Button("Cancel") {
 showingCreateAlert = false
 }
 .buttonStyle(BorderedButtonStyle())
 
 Button("Create") {
 let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
 if !name.isEmpty {
 viewModel.createProfile(name: name)
 showingCreateAlert = false
 }
 }
 .buttonStyle(BorderedProminentButtonStyle())
 .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
 }
 }
 .padding(18)
 .frame(width: 260, height: 130)
 .background(Color(white: 0.1))
 }
 }
}

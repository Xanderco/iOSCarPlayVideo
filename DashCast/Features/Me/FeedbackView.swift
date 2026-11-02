import SwiftUI

public struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messageText: String = ""
    @State private var contactInfo: String = ""
    @State private var showingSuccessAlert: Bool = false
    @State private var showingInfoAlert: Bool = false

    public init() {}

    private var isMessageValid: Bool {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tell us what's wrong")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text("Bugs, missing widgets, sound requests — we read every message.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                        .padding(.top, 10)

                        // Message Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text("Your message")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Text("*")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.dashRed)
                            }

                            ZStack(alignment: .topLeading) {
                                if messageText.isEmpty {
                                    Text("Describe what happened, and what you expected.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.dashTextMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                }

                                TextEditor(text: $messageText)
                                    .font(.system(size: 14))
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .padding(10)
                                    .frame(minHeight: 120)
                            }
                            .background(Color.dashSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dashBorder, lineWidth: 1))

                            Text("At least 10 characters (\(min(messageText.count, 10))/10)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isMessageValid ? Color.dashGreen : Color.dashOrange)
                        }

                        // Contact Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text("How to reach you")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Text("*")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.dashRed)
                            }

                            TextField("Email or phone number", text: $contactInfo)
                                .font(.system(size: 14))
                                .padding(14)
                                .background(Color.dashSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dashBorder, lineWidth: 1))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        // Screenshots Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Screenshots")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Spacer()
                                Text("0/9")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dashTextMuted)
                            }

                            Button {} label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.dashYellow)
                                    Text("Add")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.dashYellow)
                                }
                                .frame(width: 72, height: 72)
                                .background(Color.dashSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.dashYellow.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                )
                            }
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                }

                // Sticky Send Feedback Button
                Button {
                    showingSuccessAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Send Feedback")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isMessageValid ? LinearGradient.dashAccentGradient : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                    .clipShape(Capsule())
                    .shadow(color: isMessageValid ? Color.dashYellow.opacity(0.35) : Color.clear, radius: 10, y: 4)
                }
                .disabled(!isMessageValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.dashYellow)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfoAlert = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
            .alert("Feedback Sent", isPresented: $showingSuccessAlert) {
                Button("Done", role: .cancel) { dismiss() }
            } message: {
                Text("Thank you! Your feedback helps us improve DashCast.")
            }
            .alert("Feedback Policy", isPresented: $showingInfoAlert) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("We never collect telemetry without consent. Diagnostics sent with feedback are strictly anonymous.")
            }
        }
    }
}

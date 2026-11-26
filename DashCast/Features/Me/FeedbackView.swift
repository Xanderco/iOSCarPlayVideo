import SwiftUI

/// Pure validation helpers for `FeedbackView`.
public enum FeedbackFormValidator {
    nonisolated public static let minimumMessageLength: Int = 10

    nonisolated public static func trimmedLength(_ message: String) -> Int {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    nonisolated public static func isMessageValid(_ message: String) -> Bool {
        trimmedLength(message) >= minimumMessageLength
    }

    nonisolated public static func clampedCharacterCount(_ message: String) -> Int {
        min(message.count, minimumMessageLength)
    }
}

/// Localized copy keys for `FeedbackView`.
public enum FeedbackCopy {
    nonisolated public static let headerTitleString = "Tell us what's wrong"
    nonisolated public static let headerSubtitleString = "Bugs, missing widgets, sound requests — we read every message."
    nonisolated public static let yourMessageString = "Your message"
    nonisolated public static let messagePlaceholderString = "Describe what happened, and what you expected."
    nonisolated public static let minimumCharactersFormatString = "At least 10 characters (%lld/10)"
    nonisolated public static let contactHeaderString = "How to reach you"
    nonisolated public static let contactPlaceholderString = "Email or phone number"
    nonisolated public static let screenshotsHeaderString = "Screenshots"
    nonisolated public static let screenshotsCountZeroString = "0/9"
    nonisolated public static let addString = "Add"
    nonisolated public static let sendFeedbackString = "Send Feedback"
    nonisolated public static let navigationTitleString = "Feedback"
    nonisolated public static let cancelString = "Cancel"
    nonisolated public static let feedbackSentTitleString = "Feedback Sent"
    nonisolated public static let doneString = "Done"
    nonisolated public static let feedbackSentMessageString = "Thank you! Your feedback helps us improve DashCast."
    nonisolated public static let feedbackPolicyTitleString = "Feedback Policy"
    nonisolated public static let gotItString = "Got it"
    nonisolated public static let feedbackPolicyMessageString = "We never collect telemetry without consent. Diagnostics sent with feedback are strictly anonymous."

    nonisolated public static let allLocalizationKeys: [String] = [
        headerTitleString,
        headerSubtitleString,
        yourMessageString,
        messagePlaceholderString,
        minimumCharactersFormatString,
        contactHeaderString,
        contactPlaceholderString,
        screenshotsHeaderString,
        screenshotsCountZeroString,
        addString,
        sendFeedbackString,
        navigationTitleString,
        cancelString,
        feedbackSentTitleString,
        doneString,
        feedbackSentMessageString,
        feedbackPolicyTitleString,
        gotItString,
        feedbackPolicyMessageString
    ]

    @MainActor public static var headerTitleKey: LocalizedStringKey { LocalizedStringKey(headerTitleString) }
    @MainActor public static var headerSubtitleKey: LocalizedStringKey { LocalizedStringKey(headerSubtitleString) }
    @MainActor public static var yourMessageKey: LocalizedStringKey { LocalizedStringKey(yourMessageString) }
    @MainActor public static var messagePlaceholderKey: LocalizedStringKey { LocalizedStringKey(messagePlaceholderString) }
    @MainActor public static var contactHeaderKey: LocalizedStringKey { LocalizedStringKey(contactHeaderString) }
    @MainActor public static var contactPlaceholderKey: LocalizedStringKey { LocalizedStringKey(contactPlaceholderString) }
    @MainActor public static var screenshotsHeaderKey: LocalizedStringKey { LocalizedStringKey(screenshotsHeaderString) }
    @MainActor public static var screenshotsCountZeroKey: LocalizedStringKey { LocalizedStringKey(screenshotsCountZeroString) }
    @MainActor public static var addKey: LocalizedStringKey { LocalizedStringKey(addString) }
    @MainActor public static var sendFeedbackKey: LocalizedStringKey { LocalizedStringKey(sendFeedbackString) }
    @MainActor public static var navigationTitleKey: LocalizedStringKey { LocalizedStringKey(navigationTitleString) }
    @MainActor public static var cancelKey: LocalizedStringKey { LocalizedStringKey(cancelString) }
    @MainActor public static var feedbackSentTitleKey: LocalizedStringKey { LocalizedStringKey(feedbackSentTitleString) }
    @MainActor public static var doneKey: LocalizedStringKey { LocalizedStringKey(doneString) }
    @MainActor public static var feedbackSentMessageKey: LocalizedStringKey { LocalizedStringKey(feedbackSentMessageString) }
    @MainActor public static var feedbackPolicyTitleKey: LocalizedStringKey { LocalizedStringKey(feedbackPolicyTitleString) }
    @MainActor public static var gotItKey: LocalizedStringKey { LocalizedStringKey(gotItString) }
    @MainActor public static var feedbackPolicyMessageKey: LocalizedStringKey { LocalizedStringKey(feedbackPolicyMessageString) }

    @MainActor
    public static func minimumCharactersKey(clampedCount: Int) -> LocalizedStringKey {
        LocalizedStringKey("At least 10 characters (\(clampedCount)/10)")
    }
}

public struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messageText: String = ""
    @State private var contactInfo: String = ""
    @State private var showingSuccessAlert: Bool = false
    @State private var showingInfoAlert: Bool = false

    public init() {}

    private var isMessageValid: Bool {
        FeedbackFormValidator.isMessageValid(messageText)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.dashBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(FeedbackCopy.headerTitleKey)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Color.dashTextPrimary)

                            Text(FeedbackCopy.headerSubtitleKey)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                        .padding(.top, 10)

                        // Message Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text(FeedbackCopy.yourMessageKey)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Text("*")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.dashRed)
                            }

                            ZStack(alignment: .topLeading) {
                                if messageText.isEmpty {
                                    Text(FeedbackCopy.messagePlaceholderKey)
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

                            Text(FeedbackCopy.minimumCharactersKey(clampedCount: FeedbackFormValidator.clampedCharacterCount(messageText)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isMessageValid ? Color.dashGreen : Color.dashOrange)
                        }

                        // Contact Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text(FeedbackCopy.contactHeaderKey)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Text("*")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.dashRed)
                            }

                            TextField(FeedbackCopy.contactPlaceholderKey, text: $contactInfo)
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
                                Text(FeedbackCopy.screenshotsHeaderKey)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.dashTextPrimary)
                                Spacer()
                                Text(FeedbackCopy.screenshotsCountZeroKey)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dashTextMuted)
                            }

                            Button {} label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.dashYellow)
                                    Text(FeedbackCopy.addKey)
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
                        Text(FeedbackCopy.sendFeedbackKey)
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
            .navigationTitle(FeedbackCopy.navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(FeedbackCopy.cancelKey) { dismiss() }
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
            .alert(FeedbackCopy.feedbackSentTitleKey, isPresented: $showingSuccessAlert) {
                Button(FeedbackCopy.doneKey, role: .cancel) { dismiss() }
            } message: {
                Text(FeedbackCopy.feedbackSentMessageKey)
            }
            .alert(FeedbackCopy.feedbackPolicyTitleKey, isPresented: $showingInfoAlert) {
                Button(FeedbackCopy.gotItKey, role: .cancel) {}
            } message: {
                Text(FeedbackCopy.feedbackPolicyMessageKey)
            }
        }
    }
}

import Foundation
import PhotosUI
import SwiftUI

@MainActor
public final class LocalVideoManager: ObservableObject {
    public static let shared = LocalVideoManager()

    @Published public private(set) var localVideos: [ChannelModel] = []

    public init() {
        loadSavedLocalVideos()
    }

    public func importVideo(from item: PhotosPickerItem) async {
        do {
            guard let movie = try await item.loadTransferable(type: MovieFileTransferable.self) else {
                return
            }

            let fileName = "video_\(UUID().uuidString).mp4"
            let destinationURL = getDocumentsDirectory().appendingPathComponent(fileName)

            try FileManager.default.copyItem(at: movie.url, to: destinationURL)

            let channel = ChannelModel(
                name: "Local Video \(localVideos.count + 1)",
                streamURL: destinationURL,
                groupTitle: "Local Videos"
            )

            localVideos.append(channel)
            saveLocalVideos()
        } catch {
            print("Failed to import video: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveLocalVideos() {
        if let data = try? JSONEncoder().encode(localVideos) {
            UserDefaults.standard.set(data, forKey: "dashcast_local_imported_videos")
        }
    }

    private func loadSavedLocalVideos() {
        if let data = UserDefaults.standard.data(forKey: "dashcast_local_imported_videos"),
           let videos = try? JSONDecoder().decode([ChannelModel].self, from: data) {
            self.localVideos = videos
        }
    }
}

public struct MovieFileTransferable: Transferable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieFileTransferable(url: copy)
        }
    }
}

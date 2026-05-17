import Foundation
import UIKit

// MARK: - Image uploader
//
// Single-shot PUT of a JPEG/PNG to a backend-issued presigned S3 URL.
// Used by the avatar picker and the create-post sheet — both upload a
// small image (a few hundred KB after compression) so the multipart
// pipeline used by reels would be overkill.
//
// Flow (avatar example):
//   1. UI grabs a `UIImage` from PhotosPicker or Camera.
//   2. ImageUploader.uploadAvatar(image:) presigns + PUTs + PATCHes the
//      worker record with the resulting public URL.
//   3. Caller refreshes the profile so the new avatar surfaces.

enum ImageUploadError: LocalizedError {
    case encodingFailed
    case noResponse
    case uploadFailed(status: Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:        return "Couldn't prepare the image for upload."
        case .noResponse:            return "No response from the image upload."
        case .uploadFailed(let s):   return "Image upload failed (HTTP \(s))."
        }
    }
}

@MainActor
enum ImageUploader {

    /// Resize-and-JPEG-compress a `UIImage` for upload. Aims at a target
    /// long-edge of ``maxEdge`` (avatar 1024, post image 1600 by default)
    /// and a JPEG quality of 0.82 — a good balance for Tier-3 networks.
    static func encodeJPEG(_ image: UIImage, maxEdge: CGFloat = 1024, quality: CGFloat = 0.82) -> Data? {
        let scaled = resize(image, maxEdge: maxEdge)
        return scaled.jpegData(compressionQuality: quality)
    }

    /// Upload an already-encoded image to the given presigned URL.
    /// Returns once the PUT succeeds. Throws ``ImageUploadError`` on any
    /// non-2xx response.
    static func putJPEG(
        data: Data, to presignedURL: String, contentType: String = "image/jpeg",
    ) async throws {
        guard let url = URL(string: presignedURL) else {
            throw ImageUploadError.noResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        let (_, response) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw ImageUploadError.noResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageUploadError.uploadFailed(status: http.statusCode)
        }
    }

    /// End-to-end avatar upload: presign → PUT → patch the worker row
    /// with the new ``avatar_url``. Returns the public URL on success so
    /// the caller can update its in-memory worker model.
    @discardableResult
    static func uploadAvatar(_ image: UIImage,
                             service: WorkerService = .shared) async throws -> String {
        guard let data = encodeJPEG(image, maxEdge: 1024, quality: 0.85) else {
            throw ImageUploadError.encodingFailed
        }
        let presigned = try await service.requestAvatarUploadURL(contentType: "image/jpeg")
        try await putJPEG(data: data, to: presigned.uploadURL, contentType: presigned.contentType)
        _ = try await service.updateSelf(WorkerUpdateRequest(avatarURL: presigned.publicURL))
        return presigned.publicURL
    }

    /// Presign + PUT a post image. Returns the resulting public URL so
    /// the caller can attach it to ``WorkerService.createPost``.
    static func uploadPostImage(_ image: UIImage,
                                service: WorkerService = .shared) async throws -> String {
        guard let data = encodeJPEG(image, maxEdge: 1600, quality: 0.82) else {
            throw ImageUploadError.encodingFailed
        }
        let presigned = try await service.requestPostImageUploadURL(contentType: "image/jpeg")
        try await putJPEG(data: data, to: presigned.uploadURL, contentType: presigned.contentType)
        return presigned.publicURL
    }

    // MARK: - Image resize

    private static func resize(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // we want pixels, not points
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

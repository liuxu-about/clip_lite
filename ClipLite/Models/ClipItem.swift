import Foundation

struct ClipItem: Identifiable, Equatable {
    let id: UUID
    let type: ClipType
    let createdAt: Date
    let hashValue: String

    let textContent: String?
    let textPreview: String

    let imagePath: String?
    let thumbnailPath: String?
    let fileSize: Int64?
    let imageWidth: Int?
    let imageHeight: Int?

    init(
        id: UUID = UUID(),
        type: ClipType,
        createdAt: Date = Date(),
        hashValue: String,
        textContent: String?,
        textPreview: String,
        imagePath: String? = nil,
        thumbnailPath: String? = nil,
        fileSize: Int64? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.hashValue = hashValue
        self.textContent = textContent
        self.textPreview = textPreview
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.fileSize = fileSize
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

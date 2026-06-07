import SwiftUI

public struct TourPage: Identifiable {
    public let id = UUID()
    public let imageName: String
    public let imageBundle: Bundle?
    public let title: LocalizedStringKey
    public let description: LocalizedStringKey
    public let tableName: String?
    public let stringsBundle: Bundle?

    public init(
        imageName: String,
        imageBundle: Bundle? = nil,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        tableName: String? = nil,
        stringsBundle: Bundle? = nil
    ) {
        self.imageName = imageName
        self.imageBundle = imageBundle
        self.title = title
        self.description = description
        self.tableName = tableName
        self.stringsBundle = stringsBundle
    }
}

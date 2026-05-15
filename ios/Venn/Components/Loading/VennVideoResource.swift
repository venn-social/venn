import Foundation

/// Bundle-backed video resource used by branded loading surfaces.
struct VennVideoResource: Equatable {
    let name: String
    var fileExtension = "mp4"
    var subdirectory = "Videos"

    var url: URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension)
    }
}

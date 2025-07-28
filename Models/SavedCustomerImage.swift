import Foundation

struct SavedCustomerImage: Identifiable {
    let id: Int
    let customerName: String
    let imagePath: String
    let date: Date
    let uploadedBy: String
}
import Foundation

extension Array {
    func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        self.sorted { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}

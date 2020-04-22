/// A Swift object that can be accessed from HyperTalk.
class HyperTalkObject: Equatable {
    let id: Int
    
    internal init(id: Int) {
        self.id = id
    }

    static func == (lhs: HyperTalkObject, rhs: HyperTalkObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hyperTalkPropertyValue(_ name: String) throws -> Variant {
        if name == "id" {
            return Variant(id)
        } else {
            throw RuntimeError.unknownProperty(name)
        }
    }
    
    func setHyperTalkProperty(_ name: String, to value: Variant) throws {
        if name == "id" {
            throw RuntimeError.cantChangeReadOnlyProperty(name)
        } else {
            throw RuntimeError.unknownProperty(name)
        }
    }
}

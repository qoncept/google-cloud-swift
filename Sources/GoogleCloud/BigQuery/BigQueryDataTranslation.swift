import Foundation

enum BigQueryDataTranslation {
    static func encode(_ query: BigQueryQueryString) -> (query: String, parameters: [BigQueryQueryRequest.QueryParameter]) {
        var rawQuery: String = ""
        var parameters: [BigQueryQueryRequest.QueryParameter] = []
        for fragment in query.fragments {
            switch fragment {
            case .raw(let string):
                rawQuery.append(string)
            case .parameter(let param):
                let paramName = "p\(parameters.count)"
                rawQuery.append("@\(paramName)")
                parameters.append(.init(
                    name: paramName,
                    parameterType: .init(type: type(of: param).parameterDataType.rawValue),
                    parameterValue: .init(value: param.parameterDataValue())
                ))
            }
        }

        return (rawQuery, parameters)
    }

    static func decode<D: Decodable>(_ type: D.Type, dataType: BigQueryDataType, dataValue: String, codingPath: [any CodingKey]) throws -> D {
        if let fastPathType = type as? any BigQueryDecodable.Type {
            return try fastPathType.init(dataType: dataType, dataValue: dataValue) as! D
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            do {
                return try decoder.decode(type, from: Data(dataValue.utf8))
            } catch {
                do {
                    return try decoder.decode(type, from: Data("\"\(dataValue)\"".utf8))
                } catch {
                    throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "\"\(dataValue)\" cannot decode to \(type)"))
                }
            }
        }
    }
}

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
                    parameterType: .init(type: type(of: param).parameterDataType),
                    parameterValue: .init(value: param.parameterDataValue())
                ))
            }
        }

        return (rawQuery, parameters)
    }

    static func decode<D: Decodable>(_ type: D.Type, dataType: String, dataValue: String) throws -> D {
        if let fastPathType = type as? any BigQueryDecodable.Type {
            return try fastPathType.init(dataType: dataType, dataValue: dataValue) as! D
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            var value = dataValue
            do {
                return try decoder.decode(type, from: Data(value.utf8))
            } catch {
                value = "\"\(value)\""
                return try decoder.decode(type, from: Data(value.utf8))
            }
        }
    }
}

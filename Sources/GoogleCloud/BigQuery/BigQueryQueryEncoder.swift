enum BigQueryQueryEncoder {
    static func encode(_ query: BigQueryQueryString) -> BigQueryQueryRequest {
        var rawQuery: String = ""
        var parameters: [BigQueryQueryRequest.QueryParameter] = []
        for fragment in query.fragments {
            switch fragment {
            case .raw(let string):
                rawQuery.append(string)
            case .parameter(let param):
                let paramName = "_\(parameters.count)"
                rawQuery.append("@\(paramName)")
                parameters.append(.init(
                    name: paramName,
                    parameterType: .init(type: type(of: param).parameterDataType),
                    parameterValue: .init(value: param.parameterDataValue())
                ))
            }
        }

        return .init(
            query: rawQuery,
            queryParameters: parameters
        )
    }
}

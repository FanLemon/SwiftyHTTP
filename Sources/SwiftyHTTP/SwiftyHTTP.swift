import Foundation



protocol HTTPSession {
    
    var urlSession: URLSession { get }
    
    var baseURLString: String { get }
}


enum HTTPMethod: String {
    
    case GET = "GET"
    
    case POST = "POST"
    
    case PUT = "PUT"
    
    case PATCH = "PATCH"
    
    case DELETE = "DELETE"
}


enum HTTPSessionParameter {
    
    case none
    
    case urlEncoding(parameters: [String: Any])
    
    case postJSON(parameters: [String: Any])
        
    case postXML(parameters: [String: Any])
}


enum HTTPResponseDataType {
    
    case text
    
    case json
    
    case xml
}


enum HTTPSessionError {
    
    case baseURLInvalid(baseURL: String)
    
    case urlEncodingError
    
    case parametersJSONEncodingError(parameters: [String: Any])
    
    case requestError(error: Error)
    
    case responseFailed
    
    case httpStatusCodeInvalid
    
    case noResponsedData
    
    case decodingJSONDataError(jsonData: Data)
}


enum HTTPSessionResponse<T> {
    
    case success(T)
    
    case failure(error: HTTPSessionError)
}


typealias HTTPSessionHeaders = [String: String]


protocol HTTPURLRoute {
    
    var path: String { get }
    
    var method: HTTPMethod { get }
    
    var headers: HTTPSessionHeaders { get }
    
    var parameter: HTTPSessionParameter { get }
    
    var responseDataType: HTTPResponseDataType { get }
    
    @discardableResult func request<T>(httpSession: HTTPSession, dataType: T.Type, completion: @escaping (_ response: HTTPSessionResponse<T>) -> Void) -> URLSessionTask? where T: Decodable
}


extension URLComponents {
    
    init?(routeURL: URL, parameters: [String: Any]) {
        self.init(url: routeURL, resolvingAgainstBaseURL: false)
        
        queryItems = parameters.map({ key, value in
            return URLQueryItem(name: key, value: String(describing: value))
        })
    }
}


extension HTTPURLRoute {
    
    @discardableResult func request<T>(httpSession: HTTPSession, dataType: T.Type, completion: @escaping (_ response: HTTPSessionResponse<T>) -> Void) -> URLSessionTask? where T: Decodable {
        
        guard let baseURL = URL(string: httpSession.baseURLString) else {
            completion(HTTPSessionResponse.failure(error: HTTPSessionError.baseURLInvalid(baseURL: httpSession.baseURLString)))
            return nil
        }
        
        var routeURL = baseURL.appendingPathComponent(path)
        var bodyData: Data?
        
        switch parameter {
        case .urlEncoding(let paras):
            guard let encodedURL = URLComponents(routeURL: routeURL, parameters: paras)?.url else {
                completion(HTTPSessionResponse.failure(error: HTTPSessionError.urlEncodingError))
                return nil
            }
            
            routeURL = encodedURL
            
        case .postJSON(let paras):
            bodyData = try? JSONSerialization.data(withJSONObject: paras, options: [])
            
            if nil == bodyData {
                completion(HTTPSessionResponse.failure(error: HTTPSessionError.parametersJSONEncodingError(parameters: paras)))
                return nil
            }
            
        case .postXML(let paras):
            print("It looks like too old school. Objects: [\(paras)]")
            break
            
        default:
            break
        }
        
        
        var urlRequest = URLRequest(url: routeURL)
        
        urlRequest.httpMethod = method.rawValue
        
        headers.forEach { (key: String, value: String) in
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        urlRequest.httpBody = bodyData
                
        
        let task = httpSession.urlSession.dataTask(with: urlRequest) { data, urlResponse, error in
            
            if let err = error {
                print("urlSession.dataTask error: [\(err)]")
                completion(HTTPSessionResponse.failure(error: HTTPSessionError.requestError(error: err)))
                return
            }
            
            guard let response = urlResponse as? HTTPURLResponse else {
                completion(HTTPSessionResponse.failure(error: HTTPSessionError.responseFailed))
                return
            }
            
            switch response.statusCode {
            case 200...299:
                guard let respData = data else {
                    completion(HTTPSessionResponse.failure(error: HTTPSessionError.noResponsedData))
                    return
                }
                
                switch self.responseDataType {
                case .json:
                    let decoder = JSONDecoder()
                    guard let model = try? decoder.decode(T.self, from: respData) else {
                        completion(HTTPSessionResponse.failure(error: HTTPSessionError.decodingJSONDataError(jsonData: respData)))
                        return
                    }
                    
                    completion(HTTPSessionResponse.success(model))
                    
                case .text:
                    print("Responsed Data is Text.")
                    
                default:
                    print("It looks like too old school. Responsed Data Length: [\(respData.count)]")
                }
                
            default:
                print("HTTP Responsed Status Code: [\(response.statusCode)]")
                completion(HTTPSessionResponse.failure(error: HTTPSessionError.httpStatusCodeInvalid))
                return
            }
        }
                
        task.resume()
        return task
    }
}

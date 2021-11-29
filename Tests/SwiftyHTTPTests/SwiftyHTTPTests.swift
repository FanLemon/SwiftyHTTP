import XCTest
@testable import SwiftyHTTP

//
// https://reqres.in/api/login
//


class APITestHTTPSession: HTTPSession {
    
    var urlSession: URLSession = URLSession(configuration: URLSessionConfiguration.default)
    
    var baseURLString: String = "https://reqres.in/"
    
    init() {
        
    }
    
    static let shared = APITestHTTPSession()
}


enum APITestUserModule: HTTPURLRoute {
    
    case login(email: String, password: String)
    
    case singleUser
    
    case users(page: Int)
    
    var path: String {
        switch self {
        case .login( _, _):
            return "api/login"
            
        case .singleUser:
            return "api/users/2"
            
        case .users( _):
            return "api/users"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .login( _, _):
            return .POST
        case .singleUser:
            return .GET
        case .users( _):
            return .GET
        }
    }
    
    var headers: [String : String] {
        return ["Content-Type": "application/json"]
    }
     
    //
    //    {
    //        "email": "eve.holt@reqres.in",
    //        "password": "cityslicka"
    //    }
    //
    var parameter: HTTPSessionParameter {
        switch self {
        case .login( let email, let password):
            return HTTPSessionParameter.postJSON(parameters: ["email": email, "password": password])
        case .singleUser:
            return HTTPSessionParameter.none
        case .users( let page):
            return HTTPSessionParameter.urlEncoding(parameters: ["page" : page])
        }
    }
        
    var responseDataType: HTTPResponseDataType {
        return .json
    }
}


//
// {
//     "token": "QpwL5tke4Pnpja7X4"
// }
//
struct UserLoginStatus: Codable {
    
    var token: String
}


//
//    {
//        "data": {
//            "id": 2,
//            "email": "janet.weaver@reqres.in",
//            "first_name": "Janet",
//            "last_name": "Weaver",
//            "avatar": "https://reqres.in/img/faces/2-image.jpg"
//        },
//        "support": {
//            "url": "https://reqres.in/#support-heading",
//            "text": "To keep ReqRes free, contributions towards server costs are appreciated!"
//        }
//    }
//
struct UserData: Codable {
    
    var id: Int
    
    var email: String
    
    var first_name: String
    
    var last_name: String
    
    var avatar: String
}

struct UserSupport: Codable {
    
    var url: String
    
    var text: String
}

struct User: Codable {
    
    var data: UserData
    
    var support: UserSupport
}

struct UsersPage: Codable {
    
    var page: Int
    
    var per_page: Int
    
    var total: Int
    
    var total_pages: Int
    
    var data: [UserData]
    
    var support: UserSupport
}



final class SwiftyHTTPTests: XCTestCase {
    
    func testPost() throws {
        
        var loginStatus = UserLoginStatus(token: "")
        let semaphore = DispatchSemaphore(value: 0)
        
        APITestUserModule.login(email: "eve.holt@reqres.in", password: "cityslicka").request(httpSession: APITestHTTPSession.shared, dataType: UserLoginStatus.self) { response in
            
            switch response {
            case .success(let status):
                print("Login return status: [\(status)]")
                loginStatus = status
                semaphore.signal()
                
            case .failure(let err):
                print("User Login Error: \(err)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 6)
        
        XCTAssertEqual(loginStatus.token, "QpwL5tke4Pnpja7X4")
    }
    
    func testGet() throws {
        
        var singleUser = User(data: UserData(id: 0, email: "", first_name: "", last_name: "", avatar: ""),
                              support: UserSupport(url: "", text: ""))
        
        let semaphore = DispatchSemaphore(value: 0)
        
        APITestUserModule.singleUser.request(httpSession: APITestHTTPSession.shared, dataType: User.self) { response in
            
            switch response {
            case .success(let user):
                print("User [\(user)]")
                singleUser = user
                semaphore.signal()
                
            case .failure(let err):
                print("User get single user Error: \(err)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 6)
        
        XCTAssertEqual(singleUser.data.first_name, "Janet")
        XCTAssertEqual(singleUser.data.last_name, "Weaver")
    }
    
    func testURLEncoding() throws {
        
        var pageUser = UsersPage(page: 0, per_page: 0, total: 0, total_pages: 0, data: [], support: UserSupport(url: "", text: ""))
        
        let semaphore = DispatchSemaphore(value: 0)
        
        APITestUserModule.users(page: 2).request(httpSession: APITestHTTPSession.shared, dataType: UsersPage.self) { response in
            
            switch response {
            case .success(let page):
                print("Page User [\(page)]")
                pageUser = page
                semaphore.signal()
                
            case .failure(let err):
                print("User get page user Error: \(err)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: DispatchTime.now() + 6)
        
        XCTAssertEqual(pageUser.data.count, 6)
        XCTAssertEqual(pageUser.support.text, "To keep ReqRes free, contributions towards server costs are appreciated!")
    }
    
    @available(macOS 12.0.0, iOS 15.0.0, *)
    func testAwaitGet() async throws {
        
        let result = try await APITestUserModule.singleUser.fetch(httpSession: APITestHTTPSession.shared, dataType: User.self)
        
        XCTAssertEqual(result.data.first_name, "Janet")
        XCTAssertEqual(result.data.last_name, "Weaver")
    }
    
    @available(macOS 12.0.0, iOS 15.0.0, *)
    func testAwaitPost() async throws {
        
        let loginStatus = try await APITestUserModule.login(email: "eve.holt@reqres.in", password: "cityslicka").fetch(httpSession: APITestHTTPSession.shared, dataType: UserLoginStatus.self)
        
        XCTAssertEqual(loginStatus.token, "QpwL5tke4Pnpja7X4")
    }
    
    @available(macOS 12.0.0, iOS 15.0.0, *)
    func testAwaitURLEncoding() async throws {
        
        let pageUser = try await APITestUserModule.users(page: 2).fetch(httpSession: APITestHTTPSession.shared, dataType: UsersPage.self)
        
        XCTAssertEqual(pageUser.data.count, 6)
        XCTAssertEqual(pageUser.support.text, "To keep ReqRes free, contributions towards server costs are appreciated!")
    }
}



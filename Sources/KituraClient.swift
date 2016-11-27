//
//  KituraClient.swift
//  OnBeatCore
//
//  Created by Andrew J Wagner on 11/26/16.
//
//

import Foundation
import SwiftServe
import KituraNet

class KituraClient: Client {
    public func respond(to request: SwiftServe.ClientRequest) -> SwiftServe.ClientResponse {
        let request = request as! KituraClientRequest

        var finalResponse: SwiftServe.ClientResponse?
        let condition = NSCondition()
        let finalRequest = HTTP.request(request.options, callback: { response in
            if let response = response {
                finalResponse = KituraClientResponse(response: response)
            }
            condition.signal()
        })
        finalRequest.end(request.body)
        while finalResponse == nil {
            condition.wait()
        }
        return finalResponse!
    }

    public required init(url: URL) throws {
    }
}

class KituraClientRequest: SwiftServe.ClientRequest {
    let urlComponents: URLComponents
    let method: HTTPMethod
    let headers: [String:String]
    let body: String

    public required init(method: HTTPMethod, url: URL, headers: [String : String], body: String) {
        self.method = method
        self.urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        self.headers = headers
        self.body = body
    }

    var options: [KituraNet.ClientRequest.Options] {
        var options: [KituraNet.ClientRequest.Options] = [
            .method(self.method.rawValue),
            .headers(self.headers),
            .path(self.urlComponents.path),
        ]
        if let schema = self.urlComponents.scheme {
            options.append(.schema(schema))
        }
        if let hostname = self.urlComponents.host {
            options.append(.hostname(hostname))
        }
        if let port = self.urlComponents.port {
            options.append(.port(Int16(port)))
        }
        if let username = self.urlComponents.user {
            options.append(.username(username))
        }
        if let password = self.urlComponents.password {
            options.append(.password(password))
        }
        return options
    }
}

class KituraClientResponse: SwiftServe.ClientResponse {
    private let response: KituraNet.ClientResponse

    init(response: KituraNet.ClientResponse) {
        self.response = response
    }

    public var body: Data {
        do {
            var output = Data()

            let _ = try self.response.read(into: &output)

            return output
        }
        catch let error {
            print("Error reading data: \(error)")
            return Data()
        }
    }

    public var status: HTTPStatus {
        return HTTPStatus(rawValue: self.response.statusCode.rawValue) ?? .internalServerError
    }

}

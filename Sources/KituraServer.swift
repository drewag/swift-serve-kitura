//
//  KituraServer.swift
//  SwiftServeKitura
//
//  Created by Andrew J Wagner on 11/26/16.
//
//

import Foundation
import SwiftServe
import Kitura
import KituraNet

open class KituraServer: SwiftServe.Server {
    let port: Int
    let router: SwiftServe.Router

    struct HTTPSInfo {
        let certificatePath: String
        let privateKeyPath: String
    }
    let httpsInfo: HTTPSInfo?

    public var extraLogForRequest: ((SwiftServe.Request) -> String?)?

    public required init(port: Int, router: SwiftServe.Router) throws {
        self.port = port
        self.router = router
        self.httpsInfo = nil
    }

    public required init(port: Int, router: SwiftServe.Router, certificatePath: String, privateKeyPath: String) throws {
        self.port = port
        self.router = router
        self.httpsInfo = HTTPSInfo(certificatePath: certificatePath, privateKeyPath: privateKeyPath)
    }

    public func start() throws {
        ClientFactory.singleton.clientType = KituraClient.self
        ClientFactory.singleton.requestType = KituraClientRequest.self

        let router = Router()
        router.all { rawRequest, rawResponse, next in
            let rawResponse = rawResponse
            let request = KituraRequest(request: rawRequest)
            let kituraResponse: KituraResponse
            do {
                switch try self.router.route(request: request, to: rawRequest.parsedURL.path!) {
                case .handled(let response):
                    self.log(response: response, to: request)
                    kituraResponse = response as! KituraResponse
                case .unhandled:
                    let response = self.unhandledResponse(to: request)
                    self.log(response: response, to: request)
                    kituraResponse = response as! KituraResponse
                }
            }
            catch let error {
                let response = self.response(for: error, from: request)
                self.log(response: response, to: request)
                kituraResponse = response as! KituraResponse
            }
            rawResponse.statusCode = kituraResponse.kituraStatus
            for (key, value) in kituraResponse.headers {
                rawResponse.headers[key] = value
            }
            switch kituraResponse.body {
            case .data(let data):
                rawResponse.send(data: data)
            case .file(let path):
                try rawResponse.send(fileName: path)
                break
            }
            try rawResponse.end()
        }
        let sslConfig: SSLConfig?
        if let httpsInfo = self.httpsInfo {
            #if os(Linux)
                sslConfig = SSLConfig(
                    withCACertificateDirectory: nil,
                    usingCertificateFile: httpsInfo.certificatePath,
                    withKeyFile: httpsInfo.privateKeyPath,
                    usingSelfSignedCerts: true
                )
            #else
                sslConfig = nil
            #endif
        }
        else {
            sslConfig = nil
        }
        Kitura.addHTTPServer(onPort: port, with: router, withSSL: sslConfig)
            .failed(callback: { error in
                print(error)
            })
        Kitura.run()
    }
}

private class KituraRequest: Request {
    let request: RouterRequest

    init(request: RouterRequest) {
        self.request = request
    }

    public let databaseConnection = DatabaseConnection()

    public var host: String {
        return self.request.hostname
    }

    public var cookies: [String : String] {
        var cookies = [String:String]()
        for (key, value) in self.headers {
            if key == "Cookie" {
                let cookieNameValues = value.components(separatedBy: "; ")
                for rawCookie in cookieNameValues {
                    var name = ""
                    var value = ""
                    var foundSeparator = false
                    for character in rawCookie.characters {
                        guard !foundSeparator else  {
                            value.append(character)
                            continue
                        }
                        if character == "=" {
                            foundSeparator = true
                        }
                        else {
                            name.append(character)
                        }
                    }
                    if foundSeparator {
                        cookies[name] = value
                    }
                }
            }
        }
        return cookies
    }

    public var headers: [String : String] {
        var output = [String:String]()

        for (key, value) in self.request.headers {
            output[key] = value
        }

        return output
    }

    private var readData: Data?

    public var data: Data {
        if let data = self.readData {
            return data
        }

        do {
            var output = Data()

            let _ = try self.request.read(into: &output)

            self.readData = output
            return output
        }
        catch let error {
            print("Error reading data: \(error)")
            return Data()
        }
    }

    public var endpoint: URL {
        return URL(string: self.request.url)!
    }

    public var ip: String {
        return self.request.remoteAddress
    }

    public var method: HTTPMethod {
        switch self.request.method {
        case .get:
            return .get
        case .post:
            return .post
        case .put:
            return .put
        case .delete:
            return .delete
        default:
            return .any
        }
    }

    public func response(withData data: Data, status: HTTPStatus, headers: [String : String]) -> Response {
        return KituraResponse(body: .data(data), status: status, headers: headers)
    }

    public func response(withFileAt path: String, status: HTTPStatus, headers: [String:String]) throws -> Response {
        return KituraResponse(body: .file(path), status: status, headers: headers)
    }
}

private class KituraResponse: Response {
    public var status: HTTPStatus

    enum Body {
        case data(Data)
        case file(String)
    }

    let body: Body
    var kituraStatus: HTTPStatusCode {
        return HTTPStatusCode(rawValue: self.status.rawValue) ?? .unknown
    }
    let headers: [String:String]

    init(body: Body, status: HTTPStatus, headers: [String:String]) {
        self.status = status
        self.body = body
        self.headers = headers
    }
}

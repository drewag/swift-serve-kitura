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
import Swiftlier
import SQL
import PostgreSQL
import Decree

open class KituraServer: SwiftServe.Server {
    let port: Int
    let router: SwiftServe.Router

    struct HTTPSInfo {
        let certificatePath: String
        let privateKeyPath: String
    }
    let httpsInfo: HTTPSInfo?

    public let errorViewRoot: String
    public var extraLogForRequest: ((SwiftServe.Request) -> String?)?
    public var postProcessResponse: ((inout Response) -> ())?

    public required init(port: Int, router: SwiftServe.Router, errorViewRoot: String) throws {
        self.port = port
        self.router = router
        self.httpsInfo = nil
        self.errorViewRoot = errorViewRoot
    }

    public required init(port: Int, router: SwiftServe.Router, errorViewRoot: String, certificatePath: String, privateKeyPath: String) throws {
        self.port = port
        self.router = router
        self.httpsInfo = HTTPSInfo(certificatePath: certificatePath, privateKeyPath: privateKeyPath)
        self.errorViewRoot = errorViewRoot
    }

    public func start() throws {
        let router = Router()
        router.all { rawRequest, rawResponse, next in
            let rawResponse = rawResponse
            let request = KituraRequest(request: rawRequest)
            var response: Response
            do {
                guard let path = rawRequest.parsedURL.path?.removingPercentEncoding else {
                    throw GenericSwiftlierError("routing", because: "it has an invalid path")
                }
                switch try self.router.route(request: request, to: path) {
                case .handled(let newResponse):
                    response = newResponse
                case .unhandled:
                    let newResponse = self.unhandledResponse(to: request)
                    response = newResponse
                }
            }
            catch let error {
                let newResponse = self.response(for: error, from: request)
                response = newResponse
            }

            self.postProcessResponse?(&response)
            self.log(response: response, to: request)

            let kituraResponse = response as! KituraResponse

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

    public var preprocessStack = RequestProcessStack()
    public var postprocessStack = RequestProcessStack()

    init(request: RouterRequest) {
        self.request = request
    }

    public let databaseConnection: Connection = PostgreSQLConnection()

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
                    for character in rawCookie {
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

    public var headers: [CaseInsensitiveKey : String] {
        var output = [CaseInsensitiveKey:String]()

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
        return self.request.urlURL
    }

    public var ip: String {
        return self.request.remoteAddress
    }

    public var method: Decree.Method {
        return Decree.Method(rawValue: self.request.method.rawValue)
    }

    public func response(withData data: Data, status: HTTPStatus, error: SwiftlierError?, headers: [String : String]) -> Response {
        return KituraResponse(body: .data(data), status: status, error: error, headers: headers)
    }

    public func response(withFileAt path: String, status: HTTPStatus, error: SwiftlierError?, headers: [String:String]) throws -> Response {
        return KituraResponse(body: .file(path), status: status, error: error, headers: headers)
    }
}

private class KituraResponse: Response {
    public let error: SwiftlierError?
    public var status: HTTPStatus

    enum Body {
        case data(Data)
        case file(String)
    }

    let body: Body
    var kituraStatus: HTTPStatusCode {
        return HTTPStatusCode(rawValue: self.status.rawValue) ?? .unknown
    }
    var headers: [String:String]

    init(body: Body, status: HTTPStatus, error: SwiftlierError?, headers: [String:String]) {
        self.status = status
        self.body = body
        self.headers = headers
        self.error = error
    }
}

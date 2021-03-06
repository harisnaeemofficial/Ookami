//
//  PaginatedServiceSpec.swift
//  Ookami
//
//  Created by Maka on 14/11/16.
//  Copyright © 2016 Mikunj Varsani. All rights reserved.
//

import Quick
import Nimble
@testable import OokamiKit
import SwiftyJSON
import OHHTTPStubs
import RealmSwift

private class StubParser: Parser {
    
    override func parse(json: JSON, callback: @escaping ([Object]) -> Void) {
        let o = StubRealmObject()
        o.id = 1
        callback([o])
    }
}

private class StubPaginatedService: PaginatedService {
    
    var startCalledCount = 0
    var nextCalledCount = 0
    var prevCalledCount = 0
    var firstCalledCount = 0
    var lastCalledCount = 0
    
    override func start() {
        startCalledCount += 1
        super.start()
    }
    
    override func next() {
        nextCalledCount += 1
        super.next()
    }
    
    override func prev() {
        prevCalledCount += 1
        super.prev()
    }
    
    override func first() {
        firstCalledCount += 1
        super.first()
    }
    
    override func last() {
        lastCalledCount += 1
        super.last()
    }
    
}

class PaginatedServiceSpec: QuickSpec {
    override func spec() {
        
        var client: NetworkClient!
        var request: KitsuLibraryRequest!
        
        describe("Paginated Base") {
            
            beforeEach {
                
                client = NetworkClient(baseURL: "http://kitsu.io", heimdallr: StubAuthHeimdallr())
                request = KitsuLibraryRequest(userID: 1, type: .anime)
                
                //Stub the network to return JSON data
                stub(condition: isHost("kitsu.io")) { _ in
                    return OHHTTPStubsResponse(error: NetworkClientError.error("failed to get json"))
                }
            }
            
            afterEach {
                OHHTTPStubs.removeAllStubs()
            }
            
            context("Requests") {
                context("Calling original request") {
                    it("should call original request if there are no links") {
                        let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                        
                        p.next()
                        p.prev()
                        p.first()
                        p.last()
                        expect(p.startCalledCount).toEventually(equal(4))
                    }
                    
                    it("should not call original request if it has already been called") {
                        let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                        p.calledOriginalRequest = true
                        
                        p.next()
                        p.prev()
                        p.first()
                        p.last()
                        expect(p.startCalledCount).toEventually(equal(0))
                    }
                }
                
                
                it("should correctly build requests for links") {
                    let linkString = "http://abc.io/anime"
                    let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                    let request = p.request(for: linkString)
                    expect(request.url).to(equal(linkString))
                }
                
                it("should return error if link is nil") {
                    var error: Error?
                    
                    let p = StubPaginatedService(request: request, client: client) { _, e, _ in
                        error = e
                    }
                    p.calledOriginalRequest = true
                    p.links.first = "hello"
                    p.performRequest(for: nil, nilError: .noNextPage)
                    expect(error).toEventually(matchError(PaginationError.noNextPage))
                }
            }
            
            context("Fetching") {
                context("Links") {
                    it("should correctly set links from json") {
                        let data = ["links": ["first": "abc", "last": "def"]]
                        let json = JSON(data)
                        let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                        p.updateLinks(fromJSON: json)
                        
                        expect(p.links.hasAnyLinks()).to(beTrue())
                        expect(p.links.first).to(equal("abc"))
                        expect(p.links.next).to(beNil())
                        expect(p.links.previous).to(beNil())
                        expect(p.links.last).to(equal("def"))
                    }
                    
                    it("should set all links to nil if no links exist in json") {
                        let json = TestHelper.json(data: "abc")
                        let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                        p.links.first = "abc"
                        p.links.next = "def"
                        p.links.previous = "ghi"
                        p.links.last = "jkl"
                        p.updateLinks(fromJSON: json)
                        
                        expect(p.links.hasAnyLinks()).to(beFalse())
                        expect(p.links.first).to(beNil())
                        expect(p.links.next).to(beNil())
                        expect(p.links.previous).to(beNil())
                        expect(p.links.last).to(beNil())
                    }
                    
                    it("should set all links to nil if links is not a dictionary in json") {
                        let json = JSON(["links": "abc"])
                        let p = StubPaginatedService(request: request, client: client) { _, _, _ in }
                        p.links.first = "abc"
                        p.links.next = "def"
                        p.links.previous = "ghi"
                        p.links.last = "jkl"
                        p.updateLinks(fromJSON: json)
                        
                        expect(p.links.hasAnyLinks()).to(beFalse())
                        expect(p.links.first).to(beNil())
                        expect(p.links.next).to(beNil())
                        expect(p.links.previous).to(beNil())
                        expect(p.links.last).to(beNil())
                    }
                }
                
                context("Objects") {
                    it("should correctly return fetched objects") {
                        var objects: [Object]?
                        
                        
                        stub(condition: isHost("kitsu.io")) { _ in
                            let data = ["data": "hi"]
                            return OHHTTPStubsResponse(jsonObject: data, statusCode: 200, headers: ["Content-Type": "application/vnd.api+json"])
                        }
                        
                        let p = StubPaginatedService(request: request, client: client) { fetched, _, _ in
                            objects = fetched
                        }
                        p.parser = StubParser()
                        p.start()
                        
                        expect(p.startCalledCount).toEventually(equal(1))
                        expect(objects).toEventually(haveCount(1))
                    }
                    
                    it("should correctly call the link and return the objects") {
                        var objects: [Object]?
                        var error: Error? = NetworkClientError.error("an error")
                        
                        stub(condition: isHost("abc.io")) { _ in
                            let data = ["data": "hi"]
                            return OHHTTPStubsResponse(jsonObject: data, statusCode: 200, headers: ["Content-Type": "application/vnd.api+json"])
                        }
                        
                        let p = StubPaginatedService(request: request, client: client) { fetched, e, _ in
                            objects = fetched
                            error = e
                        }
                        
                        p.parser = StubParser()
                        p.calledOriginalRequest = true
                        p.links.next = "http://abc.io/anime"
                        p.next()
                        
                        expect(p.nextCalledCount).toEventually(equal(1))
                        expect(objects).toEventually(haveCount(1))
                        expect(error).toEventually(beNil())
                    }
                }
            }
        }
    }
}




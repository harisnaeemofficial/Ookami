//
//  PaginatedLibrary.swift
//  Ookami
//
//  Created by Maka on 13/11/16.
//  Copyright © 2016 Mikunj Varsani. All rights reserved.
//

import Foundation
import SwiftyJSON
import RealmSwift

/*
 The reason we have a paginated library class is because users won't look at ALL of another users library if you think about it.
 
 Say a user `A` looks at user `B`'s completed library which has 1000 entries. `A` won't bother looking through all 1000 entries of `B`, thus we can save time and data usage by adding in pagination, which is already supported by the api. This makes it so user `A` can still look at user `B`'s completed library, but if they wish to view more we just fetch the next page from the server for them.
 
 However we still need to be able to fetch a full users library regardless of pagination, thus the FetchLibraryOperation still exists. This is needed for the current user using the app. We need to reliably be able to sync between the website and the app (e.g if user deletes entry on website, then it should be deleted in app) and the only way to do that is to fetch the users whole library.
*/

/// Struct for holding the pagination link state
public struct PaginatedLibraryLinks {
    public var first: String?
    public var next: String?
    public var previous: String?
    public var last: String?
    
    /// Check whether there is any link that is not nil
    ///
    /// - Returns: Whether there is a link that is not nil
    public func hasAnyLinks() -> Bool {
        return first != nil || next != nil || previous != nil || last != nil
    }
}

public enum PaginatedLibraryError : Error {
    case invalidJSONRecieved
    case noNextPage
    case noPreviousPage
    case noFirstPage
    case noLastPage
}

/// Class for fetching a user's library paginated from the server.
///
/// How this works is that it will first fetch entries through the request passed in.
/// There after it will use the links provided from the response to preform the rest of the fetches.
/// If at any point a request fails, then the current link state will not be overriden.
///
/// E.g nextLink = 5, library.next() -> fails, nextLink will still be 5, thus calling next again will try perform the request again
public class PaginatedLibrary {
    
    ///A bool to track whether we called the original request, using `start()`
    ///This is specifically used as to not cause an infinite loop when calling the functions such as `next()` and `prev()` etc
    var calledOriginalRequest: Bool = false
    
    /// The completion block type, return the the fetched objects on the current page, or an Error if something went wrong
    public typealias PaginatedLibraryCompletion = ([Object]?, Error?) -> Void
    
    /// The JSON Parser
    public var parser: Parser = Parser()
    
    /// The queue for executing the pagination requests on
    var queue: OperationQueue = {
        let q = OperationQueue()
        //Make it serial
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    /// The library get requests passed in
    let originalRequest: KitsuLibraryRequest
    public var request: KitsuLibraryRequest {
        return originalRequest.copy() as! KitsuLibraryRequest
    }
    
    /// The client to execute request on
    let client: NetworkClientProtocol
    
    /// The completion block which gets called everytime a request was successful
    let completion: PaginatedLibraryCompletion
    
    /// The links for pagination
    public internal(set) var links: PaginatedLibraryLinks = PaginatedLibraryLinks()
    
    /// Create a paginated library.
    /// call `start()` to begin the fetch
    ///
    /// - Parameters:
    ///   - request: The paged kitsu request for the library
    ///   - client: The client to execute request on
    ///   - completion: The completion block, returns the fetched entries and related objects on the current page, or an Error if something went wrong.
    ///                 This gets called everytime a page of entries is recieved.
    ///                 This can be through calls such as `next()`, `prev()` etc ...
    public init(request: KitsuLibraryRequest, client: NetworkClientProtocol, completion: @escaping PaginatedLibraryCompletion) {
        self.originalRequest = request.copy() as! KitsuLibraryRequest 
        self.client = client
        self.completion = completion
    }

    //MARK: - Requesting
    
    /// Perform a request on the client
    ///
    /// - Parameter request: The network request
    /// - Parameter isOriginal: Whether the request is the original request
    func perform(request: NetworkRequest, isOriginal: Bool = false) {
        let operation = NetworkOperation(request: request, client: client) { json, error in

            //Check for errors
            guard error == nil else {
                self.completion(nil, error)
                return
            }
            
            //Check we have the JSON
            guard json != nil else {
                self.completion(nil, PaginatedLibraryError.invalidJSONRecieved)
                return
            }
            
            //Set the bool to indicate we have called the original request
            if isOriginal {
                self.calledOriginalRequest = true
            }
            
            //Update the links
            self.updateLinks(fromJSON: json!)
            
            //Parse the response
            let parsed = self.parser.parse(json: json!)
            self.completion(parsed, nil)
        }
        queue.addOperation(operation)
    }
    
    /// Update the link state from the recieved json.
    /// - Important: If no link dictionary is found in the json then it sets all the links to nil
    ///
    /// - Parameter json: The json object
    func updateLinks(fromJSON json: JSON) {
        let links = json["links"]
        if links.exists() && links.type == .dictionary {
            self.links.first = links["first"].string
            self.links.next = links["next"].string
            self.links.previous = links["prev"].string
            self.links.last = links["last"].string
        } else {
            self.links.first = nil
            self.links.next = nil
            self.links.previous = nil
            self.links.last = nil
        }
    }

    //MARK: - Methods
    
    /// Get the network request for an absolute link
    ///
    /// - Parameter link: The absolute link
    /// - Returns: The request for the link
    func request(for link: String) -> NetworkRequest {
        //When we get the link, it should automatically have the baseURL tacked onto it, so we can get away with passing the full url to it
        return NetworkRequest(absoluteURL: link, method: .get)
    }
    
    
    /// Perform a request for a given link
    ///
    /// - Parameters:
    ///   - link: The link
    ///   - nilError: The error to pass if link was nil
    func performRequest(for link: String?, nilError: PaginatedLibraryError) {
        //If we haven't called the original request then call it.
        //This is to stop an infinite recursion from occurring which can happen if a client keeps calling functions such as `next()` and `prev()`
        guard calledOriginalRequest else {
            start()
            return
        }
        
        //At this point we know that `start()` has been called. 
        //However if we still don't have any links then that must mean the links were not in the response.
        //We also check that if it does have links, that the current passed in link is valid.
        guard links.hasAnyLinks(), link != nil else {
            self.completion(nil, nilError)
            return
        }
        
        perform(request: request(for: link!))
    }

    /// Send out the original request
    public func start() {
        let nRequest = request.build()
        perform(request: nRequest, isOriginal: true)
    }
    
    /// Get the next page
    public func next() {
        performRequest(for: links.next, nilError: .noNextPage)
    }
    
    /// Get the previous page
    public func prev() {
        performRequest(for: links.previous, nilError: .noPreviousPage)
    }
    
    /// Get the first page
    public func first() {
        performRequest(for: links.first, nilError: .noFirstPage)
    }
    
    /// Get the last page
    public func last() {
        performRequest(for: links.last, nilError: .noLastPage)
    }
    
}

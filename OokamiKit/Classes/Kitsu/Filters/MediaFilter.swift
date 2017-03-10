//
//  MediaFilter.swift
//  Ookami
//
//  Created by Maka on 7/2/17.
//  Copyright © 2017 Mikunj Varsani. All rights reserved.
//

import Foundation

//A struct for representing sorting by a given key
public struct Sort {
    
    public enum Direction {
        case ascending
        case descending
    }
    
    public var key: String
    public var direction: Direction
    
    public init(by key: String, direction: Direction = .descending) {
        self.key = key
        self.direction = direction
    }
}

//A class for representing the media filters
public class MediaFilter {
    
    /// The sorting to apply to the filter
    public var sort: Sort
    
    /// The year range to filter
    public var year: RangeFilter<Int> {
        didSet {
            year.capValues(min: 1907, max: 99999)
            year.applyCorrection()
        }
    }
    
    //The rating range between 0.5 and 5.0 inclusive
    public var rating: RangeFilter<Double> {
        didSet {
            //Set the end to 5.0 if it's not set
            rating.end = rating.end ?? 5.0
            rating.capValues(min: 0.5, max: 5.0)
            rating.applyCorrection()
        }
    }
    
    //The genres
    public internal(set) var genres: [String] = []
    
    //Additional filters
    public internal(set) var additionalFilters: [String: Any] = [:]
    
    /// Create a media filter
    public init() {
        year = RangeFilter(start: 1907, end: nil)
        rating = RangeFilter(start: 0.5, end: 5.0)
        sort = Sort(by: "user_count")
    }
    
    /// Filter the media by genres.
    ///
    /// - Parameter genres: An array of genres to filter. If empty then it shows All genres.
    public func filter(genres: [Genre]) {
        self.genres = genres.map { $0.name }
    }
    
    /// Filter the media by a specific key
    ///
    /// - Parameters:
    ///   - key: The key
    ///   - value: The value to filter key by.
    public func filter(key: String, value: Any) {
        additionalFilters[key] = value
    }
    
    /// Convert the filters to a dictionary.
    ///
    /// - Returns: The dictionary representation of the filters
    public func construct() -> [String: Any] {
        var dict: [String: Any] = ["year": year.description]
        
        //Only include rating if it's not the default
        //This is because kitsu doesn't return media which has no rating ...
        if rating.start != 0.5 || rating.end != 5.0 {
            dict["averageRating"] = rating.description
        }
        
        //Filter genres only if we added them
        if genres.count > 0 {
            dict["genres"] = genres
        }
        
        //Add the additional filters
        for (key, value) in additionalFilters {
            dict[key] = value
        }
        
        return dict
    }
    
}

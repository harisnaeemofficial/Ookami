//
//  LibraryViewController.swift
//  Ookami
//
//  Created by Maka on 2/1/17.
//  Copyright © 2017 Mikunj Varsani. All rights reserved.
//

import UIKit
import OokamiKit
import XLPagerTabStrip
import BTNavigationDropdownMenu

protocol LibraryDataSourceParent: class {
    func didTapEntry(entry: LibraryEntry)
    func didUpdateEntries()
}

protocol LibraryDataSource: ItemViewControllerDataSource {
    weak var parent: LibraryDataSourceParent? { get set }
    func didSet(sort: LibraryViewController.Sort)
}

//Class used for displaying library entries of a specific type (e.g anime, manga)
final class LibraryViewController: ButtonBarPagerTabStripViewController {
    
    //Bool to keep track of whether the view finished loading
    fileprivate var didFinishLoading = false
    
    //The current library we are displaying
    fileprivate var type: Media.MediaType
    
    //The source of data to use
    fileprivate var source: [LibraryEntry.Status: LibraryDataSource]
    
    //The controllers to display
    fileprivate var itemControllers: [LibraryEntry.Status: ItemViewController] = [:]
    
    //Filter the results
    var sort: Sort {
        didSet {
            Sort.save(sort: sort)
            source.values.forEach { $0.didSet(sort: sort) }
        }
    }
    
    ///A clean flow layout for the buttonBarView.
    ///This is there because there is a bug in XLPagerTabStrip where if you set the buttonBarItemFont,
    ///the bar buttons don't size properley when setting buttonBarItemsShouldFillAvailiableWidth = true.
    //By setting a layout with all zero values, it seems to fix the issue
    fileprivate var flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 1, height: 1)
        layout.headerReferenceSize = .zero
        layout.footerReferenceSize = .zero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        return layout
    }()
    
    
    /// Create an `LibraryViewController`
    ///
    /// - Parameter dataSource: The datasource to use.
    init(dataSource: [LibraryEntry.Status: LibraryDataSource], type: Media.MediaType) {
        self.source = dataSource
        self.type = type
        sort = Sort.load() ?? Sort(type: .progressedAt, direction: .descending)
        super.init(nibName: nil, bundle: nil)
        
        //Save the sort incase it was never saved before
        Sort.save(sort: sort)
    }
    
    /// Do not use this to initialize `LibraryViewController`
    /// It will throw a fatal error if you do.
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use LibraryViewController.init(dataSource:)")
    }
    
    override func viewDidLoad() {
        let theme = Theme.PagerButtonBarTheme()
        self.settings.style.buttonBarItemLeftRightMargin = 12
        self.settings.style.buttonBarItemFont = UIFont.systemFont(ofSize: 14)
        self.settings.style.buttonBarItemTitleColor = theme.buttonTextColor
        self.settings.style.buttonBarBackgroundColor = theme.backgroundColor
        self.settings.style.buttonBarItemBackgroundColor = theme.buttonColor
        
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            self.containerView?.contentInsetAdjustmentBehavior = .always
        }
        
        //Read above for explanation on setting the layout
        buttonBarView.collectionViewLayout = flowLayout
        didFinishLoading = true
    }
    
    func reloadTitles() {
        self.updateItemControllerTitles()
    }
    
    func reloadData() {
        for controller in itemControllers.values {
            controller.reloadData()
        }
    }
    
    private func updateItemControllerTitles() {
        //Update the sources
        for status in LibraryEntry.Status.all {
            let controller = itemControllers[status]
            let dataSource = source[status]
            
            //Add the title with entry count
            let count = dataSource?.count ?? 0
            let title = status.toString(forMedia: type) + " (\(count))"
            controller?.title = title
        }
        
        if didFinishLoading {
            buttonBarView.reloadData()
        }
    }
    
    private func updateItemViewControllers() {
        //Update the sources
        for status in LibraryEntry.Status.all {
            source[status]?.didSet(sort: sort)
            itemControllers[status]?.dataSource = source[status]
        }
        
        updateItemControllerTitles()
    }
    
    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        
        var controllers: [ItemViewController] = []
        
        //Create the item view controllers and add them in order
        for status in LibraryEntry.Status.all {
            let dataSource = source[status]
            let itemController = ItemViewController(dataSource: dataSource)
            itemController.title = status.toString(forMedia: type)
            itemControllers[status] = itemController
            itemController.shouldLoadImages = status == .current
            
            controllers.append(itemController)
        }
        
        updateItemViewControllers()
        
        return controllers
    }
    
    override func updateIndicator(for viewController: PagerTabStripViewController, fromIndex: Int, toIndex: Int, withProgressPercentage progressPercentage: CGFloat, indexWasChanged: Bool) {
        super.updateIndicator(for: viewController, fromIndex: fromIndex, toIndex: toIndex, withProgressPercentage: progressPercentage, indexWasChanged: indexWasChanged)
        
        //Change the color under the bar
        let statuses = LibraryEntry.Status.all
        if progressPercentage < 0.5 {
            self.buttonBarView.selectedBar.backgroundColor = statuses[fromIndex].color()
        } else {
            self.buttonBarView.selectedBar.backgroundColor = statuses[toIndex].color()
        }
        
        //Just double check bounds incase of index errors
        guard fromIndex >= 0,
            fromIndex < self.viewControllers.count,
            toIndex >= 0,
            toIndex < self.viewControllers.count else {
                return
        }
        
        //Set the image should load on the view controller
        //This is to improve memory usage, so controllers which are hidden don't store the images.
        let from = self.viewControllers[fromIndex] as? ItemViewController
        let to = self.viewControllers[toIndex] as? ItemViewController
        
        to?.shouldLoadImages = true
        if progressPercentage >= 0.98, fromIndex != toIndex {
            from?.shouldLoadImages = false
        }
    }
    
}

//Mark:- Sorting
extension LibraryViewController {
    
    //A Sort struct just for Library
    struct Sort: Equatable {
        
        enum SortType: String {
            case progressedAt = "Last Updated"
            case title
            case progress
            case rating
        }
        
        enum Direction: String {
            case ascending
            case descending
        }
        
        var type: SortType
        var direction: Direction
        
        init(type: SortType, direction: Direction = .descending) {
            self.type = type
            self.direction = direction
        }
        
        //Save the sort
        static func save(sort: Sort) {
            let defaults = UserDefaults.standard
            defaults.set(sort.type.rawValue, forKey: "Library-Sort-Type")
            defaults.set(sort.direction.rawValue, forKey: "Library-Sort-Direction")
        }
        
        //Load a saved sort
        static func load() -> Sort? {
            let defaults = UserDefaults.standard
            guard let typeString = defaults.string(forKey: "Library-Sort-Type"),
                let directionString = defaults.string(forKey: "Library-Sort-Direction"),
                let type = SortType(rawValue: typeString),
                let direction = Direction(rawValue: directionString) else {
                    return nil
            }
            
            return Sort(type: type, direction: direction)
        }
        
        static func ==(lhs: Sort, rhs: Sort) -> Bool {
            return lhs.type == rhs.type &&
                lhs.direction == rhs.direction
        }
    }
}

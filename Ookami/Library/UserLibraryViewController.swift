//
//  UserLibraryViewController.swift
//  Ookami
//
//  Created by Maka on 4/1/17.
//  Copyright © 2017 Mikunj Varsani. All rights reserved.
//

import UIKit
import BTNavigationDropdownMenu
import OokamiKit
import Cartography
import NVActivityIndicatorView

//TODO: Need to add PagedLibraryDataSource
//TODO: Move settings to a page later

//Class used for displaying a users library (both anime and manga)
final class UserLibraryViewController: UIViewController {
    
    //The current user we're fetching library for
    fileprivate var userID: Int
    
    //The source of the data
    fileprivate var source: UserLibraryViewDataSource
    
    //The list of items which can be selected in the dropdown menu
    fileprivate var dropDownMenuItems = ["Anime", "Manga"]
    
    //The dropdown menu
    fileprivate var dropDownMenu: BTNavigationDropdownMenu!
    
    //The library view controllers
    fileprivate var animeController: LibraryViewController?
    fileprivate var mangaController: LibraryViewController?
    
    //The activity indicator for this view
    var activityIndicator: FullScreenActivityIndicator = {
        return FullScreenActivityIndicator()
    }()
    
    //The mail composer to use
    //TODO: Move this out after we have a proper settings page
    fileprivate lazy var mailComposer: MailComposer = {
        return MailComposer(parent: self)
    }()
    
    //The settings button to use
    fileprivate lazy var settingsButton: UIBarButtonItem = {
        return UIBarButtonItem(withIcon: .cogIcon, size: CGSize(width: 22, height: 22), target: self, action: #selector(settingsTapped))
    }()
    
    //The filter button
    fileprivate lazy var filterBarButton: UIBarButtonItem = {
        return UIBarButtonItem(withIcon: .filterIcon, size: CGSize(width: 22, height: 22), target: self, action: #selector(filterTapped))
    }()
    
    //The search button
    fileprivate lazy var searchBarButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchTapped))
    }()
    
    /// Create a `UserLibraryViewController`
    ///
    /// - Parameters:
    ///   - userID: The user id who we are showing the library of
    ///   - dataSource: The data source to use.
    init(userID: Int, dataSource: UserLibraryViewDataSource) {
        self.userID = userID
        self.source = dataSource
        super.init(nibName: nil, bundle: nil)
        
        //Set ourselves as the parent so we can show the appropriate VC when an entry is tapped
        self.source.parent = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use UserLibraryViewController.init(dataSource:)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.titleView = dropDownMenu
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Theme.ControllerTheme().backgroundColor
        
        //Add the library views
        animeController = LibraryViewController(dataSource: source.anime, type: .anime)
        mangaController = LibraryViewController(dataSource: source.manga, type: .manga)
        
        //Make sure both the anime and manga controller sorts are the same
        set(sort: animeController!.sort)
        
        for controller in [animeController!, mangaController!] as [LibraryViewController] {
            self.addChildViewController(controller)
            self.view.addSubview(controller.view)
            
            constrain(controller.view) { view in
                view.edges == view.superview!.edges
            }
            
            controller.didMove(toParentViewController: self)
        }
        
        //Setup dropdown menu
        dropDownMenu = BTNavigationDropdownMenu(title: dropDownMenuItems[0], items: dropDownMenuItems as [AnyObject])
        dropDownMenu.animationDuration = 0.2
        dropDownMenu.shouldKeepSelectedCellColor = true
        
        //Themeing
        let theme = Theme.DropDownTheme()
        dropDownMenu.cellBackgroundColor = theme.backgroundColor
        dropDownMenu.cellTextLabelColor = theme.textColor
        dropDownMenu.menuTitleColor = theme.textColor
        dropDownMenu.arrowTintColor = theme.textColor
        dropDownMenu.cellSelectionColor = theme.selectionBackgroundColor
        dropDownMenu.cellSeparatorColor = theme.seperatorColor
        
        dropDownMenu.didSelectItemAtIndexHandler = { [weak self] index in
            if let item = self?.dropDownMenuItems[index] {
                if item == "Anime" { self?.show(.anime) }
                if item == "Manga" { self?.show(.manga) }
            }
        }
        
        self.navigationItem.leftBarButtonItem = settingsButton
        self.navigationItem.rightBarButtonItems = [searchBarButton, filterBarButton]
        
        activityIndicator.add(to: self.view)
        
        show(.anime)
    }
    
    /// Show the appropriate view controller for the given media type
    ///
    /// - Parameter type: The media type
    func show(_ type: Media.MediaType) {
        animeController?.view.isHidden = type != .anime
        mangaController?.view.isHidden = type != .manga
    }
    
    //Reload the entries
    func reload() {
        animeController?.reloadData()
        mangaController?.reloadData()
    }
    
    func showRatingSystemAlert() {
        
        guard CurrentUser().isLoggedIn(),
            let currentSystem = CurrentUser().user?.ratingSystem else {
                return
        }
        
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.barButtonItem = settingsButton
        
        let ratingSystems = User.RatingSystem.all.filter { $0 != currentSystem }
        
        for system in ratingSystems {
            
            let changeRating = UIAlertAction(title: system.rawValue.capitalized, style: .default) { _ in
                
                DispatchQueue.main.async {
                    self.activityIndicator.showIndicator()
                    
                    UserService().update(ratingSystem: system) { error in
                        
                        self.activityIndicator.hideIndicator()
                        self.reload()
                        
                        if let error = error {
                            ErrorAlert.showAlert(in: self, title: "Error Occurred", message: error.localizedDescription)
                        }
                    }
                    
                }
            }
            alert.addAction(changeRating)
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancel)
        
        if self.presentedViewController == nil {
            self.present(alert, animated: true)
        }
        
    }
    
    func settingsTapped() {
        //TODO: Move this out of here after main pages (discovery, user, library) have been implemented
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.barButtonItem = settingsButton
        
        if CurrentUser().isLoggedIn() {
            
            let changeRating = UIAlertAction(title: "Change Rating System", style: .default) { _ in
                
                
                DispatchQueue.main.async {
                    self.showRatingSystemAlert()
                }
            }
            
            alert.addAction(changeRating)
        }
        
        let feedback = UIAlertAction(title: "Send Feedback", style: .default) { _ in
            self.mailComposer.present()
        }
        alert.addAction(feedback)
        
        let logout = UIAlertAction(title: "Logout", style: .destructive) { _ in
            CurrentUser().logout()
        }
        alert.addAction(logout)
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancel)
        
        if self.presentedViewController == nil {
            self.present(alert, animated: true)
        }
    }


    func filterTapped() {
        if let sort = animeController?.sort {
            let vc: LibraryFilterViewController = LibraryFilterViewController(sort: sort) { sort in
                self.set(sort: sort)
            }
            
            let nav = UINavigationController(rootViewController: vc)
            vc.title = "Filter"
            self.present(nav, animated: true)
        }
    }
    
    func searchTapped() {
        let type: Media.MediaType = (animeController?.view.isHidden ?? false) ? .manga : .anime
        let source = LocalSearchDataSource(userID: userID, type: type)
        let vc = SearchItemViewController(dataSource: source)
        vc.title = "Search Library"
        vc.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func set(sort: LibraryViewController.Sort) {
        if animeController?.sort != sort || mangaController?.sort != sort {
            animeController?.sort = sort
            mangaController?.sort = sort
        }
    }
    
}

extension UserLibraryViewController: LibraryDataSourceParent {
    func didTapEntry(entry: LibraryEntry) {
        AppCoordinator.showLibraryEntryVC(in: self.navigationController, entry: entry)
    }
    
    func didUpdateEntries() {
        animeController?.reloadTitles()
        mangaController?.reloadTitles()
    }
}

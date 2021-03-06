//
//  LibraryEntryViewController.swift
//  Ookami
//
//  Created by Maka on 6/1/17.
//  Copyright © 2017 Mikunj Varsani. All rights reserved.
//

import UIKit
import OokamiKit
import Cartography
import Reusable
import ActionSheetPicker_3_0
import NVActivityIndicatorView

private extension LibraryEntry {
    
    /// Convert `LibraryEntry` to `EntryMediaHeaderViewData`
    ///
    /// - Returns: The data representation of entry
    func toEntryMediaHeaderData() -> EntryMediaHeaderViewData {
        if let anime = self.anime { return EntryMediaHeaderViewData(anime: anime) }
        if let manga = self.manga { return EntryMediaHeaderViewData(manga: manga) }
        
        return EntryMediaHeaderViewData()
    }
}


//A class to show/edit a library entry
class LibraryEntryViewController: UIViewController {
    
    //The data to use for the controller
    let data: LibraryEntryViewData
    
    //The tableview to display data in
    lazy var tableView: UITableView = {
        let t = UITableView()
        t.alwaysBounceVertical = true
        t.backgroundColor = Theme.ControllerTheme().backgroundColor
        t.dataSource = self
        t.delegate = self
        
        t.register(cellType: EntryStringTableViewCell.self)
        t.register(cellType: EntryBoolTableViewCell.self)
        t.register(cellType: EntryButtonTableViewCell.self)
        
        t.tintColor = Theme.EntryView().tintColor
        
        //Auto table height
        t.estimatedRowHeight = 60
        t.rowHeight = UITableViewAutomaticDimension
        
        //Set the footer view so we don't get extra seperators
        t.tableFooterView = UIView(frame: .zero)
        
        //Disable default reading margins
        t.cellLayoutMarginsFollowReadableWidth = false
        
        if #available(iOS 11, *) {
            t.contentInsetAdjustmentBehavior = .never
        }
        
        return t
    }()
    
    //Pencil image used to indicate that user can edit the field
    fileprivate lazy var pencilImage: UIImage = {
        return FontAwesomeIcon.pencilIcon.image(ofSize: CGSize(width: 10, height: 10), color: Theme.EntryView().tintColor)
    }()
    
    //Whether the entry is editable
    let editable: Bool
    
    //The data we are going to use for the table view
    fileprivate var tableData: [LibraryEntryViewData.TableData] = []
    
    //Bar buttons
    var saveBarButton: UIBarButtonItem?
    var clearBarButton: UIBarButtonItem?
    
    //The activity indicator
    var activityIndicator: NVActivityIndicatorView = {
        let theme = Theme.ActivityIndicatorTheme()
        let view = NVActivityIndicatorView(frame: CGRect(origin: CGPoint.zero, size: theme.size), type: theme.type, color: theme.color)
        return view
    }()
    
    //The indicator overlay for displaying
    var indicatorOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        return v
    }()
    
    //Setting for disabling the media button on the header view
    //Useful to stop infinite recurrsion, E.g from entry -> media -> entry -> media ... etc
    var shouldShowMediaButton: Bool = true
    
    /// Create an LibraryEntryViewController
    ///
    /// - Parameter entry: The library entry to view.
    init(entry: LibraryEntry) {
        //Set the data
        self.data = LibraryEntryViewData(entry: entry)
        
        //entry is only editabe if we are the current user
        editable = entry.userID == CurrentUser().userID
        
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Do not use this to initialize `LibraryEntryViewController`
    /// It will throw a fatal error if you do.
    required init?(coder aDecoder: NSCoder) {
        fatalError("Use LibraryEntryViewController(entry:)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Show the save icon if we can edit the entries
        if editable {
            let size = CGSize(width: 22, height: 22)
            
            let saveImage = UIImage(named: "Check")
            saveBarButton = UIBarButtonItem(image: saveImage, style: .done, target: self, action: #selector(didSave))
            clearBarButton = UIBarButtonItem(withIcon: .trashIcon, size: size, target: self, action: #selector(didClear))
            
            self.navigationItem.rightBarButtonItems = [saveBarButton!, clearBarButton!]
        }
        
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.data.isInvalid() {
            let _ = self.navigationController?.popViewController(animated: true)
            return
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Add the table view
        self.view.addSubview(tableView)
        constrain(tableView) { view in
            view.edges == view.superview!.edges
        }
        
        //Add the indicator overlay
        self.view.addSubview(indicatorOverlay)
        constrain(indicatorOverlay) { view in
            view.edges == view.superview!.edges
        }
        
        //Add the indicator ontop of the overlay
        indicatorOverlay.addSubview(activityIndicator)
        let size = Theme.ActivityIndicatorTheme().size
        constrain(activityIndicator) { view in
            view.center == view.superview!.center
            view.width == size.width
            view.height == size.height
        }
        
        //Hide them both
        hideIndicator()
        
        //Force tableview layout
        tableView.setNeedsLayout()
        tableView.layoutIfNeeded()
        
        //Add the header
        if let entry = data.updater?.entry {
            var data = entry.toEntryMediaHeaderData()
            data.shouldShowMediaButton = shouldShowMediaButton
            
            let header = EntryMediaHeaderView(data: data)
            header.delegate = self
            tableView.tableHeaderView = header
        }
        
        //Reload the data
        self.reloadData()
    }
    
    //Reload the data and update the button bar items
    func reloadData() {
        
        //Only enable the buttons if there was a change
        saveBarButton?.isEnabled = data.updater?.wasEdited() ?? false
        clearBarButton?.isEnabled = data.updater?.wasEdited() ?? false
        
        //We set the offset again because tableview jumps when reloading if the entry has long notes
        let offset = tableView.contentOffset
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableView.setContentOffset(offset, animated: false)
    }
    
}

//MARK:- Data source
extension LibraryEntryViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //We can do it this was because we are 100% certain the data count won't change randomly while view is up
        return data.tableData().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableData = data.tableData()
        let type = tableData[indexPath.row].type
        var cell: UITableViewCell = UITableViewCell()
        switch type {
        case .bool:
            cell = tableView.dequeueReusableCell(for: indexPath) as EntryBoolTableViewCell
            
        case .string:
            cell = tableView.dequeueReusableCell(for: indexPath) as EntryStringTableViewCell
            
        case .button:
            cell = tableView.dequeueReusableCell(for: indexPath) as EntryButtonTableViewCell
            
        case .delete:
            cell = UITableViewCell()
        }
        
        //We update here because tableview won't automatically adjust height in willDisplayCell, unless we change orientation
        update(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func update(cell: UITableViewCell, indexPath: IndexPath) {
        let tableData = self.data.tableData()
        let data = tableData[indexPath.row]
        let heading = data.heading.rawValue
        
        //String cell
        if let stringCell = cell as? EntryStringTableViewCell {
            
            let pencil = UIImageView(image: pencilImage)
            
            cell.accessoryType = .none
            cell.accessoryView = pencil
            stringCell.headingLabel.text = heading
            
            let value = data.value as? String ?? ""
            stringCell.valueLabel.text = value.isEmpty ? "-" : value
        }
        
        //Bool cell
        if let boolCell = cell as? EntryBoolTableViewCell {
            boolCell.headingLabel.text = heading
            
            let value = data.value as? Bool ?? false
            cell.accessoryType = value ? .checkmark : .none
        }
        
        //Button cell
        if let buttonCell = cell as? EntryButtonTableViewCell {
            let value = data.value as? String ?? ""
            buttonCell.headingLabel.text = heading
            buttonCell.valueLabel.text = value.isEmpty ? "-" : value
            buttonCell.button.isHidden = !editable
            buttonCell.delegate = self
            buttonCell.indexPath = indexPath
        }
        
        if data.heading == .delete {
            cell.backgroundColor = Theme.Colors().red
            cell.textLabel?.text = data.value as? String ?? "Delete"
            cell.textLabel?.textColor = UIColor.white
        }
        
        if !editable {
            cell.accessoryView = nil
        }
    }
    
}

//MARK:- Delegate
extension LibraryEntryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if !editable { return }
        
        let tableData = data.tableData()
        let heading = tableData[indexPath.row].heading
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        data.didSelect(heading: heading, cell: cell, controller: self)
    }
}

//MARK:- EntryMediaHeaderViewDelegate & Entry Button Delegate
extension LibraryEntryViewController: EntryMediaHeaderViewDelegate, EntryButtonDelegate {
    func didTapMediaButton() {
        guard let entry = data.updater?.entry else {
            return
        }
        
        if let anime = entry.anime {
            AppCoordinator.showAnimeVC(in: self.navigationController!, anime: anime)
        }
        
        if let manga = entry.manga {
            AppCoordinator.showMangaVC(in: self, manga: manga)
        }
    }
    
    //+1 button tapped
    func didTapButton(inCell: EntryButtonTableViewCell, indexPath: IndexPath?) {
        if let indexPath = indexPath {
            let tableData = self.data.tableData()
            let d = tableData[indexPath.row]
            
            //Update the values accordingly
            switch d.heading {
            case .progress:
                data.updater?.incrementProgress()
                
            case .reconsumeCount:
                data.updater?.incrementReconsumeCount()
                
            default:
                break
            }
            
            self.reloadData()
        }
    }
}

extension LibraryEntryViewController: TextEditingViewControllerDelegate {
    func textEditingViewController(_ controller: TextEditingViewController, didSave text: String) {
        data.updater?.update(notes: text)
        self.reloadData()
    }
}

//MARK:- Entry saving
extension LibraryEntryViewController {
    
    func showIndicator() {
        UIView.animate(withDuration: 0.25) {
            self.activityIndicator.startAnimating()
            self.indicatorOverlay.isHidden = false
            self.navigationController?.navigationBar.isUserInteractionEnabled = false
            self.saveBarButton?.isEnabled = false
            self.clearBarButton?.isEnabled = false
        }
    }
    
    func hideIndicator() {
        UIView.animate(withDuration: 0.25) {
            self.activityIndicator.stopAnimating()
            self.indicatorOverlay.isHidden = true
            self.navigationController?.navigationBar.isUserInteractionEnabled = true
            self.saveBarButton?.isEnabled = true
            self.clearBarButton?.isEnabled = true
        }
    }
    
    //Save was tapped
    func didSave() {
        showIndicator()
        data.updater?.save { error in
            self.hideIndicator()
            guard error == nil else {
                
                //Show an alert to the user
                ErrorAlert.showAlert(in: self, title: "Error", message: "\(error!.localizedDescription). Please try again.")
                print(error!.localizedDescription)
                
                return
            }
            
            //Reload the display
            self.reloadData()
            
            //NOTE: Disabled for now, but we can always add an option to automatically pop upon save
            //let _ = self.navigationController?.popViewController(animated: true)
            
        }
    }
    
    func didClear() {
        data.updater?.reset()
        self.reloadData()
    }
}

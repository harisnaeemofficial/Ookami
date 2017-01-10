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
        let view = NVActivityIndicatorView(frame: CGRect(origin: CGPoint.zero, size: theme.size), type: .ballSpinFadeLoader, color: theme.color)
        return view
    }()
    
    //The dark overlay for displaying
    var darkOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        return v
    }()
    
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
        
        // Show the save icon if we can edit the entries
        if editable {
            let size = CGSize(width: 22, height: 22)
            saveBarButton = UIBarButtonItem(withIcon: .okIcon, size: size, target: self, action: #selector(didSave))
            clearBarButton = UIBarButtonItem(withIcon: .trashIcon, size: size, target: self, action: #selector(didClear))
            
            self.navigationItem.rightBarButtonItems = [saveBarButton!, clearBarButton!]
        }
        
        reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Add the table view
        self.view.addSubview(tableView)
        constrain(tableView) { view in
            view.edges == view.superview!.edges
        }
        
        //Add the dark overlay
        self.view.addSubview(darkOverlay)
        constrain(darkOverlay) { view in
            view.edges == view.superview!.edges
        }
        
        //Add the indicator ontop of the overlay
        darkOverlay.addSubview(activityIndicator)
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
        let header = EntryMediaHeaderView(data: data.updater.entry.toEntryMediaHeaderData())
        header.delegate = self
        tableView.tableHeaderView = header
        
        //Reload the data
        self.reloadData()
    }
    
    //Reload the data and update the button bar items
    func reloadData() {
        //Only enable the buttons if there was a change
        saveBarButton?.isEnabled = data.updater.wasEdited()
        clearBarButton?.isEnabled = data.updater.wasEdited()
        
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
            break
        case .string:
            cell = tableView.dequeueReusableCell(for: indexPath) as EntryStringTableViewCell
            break
        case .button:
            cell = tableView.dequeueReusableCell(for: indexPath) as EntryButtonTableViewCell
            break
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
        let entry = data.updater.entry
        let tableData = data.tableData()
        let heading = tableData[indexPath.row].heading
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        switch heading {
        case .progress:
            
            let max = entry.maxProgress() ?? 999
            let rows = Array(0...max)
            ActionSheetStringPicker.show(withTitle: "Progress", rows: rows, initialSelection: entry.progress, doneBlock: { picker, index, value in
                if let newValue = value as? Int {
                    self.data.updater.update(progress: newValue)
                    self.reloadData()
                }
            }, cancel: { _ in }, origin: cell)
            
            break
            
        case .status:
            
            let statuses = LibraryEntry.Status.all
            let rows: [String] = statuses.map {
                if let media = entry.media {
                    return $0.toString(forMedia: media.type)
                }
                
                return "-"
            }
            
            let initial = statuses.index(of: entry.status ?? .current) ?? 0
            ActionSheetStringPicker.show(withTitle: "Status", rows: rows, initialSelection: initial, doneBlock: { picker, index, value in
                self.data.updater.update(status: statuses[index])
                self.reloadData()
            }, cancel: { _ in }, origin: cell)
            
            break
            
        case .rating:
            
            let ratings = Array(stride(from: 0, to: 5.5, by: 0.5))
            let initial = ratings.index(of: entry.rating) ?? 0
            
            //Format it to 1 decimal place display so it's consitent
            let rows = ratings.map { String(format: "%.1f", $0) }
            
            ActionSheetStringPicker.show(withTitle: "Rating", rows: rows, initialSelection: initial, doneBlock: { picker, index, value in
                
                //We know that we will have 10 values, so to get the rating just divide by 2
                self.data.updater.update(rating: Double(index) / 2)
                self.reloadData()
            }, cancel: { _ in }, origin: cell)
            
            break
            
        case .notes:
            
            let editingVC = TextEditingViewController(title: "Notes", text: entry.notes, placeholder: "Type your notes here!")
            editingVC.modalPresentationStyle = .overCurrentContext
            editingVC.delegate = self
            present(editingVC, animated: false)
            
            break
            
        case .reconsumeCount:
            let rows = Array(0...999)
            ActionSheetStringPicker.show(withTitle: "Reconsume Count", rows: rows, initialSelection: entry.reconsumeCount, doneBlock: { picker, index, value in
                if let newValue = value as? Int {
                    self.data.updater.update(reconsumeCount: newValue)
                    self.reloadData()
                }
            }, cancel: { _ in }, origin: cell)
            break
            
        case .reconsuming:
            //Just invert the value
            self.data.updater.update(reconsuming: !entry.reconsuming)
            self.reloadData()
            break
            
        case .isPrivate:
            self.data.updater.update(isPrivate: !entry.isPrivate)
            self.reloadData()
            break
        }
        
    }
}

//MARK:- EntryMediaHeaderViewDelegate & Entry Button Delegate
extension LibraryEntryViewController: EntryMediaHeaderViewDelegate, EntryButtonDelegate {
    func didTapMediaButton() {
        
    }
    
    //+1 button tapped
    func didTapButton(inCell: EntryButtonTableViewCell, indexPath: IndexPath?) {
        if let indexPath = indexPath {
            let tableData = self.data.tableData()
            let d = tableData[indexPath.row]
            
            //Update the values accordingly
            switch d.heading {
            case .progress:
                data.updater.incrementProgress()
                break
            case .reconsumeCount:
                data.updater.incrementReconsumeCount()
                break
                
            default:
                break
            }
            
            self.reloadData()
        }
    }
}

extension LibraryEntryViewController: TextEditingViewControllerDelegate {
    func textEditingViewController(_ controller: TextEditingViewController, didSave text: String) {
        data.updater.update(notes: text)
        self.reloadData()
    }
}

//Mark:- Entry saving
extension LibraryEntryViewController {
    
    func showIndicator() {
        UIView.animate(withDuration: 0.25) {
            self.activityIndicator.startAnimating()
            self.darkOverlay.isHidden = false
            self.navigationController?.navigationBar.isUserInteractionEnabled = false
            self.saveBarButton?.isEnabled = false
            self.clearBarButton?.isEnabled = false
        }
    }
    
    func hideIndicator() {
        UIView.animate(withDuration: 0.25) {
            self.activityIndicator.stopAnimating()
            self.darkOverlay.isHidden = true
            self.navigationController?.navigationBar.isUserInteractionEnabled = true
            self.saveBarButton?.isEnabled = true
            self.clearBarButton?.isEnabled = true
        }
    }
    
    //Save was tapped
    func didSave() {
        showIndicator()
        data.updater.save { error in
            self.hideIndicator()
            guard error == nil else {
                
                //Show an alert to the user
                let alert = UIAlertController(title: "Error", message: "\(error!.localizedDescription). Please try again.", preferredStyle: .alert)
                let action = UIAlertAction(title: "Ok", style: .cancel, handler: { _ in
                    alert.dismiss(animated: true)
                })
                
                alert.addAction(action)
                
                //Present the alert if we haven't
                if self.presentedViewController == nil {
                    self.present(alert, animated: true)
                }
                
                print(error!.localizedDescription)
                
                return
            }
            
            let _ = self.navigationController?.popViewController(animated: true)
            
        }
    }
    
    func didClear() {
        data.updater.reset()
        self.reloadData()
    }
}
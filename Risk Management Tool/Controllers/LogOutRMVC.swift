//
//  LogOutRMVC.swift
//  Risk Management Tool
//
//  Created by Nikitinho on 17/03/2019.
//  Copyright © 2019 Nikitinho. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class LogOutRMVC: UIViewController, UITableViewDelegate, UITableViewDataSource, RiskCellDelegator {
    
    @IBOutlet weak var logOutButton: UIBarButtonItem!
    private let pullToRefresh = UIRefreshControl()
    let searchController = UISearchController(searchResultsController: nil)
    
    var tableView:UITableView!
    
    var risks = [Risk]()
    var filteredRisks = [Risk]()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchRisks()
    }
    
    func dispatchDelay(delay:Double, closure:@escaping ()->()) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay, execute: closure)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Risks"
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        self.tabBarController?.tabBar.isHidden = true
        
        logOutButton.target = self;
        logOutButton.action = #selector(self.onLogOutAction(_sender:))
        
        tableView = UITableView(frame: view.bounds, style: .plain)
        
        let cellNib = UINib(nibName: "RiskTableViewCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "riskCell")
        view.addSubview(tableView)
        
        var layoutGuide:UILayoutGuide!
        
        if #available(iOS 10, *) {
            tableView.refreshControl = pullToRefresh
        } else {
            tableView.addSubview(pullToRefresh)
        }
        
        if #available(iOS 11.0, *) {
            layoutGuide = view.safeAreaLayoutGuide
        } else {
            layoutGuide = view.layoutMarginsGuide
        }
        
        pullToRefresh.addTarget(self,  action: #selector(onRefreshAction(_:)), for: .valueChanged)
        
        self.tableViewConstraintFix(tableView, layoutGuide)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        
        fetchRisks()
    }
    
    @objc private func onRefreshAction(_ sender: Any) {
        fetchRisks()
        dispatchDelay(delay: 3.0) {
            self.pullToRefresh.endRefreshing()
        }
    }
    
    @objc func onLogOutAction(_sender:UIButton!)
    {
        do{
            try FIRAuth.auth()?.signOut()
        } catch {
            print (error)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredRisks.count
        }
        
        return risks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "riskCell", for: indexPath) as! RiskTableViewCell
        if isFiltering() {
            cell.set(risk: filteredRisks[indexPath.row])
        } else {
            cell.set(risk: risks[indexPath.row])
        }
        cell.delegate = self
        return cell
    }
    
    func callSegueFromCell(_ sender: RiskTableViewCell) {
        guard let tappedIndexPath = tableView.indexPath(for: sender) else { return }
        let indexPath = IndexPath(row: tappedIndexPath.row, section: 0)
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableView.ScrollPosition.middle)
        let riskViewController = self.storyboard?.instantiateViewController(withIdentifier: "RiskVC") as! RiskVC
        if isFiltering() {
            let chosenRisk = filteredRisks[tappedIndexPath.row]
            riskViewController.riskAnalysis = chosenRisk.risksLevel
            riskViewController.riskTitle = chosenRisk.title
            riskViewController.riskDescription = chosenRisk.description
            riskViewController.riskAuthor = chosenRisk.author.username
            riskViewController.imageURL = chosenRisk.author.photoURL
            
            self.navigationController?.pushViewController(riskViewController, animated: true)
        } else {
            let chosenRisk = risks[tappedIndexPath.row]
            riskViewController.riskAnalysis = chosenRisk.risksLevel
            riskViewController.riskTitle = chosenRisk.title
            riskViewController.riskDescription = chosenRisk.description
            riskViewController.riskAuthor = chosenRisk.author.username
            riskViewController.imageURL = chosenRisk.author.photoURL
        
            self.navigationController?.pushViewController(riskViewController, animated: true)
        }
    }
    
    func fetchRisks() {
        let riskRef = FIRDatabase.database().reference().child("risks")
        let queryRef = riskRef.queryOrdered(byChild: "timestamp")
        
        queryRef.observeSingleEvent(of: .value, with: { snapshot in
            
            var tempRisks = [Risk]()
            
            for child in snapshot.children {
                if let childSnapshot = child as? FIRDataSnapshot,
                let dict = childSnapshot.value as? [String:Any],
                let author = dict["author"] as? [String:Any],
                let uid = author["uid"] as? String,
                let username = author["username"] as? String,
                let photoURL = author["photoURL"] as? String,
                let url = URL(string:photoURL),
                let title = dict["title"] as? String,
                let description = dict["description"] as? String,
                let confidentiality = dict["confidentiality"] as? Int,
                let integrity = dict["integrity"] as? Int,
                let availability = dict["availability"] as? Int,
                let threats = dict["additionalParameters"] as? [String:[String: Int]],
                let timestamp = dict["timestamp"] as? Double {
                    let userProfile = UserProfile(uid: uid, username: username, photoURL: url)
                    let risk = Risk(id: childSnapshot.key, author: userProfile, title: title, description: description, timestamp: timestamp, confidentiality: confidentiality, integrity: integrity, availability: availability)
                    risk.addThreats(threats: threats)
                    risk.calculateRisksLevel()
                    tempRisks.insert(risk, at: 0)
                }
            }
            
            self.risks = tempRisks
            self.tableView.reloadData()
        })
    }
    
    func tableViewConstraintFix(_ tableView: UITableView, _ layoutGuide: UILayoutGuide) {
        tableView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
    }
    
    func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredRisks = risks.filter({( risk : Risk) -> Bool in
            return risk.title.lowercased().contains(searchText.lowercased())
        })
        
        tableView.reloadData()
    }
    
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
}

extension LogOutRMVC: UISearchResultsUpdating {
    // MARK: - UISearchResultsUpdating Delegate
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
}

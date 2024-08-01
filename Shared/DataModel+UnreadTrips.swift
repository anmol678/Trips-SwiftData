/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An exention of DataModel that provides supports for unread trips.
*/

import SwiftUI
import SwiftData

extension DataModel {
    struct UserDefaultsKey {
        static let unreadTripIdentifiers = "unreadTripIdentifiers"
        static let historyToken = "historyToken"
    }
    /**
     Getter and setter of the unread trip identifiers in the standard `UserDefaults`. This makes the identifiers avaiable for the next launch session.
     DataModel is isolated, and `setUnreadTripIdentifiersInUserDefaults` provides a way to set the value using `await`.
     */
    var unreadTripIdentifiersInUserDefaults: [PersistentIdentifier] {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKey.unreadTripIdentifiers) else {
            return []
        }
        let tripIdentifers = try? JSONDecoder().decode([PersistentIdentifier].self, from: data)
        return tripIdentifers ?? []
    }
    
    func setUnreadTripIdentifiersInUserDefaults(_ newValue: [PersistentIdentifier]) {
        let data = try? JSONEncoder().encode(newValue)
        UserDefaults.standard.set(data, forKey: UserDefaultsKey.unreadTripIdentifiers)
    }

    /**
     Find the unread trip identifiers by parsing the history.
     */
    func findUnreadTripIdentifiers() -> [PersistentIdentifier] {
        let unreadTrips = findUnreadTrips()
        return Array(unreadTrips).map { $0.persistentModelID }
    }
    
    private func findUnreadTrips() -> Set<Trip> {
        let tokenData = UserDefaults.standard.data(forKey: UserDefaultsKey.historyToken)
        
        var historyToken: DefaultHistoryToken? = nil
        if let data = tokenData {
            historyToken = try? JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        }
        let transactions = findTransactions(after: historyToken, author: TransactionAuthor.widget)
        let (unreadTrips, newToken) = findTrips(in: transactions)
        
        if let token = newToken {
            let newTokenData = try? JSONEncoder().encode(token)
            UserDefaults.standard.set(newTokenData, forKey: UserDefaultsKey.historyToken)
        }
        return unreadTrips
    }
    
    private func findTransactions(after historyToken: DefaultHistoryToken?, author: String) -> [DefaultHistoryTransaction] {
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token = historyToken {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token) && (transaction.author == author)
            }
        }
        var transactions: [DefaultHistoryTransaction] = []
        let taskContext = ModelContext(modelContainer)
        do {
            transactions = try taskContext.fetchHistory(historyDescriptor)
        } catch let error {
            print(error)
        }
        return transactions
    }
    
    private func findTrips(in transactions: [DefaultHistoryTransaction]) -> (Set<Trip>, DefaultHistoryToken?) {
        let taskContext = ModelContext(modelContainer)
        var resultTrips: Set<Trip> = []
        for transaction in transactions {
            for change in transaction.changes {
                let modelID = change.changedPersistentIdentifier
                let fetchDescriptor = FetchDescriptor<Trip>(predicate: #Predicate { trip in
                    trip.livingAccommodation?.persistentModelID == modelID
                })
                let fetchResults = try? taskContext.fetch(fetchDescriptor)
                guard let matchedTrip = fetchResults?.first else {
                    continue
                }
                switch change {
                    case is any HistoryInsert<LivingAccommodation>:
                    resultTrips.insert(matchedTrip)
                    case is any HistoryUpdate<LivingAccommodation>:
                    resultTrips.update(with: matchedTrip)
                    case is any HistoryDelete<LivingAccommodation>:
                    resultTrips.remove(matchedTrip)
                default:
                    break
                }
            }
        }
        return (resultTrips, transactions.last?.token)
    }
}

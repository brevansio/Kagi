//
//  IAPManager.swift
//  Kagi
//
//  Created by Bruce Evans on 2020/07/05.
//  Copyright © 2020 Self. All rights reserved.
//

import Foundation
import StoreKit

enum PurchaseID: String, CaseIterable {
    case coffee = "io.brevans.kagi.coffee"
    case lunch = "io.brevans.kagi.lunch"

    var thankYouString: String {
        switch self {
        case .coffee:
            return NSLocalizedString("Thanks for the coffee!", comment: "")
        case .lunch:
            return NSLocalizedString("Thanks for lunch!", comment: "")
        }
    }
}

class IAPManager: NSObject {
    @objc static let shared = IAPManager()

    private var productRequest: SKProductsRequest?
    var products = [SKProduct]()
    var transactionCallback: ((PurchaseID?, Bool) -> Void)?

    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    @objc func requestProducts() {
        guard productRequest == nil else { return }
        productRequest = SKProductsRequest(productIdentifiers: Set(PurchaseID.allCases.map { $0.rawValue }))
        productRequest?.delegate = self
        productRequest?.start()
    }

    @objc func buy(product: SKProduct) {
        guard products.contains(product) else { return }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    @objc func enableIAP() -> Bool {
        SKPaymentQueue.canMakePayments()
    }
}

extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products = response.products
    }
}

extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach { transation in
            switch transation.transactionState {
            case .purchased, .restored:
                transactionCallback?(PurchaseID(rawValue: transation.payment.productIdentifier), true)
                SKPaymentQueue.default().finishTransaction(transation)
            case .failed:
                transactionCallback?(PurchaseID(rawValue: transation.payment.productIdentifier), false)
                SKPaymentQueue.default().finishTransaction(transation)
            case .deferred, .purchasing:
                // Do Nothing
                break
            @unknown default:
                break
            }
        }
    }
}



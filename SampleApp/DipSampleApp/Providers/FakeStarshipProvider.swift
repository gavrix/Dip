//
//  FakeStarshipProvider.swift
//  DipSampleApp
//
//  Created by Ilya Puchka on 20.01.16.
//  Copyright © 2016 AliSoftware. All rights reserved.
//

import Foundation

///Provides some dummy Starship entities
struct DummyStarshipProvider : StarshipProviderAPI {
    var pilotName: String
    
    func fetchIDs(completion: [Int] -> Void) {
        let nbShips = pilotName.characters.count
        completion(Array(0..<nbShips))
    }
    
    func fetch(id: Int, completion: Starship? -> Void) {
        completion(dummyStarship(id))
    }
    
    private func dummyStarship(idx: Int) -> Starship {
        return Starship(
            name: "\(pilotName)'s awesome starship #\(idx)",
            model: "\(pilotName)Ship",
            manufacturer: "Dummy Industries",
            crew: 1 + (idx%3),
            passengers: 10 + (idx*7 % 40),
            pilotIDs: [idx]
        )
    }
}

///Provides hardcoded Starship entities stored in memory
class HardCodedStarshipProvider : StarshipProviderAPI {
    
    let starships = [
        Starship(name: "First Ship", model: "AwesomeShip", manufacturer: "HardCoded Inc.", crew: 3, passengers: 20, pilotIDs: [1,2]),
        Starship(name: "Second Ship", model: "AwesomeShip Express", manufacturer: "HardCoded Inc.", crew: 4, passengers: 10, pilotIDs: [1]),
        Starship(name: "Third Ship", model: "AwesomeShip Cargo", manufacturer: "HardCoded Inc.", crew: 12, passengers: 150, pilotIDs: [2]),
        ] + Array(4..<75).map { Starship(name: "Ship #\($0)", model: "AwesomeShip Fighter", manufacturer: "HardCoded Inc.", crew: 1, passengers: 2, pilotIDs: [1]) }
    
    func fetchIDs(completion: [Int] -> Void) {
        completion(Array(0..<starships.count))
    }
    
    func fetch(id: Int, completion: Starship? -> Void) {
        guard id < starships.count else {
            completion(nil)
            return
        }
        completion(starships[id])
    }
}

class FakeStarshipProvider: StarshipProviderAPI {
    
    let dummyProvider: StarshipProviderAPI
    let hardCodedProvider: StarshipProviderAPI
    
    //Constructor injection again here
    init(dummyProvider: StarshipProviderAPI, hardCodedProvider: StarshipProviderAPI) {
        self.dummyProvider = dummyProvider
        self.hardCodedProvider = hardCodedProvider
    }
    
    func fetchIDs(completion: [Int] -> Void) {
        hardCodedProvider.fetchIDs(completion)
    }
    
    func fetch(id: Int, completion: Starship? -> Void) {
        if id == 0 {
            dummyProvider.fetch(id, completion: completion)
        }
        else {
            hardCodedProvider.fetch(id, completion: completion)
        }
    }
    
}



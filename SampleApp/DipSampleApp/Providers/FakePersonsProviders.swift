//
//  PlistPersonProvider.swift
//  Dip
//
//  Created by Ilya Puchka on 12/09/2015.
//  Copyright © 2015 AliSoftware. All rights reserved.
//

import Foundation

///Provides some dummy Person entities
struct DummyPilotProvider : PersonProviderAPI {
    
    func fetchIDs(completion: [Int] -> Void) {
        completion(Array(0..<5))
    }
    
    func fetch(id: Int, completion: Person? -> Void) {
        completion(dummyPerson(id))
    }
    
    private func dummyPerson(idx: Int) -> Person {
        let colors = ["blue", "brown", "yellow", "orange", "red", "dark"]
        let genders: [Gender?] = [Gender.Male, Gender.Female, nil]
        return Person(
            name: "John Dummy Doe #\(idx)",
            height: 150 + (idx*27%40),
            mass: 50 + (idx*7%30),
            hairColor: colors[idx*3%colors.count],
            eyeColor: colors[idx*2%colors.count],
            gender: genders[idx%3],
            starshipIDs: [idx % 3, 2*idx % 4]
        )
    }
}

///Provides Person entities reading then from plist file
class PlistPersonProvider : PersonProviderAPI {
    let people: [Person]
    
    init(plist basename: String) {
        guard
            let path = NSBundle.mainBundle().pathForResource(basename, ofType: "plist"),
            let list = NSArray(contentsOfFile: path),
            peopleDict = list as? [[String:AnyObject]]
            else {
                fatalError("PLIST for \(basename) not found")
        }
        
        self.people = peopleDict.map(PlistPersonProvider.personFromDict)
    }
    
    func fetchIDs(completion: [Int] -> Void) {
        completion(Array(0..<people.count))
    }
    
    func fetch(id: Int, completion: Person? -> Void) {
        guard id < people.count else {
            completion(nil)
            return
        }
        completion(people[id])
    }
    
    private static func personFromDict(dict: [String:AnyObject]) -> Person {
        guard
            let name = dict["name"] as? String,
            height = dict["height"] as? Int,
            mass = dict["mass"] as? Int,
            hairColor = dict["hairColor"] as? String,
            eyeColor = dict["eyeColor"] as? String,
            genderStr = dict["gender"] as? String,
            starshipsIDs = dict["starships"] as? [Int]
            else {
                fatalError("Invalid Plist")
        }
        
        return Person(
            name: name,
            height: height,
            mass: mass,
            hairColor: hairColor,
            eyeColor: eyeColor,
            gender: Gender(rawValue: genderStr),
            starshipIDs: starshipsIDs
        )
    }
}

class FakePersonsProvider: PersonProviderAPI {
    
    let dummyProvider: PersonProviderAPI
    var plistProvider: PersonProviderAPI!
    
    //In this class we use both constructor injection and property injection,
    //nil is a valid local default
    init(dummyProvider: PersonProviderAPI) {
        self.dummyProvider = dummyProvider
    }
    
    func fetchIDs(completion: [Int] -> Void) {
        dummyProvider.fetchIDs(completion)
    }
    
    func fetch(id: Int, completion: Person? -> Void) {
        if let plistProvider = plistProvider where id == 0 {
            plistProvider.fetch(id, completion: completion)
        }
        else {
            dummyProvider.fetch(id, completion: completion)
        }
    }

}

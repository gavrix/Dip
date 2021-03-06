//
// Dip
//
// Copyright (c) 2015 Olivier Halligon <olivier@halligon.net>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import XCTest
@testable import Dip

protocol Service: class {
  func getServiceName() -> String
}

extension Service {
  func getServiceName() -> String {
    return "\(self.dynamicType)"
  }
}

class ServiceImp1: Service {
}

class ServiceImp2: Service {
}

class DipTests: XCTestCase {
  
  let container = DependencyContainer()
  
  override func setUp() {
    super.setUp()
    container.reset()
  }
  
  func testThatItResolvesInstanceRegisteredWithoutTag() {
    //given
    container.register { ServiceImp1() as Service }
    
    //when
    let serviceInstance = try! container.resolve() as Service
    
    //then
    XCTAssertTrue(serviceInstance is ServiceImp1)
  }
  
  func testThatItResolvesInstanceRegisteredWithTag() {
    //given
    container.register(tag: "service") { ServiceImp1() as Service }
    
    //when
    let serviceInstance = try! container.resolve(tag: "service") as Service
    
    //then
    XCTAssertTrue(serviceInstance is ServiceImp1)
  }
  
  func testThatItResolvesDifferentInstancesRegisteredForDifferentTags() {
    //given
    container.register(tag: "service1") { ServiceImp1() as Service }
    container.register(tag: "service2") { ServiceImp2() as Service }
    
    //when
    let service1Instance = try! container.resolve(tag: "service1") as Service
    let service2Instance = try! container.resolve(tag: "service2") as Service
    
    //then
    XCTAssertTrue(service1Instance is ServiceImp1)
    XCTAssertTrue(service2Instance is ServiceImp2)
  }
  
  func testThatNewRegistrationOverridesPreviousRegistration() {
    //given
    container.register { ServiceImp1() as Service }
    let service1 = try! container.resolve() as Service
    
    //when
    container.register { ServiceImp2() as Service }
    let service2 = try! container.resolve() as Service
    
    //then
    XCTAssertTrue(service1 is ServiceImp1)
    XCTAssertTrue(service2 is ServiceImp2)
  }
  
  func testThatItCallsResolveDependenciesOnDefinition() {
    //given
    var resolveDependenciesCalled = false
    container.register { ServiceImp1() as Service }.resolveDependencies { (c, s) in
      resolveDependenciesCalled = true
    }
    
    //when
    try! container.resolve() as Service
    
    //then
    XCTAssertTrue(resolveDependenciesCalled)
  }
  
  func testThatItThrowsErrorIfCanNotFindDefinitionForType() {
    //given
    container.register { ServiceImp1() as ServiceImp1 }
    
    //when
    do {
      try container.resolve() as Service
      XCTFail("Unexpectedly resolved protocol")
    }
    catch let DipError.DefinitionNotFound(key) {
      //then
      typealias F = () throws -> Service
      let expectedKey = DefinitionKey(protocolType: Service.self, factoryType: F.self, associatedTag: nil)
      XCTAssertEqual(key, expectedKey)
    }
    catch {
      XCTFail("Thrown unexpected error")
    }
  }
  
  func testThatItThrowsErrorIfCanNotFindDefinitionForTag() {
    //given
    container.register(tag: "some tag") { ServiceImp1() as Service }
    
    //when
    do {
      try container.resolve(tag: "other tag") as Service
      XCTFail("Unexpectedly resolved protocol")
    }
    catch let DipError.DefinitionNotFound(key) {
      //then
      typealias F = () throws -> Service
      let expectedKey = DefinitionKey(protocolType: Service.self, factoryType: F.self, associatedTag: "other tag")
      XCTAssertEqual(key, expectedKey)
    }
    catch {
      XCTFail("Thrown unexpected error")
    }
  }
  
  func testThatItThrowsErrorIfCanNotFindDefinitionForFactoryWithArguments() {
    //given
    container.register { ServiceImp1() as Service }
    
    //when
    do {
      try container.resolve(withArguments: "some string") as Service
      XCTFail("Unexpectedly resolved protocol")
    }
    catch let DipError.DefinitionNotFound(key) {
      //then
      typealias F = (String) throws -> Service
      let expectedKey = DefinitionKey(protocolType: Service.self, factoryType: F.self, associatedTag: nil)
      XCTAssertEqual(key, expectedKey)
    }
    catch {
      XCTFail("Thrown unexpected error")
    }
  }
  
  func testThatItThrowsErrorIfConstructorThrows() {
    //given
    let failedKey = DefinitionKey(protocolType: Any.self, factoryType: Any.self)
    let expectedError = DipError.DefinitionNotFound(key: failedKey)
    container.register { () throws -> Service in throw expectedError }
    
    //when
    do {
      try container.resolve() as Service
    }
    catch let DipError.ResolutionFailed(key, error) {
      //then
      typealias F = () throws -> Service
      let expectedKey = DefinitionKey(protocolType: Service.self, factoryType: F.self)
      XCTAssertEqual(key, expectedKey)
      
      switch error {
      case let DipError.DefinitionNotFound(subKey) where subKey == failedKey:
        break
      default:
        XCTFail()
      }
    }
    catch {
      XCTFail("Thrown unexpected error")
    }
  }
  
  func testThatItThrowsErrorIfFailsToResolveDependency() {
    //given
    let failedKey = DefinitionKey(protocolType: Any.self, factoryType: Any.self)
    let expectedError = DipError.DefinitionNotFound(key: failedKey)
    container.register { ServiceImp1() as Service }
      .resolveDependencies { container, service in
        //simulate throwing error when resolving dependency
        throw expectedError
    }
    
    //when
    do {
      try container.resolve() as Service
    }
    catch let DipError.ResolutionFailed(key, error) {
      //then
      typealias F = () throws -> Service
      let expectedKey = DefinitionKey(protocolType: Service.self, factoryType: F.self)
      XCTAssertEqual(key, expectedKey)
      
      switch error {
      case let DipError.DefinitionNotFound(subKey) where subKey == failedKey:
        break
      default:
        XCTFail()
      }
    }
    catch {
      XCTFail("Thrown unexpected error")
    }
  }
  
}

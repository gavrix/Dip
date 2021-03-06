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

private protocol Server: class {
  weak var client: Client? {get}
  var anotherClient: Client? {get set}
  var optionalClient: AnyObject? {get}
}

private protocol Client: class {
  var server: Server? {get}
  var anotherServer: Server? {get set}
  var optionalServer: AnyObject? {get}
}

class AutoInjectionTests: XCTestCase {
  
  static var serverDeallocated: Bool = false
  static var clientDeallocated: Bool = false
  
  static var serverDidInjectCalled: Bool = false
  static var clientDidInjectCalled: Bool = false

  private class ServerImp: Server {
    
    deinit {
      AutoInjectionTests.serverDeallocated = true
    }
    
    var _client = InjectedWeak<Client>() { _ in
      AutoInjectionTests.clientDidInjectCalled = true
    }
    
    weak var client: Client? {
      return _client.value
    }
    
    weak var anotherClient: Client?
    
    weak var _optionalClient = InjectedWeak<AnyObject>(required: false)
    var optionalClient: AnyObject? { return _optionalClient?.value }
  }
  
  private class ClientImp: Client {
    
    deinit {
      AutoInjectionTests.clientDeallocated = true
    }
    
    var _server = Injected<Server>() { _ in
      AutoInjectionTests.serverDidInjectCalled = true
    }
    
    var anotherServer: Server?
    
    var _optionalServer = Injected<AnyObject>(required: false)
    
    var optionalServer: AnyObject? { return _optionalServer.value }
    
    var server: Server? {
      return _server.value
    }
    
    var taggedServer = Injected<Server>(tag: "tagged")

  }

  let container = DependencyContainer()
  
  override func setUp() {
    super.setUp()

    container.reset()
    AutoInjectionTests.serverDeallocated = false
    AutoInjectionTests.clientDeallocated = false
    AutoInjectionTests.clientDidInjectCalled = false
    AutoInjectionTests.serverDidInjectCalled = false
  }

  func testThatItResolvesAutoInjectedDependencies() {
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }
    
    let client = try! container.resolve() as Client
    let server = client.server
    XCTAssertTrue(client === server?.client)
  }
  
  func testThatItThrowsErrorIfFailsToInjectDependency() {
    container.register(.ObjectGraph) { ClientImp() as Client }
    
    do {
      try container.resolve() as Client
      XCTFail("Resolve should throw error")
    }
    catch { }
  }

  func testThatThereIsNoRetainCycleForCyrcularDependencies() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }

    var client: Client? = try! container.resolve() as Client
    XCTAssertNotNil(client)
    
    //when
    client = nil
    
    //then
    XCTAssertTrue(AutoInjectionTests.clientDeallocated)
    XCTAssertTrue(AutoInjectionTests.serverDeallocated)
  }
  
  func testThatItResolvesAutoInjectedSingletons() {
    //given
    container.register(.Singleton) { ServerImp() as Server }
    container.register(.Singleton) { ClientImp() as Client }
    
    //when
    let sharedClient = try! container.resolve() as Client
    let sharedServer = try! container.resolve() as Server

    let client = try! container.resolve() as Client
    let server = client.server
    
    //then
    XCTAssertTrue(client === sharedClient)
    XCTAssertTrue(client === server?.client)
    XCTAssertTrue(server === sharedServer)
  }
  
  func testThatItCallsResolveDependencyBlockOnOriginalDefiniton() {
    var serverBlockWasCalled = false
    
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
      .resolveDependencies { (container, server) -> () in
        serverBlockWasCalled = true
    }

    var clientBlockWasCalled = false
    container.register(.ObjectGraph) { ClientImp() as Client }
      .resolveDependencies { (container, client) -> () in
        clientBlockWasCalled = true
    }

    //when
    try! container.resolve() as Client
    XCTAssertTrue(serverBlockWasCalled)
    
    try! container.resolve() as Server
    XCTAssertTrue(clientBlockWasCalled)
  }
  
  func testThatItReusesResolvedAutoInjectedInstances() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
      .resolveDependencies { (container, server) -> () in
        server.anotherClient = try! container.resolve() as Client
    }

    container.register(.ObjectGraph) { ClientImp() as Client }
      .resolveDependencies { (container, client) -> () in
        client.anotherServer = try! container.resolve() as Server
    }

    //when
    let client = try! container.resolve() as Client
    
    //then
    let server = client.server
    let anotherServer = client.anotherServer
    
    XCTAssertTrue(server === anotherServer)
    
    let oneClient = server!.client
    let anotherClient = server!.anotherClient
    
    XCTAssertTrue(oneClient === anotherClient)
    XCTAssertTrue(client === anotherClient)
  }
  
  func testThatItReusesAutoInjectedInstancesOnNextResolveOrAutoInjection() {
    //given
    class Obj1 {
      let obj2 = InjectedWeak<Obj2>()
      let obj3 = Injected<Obj3>()
    }
    
    class Obj2 {
      let obj1 = Injected<Obj1>()
    }
    
    class Obj3 {
      
      weak var obj1: Obj1?
      
      init(obj: Obj1) {
        self.obj1 = obj
      }
    }
    
    container.register(.ObjectGraph) { Obj1() }
    container.register(.ObjectGraph) { Obj2() }
    container.register(.ObjectGraph) { Obj3(obj: try self.container.resolve()) }
    
    //when
    let obj2 = try! container.resolve() as Obj2
    
    //then
    XCTAssertTrue(obj2 === obj2.obj1.value!.obj2.value!,
      "Auto-injected instance should be reused on next auto-injection")
    
    XCTAssertTrue(obj2.obj1.value! === obj2.obj1.value!.obj3.value!.obj1,
      "Auto-injected instance should be reused on next resolve")
  }
  
  func testThatThereIsNoRetainCycleBetweenAutoInjectedCircularDependencies() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }

    //when
    var client: Client? = try! container.resolve() as Client
    
    //then
    weak var server: Server? = client?.server
    weak var weakClient = client
    
    XCTAssertNotNil(weakClient)
    XCTAssertNotNil(server)
    
    client = nil

    XCTAssertNil(weakClient)
    XCTAssertNil(server)
  }
  
  func testThatItCallsDidInjectOnAutoInjectedProperty() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }
    
    //when
    try! container.resolve() as Client
    
    //then
    XCTAssertTrue(AutoInjectionTests.clientDidInjectCalled)
    XCTAssertTrue(AutoInjectionTests.serverDidInjectCalled)
  }
  
  func testThatNoErrorThrownWhenOptionalPropertiesAreNotAutoInjected() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }

    do {
      //when
      try container.resolve() as Client
    }
    catch {
      //then
      XCTFail("Container should not throw error if failed to resolve optional auto-injected properties.")
    }
  }
  
  func testThatItResolvesAutoInjectedTaggedDependencies() {
    //given
    container.register(.ObjectGraph) { ServerImp() as Server }
    container.register(tag: "tagged", .ObjectGraph) { ServerImp() as Server }
    container.register(.ObjectGraph) { ClientImp() as Client }
    
    //when
    let client = try! container.resolve() as Client
    
    //then
    let taggedServer = (client as! ClientImp).taggedServer.value!
    let server = client.server!
    
    //server and tagged server should be resolved as different instances
    XCTAssertTrue(server !== taggedServer)
  }
  
}




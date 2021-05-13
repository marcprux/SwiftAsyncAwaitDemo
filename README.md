footer: async/await demo: [https://github.com/marcprux/SwiftAsyncAwaitDemo](https://github.com/marcprux/SwiftAsyncAwaitDemo)
autoscale: true

# Async/Await

## Marc Prud'hommeaux
## marc@glimpse.io
### CocoaHeads Boston, May 2021


---

# Running the Sample Project

• Environment: macOS 11.3 & Xcode 12.5

• Install and activate [Swift 5.5 Development](https://swift.org/builds/swift-5.5-branch/xcode/swift-5.5-DEVELOPMENT-SNAPSHOT-2021-04-19-a/swift-5.5-DEVELOPMENT-SNAPSHOT-2021-04-19-a-osx.pkg) toolchain from [https://swift.org/download](https://swift.org/download)

• [https://github.com/marcprux/SwiftAsyncAwaitDemo](https://github.com/marcprux/SwiftAsyncAwaitDemo)

• Open Package.swift in Xcode[^1] and run tests

[^1]: note Package.swift build flag: `-Xfrontend -enable-experimental-concurrency`

---

# The World of Swift Concurrency [^2]

![inline](https://desiatov.com/static/SwiftConcurrencyDependencies-dd58811a6b3b7d7f21b03f64b5dea026-a2a6f.png)

[^2]: Image: [https://desiatov.com/swift-structured-concurrency-introduction/](https://desiatov.com/swift-structured-concurrency-introduction/)


---

**SE-0296: Async/await**
*Status: Implemented (Swift 5.5)*
[https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)


**SE-0297: Concurrency Interoperability with Objective-C**
*Status: Implemented (Swift 5.5)*
[https://github.com/apple/swift-evolution/blob/main/proposals/0297-concurrency-objc.md#introduction](https://github.com/apple/swift-evolution/blob/main/proposals/0297-concurrency-objc.md#introduction)

---

# Swift 5.5

• Swift 5.4 was released on April 26[^3] 

• Next minor version typically in Fall (iOS 15?)

• __*Appears*__ to be backwards-compatible



[^3]: [https://swift.org/blog/swift-5-4-released/](https://swift.org/blog/swift-5-4-released/)

---


# Part 1: Async/await

* Proposal: [SE-0296](0296-async-await.md)
* Authors: [John McCall](https://github.com/rjmccall), [Doug Gregor](https://github.com/DougGregor)
* Review Manager: [Ben Cohen](https://github.com/airspeedswift)
* Status: **Implemented (Swift 5.5)**
* Implementation: Available in [recent `main` snapshots](https://swift.org/download/#snapshots) behind the flag `-Xfrontend -enable-experimental-concurrency`
* Decision Notes: [Rationale](https://forums.swift.org/t/accepted-with-modification-se-0296-async-await/43318)

---

## Introduction

• Swift async/await introduces a [coroutine model](https://en.wikipedia.org/wiki/Coroutine) to Swift. 
• Functions can opt into being `async`, allowing the programmer to compose complex logic involving asynchronous operations using the normal control-flow mechanisms. 
• The compiler is responsible for translating an asynchronous function into an appropriate set of closures and state machines.

---

## async & Concurrency

This proposal defines the semantics of asynchronous functions. However, it does not provide concurrency: that is covered by a separate proposal to introduce structured concurrency, which associates asynchronous functions with concurrently-executing tasks and provides APIs for creating, querying, and cancelling tasks.

Swift-evolution thread: [Pitch #1](https://forums.swift.org/t/concurrency-asynchronous-functions/41619), [Pitch #2](https://forums.swift.org/t/pitch-2-async-await/42420)

---

## Motivation: Completion handlers are suboptimal

Async programming with explicit callbacks (also called completion handlers) has many problems, which we’ll explore below.  We propose to address these problems by introducing async functions into the language.  Async functions allow asynchronous code to be written as straight-line code.  They also allow the implementation to directly reason about the execution pattern of the code, allowing callbacks to run far more efficiently.

---

#### Problem 1: Pyramid of doom

```swift
func processImageData1(completionBlock: (_ result: Image) -> Void) {
    loadWebResource("dataprofile.txt") { dataResource in
        loadWebResource("imagedata.dat") { imageResource in
            decodeImage(dataResource, imageResource) { imageTmp in
                dewarpAndCleanupImage(imageTmp) { imageResult in
                    completionBlock(imageResult)
                }
            }
        }
    }
}

processImageData1 { image in
    display(image)
}
```

---


```swift
// Error handling with (success?, failure?) tuple callback
// (2a) Using a `guard` statement for each callback:
func processImageData2a(completionBlock: (_ result: Image?, _ error: Error?) -> Void) {
    loadWebResource("dataprofile.txt") { dataResource, error in
        guard let dataResource = dataResource else {
            completionBlock(nil, error)
            return
        }
        loadWebResource("imagedata.dat") { imageResource, error in
            guard let imageResource = imageResource else {
                completionBlock(nil, error)
                return
            }
            decodeImage(dataResource, imageResource) { imageTmp, error in
                guard let imageTmp = imageTmp else {
                    completionBlock(nil, error)
                    return
                }
                dewarpAndCleanupImage(imageTmp) { imageResult, error in
                    guard let imageResult = imageResult else {
                        completionBlock(nil, error)
                        return
                    }
                    completionBlock(imageResult)
                }
            }
        }
    }
}

processImageData2a { image, error in
    guard let image = image else {
        display("No image today", error)
        return
    }
    display(image)
}
```

---


```swift
// Error handling with Result<Success, Failure> callback
// (2b) Using a `do-catch` statement for each callback:
func processImageData2b(completionBlock: (Result<Image, Error>) -> Void) {
    loadWebResource("dataprofile.txt") { dataResourceResult in
        do {
            let dataResource = try dataResourceResult.get()
            loadWebResource("imagedata.dat") { imageResourceResult in
                do {
                    let imageResource = try imageResourceResult.get()
                    decodeImage(dataResource, imageResource) { imageTmpResult in
                        do {
                            let imageTmp = try imageTmpResult.get()
                            dewarpAndCleanupImage(imageTmp) { imageResult in
                                completionBlock(imageResult)
                            }
                        } catch {
                            completionBlock(.failure(error))
                        }
                    }
                } catch {
                    completionBlock(.failure(error))
                }
            }
        } catch {
            completionBlock(.failure(error))
        }
    }
}

processImageData2b { result in
    do {
        let image = try result.get()
        display(image)
    } catch {
        display("No image today", error)
    }
}
```

---


```swift
// Flow handling
// (2c) Using a `switch` statement for each callback:
func processImageData2c(completionBlock: (Result<Image, Error>) -> Void) {
    loadWebResource("dataprofile.txt") { dataResourceResult in
        switch dataResourceResult {
        case .success(let dataResource):
            loadWebResource("imagedata.dat") { imageResourceResult in
                switch imageResourceResult {
                case .success(let imageResource):
                    decodeImage(dataResource, imageResource) { imageTmpResult in
                        switch imageTmpResult {
                        case .success(let imageTmp):
                            dewarpAndCleanupImage(imageTmp) { imageResult in
                                completionBlock(imageResult)
                            }
                        case .failure(let error):
                            completionBlock(.failure(error))
                        }
                    }
                case .failure(let error):
                    completionBlock(.failure(error))
                }
            }
        case .failure(let error):
            completionBlock(.failure(error))
        }
    }
}

processImageData2c { result in
    switch result {
    case .success(let image):
        display(image)
    case .failure(let error):
        display("No image today", error)
    }
}
```

---

```swift
func processImageData3(recipient: Person, completionBlock: (_ result: Image) -> Void) {
    let swizzle: (_ contents: Image) -> Void = {
      // ... continuation closure that calls completionBlock eventually
    }
    if recipient.hasProfilePicture {
        swizzle(recipient.profilePicture)
    } else {
        decodeImage { image in
            swizzle(image)
        }
    }
}
```

---

#### Problem 4: Many mistakes are easy to make

```swift
func processImageData4a(completionBlock: (_ result: Image?, _ error: Error?) -> Void) {
    loadWebResource("dataprofile.txt") { dataResource, error in
        guard let dataResource = dataResource else {
            return // <- forgot to call the block
        }
        loadWebResource("imagedata.dat") { imageResource, error in
            guard let imageResource = imageResource else {
                return // <- forgot to call the block
            }
            ...
        }
    }
}
```

---

```swift
func processImageData4b(recipient:Person, completionBlock: (_ result: Image?, _ error: Error?) -> Void) {
    if recipient.hasProfilePicture {
        if let image = recipient.profilePicture {
            completionBlock(image) // <- forgot to return after calling the block
        }
    }
    ...
}
```

---


#### Because completion handlers are awkward, too many APIs are defined synchronously

---

## Proposed solution: async/await

```swift
func loadWebResource(_ path: String) async throws -> Resource
func decodeImage(_ r1: Resource, _ r2: Resource) async throws -> Image
func dewarpAndCleanupImage(_ i : Image) async throws -> Image

func processImageData() async throws -> Image {
  let dataResource  = try await loadWebResource("dataprofile.txt")
  let imageResource = try await loadWebResource("imagedata.dat")
  let imageTmp      = try await decodeImage(dataResource, imageResource)
  let imageResult   = try await dewarpAndCleanupImage(imageTmp)
  return imageResult
}
```

---


### Asynchronous functions

Function types can be marked explicitly as `async`, indicating that the function is asynchronous:

```swift
func collect(function: () async -> Int) { ... }
```

---

A function or initializer declaration can also be declared explicitly as `async`:

```swift
class Teacher {
  init(hiringFrom: College) async throws {
    ...
  }
  
  private func raiseHand() async -> Bool {
    ...
  }
}
```

---

### Asynchronous function types

```swift
struct FunctionTypes {
  var syncNonThrowing: () -> Void
  var syncThrowing: () throws -> Void
  var asyncNonThrowing: () async -> Void
  var asyncThrowing: () async throws -> Void
  
  mutating func demonstrateConversions() {
    // Okay to add 'async' and/or 'throws'    
    asyncNonThrowing = syncNonThrowing
    asyncThrowing = syncThrowing
    syncThrowing = syncNonThrowing
    asyncThrowing = asyncNonThrowing
    
    // Error to remove 'async' or 'throws'
    syncNonThrowing = asyncNonThrowing // error
    syncThrowing = asyncThrowing       // error
    syncNonThrowing = syncThrowing     // error
    asyncNonThrowing = syncThrowing    // error
  }
}
```

---

### Await expressions


```swift
// func redirectURL(for url: URL) async -> URL { ... }
// func dataTask(with: URL) async throws -> (Data, URLResponse) { ... }

let newURL = await server.redirectURL(for: url)
let (data, response) = try await session.dataTask(with: newURL)
```

Can be written as:

```swift
let (data, response) = try await session.dataTask(with: server.redirectURL(for: url))
```

---

An `await` operand may also have no potential suspension points, which will result in a warning from the Swift compiler, following the precedent of `try` expressions:

```swift
let x = await synchronous() // warning: no calls to 'async' functions occur within 'await' expression
```

---

```swift
let (data, response) = await try session.dataTask(with: server.redirectURL(for: url)) // error: must be `try await`
let (data, response) = await (try session.dataTask(with: server.redirectURL(for: url))) // okay due to parentheses
```

---
### Closures

A closure can have `async` function type. Such closures can be explicitly marked as `async` as follows:

```swift
{ () async -> Int in
  print("here")
  return await getInt()
}
```

An anonymous closure is inferred to have `async` function type if it contains an `await` expression.

```swift
let closure = { await getInt() } // implicitly async

let closure2 = { () -> Int in     // implicitly async
  print("here")
  return await getInt()
}
```

---


```swift
// func getInt() async -> Int { ... }

let closure5 = { () -> Int in       // not 'async'
  let closure6 = { () -> Int in     // implicitly async
    if randomBool() {
      print("there")
      return await getInt()
    } else {
      let closure7 = { () -> Int in 7 }  // not 'async'
      return 0
    }
  }
  
  print("here")
  return 5
}
```

### Overloading and overload resolution

Existing Swift APIs generally support asynchronous functions via a callback interface, e.g.,

```swift
func doSomething(completionHandler: ((String) -> Void)? = nil) { ... }
```

Many such APIs are likely to be updated by adding an `async` form:

```swift
func doSomething() async -> String { ... }
```

---


```swift
doSomething() // problem: can call either, unmodified Swift rules prefer the `async` version
```

---


```swift
func doSomething() -> String { /* ... */ }       // synchronous, blocking
func doSomething() async -> String { /* ... */ } // asynchronous

// error: redeclaration of function `doSomething()`.
```

### Autoclosures


```swift
// error: async autoclosure in a function that is not itself 'async'
func computeArgumentLater<T>(_ fn: @escaping @autoclosure () async -> T) { } 
```

---


  ```swift
  // func getIntSlowly() async -> Int { ... }

  let closure = {
    computeArgumentLater(await getIntSlowly())
    print("hello")
  }
  ```

---


```swift
await computeArgumentLater(getIntSlowly())
```

---


### Protocol conformance


```swift
protocol Asynchronous {
  func f() async
}

protocol Synchronous {
  func g()
}

struct S1: Asynchronous {
  func f() async { } // okay, exactly matches
}

struct S2: Asynchronous {
  func f() { } // okay, synchronous function satisfying async requirement
}

struct S3: Synchronous {
  func g() { } // okay, exactly matches
}

struct S4: Synchronous {
  func g() async { } // error: cannot satisfy synchronous requirement with an async function
}
```

---


## Source compatibility


```swift
func await(_ x: Int, _ y: Int) -> Int { x + y }

let result = await(1, 2)
```
---



[^2]: Also: https://github.com/MaxDesiatov/SwiftConcurrencyExample

### reasync

Note: 

https://swift.org/builds/swift-5.5-branch/xcode/swift-5.5-DEVELOPMENT-SNAPSHOT-2021-05-11-a/swift-5.5-DEVELOPMENT-SNAPSHOT-2021-05-11-a-osx.pkg

---

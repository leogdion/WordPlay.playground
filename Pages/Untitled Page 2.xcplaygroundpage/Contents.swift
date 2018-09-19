//: [Previous](@previous)

import Foundation
import PlaygroundSupport

let url = playgroundSharedDataDirectory.appendingPathComponent("names.txt")
let lines = try! String(contentsOf: url).components(separatedBy: "\n")
let badWords =  try! String(contentsOf: Bundle.main.url(forResource: "badWords", withExtension: "txt") )

//: [Next](@next)

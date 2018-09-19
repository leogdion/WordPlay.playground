import Cocoa
import PlaygroundSupport

struct MWResult : Codable {
  let query : MWResultQuery
  let `continue` : MWResultContinue?
}

struct MWResultContinue : Codable {
  let plcontinue : String
}

struct MWResultQuery : Codable {
  let pages : [String : MWResultQueryPage]
}

struct MWResultQueryPage : Codable {
  let links : [MWResultLink]
}

struct MWResultLink : Codable {
  let title : String
}

PlaygroundPage.current.needsIndefiniteExecution = true

//"https://en.wikipedia.org/w/api.php?action=query&titles=List_of_birds_by_common_name&prop=links"

let baseUrl = URL(string: "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=links")!
let baseURLComponents = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)!

func buildLinksListURL (withTitles titles: String, withContinue `continue`: String? = nil) -> URL? {
  var urlComponents = baseURLComponents
  var queryItems = urlComponents.queryItems ?? [URLQueryItem]()
  queryItems.append(URLQueryItem(name: "titles", value: titles))
  if let `continue` = `continue` {
    queryItems.append(URLQueryItem(name: "plcontinue", value: `continue`))
  }
  urlComponents.queryItems = queryItems
  return urlComponents.url
}




func getLinks(byTitles titles: String, transform: ((String) -> String?)?, _ completed: @escaping (Set<String>) -> Void) {
  
  var names = Set<String>()
  let titlesGroup = DispatchGroup()
  
  let session = URLSession(configuration: .default)
  
  func manageData(_ data: Data?, response: URLResponse?, error: Error?) {
    let decoder = JSONDecoder()
    let result = try! decoder.decode(MWResult.self, from: data!)
    if let plcontinue = result.continue?.plcontinue {
      //print(titles, plcontinue)
      DispatchQueue.global(qos: .background).async {
        titlesGroup.enter()
        let url = buildLinksListURL(withTitles: titles, withContinue: plcontinue)!
        let task = session.dataTask(with: url, completionHandler: manageData)
        DispatchQueue.global(qos: .background).async {
          task.resume()
        }
      }
    }
    let links = result.query.pages.flatMap{$0.value.links}
    let newNames = links.compactMap{ (link) -> String? in
      if let transform = transform {
        return transform(link.title)
      } else {
        return link.title
      }
    }
    //print(names)
    names.formUnion(newNames)
    titlesGroup.leave()
  }
  titlesGroup.enter()
  let url = buildLinksListURL(withTitles: titles)!
  let task = session.dataTask(with: url, completionHandler: manageData)
  
  
  DispatchQueue.global(qos: .background).async {
    task.resume()
  }
  
  titlesGroup.notify(queue: .main) {
    
    completed(names)
  }
}

let group = DispatchGroup()

var birdNames : [String]!
var appleNames : [String]!
group.enter()
getLinks(byTitles: "List_of_birds_by_common_name", transform: {$0.split(separator: " ").last?.lowercased()}) { (names) in
  birdNames = names.sorted()
  group.leave()
}

group.enter()
getLinks(byTitles: "List_of_apple_cultivars", transform: {$0.split(separator: " ").last?.lowercased()}) { (names) in
  appleNames = names.sorted()
  group.leave()
}

group.notify(queue: .main) {
  print("Gathered All Data...")
  let birdNamesFirst : [[String]] = birdNames.map({ (birdName) -> [String] in
    return appleNames.map({ (appleName) -> String in
      return "\(birdName) \(appleName)"
    })
  })
  
  let appleNamesFirst : [[String]] = birdNames.map({ (birdName) -> [String] in
    return appleNames.map({ (appleName) -> String in
      return "\(appleName) \(birdName)"
    })
  })
  
  let names = appleNamesFirst.flatMap{$0} + birdNamesFirst.flatMap{$0}
  let url = playgroundSharedDataDirectory.appendingPathComponent("names.txt")
  let fileHandle = try! FileHandle(forWritingTo: url)
  let newLineData = "\n".data(using: .utf8)!
  var lastPercent = 0
  names.sorted().enumerated().forEach({ (index, name) in
    DispatchQueue.global().async {
      let percent = index/names.count*100
      if percent > lastPercent {
        lastPercent = percent
        print(lastPercent)
      }
    }
    fileHandle.write(name.data(using: .utf8)!)
    fileHandle.write(newLineData)
  })
  PlaygroundPage.current.finishExecution()
}

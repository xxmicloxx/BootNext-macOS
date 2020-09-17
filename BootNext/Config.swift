//__FILENAME__

import Foundation
import Regex

struct BootSection {
    var displayTitle: String {
        title ?? "<\(key)>"
    }
    
    var key: String
    var title: String?
    var icon: String?
}

class Config {
    var sections = [String:BootSection]()
    let bootSectionRegex = Regex(#"B:(.*)"#)
    
    private func handleSection(_ section: String) {
        if let bootMatch = bootSectionRegex.firstMatch(in: section)?.captures[0] {
            if !sections.keys.contains(bootMatch) {
                sections[bootMatch] = BootSection(key: bootMatch)
            } else {
                print("Warning: duplicate boot section \(bootMatch)")
            }
        }
    }
    
    private func handleKeyValue(_ key: String, _ value: String, inSection section: String) {
        if let bootMatch = bootSectionRegex.firstMatch(in: section)?.captures[0] {
            var section = sections[bootMatch]!
            
            switch key {
            case "Title":
                section.title = value
                break
                
            case "Icon":
                section.icon = value
                break
                
            default:
                break
            }
            
            sections[bootMatch] = section
        }
    }
    
    private func parseConfigLines(_ lines: [String]) {
        let sectionRegex = Regex(#"\[(.*)\]"#)
        let settingRegex = Regex(#"([^=]*)=(.*)"#)
        
        var section: String? = nil
        
        for var line in lines {
            if let commentStart = line.firstIndex(of: "#") {
                line = String(line[..<commentStart])
            }
            
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.count == 0 {
                continue
            } else if let sectionMatch = sectionRegex.firstMatch(in: line)?.captures[0] {
                section = sectionMatch
                print("Got section [\(sectionMatch)]")
                
                handleSection(sectionMatch)
            } else if let settingMatches = settingRegex.firstMatch(in: line)?.captures,
                let key = settingMatches[0],
                let value = settingMatches[1] {
                
                if section == nil {
                    print("Warning: Got value for key \"\(key)\" while section was not set")
                    continue
                }
                
                handleKeyValue(key, value, inSection: section!)
            } else {
                print("Warning: Got garbage: \(line)")
            }
        }
    }
    
    init(withFile file: URL) throws {
        let data = try String(contentsOfFile: file.path, encoding: .utf8)
        let lines = data.components(separatedBy: .newlines)
        parseConfigLines(lines)
    }
}

import SwiftUI

struct ContentLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let flagColors: [Color]

    static let all: [ContentLanguage] = [
        .init(id: "pl", name: "Polish",     nativeName: "Polski",      flagColors: [.white, .red]),
        .init(id: "en", name: "English",    nativeName: "English",     flagColors: [.red, .white, .blue]),
        .init(id: "de", name: "German",     nativeName: "Deutsch",     flagColors: [.black, .red, .yellow]),
        .init(id: "fr", name: "French",     nativeName: "Français",    flagColors: [.blue, .white, .red]),
        .init(id: "es", name: "Spanish",    nativeName: "Español",     flagColors: [.red, .yellow, .red]),
        .init(id: "it", name: "Italian",    nativeName: "Italiano",    flagColors: [.green, .white, .red]),
        .init(id: "uk", name: "Ukrainian",  nativeName: "Українська",  flagColors: [.blue, .yellow]),
        .init(id: "cs", name: "Czech",      nativeName: "Čeština",     flagColors: [.white, .red, .blue]),
        .init(id: "sk", name: "Slovak",     nativeName: "Slovenčina",  flagColors: [.white, .blue, .red]),
        .init(id: "ru", name: "Russian",    nativeName: "Русский",     flagColors: [.white, .blue, .red]),
        .init(id: "pt", name: "Portuguese", nativeName: "Português",   flagColors: [.green, .red]),
        .init(id: "nl", name: "Dutch",      nativeName: "Nederlands",  flagColors: [.red, .white, .blue]),
        .init(id: "sv", name: "Swedish",    nativeName: "Svenska",     flagColors: [.blue, .yellow]),
        .init(id: "nb", name: "Norwegian",  nativeName: "Norsk",       flagColors: [.red, .white, .blue]),
        .init(id: "da", name: "Danish",     nativeName: "Dansk",       flagColors: [.red, .white]),
        .init(id: "fi", name: "Finnish",    nativeName: "Suomi",       flagColors: [.white, .blue]),
        .init(id: "hu", name: "Hungarian",  nativeName: "Magyar",      flagColors: [.red, .white, .green]),
        .init(id: "ro", name: "Romanian",   nativeName: "Română",      flagColors: [.blue, .yellow, .red]),
        .init(id: "tr", name: "Turkish",    nativeName: "Türkçe",      flagColors: [.red, .white]),
        .init(id: "ja", name: "Japanese",   nativeName: "日本語",       flagColors: [.white, .red]),
        .init(id: "zh", name: "Chinese",    nativeName: "中文",         flagColors: [.red, .yellow]),
        .init(id: "ko", name: "Korean",     nativeName: "한국어",       flagColors: [.white, .red, .blue]),
        .init(id: "ar", name: "Arabic",     nativeName: "العربية",      flagColors: [.green, .white, .black]),
    ]
}

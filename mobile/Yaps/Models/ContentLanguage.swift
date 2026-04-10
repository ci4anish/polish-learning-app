import SwiftUI

struct ContentLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let flagColors: [Color]

    static let all: [ContentLanguage] = [
        .init(id: "pl", name: "Польська",      nativeName: "Polski",      flagColors: [.white, .red]),
        .init(id: "en", name: "Англійська",    nativeName: "English",     flagColors: [.red, .white, .blue]),
        .init(id: "de", name: "Німецька",      nativeName: "Deutsch",     flagColors: [.black, .red, .yellow]),
        .init(id: "fr", name: "Французька",    nativeName: "Français",    flagColors: [.blue, .white, .red]),
        .init(id: "es", name: "Іспанська",     nativeName: "Español",     flagColors: [.red, .yellow, .red]),
        .init(id: "it", name: "Італійська",    nativeName: "Italiano",    flagColors: [.green, .white, .red]),
        .init(id: "uk", name: "Українська",    nativeName: "Українська",  flagColors: [.blue, .yellow]),
        .init(id: "cs", name: "Чеська",        nativeName: "Čeština",     flagColors: [.white, .red, .blue]),
        .init(id: "sk", name: "Словацька",     nativeName: "Slovenčina",  flagColors: [.white, .blue, .red]),
        .init(id: "ru", name: "Російська",     nativeName: "Русский",     flagColors: [.white, .blue, .red]),
        .init(id: "pt", name: "Португальська", nativeName: "Português",   flagColors: [.green, .red]),
        .init(id: "nl", name: "Нідерландська", nativeName: "Nederlands",  flagColors: [.red, .white, .blue]),
        .init(id: "sv", name: "Шведська",      nativeName: "Svenska",     flagColors: [.blue, .yellow]),
        .init(id: "nb", name: "Норвезька",     nativeName: "Norsk",       flagColors: [.red, .white, .blue]),
        .init(id: "da", name: "Данська",       nativeName: "Dansk",       flagColors: [.red, .white]),
        .init(id: "fi", name: "Фінська",       nativeName: "Suomi",       flagColors: [.white, .blue]),
        .init(id: "hu", name: "Угорська",      nativeName: "Magyar",      flagColors: [.red, .white, .green]),
        .init(id: "ro", name: "Румунська",     nativeName: "Română",      flagColors: [.blue, .yellow, .red]),
        .init(id: "tr", name: "Турецька",      nativeName: "Türkçe",      flagColors: [.red, .white]),
        .init(id: "ja", name: "Японська",      nativeName: "日本語",       flagColors: [.white, .red]),
        .init(id: "zh", name: "Китайська",     nativeName: "中文",         flagColors: [.red, .yellow]),
        .init(id: "ko", name: "Корейська",     nativeName: "한국어",       flagColors: [.white, .red, .blue]),
        .init(id: "ar", name: "Арабська",      nativeName: "العربية",      flagColors: [.green, .white, .black]),
    ]
}

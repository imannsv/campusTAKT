import Foundation

public func studentMotto(after previous: String? = nil) -> String {
  let sayings = [
    "Auch kleine Schritte bringen dich weiter.",
    "Du musst nicht alles heute schaffen.",
    "Eine gute Frage ist schon ein Anfang.",
    "Fortschritt beginnt mit Ausprobieren.",
    "Pausen gehören zum Lernen dazu.",
    "Bleib neugierig. Der Rest kommt Schritt für Schritt.",
    "Heute lernen, morgen weiterdenken.",
    "Dein Tempo zählt, nicht das der anderen.",
  ]
  return sayings.filter { $0 != previous }.randomElement()!
}

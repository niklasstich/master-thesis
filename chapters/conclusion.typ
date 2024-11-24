= Conclusion and future work
Hier ist quasi "Brainstorming" für Patterns, die man noch automatisieren könnte, die ich aber nicht geschafft habe. (Composite? observer (complicated and see metalama implementation), singleton via DI, ???)

Aspects as first-class language feature instead of retrofitted (like source generators or Metalama)

Weitere Tools und Methoden zur Verifizierung von korrekter Verwendung von Patterns (z.B. Fabric die prueft ob singleton wirklich singleton ist, prüfen dass component constructor nur in fabric mit annotation verwendet wird, etc.)

TODO: Bestehende Patternimplementierungen verbessern, z.B. incrementals memento @Gamma1994[p. 287], transactional database for memento, abstract factory for factory, use metalama.observability for for unsaved changes, onchanged for unsaved

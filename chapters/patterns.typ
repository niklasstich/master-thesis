// = Implemented patterns
// Hier alle Patterns, die ich auch wirklich geschafft habe zu implementieren. Detailiert auch immer die Implementierungen und den generierten Code erklären.
#include "patterns/memento.typ"
#include "patterns/singleton.typ"
#include "patterns/unsavedchanges.typ"
#include "patterns/factory.typ"

= Analysis of other patterns
Warum ist z.B. Command blöd?

In this chapter, we shall look at some other design patterns that have not been implemented in Moyou yet and analyze whether implementing them via aspects is sensible, brings any benefits and is even possible in the first place. We'll also take a look at some reference implementations of other programming patterns courtesy of the Metalama project.

== Command
We'll start off with a quite nonsensical example of a design pattern for our approach of auto-implementing patterns. The command pattern is a behavioral pattern@ which allows us to ""

#pagebreak(weak:true)
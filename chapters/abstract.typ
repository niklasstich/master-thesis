#set page(header: [#h(1fr) iii #line(length: 100%)])
#v(2cm)
#align(center)[*Abstract*]
#v(1.33cm)
Minimizing manual, repetitive tasks programmers have to undertake in modern software development has become a key focus for the industry. In this thesis, the use of metaprogramming, and more specifically, aspect-oriented programming, to generate source code for common software design and programming patterns will be explored. First, focus will be on explaining the terminology of aspect-oriented programming, the problems it tries to solve and why it might find application when trying to implement patterns. After that, some metaprogramming solutions that could potentially be used to implement patterns using AOP in the .NET ecosystem will be analyzed, including Metalama, which was used to implement the Moyou project. The Moyou project is an open-source library containing all the implementations and tests of the patterns presented in this work and is available at [https://github.com/niklasstich/Moyou].

A detailed analysis of the Memento, Singleton, Unsaved Changes and Factory patterns follows, where the core of the problems the patterns solve and different concrete implementation strategies will be discussed, and example implementations of these patterns will be presented in Metalama. Both the positive and negative consequences of automatically implementing these patterns with AOP will be presented as well as how the solutions that were implemented apply to an example input. In that context, this thesis will also bring forth arguments that using AOP can help improve how much a codebase adheres to well-known software development principles.

Finally, some other patterns that are interesting to consider for a code generation solution like the one at hand will be discussed and some tasks and research areas that future work might concern itself with will be presented.
#set page(header: none)

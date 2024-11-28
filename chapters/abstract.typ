#set page(header: [#h(1fr) iii #line(length: 100%)])
#v(2cm)
#align(center)[*Abstract*]
#v(1.33cm)
Reducing the amount of manual grunt work programmers have to do when making software has been a big focal point in modern software development. In this thesis, we will explore using metaprogramming and more specifically aspect-oriented programming to generate source code for common software design and programming patterns. We will first focus on explaining the terminology of aspect-oriented programming, the problems it tries to solve and why it might find application when trying to implement patterns. We will then have a look at some possible metaprogramming solutions we can use to implement patterns using AOP in the .NET ecosystem, including Metalama, which was used to implement the Moyou project. The Moyou project is an open-source library containing all the implementations and tests of the patterns presented in this work and is available at [https://github.com/niklasstich/Moyou].

A detailed analysis of the Memento, Singleton, Unsaved Changes and Factory patterns follows, where we analyze the patterns, formulate the concrete designs we want to use, show how to implement them using aspects in Metalama, contemplate both the positive and negative consequences of automatically implementing these patterns with AOP and present how the solutions we implemented apply to an example input. We will also see how using AOP can help improve how much a codebase adheres to well-known software development principles.

We will finish up with presenting some other patterns that are interesting to consider for a code generation solution like the one at hand and present some tasks and research areas that future work might concern itself with.
#set page(header: none)

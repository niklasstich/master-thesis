= Factory<factory>

== Analysis of pattern
The factory method and abstract factory patterns are creational patterns@Gamma1994[p. 87ff, 107ff], which, as Nesteruk describes correctly, are variations on a more generalized description of the pattern that's commonly known as the factory pattern nowadays@Nesteruk2022[p. 73]. The main point of the factory pattern is to decouple the creation of a concrete object and the code that uses it via introduction of a third type that is responsible for creating our concrete object for our consumer@Gamma1994[p. 87f, 107f].

The abstract factory is presented in @Gamma1994 as a solution suitable "for creating families of related or dependant objects without specifying their concrete classes"@Gamma1994[p. 87], and they go on to explain that we should use it in cases where we need to have multiple versions of different components that can be swapped out transparently@Gamma1994[p. 87]. This pattern is implementing by introducing interfaces for both the factories and the components they create and is especially useful in combination with dependency injection technologies, because we usually need to introduce an interface for all of our applications dependencies (like our factories for example) anyway and implementing the abstract factory pattern completely solves the problem of mocking our objects during tests. The core of the abstract factory solution is shown in the class diagram in @factory_abstract_classdiag.

#figure(
    image("../../diagrams/factory/factory_class.svg"),
    caption: [Abstract factory class diagram with interfaces, adapted from @Gamma1994[p. 87f]]
)<factory_abstract_classdiag>

In the following section we will explore why implementing the factory pattern in Metalama is possible, but not in way the author originally intended and the compromise that was found to implement factory but not abstract factory.
== Implementation of aspects
== Example application of pattern
== Impact and consequences of aspects<factory_consequences>
#pagebreak(weak: true)
#import "../../codly/codly.typ": * 
#import "../../config.typ": ct, gen

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
The original idea for how the factory and abstract factory pattern should be implemented was the following: First of all, we would define empty stub classes for the factories. On the component types that should be constructed by factories, the `[Factory(typeof(ConcreteFactory)]` attribute would be placed. A second parameter on the attribute would have indicated the primary interface to use as a return type of the factory, if there were more than one. To also implement abstract factory, we would create a stub interface and place the `[AbstractFactory(typeof(IAbstractFactory)]` attribute on our concrete factory types. During compilation, the factory aspect would have be executed first and generate all the required methods on the factories, then the abstract factory aspect would have ran afterward and, if the signatures of the methods of the concrete factories were compatible (think parameters, return types and method names), introduce the methods to the abstract factory interface and generate the methods in it. An example of what that should have looked like in code is seen in @factory_initial_design_example. The code that should have been generated will be highlighted in green.

#codly(
    highlights:
    (
        gen(2, start: 5),
        gen(6, start: 24),
        gen(8, start: 5),
        gen(12, start: 24),
        gen(14, start: 5),
    )
)

#figure(
```cs
interface IAbstractFactory
{
    public IComponent GetComponent();
}

[AbstractFactory(typeof(IAbstractFactory))]
class ConcreteFactoryA : IAbstractFactory
{
    public IComponent GetComponent() => new ConcreteComponentA();
}

[AbstractFactory(typeof(IAbstractFactory))]
class ConcreteFactoryB : IAbstractFactory
{
    public IComponent GetComponent() => new ConcreteComponentB();
}

interface IComponent
{
}
[Factory(typeof(ConcreteFactoryA), typeof(IComponent))]
class ConcreteComponentA : IComponent, ISomeOtherInterface
{
}
[Factory(typeof(ConcreteFactoryB))]
class ConcreteComponentB : IComponent
{
}

```, caption: [Initial design proposal for factory and abstract factory implementation]
)<factory_initial_design_example>

Unfortunately, this design was not (yet) possible in Metalama during development of this patterns implementation. The reason for this is that an aspect can only manipulate the target declaration it was declared on and it's nested child types. Because the concrete factory is a separate type completely unrelated to the concrete components, it's not possible to declare the factory like this. The reason this limitation is in place is because aspects rely on source transformers behind the scenes to enact the advice that we declare in aspects and if we could build advice on arbitrary types in a compilation, every aspect would potentially need a source transformer on every declaration in the compilation. Furthermore, the factory type could be in a separate compilation altogether, in which case it would be impossible to even create a source transformer on it from the context of our current compilation. In Metalama 2025.0 however, this limitation was partially lifted, as we can now put attributes on any declaration we wish to#footnote([Information sourced from private communication with Gael Fraiteur on Nov. 23th, 2024 (via Slack)]) which can then be an aspect itself. An example implementation of abstract factory using this new feature can be found at [https://github.com/postsharp/Metalama.Samples/pull/96].

Instead, as a compromise, it was decided to reverse the design by putting the relevant attributes on the factory classes and having them reference the types they are supposed to instantiate. The design for this is more involved and requires more types, an overview of which can be found in @factory_aspects_classes.

#figure(
    image("../../diagrams/factory/factory_aspects_classes.svg"),
    caption: []
)<factory_aspects_classes>

This design means that we should have *one attribute per concrete component* and because we can only have one instance of an *aspect* per target declaration, we use plain C\# attributes in the form of `[FactoryMember(typeof(ConcreteComponent), typeof(IConcreteComponent))]` to declare these target types and use a fabric#footnote([This fabric won't be shown here because it is quite lengthy and complex due to the error handling it has to perform, but it can be found at [https://github.com/niklasstich/Moyou/blob/master/Moyou.Aspects/Moyou.Aspects.Factory/FactoryMemberFabric.cs].]) to read and rewrite them into a single `[FactoryMemberAspect]` which contains a list of tuples of `(INamedType, INamedType)`, where the first type is the concrete component type and the second type is the primary interface the factory should use as a return type on the create method. This `FactoryMemberAspect` then writes an annotation on the target@metadocs[AdviserExtensions.AddAnnotation method] which the `FactoryAttribute` aspect#footnote([Note that even though it's named `FactoryAttribute`, it's not only just a plain attribute but actually an aspect. By convention, we can use attributes in C\# by omitting `Attribute` in the declaration if the type name of the attribute ends with `Attribute`, explaining the name.]) reads and finally generates the required methods. The order in which the fabrics and aspects described are executed and the steps they perform is detailed in @factory_aspect_order. We'll do without showing the implementation code of the factory pattern here, as it is quite lengthy and verbose.

To give users the option to mark which constructor should be used, a `[FactoryConstructor]` attribute was introduced which the `FactoryAttribute` aspect will use to instantiate the concrete component in it's implementation. If the attribute is not present, the factory aspect will check whether there is a single public constructor on the component type and use it if that's the case, otherwise throw an error for the user with the demand to mark the constructor that should be used.

Because we were unhappy with the final implementation of the factory pattern, the decision was made *not* to pursue the abstract factory pattern in the same manner, as it would have required essentially copying the logic described above and adjusting it for the abstract factory.

#figure(
    image("../../diagrams/factory/factory_aspect_order.svg"),
    caption: [Activity diagram which shows a simplified overview of how the factory implementation works]
)<factory_aspect_order>

== Example application of pattern
TODO: ausklammern? kommt auf finale länge an
== Impact and consequences of aspects<factory_consequences>

#pagebreak(weak: true)
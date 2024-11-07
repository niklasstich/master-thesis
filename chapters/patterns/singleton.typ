= Singleton

== Analysis of pattern
The singleton pattern is a creational pattern which can be used to "[e]nsure a class only has one instance, and provide a global point of access to it"@Gamma1994[p. 127]. At any point of a programs lifecycle, if a class implements the singleton pattern, there must, at most, be one instance of said class. To ensure that this is the case, we make the singleton class itself responsible for managing it's own instance creation and object lifecycle as well as providing access to this instance@Gamma1994[p. 127] by declaring all constructors of the type as non-public and providing a public facing static operation to retrieve the instance of the type@Gamma1994[p. 129]. This static operation must check whether there is already an instance of the type stored statically inside of the type, create a new instance if not, and return the single instance@Gamma1994[p. 129 implementation].

#figure(
  image("../../diagrams/singleton/singleton_staticctor_classdiagram.svg"),
  caption: [Class diagram of singleton implementation using static constructor initialization]
)<singleton_static_initialization>

In @singleton_static_initialization, we see one way to define such a singleton class in C\#. We define a private instance constructor on the type and a static constructor: static constructors are a language feature that allows us to initialize our type before any instance of the type can be instantiated or any of the static members of the type can be used (such as the static property `Instance`)@dotnetdocs[Static Constructors]. Because the static constructor will only ever be called once in the entire lifetime of the program, we can be sure that there will only ever be one instance of the type. However, because we create our instance of `Singleton` directly inside the static constructor, and because the static constructor is called when either an instance of the type is created (which only the static constructor can in this case) or a static member is accessed, the object is initialized as soon as we access *any* static member on the type. This might not necessarily always be what we want, for example when we interact with other systems that need to be configured first before instantiating a connection or some such.

To solve this, we can use lazy initialization as shown in @singleton_lazy_initialization. Instead of creating the instance of our singleton type directly in our static constructor and storing it in the `Instance` property, we use the `Lazy<T>` from the .NET Framework to lazily instantiate our type@dotnetdocs[Lazy\<T> Class]. In this setup, we do not have to care about when the static constructor is called, as calling the static instructor does not instantiate the type directly; it is instead only created (via the provided lambda inside the `Lazy` constructor call) when we try to retrieve the value from the `Lazy` object via the `Instance` computed property. One advantage of using `Lazy<T>` over writing our own initialization logic is that it is already thread-safe out of the box@dotnetdocs[Lazy\<T> class]. To be specific, the `Lazy<T>` constructor shown in the example sets the thread safety mode to `LazyThreadSafetyMode.ExecutionAndPublication`, which means that in case `.Value` is called from multiple threads simultaneously, only one thread will ever be allowed to call the provided initialization lambda@dotnetdocs[LazyThreadSafetyMode Enum].

#figure(
  image("../../diagrams/singleton/singleton_lazy_classdiagram.svg"),
  caption: [Class diagram of singleton implementation using lazy initialization]
)<singleton_lazy_initialization>

Another method of initializing the instance is to use static field initializers; these initializers are run before the static constructor is called and can therefore create an instance of the type before it's static constructor is called@dotnetdocs[Static constructors]. This implementation however also has the drawback of not being lazy, just like the static constructor initialization. A full code example for a singleton implementation using static field initializers can be found in @dotnetdocs[Static constructors].

The singleton pattern can find application in cases where we need to ensure exactly one instance of the type will exist for the duration of the runtime of the program and access to it must be available to clients requiring an instance of the type@Gamma1994[p. 127]. The reason for this might be that the singleton represents a limited real-world resource (like a printer)@Freeman2015[p. 114] 

TODO: criticisms of singleton, but we still want to look at how we would implement it

== Implementation of aspects
== Example application of pattern
== Technical limitations
== Impact and consequences of aspects

#pagebreak(weak: true)
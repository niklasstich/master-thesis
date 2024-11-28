#import "../../codly/codly.typ": * 
#import "../../config.typ": ct

= Singleton<singleton>

== Analysis of Pattern<singleton_analysis>
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

Another method of initializing the instance is to use static field initializers; these initializers are run before the static constructor is called and can therefore create an instance of the type before it's static constructor is called@dotnetdocs[Static constructors]. This implementation however also has the drawback of not being lazy, just like the static constructor initialization, unless we use the `Lazy<T>` type. A full code example for a singleton implementation using static field initializers can be found in @dotnetdocs[Static constructors] or @Nesteruk2022[p. 115f] for a lazy version.

The singleton pattern can find application in cases where we need to ensure exactly one instance of the type will exist for the duration of the runtime of the program and access to it must be available to clients requiring an instance of the type@Gamma1994[p. 127]. The reason for this might be that the singleton represents a limited real-world resource (like a printer)@Freeman2015[p. 114] or because it wouldn't make sense to have multiple instances of an object, such as a read-only view of a database@Nesteruk2022[p. 113]. Despite the usefulness of the pattern in such situations, there are also many points of criticism that can be brought up against it. For one, the pattern encourages us to have our dependants highly coupled with our dependencies through references to static type variables, which makes unit testing our dependants without using real dependencies impossible@Nesteruk2022[p. 118f]. An example of this can be found in @singleton_tightly_coupled_code and @singleton_tightly_coupled_classdiag. Because `Consumer` depends on `Provider` directly and we cannot access the reference to it from the outside, it is impossible to mock or otherwise replace the dependency in a test.

#figure(
```cs
class Provider
{
    private Provider()
    {
        SomeData = 42;
    }
    private static Provider()
    {
        _instance = new Lazy<Provider>(() => new Singleton());
    }

    public static Provider Instance => _instance.Value;
    private static Lazy<Provider> _instance;
    public int SomeData { get; set; }
}

class Consumer 
{
    public Consumer()
    {
        _dependency = Singleton.Instance;
    }
    private Provider _dependency;
    public int GetSomeData(int factor) => _dependency.SomeData * factor;
}
```, caption: [Example of a tightly coupled singleton and its consumer]
)<singleton_tightly_coupled_code>

#figure(
  image("../../diagrams/singleton/singleton_tight_coupling.svg"),
  caption: [Class diagram for @singleton_tightly_coupled_code]
)<singleton_tightly_coupled_classdiag>

Making this circumstance even worse is that this pattern of static type references cascades: If our `Provider` type itself has a dependency on a different singleton, we will have to apply this exact same pattern again and our `Consumer` type is now (transitively) dependant on two singletons that cannot be replaced under test.

It could also be claimed that the singleton pattern violates the SRP because in addition to the classes own business logic responsibilities it needs to also manage it's own instances and lifecycle@Densmore2004. Even the "Gang of Four" member Erich Gamma is critical of the singleton pattern in hindsight: "When discussing which patterns to drop, we found that we still love them all. (Not really—I'm in favor of dropping Singleton. Its use is almost always a design smell.)"@OBrien2009. Without putting words into Gamma's mouth, we can take a guess at what this mentioned design smell might be. Generally, the singleton pattern is implemented either through global variables holding a reference to the instance of a type or via static variables on the type itself. The reason we might prefer to handle our singleton as a globally accessible variable somewhere (a static field is functionally the same), is that it is more convenient that passing around the instance of our singleton from type to type, which is a design smell in itself@Densmore2004.

To fix the first issue involving the references to static variables, we may simply apply the Dependency Inversion Principle (DIP)@Nesteruk2022[p. 21ff]@Martin2014[p. 127ff] and use constructor-injection like seen in @singleton_decoupled_code and @singleton_decoupled_classdiag to break the direct reference. We can then use a technique like a dependency injection framework to pull out the singleton pattern out of our `Provider` class entirely and just let the dependency injection container handle the lifetimes and injection of our singletons (see @dotnetdocs[.NET dependency injection] for example). This way, we have completely removed the classic singleton pattern out of our dependency however, and an automatic implementation of this "modern" version of the singleton pattern would be highly dependant on what kind of technology we use for the dependency injection and would only consist of generating setup code for it. Because generating a single line of declarative configuration is a moot exercise, we will not be looking further into how to implement such an aspect in this paper.

#figure(
```cs
interface IProvider 
{
    public int SomeData { get; set; }
}
class Provider : IProvider
{
    private Provider()
    {
        SomeData = 42;
    }
    public int SomeData { get; set; }
}

class Consumer 
{
    public Consumer(IProvider provider)
    {
        _dependency = provider;
    }
    private Provider _dependency;
    public int GetSomeData(int factor) => _dependency.SomeData * factor;
}
```, caption: [Example in @singleton_tightly_coupled_code decoupled via DIP]
)<singleton_decoupled_code>
#figure(
  image("../../diagrams/singleton/singleton_decoupled.svg"),
  caption: [Class Diagram for @singleton_decoupled_code]
)<singleton_decoupled_classdiag>

Despite these mentioned criticisms, it is still worthwhile to look at how we would automatically implement the classic singleton pattern via aspects, because we are not always in a position to use the alternative solutions mentioned above due to e.g. performance, platform or other architectural constraints and could therefore still potentially reap benefits from automating this pattern. Because singleton is such a prevalent pattern that finds application in many legacy and modern code bases alike, we can analyze whether switching to an aspect to automate the implementation of the has any advantages in such cases.

== Implementation of Aspects
The singleton aspect is implemented in a single class `SingletonAttribute`, which again extends `TypeAspect`. The attribute has one single parameter, a boolean indicating whether the singleton should be lazily initiated.

As with all aspects, before execution of the `BuildAspect` method we can check whether the target is eligible for the aspect. In the case of singleton, we check that the target is not an interface, is not abstract and is not static. Furthermore, the type must have at least one parameterless constructor. We can additionally ensure that the target type will only be a class by putting the `[AttributeUsage(AttributeTargets.Class)]` attribute onto the `SingletonAttribute` itself. If we now try to use it on a struct for example, the .NET compiler itself will give us an error. Next, we will look at the logic of `BuildAspect`.

First of all, the aspect retrieves all constructors on the target type. If there is exactly one constructor, we check if that constructor is the implicit parameterless constructor of the type. In C\#, any non-static class that has no explicitly defined constructors will automatically get an implicit public constructor with no parameters@dotnetdocs[Using Constructors]. If that is the case, we will warn the user that this type has no explicit constructor, and therefore has the implicit public parameterless constructor, and therefore is technically not suitable for the singleton pattern as there should be no publically accessible constructors on the type. Otherwise, we go through all constructors again and check whether they are public and accordingly report those as warnings too, as they should not be public to prevent the singleton being instantiated anywhere else. After this, we go to the actual generating step of the singleton, which depends on the value set to the `Lazy` parameter mentioned before. The code up to this step can be seen in @singleton_aspect_analysis.

#figure(
```cs
var constructors = builder.Target.Constructors.ToList();
var first = constructors.First();
if (constructors.Count == 1 && first is { IsImplicitlyDeclared: true, Parameters.Count: 0, Accessibility: Accessibility.Public })
{
    ReportImplicitConstructor(builder);
}
else
{
    foreach (var constructor in constructors.Where(constructor => constructor.Accessibility != Accessibility.Private))
    {
        ReportPublicConstructor(builder, constructor);
    }
}

if (Lazy) GenerateLazyImplementation(builder);
else GenerateNonLazyImplementation(builder);
```, caption: [`BuildAspect` code snippet before implementation step]
)<singleton_aspect_analysis>
=== Lazy Implementation<singleton_lazy_implementation>
For the lazy implementation, we introduce a static field called `_instance` to the target type, which is of type `Lazy<TTarget>` with `TTarget` being the target type the aspect is applied to. To get a reference to this `Lazy<TTarget>` type, we must first use reflection tricks to get around syntax limitations of the C\# language as can be seen in @singleton_lazy_typetrick, because we can't simply type an expression like `Lazy<TTarget>` in our current context.

To initialize this field, we add an initializer to the target. This name is misleading however, as unlike explained in @singleton_analysis, this will not generate a static initializer on the field, but instead add a line initializing the field in one of the constructors#footnote([A static constructor is automatically introduced if none exists yet.]), see @singleton_example for examples. Because we specify that we want the `InitializerKind.BeforeTypeConstructor`, Metalama will make this initialization in the static constructor of the type (also sometimes referred to as the type constructor), if we instead had specified `InitializerKind.BeforeTypeConstructor`, it would be initialized in the instance constructor(s) of the type. When calling the `AddInitializer` method, we pass in our `CreateLazyInstance` template as an implementation for the initializer.

Finally, we must introduce a property from which our consumers can get the instance of the singleton. To do this, we call the advice factory on our builder once again, with `IntroduceProperty` this time, to which we pass our `GetLazyInstance` template and no template for the setter (`null` argument after `nameof(GetLazyInstance)`). Once again, we have to specify that we want this property to be static and that we want it to be public in this case.

In the templates for this implementation, the generic type parameter T is a compile-time value, but during generation of the run-time code the method becomes non-generic, meaning the parameter T is removed and all occurrences of T, such as in the return types, are replaced with the type that was passed in for that parameter instead. Furthermore, the `meta.ThisType` compile-time expressions are replaced with run-time expressions referring to the target type of the aspect, in contrast to `meta.This`, which would refer to the current instance of the target type, which would not be applicable because we are in a static syntax in this template. Because templates themselves however are agnostic to whether they are used in a static or non-static context, we must specify this when we apply the template in our initializer or property advice definitions.

In the `CreateLazyInstance` template in @singleton_lazy_new_constraint, we once again see that the `new()` constraint is being used. As previously explained, this constraint ensures that the type T must have a parameterless public constructor. However, in this instance, this is not actually what we want, as we are making a singleton implementation, and only the singleton itself should be able to make an instance of itself. Luckily, Metalama simply ignores this constraint completely when generating code from our templates, that is because internally Metalama turns this generic method into a non-generic method during compilation and the `new()` constraint is ignored in this compilation step#footnote([Information sourced from private communication with Metalama developer Daniel Balaš via the Metalama Slack channel, dated Nov. 10th 2024]). We must however still define this constraint here, because otherwise the semantics of C\# generic type parameters will not allow us to call the `new T()` constructor inside of our generic method code, even though Metalama itself does not care about the constraint.
#codly(
  highlights: (
    (line: 3, start: 5, tag: "[1]", label: <singleton_lazy_typetrick>),
    ct(19),
    ct(20, start: 34, end: 48),
    ct(22, start: 12, end: 24),
    ct(25),
    ct(26, start: 40, end: 54),
    ct(26, start: 45, tag: "[2]", label: <singleton_lazy_new_constraint>),
    ct(28, start: 5, end: 17)
  )
)
#figure(
```cs
private void GenerateLazyImplementation(IAspectBuilder<INamedType> builder)
{
  var lazyGeneric = 
    typeof(Lazy<>).MakeGenericType([builder.Target.ToType()]);
  builder.Advice.IntroduceField(builder.Target, "_instance", lazyGeneric,
    IntroductionScope.Static, OverrideStrategy.Override
  );
  builder.Advice.AddInitializer(builder.Target, nameof(CreateLazyInstance),
    InitializerKind.BeforeTypeConstructor,
    args: new { T = builder.Target }
  );
  builder.Advice.IntroduceProperty(builder.Target, "Instance",
    nameof(GetLazyInstance), null, IntroductionScope.Static,
    OverrideStrategy.Override, 
    pbuilder => pbuilder.Accessibility = Accessibility.Public,
    args: new { T = builder.Target }
  );
}

[Template]
private static T GetLazyInstance<[CompileTime] T>()
{
    return meta.ThisType._instance.Value;
}

[Template]
private static void CreateLazyInstance<[CompileTime] T>() where T : new()
{
    meta.ThisType._instance = new Lazy<T>(() => new T());
}
```, caption: [Code snippet for lazy implementation of singleton]
)<singleton_code_lazy>
=== Non-Lazy Implementation
The non-lazy implementation is essentially the same as the lazy implementation from @singleton_lazy_implementation, with the key differences being that we use the target type directly instead of the lazy generic type when we define the `_instance` field and it's initializer, and dropping the `.Value` access as we've dropped the indirection. Otherwise, the steps are exactly the same and the final generated code looks the same to our consumers interface-wise.
== Example Application of Pattern<singleton_example>
In @singleton_example_lazy, we find the implementation that our singleton aspect generates in lazy mode. Note that in the declaration of the `[Singleton]` attribute, we do not have to specify the `Lazy` property as it is set to true by default. In @singleton_example_nonlazy, a similar non-lazy example is given. Note that in both examples, the interface of `Instance` is the same and only how we store the instance field differs; therefore users of our singleton do not need to concern themselves about how the singleton is instantiated.
#figure(
```diff
 using Moyou.Aspects.Singleton;
 
 namespace Moyou.UnitTest.Singleton;
 
 [Singleton]
 public partial class SingletonDummy
 {
     public static bool ConstructorCalled { get; private set; }
     private SingletonDummy()
     {
         ConstructorCalled = true;
     }
+
+
+    private static Lazy<SingletonDummy> _instance;
+
+    static SingletonDummy()
+    {
+        SingletonDummy._instance = new Lazy<SingletonDummy>(() => new SingletonDummy());
+    }
+
+    public static SingletonDummy Instance
+    {
+        get
+        {
+            return _instance.Value;
+        }
+    }
 }
```, caption: [Example of singleton aspect implementation in Lazy mode]
)<singleton_example_lazy>

#figure(
```diff
 using Moyou.Aspects.Singleton;
 
 namespace Moyou.UnitTest.Singleton;
 
 [Singleton(Lazy = false)]
 public partial class SingletonNonLazyDummy
 {
     public static bool ConstructorCalled { get; private set; }
 
     private SingletonNonLazyDummy()
     {
         ConstructorCalled = true;
     }
+
+
+    private static SingletonNonLazyDummy _instance;
+
+    static SingletonNonLazyDummy()
+    {
+        SingletonNonLazyDummy._instance = new SingletonNonLazyDummy();
+    }
+
+    public static SingletonNonLazyDummy Instance
+    {
+        get
+        {
+            return _instance;
+        }
+    }
 }
```, caption: [Example of non-lazy singleton implementation via the aspect]
)<singleton_example_nonlazy>
== Impact and Consequences of Implementation<singleton_consequences>
Using our singleton aspect to implement the singleton functionality for us does not give us quite as many advantages as the memento aspect did, because singleton is a pretty static pattern that does not change much even when the type we implement singleton itself changes significantly. That does however not mean that using metaprogramming to extract the singleton implementation from our singleton types itself has no merit. The arguments posited in @memento_consequences, except for the argument about the changing implementation, still stand. By removing the singleton implementation from the explicit code of the type we have made the type itself easier to understand and maintain, fulfilling our adapted defintion of the SRP. We've also again reduced code duplication by not having to copy-paste the same singleton implementation every time, instead relying on one singleton aspect implementation that can be tested in advance, reducing run-time code test requirements and that can be changed once centrally to change the implementation of all our singletons automatically.

It can therefore be concluded that even though the singleton initally appears very simple to understand and implement, there are still advantages to be had from automating it, even though it is "only" a creational pattern and does not carry much logic itself. This is because the singleton pattern solves a problem that fits our definition of cross-cutting concerns from @aop very well: the logic of the singleton pattern is concerned with the lifetime of objects of our target types rather than the actual functional business logic of the types itself, compare with @Kiczales1997[definition on p. 7]. If we follow the theory of aspect-oriented programming@Kiczales1997, it is only natural that we'd want to pull this concern out of our components.

#pagebreak(weak: true)
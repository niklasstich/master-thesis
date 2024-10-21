= Memento

== Analysis of pattern<memento_analysis>
The memento pattern is a behavioural pattern which allows us to, "without violating encapsulation, capture and 
externalize an object's internal state so that the object can be restored to this state later" @Gamma1994[p.283].
The so-called originator of the pattern is the class which holds the data we want to store and restore and emits
a memento object on call of `GetMemento()`. The state that has been captured during the creation of the memento object
can then be restored at a later point by calling the `RestoreMemento(IMemento)` method and passing the memento object.

Depending on language support, this memento object is usually implemented  
as a private nested class of the originator and implements a generic interface. This has the following advantages: 
+ It ensures that only the originator class itself knows the type and therefore only the originator can read the data
  stored inside of the memento object, preserving encapsulation.
+ We can store the memento object in a more generic manner, i.e. the consumer of our originator type does not need to 
  also know about the concrete memento type.
+ If the language supports it, the nested private class can access all of it's encapsulating outer classes private fields
  and properties, which enables us to build a quasi copy constructor on the memento type (see @copyctor) rather than
  assigning the properties of the memento in our `GetMemento()` method (see @propertysetter).


#figure(
  image("../../diagrams/memento_copy_constructor.svg"), 
  caption: [
    Memento class diagram using a copy constructor in the memento type, compare @Gamma1994[p.285]
  ]
)<copyctor>

#figure(
  image("../../diagrams/memento_properties_setter.svg"),
  caption: [Memento class diagram using property setters in the originator type]
)<propertysetter>

When using a language that does not support nested (private) classes, such as C++, one should consider using other language features to achieve a similar encapsulation (for example, using the `friend` keyword in C++ to expose the private fields of the memento class to the originator @Gamma1994[p.287]).

In some literature @Gamma1994[p.285]TODO: where else?, the classes that retrieve and hold the memento from the originator and controls when to restore them is called the caretaker. For example, when using the Command pattern to encapsulate changes to the originator as objects @Gamma1994[p.233], we would designate the command itself as the caretaker of the originator, requesting a memento object before making any changes and reapplying it onto the originator when the Undo method is called @Gamma1994[p. 238]. As outlined before, ideally the caretaker should not have any access to the data stored inside of the memento and should merely hold the memento until it is used to reapply a past state on the originator.

We must also take care to consider whether to shallow or deep copy our originator objects. When creating a shallow copy, we may simply copy all value type values and copy references to child objects into our memento type. When creating a deep copy on the other hand, we must clone all the child objects we hold a reference to (and in turn, copy all the objects that these objects hold references to, and so on). Both approaches have advantages and drawbacks:

- Creating shallow copies of objects is much faster, simpler and cheaper in terms of memory cost than creating deep copies @Gamma1994[p.286].
- When deep copying our originator to create mementos, restoring to a given state is much simpler, as we can simple restore any memento to restore the originator to its state when we created the memento.
- In contrast, when shallow copying, we must take care to not only reapply a memento to the originator itself, but also apply all mementos of child objects the originator holds a reference to, and to always reapply our mementos in the opposite order of the order we made the changes (and hence created the mementos) in.
- When restoring from a deep copy, simply reassigning the cloned child objects back to the originator destroys referential equality as we now point to a different object. This might be a potential problem for some applications.


== Implementation of aspects
=== Aspects and types
To automatically generate code that implements the functionality of the Memento pattern and to account for its possible variations as discussed in @memento_analysis required the implementation of several different aspect classes and other types in the `Moyou.Aspects.Memento` namespace: 

- `MementoAttribute`, a type aspect which is used to decorate the originator and which handles generating the main logic of creating and restoring from memento objects.

- `MementoCreateHookAttribute` and `MementoRestoreHookAttribute` are method aspects that can be used to mark methods with a compatible signature on the originator to hook into the process of creating a memento or restoring from a memento.

- `MementoIgnoreAttribute` is an empty attribute class which is used to mark members the memento implementation should ignore.

- Furthermore, the package also introduces `IMemento` and `IOriginator` interfaces as outlined in @copyctor and @propertysetter. 

- Lastly, the enumerables `StrictnessMode` and `MemberMode` are used for configuration purposes. When consumers put the `[Memento]` attribute on a type, they can optionally configure the `StrictnessMode` and `MemberMode` of the Memento implementation by setting these properties via the attribute syntax, e.g. `[Memento(StrictnessMode = StrictnessMode.Loose)]`. 

The relationships between these classes are illustrated in @memento_aspects_classdiagram.

#figure(
  image("../../diagrams/memento_aspects_classdiagram.svg"),
  caption: [Class diagram illustrating the types in `Moyou.Aspects.Memento` and the relationships between them]
)<memento_aspects_classdiagram>

When our aspects share data or otherwise depend on each others results, we must define an explicit order in which the aspects shall be executed at compile-time (the default order is alphabetical @metadocs[Ordering aspects]). This order is inverse to the order of execution of the aspects at run-time. This should be intuitive enough in an example of two MethodAspects modifying a method: The aspect which last modified the method will be the first one to have its own code executed and vice versa @metadocs[Ordering aspects].

For memento we must specify the order explicitly, because the `MementoRestoreHookAttribute` and `MementoCreateHookAttribute` both reference types and methods that might only be present on the target methods containing type after the `MementoAttribute` has been executed on it. The required order is shown in @memento_aspectorder.
#figure(
  image("../../diagrams/memento_aspectorder_comp.svg"),
  caption: [Manually defined compile-time order of aspects in the Memento package]
)<memento_aspectorder>
  

=== MementoAttribute <mementoattributeimpl>
As explained in TODO-REFERENCE-CHAPTER, before we begin execution of the `BuildAspect` logic, we first check the eligibility of the target declaration for this aspect. In the case of memento, this is defined as the target type being neither abstract nor an interface: 
```
public override void BuildEligibility(IEligibilityBuilder<INamedType> builder)
{
    base.BuildEligibility(builder);
    builder.MustNotBeAbstract();
    builder.MustNotBeInterface();
}
```

If this check succeeds, `BuildAspect` is called and the aspect executes the following tasks:
==== Find relevant members 
Depending on the setting of `MemberMode`, we either gather only fields, only properties, or all fields and properties of the target type and filter them by by writeability, retaining only members that can be written to at all times (i.e. a property with a `set` method or simply a field), as constructor-only or init-only members cannot be restored later on. We also filter out all members that are marked with the `[MementoIgnore]` attribute and so-called anonymous backing fields: "When you declare a property as shown in the following example, the compiler creates a private, anonymous backing field that can only be accessed through the property's get and set accessors." @dotnetdocs[Auto-Implemented Properties]. Unfortunately, Metalama does not directly offer us a way to recognize a field as a backing field for an auto property, but it's still possible to recognize them via simple string comparison of the field's name, as they always end with a specific string and also contain characters (such as `<` and `>`) that would be illegal in user-provided code, e.g. `<A>k__BackingField`.

==== StrictnessMode diagnostics
If the `StrictnessMode` is set to strict, we now report all members for which we do not have a value retaining copy heuristic in @memento_method_impl as a warning. This means that the reference to the value of the member will be simply copied, which as discussed in @memento_analysis might not always be the intended behaviour. This is also the reason why `StrictnessMode` is set to strict by default, as to force the user to acknowledge that this is how their memento implementation will behave. In order to get rid of the warning, the user then has the choice to either implement `ICloneable` on the object, essentially turning the shallow copy into a deep copy, or simply set the `StrictnessMode` to loose.

==== Configure memento class


==== Implement interfaces


==== Method implementation <memento_method_impl> 



=== CreateHookAttribute and RestoreHookAttribute <createandrestorehookimpl>



== Technical limitations
== Example application of pattern with and without aspects
== Impact and consequences

#pagebreak(weak:true)
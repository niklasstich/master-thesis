= Memento

== Analysis of pattern<memento_analysis>
The memento pattern is a behavioural pattern which allows us to, "without violating encapsulation, capture and 
externalize an object's internal state so that the object can be restored to this state later"@Gamma1994[p.283].
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

When using a language that does not support nested (private) classes, such as C++, one should consider using other language features to achieve a similar encapsulation (for example, using the `friend` keyword in C++ to expose the private fields of the memento class to the originator@Gamma1994[p.287]).

In some literature@Gamma1994[p.285]TODO: where else?, the classes that retrieve and hold the memento from the originator and controls when to restore them is called the caretaker. For example, when using the Command pattern to encapsulate changes to the originator as objects@Gamma1994[p.233], we would designate the command itself as the caretaker of the originator, requesting a memento object before making any changes and reapplying it onto the originator when the Undo method is called@Gamma1994[p. 238]. As outlined before, ideally the caretaker should not have any access to the data stored inside of the memento and should merely hold the memento until it is used to reapply a past state on the originator.

We must also take care to consider whether to shallow or deep copy our originator objects. When creating a shallow copy, we may simply copy all value type values and copy references to child objects into our memento type. When creating a deep copy on the other hand, we must clone all the child objects we hold a reference to (and in turn, copy all the objects that these objects hold references to, and so on). Both approaches have advantages and drawbacks:

- Creating shallow copies of objects is much faster, simpler and cheaper in terms of memory cost than creating deep copies@Gamma1994[p.286].
- When deep copying our originator to create mementos, restoring to a given state is much simpler, as we can simple restore any memento to restore the originator to its state when we created the memento.
- In contrast, when shallow copying, we must take care to not only reapply a memento to the originator itself, but also apply all mementos of child objects the originator holds a reference to, and to always reapply our mementos in the opposite order of the order we made the changes (and hence created the mementos) in.
- When restoring from a deep copy, simply reassigning the cloned child objects back to the originator destroys referential equality as we now point to a different object. This might be a potential problem for some applications.


== Implementation of aspects
To automatically generate code that implements the functionality of the Memento pattern and to account for its possible variations as discussed in @memento_analysis required the implementation of several different aspect classes and other types: The `Moyou.Aspects.Memento` namespace defines `MementoAttribute`, a type aspect which is used to decorate the originator and which handles generating the main logic of creating and restoring from memento objects, `MementoCreateHookAttribute` and `MementoRestoreHookAttribute`, which are method aspects that can be used to mark methods with a compatible signature on the originator to hook into the process of creating a memento or restoring from a memento and `MementoIgnoreAttribute`, an empty aspect class which is used to mark members the memento implementation should ignore. Furthermore, the package also introduces `IMemento` and `IOriginator` interfaces as outlined in @copyctor and @propertysetter. Lastly, the enumerables `StrictnessMode` and `MemberMode` are used for configuration purposes. The relationship between these classes is illustrated in @memento_aspects_classdiagram

#figure(
  image("../../diagrams/memento_aspects_classdiagram.svg"),
  caption: [Class diagram illustrating the types in `Moyou.Aspects.Memento` and the relationships between them]
)<memento_aspects_classdiagram>

== Technical limitations
== Example application of pattern with and without aspects
== Impact and consequences

#pagebreak(weak:true)
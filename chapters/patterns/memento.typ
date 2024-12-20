#import "../../codly/codly.typ": * 
#import "../../config.typ": ct

= Memento<memento>

== Analysis of Pattern<memento_analysis>
The memento pattern is a behavioral pattern@Gamma1994[p. 283] which allows us to, "without violating encapsulation, capture and 
externalize an object's internal state so that the object can be restored to this state later" @Gamma1994[p. 283].
The so-called originator of the pattern is the class which holds the data we want to store and restore and emits
a memento object on call of `GetMemento()`@Gamma1994[p. 284f]. The state that has been captured during the creation of the memento object
can then be restored at a later point by calling the `RestoreMemento(IMemento)` method and passing the memento object@Gamma1994[p. 284f].

Depending on language support, this memento object is usually implemented  
as a private nested class of the originator and implements a generic interface. This has the following advantages: 
+ It ensures that only the originator class itself knows the type and therefore only the originator can read the data
  stored inside of the memento object, preserving encapsulation@Gamma1994[p. 284].
+ We can store the memento object more generically, i.e. the consumer of our originator type does not need to 
  also know about the concrete memento type.
+ If the language supports it, the nested private class can access all of its encapsulating outer classes private fields
  and properties, which enables us to build a quasi-copy constructor on the memento type (see @copyctor) rather than
  assigning the properties of the memento in our `GetMemento()` method (see @propertysetter).


#figure(
  image("../../diagrams/memento/memento_copy_constructor.svg"), 
  caption: [
    Memento class diagram using a copy constructor in the memento type, compare @Gamma1994[p.285]
  ]
)<copyctor>

#figure(
  image("../../diagrams/memento/memento_properties_setter.svg"),
  caption: [Memento class diagram using property setters in the originator type]
)<propertysetter>

When using a language that does not support nested (private) classes, such as C++, one should consider using other language features to achieve a similar encapsulation (for example, using the `friend` keyword in C++ to expose the private fields of the memento class to the originator @Gamma1994[p.287]).

In @Gamma1994[p.285], the class that retrieves and holds the memento from the originator and controls when to restore them is called the caretaker. For example, when using the Command pattern to encapsulate changes to the originator as objects@Gamma1994[p.233], we would designate the command itself as the caretaker of the originator, requesting a memento object before making any changes and reapplying it onto the originator when the Undo method is called@Gamma1994[p. 238]. As outlined before, ideally the caretaker should not have any access to the data stored inside of the memento and should merely hold the memento until it is used to reapply a past state on the originator.

We must also take care to consider whether to shallow or deep copy our originator objects. When creating a shallow copy, we may simply copy all value type values and copy references to child objects into our memento type. For a deep copy on the other hand, we must clone all the child objects we hold a reference to (and in turn, copy all the objects that these objects hold references to, and so on). Both approaches have advantages and drawbacks:

- Creating shallow copies of objects is much faster, simpler and cheaper in terms of memory cost than creating deep copies @Gamma1994[p.286].
- When deep copying our originator to create mementos, restoring to a given state is much simpler, as we can simply restore any memento to restore the originator to its state when we created the memento.
- In contrast, when shallow copying, we have to not only reapply a memento to the originator itself, but also apply all mementos of child objects the originator holds a reference to, and always reapply our mementos in the opposite order of the order we made the changes in (which is the order we created the mementos in).
- When restoring from a deep copy, simply reassigning the cloned child objects back to the originator destroys referential equality as we now point to a different object. This might be a potential problem for some applications.


== Implementation of Aspects
In this section, the implementation of memento using Metalama will be explored. It should be noted that there is an official implementation of the memento pattern by the Metalama developers at @metadocs[Commented examples - Memento], but this example was published after work on this project (and this memento implementation) was started.
=== Aspects and Types
To automatically generate code that implements the functionality of the Memento pattern and to account for its possible variations as discussed in @memento_analysis required the implementation of several different aspect classes and other types in the `Moyou.Aspects.Memento` namespace: 

- `MementoAttribute`, a type aspect which is used to decorate the originator and which handles generating the main logic of creating and restoring from memento objects.

- `MementoCreateHookAttribute` and `MementoRestoreHookAttribute` are method aspects which can be used to mark methods with a compatible signature on the originator to hook into the process of creating a memento or restoring from a memento.

- `MementoIgnoreAttribute` is an empty attribute class which is used to mark members the memento implementation should ignore.

- Furthermore, the package also introduces `IMemento` and `IOriginator` interfaces as outlined in @copyctor and @propertysetter. 

- Lastly, the enum types `StrictnessMode` and `MemberMode` are used for configuration purposes. When consumers put the `[Memento]` attribute on a type, they can optionally configure the `StrictnessMode` and `MemberMode` of the Memento implementation by setting these properties via the attribute syntax, e.g. `[Memento(StrictnessMode = StrictnessMode.Loose)]`. 

The relationships between these types are illustrated in @memento_aspects_classdiagram.

#figure(
  image("../../diagrams/memento/memento_aspects_classdiagram.svg"),
  caption: [Class diagram illustrating the types in `Moyou.Aspects.Memento` and the relationships between them]
)<memento_aspects_classdiagram>

When our aspects share data or otherwise depend on each other's results, we must define an explicit order in which the aspects shall be executed at compile-time (the default order is alphabetical @metadocs[Ordering aspects]). This order is inverse to the order of execution of the aspects at run-time. This should be intuitive enough in an example of two MethodAspects modifying a method: The aspect which last modified the method will be the first one to have its own code executed and vice versa @metadocs[Ordering aspects].

For memento, we must specify the order explicitly, because the `MementoRestoreHookAttribute` and `MementoCreateHookAttribute` both reference types and methods that might only be present on the target methods containing type after the `MementoAttribute` has been executed on it. The required order is shown in @memento_aspectorder.
#figure(
  image("../../diagrams/memento/memento_aspectorder_comp.svg"),
  caption: [Manually defined compile-time order of aspects in the Memento package]
)<memento_aspectorder>
  

=== MementoAttribute <mementoattributeimpl>
As explained in @metalama, before we begin execution of the `BuildAspect` logic, we first check the eligibility of the target declaration for this aspect. In the case of memento, this is defined as the target type being neither abstract nor an interface, as can be seen in @memento_eligibility:
#figure(
```cs
public class MementoAttribute : TypeAspect 
{
  public override void BuildEligibility(IEligibilityBuilder<INamedType> builder)
  {
      base.BuildEligibility(builder);
      builder.MustNotBeAbstract();
      builder.MustNotBeInterface();
  }
}
```, caption: [BuildEligibility method of `MementoAttribute`]
)<memento_eligibility>

If this check succeeds, `BuildAspect` is called and the aspect executes the following tasks.
==== Find Relevant Members<memento_find_members>
Depending on the setting of `MemberMode`, we either gather only fields, only properties, or all fields and properties of the target type and filter them by writeability, retaining only members which can be written to at all times, i.e. a property with a `set` method or simply a non-read-only field, as constructor-only or init-only members cannot be restored later on. We also filter out all members that are marked with the `[MementoIgnore]` attribute and so-called anonymous backing fields of auto-implemented properties: "When you declare a property as shown in the following example [@autoprop_example], the compiler creates a private, anonymous backing field that can only be accessed through the property's get and set accessors." @dotnetdocs["Auto-Implemented Properties (C\# Programming Guide)"].
#figure(
```cs
public class Customer
{
    // Auto-implemented properties for trivial get and set
    public double TotalPurchases { get; set; }
    public string Name { get; set; }
    public int CustomerId { get; set; }

    [...]
}
```,
caption: [Example of C\# auto-implemented properties #cite(<dotnetdocs>, supplement: [shortened from "Auto-Implemented Properties (C\# Programming Guide)"])]
)
<autoprop_example>

These fields are typically intentionally hidden from the user in normal code, but because Metalama accesses compiler information, we get to access these fields. We do want to filter them out though, because in `MemberMode.PropertiesOnly` or `MemberMode.All`, to restore the state of our originator later, it is sufficient to simply reset the property of the backing field to its previous state. We also do not want to set these fields when in `MemberMode.FieldsOnly`, because doing so would change the state of the property using that backing field. 

Unfortunately, Metalama does not directly offer us a way to recognize a field as a backing field for an auto property, but it is still possible to recognize them via a simple string comparison of the field's name, as they always end with a specific string and also contain characters (such as `<` and `>`) that would be illegal in user-provided code, e.g. `<A>k__BackingField`.

==== StrictnessMode Diagnostics<memento_strict_diagnostics>
If the `StrictnessMode` is set to strict, we now report all members for which we do not have a value-retaining copy heuristic in @memento_method_impl as a warning. This means that the reference to the value of the member will be simply copied, which as discussed in @memento_analysis might not always be the intended behavior. This is also the reason why `StrictnessMode` is set to strict by default, as to force the user to acknowledge that this is how their memento implementation will behave. In order to get rid of the warning, the user then has the choice to either implement `ICloneable` on the object, essentially turning the shallow copy into a deep copy or simply set the `StrictnessMode` to loose.

==== Configure Memento Class <memento_configure_child>
Before adding all necessary fields to the memento child type of the originator, we must first check that it is actually present on the target type. In case it is not present, we introduce a new empty class named `Memento` inside the originator. We must then also acquire a reference to our memento type so we can configure it afterwards. All of this can be done quite elegantly via the Metalama `builder.Advice` class:
#figure(
```cs
var res = builder.Advice.IntroduceClass(builder.Target, "Memento", OverrideStrategy.Ignore);
if (res.Outcome == AdviceOutcome.Default)
{
  builder.Diagnostics.Report(
    WarningNoMementoNestedClass.WithArguments(builder.Target),
    builder.Target
  );
}
var nestedMementoType = res.Outcome == AdviceOutcome.Default
    ? res.Declaration
    : builder.Target.NestedTypes.First(NestedTypeIsEligible);
[...]
private static bool NestedTypeIsEligible(INamedType nestedType)
{
    return nestedType is
    {
        Name: "Memento", Accessibility: Accessibility.Private,
        TypeKind: TypeKind.Class or TypeKind.RecordClass or TypeKind.RecordStruct or TypeKind.Struct
    };
}
```, caption: [Introducing `Memento` child class code snippet]
)<memento_introduce_child>
As can be seen in @memento_introduce_child, we can call the `builder.Advice.IntroduceClass` method with our originator class (`builder.Target`) as the declaration target, the string "Memento" as a name and the `OverrideStrategy.None` value to create a nested class with said name inside of our target type. In case the class does not yet exist, the given `res.Outcome` will be equal to `AdviceOutcome.Default`, and we know that we must take our newly created declaration out of the advice result via `res.Declaration`. If it already exists however, `OverrideStrategy.None` tells Metalama to simply do nothing with our given advice, and `res.Outcome` will be equal to `AdviceOutcome.Ignore` instead, in which case we take the first nested type of our target type which matches the criteria for the memento type (name equal to `Memento`, private accessibility, and either a class, struct, record class or record struct).

In case the memento type did not exist yet, we also emit a warning to the user here, stating that the type was automatically generated and that they must use a fully qualified name of the memento type (e.g. `Originator.Memento`) in the signature of any methods marked with `MementoCreateHookAttribute` or `MementoRestoreHookAttribute` or alternatively define the type themselves.

We can then add the required fields to this nested type via `builder.Advice.IntroduceField` as seen in @memento_add_fields_to_memento by simply iterating over the list of relevant members we've found earlier in @memento_find_members, creating a piece of advice for each member with the reference to the nested type, the name and type of the member, specifying to make this field an instance field (rather than a static one) and public accessibility. This list of advice results is then mapped into a list of the declarations they created so we can reference them in @memento_method_impl.

#figure(
```cs
var introducedFieldsOnMemento = IntroduceMementoTypeFields();

IEnumerable<IField> IntroduceMementoTypeFields() => relevantMembers
  .Select(fieldOrProperty => 
      builder.Advice.IntroduceField(nestedMementoType,
        fieldOrProperty.Name, fieldOrProperty.Type,
        IntroductionScope.Instance, buildField: fBuilder =>
          fBuilder.Accessibility = Accessibility.Public
      )
  )
  .Select(r => r.Declaration);
```, caption: [Introducing fields to memento type code snippet]
)<memento_add_fields_to_memento>

==== Implement Interfaces
To keep the concrete memento type hidden from caretakers, we must implement the `IMemento` interface on our new `Memento` type as previously explained in @memento_analysis. We also implement `IOriginator` on the target type in @memento_impl_interfaces.
#pagebreak(weak: true)
#figure(
```cs
builder.Advice.ImplementInterface(nestedMementoType, typeof(IMemento),
  OverrideStrategy.Ignore);
builder.Advice.ImplementInterface(builder.Target, typeof(IOriginator), 
  OverrideStrategy.Override);
```, caption: [Implementing interfaces code snippet]
)<memento_impl_interfaces>


==== Method Implementation <memento_method_impl> 
After finding all relevant members of the type, warning about uncopyable reference types, creating and configuring our memento class and implementing the relevant interfaces, we can now finally implement the actual logic of the memento pattern. First of all, we must introduce two methods to satisfy the `IOriginator` interface we've just implemented on our target type: 
#figure(
```cs
[InterfaceMember]
public void RestoreMemento(IMemento memento)
{
    meta.This.RestoreMementoImpl(memento);
}

[InterfaceMember]
public IMemento CreateMemento()
{
    return meta.This.CreateMementoImpl();
}
```, caption: [Introducing methods to fulfil `IOriginator` interface code snippet]
)<memento_interface_methods>

The two methods shown in @memento_interface_methods have the exact same signature as the methods in the `IOriginator` interface and are defined on our `MementoAttribute` type. They are decorated with the `[InterfaceMember]` attribute, which itself is a specialization of the `TemplateAttribute`. The reason we prefer to use `[InterfaceMember]` over `[Template]` in this case is because Metalama will handle adding the methods to the target type for us: "This attribute instructs Metalama to introduce the member to the target class but _only_ if the ImplementInterface succeeds. If the advice is ignored because the type already implements the interface and `OverrideStrategy.Ignore` has been used, the member will not be introduced to the target type."@metadocs[Implementing Interfaces]. In our case however, we use `OverrideStrategy.Override` to ensure that even if `IOriginator` were already implemented on the type, we will still introduce our methods.

The methods we introduced here are merely stubs that call another method on the type which handles the actual logic. In @memento_restore_implmethod the template required for generating the actual restore implementation is presented. To make this code snippet more easily digestible for readers who are new to compile-time code generation, the lines that are executed at compile-time will be coloured in a shade of pink. The uncoloured lines are lines of code that will only be executed at run-time, and therefore end up in the actual generated code. This convention will be used for the rest of the thesis whenever compile-time and run-time code are mixed in method templates like this.
#codly(
  highlights: (
    ct(0),
    ct(2, start: 5),
    ct(3, start: 5),
    ct(4, start: 5),
    ct(9, start: 20, tag: "[1]", label: <memento_restore_implmethod_metacast>),
    ct(11, start: 9),
    ct(12, start: 9),
    ct(13, start: 9),
    ct(14, start: 13),
    ct(15, start: 15),
    ct(16, start: 15),
    ct(17, start: 13, end:29, tag:"[2]", label: <memento_restore_implmethod_assignment_left>),
    ct(18, start: 14, tag:"[3]", label: <memento_restore_implmethod_assignment_right>),
    ct(19, start: 9),
  ),

)
#figure(
```cs
[Template]
public void RestoreMementoImpl(IMemento memento,
    [CompileTime] INamedType nestedMementoType,
    [CompileTime] IEnumerable<IFieldOrProperty> relevantMembers,
    [CompileTime] IEnumerable<IFieldOrProperty> introducedFieldsOnMemento
)
{
    try
    {
        var cast = meta.Cast(nestedMementoType, memento);
        //prevent multiple enumerations
        var mementoTypeMembers = introducedFieldsOnMemento.ToList();
        foreach (var fieldOrProp in relevantMembers)
        {
            var nestedTypeMember = mementoTypeMembers
              .First(m => m.Name == fieldOrProp.Name)
              .With((IExpression)cast!);
            fieldOrProp.Value =
             nestedTypeMember.Value;
        }
    }
    catch (InvalidCastException icex)
    {
        throw new ArgumentException("Incorrect memento type",
          nameof(memento), icex);
    }
}
```, caption: [`RestoreMementoImpl` method template code snippet]
)<memento_restore_implmethod>
//]

The template for our restore implementation takes several compile-time arguments in order to generate the required logic. First, we must have access to the type information of our memento type, `nestedMementoType`, in order to cast the anonymized `IMemento` object we receive into the proper memento type in line 10. Second, we need references to all the fields and properties on the originator into which the state needs to be restored, and last, we need to have references to the fields on the memento type which we've introduced in @memento_configure_child.

The expression marked in @memento_restore_implmethod_metacast is a compile-time expression using the `meta.Cast` method, but this actually generates a run-time expression with a hard cast, that is, a type cast in the form of `((TTarget)value)` which throws an `ArgumentException` when the cast is invalid, as opposed to a soft cast in the form of `(value as TTarget)` which coalesces to null when the type cast is impossible @dotnetdocs[Type-testing operators and cast expression]. In case said hard cast fails, we wrap the `InvalidCastException` in our own exception with additional context and rethrow it (lines 21-24). 

We then iterate over all members of the originator that must be restored using a `foreach` loop and because this loop iterates over compile-time variables, it remains strictly in our compile-time logic and no loop is generated in the run-time code. We then look for the (single) field on the memento type that matches the name of the field or property and turn our `IFieldOrProperty` reference into an `IFieldOrPropertyInvoker` via the `.With(value)` syntax, which lets us shift the semantics of `nestedTypeMember` from a field on a type to a field on a value, meaning we can now generate an expression that accesses the member of an instance of the concrete memento type. 

We can now simply finish the assignment by assigning the value from the memento to the originator in lines 18-19. We have to be precise about the semantics of `.Value()` in this code snippet, however. Both @memento_restore_implmethod_assignment_left and @memento_restore_implmethod_assignment_right are compile-time expressions (because both `fieldOrProp` and `nestedTypeMember` are compile-time variables), our assignment (the `=` sign) itself is run-time code, and our code is currently executing in a compile-time context, so we could not possibly access the *actual* underlying values of these fields here, but instead merely generate the *syntax* for accessing them. The Metalama compiler then turns this into a run-time expression using the `IExpression` objects the `.Value()` method returns on both sides of the assignment. Again, because we are in a compile-time `foreach` loop iterating over the relevant fields and properties of the originator, we do this for each of these members, generating a line of run-time code on each loop iteration.

Next, we will look at the implementation of the create method, which is a lot more involved than the restore method, in @memento_create_implmethod.
#codly(
  highlights: (
    ct(0),
    ct(1, start: 35, end: 60),
    ct(2, start: 5),
    ct(3, start: 5),
    ct(4, start: 7),
    ct(6, start: 23),
    ct(8, start: 5),
    ct(9, start: 5),
    ct(10, start: 7),
    ct(11, start: 5),
    ct(12, start: 5),
    ct(13, start: 9),
    ct(14, start: 13),
    ct(15, start: 15),
    ct(16, start: 13),
    ct(17, start: 13),
    ct(18, start: 9, tag:"[1]", label: <memento_create_implmethod_value>),
    ct(19, start: 13, end: 35),
    ct(19, start: 16),
    ct(20, start: 9),
    ct(21, start: 11, tag:"[2]", label: <memento_create_implmethod_string>),
    ct(22, start: 9),
    ct(23, start: 13, end: 35),
    ct(23, start: 16),
    ct(24, start: 9, tag:"[3]", label: <memento_create_implmethod_cloneable>),
    ct(25, start: 13, end: 35),
    ct(25, start: 16),
    ct(26, start: 15),
    ct(27, start: 15),
    ct(28, start: 15),
    ct(29, start: 13),
    ct(30, start: 9),
    ct(31, start: 11, tag:"[4]", label: <memento_create_implmethod_enumerable>),
    ct(32, start: 11),
    ct(33, start: 9, tag:"[5]", label: <memento_create_implmethod_default>),
    ct(34, start: 11, end: 33),
    ct(34, start: 14),
    ct(35, start: 5),
  ),
)
#figure(
```cs
[Template]
public IMemento CreateMementoImpl<[CompileTime] TMementoType>(
    [CompileTime] IEnumerable<IFieldOrProperty> relevantMembers,
    [CompileTime] IEnumerable<IFieldOrProperty> introducedFieldsOnMemento
    ) where TMementoType : IMemento, new()
{
    var memento = new TMementoType();
    //prevent multiple enumerations
    var relevantMembersList = relevantMembers.ToList();
    var introducedFieldsOnMementoList =
      introducedFieldsOnMemento.ToList();
    foreach (var sourceFieldOrProp in relevantMembersList)
    {
        var targetFieldOrProp = introducedFieldsOnMementoList
            .Single(memFieldOrProp => 
              memFieldOrProp.Name == sourceFieldOrProp.Name
            )
            .With(memento);
        if (!(sourceFieldOrProp.Type.IsReferenceType ?? false))
            targetFieldOrProp.Value = sourceFieldOrProp.Value;
        else if (sourceFieldOrProp.Type
          .Is(SpecialType.String, ConversionKind.TypeDefinition)
        )
            targetFieldOrProp.Value = sourceFieldOrProp.Value;
        else if (sourceFieldOrProp.Type.Is(typeof(ICloneable)))
            targetFieldOrProp.Value = meta.Cast(sourceFieldOrProp.Type, 
              sourceFieldOrProp.Value is not null ?
              sourceFieldOrProp.Value?.Clone() :
              null
            );
        else if (sourceFieldOrProp.Type
          .Is(SpecialType.IEnumerable_T, ConversionKind.TypeDefinition))
          HandleIEnumerable(sourceFieldOrProp, targetFieldOrProp);
        else
          targetFieldOrProp.Value = sourceFieldOrProp.Value;
    }
    return memento;
}
```, caption: [`CreateMementoImpl` method template code snippet]
)<memento_create_implmethod>

We once again receive `relevantMembers` and `introducedFieldsOnMemento` as compile-time variables to our template method, which this time is a generic method taking `TMementoType` as a type parameter with the constraint that this type must implement `IMemento` and the `new()` constraint, which demands that the type must have a public parameterless constructor.

We then instantiate a new instance of this type in line 7 and assign it to a run-time variable, which is eventually returned in line 38. After collecting our `IEnumerable`s into lists, we again iterate over the relevant members of our originator type, finding the counterpart field in our memento type (once more, in a compile-time loop) and getting its value expression from `.With(memento)`. We now call a compile-time if clause, checking whether our field or property type meets various criteria. Depending on which criteria are met, the expression inside that if block is the expression that will end up in our run-time code:
- If the type is *not* a reference type (@memento_create_implmethod_value), this means it *must be* a value type, the value of which we can simply assign to our memento to copy it@dotnetdocs[Value types]. This handles most built-in primitive types for us, such as `int`, `float` or `bool`, but not the reference types `object`, `string` and `dynamic` and all types that derive from those#footnote[If we want to be pedantic about it, technically all value types also derive from `object`@dotnetdocs[8.2.3 The object type on page 8 Types in the C\# language specification] as they can be cast to the reference type `object`, but doing so (or casting them into any interface type for that matter) requires boxing them on the heap @dotnetdocs[Boxing and unboxing], as the primitive types such as `int` crucially *aren't* reference types themselves.]@dotnetdocs[Built-in types].
- Otherwise, if the type is `string` (or a type that derives from it, @memento_create_implmethod_string), we can also simply assign the reference to it to our memento, because by language definition strings must be immutable in C\#@dotnetdocs[Strings and string literals].
- Otherwise, if the type implements `ICloneable` (@memento_create_implmethod_cloneable), we can use the `.Clone()` method this interface exposes to create a clone of the object @dotnetdocs[ICloneable Interface]. Because the type in question could be potentially nullable, we have to also do a null check before calling the method in order to avoid a NullReferenceException. Because the `ICloneable` interface does not prescribe whether the clone operation must be a shallow or deep copy of the object@dotnetdocs[ICloneable Interface], the user of our memento attribute themselves must be aware of this circumstance and determine if the behavior of a given `.Clone()` implementation is what they intend to do.
- Otherwise, if the type implements the generic `IEnumerable<T>` (@memento_create_implmethod_enumerable), we call another templated method called `HandleIEnumerable`, the implementation of which has been omitted for the sake of brevity from @memento_create_implmethod. This method essentially checks what kind of `IEnumerable<T>` the type is and either clones it using the correct base collection conversion method (such as `ToDictionary` for `Dictionary<T>`) or assigns the reference if the collection is immutable/read-only. As a fallback, any other unrecognized collection types are also simply assigned by reference to the memento object.
- Otherwise, we've exhausted our heuristics (@memento_create_implmethod_default) and don't have enough information about the type to make an informed decision of how to copy it, so we simply assign it to the memento by reference as a default fallback. This is the case that has previously provoked a warning in @memento_strict_diagnostics.

To reiterate, as described earlier, all the assignments using `.Value()` on either side are compile-time expressions that evaluate to run-time expressions in our generated code.

Finally, these template methods we've just defined must be added to our target via a call to `builder.Advice.IntroduceMethod` in `BuildAspect` including all the relevant arguments, but these calls will again be omitted for the sake of brevity.

It is also worth noting that we've opted for the option of assigning the fields of the memento object in the `CreateMemento()` method as outlined in @memento_analysis and more specifically @propertysetter, rather than a copy constructor. This decision was made purely because it seemed simpler to implement it this way at first and the decision stuck until the end. One could have just as easily moved the logic of the `CreateMemento()` method into, say, a separate aspect class which the memento type is marked with, and generated it as a quasi-copy constructor there.

=== CreateHookAttribute and RestoreHookAttribute <createandrestorehookimpl>
Because methods marked with `CreateHookAttribute` and `RestoreHookAttribute` both operate on data of our nested memento type, they share the same definition for their `BuildEligibility` method, which can be seen in @createandrestore_eligibility. We check that the type declaring the method has the `MementoAttribute`, the method has a return type of `void`, has exactly one parameter with the type of our nested memento type and that the method is actually implemented and callable and therefore not abstract.

#figure(
  ```cs
public override void BuildEligibility(IEligibilityBuilder<IMethod> builder)
{
    base.BuildEligibility(builder);
    builder.DeclaringType().MustHaveAspectOfType(typeof(MementoAttribute));
    builder.ReturnType()
      .MustBe(typeof(void), ConversionKind.TypeDefinition);
    builder.HasExactlyOneParameterOfTypeNestedMemento();
    builder.MustNotBeAbstract();
}
  ```, caption: [`BuildEligibility` method for `MementoCreateHookAttribute` and `MementoRestoreHookAttribute` code snippet]
)<createandrestore_eligibility>

In @createhook_buildaspect_template we see the `BuildAspect` implementation for `MementoCreateHookAttribute`, which is quite simple. We first look for the `CreateMemento` method on the containing type of our target method and, given we were able to find it, call `builder.Advice.Override` on it with our `CreateMementoTemplate`, which takes in a reference to the target of this attribute declaration. Because we passed the reference to the original `CreateMemento()` method as the first argument to the override call, this means that the compile-time `meta.Proceed()` call in our template is converted to a run-time call to the `CreateMemento()` method, the result of which we save into a `memento` variable. We then call `target.Invoke(memento)`, which is converted to a run-time call to the hook method, before finally returning the memento. Note that the `dynamic` return type of this template is a syntax limitation of template methods and is replaced by Metalama with the actual return type of `meta.Proceed()`, which as discussed is `CreateMemento()`, and therefore the return type is `IMemento`.

The implementation of `MementoRestoreHookAttribute` is analogous to the implementation of `MementoCreateHookAttribute` so it won't be shown here; the only relevant difference between the two is that we look for a method named `RestoreMemento` instead of `CreateMemento` in `BuildAspect` and we call a different template which gets its memento variable from the method parameter of said `RestoreMemento` method via `target.Parameters` before passing it to the hook method.
#pagebreak(weak: true)

#codly(
  highlights: 
  (
    ct(15),
    ct(16, start: 38, end: 51),
    ct(18, start: 19),
    ct(19, start: 5),
  )
)

#figure(
```cs
public override void BuildAspect(IAspectBuilder<IMethod> builder)
{
    base.BuildAspect(builder);
    var createMementoMethod = 
      builder.Target.DeclaringType
        .Methods
        .FirstOrDefault(method => method.Name == "CreateMemento");
    if (createMementoMethod == null)
        return;
    builder.Advice
      .Override(createMementoMethod, nameof(CreateMementoTemplate),
        args: new { target = builder.Target, }
      );
}

[Template]
public dynamic CreateMementoTemplate(IMethod target)
{
    var memento = meta.Proceed();
    target.Invoke(memento);
    return memento!;
}
```, caption: [`MementoCreateHookAttribute` `BuildAspect` and template methods code snippet]
)<createhook_buildaspect_template>


== Example Application of Pattern
In @memento_full_example_diff we find a full example of how a class that uses all the memento attributes presented in this chapter is modified by them. The code is presented as a unified diff, which means all the lines with a leading `+`, shown in green, are added lines; all the lines with a leading `-`, shown in red, are removed lines. All gray lines stay the same between input and output, meaning our aspects have not touched them.

As we can see, our `MementoDummy` input class is largely unchanged except for the fact that we implemented the `IOriginator` interface in line 9 and the introduction of the `CreateMemento()` and `RestoreMemento()` methods (and their internal backing implementations) in lines 62-112. We also find that the predefined `Memento` record was retained, expanding it with an implementation of `IMemento` and adding the required fields to it. In lines 67 to 70, we see that the `MementoCreateHookAttribute` has changed the implementation of `CreateMemento()` by injecting a call to the user-provided hook method. Crucially, it must be noted that this method is called *after* our memento implementation has created the memento object; this is so that the user can override the implementation for certain members if they choose to do so.

We also see that, depending on what the type of a member is, different strategies are used for copying it, as explained in @memento_method_impl; as such the `string` B is not copied via its `Clone()` method but simply by reference, but the `CloneableDummy M` property is cloned and all value types `int` are copied via assignments. We also see that the property F is ignored, and so are all properties that have no always callable setter, such as C (because it only has an `init` setter) or the computed property I. Finally, we see that the hook methods `CreateHook` and `RestoreHook` are called after the respective create or restore implementation was called.
#figure(
```diff
 [Memento(StrictnessMode = StrictnessMode.Loose)]
-internal partial class MementoDummy
+internal partial class MementoDummy: IOriginator
 {
     public int A { get; set; }
     private string B { get; set; }
     internal string? C { get; init; }
 
     public int D;
     private object _e;
 
     public object E { get => _e; set => _e = value; }
 
     [MementoIgnore]
     public int F { get; set; }
     public int G { get; }
     public int H { get => 123; }
     public int I => 123;
     protected readonly object _j;
     public readonly object K;
     public List<object> L { get; set; }
 
     public CloneableDummy M { get; set; }
     public Dictionary<int,int> N { get; set; }
     public List<CloneableDummy> O { get; set; }
 
 
     [MementoIgnore]
     public string? Hook { get; set; }
 
     [MementoCreateHook]
     private void CreateHook(Memento memento)
     {
         memento.Hook = "hook set";
     }
 
     [MementoRestoreHook]
     private void RestoreHook(Memento memento)
     {
         this.Hook = memento.Hook + " and restored";
     }
 
 
-    private record Memento
+    private record Memento: IMemento    
     {
         public string? Hook { get; set; }
+        public int A;
+        public string B;
+        public int D;
+        public object E;
+        public List<object> L;
+        public CloneableDummy M;
+        public Dictionary<int, int> N;
+        public List<CloneableDummy> O;
+        public object _e;
     }
+
+    public IMemento CreateMemento()
+    {
+        IMemento memento;
+        memento = this.CreateMementoImpl();
+        CreateHook((Memento)memento);
+        return memento!;
+    }
+
+    private IMemento CreateMementoImpl()
+    {
+        var memento = new Memento();
+        memento.D = D;
+        memento._e = _e;
+        memento.A = A;
+        memento.B = B;
+        memento.E = E;
+        memento.L = L.ToList();
+        memento.M = (CloneableDummy)(M is not null ? M.Clone() : null);
+        memento.N = N.ToDictionary();
+        memento.O = O.ToList();
+        return memento;
+    }
+
+    public void RestoreMemento(IMemento memento)
+    {
+        this.RestoreMementoImpl(memento);
+        var memento_1 = memento;
+        RestoreHook((Memento)memento_1);
+    }
+
+    private void RestoreMementoImpl(IMemento memento)
+    {
+        try
+        {
+            var cast = (Memento)memento;
+            D = cast!.D;
+            _e = cast!._e;
+            A = cast!.A;
+            B = cast!.B;
+            E = cast!.E;
+            L = cast!.L;
+            M = cast!.M;
+            N = cast!.N;
+            O = cast!.O;
+        }
+        catch (InvalidCastException icex)
+        {
+            throw new ArgumentException("Incorrect memento type",
+              nameof(memento), icex);
+        }
+    }
 }
 
 public class CloneableDummy : ICloneable
 {
     public int Foo { get; set; }
     public object Clone()
     {
         return new CloneableDummy
         {
             Foo = Foo
         };
     }
 }
```, caption: [Example of memento aspects being applied to a full example class]
)<memento_full_example_diff>

== Technical Limitations <memento_tech_limitations>
In earlier versions of Metalama before the release of 2024.2, it was not possible to introduce new classes to a compilation. This meant that the user had to provide the nested memento type predefined in their code for us, which would then be filled with the implementation at compile-time. The `BuildEligibility` method of `MementoAttribute` would check for the presence of this type and would report a compile error diagnostic if it was missing. Since the said Metalama version was released, however, we can now simply introduce the type ourselves as shown in @memento_configure_child, so this check could be removed. The user's ability to define the type themselves was retained however, as to give the user the option to add custom fields or properties to the memento type for use in create and restore hook methods.

To make it possible for users to call methods that Metalama generates from their code, a .NET source generator is injected into all projects using one or more Metalama aspects. This source generator generates partial classes of our target types that include "fake" and empty stub implementations of the methods (and types) we introduce in our aspect logic, which are replaced by the actual implementations during the compilation process. Because of a C\# syntax limitation, we must declare our target types as `partial` to be able to access this generated code.

Another limitation is that if the nested type is not defined in user code and instead generated by `MementoAttribute`, it becomes impossible to define a Create- or RestoreMemento hook method that refers to the memento type using just its name; instead one has to refer to the type using its fully qualified name (e.g. `YourProject.YourNamespace.OriginatorType.Memento`).

To make using the memento aspects and the implementations they generate easier, it would be nice to generate XML documentation on the members and types we introduce. These are comment lines that start with a triple slash `///` instead of the usual double slash `//` and support a special XML syntax for describing types, methods, their parameters and return types, exceptions and other useful information@dotnetdocs[Documentation comments]@dotnetdocs[Recommended XML tags for C\# documentation comments]. Unfortunately, this is largely impossible for now, as Metalama does not support adding comments of any sort to methods that have been introduced via `Advice.IntroduceMethod` (yet).

== Impact and Consequences of Implementation<memento_consequences>
Aside from the consequences of the memento pattern mentioned in @Gamma1994[p. 286f] such as the preservation of encapsulation of the originator and simplification of the originator by making the caretaker store the captured state, automating the implementation of this pattern has several advantages in itself:

+ *Memento implementation is robust against changes to the originator and its members:* When we add new data to a class on which we implemented the memento pattern "by hand", i.e. not via an automated code generation technique such as the aspect at hand, we must take care not to forget to update both our nested memento type by adding a new field to it and the implementations of the create and restore methods on the originator by restoring from/storing to the new field. If we forget to adapt the implementation of *either or both* the create or restore method, then we've just introduced a bug and our memento implementation won't work as intended. In contrast, when using something like this aspect to automate generating our logic, simply adding the member to the originator suffices to also update the memento implementation. This gives us the guarantee that no matter how many new members we add to our originators, the memento implementation will always be correct (barring the copy limitations mentioned in @memento_strict_diagnostics). Another example of how to easily introduce another bug in the manual implementation is to implement `ICloneable` on a type of which our originator holds two references to two separate objects to (or even worse, multiple originators) because we now require to do a deep copy of the objects, but only changing the implementation of `CreateMemento()` to use the new `Clone()` method on one of the child objects; this case is also mitigated by the automatic nature of our code generation.
+ *Fulfils the DRY principle:* In a sense, the previous advantage also means that our codebase adheres to the DRY (Don't Repeat Yourself)@Hunt1999[p. 30] principle more strictly when using metaprogramming such as this memento aspect. As Hunt states, following this principle means that "[e]very piece of knowledge must have a single, unambiguous, authoritative representation within a system." @Hunt1999[p. 30]. By utilizing metaprogramming, we can move the definition of the behavior of parts of our system into a higher level of abstraction (namely aspect-oriented programming). Instead of defining "because the type of member Foobar on originator class XYZ is an array, we must copy this member as an array" on every occurrence of an array-typed member in every originator by way of writing the line of code that copies the array by hand (which is code duplication), we can now define much more succinctly that "every member in every originator class which is an array type will be copied as an array" by way of writing compile-time code *that generates code* that will copy the array. This means that, should we for example develop a new heuristic for how to copy a certain type in our codebase, a single change to the memento aspect is enough to change every occurrence of this type in all of our memento implementations.
+ *Fulfills the SRP:* In the same way that moving our memento logic into the aspect class generating the memento implementation makes our code adhere to the DRY principle, this also holds true for the SRP (Single Responsibility Principle) proposed by Robert Martin in @Martin2012, which "states that a class [...] should have one, and only one, _reason to change_"@Martin2012[p. 138]. We see that a class that implements the memento pattern has two reasons to change: Either, because the business logic of the class itself has changed (for example, new members are added or methods are changed) *or* because the way we need to implement the memento on the type has changed (see the previous `ICloneable` child object example). Or in other words, the type has two responsibilities; it needs to be able to do whatever the business logic of the type itself is and it needs to know how to store and restore its own state to and from a memento of itself. There are multiple reasons why breaking the SRP is a bad idea, but the main problem is maintainability. As Martin states, we want to "organize it [logic and complexity] so that a developer knows where to look to find things"@Martin2012[p. 139f]. In our memento example at hand, we might want to look at (or even change) how the memento implementation works on our business types. If we were to manually implement it, because every single type implementing memento has its own implementation baked into the type, this is not necessarily an easy task. One might now say that this is just how things are because the SRP and principles of encapsulation sometimes clash with each other and we need to simply pick the lesser of the two evils when deciding which principle to break. We want to offer an alternative viewpoint here. If we slightly reword the SRP to state that "the *explicit implementation* of a class [...] should have one, and only one, _reason to change_"@Martin2012[compare p. 138], with "explicit implementation" referring to the actual source code that is written manually by developers and excluding auto-generated code, like what a Metalama aspect generates, then we can say that using the memento aspect to implement memento on our types fulfils this principle. The reason why adjusting the wording of the principle to this is useful is because it still adheres to the spirit of it: As stated previously, the reason we should strive not to break the SRP is because it makes it easier to find information in our codebase. When we use an aspect to implement memento, we know exactly where to look to find the implementation of memento across our types, namely in the aspect itself, rather than in every type that implements memento explicitly. It is also not very useful to think of the explicit code and the auto-generated code of a class as the same thing, because the entire point of using metaprogramming techniques like Metalama aspects is to abstract away and hide the code (and the complexity that comes with it) away from the programmer.
+ *Shifting testing workload from run-time to compile-time code:* Because we now write code that writes code, it is both much easier and harder at the same time to verify that our final code does what it is intended to do. On one hand, we don't have to manually test every line of every occurrence of the memento run-time implementation that our aspect generates, because it will generate the same output implementation for the same input (think two classes with the same or same type of members but different class or member names) and we can simply verify once that that implementation is correct. On the other hand, we've now moved the problem of test case explosion and the impossibility of testing exhaustively from the realm of the run-time implementation into the realm of the compile-time code generating it: We cannot possibly test every input to our memento aspect that could be generated because that would be any and all valid syntax C\# classes ever, which is a proper class (in the sense of Zermelo-Fraenkel set theory, as it is a class that is not a set@Jech1978[p. 3f]) of infinite size. That said, in practical terms, it is usually good enough to test the aspects against a known, reasonable set of classes including those with known complications (for an example of this, see the `Memento` folder of the `Moyou.CompileTimeTest` project).

#pagebreak(weak:true)
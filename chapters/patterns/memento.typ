#import "../../codly/codly.typ": * 
#import "../../config.typ": ct

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

We must also take care to consider whether to shallow or deep copy our originator objects. When creating a shallow copy, we may simply copy all value type values and copy references to child objects into our memento type. For a deep copy on the other hand, we must clone all the child objects we hold a reference to (and in turn, copy all the objects that these objects hold references to, and so on). Both approaches have advantages and drawbacks:

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
As explained in TODO-REFERENCE-CHAPTER, before we begin execution of the `BuildAspect` logic, we first check the eligibility of the target declaration for this aspect. In the case of memento, this is defined as the target type being neither abstract nor an interface, as can be seen in @memento_eligibility:
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
==== Find relevant members<memento_find_members>
Depending on the setting of `MemberMode`, we either gather only fields, only properties, or all fields and properties of the target type and filter them by by writeability, retaining only members that can be written to at all times (i.e. a property with a `set` method or simply a non-readonly field), as constructor-only or init-only members cannot be restored later on. We also filter out all members that are marked with the `[MementoIgnore]` attribute and so-called anonymous backing fields of auto-implemented properties: "When you declare a property as shown in the following example [@autoprop_example], the compiler creates a private, anonymous backing field that can only be accessed through the property's get and set accessors." @dotnetdocs["Auto-Implemented Properties (C\# Programming Guide)"].
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

These fields are usually intentionally invisible to the user in normal code, but because Metalama accesses compiler information, we get to access these fields. We do want to filter them out though, because in `MemberMode.PropertiesOnly` or `MemberMode.All`, to restore the state of our originator later, it is sufficient to simply reset the property a backing field belongs to to it's previous state. We also do not want to set these fields when in `MemberMode.FieldsOnly`, because doing so would change the state of the property using that backing field. 

Unfortunately, Metalama does not directly offer us a way to recognize a field as a backing field for an auto property, but it's still possible to recognize them via simple string comparison of the field's name, as they always end with a specific string and also contain characters (such as `<` and `>`) that would be illegal in user-provided code, e.g. `<A>k__BackingField`.

==== StrictnessMode diagnostics
If the `StrictnessMode` is set to strict, we now report all members for which we do not have a value retaining copy heuristic in @memento_method_impl as a warning. This means that the reference to the value of the member will be simply copied, which as discussed in @memento_analysis might not always be the intended behaviour. This is also the reason why `StrictnessMode` is set to strict by default, as to force the user to acknowledge that this is how their memento implementation will behave. In order to get rid of the warning, the user then has the choice to either implement `ICloneable` on the object, essentially turning the shallow copy into a deep copy, or simply set the `StrictnessMode` to loose.

==== Configure memento class <memento_configure_child>
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
```, caption: [Introducing "Memento" child class code snippet]
)<memento_introduce_child>
As we can see in @memento_introduce_child, we can call the `builder.Advice.IntroduceClass` method with our originator class (`builder.Target`) as the declaration target, the string "Memento" as a name and the `OverrideStrategy.None` value to create a nested class with said name inside of our target type. In case the class does not yet exist, the given `res.Outcome` will be equal to `AdviceOutcome.Default`, and we know that we must take our newly created declaration out of the advice result via `res.Declaration`. If it already exists however, `OverrideStrategy.None` tells Metalama to simply do nothing with our given advice, and `res.Outcome` will be equal to `AdviceOutcome.Ignore` instead, in which case we take the first nested type of our target type which matches the criteria for the memento type (name equal to `Memento`, private accessibility, and either a class, struct, record class or record struct).

In case that the memento type did not exist yet, we also emit a warning to the user here, stating that the type was automatically generated and that they must use a fully qualified name of the memento type (e.g. `Originator.Memento`) in the signature of any methods marked with `MementoCreateHookAttribute` or `MementoRestoreHookAttribute` or alternatively define the type themselves. The reason for this limitation will be explained in @memento_tech_limitations.

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

==== Implement interfaces
In order to keep the concrete memento type hidden from caretakers, we must implement the `IMemento` interface on our new `Memento` type as previously explained in @memento_analysis. We also implement `IOriginator` on the target type in @memento_impl_interfaces.
#figure(
```cs
builder.Advice.ImplementInterface(nestedMementoType, typeof(IMemento),
  OverrideStrategy.Ignore);
builder.Advice.ImplementInterface(builder.Target, typeof(IOriginator), 
  OverrideStrategy.Override);
```, caption: [Implementing interfaces code snippet]
)<memento_impl_interfaces>


==== Method implementation <memento_method_impl> 
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
```, caption: [Introducing methods to fulfill `IOriginator` interface code snippet]
)<memento_interface_methods>

The two methods shown in @memento_interface_methods have the exact same signature as the methods in the `IOriginator` interface and are defined on our `MementoAttribute` type. They are decorated with the `[InterfaceMember]` attribute, which itself is a specialization of the `TemplateAttribute` introduced in TODO-REFERENCE-CHAPTER. The reason we prefer to use `[InterfaceMember]` over `[Template]` in this case is because Metalama will handle adding the methods to the target type for us: "This attribute instructs Metalama to introduce the member to the target class but _only_ if the ImplementInterface succeeds. If the advice is ignored because the type already implements the interface and `OverrideStrategy.Ignore` has been used, the member will not be introduced to the target type."@metadocs[Implementing Interfaces]. In our case however, we use `OverrideStrategy.Override` to ensure that even if `IOriginator` were already implemented on the type, we will still introduce our methods.

The methods we introduced here are merely stubs that call another method on the type which handles the actual logic. In @memento_restore_implmethod we can see the template for generating the actual restore implementation. In order to make this code snippet more easily digestable for readers that are new to compile-time code generation, the lines that are executed at compile-time will be coloured in a shade of pink. The uncoloured lines are lines of code that will only be executed at run-time, and therefore end up in the actual generated code. This convention will be used for the rest of the paper whenever compile-time and run-time code are mixed in method templates like this.
#codly(
  highlights: (
    ct(0),
    ct(2, start: 5),
    ct(3, start: 5),
    ct(4, start: 5),
    ct(9, start: 22, tag: "[1]", label: <memento_restore_implmethod_metacast>),
    ct(11, start: 9),
    ct(12, start: 9),
    ct(13, start: 9),
    ct(14, start: 13),
    ct(15, start: 15),
    ct(16, start: 15),
    ct(17, start: 13, end:27, tag:"[2]", label: <memento_restore_implmethod_assignment_left>),
    ct(18, start: 15, tag:"[3]", label: <memento_restore_implmethod_assignment_right>),
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
        throw new ArgumentException("Incorrect memento type", nameof(memento), icex);
    }
}
```, caption: [`RestoreMementoImpl` method template code snippet]
)<memento_restore_implmethod>
//]

The template to our restore implementation takes several compile-time arguments in order to generate the required logic. First, we must have access to the type information of our memento type, `nestedMementoType`, in order to cast the anonymized `IMemento` object we receive into the proper memento type in line 10. Second, we need references to all the fields and properties on the originator into which the state needs to be restored, and last, we need to have references to the fields on the memento type which we've introduced in @memento_configure_child.

The expression marked in @memento_restore_implmethod_metacast is a compile-time expression using the `meta.Cast` method, but this actually generates a run-time expression with a hard cast, a type cast in the form of `((TTarget)value)` which throws an `ArgumentException` when the cast is invalid, as opposed to a soft cast in the form of `(value as TTarget)` which coalesces to null when the type cast is impossible @dotnetdocs[Type-testing operators and cast expression]. In case said hard cast fails, we wrap the `InvalidCastException` in our own exception with additional context and rethrow it (lines 21-24). 

We then iterate over all members of the originator that must be restored, look for the (single) field on the memento type that matches it's name, and turn our `IFieldOrProperty` reference into an `IFieldOrPropertyInvoker` via the `.With(value)` syntax, which lets us shift the sematics of `nestedTypeMember` from a field on a type to a field on a value.

Now can now simply finish the assignment by assigning the value from the memento to the originator in line 18-19. We have to be precise about the semantics of `.Value()` in this code snippet however. Both @memento_restore_implmethod_assignment_left and @memento_restore_implmethod_assignment_right are compile-time expressions (because both `fieldOrProp` and `nestedTypeMember` are compile-time variables), our assignment (the `=` sign) itself is run-time code, and our code is currently executing in a compile-time context, so we could not possibly access the *actual* underlying values of these fields here, but instead merely generate the *syntax* for accessing them. The Metalama compiler then turns this into a run-time expression using the `IExpression` objects the `.Value()` method returns on both sides of the assignment.



#figure(
```cs
[Template]
public IMemento CreateMementoImpl<[CompileTime] TMementoType>(
    [CompileTime] IEnumerable<IFieldOrProperty> relevantMembers,
    [CompileTime] IEnumerable<IFieldOrProperty> introducedFieldsOnMemento,
    IAspectBuilder<INamedType> builder) where TMementoType : IMemento, new()
{
    var memento = new TMementoType();
    //prevent multiple enumerations
    var relevantMembersList = relevantMembers.ToList();
    var introducedFieldsOnMementoList = introducedFieldsOnMemento.ToList();
    foreach (var sourceFieldOrProp in relevantMembersList)
    {
        var targetFieldOrProp = introducedFieldsOnMementoList
            .Single(memFieldOrProp => memFieldOrProp.Name == sourceFieldOrProp.Name).With(memento);
        if (!(sourceFieldOrProp.Type.IsReferenceType ?? false))
            targetFieldOrProp.Value = sourceFieldOrProp.Value;
        else if (sourceFieldOrProp.Type.Is(SpecialType.String, ConversionKind.TypeDefinition)) //strings are immutable
            targetFieldOrProp.Value = sourceFieldOrProp.Value;
        else if (sourceFieldOrProp.Type.Is(typeof(ICloneable)))
        {
            targetFieldOrProp.Value = meta.Cast(sourceFieldOrProp.Type,
                sourceFieldOrProp.Value is not null ? sourceFieldOrProp.Value?.Clone() : null);
        }
        else if (sourceFieldOrProp.Type.Is(SpecialType.IEnumerable_T, ConversionKind.TypeDefinition))
        {
            HandleIEnumerable(sourceFieldOrProp, targetFieldOrProp, builder);
        }
        else
        {
            targetFieldOrProp.Value = sourceFieldOrProp.Value;
        }
    }
    return memento;
}
```, caption: [`CreateMementoImpl` method template code snippet]
)<memento_create_implmethod>


=== CreateHookAttribute and RestoreHookAttribute <createandrestorehookimpl>



== Technical limitations <memento_tech_limitations>
== Example application of pattern with and without aspects
== Impact and consequences

#pagebreak(weak:true)
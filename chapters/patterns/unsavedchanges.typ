#import "../../codly/codly.typ": * 
#import "../../config.typ": ct

= Unsaved Changes<unsaved_changes>

== Analysis of Pattern<unsaved_changes_analysis>

The pattern described in this section is certainly nothing new, and the author of this work is not claiming to have invented a new pattern here, however, it is very difficult to find any substantial literature on it#footnote([The closest thing that can be found is the "dirty flag" pattern, which is often used in games or other applications where performance is critical, to only perform certain operations exactly when they are needed. Both the problem that's being solved with that pattern and the solution to the problem are different to what will be explained here because we are more concerned with notifying our UI whether *any* object in our hierarchy has changed rather than saving operations at an object level. An example analysis of that pattern can be found at https://gameprogrammingpatterns.com/dirty-flag.html.]). As such, we will first describe the problem it tries to solve here, then propose a systematic solution to it, before going into how to automate implementing it.

In modern applications that allow users to edit files of any sort, it is very common to give users an indication whenever a file or open context of any sort has any changes that have not been saved yet. Two different examples can be observed in @unsaved_changes_example_images. There are many different ways we can handle a user's unsaved changes, the first example is a blocking modal dialogue that prevents the user from closing the application until they select how to proceed, and the second example is a much more subtle way of informing the user, which is acceptable in this scenario, as the application in question actually persists unsaved changes when it is closed and reopened.

#figure(
  grid(columns: 2, row-gutter: 2mm, column-gutter: 2mm,  
  box(image("../../Bilder/unsaved_changes_authoringtool.png"), stroke: (paint: black, thickness: 1pt)), image("../../Bilder/unsaved_changes_vscode.png"), 
  ["a) AdLer authoring tool"#footnote("https://github.com/ProjektAdLer/Autorentool")], ["b) Visual Studio Code"#footnote("https://code.visualstudio.com/")]),
  caption: ["Examples of software with user interfaces that warn or inform the user of unsaved changes"]
)<unsaved_changes_example_images>

To implement a feature like this, we have two options: Either we let our UI keep track of whenever any input is made to it that necessitates a save (which is a bad idea for hopefully obvious reasons, but to name a few: it would violate MVC/MVVC architecture, violate SRP and necessitate closer coupling of UI components so they can communicate the unsaved changes state between each other) or we make the data that we operate on track whenever any changes have been made to it that have not yet been saved.

To illustrate this problem better, we will introduce an example. Imagine we are creating a simple video game in which the player can collect and equip items, and said items have durability. Whenever *any* state in our game changes, we want to be able to track this information to know when to prompt the player to save the game. In @unsaved_changes_item_example we find a basic example of how we can implement a property to keep track of unsaved changes in our item classes. We also add a method to reset the `UnsavedChanges` property back to false.

#figure(
```cs
public interface UnsavedChanges 
{
  bool UnsavedChanges { get; }
  void ResetUnsavedChanges();
}
public interface Item : UnsavedChanges
{
  string Name { get; }
  int Durability { get; set; }
}

public class Weapon : Item
{
  public Weapon(string name, int durability)
  {
      Name = name;
      Durability = durability;
  }

  private int _durability;

  public string Name { get; }
  
  public int Durability { 
    get => _durability;
    set 
    {
      if(_durability == value) return;
      _durability = value;
      UnsavedChanges = true;
    }
  }

  public bool UnsavedChanges { get; private set; }

  public void ResetUnsavedChanges() 
  {
    UnsavedChanges = false;
  }
}
```, caption: [Example of a basic DTO with UnsavedChanges property]
)<unsaved_changes_item_example>

This solution works perfectly fine for the single simple class shown here, but as soon as we add more classes into a hierarchy of sorts, the logic of `UnsavedChanges` becomes a lot more tedious to maintain, as we now need to consider the object itself and all child objects it holds references to. We now add a Player class that can wear one weapon and hold a variety of items in its inventory in @unsaved_changes_player_example. As we can see, we now need to consider not only the player object itself for its unsaved changes, but also all objects it holds a reference to. The `ResetUnsavedChanges()` method now also becomes more complex, because we need to reset the player and all the objects in the hierarchy.

#figure(
```cs
public class Player 
{
  public Player()
  {
    EquippedWeapon = null;
    Inventory = new List<Item>();
    UnsavedChanges = true;
  }
  private bool _unsavedChanges;
  private Weapon? _equippedWeapon;

  public List<Item> Inventory { get; private set; }
  public Weapon? EquippedWeapon 
  {
    get => _equippedWeapon;
    set 
    {
      if(_equippedWeapon == _value) return;
      _equippedWeapon = _value;
      UnsavedChanges = true;
    }
  }

  public bool UnsavedChanges 
  {
    get => _unsavedChanges || EquippedWeapon?.UnsavedChanges ||
      Inventory.Any(item => item.UnsavedChanges);
    set
    {
      _unsavedChanges = value;
    }
  }

  public void ResetUnsavedChanges() 
  {
    _unsavedChanges = false;
    EquippedWeapon?.ResetUnsavedChanges();
    foreach(var item in Inventory)
    {
      item.ResetUnsavedChanges();
    }
  }
}
```, caption: [Player class holding references to the weapons from @unsaved_changes_item_example]
)<unsaved_changes_player_example>

Now imagine that our object hierarchy is dozens of classes that have dependencies between each other much more complex than in this example (like a composite@Gamma1994[p. 163] structure for example), and it should hopefully be quite obvious that this leads to a very brittle implementation that is error-prone when we forget to add a check for a new member in one of our `UnsavedChanges` properties or forget to reset a member in our `ResetUnsavedChanges()` methods. This is actually a real issue that has happened multiple times while the author was a part of the AdLer project and working on the authoring tool of said project, the screenshot of which was shown in @unsaved_changes_example_images. The check for whether there are unsaved changes basically devolves into a tree search problem where we need to keep looking through our entire tree structure until we either a) find any node that has unsaved changes or b) exhaust the tree. Resetting the unsaved changes property similarly becomes a tree traversal problem where we must visit every node and call `ResetUnsavedChanges()`. 

The problem with this design is that, once again, it breaks the SRP. Our `Player` class is now responsible for doing a multitude of different things:
+ It is responsible for holding its own functional state (the properties `Inventory` and `EquippedWeapon`)
+ It is responsible for deciding when it has unsaved changes and in doing so is responsible for checking whether its members have unsaved changes
+ It is responsible for resetting its own unsaved changes state and the unsaved changes state of its members

We should note that there are two possible ways to implement tracking the changes of an object. The first possibility is the object itself tracking whenever it has been changed via its property setters, as shown in the examples @unsaved_changes_item_example and @unsaved_changes_player_example. The other possibility is that whatever business logic decides how and when to change our object's state also decides when it has made changes to an object that constitute unsaved changes and sets the property from the outside accordingly. This would at least partially mitigate the second problem of responsibility above (the object still needs to keep track of the property itself), which is why this is the way we chose to implement unsaved changes in the aspect implementation that follows shortly in @unsaved_changes_implementation. It would however be entirely feasible to automate the first option by adjusting the aspect to hook into something like an automatic `NotifyPropertyChanged` implementation#footnote([Such as https://doc.postsharp.net/metalama/examples/notifypropertychanged for example]).

It is also worth talking about the state pattern and why we believe it should not find application here. Using the state pattern, we can "[a]llow an object to alter its behavior when its internal state changes."@Gamma1994[p. 305] by assigning an object that encapsulates the current state to a state member on our object@Gamma1994[p. 305f]. In theory, we could use this pattern instead of the boolean property `UnsavedChanges` and encapsulate the state into two classes `HasUnsavedChanges` and `NoUnsavedChanges`. We could then implement a method `HasUnsavedChanges()` on the two state objects that return `true` and `false` accordingly. The issue with this is that we haven't done anything to solve our original problem of having to traverse the tree of our members which we still need to do with this implementation. This means that either we need to make strategy types for each type in our hierarchy which knows what members of the type itself to check for unsaved changes, or ask the type directly by retaining the `UnsavedChanges` property implementation for the member objects, meaning we'd have effectively gained nothing. Another, even worse, idea is to make parent objects register on an event#footnote([Compare C\# events@dotnetdocs[event (C\# reference)] with observer pattern in @Gamma1994[p. 293ff]]) on their members and having the members notify their parents whenever their strategy object changes, giving the parent object a chance to update their own strategy. This would create an impenetrable mess of double-references from parents to children and back which is certainly possible to implement, but one has to ask oneself if that is truly an improvement in maintainability compared to the proposed example.

The usage of many different other patterns could be discussed here, for example, if we only cared about the fact that *an* object in our hierarchy has changed but never cared about *what part of the object hierarchy* has changed, we could use a mediator@Gamma1994[p. 273ff] to extract and simplify the logic of change notification by making the Player class (or whatever the top object of our hierarchy ends up being) subscribe to the `OnChange` event of some sort of `ChangeTracker` mediator class, passing a reference to this mediator to every member of the hierarchy and making the components call this mediator whenever there is a change, effectively notifying our Player. Using this approach we could find out what concrete object has the change (simply by making the changed object pass itself to the mediator, which passes it to the player), but it would be difficult to identify which subtree of our object structure has changed because of this, which could be something we need if we need to persist subtrees of our hierarchy on change for example. Using C\# delegates@dotnetdocs[Delegates (C\# Programming Guide)] could even eliminate the need for the mediator type. One could also discuss whether the application of the chain of responsibility pattern brings advantages here, but we will do without discussing whether this improves the proposed design in this thesis and move forward with how to automatically implement said design.


== Implementation of Aspects<unsaved_changes_implementation>
The `Moyou.Aspects.UnsavedChanges` namespace consists of only two types: an `IUnsavedChanges` interface which we will implement on our targets and an `UnsavedChangesAttribute` type aspect that handles the implementation of the pattern. These types can be found represented in @unsaved_changes_aspects.

#figure(
  image("../../diagrams/unsaved_changes/unsaved_changes_aspects.svg"),
  caption: [Class diagram illustrating the types in `Moyou.Aspects.UnsavedChanges` and the relationships between them]
)<unsaved_changes_aspects>

This aspect only has a single requirement in its `BuildEligibility` method which is that the type must not be an interface, as these would not make any sense as a target in this context.

Arriving in our `BuildAspect` method, the first thing we do is implement our `IUnsavedChanges` interface as seen in @unsaved_changes_aspects and introduce a field called `_internalUnsavedChanges` of type bool with private accessibility. We then look for all members of the type that are relevant for checking whether we have unsaved changes, meaning all types which themselves are also marked with the `[UnsavedChanges]` attribute. Similarly, we look for all members on our target, the type of which implements `IEnumerable<T>` where type `T` has the `[UnsavedChanges]` attribute applied to it. From both of these collections, we remove all fields which we can identify as backing fields (similar reasoning as in @memento_find_members, merely looking at the property is sufficient). The code so far can be found in @unsaved_changes_implementation_part1.

#codly(
  highlights: 
  (
    ct(38, end: 10),
  )
)
#figure(
```cs
public override void BuildAspect(IAspectBuilder<INamedType> builder)
{
  base.BuildAspect(builder);

  builder.ImplementInterface(typeof(IUnsavedChanges),
    OverrideStrategy.Ignore);

  builder.IntroduceField(nameof(_internalUnsavedChanges),
    IntroductionScope.Instance, 
    buildField:
      fbuilder => { fbuilder.Accessibility = Accessibility.Private; }
  );

  var relevantMembers = builder.Target.AllFieldsAndProperties
    .Where(member => 
      member.TypeHasAttribute(typeof(UnsavedChangesAttribute))
    )
    .Where(member => 
      member is not IField field || !field.IsAutoBackingField()
    )
    .ToList();

  var relevantIEnumerableMembers = builder.Target.AllFieldsAndProperties
    .Where(member => member.Type is INamedType ntype &&
            !ntype.Is(SpecialType.String) &&
            ntype.Is(typeof(IEnumerable<>), ConversionKind.TypeDefinition)
    )
    .Where(member => member.
      TypeArgumentOfEnumerableHasAttribute(typeof(UnsavedChangesAttribute))
    )
    .Where(member => 
      member is not IField field || !field.IsAutoBackingField()
    )
    .ToList();
    
  [...]
}

[Template] private bool _internalUnsavedChanges = false;
```, caption: [Implementing IUnsavedChanges, creating the unsaved changes field and finding relevant members in `UnsavedChangesAttribute`]
)<unsaved_changes_implementation_part1>

In @unsaved_changes_implementation_part2 we see the template for implementing the private `GetUnsavedChanges()` method on the target which does the actual heavy lifting of determining whether or not there are unsaved changes in an instance of our target. It takes in the previously constructed lists of relevant members from @unsaved_changes_implementation_part1 as compile-time variables. This method is constructed in a bit of a special way using an `ExpressionBuilder` instead of template techniques shown in the earlier template code. This is because using an `ExpressionBuilder` to build this method makes it much easier to express the logic we're trying to build, as we can simply feed the builder arbitrary syntax expressions that we want to have converted to run-time code later on in our return statement in line 31 and this syntax only needs to be valid *after* all our aspects have been processed. Because of this, all the code that is in this template method (except the return statement) is compile-time code and as such, the convention of marking it pink has been skipped, merely the expressions that we feed into the `exprBuilder` variable are later converted to run-time code by Metalama. 

We start out our logic in @unsaved_changes_implementation_part2 by adding a check to `_internalUnsavedChanges` of the current instance. Then, for each non-IEnumerable member that we identified in @unsaved_changes_implementation_part1, we append a verbatim boolean OR `||` followed by an expression that checks whether that member's value has unsaved changes or not. If the type of that member is nullable, we must additionally take care not to cause a `NullReferenceException` by using the null-conditional operator `?.` @dotnetdocs[Member access operators and expressions - the dot, indexer, and invocation operators. - section Null-conditional operators ?. and ?[]] when accessing the `UnsavedChanges` property and defaulting to false on a null value via the null-coalescing operator `??` @dotnetdocs[?? and ??= operators - the null-coalescing operators].


#figure(
```cs
[Template]
private static bool GetUnsavedChanges(
  [CompileTime] IEnumerable<IFieldOrProperty> relevantMembers,
  [CompileTime] IEnumerable<IFieldOrProperty> relevantIEnumerableMembers
)
{
  var exprBuilder = new ExpressionBuilder();
  exprBuilder.AppendExpression(meta.This._internalUnsavedChanges);
  foreach (var member in relevantMembers)
  {
    exprBuilder.AppendVerbatim("||");
    if (member.Type.IsNullable!.Value)
      exprBuilder.AppendExpression((member.Value?.UnsavedChanges ?? false));
    else
      exprBuilder.AppendExpression(member.Value!.UnsavedChanges);
  }

  foreach (var member in relevantIEnumerableMembers)
  {
    exprBuilder.AppendVerbatim("||");
    var enumerableNullable = 
      meta.CompileTime(member.Type.IsNullable!.Value);
    var genericTypeNullable = 
      meta.CompileTime((INamedType)member.Type).TypeArguments[0]
        .IsNullable!.Value;
    GetUnsavedChangesHandleIEnumerable(enumerableNullable,
      genericTypeNullable, member, exprBuilder
    );
  }

  return exprBuilder.ToExpression().Value;
}
```, caption: [Template code for implementation of private `GetUnsavedChanges()` method, without marking compile-time code pink]
)<unsaved_changes_implementation_part2>

We then go over every `IEnumerable<T>` member we collected in @unsaved_changes_implementation_part1 and, in @unsaved_changes_implementation_part3, similarly build out the logic for the enumerable members, however instead of checking every member of the collection for unsaved changes via the LINQ `.Any()` method. Here, we must be careful to check not only whether the `IEnumerable<T>` type itself is nullable, but also whether the `T` type argument inside of that type is nullable (see lines 21 to 25 in @unsaved_changes_implementation_part2), and introduce null-safety checks accordingly as described above#footnote[The syntax for the case that the enumerable type is nullable had to be appended via interpolated verbatim strings, as it was impossible to create the logic required as a statement with valid C\# syntax here.]. The correct syntax is then appended to the expression builder once more, which finally in line 31 of @unsaved_changes_implementation_part2 returns the value of this boolean expression as the return value of the method. 

#figure(
```cs
[Template]
private static void GetUnsavedChangesHandleIEnumerable(
  [CompileTime] bool enumerableNullable,
  [CompileTime] bool genericTypeNullable,
  [CompileTime] IFieldOrProperty member,
  [CompileTime] ExpressionBuilder exprBuilder
)
{
  if (enumerableNullable)
  {
    exprBuilder.AppendVerbatim(genericTypeNullable
      ? $"({member.Name} is null ? false : {member.Name}.Any(v => v?.UnsavedChanges ?? false))"
      : $"({member.Name} is null ? false : {member.Name}.Any(v => v.UnsavedChanges))");
  }
  else
  {
    exprBuilder.AppendExpression(genericTypeNullable
      ? ((IEnumerable<IUnsavedChanges?>)member.Value!).Any(v => v?.UnsavedChanges ?? false)
      : ((IEnumerable<IUnsavedChanges>)member.Value!).Any(v => v.UnsavedChanges));
  }
}
```, caption: [`GetUnsavedChangesHandleIEnumerable` template code, compile-time code is again not marked as it consists of exclusively compile-time code]
)<unsaved_changes_implementation_part3>

Finally, in @unsaved_changes_implementation_part4, we introduce the `ResetUnsavedChanges` method via another template#footnote([Not shown here for brevity, but it essentially does the same thing as the `GetUnsavedChanges` template by going over all members and enumerable members and calling `ResetUnsavedChanges` on the objects.]) and the `UnsavedChanges` property via a final template that simply calls the `GetUnsavedChanges()` method on the instance. We want these to be public, as these are the public-facing contracts of the `IUnsavedChanges` interface.

#codly(
  highlights:
  (
    ct(18, end: 10),
    ct(18, start: 32, end: 40),
  )
)
#figure(
```cs
public override void BuildAspect(IAspectBuilder<INamedType> builder)
{
  [...]
  builder.IntroduceMethod(nameof(ResetUnsavedChanges),
    IntroductionScope.Instance,
    buildMethod: mBuilder =>
      { mBuilder.Accessibility = Accessibility.Public; },
    args: new { relevantMembers, relevantIEnumerableMembers }
  );

  builder.IntroduceProperty(nameof(UnsavedChanges),
    IntroductionScope.Instance,
    buildProperty: pBuilder =>
      { pBuilder.Accessibility = Accessibility.Public; }
  );
  [...]
}
[...]
[Template] public bool UnsavedChanges => meta.This.GetUnsavedChanges();
```, caption: [Continuation of `BuildAspect` method from @unsaved_changes_implementation_part1]
)<unsaved_changes_implementation_part4>

== Example Application of Pattern
In @unsaved_changes_diff, we see what the diff view for an example class structure in @unsaved_changes_diff_diag looks like. The example at hand is still quite simple but includes normal associations as well as aggregate associations with different nullability. Because of this, the `GetUnsavedChanges()` implementation of class `A` already has considerable complexity, even though we only have three members in that class. Each of the types also has a method to set unsaved changes from the outside, this is so we can set unsaved changes from the outside in our unit tests and check that both getting the unsaved changes and resetting them work properly.


#figure(
```diff
 [UnsavedChanges]
-public partial class A
+public partial class A: IUnsavedChanges
 {
     public B B { get; set; }
     public IEnumerable<B?> Bs { get; set; }
     public IEnumerable<B>? Bs2 { get; set; }
     public void SetUnsavedChanges() => _internalUnsavedChanges = true;
+
+    private bool _internalUnsavedChanges = false;
+
+    public bool UnsavedChanges
+    {
+        get
+        {
+            return this.GetUnsavedChanges();
+        }
+    }
+
+    private bool GetUnsavedChanges()
+    {
+        return (bool)(this._internalUnsavedChanges ||
+          this.B.UnsavedChanges ||
+          Enumerable.Any(((IEnumerable<IUnsavedChanges?>)this.Bs), v => v?.UnsavedChanges ?? false) ||
+          (Bs2 is null ? false : Bs2.Any(v => v.UnsavedChanges))
+        );
+    }
+
+    public void ResetUnsavedChanges()
+    {
+        this._internalUnsavedChanges = false;
+        B.ResetUnsavedChanges();
+        foreach (var val in Bs)
+        {
+            val?.ResetUnsavedChanges();
+        }
+        if (Bs2 is not null)
+        {
+            foreach (var val_1 in Bs2!)
+            {
+                val_1.ResetUnsavedChanges();
+            }
+        }
+    }
 }
 
 [UnsavedChanges]
-public partial class B
+public partial class B: IUnsavedChanges
 {
     public C C { get; set; }
     public C? C1 { get; set; }
     public IEnumerable<C> Cs { get; set; }
     public void SetUnsavedChanges() => _internalUnsavedChanges = true;
+
+    private bool _internalUnsavedChanges = false;
+
+    public bool UnsavedChanges
+    {
+        get
+        {
+            return this.GetUnsavedChanges();
+        }
+    }
+
+    private bool GetUnsavedChanges()
+    {
+        return (bool)(this._internalUnsavedChanges ||
+          this.C.UnsavedChanges ||
+          (this.C1?.UnsavedChanges ?? false) ||
+          Enumerable.Any(((IEnumerable<IUnsavedChanges>)this.Cs), v_1 => v_1.UnsavedChanges)
+        );
+    }
+
+    public void ResetUnsavedChanges()
+    {
+        this._internalUnsavedChanges = false;
+        C.ResetUnsavedChanges();
+        C1?.ResetUnsavedChanges();
+        foreach (var val in Cs)
+        {
+            val.ResetUnsavedChanges();
+        }
+    }
 }
 
 [UnsavedChanges]
-public partial class C
+public partial class C: IUnsavedChanges
 {
     private int Foobar { get; set; }
     public void SetUnsavedChanges() => _internalUnsavedChanges = true;
+
+    private bool _internalUnsavedChanges = false;
+
+    public bool UnsavedChanges
+    {
+        get
+        {
+            return this.GetUnsavedChanges();
+        }
+    }
+
+    private bool GetUnsavedChanges()
+    {
+        return _internalUnsavedChanges;
+    }
+
+    public void ResetUnsavedChanges()
+    {
+        this._internalUnsavedChanges = false;
+    }
 }
```, caption: [Example code diff view for the example in @unsaved_changes_diff_diag]
)<unsaved_changes_diff>
#figure(
image("../../diagrams/unsaved_changes/unsaved_changes_example_class.svg"),
caption: [Example data structure for `<<UnsavedChanges>>`. The backslash in member `Bs2` in class `A` is needed because of a PlantUML limitation.]
)<unsaved_changes_diff_diag>
//== Technical limitations
== Impact and Consequences of Implementation<unsaved_consequences>
Once again, we can name similar improvements of the automatic implementation of this pattern over the manual implementation similar to the consequences mentioned in @memento_consequences and @singleton_consequences. For one, we've extracted a responsibility out of our functionally interesting code by extracting the implementation of the unsaved changes pattern into a separate aspect. Whenever we add a new entity class into our hierarchy now which also needs to conform to this unsaved changes pattern, we simply mark it with the attribute, add it wherever we need it in our existing entity types and the implementation of the `GetUnsavedChanges()` method in all our entities will automatically be adjusted everywhere without further need for user input. This makes maintaining, understanding and reasoning about our domain model easier and gives us the assurance that our unsaved changes implementation is robust and bug-free. We also again profit from not having to repeat very similar code over and over again across our codebase, and from the fact that we can test our aspect generates correct code once, and test this generated code once, to ensure that our aspect implementation works as intended across a multitude of similar inputs.

It has to be mentioned again, however, that this implementation of unsaved changes is by far *not* performance-optimized. For one, if we really only need to ever know that *any* unsaved change has occurred in our object hierarchy, we should use the alternative implementation using a delegate call mentioned in @unsaved_changes_analysis. Even if that is the case, the implementation presented here is not optimal as we do not cache the result of our unsaved changes lookup at all and need to repeat our entire analysis every time#footnote([Solving this issue would need some sort of NotifyPropertyChanged implementation, like the one mentioned in @observer_notifypropertychanged.]). Fortunately, at least the boolean OR operator `||` is short-circuiting in C\#@dotnetdocs[Boolean logical operators], meaning that as soon as we find *any* true value, we don't need to evaluate all other members in the hierarchy anymore. For really big hierarchies, it might also be worthwhile to think about depth-first vs breadth-first traversal of the tree problem mentioned in @unsaved_changes_analysis.

#pagebreak(weak: true)
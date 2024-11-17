= Unsaved changes<unsaved_changes>

== Analysis of pattern
TODO: reference dirty bit? not exactly the same problem but similar solution, however this is cascading where as dirty bit isnt. find literature?

The pattern described in this section is certainly nothing new, and the author of this work is not claiming to have invented a new pattern here, however it is very difficult to find any substantial literature on it#footnote([The closest thing that can be found is the "dirty flag" pattern, which is often used in games or other applications where performance is critical to only calculate certain things exactly when they are needed. Both the problem that's being solved with that pattern and the solution to it is different to what will be explained here, however, as we are more concerned with notifying our UI whether *any* object in our hierarchy has changed rather than saving operations at an object level. An example analysis of that pattern can be found at https://gameprogrammingpatterns.com/dirty-flag.html.]). As such, we will first describe the problem it tries to solve here, then propose a systematic solution to it, before going into how to automate implementing it.

In modern applications that allow users to edit files of any sort, it is very common to give users an indication whenever a file or open context of any sort has any changes that have not been saved yet. Two different examples can be observed in @unsaved_changes_example_images. There are many different ways we can handle a users unsaved changes, the first example is a blocking modal dialog that prevents the user from closing the application until they select how to proceed, the second example is a much more subtle way of informing the user, which is acceptable in this scenario, as the application in question actually persists unsaved changes when it is closed and reopened.

#figure(
  grid(columns: 2, row-gutter: 2mm, column-gutter: 2mm,  
  box(image("../../Bilder/unsaved_changes_authoringtool.png"), stroke: (paint: black, thickness: 1pt)), image("../../Bilder/unsaved_changes_vscode.png"), 
  ["a) AdLer authoring tool"#footnote("https://github.com/ProjektAdLer/Autorentool")], ["b) Visual Studio Code"#footnote("https://code.visualstudio.com/")]),
  caption: ["Examples of software with user interfaces that warn or inform the user of unsaved changes"]
)<unsaved_changes_example_images>

In order to implement a feature like this, we have two options: Either we let our UI keep track of whenever any input is made to it that necessitates a save (which is a bad idea for hopefully obvious reasons, but to name a few: it would violate MVC/MVVC architecture, violate SRP and necessitate closer coupling of UI components so they can communicate the unsaved changes state between each other) or we make the data that we operate on track whenever any changes have been made to it that have not yet been saved.

To illustrate this problem better, we'll introduce an example. Imagine we are creating a simple video game in which the player can collect and equip items, and said items have durability. Whenever *any* state in our game changes, we want to be able to track this information to know when to prompt the player to save the game. In @unsaved_changes_item_example we find a basic example of how we can implement a property to keep track of unsaved changes in our item classes. We also add a method to reset the `UnsavedChanges` property back to false.

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

This solution works perfectly fine for the single simple class shown here, but as soon as we add more classes into a hierarchy of sorts, the logic of `UnsavedChanges` becomes a lot more tedious to maintain, as we now need to consider the object itself and all child objects it holds references to. We now add a Player class that can wear one weapon and hold a variety of items it it's inventory in @unsaved_changes_player_example. As we can see, we now need to consider not only the player object itself for it's unsaved changes, but also all objects it holds a reference to. The `ResetUnsavedChanges()` method now also becomes more complex, because we need to reset the player and all the objects in the hierarchy.

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

The problem with this design is that, once again, it breaks the SRP. Our `Player` class is now responsible for doing a multitude different things:
+ It is responsible for holding it's own functional state (the properties `Inventory` and `EquippedWeapon`)
+ It is responsible for deciding when it has unsaved changes and in doing so is responsible for checking whether it's members have unsaved changes
+ It is responsible for resetting it's own unsaved changes state and the unsaved changes state of it's members

We should note that there are two possible ways to implement tracking the changes of an object. The first possibility is the object itself tracking whenever it has been changed via it's property setters, as shown in the examples @unsaved_changes_item_example and @unsaved_changes_player_example. The other possibility is that whatever business logic decides how and when to change our objects state also decides when it has made changes to an object that constitute unsaved changes and sets the property from the outside accordingly. This would at least partially mitigate the second problem of responsibility above (the object still needs to keep track of the property itself), which is why this is the way we chose to implement unsaved changes in the aspect implementation that follows shortly in @unsaved_changes_implementation. It would however be entirely feasible to automate the first option by adjusting the aspect to hook into something like an automatic `NotifyPropertyChanged` implementation#footnote([Such as https://doc.postsharp.net/metalama/examples/notifypropertychanged for example]).

It's also worth talking about the state pattern and why we believe it should not find application here. Using the state pattern, we can "[a]llow an objecct to alter its behavior when its internal state changes."@Gamma1994[p. 305] by assigning an object that encapsulates the current state to a state member on our object@Gamma1994[p. 305f]. In theory, we could use this pattern instead of the boolean property `UnsavedChanges` and encapsulate the state into two classes `HasUnsavedChanges` and `NoUnsavedChanges`. We could then implement a method `HasUnsavedChanges()` on the two state objects that return `true` and `false` accordingly. The issue with this is that we haven't done anything to solve our original problem of having to traverse the tree of our members which we still need to do with this implementation. This means that either we need to make strategy types for each type in our hierarchy that knows what members of the type itself to check for unsaved changes, or ask the type directly by retaining the `UnsavedChanges` property implementation for the member objects, meaning we'd have effectively gained nothing. Another, even worse, idea is to make parent objects register on an event#footnote([Compare C\# events@dotnetdocs[event (C\# reference)] with observer pattern in @Gamma1994[p. 293ff]]) on their members and having the members notify their parents whenever their strategy object changes, giving the parent object a chance to update their own strategy. This would create an impenetrable mess of double-references from parents to children and back which is certainly possible to implement, but one has to ask oneself if that is truly an improvement in maintainability compared to the proposed example.

The usage of many different other patterns could be discussed here, for example, if we only cared about the fact that *an* object in our hierarchy has changes but never care about *what part of the object hierarchy* has changes, we could use a mediator@Gamma1994[p. 273ff] to extract and simplify the logic of change notification by making the Player class (or whatever the top object of our hierarchy ends up being) subscribe to the `OnChange` event of some sort of `ChangeTracker` mediator class, passing a reference to this mediator to every member of the hierarchy and making the components call this mediator whenever there is a change, effectively notifying our Player. Using this approach we could find out what concrete object has the change (simply by making the changed object pass itself to the mediator, which passes it to the player), but it would be difficult to identify the entire subtree of our object structure has changes because of this, which could be something we need if we need to persist subtrees of our hierarchy on change for example. Using C\# delegates@dotnetdocs[Delegates (C\# Programming Guide)] could even eliminate the need for the mediator type. One could also discuss whether the application of the chain of responsibility pattern brings advantages here, but we'll leave it as an exercise to the reader to determine whether this actually improves the proposed design and move forward with how to automatically implement said design.


== Implementation of aspects<unsaved_changes_implementation>
The `Moyou.Aspects.UnsavedChanges` namespace consists of only two types: an `IUnsavedChanges` interface which we will implement on our targets and an `UnsavedChangesAttribute`

== Example application of pattern
== Technical limitations
== Impact and consequences of aspects<unsaved_consequences>
TODO: probably not performance optimal on REALLY big hierarchies (discussion of depth-first vs breadth-first)
#pagebreak(weak: true)
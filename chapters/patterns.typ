// = Implemented patterns
// Hier alle Patterns, die ich auch wirklich geschafft habe zu implementieren. Detailiert auch immer die Implementierungen und den generierten Code erklären.
#include "patterns/memento.typ"
#include "patterns/singleton.typ"
#include "patterns/unsavedchanges.typ"
#include "patterns/factory.typ"

= Analysis of Other Patterns
In this chapter, we shall look at some other design patterns that have not been implemented in Moyou yet and analyze whether implementing them via aspects is sensible, brings any benefits and is even possible in the first place. We'll also take a look at some reference implementations of other programming patterns courtesy of the Metalama project.

== Command
We'll start off with the command pattern, a behavioral pattern@Gamma1994[p. 233] which allows us to "[e]ncapsulate a request as an object, thereby letting [us] parameterize clients with different requests, queue or log requests and support undoable operations"@Gamma1994[p. 233]. In this description of the problem, we have a "Receiver" that offers some exposed functionality and a "Client" that needs to call this "Receiver" and the solution to decoupling the two is to introduce a concrete command class for each of the methods the receiver exposes which the client then refers to instead of the receiver itself; a fourth (optional) class called the "Invoker" is responsible for receiving commands and ultimately executing them@Gamma1994[p. 233ff]. This invoker class is very useful if we are planning to introduce features like undo and redo, as it can hold references to the commands it has executed in a stack and handle calling undo and redo on the commands in the correct order for us@Gamma1994[p. 237].

This is the basic description of the pattern. Gamma et al. then go on to explain in @Gamma1994[p. 238] that there are different philosophies as to how much work the command should do, which in turn defines how much logic the command itself needs to have: The command can either be extremely thin and only hold a reference to the receiver, the arguments for invocation, and have a single method `Execute()` that calls the receiver with the arguments it was given@Gamma1994[p. 238]; on the other hand we could move the business logic of the receiver entirely into the command itself and execute it upon call to the `Execute()` method@Gamma1994[p. 238], in which case the command is very heavy on logic. When thinking about how we could implement the command pattern via code generation, we need to think about what level of complexity inside the command is appropriate and feasible to automatically generate. The more we move from the former, thinner design philosophy of the command to the latter, more complexity-laden one, the more difficult it becomes for us to autogenerate the implementation of our command classes, as we need to have more and more information about what the implementation should look like.

A possible solution for an autogenerated command pattern implementation could be the introduction of a `[Command]` aspect which, when placed on a method of our business logic, creates a command class for that target method, properties inside that class for the arguments of the method, a constructor that sets these properties and the receiver object and the `Execute()` method that then executes the target method on the receiver object. This could then be extended further with the use of other patterns and aspects, for example, we could introduce another attribute that parameters to the method can be marked with to signal that their memento implementation should be used to automatically implement undo on the resulting command. If a better way is found to implement the factory pattern that makes it possible to declare on a type itself that it should be added to a factory (see limitation in TODO: REFERENCE), we could add a parameter to the command aspect that automatically adds the command to a command factory class for that receiver. An example of what that could look like is presented in @patterns_command_example, with just a plain command and one undo command that automatically uses the memento implementation provided by the memento aspect from @memento.

#figure(
```cs
interface ICommand 
{
  void Execute();
}
interface IUndoCommand : ICommand
{
  void Undo()
}

[Memento]
class SomeData : IOriginator
{
  public int Foo {get; set;}
  //automatic memento implementation here
}

class SpecialMaths 
{
  [Command]public void Add(SomeData data, int a, int b) => data.Foo = a+b;
  [Command]
  public void Mult3([CommandUndo]SomeData data, int a, int b, int c) =>
    data.Foo = a*b*c;
}

//fully autogenerated by [Command]
class SpecialMathsAddCommand : ICommand
{
  public SpecialMathsAddCommand(SpecialMaths receiver, SomeData data, int a, int b)
  {
    Receiver = receiver;
    Data = data;
    A = a;
    B = b;
  }

  private SpecialMaths receiver { get; }
  private SomeData Data { get; }
  private int A { get; }
  private int B { get; }

  public void Execute() => Receiver.Add(Data, A, B);
}

//fully autogenerated by [Command]
class SpecialMathsMult3Command : IUndoCommand
{
  public SpecialMathsAddCommand(SpecialMaths receiver, SomeData data, int a, int b, int c)
  {
    Receiver = receiver;
    Data = data;
    A = a;
    B = b;
  }

  private SpecialMaths receiver { get; }
  private SomeData Data { get; }
  private int A { get; }
  private int B { get; }
  //because of [CommandUndo]
  private IMemento DataMemento { get; set; }

  public void Execute() 
  {
    DataMemento = Data.GetMemento();
    Receiver.Add(Data, A, B);
  }

  //because of [CommandUndo]
  public void Undo() 
  {
    if(DataMemento == null) 
      throw new InvalidOperationException("No memento");
    Data.RestoreMemento(DataMemento);
    DataMemento = null;
  }
}
```, caption: [Example of generated code that could be realized with a `[Command]` pattern]
)<patterns_command_example>

We definitely have to ask the question, however, what we would achieve by doing all this. The command pattern in its form described here already fits perfectly within the tools of abstraction that object-oriented programming offers us: there are no cross-cutting concerns to speak of, rather the concern that the command pattern addresses is already abstracted into its own class, the concrete command itself. We would certainly still save ourselves the copy-and-paste work of creating these command classes ourselves, but it comes at the cost of reduced customizability as described above. If we, in the future, want to move from the thin command objects to the more involved philosophy of putting all the logic from the receiver into the command, we cannot do that with the automatic command implementation #footnote([A possible solution for this can be the Metalama feature of divorcing where we can remove our reliance on a certain aspect by generating out the source code it produces once and adding it into our own codebase, see @metadocs[Divorcing from Metalama]]). We also still reap the benefits of being able to test the logic of our compile-time code and the logic of the run-time code it generates once and being confident that all our command implementations are correct, as mentioned in the previous sections.

TODO: reference Metalama UWP command implementation

== Observer/INotifyPropertyChanged
TODO

#pagebreak(weak:true)
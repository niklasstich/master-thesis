= Introduction<intro>
== Aspect-Oriented Programming<aop>
In 1997, Kiczales et al. first posited the concept of aspect-oriented programming (AOP) in @Kiczales1997. Specifically, they found that in modern software applications, there exist components, which are concerned with what they call "functional decomposition" of our business logic@Kiczales1997[p. 2f, p. 6f], essentially breaking apart our functional requirements into the levels of abstraction the language at hand supports and separate properties which they coined as "cross-cutting concerns", often non-functional requirements "that affect the performance or semantics of the components"@Kiczales1997[p. 6f] that span across these abstractions@Kiczales1997[p. 7], namely classes in the case of object-oriented programming (OOP) languages like C\# at hand. The solution to these cross-cutting concerns are called "aspects", and they exist, conceptually, outside of our component hierarchy@Kiczales1997[p. 7]. The problem with aspects is that, in classic OOP languages, there is no good way to abstract them out of the components or classes they span across@Kiczales1997[p. 6f]. A good example of this is logging@metadocs: Say we want to provide trace logging across our entire existing application, putting out a log message whenever we enter and exit a method on the call stack@metadocs[Commented examples - Logging]. Out of the box, there is no good way to realize this in C\# in a manner that does not affect our functional units, or in other words, classes, and as a consequence we would have to add explicit logging statements to every method in our application, like in @logging_classic_example.

#figure(
```cs
public class Math 
{
    public int Add(int a, int b) 
    {
        Console.WriteLine("Entering method Add");
        var result = a + b;
        Console.WriteLine("Exiting method Add");
        return result;
    }
}
```, caption: [Very simple example of logging mixed in with business logic. The logging code in the example cannot be well abstracted out of class `Math` by means of Object-Oriented Programming.]
)<logging_classic_example>

Metaprogramming can help us solve this issue in a more implementation-agnostic way. There are many different approaches in the metaprogramming space, such as the "Metaobject Protocol"#footnote([A well-known example of a metaobject protocol language is Common Lisp or more specifically the Common Lisp Object System, an extension of Common Lisp that constitutes "a high-level object-oriented language"@Kiczales1999[p. 2], the design of which the authors of @Kiczales1999 have been involved in.]), described in @Kiczales1999, in which the basic structural building blocks of a language are themselves represented by first-class objects of the language that can be manipulated through writing code in the language@Kiczales1999[p. 1, p. 137]. This is a very powerful approach, because it allows us to manipulate how the language itself is implemented during run-time@Kiczales1999[p. 1]. On the other hand, there are more structured approaches like the "aspect weaver", which focuses on solving the implementation of aspects from the previous definition of AOP. Aspect weavers combine both the "component language", the programming language in which we write our functional components (e.g. classes), and an "aspect language", in which we write our aspects which, when woven with the aspect weaver (a compiler of sorts), manipulate our input components to generate our final program@Kiczales1997[p. 9]. There are also approaches that do this aspect weaving during run-time, but these will not be the focus of this work.

Using such aspect weavers, we can define a logging aspect that we can apply to our existing implementation to solve the previously brought up issue of logging: The aspect will automatically change the implementation of our existing components to add logging for us, without having to touch the functional part of our components ourselves at all@metadocs[Commented examples - Logging - Step 1]. The possibly most well-known example of such an aspect weaver technology is the AOP language AspectJ, which itself is an extension to Java@aspectjdocs[Introduction]. An example solution for our logging problem in AspectJ can be found in @aspectj_trace_example. In the example, we find the definition of an aspect called `SimpleTracing`. In this aspect we see the definition of a so-called pointcut, an entrypoint of sorts for the aspects we define, which matches the execution of all methods regardless of return type (first `*`), method name (second `*`) or parameters (`(..)`). We can then define various different points of advice inside of our aspect which will be applied to all instances that their pointcuts match. In our example, we define a `before` advice on our `anyMethodCall` pointcut, meaning the code inside our advice (which is a very *improper* example of logging and should in no way constitute a recommendation of how to implement trace logging) will be called before the execution of any arbitrary method; the `after` advice works analogously, being executed after the execution of any arbitrary method.

#figure(
```aspectj
aspect SimpleTracing {
    pointcut anyMethodCall():
        execution(* *(..));

    before(): anyMethodCall() {
        System.out.println("Entering method " + thisJoinPoint);
    }

    after(): anyMethodCall() {
        System.out.println("Exiting method " + thisJoinPoint);
    }
}
```, caption: [AspectJ solution for the trace logging problem, compare @aspectjdocs[Development Aspects - Tracing]]
)<aspectj_trace_example>

This concept of aspect-weaving can be used to solve many common cross-cutting concerns efficiently by extracting the solution to them out of the code that we really care about, our business logic. 

== Software design patterns
Software design patterns are are tool for developers to find a common language to talk about commonly occuring problems in software development, the core principles of how to solve these problems, what consequences applying the specific solution has for our program and also gives us a meaningful name to remember this information by@Gamma1994[p. 1ff]. As Gamma et al. put it, using patterns in our designs "help[s] a designer get the design 'right' faster"@Gamma1994[p. 2] as we do not have to approach every reoccuring problem using basic principles again@Gamma1994[p. 1]. In other words, "design patterns [...] are descriptions of communicating objects and classes that are customized to solve a general design problem in a particular context"@Gamma1994[p. 3]. The demand to abstract problems and common solutions for them into a higher level of abstraction such as the patterns at hand is not exclusive to software design and development; in fact, the very concept of patterns described by the "Gang of Four", as Gamma et al. are sometimes referred to, in their standard reference work "Design Patterns" is borrowed from @Alexander1977, a 1970s book about reoccurring patterns of the architecture of houses, neighborhoods and townships.

Due to the very nature of these patterns, they describe problems in a way that is not specific to a certain problem domain and can find application in all sorts of object-oriented programs, no matter what the functional logic of these programs might be. This is certainly reminiscent of our description of cross-cutting concerns earlier, and it can certainly be argued that some of the design patterns described in @Gamma1994 are solutions to cross-cutting concerns, such as the singleton, which is concerned with *how* an object is instantiated and how consumers can access it's instance, or the memento, which is concerned with how we can take snapshots of an objects state without opening up it's encapsulation. These patterns do not really care about what exactly it is that our classes and components do on a functional level. The solutions to these concerns are however mixed in with our units of functional decomposition, classes to be specific, in these patterns. There is no clean separation between the functional logic of our components and the logic required to solve cross-cutting concerns that span across these components. This is where using AOP and metaprogramming solutions can come in and help us create separation of concerns again (more on this in detail in @memento_consequences, after we have established a full example solution). 

This work is concerned with how we can use aspect-oriented programming to automatically implement various classic software design patterns such as the ones found in @Gamma1994 and a non-conventional example. These patterns often try to solve a cross-cutting concern, but because they are confined to the paradigm of object-oriented programming, this approach has drawbacks. The concrete advantages of using AOP to address the implementation of these patterns will become clear once we apply the principles to concrete examples and will be thoroughly analyzed in Sections #ref(<memento_consequences>, supplement: none), #ref(<singleton_consequences>, supplement: none), #ref(<unsaved_consequences>, supplement: none) and #ref(<factory_consequences>, supplement: none).

== .NET ecosystem metaprogramming solutions
In the .NET ecosystem, which has been chosen for this work as the author is most familiar with C\# from previous work experience, there are several tools available that may facilitate AOP, code generation or metaprogramming in general to various degrees. Ideally, we would want to use a .NET based templating solution so we can write C\# code that generates C\# code, as it is most comfortable for a developer to stay in the same ecosystem they are already familiar with. Some possible solutions will be explored in this section, no claim is being made that this list of solutions is exhaustive or that there doesn't exist a more ideal solution.

TODO: NUTZWERTANALYSE => Siehe dazu Projektmanagement Burghardt ISBN 978-3-89578-472-9
=== T4 templates
T4#footnote([T4 is an acronym for Text Template Transformation Toolkit]) templates are a .NET technology that allow mixing raw text and C\# or Visual Basic program code and that can be used to generate any arbitrary text files, including C\# source code@dotnetdocs[Code Generation and T4 Text Templates]. These T4 templates can then be transformed either at run-time or compile-time#footnote([The T4 documentation mentions "design time" in this context@dotnetdocs[Code Generation and T4 Text Templates]. Design-time builds are run by the IDE during editing of a codebase and are smaller, faster builds that are used to gather information for tools like Intellisense that aid the development experience, an extremely crucial feature for modern software development. This means that templates are technically expanded while we are working on our solution, but as we are not concerned with the design-time experience in this paper, we will keep referring to design-time semantics as compile-time for the rest of this document even though they are technically different things.]) into a string or a file respectively. An example of a very simple run-time T4 text template that generates an HTML page which contains the current datetime is given in @approach_t4_template_html. Another, more involved example of a compile-time T4 template is given in @approach_t4_template_cs, where a XML file is used as input to generate a .cs source code file that can then be used as part of a C\# project.
#figure(
```t4
<html><body>
 The date and time now is: <#= DateTime.Now #>
</body></html>
```, caption: [Simple T4 template taken from @dotnetdocs[Code Generation and T4 Text Templates]]
)<approach_t4_template_html>

#figure(
```t4
<#@ output extension=".cs" #>
<#@ assembly name="System.Xml" #>
<#
 System.Xml.XmlDocument configurationData = ...; // Read a data file here.
#>
namespace Fabrikam.<#= configurationData.SelectSingleNode("jobName").Value #>
{
  ... // More code here.
}
```, caption: [More complex T4 template taken from @dotnetdocs[Code Generation and T4 Text Templates]]
)<approach_t4_template_cs>

T4 templates are already quite powerful, as we can do arbitrary text transformations utilizing C\# code, but lacks some crucial features. Namely, T4 templates can only generate new source code files, they cannot add to existing files or even change them. This means we could not possibly implement our cross-cutting logging concern from @aop without touching our existing existing implementation (we could, for example, use a decorator). This also means that implementing patterns on existing types would not be possible in the cases where just defining a partial class is not enough. Emitting meaningful error messages with T4 templates is possible but requires that the host (the context in which the T4 template is expanded) supports this@dotnetdocs[Access Visual Studio or other hosts from a text template]. Furthermore, T4 templates have no real mechanism for communication between templates, may be difficult to debug and are subject to length limitations due to internal string concatenation in the expansion of templates@dotnetdocs[Debugging a T4 Text Template]. Due to these limitations, using T4 templates was not an option for this work.

=== Source Generators<source_generators>
Source generators, or more specifically incremental generators#footnote([Incremental generators are an inprovement upon legacy v1 source generators@roslyndocs[source-generators.md] and have multiple benefits, most notably that they are much more performant because of caching and other low-level optimizations in how they access compiler information@roslyndocs[incremental-generators.md], which improves performance at design-time by making the editing experience in the IDE more snappy. We'll henceforth just refer to them as source generators as they are conceptually very similar.]), are a feature of the .NET compiler toolchain Roslyn which allows us to access internal compiler information at compile-time and generate new code that should be added to a solution during the compilation process. Source generators are already finding application in the .NET framework itself, such as in the `System.Text.Json` namespace to generate the (de-)serialization implementation of types at compile-time rather than using runtime reflection, and they can be very useful for creating a more efficient compile-time implementation of tasks that usually use reflection in general, such as getting the string representation of enum values at runtime. In @source_generator_example we find an example of a source generator that scans for files ending with `.txt` in the solution and creates a class with a `const` field for each of the files that contains the contents of the file@roslyndocs[incremental-generators.md].
#figure(
```cs
// find all additional files that end with .txt
IncrementalValuesProvider<AdditionalText> textFiles = initContext
    .AdditionalTextsProvider
    .Where(static file => file.Path.EndsWith(".txt"));

// read their contents and save their name
IncrementalValuesProvider<(string name, string content)>
    namesAndContents = textFiles
        .Select((text, cancellationToken) =>
            (name: Path.GetFileNameWithoutExtension(text.Path),
            content: text.GetText(cancellationToken)!.ToString())
        );

// generate a class that contains their values as const strings
initContext.RegisterSourceOutput(namesAndContents, (spc, nameAndContent) =>
{
    spc.AddSource($"ConstStrings.{nameAndContent.name}", $@"
public static partial class ConstStrings
{{
public const string {nameAndContent.name} = ""{nameAndContent.content}"";
}}");
});
```, caption: [Example source generator snippet taken from @roslyndocs[incremental-generators.md], formatting changed]
)<source_generator_example>

Because we define source generators as plain C\# classes that act upon some input data in a standard C\# projects, this is a very powerful way of metaprogramming out of the box. There are however some major limitations that might dissuade one from using source generators for a target problem, namely that a project defining them must target the `netstandard2.0` target moniker#footnote([It is technically possible to target the higher version `netstandard2.1` instead, which supports more APIs and features, but this has some serious drawbacks, see https://github.com/dotnet/roslyn/issues/47087.]) and they can only perform some limited input/output operations via the source generator API. Most importantly however, source generators are intended *only* for adding new content to a project or solution and as such, it is impossible to change any existing source code@roslyndocs[incremental-generators.cookbook.md]. In the Rosyln documentation, the developers make this even more clear by explicitly bringing up our logging example from @aop as an anti-pattern: "There are many post-processing tasks that users perform on their assemblies today, which here we define broadly as 'code rewriting'. These include, but are not limited to: [...] Logging injection [...]"@roslyndocs[incremental-generators.cookbook.md]. This means that source generators, just like T4 templates, are not suitable for solving the logging cross-cutting concern introduced in @aop.

Source generators are also based on a very low-level API that directly hooks into the compiler pipeline, which as a result is very "compiler-esque". What is meant by this is we must operate on the same data the compiler has access too, which involves directly writing logic that filters through syntax trees, type declaration syntax and other compiler-specific representations of the source code the generator acts upon. Many basic operations are cumbersome, because there are no utility functions for them, such as filtering out all types in a context that have a certain attribute applied to it as can be seen in @source_generator_hasmemento. The only way to generate output source code is via raw strings, which necessitates making string operations or using helper packages like GodeGenHelpers#footnote([https://github.com/dansiegel/CodeGenHelpers]) to construct our source code; there is no built-in templating engine. There is also not much documentation of the APIs that do exist, and the user base of source generators is apparently quite small (in comparison to the greater C\# ecosystem) which makes getting help when getting stuck quite difficult at times.

#figure(
```cs
private static bool HasMementoAttribute(GeneratorSyntaxContext context,
CancellationToken cancellationToken,
MemberDeclarationSyntax classDeclarationSyntax) =>
    classDeclarationSyntax.AttributeLists
        .SelectMany(attributeListSyntax => attributeListSyntax.Attributes)
        .Select(attributeSyntax =>
            ModelExtensions.GetSymbolInfo(context.SemanticModel,
                attributeSyntax,
                cancellationToken)
            )
        .Select(attributeSymbol => attributeSymbol
            .Symbol?.ContainingType?.ToDisplayString()
        )
        .Any(fullName => 
            fullName == MementoAttributeHelper.AttributeFullName
        );
```, caption: [Example source generator code that checks whether a declaration has a certain attribute declared on it#footnote([This code is from a previous attempt to implement patterns using source generators, see https://github.com/niklasstich/Kinen])]
)<source_generator_hasmemento>

For the previous reasons it was determined that, while source generators are useful for *some* metaprogramming tasks, they are not suitable as a solution for the intended use case of this work.

=== Metalama<metalama>
Roslyn Fork
Pro: Kann schon viel, bereits "battle tested", aktive Weiterentwicklung, garantierter Support weil kommerzielles Produkt
aspekte erklaeren und wie sie funktionieren

Contra: Kommerzielles Produkt, kann noch nicht alles (z.B. nested types generieren)

Metalama is a commercial C\# metaprogramming framework, the main selling point of which is the ability to implement aspects, like they were introduced in @aop, that let us generate repetitive boilderplate code that we could not possibly abstract out of our classes otherwise@metadocs[Video tutorials - 0. A short introduction]. It also supports automatically applying these aspects across our codebases via their programatic Fabrics API which can also be used for validation of code. Metalama is being developed by SharpCrafters, the makers of PostSharp, their previous aspect-oriented metaprogramming framework that is based on a post-compiler@metadocs[Migrating from PostSharp - Why migrate] manipulating Common Intermediate Language (commonly referred to as MSIL or CIL), the managed intermediate code that the C\# compiler produces@dotnetdocs[What is "managed code"?] both at compile-time and run-time. Compared to PostSharp, Metalama code generation is fully compile-time meaning it has no runtime overhead and the code that is added by aspects can be seen and accessed from user code@metadocs[Migrating from PostSharp - Why migrate], which is why the developers recommend PostSharp users eventually migrate to the more modern and well-maintained Metalama, if possible@metadocs[Migrating from PostSharp - Why migrate & When migrate].

As mentioned, at the core of Metalama functionality are aspects, standard C\# classes that implement special Metalama interfaces that are picked up during the compilation process. The transformations that these aspects execute on the code are itself based on a Metalama fork of the Roslyn compiler#footnote([https://github.com/postsharp/Metalama.Compiler]) that introduces the concept of source transformers, which, in addition to the features of source generators introduced in @source_generators, can also modify existing source code#footnote([Information sourced from private communication with Gael Fraiteur on Nov. 20th, 2024 (via Zoom)]). In @metalama_classdiag, we can see the basic type structure of Metalama aspects. Any type that implements `IAspect<T>`, where `T` is an `IDeclaration` such as `IMethod`, `INamedType` or other types of code declarations, will have it's `BuildEligibility` and `BuildAspect` methods executed during compile-time@metadocs[Namespace Metalama.Framework.Aspects & Understanding the aspect framework design] and have access to compiler infomation similar to what was described in @source_generators. The abstract types `MethodAspect` and `TypeAspect` (and several others described in @metadocs[Namespace Metalama.Framework.Aspects]) are just helper types that allow us to more easily implement the `IAspect<T>` interface correctly on our aspect types@metadocs[Namespace Metalama.Framework.Aspects & Understanding the aspect framework design].

The `BuildEligibilty` method allows us to check whether or not the aspect that is being executed is actually applicable to the target declaration. To define these checks, we can use predefined extension methods like the `MustNotBeInterface`#footnote([https://doc.postsharp.net/metalama/api/metalama-framework-eligibility-eligibilityextensions-mustnotbeinterface]) or `MustNotBeAbstract`#footnote([https://doc.postsharp.net/metalama/api/metalama-framework-eligibility-eligibilityextensions-mustnotbeabstract]) or define our own logic using the `MustSatisfy`#footnote([https://doc.postsharp.net/metalama/api/metalama-framework-eligibility-eligibilityextensions-mustsatisfy]) method that takes in a validation predicate and a function that generates a justification for why a target is not eligible for the aspect. If the eligibility is true, the `BuildAspect` method is executed in which we can do our actual aspect logic such as introducing new members, types or methods, implementing interfaces, changing existing code and much more. 

#figure(
    image("../diagrams/metalama_stereotypes.svg"), caption: [Class diagram showing type relations in Metalama and aspect stereotype convention used in this paper (the abstract classes the aspects inherit from will not be repeated every time). Diagram is non-exhaustive and does not show all members on all types.]
)<metalama_classdiag>

Fortunately, as aspects are a much higher-level API than the source generator API, it is much simpler to find out revelant information about our targets as there is already a lot of information prepared for us via convenience methods of the Metalama framework. As an example, the code for finding out whether a type has an attribute applied to it is depicted in @metalama_aspect_example (compare with the source generator example from @source_generator_hasmemento).

#figure(
```cs
[CompileTime]
public static bool HasAttribute<TAttribute>(this INamedType type) where TAttribute : Attribute =>
    type.Attributes.Any(attr =>
        attr.Type.FullName == typeof(TAttribute).FullName);
```, caption: [Generic Metalama code that checks whether a type is marked with any arbitrary attribute]
)<metalama_aspect_example>

To add new code, Metalama offers a feature called "T\# templates", which allow us to write normal C\# code with added APIs and functionality provided by the T\# dialect@metadocs[Writing T\# templates]. We can use these templates to add a variety of declarations, such as methods, property getters and setters or field initializers. In @metalama_logging_example, we see an example of such a template. The aspect implements `OverrideMethodAspect` which defines a method `OverrideMethod()` which is used to override the implementation of the target method this aspect is used on. This `OverrideMethod()` is itself interpreted as a template method, and as such, we can use the `meta` keyword to do things like get the name of the target method or executing it via `meta.Proceed()`. Templates will be explained more thoroughly when necessary in the following sections, but for now it is important to understand that these templates and the ability to edit existing code makes Metalama much more powerful than T4 templates or source generators for the metaprogramming task at hand.

#figure(
```cs
public class LogAttribute : OverrideMethodAspect
{
    public override dynamic? OverrideMethod()
    {
        Console.WriteLine($"{meta.Target.Method} started.");

        try
        {
            var result = meta.Proceed();
            Console.WriteLine($"{meta.Target.Method} succeeded.");
            return result;
        }
        catch (Exception e)
        {
            Console.WriteLine($"{meta.Target.Method} failed: {e.Message}.");
            throw;
        }
    }
}
```, caption: [Example implementation of console logging using Metalama, taken from @metadocs[Commented examples - Logging - Step 2. Adding the method name]]
)<metalama_logging_example>

Declarations that are newly introduced by aspects (i.e. new methods, fields, properties, types etc.) can be used from our existing code, we simply have to mark our classes as `partial` to be able to see these declarations#footnote([This is another design-time feature (compare with T4 template footnote above). During editing of our code, design-time compilations are triggered and "fake" source generators are registered in our project that generate empty implementations of these members. During the actual compilation, these are replaced by the real implementations via source transformers.]).

Internally, Metalama takes these templates and compiles them into a a string of `ITemplateSyntaxFactory`#footnote([https://github.com/postsharp/Metalama.Framework/blob/release/2024.2/Metalama.Framework.CompileTimeContracts/ITemplateSyntaxFactory.cs and https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.csharp.syntaxfactory?view=roslyn-dotnet-4.9.0]) statements that dynamically build the code that the template is supposed to generate.#footnote([Information sourced from private communication with Gael Fraiteur on Nov. 20th, 2024 (via Zoom)]) In @metalama_template_syntaxfactory we see an example of how a very simple template method with just one return statement is transformed into calls to the Metalama interface `ITemplateSyntaxFactory` and Roslyn `SyntaxFactory` type. Later on, after the template compilation step is complete, all the applicable targets of an aspect are collected and sorted by depth, starting at the base type of a type hierarchy and all targets of the same depth are passed through the aspect (in a parallelized manner for better performance), where the aspects then call these compiled template functions with the information acquired from the target inside of their `BuildAspect()` methods#footnote([Information sourced from private communication with Gael Fraiteur on Nov. 20th, 2024 (via Zoom)]).
#figure(
```cs
private static SyntaxNode __GetLazyInstance(ITemplateSyntaxFactory templateSyntaxFactory, TemplateTypeArgument T)
{
  List<StatementOrTrivia> __s1 = new List<StatementOrTrivia>();
  meta.DebugBreak();

  // return meta.ThisType._instance.Value;
  templateSyntaxFactory.AddStatement(                
    __s1,
    templateSyntaxFactory.AddSimplifierAnnotations(                    
      templateSyntaxFactory.ReturnStatement(                        
        templateSyntaxFactory.AddSimplifierAnnotations(                            
          SyntaxFactory.MemberAccessExpression(                                
            SyntaxKind.SimpleMemberAccessExpression,
            templateSyntaxFactory.DynamicMemberAccessExpression(                                    
              templateSyntaxFactory.GetUserExpression(meta.ThisType),
              "_instance"),
            SyntaxFactory.Token(SyntaxKind.DotToken),
            SyntaxFactory.IdentifierName(
              SyntaxFactory.Identifier("Value")))))));
  return SyntaxFactory.Block(default,
    templateSyntaxFactory.ToStatementList(__s1)
  );
}
```, caption: [Example of a very simple template expression that was transformed into `SyntaxFactory` statements. Snippet has been shortened by removing fully qualified global type names.]
)<metalama_template_syntaxfactory>


Another important feature of Metalama are Fabrics, these are classes that allow us to apply our aspects across many declarations in our code base by writing imperative code instead of having to mark every type or member manually@metadocs[Adding many aspects at once & More about fabrics]. For example, in @metalama_fabric_example, we see a `ProjectFabric` that will run in our project and mark *every* method on *every* type with the `LogAttribute` aspect example from @metalama_logging_example. Using these fabrics to apply aspects to our classes is very convenient, as types and their methods and members et cetera are represented using `IEnumerable` collections, which we can easily filter and apply transformations to using LINQ syntax (like seen in the example with the `SelectMany` statement, which selects a member on each entry and flattens the resulting new enumerable@dotnetdocs[Enumerable.SelectMany Method]). This makes it usually quite easy to understand the fabric code and reason about which of our aspects are applied to which declarations in our code base. For example, we could easily write a fabric that takes all classes from one of our namespaces that contains all our entities and apply the `[Memento]` and `[UnsavedChanges]` aspects from @memento and @unsaved_changes respectively to these types.

#figure(
```cs
using Metalama.Framework.Code;
using Metalama.Framework.Fabrics;
using System.Linq;

namespace Doc.ProjectFabric_TwoAspects;

internal class Fabric : ProjectFabric
{
    public override void AmendProject(IProjectAmender project)
    {
        AddLogging( project );
    }

    private static void AddLogging(IProjectAmender project)
    {
        project
            .SelectMany( p => p.Types )
            .SelectMany( t => t.Methods )
            .AddAspectIfEligible<LogAttribute>();
    }
}
```, caption: [Example shortened from @metadocs[Adding many aspects at once, Example 2 - Fabric Code]]
)<metalama_fabric_example>

== Moyou
While working on this topic, the Metalama aspect library project Moyou (japanese #text(font: "Noto Sans JP")[模様], transliterated as moyō, meaning pattern or design) was created to house the implementations of all the patterns presented in this work. The repository of the project is freely accessible at [https://github.com/niklasstich/moyou].

The Moyou project is largely divided into 5 namespaces: 
- `Moyou.Aspects`, where the actual implementations presented in Sections #ref(<memento>, supplement: none), #ref(<singleton>, supplement: none), #ref(<unsaved_changes>, supplement: none) and #ref(<factory>, supplement: none) can be found,
- `Moyou.Diagnostics`, which holds the information required in diagnostics emitted by the aspect implementations,
- `Moyou.Extensions`, a collection of useful extension methods@dotnetdocs[Extension Methods (C\# Programming Guide)] used across various aspects,
- `Moyou.Test`, a library of text-based snapshot tests that verify that, for a given input, our aspects generate the correct output code,
- `Moyou.UnitTest`, another test library which applies aspects to actual classes and tests that the generated code functions as expected.

Regarding `Moyou.Test`, special care was taken to consider as many likely scenarios of possible kinds of input to the aspects as possible, including input that results in warning or error diagnostics by the aspects (such as e.g. marking an abstract class as a singleton). The benefits of splitting testing across both compile-time and run-time code of aspects will be more thoroughly explained after the first aspect is introduced in @memento_consequences.


== A note on notation
This paper uses PlantUML#footnote([https://plantuml.com/]) to generate the various diagrams shown throughout. In @classdiag_legend, a legend showing the various different elements and relationship of the UML diagrams used here can be observed#footnote([A full reference is available at https://plantuml.com/class-diagram for class diagrams and https://plantuml.com/activity-diagram-beta for activity diagrams.]). In general, only members relevant to the topic at hand will be shown on types in class diagrams. Class diagrams that contain Metalama aspect types will not have their template members represented in these class diagrams as they are not actually relevant to the aspect itself but are rather applied to the target declaration of the aspect.

#figure(
    image("../diagrams/legend.svg"), caption: [PlantUML class diagram legend]
)<classdiag_legend>

Please note that, due to space constraints, listings containing source code are sometimes formatted differently than in the source they are from, including omitting excess empty lines, class or method signature declarations and comments. Lines that are too long to fit on a page will sometimes be broken into multiple lines. Be assured that these modifications of the source code do not change the functionality at all.

#pagebreak(weak: true)
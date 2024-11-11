= Introduction
== Aspect-Oriented Programming<aop>
In 1997, Kiczales et al. first posited the concept of aspect-oriented programming (AOP) in @Kiczales1997. Specifically, they found that in modern software applications, there exist components, which are concerned with what they call "functional decomposition" of our business logic@Kiczales1997[p. 2f, p. 6f], essentially breaking apart our functional requirements into the levels of abstraction the language at hand supports and separate properties which they coined as "cross-cutting concerns", often non-functional requirements "that affect the performance or semantics of the components"@Kiczales1997[p. 6f] that span across these abstractions@Kiczales1997[p. 7], namely classes in the case of object-oriented programming (OOP) languages like C\# at hand. The solution to these cross-cutting concerns are called "aspects", and they exist, conceptually, outside of our component hierarchy@Kiczales1997[p. 7]. The problem with aspects is that, in classic OOP languages, there is no good way to abstract them out of the components or classes they span across@Kiczales1997[p. 6f]. A good example of this is logging@metadocs: Say we want to provide trace logging across our entire existing application, putting out a log message whenever we enter and exit a method on the call stack@metadocs[Commented examples - Logging]. Out of the box, there is no good way to realize this in C\# in a manner that does not affect our functional units, or in other words, classes, and as a consequence we would have to add explicit logging statements to every method in our application.

Metaprogramming can help us solve this issue in a more implementation-agnostic way. There are many different approaches in the metaprogramming space, such as the "Metaobject Protocol"#footnote([An example of a metaobject protocol language is Common Lisp or more specifically the Common Lisp Object System, an extension of Common Lisp that constitutes "a high-level object-oriented language"@Kiczales1999[p. 2], the design of which the authors of @Kiczales1999 have been involved in.]), described in @Kiczales1999, in which the basic structural building blocks of a language are themselves represented by first-class objects of the language that can be manipulated through writing code in the language@Kiczales1999[p. 1, p. 137]. This is a very powerful approach, because it allows us to manipulate how the language itself is implemented during run-time@Kiczales1999[p. 1]. On the other hand, there are more structured approaches like the "aspect weaver", which focuses on solving the implementation of aspects from the previous definition of AOP. Aspect weavers combine both the "component language", the programming language in which we write our functional components (e.g. classes), and an "aspect language", in which we write our aspects which, when woven with the aspect weaver (a compiler of sorts), manipulate our input components to generate our final program@Kiczales1997[p. 9]. There are also approaches that do this aspect weaving during run-time, but these will not be the focus of this work.

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

This work is concerned with how we can use aspect-oriented programming to automatically implement various classic software design patterns such as the ones found in @Gamma1994 and a non-conventional example. These patterns often try to solve a cross-cutting concern, but because they are confined to the paradigm of object-oriented programming, this approach has drawbacks. The concrete advantages of using AOP to address the implementation of these patterns will become clear once we apply the principles to concrete examples and will be thoroughly analyzed in Sections #ref(<memento_consequences>, supplement: none), #ref(<singleton_consequences>, supplement: none), #ref(<unsaved_consequences>, supplement: none) and #ref(<factory_consequences>, supplement: none).

== .NET ecosystem metaprogramming solutions
In the .NET ecosystem, which has been chosen for this work as the author is most familiar with C\# from previous work experience, there are several tools available that may facilitate AOP and metaprogramming in general to various degrees. Ideally, we would want to use a .NET based templating solution so we can write C\# code that generates C\# code, as it is most comfortable for a developer to stay in the same ecosystem they are already familiar with. Some possible solutions will be explored in this section, no claim is being made that this list of solutions is exhaustive or that there doesn't exist a more ideal solution.

TODO: NUTZWERTANALYSE => Siehe dazu Projektmanagement Burghardt ISBN 978-3-89578-472-9
=== T4 templates
T4#footnote([T4 is an acronym for Text Template Transformation Toolkit]) templates are a .NET technology that allow mixing raw text and C\# or Visual Basic program code and that can be used to generate any arbitrary text files, including C\# source code@dotnetdocs[Code Generation and T4 Text Templates]. These T4 templates can then be transformed either at run-time or compile-time#footnote([The T4 documentation mentions "design time" in this context@dotnetdocs[Code Generation and T4 Text Templates]. Design-time builds are run by the IDE during editing of a codebase and are smaller, faster builds that are used to gather information for tools like Intellisense that aid the development experience. This means that templates are technically expanded while we are working on our solution, but as we are not concerned with the design-time experience in this paper, we will keep referring to design-time semantics as compile-time for the rest of this document.]) into a string or a file respectively. An example of a very simple run-time T4 text template that generates an HTML page which contains the current datetime is given in @approach_t4_template_html. Another, more involved example of a compile-time T4 template is given in @approach_t4_template_cs, where a XML file is used as input to generate a .cs source code file that can then be used as part of a C\# project.
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

=== Source Generator
Source generators, or more specifically incremental generators#footnote([Incremental generators are an inprovement upon legacy v1 source generators@roslyndocs[source-generators.md] and have multiple benefits, most notably that they are much more performant because of caching and other low-level optimizations in how they access compiler information@roslyndocs[incremental-generators.md], which improves performance at design-time by making the editing experience in the IDE more snappy. We'll henceforth just refer to them as source generators as they are conceptually very similar.]), are a feature of the .NET compiler toolchain Roslyn which allows us to access internal compiler information at compile-time and generate new code that should be added to a solution during the compilation process. Source generators are already finding application in the .NET framework itself, such as in the `System.Text.Json` namespace to generate the (de-)serialization implementation of types at compile-time rather than using runtime reflection or  Conceptually, source generators are intended *only* for adding new content t

=== Postsharp

=== Metalama<metalama>
Roslyn Fork
Pro: Kann schon viel, bereits "battle tested", aktive Weiterentwicklung, garantierter Support weil kommerzielles Produkt
aspekte erklaeren und wie sie funktionieren

Contra: Kommerzielles Produkt, kann noch nicht alles (z.B. nested types generieren)
== Similar solutions in other languages (?)
Java? Google Auto? Telosys? jOOQ? hygen?
== Custom code generation framework
Viel zu viel Arbeit für den Rahmen einer Masterarbeit

#pagebreak(weak: true)
#import "config.typ": head
#show: doc => head(
  title: [A Source Code Generator Package for Common Design and Programming Patterns],
  authors: (
    (
      name: "Niklas Stich",
      affiliation: "Kempten University of Applied Sciences",
      email: "niklas.stich@hs-kempten.de",
    ),
  ),
  abstract: lorem(80),
  doc,
)

#outline(title: "Table of contents")

#include "chapters/introduction.typ"
#include "chapters/approach.typ"
#include "chapters/metalama.typ"
#include "chapters/patterns.typ"
#include "chapters/conclusion.typ"


#bibliography("sources.bib", style: "ieee")
#outline(title: "Table of Figures", target: figure)
//#outline(title: "Table of tables", target: table)
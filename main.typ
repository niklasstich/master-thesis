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

$a^(alpha_5^7)$
$Alpha$


#include "chapters/introduction.typ"
#include "chapters/approach.typ"
#include "chapters/metalama.typ"
#include "chapters/patterns.typ"
#include "chapters/conclusion.typ"

TODO: APPENDIX (kein Appendix, stattdessen z.B. ausführliches Beispiel auf Datenträger)

#bibliography("sources.bib", style: "ieee")
#outline(title: "Table of figures", target: figure)
//#outline(title: "Table of tables", target: table)
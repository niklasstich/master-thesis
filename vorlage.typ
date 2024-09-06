#import "config.typ": template
#show: template

#include "chapters/title.typ"
#pagebreak(weak: true)

#include "chapters/abstract.typ"
#include "chapters/toc.typ"

#include "chapters/introduction.typ"
#include "chapters/approach.typ"
#include "chapters/metalama.typ"
#include "chapters/patterns.typ"
#include "chapters/conclusion.typ"

TODO: APPENDIX (kein Appendix, stattdessen z.B. ausführliches Beispiel auf Datenträger)


#pagebreak(weak: false)
#bibliography("sources.bib", style: "ieee")
#pagebreak(weak: false)

#include "chapters/tof.typ"
#include "chapters/erklaerung.typ"
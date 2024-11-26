#import "config.typ": template
#show: template

#include "chapters/title.typ"
#pagebreak(weak: true)

#include "chapters/acknowledgements.typ"

#include "chapters/abstract.typ"

#set page(numbering: "1")
#counter(page).update(1)

#include "chapters/toc.typ"

// #include "chapters/introduction.typ"
#include "chapters/approach.typ"
//#include "chapters/metalama.typ"
#include "chapters/patterns.typ"
#include "chapters/conclusion.typ"


#pagebreak(weak: false)
#bibliography("sources.bib", style: "ieee")
#pagebreak(weak: false)

#include "chapters/tof.typ"
#include "chapters/erklaerung.typ"
#set outline(fill: [#box(width: 1fr, repeat[#h(3pt).#h(3pt)])#h(0.5cm)])
#show outline.entry.where(level: 1): entry => strong({
  v(15pt, weak: true)
  entry.body
  h(1fr)
  entry.page
})
#heading(outlined: false, numbering: none, "Table of contents")
#v(1em)
#outline(title: none, indent: auto, target: heading, depth: 10)
#pagebreak(weak: true)
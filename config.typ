#let conf(
  title: none,
  authors: (),
  abstract: [],
  doc,
) = {

  set text(
    font: "New Computer Modern",
  )
  
  set page(
    paper: "a4",
    margin: (x: 1.82cm, y:1.5cm)
  )

  set par(
    justify: true,
    leading: 0.6em
  )

  set heading(
    numbering: "1."
  )

  set align(center)
  text(17pt, title)

  let count = authors.len()
  let ncols = calc.min(count, 3)

  grid(
    columns: (1fr,) * ncols,
    row-gutter: 24pt,
    ..authors.map(author => [
      #author.name \
      #author.affiliation \
      #link("mailto:" + author.email)
    ]),
  )

  // Set and show rules from before.
  set text(
    size: 12pt
  )
  par(justify: false)[
    *Abstract* \
    #abstract
  ]

  set align(left)
  doc
}
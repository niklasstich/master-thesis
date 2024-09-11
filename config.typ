#let template(doc) = [
  //Metadaten für das Dokument, bitte selbst einfügen
  #set document(author: "", title: "", date: auto, keywords: "")

  //Einstellung für Seiten
  #set page(paper: "a4", margin: (left: 25mm, right: 20mm, top: 25mm, bottom: 25mm))

  //Einstellungen für Text
  #set text(size: 12pt, font: "New Computer Modern")
  #set par(leading: 0.55em, justify: true, linebreaks: "optimized")
  #show par: set block(spacing: 0.55em)

  //Einstellungen für Überschriften
  #set heading(numbering: "1.1")
  #show heading: set block(above: 1.4em, below: 1em)
  #show heading.where(level: 1): set text(size: 17.28pt)
  #show heading.where(level: 2): set text(size: 14.4pt)

  //Einstellungen für Zitate
  // #show figure.where(kind: image): set figure(supplement: "Abbildung")
  // #show figure.where(kind: table): set figure(supplement: "Tabelle")
  #set figure(numbering: "1.1")
  //Per-section-numbering ist in typst aktuell (04/24) noch nicht supported und ist auf der roadmap. D.h. die nummerierung ist 1, 2, 3 statt 1.1, 1.2, 2.1
  //Man kann das mit dem numbering-parameter manuell überschreiben, ist aber nicht ganz sinn der sache
  #set bibliography(style: "Literatur/din-1505-2-alphanumeric.csl")
  //Ich habe leider keinen exakten match für den "alphadin"-style gefunden, der in der LaTeX Vorlage verwendet wird. DIN-1505 kommt dem am nähesten
  //Den Zitierstil muss man aber sowieso mit dem jeweiligen Betreuer absprechen!
  //Quelle für die csl-Datei: https://www.zotero.org/styles?format=label (Stand 4.4.24)

  #import "@preview/pintorita:0.1.1"

  #show raw: set text(font: "Fira Code", ligatures: true)
  #show raw.where(lang: "pintora"): it => pintorita.render(it.text)

  #doc
]

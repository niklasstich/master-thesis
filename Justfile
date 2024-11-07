set windows-shell := ["pwsh", "-NoLogo", "-Command"]

build: build-images
	typst compile vorlage.typ output.pdf

build-images:
	java -jar ./diagrams/plantuml-1.2024.7.jar -tsvg ./diagrams/**/*.diag
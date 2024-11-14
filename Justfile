set windows-shell := ["pwsh", "-NoLogo", "-Command"]

build: build-images
	typst compile vorlage.typ output.pdf

build-images:
	find ./diagrams -type f -name "*.diag" -exec java -jar ./diagrams/plantuml-1.2024.7.jar -tsvg {} + 
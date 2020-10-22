npmbin=node_modules/.bin
cfcm=$(npmbin)/commonform-commonmark
cfdocx=$(npmbin)/commonform-docx
lint=$(npmbin)/commonform-lint
critique=$(npmbin)/commonform-critique
json=$(npmbin)/json
tools=$(cfcm) $(cfdocx) $(lint) $(critique) $(json)
basenames=offer-letter confidentiality-ip-terms employment-terms
forms=$(addprefix build/,$(addsuffix .json,$(filter-out offer-letter, $(basenames))))

all: docx pdf

docx: $(foreach basename,$(basenames:=.docx),$(addprefix build/,$(basename)))

pdf: $(foreach basename,$(basenames:=.pdf),$(addprefix build/,$(basename)))

build/%.docx: %.docx | build
	cp $< $@

build/%.docx: build/%.json build/%.title build/%.edition build/%.directions build/%.blanks build/%.signatures styles.json | $(cfdocx) build
	$(cfdocx) --title "$(shell cat build/$*.title)" --edition "$(shell cat build/$*.edition)" --number outline --left-align-title --smartify --indent-margins --styles styles.json --values build/$*.blanks --directions build/$*.directions --signatures build/$*.signatures --mark-filled $< > $@

build/%.title: build/%.parsed | $(json) build
	$(json) frontMatter.title < $< > $@

build/%.edition: build/%.parsed | $(json) build
	$(json) frontMatter.edition < $< > $@

build/%.json: build/%.parsed | $(json) build
	$(json) form < $< > $@

build/%.blanks: build/%.parsed | $(json) build
	$(json) frontMatter.blanks < $< > $@

build/%.signatures: build/%.parsed | $(json) build
	$(json) frontMatter.signatures < $< > $@

build/%.directions: build/%.parsed | $(json) build
	$(json) directions < $< > $@

build/%.parsed: %.md | $(cfcm) build
	$(cfcm) parse $<  > $@

%.pdf: %.docx
	unoconv $<

build:
	mkdir -p $@

$(tools):
	npm ci

.PHONY: lint critique clean docker

lint: $(forms) | $(lint) $(json)
	@for form in $(forms); do \
		echo ; \
		echo $$form; \
		cat $$form | $(lint) | $(json) -a message | sort -u; \
	done; \

critique: $(forms) | $(critique) $(json)
	@for form in $(forms); do \
		echo ; \
		echo $$form ; \
		cat $$form | $(critique) | $(json) -a message | sort -u; \
	done

clean:
	rm -rf build

dockertag=square-one-forms

docker:
	docker build -t $(dockertag) .
	docker run --name $(dockertag) $(dockertag)
	docker cp $(dockertag):/workdir/build .
	docker rm $(dockertag)

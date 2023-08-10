npmbin=node_modules/.bin
cfcm=$(npmbin)/commonform-commonmark
cfdocx=$(npmbin)/commonform-docx
cfhtml=$(npmbin)/commonform-html
lint=$(npmbin)/commonform-lint
critique=$(npmbin)/commonform-critique
json=$(npmbin)/json
tools=$(cfcm) $(cfdocx) $(lint) $(critique) $(json)
common_form_basenames=confidentiality-ip employee contractor
docx_basenames=offer-letter statement-of-work
all_basenames=$(common_form_basenames) $(docx_basenames)
forms=$(addprefix build/,$(addsuffix .json,$(common_form_basenames)))

VERSION ?= Development Draft
ifeq ($(VERSION),Development Draft)
	VERSION_NUMBER=DRAFT
	VERSION_STRING=Development Draft
else
	VERSION_NUMBER=$(VERSION)
	VERSION_STRING=Version $(VERSION)
endif

all: docx pdf html rtf

docx: $(foreach basename,$(all_basenames:=.docx),$(addprefix build/,$(basename)))

rtf: $(foreach basename,$(all_basenames:=.rtf),$(addprefix build/,$(basename)))

pdf: $(foreach basename,$(all_basenames:=.pdf),$(addprefix build/,$(basename)))

html: $(foreach basename,$(common_form_basenames:=.html),$(addprefix build/,$(basename)))

build/%.docx: %.html reference.docx | build
	cat $< \
		| sed "s/VERSION_NUMBER/$(VERSION_NUMBER)/g" \
		| sed "s/VERSION_STRING/$(VERSION_STRING)/g" \
		| pandoc -f html -o $@ --reference-doc reference.docx

build/%.rtf: build/%.docx | build
	soffice --headless --convert-to rtf --outdir build $<

build/%.docx: build/%.json build/%.title build/%.directions build/%.blanks build/%.signatures styles.json | $(cfdocx) build
	$(cfdocx) --title "$(shell cat build/$*.title)" --form-version "$(VERSION_STRING)" --number outline --left-align-title --smart --indent-margins --styles styles.json --values build/$*.blanks --directions build/$*.directions --signatures build/$*.signatures $< > $@

build/%.html: build/%.json build/%.title build/%.directions build/%.blanks build/%.signatures styles.json | $(cfdocx) build
	$(cfhtml) --html5 --smart --lists --ids --title "$(shell cat build/$*.title)" --form-version "$(VERSION_STRING)" --values build/$*.blanks --directions build/$*.directions --signatures build/$*.signatures < $< > $@

build/%.title: build/%.parsed | $(json) build
	$(json) frontMatter.title < $< > $@

build/%.json: build/%.parsed | $(json) build
	$(json) form < $< > $@

build/%.blanks: build/%.parsed | $(json) build
	$(json) frontMatter.blanks < $< > $@

build/%.signatures: build/%.parsed | $(json) build
	$(json) frontMatter.signatures < $< > $@

build/%.directions: build/%.parsed | $(json) build
	$(json) directions < $< > $@

build/%.parsed: %.md | $(cfcm) build
	cat $< \
		| sed "s/VERSION_NUMBER/$(VERSION_NUMBER)/g" \
		| sed "s/VERSION_STRING/$(VERSION_STRING)/g" \
		| $(cfcm) parse > $@

build/%.pdf: build/%.docx
	soffice --headless --convert-to pdf --outdir build $<

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

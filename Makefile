#
# Makefile to build ZIP and README.html
#

# If this is changed, the version in th completion and support scripts and the
# xsl has to be changed too.
VERSION = 0.1.0

NAME = extensible-maven-completion
ZIP_NAME = $(NAME)-$(VERSION).zip
ZIP_CONTENT = README.md INSTALL _maven-completion.bash bin/mvn-comp-create-extension.sh bin/mvn-comp-create-extension.xsl

.PHONY: zip html clean check help tests

all:    tests check zip    ## run tests, shellcheck and build zip

help:
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%s\033[0m\n    %s\n", $$1, $$2}'

tests:   ## run tests
	tests/test_comp.sh "$(VERSION)"

check:  ## run shellcheck
	shellcheck -sbash -fgcc _maven-completion.bash bin/*.sh tests/test_comp.sh

version_check:  ## Check that version is set correctly
	./version_check.sh "$(VERSION)"

zip: version_check $(ZIP_NAME)            ## Build zip file

html: README.html           ## Build README.html

$(ZIP_NAME): $(ZIP_CONTENT)
	zip $@ $^


README.html: README.md
	marked --gfm --tables $< > $@

clean:                     ## Cleanup by removing README.html and zip file
	rm -f $(ZIP_NAME) README.html
	rm -rf tests/workdir


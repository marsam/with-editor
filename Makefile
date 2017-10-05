-include config.mk

PKG = with-editor

ELS   = $(PKG).el
ELCS  = $(ELS:.el=.elc)

DEPS  = dash

EMACS      ?= emacs
EMACS_ARGS ?=
EMACS_ARGS += --eval '(setq with-editor-emacsclient-executable nil)'

LOAD_PATH  ?= $(addprefix -L ../,$(DEPS))
LOAD_PATH  += -L .

ifndef ORG_LOAD_PATH
ORG_LOAD_PATH  = -L ../dash
ORG_LOAD_PATH += -L ../org/lisp
ORG_LOAD_PATH += -L ../org/contrib/lisp
ORG_LOAD_PATH += -L ../ox-texinfo+
endif

INSTALL_INFO     ?= $(shell command -v ginstall-info || printf install-info)
MAKEINFO         ?= makeinfo
MANUAL_HTML_ARGS ?= --css-ref /assets/page.css

VERSION := $(shell test -e .git && \
	git tag | cut -c2- | sort --version-sort | tail -1)

all: lisp info
doc: info html html-dir pdf

help:
	$(info make all          - generate lisp and manual)
	$(info make doc          - generate most manual formats)
	$(info make lisp         - generate byte-code and autoloads)
	$(info make texi         - generate texi manual)
	$(info make info         - generate info manual)
	$(info make html         - generate html manual file)
	$(info make html-dir     - generate html manual directory)
	$(info make pdf          - generate pdf manual)
	$(info make bump-version - bump version strings)
	$(info make authors      - generate AUTHORS.md)
	$(info make preview      - preview html manual)
	$(info make publish      - publish html manual)
	$(info make clean        - remove most generated files)
	$(info make clean-texi   - remove (tracked) texi manual)
	$(info make clean-all    - remove all generated files)
	@printf "\n"

lisp: $(ELCS) loaddefs

loaddefs: $(PKG)-autoloads.el

%.elc: %.el
	@printf "Compiling $<\n"
	@$(EMACS) -Q --batch $(EMACS_ARGS) $(LOAD_PATH) -f batch-byte-compile $<

bump-version:
	@sed -i -e "s/\(#+SUBTITLE: for version \)[.0-9]*/\1$(VERSION)/" $(PKG).org

texi: $(PKG).texi
info: $(PKG).info dir
html: $(PKG).html
pdf:  $(PKG).pdf

ORG_ARGS  = --batch -Q $(ORG_LOAD_PATH) -l ox-extra -l ox-texinfo+.el
ORG_EVAL  = --eval "(ox-extras-activate '(ignore-headlines))"
ORG_EVAL += --eval "(setq indent-tabs-mode nil)"
ORG_EVAL += --eval "(setq org-src-preserve-indentation nil)"
ORG_EVAL += --funcall org-texinfo-export-to-texinfo

%.texi: %.org
	@printf "Generating $@\n"
	@$(EMACS) $(ORG_ARGS) $< $(ORG_EVAL)
	@printf "\n" >> $@
	@rm -f $@~

%.info: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --no-split $< -o $@

dir: $(PKG).info
	@printf "Generating $@\n"
	@printf "%s" $^ | xargs -n 1 $(INSTALL_INFO) --dir=$@

%.html: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --html --no-split $(MANUAL_HTML_ARGS) $<

html-dir: $(PKG).texi
	@printf "Generating $(PKG)/*.html\n"
	@$(MAKEINFO) --html $(MANUAL_HTML_ARGS) $<

%.pdf: %.texi
	@printf "Generating $@\n"
	@texi2pdf --clean $< > /dev/null

DOMAIN         ?= magit.vc
PUBLISH_BUCKET ?= s3://$(DOMAIN)
PREVIEW_BUCKET ?= s3://preview.$(DOMAIN)
PUBLISH_TARGET ?= $(PUBLISH_BUCKET)/manual/
PREVIEW_TARGET ?= $(PREVIEW_BUCKET)/manual/

preview: html html-dir pdf
	@aws s3 cp $(PKG).html $(PREVIEW_TARGET)
	@aws s3 cp $(PKG).pdf $(PREVIEW_TARGET)
	@aws s3 sync $(PKG) $(PREVIEW_TARGET)$(PKG)/

publish: html html-dir pdf
	@aws s3 cp $(PKG).html $(PUBLISH_TARGET)
	@aws s3 cp $(PKG).pdf $(PUBLISH_TARGET)
	@aws s3 sync $(PKG) $(PUBLISH_TARGET)$(PKG)/

CLEAN  = $(ELCS) $(PKG)-autoloads.el $(PKG).info dir
CLEAN += $(PKG) $(PKG).html $(PKG).pdf

clean:
	@printf "Cleaning...\n"
	@rm -rf $(CLEAN)

clean-texi:
	@printf "Cleaning...\n"
	@rm -f $(PKG).texi

clean-all:
	@printf "Cleaning...\n"
	@rm -rf $(CLEAN) $(PKG).texi

authors: AUTHORS.md

AUTHORS.md:
	@ printf "Authors\n=======\n\n" > $@
	@ ( printf "%s\n" "- Barak A. Pearlmutter <barak+git@pearlmutter.net>" && \
	    printf "%s\n" "- Lele Gaifax <lele@metapensiero.it>" && \
	    printf "%s\n" "- Rémi Vanicat <vanicat@debian.org>" && \
	    git log --pretty=format:'- %aN <%aE>' \
	  ) | sort -u >> $@

define LOADDEFS_TMPL
;;; $(PKG)-autoloads.el --- automatically extracted autoloads
;;
;;; Code:
(add-to-list 'load-path (directory-file-name \
(or (file-name-directory #$$) (car load-path))))

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; End:
;;; $(PKG)-autoloads.el ends here
endef
export LOADDEFS_TMPL
#'

$(PKG)-autoloads.el: $(ELS)
	@printf "Generating $@\n"
	@printf "%s" "$$LOADDEFS_TMPL" > $@
	@$(EMACS) -Q --batch --eval "(progn\
	(setq make-backup-files nil)\
	(setq vc-handled-backends nil)\
	(setq default-directory (file-truename default-directory))\
	(setq generated-autoload-file (expand-file-name \"$@\"))\
	(setq find-file-visit-truename t)\
	(update-directory-autoloads default-directory))"

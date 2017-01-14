BIN_DIR := bin
SCRIPT_DIR := scripts
SRC_DIR := src
OUT_DIR := out
RECORDINGS_DIR := recordings

GENERATED_FILES := reseau.txt words.mlf phones.mlf hmm0/proto hmm0/hmmdefs hmm1/hmmdefs hmm2/hmmdefs hmm3/hmmdefs
GENERATED_FILES := $(addprefix $(OUT_DIR)/, $(GENERATED_FILES))

SENTENCES_TO_READ := 20

.PHONY := all update_mfc a_lire.txt

all: $(GENERATED_FILES) | $(OUT_DIR)/list.scp

$(OUT_DIR)/reseau.txt: $(SRC_DIR)/grammaire.txt | $(OUT_DIR)
	$(BIN_DIR)/HParse $^ $@

$(OUT_DIR)/words.mlf: $(OUT_DIR)/a_lire.txt
	$(SCRIPT_DIR)/prompts2mlf $^ > $@

$(OUT_DIR)/phones.mlf: $(SRC_DIR)/dictionnaire.txt $(SRC_DIR)/mkphones.led $(OUT_DIR)/words.mlf | $(OUT_DIR)
	$(BIN_DIR)/HLEd -l '*' -d $(SRC_DIR)/dictionnaire.txt -i $@ $(SRC_DIR)/mkphones.led $(OUT_DIR)/words.mlf

$(OUT_DIR)/hmm0/proto: | $(OUT_DIR)/list.scp $(OUT_DIR)/hmm0
	$(BIN_DIR)/HCompV -T 1 -C $(SRC_DIR)/mfccda.conf -f 0.01 -m -M $(OUT_DIR)/hmm0 $(SRC_DIR)/proto $(RECORDINGS_DIR)/*.mfc

$(OUT_DIR)/hmm0/hmmdefs: $(OUT_DIR)/hmm0/proto
	$(SCRIPT_DIR)/initialise_modeles $(OUT_DIR)/hmm0 $(SRC_DIR)/monophones.txt

$(OUT_DIR)/hmm1/hmmdefs: $(OUT_DIR)/hmm0/hmmdefs | $(OUT_DIR)/hmm1
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm0/hmmdefs -M $(OUT_DIR)/hmm1 $(SRC_DIR)/monophones.txt $(RECORDINGS_DIR)/*.mfc

$(OUT_DIR)/hmm2/hmmdefs: $(OUT_DIR)/hmm1/hmmdefs | $(OUT_DIR)/hmm2
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm1/hmmdefs -M $(OUT_DIR)/hmm2 $(SRC_DIR)/monophones.txt $(RECORDINGS_DIR)/*.mfc

$(OUT_DIR)/hmm3/hmmdefs: $(OUT_DIR)/hmm2/hmmdefs | $(OUT_DIR)/hmm3
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm2/hmmdefs -M $(OUT_DIR)/hmm3 $(SRC_DIR)/monophones.txt $(RECORDINGS_DIR)/*.mfc

update_mfc: $(OUT_DIR)/list.scp
	$(BIN_DIR)/HCopy -T 1 -C $(SRC_DIR)/mfcc.conf -S $(OUT_DIR)/list.scp

a_lire.txt: $(OUT_DIR)/reseau.txt $(SRC_DIR)/dictionnaire.txt | $(OUT_DIR)
	$(BIN_DIR)/HSGen -n $(SENTENCES_TO_READ) $^ > $@

$(OUT_DIR)/list.scp:
	$(SCRIPT_DIR)/dir2list $(RECORDINGS_DIR) > $@
	$(MAKE) update_mfc

$(OUT_DIR):
	mkdir $@

$(OUT_DIR)/hmm%:
	mkdir -p $@

$(RECORDINGS_DIR):
	tar -xvfz $(RECORDINGS_DIR).tar.gz

clean:
	$(RM) $(GENERATED_FILES)

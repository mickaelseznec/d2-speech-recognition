BIN_DIR := bin
SCRIPT_DIR := scripts
SRC_DIR := src
OUT_DIR := out
RECORDINGS_DIR := recordings
TRAIN_DIR := $(RECORDINGS_DIR)/train
TEST_DIR := $(RECORDINGS_DIR)/test

GENERATED_FILES := reseau.txt words.mlf phones.mlf hmm0/proto hmm0/hmmdefs hmm1/hmmdefs hmm2/hmmdefs hmm3/hmmdefs reco.mlf hmm4/hmmdefs hmm5/hmmdefs hmm6/hmmdefs hmm7/hmmdefs


GENERATED_FILES := $(addprefix $(OUT_DIR)/, $(GENERATED_FILES))

SENTENCES_TO_READ := 20

.PHONY := all update_mfc new_sentences

all: $(GENERATED_FILES) | $(OUT_DIR)/list.scp

$(OUT_DIR)/reseau.txt: $(SRC_DIR)/grammaire.txt | $(OUT_DIR)
	$(BIN_DIR)/HParse $^ $@

$(OUT_DIR)/words.mlf: a_lire.txt
	$(SCRIPT_DIR)/prompts2mlf $^ > $@

$(OUT_DIR)/phones.mlf: $(SRC_DIR)/dictionnaire.txt $(SRC_DIR)/mkphones.led $(OUT_DIR)/words.mlf | $(OUT_DIR)
	$(BIN_DIR)/HLEd -l '*' -d $(SRC_DIR)/dictionnaire.txt -i $@ $(SRC_DIR)/mkphones.led $(OUT_DIR)/words.mlf

$(OUT_DIR)/hmm0/proto: | $(OUT_DIR)/list.scp $(OUT_DIR)/hmm0 $(RECORDINGS_DIR)
	$(BIN_DIR)/HCompV -T 1 -C $(SRC_DIR)/mfccda.conf -f 0.01 -m -M $(OUT_DIR)/hmm0 $(SRC_DIR)/proto $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm0/hmmdefs: $(OUT_DIR)/hmm0/proto
	$(SCRIPT_DIR)/initialise_modeles $(OUT_DIR)/hmm0 $(SRC_DIR)/monophones.txt

$(OUT_DIR)/hmm1/hmmdefs: $(OUT_DIR)/hmm0/hmmdefs | $(OUT_DIR)/hmm1
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm0/hmmdefs -H $(OUT_DIR)/hmm0/macros -M $(OUT_DIR)/hmm1 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm2/hmmdefs: $(OUT_DIR)/hmm1/hmmdefs | $(OUT_DIR)/hmm2
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm1/hmmdefs -H $(OUT_DIR)/hmm1/macros -M $(OUT_DIR)/hmm2 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm3/hmmdefs: $(OUT_DIR)/hmm2/hmmdefs | $(OUT_DIR)/hmm3
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm2/hmmdefs -H $(OUT_DIR)/hmm2/macros -M $(OUT_DIR)/hmm3 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm4/hmmdefs: $(OUT_DIR)/hmm3/hmmdefs | $(OUT_DIR)/hmm4
	$(BIN_DIR)/HHEd -H $(OUT_DIR)/hmm3/hmmdefs -H $(OUT_DIR)/hmm3/macros -M $(OUT_DIR)/hmm4 $(SRC_DIR)/mixup-2.hed $(SRC_DIR)/monophones.txt

$(OUT_DIR)/hmm5/hmmdefs: $(OUT_DIR)/hmm4/hmmdefs | $(OUT_DIR)/hmm5
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm4/hmmdefs -H $(OUT_DIR)/hmm4/macros -M $(OUT_DIR)/hmm5 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm6/hmmdefs: $(OUT_DIR)/hmm5/hmmdefs | $(OUT_DIR)/hmm6
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm5/hmmdefs -H $(OUT_DIR)/hmm5/macros -M $(OUT_DIR)/hmm6 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/hmm7/hmmdefs: $(OUT_DIR)/hmm6/hmmdefs | $(OUT_DIR)/hmm7
	$(BIN_DIR)/HERest -C $(SRC_DIR)/mfccda.conf -I $(OUT_DIR)/phones.mlf -t 250.0 150.0 1000.0 \
	    -H $(OUT_DIR)/hmm6/hmmdefs -H $(OUT_DIR)/hmm6/macros -M $(OUT_DIR)/hmm7 $(SRC_DIR)/monophones.txt $(TRAIN_DIR)/*.mfc

$(OUT_DIR)/reco.mlf: $(OUT_DIR)/hmm7/hmmdefs
	$(BIN_DIR)/HVite -T 1 -t 500 -l '*' -C $(SRC_DIR)/mfccda.conf -H $(OUT_DIR)/hmm7/macros -H $(OUT_DIR)/hmm7/hmmdefs -i $@ -p 0.0 -s 5.0 -w $(OUT_DIR)/reseau.txt $(SRC_DIR)/dictionnaire.txt $(SRC_DIR)/monophones.txt $(TEST_DIR)/*.mfc > /dev/null

$(OUT_DIR)/test.mlf: a_lire_test.txt
	$(SCRIPT_DIR)/prompts2mlftest $^ > $@

results: $(OUT_DIR)/reco.mlf $(OUT_DIR)/test.mlf
	$(BIN_DIR)/HResults -t -I $(OUT_DIR)/test.mlf $(SRC_DIR)/dictionnaire.txt $(OUT_DIR)/reco.mlf

update_mfc: $(OUT_DIR)/list.scp | $(RECORDINGS_DIR)
	$(BIN_DIR)/HCopy -T 1 -C $(SRC_DIR)/mfcc.conf -S $(OUT_DIR)/list.scp

new_sentences: $(OUT_DIR)/reseau.txt $(SRC_DIR)/dictionnaire.txt | $(OUT_DIR)
	$(BIN_DIR)/HSGen -n $(SENTENCES_TO_READ) $^ >> a_lire.txt

$(OUT_DIR)/list.scp: | $(RECORDINGS_DIR)
	$(SCRIPT_DIR)/dir2list $(TRAIN_DIR) > $@
	$(MAKE) update_mfc

$(OUT_DIR):
	mkdir $@

$(OUT_DIR)/hmm%:
	mkdir -p $@

$(RECORDINGS_DIR):
	tar xvfz $(RECORDINGS_DIR).tar.gz

clean:
	$(RM) $(GENERATED_FILES)

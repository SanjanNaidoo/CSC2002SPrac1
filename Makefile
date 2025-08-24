JAVAC := javac
JAVA  := java

SRC := SoloLevelling
BIN := bin

SER := DungeonHunter
PAR := DungeonHunterPAR

SER_SRCS := $(SRC)/DungeonMap.java $(SRC)/Hunt.java $(SRC)/$(SER).java
PAR_SRC  := $(SRC)/$(PAR).java

# Override at call: make run ARGS="100 0.2 0"
ARGS ?= 50 0.10 1

.PHONY: all serial parallel run run-par clean

all: serial parallel

$(BIN):
	mkdir -p $(BIN)

# Compile serial set first so Hunt's reference to DungeonHunter resolves
serial: | $(BIN)
	$(JAVAC) -d $(BIN) $(SER_SRCS)

# Then compile the parallel main against already-built classes in bin/
parallel: serial
	$(JAVAC) -cp $(BIN) -d $(BIN) $(PAR_SRC)

run: serial
	$(JAVA) -cp $(BIN) $(SER) $(ARGS)

run-par: parallel
	$(JAVA) -cp $(BIN) $(PAR) $(ARGS)

clean:
	rm -rf $(BIN)

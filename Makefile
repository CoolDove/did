debug:
	odin build ./src -resource:app.rc -debug -out:game.exe 
release:
	odin build ./src -resource:app.rc -out:game.exe -subsystem:windows

clean:
	rm game.exe game.pdb

cody:
	@cody -direxclude ./src/dude/vendor -q

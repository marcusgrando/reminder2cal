SWIFT = swift build
FLAGS = --configuration release
OUTPUT = .build/release/Reminder2Cal

all: $(OUTPUT)

$(OUTPUT):
	$(SWIFT) $(FLAGS)
	mkdir -p Reminder2Cal.app/Contents/MacOS Reminder2Cal.app/Contents/Resources/
	cp Info.plist Reminder2Cal.app/Contents/
	cp icon.icns Reminder2Cal.app/Contents/Resources/
	xattr -c Reminder2Cal.app/Contents/Resources/icon.icns
	cp $(OUTPUT) Reminder2Cal.app/Contents/MacOS/Reminder2Cal

clean:
	rm -rf Reminder2Cal.app .build

.PHONY: all clean
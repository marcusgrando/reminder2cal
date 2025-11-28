SWIFT = swift build
FLAGS = --configuration release
OUTPUT = .build/release/Reminder2Cal

all: $(OUTPUT)

$(OUTPUT):
	$(SWIFT) $(FLAGS)
	mkdir -p Reminder2Cal.app/Contents/MacOS Reminder2Cal.app/Contents/Resources/
	cp Info.plist Reminder2Cal.app/Contents/
	cp icon.icns Reminder2Cal.app/Contents/Resources/
	cp reminder2cal.svg Reminder2Cal.app/Contents/Resources/
	xattr -c Reminder2Cal.app/Contents/Resources/icon.icns
	xcrun actool --output-format human-readable-text --notices --warnings --platform macosx --minimum-deployment-target 13.0 --compile Reminder2Cal.app/Contents/Resources/ Assets.xcassets
	cp $(OUTPUT) Reminder2Cal.app/Contents/MacOS/Reminder2Cal
	codesign --force --verify --verbose --sign "Developer ID Application: Marcus Nestor Alves Grando (MY427949GW)" Reminder2Cal.app
	touch Reminder2Cal.app

clean:
	rm -rf Reminder2Cal.app .build
	pkill Reminder2Cal

.PHONY: all clean
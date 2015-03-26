#Frequently Asked Question.

**Subler homepage**
The project new home is on bitbucket: https://bitbucket.org/galad87/subler

**Why doesn't QuickTime and others Apple's devices see the subtitles/chapters?**

The file extension must be .m4v, or QuickTime and iPod/AppleTV won't show any subtitles tracks.

**How can I add chapters' images?**

Enable the "Create Preview Images" checkbox in the Preferences, the next time you will save or optimize a file, a new track with the chapters' images will be created.

**Why does my SRT file not import in Subler?**

Even though the text encoding detector should detect the text encoding of your SRT file, it sometimes fails to do so. You'll increase your chances of success by using UTF-8 encoding. You can use Jubler to edit the SRT file before importing in Subler.


**AppleTV 2 hangs on movies with AC-3 audio?**

It seems the latest ATV2 software needs the file to be properly interleaved. You can make it so by using Subler's Optimize function.

**What's the "Optimize" function ?**

It interleaves the audio and video samples, and puts the "MooV" atom at the begining of the file, restoring the Quicktime "fast-start" (also known as "pseudo-streaming") ability of the file.

**How to improve VobSub and PGS ocr**

If you are trying to OCR a non English subtitle track, you can download from https://code.google.com/p/tesseract-ocr/downloads/list the Tesseract 3.02 language files for the language you want, and copy the .tessdata file inside ~/Library/Application Support/Subler/tessdata/ (the library folder inside your home folder, it might be hidden, you can select the Go menu in Finder, press all and select "Library"). Subler will load the new .tessdata file automatically when needed.

**Perian AC-3 issue on Mountain Lion and later OS X releases**

Download A52Codec from the download page, and decompress it in ~/Library/Audio/Plug-Ins/Components .
More info in: http://code.google.com/p/subler/issues/detail?id=404#c12

**Why can't I mux file larger than 4GB?**

You need to enable the "64 Bit chunk offset" checkbox if you think the files will be bigger than 4GB. It's not enabled by default, because many devices (old iPod, Playstation 3) can't read this type of mp4.
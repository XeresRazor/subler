# What is Subler? #

Subler is a Mac OS X application that opens media containers like movie files, lets you to add or remove data inside them, and then saves them out again. In the specialized language of the video world, Subler is a "muxer" (or multiplexer), a muxer dedicated to creating MPEG4 files (.m4v, .mp4) for iDevices.

Subler's original purpose was to allow you to easily add subtitles to your video files, and thus the name "subler", as in "subtitler". In time, new features have been added to help Subler solve similar common problems. For instance, with Subler you can open an existing media file, add chapter titles, remove an unwanted commentary track, tag the file with episode information for a TV show, and then save it back out again.

There are lots of utilities that handle one of these tasks. Subler handles all of them, and quickly!

### What is a "media container"? ###

In the past, computer programs generally worked only with a specific type of data - word processors worked with text, spreadsheets worked with numbers. There was a little variability in data, like adding an image inside a Word document, but there was always some sort of "key data" that every program focused on. Each program saved that data in its own private format, so Microsoft Word documents were different than WordPerfect documents, even though the data inside was essentially the same.

Multimedia changed all this. Multimedia files are highly variable and might contain any sort of data. We are most familiar with movies as the classic multimedia file. If you open a movie file and look inside, you'll find all sorts of different types of data. There's almost always one main video track, but there are very often multiple soundtracks to support different types of audio equipment - Dolby Pro, DTS, etc - and sometimes other features like subtitles. Another file might include audio and text tracks only, a "movie" file used to store music.

In contrast to the older model, in the multimedia world there is no "key data" that the file format can be based on. Every file could have any sort of data inside it.

To support this sort of flexibility, multimedia systems like QuickTime refer to the file format as nothing more than a "container". The container holds different "tracks", in any format you might want. The containers try to be completely agnostic about the data inside, and so in theory any one of the formats could hold any sort of multimedia. You could even store a Word document inside one.

In a perfect world you'd only need one container format, and it could store anything.

But this isn't a perfect world. Many similar container formats sprung up in the early days, and many of these were tightly bound to a particular type of content. AVI, for instance, almost always contained a movie written using a particular video software, while MOV on the Mac was the same, but different. One platform's software couldn't read another's files, making life difficult for everyone.

Things aren't as bad as they used to be. With the introduction of the H.264 video format, the entire media world has quickly been moving to MP4 media. That means that the video inside that QuickTime file is the same as the video inside an WMV. Audio too is likely to work across platforms.

In theory, QuickTime should be the major container format and everyone should be able to read it, as it was accepted as part of the wider MP4 standard.

But in spite of this, or perhaps because of it, different container formats continue to proliferate. Common container formats are .avi and .wmv from the Wintel world, and .mkv, an open-standard developed under the Matroska project.

### What is "muxing"? ###

Media container files all have the same basic purpose, and generally have the same set of features. All of them have their own advantages and problems. Honestly, there's little technical reason, these days, to pick one over the other.

In the past it was unlikely that the formats of the media inside the containers could play on other platforms - an .avi file from the Wintel world would normally use video formats that QuickTime could not understand. But today the H.264 format has rapidly started taking over the video side of things, and AC-3 is common for sound. So, when faced by a container format that your iDevice won't open, it's entirely possible that the media inside is just fine and that the only problem is the container.

Subler has the ability to change the container format, taking the media from one container and then placing it, unchanged, into another. The output format is a standard QuickTime file. If the media inside can be played by your iDevice, and this is increasingly common, Subler can convert the file for you in seconds.

### What's the difference between Subler and Handbrake? ###

Subler is a muxer, it takes the media inside a container, adds or removes tracks and makes similar minor changes, and saves out the media in another container. The actual content inside is unchanged. This process is very fast -- remuxing a 1-hour movie takes maybe two to three minutes.

Handbrake is a converter, or "transcoder". It takes the media inside the container, converts it into a new format, and saves it to another container. Converting a movie requires every frame of the video to be decoded and recoded into a new format, which can take hours.

Subler only works if the media formats inside the container are something your media device can play. If that's not the case, the new Subler movie simply won't work.

Handbrake can ''change'' that media into something your media device can play, practically every time.

So why would you use Subler at all? Because it's extremely fast. If the formats are compatible and the stars align, Subler is the way to go. It's so fast, you should just try it to see what happens, and then move on to Handbrake if that doesn't work.

### What containers does Subler read? ###

Subler can read mp4, mov and matroska.

### What else does it do? ###

Subler was not originally a full featured mp4 muxer, it was originally a way for opening up media files for editing subtitle tracks. This functionality is still there, improved, expanded, and is used in some form with just about every file.

Subler supports the SubRip style subtitle tracks, in .srt files. SubRip is a text file containing the subtitle text with some basic mark-up to add style and properly synch it with the video. Subler can add multiple caption files to support multiple languages, and has a few switches you can use to move the titles around or delay them to account for additional material added to the start of the file (ads). Here's an outline of the basic format:

http://en.wikipedia.org/wiki/SubRip#SubRip_text_file_format

Subler also allows you to edit the "metadata" in the file, things like the title, season and episode numbers, description and ratings. These show up in your players, like the AppleTV or iTunes, and help you organize your media. Most rippers and recorders don't bother to add this data, which means you have to do it by hand. Subler supports a long list of tags, and lets you import them from a text file. Better yet, Subler also has links to popular "metadata" databases to automate this process, finding the data on tagChimp database and adding it all in a few clicks.

Subler also lets you edit the "chapter" information that you find in most iTunes movies. These can be imported from a text file to make them easy to add in bulk. Subler will also create chapter images that QuickTime uses to quickly move through the files.

Finally, Subler can correct for basic errors made by most encoders, allowing the file to be more easily understood and played by QuickTime based players.
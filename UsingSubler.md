## Overview ##

Subler is based around the idea of "projects". In Subler, projects are represented by windows with a track listing at the top, and data from the tracks below. After creating a new project, you associate it with media tracks by Open…ing files from the File menu, or simply dragging and dropping them from the Finder into the project window. As each file is added, you will be asked which tracks you would like to read out of the file, adding them to the track list.

## Opening movies ##
Since Subler is an document-based application (every document represent a file on the computer hard disk), you can either open an existing document, or create a new one from scratch.

Here's the step for opening an existing document you want to work with.

1) Open Subler<br />
2) Select "Open" from the file menu.<br />
3) Select the desired file from the panel.<br />

A faster way is to drag the document icon on the Subler icon in the Dock or in the Finder.

Subler can even create new documents, when an empty file is needed.

Since every task below needs a project, here's the steps for opening a new project and setting it to the media file you want to work with.

1) Open Subler<br />
2) Select "New" from the file menu. A project window will appear.<br />
3) Drag the file from the Finder into the project window.<br />
4) A sheet will appear showing you the tracks in the file. Select the ones you'd like (the defaults are right 90% of the time). Press the Add button.<br />

## Typical tasks ##

### How do I quickly remux a file? ###

You have a movie in mkv format that you're pretty sure will work fine in QuickTime. How do you convert the mkv to m4v? Follow the steps above to create a project and open the file, and then…

5) click on the Video track (if there is one). If the H.264 format (bottom of the scree) is High 5.1, you'll likely want to change this to "Main @ 3.1". This makes a minor change to the file that makes QuickTime happy to open the file. The file may not work correctly, but without this bit set it won't even try to open it.<<br />

6) Select Save from the file menu, and give the new file a name.<br />

That's it! The remux only takes a few minutes.

That said, you'll likely want to at least add some metadata while you go, see below for details.

### Adding a subtitle track ###

Subler was originally designed to add subtitles and similar "rare" tracks to existing files. It supports the srt format introduced with SubRip, which has become a de-facto standard and widely available from sources like OpenSubtitle.

To add a subtitle track to a movie, follow the steps above to create a project and open the file, then...

5) Select Import->File... from the File menu or click the + button above the track listing in the project window.<br />
6) Use the Open dialog to find the subtitle track, in .SRT format, and Open it.<br />
7) A pane appears allowing you to edit basic information about the track. Most times no changes will be needed, simply click Add.<br />
8) The subtitle track appears at the end of the track list, with a default name.

i) You can double click the name to edit it.<br />
ii) The language of the subtitles can be changed in the track listing.<br />
iii) Selecting the subtitle track in the listing will display an editor allowing you to make changes to the visual appearance of the subtitles.<br />

### Adding multiple soundtracks ###
QuickTime has the ability, like a DVD, to include multiple soundtracks and let you select the one you want for playback. Subler is an easy way to add these to your existing movies.

To add a new soundtrack to a movie, follow the steps above to create a project and open the file, then...

5) Select Import->File... from the File menu or click the + button above the track listing in the project window.<br />
6) Use the Open dialog to find the sound file and Open it.<br />
7) Repeat (5) and (6) for each additional soundtrack you want to add.<br />

8) Click on the first track you added, so that the Sound Settings pane appears at the bottom of the document.<br />
9) In the upper pane, select the correct language for the track.<br />
10) In the bottom pane, Select the same "Alternate Group" for each one, typically 1.<br />
11) Repeat (8) through (10) for each of the tracks you imported.<br />

Hint: The first Sound Track in the track list in the upper pane will define the "default" one when opened in QuickTime Player.

Another hint: If you're also adding multiple subtitle tracks, assign them to a different Alternate Group, say 2.

### Using Subler to add and edit metadata ###

Another common task when working with movie files is adding or editing the "metadata" tags. These are the little switches that do things like turn on the HD flag in iTunes, or add season information to tv shows. These are well populated from sources like iTunes, but most DVD rippers and tv recording boxes fail to set any of these flags. There are a variety of tools on the Mac for working with these flags, like MetaX. But after using Subler for this job only one time, you'll probably never use them again.

Subler uses tagChimp to find and set these flags, but can also do this manually. Using tagChimp is so fast and easy, you may as well try it. Follow the steps above to create a project and open your file, then...

5) Select Import->tagChimp... from the File menu.<br />
6) In the window that appears, type in the title of the movie and press Return to start a search.<br />
7) Scroll through and click on the results to review them, and click Add when you find the one you want.<br />

i) meta data is not a track, and does not appear in the track listing. To edit it, click a blank area in the track listing to "select nothing".<br />
ii) tags can be added manually using the + pop-up menu below the tag listing<br />
iii) existing tags can be edited by double-clicking on them<br />
iv) the Artwork and Other Settings tabs in are also metadata, but these editors make it easier to work with these particular types of data.<br />

### Adding and editing chapters ###

Chapter data already inside media files will be properly imported into Subler, and can be easily edited them by selecting the track and then using the editor below. Subler can also import chapter listings from text files, which can be an easier format to work with. The chapter format used by Subler is simple, and can be found in the ChapterTextFormat document.

To import chapters from a file, follow the steps above to create a project and open your file, then

5)
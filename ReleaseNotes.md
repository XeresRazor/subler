# Subler 0.25 #

  * Fixed a cache invalidation issue that could prevent the download of updated movie and tv show metadata.
  * Fixed mono audio conversion.
  * Various bug fixed.

# Subler 0.24 #

  * New audio conversion option: AAC + AC-3.
  * Better results from TVDB and iTunes Store.

# Subler 0.23 #

  * Fixed a crash that could occur when searching for metadata with TheMovieDB.
  * Retrieve TV Network, Genre and Rating from TheTVDB.
  * Better posters selection with TheMovieDB.

# Subler 0.21-0.22 #

  * Fixed a crash that could occur when searching for metadata.
  * Fixed a crash that could occur when adding chapters from a txt file.
  * Various bug fixed.

# Subler 0.20 #

  * Updated TheMovieDB api.
  * Added iTunes Store metadata importer.
  * Improved ratings selection.
  * Srt -> tx3g conversion improvement: font color, subtitles position (bottom, top), forced subtitles. (refer to the SrtFileFormat wiki page for an example).
  * Various bug fixed.

# Subler 0.19 #

  * HDMV / PGS OCR.
  * Fixed an issue that caused the save operation to take a long time.
  * Added "Home Video" to the media kind list.

# Subler 0.18 #

  * Fixed an issue with thetvdb, results were not returned for some tv series.
  * Fixed some regression in the mov importer.
  * Added "iTunes U" to the media kind list.

# Subler 0.17 #

  * Forced subtitles tracks. A new option to set a track as "forced". iDevices will automatically display the right forced track for a given language (does not work with vobsub, only tx3g)
  * Ocr languages. Subler will now check ~/Library/Application Support/Subler/tessdata for Tesseract traineddata files.
  * Fixed an issue with the rating tag.

# Subler 0.16 #

  * VobSub OCR to text for subtitles
  * Per track conversion settings.
  * ALAC and DTS muxing support.
  * Queue window for batch operations.
  * 1080p tag (iTunes 10.6).

  * 0.16 requires Mac OS X 10.6 or higher.

# Subler 0.14 #

  * TMDb and TVDB metadata search engine (replacing tagChimp)
  * Metadata Sets. Metadata Sets can now be saved an quickly reloaded from the Metadata View.
  * Added support for Non-Drop Frame timecode in SCC files.
  * Added an "Export" menu item to export tx3g back to srt and chapters to txt
  * Added Podcast related tags
  * Various bug fixes
# Introduction #

Some information on SublerCLI

# Details #

**-source**

> the file you want to add to your mp4 file.

**-dest**

> the file where things will be saved

**-chapters**

> the .txt files with the chapters (see the chapter help)

**-chapterspreview**

> an options to create an additional video track with the preview of the chapters, used by iTunes and something else.

**-delay**

> the delay of the subtitle track in ms

**-height**

> the height of the subtitle track in pixel

**-language**

> the language of the subtitle track (i.e. English)

**-remove**

> remove all the existing subtitles tracks

**-optimize**

> optimize the file by moving the moov atom at the begin and interleaving the samples

**-downmix**

> downmix audio (mono, stereo, dolby, pl2)  from the source file

**-listtracks**

> list the tracks of the source file

**-listmetadata**

> list the metadata of the source file

**-help**

> print this help information

**-version**

> print version

**-metadata**

> set tags in the mp4
> example: -metadata "{TagName:TagValue}"

| Tag Name | Type |
|:---------|:-----|
| Name | string |
| Artist | string |
| Album Artist | string |
| Album | string |
| Grouping | string |
| Composer | string |
| Comments | string |
| Genre | string |
| Release Date | YYYY-MM-DD string |
| Track # | track#/totalTracks# string |
| Disk # | disk#/totalDisks# string |
| TV Show | string |
| TV Episode # | string |
| TV Network | string |
| TV Episode ID | number |
| TV Season | string |
| Description | string |
| Long Description | string |
| Rating | string, see the table below |
| Rating Annotation | string |
| Studio | string |
| Cast | string |
| Director | string |
| Codirector | string |
| Producers | string |
| Screenwriters | string |
| Lyrics | string |
| Copyright | string |
| Encoding Tool | string |
| Encoded By | string |
| contentID | string |
| HD Video | bool |
| Gapless | bool |
| Content Rating | string, see the table below |
| Media Kind | string, see the table below |
| Artwork | string, path to the file |

Media Kind
| Music |
|:------|
| Audiobook |
| Music Video |
| Movie |
| TV Show |
| Booklet |
| Ringtone |

Content Rating
| None |
|:-----|
| Clean |
| Explicit |

Rating
US Ratings
| Not Rated |
|:----------|
| G |
| PG |
| PG-13 |
| R |
| NC-17 |
| Unrated |

| TV-Y |
|:-----|
| TV-Y7 |
| TV-G |
| TV-PG |
| TV-14 |
| TV-MA |
| Unrated |

Uk Ratings

| Not Rated |
|:----------|
| U |
| Uc |
| PG |
| 12 |
| 12A |
| 15 |
| 18 |
| [R18](https://code.google.com/p/subler/source/detail?r=18) |
| Exempt |
| Unrated |

| Caution |
|:--------|

German Ratings
| FSK 0 |
|:------|
| FSK 6 |
| FSK 12 |
| FSK 16 |
| FSK 18 |
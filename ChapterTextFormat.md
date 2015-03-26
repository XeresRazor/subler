# Introduction #

Description of the chapters text format that Subler can import.

# Details #

Subler can import chapter in two different formats.

The first one is the one used by mp4v2's mp4chaps utility
It's a simple format, it consist in the timestamp followed by the chapter title.
_Example:_

```
00:00:00.000 Prologue
00:00:19.987 Opening
00:01:50.160 Episode Blablabla
00:21:54.530 Ending
00:23:24.453 Preview
```

The second one is the ogg text format used by some utilities.
_Example:_

```
CHAPTER01=00:00:00.000 
CHAPTER01NAME=Living Weapon 
CHAPTER02=00:05:00.750 
CHAPTER02NAME=A Better World 
CHAPTER03=00:09:31.937 
CHAPTER03NAME=Aboard Serenity (Main Titles) 
CHAPTER04=00:14:49.088 
CHAPTER04NAME=Going for a Ride
```

The file needs to be a .txt text file.
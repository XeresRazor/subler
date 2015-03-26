# srt example #

```
1
00:00:02,600 --> 00:00:06,600 X1:0 !!!
<font color="#ffff00">Yellow Forced Text</font>
More text and <i>Italic text</i> at top.

2
00:00:06,800 --> 00:00:10,000
<font color="#ffff00">More Yellow</font>
and two line of text at bottom.

3
00:00:11.000 --> 00:00:14.000 !!!
<b>Bold</b> and forced at bottom.

4
00:00:15.500 --> 00:00:18.500 X1:0
<font color="#3333CC">Color, <i>italic</i>!</font>
- I am <font color="#FF0000"><u>red</u></font>!
```

# feature supported #

  * `<b>` bold
  * `<i>` italic
  * `<u>` underlined
  * `<font color="#ffccee">`
  * X1:0 means the subtitle is aligned to the top of the video
  * !!! means a forced subtitle
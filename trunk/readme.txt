[[ 
   23.4.2012 Note: Uploaded project to Google Code, released under
   MIT license. Contact jani.halme@gmail.com for more info. Below is
   the original readme.txt from 1999.
]]

S3MLIB v1.0, a small 100% Assembler S3M-module player for GUS (and SB?)
-----------------------------------------------------------------------

AUTHOR
  Firehawk/Dawn aka. Jani Halme <jha@dlc.fi>


DISCLAIMER (or something like that)
  You can use this for anything you want, except ripping it and saying
  that it's your own code. I like getting greetings a lot, too. :)
  If this player won't do what it's supposed to do (play a song), it's
  not my fault. Nor will I be liable for any damages this program could
  do (Yes, if you kill your hamster in frustration of using this player,
  I'm not to blame.)


USAGE
  Very easy. :) See 'asmtest.asm' to see an example on how to use it
  in assembler programs linked with PMODE/W. If you want to use Watcom C,
  then check out 'wctest.c' for an example on how to do that. Use the
  batch files 'asmmake.bat' and 'wcmake.bat' to build the examples.
  You can also choose which drivers are compiled to the main library
  by editing 's3mconf.asm'. Not much to edit there, really, as that
  SB support is not finished. Also, sorry for not including an example
  on how to sync with music. It's not very difficult, though. :)


SNIFF, SNIFF
  I started developing this player in summer 1995 for our game
  project that was never really even started. The code was working
  in winter 1996 and it was used for our 64KB intro 'Pallo' that was
  hastily made in a few days before ASM96. After that, I tried to revise
  the code to support SB and fix some small glitches but I somehow lost
  interest when Gravis announced their withdrawal from the sound card
  market. Now, on spring 1999, I'm releasing this source code in case
  someone still needs a solid GUS-only S3M player. If you use this code
  for something, please e-mail me; knowing that someone uses my code
  would make me really happy. :)


KNOWN PROBLEMS
 * You may find some comments in finnish. They're probably not very
   useful anyway, so just forget them :)

 * The timer reprogramming is ugly and messes up the system clock...

 * "Exception 00"s in some _rare_ occasions. Control-E by Dune/Orange does
   this in the middle of the song on pattern 03. Suspiciously, that
   pattern is completely empty. However, I chopped the song into four
   patterns, one of which is 03. This didn't give the error - it comes
   only when playing the full song. Weird...

 * GUS PnP cards don't seem to work with the player. Don't know why. I've
   tested this player on each of my Ultrasounds (Classic, MAX, Extreme)
   without any problems. If anyone knows something that might help, mail
   me. I modified the GF1 reset routine a bit, so it might work better
   now...

 * I don't really have time to mess with this anymore, so if someone
   would like to finish the SB support or do some bugfixes, go right
   ahead. Release your own versions if you please, even. Just tell me
   about it first. :)

 * Ultrasound is discontinued... Sniff.. :(


TODO
 * Fix that timer thing. It's no fun at all.

 * SB-support (started it already, but didn't have time to actually
   implement it). Anyone want to finish it? :)

 * Autodetect soundcards


THANKS
  Brainpower        -   Did some testing with his GUS PnP and also gave some
                        clues on how to code for a SB.
  Salomon           -   For making some cool S3Ms and for testing with his
                        older revision GUS MAX.
  FreddyV/Useless   -   For releasing USMP, which I eyeballed a bit while
                        fixing that GF1 reset thing. Hope it works better...
  Advanced Gravis   -   For the excellent sound card that still sounds great
                        after so many years.


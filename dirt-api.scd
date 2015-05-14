/*I looked into adding freeverb support many moons ago but couldn't find
a nicely packaged library, perhaps it's better now?

It would be good to have a supercollider sampler. Dirt works like the
below but probably best to make something similar that takes
advantages of the affordances of supercollider..

The current dirt OSC API looks like this:
 iifsffffffsffffififfffifffff

:)

The first two integers are the timestamp, in SC we'd use bundle
timestamps for that, so lets ignore them.


*/


0 f: cps - the current cycles per second, used for calculating speed,
begin/end etc when 'unit' is set to 'c'

1 s: sample_name - a sample specified by foldername and index. I.e.
bass:4 would select the fifth wav file in the 'bass' folder. By
default it would look in ./samples/bass/

2 f: offset - not currently used, it seems, but was once start time
offset in seconds (or these days, units) from the timestamp as a way
to add some timing expression..

3 f: start - where to start playing the sample, i.e. 0.25 would be 1/4
in to the sample file.
4 f: end - where to stop playing the sample. Together these can be
used to select a grain for granular synthesis

5 f: speed - playback speed. 1 = normal, -1 = backwards, 0.5 = half speed

6 f: pan - 0 to 1, in stereo 0 is left, 1 is right and 0.5 is centre.
In multichannel a ring configuration is assumed where 0 and 1 are the
same speaker and 0.5 is opposite. With 4 speakers, 0.125 would be
halfway between first and second speakers.

7 f velocity - not implemented, I think this was going to allow
samples to pan across while playing

8 s vowel - 'a', 'e', 'o', 'i' or 'u' to select a formant filter

9 f cutoff - 0 to 1
10 f crush - 0 to 1

11 f accelerate - increases speed of playback by accelerate/samplerate
every sample

12 shape - dirty waveshaping from 0 to 1

13 kriole_chunk - something left behind a non-tidal project..

14 gain - multiplies by powf(gain/2, 4);

15 cutgroup - with positive integers, stop samples playing that are in
the same cutgroup. With negative, only stop the same sample from
playing in the same cutgroup

16 f delay - there's a global delay line, this controls amount going
in (simple multiplication I think)
17 f delaytime - length of delay line
18 f delayfeedback - amount feeding back

(There's a bit of pseudorandomness added to the index when reading
samples out of the delay line for some reason. This kind of behaviour
doesn't need to be replicated!)

19 crush f - bit crusher

19 coarse - not sure, makes it sound coarse!

20 hcutoff - high pass filter
21 hresonance
22 bandqf - band pass filter
22 bandq

23 s unit - "r" makes unit of speed and start/end time in terms of
ratio (the default described above), "c" in terms of cycles per second
(i.e. 1 to play back at a speed that makes the sample exactly fill one
cycle), and "s" in terms of seconds


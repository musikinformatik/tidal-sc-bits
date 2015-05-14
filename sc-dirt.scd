(
s.options.numBuffers = 1024 * 16;
~numCutGroups = 16;
~numChannels = 2;

s.tree = {
	~cutGroups = 16.collect { |i| Group(s) };
	~bus = Bus.audio(s, ~numChannels);
};
s.reboot;
)


(
var path = "samples".resolveRelative; // put your sample path here
var folderPaths = pathMatch(path +/+ "**");
~buffers = ();

folderPaths.do { |folderPath|
	PathName(folderPath).filesDo { |filepath|
		var buf, name;
		if(filepath.extension == "wav") {
			buf = Buffer.read(s, filepath.fullPath);
			name = filepath.folderName;
			~buffers[name.asSymbol] = ~buffers[name.asSymbol].add(buf)
		}
	};
};

)

// test buffers
~buffers.choose.play;
~buffers.keys;
~buffers['cp'][1].play



// init sc-dirt
(


SynthDef(\dirt, { |out, speed = 1, bufnum, start, end, pan, accelerate, amp = 0.1, offset, doneAction=2|
	var env, sound, numFrames, startFrame, dur;
	numFrames = BufDur.kr(bufnum);
	dur = numFrames * (end - start) / speed; // todo: account for accelerate
	startFrame = start * BufFrames.kr(bufnum) + (offset * BufSampleRate.kr(bufnum));
	env = EnvGen.ar(Env.linen(0, dur, 0.001, amp, -4), doneAction:doneAction);
	sound = PlayBuf.ar(1, bufnum, speed + Sweep.kr(1, accelerate) * BufRateScale.kr(bufnum), 0, startFrame);
	OffsetOut.ar(out,
		PanAz.ar(~numChannels, sound, pan, env)
	);
}).add;


// this is just a placeholder, not sure how it is best translated
SynthDef(\dirt_vowel, { |out, cutoff, resonance|
	var signal = In.ar(out, ~numChannels);
	var freq = \freq.kr(440);
	var formfreqs = \formfreqs.kr([500, 772, 1002]);
	DetectSilence.ar(signal, doneAction:2);
	signal = Formlet.ar(signal, freq, 1/formfreqs); // not sure how to use cutoff and resonance.
	ReplaceOut.ar(out, signal)
}).add;

SynthDef(\dirt_crush, { |out, cutoff, resonance|
	var signal = In.ar(out, ~numChannels);
	var bitsize = 4;
	DetectSilence.ar(signal, doneAction:2);
	signal = signal.round(0.5 ** bitsize);
	ReplaceOut.ar(out, signal)
}).add;

SynthDef(\dirt_monitor, { |out, in|
	var signal = In.ar(in, ~numChannels);
	DetectSilence.ar(signal, doneAction:2);
	Out.ar(out, signal);
	ReplaceOut.ar(in, Silent.ar(~numChannels)) // clears bus signal for subsequent synths
}).add;


~dirt = {
	|cps = 1, name, offset = 0, start = 0, end = 1, speed = 1, pan = 0,
	velocity, vowel, cutoff, resonance,
	accelerate = 0, shape, krio, gain = 2, cutgroup = 0, delay, delaytime, delayfeedback,
	crush, coarse, hcutoff, hresonance, bandqf, bandq, unit|

	var amp, allbufs, bufnum, group;
	var key, index, instrument = \dirt;
	var synths;
	#key, index = name.asString.split($:);
	allbufs = ~buffers[key.asSymbol];
	if(allbufs.notNil) {
		index = (index ? 0).asInteger;
		bufnum = allbufs.wrapAt(index);
		amp = pow(gain / 2, 4);
		speed = speed * cps;
		group = ~cutGroups.clipAt(cutgroup);

		s.bind {

			if(cutgroup != 0) {
				if(cutgroup > 0) {
					~cutGroups.clipAt(cutgroup).set(\gate, 0)
				} {
					// negative not yet implemented, would need to keep track of each synth.
				}
			};

			synths = synths.add(
				Synth(instrument,
					[
						speed: speed,
						bufnum: bufnum,
						start: start,
						end: end,
						pan: pan,
						accelerate: accelerate,
						amp: amp,
						offset: offset,
						out: ~bus],
					group,
					\addToTail
				);
			);
			if(vowel.notNil) {
				synths = synths.add(
					Synth(\dirt_vowel,
						[
							out: ~bus,
							cutoff: cutoff,
							resonance: resonance],
						group,
						\addToTail
					);
				);
			};
			if(crush.notNil) {
				synths = synths.add(
					Synth(\dirt_crush,
						[
							out: ~bus
						],
						group,
						\addToTail
					);
				);
			};

			synths = synths.add(
				Synth(\dirt_monitor,
					[in: ~bus, out: 0],
					group,
					\addToTail
				);
			);

		};

	} {
		"no sample found for this name: %\n".postf(name);
	}
};


OSCdef(\dirt, { |msg|
	~dirt.(msg[1..]);
}, '/play');
)


// some tests

(
Tdef(\x, {
	loop {
		~dirt.(1, 'cp:10', 0, 0.1.rand, 1.0.rand, 1 + 1.3.rand2, 2.rand2, accelerate:1);
		(0.2 * [1, 2, 1/3]).choose.wait;
	}
}).play;
)

(
Tdef(\x, {
	loop {
		~dirt.(1, 'cp:10', 0, 0.1.rand, 1.0.rand, 1 + 1.3.rand2, 2.rand2, accelerate:1, crush:1);
		(0.2 * [1, 2, 1/3]).choose.wait;
	}
}).play;
)



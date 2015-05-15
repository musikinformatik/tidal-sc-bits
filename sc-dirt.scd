(

s.options.numBuffers = 1024 * 16;
~numChannels = 2; // adjust this to your channel setup

// we need this here, because it is a global effect (repeated below under effects)
SynthDef(\dirt_delay, { |out, delayBus, delaytime, delayfeedback|
	var signal = In.ar(delayBus, ~numChannels);
	signal = SwitchDelay.ar(signal, 1, 1, delaytime, delayfeedback); // try this from sc3-plugins
	Out.ar(out, signal);
}).add;



s.tree = {
	/*
	we use one private bus, so we can use the public one for mixing everything together (see the "dirt_monitor" synth def)
	*/
	~bus = Bus.audio(s, ~numChannels);
	~delayBus =  Bus.audio(s, ~numChannels);
	~delaySynthID = s.nextNodeID;
	s.sendMsg(\s_new, \dirt_delay, ~delaySynthID, 3, 1, \delayBus, ~delayBus.index, \out, 0); // add delay after group 1
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
		if(filepath.extension == "wav" or: { filepath.extension == "WAV" }) {
			buf = Buffer.read(s, filepath.fullPath);
			name = filepath.folderName;
			~buffers[name.asSymbol] = ~buffers[name.asSymbol].add(buf)
		}
	};
};

)



// test buffers
~buffers.keys;
~buffers['CY'][1].play

// init sc-dirt
(
/*
in order to avoid bookkeeping on the language side, we implement cutgroups as follows:
The language initialises the synth with its sample id (some number that correlates with the sample name) and the cutgroup. Before we start the new synth, we send a /set message to all synths, and those that match the specifics will be released.
*/

~gateCutGroup = {
	// this is necessary because the message "==" tests for objects, not for signals
	var same = { |a, b| BinaryOpUGen('==', a, b) };
	var sameCutGroup = same.(\cutGroup.kr(0), abs(\gateCutGroup.kr(0)));
	var sameSample = same.(\sample.kr(0), \gateSample.kr(0));
	var which = \gateCutGroup.kr(0).sign; // -1, 0, 1
	var free = Select.kr(which + 1, // 0, 1, 2
		[
			sameSample,
			0.0, // default cut group 0 doesn't ever cut
			1.0
		]
	) * sameCutGroup; // same cut group is mandatory

	EnvGen.kr(Env.asr(0, 1, 0.01), 1 - free, doneAction:2);
};

SynthDef(\dirt, { |out, bufnum, start=0, end=1, pan, amp = 0.1,
	speed = 1, accelerate, offset, cps, unit, doneAction=2|

	var env, sound, dur, length, rate;
	var sampleFrames, sampleDur, startFrame, sampleSampleRate;

	length = end - start;
	sampleDur = BufDur.kr(bufnum);
	sampleFrames = BufFrames.kr(bufnum);
	sampleSampleRate = BufSampleRate.kr(bufnum);

	// need to check these carefully
	// todo: account for accelerate
	rate = Select.kr(unit, [
		speed,
		cps * speed / sampleDur,
		speed / cps
	]);

	// if we accelerate, do we get shorter?
	dur = Select.kr(unit, [
		sampleDur * length,
		length / cps,
		length
	]) / rate;

	startFrame = Select.kr(unit, [
		sampleFrames * start,
		sampleSampleRate / cps * start,
		sampleSampleRate * start
	]);

	rate = rate + Sweep.kr(1, accelerate); // maybe this needs to be moved up?

	env = EnvGen.ar(Env.linen(0, dur, 0.001, amp, -4), doneAction:doneAction);
	sound = PlayBuf.ar(1,
		bufnum,
		// bufratescale adjusts the rate if sample doesn't have the same rate as soundcard
		rate * BufRateScale.kr(bufnum),
		0,
		startFrame
	);
	env = env * ~gateCutGroup.value; // this synth can be freed by cutgroup mechanism
	OffsetOut.ar(out,
		PanAz.ar(~numChannels, sound, pan, env)
	);
}).add;

/*
The following effect synths are freed when input is silent for longer than 0.1 sec. This makes it unnecessary to keep track of any synths. But this may cause problems with samples that contain silence. One way to solve this involves bookkeeping of synths on the language side (haskell or sclang). For now, we use the simplest possible way.
*/

// these are just placeholders, not sure how they are best translated

// we need to select formant bands for the vowels in sclang (at least this would be the most efficient)
SynthDef(\dirt_vowel, { |out, cutoff = 440, resonance = 0.5, vowel|
	var signal = In.ar(out, ~numChannels);
	var freq = cutoff.linexp(0, 1, 200, 500); // adjust this and the vowel freqencies
	var vowelFreqs = Select.kr(vowel, [
		[800, 1150, 2800, 3500, 4950],
		[400, 1600, 2700, 3300, 4950],
		[350, 1700, 2700, 3700, 4950],
		[450, 800, 2830, 3500, 4950],
		[325, 700, 2530, 3500, 4950]
	]);
	signal = Formlet.ar(signal, (cutoff / 440) * vowelFreqs, 1/resonance); // not sure how to use this here.
	signal = signal.sum; // sum all filters
	DetectSilence.ar(LeakDC.ar(signal), doneAction:2);
	ReplaceOut.ar(out, signal)
}).add;

// would be nice to have some more parameters in some cases

SynthDef(\dirt_crush, { |out, crush = 4|
	var signal = In.ar(out, ~numChannels);
	signal = signal.round(0.5 ** crush);
	DetectSilence.ar(LeakDC.ar(signal), doneAction:2);
	ReplaceOut.ar(out, signal)
}).add;

SynthDef(\dirt_hpf, { |out, hcutoff = 440, hresonance = 0|
	var signal = In.ar(out, ~numChannels);
	signal = RHPF.ar(signal, hcutoff, hresonance.linexp(0, 1, 1, 0.001));
	DetectSilence.ar(LeakDC.ar(signal), doneAction:2);
	ReplaceOut.ar(out, signal)
}).add;

SynthDef(\dirt_bpf, { |out, bandqf = 440, bandq = 10|
	var signal = In.ar(out, ~numChannels);
	signal = BPF.ar(signal, bandqf, 1/bandq) * max(bandq, 1.0);
	DetectSilence.ar(LeakDC.ar(signal), doneAction:2);
	ReplaceOut.ar(out, signal)
}).add;

// the monitor does the mixing and zeroing of the busses

SynthDef(\dirt_monitor, { |out, in, delayBus, delay = 0|
	var signal = In.ar(in, ~numChannels);
	DetectSilence.ar(signal, doneAction:2);
	Out.ar(out, signal);
	Out.ar(delayBus, signal * delay);
	ReplaceOut.ar(in, Silent.ar(~numChannels)) // clears bus signal for subsequent synths
}).add;


SynthDef(\dirt_delay, { |out, delayBus, delaytime, delayfeedback|
	var signal = In.ar(delayBus, ~numChannels);
	signal = SwitchDelay.ar(signal, 1, 1, delaytime, delayfeedback); // try this from sc3-plugins
	Out.ar(out, signal);
}).add;

/*
Functions for sending synths to the server.
*/

~sendSynth = { |instrument, args|
	s.sendMsg(\s_new, instrument,
		-1, // no id
		1, // add action: addToTail
		1, // send to group 1
		*args // append all other args
	)
};


~dirt = {
	|cps = 1, name, offset = 0, start = 0, end = 1, speed = 1, pan = 0, velocity,
	vowel, cutoff = 300, resonance = 0.5,
	accelerate = 0, shape, krio, gain = 2, cutgroup = 0,
	delay = 0, delaytime = 0, delayfeedback = 0,
	crush = 0,
	coarse = 0,
	hcutoff = 0, hresonance = 0,
	bandqf = 0, bandq = 0,
	unit = \r|

	var amp, allbufs, buffer, group;
	var key, index, instrument = \dirt;
	var sample;

	#key, index = name.asString.split($:);
	key = key.asSymbol;
	allbufs = ~buffers[key];

	if(allbufs.notNil) {
		index = (index ? 0).asInteger;
		buffer = allbufs.wrapAt(index);
		amp = pow(gain / 2, 4);
		speed = speed * cps;
		sample = name.identityHash;
		unit = #[\r, \c, \s].indexOf(unit) ? 0;

		s.bind { // use this to build a bundle

			if(cutgroup != 0) {
				// set group 1, in which all synths are living
				s.sendMsg(\n_set, 1, \gateCutGroup, cutgroup, \gateSample, sample);
			};

			// set global delay synth parameters
			if(delaytime != 0 or: { delayfeedback != 0 }) {
				s.sendMsg(\n_set, ~delaySynthID, \delaytime, delaytime, \delayfeedback, delayfeedback);
			};

			~sendSynth.(instrument, [
				speed: speed,
				bufnum: buffer.bufnum,
				start: start,
				end: end,
				pan: pan,
				accelerate: accelerate,
				amp: amp,
				offset: offset,
				cutGroup: cutgroup.abs, // ignore negatives here!
				sample: sample,
				cps: cps,
				out: ~bus.index]
			);

			if(vowel.notNil) {
				vowel = [\a, \e, \i, \o, \u].indexOf(vowel); // convert to number
				~sendSynth.(\dirt_vowel,
					[
						out: ~bus.index,
						vowel: vowel,
						cutoff: cutoff,
						resonance: resonance
					]
				);

			};

			if(crush != 0) {
				~sendSynth.(\dirt_crush,
					[
						crush: crush,
						out: ~bus.index
					]
				);
			};
			if(hcutoff != 0) {
				~sendSynth.(\dirt_hpf,
					[
						hcutoff: hcutoff,
						hresonance: hresonance,
						out: ~bus.index
					]
				);
			};
			if(bandqf != 0) {
				~sendSynth.(\dirt_bpf,
					[
						bandqf: bandqf,
						bandq: bandq,
						out: ~bus.index
					]
				);
			};

			~sendSynth.(\dirt_monitor,
				[
					in: ~bus.index,  // read from private
					out: 0,     // write to public,
					delayBus: ~delayBus.index,
					delay: delay
				]
			);


		};

	} {
		if(SynthDescLib.at(key).notNil) {
			// allow a synthesis replacement of a sample
			~sendSynth.(key, [
				speed: speed,
				start: start,
				end: end,
				pan: pan,
				accelerate: accelerate,
				amp: amp,
				cps: cps,
				offset: offset,
				cutGroup: cutgroup.abs, // ignore negatives here!
				out: ~bus.index]
			)
		} {
			"no sample found for this name: %\n".postf(name);
		}
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
		~dirt.(1, 'CY:10', 0, 0.1.rand, 1.0.rand, 1 + 1.3.rand2, 2.rand2, accelerate:0);
		(0.2 * [1, 2, 1/3]).choose.wait;
	}
}).play;
)

(
Tdef(\x, {
	loop {
		~dirt.(1, 'CY:10', 0, 0.1.rand, 1.0.rand, 1 + 1.3.rand2, 2.rand2, accelerate:0.2.rand2, crush:8);
		(0.2 * [1, 2, 1/3]).choose.wait;
	}
}).play;
)

// cutgroup tests
~dirt.(1, 'CY:10', speed: 0.02, cutgroup: -8); // really slow, to keep it on
~dirt.(1, 'CY:10', speed: 0.02, cutgroup: -8); // cut the old one
~dirt.(1, 'CY:10', speed: 0.02, cutgroup: -8); // ... again


//  With negative, only stop the same sample from playing in the same cutgroup
~dirt.(1, 'CY:9', speed: 0.02, cutgroup: -8); // a different sample, is added
~dirt.(1, 'CY:9', speed: 0.02, cutgroup: -8); // the same sample, frees

//  with positive integers, stop samples playing that are in the same cutgroup.
~dirt.(1, 'CY:10', speed: 0.02, cutgroup: 8); // should free all others


// test effects:
~dirt.(1, 'CY:10', speed: 0.1, crush: 4);
~dirt.(1, 'CY:10', speed: 1, hcutoff: 1000, hresonance: 20);
~dirt.(1, 'CY:10', speed: 1, hcutoff: 3000, hresonance: 10);
~dirt.(1, 'CY:10', speed: 1, bandqf: 3000, bandq: 100);
~dirt.(1, 'CY:10', speed: 1, bandqf: 3000, bandq: 100, crush: 4);
~dirt.(1, 'CY:10', speed: 1, vowel: \a);
~dirt.(1, 'CY:10', speed: 1, vowel: \i, resonance: 1.4);


// test delay:

~dirt.(1, 'CY:10', speed: 1, delaytime: 0.8, delay: 1);
~dirt.(1, 'CY:10', speed: 1, delaytime: 0.8, delay: 0);
~dirt.(1, 'CY:10', speed: 1, delaytime: 0.2, delay: 1);


// test replacement:
(
SynthDef(\imp, { |out, speed = 1, bufnum, start=0, end=1, pan, accelerate, amp = 0.1, offset, doneAction=2|
	var env, sound, dur;
	dur = (end - start) / speed;
	env = EnvGen.ar(Env.linen(0, dur, 0.001, amp, -4), doneAction:doneAction);
	sound = Blip.ar(32 * (start + 1) * (speed + Sweep.kr(1, accelerate)), 100);
	env = env * ~gateCutGroup.value; // this synth can be freed by cutgroup mechanism
	OffsetOut.ar(out,
		PanAz.ar(~numChannels, sound, pan, env)
	);
}).add;
)

~dirt.(1, 'imp', speed: 1, start: 0, end: 1);
~dirt.(1, 'imp', speed: 1, start: 0.5, end: 1);
~dirt.(1, 'imp', speed: 1, start: 0, end: 1, accelerate: 3);




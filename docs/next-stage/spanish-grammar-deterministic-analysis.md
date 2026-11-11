# Deterministic grammar analysis (next stage, S11)

> **Status:** notes for the next stage, part of S11 in the Build Plan. The project doc `claude/Spanish Games Next Stage Notes.md` (section 9) points here. This is not a build item; the scheduled tasks do not act on it.

## Scope (Andrew, 11 Nov 2026)

- For grammar points with clear rules, starting with the subjunctive.
- Natural language is out of scope: it is always ambiguous, and stays with the AI check.
- For each verb, deterministic code should decide:

| Call | How code makes it |
|---|---|
| This verb is subjunctive, or it isn't | Word analysis lists the possible readings of the form; the sentence structure picks one (*sienta* after *quiero que* is *sentir*, subjunctive). |
| The subjunctive is required here | Trigger rules check what the clause hangs off: *querer que*, *para que*, *ojalá* and so on. |
| It is used as it should be, or it isn't | Compare the two: required and used is right; required and missing, or used where the indicative is required, is wrong. |
| It's ambiguous | The trigger depends on meaning (*aunque*, *cuando*, *no creer que*), or the form can't be resolved. Set aside, not guessed. |

Same sentence in, same answer out, every time.

## Where it can go wrong

The input, not the rules:

- Missing accents (*este* / *esté*, *hable* / *hablé*) and voice mis-transcriptions can change which form the code thinks it has.
- The parser can misread a learner's sentence, especially a long or broken one, and attach the *que* clause to the wrong verb.

Both give wrong calls, not inconsistent ones. The spike should report how often, alongside the right / wrong / ambiguous counts.

## Trial data

- This answers the open question in the note below: the conversations do exist as exportable text. Andrew's extract `spanish_companion_transcripts_2026-10-01_to_2026-11-09.md` has about 264 clearly Spanish turns of his, roughly 8,600 words, across 29 thread-days.
- It is on Andrew's Mac and must stay out of git: this repo is public.
- Before analysis: drop voice turns mis-transcribed as Portuguese or Italian. The "(voice)" marker looks unreliable, so it cannot be used to tell spoken from written.

---

## Original note (from another conversation, 11 Nov 2026, unchanged)


*A note from a conversation on 11 November 2026, written to be carried into the Spanish companion app project. The tool names below came from general knowledge during the conversation. They were not checked on the web, so check versions and licences before relying on them.*

### The idea in one paragraph

The Spanish companion app should give a learner an overview like this: "you used the subjunctive 40 times; 31 were right, 6 were wrong, 3 depend on what you meant." Asking a general AI model to find these in a transcript gives answers that drift from run to run, because it is doing everything at once. The steadier approach is the way language researchers have done grammar analysis for about thirty years. Fixed, rule-following code (deterministic code: same input, same answer, every time) does everything that can be decided mechanically. It sorts each case into **right**, **wrong** or **ambiguous**, and only the ambiguous cases go to an AI model, as one small, specific question each. You end up with less work for the model, more consistent results, and a log you can inspect.

### The four layers

**1. Word analysis: list every possible reading. Fixed rules, no AI.**
Spanish verb forms are a finite, well-documented set. A *morphological analyser* (a program that breaks a word into its dictionary form plus tense, mood and person) takes a word and returns every reading it could have, without choosing one. For example, *sienta* could be *sentar* (to sit), present indicative, 3rd person; or *sentir* (to feel), present subjunctive, 1st or 3rd person. Under the hood this is a lookup table.

**2. Sentence structure: settles most of the ambiguity. A small statistical model, not a chatbot.**
A *parser* works out how the sentence fits together: which verb is the main one, and which clause hangs off which. Once that's known, most ambiguous words resolve themselves:
- *Quiero que te sienta mejor*: the *que* clause hangs off *querer*, which calls for a subjunctive, so this is *sentir*, subjunctive.
- *Ella se sienta aquí*: there's no clause that calls for a subjunctive, so this is *sentar*, indicative.

Parsers are small (tens of megabytes) and very accurate on clean text.

**3. Trigger rules: your list of when the subjunctive is required. Fixed rules.**
With the structure and each verb's mood known, you write the finite rules you already know as a teacher:
- **Subjunctive required:** after *querer que*, *es importante que*, *para que*, *ojalá*, and so on.
- **Indicative required:** after *creer que* in a positive sentence.
- **Depends on meaning:** after *aunque*, *cuando*, *si*, *creer que* in a negative sentence, and similar.

Each rule sorts a case into right, wrong or ambiguous. These rules are what produce the learner's overview, and because they're plain code you can read and test every one.

**4. AI only for the "depends on meaning" pile.**
Take *aunque llueve* versus *aunque llueva*: did the learner mean a fact ("even though it's raining") or a possibility ("even if it rains")? Only the context can tell you. The question you send to the model is narrow: "here is the sentence, the parse, and the two readings; which did the speaker mean?" That's a much lighter job than "find all the grammar mistakes in this conversation", and each answer can be logged and reviewed.

### Tools that came up (check before relying on them)

| Tool | What it does | Notes to check |
|---|---|---|
| **FreeLing** | A language-analysis toolkit from Barcelona, with Spanish as its home language. Does word analysis and sentence structure. | Licence (believed to be one that requires sharing your own code if you distribute it). Size and maintenance status. |
| **spaCy** (Spanish models) | A widely used Python toolkit. Tags every verb with mood, tense, person and number, and parses sentences. | The toolkit has a permissive licence, but the Spanish models may carry a different, stricter one. Check before shipping. |
| **Stanza** | Stanford's equivalent of spaCy, with good Spanish models. | Licence and model size. |
| **COWS-L2H** | A collection of Spanish written by learners, with their errors marked up (University of California, Davis). The raw material for training a model on learner Spanish mistakes specifically. | What it may be used for; how much of it covers the subjunctive. |

A small model trained specifically on Spanish learner errors is an active research area, but nothing ready-made for a phone turned up that I'd trust without testing. Layers 1–3 may give you most of the consistency you were after without one.

### Honest caveats

- **Learner text is messy.** Missing accents (*este* / *esté*) and spelling slips confuse word analysers and parsers, so you'd want a cleanup step or an accent-tolerant lookup before layer 1. For a learner app this is the most likely place to go wrong. Spike it early.
- **Speech transcripts add noise.** If the conversations come from speech-to-text, a transcription error can look like a grammar error. Keep the audio or transcription confidence alongside the text if you can.
- **The rules are a teaching asset, not just code.** Writing the trigger list is where your expertise as a teacher goes. An AI can draft the list, but you should own it.

### Phone or Mac?

- **On the phone, eventually:** the verb tables are just data and could be written in Dart (Flutter's language). A parser the size of spaCy's should be able to run on a phone through the same route as the on-device speech models (ONNX, a common model file format). That's plausible, but not verified.
- **On the Mac first:** for analysing your *own* conversations, the quicker spike is a batch job on your MacBook. Export the transcripts, run them through spaCy or Stanza in Python, apply a handful of trigger rules, and look at the right/wrong/ambiguous counts. That answers "does this work on real learner Spanish?" before any app work.

### Open question for that project

Are the companion app's conversations already stored as text you can export, or do they only exist inside the app's chat? That decides whether the first spike can start tomorrow.

### The wider lesson

No agent had suggested this approach, despite a lot of thinking about how the app should work. So when designing any AI feature, ask early: **"Is there a tried-and-tested way to do part of this without AI, and what's left over that really needs the model?"** Language, maths, dates, spelling, scheduling and scoring often have a well-established rule-based core.

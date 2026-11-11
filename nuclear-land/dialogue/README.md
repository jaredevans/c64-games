# Dialogue (milestone 4)

The whole cast's conversations, one file per person, built into the game by
`tools/make_dialogue.py` (it reads `dialogue/*.txt`). Written as a draft for review, then moved
in as it was. The milestone 5 mechanics below aren't built yet.

## How to read a script

Each file is one person, in the same format as the built `dialogue/hesper.txt`:

- `start` is the trust tier the person starts at: Wary, Guarded, Open or Friendly.
- `favours` names the squad member who earns extra trust.
- `greet` is the opening line.
- `deflect` is the default brush-off when trust is too low.
- `unknown` is the reply to a word the person knows nothing about.
- Each `topic` lists a keyword and any aliases. Under it, `tier` is the trust needed, `say` is the
  real answer, and an optional `else` is that topic's own brush-off.

Words in CAPITALS in a `say` line join the squad's Known list when the answer is given. Nothing
else is capitalised, so no word gets added by accident. All text wraps to 24 columns in the game.

`hesper.txt` is the M3 file plus new topics at the end, marked NEW. The M3 lines are unchanged.
The new topics answer words the squad learns from other people.

## The clue chain

| Who | Where | Starts | Favours | What they give up |
|---|---|---|---|---|
| Hesper | pump house | Wary | Maren | TANKS at Open: the tanks drain too fast, which points to CORWIN and the CARAVAN |
| Brandt | reactor gate | Wary | Rook | VOSS at Open: Voss went into the compound that night and the Keepers sealed it. Also names PIP, who climbs the back fence |
| Tamsin | greenhouse | Guarded | Dials | REACTOR at Guarded: the runoff kills the plants. VOSS at Open: LIGHTS in the reactor at night, so Voss is alive |
| Jory | west-edge shack | Wary, locked | Maren | Only after Maren's treatment: the mayor's men filling tanker CARTS at the COOLANT VALVE |
| Odalys | caravan camp | Guarded | Vesna | WATER at Open: it's bought by the barrel from the back of the reactor, so BARRELS. Asked about the barrels, Odalys adds that they're stamped with the town hall's mark |
| Pip | Market Row | Open | Rook | JOB gives the GHOST. GHOST at Friendly gives the HATCH behind the dome. Also names JORY and ODALYS |
| Corwin | town hall | Friendly (fake) | none | Answers everything warmly and lies. Blames OUTSIDERS. Never confesses |
| Voss | basement | Open | none | The tapped coolant line, and names Corwin. PROOF says what the town would need |

The four proofs each come from exactly one place, and the check script enforces this:

- **CARTS:** Jory.
- **BARRELS:** Odalys.
- **TRACKS:** Rook's skill at the back fence.
- **TAPPED:** Dials's skill at the valve.

Voss and everyone else mention these things in lower case, so talking can't count as finding
proof.

Corwin's lies can be caught against the others:

- Grain barrels, against Odalys's town-hall drums.
- "My men take a short cut", against the tracks.
- "Brandt guards it day and night", against Brandt's "it's a long fence".

## Milestone 5 mechanics this text assumes

The script format doesn't express these. They're written here so the review covers the whole story.

1. **Skill lines on the squad strip.** These are the message line in the HUD, 40 columns max.

   | Skill spot | Message | Effect |
   |---|---|---|
   | Rook, back of the compound fence | `rook: cart tracks lead to the storehouse` | TRACKS joins Known |
   | Dials, the coolant valve (inside the grounds) | `dials: someone tapped the coolant line!` | TAPPED joins Known |
   | Dials, the hatch, HATCH known | `dials forces the hatch. stairs go down.` | The hatch opens to the basement |
   | Dials, the hatch, HATCH not known | `dials finds nothing to fix.` (as now) | Nothing |
   | Vesna, next to Brandt | `vesna talks brandt into opening up.` | The gate opens and Brandt goes to Open |
   | Maren, next to Jory | `maren treats jory's fever.` | Jory goes to Open |

2. **Jory is locked.** Every real topic is at Open, and trust only grows from real answers, so
   talking can't unlock Jory. Vesna's first-meeting bonus only reaches Guarded. This works with
   the current rules; no new code is needed for the lock itself.
3. **The ending.** Once Voss has answered CORWIN, leaving the conversation runs the ending. It
   counts how many of CARTS, BARRELS, TRACKS and TAPPED are on the Known list.

   **Two or more proofs:**

   > The squad brings Abel Voss up out of the dark.
   >
   > In the town square, Hesper reads out the tank numbers. Jory tells what he saw at the valve.
   > The Keepers break open the storehouse and find the drums, stamped with the town hall's mark.
   >
   > Corwin smiles to the very end. It doesn't help.
   >
   > The coolant runs where it should. The reactor steadies, and Cinderhill keeps its lights.
   > For now.

   **Fewer than two:**

   > Voss climbs into the daylight, blinking.
   >
   > The mayor shakes his hand and calls it a miracle. Nobody asks where the water went. By
   > morning the tap on the coolant line is gone.
   >
   > Voss knows. You know. The reactor sputters on, and Cinderhill's fate is still open.

## Numbers

- **Keywords:** 28 of the 32 the Known list can hold. That's the 4 known at the start, 22 from
  answers and 2 from skill spots. The two Known rows show about the newest dozen. Older words stay
  known and still work when typed.
- **Topics:** 155 across the 8 people. Hesper has the most at 27, under the limit of 32.
- **Size:** about 14.7 KB of text plus 2.4 KB of tables. That and all eight portraits didn't fit
  in memory together, so portraits now load from disk when a conversation opens. With the whole
  cast's dialogue built in, about 8 KB is left for milestone 5.
- **Checks:** the draft passes all of the tool's own limits:
  - 24 columns per line;
  - 14 lines per answer;
  - no two keywords sharing their first 4 letters within one person;
  - only characters the font has.

  A simulation of the trust rules also confirms every topic can be reached by talking, except
  Jory's, by design.

## My calls (please check)

- Brandt, Tamsin, Odalys, Pip and Hesper never get a he or she. Voss and Corwin are "he", as in
  the built text. Jory is "he" only in the ending, following the spec's "makes him talk".
- Jory's fever is left ambiguous: a cold, or standing in the warm runoff. It isn't poison.
- Pip's way into the compound is a hole only a kid fits through, so it doesn't bypass Vesna's
  persuasion.
- The Keepers watch the front gate, and the carts used the back fence. That's how the theft
  happened under their noses.
- Brandt's gate opens only to Vesna's skill. Talking Brandt up to Open gets the story, not the key.
- Small inventions: six Keepers, forty barrels a week, Corwin's twelve years as mayor, the
  caravan dog Biscuit, about three hundred people in town.

# english-coach

Personal Claude Code plugin. Passive American English coaching for a Brazilian Portuguese speaker. Every prompt you send (typed or voice-dictated, in English or Portuguese) is executed normally, and Claude silently appends a nativized correction to a single global learning file. No blocking, no interruptions.

## What it does

- On every prompt, a `UserPromptSubmit` hook injects coaching instructions into Claude's context.
- Claude appends an entry to `~/.claude/english-learning/learning.md`:

```markdown
## 2026-08-15 14:32 | project: my-app
- ORIGINAL: I builded a endpoint for get the users datas
- NATIVE: I built an endpoint to fetch the user data
- WHY:
  - "builded" > "built" (irregular past)
  - "a endpoint" > "an endpoint" (article before vowel sound)
  - "for get" > "to fetch" (infinitive of purpose)
  - "datas" > "data" (uncountable)
```

- Prompts written in Portuguese are ignored by the coach: the task runs normally and nothing is logged. Coaching applies only to prompts attempted in English.
- The Portuguese test is a **ratio, not a tripwire**: a prompt is only skipped when more than 20% of its words are Portuguese. Dropping a couple of Portuguese words into an English sentence to cover a vocabulary gap therefore still gets coached, and the missing English term earns its own `WHY` bullet.
- Prompts that are already natural English are not logged (keeps the file signal-dense).
- **Missing apostrophes in contractions are ignored** (`im`, `dont`, `thats`, `howd`, `theres`). They are typing speed, not a language gap, and they never trigger an entry on their own. The word-choice pairs stay in scope, though, since those are grammar and not a slip: `its`/`it's`, `your`/`you're`, `their`/`they're`/`there`, `whose`/`who's`, `were`/`we're`.
- Skipped automatically: slash commands, prompts under 4 words ("yes", "continue"), and Portuguese input (all detected in the hook itself, zero token cost).
- Probable dictation (STT) errors are tagged `[STT?]` instead of being treated as grammar mistakes.
- `/english-review` produces two parts: a compact analysis (recurring patterns, false cognates, progress signal, drills) and then every logged entry reformatted with `NATIVE` and `WHY` nested under `ORIGINAL`. Arguments: a topic (`/english-review prepositions`) narrows both parts, a number (`/english-review 20`) caps the listing at the 20 newest entries, and the two combine.

## Install (local, personal use)

The plugin lives inside a local marketplace directory, versioned in the `linux-config` repo. The marketplace root is `~/projects/linux-config/claude-plugins` (it holds `.claude-plugin/marketplace.json`), and the plugin itself is the `english-coach/` folder inside it. The marketplace's own [README](../README.md) and `Makefile` cover registration, reinstall and checks for every plugin there. One-time setup:

```bash
# 1. Clone the repo if it is not on this machine yet:
git clone <your-remote>/linux-config.git ~/projects/linux-config

# 2. Make the hook executable:
chmod +x ~/projects/linux-config/claude-plugins/english-coach/hooks/english-coach.sh

# 3. Register the local marketplace and install:
claude plugin marketplace add ~/projects/linux-config/claude-plugins
claude plugin install english-coach@personal

# 4. Restart Claude Code (hooks load at session start).
```

The plugin runs from a cached copy under `~/.claude/plugins/cache/personal/english-coach/`, so edits made in the repo only take effect after reinstalling (`claude plugin uninstall english-coach@personal`, then `claude plugin install english-coach@personal`, or `make -C ~/projects/linux-config/claude-plugins reinstall PLUGIN=english-coach`) and restarting Claude Code (or `/reload-plugins`).

Verify: run `/hooks` inside Claude Code and confirm the english-coach UserPromptSubmit hook is listed.

## Permissions (one-time)

The log file lives outside your project, so allow Claude to write there without prompting. Add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "additionalDirectories": ["~/.claude/english-learning"]
  }
}
```

## Usage with voice

1. Inside Claude Code, run `/voice` and grant microphone permission.
   - On Linux the microphone goes through PipeWire or PulseAudio. If recording stays silent, check that your terminal is not muted in `pavucontrol` under Recording.
2. In `/config`, keep the dictation language set to `en`. Speaking Portuguese with `en` set will produce garbled transcriptions, which nudges you toward English.
3. Hold space to record, release to insert the transcription, edit if needed, press Enter. Typing remains fully functional alongside voice.

## Configuration

| Setting | Default | Override |
|---|---|---|
| Portuguese cutoff (% of words above which a prompt is skipped) | `20` | Export `ENGLISH_COACH_PT_THRESHOLD` in `~/.zshrc`. Raise it to keep coaching heavily mixed prompts, lower it to skip sooner. |
| Minimum words to trigger | `4` | Export `ENGLISH_COACH_MIN_WORDS` in `~/.zshrc`. |
| Log file location | `~/.claude/english-learning/learning.md` | Export `ENGLISH_COACH_LOG` in `~/.zshrc`. Recommended: a note inside your Obsidian vault, e.g. `export ENGLISH_COACH_LOG="$HOME/Obsidian/SecondBrain/Areas/English/learning.md"` (adjust to your vault path). Remotely Save then makes it readable on mobile for free. |

When pointing the log into the vault, also update the permissions entry to match, e.g. `"additionalDirectories": ["~/Obsidian/SecondBrain/Areas/English"]`.

## Claude Desktop (same log file, best-effort)

Claude Desktop has no hooks, so coverage there is instruction-based: the model applies it most of the time, not deterministically. Claude Code remains the reliable capture channel.

Paste this into claude.ai Settings > Profile (user preferences), adjusting the note path to your vault:

```
English coaching: I am a Brazilian Portuguese speaker training American English.
When my message is written in English and contains grammar, word-choice, or
phrasing mistakes, AND a tool capable of writing to my Obsidian vault or local
filesystem is available in this conversation: silently append one entry to the
note Areas/English/learning.md in my vault, formatted as:
## <date time> | project: desktop
- ORIGINAL: <my message verbatim>
- NATIVE: <natural American English version>
- WHY: <terse bullets, one per correction>
Rules: never mention the log or corrections in your reply; never block, delay,
or alter my actual request; skip messages under 4 words, messages that are
already natural English, and messages more than 20% Portuguese by word count. A
message that is mostly English with a few Portuguese words is a vocabulary gap,
not Portuguese: coach it and give me the English term. Ignore missing
apostrophes in contractions (im, dont, thats, howd) entirely, but do coach
its/it's, your/you're, their/they're/there and whose/who's, which are word
choices rather than typos. If no such tool is available, do nothing at all.
```

Voice on Desktop works out of the box with the built-in dictation, no extra setup.

## Review ritual

The log is only worth what you extract from it. Suggested cadence: one weekly `/english-review` in Claude Code (the log is shared, so it covers Desktop entries too). Reading the note on mobile via Obsidian + Remotely Save works for passive review anywhere.

## Maintenance

- Review weekly with `/english-review`.
- **Nothing prunes the log.** There is no rotation, no cron job and no size cap: every entry stays until you move it yourself. At roughly 1 KB per entry this is a context cost long before it is a disk cost, since `/english-review` reads the whole file. Archive with a plain rename when it gets unwieldy:

  ```bash
  mv ~/.claude/english-learning/learning.md ~/.claude/english-learning/learning-$(date +%Y-%m).md
  ```

  The hook recreates the directory and Claude recreates the file on the next logged prompt. Archived files are ignored by `/english-review`, which only reads `learning.md`.
- **The log is not backed up.** `~/.claude/english-learning/` sits outside the `linux-config` mirror, so `backup.sh` never touches it. Point `ENGLISH_COACH_LOG` at a synced folder (see Configuration) if losing the history would bother you.
- Uninstall: `claude plugin uninstall english-coach@personal`.

## Troubleshooting

- **No entries appearing**: run `/hooks` to confirm the hook is loaded. Hooks only load at session start, so restart Claude Code after install or edits.
- **Hook loaded but no context injected**: some Claude Code versions had a bug where plugin-defined `UserPromptSubmit` stdout was not injected. Workaround: register the hook directly in `~/.claude/settings.json` instead:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/projects/linux-config/claude-plugins/english-coach/hooks/english-coach.sh"
          }
        ]
      }
    ]
  }
}
```

- **Claude asks permission to write the log every time**: check the `additionalDirectories` entry above.
- **Entries logged for prompts that were fine**: the "already natural" judgment is Claude's. Tighten rule 1 in `english-coach.sh` if it over-logs.
- **Apostrophes still being corrected**: rule 2 in `english-coach.sh` covers them. Add the spelling you keep seeing to its list, but keep the `its`/`it's` style pairs out of it, since those are genuine word choices.
- **A Portuguese prompt got coached anyway**: its Portuguese word share landed at or under the cutoff. Either lower `ENGLISH_COACH_PT_THRESHOLD` or add the missing words to the `PT_WORDS` list in `english-coach.sh`. That list deliberately omits words that also exist in English (`a`, `as`, `no`, `do`, `com`, `todo`, `era`, `me`), since a false Portuguese hit silently costs a lesson.

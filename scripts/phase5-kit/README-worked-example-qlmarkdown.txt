==============================================================================
  PHASE 5 RUNTIME REVIEW - QLMarkdown 1.5.0
  Procedure for the isolation account
==============================================================================

Plain text on purpose. You do not have QLMarkdown installed yet, so nothing
here relies on a Markdown previewer. Read it in TextEdit, or in Terminal with:

    less /Users/Shared/phase5-kit/README.txt

  (press the space bar to page down, press q to quit)

------------------------------------------------------------------------------
  WHAT THIS IS FOR
------------------------------------------------------------------------------

Phases 1 to 4 of this review were done by reading. Nothing was ever run.
Those phases produced one unresolved question, and Phase 5 exists to answer it:

    A Markdown file might be able to make QLMarkdown read an unrelated file
    from your disk and embed its contents into the preview - just because you
    clicked the file once in Finder.

Reading the source suggested this is possible. Reading cannot prove it.
So now we test it, on purpose, in an account that contains nothing valuable.

You are looking for FOUR answers:

    Q1  Does a previewed file cause QLMarkdown to read an unrelated file?
    Q2  Does JavaScript run inside the Quick Look preview window?
    Q3  When does it download MathJax and Mermaid from the internet?
    Q4  Does it check for software updates before you agree to let it?

------------------------------------------------------------------------------
  SAFETY - READ THIS FIRST
------------------------------------------------------------------------------

  *  Do ALL of this in the standard account named "isolation".
     Never in your admin account. The setup script refuses to run as an admin.

  *  There are NO real passwords or keys anywhere in this test. The files
     named id_rsa and credentials contain harmless fake text called
     "canaries". Their only job is to be easy to search for. If a canary
     ever shows up somewhere it should not, that is your evidence.

  *  Install QLMarkdown into  ~/Applications  (inside this account).
     Do NOT install into /Applications - that folder is shared with your
     real account and would defeat the whole point.

  *  You may stop at any time. Stopping is a valid outcome, not a failure.

------------------------------------------------------------------------------
  BEFORE YOU BEGIN - three windows
------------------------------------------------------------------------------

Open Terminal in the isolation account.

  >>> TIMING CUE 1 of 4 - copy and paste this now, before anything else:

          bash /Users/Shared/phase5-kit/mark.sh prep-start

  It prints the time and records it. That is all it does.

Now make THREE windows or tabs. Two of them stay open and running for the
whole session. (The window you just typed in becomes WINDOW C.)

  WINDOW A - the listener. This is your most important instrument.
  WINDOW B - the log stream. This is your second instrument.
  WINDOW C - for typing commands.

Set them up in this order.

  WINDOW A, type:

      mkdir -p ~/probe && cd ~/probe
      python3 -m http.server 8000

  You should see:  Serving HTTP on :: port 8000 ...
  Leave it running. Keep it where you can see it.

  WINDOW B, the log window.

  CORRECTION - please read, this instruction was wrong in the first version.

  The live command 'log stream' requires administrator rights, which this
  account deliberately does not have. If you tried it and got:

      log: must be admin to run 'stream' command

  that is the isolation working exactly as intended. Not a fault, and not
  something to fix by granting this account more power.

  Two things replace it, and between them you lose nothing:

  1. A FULL LIVE CAPTURE IS ALREADY RUNNING FOR YOU in the admin session.
     It records everything QLMarkdown logs, system-wide - including from
     this account - into:

         /Users/Shared/phase5-kit/out/logstream.txt

     You do not need to start it, watch it, or keep it alive. It is already
     going and it will capture every probe you run.

  2. For live feedback during the probes, use the on-demand version in
     WINDOW B. Run it AFTER each probe file rather than watching non-stop:

         log show --last 2m --predicate 'subsystem CONTAINS "sbarex"' --info --debug

     First check that it works at all in this account:

         log show --last 1m --info | head -3

     If that prints a table header starting with "Timestamp", you are fine.
     If it also refuses, no problem - skip WINDOW B entirely and rely on the
     capture in (1) plus the listener in WINDOW A. Nothing is lost; you just
     read the evidence afterwards instead of during.

Leave WINDOW A alone from now on. All typing happens in WINDOW C.

------------------------------------------------------------------------------
  WHY THE LISTENER MATTERS
------------------------------------------------------------------------------

The listener is a tiny web server running on your own machine. Nothing it
receives ever leaves the computer.

If QLMarkdown reads your fake key and then tries to send it somewhere, we
point that "somewhere" at the listener. The listener writes down every
request it receives. So:

    A canary string appearing in a listener request = data theft, proven,
    with nothing actually stolen.

We rely on the listener rather than on Little Snitch because Quick Look
extensions run inside Apple's own background processes. A firewall often
blames those Apple processes instead of QLMarkdown, which makes firewall
logs confusing. The listener has no such problem.

------------------------------------------------------------------------------
  STEP 1 - CALIBRATE (prove your instruments work)
------------------------------------------------------------------------------

An instrument that is silently broken will tell you "all clear" when it
should be screaming. Test them before you trust them.

  1a. In WINDOW C:

          curl -s http://127.0.0.1:8000/calibration > /dev/null

      Look at WINDOW A. You should see a new line ending in:

          "GET /calibration HTTP/1.1" 404 -

      The 404 is CORRECT and expected. The file does not exist. What matters
      is that the request was seen at all.

      If nothing appears in WINDOW A - STOP. Fix the listener first.
      Everything else depends on it.

  1b. Check the Little Snitch menu bar icon. It must show the profile name
      "Audit". Creating a profile does not switch to it.

  1c. In WINDOW C:

          curl -I --max-time 15 https://example.com

      One of three things happens. All three are useful. Write down which:

        (i)   A Little Snitch alert appears naming "curl".
              -> Good. Click Deny, and choose "once" if offered.
              -> Your firewall works.

        (ii)  No alert, and you get back "HTTP/2 200".
              -> The firewall silently allowed it. It will probably not
                 show you QLMarkdown's traffic either.
              -> NOT a blocker. Note it and carry on. The listener still
                 answers every question that matters.

        (iii) No alert, and curl fails straight away.
              -> Silently blocked, no visibility. Same as (ii): note and
                 carry on.

  1d. Check the log window works, in WINDOW B:

          log show --last 1m --info | head -3

      A table header starting with "Timestamp" means it works.
      A refusal means skip WINDOW B and rely on the admin-session capture.
      Either way, write down which you got.

------------------------------------------------------------------------------
  STEP 2 - RUN THE SETUP SCRIPT
------------------------------------------------------------------------------

This creates the fake canary files, records a "before" snapshot of your
system, and writes the test files.

You are encouraged to read it first - this whole framework is about not
running code you have not looked at:

      less /Users/Shared/phase5-kit/01-setup.sh

Then run it, in WINDOW C:

      bash /Users/Shared/phase5-kit/01-setup.sh

It prints a summary when it finishes. It does not install anything and it
does not touch the internet.

  HEADS UP: macOS will probably show a permission box saying that Terminal
  "wants access to control System Events". That is this script asking for the
  list of login items, so it can tell later whether QLMarkdown added one.
  Click OK / Allow. If you refuse, the login-item check simply comes back
  empty and you lose one piece of evidence - not the end of the world.

  >>> TIMING CUE 2 of 4 - when the script prints READY, paste this:

          bash /Users/Shared/phase5-kit/mark.sh prep-end

  It will show you how long the prep took. Preparation is now finished.
  Take a break here if you want one - the clock is stopped between segments.

------------------------------------------------------------------------------
  STEP 3 - INSTALL QLMARKDOWN, AND WATCH WHILE YOU DO
------------------------------------------------------------------------------

Everything you need is in this section. You do not need to consult anyone or
switch accounts. If something goes wrong, the fix is written inline below.

Keep your eyes on WINDOW A (the listener) and on Little Snitch throughout.
This is where questions Q3 and Q4 get answered.

IGNORE WINDOW B. It does not exist for this run - a standard account has no
access to the system log at all. That is the isolation working correctly.
The log evidence is retrieved afterwards from the admin account. Nothing is
lost and there is nothing for you to do about it.

  >>> TIMING CUE 3 of 4 - paste this before you copy the app in:

          bash /Users/Shared/phase5-kit/mark.sh exec-start

  If you need to step away at any point:

          bash /Users/Shared/phase5-kit/mark.sh pause
          bash /Users/Shared/phase5-kit/mark.sh resume

  Paused time is subtracted automatically. Pause as often as you like.


  3z. OPEN YOUR ANSWER SHEET FIRST. Do this before anything else, and type
      into it as you go. It saves you remembering anything.

          cp /Users/Shared/phase5-kit/observations-template.txt \
             /Users/Shared/phase5-kit/out/observations.txt
          open -e /Users/Shared/phase5-kit/out/observations.txt

      TextEdit opens. Leave it open. Save with Command-S now and then.
      The assistant reads this file directly - you never retype anything.


  3a. COPY THE APP IN.

      The exact audited version is already staged for you, and its signature
      was re-verified after staging. In WINDOW C:

          mkdir -p ~/Applications
          cp -R "/Users/Shared/phase5-kit/QLMarkdown.app" ~/Applications/

      Copying is not launching. Nothing is running yet.


  3b. LAUNCH IT ONCE, from ~/Applications.

      macOS requires one launch before a Quick Look extension is registered.

          open ~/Applications/QLMarkdown.app

      WATCH, and write the answers into your answer sheet:

        *  Any Little Snitch alert? To what address?
        *  Did WINDOW A show anything?
        *  Did it ask for an administrator password?
           (If yes, that is a finding - record exactly what asked.)
        *  Did it ASK to check for updates, or just start checking?

      You will NOT get an "unidentified developer" warning. That is expected
      here and explained under KNOWN QUIRKS near the end of this file.


  3c. CHECK WHETHER IT DOWNLOADED JAVASCRIPT.   (question Q3)

      Immediately after first launch, in WINDOW C:

          ls -la ~/Library/Group\ Containers/group.org.sbarex.qlmarkdown/js/

      If MathJax and Mermaid files are already there, they were fetched from
      the internet during first launch, before you asked for anything.
      Note the timestamps. Paste the output into your answer sheet.

      "No such file or directory" is an equally useful answer - it means
      nothing was downloaded yet.


  3d. MAKE SURE THE EXTENSION IS ACTUALLY WORKING.

      THIS IS THE STEP MOST LIKELY TO WASTE YOUR TIME. If the extension is
      not active, macOS silently falls back to its own plain text preview.
      Every probe below would then appear to do nothing, and you would
      wrongly conclude the software is clean.

      First, tick it on:
        System Settings > General > Login Items & Extensions > Quick Look
      Make sure QLMarkdown is present and TICKED.

      THEN TEST IT FUNCTIONALLY. This is the only check that matters:

          open ~/probe

      Select 00-control.md, press the SPACE BAR.

        FORMATTED  - styled heading, a real table with borders, a colourful
                     code block
                     -> WORKING. Record it and go to 3e.

        RAW TEXT   - you can literally see  #  and  |  and  **  characters
                     -> NOT working. Fix it with the steps below.

      IF IT SHOWS RAW TEXT, in this order:

        1. Close the preview. Quit QLMarkdown completely (Command-Q).
        2. Reset the preview cache and relaunch:

               qlmanage -r cache
               killall -9 qlmanage 2>/dev/null
               open ~/Applications/QLMarkdown.app

        3. Re-tick it in System Settings, then try 00-control.md again.
        4. Still raw? Drag ~/Applications/QLMarkdown.app to the Trash,
           copy it in again from 3a, launch once, re-tick, retry.

      DO NOT USE  qlmanage -m plugins  TO CHECK THIS. It will always print
      nothing, no matter how correctly things are installed. It only lists
      the OLD style of Quick Look plugin, and QLMarkdown ships a MODERN app
      extension that qlmanage cannot see. Earlier instructions here said
      otherwise and that was simply wrong.

      If you want a registry check anyway, this is the correct one:

          pluginkit -m -p com.apple.quicklook.preview
          pluginkit -m | grep -i qlmarkdown

      A leading  +  means enabled, a leading  -  means disabled. But trust
      the space-bar test over this.

      If you have retried three times and it still shows raw text, STOP.
      Record it in the answer sheet and go and ask. Do not keep reinstalling
      - repeated identical attempts are not evidence, they are just time.


  3e. RECORD THE SETTINGS, AND CHANGE NOTHING.

      Reading the source predicted this app ships with raw HTML rendering
      switched ON - the opposite of what its own documentation claims.
      Confirm that against the real thing before testing anything.

      In the QLMarkdown window, find the options and write ON or OFF for
      each of these into your answer sheet:

          Inline HTML (unsafe)      predicted ON
          Inline local images       predicted ON
          Validate UTF              predicted OFF
          Math                      predicted ON
          Mermaid                   predicted ON
          Table                     predicted ON

      DO NOT CHANGE ANY OF THEM. You are testing the software as it ships.

      If what you see does not match the predictions, that is a finding in
      its own right, and it changes what every probe below means. Write down
      exactly what you saw.

      Then quit the QLMarkdown window (the previews do not need it open).

------------------------------------------------------------------------------
  STEP 4 - PREVIEW THE TEST FILES, ONE AT A TIME
------------------------------------------------------------------------------

Open Finder and go to your "probe" folder. In WINDOW C you can type:

      open ~/probe

To preview a file: click it ONCE to select it, then press the SPACE BAR.
Press SPACE again, or Escape, to close the preview.

Do NOT double-click. Single click, then space. The whole point is that
merely previewing is enough.

Go in order. After each one, glance at WINDOW A, and in WINDOW B run:

      log show --last 2m --predicate 'subsystem CONTAINS "sbarex"' --info --debug

(If log show does not work in this account, skip it - everything is being
captured for you in out/logstream.txt regardless.)

  FILE 00-control.md
      Ordinary Markdown. Establishes what normal looks like.
      Expect: renders nicely. Nothing in WINDOW A.

  FILE 01-remote-image.md
      Contains an image whose address points at your listener.
      Expect in WINDOW A: a request for /remote-image-probe.png
      If it appears, previewing a file reaches the network on its own.

  FILE 02-traversal-benign.md
      Tries to pull in /etc/hosts - a harmless public system file.
      Watch WINDOW B for a message saying "is not an image!"
        *  Message appears -> QLMarkdown REFUSED. Good.
        *  No message, and you see junk text or a broken image
           -> it accepted the file. That is Q1 answered.

  FILE 03-traversal-canary.md      <<< THE IMPORTANT ONE
      Tries to pull in the fake private key.

      This file deliberately contains the SAME request written two ways:
      once as raw HTML, once in Markdown syntax. Reading the source predicted
      they behave DIFFERENTLY, so here is the exact prediction to test:

          Markdown syntax  ![canary](../.ssh/id_rsa)
              -> should be REFUSED, and should log "is not an image!"

          Raw HTML         <img src="../.ssh/id_rsa">
              -> predicted to be ACCEPTED, silently, with no log message

      So if the prediction is right, WINDOW B shows the rejection message
      roughly once, not twice, even though the file asks twice.

      That asymmetry is the whole finding. Count the messages carefully and
      write down how many you saw.

      Then run STEP 5 to confirm what actually ended up in the output.

  FILE 04-script-probe.md
      Contains image and SVG tags carrying onerror/onload handlers that
      try to call your listener.
      Expect in WINDOW A: a request for /js-executed or /svg-onload
      If either appears, JavaScript RUNS in the preview. That is Q2, and
      it is the answer that decides the whole review.

  FILE 05-mermaid.md
      A Mermaid diagram.
      If a diagram draws, JavaScript is running (Mermaid needs it).
      Watch for a download if the library was not already cached.

  FILE 06-math.md
      A mathematical formula, same idea.

  FILE 07-malformed.md
      Deliberately broken text. Expect ugly output. You are watching for
      a CRASH or the preview hanging - either is worth recording.

  FILE 08-large.md
      A large file, roughly 2 to 3 megabytes of text. Watch for the fan
      spinning up or a long freeze.

      If the preview hangs, press Escape and give it a moment. If Finder
      itself becomes unresponsive, that is worth recording - and you can
      recover with:  killall -9 qlmanage   (this harms nothing).

------------------------------------------------------------------------------
  STEP 5 - CHECK WHETHER THE CANARY LEAKED
------------------------------------------------------------------------------

When QLMarkdown embeds a file into a preview it converts it into a long
run of letters and digits called base64. So searching for the plain words
"CANARY-AUDIT" is not enough - you must also search for the encoded form.

The setup script saved both forms for you. View them with:

      cat ~/probe/canaries.txt

QLMarkdown ships a command line tool that uses the same rendering engine.
Using it lets us capture the output as a file we can actually search.

THE TWO FLAGS MATTER. The command line tool does not share settings with the
Quick Look extension, and it defaults differently. Without these flags it
will not exercise the code path we are testing, and you would get a false
all-clear:

      ~/Applications/QLMarkdown.app/Contents/Resources/qlmarkdown_cli \
          --raw-html on --inline-images on \
          -o ~/probe/rendered-canary.html \
          ~/probe/03-traversal-canary.md

(If it complains about not finding its resources, add this as well:
     --app ~/Applications/QLMarkdown.app )

Then:

      bash /Users/Shared/phase5-kit/03-check-canary.sh

The check script tells you plainly whether the canary made it into the
rendered output.

Note the limitation, and record it: the command line tool is a slightly
different path from the Quick Look extension. A hit here proves the
mechanism is real. The WINDOW B evidence from STEP 4 is what tells you
the Quick Look extension behaves the same way.

------------------------------------------------------------------------------
  STEP 6 - CHECK WHETHER ANYTHING STUCK AROUND
------------------------------------------------------------------------------

In WINDOW C:

      bash /Users/Shared/phase5-kit/02-capture.sh

This takes an "after" snapshot, compares it with the "before" one from
STEP 2, and copies everything into /Users/Shared/phase5-kit/out/ so the
assistant can read it from your admin account.

You are looking for anything NEW:
      *  background services (launch agents or daemons)
      *  login items
      *  changes to your startup files

A Markdown previewer has no legitimate reason to add any of these.

------------------------------------------------------------------------------
  STEP 7 - SAVE THE LISTENER LOG
------------------------------------------------------------------------------

Go to WINDOW A. Select all the text in that window and save or copy it into:

      /Users/Shared/phase5-kit/out/listener-log.txt

This is your primary evidence. Do not skip it.

  >>> TIMING CUE 4 of 4 - once the listener log is saved, paste this:

          bash /Users/Shared/phase5-kit/mark.sh exec-end

  It will show you how long the execution segment took. You are done.

------------------------------------------------------------------------------
  KNOWN QUIRKS - none of these are faults, but they will confuse you
------------------------------------------------------------------------------

  *  NO "UNIDENTIFIED DEVELOPER" WARNING.
     Normally macOS warns you the first time you open something downloaded
     from the internet. You will not get that warning here, because the file
     was fetched with a command line tool rather than a browser, so macOS
     never tagged it. This is expected. It also means your experience differs
     slightly from a normal user's - worth noting in the report.

  *  LITTLE SNITCH MAY BLAME APPLE.
     Quick Look extensions run inside Apple's own background processes, so
     alerts may name something like QuickLookUIService instead of QLMarkdown.
     Do not read that as "QLMarkdown did nothing". Trust the listener.

  *  THE LISTENER SHOWS 404 FOR EVERYTHING.
     That is correct. The listener has no files to serve. A 404 still proves
     the request was made, which is all we care about.

  *  THE LOG WINDOW MAY BE CHATTY.
     Other software also logs. You only care about lines mentioning sbarex
     or QLMarkdown.

  *  PREVIEWS CACHE.
     If you preview the same file twice, the second time may not repeat the
     work. If you need a clean re-test, run:  qlmanage -r cache
     then try again.

  *  NOTHING HERE WILL DELETE YOUR DATA.
     The worst realistic outcome is a preview window that hangs. Escape, or
     killall -9 qlmanage, gets you out of it.

------------------------------------------------------------------------------
  STOP IMMEDIATELY IF ANY OF THESE HAPPEN
------------------------------------------------------------------------------

Each one is an automatic REJECT under the rules you agreed in advance,
before any of this was run:

      *  A canary string appears in ANY listener request.
      *  It contacts an address that no earlier phase predicted.
      *  It asks for an administrator password without an obvious reason.
      *  It installs a background service or a login item.
      *  It starts a shell, a script interpreter, or a network tool.

If any of these occur: stop, write down exactly what you saw, and switch
back to your admin account to report it.

------------------------------------------------------------------------------
  WHEN YOU ARE DONE
------------------------------------------------------------------------------

Switch back to your admin account and tell the assistant you are finished.
It will read the files in /Users/Shared/phase5-kit/out/ directly, so you do
not need to retype anything.

Do NOT delete the isolation account yet. Wait until the findings are written
into the report and you have made your decision.

==============================================================================

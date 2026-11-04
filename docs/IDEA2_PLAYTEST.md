# Golden Hour: work the donut stand

Idea 2 playtest - version 0.3.0

You are the operator behind a mini-donut stand. The machine fills a tray while
you portion, coat, and hand over orders. Your job is to keep the serving rhythm
going while attending to the machine and the waiting customers.

## Your first order

1. Read the customer's requested container and sugar.
2. Take a bag or bucket from the counter.
3. Pick up the scoop, then click the tray to collect up to three cooked donuts.
4. Pour those donuts into your container, then scoop and pour again as needed.
5. Add the requested cinnamon sugar or powdered sugar.
6. Click the finished package to lift it, then click the waiting customer to
   hand it over. Clicking the package again puts it down.

A bag holds **six donuts**: two full scoops. A bucket holds **twelve donuts**:
four full scoops. A scoop taken from an almost-empty tray may contain fewer
than three, so watch the actual portion count. The wider-scoop upgrade changes
the scoop size to four.

Use the physical counter objects to perform the work. The order display and
machine indicators tell you what needs attention. The scoop stays selected
between loads so filling a bucket feels like a continuous sequence.

Click or tap an object to use it. Hold the repair lever or batter hopper until
its progress bar completes. On a computer, hold the right mouse button and drag
to look around; **Home** recentres the view. **Esc** pauses. The pause menu has
instructions, sound/music controls, reduced motion, and save-and-return.

Optional keyboard controls: **B** bag, **V** bucket, **S** pick up scoop,
**F** scoop from tray, **Space** pour/lift/put down, **C** cinnamon,
**P** powdered, **E** hand over, hold **R** repair, hold **T** refill,
**- / +** adjust heat, **X** discard, **H** help.

## Keep the stand moving

- Customers have limited patience. Finish an order before starting unnecessary
  extra work, and watch the waiting line.
- Match the front customer's container and sugar. A wrong order stays with you
  and costs patience. Use the discard bin to start again; plain donuts can be
  recovered, but coated mistakes are wasted.
- Clear a jam by holding the machine's repair interaction until it completes.
- If the oil gets too hot, reduce the heat using the machine control. Watch the
  indicator to see the effect of the adjustment.
- Refill the hopper when batter runs low. Production and the ready-donut tray
  give you a buffer while your hands are busy serving.
- Work through three shifts. Reach the displayed sales target before the clock
  runs out, then choose improvements between shifts. Later shifts test how well
  you balance serving, supplies, and maintenance.

This is a hands-on serving prototype. The useful playtest question is whether
scooping, pouring, coating, and handing over an order feels satisfying enough
to repeat while the queue makes you choose what to do next.

## Start the build

On Windows, open `GoldenHour.exe` from the version 0.3.0 folder or its Idea 2 ZIP.
Keep the included LICENSES folder with the game. No account is needed.

The Web build must be served over HTTP or HTTPS; opening `index.html` directly
from disk will not work. Use a browser supporting WebGL 2 and WebAssembly, and
click the game to let it receive input and play audio.

The previous Idea 1 version 0.2.0 builds remain available separately for
comparison. This version changes the loop to manual service; it does not ship
Steam integration or native iOS/Android packages.

## Useful feedback

Tell us where an interaction felt satisfying, where you lost track of the held
tool or container, and what caused a missed order. Note whether waiting for the
machine felt purposeful or idle, and whether maintenance created a worthwhile
decision or merely interrupted you. Include your platform and the shift number.

## Credits

The machine, stand, donuts, animations, and synthesized audio are original
project assets. Godot is MIT-licensed. The Fredoka typeface is supplied under
SIL OFL 1.1. Complete engine, third-party, and font notices accompany the build.

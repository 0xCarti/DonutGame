# Golden Hour product direction

## Chosen game

Develop **Game Idea #1**: a 3D mini-donut roguelite built around one familiar machine, escalating sales targets, and upgrades that combine into increasingly powerful production. The machine is the centrepiece throughout a run. The player chooses batches and destinations, watches donuts cook, and decides when to sell trays.

The desired presentation is tactile and dimensional: a small place the player feels they are operating, with the animation and escalating reward energy of machine-centred roguelikes. References inform the quality and feel; Golden Hour retains its own donut-stand identity, original assets, and fictional equipment branding.

The current playable baseline has six shifts, three recipes and trays, twenty upgrades, saving, a tutorial, and mouse/touch/keyboard controls. Its short runs support quick playtesting. Balance and long-term progression remain subjects for playtest feedback.

## Setting and future venues

The initial setting is a **warm fairground**: a welcoming stand, late-day light, canopy fabric, wooden counters, glowing signs, and movement beyond the booth. Keep the machine, cooking donuts, and controls visually dominant.

Future venue directions include **concerts and sporting events**. Preserve the recognisable machine and operating layout while changing the environment around it: crowd silhouettes, lighting, music, neighbouring concessions, props, and the atmosphere of a particular event. A venue should feel like a new place to run the same stand. Venue-specific gameplay rules can be considered later, separately from art variation.

Keep environment components replaceable: background scene, lighting profile, ambience, counter dressing, and signage. Cosmetic venue selection should not silently alter targets, payouts, machine capacity, or recipe behavior.

## Art and animation priorities

Move beyond basic geometric blockout while preserving clear silhouettes and mobile-friendly performance.

- **Hero machine:** recognisable stainless-steel hopper, frying channel, moving flipper and delivery chute; bevelled edges, fasteners, seams, lightly varied roughness, and controlled reflections make it feel manufactured.
- **Food:** rounded, slightly irregular rings with visible browning and a distinct coating treatment for cinnamon, powdered sugar, and cocoa. Gold variants should read immediately without hiding the recipe.
- **Counter and props:** believable wood grain, small wear marks, paper bags, supply containers, handles, labels, and folded or stretched fabric. Detail should reward looking closely without competing with the donuts.
- **Lighting:** warm practical lights and cooler shadow separation, with enough fill to keep recipes and tray occupancy readable. Use highlights to describe surfaces rather than making the whole stand uniformly shiny.
- **Motion:** a clear drop, a satisfying fry/flip, a little landing bounce, and a decisive sale. Add small machinery movements and restrained venue activity to make the scene feel alive.
- **Composition:** keep the three tray destinations distinct. Celebration should reinforce the sale location and then lead attention to the updated total.

Prefer a few intentional material and shape details over many indistinct decorative objects. Check the machine and food at actual gameplay size, not only in close-up renders.

## Escalating score feedback

Successful sales should build from a modest acknowledgement into a much more exciting payoff as combinations grow. The **actual earned amount** remains the most readable element; a short named tier, colour, sound layer, and burst intensity support it.

Feedback tiers and presentation chains are visual/audio interpretation of a completed sale. They do not add money or change the run model. A visual chain must not be labelled as a payout multiplier unless it corresponds to an actual gameplay multiplier.

Use the sale receipt as the source of truth. It already carries amount, count, full-tray status, golden count, combination text, multiplier, and streak. Avoid processing the same sale through both a direct callback and the queued event path. Keep feedback randomness separate from the seeded gameplay RNG.

Keep the machine, quota, timer, and tray buttons usable during the strongest effects. Bound simultaneous popups and particles; consolidate rapid repeated sales rather than layering unreadable text. Decorative controls must not intercept pointer input. Clear transient feedback when leaving gameplay.

Provide a **reduced-motion setting** that preserves the amount and meaning while removing camera shake, large scale changes, fast travel, and dense particle bursts. The preference applies immediately and survives restarts. Sound and motion preferences remain separate.

## Purchases and monetization: open decision

The project should leave room for future purchases. The monetization model is **not decided**. The current choice awaiting the user's direction is cosmetics, gameplay boosts, or leaving the decision open. This pass creates no store, checkout, payment processing, or paid entitlement implementation.

**Recommendation: start with cosmetics.** Machine finishes, stand decoration, canopy designs, signs, packaging looks, and venue themes can extend the game's identity while preserving the shared challenge. Keep recipes, ordinary upgrade combinations, and the core loop meaningful without a purchase.

If the user later chooses gameplay boosts, define their effects and limits before implementation. Consider explicitly marked **assisted runs**, with separate records from the standard ruleset. Avoid mixing boosted and standard results in a future leaderboard or comparing them as equivalent performance. This is a recommendation for a future design decision, not an implemented system or an approved commercial plan.

For future architecture, keep these concerns distinct:

- The run model owns targets, upgrades, production, and payouts.
- A presentation loadout selects compatible visual and audio assets.
- A future entitlement layer would determine which optional content is available.
- A future ruleset identifier would record any approved gameplay assistance.

The current playtest should remain fully usable while these product decisions are explored. Reserve extensibility without adding purchase prompts to the existing play flow.

## Next validation questions

1. Can players tell why a sale triggered stronger feedback?
2. Can they read the amount and locate the next action during a large payout?
3. Do simultaneous tray sales feel exciting without hiding important information?
4. Does reduced motion retain the same clarity and sense of success?
5. Do richer materials make the machine feel tangible at the normal camera distance?
6. Does the stand remain readable at a small landscape viewport?
7. Which cosmetic changes would players actually want to collect or choose?
8. If boosts are considered, what player problem would they solve, and should those runs be recorded separately?

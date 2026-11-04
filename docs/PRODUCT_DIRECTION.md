# Golden Hour product direction

## Chosen game

Develop **Game Idea #2**, viewed from **first person behind the counter**. This replaces Idea 1 as the active design after the first tray-builder playtest felt boring and made perfect trays too easy. Preserve the earlier prototype for comparison.

The machine automatically drops plain donuts into a catch tray. Customers order bags or buckets with cinnamon or powdered sugar. The player chooses the container, picks up a scoop, scoops donuts, pours them into the container, adds the requested coating, lifts the order, and hands it to the waiting customer. The scoop stays equipped between loads. Occasional jams, rising oil temperature, and batter refills compete with service.

The challenge should come from reading orders, completing a satisfying physical sequence, maintaining stock, and choosing when to interrupt service. A wrong order should have understandable consequences and a clear recovery path. Avoid replacing the old easy tray button with a new automatic-serve button.

Version 0.3.0 provides three timed shifts, a queue of up to three customers, eight possible upgrades, two container sizes, two coatings, physical scene interactions, visible hands and tools, and local saving. Quotas rise as customers arrive more quickly. Upgrades help production, capacity, patience, repairs, and tips while retaining manual service.

## Setting and perspective

Start at a **warm fairground** with canopy fabric, wood counters, steel machinery, practical lights, nearby stalls, and a visible customer across the counter. The camera belongs to the operator. Visible arms, held tools, local object responses, and bounded look movement reinforce presence. Interaction targets must remain visible and reachable at the normal camera angle.

Future **concert and sports venues** should change the environment around a familiar operating layout: crowds, music, neighboring concessions, lighting, signage, and atmosphere. Venue unlock progression is a future feature. Keep scenery and lighting separate from order and production rules so cosmetic venue choices do not silently alter difficulty.

## Art and animation

The user's quality references are CloverPit, RACCOIN, and Bills Must Be Paid: dimensional environments and tactile machines with satisfying motion. Use these as references for presentation quality, while retaining original art, names, equipment, and a distinct donut-stand identity.

- Give the hero machine recognizable stainless surfaces, a batter hopper, frying channel, flipper, chute, bevels, fasteners, cables, and working controls.
- Give donuts browned irregular surfaces and visually distinct coatings. Make scoop contents and package fill legible.
- Give paper containers folds, printed designs, and visible depth. Use believable hands, gripping, pouring, seasoning, and handing-over animations.
- Keep the customer and active workstation readable. Warm light should reveal materials without washing them out.
- Use camera movement carefully. Preserve precise pointer targets and provide immediate reduced-motion settings.

Procedural assets establish the playable composition, but are not a claim of final commercial art quality. Assess graphics at gameplay distance and during actual interactions.

## Reward feedback

Correct service should produce a readable earned amount, customer response, sound, and a small visual reward. Consecutive good service should escalate the lights, particles, sound, and bounded camera motion. The strongest effects must leave the next ticket and physical work area usable.

Base effects on the authoritative completed-sale receipt. Do not duplicate the reward through both a direct action and a queued event. Decorative randomness must remain separate from the seeded gameplay simulation. A visual tier must not imply an unearned payout multiplier.

Reduced motion should remove shake and disruptive movement while retaining readable outcomes. Sound, music, and motion remain independent settings.

## Purchases: open decision

Leave architectural room for optional purchases, as requested, but the monetization model is **not decided**. No store, checkout, paid entitlements, or gameplay boosts are implemented or approved.

Cosmetic machine finishes, packaging, canopy designs, signs, and venue themes are a possible starting point. If temporary gameplay boosts are chosen later, specify their effects and limits, and consider separately labeled assisted runs. Those are recommendations for later decisions, not adopted rules.

Keep the run simulation, presentation choices, and any future entitlement system separate. The playtest must remain fully usable while the commercial model is explored.

## What to learn from this pivot

1. Does scooping, pouring, coating, and handing over feel good to repeat?
2. Can a new player find the correct physical objects and understand what is held?
3. Does the first shift teach a rhythm before later shifts create pressure?
4. Do maintenance and stock create worthwhile decisions rather than arbitrary interruptions?
5. Can mistakes be diagnosed and recovered from quickly?
6. Are upgrades noticeable without removing the serving loop?
7. Do successful streaks feel exciting while the next action remains readable?
8. Does the first-person booth feel dimensional and inviting at actual gameplay size?

# Golden Hour product direction

## Chosen game

Develop **Game Idea #2**, viewed from **first person behind the counter**. This replaces Idea 1 as the active design after the first tray-builder playtest felt boring and made perfect trays too easy. Preserve the earlier prototype for comparison.

The machine automatically drops plain donuts into a catch tray. Customers order bags or buckets with cinnamon or powdered sugar. The player chooses the container, picks up a scoop, scoops donuts, pours them into the container, adds the requested coating, lifts the order, and hands it to the waiting customer. The scoop stays equipped between loads. Occasional jams, rising oil temperature, and batter refills compete with service.

The challenge should come from reading orders, completing a satisfying physical sequence, maintaining stock, and choosing when to interrupt service. A wrong order should have understandable consequences and a clear recovery path. Avoid replacing the old easy tray button with a new automatic-serve button.

Version 1.0.0 provides a complete fairground campaign with six timed shifts, a queue of up to three customers, nineteen earned upgrades, two container sizes, two coatings, physical scene interactions, visible hands and tools, and local saving. Standard and Relaxed offer different pacing. Practice teaches service and fault recovery without a timer. Winning unlocks Endless Rush. Career badges and three earned stand palettes persist between runs.

## Setting and perspective

Start at a **warm fairground** with canopy fabric, wood counters, steel machinery, practical lights, nearby stalls, and a visible customer across the counter. The camera belongs to the operator. Visible arms, held tools, local object responses, and bounded look movement reinforce presence. Interaction targets must remain visible and reachable at the normal camera angle.

The **concert and stadium venues** change the environment around a familiar operating layout: crowds, music, neighboring concessions, lighting, signage, and atmosphere. Version 1.2 earns a venue and machine transition after each six-shift chapter. Keep scenery and lighting separate from order and production rules so cosmetic venue choices do not silently alter difficulty.

## Art and animation

The user's quality references are CloverPit, RACCOIN, and Bills Must Be Paid: dimensional environments and tactile machines with satisfying motion. Use these as references for presentation quality, while retaining original art, names, equipment, and a distinct donut-stand identity.

- Give the hero machine recognizable stainless surfaces, a batter hopper, frying channel, flipper, chute, bevels, fasteners, cables, and working controls.
- Give donuts browned irregular surfaces and visually distinct coatings. Make scoop contents and package fill legible.
- Give paper containers folds, printed designs, and visible depth. Use believable hands, gripping, pouring, seasoning, and handing-over animations.
- Keep the customer and active workstation readable. Warm light should reveal materials without washing them out.
- Use camera movement carefully. Preserve precise pointer targets and provide immediate reduced-motion settings.

V1 ships its authored stylized booth, textured materials, detailed original machine, irregular browned donuts, generated packaging emblems and sign, animated service actions, and dusk fairground environment. Review graphics at gameplay distance and during actual interactions, including both Windows and browser rendering.

## Reward feedback

Correct service should produce a readable earned amount, customer response, sound, and a small visual reward. Consecutive good service should escalate the lights, particles, sound, and bounded camera motion. The strongest effects must leave the next ticket and physical work area usable.

Base effects on the authoritative completed-sale receipt. Do not duplicate the reward through both a direct action and a queued event. Decorative randomness must remain separate from the seeded gameplay simulation. A visual tier must not imply an unearned payout multiplier.

Reduced motion should remove shake and disruptive movement while retaining readable outcomes. Sound, music, and motion remain independent settings.

## Historical V1 scope and current purchase boundary

The user selected a **free game with optional temporary gameplay boosts and cosmetic purchases**, then explicitly deferred all purchase and Steam integration work to **version 2** because no Steamworks account or app exists. V1 must be a finished offline game with at least one complete venue, finalized graphics and the full gameplay loop. Its venue is the fairground, structured as a six-shift campaign.

V1 has no paid store, checkout, paid entitlements, purchase prompts or usable gameplay boosts. Its equipment, badges, palettes and Endless unlock are earned by play. The dormant future-boost API is disabled. No external platform account is required.

The latest approval brings the cosmetic catalog and five earnable one-shift buffs into 1.2. Real platform checkout, receipt validation and restoration still require a configured store account. Keep run simulation and presentation independent of any future entitlement system. Do not retroactively charge for V1's earned unlocks. The concert and stadium are now part of the eighteen-shift campaign.

## Deferred gameplay ideas â€” 2026-11-04

**Status: implementation authorized by the user; included in version1.2.0.**

1. **Stand appeal and customer ratings.** Give the stand an overall appeal score
   that affects how many customers approach. If the customer currently being
   served waits a long time, their rating should suffer. Punching a customer
   should also negatively affect their rating and the stand's appeal.
2. **Accept imperfect orders with consequences.** Allow handing a bag to a
   customer who requested a bucket, or serving the wrong flavor. Award only a
   fraction of the reward for a correct order and reduce the stand's appeal.
3. **Adjustable machine production speed.** Add a player control that slows the
   machine's donut production rate.

The implementation uses appeal 0–100, customer ratings, partial payouts of25% or40%, and an independent Slow/Normal/Fast feed control. See `EXPANSION_1_2.md` for the complete approved expansion, achievements, shop, and validation limits.

## What to learn from this pivot

1. Does scooping, pouring, coating, and handing over feel good to repeat?
2. Can a new player find the correct physical objects and understand what is held?
3. Does the first shift teach a rhythm before later shifts create pressure?
4. Do maintenance and stock create worthwhile decisions rather than arbitrary interruptions?
5. Can mistakes be diagnosed and recovered from quickly?
6. Are upgrades noticeable without removing the serving loop?
7. Do successful streaks feel exciting while the next action remains readable?
8. Does the first-person booth feel dimensional and inviting at actual gameplay size?

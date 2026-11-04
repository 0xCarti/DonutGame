# Golden Hour character art

Original procedural artwork; no third-party models or textures. Regenerate with
`blender --background --python tools/unity/build_characters.py` from the repository.
Authoring `.blend` files are packaged in the `*.source.zip` archives, so Unity imports
the provided FBXs without depending on a locally installed Blender version.

## Coordinate system and assets

One authored unit is one metre. Source meshes face **Blender -Y**, with **Z** up.
FBX export uses `axis_forward='-Z'`, `axis_up='Y'`, and no baked space transform.
The intended Unity presentation frame is +Z forward / +Y up, but the final imported
root yaw must be checked in Unity. The offline scene roundtrip currently places the
customer facing the operator at yaw zero; it does not prove Unity's import transform.
Do not infer first-person hand orientation from that offline preview alone.

- `BakerHands.fbx`: camera-local root at zero. Source Blender rest palms are
  `(±0.205, -0.495, -0.245)`; the intended Unity presentation position is
  `(±0.205, -0.245, 0.495)` after the imported-root orientation is confirmed.
  Gloves are continuous manifold surfaces, with isolated
  digit weighting and stable hinge axes. Sleeves articulate at shoulder and elbow.
- `Customer_Milo.fbx`: ground origin, approximately 1.75 m tall. This is a single
  authored customer with an inset-eyed face, shaped nose, lips, eyebrows, ears,
  side-swept hair, folded overshirt collar, chest pockets, trousers, and sneakers.

Import animation as **Legacy**, preserve hierarchy, and disable mesh optimization
that removes exposed transforms. Load embedded `AnimationClip` assets, excluding
`__preview__` clips. The driver accepts Blender names such as `HandsRig|Hands_Scoop`
and simplifies them automatically.

```csharp
var driver = model.AddComponent<GoldenHour.CharacterAnimationDriver>();
driver.Configure(importedClips, true); // false for the customer
driver.PlayAction("Scoop", .55f, .08f);
heldTool.transform.SetParent(driver.Grip("R"), false);
```

`Grip()` returns a corrected tool attachment transform at the palm, with **+Z toward
the fingers and +Y toward the back of the glove**. This frame is calculated from the
wrist, middle-finger base, and palm anchor positions, so it survives FBX axis/root
rotation changes. The underlying FBX `Grip.R` / `Grip.L` bones follow
Blender bone conventions and should not be used directly for tool orientation.
The tool pivot is the player's grasp point; offset the tool geometry from that point.

## Skeleton

Hands: `Root` → `UpperArm.L/R` → `Forearm.L/R` → `Hand.L/R`.
Each hand has `Thumb`, `Index`, `Middle`, `Ring`, and `Pinky` chains, e.g.
`Index.01.R` → `Index.02.R` → `Index.03.R`, plus `Grip.L/R`.

Customer: `Root` → `Hips` → `Spine` → `Chest` → `Neck` → `Head`, with
`Shoulder.L/R`, `UpperArm.L/R`, `Forearm.L/R`, `Hand.L/R`, articulated digits,
and `Thigh.L/R` → `Shin.L/R` → `Foot.L/R`.

Optional `HandTargetIK` applies a two-bone solution after animation. Assign
`rightTarget` / `leftTarget`, optional elbow hints, and blend weights; zero weight
preserves authored animation. Targets are world-space wrist targets.

## Tool motion integration

Add `HandWorkstationDriver` to the hands root. It drives `HandTargetIK` with blended
world-space grasp targets and automatically maintains the matching left, right, or
two-handed grip pose when the action clip finishes.

```csharp
var workHands = hands.AddComponent<GoldenHour.HandWorkstationDriver>();
workHands.SetToolTarget(scoopGraspPoint, 1f, "R");
workHands.PlayToolAction("Scoop", .55f);
// While scooping, animate the scoop and its grasp child along the intended path.
// The right wrist follows that grasp point, including its rotation.

workHands.SetBimanualTargets(shakerGraspPoint, bagLeftGraspPoint);
workHands.PlayToolAction("Shake", .32f);

workHands.ClearAllTargets();  // release tools before an unconstrained punch
workHands.PlayToolAction("Punch", .25f);
```

The grasp target must be independent of the hand skeleton. A tool parented beneath
`Grip()` already follows the hand and must not also become its IK target. For world
tool motion, parent tool meshes under their own scene/presentation root and place a
grasp child at the handle. The child uses local +Z forward and +Y up in the expected
palm orientation. The driver converts that palm pose into the correct wrist pose.

Targets are clamped to 97.5% of actual upper-arm plus forearm length. No bone is
stretched. `RightTargetWithinReach` / `LeftTargetWithinReach` tell the controller
whether the requested grasp can be reached. Keep held tools within this envelope;
clear the target before releasing a bag toward a customer. Optional elbow hints can
be assigned with `SetElbowHint(hint, "R")`. `ClearToolTarget("L")` fades one hand back
to its authored animation without affecting the other.

## Authored clips

Hands: `Idle`, `Reach`, `Grip`, `GripHold`, `GripHoldLeft`, `GripHoldBoth`, `Scoop`,
`Pour`, `Shake`, `Handoff`, `PunchRapid`. `PlayAction("Punch")` aliases `PunchRapid`.

Customer: `Idle`, `Order`, `Receive`, `Happy`, `Impatient`, `ComicRecoil`.
`PlayAction("Recoil")` and `PlayAction("Backhop")` select `ComicRecoil`.
The comic recoil is a quick backward reaction and small recovery hop, with no injury.

Actions blend in and automatically return to idle. `GripHold` loops until another
action is requested. The optional duration scales clip playback speed.

## Verification

`QA_*.png` are actual Cycles renders of the generated meshes with their skin rigs
and authored animation clips. `character_manifest.json` records vertices, bones,
and clips. These renders verify authoring geometry, not Unity lighting or gameplay;
the final Unity build still needs an in-engine visual pass.

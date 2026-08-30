# 3D → Mixamo → strips pilot (archer) — runbook

Goal: one 3D mesh of the severed-thread archer, Mixamo's mocap walk on it,
rendered back into ordinary 8-direction walk strips. If the look passes, every
future animation for every character is a library pick.

Division of labour: **you do the two signups and three uploads** (accounts are
yours to create; ~10 minutes total). Everything before and after is automated
and already prepared in this folder.

## Your steps

### 1. Mesh the character (Meshy — free tier)
1. Sign up at meshy.ai (free tier includes enough credits for several meshes).
2. New task → **Image to 3D** → upload `card_front.png` **from your
   Downloads folder** (copies of the cards + PROMPT.txt live there for easy
   browsing; originals stay in this kit folder). If the result is rough,
   retry with `card_both_views.png`, or use `PROMPT.txt` in a Text-to-3D
   task instead.
3. When it finishes, download the model as **FBX** (or GLB if FBX isn't
   offered) — your normal Downloads folder is fine.
   Judge it loosely — proportions and readable gear matter; small surface
   mush is fine at our render size (she shows ~88px tall in game).

### 2. Rig + walk (Mixamo — free)
1. Sign in at mixamo.com (any free Adobe ID).
2. **Upload character** → the FBX/GLB from step 1 → follow the auto-rigger
   (place the chin/wrist/elbow/knee/groin markers on the model — one minute).
3. In the animation search, pick **"Walking"** (the plain forward walk; if it
   reads too casual, "Standard Walk" — your taste). Tick **In Place**.
4. **Download**: format FBX Binary, 30 fps, **With Skin** — let it land in
   your Downloads folder like any download; name it `archer_walk.fbx` if
   asked (or leave the default name).

### 3. Hand back
Just say the word — Claude fetches the FBX from Downloads. My side from there, fully
automated: Blender headless renders one walk loop from the 8 game camera
angles (`blender_render_strips.py`, already written), frames assemble into
429-cell strips on the family feet line, palette gets graded toward the 2D
art, and it installs into the **Archer G2D Pilot** skin's walk slots — same
A/B review setup as before: ladder GIF + in-game.

## Machine prerequisite — DONE
Blender 4.2.23 LTS installed (portable) at
`C:\Users\asali\Projects\blender\blender-4.2.23-windows-x64\blender.exe`,
headless python verified. Nothing left on the machine side.

## Cost
$0 on the free tiers for this pilot. No card required anywhere.

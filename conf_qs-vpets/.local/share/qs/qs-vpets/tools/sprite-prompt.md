# Reference images for `mksheet.sh`

Two generated images are enough for a complete pet: one **views sheet** (walk +
idle, 5 rows x 4 columns) and one **rest sheet** (sleeping / sitting poses).
`mksheet.sh` mirrors the 5 drawn views into the 8 direction rows PMD expects, so
the model never has to draw a left-facing view - which is exactly where image
models start drifting.

The views sheet is per pet, since it needs 20 cells of one character. Sleeping
has no directions and no walk cycle, so the whole pack fits in one image with a
pet per row - see [3. Pack sleep sheet](#3-pack-sleep-sheet-all-7-pets-in-one-image).

What matters in the prompt, in order of how often it goes wrong:

1. **exactly 5 rows** - the model likes to "help" by drawing all 8 compass
   directions. `--grid 5x4` over an 8-row image slices every band across two
   drawn rows and the sheet comes out with the pet facing the wrong way per
   direction. Count the rows before cutting, every time.
2. **the viewing angle is constant along a row** - columns are a walk cycle, not
   a turntable. When the model rotates the pet between columns, the pet visibly
   spins while walking in a straight line.
3. **flat, pure white background, no shadows, no ground line, no grid lines** -
   anything drawn between the cells becomes a blob the cutter has to guess about
4. **one animal per cell, fully inside it, with a clear margin** - a body drawn
   over the cell border comes out sliced flat on that side
5. **same character, same size, same palette in every cell** - one shared scale
   is computed for the whole sheet, so a single oversized cell shrinks all the
   others
6. **no text, no labels, no numbers, no frames**
7. large canvas - at least 200px per cell, ideally 400px

---

## 1. Views sheet (Walk + Idle)

Pixel art sprite sheet, 3/4 top-down view like a Game Boy Advance RPG.

Grid: exactly 5 rows and exactly 4 columns. 20 cells total, evenly spaced.
Do not draw a 6th row. Do not draw the 8 compass directions - only these 5
viewing angles. One whole animal per cell, centered, with empty margin on all
four sides: no part of the animal (ear, tail, paw) may reach the cell border.

Rows are viewing angles, always the same character, always facing right or
away - never to the left:

- row 1: front view, facing the viewer. Both eyes visible, body symmetric.
- row 2: front 3/4, the body turned 45 degrees to its right. Both eyes and the
  muzzle still visible, and one whole flank of the body is now in view.
- row 3: full right-side profile, head pointing right. One eye visible, the
  body is at its longest, no part of the chest or back facing the viewer.
- row 4: back 3/4, facing away turned 45 degrees to its right. Mostly back and
  flank, the tip of the muzzle may peek out, no eyes.
- row 5: back view, facing directly away. Only the back of the head, the back
  and the tail. No face, no eyes, no muzzle.

Columns are the 4 frames of one walking cycle, at the angle of that row and
only that angle. The camera does not move and the animal does not turn between
columns: head, body and tail keep the exact same orientation across all 4
cells of a row. Only the legs change - left legs forward, legs passing under
the body, right legs forward, legs passing - plus a 1-2 pixel up/down bob. The
legs must visibly alternate in every row, including the front and back views.

Style: chunky pixel art, thick dark outline, flat colors, limited palette of
about 10 colors, no anti-aliasing, no gradients, no blur.

Background: pure white #FFFFFF, completely flat. No drop shadows, no ground,
no grid lines, no cell borders, no text, no labels, no watermark.

Image size: 2048x2560.

Check the split before cutting anything - this is the step that catches the
8-rows-instead-of-5 failure:

```sh
# draws the grid over the source; open it and count the red bands.
# every band must hold exactly one row of animals, none cut in half
tools/mksheet.sh --src ~/Downloads/pets/views.png --grid 5x4 --inspect
```

If the model drew 8 rows anyway and rows 1-5 are the right angles, the image is
still usable - cut it as 8 and keep the first five, since rows 6-8 are the
left-facing ones the model gets wrong:

```sh
tools/mksheet.sh --src ~/Downloads/pets/views.png --out assets/sprites/rex \
    --name Walk --grid 8x4 --pick 1,2,3,4,5 --mirror --durations 3,3,3,3 --preview
```

Otherwise:

```sh
# walk: 4 frames per direction, expanded to the 8 PMD rows
tools/mksheet.sh --src ~/Downloads/pets/views.png --out assets/sprites/rex \
    --name Walk --grid 5x4 --mirror --durations 3,3,3,3 --preview

# idle: reuse the two contact poses of the walk cycle as a breathing loop.
# only works if the row kept one angle - check frames 1 and 3 of row 1 first
tools/mksheet.sh --src ~/Downloads/pets/views.png --out assets/sprites/rex \
    --name Idle --grid 5x4 --take 1,3 --mirror --durations 16,6 --preview
```

## 2. Rest sheet (Sleep, and Sit if you want one)

> Pixel art sprite sheet of the same **[golden retriever puppy]**, identical
> style, palette and outline as before.
>
> Grid: exactly 2 rows and exactly 2 columns, 4 cells total, evenly spaced. One
> animal per cell, centered, with empty margin on all four sides: no part of the
> animal may reach the cell border.
>
> - row 1: the puppy curled up asleep, seen from the side, eyes closed. Column 1
>   breathing in (body slightly expanded), column 2 breathing out. Same pose and
>   same angle in both cells - only the body volume changes.
> - row 2: the puppy sitting, facing the viewer. Column 1 still, column 2 with
>   the head tilted slightly. Same pose and same angle in both cells.
>
> Same rules: pure white #FFFFFF background, no shadows, no ground, no grid
> lines, no text. Chunky pixel art, thick dark outline, flat colors, no
> anti-aliasing.
>
> Image size: 1600x1600.

Then (lying poses are wider than a walking frame, so they get a 48px frame -
`SpriteAnimation.qml` scales every frame against a 32px base, so a 48px frame
simply renders 1.5x bigger):

```sh
tools/mksheet.sh --src ~/Downloads/pets/rest.png --out assets/sprites/rex \
    --name Sleep --grid 2xauto --pick 1 --frame 48x48 --durations 40,40 --preview

tools/mksheet.sh --src ~/Downloads/pets/rest.png --out assets/sprites/rex \
    --name Sit --grid 2xauto --pick 2 --frame 48x48 --durations 20,20 --preview
```

`Sleep` and `Sit` are single-row on purpose: `SpriteAnimation.qml` forces
`_dirRow = 0` for them, and they back the `sit`, `sitDown` and `deepsleep`
fallbacks.

## 3. Pack sleep sheet (all 7 pets in one image)

Sleeping is the one animation with no direction rows and no walk cycle, so the
whole pack fits in a single image: one pet per row, two breathing frames per
row. `--out` takes the 7 pack directories and writes one `Sleep-Anim.png` into
each in a single run.

Pin each pet by description, not by position - the row order below is the same
order passed to `--out`, and that mapping is the only thing holding the sheet
together:

Pixel art sprite sheet of 7 different sleeping pets, chunky pixel art, thick
dark outline, flat colors, limited palette, no anti-aliasing, no gradients, no
blur.

Grid: exactly 7 rows and exactly 2 columns. 14 cells total, evenly spaced.
Do not add an 8th row, do not merge rows, do not leave a row empty. One animal
per cell, centered, with empty margin on all four sides: no part of the animal
(ear, tail, paw) may reach the cell border.

Every animal is curled up asleep, lying on the ground, seen from the side, eyes
closed, head resting on or near its front paws. The two columns of a row are
the same pet in the same pose at the same angle - column 1 breathing in, body
slightly expanded, column 2 breathing out, body slightly compressed. Nothing
else changes between the two columns: no head turn, no leg move, no mirroring.

Each row is a different animal, always in this order:

- row 1: a brown puppy with a cream chest and floppy ears
- row 2: a reddish-brown chihuahua with large pointed ears and a white chest
- row 3: a black-and-tan chihuahua with large pointed ears, white chest and tan paws
- row 4: a short-legged black-and-tan dog with a tan muzzle and tan paws
- row 5: a siamese cat, cream body with dark brown face, ears, paws and tail
- row 6: a long-haired black cat
- row 7: a golden retriever puppy, golden yellow with floppy ears

Background: pure white #FFFFFF, completely flat. No drop shadows, no ground,
no grid lines, no cell borders, no text, no labels, no watermark.

Image size: 1024x2048.

Count the rows before cutting - 7 rows is where this one goes wrong, the same
way 5 rows does on the views sheet:

```sh
tools/mksheet.sh --src ~/Downloads/pets/sleep.png --grid 7x2 --inspect
```

Then one command for the whole pack. The `--out` list and `--pick` list are
positional: the Nth directory gets the Nth picked row, so keep them in the same
order as the rows in the prompt.

```sh
tools/mksheet.sh --src ~/Downloads/pets/sleep.png --name Sleep \
    --grid 7x2 --pick 1,2,3,4,5,6,7 --frame 48x48 --durations 40,40 --preview \
    --out assets/sprites/belo,assets/sprites/billy,assets/sprites/gisele,assets/sprites/guerreiro,assets/sprites/kitty,assets/sprites/lua,assets/sprites/sandy
```

Each pet gets its own scale, so every one of them fills its own 48px frame -
the pack sheet does not make a chihuahua smaller than a retriever. Previews are
written per pack (`/tmp/mksheet-<pack>-Sleep-preview.png`), so all 7 survive the
run. Redoing a single pet later is the normal single-directory form with the
row it sits on:

```sh
tools/mksheet.sh --src ~/Downloads/pets/sleep.png --out assets/sprites/lua \
    --name Sleep --grid 7x2 --pick 6 --frame 48x48 --durations 40,40 --preview
```

---

## When the output looks wrong

| symptom                                        | fix                                                                                                                          |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| walking right shows the back / the wrong view  | the source has more (or fewer) rows than `--grid` says - `--inspect` and count the bands, then `--grid 8x4 --pick 1,2,3,4,5` |
| the pet turns while walking in a straight line | the model rotated the character between columns - regenerate, the row must keep one angle                                    |
| a frame is sliced flat on one side             | the animal was drawn over the cell border - regenerate that image, `--inset` cannot recover it                               |
| the pet slides without moving its legs         | the model repeated one pose across the 4 columns - regenerate                                                                |
| sprite sizes jump between directions           | the model drew them at different sizes - `--align each` (default) can't fix scale, regenerate or crop that row apart         |
| a stray line or speck rides along              | `--min-blob 0.3`, or `--inset 6` if it is a grid line at the cell edge                                                       |
| edges keep a light halo                        | `--fuzz 25%` (background tolerance) and `--colors 32`                                                                        |
| pet floats above the floor                     | that frame's lowest pixel is a shadow blob the model drew - raise `--min-blob`                                               |
| pet is cut off                                 | the model drew it touching the cell edge - regenerate that image                                                             |
| `--grid RxauTo` finds too many frames          | `--take 1,2` picks the ones you want, in order                                                                               |

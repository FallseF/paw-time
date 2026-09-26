# Garden sprite prompts

Generated with the built-in `image_gen` tool. Exported to 768 x 768 RGBA PNG after removing faint alpha residue and normalizing flat color fills; smooth antialiasing is retained along the edges. Palettes: white and black, plus straw yellow (#E9C65B) and wood brown (#9B733F) for kakashi, red (#E72B35) for jizo, and navy (#213867) for nebukuro.

## kakashi.png

Use case: stylized-concept.
Asset type: one standalone transparent PNG garden decoration sprite for a Godot game, square canvas, preferably 768 x 768 pixels.
Style: The Battle Cats (にゃんこ大戦争) deadpan absurd simplicity, matching small sheet-ghost characters with pure white bodies, tiny widely spaced solid black dot eyes and a very short single straight horizontal black mouth. Thick EVEN black ink outlines, same weight on the silhouette and major seams. Clean flat solid colors. Humor comes only from the deadpan silhouette. No big eyes, no begging expression, no smiles, no blush, no glossy highlights, no sparkle, no gradients, no texture, no shading.
Composition: a SINGLE isolated subject centered horizontally, its physical base in the lower part of the square at about 85% canvas height; keep generous empty transparent margins above, on both sides and below, with all outlines fully contained. The sprite must be legible at small game scale.
Background: real transparent alpha channel in a PNG, RGBA. Every pixel outside the subject must have alpha 0. In particular all corners and outer edges must be completely transparent. Do NOT draw a checkerboard, background color, floor, ground line, ground shadow, cast shadow, halo, glow or scenery.
No labels, watermarks, borders or text, except where explicitly specified below.
Subject: a white sheet-ghost in the shape of a scarecrow, mounted on ONE vertical wooden pole. Its short simple arms stick straight out to both sides in a deadpan T pose. It wears a broad simple straw hat in one flat straw-yellow accent; minimal black marks may suggest the straw, but no texture or hatching. Under the hat it has two TINY round black dot eyes and one short straight line mouth, utterly expressionless. Simple white scalloped hem above the pole. The pole is straight, simple and flat muted wood-brown, ending visibly at the base with NO mound or grass. Pure white, black, straw yellow, and muted brown are the entire palette: only these two small accent colors. One ghost only. Fit the whole silhouette including hat, arms and pole inside the margins.

Final color cleanup prompt:

Use case: precise-object-edit.
Input image: edit target, the attached garden sprite.
Make a STRICT FLAT-COLOR cleanup of this exact sprite, maintaining its character design, deadpan expression, silhouette, thick even black ink outlines, horizontal centering and generous transparent margins.
Change only the color rendering and alpha cleanliness. Retain the one vertical pole, the arms-out silhouette, straw hat, tiny dot eyes, and straight mouth.
Paint-bucket / vector-style flat areas only: hat = uniform straw yellow #E9C65B; wooden supports = uniform muted brown #9B733F; white ghost body = #FFFFFF; all ink = #000000. Each filled region must be a single perfectly uniform RGB color. Remove ALL visible mottling, grain, texture, color variation, gradients, shading, highlights and shadows. No paper texture or lighting model. A crisp simple cel icon in the absurd deadpan The Battle Cats style.
PNG RGBA with actual transparent background. Character interiors and ink are fully opaque (alpha 255). Outside the subject everything must be alpha 0: no faint residue, haze or isolated translucent specks. Keep clean antialiasing only immediately at silhouette boundaries. All four corners and generous outer margins remain alpha 0. No ground shadow, no floor line, no background, no checkerboard. Preserve the square canvas.

## jizo.png

Use case: stylized-concept.
Asset type: one standalone transparent PNG garden decoration sprite for a Godot game, square canvas, preferably 768 x 768 pixels.
Style: The Battle Cats (にゃんこ大戦争) deadpan absurd simplicity, matching small sheet-ghost characters with pure white bodies, tiny widely spaced solid black dot eyes and a very short single straight horizontal black mouth. Thick EVEN black ink outlines, same weight on the silhouette and major seams. Clean flat solid colors. Humor comes only from the deadpan silhouette. No big eyes, no begging expression, no smiles, no blush, no glossy highlights, no sparkle, no gradients, no texture, no shading.
Composition: a SINGLE isolated subject centered horizontally, its physical base in the lower part of the square at about 85% canvas height; keep generous empty transparent margins above, on both sides and below, with all outlines fully contained. The sprite must be legible at small game scale.
Background: real transparent alpha channel in a PNG, RGBA. Every pixel outside the subject must have alpha 0. In particular all corners and outer edges must be completely transparent. Do NOT draw a checkerboard, background color, floor, ground line, ground shadow, cast shadow, halo, glow or scenery.
No labels, watermarks, borders or text, except where explicitly specified below.
Subject: a small round WHITE ghost sitting calmly like a Japanese roadside jizo statue. Soft round head continuing into a squat white body, tiny simple folded hands and rounded seated base, white material rather than gray stone. A simple vivid flat RED cloth bib hangs on the chest, with a black outline and no decoration. Its eyes are CLOSED as two tiny straight horizontal black lines, and its mouth is one tiny straight horizontal line, completely calm and expressionless. No nose, ears, hair, hat or stone pedestal. Only white, black and one solid red accent. Single ghost only. Fully transparent beneath the rounded seated base, no ground shadow. The entire compact figure stays centered with large clear transparent margins.

Final color cleanup prompt:

Use case: precise-object-edit.
Input image: edit target, the attached garden sprite.
Make a STRICT FLAT-COLOR cleanup of this exact sprite, maintaining its character design, deadpan expression, silhouette, thick even black ink outlines, horizontal centering and generous transparent margins.
Change only the color rendering and alpha cleanliness. Retain the seated small round jizo ghost, folded hands, red bib, closed line eyes and straight mouth.
Paint-bucket / vector-style flat areas only: bib = uniform solid red #E72B35; entire white ghost = #FFFFFF; all ink = #000000. Each filled region must be a single perfectly uniform RGB color. Remove ALL visible mottling, grain, texture, color variation, gradients, shading, highlights and shadows. No paper texture or lighting model. A crisp simple cel icon in the absurd deadpan The Battle Cats style.
PNG RGBA with actual transparent background. Character interiors and ink are fully opaque (alpha 255). Outside the subject everything must be alpha 0: no faint residue, haze or isolated translucent specks. Keep clean antialiasing only immediately at silhouette boundaries. All four corners and generous outer margins remain alpha 0. No ground shadow, no floor line, no background, no checkerboard. Preserve the square canvas.

## nebukuro.png

Use case: stylized-concept.
Asset type: one standalone transparent PNG garden decoration sprite for a Godot game, square canvas, preferably 768 x 768 pixels.
Style: The Battle Cats (にゃんこ大戦争) deadpan absurd simplicity, matching small sheet-ghost characters with pure white bodies, tiny widely spaced solid black dot eyes and a very short single straight horizontal black mouth. Thick EVEN black ink outlines, same weight on the silhouette and major seams. Clean flat solid colors. Humor comes only from the deadpan silhouette. No big eyes, no begging expression, no smiles, no blush, no glossy highlights, no sparkle, no gradients, no texture, no shading.
Composition: a SINGLE isolated subject centered horizontally, its physical base in the lower part of the square at about 85% canvas height; keep generous empty transparent margins above, on both sides and below, with all outlines fully contained. The sprite must be legible at small game scale.
Background: real transparent alpha channel in a PNG, RGBA. Every pixel outside the subject must have alpha 0. In particular all corners and outer edges must be completely transparent. Do NOT draw a checkerboard, background color, floor, ground line, ground shadow, cast shadow, halo, glow or scenery.
No labels, watermarks, borders or text, except where explicitly specified below.
Subject: a white ghost zipped up to its FACE inside ONE navy-blue sleeping bag lying horizontally on the ground, shown in a simple side / slight three-quarter view. The head at the left end is a rounded white ghost face emerging only through the close-fitting bag opening; two TINY OPEN black dot eyes and a single short straight horizontal line mouth stare blankly ahead. The bag extends horizontally to the right with a round closed foot end and is one SOLID flat navy-blue accent, no quilts, no inner shadows, no highlights. One minimal black zipper seam and tiny simple zipper pull show it is zipped all the way up to the face. NO hat, pillow, bed, bedroll spiral or blanket. A single very small handwritten lowercase black "z" floats just above the face. This one lowercase z is the ONLY text. The physical bottom of the horizontal bag is near 85% canvas height, with lots of transparent space above; keep the entire bag, face and z well inside the square. Only pure white, black and solid navy blue. No floor marks or shadows.

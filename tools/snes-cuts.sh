#!/bin/bash
# Re-cut every SNES sheet, with the settings each one actually needs.
#
#   ./tools/snes-cuts.sh              all of them
#   ./tools/snes-cuts.sh kirby leo    just those
#
# The Mega Drive sheets could be cut with one command each and mostly one set of
# flags. These cannot, and the settings are not guessable from the character —
# they are properties of how that particular sheet was drawn and rasterised. So
# they live here rather than in somebody's shell history, because the frame
# numbering is the interface `catalog.py` writes against: re-cut a sheet with
# different flags and every range authored for it silently points somewhere else.
#
# What the flags mean, and why they differ:
#
#   --gap    Dilation before labelling. 3 rejoins a sprite's detached parts;
#            1 does nothing at all. Turtles in Time needs both — see
#            docs/snes-buddies.md. Even values round up: the kernel must be odd.
#   --keys   Background and chrome colours. `auto` with `--chrome 1.0` takes the
#            single dominant colour, which is right for a plain sheet. A boxed
#            sheet needs its panel fills and caption bars listed explicitly, or
#            the borders weld every frame together.
#   --max    Drop components larger than this. Not a size filter on sprites —
#            a component that big is several frames joined by chrome that should
#            have been keyed, and it would otherwise set the shared canvas.
#
# Frames are left whole. `build.sh` copies only the ones the animations name, so
# the repository keeps the rest for the next time a clip needs widening.
set -euo pipefail
cd "$(dirname "$0")/.."

cut() {  # cut <id> <sheet basename> <flags...>
    local id=$1 sheet=$2; shift 2
    [ -f "assets/snes/$sheet.png" ] || { echo "  $id: no assets/snes/$sheet.png, skipping"; return; }
    python3 tools/blobs.py "$id" "assets/snes/$sheet.png" "$@"
}

want=("$@")
run() { [ ${#want[@]} -eq 0 ] || [[ " ${want[*]} " == *" $1 "* ]]; }

# Plain sheets: one flat background colour, sprites well separated.
run kirby    && cut kirby    kirby    --gap 3 --chrome 1.0 --max 60
run squawks  && cut squawks  squawks  --gap 3 --chrome 1.0 --max 60
run metroid  && cut metroid  metroid  --gap 3 --chrome 1.0 --max 90
run megamanx && cut megamanx megamanx --gap 3 --chrome 1.0 --max 90
run diddy    && cut diddy    diddy    --gap 3 --chrome 1.0 --max 90
run dixie    && cut dixie    dixie    --gap 3 --chrome 1.0 --max 90
run simon    && cut simon    simon    --gap 3 --chrome 1.0 --max 90
run jimworm  && cut jimworm  jim      --gap 3 --chrome 1.0 --max 90
run dk       && cut dk       dk       --gap 3 --chrome 1.0 --max 130
run guy      && cut guy      guy      --gap 3 --chrome 1.0 --max 110
run richter  && cut richter  richter  --gap 3 --chrome 1.0 --max 110
run ewj      && cut ewj      ewj      --gap 3 --chrome 1.0 --max 110
run mikey    && cut mikey    mikey    --gap 3 --chrome 1.0 --max 110

# Boxed sheets: every frame drawn inside a panel, so the panel colours have to
# be keyed too or the borders join the whole image into one component.
run mario  && cut mario  mario  --keys "0,148,148;0,84,84;0,116,116;0,52,52" --gap 3 --max 90
run luigi  && cut luigi  luigi  --keys "0,148,148;0,84,84;0,116,116;0,52,52" --gap 3 --max 90
run samus  && cut samus  samus  --keys "230,164,244;192,128,246;30,144,255"  --gap 3 --max 80

# Pac-Man is boxed *and* tightly packed: with the box colours gone, dilation
# reaches across where the border was and joins whole rows. 213 frames at gap 3,
# most of them two or three Pac-Men wide; 1,426 clean ones at gap 1.
run pacman && cut pacman pacman --keys "0,128,255;0,84,168" --gap 1 --max 60

# Turtles in Time. Leonardo, Raphael and Donatello have neighbouring frames close
# enough that dilation welds them, so they take no dilation at all. Michelangelo
# is cut at 3 above, because at 1 his nunchucks come off as eleven splinters.
run leo    && cut leo    leo    --gap 1 --chrome 1.0 --max 110
run raph   && cut raph   raph   --gap 1 --chrome 1.0 --max 110
run donnie && cut donnie donnie --gap 1 --chrome 1.0 --max 110

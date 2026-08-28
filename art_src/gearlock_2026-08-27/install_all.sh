#!/bin/bash
# gearlock 2026-08-27 install map -- run per stage AFTER visually vetting its row.
# W-side facings install as mirrors of E (quadrant scheme, symmetric-base ruling).
# install_row_strip.py backs up each target then unlinks it itself before
# saving (the PIL Errno-22 overwrite quirk) -- do NOT rm targets here, that
# defeats the backup.
set -e
cd "$(dirname "$0")/../.."
SP=game/assets/sprites
ST=art_src/gearlock_2026-08-27
BK=$ST/replaced
I="python tools/art/install_row_strip.py"

stage=$1
case "$stage" in
pal_walk_s)

  $I --row $ST/pal_walk_s/pal_walk_s_row.png --old $BK/paladin_walk_s.png --frames 8 \
     --out $SP/paladin_walk_s.png --out $SP/paladin_walk.png --backup-dir $BK ;;
pal_walk_e)

  $I --row $ST/pal_walk_e/pal_walk_e_row.png --old $ST/pal_walk_e/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK ;;
pal_walk_n)

  $I --row $ST/pal_walk_n/pal_walk_n_row.png --old $ST/pal_walk_n/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_n.png --backup-dir $BK ;;
archer_idle_s)

  $I --row $ST/archer_idle_s/archer_idle_s_row.png --old $ST/archer_idle_s/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_s.png --out $SP/archer_anim.png --backup-dir $BK ;;
archer_idle_e)

  $I --row $ST/archer_idle_e/archer_idle_e_row.png --old $ST/archer_idle_e/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_e.png --out $SP/archer_anim_se.png --out $SP/archer_anim_ne.png \
     --mirror-out $SP/archer_anim_w.png --mirror-out $SP/archer_anim_sw.png \
     --mirror-out $SP/archer_anim_nw.png --backup-dir $BK ;;
archer_idle_n)

  $I --row $ST/archer_idle_n/archer_idle_n_row.png --old $ST/archer_idle_n/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_n.png --backup-dir $BK ;;
sin_throw_s)

  $I --row $ST/sin_throw_s/sin_throw_s_row.png --old $ST/sin_throw_s/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_s.png --out $SP/assassin_attack2.png --backup-dir $BK ;;
sin_throw_e)

  $I --row $ST/sin_throw_e/sin_throw_e_row.png --old $ST/sin_throw_e/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_e.png --out $SP/assassin_attack2_se.png \
     --out $SP/assassin_attack2_ne.png --mirror-out $SP/assassin_attack2_w.png \
     --mirror-out $SP/assassin_attack2_sw.png --mirror-out $SP/assassin_attack2_nw.png --backup-dir $BK ;;
sin_throw_n)

  $I --row $ST/sin_throw_n/sin_throw_n_row.png --old $ST/sin_throw_n/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_n.png --backup-dir $BK ;;
pal_walk_e2)

  $I --row $ST/pal_walk_e2/pal_walk_e2_row.png --old $ST/pal_walk_e2/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_s)

  $I --row $ST/archer_walk_s/archer_walk_s_row.png --old $ST/archer_walk_s/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_s.png --out $SP/archer_walk.png --backup-dir $BK/round2 ;;
archer_walk_e)

  $I --row $ST/archer_walk_e/archer_walk_e_row.png --old $ST/archer_walk_e/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_e.png --out $SP/archer_walk_se.png --out $SP/archer_walk_ne.png \
     --mirror-out $SP/archer_walk_w.png --mirror-out $SP/archer_walk_sw.png \
     --mirror-out $SP/archer_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_e2)

  $I --row $ST/archer_walk_e2/archer_walk_e2_row.png --old $ST/archer_walk_e/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_e.png --out $SP/archer_walk_se.png --out $SP/archer_walk_ne.png \
     --mirror-out $SP/archer_walk_w.png --mirror-out $SP/archer_walk_sw.png \
     --mirror-out $SP/archer_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_n)

  $I --row $ST/archer_walk_n/archer_walk_n_row.png --old $ST/archer_walk_n/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_n.png --backup-dir $BK/round2 ;;
pal_walk_e3)

  $I --row $ST/pal_walk_e3/pal_walk_e3_row.png --old $ST/pal_walk_e3/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK/round3 ;;
pal_walk_n2)

  $I --row $ST/pal_walk_n2/pal_walk_n2_row.png --old $ST/pal_walk_n2/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_n.png --backup-dir $BK/round3 ;;
archer_walk_n2)

  $I --row $ST/archer_walk_n2/archer_walk_n2_row.png --old $ST/archer_walk_n2/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_n.png --backup-dir $BK/round3 ;;
archer_walk_n3)

  $I --row $ST/archer_walk_n3/archer_walk_n3_row.png --old $ST/archer_walk_n2/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_n.png --backup-dir $BK/round4 ;;
archer_dash_s)

  $I --row $ST/archer_dash_s/archer_dash_s_row.png --old $ST/archer_dash_s/refs/ref1_dash.png --frames 6 \
     --out $SP/archer_dash_s.png --out $SP/archer_dash.png --backup-dir $BK/round4 ;;
archer_dash_e)

  $I --row $ST/archer_dash_e/archer_dash_e_row.png --old $ST/archer_dash_e/refs/ref1_dash.png --frames 6 \
     --out $SP/archer_dash_e.png --out $SP/archer_dash_se.png --out $SP/archer_dash_ne.png \
     --mirror-out $SP/archer_dash_w.png --mirror-out $SP/archer_dash_sw.png \
     --mirror-out $SP/archer_dash_nw.png --backup-dir $BK/round4 ;;
archer_dash_n)

  $I --row $ST/archer_dash_n/archer_dash_n_row.png --old $ST/archer_dash_n/refs/ref1_dash.png --frames 6 \
     --out $SP/archer_dash_n.png --backup-dir $BK/round4 ;;
*) echo "unknown stage: $stage"; exit 1 ;;
esac

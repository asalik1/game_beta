#!/bin/bash
# gearlock 2026-08-27 install map -- run per stage AFTER visually vetting its row.
# W-side facings install as mirrors of E (quadrant scheme, symmetric-base ruling).
# Targets are rm'd first: PIL save() over the exact existing name can throw
# Errno 22 on this box (CODEX_HEADLESS.md section 9).
set -e
cd "$(dirname "$0")/../.."
SP=game/assets/sprites
ST=art_src/gearlock_2026-08-27
BK=$ST/replaced
I="python tools/art/install_row_strip.py"

stage=$1
case "$stage" in
pal_walk_s)
  rm -f $SP/paladin_walk_s.png $SP/paladin_walk.png
  $I --row $ST/pal_walk_s/pal_walk_s_row.png --old $BK/paladin_walk_s.png --frames 8 \
     --out $SP/paladin_walk_s.png --out $SP/paladin_walk.png --backup-dir $BK ;;
pal_walk_e)
  rm -f $SP/paladin_walk_e.png $SP/paladin_walk_se.png $SP/paladin_walk_ne.png \
        $SP/paladin_walk_w.png $SP/paladin_walk_sw.png $SP/paladin_walk_nw.png
  $I --row $ST/pal_walk_e/pal_walk_e_row.png --old $ST/pal_walk_e/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK ;;
pal_walk_n)
  rm -f $SP/paladin_walk_n.png
  $I --row $ST/pal_walk_n/pal_walk_n_row.png --old $ST/pal_walk_n/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_n.png --backup-dir $BK ;;
archer_idle_s)
  rm -f $SP/archer_anim_s.png $SP/archer_anim.png
  $I --row $ST/archer_idle_s/archer_idle_s_row.png --old $ST/archer_idle_s/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_s.png --out $SP/archer_anim.png --backup-dir $BK ;;
archer_idle_e)
  rm -f $SP/archer_anim_e.png $SP/archer_anim_se.png $SP/archer_anim_ne.png \
        $SP/archer_anim_w.png $SP/archer_anim_sw.png $SP/archer_anim_nw.png
  $I --row $ST/archer_idle_e/archer_idle_e_row.png --old $ST/archer_idle_e/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_e.png --out $SP/archer_anim_se.png --out $SP/archer_anim_ne.png \
     --mirror-out $SP/archer_anim_w.png --mirror-out $SP/archer_anim_sw.png \
     --mirror-out $SP/archer_anim_nw.png --backup-dir $BK ;;
archer_idle_n)
  rm -f $SP/archer_anim_n.png
  $I --row $ST/archer_idle_n/archer_idle_n_row.png --old $ST/archer_idle_n/refs/ref1_idle.png --frames 4 \
     --out $SP/archer_anim_n.png --backup-dir $BK ;;
sin_throw_s)
  rm -f $SP/assassin_attack2_s.png $SP/assassin_attack2.png
  $I --row $ST/sin_throw_s/sin_throw_s_row.png --old $ST/sin_throw_s/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_s.png --out $SP/assassin_attack2.png --backup-dir $BK ;;
sin_throw_e)
  rm -f $SP/assassin_attack2_e.png $SP/assassin_attack2_se.png $SP/assassin_attack2_ne.png \
        $SP/assassin_attack2_w.png $SP/assassin_attack2_sw.png $SP/assassin_attack2_nw.png
  $I --row $ST/sin_throw_e/sin_throw_e_row.png --old $ST/sin_throw_e/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_e.png --out $SP/assassin_attack2_se.png \
     --out $SP/assassin_attack2_ne.png --mirror-out $SP/assassin_attack2_w.png \
     --mirror-out $SP/assassin_attack2_sw.png --mirror-out $SP/assassin_attack2_nw.png --backup-dir $BK ;;
sin_throw_n)
  rm -f $SP/assassin_attack2_n.png
  $I --row $ST/sin_throw_n/sin_throw_n_row.png --old $ST/sin_throw_n/refs/ref2_old_throw.png --frames 8 \
     --seat uniform --out $SP/assassin_attack2_n.png --backup-dir $BK ;;
pal_walk_e2)
  rm -f $SP/paladin_walk_e.png $SP/paladin_walk_se.png $SP/paladin_walk_ne.png \
        $SP/paladin_walk_w.png $SP/paladin_walk_sw.png $SP/paladin_walk_nw.png
  $I --row $ST/pal_walk_e2/pal_walk_e2_row.png --old $ST/pal_walk_e2/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_s)
  rm -f $SP/archer_walk_s.png $SP/archer_walk.png
  $I --row $ST/archer_walk_s/archer_walk_s_row.png --old $ST/archer_walk_s/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_s.png --out $SP/archer_walk.png --backup-dir $BK/round2 ;;
archer_walk_e)
  rm -f $SP/archer_walk_e.png $SP/archer_walk_se.png $SP/archer_walk_ne.png \
        $SP/archer_walk_w.png $SP/archer_walk_sw.png $SP/archer_walk_nw.png
  $I --row $ST/archer_walk_e/archer_walk_e_row.png --old $ST/archer_walk_e/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_e.png --out $SP/archer_walk_se.png --out $SP/archer_walk_ne.png \
     --mirror-out $SP/archer_walk_w.png --mirror-out $SP/archer_walk_sw.png \
     --mirror-out $SP/archer_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_e2)
  rm -f $SP/archer_walk_e.png $SP/archer_walk_se.png $SP/archer_walk_ne.png \
        $SP/archer_walk_w.png $SP/archer_walk_sw.png $SP/archer_walk_nw.png
  $I --row $ST/archer_walk_e2/archer_walk_e2_row.png --old $ST/archer_walk_e/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_e.png --out $SP/archer_walk_se.png --out $SP/archer_walk_ne.png \
     --mirror-out $SP/archer_walk_w.png --mirror-out $SP/archer_walk_sw.png \
     --mirror-out $SP/archer_walk_nw.png --backup-dir $BK/round2 ;;
archer_walk_n)
  rm -f $SP/archer_walk_n.png
  $I --row $ST/archer_walk_n/archer_walk_n_row.png --old $ST/archer_walk_n/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_n.png --backup-dir $BK/round2 ;;
pal_walk_e3)
  rm -f $SP/paladin_walk_e.png $SP/paladin_walk_se.png $SP/paladin_walk_ne.png \
        $SP/paladin_walk_w.png $SP/paladin_walk_sw.png $SP/paladin_walk_nw.png
  $I --row $ST/pal_walk_e3/pal_walk_e3_row.png --old $ST/pal_walk_e3/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_e.png --out $SP/paladin_walk_se.png --out $SP/paladin_walk_ne.png \
     --mirror-out $SP/paladin_walk_w.png --mirror-out $SP/paladin_walk_sw.png \
     --mirror-out $SP/paladin_walk_nw.png --backup-dir $BK/round3 ;;
pal_walk_n2)
  rm -f $SP/paladin_walk_n.png
  $I --row $ST/pal_walk_n2/pal_walk_n2_row.png --old $ST/pal_walk_n2/refs/ref1_walk.png --frames 8 \
     --out $SP/paladin_walk_n.png --backup-dir $BK/round3 ;;
archer_walk_n2)
  rm -f $SP/archer_walk_n.png
  $I --row $ST/archer_walk_n2/archer_walk_n2_row.png --old $ST/archer_walk_n2/refs/ref1_walk.png --frames 6 \
     --out $SP/archer_walk_n.png --backup-dir $BK/round3 ;;
*) echo "unknown stage: $stage"; exit 1 ;;
esac

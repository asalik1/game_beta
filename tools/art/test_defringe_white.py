"""RGB-only defringe safety contracts; fixtures stay inside this checkout."""

import sys, unittest, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'art'))
import defringe_white as d
TEMP_ROOT = Path(__file__).resolve().parents[2] / 'build/qa/t57/tests'
TEMP_ROOT.mkdir(parents=True, exist_ok=True)

class WhiteDefringeTests(unittest.TestCase):

    def sprite(self):
        a = np.zeros((40, 40, 4), dtype=np.uint8)
        a[5:35, 5:35] = [240, 240, 240, 120]
        a[7:33, 7:33] = [30, 65, 50, 255]
        return a

    def test_alpha_opaque_and_idempotence(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            p = Path(folder) / 'tree.png'
            a = self.sprite()
            Image.fromarray(a).save(p)
            self.assertEqual(d.measure(p)['verdict'], 'HALO')
            self.assertGreater(d.defringe(p, True)['changed'], 0)
            b = np.array(Image.open(p))
            self.assertTrue(np.array_equal(a[:, :, 3], b[:, :, 3]))
            self.assertTrue(np.array_equal(a[a[:, :, 3] == 255], b[a[:, :, 3] == 255]))
            old = p.read_bytes()
            self.assertEqual(d.defringe(p, True)['changed'], 0)
            self.assertEqual(old, p.read_bytes())
            self.assertEqual(list(b[5, 5, :3]), [30, 65, 50])
            self.assertEqual(list(b[4, 7, :3]), [30, 65, 50])

    def test_refuses_snow_and_blossom_content(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            p = Path(folder) / 'snow.png'
            a = self.sprite()
            a[8:32, 8:32, :3] = 245
            Image.fromarray(a).save(p)
            old = p.read_bytes()
            self.assertEqual(d.measure(p)['verdict'], 'content')
            self.assertEqual(d.defringe(p, True)['changed'], 0)
            self.assertEqual(old, p.read_bytes())

    def test_empty_and_translucent_no_donors(self):
        for alpha in [0, 120]:
            a = np.full((40, 40, 4), 240, dtype=np.uint8)
            a[:, :, 3] = alpha
            m, b = d.inspect_cell(a, True)
            self.assertEqual(m['changed'], 0)
            self.assertTrue(np.array_equal(a, b))

    def test_animation_donors_stay_in_cell(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            root = Path(folder)
            a = self.sprite()
            b = self.sprite()
            b[b[:, :, 3] == 255, :3] = [110, 20, 30]
            Image.fromarray(a).save(root / 'tree.png')
            p = root / 'tree_anim.png'
            Image.fromarray(np.concatenate([a, b], axis=1)).save(p)
            self.assertEqual(len(d.cells(p, 80, 40)), 2)
            d.defringe(p, True)
            out = np.array(Image.open(p))
            self.assertEqual(list(out[5, 5, :3]), [30, 65, 50])
            self.assertEqual(list(out[5, 45, :3]), [110, 20, 30])

    def test_protected_skin_refused(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            root = Path(folder) / 'skins'
            root.mkdir()
            p = root / 'skin.png'
            Image.fromarray(self.sprite()).save(p)
            old = p.read_bytes()
            self.assertTrue(d.defringe(p, True)['protected'])
            self.assertEqual(old, p.read_bytes())

    def test_mixed_strip_refused_without_partial_write(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            root = Path(folder)
            halo = self.sprite()
            snow = self.sprite()
            snow[8:32, 8:32, :3] = 245
            Image.fromarray(halo).save(root / 'tree.png')
            p = root / 'tree_anim.png'
            Image.fromarray(np.concatenate([halo, halo, halo, snow], axis=1)).save(p)
            old = p.read_bytes()
            self.assertEqual(d.defringe(p, True)['verdict'], 'content')
            self.assertEqual(old, p.read_bytes())

    def test_dry_run_preserves_file(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            p = Path(folder) / 'tree.png'
            Image.fromarray(self.sprite()).save(p)
            old = p.read_bytes()
            self.assertGreater(d.defringe(p)['changed'], 0)
            self.assertEqual(old, p.read_bytes())
if __name__ == '__main__':
    unittest.main()

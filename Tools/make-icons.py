#!/usr/bin/env python3
"""Writes the library's symbolic icons to Resources/: share, email, copy,
save, folder, open, cloud (24x24) and file, text (48x48), named <name>-symbolic.png so
themes that tint template images draw them in the colour of the text around
them. Only the shape (alpha) matters. Needs python3-cairo."""

import math
import os

import cairo

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources")
W = 2.0


def fill(cr, x, y, w, h):
    cr.rectangle(x, y, w, h)
    cr.fill()


def triangle(cr, points):
    cr.move_to(*points[0])
    for p in points[1:]:
        cr.line_to(*p)
    cr.close_path()
    cr.fill()


def stroke(cr, points, close=False):
    cr.set_line_width(W)
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.move_to(*points[0])
    for p in points[1:]:
        cr.line_to(*p)
    if close:
        cr.close_path()
    cr.stroke()


def share(cr):
    stroke(cr, [(9, 10), (5, 10), (5, 21), (19, 21), (19, 10), (15, 10)])
    fill(cr, 11, 6, 2, 10)
    triangle(cr, [(7, 8), (17, 8), (12, 2)])


def email(cr):
    stroke(cr, [(3, 6), (21, 6), (21, 19), (3, 19)], close=True)
    stroke(cr, [(4, 7), (12, 13), (20, 7)])


def copy(cr):
    stroke(cr, [(8, 8), (20, 8), (20, 21), (8, 21)], close=True)
    stroke(cr, [(15, 7), (15, 3), (4, 3), (4, 16), (7, 16)])


def save(cr):
    stroke(cr, [(12, 3), (12, 14)])
    triangle(cr, [(7, 11), (17, 11), (12, 16)])
    stroke(cr, [(4, 15), (4, 21), (20, 21), (20, 15)])


def folder(cr):
    stroke(cr, [(3, 19), (3, 5), (9, 5), (11, 7), (21, 7), (21, 19)], close=True)


def open_with(cr):
    # An app's window with an arrow leaving it: open in another app.
    stroke(cr, [(11, 5), (4, 5), (4, 20), (19, 20), (19, 13)])
    stroke(cr, [(10, 14), (20, 4)])
    triangle(cr, [(13, 3), (21, 3), (21, 11)])


def cloud(cr):
    # A wide cloud with an arrow rising into it: upload, then link.
    cr.set_line_width(W)
    cr.new_path()
    cr.move_to(9, 18)
    cr.line_to(6, 18)
    cr.arc(6, 14, 4, math.pi * 0.5, math.pi * 1.5)
    cr.arc(11, 9.5, 5, math.pi * 1.1, math.pi * 1.85)
    cr.arc(18, 13.5, 4.5, math.pi * 1.4, math.pi * 0.5)
    cr.line_to(15, 18)
    cr.stroke()
    stroke(cr, [(12, 21), (12, 14)])
    triangle(cr, [(8.5, 15.5), (15.5, 15.5), (12, 11.5)])


def file48(cr):
    stroke(cr, [(11, 5), (29, 5), (39, 15), (39, 43), (11, 43)], close=True)
    stroke(cr, [(29, 5), (29, 15), (39, 15)])
    for y in (22, 28, 34):
        fill(cr, 16, y, 18, 2)


def text48(cr):
    for y, w in ((12, 30), (20, 26), (28, 30), (36, 18)):
        fill(cr, 9, y, w, 3)


ICONS = {
    "GSSharing-share-symbolic": (share, 24),
    "GSSharing-email-symbolic": (email, 24),
    "GSSharing-copy-symbolic": (copy, 24),
    "GSSharing-save-symbolic": (save, 24),
    "GSSharing-folder-symbolic": (folder, 24),
    "GSSharing-open-symbolic": (open_with, 24),
    "GSSharing-cloud-symbolic": (cloud, 24),
    "GSSharing-file-symbolic": (file48, 48),
    "GSSharing-text-symbolic": (text48, 48),
}

os.makedirs(OUT, exist_ok=True)
for name, (draw, size) in ICONS.items():
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    cr = cairo.Context(surface)
    cr.set_source_rgb(0, 0, 0)
    draw(cr)
    surface.flush()
    surface.write_to_png(os.path.join(OUT, name + ".png"))
print("wrote %d icons" % len(ICONS))

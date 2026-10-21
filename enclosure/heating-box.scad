// Heating box: wall enclosure next to the boiler for the Shelly 1 Gen4 (heat-demand relay)
// and the eBUS Adapter Stick C6. Print in flame-retardant ABS (UL94 V-0).
//
// Layout as it hangs on the wall (looking at the lid), all cables leave through the bottom:
//
//   +------------------------------+
//   |      [ Shelly, terminals ]   |   N L | 12V SW  O I   (the divider meets the gap after L)
//   |   mains   |      low voltage |
//   |  (L/N, E) |  O/I + eBUS stick|
//   |  [earth]  |        [stick]   |
//   |  clamp    |  clamp     USB   |
//   +---o-------+----o--------o----+
//      mains flex  boiler cable  USB-C
//
// - Mains compartment (left): the fused-spur flex to L/N, its earth core into a Wago in the
//   pocket, a screw-down clamp so a pull on the flex can't reach the terminals. No vents.
// - Low-voltage compartment (right): O/I to the boiler's 24V= RT, the eBUS pair, the stick and
//   its USB-C lead. Vents on the right-hand side only.
// - The divider runs from the bottom wall up to just below the Shelly's terminals.
// - The lid needs a screwdriver (4 x M3 self-tapping), is marked 230 V over the mains side and
//   has ribs that hold the Shelly and the stick down. Tongues close the cable slots above the cables.
// - Two countersunk wall screws (No. 8 / 4 mm), both in the low-voltage compartment.
//
// Render a part with:  openscad -D 'part="base"' -o base.stl heating-box.scad
// Parts: assembly (preview only), inside (base + stand-ins, no lid), base, lid, clamp_mains,
// clamp_lv, testfit (floor and 4 mm of the walls, to check the fit before the full print).

part = "assembly"; // [assembly, inside, base, lid, clamp_mains, clamp_lv, testfit]

/* [Measured 2026-10-20 (mm)] */
shelly = [42.27, 38.29, 16.5]; // Shelly width, height, depth as mounted (terminal strip along the bottom edge); depth from the datasheet
shelly_split = 0.39;       // the gap between the L and 12V terminals, as a fraction of the Shelly's width from its left edge
ferrules = 6;              // how far the wire ferrules stick out below the terminals
stick = [20, 46.53, 13.3]; // eBUS stick width, length, depth (to the top of the black headers)
plug_h = 60 - 46.53;       // the green eBUS plug and its ferrules reach 60 mm from the stick's USB end
// Cables as [width, height] lying on the floor; round ones have both the same.
mains = [5.5, 3.3];        // black mains flex: flat (oval)
lv = [5, 5];               // white boiler cable (O/I + eBUS)
usb = [3.8, 3.8];          // USB-C lead
usb_room = 24 + 2;         // below the stick: USB-C plug + strain relief (24 mm), cable straight out
earth_pocket = true;       // pocket for a Wago 221-413 for an earth core (not needed with 2-core flex)
wago = [14.1, 18.6, 8.2];  // Wago 221-413 (width, length, height)

/* [Box] */
wall = 2.5;
floor_t = 3;
lid_t = 3;
r_out = 6;                 // outside corner radius (the inside follows at constant wall)
edge = 0.6;                // chamfer on both sides of the lid joint: a small V shadow line
foot = 1;                  // chamfer round the bottom (wall side): neat edge, hides elephant foot
lid_round = 1.8;           // rounded top edge of the lid
gap = 0.6;                 // clearance around the Shelly and the stick
fit = 0.3;                 // lid lip / slot tongue clearance
// Cable clamps: [squeeze (fraction of the cable height), ridge width, ridge height, floor ridges]
mains_grip = [0.15, 2, 1, false];
lv_grip = [0.3, 3, 1.5, true]; // round cable: firmer squeeze plus two floor ridges for an S-bend
mains_w = 30;              // mains compartment width
lv_w = stick[0] + 22;      // low-voltage compartment width
div_t = 2;
inner_d = max(shelly[2], stick[2]) + 6; // inside depth (wall to lid)
boss_d = 7;                // lid screw bosses in the inside corners
self_tap = 2.6;            // pilot hole for M3 self-tapping screws
m3_clear = 3.4;
wall_screw = 4.5;          // No. 8 / 4 mm wall screws
wall_head = 8.6;

$fn = 48;

// ---- derived layout (inside coordinates: x right, y up, z out of the wall; origin = inner bottom-left)
W = mains_w + div_t + lv_w;
y_stick0 = usb_room;
y_div_top = y_stick0 + stick[1] + plug_h + 6;
y_sh0 = y_div_top + ferrules + 6;             // bottom (terminal) edge of the Shelly: ferrules + room to bend the cores
H = y_sh0 + shelly[1] + 8;
x_div = mains_w + div_t / 2;
sh_x0 = x_div - shelly_split * shelly[0];
stick_x0 = W - 3 - stick[0] - gap;
usb_x = stick_x0 + (stick[0] + gap) / 2;
mains_x = mains_w / 2;
clamp_y = 14;
mains_off = mains[0] / 2 + 5;                 // clamp screw offset from the cable centre
lv_off = lv[0] / 2 + 4;
lv_x = mains_w + div_t + lv_off + 4 + 0.5;    // the clamp bar's end clears the divider by 0.5 mm
top = floor_t + inner_d;                      // rim height
r_in = r_out - wall;
bi = boss_d / 2 - 0.5;                        // bosses sink 0.5 mm into the walls (no line-only contact) and
                                              // sit far enough in for the countersinks to clear the lid's rounded edge
corners = [[bi, bi], [W - bi, bi], [bi, H - bi], [W - bi, H - bi]];
wall_screws = [[(sh_x0 + shelly[0] + W) / 2, y_sh0 + shelly[1] / 2], [lv_x, y_stick0 + stick[1] / 2]];
slots = [[mains_x, mains], [lv_x, lv], [usb_x, usb]];

assert(sh_x0 > bi + boss_d / 2 + 1, "Shelly hits the lid screw boss: widen mains_w or change shelly_split");
assert(sh_x0 + shelly[0] < W - 2, "Shelly too wide for the box: widen lv_w");
assert(wall_screws[0][0] - wall_head / 2 > sh_x0 + shelly[0] + 1, "top wall screw under the Shelly: widen lv_w");
assert(wall_screws[1][0] + wall_head / 2 < stick_x0 - 1.5, "lower wall screw under the stick: widen lv_w");

// ---- shapes
module rrect(w, h, r) { translate([r, r]) offset(r = r) square([w - 2 * r, h - 2 * r]); }

// Rounded-corner block from z = 0 to ht, origin at its outer bottom-left corner, with an optional
// bottom chamfer (cb) and either a top chamfer (ct) or a rounded top edge (rt).
module rounded_block(w, h, r, ht, cb = 0, ct = 0, rt = 0) {
    prof = concat(
        cb > 0 ? [[0, cb], [cb, 0]] : [[0, 0]],
        rt > 0 ? [for (a = [0 : 15 : 90]) [ht - rt + rt * sin(a), rt * (1 - cos(a))]]
               : ct > 0 ? [[ht - ct, 0], [ht, ct]] : [[ht, 0]]);
    hull() for (q = prof) translate([q[1], q[1], min(q[0], ht - 0.01)])
        linear_extrude(0.01) rrect(w - 2 * q[1], h - 2 * q[1], r - q[1]);
}

// ---- base
module stadium(c) {          // cable cross-section [width, height]; a circle when both match
    hull() for (s = [-1, 1]) translate([s * (c[0] - c[1]) / 2, 0]) circle(d = c[1]);
}

module u_slot(x, c) {        // cable slot in the bottom wall, open towards the lid
    translate([x, 1, floor_t + c[1] / 2]) rotate([90, 0, 0]) linear_extrude(wall + 2) {
        offset(delta = fit) stadium(c);
        translate([-c[0] / 2 - fit, 0]) square([c[0] + 2 * fit, inner_d]);
    }
}

function clamp_h(c, g) = floor_t + c[1] * (1 - g[0]) + g[2]; // boss top: the clamp's ridge squeezes the sheath by g[0]

module clamp_bosses(x, c, off, g) {
    for (s = [-1, 1]) translate([x + s * off, clamp_y, 0])
        difference() {
            cylinder(d = 7, h = clamp_h(c, g));
            translate([0, 0, floor_t]) cylinder(d = self_tap, h = 20);
        }
    // floor ridges just outside the bar: with its ridge in the middle they kink the cable
    if (g[3]) for (s = [-1, 1]) translate([x - c[0] / 2 - 1, clamp_y + s * 4.75 - 0.75, 0])
        cube([c[0] + 2, 1.5, floor_t + 1]);
}

module l_corner(sx, sy) {    // L-shaped locating rail around a corner of the Shelly
    mirror([sx < 0 ? 1 : 0, 0, 0]) mirror([0, sy < 0 ? 1 : 0, 0])
        difference() { cube([7, 7, floor_t + 3]); translate([1.5, 1.5, 0]) cube([10, 10, 10]); }
}

module base() {
    difference() {
        union() {
            // tray
            difference() {
                translate([-wall, -wall, 0]) rounded_block(W + 2 * wall, H + 2 * wall, r_out, top, cb = foot, ct = edge);
                translate([0, 0, floor_t]) linear_extrude(top) rrect(W, H, r_in);
            }
            // lid screw bosses
            for (c = corners) translate([c[0], c[1], 0]) cylinder(d = boss_d, h = top);
            // divider: bottom wall up to just below the Shelly's terminals
            translate([mains_w, 0, 0]) cube([div_t, y_div_top, top]);
            // Shelly locating corners (not along the terminal edge, the wires need it)
            sx0 = sh_x0 - gap / 2 - 1.5; sx1 = sh_x0 + shelly[0] + gap / 2 + 1.5;
            sy0 = y_sh0 - gap / 2 - 1.5; sy1 = y_sh0 + shelly[1] + gap / 2 + 1.5;
            translate([sx0, sy1, 0]) l_corner(1, -1);
            translate([sx1, sy1, 0]) l_corner(-1, -1);
            translate([sx0, sy0 + 4, 0]) l_corner(1, 1);  // lifted so the terminal wires pass
            translate([sx1, sy0 + 4, 0]) l_corner(-1, 1);
            // stick rails
            for (x = [stick_x0 - 1.5, stick_x0 + stick[0] + gap])
                translate([x, y_stick0 + 6, 0]) cube([1.5, stick[1] - 12, floor_t + 3]);
            // earth Wago pocket
            if (earth_pocket) translate([mains_x - wago[0] / 2 - gap - 1.2, clamp_y + 14, 0])
                difference() {
                    cube([wago[0] + 2 * gap + 2.4, wago[1] + 2 * gap + 2.4, floor_t + 3]);
                    translate([1.2, 1.2, floor_t]) cube([wago[0] + 2 * gap, wago[1] + 2 * gap, 10]);
                    translate([-1, 3, floor_t]) cube([wago[0] + 10, wago[1] - 6, 10]); // open sides for the wires
                }
            // cable clamp bosses
            clamp_bosses(mains_x, mains, mains_off, mains_grip);
            clamp_bosses(lv_x, lv, lv_off, lv_grip);
        }
        // lid screw holes
        for (c = corners) translate([c[0], c[1], floor_t + 2]) cylinder(d = self_tap, h = top);
        // cable slots
        for (s = slots) u_slot(s[0], s[1]);
        // wall screws, countersunk from inside
        for (p = wall_screws) translate([p[0], p[1], -1]) {
            cylinder(d = wall_screw, h = floor_t + 2);
            translate([0, 0, 1 + floor_t - wall_head / 2 + 0.01]) cylinder(d1 = 0, d2 = wall_head, h = wall_head / 2);
        }
        // vents: right-hand side, low-voltage compartment only
        for (i = [0 : 4]) translate([W - 1, y_stick0 + 10.8 + i * 12, floor_t + 5.8])
            hull() for (z = [0, inner_d - 11.6]) translate([0, 0, z]) rotate([0, 90, 0]) cylinder(d = 1.6, h = wall + 2);
    }
}

// ---- lid (modelled in place on top of the base; flipped for printing)
module lid() {
    difference() {
        union() {
            translate([-wall, -wall, top]) rounded_block(W + 2 * wall, H + 2 * wall, r_out, lid_t, cb = edge, rt = lid_round);
            // locating lip just inside the walls, cut back around the bosses and the divider
            difference() {
                translate([fit, fit, top - 3]) linear_extrude(3.01) rrect(W - 2 * fit, H - 2 * fit, r_in - fit);
                translate([fit + 1.2, fit + 1.2, top - 4]) linear_extrude(5) rrect(W - 2 * fit - 2.4, H - 2 * fit - 2.4, max(r_in - fit - 1.2, 0.5));
                for (c = corners) translate([c[0], c[1], top - 4]) cylinder(d = boss_d + 2, h = 5);
                translate([mains_w - 1, -1, top - 4]) cube([div_t + 2, 4, 5]);
            }
            // tongues closing the cable slots down to just above each cable
            for (s = slots) translate([s[0] - s[1][0] / 2 - fit + 0.2, -wall, floor_t + s[1][1] + 0.3])
                cube([s[1][0] + 2 * fit - 0.4, wall, top - floor_t - s[1][1] - 0.3]);
            // ribs holding the Shelly and the stick down (0.5 mm clearance)
            translate([sh_x0 + 6, y_sh0 + shelly[1] / 2 - 1, floor_t + shelly[2] + 0.5])
                cube([shelly[0] - 12, 2, top - floor_t - shelly[2] - 0.5]);
            for (dy = [0.25, 0.75]) translate([stick_x0 + 4, y_stick0 + stick[1] * dy - 1, floor_t + stick[2] + 0.5])
                cube([stick[0] - 8, 2, top - floor_t - stick[2] - 0.5]);
        }
        // countersunk M3 screws into the bosses
        for (c = corners) translate([c[0], c[1], top - 1]) {
            cylinder(d = m3_clear, h = lid_t + 2);
            translate([0, 0, lid_t + 1 - 1.8]) cylinder(d1 = m3_clear, d2 = 6.5, h = 1.81);
        }
        // markings, 0.6 mm deep
        translate([mains_w / 2, y_div_top / 2, top + lid_t - 0.6]) linear_extrude(1) {
            text("230 V", size = 7, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            translate([0, -11]) text("ISOLATE AT SPUR", size = 2.6, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        }
        translate([mains_w + div_t + lv_w / 2, y_div_top / 2, top + lid_t - 0.6]) linear_extrude(1)
            text("eBUS / 24 V", size = 4, halign = "center", valign = "center", font = "Liberation Sans");
        // line over the divider
        translate([x_div - 0.4, 0, top + lid_t - 0.6]) cube([0.8, y_div_top, 1]);
    }
}

// ---- cable clamp bars (print flat)
module clamp(c, off, g) {
    difference() {
        hull() for (s = [-1, 1]) translate([s * off, 0, 0]) cylinder(d = 8, h = 3);
        for (s = [-1, 1]) translate([s * off, 0, -1]) cylinder(d = m3_clear, h = 5);
    }
    // ridge that bites into the sheath
    translate([-c[0] / 2, -g[1] / 2, -g[2]]) cube([c[0], g[1], g[2]]);
}

// ---- parts
if (part == "base") base();
else if (part == "lid") translate([0, 0, top + lid_t]) rotate([180, 0, 0]) lid();
else if (part == "clamp_mains") translate([0, 0, 3]) rotate([180, 0, 0]) clamp(mains, mains_off, mains_grip); // ridge up
else if (part == "clamp_lv") translate([0, 0, 3]) rotate([180, 0, 0]) clamp(lv, lv_off, lv_grip);
else if (part == "testfit") intersection() { base(); translate([-50, -50, 0]) cube([W + 100, H + 100, floor_t + 4]); }
else {
    base();
    if (part == "assembly") color("lightgrey", 0.35) translate([0, 0, 25]) lid();
    // stand-ins for the parts, to check the fit
    color("royalblue") translate([sh_x0, y_sh0, floor_t]) cube(shelly);
    color("white") translate([stick_x0 + gap / 2, y_stick0, floor_t]) cube(stick);
    color("green") translate([stick_x0 + gap / 2 + 2, y_stick0 + stick[1], floor_t + 2]) cube([stick[0] - 4, plug_h, stick[2] - 2]);
    for (s = slots) color(s[0] == mains_x ? "black" : "white")
        translate([s[0], 30, floor_t + s[1][1] / 2]) rotate([90, 0, 0]) linear_extrude(50) stadium(s[1]);
    if (earth_pocket) color("orange") translate([mains_x - wago[0] / 2, clamp_y + 14 + 1.2 + gap, floor_t]) cube(wago);
    color("dimgrey") translate([mains_x, clamp_y, clamp_h(mains, mains_grip)]) clamp(mains, mains_off, mains_grip);
    color("dimgrey") translate([lv_x, clamp_y, clamp_h(lv, lv_grip)]) clamp(lv, lv_off, lv_grip);
}

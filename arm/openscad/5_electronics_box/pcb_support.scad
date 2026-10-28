// pcb_support.scad — Electronics base of the camera arm (older version, replaced by electronics_box.scad)
// Holds: 50x70 perfboard, ULN2003 module and Raspberry Pi 4 in the GeeekPi Armor case (dual fan).
// v2: corner brackets WITHOUT snap lips (the PCB drops in freely),
//     cradle for the Pi case with 4 low corner brackets (ports free) and slots for cable ties/Velcro.
// v3: reduced clearance and PCBs fixed with 4 M2 self-tapping screws each in the corner holes.
// Plate to be screwed to the bench with 4 countersunk wood screws.
// All dimensions in mm. Change only the parameters below.

/* [Perfboard] */
mf_x        = 70;     // perfboard length
mf_y        = 50;     // perfboard width
mf_sp       = 1.6;    // perfboard thickness
mf_aria     = 7;      // space under the perfboard (wires and tracks on the solder side)

/* [ULN2003 module] */
uln_x       = 35;     // module length
uln_y       = 32;     // module width
uln_sp      = 1.6;    // PCB thickness
uln_aria    = 4;      // space under the module (soldered pins)
uln_dist    = 8;      // distance between perfboard and module

/* [M2 fixing holes (hole centre from the PCB edge)] */
mf_foro_x   = 2.0;    // 5x7 perfboard: hole spacing 66 mm on the long side
mf_foro_y   = 1.8;    // 5x7 perfboard: hole spacing 46.4 mm on the short side
uln_foro_x  = 2.5;    // ULN2003: measure with a caliper (hole centre from the short edge)
uln_foro_y  = 2.5;    // ULN2003: measure with a caliper (hole centre from the long edge)
pilota_m2   = 1.6;    // pilot hole for M2 self-tapping screw in PETG
prof_m2     = 6;      // pilot hole depth (M2x6..M2x8 screws)

/* [PCB corner brackets (no lips)] */
gioco       = 0.4;    // clearance per side around the PCBs (the M2 screws do the rest)
parete      = 1.8;    // wall thickness
braccio     = 8;      // arm length
appoggio    = 3.5;    // how far the support goes under the PCB
sopra       = 1.5;    // how far the walls rise above the PCB plane

/* [Raspberry Pi 4 case] */
pi_x        = 87;     // case length (Armor: 87)
pi_y        = 56;     // case width (Armor: 56)
pi_gioco    = 1.5;    // clearance per side
pi_parete   = 2.4;    // corner bracket thickness
pi_braccio  = 14;     // corner bracket arm length (leaves the ports free)
pi_h        = 10;     // corner bracket height above the plate
pi_dist     = 8;      // distance between Pi cradle and PCB
cinghia_l   = 12;     // Velcro strap / cable tie slot (length)
cinghia_w   = 3;      // slot (width)
cinghia_x   = 25;     // slot position from the short side of the case (outside the corner brackets)

/* [Plate] */
piastra_h   = 3;      // plate thickness
margine     = 4;      // border around the corner brackets
orecchia    = 9;      // side ears for the screws
vite_d      = 4.5;    // 4 mm wood screws
vite_t      = 8.5;    // countersunk head diameter
fascetta_l  = 4;      // cable tie slot (length)
fascetta_w  = 2.2;    // cable tie slot (width)

/* [Quality] */
$fn = 48;

// ---------------------------------------------------------------- derived dimensions
est     = gioco + parete;                       // PCB corner bracket footprint beyond the edge
pest    = pi_gioco + pi_parete;                 // Pi corner bracket footprint beyond the case
gruppo  = mf_x + uln_dist + uln_x;              // width of perfboard + module
z_mf    = piastra_h + mf_aria;
z_uln   = piastra_h + uln_aria;

// Pi cradle (GPIO side towards the perfboard, USB-C/HDMI ports towards the edge)
pi_x0   = (gruppo - pi_x) / 2;
pi_y0   = 0;
// perfboard and module above the cradle
mf_y0   = pi_y0 + pi_y + pest + pi_dist + est;
uln_x0  = mf_x + uln_dist;
uln_y0  = mf_y0 + (mf_y - uln_y) / 2;

px0 = min(-est, pi_x0 - pest) - margine - orecchia;
px1 = max(gruppo + est, pi_x0 + pi_x + pest) + margine + orecchia;
py0 = pi_y0 - pest - margine;
py1 = mf_y0 + mf_y + est + margine;

// perfboard hole: column 1..24, row 0..17 (row 0 = A, high y side)
mf_fx0 = (mf_x - 23 * 2.54) / 2;
mf_fy0 = (mf_y - 17 * 2.54) / 2;
function foro(c, r) = [mf_fx0 + (c - 1) * 2.54, mf_y0 + mf_y - mf_fy0 - r * 2.54];

echo(str("Plate: ", px1 - px0, " x ", py1 - py0, " mm"));
echo(str("Perfboard seat: ", mf_x + 2 * gioco, " x ", mf_y + 2 * gioco));
echo(str("ULN2003 seat: ", uln_x + 2 * gioco, " x ", uln_y + 2 * gioco));
echo(str("Pi case seat: ", pi_x + 2 * pi_gioco, " x ", pi_y + 2 * pi_gioco));

// ---------------------------------------------------------------- PCB corner bracket without lip (quadrant x>0, y>0)
module angolare(z_app, sp, fx, fy) {
    z_top = z_app + sp + sopra;
    ax = max(appoggio, fx + 2.4);    // the support widens to hold the M2 hole
    ay = max(appoggio, fy + 2.4);
    // support under the PCB corner with M2 pilot hole matching the corner hole
    difference() {
        translate([-gioco, -gioco, 0]) cube([ax + gioco, ay + gioco, z_app]);
        translate([fx, fy, z_app - prof_m2]) cylinder(d = pilota_m2, h = prof_m2 + 0.01, $fn = 20);
        translate([fx, fy, z_app - 0.6]) cylinder(d1 = pilota_m2, d2 = pilota_m2 + 1.2, h = 0.61, $fn = 20);   // lead-in
    }
    // two vertical walls with lead-in chamfer at the top (inside)
    difference() {
        union() {
            translate([-est, -est, 0]) cube([parete, braccio + est, z_top]);
            translate([-est, -est, 0]) cube([braccio + est, parete, z_top]);
        }
        // 45-degree chamfer on the inner top edge: guides the PCB down
        // wall along y (inner face x = -gioco)
        translate([0, -est - 1, 0]) rotate([-90, 0, 0]) linear_extrude(braccio + est + 2)
            polygon([[-gioco + 0.01, -z_top - 0.01], [-gioco - 1, -z_top - 0.01], [-gioco + 0.01, -z_top + 1]]);
        // wall along x (inner face y = -gioco)
        translate([-est - 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(braccio + est + 2)
            polygon([[-gioco + 0.01, z_top + 0.01], [-gioco - 1, z_top + 0.01], [-gioco + 0.01, z_top - 1]]);
    }
}

module quattro_angolari(ox, oy, lx, ly, z_app, sp, fx, fy) {
    translate([ox, oy, 0])                          angolare(z_app, sp, fx, fy);
    translate([ox + lx, oy, 0])      mirror([1, 0, 0]) angolare(z_app, sp, fx, fy);
    translate([ox, oy + ly, 0])      mirror([0, 1, 0]) angolare(z_app, sp, fx, fy);
    translate([ox + lx, oy + ly, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare(z_app, sp, fx, fy);
}

// ---------------------------------------------------------------- Pi case corner bracket
module angolare_pi() {
    translate([-pest, -pest, 0]) cube([pi_parete, pi_braccio + pest, pi_h]);
    translate([-pest, -pest, 0]) cube([pi_braccio + pest, pi_parete, pi_h]);
}

module culla_pi() {
    translate([pi_x0, pi_y0, 0]) {
        angolare_pi();
        translate([pi_x, 0, 0])    mirror([1, 0, 0]) angolare_pi();
        translate([0, pi_y, 0])    mirror([0, 1, 0]) angolare_pi();
        translate([pi_x, pi_y, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare_pi();
    }
}

// ---------------------------------------------------------------- plate
module piastra() {
    difference() {
        hull() for (x = [px0 + 4, px1 - 4], y = [py0 + 4, py1 - 4])
            translate([x, y, 0]) cylinder(r = 4, h = piastra_h);
        // countersunk screws in the ears
        for (x = [px0 + orecchia / 2 + 1, px1 - orecchia / 2 - 1], y = [py0 + 10, py1 - 10])
            translate([x, y, -0.01]) {
                cylinder(d = vite_d, h = piastra_h + 1);
                translate([0, 0, piastra_h - (vite_t - vite_d) / 2 + 0.02])
                    cylinder(d1 = vite_d, d2 = vite_t, h = (vite_t - vite_d) / 2);
            }
        // strap slots for the Pi case (just outside the long sides, near the short sides)
        for (x = [pi_x0 + cinghia_x, pi_x0 + pi_x - cinghia_x])
            for (y = [pi_y0 - pi_gioco - 1 - cinghia_w, pi_y0 + pi_y + pi_gioco + 1])
                translate([x - cinghia_l / 2, y, -1]) cube([cinghia_l, cinghia_w, piastra_h + 2]);
        // ventilation under the case
        for (i = [0:4]) translate([pi_x0 + 22 + i * 9.5, pi_y0 + 10, -1]) cube([5, pi_y - 20, piastra_h + 2]);
        // cable tie slots: servo cables along the top edge, motor cable to the right of the module
        for (x = [15, 40])
            for (dy = [0, 7]) translate([x - fascetta_l / 2, py1 - 2.5 - fascetta_w - dy, -1]) cube([fascetta_l, fascetta_w, piastra_h + 2]);
        for (dx = [0, 7]) translate([uln_x0 + uln_x + est + 2 + dx, uln_y0 + uln_y / 2 - fascetta_l / 2, -1])
            cube([fascetta_w, fascetta_l, piastra_h + 2]);
        // lightening under the perfboard
        translate([12, mf_y0 + 10, piastra_h - 1]) cube([mf_x - 24, mf_y - 20, 2]);
    }
}

// ---------------------------------------------------------------- printable assembly
module supporto() {
    piastra();
    culla_pi();
    quattro_angolari(0, mf_y0, mf_x, mf_y, z_mf, mf_sp, mf_foro_x, mf_foro_y);
    quattro_angolari(uln_x0, uln_y0, uln_x, uln_y, z_uln, uln_sp, uln_foro_x, uln_foro_y);
    // support pillars under the perfboard
    for (p = [foro(12, 17) + [1.27, 0], foro(24, 9) + [1.27, 1.27]])
        translate([p[0], p[1], 0]) cylinder(d = 4, h = z_mf);
}

supporto();

// outlines for checking (F5 preview only)
%translate([0, mf_y0, z_mf]) cube([mf_x, mf_y, mf_sp]);
%translate([uln_x0, uln_y0, z_uln]) cube([uln_x, uln_y, uln_sp]);
%translate([pi_x0, pi_y0, piastra_h]) cube([pi_x, pi_y, 25]);

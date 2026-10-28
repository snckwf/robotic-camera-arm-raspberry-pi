// arm_base.scad — Rotating base of the camera arm
// Pivot: M8x60 hex head bolt + 2 × 608 bearings (8x22x7)
// Motor: 28BYJ-48 with 17-tooth pinion -> 34-tooth ring gear (1:2 reduction)
// Homing: 6x3 neodymium magnet in the plate + KY-024 Hall module on the base
// All dimensions in mm. Change only the parameters below.

/* [Part to generate] */
parte = "assembly"; // [assembly, fixed_base, turntable, pinion, spacer, small_ring]

/* [608 bearings] */
cusc_d        = 22;     // outer diameter
cusc_h        = 7;      // thickness
cusc_gioco    = 0.1;    // light press-fit on the seat diameter
cusc_battuta  = 19;     // outer ring shoulder diameter
anello_int_d  = 11.5;   // rests only on the inner ring (does not touch the seals)
distanza_cusc = 16;     // space between the two bearings in the hub

/* [M8 bolt] */
testa_vite    = "hex"; // [hex, socket]
m8_foro       = 8.4;    // M8 clearance hole
m8_chiave     = 13;     // hex head key size
m8_testa_h    = 5.3;    // hex head height
m8_brugola_d  = 13.5;   // socket head diameter (ISO 4762) + clearance
m8_brugola_h  = 8.2;    // socket head height + clearance

/* [Base plate] */
pb_x0         = -55;    // left edge (relative to the rotation axis)
pb_x1         = 82;     // right edge (motor side)
pb_y          = 100;    // width
pb_h          = 5;      // plate thickness
pb_r          = 8;      // corner radius
boss_d        = 32;     // central boss
boss_h        = 14;     // boss height (top face)
vite_legno_d  = 4.5;    // wood screws to fix it to the bench
vite_legno_t  = 9;      // countersunk head diameter

/* [Turntable] */
mozzo_d       = 30;
z_mozzo0      = 15.5;   // lower height of the hub
disco_d       = 90;
disco_h       = 7;      // 4.4 mm of disc remain above the M3 nuts
attacco_passo = 46;     // 4 M3 holes in a square for the shoulder turret (nuts outside the ring gear spacer)
m3_foro       = 3.4;    // M3 clearance
m3_dado       = 6.0;    // M3 nut key (5.5) + clearance
m3_dado_h     = 2.6;    // M3 nut 2.4 high
magnete_d     = 6.3;    // 6x3 magnet + clearance
magnete_h     = 3.2;
magnete_r     = 38;     // radius of the magnet / sensor track

/* [Gears] */
modulo        = 1.5;
z_corona      = 34;     // ring gear teeth (on the plate)
z_pignone     = 17;     // pinion teeth (on the motor) -> 1:2
ingr_h        = 8;      // ring gear tooth thickness
pignone_h     = 7;      // pinion thickness (1 mm clearance under the ring gear spacer)
pign_tondo    = 2.5;    // lower round section of the bore: the 28BYJ-48 shaft has flats only in the last 6 mm
z_ingr        = 26;     // lower height of the teeth
gioco_denti   = 0.15;   // clearance on the tooth thickness

/* [28BYJ-48 motor] */
mot_d         = 28;     // body diameter
mot_h         = 19;     // body height (up to the ear plane)
mot_off       = 8;      // shaft offset from the body
orecchie_int  = 35;     // fixing hole spacing
orecchie_t    = 0.8;    // ear thickness
mot_vite      = 2.5;    // pilot hole: M3 screw driven into the plastic
albero_d      = 5;
albero_piatti = 3;      // distance between the shaft flats

/* [KY-024 Hall sensor] */
hall_x        = -38;    // under the magnet track
hall_alt      = 22;     // height of the pedestal face (low: trimmer and components stay under the plate)
hall_lung     = 30;     // pedestal length (along Y)
hall_largh    = 10;
hall_fori     = [-30, -22]; // Y positions of the M3 pilot holes

/* [Quality] */
$fn = 96;

// ---------------------------------------------------------------- derived dimensions
rp_corona   = modulo * z_corona / 2;
rp_pignone  = modulo * z_pignone / 2;
interasse   = rp_corona + rp_pignone;          // 38.25 with the standard values
mot_x       = interasse + mot_off;              // motor body centre
z_c1        = boss_h + 1;                       // lower bearing base
z_c2        = z_c1 + cusc_h + distanza_cusc;    // upper bearing base
z_top       = z_c2 + cusc_h;                    // plate top face (= bearing flush)
z_disco0    = z_top - disco_h;

echo(str("Gear centre distance = ", interasse, " mm"));
echo(str("Plate top face at z = ", z_top, " mm"));
echo(str("Spacer length = ", distanza_cusc, " mm"));

// ---------------------------------------------------------------- involute gear
function inv(a) = tan(a) - a * PI / 180;        // a in degrees -> radians
function gradi(x) = x * 180 / PI;

module ingranaggio(z, m, h, gioco = 0.15, pa = 20) {
    rp = m * z / 2;
    rb = rp * cos(pa);
    ra = rp + m;
    rf = rp - 1.25 * m;
    semi = PI / (2 * z) - (gioco / 2) / rp;     // half tooth at the pitch circle (rad)
    base = semi + inv(pa);
    r0 = max(rb, rf);
    n = 12;
    fianco = [for (i = [0 : n]) let(r = r0 + (ra - r0) * i / n)
              [r, gradi(base - inv(acos(rb / r)))]];
    a0 = fianco[0][1];
    su = [for (p = fianco) [p[0] * cos(p[1]), p[0] * sin(p[1])]];
    giu = [for (i = [n : -1 : 0]) let(p = fianco[i]) [p[0] * cos(-p[1]), p[0] * sin(-p[1])]];
    radice = [[(rf - 0.4) * cos(-a0), (rf - 0.4) * sin(-a0)],
              [(rf - 0.4) * cos(a0),  (rf - 0.4) * sin(a0)]];
    linear_extrude(h)
        union() {
            circle(r = rf, $fn = z * 4);
            for (k = [0 : z - 1]) rotate(k * 360 / z)
                polygon(concat(giu, radice, su));
        }
}

// ---------------------------------------------------------------- fixed base
module piastra_2d() {
    hull()
        for (x = [pb_x0 + pb_r, pb_x1 - pb_r], y = [-pb_y / 2 + pb_r, pb_y / 2 - pb_r])
            translate([x, y]) circle(r = pb_r);
}

module base_fissa() {
    difference() {
        union() {
            linear_extrude(pb_h) piastra_2d();
            cylinder(d = boss_d, h = boss_h);
            // resting ring on the inner ring of the lower bearing
            translate([0, 0, boss_h - 0.01]) cylinder(d = anello_int_d, h = 1.01);
            // posts for the motor ears
            for (s = [-1, 1])
                translate([mot_x, s * orecchie_int / 2, 0])
                    cylinder(d = 7, h = pb_h + mot_h - orecchie_t);
            // Hall sensor pedestal
            translate([hall_x - hall_largh / 2, -hall_lung - 6, 0])
                cube([hall_largh, hall_lung, hall_alt]);
        }
        // M8 bolt head seat (from below) + clearance hole with 0.3 mm sacrificial layer
        if (testa_vite == "hex") {
            translate([0, 0, -0.01])
                cylinder(d = (m8_chiave + 0.4) / cos(30), h = m8_testa_h + 0.31, $fn = 6);
            translate([0, 0, m8_testa_h + 0.6]) cylinder(d = m8_foro, h = 50, $fn = 48);
        } else {
            translate([0, 0, -0.01]) cylinder(d = m8_brugola_d, h = m8_brugola_h + 0.01);
            translate([0, 0, m8_brugola_h + 0.3]) cylinder(d = m8_foro, h = 50, $fn = 48);
        }
        // motor pilot holes
        for (s = [-1, 1])
            translate([mot_x, s * orecchie_int / 2, pb_h])
                cylinder(d = mot_vite, h = mot_h, $fn = 32);
        // sensor M3 pilot holes
        for (y = hall_fori)
            translate([hall_x, y, hall_alt - 10]) cylinder(d = 2.5, h = 11, $fn = 32);
        // countersunk holes for wood screws
        for (x = [pb_x0 + 9, pb_x1 - 9], y = [-pb_y / 2 + 9, pb_y / 2 - 9])
            translate([x, y, -0.01]) {
                cylinder(d = vite_legno_d, h = pb_h + 1, $fn = 32);
                translate([0, 0, pb_h - (vite_legno_t - vite_legno_d) / 2 + 0.02])
                    cylinder(d1 = vite_legno_d, d2 = vite_legno_t, h = (vite_legno_t - vite_legno_d) / 2, $fn = 32);
            }
    }
}

// ---------------------------------------------------------------- turntable
module piatto_rotante() {
    difference() {
        union() {
            translate([0, 0, z_mozzo0]) cylinder(d = mozzo_d, h = z_top - z_mozzo0);
            translate([0, 0, z_ingr]) ingranaggio(z_corona, modulo, ingr_h, gioco_denti);
            translate([0, 0, z_disco0]) cylinder(d = disco_d, h = disco_h, $fn = 180);
            // solid spacer between ring gear and disc, as wide as the tooth tips:
            // printing upside down (disc on the bed) every layer is supported by the one below
            translate([0, 0, z_ingr + ingr_h - 0.01])
                cylinder(r = rp_corona + modulo, h = z_disco0 - z_ingr - ingr_h + 0.02, $fn = 180);
        }
        // central hole
        translate([0, 0, z_mozzo0 - 1]) cylinder(d = 16, h = z_top);
        // lower bearing seat + shoulder
        translate([0, 0, z_mozzo0 - 0.01]) cylinder(d = cusc_d + cusc_gioco, h = z_c1 + cusc_h - z_mozzo0 + 0.01);
        translate([0, 0, z_c1 + cusc_h - 0.01]) cylinder(d1 = cusc_battuta, d2 = 16, h = 1.5);
        // upper bearing seat + shoulder
        translate([0, 0, z_c2]) cylinder(d = cusc_d + cusc_gioco, h = cusc_h + 0.01);
        // 45-degree cone shoulder (no flat step): printable upside down without overhangs,
        // the outer ring of the 608 rests on the chamfer
        translate([0, 0, z_c2 - (cusc_d + cusc_gioco - 16) / 2])
            cylinder(d1 = 16, d2 = cusc_d + cusc_gioco, h = (cusc_d + cusc_gioco - 16) / 2 + 0.01);
        // 4 M3 holes with nut seat under the disc
        for (x = [-1, 1], y = [-1, 1])
            translate([x * attacco_passo / 2, y * attacco_passo / 2, z_disco0 - 0.01]) {
                cylinder(d = m3_foro, h = disco_h + 1, $fn = 32);
                rotate(30) cylinder(d = m3_dado / cos(30), h = m3_dado_h, $fn = 6);
            }
        // magnet seat (under the disc, above the sensor in the rest position)
        translate([hall_x, 0, z_disco0 - 0.01]) cylinder(d = magnete_d, h = magnete_h + 0.01, $fn = 48);
        // reference notch on the edge (+X direction = front)
        translate([disco_d / 2, 0, z_top]) rotate([0, 45, 0]) cube([2, 3, 2], center = true);
    }
}

// ---------------------------------------------------------------- motor pinion
module pignone() {
    difference() {
        ingranaggio(z_pignone, modulo, pignone_h, gioco_denti);
        // lower round section (the shaft is round between collar and start of the flats)
        translate([0, 0, -0.01]) cylinder(d = albero_d + 0.3, h = pign_tondo + 0.01, $fn = 48);
        // upper section shaped on the shaft flats
        translate([0, 0, pign_tondo - 0.01])
            intersection() {
                cylinder(d = albero_d + 0.2, h = pignone_h, $fn = 48);
                translate([-(albero_piatti + 0.2) / 2, -5, 0]) cube([albero_piatti + 0.2, 10, pignone_h]);
            }
    }
}

// ---------------------------------------------------------------- spacers (inner ring only)
module distanziale() {
    difference() {
        cylinder(d = anello_int_d, h = distanza_cusc);
        translate([0, 0, -1]) cylinder(d = m8_foro, h = distanza_cusc + 2, $fn = 48);
    }
}

module anellino() {
    difference() {
        cylinder(d = anello_int_d, h = 2);
        translate([0, 0, -1]) cylinder(d = m8_foro, h = 4, $fn = 48);
    }
}

// ---------------------------------------------------------------- assembly (with commercial parts transparent)
module cuscinetto_608() {
    difference() {
        cylinder(d = cusc_d, h = cusc_h);
        translate([0, 0, -1]) cylinder(d = 8, h = cusc_h + 2);
    }
}

module motore_28byj() {
    color("silver") cylinder(d = mot_d, h = mot_h);
    color("silver") translate([0, 0, mot_h - orecchie_t])
        linear_extrude(orecchie_t) hull() for (s = [-1, 1]) translate([0, s * orecchie_int / 2]) circle(d = 7);
    color("royalblue") translate([mot_d / 2 - 3, -8.5, 0]) cube([6, 17, mot_h - 1]);
    color("gold") translate([-mot_off, 0, mot_h]) cylinder(d = 9, h = 1.5);
    color("gold") translate([-mot_off, 0, mot_h]) cylinder(d = albero_d, h = 10);
}

module assieme() {
    color("lightsteelblue") base_fissa();
    color("orange") piatto_rotante();
    // with 17 teeth (odd) at 180 degrees there is already a gap: no phase rotation
    color("tomato") translate([interasse, 0, z_ingr]) pignone();
    color("orange") translate([0, 0, z_c1 + cusc_h]) distanziale();
    color("orange") translate([0, 0, z_top]) anellino();
    translate([mot_x, 0, pb_h]) motore_28byj();
    color("dimgray", 0.6) {
        translate([0, 0, z_c1]) cuscinetto_608();
        translate([0, 0, z_c2]) cuscinetto_608();
        cylinder(d = 8, h = 60 + m8_testa_h);                                   // bolt
        cylinder(d = m8_chiave / cos(30), h = m8_testa_h, $fn = 6);             // head
        translate([0, 0, z_top + 2]) cylinder(d = 16, h = 1.6);                 // washer
        translate([0, 0, z_top + 3.6]) cylinder(d = 13 / cos(30), h = 8, $fn = 6); // self-locking nut
    }
    color("red") translate([hall_x, 0, z_disco0]) cylinder(d = 6, h = 3);    // magnet
    color("green") translate([hall_x - 7.5, -36, hall_alt]) cube([15, 36, 1.6]); // KY-024
}

// ---------------------------------------------------------------- selection
if      (parte == "assembly")       assieme();
else if (parte == "fixed_base")     base_fissa();
else if (parte == "turntable")      rotate([180, 0, 0]) translate([0, 0, -z_top]) piatto_rotante(); // disc on the bed
else if (parte == "pinion")         pignone();
else if (parte == "spacer")         distanziale();
else if (parte == "small_ring")     anellino();

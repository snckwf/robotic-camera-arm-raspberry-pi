// electronics_box.scad — Closed box for the camera arm electronics
// v3 (19/10/2026): larger box. Inside: 5V 5A power supply (85x58x32), Freenove FNK0080 breakout (holes 58x49),
//         PCA9685 (servos), BSS138 level shifter (LCD), ULN2003 module, 4 Forbox terminals for 5V/GND,
//         230V switch and mains inlet.
// The breakout is connected to the Pi on the lid with a 40-pin GPIO cable running through the lid slot.
// On top of the lid, in the open: Raspberry Pi 4 in the GeeekPi Armor case (87x56x25).
// Lid closed with 4 M3 button-head screws driven into the posts (2.5 pilot holes).
// 16x2 LCD display: separate two-piece box (display_shell + display_bottom) to be fixed wherever you like.
// Breakout on posts with the kit M2.5 screws, ULN2003 with M2 self-tapping screws. The power supply is fixed with its own screws (flat bottom).
// All dimensions in mm. Change only the parameters below.

/* [Part to generate] */
parte = "assembly"; // [assembly, box, lid, cable_clamp, display_shell, display_bottom]

/* [Box] */
in_x      = 190;   // inside along X
in_y      = 132;   // inside along Y
in_h      = 50;    // inside: from the bottom to the lid
parete    = 2.4;   // 2.4 mm: suits the snap tabs of rocker switches (1-3 mm panel)
fondo     = 3;
coperchio_h = 3;
colonna   = 10;    // corner posts for the lid screws (square)
pilota_m3 = 2.5;   // M3 screw driven into the plastic
passante_m3 = 3.4;
testa_m3  = 6.5;   // M3 button head counterbore (ISO 7380)

/* [5V 5A power supply] */
psu_x     = 85;    // length (terminal block on the short side towards +X)
psu_y     = 58;
psu_h     = 32;
psu_pos   = [12, 6];

/* [Freenove breakout and ULN2003] */
bo_x = 85; bo_y = 56;            // board footprint (Raspberry Pi format)
bo_pos = [11, 72];               // board corner
bo_fori = [[3.5, 3.5], [61.5, 3.5], [3.5, 52.5], [61.5, 52.5]];   // M2.5 holes (Pi/HAT pattern 58 x 49)
bo_alt  = 11;                    // post height: leaves room for the 40-pin connector under the board
col_d   = 12;                    // post diameter
col_base = 18;                   // diameter of the conical fillet at the base (reinforcement against tearing)
col_base_h = 5;                  // fillet height
bo_taglio = 2.6;                 // posts cut at 2.6 mm from the hole centre towards the board centre (40-pin connector underneath)
passante_m25 = 2.8;              // hole for M2.5 screw
dado_m25  = 5.4;                 // M2.5 nut key (5) + clearance
dado_m25_h = 2.3;                // nut seat height (nut 2)
dado_m25_z = 0.6;                // thickness above the nut: the kit M2.5x4 screw (4 - 1.6 of board) grips the whole nut
uln_x = 35; uln_y = 32; uln_sp = 1.6; uln_aria = 4; uln_pos = [144, 86];
wago_anc = [[108, 14], [128, 14], [108, 34], [128, 34]]; // anchors for the cable ties of the 4 Forbox terminals (2 for +5V, 2 for GND)
pca_pos  = [118, 52];            // PCA9685 (servos): board corner
pca_dim  = [62.3, 25.4];
pca_fori = [[3.2, 3.15], [59.1, 3.15], [3.2, 22.25], [59.1, 22.25]];   // M2.5 holes (spacing 55.9 x 19.1: measure)
pca_alt  = 6;                    // posts (M2.5x8 self-tapping screw in the pilot hole)
pilota_m25 = 2.1;
bss_pos  = [97, 54];            // inner corner of the seat            // BSS138 4-channel level shifter (held with a drop of hot glue)
bss_dim  = [16.4, 15.9];        // bay: 16 x 15.5 module (6 pins at 2.54 pitch per row, rows 12.7 mm apart) + 0.2 each side; pins facing up
bss_par  = 2;                   // seat walls
bss_h    = 4.5;                 // high walls on the sides without pins (with snap teeth)
bss_h_pin = 2.2;                // low walls on the sides with the pin rows (they do not hinder the Dupont jumpers)
uln_foro = [2.5, 2.5];   // ULN2003 corner holes: measure with a caliper
gioco_pcb = 0.4;
parete_ang = 1.8;
braccio_ang = 8;
pilota_m2 = 1.6;

/* [230V switch and mains inlet (front wall Y=0)] */
sw_x      = 158;   // switch centre along X
sw_w      = 19.2;  // KCD1 rocker switch hole (19.2 x 12.9); large KCD3: 28 x 22
sw_h      = 12.9;
sw_z      = 26;    // hole centre above the bottom
rete_x    = 178;   // mains cable hole centre
rete_d    = 8;     // 3x0.75 cable (d 6-7); for a PG7 cable gland set 12.5
rete_z    = 6;     // hole centre above the bottom (the cable rests on the bottom)
fc_int    = 18;    // cable clamp screw spacing
fc_alt    = 5;     // cable clamp post height (squeezes the d 7 cable to 5 mm)
fc_y      = 16;    // distance of the cable clamp from the front wall

/* [Cable exit towards the arm (right wall X=in_x)] */
usc_y     = [58, 116];
usc_z     = [10, 32];

/* [Raspberry Pi on the lid] */
pi_x = 87; pi_y = 56; pi_gioco = 1.5;
pi_pos    = [10, 44];   // cradle corner (inside) on the lid
pi_par    = 2.4;
pi_bra    = 14;
pi_h      = 10;
dup_slot  = [[14, 114], [66, 13]];  // slot for the 40-pin GPIO cable: the IDC connector (56 x 9 + key) passes with margin
usbc_slot = [[14, 32], [16, 9]];    // passage for the Pi USB-C power cable
cinghia   = [12, 3];

/* [16x2 LCD display box at 45 degrees (separate: fix it wherever you like)] */
tl_sul_coperchio = false;   // true = old version integrated in the lid (shelf + opening)
df_sp      = 4;         // thickness of the box bottom
df_orecchia = 12;       // tab on the left side of the bottom with 2 holes to fix it (M3 screws); no tab on the right
df_cavo    = 8;         // cable hole in the bottom
lcd_pcb    = [80, 36];  // 1602 LCD board
lcd_fori   = [75, 31];  // board fixing hole spacing (measure)
lcd_fin    = [72, 25];  // window for the metal frame (frame 71 x 24-26)
lcd_corn   = 7;         // height of the metal frame above the board (measure): the frame comes flush with the front
lcd_gioco  = [13, 6];   // space between board and walls: left (I2C module pin exit) / right
tl_xf      = in_x + parete;   // x of the turret front: flush with the right side of the box
tl_fuori   = 0.6;       // part of the turret outside the box outline (0.6 = 60%)
tl_par     = 2.4;       // wall thickness
tl_marg    = [10, 3];    // margin below / above the board along the inclined plane
tl_prof    = 48;        // total depth (room behind the board for the I2C module soldered on top)
tl_bor_d   = 8;         // bosses of the 4 M3 fixing screws (screwed from under the lid)
tl_bor_h   = 8;
tl_bor_xy  = [4, 8.4];  // boss distance from the edges (x) and from the front (y)
lcd_bor_d  = 5.5;       // LCD board screw bosses (M3 x 6 in the pilot hole)

/* [Fixing to the bench] */
orecchia  = 10;
vite_legno = 4.5;
vite_testa = 8.5;

/* [Quality] */
$fn = 40;

// ---------------------------------------------------------------- derived dimensions
ex = in_x + 2 * parete;
ey = in_y + 2 * parete;
ez = fondo + in_h;                 // box height (top edge)
est = gioco_pcb + parete_ang;
pest = pi_gioco + pi_par;
tl_L  = lcd_pcb[0] + lcd_gioco[0] + lcd_gioco[1] + 2 * tl_par;   // turret length
tl_lx = tl_par + lcd_gioco[0] + lcd_pcb[0] / 2;                  // board centre along x
tl_s  = (tl_marg[0] + lcd_pcb[1] + tl_marg[1]) / sqrt(2);  // height (plane inclined at 45 degrees)
tl_lc = tl_marg[0] + lcd_pcb[1] / 2;                  // board centre along the inclined plane
function tl_viti() = [[tl_bor_xy[0], tl_bor_xy[1]], [tl_L - tl_bor_xy[0], tl_bor_xy[1]],
                      [tl_bor_xy[0], tl_prof - tl_par - 4], [tl_L - tl_bor_xy[0], tl_prof - tl_par - 4]];
tl_y0 = in_y + parete - (1 - tl_fuori) * tl_L;      // y of the inner end of the turret (the other sticks out beyond the back side)
tl_ap = [[11, 14], [in_y - 2 - tl_y0, tl_prof - tl_par - 9]];   // opening in the lid under the turret (only inside the box)
module tl_su_coperchio() translate([tl_xf, tl_y0, 0]) rotate(90) children();   // turret system -> lid (screen towards X+)
// the turret covers the rear right corner: there the lid has no screw (it stays fixed with the other 3)
function viti_coperchio() = [for (c = colonne()) if (!tl_sul_coperchio || !(c[0] > in_x / 2 && c[1] > in_y / 2)) c];
// the inner coordinates start from (0,0, fondo): the box is shifted by -parete
echo(str("Outer box: ", ex, " x ", ey, " x ", ez, " mm; with lid ", ez + coperchio_h));
echo(str("Breakout ", bo_x, " x ", bo_y, " on posts h ", bo_alt, ", ULN ", uln_x + 2 * gioco_pcb, " x ", uln_y + 2 * gioco_pcb));

// vertical through slot in a wall parallel to YZ (along X) or XZ (along Y): semicircular ends
module asola_x(x0, y, z0, z1, w) hull() for (z = [z0, z1]) translate([x0, y, z]) rotate([0, 90, 0]) cylinder(d = w, h = parete + 2, $fn = 24);
module asola_y(x, y0, z0, z1, w) hull() for (z = [z0, z1]) translate([x, y0, z]) rotate([-90, 0, 0]) cylinder(d = w, h = parete + 2, $fn = 24);

function colonne() = [[colonna / 2, colonna / 2], [in_x - colonna / 2, colonna / 2],
                      [colonna / 2, in_y - colonna / 2], [in_x - colonna / 2, in_y - colonna / 2]];

module arrotondato(x, y, h, r = 3) {
    hull() for (i = [r, x - r], j = [r, y - r]) translate([i, j, 0]) cylinder(r = r, h = h);
}

// ---------------------------------------------------------------- PCB corner brackets with M2 hole (as in pcb_support v3)
module angolare(z_app, sp, fx, fy) {
    z_top = z_app + sp + 1.5;
    ax = fx + 2.4; ay = fy + 2.4;
    difference() {
        translate([-gioco_pcb, -gioco_pcb, 0]) cube([ax + gioco_pcb, ay + gioco_pcb, z_app]);
        translate([fx, fy, z_app - 6]) cylinder(d = pilota_m2, h = 6.01, $fn = 20);
    }
    translate([-est, -est, 0]) cube([parete_ang, braccio_ang + est, z_top]);
    translate([-est, -est, 0]) cube([braccio_ang + est, parete_ang, z_top]);
}
module quattro_angolari(pos, lx, ly, z_app, sp, f) {
    translate([pos[0], pos[1], 0]) {
        angolare(z_app, sp, f[0], f[1]);
        translate([lx, 0, 0])  mirror([1, 0, 0]) angolare(z_app, sp, f[0], f[1]);
        translate([0, ly, 0])  mirror([0, 1, 0]) angolare(z_app, sp, f[0], f[1]);
        translate([lx, ly, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare(z_app, sp, f[0], f[1]);
    }
}

// ---------------------------------------------------------------- box (system: inside from (0,0), inner bottom at z = fondo)
module scatola() {
    difference() {
        union() {
            translate([-parete, -parete, 0]) arrotondato(ex, ey, ez);
            // ears for the wood screws (X sides)
            for (x = [-parete - orecchia, in_x + parete - 3], y = [12, in_y - 12 - 16])
                translate([x, y, 0]) cube([orecchia + 3, 16, 4]);
        }
        // inner cavity
        translate([0, 0, fondo]) cube([in_x, in_y, in_h + 1]);
        // countersunk wood screw holes
        for (x = [-parete - orecchia / 2, in_x + parete + orecchia / 2], y = [20, in_y - 20])
            translate([x, y, -0.01]) {
                cylinder(d = vite_legno, h = 5);
                translate([0, 0, 4 - (vite_testa - vite_legno) / 2 + 0.02]) cylinder(d1 = vite_legno, d2 = vite_testa, h = (vite_testa - vite_legno) / 2);
            }
        // front wall: switch and mains inlet
        translate([sw_x - sw_w / 2, -parete - 1, fondo + sw_z - sw_h / 2]) cube([sw_w, parete + 2, sw_h]);
        translate([rete_x, 1, fondo + rete_z]) rotate([90, 0, 0]) cylinder(d = rete_d, h = parete + 2);
        // right wall: cable exit towards the arm (rounded slot)
        translate([in_x - 1, 0, fondo]) hull() for (y = usc_y, z = usc_z)
            translate([0, y, z]) rotate([0, 90, 0]) cylinder(r = 4, h = parete + 2);
        // left wall: ventilation next to the power supply (vertical slots with round ends: no supports)
        for (i = [0:6]) asola_x(-parete - 1, psu_pos[1] + 7.5 + i * 7, fondo + 9.5, fondo + psu_h - 3.5, 3);
        // rear wall: high ventilation (vertical slots)
        for (i = [0 : floor((in_x - 34) / 12)]) asola_y(22 + i * 12, in_y - 1, fondo + in_h - 12, fondo + in_h - 6, 4);
    }
    // corner posts for the lid screws
    for (c = colonne()) difference() {
        translate([c[0] - colonna / 2, c[1] - colonna / 2, 0]) cube([colonna, colonna, ez]);
        translate([c[0], c[1], ez - 14]) cylinder(d = pilota_m3, h = 14.1);
    }
    // perfboard and ULN2003 supports
    translate([0, 0, fondo - 0.01]) {
        // Freenove breakout posts: kit M2.5x4 screw from above into an M2.5 nut inserted from the side near the top
        for (f = bo_fori) translate([bo_pos[0] + f[0], bo_pos[1] + f[1], 0]) difference() {
            // post with conical fillet at the base; cut where it touches the power supply (y < 62.4)
            intersection() {
                union() {
                    cylinder(d = col_d, h = bo_alt);
                    cylinder(d1 = col_base, d2 = col_d, h = col_base_h);
                }
                translate([-20, psu_pos[1] + psu_y + 0.4 - (bo_pos[1] + f[1]), -1]) cube([40, in_y - (psu_pos[1] + psu_y + 0.4), bo_alt + 2]);   // inside the box
            }
            translate([0, 0, bo_alt - 8]) cylinder(d = passante_m25, h = 8.1);
            // side towards the centre cut away: leaves room for the 40-pin female connector under the board
            // (it sits between the holes, on the same row, from 3.6 mm from the hole centre onwards)
            translate([f[0] < 30 ? bo_taglio : -bo_taglio - 30, -20, -1]) cube([30, 40, bo_alt + 2]);
            // nut seat open towards the outside of the board: insert the nut before fitting the breakout
            translate([0, 0, bo_alt - dado_m25_z - dado_m25_h]) hull() {
                rotate(30) cylinder(d = dado_m25 / cos(30), h = dado_m25_h, $fn = 6);
                translate([(f[0] < 30 ? -1 : 1) * 8, 0, 0]) rotate(30) cylinder(d = dado_m25 / cos(30), h = dado_m25_h, $fn = 6);
            }
        }
        // cable tie anchors for the Forbox terminals (bridge on the bottom)
        for (w = wago_anc) translate([w[0] - 3, w[1] - 5, 0]) difference() {
            cube([6, 10, 5]);
            translate([-1, 3.4, -0.01]) cube([8, 3.2, 2.6]);
        }
        quattro_angolari(uln_pos, uln_x, uln_y, uln_aria, uln_sp, uln_foro);
        // PCA9685 posts (with fillet at the base)
        for (q = pca_fori) translate([pca_pos[0] + q[0], pca_pos[1] + q[1], 0]) difference() {
            union() { cylinder(d = 6.5, h = pca_alt); cylinder(d1 = 10, d2 = 6.5, h = 2.5); }
            translate([0, 0, 0.8]) cylinder(d = pilota_m25, h = pca_alt, $fn = 20);
        }
        // BSS138 level shifter seat: tray with low walls on the pin sides and snap teeth on the other two
        translate([bss_pos[0], bss_pos[1], 0]) {
            difference() {
                translate([-bss_par, -bss_par, 0]) cube([bss_dim[0] + 2 * bss_par, bss_dim[1] + 2 * bss_par, bss_h]);
                translate([0, 0, -1]) cube([bss_dim[0], bss_dim[1], bss_h + 2]);
                // sides with the pin rows (along X): lowered walls
                for (y = [-bss_par - 1, bss_dim[1] - 0.01]) translate([-bss_par - 1, y, bss_h_pin]) cube([bss_dim[0] + 2 * bss_par + 2, bss_par + 1.01, bss_h]);
                // window under the centre: push the module out with a screwdriver from below
            }
            // snap teeth (sides without pins, along Y): just above the board (1.6) with lead-in
            for (s = [0, 1]) translate([s * bss_dim[0], bss_dim[1] / 2 - 3, 1.8]) mirror([s, 0, 0])
                hull() { cube([0.01, 6, 1.2]); translate([0, 0, 0]) cube([0.6, 6, 0.4]); }
        }
    }
    // mains cable clamp posts
    for (s = [-1, 1]) translate([rete_x + s * fc_int / 2, fc_y, fondo - 0.01]) difference() {
        cylinder(d = 8, h = fc_alt);
        cylinder(d = pilota_m3, h = fc_alt + 1);
    }
}

// ---------------------------------------------------------------- lid (same system, rests at z = ez)
module coperchio() {
    translate([0, 0, ez]) {
        difference() {
            union() {
                translate([-parete, -parete, 0]) arrotondato(ex, ey, coperchio_h);
                // cantilever shelf under the LCD turret (integrated version only)
                if (tl_sul_coperchio) translate([tl_xf - tl_prof, tl_y0, 0]) arrotondato(tl_prof, tl_L, coperchio_h, 3);
            }
            // M3 screws into the posts with counterbore for the button head
            for (c = viti_coperchio()) translate([c[0], c[1], -1]) {
                cylinder(d = passante_m3, h = coperchio_h + 2);
                translate([0, 0, 1 + coperchio_h - 1.8]) cylinder(d = testa_m3, h = 3);
            }
            // Dupont cable slot (above the perfboard header) and Pi USB-C passage
            for (s = [dup_slot, usbc_slot]) translate([s[0][0], s[0][1], -1]) arrotondato(s[1][0], s[1][1], coperchio_h + 2, 2);
            // ventilation above the power supply
            for (i = [0:7]) translate([40 + i * 7, 8, -1]) arrotondato(3, 26, coperchio_h + 2, 1.4);
            // ventilation above PCA9685 and ULN2003
            for (i = [0:8]) translate([116 + i * 8, 54, -1]) arrotondato(3, 26, coperchio_h + 2, 1.4);
            // grommet hole for the display wires (I2C) and other external cables
            translate([170, 112, -1]) cylinder(d = 12, h = coperchio_h + 2);
            // LCD turret: opening for cables and air + 4 M3 holes (screws from below, into the turret bosses)
            if (tl_sul_coperchio) tl_su_coperchio() {
                translate([tl_ap[0][0], tl_ap[0][1], -1]) arrotondato(tl_ap[1][0] - tl_ap[0][0], tl_ap[1][1] - tl_ap[0][1], coperchio_h + 2, 3);
                for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = passante_m3, h = coperchio_h + 2);
            }
            // Velcro strap slots for the Pi case
            for (x = [pi_pos[0] + 30, pi_pos[0] + pi_x + 2 * pi_gioco - 30], y = [pi_pos[1] - 1 - cinghia[1], pi_pos[1] + pi_y + 2 * pi_gioco + 1])
                translate([x - cinghia[0] / 2, y, -1]) cube([cinghia[0], cinghia[1], coperchio_h + 2]);
        }
        // Pi case cradle: 4 low corner brackets, ports free
        translate([pi_pos[0] + pi_gioco, pi_pos[1] + pi_gioco, coperchio_h - 0.01]) {
            for (m = [[0, 0], [1, 0], [0, 1], [1, 1]])
                translate([m[0] * pi_x, m[1] * pi_y, 0]) mirror([m[0], 0, 0]) mirror([0, m[1], 0]) {
                    translate([-pest, -pest, 0]) cube([pi_par, pi_bra + pest, pi_h]);
                    translate([-pest, -pest, 0]) cube([pi_bra + pest, pi_par, pi_h]);
                }
        }
    }
}

// ---------------------------------------------------------------- 16x2 LCD turret at 45 degrees
// local system: x along the turret, y towards the back (y=0 front), z up (z=0 resting on the lid)
module tl_profilo() polygon([[0, 0], [tl_s, tl_s], [tl_prof, tl_s], [tl_prof, 0]]);
module tl_su_piano(d, x) translate([x, d / sqrt(2), d / sqrt(2)]) rotate([45, 0, 0]) children();  // local z = outward normal
module torretta_lcd() {
    difference() {
        union() {
            difference() {
                rotate([90, 0, 90]) linear_extrude(tl_L) tl_profilo();
                // inner cavity, open underneath
                translate([tl_par, 0, 0]) rotate([90, 0, 90]) linear_extrude(tl_L - 2 * tl_par) {
                    offset(delta = -tl_par) tl_profilo();
                    translate([tl_par * (1 + sqrt(2)), -1]) square([tl_prof - tl_par - tl_par * (1 + sqrt(2)), tl_par + 1.01]);
                }
            }
            // bosses of the screws fixing it to the lid
            intersection() {
                for (v = tl_viti()) translate([v[0], v[1], 0]) cylinder(d = tl_bor_d, h = tl_bor_h);
                rotate([90, 0, 90]) linear_extrude(tl_L) tl_profilo();
            }
            // LCD board bosses (behind the inclined plane)
            for (i = [-1, 1], j = [-1, 1]) tl_su_piano(tl_lc + j * lcd_fori[1] / 2, tl_lx + i * lcd_fori[0] / 2)
                translate([0, 0, -lcd_corn]) cylinder(d = lcd_bor_d, h = lcd_corn - 0.5);
        }
        // window for the display frame
        tl_su_piano(tl_lc, tl_lx) translate([-lcd_fin[0] / 2, -lcd_fin[1] / 2, -tl_par - 1]) cube([lcd_fin[0], lcd_fin[1], tl_par + 2]);
        // LCD screw pilot holes (M3: not through, 1 mm remains)
        for (i = [-1, 1], j = [-1, 1]) tl_su_piano(tl_lc + j * lcd_fori[1] / 2, tl_lx + i * lcd_fori[0] / 2)
            translate([0, 0, -lcd_corn - 1]) cylinder(d = pilota_m3, h = lcd_corn);
        // fixing screw pilot holes (from below)
        for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = pilota_m3, h = 7);
        // ventilation on the back (vertical slots)
        for (i = [0:6]) hull() for (z = [7, tl_s - 7]) translate([tl_L / 2 + (i - 3) * 9, tl_prof + 1, z]) rotate([90, 0, 0]) cylinder(d = 3, h = tl_par + 2, $fn = 20);
    }
}
// display box bottom: closes underneath, 4 M3 screws from below into the shell bosses, tabs to fix it
module display_fondo() {
    gi = 0.3;   // clearance of the centring rim inside the shell walls
    difference() {
        union() {
            translate([-df_orecchia, 0, 0]) arrotondato(tl_L + df_orecchia, tl_prof, df_sp, 3);
            // centring rim inside the shell
            translate([0, 0, df_sp - 0.01]) difference() {
                translate([tl_par + gi, tl_par * (1 + sqrt(2)) + gi + 1.5, 0]) cube([tl_L - 2 * (tl_par + gi), tl_prof - tl_par * (2 + sqrt(2)) - 2 * gi - 1.5, 1.5]);
                translate([tl_par + gi + 1.6, tl_par * (1 + sqrt(2)) + gi + 3.1, -1]) cube([tl_L - 2 * (tl_par + gi + 1.6), tl_prof - tl_par * (2 + sqrt(2)) - 2 * gi - 4.7, 4]);
                for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = tl_bor_d + 0.8, h = 4);
            }
        }
        // shell screws (head recessed underneath)
        for (v = tl_viti()) translate([v[0], v[1], -1]) {
            cylinder(d = passante_m3, h = df_sp + 3);
            cylinder(d = testa_m3, h = 1 + 2);
        }
        // fixing holes in the tabs
        for (x = [-df_orecchia / 2], y = [tl_prof / 2 - 12, tl_prof / 2 + 12])
            translate([x, y, -1]) cylinder(d = passante_m3, h = df_sp + 2);
        // cable passage (near the exit of the I2C module pins, left side)
        translate([tl_par + lcd_gioco[0], tl_prof - 16, -1]) cylinder(d = df_cavo, h = df_sp + 4);
    }
}

module lcd_sagoma() {   // board + frame + I2C module soldered behind (preview only)
    tl_su_piano(tl_lc, tl_lx) {
        translate([-lcd_pcb[0] / 2, -lcd_pcb[1] / 2, -lcd_corn - 1.6]) cube([lcd_pcb[0], lcd_pcb[1], 1.6]);
        translate([-71 / 2, -24 / 2, -lcd_corn]) cube([71, 24, lcd_corn]);
        translate([-lcd_pcb[0] / 2 + 2, lcd_pcb[1] / 2 - 21, -lcd_corn - 1.6 - 10]) cube([42, 19, 10]);
        translate([-lcd_pcb[0] / 2 - 12, lcd_pcb[1] / 2 - 15, -lcd_corn - 1.6 - 8]) cube([14, 10, 3]);   // I2C pins towards the left
    }
}

// ---------------------------------------------------------------- mains cable clamp
module fermacavo() {
    difference() {
        hull() for (s = [-1, 1]) translate([s * fc_int / 2, 0, 0]) cylinder(d = 9, h = 3);
        for (s = [-1, 1]) translate([s * fc_int / 2, 0, -1]) cylinder(d = passante_m3, h = 5);
    }
}

// ---------------------------------------------------------------- assembly with outlines
module assieme() {
    color("#f39c12") scatola();
    color("#e8590c") coperchio();
    color("#e8590c") translate([rete_x, fc_y, fondo + fc_alt]) fermacavo();
    if (tl_sul_coperchio) {
        color("#2b8a3e") translate([0, 0, ez + coperchio_h]) tl_su_coperchio() torretta_lcd();
        %translate([0, 0, ez + coperchio_h]) tl_su_coperchio() lcd_sagoma();
    } else translate([in_x + 40, 0, 0]) {          // separate display box, next to the box
        color("#868e96") display_fondo();
        color("#2b8a3e") translate([0, 0, df_sp]) torretta_lcd();
        %translate([0, 0, df_sp]) lcd_sagoma();
    }
    // outlines (preview only)
    %translate([psu_pos[0], psu_pos[1], fondo]) cube([psu_x, psu_y, psu_h]);
    %translate([bo_pos[0], bo_pos[1], fondo + bo_alt]) cube([bo_x, bo_y, 1.6]);
    %translate([uln_pos[0], uln_pos[1], fondo + uln_aria]) cube([uln_x, uln_y, uln_sp]);
    %translate([pca_pos[0], pca_pos[1], fondo + pca_alt]) cube([pca_dim[0], pca_dim[1], 12]);
    %translate([bss_pos[0], bss_pos[1], fondo]) cube([bss_dim[0], bss_dim[1], 3]);
    %translate([pi_pos[0] + pi_gioco, pi_pos[1] + pi_gioco, ez + coperchio_h]) cube([pi_x, pi_y, 25]);
    %translate([rete_x, 30, fondo + rete_z]) rotate([90, 0, 0]) cylinder(d = 7, h = 40);
    %translate([sw_x - 10.5, -2.4 - 1, fondo + sw_z - 7.5]) cube([21, 22, 15]);
}

// ---------------------------------------------------------------- selection (print orientation)
if      (parte == "assembly")  assieme();
else if (parte == "box")       scatola();
else if (parte == "lid")       translate([0, 0, -ez]) coperchio();          // top face up, resting on the bed
else if (parte == "cable_clamp") fermacavo();
else if (parte == "display_shell")  rotate([0, -90, 0]) torretta_lcd();    // printed on its side: window and slots without supports
else if (parte == "display_bottom") display_fondo();

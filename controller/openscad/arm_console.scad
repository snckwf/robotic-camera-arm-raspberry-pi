// arm_console.scad — Remote bench console for the camera arm
// 2 KY-023 joysticks (left: base + shoulder, right: elbow), 4 12x12 buttons with A14 square cap (head tilt / rotation).
// Inside: Arduino Nano that reads everything and talks to the Raspberry over USB (a single cable, it also carries the power).
// Parts: shell (printed upside down, top face on the bed), bottom, plate holding the buttons.
// Screws: all M3 button head. Bottom: 4 x M3x8. Joysticks: 4 x M3x6 each. Button plate: 2 x M3x6.
// All dimensions in mm.

/* [Part to generate] */
parte = "assembly"; // [assembly, shell, bottom, plate]

/* [Shell] */
L     = 170;    // width
P     = 90;     // depth
H     = 32;     // total height (bottom included)
r_ang = 8;      // plan corner radius
par   = 2.4;    // walls
cielo = 2.4;    // top face thickness
fondo_h = 3;    // bottom thickness
pilota_m3 = 2.5;
passante_m3 = 3.4;

/* [KY-023 joystick] */
joy_x    = 52;          // distance of the joystick centre from the console centre
joy_foro = 26;          // hole in the top for the joystick dome
joy_fori = [20.5, 26.5];// board hole spacing (x, y) around the stick centre: MEASURE
joy_alt  = 11.5;        // from the board face to the underside of the lid: metal bracket height + 0.5 (MEASURE)
joy_pcb  = [26, 34];    // board (5-pin connector towards the back, +y)
joy_col_d = 6.5;

/* [12x12 buttons + 10x10 cap] */
pul_passo = 16;          // distance of the 4 buttons from the centre of the cross
pul_croce = [0, -2];     // centre of the cross
tappo_foro = 10.6;       // square hole for the 10x10 cap
pul_corpo  = 12.4;       // seat for the 12x12 body under the top
pul_sede   = 0.8;        // seat depth: the top stays 1.6 around the cap (cap sticks out ~3.4)
pul_h      = 3.5;        // button body height
piast_sp   = 2.5;        // retaining plate thickness
piast_lato = 50;

/* [Arduino Nano] */
nano     = [18.0, 43.2];  // board
nano_alz = 2;             // support: the components under the board stay free
usb_fin  = [12.5, 11];    // USB window in the back (open at the bottom)

$fn = 48;

// ---------------------------------------------------------------- derived dimensions
z_cielo = H - cielo;                         // underside of the top face
z_pul   = z_cielo + pul_sede;                // top face of the button body
z_piast = z_pul - pul_h;                     // top face of the plate
pulsanti = [[0, 1], [0, -1], [-1, 0], [1, 0]];   // up, down, left, right
function pul_pos(p) = [pul_croce[0] + p[0] * pul_passo, pul_croce[1] + p[1] * pul_passo];
piast_viti = [[pul_croce[0] + 21, pul_croce[1] + 21], [pul_croce[0] - 21, pul_croce[1] - 21]];
col_fondo = [[-L / 2 + 8, -P / 2 + 8], [L / 2 - 8, -P / 2 + 8], [-L / 2 + 8, P / 2 - 8], [L / 2 - 8, P / 2 - 8]];
nano_y1 = P / 2 - par - 0.8;                 // rear edge of the Nano board
nano_y0 = nano_y1 - nano[1];

module pianta(l, p, r, h) hull() for (i = [-1, 1], j = [-1, 1]) translate([i * (l / 2 - r), j * (p / 2 - r), 0]) cylinder(r = r, h = h);

// ---------------------------------------------------------------- shell (system: bottom at z=0, top face at z=H)
module guscio() {
    difference() {
        union() {
            difference() {
                translate([0, 0, fondo_h]) pianta(L, P, r_ang, H - fondo_h);
                translate([0, 0, fondo_h - 1]) pianta(L - 2 * par, P - 2 * par, r_ang - par, H - fondo_h - cielo + 1);
            }
            // bottom screw columns
            for (c = col_fondo) translate([c[0], c[1], fondo_h]) cylinder(d = 9, h = H - fondo_h - 0.1);
            // joystick posts
            for (s = [-1, 1], i = [-1, 1], j = [-1, 1])
                translate([s * joy_x + i * joy_fori[0] / 2, j * joy_fori[1] / 2, z_cielo - joy_alt]) cylinder(d = joy_col_d, h = joy_alt + 0.1);
            // button plate bosses
            for (v = piast_viti) translate([v[0], v[1], z_piast]) cylinder(d = 7, h = z_cielo - z_piast + 0.1);
        }
        // joystick holes
        for (s = [-1, 1]) translate([s * joy_x, 0, z_cielo - 1]) cylinder(d = joy_foro, h = cielo + 2, $fn = 96);
        // buttons: cap hole + body seat
        for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], 0]) {
            translate([-tappo_foro / 2, -tappo_foro / 2, z_cielo - 1]) cube([tappo_foro, tappo_foro, cielo + 2]);
            translate([-pul_corpo / 2, -pul_corpo / 2, z_cielo - 1]) cube([pul_corpo, pul_corpo, pul_sede + 1]);
        }
        // pilot holes
        for (c = col_fondo) translate([c[0], c[1], fondo_h - 1]) cylinder(d = pilota_m3, h = 11);
        for (s = [-1, 1], i = [-1, 1], j = [-1, 1])
            translate([s * joy_x + i * joy_fori[0] / 2, j * joy_fori[1] / 2, z_cielo - joy_alt - 1]) cylinder(d = pilota_m3, h = joy_alt + 0.5, $fn = 24);
        for (v = piast_viti) translate([v[0], v[1], z_piast - 1]) cylinder(d = pilota_m3, h = z_cielo - z_piast + 1.6, $fn = 24);
        // Nano USB window in the back (open at the bottom)
        translate([-usb_fin[0] / 2, P / 2 - par - 1, fondo_h - 1]) cube([usb_fin[0], par + 2, usb_fin[1] + 1]);
        // text engraved on the top
        translate([0, 0, H - 0.6]) linear_extrude(1) {
            for (s = [-1, 1]) translate([s * joy_x, -joy_foro / 2 - 9]) text(s < 0 ? "BASE / SHOULDER" : "ELBOW", size = 4.2, halign = "center", font = "Liberation Sans:style=Bold");
            translate([pul_croce[0], pul_croce[1] - pul_passo - 15]) text("HEAD", size = 4.2, halign = "center", font = "Liberation Sans:style=Bold");
        }
    }
}

// ---------------------------------------------------------------- bottom (printed as is, Nano tabs facing up)
module fondo() {
    difference() {
        union() {
            pianta(L, P, r_ang, fondo_h);
            // Nano cradle: two side walls with inner support
            for (s = [-1, 1]) translate([s * (nano[0] / 2 + 0.3) + (s < 0 ? -2.4 : 0), nano_y0, fondo_h - 0.01]) cube([2.4, nano[1], nano_alz + 1.6 + 1.5]);
            for (s = [-1, 1]) translate([s * (nano[0] / 2 + 0.3) + (s < 0 ? 0 : -1.2), nano_y0, fondo_h - 0.01]) cube([1.2, nano[1], nano_alz]);
        }
        for (c = col_fondo) translate([c[0], c[1], -1]) cylinder(d = passante_m3, h = fondo_h + 2);
        // slots for two cable ties over the Nano
        for (y = [nano_y0 + 8, nano_y1 - 12], s = [-1, 1]) translate([s * (nano[0] / 2 + 5) - 1.5, y, -1]) cube([3, 5, fondo_h + 2]);
        // recesses for adhesive feet (d 10)
        for (c = col_fondo) translate([c[0] * 0.9, c[1] * 0.75, -0.01]) cylinder(d = 10.5, h = 0.6);
    }
}

// ---------------------------------------------------------------- plate pushing the 4 buttons into their seats
module piastrina() {
    difference() {
        translate([pul_croce[0] - piast_lato / 2, pul_croce[1] - piast_lato / 2, 0]) cube([piast_lato, piast_lato, piast_sp]);
        for (v = piast_viti) translate([v[0], v[1], -1]) cylinder(d = passante_m3, h = piast_sp + 2);
        // slots for the legs (pitch 12.5 x 5) and for the wires
        for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], -1]) {
            for (s = [-1, 1]) translate([s * 6.25 - 1.5, -4.5, 0]) cube([3, 9, piast_sp + 2]);
            translate([-3, -3, 0]) cube([6, 6, piast_sp + 2]);
        }
    }
}

// ---------------------------------------------------------------- outlines (preview only)
module sagome() {
    for (s = [-1, 1]) translate([s * joy_x, 0, z_cielo - joy_alt]) {
        translate([-joy_pcb[0] / 2, -joy_pcb[1] / 2, -1.6]) cube([joy_pcb[0], joy_pcb[1] + 6, 1.6]);
        translate([-8, -8, 0]) cube([16, 16, joy_alt - 0.5]);
        translate([0, 0, joy_alt + 3]) cylinder(d = 24, h = 10);
    }
    for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], z_piast]) {
        translate([-6, -6, 0]) cube([12, 12, pul_h]);
        translate([-5, -5, pul_h + 0.6]) cube([10, 10, 4.6]);
    }
    translate([-nano[0] / 2, nano_y0, fondo_h + nano_alz]) cube([nano[0], nano[1], 1.6]);
    translate([-4, nano_y1 - 9, fondo_h + nano_alz + 1.6]) cube([8, 10, 4]);
}

module assieme() {
    color("#1971c2") guscio();
    color("#868e96") fondo();
    color("#e8590c") translate([0, 0, z_piast - piast_sp]) piastrina();
    %sagome();
}

// ---------------------------------------------------------------- selection (print orientation)
if      (parte == "assembly")  assieme();
else if (parte == "shell")     translate([0, 0, H]) rotate([180, 0, 0]) guscio();   // upside down: top face on the bed
else if (parte == "bottom")    fondo();
else if (parte == "plate")     piastrina();

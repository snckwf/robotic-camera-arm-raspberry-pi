// arm_shoulder.scad — Shoulder turret + upper arm (humerus) of the camera arm
// Screws onto the base turntable (4 M3x12 button-head screws, nuts already in the plate seats).
// Shoulder: MG996R on one side, M8x40 bolt in the 608 bearing on the other.
// "Zero-length" balancing: 2 × 7x51 springs in parallel + cord over 2 rollers (A and C).
// All dimensions in mm. Change only the parameters below.

/* [Part to generate] */
parte = "assembly"; // [assembly, turret, upper_arm, roller, yoke]
angolo = 70;       // assembly only: arm angle from vertical (28..100)

/* [Shoulder geometry] */
H         = 88;    // shoulder axle height above the plate
a_molla   = 28;    // distance of roller A above the axle (spring lever arm)
b_molla   = [24, 28, 32]; // cord attachment holes on the arm (calibration)
L_braccio = 150;   // distance shoulder axle - elbow flange

/* [MG996R] */
s_l       = 40.7;  // body length
s_w       = 19.7;  // body width
s_h       = 37;    // body height (bottom - top face)
s_asse    = 10.2;  // distance of the splined shaft from the near short side
s_aletta  = 7.9;   // distance top face - resting face of the tabs
s_fori_l  = 49.5;  // tab hole spacing (long)
s_fori_w  = 10;    // tab hole spacing (short)
corno_off = 6.5;   // servo top face -> outer face of the round horn
corno_d   = 25.5;  // diameter of the round horn seat in the arm
corno_inc = 1.5;   // horn seat depth

/* [Bearing and M8 bolt] */
cusc_d    = 22.1;  // 608 seat (light press-fit)
cusc_h    = 7;
m8_foro   = 8.3;
m8_chiave = 13.3;  // hex head seat (+clearance)
m8_testa  = 5.6;

/* [Structure] */
base_d    = 80;    // base ring diameter
base_h    = 18;
base_foro = 24;    // passage for the M8 nut of the rotating base
m3_passo  = 46;    // M3 holes of the turntable (must match attacco_passo in arm_base.scad)
m3_foro   = 3.4;   // M3 clearance (turret fixing)
rullo_vite = 3.4;  // roller pin: M3 screw through the side plates
rullo_foro = 3.6;  // roller hole: turns freely on the M3
m3_testa  = 6.5;   // M3 button head counterbore (ISO 7380, d 5.7)
m3_presa  = 5;     // thickness under the head (M3x12 screw)
sp_servo  = 5;     // servo side plate thickness
sp_cusc   = 9.6;   // bearing side plate thickness (7 + 0.6 + 2 lip)
rullo_d   = 10;    // diameter of rollers A and C
x_C       = -19;   // position of roller C (above the springs)
y_molle   = 5;     // half the distance between the two springs

/* [Quality] */
$fn = 72;

// ---------------------------------------------------------------- derived dimensions (Y axis = shoulder axle)
y_hub0   = -10;                         // bearing-side face of the arm hub
y_hub1   = 10;                          // servo-side face
y_corno  = y_hub1 - corno_inc;          // horn face in contact with the arm
y_stop   = y_corno + corno_off;         // servo top face
y_ali    = y_stop + s_aletta;           // tab support = outer face of the servo side plate
y_fs0    = y_ali - sp_servo;            // inner face of the servo side plate
y_fc0    = y_hub0 - 1;                  // inner face of the bearing side plate
y_fc1    = y_fc0 - sp_cusc;             // outer face
y_mid    = (y_fs0 + y_fc0) / 2;         // centre of the bay (plane of the springs and the cord)
z_A      = H + a_molla;
x_molle  = x_C - rullo_d / 2;           // spring axis (rear tangent of roller C)
s_z1     = H + s_asse;                  // upper end of the servo body
s_z0     = s_z1 - s_l;                  // lower end
s_zc     = (s_z0 + s_z1) / 2;

echo(str("Bay between the side plates: ", y_fs0 - y_fc0, " mm (centre y=", y_mid, ")"));
echo(str("Roller length: ", y_fs0 - y_fc0 - 1, " mm"));
echo(str("Roller screw: M3 x ", ceil((y_ali - y_fc1 + 6) / 5) * 5));

// ---------------------------------------------------------------- side plate profile (XZ plane)
module profilo_fiancata() {
    hull() {
        translate([-15.5, base_h]) square([31, 8]);
        translate([0, H]) circle(r = 18);
        translate([0, z_A]) circle(r = 8);
        translate([x_C, z_A]) circle(r = 8);
    }
}
module fiancata(y0, y1) {   // extrudes the profile between y0 and y1 (y0 < y1)
    translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0) profilo_fiancata();
}
module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 32);
}

// ---------------------------------------------------------------- turret
module torretta() {
    difference() {
        union() {
            // base ring
            cylinder(d = base_d, h = base_h, $fn = 120);
            // side plates
            fiancata(y_fs0, y_ali);
            fiancata(y_fc1, y_fc0);
            // tab screw bosses (towards the bay)
            for (z = [s_zc - s_fori_l / 2, s_zc + s_fori_l / 2], x = [-s_fori_w / 2, s_fori_w / 2])
                translate([x, y_fs0 + 0.01, z]) rotate([90, 0, 0]) cylinder(d = 8, h = y_fs0 - (y_stop + 0.5), $fn = 32);
            // spring anchoring cheeks (horizontal M3 screw)
            for (y = [y_mid - y_molle - 7.5, y_mid + y_molle + 4.5])
                translate([x_molle - 4, y, base_h - 0.01]) cube([8, 3, 18]);
        }
        // central passage and M3 holes with counterbore
        translate([0, 0, -1]) cylinder(d = base_foro, h = base_h + 2);
        for (x = [-1, 1], y = [-1, 1])
            translate([x * m3_passo / 2, y * m3_passo / 2, -1]) {
                cylinder(d = m3_foro, h = base_h + 2, $fn = 32);
                translate([0, 0, 1 + m3_presa]) cylinder(d = m3_testa, h = base_h, $fn = 32);
            }
        // servo body window
        translate([-s_w / 2 - 0.3, y_fs0 - 1, s_z0 - 0.3]) cube([s_w + 0.6, sp_servo + 2, s_l + 0.6]);
        // tab screw pilot holes (M3x10 driven into the plastic)
        for (z = [s_zc - s_fori_l / 2, s_zc + s_fori_l / 2], x = [-s_fori_w / 2, s_fori_w / 2])
            foro_y(x, z, 2.5, y_stop, y_ali + 1);
        // 608 bearing seat (from the bay side) + outer lip
        foro_y(0, H, cusc_d, y_fc0 - cusc_h - 0.6, y_fc0 + 1);
        foro_y(0, H, 17, y_fc1 - 1, y_fc0);
        // holes for rollers A and C
        foro_y(0, z_A, rullo_vite);
        foro_y(x_C, z_A, rullo_vite);
        // holes for the cheek M3 screw (3 pretension positions)
        for (z = [base_h + 6, base_h + 10, base_h + 14]) foro_y(x_molle, z, 3.4);
    }
}

// ---------------------------------------------------------------- upper arm (local system: shoulder axle = origin, arm along +X)
module braccio() {
    difference() {
        union() {
            // hub + straight 20x16 beam (narrow near the hub to pass under roller A)
            translate([0, y_hub1, 0]) rotate([90, 0, 0]) cylinder(r = 14, h = y_hub1 - y_hub0);
            translate([0, y_hub0, -8]) cube([L_braccio, y_hub1 - y_hub0, 16]);
            translate([L_braccio - 18, y_hub0, -8]) cube([18 + 0.01, y_hub1 - y_hub0, 16]);
        }
        // M8 bolt hole + hex head seat (under the horn)
        translate([0, 30, 0]) rotate([90, 0, 0]) cylinder(d = m8_foro, h = 60, $fn = 48);
        translate([0, y_corno + 0.01, 0]) rotate([90, 0, 0]) rotate(30)
            cylinder(d = m8_chiave / cos(30), h = m8_testa, $fn = 6);
        // round horn seat
        translate([0, y_hub1 + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = corno_d, h = corno_inc + 0.01);
        // cord attachment holes (through the thickness)
        for (b = b_molla) translate([b, 0, -10]) cylinder(d = 3, h = 20, $fn = 24);
        // lightening
        hull() for (x = [48, L_braccio - 32]) translate([x, 20, 0]) rotate([90, 0, 0]) cylinder(d = 8, h = 40, $fn = 32);
        // elbow joint: 2 M3 through holes in the thickness (M3x35 screws through the elbow support)
        for (y = [-5, 5]) translate([L_braccio - 7, y, -20]) cylinder(d = 3.4, h = 40, $fn = 24);
    }
}

// ---------------------------------------------------------------- small parts
module rullo() {
    l = y_fs0 - y_fc0 - 1;
    difference() {
        cylinder(d = rullo_d, h = l);
        translate([0, 0, -1]) cylinder(d = rullo_foro, h = l + 2, $fn = 32);   // M3 pin
        // groove for the cord
        translate([0, 0, l / 2]) rotate_extrude() translate([rullo_d / 2 + 0.6, 0]) circle(r = 1.2, $fn = 24);
    }
}
module giogo() {
    difference() {
        hull() for (y = [-y_molle - 3, y_molle + 3]) translate([0, y, 0]) cylinder(r = 3.5, h = 4);
        for (y = [-y_molle, y_molle]) translate([0, y, -1]) cylinder(d = 2.2, h = 6, $fn = 24);
        translate([0, 0, -1]) cylinder(d = 2.2, h = 6, $fn = 24);
    }
}

// ---------------------------------------------------------------- assembly
module mg996r() {
    color("dimgray") translate([-s_w / 2, y_stop, s_z0]) cube([s_w, s_h, s_l]);
    color("dimgray") translate([-s_w / 2, y_ali, s_zc - 27]) cube([s_w, 2.5, 54]);
    color("white") translate([0, y_stop + 0.01, H]) rotate([90, 0, 0]) cylinder(d = 24, h = y_stop - y_corno);
}
module assieme() {
    color("lightsteelblue") torretta();
    translate([0, 0, H]) rotate([0, -(90 - angolo), 0]) color("orange") braccio();
    mg996r();
    color("tomato") translate([0, y_fc0 - 0.5, z_A]) rotate([90, 0, 0]) translate([0, 0, -(y_fs0 - y_fc0 - 1)]) rullo();
    color("tomato") translate([x_C, y_fc0 - 0.5, z_A]) rotate([90, 0, 0]) translate([0, 0, -(y_fs0 - y_fc0 - 1)]) rullo();
    color("dimgray", 0.6) {
        translate([0, y_fc0 - 0.6, H]) rotate([90, 0, 0]) difference() { cylinder(d = 22, h = 7); translate([0, 0, -1]) cylinder(d = 8, h = 9); }
        translate([0, y_corno - m8_testa, H]) rotate([90, 0, 0]) cylinder(d = 8, h = 40);
    }
    // springs (at working length for the given angle)
    d = norm([sin(angolo) * b_molla[1], 0, cos(angolo) * b_molla[1] - a_molla]);
    for (s = [-1, 1]) color("silver") translate([x_molle, y_mid + s * y_molle, base_h + 10])
        cylinder(d = 7, h = 35 + d);
}

// ---------------------------------------------------------------- selection
if      (parte == "assembly")  assieme();
else if (parte == "turret")    torretta();
else if (parte == "upper_arm") translate([0, 0, -y_hub0]) rotate([90, 0, 0]) braccio();   // printed on its side
else if (parte == "roller")    rullo();
else if (parte == "yoke")      giogo();

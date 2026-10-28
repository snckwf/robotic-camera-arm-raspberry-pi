// arm_elbow.scad — Elbow support (MG996R) + forearm of the camera arm
// The support slips onto the end of the upper arm (20x16 humerus) and is locked with 2 M3x35 screws.
// Servo side: MG996R with round horn on the forearm. Opposite side: M3x16 button-head screw as pin.
// Local system = the arm one: shoulder axle at x=0, arm along +X, elbow axle parallel to Y.
// All dimensions in mm. Change only the parameters below.

/* [Part to generate] */
parte = "assembly"; // [assembly, support, forearm]
piega = -60;       // assembly only: forearm angle relative to the arm (-140..140)

/* [Arm dimensions (must match arm_shoulder.scad)] */
L_braccio = 150;   // end of the arm
innesto   = 22;    // length of the arm section inserted in the support
x_viti    = L_braccio - 7;
y_viti    = 5;     // M3 screws at y = +/-5
br_y      = 10;    // half arm width
br_z      = 8;     // half arm thickness

/* [Elbow] */
x_e       = 168;   // elbow axle
L_avamb   = 130;   // elbow axle -> head flange
gioco     = 0.2;

/* [MG996R (as for the shoulder)] */
s_l       = 40.7;
s_w       = 19.7;
s_asse    = 10.2;
s_aletta  = 7.9;
s_fori_l  = 49.5;
s_fori_w  = 10;
corno_off = 6.5;
corno_d   = 25.5;
corno_inc = 1.5;

/* [Structure] */
sp_servo  = 5;
sp_perno  = 6;
h_z       = 16;    // half height of the support (print plane at z = -h_z)

/* [Quality] */
$fn = 72;

// ---------------------------------------------------------------- derived dimensions (same as the shoulder)
y_hub0  = -10;
y_hub1  = 10;
y_corno = y_hub1 - corno_inc;
y_stop  = y_corno + corno_off;      // servo top face
y_ali   = y_stop + s_aletta;        // outer face of the servo side plate
y_fs0   = y_ali - sp_servo;
y_fp0   = y_hub0 - 1;               // inner face of the pin side plate
y_fp1   = y_fp0 - sp_perno;
s_x1    = x_e + s_asse;             // servo body along X, towards the arm
s_x0    = s_x1 - s_l;
s_xc    = (s_x0 + s_x1) / 2;
x_ini   = L_braccio - innesto;      // sleeve start
x_fine  = L_braccio + 2;            // sleeve bottom

echo(str("Hub-sleeve clearance: ", x_e - 14 - x_fine, " mm"));

module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 32);
}

// ---------------------------------------------------------------- elbow support
module supporto() {
    difference() {
        union() {
            // sleeve around the end of the arm
            translate([x_ini, y_fp1, -h_z]) cube([x_fine - x_ini, y_fs0 - y_fp1, 2 * h_z]);
            // servo side plate
            hull() {
                translate([s_x0 - 11, y_fs0, -h_z]) cube([1, sp_servo, 2 * h_z]);
                translate([x_e, y_ali, 0]) rotate([90, 0, 0]) cylinder(r = h_z, h = sp_servo);
                translate([s_xc + s_fori_l / 2 + 5, y_fs0, -h_z]) cube([1, sp_servo, 2 * h_z]);
            }
            // pin side plate
            hull() {
                translate([x_ini, y_fp1, -h_z]) cube([1, sp_perno, 2 * h_z]);
                translate([x_e, y_fp0, 0]) rotate([90, 0, 0]) cylinder(r = h_z, h = sp_perno);
            }
        }
        // arm seat (open towards the shoulder)
        translate([x_ini - 1, -br_y - gioco, -br_z - gioco]) cube([L_braccio - x_ini + 1 + gioco, 2 * (br_y + gioco), 2 * (br_z + gioco)]);
        // upper part of the servo entering the bay + window in the side plate
        translate([s_x0 - 0.3, y_stop - 0.3, -s_w / 2 - 0.3]) cube([s_l + 0.6, y_ali - y_stop + 1.3, s_w + 0.6]);
        // tab pilot holes (M3x10 driven into the plastic)
        for (x = [s_xc - s_fori_l / 2, s_xc + s_fori_l / 2], z = [-s_fori_w / 2, s_fori_w / 2])
            foro_y(x, z, 2.5, y_fs0 - 1, y_ali + 1);
        // elbow pin: M3 screw driven into the side plate
        foro_y(x_e, 0, 2.5, y_fp1 - 1, y_fp0 + 1);
        // front chamfers of the sleeve (more travel for the forearm)
        for (s = [-1, 1]) translate([x_fine, y_fp0, s * h_z]) rotate([0, 45, 0]) translate([-3.5, 0, -3.5]) cube([7, y_fs0 - y_fp0, 7]);
        // bay for the forearm hub
        translate([x_fine, y_fp0, -h_z - 1]) cube([60, y_fs0 - y_fp0, 2 * h_z + 2]);
        // vertical M3x35 screws: head on top (counterbore), nut below (hex seat)
        for (y = [-y_viti, y_viti]) translate([x_viti, y, 0]) {
            translate([0, 0, -h_z - 1]) cylinder(d = 3.4, h = 2 * h_z + 2, $fn = 24);
            translate([0, 0, h_z - 3]) cylinder(d = 6.5, h = 4, $fn = 32);
            translate([0, 0, -h_z - 0.01]) rotate(30) cylinder(d = 6.4 / cos(30), h = 3, $fn = 6);
        }
    }
}

// ---------------------------------------------------------------- forearm (local: elbow axle = origin, along +X)
module avambraccio() {
    difference() {
        union() {
            translate([0, y_hub1, 0]) rotate([90, 0, 0]) cylinder(r = 14, h = y_hub1 - y_hub0);
            translate([0, y_hub0, -br_z]) cube([L_avamb, y_hub1 - y_hub0, 2 * br_z]);
        }
        // round horn seat
        translate([0, y_hub1 + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = corno_d, h = corno_inc + 0.01);
        // M3 pin hole (opposite side): the hub turns on the screw
        foro_y(0, 0, 3.4, y_hub0 - 1, 2);
        // lightening
        hull() for (x = [24, L_avamb - 30]) translate([x, 20, 0]) rotate([90, 0, 0]) cylinder(d = 8, h = 40, $fn = 32);
        // head joint: 2 M3 holes in the thickness (same pattern as the arm)
        for (y = [-y_viti, y_viti]) translate([L_avamb - 7, y, -20]) cylinder(d = 3.4, h = 40, $fn = 24);
    }
}

// ---------------------------------------------------------------- assembly
module mg996r() {
    color("dimgray") translate([s_x0, y_stop, -s_w / 2]) cube([s_l, 37, s_w]);
    color("dimgray") translate([s_xc - 27, y_ali, -s_w / 2]) cube([54, 2.5, s_w]);
    color("white") translate([x_e, y_stop + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = 24, h = y_stop - y_corno);
}
module braccio_finale() {   // last section of the arm, for reference only
    color("orange", 0.5) translate([L_braccio - 40, -br_y, -br_z]) cube([40, 2 * br_y, 2 * br_z]);
}
module assieme() {
    braccio_finale();
    color("lightsteelblue") supporto();
    mg996r();
    color("gold") translate([x_e, 0, 0]) rotate([0, -piega, 0]) avambraccio();
}

// ---------------------------------------------------------------- selection
if      (parte == "assembly")    assieme();
else if (parte == "support")     translate([0, 0, h_z]) supporto();                          // on the bed at z = -h_z
else if (parte == "forearm")     translate([0, 0, -y_hub0]) rotate([90, 0, 0]) avambraccio(); // on its side

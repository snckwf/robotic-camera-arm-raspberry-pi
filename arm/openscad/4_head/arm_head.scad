// arm_head.scad — Head of the camera arm
// base_testa (head base): slips onto the tip of the forearm (2 M3x25 screws) and carries the TILT MG90S (pitch).
// culla (cradle):         turns on the tilt and carries the ROTATION MG90S around the optical axis (straightens the image).
// piastra (plate):        on the rotation servo horn; camera v2 (IMX219) + WS2812B 24-LED ring.
// Local system = the forearm one: elbow axle at x=0, forearm along +X, tip at x=130.
// All dimensions in mm. Change only the parameters below.

/* [Part to generate] */
parte = "assembly"; // [assembly, head_base, cradle, plate]
tilt  = -45;       // assembly only: pitch (-100..100)
roll  = 0;         // assembly only: camera rotation

/* [Forearm (as in arm_elbow.scad)] */
L_av    = 130;
av_y    = 10;
av_z    = 8;
x_viti  = L_av - 7;
y_viti  = 5;
gioco   = 0.2;

/* [MG90S] */
m_l      = 22.8;   // body length
m_w      = 12.2;   // width
m_h      = 22.7;   // bottom -> top face
m_asse   = 6.0;    // axle from the near short side
m_aletta = 4.3;    // top face -> top face of the tabs
m_ala_sp = 2.5;    // tab thickness
m_fori   = 27.8;   // tab hole spacing
m_corno  = 9.6;    // top face of the body -> outer face of the fitted horn arm
                   // (gear tower ~4 + horn hub): MEASURE on the servo with the horn fitted
sq_inc   = 1.6;    // single horn seat depth
sq_l     = 16;     // horn arm length (centre -> outer hole)
sq_mozzo_d = 8.0;  // recess for the horn hub (MG90S hub ~7.2 + clearance)
sq_mozzo_p = 2.2;  // how far the hub sticks out beyond the arm on the part side (total recess = sq_inc + this)
sq_asola  = [6, 14];
/* [MG90S cross horn on the camera plate] */
cr_l1    = 17.5;     // long arm: centre -> end (measure)
cr_l2    = 10.5;   // short arm: centre -> end (measure)
cr_fine  = 5.6;    // width at the arm ends (+ clearance)
cr_base  = 7.0;    // width of the arms near the hub (+ clearance)
vite_c_d = 2.3;    // central screw hole (horn screw, M2)
rialzo_d = 11;     // central boss on the front of the plate (floor for the central screw)  // section of the arm with the small holes (radius from..to): slot for the horn screws

/* [Camera v2 IMX219] */
cam_w    = 25;
cam_h    = 23.86;
cam_ott  = 9.46;   // lens centre from the top edge
cam_fx   = 21;     // horizontal hole spacing
cam_fy   = [2, 14.5]; // holes from the top edge
cam_dist = 5.5;    // standoffs (leave room for the central boss of the plate)

/* [WS2812B 24-LED ring] */
ring_de  = 66;
ring_di  = 52;
piastra_d = 72;
piastra_s = 3;

/* [Quality] */
$fn = 64;

// ---------------------------------------------------------------- derived dimensions
hub_r   = 9;
x_t     = L_av + 2 + hub_r + 2;      // tilt axle (2 mm clearance from the sleeve)
hub_y0  = -7.5;
hub_y1  = 9;
y_cor   = hub_y1 - sq_inc;           // tilt horn face
y_top   = y_cor + m_corno;           // top face of the tilt servo
y_ali   = y_top + m_aletta;          // outer face of the servo side plate
y_fs0   = y_ali - 3;                 // servo side plate 3 thick
y_fp0   = hub_y0 - 0.5;              // pin side plate: inner face
y_fp1   = y_fp0 - 4;
t_x1    = x_t + m_asse;              // tilt servo body along -X
t_x0    = t_x1 - m_l;
t_xc    = (t_x0 + t_x1) / 2;
x_m0    = L_av - 22;                 // sleeve start
x_m1    = L_av + 2;
// cradle (local: tilt axle = origin)
r_y     = 1;                         // camera rotation axis (y)
r_top   = 45;                        // top face of the rotation servo (x)
r_ali   = r_top - m_aletta;          // top face of the tabs
r_pf    = r_ali - m_ala_sp;          // front face of the small plate: the underside of the tabs rests on it
r_z0    = -m_asse;                   // rotation servo body along +Z
r_z1    = r_z0 + m_l;
r_zc    = (r_z0 + r_z1) / 2;
x_pc    = r_top + m_corno - sq_inc;  // rear face of the camera plate (cradle local)

echo(str("Cradle-sleeve clearance: ", x_t - hub_r - x_m1, " mm"));

module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 24);
}
module sede_squadretta(h) {   // single-arm horn, arm towards +X
    // the MG90S horn hub also sticks out beyond the arm face: deeper round recess
    cylinder(d = sq_mozzo_d, h = h + sq_mozzo_p);
    hull() { cylinder(d = 7.6, h = h); translate([sq_l, 0, 0]) cylinder(d = 4.6, h = h); }
}

// ---------------------------------------------------------------- head base
module base_testa() {
    hz = 12;
    difference() {
        union() {
            translate([x_m0, y_fp1, -hz]) cube([x_m1 - x_m0, y_fs0 - y_fp1, 2 * hz]);
            hull() {   // tilt servo side plate
                translate([t_xc - m_fori / 2 - 4, y_fs0, -hz]) cube([1, 3, 2 * hz]);
                translate([x_t, y_ali, 0]) rotate([90, 0, 0]) cylinder(r = hz, h = 3);
                translate([t_xc + m_fori / 2 + 3, y_fs0, -hz]) cube([1, 3, 2 * hz]);
            }
            hull() {   // pin side plate
                translate([x_m0, y_fp1, -hz]) cube([1, 4, 2 * hz]);
                translate([x_t, y_fp0, 0]) rotate([90, 0, 0]) cylinder(r = hz, h = 4);
            }
        }
        // forearm seat
        translate([x_m0 - 1, -av_y - gioco, -av_z - gioco]) cube([L_av - x_m0 + 1 + gioco, 2 * (av_y + gioco), 2 * (av_z + gioco)]);
        // upper part of the tilt servo + window
        translate([t_x0 - 0.3, y_top - 0.3, -m_w / 2 - 0.3]) cube([m_l + 0.6, y_ali - y_top + 1.3, m_w + 0.6]);
        // tab holes (M2 self-tapping)
        for (x = [t_xc - m_fori / 2, t_xc + m_fori / 2]) foro_y(x, 0, 1.8, y_fs0 - 1, y_ali + 1);
        // tilt pin: M3 self-tapping screw in the side plate
        foro_y(x_t, 0, 2.5, y_fp1 - 1, y_fp0 + 1);
        // cradle bay
        translate([x_m1, y_fp0, -hz - 1]) cube([40, y_fs0 - y_fp0, 2 * hz + 2]);
        // vertical M3x25 screws
        for (y = [-y_viti, y_viti]) translate([x_viti, y, 0]) {
            translate([0, 0, -hz - 1]) cylinder(d = 3.4, h = 2 * hz + 2, $fn = 24);
            translate([0, 0, hz - 2.5]) cylinder(d = 6.5, h = 4, $fn = 32);
            translate([0, 0, -hz - 0.01]) rotate(30) cylinder(d = 6.4 / cos(30), h = 2.6, $fn = 6);
        }
    }
}

// ---------------------------------------------------------------- cradle (local: tilt axle = origin)
module culla() {
    difference() {
        union() {
            translate([0, hub_y1, 0]) rotate([90, 0, 0]) cylinder(r = hub_r, h = hub_y1 - hub_y0);
            // solid neck near the hub: gives material to the horn arm screws
            hull() {
                translate([0, hub_y0, 0]) rotate([-90, 0, 0]) cylinder(r = hub_r, h = hub_y1 - hub_y0);
                translate([14, hub_y0, -hub_r]) cube([1, hub_y1 - hub_y0, 2 * hub_r]);
            }
            // sides
            for (y = [[hub_y0, r_y - m_w / 2 - 0.4], [r_y + m_w / 2 + 0.4, hub_y1]])
                union() {   // narrow neck near the hub (lets the tilt turn +/-90 degrees)
                    hull() {
                        translate([0, y[0], 0]) rotate([-90, 0, 0]) cylinder(r = hub_r, h = y[1] - y[0]);
                        translate([14, y[0], -hub_r]) cube([1, y[1] - y[0], 2 * hub_r]);
                    }
                    translate([14, y[0], r_z0 - 6]) cube([r_pf - 14 + 0.1, y[1] - y[0], r_z1 - r_z0 + 12]);
                }
            // tab plate (the servo goes in from the front, bottom first, and the tabs rest here in front)
            translate([r_pf - 3, hub_y0, r_z0 - 6]) cube([3, hub_y1 - hub_y0, r_z1 - r_z0 + 12]);
        }
        // tilt servo horn seat (+Y face of the hub), arm towards +X
        translate([0, hub_y1 + 0.01, 0]) rotate([90, 0, 0]) sede_squadretta(sq_inc + 0.01);
        // 1.5-wide slot under the arm: the horn self-tapping screws grip the sides of the slot
        translate([0, hub_y1 - sq_inc + 0.01, 0]) rotate([90, 0, 0]) linear_extrude(8)
            hull() for (r = sq_asola) translate([r, 0]) circle(d = 1.5, $fn = 16);
        // M3 pin hole
        foro_y(0, 0, 3.4, hub_y0 - 1, 0);
        // rotation servo body + window
        translate([r_top - m_h - 1, r_y - m_w / 2 - 0.3, r_z0 - 0.3]) cube([m_h + 2, m_w + 0.6, m_l + 0.6]);
        // tab holes (M2)
        for (z = [r_zc - m_fori / 2, r_zc + m_fori / 2])
            translate([r_pf - 4, r_y, z]) rotate([0, 90, 0]) cylinder(d = 1.8, h = 5, $fn = 24);
        // notches at the ends of the window to let the servo cable through
        for (z = [r_z0 - 0.3 - 2.5, r_z1 + 0.3]) translate([r_pf - 3.5, r_y - 2.5, z - 0.01]) cube([4, 5, 2.52]);
    }
}

// ---------------------------------------------------------------- camera plate (local: rotation axis = X axis, rear face at x=0)
module sede_croce(h) {   // cross horn: long arms along Y, short along Z (plate system)
    for (a = [0, 180]) rotate([a, 0, 0]) hull() {
        rotate([0, 90, 0]) cylinder(d = cr_base, h = h);
        translate([0, cr_l1, 0]) rotate([0, 90, 0]) cylinder(d = cr_fine, h = h);
    }
    for (a = [90, 270]) rotate([a, 0, 0]) hull() {
        rotate([0, 90, 0]) cylinder(d = cr_base, h = h);
        translate([0, cr_l2, 0]) rotate([0, 90, 0]) cylinder(d = cr_fine, h = h);
    }
}
module piastra() {
    sp_c = sq_inc + sq_mozzo_p + 1.6;          // thickness at the centre: hub recess + 1.6 floor for the central screw
    difference() {
        union() {
            rotate([0, 90, 0]) cylinder(d = piastra_d, h = piastra_s, $fn = 120);
            // central boss on the front
            rotate([0, 90, 0]) cylinder(d = rialzo_d, h = sp_c, $fn = 48);
            // camera standoffs
            for (y = [-cam_fx / 2, cam_fx / 2], f = cam_fy)
                translate([piastra_s - 0.01, y, cam_ott - f]) rotate([0, 90, 0]) cylinder(d = 4.5, h = cam_dist);
        }
        // cross horn seat (rear face) + hub recess (blind)
        translate([-0.01, 0, 0]) sede_croce(sq_inc + 0.01);
        translate([-0.01, 0, 0]) rotate([0, 90, 0]) cylinder(d = sq_mozzo_d, h = sq_inc + sq_mozzo_p + 0.01, $fn = 32);
        // central screw: from the front it goes through the 1.6 mm floor and screws into the servo shaft (head resting on the boss)
        translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = vite_c_d, h = sp_c + 2, $fn = 20);
        // 2.2 through slots along the 4 arms: screws from the front into the small holes of the horn
        for (a = [0, 180]) rotate([a, 0, 0]) hull() for (r = [rialzo_d / 2 + 1.2, cr_l1 - 1.5]) translate([-1, r, 0]) rotate([0, 90, 0]) cylinder(d = 2.2, h = piastra_s + 2, $fn = 16);
        for (a = [90, 270]) rotate([a, 0, 0]) hull() for (r = [rialzo_d / 2 + 1.2, cr_l2 - 1.5]) translate([-1, r, 0]) rotate([0, 90, 0]) cylinder(d = 2.2, h = piastra_s + 2, $fn = 16);
        // LED ring seat (camera side: the LEDs face forwards, same direction as the lens)
        translate([piastra_s - 1, 0, 0]) rotate([0, 90, 0]) difference() {
            cylinder(d = ring_de + 0.6, h = 2, $fn = 120);
            translate([0, 0, -1]) cylinder(d = ring_di - 0.6, h = 4, $fn = 120);
        }
        // camera M2 pilot holes
        for (y = [-cam_fx / 2, cam_fx / 2], f = cam_fy)
            translate([0, y, cam_ott - f]) rotate([0, 90, 0]) cylinder(d = 1.8, h = 12);
        // slot for the camera ribbon (under the board)
        translate([-1, -9, cam_ott - cam_h - 4]) cube([piastra_s + 2, 18, 2.2]);
        // ring cable holes (5V, DIN, GND)
        for (a = [200, 215]) rotate([a, 0, 0]) translate([-1, 0, (ring_di / 2 + ring_de / 2) / 2]) rotate([0, 90, 0]) cylinder(d = 2.5, h = piastra_s + 2);
    }
}

// ---------------------------------------------------------------- assembly
module mg90s_tilt() {
    color("royalblue") translate([t_x0, y_top, -m_w / 2]) cube([m_l, m_h, m_w]);
    color("royalblue") translate([t_xc - 16.25, y_ali, -m_w / 2]) cube([32.5, 2.5, m_w]);
}
module mg90s_roll() {
    color("royalblue") translate([r_top - m_h, r_y - m_w / 2, r_z0]) cube([m_h, m_w, m_l]);
    color("royalblue") translate([r_pf, r_y - m_w / 2, r_zc - 16.25]) cube([m_ala_sp, m_w, 32.5]);
}
module camera() {
    color("darkgreen") translate([piastra_s + cam_dist, -cam_w / 2, cam_ott - cam_h]) cube([1, cam_w, cam_h]);
    color("black") translate([piastra_s + cam_dist + 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = 8, h = 6);
    color("white", 0.8) translate([piastra_s - 1, 0, 0]) rotate([0, 90, 0]) difference() {
        cylinder(d = ring_de, h = 3.2, $fn = 120); translate([0, 0, -1]) cylinder(d = ring_di, h = 6, $fn = 120); }
}
module assieme() {
    color("gold", 0.6) translate([L_av - 40, -av_y, -av_z]) cube([40, 2 * av_y, 2 * av_z]);
    color("lightsteelblue") base_testa();
    mg90s_tilt();
    translate([x_t, 0, 0]) rotate([0, -tilt, 0]) {
        color("orange") culla();
        mg90s_roll();
        translate([x_pc, r_y, 0]) rotate([roll, 0, 0]) { color("tomato") piastra(); camera(); }
    }
}

// ---------------------------------------------------------------- selection
if      (parte == "assembly")   assieme();
else if (parte == "head_base")  translate([0, 0, 12]) base_testa();                  // on the bed at z = -12
else if (parte == "cradle")     translate([0, 0, -hub_y0]) rotate([90, 0, 0]) culla(); // on side -Y
else if (parte == "plate")      rotate([0, -90, 0]) piastra();                          // rear face on the bed

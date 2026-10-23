// braccio_testa.scad — Testa del braccio telecamera
// base_testa: calza sulla punta dell'avambraccio (2 viti M3x25) e porta l'MG90S del TILT (beccheggio).
// culla:      ruota sul tilt e porta l'MG90S di ROTAZIONE attorno all'asse ottico (raddrizza l'immagine).
// piastra:    sulla squadretta del servo di rotazione; camera v2 (IMX219) + anello WS2812B 24 LED.
// Sistema locale = quello dell'avambraccio: asse gomito in x=0, avambraccio lungo +X, punta a x=130.
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Parte da generare] */
parte = "assieme"; // [assieme, base_testa, culla, piastra]
tilt  = -45;       // solo assieme: beccheggio (-100..100)
roll  = 0;         // solo assieme: rotazione camera

/* [Avambraccio (come braccio_gomito.scad)] */
L_av    = 130;
av_y    = 10;
av_z    = 8;
x_viti  = L_av - 7;
y_viti  = 5;
gioco   = 0.2;

/* [MG90S] */
m_l      = 22.8;   // lunghezza corpo
m_w      = 12.2;   // larghezza
m_h      = 22.7;   // fondo -> faccia superiore
m_asse   = 6.0;    // asse dal lato corto vicino
m_aletta = 4.3;    // faccia superiore -> faccia superiore delle alette
m_ala_sp = 2.5;    // spessore alette
m_fori   = 27.8;   // interasse fori alette
m_corno  = 9.6;    // faccia superiore del corpo -> faccia esterna del braccio della squadretta montata
                   // (torretta ingranaggi ~4 + mozzo squadretta): MISURARE sul servo con squadretta montata
sq_inc   = 1.6;    // profondita' sede squadretta singola
sq_l     = 16;     // lunghezza braccio squadretta (centro -> foro esterno)
sq_mozzo_d = 8.0;  // incavo per il mozzo della squadretta (mozzo MG90S ~7,2 + gioco)
sq_mozzo_p = 2.2;  // quanto il mozzo sporge oltre il braccio dal lato del pezzo (incavo totale = sq_inc + questo)
sq_asola  = [6, 14];
/* [Squadretta a croce MG90S sulla piastra camera] */
cr_l1    = 17.5;     // braccio lungo: centro -> estremita' (misurare)
cr_l2    = 10.5;   // braccio corto: centro -> estremita' (misurare)
cr_fine  = 5.6;    // larghezza alle estremita' dei bracci (+ gioco)
cr_base  = 7.0;    // larghezza dei bracci vicino al mozzo (+ gioco)
vite_c_d = 2.3;    // foro vite centrale (vite della squadretta, M2)
rialzo_d = 11;     // rialzo centrale sul davanti della piastra (fondo per la vite centrale)  // tratto del braccio con i forellini (raggio da..a): asola per le viti della squadretta

/* [Camera v2 IMX219] */
cam_w    = 25;
cam_h    = 23.86;
cam_ott  = 9.46;   // centro obiettivo dal bordo alto
cam_fx   = 21;     // interasse fori orizzontale
cam_fy   = [2, 14.5]; // fori dal bordo alto
cam_dist = 5.5;    // distanziali (lasciano spazio al rialzo centrale della piastra)

/* [Anello WS2812B 24 LED] */
ring_de  = 66;
ring_di  = 52;
piastra_d = 72;
piastra_s = 3;

/* [Qualita'] */
$fn = 64;

// ---------------------------------------------------------------- quote derivate
hub_r   = 9;
x_t     = L_av + 2 + hub_r + 2;      // asse tilt (2 mm di gioco dal manicotto)
hub_y0  = -7.5;
hub_y1  = 9;
y_cor   = hub_y1 - sq_inc;           // faccia squadretta tilt
y_top   = y_cor + m_corno;           // faccia superiore servo tilt
y_ali   = y_top + m_aletta;          // faccia esterna fiancata servo
y_fs0   = y_ali - 3;                 // fiancata servo spessa 3
y_fp0   = hub_y0 - 0.5;              // fiancata perno: interna
y_fp1   = y_fp0 - 4;
t_x1    = x_t + m_asse;              // corpo servo tilt lungo -X
t_x0    = t_x1 - m_l;
t_xc    = (t_x0 + t_x1) / 2;
x_m0    = L_av - 22;                 // inizio manicotto
x_m1    = L_av + 2;
// culla (locale: asse tilt = origine)
r_y     = 1;                         // asse di rotazione camera (y)
r_top   = 45;                        // faccia superiore servo rotazione (x)
r_ali   = r_top - m_aletta;          // faccia superiore delle alette
r_pf    = r_ali - m_ala_sp;          // faccia anteriore della piastrina: ci appoggia il sotto delle alette
r_z0    = -m_asse;                   // corpo servo rotazione lungo +Z
r_z1    = r_z0 + m_l;
r_zc    = (r_z0 + r_z1) / 2;
x_pc    = r_top + m_corno - sq_inc;  // faccia posteriore piastra camera (locale culla)

echo(str("Gioco culla-manicotto: ", x_t - hub_r - x_m1, " mm"));

module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 24);
}
module sede_squadretta(h) {   // squadretta a braccio singolo, braccio verso +X
    // il mozzo della squadretta MG90S sporge anche oltre la faccia del braccio: incavo tondo piu' profondo
    cylinder(d = sq_mozzo_d, h = h + sq_mozzo_p);
    hull() { cylinder(d = 7.6, h = h); translate([sq_l, 0, 0]) cylinder(d = 4.6, h = h); }
}

// ---------------------------------------------------------------- base testa
module base_testa() {
    hz = 12;
    difference() {
        union() {
            translate([x_m0, y_fp1, -hz]) cube([x_m1 - x_m0, y_fs0 - y_fp1, 2 * hz]);
            hull() {   // fiancata servo tilt
                translate([t_xc - m_fori / 2 - 4, y_fs0, -hz]) cube([1, 3, 2 * hz]);
                translate([x_t, y_ali, 0]) rotate([90, 0, 0]) cylinder(r = hz, h = 3);
                translate([t_xc + m_fori / 2 + 3, y_fs0, -hz]) cube([1, 3, 2 * hz]);
            }
            hull() {   // fiancata perno
                translate([x_m0, y_fp1, -hz]) cube([1, 4, 2 * hz]);
                translate([x_t, y_fp0, 0]) rotate([90, 0, 0]) cylinder(r = hz, h = 4);
            }
        }
        // sede avambraccio
        translate([x_m0 - 1, -av_y - gioco, -av_z - gioco]) cube([L_av - x_m0 + 1 + gioco, 2 * (av_y + gioco), 2 * (av_z + gioco)]);
        // parte superiore del servo tilt + finestra
        translate([t_x0 - 0.3, y_top - 0.3, -m_w / 2 - 0.3]) cube([m_l + 0.6, y_ali - y_top + 1.3, m_w + 0.6]);
        // fori alette (autofilettanti M2)
        for (x = [t_xc - m_fori / 2, t_xc + m_fori / 2]) foro_y(x, 0, 1.8, y_fs0 - 1, y_ali + 1);
        // perno tilt: autofilettante M3 nella fiancata
        foro_y(x_t, 0, 2.5, y_fp1 - 1, y_fp0 + 1);
        // vano culla
        translate([x_m1, y_fp0, -hz - 1]) cube([40, y_fs0 - y_fp0, 2 * hz + 2]);
        // viti M3x25 verticali
        for (y = [-y_viti, y_viti]) translate([x_viti, y, 0]) {
            translate([0, 0, -hz - 1]) cylinder(d = 3.4, h = 2 * hz + 2, $fn = 24);
            translate([0, 0, hz - 2.5]) cylinder(d = 6.5, h = 4, $fn = 32);
            translate([0, 0, -hz - 0.01]) rotate(30) cylinder(d = 6.4 / cos(30), h = 2.6, $fn = 6);
        }
    }
}

// ---------------------------------------------------------------- culla (locale: asse tilt = origine)
module culla() {
    difference() {
        union() {
            translate([0, hub_y1, 0]) rotate([90, 0, 0]) cylinder(r = hub_r, h = hub_y1 - hub_y0);
            // collo pieno vicino al mozzo: da' materiale alle viti del braccio della squadretta
            hull() {
                translate([0, hub_y0, 0]) rotate([-90, 0, 0]) cylinder(r = hub_r, h = hub_y1 - hub_y0);
                translate([14, hub_y0, -hub_r]) cube([1, hub_y1 - hub_y0, 2 * hub_r]);
            }
            // fianchi
            for (y = [[hub_y0, r_y - m_w / 2 - 0.4], [r_y + m_w / 2 + 0.4, hub_y1]])
                union() {   // collo stretto vicino al mozzo (lascia ruotare il tilt di +/-90 gradi)
                    hull() {
                        translate([0, y[0], 0]) rotate([-90, 0, 0]) cylinder(r = hub_r, h = y[1] - y[0]);
                        translate([14, y[0], -hub_r]) cube([1, y[1] - y[0], 2 * hub_r]);
                    }
                    translate([14, y[0], r_z0 - 6]) cube([r_pf - 14 + 0.1, y[1] - y[0], r_z1 - r_z0 + 12]);
                }
            // piastrina alette (il servo entra dal davanti, fondo per primo, e le alette appoggiano qui davanti)
            translate([r_pf - 3, hub_y0, r_z0 - 6]) cube([3, hub_y1 - hub_y0, r_z1 - r_z0 + 12]);
        }
        // sede squadretta del servo tilt (faccia +Y del mozzo), braccio verso +X
        translate([0, hub_y1 + 0.01, 0]) rotate([90, 0, 0]) sede_squadretta(sq_inc + 0.01);
        // asola larga 1,5 sotto il braccio: le viti autofilettanti della squadretta fanno presa sui fianchi dell'asola
        translate([0, hub_y1 - sq_inc + 0.01, 0]) rotate([90, 0, 0]) linear_extrude(8)
            hull() for (r = sq_asola) translate([r, 0]) circle(d = 1.5, $fn = 16);
        // foro perno M3
        foro_y(0, 0, 3.4, hub_y0 - 1, 0);
        // corpo servo di rotazione + finestra
        translate([r_top - m_h - 1, r_y - m_w / 2 - 0.3, r_z0 - 0.3]) cube([m_h + 2, m_w + 0.6, m_l + 0.6]);
        // fori alette (M2)
        for (z = [r_zc - m_fori / 2, r_zc + m_fori / 2])
            translate([r_pf - 4, r_y, z]) rotate([0, 90, 0]) cylinder(d = 1.8, h = 5, $fn = 24);
        // tacche alle estremita' della finestra per far passare il cavo del servo
        for (z = [r_z0 - 0.3 - 2.5, r_z1 + 0.3]) translate([r_pf - 3.5, r_y - 2.5, z - 0.01]) cube([4, 5, 2.52]);
    }
}

// ---------------------------------------------------------------- piastra camera (locale: asse rotazione = asse X, faccia posteriore a x=0)
module sede_croce(h) {   // squadretta a croce: bracci lunghi lungo Y, corti lungo Z (sistema piastra)
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
    sp_c = sq_inc + sq_mozzo_p + 1.6;          // spessore al centro: incavo mozzo + 1,6 di fondo per la vite centrale
    difference() {
        union() {
            rotate([0, 90, 0]) cylinder(d = piastra_d, h = piastra_s, $fn = 120);
            // rialzo centrale sul davanti
            rotate([0, 90, 0]) cylinder(d = rialzo_d, h = sp_c, $fn = 48);
            // distanziali camera
            for (y = [-cam_fx / 2, cam_fx / 2], f = cam_fy)
                translate([piastra_s - 0.01, y, cam_ott - f]) rotate([0, 90, 0]) cylinder(d = 4.5, h = cam_dist);
        }
        // sede della squadretta a croce (faccia posteriore) + incavo del mozzo (cieco)
        translate([-0.01, 0, 0]) sede_croce(sq_inc + 0.01);
        translate([-0.01, 0, 0]) rotate([0, 90, 0]) cylinder(d = sq_mozzo_d, h = sq_inc + sq_mozzo_p + 0.01, $fn = 32);
        // vite centrale: dal davanti attraversa 1,6 mm di fondo e si avvita nell'albero del servo (testa appoggiata sul rialzo)
        translate([-1, 0, 0]) rotate([0, 90, 0]) cylinder(d = vite_c_d, h = sp_c + 2, $fn = 20);
        // asole passanti 2,2 lungo i 4 bracci: viti dal davanti nei forellini della squadretta
        for (a = [0, 180]) rotate([a, 0, 0]) hull() for (r = [rialzo_d / 2 + 1.2, cr_l1 - 1.5]) translate([-1, r, 0]) rotate([0, 90, 0]) cylinder(d = 2.2, h = piastra_s + 2, $fn = 16);
        for (a = [90, 270]) rotate([a, 0, 0]) hull() for (r = [rialzo_d / 2 + 1.2, cr_l2 - 1.5]) translate([-1, r, 0]) rotate([0, 90, 0]) cylinder(d = 2.2, h = piastra_s + 2, $fn = 16);
        // sede anello LED (lato camera: i LED guardano in avanti, stessa direzione dell'obiettivo)
        translate([piastra_s - 1, 0, 0]) rotate([0, 90, 0]) difference() {
            cylinder(d = ring_de + 0.6, h = 2, $fn = 120);
            translate([0, 0, -1]) cylinder(d = ring_di - 0.6, h = 4, $fn = 120);
        }
        // fori pilota M2 della camera
        for (y = [-cam_fx / 2, cam_fx / 2], f = cam_fy)
            translate([0, y, cam_ott - f]) rotate([0, 90, 0]) cylinder(d = 1.8, h = 12);
        // feritoia per il flat della camera (sotto la scheda)
        translate([-1, -9, cam_ott - cam_h - 4]) cube([piastra_s + 2, 18, 2.2]);
        // fori cavi anello (5V, DIN, GND)
        for (a = [200, 215]) rotate([a, 0, 0]) translate([-1, 0, (ring_di / 2 + ring_de / 2) / 2]) rotate([0, 90, 0]) cylinder(d = 2.5, h = piastra_s + 2);
    }
}

// ---------------------------------------------------------------- assieme
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

// ---------------------------------------------------------------- selezione
if      (parte == "assieme")    assieme();
else if (parte == "base_testa") translate([0, 0, 12]) base_testa();                  // sul piano a z = -12
else if (parte == "culla")      translate([0, 0, -hub_y0]) rotate([90, 0, 0]) culla(); // sul fianco -Y
else if (parte == "piastra")    rotate([0, -90, 0]) piastra();                          // faccia posteriore sul piano
